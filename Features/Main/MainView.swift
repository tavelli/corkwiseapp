import PhotosUI
import SwiftData
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct MainView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @Query(sort: \WineScan.createdAt, order: .reverse) private var recentScans: [WineScan]
    @State private var viewModel = MainViewModel()
    @State private var isShowingCamera = false
    @State private var isShowingPhotoPicker = false
    @State private var isShowingFileImporter = false
    @State private var isShowingUploadOptions = false
    @State private var isShowingURLImporter = false
    @State private var menuURLText = ""
    @State private var selectedPhotoItem: PhotosPickerItem?

    let preferences: UserWinePreferences?

    var body: some View {
        @Bindable var bindableViewModel = viewModel

        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                actionPanel

                if recentScans.isEmpty == false {
                    RecentScansView(
                        scans: recentScans,
                        openScan: openScan,
                        showAllScans: appState.showAllScans
                    )
                    .padding(.horizontal, 20)
                }
            }
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .background(mainScreenBackground.ignoresSafeArea())
        .safeAreaInset(edge: .top, spacing: 0) {
            header
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 12)
                .background {
                    Rectangle()
                        .fill(Color.wineCanvasTop)
                        .ignoresSafeArea(edges: .top)
                }
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(Color.wineBorder.opacity(0.4))
                        .frame(height: 1)
                }
        }
        .navigationBarBackButtonHidden()
        .overlay {
            if viewModel.isScanning {
                ScanLoadingView(message: viewModel.loadingMessage)
            }
        }
        .confirmationDialog("Upload Wine List", isPresented: $isShowingUploadOptions, titleVisibility: .visible) {
            Button("Photo Library") {
                isShowingPhotoPicker = true
            }

            Button("Browse Files") {
                isShowingFileImporter = true
            }

            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Choose a photo from your library or browse image and PDF files.")
        }
        .sheet(item: $bindableViewModel.failure) { failure in
            ScanFailureView(
                title: failure.title,
                message: failure.message,
                canRetry: viewModel.canRetryLastScan,
                retryAction: {
                    retryLastScan()
                },
                uploadAction: {
                    viewModel.clearFailure()
                    isShowingUploadOptions = true
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
        .sheet(isPresented: $isShowingURLImporter) {
            MenuURLImportSheet(urlText: $menuURLText) { menuURL in
                processMenuURL(menuURL)
            }
            .presentationDetents([.height(300)])
            .presentationDragIndicator(.visible)
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
        .fileImporter(
            isPresented: $isShowingFileImporter,
            allowedContentTypes: [.image, .pdf],
            allowsMultipleSelection: false
        ) { result in
            handleImportedFile(result)
        }
        .task(id: preferences?.usualPurchasePreference) {
            guard let preferredPurchaseMode = preferences?.usualPurchasePreferenceValue.defaultPurchaseMode else {
                return
            }

            viewModel.purchaseMode = preferredPurchaseMode
        }
        .task(id: categoryPreferenceSeedID) {
            guard preferences != nil || recentScans.isEmpty == false else {
                return
            }

            viewModel.configureInitialCategoryPreference(
                preferences: preferences,
                latestScan: recentScans.first
            )
        }
    }

    private var categoryPreferenceSeedID: String {
        [
            preferences?.favoriteVarietals?.joined(separator: ",") ?? "",
            recentScans.first?.categoryPreference ?? "",
            recentScans.first?.createdAt.ISO8601Format() ?? "",
        ].joined(separator: "|")
    }

    private func processSelectedImage(_ image: UIImage) {
        guard let preferences else { return }

        viewModel.startScan(image: image, preferences: preferences, modelContext: modelContext) { result in
            appState.showResults(result, purchaseMode: viewModel.purchaseMode, viewedAt: .now)
        }
    }

    private func processMenuURL(_ menuURL: URL) {
        guard let preferences else { return }

        viewModel.startScan(menuURL: menuURL, preferences: preferences, modelContext: modelContext) { result in
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

    private func handleImportedFile(_ result: Result<[URL], Error>) {
        do {
            guard let fileURL = try result.get().first else {
                return
            }

            guard let preferences else { return }

            let attachment = try ImagePreparationService().prepareAttachment(from: fileURL)
            viewModel.startScan(attachment: attachment, preferences: preferences, modelContext: modelContext) { result in
                appState.showResults(result, purchaseMode: viewModel.purchaseMode, viewedAt: .now)
            }
        } catch {
            viewModel.failure = ScanFailureState(
                title: "Couldn't import that file.",
                message: "Choose a photo or a PDF with a readable wine list and try again."
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
            Image("headerlogo3")
                .resizable()
                .scaledToFit()
                .frame(height: 46)

            Spacer()

            Button(action: appState.showPreferences) {
                Image(systemName: "person.crop.circle")
                    .font(.system(size: 30, weight: .regular))
                    .foregroundStyle(Color.wineText.opacity(0.78))
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
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color.wineCardBackground)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.wineBorder.opacity(0.9))
                .frame(height: 1)
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.wineBorder.opacity(0.9))
                .frame(height: 1)
        }
    }

    private var controlPanel: some View {
        VStack(spacing: 14) {
            slidingSegmentedControl(
                items: PurchaseMode.allCases,
                selection: Binding(
                    get: { viewModel.purchaseMode },
                    set: { viewModel.purchaseMode = $0 }
                ),
                title: \.title
            ) { purchaseMode in
                if purchaseMode == .glass {
                    Image(systemName: "wineglass")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(width: 17, height: 20)
                } else {
                    Image("WineBottle")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 17, height: 20)
                }
            }

            categoryPreferenceChips(
                selection: Binding(
                    get: { viewModel.categoryPreference },
                    set: { viewModel.categoryPreference = $0 }
                )
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
        .padding(.top, 6)
        .padding(.bottom, 6)
    }

    private func categoryPreferenceChips(selection: Binding<WineCategoryPreference>) -> some View {
        HStack(spacing: 8) {
            ForEach(WineCategoryPreference.allCases) { category in
                let isSelected = selection.wrappedValue == category

                Button {
                    withAnimation(.spring(response: 0.24, dampingFraction: 0.86)) {
                        selection.wrappedValue = category
                    }
                } label: {
                    Text(category.title)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                        .foregroundStyle(isSelected ? Color.white : Color.wineText)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .padding(.horizontal, 6)
                        .background(isSelected ? Color.wineSelectionFill : Color.wineOptionBackground)
                        .clipShape(.capsule)
                        .overlay {
                            Capsule()
                                .stroke(
                                    isSelected ? Color.wineSelectionFill : Color.wineBorder.opacity(0.9),
                                    lineWidth: 1
                                )
                        }
                }
                .buttonStyle(.plain)
            }
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

                Text("Other ways to scan")
                    .font(.caption.weight(.semibold))
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
                    isShowingUploadOptions = true
                }

                optionButton(
                    title: "Paste URL",
                    subtitle: "Menu link",
                    systemImage: "link"
                ) {
                    isShowingURLImporter = true
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
            HStack(spacing: 14) {
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
            .padding(.horizontal, 14)
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

    private func slidingSegmentedControl<Item: Hashable, Icon: View>(
        items: [Item],
        selection: Binding<Item>,
        title: KeyPath<Item, String>,
        @ViewBuilder icon: @escaping (Item) -> Icon
    ) -> some View {
        HStack(spacing: 8) {
            ForEach(items, id: \.self) { item in
                let isSelected = selection.wrappedValue == item

                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                        selection.wrappedValue = item
                    }
                } label: {
                    HStack(spacing: 8) {
                        icon(item)

                        Text(item[keyPath: title].uppercased())
                            .font(.caption.weight(.bold))
                            .tracking(0.6)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                    .foregroundStyle(isSelected ? Color.white : Color.wineText)
                    .frame(maxWidth: .infinity)
                    .frame(height: 38)
                    .background(isSelected ? Color.wineSelectionFill : Color.wineOptionBackground)
                    .clipShape(.capsule)
                    .overlay {
                        Capsule()
                            .stroke(
                                isSelected ? Color.wineSelectionFill : Color.wineBorder.opacity(0.9),
                                lineWidth: 1
                            )
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct MenuURLImportSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var urlText: String
    @State private var validationMessage: String?
    @FocusState private var isURLFieldFocused: Bool

    let onAnalyze: (URL) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 7) {
                Text("Analyze from link")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.wineText)

                Text("Enter a link to the restaurant menu page.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Image(systemName: "link")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.wineAccent)
                        .frame(width: 20)

                    TextField("", text: $urlText)
                        .keyboardType(.URL)
                        .textContentType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .foregroundStyle(Color.wineText)
                        .tint(Color.wineAccent)
                        .focused($isURLFieldFocused)
                        .submitLabel(.go)
                        .onSubmit(submit)

                    if urlText.isEmpty == false {
                        Button {
                            urlText = ""
                            validationMessage = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(Color.secondary.opacity(0.55))
                                .frame(width: 34, height: 34)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Clear URL")
                    }
                }
                .padding(.horizontal, 14)
                .frame(height: 52)
                .background(Color.wineOptionBackground)
                .clipShape(.rect(cornerRadius: 14))
                .overlay {
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(validationMessage == nil ? Color.wineBorder : Color.red.opacity(0.65), lineWidth: 1)
                }

                if let validationMessage {
                    Text(validationMessage)
                        .font(.caption)
                        .foregroundStyle(Color.red)
                }
            }

            Button(action: submit) {
                Text("Analyze Menu")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(canSubmit ? Color.wineAccent : Color.wineAccent.opacity(0.38))
                    .clipShape(.rect(cornerRadius: 16))
            }
            .buttonStyle(.plain)
            .disabled(canSubmit == false)

            Button("Cancel", role: .cancel) {
                dismiss()
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color.wineText.opacity(0.72))
            .frame(maxWidth: .infinity)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 22)
        .padding(.top, 34)
        .padding(.bottom, 12)
        .background(Color.wineCardBackground.ignoresSafeArea())
        .onAppear {
            isURLFieldFocused = true
        }
    }

    private var canSubmit: Bool {
        Self.normalizedURL(from: urlText) != nil
    }

    private func submit() {
        guard let menuURL = Self.normalizedURL(from: urlText) else {
            validationMessage = "Enter a valid menu link."
            return
        }

        validationMessage = nil
        isURLFieldFocused = false
        dismiss()
        onAnalyze(menuURL)
    }

    static func normalizedURL(from text: String) -> URL? {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedText.isEmpty == false else { return nil }

        let candidateText: String
        let lowercasedText = trimmedText.lowercased()
        if lowercasedText.hasPrefix("http://") || lowercasedText.hasPrefix("https://") {
            candidateText = trimmedText
        } else {
            candidateText = "https://\(trimmedText)"
        }

        guard let url = URL(string: candidateText),
              let scheme = url.scheme?.lowercased(),
              (scheme == "http" || scheme == "https"),
              url.host?.isEmpty == false else {
            return nil
        }

        return url
    }
}

#Preview {
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: UserWinePreferences.self, WineScan.self, configurations: configuration)
    let context = ModelContext(container)
    let preferences = UserWinePreferences(
        preferredStyles: [WineStylePreference.crispRefreshing.rawValue],
        favoriteVarietals: [
            WineVarietal.prosecco.rawValue,
            WineVarietal.chardonnay.rawValue,
        ],
        choiceStyle: ChoiceStyle.bestValue.rawValue,
        usualPurchasePreference: UsualPurchasePreference.glass.rawValue,
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
            resultJSON: sampleJSON
        )
    )

    context.insert(
        WineScan(
            createdAt: .now.addingTimeInterval(-9_600),
            restaurantName: "Wine List",
            purchaseMode: PurchaseMode.glass.rawValue,
            summaryHeadline: sampleResult.summary.headline,
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
