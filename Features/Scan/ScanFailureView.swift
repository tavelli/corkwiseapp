import SwiftUI

struct ScanFailureView: View {
    let title: String
    let message: String
    let canRetry: Bool
    let retryAction: () -> Void
    let uploadAction: () -> Void

    var body: some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.title2)
                .bold()

            Text(message)
                .foregroundStyle(.secondary)

            if canRetry {
                Button(String(localized: .commonActionTryAgain), action: retryAction)
                    .buttonStyle(.borderedProminent)
            }

            Button(String(localized: .scanFailureUploadPhoto), action: uploadAction)
                .buttonStyle(.bordered)
        }
        .padding()
    }
}
