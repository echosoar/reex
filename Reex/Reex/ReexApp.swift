import SwiftUI

@main
struct ReexApp: App {
    @StateObject private var taskMonitor = TaskMonitorService()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(taskMonitor)
                .frame(minWidth: 800, minHeight: 600)
        }
    }
}
