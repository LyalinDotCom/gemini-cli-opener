import Foundation

/// Fetches Gemini API quota data by reusing the CLI's stored OAuth credentials.
///
/// Flow:
/// 1. Read ~/.gemini/oauth_creds.json for access_token + refresh_token
/// 2. Refresh the token via Google OAuth2 if expired
/// 3. POST to cloudcode-pa.googleapis.com/v1internal:retrieveUserQuota
/// 4. Parse and filter the response into ModelQuota buckets
class QuotaService: ObservableObject {
    @Published var quota: QuotaResponse?
    @Published var isLoading = false
    @Published var error: String?

    private let credentialsURL: URL
    private let quotaEndpoint = "https://cloudcode-pa.googleapis.com/v1internal:retrieveUserQuota"

    // Gemini CLI's public OAuth client credentials (installed app — not secret)
    private let clientId = "681255809395-oo8ft2oprdrnp9e3aqf6av3hmdib135j.apps.googleusercontent.com"
    private let clientSecret = "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"
    private let tokenEndpoint = "https://oauth2.googleapis.com/token"

    /// Minimum interval between fetches
    private let minFetchInterval: TimeInterval = 60
    private var lastFetchTime: Date?

    init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        self.credentialsURL = home.appendingPathComponent(".gemini/oauth_creds.json")
    }

    /// Fetch quota data from the API. Skips if fetched recently.
    func refresh(force: Bool = false) {
        if !force, let last = lastFetchTime, Date().timeIntervalSince(last) < minFetchInterval {
            Log.data.debug("Quota fetch skipped — too recent")
            return
        }

        isLoading = true
        error = nil

        Task {
            do {
                let response = try await fetchQuota()
                await MainActor.run {
                    self.quota = response
                    self.isLoading = false
                    self.lastFetchTime = Date()
                    Log.data.info("Quota fetched: \(response.buckets.count) models")
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    self.isLoading = false
                    Log.data.error("Quota fetch failed: \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - API Call

    private func fetchQuota() async throws -> QuotaResponse {
        let token = try await getValidAccessToken()

        var request = URLRequest(url: URL(string: quotaEndpoint)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        // Empty body — the API rejects unknown fields
        request.httpBody = "{}".data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw QuotaError.invalidResponse
        }
        guard httpResponse.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? ""
            Log.data.error("Quota API returned \(httpResponse.statusCode): \(body)")
            throw QuotaError.apiError(httpResponse.statusCode, body)
        }

        return parseQuotaResponse(data)
    }

    // MARK: - OAuth Token Management

    private func getValidAccessToken() async throws -> String {
        let creds = try loadCredentials()

        // Check if token is still valid (with 60s buffer)
        if let expiry = creds.expiryDate, expiry > Date().addingTimeInterval(60) {
            return creds.accessToken
        }

        Log.data.info("Access token expired, refreshing...")
        guard let refreshToken = creds.refreshToken else {
            throw QuotaError.noRefreshToken
        }
        return try await refreshAccessToken(refreshToken: refreshToken)
    }

    private func refreshAccessToken(refreshToken: String) async throws -> String {
        var request = URLRequest(url: URL(string: tokenEndpoint)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = [
            "client_id=\(clientId)",
            "client_secret=\(clientSecret)",
            "refresh_token=\(refreshToken)",
            "grant_type=refresh_token"
        ].joined(separator: "&")
        request.httpBody = body.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw QuotaError.tokenRefreshFailed
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let newToken = json["access_token"] as? String else {
            throw QuotaError.tokenRefreshFailed
        }

        let expiresIn = json["expires_in"] as? Int ?? 3600
        try saveRefreshedToken(accessToken: newToken, expiresIn: expiresIn)

        Log.data.info("Access token refreshed successfully")
        return newToken
    }

    // MARK: - Credentials File I/O

    private struct StoredCredentials {
        let accessToken: String
        let refreshToken: String?
        let expiryDate: Date?
    }

    private func loadCredentials() throws -> StoredCredentials {
        guard let data = try? Data(contentsOf: credentialsURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let accessToken = json["access_token"] as? String else {
            throw QuotaError.noCredentials
        }

        var expiryDate: Date?
        if let expiryMs = json["expiry_date"] as? Double {
            expiryDate = Date(timeIntervalSince1970: expiryMs / 1000)
        }

        return StoredCredentials(
            accessToken: accessToken,
            refreshToken: json["refresh_token"] as? String,
            expiryDate: expiryDate
        )
    }

    private func saveRefreshedToken(accessToken: String, expiresIn: Int) throws {
        guard var data = try? Data(contentsOf: credentialsURL),
              var json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }

        json["access_token"] = accessToken
        json["expiry_date"] = (Date().timeIntervalSince1970 + Double(expiresIn)) * 1000

        data = try JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)
        try data.write(to: credentialsURL)
    }

    // MARK: - Response Parsing

    private func parseQuotaResponse(_ data: Data) -> QuotaResponse {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let buckets = json["buckets"] as? [[String: Any]] else {
            return QuotaResponse(buckets: [], fetchedAt: Date())
        }

        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime]

        let allQuotas: [ModelQuota] = buckets.compactMap { bucket in
            guard let modelId = bucket["modelId"] as? String else { return nil }

            // Skip _vertex duplicates — they mirror the main model
            if modelId.hasSuffix("_vertex") { return nil }

            // remainingFraction is the only usage field the API returns (0.0–1.0)
            let fraction = bucket["remainingFraction"] as? Double ?? 0

            var resetTime: Date?
            if let resetStr = bucket["resetTime"] as? String {
                resetTime = isoFormatter.date(from: resetStr)
            }

            return ModelQuota(
                id: modelId,
                modelId: modelId,
                remainingFraction: fraction,
                resetTime: resetTime
            )
        }

        // Sort: most-used models first (lowest remaining fraction)
        let sorted = allQuotas.sorted { $0.remainingFraction < $1.remainingFraction }

        return QuotaResponse(buckets: sorted, fetchedAt: Date())
    }
}

// MARK: - Errors

enum QuotaError: LocalizedError {
    case noCredentials
    case noRefreshToken
    case tokenRefreshFailed
    case invalidResponse
    case apiError(Int, String)

    var errorDescription: String? {
        switch self {
        case .noCredentials: return "No Gemini CLI credentials found"
        case .noRefreshToken: return "No refresh token — re-authenticate in Gemini CLI"
        case .tokenRefreshFailed: return "Failed to refresh access token"
        case .invalidResponse: return "Invalid API response"
        case .apiError(let code, _): return "API error (\(code))"
        }
    }
}
