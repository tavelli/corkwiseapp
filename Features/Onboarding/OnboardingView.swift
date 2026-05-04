import SwiftData
import SwiftUI

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: OnboardingViewModel

    init(existingPreferences: UserWinePreferences?) {
        _viewModel = State(initialValue: OnboardingViewModel(existingPreferences: existingPreferences))
    }

    var body: some View {
        @Bindable var bindableViewModel = viewModel

        VStack(alignment: .leading, spacing: 0) {
            header

            stepContent(
                purchaseSelection: $bindableViewModel.selectedUsualPurchasePreference,
                selectedStyles: bindableViewModel.selectedStyles,
                selectedVarietals: bindableViewModel.selectedVarietals,
                choiceSelection: $bindableViewModel.selectedChoiceStyle
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .animation(.snappy(duration: 0.22), value: viewModel.currentStep)

            if viewModel.showsFooterCTA {
                footer
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 16)
        .background(mainScreenBackground.ignoresSafeArea())
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            Image("headerlogo3")
                .resizable()
                .scaledToFit()
                .frame(height: 72)

            Text("Build your taste profile for smarter picks.")
                .font(.subheadline)
                .foregroundStyle(Color.wineMutedText.opacity(0.82))
                .padding(.top, 12)

            ProgressView(value: Double(viewModel.currentStep + 1), total: 4)
                .tint(Color.wineAccent)
                .scaleEffect(x: 1, y: 1.12, anchor: .center)
                .padding(.top, 20)
                .padding(.bottom, 34)
        }
    }

    private var footer: some View {
        HStack {
            if viewModel.currentStep > 0 {
                Button("Back", action: viewModel.goBack)
                    .buttonStyle(OnboardingSecondaryButtonStyle())
            }

            Spacer()

            Button(viewModel.isLastStep ? "Finish" : "Continue") {
                if viewModel.isLastStep {
                    persistPreferences()
                } else {
                    viewModel.goForward()
                }
            }
            .buttonStyle(OnboardingPrimaryButtonStyle())
            .disabled(viewModel.canContinue == false)
        }
        .padding(.top, 24)
    }

    @ViewBuilder
    private func stepContent(
        purchaseSelection: Binding<UsualPurchasePreference?>,
        selectedStyles: Set<WineStylePreference>,
        selectedVarietals: Set<WineVarietal>,
        choiceSelection: Binding<ChoiceStyle?>
    ) -> some View {
        switch viewModel.currentStep {
        case 0:
            ChoiceStyleQuestionView(selection: choiceSelection, onSelect: handleChoiceStyleSelection)
        case 1:
            PurchasePreferenceQuestionView(selection: purchaseSelection, onSelect: handlePurchasePreferenceSelection)
        case 2:
            StyleQuestionView(
                selectedStyles: selectedStyles,
                toggleStyle: viewModel.toggleStyle
            )
        default:
            VarietalQuestionView(
                selectedVarietals: selectedVarietals,
                toggleVarietal: viewModel.toggleVarietal
            )
        }
    }

    private func handleChoiceStyleSelection(_ style: ChoiceStyle) {
        let changed = viewModel.selectedChoiceStyle != style
        viewModel.selectedChoiceStyle = style

        guard changed else { return }
        autoAdvanceIfNeeded()
    }

    private func handlePurchasePreferenceSelection(_ preference: UsualPurchasePreference) {
        let changed = viewModel.selectedUsualPurchasePreference != preference
        viewModel.selectedUsualPurchasePreference = preference

        guard changed else { return }
        autoAdvanceIfNeeded()
    }

    private func autoAdvanceIfNeeded() {
        let step = viewModel.currentStep

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(180))
            guard viewModel.currentStep == step, viewModel.showsFooterCTA == false else { return }
            viewModel.goForward()
        }
    }

    private func persistPreferences() {
        let fetchDescriptor = FetchDescriptor<UserWinePreferences>(
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )

        let existing = try? modelContext.fetch(fetchDescriptor).first
        let now = Date.now
        let choiceStyle = viewModel.selectedChoiceStyle ?? .bestValue

        if let existing {
            existing.preferredStyles = viewModel.selectedStyles.map(\.rawValue).sorted()
            existing.favoriteVarietals = viewModel.selectedVarietals.map(\.rawValue).sorted()
            existing.choiceStyle = choiceStyle.rawValue
            existing.usualPurchasePreference = viewModel.selectedUsualPurchasePreference?.rawValue
            existing.hasCompletedOnboarding = true
            existing.updatedAt = now
        } else {
            let preferences = UserWinePreferences(
                preferredStyles: viewModel.selectedStyles.map(\.rawValue).sorted(),
                favoriteVarietals: viewModel.selectedVarietals.map(\.rawValue).sorted(),
                choiceStyle: choiceStyle.rawValue,
                usualPurchasePreference: viewModel.selectedUsualPurchasePreference?.rawValue,
                hasCompletedOnboarding: true,
                createdAt: now,
                updatedAt: now
            )
            modelContext.insert(preferences)
        }

        try? modelContext.save()
    }
}

