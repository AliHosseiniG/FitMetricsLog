//
//  WorkoutLogView.swift
//  FlexCore
//

import SwiftUI

// MARK: - Log Tab Root
struct LogView: View {
    @ObservedObject private var loc = LocalizationManager.shared
    @EnvironmentObject var logStore:      WorkoutLogStore
    @EnvironmentObject var exerciseStore: ExerciseStore
    @EnvironmentObject var planStore:     WorkoutPlanStore
    @State private var showingNew      = false
    @State private var showingExport   = false
    @State private var isSelecting     = false
    @State private var selectedIDs     = Set<UUID>()
    @State private var showDeleteAlert = false
    @State private var editSession:    WorkoutSession? = nil
    @State private var chartExercise:  Exercise? = nil

    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "111111").ignoresSafeArea()
                VStack(spacing: 0) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(L(.workoutLog))
                                .font(.system(size: 26, weight: .bold)).foregroundColor(.white)
                            Text(isSelecting && !selectedIDs.isEmpty
                                 ? "\(selectedIDs.count) " + L(.sessions)
                                 : "\(logStore.sessions.count) " + L(.sessions))
                                .font(.system(size: 13))
                                .foregroundColor(isSelecting && !selectedIDs.isEmpty ? .orange : .gray)
                                .animation(.easeInOut(duration: 0.2), value: selectedIDs.count)
                        }
                        Spacer()
                        HStack(spacing: 12) {
                            if isSelecting {
                                // Select All / Deselect All
                                Button(action: {
                                    if selectedIDs.count == logStore.sessions.count {
                                        selectedIDs.removeAll()
                                    } else {
                                        selectedIDs = Set(logStore.sessions.map(\.id))
                                    }
                                }) {
                                    Text(selectedIDs.count == logStore.sessions.count ? L(.deselectAll) : L(.selectAll))
                                        .font(.system(size: 13)).foregroundColor(.orange)
                                }
                                // Delete selected
                                Button(action: { if !selectedIDs.isEmpty { showDeleteAlert = true } }) {
                                    Image(systemName: "trash.fill")
                                        .font(.system(size: 18))
                                        .foregroundColor(selectedIDs.isEmpty ? .gray : .red)
                                }
                                .disabled(selectedIDs.isEmpty)
                                // Done
                                Button(action: { withAnimation { isSelecting = false; selectedIDs.removeAll() } }) {
                                    Text("Done").font(.system(size: 15, weight: .semibold)).foregroundColor(.orange)
                                }
                            } else {
                                Button(action: { showingExport = true }) {
                                    Image(systemName: "square.and.arrow.up")
                                        .font(.system(size: 22)).foregroundColor(.orange)
                                }
                                Button(action: { withAnimation { isSelecting = true } }) {
                                    Image(systemName: "checkmark.circle")
                                        .font(.system(size: 22)).foregroundColor(.orange)
                                }
                                Button(action: { showingNew = true }) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 28)).foregroundColor(.orange)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20).padding(.top, 60).padding(.bottom, 20)

                    if logStore.sessions.isEmpty {
                        emptyState
                    } else {
                        ScrollView(showsIndicators: false) {
                            LazyVStack(spacing: 14) {
                                ForEach(logStore.sessions.sorted { $0.date > $1.date }) { session in
                                    if isSelecting {
                                        // Selectable row
                                        Button(action: { toggleSession(session.id) }) {
                                            HStack(spacing: 12) {
                                                Image(systemName: selectedIDs.contains(session.id)
                                                      ? "checkmark.circle.fill" : "circle")
                                                    .font(.system(size: 22))
                                                    .foregroundColor(selectedIDs.contains(session.id) ? .orange : .gray.opacity(0.5))
                                                SessionRowCard(session: session)
                                            }
                                        }.padding(.horizontal, 20)
                                    } else {
                                        NavigationLink(destination: SessionDetailView(session: session)) {
                                            SessionRowCard(session: session)
                                        }
                                        .padding(.horizontal, 20)
                                        .contextMenu {
                                            Button { editSession = session } label: {
                                                Label(L(.edit), systemImage: "pencil")
                                            }
                                            Divider()
                                            Button(role: .destructive) { logStore.deleteSession(session) } label: {
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
            .sheet(isPresented: $showingNew) {
                NewSessionView(prefillPlan: nil)
                    .environmentObject(logStore)
                    .environmentObject(exerciseStore)
                    .environmentObject(planStore)
            }
            .sheet(isPresented: $showingExport) {
                ExportView().environmentObject(logStore)
            }
            .sheet(item: $editSession) { s in
                NewSessionView(prefillPlan: nil, existingSession: s)
                    .environmentObject(logStore)
                    .environmentObject(exerciseStore)
                    .environmentObject(planStore)
            }
            .alert("Delete \(selectedIDs.count) Session\(selectedIDs.count == 1 ? "" : "s")?",
                   isPresented: $showDeleteAlert) {
                Button(L(.delete), role: .destructive) { deleteSelected() }
                Button(L(.cancel), role: .cancel) {}
            } message: {
                Text(L(.cannotUndo))
            }
        }
    }

    func toggleSession(_ id: UUID) {
        if selectedIDs.contains(id) { selectedIDs.remove(id) }
        else { selectedIDs.insert(id) }
    }

    func deleteSelected() {
        for id in selectedIDs {
            if let s = logStore.sessions.first(where: { $0.id == id }) {
                logStore.deleteSession(s)
            }
        }
        selectedIDs.removeAll()
        isSelecting = false
    }

    var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 60)).foregroundColor(.gray.opacity(0.4))
            Text(L(.noLogsYet))
                .font(.system(size: 20, weight: .semibold)).foregroundColor(.white)
            Text(L(.tapToLog))
                .font(.system(size: 14)).foregroundColor(.gray)
            Button(action: { showingNew = true }) {
                Label(L(.logSession), systemImage: "plus")
                    .font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
                    .padding(.horizontal, 28).padding(.vertical, 14)
                    .background(Color.orange).cornerRadius(24)
            }.padding(.top, 8)
            Spacer()
        }
    }
}

