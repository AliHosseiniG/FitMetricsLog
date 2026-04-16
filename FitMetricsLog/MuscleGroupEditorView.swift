//
//  MuscleGroupEditorView.swift
//  FlexCore
//
//  MuscleGroupManager is the single source of truth for ALL groups (built-in + custom).
//  Built-in groups can be renamed. Custom groups can be fully edited or deleted.
//

import SwiftUI
import PhotosUI
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

    func clearCustomizations() {
        overrides.removeAll()
        UserDefaults.standard.removeObject(forKey: customKey)
        UserDefaults.standard.removeObject(forKey: overrideKey)
        UserDefaults.standard.removeObject(forKey: "hiddenBuiltIns_v1")
        rebuildGroups()
    }

    /// Resize oversized muscle group images (safe — only shrinks, never deletes)
    func resizeStoredImages(maxDimension: CGFloat = 800) {
        var customsChanged = false
        var customs = customFromStore()
        for i in customs.indices {
            guard let data = customs[i].imageData,
                  let img = UIImage(data: data) else { continue }
            let sz = img.size
            let scale = min(maxDimension / sz.width, maxDimension / sz.height, 1.0)
            if scale >= 1.0 { continue }
            let newSz = CGSize(width: sz.width * scale, height: sz.height * scale)
            let renderer = UIGraphicsImageRenderer(size: newSz)
            let resized = renderer.image { _ in img.draw(in: CGRect(origin: .zero, size: newSz)) }
            if let newData = resized.jpegData(compressionQuality: 0.7) {
                customs[i].imageData = newData
                customsChanged = true
            }
        }
        if customsChanged { saveCustom(customs) }

        var overridesChanged = false
        for (key, var g) in overrides {
            guard let data = g.imageData, let img = UIImage(data: data) else { continue }
            let sz = img.size
            let scale = min(maxDimension / sz.width, maxDimension / sz.height, 1.0)
            if scale >= 1.0 { continue }
            let newSz = CGSize(width: sz.width * scale, height: sz.height * scale)
            let renderer = UIGraphicsImageRenderer(size: newSz)
            let resized = renderer.image { _ in img.draw(in: CGRect(origin: .zero, size: newSz)) }
            if let newData = resized.jpegData(compressionQuality: 0.7) {
                g.imageData = newData
                overrides[key] = g
                overridesChanged = true
            }
        }
        if overridesChanged { saveOverrides() }
        if customsChanged || overridesChanged { rebuildGroups() }
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
    @ObservedObject private var loc = LocalizationManager.shared
    @ObservedObject var manager = MuscleGroupManager.shared
    @Environment(\.dismiss) var dismiss
    @State private var editing: MuscleGroup?    = nil
    @State private var showingAdd               = false
    @State private var deleteTarget: MuscleGroup? = nil
    @State private var showDeleteAlert          = false
    @State private var fullscreenImage: UIImage? = nil

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
                    Text(L(.muscleGroupsTitle)).font(.system(size: 17, weight: .semibold)).foregroundColor(.white)
                    Spacer()
                    Button(action: { showingAdd = true }) {
                        Image(systemName: "plus.circle.fill").font(.system(size: 22)).foregroundColor(.orange)
                    }
                }
                .padding(.horizontal, 20).padding(.top, 55).padding(.bottom, 16)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        // Built-in (visible)
                        sectionLabel(L(.builtInGroups))
                        ForEach(builtIn) { g in
                            groupRow(g, isBuiltIn: true).padding(.horizontal, 20)
                        }
                        if builtIn.isEmpty {
                            Text(L(.allBuiltInHidden))
                                .font(.system(size: 13)).foregroundColor(.gray)
                                .padding(.horizontal, 20)
                        }

                        // Custom
                        if !custom.isEmpty {
                            sectionLabel(L(.myCustomGroups)).padding(.top, 8)
                            ForEach(custom) { g in
                                groupRow(g, isBuiltIn: false).padding(.horizontal, 20)
                            }
                        }

                        // Hidden built-ins with restore
                        let hiddenGroups = MuscleGroup.builtIn.filter { b in
                            !manager.groups.contains(where: { $0.id == b.id })
                        }
                        if !hiddenGroups.isEmpty {
                            sectionLabel(L(.hiddenGroupsHint)).padding(.top, 8)
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
                                Text(L(.tapToAddCustom)).font(.system(size: 14)).foregroundColor(.gray)
                            }.padding(.top, 30)
                        }

                        Spacer(minLength: 100)
                    }
                }
            }
        }
        .sheet(isPresented: $showingAdd) { MuscleGroupForm(existing: nil) }
        .sheet(item: $editing)           { g in MuscleGroupForm(existing: g) }
        .alert(L(.deleteGroup), isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) { if let g = deleteTarget { manager.delete(g) } }
            Button(L(.cancel), role: .cancel) {}
        } message: {
            if let g = deleteTarget, MuscleGroup.builtIn.contains(where: { $0.id == g.id }) {
                Text(L(.deleteBuiltInMsg))
            } else {
                Text(L(.noAffectLogs))
            }
        }
        .overlay {
            if let img = fullscreenImage {
                FullscreenImageViewer(
                    images: [img],
                    startIndex: 0,
                    onDismiss: { fullscreenImage = nil }
                )
                .transition(.opacity)
                .zIndex(99)
            }
        }
    }

    func sectionLabel(_ text: String) -> some View {
        Text(text).font(.system(size: 12, weight: .semibold)).foregroundColor(.gray)
            .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 20)
    }

    func groupRow(_ g: MuscleGroup, isBuiltIn: Bool) -> some View {
        HStack(spacing: 14) {
            ZStack {
                if let img = g.image {
                    Image(uiImage: img).resizable().scaledToFill()
                        .frame(width: 42, height: 42).clipped().cornerRadius(10)
                } else {
                    Image(systemName: g.icon).font(.system(size: 17)).foregroundColor(g.color)
                        .frame(width: 42, height: 42).background(g.color.opacity(0.15)).cornerRadius(10)
                }
            }
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
        .onTapGesture(count: 2) {
            if let img = g.image { fullscreenImage = img }
        }
    }
}

