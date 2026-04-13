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
import AVKit
import AVFoundation

// Wrappers for fullScreenCover(item:)
struct CropImageWrapper: Identifiable {
    let id = UUID()
    let image: UIImage
}
struct CropVideoWrapper: Identifiable {
    let id = UUID()
    let url: URL
}

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
    @State private var localVideoFileName: String = ""
    @State private var videoThumbnail: UIImage? = nil
    @State private var showVideoSource   = false
    @State private var showVideoPHPicker = false
    @State private var showVideoRecorder = false
    @State private var showVideoPlayer   = false
    @State private var imageToCrop: CropImageWrapper? = nil
    @State private var videoToCropURL: CropVideoWrapper? = nil
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
                        videoSection
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
        .sheet(isPresented: $showPHPicker)  { PHPickerWrapper  { img in if let img { imageToCrop = CropImageWrapper(image: img) } } }
        .sheet(isPresented: $showCamPicker) { CameraWrapper    { img in if let img { imageToCrop = CropImageWrapper(image: img) } } }
        .sheet(isPresented: $showVideoPHPicker) {
            VideoPHPickerWrapper { url in
                guard let url else { return }
                videoToCropURL = CropVideoWrapper(url: url)
            }
        }
        .sheet(isPresented: $showVideoRecorder) {
            VideoRecorderWrapper { url in
                guard let url else { return }
                videoToCropURL = CropVideoWrapper(url: url)
            }
        }
        .fullScreenCover(isPresented: $showVideoPlayer) {
            if let url = VideoFileManager.url(for: localVideoFileName) {
                VideoPlayerFullscreen(url: url) { showVideoPlayer = false }
            }
        }
        .fullScreenCover(item: $imageToCrop) { wrapper in
            ImageCropperView(image: wrapper.image) { cropped in
                if images.count < 6 { images.append(cropped) }
                imageToCrop = nil
            } onCancel: {
                imageToCrop = nil
            }
        }
        .fullScreenCover(item: $videoToCropURL) { wrapper in
            VideoTrimmerView(sourceURL: wrapper.url) { trimmedURL in
                if let name = VideoFileManager.save(from: trimmedURL) {
                    localVideoFileName = name
                    videoThumbnail = VideoFileManager.thumbnail(for: name)
                }
                videoToCropURL = nil
            } onCancel: {
                videoToCropURL = nil
            }
        }
        .confirmationDialog("Add Photo", isPresented: $showSource) {
            Button(L(.chooseFromLibrary)) { showPHPicker  = true }
            Button(L(.takePhoto)) { showCamPicker = true }
            Button(L(.cancel), role: .cancel) {}
        }
        .confirmationDialog("Add Video", isPresented: $showVideoSource) {
            Button("Choose from Library") { showVideoPHPicker = true }
            Button("Record Video")        { showVideoRecorder = true }
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

    // MARK: Video
    var videoSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Video").font(.system(size: 14, weight: .medium)).foregroundColor(.gray)
                Spacer()
                if !localVideoFileName.isEmpty {
                    Text("1 video").font(.system(size: 12)).foregroundColor(.gray)
                }
            }
            if !localVideoFileName.isEmpty {
                ZStack(alignment: .topTrailing) {
                    Button(action: { showVideoPlayer = true }) {
                        ZStack {
                            if let thumb = videoThumbnail {
                                Image(uiImage: thumb).resizable().scaledToFill()
                                    .frame(maxWidth: .infinity, maxHeight: 180).clipped().cornerRadius(12)
                            } else {
                                RoundedRectangle(cornerRadius: 12).fill(Color(hex: "1C1C1E"))
                                    .frame(maxWidth: .infinity, maxHeight: 180)
                            }
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 44)).foregroundColor(.white.opacity(0.9))
                                .shadow(color: .black.opacity(0.5), radius: 4)
                        }
                    }
                    Button(action: {
                        VideoFileManager.delete(localVideoFileName)
                        localVideoFileName = ""
                        videoThumbnail = nil
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24)).foregroundColor(.white)
                            .background(Color.black.opacity(0.6).clipShape(Circle()))
                    }.offset(x: 6, y: -6)
                }
            } else {
                Button(action: { showVideoSource = true }) {
                    VStack(spacing: 8) {
                        Image(systemName: "video.fill").font(.system(size: 22)).foregroundColor(.orange)
                        Text("Add Video").font(.system(size: 11)).foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity).frame(height: 90)
                    .background(Color(hex: "1C1C1E")).cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.orange.opacity(0.4), style: StrokeStyle(lineWidth: 1.5, dash: [5])))
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
        localVideoFileName = ex.localVideoFileName
        if !ex.localVideoFileName.isEmpty {
            videoThumbnail = VideoFileManager.thumbnail(for: ex.localVideoFileName)
        }
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
            videoURL: videoURL, localVideoFileName: localVideoFileName,
            tags: tagList, customColorHex: colorHex
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
        images = []; colorHex = "FF6B00"; localVideoFileName = ""; videoThumbnail = nil
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
    @Environment(\.dismiss) private var dismiss
    var onCapture: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let vc = UIImagePickerController()
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            vc.sourceType = .camera
        } else {
            vc.sourceType = .photoLibrary
        }
        vc.delegate = context.coordinator
        return vc
    }
    func updateUIViewController(_ vc: UIImagePickerController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraWrapper
        init(_ parent: CameraWrapper) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            let image = info[.originalImage] as? UIImage
            DispatchQueue.main.async {
                self.parent.onCapture(image)
                self.parent.dismiss()
            }
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            DispatchQueue.main.async {
                self.parent.onCapture(nil)
                self.parent.dismiss()
            }
        }
    }
}

