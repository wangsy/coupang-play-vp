import Foundation
import os

/// Every action the app and the page take, in one place (spec S9).
///
/// Each line goes to three sinks:
/// - unified log (`subsystem coupangplay-vp`) — `log show` / Console.app
/// - stdout, unbuffered — `devicectl device process launch --console` streams it live
/// - `Documents/logs/<launch>/events.log` — `scripts/device-pull.sh` copies it off the device
///
/// Text is passed through `LogRedaction` first. Snapshots of the screen land in the same folder.
final class EventLog: @unchecked Sendable {
    enum Category: String {
        case app, nav, page, ui, media, snap, dialog
    }

    static let shared = EventLog()

    /// This launch's folder: `Documents/logs/<yyMMdd-HHmmss>/`.
    let folder: URL
    private let queue = DispatchQueue(label: "coupangplay-vp.eventlog")
    private let handle: FileHandle?
    private let timestamp: DateFormatter
    private var loggers: [Category: Logger] = [:]
    private static let keptLaunches = 10

    private init() {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let root = documents.appending(path: "logs", directoryHint: .isDirectory)
        let stamp = DateFormatter()
        stamp.locale = Locale(identifier: "en_US_POSIX")
        stamp.dateFormat = "yyMMdd-HHmmss"
        folder = root.appending(path: stamp.string(from: Date()), directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        Self.prune(root, keep: Self.keptLaunches)

        let file = folder.appending(path: "events.log")
        FileManager.default.createFile(atPath: file.path, contents: nil)
        handle = try? FileHandle(forWritingTo: file)

        // The live stream (`devicectl --console`) can go away at any time; writing to a closed pipe must not kill the app.
        signal(SIGPIPE, SIG_IGN)

        timestamp = DateFormatter()
        timestamp.locale = Locale(identifier: "en_US_POSIX")
        timestamp.dateFormat = "HH:mm:ss.SSS"
    }

    func log(_ category: Category, _ message: String) {
        let text = LogRedaction.text(message)
        let now = Date()
        queue.async { [self] in
            let logger = loggers[category] ?? Logger(subsystem: "coupangplay-vp", category: category.rawValue)
            loggers[category] = logger
            logger.notice("\(text, privacy: .public)")
            let line = "\(timestamp.string(from: now)) [\(category.rawValue)] \(text)\n"
            let data = Data(line.utf8)
            // write(contentsOf:) throws a Swift error instead of raising an ObjC exception (12:16 device crash).
            try? FileHandle.standardOutput.write(contentsOf: data)
            try? handle?.write(contentsOf: data)
        }
    }

    /// Writes `data` next to the log and returns its file name.
    func save(_ data: Data, named name: String) -> String {
        let url = folder.appending(path: name)
        queue.async { try? data.write(to: url) }
        return name
    }

    private static func prune(_ root: URL, keep: Int) {
        let folders = (try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)) ?? []
        let old = folders.map(\.lastPathComponent).sorted().dropLast(keep)
        for name in old {
            try? FileManager.default.removeItem(at: root.appending(path: name))
        }
    }
}
