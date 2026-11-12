import Foundation
import Combine

final class Settings: ObservableObject {
    static let shared = Settings()

    private let defaults = UserDefaults.standard

    @Published var types: [String] {
        didSet { defaults.set(types, forKey: "types") }
    }
    @Published var intervalHours: Int {
        didSet { defaults.set(intervalHours, forKey: "intervalHours") }
    }

    init() {
        defaults.register(defaults: [
            "types": ["landscapes"],
            "intervalHours": 12,
        ])
        types = defaults.stringArray(forKey: "types") ?? ["landscapes"]
        intervalHours = defaults.integer(forKey: "intervalHours")
        if types.isEmpty { types = ["landscapes"] }
    }

    var history: [String] {
        get { defaults.stringArray(forKey: "history") ?? [] }
        set { defaults.set(Array(newValue.suffix(30)), forKey: "history") }
    }

    var lastChange: Date? {
        get { defaults.object(forKey: "lastChange") as? Date }
        set { defaults.set(newValue, forKey: "lastChange") }
    }

    var currentURLBase: String {
        get { defaults.string(forKey: "currentURLBase") ?? "" }
        set { defaults.set(newValue, forKey: "currentURLBase") }
    }
    var currentImagePath: String {
        get { defaults.string(forKey: "currentImagePath") ?? "" }
        set { defaults.set(newValue, forKey: "currentImagePath") }
    }
    var currentTitle: String {
        get { defaults.string(forKey: "currentTitle") ?? "" }
        set { defaults.set(newValue, forKey: "currentTitle") }
    }
    var currentCopyright: String {
        get { defaults.string(forKey: "currentCopyright") ?? "" }
        set { defaults.set(newValue, forKey: "currentCopyright") }
    }

    var welcomeShown: Bool {
        get { defaults.bool(forKey: "welcomeShown") }
        set { defaults.set(newValue, forKey: "welcomeShown") }
    }

    // Toggling rules: "Everything" is exclusive, and at least one type stays on.
    func toggleType(_ id: String) {
        var current = types
        if id == Categories.everythingID {
            current = [Categories.everythingID]
        } else if current.contains(id) {
            if current.count > 1 {
                current.removeAll { $0 == id }
            }
        } else {
            current.removeAll { $0 == Categories.everythingID }
            current.append(id)
        }
        types = current
    }
}