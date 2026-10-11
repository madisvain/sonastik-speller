/* SPDX-License-Identifier: LGPL-2.1-or-later
 * Copyright (c) 2026 Madis Väin
 */
import XCTest
@testable import TestHost

final class MenuTests: XCTestCase {
    func testEstonianPayload() {
        let payload = SpellingLanguage.payload(for: SpellingLanguage.estonian)
        XCTAssertEqual(payload.language, "et")
        XCTAssertEqual(payload.vendor, "Sonastik")
        XCTAssertFalse(payload.identifiesLanguagesAutomatically)
        XCTAssertEqual(payload.kbSpellingLanguage["KB_SpellingLanguage"] as? [String], ["et", "Sonastik"])
        XCTAssertEqual(payload.kbSpellingLanguage["KB_SpellingLanguageIsAutomatic"] as? Bool, false)
    }

    func testEnglishPayloadUsesBritishEnglishWhenNoneIsPreferred() {
        let server = SpellingLanguage.englishServer(preferredServers: [["et", "Sonastik"]])
        XCTAssertEqual(server, SpellServer(language: "en_GB", vendor: "Apple"))
        let payload = SpellingLanguage.payload(for: server)
        XCTAssertEqual(payload.language, "en_GB")
        XCTAssertEqual(payload.vendor, "Apple")
        XCTAssertFalse(payload.identifiesLanguagesAutomatically)
    }

    func testEnglishPayloadUsesThePreferredEnglishEntry() {
        let server = SpellingLanguage.englishServer(preferredServers: [
            ["et", "Sonastik"],
            ["en_US", "Apple"],
        ])
        XCTAssertEqual(server, SpellServer(language: "en_US", vendor: "Apple"))
    }

    func testMergedVendorsKeepExistingEntries() {
        let vendors = SpellingLanguage.mergedVendors(["en_GB": "Apple", "et": "Other"])
        XCTAssertEqual(vendors["en_GB"], "Apple")
        XCTAssertEqual(vendors["et"], "Sonastik")
    }

    func testStatusTitle() {
        XCTAssertEqual(SpellingLanguage.statusTitle(for: "et"), "ET")
        XCTAssertEqual(SpellingLanguage.statusTitle(for: "en_GB"), "EN")
        XCTAssertEqual(SpellingLanguage.statusTitle(for: "fi"), "fi")
        XCTAssertEqual(SpellingLanguage.statusTitle(for: nil), "—")
    }

    func testVersionLines() {
        let status = ServiceStatus.make(
            bundleExists: true,
            isRunning: true,
            info: [
                "CFBundleShortVersionString": "1.0",
                "SonastikEngineVersion": "vabamorf abc",
            ])
        XCTAssertEqual(status.presenceLabel, "Sõnastik is running")
        XCTAssertEqual(status.versionLines, ["Version 1.0", "vabamorf abc"])
        XCTAssertEqual(status.tooltip, "Sõnastik · running · 1.0 · vabamorf abc")
    }

    func testMissingBundleIsNotInstalled() {
        let status = ServiceStatus.make(bundleExists: false, isRunning: true, info: [
            "CFBundleShortVersionString": "1.0",
        ])
        XCTAssertEqual(status.presence, .notInstalled)
        XCTAssertEqual(status.presenceLabel, "Sõnastik is not installed")
        XCTAssertEqual(status.versionLines, ["Not installed"])
        XCTAssertFalse(status.canStart)
    }

    func testPresentBundleThatIsStopped() {
        let status = ServiceStatus.make(bundleExists: true, isRunning: false, info: [:])
        XCTAssertEqual(status.presence, .notRunning)
        XCTAssertEqual(status.presenceLabel, "Sõnastik is not running")
        XCTAssertTrue(status.canStart)
        XCTAssertEqual(status.versionLines, ["Version unknown"])
    }
}
