import Foundation

struct CommandExecutor {
    let shellPath: String
    let workingDirectory: String
    
    struct ExecutionResult {
        let output: String
        let exitCode: Int32
    }
    
    func execute(command: String) async -> ExecutionResult {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let task = Process()
                task.executableURL = URL(fileURLWithPath: shellPath)
                task.arguments = ["-c", command]
                task.currentDirectoryURL = URL(fileURLWithPath: workingDirectory)
                
                let outputPipe = Pipe()
                let errorPipe = Pipe()
                task.standardOutput = outputPipe
                task.standardError = errorPipe
                
                var outputData = Data()
                var errorData = Data()
                
                outputPipe.fileHandleForReading.readabilityHandler = { handle in
                    outputData.append(handle.availableData)
                }
                
                errorPipe.fileHandleForReading.readabilityHandler = { handle in
                    errorData.append(handle.availableData)
                }
                
                do {
                    try task.run()
                    task.waitUntilExit()
                    
                    outputPipe.fileHandleForReading.readabilityHandler = nil
                    errorPipe.fileHandleForReading.readabilityHandler = nil
                    
                    outputData.append(outputPipe.fileHandleForReading.readDataToEndOfFile())
                    errorData.append(errorPipe.fileHandleForReading.readDataToEndOfFile())
                    
                    let output = String(data: outputData, encoding: .utf8) ?? ""
                    let error = String(data: errorData, encoding: .utf8) ?? ""
                    
                    let combinedOutput = output + (error.isEmpty ? "" : "\n\nErrors:\n\(error)")
                    
                    let result = ExecutionResult(
                        output: combinedOutput,
                        exitCode: task.terminationStatus
                    )
                    
                    continuation.resume(returning: result)
                } catch {
                    let result = ExecutionResult(
                        output: "Failed to execute command: \(error.localizedDescription)",
                        exitCode: -1
                    )
                    continuation.resume(returning: result)
                }
            }
        }
    }
}
