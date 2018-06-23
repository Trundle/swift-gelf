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

public enum LogLevel: Int {
    case Debug = 7
    case Info = 6
    case Warn = 5
    case Error = 4
    case Fatal = 3
}

public struct LogEvent {
    let timestamp: Double
    let level: LogLevel
    let shortMessage: String
    let fields: [String: Any]
}
