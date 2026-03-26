//
//  AddExerciseView.swift
//  FlexCore
//
//  Features:
//  - Multi muscle group selection (chips, primary = first selected)
//  - Camera: PHPickerWrapper (no crash) + CameraWrapper
//  - Keyboard dismisses on background tap
//

import SwiftUI
import PhotosUI

extension Color {
    func toHex() -> String? {
        let ui = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard ui.getRed(&r, green: &g, blue: &b, alpha: &a) else { return nil }
        return String(format: "%02X%02X%02X", Int(r*255), Int(g*255), Int(b*255))
    }
}

struct AddExerciseView: View {
    @ObservedObject private var loc = LocalizationManager.shared
    @EnvironmentObject var exerciseStore: ExerciseStore
    @EnvironmentObject var logStore:      WorkoutLogStore
    @EnvironmentObject var planStore:     WorkoutPlanStore
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var muscleManager = MuscleGroupManager.shared

    var exerciseToEdit: Exercise? = nil

    @State private var name:         String               = ""
    @State private var desc:         String               = ""
    @State private var muscleGroups: [MuscleGroup]        = [.chest]   // multi-select, ordered
    @State private var difficulty:   Exercise.Difficulty  = .beginner
    @State private var duration:     Int                  = 10
    @State private var sets:         Int                  = 3
    @State private var reps:         Int                  = 10
    @State private var videoURL:     String               = ""
    @State private var tags:         String               = ""
    @State private var colorHex:     String               = "FF6B00"
    @State private var images:       [UIImage]            = []
    @State private var showPHPicker  = false
    @State private var showCamPicker = false
    @State private var showSource    = false
    @State private var showToast     = false
    @FocusState private var focused: Bool

    var isEditing: Bool { exerciseToEdit != nil }
    let colorPresets = [
        // Oranges & Reds
        "FF6B00","FF3B30","FF2D55","FF6B6B","FF9500",
        "FF5733","E74C3C","C0392B","FF8C69","FFA07A",
        // Yellows & Greens
        "FFCC00","FFD60A","FFEAA7","F1C40F","E67E22",
        "34C759","30D158","96CEB4","00C7BE","2ECC71",
        "27AE60","1ABC9C","00B894","55EFC4","A8E6CF",
        // Blues & Purples
        "32ADE6","007AFF","45B7D1","3498DB","2980B9",
        "5856D6","AF52DE","BF5AF2","9B59B6","8E44AD",
        "6C5CE7","A29BFE","74B9FF","0984E3","00CEC9",
        // Pinks & Browns
        "FF2D55","FD79A8","E84393","C9184A","FF4DA6",
        "AC8E68","D2A679","A0522D","8B4513","795548",
        // Neutrals
        "636366","8E8E93","B2BEC3","DFE6E9","FFFFFF",
        "2D3436","1E272E","000000","34495E","7F8C8D"
    ]
    @State private var showCustomColorPicker = false
    @State private var customColor: Color = .orange

