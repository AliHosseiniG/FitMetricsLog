//
//  ContentView.swift
//  FlexCore
//

import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var exerciseStore = ExerciseStore()
    @StateObject private var logStore      = WorkoutLogStore()
    @StateObject private var planStore     = WorkoutPlanStore()
    @State private var showingSplash = true

    var body: some View {
        ZStack {
            if showingSplash {
                SplashView(showingSplash: $showingSplash).transition(.opacity)
            } else {
                MainTabView()
                    .environmentObject(exerciseStore)
                    .environmentObject(logStore)
                    .environmentObject(planStore)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.45), value: showingSplash)
        .onAppear {
            // Wire stores for cross-sync
            planStore.logStore = logStore
        }
    }
}

// MARK: - Splash
struct SplashView: View {
    @Binding var showingSplash: Bool
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            LinearGradient(colors: [.black, Color(hex: "1A1A1A"), .black],
                           startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
            VStack(spacing: 0) {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "dumbbell.fill").font(.system(size: 60)).foregroundColor(.orange)
                    Text("FLEXCORE")
                        .font(.system(size: 38, weight: .black, design: .rounded))
                        .foregroundColor(.white).tracking(6)
                }
                Spacer()
                VStack(alignment: .leading, spacing: 14) {
                    Text("Unleash Your Potential\nwith Flexcore")
                        .font(.system(size: 32, weight: .bold)).foregroundColor(.white).lineSpacing(4)
                    Text("Log workouts · Track progress · See your gains")
                        .font(.system(size: 15)).foregroundColor(.white.opacity(0.6))
                }
                .padding(.horizontal, 30).padding(.bottom, 40)
                Button(action: { withAnimation { showingSplash = false } }) {
                    HStack {
                        Text("Get Started").font(.system(size: 17, weight: .semibold))
                        Text("🔥")
                    }
                    .foregroundColor(.black).frame(maxWidth: .infinity).frame(height: 56)
                    .background(Color.white).cornerRadius(28)
                }
                .padding(.horizontal, 30).padding(.bottom, 50)
            }
        }
    }
}

// MARK: - Main Tab View — native iOS TabBar
struct MainTabView: View {
    @EnvironmentObject var exerciseStore: ExerciseStore
    @EnvironmentObject var logStore:      WorkoutLogStore
    @EnvironmentObject var planStore:     WorkoutPlanStore

    init() {
        // Style native tab bar
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(red: 0.11, green: 0.11, blue: 0.11, alpha: 1)
        appearance.stackedLayoutAppearance.selected.iconColor   = UIColor.orange
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor.orange]
        appearance.stackedLayoutAppearance.normal.iconColor     = UIColor.gray
        appearance.stackedLayoutAppearance.normal.titleTextAttributes   = [.foregroundColor: UIColor.gray]
        UITabBar.appearance().standardAppearance   = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }

            ExerciseListView()
                .tabItem {
                    Label("Exercises", systemImage: "list.bullet")
                }

            LogView()
                .tabItem {
                    Label("Log", systemImage: "plus.circle.fill")
                }

            WorkoutPlanListView()
                .tabItem {
                    Label("Programs", systemImage: "list.bullet.clipboard")
                }

            ProgressDashboardView()
                .tabItem {
                    Label("Progress", systemImage: "chart.bar.fill")
                }

            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
        }
        .accentColor(.orange)
    }
}

// MARK: - Profile View
struct ProfileView: View {
    @EnvironmentObject var exerciseStore: ExerciseStore
    @EnvironmentObject var logStore:      WorkoutLogStore
    @EnvironmentObject var planStore:     WorkoutPlanStore
    @State private var search              = ""
    @State private var showingMuscleEditor  = false
    @State private var showingAbout         = false
    @State private var showingImportExport  = false
    @FocusState private var searchFocused: Bool

