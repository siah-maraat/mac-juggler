import Foundation
import Security

final class AuthManager {
    private let token: String

    init(token: String? = nil) {
        if let token = token {
            self.token = token
        } else if let stored = AuthManager.loadFromKeychain() {
            self.token = stored
        } else {
            let generated = UUID().uuidString
            AuthManager.saveToKeychain(generated)
            self.token = generated
        }
    }

    var currentToken: String { token }

    func validate(_ candidate: String) -> Bool {
        candidate == token
    }

    // MARK: - Keychain

    private static let keychainAccount = "trackpad-relay-auth"
    private static let keychainService = "com.trackpadrelay"

    private static func saveToKeychain(_ token: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecValueData as String: token.data(using: .utf8)!,
        ]

        // Delete existing if any
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    private static func loadFromKeychain() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }
}
