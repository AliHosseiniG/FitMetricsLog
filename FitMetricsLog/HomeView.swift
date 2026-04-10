//
//  HomeView.swift
//  FlexCore
//
//  Home = greeting + quick stats + Progress dashboard content
//

import SwiftUI

struct HomeView: View {
    @ObservedObject private var loc = LocalizationManager.shared
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
                Text(L(.letsTrainEmoji)).font(.system(size: 13)).foregroundColor(.orange)
                Text("FitMetricsLog").font(.system(size: 26, weight: .bold)).foregroundColor(.white)
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
                Text(L(.workoutsLogged)).font(.system(size: 12)).foregroundColor(.gray)
                Text("\(logStore.sessions.count)")
                    .font(.system(size: 34, weight: .black)).foregroundColor(.white)
                Text(L(.allTime)).font(.system(size: 12)).foregroundColor(.gray)
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
    @State private var selectedMuscles:   Set<String> = []
    @State private var selectedExercises: Set<UUID>   = []

    enum HomeChartStyle: String, CaseIterable {
        case bar  = "bar"
        case line = "line"
        var label: String {
            self == .bar ? L(.barChart) : L(.lineChart)
        }
    }

    @State private var showFilterSheet = false
    @State private var showFullscreenChart = false

    // Computed chart data & title (shared between inline and fullscreen)
    var chartData: [(date: Date, volume: Double)] {
        if !selectedExercises.isEmpty {
            let allDays = selectedExercises.flatMap { eid in
                logStore.dailyVolumesForExercise(id: eid, in: range)
            }
            let grouped = Dictionary(grouping: allDays, by: { Calendar.current.startOfDay(for: $0.date) })
            return grouped.map { (date: $0.key, volume: $0.value.reduce(0) { $0 + $1.volume }) }
                       .sorted { $0.date < $1.date }
        }
        if !selectedMuscles.isEmpty {
            let groups = MuscleGroupManager.shared.groups.filter { selectedMuscles.contains($0.id) }
            let allDays = groups.flatMap { g in logStore.dailyVolumes(in: range, muscle: g) }
            let grouped = Dictionary(grouping: allDays, by: { Calendar.current.startOfDay(for: $0.date) })
            return grouped.map { (date: $0.key, volume: $0.value.reduce(0) { $0 + $1.volume }) }
                       .sorted { $0.date < $1.date }
        }
        return logStore.dailyVolumes(in: range, muscle: nil)
    }

    var chartTitle: String {
        if selectedExercises.count == 1,
           let ex = exerciseStore.exercises.first(where: { selectedExercises.contains($0.id) }) {
            return "\(ex.name) Volume"
        }
        if selectedExercises.count > 1 { return "\(selectedExercises.count) Exercises Volume" }
        if selectedMuscles.count == 1,
           let g = MuscleGroupManager.shared.groups.first(where: { selectedMuscles.contains($0.id) }) {
            return "\(g.rawValue) Volume"
        }
        if selectedMuscles.count > 1 { return "\(selectedMuscles.count) Groups Volume" }
        return "Total Volume"
    }

    var body: some View {
        VStack(spacing: 0) {
            sectionHeaderWithFilters.padding(.horizontal, 20)
            chartCard.padding(.top, 12).padding(.horizontal, 20)
            insightRow.padding(.top, 16).padding(.horizontal, 20)
            muscleBreakdown.padding(.top, 16).padding(.horizontal, 20)
        }
        .sheet(isPresented: $showFilterSheet) {
            FilterSheetView(
                muscleManager: muscleManager,
                exercises: exerciseStore.exercises,
                selectedMuscles: $selectedMuscles,
                selectedExercises: $selectedExercises
            )
            .presentationDetents([.medium, .large])
        }
        .fullScreenCover(isPresented: $showFullscreenChart) {
            FullscreenChartView(data: chartData, title: chartTitle, isBar: style == .bar)
                .modifier(LandscapeModifier())
        }
    }

