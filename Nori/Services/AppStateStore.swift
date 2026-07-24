import Foundation

actor AppStateStore {
    private let fileManager: FileManager
    private let stateURL: URL
    private var latestRevision: UInt64 = 0

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        let baseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        stateURL = baseURL.appending(path: "Nori", directoryHint: .isDirectory)
            .appending(path: "state.json", directoryHint: .notDirectory)
    }

    func load() throws -> PersistedAppState? {
        guard fileManager.fileExists(atPath: stateURL.path()) else { return nil }
        let data = try Data(contentsOf: stateURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(PersistedAppState.self, from: data)
    }

    func save(_ state: PersistedAppState, revision: UInt64) throws {
        guard revision >= latestRevision else { return }
        latestRevision = revision
        let directory = stateURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(state)
        try data.write(to: stateURL, options: [.atomic, .completeFileProtectionUnlessOpen])
    }
}
