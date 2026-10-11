/* SPDX-License-Identifier: LGPL-2.1-or-later
 * Copyright (c) 2026 Madis Väin
 */
import XCTest
@testable import TestHost

final class TokenizerTests: XCTestCase {
    func testRanges() {
        XCTAssertEqual(
            Tokenizer.words(in: "tere maailm"),
            [
                Tokenizer.Word(text: "tere", range: NSRange(location: 0, length: 4)),
                Tokenizer.Word(text: "maailm", range: NSRange(location: 5, length: 6)),
            ])
        XCTAssertEqual(
            Tokenizer.words(in: "kõrgaridus"),
            [Tokenizer.Word(text: "kõrgaridus", range: NSRange(location: 0, length: 10))])
        XCTAssertEqual(
            Tokenizer.words(in: "raamatukogu."),
            [Tokenizer.Word(text: "raamatukogu", range: NSRange(location: 0, length: 11))])
        XCTAssertEqual(Tokenizer.words(in: "123"), [])
        XCTAssertEqual(
            Tokenizer.words(in: "õäöüšž"),
            [Tokenizer.Word(text: "õäöüšž", range: NSRange(location: 0, length: 6))])
    }
}
