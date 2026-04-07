import Foundation

struct StoragePaths {
    let rootDirectory: URL
    let dataFile: URL
    let audioDirectory: URL

    init(fileManager: FileManager = .default) {
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser
        rootDirectory = documentsDirectory.appendingPathComponent("TutorTable", isDirectory: true)
        dataFile = rootDirectory.appendingPathComponent("tutor-data.json")
        audioDirectory = rootDirectory.appendingPathComponent("AudioNotes", isDirectory: true)
    }

    func ensureDirectories() throws {
        try FileManager.default.createDirectory(at: rootDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: audioDirectory, withIntermediateDirectories: true)
    }
}
