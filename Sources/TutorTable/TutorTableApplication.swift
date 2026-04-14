import AppKit
import Combine
import Foundation

@MainActor
final class TutorTableApplication: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private let showWindowNotification = Notification.Name("com.esatgokcen.tutortable.show-window")
    private weak var appModel: AppModel?
    private weak var window: NSWindow?
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private var didConfigureSystemIntegrations = false
    private var hotKeyTooltipCancellable: AnyCancellable?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.regular)
        configureStatusItem()
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleShowWindowNotification),
            name: showWindowNotification,
            object: nil
        )
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        presentWindow()
        return true
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        return false
    }

    func bind(appModel: AppModel) {
        self.appModel = appModel
        hotKeyTooltipCancellable = appModel.$activeHotKeyDescription
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateStatusItemTooltip()
            }

        guard !didConfigureSystemIntegrations else {
            updateStatusItemTooltip()
            return
        }

        appModel.onPresentWindow = { [weak self] in
            self?.presentWindow()
        }
        appModel.configureSystemIntegrations()
        didConfigureSystemIntegrations = true
        updateStatusItemTooltip()
    }

    func attach(window: NSWindow) {
        let isNewWindow = self.window !== window
        self.window = window
        window.delegate = self
        window.title = "TutorTable"
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 1120, height: 760)
        window.collectionBehavior.insert(.moveToActiveSpace)

        if isNewWindow {
            window.setContentSize(NSSize(width: 1180, height: 780))
            window.center()
            presentWindow()
        }
    }

    @objc
    func presentWindow() {
        guard let window else {
            NSApplication.shared.activate(ignoringOtherApps: true)
            return
        }

        NSApplication.shared.unhide(nil)
        if !window.isVisible {
            window.center()
        }
        if window.isMiniaturized {
            window.deminiaturize(nil)
        }

        NSApplication.shared.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }

    @objc
    private func handleShowWindowNotification() {
        presentWindow()
    }

    @objc
    private func openDataFolder() {
        appModel?.openDataFolder()
    }

    @objc
    private func addSampleData() {
        appModel?.addSampleData()
        presentWindow()
    }

    @objc
    private func openFromStatusItem() {
        presentWindow()
    }

    @objc
    private func quitApplication() {
        NSApplication.shared.terminate(nil)
    }

    private func configureStatusItem() {
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "graduationcap.circle.fill", accessibilityDescription: "TutorTable")
            button.title = " TutorTable"
            button.toolTip = "TutorTable"
        }

        let menu = NSMenu()
        let openItem = NSMenuItem(title: "Open TutorTable", action: #selector(openFromStatusItem), keyEquivalent: "")
        openItem.target = self
        menu.addItem(openItem)

        let sampleItem = NSMenuItem(title: "Add Sample Data", action: #selector(addSampleData), keyEquivalent: "")
        sampleItem.target = self
        menu.addItem(sampleItem)

        let dataFolderItem = NSMenuItem(title: "Open Data Folder", action: #selector(openDataFolder), keyEquivalent: "")
        dataFolderItem.target = self
        menu.addItem(dataFolderItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit TutorTable", action: #selector(quitApplication), keyEquivalent: "")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    private func updateStatusItemTooltip() {
        guard let button = statusItem.button else {
            return
        }

        if let appModel {
            button.toolTip = "TutorTable. Use the menu bar icon or \(appModel.activeHotKeyDescription) to reopen the app."
        } else {
            button.toolTip = "TutorTable"
        }
    }

    deinit {
        DistributedNotificationCenter.default().removeObserver(self)
    }
}
