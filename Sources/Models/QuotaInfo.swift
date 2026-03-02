import Foundation

/// Quota information for a single Gemini model.
/// The API returns remainingFraction (0.0–1.0) and reset time per model.
struct ModelQuota: Identifiable {
    let id: String
    let modelId: String
    let remainingFraction: Double   // 0.0 (exhausted) to 1.0 (full)
    let resetTime: Date?

    /// Short display name for UI
    var displayName: String {
        let lower = modelId.lowercased()
        // Map known model IDs to short labels
        if lower.contains("3-pro")            { return "3 Pro" }
        if lower.contains("3-flash")          { return "3 Flash" }
        if lower.contains("2.5-pro")          { return "2.5 Pro" }
        if lower.contains("2.5-flash-lite")   { return "2.5 Flash Lite" }
        if lower.contains("2.5-flash")        { return "2.5 Flash" }
        if lower.contains("2.0-flash")        { return "2.0 Flash" }
        return modelId
    }

    /// Percentage remaining (0–100)
    var percentRemaining: Int {
        Int(remainingFraction * 100)
    }

    /// True if this model has been used at all (fraction < 1.0)
    var hasUsage: Bool {
        remainingFraction < 1.0
    }
}

/// Aggregated quota response from the API.
struct QuotaResponse {
    let buckets: [ModelQuota]
    let fetchedAt: Date

    /// Models that have actual usage (not at 100%)
    var usedBuckets: [ModelQuota] {
        buckets.filter { $0.hasUsage }
    }

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

    var hasData: Bool {
        !buckets.isEmpty
    }
}
