import Foundation
import SwiftData

@Model
final class WineScan {
    var createdAt: Date
    var restaurantName: String?
    var purchaseMode: String
    var bottleContext: String?
    var summaryHeadline: String?
    var bestPickName: String?
    var bestPickScore: Double?
    var resultJSON: String

    init(
        createdAt: Date = .now,
        restaurantName: String? = nil,
        purchaseMode: String,
        bottleContext: String? = nil,
        summaryHeadline: String? = nil,
        bestPickName: String? = nil,
        bestPickScore: Double? = nil,
        resultJSON: String
    ) {
        self.createdAt = createdAt
        self.restaurantName = restaurantName
        self.purchaseMode = purchaseMode
        self.bottleContext = bottleContext
        self.summaryHeadline = summaryHeadline
        self.bestPickName = bestPickName
        self.bestPickScore = bestPickScore
        self.resultJSON = resultJSON
    }
}

extension WineScan {
    var purchaseModeValue: PurchaseMode {
        PurchaseMode(rawValue: purchaseMode) ?? .bottle
    }

    var bottleContextValue: BottleContext? {
        guard let bottleContext else { return nil }
        return BottleContext(rawValue: bottleContext)
    }
}
