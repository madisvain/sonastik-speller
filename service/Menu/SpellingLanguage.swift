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

    /// The Spelling Set Up list, in the user's order. Incomplete rows are skipped.
    static func servers(from preferredServers: [[String]]) -> [SpellServer] {
        preferredServers.compactMap { pair in
            guard pair.count >= 2, !pair[0].isEmpty else { return nil }
            return SpellServer(language: pair[0], vendor: pair[1])
        }
    }

    /// The first four languages stay in the menu. The rest go in a submenu.
    static let inlineLimit = 4

    static func layout(for servers: [SpellServer]) -> (inline: [SpellServer], overflow: [SpellServer]) {
        guard servers.count > inlineLimit else { return (servers, []) }
        return (Array(servers.prefix(inlineLimit)), Array(servers.dropFirst(inlineLimit)))
    }

    /// Native language name, with the vendor when it is not Apple.
    /// `et` / Sonastik is "Eesti (Sonastik)". `en_GB` / Apple is "English (United Kingdom)".
    static func menuTitle(for server: SpellServer) -> String {
        let locale = Locale(identifier: server.language)
        let raw = locale.localizedString(forIdentifier: server.language) ?? server.language
        let name = raw.prefix(1).uppercased(with: locale) + raw.dropFirst()
        if server.vendor.isEmpty || server.vendor == "Apple" {
            return String(name)
        }
        return "\(name) (\(server.vendor))"
    }

    static func isCurrent(_ server: SpellServer, language: String, vendors: [String: String]) -> Bool {
        guard server.language == language else { return false }
        guard let vendor = vendors[language], !vendor.isEmpty else { return true }
        return server.vendor == vendor
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
