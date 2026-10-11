/* SPDX-License-Identifier: LGPL-2.1-or-later
 * Copyright (c) 2026 Madis Väin
 *
 * Unit tests load into this app. It does not call NSSpellServer.run().
 */
import AppKit

@main
enum TestHostMain {
    static func main() {
        NSApplication.shared.run()
    }
}
