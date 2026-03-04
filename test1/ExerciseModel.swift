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
import Combine

// MARK: - MuscleGroup (struct — supports built-in + custom)
struct MuscleGroup: Identifiable, Codable, Hashable {
    var id:       String
    var rawValue: String
    var icon:     String
    var colorHex: String

    var color: Color { Color(hex: colorHex) }

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
    func delete(_ e: Exercise)         { exercises.removeAll { $0.id == e.id }; save() }
    func deleteExercise(_ e: Exercise) { delete(e) }
    func delete(at offsets: IndexSet)  { exercises.remove(atOffsets: offsets); save() }

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
