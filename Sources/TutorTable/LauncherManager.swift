import AppKit
import Foundation

struct LauncherHotKeyStatus: Codable {
    var displayName: String
    var didRegister: Bool
}

final class LauncherManager {
    private let statusFile: URL

    init(rootDirectory: URL) {
        statusFile = rootDirectory.appendingPathComponent("hotkey-status.json")
    }

    func startLauncherIfNeeded() {
        guard let launcherURL = launcherAppURL, FileManager.default.fileExists(atPath: launcherURL.path) else {
            return
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        configuration.createsNewApplicationInstance = false

        NSWorkspace.shared.openApplication(at: launcherURL, configuration: configuration) { _, _ in }
    }

    func loadStatus() -> LauncherHotKeyStatus? {
        guard let data = try? Data(contentsOf: statusFile) else {
            return nil
        }

        return try? JSONDecoder().decode(LauncherHotKeyStatus.self, from: data)
    }

    var fallbackDisplayName: String {
        "Command + Option + M"
    }

    private var launcherAppURL: URL? {
        Bundle.main.resourceURL?.appendingPathComponent("TutorTableLauncher.app", isDirectory: true)
    }
}
