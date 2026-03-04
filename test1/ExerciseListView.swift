//
//  ExerciseListView.swift
//  FlexCore
//

import SwiftUI

// MARK: - Exercise List
struct ExerciseListView: View {
    @EnvironmentObject var exerciseStore: ExerciseStore
    @EnvironmentObject var logStore: WorkoutLogStore
    @EnvironmentObject var planStore: WorkoutPlanStore
    @ObservedObject private var muscleManager = MuscleGroupManager.shared
    @State private var selectedGroup: MuscleGroup? = nil
    @State private var searchText  = ""
    @State private var showingAdd  = false

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
                            Text("Exercises")
                                .font(.system(size: 26, weight: .bold)).foregroundColor(.white)
                            Text("\(filtered.count) in library")
                                .font(.system(size: 13)).foregroundColor(.gray)
                        }
                        Spacer()
                        Button(action: { showingAdd = true }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 28)).foregroundColor(.orange)
                        }
                    }
                    .padding(.horizontal, 20).padding(.top, 60).padding(.bottom, 16)

                    // Search
                    HStack {
                        Image(systemName: "magnifyingglass").foregroundColor(.gray)
                        TextField("Search exercises...", text: $searchText).foregroundColor(.white)
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
                            FilterChip(title: "All", isSelected: selectedGroup == nil) {
                                selectedGroup = nil
                            }
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
                                    NavigationLink(destination: ExerciseDetailView(exercise: ex)) {
                                        ExerciseRowCard(exercise: ex)
                                    }.padding(.horizontal, 20)
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
        }
    }

    var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "dumbbell")
                .font(.system(size: 60)).foregroundColor(.gray.opacity(0.4))
            Text("No exercises yet")
                .font(.system(size: 20, weight: .semibold)).foregroundColor(.white)
            Text("Tap + to add your first exercise")
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

            // Floating nav bar overlay
            VStack {
                HStack {
                    // ← Back button
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 40, height: 40)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                    }
                    Spacer()
                    // ⋯ Menu
                    Menu {
                        Button("Edit", systemImage: "pencil")               { showingEdit = true }
                        Button("Delete", systemImage: "trash", role: .destructive) { showingDelete = true }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                            .frame(width: 40, height: 40)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 20).padding(.top, 55)
                Spacer()
            }

            // Full-screen image viewer (topmost layer)
            if let idx = fullscreenIndex {
                FullscreenImageViewer(
                    images: live.images,
                    startIndex: idx,
                    onDismiss: { fullscreenIndex = nil }
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
        .alert("Delete Exercise", isPresented: $showingDelete) {
            Button("Delete", role: .destructive) {
                exerciseStore.delete(exercise); dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Workout history for this exercise will be kept.")
        }
    }

    // MARK: Hero image / gradient
    var heroSection: some View {
        ZStack(alignment: .bottomLeading) {
            if let img = live.firstImage {
                Image(uiImage: img)
                    .resizable().scaledToFill()
                    .frame(height: 300).clipped()
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
            StatCell(icon: "chart.bar.fill", value: live.difficulty.rawValue, unit: "",
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
            SectionTitle("Muscle Groups")
            VStack(spacing: 8) {
                ForEach(Array(live.muscleGroups.enumerated()), id: \.element.id) { idx, g in
                    let liveG = MuscleGroupManager.shared.liveGroup(for: g.id) ?? g
                    HStack(spacing: 12) {
                        Image(systemName: liveG.icon)
                            .font(.system(size: 22))
                            .foregroundColor(liveG.color)
                            .frame(width: 46, height: 46)
                            .background(liveG.color.opacity(0.15))
                            .cornerRadius(12)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(liveG.rawValue)
                                .font(.system(size: 14, weight: .semibold)).foregroundColor(.white)
                            Text(idx == 0 ? "Primary" : "Secondary")
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
                        Text("Watch Video")
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

    // Gallery: tap any thumbnail → full-screen viewer
    var gallerySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle("Photos  (\(live.images.count))")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Array(live.images.enumerated()), id: \.offset) { idx, img in
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                fullscreenIndex = idx
                            }
                        }) {
                            Image(uiImage: img)
                                .resizable().scaledToFill()
                                .frame(width: 130, height: 130)
                                .clipped().cornerRadius(14)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                                )
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Full-screen image viewer
struct FullscreenImageViewer: View {
    let images:     [UIImage]
    let startIndex: Int
    let onDismiss:  () -> Void

    @State private var currentIndex: Int

    init(images: [UIImage], startIndex: Int, onDismiss: @escaping () -> Void) {
        self.images    = images
        self.startIndex = startIndex
        self.onDismiss = onDismiss
        _currentIndex  = State(initialValue: startIndex)
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.96).ignoresSafeArea()

            TabView(selection: $currentIndex) {
                ForEach(Array(images.enumerated()), id: \.offset) { idx, img in
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                        .tag(idx)
                        .padding()
                }
            }
            .tabViewStyle(.page)
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            // Close + counter
            VStack {
                HStack {
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
                Text("\(currentIndex + 1) / \(images.count)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.bottom, 40)
            }
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
    let isSelected: Bool; let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 11))
                Text(title).font(.system(size: 12, weight: isSelected ? .bold : .medium))
                if isSelected {
                    Image(systemName: "checkmark").font(.system(size: 9, weight: .bold))
                }
            }
            .foregroundColor(isSelected ? .white : color)
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(isSelected ? color : color.opacity(0.14))
            .cornerRadius(18)
            .overlay(RoundedRectangle(cornerRadius: 18)
                .stroke(color.opacity(isSelected ? 0 : 0.4), lineWidth: 1))
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
                        .frame(width: 78, height: 78).clipped().cornerRadius(12)
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
                    Text(exercise.difficulty.rawValue)
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
