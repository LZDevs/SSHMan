import Foundation
import SwiftUI

/// Supported terminal applications
enum TerminalApp: String, CaseIterable, Codable {
    case ghostty
    case terminal
    case iterm2
    case custom

    var displayName: String {
        switch self {
        case .ghostty: return "Ghostty"
        case .terminal: return "Terminal"
        case .iterm2: return "iTerm2"
        case .custom: return "Custom"
        }
    }

    var appPath: String {
        switch self {
        case .ghostty: return "/Applications/Ghostty.app"
        case .terminal: return "/System/Applications/Utilities/Terminal.app"
        case .iterm2: return "/Applications/iTerm.app"
        case .custom: return ""
        }
    }

    var isInstalled: Bool {
        switch self {
        case .custom: return true
        default: return FileManager.default.fileExists(atPath: appPath)
        }
    }
}

/// Per-host terminal override (stored in a separate JSON file)
struct HostTerminalOverride: Codable {
    var hostID: String  // host alias
    var terminal: TerminalApp
    var customAppPath: String?
}

/// Manages global terminal preferences and per-host overrides
final class TerminalPreferences: ObservableObject {
    static let shared = TerminalPreferences()

    @AppStorage("defaultTerminal") var defaultTerminal: TerminalApp = .ghostty
    @AppStorage("customTerminalPath") var customTerminalPath: String = ""
    @AppStorage("maskHostIP") var maskHostIP: Bool = false

    @Published var hostOverrides: [String: HostTerminalOverride] = [:]

    private static let overridesURL: URL = {
        guard let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            fatalError("Application Support directory unavailable")
        }
        let url = base.appendingPathComponent("SSHMan", isDirectory: true)
        try? FileManager.default.createDirectory(
            at: url, withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        return url.appendingPathComponent("host_terminal_prefs.json")
    }()

    private init() {
        loadOverrides()
    }

    /// Resolve which terminal to use for a given host
    func resolvedTerminal(for hostAlias: String) -> TerminalApp {
        hostOverrides[hostAlias]?.terminal ?? defaultTerminal
    }

    /// Resolve the custom app path for a given host
    func resolvedCustomPath(for hostAlias: String) -> String {
        if let override = hostOverrides[hostAlias], override.terminal == .custom,
           let path = override.customAppPath, !path.isEmpty {
            return path
        }
        return customTerminalPath
    }

    // MARK: - Per-host overrides

    func setOverride(for hostAlias: String, terminal: TerminalApp, customPath: String? = nil) {
        hostOverrides[hostAlias] = HostTerminalOverride(
            hostID: hostAlias,
            terminal: terminal,
            customAppPath: customPath
        )
        saveOverrides()
    }

    func removeOverride(for hostAlias: String) {
        hostOverrides.removeValue(forKey: hostAlias)
        saveOverrides()
    }

    func hasOverride(for hostAlias: String) -> Bool {
        hostOverrides[hostAlias] != nil
    }

    // MARK: - Persistence

    private func loadOverrides() {
        guard FileManager.default.fileExists(atPath: Self.overridesURL.path),
              let data = try? Data(contentsOf: Self.overridesURL),
              let list = try? JSONDecoder().decode([HostTerminalOverride].self, from: data) else {
            return
        }
        hostOverrides = Dictionary(uniqueKeysWithValues: list.map { ($0.hostID, $0) })
    }

    private func saveOverrides() {
        let list = Array(hostOverrides.values)
        guard let data = try? JSONEncoder().encode(list) else { return }
        try? data.write(to: Self.overridesURL, options: .atomic)
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: Self.overridesURL.path)
    }
}

