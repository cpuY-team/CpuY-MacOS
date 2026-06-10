import Foundation
import Combine
import Darwin
import IOKit
import IOKit.ps
import AppKit
import SystemConfiguration

// MARK: - Data Models

struct CpuData {
    var usagePercent: Double = 0
    var coreUsage: [Double] = []
    var logicalCores: Int = 0
    var physicalCores: Int = 0
    var modelName: String = "—"
    var baseMHz: Double = 0
    var temperatureCelsius: Double = -1
    var l1iCacheBytes: Int = 0
    var l1dCacheBytes: Int = 0
    var l2CacheBytes: Int = 0
    var l3CacheBytes: Int = 0
    var features: [String] = []
    var busFreqMHz: Double = 0
    var packages: Int = 1
    var isAppleSilicon: Bool = false
}

struct MemoryModule: Identifiable {
    let id = UUID()
    var slot: String = ""
    var sizeBytes: UInt64 = 0
    var type: String = ""
    var speed: String = ""
    var manufacturer: String = ""
    var partNumber: String = ""
    var status: String = "ok"
}

struct RamData {
    var totalBytes: UInt64 = 0
    var usedBytes: UInt64 = 0
    var availableBytes: UInt64 = 0
    var usagePercent: Double = 0
    var swapTotalBytes: UInt64 = 0
    var swapUsedBytes: UInt64 = 0
    var swapUsagePercent: Double = 0
    var modules: [MemoryModule] = []
    var isUnifiedMemory: Bool = false
}

struct VolumeData: Identifiable {
    let id = UUID()
    var mountPoint: String = ""
    var fsType: String = ""
    var totalBytes: UInt64 = 0
    var usedBytes: UInt64 = 0
    var freeBytes: UInt64 = 0
    var usagePercent: Double = 0
}

struct BatteryData {
    var present: Bool = false
    var chargePercent: Double = -1
    var healthPercent: Double = -1
    var isCharging: Bool = false
    var isPluggedIn: Bool = false
    var timeRemainingMinutes: Int = -1
    var timeToFullMinutes: Int = -1
    var cycleCount: Int = -1
    var currentCapacityMAh: Int = -1
    var maxCapacityMAh: Int = -1
    var designCapacityMAh: Int = -1
    var voltage: Int = -1
    var amperage: Int = 0
    var temperatureCelsius: Double = -1
    var source: String = ""
}

struct InterfaceData: Identifiable {
    let id = UUID()
    var name: String = ""
    var ipv4: String = ""
    var ipv6: String = ""
    var macAddress: String = ""
    var isUp: Bool = false
    var bytesSent: UInt64 = 0
    var bytesReceived: UInt64 = 0
}

struct DisplayData: Identifiable {
    var id: Int
    var name: String = ""
    var widthPx: Int = 0
    var heightPx: Int = 0
    var widthPt: Int = 0
    var heightPt: Int = 0
    var posX: Int = 0
    var posY: Int = 0
    var refreshRateHz: Double = 0
    var dpi: Double = 0
    var bitDepth: Int = 32
    var isPrimary: Bool = false
}

struct DiskDriveData: Identifiable {
    var id: Int { index }
    var index: Int = 0
    var model: String = ""
    var busType: String = ""
    var sizeBytes: UInt64 = 0
    var isSSD: Bool = false
}

struct SysInfoData {
    var osName: String = "macOS"
    var osVersion: String = ""
    var osBuild: String = ""
    var kernelVersion: String = ""
    var hostname: String = ""
    var username: String = ""
    var architecture: String = ""
    var cpuVendor: String = ""
    var uptimeSeconds: Int = 0
    var processCount: Int = 0
    var machineModel: String = ""
    var serialNumber: String = ""
}

struct OSInfoData {
    var sipEnabled: Bool = true
    var sipFlags: UInt32 = 0
    var sipStatusString: String = ""
    var fileVaultEnabled: Bool? = nil
    var gatekeeperEnabled: Bool? = nil
    var bootArgs: String = ""
    var computerName: String = ""
    var timezone: String = ""
    var locale: String = ""
    var currentShell: String = ""
    var boardID: String = ""
    var platformUUID: String = ""
    var isAppleSilicon: Bool = false
    var secureBootLevel: String = ""
}

struct HackintoshIndicator: Identifiable {
    let id = UUID()
    var name: String
    var value: String
    var suspicious: Bool
    var points: Int
}

struct HackintoshData {
    var checked: Bool = false
    var bootloaderName: String = ""
    var bootloaderVersion: String = ""
    var confidence: Int = 0
    var verdict: String = "Checking…"
    var indicators: [HackintoshIndicator] = []
    var loadedHCKexts: [String] = []
}

// MARK: - System Monitor

