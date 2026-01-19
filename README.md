# Reex - Remote Execute Command

A SwiftUI-based macOS application for managing and executing commands in different folders.

## Features

- **Folder Management**: Add folders to manage commands for different projects
- **Command Execution**: Define commands with placeholders like `{name}` for dynamic values
- **Execution History**: View all command executions with timestamps and output
- **Shell Selection**: Choose between /bin/bash, /bin/sh, or /bin/zsh
- **Process Isolation**: Each command runs in a separate process

## Building

```bash
xcodebuild -project Reex.xcodeproj -scheme Reex -configuration Release

~/Library/Developer/Xcode/DerivedData/Reex-*/Build/Products/Release/Reex.app/Contents/MacOS/Reex
```

## Requirements

- macOS 13.0 or later
- Xcode 15.0 or later

