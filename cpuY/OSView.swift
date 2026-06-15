import SwiftUI

struct OSView: View {
    @EnvironmentObject private var monitor: SystemMonitor
    private var os: OSInfoData        { monitor.osInfo }
    private var hk: HackintoshData   { monitor.hackintosh }
    private var si: SysInfoData      { monitor.sysInfo }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                softwareSection
                securitySection
                bootSection
                environmentSection
                hackintoshSection
                PrivilegedInfoCard(tab: .os)
            }
            .padding(12)
        }
        .background(Color.cpuBg)
    }

    // MARK: - Software

    private var softwareSection: some View {
        CardView {
            VStack(alignment: .leading, spacing: 2) {
                SectionLabel(text: "Software")
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 2) {
                    KVRow(key: "macOS",    value: "\(si.osName) \(si.osVersion) (\(si.osBuild))")
                    KVRow(key: "Codename", value: macOSCodename(si.osVersion))
                    KVRow(key: "Kernel",   value: si.kernelVersion)
                    KVRow(key: "Machine",  value: si.machineModel)
                }
            }
        }
    }

    // MARK: - Security

    private var securitySection: some View {
        CardView {
            VStack(alignment: .leading, spacing: 8) {
                SectionLabel(text: "Security")

                // Top-level status row
                HStack(spacing: 12) {
                    statusPill(
                        label: "SIP",
                        on: os.sipEnabled,
                        onLabel: "Enabled",
                        offLabel: "Disabled"
                    )
                    if let fv = os.fileVaultEnabled {
                        statusPill(label: "FileVault", on: fv, onLabel: "On", offLabel: "Off")
                    }
                    if let gk = os.gatekeeperEnabled {
                        statusPill(label: "Gatekeeper", on: gk, onLabel: "Enabled", offLabel: "Disabled")
                    }
                    if os.isAppleSilicon, !os.secureBootLevel.isEmpty {
                        Text(os.secureBootLevel)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.cpuMuted)
                            .padding(.horizontal, 7).padding(.vertical, 2)
                            .background(Color.cpuCard)
                            .clipShape(Capsule())
                    }
                }

                // SIP per-flag breakdown
                Divider().overlay(Color.cpuSep)
                SectionLabel(text: "SIP Protection Flags")
                VStack(spacing: 0) {
                    ForEach(sipFlags, id: \.bit) { flag in
                        HStack {
                            Image(systemName: flagEnabled(flag.bit) ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(flagEnabled(flag.bit) ? Color.cpuGood : Color.cpuDanger)
                                .font(.system(size: 11))
                            Text(flag.label)
                                .font(.system(size: 12))
                                .foregroundStyle(flagEnabled(flag.bit) ? .primary : Color.cpuDanger)
                            Spacer()
                            Text(flagEnabled(flag.bit) ? "Protected" : "Disabled")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(flagEnabled(flag.bit) ? Color.cpuMuted : Color.cpuDanger)
                        }
                        .padding(.vertical, 3)
                        if flag.bit != sipFlags.last?.bit {
                            Divider().overlay(Color.cpuSep.opacity(0.5))
                        }
                    }
                }

                if os.sipFlags != 0 {
                    Text(String(format: "csr-active-config: 0x%04X", os.sipFlags))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Color.cpuMuted)
                }
            }
        }
    }

    // MARK: - Boot

    private var bootSection: some View {
        CardView {
            VStack(alignment: .leading, spacing: 2) {
                SectionLabel(text: "Boot")
                if !os.bootArgs.isEmpty {
                    KVRow(key: "Boot Args", value: os.bootArgs)
                } else {
                    KVRow(key: "Boot Args", value: "(none)")
                }
                if !os.boardID.isEmpty     { KVRow(key: "Board ID",       value: os.boardID)      }
                if !os.platformUUID.isEmpty { KVRow(key: "Platform UUID",  value: os.platformUUID) }
                if !si.serialNumber.isEmpty { KVRow(key: "Serial Number",  value: si.serialNumber) }
            }
        }
    }

    // MARK: - Environment

    private var environmentSection: some View {
        CardView {
            VStack(alignment: .leading, spacing: 2) {
                SectionLabel(text: "Environment")
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 2) {
                    if !os.computerName.isEmpty { KVRow(key: "Computer Name", value: os.computerName) }
                    if !si.hostname.isEmpty     { KVRow(key: "Hostname",      value: si.hostname)     }
                    if !si.username.isEmpty     { KVRow(key: "User",          value: si.username)     }
                    if !os.currentShell.isEmpty { KVRow(key: "Shell",         value: os.currentShell) }
                    if !os.timezone.isEmpty     { KVRow(key: "Timezone",      value: os.timezone)     }
                    if !os.locale.isEmpty       { KVRow(key: "Locale",        value: os.locale)       }
                }
            }
        }
    }

    // MARK: - Hackintosh

    private var hackintoshSection: some View {
        CardView {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    SectionLabel(text: "Hackintosh Detection")
                    Spacer()
                    if hk.checked { verdictBadge }
                }

                if !hk.checked {
                    HStack(spacing: 6) {
                        ProgressView().scaleEffect(0.6)
                        Text("Analysing system…")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.cpuMuted)
                    }
                } else {
                    // Bootloader + loaded kexts
                    if !hk.bootloaderName.isEmpty {
                        HStack(spacing: 8) {
                            Text("Bootloader:")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.cpuMuted)
                            let blLabel = hk.isOCLP
                                ? "OpenCore (OCLP \(hk.oclpVersion))"
                                : hk.bootloaderName + (hk.bootloaderVersion.isEmpty ? "" : " \(hk.bootloaderVersion)")
                            Text(blLabel)
                                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                .foregroundStyle(hk.isOCLP && hk.confidence <= 50
                                    ? Color(red: 0.6, green: 0.4, blue: 1.0)
                                    : Color.cpuDanger)
                        }
                    }

                    // Confidence meter
                    HStack(spacing: 8) {
                        Text("Confidence")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.cpuMuted)
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 3).fill(Color.cpuCard).frame(height: 8)
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(confidenceColor)
                                    .frame(width: geo.size.width * CGFloat(hk.confidence) / 100.0, height: 8)
                            }
                        }
                        .frame(height: 8)
                        Text("\(hk.confidence)%")
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundStyle(confidenceColor)
                            .frame(width: 36, alignment: .trailing)
                    }

                    if !hk.loadedHCKexts.isEmpty {
                        Divider().overlay(Color.cpuSep)
                        SectionLabel(text: "Suspicious Kexts (\(hk.loadedHCKexts.count))")
                        FlexRow(items: hk.loadedHCKexts) { kext in
                            Text(kext.components(separatedBy: ".").last ?? kext)
                                .font(.system(size: 10, design: .monospaced))
                                .padding(.horizontal, 5).padding(.vertical, 2)
                                .background(Color.cpuDanger.opacity(0.15))
                                .foregroundStyle(Color.cpuDanger)
                                .clipShape(RoundedRectangle(cornerRadius: 3))
                        }
                    }

                    Divider().overlay(Color.cpuSep)
                    SectionLabel(text: "Indicators")
                    VStack(spacing: 0) {
                        ForEach(hk.indicators) { ind in
                            HStack(alignment: .top, spacing: 6) {
                                let iconName = ind.suspicious ? "exclamationmark.triangle.fill"
                                             : ind.isWarning  ? "exclamationmark.circle.fill"
                                             : "checkmark.circle.fill"
                                let iconColor: Color = ind.suspicious ? .cpuWarn
                                             : ind.isWarning  ? .orange
                                             : .cpuGood
                                Image(systemName: iconName)
                                    .foregroundStyle(iconColor)
                                    .font(.system(size: 11))
                                    .padding(.top, 1)
                                VStack(alignment: .leading, spacing: 0) {
                                    HStack {
                                        Text(ind.name)
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundStyle(.primary)
                                        Spacer()
                                        if ind.suspicious {
                                            Text("+\(ind.points) pts")
                                                .font(.system(size: 10, design: .monospaced))
                                                .foregroundStyle(Color.cpuWarn)
                                        }
                                    }
                                    Text(ind.value)
                                        .font(.system(size: 11))
                                        .foregroundStyle(ind.isWarning ? .orange.opacity(0.8) : Color.cpuMuted)
                                        .lineLimit(2)
                                }
                            }
                            .padding(.vertical, 4)
                            if ind.id != hk.indicators.last?.id {
                                Divider().overlay(Color.cpuSep.opacity(0.5))
                            }
                        }
                    }
                }
            }
        }
    }


    // MARK: - Helpers

    private var verdictBadge: some View {
        let color = verdictColor
        let useDark = hk.confidence < 20
        return Text(hk.verdict)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(useDark ? Color.black : Color.white)
            .padding(.horizontal, 9).padding(.vertical, 3)
            .background(color)
            .clipShape(Capsule())
    }

    private var verdictColor: Color {
        if hk.isOCLP && hk.confidence <= 50 { return Color(red: 0.6, green: 0.4, blue: 1.0) }
        switch hk.confidence {
        case 0..<20: return .cpuGood
        case 20..<50: return .cpuWarn
        case 50..<80: return .orange
        default: return .cpuDanger
        }
    }

    private var confidenceColor: Color { verdictColor }

    private func flagEnabled(_ bit: UInt32) -> Bool {
        // A bit SET in csr-active-config means that protection is DISABLED
        // When sipFlags == 0, all protections are active (bit is NOT set → protected)
        return (os.sipFlags & bit) == 0
    }

    private struct SIPFlag { let bit: UInt32; let label: String }

    private let sipFlags: [SIPFlag] = [
        SIPFlag(bit: 0x001, label: "Kext Signing"),
        SIPFlag(bit: 0x002, label: "Filesystem Protections"),
        SIPFlag(bit: 0x004, label: "Task for PID (Debugging)"),
        SIPFlag(bit: 0x008, label: "Kernel Debugger"),
        SIPFlag(bit: 0x010, label: "Apple Internal"),
        SIPFlag(bit: 0x020, label: "DTrace"),
        SIPFlag(bit: 0x040, label: "NVRAM Protections"),
        SIPFlag(bit: 0x080, label: "Device Configuration"),
        SIPFlag(bit: 0x100, label: "Recovery OS Restrictions"),
        SIPFlag(bit: 0x200, label: "Unauthenticated Root"),
        SIPFlag(bit: 0x800, label: "Execution Policy"),
    ]

    private func macOSCodename(_ version: String) -> String {
        let major = Int(version.components(separatedBy: ".").first ?? "0") ?? 0
        switch major {
        case 26: return "Tahoe"
        case 15: return "Sequoia"
        case 14: return "Sonoma"
        case 13: return "Ventura"
        case 12: return "Monterey"
        case 11: return "Big Sur"
        case 10: return version.hasPrefix("10.15") ? "Catalina"
                        : version.hasPrefix("10.14") ? "Mojave"
                        : version.hasPrefix("10.13") ? "High Sierra"
                        : version.hasPrefix("10.12") ? "Sierra" : ""
        default: return ""
        }
    }

    private func statusPill(label: String, on: Bool, onLabel: String, offLabel: String) -> some View {
        let color: Color = on ? .cpuGood : .cpuDanger
        return VStack(spacing: 1) {
            Text(label).font(.system(size: 9)).foregroundStyle(Color.cpuMuted)
            Text(on ? onLabel : offLabel)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(color)
                .padding(.horizontal, 7).padding(.vertical, 2)
                .background(color.opacity(0.18))
                .clipShape(Capsule())
        }
    }
}

// Generic horizontal-wrapping flex row for pill lists
private struct FlexRow<Item: Hashable, Content: View>: View {
    let items: [Item]
    let content: (Item) -> Content
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                // Simple wrapping – SwiftUI doesn't have native flow layout for simple cases
                ForEach(items, id: \.self) { item in
                    content(item)
                }
            }
        }
    }
}
