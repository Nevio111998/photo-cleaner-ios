import Foundation

struct SavedState: Codable {
    var version = 1
    var records: [PhotoRecord] = []
    var decisions: [String: Decision] = [:]
}

enum Persistence {
    static var url: URL {
        get throws {
            let directory = try FileManager.default.url(for: .applicationSupportDirectory,
                in: .userDomainMask, appropriateFor: nil, create: true)
            return directory.appendingPathComponent("PhotoCleaner-state.json")
        }
    }
    static func load() throws -> SavedState {
        let path = try url
        guard FileManager.default.fileExists(atPath: path.path) else { return SavedState() }
        let state = try JSONDecoder().decode(SavedState.self, from: Data(contentsOf: path))
        guard state.version == 1 else { return SavedState() }
        return state
    }
    static func save(_ state: SavedState) throws {
        let path = try url
        try JSONEncoder().encode(state).write(to: path, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        var protectedURL = path
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try protectedURL.setResourceValues(values)
    }
}
