import SwiftUI

struct NetworkView: View {
    @EnvironmentObject private var monitor: SystemMonitor

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {

                if monitor.interfaces.isEmpty {
                    CardView {
                        Text("No network interfaces found.")
                            .foregroundStyle(Color.cpuMuted)
                    }
                } else {
                    CardView {
                        VStack(alignment: .leading, spacing: 0) {
                            SectionLabel(text: "Interfaces")
                            ForEach(monitor.interfaces) { iface in
                                InterfaceRow(iface: iface)
                                if iface.id != monitor.interfaces.last?.id {
                                    Divider().overlay(Color.cpuSep).padding(.vertical, 6)
                                }
                            }
                        }
                    }
                }

                CardView {
                    VStack(alignment: .leading, spacing: 6) {
                        SectionLabel(text: "Public IP")
                        HStack(spacing: 8) {
                            if monitor.publicIP == "..." {
                                ProgressView().scaleEffect(0.6)
                                Text("Fetching via api.ipify.org…")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color.cpuMuted)
                            } else {
                                Text(monitor.publicIP)
                                    .font(.system(size: 14, design: .monospaced))
                                    .foregroundStyle(.primary)
                                    .textSelection(.enabled)
                                Text("via api.ipify.org")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Color.cpuMuted)
                            }
                            Spacer()
                            Button("Refresh") { monitor.refreshPublicIP() }
                                .buttonStyle(.plain)
                                .font(.system(size: 11))
                                .foregroundStyle(Color.cpuAccent)
                        }
                    }
                }
            }
            .padding(12)
        }
        .background(Color.cpuBg)
    }
}

private struct InterfaceRow: View {
    let iface: InterfaceData

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Circle()
                    .fill(iface.isUp ? Color.cpuGood : Color.cpuDanger)
                    .frame(width: 7, height: 7)
                Text(iface.name)
                    .font(.system(size: 12, weight: .semibold))
                Text(iface.isUp ? "UP" : "DOWN")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(iface.isUp ? Color.cpuGood : Color.cpuDanger)
            }
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 2) {
                if !iface.ipv4.isEmpty       { KVRow(key: "IPv4",     value: iface.ipv4) }
                if iface.bytesSent > 0       { KVRow(key: "Sent",     value: fmtBytes(iface.bytesSent)) }
                if !iface.ipv6.isEmpty       { KVRow(key: "IPv6",     value: iface.ipv6) }
                if iface.bytesReceived > 0   { KVRow(key: "Received", value: fmtBytes(iface.bytesReceived)) }
                if !iface.macAddress.isEmpty { KVRow(key: "MAC",      value: iface.macAddress) }
            }
        }
        .padding(.vertical, 4)
    }
}
