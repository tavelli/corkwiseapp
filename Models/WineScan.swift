import Foundation
import SwiftData

@Model
final class WineScan {
    var createdAt: Date
    var analysisId: String?
    var restaurantName: String?
    var purchaseMode: String
    var bottleContext: String?
    var categoryPreference: String?
    var summaryHeadline: String?
    var resultJSON: String
    var hasSubmittedFeedback: Bool = false

    init(
        createdAt: Date = .now,
        analysisId: String? = nil,
        restaurantName: String? = nil,
        purchaseMode: String,
        bottleContext: String? = nil,
        categoryPreference: String? = nil,
        summaryHeadline: String? = nil,
        resultJSON: String,
        hasSubmittedFeedback: Bool = false
    ) {
        self.createdAt = createdAt
        self.analysisId = analysisId
        self.restaurantName = restaurantName
        self.purchaseMode = purchaseMode
        self.bottleContext = bottleContext
        self.categoryPreference = categoryPreference
        self.summaryHeadline = summaryHeadline
        self.resultJSON = resultJSON
        self.hasSubmittedFeedback = hasSubmittedFeedback
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

    var categoryPreferenceValue: WineCategoryPreference {
        guard let categoryPreference else { return .anything }
        return WineCategoryPreference(rawValue: categoryPreference) ?? .anything
    }
}
