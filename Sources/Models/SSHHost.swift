import Foundation

struct SSHHost: Identifiable, Codable, Hashable {
    let id: UUID
    var host: String
    var label: String
    var hostName: String
    var user: String
    var port: Int?
    var identityFile: String
    var proxyJump: String
    var forwardAgent: Bool
    var extraOptions: [String: String]
    var comment: String

    init(
        id: UUID = UUID(),
        host: String = "",
        label: String = "",
        hostName: String = "",
        user: String = "",
        port: Int? = nil,
        identityFile: String = "",
        proxyJump: String = "",
        forwardAgent: Bool = false,
        extraOptions: [String: String] = [:],
        comment: String = ""
    ) {
        self.id = id
        self.host = host
        self.label = label
        self.hostName = hostName
        self.user = user
        self.port = port
        self.identityFile = identityFile
        self.proxyJump = proxyJump
        self.forwardAgent = forwardAgent
        self.extraOptions = extraOptions
        self.comment = comment
    }

    /// The display name — prefers label, falls back to host alias
    var displayName: String {
        if !label.isEmpty { return label }
        return host.isEmpty ? hostName : host
    }

    /// Build the ssh command string for this host (shell-safe)
    var sshCommand: String {
        // If there's a Host alias, just use that
        if !host.isEmpty && host != "*" {
            return "ssh \(host.shellEscaped)"
        }
        var cmd = "ssh"
        if !user.isEmpty {
            cmd += " \(user.shellEscaped)@\(hostName.shellEscaped)"
        } else {
            cmd += " \(hostName.shellEscaped)"
        }
        if let port, port != TerminalService.defaultSSHPort {
            cmd += " -p \(port)"
        }
        return cmd
    }

    /// Whether this is a wildcard/default host
    var isWildcard: Bool {
        host == "*"
    }
}

// MARK: - Shell Escaping

extension String {
    /// Shell-escape for safe use in command strings.
    /// Only escapes if the string contains characters that need it.
    var shellEscaped: String {
        let safe = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_./:@"))
        if unicodeScalars.allSatisfy({ safe.contains($0) }) {
            return self
        }
        return "'" + replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
