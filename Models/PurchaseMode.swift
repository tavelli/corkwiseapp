import Foundation

enum PurchaseMode: String, Codable, CaseIterable, Identifiable, Hashable {
    case glass
    case bottle

    var id: String { rawValue }

    var title: String {
        switch self {
        case .glass:
            return String(localized: "Glass")
        case .bottle:
            return String(localized: "Bottle")
        }
    }
}

enum WineCategoryPreference: String, Codable, CaseIterable, Identifiable, Hashable {
    case anything
    case reds
    case whites
    case sparkling

    var id: String { rawValue }

    var title: String {
        switch self {
        case .anything:
            return String(localized: "Anything")
        case .reds:
            return String(localized: "Reds")
        case .whites:
            return String(localized: "Whites")
        case .sparkling:
            return String(localized: "Sparkling")
        }
    }

    static func defaultPreference(for varietals: [WineVarietal]) -> WineCategoryPreference {
        let scores = varietals.reduce(into: [WineCategoryPreference: Int]()) { scores, varietal in
            switch varietal.category {
            case .redWines:
                scores[.reds, default: 0] += 1
            case .whiteWines, .blush:
                scores[.whites, default: 0] += 1
            case .sparklingWines:
                scores[.sparkling, default: 0] += 1
            }
        }

        guard let strongestPreference = scores.max(by: { $0.value < $1.value }) else {
            return .anything
        }

        let strongestScore = strongestPreference.value
        let tiedPreferences = scores.filter { $0.value == strongestScore }
        return tiedPreferences.count == 1 ? strongestPreference.key : .anything
    }
}

enum BottleContext: String, Codable, CaseIterable, Identifiable, Hashable {
    case forMe = "for_me"
    case forGroup = "for_group"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .forMe:
            return String(localized: "For Me")
        case .forGroup:
            return String(localized: "For a Group")
        }
    }

    var shortTitle: String {
        switch self {
        case .forMe:
            return String(localized: "For Me")
        case .forGroup:
            return String(localized: "For Group")
        }
    }
}
