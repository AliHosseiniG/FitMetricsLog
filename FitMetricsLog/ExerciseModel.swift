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
import ImageIO

// MARK: - Image Downsampling Cache
// Uses NSCache (auto-evicts on memory pressure) to hold small decoded thumbnails.
// Downsamples JPEGs via ImageIO without loading the full bitmap.
enum ImageDataCache {
    private static let cache: NSCache<NSString, UIImage> = {
        let c = NSCache<NSString, UIImage>()
        c.countLimit = 200            // max 200 thumbnails in memory
        c.totalCostLimit = 40 * 1024 * 1024  // ~40 MB
        return c
    }()

    /// Returns a downsampled UIImage from raw Data, caching by key.
    static func thumbnail(data: Data, maxPixelSize: CGFloat, key: String) -> UIImage? {
        let nsKey = key as NSString
        if let cached = cache.object(forKey: nsKey) { return cached }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
        else { return nil }
        let img = UIImage(cgImage: cg)
        // Approximate memory cost (4 bytes per pixel)
        let cost = Int(img.size.width * img.size.height * 4)
        cache.setObject(img, forKey: nsKey, cost: cost)
        return img
    }

    static func clear() { cache.removeAllObjects() }

    // Shared accessors so ImageFileManager can use the same cache.
    static func cachedObject(forKey key: NSString) -> UIImage? { cache.object(forKey: key) }
    static func setObject(_ img: UIImage, forKey key: NSString, cost: Int) {
        cache.setObject(img, forKey: key, cost: cost)
    }
}

// MARK: - Image File Manager (disk-based storage for exercise images)
// Stores exercise images as JPEG files in Documents/ExerciseImages/.
// Keeps memory usage low by loading from disk on demand, via downsampled thumbnails.
enum ImageFileManager {
    private static var imagesDir: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("ExerciseImages", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Save raw image data to a new file; returns the file name.
    static func save(_ data: Data, fileName: String? = nil) -> String {
        let name = fileName ?? "\(UUID().uuidString).jpg"
        let url = imagesDir.appendingPathComponent(name)
        try? data.write(to: url)
        return name
    }

    /// Resolve a file name to a URL, or nil if missing.
    static func url(for fileName: String) -> URL? {
        guard !fileName.isEmpty else { return nil }
        let url = imagesDir.appendingPathComponent(fileName)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    /// Delete an image file from disk.
    static func delete(_ fileName: String) {
        guard !fileName.isEmpty else { return }
        let url = imagesDir.appendingPathComponent(fileName)
        try? FileManager.default.removeItem(at: url)
    }

    /// Downsampled thumbnail directly from file — avoids loading full bitmap.
    static func thumbnail(fileName: String, maxPixelSize: CGFloat) -> UIImage? {
        guard let url = url(for: fileName) else { return nil }
        let key = "file-\(fileName)-\(Int(maxPixelSize))" as NSString
        if let cached = ImageDataCache.cachedObject(forKey: key) { return cached }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
        else { return nil }
        let img = UIImage(cgImage: cg)
        let cost = Int(img.size.width * img.size.height * 4)
        ImageDataCache.setObject(img, forKey: key, cost: cost)
        return img
    }
}

extension Exercise {
    /// Small cached thumbnail of first image (for list/row display).
    func thumbnail(maxPixelSize: CGFloat = 200) -> UIImage? {
        // Prefer disk file if available
        if let name = localImageFileNames.first,
           let img = ImageFileManager.thumbnail(fileName: name, maxPixelSize: maxPixelSize) {
            return img
        }
        // Fallback: legacy in-memory data (pre-migration)
        guard let data = imageDatas.first else { return nil }
        return ImageDataCache.thumbnail(data: data, maxPixelSize: maxPixelSize,
                                        key: "ex-\(id.uuidString)-0-\(Int(maxPixelSize))")
    }

    /// Cached thumbnails for the full image gallery.
    func galleryThumbnails(maxPixelSize: CGFloat = 400) -> [UIImage] {
        if !localImageFileNames.isEmpty {
            return localImageFileNames.compactMap {
                ImageFileManager.thumbnail(fileName: $0, maxPixelSize: maxPixelSize)
            }
        }
        return imageDatas.enumerated().compactMap { idx, data in
            ImageDataCache.thumbnail(data: data, maxPixelSize: maxPixelSize,
                                     key: "ex-\(id.uuidString)-\(idx)-\(Int(maxPixelSize))")
        }
    }
}

extension WorkoutPlan {
    /// Cached thumbnail of the plan cover photo.
    func coverThumbnail(maxPixelSize: CGFloat = 600) -> UIImage? {
        guard let data = imageData else { return nil }
        return ImageDataCache.thumbnail(data: data, maxPixelSize: maxPixelSize,
                                        key: "plan-\(id.uuidString)-\(Int(maxPixelSize))")
    }
}

extension WorkoutLog {
    /// Cached thumbnails of log's exercise image snapshots.
    func logGalleryThumbnails(maxPixelSize: CGFloat = 300) -> [UIImage] {
        exerciseImageDatas.enumerated().compactMap { idx, data in
            ImageDataCache.thumbnail(data: data, maxPixelSize: maxPixelSize,
                                     key: "log-\(id.uuidString)-\(idx)-\(Int(maxPixelSize))")
        }
    }

    /// Cached thumbnail of the log's first image (small icon).
    func logThumbnail(maxPixelSize: CGFloat = 100) -> UIImage? {
        guard let data = exerciseImageData ?? exerciseImageDatas.first else { return nil }
        return ImageDataCache.thumbnail(data: data, maxPixelSize: maxPixelSize,
                                        key: "log-\(id.uuidString)-first-\(Int(maxPixelSize))")
    }
}

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
    var imageDatas:      [Data]   = []   // legacy — migrated to disk files at launch
    var localImageFileNames: [String] = [] // files in Documents/ExerciseImages/
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

    // DO NOT USE: images property loads ALL full-res images — use thumbnail() or galleryThumbnails() instead
    // var images:     [UIImage] { imageDatas.compactMap { UIImage(data: $0) } }
    // var firstImage: UIImage?  { images.first }
    var chartColor: Color {
        guard let hex = customColorHex else { return muscleGroup.color }
        return Color(hex: hex)
    }
}

// MARK: - Exercise: tolerant Codable
// Swift's synthesized Decodable throws `keyNotFound` when a non-Optional property
// is missing from the JSON (default values are NOT applied at decode time).
// Older saved exercises don't have `localImageFileNames`, so we decode every
// optional/defaulted field with `decodeIfPresent` to keep legacy data loading.
extension Exercise {
    private enum CodingKeys: String, CodingKey {
        case id, name, description, muscleGroups, difficulty, duration, sets, reps
        case imageDatas, localImageFileNames, videoURL, localVideoFileName
        case createdAt, tags, customColorHex
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id                  = try c.decodeIfPresent(UUID.self,         forKey: .id) ?? UUID()
        self.name                = try c.decode(String.self,                forKey: .name)
        self.description         = try c.decode(String.self,                forKey: .description)
        self.muscleGroups        = try c.decode([MuscleGroup].self,         forKey: .muscleGroups)
        self.difficulty          = try c.decode(Difficulty.self,            forKey: .difficulty)
        self.duration            = try c.decode(Int.self,                   forKey: .duration)
        self.sets                = try c.decode(Int.self,                   forKey: .sets)
        self.reps                = try c.decode(Int.self,                   forKey: .reps)
        self.imageDatas          = try c.decodeIfPresent([Data].self,       forKey: .imageDatas)          ?? []
        self.localImageFileNames = try c.decodeIfPresent([String].self,     forKey: .localImageFileNames) ?? []
        self.videoURL            = try c.decodeIfPresent(String.self,       forKey: .videoURL)            ?? ""
        self.localVideoFileName  = try c.decodeIfPresent(String.self,       forKey: .localVideoFileName)  ?? ""
        self.createdAt           = try c.decodeIfPresent(Date.self,         forKey: .createdAt)           ?? Date()
        self.tags                = try c.decodeIfPresent([String].self,     forKey: .tags)                ?? []
        self.customColorHex      = try c.decodeIfPresent(String.self,       forKey: .customColorHex)
    }
}

// MARK: - ExerciseStore
class ExerciseStore: ObservableObject {
    @Published var exercises: [Exercise] = []
    private let saveKey = "exercises_v5"

