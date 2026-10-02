import Testing
@testable import Mocker

@Suite("GoTemplate inspect --format Tests")
struct GoTemplateTests {
    /// A flat mocker container inspect record (as emitted by `ContainerInfo`).
    private func runningContainer() -> [String: Any] {
        [
            "id": "mocker-probe",
            "name": "mocker-probe",
            "image": "postgres:16-alpine",
            "state": "running",
            "status": "Up 2 seconds",
            "networkAddress": "192.168.64.3",
        ]
    }

    // MARK: - Docker-compatibility aliases (the dev-stand health gate)

    @Test("{{.State.Running}} renders bare true for a running container")
    func stateRunningTrue() {
        let out = GoTemplate.render("{{.State.Running}}", object: runningContainer())
        #expect(out == "true")
    }

    @Test("{{.State.Running}} renders bare false for a stopped container")
    func stateRunningFalse() {
        var c = runningContainer()
        c["state"] = "stopped"
        let out = GoTemplate.render("{{.State.Running}}", object: c)
        #expect(out == "false")
    }

    @Test("{{.State.Status}} renders the lifecycle string")
    func stateStatus() {
        let out = GoTemplate.render("{{.State.Status}}", object: runningContainer())
        #expect(out == "running")
    }

    @Test("{{.Name}} is slash-prefixed like Docker")
    func nameSlashPrefixed() {
        let out = GoTemplate.render("{{.Name}}", object: runningContainer())
        #expect(out == "/mocker-probe")
    }

    @Test("{{.Id}} resolves the container id")
    func idResolves() {
        let out = GoTemplate.render("{{.Id}}", object: runningContainer())
        #expect(out == "mocker-probe")
    }

    @Test("{{.Config.Image}} resolves the image reference")
    func configImage() {
        let out = GoTemplate.render("{{.Config.Image}}", object: runningContainer())
        #expect(out == "postgres:16-alpine")
    }

    @Test("{{.NetworkSettings.IPAddress}} resolves the container IP")
    func networkIP() {
        let out = GoTemplate.render("{{.NetworkSettings.IPAddress}}", object: runningContainer())
        #expect(out == "192.168.64.3")
    }

    // MARK: - Whitespace, literals, multiple tokens

    @Test("whitespace inside the braces is tolerated")
    func whitespaceTolerated() {
        let out = GoTemplate.render("{{ .State.Running }}", object: runningContainer())
        #expect(out == "true")
    }

    @Test("surrounding literal text is preserved")
    func literalTextPreserved() {
        let out = GoTemplate.render("status={{.State.Status}}!", object: runningContainer())
        #expect(out == "status=running!")
    }

    @Test("multiple tokens in one template all resolve")
    func multipleTokens() {
        let out = GoTemplate.render("{{.Id}} {{.State.Running}}", object: runningContainer())
        #expect(out == "mocker-probe true")
    }

    // MARK: - Native + image paths

    @Test("native flat path {{.state}} resolves directly")
    func nativeStatePath() {
        let out = GoTemplate.render("{{.state}}", object: runningContainer())
        #expect(out == "running")
    }

    @Test("unknown path renders empty, not the literal token")
    func unknownPathEmpty() {
        let out = GoTemplate.render("{{.Nope.Missing}}", object: runningContainer())
        #expect(out == "")
    }

    @Test("Docker-shaped image record (PascalCase) passes through untouched")
    func imageRecordPassthrough() {
        // Image inspect already emits Docker PascalCase keys and no flat `state`.
        let image: [String: Any] = ["Id": "sha256:abc", "Os": "linux"]
        #expect(GoTemplate.render("{{.Id}}", object: image) == "sha256:abc")
        #expect(GoTemplate.render("{{.Os}}", object: image) == "linux")
    }

    @Test("a value containing braces does not retrigger substitution")
    func noReentrantSubstitution() {
        var c = runningContainer()
        c["name"] = "{{.State.Running}}"
        // Name is slash-prefixed; the brace content must survive verbatim.
        let out = GoTemplate.render("{{.Name}}", object: c)
        #expect(out == "/{{.State.Running}}")
    }
}
