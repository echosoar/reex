# Reex - Remote Execute Command

A SwiftUI-based macOS application for managing and executing commands in different folders with remote task monitoring capabilities.

## Features

### 1. Folder Management
- **Folder List View**: Main interface showing all configured folders
- **Add/Remove Folders**: Easy folder management with file browser integration
- Each folder maintains its own set of commands and execution history

### 2. Command Management
- **Command List**: Each folder has a list of executable commands
- **Command Properties**:
  - Name: Human-readable command identifier
  - CMD: The actual shell command to execute
- **Placeholder Support**: Use `{placeholder_name}` syntax in commands
  - Example: `echo "Hello {name}"` 
  - UI automatically generates input fields for placeholders
- **One-Click Execution**: Execute button for each command

### 3. Command Execution
- **Process Isolation**: Each command runs in a new process
- **Shell Selection**: Choose between `/bin/bash`, `/bin/sh`, or `/bin/zsh`
- **Working Directory**: Commands execute in the folder's directory
- **Real-time Output**: Capture both stdout and stderr
- **Exit Code Tracking**: Monitor command success/failure

### 4. Task Monitoring
- **Remote Task Queue**: Configure a URL to fetch pending tasks
- **Polling Interval**: Checks for new tasks every 60 seconds
- **Task Format**:
  ```json
  [
    {
      "id": "task-123",
      "name": "command-name",
      "params": {
        "placeholder1": "value1",
        "placeholder2": "value2"
      }
    }
  ]
  ```
- **Auto-Execution**: Automatically executes the latest unprocessed task
- **Duplicate Prevention**: Tracks executed tasks to avoid re-execution

### 5. Execution Records
- **History Tracking**: All command executions are logged
- **Record Details**:
  - Command name and full resolved command
  - Execution output (stdout + stderr)
  - Exit code (success/failure indicator)
  - Timestamp
  - Associated task ID (if from remote monitoring)
- **Record Viewer**: Detailed view of each execution with copy functionality
- **Persistent Storage**: Records saved using UserDefaults

### 6. Upload Results
- **POST Endpoint**: Configure a URL to upload execution results
- **Upload Format**:
  ```json
  {
    "id": "task-123",
    "output": "command output...",
    "exitCode": 0,
    "timestamp": "2026-01-15T05:30:45Z"
  }
  ```
- **Automatic Upload**: Results uploaded after command execution (when URL configured)

## Architecture

### Models
- **Folder**: Container for commands and configuration
- **Command**: Individual executable command with placeholder support
- **ExecutionRecord**: Log entry for command execution
- **RemoteTask**: Task structure from monitoring endpoint

### Services
- **TaskMonitorService**: Handles remote task polling and execution
- **CommandExecutor**: Manages process creation and execution

### Views
- **FolderListView**: Main folder management interface
- **FolderDetailView**: Folder settings and command management
- **CommandRowView**: Individual command with execute functionality
- **ExecutionRecordView**: Execution history viewer

## Requirements

- macOS 13.0 or later
- Xcode 15.0 or later
- Swift 5.9 or later

## Security

The app uses sandboxing with the following entitlements:
- User-selected file read/write access
- Network client (for remote task monitoring and result uploads)

## Usage

1. **Add a Folder**: Click "Add Folder" and select a directory
2. **Configure Commands**: Enter folder settings and add commands with placeholders
3. **Execute Commands**: Fill in placeholder values and click execute
4. **Setup Monitoring** (Optional): Configure task monitor URL for remote execution
5. **Upload Results** (Optional): Configure upload URL to send execution results

## Building

Open `Reex/Reex.xcodeproj` in Xcode and build for macOS.

```bash
cd Reex
xcodebuild -project Reex.xcodeproj -scheme Reex -configuration Release
```

## Data Storage

- Folder configurations: Stored in UserDefaults under key "folders"
- Execution records: Stored per folder in UserDefaults with key "records_{folder-id}"
