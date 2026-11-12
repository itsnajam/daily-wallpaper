import SwiftUI

struct MenuContent: View {
    @ObservedObject var engine: WallpaperEngine
    @ObservedObject var settings = Settings.shared
    @ObservedObject var login = LoginItem.shared

    private let intervals: [(hours: Int, label: String)] = [
        (1, "1 hour"), (3, "3 hours"), (6, "6 hours"),
        (12, "12 hours"), (24, "24 hours"), (0, "Manual only"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            if let img = engine.thumbnail {
                Image(nsImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 248, height: 140)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            Text(engine.title.isEmpty ? "Daily Wallpaper" : engine.title)
                .font(.headline)
                .lineLimit(2)
            Text(engine.copyright)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(EdgeInsets(top: 8, leading: 12, bottom: 4, trailing: 12))
        .frame(width: 272, alignment: .leading)

        if !engine.status.isEmpty {
            Text(engine.status)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
        }

        Divider()

        Button("Next wallpaper") { engine.fetchNow(reason: "manual") }
            .disabled(engine.isFetching)

        Menu("Change every") {
            ForEach(intervals, id: \.hours) { option in
                Button {
                    settings.intervalHours = option.hours
                    engine.intervalChanged()
                } label: {
                    HStack {
                        Image(systemName: "checkmark")
                            .opacity(settings.intervalHours == option.hours ? 1 : 0)
                        Text(option.label)
                    }
                }
            }
        }

        Menu("Wallpaper types") {
            ForEach(Categories.all, id: \.id) { type in
                Toggle(type.name, isOn: Binding(
                    get: { settings.types.contains(type.id) },
                    set: { _ in settings.toggleType(type.id) }
                ))
            }
            Divider()
            Toggle(Categories.everythingName, isOn: Binding(
                get: { settings.types.contains(Categories.everythingID) },
                set: { _ in settings.toggleType(Categories.everythingID) }
            ))
        }

        Divider()

        Toggle("Open at Login", isOn: Binding(
            get: { login.isEnabled },
            set: { newValue in login.set(newValue) }
        ))

        if engine.automationDenied {
            Button("Allow Daily Wallpaper to control System Events") {
                LockScreen.openAutomationSettings()
            }
        }

        Button {
            if !engine.lockSynced { WindowManager.shared.showLockSetup() }
        } label: {
            Text(engine.lockSynced ? "Lock screen: synced ✓" : "Lock screen not synced, click to fix")
        }
        .disabled(engine.lockSynced)

        Button("About Daily Wallpaper") { WindowManager.shared.showAbout() }

        Divider()

        Button("Quit Daily Wallpaper") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
            .onAppear {
                login.refresh()
                engine.refreshLockState()
            }
    }
}