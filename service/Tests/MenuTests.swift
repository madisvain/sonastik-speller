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

    func testServersKeepTheSetUpOrder() {
        let servers = SpellingLanguage.servers(from: [
            ["et", "Sonastik"],
            ["en_GB"],
            ["en_US", "Apple"],
        ])
        XCTAssertEqual(servers, [
            SpellServer(language: "et", vendor: "Sonastik"),
            SpellServer(language: "en_US", vendor: "Apple"),
        ])
    }

    func testLayoutShowsFourAndOverflowsTheRest() {
        let servers = (0..<6).map { SpellServer(language: "l\($0)", vendor: "Apple") }
        let layout = SpellingLanguage.layout(for: servers)
        XCTAssertEqual(layout.inline.map(\.language), ["l0", "l1", "l2", "l3"])
        XCTAssertEqual(layout.overflow.map(\.language), ["l4", "l5"])
    }

    func testLayoutOfFourHasNoSubmenu() {
        let servers = (0..<4).map { SpellServer(language: "l\($0)", vendor: "Apple") }
        let layout = SpellingLanguage.layout(for: servers)
        XCTAssertEqual(layout.inline.count, 4)
        XCTAssertTrue(layout.overflow.isEmpty)
    }

    func testMenuTitles() {
        XCTAssertEqual(
            SpellingLanguage.menuTitle(for: SpellServer(language: "et", vendor: "Sonastik")),
            "Eesti (Sonastik)")
        XCTAssertEqual(
            SpellingLanguage.menuTitle(for: SpellServer(language: "en_GB", vendor: "Apple")),
            "English (United Kingdom)")
        XCTAssertEqual(
            SpellingLanguage.menuTitle(for: SpellServer(language: "cs", vendor: "Apple")),
            "Čeština")
    }

    func testCurrentMatchUsesLanguageAndVendor() {
        let vendors = ["et": "Sonastik", "en_GB": "Apple"]
        XCTAssertTrue(SpellingLanguage.isCurrent(
            SpellServer(language: "et", vendor: "Sonastik"),
            language: "et",
            vendors: vendors))
        XCTAssertFalse(SpellingLanguage.isCurrent(
            SpellServer(language: "en_GB", vendor: "Apple"),
            language: "et",
            vendors: vendors))
        XCTAssertFalse(SpellingLanguage.isCurrent(
            SpellServer(language: "en_US", vendor: "Apple"),
            language: "en_GB",
            vendors: vendors))
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
