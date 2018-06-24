import XCTest

@testable import GELF

final class ThresholdFilterTests: XCTestCase {

    private let filter: ThresholdFilter = ThresholdFilter(thresholdLevel: .Info)

    func testFiltersLowerLogLevel() {
        let event = createLogEvent(level: .Debug)
        XCTAssertFalse(filter.shouldBeKept(event))
    }

    func testPassesLogLevel() {
        let event = createLogEvent(level: .Info)
        XCTAssertTrue(filter.shouldBeKept(event))
    }

    private func createLogEvent(level: LogLevel) -> LogEvent {
        return LogEvent(timestamp: Date(), level: level, shortMessage: "some message", fields: [:])
    }

    static var allTests = [
        ("testFiltersLowerLogLevel", testFiltersLowerLogLevel),
    ]
}


final class LoggerTests: XCTestCase {

    class TestAppender: LogAppender {
        var timesCalled: Int = 0

        func append(_ event: LogEvent) {
            timesCalled += 1
            XCTAssertEqual(LogLevel.Info, event.level)
            XCTAssertEqual("some message", event.shortMessage)
        }
    }

    func testAppendsToAllAppenders() {
        let firstAppender = TestAppender()
        let secondAppender = TestAppender()
        let logger = Logger(appenders: [firstAppender, secondAppender])

        logger.info("some message")

        XCTAssertEqual(1, firstAppender.timesCalled)
        XCTAssertEqual(1, secondAppender.timesCalled)
    }

    static var allTests = [
        ("testAppendsToAllAppenders", testAppendsToAllAppenders),
    ]
}