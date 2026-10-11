/* SPDX-License-Identifier: LGPL-2.1-or-later
 * Copyright (c) 2026 Madis Väin
 */
import AppKit
import os
import ServiceManagement

private let log = Logger(subsystem: "ee.madisvain.sonastik", category: "menu")

/// `NSMenuItem.representedObject` needs a class. `SpellServer` is a struct.
private final class SpellServerBox: NSObject {
    let server: SpellServer
    init(_ server: SpellServer) { self.server = server }
}

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

        addLanguageItems(to: menu, language: language, vendors: GlobalSpelling.vendors())

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

    private func addLanguageItems(to menu: NSMenu, language: String, vendors: [String: String]) {
        let servers = SpellingLanguage.servers(from: GlobalSpelling.preferredServers())
        let layout = SpellingLanguage.layout(for: servers)
        if layout.inline.isEmpty {
            let empty = NSMenuItem(title: "No spelling languages", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
            return
        }
        for server in layout.inline {
            menu.addItem(languageItem(server, language: language, vendors: vendors))
        }
        guard !layout.overflow.isEmpty else { return }
        let more = NSMenuItem(title: "More", action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        submenu.autoenablesItems = false
        var overflowSelected = false
        for server in layout.overflow {
            let item = languageItem(server, language: language, vendors: vendors)
            if item.state == .on { overflowSelected = true }
            submenu.addItem(item)
        }
        more.submenu = submenu
        more.state = overflowSelected ? .on : .off
        menu.addItem(more)
    }

    private func languageItem(
        _ server: SpellServer,
        language: String,
        vendors: [String: String]
    ) -> NSMenuItem {
        let item = NSMenuItem(
            title: SpellingLanguage.menuTitle(for: server),
            action: #selector(chooseServer(_:)),
            keyEquivalent: "")
        item.target = self
        item.representedObject = SpellServerBox(server)
        item.state = SpellingLanguage.isCurrent(server, language: language, vendors: vendors) ? .on : .off
        return item
    }

    @objc private func chooseServer(_ sender: NSMenuItem) {
        guard let box = sender.representedObject as? SpellServerBox else { return }
        GlobalSpelling.apply(SpellingLanguage.payload(for: box.server))
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
