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
