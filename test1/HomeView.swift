//
//  HomeView.swift
//  FlexCore
//
//  Home = greeting + quick stats + Progress dashboard content
//

import SwiftUI

struct HomeView: View {
    @EnvironmentObject var exerciseStore: ExerciseStore
    @EnvironmentObject var logStore:      WorkoutLogStore
    @ObservedObject private var muscleManager = MuscleGroupManager.shared

    var body: some View {
        ZStack {
            Color(hex: "111111").ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    headerBar.padding(.bottom, 20)
                    heroBanner.padding(.horizontal, 20)
                    quickStats.padding(.top, 20)
                    HomeProgressSection()
                        .padding(.top, 24)
                    Spacer(minLength: 100)
                }
            }
        }
    }

    // MARK: Header
    var headerBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Let's Train 💪").font(.system(size: 13)).foregroundColor(.orange)
                Text("FlexCore").font(.system(size: 26, weight: .bold)).foregroundColor(.white)
            }
            Spacer()
        }
        .padding(.horizontal, 20).padding(.top, 8)
    }

    // MARK: Hero
    var heroBanner: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Total Exercises").font(.system(size: 12)).foregroundColor(.gray)
                Text("\(exerciseStore.exercises.count)")
                    .font(.system(size: 34, weight: .black)).foregroundColor(.orange)
                Text("in your library").font(.system(size: 12)).foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(Color(hex: "1C1C1E")).cornerRadius(16)

            Spacer().frame(width: 12)

            VStack(alignment: .leading, spacing: 8) {
                Text("Workouts Logged").font(.system(size: 12)).foregroundColor(.gray)
                Text("\(logStore.sessions.count)")
                    .font(.system(size: 34, weight: .black)).foregroundColor(.white)
                Text("all time").font(.system(size: 12)).foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(Color(hex: "1C1C1E")).cornerRadius(16)
        }
    }

    // MARK: Quick stats
    var quickStats: some View {
        let cal = Calendar.current
        // Current calendar week (Mon–Sun or Sun–Sat per device locale)
        let weekStart = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date()))!
        let weekSessions = logStore.sessions.filter { $0.date >= weekStart }
        let weekCount  = weekSessions.count
        let weekVol    = Int(weekSessions.reduce(0) { $0 + $1.totalVolume })
        let streak     = calculateStreak()

        return HStack(spacing: 0) {
            QuickStat(icon: "calendar.badge.checkmark",
                      value: "\(weekCount)",
                      label: "This Week",
                      sublabel: weekCount == 0 ? "No sessions yet" : "\(weekCount) session\(weekCount == 1 ? "" : "s")",
                      color: .orange)
            Divider().background(Color.white.opacity(0.08)).frame(height: 40)
            QuickStat(icon: "scalemass.fill",
                      value: weekVol == 0 ? "—" : "\(weekVol) kg",
                      label: "Week Volume",
                      sublabel: weekVol == 0 ? "Log a workout" : "this week",
                      color: .blue)
            Divider().background(Color.white.opacity(0.08)).frame(height: 40)
            QuickStat(icon: "flame.fill",
                      value: streak == 0 ? "—" : "\(streak)d",
                      label: "Streak",
                      sublabel: streak == 0 ? "Train today!" : "consecutive days",
                      color: streak == 0 ? .gray : .red)
        }
        .padding(.vertical, 14)
        .background(Color(hex: "1C1C1E")).cornerRadius(14)
        .padding(.horizontal, 20)
    }

    func calculateStreak() -> Int {
        let cal = Calendar.current
        var streak = 0
        var checkDate = cal.startOfDay(for: Date())
        let sessionDays = Set(logStore.sessions.map { cal.startOfDay(for: $0.date) })
        // Allow today or yesterday as streak start
        if !sessionDays.contains(checkDate) {
            let yesterday = cal.date(byAdding: .day, value: -1, to: checkDate)!
            if sessionDays.contains(yesterday) {
                checkDate = yesterday
            } else {
                return 0
            }
        }
        while sessionDays.contains(checkDate) {
            streak += 1
            checkDate = cal.date(byAdding: .day, value: -1, to: checkDate)!
        }
        return streak
    }
}

struct QuickStat: View {
    let icon: String; let value: String; let label: String
    var sublabel: String = ""
    let color: Color
    var body: some View {
        VStack(spacing: 3) {
            Image(systemName: icon).font(.system(size: 13)).foregroundColor(color)
            Text(value).font(.system(size: 15, weight: .bold)).foregroundColor(.white)
            Text(label).font(.system(size: 9, weight: .medium)).foregroundColor(.gray)
        }.frame(maxWidth: .infinity)
    }
}

