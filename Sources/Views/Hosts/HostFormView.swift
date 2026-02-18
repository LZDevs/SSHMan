import SwiftUI

struct HostFormView: View {
    enum Mode {
        case add
        case edit(SSHHost)
    }

    let mode: Mode
    let groups: [HostGroup]
    let onSave: (SSHHost, UUID?) -> Void
    var onCancel: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var tm = ThemeManager.shared

    @State private var name: String = ""
    @State private var hostName: String = ""
    @State private var user: String = ""
    @State private var portString: String = ""
    @State private var identityFile: String = ""
    @State private var proxyJump: String = ""
    @State private var sftpPath: String = ""
    @State private var sshInitPath: Bool = true
    @State private var forwardAgent: Bool = false
    @State private var selectedIcon: String = ""
    @State private var showIconPicker: Bool = false
    @State private var comment: String = ""
    @State private var extraOptionsText: String = ""
    @State private var availableKeys: [SSHKeyInfo] = []
    @State private var useDefaultTerminal: Bool = true
    @State private var selectedTerminal: TerminalApp = .ghostty
    @State private var customTerminalPath: String = ""
    @State private var selectedGroupID: UUID?

    private let terminalPrefs = TerminalPreferences.shared
    private var t: AppTheme { tm.current }
    private var existingID: UUID?

