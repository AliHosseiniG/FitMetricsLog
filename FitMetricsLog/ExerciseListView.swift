//
//  ExerciseListView.swift
//  FlexCore
//

import SwiftUI

// MARK: - Exercise List
struct ExerciseListView: View {
    @ObservedObject private var loc = LocalizationManager.shared
    @EnvironmentObject var exerciseStore: ExerciseStore
    @EnvironmentObject var logStore: WorkoutLogStore
    @EnvironmentObject var planStore: WorkoutPlanStore
    @ObservedObject private var muscleManager = MuscleGroupManager.shared
    @State private var selectedGroup: MuscleGroup? = nil
    @State private var searchText    = ""
    @State private var showingAdd    = false
    @State private var isSelecting   = false
    @State private var selectedIDs   = Set<UUID>()
    @State private var showDeleteAlert = false

    var filtered: [Exercise] {
        var result = exerciseStore.exercises
        if let g = selectedGroup { result = result.filter { $0.muscleGroups.contains(g) } }
        if !searchText.isEmpty {
            result = result.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.description.localizedCaseInsensitiveContains(searchText)
            }
        }
        return result
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "111111").ignoresSafeArea()
                VStack(spacing: 0) {
                    // Header
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(L(.exercises))
                                .font(.system(size: 26, weight: .bold)).foregroundColor(.white)
                            Text(isSelecting && !selectedIDs.isEmpty
                                 ? "\(selectedIDs.count) selected"
                                 : "\(filtered.count) " + L(.inYourLibrary))
                                .font(.system(size: 13))
                                .foregroundColor(isSelecting && !selectedIDs.isEmpty ? .orange : .gray)
                        }
                        Spacer()
                        HStack(spacing: 10) {
                            if isSelecting {
                                Button(action: {
                                    if selectedIDs.count == filtered.count {
                                        selectedIDs.removeAll()
                                    } else {
                                        selectedIDs = Set(filtered.map(\.id))
                                    }
                                }) {
                                    Text(selectedIDs.count == filtered.count ? L(.deselectAll) : L(.selectAll))
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
                                Button(action: { withAnimation { isSelecting = true } }) {
                                    Image(systemName: "checkmark.circle").font(.system(size: 22)).foregroundColor(.orange)
                                }
                                Button(action: { showingAdd = true }) {
                                    Image(systemName: "plus.circle.fill").font(.system(size: 28)).foregroundColor(.orange)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20).padding(.top, 60).padding(.bottom, 16)

                    // Search
                    HStack {
                        Image(systemName: "magnifyingglass").foregroundColor(.gray)
                        TextField(L(.exercises) + "...", text: $searchText).foregroundColor(.white)
                        if !searchText.isEmpty {
                            Button(action: { searchText = "" }) {
                                Image(systemName: "xmark.circle.fill").foregroundColor(.gray)
                            }
                        }
                    }
                    .padding(12).background(Color(hex: "2C2C2C")).cornerRadius(12)
                    .padding(.horizontal, 20).padding(.bottom, 12)

                    // Muscle filter chips
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            FilterChip(title: L(.all), isSelected: selectedGroup == nil) { selectedGroup = nil }
                            ForEach(MuscleGroupManager.shared.groups, id: \.self) { g in
                                FilterChip(title: g.rawValue, isSelected: selectedGroup == g) {
                                    selectedGroup = selectedGroup == g ? nil : g
                                }
                            }
                        }.padding(.horizontal, 20)
                    }.padding(.bottom, 12)

                    if exerciseStore.exercises.isEmpty {
                        emptyState
                    } else {
                        ScrollView(showsIndicators: false) {
                            LazyVStack(spacing: 12) {
                                ForEach(filtered) { ex in
                                    if isSelecting {
                                        Button(action: { toggleExercise(ex.id) }) {
                                            HStack(spacing: 12) {
                                                Image(systemName: selectedIDs.contains(ex.id)
                                                      ? "checkmark.circle.fill" : "circle")
                                                    .font(.system(size: 22))
                                                    .foregroundColor(selectedIDs.contains(ex.id) ? .orange : .gray.opacity(0.5))
                                                ExerciseRowCard(exercise: ex)
                                            }
                                        }.padding(.horizontal, 20)
                                    } else {
                                        NavigationLink(destination: ExerciseDetailView(exercise: ex)) {
                                            ExerciseRowCard(exercise: ex)
                                        }.padding(.horizontal, 20)
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
                AddExerciseView()
                    .environmentObject(exerciseStore)
                    .environmentObject(logStore)
            }
            .alert("Delete \(selectedIDs.count) Exercise\(selectedIDs.count == 1 ? "" : "s")?",
                   isPresented: $showDeleteAlert) {
                Button(L(.delete), role: .destructive) { deleteSelected() }
                Button(L(.cancel), role: .cancel) {}
            } message: { Text("This action cannot be undone.") }
        }
    }

    func toggleExercise(_ id: UUID) {
        if selectedIDs.contains(id) { selectedIDs.remove(id) } else { selectedIDs.insert(id) }
    }
    func deleteSelected() {
        for id in selectedIDs {
            if let ex = exerciseStore.exercises.first(where: { $0.id == id }) {
                exerciseStore.delete(ex)
            }
        }
        selectedIDs.removeAll(); isSelecting = false
    }

    var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "dumbbell")
                .font(.system(size: 60)).foregroundColor(.gray.opacity(0.4))
            Text(L(.noExercisesYet))
                .font(.system(size: 20, weight: .semibold)).foregroundColor(.white)
            Text(L(.tapToAddExercise))
                .font(.system(size: 14)).foregroundColor(.gray)
            Button(action: { showingAdd = true }) {
                Label("Add Exercise", systemImage: "plus")
                    .font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
                    .padding(.horizontal, 28).padding(.vertical, 14)
                    .background(Color.orange).cornerRadius(24)
            }.padding(.top, 8)
            Spacer()
        }
    }
}

