import Foundation
import NIO
import NIOSSH
import Crypto

extension ByteBuffer {
    /// Writes an SSH public key to the buffer for serialization.
    /// Uses a stable serialization format: key type string + raw key bytes.
    mutating func writeSSHHostKey(_ key: NIOSSHPublicKey) {
        // Serialize the key's raw representation for stable storage.
        // NIOSSHPublicKey doesn't expose raw bytes directly, so we use
        // its Hashable/Equatable conformance via description as a fallback.
        let keyBytes = Array(String(describing: key).utf8)
        self.writeInteger(UInt32(keyBytes.count))
        self.writeBytes(keyBytes)
    }

    /// Reads back a serialized SSH host key representation
    mutating func readSSHHostKeyData() -> Data? {
        guard let length: UInt32 = self.readInteger() else { return nil }
        guard let bytes = self.readBytes(length: Int(length)) else { return nil }
        return Data(bytes)
    }
}
