import SwiftData
import SwiftUI

struct PreferencesView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @Query(sort: \UserWinePreferences.createdAt) private var preferenceRecords: [UserWinePreferences]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if let preferences = preferenceRecords.first {
                    PreferenceSection(title: "Preferred Styles") {
                        VStack(spacing: 12) {
                            ForEach(WineStylePreference.allCases) { style in
                                Button {
                                    toggleStyle(style, preferences: preferences)
                                } label: {
                                    HStack {
                                        Text(style.title)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(Color.wineText)

                                        Spacer()

                                        Image(systemName: preferences.preferredStyleValues.contains(style) ? "checkmark.square.fill" : "square")
                                            .foregroundStyle(preferences.preferredStyleValues.contains(style) ? Color.wineAccent : .secondary)
                                    }
                                    .padding(16)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.white.opacity(0.7))
                                    .clipShape(.rect(cornerRadius: 18))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    PreferenceSection(title: "Favorite Varietals") {
                        VStack(alignment: .leading, spacing: 18) {
                            ForEach(WineVarietalCategory.allCases) { category in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(category.title)
                                        .font(.headline)
                                        .foregroundStyle(Color.wineText)

                                    ForEach(category.varietals) { varietal in
                                        Button {
                                            toggleVarietal(varietal, preferences: preferences)
                                        } label: {
                                            HStack(spacing: 12) {
                                                Text(varietal.title)
                                                    .font(.subheadline.weight(.semibold))
                                                    .foregroundStyle(Color.wineText)

                                                Spacer()

                                                Image(systemName: preferences.favoriteVarietalValues.contains(varietal) ? "checkmark.square.fill" : "square")
                                                    .foregroundStyle(preferences.favoriteVarietalValues.contains(varietal) ? Color.wineAccent : .secondary)
                                            }
                                            .padding(16)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .background(Color.white.opacity(0.7))
                                            .clipShape(.rect(cornerRadius: 18))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }

                    PreferenceSection(title: "Decision Style") {
                        Picker("Decision Style", selection: binding(for: preferences, keyPath: \.choiceStyle, defaultValue: ChoiceStyle.bestValue.rawValue)) {
                            ForEach(ChoiceStyle.allCases) { style in
                                Text(style.title).tag(style.rawValue)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(Color.wineAccent)
                    }

                    PreferenceSection(title: "Tone") {
                        VStack(spacing: 12) {
                            ForEach(TonePreference.allCases) { tone in
                                Button {
                                    preferences.tone = tone.rawValue
                                    preferences.updatedAt = .now
                                    try? modelContext.save()
                                } label: {
                                    HStack(alignment: .top, spacing: 12) {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(tone.title)
                                                .font(.subheadline.weight(.semibold))
                                                .foregroundStyle(Color.wineText)

                                            Text(tone.userDescription)
                                                .font(.footnote)
                                                .foregroundStyle(.secondary)
                                        }

                                        Spacer()

                                        Image(systemName: preferences.toneValue == tone ? "checkmark.circle.fill" : "circle")
                                            .foregroundStyle(preferences.toneValue == tone ? Color.wineAccent : .secondary)
                                    }
                                    .padding(16)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.white.opacity(0.7))
                                    .clipShape(.rect(cornerRadius: 18))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    #if DEBUG
                    PreferenceSection(title: "Debug") {
                        Button(role: .destructive) {
                            clearAllScans()
                        } label: {
                            Text("Clear All Scans")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(Color.wineAccent)

                        Button(role: .destructive) {
                            resetPreferences()
                        } label: {
                            Text("Reset Onboarding")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.wineAccent)

                        Text("Deletes the saved taste profile so the app returns to onboarding on next render.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    #endif
                } else {
                    Text("No preferences found. Complete onboarding to create your taste profile.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white.opacity(0.9))
                        .clipShape(.rect(cornerRadius: 20))
                }
            }
            .padding(20)
        }
        .navigationTitle("Preferences")
        .navigationBarTitleDisplayMode(.inline)
        .background(mainScreenBackground.ignoresSafeArea())
    }

    private func binding(
        for preferences: UserWinePreferences,
        keyPath: ReferenceWritableKeyPath<UserWinePreferences, String>,
        defaultValue: String
    ) -> Binding<String> {
        Binding(
            get: {
                let value = preferences[keyPath: keyPath]
                return value.isEmpty ? defaultValue : value
            },
            set: { newValue in
                preferences[keyPath: keyPath] = newValue
                preferences.updatedAt = .now
                try? modelContext.save()
            }
        )
    }

    private func toggleStyle(_ style: WineStylePreference, preferences: UserWinePreferences) {
        var selectedStyles = Set(preferences.preferredStyleValues)
        if selectedStyles.contains(style) {
            selectedStyles.remove(style)
        } else {
            selectedStyles.insert(style)
        }

        guard selectedStyles.isEmpty == false else { return }
        preferences.preferredStyles = selectedStyles.map(\.rawValue).sorted()
        preferences.updatedAt = .now
        try? modelContext.save()
    }

    private func toggleVarietal(_ varietal: WineVarietal, preferences: UserWinePreferences) {
        var selectedVarietals = Set(preferences.favoriteVarietalValues)
        if selectedVarietals.contains(varietal) {
            selectedVarietals.remove(varietal)
        } else {
            selectedVarietals.insert(varietal)
        }

        preferences.favoriteVarietals = selectedVarietals.map(\.rawValue).sorted()
        preferences.updatedAt = .now
        try? modelContext.save()
    }

    private func resetPreferences() {
        for preferences in preferenceRecords {
            modelContext.delete(preferences)
        }

        try? modelContext.save()
        appState.resetMainNavigation()
    }

    private func clearAllScans() {
        let fetchDescriptor = FetchDescriptor<WineScan>()
        let scans = (try? modelContext.fetch(fetchDescriptor)) ?? []

        for scan in scans {
            modelContext.delete(scan)
        }

        try? modelContext.save()
        appState.resetMainNavigation()
    }
}

private struct PreferenceSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.title3.weight(.bold))
                .foregroundStyle(Color.wineText)

            content
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.86))
        .clipShape(.rect(cornerRadius: 26))
        .overlay {
            RoundedRectangle(cornerRadius: 26)
                .stroke(Color.wineBorder, lineWidth: 1)
        }
    }
}

#Preview {
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: UserWinePreferences.self,
        WineScan.self,
        configurations: configuration
    )
    let context = ModelContext(container)

    context.insert(
        UserWinePreferences(
            preferredStyles: [
                WineStylePreference.crispRefreshing.rawValue,
                WineStylePreference.earthySavory.rawValue,
            ],
            favoriteVarietals: [
                WineVarietal.chardonnay.rawValue,
                WineVarietal.prosecco.rawValue,
                WineVarietal.pinotNoir.rawValue,
                WineVarietal.tempranillo.rawValue,
            ],
            choiceStyle: ChoiceStyle.interesting.rawValue,
            usualPurchasePreference: UsualPurchasePreference.bottle.rawValue,
            tone: TonePreference.sommelier.rawValue,
            hasCompletedOnboarding: true
        )
    )
    try! context.save()

    return PreferencesView()
        .environment(AppState())
        .modelContainer(container)
}
