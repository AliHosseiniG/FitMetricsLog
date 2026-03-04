//
//  MuscleGroupEditorView.swift
//  FlexCore
//
//  MuscleGroupManager is the single source of truth for ALL groups (built-in + custom).
//  Built-in groups can be renamed. Custom groups can be fully edited or deleted.
//

import SwiftUI
import Combine

// MARK: - MuscleGroupManager
class MuscleGroupManager: ObservableObject {
    static let shared = MuscleGroupManager()

    @Published var groups: [MuscleGroup] = []

    private let customKey   = "customMuscleGroups_v2"
    private let overrideKey = "builtinOverrides_v1"   // renamed built-ins

    // Overrides: id → custom name/icon/color
    private var overrides: [String: MuscleGroup] = [:]

    init() { load() }

    // All groups: built-in (possibly overridden) + custom
    /// Returns the current live version of a group by id (applies overrides/renames)
    func liveGroup(for id: String) -> MuscleGroup? {
        groups.first { $0.id == id }
    }

    /// Returns live rawValue (name) for a group — falls back to stored name if not found
    func liveName(for group: MuscleGroup) -> String {
        liveGroup(for: group.id)?.rawValue ?? group.rawValue
    }

    /// Returns live color for a group
    func liveColor(for group: MuscleGroup) -> Color {
        liveGroup(for: group.id)?.color ?? group.color
    }

    /// Returns live icon for a group
    func liveIcon(for group: MuscleGroup) -> String {
        liveGroup(for: group.id)?.icon ?? group.icon
    }

    func rebuildGroups() {
        let hidden = hiddenBuiltIns()
        var result: [MuscleGroup] = MuscleGroup.builtIn
            .filter { !hidden.contains($0.id) }
            .map { b in overrides[b.id] ?? b }
        result += customFromStore()
        groups = result
        objectWillChange.send()
    }

    func group(for id: String) -> MuscleGroup? { groups.first { $0.id == id } }

    // Update any group (built-in or custom)
    func update(_ g: MuscleGroup) {
        if MuscleGroup.builtIn.contains(where: { $0.id == g.id }) {
            overrides[g.id] = g
            saveOverrides()
        } else {
            var customs = customFromStore()
            if let i = customs.firstIndex(where: { $0.id == g.id }) {
                customs[i] = g
                saveCustom(customs)
            }
        }
        rebuildGroups()
    }

    func add(_ g: MuscleGroup) {
        var customs = customFromStore()
        customs.append(g)
        saveCustom(customs)
        rebuildGroups()
    }

    func delete(_ g: MuscleGroup) {
        if MuscleGroup.builtIn.contains(where: { $0.id == g.id }) {
            // Hide built-in by storing it in a "hidden" set
            var hidden = hiddenBuiltIns()
            hidden.insert(g.id)
            saveHiddenBuiltIns(hidden)
        } else {
            var customs = customFromStore()
            customs.removeAll { $0.id == g.id }
            saveCustom(customs)
        }
        rebuildGroups()
    }

    func restoreBuiltin(_ g: MuscleGroup) {
        var hidden = hiddenBuiltIns()
        hidden.remove(g.id)
        saveHiddenBuiltIns(hidden)
        rebuildGroups()
    }

    private func hiddenBuiltIns() -> Set<String> {
        guard let data = UserDefaults.standard.data(forKey: "hiddenBuiltIns_v1"),
              let set  = try? JSONDecoder().decode(Set<String>.self, from: data)
        else { return [] }
        return set
    }

    private func saveHiddenBuiltIns(_ set: Set<String>) {
        if let enc = try? JSONEncoder().encode(set) {
            UserDefaults.standard.set(enc, forKey: "hiddenBuiltIns_v1")
        }
    }

    func resetBuiltin(_ g: MuscleGroup) {
        overrides.removeValue(forKey: g.id)
        saveOverrides()
        rebuildGroups()
    }

