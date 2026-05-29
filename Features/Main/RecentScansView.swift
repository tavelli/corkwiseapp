import SwiftUI

struct RecentScansView: View {
    let scans: [WineScan]
    let openScan: (WineScan) -> Void
    let showAllScans: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text(scans.isEmpty ? String(localized: .historyEmptyTipsTitle) : String(localized: .historyRecentTitle))
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(Color.wineText)

                Spacer()

                if scans.isEmpty == false {
                    Button(String(localized: .historySeeAll), action: showAllScans)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.wineAccent)
                }
            }

            if scans.isEmpty {
                RecentScansEmptyStateCard()
            } else {
                ScanHistoryList(scans: Array(scans.prefix(2)), openScan: openScan)
            }
        }
    }
}

private struct RecentScansEmptyStateCard: View {
    private let tips = [
        Tip(
            title: .historyTipFullPageTitle,
            message: .historyTipFullPageMessage,
            systemImage: "viewfinder"
        ),
        Tip(
            title: .historyTipMultiplePagesTitle,
            message: .historyTipMultiplePagesMessage,
            systemImage: "doc.on.doc"
        ),
        Tip(
            title: .historyTipAvoidGlareTitle,
            message: .historyTipAvoidGlareMessage,
            systemImage: "sun.max"
        ),
    ]

        var body: some View {
            VStack(spacing: 0) {
            ForEach(Array(tips.enumerated()), id: \.offset) { index, tip in
                TipRow(tip: tip)

                if index < tips.count - 1 {
                    Divider()
                        .background(Color.wineDivider.opacity(0.65))
                        .padding(.leading, 60)
                        .padding(.trailing, 18)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.82))
        .clipShape(.rect(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.wineBorder, lineWidth: 1)
        }
    }

    private struct Tip {
        let title: LocalizedStringResource
        let message: LocalizedStringResource
        let systemImage: String
    }

    private struct TipRow: View {
        let tip: Tip

        var body: some View {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: tip.systemImage)
                    .font(.system(size: 20, weight: .regular))
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(Color.wineMutedText)
                    .frame(width: 42, height: 42)
                    .background(Color.wineCardBackground.opacity(0.82))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(tip.title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color.wineText)

                    Text(tip.message)
                        .font(.subheadline)
                        .foregroundStyle(Color.wineMutedText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct ScanHistoryList: View {
    let scans: [WineScan]
    let openScan: (WineScan) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(scans.indices, id: \.self) { index in
                let scan = scans[index]

                ScanHistoryRow(scan: scan) {
                    openScan(scan)
                }

                if index < scans.index(before: scans.endIndex) {
                    Divider()
                        .background(Color.wineDivider.opacity(0.65))
                        .padding(.leading, 18)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.92))
        .clipShape(.rect(cornerRadius: 26))
        .overlay {
            RoundedRectangle(cornerRadius: 26)
                .stroke(Color.wineBorder, lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.04), radius: 18, y: 10)
    }
}

private struct ScanHistoryRow: View {
    let scan: WineScan
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(scan.restaurantName ?? String(localized: .commonWineList))
                        .font(.headline.weight(.medium))
                        .foregroundStyle(Color.wineText)

                    Text(metadataText)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 6) {
                        Image(phosphor: .crownFill)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 15, height: 15)

                        Text(topPickName)
                            .font(.subheadline.weight(.regular))
                            .lineLimit(2)
                    }
                    .foregroundStyle(Color.resultHeroTop)
                    .accessibilityLabel(Text(.historyTopPick(topPickName)))
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.headline.weight(.medium))
                    .foregroundStyle(Color.wineText)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    private var metadataText: String {
        var parts = [scan.createdAt.formatted(Date.FormatStyle()
            .weekday(.abbreviated)
            .month(.abbreviated)
            .day())]
        parts.append(scan.purchaseModeValue.title)
        if scan.categoryPreferenceValue != .anything {
            parts.append(scan.categoryPreferenceValue.title)
        }
        return parts.joined(separator: " • ")
    }

    private var topPickName: String {
        guard
            let data = scan.resultJSON.data(using: .utf8),
            let result = try? JSONDecoder().decode(WineScanResult.self, from: data),
            let topRecommendation = result.recommendations.first
        else {
            return String(localized: .commonUnknown)
        }

        return topRecommendation.displayTitle
    }
}
