//
//  ExerciseModel.swift
//  FlexCore
//
//  ⚠️  Color(hex:) defined ONLY here.

//  ⚠️  Exercise / ExerciseStore defined ONLY here.
//
//  v5: muscleGroups is now [MuscleGroup] (multi-select support)
//      Primary muscle = muscleGroups.first
//

import SwiftUI
import UIKit
import Combine
import AVFoundation

// MARK: - MuscleGroup (struct — supports built-in + custom)
struct MuscleGroup: Identifiable, Codable, Hashable {
    var id:        String
    var rawValue:  String
    var icon:      String
    var colorHex:  String
    var imageData: Data? = nil     // optional cover photo

    var color: Color   { Color(hex: colorHex) }
    var image: UIImage? { imageData.flatMap { UIImage(data: $0) } }

    static func == (lhs: MuscleGroup, rhs: MuscleGroup) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    static let chest     = MuscleGroup(id:"chest",     rawValue:"Chest",     icon:"figure.arms.open",                   colorHex:"FF6B00")
    static let back      = MuscleGroup(id:"back",      rawValue:"Back",      icon:"figure.walk",                        colorHex:"007AFF")
    static let arms      = MuscleGroup(id:"arms",      rawValue:"Arms",      icon:"dumbbell.fill",                      colorHex:"34C759")
    static let legs      = MuscleGroup(id:"legs",      rawValue:"Legs",      icon:"figure.run",                         colorHex:"5856D6")
    static let shoulders = MuscleGroup(id:"shoulders", rawValue:"Shoulders", icon:"figure.mixed.cardio",                colorHex:"FFCC00")
    static let core      = MuscleGroup(id:"core",      rawValue:"Core",      icon:"figure.core.training",               colorHex:"FF3B30")
    static let cardio    = MuscleGroup(id:"cardio",    rawValue:"Cardio",    icon:"heart.fill",                         colorHex:"FF2D55")
    static let fullBody  = MuscleGroup(id:"fullBody",  rawValue:"Full Body", icon:"figure.strengthtraining.functional", colorHex:"00C7BE")

    static let builtIn: [MuscleGroup] = [.chest, .back, .arms, .legs, .shoulders, .core, .cardio, .fullBody]
}

// MARK: - Exercise
struct Exercise: Identifiable, Codable {
    var id              = UUID()
    var name:            String
    var description:     String
    var muscleGroups:    [MuscleGroup]          // ← multi-select (primary = first)
    var difficulty:      Difficulty
    var duration:        Int
    var sets:            Int
    var reps:            Int
    var imageDatas:      [Data]   = []
    var videoURL:        String   = ""
    var localVideoFileName: String = ""   // file in Documents/ExerciseVideos/
    var createdAt:       Date     = Date()
    var tags:            [String] = []
    var customColorHex:  String?  = nil

    // Convenience: primary muscle group
    var muscleGroup: MuscleGroup { muscleGroups.first ?? .fullBody }

    // MARK: Difficulty
    enum Difficulty: String, Codable, CaseIterable {
        case beginner     = "Beginner"
        case intermediate = "Intermediate"
        case advanced     = "Advanced"

        var localizedLabel: String {
            switch self {
            case .beginner:     return L(.beginner)
            case .intermediate: return L(.intermediate)
            case .advanced:     return L(.advanced)
            }
        }

        var color: Color {
            switch self {
            case .beginner:     return .green
            case .intermediate: return .orange
            case .advanced:     return .red
            }
        }
    }

    var images:     [UIImage] { imageDatas.compactMap { UIImage(data: $0) } }
    var firstImage: UIImage?  { images.first }
    var chartColor: Color {
        guard let hex = customColorHex else { return muscleGroup.color }
        return Color(hex: hex)
    }
}

// MARK: - ExerciseStore
class ExerciseStore: ObservableObject {
    @Published var exercises: [Exercise] = []
    private let saveKey = "exercises_v5"

    init() { load() }

    func add(_ e: Exercise)            { exercises.append(e); save() }
    func addExercise(_ e: Exercise)    { add(e) }
    func update(_ e: Exercise) {
        guard let i = exercises.firstIndex(where: { $0.id == e.id }) else { return }
        exercises[i] = e; save()
    }
    func updateExercise(_ e: Exercise) { update(e) }
    func delete(_ e: Exercise)         { VideoFileManager.delete(e.localVideoFileName); exercises.removeAll { $0.id == e.id }; save() }
    func deleteExercise(_ e: Exercise) { delete(e) }
    func delete(at offsets: IndexSet)  { exercises.remove(atOffsets: offsets); save() }
    func clearAll() { exercises = []; save() }

