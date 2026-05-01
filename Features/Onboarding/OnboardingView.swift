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

            TabView(selection: $bindableViewModel.currentStep) {
                ExperienceQuestionView(selection: $bindableViewModel.selectedExperienceLevel)
                    .tag(0)

                StyleQuestionView(
                    selectedStyles: bindableViewModel.selectedStyles,
                    toggleStyle: viewModel.toggleStyle
                )
                .tag(1)

                VarietalQuestionView(
                    selectedVarietals: bindableViewModel.selectedVarietals,
                    toggleVarietal: viewModel.toggleVarietal
                )
                .tag(2)

                ChoiceStyleQuestionView(selection: $bindableViewModel.selectedChoiceStyle)
                    .tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.default, value: viewModel.currentStep)

            HStack {
                if viewModel.currentStep > 0 {
                    Button("Back", action: viewModel.goBack)
                        .buttonStyle(.bordered)
                }

                Spacer()

                Button(viewModel.isLastStep ? "Finish" : "Continue") {
                    if viewModel.isLastStep {
                        persistPreferences()
                    } else {
                        viewModel.goForward()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.canContinue == false)
            }
        }
        .padding()
        .background(
            LinearGradient(
                colors: [.wineBackgroundTop, .wineBackgroundBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
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
                            isSelected: selectedVarietals.contains(varietal)
                        ) {
                            toggleVarietal(varietal)
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
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
            ForEach(WineStylePreference.allCases) { style in
                SelectableOptionButton(
                    title: style.title,
                    subtitle: "Choose one or more",
                    isSelected: selectedStyles.contains(style)
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

            VStack(alignment: .leading) {
                content
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(.rect(cornerRadius: 24))
    }
}

private struct SelectableOptionButton: View {
    let title: String
    var subtitle: String? = nil
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading) {
                    Text(title)
                        .bold()
                    if let subtitle {
                        Text(subtitle)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .imageScale(.large)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                if isSelected {
                    Color.accentColor.opacity(0.16)
                } else {
                    Color.clear
                }
            }
            .clipShape(.rect(cornerRadius: 18))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    OnboardingView(existingPreferences: nil)
        .modelContainer(for: [UserWinePreferences.self, WineScan.self], inMemory: true)
}
