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
    case Debug = 7
    case Info = 6
    case Warn = 5
    case Error = 4
    case Fatal = 3
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
}

// XXX documentation
public class Logger {

    private var appenders: [LogAppender] = []

    init() {
        self.appenders = [PrintAppender()]
    }

    init(parent: Logger) {
        self.appenders = [parent]
    }

    public func addAppender(_ appender: LogAppender) {
        appenders.append(appender)
    }
}

/// MARK: Logging functions
extension Logger {
    public func info(_ msg: String, _ fields: [String: Any] = [:]) {
        log(level: .Info, msg: msg, fields: fields)
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

extension Logger: LogAppender {
    public func append(_ event: LogEvent) {
        for appender in appenders {
            appender.append(event)
        }
    }
}


// The root logger
let rootLogger = Logger()

public func getLogger() -> Logger {
    return Logger(parent: rootLogger)
}