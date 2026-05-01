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
    var purchaseMode: PurchaseMode = .bottle
    var isScanning = false
    var loadingMessage = "Reading the wine list…"
    var failure: ScanFailureState?
    var selectedPreviewImage: UIImage?

    private let analysisService = WineAnalysisService()
    private let imagePreparationService = ImagePreparationService()
    private var loadingTask: Task<Void, Never>?
    private var pendingImage: UIImage?

    func startScan(
        image: UIImage,
        preferences: UserWinePreferences,
        modelContext: ModelContext,
        onResult: @escaping (WineScanResult) -> Void
    ) {
        Task {
            do {
                pendingImage = image
                selectedPreviewImage = image
                isScanning = true
                startLoadingMessages()

                let preparedImageData = try imagePreparationService.prepareForUpload(image)
                let result = try await analysisService.analyzeMenu(
                    imageData: preparedImageData,
                    purchaseMode: purchaseMode,
                    preferences: preferences
                )

                try save(result: result, modelContext: modelContext)
                finishScan()
                onResult(result)
            } catch {
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
        guard let pendingImage else { return }
        clearFailure()
        startScan(image: pendingImage, preferences: preferences, modelContext: modelContext, onResult: onResult)
    }

    func clearFailure() {
        failure = nil
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
            summaryHeadline: result.summary.headline,
            bestPickName: result.summary.bestPickName,
            bestPickScore: result.summary.bestPickScore,
            resultJSON: json
        )

        modelContext.insert(scan)
        try modelContext.save()
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
            case .invalidImage:
                return ScanFailureState(
                    title: "Couldn't prepare that image.",
                    message: "Try taking the photo again or upload a clearer image."
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
}
