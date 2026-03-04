//
//  WorkoutPlanView.swift
//  FlexCore
//

import SwiftUI

// MARK: - Plans Tab Root
struct WorkoutPlanListView: View {
    @EnvironmentObject var planStore:     WorkoutPlanStore
    @EnvironmentObject var exerciseStore: ExerciseStore
    @State private var showingAdd = false
    @State private var editing: WorkoutPlan? = nil

    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "111111").ignoresSafeArea()
                VStack(spacing: 0) {
                    // Header
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Programs")
                                .font(.system(size: 26, weight: .bold)).foregroundColor(.white)
                            Text("\(planStore.plans.count) workout plans")
                                .font(.system(size: 13)).foregroundColor(.gray)
                        }
                        Spacer()
                        Button(action: { showingAdd = true }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 28)).foregroundColor(.orange)
                        }
                    }
                    .padding(.horizontal, 20).padding(.top, 60).padding(.bottom, 20)

                    if planStore.plans.isEmpty {
                        emptyState
                    } else {
                        ScrollView(showsIndicators: false) {
                            LazyVStack(spacing: 14) {
                                ForEach(planStore.plans) { plan in
                                    NavigationLink(destination: PlanDetailView(plan: plan)) {
                                        PlanRowCard(plan: plan)
                                    }
                                    .padding(.horizontal, 20)
                                }
                                Spacer(minLength: 100)
                            }
                        }
                    }
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showingAdd) {
                PlanFormView(existing: nil)
                    .environmentObject(planStore)
                    .environmentObject(exerciseStore)
            }
            .sheet(item: $editing) { plan in
                PlanFormView(existing: plan)
                    .environmentObject(planStore)
                    .environmentObject(exerciseStore)
            }
        }
    }

    var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "list.bullet.clipboard")
                .font(.system(size: 60)).foregroundColor(.gray.opacity(0.35))
            Text("No programs yet")
                .font(.system(size: 20, weight: .semibold)).foregroundColor(.white)
            Text("Create a workout plan to organize your exercises")
                .font(.system(size: 14)).foregroundColor(.gray)
                .multilineTextAlignment(.center).padding(.horizontal, 30)
            Button(action: { showingAdd = true }) {
                Label("Create Program", systemImage: "plus")
                    .font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
                    .padding(.horizontal, 28).padding(.vertical, 14)
                    .background(Color.orange).cornerRadius(24)
            }.padding(.top, 8)
            Spacer()
        }
    }
}

// MARK: - Plan Row Card
struct PlanRowCard: View {
    let plan: WorkoutPlan
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(plan.color.opacity(0.2))
                        .frame(width: 44, height: 44)
                    Image(systemName: "list.bullet.clipboard.fill")
                        .font(.system(size: 20)).foregroundColor(plan.color)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(plan.name)
                        .font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
                    Text("\(plan.items.count) exercise\(plan.items.count == 1 ? "" : "s")")
                        .font(.system(size: 12)).foregroundColor(.gray)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11)).foregroundColor(.gray)
            }
            if !plan.muscleGroups.isEmpty {
                HStack(spacing: 6) {
                    ForEach(plan.muscleGroups, id: \.self) { g in
                        Text(g.rawValue)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(g.color)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(g.color.opacity(0.12)).cornerRadius(6)
                    }
                }
            }
        }
        .padding(14).background(Color(hex: "1C1C1E")).cornerRadius(14)
    }
}

// MARK: - Plan Detail
struct PlanDetailView: View {
    @EnvironmentObject var planStore:     WorkoutPlanStore
    @EnvironmentObject var exerciseStore: ExerciseStore
    @EnvironmentObject var logStore:      WorkoutLogStore
    @Environment(\.dismiss) var dismiss

    let plan: WorkoutPlan
    @State private var showingEdit    = false
    @State private var showingDelete  = false
    @State private var showingLog     = false
    @State private var isReordering   = false
    @State private var localItems:    [PlanExerciseItem] = []

    var live: WorkoutPlan {
        planStore.plans.first { $0.id == plan.id } ?? plan
    }

