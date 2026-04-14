import AppKit
import Foundation

struct LauncherHotKeyStatus: Codable {
    var displayName: String
    var didRegister: Bool
}

final class LauncherManager {
    private let launcherBundleIdentifier = "com.esatgokcen.tutortable.launcher"
    private let statusFile: URL

    init(fileManager: FileManager = .default) {
        let applicationSupportDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser
        statusFile = applicationSupportDirectory
            .appendingPathComponent("TutorTable", isDirectory: true)
            .appendingPathComponent("System", isDirectory: true)
            .appendingPathComponent("hotkey-status.json")
    }

    func startLauncherIfNeeded() {
        guard let launcherURL = launcherAppURL, FileManager.default.fileExists(atPath: launcherURL.path) else {
            return
        }

        for runningApp in NSRunningApplication.runningApplications(withBundleIdentifier: launcherBundleIdentifier) {
            runningApp.forceTerminate()
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        configuration.createsNewApplicationInstance = true

        NSWorkspace.shared.openApplication(at: launcherURL, configuration: configuration) { _, _ in }
    }

    func loadStatus() -> LauncherHotKeyStatus? {
        guard let data = try? Data(contentsOf: statusFile) else {
            return nil
        }

        return try? JSONDecoder().decode(LauncherHotKeyStatus.self, from: data)
    }

    var fallbackDisplayName: String {
        "Command + Option + T"
    }

    private var launcherAppURL: URL? {
        Bundle.main.resourceURL?.appendingPathComponent("TutorTableLauncher.app", isDirectory: true)
    }
}
