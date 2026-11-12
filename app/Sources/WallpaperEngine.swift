import AppKit
import Combine
import Foundation

struct BingImage {
    let urlbase: String
    let title: String
    let copyright: String
    let fullstartdate: String
    let market: String

    var id: String { urlbase.components(separatedBy: "id=").last ?? urlbase }
    var downloadURL: URL? { URL(string: "https://www.bing.com" + urlbase + "_UHD.jpg") }
}

@MainActor
final class WallpaperEngine: ObservableObject {
    static let shared = WallpaperEngine()

    @Published var thumbnail: NSImage?
    @Published var title: String
    @Published var copyright: String
    @Published var status: String = ""
    @Published var isFetching = false
    @Published var lockSynced = false
    @Published var automationDenied = false

    let settings = Settings.shared

    private var timer: Timer?
    private var syncTimer: Timer?
    private var wakeObserver: NSObjectProtocol?
    private let markets = ["en-US", "en-GB", "en-CA", "en-AU", "en-IN"]
    private let session: URLSession

    var storeDir: URL {
        URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/Application Support/DailyWallpaper", isDirectory: true)
    }
    var currentImageURL: URL {
        URL(fileURLWithPath: settings.currentImagePath)
    }

    private init() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 20
        config.timeoutIntervalForResource = 90
        session = URLSession(configuration: config)
        title = settings.currentTitle
        copyright = settings.currentCopyright
        loadThumbnail()
        refreshLockState()
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.fetchIfDue(reason: "wake") }
        }
    }

    func start() {
        makePicturesSymlink()
        rescheduleTimer()
        // The wallpaper store flushes lazily, so keep the sync indicator current
        // rather than relying on the menu's onAppear (which fires only once).
        let st = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshLockState() }
        }
        st.tolerance = 1
        RunLoop.main.add(st, forMode: .common)
        syncTimer = st
        fetchIfDue(reason: "launch")
    }

    // System Settings' photo picker hides ~/Library, so expose the store folder
    // under ~/Pictures for the one-time lock screen pick.
    private func makePicturesSymlink() {
        let fm = FileManager.default
        let pictures = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Pictures", isDirectory: true)
        let link = pictures.appendingPathComponent("Daily Wallpaper")
        try? fm.createDirectory(at: pictures, withIntermediateDirectories: true)
        if !fm.fileExists(atPath: link.path) {
            try? fm.createSymbolicLink(at: link, withDestinationURL: storeDir)
        }
    }

    // MARK: - Scheduling

    func rescheduleTimer() {
        timer?.invalidate()
        timer = nil
        let hours = settings.intervalHours
        guard hours > 0 else { return }
        let interval = TimeInterval(hours) * 3600
        let t = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.fetchIfDue(reason: "timer") }
        }
        t.tolerance = interval * 0.1
        RunLoop.main.add(t, forMode: .common)
        timer = t
        Log.write("Timer set: every \(hours)h")
    }

    func intervalChanged() {
        rescheduleTimer()
        fetchIfDue(reason: "interval")
    }

    func fetchIfDue(reason: String) {
        let hours = settings.intervalHours
        guard hours > 0 else { return }
        if let last = settings.lastChange,
           Date().timeIntervalSince(last) < TimeInterval(hours) * 3600 {
            return
        }
        fetchNow(reason: reason)
    }

    func fetchNow(reason: String) {
        guard !isFetching else { return }
        isFetching = true
        status = "Fetching…"
        Task { await runFetch(reason: reason) }
    }

    // MARK: - Fetch and apply

    private func runFetch(reason: String) async {
        defer { isFetching = false }
        let pool = await fetchPool()
        if pool.images.isEmpty && pool.successes == 0 {
            status = "Offline, keeping current wallpaper"
            Log.write("Network: could not reach Bing. Keeping current wallpaper.")
            return
        }
        let history = Set(settings.history)
        let currentBase = settings.currentURLBase
        let types = settings.types
        // The same scene appears in several markets under different urlbases
        // (and sometimes a generic title like "Info"); dedup by scene too.
        let historyScenes = Set(settings.history.map { sceneKey($0) })
        let currentScene = sceneKey(currentBase)
        let candidates = pool.images
            .filter { !history.contains($0.urlbase) && $0.urlbase != currentBase }
            .filter { !historyScenes.contains(sceneKey($0.urlbase)) && sceneKey($0.urlbase) != currentScene }
            .filter { Categories.matches(title: $0.title, copyright: $0.copyright, types: types) }
            .sorted { $0.fullstartdate > $1.fullstartdate }
        guard let pick = candidates.first else {
            let label = Categories.label(for: types)
            status = label.isEmpty
                ? "No new photo yet, will try again later"
                : "No new \(label) photo yet, will try again later"
            Log.write("No new photo for types [\(types.joined(separator: ","))]. Keeping current wallpaper.")
            return
        }
        do {
            try await apply(pick)
            status = ""
        } catch {
            status = "Download failed, keeping current wallpaper"
            Log.write("Failed to apply \(pick.urlbase): \(error.localizedDescription)")
        }
    }

    private func apply(_ image: BingImage) async throws {
        guard let url = image.downloadURL else {
            throw NSError(domain: "DailyWallpaper", code: 1, userInfo: [NSLocalizedDescriptionKey: "bad URL"])
        }
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw NSError(domain: "DailyWallpaper", code: 2, userInfo: [NSLocalizedDescriptionKey: "bad HTTP status"])
        }
        guard data.count >= 100_000, data.starts(with: [0xFF, 0xD8, 0xFF]), NSImage(data: data) != nil else {
            throw NSError(domain: "DailyWallpaper", code: 3, userInfo: [NSLocalizedDescriptionKey: "not a valid JPEG"])
        }

        let fm = FileManager.default
        try fm.createDirectory(at: storeDir, withIntermediateDirectories: true)
        let tmp = storeDir.appendingPathComponent(".incoming.jpg")
        try? fm.removeItem(at: tmp)
        try data.write(to: tmp)

        // Store the photo under its own name. Setting the desktop from a fresh
        // path always refreshes it, and (when the lock screen is a normal image)
        // macOS moves the lock screen entry to this new file on its own.
        let final = storeDir.appendingPathComponent("\(image.id).jpg")
        try? fm.removeItem(at: final)
        try fm.moveItem(at: tmp, to: final)

        // Set the desktop (and, after the one-time pick, the lock screen) via
        // System Events. The NSWorkspace per-screen setter only moves the desktop
        // and drops the "Show on all Spaces" link, so it is not used.
        guard await setDesktopViaSystemEvents(final) else {
            try? fm.removeItem(at: final)
            throw NSError(domain: "DailyWallpaper", code: 4, userInfo: [NSLocalizedDescriptionKey: "could not set desktop"])
        }

        // Keep the current photo and whatever the lock screen still points at;
        // the latter is deleted on a later run once the lock screen moves on.
        let lockPath = LockScreen.systemDefaultImageURL()?.standardizedFileURL.path
        if let files = try? fm.contentsOfDirectory(at: storeDir, includingPropertiesForKeys: nil) {
            for f in files where f.pathExtension.lowercased() == "jpg" {
                if f.lastPathComponent == final.lastPathComponent { continue }
                if let lockPath, lockPath == f.standardizedFileURL.path { continue }
                try? fm.removeItem(at: f)
            }
        }

        settings.currentImagePath = final.path
        settings.currentURLBase = image.urlbase
        settings.currentTitle = image.title
        settings.currentCopyright = image.copyright
        settings.lastChange = Date()
        var h = settings.history
        h.append(image.urlbase)
        settings.history = h
        title = image.title
        copyright = image.copyright
        loadThumbnail()
        refreshLockState()
        Log.write("Set wallpaper: \(image.title) | \(image.copyright)")
    }

    private func setDesktopViaSystemEvents(_ url: URL) async -> Bool {
        let escaped = url.path
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let source = "tell application \"System Events\" to tell every desktop to set picture to POSIX file \"\(escaped)\""

        // In-process first; macOS asks for Automation permission once on first use.
        var scriptError: NSDictionary?
        NSAppleScript(source: source)?.executeAndReturnError(&scriptError)
        if scriptError == nil {
            automationDenied = false
            return true
        }
        if let code = scriptError?[NSAppleScript.errorNumber] as? Int, code == -1743 {
            automationDenied = true
        }

        // Fallback to the osascript binary.
        let ok = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            DispatchQueue.global().async {
                let p = Process()
                p.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
                p.arguments = ["-e", source]
                do {
                    try p.run()
                    p.waitUntilExit()
                    continuation.resume(returning: p.terminationStatus == 0)
                } catch {
                    continuation.resume(returning: false)
                }
            }
        }
        if ok { automationDenied = false }
        return ok
    }

    private func sceneKey(_ urlbase: String) -> String {
        let id = urlbase.components(separatedBy: "id=").last ?? urlbase
        return id.components(separatedBy: "_").first ?? id
    }

    // MARK: - State

    func refreshLockState() {
        let synced = LockScreen.isSynced(to: currentImageURL)
        if synced != lockSynced {
            Log.write("lock screen synced=\(synced)")
        }
        lockSynced = synced
    }

    private func loadThumbnail() {
        let path = settings.currentImagePath
        guard !path.isEmpty, let img = NSImage(contentsOfFile: path) else {
            thumbnail = nil
            return
        }
        let target = NSSize(width: 480, height: 270)
        let small = NSImage(size: target)
        small.lockFocus()
        img.draw(in: NSRect(origin: .zero, size: target), from: .zero, operation: .copy, fraction: 1)
        small.unlockFocus()
        thumbnail = small
    }

    // MARK: - Feed

    private func fetchPool() async -> (images: [BingImage], successes: Int) {
        await withTaskGroup(of: [BingImage]?.self) { group in
            for mkt in markets {
                for idx in [0, 8] {
                    group.addTask { [session] in
                        guard let url = URL(string: "https://www.bing.com/HPImageArchive.aspx?format=js&idx=\(idx)&n=8&mkt=\(mkt)") else { return nil }
                        guard let (data, resp) = try? await session.data(from: url),
                              let http = resp as? HTTPURLResponse, http.statusCode == 200,
                              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                              let arr = obj["images"] as? [[String: Any]] else { return nil }
                        return arr.compactMap { item -> BingImage? in
                            guard let ub = item["urlbase"] as? String, !ub.isEmpty else { return nil }
                            return BingImage(
                                urlbase: ub,
                                title: item["title"] as? String ?? "",
                                copyright: item["copyright"] as? String ?? "",
                                fullstartdate: item["fullstartdate"] as? String ?? (item["startdate"] as? String ?? ""),
                                market: mkt
                            )
                        }
                    }
                }
            }
            var seen = Set<String>()
            var images: [BingImage] = []
            var successes = 0
            for await result in group {
                guard let result else { continue }
                successes += 1
                for img in result where !seen.contains(img.urlbase) {
                    seen.insert(img.urlbase)
                    images.append(img)
                }
            }
            // One entry per scene, preferring en-US and a real title over the
            // generic "Info" some markets return for the same photo.
            let ranked = images.sorted { a, b in
                func score(_ x: BingImage) -> (Int, Int) {
                    (x.market == "en-US" ? 0 : 1, (x.title.isEmpty || x.title == "Info") ? 1 : 0)
                }
                return score(a) < score(b)
            }
            var seenScene = Set<String>()
            var best: [BingImage] = []
            for img in ranked {
                let key = sceneKey(img.urlbase)
                if seenScene.contains(key) { continue }
                seenScene.insert(key)
                best.append(img)
            }
            return (best, successes)
        }
    }
}