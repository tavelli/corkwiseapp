import Combine
import SwiftUI

struct ScanProgressResultsView: View {
    @Environment(AppState.self) private var appState
    @State private var startedAt = Date()
    @State private var progress = 0.01
    @State private var isCompleting = false
    @State private var isOverlayVisible = true
    @State private var isShowingCancelConfirmation = false

    let scanID: UUID

    private let timer = Timer.publish(every: 0.12, on: .main, in: .common).autoconnect()

    private var presentation: ScanPresentation? {
        guard appState.activeScanPresentation?.id == scanID else { return nil }
        return appState.activeScanPresentation
    }

    private var result: WineScanResult? {
        presentation?.result
    }

    private var purchaseMode: PurchaseMode {
        presentation?.purchaseMode ?? .bottle
    }

    private var viewedAt: Date {
        presentation?.viewedAt ?? startedAt
    }

    private var elapsedSeconds: TimeInterval {
        Date().timeIntervalSince(startedAt)
    }

    private var pageTitle: String {
        guard isOverlayVisible == false else { return "" }
        guard let result else { return "Analyzing Wine List" }

        let restaurantName = result.restaurantName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayName = if let restaurantName, restaurantName.isEmpty == false {
            restaurantName
        } else {
            "Wine List"
        }

        return "\(displayName) - \(viewedAt.formatted(date: .abbreviated, time: .omitted)) "
    }

    var body: some View {
        ZStack {
            if let result {
                ResultsContentView(result: result, purchaseMode: purchaseMode)
            } else {
                ScanResultsSkeletonView()
            }

            if isOverlayVisible {
                Color.black
                    .opacity(0.32)
                    .ignoresSafeArea()
                    .transition(.opacity)

                ScanProgressModal(
                    progress: progress,
                    elapsedSeconds: elapsedSeconds,
                    isCompleting: isCompleting,
                    purchaseMode: purchaseMode,
                    isCancelVisible: isCancelVisible,
                    cancelAction: {
                        isShowingCancelConfirmation = true
                    }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
                .zIndex(1)
            }

        }
        .background(mainScreenBackground.ignoresSafeArea())
        .navigationTitle(pageTitle)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(isOverlayVisible)
        .interactiveDismissDisabled(isOverlayVisible)
        .onAppear {
            startedAt = Date()
            progress = 0.01
        }
        .onReceive(timer) { _ in
            guard result == nil, isCompleting == false else { return }
            withAnimation(.linear(duration: 0.18)) {
                progress = estimatedProgress(for: elapsedSeconds)
            }
        }
        .onChange(of: result) { _, newValue in
            guard newValue != nil, isCompleting == false else { return }
            completeLoadingExperience()
        }
        .sheet(isPresented: $isShowingCancelConfirmation) {
            ScanCancelConfirmationSheet(
                keepScanningAction: {
                    isShowingCancelConfirmation = false
                },
                cancelScanAction: {
                    isShowingCancelConfirmation = false
                    appState.cancelScanProgress(id: scanID)
                }
            )
            .presentationDetents([.height(238)])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(28)
        }
    }

    private var isCancelVisible: Bool {
        result == nil && isCompleting == false
    }

    private func estimatedProgress(for elapsed: TimeInterval) -> Double {
        switch elapsed {
        case ..<2:
            return interpolate(elapsed, start: 0, end: 2, from: 0.01, to: 0.15)
        case ..<7:
            return interpolate(elapsed, start: 2, end: 7, from: 0.15, to: 0.40)
        case ..<17:
            return interpolate(elapsed, start: 7, end: 17, from: 0.40, to: 0.85)
        case ..<20:
            return interpolate(elapsed, start: 17, end: 20, from: 0.85, to: 0.945)
        default:
            return 0.945
        }
    }

    private func interpolate(
        _ value: TimeInterval,
        start: TimeInterval,
        end: TimeInterval,
        from: Double,
        to: Double
    ) -> Double {
        let fraction = min(max((value - start) / (end - start), 0), 1)
        return from + (to - from) * fraction
    }

    private func completeLoadingExperience() {
        isCompleting = true

        withAnimation(.easeOut(duration: 0.22)) {
            progress = 1
        }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(340))
            withAnimation(.easeOut(duration: 0.24)) {
                isOverlayVisible = false
            }
        }
    }
}

