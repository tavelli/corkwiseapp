import PhotosUI
import SwiftData
import SwiftUI

struct MainView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @Query(sort: \WineScan.createdAt, order: .reverse) private var recentScans: [WineScan]
    @State private var viewModel = MainViewModel()
    @State private var isShowingCamera = false
    @State private var isShowingPhotoPicker = false
    @State private var selectedPhotoItem: PhotosPickerItem?

    let preferences: UserWinePreferences?

    var body: some View {
        @Bindable var bindableViewModel = viewModel

        ScrollView {
            VStack(alignment: .leading) {
                Text("CorkWise")
                    .font(.largeTitle)
                    .bold()

                Text("Your personal wine list advisor.")
                    .font(.title3)
                    .foregroundStyle(.secondary)

                Picker("Purchase mode", selection: $bindableViewModel.purchaseMode) {
                    ForEach(PurchaseMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                if let selectedPreviewImage = viewModel.selectedPreviewImage {
                    Image(uiImage: selectedPreviewImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .clipShape(.rect(cornerRadius: 24))
                }

                VStack(alignment: .leading) {
                    Button("Scan Wine List", systemImage: "camera.viewfinder") {
                        openCamera()
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Upload Photo", systemImage: "photo.on.rectangle") {
                        isShowingPhotoPicker = true
                    }
                    .buttonStyle(.bordered)
                }

                RecentScansView(scans: recentScans, openScan: openScan)
            }
            .padding()
        }
        .navigationTitle("Advisor")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if viewModel.isScanning {
                ScanLoadingView(message: viewModel.loadingMessage)
            }
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
            appState.showResults(result)
        }
    }

    private func retryLastScan() {
        guard let preferences else { return }

        viewModel.retryLastScan(preferences: preferences, modelContext: modelContext) { result in
            appState.showResults(result)
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
        appState.showResults(result)
    }
}

#Preview {
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: UserWinePreferences.self, WineScan.self, configurations: configuration)
    let context = ModelContext(container)
    context.insert(
        UserWinePreferences(
            experienceLevel: ExperienceLevel.casual.rawValue,
            preferredStyles: [WineStylePreference.crispRefreshing.rawValue],
            choiceStyle: ChoiceStyle.bestValue.rawValue,
            hasCompletedOnboarding: true
        )
    )

    return MainView(preferences: nil)
        .environment(AppState())
        .modelContainer(container)
}
