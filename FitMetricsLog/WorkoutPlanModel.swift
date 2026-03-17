//
//  WorkoutPlanModel.swift
//  FlexCore
//
//  v2: Plan name changes sync to WorkoutSession.sourcePlanName
//      WorkoutSession gets sourcePlanId + sourcePlanName fields
//

import SwiftUI
import Combine

// MARK: - Plan Exercise Item
struct PlanExerciseItem: Identifiable, Codable {
    var id           = UUID()
    var exerciseId:   UUID
    var exerciseName: String
    var muscleGroup:  MuscleGroup
    var targetSets:   Int    = 3
    var targetReps:   Int    = 10
    var targetWeight: Double = 0
}

// MARK: - Workout Plan
struct WorkoutPlan: Identifiable, Codable {
    var id        = UUID()
    var name:      String
    var notes:     String             = ""
    var items:     [PlanExerciseItem] = []
    var createdAt: Date               = Date()
    var colorHex:  String             = "FF6B00"

    var color: Color { Color(hex: colorHex) }
    var muscleGroups: [MuscleGroup] {
        Array(Set(items.map(\.muscleGroup))).sorted { $0.rawValue < $1.rawValue }
    }
}

// MARK: - WorkoutPlanStore
class WorkoutPlanStore: ObservableObject {
    @Published var plans: [WorkoutPlan] = []
    private let key = "workoutPlans_v2"

    // We need a reference to logStore to sync plan name changes
    var logStore: WorkoutLogStore?

    init() { load() }

    func add(_ p: WorkoutPlan) { plans.append(p); save() }

    func update(_ p: WorkoutPlan) {
        guard let i = plans.firstIndex(where: { $0.id == p.id }) else { return }
        let oldName = plans[i].name
        plans[i] = p
        save()
        // Sync name change into all sessions that came from this plan
        if oldName != p.name {
            logStore?.syncPlanName(id: p.id, newName: p.name)
        }
        // Sync exercise name changes into items
        // (already done by ExerciseStore via syncExerciseName)
    }

    func delete(_ p: WorkoutPlan) { plans.removeAll { $0.id == p.id }; save() }
    func clearAll() { plans = []; save() }

    /// Called when an exercise is renamed — update matching items in all plans
    func syncExerciseName(id: UUID, newName: String) {
        var changed = false
        for pi in plans.indices {
            for ii in plans[pi].items.indices where plans[pi].items[ii].exerciseId == id {
                plans[pi].items[ii].exerciseName = newName; changed = true
            }
        }
        if changed { save() }
    }

    private func save() {
        if let enc = try? JSONEncoder().encode(plans) {
            UserDefaults.standard.set(enc, forKey: key)
        }
    }
    private func load() {
        // Try current key first
        if let data = UserDefaults.standard.data(forKey: key),
           let dec  = try? JSONDecoder().decode([WorkoutPlan].self, from: data) {
            plans = dec; return
        }
        // Migration: try older keys
        for oldKey in ["workoutPlans_v1", "workoutPlans"] {
            if let data = UserDefaults.standard.data(forKey: oldKey),
               let dec  = try? JSONDecoder().decode([WorkoutPlan].self, from: data) {
                plans = dec
                save()
                UserDefaults.standard.removeObject(forKey: oldKey)
                return
            }
        }
    }
}
