import Foundation

enum WineAnalysisServiceError: Error {
    case backendNotConfigured
    case authorizationFailed
    case entitlementRequired(WineAnalysisErrorResponse)
    case invalidInput
    case invalidResponse(String?)
    case requestFailed
    case serverError(WineAnalysisErrorResponse)
}

struct WineAnalysisService {
    func analyzeMenu(
        attachment: AnalyzeWineMenuAttachment,
        purchaseMode: PurchaseMode,
        bottleContext: BottleContext?,
        categoryPreference: WineCategoryPreference,
        preferences: UserWinePreferences
    ) async throws -> WineScanResult {
        guard let endpoint = AppConfiguration.shared.analysisEndpoint else {
            throw WineAnalysisServiceError.backendNotConfigured
        }

        let appUserID = try appUserID()
        guard attachment.base64Data.isEmpty == false else {
            throw WineAnalysisServiceError.invalidInput
        }

        let requestBody = AnalyzeWineMenuRequest(
            appUserId: appUserID,
            buildConfiguration: BuildChannel.current,
            attachment: attachment,
            menuUrl: nil,
            purchaseMode: purchaseMode,
            bottleContext: purchaseMode == .bottle ? bottleContext : nil,
            categoryPreference: categoryPreference,
            userPreferences: preferences.payload
        )

        return try await send(requestBody, to: endpoint)
    }

    func analyzeMenu(
        menuURL: URL,
        purchaseMode: PurchaseMode,
        bottleContext: BottleContext?,
        categoryPreference: WineCategoryPreference,
        preferences: UserWinePreferences
    ) async throws -> WineScanResult {
        guard let endpoint = AppConfiguration.shared.analysisEndpoint else {
            throw WineAnalysisServiceError.backendNotConfigured
        }

        let appUserID = try appUserID()
        guard menuURL.scheme == "http" || menuURL.scheme == "https" else {
            throw WineAnalysisServiceError.invalidInput
        }

        let requestBody = AnalyzeWineMenuRequest(
            appUserId: appUserID,
            buildConfiguration: BuildChannel.current,
            attachment: nil,
            menuUrl: menuURL.absoluteString,
            purchaseMode: purchaseMode,
            bottleContext: purchaseMode == .bottle ? bottleContext : nil,
            categoryPreference: categoryPreference,
            userPreferences: preferences.payload
        )

        return try await send(requestBody, to: endpoint)
    }

    private func send(_ requestBody: AnalyzeWineMenuRequest, to endpoint: URL) async throws -> WineScanResult {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(try await accessToken())", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 45
        request.httpBody = try JSONEncoder().encode(requestBody)

        let responseData: Data
        let response: URLResponse

        do {
            (responseData, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw WineAnalysisServiceError.requestFailed
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw WineAnalysisServiceError.invalidResponse(nil)
        }

        #if DEBUG
        let responseText = String(data: responseData, encoding: .utf8) ?? "<non-utf8 response>"
        print("WineAnalysisService request URL: \(endpoint.absoluteString)")
        print("WineAnalysisService response status: \(httpResponse.statusCode)")
        print("WineAnalysisService response body: \(responseText)")
        #endif

        let decoder = JSONDecoder()

        if (200...299).contains(httpResponse.statusCode) {
            do {
                return try decoder.decode(WineScanResult.self, from: responseData)
            } catch {
                #if DEBUG
                print("WineAnalysisService failed to decode WineScanResult")
                #endif
                throw WineAnalysisServiceError.invalidResponse(String(data: responseData, encoding: .utf8))
            }
        }

        if httpResponse.statusCode == 401 {
            throw WineAnalysisServiceError.authorizationFailed
        }

        if let errorResponse = try? decoder.decode(WineAnalysisErrorResponse.self, from: responseData) {
            if errorResponse.error == "entitlement_required" {
                throw WineAnalysisServiceError.entitlementRequired(errorResponse)
            }

            throw WineAnalysisServiceError.serverError(errorResponse)
        }

        throw WineAnalysisServiceError.invalidResponse(String(data: responseData, encoding: .utf8))
    }

    private func appUserID() throws -> String {
        do {
            return try AppIdentityService.shared.appUserID()
        } catch {
            throw WineAnalysisServiceError.authorizationFailed
        }
    }

    private func accessToken() async throws -> String {
        do {
            return try await SupabaseAuthService.shared.accessToken()
        } catch SupabaseAuthServiceError.backendNotConfigured {
            throw WineAnalysisServiceError.backendNotConfigured
        } catch {
            throw WineAnalysisServiceError.authorizationFailed
        }
    }
}
