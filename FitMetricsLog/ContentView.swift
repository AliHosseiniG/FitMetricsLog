//
//  ContentView.swift
//  FlexCore
//

import SwiftUI
import UIKit
import PhotosUI
import Combine
import UniformTypeIdentifiers

// MARK: - User Profile Store
class UserProfileStore: ObservableObject {
    static let shared = UserProfileStore()
    @Published var userName:  String = "Athlete"
    @Published var avatarData: Data? = nil

    private let nameKey   = "userProfile_name_v1"
    private let avatarKey = "userProfile_avatar_v1"

    init() { load() }

    func save() {
        UserDefaults.standard.set(userName, forKey: nameKey)
        if let d = avatarData { UserDefaults.standard.set(d, forKey: avatarKey) }
        else { UserDefaults.standard.removeObject(forKey: avatarKey) }
    }
    private func load() {
        userName   = UserDefaults.standard.string(forKey: nameKey) ?? "Athlete"
        avatarData = UserDefaults.standard.data(forKey: avatarKey)
    }
    var avatar: UIImage? { avatarData.flatMap { UIImage(data: $0) } }
}


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
            // One-time resize of large stored images (safe — no data deleted)
            DispatchQueue.global(qos: .background).async {
                logStore.resizeStoredImages(maxDimension: 600)
                exerciseStore.resizeStoredImages(maxDimension: 900)
            }
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
                VStack(spacing: 8) {
                    Image(systemName: "dumbbell.fill").font(.system(size: 56)).foregroundColor(.orange)
                    Text("FML")
                        .font(.system(size: 72, weight: .black, design: .rounded))
                        .foregroundColor(.white).tracking(8)
                    Text("FitMetricsLog")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.5)).tracking(4)
                }
                Spacer()
                VStack(alignment: .leading, spacing: 14) {
                    Text("Unleash Your Potential\nwith FitMetricsLog")
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
                    Label(L(.tabHome), systemImage: "house.fill")
                }

            ExerciseListView()
                .tabItem {
                    Label(L(.tabExercises), systemImage: "list.bullet")
                }

            LogView()
                .tabItem {
                    Label(L(.tabLog), systemImage: "plus.circle.fill")
                }

            WorkoutPlanListView()
                .tabItem {
                    Label(L(.tabPrograms), systemImage: "list.bullet.clipboard")
                }

            ProgressDashboardView()
                .tabItem {
                    Label(L(.myProgress), systemImage: "chart.bar.fill")
                }

            ProfileView()
                .tabItem {
                    Label(L(.profile), systemImage: "person.fill")
                }
        }
        .accentColor(.orange)
    }
}

// MARK: - Profile View
struct ProfileView: View {
    @EnvironmentObject var exerciseStore:  ExerciseStore
    @EnvironmentObject var logStore:       WorkoutLogStore
    @EnvironmentObject var planStore:      WorkoutPlanStore
    @StateObject private var userProfile = UserProfileStore.shared
    @ObservedObject private var loc = LocalizationManager.shared

