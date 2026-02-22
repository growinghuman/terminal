import Foundation
import NIO
import NIOSSH

extension ByteBuffer {
    /// Writes an SSH public key to the buffer for serialization
    mutating func writeSSHHostKey(_ key: NIOSSHPublicKey) {
        // Simple serialization by converting key description to bytes
        let description = String(describing: key)
        self.writeString(description)
    }
}
