import Foundation

struct Folder: Identifiable, Codable {
    let id: UUID
    var name: String
    var path: String
    var commands: [Command]
    var shellPath: String
    
    init(id: UUID = UUID(), name: String, path: String, commands: [Command] = [], shellPath: String = "/bin/bash") {
        self.id = id
        self.name = name
        self.path = path
        self.commands = commands
        self.shellPath = shellPath
    }
}

struct Command: Identifiable, Codable {
    let id: UUID
    var name: String
    var cmd: String
    
    init(id: UUID = UUID(), name: String, cmd: String) {
        self.id = id
        self.name = name
        self.cmd = cmd
    }
    
    func placeholders() -> [String] {
        let pattern = "\\{([^}]+)\\}"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return []
        }
        
        let nsString = cmd as NSString
        let results = regex.matches(in: cmd, options: [], range: NSRange(location: 0, length: nsString.length))
        
        return results.compactMap { match in
            guard match.numberOfRanges > 1 else { return nil }
            let range = match.range(at: 1)
            return nsString.substring(with: range)
        }
    }
    
    func resolve(placeholders: [String: String]) -> String {
        var resolved = cmd
        for (key, value) in placeholders {
            resolved = resolved.replacingOccurrences(of: "{\(key)}", with: value)
        }
        return resolved
    }
}

struct ExecutionRecord: Identifiable, Codable {
    let id: UUID
    var commandName: String
    var command: String
    var output: String
    var timestamp: Date
    var exitCode: Int32
    
    init(id: UUID = UUID(), commandName: String, command: String, output: String, timestamp: Date = Date(), exitCode: Int32 = 0) {
        self.id = id
        self.commandName = commandName
        self.command = command
        self.output = output
        self.timestamp = timestamp
        self.exitCode = exitCode
    }
}