// MARK: - Exercise Detail
struct ExerciseDetailView: View {
    @ObservedObject private var loc = LocalizationManager.shared
    @EnvironmentObject var exerciseStore: ExerciseStore
    @EnvironmentObject var logStore: WorkoutLogStore
    @EnvironmentObject var planStore: WorkoutPlanStore
    @ObservedObject private var muscleManager = MuscleGroupManager.shared
    @Environment(\.dismiss) var dismiss

    let exercise: Exercise
    @State private var showingEdit       = false
    @State private var showingDelete     = false
    @State private var fullscreenIndex: Int? = nil   // nil = hidden

    var live: Exercise {
        exerciseStore.exercises.first { $0.id == exercise.id } ?? exercise
    }

    var body: some View {
        ZStack {
            Color(hex: "111111").ignoresSafeArea()

            // Main scroll content
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    heroSection
                    VStack(alignment: .leading, spacing: 22) {
                        statsRow
                        if !live.description.isEmpty      { descSection }
                        if !live.tags.isEmpty             { tagsSection }
                        muscleSection
                        if !live.videoURL.isEmpty         { videoSection }
                        if !live.images.isEmpty           { gallerySection }
                        Spacer(minLength: 120)
                    }
                    .padding(.horizontal, 20).padding(.top, 20)
                }
            }

