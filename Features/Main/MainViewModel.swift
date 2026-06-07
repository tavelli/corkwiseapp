import Foundation
import Observation
import SwiftData
import UIKit

struct ScanFailureState: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let message: String
    let recoveryAction: ScanFailureRecoveryAction

    init(
        title: String,
        message: String,
        recoveryAction: ScanFailureRecoveryAction = .dismiss
    ) {
        self.title = title
        self.message = message
        self.recoveryAction = recoveryAction
    }

    var buttonTitle: String {
        switch recoveryAction {
        case .retrySameScan:
            String(localized: "scanFailure.action.retry")
        case .dismiss:
            String(localized: "scanFailure.action.tryNewList")
        }
    }
}

enum ScanFailureRecoveryAction: Hashable {
    case retrySameScan
    case dismiss
}

@MainActor
@Observable
final class MainViewModel {
    private static let lastScanCategoryPreferenceKey = "lastScanCategoryPreference"
    private static let lastScanPurchaseModeKey = "lastScanPurchaseMode"

    var purchaseMode: PurchaseMode = .bottle
    var bottleContext: BottleContext = .forMe
    var categoryPreference: WineCategoryPreference = .anything
    var isScanning = false
    var loadingMessage = String(localized: .mainViewModelLoadingReadingWineList)
    var failure: ScanFailureState?
    var selectedPreviewImage: UIImage?
    private var canRetryLastScan: Bool {
        pendingAttachments?.isEmpty == false
    }

    private let analysisService = WineAnalysisService()
    private let imagePreparationService = ImagePreparationService()
    private var loadingTask: Task<Void, Never>?
    private var scanTask: Task<Void, Never>?
    private var pendingAttachments: [AnalyzeWineMenuAttachment]?
    private var hasConfiguredInitialCategoryPreference = false
    private var hasConfiguredInitialPurchaseMode = false

