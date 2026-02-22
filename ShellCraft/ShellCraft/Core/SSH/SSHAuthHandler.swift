import Foundation
import NIO
import NIOSSH
import Crypto

/// Handles SSH password authentication
final class PasswordAuthDelegate: NIOSSHClientUserAuthenticationDelegate {
    private let username: String
    private let password: String

    init(username: String, password: String) {
        self.username = username
        self.password = password
    }

    func nextAuthenticationType(
        availableMethods: NIOSSHAvailableUserAuthenticationMethods,
        nextChallengePromise: EventLoopPromise<NIOSSHUserAuthenticationOffer?>
    ) {
        if availableMethods.contains(.password) {
            nextChallengePromise.succeed(
                .init(
                    username: username,
                    serviceName: "ssh-connection",
                    offer: .password(.init(password: password))
                )
            )
        } else {
            nextChallengePromise.succeed(nil)
        }
    }
}

/// Handles SSH public key authentication
final class PublicKeyAuthDelegate: NIOSSHClientUserAuthenticationDelegate {
    private let username: String
    private let privateKey: NIOSSHPrivateKey

    init(username: String, privateKey: NIOSSHPrivateKey) {
        self.username = username
        self.privateKey = privateKey
    }

    func nextAuthenticationType(
        availableMethods: NIOSSHAvailableUserAuthenticationMethods,
        nextChallengePromise: EventLoopPromise<NIOSSHUserAuthenticationOffer?>
    ) {
        if availableMethods.contains(.publicKey) {
            nextChallengePromise.succeed(
                .init(
                    username: username,
                    serviceName: "ssh-connection",
                    offer: .privateKey(.init(privateKey: privateKey))
                )
            )
        } else {
            nextChallengePromise.succeed(nil)
        }
    }
}

/// Accepts all server host keys (for initial implementation)
/// TODO: Implement known_hosts verification
final class AcceptAllHostKeysDelegate: NIOSSHClientServerAuthenticationDelegate {
    func validateHostKey(
        hostKey: NIOSSHPublicKey,
        validationCompletePromise: EventLoopPromise<Void>
    ) {
        // Accept all host keys for now
        // In production, compare against known_hosts
        validationCompletePromise.succeed(())
    }
}

/// Validates host keys against a known hosts store
final class KnownHostsDelegate: NIOSSHClientServerAuthenticationDelegate {
    private let knownHosts: KnownHostsStore
    private let hostname: String
    private let port: Int

    var onUnknownHost: ((NIOSSHPublicKey) async -> Bool)?

    init(knownHosts: KnownHostsStore, hostname: String, port: Int) {
        self.knownHosts = knownHosts
        self.hostname = hostname
        self.port = port
    }

    func validateHostKey(
        hostKey: NIOSSHPublicKey,
        validationCompletePromise: EventLoopPromise<Void>
    ) {
        let result = knownHosts.verify(host: hostname, port: port, key: hostKey)
        switch result {
        case .trusted:
            validationCompletePromise.succeed(())
        case .changed:
            validationCompletePromise.fail(SSHError.authenticationFailed)
        case .unknown:
            // For simplicity, accept and store unknown hosts
            knownHosts.addHost(hostname, port: port, key: hostKey)
            validationCompletePromise.succeed(())
        }
    }
}
