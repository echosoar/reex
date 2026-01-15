import SwiftUI

struct CommandRowView: View {
    let command: Command
    let folder: Folder
    let onExecute: (Command, [String: String]) -> Void
    
    @State private var placeholderValues: [String: String] = [:]
    @State private var isExecuting = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(command.name)
                    .font(.headline)
                
                Spacer()
                
                if !placeholders.isEmpty {
                    Button("Execute") {
                        executeCommand()
                    }
                    .disabled(isExecuting || !allPlaceholdersFilled)
                } else {
                    Button("Execute") {
                        executeCommand()
                    }
                    .disabled(isExecuting)
                }
            }
            
            Text(command.cmd)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
                .lineLimit(2)
            
            if !placeholders.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(placeholders, id: \.self) { placeholder in
                        HStack {
                            Text("{\(placeholder)}")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 100, alignment: .trailing)
                            
                            TextField("Value", text: Binding(
                                get: { placeholderValues[placeholder] ?? "" },
                                set: { placeholderValues[placeholder] = $0 }
                            ))
                            .textFieldStyle(.roundedBorder)
                            .font(.caption)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
    
    private var placeholders: [String] {
        command.placeholders()
    }
    
    private var allPlaceholdersFilled: Bool {
        placeholders.allSatisfy { placeholder in
            !(placeholderValues[placeholder] ?? "").isEmpty
        }
    }
    
    private func executeCommand() {
        isExecuting = true
        onExecute(command, placeholderValues)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isExecuting = false
        }
    }
}