    @State private var search               = ""
    @State private var showingMuscleEditor  = false
    @State private var showingAbout         = false
    @State private var showingImportExport  = false
    @State private var showingEditProfile   = false
    @State private var showingClearAll      = false
    @State private var showingLanguage      = false
    @FocusState private var searchFocused:  Bool

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
                        Text(L(.profile)).font(.system(size: 26, weight: .bold)).foregroundColor(.white)
                        Spacer()
                        Button(action: { showingMuscleEditor = true }) {
                            HStack(spacing: 5) {
                                Image(systemName: "figure.strengthtraining.functional").font(.system(size: 13))
                                Text(L(.muscleGroupsTitle)).font(.system(size: 12, weight: .medium))
                            }
                            .foregroundColor(.orange)
                            .padding(.horizontal, 12).padding(.vertical, 7)
                            .background(Color.orange.opacity(0.12)).cornerRadius(10)
                        }
                    }
                    .padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 12)

                    HStack {
                        Image(systemName: "magnifyingglass").foregroundColor(.gray)
                        TextField(L(.tabExercises) + "...", text: $search)
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
                            profileContent
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
            .navigationBarBackButtonHidden(true)
            .sheet(isPresented: $showingMuscleEditor) { MuscleGroupEditorView() }
            .sheet(isPresented: $showingAbout)         { AboutView() }
            .sheet(isPresented: $showingEditProfile)   { EditProfileView() }
            .sheet(isPresented: $showingImportExport) {
                ImportExportView()
                    .environmentObject(exerciseStore)
                    .environmentObject(planStore)
                    .environmentObject(logStore)
            }
            .sheet(isPresented: $showingLanguage) { LanguageSettingsView() }
            .alert(L(.clearAllQ), isPresented: $showingClearAll) {
                Button(L(.clearEverything), role: .destructive) { clearAllData() }
                Button(L(.cancel), role: .cancel) {}
            } message: {
                Text(L(.clearAllMsg))
            }
        }
    }

    func clearAllData() {
        exerciseStore.clearAll()
        logStore.clearAll()
        planStore.clearAll()
        UserProfileStore.shared.userName  = "Athlete"
        UserProfileStore.shared.avatarData = nil
        UserProfileStore.shared.save()
        // Clear max reps storage
        UserDefaults.standard.removeObject(forKey: "exercise_max_reps_v1")
        // Clear muscle group customizations
        UserDefaults.standard.removeObject(forKey: "hiddenBuiltIns_v1")
        MuscleGroupManager.shared.clearCustomizations()
    }

    var profileContent: some View {
        VStack(spacing: 20) {
            // ── Avatar + Name Card ──
            ZStack(alignment: .bottomTrailing) {
                VStack(spacing: 0) {
                    // Cover gradient
                    LinearGradient(colors: [Color.orange.opacity(0.35), Color(hex: "111111")],
                                   startPoint: .top, endPoint: .bottom)
                        .frame(height: 100).roundedCorners(16, corners: [.topLeft, .topRight])

                    VStack(spacing: 8) {
                        Spacer().frame(height: 44)   // space for avatar overlap
                        Text(userProfile.userName)
                            .font(.system(size: 22, weight: .bold)).foregroundColor(.white)
                        Text(L(.fitmetricslogMember))
                            .font(.system(size: 13)).foregroundColor(.gray)
                        Spacer().frame(height: 16)

                        // Stats row
                        HStack(spacing: 0) {
                            ProfStat(value: "\(exerciseStore.exercises.count)", label: L(.tabExercises))
                            Divider().background(Color.white.opacity(0.12)).frame(height: 36)
                            ProfStat(value: "\(logStore.sessions.count)",       label: L(.sessionCount))
                            Divider().background(Color.white.opacity(0.12)).frame(height: 36)
                            ProfStat(value: "\(Int(logStore.totalVolume(in: .all)))", label: L(.kgLifted))
                        }
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.05)).cornerRadius(12)
                        .padding(.horizontal, 16).padding(.bottom, 16)
                    }
                    .background(Color(hex: "1C1C1E"))
                    .roundedCorners(16, corners: [.bottomLeft, .bottomRight])
                }
                .background(Color(hex: "1C1C1E")).cornerRadius(16)
            }
            .overlay(
                // Avatar overlapping cover / content
                Button(action: { showingEditProfile = true }) {
                    ZStack {
                        Circle().fill(Color(hex: "1C1C1E")).frame(width: 88, height: 88)
                        if let img = userProfile.avatar {
                            Image(uiImage: img).resizable().scaledToFill()
                                .frame(width: 80, height: 80).clipped().clipShape(Circle())
                        } else {
                            Circle().fill(Color.orange.opacity(0.22)).frame(width: 80, height: 80)
                            Image(systemName: "person.fill")
                                .font(.system(size: 34)).foregroundColor(.orange)
                        }
                        // Edit badge
                        Circle().fill(Color.orange).frame(width: 26, height: 26)
                            .overlay(Image(systemName: "pencil").font(.system(size: 11, weight: .bold)).foregroundColor(.white))
                            .offset(x: 28, y: 28)
                    }
                },
                alignment: .top
            )
            .padding(.top, 44)
            .padding(.horizontal, 20)

            // ── Settings ──
            VStack(spacing: 0) {
                SettingsRow(icon: "person.crop.circle", label: L(.editProfile)) {
                    showingEditProfile = true
                }
                Divider().background(Color.white.opacity(0.08)).padding(.leading, 58)
                SettingsRow(icon: "figure.strengthtraining.functional", label: L(.manageMuscleoGroups)) {
                    showingMuscleEditor = true
                }
                Divider().background(Color.white.opacity(0.08)).padding(.leading, 58)
                SettingsRow(icon: "square.and.arrow.up.on.square", label: L(.importExport)) {
                    showingImportExport = true
                }
                Divider().background(Color.white.opacity(0.08)).padding(.leading, 58)
                SettingsRow(icon: "info.circle.fill", label: L(.aboutApp)) {
                    showingAbout = true
                }
                Divider().background(Color.white.opacity(0.08)).padding(.leading, 58)
                SettingsRow(icon: "globe", label: L(.appLanguage)) {
                    showingLanguage = true
                }
                Divider().background(Color.white.opacity(0.08)).padding(.leading, 58)
                Button(action: { showingClearAll = true }) {
                    HStack(spacing: 14) {
                        Image(systemName: "trash.fill").font(.system(size: 15)).foregroundColor(.red)
                            .frame(width: 32, height: 32).background(Color.red.opacity(0.14)).cornerRadius(8)
                        Text(L(.clearAllData)).font(.system(size: 14)).foregroundColor(.red)
                        Spacer()
                        Image(systemName: "chevron.right").font(.system(size: 12)).foregroundColor(.gray)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 13)
                }
            }
            .background(Color(hex: "1C1C1E")).cornerRadius(14)
            .padding(.horizontal, 20)

            Spacer(minLength: 100)
        }
    }
}

