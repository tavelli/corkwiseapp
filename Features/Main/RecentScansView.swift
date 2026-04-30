import SwiftUI

struct RecentScansView: View {
    let scans: [WineScan]
    let openScan: (WineScan) -> Void

    var body: some View {
        VStack(alignment: .leading) {
            Text("Recent Scans")
                .font(.title2)
                .bold()

            if scans.isEmpty {
                Text("No scans yet. Run a scan to start building local history.")
                    .foregroundStyle(.secondary)
                    .padding()
                    .background(.thinMaterial)
                    .clipShape(.rect(cornerRadius: 20))
            } else {
                ForEach(scans) { scan in
                    Button {
                        openScan(scan)
                    } label: {
                        VStack(alignment: .leading) {
                            Text(scan.restaurantName ?? "Wine List")
                                .bold()
                            Text("\(scan.purchaseModeValue.title) · \(scan.createdAt.formatted(date: .abbreviated, time: .omitted))")
                                .foregroundStyle(.secondary)
                            Text("Best pick: \(scan.bestPickName ?? "Unknown") · \((scan.bestPickScore ?? 0).formatted(.number.precision(.fractionLength(1))))")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.thinMaterial)
                        .clipShape(.rect(cornerRadius: 20))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
