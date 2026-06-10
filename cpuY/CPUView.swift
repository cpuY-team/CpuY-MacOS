import SwiftUI
#if canImport(Charts)
import Charts
#endif

struct CPUView: View {
    @EnvironmentObject private var monitor: SystemMonitor
    private var cpu: CpuData { monitor.cpu }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {

                CardView {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(String(format: "%.1f%%", cpu.usagePercent))
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .foregroundStyle(usageColor(cpu.usagePercent))
                            if cpu.baseMHz > 0 {
                                Text(String(format: "@ %.0f MHz", cpu.baseMHz))
                                    .font(.system(size: 14))
                                    .foregroundStyle(Color.cpuMuted)
                            }
                            if cpu.isAppleSilicon {
                                Text("Apple Silicon")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.black)
                                    .padding(.horizontal, 7).padding(.vertical, 2)
                                    .background(Color.cpuAccent)
                                    .clipShape(Capsule())
                            }
                        }
                        SparklineView(data: monitor.cpuHistory)
                    }
                }

                CardView {
                    VStack(alignment: .leading, spacing: 2) {
                        SectionLabel(text: "Processor")
                        KVRow(key: "Model", value: cpu.modelName)
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 2) {
                            KVRow(key: "Logical Cores",  value: "\(cpu.logicalCores)")
                            KVRow(key: "Physical Cores", value: "\(cpu.physicalCores)")
                            if cpu.packages > 1         { KVRow(key: "Packages",  value: "\(cpu.packages)") }
                            if cpu.baseMHz > 0          { KVRow(key: "Base Freq", value: String(format: "%.0f MHz", cpu.baseMHz)) }
                            if cpu.busFreqMHz > 0       { KVRow(key: "Bus Freq",  value: String(format: "%.0f MHz", cpu.busFreqMHz)) }
                            if cpu.temperatureCelsius >= 0 { KVRow(key: "Temp",   value: String(format: "%.1f °C", cpu.temperatureCelsius)) }
                        }
                    }
                }

                if cpu.l2CacheBytes > 0 || cpu.l3CacheBytes > 0 {
                    CardView {
                        VStack(alignment: .leading, spacing: 2) {
                            SectionLabel(text: "Cache")
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 2) {
                                if cpu.l1iCacheBytes > 0 { KVRow(key: "L1 Instruction", value: fmtBytes(UInt64(cpu.l1iCacheBytes))) }
                                if cpu.l1dCacheBytes > 0 { KVRow(key: "L1 Data",        value: fmtBytes(UInt64(cpu.l1dCacheBytes))) }
                                if cpu.l2CacheBytes  > 0 { KVRow(key: "L2",             value: fmtBytes(UInt64(cpu.l2CacheBytes)))  }
                                if cpu.l3CacheBytes  > 0 { KVRow(key: "L3",             value: fmtBytes(UInt64(cpu.l3CacheBytes)))  }
                            }
                        }
                    }
                }

                if !cpu.features.isEmpty {
                    CardView {
                        VStack(alignment: .leading, spacing: 6) {
                            SectionLabel(text: "Feature Flags (\(cpu.features.count))")
                            FeatureFlagCloud(flags: cpu.features)
                        }
                    }
                }

                if !cpu.coreUsage.isEmpty {
                    CardView {
                        VStack(alignment: .leading, spacing: 6) {
                            SectionLabel(text: "Per-Core Usage")
                            CoreGrid(coreUsage: cpu.coreUsage)
                        }
                    }
                }
            }
            .padding(12)
        }
        .background(Color.cpuBg)
    }
}

private struct CoreGrid: View {
    let coreUsage: [Double]
    let cols = [GridItem(.flexible()), GridItem(.flexible())]
    var body: some View {
        LazyVGrid(columns: cols, spacing: 4) {
            ForEach(coreUsage.indices, id: \.self) { i in
                UsageBar(label: "Core \(i)", percent: coreUsage[i], height: 12)
            }
        }
    }
}

// Feature flag cloud – wrapping flow on 13+, adaptive grid on 11/12
private struct FeatureFlagCloud: View {
    let flags: [String]
    let highlighted: Set<String> = ["SSE","SSE2","SSE3","SSSE3","SSE4.1","SSE4.2",
                                    "AVX","AVX2","AVX512F","AES","FMA","F16C","BMI","BMI2","POPCNT"]
    var body: some View {
        if #available(macOS 13, *) {
            FlowLayout(spacing: 4) {
                ForEach(flags, id: \.self) { flagChip($0) }
            }
        } else {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 70, maximum: 120))], alignment: .leading, spacing: 4) {
                ForEach(flags, id: \.self) { flagChip($0) }
            }
        }
    }

    private func flagChip(_ flag: String) -> some View {
        Text(flag)
            .font(.system(size: 10, design: .monospaced))
            .padding(.horizontal, 5).padding(.vertical, 2)
            .background(highlighted.contains(flag) ? Color.cpuAccent.opacity(0.25) : Color.cpuCard)
            .foregroundStyle(highlighted.contains(flag) ? Color.cpuAccent : Color.cpuMuted)
            .clipShape(RoundedRectangle(cornerRadius: 3))
    }
}

// Wrapping flow layout – macOS 13+ (Layout protocol)
@available(macOS 13, *)
private struct FlowLayout: Layout {
    var spacing: CGFloat = 4
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 500
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0, maxY: CGFloat = 0
        for sub in subviews {
            let sz = sub.sizeThatFits(.unspecified)
            if x + sz.width > width, x > 0 { y += rowH + spacing; x = 0; rowH = 0 }
            rowH = max(rowH, sz.height); x += sz.width + spacing; maxY = y + rowH
        }
        return CGSize(width: width, height: maxY)
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowH: CGFloat = 0
        for sub in subviews {
            let sz = sub.sizeThatFits(.unspecified)
            if x + sz.width > bounds.maxX, x > bounds.minX { y += rowH + spacing; x = bounds.minX; rowH = 0 }
            sub.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            rowH = max(rowH, sz.height); x += sz.width + spacing
        }
    }
}
