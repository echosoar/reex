import Foundation
import SwiftUI

class TaskMonitorService: ObservableObject {
    @Published private(set) var activeFolders: Set<UUID> = []
    private var timers: [UUID: Timer] = [:]
    private var lastExecutedTasks: [UUID: String] = [:]
    
    func startMonitoring(folder: Binding<Folder>, onExecute: @escaping (Command, [String: String], String?) -> Void) {
        let folderId = folder.wrappedValue.id
        
        guard !activeFolders.contains(folderId) else { return }
        guard let monitorURL = folder.wrappedValue.taskMonitorURL, !monitorURL.isEmpty else { return }
        
        activeFolders.insert(folderId)
        
        let timer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            Task {
                await self?.checkTasks(folder: folder, onExecute: onExecute)
            }
        }
        
        timers[folderId] = timer
        
        Task {
            await checkTasks(folder: folder, onExecute: onExecute)
        }
    }
    
    func stopMonitoring(folderId: UUID) {
        activeFolders.remove(folderId)
        timers[folderId]?.invalidate()
        timers.removeValue(forKey: folderId)
        lastExecutedTasks.removeValue(forKey: folderId)
    }
    
    func isMonitoring(folderId: UUID) -> Bool {
        activeFolders.contains(folderId)
    }
    
    private func checkTasks(folder: Binding<Folder>, onExecute: @escaping (Command, [String: String], String?) -> Void) async {
        guard let urlString = folder.wrappedValue.taskMonitorURL,
              let url = URL(string: urlString) else { return }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let tasks = try JSONDecoder().decode([RemoteTask].self, from: data)
            
            guard let latestTask = tasks.first else { return }
            
            let folderId = folder.wrappedValue.id
            if lastExecutedTasks[folderId] == latestTask.id {
                return
            }
            
            if let command = folder.wrappedValue.commands.first(where: { $0.name == latestTask.name }) {
                await MainActor.run {
                    onExecute(command, latestTask.params, latestTask.id)
                }
                lastExecutedTasks[folderId] = latestTask.id
            }
        } catch {
            print("Failed to fetch tasks: \(error)")
        }
    }
}
