import Foundation

/// Quota information for a single Gemini model.
struct ModelQuota: Identifiable {
    let id: String           // modelId from API
    let modelId: String
    let remainingFraction: Double   // 0.0 to 1.0
    let remainingAmount: Int?       // Absolute count of requests left
    let resetTime: Date?            // When quota resets

    /// Human-readable model name (strip prefixes, shorten)
    var displayName: String {
        // "gemini-2.5-pro-preview-05-06" → "Pro"
        // "gemini-2.5-flash-preview-05-20" → "Flash"
        // "gemini-2.0-flash" → "Flash 2.0"
        let lower = modelId.lowercased()
        if lower.contains("pro") { return "Pro" }
        if lower.contains("flash") { return "Flash" }
        return modelId
    }

    /// Percentage remaining (0–100)
    var percentRemaining: Int {
        Int(remainingFraction * 100)
    }

    /// Calculated total limit from remaining amount and fraction
    var totalLimit: Int? {
        guard let remaining = remainingAmount, remainingFraction > 0 else { return nil }
        return Int(Double(remaining) / remainingFraction)
    }
}

/// Aggregated quota response from the API.
struct QuotaResponse {
    let buckets: [ModelQuota]
    let fetchedAt: Date

    /// Time until the earliest reset
    var resetTimeString: String? {
        guard let earliest = buckets.compactMap(\.resetTime).min() else { return nil }
        let interval = earliest.timeIntervalSince(Date())
        if interval <= 0 { return "resetting now" }

        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        if hours > 0 {
            return "resets in \(hours)h \(minutes)m"
        }
        return "resets in \(minutes)m"
    }

    /// True if we have any meaningful quota data
    var hasData: Bool {
        !buckets.isEmpty
    }
}
