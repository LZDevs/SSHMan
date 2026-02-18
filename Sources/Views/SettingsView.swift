import SwiftUI

struct SettingsView: View {
    var isInline: Bool = false

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var tm = ThemeManager.shared
    @ObservedObject private var prefs = TerminalPreferences.shared

    private var t: AppTheme { tm.current }

    private let themeColumns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Settings")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(t.foreground)
                Spacer()
                if !isInline {
                    Button("Done") { dismiss() }
                        .keyboardShortcut(.cancelAction)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Rectangle().fill(t.secondary.opacity(0.2)).frame(height: 0.5)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    themeSection
                    displaySection
                    terminalSection
                    availabilitySection
                }
                .padding(16)
            }
        }
        .background(t.background)
        .frame(
            minWidth: isInline ? nil : 480,
            idealWidth: isInline ? nil : 480,
            minHeight: isInline ? nil : 440,
            idealHeight: isInline ? nil : 440
        )
    }

    // MARK: - Theme Section

    private var themeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("THEME")

            LazyVGrid(columns: themeColumns, spacing: 10) {
                ForEach(AppTheme.all) { theme in
                    themeCard(theme)
                }
            }
        }
    }

    private func themeCard(_ theme: AppTheme) -> some View {
        let isSelected = tm.current.id == theme.id
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                tm.select(theme)
            }
        } label: {
            VStack(spacing: 0) {
                // Color preview strip
                HStack(spacing: 0) {
                    theme.background.frame(height: 28)
                    theme.surface.frame(height: 28)
                    theme.accent.frame(height: 28)
                    theme.cyan.frame(height: 28)
                    theme.green.frame(height: 28)
                }
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .padding(.horizontal, 8)
                .padding(.top, 8)

                // Theme name + indicator
                HStack(spacing: 4) {
                    Circle()
                        .fill(t.secondary.opacity(0.4))
                        .frame(width: 5, height: 5)
                    Text(theme.name)
                        .font(.system(size: 10.5, weight: isSelected ? .bold : .medium))
                        .foregroundColor(t.foreground)
                        .lineLimit(1)
                }
                .padding(.top, 6)
                .padding(.bottom, 8)
            }
            .background(
                RoundedRectangle(cornerRadius: 9)
                    .fill(isSelected ? t.accent.opacity(0.12) : t.surface.opacity(0.6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9)
                    .strokeBorder(
                        isSelected ? t.accent.opacity(0.6) : t.secondary.opacity(0.15),
                        lineWidth: isSelected ? 1.5 : 0.5
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Display Section

    private var displaySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("DISPLAY")

            VStack(spacing: 8) {
                Toggle("Mask IP / hostname on host tiles", isOn: $prefs.maskHostIP)
                    .font(.system(size: 12))
                    .foregroundColor(t.foreground)
                    .toggleStyle(.switch)
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 9).fill(t.surface.opacity(0.6)))
            .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(t.secondary.opacity(0.15), lineWidth: 0.5))
        }
    }

    // MARK: - Terminal Section

    private var terminalSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("DEFAULT TERMINAL")

            VStack(spacing: 8) {
                HStack {
                    Text("Terminal App")
                        .font(.system(size: 12))
                        .foregroundColor(t.secondary)
                        .frame(width: 100, alignment: .trailing)
                    Picker("", selection: $prefs.defaultTerminal) {
                        ForEach(TerminalApp.allCases, id: \.self) { app in
                            Text(app.displayName).tag(app)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: 200)
                }

                if prefs.defaultTerminal == .custom {
                    HStack {
                        Text("App Path")
                            .font(.system(size: 12))
                            .foregroundColor(t.secondary)
                            .frame(width: 100, alignment: .trailing)
                        TextField("/Applications/MyTerm.app", text: $prefs.customTerminalPath)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 12))
                        Button("Browse...") { browseForApp() }
                            .font(.system(size: 12))
                    }
                }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 9).fill(t.surface.opacity(0.6)))
            .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(t.secondary.opacity(0.15), lineWidth: 0.5))
        }
    }

    // MARK: - Availability Section

    private var availabilitySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("AVAILABILITY")

            VStack(spacing: 6) {
                ForEach(TerminalApp.allCases.filter { $0 != .custom }, id: \.self) { app in
                    HStack(spacing: 8) {
                        Image(systemName: app.isInstalled ? "checkmark.circle.fill" : "xmark.circle")
                            .font(.system(size: 12))
                            .foregroundColor(app.isInstalled ? t.green : t.secondary.opacity(0.4))
                        Text(app.displayName)
                            .font(.system(size: 12))
                            .foregroundColor(app.isInstalled ? t.foreground : t.secondary)
                        Spacer()
                        if app.isInstalled {
                            Text("Installed")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(t.green.opacity(0.7))
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 7)
                            .fill(app.isInstalled ? t.green.opacity(0.04) : .clear)
                    )
                }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 9).fill(t.surface.opacity(0.6)))
            .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(t.secondary.opacity(0.15), lineWidth: 0.5))
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

    private func browseForApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        if panel.runModal() == .OK, let url = panel.url {
            prefs.customTerminalPath = url.path
        }
    }
}
