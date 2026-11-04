import AppKit
import PossumCore
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let helper = HelperClient()
    private let defaults = UserDefaults.standard
    private let deadlineKey = "restoreSleepDeadline"
    private let durations: [(title: String, seconds: TimeInterval)] = [
        ("30 Minutes", 30 * 60),
        ("1 Hour", 60 * 60),
        ("2 Hours", 2 * 60 * 60),
        ("4 Hours", 4 * 60 * 60),
        ("8 Hours", 8 * 60 * 60),
    ]

    private var statusItem: NSStatusItem!
    private var refreshTimer: Timer?
    private var busy = false
    /// Last verified value of `SleepDisabled`; `nil` when it could not be read.
    private var sleepDisabled: Bool?

    private var restoreDeadline: Date? {
        get { defaults.object(forKey: deadlineKey) as? Date }
        set { defaults.set(newValue, forKey: deadlineKey) }
    }

    // MARK: Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let menu = NSMenu()
        menu.delegate = self
        menu.autoenablesItems = false
        statusItem.menu = menu

        refresh()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        refreshTimer?.tolerance = 5
    }

    // MARK: Status

    /// Re-reads `pmset -g`, updates the icon, and enforces the restore timer.
    private func refresh() {
        sleepDisabled = PMSet.readSleepDisabled()
        updateIcon()

        if sleepDisabled != true, restoreDeadline != nil {
            restoreDeadline = nil
        }
        if sleepDisabled == true, let deadline = restoreDeadline, deadline <= Date(), !busy {
            setSleepDisabled(false)
        }
    }

    private func updateIcon() {
        guard let button = statusItem.button else { return }
        let awake = sleepDisabled == true
        let image = NSImage(named: awake ? "possum-awake" : "possum-sleep")
        image?.isTemplate = true
        image?.size = NSSize(width: 22, height: 22)
        image?.accessibilityDescription = awake ? "Possum: sleep disabled" : "Possum: normal sleep"
        button.image = image
        button.toolTip = statusText
    }

    private var statusText: String {
        switch sleepDisabled {
        case true?: return "Sleep disabled — stays awake with the lid closed"
        case false?: return "Normal sleep"
        case nil: return "Sleep status unknown"
        }
    }

    // MARK: Menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        sleepDisabled = PMSet.readSleepDisabled()
        updateIcon()
        menu.removeAllItems()

        let status = NSMenuItem(title: statusText, action: nil, keyEquivalent: "")
        status.isEnabled = false
        menu.addItem(status)
        if sleepDisabled == true, let deadline = restoreDeadline {
            let info = NSMenuItem(title: "Restores sleep at \(deadline.formatted(date: .omitted, time: .shortened))", action: nil, keyEquivalent: "")
            info.isEnabled = false
            menu.addItem(info)
        }
        menu.addItem(.separator())

        let toggle = NSMenuItem(title: "Prevent Sleep", action: #selector(toggleSleep), keyEquivalent: "")
        toggle.target = self
        toggle.state = sleepDisabled == true ? .on : .off
        toggle.isEnabled = !busy
        menu.addItem(toggle)

        let restore = NSMenuItem(title: "Prevent Sleep For", action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        for (index, duration) in durations.enumerated() {
            let item = NSMenuItem(title: duration.title, action: #selector(preventSleepFor(_:)), keyEquivalent: "")
            item.target = self
            item.tag = index
            item.isEnabled = !busy
            submenu.addItem(item)
        }
        restore.submenu = submenu
        menu.addItem(restore)
        menu.addItem(.separator())

        switch helper.status {
        case .requiresApproval:
            let approve = NSMenuItem(title: "Allow Helper in System Settings…", action: #selector(openApproval), keyEquivalent: "")
            approve.target = self
            menu.addItem(approve)
            menu.addItem(.separator())
        default:
            break
        }

        let login = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        login.target = self
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)
        menu.addItem(.separator())

        let restoreAndQuit = NSMenuItem(title: "Enable Sleep and Quit", action: #selector(enableSleepAndQuit), keyEquivalent: "")
        restoreAndQuit.target = self
        restoreAndQuit.isEnabled = !busy
        menu.addItem(restoreAndQuit)

        let quit = NSMenuItem(title: "Quit Possum", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        if sleepDisabled == true {
            quit.toolTip = "Sleep stays disabled after quitting."
        }
        menu.addItem(quit)
    }

    // MARK: Actions

    @objc private func toggleSleep() {
        restoreDeadline = nil
        setSleepDisabled(sleepDisabled != true)
    }

    @objc private func preventSleepFor(_ sender: NSMenuItem) {
        let seconds = durations[sender.tag].seconds
        setSleepDisabled(true) { [weak self] ok in
            if ok { self?.restoreDeadline = Date().addingTimeInterval(seconds) }
        }
    }

    @objc private func enableSleepAndQuit() {
        restoreDeadline = nil
        setSleepDisabled(false) { ok in
            if ok { NSApp.terminate(nil) }
        }
    }

    @objc private func openApproval() {
        helper.openApprovalSettings()
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            showError("Could not change Launch at Login", error)
        }
    }

    private func setSleepDisabled(_ disabled: Bool, completion: ((Bool) -> Void)? = nil) {
        busy = true
        helper.setSleepDisabled(disabled) { [weak self] result in
            guard let self else { return }
            self.busy = false
            self.refresh()
            switch result {
            case .success:
                completion?(self.sleepDisabled == disabled)
            case .failure(let error):
                if case HelperError.requiresApproval = error {
                    self.helper.openApprovalSettings()
                }
                self.showError(disabled ? "Could not disable sleep" : "Could not enable sleep", error)
                completion?(false)
            }
        }
    }

    private func showError(_ title: String, _ error: Error) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.runModal()
    }
}
