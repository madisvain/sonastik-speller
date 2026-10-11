/* SPDX-License-Identifier: LGPL-2.1-or-later
 * Copyright (c) 2026 Madis Väin
 */
import Foundation

/// NSSpellServer keeps its delegate unretained. The caller holds this object.
final class SpellServerDelegate: NSObject, NSSpellServerDelegate {
    let engine: VabamorfEngine

    init(engine: VabamorfEngine) {
        self.engine = engine
        super.init()
    }

    func spellServer(
        _ sender: NSSpellServer,
        findMisspelledWordIn stringToCheck: String,
        language: String,
        wordCount: UnsafeMutablePointer<Int>,
        countOnly: Bool
    ) -> NSRange {
        let words = Tokenizer.words(in: stringToCheck)
        if countOnly {
            wordCount.pointee = words.count
            return NSRange(location: NSNotFound, length: 0)
        }
        for (index, word) in words.enumerated() {
            if !isAccepted(word.text) {
                wordCount.pointee = index + 1
                return word.range
            }
        }
        wordCount.pointee = words.count
        return NSRange(location: NSNotFound, length: 0)
    }

    func spellServer(
        _ sender: NSSpellServer,
        suggestGuessesForWord word: String,
        inLanguage language: String
    ) -> [String]? {
        engine.suggestions(for: word)
    }

    /// A sentence-initial capital is accepted when the lowercased word is.
    private func isAccepted(_ word: String) -> Bool {
        if engine.isCorrect(word) {
            return true
        }
        let folded = word.lowercased()
        return folded != word && engine.isCorrect(folded)
    }
}
