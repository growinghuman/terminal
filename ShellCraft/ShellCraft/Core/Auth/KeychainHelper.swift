import Foundation
import Security

/// Secure storage for SSH keys and passwords using iOS Keychain
struct KeychainHelper {
    enum KeychainError: LocalizedError {
        case duplicateItem
        case itemNotFound
        case unexpectedStatus(OSStatus)
        case encodingError
        case decodingError

        var errorDescription: String? {
            switch self {
            case .duplicateItem: return "Item already exists in Keychain"
            case .itemNotFound: return "Item not found in Keychain"
            case .unexpectedStatus(let status):
                return "Keychain error: \(SecCopyErrorMessageString(status, nil) as String? ?? "Unknown")"
            case .encodingError: return "Failed to encode data"
            case .decodingError: return "Failed to decode data"
            }
        }
    }

    private static let service = "com.shellcraft.ssh"

    // MARK: - Password Storage

    static func savePassword(_ password: String, for account: String) throws {
        guard let data = password.data(using: .utf8) else {
            throw KeychainError.encodingError
        }
        try saveData(data, for: account, type: "password")
    }

    static func getPassword(for account: String) throws -> String {
        let data = try getData(for: account, type: "password")
        guard let password = String(data: data, encoding: .utf8) else {
            throw KeychainError.decodingError
        }
        return password
    }

    // MARK: - SSH Key Storage

    static func savePrivateKey(_ keyData: Data, for keyID: String) throws {
        try saveData(keyData, for: keyID, type: "sshkey")
    }

    static func getPrivateKey(for keyID: String) throws -> Data {
        try getData(for: keyID, type: "sshkey")
    }

    static func deletePrivateKey(for keyID: String) throws {
        try deleteData(for: keyID, type: "sshkey")
    }

    // MARK: - Generic Operations

    static func deletePassword(for account: String) throws {
        try deleteData(for: account, type: "password")
    }

    static func updatePassword(_ password: String, for account: String) throws {
        guard let data = password.data(using: .utf8) else {
            throw KeychainError.encodingError
        }
        try updateData(data, for: account, type: "password")
    }

    // MARK: - Private Helpers

    private static func saveData(_ data: Data, for account: String, type: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "\(service).\(type)",
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]

        let status = SecItemAdd(query as CFDictionary, nil)

        if status == errSecDuplicateItem {
            try updateData(data, for: account, type: type)
        } else if status != errSecSuccess {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    private static func getData(for account: String, type: String) throws -> Data {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "\(service).\(type)",
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else {
            if status == errSecItemNotFound {
                throw KeychainError.itemNotFound
            }
            throw KeychainError.unexpectedStatus(status)
        }

        return data
    }

    private static func updateData(_ data: Data, for account: String, type: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "\(service).\(type)",
            kSecAttrAccount as String: account,
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: data,
        ]

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)

        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    private static func deleteData(for account: String, type: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "\(service).\(type)",
            kSecAttrAccount as String: account,
        ]

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }
}
