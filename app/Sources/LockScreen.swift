import AppKit
import Foundation

// Read-only inspection of the wallpaper store. On macOS 27 the lock screen is
// the SystemDefault.Desktop entry in
// ~/Library/Application Support/com.apple.wallpaper/Store/Index.plist. We never
// write to this store. Setting the desktop via System Events moves this entry
// once the user has picked a photo with "Show on all Spaces" enabled.
enum LockScreen {
    static let imageProvider = "com.apple.wallpaper.choice.image"

    static var storeURL: URL {
        URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/Application Support/com.apple.wallpaper/Store/Index.plist")
    }

    private static func systemDefaultChoice() -> [String: Any]? {
        guard let data = try? Data(contentsOf: storeURL),
              let root = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let systemDefault = root["SystemDefault"] as? [String: Any],
              let desktop = systemDefault["Desktop"] as? [String: Any],
              let content = desktop["Content"] as? [String: Any],
              let choices = content["Choices"] as? [[String: Any]],
              let first = choices.first
        else { return nil }
        return first
    }

    static func systemDefaultProvider() -> String? {
        systemDefaultChoice()?["Provider"] as? String
    }

    static func systemDefaultImageURL() -> URL? {
        guard let choice = systemDefaultChoice(),
              let cfgData = choice["Configuration"] as? Data,
              let cfg = try? PropertyListSerialization.propertyList(from: cfgData, format: nil) as? [String: Any],
              let urlDict = cfg["url"] as? [String: Any],
              let relative = urlDict["relative"] as? String,
              let url = URL(string: relative)
        else { return nil }
        return url
    }

    // Honest sync: the lock screen must be a normal image AND point at the app's
    // current photo. Anything else (an Aerial, or a stale file) is not synced.
    static func isSynced(to current: URL) -> Bool {
        guard systemDefaultProvider() == imageProvider,
              let lockURL = systemDefaultImageURL()
        else { return false }
        return lockURL.standardizedFileURL.path == current.standardizedFileURL.path
    }

    static func openSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Wallpaper-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }

    static func openAutomationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
            NSWorkspace.shared.open(url)
        }
    }
}