    init(mode: Mode, groups: [HostGroup] = [], initialGroupID: UUID? = nil, onSave: @escaping (SSHHost, UUID?) -> Void, onCancel: (() -> Void)? = nil) {
        self.mode = mode
        self.groups = groups
        self.onSave = onSave
        self.onCancel = onCancel

        _selectedGroupID = State(initialValue: initialGroupID)

        switch mode {
        case .add:
            existingID = nil
        case .edit(let existing):
            existingID = existing.id
            _name = State(initialValue: existing.label.isEmpty ? existing.host : existing.label)
            _hostName = State(initialValue: existing.hostName)
            _user = State(initialValue: existing.user)
            _portString = State(initialValue: existing.port.map(String.init) ?? "")
            _identityFile = State(initialValue: existing.identityFile)
            _proxyJump = State(initialValue: existing.proxyJump)
            _sftpPath = State(initialValue: existing.sftpPath)
            _sshInitPath = State(initialValue: existing.sshInitPath)
            _forwardAgent = State(initialValue: existing.forwardAgent)
            _selectedIcon = State(initialValue: existing.icon)
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
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return false }
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
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(t.foreground)
                Spacer()
                Button("Cancel") { cancelAction() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Rectangle().fill(t.secondary.opacity(0.2)).frame(height: 0.5)

            ScrollViewReader { scrollProxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Connection
                    formSection("CONNECTION") {
                        labeledField("Name", text: $name, prompt: "e.g., My Server")
                        labeledField("HostName", text: $hostName, prompt: "IP address or domain")
                        labeledField("User", text: $user, prompt: "Username")
                        labeledField("Port", text: $portString, prompt: "22")
                        if !groups.isEmpty {
                            HStack {
                                Text("Group")
                                    .font(.system(size: 12))
                                    .frame(width: 120, alignment: .trailing)
                                    .foregroundColor(t.secondary)
                                Picker("", selection: $selectedGroupID) {
                                    Text("None").tag(UUID?.none)
                                    ForEach(groups) { group in
                                        Text(group.name).tag(UUID?.some(group.id))
                                    }
                                }
                                .labelsHidden()
                                .pickerStyle(.menu)
                            }
                        }
                    }

                    // Authentication (merged with Proxy)
                    formSection("AUTHENTICATION") {
                        HStack {
                            Text("Identity File")
                                .font(.system(size: 12))
                                .frame(width: 120, alignment: .trailing)
                                .foregroundColor(t.secondary)
                            TextField("~/.ssh/id_ed25519", text: $identityFile)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 12))
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
                                                    .foregroundColor(t.secondary)
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
                                .font(.system(size: 12))
                                .frame(width: 120, alignment: .trailing)
                                .foregroundColor(t.secondary)
                            Toggle("", isOn: $forwardAgent)
                                .labelsHidden()
                            Spacer()
                        }
                        labeledField("ProxyJump", text: $proxyJump, prompt: "e.g., bastion")
                    }

                    // Paths
                    formSection("PATHS") {
                        labeledField("Initial Path", text: $sftpPath, prompt: "e.g., /var/www")
                        if !sftpPath.trimmingCharacters(in: .whitespaces).isEmpty {
                            HStack {
                                Text("SSH cd")
                                    .font(.system(size: 12))
                                    .frame(width: 120, alignment: .trailing)
                                    .foregroundColor(t.secondary)
                                Toggle("", isOn: $sshInitPath)
                                    .labelsHidden()
                                Text("cd into this path on SSH connect")
                                    .font(.system(size: 11))
                                    .foregroundColor(t.secondary)
                                Spacer()
                            }
                        }
                    }

                    // Terminal
                    formSection("TERMINAL") {
                        HStack {
                            Text("Terminal")
                                .font(.system(size: 12))
                                .frame(width: 120, alignment: .trailing)
                                .foregroundColor(t.secondary)
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
                                    .font(.system(size: 12))
                                    .frame(width: 120, alignment: .trailing)
                                    .foregroundColor(t.secondary)
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
                                        .font(.system(size: 12))
                                        .frame(width: 120, alignment: .trailing)
                                        .foregroundColor(t.secondary)
                                    TextField("/Applications/MyTerm.app", text: $customTerminalPath)
                                        .textFieldStyle(.roundedBorder)
                                        .font(.system(size: 12))
                                }
                            }
                        }
                    }

                    // Advanced (merged Extra Options + Comment)
                    formSection("ADVANCED") {
                        HStack(alignment: .top) {
                            Text("Options")
                                .font(.system(size: 12))
                                .frame(width: 120, alignment: .trailing)
                                .foregroundColor(t.secondary)
                            TextEditor(text: $extraOptionsText)
                                .font(.system(.body, design: .monospaced))
                                .frame(minHeight: 50, maxHeight: 80)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(t.secondary.opacity(0.3))
                                )
                        }
                        labeledField("Comment", text: $comment, prompt: "Optional note")
                    }

                    // Icon (collapsible)
                    VStack(alignment: .leading, spacing: 10) {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showIconPicker.toggle()
                            }
                            if showIconPicker {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                    withAnimation {
                                        scrollProxy.scrollTo("iconPickerBottom", anchor: .bottom)
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: showIconPicker ? "chevron.down" : "chevron.right")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(t.secondary)
                                    .frame(width: 12)
                                sectionHeader("ICON")
                                if !selectedIcon.isEmpty {
                                    Image(systemName: selectedIcon)
                                        .font(.system(size: 11))
                                        .foregroundColor(t.accent)
                                }
                                Spacer()
                            }
                        }
                        .buttonStyle(.plain)

                        if showIconPicker {
                            iconPicker
                                .padding(12)
                                .background(RoundedRectangle(cornerRadius: 9).fill(t.surface.opacity(0.6)))
                                .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(t.secondary.opacity(0.15), lineWidth: 0.5))
                                .transition(.opacity.combined(with: .move(edge: .top)))
                                .id("iconPickerBottom")
                        }
                    }
                }
                .padding(16)
            }
            }

            Rectangle().fill(t.secondary.opacity(0.2)).frame(height: 0.5)

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
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
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

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.system(size: 10.5, weight: .bold))
                .foregroundColor(t.secondary)
                .tracking(0.6)
            Rectangle()
                .fill(t.secondary.opacity(0.2))
                .frame(height: 0.5)
        }
    }

    private func formSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(title)
            VStack(spacing: 10) {
                content()
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 9).fill(t.surface.opacity(0.6)))
            .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(t.secondary.opacity(0.15), lineWidth: 0.5))
        }
    }

    private func labeledField(_ label: String, text: Binding<String>, prompt: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .frame(width: 120, alignment: .trailing)
                .foregroundColor(t.secondary)
            TextField(prompt, text: text)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12))
        }
    }

    private static let iconChoices: [(name: String, symbol: String)] = [
        ("Default", "server.rack"),
        ("Desktop", "desktopcomputer"),
        ("Laptop", "laptopcomputer"),
        ("Cloud", "cloud"),
        ("Drive", "externaldrive"),
        ("Network", "network"),
        ("Router", "wifi.router"),
        ("CPU", "cpu"),
        ("Memory", "memorychip"),
        ("Terminal", "terminal"),
        ("Globe", "globe"),
        ("Shield", "lock.shield"),
        ("Cube", "cube"),
        ("Building", "building.2"),
        ("House", "house"),
        ("Media", "play.rectangle"),
        ("Files", "doc.on.doc"),
        ("Chart", "chart.bar"),
        ("Bolt", "bolt"),
        ("Wrench", "wrench"),
        ("Game", "gamecontroller"),
        ("Antenna", "antenna.radiowaves.left.and.right"),
    ]

    private var iconPicker: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 5)
        return LazyVGrid(columns: columns, spacing: 8) {
            ForEach(Self.iconChoices, id: \.symbol) { choice in
                let isDefault = choice.symbol == "server.rack"
                let isSelected = isDefault ? selectedIcon.isEmpty : selectedIcon == choice.symbol
                Button {
                    selectedIcon = isDefault ? "" : choice.symbol
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: choice.symbol)
                            .font(.system(size: 16))
                            .frame(width: 36, height: 36)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(isSelected ? t.accent.opacity(0.2) : t.surface.opacity(0.6))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(isSelected ? t.accent : t.secondary.opacity(0.2), lineWidth: isSelected ? 1.5 : 0.5)
                            )
                        Text(choice.name)
                            .font(.system(size: 9))
                            .lineLimit(1)
                    }
                    .foregroundColor(isSelected ? t.accent : t.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 4)
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

        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let newHost = SSHHost(
            id: existingID ?? UUID(),
            host: SSHConfig.sanitizeAlias(trimmedName),
            label: trimmedName,
            hostName: hostName.trimmingCharacters(in: .whitespaces),
            user: user.trimmingCharacters(in: .whitespaces),
            port: port,
            identityFile: identityFile.trimmingCharacters(in: .whitespaces),
            proxyJump: proxyJump.trimmingCharacters(in: .whitespaces),
            forwardAgent: forwardAgent,
            icon: selectedIcon,
            sftpPath: sftpPath.trimmingCharacters(in: .whitespaces),
            sshInitPath: sshInitPath,
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

        onSave(newHost, selectedGroupID)
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