    var body: some View {
        ZStack {
            Color(hex: "111111").ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Hero
                    ZStack(alignment: .bottomLeading) {
                        LinearGradient(
                            colors: [live.color.opacity(0.4), Color(hex: "111111")],
                            startPoint: .top, endPoint: .bottom
                        ).frame(height: 200)
                        Image(systemName: "list.bullet.clipboard.fill")
                            .font(.system(size: 90)).foregroundColor(live.color.opacity(0.15))
                            .frame(maxWidth: .infinity, alignment: .trailing).padding(.trailing, 20)
                        VStack(alignment: .leading, spacing: 6) {
                            Text("\(live.items.count) exercises")
                                .font(.system(size: 12, weight: .semibold)).foregroundColor(live.color)
                                .padding(.horizontal, 10).padding(.vertical, 4)
                                .background(live.color.opacity(0.15)).cornerRadius(8)
                            Text(live.name)
                                .font(.system(size: 28, weight: .bold)).foregroundColor(.white)
                        }.padding(20)
                    }

                    VStack(alignment: .leading, spacing: 20) {
                        // Start workout button
                        Button(action: { showingLog = true }) {
                            HStack {
                                Image(systemName: "play.circle.fill").font(.system(size: 20))
                                Text("Start Workout")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity).frame(height: 52)
                            .background(Color.orange).cornerRadius(26)
                        }

                        if !live.notes.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Notes").font(.system(size: 15, weight: .bold)).foregroundColor(.white)
                                Text(live.notes).font(.system(size: 13)).foregroundColor(.gray)
                            }
                        }

                        HStack {
                            Text("Exercises").font(.system(size: 17, weight: .bold)).foregroundColor(.white)
                            Spacer()
                            Button(action: {
                                if isReordering {
                                    // Save reordered items
                                    var updated = live
                                    updated.items = localItems
                                    planStore.update(updated)
                                } else {
                                    localItems = live.items
                                }
                                withAnimation(.spring(response: 0.3)) { isReordering.toggle() }
                            }) {
                                Text(isReordering ? "Done" : "Reorder")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(isReordering ? .green : .orange)
                                    .padding(.horizontal, 12).padding(.vertical, 6)
                                    .background((isReordering ? Color.green : Color.orange).opacity(0.12))
                                    .cornerRadius(10)
                            }
                        }

                        if isReordering {
                            List {
                                ForEach(Array(localItems.enumerated()), id: \.element.id) { idx, item in
                                    HStack(spacing: 12) {
                                        Image(systemName: "line.3.horizontal")
                                            .foregroundColor(.gray).font(.system(size: 16))
                                        Text("\(idx + 1)")
                                            .font(.system(size: 13, weight: .bold)).foregroundColor(.orange)
                                            .frame(width: 22)
                                        Image(systemName: item.muscleGroup.icon)
                                            .font(.system(size: 13)).foregroundColor(item.muscleGroup.color)
                                            .frame(width: 30, height: 30)
                                            .background(item.muscleGroup.color.opacity(0.12)).cornerRadius(8)
                                        Text(item.exerciseName)
                                            .font(.system(size: 13, weight: .semibold)).foregroundColor(.white)
                                        Spacer()
                                    }
                                    .padding(.vertical, 4)
                                    .listRowBackground(Color(hex: "1C1C1E"))
                                    .listRowSeparatorTint(Color.white.opacity(0.08))
                                }
                                .onMove { from, to in localItems.move(fromOffsets: from, toOffset: to) }
                            }
                            .listStyle(.plain)
                            .scrollContentBackground(.hidden)
                            .frame(height: CGFloat(localItems.count) * 56 + 10)
                            .environment(\.editMode, .constant(.active))
                        } else {
                            ForEach(Array(live.items.enumerated()), id: \.element.id) { idx, item in
                                PlanItemRow(item: item, index: idx + 1)
                            }
                        }
                        Spacer(minLength: 100)
                    }
                    .padding(20)
                }
            }

            // Nav bar overlay
            VStack {
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold)).foregroundColor(.white)
                            .frame(width: 40, height: 40)
                            .background(Color.black.opacity(0.55)).clipShape(Circle())
                    }
                    Spacer()
                    Menu {
                        Button("Edit", systemImage: "pencil")               { showingEdit = true }
                        Button("Delete", systemImage: "trash", role: .destructive) { showingDelete = true }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 16)).foregroundColor(.white)
                            .frame(width: 40, height: 40)
                            .background(Color.black.opacity(0.55)).clipShape(Circle())
                    }
                }
                .padding(.horizontal, 20).padding(.top, 55)
                Spacer()
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showingEdit) {
            PlanFormView(existing: live)
                .environmentObject(planStore)
                .environmentObject(exerciseStore)
        }
        .sheet(isPresented: $showingLog) {
            NewSessionView(prefillPlan: live)
                .environmentObject(logStore)
                .environmentObject(exerciseStore)
                .environmentObject(planStore)
        }
        .alert("Delete Program", isPresented: $showingDelete) {
            Button("Delete", role: .destructive) { planStore.delete(plan); dismiss() }
            Button("Cancel", role: .cancel) {}
        }
    }
}