private struct StyleQuestionView: View {
    let selectedStyles: Set<WineStylePreference>
    let toggleStyle: (WineStylePreference) -> Void

    var body: some View {
        QuestionSection(title: "What kind of wines do you usually like?") {
            Text("Choose 1–2 that sound most like you")
                .font(.subheadline)
                .foregroundStyle(Color.wineMutedText)

            ForEach(WineStylePreference.allCases) { style in
                SelectableOptionButton(
                    title: style.title,
                    isSelected: selectedStyles.contains(style),
                    indicatorStyle: .checkbox
                ) {
                    toggleStyle(style)
                }
            }
        }
    }
}

private struct ChoiceStyleQuestionView: View {
    @Binding var selection: ChoiceStyle?
    let onSelect: (ChoiceStyle) -> Void

    var body: some View {
        QuestionSection(title: "How do you usually choose wine?") {
            ForEach(ChoiceStyle.allCases) { style in
                SelectableOptionButton(
                    title: style.title,
                    subtitle: style.description,
                    isSelected: selection == style
                ) {
                    onSelect(style)
                }
            }
        }
    }
}

private struct PurchasePreferenceQuestionView: View {
    @Binding var selection: UsualPurchasePreference?
    let onSelect: (UsualPurchasePreference) -> Void

    var body: some View {
        QuestionSection(title: "Are you usually picking a glass or a bottle?") {
            ForEach(UsualPurchasePreference.allCases) { preference in
                SelectableOptionButton(
                    title: preference.title,
                    subtitle: preference.description,
                    isSelected: selection == preference
                ) {
                    onSelect(preference)
                }
            }
        }
    }
}

private struct VarietalQuestionView: View {
    let selectedVarietals: Set<WineVarietal>
    let toggleVarietal: (WineVarietal) -> Void

    var body: some View {
        ScrollView {
            QuestionSection(title: "What wine varietals do you usually reach for?") {
                Text("Select any you like — or skip for now")
                    .font(.subheadline)
                    .foregroundStyle(Color.wineMutedText)

                ForEach(WineVarietalCategory.allCases) { category in
                    VStack(alignment: .leading, spacing: 10) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(category.title)
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(Color.wineDeep)

                            Rectangle()
                                .fill(Color.wineDivider.opacity(0.9))
                                .frame(height: 0.5)
                        }

                        ForEach(category.varietals) { varietal in
                            SelectableOptionButton(
                                title: varietal.title,
                                isSelected: selectedVarietals.contains(varietal),
                                indicatorStyle: .checkbox
                            ) {
                                toggleVarietal(varietal)
                            }
                        }
                    }
                    .padding(.top, 14)
                }
            }
        }
        .scrollIndicators(.hidden)
    }
}

private struct QuestionSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(title)
                .font(.title2)
                .bold()
                .foregroundStyle(Color.wineText)

            VStack(alignment: .leading, spacing: 12) {
                content
            }
        }
    }
}

private struct SelectableOptionButton: View {
    enum IndicatorStyle {
        case circle
        case checkbox
    }

    let title: String
    var subtitle: String? = nil
    let isSelected: Bool
    var indicatorStyle: IndicatorStyle = .circle
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .bold()
                        .foregroundStyle(Color.wineText)
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(Color.wineMutedText.opacity(isSelected ? 0.86 : 0.72))
                    }
                }

                Spacer()

                Image(systemName: indicatorSystemName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.wineAccent : Color.wineMutedText)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? Color.wineSoftPeach.opacity(0.34) : Color.wineOptionBackground.opacity(0.56))
            .clipShape(.rect(cornerRadius: 18))
            .scaleEffect(isSelected ? 1 : 0.985)
            .animation(.spring(response: 0.24, dampingFraction: 0.72), value: isSelected)
        }
        .buttonStyle(.plain)
    }

    private var indicatorSystemName: String {
        switch indicatorStyle {
        case .circle:
            isSelected ? "checkmark.circle.fill" : "circle"
        case .checkbox:
            isSelected ? "checkmark.square.fill" : "square"
        }
    }
}

private struct OnboardingPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.wineAccent.opacity(configuration.isPressed ? 0.88 : 1))
            .clipShape(.rect(cornerRadius: 14))
    }
}

private struct OnboardingSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color.wineText)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(Color.wineOptionBackground.opacity(configuration.isPressed ? 0.92 : 1))
            .clipShape(.rect(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.wineBorder, lineWidth: 1)
            }
    }
}

#Preview {
    OnboardingView(existingPreferences: nil)
        .modelContainer(for: [UserWinePreferences.self, WineScan.self], inMemory: true)
}
