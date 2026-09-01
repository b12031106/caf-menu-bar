import AppKit
import Carbon
import ServiceManagement

private final class CafApp: NSObject, NSApplicationDelegate, NSUserNotificationCenterDelegate {
    private enum CaffeinateMode: String {
        case keepDisplayAwake
        case allowDisplaySleep

        var arguments: [String] {
            switch self {
            case .keepDisplayAwake:
                ["-dims"]
            case .allowDisplaySleep:
                ["-ims"]
            }
        }
    }

    private let bundleIdentifier = "local.caf.menubar"
    private let toggleNotification = Notification.Name("local.caf.menubar.toggle")
    private let pidFile = URL(fileURLWithPath: "/tmp/local.caf.menubar.caffeinate.pid")
    private let caffeinateModeDefaultsKey = "local.caf.menubar.caffeinateMode"
    private let launchAtLoginConfiguredDefaultsKey = "local.caf.menubar.launchAtLoginConfigured"
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private var caffeinateProcess: Process?
    private var hotKeyRef: EventHotKeyRef?
    private var hotKeyHandler: EventHandlerRef?

    func applicationDidFinishLaunching(_ notification: Notification) {
        ProcessInfo.processInfo.disableAutomaticTermination("caf keeps the menu bar toggle alive")
        ProcessInfo.processInfo.disableSuddenTermination()
        NSApp.setActivationPolicy(.accessory)

        if notifyExistingInstance() {
            NSApp.terminate(nil)
            return
        }

        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(toggleFromExternalLaunch),
            name: toggleNotification,
            object: nil
        )

