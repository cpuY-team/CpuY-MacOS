import SwiftUI

struct StorageView: View {
    @EnvironmentObject private var monitor: SystemMonitor

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {

                // Physical drives
                if !monitor.disks.isEmpty {
                    CardView {
                        VStack(alignment: .leading, spacing: 4) {
                            SectionLabel(text: "Physical Drives")
                            ForEach(monitor.disks) { disk in
                                DiskRow(disk: disk)
                                if disk.index < monitor.disks.count - 1 {
                                    Divider().overlay(Color.cpuSep).padding(.vertical, 4)
                                }
                            }
                        }
                    }
                }

                // Volumes
                if !monitor.volumes.isEmpty {
                    CardView {
                        VStack(alignment: .leading, spacing: 4) {
                            SectionLabel(text: "Partitions & Volumes")
                            ForEach(monitor.volumes) { vol in
                                VolumeRow(vol: vol)
                                if vol.id != monitor.volumes.last?.id {
                                    Divider().overlay(Color.cpuSep).padding(.vertical, 4)
                                }
                            }
                        }
                    }
                }
                PrivilegedInfoCard(tab: .storage)
            }
            .padding(12)
        }
        .background(Color.cpuBg)
    }
}

private struct DiskRow: View {
    let disk: DiskDriveData
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: disk.isSSD ? "memorychip" : "internaldrive")
                    .foregroundStyle(Color.cpuAccent)
                Text(disk.model.isEmpty ? "Disk \(disk.index)" : disk.model)
                    .font(.system(size: 12, weight: .medium))
                if !disk.busType.isEmpty {
                    Text(disk.isSSD ? "[\(disk.busType)  SSD]" : "[\(disk.busType)  HDD]")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.cpuMuted)
                }
            }
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 2) {
                if disk.sizeBytes > 0 { KVRow(key: "Capacity", value: fmtBytes(disk.sizeBytes)) }
            }
        }
    }
}

private struct VolumeRow: View {
    let vol: VolumeData
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: vol.mountPoint == "/" ? "externaldrive.fill" : "folder")
                    .foregroundStyle(Color.cpuAccent)
                Text(vol.mountPoint)
                    .font(.system(size: 12, weight: .medium))
                Text(vol.fsType)
                    .font(.system(size: 10))
                    .foregroundStyle(Color.cpuMuted)
            }
            UsageBar(label: "Used", percent: vol.usagePercent, height: 14)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 2) {
                KVRow(key: "Total", value: fmtBytes(vol.totalBytes))
                KVRow(key: "Used",  value: fmtBytes(vol.usedBytes))
                KVRow(key: "Free",  value: fmtBytes(vol.freeBytes))
                KVRow(key: "Usage", value: String(format: "%.1f%%", vol.usagePercent))
            }
        }
    }
}
