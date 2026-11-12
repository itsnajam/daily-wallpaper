import SwiftUI

// Shown when the lock screen is not synced to the current photo. The user picks
// the current photo once in System Settings with "Show on all Spaces" enabled;
// after that, setting the desktop keeps the lock screen updated.
struct LockScreenTip: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Pick the current photo under Your Photos and turn on Show on all Spaces, once. Find it in Pictures → Daily Wallpaper.")
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
            Button("Open Wallpaper Settings") { LockScreen.openSettings() }
        }
    }
}

struct LockSetupView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Sync the lock screen")
                .font(.title3.bold())
            LockScreenTip()
            HStack {
                Spacer()
                Button("Done") { WindowManager.shared.close(id: "locksetup") }
            }
        }
        .padding(20)
        .frame(width: 460, alignment: .leading)
    }
}

struct WelcomeView: View {
    @ObservedObject var login = LoginItem.shared
    @ObservedObject var engine = WallpaperEngine.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Welcome to Daily Wallpaper")
                .font(.title2.bold())
            Text("A fresh Bing photo on your desktop and lock screen, on your schedule.\nPick your wallpaper types and how often it changes from the menu bar icon.")
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)

            if !engine.lockSynced {
                GroupBox("Lock screen") {
                    LockScreenTip()
                        .padding(6)
                }
            }

            Toggle("Open at Login", isOn: Binding(
                get: { login.isEnabled },
                set: { newValue in login.set(newValue) }
            ))

            HStack {
                Link("Made by najam.dev", destination: URL(string: "https://najam.dev")!)
                    .font(.callout)
                Spacer()
                Button("Get Started") { WindowManager.shared.close(id: "welcome") }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(22)
        .frame(width: 460, alignment: .leading)
    }
}