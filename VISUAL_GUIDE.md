# Reex Visual Guide

## App Interface Mockup

```
┌────────────────────────────────────────────────────────────────────────┐
│  Reex                                                          ● ● ●   │
├─────────────────────┬──────────────────────────────────────────────────┤
│  Folders            │  Folder Detail: My Project                       │
│                     │                                                  │
│  📁 My Project      │  ┌─────────────────────────────────────────────┐│
│  📁 Web Server      ││  │ Folder Settings                             ││
│  📁 Scripts         ││  │                                             ││
│                     ││  │ Folder Name: My Project                     ││
│  [+ Add Folder]     ││  │ Folder Path: /Users/me/projects/myproject   ││
│                     ││  │ Shell Binary: /bin/bash ▼                   ││
│                     ││  │                                             ││
│                     ││  │ Monitor URL: http://localhost:8080/tasks    ││
│                     ││  │ Upload URL: http://localhost:8080/upload    ││
│                     ││  │                                             ││
│                     ││  │ [Start Monitoring]  ⦿ Monitoring active...  ││
│                     ││  └─────────────────────────────────────────────┘│
│                     │                                                  │
│                     │  Commands                        [+ Add Command] │
│                     │                                                  │
│                     │  ┌────────────────────────────────────────────┐ │
│                     │  │ Build Project                  [Execute]   │ │
│                     │  │ npm run build                              │ │
│                     │  └────────────────────────────────────────────┘ │
│                     │                                                  │
│                     │  ┌────────────────────────────────────────────┐ │
│                     │  │ Deploy to Environment         [Execute]    │ │
│                     │  │ ./deploy.sh {environment}                  │ │
│                     │  │ {environment}: [production____]            │ │
│                     │  └────────────────────────────────────────────┘ │
│                     │                                                  │
│                     │  ┌────────────────────────────────────────────┐ │
│                     │  │ Run Tests                     [Execute]    │ │
│                     │  │ npm test -- {test_file}                    │ │
│                     │  │ {test_file}: [app.test.js__]               │ │
│                     │  └────────────────────────────────────────────┘ │
│                     │                                                  │
│                     ├──────────────────────────────────────────────────┤
│                     │  Execution Records                               │
│                     │                                                  │
│                     │  ✅ Deploy to Environment  Jan 15 5:30 PM       │
│                     │     ./deploy.sh production  Task ID: task-123   │
│                     │                                                  │
│                     │  ✅ Build Project          Jan 15 5:25 PM       │
│                     │     npm run build                                │
│                     │                                                  │
│                     │  ❌ Run Tests              Jan 15 5:20 PM       │
│                     │     npm test -- app.test.js                     │
└─────────────────────┴──────────────────────────────────────────────────┘
```

## Add Folder Dialog

```
┌──────────────────────────────────┐
│  Add New Folder                  │
├──────────────────────────────────┤
│                                  │
│  Folder Name:                    │
│  [My Project____________]        │
│                                  │
│  Folder Path:                    │
│  [/Users/me/projects/...] [Choose...] │
│                                  │
│         [Cancel]      [Add]      │
└──────────────────────────────────┘
```

## Add Command Dialog

```
┌──────────────────────────────────────────┐
│  Add New Command                         │
├──────────────────────────────────────────┤
│                                          │
│  Command Name:                           │
│  [Deploy to Environment_______]          │
│                                          │
│  Command:                                │
│  ┌──────────────────────────────────────┐│
│  │./deploy.sh {environment}             ││
│  │cd {target_dir} && npm install        ││
│  │                                      ││
│  └──────────────────────────────────────┘│
│  Use {placeholder} for parameters        │
│                                          │
│         [Cancel]           [Add]         │
└──────────────────────────────────────────┘
```

## Execution Detail View

