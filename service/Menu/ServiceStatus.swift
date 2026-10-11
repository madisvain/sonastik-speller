/* SPDX-License-Identifier: LGPL-2.1-or-later
 * Copyright (c) 2026 Madis Väin
 */
import Foundation

struct ServiceStatus: Equatable {
    enum Presence: Equatable {
        case notInstalled
        case notRunning
        case running
    }

    static let serviceBundleIdentifier = "ee.madisvain.EstonianSpeller"

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
}