    var results: [Exercise] {
        guard !search.isEmpty else { return [] }
        return exerciseStore.exercises.filter {
            $0.name.localizedCaseInsensitiveContains(search) ||
            $0.muscleGroup.rawValue.localizedCaseInsensitiveContains(search)
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "111111").ignoresSafeArea()
                    .onTapGesture { searchFocused = false }
                VStack(spacing: 0) {
                    HStack {
                        Text("Profile").font(.system(size: 26, weight: .bold)).foregroundColor(.white)
                        Spacer()
                        Button(action: { showingMuscleEditor = true }) {
                            HStack(spacing: 5) {
                                Image(systemName: "figure.strengthtraining.functional").font(.system(size: 13))
                                Text("Muscles").font(.system(size: 12, weight: .medium))
                            }
                            .foregroundColor(.orange)
                            .padding(.horizontal, 12).padding(.vertical, 7)
                            .background(Color.orange.opacity(0.12)).cornerRadius(10)
                        }
                    }
                    .padding(.horizontal, 20).padding(.top, 60).padding(.bottom, 12)

                    HStack {
                        Image(systemName: "magnifyingglass").foregroundColor(.gray)
                        TextField("Search exercises...", text: $search)
                            .foregroundColor(.white).focused($searchFocused)
                        if !search.isEmpty {
                            Button(action: { search = "" }) {
                                Image(systemName: "xmark.circle.fill").foregroundColor(.gray)
                            }
                        }
                    }
                    .padding(12).background(Color(hex: "2C2C2C")).cornerRadius(12)
                    .padding(.horizontal, 20).padding(.bottom, 14)

                    ScrollView(showsIndicators: false) {
                        if search.isEmpty {
                            profileStats
                        } else if results.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 40)).foregroundColor(.gray.opacity(0.4))
                                Text("No results").foregroundColor(.gray)
                            }.padding(.top, 60)
                        } else {
                            LazyVStack(spacing: 10) {
                                ForEach(results) { ex in
                                    NavigationLink(destination: ExerciseDetailView(exercise: ex)) {
                                        ExerciseRowCard(exercise: ex)
                                    }.padding(.horizontal, 20)
                                }
                            }.padding(.bottom, 100)
                        }
                    }
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showingMuscleEditor) { MuscleGroupEditorView() }
            .sheet(isPresented: $showingAbout) { AboutView() }
            .sheet(isPresented: $showingImportExport) {
                ImportExportView()
                    .environmentObject(exerciseStore)
                    .environmentObject(planStore)
            }
        }
    }

    var profileStats: some View {
        VStack(spacing: 20) {
            VStack(spacing: 10) {
                ZStack {
                    Circle().fill(Color.orange.opacity(0.18)).frame(width: 80, height: 80)
                    Image(systemName: "person.fill").font(.system(size: 36)).foregroundColor(.orange)
                }
                Text("Athlete").font(.system(size: 20, weight: .bold)).foregroundColor(.white)
                Text("FlexCore Member").font(.system(size: 13)).foregroundColor(.gray)
            }
            HStack(spacing: 0) {
                ProfStat(value: "\(exerciseStore.exercises.count)",      label: "Exercises")
                Divider().background(Color.white.opacity(0.1)).frame(height: 36)
                ProfStat(value: "\(logStore.sessions.count)",            label: "Sessions")
                Divider().background(Color.white.opacity(0.1)).frame(height: 36)
                ProfStat(value: "\(Int(logStore.totalVolume(in: .all)))", label: "kg lifted")
            }
            .padding(.vertical, 14).background(Color(hex: "1C1C1E")).cornerRadius(14)
            .padding(.horizontal, 20)

            VStack(spacing: 0) {
                SettingsRow(icon: "figure.strengthtraining.functional", label: "Manage Muscle Groups") {
                    showingMuscleEditor = true
                }
                Divider().background(Color.white.opacity(0.08)).padding(.leading, 58)
                SettingsRow(icon: "square.and.arrow.up.on.square", label: "Import / Export Data") {
                    showingImportExport = true
                }
                Divider().background(Color.white.opacity(0.08)).padding(.leading, 58)
                SettingsRow(icon: "info.circle.fill", label: "About FlexCore") {
                    showingAbout = true
                }
            }
            .background(Color(hex: "1C1C1E")).cornerRadius(14)
            .padding(.horizontal, 20)

            Spacer(minLength: 100)
        }
    }
}

struct ProfStat: View {
    let value: String; let label: String
    var body: some View {
        VStack(spacing: 4) {
            Text(value).font(.system(size: 22, weight: .bold)).foregroundColor(.orange)
            Text(label).font(.system(size: 11)).foregroundColor(.gray)
        }.frame(maxWidth: .infinity)
    }
}

struct SettingsRow: View {
    let icon: String; let label: String; let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon).font(.system(size: 15)).foregroundColor(.orange)
                    .frame(width: 32, height: 32).background(Color.orange.opacity(0.14)).cornerRadius(8)
                Text(label).font(.system(size: 14)).foregroundColor(.white)
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 12)).foregroundColor(.gray)
            }
            .padding(.horizontal, 16).padding(.vertical, 13)
        }
    }
}