            // Floating nav bar overlay — always on top
            VStack {
                HStack {
                    // ← Back button
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 40, height: 40)
                            .background(Color.black.opacity(0.7))
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.4), radius: 4)
                    }
                    Spacer()
                    // ⋯ Menu
                    Menu {
                        Button("Edit", systemImage: "pencil")               { showingEdit = true }
                        Button("Delete", systemImage: "trash", role: .destructive) { showingDelete = true }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 40, height: 40)
                            .background(Color.black.opacity(0.7))
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.4), radius: 4)
                    }
                }
                .padding(.horizontal, 20).padding(.top, 55)
                Spacer()
            }
            .zIndex(50)  // always above hero image

            // Full-screen image viewer (topmost layer)
            if let idx = fullscreenIndex {
                FullscreenImageViewer(
                    images: live.images,
                    startIndex: idx,
                    onDismiss: { fullscreenIndex = nil },
                    onDelete: { deleteImage(at: $0) }
                )
                .zIndex(99)
                .transition(.opacity)
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showingEdit) {
            AddExerciseView(exerciseToEdit: live)
                .environmentObject(exerciseStore)
                .environmentObject(logStore)
        }
        .alert(L(.deleteExercise), isPresented: $showingDelete) {
            Button("Delete", role: .destructive) {
                exerciseStore.delete(exercise); dismiss()
            }
            Button(L(.cancel), role: .cancel) {}
        } message: {
            Text(L(.historyKept))
        }
    }

    // MARK: Hero image / gradient
    var heroSection: some View {
        ZStack(alignment: .bottomLeading) {
            if let img = live.firstImage {
                Image(uiImage: img)
                    .resizable().scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: 300)
                    .clipped()
                    .overlay(
                        LinearGradient(colors: [.clear, Color(hex: "111111")],
                                       startPoint: .center, endPoint: .bottom)
                    )
            } else {
                ZStack {
                    LinearGradient(
                        colors: [live.muscleGroup.color.opacity(0.35), Color(hex: "111111")],
                        startPoint: .top, endPoint: .bottom
                    )
                    Image(systemName: live.muscleGroup.icon)
                        .font(.system(size: 110))
                        .foregroundColor(live.muscleGroup.color.opacity(0.2))
                }
                .frame(height: 300)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(MuscleGroupManager.shared.liveName(for: live.muscleGroup))
                    .font(.system(size: 12, weight: .semibold)).foregroundColor(.orange)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Color.orange.opacity(0.15)).cornerRadius(8)
                Text(live.name)
                    .font(.system(size: 28, weight: .bold)).foregroundColor(.white)
            }.padding(20)
        }
    }

    // MARK: Stats
    var statsRow: some View {
        HStack(spacing: 0) {
            StatCell(icon: "clock.fill",    value: "\(live.duration)", unit: "min",  color: .orange)
            Divider().background(Color.white.opacity(0.12)).frame(height: 36)
            StatCell(icon: "repeat",        value: "\(live.sets)",     unit: "sets", color: .blue)
            Divider().background(Color.white.opacity(0.12)).frame(height: 36)
            StatCell(icon: "figure.strengthtraining.traditional",
                                            value: "\(live.reps)",     unit: "reps", color: .green)
            Divider().background(Color.white.opacity(0.12)).frame(height: 36)
            StatCell(icon: "chart.bar.fill", value: live.difficulty.localizedLabel, unit: "",
                     color: live.difficulty.color)
        }
        .padding(.vertical, 14)
        .background(Color(hex: "1C1C1E")).cornerRadius(14)
    }

    var descSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle("Description")
            Text(live.description)
                .font(.system(size: 14)).foregroundColor(.gray).lineSpacing(5)
        }
    }

    var tagsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle("Tags")
            HStack(spacing: 8) {
                ForEach(live.tags, id: \.self) { tag in
                    Text("#\(tag)")
                        .font(.system(size: 12)).foregroundColor(.orange)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Color.orange.opacity(0.12)).cornerRadius(10)
                }
            }
        }
    }

    var muscleSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(L(.muscleGroups))
            VStack(spacing: 8) {
                ForEach(Array(live.muscleGroups.enumerated()), id: \.element.id) { idx, g in
                    let liveG = MuscleGroupManager.shared.liveGroup(for: g.id) ?? g
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(liveG.color.opacity(0.15))
                                .frame(width: 46, height: 46)
                            if let img = liveG.image {
                                Image(uiImage: img).resizable().scaledToFill()
                                    .frame(width: 46, height: 46).clipped().cornerRadius(12)
                            } else {
                                Image(systemName: liveG.icon)
                                    .font(.system(size: 22)).foregroundColor(liveG.color)
                            }
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(liveG.rawValue)
                                .font(.system(size: 14, weight: .semibold)).foregroundColor(.white)
                            Text(idx == 0 ? L(.primary) : L(.secondary))
                                .font(.system(size: 11)).foregroundColor(.gray)
                        }
                        Spacer()
                    }
                }
            }
        }
    }

    // Video: taps open Safari / YouTube etc.
    var videoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle("Tutorial Video")
            Button(action: {
                let raw    = live.videoURL
                let urlStr = raw.hasPrefix("http") ? raw : "https://\(raw)"
                if let url = URL(string: urlStr) {
                    UIApplication.shared.open(url)
                }
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 36)).foregroundColor(.orange)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(L(.watchVideo))
                            .font(.system(size: 14, weight: .semibold)).foregroundColor(.white)
                        Text(live.videoURL)
                            .font(.system(size: 11)).foregroundColor(.gray).lineLimit(1)
                    }
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 13)).foregroundColor(.orange)
                }
                .padding(14)
                .background(Color(hex: "1C1C1E")).cornerRadius(12)
            }
        }
    }

    // Gallery: tap → fullscreen, long-press or X button → delete
    var gallerySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                SectionTitle("Photos  (\(live.images.count))")
                Spacer()
                if live.images.count > 0 {
                    Text(L(.tapToViewHoldToDelete))
                        .font(.system(size: 11)).foregroundColor(.gray)
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Array(live.images.enumerated()), id: \.offset) { idx, img in
                        ZStack(alignment: .topTrailing) {
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) { fullscreenIndex = idx }
                            }) {
                                Image(uiImage: img)
                                    .resizable().scaledToFill()
                                    .frame(width: 130, height: 130)
                                    .clipped().cornerRadius(14)
                                    .overlay(RoundedRectangle(cornerRadius: 14)
                                        .stroke(Color.white.opacity(0.08), lineWidth: 1))
                            }
                            .contextMenu {
                                Button(role: .destructive) { deleteImage(at: idx) } label: {
                                    Label(L(.delete) + " " + L(.photos), systemImage: "trash")
                                }
                            }
                            // Delete badge
                            Button(action: { deleteImage(at: idx) }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.white)
                                    .background(Color.black.opacity(0.55).clipShape(Circle()))
                            }
                            .offset(x: 6, y: -6)
                        }
                    }
                }
            }
        }
    }

    func deleteImage(at index: Int) {
        var updated = live
        updated.imageDatas.remove(at: index)
        exerciseStore.update(updated)
    }
}

