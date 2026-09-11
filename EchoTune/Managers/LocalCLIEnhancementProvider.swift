import Foundation

/// Ollama-backed enhancement with no network request from EchoTune. Ollama is
/// an optional user-installed dependency, so absence is represented as an
/// unavailable row rather than an error during app startup.
final class LocalCLIEnhancementProvider: EnhancementProvider, @unchecked Sendable {
    enum ProviderError: Error, LocalizedError {
        case unavailable
        case emptyOutput
        case timedOut
        case processFailed(Int32, String)

        var errorDescription: String? {
            switch self {
            case .unavailable: return "Ollama is not installed. Install it to use local enhancement."
            case .emptyOutput: return "Ollama returned no enhancement text."
            case .timedOut: return "Ollama enhancement timed out after 30 seconds."
            case .processFailed(let code, let message):
                return message.isEmpty ? "Ollama exited with status \(code)." : "Ollama failed: \(message)"
            }
        }
    }

    let id = "ollama-local"
    let displayName = "Ollama (local)"
    private let lock = NSLock()
    private var configuredModelName: String
    private var detectedPath: String?

    var isAvailable: Bool {
        lock.lock()
        defer { lock.unlock() }
        return detectedPath != nil
    }

    init(modelName: String = "llama3.2:1b") {
        self.configuredModelName = modelName
    }

    func updateModelName(_ modelName: String) {
        lock.lock()
        configuredModelName = modelName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "llama3.2:1b" : modelName
        lock.unlock()
    }

    func refreshAvailability() async {
        let path = await Task.detached(priority: .utility) {
            Self.locateBinary()
        }.value
        lock.lock()
        detectedPath = path
        lock.unlock()
    }

    static func standardCandidatePaths(homeDirectory: String = NSHomeDirectory(), path: String = ProcessInfo.processInfo.environment["PATH"] ?? "") -> [String] {
        var candidates = [
            "/opt/homebrew/bin/ollama",
            "/usr/local/bin/ollama",
            "\(homeDirectory)/.local/bin/ollama",
            "/Applications/Ollama.app/Contents/Resources/ollama"
        ]
        candidates.append(contentsOf: path.split(separator: ":").map { "\($0)/ollama" })
        return Array(NSOrderedSet(array: candidates)) as? [String] ?? candidates
    }

    static func locateBinary(fileManager: FileManager = .default, homeDirectory: String = NSHomeDirectory(), path: String = ProcessInfo.processInfo.environment["PATH"] ?? "") -> String? {
        standardCandidatePaths(homeDirectory: homeDirectory, path: path).first {
            fileManager.isExecutableFile(atPath: $0)
        }
    }

    static func commandArguments(modelName: String) -> [String] {
        ["run", modelName]
    }

    func polish(_ text: String, prompt: String) async throws -> String {
        lock.lock()
        let executable = detectedPath
        lock.unlock()
        guard let executable else { throw ProviderError.unavailable }

        let input = """
        \(prompt)

        <DICTATION>
        \(text)
        </DICTATION>
        Return only the polished text.
        """
        let inputData = Data(input.utf8)
        lock.lock()
        let modelName = configuredModelName
        lock.unlock()

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                let stdin = Pipe()
                let stdout = Pipe()
                let stderr = Pipe()
                process.executableURL = URL(fileURLWithPath: executable)
                process.arguments = Self.commandArguments(modelName: modelName)
                process.standardInput = stdin
                process.standardOutput = stdout
                process.standardError = stderr

                do {
                    try process.run()
                    stdin.fileHandleForWriting.write(inputData)
                    stdin.fileHandleForWriting.closeFile()
                } catch {
                    continuation.resume(throwing: error)
                    return
                }

                let deadline = Date().addingTimeInterval(30)
                while process.isRunning && Date() < deadline {
                    Thread.sleep(forTimeInterval: 0.1)
                }
                if process.isRunning {
                    process.terminate()
                    continuation.resume(throwing: ProviderError.timedOut)
                    return
                }

                let output = String(data: stdout.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                let errorText = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                guard process.terminationStatus == 0 else {
                    continuation.resume(throwing: ProviderError.processFailed(process.terminationStatus, errorText.trimmingCharacters(in: .whitespacesAndNewlines)))
                    return
                }
                let cleaned = output.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !cleaned.isEmpty else {
                    continuation.resume(throwing: ProviderError.emptyOutput)
                    return
                }
                continuation.resume(returning: cleaned)
            }
        }
    }
}
