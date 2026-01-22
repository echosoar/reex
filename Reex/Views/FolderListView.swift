import SwiftUI

struct FolderListView: View {
    @State private var folders: [Folder] = []
    @State private var selectedFolder: Folder?
    @State private var showingAddFolder = false
    @State private var newFolderName = ""
    @State private var newFolderPath = ""
    @State private var newFolderURL: URL?
    @State private var pollingTask: Task<Void, Never>?
    @State private var currentExecutionTasks: [UUID: (task: Task<Void, Never>, executor: CommandExecutor, remoteCommand: any Codable)] = [:]

    var body: some View {
        NavigationSplitView {
            VStack {
                HStack {
                    Text("Folders")
                        .font(.headline)
                    Spacer()
                    Button(action: { showingAddFolder = true }) {
                        Label("Add Folder", systemImage: "plus")
                    }
                }
                .padding()
                
                List(selection: $selectedFolder) {
                    ForEach(folders) { folder in
                        NavigationLink(value: folder) {
                            VStack(alignment: .leading) {
                                Text(folder.name)
                                    .font(.headline)
                                Text(folder.path)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .contextMenu {
                            Button("Delete", role: .destructive) {
                                deleteFolder(folder)
                            }
                        }
                    }
                    .onDelete(perform: deleteFolders)
                }
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 250)
        } detail: {
            if let folder = selectedFolder {
                FolderDetailView(folder: binding(for: folder))
                    .id(folder.id)  // Force view recreation when folder changes
            } else {
                Text("Select a folder")
                    .foregroundColor(.secondary)
            }
        }
        .sheet(isPresented: $showingAddFolder) {
            AddFolderSheet(
                folderName: $newFolderName,
                folderPath: $newFolderPath,
                folderURL: $newFolderURL,
                onAdd: {
                    addFolder(url: newFolderURL)
                }
            )
        }
        .onChange(of: folders) { newFolders in
            // Update selectedFolder if it exists in the new folders array
            if let selectedFolder = selectedFolder,
               let updatedFolder = newFolders.first(where: { $0.id == selectedFolder.id }) {
                self.selectedFolder = updatedFolder
            }
        }
        .onAppear {
            loadFolders()
            startPollingRemoteConfigs()
        }
        .onDisappear {
            stopPollingRemoteConfigs()
        }
    }
    
    private func binding(for folder: Folder) -> Binding<Folder> {
        guard let index = folders.firstIndex(where: { $0.id == folder.id }) else {
            return .constant(folder)
        }
        return Binding(
            get: {
                self.folders[index]
            },
            set: { newValue in
                print("[binding.set] Updating folder \(newValue.name) at index \(index)")
                print("[binding.set] Old commands count: \(self.folders[index].commands.count)")
                print("[binding.set] New commands count: \(newValue.commands.count)")
                print("[binding.set] New commands: \(newValue.commands.map { "\($0.name): \($0.cmd)" })")

                // 正确更新数组的方法：先复制整个数组，更新指定位置，再赋值回去
                var updatedFolders = self.folders
                updatedFolders[index] = newValue

                // 直接使用更新后的数组保存，而不是依赖 self.folders（因为状态更新是异步的）
                self.saveFolders(folders: updatedFolders)

                // 然后再更新状态
                self.folders = updatedFolders

                // 同时更新 selectedFolder，确保状态同步
                if self.selectedFolder?.id == newValue.id {
                    self.selectedFolder = newValue
                }

                // Verify save
                if let data = UserDefaults.standard.data(forKey: "folders"),
                   let decoded = try? JSONDecoder().decode([Folder].self, from: data),
                   let savedFolder = decoded.first(where: { $0.id == newValue.id }) {
                    print("[binding.set] Saved commands count: \(savedFolder.commands.count)")
                    print("[binding.set] Saved commands: \(savedFolder.commands.map { "\($0.name): \($0.cmd)" })")
                } else {
                    print("[binding.set] Failed to decode saved folders")
                }
            }
        )
    }
    
    private func addFolder(url: URL?) {
        var bookmarkData: Data?
        if let url = url {
            do {
                bookmarkData = try url.bookmarkData(options: .withSecurityScope,
                                                   includingResourceValuesForKeys: nil,
                                                   relativeTo: nil)
            } catch {
                print("Failed to create bookmark: \(error)")
            }
        }
        
        let folder = Folder(name: newFolderName, path: newFolderPath, bookmarkData: bookmarkData)
        folders.append(folder)
        saveFolders()
        newFolderName = ""
        newFolderPath = ""
        newFolderURL = nil
        showingAddFolder = false
    }
    
    private func executionRecordsKey(for folder: Folder) -> String {
        return "records_\(folder.id.uuidString)"
    }
    
    private func deleteFolder(_ folder: Folder) {
        // Remove execution records from UserDefaults
        UserDefaults.standard.removeObject(forKey: executionRecordsKey(for: folder))
        
        // Remove the folder
        if let index = folders.firstIndex(where: { $0.id == folder.id }) {
            folders.remove(at: index)
            saveFolders()
            
            // Clear selection if the deleted folder was selected
            if selectedFolder?.id == folder.id {
                selectedFolder = nil
            }
        }
    }
    
    private func deleteFolders(at offsets: IndexSet) {
        // Check if selected folder will be deleted
        let willDeleteSelected = offsets.contains(where: { index in
            folders[index].id == selectedFolder?.id
        })
        
        // Remove execution records for each folder being deleted
        for index in offsets {
            let folder = folders[index]
            UserDefaults.standard.removeObject(forKey: executionRecordsKey(for: folder))
        }
        
        folders.remove(atOffsets: offsets)
        saveFolders()
        
        // Clear selection if the deleted folder was selected
        if willDeleteSelected {
            selectedFolder = nil
        }
    }
    
    private func loadFolders() {
        if let data = UserDefaults.standard.data(forKey: "folders"),
           let decoded = try? JSONDecoder().decode([Folder].self, from: data) {
            folders = decoded
        }
    }
    
    private func saveFolders(folders: [Folder]? = nil) {
        let foldersToSave = folders ?? self.folders
        if let encoded = try? JSONEncoder().encode(foldersToSave) {
            UserDefaults.standard.set(encoded, forKey: "folders")
        }
    }

    // MARK: - Remote config polling (global)
    private func startPollingRemoteConfigs() {
        stopPollingRemoteConfigs()
        pollingTask = Task {
            while !Task.isCancelled {
                await pollOnce()
                try? await Task.sleep(nanoseconds: 60 * 1_000_000_000) // 60s
            }
        }
    }

    private func stopPollingRemoteConfigs() {
        pollingTask?.cancel()
        pollingTask = nil
        // 取消所有正在执行的任务
        for (_, taskInfo) in currentExecutionTasks {
            taskInfo.executor.cancel()
            taskInfo.task.cancel()
        }
        currentExecutionTasks.removeAll()
    }


    private func pollOnce() async {
        // Snapshot folders on main actor to avoid races
        let foldersSnapshot = await MainActor.run { self.folders }

        print("Polling remote commands for folders...")

        for folder in foldersSnapshot {
            print("Polling folder: \(folder.name), url: \(folder.remoteCommandUrl ?? "nil")")
            guard let urlString = folder.remoteCommandUrl, !urlString.isEmpty, let url = URL(string: urlString) else {
                continue
            }

            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                print("Fetched remote url: \(urlString), data: \(String(data: data, encoding: .utf8) ?? "")")
                struct RemoteItem: Codable { let id: Int; let commandName: String; let arguments: [String: String]?; let callback: String? }
                struct RemoteResponse: Codable { let list: [RemoteItem] }

                let decoded = try JSONDecoder().decode(RemoteResponse.self, from: data)
                guard let first = decoded.list.first else { continue }

                print("decoded remote command: id:\(first.id) commandName:\(first.commandName) arguments:\(first.arguments ?? [:]) callback:\(first.callback ?? "nil")")

                // Check if already executed
                let executedKey = "remote_executed_\(folder.id.uuidString)"
                var executed = UserDefaults.standard.array(forKey: executedKey) as? [Int] ?? []
                if executed.contains(first.id) { continue }

                // 如果该文件夹有正在执行的老任务，取消它
                let existingTaskInfo = await MainActor.run { currentExecutionTasks[folder.id] }
                if let existingTaskInfo = existingTaskInfo {
                    print("Canceling current task for folder \(folder.name) (current task id: \(String(describing: (existingTaskInfo.remoteCommand as? RemoteItem)?.id)), new task id: \(first.id))")

                    // 取消当前执行
                    existingTaskInfo.executor.cancel()
                    existingTaskInfo.task.cancel()

                    // 从 currentExecutionTasks 中移除老任务
                    await MainActor.run {
                        currentExecutionTasks.removeValue(forKey: folder.id)
                    }

                    // 为老任务创建超时记录
                    if let oldRemoteCommand = existingTaskInfo.remoteCommand as? RemoteItem {
                        let timeoutRecord = ExecutionRecord(
                            commandName: "Unknown",
                            command: "",
                            output: "Execution timed out (new task arrived)",
                            exitCode: -2, // 超时退出码
                            remoteCommandId: oldRemoteCommand.id,
                            isRemote: true
                        )
                        saveExecutionRecord(folder: folder, record: timeoutRecord)
                        executed.append(oldRemoteCommand.id)
                        UserDefaults.standard.set(executed, forKey: executedKey)
                        NotificationCenter.default.post(name: Notification.Name("executionRecordsUpdated"), object: folder.id.uuidString)

                        // 发送超时回调
                        if let cb = oldRemoteCommand.callback, let cbUrl = URL(string: cb) {
                            Task {
                                var request = URLRequest(url: cbUrl)
                                request.httpMethod = "POST"
                                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                                let body = ["output": "Execution timed out (new task arrived)"]
                                if let bodyData = try? JSONEncoder().encode(body) {
                                    do {
                                        request.httpBody = bodyData
                                        let (_, _) = try await URLSession.shared.data(for: request)
                                    } catch {
                                        print("Failed to POST callback: \(error)")
                                    }
                                }
                            }
                        }
                    }
                }

                // 执行新任务
                if let cmd = folder.commands.first(where: { $0.name == first.commandName }) {
                    let executor = CommandExecutor(shellPath: folder.shellPath, workingDirectory: folder.path)
                    let task = Task {
                        let params = first.arguments ?? [:]

                        // Start security scope if needed
                        let accessGranted = folder.startAccessingSecurityScopedResource()
                        defer {
                            if accessGranted { folder.stopAccessingSecurityScopedResource() }
                        }

                        var resultOutput = ""
                        var resultExit: Int32 = 0
                        do {
                            let result = await executor.execute(command: cmd.resolve(placeholders: params))
                            resultOutput = result.output
                            resultExit = result.exitCode
                        } catch {
                            resultOutput = "Execution failed: \(error.localizedDescription)"
                            resultExit = -1
                        }

                        // Save record
                        let record = ExecutionRecord(commandName: cmd.name, command: cmd.resolve(placeholders: params), output: resultOutput, exitCode: resultExit, remoteCommandId: first.id, isRemote: true)
                        saveExecutionRecord(folder: folder, record: record)

                        // Mark executed
                        var executed = UserDefaults.standard.array(forKey: executedKey) as? [Int] ?? []
                        executed.append(first.id)
                        UserDefaults.standard.set(executed, forKey: executedKey)

                        // Notify listeners to reload
                        NotificationCenter.default.post(name: Notification.Name("executionRecordsUpdated"), object: folder.id.uuidString)

                        // If callback provided, POST output
                        if let cb = first.callback, let cbUrl = URL(string: cb) {
                            Task {
                                var request = URLRequest(url: cbUrl)
                                request.httpMethod = "POST"
                                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                                let body = ["output": resultOutput]
                                if let bodyData = try? JSONEncoder().encode(body) {
                                    do {
                                        request.httpBody = bodyData
                                        let (_, _) = try await URLSession.shared.data(for: request)
                                    } catch {
                                        print("Failed to POST callback: \(error)")
                                    }
                                }
                            }
                        }

                        // 任务完成后移除追踪（必须在主 Actor 上执行）
                        await MainActor.run {
                            currentExecutionTasks.removeValue(forKey: folder.id)
                        }
                    }

                    // 追踪新任务（必须在主 Actor 上执行）
                    await MainActor.run {
                        currentExecutionTasks[folder.id] = (task: task, executor: executor, remoteCommand: first)
                    }
                }
            } catch {
                // ignore network/parse errors for now
                continue
            }
        }
    }

    private func saveExecutionRecord(folder: Folder, record: ExecutionRecord) {
        let key = executionRecordsKey(for: folder)
        var records: [ExecutionRecord] = []
        if let d = UserDefaults.standard.data(forKey: key), let dec = try? JSONDecoder().decode([ExecutionRecord].self, from: d) {
            records = dec
        }
        records.insert(record, at: 0)
        if let enc = try? JSONEncoder().encode(records) {
            UserDefaults.standard.set(enc, forKey: key)
            print("[saveExecutionRecord] Saved record for folder:\(folder.name) id:\(folder.id.uuidString) key:\(key) outputPreview:\(record.output.prefix(80))")
        }
    }
}

struct AddFolderSheet: View {
    @Binding var folderName: String
    @Binding var folderPath: String
    @Binding var folderURL: URL?
    let onAdd: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Add New Folder")
                .font(.headline)
            
            TextField("Folder Name", text: $folderName)
                .textFieldStyle(.roundedBorder)
            
            HStack {
                TextField("Folder Path", text: $folderPath)
                    .textFieldStyle(.roundedBorder)
                    .disabled(true)
                
                Button("Choose...") {
                    let panel = NSOpenPanel()
                    panel.canChooseFiles = false
                    panel.canChooseDirectories = true
                    panel.allowsMultipleSelection = false
                    if panel.runModal() == .OK, let url = panel.url {
                        folderURL = url
                        folderPath = url.path
                        if folderName.isEmpty {
                            folderName = url.lastPathComponent
                        }
                    }
                }
            }
            
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button("Add") {
                    onAdd()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(folderName.isEmpty || folderPath.isEmpty)
            }
        }
        .padding()
        .frame(width: 400)
    }
}

#Preview {
    FolderListView()
}
