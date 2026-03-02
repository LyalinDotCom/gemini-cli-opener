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
                .lineLimit(2)
            Spacer()
            Button("Retry") {
                quotaService.refresh(force: true)
            }
            .buttonStyle(.bordered)
            .controlSize(.mini)
        }
    }

    // MARK: - Quota Content

    private func quotaContent(_ quota: QuotaResponse) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header row
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

            // Show models with usage first, then a summary of unused ones
            let used = quota.usedBuckets
            let unusedCount = quota.buckets.count - used.count

            if used.isEmpty {
                Text("All models at full quota")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ForEach(used) { bucket in
                    QuotaBarView(quota: bucket)
                }
            }

            if unusedCount > 0 {
                Text("\(unusedCount) other model\(unusedCount == 1 ? "" : "s") at 100%")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
}

/// A single model's quota bar: label, progress bar, percentage.
struct QuotaBarView: View {
    let quota: ModelQuota

    var body: some View {
        HStack(spacing: 8) {
            // Model name
            Text(quota.displayName)
                .font(.caption)
                .frame(width: 80, alignment: .leading)

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.primary.opacity(0.1))

                    RoundedRectangle(cornerRadius: 3)
                        .fill(barColor)
                        .frame(width: max(geo.size.width * quota.remainingFraction, 2))
                }
            }
            .frame(height: 6)

            // Percentage
            Text("\(quota.percentRemaining)%")
                .font(.caption2)
                .monospacedDigit()
                .foregroundColor(barColor)
                .frame(width: 32, alignment: .trailing)
        }
        .frame(height: 16)
    }

    /// Color based on remaining fraction: green → yellow → red
    private var barColor: Color {
        if quota.remainingFraction > 0.5 { return .green }
        if quota.remainingFraction > 0.2 { return .yellow }
        return .red
    }
}
