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
                Button("Try Again", action: retryAction)
                    .buttonStyle(.borderedProminent)
            }

            Button("Upload Photo", action: uploadAction)
                .buttonStyle(.bordered)
        }
        .padding()
    }
}
