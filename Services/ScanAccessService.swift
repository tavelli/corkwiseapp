import Foundation

enum ScanAccessServiceError: Error {
    case backendNotConfigured
    case authorizationFailed
    case invalidResponse(String?)
    case requestFailed
}

struct ScanAccessRequest: Codable {
    let action: String
    let appUserId: String
    let buildConfiguration: String

    init(appUserId: String, buildConfiguration: String) {
        action = "scan_access"
        self.appUserId = appUserId
        self.buildConfiguration = buildConfiguration
    }
}

struct ScanAccessResponse: Codable, Hashable {
    let hasActiveEntitlement: Bool
    let hasFreeScanAllowance: Bool
    let hasRetryCredit: Bool
    let freeScansUsed: Int
    let freeScanLimit: Int

    private enum CodingKeys: String, CodingKey {
        case hasActiveEntitlement
        case hasFreeScanAllowance
        case hasRetryCredit
        case freeScansUsed
        case freeScanLimit
    }

    init(
        hasActiveEntitlement: Bool,
        hasFreeScanAllowance: Bool,
        hasRetryCredit: Bool = false,
        freeScansUsed: Int,
        freeScanLimit: Int
    ) {
        self.hasActiveEntitlement = hasActiveEntitlement
        self.hasFreeScanAllowance = hasFreeScanAllowance
        self.hasRetryCredit = hasRetryCredit
        self.freeScansUsed = freeScansUsed
        self.freeScanLimit = freeScanLimit
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        hasActiveEntitlement = try container.decode(Bool.self, forKey: .hasActiveEntitlement)
        hasFreeScanAllowance = try container.decode(Bool.self, forKey: .hasFreeScanAllowance)
        hasRetryCredit = try container.decodeIfPresent(Bool.self, forKey: .hasRetryCredit) ?? false
        freeScansUsed = try container.decode(Int.self, forKey: .freeScansUsed)
        freeScanLimit = try container.decode(Int.self, forKey: .freeScanLimit)
    }
}

struct ScanAccessService {
    func scanAccess() async throws -> ScanAccessResponse {
        guard let endpoint = AppConfiguration.shared.analysisEndpoint else {
            throw ScanAccessServiceError.backendNotConfigured
        }

        let requestBody = ScanAccessRequest(
            appUserId: try appUserID(),
            buildConfiguration: await BuildChannel.current()
        )

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let apiKey = AppConfiguration.shared.supabaseAPIKey {
            request.setValue(apiKey, forHTTPHeaderField: "apikey")
        }
        request.setValue("Bearer \(try await accessToken())", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30
        request.httpBody = try JSONEncoder().encode(requestBody)

        let responseData: Data
        let response: URLResponse

        do {
            (responseData, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw ScanAccessServiceError.requestFailed
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ScanAccessServiceError.invalidResponse(nil)
        }

        if httpResponse.statusCode == 401 {
            throw ScanAccessServiceError.authorizationFailed
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw ScanAccessServiceError.invalidResponse(String(data: responseData, encoding: .utf8))
        }

        do {
            return try JSONDecoder().decode(ScanAccessResponse.self, from: responseData)
        } catch {
            throw ScanAccessServiceError.invalidResponse(String(data: responseData, encoding: .utf8))
        }
    }

    private func appUserID() throws -> String {
        do {
            return try AppIdentityService.shared.appUserID()
        } catch {
            throw ScanAccessServiceError.authorizationFailed
        }
    }

    private func accessToken() async throws -> String {
        do {
            return try await SupabaseAuthService.shared.accessToken()
        } catch SupabaseAuthServiceError.backendNotConfigured {
            throw ScanAccessServiceError.backendNotConfigured
        } catch {
            throw ScanAccessServiceError.authorizationFailed
        }
    }
}
