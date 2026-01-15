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
                
                // Thread-safe data collection
                let outputData = NSMutableData()
                let errorData = NSMutableData()
                let dataLock = NSLock()
                
                outputPipe.fileHandleForReading.readabilityHandler = { handle in
                    let data = handle.availableData
                    dataLock.lock()
                    outputData.append(data)
                    dataLock.unlock()
                }
                
                errorPipe.fileHandleForReading.readabilityHandler = { handle in
                    let data = handle.availableData
                    dataLock.lock()
                    errorData.append(data)
                    dataLock.unlock()
                }
                
                do {
                    try task.run()
                    task.waitUntilExit()
                    
                    outputPipe.fileHandleForReading.readabilityHandler = nil
                    errorPipe.fileHandleForReading.readabilityHandler = nil
                    
                    dataLock.lock()
                    outputData.append(outputPipe.fileHandleForReading.readDataToEndOfFile())
                    errorData.append(errorPipe.fileHandleForReading.readDataToEndOfFile())
                    dataLock.unlock()
                    
                    let output = String(data: outputData as Data, encoding: .utf8) ?? ""
                    let error = String(data: errorData as Data, encoding: .utf8) ?? ""
                    
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