    // Active filters shown as compact chips
    var activeFilterRow: some View {
        HStack(spacing: 8) {
            ForEach(Array(selectedMuscles), id: \.self) { mid in
                if let g = muscleManager.liveGroup(for: mid) {
                    ActiveFilterChip(label: g.rawValue, color: g.color) {
                        selectedMuscles.remove(mid)
                        if selectedMuscles.isEmpty { selectedExercises.removeAll() }
                    }
                }
            }
            ForEach(Array(selectedExercises), id: \.self) { eid in
                if let ex = exerciseStore.exercises.first(where: { $0.id == eid }) {
                    ActiveFilterChip(label: ex.name, color: .orange) { selectedExercises.remove(eid) }
                }
            }
            Spacer()
        }
    }

    // muscleFilter moved to FilterSheetView

    // exerciseFilter moved to FilterSheetView

    var sectionHeader: some View { sectionHeaderWithFilters }

    var sectionHeaderWithFilters: some View {
        VStack(spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L(.yourProgress)).font(.system(size: 20, weight: .bold)).foregroundColor(.white)
                    Text("Volume & muscle breakdown").font(.system(size: 12)).foregroundColor(.gray)
                }
                Spacer()
                HStack(spacing: 6) {
                    // Range selector (compact)
                    Menu {
                        ForEach(DateRange.allCases, id: \.self) { r in
                            Button(action: { range = r }) {
                                HStack {
                                    Text(r.rawValue)
                                    if range == r { Image(systemName: "checkmark") }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(range.rawValue)
                                .font(.system(size: 12, weight: .semibold)).foregroundColor(.white)
                            Image(systemName: "chevron.down").font(.system(size: 9)).foregroundColor(.gray)
                        }
                        .padding(.horizontal, 9).padding(.vertical, 7)
                        .background(Color(hex: "2C2C2C")).cornerRadius(10)
                    }
                    // Filter button
                    Button(action: { showFilterSheet = true }) {
                        let active = !selectedMuscles.isEmpty || !selectedExercises.isEmpty
                        Image(systemName: active ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                            .font(.system(size: 20))
                            .foregroundColor(active ? .orange : .gray)
                            .padding(.horizontal, 9).padding(.vertical, 7)
                            .background(Color(hex: "2C2C2C")).cornerRadius(10)
                    }
                    // Chart style toggle
                    HStack(spacing: 0) {
                        ForEach(HomeChartStyle.allCases, id: \.self) { s in
                            Button(action: { style = s }) {
                                Image(systemName: s == .bar ? "chart.bar.fill" : "chart.line.uptrend.xyaxis")
                                    .font(.system(size: 13))
                                    .foregroundColor(style == s ? .black : .gray)
                                    .frame(width: 30, height: 28)
                                    .background(style == s ? Color.orange : Color.clear)
                                    .cornerRadius(7)
                            }
                        }
                    }
                    .padding(3).background(Color(hex: "2C2C2C")).cornerRadius(10)
                }
            }
            // Active filter chips (compact, only when active)
            if !selectedMuscles.isEmpty || !selectedExercises.isEmpty {
                HStack(spacing: 8) {
                    ForEach(Array(selectedMuscles), id: \.self) { mid in
                        if let g = muscleManager.liveGroup(for: mid) {
                            ActiveFilterChip(label: g.rawValue, color: g.color) {
                                selectedMuscles.remove(mid)
                                if selectedMuscles.isEmpty { selectedExercises.removeAll() }
                            }
                        }
                    }
                    ForEach(Array(selectedExercises), id: \.self) { eid in
                        if let ex = exerciseStore.exercises.first(where: { $0.id == eid }) {
                            ActiveFilterChip(label: ex.name, color: .orange) { selectedExercises.remove(eid) }
                        }
                    }
                    Spacer()
                }
            }
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
            Text(chartTitle)
                .font(.system(size: 15, weight: .bold)).foregroundColor(.white)
            let data = chartData
            if data.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.system(size: 36)).foregroundColor(.gray.opacity(0.3))
                    Text(L(.logWorkoutsFirst))
                        .font(.system(size: 12)).foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity).frame(height: 120)
                .background(Color(hex: "1C1C1E")).cornerRadius(14)
            } else {
                HomeVolumeChart(data: data, isBar: style == .bar) {
                    showFullscreenChart = true
                }
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
        let stats    = selectedMuscles.isEmpty ? allStats : allStats.filter { selectedMuscles.contains($0.muscleGroup.id) }
        let maxVol = stats.map(\.totalVolume).max() ?? 1

        return VStack(alignment: .leading, spacing: 10) {
            Text(L(.muscleBreakdown)).font(.system(size: 15, weight: .bold)).foregroundColor(.white)
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
    var onFullscreen: (() -> Void)? = nil

    @State private var hovered: Int? = nil
    @GestureState private var isDragging = false

    // Y-axis: 4 nice labels starting from minVal (not 0)
    func yLabels(min minVal: Double, max maxVal: Double) -> [Double] {
        guard maxVal > minVal else { return [minVal] }
        let range = maxVal - minVal
        let step = (range / 3).rounded(.up)
        let nice = step <= 5  ? ceil(step / 1)  * 1
                 : step <= 10 ? ceil(step / 5)  * 5
                 : step <= 50 ? ceil(step / 10) * 10
                 : step <= 200 ? ceil(step / 50) * 50
                 : ceil(step / 100) * 100
        let base = (minVal / nice).rounded(.down) * nice
        return [base, base+nice, base+nice*2, base+nice*3].filter { $0 <= maxVal * 1.05 + nice }
    }

    // X-axis: up to 5 evenly-spaced date labels
    func xLabels() -> [(Int, Date)] {
        guard data.count > 1 else { return data.indices.map { ($0, data[$0].date) } }
        let count = min(5, data.count)
        let step = Double(data.count - 1) / Double(count - 1)
        return (0..<count).map { i in
            let idx = min(Int((Double(i) * step).rounded()), data.count - 1)
            return (idx, data[idx].date)
        }
    }

    var dateFormatter: DateFormatter {
        let f = DateFormatter(); f.dateFormat = "d MMM"; return f
    }

    var fullDateFormatter: DateFormatter {
        let f = DateFormatter(); f.dateFormat = "d MMM yyyy"; return f
    }

    // Compute x position for a data point index
    func xPos(index: Int, width: CGFloat) -> CGFloat {
        guard data.count > 1 else { return width / 2 }
        return CGFloat(index) / CGFloat(data.count - 1) * (width - 8) + 4
    }

    // Compute y position for a volume value
    func yPos(volume: Double, height: CGFloat, yBase: Double, yTop: Double) -> CGFloat {
        (height - 4) * (1 - CGFloat((volume - yBase) / (yTop - yBase))) + 2
    }

    // Find nearest index from drag x position
    func nearestIndex(x: CGFloat, width: CGFloat) -> Int {
        guard data.count > 1 else { return 0 }
        let segW = (width - 8) / CGFloat(data.count - 1)
        let idx = Int(((x - 4) / segW).rounded())
        return max(0, min(data.count - 1, idx))
    }

    var body: some View {
        let minVol = (data.map(\.volume).min() ?? 0)
        let maxVol = (data.map(\.volume).max() ?? 1)
        let yLbls  = yLabels(min: minVol, max: maxVol)
        let xLbls  = xLabels()
        let yLabelW: CGFloat = 40
        let xLabelH: CGFloat = 18
        let chartH:  CGFloat = 140
        let yBase  = minVol * 0.95
        let yTop   = maxVol * 1.05

        VStack(spacing: 0) {
            HStack(alignment: .bottom, spacing: 0) {
                // Y-axis labels
                VStack(alignment: .trailing, spacing: 0) {
                    ForEach(yLbls.reversed(), id: \.self) { val in
                        Text(val >= 1000 ? String(format: "%.0fk", val/1000) : "\(Int(val))")
                            .font(.system(size: 9)).foregroundColor(.gray)
                            .frame(maxHeight: .infinity, alignment: .center)
                    }
                }
                .frame(width: yLabelW, height: chartH)

                // Chart area
                GeometryReader { geo in
                    let w = geo.size.width
                    let h = geo.size.height
                    ZStack {
                        Color(hex: "1C1C1E")

                        // Y grid lines
                        ForEach(yLbls, id: \.self) { val in
                            let y = h * (1 - CGFloat((val - yBase) / (yTop - yBase)))
                            Path { p in p.move(to: CGPoint(x: 0, y: y)); p.addLine(to: CGPoint(x: w, y: y)) }
                                .stroke(Color.white.opacity(val == 0 ? 0.15 : 0.06), lineWidth: val == 0 ? 1 : 0.5)
                        }

                        if isBar {
                            // ── Bar chart ──
                            let barW = max(3, (w - 8) / CGFloat(max(data.count, 1)) - 2)
                            HStack(alignment: .bottom, spacing: 2) {
                                ForEach(Array(data.enumerated()), id: \.offset) { idx, pt in
                                    let barH = max(3, (h - 4) * CGFloat((pt.volume - yBase) / (yTop - yBase)))
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(hovered == idx ? Color.orange : Color.orange.opacity(0.7))
                                        .frame(width: barW, height: barH)
                                }
                            }
                            .padding(.horizontal, 4).padding(.bottom, 2)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                        } else {
                            // ── Line chart ──
                            let pts: [CGPoint] = data.enumerated().map { i, pt in
                                CGPoint(x: xPos(index: i, width: w),
                                        y: yPos(volume: pt.volume, height: h, yBase: yBase, yTop: yTop))
                            }
                            // Fill under line
                            Path { path in
                                guard let first = pts.first, let last = pts.last else { return }
                                path.move(to: CGPoint(x: first.x, y: h))
                                path.addLine(to: first)
                                for pt in pts.dropFirst() { path.addLine(to: pt) }
                                path.addLine(to: CGPoint(x: last.x, y: h))
                            }
                            .fill(LinearGradient(colors: [Color.orange.opacity(0.25), .clear],
                                                  startPoint: .top, endPoint: .bottom))
                            // Line
                            Path { path in
                                for (i, pt) in pts.enumerated() {
                                    if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
                                }
                            }
                            .stroke(Color.orange, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                        }

                        // ── Hover indicator (dashed line + dot + tooltip) ──
                        if let idx = hovered, idx < data.count {
                            let dp = data[idx]
                            let xP: CGFloat = {
                                if isBar {
                                    let barW = max(3, (w - 8) / CGFloat(max(data.count, 1)) - 2)
                                    let totalSpacing = CGFloat(max(data.count - 1, 0)) * 2
                                    let totalBars = CGFloat(data.count) * barW
                                    let startX: CGFloat = 4 + (w - 8 - totalBars - totalSpacing) / 2
                                    return startX + CGFloat(idx) * (barW + 2) + barW / 2
                                } else {
                                    return xPos(index: idx, width: w)
                                }
                            }()
                            let yP: CGFloat = isBar
                                ? h - max(3, (h - 4) * CGFloat((dp.volume - yBase) / (yTop - yBase))) - 2
                                : yPos(volume: dp.volume, height: h, yBase: yBase, yTop: yTop)

                            // Dashed vertical line
                            Path { p in
                                p.move(to: CGPoint(x: xP, y: 0))
                                p.addLine(to: CGPoint(x: xP, y: h))
                            }
                            .stroke(Color.gray.opacity(0.5),
                                    style: StrokeStyle(lineWidth: 1, dash: [4, 3]))

                            // Outer ring
                            Circle()
                                .stroke(Color.white.opacity(0.3), lineWidth: 2)
                                .frame(width: 18, height: 18)
                                .position(x: xP, y: yP)
                            // Inner dot
                            Circle()
                                .fill(Color.orange)
                                .frame(width: 8, height: 8)
                                .position(x: xP, y: yP)

                            // Floating tooltip card
                            let tooltipW: CGFloat = 110
                            let tooltipX = min(max(tooltipW/2 + 4, xP), w - tooltipW/2 - 4)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Volume")
                                    .font(.system(size: 9)).foregroundColor(.gray)
                                Text(dp.volume >= 1000 ? String(format: "%.1fk", dp.volume/1000) : "\(Int(dp.volume)) kg")
                                    .font(.system(size: 18, weight: .black)).foregroundColor(.white)
                                Divider().background(Color.white.opacity(0.15))
                                Text(fullDateFormatter.string(from: dp.date))
                                    .font(.system(size: 9)).foregroundColor(.gray)
                            }
                            .padding(.horizontal, 12).padding(.vertical, 10)
                            .frame(width: tooltipW)
                            .background(Color(hex: "1A1A1A"))
                            .cornerRadius(12)
                            .shadow(color: .black.opacity(0.5), radius: 10, y: 4)
                            .position(x: tooltipX, y: max(42, yP - 55))
                        }
                    }
                    .cornerRadius(12)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .updating($isDragging) { _, state, _ in state = true }
                            .onChanged { v in
                                let idx = nearestIndex(x: v.location.x, width: w)
                                if hovered != idx { hovered = idx }
                            }
                            .onEnded { _ in
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    withAnimation(.easeOut(duration: 0.3)) { hovered = nil }
                                }
                            }
                    )
                    .simultaneousGesture(
                        TapGesture(count: 2).onEnded { onFullscreen?() }
                    )
                }
                .frame(height: chartH)
                .onChange(of: isBar) { _ in hovered = nil }
            }

            // X-axis labels
            HStack(alignment: .top, spacing: 0) {
                Spacer().frame(width: yLabelW)
                GeometryReader { geo in
                    let w = geo.size.width
                    ZStack(alignment: .topLeading) {
                        ForEach(xLbls, id: \.0) { idx, date in
                            let x = data.count > 1
                                ? CGFloat(idx) / CGFloat(data.count - 1) * (w - 8) + 4
                                : w / 2
                            Text(dateFormatter.string(from: date))
                                .font(.system(size: 9)).foregroundColor(.gray)
                                .fixedSize()
                                .position(x: x, y: 8)
                        }
                    }
                }
                .frame(height: xLabelH)
            }

            // Fullscreen hint
            if onFullscreen != nil {
                HStack {
                    Spacer()
                    Button(action: { onFullscreen?() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .font(.system(size: 10))
                            Text("Fullscreen")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundColor(.gray)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Color(hex: "2C2C2C")).cornerRadius(8)
                    }
                }
                .padding(.top, 6)
            }
        }
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


// MARK: - Active Filter Chip
struct ActiveFilterChip: View {
    let label: String; let color: Color; let onRemove: () -> Void
    var body: some View {
        HStack(spacing: 4) {
            Text(label).font(.system(size: 11, weight: .medium)).foregroundColor(color)
            Button(action: onRemove) {
                Image(systemName: "xmark").font(.system(size: 9, weight: .bold)).foregroundColor(color)
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(color.opacity(0.15)).cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(color.opacity(0.3), lineWidth: 1))
    }
}

// MARK: - Filter Sheet
struct FilterSheetView: View {
    @ObservedObject var muscleManager: MuscleGroupManager
    @ObservedObject private var loc = LocalizationManager.shared
    let exercises: [Exercise]
    @Binding var selectedMuscles:   Set<String>
    @Binding var selectedExercises: Set<UUID>
    @Environment(\.dismiss) var dismiss

    var filteredExercises: [Exercise] {
        guard !selectedMuscles.isEmpty else { return exercises }
        return exercises.filter { ex in
            ex.muscleGroups.contains(where: { selectedMuscles.contains($0.id) })
        }
    }

    var body: some View {
        ZStack {
            Color(hex: "111111").ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                // Handle
                HStack {
                    Spacer()
                    RoundedRectangle(cornerRadius: 3).fill(Color.gray.opacity(0.4))
                        .frame(width: 40, height: 4)
                    Spacer()
                }.padding(.top, 10)

                HStack {
                    Text(L(.filter)).font(.system(size: 18, weight: .bold)).foregroundColor(.white)
                    Spacer()
                    // Selection count badge
                    let total = selectedMuscles.count + selectedExercises.count
                    if total > 0 {
                        Text("\(total)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Color.orange).cornerRadius(10)
                    }
                    Button(L(.reset)) {
                        selectedMuscles.removeAll(); selectedExercises.removeAll()
                    }.foregroundColor(.orange).padding(.leading, 10)
                    Button(L(.done)) { dismiss() }
                        .font(.system(size: 15, weight: .semibold)).foregroundColor(.orange)
                        .padding(.leading, 12)
                }.padding(.horizontal, 20).padding(.top, 14).padding(.bottom, 16)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {

                        // ── Muscle Groups (multi) ──
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text(L(.muscleGroups))
                                    .font(.system(size: 13, weight: .semibold)).foregroundColor(.gray)
                                if !selectedMuscles.isEmpty {
                                    Text("\(selectedMuscles.count) selected")
                                        .font(.system(size: 11)).foregroundColor(.orange)
                                }
                            }.padding(.horizontal, 20)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    // All button
                                    FilterChip(title: L(.all), isSelected: selectedMuscles.isEmpty) {
                                        selectedMuscles.removeAll(); selectedExercises.removeAll()
                                    }
                                    ForEach(muscleManager.groups) { g in
                                        FilterChipColored(
                                            title: g.rawValue, icon: g.icon, color: g.color,
                                            muscleImage: g.image,
                                            isSelected: selectedMuscles.contains(g.id)
                                        ) {
                                            if selectedMuscles.contains(g.id) {
                                                selectedMuscles.remove(g.id)
                                                // Remove exercises that no longer match
                                                selectedExercises = selectedExercises.filter { eid in
                                                    exercises.first { $0.id == eid }.map {
                                                        $0.muscleGroups.contains(where: { selectedMuscles.contains($0.id) })
                                                    } ?? false
                                                }
                                            } else {
                                                selectedMuscles.insert(g.id)
                                            }
                                        }
                                    }
                                }.padding(.horizontal, 20)
                            }
                        }

                        // ── Exercises (multi) ──
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text(L(.exercises))
                                    .font(.system(size: 13, weight: .semibold)).foregroundColor(.gray)
                                if !selectedExercises.isEmpty {
                                    Text("\(selectedExercises.count) selected")
                                        .font(.system(size: 11)).foregroundColor(.orange)
                                }
                            }.padding(.horizontal, 20)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    FilterChip(title: L(.all), isSelected: selectedExercises.isEmpty) {
                                        selectedExercises.removeAll()
                                    }
                                    ForEach(filteredExercises) { ex in
                                        FilterChip(
                                            title: ex.name,
                                            isSelected: selectedExercises.contains(ex.id)
                                        ) {
                                            if selectedExercises.contains(ex.id) {
                                                selectedExercises.remove(ex.id)
                                            } else {
                                                selectedExercises.insert(ex.id)
                                            }
                                        }
                                    }
                                }.padding(.horizontal, 20)
                            }
                        }
                    }
                    .padding(.bottom, 40)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Fullscreen Landscape Chart View