private struct ScanCancelConfirmationSheet: View {
    let keepScanningAction: () -> Void
    let cancelScanAction: () -> Void

    var body: some View {
        VStack(spacing: 22) {
            VStack(spacing: 8) {
                Text("Cancel scan?")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.wineText)

                Text("Your recommendations will be discarded.")
                    .font(.subheadline)
                    .foregroundStyle(Color.wineMutedText)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 24)

            VStack(spacing: 10) {
                Button("Keep scanning", action: keepScanningAction)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(Color.wineMutedText.opacity(0.78))
                    .clipShape(.rect(cornerRadius: 14))

                Button("Cancel scan", role: .destructive, action: cancelScanAction)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 24)
        .presentationBackground(Color(red: 0.998, green: 0.992, blue: 0.985))
    }
}

private struct ScanProgressModal: View {
    let progress: Double
    let elapsedSeconds: TimeInterval
    let isCompleting: Bool
    let purchaseMode: PurchaseMode
    let isCancelVisible: Bool
    let cancelAction: () -> Void

    private let steps = [
        "Scanning menu",
        "Reading wine list",
        "Evaluating quality & value",
        "Curating recommendations",
    ]

    private var activeStepIndex: Int {
        if isCompleting { return steps.count }

        switch elapsedSeconds {
        case ..<2:
            return 0
        case ..<7:
            return 1
        case ..<17:
            return 2
        default:
            return 3
        }
    }

    private var footerText: String {
        guard isCompleting == false else { return "Finishing up..." }
        guard elapsedSeconds < 20 else { return "Finishing up..." }

        let remaining = max(1, Int(ceil(20 - elapsedSeconds)))
        return "~\(remaining) sec remaining"
    }

    private var titleText: String {
        switch purchaseMode {
        case .glass:
            return "Finding the best pours"
        case .bottle:
            return "Finding the best bottles"
        }
    }

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 24) {
                VStack(spacing: 6) {
                    Text(titleText)
                        .font(.system(size: 21, weight: .bold, design: .serif))
                        .foregroundStyle(Color.wineText)

                    Text("takes about 20 seconds")
                        .font(.subheadline)
                        .foregroundStyle(Color.wineMutedText)
                }

                VStack(spacing: 18) {
                    ForEach(Array(steps.enumerated()), id: \.offset) { index, title in
                        ScanProgressStepRow(
                            title: title,
                            state: state(for: index)
                        )
                    }
                }
                .padding(.bottom, 2)

                VStack(spacing: 11) {
                    ScanProgressBar(progress: progress)

                    HStack {
                        Text(footerText)
                            .foregroundStyle(Color.wineMutedText.opacity(0.92))
                        Spacer()
                        Button("Cancel", action: cancelAction)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.wineMutedText.opacity(0.68))
                            .buttonStyle(.plain)
                            .opacity(isCancelVisible ? 1 : 0)
                            .allowsHitTesting(isCancelVisible)
                            .animation(.easeOut(duration: 0.28), value: isCancelVisible)
                    }
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                }
            }
            .padding(22)
            .frame(width: min(proxy.size.width - 48, 336))
            .background(Color(red: 0.998, green: 0.992, blue: 0.985))
            .clipShape(.rect(cornerRadius: 22))
            .overlay {
                RoundedRectangle(cornerRadius: 22)
                    .stroke(Color.wineBorder.opacity(0.58), lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(0.30), radius: 34, y: 18)
            .shadow(color: Color.wineDeep.opacity(0.08), radius: 10, y: 4)
            .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
        }
    }

    private func state(for index: Int) -> ScanProgressStepRow.State {
        if isCompleting || index < activeStepIndex {
            return .completed
        }

        if index == activeStepIndex {
            return .active
        }

        return .upcoming
    }
}