// MARK: - Full-screen image viewer
struct FullscreenImageViewer: View {
    @ObservedObject private var loc = LocalizationManager.shared
    let images:      [UIImage]
    let startIndex:  Int
    let onDismiss:   () -> Void
    var onDelete:    ((Int) -> Void)? = nil   // optional delete callback

    @State private var currentIndex: Int
    @State private var showDeleteConfirm = false

    init(images: [UIImage], startIndex: Int,
         onDismiss: @escaping () -> Void,
         onDelete: ((Int) -> Void)? = nil) {
        self.images     = images
        self.startIndex = startIndex
        self.onDismiss  = onDismiss
        self.onDelete   = onDelete
        _currentIndex   = State(initialValue: startIndex)
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.96).ignoresSafeArea()

            TabView(selection: $currentIndex) {
                ForEach(Array(images.enumerated()), id: \.offset) { idx, img in
                    Image(uiImage: img)
                        .resizable().scaledToFit()
                        .tag(idx).padding()
                }
            }
            .tabViewStyle(.page)
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            VStack {
                // Top bar: close + delete
                HStack {
                    if onDelete != nil {
                        Button(action: { showDeleteConfirm = true }) {
                            Image(systemName: "trash.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.red)
                                .padding(10)
                                .background(Color.black.opacity(0.5).clipShape(Circle()))
                        }
                        .padding(.top, 55).padding(.leading, 20)
                    }
                    Spacer()
                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.white)
                            .background(Color.black.opacity(0.3).clipShape(Circle()))
                    }
                    .padding(.top, 55).padding(.trailing, 20)
                }
                Spacer()
                // Counter + delete hint
                VStack(spacing: 6) {
                    Text("\(currentIndex + 1) / \(images.count)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                    if onDelete != nil {
                        Text(L(.tapTrashToDelete))
                            .font(.system(size: 11)).foregroundColor(.gray)
                    }
                }.padding(.bottom, 40)
            }
        }
        .alert(L(.deletePhotoQ), isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                onDelete?(currentIndex)
                if images.count <= 1 { onDismiss() }
                else { currentIndex = max(0, currentIndex - 1) }
            }
            Button(L(.cancel), role: .cancel) {}
        } message: {
            Text(L(.thisCannotBeUndone))
        }
    }
}

// MARK: - Shared UI helpers