    // MARK: - Storage
    private func customFromStore() -> [MuscleGroup] {
        guard let data = UserDefaults.standard.data(forKey: customKey),
              let dec  = try? JSONDecoder().decode([MuscleGroup].self, from: data)
        else { return [] }
        return dec
    }
    private func saveCustom(_ arr: [MuscleGroup]) {
        if let enc = try? JSONEncoder().encode(arr) { UserDefaults.standard.set(enc, forKey: customKey) }
    }
    private func saveOverrides() {
        if let enc = try? JSONEncoder().encode(overrides) { UserDefaults.standard.set(enc, forKey: overrideKey) }
    }
    private func load() {
        if let data = UserDefaults.standard.data(forKey: overrideKey),
           let dec  = try? JSONDecoder().decode([String: MuscleGroup].self, from: data) {
            overrides = dec
        }
        rebuildGroups()
    }
}

// MARK: - Editor View
struct MuscleGroupEditorView: View {
    @ObservedObject var manager = MuscleGroupManager.shared
    @Environment(\.dismiss) var dismiss
    @State private var editing: MuscleGroup?    = nil
    @State private var showingAdd               = false
    @State private var deleteTarget: MuscleGroup? = nil
    @State private var showDeleteAlert          = false

    var builtIn: [MuscleGroup] { manager.groups.filter { g in MuscleGroup.builtIn.contains { $0.id == g.id } } }
    var custom:  [MuscleGroup] { manager.groups.filter { g in !MuscleGroup.builtIn.contains { $0.id == g.id } } }

