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
            if viewModel.currentStep > 0 {
                header
            }

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
            HStack(spacing: 12) {
                if viewModel.canGoBack {
                    Button(action: viewModel.goBack) {
                        Image(systemName: "chevron.left")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(Color.wineText)
                            .frame(width: 32, height: 32)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .frame(width: 32, height: 32)
                }

                if viewModel.currentStep > 0 {
                    ProgressView(value: Double(viewModel.currentStep), total: 4)
                        .tint(Color.wineAccent)
                        .scaleEffect(x: 1, y: 1.35, anchor: .center)
                        .frame(maxWidth: .infinity)
                } else {
                    Spacer()
                }
            }
            .frame(height: 32)
            .padding(.bottom, 20)

            Image("headerlogo4")
                .resizable()
                .scaledToFit()
                .frame(height: 55)

            Text("Building your taste profile for smarter picks.")
                .font(.subheadline)
                .foregroundStyle(Color.wineText.opacity(0.6))
                .padding(.top, 6)
                .padding(.bottom, 38)
        }
    }

    private var footer: some View {
        Button {
            if viewModel.isLastStep {
                persistPreferences()
            } else {
                viewModel.goForward()
            }
        } label: {
            if viewModel.currentStep == 0 {
                HStack(spacing: 12) {
                    Spacer(minLength: 0)
                    Text("Start ordering better wine")
                    Spacer(minLength: 0)
                    Image(systemName: "arrow.right")
                        .font(.title3)
                }
            } else {
                Text(viewModel.isLastStep ? "Finish" : "Continue")
            }
        }
        .buttonStyle(OnboardingPrimaryButtonStyle())
        .disabled(viewModel.canContinue == false)
        .frame(maxWidth: .infinity)
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
            OnboardingIntroStepView()
        case 1:
            ChoiceStyleQuestionView(selection: choiceSelection, onSelect: handleChoiceStyleSelection)
        case 2:
            PurchasePreferenceQuestionView(selection: purchaseSelection, onSelect: handlePurchasePreferenceSelection)
        case 3:
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
            guard viewModel.currentStep == step, viewModel.shouldAutoAdvanceCurrentStep else { return }
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

private struct OnboardingIntroStepView: View {
    @ScaledMetric(relativeTo: .largeTitle) private var headlineFontSize = 42

    var body: some View {
        VStack(spacing: 0) {
            Image("headerlogo4")
                .resizable()
                .scaledToFit()
                .frame(height: 44)
                .padding(.top, 8)

            Spacer(minLength: 28)

            VStack(spacing: 18) {
                Text("Stop overpaying\nfor bad wine.")
                    .font(.system(size: headlineFontSize, weight: .semibold))
                    .dynamicTypeSize(.large ... .accessibility1)
                    .foregroundStyle(Color.wineText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Scan any wine list and instantly see what's worth ordering - and what to avoid.")
                    .font(.body)
                    .foregroundStyle(Color.wineMutedText)
                    .lineSpacing(4)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)

            Spacer(minLength: 34)

            VStack(spacing: 12) {
                HStack(spacing: 20) {
                    Text("ON YOUR OWN")
                        .font(.caption)
                        .bold()
                        .foregroundStyle(Color.wineAccent)
                        .frame(maxWidth: .infinity)

                    Text("USING CORKWISE")
                        .font(.caption)
                        .bold()
                        .foregroundStyle(Color(red: 0.18, green: 0.34, blue: 0.16))
                        .frame(maxWidth: .infinity)
                }

                HStack(alignment: .center, spacing: 20) {
                    IntroComparisonCard(
                        tint: Color.wineDeep.opacity(0.78),
                        background: Color.wineAccent.opacity(0.06),
                        systemImage: "xmark",
                        items: [
                            "Overpaying for wine",
                            "Playing it safe",
                            "Disappointing pours",
                            "Staring at the menu"
                        ]
                    )

                    IntroComparisonCard(
                        tint: Color(red: 0.28, green: 0.36, blue: 0.20).opacity(0.88),
                        background: Color(red: 0.18, green: 0.34, blue: 0.16).opacity(0.07),
                        systemImage: "checkmark",
                        items: [
                            "Hidden value picks",
                            "Discover new favoritess",
                            "Wine worth ordering",
                            "Enjoying the moment"
                        ]
                    )
                }
            }

            Spacer(minLength: 0)
        }
    }
}

private struct IntroComparisonCard: View {
    let tint: Color
    let background: Color
    let systemImage: String
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ForEach(items, id: \.self) { item in
                HStack(alignment: .center, spacing: 10) {
                    Circle()
                        .strokeBorder(tint, lineWidth: 1.2)
                        .background(
                            Circle()
                                .fill(systemImage == "checkmark" ? tint.opacity(0.95) : Color.clear)
                        )
                        .frame(width: 23, height: 23)
                        .overlay {
                            Image(systemName: systemImage)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(systemImage == "checkmark" ? Color.white : tint)
                        }

                    Text(item)
                        .font(.caption)
                        .foregroundStyle(Color.wineText)
                        .fixedSize(horizontal: false, vertical: true)
                }.frame(minHeight: 40, alignment: .leading)

            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity, minHeight: 260, alignment: .topLeading)
        .background(background)
        .clipShape(.rect(cornerRadius: 24))
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
                    isSelected: selectedStyles.contains(style)
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
                        Text(category.title)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(Color.wineDeep)

                        ForEach(category.varietals) { varietal in
                            SelectableOptionButton(
                                title: varietal.title,
                                isSelected: selectedVarietals.contains(varietal)
                            ) {
                                toggleVarietal(varietal)
                            }
                        }
                    }
                    .padding(.top, 14)
                }
            }
            .padding(.bottom, 100)
        }
        .scrollIndicators(.hidden)
        .overlay(alignment: .bottom) {
            LinearGradient(
                colors: [
                    Color.white.opacity(0),
                    Color.wineCanvasBottom.opacity(0.92)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 100)
            .allowsHitTesting(false)
        }
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
    let title: String
    var subtitle: String? = nil
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .bold()
                    .foregroundStyle(isSelected ? Color.wineDeep : Color.wineText)

                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(isSelected ? Color.wineDeep.opacity(0.78) : Color.wineMutedText.opacity(0.9))
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? Color.wineSoftPeach.opacity(0.42) : Color.white.opacity(0.94))
            .clipShape(.rect(cornerRadius: 18))
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .stroke(isSelected ? Color.wineAccent.opacity(0.55) : Color.wineBorder.opacity(0.9), lineWidth: 1)
            }
            .scaleEffect(isSelected ? 1 : 0.985)
            .animation(.spring(response: 0.24, dampingFraction: 0.72), value: isSelected)
        }
        .buttonStyle(.plain)
    }
}

private struct OnboardingPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        PrimaryButton(configuration: configuration)
    }

    private struct PrimaryButton: View {
        @Environment(\.isEnabled) private var isEnabled
        let configuration: Configuration

        var body: some View {
            configuration.label
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isEnabled ? Color.white : Color.wineMutedText.opacity(0.85))
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(backgroundColor)
                .clipShape(.rect(cornerRadius: 14))
                .scaleEffect(isEnabled ? 1 : 0.985)
                .animation(.easeOut(duration: 0.18), value: isEnabled)
        }

        private var backgroundColor: Color {
            guard isEnabled else {
                return Color.wineBorder.opacity(0.75)
            }

            return Color.wineAccent.opacity(configuration.isPressed ? 0.88 : 1)
        }
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
