import SwiftUI

struct ScanLoadingView: View {
    let message: String

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.black.opacity(0.2))
                .ignoresSafeArea()

            VStack {
                ProgressView()
                    .controlSize(.large)
                Text(message)
                    .font(.title3)
                    .bold()
            }
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(.rect(cornerRadius: 24))
        }
    }
}
