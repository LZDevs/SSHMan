import SwiftUI

struct HostRowView: View {
    let host: SSHHost
    var onEdit: (() -> Void)?
    var onConnect: (() -> Void)?

    @ObservedObject private var tm = ThemeManager.shared
    @ObservedObject private var prefs = TerminalPreferences.shared
    @State private var isHovered = false
    private var t: AppTheme { tm.current }

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(host.isWildcard
                        ? t.orange.opacity(0.15)
                        : t.accent.opacity(0.15))
                    .frame(width: 34, height: 34)
                Image(systemName: host.isWildcard ? "asterisk" : (host.icon.isEmpty ? "server.rack" : host.icon))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(host.isWildcard ? t.orange : t.accent)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(host.displayName)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundColor(t.foreground)
                    .lineLimit(1)
                    .truncationMode(.tail)

                if !host.hostName.isEmpty {
                    Text(connectionString)
                        .font(.system(size: 10.5))
                        .foregroundColor(t.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            Spacer(minLength: 0)

            if isHovered, let onEdit {
                Button(action: onEdit) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(t.accent.opacity(0.2))
                            .frame(width: 26, height: 26)
                        Image(systemName: "pencil")
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundColor(t.accent)
                    }
                }
                .buttonStyle(.plain)
                .transition(.scale(scale: 0.85).combined(with: .opacity))
                .help("Edit host")
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 9)
                .fill(isHovered
                    ? t.surface.opacity(0.9)
                    : t.surface.opacity(0.6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9)
                .strokeBorder(
                    isHovered
                        ? t.accent.opacity(0.4)
                        : t.secondary.opacity(0.2),
                    lineWidth: 0.5
                )
        )
        .contentShape(Rectangle())
        .simultaneousGesture(
            TapGesture(count: 2).onEnded {
                onConnect?()
            }
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("SSH Host \(host.displayName)")
        .accessibilityHint("Double click to connect")
        .accessibilityAction(.default) { onConnect?() }
    }

    private var connectionString: String {
        let displayHost = prefs.maskHostIP ? "***.***.***.***" : host.hostName
        var parts: [String] = []
        if !host.user.isEmpty {
            parts.append("\(host.user)@\(displayHost)")
        } else {
            parts.append(displayHost)
        }
        if let port = host.port, port != TerminalService.defaultSSHPort {
            parts.append(":\(port)")
        }
        return parts.joined()
    }
}
