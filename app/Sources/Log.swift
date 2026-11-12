import Foundation

enum Log {
    private static let fileURL = URL(fileURLWithPath: NSHomeDirectory())
        .appendingPathComponent("Library/Logs/DailyWallpaper.log")
    private static let queue = DispatchQueue(label: "dev.najam.dailywallpaper.log")

    static func write(_ message: String) {
        queue.async {
            let stamp = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .medium)
            let line = "\(stamp) | \(message)\n"
            let fm = FileManager.default
            try? fm.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            if let handle = try? FileHandle(forWritingTo: fileURL) {
                defer { try? handle.close() }
                _ = try? handle.seekToEnd()
                try? handle.write(contentsOf: Data(line.utf8))
            } else {
                try? line.data(using: .utf8)?.write(to: fileURL)
            }
            trim()
        }
    }

    private static func trim() {
        guard let data = try? Data(contentsOf: fileURL),
              let text = String(data: data, encoding: .utf8) else { return }
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        if lines.count > 200 {
            let kept = lines.suffix(200).joined(separator: "\n")
            try? kept.data(using: .utf8)?.write(to: fileURL)
        }
    }
}