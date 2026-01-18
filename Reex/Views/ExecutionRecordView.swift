import SwiftUI

struct ExecutionRecordRow: View {
    let record: ExecutionRecord
    @State private var showingDetail = false
    
    var body: some View {
        Button(action: {
            showingDetail = true
        }) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(record.commandName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    if record.isRemote {
                        Image(systemName: "cloud")
                            .foregroundColor(.blue)
                            .help("Remote command")
                    }
                    
                    Spacer()
                    
                    if record.exitCode == 0 {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    } else {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                    }
                    
                    Text(formatDate(record.timestamp))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text(record.command)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Copy Output") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(record.output, forType: .string)
            }
        }
        .sheet(isPresented: $showingDetail) {
            RecordDetailView(record: record)
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
}

struct ExecutionRecordView: View {
    @Binding var records: [ExecutionRecord]
    @State private var selectedRecord: ExecutionRecord?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Execution Records")
                .font(.headline)
                .padding(.horizontal)
                .padding(.top, 8)
            
            if records.isEmpty {
                Text("No execution records yet")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(records) { record in
                    Button(action: {
                        selectedRecord = record
                    }) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(record.commandName)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                if record.isRemote {
                                    Image(systemName: "cloud")
                                        .foregroundColor(.blue)
                                        .help("Remote command")
                                }
                                
                                Spacer()
                                
                                if record.exitCode == 0 {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                } else {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.red)
                                }
                                
                                Text(formatDate(record.timestamp))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Text(record.command)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("Copy Output") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(record.output, forType: .string)
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
        .sheet(item: $selectedRecord) { record in
            RecordDetailView(record: record)
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
}

struct RecordDetailView: View {
    let record: ExecutionRecord
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Execution Details")
                    .font(.headline)
                
                Spacer()
                
                Button("Close") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }
            
            Divider()
            
            Group {
                LabeledContent("Command Name", value: record.commandName)
                LabeledContent("Exit Code", value: "\(record.exitCode)")
                LabeledContent("Timestamp", value: formatDate(record.timestamp))
                
                if record.isRemote {
                    LabeledContent("Source", value: "Remote Command")
                    if let remoteId = record.remoteCommandId {
                        LabeledContent("Remote ID", value: "\(remoteId)")
                    }
                }
                
                VStack(alignment: .leading) {
                    Text("Command:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(record.command)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                }
            }
            
            VStack(alignment: .leading) {
                Text("Output:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                ScrollView {
                    Text(record.output)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                Button("Copy Output") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(record.output, forType: .string)
                }
                .padding(.top, 8)
            }
        }
        .padding(20)
        .frame(minWidth: 600, minHeight: 500)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
}
