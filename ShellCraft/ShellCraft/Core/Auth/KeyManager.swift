import Foundation
import Security
import Crypto
import NIOSSH

/// Manages SSH key generation, import/export, and storage
final class KeyManager {
    static let shared = KeyManager()

    private init() {}

    // MARK: - Key Generation

    func generateKeyPair(type: SSHKeyType, comment: String? = nil) throws -> (publicKey: Data, privateKeychainID: String) {
        let keychainID = UUID().uuidString

        switch type {
        case .ed25519:
            let privateKey = Curve25519.Signing.PrivateKey()
            let publicKey = privateKey.publicKey

            // Store private key in Keychain
            try KeychainHelper.savePrivateKey(privateKey.rawRepresentation, for: keychainID)

            return (publicKey.rawRepresentation, keychainID)

        case .ecdsaP256:
            let privateKey = P256.Signing.PrivateKey()
            let publicKey = privateKey.publicKey

            try KeychainHelper.savePrivateKey(privateKey.rawRepresentation, for: keychainID)

            return (publicKey.compactRepresentation ?? publicKey.rawRepresentation, keychainID)

        case .ecdsaP384:
            let privateKey = P384.Signing.PrivateKey()
            let publicKey = privateKey.publicKey

            try KeychainHelper.savePrivateKey(privateKey.rawRepresentation, for: keychainID)

            return (publicKey.compactRepresentation ?? publicKey.rawRepresentation, keychainID)

        case .rsa2048, .rsa4096:
            // RSA key generation requires SecKey APIs
            let keyPair = try generateRSAKeyPair(bits: type.bitSize)
            try KeychainHelper.savePrivateKey(keyPair.privateKey, for: keychainID)
            return (keyPair.publicKey, keychainID)
        }
    }

    // MARK: - Key Loading

    func loadNIOSSHPrivateKey(keychainID: String, type: SSHKeyType) throws -> NIOSSHPrivateKey {
        let keyData = try KeychainHelper.getPrivateKey(for: keychainID)

        switch type {
        case .ed25519:
            let privateKey = try Curve25519.Signing.PrivateKey(rawRepresentation: keyData)
            return NIOSSHPrivateKey(ed25519Key: privateKey)

        case .ecdsaP256:
            let privateKey = try P256.Signing.PrivateKey(rawRepresentation: keyData)
            return NIOSSHPrivateKey(p256Key: privateKey)

        case .ecdsaP384:
            let privateKey = try P384.Signing.PrivateKey(rawRepresentation: keyData)
            return NIOSSHPrivateKey(p384Key: privateKey)

        case .rsa2048, .rsa4096:
            // RSA keys need special handling with SecKey
            throw KeyManagerError.unsupportedKeyType
        }
    }

    // MARK: - Public Key Export

    func exportPublicKeyOpenSSH(publicKeyData: Data, type: SSHKeyType, comment: String = "") -> String {
        let keyTypeString: String
        switch type {
        case .ed25519: keyTypeString = "ssh-ed25519"
        case .ecdsaP256: keyTypeString = "ecdsa-sha2-nistp256"
        case .ecdsaP384: keyTypeString = "ecdsa-sha2-nistp384"
        case .rsa2048, .rsa4096: keyTypeString = "ssh-rsa"
        }

        let base64Key = publicKeyData.base64EncodedString()
        let commentSuffix = comment.isEmpty ? "" : " \(comment)"
        return "\(keyTypeString) \(base64Key)\(commentSuffix)"
    }

    // MARK: - Key Deletion

    func deleteKeyPair(keychainID: String) throws {
        try KeychainHelper.deletePrivateKey(for: keychainID)
    }

    // MARK: - RSA Key Generation (via SecKey)

    private func generateRSAKeyPair(bits: Int) throws -> (publicKey: Data, privateKey: Data) {
        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecAttrKeySizeInBits as String: bits,
        ]

        var error: Unmanaged<CFError>?
        guard let privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
            throw error?.takeRetainedValue() ?? KeyManagerError.keyGenerationFailed
        }

        guard let publicKey = SecKeyCopyPublicKey(privateKey) else {
            throw KeyManagerError.keyGenerationFailed
        }

        guard let privateKeyData = SecKeyCopyExternalRepresentation(privateKey, &error) as Data?,
              let publicKeyData = SecKeyCopyExternalRepresentation(publicKey, &error) as Data? else {
            throw error?.takeRetainedValue() ?? KeyManagerError.keyGenerationFailed
        }

        return (publicKeyData, privateKeyData)
    }
}

enum KeyManagerError: LocalizedError {
    case keyGenerationFailed
    case unsupportedKeyType
    case importFailed

    var errorDescription: String? {
        switch self {
        case .keyGenerationFailed: return "Failed to generate key pair"
        case .unsupportedKeyType: return "Unsupported key type"
        case .importFailed: return "Failed to import key"
        }
    }
}
