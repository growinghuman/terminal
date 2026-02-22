import Foundation
import NIO
import NIOSSH

/// Handles data flowing through an SSH shell channel
final class SSHShellHandler: ChannelDuplexHandler {
    typealias InboundIn = SSHChannelData
    typealias InboundOut = ByteBuffer
    typealias OutboundIn = ByteBuffer
    typealias OutboundOut = SSHChannelData

    var onData: ((Data) -> Void)?

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let channelData = unwrapInboundIn(data)

        guard case .byteBuffer(let buffer) = channelData.data else {
            return
        }

        // Forward to terminal emulator
        if let bytes = buffer.getBytes(at: buffer.readerIndex, length: buffer.readableBytes) {
            let data = Data(bytes)
            onData?(data)
        }

        context.fireChannelRead(wrapInboundOut(buffer))
    }

    func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
        let buffer = unwrapOutboundIn(data)
        let channelData = SSHChannelData(
            type: .channel,
            data: .byteBuffer(buffer)
        )
        context.write(wrapOutboundOut(channelData), promise: promise)
    }

    func channelInactive(context: ChannelHandlerContext) {
        context.fireChannelInactive()
    }

    func errorCaught(context: ChannelHandlerContext, error: Error) {
        context.fireErrorCaught(error)
    }
}

/// Handles data from exec (single command) channels
final class SSHExecHandler: ChannelDuplexHandler {
    typealias InboundIn = SSHChannelData
    typealias InboundOut = ByteBuffer
    typealias OutboundIn = ByteBuffer
    typealias OutboundOut = SSHChannelData

    private var outputBuffer = Data()
    var onComplete: ((Data) -> Void)?
    var onData: ((Data) -> Void)?

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let channelData = unwrapInboundIn(data)

        guard case .byteBuffer(let buffer) = channelData.data else {
            return
        }

        if let bytes = buffer.getBytes(at: buffer.readerIndex, length: buffer.readableBytes) {
            let data = Data(bytes)
            outputBuffer.append(data)
            onData?(data)
        }

        context.fireChannelRead(wrapInboundOut(buffer))
    }

    func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
        let buffer = unwrapOutboundIn(data)
        let channelData = SSHChannelData(
            type: .channel,
            data: .byteBuffer(buffer)
        )
        context.write(wrapOutboundOut(channelData), promise: promise)
    }

    func channelInactive(context: ChannelHandlerContext) {
        onComplete?(outputBuffer)
        context.fireChannelInactive()
    }
}
