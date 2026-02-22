import Foundation
import SwiftData

@Model
final class SSHKeyPair {
    var id: UUID
    var name: String
    var keyType: SSHKeyType
    var publicKeyData: Data?
    var privateKeyKeychainID: String
    var comment: String?
    var createdAt: Date
    var isDefault: Bool

    init(
        name: String,
        keyType: SSHKeyType,
        publicKeyData: Data? = nil,
        privateKeyKeychainID: String,
        comment: String? = nil,
        isDefault: Bool = false
    ) {
        self.id = UUID()
        self.name = name
        self.keyType = keyType
        self.publicKeyData = publicKeyData
        self.privateKeyKeychainID = privateKeyKeychainID
        self.comment = comment
        self.createdAt = Date()
        self.isDefault = isDefault
    }
}

enum SSHKeyType: String, Codable, CaseIterable, Identifiable {
    case rsa2048
    case rsa4096
    case ed25519
    case ecdsaP256
    case ecdsaP384

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .rsa2048: return "RSA 2048"
        case .rsa4096: return "RSA 4096"
        case .ed25519: return "Ed25519"
        case .ecdsaP256: return "ECDSA P-256"
        case .ecdsaP384: return "ECDSA P-384"
        }
    }

    var bitSize: Int {
        switch self {
        case .rsa2048: return 2048
        case .rsa4096: return 4096
        case .ed25519: return 256
        case .ecdsaP256: return 256
        case .ecdsaP384: return 384
        }
    }
}
