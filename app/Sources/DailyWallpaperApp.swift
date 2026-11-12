import SwiftUI

@main
struct DailyWallpaperApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuContent(engine: WallpaperEngine.shared)
        } label: {
            Image(systemName: "mountain.2")
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let settings = Settings.shared
        if !settings.welcomeShown {
            settings.welcomeShown = true
            LoginItem.shared.set(true)
            WindowManager.shared.showWelcome()
        }
        WallpaperEngine.shared.start()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}