import Foundation
import SwiftData

enum ExperienceLevel: String, Codable, CaseIterable, Identifiable {
    case beginner
    case casual
    case enthusiast

    var id: String { rawValue }

    var title: String {
        switch self {
        case .beginner:
            return "Beginner"
        case .casual:
            return "Casual wine drinker"
        case .enthusiast:
            return "Enthusiast"
        }
    }
}

enum WineStylePreference: String, Codable, CaseIterable, Identifiable {
    case crispRefreshing = "crisp_refreshing"
    case fruitySmooth = "fruity_smooth"
    case richFull = "rich_full"
    case earthySavory = "earthy_savory"
    case boldStructured = "bold_structured"
    case unsure

    var id: String { rawValue }

    var title: String {
        switch self {
        case .crispRefreshing:
            return "Crisp and refreshing"
        case .fruitySmooth:
            return "Fruity and smooth"
        case .richFull:
            return "Rich and full-bodied"
        case .earthySavory:
            return "Earthy and savory"
        case .boldStructured:
            return "Bold and structured"
        case .unsure:
            return "I'm not sure"
        }
    }
}

enum ChoiceStyle: String, Codable, CaseIterable, Identifiable {
    case bestValue = "best_value"
    case safeChoice = "safe_choice"
    case interesting
    case premium
    case needsHelp = "needs_help"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .bestValue:
            return "Best value"
        case .safeChoice:
            return "Safest crowd-pleaser"
        case .interesting:
            return "Something interesting"
        case .premium:
            return "Premium pick"
        case .needsHelp:
            return "I usually need help"
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
            return "Pinot Grigio"
        case .sauvignonBlanc:
            return "Sauvignon Blanc"
        case .riesling:
            return "Riesling"
        case .chardonnay:
            return "Chardonnay"
        case .dryRose:
            return "Dry Rosé"
        case .pinotNoirRose:
            return "Pinot Noir Rosé"
        case .whiteZinfandel:
            return "White Zinfandel"
        case .moscato:
            return "Moscato"
        case .prosecco:
            return "Prosecco"
        case .cava:
            return "Cava"
        case .champagne:
            return "Champagne"
        case .pinotNoir:
            return "Pinot Noir"
        case .grenacheGarnacha:
            return "Grenache / Garnacha"
        case .sangiovese:
            return "Sangiovese"
        case .merlot:
            return "Merlot"
        case .tempranillo:
            return "Tempranillo"
        case .malbec:
            return "Malbec"
        case .syrahShiraz:
            return "Syrah / Shiraz"
        case .zinfandel:
            return "Zinfandel"
        case .cabernetSauvignon:
            return "Cabernet Sauvignon"
        }
    }

    var description: String {
        switch self {
        case .pinotGrigio:
            return "Light, crisp, and neutral. The easy-drinking choice."
        case .sauvignonBlanc:
            return "Zesty and aromatic. Often has green notes like grass and lime."
        case .riesling:
            return "High acidity. Can range from bone-dry to very sweet."
        case .chardonnay:
            return "Medium to full-bodied. Often buttery if oak-aged, or apple-like if not."
        case .dryRose:
            return "A crisp, bone-dry wine with elegant notes of strawberry and a refreshing finish."
        case .pinotNoirRose:
            return "A delicate and aromatic dry wine with bright cherry notes and a smooth, silky texture."
        case .whiteZinfandel:
            return "A soft and distinctly sweet wine with jammy flavors of raspberry and cream."
        case .moscato:
            return "A light, sweet tingle with soft floral notes and very low alcohol."
        case .prosecco:
            return "Fresh and fruity with smooth, easy-going bubbles."
        case .cava:
            return "Crisp and dry with a steady stream of fine, refreshing bubbles."
        case .champagne:
            return "Intense, pinpoint bubbles with complex toasty notes and a sharp finish."
        case .pinotNoir:
            return "Light-bodied, smooth, and earthy. The most popular elegant red."
        case .grenacheGarnacha:
            return "Medium-bodied and fruity with strawberry and raspberry notes."
        case .sangiovese:
            return "Savory and acidic. The classic Italian restaurant grape."
        case .merlot:
            return "Medium-to-full-bodied, plush, and soft with very low grip."
        case .tempranillo:
            return "Savory with notes of leather and dried cherry."
        case .malbec:
            return "Bold and juicy with dark plum and cocoa flavors."
        case .syrahShiraz:
            return "Bold, intense, and often peppery or smoky."
        case .zinfandel:
            return "Jammy, bold, and high-alcohol with fruit-forward character."
        case .cabernetSauvignon:
            return "The heaviest red. Bold tannins and dark fruit."
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
    case whiteWines
    case blush
    case redWines
    case sparklingWines

    var id: String { rawValue }

    var title: String {
        switch self {
        case .whiteWines:
            return "Whites (Light to Full)"
        case .blush:
            return "Blush (Dry to sweet)"
        case .redWines:
            return "Reds (Light to Full)"
        case .sparklingWines:
            return "Sparkling (Least to most fizzy)"
        }
    }

    var varietals: [WineVarietal] {
        WineVarietal.allCases.filter { $0.category == self }
    }
}

@Model
final class UserWinePreferences {
    var experienceLevel: String
    var preferredStyles: [String]
    var favoriteVarietals: [String]?
    var choiceStyle: String
    var hasCompletedOnboarding: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        experienceLevel: String,
        preferredStyles: [String],
        favoriteVarietals: [String] = [],
        choiceStyle: String,
        hasCompletedOnboarding: Bool = false,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.experienceLevel = experienceLevel
        self.preferredStyles = preferredStyles
        self.favoriteVarietals = favoriteVarietals
        self.choiceStyle = choiceStyle
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

extension UserWinePreferences {
    var experienceLevelValue: ExperienceLevel {
        ExperienceLevel(rawValue: experienceLevel) ?? .casual
    }

    var preferredStyleValues: [WineStylePreference] {
        preferredStyles.compactMap(WineStylePreference.init(rawValue:))
    }

    var favoriteVarietalValues: [WineVarietal] {
        (favoriteVarietals ?? []).compactMap(WineVarietal.init(rawValue:))
    }

    var choiceStyleValue: ChoiceStyle {
        ChoiceStyle(rawValue: choiceStyle) ?? .bestValue
    }

    var payload: UserPreferencesPayload {
        UserPreferencesPayload(
            experienceLevel: experienceLevel,
            preferredStyles: preferredStyles,
            favoriteVarietals: favoriteVarietals ?? [],
            choiceStyle: choiceStyle
        )
    }
}
