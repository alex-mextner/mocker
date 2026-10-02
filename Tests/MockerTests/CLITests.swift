import Foundation
import Testing
import ArgumentParser
import MockerKit
@testable import Mocker

@Suite("CLI Tests")
struct CLITests {
    @Test("Mocker version is defined and consistent")
    func version() {
        let version = Version.currentVersion
        #expect(!version.isEmpty)
        // x-release-please-start-version
        #expect(version == "0.7.2")
        // x-release-please-end
    }

    @Test("Update errors instead of silently ignoring --memory")
    func updateMemoryErrorsInsteadOfNoOp() async throws {
        // Apple Containerization sizes a container's VM once at `run` time and has no
        // live-update path, so `mocker update -m` used to just print a warning and
        // exit 0 — a silent no-op that looked like success. It must now fail loudly
        // instead of pretending the limit changed. See #62.
        let command = try Update.parse(["--memory", "3g", "some-container"])
        await #expect(throws: MockerError.self) {
            try await command.run()
        }
    }

    @Test("Update errors instead of silently ignoring --cpus")
    func updateCpusErrorsInsteadOfNoOp() async throws {
        let command = try Update.parse(["--cpus", "2", "some-container"])
        await #expect(throws: MockerError.self) {
            try await command.run()
        }
    }

    @Test("Run command accepts --env-file flag")
    func runEnvFileFlag() throws {
        let command = try Run.parse(["--env-file", "test.env", "alpine"])
        #expect(command.envFile == "test.env")
        #expect(command.image == "alpine")
    }

    @Test("Compose subcommand accepts repeated -f flags")
    func composeRepeatedFile() throws {
        let command = try ComposePull.parse(["-f", "a.yaml", "-f", "b.yaml"])
        #expect(command.options.files == ["a.yaml", "b.yaml"])
    }

    @Test("Compose subcommand accepts --file long flag (Docker parity)")
    func composeFileLongFlag() throws {
        let command = try ComposePull.parse(["--file", "a.yaml"])
        #expect(command.options.files == ["a.yaml"])
    }

    @Test("Compose subcommand accepts --file mixed with -f")
    func composeFileLongAndShort() throws {
        let command = try ComposePull.parse(["-f", "a.yaml", "--file", "b.yaml"])
        #expect(command.options.files == ["a.yaml", "b.yaml"])
    }

    @Test("Compose up parses -f together with a subcommand flag")
    func composeUpFileAndFlag() throws {
        let command = try ComposeUp.parse(["-f", "docker-compose.yml", "--detach"])
        #expect(command.options.files == ["docker-compose.yml"])
        #expect(command.detach == true)
    }

    @Test("Compose subcommand accepts --project-directory flag")
    func composeProjectDirectoryFlag() throws {
        let command = try ComposePull.parse(["--project-directory", "/tmp/myproj", "-f", "a.yaml"])
        #expect(command.options.projectDirectory == "/tmp/myproj")
    }

    @Test("Compose up parses --force-recreate")
    func composeUpForceRecreateFlag() throws {
        let command = try ComposeUp.parse(["-d", "--force-recreate"])
        #expect(command.forceRecreate == true)
        #expect(command.noRecreate == false)
    }

    @Test("Compose up parses --no-recreate")
    func composeUpNoRecreateFlag() throws {
        let command = try ComposeUp.parse(["-d", "--no-recreate"])
        #expect(command.noRecreate == true)
        #expect(command.forceRecreate == false)
    }

    @Test("Compose up rejects --force-recreate + --no-recreate together")
    func composeUpForceAndNoRecreateConflict() throws {
        do {
            _ = try ComposeUp.parse(["-d", "--force-recreate", "--no-recreate"])
            Issue.record("expected parse() to throw")
        } catch {
            let msg = String(describing: error)
            #expect(msg.contains("--force-recreate"))
            #expect(msg.contains("--no-recreate"))
        }
    }

    @Test("Compose create parses --force-recreate")
    func composeCreateForceRecreateFlag() throws {
        let command = try ComposeCreate.parse(["--force-recreate"])
        #expect(command.forceRecreate == true)
        #expect(command.noRecreate == false)
    }

    @Test("Compose create parses --no-recreate")
    func composeCreateNoRecreateFlag() throws {
        let command = try ComposeCreate.parse(["--no-recreate"])
        #expect(command.noRecreate == true)
        #expect(command.forceRecreate == false)
    }

    @Test("Compose create rejects --force-recreate + --no-recreate together")
    func composeCreateForceAndNoRecreateConflict() throws {
        do {
            _ = try ComposeCreate.parse(["--force-recreate", "--no-recreate"])
            Issue.record("expected parse() to throw")
        } catch {
            let msg = String(describing: error)
            #expect(msg.contains("--force-recreate"))
            #expect(msg.contains("--no-recreate"))
        }
    }

    @Test("loadCompose discovers the default file inside --project-directory when -f is omitted")
    func loadComposeUsesProjectDirectoryForDefaultDiscovery() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let projectDir = root.appendingPathComponent("proj")
        try FileManager.default.createDirectory(at: projectDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let composePath = projectDir.appendingPathComponent("compose.yml")
        try "services:\n  web:\n    image: nginx:latest\n".write(to: composePath, atomically: true, encoding: .utf8)

        let command = try ComposePull.parse(["--project-directory", projectDir.path])
        let (composeFile, _, resolvedProjectDir) = try command.options.loadCompose()

        #expect(resolvedProjectDir.path == projectDir.path)
        #expect(composeFile.services["web"] != nil)
    }

    @Test("Run command accepts nested virtualization flags")
    func runVirtualizationFlags() throws {
        let command = try Run.parse(["--virtualization", "--kernel", "/tmp/vmlinux", "ubuntu:latest"])
        #expect(command.virtualization == true)
        #expect(command.kernel == "/tmp/vmlinux")
        #expect(command.image == "ubuntu:latest")
    }

    @Test("Create command accepts nested virtualization flags")
    func createVirtualizationFlags() throws {
        let command = try Create.parse(["--virtualization", "--kernel", "/tmp/vmlinux", "ubuntu:latest"])
        #expect(command.virtualization == true)
        #expect(command.kernel == "/tmp/vmlinux")
        #expect(command.image == "ubuntu:latest")
    }

    @Test("Pull command accepts --platform flag")
    func pullPlatformFlag() throws {
        let command = try Pull.parse(["--platform", "linux/amd64", "alpine:latest"])
        #expect(command.platform == "linux/amd64")
        #expect(command.image == "alpine:latest")
    }

    @Test("Pull command leaves platform nil when omitted")
    func pullPlatformDefaultsNil() throws {
        let command = try Pull.parse(["alpine:latest"])
        #expect(command.platform == nil)
    }

    @Test("Push command accepts --platform flag")
    func pushPlatformFlag() throws {
        let command = try Push.parse(["--platform", "linux/arm64", "myrepo/app:1.0"])
        #expect(command.platform == "linux/arm64")
        #expect(command.image == "myrepo/app:1.0")
    }

    @Test("Build command accepts repeated --platform flags")
    func buildRepeatedPlatform() throws {
        let command = try Build.parse([
            "-t", "multi:latest",
            "--platform", "linux/amd64",
            "--platform", "linux/arm64",
            ".",
        ])
        #expect(command.platform == ["linux/amd64", "linux/arm64"])
        #expect(command.tag == "multi:latest")
    }

    @Test("Build command leaves platform empty when omitted")
    func buildPlatformDefaultsEmpty() throws {
        let command = try Build.parse(["-t", "x:latest", "."])
        #expect(command.platform.isEmpty)
    }

    @Test("Manifest inspect command parses reference argument")
    func manifestInspectParse() throws {
        let command = try ManifestInspect.parse(["myrepo/multi:latest"])
        #expect(command.manifestList == "myrepo/multi:latest")
    }

    @Test("Manifest create command parses list name and children")
    func manifestCreateParse() throws {
        let command = try ManifestCreate.parse([
            "myrepo/multi:latest",
            "myrepo/app:linux-amd64",
            "myrepo/app:linux-arm64",
        ])
        #expect(command.manifestList == "myrepo/multi:latest")
        #expect(command.manifests == ["myrepo/app:linux-amd64", "myrepo/app:linux-arm64"])
    }

    @Test("Manifest add command parses list and child")
    func manifestAddParse() throws {
        let command = try ManifestAdd.parse(["multi:latest", "child:linux-amd64"])
        #expect(command.manifestList == "multi:latest")
        #expect(command.manifest == "child:linux-amd64")
    }

    @Test("Manifest rm command parses list and target")
    func manifestRmParse() throws {
        let platformCmd = try ManifestRm.parse(["multi:latest", "linux/amd64"])
        #expect(platformCmd.target == "linux/amd64")
        let digestCmd = try ManifestRm.parse(["multi:latest", "sha256:deadbeef"])
        #expect(digestCmd.target == "sha256:deadbeef")
    }

    @Test("Manifest push command parses list name")
    func manifestPushParse() throws {
        let command = try ManifestPush.parse(["myrepo/multi:latest"])
        #expect(command.manifestList == "myrepo/multi:latest")
    }

    @Test("Manifest annotate parses os/arch/variant overrides")
    func manifestAnnotateParse() throws {
        let command = try ManifestAnnotate.parse([
            "multi:latest", "child:arm64",
            "--os", "linux",
            "--arch", "arm64",
            "--variant", "v8",
        ])
        #expect(command.manifestList == "multi:latest")
        #expect(command.manifest == "child:arm64")
        #expect(command.os == "linux")
        #expect(command.arch == "arm64")
        #expect(command.variant == "v8")
    }

    @Test("Manifest annotate leaves overrides nil when omitted")
    func manifestAnnotateDefaults() throws {
        let command = try ManifestAnnotate.parse(["multi:latest", "child:arm64"])
        #expect(command.os == nil)
        #expect(command.arch == nil)
        #expect(command.variant == nil)
    }

    @Test("image ls command accepts all list flags")
    func imageLsAllFlags() throws {
        let command = try ImageLs.parse(["--quiet", "--all", "--filter", "reference=nginx", "--format", "{{.ID}}", "--digests", "--no-trunc", "--tree"])
        #expect(command.options.quiet == true)
        #expect(command.options.all == true)
        #expect(command.options.filter == ["reference=nginx"])
        #expect(command.options.format == "{{.ID}}")
        #expect(command.options.digests == true)
        #expect(command.options.noTrunc == true)
        #expect(command.options.tree == true)
    }

    @Test("image ls --filter narrows by reference and label")
    func imageLsFilter() throws {
        let images = [
            ImageInfo(id: "a", repository: "nginx", tag: "latest", labels: ["env": "prod"]),
            ImageInfo(id: "b", repository: "redis", tag: "7", labels: ["env": "dev"]),
        ]
        let byRef = try ImageLs.parse(["--filter", "reference=nginx"]).options
        #expect(byRef.filtered(images).map(\.id) == ["a"])

        let byLabel = try ImageLs.parse(["--filter", "label=env=dev"]).options
        #expect(byLabel.filtered(images).map(\.id) == ["b"])
    }

    @Test("image ls --format substitutes repository, tag and labels")
    func imageLsFormat() throws {
        let img = ImageInfo(id: "abc123def456789", repository: "nginx", tag: "latest", labels: ["env": "prod"])
        let opts = try ImageLs.parse(["--format", "{{.Repository}}:{{.Tag}} {{.Labels}}"]).options
        #expect(opts.formatLine(img) == "nginx:latest env=prod")

        let noTrunc = try ImageLs.parse(["--format", "{{.ID}}", "--no-trunc"]).options
        #expect(noTrunc.formatLine(img) == "abc123def456789")
    }

    @Test("container ls command accepts all list flags")
    func containerLsAllFlags() throws {
        let command = try ContainerLs.parse(["--all", "--quiet", "--filter", "status=running", "--format", "{{.ID}}", "--no-trunc", "-n", "3", "--latest", "--size"])
        #expect(command.options.all == true)
        #expect(command.options.quiet == true)
        #expect(command.options.filter == ["status=running"])
        #expect(command.options.format == "{{.ID}}")
        #expect(command.options.noTrunc == true)
        #expect(command.options.last == 3)
        #expect(command.options.latest == true)
        #expect(command.options.size == true)
    }

    @Test("container ls --filter narrows by status and name")
    func containerLsFilter() throws {
        let containers = [
            ContainerInfo(id: "a", name: "web", image: "nginx", state: .running, status: "Up", created: .distantPast),
            ContainerInfo(id: "b", name: "db", image: "redis", state: .exited, status: "Exited", created: .distantPast),
        ]
        let byStatus = try ContainerLs.parse(["--filter", "status=running"]).options
        #expect(byStatus.filtered(containers).map(\.id) == ["a"])

        let byName = try ContainerLs.parse(["--filter", "name=db"]).options
        #expect(byName.filtered(containers).map(\.id) == ["b"])
    }

    @Test("Build -f flag parses to the provided path")
    func buildFileOptionParsesPath() throws {
        let command = try Build.parse(["-f", "/abs/path/Dockerfile", "-t", "x:1", "."])
        #expect(command.file == "/abs/path/Dockerfile")
    }

    @Test("Build -f flag defaults to nil when omitted")
    func buildFileOptionDefaultsNil() throws {
        let command = try Build.parse(["-t", "x:1", "."])
        #expect(command.file == nil)
    }

    @Test("Run passes args after image to container")
    func runPassthroughAfterImage() throws {
        let command = try Run.parse(["--rm", "img", "ls", "-la", "/stuff/"])
        #expect(command.command == ["ls", "-la", "/stuff/"])
        #expect(command.rm == true)
    }

    @Test("Create passes args after image to container")
    func createPassthroughAfterImage() throws {
        let command = try Create.parse(["img", "cmd", "-flag"])
        #expect(command.command == ["cmd", "-flag"])
    }

    @Test("Exec passes args after container to command")
    func execPassthroughAfterContainer() throws {
        let command = try Exec.parse(["ctn", "ls", "-la"])
        #expect(command.command == ["ls", "-la"])
    }

    @Test("Compose run passes args after service to container")
    func composeRunPassthroughAfterService() throws {
        let command = try ComposeRun.parse(["svc", "ls", "-la"])
        #expect(command.command == ["ls", "-la"])
    }

    @Test("Compose exec passes args after service to command")
    func composeExecPassthroughAfterService() throws {
        let command = try ComposeExec.parse(["svc", "ls", "-la"])
        #expect(command.command == ["ls", "-la"])
    }

    @Test("Run strips leading -- terminator")
    func runStripsLeadingDoubleDash() throws {
        var command = try Run.parse(["--rm", "img", "--", "ls", "-la"])
        try command.validate()
        #expect(command.command == ["ls", "-la"])
        #expect(command.rm == true)
    }

    @Test("Run preserves non-leading -- inside command")
    func runPreservesNonLeadingDoubleDash() throws {
        var command = try Run.parse(["img", "ls", "--", "-la"])
        try command.validate()
        #expect(command.command == ["ls", "--", "-la"])
    }

    @Test("Create strips leading -- terminator")
    func createStripsLeadingDoubleDash() throws {
        var command = try Create.parse(["img", "--", "cmd", "-flag"])
        try command.validate()
        #expect(command.command == ["cmd", "-flag"])
    }

    @Test("Exec strips leading -- terminator")
    func execStripsLeadingDoubleDash() throws {
        var command = try Exec.parse(["ctn", "--", "ls", "-la"])
        try command.validate()
        #expect(command.command == ["ls", "-la"])
    }

    @Test("Compose run strips leading -- terminator")
    func composeRunStripsLeadingDoubleDash() throws {
        var command = try ComposeRun.parse(["svc", "--", "ls", "-la"])
        try command.validate()
        #expect(command.command == ["ls", "-la"])
    }

    @Test("Compose exec strips leading -- terminator")
    func composeExecStripsLeadingDoubleDash() throws {
        var command = try ComposeExec.parse(["svc", "--", "ls", "-la"])
        try command.validate()
        #expect(command.command == ["ls", "-la"])
    }

    // Negative-number-valued options (`--memory-swap -1`, `--pids-limit -1`,
    // `--oom-score-adj -500`) used to fail in the space-separated form because
    // ArgumentParser's default `.next` parsing strategy refuses to consume a
    // following token that looks like another flag (leading `-`). The `=`-joined
    // form (`--memory-swap=-1`) always worked, masking the bug. Fixed by declaring
    // these options with `parsing: .unconditional` so the immediately following
    // token is always treated as the value, matching Docker CLI parity. Both forms
    // must parse to the same value for every affected flag on every command that
    // declares it.

    @Test("Create accepts --memory-swap -1 (space form)")
    func createMemorySwapSpaceForm() throws {
        let command = try Create.parse(["--memory-swap", "-1", "alpine"])
        #expect(command.memorySwap == "-1")
    }

    @Test("Create accepts --memory-swap=-1 (equals form)")
    func createMemorySwapEqualsForm() throws {
        let command = try Create.parse(["--memory-swap=-1", "alpine"])
        #expect(command.memorySwap == "-1")
    }

    @Test("Create accepts --pids-limit -1 (space form)")
    func createPidsLimitSpaceForm() throws {
        let command = try Create.parse(["--pids-limit", "-1", "alpine"])
        #expect(command.pidsLimit == -1)
    }

    @Test("Create accepts --pids-limit=-1 (equals form)")
    func createPidsLimitEqualsForm() throws {
        let command = try Create.parse(["--pids-limit=-1", "alpine"])
        #expect(command.pidsLimit == -1)
    }

    @Test("Create accepts --oom-score-adj -500 (space form)")
    func createOomScoreAdjSpaceForm() throws {
        let command = try Create.parse(["--oom-score-adj", "-500", "alpine"])
        #expect(command.oomScoreAdj == -500)
    }

    @Test("Create accepts --oom-score-adj=-500 (equals form)")
    func createOomScoreAdjEqualsForm() throws {
        let command = try Create.parse(["--oom-score-adj=-500", "alpine"])
        #expect(command.oomScoreAdj == -500)
    }

    @Test("Run accepts --memory-swap -1 (space form)")
    func runMemorySwapSpaceForm() throws {
        let command = try Run.parse(["--memory-swap", "-1", "alpine"])
        #expect(command.memorySwap == "-1")
    }

    @Test("Run accepts --pids-limit -1 (space form)")
    func runPidsLimitSpaceForm() throws {
        let command = try Run.parse(["--pids-limit", "-1", "alpine"])
        #expect(command.pidsLimit == -1)
    }

    @Test("Run accepts --oom-score-adj -500 (space form)")
    func runOomScoreAdjSpaceForm() throws {
        let command = try Run.parse(["--oom-score-adj", "-500", "alpine"])
        #expect(command.oomScoreAdj == -500)
    }

    @Test("Update accepts --memory-swap -1 (space form)")
    func updateMemorySwapSpaceForm() throws {
        let command = try Update.parse(["--memory-swap", "-1", "some-container"])
        #expect(command.memorySwap == "-1")
    }

    @Test("Update accepts --pids-limit -1 (space form)")
    func updatePidsLimitSpaceForm() throws {
        let command = try Update.parse(["--pids-limit", "-1", "some-container"])
        #expect(command.pidsLimit == -1)
    }

    @Test("Update still parses a positive --pids-limit value normally")
    func updatePidsLimitPositiveValue() throws {
        let command = try Update.parse(["--pids-limit", "100", "some-container"])
        #expect(command.pidsLimit == 100)
    }

    // --cpu-quota and --memory-swappiness accept a negative sentinel in Docker too
    // (-1 disables the quota / falls back to the daemon default), so the same
    // space-separated parsing bug applied to them.

    @Test("Create accepts --cpu-quota -1 (space form)")
    func createCpuQuotaSpaceForm() throws {
        let command = try Create.parse(["--cpu-quota", "-1", "alpine"])
        #expect(command.cpuQuota == -1)
    }

    @Test("Create accepts --memory-swappiness -1 (space form)")
    func createMemorySwappinessSpaceForm() throws {
        let command = try Create.parse(["--memory-swappiness", "-1", "alpine"])
        #expect(command.memorySwappiness == -1)
    }

    @Test("Run accepts --cpu-quota -1 (space form)")
    func runCpuQuotaSpaceForm() throws {
        let command = try Run.parse(["--cpu-quota", "-1", "alpine"])
        #expect(command.cpuQuota == -1)
    }

    @Test("Run accepts --memory-swappiness -1 (space form)")
    func runMemorySwappinessSpaceForm() throws {
        let command = try Run.parse(["--memory-swappiness", "-1", "alpine"])
        #expect(command.memorySwappiness == -1)
    }

    @Test("Update accepts --cpu-quota -1 (space form)")
    func updateCpuQuotaSpaceForm() throws {
        let command = try Update.parse(["--cpu-quota", "-1", "some-container"])
        #expect(command.cpuQuota == -1)
    }

    // `.unconditional` parsing means an omitted --memory-swap value now silently
    // consumes the next flag as its "value" instead of erroring — String has no
    // type-level check the way Int-typed options (--pids-limit, --oom-score-adj,
    // --cpu-quota) get from ArgumentParser's own conversion. `validate()` rejects
    // any value that is itself long-flag-shaped so this doesn't fail silently.

    // `Command.parse(...)` already runs `validate()` internally (see
    // ArgumentParser's `ParsableArguments.parse(_:)`) and wraps whatever it throws
    // as `ParserError.userValidationError`, so the rejection surfaces at the
    // `parse()` call itself, not a separately-called `.validate()`.

    @Test("Create rejects --memory-swap immediately followed by another flag")
    func createMemorySwapRejectsSwallowedFlag() {
        #expect(throws: (any Error).self) {
            _ = try Create.parse(["--memory-swap", "--oom-kill-disable", "alpine"])
        }
    }

    @Test("Run rejects --memory-swap immediately followed by another flag")
    func runMemorySwapRejectsSwallowedFlag() {
        #expect(throws: (any Error).self) {
            _ = try Run.parse(["--memory-swap", "--oom-kill-disable", "alpine"])
        }
    }

    @Test("Update rejects --memory-swap immediately followed by another flag")
    func updateMemorySwapRejectsSwallowedFlag() {
        #expect(throws: (any Error).self) {
            _ = try Update.parse(["--memory-swap", "--force", "some-container"])
        }
    }
}
