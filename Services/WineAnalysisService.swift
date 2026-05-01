import Foundation

enum WineAnalysisServiceError: Error {
    case backendNotConfigured
    case invalidImage
    case invalidResponse(String?)
    case requestFailed
    case serverError(WineAnalysisErrorResponse)
}

struct WineAnalysisService {
    func analyzeMenu(
        imageData: Data,
        purchaseMode: PurchaseMode,
        bottleContext: BottleContext?,
        preferences: UserWinePreferences
    ) async throws -> WineScanResult {
        guard let endpoint = AppConfiguration.shared.analysisEndpoint else {
            throw WineAnalysisServiceError.backendNotConfigured
        }

        guard imageData.isEmpty == false else {
            throw WineAnalysisServiceError.invalidImage
        }

        let requestBody = AnalyzeWineMenuRequest(
            imageBase64: imageData.base64EncodedString(),
            purchaseMode: purchaseMode,
            bottleContext: purchaseMode == .bottle ? bottleContext : nil,
            userPreferences: preferences.payload
        )

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
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

        if let errorResponse = try? decoder.decode(WineAnalysisErrorResponse.self, from: responseData) {
            throw WineAnalysisServiceError.serverError(errorResponse)
        }

        throw WineAnalysisServiceError.invalidResponse(String(data: responseData, encoding: .utf8))
    }
}
