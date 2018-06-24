import Foundation
import NIO
import NIOFoundationCompat
import XCTest

@testable import GELF

final class GELFTests: XCTestCase {
    let decoder: JSONDecoder = JSONDecoder()

    func testEncoder() throws {
        let channel = EmbeddedChannel()
        _ = try channel.pipeline.add(handler: createGelfEncoder()).wait()
        let msg = createLogEvent()
        _ = try channel.writeAndFlush(msg).wait()

        if case .some(.byteBuffer(var buffer)) = channel.readOutbound() {
            guard let json = buffer.readData(length: buffer.readableBytes) else {
                XCTFail("Could not read expected JSON")
                return
            }
            let decoded = try decoder.decode([String: GelfValue].self, from: json)
            XCTAssertEqual("1.1", decoded["version"])
            AssertEqualGelfNumber(1234567.89, decoded["timestamp"])
            XCTAssertEqual("test-sender-host", decoded["host"])
            XCTAssertEqual(6, decoded["level"])
            XCTAssertEqual("The log message", decoded["short_message"])
            XCTAssertEqual("test-facility", decoded["_facility"])
            XCTAssertEqual("string value", decoded["_string"])
            XCTAssertEqual(42, decoded["_number"])
            // Optionals get unpacked
            XCTAssertEqual(42, decoded["_optional"])
            XCTAssertEqual("value", decoded["_static"])
        } else {
            XCTFail("couldn't read ByteBuffer from channel")
        }

        XCTAssertFalse(try channel.finish())
    }

    private func AssertEqualGelfNumber(_ expected: Double, _ actual: GelfValue?, accuracy: Double = 0.0000001) {
        if case let .some(GelfValue.number(value)) = actual {
            XCTAssertEqual(expected, value, accuracy: accuracy)
        } else {
            XCTFail("Expected a GELF number, got \(String(describing: actual)) instead")
        }
    }

    private func createGelfEncoder() -> GelfEncoder {
        return GelfEncoder(host: "test-sender-host", facility: "test-facility",
                additionalFields: ["static": "value"])
    }

    private func createLogEvent() -> LogEvent {
        return LogEvent(
                timestamp: Date(timeIntervalSince1970: 1234567.89),
                level: .Info,
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
