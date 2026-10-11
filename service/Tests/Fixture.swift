/* SPDX-License-Identifier: LGPL-2.1-or-later
 * Copyright (c) 2026 Madis Väin
 */
import Foundation

enum Fixture {
    /// The dictionary embedded in the test host. The checkout copy sits in the
    /// repo, and macOS denies the test host access to Documents, Desktop, and
    /// Downloads, so a path walked up from this file fails with EPERM there.
    static var dictionaryPath: String {
        Bundle.main.path(forResource: "et", ofType: "dct") ?? ""
    }
}
