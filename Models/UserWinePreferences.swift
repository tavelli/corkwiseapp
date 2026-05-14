import Foundation
import SwiftData

enum WineStylePreference: String, Codable, CaseIterable, Identifiable {
    case crispRefreshing = "crisp_refreshing"
    case fruitySmooth = "fruity_smooth"
    case richFull = "rich_full"
    case earthySavory = "earthy_savory"
    case boldStructured = "bold_structured"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .crispRefreshing:
            return String(localized: .wineStyleCrispRefreshingTitle)
        case .fruitySmooth:
            return String(localized: .wineStyleFruitySmoothTitle)
        case .richFull:
            return String(localized: .wineStyleRichFullTitle)
        case .earthySavory:
            return String(localized: .wineStyleEarthySavoryTitle)
        case .boldStructured:
            return String(localized: .wineStyleBoldStructuredTitle)
        }
    }
}

enum ChoiceStyle: String, Codable, CaseIterable, Identifiable {
    case bestValue = "best_value"
    case safeChoice = "safe_choice"
    case interesting
    case premium

    var id: String { rawValue }

    var title: String {
        switch self {
        case .bestValue:
            return String(localized: .choiceStyleBestValueTitle)
        case .safeChoice:
            return String(localized: .choiceStyleSafeChoiceTitle)
        case .interesting:
            return String(localized: .choiceStyleInterestingTitle)
        case .premium:
            return String(localized: .choiceStylePremiumTitle)
        }
    }

    var description: String {
        switch self {
        case .bestValue:
            return String(localized: .choiceStyleBestValueDescription)
        case .safeChoice:
            return String(localized: .choiceStyleSafeChoiceDescription)
        case .interesting:
            return String(localized: .choiceStyleInterestingDescription)
        case .premium:
            return String(localized: .choiceStylePremiumDescription)
        }
    }
}

enum UsualPurchasePreference: String, Codable, CaseIterable, Identifiable {
    case glass
    case bottle

    var id: String { rawValue }

    var title: String {
        switch self {
        case .glass:
            return String(localized: .usualPurchasePreferenceGlassTitle)
        case .bottle:
            return String(localized: .usualPurchasePreferenceBottleTitle)
        }
    }

    var description: String {
        switch self {
        case .glass:
            return String(localized: .usualPurchasePreferenceGlassDescription)
        case .bottle:
            return String(localized: .usualPurchasePreferenceBottleDescription)
        }
    }

    var defaultPurchaseMode: PurchaseMode? {
        switch self {
        case .glass:
            return .glass
        case .bottle:
            return .bottle
        }
    }
}

enum TonePreference: String, Codable, CaseIterable, Identifiable {
    case standard
    case sommelier
    case sassy

    var id: String { rawValue }

    var title: String {
        switch self {
        case .standard:
            return String(localized: .toneStandardTitle)
        case .sommelier:
            return String(localized: .toneSommelierTitle)
        case .sassy:
            return String(localized: .toneSassyTitle)
        }
    }

    var userDescription: String {
        switch self {
        case .standard:
            return String(localized: .toneStandardDescription)
        case .sommelier:
            return String(localized: .toneSommelierDescription)
        case .sassy:
            return String(localized: .toneSassyDescription)
        }
    }
}