// MARK: - Session Row Card
struct SessionRowCard: View {
    let session: WorkoutSession
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(session.date.formatted(date: .complete, time: .omitted))
                        .font(.system(size: 14, weight: .semibold)).foregroundColor(.white)
                    Text(session.date.formatted(date: .omitted, time: .shortened))
                        .font(.system(size: 11)).foregroundColor(.gray.opacity(0.7))
                    if let planName = session.sourcePlanName {
                        Label(planName, systemImage: "list.bullet.clipboard")
                            .font(.system(size: 11, weight: .medium)).foregroundColor(.orange)
                    }
                    Text("\(session.logs.count) exercise\(session.logs.count == 1 ? "" : "s")")
                        .font(.system(size: 12)).foregroundColor(.gray)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text("\(Int(session.totalVolume)) kg")
                        .font(.system(size: 16, weight: .bold)).foregroundColor(.orange)
                    Text("total volume").font(.system(size: 11)).foregroundColor(.gray)
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    ForEach(session.muscleGroups, id: \.self) { g in
                        let lg = MuscleGroupManager.shared.liveGroup(for: g.id) ?? g
                        HStack(spacing: 4) {
                            Image(systemName: lg.icon).font(.system(size: 10))
                            Text(lg.rawValue).font(.system(size: 10, weight: .medium))
                        }
                        .foregroundColor(lg.color)
                        .padding(.horizontal, 9).padding(.vertical, 4)
                        .background(lg.color.opacity(0.14)).cornerRadius(8)
                    }
                }
            }
            HStack(spacing: 18) {
                LogMiniStat(icon: "clock",      value: "\(session.durationMinutes) min")
                LogMiniStat(icon: "flame.fill", value: "\(session.logs.reduce(0){$0+$1.sets.count}) sets")
                LogMiniStat(icon: "repeat",     value: "\(session.logs.reduce(0){$0+$1.totalReps}) reps")
            }
        }
        .padding(16).background(Color(hex: "1C1C1E")).cornerRadius(16)
    }
}

struct LogMiniStat: View {
    let icon: String; let value: String
    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 11)).foregroundColor(.orange)
            Text(value).font(.system(size: 12)).foregroundColor(.gray)
        }
    }
}

// MARK: - Session Detail (with Edit button)
struct SessionDetailView: View {
    @ObservedObject private var loc = LocalizationManager.shared
    @EnvironmentObject var logStore:      WorkoutLogStore
    @EnvironmentObject var exerciseStore: ExerciseStore
    @EnvironmentObject var planStore:     WorkoutPlanStore
    @Environment(\.dismiss) var dismiss

    let session: WorkoutSession
    @State private var showingDelete  = false
    @State private var showingEdit    = false
    @State private var isReordering   = false
    @State private var chartExercise: Exercise? = nil

    var live: WorkoutSession {
        logStore.sessions.first { $0.id == session.id } ?? session
    }

    func toggleCompleted(log: WorkoutLog) {
        guard var s = logStore.sessions.first(where: { $0.id == session.id }),
              let li = s.logs.firstIndex(where: { $0.id == log.id }) else { return }
        s.logs[li].isCompleted.toggle()
        logStore.updateSession(s)
    }

    func moveLogs(from: IndexSet, to: Int) {
        guard var s = logStore.sessions.first(where: { $0.id == session.id }) else { return }
        s.logs.move(fromOffsets: from, toOffset: to)
        logStore.updateSession(s)
    }

    var body: some View {
        ZStack {
            Color(hex: "111111").ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        Button(action: { dismiss() }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold)).foregroundColor(.white)
                                .frame(width: 40, height: 40)
                                .background(Color(hex: "2C2C2C")).clipShape(Circle())
                        }
                        Spacer()
                        Text(live.date.formatted(date: .abbreviated, time: .omitted))
                            .font(.system(size: 16, weight: .semibold)).foregroundColor(.white)
                        Spacer()
                        Menu {
                            Button(L(.editSession), systemImage: "pencil") { showingEdit = true }
                            Button(L(.duplicateSession), systemImage: "doc.on.doc") { duplicateSession() }
                            Divider()
                            Button(L(.delete), systemImage: "trash", role: .destructive) { showingDelete = true }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 15)).foregroundColor(.white)
                                .frame(width: 40, height: 40)
                                .background(Color(hex: "2C2C2C")).clipShape(Circle())
                        }
                    }
                    .padding(.horizontal, 20).padding(.top, 55)

                    HStack(spacing: 0) {
                        SessCell(value: "\(Int(live.totalVolume))", unit: "kg vol")
                        Divider().background(Color.white.opacity(0.1)).frame(height: 36)
                        SessCell(value: "\(live.logs.count)",       unit: "exercises")
                        Divider().background(Color.white.opacity(0.1)).frame(height: 36)
                        SessCell(value: "\(live.durationMinutes)",  unit: "min")
                        Divider().background(Color.white.opacity(0.1)).frame(height: 36)
                        SessCell(value: "\(live.logs.reduce(0){$0+$1.sets.count})", unit: "sets")
                    }
                    .padding(.vertical, 14)
                    .background(Color(hex: "1C1C1E")).cornerRadius(14)
                    .padding(.horizontal, 20)

                    // Reorder button
                    HStack {
                        Spacer()
                        Button(action: { withAnimation { isReordering.toggle() } }) {
                            Label(isReordering ? "Done" : "Reorder",
                                  systemImage: isReordering ? "checkmark" : "arrow.up.arrow.down")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.orange)
                        }
                    }.padding(.horizontal, 20)

                    if isReordering {
                        List {
                            ForEach(live.logs) { log in
                                HStack(spacing: 10) {
                                    Image(systemName: "line.3.horizontal")
                                        .foregroundColor(.gray)
                                    Text(log.exerciseName)
                                        .font(.system(size: 13, weight: .medium)).foregroundColor(.white)
                                    Spacer()
                                }
                                .padding(.vertical, 6)
                                .listRowBackground(Color(hex: "1C1C1E"))
                                .listRowSeparatorTint(Color.white.opacity(0.07))
                            }
                            .onMove(perform: moveLogs)
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                        .frame(height: CGFloat(live.logs.count) * 52)
                        .environment(\.editMode, .constant(.active))
                        .background(Color(hex: "1C1C1E")).cornerRadius(12)
                        .padding(.horizontal, 20)
                    } else {
                        ForEach(live.logs) { log in
                            ExLogCard(
                                log: log,
                                onChart: {
                                    if let ex = exerciseStore.exercises.first(where: { $0.id == log.exerciseId }) {
                                        chartExercise = ex
                                    }
                                },
                                onToggleComplete: { toggleCompleted(log: log) }
                            )
                                .padding(.horizontal, 20)
                                .background(
                                    log.isCompleted
                                        ? Color.green.opacity(0.06).cornerRadius(14)
                                        : Color.clear.cornerRadius(14)
                                )
                        }
                    }
                    if !live.sessionNotes.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(L(.notes)).font(.system(size: 14, weight: .semibold)).foregroundColor(.gray)
                            Text(live.sessionNotes).font(.system(size: 13)).foregroundColor(.white)
                        }.padding(.horizontal, 20)
                    }
                    Spacer(minLength: 100)
                }
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showingEdit) {
            NewSessionView(prefillPlan: nil, existingSession: live)
                .environmentObject(logStore)
                .environmentObject(exerciseStore)
                .environmentObject(planStore)
        }
        .sheet(item: $chartExercise) { ex in
            ExerciseChartView(exercise: ex).environmentObject(logStore)
        }
        .alert(L(.deleteSession), isPresented: $showingDelete) {
            Button(L(.delete), role: .destructive) { logStore.deleteSession(session); dismiss() }
            Button(L(.cancel), role: .cancel) {}
        }
    }

    func duplicateSession() {
        var copy = live
        copy.id   = UUID()
        copy.date = Date()
        // Reset log IDs
        copy.logs = copy.logs.map { log in
            var l = log; l.id = UUID()
            l.sets = l.sets.map { s in var s2 = s; s2.id = UUID(); return s2 }
            return l
        }
        logStore.addSession(copy)
    }
}