struct PlanItemRow: View {
    let item: PlanExerciseItem
    let index: Int
    var body: some View {
        HStack(spacing: 14) {
            Text("\(index)")
                .font(.system(size: 14, weight: .bold)).foregroundColor(.orange)
                .frame(width: 26, height: 26)
                .background(Color.orange.opacity(0.12)).cornerRadius(8)
            Image(systemName: item.muscleGroup.icon)
                .font(.system(size: 15)).foregroundColor(item.muscleGroup.color)
                .frame(width: 36, height: 36)
                .background(item.muscleGroup.color.opacity(0.12)).cornerRadius(9)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.exerciseName)
                    .font(.system(size: 13, weight: .semibold)).foregroundColor(.white)
                HStack(spacing: 10) {
                    Label("\(item.targetSets) sets", systemImage: "repeat")
                        .font(.system(size: 11)).foregroundColor(.gray)
                    Label("\(item.targetReps) reps", systemImage: "arrow.clockwise")
                        .font(.system(size: 11)).foregroundColor(.gray)
                    if item.targetWeight > 0 {
                        Label(String(format: "%.1f kg", item.targetWeight), systemImage: "scalemass")
                            .font(.system(size: 11)).foregroundColor(.orange)
                    }
                }
            }
            Spacer()
        }
        .padding(12).background(Color(hex: "1C1C1E")).cornerRadius(12)
    }
}

// MARK: - Plan Form (Create / Edit)
struct PlanFormView: View {
    var existing: WorkoutPlan?
    @EnvironmentObject var planStore:     WorkoutPlanStore
    @EnvironmentObject var exerciseStore: ExerciseStore
    @Environment(\.dismiss) var dismiss

    @State private var name      = ""
    @State private var notes     = ""
    @State private var colorHex  = "FF6B00"
    @State private var items:  [PlanExerciseItem] = []
    @State private var showingExPicker = false
    @State private var editingItem: PlanExerciseItem? = nil
    @FocusState private var focused: Bool

    let colors = ["FF6B00","FF3B30","FF9500","FFCC00","34C759",
                  "00C7BE","007AFF","5856D6","AF52DE","FF2D55"]

    var isEditing: Bool { existing != nil }

