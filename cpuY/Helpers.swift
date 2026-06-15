import SwiftUI
#if canImport(Charts)
import Charts
#endif

// MARK: - Theme

extension Color {
    static let cpuAccent  = Color(red: 0.25, green: 0.60, blue: 1.00)
    static let cpuGood    = Color(red: 0.20, green: 0.85, blue: 0.45)
    static let cpuWarn    = Color(red: 1.00, green: 0.75, blue: 0.10)
    static let cpuDanger  = Color(red: 1.00, green: 0.28, blue: 0.28)
    static let cpuMuted   = Color(nsColor: .secondaryLabelColor)
    static let cpuBg      = Color(nsColor: .windowBackgroundColor)
    static let cpuCard    = Color(nsColor: .controlBackgroundColor)
    static let cpuSep     = Color(nsColor: .separatorColor)
}

func usageColor(_ pct: Double) -> Color {
    if pct < 50 { return .cpuGood }
    if pct < 80 { return .cpuWarn }
    return .cpuDanger
}

// MARK: - Formatters

func fmtBytes(_ bytes: UInt64) -> String {
    let units = ["B", "KB", "MB", "GB", "TB"]
    var value = Double(bytes); var i = 0
    while value >= 1024 && i < 4 { value /= 1024; i += 1 }
    return String(format: "%.2f %@", value, units[i])
}

func fmtUptime(_ seconds: Int) -> String {
    let d = seconds / 86400, h = (seconds % 86400) / 3600
    let m = (seconds % 3600) / 60, s = seconds % 60
    return "\(d)d \(h)h \(m)m \(s)s"
}

// MARK: - View extensions for conditional OS features

extension View {
    /// Glass card background – Liquid Glass on 26+, material on 12–25, flat on 11.
    @ViewBuilder
    func cardStyle() -> some View {
        if #available(macOS 26, *) {
            self.glassEffect(in: RoundedRectangle(cornerRadius: 14))
        } else if #available(macOS 12, *) {
            self
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        } else {
            self
                .background(Color.cpuCard)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    /// Sidebar / panel background.
    @ViewBuilder
    func sidebarMaterial() -> some View {
        if #available(macOS 12, *) {
            self.background(.ultraThinMaterial)
        } else {
            self.background(Color(red: 0.10, green: 0.10, blue: 0.12))
        }
    }

    /// Window glass background (macOS 26 only).
    @ViewBuilder
    func windowGlass() -> some View {
        if #available(macOS 26, *) {
            self.containerBackground(.ultraThinMaterial, for: .window)
        } else {
            self
        }
    }

    /// Numeric text transition (macOS 14+), no-op otherwise.
    @ViewBuilder
    func numericTransition() -> some View {
        if #available(macOS 14, *) {
            self.contentTransition(.numericText())
        } else {
            self
        }
    }
}

// MARK: - Shared Components

struct SectionLabel: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(Color.cpuMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 8)
            .padding(.bottom, 4)
    }
}

struct KVRow: View {
    let key: String
    let value: String
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(key)
                .font(.system(size: 12))
                .foregroundStyle(Color.cpuMuted)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 6)
            Text(value)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.primary)
                .textSelection(.enabled)
                .lineLimit(2)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 3)
    }
}

struct UsageBar: View {
    var label: String = ""
    let percent: Double
    var height: CGFloat = 14
    var body: some View {
        HStack(spacing: 10) {
            if !label.isEmpty {
                Text(label)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.cpuMuted)
                    .frame(width: 80, alignment: .leading)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.primary.opacity(0.08))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(usageColor(percent))
                        .frame(width: max(2, geo.size.width * CGFloat(max(0, min(percent, 100)) / 100)))
                        .animation(.linear(duration: 0.3), value: percent)
                    Text(String(format: "%.1f%%", percent))
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.white.opacity(0.85))
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .frame(height: height)
        }
    }
}

// MARK: - Sparkline (tiered by OS)

struct SparklineView: View {
    let data: [Double]
    var color: Color = .cpuAccent

    var body: some View {
        if #available(macOS 13, *) {
            ChartsSparkline(data: data, color: color)
        } else {
            PathSparkline(data: data, color: color)
        }
    }
}

@available(macOS 13, *)
private struct ChartsSparkline: View {
    let data: [Double]
    var color: Color

    private struct Pt: Identifiable { let id: Int; let val: Double }