// MARK: - Edit Profile Sheet
struct EditProfileView: View {
    @ObservedObject private var userProfile = UserProfileStore.shared
    @Environment(\.dismiss) var dismiss

    @State private var draftName:  String = ""
    @State private var draftImage: UIImage? = nil
    @State private var showPicker  = false
    @State private var showCamera  = false
    @State private var showOptions = false
    @FocusState private var focused: Bool

    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "111111").ignoresSafeArea()
                    .onTapGesture { focused = false }
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 28) {

                        // Avatar picker
                        VStack(spacing: 14) {
                            Button(action: { showOptions = true }) {
                                ZStack(alignment: .bottomTrailing) {
                                    if let img = draftImage {
                                        Image(uiImage: img).resizable().scaledToFill()
                                            .frame(width: 110, height: 110).clipped().clipShape(Circle())
                                            .overlay(Circle().stroke(Color.orange, lineWidth: 3))
                                    } else {
                                        Circle().fill(Color.orange.opacity(0.18)).frame(width: 110, height: 110)
                                            .overlay(Image(systemName: "person.fill")
                                                .font(.system(size: 46)).foregroundColor(.orange))
                                    }
                                    // Camera badge
                                    Circle().fill(Color.orange).frame(width: 32, height: 32)
                                        .overlay(Image(systemName: "camera.fill")
                                            .font(.system(size: 13)).foregroundColor(.white))
                                        .offset(x: 4, y: 4)
                                }
                            }
                            Text(L(.tapToChangePhoto))
                                .font(.system(size: 12)).foregroundColor(.gray)
                        }
                        .padding(.top, 20)

                        // Name field
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L(.displayName)).font(.system(size: 13)).foregroundColor(.gray)
                            HStack {
                                Image(systemName: "person.fill").foregroundColor(.orange).frame(width: 20)
                                TextField(L(.displayName) + "...", text: $draftName)
                                    .foregroundColor(.white).focused($focused)
                                if !draftName.isEmpty {
                                    Button(action: { draftName = "" }) {
                                        Image(systemName: "xmark.circle.fill").foregroundColor(.gray)
                                    }
                                }
                            }
                            .padding(14).background(Color(hex: "1C1C1E")).cornerRadius(12)
                        }
                        .padding(.horizontal, 20)

                        // Remove photo button
                        if draftImage != nil {
                            Button(action: { draftImage = nil }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "trash").foregroundColor(.red)
                                    Text(L(.removePhoto)).foregroundColor(.red)
                                }
                                .font(.system(size: 14))
                                .frame(maxWidth: .infinity).frame(height: 46)
                                .background(Color.red.opacity(0.08)).cornerRadius(12)
                                .padding(.horizontal, 20)
                            }
                        }

                        Spacer(minLength: 60)
                    }
                }
            }
            .navigationTitle(L(.editProfile))
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button(L(.cancel)) { dismiss() }.foregroundColor(.orange),
                trailing: Button(L(.save)) { saveProfile() }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(draftName.trimmingCharacters(in: .whitespaces).isEmpty ? .gray : .orange)
                    .disabled(draftName.trimmingCharacters(in: .whitespaces).isEmpty)
            )
            .confirmationDialog("Change Photo", isPresented: $showOptions) {
                Button(L(.chooseFromLibrary)) { showPicker = true }
                Button(L(.takePhoto)) { showCamera = true }
                if draftImage != nil {
                    Button(L(.removePhoto), role: .destructive) { draftImage = nil }
                }
                Button("Cancel", role: .cancel) {}
            }
            .sheet(isPresented: $showPicker) {
                ProfilePhotoPicker { img in if let img { draftImage = img } }
            }
            .sheet(isPresented: $showCamera) {
                CameraWrapper { img in if let img { draftImage = img } }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            draftName  = userProfile.userName
            draftImage = userProfile.avatar
        }
    }

    func saveProfile() {
        userProfile.userName  = draftName.trimmingCharacters(in: .whitespaces)
        userProfile.avatarData = draftImage?.jpegData(compressionQuality: 0.75)
        userProfile.save()
        dismiss()
    }
}

