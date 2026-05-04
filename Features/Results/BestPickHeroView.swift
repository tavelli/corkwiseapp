import SwiftUI

struct BestPickHeroView: View {
    let summary: ScanSummary
    let restaurantName: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "star.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.resultHeroIvory)
                            .frame(width: 22, height: 22)
                            .background(Color.white.opacity(0.12))
                            .clipShape(.rect(cornerRadius: 7))

                        Text("TOP PICK")
                            .font(.caption.weight(.bold))
                            .tracking(0.8)
                            .foregroundStyle(Color.white.opacity(0.95))
                    }

                    Text(summary.bestPickName)
                        .font(.system(size: 25, weight: .bold, design: .serif))
                        .foregroundStyle(Color.white.opacity(0.95))
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Score")
                        .font(.subheadline)
                        .foregroundStyle(Color.white.opacity(0.95))
                    Text(summary.bestPickScore.formatted(.number.precision(.fractionLength(1))))
                        .font(.system(size: 31, weight: .bold, design: .serif))
                        .bold()
                        .foregroundStyle(Color.resultHeroIvory)
                }
            }

            Text(summary.bestPickWhy)
                .font(.body)
                .lineSpacing(2)
                .foregroundStyle(Color.white.opacity(0.95))

//            if let restaurantName {
//                Label(restaurantName, systemImage: "fork.knife")
//                    .font(.footnote)
//                    .foregroundStyle(Color.white.opacity(0.9))
//            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack {
                LinearGradient(
                    colors: [.resultHeroTop, .resultHeroBottom],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                LinearGradient(
                    colors: [
                        Color.black.opacity(0.14),
                        Color.clear,
                        Color.black.opacity(0.22),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .blendMode(.multiply)
            }
        )
        .overlay {
            Rectangle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.10),
                            Color.clear,
                        ],
                        center: .topTrailing,
                        startRadius: 8,
                        endRadius: 220
                    )
                )
                .blendMode(.screen)
        }
        .overlay(alignment: .bottomTrailing) {
            Circle()
                .fill(Color.resultHeroIvory.opacity(0.06))
                .frame(width: 132, height: 132)
                .offset(x: 40, y: 40)
        }
        .overlay(alignment: .topLeading) {
            Circle()
                .fill(Color.white.opacity(0.05))
                .frame(width: 180, height: 180)
                .offset(x: -50, y: -70)
        }
        .clipShape(.rect(cornerRadius: 28))
        .shadow(color: Color.black.opacity(0.08), radius: 18, y: 10)
    }
}
