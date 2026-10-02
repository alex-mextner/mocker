import ArgumentParser

/// Guards `String?`-typed resource options (like `--memory-swap`) that are declared
/// with `parsing: .unconditional` so they can accept a negative-number value in the
/// space-separated form (`--memory-swap -1`, matching Docker CLI parity — see
/// `Option.swift`'s `SingleValueParsingStrategy.unconditional` docs upstream).
///
/// `.unconditional` parsing always consumes the very next token as the value, even
/// when that token looks like another flag (`--oom-kill-disable`). Unlike the `Int?`
/// resource options (`--pids-limit`, `--oom-score-adj`, `--cpu-quota`,
/// `--memory-swappiness`), ArgumentParser can't reject that on its own for a
/// `String?` option — any string converts. Call this from each command's
/// `validate()` to reject a value that is itself a long-flag-shaped token, which is
/// never a legitimate size string ("512m", "-1", "1g") and almost always means the
/// flag's value was omitted and the next flag got swallowed instead.
func validateResourceOptionValue(_ value: String?, flag: String) throws {
    guard let value, value.hasPrefix("--") else { return }
    throw ValidationError(
        "Missing value for '\(flag)': '\(value)' looks like another option, not a value."
    )
}