struct SessCell: View {
    let value: String; let unit: String
    var body: some View {
        VStack(spacing: 3) {
            Text(value).font(.system(size: 18, weight: .bold)).foregroundColor(.orange)
            Text(unit).font(.system(size: 10)).foregroundColor(.gray)
        }.frame(maxWidth: .infinity)
    }
}

struct ExLogCard: View {
    let log: WorkoutLog
    var onChart: (() -> Void)? = nil
    var onToggleComplete: (() -> Void)? = nil
    var body: some View {
        let liveG = MuscleGroupManager.shared.liveGroup(for: log.muscleGroup.id) ?? log.muscleGroup
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                // Exercise photo or icon
                ZStack {
                    RoundedRectangle(cornerRadius: 9)
                        .fill(liveG.color.opacity(0.15))
                        .frame(width: 44, height: 44)
                    if let data = log.exerciseImageData, let img = UIImage(data: data) {
                        Image(uiImage: img).resizable().scaledToFill()
                            .frame(width: 44, height: 44).clipped().cornerRadius(9)
                    } else {
                        Image(systemName: liveG.icon)
                            .font(.system(size: 18)).foregroundColor(liveG.color)
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(log.exerciseName)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(log.isCompleted ? .gray : .white)
                            .strikethrough(log.isCompleted, color: .gray)
                        // Chart button — inline next to exercise name
                        if onChart != nil {
                            Button(action: { onChart?() }) {
                                Image(systemName: "chart.line.uptrend.xyaxis")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.orange.opacity(0.85))
                                    .frame(width: 26, height: 22)
                                    .background(Color.orange.opacity(0.12))
                                    .cornerRadius(6)
                            }
                        }
                    }
                    Text(liveG.rawValue)
                        .font(.system(size: 11)).foregroundColor(liveG.color)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(Int(log.maxWeight)) kg max")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(log.isCompleted ? .gray : .white)
                    Text("\(Int(log.totalVolume)) kg vol")
                        .font(.system(size: 11)).foregroundColor(.gray)
                }
                // Checkbox
                if onToggleComplete != nil {
                    Button(action: { onToggleComplete?() }) {
                        Image(systemName: log.isCompleted ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 24))
                            .foregroundColor(log.isCompleted ? .green : .gray.opacity(0.5))
                    }
                }
            }
            HStack {
                Text("SET").frame(width: 30, alignment: .leading)
                Spacer()
                Text("WEIGHT").frame(width: 90, alignment: .center)
                Spacer()
                Text("REPS").frame(width: 50, alignment: .trailing)
            }.font(.system(size: 10, weight: .semibold)).foregroundColor(.gray)

            ForEach(log.sets) { s in
                HStack {
                    Text("\(s.setNumber)").frame(width: 30, alignment: .leading).foregroundColor(.orange)
                    Spacer()
                    Text(String(format: "%.1f kg", s.weight)).frame(width: 90, alignment: .center).foregroundColor(.white)
                    Spacer()
                    Text("\(s.reps)").frame(width: 50, alignment: .trailing).foregroundColor(.white)
                }
                .font(.system(size: 13))
                .padding(.vertical, 4).padding(.horizontal, 8)
                .background(Color.white.opacity(0.04)).cornerRadius(7)
            }
            HStack(spacing: 5) {
                Image(systemName: "trophy.fill").font(.system(size: 11)).foregroundColor(.yellow)
                Text("Est. 1RM: \(Int(log.estimatedOneRepMax)) kg")
                    .font(.system(size: 11)).foregroundColor(.gray)
            }
            // Exercise images gallery (all photos)
            let allImgs = log.allImages
            if !allImgs.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(allImgs.enumerated()), id: \.offset) { _, img in
                            Image(uiImage: img).resizable().scaledToFill()
                                .frame(width: allImgs.count == 1 ? 220 : 120, height: 90)
                                .clipped().cornerRadius(10)
                        }
                    }
                }.padding(.top, 4)
            }
        }
        .padding(14).background(Color(hex: "1C1C1E")).cornerRadius(14)
        .contextMenu {
            if let onChart {
                Button(action: onChart) {
                    Label("Volume Chart", systemImage: "chart.line.uptrend.xyaxis")
                }
            }
        }
    }
}

// MARK: - New / Edit Session
struct NewSessionView: View {
    @ObservedObject private var loc = LocalizationManager.shared
    @EnvironmentObject var logStore:      WorkoutLogStore
    @EnvironmentObject var exerciseStore: ExerciseStore
    @EnvironmentObject var planStore:     WorkoutPlanStore
    @Environment(\.dismiss) var dismiss

    var prefillPlan:      WorkoutPlan?    = nil
    var existingSession:  WorkoutSession? = nil

    @State private var sessionDate     = Date()
    @State private var durationMinutes = 60
    @State private var sessionNotes    = ""
    @State private var entries: [DraftLog] = []

    @State private var showingExPicker   = false
    @State private var showingPlanPicker = false
    @FocusState private var anyFocused:  Bool