// MARK: - Video PHPicker (library)
struct VideoPHPickerWrapper: UIViewControllerRepresentable {
    var onSelect: (URL?) -> Void
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var cfg = PHPickerConfiguration()
        cfg.filter = .videos
        cfg.selectionLimit = 1
        let vc = PHPickerViewController(configuration: cfg)
        vc.delegate = context.coordinator
        return vc
    }
    func updateUIViewController(_ vc: PHPickerViewController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: VideoPHPickerWrapper
        init(_ parent: VideoPHPickerWrapper) { self.parent = parent }
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard let prov = results.first?.itemProvider else { parent.onSelect(nil); return }
            if prov.hasItemConformingToTypeIdentifier("public.movie") {
                prov.loadFileRepresentation(forTypeIdentifier: "public.movie") { url, _ in
                    DispatchQueue.main.async { self.parent.onSelect(url) }
                }
            } else {
                parent.onSelect(nil)
            }
        }
    }
}

// MARK: - Video Recorder
struct VideoRecorderWrapper: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    var onRecord: (URL?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let vc = UIImagePickerController()
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            vc.sourceType = .camera
            vc.mediaTypes = ["public.movie"]
            vc.videoMaximumDuration = 120
            vc.videoQuality = .typeMedium
        } else {
            vc.sourceType = .photoLibrary
            vc.mediaTypes = ["public.movie"]
        }
        vc.delegate = context.coordinator
        return vc
    }
    func updateUIViewController(_ vc: UIImagePickerController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: VideoRecorderWrapper
        init(_ parent: VideoRecorderWrapper) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            let url = info[.mediaURL] as? URL
            DispatchQueue.main.async {
                self.parent.onRecord(url)
                self.parent.dismiss()
            }
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            DispatchQueue.main.async {
                self.parent.onRecord(nil)
                self.parent.dismiss()
            }
        }
    }
}

// MARK: - Fullscreen Video Player
struct VideoPlayerFullscreen: View {
    let url: URL
    let onDismiss: () -> Void
    @State private var player: AVPlayer?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let player {
                VideoPlayer(player: player)
                    .ignoresSafeArea()
            }
            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        player?.pause()
                        onDismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.white)
                            .background(Color.black.opacity(0.5).clipShape(Circle()))
                    }
                    .padding(.top, 55).padding(.trailing, 20)
                }
                Spacer()
            }
        }
        .onAppear {
            player = AVPlayer(url: url)
            player?.play()
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
    }
}

// MARK: - Image Cropper View
struct ImageCropperView: View {
    let image: UIImage
    let onCrop: (UIImage) -> Void
    let onCancel: () -> Void

    // Crop edges stored independently for per-handle dragging
    @State private var cropTop: CGFloat = 0
    @State private var cropLeft: CGFloat = 0
    @State private var cropBottom: CGFloat = 0
    @State private var cropRight: CGFloat = 0

    @State private var imageRect: CGRect = .zero
    @State private var containerSize: CGSize = .zero
    @State private var isDragging = false

    private let minCrop: CGFloat = 50
    private let handleHit: CGFloat = 44   // touch target per Apple HIG
    private let cornerLen: CGFloat = 22
    private let cornerWt: CGFloat = 3.5
    private let edgeBarLen: CGFloat = 24
    private let edgeBarWt: CGFloat = 3.5

