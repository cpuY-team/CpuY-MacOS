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
        HStack(spacing: 0) {

            // ── Sidebar ──────────────────────────────────────────────────────
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
                VStack(spacing: 6) {
                    MiniStat(label: "CPU",
                             value: String(format: "%.0f%%", monitor.cpu.usagePercent),
                             color: usageColor(monitor.cpu.usagePercent))
                    MiniStat(label: "RAM",
                             value: String(format: "%.0f%%", monitor.ram.usagePercent),
                             color: usageColor(monitor.ram.usagePercent))
                }
                .padding(.vertical, 14)
                .padding(.horizontal, 14)
                .numericTransition()
                .animation(.linear(duration: 0.4), value: monitor.cpu.usagePercent)
            }
            .frame(width: 148)
            .sidebarMaterial()

            Divider().overlay(Color.cpuSep)

            // ── Content ──────────────────────────────────────────────────────
            Group {
                switch selected {
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
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 720, minHeight: 580)
        .background(Color.cpuBg)
        .preferredColorScheme(.dark)
        .windowGlass()
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

private struct MiniStat: View {
    let label: String
    let value: String
    var color: Color = .primary
    var body: some View {
        HStack {
            Text(label).font(.system(size: 11)).foregroundStyle(Color.cpuMuted)
            Spacer()
            Text(value).font(.system(size: 11, weight: .semibold, design: .monospaced)).foregroundStyle(color)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(SystemMonitor())
}
