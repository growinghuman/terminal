import Foundation
import NIO
import NIOSSH
import Crypto

extension ByteBuffer {
    /// Writes an SSH public key to the buffer using its wire format representation.
    /// NIOSSHPublicKey's write(to:) produces the standard SSH wire format,
    /// which is stable and suitable for persistent storage.
    mutating func writeSSHHostKey(_ key: NIOSSHPublicKey) {
        key.write(to: &self)
    }

    /// Reads back a serialized SSH host key.
    mutating func readSSHHostKey() -> NIOSSHPublicKey? {
        return try? NIOSSHPublicKey(from: &self)
    }

    /// Reads raw bytes as Data with a length prefix and bounds validation.
    mutating func readSSHHostKeyData() -> Data? {
        guard let length: UInt32 = self.readInteger() else { return nil }
        // Prevent allocation of unreasonably large buffers (max 64KB for a key)
        guard length > 0, length <= 65536 else { return nil }
        guard let bytes = self.readBytes(length: Int(length)) else { return nil }
        return Data(bytes)
    }
}