    private var cropRect: CGRect {
        CGRect(x: cropLeft, y: cropTop,
               width: cropRight - cropLeft,
               height: cropBottom - cropTop)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar
                HStack {
                    Button(action: onCancel) {
                        Text("Cancel").font(.system(size: 16, weight: .medium)).foregroundColor(.white)
                    }
                    Spacer()
                    Text("Crop").font(.system(size: 17, weight: .semibold)).foregroundColor(.white)
                    Spacer()
                    Button(action: performCrop) {
                        Text("Done").font(.system(size: 16, weight: .semibold)).foregroundColor(.orange)
                    }
                }
                .padding(.horizontal, 20).padding(.top, 55).padding(.bottom, 14)

                GeometryReader { geo in
                    let fitted = fittedImageRect(in: geo.size)
                    ZStack {
                        // Image
                        Image(uiImage: image)
                            .resizable().scaledToFit()
                            .frame(width: fitted.width, height: fitted.height)
                            .position(x: fitted.midX, y: fitted.midY)

                        // Dim overlay
                        dimOverlay(in: geo.size)

                        // Crop border
                        Rectangle()
                            .stroke(Color.white, lineWidth: 1.5)
                            .frame(width: cropRect.width, height: cropRect.height)
                            .position(x: cropRect.midX, y: cropRect.midY)
                            .allowsHitTesting(false)

                        // Grid lines (only while dragging)
                        if isDragging { gridLines.allowsHitTesting(false) }

                        // Corner brackets (visual only)
                        cornerBrackets.allowsHitTesting(false)

                        // Edge bars (visual only)
                        edgeBars.allowsHitTesting(false)

                        // ── Draggable handles (large invisible hit areas) ──
                        // Corners
                        cornerTL(fitted).position(x: cropLeft, y: cropTop)
                        cornerTR(fitted).position(x: cropRight, y: cropTop)
                        cornerBL(fitted).position(x: cropLeft, y: cropBottom)
                        cornerBR(fitted).position(x: cropRight, y: cropBottom)

                        // Edges
                        edgeT(fitted).position(x: cropRect.midX, y: cropTop)
                        edgeB(fitted).position(x: cropRect.midX, y: cropBottom)
                        edgeL(fitted).position(x: cropLeft, y: cropRect.midY)
                        edgeR(fitted).position(x: cropRight, y: cropRect.midY)

                        // Move crop area by dragging inside
                        Rectangle()
                            .fill(Color.white.opacity(0.001))
                            .frame(width: max(cropRect.width - handleHit * 2, 10),
                                   height: max(cropRect.height - handleHit * 2, 10))
                            .position(x: cropRect.midX, y: cropRect.midY)
                            .gesture(moveDrag(fitted))
                    }
                    .onAppear {
                        containerSize = geo.size
                        let r = fittedImageRect(in: geo.size)
                        imageRect = r
                        cropTop = r.minY; cropLeft = r.minX
                        cropBottom = r.maxY; cropRight = r.maxX
                    }
                }
            }
        }
    }

    // MARK: Fitted image rect
    func fittedImageRect(in container: CGSize) -> CGRect {
        let imgAspect = image.size.width / image.size.height
        let containerAspect = container.width / container.height
        var w: CGFloat, h: CGFloat
        if imgAspect > containerAspect {
            w = container.width; h = w / imgAspect
        } else {
            h = container.height; w = h * imgAspect
        }
        return CGRect(x: (container.width - w) / 2,
                      y: (container.height - h) / 2,
                      width: w, height: h)
    }

    // MARK: Dim overlay
    func dimOverlay(in size: CGSize) -> some View {
        Canvas { ctx, sz in
            var p = Path()
            p.addRect(CGRect(origin: .zero, size: sz))
            p.addRect(cropRect)
            ctx.fill(p, with: .color(.black.opacity(0.6)), style: FillStyle(eoFill: true))
        }
        .allowsHitTesting(false)
    }

    // MARK: Grid
    var gridLines: some View {
        Canvas { ctx, _ in
            let w3 = cropRect.width / 3, h3 = cropRect.height / 3
            for i in 1...2 {
                var v = Path()
                v.move(to: .init(x: cropLeft + w3 * CGFloat(i), y: cropTop))
                v.addLine(to: .init(x: cropLeft + w3 * CGFloat(i), y: cropBottom))
                ctx.stroke(v, with: .color(.white.opacity(0.35)), lineWidth: 0.5)
                var h = Path()
                h.move(to: .init(x: cropLeft, y: cropTop + h3 * CGFloat(i)))
                h.addLine(to: .init(x: cropRight, y: cropTop + h3 * CGFloat(i)))
                ctx.stroke(h, with: .color(.white.opacity(0.35)), lineWidth: 0.5)
            }
        }
    }

    // MARK: Corner brackets
    var cornerBrackets: some View {
        Canvas { ctx, _ in
            func draw(_ cx: CGFloat, _ cy: CGFloat, _ dx: CGFloat, _ dy: CGFloat) {
                var p = Path()
                p.move(to: .init(x: cx, y: cy + dy * cornerLen))
                p.addLine(to: .init(x: cx, y: cy))
                p.addLine(to: .init(x: cx + dx * cornerLen, y: cy))
                ctx.stroke(p, with: .color(.white), lineWidth: cornerWt)
            }
            draw(cropLeft, cropTop, 1, 1)
            draw(cropRight, cropTop, -1, 1)
            draw(cropLeft, cropBottom, 1, -1)
            draw(cropRight, cropBottom, -1, -1)
        }
    }

    // MARK: Edge bars (midpoint markers)
    var edgeBars: some View {
        Canvas { ctx, _ in
            let mx = cropRect.midX, my = cropRect.midY
            func hBar(_ y: CGFloat) {
                var p = Path()
                p.move(to: .init(x: mx - edgeBarLen, y: y))
                p.addLine(to: .init(x: mx + edgeBarLen, y: y))
                ctx.stroke(p, with: .color(.white), lineWidth: edgeBarWt)
            }
            func vBar(_ x: CGFloat) {
                var p = Path()
                p.move(to: .init(x: x, y: my - edgeBarLen))
                p.addLine(to: .init(x: x, y: my + edgeBarLen))
                ctx.stroke(p, with: .color(.white), lineWidth: edgeBarWt)
            }
            hBar(cropTop); hBar(cropBottom)
            vBar(cropLeft); vBar(cropRight)
        }
    }

    // MARK: Draggable handle — stores anchor at drag start, applies accumulated translation
    struct CropHandle: View {
        let width: CGFloat
        let height: CGFloat
        let onStart: () -> Void
        let onDrag: (CGFloat, CGFloat) -> Void
        let onEnd: () -> Void

        var body: some View {
            Color.clear
                .frame(width: width, height: height)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 1)
                        .onChanged { v in
                            if v.translation == .zero { onStart() }
                            onDrag(v.translation.width, v.translation.height)
                        }
                        .onEnded { _ in onEnd() }
                )
        }
    }

    // Anchors saved at drag start
    @State private var anchorTop: CGFloat = 0
    @State private var anchorLeft: CGFloat = 0
    @State private var anchorBottom: CGFloat = 0
    @State private var anchorRight: CGFloat = 0

    func saveAnchors() {
        anchorTop = cropTop; anchorLeft = cropLeft
        anchorBottom = cropBottom; anchorRight = cropRight
        isDragging = true
    }
    func endDrag() { isDragging = false }

    func cornerTL(_ img: CGRect) -> some View {
        CropHandle(width: handleHit, height: handleHit,
                   onStart: { saveAnchors() },
                   onDrag: { dX, dY in
                       cropLeft = max(img.minX, min(anchorRight - minCrop, anchorLeft + dX))
                       cropTop = max(img.minY, min(anchorBottom - minCrop, anchorTop + dY))
                   },
                   onEnd: { endDrag() })
    }
    func cornerTR(_ img: CGRect) -> some View {
        CropHandle(width: handleHit, height: handleHit,
                   onStart: { saveAnchors() },
                   onDrag: { dX, dY in
                       cropRight = min(img.maxX, max(anchorLeft + minCrop, anchorRight + dX))
                       cropTop = max(img.minY, min(anchorBottom - minCrop, anchorTop + dY))
                   },
                   onEnd: { endDrag() })
    }
    func cornerBL(_ img: CGRect) -> some View {
        CropHandle(width: handleHit, height: handleHit,
                   onStart: { saveAnchors() },
                   onDrag: { dX, dY in
                       cropLeft = max(img.minX, min(anchorRight - minCrop, anchorLeft + dX))
                       cropBottom = min(img.maxY, max(anchorTop + minCrop, anchorBottom + dY))
                   },
                   onEnd: { endDrag() })
    }
    func cornerBR(_ img: CGRect) -> some View {
        CropHandle(width: handleHit, height: handleHit,
                   onStart: { saveAnchors() },
                   onDrag: { dX, dY in
                       cropRight = min(img.maxX, max(anchorLeft + minCrop, anchorRight + dX))
                       cropBottom = min(img.maxY, max(anchorTop + minCrop, anchorBottom + dY))
                   },
                   onEnd: { endDrag() })
    }
    func edgeT(_ img: CGRect) -> some View {
        CropHandle(width: max(cropRect.width - handleHit * 2, 10), height: handleHit,
                   onStart: { saveAnchors() },
                   onDrag: { _, dY in cropTop = max(img.minY, min(anchorBottom - minCrop, anchorTop + dY)) },
                   onEnd: { endDrag() })
    }
    func edgeB(_ img: CGRect) -> some View {
        CropHandle(width: max(cropRect.width - handleHit * 2, 10), height: handleHit,
                   onStart: { saveAnchors() },
                   onDrag: { _, dY in cropBottom = min(img.maxY, max(anchorTop + minCrop, anchorBottom + dY)) },
                   onEnd: { endDrag() })
    }
    func edgeL(_ img: CGRect) -> some View {
        CropHandle(width: handleHit, height: max(cropRect.height - handleHit * 2, 10),
                   onStart: { saveAnchors() },
                   onDrag: { dX, _ in cropLeft = max(img.minX, min(anchorRight - minCrop, anchorLeft + dX)) },
                   onEnd: { endDrag() })
    }
    func edgeR(_ img: CGRect) -> some View {
        CropHandle(width: handleHit, height: max(cropRect.height - handleHit * 2, 10),
                   onStart: { saveAnchors() },
                   onDrag: { dX, _ in cropRight = min(img.maxX, max(anchorLeft + minCrop, anchorRight + dX)) },
                   onEnd: { endDrag() })
    }
    func moveDrag(_ imgRect: CGRect) -> some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { v in
                if !isDragging { saveAnchors() }
                let w = anchorRight - anchorLeft, h = anchorBottom - anchorTop
                var newL = anchorLeft + v.translation.width
                var newT = anchorTop + v.translation.height
                newL = max(imgRect.minX, min(newL, imgRect.maxX - w))
                newT = max(imgRect.minY, min(newT, imgRect.maxY - h))
                cropLeft = newL; cropRight = newL + w
                cropTop = newT; cropBottom = newT + h
            }
            .onEnded { _ in endDrag() }
    }

    // MARK: Perform crop
    func performCrop() {
        guard imageRect.width > 0, imageRect.height > 0 else { onCrop(image); return }
        let scaleX = image.size.width / imageRect.width
        let scaleY = image.size.height / imageRect.height
        let pixelRect = CGRect(
            x: (cropLeft - imageRect.minX) * scaleX,
            y: (cropTop - imageRect.minY) * scaleY,
            width: (cropRight - cropLeft) * scaleX,
            height: (cropBottom - cropTop) * scaleY
        )
        guard let cgImage = image.cgImage?.cropping(to: pixelRect) else { onCrop(image); return }
        onCrop(UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation))
    }
}

