import SwiftUI

struct HostFormView: View {
    enum Mode {
        case add
        case edit(SSHHost)
    }

    let mode: Mode
    let onSave: (SSHHost) -> Void
    var onCancel: (() -> Void)?

    @Environment(\.dismiss) private var dismiss

    @State private var host: String = ""
    @State private var label: String = ""
    @State private var hostName: String = ""
    @State private var user: String = ""
    @State private var portString: String = ""
    @State private var identityFile: String = ""
    @State private var proxyJump: String = ""
    @State private var forwardAgent: Bool = false
    @State private var comment: String = ""
    @State private var extraOptionsText: String = ""
    @State private var availableKeys: [SSHKeyInfo] = []
    @State private var useDefaultTerminal: Bool = true
    @State private var selectedTerminal: TerminalApp = .ghostty
    @State private var customTerminalPath: String = ""

    private let terminalPrefs = TerminalPreferences.shared
    private var existingID: UUID?

    init(mode: Mode, onSave: @escaping (SSHHost) -> Void, onCancel: (() -> Void)? = nil) {
        self.mode = mode
        self.onSave = onSave
        self.onCancel = onCancel

        switch mode {
        case .add:
            existingID = nil
        case .edit(let existing):
            existingID = existing.id
            _host = State(initialValue: existing.host)
            _label = State(initialValue: existing.label)
            _hostName = State(initialValue: existing.hostName)
            _user = State(initialValue: existing.user)
            _portString = State(initialValue: existing.port.map(String.init) ?? "")
            _identityFile = State(initialValue: existing.identityFile)
            _proxyJump = State(initialValue: existing.proxyJump)
            _forwardAgent = State(initialValue: existing.forwardAgent)
            _comment = State(initialValue: existing.comment)
            _extraOptionsText = State(initialValue: existing.extraOptions.map { "\($0.key) \($0.value)" }.joined(separator: "\n"))
            let prefs = TerminalPreferences.shared
            if let override = prefs.hostOverrides[existing.host] {
                _useDefaultTerminal = State(initialValue: false)
                _selectedTerminal = State(initialValue: override.terminal)
                _customTerminalPath = State(initialValue: override.customAppPath ?? "")
            }
        }
    }

    private var isValid: Bool {
        let trimmedHost = host.trimmingCharacters(in: .whitespaces)
        guard !trimmedHost.isEmpty else { return false }
        // Validate port range if provided
        if let portStr = portString.nilIfEmpty, let p = Int(portStr) {
            if !(1...65535).contains(p) { return false }
        } else if let portStr = portString.nilIfEmpty, Int(portStr) == nil {
            return false // non-numeric port
        }
        return true
    }

