import AVFoundation
import SwiftUI
import UIKit

private let wineListCameraPageLimit = 4

struct WineListCameraView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var cameraModel: WineListCameraModel
    @State private var showingDiscardConfirmation = false

    let onAnalyze: ([UIImage]) -> Void
    let onUnavailable: () -> Void
    private let previewBackgroundImage: UIImage?

    init(
        onAnalyze: @escaping ([UIImage]) -> Void,
        onUnavailable: @escaping () -> Void
    ) {
        self.onAnalyze = onAnalyze
        self.onUnavailable = onUnavailable
        previewBackgroundImage = nil
        _cameraModel = State(initialValue: WineListCameraModel())
    }

    init(
        previewCapturedImages: [UIImage] = [],
        previewBackgroundImage: UIImage? = nil,
        onAnalyze: @escaping ([UIImage]) -> Void,
        onUnavailable: @escaping () -> Void
    ) {
        self.onAnalyze = onAnalyze
        self.onUnavailable = onUnavailable
        self.previewBackgroundImage = previewBackgroundImage
        _cameraModel = State(initialValue: WineListCameraModel(previewCapturedImages: previewCapturedImages))
    }

    var body: some View {
        ZStack {
            if let previewBackgroundImage {
                Image(uiImage: previewBackgroundImage)
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
            } else {
                CameraPreviewView(session: cameraModel.session)
                    .ignoresSafeArea()
            }

            Color.black.opacity(0.18)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar

                Spacer()

                bottomControls
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
        }
        .background(Color.black.ignoresSafeArea())
        .task {
            await cameraModel.start()
            if cameraModel.authorizationStatus == .unavailable {
                dismiss()
                onUnavailable()
            }
        }
        .onDisappear {
            cameraModel.stop()
        }
        .confirmationDialog(
            "Discard captured pages?",
            isPresented: $showingDiscardConfirmation,
            titleVisibility: .visible
        ) {
            Button("Discard Pages", role: .destructive) {
                dismiss()
            }

            Button("Keep Capturing", role: .cancel) {}
        }
    }

    private var topBar: some View {
        HStack {
            Button("Close", systemImage: "xmark") {
                close()
            }
            .labelStyle(.iconOnly)
            .font(.headline)
            .foregroundStyle(.white)
            .frame(width: 44, height: 44)
            .background(.black.opacity(0.42))
            .clipShape(.circle)
            .accessibilityLabel("Close camera")

            Spacer()

            if cameraModel.isFlashAvailable {
                Button(cameraModel.flashMode.accessibilityLabel, systemImage: cameraModel.flashMode.systemImage) {
                    cameraModel.cycleFlashMode()
                }
                .labelStyle(.iconOnly)
                .font(.headline)
                .foregroundStyle(cameraModel.flashMode.tint)
                .frame(width: 44, height: 44)
                .background(.black.opacity(0.42))
                .clipShape(.circle)
                .accessibilityLabel(cameraModel.flashMode.accessibilityLabel)
            } else {
                Color.clear
                    .frame(width: 44, height: 44)
            }
        }
    }

    private var bottomControls: some View {
        VStack(spacing: 16) {
            if cameraModel.capturedPages.isEmpty == false {
                if cameraModel.hasReachedPageLimit {
                    Text("Maximum 4 pages")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(.black.opacity(0.46))
                        .clipShape(.capsule)
                }

                thumbnailStrip
            } else {
                Text("Snap each page")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.92))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.black.opacity(0.34))
                    .clipShape(.capsule)
            }

            HStack(alignment: .center) {
                Color.clear
                    .frame(width: 104, height: 52)

                Spacer()

                shutterButton

                Spacer()

                if cameraModel.canAnalyze {
                    analyzeButton
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                } else {
                    Color.clear
                        .frame(width: 104, height: 52)
                }
            }
            .animation(.easeOut(duration: 0.18), value: cameraModel.canAnalyze)
        }
    }

    private var thumbnailStrip: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 10) {
                ForEach(cameraModel.capturedPages.enumerated(), id: \.element.id) { index, page in
                    CapturedPageThumbnail(
                        page: page,
                        number: index + 1,
                        deleteAction: {
                            cameraModel.deletePage(id: page.id)
                        }
                    )
                }
            }
            .padding(.horizontal, 2)
            .padding(.top, 8)
        }
        .scrollIndicators(.hidden)
        .frame(height: 100)
    }

    private var analyzeButton: some View {
        Button("Analyze") {
            let images = cameraModel.capturedPages.map(\.image)
            dismiss()
            onAnalyze(images)
        }
        .font(.headline.bold())
        .foregroundStyle(Color.wineSoftPeach)
        .frame(width: 104, height: 52)
        .background(Color.wineAccent)
        .clipShape(.rect(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.wineSoftPeach.opacity(0.34), lineWidth: 1)
        }
        .accessibilityLabel("Analyze captured pages")
    }

    private var shutterButton: some View {
        Button {
            cameraModel.capturePage()
        } label: {
            ZStack {
                Circle()
                    .stroke(.white.opacity(cameraModel.canCapture ? 0.9 : 0.36), lineWidth: 4)
                    .frame(width: 78, height: 78)

                Circle()
                    .fill(cameraModel.canCapture ? Color.white : Color.white.opacity(0.28))
                    .frame(width: 62, height: 62)
            }
        }
        .buttonStyle(.plain)
        .disabled(cameraModel.canCapture == false)
        .accessibilityLabel(cameraModel.capturedPages.count >= wineListCameraPageLimit ? "Page limit reached" : "Capture page")
    }

    private func close() {
        if cameraModel.capturedPages.isEmpty {
            dismiss()
        } else {
            showingDiscardConfirmation = true
        }
    }
}