    init() {
        load()
        migrateImagesToDiskIfNeeded()
    }

    func add(_ e: Exercise)            { exercises.append(e); save() }
    func addExercise(_ e: Exercise)    { add(e) }
    func update(_ e: Exercise) {
        guard let i = exercises.firstIndex(where: { $0.id == e.id }) else { return }
        // Delete any image files that were removed in the update
        let oldFiles = Set(exercises[i].localImageFileNames)
        let newFiles = Set(e.localImageFileNames)
        for removed in oldFiles.subtracting(newFiles) {
            ImageFileManager.delete(removed)
        }
        exercises[i] = e; save()
        // Clear image cache so new thumbnails regenerate
        ImageDataCache.clear()
    }
    func updateExercise(_ e: Exercise) { update(e) }
    func delete(_ e: Exercise) {
        VideoFileManager.delete(e.localVideoFileName)
        e.localImageFileNames.forEach { ImageFileManager.delete($0) }
        exercises.removeAll { $0.id == e.id }; save()
    }
    func deleteExercise(_ e: Exercise) { delete(e) }
    func delete(at offsets: IndexSet)  { exercises.remove(atOffsets: offsets); save() }
    func clearAll() { exercises = []; save() }

    /// Migration: move any in-memory imageDatas to disk files.
    /// Idempotent — only touches exercises that still carry imageDatas, so it's safe
    /// to run on every launch. No persistent flag (the previous flag could lock in
    /// an empty state if load() had previously failed).
    private func migrateImagesToDiskIfNeeded() {
        var changed = false
        for i in exercises.indices {
            guard !exercises[i].imageDatas.isEmpty else { continue }
            let names: [String] = exercises[i].imageDatas.map { data in
                ImageFileManager.save(data)
            }
            exercises[i].localImageFileNames.append(contentsOf: names)
            exercises[i].imageDatas = []   // free memory; data now on disk
            changed = true
        }
        if changed { save() }
    }

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
    // In-memory thumbnail cache — avoids regenerating thumbnails on every SwiftUI render
    private static var thumbnailCache: [String: UIImage] = [:]

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
        thumbnailCache.removeValue(forKey: fileName)
        let url = videosDir.appendingPathComponent(fileName)
        try? FileManager.default.removeItem(at: url)
    }

    static func thumbnail(for fileName: String) -> UIImage? {
        guard !fileName.isEmpty else { return nil }
        if let cached = thumbnailCache[fileName] { return cached }
        guard let url = url(for: fileName) else { return nil }
        let asset = AVAsset(url: url)
        let gen = AVAssetImageGenerator(asset: asset)
        gen.appliesPreferredTrackTransform = true
        gen.maximumSize = CGSize(width: 300, height: 300)
        if let cgImg = try? gen.copyCGImage(at: .zero, actualTime: nil) {
            let img = UIImage(cgImage: cgImg)
            thumbnailCache[fileName] = img
            return img
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