#Preview { ContentView() }

// MARK: - About View
struct AboutView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "111111").ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 30) {
                        // App icon + name
                        VStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(LinearGradient(colors: [Color.orange, Color.orange.opacity(0.6)],
                                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .frame(width: 100, height: 100)
                                Image(systemName: "dumbbell.fill")
                                    .font(.system(size: 44)).foregroundColor(.white)
                            }
                            .shadow(color: .orange.opacity(0.4), radius: 20)

                            Text("FlexCore")
                                .font(.system(size: 32, weight: .black, design: .rounded))
                                .foregroundColor(.white)
                            Text("Version 1.0.0")
                                .font(.system(size: 14)).foregroundColor(.gray)
                        }
                        .padding(.top, 20)

                        // Developer info
                        VStack(spacing: 0) {
                            InfoRow(icon: "person.fill",   label: "Developer",  value: "Ali Hosseini")
                            Divider().background(Color.white.opacity(0.08)).padding(.leading, 52)
                            InfoRow(icon: "envelope.fill", label: "Email",      value: "ali.hosseini.gh@gmail.com")
                            Divider().background(Color.white.opacity(0.08)).padding(.leading, 52)
                            InfoRow(icon: "globe",         label: "Website",    value: "www.ali.com")
                        }
                        .background(Color(hex: "1C1C1E")).cornerRadius(14)
                        .padding(.horizontal, 20)

                        // Description
                        VStack(alignment: .leading, spacing: 10) {
                            Text("About")
                                .font(.system(size: 13, weight: .semibold)).foregroundColor(.gray)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text("FlexCore is your personal workout companion. Log exercises, track progress, build custom programs, and analyze your performance over time.")
                                .font(.system(size: 14)).foregroundColor(.white).lineSpacing(5)
                        }
                        .padding(16).background(Color(hex: "1C1C1E")).cornerRadius(14)
                        .padding(.horizontal, 20)

                        Spacer(minLength: 60)
                    }
                }
            }
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Done") { dismiss() }.foregroundColor(.orange))
        }
        .preferredColorScheme(.dark)
    }
}

struct InfoRow: View {
    let icon: String; let label: String; let value: String
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon).font(.system(size: 14)).foregroundColor(.orange)
                .frame(width: 30, height: 30).background(Color.orange.opacity(0.14)).cornerRadius(8)
                .padding(.leading, 12)
            Text(label)
                .font(.system(size: 13)).foregroundColor(.gray)
                .frame(width: 76, alignment: .leading)
            Text(value)
                .font(.system(size: 14, weight: .medium)).foregroundColor(.white)
            Spacer()
        }
        .padding(.vertical, 14)
    }
}

// MARK: - Import / Export View
struct ImportExportView: View {
    @EnvironmentObject var exerciseStore: ExerciseStore
    @EnvironmentObject var planStore:     WorkoutPlanStore
    @Environment(\.dismiss) var dismiss

