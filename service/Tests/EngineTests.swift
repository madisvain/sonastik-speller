/* SPDX-License-Identifier: LGPL-2.1-or-later
 * Copyright (c) 2026 Madis Väin
 */
import XCTest
@testable import TestHost

final class EngineTests: XCTestCase {
    func testKnownWordAndSuggestion() {
        let path = Fixture.dictionaryPath
        XCTAssertFalse(path.isEmpty, "et.dct is missing from the test host bundle")
        let engine = VabamorfEngine(dictionaryPath: path)
        XCTAssertTrue(engine.isCorrect("tere"), path)
        XCTAssertEqual(engine.suggestions(for: "raamtukogu").first, "raamatukogu")
    }
}
