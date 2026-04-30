//
//  WorkoutLogModel.swift
//  FlexCore
//

import SwiftUI
import UIKit
import Combine

// MARK: - WorkoutSet
struct WorkoutSet: Identifiable, Codable {
    var id         = UUID()
    var setNumber: Int
    var weight:    Double
    var reps:      Int
    var notes:     String = ""
    var maxReps:   Int    = 0   // 0 = no limit
}

// MARK: - WorkoutLog
struct WorkoutLog: Identifiable, Codable {
    var id:               UUID
    var exerciseId:       UUID
    var exerciseName:     String
    var muscleGroup:      MuscleGroup
    var date:             Date
    var sets:             [WorkoutSet]
    var notes:            String = ""
    var isCompleted:       Bool   = false   // checkbox state
    var exerciseImageData: Data? = nil     // snapshot of exercise photo (first)
    var exerciseImageDatas: [Data] = []    // all exercise photos
    var rowNumber: Int = 0                 // manual row/order number entered by user

    init(exerciseId: UUID, exerciseName: String,
         muscleGroup: MuscleGroup, date: Date, sets: [WorkoutSet],
         exerciseImageData: Data? = nil, exerciseImageDatas: [Data] = [],
         rowNumber: Int = 0) {
        self.id                  = UUID()
        self.exerciseId          = exerciseId
        self.exerciseName        = exerciseName
        self.muscleGroup         = muscleGroup
        self.date                = date
        self.sets                = sets
        self.exerciseImageData   = exerciseImageData
        self.exerciseImageDatas  = exerciseImageDatas.isEmpty ? (exerciseImageData.map { [$0] } ?? []) : exerciseImageDatas
        self.rowNumber           = rowNumber
    }

    // DO NOT USE: allImages property loads ALL full-res images — use logThumbnail() or logGalleryThumbnails() instead
    // var allImages: [UIImage] { exerciseImageDatas.compactMap { UIImage(data: $0) } }

    var totalVolume:        Double { sets.reduce(0) { $0 + $1.weight * Double($1.reps) } }
    var maxWeight:          Double { sets.map(\.weight).max() ?? 0 }
    var totalReps:          Int    { sets.reduce(0) { $0 + $1.reps } }
    var estimatedOneRepMax: Double {
        guard let best = sets.max(by: { $0.weight * Double($0.reps) < $1.weight * Double($1.reps) })
        else { return 0 }
        if best.reps == 1 { return best.weight }
        return best.weight / (1.0278 - 0.0278 * Double(best.reps))
    }
}

// MARK: - WorkoutSession
struct WorkoutSession: Identifiable, Codable {
    var id              = UUID()
    var date:             Date
    var logs:             [WorkoutLog]
    var sessionNotes:     String = ""
    var durationMinutes:  Int    = 60
    /// End time of the session. Duration is calculated as endDate - date.
    /// Optional for backward compatibility with sessions saved before this field existed.
    var endDate:          Date?  = nil
    // Plan reference — kept in sync when plan is renamed
    var sourcePlanId:     UUID?   = nil
    var sourcePlanName:   String? = nil

    var totalVolume:  Double         { logs.reduce(0) { $0 + $1.totalVolume } }
    var muscleGroups: [MuscleGroup] {
        let raw = Array(Set(logs.map(\.muscleGroup)))
        return raw.map { MuscleGroupManager.shared.liveGroup(for: $0.id) ?? $0 }
    }
}

// MARK: - MuscleGroupStat
struct MuscleGroupStat {
    var muscleGroup:  MuscleGroup
    var totalVolume:  Double
    var sessionCount: Int
}

// MARK: - DateRange
enum DateRange: String, CaseIterable {
    case all         = "All"
    case week        = "1W"
    case month       = "1M"
    case threeMonths = "3M"
    case sixMonths   = "6M"
    case year        = "1Y"