// MARK: - Video Trimmer View
struct VideoTrimmerView: View {
    let sourceURL: URL
    let onTrim: (URL) -> Void
    let onCancel: () -> Void

    @State private var player: AVPlayer?
    @State private var duration: Double = 0
    @State private var startTime: Double = 0
    @State private var endTime: Double = 0
    @State private var currentTime: Double = 0
    @State private var isExporting = false
    @State private var timeObserver: Any?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar
                HStack {
                    Button(action: {
                        cleanup()
                        onCancel()
                    }) {
                        Text("Cancel").font(.system(size: 16, weight: .medium)).foregroundColor(.white)
                    }
                    Spacer()
                    Text("Trim Video").font(.system(size: 17, weight: .semibold)).foregroundColor(.white)
                    Spacer()
                    Button(action: exportTrimmed) {
                        if isExporting {
                            ProgressView().tint(.orange)
                        } else {
                            Text("Done").font(.system(size: 16, weight: .semibold)).foregroundColor(.orange)
                        }
                    }
                    .disabled(isExporting)
                }
                .padding(.horizontal, 20).padding(.top, 55).padding(.bottom, 14)

                // Video preview
                if let player {
                    VideoPlayer(player: player)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .cornerRadius(12)
                        .padding(.horizontal, 16)
                }