        cleanStaleCaffeinate()
        NSUserNotificationCenter.default.delegate = self
        configureDefaultLaunchAtLogin()
        configureStatusItem()
        registerHotKey()
        toggleCaffeinate(showToast: true)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        toggleCaffeinate(showToast: true)
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        NSUserNotificationCenter.default.delegate = nil
        DistributedNotificationCenter.default().removeObserver(self)
        stopCaffeinate(showToast: false)
        unregisterHotKey()
    }

    func userNotificationCenter(
        _ center: NSUserNotificationCenter,
        shouldPresent notification: NSUserNotification
    ) -> Bool {
        true
    }

    private func notifyExistingInstance() -> Bool {
        let currentPID = getpid()
        let hasPeer = NSWorkspace.shared.runningApplications.contains { app in
            app.bundleIdentifier == bundleIdentifier && app.processIdentifier != currentPID
        }

        guard hasPeer else { return false }
        DistributedNotificationCenter.default().post(name: toggleNotification, object: nil)
        return true
    }

    private func configureStatusItem() {
        statusItem.button?.target = self
        statusItem.button?.action = #selector(statusItemClicked)
        updateStatusItem()
    }

    @objc private func statusItemClicked() {
        let menu = NSMenu()

        let state = isCaffeinateRunning ? "狀態：啟用中" : "狀態：已關閉"
        let stateItem = NSMenuItem(title: state, action: nil, keyEquivalent: "")
        stateItem.isEnabled = false
        menu.addItem(stateItem)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(
            title: isCaffeinateRunning ? "關閉 Caffeinate" : "啟用 Caffeinate",
            action: #selector(toggleFromMenu),
            keyEquivalent: ""
        ))

        menu.addItem(.separator())
        let keepDisplayAwakeItem = NSMenuItem(
            title: "保持螢幕喚醒（-dims）",
            action: #selector(selectKeepDisplayAwake),
            keyEquivalent: ""
        )
        keepDisplayAwakeItem.state = caffeinateMode == .keepDisplayAwake ? .on : .off
        menu.addItem(keepDisplayAwakeItem)

        let allowDisplaySleepItem = NSMenuItem(
            title: "允許螢幕休眠（僅防止系統休眠，-ims）",
            action: #selector(selectAllowDisplaySleep),
            keyEquivalent: ""
        )
        allowDisplaySleepItem.state = caffeinateMode == .allowDisplaySleep ? .on : .off
        menu.addItem(allowDisplaySleepItem)

        let hotKeyItem = NSMenuItem(title: "熱鍵：⌃⌥⌘C", action: nil, keyEquivalent: "")
        hotKeyItem.isEnabled = false
        menu.addItem(hotKeyItem)

        menu.addItem(.separator())
        let launchAtLoginItem = NSMenuItem(
            title: launchAtLoginMenuTitle,
            action: #selector(toggleLaunchAtLogin),
            keyEquivalent: ""
        )
        switch SMAppService.mainApp.status {
        case .enabled:
            launchAtLoginItem.state = .on
        case .requiresApproval:
            launchAtLoginItem.state = .mixed
        case .notRegistered, .notFound:
            launchAtLoginItem.state = .off
        @unknown default:
            launchAtLoginItem.state = .off
        }
        menu.addItem(launchAtLoginItem)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "結束", action: #selector(quit), keyEquivalent: "q"))

        NSMenu.popUpContextMenu(menu, with: NSApp.currentEvent!, for: statusItem.button!)
    }

    @objc private func toggleFromMenu() {
        toggleCaffeinate(showToast: true)
    }

    @objc private func toggleFromExternalLaunch() {
        toggleCaffeinate(showToast: true)
    }

    @objc private func selectKeepDisplayAwake() {
        setCaffeinateMode(.keepDisplayAwake)
    }

    @objc private func selectAllowDisplaySleep() {
        setCaffeinateMode(.allowDisplaySleep)
    }

    @objc private func toggleLaunchAtLogin() {
        let service = SMAppService.mainApp

        do {
            switch service.status {
            case .enabled, .requiresApproval:
                try service.unregister()
            case .notRegistered, .notFound:
                try service.register()
            @unknown default:
                try service.register()
            }
            UserDefaults.standard.set(true, forKey: launchAtLoginConfiguredDefaultsKey)
        } catch {
            showToast("無法更新登入時啟動設定")
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private var isCaffeinateRunning: Bool {
        guard let process = caffeinateProcess else { return false }
        return process.isRunning
    }

    private var caffeinateMode: CaffeinateMode {
        get {
            guard let rawValue = UserDefaults.standard.string(forKey: caffeinateModeDefaultsKey) else {
                return .keepDisplayAwake
            }
            return CaffeinateMode(rawValue: rawValue) ?? .keepDisplayAwake
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: caffeinateModeDefaultsKey)
        }
    }

    private var launchAtLoginMenuTitle: String {
        switch SMAppService.mainApp.status {
        case .requiresApproval:
            return "登入時啟動（需在系統設定允許）"
        case .notFound:
            return "登入時啟動（目前無法使用）"
        case .enabled, .notRegistered:
            return "登入時啟動"
        @unknown default:
            return "登入時啟動"
        }
    }

    private func configureDefaultLaunchAtLogin() {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: launchAtLoginConfiguredDefaultsKey) == nil else { return }

        let service = SMAppService.mainApp
        do {
            if service.status == .notRegistered || service.status == .notFound {
                try service.register()
            }
            defaults.set(true, forKey: launchAtLoginConfiguredDefaultsKey)
        } catch {
            NSLog("caf: failed to enable launch at login: %@", error.localizedDescription)
        }
    }

    private func toggleCaffeinate(showToast: Bool) {
        if isCaffeinateRunning {
            stopCaffeinate(showToast: showToast)
        } else {
            startCaffeinate(showToast: showToast)
        }
    }

    private func setCaffeinateMode(_ mode: CaffeinateMode) {
        guard caffeinateMode != mode else { return }
        caffeinateMode = mode

        guard isCaffeinateRunning else { return }
        stopCaffeinate(showToast: false)
        startCaffeinate(showToast: true)
    }

    private func startCaffeinate(showToast: Bool) {
        cleanStaleCaffeinate()

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/caffeinate")
        process.arguments = caffeinateMode.arguments
        process.terminationHandler = { [weak self, weak process] _ in
            DispatchQueue.main.async {
                guard self?.caffeinateProcess === process else { return }
                self?.caffeinateProcess = nil
                self?.removePidFile()
                self?.updateStatusItem()
            }
        }

        do {
            try process.run()
            caffeinateProcess = process
            writePidFile(process.processIdentifier)
            updateStatusItem()
            if showToast { self.showToast("Caffeinate 啟用中") }
        } catch {
            updateStatusItem()
            self.showToast("啟用失敗")
        }
    }

    private func stopCaffeinate(showToast: Bool) {
        caffeinateProcess?.terminate()
        caffeinateProcess = nil
        removePidFile()
        updateStatusItem()
        if showToast { self.showToast("Caffeinate 已關閉") }
    }

    private func cleanStaleCaffeinate() {
        guard let pid = readPidFile(), isProcessAlive(pid) else {
            removePidFile()
            return
        }

        if caffeinateProcess?.processIdentifier == pid {
            return
        }

        kill(pid, SIGTERM)
        removePidFile()
    }

    private func writePidFile(_ pid: Int32) {
        try? "\(pid)\n".write(to: pidFile, atomically: true, encoding: .utf8)
    }

    private func readPidFile() -> Int32? {
        guard
            let contents = try? String(contentsOf: pidFile, encoding: .utf8),
            let pid = Int32(contents.trimmingCharacters(in: .whitespacesAndNewlines))
        else {
            return nil
        }
        return pid
    }

    private func removePidFile() {
        try? FileManager.default.removeItem(at: pidFile)
    }

    private func isProcessAlive(_ pid: Int32) -> Bool {
        kill(pid, 0) == 0
    }

    private func updateStatusItem() {
        guard let button = statusItem.button else { return }
        if isCaffeinateRunning {
            button.image = NSImage(systemSymbolName: "cup.and.saucer.fill", accessibilityDescription: "Caffeinate enabled")
            button.title = " ON"
        } else {
            button.image = NSImage(systemSymbolName: "cup.and.saucer", accessibilityDescription: "Caffeinate disabled")
            button.title = " OFF"
        }
    }

    private func showToast(_ message: String) {
        let notification = NSUserNotification()
        notification.title = "caf"
        notification.informativeText = message
        notification.soundName = nil
        NSUserNotificationCenter.default.deliver(notification)
    }

    private func registerHotKey() {
        let hotKeyID = EventHotKeyID(signature: OSType(UInt32(bigEndian: 0x43414645)), id: 1)
        let modifiers = UInt32(controlKey | optionKey | cmdKey)
        let keyCode = UInt32(kVK_ANSI_C)
        RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let callback: EventHandlerUPP = { _, event, userData in
            var hotKeyID = EventHotKeyID()
            GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )

            guard hotKeyID.id == 1, let userData else {
                return noErr
            }

            let app = Unmanaged<CafApp>.fromOpaque(userData).takeUnretainedValue()
            DispatchQueue.main.async {
                app.toggleCaffeinate(showToast: true)
            }
            return noErr
        }

        InstallEventHandler(
            GetApplicationEventTarget(),
            callback,
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &hotKeyHandler
        )
    }

    private func unregisterHotKey() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        if let hotKeyHandler {
            RemoveEventHandler(hotKeyHandler)
        }
    }
}

private let app = NSApplication.shared
private let delegate = CafApp()
app.delegate = delegate
app.run()