final class SystemMonitor: ObservableObject {
    @Published var cpu          = CpuData()
    @Published var ram          = RamData()
    @Published var volumes:       [VolumeData]    = []
    @Published var battery      = BatteryData()
    @Published var interfaces:    [InterfaceData] = []
    @Published var displays:      [DisplayData]   = []
    @Published var disks:         [DiskDriveData] = []
    @Published var sysInfo      = SysInfoData()
    @Published var osInfo       = OSInfoData()
    @Published var hackintosh   = HackintoshData()
    @Published var publicIP:      String          = "..."
    @Published var cpuHistory:    [Double]        = []
    @Published var ramHistory:    [Double]        = []

    // Manual backing for refreshInterval so we can call restartTimer() in the setter
    private var _refreshInterval: Double = 2.0
    var refreshInterval: Double {
        get { _refreshInterval }
        set {
            objectWillChange.send()
            _refreshInterval = newValue
            restartTimer()
        }
    }

    private let maxHistory = 120
    private let queue = DispatchQueue(label: "com.cpuY.monitor", qos: .utility)
    private var timerSource: DispatchSourceTimer?

    private var prevCoreUser:  [UInt64] = []
    private var prevCoreSys:   [UInt64] = []
    private var prevCoreIdle:  [UInt64] = []

    init() {
        queue.async { [weak self] in self?.fetchAndUpdate() }
        startTimer()
        fetchPublicIPBackground()
        fetchDisksBackground()
        fetchMemoryModulesBackground()
        fetchOSInfoBackground()
        fetchHackintoshBackground()
    }

    // MARK: - Timer

    private func startTimer() {
        let src = DispatchSource.makeTimerSource(queue: queue)
        src.schedule(deadline: .now() + _refreshInterval, repeating: _refreshInterval)
        src.setEventHandler { [weak self] in self?.fetchAndUpdate() }
        src.resume()
        timerSource = src
    }

    private func restartTimer() { timerSource?.cancel(); startTimer() }

    // MARK: - Main refresh loop