// MARK: - Group Form (create or edit any group)
struct MuscleGroupForm: View {
    @ObservedObject private var loc = LocalizationManager.shared
    var existing: MuscleGroup?
    @ObservedObject var manager = MuscleGroupManager.shared
    @Environment(\.dismiss) var dismiss

    @State private var name            = ""
    @State private var icon            = "figure.strengthtraining.functional"
    @State private var colorHex        = "FF6B00"
    @State private var imageData: Data? = nil
    @State private var showPicker      = false
    @State private var showCamera      = false
    @State private var showSource      = false
    @State private var imageToCrop: CropImageWrapper? = nil
    @State private var showCustomColor = false
    @State private var customColor     = Color.orange
    @FocusState private var nameFocused: Bool

    let colors = [
        // Oranges & Reds
        "FF6B00","FF4500","FF3B30","FF2D55","FF1744",
        // Pinks & Purples
        "FF2D8F","FF375F","AF52DE","BF5AF2","9C27B0",
        // Blues
        "007AFF","0A84FF","5AC8FA","5856D6","3634A3",
        // Teals & Greens
        "00C7BE","30D158","34C759","4CAF50","00BFA5",
        // Yellows & Ambers
        "FFCC00","FFD60A","FF9F0A","FF9500","FF6F00",
        // Browns & Neutrals
        "AC8250","A2845E","8E8E93","636366","48484A",
        // Special
        "E91E63","00897B","1565C0","6A1B9A","D84315"
    ]
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
                    Button(L(.cancel)) { dismiss() }.foregroundColor(.orange)
                    Spacer()
                    Text(isEditing ? (isBuiltIn ? L(.renameGroup) : L(.editGroup)) : L(.newGroup))
                        .font(.system(size: 17, weight: .semibold)).foregroundColor(.white)
                    Spacer()
                    Button(L(.save)) { save() }
                        .foregroundColor(name.trimmingCharacters(in: .whitespaces).isEmpty ? .gray : .orange)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(.horizontal, 20).padding(.top, 55).padding(.bottom, 20)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Preview card
                        ZStack(alignment: .bottomLeading) {
                            if let img = imageData.flatMap({ UIImage(data: $0) }) {
                                Image(uiImage: img).resizable().scaledToFill()
                                    .frame(maxWidth: .infinity).frame(height: 120)
                                    .clipped().cornerRadius(14)
                                // Gradient overlay
                                LinearGradient(colors: [.clear, .black.opacity(0.65)],
                                               startPoint: .top, endPoint: .bottom)
                                    .cornerRadius(14)
                            } else {
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color(hex: colorHex).opacity(0.15))
                                    .frame(maxWidth: .infinity).frame(height: 120)
                            }
                            HStack(spacing: 12) {
                                if imageData == nil {
                                    Image(systemName: icon).font(.system(size: 24))
                                        .foregroundColor(Color(hex: colorHex))
                                        .frame(width: 52, height: 52)
                                        .background(Color(hex: colorHex).opacity(0.2)).cornerRadius(12)
                                }
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(name.isEmpty ? "Group name" : name)
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(name.isEmpty ? .gray : .white)
                                    Text(isBuiltIn ? "Built-in Group" : "Custom Group")
                                        .font(.system(size: 11)).foregroundColor(.white.opacity(0.6))
                                }
                                Spacer()
                            }.padding(14)
                        }
                        .onTapGesture { showSource = true }
                        .overlay(
                            // camera button top-right
                            Button(action: { showSource = true }) {
                                Image(systemName: imageData == nil ? "camera.fill" : "camera.badge.ellipsis")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.white)
                                    .padding(8)
                                    .background(Color.black.opacity(0.55)).clipShape(Circle())
                            }.padding(10),
                            alignment: .topTrailing
                        )
                        .overlay(
                            Group {
                                if imageData != nil {
                                    Button(action: { imageData = nil }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 20)).foregroundColor(.white.opacity(0.8))
                                    }.padding(10)
                                }
                            },
                            alignment: .topLeading
                        )

                        // Name
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L(.groupName)).font(.system(size: 13)).foregroundColor(.gray)
                            TextField(L(.groupNamePlaceholder), text: $name)
                                .foregroundColor(.white).focused($nameFocused)
                                .padding(14).background(Color(hex: "1C1C1E")).cornerRadius(12)
                        }

                        // Colors
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text(L(.colorLabel)).font(.system(size: 13)).foregroundColor(.gray)
                                Spacer()
                                // Custom color picker button
                                Button(action: { showCustomColor = true }) {
                                    HStack(spacing: 6) {
                                        ZStack {
                                            // Rainbow ring
                                            Circle()
                                                .stroke(AngularGradient(colors: [
                                                    .red,.orange,.yellow,.green,.cyan,.blue,.purple,.pink,.red
                                                ], center: .center), lineWidth: 3)
                                                .frame(width: 22, height: 22)
                                            Circle().fill(Color(hex: colorHex)).frame(width: 14, height: 14)
                                        }
                                        Text(L(.custom)).font(.system(size: 12)).foregroundColor(.orange)
                                    }
                                    .padding(.horizontal, 10).padding(.vertical, 5)
                                    .background(Color.orange.opacity(0.12)).cornerRadius(8)
                                }
                            }

                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 10) {
                                ForEach(colors, id: \.self) { hex in
                                    Button(action: { colorHex = hex }) {
                                        Circle().fill(Color(hex: hex)).frame(height: 34)
                                            .overlay(Circle().stroke(Color.white, lineWidth: colorHex == hex ? 2.5 : 0))
                                            .overlay(
                                                colorHex == hex ?
                                                Image(systemName: "checkmark")
                                                    .font(.system(size: 10, weight: .bold))
                                                    .foregroundColor(.white) : nil
                                            )
                                            .scaleEffect(colorHex == hex ? 1.1 : 1)
                                            .animation(.spring(response: 0.2), value: colorHex)
                                    }
                                }
                            }
                        }
                        .padding(14).background(Color(hex: "1C1C1E")).cornerRadius(14)

                        // Icons
                        VStack(alignment: .leading, spacing: 10) {
                            Text(L(.iconLabel)).font(.system(size: 13)).foregroundColor(.gray)
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
        .sheet(isPresented: $showPicker) {
            MuscleGroupPhotoPicker { img in
                if let img { imageToCrop = CropImageWrapper(image: img) }
            }
        }
        .sheet(isPresented: $showCamera) {
            CameraWrapper { img in
                if let img { imageToCrop = CropImageWrapper(image: img) }
            }
        }
        .fullScreenCover(item: $imageToCrop) { wrapper in
            ImageCropperView(image: wrapper.image) { cropped in
                // Resize to max 800px before encoding to keep memory reasonable
                let resized = mgResize(cropped, maxDimension: 800)
                imageData = resized.jpegData(compressionQuality: 0.7)
                imageToCrop = nil
            } onCancel: {
                imageToCrop = nil
            }
        }
        .confirmationDialog("Add Photo", isPresented: $showSource) {
            Button("Choose from Library") { showPicker = true }
            Button("Take Photo") { showCamera = true }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showCustomColor) {
            CustomColorPickerSheet(selectedHex: $colorHex)
        }
        .onAppear {
            if let g = existing {
                name = g.rawValue; icon = g.icon; colorHex = g.colorHex
                imageData = g.imageData
            }
        }
    }

    func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        if let g = existing {
            var updated = MuscleGroup(id: g.id, rawValue: trimmed, icon: icon, colorHex: colorHex)
            updated.imageData = imageData
            manager.update(updated)
        } else {
            let newId = "custom_\(UUID().uuidString)"
            var newGroup = MuscleGroup(id: newId, rawValue: trimmed, icon: icon, colorHex: colorHex)
            newGroup.imageData = imageData
            manager.add(newGroup)
        }
        dismiss()
    }

    func mgResize(_ img: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = img.size
        let scale = min(maxDimension / size.width, maxDimension / size.height, 1.0)
        if scale >= 1.0 { return img }
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in img.draw(in: CGRect(origin: .zero, size: newSize)) }
    }
}