    @State private var showShareExercises = false
    @State private var showSharePlans     = false
    @State private var shareItem: Any?    = nil
    @State private var showFilePicker     = false
    @State private var importMessage      = ""
    @State private var showImportAlert    = false
    @State private var isExporting        = false

    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "111111").ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Export section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("EXPORT")
                                .font(.system(size: 12, weight: .semibold)).foregroundColor(.gray)
                                .padding(.leading, 4)

                            exportCard(
                                icon: "dumbbell.fill", color: .blue,
                                title: "Export Exercises",
                                subtitle: "\(exerciseStore.exercises.count) exercises"
                            ) { exportExercises() }

                            exportCard(
                                icon: "list.bullet.clipboard.fill", color: .orange,
                                title: "Export Programs",
                                subtitle: "\(planStore.plans.count) programs"
                            ) { exportPlans() }

                            exportCard(
                                icon: "square.and.arrow.up", color: .green,
                                title: "Export All Data",
                                subtitle: "Exercises + Programs"
                            ) { exportAll() }
                        }

                        // Import section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("IMPORT")
                                .font(.system(size: 12, weight: .semibold)).foregroundColor(.gray)
                                .padding(.leading, 4)

                            Text("Import previously exported FlexCore JSON files to restore exercises and programs.")
                                .font(.system(size: 12)).foregroundColor(.gray)
                                .padding(.horizontal, 4)

                            Button(action: { showFilePicker = true }) {
                                HStack(spacing: 12) {
                                    Image(systemName: "square.and.arrow.down.fill")
                                        .font(.system(size: 20)).foregroundColor(.white)
                                        .frame(width: 44, height: 44)
                                        .background(Color(hex: "5856D6")).cornerRadius(12)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text("Import from File")
                                            .font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
                                        Text("Select a .json file")
                                            .font(.system(size: 12)).foregroundColor(.gray)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right").foregroundColor(.gray)
                                }
                                .padding(16).background(Color(hex: "1C1C1E")).cornerRadius(14)
                            }
                        }

                        // Info box
                        HStack(spacing: 10) {
                            Image(systemName: "info.circle.fill").foregroundColor(.blue)
                            Text("Export creates a JSON file. Import merges the data — existing items won't be duplicated.")
                                .font(.system(size: 12)).foregroundColor(.gray)
                        }
                        .padding(14).background(Color(hex: "1C1C1E")).cornerRadius(12)

                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, 20).padding(.top, 10)
                }
            }
            .navigationTitle("Import / Export")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Done") { dismiss() }.foregroundColor(.orange))
            .sheet(isPresented: $showFilePicker) {
                DocumentPickerView { url in importFile(from: url) }
            }
            .sheet(isPresented: Binding(
                get: { shareItem != nil },
                set: { if !$0 { shareItem = nil } }
            )) {
                if let item = shareItem { ShareSheetView(items: [item]) }
            }
            .alert("Import Result", isPresented: $showImportAlert) {
                Button("OK") {}
            } message: { Text(importMessage) }
        }
        .preferredColorScheme(.dark)
    }

    func exportCard(icon: String, color: Color, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 20)).foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(color).cornerRadius(12)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
                    Text(subtitle).font(.system(size: 12)).foregroundColor(.gray)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundColor(.gray)
            }
            .padding(16).background(Color(hex: "1C1C1E")).cornerRadius(14)
        }
    }

    // MARK: Export helpers
    struct FlexCoreBundle: Codable {
        var version:   Int             = 1
        var exercises: [Exercise]?
        var plans:     [WorkoutPlan]?
    }

    func exportExercises() {
        let bundle = FlexCoreBundle(exercises: exerciseStore.exercises)
        share(bundle, filename: "FlexCore_Exercises")
    }

    func exportPlans() {
        let bundle = FlexCoreBundle(plans: planStore.plans)
        share(bundle, filename: "FlexCore_Programs")
    }

    func exportAll() {
        let bundle = FlexCoreBundle(exercises: exerciseStore.exercises, plans: planStore.plans)
        share(bundle, filename: "FlexCore_AllData")
    }

    func share(_ bundle: FlexCoreBundle, filename: String) {
        guard let data = try? JSONEncoder().encode(bundle) else { return }
        let df = DateFormatter(); df.dateFormat = "yyyyMMdd"
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(filename)_\(df.string(from: Date())).json")
        try? data.write(to: url)
        shareItem = url
    }

    // MARK: Import
    func importFile(from url: URL) {
        guard url.startAccessingSecurityScopedResource() else {
            importMessage = "Could not access the file."; showImportAlert = true; return
        }
        defer { url.stopAccessingSecurityScopedResource() }

        guard let data = try? Data(contentsOf: url),
              let bundle = try? JSONDecoder().decode(FlexCoreBundle.self, from: data)
        else {
            importMessage = "Invalid file. Please select a valid FlexCore JSON file."
            showImportAlert = true; return
        }

        var added = 0

        if let exs = bundle.exercises {
            let existing = Set(exerciseStore.exercises.map(\.id))
            for ex in exs where !existing.contains(ex.id) {
                exerciseStore.add(ex); added += 1
            }
        }

        if let plans = bundle.plans {
            let existing = Set(planStore.plans.map(\.id))
            for plan in plans where !existing.contains(plan.id) {
                planStore.add(plan); added += 1
            }
        }

        importMessage = added > 0
            ? "Successfully imported \(added) item\(added == 1 ? "" : "s")."
            : "No new items found — everything was already imported."
        showImportAlert = true
    }
}

// MARK: - Document Picker
struct DocumentPickerView: UIViewControllerRepresentable {
    var onPick: (URL) -> Void
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let vc = UIDocumentPickerViewController(forOpeningContentTypes: [.json])
        vc.delegate = context.coordinator
        return vc
    }
    func updateUIViewController(_ vc: UIDocumentPickerViewController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let p: DocumentPickerView; init(_ p: DocumentPickerView) { self.p = p }
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            if let url = urls.first { p.onPick(url) }
        }
    }
}
