import SwiftUI

struct AboutView: View {
    @EnvironmentObject private var monitor: SystemMonitor

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {

                CardView {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text("cpuY")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundStyle(Color.cpuAccent)
                            Text("System Monitor  v1.0")
                                .font(.system(size: 14))
                                .foregroundStyle(Color.cpuMuted)
                        }

                        Divider().overlay(Color.cpuSep)

                        Text("A macOS system monitor inspired by the cpuY iOS app and its C++ desktop port.")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)

                        Text("Displays CPU, RAM, storage, battery, network, and display information — refreshed live.")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }

                CardView {
                    VStack(alignment: .leading, spacing: 2) {
                        SectionLabel(text: "Credits")
                        KVRow(key: "Original iOS app", value: "nat649")
                        KVRow(key: "GitHub",            value: "github.com/nat649/cpuY-iOS")
                    }
                }

                CardView {
                    VStack(alignment: .leading, spacing: 10) {
                        SectionLabel(text: "Settings")

                        HStack {
                            Text("Refresh interval")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.cpuMuted)
                            Spacer()
                            Text(String(format: "%.1f s", monitor.refreshInterval))
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(.primary)
                                .frame(width: 44, alignment: .trailing)
                        }

                        Slider(value: $monitor.refreshInterval, in: 0.5...10.0, step: 0.5)
                            .tint(Color.cpuAccent)
                    }
                }

                CardView {
                    VStack(alignment: .leading, spacing: 4) {
                        SectionLabel(text: "Built with")
                        Text("SwiftUI  ·  Swift Charts  ·  Mach  ·  IOKit  ·  Darwin")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.cpuMuted)
                        Text("Licensed under GPL-3.0")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.cpuMuted)
                    }
                }
            }
            .padding(12)
        }
    }
}
