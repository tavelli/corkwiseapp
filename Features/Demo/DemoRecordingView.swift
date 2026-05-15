#if DEBUG
import SwiftUI

struct DemoRecordingView: View {
    @State private var result: WineScanResult?
    @State private var loadingError: String?

    private let purchaseMode = PurchaseMode.bottle
    private let viewedAt = Date()

    var body: some View {
        NavigationStack {
            ZStack {
                ScanProgressExperienceView(
                    result: result,
                    purchaseMode: purchaseMode,
                    categoryPreference: .anything,
                    viewedAt: viewedAt,
                    showsPageHeader: false,
                    showsCancelAction: false,
                    cancelAction: {}
                )

                if let loadingError {
                    DemoFixtureFailureView(message: loadingError)
                }
            }
        }
        .statusBarHidden(true)
        .task {
            await loadDemoResult()
        }
    }

    private func loadDemoResult() async {
        guard result == nil else { return }

        do {
            let demoResult = try Self.decodeDemoResult()
            try await Task.sleep(for: .seconds(3))
            guard Task.isCancelled == false else { return }
            result = demoResult
        } catch {
            loadingError = error.localizedDescription
        }
    }

    private static func decodeDemoResult() throws -> WineScanResult {
        guard let url = Bundle.main.url(forResource: "DemoWineScanResult", withExtension: "json") else {
            throw DemoRecordingError.missingFixture
        }

        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(WineScanResult.self, from: data)
    }
}

private struct DemoFixtureFailureView: View {
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Text("Demo fixture failed to load")
                .font(.headline)
                .foregroundStyle(Color.wineText)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(Color.wineMutedText)
                .multilineTextAlignment(.center)
        }
        .padding(20)
        .background(Color.resultCardBackground)
        .clipShape(.rect(cornerRadius: 18))
        .padding(24)
    }
}

private enum DemoRecordingError: LocalizedError {
    case missingFixture

    var errorDescription: String? {
        switch self {
        case .missingFixture:
            return "DemoWineScanResult.json was not found in the app bundle."
        }
    }
}

#Preview {
    DemoRecordingView()
}
#endif
