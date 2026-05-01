import PhotosUI
import SwiftData
import SwiftUI

struct MainView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @Query(sort: \WineScan.createdAt, order: .reverse) private var recentScans: [WineScan]
    @Namespace private var segmentedControlNamespace
    @State private var viewModel = MainViewModel()
    @State private var isShowingCamera = false
    @State private var isShowingPhotoPicker = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isShowingPasteURLMessage = false

    let preferences: UserWinePreferences?

    var body: some View {
        @Bindable var bindableViewModel = viewModel

        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                header
                actionPanel
                RecentScansView(
                    scans: recentScans,
                    openScan: openScan,
                    showAllScans: appState.showAllScans
                )
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .background(mainScreenBackground.ignoresSafeArea())
        .navigationBarBackButtonHidden()
        .overlay {
            if viewModel.isScanning {
                ScanLoadingView(message: viewModel.loadingMessage)
            }
        }
        .alert("Paste URL Coming Soon", isPresented: $isShowingPasteURLMessage) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("URL import isn't wired up yet. Use Scan Wine List or Upload Photo for now.")
        }
        .sheet(item: $bindableViewModel.failure) { failure in
            ScanFailureView(
                title: failure.title,
                message: failure.message,
                retryAction: {
                    retryLastScan()
                },
                uploadAction: {
                    viewModel.clearFailure()
                    isShowingPhotoPicker = true
                }
            )
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $isShowingCamera) {
            CameraPicker { image in
                processSelectedImage(image)
            }
            .ignoresSafeArea()
        }
        .task(id: selectedPhotoItem) {
            guard let selectedPhotoItem else { return }

            do {
                guard let selectedPhoto = try await selectedPhotoItem.loadTransferable(type: SelectedPhoto.self) else {
                    return
                }
                processSelectedImage(selectedPhoto.image)
                self.selectedPhotoItem = nil
            } catch {
                viewModel.failure = ScanFailureState(
                    title: "Couldn't load that photo.",
                    message: "Try selecting a different image from your library."
                )
            }
        }
        .photosPicker(
            isPresented: $isShowingPhotoPicker,
            selection: $selectedPhotoItem,
            matching: .images,
            preferredItemEncoding: .current
        )
    }

    private func processSelectedImage(_ image: UIImage) {
        guard let preferences else { return }

        viewModel.startScan(image: image, preferences: preferences, modelContext: modelContext) { result in
            appState.showResults(result, purchaseMode: viewModel.purchaseMode, viewedAt: .now)
        }
    }

    private func retryLastScan() {
        guard let preferences else { return }

        viewModel.retryLastScan(preferences: preferences, modelContext: modelContext) { result in
            appState.showResults(result, purchaseMode: viewModel.purchaseMode, viewedAt: .now)
        }
    }

    private func openCamera() {
        if CameraPicker.isCameraAvailable {
            isShowingCamera = true
        } else {
            viewModel.failure = ScanFailureState(
                title: "Camera unavailable.",
                message: "This device doesn't currently expose a camera. Upload a photo instead."
            )
        }
    }

    private func openScan(_ scan: WineScan) {
        guard let data = scan.resultJSON.data(using: .utf8) else { return }
        let decoder = JSONDecoder()

        guard let result = try? decoder.decode(WineScanResult.self, from: data) else { return }
        appState.showResults(result, purchaseMode: scan.purchaseModeValue, viewedAt: scan.createdAt)
    }

    private var header: some View {
        HStack {
            Text("CorkWise")
                .font(.system(size: 25, weight: .bold, design: .serif))
                .foregroundStyle(Color.wineAccent)

            Spacer()

            Button(action: appState.showPreferences) {
                Image(systemName: "person.circle")
                    .font(.system(size: 34, weight: .regular))
                    .foregroundStyle(Color.black.opacity(0.88))
                    .frame(width: 42, height: 42)
            }
            .buttonStyle(.plain)
        }
    }

    private var actionPanel: some View {
        VStack(spacing: 18) {
            controlPanel
            heroScanCard
            sourceOptions
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 16)
        .background(Color.wineCardBackground)
        .clipShape(.rect(cornerRadius: 28))
        .overlay {
            RoundedRectangle(cornerRadius: 28)
                .stroke(Color.wineBorder.opacity(0.75), lineWidth: 1)
        }
        .shadow(color: Color(red: 0.35, green: 0.18, blue: 0.12).opacity(0.07), radius: 24, y: 10)
    }

    private var controlPanel: some View {
        VStack(spacing: 10) {
            slidingSegmentedControl(
                items: PurchaseMode.allCases,
                selection: Binding(
                    get: { viewModel.purchaseMode },
                    set: { viewModel.purchaseMode = $0 }
                ),
                title: \.title,
                icon: { $0 == .glass ? "wineglass" : "waterbottle" }
            )

//            if viewModel.purchaseMode == .bottle {
//                slidingSegmentedControl(
//                    items: BottleContext.allCases,
//                    selection: Binding(
//                        get: { viewModel.bottleContext },
//                        set: { viewModel.bottleContext = $0 }
//                    ),
//                    title: \.title,
//                    icon: { $0 == .forMe ? "person.fill" : "person.2.fill" }
//                )
//            }
        }
    }

    private var heroScanCard: some View {
        Button(action: openCamera) {
            ZStack {
                RoundedRectangle(cornerRadius: 30)
                    .fill(
                        LinearGradient(
                            colors: [Color.wineDeep, Color.wineAccent],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Circle()
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
                    .frame(width: 150, height: 150)

                Circle()
                    .stroke(Color.white.opacity(0.05), lineWidth: 1)
                    .frame(width: 118, height: 118)

                VStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.wineSoftPeach)
                        .frame(width: 74, height: 74)
                        .overlay {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 34))
                                .foregroundStyle(Color.wineAccent)
                        }

                    Text("SCAN WINE LIST")
                        .font(.system(size: 28, weight: .medium, design: .default))
                        .tracking(1.2)
                        .foregroundStyle(Color.wineSoftPeach)

                    Text("Tap to scan a wine list")
                        .font(.subheadline)
                        .foregroundStyle(Color.wineSoftPeach.opacity(0.74))
                }
            }
            .frame(height: 200)
        }
        .buttonStyle(.plain)
    }

    private var sourceOptions: some View {
        VStack(spacing: 16) {
            HStack(spacing: 14) {
                Rectangle()
                    .fill(Color.wineDivider)
                    .frame(height: 1)

                Text("OR CHOOSE AN OPTION")
                    .font(.caption.weight(.bold))
                    .tracking(1.2)
                    .foregroundStyle(.secondary)
                    .fixedSize()

                Rectangle()
                    .fill(Color.wineDivider)
                    .frame(height: 1)
            }

            HStack(spacing: 14) {
                optionButton(
                    title: "Upload",
                    subtitle: "PDF or photo",
                    systemImage: "square.and.arrow.up"
                ) {
                    isShowingPhotoPicker = true
                }

                optionButton(
                    title: "Paste URL",
                    subtitle: "Menu link",
                    systemImage: "link"
                ) {
                    isShowingPasteURLMessage = true
                }
            }
        }
    }

    private func optionButton(
        title: String,
        subtitle: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.wineAccent)
                    .frame(width: 16)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.wineText)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(Color.wineOptionBackground)
            .clipShape(.rect(cornerRadius: 18))
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color.wineBorder, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private func slidingSegmentedControl<Item: Hashable>(
        items: [Item],
        selection: Binding<Item>,
        title: KeyPath<Item, String>,
        icon: @escaping (Item) -> String
    ) -> some View {
        HStack(spacing: 8) {
            ForEach(items, id: \.self) { item in
                let isSelected = selection.wrappedValue == item

                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                        selection.wrappedValue = item
                    }
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: icon(item))
                            .font(.system(size: 15, weight: .semibold))

                        Text(item[keyPath: title].uppercased())
                            .font(.caption.weight(.bold))
                            .tracking(0.6)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                    .foregroundStyle(isSelected ? Color.white : Color.wineMutedText)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.wineAccent)
                                .matchedGeometryEffect(id: "segmentBackground", in: segmentedControlNamespace)
                        }
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(6)
        .background(Color.wineSegmentTrack)
        .clipShape(.rect(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.wineBorder.opacity(0.7), lineWidth: 1)
        }
    }
}

