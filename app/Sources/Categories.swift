import Foundation

// Wallpaper types and their keyword lists. Edit these to taste.
// Matching is case-insensitive, whole-word, and tolerates simple plurals
// (mountain -> mountains, arch -> arches). Multi-word entries are phrases.
// A photo matches a type when its title + copyright contains an include
// word and none of that type's exclude words. "Everything" disables filtering.

struct WallpaperType {
    let id: String
    let name: String
    let include: [String]
    let exclude: [String]
}

enum Categories {
    static let everythingID = "everything"
    static let everythingName = "Everything"

    static let all: [WallpaperType] = [
        WallpaperType(
            id: "landscapes",
            name: "Landscapes",
            include: [
                "mountain", "peak", "summit", "valley", "lake", "river", "waterfall",
                "falls", "forest", "woods", "canyon", "desert", "dunes", "coast",
                "beach", "cliff", "island", "bay", "glacier", "fjord", "national park",
                "meadow", "hills", "aurora", "arch", "trail", "crag",
            ],
            exclude: [
                "flag", "lantern", "festival", "diwali", "city", "district", "street",
                "church", "cathedral", "museum", "bridge", "building", "tower",
                "skyline", "market", "town", "village", "castle", "palace", "temple",
                "monument", "statue", "boat", "ship", "car", "train", "people", "crowd",
                "bison", "bear", "bird", "fox", "whale", "penguin", "owl", "deer",
                "elephant", "lion", "tiger", "wolf", "eagle", "horse", "cow", "sheep",
                "goat", "monkey", "snake", "lizard", "turtle", "frog", "shark",
                "dolphin", "seal", "otter", "squirrel", "rabbit", "hare", "butterfly",
                "bee", "camel", "kangaroo", "koala", "panda", "leopard", "cheetah",
                "zebra", "giraffe", "hippo", "rhino", "crocodile", "alligator",
                "flamingo", "swan", "duck", "goose", "parrot", "peacock", "insect",
                "spider", "fish",
            ]
        ),
        WallpaperType(
            id: "cities",
            name: "Cities & architecture",
            include: [
                "city", "cityscape", "skyline", "downtown", "architecture", "building",
                "skyscraper", "tower", "bridge", "cathedral", "church", "castle",
                "palace", "museum", "street", "urban", "town", "village", "temple",
                "monument", "plaza", "market", "harbor", "district",
            ],
            exclude: []
        ),
        WallpaperType(
            id: "beaches",
            name: "Beaches & islands",
            include: [
                "beach", "island", "bay", "coast", "coastline", "shore", "seaside",
                "sand", "tropical", "reef", "lagoon", "atoll", "ocean", "sea", "cove",
                "archipelago", "surf",
            ],
            exclude: []
        ),
        WallpaperType(
            id: "animals",
            name: "Animals & wildlife",
            include: [
                "animal", "wildlife", "bird", "mammal", "reptile", "amphibian",
                "insect", "butterfly", "bee", "spider", "fish", "shark", "whale",
                "dolphin", "seal", "otter", "penguin", "owl", "eagle", "fox", "bear",
                "bison", "deer", "elk", "moose", "wolf", "lion", "tiger", "leopard",
                "cheetah", "zebra", "giraffe", "elephant", "rhino", "hippo",
                "crocodile", "alligator", "snake", "lizard", "turtle", "frog",
                "monkey", "ape", "kangaroo", "koala", "panda", "camel", "horse",
                "cow", "sheep", "goat", "swan", "duck", "goose", "parrot", "peacock",
                "flamingo", "squirrel", "rabbit", "hare", "hedgehog", "bat", "crab",
                "lobster", "jellyfish", "octopus", "herd", "flock", "safari",
            ],
            exclude: []
        ),
        WallpaperType(
            id: "space",
            name: "Space & night sky",
            include: [
                "space", "galaxy", "nebula", "star", "night sky", "starry", "aurora",
                "northern lights", "moon", "lunar", "planet", "mars", "comet",
                "meteor", "milky way", "eclipse", "constellation", "observatory",
                "telescope", "astronaut", "cosmos", "cosmic", "night",
            ],
            exclude: []
        ),
    ]

    static func type(id: String) -> WallpaperType? {
        all.first { $0.id == id }
    }

    // Label for the "No new <type> photo yet" menu line.
    static func label(for ids: [String]) -> String {
        if ids.contains(everythingID) { return "" }
        let names = ids.compactMap { type(id: $0)?.name }
        if names.count == 1 { return names[0] }
        return "matching"
    }

    private static let regexes: [String: (include: NSRegularExpression?, exclude: NSRegularExpression?)] = {
        var map: [String: (NSRegularExpression?, NSRegularExpression?)] = [:]
        for t in all {
            map[t.id] = (buildRegex(t.include), buildRegex(t.exclude))
        }
        return map
    }()

    private static func buildRegex(_ words: [String]) -> NSRegularExpression? {
        var stems = Set<String>()
        for w in words {
            let lower = w.lowercased()
            stems.insert(lower)
            if lower.hasSuffix("s") && lower.count > 3 {
                stems.insert(String(lower.dropLast()))
            }
        }
        guard !stems.isEmpty else { return nil }
        let alternation = stems.sorted().map { NSRegularExpression.escapedPattern(for: $0) }.joined(separator: "|")
        let pattern = "\\b(?:" + alternation + ")(?:s|es)?\\b"
        return try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
    }

    private static func contains(_ regex: NSRegularExpression?, _ text: String) -> Bool {
        guard let regex else { return false }
        return regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil
    }

    static func matches(title: String, copyright: String, types ids: [String]) -> Bool {
        if ids.contains(everythingID) { return true }
        let text = title + " " + copyright
        for id in ids {
            guard let pair = regexes[id] else { continue }
            if contains(pair.include, text) && !contains(pair.exclude, text) {
                return true
            }
        }
        return false
    }
}