enum WineVarietal: String, Codable, CaseIterable, Identifiable {
    case pinotGrigio = "pinot_grigio"
    case sauvignonBlanc = "sauvignon_blanc"
    case riesling
    case chardonnay
    case dryRose = "dry_rose"
    case pinotNoirRose = "pinot_noir_rose"
    case whiteZinfandel = "white_zinfandel"
    case moscato
    case prosecco
    case cava
    case champagne
    case pinotNoir = "pinot_noir"
    case grenacheGarnacha = "grenache_garnacha"
    case sangiovese
    case merlot
    case tempranillo
    case malbec
    case syrahShiraz = "syrah_shiraz"
    case zinfandel
    case cabernetSauvignon = "cabernet_sauvignon"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pinotGrigio:
            return String(localized: .varietalPinotGrigioTitle)
        case .sauvignonBlanc:
            return String(localized: .varietalSauvignonBlancTitle)
        case .riesling:
            return String(localized: .varietalRieslingTitle)
        case .chardonnay:
            return String(localized: .varietalChardonnayTitle)
        case .dryRose:
            return String(localized: .varietalDryRoseTitle)
        case .pinotNoirRose:
            return String(localized: .varietalPinotNoirRoseTitle)
        case .whiteZinfandel:
            return String(localized: .varietalWhiteZinfandelTitle)
        case .moscato:
            return String(localized: .varietalMoscatoTitle)
        case .prosecco:
            return String(localized: .varietalProseccoTitle)
        case .cava:
            return String(localized: .varietalCavaTitle)
        case .champagne:
            return String(localized: .varietalChampagneTitle)
        case .pinotNoir:
            return String(localized: .varietalPinotNoirTitle)
        case .grenacheGarnacha:
            return String(localized: .varietalGrenacheGarnachaTitle)
        case .sangiovese:
            return String(localized: .varietalSangioveseTitle)
        case .merlot:
            return String(localized: .varietalMerlotTitle)
        case .tempranillo:
            return String(localized: .varietalTempranilloTitle)
        case .malbec:
            return String(localized: .varietalMalbecTitle)
        case .syrahShiraz:
            return String(localized: .varietalSyrahShirazTitle)
        case .zinfandel:
            return String(localized: .varietalZinfandelTitle)
        case .cabernetSauvignon:
            return String(localized: .varietalCabernetSauvignonTitle)
        }
    }

    var description: String {
        switch self {
        case .pinotGrigio:
            return String(localized: .varietalPinotGrigioDescription)
        case .sauvignonBlanc:
            return String(localized: .varietalSauvignonBlancDescription)
        case .riesling:
            return String(localized: .varietalRieslingDescription)
        case .chardonnay:
            return String(localized: .varietalChardonnayDescription)
        case .dryRose:
            return String(localized: .varietalDryRoseDescription)
        case .pinotNoirRose:
            return String(localized: .varietalPinotNoirRoseDescription)
        case .whiteZinfandel:
            return String(localized: .varietalWhiteZinfandelDescription)
        case .moscato:
            return String(localized: .varietalMoscatoDescription)
        case .prosecco:
            return String(localized: .varietalProseccoDescription)
        case .cava:
            return String(localized: .varietalCavaDescription)
        case .champagne:
            return String(localized: .varietalChampagneDescription)
        case .pinotNoir:
            return String(localized: .varietalPinotNoirDescription)
        case .grenacheGarnacha:
            return String(localized: .varietalGrenacheGarnachaDescription)
        case .sangiovese:
            return String(localized: .varietalSangioveseDescription)
        case .merlot:
            return String(localized: .varietalMerlotDescription)
        case .tempranillo:
            return String(localized: .varietalTempranilloDescription)
        case .malbec:
            return String(localized: .varietalMalbecDescription)
        case .syrahShiraz:
            return String(localized: .varietalSyrahShirazDescription)
        case .zinfandel:
            return String(localized: .varietalZinfandelDescription)
        case .cabernetSauvignon:
            return String(localized: .varietalCabernetSauvignonDescription)
        }
    }

    var category: WineVarietalCategory {
        switch self {
        case .pinotGrigio, .sauvignonBlanc, .riesling, .chardonnay:
            return .whiteWines
        case .dryRose, .pinotNoirRose, .whiteZinfandel:
            return .blush
        case .moscato, .prosecco, .cava, .champagne:
            return .sparklingWines
        case .pinotNoir, .grenacheGarnacha, .sangiovese, .merlot, .tempranillo, .malbec, .syrahShiraz, .zinfandel, .cabernetSauvignon:
            return .redWines
        }
    }
}

enum WineVarietalCategory: String, CaseIterable, Identifiable {
    case redWines
    case whiteWines
    case blush
    case sparklingWines

    var id: String { rawValue }

    var title: String {
        switch self {
        case .redWines:
            return String(localized: .varietalCategoryRedWinesTitle)
        case .whiteWines:
            return String(localized: .varietalCategoryWhiteWinesTitle)
        case .blush:
            return String(localized: .varietalCategoryBlushTitle)
        case .sparklingWines:
            return String(localized: .varietalCategorySparklingWinesTitle)
        }
    }

    var varietals: [WineVarietal] {
        WineVarietal.allCases.filter { $0.category == self }
    }
}

@Model
final class UserWinePreferences {
    // Kept for compatibility with older on-device SwiftData stores.
    var experienceLevel: String?
    var preferredStyles: [String]
    var favoriteVarietals: [String]?
    var choiceStyle: String
    var usualPurchasePreference: String?
    var tone: String?
    var hasCompletedOnboarding: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        experienceLevel: String? = nil,
        preferredStyles: [String],
        favoriteVarietals: [String] = [],
        choiceStyle: String,
        usualPurchasePreference: String? = nil,
        tone: String = TonePreference.standard.rawValue,
        hasCompletedOnboarding: Bool = false,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.experienceLevel = experienceLevel
        self.preferredStyles = preferredStyles
        self.favoriteVarietals = favoriteVarietals
        self.choiceStyle = choiceStyle
        self.usualPurchasePreference = usualPurchasePreference
        self.tone = tone
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

extension UserWinePreferences {
    var preferredStyleValues: [WineStylePreference] {
        preferredStyles.compactMap(WineStylePreference.init(rawValue:))
    }

    var favoriteVarietalValues: [WineVarietal] {
        (favoriteVarietals ?? []).compactMap(WineVarietal.init(rawValue:))
    }

    var choiceStyleValue: ChoiceStyle {
        ChoiceStyle(rawValue: choiceStyle) ?? .bestValue
    }

    var usualPurchasePreferenceValue: UsualPurchasePreference {
        guard let usualPurchasePreference else {
            return .glass
        }

        return UsualPurchasePreference(rawValue: usualPurchasePreference) ?? .glass
    }

    var toneValue: TonePreference {
        guard let tone, let value = TonePreference(rawValue: tone) else {
            return .standard
        }

        return value
    }

    var payload: UserPreferencesPayload {
        UserPreferencesPayload(
            preferredStyles: preferredStyles,
            favoriteVarietals: favoriteVarietals ?? [],
            choiceStyle: choiceStyle,
            tone: toneValue.rawValue
        )
    }
}
