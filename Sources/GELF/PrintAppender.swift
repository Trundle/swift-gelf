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
class PrintAppender {
    let dateFormatter: DateFormatter = DateFormatter()

    init() {
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
    }
}

extension PrintAppender: LogAppender {

    func append(_ event: LogEvent) {
        let level = PrintAppender.levelRepresentation(event.level)
        let when = dateFormatter.string(from: event.timestamp)
        let fields = event.fields.map { (key, value) in "\(key)=\(value)" }.joined(separator: " ")
        print("\(when) \(level) \(event.shortMessage) \(fields)")
    }

    private static func levelRepresentation(_ level: LogLevel) -> String {
        switch level {
        case .Debug:
            return "[DEBUG]"
        case .Info:
            return "[INFO]"
        case .Warn:
            return "[WARN]"
        case .Error:
            return "[ERR]"
        case .Fatal:
            return "[FATAL]"
        }
    }
}