private struct ScanProgressBar: View {
    let progress: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.wineMutedText.opacity(0.28))

                Capsule()
                    .fill(Color.wineAccent)
                    .frame(width: max(proxy.size.width * progress, 6))
            }
        }
        .frame(height: 7)
        .animation(.easeOut(duration: 0.22), value: progress)
    }
}

private struct ScanProgressStepRow: View {
    enum State {
        case upcoming
        case active
        case completed
    }

    let title: String
    let state: State

    var body: some View {
        HStack(spacing: 11) {
            indicator
                .frame(width: 20, height: 20)
                .animation(.easeInOut(duration: 0.20), value: state)

            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(textColor)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .opacity(rowOpacity)
        .offset(y: rowOffset)
        .scaleEffect(state == .completed ? 0.995 : 1, anchor: .leading)
        .animation(.easeOut(duration: 0.26), value: state)
    }

    private var textColor: Color {
        switch state {
        case .upcoming:
            return Color.wineMutedText.opacity(0.88)
        case .active:
            return Color.wineText
        case .completed:
            return Color.wineText.opacity(0.72)
        }
    }

    private var rowOpacity: Double {
        switch state {
        case .upcoming:
            return 0.78
        case .active:
            return 1
        case .completed:
            return 0.88
        }
    }

    private var indicator: some View {
        ZStack {
            if state == .upcoming {
                Circle()
                    .stroke(Color.wineMutedText.opacity(0.42), lineWidth: 1.4)
                    .frame(width: 12, height: 12)
                    .transition(.opacity.combined(with: .scale(scale: 0.88)))
            }

            if state == .active {
                ActiveStepRing()
                    .transition(.opacity.combined(with: .scale(scale: 0.88)))
            }

            if state == .completed {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.wineAccent)
                    .transition(.opacity.combined(with: .scale(scale: 0.76)))
            }
        }
    }

    private var rowOffset: CGFloat {
        switch state {
        case .upcoming:
            return 3
        case .active, .completed:
            return 0
        }
    }
}

private struct ActiveStepRing: View {
    @State private var isRotating = false

    var body: some View {
        Circle()
            .trim(from: 0.08, to: 0.76)
            .stroke(
                Color.wineAccent,
                style: StrokeStyle(lineWidth: 2.3, lineCap: .round)
            )
            .frame(width: 17, height: 17)
            .rotationEffect(.degrees(isRotating ? 360 : 0))
            .animation(.linear(duration: 0.95).repeatForever(autoreverses: false), value: isRotating)
            .onAppear {
                isRotating = true
            }
    }
}

