import Foundation
import ServiceManagement

final class LoginItem: ObservableObject {
    static let shared = LoginItem()

    @Published var isEnabled: Bool

    private init() {
        isEnabled = SMAppService.mainApp.status == .enabled
    }

    func refresh() {
        isEnabled = SMAppService.mainApp.status == .enabled
    }

    func set(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            Log.write("Open at Login change failed: \(error.localizedDescription)")
        }
        refresh()
    }
}

// Small observable flag for view-local state. @State's initializer is a SwiftUI
// macro that the Command Line Tools do not ship, so views use @StateObject instead.
final class Flag: ObservableObject {
    @Published var on: Bool
    init(_ on: Bool) { self.on = on }
}