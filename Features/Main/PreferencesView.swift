import SwiftData
import SwiftUI

struct PreferencesView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @Query(sort: \UserWinePreferences.createdAt) private var preferenceRecords: [UserWinePreferences]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 40) {
                if let preferences = preferenceRecords.first {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(.preferencesSectionPreferredStyles)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(Color.wineText)

                        VStack(spacing: 0) {
                            ForEach(WineStylePreference.allCases) { style in
                                let isSelected = preferences.preferredStyleValues.contains(style)

                                PreferenceOptionRow(
                                    title: style.title,
                                    isSelected: isSelected,
                                    isLast: style == WineStylePreference.allCases.last
                                ) {
                                    toggleStyle(style, preferences: preferences)
                                }
                            }
                        }
                        .background(Color.white.opacity(0.72))
                        .clipShape(.rect(cornerRadius: 8))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.wineBorder, lineWidth: 1)
                        }
                    }

                    VStack(alignment: .leading, spacing: 20) {
                        Text(.preferencesSectionFavoriteVarietals)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(Color.wineText)

                        VStack(alignment: .leading, spacing: 30) {
                            ForEach(WineVarietalCategory.allCases) { category in
                                VStack(alignment: .leading, spacing: 12) {
                                    Text(category.title)
                                        .font(.headline)
                                        .foregroundStyle(Color.wineText)

                                    VStack(spacing: 0) {
                                        ForEach(category.varietals) { varietal in
                                            let isSelected = preferences.favoriteVarietalValues.contains(varietal)

                                            PreferenceOptionRow(
                                                title: varietal.title,
                                                isSelected: isSelected,
                                                isLast: varietal == category.varietals.last
                                            ) {
                                                toggleVarietal(varietal, preferences: preferences)
                                            }
                                        }
                                    }
                                    .background(Color.white.opacity(0.72))
                                    .clipShape(.rect(cornerRadius: 8))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.wineBorder, lineWidth: 1)
                                    }
                                }
                            }
                        }
                    }


                    #if DEBUG
                    PreferenceSection(title: .preferencesSectionTone) {
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
                    #endif

                    #if DEBUG
                    PreferenceSection(title: .preferencesSectionDebug) {
                        Button(role: .destructive) {
                            clearAllScans()
                        } label: {
                            Text(.preferencesDebugClearAllScans)
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(Color.wineAccent)

                        Button(role: .destructive) {
                            resetPreferences()
                        } label: {
                            Text(.preferencesDebugResetOnboarding)
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.wineAccent)

                        Text(.preferencesDebugResetExplanation)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    #endif
                } else {
                    Text(.preferencesEmptyMessage)
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
        .navigationTitle(String(localized: .preferencesTitle))
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

private struct PreferenceOptionRow: View {
    let title: String
    let isSelected: Bool
    let isLast: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                HStack {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(isSelected ? Color.wineAccent : Color.wineText)

                    Spacer()

                    Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                        .foregroundStyle(isSelected ? Color.wineAccent : Color.wineMutedText.opacity(0.45))
                }
                .padding(.horizontal)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(.rect)
                .background(isSelected ? Color.wineSoftPeach.opacity(0.24) : Color.clear)

                if isLast == false {
                    Divider()
                        .overlay(Color.wineDivider)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

private struct PreferenceSection<Content: View>: View {
    let title: LocalizedStringResource
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
