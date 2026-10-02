import Foundation

/// Minimal Go `text/template` field-path evaluator for `inspect --format`.
///
/// Why this exists
/// ---------------
/// `mocker inspect` mirrors `docker inspect`, and real-world callers drive it with
/// `-f '{{.State.Running}}'` style templates (dev stands, CI health gates, e.g.
/// `docker inspect -f '{{.State.Running}}' c | grep -q true`). Docker evaluates the
/// template and prints a bare scalar; without this, `--format` would be parsed but
/// ignored and the full JSON dumped, breaking every such caller.
///
/// Scope (intentionally small — matches the bash shim's `render_go_template`)
/// -------------------------------------------------------------------------
/// We support the `{{ .Dotted.Path }}` field-access subset that container/image
/// inspect callers actually use — not the full Go template language (no `if`,
/// `range`, pipelines, or functions). A path is resolved against the record's
/// JSON object; an unknown or null path renders empty (Docker prints `<no value>`,
/// but empty is safe for the boolean/string checks these templates feed and avoids
/// a surprising literal in scripted output).
///
/// Docker-shape compatibility layer
/// --------------------------------
/// `mocker`'s container inspect JSON is flat (`"state": "running"`), whereas Docker
/// nests it (`"State": {"Running": true, ...}`). Callers write Docker paths, so for
/// container records we resolve a handful of canonical Docker paths
/// (`.State.Running`, `.State.Status`, `.Id`, `.Name`, `.Config.Image`,
/// `.NetworkSettings.IPAddress`) onto mocker's flat fields. Plain mocker-native
/// paths (`.state`, `.id`, …) and image inspect paths (already PascalCase: `.Id`,
/// `.RepoTags`) resolve directly against the JSON.
enum GoTemplate {
    /// Render `template` against one inspect record, supplied as its encoded JSON object.
    ///
    /// - Parameters:
    ///   - template: A Go template string containing `{{ .Path }}` tokens.
    ///   - object: The record's JSON, decoded to a dictionary (one element of the
    ///     inspect array). Docker-compatibility aliases are layered on top for
    ///     container records.
    /// - Returns: The template with every recognized token replaced by its value.
    static func render(_ template: String, object: [String: Any]) -> String {
        let resolved = withDockerAliases(object)
        var output = template
        for token in tokens(in: template) {
            let value = resolveValue(path: token.path, in: resolved)
            output = output.replacingOccurrences(of: token.literal, with: value)
        }
        return output
    }

    // MARK: - Tokenization

    /// A `{{ .Path }}` occurrence: the exact source substring and its dotted path.
    private struct Token {
        let literal: String
        let path: [String]
    }

    /// Extract each distinct `{{ .Dotted.Path }}` token from the template.
    ///
    /// Scanning the original template (not substituted output) means a field value
    /// that itself contains `{{…}}` can never re-trigger substitution — no infinite
    /// loop, mirroring the bash shim's two-pass approach.
    private static func tokens(in template: String) -> [Token] {
        let pattern = #"\{\{\s*\.([A-Za-z0-9_.]+)\s*\}\}"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let full = NSRange(template.startIndex..., in: template)
        var seen = Set<String>()
        var result: [Token] = []
        for match in regex.matches(in: template, range: full) {
            guard let literalRange = Range(match.range, in: template),
                  let pathRange = Range(match.range(at: 1), in: template) else { continue }
            let literal = String(template[literalRange])
            guard seen.insert(literal).inserted else { continue }
            let path = String(template[pathRange]).split(separator: ".").map(String.init)
            result.append(Token(literal: literal, path: path))
        }
        return result
    }

    // MARK: - Path resolution

    /// Walk a dotted path through nested dictionaries, rendering the leaf as a scalar.
    private static func resolveValue(path: [String], in object: [String: Any]) -> String {
        var current: Any = object
        for key in path {
            guard let dict = current as? [String: Any], let next = dict[key] else {
                return ""
            }
            current = next
        }
        return scalar(current)
    }

    /// Render a JSON leaf the way Go's template prints it: bare `true`/`false`,
    /// integers without a decimal point, strings verbatim; containers/null → empty.
    private static func scalar(_ value: Any) -> String {
        switch value {
        case let bool as Bool:
            return bool ? "true" : "false"
        case let int as Int:
            return String(int)
        case let number as NSNumber:
            // NSNumber bridges JSON booleans and numbers; disambiguate the bool case
            // (already handled above for native Bool, but JSONSerialization yields NSNumber).
            if CFGetTypeID(number) == CFBooleanGetTypeID() {
                return number.boolValue ? "true" : "false"
            }
            if number.intValue == number.doubleValue.rounded(), number.doubleValue == Double(number.intValue) {
                return String(number.intValue)
            }
            return number.stringValue
        case let string as String:
            return string
        case is NSNull:
            return ""
        default:
            return ""
        }
    }

    // MARK: - Docker-shape compatibility

    /// Layer canonical Docker inspect paths onto a flat `mocker` container record so
    /// `{{.State.Running}}` and friends resolve. No-op for records that already carry
    /// Docker PascalCase keys (image inspect) or lack the flat `state`/`id` markers.
    private static func withDockerAliases(_ object: [String: Any]) -> [String: Any] {
        // Only container records have a lowercase flat `state` string; image inspect
        // is already Docker-shaped and must pass through untouched.
        guard let state = object["state"] as? String else { return object }

        var result = object
        result["State"] = [
            "Running": state == "running",
            "Paused": state == "paused",
            "Status": state,
            "ExitCode": 0,
        ]
        if let id = object["id"] { result["Id"] = id }
        if let name = object["name"] as? String {
            // Docker prefixes the container name with a slash.
            result["Name"] = name.hasPrefix("/") ? name : "/\(name)"
        }
        if let image = object["image"] {
            result["Config"] = ["Image": image]
            result["Image"] = image
        }
        if let address = object["networkAddress"] {
            result["NetworkSettings"] = ["IPAddress": address]
        }
        return result
    }
}
