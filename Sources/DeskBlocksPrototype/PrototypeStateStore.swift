import DeskBlocksCore
import Foundation

final class PrototypeStateStore {
    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? Self.defaultFileURL()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    func load() -> DeskBlocksState? {
        do {
            let data = try Data(contentsOf: fileURL)
            if let state = try? decoder.decode(DeskBlocksState.self, from: data) {
                return state
            }

            let legacyBlock = try decoder.decode(DeskBlockState.self, from: data)
            return DeskBlocksState(blocks: [legacyBlock])
        } catch CocoaError.fileReadNoSuchFile {
            return nil
        } catch {
            fputs("DeskBlocksPrototype: failed to load state: \(error)\n", stderr)
            return nil
        }
    }

    func save(_ state: DeskBlocksState) {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try encoder.encode(state)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            fputs("DeskBlocksPrototype: failed to save state: \(error)\n", stderr)
        }
    }

    private static func defaultFileURL() -> URL {
        let baseURL = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")

        return baseURL
            .appendingPathComponent("DeskBlocks", isDirectory: true)
            .appendingPathComponent("prototype-state.json")
    }
}