    var isEditing: Bool { existingSession != nil }

    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "111111").ignoresSafeArea()
                    .onTapGesture { anyFocused = false }

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        // Date & Time
                        HStack {
                            Label(L(.tabLog) + " · " + "Zeit", systemImage: "calendar.clock")
                                .foregroundColor(.gray).font(.system(size: 14))
                            Spacer()
                            DatePicker("", selection: $sessionDate,
                                       displayedComponents: [.date, .hourAndMinute])
                                .colorScheme(.dark).labelsHidden()
                        }
                        .padding(14).background(Color(hex: "1C1C1E")).cornerRadius(12)

                        // Duration
                        HStack {
                            Label(L(.duration), systemImage: "clock")
                                .foregroundColor(.gray).font(.system(size: 14))
                            Spacer()
                            HStack(spacing: 14) {
                                Button(action: { if durationMinutes > 15 { durationMinutes -= 15 } }) {
                                    Image(systemName: "minus.circle").foregroundColor(.orange)
                                }
                                Text("\(durationMinutes) min")
                                    .font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
                                    .frame(width: 75, alignment: .center)
                                Button(action: { durationMinutes += 15 }) {
                                    Image(systemName: "plus.circle").foregroundColor(.orange)
                                }
                            }
                        }
                        .padding(14).background(Color(hex: "1C1C1E")).cornerRadius(12)

                        // Load from plan
                        if !isEditing && !planStore.plans.isEmpty {
                            Button(action: { showingPlanPicker = true }) {
                                HStack {
                                    Image(systemName: "list.bullet.clipboard.fill").foregroundColor(.orange)
                                    Text(L(.loadFromProgram))
                                        .font(.system(size: 14, weight: .medium)).foregroundColor(.orange)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12)).foregroundColor(.gray)
                                }
                                .padding(14).background(Color(hex: "1C1C1E")).cornerRadius(12)
                            }
                        }

                        // Exercises
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text(L(.exercises))
                                    .font(.system(size: 17, weight: .bold)).foregroundColor(.white)
                                Spacer()
                                if !entries.isEmpty {
                                    Text("\(entries.count) added").font(.system(size: 12)).foregroundColor(.gray)
                                }
                            }
                            ForEach(Array(entries.indices), id: \.self) { idx in
                                DraftLogCard(entry: $entries[idx]) { entries.remove(at: idx) }
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

                        // Notes
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L(.notes)).font(.system(size: 13)).foregroundColor(.gray)
                            ZStack(alignment: .topLeading) {
                                if sessionNotes.isEmpty {
                                    Text(L(.notes) + "...").foregroundColor(.gray.opacity(0.5))
                                        .font(.system(size: 14)).padding(14)
                                }
                                TextEditor(text: $sessionNotes)
                                    .foregroundColor(.white).frame(height: 70)
                                    .scrollContentBackground(.hidden).padding(10)
                                    .focused($anyFocused)
                            }
                            .background(Color(hex: "1C1C1E")).cornerRadius(12)
                        }

                        // Save
                        Button(action: save) {
                            Text(isEditing ? L(.editSession) : L(.newSession))
                                .font(.system(size: 17, weight: .semibold)).foregroundColor(.white)
                                .frame(maxWidth: .infinity).frame(height: 54)
                                .background(LinearGradient(colors: [.orange, .orange.opacity(0.8)],
                                                           startPoint: .leading, endPoint: .trailing))
                                .cornerRadius(27)
                        }
                        .disabled(entries.isEmpty).opacity(entries.isEmpty ? 0.5 : 1)

                        Spacer(minLength: 60)
                    }
                    .padding(.horizontal, 20).padding(.top, 8)
                }
            }
            .navigationTitle(isEditing ? L(.editSession) : L(.logSession))
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(leading: Button(L(.cancel)) { dismiss() }.foregroundColor(.orange))
            .sheet(isPresented: $showingExPicker) {
                LogExercisePickerView(exercises: exerciseStore.exercises) { ex in
                    entries.append(DraftLog(exercise: ex))
                }
            }
            .sheet(isPresented: $showingPlanPicker) {
                LogPlanPickerView(plans: planStore.plans, exercises: exerciseStore.exercises) { items in
                    for item in items where !entries.contains(where: { $0.exerciseId == item.exerciseId }) {
                        entries.append(DraftLog(planItem: item))
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { prefill() }
    }

    func prefill() {
        if let s = existingSession {
            sessionDate = s.date; durationMinutes = s.durationMinutes; sessionNotes = s.sessionNotes
            entries = s.logs.map { log in
                var d = DraftLog(exerciseId: log.exerciseId, exerciseName: log.exerciseName, muscleGroup: log.muscleGroup)
                d.sets = log.sets.map { DraftSet(weight: $0.weight, reps: $0.reps) }
                return d
            }
        } else if let p = prefillPlan {
            entries = p.items.map { DraftLog(planItem: $0) }
        }
    }

    // Resize image data to max dimension for display in log
    func resizedData(_ data: Data, maxDimension: CGFloat = 600) -> Data {
        guard let img = UIImage(data: data) else { return data }
        let size = img.size
        let scale = min(maxDimension / size.width, maxDimension / size.height, 1.0)
        if scale >= 1.0 { return data }
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resized = renderer.image { _ in img.draw(in: CGRect(origin: .zero, size: newSize)) }
        return resized.jpegData(compressionQuality: 0.75) ?? data
    }

    func save() {
        let logs: [WorkoutLog] = entries.compactMap { d in
            guard !d.sets.isEmpty else { return nil }
            let ex = exerciseStore.exercises.first { $0.id == d.exerciseId }
            let imgDatas = (ex?.imageDatas ?? []).map { resizedData($0, maxDimension: 600) }
            return WorkoutLog(exerciseId: d.exerciseId, exerciseName: d.exerciseName,
                              muscleGroup: d.muscleGroup, date: sessionDate,
                              sets: d.sets.enumerated().map { i, s in
                                  WorkoutSet(setNumber: i+1, weight: s.weight, reps: s.reps)
                              },
                              exerciseImageData: imgDatas.first,
                              exerciseImageDatas: imgDatas)
        }
        guard !logs.isEmpty else { dismiss(); return }
        if var e = existingSession {
            e.date = sessionDate; e.durationMinutes = durationMinutes
            e.sessionNotes = sessionNotes; e.logs = logs
            logStore.updateSession(e)
        } else {
            var s = WorkoutSession(date: sessionDate, logs: logs)
            s.durationMinutes = durationMinutes; s.sessionNotes = sessionNotes
            s.sourcePlanId   = prefillPlan?.id
            s.sourcePlanName = prefillPlan?.name
            logStore.addSession(s)
        }
        dismiss()
    }
}

// MARK: - Draft models
struct DraftLog: Identifiable {
    var id = UUID()
    var exerciseId:   UUID
    var exerciseName: String
    var muscleGroup:  MuscleGroup
    var sets: [DraftSet] = [DraftSet()]

    init(exercise: Exercise) {
        exerciseId = exercise.id; exerciseName = exercise.name; muscleGroup = exercise.muscleGroup
    }
    init(exerciseId: UUID, exerciseName: String, muscleGroup: MuscleGroup) {
        self.exerciseId = exerciseId; self.exerciseName = exerciseName; self.muscleGroup = muscleGroup
    }
    init(planItem: PlanExerciseItem) {
        exerciseId = planItem.exerciseId; exerciseName = planItem.exerciseName; muscleGroup = planItem.muscleGroup
        sets = Array(repeating: DraftSet(weight: planItem.targetWeight, reps: planItem.targetReps),
                     count: max(1, planItem.targetSets))
    }
}

struct DraftSet: Identifiable {
    var id = UUID(); var weight: Double = 0; var reps: Int = 10
}

// MARK: - Draft Log Card (keyboard dismiss on tap)
struct DraftLogCard: View {
    @ObservedObject private var loc = LocalizationManager.shared
    @Binding var entry: DraftLog
    var onDelete: () -> Void
    @FocusState private var wFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: entry.muscleGroup.icon).foregroundColor(entry.muscleGroup.color)
                Text(entry.exerciseName).font(.system(size: 14, weight: .semibold)).foregroundColor(.white)
                Spacer()
                Button(action: onDelete) { Image(systemName: "xmark.circle.fill").foregroundColor(.gray) }
            }
            HStack {
                Text("SET").frame(width: 28, alignment: .leading)
                Spacer()
                Text("WEIGHT (kg)").frame(width: 110, alignment: .center)
                Spacer()
                Text("REPS").frame(width: 70, alignment: .trailing)
            }.font(.system(size: 10, weight: .semibold)).foregroundColor(.gray)

            ForEach(Array(entry.sets.indices), id: \.self) { idx in
                HStack {
                    Text("\(idx+1)").font(.system(size: 12)).foregroundColor(.orange).frame(width: 28, alignment: .leading)
                    Spacer()
                    TextField("0.0", value: $entry.sets[idx].weight, format: .number)
                        .keyboardType(.decimalPad).focused($wFocused)
                        .font(.system(size: 14, weight: .semibold)).foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .frame(width: 110).padding(.vertical, 6)
                        .background(Color.white.opacity(0.06)).cornerRadius(8)
                    Spacer()
                    HStack(spacing: 10) {
                        Button(action: { if entry.sets[idx].reps > 1 { entry.sets[idx].reps -= 1 } }) {
                            Image(systemName: "minus").font(.system(size: 10)).foregroundColor(.orange)
                        }
                        Text("\(entry.sets[idx].reps)")
                            .font(.system(size: 14, weight: .semibold)).foregroundColor(.white).frame(width: 26)
                        Button(action: { entry.sets[idx].reps += 1 }) {
                            Image(systemName: "plus").font(.system(size: 10)).foregroundColor(.orange)
                        }
                    }.frame(width: 70, alignment: .trailing)
                }
            }

            HStack {
                Button(action: { entry.sets.append(DraftSet()) }) {
                    Label("Add Set", systemImage: "plus").font(.system(size: 12)).foregroundColor(.orange)
                }
                Spacer()
                if entry.sets.count > 1 {
                    Button(action: { entry.sets.removeLast() }) {
                        Label("Remove", systemImage: "minus").font(.system(size: 12)).foregroundColor(.red)
                    }
                }
            }
        }
        .padding(14).background(Color(hex: "1C1C1E")).cornerRadius(14)
        .onTapGesture { wFocused = false }
    }
}

