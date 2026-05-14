import SwiftUI

struct RecentScansView: View {
    let scans: [WineScan]
    let openScan: (WineScan) -> Void
    let showAllScans: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text(.historyRecentTitle)
                    .font(.system(size: 22, weight: .semibold, design: .serif))

                Spacer()

                if scans.isEmpty == false {
                    Button(String(localized: .historySeeAll), action: showAllScans)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.wineAccent)
                }
            }

            if scans.isEmpty {
                Text(.historyEmptyRecent)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white.opacity(0.8))
                    .clipShape(.rect(cornerRadius: 20))
                    .overlay {
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.wineBorder, lineWidth: 1)
                    }
            } else {
                ForEach(scans.prefix(2)) { scan in
                    ScanHistoryCard(scan: scan, action: { openScan(scan) })
                }
            }
        }
    }
}

struct ScanHistoryCard: View {
    let scan: WineScan
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {

                VStack(alignment: .leading, spacing: 6) {
                    Text(scan.restaurantName ?? String(localized: .commonWineList))
                        .font(.headline.weight(.bold))
                        .foregroundStyle(Color.wineText)

                    Text(metadataText)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)

                    Text(.historyTopPick(topPickName))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.wineAccent)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Color.wineAccent.opacity(0.55))
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.92))
            .clipShape(.rect(cornerRadius: 26))
            .overlay {
                RoundedRectangle(cornerRadius: 26)
                    .stroke(Color.wineBorder, lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(0.04), radius: 18, y: 10)
        }
        .buttonStyle(.plain)
    }

    private var metadataText: String {
        var parts = [scan.purchaseModeValue.title]
        parts.append(scan.categoryPreferenceValue.title)
        parts.append(scan.createdAt.formatted(date: .abbreviated, time: .omitted))
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
