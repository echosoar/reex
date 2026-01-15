# Security Considerations for Reex

## Overview

Reex is a macOS application that executes shell commands. This document outlines the security considerations and measures taken to ensure safe operation.

## Security Features

### 1. Sandboxing

The app runs in a sandboxed environment with restricted capabilities:
- **File Access**: Limited to user-selected files/directories only
- **Network Access**: Client-only (no server capabilities)
- **Process Execution**: Restricted to shell commands within selected directories

See `Reex/Reex.entitlements` for the complete entitlement configuration.

### 2. User Control

All potentially dangerous operations require explicit user action:
- **Folder Selection**: User must explicitly grant access to each folder
- **Command Definition**: User must manually define all commands
- **Command Execution**: User must explicitly trigger execution (or configure monitoring)
- **Remote URLs**: User must explicitly configure monitoring and upload URLs

### 3. Data Isolation

- Each command runs in a separate process
- Working directory is restricted to the selected folder
- Process output is captured and sanitized (UTF-8 encoding)

### 4. Thread Safety

- Command execution uses thread-safe data collection with NSLock
- Async operations properly managed with Swift concurrency

## Potential Risks and Mitigations

### Risk: Command Injection

**Description**: Malicious placeholders or remote task parameters could contain shell injection attacks.

**Mitigation**:
- Commands are executed via shell with `-c` flag (single command execution)
- Each command runs in an isolated process
- User has full visibility of command definitions before execution
- User controls which folders and commands are configured

**Recommendation**: Users should:
- Carefully review commands before adding them
- Only configure trusted remote monitoring URLs
- Use specific shell paths rather than system-wide PATH

### Risk: Unauthorized Command Execution

**Description**: Remote task monitoring could execute unauthorized commands.

**Mitigation**:
- Remote tasks can only trigger commands that are explicitly defined in the app
- Task name must match an existing command name exactly
- User must explicitly start monitoring for each folder
- User can stop monitoring at any time

**Recommendation**: Users should:
- Only configure monitoring URLs they control or trust
- Regularly review the execution records
- Use HTTPS URLs for remote endpoints to prevent man-in-the-middle attacks

### Risk: Information Disclosure

**Description**: Command output could contain sensitive information.

**Mitigation**:
- Output is stored locally in UserDefaults (sandboxed)
- Upload to remote endpoints only occurs if explicitly configured
- HTTPS should be used for upload endpoints

**Recommendation**: Users should:
- Use HTTPS URLs for upload endpoints
- Review upload endpoint security before configuration
- Avoid commands that output sensitive information

### Risk: Resource Exhaustion

**Description**: Long-running or resource-intensive commands could impact system performance.

**Mitigation**:
- Each command runs in a separate process (can be terminated independently)
- Button is disabled during execution to prevent rapid repeated execution
- Execution state is tracked per command

**Recommendation**: Users should:
- Test commands before adding them to production use
- Monitor system resources when executing intensive commands
- Avoid commands that run indefinitely

## Best Practices for Users

1. **Command Definition**:
   - Review all commands before adding them
   - Use specific paths rather than relying on PATH
   - Avoid commands with side effects unless intentional
   - Test commands manually before adding placeholders

2. **Remote Monitoring**:
   - Only configure URLs you control or trust
   - Use HTTPS endpoints for monitoring and upload
   - Implement authentication on your endpoints
   - Validate task parameters on the server side

3. **Folder Selection**:
   - Only grant access to folders that need command execution
   - Use dedicated folders for Reex operations when possible
   - Regularly review configured folders

4. **Execution Records**:
   - Regularly review execution history
   - Monitor for unexpected executions
   - Use exit codes to identify failed executions

## API Endpoint Security

If you're implementing the monitoring and upload endpoints:

1. **Authentication**: Implement proper authentication (API keys, OAuth, etc.)
2. **HTTPS**: Always use HTTPS to encrypt data in transit
3. **Rate Limiting**: Implement rate limiting to prevent abuse
4. **Input Validation**: Validate all task parameters before sending to Reex
5. **Access Control**: Restrict who can submit tasks
6. **Audit Logging**: Log all task submissions and executions

## Reporting Security Issues

If you discover a security vulnerability in Reex, please report it responsibly to the repository maintainers.

## Compliance

Users are responsible for ensuring their use of Reex complies with:
- Corporate security policies
- Data protection regulations (GDPR, etc.)
- Access control requirements
- Audit and logging requirements

## Disclaimer

Reex is a tool that executes user-defined commands. The security of the overall system depends on:
- The commands users choose to configure
- The remote endpoints users choose to trust
- The folders users grant access to

Users are responsible for the security implications of their configuration and usage.