// MARK: - Exercise Picker for Log (shows image thumbnails)
struct LogExercisePickerView: View {
    let exercises: [Exercise]
    let onSelect:  (Exercise) -> Void
    @Environment(\.dismiss) var dismiss
    @State private var search = ""
    @State private var filterGroup: MuscleGroup? = nil

    var filtered: [Exercise] {
        var list = exercises
        if let g = filterGroup { list = list.filter { $0.muscleGroup == g } }
        if !search.isEmpty { list = list.filter { $0.name.localizedCaseInsensitiveContains(search) } }
        return list
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "111111").ignoresSafeArea()
                VStack(spacing: 0) {
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
                    .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 8)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            FilterChip(title: "All", isSelected: filterGroup == nil) { filterGroup = nil }
                            ForEach(MuscleGroupManager.shared.groups, id: \.self) { g in
                                FilterChip(title: g.rawValue, isSelected: filterGroup == g) {
                                    filterGroup = filterGroup == g ? nil : g
                                }
                            }
                        }.padding(.horizontal, 16)
                    }.padding(.bottom, 8)

                    List(filtered) { ex in
                        Button(action: { onSelect(ex); dismiss() }) {
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(ex.muscleGroup.color.opacity(0.15)).frame(width: 36, height: 36)
                                    if let img = ex.firstImage {
                                        Image(uiImage: img).resizable().scaledToFill()
                                            .frame(width: 36, height: 36).clipped().cornerRadius(8)
                                    } else {
                                        Image(systemName: ex.muscleGroup.icon).foregroundColor(ex.muscleGroup.color)
                                    }
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(ex.name).foregroundColor(.white).font(.system(size: 14))
                                    Text(ex.muscleGroup.rawValue).foregroundColor(.gray).font(.system(size: 11))
                                }
                                Spacer()
                                Text("\(ex.sets)×\(ex.reps)").font(.system(size: 11)).foregroundColor(.orange)
                            }
                        }
                        .listRowBackground(Color(hex: "1C1C1E"))
                    }
                    .listStyle(.plain).scrollContentBackground(.hidden)
                }
            }
            .navigationTitle(L(.addExercise))
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(leading: Button(L(.cancel)) { dismiss() }.foregroundColor(.orange))
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Plan Picker for Log Session
struct LogPlanPickerView: View {
    let plans:     [WorkoutPlan]
    let exercises: [Exercise]
    let onSelect:  ([PlanExerciseItem]) -> Void
    @Environment(\.dismiss) var dismiss