    var body: some View {
        ZStack {
            Color(hex: "111111").ignoresSafeArea()
                .onTapGesture { focused = false }
            VStack(spacing: 0) {
                topBar
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        imageSection
                        formSection
                        colorSection
                        saveButton
                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, 20).padding(.top, 10)
                }
            }
            if showToast {
                VStack {
                    Spacer()
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                        Text(L(.exerciseSaved))
                            .font(.system(size: 14, weight: .semibold)).foregroundColor(.white)
                    }
                    .padding(.horizontal, 24).padding(.vertical, 14)
                    .background(Color(hex: "2C2C2C")).cornerRadius(30)
                    .shadow(color: .black.opacity(0.5), radius: 10)
                    .padding(.bottom, 110)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(10)
            }
        }
        .onAppear(perform: prefill)
        .sheet(isPresented: $showPHPicker)  { PHPickerWrapper  { img in if let img, images.count < 6 { images.append(img) } } }
        .sheet(isPresented: $showCamPicker) { CameraWrapper    { img in if let img, images.count < 6 { images.append(img) } } }
        .confirmationDialog("Add Photo", isPresented: $showSource) {
            Button(L(.chooseFromLibrary)) { showPHPicker  = true }
            Button(L(.takePhoto)) { showCamPicker = true }
            Button(L(.cancel), role: .cancel) {}
        }
    }

    // MARK: Top bar
    var topBar: some View {
        HStack {
            Button(action: { dismiss() }) {
                HStack(spacing: 5) {
                    Image(systemName: "chevron.left").font(.system(size: 14, weight: .semibold))
                    Text(L(.cancel))
                }.foregroundColor(.orange)
            }
            Spacer()
            Text(isEditing ? L(.editExercise) : L(.newExercise))
                .font(.system(size: 17, weight: .semibold)).foregroundColor(.white)
            Spacer()
            HStack(spacing: 5) {
                Image(systemName: "chevron.left").font(.system(size: 14))
                Text("Cancel")
            }.foregroundColor(.clear)
        }
        .padding(.horizontal, 20).padding(.top, 55).padding(.bottom, 14)
    }

    // MARK: Images
    var imageSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(L(.photos)).font(.system(size: 14, weight: .medium)).foregroundColor(.gray)
                Spacer()
                Text("\(images.count)/6").font(.system(size: 12)).foregroundColor(.gray)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Array(images.enumerated()), id: \.offset) { idx, img in
                        ZStack(alignment: .topTrailing) {
                            Image(uiImage: img).resizable().scaledToFill()
                                .frame(width: 110, height: 110).clipped().cornerRadius(12)
                            Button(action: { images.remove(at: idx) }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 20)).foregroundColor(.white)
                                    .background(Color.black.opacity(0.5).clipShape(Circle()))
                            }.offset(x: 6, y: -6)
                        }
                    }
                    if images.count < 6 {
                        Button(action: { showSource = true }) {
                            VStack(spacing: 8) {
                                Image(systemName: "camera.fill").font(.system(size: 22)).foregroundColor(.orange)
                                Text(L(.addPhoto)).font(.system(size: 11)).foregroundColor(.gray)
                            }
                            .frame(width: 110, height: 110).background(Color(hex: "1C1C1E")).cornerRadius(12)
                            .overlay(RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.orange.opacity(0.4), style: StrokeStyle(lineWidth: 1.5, dash: [5])))
                        }
                    }
                }
            }
        }
    }

    // MARK: Form
    var formSection: some View {
        VStack(spacing: 14) {
            FormField(title: L(.exerciseName)) {
                TextField("e.g. Bench Press", text: $name)
                    .foregroundColor(.white).focused($focused)
            }
            FormField(title: L(.exerciseDesc)) {
                ZStack(alignment: .topLeading) {
                    if desc.isEmpty {
                        Text(L(.exerciseDesc) + "...")
                            .foregroundColor(.gray.opacity(0.5)).font(.system(size: 14)).padding(2)
                    }
                    TextEditor(text: $desc).foregroundColor(.white).frame(minHeight: 80)
                        .scrollContentBackground(.hidden).focused($focused)
                }
            }

            // ── Multi Muscle Group Selector ──
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(L(.muscleGroups)).font(.system(size: 13, weight: .medium)).foregroundColor(.gray)
                    Spacer()
                    if muscleGroups.count > 1 {
                        Text("Primary: \(muscleGroups[0].rawValue)")
                            .font(.system(size: 11)).foregroundColor(.orange)
                    }
                }
                if muscleGroups.isEmpty {
                    Text("Select at least one muscle group")
                        .font(.system(size: 12)).foregroundColor(.red.opacity(0.8))
                }
                // Selected groups (ordered — first is primary)
                if !muscleGroups.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(Array(muscleGroups.enumerated()), id: \.element.id) { idx, g in
                                HStack(spacing: 5) {
                                    if idx == 0 {
                                        Image(systemName: "star.fill")
                                            .font(.system(size: 8)).foregroundColor(.white.opacity(0.9))
                                    }
                                    Image(systemName: g.icon).font(.system(size: 11))
                                    Text(g.rawValue).font(.system(size: 12, weight: .semibold))
                                    Button(action: { removeGroup(g) }) {
                                        Image(systemName: "xmark").font(.system(size: 9, weight: .bold))
                                    }
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 10).padding(.vertical, 6)
                                .background(g.color)
                                .cornerRadius(8)
                            }
                        }
                    }
                }
                // All available groups to toggle
                Text("Tap to add/remove:").font(.system(size: 11)).foregroundColor(.gray)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 90))], spacing: 8) {
                    ForEach(muscleManager.groups) { g in
                        let selected = muscleGroups.contains(g)
                        Button(action: { toggleGroup(g) }) {
                            HStack(spacing: 5) {
                                Image(systemName: g.icon).font(.system(size: 11))
                                Text(g.rawValue).font(.system(size: 11, weight: .medium))
                                if selected {
                                    Spacer()
                                    Image(systemName: "checkmark").font(.system(size: 9, weight: .bold))
                                }
                            }
                            .foregroundColor(selected ? .white : g.color)
                            .padding(.horizontal, 10).padding(.vertical, 7)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(selected ? g.color : g.color.opacity(0.12))
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8)
                                .stroke(g.color.opacity(selected ? 0 : 0.4), lineWidth: 1))
                        }
                        .animation(.spring(response: 0.2), value: muscleGroups)
                    }
                }
            }
            .padding(14).background(Color(hex: "1C1C1E")).cornerRadius(12)

            FormField(title: L(.difficulty)) {
                Picker("", selection: $difficulty) {
                    ForEach(Exercise.Difficulty.allCases, id: \.self) { Text($0.localizedLabel).tag($0) }
                }.pickerStyle(.segmented)
            }
            HStack(spacing: 10) {
                NumField(title: L(.duration) + " (min)", value: $duration, range: 1...180)
                NumField(title: L(.sets), value: $sets, range: 1...20)
                NumField(title: L(.reps), value: $reps, range: 1...100)
            }
            FormField(title: L(.tags)) {
                TextField("strength, compound...", text: $tags).foregroundColor(.white).focused($focused)
            }
            FormField(title: L(.videoURL) + " (optional)") {
                TextField("https://youtu.be/...", text: $videoURL)
                    .foregroundColor(.white).autocapitalization(.none).keyboardType(.URL).focused($focused)
            }
        }
    }

    // MARK: Color
    var colorSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(L(.chartColor)).font(.system(size: 14, weight: .medium)).foregroundColor(.gray)
                Spacer()
                Circle().fill(Color(hex: colorHex)).frame(width: 24, height: 24)
                    .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 1))
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 8) {
                ForEach(colorPresets, id: \.self) { hex in
                    Button(action: { colorHex = hex }) {
                        Circle().fill(Color(hex: hex)).frame(height: 30)
                            .overlay(Circle().stroke(Color.white, lineWidth: colorHex == hex ? 2.5 : 0))
                            .scaleEffect(colorHex == hex ? 1.12 : 1)
                            .animation(.spring(response: 0.3), value: colorHex)
                    }
                }
                // Custom color button
                Button(action: { showCustomColorPicker = true }) {
                    ZStack {
                        Circle()
                            .fill(AngularGradient(colors: [.red,.orange,.yellow,.green,.blue,.purple,.red],
                                                  center: .center))
                            .frame(height: 30)
                        if !colorPresets.contains(colorHex) {
                            Circle().stroke(Color.white, lineWidth: 2.5).frame(height: 30)
                        }
                        Image(systemName: "plus").font(.system(size: 12, weight: .bold)).foregroundColor(.white)
                    }
                }
            }
            if showCustomColorPicker {
                ColorPicker("Custom Color", selection: $customColor, supportsOpacity: false)
                    .foregroundColor(.white)
                    .onChange(of: customColor) { c in
                        if let hex = c.toHex() { colorHex = hex }
                    }
                    .padding(.top, 4)
            }
        }
        .padding(14).background(Color(hex: "1C1C1E")).cornerRadius(14)
    }

    var saveButton: some View {
        let ok = !name.trimmingCharacters(in: .whitespaces).isEmpty && !muscleGroups.isEmpty
        return Button(action: save) {
            HStack(spacing: 8) {
                Image(systemName: isEditing ? "checkmark.circle.fill" : "plus.circle.fill")
                Text(isEditing ? "Save Changes" : "Add Exercise")
                    .font(.system(size: 17, weight: .semibold))
            }
            .foregroundColor(.white).frame(maxWidth: .infinity).frame(height: 56)
            .background(LinearGradient(colors: [.orange, .orange.opacity(0.8)],
                                       startPoint: .leading, endPoint: .trailing))
            .cornerRadius(28)
        }
        .disabled(!ok).opacity(ok ? 1 : 0.45).padding(.top, 4)
    }

    // MARK: Helpers
    func toggleGroup(_ g: MuscleGroup) {
        if let idx = muscleGroups.firstIndex(of: g) {
            muscleGroups.remove(at: idx)
        } else {
            muscleGroups.append(g)
        }
        // Update chart color to primary muscle
        if let primary = muscleGroups.first, customColorHexIsDefault() {
            colorHex = primary.colorHex
        }
    }

    func removeGroup(_ g: MuscleGroup) {
        muscleGroups.removeAll { $0 == g }
    }

    func customColorHexIsDefault() -> Bool {
        colorPresets.contains(colorHex)
    }

    func prefill() {
        guard let ex = exerciseToEdit else { return }
        name         = ex.name
        desc         = ex.description
        muscleGroups = ex.muscleGroups
        difficulty   = ex.difficulty
        duration     = ex.duration
        sets         = ex.sets
        reps         = ex.reps
        videoURL     = ex.videoURL
        tags         = ex.tags.joined(separator: ", ")
        images       = ex.images
        colorHex     = ex.customColorHex ?? ex.muscleGroup.colorHex
    }

    // Resize image to max dimension, keeping aspect ratio
    func resizedImage(_ img: UIImage, maxDimension: CGFloat = 900) -> UIImage {
        let size = img.size
        let scale = min(maxDimension / size.width, maxDimension / size.height, 1.0)
        if scale >= 1.0 { return img }
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in img.draw(in: CGRect(origin: .zero, size: newSize)) }
    }

    func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !muscleGroups.isEmpty else { return }
        let tagList = tags.components(separatedBy: CharacterSet(charactersIn: ",،"))
            .map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        let processedImages = images.map { resizedImage($0, maxDimension: 900) }
        var ex = Exercise(
            name: trimmed, description: desc,
            muscleGroups: muscleGroups,
            difficulty: difficulty, duration: duration,
            sets: sets, reps: reps,
            imageDatas: processedImages.compactMap { $0.jpegData(compressionQuality: 0.82) },
            videoURL: videoURL, tags: tagList, customColorHex: colorHex
        )
        if let existing = exerciseToEdit {
            ex.id = existing.id; ex.createdAt = existing.createdAt
            exerciseStore.update(ex)
            logStore.syncExerciseName(id: ex.id, newName: ex.name)
            planStore.syncExerciseName(id: ex.id, newName: ex.name)
            dismiss()
        } else {
            exerciseStore.add(ex)
            withAnimation(.spring()) { showToast = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.3) { withAnimation { showToast = false } }
            resetForm()
        }
    }

    func resetForm() {
        name = ""; desc = ""; muscleGroups = [.chest]; difficulty = .beginner
        duration = 10; sets = 3; reps = 10; videoURL = ""; tags = ""
        images = []; colorHex = "FF6B00"
    }
}

