/* SPDX-License-Identifier: LGPL-2.1-or-later
 * Copyright (c) 2026 Madis Väin
 */
import Foundation

struct SpellServer: Equatable {
    var language: String
    var vendor: String
}

/// The global spelling language System Settings writes when one language is chosen.
struct SpellingPayload: Equatable {
    var language: String
    var vendor: String
    /// `NSSpellCheckerAutomaticallyIdentifiesLanguages`. A menu click turns this off.
    var identifiesLanguagesAutomatically: Bool

    var kbSpellingLanguage: [String: Any] {
        [
            "KB_SpellingLanguage": [language, vendor],
            "KB_SpellingLanguageIsAutomatic": false,
        ]
    }

    static func == (lhs: SpellingPayload, rhs: SpellingPayload) -> Bool {
        lhs.language == rhs.language
            && lhs.vendor == rhs.vendor
            && lhs.identifiesLanguagesAutomatically == rhs.identifiesLanguagesAutomatically
    }
}

enum SpellingLanguage {
    static let estonian = SpellServer(language: "et", vendor: "Sonastik")
    static let fallbackEnglish = SpellServer(language: "en_GB", vendor: "Apple")

    static func isEstonian(_ languageCode: String) -> Bool {
        languageCode == "et" || languageCode.hasPrefix("et_") || languageCode.hasPrefix("et-")
    }

    static func isEnglish(_ languageCode: String) -> Bool {
        languageCode == "en" || languageCode.hasPrefix("en_") || languageCode.hasPrefix("en-")
    }

    /// `ET` or `EN` for the status item. Any other code is shown as itself.
    static func statusTitle(for languageCode: String?) -> String {
        guard let languageCode, !languageCode.isEmpty else { return "—" }
        if isEstonian(languageCode) { return "ET" }
        if isEnglish(languageCode) { return "EN" }
        return languageCode
    }

    /// The first English pair in the Set Up list, or British English from Apple.
    static func englishServer(preferredServers: [[String]]) -> SpellServer {
        for pair in preferredServers where pair.count >= 2 {
            if isEnglish(pair[0]) {
                return SpellServer(language: pair[0], vendor: pair[1])
            }
        }
        return fallbackEnglish
    }

    static func payload(for server: SpellServer) -> SpellingPayload {
        SpellingPayload(
            language: server.language,
            vendor: server.vendor,
            identifiesLanguagesAutomatically: false)
    }

    /// Keep every vendor the user already chose, and pin Estonian to Sonastik.
    static func mergedVendors(_ existing: [String: String]) -> [String: String] {
        var vendors = existing
        vendors["et"] = estonian.vendor
        return vendors
    }
}

enum GlobalSpelling {
    static func currentLanguage() -> String? {
        copy("NSPreferredSpellServerLanguage") as? String
    }

    static func preferredServers() -> [[String]] {
        guard let rows = copy("NSPreferredSpellServers") as? [Any] else { return [] }
        return rows.compactMap { row in
            guard let pair = row as? [Any], pair.count >= 2,
                  let language = pair[0] as? String,
                  let vendor = pair[1] as? String else { return nil }
            return [language, vendor]
        }
    }

    static func vendors() -> [String: String] {
        guard let raw = copy("NSPreferredSpellServerVendors") as? [String: Any] else { return [:] }
        var vendors: [String: String] = [:]
        for (language, vendor) in raw {
            if let vendor = vendor as? String {
                vendors[language] = vendor
            }
        }
        return vendors
    }

    /// Writes the global domain, the same keys System Settings writes. This does
    /// not notify apps that already have a document open.
    static func apply(_ payload: SpellingPayload) {
        let vendors = SpellingLanguage.mergedVendors(vendors())
        set("NSPreferredSpellServerLanguage", payload.language as CFString)
        set(
            "NSSpellCheckerAutomaticallyIdentifiesLanguages",
            payload.identifiesLanguagesAutomatically ? kCFBooleanTrue : kCFBooleanFalse)
        set("KB_SpellingLanguage", payload.kbSpellingLanguage as CFDictionary)
        set("NSPreferredSpellServerVendors", vendors as CFDictionary)
        CFPreferencesAppSynchronize(kCFPreferencesAnyApplication)
    }

    private static func copy(_ key: String) -> CFPropertyList? {
        CFPreferencesCopyAppValue(key as CFString, kCFPreferencesAnyApplication)
    }

    private static func set(_ key: String, _ value: CFPropertyList) {
        CFPreferencesSetAppValue(key as CFString, value, kCFPreferencesAnyApplication)
    }
}
