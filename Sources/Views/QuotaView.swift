import SwiftUI

/// Displays per-model quota usage with progress bars and reset time.
/// Shown between the header and session list in the menu bar panel.
struct QuotaView: View {
    @EnvironmentObject var quotaService: QuotaService

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if quotaService.isLoading && quotaService.quota == nil {
                loadingState
            } else if let error = quotaService.error, quotaService.quota == nil {
                errorState(error)
            } else if let quota = quotaService.quota, quota.hasData {
                quotaContent(quota)
            } else {
                // No data yet — trigger a fetch
                Text("Loading usage...")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .onAppear { quotaService.refresh() }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - States

    private var loadingState: some View {
        HStack(spacing: 6) {
            ProgressView()
                .controlSize(.small)
            Text("Loading usage...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private func errorState(_ message: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundColor(.orange)
                .font(.caption)
            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
    }

    // MARK: - Quota Content

    private func quotaContent(_ quota: QuotaResponse) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header: "Usage" + reset time
            HStack {
                Text("Usage")
                    .font(.caption)
                    .fontWeight(.semibold)
                Spacer()
                if let resetStr = quota.resetTimeString {
                    Text(resetStr)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                if quotaService.isLoading {
                    ProgressView()
                        .controlSize(.mini)
                }
            }

            // Per-model bars
            ForEach(quota.buckets) { bucket in
                QuotaBarView(quota: bucket)
            }
        }
    }
}

/// A single model's quota bar: label, progress bar, percentage, remaining count.
struct QuotaBarView: View {
    let quota: ModelQuota

    var body: some View {
        HStack(spacing: 8) {
            // Model name (fixed width for alignment)
            Text(quota.displayName)
                .font(.caption)
                .frame(width: 40, alignment: .leading)

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.primary.opacity(0.1))

                    // Filled portion
                    RoundedRectangle(cornerRadius: 3)
                        .fill(barColor)
                        .frame(width: geo.size.width * quota.remainingFraction)
                }
            }
            .frame(height: 6)

            // Percentage
            Text("\(quota.percentRemaining)%")
                .font(.caption2)
                .monospacedDigit()
                .frame(width: 30, alignment: .trailing)

            // Remaining count
            if let remaining = quota.remainingAmount {
                Text("\(remaining) left")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .frame(width: 55, alignment: .trailing)
            }
        }
        .frame(height: 14)
    }

    /// Color based on remaining fraction: green → yellow → red
    private var barColor: Color {
        if quota.remainingFraction > 0.5 { return .green }
        if quota.remainingFraction > 0.2 { return .yellow }
        return .red
    }
}