// MARK: - FormField + NumField (defined once here)
struct FormField<Content: View>: View {
    let title: String; let content: () -> Content
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.system(size: 13, weight: .medium)).foregroundColor(.gray)
            content().padding(14).background(Color(hex: "1C1C1E")).cornerRadius(12)
        }
    }
}

struct NumField: View {
    let title: String; @Binding var value: Int; let range: ClosedRange<Int>
    var body: some View {
        VStack(spacing: 6) {
            Text(title).font(.system(size: 10)).foregroundColor(.gray).multilineTextAlignment(.center)
            HStack(spacing: 0) {
                Button(action: { if value > range.lowerBound { value -= 1 } }) {
                    Image(systemName: "minus").font(.system(size: 12)).foregroundColor(.orange)
                        .frame(width: 28, height: 34)
                }
                Text("\(value)").font(.system(size: 15, weight: .bold)).foregroundColor(.white)
                    .frame(minWidth: 30)
                Button(action: { if value < range.upperBound { value += 1 } }) {
                    Image(systemName: "plus").font(.system(size: 12)).foregroundColor(.orange)
                        .frame(width: 28, height: 34)
                }
            }.background(Color(hex: "1C1C1E")).cornerRadius(10)
        }.frame(maxWidth: .infinity)
    }
}

