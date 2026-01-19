import SwiftUI

struct FolderDetailView: View {
    @Binding var folder: Folder
    @State private var executionRecords: [ExecutionRecord] = []
    @State private var showingAddCommand = false
    @State private var newCommandName = ""
    @State private var newCommandCmd = ""
    // Remote polling is handled centrally in FolderListView
    
    var body: some View {
        let _ = print("[FolderDetailView.body] Rendering for folder: \(folder.name) id: \(folder.id.uuidString) recordsCount: \(executionRecords.count)")
        ScrollView {
            VStack(spacing: 20) {
                // Folder settings
                VStack(alignment: .leading, spacing: 10) {
                    Text("Folder Settings")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    Form {
                        Section {
                            TextField("Folder Name", text: $folder.name)
                            TextField("Folder Path", text: $folder.path)
                                .disabled(true)
                            
                            Picker("Shell Binary", selection: $folder.shellPath) {
                                Text("/bin/bash").tag("/bin/bash")
                                Text("/bin/sh").tag("/bin/sh")
                                Text("/bin/zsh").tag("/bin/zsh")
                            }
                        }
                    }
                    .formStyle(.grouped)
                    .frame(height: 180)
                }
                
                Divider()
                    .padding(.horizontal)
                
                // Command list
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
                    
                    if folder.commands.isEmpty {
                        Text("No commands yet")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else {
                        LazyVStack(spacing: 8) {
                            ForEach(folder.commands) { command in
                                CommandRowView(
                                    command: command,
                                    folder: folder,
                                    onExecute: { cmd, params in
                                        executeCommand(command: cmd, params: params)
                                    }
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                
                Divider()
                    .padding(.horizontal)
                
                // Execution records
                VStack(alignment: .leading, spacing: 10) {
                    Text("Execution Records")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    // Remote command URL input field
                    VStack(alignment: .leading, spacing: 4) {
                        TextField("Remote Command URL (optional)", text: Binding(
                            get: { folder.remoteCommandUrl ?? "" },
                            set: { newValue in
                                var updatedFolder = folder
                                updatedFolder.remoteCommandUrl = newValue.isEmpty ? nil : newValue
                                folder = updatedFolder
                            }
                        ))
                        .textFieldStyle(.roundedBorder)
                        .padding(.horizontal)
                        
                        Text("Commands will be fetched from this URL every minute")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                    }
                    .padding(.bottom, 8)
                    
                    if executionRecords.isEmpty {
                        Text("No execution records yet")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else {
                        LazyVStack(spacing: 8) {
                            ForEach(executionRecords) { record in
                                ExecutionRecordRow(record: record)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.bottom, 20)
            }
            .padding(.top)
        }
        .sheet(isPresented: $showingAddCommand) {
            AddCommandSheet(
                commandName: $newCommandName,
                commandCmd: $newCommandCmd,
                onAdd: addCommand
            )
        }
        .onAppear {
            print("[FolderDetailView.onAppear] folder: \(folder.name) id: \(folder.id.uuidString)")
            loadRecords()
        }
        .onDisappear {
        }
        .onChange(of: folder.id) { newId in
            // When the selected folder changes, reload its records
            print("[FolderDetailView.onChange] folder.id changed to: \(newId) folder.name: \(folder.name) before loadRecords, current recordsCount: \(executionRecords.count)")
            loadRecords()
            print("[FolderDetailView.onChange] after loadRecords, new recordsCount: \(executionRecords.count)")
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("executionRecordsUpdated"))) { notification in
            // Only reload if the notification is for the current folder
            if let folderIdString = notification.object as? String,
               folderIdString == folder.id.uuidString {
                loadRecords()
            }
        }
    }
    
    private func executeCommand(command: Command, params: [String: String]) {
        let resolvedCmd = command.resolve(placeholders: params)
        
        Task {
            // Capture folder identity and working info at the start so switching folders
            // while the task runs won't cause the record to be saved under the wrong folder.
            let capturedFolderId = folder.id
            let capturedWorkingDir = folder.path
            let capturedShell = folder.shellPath

            // Start accessing security-scoped resource for the captured folder
            let accessGranted = folder.startAccessingSecurityScopedResource()
            defer {
                if accessGranted {
                    folder.stopAccessingSecurityScopedResource()
                }
            }

            let executor = CommandExecutor(shellPath: capturedShell, workingDirectory: capturedWorkingDir)
            let result = await executor.execute(command: resolvedCmd)

            let record = ExecutionRecord(
                commandName: command.name,
                command: resolvedCmd,
                output: result.output,
                exitCode: result.exitCode
            )

            // Persist the record to UserDefaults under the captured folder id
            let key = "records_\(capturedFolderId.uuidString)"
            var recordsForFolder: [ExecutionRecord] = []
            if let d = UserDefaults.standard.data(forKey: key), let dec = try? JSONDecoder().decode([ExecutionRecord].self, from: d) {
                recordsForFolder = dec
            }
            recordsForFolder.insert(record, at: 0)
            if let enc = try? JSONEncoder().encode(recordsForFolder) {
                UserDefaults.standard.set(enc, forKey: key)
                print("[executeCommand] Persisted record for capturedFolder:\(capturedFolderId.uuidString) key:\(key) command:\(command.name) outputPreview:\(record.output.prefix(80))")
            }

            // Only update this view's in-memory state if the view is still showing the same folder
            await MainActor.run {
                if folder.id == capturedFolderId {
                    executionRecords.insert(record, at: 0)
                }
            }
        }
    }
    
    private func addCommand() {
        let command = Command(name: newCommandName, cmd: newCommandCmd)
        
        // Create a new folder with the updated commands array
        var updatedFolder = folder
        updatedFolder.commands.append(command)
        
        // Assign the updated folder back to trigger the binding setter
        folder = updatedFolder
        
        newCommandName = ""
        newCommandCmd = ""
        showingAddCommand = false
    }
    
    private func loadRecords() {
        let key = "records_\(folder.id.uuidString)"
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([ExecutionRecord].self, from: data) {
            executionRecords = decoded
            print("[loadRecords] Loaded \(executionRecords.count) records for folder:\(folder.name) id:\(folder.id.uuidString)")
        } else {
            // Always clear executionRecords if no data found, to prevent showing stale data from previous folder
            executionRecords = []
            print("[loadRecords] No records found for folder:\(folder.name) id:\(folder.id.uuidString), cleared records")
        }
    }
    
    private func saveRecords() {
        if let encoded = try? JSONEncoder().encode(executionRecords) {
            let key = "records_\(folder.id.uuidString)"
            UserDefaults.standard.set(encoded, forKey: key)
            print("[saveRecords] Saved \(executionRecords.count) records for folder:\(folder.name) id:\(folder.id.uuidString) key:\(key)")
        }
    }
    
    // Polling is handled globally by FolderListView; no per-folder polling here.
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