    @State private var selectedIDs = Set<UUID>()   // IDs of PlanExerciseItems
    @State private var tab = 0
    // generic items created on-the-fly for exercises tab
    @State private var genericItems: [UUID: PlanExerciseItem] = [:]

    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "111111").ignoresSafeArea()
                VStack(spacing: 0) {
                    // Segment
                    HStack(spacing: 0) {
                        tabButton("Programs", idx: 0)
                        tabButton("All Exercises", idx: 1)
                    }
                    .padding(4).background(Color(hex: "1C1C1E")).cornerRadius(12)
                    .padding(.horizontal, 20).padding(.vertical, 12)

                    if tab == 0 { plansTab } else { exercisesTab }

                    if !selectedIDs.isEmpty {
                        Button(action: commitSelection) {
                            Text("Add \(selectedIDs.count) Exercise\(selectedIDs.count == 1 ? "" : "s")")
                                .font(.system(size: 16, weight: .semibold)).foregroundColor(.white)
                                .frame(maxWidth: .infinity).frame(height: 50)
                                .background(Color.orange).cornerRadius(25)
                        }
                        .padding(.horizontal, 20).padding(.vertical, 12)
                    }
                }
            }
            .navigationTitle("Load Exercises")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(leading: Button(L(.cancel)) { dismiss() }.foregroundColor(.orange))
        }
        .preferredColorScheme(.dark)
        .onAppear { buildGenericItems() }
    }

    func tabButton(_ title: String, idx: Int) -> some View {
        Button(action: { tab = idx }) {
            Text(title)
                .font(.system(size: 13, weight: tab == idx ? .bold : .regular))
                .foregroundColor(tab == idx ? .black : .gray)
                .frame(maxWidth: .infinity).padding(.vertical, 8)
                .background(tab == idx ? Color.orange : Color.clear)
                .cornerRadius(9)
        }
    }

    var plansTab: some View {
        List {
            ForEach(plans) { plan in
                Section {
                    Button(action: { togglePlan(plan) }) {
                        HStack {
                            selectCircle(on: allSelected(plan))
                            Image(systemName: "list.bullet.clipboard.fill").foregroundColor(plan.color)
                            Text("All of \"\(plan.name)\"")
                                .font(.system(size: 14, weight: .semibold)).foregroundColor(.white)
                            Spacer()
                            Text("\(plan.items.count) ex").font(.system(size: 11)).foregroundColor(.gray)
                        }
                    }
                    .listRowBackground(Color(hex: "2C2C2C"))

                    ForEach(plan.items) { item in
                        Button(action: { toggle(item.id) }) {
                            HStack {
                                selectCircle(on: selectedIDs.contains(item.id))
                                Image(systemName: item.muscleGroup.icon).foregroundColor(item.muscleGroup.color)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.exerciseName).foregroundColor(.white).font(.system(size: 13))
                                    Text("\(item.targetSets)×\(item.targetReps) · \(item.targetWeight > 0 ? String(format: "%.0f kg", item.targetWeight) : "bodyweight")")
                                        .foregroundColor(.gray).font(.system(size: 11))
                                }
                                Spacer()
                            }
                        }
                        .listRowBackground(Color(hex: "1C1C1E"))
                    }
                } header: {
                    Text(plan.name).foregroundColor(plan.color).font(.system(size: 13, weight: .semibold))
                }
            }
        }
        .listStyle(.insetGrouped).scrollContentBackground(.hidden)
    }

    var exercisesTab: some View {
        List(exercises) { ex in
            let item = genericItems[ex.id] ?? defaultItem(ex)
            Button(action: { toggle(item.id) }) {
                HStack {
                    selectCircle(on: selectedIDs.contains(item.id))
                    ZStack {
                        RoundedRectangle(cornerRadius: 7)
                            .fill(ex.muscleGroup.color.opacity(0.15)).frame(width: 32, height: 32)
                        Image(systemName: ex.muscleGroup.icon).foregroundColor(ex.muscleGroup.color)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(ex.name).foregroundColor(.white).font(.system(size: 13))
                        Text(ex.muscleGroup.rawValue).foregroundColor(.gray).font(.system(size: 11))
                    }
                    Spacer()
                    Text("\(ex.sets)×\(ex.reps)").font(.system(size: 11)).foregroundColor(.orange)
                }
            }
            .listRowBackground(Color(hex: "1C1C1E"))
        }
        .listStyle(.plain).scrollContentBackground(.hidden)
    }

    func selectCircle(on: Bool) -> some View {
        ZStack {
            Circle().stroke(on ? Color.orange : Color.gray, lineWidth: 2).frame(width: 22, height: 22)
            if on { Circle().fill(Color.orange).frame(width: 14, height: 14) }
        }
    }

    func toggle(_ id: UUID) {
        if selectedIDs.contains(id) { selectedIDs.remove(id) } else { selectedIDs.insert(id) }
    }
    func allSelected(_ plan: WorkoutPlan) -> Bool { plan.items.allSatisfy { selectedIDs.contains($0.id) } }
    func togglePlan(_ plan: WorkoutPlan) {
        if allSelected(plan) { plan.items.forEach { selectedIDs.remove($0.id) } }
        else { plan.items.forEach { selectedIDs.insert($0.id) } }
    }

    func defaultItem(_ ex: Exercise) -> PlanExerciseItem {
        PlanExerciseItem(exerciseId: ex.id, exerciseName: ex.name,
                         muscleGroup: ex.muscleGroup, targetSets: ex.sets,
                         targetReps: ex.reps, targetWeight: 0)
    }

    func buildGenericItems() {
        var dict: [UUID: PlanExerciseItem] = [:]
        for ex in exercises { dict[ex.id] = defaultItem(ex) }
        genericItems = dict
    }

    func commitSelection() {
        var result: [PlanExerciseItem] = []
        var seen = Set<UUID>()
        // Plan items first
        for plan in plans {
            for item in plan.items where selectedIDs.contains(item.id) {
                if seen.insert(item.exerciseId).inserted { result.append(item) }
            }
        }
        // Generic exercise items
        for (_, item) in genericItems where selectedIDs.contains(item.id) {
            if seen.insert(item.exerciseId).inserted { result.append(item) }
        }
        onSelect(result)
        dismiss()
    }
}

// MARK: - Export View
struct ExportView: View {
    @EnvironmentObject var logStore: WorkoutLogStore
    @ObservedObject private var loc = LocalizationManager.shared
    @Environment(\.dismiss) var dismiss

    @State private var format: ExportFormat = .csv
    @State private var exportAll  = true
    @State private var selectedIDs = Set<UUID>()
    @State private var shareURL: URL? = nil
    @State private var showShare  = false
    @State private var isWorking  = false

    enum ExportFormat: String, CaseIterable {
        case csv  = "CSV"
        case pdf  = "PDF"
        case json = "JSON"
        var icon: String {
            switch self {
            case .csv:  return "tablecells"
            case .pdf:  return "doc.richtext"
            case .json: return "curlybraces.square"
            }
        }
    }