    func configureInitialPurchaseMode(
        preferences: UserWinePreferences?,
        latestScan: WineScan?
    ) {
        guard hasConfiguredInitialPurchaseMode == false else { return }
        hasConfiguredInitialPurchaseMode = true

        if let storedPurchaseMode = UserDefaults.standard.string(forKey: Self.lastScanPurchaseModeKey),
           let purchaseMode = PurchaseMode(rawValue: storedPurchaseMode) {
            self.purchaseMode = purchaseMode
            return
        }

        if let latestScan {
            purchaseMode = latestScan.purchaseModeValue
            return
        }

        if let preferredPurchaseMode = preferences?.usualPurchasePreferenceValue.defaultPurchaseMode {
            purchaseMode = preferredPurchaseMode
        }
    }

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
        onEntitlementRequired: @escaping () -> Void = {},
        onResult: @escaping (WineScanResult) -> Void
    ) {
        startScan(
            images: [image],
            preferences: preferences,
            modelContext: modelContext,
            onEntitlementRequired: onEntitlementRequired,
            onResult: onResult
        )
    }

    func startScan(
        images: [UIImage],
        preferences: UserWinePreferences,
        modelContext: ModelContext,
        onEntitlementRequired: @escaping () -> Void = {},
        onResult: @escaping (WineScanResult) -> Void
    ) {
        do {
            let attachments = try imagePreparationService.prepareAttachments(for: images)
            selectedPreviewImage = images.first
            startScan(
                attachments: attachments,
                preferences: preferences,
                modelContext: modelContext,
                onEntitlementRequired: onEntitlementRequired,
                onResult: onResult
            )
        } catch {
            AnalyticsService.shared.trackScanFailed(
                inputType: images.count > 1 ? .images : .image,
                attachmentCount: images.count,
                purchaseMode: purchaseMode,
                categoryPreference: categoryPreference,
                error: error
            )
            failure = failureState(for: error)
        }
    }

    func startScan(
        attachments: [AnalyzeWineMenuAttachment],
        preferences: UserWinePreferences,
        modelContext: ModelContext,
        onEntitlementRequired: @escaping () -> Void = {},
        onResult: @escaping (WineScanResult) -> Void
    ) {
        scanTask?.cancel()
        scanTask = Task {
            do {
                pendingAttachments = attachments
                isScanning = true
                startLoadingMessages()
                let inputType = Self.scanInputType(for: attachments)
                AnalyticsService.shared.trackScanStarted(
                    inputType: inputType,
                    attachmentCount: attachments.count,
                    purchaseMode: purchaseMode,
                    categoryPreference: categoryPreference
                )

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
                AnalyticsService.shared.trackScanCompleted(
                    inputType: inputType,
                    attachmentCount: attachments.count,
                    purchaseMode: purchaseMode,
                    categoryPreference: categoryPreference
                )
                finishScan()
                onResult(result)
            } catch {
                guard Task.isCancelled == false else {
                    finishScan()
                    return
                }
                finishScan()
                if error.isEntitlementRequired {
                    AnalyticsService.shared.trackScanFailed(
                        inputType: Self.scanInputType(for: attachments),
                        attachmentCount: attachments.count,
                        purchaseMode: purchaseMode,
                        categoryPreference: categoryPreference,
                        error: error
                    )
                    onEntitlementRequired()
                    return
                }
                AnalyticsService.shared.trackScanFailed(
                    inputType: Self.scanInputType(for: attachments),
                    attachmentCount: attachments.count,
                    purchaseMode: purchaseMode,
                    categoryPreference: categoryPreference,
                    error: error
                )
                failure = failureState(for: error)
            }
        }
    }

    func startScan(
        menuURL: URL,
        preferences: UserWinePreferences,
        modelContext: ModelContext,
        onEntitlementRequired: @escaping () -> Void = {},
        onResult: @escaping (WineScanResult) -> Void
    ) {
        scanTask?.cancel()
        scanTask = Task {
            do {
                pendingAttachments = nil
                isScanning = true
                startLoadingMessages()
                AnalyticsService.shared.trackScanStarted(
                    inputType: .menuURL,
                    purchaseMode: purchaseMode,
                    categoryPreference: categoryPreference
                )

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
                AnalyticsService.shared.trackScanCompleted(
                    inputType: .menuURL,
                    purchaseMode: purchaseMode,
                    categoryPreference: categoryPreference
                )
                finishScan()
                onResult(result)
            } catch {
                guard Task.isCancelled == false else {
                    finishScan()
                    return
                }
                finishScan()
                if error.isEntitlementRequired {
                    AnalyticsService.shared.trackScanFailed(
                        inputType: .menuURL,
                        purchaseMode: purchaseMode,
                        categoryPreference: categoryPreference,
                        error: error
                    )
                    onEntitlementRequired()
                    return
                }
                AnalyticsService.shared.trackScanFailed(
                    inputType: .menuURL,
                    purchaseMode: purchaseMode,
                    categoryPreference: categoryPreference,
                    error: error
                )
                failure = failureState(for: error)
            }
        }
    }

    func retryLastScan(
        preferences: UserWinePreferences,
        modelContext: ModelContext,
        onEntitlementRequired: @escaping () -> Void = {},
        onResult: @escaping (WineScanResult) -> Void
    ) {
        guard let pendingAttachments else { return }
        clearFailure()
        startScan(
            attachments: pendingAttachments,
            preferences: preferences,
            modelContext: modelContext,
            onEntitlementRequired: onEntitlementRequired,
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
            analysisId: result.analysisId,
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
            purchaseMode.rawValue,
            forKey: Self.lastScanPurchaseModeKey
        )
        UserDefaults.standard.set(
            categoryPreference.rawValue,
            forKey: Self.lastScanCategoryPreferenceKey
        )
    }

    private func startLoadingMessages() {
        loadingTask?.cancel()
        loadingMessage = String(localized: .mainViewModelLoadingReadingWineList)

        loadingTask = Task { @MainActor in
            let messages = [
                String(localized: .mainViewModelLoadingEstimatingValue),
                String(localized: .mainViewModelLoadingComparingProducerQuality),
                String(localized: .mainViewModelLoadingRankingBestPicks),
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
        loadingMessage = String(localized: .mainViewModelLoadingReadingWineList)
    }

    private func failureState(for error: Error) -> ScanFailureState {
        if let serviceError = error as? WineAnalysisServiceError {
            switch serviceError {
            case .backendNotConfigured:
                return ScanFailureState(
                    title: String(localized: .mainViewModelFailureBackendNotConfiguredTitle),
                    message: String(localized: .mainViewModelFailureBackendNotConfiguredMessage),
                    recoveryAction: .dismiss
                )
            case .authorizationFailed:
                return ScanFailureState(
                    title: String(localized: .mainViewModelFailureAuthorizationTitle),
                    message: String(localized: .mainViewModelFailureAuthorizationMessage),
                    recoveryAction: .dismiss
                )
            case .entitlementRequired(let response):
                return ScanFailureState(
                    title: String(localized: .mainViewModelFailureSubscriptionRequiredTitle),
                    message: response.message,
                    recoveryAction: .dismiss
                )
            case .invalidInput:
                return ScanFailureState(
                    title: String(localized: .mainViewModelFailureInvalidInputTitle),
                    message: String(localized: .mainViewModelFailureInvalidInputMessage),
                    recoveryAction: .dismiss
                )
            case .serverError(let response):
                return ScanFailureState(
                    title: title(for: response.error),
                    message: response.message,
                    recoveryAction: response.retrySuggested && canRetryLastScan ? .retrySameScan : .dismiss
                )
            case .invalidResponse(let responseBody):
                let details = responseBody?.isEmpty == false
                    ? responseBody!
                    : String(localized: .mainViewModelFailureInvalidResponseFallbackMessage)
                return ScanFailureState(
                    title: String(localized: .mainViewModelFailureInvalidResponseTitle),
                    message: details,
                    recoveryAction: canRetryLastScan ? .retrySameScan : .dismiss
                )
            case .requestFailed:
                return ScanFailureState(
                    title: String(localized: .mainViewModelFailureRequestFailedTitle),
                    message: String(localized: .mainViewModelFailureRequestFailedMessage),
                    recoveryAction: canRetryLastScan ? .retrySameScan : .dismiss
                )
            }
        }

        return ScanFailureState(
            title: String(localized: .mainViewModelFailureUnreadableTitle),
            message: String(localized: .mainViewModelFailureUnreadableMessage),
            recoveryAction: .dismiss
        )
    }

    private func title(for errorCode: String) -> String {
        switch errorCode {
        case "menu_unreadable":
            return String(localized: .mainViewModelFailureUnreadableTitle)
        case "no_wines_detected":
            return String(localized: .mainViewModelFailureNoWinesDetectedTitle)
        case "image_too_large":
            if pendingAttachments?.contains(where: { $0.mimeType == "application/pdf" }) == true {
                return String(localized: .mainViewModelFailureFileTooLargeTitle)
            }
            return String(localized: .mainViewModelFailureImageTooLargeTitle)
        case "invalid_request":
            return String(localized: .mainViewModelFailureInvalidRequestTitle)
        case "analysis_failed":
            return String(localized: .mainViewModelFailureAnalysisFailedTitle)
        case "entitlement_required":
            return String(localized: .mainViewModelFailureSubscriptionRequiredTitle)
        default:
            return String(localized: .mainViewModelFailureScanFailedTitle)
        }
    }

    private var effectiveBottleContext: BottleContext? {
        purchaseMode == .bottle ? bottleContext : nil
    }

    private static func scanInputType(for attachments: [AnalyzeWineMenuAttachment]) -> AnalyticsService.ScanInputType {
        if attachments.contains(where: { $0.mimeType == "application/pdf" }) {
            return .pdf
        }

        return attachments.count > 1 ? .images : .image
    }
}

private extension Error {
    var isEntitlementRequired: Bool {
        guard let serviceError = self as? WineAnalysisServiceError else {
            return false
        }

        if case .entitlementRequired = serviceError {
            return true
        }

        return false
    }
}
