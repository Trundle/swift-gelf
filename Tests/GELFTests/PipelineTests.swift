import XCTest

@testable import GELF

struct ToString {
}
extension ToString: Stage {
    public func process(_ input: Int) -> String? {
        return String(input)
    }
}

struct Doubler {
}
extension Doubler: Stage {
    func process(_ input: String) -> String? {
        return input + input
    }
}

final class PipelineTests: XCTestCase {
    func testSingleStagePipeline() {
        let pipeline = Pipeline(stage: ToString())

        XCTAssertEqual("42", pipeline.process(42))
    }

    func testMultiStagePipeline() {
        let pipeline = Pipeline(stage: ToString()).append(stage: Doubler())

        XCTAssertEqual("4242", pipeline.process(42))
    }

    func testAppendOtherPipeline() {
        let first = Pipeline(stage: ToString()).append(stage: Doubler())
        let other = Pipeline(stage: Doubler())
        let pipeline = first.append(pipeline: other)

        XCTAssertEqual("1111", pipeline.process(1))
    }

    static var allTests = [
        ("testSingleStagePipeline", testSingleStagePipeline),
        ("testMultiStagePipeline", testMultiStagePipeline),
        ("testAppendOtherPipeline", testAppendOtherPipeline),
    ]
}

final class StagesTests: XCTestCase {
    func testIdentity() {
        let identity = IdentityStage<Int>()

        XCTAssertEqual(42, identity.process(42))
    }

    func testBranch() {
        var consumedValue: String? = .none
        let producer: Pipeline<String, String> = Pipeline({ $0 })
        let consumer: Pipeline<String, Void> = Pipeline( { consumedValue = $0 })
        let branch = Branch(producer: producer, consumer)

        let result = branch.process("spam")

        XCTAssertEqual("spam", result)
        XCTAssertEqual("spam", consumedValue)
    }

    static var allTests = [
        ("testIdentity", testIdentity),
        ("testBranch", testBranch),
    ]
}

final class ThresholdFilterTests: XCTestCase {

    private let filter: ThresholdFilter = ThresholdFilter(thresholdLevel: .info)

    func testFiltersLowerLogLevel() {
        let event = createLogEvent(level: .debug)
        XCTAssertNil(filter.process(event))
    }

    func testPassesLogLevel() {
        let event = createLogEvent(level: .info)
        XCTAssertNotNil(filter.process(event))
    }

    private func createLogEvent(level: LogLevel) -> LogEvent {
        return LogEvent(timestamp: Date(), level: level, shortMessage: "some message", fields: [:])
    }

    static var allTests = [
        ("testFiltersLowerLogLevel", testFiltersLowerLogLevel),
        ("testPassesLogLevel", testPassesLogLevel),
    ]
}
