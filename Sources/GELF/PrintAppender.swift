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

/// A log appender that writes to stdout
public class PrintAppender {
    let dateFormatter: DateFormatter = DateFormatter()

    public init() {
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
    }
}

extension PrintAppender: Stage {
    public func process(_ event: LogEvent) -> LogEvent? {
        let when = dateFormatter.string(from: event.timestamp)
        let fields = event.fields.map { (key, value) in "\(key)=\(value)" }.joined(separator: " ")
        print("\(when) \(event.level) \(event.shortMessage) \(fields)")
        return event
    }
}

extension LogLevel: CustomStringConvertible {
    public var description: String {
        switch self {
        case .debug:
            return "[DEBUG]"
        case .info:
            return "[INFO]"
        case .warn:
            return "[WARN]"
        case .error:
            return "[ERR]"
        case .fatal:
            return "[FATAL]"
        }
    }
}