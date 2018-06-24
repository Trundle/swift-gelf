import XCTest

#if !os(macOS)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(GELFTests.allTests),
        testCase(ThresholdFilterTests.allTests),
        testCase(LoggerTests.allTests),
    ]
}
#endif