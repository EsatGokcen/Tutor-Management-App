import Foundation

struct StoragePaths {
    let rootDirectory: URL
    let dataFile: URL

    init(fileManager: FileManager = .default) {
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser
        rootDirectory = documentsDirectory.appendingPathComponent("TutorTable", isDirectory: true)
        dataFile = rootDirectory.appendingPathComponent("tutor-data.json")
    }

    func ensureDirectories() throws {
        try FileManager.default.createDirectory(at: rootDirectory, withIntermediateDirectories: true)
    }
}
