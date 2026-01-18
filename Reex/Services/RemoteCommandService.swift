import Foundation

struct RemoteCommand: Codable {
    let id: Int
    let commandName: String
    let arguments: [String: String]
}

struct RemoteCommandResponse: Codable {
    let list: [RemoteCommand]
}

@MainActor
class RemoteCommandService: ObservableObject {
    private var timer: Timer?
    private var executedRemoteIds: Set<Int> = []
    
    func startPolling(for folder: Folder, executionRecords: [ExecutionRecord], onCommandExecuted: @escaping (ExecutionRecord) -> Void) {
        stopPolling()
        
        // Load already executed remote command IDs from existing records
        executedRemoteIds = Set(executionRecords.compactMap { $0.remoteCommandId })
        
        // Poll immediately on start
        pollRemoteCommands(for: folder, onCommandExecuted: onCommandExecuted)
        
        // Then poll every minute
        timer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            self?.pollRemoteCommands(for: folder, onCommandExecuted: onCommandExecuted)
        }
    }
    
    func stopPolling() {
        timer?.invalidate()
        timer = nil
    }
    
    private func pollRemoteCommands(for folder: Folder, onCommandExecuted: @escaping (ExecutionRecord) -> Void) {
        guard let urlString = folder.remoteCommandUrl,
              !urlString.isEmpty,
              let url = URL(string: urlString) else {
            return
        }
        
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                let response = try JSONDecoder().decode(RemoteCommandResponse.self, from: data)
                
                // Process only the first command in the list if it hasn't been executed
                if let remoteCommand = response.list.first,
                   !executedRemoteIds.contains(remoteCommand.id) {
                    await executeRemoteCommand(remoteCommand, for: folder, onCommandExecuted: onCommandExecuted)
                }
            } catch {
                print("Failed to fetch or parse remote commands: \(error)")
            }
        }
    }
    
    private func executeRemoteCommand(_ remoteCommand: RemoteCommand, for folder: Folder, onCommandExecuted: @escaping (ExecutionRecord) -> Void) async {
        // Find matching command by name
        guard let command = folder.commands.first(where: { $0.name == remoteCommand.commandName }) else {
            print("Command not found: \(remoteCommand.commandName)")
            return
        }
        
        // Resolve command with arguments
        let resolvedCmd = command.resolve(placeholders: remoteCommand.arguments)
        
        // Start accessing security-scoped resource
        let accessGranted = folder.startAccessingSecurityScopedResource()
        defer {
            if accessGranted {
                folder.stopAccessingSecurityScopedResource()
            }
        }
        
        // Execute the command
        let executor = CommandExecutor(shellPath: folder.shellPath, workingDirectory: folder.path)
        let result = await executor.execute(command: resolvedCmd)
        
        // Create execution record
        let record = ExecutionRecord(
            commandName: command.name,
            command: resolvedCmd,
            output: result.output,
            exitCode: result.exitCode,
            remoteCommandId: remoteCommand.id,
            isRemote: true
        )
        
        // Mark this ID as executed
        executedRemoteIds.insert(remoteCommand.id)
        
        // Notify about the execution
        await MainActor.run {
            onCommandExecuted(record)
        }
    }
}
