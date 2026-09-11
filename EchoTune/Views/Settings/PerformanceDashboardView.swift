import SwiftUI

struct PerformanceDashboardView: View {
    @State private var records: [PerfStore.SessionRecord] = []
    @State private var aggregate = PerfStore.Aggregate(count: 0, medianDecodeMs: 0, p95DecodeMs: 0, medianEnhancementMs: nil, p95EnhancementMs: nil)
    @State private var estimatedCloudCost: Decimal = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Performance")
                    .font(.title3.weight(.semibold))

                if let last = records.last {
                    sessionSection(last)
                    aggregateSection
                    cloudCostSection
                } else {
                    Label("No performance sessions recorded yet. Complete a dictation to populate this panel.", systemImage: "chart.bar.xaxis")
                        .foregroundColor(.secondary)
                        .padding(.vertical, 12)
                }

                Divider()
                Text("Performance data is stored locally on this Mac and never transmitted. Cloud cost figures are local estimates based on UsageMeter records, not billing statements.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 12)
        }
        .onAppear(perform: reload)
    }

    @ViewBuilder
    private func sessionSection(_ record: PerfStore.SessionRecord) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Last session")
                .font(.headline)
            metricRow("Recorded", record.recordedAt.formatted(date: .abbreviated, time: .shortened))
            metricRow("Engine / model", "\(record.engine.isEmpty ? "Unknown" : record.engine) / \(record.modelID.isEmpty ? "Unknown" : record.modelID)")
            metricRow("Recording", formatSeconds(record.fixtureDurationSeconds))
            metricRow("Decode wall time", formatMilliseconds(record.decodeMs))
            metricRow("First tick", record.firstTickMs.map(formatMilliseconds) ?? "Not recorded")
            metricRow("Tick p50 / p95", "\(record.p50TickMs.map(formatMilliseconds) ?? "Not recorded") / \(record.p95TickMs.map(formatMilliseconds) ?? "Not recorded")")
            metricRow("VAD", "\(record.vadMethod) (\(record.vadDecisionCounts.values.reduce(0, +)) decisions)")
            metricRow("Agreement", record.agreementDisposition ?? "Not recorded")
            if let enhancementMs = record.enhancementMs {
                metricRow("Enhancement", "\(formatMilliseconds(enhancementMs)) via \(record.provider ?? "unknown provider")")
            }
        }
        .padding(12)
        .background(Color.primary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var aggregateSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Last 30 days")
                .font(.headline)
            metricRow("Sessions", "\(aggregate.count)")
            metricRow("Decode median / p95", "\(formatMilliseconds(aggregate.medianDecodeMs)) / \(formatMilliseconds(aggregate.p95DecodeMs))")
            metricRow("Enhancement median / p95", "\(aggregate.medianEnhancementMs.map(formatMilliseconds) ?? "Not recorded") / \(aggregate.p95EnhancementMs.map(formatMilliseconds) ?? "Not recorded")")
        }
    }

    @ViewBuilder
    private var cloudCostSection: some View {
        if !UsageMeter.shared.recent.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Cloud usage estimate")
                    .font(.headline)
                metricRow("Estimated total", formatCost(estimatedCloudCost))
                metricRow("Basis", "Local UsageMeter seconds × configured provider estimate")
            }
        }
    }

    private func metricRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .foregroundColor(.secondary)
            Spacer(minLength: 16)
            Text(value)
                .multilineTextAlignment(.trailing)
        }
        .font(.callout)
    }

    private func reload() {
        records = PerfStore.shared.records
        aggregate = PerfStore.shared.aggregate(since: Date().addingTimeInterval(-30 * 24 * 60 * 60))
        estimatedCloudCost = UsageMeter.shared.recent.reduce(Decimal(0)) { partial, record in
            partial + (UsageMeter.shared.estimatedCost(for: record) ?? 0)
        }
    }

    private func formatSeconds(_ value: Double) -> String {
        String(format: "%.2fs", value)
    }

    private func formatMilliseconds(_ value: Double) -> String {
        String(format: "%.1fms", value)
    }

    private func formatCost(_ value: Decimal) -> String {
        "$\(NSDecimalNumber(decimal: value).doubleValue.formatted(.number.precision(.fractionLength(4)))) estimated"
    }
}
