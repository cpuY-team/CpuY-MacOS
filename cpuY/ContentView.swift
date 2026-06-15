import SwiftUI

private enum NavItem: String, CaseIterable {
    case cpu     = "CPU"
    case ram     = "RAM"
    case storage = "Storage"
    case battery = "Battery"
    case network = "Network"
    case screen  = "Screen"
    case os      = "OS"
    case info    = "Info"
    case about   = "About"

    var icon: String {
        switch self {
        case .cpu:     return "cpu"
        case .ram:     return "memorychip"
        case .storage: return "internaldrive"
        case .battery: return "battery.100"
        case .network: return "network"
        case .screen:  return "display"
        case .os:      return "shield.lefthalf.filled"
        case .info:    return "info.circle"
        case .about:   return "questionmark.circle"
        }
    }
}

struct ContentView: View {
    @EnvironmentObject private var monitor: SystemMonitor
    @State private var selected: NavItem = .cpu

    var body: some View {
        if #available(macOS 13, *) {
            splitLayout
        } else {
            legacyLayout
        }
    }

    // MARK: - Modern split view (macOS 13+)

    @available(macOS 13, *)
    private var splitLayout: some View {
        NavigationSplitView {
            List(NavItem.allCases, id: \.self, selection: splitSelection) { item in
                Label(item.rawValue, systemImage: item.icon)
            }
            .navigationSplitViewColumnWidth(min: 148, ideal: 170)
            .navigationTitle("cpuY")
            .safeAreaInset(edge: .bottom, spacing: 0) {
                sidebarFooter
            }
        } detail: {
            detailView(for: selected)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 700, minHeight: 520)
    }

    private var splitSelection: Binding<NavItem?> {
        Binding(get: { selected }, set: { selected = $0 ?? .cpu })
    }

    // MARK: - Sidebar footer

    private var sidebarFooter: some View {
        VStack(spacing: 0) {
            Divider()
            VStack(spacing: 10) {
                miniStatBar(label: "CPU",
                            value: String(format: "%.0f%%", monitor.cpu.usagePercent),
                            percent: monitor.cpu.usagePercent)
                miniStatBar(label: "RAM",
                            value: String(format: "%.0f%%", monitor.ram.usagePercent),
                            percent: monitor.ram.usagePercent)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .animation(.linear(duration: 0.4), value: monitor.cpu.usagePercent)
    }

    private func miniStatBar(label: String, value: String, percent: Double) -> some View {
        VStack(spacing: 4) {
            HStack {
                Text(label)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.cpuMuted)
                Spacer()
                Text(value)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(usageColor(percent))
                    .numericTransition()
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2).fill(Color.primary.opacity(0.08))
                    RoundedRectangle(cornerRadius: 2)
                        .fill(usageColor(percent))
                        .frame(width: geo.size.width * CGFloat(max(0, min(percent, 100))) / 100)
                        .animation(.linear(duration: 0.4), value: percent)
                }
            }
            .frame(height: 3)
        }
    }

    // MARK: - Legacy layout (macOS 11/12)

    private var legacyLayout: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                VStack(spacing: 3) {
                    Text("cpuY")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Color.cpuAccent)
                    Text("System Monitor")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.cpuMuted)
                }
                .padding(.top, 22)
                .padding(.bottom, 16)
                Divider().overlay(Color.cpuSep)
                VStack(spacing: 3) {
                    ForEach(NavItem.allCases, id: \.self) { item in
                        SidebarRow(item: item, isSelected: selected == item) {
                            selected = item
                        }
                    }
                }
                .padding(.top, 10)
                .padding(.horizontal, 8)
                Spacer()
                Divider().overlay(Color.cpuSep)
                VStack(spacing: 10) {
                    miniStatBar(label: "CPU",
                                value: String(format: "%.0f%%", monitor.cpu.usagePercent),
                                percent: monitor.cpu.usagePercent)
                    miniStatBar(label: "RAM",
                                value: String(format: "%.0f%%", monitor.ram.usagePercent),
                                percent: monitor.ram.usagePercent)
                }
                .padding(.vertical, 14)
                .padding(.horizontal, 14)
            }
            .frame(width: 148)
            .sidebarMaterial()
            Divider().overlay(Color.cpuSep)
            detailView(for: selected)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 720, minHeight: 580)
        .preferredColorScheme(.dark)
        .windowGlass()
    }

    // MARK: - Shared detail router

    @ViewBuilder
    private func detailView(for item: NavItem) -> some View {
        switch item {
        case .cpu:     CPUView()
        case .ram:     RAMView()
        case .storage: StorageView()
        case .battery: BatteryView()
        case .network: NetworkView()
        case .screen:  ScreenView()
        case .os:      OSView()
        case .info:    InfoView()
        case .about:   AboutView()
        }
    }
}

private struct SidebarRow: View {
    let item: NavItem
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 0) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Color.cpuAccent)
                    .frame(width: 16)
                    .opacity(isSelected ? 1 : 0)
                Image(systemName: item.icon)
                    .font(.system(size: 13))
                    .foregroundStyle(isSelected ? Color.cpuAccent : Color.cpuMuted)
                    .frame(width: 22)
                Text(item.rawValue)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? .primary : Color.cpuMuted)
                Spacer()
            }
            .padding(.vertical, 9)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.cpuAccent.opacity(0.14) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ContentView()
        .environmentObject(SystemMonitor())
}
