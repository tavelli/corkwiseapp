import Foundation

struct AnalyzeWineMenuRequest: Codable {
    let imageBase64: String
    let purchaseMode: PurchaseMode
    let userPreferences: UserPreferencesPayload
}

struct UserPreferencesPayload: Codable {
    let experienceLevel: String
    let preferredStyles: [String]
    let choiceStyle: String
}

struct WineScanResult: Codable, Hashable {
    let restaurantName: String?
    let purchaseMode: String
    let summary: ScanSummary
    let recommendations: [WineRecommendation]
    let categoryHighlights: [CategoryHighlight]
    let notes: [String]
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
    let menuPriceDisplay: String?
    let estimatedRetailLow: Double?
    let estimatedRetailHigh: Double?
    let estimatedRetailDisplay: String?
    let estimatedMarkupLow: Double?
    let estimatedMarkupHigh: Double?
    let estimatedMarkupDisplay: String?
    let valueScore: Double
    let why: String
    let fitForUser: String
    let styleTags: [String]
    let categoryTags: [String]
}

struct CategoryHighlight: Codable, Hashable {
    let key: String
    let title: String
    let wineRank: Int
}

struct WineAnalysisErrorResponse: Codable {
    let error: String
    let message: String
    let retrySuggested: Bool
}

extension WineScanResult {
    static func sample(for purchaseMode: PurchaseMode, preferences: UserWinePreferences) -> WineScanResult {
        let styleSummary = preferences.preferredStyleValues
            .prefix(2)
            .map(\.title)
            .joined(separator: " and ")

        let purchaseModeTitle = purchaseMode.title.lowercased()
        let fitSummary = styleSummary.isEmpty ? "your preferences" : styleSummary.lowercased()

        return WineScanResult(
            restaurantName: "Example Bistro",
            purchaseMode: purchaseMode.rawValue,
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
                    menuPriceDisplay: "$88",
                    estimatedRetailLow: 50,
                    estimatedRetailHigh: 70,
                    estimatedRetailDisplay: "~$50-$70",
                    estimatedMarkupLow: 1.3,
                    estimatedMarkupHigh: 1.8,
                    estimatedMarkupDisplay: "~1.3x-1.8x",
                    valueScore: 9.5,
                    why: "A benchmark producer with bottle age that restaurants often price more aggressively than retail availability would suggest.",
                    fitForUser: "High-confidence recommendation for \(fitSummary).",
                    styleTags: ["Rioja", "Aged Red"],
                    categoryTags: ["Best Overall", "Cellar Value"]
                ),
                WineRecommendation(
                    rank: 2,
                    wineName: "2021 Domaine de la Pepiere Muscadet Sevre et Maine",
                    menuPrice: 54,
                    menuPriceDisplay: "$54",
                    estimatedRetailLow: 22,
                    estimatedRetailHigh: 28,
                    estimatedRetailDisplay: "~$22-$28",
                    estimatedMarkupLow: 1.9,
                    estimatedMarkupHigh: 2.4,
                    estimatedMarkupDisplay: "~1.9x-2.4x",
                    valueScore: 8.6,
                    why: "A strong producer in a category that can still offer honest restaurant pricing and food-friendly versatility.",
                    fitForUser: "Especially strong if you like fresher, brighter wines.",
                    styleTags: ["Mineral", "White"],
                    categoryTags: ["Food Pairing Flex"]
                ),
                WineRecommendation(
                    rank: 3,
                    wineName: "2019 Lopez Cristobal Ribera del Duero",
                    menuPrice: 76,
                    menuPriceDisplay: "$76",
                    estimatedRetailLow: 34,
                    estimatedRetailHigh: 42,
                    estimatedRetailDisplay: "~$34-$42",
                    estimatedMarkupLow: 1.8,
                    estimatedMarkupHigh: 2.2,
                    estimatedMarkupDisplay: "~1.8x-2.2x",
                    valueScore: 7.9,
                    why: "The markup is still reasonable, and the producer quality is meaningfully stronger than some similarly priced alternatives.",
                    fitForUser: "Good match for a guest looking for something richer without paying trophy-wine pricing.",
                    styleTags: ["Tempranillo", "Structured"],
                    categoryTags: ["Rich Style"]
                )
            ],
            categoryHighlights: [
                CategoryHighlight(key: "best_overall", title: "Best Overall", wineRank: 1),
                CategoryHighlight(key: "best_value", title: "Best Value", wineRank: 1),
                CategoryHighlight(key: "best_splurge", title: "Best Splurge", wineRank: 3),
                CategoryHighlight(key: "safest_choice", title: "Safest Choice", wineRank: 2),
                CategoryHighlight(key: "most_interesting_pick", title: "Most Interesting Pick", wineRank: 1)
            ],
            notes: [
                "This is a placeholder local result until the Supabase/OpenAI analysis flow is wired in.",
                "Scores combine estimated markup, producer quality, and list context rather than markup alone."
            ]
        )
    }
}
