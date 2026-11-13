import XCTest
@testable import NoSmoke

final class StepInfoTests: XCTestCase {
    func testStepTransitions() {
        let cal = Calendar.current
        let start = cal.date(from: DateComponents(year: 2026, month: 11, day: 13, hour: 7, minute: 30))!
        let plan = [PatchStep(mg: 14, days: 21), PatchStep(mg: 7, days: 14)]
        func at(_ d: Int) -> Date { cal.date(byAdding: .day, value: d, to: start)! }

        XCTAssertEqual(stepInfo(plan: plan, start: start, now: at(0)), StepInfo(index: 0, mg: 14, day: 1, days: 21, left: 21, next: 7))
        XCTAssertEqual(stepInfo(plan: plan, start: start, now: at(21))?.mg, 7)
        XCTAssertEqual(stepInfo(plan: plan, start: start, now: at(21))?.day, 1)
        XCTAssertNil(stepInfo(plan: plan, start: start, now: at(35)))
    }
}