struct SectionTitle: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text).font(.system(size: 17, weight: .bold)).foregroundColor(.white)
    }
}

struct StatCell: View {
    let icon: String; let value: String; let unit: String; let color: Color
    var body: some View {
        VStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 16)).foregroundColor(color)
            Text(value).font(.system(size: 16, weight: .bold)).foregroundColor(.white)
            if !unit.isEmpty {
                Text(unit).font(.system(size: 10)).foregroundColor(.gray)
            }
        }.frame(maxWidth: .infinity)
    }
}

struct FilterChip: View {
    let title: String; let isSelected: Bool; let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? .black : .white)
                .padding(.horizontal, 16).padding(.vertical, 8)
                .background(isSelected ? Color.orange : Color(hex: "2C2C2C"))
                .cornerRadius(20)
        }
    }
}

/// Colored variant — used in Progress muscle filters
struct FilterChipColored: View {
    let title: String; let icon: String; let color: Color
    var muscleImage: UIImage? = nil
    let isSelected: Bool; let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                // Thumbnail or icon
                ZStack {
                    Circle().fill(color.opacity(isSelected ? 0.3 : 0.18)).frame(width: 22, height: 22)
                    if let img = muscleImage {
                        Image(uiImage: img).resizable().scaledToFill()
                            .frame(width: 22, height: 22).clipped().clipShape(Circle())
                    } else {
                        Image(systemName: icon).font(.system(size: 10))
                            .foregroundColor(isSelected ? .white : color)
                    }
                }
                Text(title).font(.system(size: 12, weight: isSelected ? .bold : .medium))
                if isSelected {
                    Image(systemName: "checkmark").font(.system(size: 9, weight: .bold))
                }
            }
            .foregroundColor(isSelected ? .white : color)
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(isSelected ? color : color.opacity(0.12))
            .cornerRadius(18)
            .overlay(RoundedRectangle(cornerRadius: 18)
                .stroke(color.opacity(isSelected ? 0 : 0.35), lineWidth: 1))
            .animation(.spring(response: 0.2), value: isSelected)
        }
    }
}

struct ExerciseRowCard: View {
    let exercise: Exercise
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(exercise.muscleGroup.color.opacity(0.15))
                    .frame(width: 78, height: 78)
                if let img = exercise.firstImage {
                    Image(uiImage: img)
                        .resizable().scaledToFill()
                        .frame(width: 78, height: 78)
                        .clipped().cornerRadius(12)
                        .clipped()
                } else {
                    Image(systemName: exercise.muscleGroup.icon)
                        .font(.system(size: 26)).foregroundColor(exercise.muscleGroup.color)
                }
            }
            VStack(alignment: .leading, spacing: 5) {
                Text(exercise.name)
                    .font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
                Text(exercise.description)
                    .font(.system(size: 11)).foregroundColor(.gray).lineLimit(2)
                HStack(spacing: 10) {
                    Label("\(exercise.duration)m", systemImage: "clock")
                        .font(.system(size: 11)).foregroundColor(.orange)
                    Label("\(exercise.sets)×\(exercise.reps)", systemImage: "repeat")
                        .font(.system(size: 11)).foregroundColor(.orange)
                    Text(exercise.difficulty.localizedLabel)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(exercise.difficulty.color)
                        .padding(.horizontal, 7).padding(.vertical, 2)
                        .background(exercise.difficulty.color.opacity(0.15)).cornerRadius(6)
                }
                // Muscle group chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 5) {
                        ForEach(exercise.muscleGroups) { g in
                            let liveG = MuscleGroupManager.shared.liveGroup(for: g.id) ?? g
                            HStack(spacing: 3) {
                                Image(systemName: liveG.icon).font(.system(size: 8))
                                Text(liveG.rawValue).font(.system(size: 9, weight: .medium))
                            }
                            .foregroundColor(liveG.color)
                            .padding(.horizontal, 6).padding(.vertical, 3)
                            .background(liveG.color.opacity(0.12)).cornerRadius(5)
                        }
                    }
                }
            }
            Spacer()
            Image(systemName: "chevron.right").font(.system(size: 11)).foregroundColor(.gray)
        }
        .padding(13).background(Color(hex: "1C1C1E")).cornerRadius(14)
    }
}
