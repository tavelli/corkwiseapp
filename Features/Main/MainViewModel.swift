import Foundation
import Observation
import SwiftData
import UIKit

struct ScanFailureState: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let message: String
}

@MainActor
@Observable
final class MainViewModel {
    private static let lastScanCategoryPreferenceKey = "lastScanCategoryPreference"

    var purchaseMode: PurchaseMode = .bottle
    var bottleContext: BottleContext = .forMe
    var categoryPreference: WineCategoryPreference = .anything
    var isScanning = false
    var loadingMessage = "Reading the wine list…"
    var failure: ScanFailureState?
    var selectedPreviewImage: UIImage?
    var canRetryLastScan: Bool {
        pendingAttachment != nil
    }

    private let analysisService = WineAnalysisService()
    private let imagePreparationService = ImagePreparationService()
    private var loadingTask: Task<Void, Never>?
    private var scanTask: Task<Void, Never>?
    private var pendingAttachment: AnalyzeWineMenuAttachment?
    private var hasConfiguredInitialCategoryPreference = false

    func configureInitialCategoryPreference(
        preferences: UserWinePreferences?,
        latestScan: WineScan?
    ) {
        guard hasConfiguredInitialCategoryPreference == false else { return }
        hasConfiguredInitialCategoryPreference = true

        if let storedPreference = UserDefaults.standard.string(forKey: Self.lastScanCategoryPreferenceKey),
           let categoryPreference = WineCategoryPreference(rawValue: storedPreference) {
            self.categoryPreference = categoryPreference
            return
        }

        if let latestScan, latestScan.categoryPreference != nil {
            categoryPreference = latestScan.categoryPreferenceValue
            return
        }

        categoryPreference = WineCategoryPreference.defaultPreference(
            for: preferences?.favoriteVarietalValues ?? []
        )
    }

    func startScan(
        image: UIImage,
        preferences: UserWinePreferences,
        modelContext: ModelContext,
        onResult: @escaping (WineScanResult) -> Void
    ) {
        do {
            let attachment = try imagePreparationService.prepareAttachment(for: image)
            selectedPreviewImage = image
            startScan(
                attachment: attachment,
                preferences: preferences,
                modelContext: modelContext,
                onResult: onResult
            )
        } catch {
            failure = failureState(for: error)
        }
    }

    func startScan(
        attachment: AnalyzeWineMenuAttachment,
        preferences: UserWinePreferences,
        modelContext: ModelContext,
        onResult: @escaping (WineScanResult) -> Void
    ) {
        scanTask?.cancel()
        scanTask = Task {
            do {
                pendingAttachment = attachment
                isScanning = true
                startLoadingMessages()

                let result = try await analysisService.analyzeMenu(
                    attachment: attachment,
                    purchaseMode: purchaseMode,
                    bottleContext: effectiveBottleContext,
                    categoryPreference: categoryPreference,
                    preferences: preferences
                )

                guard Task.isCancelled == false else { return }
                try save(result: result, modelContext: modelContext)
                guard Task.isCancelled == false else { return }
                finishScan()
                onResult(result)
            } catch {
                guard Task.isCancelled == false else {
                    finishScan()
                    return
                }
                finishScan()
                failure = failureState(for: error)
            }
        }
    }

    func startScan(
        menuURL: URL,
        preferences: UserWinePreferences,
        modelContext: ModelContext,
        onResult: @escaping (WineScanResult) -> Void
    ) {
        scanTask?.cancel()
        scanTask = Task {
            do {
                pendingAttachment = nil
                isScanning = true
                startLoadingMessages()

                let result = try await analysisService.analyzeMenu(
                    menuURL: menuURL,
                    purchaseMode: purchaseMode,
                    bottleContext: effectiveBottleContext,
                    categoryPreference: categoryPreference,
                    preferences: preferences
                )

                guard Task.isCancelled == false else { return }
                try save(result: result, modelContext: modelContext)
                guard Task.isCancelled == false else { return }
                finishScan()
                onResult(result)
            } catch {
                guard Task.isCancelled == false else {
                    finishScan()
                    return
                }
                finishScan()
                failure = failureState(for: error)
            }
        }
    }