                Spacer().frame(height: 20)

                // Duration label
                HStack {
                    Text(formatTime(startTime))
                        .font(.system(size: 13, weight: .medium)).foregroundColor(.orange)
                    Spacer()
                    Text("Duration: \(formatTime(endTime - startTime))")
                        .font(.system(size: 13, weight: .medium)).foregroundColor(.white)
                    Spacer()
                    Text(formatTime(endTime))
                        .font(.system(size: 13, weight: .medium)).foregroundColor(.orange)
                }
                .padding(.horizontal, 24)

                // Start slider
                VStack(spacing: 4) {
                    HStack {
                        Text("Start").font(.system(size: 11)).foregroundColor(.gray)
                        Spacer()
                    }
                    Slider(value: $startTime, in: 0...max(duration, 0.1)) { editing in
                        if !editing { seekTo(startTime) }
                    }
                    .tint(.orange)
                    .onChange(of: startTime) { val in
                        if val >= endTime - 0.5 { startTime = max(0, endTime - 0.5) }
                    }
                }
                .padding(.horizontal, 24).padding(.top, 10)

                // End slider
                VStack(spacing: 4) {
                    HStack {
                        Text("End").font(.system(size: 11)).foregroundColor(.gray)
                        Spacer()
                    }
                    Slider(value: $endTime, in: 0...max(duration, 0.1)) { editing in
                        if !editing { seekTo(endTime) }
                    }
                    .tint(.orange)
                    .onChange(of: endTime) { val in
                        if val <= startTime + 0.5 { endTime = min(duration, startTime + 0.5) }
                    }
                }
                .padding(.horizontal, 24).padding(.top, 6)

