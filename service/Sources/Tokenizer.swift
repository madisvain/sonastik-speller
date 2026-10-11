/* SPDX-License-Identifier: LGPL-2.1-or-later
 * Copyright (c) 2026 Madis Väin
 */
import Foundation

/// Maximal runs of Unicode letters. Digits, hyphens, and punctuation split words.
enum Tokenizer {
    struct Word: Equatable {
        var text: String
        var range: NSRange
    }

    static func words(in text: String) -> [Word] {
        var words: [Word] = []
        var index = text.startIndex
        while index < text.endIndex {
            while index < text.endIndex, !text[index].isLetter {
                index = text.index(after: index)
            }
            if index == text.endIndex {
                break
            }
            let start = index
            while index < text.endIndex, text[index].isLetter {
                index = text.index(after: index)
            }
            let location = text.utf16.distance(from: text.startIndex, to: start)
            let length = text.utf16.distance(from: start, to: index)
            words.append(Word(
                text: String(text[start..<index]),
                range: NSRange(location: location, length: length)))
        }
        return words
    }
}
