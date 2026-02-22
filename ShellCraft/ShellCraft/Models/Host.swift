import Foundation
import SwiftData

@Model
final class Host {
    var id: UUID
    var name: String
    var hostname: String
    var port: Int
    var username: String
    var authMethod: AuthMethod
    var group: String?
    var terminalThemeID: String?
    var fontSize: Int
    var environmentVariablesData: Data
    var keepAliveInterval: Int
    var createdAt: Date
    var updatedAt: Date
    var lastConnectedAt: Date?
    var isFavorite: Bool
    var notes: String?

    init(
        name: String,
        hostname: String,
        port: Int = 22,
        username: String = "root",
        authMethod: AuthMethod = .password,
        group: String? = nil,
        terminalThemeID: String? = nil,
        fontSize: Int = 14,
        environmentVariables: [String: String] = [:],
        keepAliveInterval: Int = 60,
        notes: String? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.hostname = hostname
        self.port = port
        self.username = username
        self.authMethod = authMethod
        self.group = group
        self.terminalThemeID = terminalThemeID
        self.fontSize = fontSize
        self.environmentVariablesData = (try? JSONEncoder().encode(environmentVariables)) ?? Data()
        self.keepAliveInterval = keepAliveInterval
        self.createdAt = Date()
        self.updatedAt = Date()
        self.isFavorite = false
        self.notes = notes
    }

    var environmentVariables: [String: String] {
        get {
            (try? JSONDecoder().decode([String: String].self, from: environmentVariablesData)) ?? [:]
        }
        set {
            environmentVariablesData = (try? JSONEncoder().encode(newValue)) ?? Data()
        }
    }

    var displayAddress: String {
        if port == 22 {
            return "\(username)@\(hostname)"
        }
        return "\(username)@\(hostname):\(port)"
    }
}

enum AuthMethod: String, Codable, CaseIterable, Identifiable {
    case password
    case publicKey
    case certificate

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .password: return "Password"
        case .publicKey: return "Public Key"
        case .certificate: return "Certificate"
        }
    }

    var iconName: String {
        switch self {
        case .password: return "key.fill"
        case .publicKey: return "lock.shield.fill"
        case .certificate: return "checkmark.seal.fill"
        }
    }
}
