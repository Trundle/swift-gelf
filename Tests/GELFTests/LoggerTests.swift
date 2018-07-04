import XCTest

@testable import GELF

class TestLogger {
    var timesCalled: Int = 0
}
extension TestLogger: Logger {
    func log(_ event: LogEvent) {
        timesCalled += 1
    }
}

final class LoggerTests: XCTestCase {

    func testConvenienceMethodsCallLog() {
        let logger = TestLogger()

        logger.info("some message")

        XCTAssertEqual(1, logger.timesCalled)
    }

    static var allTests = [
        ("testConvenienceMethodsCallLog", testConvenienceMethodsCallLog),
    ]
}