    var body: some View {
        ZStack {
            Color(hex: "111111").ignoresSafeArea()
            VStack(spacing: 0) {
                // Top bar
                HStack {
                    Button(action: { dismiss() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left").font(.system(size: 14, weight: .semibold))
                            Text("Back")
                        }.foregroundColor(.orange)
                    }
                    Spacer()
                    Text("Muscle Groups").font(.system(size: 17, weight: .semibold)).foregroundColor(.white)
                    Spacer()
                    Button(action: { showingAdd = true }) {
                        Image(systemName: "plus.circle.fill").font(.system(size: 22)).foregroundColor(.orange)
                    }
                }
                .padding(.horizontal, 20).padding(.top, 55).padding(.bottom, 16)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        // Built-in (visible)
                        sectionLabel("Built-in Groups")
                        ForEach(builtIn) { g in
                            groupRow(g, isBuiltIn: true).padding(.horizontal, 20)
                        }
                        if builtIn.isEmpty {
                            Text("All built-in groups are hidden")
                                .font(.system(size: 13)).foregroundColor(.gray)
                                .padding(.horizontal, 20)
                        }

                        // Custom
                        if !custom.isEmpty {
                            sectionLabel("My Custom Groups").padding(.top, 8)
                            ForEach(custom) { g in
                                groupRow(g, isBuiltIn: false).padding(.horizontal, 20)
                            }
                        }

                        // Hidden built-ins with restore
                        let hiddenGroups = MuscleGroup.builtIn.filter { b in
                            !manager.groups.contains(where: { $0.id == b.id })
                        }
                        if !hiddenGroups.isEmpty {
                            sectionLabel("Hidden Groups (tap to restore)").padding(.top, 8)
                            ForEach(hiddenGroups) { g in
                                Button(action: { manager.restoreBuiltin(g) }) {
                                    HStack(spacing: 12) {
                                        Image(systemName: g.icon).font(.system(size: 15)).foregroundColor(.gray)
                                            .frame(width: 38, height: 38)
                                            .background(Color.white.opacity(0.05)).cornerRadius(9)
                                        Text(g.rawValue).font(.system(size: 14)).foregroundColor(.gray)
                                        Spacer()
                                        Image(systemName: "arrow.counterclockwise.circle.fill")
                                            .font(.system(size: 20)).foregroundColor(.gray)
                                    }
                                    .padding(12).background(Color(hex: "1C1C1E")).cornerRadius(12)
                                    .overlay(RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.white.opacity(0.08), lineWidth: 1))
                                }
                                .padding(.horizontal, 20)
                            }
                        }

                        // Empty state for custom
                        if custom.isEmpty && builtIn.isEmpty {
                            VStack(spacing: 10) {
                                Image(systemName: "plus.circle").font(.system(size: 36)).foregroundColor(.gray.opacity(0.4))
                                Text("Tap + to add a custom group").font(.system(size: 14)).foregroundColor(.gray)
                            }.padding(.top, 30)
                        }

                        Spacer(minLength: 100)
                    }
                }
            }
        }
        .sheet(isPresented: $showingAdd) { MuscleGroupForm(existing: nil) }
        .sheet(item: $editing)           { g in MuscleGroupForm(existing: g) }
        .alert("Delete Group", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) { if let g = deleteTarget { manager.delete(g) } }
            Button("Cancel", role: .cancel) {}
        } message: {
            if let g = deleteTarget, MuscleGroup.builtIn.contains(where: { $0.id == g.id }) {
                Text("This built-in group will be hidden. You can restore it from the Hidden Groups section.")
            } else {
                Text("This will not affect existing workout logs.")
            }
        }
    }

    func sectionLabel(_ text: String) -> some View {
        Text(text).font(.system(size: 12, weight: .semibold)).foregroundColor(.gray)
            .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 20)
    }

    func groupRow(_ g: MuscleGroup, isBuiltIn: Bool) -> some View {
        HStack(spacing: 14) {
            Image(systemName: g.icon).font(.system(size: 17)).foregroundColor(g.color)
                .frame(width: 42, height: 42).background(g.color.opacity(0.15)).cornerRadius(10)
            VStack(alignment: .leading, spacing: 2) {
                Text(g.rawValue).font(.system(size: 14)).foregroundColor(.white)
                if isBuiltIn {
                    let orig = MuscleGroup.builtIn.first { $0.id == g.id }
                    if orig?.rawValue != g.rawValue {
                        Text("(original: \(orig?.rawValue ?? ""))")
                            .font(.system(size: 10)).foregroundColor(.gray)
                    }
                }
            }
            Spacer()
            // Reset button for overridden built-ins
            if isBuiltIn, let orig = MuscleGroup.builtIn.first(where: { $0.id == g.id }),
               orig != g {
                Button(action: { manager.resetBuiltin(g) }) {
                    Image(systemName: "arrow.counterclockwise.circle").font(.system(size: 20)).foregroundColor(.gray)
                }
            }
            Button(action: { editing = g }) {
                Image(systemName: "pencil.circle.fill").font(.system(size: 22)).foregroundColor(.orange)
            }
            // Delete allowed for all groups (built-in groups are hidden, not permanently removed)
            Button(action: { deleteTarget = g; showDeleteAlert = true }) {
                Image(systemName: "trash.circle.fill").font(.system(size: 22)).foregroundColor(.red)
            }
        }
        .padding(12).background(Color(hex: "1C1C1E")).cornerRadius(12)
    }
}

// MARK: - Group Form (create or edit any group)
struct MuscleGroupForm: View {
    var existing: MuscleGroup?
    @ObservedObject var manager = MuscleGroupManager.shared
    @Environment(\.dismiss) var dismiss

    @State private var name     = ""
    @State private var icon     = "figure.strengthtraining.functional"
    @State private var colorHex = "FF6B00"
    @FocusState private var nameFocused: Bool

    let colors = ["FF6B00","FF3B30","FF9500","FFCC00","34C759",
                  "00C7BE","007AFF","5856D6","AF52DE","FF2D55","AC8250","636366"]
    let icons  = ["figure.strengthtraining.functional","figure.arms.open","figure.walk",
                  "dumbbell.fill","figure.run","figure.mixed.cardio","figure.core.training",
                  "heart.fill","bolt.fill","flame.fill","star.fill","trophy.fill"]

