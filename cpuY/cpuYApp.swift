import SwiftUI

@main
struct cpuYApp: App {
    @StateObject private var monitor = SystemMonitor()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(monitor)
                // Sets preferred window size on all macOS versions
                .frame(minWidth: 720, idealWidth: 820, minHeight: 580, idealHeight: 660)
        }
    }
}
