/* SPDX-License-Identifier: LGPL-2.1-or-later
 * Copyright (c) 2026 Madis Väin
 */
import Foundation
import os

private let log = Logger(subsystem: "ee.madisvain.estonianspeller", category: "service")

/// NSSpellServer.delegate is unretained. This keeps the delegate for the process lifetime.
private var retainedDelegate: SpellServerDelegate?

@main
enum ServiceMain {
    static func main() {
        // Tests use TestHost, not this executable. This process only spells.
        let path = Bundle.main.url(forResource: "et", withExtension: "dct")?.path ?? ""
        if path.isEmpty {
            log.error("et.dct is missing from the bundle; reporting no misspellings")
        }
        let engine = VabamorfEngine(dictionaryPath: path)
        log.info("\(VabamorfEngine.version, privacy: .public)")
        log.info("dictionary \(path, privacy: .public)")

        let delegate = SpellServerDelegate(engine: engine)
        retainedDelegate = delegate
        let server = NSSpellServer()
        server.delegate = delegate
        guard server.registerLanguage("et", byVendor: "Sonastik") else {
            log.error("registerLanguage failed for et / Sonastik")
            exit(1)
        }
        server.run()
    }
}
