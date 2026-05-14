import Auth
import Foundation

enum SupabaseAuthServiceError: Error {
    case backendNotConfigured
}

@MainActor
final class SupabaseAuthService {
    static let shared = SupabaseAuthService()

    private var authClient: AuthClient?

    func accessToken() async throws -> String {
        let client = try makeAuthClient()

        do {
            let session = try await client.session
            return session.accessToken
        } catch {
            return try await client.signInAnonymously().accessToken
        }
    }

    private func makeAuthClient() throws -> AuthClient {
        if let authClient {
            return authClient
        }

        guard
            let authEndpoint = AppConfiguration.shared.authEndpoint,
            let apiKey = AppConfiguration.shared.supabaseAPIKey
        else {
            throw SupabaseAuthServiceError.backendNotConfigured
        }

        let client = AuthClient(
            url: authEndpoint,
            headers: [
                "apikey": apiKey,
                "Authorization": "Bearer \(apiKey)",
            ],
            storageKey: AppConfiguration.shared.authStorageKey,
            localStorage: AuthClient.Configuration.defaultLocalStorage
        )
        authClient = client
        return client
    }
}
