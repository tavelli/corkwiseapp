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

        VStack(alignment: .leading) {
            Text("CorkWise")
                .font(.largeTitle)
                .bold()

            Text("Build a quick taste profile so each scan can rank smarter picks for you.")
                .foregroundStyle(.secondary)

            ProgressView(value: Double(viewModel.currentStep + 1), total: 4)
                .tint(Color.wineAccent)
                .scaleEffect(x: 1, y: 1.2, anchor: .center)
                .padding(.bottom, 18)

            stepContent(
                experienceSelection: $bindableViewModel.selectedExperienceLevel,
                selectedStyles: bindableViewModel.selectedStyles,
                selectedVarietals: bindableViewModel.selectedVarietals,
                choiceSelection: $bindableViewModel.selectedChoiceStyle
            )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .animation(.default, value: viewModel.currentStep)

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
        }
        .padding()
        .background(mainScreenBackground.ignoresSafeArea())
    }

    @ViewBuilder
    private func stepContent(
        experienceSelection: Binding<ExperienceLevel>,
        selectedStyles: Set<WineStylePreference>,
        selectedVarietals: Set<WineVarietal>,
        choiceSelection: Binding<ChoiceStyle>
    ) -> some View {
        switch viewModel.currentStep {
        case 0:
            ExperienceQuestionView(selection: experienceSelection)
        case 1:
            StyleQuestionView(
                selectedStyles: selectedStyles,
                toggleStyle: viewModel.toggleStyle
            )
        case 2:
            VarietalQuestionView(
                selectedVarietals: selectedVarietals,
                toggleVarietal: viewModel.toggleVarietal
            )
        default:
            ChoiceStyleQuestionView(selection: choiceSelection)
        }
    }

    private func persistPreferences() {
        let fetchDescriptor = FetchDescriptor<UserWinePreferences>(
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )

        let existing = try? modelContext.fetch(fetchDescriptor).first
        let now = Date.now

        if let existing {
            existing.experienceLevel = viewModel.selectedExperienceLevel.rawValue
            existing.preferredStyles = viewModel.selectedStyles.map(\.rawValue).sorted()
            existing.favoriteVarietals = viewModel.selectedVarietals.map(\.rawValue).sorted()
            existing.choiceStyle = viewModel.selectedChoiceStyle.rawValue
            existing.hasCompletedOnboarding = true
            existing.updatedAt = now
        } else {
            let preferences = UserWinePreferences(
                experienceLevel: viewModel.selectedExperienceLevel.rawValue,
                preferredStyles: viewModel.selectedStyles.map(\.rawValue).sorted(),
                favoriteVarietals: viewModel.selectedVarietals.map(\.rawValue).sorted(),
                choiceStyle: viewModel.selectedChoiceStyle.rawValue,
                hasCompletedOnboarding: true,
                createdAt: now,
                updatedAt: now
            )
            modelContext.insert(preferences)
        }

        try? modelContext.save()
    }
}

private struct VarietalQuestionView: View {
    let selectedVarietals: Set<WineVarietal>
    let toggleVarietal: (WineVarietal) -> Void

    var body: some View {
        ScrollView {
            QuestionCard(title: "What wine varietals do you usually reach for?") {
                Text("Choose as many as you want.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                ForEach(WineVarietalCategory.allCases) { category in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(category.title)
                            .font(.headline)
                            .foregroundStyle(Color.wineText)

                        ForEach(category.varietals) { varietal in
                            SelectableOptionButton(
                                title: varietal.title,
                                subtitle: varietal.description,
                                isSelected: selectedVarietals.contains(varietal),
                                indicatorStyle: .checkbox
                            ) {
                                toggleVarietal(varietal)
                            }
                        }
                    }
                    .padding(.top, 4)
                }
            }
        }
        .scrollIndicators(.hidden)
    }
}

private struct ExperienceQuestionView: View {
    @Binding var selection: ExperienceLevel

    var body: some View {
        QuestionCard(title: "How would you describe your wine experience?") {
            ForEach(ExperienceLevel.allCases) { level in
                SelectableOptionButton(
                    title: level.title,
                    isSelected: selection == level
                ) {
                    selection = level
                }
            }
        }
    }
}

private struct StyleQuestionView: View {
    let selectedStyles: Set<WineStylePreference>
    let toggleStyle: (WineStylePreference) -> Void

    var body: some View {
        QuestionCard(title: "What kind of wines do you usually like?") {
            Text("Choose one or more.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

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
    @Binding var selection: ChoiceStyle

    var body: some View {
        QuestionCard(title: "How do you usually choose wine at a restaurant?") {
            ForEach(ChoiceStyle.allCases) { style in
                SelectableOptionButton(
                    title: style.title,
                    isSelected: selection == style
                ) {
                    selection = style
                }
            }
        }
    }
}

private struct QuestionCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.title2)
                .bold()
                .foregroundStyle(Color.wineText)

            VStack(alignment: .leading) {
                content
            }
        }
        .padding()
        .background(Color.wineCardBackground.opacity(0.9))
        .clipShape(.rect(cornerRadius: 24))
        .overlay {
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.wineBorder, lineWidth: 1)
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
            HStack {
                VStack(alignment: .leading) {
                    Text(title)
                        .bold()
                        .foregroundStyle(Color.wineText)
                    if let subtitle {
                        Text(subtitle)
                            .font(.footnote)
                            .foregroundStyle(Color.wineMutedText)
                    }
                }

                Spacer()

                Image(systemName: indicatorSystemName)
                    .imageScale(.large)
                    .foregroundStyle(isSelected ? Color.wineAccent : Color.wineMutedText)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? Color.wineSoftPeach.opacity(0.22) : Color.wineOptionBackground.opacity(0.72))
            .clipShape(.rect(cornerRadius: 18))
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .stroke(isSelected ? Color.wineAccent.opacity(0.18) : Color.wineBorder, lineWidth: 1)
            }
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
