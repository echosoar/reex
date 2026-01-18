import SwiftUI

struct FolderDetailView: View {
    @Binding var folder: Folder
    @State private var executionRecords: [ExecutionRecord] = []
    @State private var showingAddCommand = false
    @State private var newCommandName = ""
    @State private var newCommandCmd = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Folder settings
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
            }
            .formStyle(.grouped)
            .frame(height: 200)
            
            Divider()
            
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
                .padding(.top)
                
                ScrollView {
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
            
            // Execution records
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
    
    private func executeCommand(command: Command, params: [String: String]) {
        let resolvedCmd = command.resolve(placeholders: params)
        
        Task {
            // Start accessing security-scoped resource
            let accessGranted = folder.startAccessingSecurityScopedResource()
            defer {
                if accessGranted {
                    folder.stopAccessingSecurityScopedResource()
                }
            }
            
            let executor = CommandExecutor(shellPath: folder.shellPath, workingDirectory: folder.path)
            let result = await executor.execute(command: resolvedCmd)
            
            let record = ExecutionRecord(
                commandName: command.name,
                command: resolvedCmd,
                output: result.output,
                exitCode: result.exitCode
            )
            
            await MainActor.run {
                executionRecords.insert(record, at: 0)
                saveRecords()
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