                // Play trimmed section button
                Button(action: playTrimmedSection) {
                    HStack(spacing: 8) {
                        Image(systemName: "play.fill").font(.system(size: 14))
                        Text("Preview Trim").font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 24).padding(.vertical, 12)
                    .background(Color(hex: "2C2C2C")).cornerRadius(20)
                }
                .padding(.top, 16).padding(.bottom, 40)
            }

            if isExporting {
                Color.black.opacity(0.4).ignoresSafeArea()
                VStack(spacing: 12) {
                    ProgressView().tint(.orange).scaleEffect(1.3)
                    Text("Exporting...").font(.system(size: 14)).foregroundColor(.white)
                }
                .padding(30).background(Color(hex: "1C1C1E")).cornerRadius(16)
            }
        }
        .onAppear { setupPlayer() }
        .onDisappear { cleanup() }
    }

    func setupPlayer() {
        let asset = AVAsset(url: sourceURL)
        let p = AVPlayer(playerItem: AVPlayerItem(asset: asset))
        player = p
        Task {
            if let d = try? await asset.load(.duration) {
                let secs = CMTimeGetSeconds(d)
                await MainActor.run {
                    duration = secs
                    endTime = secs
                }
            }
        }
    }

    func seekTo(_ time: Double) {
        player?.seek(to: CMTime(seconds: time, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
    }

    func playTrimmedSection() {
        seekTo(startTime)
        player?.play()
        // Stop at end time
        let endCMTime = CMTime(seconds: endTime, preferredTimescale: 600)
        if let observer = timeObserver { player?.removeTimeObserver(observer) }
        timeObserver = player?.addBoundaryTimeObserver(forTimes: [NSValue(time: endCMTime)], queue: .main) { [self] in
            player?.pause()
        }
    }

    func cleanup() {
        if let observer = timeObserver { player?.removeTimeObserver(observer) }
        player?.pause()
        player = nil
    }

    func exportTrimmed() {
        guard !isExporting else { return }
        // If not trimmed (full duration), just use original
        if startTime < 0.1 && abs(endTime - duration) < 0.1 {
            cleanup()
            onTrim(sourceURL)
            return
        }
        isExporting = true
        let asset = AVAsset(url: sourceURL)
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetMediumQuality) else {
            isExporting = false; return
        }
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString).mov")
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mov
        let startCM = CMTime(seconds: startTime, preferredTimescale: 600)
        let endCM = CMTime(seconds: endTime, preferredTimescale: 600)
        exportSession.timeRange = CMTimeRange(start: startCM, end: endCM)

        exportSession.exportAsynchronously {
            DispatchQueue.main.async {
                isExporting = false
                if exportSession.status == .completed {
                    cleanup()
                    onTrim(outputURL)
                }
            }
        }
    }

    func formatTime(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
