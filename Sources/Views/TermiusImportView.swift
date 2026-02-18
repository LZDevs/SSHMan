import SwiftUI

struct TermiusImportView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var configService: SSHConfigService
    @ObservedObject private var tm = ThemeManager.shared

    @State private var linkText = ""
    @State private var importedCount = 0
    @State private var didImport = false
    @State private var selectedGroupID: UUID?

    private var t: AppTheme { tm.current }

    var body: some View {
        VStack(spacing: 0) {
            // Title bar
            HStack {
                Text("Import from Termius")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding()

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                Text("Paste one or more Termius sharing links (one per line):")
                    .font(.subheadline)
                    .foregroundColor(t.secondary)

                TextEditor(text: $linkText)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 120, maxHeight: 200)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(t.secondary.opacity(0.3))
                    )

                if !configService.groups.isEmpty {
                    HStack {
                        Text("Add to group:")
                            .font(.subheadline)
                            .foregroundColor(t.secondary)
                        Picker("", selection: $selectedGroupID) {
                            Text("None").tag(UUID?.none)
                            ForEach(configService.groups) { group in
                                Text(group.name).tag(UUID?.some(group.id))
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                    }
                }

                if didImport {
                    HStack(spacing: 6) {
                        Image(systemName: importedCount > 0 ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundColor(importedCount > 0 ? t.green : t.orange)
                        Text(importedCount > 0
                            ? "Imported \(importedCount) host\(importedCount == 1 ? "" : "s")."
                            : "No valid Termius links found.")
                            .font(.subheadline)
                            .foregroundColor(importedCount > 0 ? t.green : t.orange)
                    }
                }
            }
            .padding(24)

            Divider()

            HStack {
                Spacer()
                if didImport && importedCount > 0 {
                    Button("Done") { dismiss() }
                        .keyboardShortcut(.defaultAction)
                        .buttonStyle(.borderedProminent)
                } else {
                    Button("Cancel") { dismiss() }
                        .buttonStyle(.bordered)
                    Button("Import") { performImport() }
                        .keyboardShortcut(.defaultAction)
                        .buttonStyle(.borderedProminent)
                        .disabled(linkText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding()
        }
        .frame(width: 500)
    }

    // MARK: - OS → Icon mapping

    private static let osIconMap: [String: String] = [
        "debian": "terminal",
        "ubuntu": "terminal",
        "centos": "terminal",
        "fedora": "terminal",
        "linux": "terminal",
        "windows": "desktopcomputer",
        "macos": "laptopcomputer",
        "darwin": "laptopcomputer",
    ]

    // MARK: - Import

    private func performImport() {
        let lines = linkText.components(separatedBy: .newlines)
        var count = 0
        var importedAliases: [String] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            if let host = parseTermiusLink(trimmed) {
                configService.addHost(host)
                importedAliases.append(host.host)
                count += 1
            }
        }

        // Assign imported hosts to selected group
        if let groupID = selectedGroupID,
           let idx = configService.groups.firstIndex(where: { $0.id == groupID }) {
            for alias in importedAliases {
                if !configService.groups[idx].hostIDs.contains(alias) {
                    configService.groups[idx].hostIDs.append(alias)
                }
            }
            configService.saveGroups()
        }

        importedCount = count
        didImport = true
    }

    private func parseTermiusLink(_ urlString: String) -> SSHHost? {
        guard let url = URL(string: urlString),
              let fragment = url.fragment, !fragment.isEmpty else {
            return nil
        }

        var params: [String: String] = [:]
        for pair in fragment.components(separatedBy: "&") {
            let kv = pair.components(separatedBy: "=")
            guard kv.count == 2 else { continue }
            let key = kv[0].removingPercentEncoding ?? kv[0]
            let value = kv[1].removingPercentEncoding ?? kv[1]
            params[key.lowercased()] = value
        }

        guard let ip = params["ip"], !ip.isEmpty else { return nil }

        let port: Int? = params["port"].flatMap { Int($0) }
        let label = params["label"] ?? ""
        let user = params["username"] ?? ""
        let os = params["os"]?.lowercased() ?? ""
        let icon = Self.osIconMap[os] ?? ""

        let alias = label.isEmpty
            ? SSHConfig.sanitizeAlias(ip)
            : SSHConfig.sanitizeAlias(label)

        return SSHHost(
            host: alias,
            label: label,
            hostName: ip,
            user: user,
            port: port,
            icon: icon
        )
    }
}
