import SwiftUI

struct SidebarView: View {
    @EnvironmentObject var configService: SSHConfigService
    @ObservedObject private var tm = ThemeManager.shared
    @Binding var searchText: String
    @Binding var showingAddHost: Bool
    @Binding var addHostGroupID: UUID?
    var onEdit: ((SSHHost) -> Void)?
    var onConnect: ((SSHHost) -> Void)?

    @State private var showingAddGroup = false
    @State private var newGroupName = ""
    @State private var hostToDelete: SSHHost?
    @State private var showDeleteConfirm = false

    private var t: AppTheme { tm.current }

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    var filteredHosts: [SSHHost] {
        if searchText.isEmpty { return configService.hosts }
        let query = searchText.lowercased()
        return configService.hosts.filter {
            $0.host.lowercased().contains(query) ||
            $0.hostName.lowercased().contains(query) ||
            $0.user.lowercased().contains(query)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            searchBar
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 6)

            Rectangle().fill(t.secondary.opacity(0.2)).frame(height: 0.5).padding(.top, 4)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if filteredHosts.isEmpty && !searchText.isEmpty {
                        emptySearchState
                    } else {
                        if !configService.groups.isEmpty { groupedSections }
                        ungroupedSection
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 16)
            }

            Rectangle().fill(t.secondary.opacity(0.2)).frame(height: 0.5)
            HStack {
                Button { showingAddGroup = true } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "folder.badge.plus").font(.system(size: 12))
                        Text("New Group").font(.system(size: 11))
                    }
                    .foregroundColor(t.secondary)
                }
                .buttonStyle(.plain)
                Spacer()
                Text("\(configService.hosts.count) host\(configService.hosts.count == 1 ? "" : "s")")
                    .font(.system(size: 10.5))
                    .foregroundColor(t.secondary.opacity(0.7))
                Text("v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?")")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(t.secondary.opacity(0.4))
            }
            .padding(.horizontal, 16).padding(.vertical, 6)
        }
        .background(t.background)
        .alert("New Group", isPresented: $showingAddGroup) {
            TextField("Group name", text: $newGroupName)
            Button("Cancel", role: .cancel) { newGroupName = "" }
            Button("Create") {
                if !newGroupName.isEmpty {
                    configService.addGroup(HostGroup(name: newGroupName))
                    newGroupName = ""
                }
            }
        }
        .alert("Delete Host?", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let host = hostToDelete { configService.deleteHost(host) }
            }
        } message: {
            if let host = hostToDelete {
                Text("Are you sure you want to delete \"\(host.displayName)\"? This will update your SSH config file.")
            }
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 8) {
            Button { showingAddHost = true } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(t.accent.opacity(0.15))
                        .frame(width: 30, height: 30)
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(t.accent)
                }
            }
            .buttonStyle(.plain)
            .help("Add Host")

            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(t.secondary)
                    .font(.system(size: 12, weight: .medium))
                TextField("Search hosts...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12.5))
                    .foregroundColor(t.foreground)
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(t.secondary).font(.system(size: 11))
                    }.buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 7)
            .background(RoundedRectangle(cornerRadius: 7).fill(t.surface.opacity(0.5)))
            .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(t.secondary.opacity(0.2), lineWidth: 0.5))
        }
    }

    private var emptySearchState: some View {
        VStack(spacing: 8) {
            Spacer(minLength: 40)
            Image(systemName: "magnifyingglass")
                .font(.system(size: 28, weight: .light)).foregroundColor(t.secondary.opacity(0.5))
            Text("No results for \"\(searchText)\"")
                .font(.system(size: 13, weight: .medium)).foregroundColor(t.secondary)
            Spacer(minLength: 40)
        }.frame(maxWidth: .infinity)
    }

    // MARK: - Sections

    @ViewBuilder
    private var groupedSections: some View {
        ForEach(configService.groups) { group in
            let groupHosts = filteredHosts.filter { group.hostIDs.contains($0.host) }
            if !groupHosts.isEmpty || searchText.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    sectionHeader(group.name, group: group)
                        .contentShape(Rectangle())
                        .dropDestination(for: String.self) { a, _ in dropHosts(a, into: group) }
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(groupHosts) { host in hostTile(host) }
                    }
                }
                .dropDestination(for: String.self) { a, _ in dropHosts(a, into: group) }
            }
        }
    }

    @ViewBuilder
    private var ungroupedSection: some View {
        let hosts = ungroupedHosts
        if !hosts.isEmpty || configService.groups.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                if !configService.groups.isEmpty || !hosts.isEmpty {
                    sectionHeader(configService.groups.isEmpty ? "Hosts" : "Ungrouped")
                        .contentShape(Rectangle())
                        .dropDestination(for: String.self) { aliases, _ in
                            for alias in aliases {
                                guard let h = configService.hosts.first(where: { $0.host == alias }) else { continue }
                                removeHostFromGroups(h)
                            }
                            return !aliases.isEmpty
                        }
                }
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(hosts) { host in hostTile(host) }
                }
            }
        }
    }

    private func sectionHeader(_ title: String, group: HostGroup? = nil) -> some View {
        HStack(spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 10.5, weight: .bold)).foregroundColor(t.secondary).tracking(0.6)
            Rectangle().fill(t.secondary.opacity(0.2)).frame(height: 0.5)
            if let group {
                Button {
                    addHostGroupID = group.id
                    showingAddHost = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .medium)).foregroundColor(t.secondary)
                }.buttonStyle(.plain).help("Add host to \(group.name)")
            }
        }.padding(.horizontal, 2)
    }

    // MARK: - Host Tile

    private func hostTile(_ host: SSHHost) -> some View {
        HostRowView(host: host, onEdit: { onEdit?(host) }, onConnect: { onConnect?(host) })
            .draggable(host.host)
            .contextMenu {
                Button { onConnect?(host) } label: { Label("Connect", systemImage: "terminal") }
                if !host.isWildcard {
                    Button { TerminalService.openSFTP(to: host) } label: {
                        Label("SFTP", systemImage: "folder.badge.gearshape")
                    }
                }
                Button { onEdit?(host) } label: { Label("Edit", systemImage: "pencil") }
                if !host.identityFile.isEmpty && !host.isWildcard {
                    Button { TerminalService.copyKeyToHost(host, keyPath: host.identityFile) } label: {
                        Label("Copy Public Key to Server", systemImage: "paperplane.fill")
                    }
                }
                Divider()
                if !configService.groups.isEmpty {
                    Menu("Move to Group") {
                        ForEach(configService.groups) { g in Button(g.name) { moveHost(host, to: g) } }
                        Divider()
                        Button("Remove from Group") { removeHostFromGroups(host) }
                    }
                }
                Divider()
                Button(role: .destructive) { hostToDelete = host; showDeleteConfirm = true } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
    }

    // MARK: - Helpers

    private var ungroupedHosts: [SSHHost] {
        if configService.groups.isEmpty { return filteredHosts }
        let allGrouped = Set(configService.groups.flatMap { $0.hostIDs })
        return filteredHosts.filter { !allGrouped.contains($0.host) }
    }

    func moveHost(_ host: SSHHost, to group: HostGroup) {
        for i in configService.groups.indices { configService.groups[i].hostIDs.removeAll { $0 == host.host } }
        if let idx = configService.groups.firstIndex(where: { $0.id == group.id }) {
            configService.groups[idx].hostIDs.append(host.host)
        }
        configService.saveGroups()
    }

    func dropHosts(_ aliases: [String], into group: HostGroup) -> Bool {
        for a in aliases { if let h = configService.hosts.first(where: { $0.host == a }) { moveHost(h, to: group) } }
        return !aliases.isEmpty
    }

    func removeHostFromGroups(_ host: SSHHost) {
        for i in configService.groups.indices { configService.groups[i].hostIDs.removeAll { $0 == host.host } }
        configService.saveGroups()
    }
}