private struct CapturedPageThumbnail: View {
    let page: CapturedWineListPage
    let number: Int
    let deleteAction: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Image(uiImage: page.image)
                .resizable()
                .scaledToFill()
                .frame(width: 64, height: 82)
                .clipShape(.rect(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(.white.opacity(0.68), lineWidth: 1)
                }

            Button(action: deleteAction) {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.92))
                    .frame(width: 24, height: 24)
                    .background(.black.opacity(0.48))
                    .clipShape(.circle)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Delete page \(number)")
            .offset(x: 7, y: -7)
        }
        .frame(width: 76, height: 92, alignment: .bottom)
    }
}

private struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let previewView = PreviewView()
        previewView.previewLayer.session = session
        previewView.previewLayer.videoGravity = .resizeAspectFill
        return previewView
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        uiView.previewLayer.session = session
    }
}

private final class PreviewView: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }
}

private struct CapturedWineListPage: Identifiable {
    let id = UUID()
    let image: UIImage
}

private enum WineListCameraAuthorizationStatus {
    case unknown
    case ready
    case unavailable
}

private enum WineListFlashMode: CaseIterable {
    case auto
    case on
    case off

    var systemImage: String {
        switch self {
        case .auto:
            "bolt.badge.a.fill"
        case .on:
            "bolt.fill"
        case .off:
            "bolt.slash.fill"
        }
    }

    var tint: Color {
        switch self {
        case .auto, .on:
            Color.wineSoftPeach
        case .off:
            .white
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .auto:
            "Flash auto"
        case .on:
            "Flash on"
        case .off:
            "Flash off"
        }
    }

    var captureFlashMode: AVCaptureDevice.FlashMode {
        switch self {
        case .auto:
            .auto
        case .on:
            .on
        case .off:
            .off
        }
    }

    func next(availableModes: [AVCaptureDevice.FlashMode]) -> WineListFlashMode {
        let preferredOrder: [WineListFlashMode] = [.auto, .on, .off]
        let supportedModes = preferredOrder.filter { availableModes.contains($0.captureFlashMode) }
        guard supportedModes.isEmpty == false,
              let currentIndex = supportedModes.firstIndex(of: self) else {
            return supportedModes.first ?? .off
        }

        let nextIndex = supportedModes.index(after: currentIndex)
        return nextIndex == supportedModes.endIndex ? supportedModes[0] : supportedModes[nextIndex]
    }
}

@MainActor
@Observable
private final class WineListCameraModel {
    let session = AVCaptureSession()
    var capturedPages: [CapturedWineListPage] = []
    var isFlashAvailable = false
    var flashMode: WineListFlashMode = .auto
    var isCapturing = false
    var authorizationStatus: WineListCameraAuthorizationStatus = .unknown

    private let photoOutput = AVCapturePhotoOutput()
    private var captureDelegates: [Int64: PhotoCaptureDelegate] = [:]
    private var isSessionConfigured = false
    private let isPreviewingCapturedPages: Bool

    init(previewCapturedImages: [UIImage] = []) {
        capturedPages = previewCapturedImages.map { CapturedWineListPage(image: $0) }
        isPreviewingCapturedPages = previewCapturedImages.isEmpty == false
        if isPreviewingCapturedPages {
            authorizationStatus = .ready
            isFlashAvailable = true
        }
    }

    var canAnalyze: Bool {
        capturedPages.isEmpty == false
    }

    var canCapture: Bool {
        authorizationStatus == .ready && isCapturing == false && hasReachedPageLimit == false
    }

    var hasReachedPageLimit: Bool {
        capturedPages.count >= wineListCameraPageLimit
    }

    func start() async {
        guard isPreviewingCapturedPages == false else { return }

        guard await requestAccess() else {
            authorizationStatus = .unavailable
            return
        }

        do {
            try configureSessionIfNeeded()
            authorizationStatus = .ready
            if session.isRunning == false {
                session.startRunning()
            }
        } catch {
            authorizationStatus = .unavailable
        }
    }

    func stop() {
        if session.isRunning {
            session.stopRunning()
        }
    }