    var body: some View {
        ZStack {
            Color(hex: "111111").ignoresSafeArea()
                .onTapGesture { focused = false }

            VStack(spacing: 0) {
                // Top bar
                HStack {
                    Button("Cancel") { dismiss() }.foregroundColor(.orange)
                    Spacer()
                    Text(isEditing ? "Edit Program" : "New Program")
                        .font(.system(size: 17, weight: .semibold)).foregroundColor(.white)
                    Spacer()
                    Button("Save") { save() }
                        .foregroundColor(name.isEmpty ? .gray : .orange)
                        .disabled(name.isEmpty)
                }
                .padding(.horizontal, 20).padding(.top, 55).padding(.bottom, 16)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        // Name
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Program Name").font(.system(size: 13)).foregroundColor(.gray)
                            TextField("e.g. Push Day, Full Body...", text: $name)
                                .foregroundColor(.white).focused($focused)
                                .padding(14).background(Color(hex: "1C1C1E")).cornerRadius(12)
                        }

                        // Notes
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Notes (optional)").font(.system(size: 13)).foregroundColor(.gray)
                            TextField("Description...", text: $notes)
                                .foregroundColor(.white).focused($focused)
                                .padding(14).background(Color(hex: "1C1C1E")).cornerRadius(12)
                        }

                        // Color
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("Color").font(.system(size: 13)).foregroundColor(.gray)
                                Spacer()
                                Circle().fill(Color(hex: colorHex)).frame(width: 20, height: 20)
                            }
                            HStack(spacing: 10) {
                                ForEach(colors, id: \.self) { hex in
                                    Button(action: { colorHex = hex }) {
                                        Circle().fill(Color(hex: hex)).frame(height: 30)
                                            .overlay(Circle().stroke(Color.white,
                                                                     lineWidth: colorHex == hex ? 2.5 : 0))
                                            .scaleEffect(colorHex == hex ? 1.15 : 1)
                                            .animation(.spring(response: 0.25), value: colorHex)
                                    }
                                }
                            }
                        }
                        .padding(14).background(Color(hex: "1C1C1E")).cornerRadius(12)

                        // Exercise items
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("Exercises").font(.system(size: 17, weight: .bold)).foregroundColor(.white)
                                Spacer()
                                if items.count > 1 {
                                    Text("Drag ≡ to reorder")
                                        .font(.system(size: 10)).foregroundColor(.gray)
                                }
                            }

                            ForEach(Array(items.indices), id: \.self) { idx in
                                HStack(spacing: 0) {
                                    PlanItemEditRow(item: $items[idx]) {
                                        withAnimation { let i = idx; items.remove(at: i) }
                                    }
                                    // Drag handle — purely visual hint; use EditMode List for actual drag
                                }
                            }

                            // Reorder list — visible below items as a separate "reorder mode"
                            if items.count > 1 {
                                ReorderableItemList(items: $items)
                            }

                            Button(action: { showingExPicker = true }) {
                                HStack {
                                    Image(systemName: "plus.circle.fill").foregroundColor(.orange)
                                    Text("Add Exercise")
                                        .font(.system(size: 14, weight: .medium)).foregroundColor(.orange)
                                }
                                .frame(maxWidth: .infinity).frame(height: 46)
                                .background(Color.orange.opacity(0.1)).cornerRadius(12)
                                .overlay(RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.orange.opacity(0.3),
                                            style: StrokeStyle(lineWidth: 1, dash: [5])))
                            }
                        }

                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
        .onAppear { prefill() }
        .sheet(isPresented: $showingExPicker) {
            ExercisePickerForPlan(
                exercises: exerciseStore.exercises,
                alreadyAdded: items.map(\.exerciseId)
            ) { selected in
                for ex in selected {
                    guard !items.contains(where: { $0.exerciseId == ex.id }) else { continue }
                    items.append(PlanExerciseItem(
                        exerciseId:   ex.id,
                        exerciseName: ex.name,
                        muscleGroup:  ex.muscleGroup,
                        targetSets:   ex.sets,
                        targetReps:   ex.reps,
                        targetWeight: 0
                    ))
                }
            }
        }
    }

    func prefill() {
        guard let p = existing else { return }
        name     = p.name
        notes    = p.notes
        colorHex = p.colorHex
        items    = p.items
    }

    func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        if var p = existing {
            p.name     = trimmed
            p.notes    = notes
            p.colorHex = colorHex
            p.items    = items
            planStore.update(p)
        } else {
            planStore.add(WorkoutPlan(name: trimmed, notes: notes,
                                     items: items, colorHex: colorHex))
        }
        dismiss()
    }
}

