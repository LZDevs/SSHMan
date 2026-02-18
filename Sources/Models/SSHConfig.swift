import Foundation

/// Parses and writes SSH config files
struct SSHConfig {
    /// Parse an SSH config file into host entries
    static func parse(content: String) -> [SSHHost] {
        var hosts: [SSHHost] = []
        var currentHost: SSHHost?
        var pendingComment = ""

        let lines = content.components(separatedBy: .newlines)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Skip empty lines
            if trimmed.isEmpty {
                if currentHost == nil {
                    pendingComment = ""
                }
                continue
            }

            // Collect comments before a Host block
            if trimmed.hasPrefix("#") {
                if currentHost == nil {
                    if !pendingComment.isEmpty {
                        pendingComment += "\n"
                    }
                    pendingComment += trimmed
                }
                continue
            }

            // Parse key-value
            let parts = splitDirective(trimmed)
            guard let key = parts.key else { continue }

            if key.lowercased() == "host" {
                // Save previous host
                if let host = currentHost {
                    hosts.append(host)
                }
                currentHost = SSHHost(host: sanitizeAlias(parts.value))
                // Extract @label from comment if present
                let commentLines = pendingComment.components(separatedBy: "\n")
                let labelLine = commentLines.first { $0.hasPrefix("# @label ") }
                if let labelLine {
                    currentHost?.label = String(labelLine.dropFirst("# @label ".count))
                    currentHost?.comment = commentLines.filter { !$0.hasPrefix("# @label ") }.joined(separator: "\n")
                } else {
                    currentHost?.comment = pendingComment
                }
                pendingComment = ""
            } else if var host = currentHost {
                applyDirective(key: key, value: parts.value, to: &host)
                currentHost = host
            }
        }

        // Don't forget the last host
        if let host = currentHost {
            hosts.append(host)
        }

        return hosts
    }

    /// Parse a directive line into key and value
    private static func splitDirective(_ line: String) -> (key: String?, value: String) {
        // SSH config supports both "Key Value" and "Key=Value"
        let stripped = line.trimmingCharacters(in: .whitespaces)

        if let eqIdx = stripped.firstIndex(of: "=") {
            let key = String(stripped[stripped.startIndex..<eqIdx]).trimmingCharacters(in: .whitespaces)
            let value = String(stripped[stripped.index(after: eqIdx)...]).trimmingCharacters(in: .whitespaces)
            return (key, value)
        }

        // Space-separated
        let parts = stripped.split(separator: " ", maxSplits: 1)
        if parts.count == 2 {
            return (String(parts[0]), String(parts[1]).trimmingCharacters(in: .whitespaces))
        } else if parts.count == 1 {
            return (String(parts[0]), "")
        }
        return (nil, "")
    }

    /// Apply a parsed directive to a host
    private static func applyDirective(key: String, value: String, to host: inout SSHHost) {
        switch key.lowercased() {
        case "hostname":
            host.hostName = value
        case "user":
            host.user = value
        case "port":
            if let p = Int(value), (1...65535).contains(p) {
                host.port = p
            }
        case "identityfile":
            host.identityFile = value
        case "proxyjump":
            host.proxyJump = value
        case "forwardagent":
            host.forwardAgent = value.lowercased() == "yes"
        default:
            host.extraOptions[key] = value
        }
    }

    /// Sanitize a host entry (strip control chars from fields, filter dangerous extraOptions)
    static func sanitizeHost(_ host: SSHHost) -> SSHHost {
        var h = host
        h.host = sanitizeAlias(stripControlChars(h.host))
        h.label = stripControlChars(h.label)
        h.hostName = stripControlChars(h.hostName)
        h.user = stripControlChars(h.user)
        h.identityFile = stripControlChars(h.identityFile)
        h.proxyJump = stripControlChars(h.proxyJump)

        // Validate port range
        if let port = h.port, !(1...65535).contains(port) {
            h.port = nil
        }

        // Sanitize extra options: reject keys/values with control characters
        var cleaned: [String: String] = [:]
        for (key, value) in h.extraOptions {
            let cleanKey = stripControlChars(key)
            let cleanValue = stripControlChars(value)
            if !cleanKey.isEmpty {
                cleaned[cleanKey] = cleanValue
            }
        }
        h.extraOptions = cleaned

        return h
    }

    /// Replace spaces in host aliases with underscores.
    /// SSH config treats spaces in Host directives as pattern separators,
    /// which breaks SFTP app matching and is rarely intended.
    static func sanitizeAlias(_ alias: String) -> String {
        alias.replacingOccurrences(of: " ", with: "_")
    }

    private static func stripControlChars(_ s: String) -> String {
        s.unicodeScalars.filter { $0.value >= 32 || $0 == "\t" }
            .map { String($0) }.joined()
    }

    /// Serialize hosts back to SSH config format
    static func serialize(hosts: [SSHHost]) -> String {
        var lines: [String] = []

        for (index, host) in hosts.enumerated() {
            if index > 0 {
                lines.append("")
            }

            // Write label tag if present
            if !host.label.isEmpty {
                lines.append("# @label \(host.label)")
            }

            // Write comment if present
            if !host.comment.isEmpty {
                for commentLine in host.comment.components(separatedBy: .newlines) {
                    lines.append(commentLine)
                }
            }

            lines.append("Host \(host.host)")

            if !host.hostName.isEmpty {
                lines.append("    HostName \(host.hostName)")
            }
            if !host.user.isEmpty {
                lines.append("    User \(host.user)")
            }
            if let port = host.port {
                lines.append("    Port \(port)")
            }
            if !host.identityFile.isEmpty {
                lines.append("    IdentityFile \(host.identityFile)")
            }
            if !host.proxyJump.isEmpty {
                lines.append("    ProxyJump \(host.proxyJump)")
            }
            if host.forwardAgent {
                lines.append("    ForwardAgent yes")
            }

            // Write extra options — reject entries with newlines
            for key in host.extraOptions.keys.sorted() {
                if let value = host.extraOptions[key],
                   !key.contains("\n"), !key.contains("\r"),
                   !value.contains("\n"), !value.contains("\r") {
                    lines.append("    \(key) \(value)")
                }
            }
        }

        // Ensure trailing newline
        lines.append("")
        return lines.joined(separator: "\n")
    }
}