    var bounds: (start: Date, end: Date) {
        let now = Date(), cal = Calendar.current
        let start: Date
        switch self {
        case .week:        start = cal.date(byAdding: .day,   value: -7,  to: now)!
        case .month:       start = cal.date(byAdding: .month, value: -1,  to: now)!
        case .threeMonths: start = cal.date(byAdding: .month, value: -3,  to: now)!
        case .sixMonths:   start = cal.date(byAdding: .month, value: -6,  to: now)!
        case .year:        start = cal.date(byAdding: .year,  value: -1,  to: now)!
        case .all:         start = Date(timeIntervalSince1970: 0)
        }
        return (start, now)
    }
}

// MARK: - WorkoutLogStore
class WorkoutLogStore: ObservableObject {
    @Published var sessions: [WorkoutSession] = []
    private let saveKey = "workout_sessions_v5"

    init() {
        load()
        purgeLogImagesIfNeeded()
    }

    /// Clear duplicated image snapshots from every log.
    /// Idempotent — only modifies logs that still carry snapshot data, so safe to
    /// run on every launch. Exercise images now live with the Exercise on disk.
    private func purgeLogImagesIfNeeded() {
        var changed = false
        for si in sessions.indices {
            for li in sessions[si].logs.indices {
                if sessions[si].logs[li].exerciseImageData != nil ||
                   !sessions[si].logs[li].exerciseImageDatas.isEmpty {
                    sessions[si].logs[li].exerciseImageData = nil
                    sessions[si].logs[li].exerciseImageDatas = []
                    changed = true
                }
            }
        }
        if changed { save() }
    }

    // Sync exercise name across all history
    func syncExerciseName(id: UUID, newName: String) {
        var changed = false
        for si in sessions.indices {
            for li in sessions[si].logs.indices where sessions[si].logs[li].exerciseId == id {
                sessions[si].logs[li].exerciseName = newName; changed = true
            }
        }
        if changed { save() }
    }

    // Sync plan name — called when a plan is renamed
    func syncPlanName(id: UUID, newName: String) {
        var changed = false
        for si in sessions.indices where sessions[si].sourcePlanId == id {
            sessions[si].sourcePlanName = newName; changed = true
        }
        if changed { save() }
    }

    func addSession(_ s: WorkoutSession)    { sessions.insert(s, at: 0); save() }
    func updateSession(_ s: WorkoutSession) {
        if let i = sessions.firstIndex(where: { $0.id == s.id }) { sessions[i] = s; save() }
    }
    func deleteSession(_ s: WorkoutSession) { sessions.removeAll { $0.id == s.id }; save() }
    func clearAll() { sessions = []; save() }

    /// Resize exercise images in existing log entries (fixes large images from before)
    /// Safe — only shrinks, never deletes, never changes sets/weights/dates
    func resizeStoredImages(maxDimension: CGFloat = 600) {
        var changed = false
        for si in sessions.indices {
            for li in sessions[si].logs.indices {
                let log = sessions[si].logs[li]
                let newDatas: [Data] = log.exerciseImageDatas.map { data in
                    guard let img = UIImage(data: data) else { return data }
                    let sz = img.size
                    let scale = min(maxDimension / sz.width, maxDimension / sz.height, 1.0)
                    if scale >= 1.0 { return data }
                    let newSz = CGSize(width: sz.width * scale, height: sz.height * scale)
                    let renderer = UIGraphicsImageRenderer(size: newSz)
                    let resized = renderer.image { _ in img.draw(in: CGRect(origin: .zero, size: newSz)) }
                    return resized.jpegData(compressionQuality: 0.75) ?? data
                }
                if newDatas != log.exerciseImageDatas {
                    sessions[si].logs[li].exerciseImageDatas = newDatas
                    sessions[si].logs[li].exerciseImageData  = newDatas.first
                    changed = true
                }
            }
        }
        if changed { save() }
    }

    // MARK: Analytics

    func dailyVolumes(in range: DateRange,
                      muscle: MuscleGroup? = nil) -> [(date: Date, volume: Double)] {
        let cal = Calendar.current
        let (start, end) = range.bounds
        var dict: [Date: Double] = [:]
        for session in sessions where session.date >= start && session.date <= end {
            let day  = cal.startOfDay(for: session.date)
            let logs = muscle == nil ? session.logs : session.logs.filter { $0.muscleGroup == muscle! }
            let vol  = logs.reduce(0) { $0 + $1.totalVolume }
            if vol > 0 { dict[day, default: 0] += vol }
        }
        return dict.map { ($0.key, $0.value) }.sorted { $0.date < $1.date }
    }