    var isEditing: Bool { existing != nil }
    var isBuiltIn: Bool { existing.map { g in MuscleGroup.builtIn.contains { $0.id == g.id } } ?? false }

    var body: some View {
        ZStack {
            Color(hex: "111111").ignoresSafeArea()
                .onTapGesture { nameFocused = false }
            VStack(spacing: 0) {
                HStack {
                    Button("Cancel") { dismiss() }.foregroundColor(.orange)
                    Spacer()
                    Text(isEditing ? (isBuiltIn ? "Rename Group" : "Edit Group") : "New Group")
                        .font(.system(size: 17, weight: .semibold)).foregroundColor(.white)
                    Spacer()
                    Button("Save") { save() }
                        .foregroundColor(name.trimmingCharacters(in: .whitespaces).isEmpty ? .gray : .orange)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(.horizontal, 20).padding(.top, 55).padding(.bottom, 20)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Preview
                        HStack(spacing: 14) {
                            Image(systemName: icon).font(.system(size: 28))
                                .foregroundColor(Color(hex: colorHex))
                                .frame(width: 64, height: 64)
                                .background(Color(hex: colorHex).opacity(0.2)).cornerRadius(16)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(name.isEmpty ? "Group name" : name)
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(name.isEmpty ? .gray : .white)
                                Text(isBuiltIn ? "Built-in Group" : "Custom Group")
                                    .font(.system(size: 12)).foregroundColor(.gray)
                            }
                            Spacer()
                        }
                        .padding(16).background(Color(hex: "1C1C1E")).cornerRadius(14)

                        // Name
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Group Name").font(.system(size: 13)).foregroundColor(.gray)
                            TextField("e.g. Glutes, Upper Chest...", text: $name)
                                .foregroundColor(.white).focused($nameFocused)
                                .padding(14).background(Color(hex: "1C1C1E")).cornerRadius(12)
                        }

                        // Colors
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Color").font(.system(size: 13)).foregroundColor(.gray)
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 10) {
                                ForEach(colors, id: \.self) { hex in
                                    Button(action: { colorHex = hex }) {
                                        Circle().fill(Color(hex: hex)).frame(height: 36)
                                            .overlay(Circle().stroke(Color.white, lineWidth: colorHex == hex ? 2.5 : 0))
                                            .scaleEffect(colorHex == hex ? 1.12 : 1)
                                            .animation(.spring(response: 0.25), value: colorHex)
                                    }
                                }
                            }
                        }
                        .padding(14).background(Color(hex: "1C1C1E")).cornerRadius(14)

                        // Icons
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Icon").font(.system(size: 13)).foregroundColor(.gray)
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 10) {
                                ForEach(icons, id: \.self) { ic in
                                    Button(action: { icon = ic }) {
                                        Image(systemName: ic).font(.system(size: 18))
                                            .foregroundColor(icon == ic ? .black : Color(hex: colorHex))
                                            .frame(width: 44, height: 44)
                                            .background(icon == ic ? Color(hex: colorHex) : Color(hex: colorHex).opacity(0.15))
                                            .cornerRadius(10)
                                    }
                                }
                            }
                        }
                        .padding(14).background(Color(hex: "1C1C1E")).cornerRadius(14)

                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
        .onAppear {
            if let g = existing { name = g.rawValue; icon = g.icon; colorHex = g.colorHex }
        }
    }

    func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        if let g = existing {
            // Update existing (built-in or custom)
            let updated = MuscleGroup(id: g.id, rawValue: trimmed, icon: icon, colorHex: colorHex)
            manager.update(updated)
        } else {
            // New custom group
            let newId = "custom_\(UUID().uuidString)"
            manager.add(MuscleGroup(id: newId, rawValue: trimmed, icon: icon, colorHex: colorHex))
        }
        dismiss()
    }
}