    func retryLastScan(
        preferences: UserWinePreferences,
        modelContext: ModelContext,
        onResult: @escaping (WineScanResult) -> Void
    ) {
        guard let pendingAttachment else { return }
        clearFailure()
        startScan(
            attachment: pendingAttachment,
            preferences: preferences,
            modelContext: modelContext,
            onResult: onResult
        )
    }

    func clearFailure() {
        failure = nil
    }

    func cancelScan() {
        scanTask?.cancel()
        scanTask = nil
        finishScan()
    }

    private func save(result: WineScanResult, modelContext: ModelContext) throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(result)
        guard let json = String(data: data, encoding: .utf8) else {
            throw CocoaError(.coderInvalidValue)
        }

        let scan = WineScan(
            createdAt: .now,
            restaurantName: result.restaurantName,
            purchaseMode: purchaseMode.rawValue,
            bottleContext: purchaseMode == .bottle ? bottleContext.rawValue : nil,
            categoryPreference: categoryPreference.rawValue,
            summaryHeadline: result.summary.headline,
            resultJSON: json
        )

        modelContext.insert(scan)
        try modelContext.save()
        UserDefaults.standard.set(
            categoryPreference.rawValue,
            forKey: Self.lastScanCategoryPreferenceKey
        )
    }

    private func startLoadingMessages() {
        loadingTask?.cancel()
        loadingMessage = "Reading the wine list…"

        loadingTask = Task { @MainActor in
            let messages = [
                "Estimating value…",
                "Comparing producer quality…",
                "Ranking the best picks…",
            ]

            for message in messages {
                try? await Task.sleep(for: .seconds(0.9))
                guard Task.isCancelled == false else { return }
                loadingMessage = message
            }
        }
    }

    private func finishScan() {
        loadingTask?.cancel()
        loadingTask = nil
        scanTask = nil
        isScanning = false
        loadingMessage = "Reading the wine list…"
    }

    private func failureState(for error: Error) -> ScanFailureState {
        if let serviceError = error as? WineAnalysisServiceError {
            switch serviceError {
            case .backendNotConfigured:
                return ScanFailureState(
                    title: "Backend not configured.",
                    message: "Add the Supabase base URL to the app configuration before running live scans."
                )
            case .invalidInput:
                return ScanFailureState(
                    title: "Couldn't prepare that file.",
                    message: "Try another image or PDF with a readable wine list."
                )
            case .serverError(let response):
                return ScanFailureState(
                    title: title(for: response.error),
                    message: response.message
                )
            case .invalidResponse(let responseBody):
                let details = responseBody?.isEmpty == false
                    ? responseBody!
                    : "The wine analysis service returned data the app couldn't read."
                return ScanFailureState(
                    title: "Unexpected response from the server.",
                    message: details
                )
            case .requestFailed:
                return ScanFailureState(
                    title: "Network request failed.",
                    message: "Check your connection and try the scan again."
                )
            }
        }

        return ScanFailureState(
            title: "Couldn't read enough of the wine list.",
            message: "Try taking the photo again in better light, or upload a clearer image."
        )
    }

    private func title(for errorCode: String) -> String {
        switch errorCode {
        case "menu_unreadable":
            return "Couldn't read enough of the wine list."
        case "no_wines_detected":
            return "No wines detected."
        case "image_too_large":
            return "Image too large."
        case "invalid_request":
            return "Invalid scan request."
        case "analysis_failed":
            return "Analysis failed."
        default:
            return "Scan failed."
        }
    }

    private var effectiveBottleContext: BottleContext? {
        purchaseMode == .bottle ? bottleContext : nil
    }
}
