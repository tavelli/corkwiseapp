import SwiftUI

struct RecentScansView: View {
    let scans: [WineScan]
    let openScan: (WineScan) -> Void
    let showAllScans: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Recent Scans")
                    .font(.system(size: 22, weight: .semibold, design: .serif))

                Spacer()

                if scans.isEmpty == false {
                    Button("See All", action: showAllScans)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.wineAccent)
                }
            }

            if scans.isEmpty {
                Text("No scans yet. Run a scan to start building local history.")
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
//                VStack(spacing: 8) {
//                    RoundedRectangle(cornerRadius: 18)
//                        .fill(
//                            LinearGradient(
//                                colors: [Color.wineAccent.opacity(0.16), Color.wineSoftPeach],
//                                startPoint: .top,
//                                endPoint: .bottom
//                            )
//                        )
//                        .frame(width: 64, height: 96)
//                        .overlay {
//                            Image(systemName: scan.purchaseModeValue == .glass ? "wineglass.fill" : "wineglass")
//                                .font(.system(size: 28))
//                                .foregroundStyle(Color.wineAccent.opacity(0.85))
//                        }
//
//                    Text(scoreText)
//                        .font(.headline.weight(.bold))
//                        .foregroundStyle(Color.wineAccent)
//                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(scan.restaurantName ?? "Wine List")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(Color.wineText)

                    Text(metadataText)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)

                    Text("Top pick: \(scan.bestPickName ?? "Unknown")")
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

    private var scoreText: String {
        (scan.bestPickScore ?? 0).formatted(.number.precision(.fractionLength(1)))
    }

    private var metadataText: String {
        var parts = [scan.purchaseModeValue.title]
        parts.append(scan.categoryPreferenceValue.title)

        // this was for me / for a group thing we can probably delete
//        if scan.purchaseModeValue == .bottle, let bottleContext = scan.bottleContextValue {
//            parts.append(bottleContext.shortTitle)
//        }

        parts.append(scan.createdAt.formatted(date: .abbreviated, time: .omitted))
        return parts.joined(separator: " • ")
    }
}
