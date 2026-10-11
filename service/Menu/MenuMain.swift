/* SPDX-License-Identifier: LGPL-2.1-or-later
 * Copyright (c) 2026 Madis Väin
 */
import AppKit
import os
import ServiceManagement

private let log = Logger(subsystem: "ee.madisvain.sonastik", category: "menu")

/// NSApplication.delegate is unretained. This keeps the controller for the process lifetime.
private var retainedController: MenuController?

@main
enum MenuMain {
    static func main() {
        if CommandLine.arguments.contains("--unregister") {
            do {
                try SMAppService.mainApp.unregister()
            } catch {
                log.error("unregister failed: \(error, privacy: .public)")
                exit(1)
            }
            exit(0)
        }

        let app = NSApplication.shared
        let controller = MenuController()
        retainedController = controller
        app.delegate = controller
        app.run()
    }
}

final class MenuController: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = NSMenu()
    private var timer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        menu.autoenablesItems = false
        menu.delegate = self
        statusItem.menu = menu
        refreshChrome()
        registerLoginItem()

        let timer = Timer(timeInterval: 3, repeats: true) { [weak self] _ in
            self?.refreshChrome()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func applicationWillTerminate(_ notification: Notification) {
        timer?.invalidate()
    }

    func menuWillOpen(_ menu: NSMenu) {
        refreshChrome()
        rebuild(menu)
    }

    private func registerLoginItem() {
        do {
            try SMAppService.mainApp.register()
        } catch {
            // Launching from dist/ is outside an Applications folder, so registration
            // fails there. The status item still works. install-dev.sh copies the app
            // to ~/Applications, where this succeeds.
            log.error("login item register failed: \(error, privacy: .public)")
        }
    }

    private func refreshChrome() {
        let language = GlobalSpelling.currentLanguage()
        let running = !NSRunningApplication.runningApplications(
            withBundleIdentifier: ServiceStatus.serviceBundleIdentifier
        ).isEmpty
        let status = ServiceStatus.loadInstalled(isRunning: running)
        statusItem.button?.title = SpellingLanguage.statusTitle(for: language)
        statusItem.button?.toolTip = status.tooltip
    }

    private func rebuild(_ menu: NSMenu) {
        menu.removeAllItems()
        let language = GlobalSpelling.currentLanguage() ?? ""
        let running = !NSRunningApplication.runningApplications(
            withBundleIdentifier: ServiceStatus.serviceBundleIdentifier
        ).isEmpty
        let status = ServiceStatus.loadInstalled(isRunning: running)

        let eesti = NSMenuItem(title: "Eesti", action: #selector(chooseEstonian), keyEquivalent: "")
        eesti.target = self
        eesti.state = SpellingLanguage.isEstonian(language) ? .on : .off
        menu.addItem(eesti)

        let english = NSMenuItem(title: "English", action: #selector(chooseEnglish), keyEquivalent: "")
        english.target = self
        english.state = SpellingLanguage.isEnglish(language) ? .on : .off
        menu.addItem(english)

        menu.addItem(.separator())

        let presence = NSMenuItem(title: status.presenceLabel, action: nil, keyEquivalent: "")
        presence.isEnabled = false
        menu.addItem(presence)

        if status.canStart {
            let start = NSMenuItem(title: "Start Sõnastik", action: #selector(startService), keyEquivalent: "")
            start.target = self
            menu.addItem(start)
        }

        for line in status.versionLines {
            let version = NSMenuItem(title: line, action: nil, keyEquivalent: "")
            version.isEnabled = false
            menu.addItem(version)
        }

        if SMAppService.mainApp.status == .requiresApproval {
            menu.addItem(.separator())
            let allow = NSMenuItem(
                title: "Allow Sõnastik in Login Items",
                action: #selector(openLoginItems),
                keyEquivalent: "")
            allow.target = self
            menu.addItem(allow)
        }

        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit Sõnastik", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
    }

    @objc private func chooseEstonian() {
        GlobalSpelling.apply(SpellingLanguage.payload(for: SpellingLanguage.estonian))
        refreshChrome()
    }

    @objc private func chooseEnglish() {
        let server = SpellingLanguage.englishServer(preferredServers: GlobalSpelling.preferredServers())
        GlobalSpelling.apply(SpellingLanguage.payload(for: server))
        refreshChrome()
    }

    @objc private func startService() {
        let binary = ServiceStatus.installedBundle.appendingPathComponent("Contents/MacOS/EstonianSpeller")
        guard FileManager.default.isExecutableFile(atPath: binary.path) else {
            log.error("speller executable is missing")
            return
        }
        // The spelling process is independent of this menu app. Quitting the menu
        // must leave it running, so this Process is not stored or terminated.
        let process = Process()
        process.executableURL = binary
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            log.error("start failed: \(error, privacy: .public)")
        }
        refreshChrome()
    }

    @objc private func openLoginItems() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