```
┌───────────────────────────────────────────────────────┐
│  Execution Details                          [Close]   │
├───────────────────────────────────────────────────────┤
│                                                       │
│  Command Name: Deploy to Environment                  │
│  Task ID: task-123                                    │
│  Exit Code: 0                                         │
│  Timestamp: January 15, 2026 at 5:30:45 PM          │
│                                                       │
│  Command:                                            │
│  ./deploy.sh production                              │
│                                                       │
│  Output:                                             │
│  ┌───────────────────────────────────────────────┐  │
│  │Deploying to production...                     │  │
│  │Building assets...                              │  │
│  │Uploading files...                              │  │
│  │Deployment successful!                          │  │
│  │                                                │  │
│  │                                                │  │
│  └───────────────────────────────────────────────┘  │
│                                                       │
│  [Copy Output]                                        │
└───────────────────────────────────────────────────────┘
```

## Workflow Example

### 1. Manual Execution Flow

```
User                  App                    System
  │                    │                       │
  │─── Click Execute ──>                       │
  │                    │                       │
  │                    │─── Create Process ───>│
  │                    │                       │
  │                    │<─── Output ───────────│
  │                    │                       │
  │<─── Show Result ───│                       │
  │                    │                       │
  │                    │─── Save Record ───────>UserDefaults
  │                    │                       │
  │                    │─── Upload Result ─────>Remote Server
```

### 2. Remote Task Flow

```
Remote Server         App                    System
  │                    │                       │
  │<─── Poll Tasks ────│                       │
  │                    │                       │
  │─── Return Tasks ──>│                       │
  │                    │                       │
  │                    │─── Check if New ──────>Memory
  │                    │                       │
  │                    │─── Create Process ───>│
  │                    │                       │
  │                    │<─── Output ───────────│
  │                    │                       │
  │<─── Upload Result ─│                       │
```

## User Journey

### First Time Setup

1. **Open App** → See empty folder list
2. **Click "+ Add Folder"** → Choose directory
3. **Folder appears in list** → Click to open
4. **Click "+ Add Command"** → Enter name and cmd
5. **Command appears** → Click "Execute"
6. **View results** → Check execution records

### Daily Usage

1. **Open App** → See folder list
2. **Select folder** → View commands
3. **Fill placeholders** → Click "Execute"
4. **Monitor progress** → Check records

### Remote Monitoring Setup

1. **Open folder settings**
2. **Enter Monitor URL** → http://api.example.com/tasks
3. **Enter Upload URL** → http://api.example.com/upload
4. **Click "Start Monitoring"**
5. **App polls every 60 seconds**
6. **New tasks auto-execute**
7. **Results auto-upload**

## Key UI Elements

### Folder List (Sidebar)
- Shows all configured folders
- Click to select and view details
- Swipe to delete
- Button to add new folder

### Folder Detail (Main Area)
- Folder settings form
- Shell binary picker
- Task monitoring configuration
- Command list
- Add command button

### Command Row
- Command name (bold)
- Command preview (monospace)
- Placeholder input fields (if any)
- Execute button

### Execution Records
- List of all executions
- Success/failure indicators
- Timestamps
- Click to view full details

## Visual Indicators

| Symbol | Meaning              |
|--------|---------------------|
| ✅     | Successful execution |
| ❌     | Failed execution     |
| ⦿      | Monitoring active    |
| 📁     | Folder               |
| {xxx}  | Placeholder          |

## Color Scheme

- **Green**: Success states, active monitoring
- **Red**: Error states, failed executions
- **Blue**: Task IDs, links
- **Gray**: Secondary text, disabled states
- **System**: Uses macOS system colors for native feel

## Interactions

- **Single Click**: Select/Execute
- **Right Click**: Context menu (copy output)
- **Return Key**: Default action (Add/Execute)
- **Escape Key**: Cancel dialogs
- **Drag & Drop**: Not supported (use file picker)

## Accessibility

- Full keyboard navigation
- Screen reader support via SwiftUI
- High contrast mode compatible
- System font scaling supported
