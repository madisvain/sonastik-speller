/* SPDX-License-Identifier: LGPL-2.1-or-later
 * Copyright (c) 2026 Madis Väin
 *
 * Vabamorf is not thread-safe. Every vm_* call stays on `queue`.
 */
import Foundation
import os

final class VabamorfEngine {
    static let cacheCapacity = 10_000

    static var version: String {
        String(cString: vm_version())
    }

    let dictionaryPath: String

    private let queue = DispatchQueue(label: "ee.madisvain.estonianspeller.engine")
    private let logger = Logger(subsystem: "ee.madisvain.estonianspeller", category: "engine")
    private var speller: OpaquePointer?
    private var spellCache = LRUCache<Bool>(capacity: cacheCapacity)
    private var suggestCache = LRUCache<[String]>(capacity: cacheCapacity)

    init(dictionaryPath: String) {
        self.dictionaryPath = dictionaryPath
        queue.sync {
            openLocked()
        }
    }

    deinit {
        queue.sync {
            vm_close(speller)
            speller = nil
        }
    }

    /// True when the dictionary is closed: a failed open reports no misspellings.
    func isCorrect(_ word: String) -> Bool {
        queue.sync {
            guard speller != nil else {
                return true
            }
            if let cached = spellCache.value(for: word) {
                return cached
            }
            let status = spellLocked(word)
            guard status >= 0 else {
                logger.error("vm_spell failed")
                return true
            }
            let correct = status == 1
            spellCache.insert(correct, for: word)
            return correct
        }
    }

    func suggestions(for word: String) -> [String] {
        queue.sync {
            guard speller != nil else {
                return []
            }
            if let cached = suggestCache.value(for: word) {
                return cached
            }
            guard let list = suggestLocked(word) else {
                return []
            }
            suggestCache.insert(list, for: word)
            return list
        }
    }

    private func openLocked() {
        var err: UnsafeMutablePointer<CChar>?
        let opened = dictionaryPath.withCString { vm_open($0, &err) }
        guard let opened else {
            let message = err.map { pointer -> String in
                defer { free(pointer) }
                return String(cString: pointer)
            } ?? "cannot open dictionary"
            logger.error("dictionary open failed: \(message, privacy: .public) path \(self.dictionaryPath, privacy: .public)")
            return
        }
        speller = opened
    }

    private func spellLocked(_ word: String) -> Int32 {
        guard let speller else {
            return -1
        }
        return word.withCString { vm_spell(speller, $0) }
    }

    /// Nil means the call failed and must not be cached. An empty array is a real result.
    private func suggestLocked(_ word: String) -> [String]? {
        guard let speller else {
            return []
        }
        var list: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?
        var count: Int32 = 0
        let status = word.withCString { vm_suggest(speller, $0, &list, &count) }
        defer { vm_free_suggestions(list, count) }
        guard status == 0 else {
            logger.error("vm_suggest failed")
            return nil
        }
        guard count > 0, let list else {
            return []
        }
        var words: [String] = []
        words.reserveCapacity(Int(count))
        for index in 0..<Int(count) {
            guard let pointer = list[index] else {
                continue
            }
            words.append(String(cString: pointer))
        }
        return words
    }
}

private struct LRUCache<Value> {
    private var values: [String: Value] = [:]
    private var order: [String] = []
    private let capacity: Int

    init(capacity: Int) {
        self.capacity = capacity
    }

    mutating func value(for key: String) -> Value? {
        guard let found = values[key] else {
            return nil
        }
        moveToEnd(key)
        return found
    }

    mutating func insert(_ value: Value, for key: String) {
        if values[key] == nil {
            order.append(key)
        } else {
            moveToEnd(key)
        }
        values[key] = value
        while order.count > capacity {
            values.removeValue(forKey: order.removeFirst())
        }
    }

    private mutating func moveToEnd(_ key: String) {
        guard let index = order.firstIndex(of: key) else {
            return
        }
        order.remove(at: index)
        order.append(key)
    }
}
