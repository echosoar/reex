import SwiftUI

struct FolderDetailView: View {
    @Binding var folder: Folder
    @State private var executionRecords: [ExecutionRecord] = []
    @State private var showingAddCommand = false
    @State private var newCommandName = ""
    @State private var newCommandCmd = ""
    @EnvironmentObject var taskMonitor: TaskMonitorService
    
    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("Folder Settings") {
                    TextField("Folder Name", text: $folder.name)
                    TextField("Folder Path", text: $folder.path)
                        .disabled(true)
                    
                    Picker("Shell Binary", selection: $folder.shellPath) {
                        Text("/bin/bash").tag("/bin/bash")
                        Text("/bin/sh").tag("/bin/sh")
                        Text("/bin/zsh").tag("/bin/zsh")
                    }
                }
                
                Section("Task Monitor") {
                    TextField("Monitor URL (optional)", text: Binding(
                        get: { folder.taskMonitorURL ?? "" },
                        set: { folder.taskMonitorURL = $0.isEmpty ? nil : $0 }
                    ))
                    
                    TextField("Upload Record URL (optional)", text: Binding(
                        get: { folder.uploadRecordURL ?? "" },
                        set: { folder.uploadRecordURL = $0.isEmpty ? nil : $0 }
                    ))
                    
                    if let monitorURL = folder.taskMonitorURL, !monitorURL.isEmpty {
                        Button("Start Monitoring") {
                            taskMonitor.startMonitoring(folder: $folder, onExecute: executeCommand)
                        }
                        .disabled(taskMonitor.isMonitoring(folderId: folder.id))
                        
                        if taskMonitor.isMonitoring(folderId: folder.id) {
                            Text("Monitoring active...")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .frame(height: 350)
            
            Divider()
            
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Commands")
                        .font(.headline)
                    Spacer()
                    Button(action: { showingAddCommand = true }) {
                        Label("Add Command", systemImage: "plus")
                    }
                }
                .padding(.horizontal)
                .padding(.top)
                
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(folder.commands) { command in
                            CommandRowView(
                                command: command,
                                folder: folder,
                                onExecute: { cmd, params in
                                    executeCommand(command: cmd, params: params, taskId: nil)
                                }
                            )
                        }
                    }
                    .padding(.horizontal)
                }
            }
            
            Divider()
            
            ExecutionRecordView(records: $executionRecords)
                .frame(height: 200)
        }
        .sheet(isPresented: $showingAddCommand) {
            AddCommandSheet(
                commandName: $newCommandName,
                commandCmd: $newCommandCmd,
                onAdd: addCommand
            )
        }
        .onAppear(perform: loadRecords)
    }
    
    private func executeCommand(command: Command, params: [String: String], taskId: String?) {
        let resolvedCmd = command.resolve(placeholders: params)
        
        Task {
            let executor = CommandExecutor(shellPath: folder.shellPath, workingDirectory: folder.path)
            let result = await executor.execute(command: resolvedCmd)
            
            let record = ExecutionRecord(
                taskId: taskId,
                commandName: command.name,
                command: resolvedCmd,
                output: result.output,
                exitCode: result.exitCode
            )
            
            await MainActor.run {
                executionRecords.insert(record, at: 0)
                saveRecords()
            }
            
            if let uploadURL = folder.uploadRecordURL, let taskId = taskId {
                await uploadRecord(record: record, to: uploadURL)
            }
        }
    }
    
    private func uploadRecord(record: ExecutionRecord, to urlString: String) async {
        guard let url = URL(string: urlString) else { return }
        
        let payload: [String: Any] = [
            "id": record.taskId ?? "",
            "output": record.output,
            "exitCode": record.exitCode,
            "timestamp": ISO8601DateFormatter().string(from: record.timestamp)
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: payload) else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        
        do {
            let (_, _) = try await URLSession.shared.data(for: request)
        } catch {
            print("Failed to upload record: \(error)")
        }
    }
    
    private func addCommand() {
        let command = Command(name: newCommandName, cmd: newCommandCmd)
        folder.commands.append(command)
        newCommandName = ""
        newCommandCmd = ""
        showingAddCommand = false
    }
    
    private func loadRecords() {
        if let data = UserDefaults.standard.data(forKey: "records_\(folder.id.uuidString)"),
           let decoded = try? JSONDecoder().decode([ExecutionRecord].self, from: data) {
            executionRecords = decoded
        }
    }
    
    private func saveRecords() {
        if let encoded = try? JSONEncoder().encode(executionRecords) {
            UserDefaults.standard.set(encoded, forKey: "records_\(folder.id.uuidString)")
        }
    }
}

struct AddCommandSheet: View {
    @Binding var commandName: String
    @Binding var commandCmd: String
    let onAdd: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Add New Command")
                .font(.headline)
            
            TextField("Command Name", text: $commandName)
                .textFieldStyle(.roundedBorder)
            
            VStack(alignment: .leading) {
                Text("Command")
                    .font(.caption)
                TextEditor(text: $commandCmd)
                    .font(.system(.body, design: .monospaced))
                    .frame(height: 100)
                    .border(Color.gray.opacity(0.3))
                
                Text("Use {placeholder} for parameters")
                    .font(.caption)
                    .foregroundColor(.secondary)
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
                .disabled(commandName.isEmpty || commandCmd.isEmpty)
            }
        }
        .padding()
        .frame(width: 500)
    }
}
