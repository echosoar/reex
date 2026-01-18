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
    var onClear: (() -> Void)?
    @State private var showingClearConfirmation = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Execution Records")
                    .font(.headline)

                Spacer()

                Button(role: .destructive) {
                    showingClearConfirmation = true
                } label: {
                    Label("Clear", systemImage: "trash")
                }
                .disabled(records.isEmpty)
                .help("Clear all execution records")
            }
            .padding(.horizontal)
            .padding(.top, 8)
            
            if records.isEmpty {
                Text("No execution records yet")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(records) { record in
                        ExecutionRecordRow(record: record)
                    }
                }
                .padding(.horizontal)
            }
        }
        

        .alert("Clear all records?", isPresented: $showingClearConfirmation) {
            Button("Clear", role: .destructive) {
                if let onClear = onClear {
                    onClear()
                } else {
                    records.removeAll()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to clear all execution records? This cannot be undone.")
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
