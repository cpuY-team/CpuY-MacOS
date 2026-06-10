import SwiftUI

struct InfoView: View {
    @EnvironmentObject private var monitor: SystemMonitor
    private var si: SysInfoData   { monitor.sysInfo }
    private var cpu: CpuData      { monitor.cpu }
    private var ram: RamData      { monitor.ram }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {

                // OS
                CardView {
                    VStack(alignment: .leading, spacing: 2) {
                        SectionLabel(text: "Operating System")
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 2) {
                            KVRow(key: "OS",            value: si.osName)
                            KVRow(key: "Architecture",  value: si.architecture)
                            KVRow(key: "Version",       value: si.osVersion)
                            KVRow(key: "Hostname",      value: si.hostname)
                            if !si.osBuild.isEmpty { KVRow(key: "Build", value: si.osBuild) }
                            if !si.username.isEmpty { KVRow(key: "User", value: si.username) }
                            KVRow(key: "Kernel",        value: si.kernelVersion)
                        }
                    }
                }

                // Hardware
                CardView {
                    VStack(alignment: .leading, spacing: 2) {
                        SectionLabel(text: "Hardware")
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 2) {
                            KVRow(key: "Machine",        value: si.machineModel)
                            KVRow(key: "RAM Total",      value: fmtBytes(ram.totalBytes))
                            if !si.cpuVendor.isEmpty { KVRow(key: "CPU Vendor", value: si.cpuVendor) }
                            if ram.swapTotalBytes > 0 { KVRow(key: "Swap Total", value: fmtBytes(ram.swapTotalBytes)) }
                            KVRow(key: "CPU Model",      value: cpu.modelName)
                            if si.processCount > 0 { KVRow(key: "Processes", value: "\(si.processCount)") }
                            KVRow(key: "Logical Cores",  value: "\(cpu.logicalCores)")
                            KVRow(key: "Physical Cores", value: "\(cpu.physicalCores)")
                        }
                    }
                }

                // Firmware & Identity
                if !si.serialNumber.isEmpty {
                    CardView {
                        VStack(alignment: .leading, spacing: 2) {
                            SectionLabel(text: "Identity")
                            KVRow(key: "Serial No.", value: si.serialNumber)
                        }
                    }
                }

                // Uptime
                CardView {
                    VStack(alignment: .leading, spacing: 4) {
                        SectionLabel(text: "Uptime")
                        Text(fmtUptime(si.uptimeSeconds))
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundStyle(.primary)
                    }
                }
            }
            .padding(12)
        }
        .background(Color.cpuBg)
    }
}
