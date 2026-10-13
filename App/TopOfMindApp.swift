import AppKit
import Combine
import ServiceManagement
import SwiftUI
import TopOfMindCore

@main
enum TopOfMindApp {
    @MainActor
    static func main() {
        let application = NSApplication.shared
        application.setActivationPolicy(.accessory)
        let delegate = AppDelegate(options: LaunchOptions(arguments: CommandLine.arguments))
        application.delegate = delegate
        withExtendedLifetime(delegate) { application.run() }
    }
}

struct LaunchOptions {
    var demo = false
    var theme: ThemePreference?
    var snapshotPath: String?

    init(arguments: [String]) {
        demo = arguments.contains("--demo") || (Bundle.main.object(forInfoDictionaryKey: "TopOfMindDemoMode") as? Bool == true)
        if let index = arguments.firstIndex(of: "--theme"), arguments.indices.contains(index + 1) {
            theme = ThemePreference(rawValue: arguments[index + 1])
        }
        if let index = arguments.firstIndex(of: "--snapshot"), arguments.indices.contains(index + 1) {
            snapshotPath = arguments[index + 1]
            demo = true
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private let options: LaunchOptions
    private var store: BoardStore!
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var contentController: GlassViewController!
    private var demoPanel: NSPanel?
    private var cancellables: Set<AnyCancellable> = []

    init(options: LaunchOptions) { self.options = options }

    func applicationDidFinishLaunching(_ notification: Notification) {
        store = BoardStore(demo: options.demo, theme: options.theme)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            let customImage = Bundle.main.url(forResource: "MenuBarIcon", withExtension: "png").flatMap { NSImage(contentsOf: $0) }
            let image = customImage ?? NSImage(systemSymbolName: "list.clipboard", accessibilityDescription: "Top of Mind")
                ?? NSImage(systemSymbolName: "checklist", accessibilityDescription: "Top of Mind")
            image?.isTemplate = true
            image?.size = customImage == nil ? NSSize(width: 17, height: 18) : NSSize(width: 15, height: 19)
            button.image = image
            button.imagePosition = .imageOnly
            button.toolTip = "Top of Mind — capture and organize tasks"
            button.target = self
            button.action = #selector(statusItemClicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.setAccessibilityLabel("Top of Mind")
        }

        let view = BoardView(
            store: store,
            onClose: { [weak self] in self?.closePanel() },
            onAppearanceChange: { [weak self] in self?.updateAppearance() },
            onPinChange: { [weak self] in self?.updatePin() }
        )
        let size = panelSize()
        contentController = GlassViewController(rootView: view, size: size)
        popover = NSPopover()
        popover.contentSize = size
        popover.contentViewController = contentController
        popover.delegate = self
        popover.animates = true
        updateAppearance()
        updatePin()

        if options.snapshotPath != nil {
            showDemoPanel(size: size)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in self?.writeSnapshot() }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in self?.openPanel() }
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        openPanel()
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let statusItem { NSStatusBar.system.removeStatusItem(statusItem) }
    }

    @objc private func statusItemClicked(_ sender: Any?) {
        if NSApp.currentEvent?.type == .rightMouseUp { showStatusMenu(); return }
        if popover.isShown { closePanel() } else { openPanel() }
    }

    @objc private func openPanel() {
        guard let button = statusItem?.button else { return }
        if let demoPanel { demoPanel.makeKeyAndOrderFront(nil); return }
        let size = panelSize()
        popover.contentSize = size
        contentController.view.frame = NSRect(origin: .zero, size: size)
        NSApp.activate(ignoringOtherApps: true)
        updateAppearance()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }

    private func closePanel() {
        if let demoPanel { demoPanel.orderOut(nil) } else { popover.performClose(nil) }
    }

    private func updateAppearance() {
        guard let store, let contentController else { return }
        let appearance = NSAppearance(named: store.isDark ? .darkAqua : .aqua)
        contentController.view.appearance = appearance
        contentController.effectView.material = .popover
        contentController.effectView.state = .active
        popover?.appearance = appearance
        demoPanel?.appearance = appearance
    }

