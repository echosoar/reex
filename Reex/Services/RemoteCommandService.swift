import Foundation

struct RemoteCommand: Codable {
    let id: Int
    let commandName: String
    let arguments: [String: String]
    let callback: String?
}

struct RemoteCommandResponse: Codable {
    let list: [RemoteCommand]
}

@MainActor
class RemoteCommandService: ObservableObject {
    private var timer: Timer?
    private var executedRemoteIds: Set<Int> = []
    private var currentExecutor: CommandExecutor?
    private var currentRemoteCommand: RemoteCommand?
    private var currentExecutionTask: Task<Void, Never>?

    func startPolling(for folder: Folder, executionRecords: [ExecutionRecord], onCommandExecuted: @escaping (ExecutionRecord) -> Void) {
        stopPolling()

        // Load already executed remote command IDs from existing records
        executedRemoteIds = Set(executionRecords.compactMap { $0.remoteCommandId })

        // Poll immediately on start
        pollRemoteCommands(for: folder, onCommandExecuted: onCommandExecuted)

        // Then poll every minute
        timer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.pollRemoteCommands(for: folder, onCommandExecuted: onCommandExecuted)
        }
    }

    func stopPolling() {
        timer?.invalidate()
        timer = nil
        cancelCurrentTask()
    }

    private func cancelCurrentTask() {
        if let currentTask = currentExecutionTask {
            currentTask.cancel()
            currentExecutionTask = nil
        }
        if let executor = currentExecutor {
            executor.cancel()
            currentExecutor = nil
        }
        // 如果有正在执行的任务，设置超时结果
        if let remoteCommand = currentRemoteCommand {
            // 这里可以添加超时记录的处理，但需要 folder 和 callback，所以可能需要在执行时保存这些信息
            // 或者在 cancel 时传入需要的信息
        }
        currentRemoteCommand = nil
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
                print("Fetched remote commands: \(String(data: data, encoding: .utf8) ?? "")")
                print("Executed remote IDs: \(executedRemoteIds)")
                let response = try JSONDecoder().decode(RemoteCommandResponse.self, from: data)

                // Process only the first command in the list if it hasn't been executed
                if let remoteCommand = response.list.first,
                   !executedRemoteIds.contains(remoteCommand.id) {

                    // 如果有正在执行的老任务，取消它
                    if let currentTask = currentExecutionTask, currentRemoteCommand != nil {
                        print("Canceling current task (id: \(currentRemoteCommand!.id)) to execute new task (id: \(remoteCommand.id))")

                        // 取消当前执行
                        currentExecutor?.cancel()
                        currentTask.cancel()

                        // 为老任务创建超时记录
                        if let oldCommand = currentRemoteCommand {
                            let timeoutRecord = ExecutionRecord(
                                commandName: "Unknown", // 无法确定命令名称，因为可能没有保存
                                command: "",
                                output: "Execution timed out (new task arrived)",
                                exitCode: -2, // 超时退出码
                                remoteCommandId: oldCommand.id,
                                isRemote: true
                            )
                            onCommandExecuted(timeoutRecord)
                            executedRemoteIds.insert(oldCommand.id)

                            // 发送超时回调
                            if let cb = oldCommand.callback, let cbUrl = URL(string: cb) {
                                var request = URLRequest(url: cbUrl)
                                request.httpMethod = "POST"
                                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                                let body = ["output": "Execution timed out (new task arrived)"]
                                if let bodyData = try? JSONEncoder().encode(body) {
                                    request.httpBody = bodyData
                                    Task {
                                        do {
                                            let (_, _) = try await URLSession.shared.data(for: request)
                                        } catch {
                                            NSLog("Failed to POST callback: \(error)")
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // 执行新任务
                    currentRemoteCommand = remoteCommand
                    currentExecutionTask = Task {
                        await executeRemoteCommand(remoteCommand, for: folder, onCommandExecuted: onCommandExecuted)
                        // 任务执行完成后清理
                        currentExecutionTask = nil
                        currentExecutor = nil
                        currentRemoteCommand = nil
                    }
                }
            } catch {
                NSLog("Failed to fetch or parse remote commands: \(error.localizedDescription)")
            }
        }
    }

    private func executeRemoteCommand(_ remoteCommand: RemoteCommand, for folder: Folder, onCommandExecuted: @escaping (ExecutionRecord) -> Void) async {
        // Find matching command by name
        guard let command = folder.commands.first(where: { $0.name == remoteCommand.commandName }) else {
            NSLog("Command not found: \(remoteCommand.commandName)")
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
        currentExecutor = executor

        var outputText = ""
        var exitCode: Int32 = 0
        do {
            let result = await executor.execute(command: resolvedCmd)
            outputText = result.output
            exitCode = result.exitCode
        } catch {
            outputText = "Execution failed: \(error.localizedDescription)"
            exitCode = -1
        }

        // Create execution record
        let record = ExecutionRecord(
            commandName: command.name,
            command: resolvedCmd,
            output: outputText,
            exitCode: exitCode,
            remoteCommandId: remoteCommand.id,
            isRemote: true
        )

        // Mark this ID as executed
        executedRemoteIds.insert(remoteCommand.id)

        // Notify about the execution
        onCommandExecuted(record)

        // Send callback if provided
        if let cb = remoteCommand.callback, let cbUrl = URL(string: cb) {
            var request = URLRequest(url: cbUrl)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let body = ["output": outputText]
            if let bodyData = try? JSONEncoder().encode(body) {
                request.httpBody = bodyData
                Task {
                    do {
                        let (_, _) = try await URLSession.shared.data(for: request)
                    } catch {
                        NSLog("Failed to POST callback: \(error)")
                    }
                }
            }
        }
    }
}
