import SwiftUI

struct BatteryView: View {
    @EnvironmentObject private var monitor: SystemMonitor
    private var bat: BatteryData { monitor.battery }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                if !bat.present {
                    CardView {
                        HStack(spacing: 10) {
                            Image(systemName: "desktopcomputer")
                                .font(.system(size: 28))
                                .foregroundStyle(Color.cpuMuted)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("No battery detected.")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Color.cpuMuted)
                                Text("If this is a hackintosh with a laptop battery, ensure AppleSmartBattery kext is loaded.")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Color.cpuMuted.opacity(0.7))
                            }
                        }
                        .padding(.vertical, 8)
                    }
                } else {
                    // Charge card
                    CardView {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .firstTextBaseline, spacing: 10) {
                                Text(String(format: "%.0f%%", max(0, bat.chargePercent)))
                                    .font(.system(size: 42, weight: .bold, design: .rounded))
                                    .foregroundStyle(batteryChargeColor)
                                VStack(alignment: .leading, spacing: 2) {
                                    statusBadge
                                    if !timeString.isEmpty {
                                        Text(timeString)
                                            .font(.system(size: 11))
                                            .foregroundStyle(Color.cpuMuted)
                                    }
                                }
                                Spacer()
                                if bat.amperage != 0 {
                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text(String(format: "%+d mA", bat.amperage))
                                            .font(.system(size: 12, design: .monospaced))
                                            .foregroundStyle(bat.amperage > 0 ? Color.cpuGood : Color.cpuWarn)
                                        if bat.voltage > 0 {
                                            Text(String(format: "%.2f V", Double(bat.voltage) / 1000.0))
                                                .font(.system(size: 11, design: .monospaced))
                                                .foregroundStyle(Color.cpuMuted)
                                        }
                                    }
                                }
                            }
                            UsageBar(label: "Charge", percent: max(0, bat.chargePercent), height: 18)
                        }
                    }

                    // Health
                    if bat.healthPercent >= 0 {
                        CardView {
                            VStack(alignment: .leading, spacing: 6) {
                                SectionLabel(text: "Battery Health")
                                UsageBar(label: "Health", percent: min(100, bat.healthPercent), height: 18)
                                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 2) {
                                    KVRow(key: "Health",   value: String(format: "%.1f%%", bat.healthPercent))
                                    if bat.cycleCount >= 0 { KVRow(key: "Cycle Count", value: "\(bat.cycleCount)") }
                                    if bat.currentCapacityMAh >= 0 { KVRow(key: "Current Cap", value: "\(bat.currentCapacityMAh) mAh") }
                                    if bat.maxCapacityMAh >= 0     { KVRow(key: "Max Cap",     value: "\(bat.maxCapacityMAh) mAh") }
                                    if bat.designCapacityMAh >= 0  { KVRow(key: "Design Cap",  value: "\(bat.designCapacityMAh) mAh") }
                                }
                            }
                        }
                    }

                    // Details
                    CardView {
                        VStack(alignment: .leading, spacing: 2) {
                            SectionLabel(text: "Details")
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 2) {
                                KVRow(key: "Status", value: statusText)
                                if bat.chargePercent >= 0   { KVRow(key: "Charge",  value: String(format: "%.0f%%", bat.chargePercent)) }
                                if bat.voltage > 0          { KVRow(key: "Voltage", value: String(format: "%.3f V", Double(bat.voltage) / 1000.0)) }
                                if bat.amperage != 0        { KVRow(key: "Current", value: String(format: "%+d mA", bat.amperage)) }
                                if bat.temperatureCelsius > 0 {
                                    KVRow(key: "Temp", value: String(format: "%.1f °C", bat.temperatureCelsius))
                                }
                                if !bat.source.isEmpty      { KVRow(key: "Source",  value: bat.source) }
                            }
                        }
                    }

                    // Power draw estimate
                    if bat.voltage > 0, bat.amperage != 0 {
                        CardView {
                            VStack(alignment: .leading, spacing: 2) {
                                SectionLabel(text: "Power")
                                let watts = abs(Double(bat.voltage) * Double(bat.amperage)) / 1_000_000.0
                                KVRow(key: bat.amperage < 0 ? "Draw" : "Input",
                                      value: String(format: "%.2f W", watts))
                            }
                        }
                    }
                }
                PrivilegedInfoCard(tab: .battery)
            }
            .padding(12)
        }
        .background(Color.cpuBg)
    }

    private var statusText: String {
        if bat.isCharging  { return "Charging" }
        if bat.isPluggedIn { return "Plugged In" }
        return "Discharging"
    }

    private var statusBadge: some View {
        let (label, color): (String, Color) = bat.isCharging
            ? ("Charging",    .cpuGood)
            : bat.isPluggedIn
            ? ("Plugged In",  .cpuAccent)
            : ("Discharging", .cpuWarn)
        return Text(label)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 7).padding(.vertical, 2)
            .background(color.opacity(0.18))
            .clipShape(Capsule())
    }

    private var batteryChargeColor: Color {
        if bat.isCharging      { return .cpuGood }
        if bat.chargePercent > 30 { return .cpuGood }
        if bat.chargePercent > 10 { return .cpuWarn }
        return .cpuDanger
    }

    private var timeString: String {
        if !bat.isCharging, bat.timeRemainingMinutes >= 0 {
            let h = bat.timeRemainingMinutes / 60, m = bat.timeRemainingMinutes % 60
            return "\(h)h \(m)m remaining"
        }
        if bat.isCharging, bat.timeToFullMinutes >= 0 {
            let h = bat.timeToFullMinutes / 60, m = bat.timeToFullMinutes % 60
            return "\(h)h \(m)m to full"
        }
        return ""
    }
}