    func dailyVolumesForExercise(id: UUID, in range: DateRange) -> [(date: Date, volume: Double)] {
        let cal = Calendar.current
        let (start, end) = range.bounds
        var dict: [Date: Double] = [:]
        for session in sessions where session.date >= start && session.date <= end {
            let day = cal.startOfDay(for: session.date)
            let vol = session.logs.filter { $0.exerciseId == id }.reduce(0) { $0 + $1.totalVolume }
            if vol > 0 { dict[day, default: 0] += vol }
        }
        return dict.map { ($0.key, $0.value) }.sorted { $0.date < $1.date }
    }

    func muscleGroupStats(in range: DateRange) -> [MuscleGroupStat] {
        let (start, end) = range.bounds
        var dict: [MuscleGroup: (vol: Double, cnt: Int)] = [:]
        for session in sessions where session.date >= start && session.date <= end {
            for log in session.logs {
                let e = dict[log.muscleGroup] ?? (0, 0)
                dict[log.muscleGroup] = (e.vol + log.totalVolume, e.cnt + 1)
            }
        }
        return dict.map { MuscleGroupStat(muscleGroup: $0, totalVolume: $1.vol, sessionCount: $1.cnt) }
                   .sorted { $0.totalVolume > $1.totalVolume }
    }

    func muscleGroupSessionCounts(in range: DateRange) -> [MuscleGroup: Int] {
        let (start, end) = range.bounds
        var result: [MuscleGroup: Int] = [:]
        for session in sessions where session.date >= start && session.date <= end {
            for g in session.muscleGroups { result[g, default: 0] += 1 }
        }
        return result
    }

    func neglectedMuscles(in range: DateRange, topN: Int = 3) -> [MuscleGroup] {
        // Neglected = lowest total volume (exclude cardio/fullBody)
        let stats = muscleGroupStats(in: range)
        let volMap = Dictionary(uniqueKeysWithValues: stats.map { ($0.muscleGroup, $0.totalVolume) })
        return MuscleGroupManager.shared.groups
            .filter { $0.id != "cardio" && $0.id != "fullBody" }
            .sorted { (volMap[$0] ?? 0) < (volMap[$1] ?? 0) }
            .prefix(topN).map { $0 }
    }

    func overtrainedMuscles(in range: DateRange, topN: Int = 1) -> [MuscleGroup] {
        // Most trained = highest total volume
        let stats = muscleGroupStats(in: range)
        return stats
            .sorted { $0.totalVolume > $1.totalVolume }
            .prefix(topN).map { $0.muscleGroup }
    }

    func totalSessions(in range: DateRange) -> Int {
        let (s, e) = range.bounds
        return sessions.filter { $0.date >= s && $0.date <= e }.count
    }

    func totalVolume(in range: DateRange) -> Double {
        let (s, e) = range.bounds
        return sessions.filter { $0.date >= s && $0.date <= e }.reduce(0) { $0 + $1.totalVolume }
    }

    private func save() {
        if let enc = try? JSONEncoder().encode(sessions) {
            UserDefaults.standard.set(enc, forKey: saveKey)
        }
    }
    private func load() {
        // Try current key first
        if let data = UserDefaults.standard.data(forKey: saveKey),
           let dec  = try? JSONDecoder().decode([WorkoutSession].self, from: data) {
            sessions = dec; return
        }
        // Migration: try older keys
        for oldKey in ["workout_sessions_v4", "workout_sessions_v3",
                       "workout_sessions_v2", "workout_sessions_v1", "workout_sessions"] {
            if let data = UserDefaults.standard.data(forKey: oldKey),
               let dec  = try? JSONDecoder().decode([WorkoutSession].self, from: data) {
                sessions = dec
                save()
                UserDefaults.standard.removeObject(forKey: oldKey)
                return
            }
        }
    }
}
