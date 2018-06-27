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

// XXX documentation
public protocol LogAppender {
    func append(_ event: LogEvent)
    func start() throws
    func stop() throws
}

// Default implementations for some of the LogAppender methods
extension LogAppender {
    public func start() throws {
        // Do nothing
    }

    public func stop() throws {
        // Do nothing
    }
}

/// A convenient base class for implementors of `LogAppender`.
public class LogAppenderBase {

    var filters: [EventFilter] = []

    public func addFilter(_ filter: EventFilter) {
        filters.append(filter)
    }

    /// Called after checking against an event against all filters.
    /// Should do the actual appending.
    func doAppend(_ event: LogEvent) {
    }
}

extension LogAppenderBase: LogAppender {
    public func append(_ event: LogEvent) {
        if filters.allSatisfy({ $0.shouldBeKept(event) }) {
            doAppend(event)
        }
    }
}

// MARK: Filters

public protocol EventFilter {
    func shouldBeKept(_ event: LogEvent) -> Bool
}

/// Filters log events based on their level
public final class ThresholdFilter {
    private let thresholdLevel: LogLevel

    public init(thresholdLevel: LogLevel) {
        self.thresholdLevel = thresholdLevel
    }
}

extension ThresholdFilter: EventFilter {
    public func shouldBeKept(_ event: LogEvent) -> Bool {
        return event.level.rawValue <= thresholdLevel.rawValue
    }
}

/// An object that allows adding events ("log messages") to the logging
/// system. Typically the main touch point for application code to the
/// logging system.
/// Every event can be enriched with arbitrary key-value pairs that will
/// be reported together with the event (also known as structured logging).
public final class Logger: LogAppenderBase {

    private var appenders: [LogAppender] = []

    init(appenders: [LogAppender]) {
        self.appenders = appenders
    }

    init(parent: Logger) {
        self.appenders = [parent]
    }

    public func addAppender(_ appender: LogAppender) {
        appenders.append(appender)
    }

    override func doAppend(_ event: LogEvent) {
        for appender in appenders {
            appender.append(event)
        }
    }
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
        append(event)
    }
}

// MARK: Helpers

#if !swift(>=4.2)
extension Sequence {
    func allSatisfy(_ predicate: (Element) -> Bool) -> Bool {
        for element in self {
            guard predicate(element) else {
                return false
            }
        }
        return true
    }
}
#endif


// MARK: Obtaining loggers

// The root logger
let rootLogger = Logger(appenders: [PrintAppender()])

public func getLogger() -> Logger {
    return Logger(parent: rootLogger)
}