struct FullscreenChartView: View {
    let data: [(date: Date, volume: Double)]
    let title: String
    let isBar: Bool
    @Environment(\.dismiss) var dismiss

    @State private var hovered: Int? = nil
    @GestureState private var isDragging = false

    var dateFormatter: DateFormatter {
        let f = DateFormatter(); f.dateFormat = "d MMM"; return f
    }
    var fullDateFormatter: DateFormatter {
        let f = DateFormatter(); f.dateFormat = "d MMM yyyy"; return f
    }

    func yLabels(min minVal: Double, max maxVal: Double) -> [Double] {
        guard maxVal > minVal else { return [minVal] }
        let step = ((maxVal - minVal) / 4).rounded(.up)
        let nice = step <= 5 ? ceil(step/1)*1
                 : step <= 10 ? ceil(step/5)*5
                 : step <= 50 ? ceil(step/10)*10
                 : step <= 200 ? ceil(step/50)*50
                 : ceil(step/100)*100
        let base = (minVal / nice).rounded(.down) * nice
        return stride(from: base, through: maxVal * 1.05 + nice, by: nice).map { $0 }
    }

    func xLabels() -> [(Int, Date)] {
        guard data.count > 1 else { return data.indices.map { ($0, data[$0].date) } }
        let count = min(8, data.count)
        let step = Double(data.count - 1) / Double(count - 1)
        return (0..<count).map { i in
            let idx = min(Int((Double(i) * step).rounded()), data.count - 1)
            return (idx, data[idx].date)
        }
    }

