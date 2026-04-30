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

@Model
final class UserWinePreferences {
    var experienceLevel: String
    var preferredStyles: [String]
    var choiceStyle: String
    var hasCompletedOnboarding: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        experienceLevel: String,
        preferredStyles: [String],
        choiceStyle: String,
        hasCompletedOnboarding: Bool = false,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.experienceLevel = experienceLevel
        self.preferredStyles = preferredStyles
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

    var choiceStyleValue: ChoiceStyle {
        ChoiceStyle(rawValue: choiceStyle) ?? .bestValue
    }

    var payload: UserPreferencesPayload {
        UserPreferencesPayload(
            experienceLevel: experienceLevel,
            preferredStyles: preferredStyles,
            choiceStyle: choiceStyle
        )
    }
}
