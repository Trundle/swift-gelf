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

final class GelfEncoder: MessageToByteEncoder {
    typealias OutboundIn = LogEvent

    private let encoder: JSONEncoder = JSONEncoder()

    func encode(ctx: ChannelHandlerContext, data: OutboundIn, out: inout ByteBuffer) throws {
        let gelfMessage = toGelfMessage(data)
        let encoded = try encoder.encode(gelfMessage)
        out.write(bytes: encoded)
        out.write(staticString: "\0")
    }

    private func toGelfMessage(_ event: LogEvent) -> [String: GelfValue] {
        var gelfMsg: [String: GelfValue] = [
            "version": "1.1",
            "timestamp": GelfValue(event.timestamp),
            "level": GelfValue(event.level.rawValue),
            "short_message": GelfValue(event.shortMessage),
        ]
        for (name, value) in event.fields {
            var gelfValue: GelfValue
            switch value {
            case let string as String:
                gelfValue = GelfValue(string)
            case let number as Double:
                gelfValue = GelfValue(number)
            case let number as Float:
                gelfValue = GelfValue(number)
            case let number as Int:
                gelfValue = GelfValue(number)
            case let debugConvertible as CustomDebugStringConvertible:
                gelfValue = GelfValue(debugConvertible.debugDescription)
            default:
                gelfValue = GelfValue(Mirror(reflecting: value).description)
            }
            gelfMsg["_" + name] = gelfValue
        }
        return gelfMsg
    }
}

// MARK: GelfAppender

/// Appends messages to a GELF server
public final class GelfAppender {

    private let bootstrap: ClientBootstrap
    private let host: String
    private let port: Int
    private var channel: Channel?

    init(group: EventLoopGroup, host: String, port: Int = 12201) {
        self.host = host
        self.port = port
        self.bootstrap = ClientBootstrap(group: group)
        .channelInitializer { channel in
            channel.pipeline.add(handler: GelfEncoder())
        }
    }

    public func start() throws {
        channel = try bootstrap.connect(host: host, port: port).wait()
    }

    public func stop() throws {
        try channel?.close().wait()
        channel = .none
    }
}