// Editable row inside PlanFormView
struct PlanItemEditRow: View {
    @Binding var item: PlanExerciseItem
    var onDelete: () -> Void
    @FocusState private var wFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: item.muscleGroup.icon)
                    .foregroundColor(item.muscleGroup.color)
                Text(item.exerciseName)
                    .font(.system(size: 13, weight: .semibold)).foregroundColor(.white)
                Spacer()
                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill").foregroundColor(.gray.opacity(0.6))
                }
            }

            HStack(spacing: 16) {
                // Sets stepper
                VStack(spacing: 4) {
                    Text("Sets").font(.system(size: 10)).foregroundColor(.gray)
                    HStack(spacing: 8) {
                        Button(action: { if item.targetSets > 1 { item.targetSets -= 1 } }) {
                            Image(systemName: "minus").font(.system(size: 10)).foregroundColor(.orange)
                        }
                        Text("\(item.targetSets)").font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white).frame(width: 22, alignment: .center)
                        Button(action: { item.targetSets += 1 }) {
                            Image(systemName: "plus").font(.system(size: 10)).foregroundColor(.orange)
                        }
                    }
                    .padding(.vertical, 6).padding(.horizontal, 8)
                    .background(Color.white.opacity(0.06)).cornerRadius(8)
                }

                // Reps stepper
                VStack(spacing: 4) {
                    Text("Reps").font(.system(size: 10)).foregroundColor(.gray)
                    HStack(spacing: 8) {
                        Button(action: { if item.targetReps > 1 { item.targetReps -= 1 } }) {
                            Image(systemName: "minus").font(.system(size: 10)).foregroundColor(.orange)
                        }
                        Text("\(item.targetReps)").font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white).frame(width: 22, alignment: .center)
                        Button(action: { item.targetReps += 1 }) {
                            Image(systemName: "plus").font(.system(size: 10)).foregroundColor(.orange)
                        }
                    }
                    .padding(.vertical, 6).padding(.horizontal, 8)
                    .background(Color.white.opacity(0.06)).cornerRadius(8)
                }

                // Weight field
                VStack(spacing: 4) {
                    Text("Weight (kg)").font(.system(size: 10)).foregroundColor(.gray)
                    TextField("0", value: $item.targetWeight, format: .number)
                        .keyboardType(.decimalPad).focused($wFocused)
                        .font(.system(size: 14, weight: .bold)).foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .frame(width: 70).padding(.vertical, 6)
                        .background(Color.white.opacity(0.06)).cornerRadius(8)
                }
            }
        }
        .padding(12).background(Color(hex: "1C1C1E")).cornerRadius(12)
    }
}

// Simple exercise picker for plan builder
// Compact reorder-only list (drag to sort, no clip)
struct ReorderableItemList: View {
    @Binding var items: [PlanExerciseItem]
    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            Button(action: { withAnimation(.spring(response: 0.3)) { isExpanded.toggle() } }) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 12)).foregroundColor(.orange)
                    Text(isExpanded ? "Hide Reorder" : "Reorder Exercises")
                        .font(.system(size: 13, weight: .medium)).foregroundColor(.orange)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11)).foregroundColor(.gray)
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(Color.orange.opacity(0.08)).cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.orange.opacity(0.25), lineWidth: 1))
            }

            if isExpanded {
                List {
                    ForEach(Array(items.enumerated()), id: \.element.id) { idx, item in
                        HStack(spacing: 12) {
                            Image(systemName: "line.3.horizontal")
                                .font(.system(size: 16)).foregroundColor(.gray)
                            Text("\(idx + 1)")
                                .font(.system(size: 13, weight: .bold)).foregroundColor(.orange)
                                .frame(width: 22)
                            Image(systemName: item.muscleGroup.icon)
                                .font(.system(size: 13)).foregroundColor(item.muscleGroup.color)
                                .frame(width: 28, height: 28)
                                .background(item.muscleGroup.color.opacity(0.12)).cornerRadius(7)
                            Text(item.exerciseName)
                                .font(.system(size: 13, weight: .semibold)).foregroundColor(.white)
                                .lineLimit(1)
                            Spacer()
                        }
                        .padding(.vertical, 6)
                        .listRowBackground(Color(hex: "1C1C1E"))
                        .listRowSeparatorTint(Color.white.opacity(0.07))
                    }
                    .onMove { from, to in items.move(fromOffsets: from, toOffset: to) }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .frame(height: CGFloat(items.count) * 52 + 8)
                .environment(\.editMode, .constant(.active))
                .cornerRadius(10)
                .padding(.top, 6)
            }
        }
    }
}

