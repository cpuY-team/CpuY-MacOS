# cpuY — macOS System Monitor

A native SwiftUI system monitor for macOS, ported and expanded from the original [iOS SwiftUI app](https://github.com/nat649/cpuY-iOS). Displays real-time CPU, RAM, storage, battery, network, display, and OS information — with full **Liquid Glass** support on macOS 26 Tahoe and graceful fallbacks down to macOS 12 Monterey.

---

## Features

### CPU
- Live usage percentage with animated sparkline history
- Per-core usage bars (all logical cores)
- L1i / L1d / L2 / L3 cache sizes
- Base frequency, bus frequency, package count
- Full ISA feature flag cloud (SSE, AVX, AES, FMA, BMI, etc.) with highlights for well-known extensions
- Apple Silicon badge detection

### RAM
- Live usage percentage with sparkline
- Used / available / total breakdown
- Swap / compressed memory usage bar
- **Memory module details** via `system_profiler`: slot, size, type (DDR4/LPDDR5/etc.), speed, manufacturer, part number
- Unified Memory badge for Apple Silicon

### Storage
- Physical drive list with model, bus type (NVMe / SATA / USB), capacity, SSD/HDD flag
- All mounted volumes with filesystem type, usage bar, total / used / free

### Battery
- Charge percentage, status badge (Charging / Plugged In / Discharging), time remaining / time to full
- Health percentage bar with cycle count
- Raw mAh values: current capacity, max capacity, design capacity
- Voltage (mV), current (mA), power draw (W) estimate
- Temperature
- **Desktop hackintosh support**: falls back to direct `IOServiceGetMatchingService("AppleSmartBattery")` when `IOPowerSources` finds nothing — works even when the SMBIOS reports a desktop machine type

### Network
- All active interfaces with IPv4, IPv6, MAC address, bytes sent/received
- Live public IP lookup (via ip-api.com) with manual refresh

### Screen
- Per-display: resolution (px and pt), refresh rate, DPI/PPI, bit depth, megapixels, aspect ratio, position
- Multi-monitor virtual desktop summary
- Primary display indicator

### OS
- macOS version with codename lookup (Monterey → Tahoe)
- **SIP status** — fully enabled / partially disabled with per-flag breakdown (11 flags: Kext Signing, Filesystem, DTrace, NVRAM, Unauthenticated Root, etc.) decoded from NVRAM `csr-active-config`
- **FileVault** status
- **Gatekeeper** status
- **Secure Boot** level (Apple Silicon, via `bputil`)
- Boot arguments, Board ID, Platform UUID, Serial Number
- Computer name, hostname, user, shell, timezone, locale

### Hackintosh Detection
- Confidence score (0–100) with verdict badge
- **OpenCore** NVRAM key detection (+90 pts)
- **Clover** NVRAM key detection (+85 pts)
- **AMD CPU vendor** check (+90 pts — Apple has never shipped AMD CPUs)
- Loaded kext scan: VirtualSMC, FakeSMC, Lilu, AppleALC, WhateverGreen, IntelMausi, AirportItlwm, BrcmPatchRAM, NVMeFix, RestrictEvents
- Suspicious boot argument detection (`alcid=`, `agdpmod=`, `shikigva=`, `-wegnoegpu`, etc.)
- Serial number validity check
- Partial SIP disable detection
- Apple Silicon automatically caps confidence at 5 (genuine Apple hardware)
- Verdict: **Genuine Mac** / **Suspicious** / **Likely Hackintosh** / **Hackintosh Detected**

### Info
- OS name, version, build, kernel version, architecture
- Machine model, CPU vendor and model, RAM total, swap total, process count
- Serial number, uptime

### About
- Adjustable refresh interval (0.5 s – 10 s) via slider
- Live CPU / RAM readout in sidebar

---

## OS Compatibility

| macOS | Version | Cards | Sparkline | Feature Flags | Sidebar | Window |
|---|---|---|---|---|---|---|
| 12 Monterey | 2021 | Flat colored | Path/GeometryReader | Adaptive grid | Dark material | — |
| 13 Ventura | 2022 | `.regularMaterial` | Swift Charts | Wrapping FlowLayout | `.ultraThinMaterial` | — |
| 14 Sonoma | 2023 | `.regularMaterial` | Swift Charts | Wrapping FlowLayout | `.ultraThinMaterial` | Numeric transitions |
| 15 Sequoia | 2024 | `.regularMaterial` | Swift Charts | Wrapping FlowLayout | `.ultraThinMaterial` | — |
| 26 Tahoe | 2025 | **Liquid Glass** `.glassEffect()` | Swift Charts | Wrapping FlowLayout | `.ultraThinMaterial` | `containerBackground` glass |

Minimum deployment target: **macOS 12.0**. Supports every Mac from 2015 onward.

---

## Installation

### Download (pre-built)

1. Download `cpuY.zip` from [Releases](../../releases)
2. Unzip and move `cpuY.app` to `/Applications`
3. **First launch:** right-click → **Open** → click **Open** in the Gatekeeper dialog (required once because the app is not notarized)
   - Alternatively: `xattr -dr com.apple.quarantine /Applications/cpuY.app`

### Build from source

**Requirements:**
- Xcode 16 or later
- macOS 12.0+ deployment target (set in project)

```bash
git clone https://github.com/cpuY-team/CpuY-MacOS
cd cpuY

xcodebuild \
  -project cpuY.xcodeproj \
  -scheme cpuY \
  -configuration Release \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  build
```

The built `.app` will be in `~/Library/Developer/Xcode/DerivedData/cpuY-*/Build/Products/Release/cpuY.app`.

Or open `cpuY.xcodeproj` in Xcode and press **⌘R**.

---

## Architecture

### Tech stack

| Layer | Technology |
|---|---|
| UI | SwiftUI (custom sidebar navigation, no TabView) |
| Charts | Swift Charts (macOS 13+), Path fallback (macOS 12) |
| State | `ObservableObject` + `@Published` (compatible with macOS 12+) |
| System data | Mach kernel APIs, IOKit, Darwin sysctls, POSIX |
| Layout | Custom `Layout`-protocol `FlowLayout` (macOS 13+), `LazyVGrid` fallback |
| Glass | `.glassEffect()` (macOS 26), `.regularMaterial` (macOS 12–25) |

### Data sources

| Data | Source |
|---|---|
| CPU usage | `host_processor_info` with per-tick delta tracking |
| CPU info | `sysctlbyname` (`hw.*`, `machdep.cpu.*`) |
| RAM | `host_statistics64` + `vm_statistics64_data_t` |
| Memory modules | `system_profiler SPMemoryDataType -json` |
| Volumes | `getmntinfo` (C API, not FileManager) |
| Battery (standard) | `IOPSCopyPowerSourcesInfo` / `IOPSCopyPowerSourcesList` |
| Battery (desktop SMBIOS) | `IOServiceGetMatchingService("AppleSmartBattery")` |
| Network interfaces | `getifaddrs` (IP, MAC, byte counters) |
| Displays | `NSScreen.screens` + `CGDisplayCopyDisplayMode` (main thread) |
| Physical disks | `diskutil` shell |
| OS / security info | `csrutil`, `fdesetup`, `spctl`, `nvram`, IOKit `IOPlatformExpertDevice` |
| Hackintosh detection | NVRAM keys, `kextstat`, `sysctlbyname("machdep.cpu.vendor")`, boot args |
| Public IP | `curl ip-api.com/json (JSON, `query` field)` |
| Computer name | `SCDynamicStoreCopyComputerName` |

### File structure

```
cpuY/
├── cpuYApp.swift          Entry point, @StateObject, WindowGroup
├── ContentView.swift      Custom sidebar + content router
├── SystemMonitor.swift    ObservableObject, all data models, all fetching
├── Helpers.swift          Theme, formatters, CardView, SparklineView, UsageBar, etc.
├── CPUView.swift          CPU tab
├── RAMView.swift          RAM tab
├── StorageView.swift      Storage tab
├── BatteryView.swift      Battery tab
├── NetworkView.swift      Network tab
├── ScreenView.swift       Screen tab
├── OSView.swift           OS + hackintosh detection tab
├── InfoView.swift         System info tab
└── AboutView.swift        About + refresh interval slider
```

All files are auto-included via Xcode's `PBXFileSystemSynchronizedRootGroup` — no need to manually add new `.swift` files to the project.

---

## Privacy

cpuY reads system information locally and does not transmit any data except for a single outbound request to `ip-api.com` to display your public IP address (Network tab). No analytics, no telemetry, no background processes after the app is closed.

The app is **not sandboxed** — sandboxing would block the shell-based data sources (`diskutil`, `nvram`, `kextstat`, `system_profiler`, etc.) needed for deep system info.

---

## Credits

- Original iOS app: **nat649** — [github.com/nat649/cpuY-iOS](https://github.com/nat649/cpuY-iOS)
- Built with SwiftUI, Swift Charts, Mach, IOKit, Darwin, SystemConfiguration

---

## License

MIT — see [LICENSE](LICENSE) for details.
