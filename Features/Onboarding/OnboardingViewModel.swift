import Foundation
import Observation

@MainActor
@Observable
final class OnboardingViewModel {
    var currentStep = 0
    var selectedUsualPurchasePreference: UsualPurchasePreference?
    var selectedStyles: Set<WineStylePreference>
    var selectedVarietals: Set<WineVarietal>
    var selectedChoiceStyle: ChoiceStyle

    init(existingPreferences: UserWinePreferences?) {
        selectedUsualPurchasePreference = existingPreferences?.usualPurchasePreferenceValue
        selectedStyles = Set(existingPreferences?.preferredStyleValues ?? [])
        selectedVarietals = Set(existingPreferences?.favoriteVarietalValues ?? [])
        selectedChoiceStyle = existingPreferences?.choiceStyleValue ?? .bestValue
    }

    var canContinue: Bool {
        switch currentStep {
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

    func goBack() {
        currentStep = max(0, currentStep - 1)
    }

    func goForward() {
        guard currentStep < 3 else { return }
        currentStep += 1
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
}
