import Foundation
import Observation

@MainActor
@Observable
final class OnboardingViewModel {
    var currentStep = 0
    private(set) var furthestStepReached = 0
    var selectedUsualPurchasePreference: UsualPurchasePreference?
    var selectedStyles: Set<WineStylePreference>
    var selectedVarietals: Set<WineVarietal>
    var selectedChoiceStyle: ChoiceStyle?

    init(existingPreferences: UserWinePreferences?) {
        selectedUsualPurchasePreference = existingPreferences?.usualPurchasePreferenceValue
        selectedStyles = Set(existingPreferences?.preferredStyleValues ?? [])
        selectedVarietals = Set(existingPreferences?.favoriteVarietalValues ?? [])
        selectedChoiceStyle = existingPreferences?.choiceStyleValue
    }

    var canContinue: Bool {
        switch currentStep {
        case 0:
            return selectedChoiceStyle != nil
        case 1:
            return selectedUsualPurchasePreference != nil
        case 2:
            return selectedStyles.isEmpty == false
        default:
            return true
        }
    }

    var isLastStep: Bool {
        currentStep == 3
    }

    var showsFooterCTA: Bool {
        currentStep >= 2 || hasRevisitedCurrentStep
    }

    var shouldAutoAdvanceCurrentStep: Bool {
        currentStep < 2 && hasRevisitedCurrentStep == false
    }

    func goBack() {
        currentStep = max(0, currentStep - 1)
    }

    func goForward() {
        guard currentStep < 3 else { return }
        currentStep += 1
        furthestStepReached = max(furthestStepReached, currentStep)
    }

    func toggleStyle(_ style: WineStylePreference) {
        if selectedStyles.contains(style) {
            selectedStyles.remove(style)
        } else {
            selectedStyles.insert(style)
        }
    }

    func toggleVarietal(_ varietal: WineVarietal) {
        if selectedVarietals.contains(varietal) {
            selectedVarietals.remove(varietal)
        } else {
            selectedVarietals.insert(varietal)
        }
    }

    private var hasRevisitedCurrentStep: Bool {
        furthestStepReached > currentStep
    }
}
