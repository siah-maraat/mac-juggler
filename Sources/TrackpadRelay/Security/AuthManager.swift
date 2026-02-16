import Foundation

final class AuthManager {
    private let token: String

    init(token: String? = nil) {
        if let token = token {
            self.token = token
        } else if let stored = AuthManager.loadFromFile() {
            self.token = stored
        } else {
            let generated = UUID().uuidString
            AuthManager.saveToFile(generated)
            self.token = generated
        }
    }

    var currentToken: String { token }

    func validate(_ candidate: String) -> Bool {
        candidate == token
    }

    // MARK: - File-based token storage

    private static var configDir: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config")
            .appendingPathComponent("trackpad-relay")
    }

    private static var tokenFile: URL {
        configDir.appendingPathComponent("token")
    }

    private static func saveToFile(_ token: String) {
        let fm = FileManager.default
        do {
            try fm.createDirectory(at: configDir, withIntermediateDirectories: true)

            // Write token
            try token.write(to: tokenFile, atomically: true, encoding: .utf8)

            // chmod 600 — owner read/write only
            try fm.setAttributes(
                [.posixPermissions: 0o600],
                ofItemAtPath: tokenFile.path
            )

            // chmod 700 on config dir
            try fm.setAttributes(
                [.posixPermissions: 0o700],
                ofItemAtPath: configDir.path
            )
        } catch {
            fputs("⚠️  Failed to save auth token: \(error)\n", stderr)
        }
    }

    private static func loadFromFile() -> String? {
        guard let data = try? Data(contentsOf: tokenFile),
              let token = String(data: data, encoding: .utf8) else {
            return nil
        }
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
