# Reex Application Architecture

## Component Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                        ReexApp (Main)                       │
│                  @StateObject TaskMonitorService            │
└──────────────────────────┬──────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                       ContentView                           │
└──────────────────────────┬──────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                     FolderListView                          │
│  • Displays folder list                                     │
│  • Add/Delete folders                                       │
│  • NavigationSplitView with detail                          │
└──────────────────────────┬──────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                   FolderDetailView                          │
│  • Folder settings (name, path, shell)                      │
│  • Task monitor configuration                               │
│  • Command list management                                  │
│  • Execution records display                                │
└─────────┬────────────────┴───────────────┬─────────────────┘
          │                                │
          ▼                                ▼
┌──────────────────────┐         ┌──────────────────────────┐
│  CommandRowView      │         │  ExecutionRecordView     │
│  • Display command   │         │  • List all executions   │
│  • Placeholder input │         │  • Show output details   │
│  • Execute button    │         │  • Copy functionality    │
└──────────┬───────────┘         └──────────────────────────┘
           │
           ▼
┌─────────────────────────────────────────────────────────────┐
│                   CommandExecutor Service                   │
│  • Creates new Process                                      │
│  • Sets working directory                                   │
│  • Executes command in shell                                │
│  • Captures stdout/stderr                                   │
│  • Returns output and exit code                             │
└─────────────────────────────────────────────────────────────┘
```

## Data Flow

### 1. Manual Command Execution

```
User Input → CommandRowView → FolderDetailView.executeCommand()
                                        ↓
                              CommandExecutor.execute()
                                        ↓
                              New Process (bash -c "command")
                                        ↓
                              Capture Output + Exit Code
                                        ↓
                              ExecutionRecord created
                                        ↓
                              Save to UserDefaults
                                        ↓
                              [Optional] Upload to remote URL
```

### 2. Remote Task Monitoring

```
TaskMonitorService.startMonitoring()
         ↓
Timer (every 60s) → Fetch tasks from URL
         ↓
Parse JSON → Get latest task
         ↓
Check if already executed? → No → Find matching command
         ↓                              ↓
    Ignore                    Execute with task params
                                        ↓
                              ExecutionRecord (with taskId)
                                        ↓
                              Upload result to upload URL
```

## File Structure

```
Reex/
├── Reex.xcodeproj/
│   └── project.pbxproj          # Xcode project configuration
├── Reex/
│   ├── ReexApp.swift            # App entry point
│   ├── ContentView.swift        # Root view
│   ├── Models.swift             # Data models
│   │   ├── Folder
│   │   ├── Command
│   │   ├── ExecutionRecord
│   │   └── RemoteTask
│   ├── Views/
│   │   ├── FolderListView.swift      # Home page
│   │   ├── FolderDetailView.swift    # Folder settings
│   │   ├── CommandRowView.swift      # Command item
│   │   └── ExecutionRecordView.swift # Execution history
│   ├── Services/
│   │   ├── TaskMonitorService.swift  # Remote monitoring
│   │   └── CommandExecutor.swift     # Command execution
│   ├── Assets.xcassets/         # App icons and colors
│   └── Reex.entitlements        # Sandbox permissions
└── README.md                    # Documentation
```

## Data Models

### Folder
```swift
{
  id: UUID
  name: String
  path: String                  // Working directory
  commands: [Command]
  taskMonitorURL: String?       // Polling endpoint
  uploadRecordURL: String?      // Result upload endpoint
  shellPath: String             // /bin/bash, /bin/sh, /bin/zsh
}
```

### Command
```swift
{
  id: UUID
  name: String
  cmd: String                   // Can contain {placeholder}
}
```

### ExecutionRecord
```swift
{
  id: UUID
  taskId: String?               // From remote task (optional)
  commandName: String
  command: String               // Resolved command
  output: String                // stdout + stderr
  timestamp: Date
  exitCode: Int32
}
```

### RemoteTask (from monitoring URL)
```json
{
  "id": "task-123",
  "name": "command-name",
  "params": {
    "placeholder1": "value1"
  }
}
```

## API Endpoints

### Task Monitor Endpoint (GET)
```
GET http://example.com/tasks

Response: [RemoteTask]
[
  {
    "id": "unique-task-id",
    "name": "command-name-in-app",
    "params": {
      "placeholder_key": "value"
    }
  }
]
```

### Upload Record Endpoint (POST)
```
POST http://example.com/upload

Body:
{
  "id": "task-id",
  "output": "command output...",
  "exitCode": 0,
  "timestamp": "2026-01-15T05:30:45Z"
}
```

## State Management

- **Folder Data**: Stored in UserDefaults with key `"folders"`
- **Execution Records**: Stored per folder with key `"records_{folderId}"`
- **Task Monitoring**: In-memory state in TaskMonitorService
- **UI State**: SwiftUI @State and @Binding

## Threading Model

- **Main Thread**: UI updates via @MainActor
- **Background Thread**: Command execution via DispatchQueue.global
- **Async Tasks**: Network requests via URLSession
- **Timers**: Task monitoring via Timer (main run loop)
- **Thread Safety**: NSLock for data collection during command execution

## Security Layers

1. **Sandboxing**: macOS App Sandbox with limited entitlements
2. **User Authorization**: Explicit folder selection required
3. **Process Isolation**: Each command in separate process
4. **Input Validation**: User controls all command definitions
5. **Network Security**: HTTPS recommended for remote endpoints
