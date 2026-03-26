//
//  WorkoutPlanView.swift
//  FlexCore
//

import SwiftUI

// MARK: - Plans Tab Root
struct WorkoutPlanListView: View {
    @ObservedObject private var loc = LocalizationManager.shared
    @EnvironmentObject var planStore:     WorkoutPlanStore
    @EnvironmentObject var exerciseStore: ExerciseStore
    @State private var showingAdd      = false
    @State private var showingAutoGen  = false
    @State private var editing: WorkoutPlan? = nil
    @State private var isSelecting     = false
    @State private var selectedIDs     = Set<UUID>()
    @State private var showDeleteAlert = false
    @State private var quickEdit: WorkoutPlan? = nil

    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "111111").ignoresSafeArea()
                VStack(spacing: 0) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(L(.programs))
                                .font(.system(size: 26, weight: .bold)).foregroundColor(.white)
                            Text(isSelecting && !selectedIDs.isEmpty
                                 ? "\(selectedIDs.count) selected"
                                 : "\(planStore.plans.count) " + L(.workoutPlans))
                                .font(.system(size: 13))
                                .foregroundColor(isSelecting && !selectedIDs.isEmpty ? .orange : .gray)
                        }
                        Spacer()
                        HStack(spacing: 10) {
                            if isSelecting {
                                Button(action: {
                                    if selectedIDs.count == planStore.plans.count {
                                        selectedIDs.removeAll()
                                    } else {
                                        selectedIDs = Set(planStore.plans.map(\.id))
                                    }
                                }) {
                                    Text(selectedIDs.count == planStore.plans.count ? L(.deselectAll) : L(.selectAll))
                                        .font(.system(size: 13)).foregroundColor(.orange)
                                }
                                Button(action: { if !selectedIDs.isEmpty { showDeleteAlert = true } }) {
                                    Image(systemName: "trash.fill").font(.system(size: 18))
                                        .foregroundColor(selectedIDs.isEmpty ? .gray : .red)
                                }.disabled(selectedIDs.isEmpty)
                                Button(action: { withAnimation { isSelecting = false; selectedIDs.removeAll() } }) {
                                    Text("Done").font(.system(size: 15, weight: .semibold)).foregroundColor(.orange)
                                }
                            } else {
                                Button(action: { showingAutoGen = true }) {
                                    Image(systemName: "wand.and.stars").font(.system(size: 22)).foregroundColor(.orange)
                                }
                                Button(action: { withAnimation { isSelecting = true } }) {
                                    Image(systemName: "checkmark.circle").font(.system(size: 22)).foregroundColor(.orange)
                                }
                                Button(action: { showingAdd = true }) {
                                    Image(systemName: "plus.circle.fill").font(.system(size: 28)).foregroundColor(.orange)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20).padding(.top, 60).padding(.bottom, 20)

                    if planStore.plans.isEmpty {
                        emptyState
                    } else {
                        ScrollView(showsIndicators: false) {
                            LazyVStack(spacing: 14) {
                                ForEach(planStore.plans) { plan in
                                    if isSelecting {
                                        Button(action: { togglePlan(plan.id) }) {
                                            HStack(spacing: 12) {
                                                Image(systemName: selectedIDs.contains(plan.id)
                                                      ? "checkmark.circle.fill" : "circle")
                                                    .font(.system(size: 22))
                                                    .foregroundColor(selectedIDs.contains(plan.id) ? .orange : .gray.opacity(0.5))
                                                PlanRowCard(plan: plan)
                                            }
                                        }.padding(.horizontal, 20)
                                    } else {
                                        NavigationLink(destination: PlanDetailView(plan: plan)) {
                                            PlanRowCard(plan: plan)
                                        }
                                        .padding(.horizontal, 20)
                                        .contextMenu {
                                            Button { quickEdit = plan } label: {
                                                Label(L(.edit), systemImage: "pencil")
                                            }
                                            Divider()
                                            Button(role: .destructive) { planStore.delete(plan) } label: {
                                                Label(L(.delete), systemImage: "trash")
                                            }
                                        }
                                    }
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
            .sheet(isPresented: $showingAutoGen) {
                AutoGeneratePlanView()
                    .environmentObject(planStore)
                    .environmentObject(exerciseStore)
            }
            .sheet(item: $quickEdit) { plan in
                PlanFormView(existing: plan)
                    .environmentObject(planStore)
                    .environmentObject(exerciseStore)
            }
            .alert("Delete \(selectedIDs.count) Program\(selectedIDs.count == 1 ? "" : "s")?",
                   isPresented: $showDeleteAlert) {
                Button(L(.delete), role: .destructive) { deleteSelected() }
                Button(L(.cancel), role: .cancel) {}
            } message: { Text(L(.cannotUndo)) }
        }
    }

    func togglePlan(_ id: UUID) {
        if selectedIDs.contains(id) { selectedIDs.remove(id) } else { selectedIDs.insert(id) }
    }
    func deleteSelected() {
        for id in selectedIDs {
            if let p = planStore.plans.first(where: { $0.id == id }) { planStore.delete(p) }
        }
        selectedIDs.removeAll(); isSelecting = false
    }

    var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "list.bullet.clipboard")
                .font(.system(size: 60)).foregroundColor(.gray.opacity(0.35))
            Text(L(.noPrograms))
                .font(.system(size: 20, weight: .semibold)).foregroundColor(.white)
            Text(L(.tapToCreate))
                .font(.system(size: 14)).foregroundColor(.gray)
                .multilineTextAlignment(.center).padding(.horizontal, 30)
            Button(action: { showingAdd = true }) {
                Label(L(.createProgram), systemImage: "plus")
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
    @ObservedObject private var loc = LocalizationManager.shared
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
                            Text(L(.exercises)).font(.system(size: 17, weight: .bold)).foregroundColor(.white)
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
                        Button(L(.delete), systemImage: "trash", role: .destructive) { showingDelete = true }
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
        .alert(L(.deleteProgram), isPresented: $showingDelete) {
            Button("Delete", role: .destructive) { planStore.delete(plan); dismiss() }
            Button(L(.cancel), role: .cancel) {}
        }
    }
}

struct PlanItemRow: View {
    @ObservedObject private var loc = LocalizationManager.shared
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
    @ObservedObject private var loc = LocalizationManager.shared
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
                    Button(L(.cancel)) { dismiss() }.foregroundColor(.orange)
                    Spacer()
                    Text(isEditing ? L(.editProgram) : L(.newProgram))
                        .font(.system(size: 17, weight: .semibold)).foregroundColor(.white)
                    Spacer()
                    Button(L(.save)) { save() }
                        .foregroundColor(name.isEmpty ? .gray : .orange)
                        .disabled(name.isEmpty)
                }
                .padding(.horizontal, 20).padding(.top, 55).padding(.bottom, 16)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        // Name
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L(.programName)).font(.system(size: 13)).foregroundColor(.gray)
                            TextField("e.g. Push Day, Full Body...", text: $name)
                                .foregroundColor(.white).focused($focused)
                                .padding(14).background(Color(hex: "1C1C1E")).cornerRadius(12)
                        }

                        // Notes
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L(.notes) + " (optional)").font(.system(size: 13)).foregroundColor(.gray)
                            TextField(L(.exerciseDesc) + "...", text: $notes)
                                .foregroundColor(.white).focused($focused)
                                .padding(14).background(Color(hex: "1C1C1E")).cornerRadius(12)
                        }

                        // Color
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text(L(.colorLabel)).font(.system(size: 13)).foregroundColor(.gray)
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
                                Text(L(.exercises)).font(.system(size: 17, weight: .bold)).foregroundColor(.white)
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
                                    Text(L(.addExercise))
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
                            Text(L(.add) + " \(selected.count) " + L(.exercises))
                                .font(.system(size: 16, weight: .semibold)).foregroundColor(.black)
                                .frame(maxWidth: .infinity).frame(height: 52)
                                .background(Color.orange).cornerRadius(26)
                        }
                        .padding(.horizontal, 20).padding(.vertical, 12)
                    }
                }
            }
            .navigationTitle(L(.addExercise))
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button(L(.cancel)) { dismiss() }.foregroundColor(.orange),
                trailing: selected.isEmpty ? nil : Button("Select All") {
                    let addable = filtered.filter { !alreadyAdded.contains($0.id) }
                    addable.forEach { selected.insert($0.id) }
                }.foregroundColor(.orange)
            )
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Auto Generate Plan View
struct AutoGeneratePlanView: View {
    @ObservedObject private var loc = LocalizationManager.shared
    @EnvironmentObject var planStore:     WorkoutPlanStore
    @EnvironmentObject var exerciseStore: ExerciseStore
    @ObservedObject private var muscleManager = MuscleGroupManager.shared
    @Environment(\.dismiss) var dismiss

