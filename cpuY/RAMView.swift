import SwiftUI

struct RAMView: View {
    @EnvironmentObject private var monitor: SystemMonitor
    private var ram: RamData { monitor.ram }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {

                CardView {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(String(format: "%.1f%%", ram.usagePercent))
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .foregroundStyle(usageColor(ram.usagePercent))
                            Text("\(fmtBytes(ram.usedBytes)) / \(fmtBytes(ram.totalBytes))")
                                .font(.system(size: 13))
                                .foregroundStyle(Color.cpuMuted)
                            if ram.isUnifiedMemory {
                                Text("Unified")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.black)
                                    .padding(.horizontal, 7).padding(.vertical, 2)
                                    .background(Color.cpuAccent)
                                    .clipShape(Capsule())
                            }
                        }
                        UsageBar(label: "RAM", percent: ram.usagePercent, height: 16)
                        SparklineView(data: monitor.ramHistory)
                    }
                }

                CardView {
                    VStack(alignment: .leading, spacing: 2) {
                        SectionLabel(text: "Memory")
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 2) {
                            KVRow(key: "Total",     value: fmtBytes(ram.totalBytes))
                            KVRow(key: "Used",      value: fmtBytes(ram.usedBytes))
                            KVRow(key: "Available", value: fmtBytes(ram.availableBytes))
                        }
                    }
                }

                if ram.swapTotalBytes > 0 {
                    CardView {
                        VStack(alignment: .leading, spacing: 6) {
                            SectionLabel(text: "Swap / Compressed Memory")
                            UsageBar(label: "Swap", percent: ram.swapUsagePercent, height: 16)
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 2) {
                                KVRow(key: "Total", value: fmtBytes(ram.swapTotalBytes))
                                KVRow(key: "Used",  value: fmtBytes(ram.swapUsedBytes))
                                KVRow(key: "Usage", value: String(format: "%.1f%%", ram.swapUsagePercent))
                            }
                        }
                    }
                }

                // Memory modules
                if !ram.modules.isEmpty {
                    CardView {
                        VStack(alignment: .leading, spacing: 6) {
                            SectionLabel(text: "Memory Modules (\(ram.modules.count) slot\(ram.modules.count == 1 ? "" : "s"))")
                            ForEach(ram.modules) { mod in
                                ModuleRow(module: mod)
                                if mod.id != ram.modules.last?.id {
                                    Divider().overlay(Color.cpuSep)
                                }
                            }
                        }
                    }
                } else {
                    CardView {
                        HStack(spacing: 6) {
                            ProgressView().scaleEffect(0.6)
                            Text("Loading memory module info…")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.cpuMuted)
                        }
                    }
                }
            }
            .padding(12)
        }
        .background(Color.cpuBg)
    }
}

private struct ModuleRow: View {
    let module: MemoryModule

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(module.slot.isEmpty ? "Unknown Slot" : module.slot)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.primary)
                Spacer()
                Text(fmtBytes(module.sizeBytes))
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.cpuAccent)
            }
            HStack(spacing: 12) {
                if !module.type.isEmpty  { chip(module.type) }
                if !module.speed.isEmpty { chip(module.speed) }
                if module.status.lowercased() != "ok" && !module.status.isEmpty {
                    chip(module.status, bad: true)
                }
            }
            if !module.manufacturer.isEmpty || !module.partNumber.isEmpty {
                HStack(spacing: 6) {
                    if !module.manufacturer.isEmpty {
                        Text(module.manufacturer)
                            .font(.system(size: 10))
                            .foregroundStyle(Color.cpuMuted)
                    }
                    if !module.partNumber.isEmpty {
                        Text(module.partNumber)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(Color.cpuMuted)
                    }
                }
            }
        }
    }

    private func chip(_ label: String, bad: Bool = false) -> some View {
        Text(label)
            .font(.system(size: 10))
            .padding(.horizontal, 5).padding(.vertical, 1)
            .background(bad ? Color.cpuDanger.opacity(0.18) : Color.cpuCard)
            .foregroundStyle(bad ? Color.cpuDanger : Color.cpuMuted)
            .clipShape(RoundedRectangle(cornerRadius: 3))
    }
}