// MARK: - PHPicker (library, no crash)
struct PHPickerWrapper: UIViewControllerRepresentable {
    var onSelect: (UIImage?) -> Void
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var cfg = PHPickerConfiguration(); cfg.filter = .images; cfg.selectionLimit = 1
        let vc = PHPickerViewController(configuration: cfg); vc.delegate = context.coordinator; return vc
    }
    func updateUIViewController(_ vc: PHPickerViewController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let p: PHPickerWrapper; init(_ p: PHPickerWrapper) { self.p = p }
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard let prov = results.first?.itemProvider,
                  prov.canLoadObject(ofClass: UIImage.self) else { p.onSelect(nil); return }
            prov.loadObject(ofClass: UIImage.self) { obj, _ in
                DispatchQueue.main.async { self.p.onSelect(obj as? UIImage) }
            }
        }
    }
}

// MARK: - Camera Wrapper
struct CameraWrapper: UIViewControllerRepresentable {
    var onCapture: (UIImage?) -> Void
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let vc = UIImagePickerController()
        vc.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        vc.delegate = context.coordinator; return vc
    }
    func updateUIViewController(_ vc: UIImagePickerController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let p: CameraWrapper; init(_ p: CameraWrapper) { self.p = p }
        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            p.onCapture(info[.originalImage] as? UIImage); picker.dismiss(animated: true)
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            p.onCapture(nil); picker.dismiss(animated: true)
        }
    }
}
