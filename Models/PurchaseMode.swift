import Foundation

enum PurchaseMode: String, Codable, CaseIterable, Identifiable, Hashable {
    case glass
    case bottle

    var id: String { rawValue }

    var title: String {
        switch self {
        case .glass:
            return "Glass"
        case .bottle:
            return "Bottle"
        }
    }
}

enum BottleContext: String, Codable, CaseIterable, Identifiable, Hashable {
    case forMe = "for_me"
    case forGroup = "for_group"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .forMe:
            return "For Me"
        case .forGroup:
            return "For a Group"
        }
    }

    var shortTitle: String {
        switch self {
        case .forMe:
            return "For Me"
        case .forGroup:
            return "For Group"
        }
    }
}