    var body: some View {
        let pts = data.enumerated().map { Pt(id: $0.offset, val: $0.element) }
        Chart(pts) { pt in
            AreaMark(x: .value("t", pt.id), y: .value("v", pt.val))
                .foregroundStyle(color.opacity(0.20).gradient)
            LineMark(x: .value("t", pt.id), y: .value("v", pt.val))
                .foregroundStyle(color)
                .lineStyle(StrokeStyle(lineWidth: 1.5))
        }
        .chartYScale(domain: 0...100)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
        .frame(height: 55)
        .background(Color.primary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

// Works on macOS 11+
private struct PathSparkline: View {
    let data: [Double]
    var color: Color

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let count = data.count
            if count > 1 {
                let pts: [CGPoint] = data.enumerated().map { i, v in
                    CGPoint(x: w * CGFloat(i) / CGFloat(count - 1),
                            y: h - h * CGFloat(max(0, min(v, 100))) / 100)
                }
                // Area fill
                Path { path in
                    path.move(to: CGPoint(x: pts[0].x, y: h))
                    path.addLine(to: pts[0])
                    for pt in pts.dropFirst() { path.addLine(to: pt) }
                    path.addLine(to: CGPoint(x: pts.last!.x, y: h))
                    path.closeSubpath()
                }
                .fill(color.opacity(0.20))
                // Line
                Path { path in
                    path.move(to: pts[0])
                    for pt in pts.dropFirst() { path.addLine(to: pt) }
                }
                .stroke(color, lineWidth: 1.5)
            }
        }
        .frame(height: 55)
        .background(Color.primary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

// MARK: - Card

struct CardView<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardStyle()
    }
}

// MARK: - Privileged Info Card

struct PrivilegedInfoCard: View {
    let tab: PrivilegedTab
    @EnvironmentObject private var monitor: SystemMonitor
    @State private var showSheet = false
    @State private var error = ""

    private var hint: String {
        switch tab {
        case .cpu:     return "Read CPU power draw and frequency data via powermetrics."
        case .ram:     return "Read detailed memory slot information."
        case .storage: return "Read storage type, SMART status, and capacity details."
        case .battery: return "Read raw battery registry (chemistry, cycle count, serial)."
        case .network: return "Read routing table and ARP cache."
        case .screen:  return "Read full display details including EDID data."
        case .os:      return "Read all NVRAM variables and SMC sensor data."
        case .info:    return "Read full hardware report."
        }
    }

    var body: some View {
        CardView {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    SectionLabel(text: "Root Info")
                    Spacer()
                    if monitor.isGatheringPriv {
                        HStack(spacing: 6) {
                            ProgressView().scaleEffect(0.6)
                            Text("Gathering…").font(.system(size: 11)).foregroundStyle(Color.cpuMuted)
                        }
                    } else {
                        Button(monitor.privilegedData == nil ? "Gather More Info" : "Refresh") {
                            error = ""; showSheet = true
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.cpuAccent)
                    }
                }

                if let priv = monitor.privilegedData {
                    privContent(priv)
                } else {
                    Text(hint).font(.system(size: 12)).foregroundStyle(Color.cpuMuted)
                    if !error.isEmpty {
                        Text(error).font(.system(size: 11)).foregroundStyle(Color.cpuDanger)
                    }
                }
            }
        }
        .sheet(isPresented: $showSheet) {
            PrivilegedPasswordSheet(error: $error) { pw in
                monitor.gatherPrivilegedInfo(password: pw) { err in
                    if let err { error = err; showSheet = true }
                }
            }
        }
    }

    @ViewBuilder
    private func privContent(_ priv: PrivilegedData) -> some View {
        switch tab {
        case .cpu:
            kvSection("CPU Power & Frequency", priv.cpu)
        case .ram:
            kvSection("Memory Details", priv.ram)
        case .storage:
            kvSection("Storage Details", priv.storage)
        case .battery:
            kvSection("Battery Registry", priv.battery)
        case .network:
            kvSection("Routing & ARP", priv.network)
        case .screen:
            kvSection("Display Details", priv.screen)
        case .os:
            if !priv.smc.isEmpty {
                kvSection("SMC Sensors", priv.smc)
                Divider().overlay(Color.cpuSep)
            }
            nvramSection(priv.nvram)
        case .info:
            kvSection("Hardware Report", priv.info)
        }
    }

    @ViewBuilder
    private func kvSection(_ title: String, _ items: [PrivilegedKV]) -> some View {
        if items.isEmpty {
            Text("No data returned.").font(.system(size: 12)).foregroundStyle(Color.cpuMuted)
        } else {
            SectionLabel(text: title)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 2) {
                ForEach(items) { item in KVRow(key: item.key, value: item.value) }
            }
        }
    }

    @ViewBuilder
    private func nvramSection(_ entries: [PrivilegedNVRAMEntry]) -> some View {
        if entries.isEmpty {
            Text("No NVRAM data returned.").font(.system(size: 12)).foregroundStyle(Color.cpuMuted)
        } else {
            SectionLabel(text: "NVRAM — \(entries.count) variables")
            VStack(spacing: 0) {
                ForEach(entries) { entry in
                    HStack(alignment: .top, spacing: 6) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(entry.displayKey)
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            if !entry.guid.isEmpty {
                                Text(entry.guid)
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundStyle(Color.cpuMuted)
                            }
                        }
                        .frame(minWidth: 130, alignment: .leading)
                        Spacer()
                        Text(entry.value)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(Color.cpuMuted)
                            .lineLimit(2)
                            .multilineTextAlignment(.trailing)
                    }
                    .padding(.vertical, 3)
                    if entry.id != entries.last?.id {
                        Divider().overlay(Color.cpuSep.opacity(0.5))
                    }
                }
            }
        }
    }
}

private struct PrivilegedPasswordSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var error: String
    @State private var password = ""
    let onSubmit: (String) -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 40))
                .foregroundStyle(Color.cpuAccent)
            Text("Administrator Access")
                .font(.headline)
            Text("Your password is used once with sudo to gather privileged hardware data. It is never stored.")
                .font(.system(size: 12))
                .foregroundStyle(Color.cpuMuted)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)
            SecureField("Password", text: $password)
                .textFieldStyle(.roundedBorder)
                .frame(width: 240)
                .onSubmit { submit() }
            if !error.isEmpty {
                Text(error).font(.system(size: 11)).foregroundStyle(Color.cpuDanger)
            }
            HStack(spacing: 12) {
                Button("Cancel") { password = ""; error = ""; dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Gather") { submit() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(password.isEmpty)
            }
        }
        .padding(28)
        .frame(width: 360)
    }

    private func submit() {
        let pw = password; password = ""; error = ""; dismiss(); onSubmit(pw)
    }
}
