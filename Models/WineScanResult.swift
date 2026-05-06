import Foundation

struct AnalyzeWineMenuRequest: Codable {
    let attachment: AnalyzeWineMenuAttachment?
    let menuUrl: String?
    let purchaseMode: PurchaseMode
    let bottleContext: BottleContext?
    let categoryPreference: WineCategoryPreference
    let userPreferences: UserPreferencesPayload
}

struct AnalyzeWineMenuAttachment: Codable {
    let base64Data: String
    let mimeType: String
    let filename: String?
}

struct UserPreferencesPayload: Codable {
    let preferredStyles: [String]
    let favoriteVarietals: [String]
    let choiceStyle: String
    let tone: String
}

struct WineScanResult: Codable, Hashable {
    let restaurantName: String?
    let summary: ScanSummary
    let recommendations: [WineRecommendation]
    let categoryRecommendations: [RecommendationCategorySection]
    let notes: [String]
    let debugInfo: ScanDebugInfo?
}

struct ScanSummary: Codable, Hashable {
    let headline: String
    let bestPickName: String
    let bestPickScore: Double
    let bestPickWhy: String
}

struct WineRecommendation: Codable, Identifiable, Hashable {
    var id: String { "\(rank)-\(wineName)" }

    let rank: Int
    let wineName: String
    let menuPrice: Double?
    let estimatedRetail: Double?
    let valueScore: Double
    let why: String

    private enum CodingKeys: String, CodingKey {
        case rank
        case wineName
        case menuPrice
        case estimatedRetail
        case estimatedRetailLow
        case estimatedRetailHigh
        case valueScore
        case why
    }

    init(
        rank: Int,
        wineName: String,
        menuPrice: Double?,
        estimatedRetail: Double?,
        valueScore: Double,
        why: String
    ) {
        self.rank = rank
        self.wineName = wineName
        self.menuPrice = menuPrice
        self.estimatedRetail = estimatedRetail
        self.valueScore = valueScore
        self.why = why
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        rank = try container.decode(Int.self, forKey: .rank)
        wineName = try container.decode(String.self, forKey: .wineName)
        menuPrice = try container.decodeIfPresent(Double.self, forKey: .menuPrice)
        valueScore = try container.decode(Double.self, forKey: .valueScore)
        why = try container.decode(String.self, forKey: .why)

        if let estimatedRetail = try container.decodeIfPresent(Double.self, forKey: .estimatedRetail) {
            self.estimatedRetail = estimatedRetail
            return
        }

        let low = try container.decodeIfPresent(Double.self, forKey: .estimatedRetailLow)
        let high = try container.decodeIfPresent(Double.self, forKey: .estimatedRetailHigh)

        switch (low, high) {
        case let (low?, high?):
            estimatedRetail = (low + high) / 2
        case let (low?, nil):
            estimatedRetail = low
        case let (nil, high?):
            estimatedRetail = high
        default:
            estimatedRetail = nil
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(rank, forKey: .rank)
        try container.encode(wineName, forKey: .wineName)
        try container.encodeIfPresent(menuPrice, forKey: .menuPrice)
        try container.encodeIfPresent(estimatedRetail, forKey: .estimatedRetail)
        try container.encode(valueScore, forKey: .valueScore)
        try container.encode(why, forKey: .why)
    }
}

struct RecommendationCategorySection: Codable, Hashable {
    let key: String
    let title: String
    let recommendations: [WineRecommendation]
}

struct ScanDebugInfo: Codable, Hashable {
    let model: String
    let apiDurationMilliseconds: Int
}

struct WineAnalysisErrorResponse: Codable {
    let error: String
    let message: String
    let retrySuggested: Bool
}

extension WineScanResult {
    static func sample(for purchaseMode: PurchaseMode, preferences: UserWinePreferences) -> WineScanResult {
        let purchaseModeTitle = purchaseMode.title.lowercased()

        return WineScanResult(
            restaurantName: "Example Bistro",
            summary: ScanSummary(
                headline: "Smartest \(purchaseModeTitle) picks on this list",
                bestPickName: "2012 R. Lopez de Heredia Viña Tondonia Rioja",
                bestPickScore: 9.5,
                bestPickWhy: "Aged, iconic Rioja at a very fair restaurant price relative to the rest of the list."
            ),
            recommendations: [
                WineRecommendation(
                    rank: 1,
                    wineName: "2012 R. Lopez de Heredia Viña Tondonia Rioja",
                    menuPrice: 88,
                    estimatedRetail: 60,
                    valueScore: 9.5,
                    why: "A benchmark producer with bottle age that restaurants often price more aggressively than retail availability would suggest."
                ),
                WineRecommendation(
                    rank: 2,
                    wineName: "2021 Domaine de la Pepiere Muscadet Sevre et Maine",
                    menuPrice: 54,
                    estimatedRetail: 25,
                    valueScore: 8.6,
                    why: "A strong producer in a category that can still offer honest restaurant pricing and food-friendly versatility."
                ),
                WineRecommendation(
                    rank: 3,
                    wineName: "2019 Lopez Cristobal Ribera del Duero",
                    menuPrice: 76,
                    estimatedRetail: 38,
                    valueScore: 7.9,
                    why: "The markup is still reasonable, and the producer quality is meaningfully stronger than some similarly priced alternatives."
                )
            ],
            categoryRecommendations: [
                RecommendationCategorySection(
                    key: "best_value",
                    title: "Best Value",
                    recommendations: [
                        WineRecommendation(
                            rank: 1,
                            wineName: "2021 Domaine de la Pepiere Muscadet Sevre et Maine",
                            menuPrice: 54,
                            estimatedRetail: 25,
                            valueScore: 8.6,
                            why: "Strong producer quality and honest restaurant pricing make this the clearest value play."
                        )
                    ]
                ),
                RecommendationCategorySection(
                    key: "best_splurge",
                    title: "Best Splurge",
                    recommendations: [
                        WineRecommendation(
                            rank: 3,
                            wineName: "2019 Lopez Cristobal Ribera del Duero",
                            menuPrice: 76,
                            estimatedRetail: 38,
                            valueScore: 7.9,
                            why: "If you want to spend a bit more, this gives a more serious bottle without entering trophy pricing."
                        )
                    ]
                ),
                RecommendationCategorySection(
                    key: "safest_choice",
                    title: "Safest Choice",
                    recommendations: [
                        WineRecommendation(
                            rank: 2,
                            wineName: "2021 Domaine de la Pepiere Muscadet Sevre et Maine",
                            menuPrice: 54,
                            estimatedRetail: 25,
                            valueScore: 8.6,
                            why: "A broad-appeal bottle with strong restaurant utility and low risk."
                        )
                    ]
                ),
                RecommendationCategorySection(
                    key: "most_interesting_pick",
                    title: "Most Interesting Pick",
                    recommendations: [
                        WineRecommendation(
                            rank: 1,
                            wineName: "2012 R. Lopez de Heredia Viña Tondonia Rioja",
                            menuPrice: 88,
                            estimatedRetail: 60,
                            valueScore: 9.5,
                            why: "Age, style, and producer profile make this the most compelling conversation bottle on the list."
                        )
                    ]
                )
            ],
            notes: [
                "This is a placeholder local result until the Supabase/OpenAI analysis flow is wired in.",
                "Scores combine estimated markup, producer quality, and list context rather than markup alone."
            ],
            debugInfo: ScanDebugInfo(
                model: "sample-data",
                apiDurationMilliseconds: 820
            )
        )
    }
}