    @State private var planName       = "Auto Program"
    @State private var selections:    [MuscleGroup: Int] = [:]
    @State private var generatedPlan: WorkoutPlan? = nil
    @State private var showPreview    = false
    @State private var errorMessage   = ""

    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "111111").ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {

                        // Plan name
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L(.programName)).font(.system(size: 13)).foregroundColor(.gray)
                            TextField("e.g. Full Body, Push Day...", text: $planName)
                                .foregroundColor(.white)
                                .padding(14).background(Color(hex: "1C1C1E")).cornerRadius(12)
                        }

                        // Muscle group selection
                        VStack(alignment: .leading, spacing: 12) {
                            Text(L(.selectMusclesCount))
                                .font(.system(size: 13)).foregroundColor(.gray)

                            ForEach(muscleManager.groups) { g in
                                let count     = selections[g] ?? 0
                                let available = exerciseStore.exercises
                                    .filter { $0.muscleGroups.contains(where: { $0.id == g.id }) }.count

                                HStack(spacing: 12) {
                                    Image(systemName: g.icon)
                                        .foregroundColor(g.color)
                                        .frame(width: 36, height: 36)
                                        .background(g.color.opacity(0.12)).cornerRadius(9)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(g.rawValue)
                                            .font(.system(size: 13, weight: .medium)).foregroundColor(.white)
                                        Text("\(available) exercise\(available == 1 ? "" : "s") available")
                                            .font(.system(size: 10)).foregroundColor(.gray)
                                    }

                                    Spacer()

                                    HStack(spacing: 10) {
                                        Button(action: { if count > 0 { selections[g] = count - 1 } }) {
                                            Image(systemName: "minus.circle")
                                                .foregroundColor(count > 0 ? .orange : .gray.opacity(0.3))
                                        }.disabled(count == 0)

                                        Text("\(count)")
                                            .font(.system(size: 15, weight: .bold))
                                            .foregroundColor(count > 0 ? .white : .gray)
                                            .frame(width: 22, alignment: .center)

                                        Button(action: { if count < available { selections[g] = count + 1 } }) {
                                            Image(systemName: "plus.circle")
                                                .foregroundColor(count < available ? .orange : .gray.opacity(0.3))
                                        }.disabled(count >= available)
                                    }
                                }
                                .padding(12)
                                .background(count > 0 ? g.color.opacity(0.08) : Color(hex: "1C1C1E"))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(count > 0 ? g.color.opacity(0.4) : Color.clear, lineWidth: 1)
                                )
                            }
                        }

                        // Summary of selection
                        let totalEx = selections.values.reduce(0, +)
                        if totalEx > 0 {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                                Text("\(totalEx) exercise\(totalEx == 1 ? "" : "s") from \(selections.filter { $0.value > 0 }.count) muscle group\(selections.filter { $0.value > 0 }.count == 1 ? "" : "s")")
                                    .font(.system(size: 13)).foregroundColor(.white)
                            }
                            .padding(12).background(Color.green.opacity(0.08)).cornerRadius(10)
                        }

                        if !errorMessage.isEmpty {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.red)
                                Text(errorMessage).font(.system(size: 13)).foregroundColor(.red)
                            }
                            .padding(12).background(Color.red.opacity(0.08)).cornerRadius(10)
                        }

                        // Generate button
                        Button(action: generatePlan) {
                            HStack(spacing: 8) {
                                Image(systemName: "wand.and.stars")
                                Text(L(.generateProgram))
                            }
                            .font(.system(size: 16, weight: .semibold)).foregroundColor(.black)
                            .frame(maxWidth: .infinity).frame(height: 52)
                            .background(canGenerate ? Color.orange : Color.gray.opacity(0.3))
                            .cornerRadius(26)
                        }
                        .disabled(!canGenerate)

                        Spacer(minLength: 80)
                    }
                    .padding(.horizontal, 20).padding(.top, 16)
                }
            }
            .navigationTitle("Auto-Generate Program")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(leading: Button(L(.cancel)) { dismiss() }.foregroundColor(.orange))
            .sheet(isPresented: $showPreview) {
                if let plan = generatedPlan {
                    AutoGenPreviewView(
                        plan: plan,
                        onSave: {
                            planStore.add(plan)
                            showPreview = false
                            dismiss()
                        },
                        onRegenerate: {
                            showPreview = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                generatePlan()
                            }
                        },
                        onCancel: { showPreview = false }
                    )
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    var canGenerate: Bool {
        !planName.trimmingCharacters(in: .whitespaces).isEmpty &&
        selections.values.reduce(0, +) > 0
    }

    func generatePlan() {
        errorMessage = ""
        var items: [PlanExerciseItem] = []

        // Keep muscle groups ordered: iterate muscleManager.groups to preserve order
        for g in muscleManager.groups {
            guard let count = selections[g], count > 0 else { continue }
            let pool = exerciseStore.exercises
                .filter { $0.muscleGroups.contains(where: { $0.id == g.id }) }
                .shuffled()
            let picked = Array(pool.prefix(count))
            if picked.count < count {
                errorMessage = "Not enough exercises for \(g.rawValue). Found \(picked.count), need \(count)."
                return
            }
            // Add group exercises consecutively (no shuffle between groups)
            for ex in picked {
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

        generatedPlan = WorkoutPlan(
            name:     planName.trimmingCharacters(in: .whitespaces),
            notes:    "Auto-generated",
            items:    items,
            colorHex: "FF6B00"
        )
        showPreview = true
    }
}

// MARK: - Auto-Gen Preview (full screen preview before save)
struct AutoGenPreviewView: View {
    @ObservedObject private var loc = LocalizationManager.shared
    let plan:          WorkoutPlan
    let onSave:        () -> Void
    let onRegenerate:  () -> Void
    let onCancel:      () -> Void

    // Group items by muscle group, preserving order
    var groupedItems: [(group: MuscleGroup, items: [PlanExerciseItem])] {
        var seen:   [String] = []
        var groups: [String: (MuscleGroup, [PlanExerciseItem])] = [:]
        for item in plan.items {
            let id = item.muscleGroup.id
            if groups[id] == nil {
                groups[id] = (item.muscleGroup, [])
                seen.append(id)
            }
            groups[id]!.1.append(item)
        }
        return seen.compactMap { id in
            guard let (g, items) = groups[id] else { return nil }
            return (g, items)
        }
    }

    var body: some View {
        ZStack {
            Color(hex: "111111").ignoresSafeArea()
            VStack(spacing: 0) {

                // Header
                VStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 3).fill(Color.gray.opacity(0.4))
                        .frame(width: 40, height: 4).padding(.top, 12)

                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(plan.name)
                                .font(.system(size: 20, weight: .bold)).foregroundColor(.white)
                            Text("\(plan.items.count) exercises · Auto-generated")
                                .font(.system(size: 12)).foregroundColor(.gray)
                        }
                        Spacer()
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 22)).foregroundColor(.orange)
                    }
                    .padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 16)

                    // Stats row
                    HStack(spacing: 0) {
                        previewStat(value: "\(plan.items.count)", label: L(.exercises))
                        Divider().background(Color.white.opacity(0.1)).frame(height: 30)
                        previewStat(value: "\(groupedItems.count)", label: "Muscle Groups")
                        Divider().background(Color.white.opacity(0.1)).frame(height: 30)
                        previewStat(value: "\(plan.items.reduce(0) { $0 + $1.targetSets })", label: "Total Sets")
                    }
                    .padding(.vertical, 12)
                    .background(Color(hex: "1C1C1E")).cornerRadius(12)
                    .padding(.horizontal, 20).padding(.bottom, 12)
                }
                .background(Color(hex: "111111"))

                // Exercise list grouped by muscle
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(groupedItems, id: \.group.id) { group, items in
                            VStack(alignment: .leading, spacing: 8) {
                                // Muscle group header
                                HStack(spacing: 8) {
                                    Image(systemName: group.icon)
                                        .font(.system(size: 12))
                                        .foregroundColor(group.color)
                                    Text(group.rawValue)
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(group.color)
                                    Text("\(items.count) exercise\(items.count == 1 ? "" : "s")")
                                        .font(.system(size: 11)).foregroundColor(.gray)
                                    Spacer()
                                }
                                .padding(.horizontal, 12).padding(.vertical, 8)
                                .background(group.color.opacity(0.1)).cornerRadius(10)

                                // Exercises in this group
                                ForEach(Array(items.enumerated()), id: \.offset) { idx, item in
                                    HStack(spacing: 12) {
                                        Text("\(idx + 1)")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(group.color)
                                            .frame(width: 22, height: 22)
                                            .background(group.color.opacity(0.15))
                                            .clipShape(Circle())

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(item.exerciseName)
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundColor(.white)
                                            Text("\(item.targetSets) sets × \(item.targetReps) reps")
                                                .font(.system(size: 11)).foregroundColor(.gray)
                                        }
                                        Spacer()
                                    }
                                    .padding(.horizontal, 12).padding(.vertical, 10)
                                    .background(Color(hex: "1C1C1E")).cornerRadius(10)
                                }
                            }
                        }
                        Spacer(minLength: 20)
                    }
                    .padding(.horizontal, 20).padding(.top, 12)
                }

                // Bottom action buttons
                VStack(spacing: 10) {
                    Button(action: onSave) {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                            Text(L(.saveProgram))
                        }
                        .font(.system(size: 16, weight: .semibold)).foregroundColor(.black)
                        .frame(maxWidth: .infinity).frame(height: 52)
                        .background(Color.orange).cornerRadius(26)
                    }

                    HStack(spacing: 10) {
                        Button(action: onRegenerate) {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                Text(L(.regenerate))
                            }
                            .font(.system(size: 15, weight: .medium)).foregroundColor(.orange)
                            .frame(maxWidth: .infinity).frame(height: 46)
                            .background(Color.orange.opacity(0.12)).cornerRadius(23)
                        }

                        Button(action: onCancel) {
                            Text(L(.cancel))
                                .font(.system(size: 15, weight: .medium)).foregroundColor(.gray)
                                .frame(maxWidth: .infinity).frame(height: 46)
                                .background(Color(hex: "2C2C2C")).cornerRadius(23)
                        }
                    }
                }
                .padding(.horizontal, 20).padding(.vertical, 16)
                .background(Color(hex: "111111"))
            }
        }
        .preferredColorScheme(.dark)
    }

    func previewStat(value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Text(value).font(.system(size: 16, weight: .bold)).foregroundColor(.orange)
            Text(label).font(.system(size: 10)).foregroundColor(.gray)
        }.frame(maxWidth: .infinity)
    }
}