    private var title: String {
        switch mode {
        case .add: return "Add Host"
        case .edit: return "Edit Host"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Title bar
            HStack {
                Text(title)
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                Button("Cancel") { cancelAction() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding()

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Connection
                    sectionHeader("Connection")
                    VStack(spacing: 10) {
                        labeledField("Host Alias", text: $host, prompt: "e.g., myserver (no spaces)")
                        labeledField("Display Name", text: $label, prompt: "Optional, e.g., BDIX - Micro")
                        labeledField("HostName", text: $hostName, prompt: "IP address or domain")
                        labeledField("User", text: $user, prompt: "Username")
                        labeledField("Port", text: $portString, prompt: "22")
                    }

                    Divider()

                    // Authentication
                    sectionHeader("Authentication")
                    VStack(spacing: 10) {
                        HStack {
                            Text("Identity File")
                                .frame(width: 120, alignment: .trailing)
                                .foregroundColor(.secondary)
                            TextField("~/.ssh/id_ed25519", text: $identityFile)
                                .textFieldStyle(.roundedBorder)
                            Menu {
                                if availableKeys.isEmpty {
                                    Text("No keys found")
                                } else {
                                    ForEach(availableKeys) { key in
                                        Button {
                                            identityFile = "~/.ssh/\(key.name)"
                                        } label: {
                                            HStack {
                                                Text(key.name)
                                                Text("(\(key.keyType))")
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                    }
                                }
                            } label: {
                                Image(systemName: "key")
                            }
                            .menuStyle(.borderlessButton)
                            .frame(width: 30)
                            .help("Select an SSH key")
                        }
                        HStack {
                            Text("Forward Agent")
                                .frame(width: 120, alignment: .trailing)
                                .foregroundColor(.secondary)
                            Toggle("", isOn: $forwardAgent)
                                .labelsHidden()
                            Spacer()
                        }
                    }

                    Divider()

                    // Proxy
                    sectionHeader("Proxy")
                    labeledField("ProxyJump", text: $proxyJump, prompt: "e.g., bastion")

                    Divider()

                    // Terminal
                    sectionHeader("Terminal")
                    VStack(spacing: 10) {
                        HStack {
                            Text("Terminal")
                                .frame(width: 120, alignment: .trailing)
                                .foregroundColor(.secondary)
                            Picker("", selection: $useDefaultTerminal) {
                                Text("Use Default (\(terminalPrefs.defaultTerminal.displayName))")
                                    .tag(true)
                                Text("Override for this host")
                                    .tag(false)
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                        }

                        if !useDefaultTerminal {
                            HStack {
                                Text("App")
                                    .frame(width: 120, alignment: .trailing)
                                    .foregroundColor(.secondary)
                                Picker("", selection: $selectedTerminal) {
                                    ForEach(TerminalApp.allCases, id: \.self) { app in
                                        Text(app.displayName).tag(app)
                                    }
                                }
                                .labelsHidden()
                                .pickerStyle(.menu)
                            }

                            if selectedTerminal == .custom {
                                HStack {
                                    Text("App Path")
                                        .frame(width: 120, alignment: .trailing)
                                        .foregroundColor(.secondary)
                                    TextField("/Applications/MyTerm.app", text: $customTerminalPath)
                                        .textFieldStyle(.roundedBorder)
                                }
                            }
                        }
                    }

                    Divider()

                    // Extra Options
                    sectionHeader("Additional Options")
                    HStack(alignment: .top) {
                        Text("Options")
                            .frame(width: 120, alignment: .trailing)
                            .foregroundColor(.secondary)
                        TextEditor(text: $extraOptionsText)
                            .font(.system(.body, design: .monospaced))
                            .frame(minHeight: 50, maxHeight: 80)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color.secondary.opacity(0.3))
                            )
                    }

                    Divider()

                    // Comment
                    sectionHeader("Comment")
                    labeledField("Comment", text: $comment, prompt: "Optional note")
                }
                .padding(24)
            }

            Divider()

            // Action buttons
            HStack {
                Spacer()
                Button("Cancel") { cancelAction() }
                    .buttonStyle(.bordered)
                Button("Save") { saveHost() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(!isValid)
            }
            .padding()
        }
        .task {
            availableKeys = SSHKeyService.shared.listKeys()
        }
    }

    private func cancelAction() {
        if let onCancel {
            onCancel()
        } else {
            dismiss()
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundColor(.secondary)
            .textCase(.uppercase)
    }

    private func labeledField(_ label: String, text: Binding<String>, prompt: String) -> some View {
        HStack {
            Text(label)
                .frame(width: 120, alignment: .trailing)
                .foregroundColor(.secondary)
            TextField(prompt, text: text)
                .textFieldStyle(.roundedBorder)
        }
    }

    private func saveHost() {
        let port: Int? = portString.nilIfEmpty.flatMap { Int($0) }
        var extras: [String: String] = [:]

        // Parse extra options
        for line in extraOptionsText.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }
            let parts = trimmed.split(separator: " ", maxSplits: 1)
            if parts.count == 2 {
                extras[String(parts[0])] = String(parts[1])
            }
        }

        // Format comment
        var formattedComment = comment.trimmingCharacters(in: .whitespaces)
        if !formattedComment.isEmpty && !formattedComment.hasPrefix("#") {
            formattedComment = "# " + formattedComment
        }

        let newHost = SSHHost(
            id: existingID ?? UUID(),
            host: SSHConfig.sanitizeAlias(host.trimmingCharacters(in: .whitespaces)),
            label: label.trimmingCharacters(in: .whitespaces),
            hostName: hostName.trimmingCharacters(in: .whitespaces),
            user: user.trimmingCharacters(in: .whitespaces),
            port: port,
            identityFile: identityFile.trimmingCharacters(in: .whitespaces),
            proxyJump: proxyJump.trimmingCharacters(in: .whitespaces),
            forwardAgent: forwardAgent,
            extraOptions: extras,
            comment: formattedComment
        )

        // Save per-host terminal override
        let alias = newHost.host
        if useDefaultTerminal {
            terminalPrefs.removeOverride(for: alias)
        } else {
            terminalPrefs.setOverride(
                for: alias,
                terminal: selectedTerminal,
                customPath: selectedTerminal == .custom ? customTerminalPath : nil
            )
        }

        onSave(newHost)
        if onCancel == nil {
            dismiss()
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? nil : trimmed
    }
}