    /// Resize oversized exercise images in background — safe, no data deleted
    func resizeStoredImages(maxDimension: CGFloat = 900) {
        var changed = false
        for i in exercises.indices {
            let newDatas: [Data] = exercises[i].imageDatas.map { data in
                guard let img = UIImage(data: data) else { return data }
                let sz = img.size
                guard sz.width > maxDimension || sz.height > maxDimension else { return data }
                let scale = min(maxDimension / sz.width, maxDimension / sz.height)
                let newSz = CGSize(width: sz.width * scale, height: sz.height * scale)
                let renderer = UIGraphicsImageRenderer(size: newSz)
                let resized = renderer.image { _ in img.draw(in: CGRect(origin: .zero, size: newSz)) }
                return resized.jpegData(compressionQuality: 0.82) ?? data
            }
            if newDatas != exercises[i].imageDatas {
                exercises[i].imageDatas = newDatas
                changed = true
            }
        }
        if changed { save() }
    }

    func exercises(for group: MuscleGroup) -> [Exercise] {
        exercises.filter { $0.muscleGroups.contains(group) }
    }

    private func save() {
        if let enc = try? JSONEncoder().encode(exercises) {
            UserDefaults.standard.set(enc, forKey: saveKey)
        }
    }
    private func load() {
        // Try current key first
        if let data = UserDefaults.standard.data(forKey: saveKey),
           let dec  = try? JSONDecoder().decode([Exercise].self, from: data) {
            exercises = dec; return
        }
        // Migration: try older keys in descending order
        for oldKey in ["exercises_v4", "exercises_v3", "exercises_v2", "exercises_v1", "exercises"] {
            if let data = UserDefaults.standard.data(forKey: oldKey),
               let dec  = try? JSONDecoder().decode([Exercise].self, from: data) {
                exercises = dec
                save() // re-save under current key
                UserDefaults.standard.removeObject(forKey: oldKey)
                return
            }
        }
    }
}

// MARK: - Video File Manager
enum VideoFileManager {
    private static var videosDir: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("ExerciseVideos", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func save(_ data: Data, fileName: String? = nil) -> String {
        let name = fileName ?? "\(UUID().uuidString).mov"
        let url = videosDir.appendingPathComponent(name)
        try? data.write(to: url)
        return name
    }

    static func save(from sourceURL: URL) -> String? {
        let name = "\(UUID().uuidString).\(sourceURL.pathExtension.isEmpty ? "mov" : sourceURL.pathExtension)"
        let dest = videosDir.appendingPathComponent(name)
        do {
            if FileManager.default.fileExists(atPath: dest.path) {
                try FileManager.default.removeItem(at: dest)
            }
            try FileManager.default.copyItem(at: sourceURL, to: dest)
            return name
        } catch { return nil }
    }

    static func url(for fileName: String) -> URL? {
        guard !fileName.isEmpty else { return nil }
        let url = videosDir.appendingPathComponent(fileName)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    static func delete(_ fileName: String) {
        guard !fileName.isEmpty else { return }
        let url = videosDir.appendingPathComponent(fileName)
        try? FileManager.default.removeItem(at: url)
    }

    static func thumbnail(for fileName: String) -> UIImage? {
        guard let url = url(for: fileName) else { return nil }
        let asset = AVAsset(url: url)
        let gen = AVAssetImageGenerator(asset: asset)
        gen.appliesPreferredTrackTransform = true
        gen.maximumSize = CGSize(width: 300, height: 300)
        if let cgImg = try? gen.copyCGImage(at: .zero, actualTime: nil) {
            return UIImage(cgImage: cgImg)
        }
        return nil
    }
}

// MARK: - Color Extension  ← ONE place
extension Color {
    init(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: h).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch h.count {
        case 3:  (a,r,g,b) = (255,(int>>8)*17,(int>>4 & 0xF)*17,(int & 0xF)*17)
        case 6:  (a,r,g,b) = (255, int>>16, int>>8 & 0xFF, int & 0xFF)
        case 8:  (a,r,g,b) = (int>>24, int>>16 & 0xFF, int>>8 & 0xFF, int & 0xFF)
        default: (a,r,g,b) = (255,255,255,255)
        }
        self.init(.sRGB,
                  red:   Double(r)/255,
                  green: Double(g)/255,
                  blue:  Double(b)/255,
                  opacity: Double(a)/255)
    }

    func toHex() -> String {
        let ui = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "%02X%02X%02X", Int(r*255), Int(g*255), Int(b*255))
    }
}