// MARK: - Photo Picker for Muscle Group
struct MuscleGroupPhotoPicker: UIViewControllerRepresentable {
    let onSelect: (UIImage?) -> Void
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images; config.selectionLimit = 1
        let vc = PHPickerViewController(configuration: config)
        vc.delegate = context.coordinator
        return vc
    }
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(onSelect: onSelect) }
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onSelect: (UIImage?) -> Void
        init(onSelect: @escaping (UIImage?) -> Void) { self.onSelect = onSelect }
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard let provider = results.first?.itemProvider,
                  provider.canLoadObject(ofClass: UIImage.self) else { onSelect(nil); return }
            provider.loadObject(ofClass: UIImage.self) { obj, _ in
                DispatchQueue.main.async { self.onSelect(obj as? UIImage) }
            }
        }
    }
}

// MARK: - Custom Color Picker Sheet
struct CustomColorPickerSheet: View {
    @ObservedObject private var loc = LocalizationManager.shared
    @Binding var selectedHex: String
    @Environment(\.dismiss) var dismiss

    @State private var r: Double = 1.0
    @State private var g: Double = 0.42
    @State private var b: Double = 0.0
    @State private var hexInput  = "FF6B00"
    @State private var hexError  = false

    var currentColor: Color { Color(red: r, green: g, blue: b) }
    var currentHex: String {
        let ri = Int(r * 255), gi = Int(g * 255), bi = Int(b * 255)
        return String(format: "%02X%02X%02X", ri, gi, bi)
    }