// MARK: - Profile Photo Picker
struct ProfilePhotoPicker: UIViewControllerRepresentable {
    let onSelect: (UIImage?) -> Void
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images; config.selectionLimit = 1
        let vc = PHPickerViewController(configuration: config)
        vc.delegate = context.coordinator; return vc
    }
    func updateUIViewController(_ vc: PHPickerViewController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(onSelect: onSelect) }
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onSelect: (UIImage?) -> Void
        init(onSelect: @escaping (UIImage?) -> Void) { self.onSelect = onSelect }
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard let provider = results.first?.itemProvider,
                  provider.canLoadObject(ofClass: UIImage.self) else { onSelect(nil); return }
            provider.loadObject(ofClass: UIImage.self) { obj, _ in
                DispatchQueue.main.async { self.onSelect(obj as? UIImage) }
            }
        }
    }
}

// MARK: - Corner radius helper
extension View {
    func roundedCorners(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}
struct RoundedCorner: Shape {
    var radius: CGFloat; var corners: UIRectCorner
    func path(in rect: CGRect) -> Path {
        Path(UIBezierPath(roundedRect: rect, byRoundingCorners: corners,
                          cornerRadii: CGSize(width: radius, height: radius)).cgPath)
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


// MARK: - Language Settings View
struct LanguageSettingsView: View {
    @ObservedObject private var loc = LocalizationManager.shared
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "111111").ignoresSafeArea()
                VStack(spacing: 20) {
                    VStack(spacing: 0) {
                        ForEach(AppLanguage.allCases, id: \.rawValue) { lang in
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    loc.language = lang
                                }
                            }) {
                                HStack(spacing: 16) {
                                    Text(lang.flag).font(.system(size: 28))
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(lang.displayName)
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(.white)
                                    }
                                    Spacer()
                                    if loc.language == lang {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 22)).foregroundColor(.orange)
                                    } else {
                                        Image(systemName: "circle")
                                            .font(.system(size: 22)).foregroundColor(.gray.opacity(0.4))
                                    }
                                }
                                .padding(.horizontal, 20).padding(.vertical, 16)
                                .background(loc.language == lang
                                            ? Color.orange.opacity(0.08) : Color.clear)
                            }
                            if lang != AppLanguage.allCases.last {
                                Divider().background(Color.white.opacity(0.08)).padding(.leading, 68)
                            }
                        }
                    }
                    .background(Color(hex: "1C1C1E")).cornerRadius(14)
                    .padding(.horizontal, 20)

                    Text(loc.language == .german
                         ? "Die Sprache wird sofort übernommen."
                         : "Language changes take effect immediately.")
                        .font(.system(size: 13)).foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)

                    Spacer()
                }
                .padding(.top, 24)
            }
            .navigationTitle(L(.appLanguage))
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing:
                Button(L(.done)) { dismiss() }.foregroundColor(.orange)
            )
        }
        .preferredColorScheme(.dark)
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

                            Text("FitMetricsLog")
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
                            Text("FitMetricsLog is your personal workout companion. Log exercises, track progress, build custom programs, and analyze your performance over time.")
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
    @EnvironmentObject var logStore:      WorkoutLogStore
    @Environment(\.dismiss) var dismiss

    @State private var showShareExercises = false
    @State private var showSharePlans     = false
    @State private var shareItem: Any?    = nil
    @State private var showFilePicker     = false
    @State private var importMessage      = ""
    @State private var showImportAlert    = false
    @State private var isExporting        = false
    @State private var showLogExport      = false

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

                            exportCard(
                                icon: "chart.bar.doc.horizontal.fill", color: Color(hex: "FF6B00"),
                                title: "Export Workout Logs",
                                subtitle: "\(logStore.sessions.count) sessions · CSV or PDF"
                            ) { showLogExport = true }
                        }

                        // Import section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("IMPORT")
                                .font(.system(size: 12, weight: .semibold)).foregroundColor(.gray)
                                .padding(.leading, 4)

                            Text("Import previously exported FitMetricsLog JSON files to restore exercises and programs.")
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
            .sheet(isPresented: $showLogExport) {
                ExportView().environmentObject(logStore)
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
    struct FitMetricsBundle: Codable {
        var version:   Int             = 1
        var exercises: [Exercise]?
        var plans:     [WorkoutPlan]?
    }

    func exportExercises() {
        let bundle = FitMetricsBundle(exercises: exerciseStore.exercises)
        share(bundle, filename: "FitMetricsLog_Exercises")
    }

    func exportPlans() {
        let bundle = FitMetricsBundle(plans: planStore.plans)
        share(bundle, filename: "FitMetricsLog_Programs")
    }

    func exportAll() {
        let bundle = FitMetricsBundle(exercises: exerciseStore.exercises, plans: planStore.plans)
        share(bundle, filename: "FitMetricsLog_AllData")
    }

    func share(_ bundle: FitMetricsBundle, filename: String) {
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
              let bundle = try? JSONDecoder().decode(FitMetricsBundle.self, from: data)
        else {
            importMessage = "Invalid file. Please select a valid FitMetricsLog JSON file."
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
