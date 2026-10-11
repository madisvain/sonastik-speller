/* SPDX-License-Identifier: LGPL-2.1-or-later
 * Copyright (c) 2026 Madis Väin
 */
import XCTest
@testable import TestHost

final class DelegateTests: XCTestCase {
    private func delegate() -> SpellServerDelegate {
        SpellServerDelegate(engine: VabamorfEngine(dictionaryPath: Fixture.dictionaryPath))
    }

    func testMisspelledRangeAndWordCount() {
        let text = "tere raamtukogu"
        var count = 0
        let range = delegate().spellServer(
            NSSpellServer(),
            findMisspelledWordIn: text,
            language: "et",
            wordCount: &count,
            countOnly: false)
        XCTAssertEqual((text as NSString).substring(with: range), "raamtukogu")
        XCTAssertEqual(count, 2)
    }

    func testSentenceCapitalIsAccepted() {
        var count = 0
        let range = delegate().spellServer(
            NSSpellServer(),
            findMisspelledWordIn: "Tere",
            language: "et",
            wordCount: &count,
            countOnly: false)
        XCTAssertEqual(range.location, NSNotFound)
        XCTAssertEqual(count, 1)
    }

    func testCountOnlySkipsTheEngine() {
        var count = 0
        let range = delegate().spellServer(
            NSSpellServer(),
            findMisspelledWordIn: "tere raamtukogu",
            language: "et",
            wordCount: &count,
            countOnly: true)
        XCTAssertEqual(range.location, NSNotFound)
        XCTAssertEqual(count, 2)
    }

    func testSpellMethodsAreVisibleToAppKit() {
        let checker = delegate()
        XCTAssertTrue(checker.responds(to: Selector((
            "spellServer:findMisspelledWordInString:language:wordCount:countOnly:"))))
        XCTAssertTrue(checker.responds(to: Selector((
            "spellServer:suggestGuessesForWord:inLanguage:"))))
    }
}