    // Preset swatches for quick pick
    let swatches: [[String]] = [
        ["FF0000","FF4500","FF6B00","FF9500","FFCC00"],
        ["FFD700","ADFF2F","00FF7F","00FA9A","00FFFF"],
        ["00BFFF","1E90FF","4169E1","8A2BE2","DA70D6"],
        ["FF69B4","FF1493","DC143C","B22222","8B0000"],
        ["FFFFFF","C0C0C0","808080","404040","000000"],
    ]

    var body: some View {
        ZStack {
            Color(hex: "111111").ignoresSafeArea()
            VStack(spacing: 0) {
                // Nav bar
                HStack {
                    Button(L(.cancel)) { dismiss() }.foregroundColor(.orange)
                    Spacer()
                    Text(L(.customColor)).font(.system(size: 17, weight: .semibold)).foregroundColor(.white)
                    Spacer()
                    Button(L(.apply)) {
                        selectedHex = currentHex
                        dismiss()
                    }.font(.system(size: 15, weight: .semibold)).foregroundColor(.orange)
                }
                .padding(.horizontal, 20).padding(.top, 55).padding(.bottom, 20)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {

                        // ── Preview ──
                        ZStack {
                            // Checkerboard (transparency bg)
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white.opacity(0.05))
                                .frame(height: 90)
                            RoundedRectangle(cornerRadius: 16)
                                .fill(currentColor)
                                .frame(height: 90)
                            Text("#\(currentHex)")
                                .font(.system(size: 16, weight: .semibold, design: .monospaced))
                                .foregroundColor(r + g + b > 1.5 ? .black.opacity(0.6) : .white.opacity(0.8))
                        }
                        .padding(.horizontal, 20)

                        // ── RGB Sliders ──
                        VStack(spacing: 14) {
                            colorSlider(label: "R", value: $r,
                                        trackColor: Color(red: r, green: 0, blue: 0),
                                        brightColor: .red)
                            colorSlider(label: "G", value: $g,
                                        trackColor: Color(red: 0, green: g, blue: 0),
                                        brightColor: .green)
                            colorSlider(label: "B", value: $b,
                                        trackColor: Color(red: 0, green: 0, blue: b),
                                        brightColor: .blue)
                        }
                        .padding(16).background(Color(hex: "1C1C1E")).cornerRadius(14)
                        .padding(.horizontal, 20)
                        .onChange(of: r) { _ in hexInput = currentHex }
                        .onChange(of: g) { _ in hexInput = currentHex }
                        .onChange(of: b) { _ in hexInput = currentHex }

                        // ── Hex Input ──
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L(.hexCode)).font(.system(size: 13)).foregroundColor(.gray)
                            HStack(spacing: 10) {
                                Text("#").font(.system(size: 16, weight: .medium, design: .monospaced))
                                    .foregroundColor(.gray)
                                TextField("FF6B00", text: $hexInput)
                                    .font(.system(size: 16, weight: .medium, design: .monospaced))
                                    .foregroundColor(hexError ? .red : .white)
                                    .textInputAutocapitalization(.characters)
                                    .autocorrectionDisabled()
                                    .onChange(of: hexInput) { val in
                                        let clean = val.uppercased().filter { "0123456789ABCDEF".contains($0) }
                                        if clean.count <= 6 {
                                            hexInput = clean
                                            if clean.count == 6 {
                                                applyHex(clean)
                                                hexError = false
                                            } else if clean.count > 0 {
                                                hexError = true
                                            }
                                        }
                                    }
                                Spacer()
                                Circle().fill(currentColor).frame(width: 28, height: 28)
                                    .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))
                            }
                            .padding(14).background(Color(hex: "2C2C2C")).cornerRadius(12)
                            if hexError {
                                Text(L(.enterValidHex)).font(.system(size: 11)).foregroundColor(.red)
                            }
                        }
                        .padding(.horizontal, 20)

                        // ── Swatch Presets ──
                        VStack(alignment: .leading, spacing: 10) {
                            Text(L(.presets)).font(.system(size: 13)).foregroundColor(.gray)
                            VStack(spacing: 8) {
                                ForEach(swatches, id: \.self) { row in
                                    HStack(spacing: 8) {
                                        ForEach(row, id: \.self) { hex in
                                            Button(action: {
                                                hexInput = hex
                                                applyHex(hex)
                                            }) {
                                                RoundedRectangle(cornerRadius: 8)
                                                    .fill(Color(hex: hex))
                                                    .frame(height: 36)
                                                    .overlay(
                                                        currentHex == hex ?
                                                        RoundedRectangle(cornerRadius: 8)
                                                            .stroke(Color.white, lineWidth: 2.5) : nil
                                                    )
                                                    .overlay(
                                                        currentHex == hex ?
                                                        Image(systemName: "checkmark")
                                                            .font(.system(size: 11, weight: .bold))
                                                            .foregroundColor(hex == "FFFFFF" || hex == "FFFF00" ? .black : .white)
                                                        : nil
                                                    )
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .padding(16).background(Color(hex: "1C1C1E")).cornerRadius(14)
                        .padding(.horizontal, 20)

                        Spacer(minLength: 80)
                    }
                }
            }
        }
        .onAppear { applyHex(selectedHex) }
    }

    func applyHex(_ hex: String) {
        guard hex.count == 6,
              let rv = UInt8(hex.prefix(2), radix: 16),
              let gv = UInt8(hex.dropFirst(2).prefix(2), radix: 16),
              let bv = UInt8(hex.dropFirst(4).prefix(2), radix: 16)
        else { return }
        r = Double(rv) / 255
        g = Double(gv) / 255
        b = Double(bv) / 255
    }

    func colorSlider(label: String, value: Binding<Double>,
                     trackColor: Color, brightColor: Color) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(brightColor)
                .frame(width: 16)
            ZStack(alignment: .leading) {
                // Track gradient
                LinearGradient(
                    colors: [Color(red: label == "R" ? 0 : r,
                                   green: label == "G" ? 0 : g,
                                   blue: label == "B" ? 0 : b),
                             Color(red: label == "R" ? 1 : r,
                                   green: label == "G" ? 1 : g,
                                   blue: label == "B" ? 1 : b)],
                    startPoint: .leading, endPoint: .trailing
                )
                .frame(height: 6).cornerRadius(3)
                Slider(value: value, in: 0...1)
                    .tint(brightColor)
            }
            Text("\(Int(value.wrappedValue * 255))")
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.gray)
                .frame(width: 30, alignment: .trailing)
        }
    }
}
