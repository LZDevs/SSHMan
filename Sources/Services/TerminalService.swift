import AppKit
import Foundation
import os

private let logger = Logger(subsystem: "com.lzdevs.sshvault", category: "terminal")

/// Launches SSH connections in configurable terminal applications
struct TerminalService {
    private static let prefs = TerminalPreferences.shared

    static let defaultSSHPort = 22

    /// Shell-escape a string for safe use in sh -c
    private static func shellEscape(_ s: String) -> String {
        "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    /// Expand ~ to the full home directory path
    private static func expandTilde(_ path: String) -> String {
        if path.hasPrefix("~/") {
            return FileManager.default.homeDirectoryForCurrentUser.path + String(path.dropFirst(1))
        }
        return path
    }

    /// Launch an SSH connection using the resolved terminal for this host
    static func connect(to host: SSHHost) {
        var cmd = "ssh"
        if !host.identityFile.isEmpty {
            cmd += " -i \(shellEscape(expandTilde(host.identityFile)))"
        }
        if let port = host.port, port != Self.defaultSSHPort {
            cmd += " -p \(port)"
        }
        if host.forwardAgent {
            cmd += " -A"
        }
        if !host.proxyJump.isEmpty {
            cmd += " -J \(shellEscape(host.proxyJump))"
        }
        let target: String
        if !host.user.isEmpty {
            target = "\(host.user)@\(host.hostName)"
        } else {
            target = host.hostName
        }
        cmd += " \(shellEscape(target))"

        if host.sshInitPath && !host.sftpPath.isEmpty {
            cmd += " -t \(shellEscape("cd \(host.sftpPath) && exec $SHELL -l"))"
        }

        let terminal = prefs.resolvedTerminal(for: host.host)
        let customPath = prefs.resolvedCustomPath(for: host.host)
        launchTerminal(shellCommand: cmd, using: terminal, customAppPath: customPath)
    }

    /// Open an SFTP connection in the system's preferred SFTP app via URL scheme.
    /// Uses the SSH config alias so apps like Transmit can match it against
    /// ~/.ssh/config and inherit identity files, proxy settings, etc.
    static func openSFTP(to host: SSHHost) {
        let path = host.sftpPath.isEmpty ? "" : "/\(host.sftpPath)"
        guard let url = URL(string: "sftp://\(host.host)\(path)") else {
            logger.warning("Failed to build SFTP URL for \(host.displayName)")
            return
        }
        NSWorkspace.shared.open(url)
    }

    /// Launch an interactive SFTP session to the host
    static func sftpBrowse(to host: SSHHost) {
        var cmd = "sftp"
        if !host.identityFile.isEmpty {
            cmd += " -i \(shellEscape(expandTilde(host.identityFile)))"
        }
        if let port = host.port, port != Self.defaultSSHPort {
            cmd += " -P \(port)"
        }
        if !host.proxyJump.isEmpty {
            cmd += " -J \(shellEscape(host.proxyJump))"
        }
        let target: String
        if !host.user.isEmpty {
            target = "\(host.user)@\(host.hostName)"
        } else {
            target = host.hostName
        }
        cmd += " \(shellEscape(target))"

        let terminal = prefs.resolvedTerminal(for: host.host)
        let customPath = prefs.resolvedCustomPath(for: host.host)
        launchTerminal(shellCommand: cmd, using: terminal, customAppPath: customPath)
    }

    /// Run ssh-copy-id to push a public key to the host
    static func copyKeyToHost(_ host: SSHHost, keyPath: String) {
        let fullPath = expandTilde(keyPath)
        var cmd = "ssh-copy-id"
        cmd += " -i \(shellEscape(fullPath))"
        if let port = host.port, port != Self.defaultSSHPort {
            cmd += " -p \(port)"
        }
        let target: String
        if !host.user.isEmpty {
            target = "\(host.user)@\(host.hostName)"
        } else {
            target = host.hostName
        }
        cmd += " \(shellEscape(target))"

        let terminal = prefs.resolvedTerminal(for: host.host)
        let customPath = prefs.resolvedCustomPath(for: host.host)
        launchTerminal(shellCommand: cmd, using: terminal, customAppPath: customPath)
    }

    /// Launch a shell command in the specified terminal app
    private static func launchTerminal(shellCommand: String, using terminal: TerminalApp, customAppPath: String = "") {
        switch terminal {
        case .ghostty:
            // Set TERM=xterm-256color so remote servers don't need the xterm-ghostty terminfo
            launchDirectBinary(
                binPath: TerminalApp.ghostty.appPath + "/Contents/MacOS/ghostty",
                shellCommand: "TERM=xterm-256color " + shellCommand
            )
        case .terminal:
            launchViaAppleScript(
                script: "tell application \"Terminal\" to do script \"\(escapeAppleScript(shellCommand))\"",
                appName: "Terminal"
            )
        case .iterm2:
            launchViaAppleScript(
                script: "tell application \"iTerm2\" to create window with default profile command \"\(escapeAppleScript(shellCommand))\"",
                appName: "iTerm2"
            )
        case .custom:
            guard !customAppPath.isEmpty else {
                logger.warning("Custom terminal path not configured")
                return
            }
            guard customAppPath.hasSuffix(".app") else {
                logger.warning("Custom terminal path must end with .app")
                return
            }
            let appName = URL(fileURLWithPath: customAppPath).deletingPathExtension().lastPathComponent
            let binPath = customAppPath + "/Contents/MacOS/\(appName)"
            guard FileManager.default.fileExists(atPath: binPath) else {
                logger.warning("Custom terminal binary not found at expected path")
                return
            }
            launchDirectBinary(binPath: binPath, shellCommand: shellCommand)
        }
    }

    /// Launch a terminal via direct binary execution (Ghostty-style: binary -e /bin/sh -c "cmd")
    private static func launchDirectBinary(binPath: String, shellCommand: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: binPath)
        process.arguments = ["-e", "/bin/sh", "-c", shellCommand]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            logger.error("Failed to launch terminal: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Launch a terminal via AppleScript (Terminal.app, iTerm2)
    private static func launchViaAppleScript(script: String, appName: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            logger.error("Failed to launch \(appName, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Escape a string for safe embedding in AppleScript double-quoted strings
    private static func escapeAppleScript(_ s: String) -> String {
        // Strip control characters that could break out of AppleScript strings
        let cleaned = s.unicodeScalars.filter { $0.value >= 32 || $0 == "\t" }
            .map { String($0) }.joined()
        return cleaned
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