    func cycleFlashMode() {
        flashMode = flashMode.next(availableModes: photoOutput.supportedFlashModes)
    }

    func deletePage(id: UUID) {
        capturedPages.removeAll { $0.id == id }
    }

    func capturePage() {
        guard canCapture else { return }
        isCapturing = true

        let settings = AVCapturePhotoSettings()
        if photoOutput.supportedFlashModes.contains(flashMode.captureFlashMode) {
            settings.flashMode = flashMode.captureFlashMode
        }

        let delegate = PhotoCaptureDelegate { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                defer { self.isCapturing = false }

                self.captureDelegates[settings.uniqueID] = nil

                guard case .success(let data) = result,
                      let image = UIImage(data: data),
                      self.capturedPages.count < wineListCameraPageLimit else {
                    return
                }

                self.capturedPages.append(CapturedWineListPage(image: image))
            }
        }

        captureDelegates[settings.uniqueID] = delegate
        photoOutput.capturePhoto(with: settings, delegate: delegate)
    }

    private func requestAccess() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video)
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }

    private func configureSessionIfNeeded() throws {
        guard isSessionConfigured == false else { return }

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            throw WineAnalysisServiceError.invalidInput
        }

        let input = try AVCaptureDeviceInput(device: device)

        session.beginConfiguration()
        session.sessionPreset = .photo

        if session.canAddInput(input) {
            session.addInput(input)
        } else {
            session.commitConfiguration()
            throw WineAnalysisServiceError.invalidInput
        }

        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        } else {
            session.commitConfiguration()
            throw WineAnalysisServiceError.invalidInput
        }

        photoOutput.maxPhotoQualityPrioritization = .speed
        session.commitConfiguration()

        isFlashAvailable = device.hasFlash && photoOutput.supportedFlashModes.isEmpty == false
        if photoOutput.supportedFlashModes.contains(flashMode.captureFlashMode) == false {
            flashMode = WineListFlashMode.off.next(availableModes: photoOutput.supportedFlashModes)
        }
        isSessionConfigured = true
    }
}

private final class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    private let completion: (Result<Data, Error>) -> Void
    private var photoData: Data?

    init(completion: @escaping (Result<Data, Error>) -> Void) {
        self.completion = completion
    }

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        if let error {
            completion(.failure(error))
            return
        }

        photoData = photo.fileDataRepresentation()
    }

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings,
        error: Error?
    ) {
        if let error {
            completion(.failure(error))
            return
        }

        guard let photoData else {
            completion(.failure(WineAnalysisServiceError.invalidInput))
            return
        }

        completion(.success(photoData))
    }
}

#Preview("No photos") {
    WineListCameraView(
        previewBackgroundImage: WineListCameraPreviewImages.cameraBackground,
        onAnalyze: { _ in },
        onUnavailable: {}
    )
}

#Preview("Two photos captured") {
    WineListCameraView(
        previewCapturedImages: WineListCameraPreviewImages.twoPages,
        previewBackgroundImage: WineListCameraPreviewImages.cameraBackground,
        onAnalyze: { _ in },
        onUnavailable: {}
    )
}

private enum WineListCameraPreviewImages {
    static var cameraBackground: UIImage? {
        UIImage(contentsOfFile: "/Users/dan/Downloads/PXL_20260509_001111784.jpg")
    }

    static var twoPages: [UIImage] {
        [
            samplePage(title: "By the Glass", tint: UIColor(red: 0.98, green: 0.77, blue: 0.63, alpha: 1)),
            samplePage(title: "Reds", tint: UIColor(red: 0.45, green: 0.07, blue: 0.09, alpha: 1)),
        ]
    }

    private static func samplePage(title: String, tint: UIColor) -> UIImage {
        let size = CGSize(width: 420, height: 560)
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { context in
            UIColor(red: 0.98, green: 0.96, blue: 0.91, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: size))

            tint.withAlphaComponent(0.18).setFill()
            context.fill(CGRect(x: 0, y: 0, width: size.width, height: 88))

            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 32, weight: .semibold),
                .foregroundColor: UIColor(red: 0.18, green: 0.11, blue: 0.09, alpha: 1),
            ]
            title.draw(at: CGPoint(x: 34, y: 26), withAttributes: titleAttributes)

            let lineColor = UIColor(red: 0.28, green: 0.22, blue: 0.18, alpha: 0.5)
            lineColor.setStroke()

            for index in 0..<9 {
                let y = 128 + CGFloat(index * 42)
                let path = UIBezierPath()
                path.move(to: CGPoint(x: 34, y: y))
                path.addLine(to: CGPoint(x: size.width - 34, y: y))
                path.lineWidth = index.isMultiple(of: 3) ? 3 : 2
                path.stroke()
            }

            tint.withAlphaComponent(0.55).setFill()
            context.cgContext.fillEllipse(in: CGRect(x: size.width - 76, y: 24, width: 34, height: 34))
        }
    }
}
