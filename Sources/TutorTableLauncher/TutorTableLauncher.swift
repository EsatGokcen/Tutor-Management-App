import AppKit
import Foundation

struct LauncherHotKeyStatus: Codable {
    var displayName: String
    var didRegister: Bool
    var registrationErrorCode: Int32?
    var updatedAt: Date
    var lastActivatedAt: Date?
}

struct LauncherStatusPaths {
    let rootDirectory: URL
    let statusFile: URL

    init(fileManager: FileManager = .default) {
        let applicationSupportDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser
        rootDirectory = applicationSupportDirectory
            .appendingPathComponent("TutorTable", isDirectory: true)
            .appendingPathComponent("System", isDirectory: true)
        statusFile = rootDirectory.appendingPathComponent("hotkey-status.json")
    }

    func ensureDirectories() throws {
        try FileManager.default.createDirectory(at: rootDirectory, withIntermediateDirectories: true)
    }
}

final class TutorTableLauncher: NSObject, NSApplicationDelegate {
    private let hotKeyManager = LauncherHotKeyManager()
    private let statusPaths = LauncherStatusPaths()
    private let mainAppBundleIdentifier = "com.esatgokcen.tutortable"
    private let showWindowNotification = Notification.Name("com.esatgokcen.tutortable.show-window")
    private var lastActivatedAt: Date?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)

        let result = hotKeyManager.registerPreferredShortcut { [weak self] in
            self?.openTutorTable()
        }
        NSLog(
            "TutorTableLauncher registered hotkey '\(result.displayName)' success=\(result.didRegister) error=\(result.registrationErrorCode ?? 0)"
        )
        writeStatus(
            displayName: result.displayName,
            didRegister: result.didRegister,
            registrationErrorCode: result.registrationErrorCode
        )
    }

    private func openTutorTable() {
        lastActivatedAt = Date()
        writeStatusSnapshot()
        NSLog("TutorTableLauncher hotkey activated")

        if let runningApp = NSRunningApplication.runningApplications(withBundleIdentifier: mainAppBundleIdentifier).first {
            DistributedNotificationCenter.default().postNotificationName(
                showWindowNotification,
                object: nil,
                userInfo: nil,
                deliverImmediately: true
            )
            runningApp.activate(options: [.activateIgnoringOtherApps])
            return
        }

        guard let tutorTableURL = mainAppURL else {
            return
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        configuration.createsNewApplicationInstance = false

        NSWorkspace.shared.openApplication(at: tutorTableURL, configuration: configuration) { _, _ in }
    }

    private func writeStatus(displayName: String, didRegister: Bool, registrationErrorCode: Int32?) {
        do {
            try statusPaths.ensureDirectories()
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(
                LauncherHotKeyStatus(
                    displayName: displayName,
                    didRegister: didRegister,
                    registrationErrorCode: registrationErrorCode,
                    updatedAt: Date(),
                    lastActivatedAt: lastActivatedAt
                )
            )
            try data.write(to: statusPaths.statusFile, options: .atomic)
        } catch {
            NSLog("TutorTableLauncher could not write hotkey status: \(error.localizedDescription)")
        }
    }

    private func writeStatusSnapshot() {
        guard let data = try? Data(contentsOf: statusPaths.statusFile),
              var status = try? JSONDecoder.launcherDecoder.decode(LauncherHotKeyStatus.self, from: data) else {
            return
        }

        status.updatedAt = Date()
        status.lastActivatedAt = lastActivatedAt

        do {
            try statusPaths.ensureDirectories()
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(status).write(to: statusPaths.statusFile, options: .atomic)
        } catch {
            NSLog("TutorTableLauncher could not refresh hotkey status: \(error.localizedDescription)")
        }
    }

    private var mainAppURL: URL? {
        Bundle.main.bundleURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}

private extension JSONDecoder {
    static var launcherDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