    var sessionsToExport: [WorkoutSession] {
        let all = logStore.sessions.sorted { $0.date > $1.date }
        return exportAll ? all : all.filter { selectedIDs.contains($0.id) }
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "111111").ignoresSafeArea()
                VStack(spacing: 0) {

                    // ── Format selector ──
                    HStack(spacing: 10) {
                        ForEach(ExportFormat.allCases, id: \.self) { f in
                            Button(action: { format = f }) {
                                HStack(spacing: 6) {
                                    Image(systemName: f.icon)
                                    Text(f.rawValue).fontWeight(.semibold)
                                }
                                .font(.system(size: 14))
                                .foregroundColor(format == f ? .black : .gray)
                                .frame(maxWidth: .infinity).padding(.vertical, 12)
                                .background(format == f ? Color.orange : Color(hex: "2C2C2C"))
                                .cornerRadius(12)
                            }
                        }
                    }
                    .padding(.horizontal, 20).padding(.top, 20).padding(.bottom, 16)

                    // ── Scope toggle ──
                    HStack(spacing: 0) {
                        scopeButton(label: L(.selectAll) + " (\(logStore.sessions.count))",
                                    active: exportAll) { exportAll = true }
                        scopeButton(label: L(.selectSessions),
                                    active: !exportAll) { exportAll = false }
                    }
                    .padding(.horizontal, 20).padding(.bottom, 12)

                    // ── Session list (only when picking) ──
                    if !exportAll {
                        List(logStore.sessions.sorted { $0.date > $1.date }) { session in
                            Button(action: { toggle(session.id) }) {
                                HStack(spacing: 12) {
                                    Image(systemName: selectedIDs.contains(session.id)
                                          ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 22))
                                        .foregroundColor(selectedIDs.contains(session.id) ? .orange : .gray.opacity(0.4))
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(session.date.formatted(date: .abbreviated, time: .shortened))
                                            .font(.system(size: 14, weight: .medium)).foregroundColor(.white)
                                        Text("\(session.logs.count) " + L(.exercises) + " · \(Int(session.totalVolume)) kg")
                                            .font(.system(size: 11)).foregroundColor(.gray)
                                    }
                                    Spacer()
                                }
                            }
                            .listRowBackground(Color(hex: "1C1C1E"))
                        }
                        .listStyle(.plain).scrollContentBackground(.hidden)
                    } else {
                        // All-sessions summary card
                        VStack(spacing: 14) {
                            Image(systemName: "tray.full.fill")
                                .font(.system(size: 52)).foregroundColor(.orange.opacity(0.85))
                            Text("\(logStore.sessions.count) " + L(.sessions))
                                .font(.system(size: 22, weight: .bold)).foregroundColor(.white)
                            Text(L(.willBeIncluded))
                                .font(.system(size: 13)).foregroundColor(.gray)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.top, 20)
                    }

                    // ── Export button ──
                    VStack(spacing: 8) {
                        if !exportAll && selectedIDs.isEmpty {
                            Text(L(.selectAtLeastOne))
                                .font(.system(size: 12)).foregroundColor(.red.opacity(0.8))
                        }
                        Button(action: doExport) {
                            ZStack {
                                if isWorking {
                                    ProgressView().tint(.white)
                                } else {
                                    HStack(spacing: 10) {
                                        Image(systemName: "square.and.arrow.up")
                                            .font(.system(size: 16, weight: .semibold))
                                        Text(exportLabel)
                                            .font(.system(size: 16, weight: .semibold))
                                    }
                                }
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity).frame(height: 54)
                            .background(canExport ? Color.orange : Color.gray.opacity(0.35))
                            .cornerRadius(27)
                        }
                        .disabled(!canExport || isWorking)
                    }
                    .padding(.horizontal, 20).padding(.vertical, 16)
                    .background(Color(hex: "1A1A1A"))
                }
            }
            .navigationTitle(L(.exportData))
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(leading:
                Button(L(.cancel)) { dismiss() }.foregroundColor(.orange)
            )
            .sheet(isPresented: $showShare) {
                if let url = shareURL { ShareSheetView(items: [url]) }
            }
        }
        .preferredColorScheme(.dark)
    }

    var canExport: Bool {
        !sessionsToExport.isEmpty
    }

    var exportLabel: String {
        let count = sessionsToExport.count
        return "\(count) \(L(.sessions)) · \(format.rawValue)"
    }

    func scopeButton(label: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13, weight: active ? .semibold : .regular))
                .foregroundColor(active ? .orange : .gray)
                .frame(maxWidth: .infinity).padding(.vertical, 8)
                .background(active ? Color.orange.opacity(0.12) : Color.clear)
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10)
                    .stroke(active ? Color.orange.opacity(0.4) : Color.gray.opacity(0.2), lineWidth: 1))
        }
    }

    func toggle(_ id: UUID) {
        if selectedIDs.contains(id) { selectedIDs.remove(id) }
        else { selectedIDs.insert(id) }
    }

    func doExport() {
        guard canExport else { return }
        isWorking = true
        let sessions = sessionsToExport
        let fmt = format
        DispatchQueue.global(qos: .userInitiated).async {
            let url: URL?
            switch fmt {
            case .csv:  url = ExportHelper.generateCSV(sessions: sessions)
            case .pdf:  url = ExportHelper.generatePDF(sessions: sessions)
            case .json: url = ExportHelper.generateJSON(sessions: sessions)
            }
            DispatchQueue.main.async {
                isWorking = false
                if let url {
                    shareURL = url
                    showShare = true
                }
            }
        }
    }
}


// MARK: - Share Sheet
struct ShareSheetView: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

// MARK: - Export Helper
struct ExportHelper {

    // MARK: JSON
    static func generateJSON(sessions: [WorkoutSession]) -> URL? {
        struct LogBundle: Codable {
            let exportDate: String
            let sessionCount: Int
            let sessions: [WorkoutSession]
        }
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        let bundle = LogBundle(
            exportDate: df.string(from: Date()),
            sessionCount: sessions.count,
            sessions: sessions.sorted { $0.date > $1.date }
        )
        guard let data = try? JSONEncoder().encode(bundle) else { return nil }
        let filename = "FitMetricsLog_WorkoutLogs_\(df.string(from: Date())).json"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try? data.write(to: url)
        return url
    }