    private func fetchAndUpdate() {
        let newCpu  = fetchCPU()
        let newRam  = fetchRAM()
        let newVols = fetchVolumes()
        let newBat  = fetchBattery()
        let newNet  = fetchNetwork()
        let newSys  = fetchSysInfo()

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.cpu        = newCpu
            self.ram        = { var r = newRam; r.modules = self.ram.modules; r.isUnifiedMemory = self.ram.isUnifiedMemory; return r }()
            self.volumes    = newVols
            self.battery    = newBat
            self.interfaces = newNet
            self.sysInfo    = newSys
            self.displays   = self.fetchDisplaysOnMain()

            self.cpuHistory.append(newCpu.usagePercent)
            self.ramHistory.append(newRam.usagePercent)
            if self.cpuHistory.count > self.maxHistory { self.cpuHistory.removeFirst() }
            if self.ramHistory.count > self.maxHistory { self.ramHistory.removeFirst() }
        }
    }

    // MARK: - CPU

    private func fetchCPU() -> CpuData {
        var info = CpuData()

        var numCPUs: natural_t = 0
        var cpuInfoArray: processor_info_array_t?
        var numCpuInfo: mach_msg_type_number_t = 0
        let kr = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO,
                                     &numCPUs, &cpuInfoArray, &numCpuInfo)
        if kr == KERN_SUCCESS, let cpuInfo = cpuInfoArray {
            let count = Int(numCPUs)
            if prevCoreUser.count != count {
                prevCoreUser = Array(repeating: 0, count: count)
                prevCoreSys  = Array(repeating: 0, count: count)
                prevCoreIdle = Array(repeating: 0, count: count)
            }
            info.coreUsage = Array(repeating: 0.0, count: count)
            var totalUsed: UInt64 = 0; var totalAll: UInt64 = 0
            for i in 0..<count {
                let base = Int(CPU_STATE_MAX) * i
                let u  = UInt64(bitPattern: Int64(cpuInfo[base + Int(CPU_STATE_USER)]))
                let s  = UInt64(bitPattern: Int64(cpuInfo[base + Int(CPU_STATE_SYSTEM)]))
                let id = UInt64(bitPattern: Int64(cpuInfo[base + Int(CPU_STATE_IDLE)]))
                let dU = u &- prevCoreUser[i]; let dS = s &- prevCoreSys[i]; let dI = id &- prevCoreIdle[i]
                let tot = dU &+ dS &+ dI
                info.coreUsage[i] = tot > 0 ? Double(dU &+ dS) / Double(tot) * 100.0 : 0.0
                totalUsed &+= dU &+ dS; totalAll &+= tot
                prevCoreUser[i] = u; prevCoreSys[i] = s; prevCoreIdle[i] = id
            }
            info.usagePercent = totalAll > 0 ? Double(totalUsed) / Double(totalAll) * 100.0 : 0.0
            vm_deallocate(mach_task_self_, vm_address_t(UInt(bitPattern: cpuInfo)),
                          vm_size_t(Int(numCpuInfo) * MemoryLayout<Int32>.size))
        }

        var brand = [CChar](repeating: 0, count: 256); var sz = 256
        sysctlbyname("machdep.cpu.brand_string", &brand, &sz, nil, 0)
        let brandStr = String(cString: brand)
        info.modelName     = brandStr.isEmpty ? sysctlString("hw.model") : brandStr
        info.logicalCores  = sysctlInt("hw.logicalcpu")
        info.physicalCores = sysctlInt("hw.physicalcpu")
        info.packages      = max(1, sysctlInt("hw.packages"))

        var freq: UInt64 = 0; sz = MemoryLayout<UInt64>.size
        sysctlbyname("hw.cpufrequency", &freq, &sz, nil, 0)
        if freq == 0 { sz = MemoryLayout<UInt64>.size; sysctlbyname("hw.cpufrequency_max", &freq, &sz, nil, 0) }
        info.baseMHz = Double(freq) / 1_000_000.0

        var busFreq: UInt64 = 0; sz = MemoryLayout<UInt64>.size
        sysctlbyname("hw.busfrequency", &busFreq, &sz, nil, 0)
        info.busFreqMHz = Double(busFreq) / 1_000_000.0

        var l1i = 0, l1d = 0, l2 = 0, l3 = 0; sz = MemoryLayout<Int>.size
        sysctlbyname("hw.l1icachesize", &l1i, &sz, nil, 0); sz = MemoryLayout<Int>.size
        sysctlbyname("hw.l1dcachesize", &l1d, &sz, nil, 0); sz = MemoryLayout<Int>.size
        sysctlbyname("hw.l2cachesize",  &l2,  &sz, nil, 0); sz = MemoryLayout<Int>.size
        sysctlbyname("hw.l3cachesize",  &l3,  &sz, nil, 0)
        info.l1iCacheBytes = l1i; info.l1dCacheBytes = l1d
        info.l2CacheBytes  = l2;  info.l3CacheBytes  = l3

        var arm64: Int32 = 0; sz = MemoryLayout<Int32>.size
        sysctlbyname("hw.optional.arm64", &arm64, &sz, nil, 0)
        info.isAppleSilicon = arm64 != 0

        let rawFeats = [sysctlString("machdep.cpu.features"),
                        sysctlString("machdep.cpu.extfeatures"),
                        sysctlString("machdep.cpu.leaf7_features")]
            .joined(separator: " ")
        info.features = rawFeats.components(separatedBy: .whitespaces).filter { !$0.isEmpty }

        info.temperatureCelsius = -1
        return info
    }

    // MARK: - RAM

    private func fetchRAM() -> RamData {
        var info = RamData()
        var total: UInt64 = 0; var sz = MemoryLayout<UInt64>.size
        sysctlbyname("hw.memsize", &total, &sz, nil, 0); info.totalBytes = total

        let vmInfo64Count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        var count = vmInfo64Count; var vmStats = vm_statistics64_data_t()
        let kr = withUnsafeMutablePointer(to: &vmStats) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(vmInfo64Count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        if kr == KERN_SUCCESS {
            var pageSize: vm_size_t = 0; host_page_size(mach_host_self(), &pageSize)
            let pg = UInt64(pageSize)
            info.availableBytes = (UInt64(vmStats.free_count) + UInt64(vmStats.inactive_count)) * pg
            info.usedBytes      = total > info.availableBytes ? total - info.availableBytes : 0
            info.usagePercent   = total > 0 ? Double(info.usedBytes) / Double(total) * 100.0 : 0
        }

        var swap = xsw_usage(); sz = MemoryLayout<xsw_usage>.size
        sysctlbyname("vm.swapusage", &swap, &sz, nil, 0)
        info.swapTotalBytes = swap.xsu_total; info.swapUsedBytes = swap.xsu_used
        if info.swapTotalBytes > 0 {
            info.swapUsagePercent = Double(info.swapUsedBytes) / Double(info.swapTotalBytes) * 100.0
        }
        return info
    }

    private func fetchMemoryModulesBackground() {
        queue.async { [weak self] in
            guard let self else { return }
            let (modules, unified) = self.fetchMemoryModulesSP()
            DispatchQueue.main.async {
                self.ram.modules = modules
                self.ram.isUnifiedMemory = unified
            }
        }
    }

    private func fetchMemoryModulesSP() -> ([MemoryModule], Bool) {
        let output = shell("system_profiler SPMemoryDataType -json 2>/dev/null")
        guard let data = output.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let arr  = json["SPMemoryDataType"] as? [[String: Any]],
              let entry = arr.first,
              let items = entry["_items"] as? [[String: Any]] else { return ([], false) }

        let modules: [MemoryModule] = items.compactMap { item in
            let sizeStr = item["dimm_size"] as? String ?? ""
            if sizeStr.lowercased() == "empty" || sizeStr == "(empty)" { return nil }
            var m = MemoryModule()
            m.slot         = item["_name"]             as? String ?? ""
            m.sizeBytes    = parseMemSize(sizeStr)
            m.type         = item["dimm_type"]         as? String ?? ""
            m.speed        = item["dimm_speed"]        as? String ?? ""
            m.manufacturer = item["dimm_manufacturer"] as? String ?? ""
            m.partNumber   = item["dimm_part_number"]  as? String ?? ""
            m.status       = item["dimm_status"]       as? String ?? "ok"
            return m.sizeBytes > 0 ? m : nil
        }
        let isUnified = modules.first.map { $0.type.uppercased().contains("LPDDR") } ?? false
        return (modules, isUnified)
    }

    private func parseMemSize(_ str: String) -> UInt64 {
        let p = str.components(separatedBy: " ")
        guard let v = Double(p.first ?? "") else { return 0 }
        switch (p.dropFirst().first ?? "").uppercased() {
        case "KB": return UInt64(v * 1_024)
        case "MB": return UInt64(v * 1_048_576)
        case "GB": return UInt64(v * 1_073_741_824)
        case "TB": return UInt64(v * 1_099_511_627_776)
        default: return UInt64(v)
        }
    }

    // MARK: - Volumes

    private func fetchVolumes() -> [VolumeData] {
        var mounts: UnsafeMutablePointer<statfs>?
        let n = getmntinfo(&mounts, MNT_NOWAIT)
        guard n > 0, let mts = mounts else { return [] }
        let skip: Set<String> = ["devfs", "autofs", "tmpfs", "nullfs", "fdescfs", "map"]
        var result: [VolumeData] = []
        for i in 0..<Int(n) {
            let mt = mts[i]
            var v = VolumeData()
            v.mountPoint = withUnsafePointer(to: mt.f_mntonname) {
                $0.withMemoryRebound(to: CChar.self, capacity: Int(MNAMELEN)) { String(cString: $0) }
            }
            v.fsType = withUnsafePointer(to: mt.f_fstypename) {
                $0.withMemoryRebound(to: CChar.self, capacity: Int(MFSTYPENAMELEN)) { String(cString: $0) }
            }
            if skip.contains(v.fsType) { continue }
            let bsize = UInt64(mt.f_bsize)
            v.totalBytes = UInt64(mt.f_blocks) * bsize
            v.freeBytes  = UInt64(mt.f_bfree)  * bsize
            v.usedBytes  = v.totalBytes > v.freeBytes ? v.totalBytes - v.freeBytes : 0
            guard v.totalBytes > 0 else { continue }
            v.usagePercent = Double(v.usedBytes) / Double(v.totalBytes) * 100.0
            result.append(v)
        }
        return result
    }

    // MARK: - Battery

    private func fetchBattery() -> BatteryData {
        var info = BatteryData()
        info.healthPercent = -1; info.timeRemainingMinutes = -1; info.timeToFullMinutes = -1
        info.cycleCount = -1; info.voltage = -1; info.temperatureCelsius = -1

        let blob   = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let psList = IOPSCopyPowerSourcesList(blob).takeRetainedValue() as NSArray
        for src in psList {
            guard let rawDesc = IOPSGetPowerSourceDescription(blob, src as CFTypeRef),
                  let desc    = rawDesc.takeUnretainedValue() as? [String: AnyObject] else { continue }
            let type   = desc[kIOPSTypeKey] as? String ?? ""
            let hasCap = desc[kIOPSCurrentCapacityKey] != nil
            guard type == kIOPSInternalBatteryType || hasCap else { continue }
            info.present       = true
            info.source        = "IOPowerSources"
            info.chargePercent = Double(desc[kIOPSCurrentCapacityKey] as? Int ?? -1)
            if let mc = desc[kIOPSMaxCapacityKey] as? Int,
               let dc = desc["DesignCapacity"]   as? Int, dc > 0 {
                info.healthPercent = Double(mc) / Double(dc) * 100.0
            }
            let state        = desc[kIOPSPowerSourceStateKey] as? String ?? ""
            info.isPluggedIn = (state == kIOPSACPowerValue)
            info.isCharging  = info.isPluggedIn && (info.chargePercent < 100)
            if let tte = desc[kIOPSTimeToEmptyKey]      as? Int, tte > 0 { info.timeRemainingMinutes = tte }
            if let ttf = desc[kIOPSTimeToFullChargeKey] as? Int, ttf > 0 { info.timeToFullMinutes    = ttf }
            break
        }

        let svc = IOServiceGetMatchingService(0, IOServiceMatching("AppleSmartBattery"))
        if svc != IO_OBJECT_NULL {
            defer { IOObjectRelease(svc) }
            var propsRef: Unmanaged<CFMutableDictionary>?
            if IORegistryEntryCreateCFProperties(svc, &propsRef, kCFAllocatorDefault, 0) == KERN_SUCCESS {
                let raw = propsRef?.takeRetainedValue() as NSDictionary? ?? [:]
                if !info.present {
                    info.present = raw["BatteryInstalled"] as? Bool ?? true
                    info.source  = "AppleSmartBattery"
                    let curr   = raw["CurrentCapacity"] as? Int ?? 0
                    let maxCap = raw["MaxCapacity"]     as? Int ?? 0
                    if maxCap > 0 {
                        info.chargePercent      = Double(curr) / Double(maxCap) * 100.0
                        info.currentCapacityMAh = curr
                        info.maxCapacityMAh     = maxCap
                    }
                    let design = raw["DesignCapacity"] as? Int ?? 0
                    if design > 0, maxCap > 0 {
                        info.healthPercent     = Double(maxCap) / Double(design) * 100.0
                        info.designCapacityMAh = design
                    }
                    info.isCharging  = raw["IsCharging"]        as? Bool ?? false
                    info.isPluggedIn = raw["ExternalConnected"] as? Bool ?? false
                    if let tte = raw["TimeRemaining"] as? Int, tte > 0, tte < 65535 {
                        info.timeRemainingMinutes = tte
                    }
                }
                if let cc = raw["CycleCount"]  as? Int { info.cycleCount = cc }
                if let v  = raw["Voltage"]     as? Int { info.voltage    = v  }
                if let a  = raw["Amperage"]    as? Int { info.amperage   = a  }
                if let t  = raw["Temperature"] as? Int {
                    var c = Double(t) / 100.0 - 273.15
                    if c < -30 || c > 120 { c = Double(t) / 10.0 }
                    info.temperatureCelsius = c
                }
                if info.currentCapacityMAh < 0, let curr  = raw["CurrentCapacity"] as? Int { info.currentCapacityMAh = curr }
                if info.maxCapacityMAh    < 0, let maxCap = raw["MaxCapacity"]     as? Int { info.maxCapacityMAh     = maxCap }
                if info.designCapacityMAh < 0, let design = raw["DesignCapacity"]  as? Int { info.designCapacityMAh  = design }
            }
        }
        return info
    }

    // MARK: - Network

    private func fetchNetwork() -> [InterfaceData] {
        var result: [InterfaceData] = []
        var ifap: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifap) == 0, let ifList = ifap else { return result }
        defer { freeifaddrs(ifList) }

        var ifa: UnsafeMutablePointer<ifaddrs>? = ifList
        while let current = ifa {
            defer { ifa = current.pointee.ifa_next }
            guard let nameC = current.pointee.ifa_name else { continue }
            let name = String(cString: nameC)
            if name == "lo0" { continue }

            let idx: Int
            if let ex = result.firstIndex(where: { $0.name == name }) { idx = ex }
            else {
                var iface = InterfaceData(); iface.name = name
                iface.isUp = (current.pointee.ifa_flags & UInt32(IFF_UP)) != 0
                result.append(iface); idx = result.count - 1
            }
            guard let addr = current.pointee.ifa_addr else { continue }
            let fam = Int32(addr.pointee.sa_family)

            if fam == AF_INET {
                var buf = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
                addr.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { sin in
                    var a = sin.pointee.sin_addr; inet_ntop(AF_INET, &a, &buf, socklen_t(INET_ADDRSTRLEN))
                }
                if result[idx].ipv4.isEmpty { result[idx].ipv4 = String(cString: buf) }
            } else if fam == AF_INET6 {
                var buf = [CChar](repeating: 0, count: Int(INET6_ADDRSTRLEN))
                addr.withMemoryRebound(to: sockaddr_in6.self, capacity: 1) { sin6 in
                    var a = sin6.pointee.sin6_addr; inet_ntop(AF_INET6, &a, &buf, socklen_t(INET6_ADDRSTRLEN))
                }
                if result[idx].ipv6.isEmpty { result[idx].ipv6 = String(cString: buf) }
            } else if fam == AF_LINK {
                addr.withMemoryRebound(to: sockaddr_dl.self, capacity: 1) { sdl in
                    let nlen = Int(sdl.pointee.sdl_nlen), alen = Int(sdl.pointee.sdl_alen)
                    if alen == 6, result[idx].macAddress.isEmpty {
                        let mac: String = withUnsafePointer(to: sdl.pointee) { sPtr in
                            let raw = UnsafeRawPointer(sPtr)
                            return (0..<6).map { String(format: "%02X", raw.load(fromByteOffset: 8 + nlen + $0, as: UInt8.self)) }
                                         .joined(separator: ":")
                        }
                        result[idx].macAddress = mac
                    }
                    if let d = current.pointee.ifa_data?.assumingMemoryBound(to: if_data.self) {
                        result[idx].bytesSent     = UInt64(d.pointee.ifi_obytes)
                        result[idx].bytesReceived = UInt64(d.pointee.ifi_ibytes)
                    }
                }
            }
        }
        return result
    }

    // MARK: - Displays (main thread)

    private func fetchDisplaysOnMain() -> [DisplayData] {
        NSScreen.screens.enumerated().map { index, screen in
            var d = DisplayData(id: index)
            if #available(macOS 12, *) { d.name = screen.localizedName }
            let frame = screen.frame; let scale = screen.backingScaleFactor
            d.widthPt = Int(frame.width); d.heightPt = Int(frame.height)
            d.widthPx = Int(frame.width * scale); d.heightPx = Int(frame.height * scale)
            d.posX = Int(frame.origin.x); d.posY = Int(frame.origin.y); d.bitDepth = 32
            if let num = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber {
                let cgID = CGDirectDisplayID(num.uint32Value)
                d.isPrimary = (cgID == CGMainDisplayID())
                if let mode = CGDisplayCopyDisplayMode(cgID) { d.refreshRateHz = mode.refreshRate }
                let physMM = CGDisplayScreenSize(cgID)
                if physMM.width > 0 { d.dpi = Double(CGDisplayPixelsWide(cgID)) / (physMM.width / 25.4) }
            }
            return d
        }
    }

    // MARK: - System Info

    private func fetchSysInfo() -> SysInfoData {
        var info = SysInfoData()
        info.osName = "macOS"; info.osVersion = sysctlString("kern.osproductversion")
        info.osBuild = sysctlString("kern.osversion"); info.machineModel = sysctlString("hw.model")
        info.cpuVendor = sysctlString("machdep.cpu.vendor")
        var uts = utsname(); uname(&uts)
        info.kernelVersion = utsFieldString(&uts.release)
        info.hostname      = utsFieldString(&uts.nodename)
        info.architecture  = utsFieldString(&uts.machine)
        if let pw = getpwuid(getuid()) { info.username = String(cString: pw.pointee.pw_name) }
        var boottime = timeval(); var sz = MemoryLayout<timeval>.size
        sysctlbyname("kern.boottime", &boottime, &sz, nil, 0)
        info.uptimeSeconds = Int(time(nil) - boottime.tv_sec)
        var mibBuf: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_ALL]; var procSz = 0
        sysctl(&mibBuf, 3, nil, &procSz, nil, 0)
        info.processCount = procSz / MemoryLayout<kinfo_proc>.size
        let pe = IOServiceGetMatchingService(0, IOServiceMatching("IOPlatformExpertDevice"))
        if pe != IO_OBJECT_NULL {
            info.serialNumber = ioRegistryString(pe, "IOPlatformSerialNumber")
            IOObjectRelease(pe)
        }
        return info
    }

    // MARK: - OS Info

    private func fetchOSInfoBackground() {
        queue.async { [weak self] in
            guard let self else { return }
            let r = self.fetchOSInfo()
            DispatchQueue.main.async { self.osInfo = r }
        }
    }

    private func fetchOSInfo() -> OSInfoData {
        var info = OSInfoData()
        let sipOut = shell("csrutil status 2>/dev/null").trimmingCharacters(in: .whitespacesAndNewlines)
        info.sipEnabled = !sipOut.lowercased().contains("disabled")
        info.sipStatusString = sipOut
        let csrNvram = shell("nvram 7C436110-AB2A-4BBB-A880-FE41995C9F82:csr-active-config 2>/dev/null")
        info.sipFlags = parseCsrFlags(csrNvram)
        let fvOut = shell("fdesetup status 2>/dev/null").lowercased()
        if fvOut.contains("on") || fvOut.contains("enabled") { info.fileVaultEnabled = true }
        else if fvOut.contains("off") || fvOut.contains("disabled") { info.fileVaultEnabled = false }
        let spctlOut = shell("spctl --status 2>/dev/null").lowercased()
        if !spctlOut.isEmpty { info.gatekeeperEnabled = spctlOut.contains("enabled") }
        let bootRaw = shell("nvram boot-args 2>/dev/null").trimmingCharacters(in: .whitespacesAndNewlines)
        let bootParts = bootRaw.components(separatedBy: "\t")
        info.bootArgs = bootParts.count >= 2 ? bootParts.dropFirst().joined(separator: "\t") : ""
        let pe = IOServiceGetMatchingService(0, IOServiceMatching("IOPlatformExpertDevice"))
        if pe != IO_OBJECT_NULL {
            info.boardID      = ioRegistryString(pe, "board-id")
            info.platformUUID = ioRegistryString(pe, "IOPlatformUUID")
            IOObjectRelease(pe)
        }
        if let cfName = SCDynamicStoreCopyComputerName(nil, nil) { info.computerName = cfName as String }
        info.locale   = Locale.current.identifier
        info.timezone = TimeZone.current.identifier
        info.currentShell = ProcessInfo.processInfo.environment["SHELL"] ?? ""
        var arm64: Int32 = 0; var sz = MemoryLayout<Int32>.size
        sysctlbyname("hw.optional.arm64", &arm64, &sz, nil, 0)
        info.isAppleSilicon = arm64 != 0
        if info.isAppleSilicon {
            let bpOut = shell("bputil -g 2>/dev/null")
            if bpOut.contains("Full Security")   { info.secureBootLevel = "Full Security" }
            else if bpOut.contains("Medium")     { info.secureBootLevel = "Reduced Security" }
            else if bpOut.contains("Permissive") { info.secureBootLevel = "Permissive Security" }
            else                                  { info.secureBootLevel = "Unknown" }
        }
        return info
    }

    private func parseCsrFlags(_ nvramOut: String) -> UInt32 {
        guard let tabIdx = nvramOut.firstIndex(of: "\t") else { return 0 }
        let val = String(nvramOut[nvramOut.index(after: tabIdx)...]).trimmingCharacters(in: .whitespacesAndNewlines)
        var bytes: [UInt8] = []; var i = val.startIndex
        while i < val.endIndex {
            if val[i] == "%" {
                let s = val.index(i, offsetBy: 1)
                guard let e = val.index(s, offsetBy: 2, limitedBy: val.endIndex) else { break }
                if let b = UInt8(val[s..<e], radix: 16) { bytes.append(b) }
                i = e
            } else { i = val.index(after: i) }
        }
        guard !bytes.isEmpty else { return 0 }
        if bytes.count >= 4 {
            return UInt32(bytes[0]) | (UInt32(bytes[1]) << 8) | (UInt32(bytes[2]) << 16) | (UInt32(bytes[3]) << 24)
        }
        return UInt32(bytes[0])
    }

    // MARK: - Hackintosh Detection

    private func fetchHackintoshBackground() {
        queue.async { [weak self] in
            guard let self else { return }
            let r = self.detectHackintosh()
            DispatchQueue.main.async { self.hackintosh = r }
        }
    }

    private func detectHackintosh() -> HackintoshData {
        var data = HackintoshData(); data.checked = true
        var score = 0
        var indicators: [HackintoshIndicator] = []
        func ind(_ name: String, _ value: String, _ suspicious: Bool, _ pts: Int) {
            indicators.append(HackintoshIndicator(name: name, value: value, suspicious: suspicious, points: pts))
            if suspicious { score += pts }
        }
        var arm64: Int32 = 0; var sz = MemoryLayout<Int32>.size
        sysctlbyname("hw.optional.arm64", &arm64, &sz, nil, 0)
        let isARM = arm64 != 0
        if isARM { ind("Platform", "Apple Silicon (arm64)", false, 0) }
        let vendor = sysctlString("machdep.cpu.vendor")
        if vendor == "AuthenticAMD" { ind("CPU Vendor", "AuthenticAMD — Apple has never shipped AMD CPUs", true, 90) }
        else if !vendor.isEmpty { ind("CPU Vendor", vendor, false, 0) }
        let ocVersion = nvramValue("4D1FDA02-38C7-4A6A-9CC6-4BCCA8B30102:opencore-version")
        if !ocVersion.isEmpty {
            data.bootloaderName = "OpenCore"; data.bootloaderVersion = ocVersion
            ind("OpenCore", ocVersion, true, 90)
        }
        let cloverCheck = nvramValue("7C436110-AB2A-4BBB-A880-FE41995C9F82:Clover.Version")
        if !cloverCheck.isEmpty { data.bootloaderName = "Clover"; ind("Clover", cloverCheck, true, 85) }
        let kextOut = shell("kextstat 2>/dev/null | grep -iE 'VirtualSMC|FakeSMC|Lilu|AppleALC|WhateverGreen|IntelMausi|RealtekRTL8111|AirportItlwm|BrcmPatchRAM|NVMeFix|RestrictEvents' | awk '{print $6}'")
        let kextList = kextOut.components(separatedBy: "\n").filter { !$0.isEmpty }
        data.loadedHCKexts = kextList
        let kextScores: [(String, Int)] = [
            ("VirtualSMC", 75), ("FakeSMC", 80), ("Lilu", 60), ("AppleALC", 45),
            ("WhateverGreen", 45), ("IntelMausi", 40), ("RealtekRTL8111", 35),
            ("AirportItlwm", 40), ("BrcmPatchRAM", 35), ("NVMeFix", 30), ("RestrictEvents", 25)
        ]
        for kext in kextList {
            for (name, pts) in kextScores where kext.contains(name) { ind("Kext: \(name)", "Loaded", true, pts); break }
        }
        let bootArgs = nvramValue("boot-args")
        if !bootArgs.isEmpty {
            let suspArgs = ["alcid=","agdpmod=","shikigva=","-wegnoegpu","nv_disable=","igfxonln=",
                            "-igfxnohdmi","igfxfw=","cpuid_set=","-liludbg","-liluoff","-alcdbg","-wegdbg"]
            if suspArgs.contains(where: { bootArgs.contains($0) }) { ind("Boot Args", bootArgs, true, 40) }
            else if bootArgs.contains("-v") { ind("Boot Args (verbose)", bootArgs, true, 10) }
            else { ind("Boot Args", bootArgs, false, 0) }
        }
        let pe = IOServiceGetMatchingService(0, IOServiceMatching("IOPlatformExpertDevice"))
        if pe != IO_OBJECT_NULL {
            let serial = ioRegistryString(pe, "IOPlatformSerialNumber"); IOObjectRelease(pe)
            if serial.isEmpty || serial == "0" || serial == "000000000000" || serial.count < 8 {
                ind("Serial Number", serial.isEmpty ? "(empty)" : serial, true, 35)
            } else { ind("Serial Number", serial, false, 0) }
        }
        let csrOut = shell("nvram 7C436110-AB2A-4BBB-A880-FE41995C9F82:csr-active-config 2>/dev/null")
        if !csrOut.isEmpty {
            let flags = parseCsrFlags(csrOut)
            if flags != 0 { ind("SIP Config", String(format: "0x%04X (partially disabled)", flags), true, flags > 0x10 ? 20 : 10) }
            else { ind("SIP", "Fully enabled", false, 0) }
        }
        if isARM { score = min(score, 8) }
        data.confidence = min(score, 100)
        if isARM && score < 10 { data.verdict = "Apple Silicon — Genuine Mac" }
        else if data.confidence >= 80 { data.verdict = "Hackintosh Detected" }
        else if data.confidence >= 50 { data.verdict = "Likely Hackintosh" }
        else if data.confidence >= 20 { data.verdict = "Suspicious" }
        else { data.verdict = "Genuine Mac" }
        data.indicators = indicators
        return data
    }

    // MARK: - Disk Drives

    private func fetchDisksBackground() {
        queue.async { [weak self] in
            guard let self else { return }
            let r = self.fetchDisks()
            DispatchQueue.main.async { self.disks = r }
        }
    }

    private func fetchDisks() -> [DiskDriveData] {
        var result: [DiskDriveData] = []; var idx = 0
        for line in shell("diskutil list 2>/dev/null").components(separatedBy: "\n") {
            guard line.hasPrefix("/dev/disk") else { continue }
            let diskName = (line.components(separatedBy: " ").first ?? "").replacingOccurrences(of: "/dev/", with: "")
            guard diskName.range(of: #"^disk\d+$"#, options: .regularExpression) != nil else { continue }
            let infoStr = shell("diskutil info /dev/\(diskName) 2>/dev/null")
            var d = DiskDriveData(); d.index = idx; idx += 1
            for ln in infoStr.components(separatedBy: "\n") {
                let t = ln.trimmingCharacters(in: .whitespaces)
                if t.hasPrefix("Device / Media Name:") { d.model   = valueAfterColon(t) }
                if t.hasPrefix("Solid State:")         { d.isSSD   = valueAfterColon(t) == "Yes" }
                if t.hasPrefix("Protocol:")            { d.busType = valueAfterColon(t) }
                if t.hasPrefix("Disk Size:") {
                    let s = valueAfterColon(t)
                    if let p1 = s.firstIndex(of: "(") {
                        let sub = s[s.index(after: p1)...]
                        if let sp = sub.firstIndex(of: " ") { d.sizeBytes = UInt64(String(sub[..<sp])) ?? 0 }
                    }
                }
            }
            result.append(d)
        }
        return result
    }

    // MARK: - Public IP

    private func fetchPublicIPBackground() {
        DispatchQueue.global(qos: .background).async { [weak self] in
            let ip = (self?.shell("curl -s --max-time 5 https://api.ipify.org 2>/dev/null") ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            DispatchQueue.main.async { self?.publicIP = ip.isEmpty ? "Unavailable" : ip }
        }
    }

    func refreshPublicIP() { publicIP = "..."; fetchPublicIPBackground() }

    // MARK: - Utilities

    private func sysctlString(_ name: String) -> String {
        var buf = [CChar](repeating: 0, count: 256); var sz = 256
        sysctlbyname(name, &buf, &sz, nil, 0); return String(cString: buf)
    }
    private func sysctlInt(_ name: String) -> Int {
        var v: Int32 = 0; var sz = MemoryLayout<Int32>.size
        sysctlbyname(name, &v, &sz, nil, 0); return Int(v)
    }
    private func utsFieldString<T>(_ ptr: UnsafePointer<T>) -> String {
        ptr.withMemoryRebound(to: CChar.self, capacity: 256) { String(cString: $0) }
    }
    private func ioRegistryString(_ entry: io_registry_entry_t, _ key: String) -> String {
        guard let val = IORegistryEntryCreateCFProperty(entry, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() else { return "" }
        if let s = val as? String { return s }
        if let d = val as? Data { return String(bytes: d.filter { $0 != 0 }, encoding: .utf8) ?? "" }
        return ""
    }
    private func nvramValue(_ key: String) -> String {
        let out = shell("nvram \(key) 2>/dev/null").trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = out.components(separatedBy: "\t")
        return parts.count >= 2 ? parts.dropFirst().joined(separator: "\t") : ""
    }
    @discardableResult
    private func shell(_ cmd: String) -> String {
        let p = Process(); let pipe = Pipe()
        p.executableURL = URL(fileURLWithPath: "/bin/bash")
        p.arguments = ["-c", cmd]; p.standardOutput = pipe; p.standardError = Pipe()
        try? p.run(); p.waitUntilExit()
        return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    }
    private func valueAfterColon(_ s: String) -> String {
        guard let i = s.firstIndex(of: ":") else { return "" }
        return String(s[s.index(after: i)...]).trimmingCharacters(in: .whitespaces)
    }
}