#Preview {
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: UserWinePreferences.self, WineScan.self, configurations: configuration)
    let context = ModelContext(container)
    let preferences = UserWinePreferences(
        experienceLevel: ExperienceLevel.casual.rawValue,
        preferredStyles: [WineStylePreference.crispRefreshing.rawValue],
        favoriteVarietals: [
            WineVarietal.prosecco.rawValue,
            WineVarietal.chardonnay.rawValue,
        ],
        choiceStyle: ChoiceStyle.bestValue.rawValue,
        hasCompletedOnboarding: true
    )
    context.insert(
        preferences
    )
    let sampleResult = WineScanResult.sample(for: .glass, preferences: preferences)
    let sampleData = try! JSONEncoder().encode(sampleResult)
    let sampleJSON = String(data: sampleData, encoding: .utf8)!

    context.insert(
        WineScan(
            createdAt: .now.addingTimeInterval(-4_800),
            restaurantName: "Max's",
            purchaseMode: PurchaseMode.glass.rawValue,
            summaryHeadline: sampleResult.summary.headline,
            bestPickName: "Roederer Estate Brut (Glass)",
            bestPickScore: 8.8,
            resultJSON: sampleJSON
        )
    )

    context.insert(
        WineScan(
            createdAt: .now.addingTimeInterval(-9_600),
            restaurantName: "Wine List",
            purchaseMode: PurchaseMode.glass.rawValue,
            summaryHeadline: sampleResult.summary.headline,
            bestPickName: "Cune Rioja Crianza (Glass)",
            bestPickScore: 8.2,
            resultJSON: sampleJSON
        )
    )
    try! context.save()

    return MainView(preferences: preferences)
        .environment(AppState())
        .modelContainer(container)
}

var mainScreenBackground: some View {
    LinearGradient(
        colors: [Color.wineCanvasTop, Color.wineCanvasBottom],
        startPoint: .top,
        endPoint: .bottom
    )
}