struct ExercisePickerForPlan: View {
    let exercises:    [Exercise]
    var alreadyAdded: [UUID] = []
    let onSelect:     ([Exercise]) -> Void
    @Environment(\.dismiss) var dismiss
    @State private var search   = ""
    @State private var selected = Set<UUID>()

    var filtered: [Exercise] {
        search.isEmpty ? exercises
            : exercises.filter { $0.name.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "111111").ignoresSafeArea()
                VStack(spacing: 0) {
                    // Search bar
                    HStack {
                        Image(systemName: "magnifyingglass").foregroundColor(.gray)
                        TextField("Search...", text: $search).foregroundColor(.white)
                        if !search.isEmpty {
                            Button(action: { search = "" }) {
                                Image(systemName: "xmark.circle.fill").foregroundColor(.gray)
                            }
                        }
                    }
                    .padding(12).background(Color(hex: "2C2C2C")).cornerRadius(12)
                    .padding(.horizontal, 16).padding(.vertical, 10)

                    List(filtered) { ex in
                        let isAdded   = alreadyAdded.contains(ex.id)
                        let isChosen  = selected.contains(ex.id)
                        Button(action: {
                            if isAdded { return }
                            if isChosen { selected.remove(ex.id) }
                            else        { selected.insert(ex.id) }
                        }) {
                            HStack(spacing: 12) {
                                // Checkmark / already-added indicator
                                ZStack {
                                    Circle()
                                        .stroke(isAdded ? Color.gray : (isChosen ? Color.orange : Color.gray.opacity(0.4)), lineWidth: 2)
                                        .frame(width: 24, height: 24)
                                    if isAdded {
                                        Image(systemName: "checkmark").font(.system(size: 10, weight: .bold)).foregroundColor(.gray)
                                    } else if isChosen {
                                        Circle().fill(Color.orange).frame(width: 16, height: 16)
                                    }
                                }

                                Image(systemName: ex.muscleGroup.icon)
                                    .foregroundColor(ex.muscleGroup.color)
                                    .frame(width: 30, height: 30)
                                    .background(ex.muscleGroup.color.opacity(0.12)).cornerRadius(8)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(ex.name)
                                        .foregroundColor(isAdded ? .gray : .white)
                                        .font(.system(size: 14, weight: .medium))
                                    Text(ex.muscleGroups.map(\.rawValue).joined(separator: ", "))
                                        .foregroundColor(.gray).font(.system(size: 11))
                                }
                                Spacer()
                                if isAdded {
                                    Text("Added").font(.system(size: 10)).foregroundColor(.gray)
                                }
                            }
                        }
                        .disabled(isAdded)
                        .listRowBackground(Color(hex: "1C1C1E"))
                        .listRowSeparatorTint(Color.white.opacity(0.07))
                    }
                    .listStyle(.plain).scrollContentBackground(.hidden)

                    // Add button
                    if !selected.isEmpty {
                        Button(action: {
                            let toAdd = exercises.filter { selected.contains($0.id) }
                            onSelect(toAdd)
                            dismiss()
                        }) {
                            Text("Add \(selected.count) Exercise\(selected.count == 1 ? "" : "s")")
                                .font(.system(size: 16, weight: .semibold)).foregroundColor(.black)
                                .frame(maxWidth: .infinity).frame(height: 52)
                                .background(Color.orange).cornerRadius(26)
                        }
                        .padding(.horizontal, 20).padding(.vertical, 12)
                    }
                }
            }
            .navigationTitle("Add Exercises")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") { dismiss() }.foregroundColor(.orange),
                trailing: selected.isEmpty ? nil : Button("Select All") {
                    let addable = filtered.filter { !alreadyAdded.contains($0.id) }
                    addable.forEach { selected.insert($0.id) }
                }.foregroundColor(.orange)
            )
        }
        .preferredColorScheme(.dark)
    }
}
