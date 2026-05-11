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
        pendingAttachments?.isEmpty == false
    }

    private let analysisService = WineAnalysisService()
    private let imagePreparationService = ImagePreparationService()
    private var loadingTask: Task<Void, Never>?
    private var scanTask: Task<Void, Never>?
    private var pendingAttachments: [AnalyzeWineMenuAttachment]?
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
        startScan(
            images: [image],
            preferences: preferences,
            modelContext: modelContext,
            onResult: onResult
        )
    }

    func startScan(
        images: [UIImage],
        preferences: UserWinePreferences,
        modelContext: ModelContext,
        onResult: @escaping (WineScanResult) -> Void
    ) {
        do {
            let attachments = try imagePreparationService.prepareAttachments(for: images)
            selectedPreviewImage = images.first
            startScan(
                attachments: attachments,
                preferences: preferences,
                modelContext: modelContext,
                onResult: onResult
            )
        } catch {
            failure = failureState(for: error)
        }
    }

    func startScan(
        attachments: [AnalyzeWineMenuAttachment],
        preferences: UserWinePreferences,
        modelContext: ModelContext,
        onResult: @escaping (WineScanResult) -> Void
    ) {
        scanTask?.cancel()
        scanTask = Task {
            do {
                pendingAttachments = attachments
                isScanning = true
                startLoadingMessages()

                let result = try await analysisService.analyzeMenu(
                    attachments: attachments,
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
                pendingAttachments = nil
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
        guard let pendingAttachments else { return }
        clearFailure()
        startScan(
            attachments: pendingAttachments,
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
            case .authorizationFailed:
                return ScanFailureState(
                    title: "Couldn't verify app access.",
                    message: "Please try again in a moment."
                )
            case .entitlementRequired(let response):
                return ScanFailureState(
                    title: "Subscription required.",
                    message: response.message
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
        case "entitlement_required":
            return "Subscription required."
        default:
            return "Scan failed."
        }
    }

    private var effectiveBottleContext: BottleContext? {
        purchaseMode == .bottle ? bottleContext : nil
    }
}
