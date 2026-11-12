import AppKit
import SwiftUI

// AppKit-hosted windows for Welcome / About / Lock screen setup.
// MenuBarExtra apps have no regular window scene, so these are plain NSWindows.
@MainActor
final class WindowManager {
    static let shared = WindowManager()
    private var windows: [String: NSWindow] = [:]

    func show(id: String, title: String, size: NSSize, @ViewBuilder content: () -> some View) {
        if let existing = windows[id] {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = title
        window.contentView = NSHostingView(rootView: content())
        window.isReleasedWhenClosed = false
        window.center()
        windows[id] = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func close(id: String) {
        windows[id]?.close()
    }

    func showWelcome() {
        let height: CGFloat = WallpaperEngine.shared.lockSynced ? 300 : 410
        show(id: "welcome", title: "Welcome to Daily Wallpaper", size: NSSize(width: 460, height: height)) {
            WelcomeView()
        }
    }

    func showAbout() {
        show(id: "about", title: "About Daily Wallpaper", size: NSSize(width: 380, height: 480)) {
            AboutView()
        }
    }

    func showLockSetup() {
        show(id: "locksetup", title: "Lock Screen Setup", size: NSSize(width: 460, height: 220)) {
            LockSetupView()
        }
    }
}