// MARK: - Home Progress Section (mirrors ProgressDashboardView content, no header)
struct HomeProgressSection: View {
    @EnvironmentObject var logStore:      WorkoutLogStore
    @EnvironmentObject var exerciseStore: ExerciseStore
    @ObservedObject private var muscleManager = MuscleGroupManager.shared

    @State private var range:           DateRange  = .month
    @State private var style:           HomeChartStyle = .bar
    @State private var selectedMuscle:  MuscleGroup? = nil
    @State private var selectedExercise: Exercise?   = nil

    enum HomeChartStyle: String, CaseIterable {
        case bar  = "Bar"
        case line = "Line"
    }

    var body: some View {
        VStack(spacing: 0) {
            sectionHeader.padding(.horizontal, 20)
            rangeBar.padding(.top, 10).padding(.horizontal, 20)
            muscleFilter.padding(.top, 8)
            exerciseFilter.padding(.top, 6)
            chartCard.padding(.top, 12).padding(.horizontal, 20)
            insightRow.padding(.top, 16).padding(.horizontal, 20)
            muscleBreakdown.padding(.top, 16).padding(.horizontal, 20)
        }
    }

    // MARK: Muscle group filter chips
    var muscleFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(title: "All", isSelected: selectedMuscle == nil) {
                    selectedMuscle = nil
                    selectedExercise = nil
                }
                ForEach(muscleManager.groups) { g in
                    FilterChipColored(
                        title: g.rawValue,
                        icon: g.icon,
                        color: g.color,
                        isSelected: selectedMuscle?.id == g.id
                    ) {
                        selectedMuscle = selectedMuscle?.id == g.id ? nil : g
                        selectedExercise = nil
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: Exercise filter chips
    var exerciseFilter: some View {
        let pool: [Exercise] = {
            if let m = selectedMuscle {
                return exerciseStore.exercises.filter { $0.muscleGroups.contains(where: { $0.id == m.id }) }
            }
            return exerciseStore.exercises
        }()

        return Group {
            if !pool.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        FilterChip(title: "All Exercises", isSelected: selectedExercise == nil) {
                            selectedExercise = nil
                        }
                        ForEach(pool) { ex in
                            FilterChip(title: ex.name, isSelected: selectedExercise?.id == ex.id) {
                                selectedExercise = selectedExercise?.id == ex.id ? nil : ex
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
    }

    var sectionHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Your Progress").font(.system(size: 20, weight: .bold)).foregroundColor(.white)
                Text("Volume & muscle breakdown").font(.system(size: 12)).foregroundColor(.gray)
            }
            Spacer()
            HStack(spacing: 0) {
                ForEach(HomeChartStyle.allCases, id: \.self) { s in
                    Button(action: { style = s }) {
                        Image(systemName: s == .bar ? "chart.bar.fill" : "chart.line.uptrend.xyaxis")
                            .font(.system(size: 13))
                            .foregroundColor(style == s ? .black : .gray)
                            .frame(width: 32, height: 28)
                            .background(style == s ? Color.orange : Color.clear)
                            .cornerRadius(7)
                    }
                }
            }
            .padding(3).background(Color(hex: "2C2C2C")).cornerRadius(10)
        }
    }

    var rangeBar: some View {
        HStack(spacing: 0) {
            ForEach(DateRange.allCases, id: \.self) { r in
                Button(action: { range = r }) {
                    Text(r.rawValue)
                        .font(.system(size: 12, weight: range == r ? .bold : .regular))
                        .foregroundColor(range == r ? .black : .gray)
                        .frame(maxWidth: .infinity).padding(.vertical, 8)
                        .background(range == r ? Color.orange : Color.clear)
                        .cornerRadius(9)
                }
            }
        }
        .padding(3).background(Color(hex: "1C1C1E")).cornerRadius(12)
    }

    var chartCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            let chartTitle: String = {
                if let ex = selectedExercise { return "\(ex.name) Volume" }
                if let m  = selectedMuscle   { return "\(MuscleGroupManager.shared.liveName(for: m)) Volume" }
                return "Total Volume"
            }()
            Text(chartTitle)
                .font(.system(size: 15, weight: .bold)).foregroundColor(.white)
            let data: [(date: Date, volume: Double)] = {
                if let ex = selectedExercise {
                    return logStore.dailyVolumesForExercise(id: ex.id, in: range)
                }
                return logStore.dailyVolumes(in: range, muscle: selectedMuscle)
            }()
            if data.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.system(size: 36)).foregroundColor(.gray.opacity(0.3))
                    Text("Log workouts to see your volume chart")
                        .font(.system(size: 12)).foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity).frame(height: 120)
                .background(Color(hex: "1C1C1E")).cornerRadius(14)
            } else {
                HomeVolumeChart(data: data, isBar: style == .bar)
            }
        }
    }

    var insightRow: some View {
        let mgr       = MuscleGroupManager.shared
        let most      = logStore.overtrainedMuscles(in: range, topN: 1).first.map { mgr.liveName(for: $0) } ?? "—"
        let neglected = logStore.neglectedMuscles(in: range, topN: 1).first.map { mgr.liveName(for: $0) } ?? "—"
        return HStack(spacing: 10) {
            MiniInsight(icon: "flame.fill",                    color: .orange, title: "Most Trained",  value: most)
            MiniInsight(icon: "exclamationmark.triangle.fill", color: .red,    title: "Needs Work",    value: neglected)
        }
    }

    var muscleBreakdown: some View {
        let allStats = logStore.muscleGroupStats(in: range)
        let stats    = selectedMuscle == nil ? allStats : allStats.filter { $0.muscleGroup == selectedMuscle! }
        let maxVol = stats.map(\.totalVolume).max() ?? 1

        return VStack(alignment: .leading, spacing: 10) {
            Text("Muscle Breakdown").font(.system(size: 15, weight: .bold)).foregroundColor(.white)
            if stats.isEmpty {
                Text("No data yet — log a workout first")
                    .font(.system(size: 12)).foregroundColor(.gray)
                    .padding(.vertical, 10)
            } else {
                ForEach(stats.prefix(6), id: \.muscleGroup) { stat in
                    HomeBarRow(stat: stat, maxVolume: maxVol)
                }
            }
        }
        .padding(14).background(Color(hex: "1C1C1E")).cornerRadius(14)
    }
}

