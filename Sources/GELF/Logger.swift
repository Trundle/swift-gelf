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

/// The GELF-independent parts of the logging API

import Foundation

public enum LogLevel: Int {
    case debug = 7
    case info = 6
    case warn = 5
    case error = 4
    case fatal = 3
}

public struct LogEvent {
    let timestamp: Date
    let level: LogLevel
    let shortMessage: String
    let fields: [String: Any]

    public init(timestamp: Date, level: LogLevel, shortMessage: String, fields: [String: Any]) {
        self.timestamp = timestamp
        self.level = level
        self.shortMessage = shortMessage
        self.fields = fields
    }
}


/// The logger protocol. It's simply a consumer of a LogEvent.
/// Loggers are considered immutable.
public protocol Logger {
    func log(_ event: LogEvent)
}

// MARK: Logging functions
extension Logger {
    public func debug(_ msg: String, _ fields: [String: Any] = [:]) {
        log(level: .debug, msg: msg, fields: fields)
    }

    public func info(_ msg: String, _ fields: [String: Any] = [:]) {
        log(level: .info, msg: msg, fields: fields)
    }

    public func warn(_ msg: String, _ fields: [String: Any] = [:]) {
        log(level: .warn, msg: msg, fields: fields)
    }

    public func error(_ msg: String, _ fields: [String: Any] = [:]) {
        log(level: .error, msg: msg, fields: fields)
    }

    public func fatal(_ msg: String, _ fields: [String: Any] = [:]) {
        log(level: .fatal, msg: msg, fields: fields)
    }

    public func log(level: LogLevel, msg: String, fields: [String: Any]) {
        let event = LogEvent(
                timestamp: Date(),
                level: level,
                shortMessage: msg,
                fields: fields)
        log(event)
    }
}

// MARK: Default implementation of a logger

final class DefaultLogger {
    private let consumer: (LogEvent) -> Void

    init(consumer: @escaping (LogEvent) -> Void) {
        self.consumer = consumer
    }
}
extension DefaultLogger: Logger {
    func log(_ event: LogEvent) {
        consumer(event)
    }
}

// MARK: Obtaining loggers
var consumer: (LogEvent) -> () = { _ = PrintAppender().process($0) }

public func getLogger() -> Logger {
    return DefaultLogger(consumer: consumer)
}

public func configureLogging<A>(pipeline: Pipeline<LogEvent, A>) {
    consumer = { _ = pipeline.process($0) }
}
