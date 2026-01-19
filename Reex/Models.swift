import Foundation

struct Folder: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var path: String
    var commands: [Command]
    var shellPath: String
    var bookmarkData: Data?
    var remoteCommandUrl: String?
    
    init(id: UUID = UUID(), name: String, path: String, commands: [Command] = [], shellPath: String = "/bin/bash", bookmarkData: Data? = nil, remoteCommandUrl: String? = nil) {
        self.id = id
        self.name = name
        self.path = path
        self.commands = commands
        self.shellPath = shellPath
        self.bookmarkData = bookmarkData
        self.remoteCommandUrl = remoteCommandUrl
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Folder, rhs: Folder) -> Bool {
        // Folder identity should be determined by `id` only. Using other fields
        // for equality breaks selection and binding semantics in SwiftUI (the
        // List/Selection uses equality to identify items). Keep equality simple
        // so selection continues to map to the correct folder.
        return lhs.id == rhs.id
    }
    
    // Helper to access the directory with security-scoped bookmark
    func accessSecurityScopedResource() -> URL? {
        guard let bookmarkData = bookmarkData else {
            return URL(fileURLWithPath: path)
        }
        
        var isStale = false
        guard let url = try? URL(resolvingBookmarkData: bookmarkData,
                                  options: .withSecurityScope,
                                  relativeTo: nil,
                                  bookmarkDataIsStale: &isStale) else {
            return URL(fileURLWithPath: path)
        }
        
        return url
    }
    
    func startAccessingSecurityScopedResource() -> Bool {
        guard let url = accessSecurityScopedResource() else { return false }
        return url.startAccessingSecurityScopedResource()
    }
    
    func stopAccessingSecurityScopedResource() {
        guard let url = accessSecurityScopedResource() else { return }
        url.stopAccessingSecurityScopedResource()
    }
}

struct Command: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var cmd: String
    
    init(id: UUID = UUID(), name: String, cmd: String) {
        self.id = id
        self.name = name
        self.cmd = cmd
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Command, rhs: Command) -> Bool {
        lhs.id == rhs.id &&
        lhs.name == rhs.name &&
        lhs.cmd == rhs.cmd
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
    var remoteCommandId: Int?
    var isRemote: Bool
    
    init(id: UUID = UUID(), commandName: String, command: String, output: String, timestamp: Date = Date(), exitCode: Int32 = 0, remoteCommandId: Int? = nil, isRemote: Bool = false) {
        self.id = id
        self.commandName = commandName
        self.command = command
        self.output = output
        self.timestamp = timestamp
        self.exitCode = exitCode
        self.remoteCommandId = remoteCommandId
        self.isRemote = isRemote
    }
}
