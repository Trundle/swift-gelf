import Foundation
import NIO
import NIOFoundationCompat
import XCTest

@testable import GELF

final class GELFTests: XCTestCase {
    let decoder: JSONDecoder = JSONDecoder()

    func testEncoder() throws {
        let channel = EmbeddedChannel()
        _ = try channel.pipeline.add(handler: GelfEncoder()).wait()
        let msg = createLogEvent()
        _ = try channel.writeAndFlush(msg).wait()

        if case .some(.byteBuffer(var buffer)) = channel.readOutbound() {
            guard let json = buffer.readData(length: buffer.readableBytes - 1) else {
                XCTFail("Could not read expected JSON")
                return
            }
            let decoded = try decoder.decode([String: GelfValue].self, from: json)
            XCTAssertEqual(GelfValue("1.1"), decoded["version"])
            XCTAssertEqual(GelfValue(1234567.89), decoded["timestamp"])
            XCTAssertEqual(GelfValue(6), decoded["level"])
            XCTAssertEqual(GelfValue("The log message"), decoded["short_message"])
            XCTAssertEqual(GelfValue("string value"), decoded["_string"])
            XCTAssertEqual(GelfValue(42), decoded["_number"])
            // Optionals get unpacked
            XCTAssertEqual(GelfValue(42), decoded["_optional"])

            let byte = buffer.readBytes(length: 1)
            XCTAssertEqual([UInt8(0)], byte)
        } else {
            XCTFail("couldn't read ByteBuffer from channel")
        }

        XCTAssertFalse(try channel.finish())
    }

    private func createLogEvent() -> LogEvent {
        return LogEvent(
                timestamp: 1234567.89, level: .Info,
                shortMessage: "The log message",
                fields: [
                    "string": "string value",
                    "number": 42,
                    "optional": Optional.some(42) as Any,
                ])
    }

    static var allTests = [
        ("testEncoder", testEncoder),
    ]
}
