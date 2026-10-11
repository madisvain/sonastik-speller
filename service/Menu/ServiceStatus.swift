/* SPDX-License-Identifier: LGPL-2.1-or-later
 * Copyright (c) 2026 Madis Väin
 */
import Darwin
import Foundation

struct ServiceStatus: Equatable {
    enum Presence: Equatable {
        case notInstalled
        case notRunning
        case running
    }

    /// `proc_pidpath` buffer. `PROC_PIDPATHINFO_MAXSIZE` is `4 * MAXPATHLEN`,
    /// and that macro is not visible to Swift.
    private static let pidPathCapacity = 4 * 1024

    static var installedBundle: URL {
        URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
            .appendingPathComponent("Library/Services/EstonianSpeller.service", isDirectory: true)
    }

    var presence: Presence
    var marketingVersion: String?
    var engineVersion: String?

    var presenceLabel: String {
        switch presence {
        case .notInstalled: "Sõnastik is not installed"
        case .notRunning: "Sõnastik is not running"
        case .running: "Sõnastik is running"
        }
    }

    var canStart: Bool { presence == .notRunning }

    var versionLines: [String] {
        if presence == .notInstalled { return ["Not installed"] }
        var lines: [String] = []
        if let marketingVersion, !marketingVersion.isEmpty {
            lines.append("Version \(marketingVersion)")
        }
        if let engineVersion, !engineVersion.isEmpty {
            lines.append(engineVersion)
        }
        if lines.isEmpty {
            lines.append("Version unknown")
        }
        return lines
    }

    /// Tooltip: product name, whether the background speller is running, then the version.
    var tooltip: String {
        var parts = ["Sõnastik"]
        switch presence {
        case .running: parts.append("running")
        case .notRunning: parts.append("not running")
        case .notInstalled: parts.append("not installed")
        }
        if presence != .notInstalled {
            if let marketingVersion, !marketingVersion.isEmpty {
                parts.append(marketingVersion)
            }
            if let engineVersion, !engineVersion.isEmpty {
                parts.append(engineVersion)
            }
        }
        return parts.joined(separator: " · ")
    }

    static func make(bundleExists: Bool, isRunning: Bool, info: [String: String]) -> ServiceStatus {
        guard bundleExists else {
            return ServiceStatus(presence: .notInstalled, marketingVersion: nil, engineVersion: nil)
        }
        return ServiceStatus(
            presence: isRunning ? .running : .notRunning,
            marketingVersion: info["CFBundleShortVersionString"],
            engineVersion: info["SonastikEngineVersion"])
    }

    static func loadInstalled(isRunning: Bool) -> ServiceStatus {
        let bundle = installedBundle
        let exists = FileManager.default.fileExists(atPath: bundle.path)
        var info: [String: String] = [:]
        if exists {
            let plistURL = bundle.appendingPathComponent("Contents/Info.plist")
            if let raw = NSDictionary(contentsOf: plistURL) {
                for key in ["CFBundleShortVersionString", "SonastikEngineVersion"] {
                    if let value = raw[key] as? String {
                        info[key] = value
                    }
                }
            }
        }
        return make(bundleExists: exists, isRunning: isRunning, info: info)
    }

    static var installedExecutable: URL {
        installedBundle.appendingPathComponent("Contents/MacOS/EstonianSpeller")
    }

    /// Exact path match. A second copy under `dist/` is not the installed service.
    static func isRunning(executablePath: String, among paths: [String]) -> Bool {
        paths.contains(executablePath)
    }

    /// The spell server never creates an `NSApplication`, so Launch Services
    /// cannot see it. Match the executable path instead.
    static func isInstalledRunning() -> Bool {
        isRunning(executablePath: installedExecutable.path, among: runningExecutablePaths())
    }

    static func runningExecutablePaths() -> [String] {
        var byteCount = proc_listpids(UInt32(PROC_ALL_PIDS), 0, nil, 0)
        guard byteCount > 0 else { return [] }
        byteCount += Int32(MemoryLayout<pid_t>.stride * 32)
        let count = Int(byteCount) / MemoryLayout<pid_t>.stride
        var pids = [pid_t](repeating: 0, count: max(count, 1))
        let written = pids.withUnsafeMutableBytes { raw in
            proc_listpids(UInt32(PROC_ALL_PIDS), 0, raw.baseAddress, Int32(raw.count))
        }
        guard written > 0 else { return [] }
        let n = min(pids.count, Int(written) / MemoryLayout<pid_t>.stride)
        var paths: [String] = []
        paths.reserveCapacity(n)
        for pid in pids.prefix(n) where pid > 0 {
            var buffer = [CChar](repeating: 0, count: pidPathCapacity)
            let length = buffer.withUnsafeMutableBytes { raw in
                proc_pidpath(pid, raw.baseAddress, UInt32(raw.count))
            }
            if length > 0 {
                paths.append(String(cString: buffer))
            }
        }
        return paths
    }

    /// Starts `executablePath` in its own session, with standard streams on
    /// `/dev/null`. Returns 0 when that path is already running or the spawn
    /// succeeded. Otherwise a posix error code. Quitting the menu app does not
    /// signal this process.
    static func startDetached(executablePath: String) -> Int32 {
        if isRunning(executablePath: executablePath, among: runningExecutablePaths()) {
            return 0
        }

        var attr: posix_spawnattr_t?
        let initAttr = posix_spawnattr_init(&attr)
        guard initAttr == 0 else { return initAttr }
        defer { posix_spawnattr_destroy(&attr) }
        let setFlags = posix_spawnattr_setflags(&attr, Int16(POSIX_SPAWN_SETSID))
        guard setFlags == 0 else { return setFlags }

        var actions: posix_spawn_file_actions_t?
        let initActions = posix_spawn_file_actions_init(&actions)
        guard initActions == 0 else { return initActions }
        defer { posix_spawn_file_actions_destroy(&actions) }

        let devnull = "/dev/null"
        let opens: [(Int32, Int32)] = [
            (STDIN_FILENO, O_RDONLY),
            (STDOUT_FILENO, O_WRONLY),
            (STDERR_FILENO, O_WRONLY),
        ]
        for (fd, flags) in opens {
            let opened = posix_spawn_file_actions_addopen(
                &actions, fd, devnull, flags, mode_t(0))
            guard opened == 0 else { return opened }
        }

        var pid: pid_t = 0
        return executablePath.withCString { cPath in
            var argv: [UnsafeMutablePointer<CChar>?] = [
                UnsafeMutablePointer(mutating: cPath),
                nil,
            ]
            return posix_spawn(&pid, cPath, &actions, &attr, &argv, environ)
        }
    }
}