    // MARK: CSV
    static func generateCSV(sessions: [WorkoutSession]) -> URL? {
        var rows: [String] = []
        rows.append("Date,Duration(min),Exercise,MuscleGroup,Set,Weight(kg),Reps,Volume,Notes")
        let df = DateFormatter(); df.dateStyle = .short; df.timeStyle = .none

        for session in sessions.sorted(by: { $0.date > $1.date }) {
            for log in session.logs {
                if log.sets.isEmpty {
                    let row = [
                        df.string(from: session.date),
                        "\(session.durationMinutes)",
                        csvEscape(log.exerciseName),
                        csvEscape(log.muscleGroup.rawValue),
                        "","","","",
                        csvEscape(session.sessionNotes)
                    ].joined(separator: ",")
                    rows.append(row)
                } else {
                    for s in log.sets {
                        let vol = s.weight * Double(s.reps)
                        let row = [
                            df.string(from: session.date),
                            "\(session.durationMinutes)",
                            csvEscape(log.exerciseName),
                            csvEscape(log.muscleGroup.rawValue),
                            "\(s.setNumber)",
                            String(format: "%.1f", s.weight),
                            "\(s.reps)",
                            String(format: "%.1f", vol),
                            csvEscape(session.sessionNotes)
                        ].joined(separator: ",")
                        rows.append(row)
                    }
                }
            }
        }

        let csv = rows.joined(separator: "\n")
        return writeTemp(data: Data(csv.utf8), filename: "FitMetricsLog_Workouts_\(timestamp()).csv")
    }

    private static func csvEscape(_ s: String) -> String {
        let escaped = s.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }

    // MARK: PDF
    static func generatePDF(sessions: [WorkoutSession]) -> URL? {
        let pageW: CGFloat = 595, pageH: CGFloat = 842
        let margin: CGFloat = 40
        let pageRect = CGRect(x: 0, y: 0, width: pageW, height: pageH)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        let df = DateFormatter(); df.dateStyle = .medium; df.timeStyle = .none

        // Light theme colors
        let bgColor      = UIColor.white
        let textColor    = UIColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1)
        let subColor     = UIColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1)
        let headerBg     = UIColor(red: 0.95, green: 0.95, blue: 0.97, alpha: 1)
        let accentColor  = UIColor(red: 1.0, green: 0.42, blue: 0.0, alpha: 1)
        let separatorClr = UIColor(red: 0.85, green: 0.85, blue: 0.87, alpha: 1)

        let pdfData = renderer.pdfData { ctx in
            ctx.beginPage()
            var y: CGFloat = margin

            func fillBackground() {
                bgColor.setFill()
                UIRectFill(pageRect)
            }

            func drawText(_ text: String, x: CGFloat, y: CGFloat, size: CGFloat,
                          bold: Bool = false, color: UIColor = UIColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1),
                          maxWidth: CGFloat = pageW - 2*margin) {
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: bold ? UIFont.boldSystemFont(ofSize: size) : UIFont.systemFont(ofSize: size),
                    .foregroundColor: color
                ]
                NSAttributedString(string: text, attributes: attrs)
                    .draw(in: CGRect(x: x, y: y, width: maxWidth, height: 1000))
            }

            func newPageIfNeeded(requiredHeight: CGFloat) {
                if y + requiredHeight > pageH - margin {
                    ctx.beginPage()
                    fillBackground()
                    y = margin
                }
            }

            // White background
            fillBackground()

            // Title
            drawText("FitMetricsLog — Workout Log", x: margin, y: y, size: 22, bold: true, color: textColor)
            y += 30
            drawText("Generated \(df.string(from: Date())) · \(sessions.count) sessions",
                     x: margin, y: y, size: 11, color: subColor)
            y += 20

            // Orange accent line
            accentColor.setFill()
            UIRectFill(CGRect(x: margin, y: y, width: pageW - 2*margin, height: 2))
            y += 14

            for session in sessions.sorted(by: { $0.date < $1.date }) {
                newPageIfNeeded(requiredHeight: 60)

                // Session header — light gray box
                headerBg.setFill()
                UIBezierPath(roundedRect: CGRect(x: margin, y: y, width: pageW - 2*margin, height: 30),
                             cornerRadius: 6).fill()

                drawText(df.string(from: session.date), x: margin + 10, y: y + 8,
                         size: 12, bold: true, color: textColor)
                let stats = "\(session.durationMinutes) min · \(session.logs.count) exercises · \(Int(session.totalVolume)) kg"
                drawText(stats, x: margin + 200, y: y + 9, size: 10, color: accentColor)
                y += 38

                for log in session.logs {
                    newPageIfNeeded(requiredHeight: 24 + CGFloat(log.sets.count) * 18)

                    drawText("• \(log.exerciseName)  (\(MuscleGroupManager.shared.liveName(for: log.muscleGroup)))",
                             x: margin + 10, y: y, size: 11, bold: true, color: textColor)
                    y += 16

                    drawText("SET",    x: margin + 20,  y: y, size: 9, color: subColor)
                    drawText("WEIGHT", x: margin + 60,  y: y, size: 9, color: subColor)
                    drawText("REPS",   x: margin + 130, y: y, size: 9, color: subColor)
                    drawText("VOL",    x: margin + 185, y: y, size: 9, color: subColor)
                    y += 14

                    for s in log.sets {
                        drawText("\(s.setNumber)",                            x: margin + 20,  y: y, size: 10, color: textColor)
                        drawText(String(format: "%.1f kg", s.weight),          x: margin + 60,  y: y, size: 10, color: textColor)
                        drawText("\(s.reps)",                                 x: margin + 130, y: y, size: 10, color: textColor)
                        drawText(String(format: "%.0f kg", s.weight * Double(s.reps)), x: margin + 185, y: y, size: 10, color: subColor)
                        y += 16
                    }

                    let orm = String(format: "%.0f", log.estimatedOneRepMax)
                    drawText("Est. 1RM: \(orm) kg", x: margin + 20, y: y, size: 9, color: accentColor)
                    y += 16

                    separatorClr.setFill()
                    UIRectFill(CGRect(x: margin + 10, y: y, width: pageW - 2*margin - 10, height: 0.5))
                    y += 8
                }

                if !session.sessionNotes.isEmpty {
                    drawText("Notes: \(session.sessionNotes)", x: margin + 10, y: y,
                             size: 10, color: subColor)
                    y += 14
                }

                y += 14
            }
        }

        return writeTemp(data: pdfData, filename: "FitMetricsLog_Workouts_\(timestamp()).pdf")
    }

    // MARK: Helpers
    private static func timestamp() -> String {
        let df = DateFormatter(); df.dateFormat = "yyyyMMdd_HHmm"
        return df.string(from: Date())
    }

    private static func writeTemp(data: Data, filename: String) -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        do { try data.write(to: url); return url }
        catch { return nil }
    }
}
