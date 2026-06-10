import SwiftUI

struct ScreenView: View {
    @EnvironmentObject private var monitor: SystemMonitor

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {

                if monitor.displays.isEmpty {
                    CardView {
                        Text("No display information available.")
                            .foregroundStyle(Color.cpuMuted)
                    }
                } else {
                    let count = monitor.displays.count
                    CardView {
                        VStack(alignment: .leading, spacing: 0) {
                            HStack {
                                Text("\(count) Monitor\(count > 1 ? "s" : "") detected")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Color.cpuMuted)
                                Spacer()
                            }
                            .padding(.bottom, 4)

                            ForEach(monitor.displays) { disp in
                                DisplayRow(disp: disp, index: disp.id)
                                if disp.id < monitor.displays.count - 1 {
                                    Divider().overlay(Color.cpuSep).padding(.vertical, 8)
                                }
                            }
                        }
                    }

                    // Virtual desktop summary for multi-monitor
                    if monitor.displays.count > 1 {
                        let minX = monitor.displays.map { $0.posX }.min() ?? 0
                        let minY = monitor.displays.map { $0.posY }.min() ?? 0
                        let maxX = monitor.displays.map { $0.posX + $0.widthPt }.max() ?? 0
                        let maxY = monitor.displays.map { $0.posY + $0.heightPt }.max() ?? 0

                        CardView {
                            VStack(alignment: .leading, spacing: 4) {
                                SectionLabel(text: "Virtual Desktop")
                                KVRow(key: "Total size",
                                      value: "\(maxX - minX) × \(maxY - minY) pts (spanning \(monitor.displays.count) monitors)")
                            }
                        }
                    }
                }
                PrivilegedInfoCard(tab: .screen)
            }
            .padding(12)
        }
        .background(Color.cpuBg)
    }
}

private struct DisplayRow: View {
    let disp: DisplayData
    let index: Int

    private var aspectRatio: String {
        let a = disp.widthPx, b = disp.heightPx
        if a == 0 || b == 0 { return "—" }
        func gcd(_ x: Int, _ y: Int) -> Int { y == 0 ? x : gcd(y, x % y) }
        let g = gcd(a, b)
        return "\(a/g):\(b/g)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "display")
                    .foregroundStyle(disp.isPrimary ? Color.cpuAccent : .primary)
                Text("Display \(index + 1)\(disp.name.isEmpty ? "" : "  \(disp.name)")\(disp.isPrimary ? "  [Primary]" : "")")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(disp.isPrimary ? Color.cpuAccent : .primary)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 2) {
                KVRow(key: "Resolution",  value: "\(disp.widthPx) × \(disp.heightPx)")
                if disp.dpi > 0 {
                    KVRow(key: "DPI / PPI", value: String(format: "%.0f ppi", disp.dpi))
                }
                KVRow(key: "Points",      value: "\(disp.widthPt) × \(disp.heightPt)")
                KVRow(key: "Color depth", value: "\(disp.bitDepth)-bit")
                if disp.refreshRateHz > 0 {
                    KVRow(key: "Refresh", value: String(format: "%.0f Hz", disp.refreshRateHz))
                }
                if disp.widthPx > 0 && disp.heightPx > 0 {
                    KVRow(key: "Megapixels",  value: String(format: "%.2f MP", Double(disp.widthPx * disp.heightPx) / 1_000_000))
                    KVRow(key: "Aspect ratio", value: aspectRatio)
                }
                if disp.posX != 0 || disp.posY != 0 {
                    KVRow(key: "Position", value: "\(disp.posX), \(disp.posY)")
                }
            }
        }
        .padding(.vertical, 4)
    }
}