// MARK: - Mini chart for Home
struct HomeVolumeChart: View {
    let data: [(date: Date, volume: Double)]
    let isBar: Bool

    var body: some View {
        let maxVol = data.map(\.volume).max() ?? 1
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                Color(hex: "1C1C1E")
                if isBar {
                    // Bar chart
                    let barW = max(4, (w - 20) / CGFloat(data.count) - 2)
                    HStack(alignment: .bottom, spacing: 2) {
                        ForEach(Array(data.enumerated()), id: \.offset) { _, pt in
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.orange.opacity(0.75))
                                .frame(width: barW, height: max(4, h * CGFloat(pt.volume / maxVol) - 10))
                        }
                    }
                    .padding(.horizontal, 10).padding(.bottom, 10)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                } else {
                    // Line chart
                    Path { path in
                        for (i, pt) in data.enumerated() {
                            let x = 10 + CGFloat(i) / CGFloat(max(data.count - 1, 1)) * (w - 20)
                            let y = (h - 16) * (1 - CGFloat(pt.volume / maxVol)) + 8
                            if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                            else      { path.addLine(to: CGPoint(x: x, y: y)) }
                        }
                    }
                    .stroke(Color.orange, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                }
            }
            .cornerRadius(14)
        }
        .frame(height: 130)
    }
}

struct MiniInsight: View {
    let icon: String; let color: Color; let title: String; let value: String
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 14)).foregroundColor(color)
                .frame(width: 32, height: 32).background(color.opacity(0.14)).cornerRadius(8)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 10)).foregroundColor(.gray)
                Text(value).font(.system(size: 13, weight: .bold)).foregroundColor(.white).lineLimit(1)
            }
            Spacer()
        }
        .padding(10).background(Color(hex: "1C1C1E")).cornerRadius(12)
        .frame(maxWidth: .infinity)
    }
}

struct HomeBarRow: View {
    let stat: MuscleGroupStat; let maxVolume: Double
    var body: some View {
        let liveG = MuscleGroupManager.shared.liveGroup(for: stat.muscleGroup.id) ?? stat.muscleGroup
        HStack(spacing: 10) {
            Image(systemName: liveG.icon)
                .font(.system(size: 11)).foregroundColor(liveG.color)
                .frame(width: 26, height: 26)
                .background(liveG.color.opacity(0.14)).cornerRadius(7)
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(liveG.rawValue)
                        .font(.system(size: 12, weight: .medium)).foregroundColor(.white)
                    Spacer()
                    Text("\(Int(stat.totalVolume)) kg")
                        .font(.system(size: 11)).foregroundColor(.gray)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.07)).frame(height: 5)
                        Capsule().fill(liveG.color)
                            .frame(width: geo.size.width * CGFloat(stat.totalVolume / maxVolume), height: 5)
                    }
                }.frame(height: 5)
            }
        }
    }
}
