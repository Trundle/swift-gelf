// Copyright 2018 Andreas Stührk <andy@hammerhartes.de>
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation
import NIO
import NIOConcurrencyHelpers

// MARK: GelfValue - a value in a GELF messages
// Work around Codabale's ability to operate with generic JSON values

/// A value in a GELF message. Note that GELF messages don't have nested fields or arrays.
enum GelfValue: Equatable {
    case string(String)
    case number(Double)
}

extension GelfValue {
    init(_ value: Double) {
        self = .number(value)
    }

    init(_ value: Float) {
        self = .number(Double(value))
    }

    init(_ value: Int) {
        self = .number(Double(value))
    }

    init(_ value: String) {
        self = .string(value)
    }
}

extension GelfValue: ExpressibleByIntegerLiteral {
    typealias IntegerLiteralType = Int

    init(integerLiteral value: IntegerLiteralType) {
        self = .number(Double(value))
    }
}

extension GelfValue: ExpressibleByFloatLiteral {
    init(floatLiteral value: Float) {
        self = .number(Double(value))
    }
}

extension GelfValue: ExpressibleByStringLiteral {
    init(stringLiteral value: String) {
        self = .string(value)
    }
}

extension GelfValue: Codable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case let .string(value):
            try container.encode(value)
        case let .number(value):
            try container.encode(value)
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let number = try? container.decode(Double.self) {
            self = .number(number)
        } else if let string = try? container.decode(String.self) {
            self = .string(string)
        } else {
            throw DecodingError.dataCorrupted(
                    .init(codingPath: decoder.codingPath,
                            debugDescription: "Unexpected (or even invalid) JSON value.")
            )
        }
    }
}

// MARK: Encoder

/// Writes the message delimiter (a null byte).
final class GelfMessageDelimiter: ChannelOutboundHandler {
    typealias OutboundIn = ByteBuffer
    typealias OutboundOut = ByteBuffer

    func write(ctx: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
        var buf = self.unwrapOutboundIn(data)
        buf.write(staticString: "\0")
        ctx.write(self.wrapOutboundOut(buf), promise: promise)
    }
}

final class GelfEncoder: MessageToByteEncoder {
    typealias OutboundIn = LogEvent

    private let encoder: JSONEncoder = JSONEncoder()
    private let host: String
    private let facility: String
    private let additionalFields: [String: GelfValue]

    init(host: String, facility: String, additionalFields: [String: Any] = [:]) {
        self.host = host
        self.facility = facility
        var gelfAdditionalFields: [String: GelfValue] = [:]
        for (name, value) in additionalFields {
            gelfAdditionalFields["_" + name] = GelfEncoder.toGelfValue(value)
        }
        self.additionalFields = gelfAdditionalFields
    }

    func encode(ctx: ChannelHandlerContext, data: OutboundIn, out: inout ByteBuffer) throws {
        let gelfMessage = toGelfMessage(data)
        let encoded = try encoder.encode(gelfMessage)
        out.write(bytes: encoded)
    }

    private func toGelfMessage(_ event: LogEvent) -> [String: GelfValue] {
        var gelfMsg: [String: GelfValue] = [
            "version": "1.1",
            "host": GelfValue(self.host),
            "timestamp": GelfValue(event.timestamp.timeIntervalSince1970),
            "level": GelfValue(event.level.rawValue),
            "short_message": GelfValue(event.shortMessage),
            "_facility": GelfValue(self.facility),
        ]
        for (name, value) in event.fields {
            gelfMsg["_" + name] = GelfEncoder.toGelfValue(value)
        }
        gelfMsg.merge(additionalFields, uniquingKeysWith: { (_, new) in new })
        return gelfMsg
    }

    private static func toGelfValue(_ value: Any) -> GelfValue {
        switch value {
        case let string as String:
            return GelfValue(string)
        case let number as Double:
            return GelfValue(number)
        case let number as Float:
            return GelfValue(number)
        case let number as Int:
            return GelfValue(number)
        default:
            return GelfValue(String(describing: value))
        }
    }
}

// MARK: Transport helpers

private class ReconnectInitiator: ChannelInboundHandler {
    typealias InboundIn = ByteBuffer

    let disconnectCallback: () -> Void

    init(disconnectCallback: @escaping () -> Void) {
        self.disconnectCallback = disconnectCallback
    }

    func channelInactive(ctx: ChannelHandlerContext) {
        // XXX replace by logger call
        print("[INFO] GelfAppender: Connection lost")
        disconnectCallback()
    }
}