    private func updatePin() {
        popover?.behavior = store.snapshot.isPinned ? .applicationDefined : .transient
    }

    private func panelSize() -> NSSize {
        let frame = (statusItem?.button?.window?.screen ?? NSScreen.main)?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1200, height: 800)
        return NSSize(width: min(1000, frame.width - 40), height: min(650, frame.height - 45))
    }

    private func showStatusMenu() {
        let menu = NSMenu()
        let open = NSMenuItem(title: "Open Top of Mind", action: #selector(openPanel), keyEquivalent: "")
        open.target = self
        menu.addItem(open)
        let appearance = NSMenuItem(title: store.isDark ? "Switch to Light Mode" : "Switch to Dark Mode", action: #selector(toggleTheme), keyEquivalent: "")
        appearance.target = self
        menu.addItem(appearance)
        let pin = NSMenuItem(title: "Keep Panel Open", action: #selector(togglePin), keyEquivalent: "")
        pin.target = self
        pin.state = store.snapshot.isPinned ? .on : .off
        menu.addItem(pin)
        menu.addItem(.separator())
        if Bundle.main.bundleURL.pathExtension == "app", !options.demo {
            let login = NSMenuItem(title: "Launch at Login", action: #selector(toggleLogin), keyEquivalent: "")
            login.target = self
            login.state = SMAppService.mainApp.status == .enabled ? .on : .off
            menu.addItem(login)
            menu.addItem(.separator())
        }
        let quit = NSMenuItem(title: "Quit Top of Mind", action: #selector(quitApplication), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func toggleTheme() { store.toggleTheme() }
    @objc private func togglePin() { store.togglePin() }
    @objc private func quitApplication() { NSApp.terminate(nil) }
    @objc private func toggleLogin() {
        do {
            if SMAppService.mainApp.status == .enabled { try SMAppService.mainApp.unregister() }
            else { try SMAppService.mainApp.register() }
        } catch {
            store.errorMessage = "Launch at Login could not be changed. \(error.localizedDescription)"
            openPanel()
        }
    }

    private func showDemoPanel(size: NSSize) {
        let panel = NSPanel(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.contentViewController = contentController
        panel.appearance = NSAppearance(named: store.isDark ? .darkAqua : .aqua)
        panel.title = "Top of Mind"
        panel.center()
        panel.makeKeyAndOrderFront(nil)
        demoPanel = panel
    }

    private func writeSnapshot() {
        guard let path = options.snapshotPath else { return }
        let view = contentController.view
        view.layoutSubtreeIfNeeded()
        guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { snapshotFailed("Could not create image."); return }
        view.cacheDisplay(in: view.bounds, to: bitmap)
        guard let data = bitmap.representation(using: .png, properties: [:]) else { snapshotFailed("Could not encode image."); return }
        do {
            let url = URL(fileURLWithPath: path)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: url, options: .atomic)
            print("Saved Top of Mind demo screenshot to \(path)")
            NSApp.terminate(nil)
        } catch { snapshotFailed(error.localizedDescription) }
    }

    private func snapshotFailed(_ message: String) {
        print("Snapshot failed: \(message)")
        exit(EXIT_FAILURE)
    }
}

@MainActor
final class GlassViewController: NSViewController {
    let effectView = NSVisualEffectView()
    private let hostingView: NSHostingView<BoardView>
    private let initialSize: NSSize

    init(rootView: BoardView, size: NSSize) {
        hostingView = NSHostingView(rootView: rootView)
        initialSize = size
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func loadView() {
        effectView.frame = NSRect(origin: .zero, size: initialSize)
        effectView.material = .popover
        effectView.blendingMode = .behindWindow
        effectView.state = .active
        effectView.wantsLayer = true
        effectView.layer?.cornerRadius = 18
        effectView.layer?.masksToBounds = true
        hostingView.frame = effectView.bounds
        hostingView.autoresizingMask = [.width, .height]
        effectView.addSubview(hostingView)
        view = effectView
    }
}
