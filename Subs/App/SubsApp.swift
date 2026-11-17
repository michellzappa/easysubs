import AppKit
import Combine
import HouseKit
import HouseKitSparkle

@main
@MainActor
final class SubsAppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, NSWindowDelegate, NSDraggingDestination {
    private let settings = SettingsStore()
    private lazy var queue = SubtitleQueue(settings: settings)
    private lazy var settingsWindowController = HouseSettingsWindowController.subs(settings: settings, updates: updates)
    private lazy var dropWindowController = DropWindowController(queue: queue, settings: settings) { [weak self] in
        self?.showOpenSubtitlesSettings()
    }
    /// Sparkle. Feed and key come from Info.plist (housekit docs/releasing.md).
    private let updates = SparkleUpdater(appName: "Subs")
    private var statusItem: NSStatusItem!
    private var statusMenu: NSMenu!
    private var cancellables = Set<AnyCancellable>()

    /// Recent jobs listed in the status menu.
    private static let menuJobCount = 5

    static func main() {
        let application = NSApplication.shared
        let delegate = SubsAppDelegate()
        application.delegate = delegate
        application.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)
        NSApplication.shared.mainMenu = makeMainMenu()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = MenuBarPlate.image(glyph: HouseGlyphs.subs)
            button.imagePosition = .imageOnly
            button.setAccessibilityLabel("Subs menu")
            button.toolTip = "Subs: drop a video here to get its subtitles"
            // The status item's own window takes the drop; this delegate
            // receives the dragging messages for it.
            button.window?.registerForDraggedTypes([.fileURL])
            button.window?.delegate = self
        }
        statusMenu = NSMenu()
        statusMenu.delegate = self
        statusItem.menu = statusMenu
        rebuildStatusMenu()

        queue.onNeedsSetup = { [weak self] in self?.showOpenSubtitlesSettings() }
        queue.$isProcessing
            .removeDuplicates()
            .sink { [weak self] processing in
                // Dimmed while a subtitle is on its way.
                self?.statusItem.button?.alphaValue = processing ? 0.5 : 1
            }
            .store(in: &cancellables)

        if !settings.isConfigured {
            showOpenSubtitlesSettings()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { settingsWindowController.show() }
        return true
    }

    private func showOpenSubtitlesSettings() {
        settingsWindowController.show(pane: HouseSettingsWindowController.openSubtitlesPaneID)
    }

    // MARK: - Drop on the status item

    func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation {
        guard !Self.videos(in: sender).isEmpty else { return [] }
        statusItem.button?.highlight(true)
        return .copy
    }

    func draggingUpdated(_ sender: any NSDraggingInfo) -> NSDragOperation {
        Self.videos(in: sender).isEmpty ? [] : .copy
    }

    func draggingExited(_ sender: (any NSDraggingInfo)?) {
        statusItem.button?.highlight(false)
    }

    func prepareForDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        !Self.videos(in: sender).isEmpty
    }

    func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        statusItem.button?.highlight(false)
        return queue.accept(Self.videos(in: sender))
    }

    func concludeDragOperation(_ sender: (any NSDraggingInfo)?) {
        statusItem.button?.highlight(false)
    }

    private static func videos(in sender: any NSDraggingInfo) -> [URL] {
        let urls = sender.draggingPasteboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        ) as? [URL] ?? []
        return SubtitleQueue.videos(in: urls)
    }

    // MARK: - Status menu

    func menuWillOpen(_ menu: NSMenu) {
        guard menu === statusMenu else { return }
        rebuildStatusMenu()
    }

    /// Action-first, same shape as Clip and Cargo: header, the things you
    /// came for, then Settings / Launch at Login / Quit.
    private func rebuildStatusMenu() {
        statusMenu.removeAllItems()
        let header: String
        if !settings.isConfigured {
            header = "Set up OpenSubtitles"
        } else if queue.isProcessing {
            header = "Finding subtitles…"
        } else {
            header = "Subs · \(settings.languageName)"
        }
        statusMenu.addItem(StatusMenu.sectionHeader(header))

        let recent = queue.jobs.prefix(Self.menuJobCount)
        for job in recent {
            let item = NSMenuItem(title: job.videoURL.lastPathComponent, action: nil, keyEquivalent: "")
            item.image = NSImage(systemSymbolName: Self.symbol(for: job.stage), accessibilityDescription: nil)
            item.toolTip = job.detail
            if let subtitle = job.subtitleURL {
                item.action = #selector(revealSubtitle(_:))
                item.representedObject = subtitle
            }
            statusMenu.addItem(item)
        }
        if !recent.isEmpty {
            statusMenu.addItem(.separator())
        }

        if !settings.isConfigured {
            statusMenu.addItem(NSMenuItem(title: "Set Up OpenSubtitles…", action: #selector(showSetup(_:)), keyEquivalent: ""))
        }
        statusMenu.addItem(NSMenuItem(title: "Open Drop Window", action: #selector(showDropWindow(_:)), keyEquivalent: "d"))
        statusMenu.addItem(NSMenuItem(title: "Choose Videos…", action: #selector(chooseVideos(_:)), keyEquivalent: "o"))
        let clearItem = NSMenuItem(title: "Clear Finished", action: #selector(clearFinished(_:)), keyEquivalent: "")
        clearItem.isEnabled = queue.jobs.contains { !$0.stage.isActive && $0.stage != .queued }
        statusMenu.addItem(clearItem)
        statusMenu.items.forEach { $0.target = self }
        StatusMenu.appendStandardTail(
            to: statusMenu,
            appName: "Subs",
            target: self,
            settings: #selector(showSettings(_:)),
            launchAtLogin: #selector(toggleLaunchAtLogin(_:)),
            launchAtLoginEnabled: LaunchAtLogin.isRequested,
            quit: #selector(quit(_:)),
            updates: updates
        )
    }

    private static func symbol(for stage: JobStage) -> String {
        switch stage {
        case .queued: "clock"
        case .hashing, .searching, .downloading: "arrow.down.circle"
        case .saved: "checkmark.circle.fill"
        case .skipped: "checkmark.circle"
        case .failed: "exclamationmark.circle"
        }
    }

    private func makeMainMenu() -> NSMenu {
        let mainMenu = NSMenu()
        let appMenu = NSMenu(title: "Subs")
        appMenu.addItem(withTitle: "Settings…", action: #selector(showSettings(_:)), keyEquivalent: ",").target = self
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit Subs", action: #selector(quit(_:)), keyEquivalent: "q").target = self
        mainMenu.addItem(withTitle: "Subs", action: nil, keyEquivalent: "").submenu = appMenu

        // Text fields in Settings need these to respond to ⌘C/⌘V/⌘A.
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        mainMenu.addItem(withTitle: "Edit", action: nil, keyEquivalent: "").submenu = editMenu

        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        mainMenu.addItem(withTitle: "Window", action: nil, keyEquivalent: "").submenu = windowMenu
        NSApplication.shared.windowsMenu = windowMenu
        return mainMenu
    }

    // MARK: - Actions

    @objc private func revealSubtitle(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }
        queue.reveal(url)
    }

    @objc private func showDropWindow(_ sender: Any?) {
        dropWindowController.show()
    }

    @objc private func chooseVideos(_ sender: Any?) {
        queue.chooseVideos()
    }

    @objc private func clearFinished(_ sender: Any?) {
        queue.clearFinished()
    }

    @objc private func showSetup(_ sender: Any?) {
        showOpenSubtitlesSettings()
    }

    @objc private func showSettings(_ sender: Any?) {
        settingsWindowController.show()
    }

    @objc private func toggleLaunchAtLogin(_ sender: Any?) {
        do {
            try LaunchAtLogin.setEnabled(!LaunchAtLogin.isRequested)
        } catch {
            NSLog("Subs: launch at login failed: \(error)")
        }
    }

    @objc private func quit(_ sender: Any?) {
        NSApp.terminate(nil)
    }
}
