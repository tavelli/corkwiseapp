import SwiftUI

struct BestPickHeroView: View {
    let summary: ScanSummary
    let restaurantName: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Best Pick")
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.8))

                    Text(summary.bestPickName)
                        .font(.title2)
                        .bold()
                        .foregroundStyle(.white)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Score")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.75))
                    Text(summary.bestPickScore.formatted(.number.precision(.fractionLength(1))))
                        .font(.largeTitle)
                        .bold()
                        .foregroundStyle(.white)
                }
            }

            Text(summary.bestPickWhy)
                .foregroundStyle(.white.opacity(0.88))

            if let restaurantName {
                Label(restaurantName, systemImage: "fork.knife")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.78))
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [.heroBackgroundTop, .heroBackgroundBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(alignment: .bottomTrailing) {
            Circle()
                .fill(.white.opacity(0.08))
                .frame(width: 120, height: 120)
                .offset(x: 36, y: 36)
        }
        .clipShape(.rect(cornerRadius: 28))
    }
}
