import AppKit
import Foundation

struct LauncherHotKeyStatus: Codable {
    var displayName: String
    var didRegister: Bool
}

struct LauncherStatusPaths {
    let rootDirectory: URL
    let statusFile: URL

    init(fileManager: FileManager = .default) {
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser
        rootDirectory = documentsDirectory.appendingPathComponent("TutorTable", isDirectory: true)
        statusFile = rootDirectory.appendingPathComponent("hotkey-status.json")
    }

    func ensureDirectories() throws {
        try FileManager.default.createDirectory(at: rootDirectory, withIntermediateDirectories: true)
    }
}

@main
final class TutorTableLauncher: NSObject, NSApplicationDelegate {
    private let hotKeyManager = LauncherHotKeyManager()
    private let statusPaths = LauncherStatusPaths()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)

        let result = hotKeyManager.registerPreferredShortcut { [weak self] in
            self?.openTutorTable()
        }
        writeStatus(displayName: result.displayName, didRegister: result.didRegister)
    }

    private func openTutorTable() {
        guard let tutorTableURL = mainAppURL else {
            return
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        configuration.createsNewApplicationInstance = false

        NSWorkspace.shared.openApplication(at: tutorTableURL, configuration: configuration) { _, _ in }
    }

    private func writeStatus(displayName: String, didRegister: Bool) {
        do {
            try statusPaths.ensureDirectories()
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(LauncherHotKeyStatus(displayName: displayName, didRegister: didRegister))
            try data.write(to: statusPaths.statusFile, options: .atomic)
        } catch {
            // The launcher remains usable even if status persistence fails.
        }
    }

    private var mainAppURL: URL? {
        Bundle.main.bundleURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
