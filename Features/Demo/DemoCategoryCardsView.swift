#if DEBUG
import SwiftUI

struct DemoCategoryCardsView: View {
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(DemoCategoryCard.Category.allCases) { category in
                    DemoCategoryCard(category: category)
                }
            }
            .padding(20)
        }
        .background(mainScreenBackground.ignoresSafeArea())
        .persistentSystemOverlays(.hidden)
        .statusBarHidden(true)
    }
}

private struct DemoCategoryCard: View {
    let category: Category

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(phosphor: category.icon)
                .resizable()
                .scaledToFit()
                .foregroundStyle(Color.wineAccent)
                .frame(width: 46, height: 46)
                .frame(width: 64, height: 64)

            Text(category.title)
                .font(.title3)
                .bold()
                .multilineTextAlignment(.leading)
                .foregroundStyle(Color.wineAccent)
                .minimumScaleFactor(0.82)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .center)
        .frame(minHeight: 80)
        .background(Color.resultCardBackground)
        .clipShape(.rect(cornerRadius: 22))
        .overlay {
            RoundedRectangle(cornerRadius: 22)
                .stroke(Color.wineBorder.opacity(0.85), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.035), radius: 12, y: 6)
    }

    enum Category: CaseIterable, Identifiable {
        case bestValue
        case worthTheSplurge
//        case crowdPleaser
//        case hiddenGem
        case trySomethingNew

        var id: Self { self }

        var title: String {
            switch self {
            case .bestValue:
                return String(localized: .resultsCategoryBestValue)
            case .worthTheSplurge:
                return String(localized: .resultsCategoryWorthTheSplurge)
//            case .crowdPleaser:
//                return String(localized: .resultsCategoryCrowdPleaser)
//            case .hiddenGem:
                // return String(localized: .resultsCategoryHiddenGem)
                
            case .trySomethingNew:
                return String(localized: .resultsCategoryTrySomethingNew)
                
            }
        }

        var icon: PhosphorIcon {
            switch self {
            case .bestValue:
                return .chartBar
            case .worthTheSplurge:
                return .medal
//            case .crowdPleaser:
//                return .sealCheck
//            case .hiddenGem:
                // return .listMagnifyingGlass
            case .trySomethingNew:
                return .arrowsSplit
            }
        }
    }
}

#Preview {
    DemoCategoryCardsView()
}
#endif