    func xPos(index: Int, width: CGFloat) -> CGFloat {
        guard data.count > 1 else { return width / 2 }
        return CGFloat(index) / CGFloat(data.count - 1) * (width - 12) + 6
    }

    func yPos(volume: Double, height: CGFloat, yBase: Double, yTop: Double) -> CGFloat {
        (height - 6) * (1 - CGFloat((volume - yBase) / (yTop - yBase))) + 3
    }

    func nearestIndex(x: CGFloat, width: CGFloat) -> Int {
        guard data.count > 1 else { return 0 }
        let segW = (width - 12) / CGFloat(data.count - 1)
        return max(0, min(data.count - 1, Int(((x - 6) / segW).rounded())))
    }

    var body: some View {
        let minVol = data.map(\.volume).min() ?? 0
        let maxVol = data.map(\.volume).max() ?? 1
        let yLbls  = yLabels(min: minVol, max: maxVol)
        let xLbls  = xLabels()
        let yBase  = minVol * 0.95
        let yTop   = maxVol * 1.05

        ZStack {
            Color(hex: "111111").ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title).font(.system(size: 18, weight: .bold)).foregroundColor(.white)
                        Text("\(data.count) sessions").font(.system(size: 12)).foregroundColor(.gray)
                    }
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 26))
                            .foregroundColor(.gray)
                    }
                }
                .padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 12)

                // Chart
                HStack(alignment: .bottom, spacing: 0) {
                    // Y labels
                    VStack(alignment: .trailing, spacing: 0) {
                        ForEach(yLbls.reversed(), id: \.self) { val in
                            Text(val >= 1000 ? String(format: "%.0fk", val/1000) : "\(Int(val))")
                                .font(.system(size: 10)).foregroundColor(.gray)
                                .frame(maxHeight: .infinity, alignment: .center)
                        }
                    }
                    .frame(width: 44)

                    // Chart area
                    GeometryReader { geo in
                        let w = geo.size.width
                        let h = geo.size.height

                        ZStack {
                            Color(hex: "1C1C1E")

                            // Grid lines
                            ForEach(yLbls, id: \.self) { val in
                                let y = h * (1 - CGFloat((val - yBase) / (yTop - yBase)))
                                Path { p in
                                    p.move(to: CGPoint(x: 0, y: y))
                                    p.addLine(to: CGPoint(x: w, y: y))
                                }
                                .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
                            }

                            if isBar {
                                let barW = max(4, (w - 12) / CGFloat(max(data.count, 1)) - 3)
                                HStack(alignment: .bottom, spacing: 3) {
                                    ForEach(Array(data.enumerated()), id: \.offset) { idx, pt in
                                        let barH = max(3, (h - 6) * CGFloat((pt.volume - yBase) / (yTop - yBase)))
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(hovered == idx ? Color.orange : Color.orange.opacity(0.7))
                                            .frame(width: barW, height: barH)
                                    }
                                }
                                .padding(.horizontal, 6).padding(.bottom, 3)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                            } else {
                                let pts: [CGPoint] = data.enumerated().map { i, pt in
                                    CGPoint(x: xPos(index: i, width: w),
                                            y: yPos(volume: pt.volume, height: h, yBase: yBase, yTop: yTop))
                                }
                                // Fill
                                Path { path in
                                    guard let first = pts.first, let last = pts.last else { return }
                                    path.move(to: CGPoint(x: first.x, y: h))
                                    path.addLine(to: first)
                                    for pt in pts.dropFirst() { path.addLine(to: pt) }
                                    path.addLine(to: CGPoint(x: last.x, y: h))
                                }
                                .fill(LinearGradient(colors: [Color.orange.opacity(0.3), .clear],
                                                      startPoint: .top, endPoint: .bottom))
                                // Line
                                Path { path in
                                    for (i, pt) in pts.enumerated() {
                                        if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
                                    }
                                }
                                .stroke(Color.orange, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                            }

                            // ── Hover indicator ──
                            if let idx = hovered, idx < data.count {
                                let dp = data[idx]
                                let xP = xPos(index: idx, width: w)
                                let yP = isBar
                                    ? h - max(3, (h - 6) * CGFloat((dp.volume - yBase) / (yTop - yBase))) - 3
                                    : yPos(volume: dp.volume, height: h, yBase: yBase, yTop: yTop)

                                // Dashed vertical line
                                Path { p in
                                    p.move(to: CGPoint(x: xP, y: 0))
                                    p.addLine(to: CGPoint(x: xP, y: h))
                                }
                                .stroke(Color.gray.opacity(0.5),
                                        style: StrokeStyle(lineWidth: 1, dash: [5, 3]))

                                // Outer ring
                                Circle()
                                    .stroke(Color.white.opacity(0.3), lineWidth: 2.5)
                                    .frame(width: 22, height: 22)
                                    .position(x: xP, y: yP)
                                // Inner dot
                                Circle()
                                    .fill(Color.orange)
                                    .frame(width: 10, height: 10)
                                    .position(x: xP, y: yP)

                                // Floating tooltip
                                let tooltipW: CGFloat = 140
                                let tooltipX = min(max(tooltipW/2 + 6, xP), w - tooltipW/2 - 6)
                                VStack(alignment: .leading, spacing: 5) {
                                    Text("Volume")
                                        .font(.system(size: 10)).foregroundColor(.gray)
                                    Text(dp.volume >= 1000 ? String(format: "%.1fk", dp.volume/1000) : "\(Int(dp.volume)) kg")
                                        .font(.system(size: 22, weight: .black)).foregroundColor(.white)
                                    Divider().background(Color.white.opacity(0.15))
                                    Text(fullDateFormatter.string(from: dp.date))
                                        .font(.system(size: 10)).foregroundColor(.gray)
                                }
                                .padding(.horizontal, 14).padding(.vertical, 12)
                                .frame(width: tooltipW)
                                .background(Color(hex: "1A1A1A"))
                                .cornerRadius(14)
                                .shadow(color: .black.opacity(0.6), radius: 12, y: 5)
                                .position(x: tooltipX, y: max(50, yP - 65))
                            }
                        }
                        .cornerRadius(14)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .updating($isDragging) { _, state, _ in state = true }
                                .onChanged { v in
                                    let idx = nearestIndex(x: v.location.x, width: w)
                                    if hovered != idx { hovered = idx }
                                }
                                .onEnded { _ in
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                                        withAnimation(.easeOut(duration: 0.3)) { hovered = nil }
                                    }
                                }
                        )
                    }
                }
                .padding(.horizontal, 20)
                .frame(maxHeight: .infinity)

                // X labels
                HStack(alignment: .top, spacing: 0) {
                    Spacer().frame(width: 64)
                    GeometryReader { geo in
                        let w = geo.size.width
                        ZStack(alignment: .topLeading) {
                            ForEach(xLbls, id: \.0) { idx, date in
                                let x = data.count > 1
                                    ? CGFloat(idx) / CGFloat(data.count - 1) * (w - 12) + 6
                                    : w / 2
                                Text(dateFormatter.string(from: date))
                                    .font(.system(size: 10)).foregroundColor(.gray)
                                    .fixedSize().position(x: x, y: 8)
                            }
                        }
                    }
                    .frame(height: 24)
                    Spacer().frame(width: 20)
                }
                .padding(.bottom, 16)
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Landscape orientation support
struct LandscapeModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .onAppear {
                let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene
                windowScene?.requestGeometryUpdate(.iOS(interfaceOrientations: .landscape))
                UIViewController.attemptRotationToDeviceOrientation()
            }
            .onDisappear {
                let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene
                windowScene?.requestGeometryUpdate(.iOS(interfaceOrientations: .all))
                UIViewController.attemptRotationToDeviceOrientation()
            }
    }
}