private struct ScanResultsSkeletonView: View {
    @State private var isPulsing = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                heroSkeleton
                menuSnapshotSkeleton

                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 10) {
                        Circle()
                            .fill(skeletonFill)
                            .frame(width: 38, height: 38)
                        Capsule()
                            .fill(skeletonFill)
                            .frame(width: 170, height: 22)
                    }

                    ForEach(0..<3, id: \.self) { _ in
                        pickCardSkeleton
                    }
                }
            }
            .padding(20)
        }
        .opacity(isPulsing ? 0.84 : 0.68)
        .animation(.easeInOut(duration: 1.15).repeatForever(autoreverses: true), value: isPulsing)
        .onAppear {
            isPulsing = true
        }
        .accessibilityHidden(true)
    }

    private var heroSkeleton: some View {
        VStack(alignment: .leading, spacing: 18) {
            Capsule()
                .fill(Color.white.opacity(0.20))
                .frame(width: 92, height: 18)

            HStack(spacing: 14) {
                Circle()
                    .fill(Color.white.opacity(0.18))
                    .frame(width: 58, height: 58)

                VStack(alignment: .leading, spacing: 8) {
                    Capsule()
                    .fill(Color.white.opacity(0.30))
                        .frame(width: 210, height: 22)
                    Capsule()
                        .fill(Color.white.opacity(0.22))
                        .frame(width: 150, height: 16)
                }
            }

            HStack(spacing: 12) {
                ForEach(0..<3, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(0.22))
                        .frame(height: 44)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Capsule()
                    .fill(Color.white.opacity(0.28))
                    .frame(height: 14)
                Capsule()
                    .fill(Color.white.opacity(0.21))
                    .frame(width: 250, height: 14)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [
                    Color.resultHeroTop.opacity(0.50),
                    Color.resultHeroBottom.opacity(0.50),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(.rect(cornerRadius: 28))
        .shadow(color: Color.black.opacity(0.025), radius: 12, y: 6)
    }

    private var menuSnapshotSkeleton: some View {
        VStack(alignment: .leading, spacing: 10) {
            Capsule()
                .fill(skeletonFill)
                .frame(width: 120, height: 14)
            Capsule()
                .fill(skeletonFill)
                .frame(height: 13)
            Capsule()
                .fill(skeletonFill)
                .frame(width: 240, height: 13)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.resultCardBackground.opacity(0.74))
        .clipShape(.rect(cornerRadius: 22))
        .overlay {
            RoundedRectangle(cornerRadius: 22)
                .stroke(Color.wineBorder.opacity(0.38), lineWidth: 1)
        }
    }

    private var pickCardSkeleton: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                Circle()
                    .fill(skeletonFill)
                    .frame(width: 42, height: 42)

                VStack(alignment: .leading, spacing: 7) {
                    Capsule()
                        .fill(skeletonFill)
                        .frame(width: 190, height: 17)
                    Capsule()
                        .fill(skeletonFill)
                        .frame(width: 132, height: 13)
                }
            }

            HStack(spacing: 12) {
                ForEach(0..<3, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 8)
                        .fill(skeletonFill)
                        .frame(height: 36)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Capsule()
                    .fill(skeletonFill)
                    .frame(width: 94, height: 13)
                Capsule()
                    .fill(skeletonFill)
                    .frame(height: 12)
                Capsule()
                    .fill(skeletonFill)
                    .frame(width: 230, height: 12)
            }
        }
        .padding(20)
        .background(Color.resultCardBackground.opacity(0.72))
        .clipShape(.rect(cornerRadius: 22))
        .overlay {
            RoundedRectangle(cornerRadius: 22)
                .stroke(Color.wineBorder.opacity(0.34), lineWidth: 1)
        }
    }

    private var skeletonFill: Color {
        Color.wineMutedText.opacity(0.17)
    }
}

#if DEBUG
#Preview("Loading Skeleton") {
    ScanProgressPreviewHost()
}

#Preview("Results Behind Modal") {
    ScanProgressPreviewHost(result: ScanProgressPreviewHost.sampleResult)
}

private struct ScanProgressPreviewHost: View {
    @State private var appState: AppState
    private let scanID: UUID

    init(result: WineScanResult? = nil) {
        let appState = AppState()
        let presentation = ScanPresentation(purchaseMode: .bottle, viewedAt: .now)
        presentation.result = result
        appState.activeScanPresentation = presentation

        _appState = State(initialValue: appState)
        scanID = presentation.id
    }

    var body: some View {
        NavigationStack {
            ScanProgressResultsView(scanID: scanID)
        }
        .environment(appState)
    }

    static var sampleResult: WineScanResult {
        WineScanResult.sample(
            for: .bottle,
            preferences: UserWinePreferences(
                preferredStyles: [WineStylePreference.earthySavory.rawValue],
                favoriteVarietals: ["Pinot Noir", "Nebbiolo"],
                choiceStyle: ChoiceStyle.bestValue.rawValue,
                usualPurchasePreference: UsualPurchasePreference.bottle.rawValue,
                hasCompletedOnboarding: true
            )
        )
    }
}
#endif
