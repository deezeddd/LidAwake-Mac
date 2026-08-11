import Cocoa
import IOKit
import ServiceManagement

@_silgen_name("DisplayServicesGetBrightness")
func DisplayServicesGetBrightness(_ display: UInt32, _ brightness: UnsafeMutablePointer<Float>) -> Int32

@_silgen_name("DisplayServicesSetBrightness")
func DisplayServicesSetBrightness(_ display: UInt32, _ brightness: Float) -> Int32

let setupCommand = "sudo sh -c 'f=$(mktemp); echo \"\(NSUserName()) ALL=(ALL) NOPASSWD: /usr/bin/pmset -a disablesleep 1, /usr/bin/pmset -a disablesleep 0\" > \"$f\"; visudo -cf \"$f\" && install -m 440 \"$f\" /etc/sudoers.d/lid-awake && echo INSTALLED'"

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private let toggleItem = NSMenuItem()
    private let loginItem = NSMenuItem()

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        let menu = NSMenu()
        menu.delegate = self

        toggleItem.title = "Keep Awake When Lid Is Closed"
        toggleItem.action = #selector(toggleLidAwake)
        toggleItem.target = self
        menu.addItem(toggleItem)

        menu.addItem(.separator())

        loginItem.title = "Start at Login"
        loginItem.action = #selector(toggleStartAtLogin)
        loginItem.target = self
        menu.addItem(loginItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit Lid Awake", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)

        statusItem.menu = menu
        refreshUI()

        let workspaceCenter = NSWorkspace.shared.notificationCenter
        workspaceCenter.addObserver(self, selector: #selector(handleScreensSleep),
                                    name: NSWorkspace.screensDidSleepNotification, object: nil)
        workspaceCenter.addObserver(self, selector: #selector(handleScreensWake),
                                    name: NSWorkspace.screensDidWakeNotification, object: nil)

        lastClamshellClosed = isClamshellClosed()
        if let current = getBrightness() {
            lastKnownBrightness = current
        }
        logEvent("started (clamshell closed: \(lastClamshellClosed), brightness: \(lastKnownBrightness))")
        clamshellTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.pollClamshell()
        }
    }

    // MARK: - Brightness save/restore around lid close

    private let savedBrightnessKey = "savedBrightness"
    private var lastKnownBrightness: Float = 0.5
    private var lastClamshellClosed = false
    private var clamshellTimer: Timer?

    private func logEvent(_ message: String) {
        let url = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/LidAwake.log")
        let stamp = ISO8601DateFormatter().string(from: Date())
        guard let data = "\(stamp) \(message)\n".data(using: .utf8) else { return }
        if let handle = try? FileHandle(forWritingTo: url) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
        } else {
            try? data.write(to: url)
        }
    }

    private func isClamshellClosed() -> Bool {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPMrootDomain"))
        guard service != 0 else { return false }
        defer { IOObjectRelease(service) }
        guard let property = IORegistryEntryCreateCFProperty(
            service, "AppleClamshellState" as CFString, kCFAllocatorDefault, 0
        )?.takeRetainedValue() as? Bool else { return false }
        return property
    }

    private func getBuiltinDisplayID() -> UInt32? {
        var displays = [CGDirectDisplayID](repeating: 0, count: 8)
        var count: UInt32 = 0
        guard CGGetOnlineDisplayList(8, &displays, &count) == .success else { return nil }
        for i in 0..<Int(count) where CGDisplayIsBuiltin(displays[i]) != 0 {
            return displays[i]
        }
        return nil
    }

    private func getBrightness() -> Float? {
        guard let display = getBuiltinDisplayID() else { return nil }
        var value: Float = 0
        guard DisplayServicesGetBrightness(display, &value) == 0 else { return nil }
        return value
    }

    @discardableResult
    private func setBrightness(_ value: Float) -> Bool {
        guard let display = getBuiltinDisplayID() else { return false }
        return DisplayServicesSetBrightness(display, value) == 0
    }

    private func pollClamshell() {
        let closed = isClamshellClosed()
        if closed != lastClamshellClosed {
            lastClamshellClosed = closed
            if closed {
                saveBrightnessAndZero(reason: "lid closed")
            } else {
                restoreBrightness(reason: "lid opened")
            }
            return
        }
        if !closed {
            if UserDefaults.standard.object(forKey: savedBrightnessKey) != nil {
                restoreBrightness(reason: "retry after lid opened")
            } else if let current = getBrightness() {
                lastKnownBrightness = current
            }
        }
    }

    private func saveBrightnessAndZero(reason: String) {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: savedBrightnessKey) == nil {
            let toSave = getBrightness() ?? lastKnownBrightness
            defaults.set(toSave, forKey: savedBrightnessKey)
            logEvent("\(reason): saved brightness \(toSave)")
        }
        let ok = setBrightness(0)
        logEvent("\(reason): set brightness to 0 \(ok ? "ok" : "failed (display offline)")")
    }

    private func restoreBrightness(reason: String) {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: savedBrightnessKey) != nil else { return }
        let saved = defaults.float(forKey: savedBrightnessKey)
        if setBrightness(saved) {
            defaults.removeObject(forKey: savedBrightnessKey)
            logEvent("\(reason): restored brightness \(saved)")
        } else {
            logEvent("\(reason): restore to \(saved) failed, will retry")
        }
    }

    @objc private func handleScreensSleep() {
        saveBrightnessAndZero(reason: "screens slept")
    }

    @objc private func handleScreensWake() {
        restoreBrightness(reason: "screens woke")
    }

    private func runProcess(_ path: String, _ args: [String]) -> (Int32, String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = args
        let outPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = Pipe()
        do { try process.run() } catch { return (-1, "") }
        process.waitUntilExit()
        let data = outPipe.fileHandleForReading.readDataToEndOfFile()
        return (process.terminationStatus, String(data: data, encoding: .utf8) ?? "")
    }

    private func isLidAwakeOn() -> Bool {
        let (_, output) = runProcess("/usr/bin/pmset", ["-g"])
        for line in output.split(separator: "\n") where line.contains("SleepDisabled") {
            return line.trimmingCharacters(in: .whitespaces).hasSuffix("1")
        }
        return false
    }

    private func statusImage(on: Bool) -> NSImage? {
        let candidates = on
            ? ["cup.and.saucer.fill", "moon.fill", "sun.max.fill"]
            : ["cup.and.saucer", "moon.zzz", "moon"]
        for name in candidates {
            if let image = NSImage(systemSymbolName: name, accessibilityDescription: "Lid Awake") {
                image.isTemplate = true
                return image
            }
        }
        return nil
    }

    private func refreshUI() {
        let on = isLidAwakeOn()
        statusItem.button?.image = statusImage(on: on)
        statusItem.button?.toolTip = on
            ? "Lid Awake: on. The Mac keeps running with the lid closed."
            : "Lid Awake: off. Closing the lid sleeps the Mac normally."
        toggleItem.state = on ? .on : .off
        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        refreshUI()
    }

    @objc private func toggleLidAwake() {
        let target = isLidAwakeOn() ? "0" : "1"
        let (status, _) = runProcess("/usr/bin/sudo", ["-n", "/usr/bin/pmset", "-a", "disablesleep", target])
        if status != 0 {
            showSetupAlert()
        }
        refreshUI()
    }

    private func showSetupAlert() {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "One-Time Setup Needed"
        alert.informativeText = "Lid Awake needs permission to change the sleep setting without asking for your password every time.\n\nClick \u{201C}Copy Command\u{201D}, paste it into Terminal, enter your password once, then use the toggle again."
        alert.addButton(withTitle: "Copy Command")
        alert.addButton(withTitle: "Cancel")
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(setupCommand, forType: .string)
        }
    }

    @objc private func toggleStartAtLogin() {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled {
                try service.unregister()
            } else {
                try service.register()
            }
        } catch {
            NSSound.beep()
        }
        refreshUI()
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