// MARK: GelfAppender

/// Appends messages to a GELF server
public final class GelfAppender {
    // Buffer where log events are stored in case the appender is not connected
    private var buffer: CircularBuffer<LogEvent> = CircularBuffer(initialRingCapacity: 100)
    private let facility: String
    private let senderHost: String
    private let host: String
    private let port: Int
    private let additionalFields: [String: Any]
    private let reconnectDelay: TimeAmount
    private let maxBufferSize: Int
    private let group: EventLoopGroup
    private var loop: EventLoop!
    private var bootstrap: ClientBootstrap!
    // Invariant: present value means there is an active connection to the GELF server
    private var channel: Channel?
    private var started: Atomic<Bool> = Atomic(value: false)
    private var inFlight: Atomic<Int> = Atomic(value: 0)
    private let maxInFlight: Int
    private var lastMessageSent: EventLoopPromise<Void>!

    public init(group: EventLoopGroup, senderHost: String, facility: String,
                host: String, port: Int = 12201,
                additionalFields: [String: Any] = [:],
                reconnectDelay: TimeAmount = TimeAmount.seconds(1),
                maxBufferSize: Int = 1000,
                maxInFlight: Int = 1000) {
        self.senderHost = senderHost
        self.facility = facility
        self.group = group
        self.host = host
        self.port = port
        self.additionalFields = additionalFields
        self.reconnectDelay = reconnectDelay
        self.maxBufferSize = maxBufferSize
        self.maxInFlight = maxInFlight
    }

    public func start() throws {
        bootstrap = ClientBootstrap(group: group)
                .channelInitializer { channel in
                    channel.pipeline.add(handler: GelfMessageDelimiter()).then {
                        channel.pipeline.add(handler: GelfEncoder(
                                host: self.senderHost, facility: self.facility,
                                additionalFields: self.additionalFields))
                    }.then {
                        channel.pipeline.add(handler: ReconnectInitiator(disconnectCallback: self.initiateReconnect))
                    }
                }
        channel = try bootstrap.connect(host: host, port: port).wait()
        loop = channel!.eventLoop
        lastMessageSent = loop.newPromise()
        started.store(true)
    }

    /// Stops the appender. Waits until all pending messages are sent and then
    /// closes the connection to the GELF server. In case there is no active
    /// connection to the GELF server or the connection is lost, the pending
    /// messages will be discarded.
    public func stop() throws {
        started.store(false)
        if let channel = self.channel {
            self.channel = .none
            if inFlight.load() <= 0 {
                try channel.close().wait()
            } else {
                try self.lastMessageSent.futureResult.then { channel.close() }.wait()
            }
        }
    }

    private func initiateReconnect() {
        guard started.load() else {
            return
        }
        channel = .none
        _ = loop.scheduleTask(in: reconnectDelay) {
            let future = self.bootstrap.connect(host: self.host, port: self.port)
            future.whenSuccess { channel in
                self.channel = .some(channel)
                self.sendBufferedEvents()
            }
            future.whenFailure { error in
                // XXX use logger instead
                print("[WARN] GelfAppender: Could not reconnect: \(error)")
                self.initiateReconnect()
            }
        }
    }

    private func sendBufferedEvents() {
        assert(loop.inEventLoop)
        while case .some(_) = channel, !buffer.isEmpty {
            _ = process(buffer.removeFirst())
        }
    }
}

extension GelfAppender: Stage {
    public func process(_ event: LogEvent) -> LogEvent? {
        if let channel = self.channel {
            guard inFlight.add(1) < self.maxInFlight else {
                self.handleComplete()
                print("[WARN] GelfAppender: Too many messages in flight, dropping", event)
                return event
            }
            let future = channel.writeAndFlush(event)
            future.whenFailure { _ in _ = self.process(event) }
            future.whenComplete(self.handleComplete)
        } else {
            // We are disconnected currently
            loop.execute {
                guard self.buffer.count < self.maxBufferSize else {
                    print("[WARN] GelfAppender: Log buffer over capacity while disconnected, dropping", event)
                    return
                }
                self.buffer.append(event)
            }
        }
        return event
    }

    private func handleComplete() {
        // Note that the previous value is returned, hence the comparison against 1
        if self.inFlight.sub(1) <= 1 && !self.started.load() {
            self.lastMessageSent.succeed(result: ())
        }
    }
}