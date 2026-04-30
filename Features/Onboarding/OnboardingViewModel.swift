import Foundation
import Observation

@MainActor
@Observable
final class OnboardingViewModel {
    var currentStep = 0
    var selectedExperienceLevel: ExperienceLevel
    var selectedStyles: Set<WineStylePreference>
    var selectedChoiceStyle: ChoiceStyle

    init(existingPreferences: UserWinePreferences?) {
        selectedExperienceLevel = existingPreferences?.experienceLevelValue ?? .casual
        selectedStyles = Set(existingPreferences?.preferredStyleValues ?? [])
        selectedChoiceStyle = existingPreferences?.choiceStyleValue ?? .bestValue
    }

    var canContinue: Bool {
        switch currentStep {
        case 1:
            return selectedStyles.isEmpty == false
        default:
            return true
        }
    }

    var isLastStep: Bool {
        currentStep == 2
    }

    func goBack() {
        currentStep = max(0, currentStep - 1)
    }

    func goForward() {
        guard currentStep < 2 else { return }
        currentStep += 1
    }

    func toggleStyle(_ style: WineStylePreference) {
        if selectedStyles.contains(style) {
            selectedStyles.remove(style)
        } else {
            selectedStyles.insert(style)
        }
    }
}
