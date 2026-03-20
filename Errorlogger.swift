import Foundation
import AppKit

class ErrorLogger {
    static let shared = ErrorLogger()
    private let logDir: URL
    private let ts   = DateFormatter()
    private let file = DateFormatter()

    private init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        logDir = docs.appendingPathComponent("AeroutAuto/Logs", isDirectory: true)
        try? FileManager.default.createDirectory(at: logDir, withIntermediateDirectories: true)
        ts.dateFormat   = "yyyy-MM-dd HH:mm:ss.SSS"
        file.dateFormat = "yyyy-MM-dd"
    }

    func log(_ msg: String, level: String = "INFO", f: String = #file, l: Int = #line) {
        let now = Date()
        let src = URL(fileURLWithPath: f).lastPathComponent
        write("[\(ts.string(from: now))] [\(level)] [\(src):\(l)] \(msg)\n", date: now)
    }

    func error(_ err: Error, context: String = "", f: String = #file, l: Int = #line) {
        log("\(context.isEmpty ? "" : "[\(context)] ")\(err.localizedDescription)", level: "ERROR", f: f, l: l)
    }

    private func write(_ text: String, date: Date) {
        let name = "AeroutAuto_\(file.string(from: date)).log"
        let url  = logDir.appendingPathComponent(name)
        guard let data = text.data(using: .utf8) else { return }
        if FileManager.default.fileExists(atPath: url.path) {
            if let h = try? FileHandle(forWritingTo: url) { h.seekToEndOfFile(); h.write(data); h.closeFile() }
        } else {
            let header = "=== Aerout Auto Log | \(date) | \(ProcessInfo.processInfo.operatingSystemVersionString) ===\n=== Bug reports: Discord 5qvx ===\n\n"
            try? (header + text).data(using: .utf8)?.write(to: url)
        }
    }

    var logFiles: [URL] {
        (try? FileManager.default.contentsOfDirectory(at: logDir, includingPropertiesForKeys: nil, options: .skipsHiddenFiles))?
            .filter { $0.pathExtension == "log" }
            .sorted { $0.lastPathComponent > $1.lastPathComponent } ?? []
    }

    func revealInFinder() { NSWorkspace.shared.open(logDir) }
}
