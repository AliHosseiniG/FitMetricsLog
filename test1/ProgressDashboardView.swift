//
//  ProgressDashboardView.swift
//  FlexCore
//

import SwiftUI

struct ProgressDashboardView: View {
    @EnvironmentObject var logStore:      WorkoutLogStore
    @EnvironmentObject var exerciseStore: ExerciseStore

    @State private var range:     DateRange         = .month
    @State private var muscles:   Set<String>      = []   // MuscleGroup IDs
    @State private var exercises: Set<UUID>        = []   // Exercise IDs
    @State private var style:     ChartStyle        = .bar

    // Convenience
    var selectedMuscles:   [MuscleGroup] {
        MuscleGroupManager.shared.groups.filter { muscles.contains($0.id) }
    }
    var selectedExercises: [Exercise] {
        exerciseStore.exercises.filter { exercises.contains($0.id) }
    }

    enum ChartStyle: String, CaseIterable {
        case bar  = "Bar"
        case line = "Line"
    }

    var body: some View {
        ZStack {
            Color(hex: "111111").ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    header
                    rangeBar.padding(.top, 16)
                    muscleChips.padding(.top, 10)
                    exerciseChips.padding(.top, 6)
                    summaryGrid.padding(.top, 18)
                    chartCard.padding(.top, 22)
                    insights.padding(.top, 22)
                    breakdown.padding(.top, 22)
                    Spacer(minLength: 100)
                }
            }
        }
        .navigationBarHidden(true)
    }

    // MARK: - Header
    var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("My Progress")
                    .font(.system(size: 28, weight: .bold)).foregroundColor(.white)
                Text("Analytics & Insights")
                    .font(.system(size: 13)).foregroundColor(.gray)
            }
            Spacer()
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 26)).foregroundColor(.orange)
        }
        .padding(.horizontal, 20).padding(.top, 60)
    }

    // MARK: - Date range segmented control
    var rangeBar: some View {
        HStack(spacing: 0) {
            ForEach(DateRange.allCases, id: \.self) { r in
                Button(action: { range = r }) {
                    Text(r.rawValue)
                        .font(.system(size: 13, weight: range == r ? .bold : .regular))
                        .foregroundColor(range == r ? .black : .gray)
                        .frame(maxWidth: .infinity).padding(.vertical, 9)
                        .background(range == r ? Color.orange : Color.clear)
                        .cornerRadius(10)
                }
            }
        }
        .padding(4).background(Color(hex: "1C1C1E")).cornerRadius(14)
        .padding(.horizontal, 20)
    }

    // MARK: - Muscle filter chips (multi-select)
    var muscleChips: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Muscle Groups")
                    .font(.system(size: 12, weight: .semibold)).foregroundColor(.gray)
                    .padding(.leading, 20)
                Spacer()
                if !muscles.isEmpty {
                    Button(action: { muscles.removeAll(); exercises.removeAll() }) {
                        Text("Clear")
                            .font(.system(size: 12)).foregroundColor(.orange)
                            .padding(.trailing, 20)
                    }
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    FilterChip(title: "All", isSelected: muscles.isEmpty) {
                        muscles.removeAll(); exercises.removeAll()
                    }
                    ForEach(MuscleGroupManager.shared.groups) { g in
                        let on = muscles.contains(g.id)
                        FilterChipColored(
                            title: g.rawValue,
                            icon: g.icon,
                            color: g.color,
                            isSelected: on
                        ) {
                            if on { muscles.remove(g.id) }
                            else  { muscles.insert(g.id) }
                            // remove exercises not in new muscle set
                            if !muscles.isEmpty {
                                exercises = exercises.filter { eid in
                                    exerciseStore.exercises.first(where: { $0.id == eid })
                                        .map { $0.muscleGroups.contains(where: { muscles.contains($0.id) }) } ?? false
                                }
                            }
                        }
                    }
                }.padding(.horizontal, 20)
            }
        }
    }

    // MARK: - Exercise filter chips (multi-select)
    @ViewBuilder
    var exerciseChips: some View {
        let pool: [Exercise] = {
            if muscles.isEmpty { return exerciseStore.exercises }
            return exerciseStore.exercises.filter { ex in
                ex.muscleGroups.contains(where: { muscles.contains($0.id) })
            }
        }()

        if !pool.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Exercises")
                        .font(.system(size: 12, weight: .semibold)).foregroundColor(.gray)
                        .padding(.leading, 20)
                    Spacer()
                    if !exercises.isEmpty {
                        Button(action: { exercises.removeAll() }) {
                            Text("Clear")
                                .font(.system(size: 12)).foregroundColor(.orange)
                                .padding(.trailing, 20)
                        }
                    }
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        FilterChip(title: "All", isSelected: exercises.isEmpty) {
                            exercises.removeAll()
                        }
                        ForEach(pool) { ex in
                            let on = exercises.contains(ex.id)
                            FilterChip(title: ex.name, isSelected: on) {
                                if on { exercises.remove(ex.id) }
                                else  { exercises.insert(ex.id) }
                            }
                        }
                    }.padding(.horizontal, 20)
                }
            }
        }
    }

    // MARK: - Summary grid
    var summaryGrid: some View {
        let sessions  = logStore.totalSessions(in: range)
        let volume    = logStore.totalVolume(in: range)
        let most      = logStore.overtrainedMuscles(in: range, topN: 1).first.map { MuscleGroupManager.shared.liveName(for: $0) } ?? "—"
        let neglected = logStore.neglectedMuscles(in: range, topN: 1).first.map { MuscleGroupManager.shared.liveName(for: $0) } ?? "—"

        return LazyVGrid(
            columns: [GridItem(.flexible()), GridItem(.flexible())],
            spacing: 12
        ) {
            DashCard(title: "Sessions",     value: "\(sessions)",       icon: "calendar.badge.checkmark", color: .orange)
            DashCard(title: "Total Volume", value: "\(Int(volume)) kg", icon: "scalemass.fill",           color: .blue)
            DashCard(title: "Most Trained", value: most,                icon: "flame.fill",               color: .green)
            DashCard(title: "Needs Work",   value: neglected,           icon: "exclamationmark.triangle.fill", color: .red)
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Chart card
    var chartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(chartTitle)
                    .font(.system(size: 17, weight: .bold)).foregroundColor(.white)
                Spacer()
                // Bar / Line toggle
                HStack(spacing: 0) {
                    ForEach(ChartStyle.allCases, id: \.self) { s in
                        Button(action: { style = s }) {
                            Image(systemName: s == .bar
                                  ? "chart.bar.fill" : "chart.line.uptrend.xyaxis")
                                .font(.system(size: 14))
                                .foregroundColor(style == s ? .black : .gray)
                                .frame(width: 34, height: 30)
                                .background(style == s ? Color.orange : Color.clear)
                                .cornerRadius(8)
                        }
                    }
                }
                .padding(3).background(Color(hex: "2C2C2C")).cornerRadius(10)
            }
            .padding(.horizontal, 20)

            let data = chartData
            if data.isEmpty {
                emptyChart.padding(.horizontal, 20)
            } else {
                VolumeChart(data: data, style: style, accent: chartAccent)
                    .padding(.horizontal, 20)
            }
        }
    }

    var chartData: [(date: Date, volume: Double)] {
        if !exercises.isEmpty {
            // Sum volumes across all selected exercises per day
            return mergedDailyVolumes(
                selectedExercises.map { logStore.dailyVolumesForExercise(id: $0.id, in: range) }
            )
        }
        if !muscles.isEmpty {
            // Sum volumes across all selected muscle groups per day
            return mergedDailyVolumes(
                selectedMuscles.map { logStore.dailyVolumes(in: range, muscle: $0) }
            )
        }
        return logStore.dailyVolumes(in: range, muscle: nil)
    }

    func mergedDailyVolumes(_ lists: [[(date: Date, volume: Double)]]) -> [(date: Date, volume: Double)] {
        var dict: [Date: Double] = [:]
        for list in lists {
            for item in list { dict[item.date, default: 0] += item.volume }
        }
        return dict.map { ($0.key, $0.value) }.sorted { $0.date < $1.date }
    }

    var chartTitle: String {
        if !exercises.isEmpty {
            let names = selectedExercises.prefix(2).map(\.name).joined(separator: " + ")
            return exercises.count > 2 ? "\(names) +\(exercises.count-2) more" : names
        }
        if !muscles.isEmpty {
            let names = selectedMuscles.prefix(2).map(\.rawValue).joined(separator: " + ")
            return muscles.count > 2 ? "\(names) +\(muscles.count-2) more" : "\(names) Volume"
        }
        return "Total Volume"
    }

    var chartAccent: Color {
        if let ex = selectedExercises.first { return ex.chartColor }
        if let m  = selectedMuscles.first   { return m.color }
        return .orange
    }

    var emptyChart: some View {
        VStack(spacing: 14) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 40)).foregroundColor(.gray.opacity(0.35))
            Text("No data for this period")
                .font(.system(size: 14)).foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity).frame(height: 140)
        .background(Color(hex: "1C1C1E")).cornerRadius(16)
    }

    // MARK: - Insights
    var insights: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Insights")
                .font(.system(size: 18, weight: .bold)).foregroundColor(.white)
                .padding(.horizontal, 20)

            let neglected   = logStore.neglectedMuscles(in: range, topN: 3)
            let overtrained = logStore.overtrainedMuscles(in: range, topN: 2)
            let counts      = logStore.muscleGroupSessionCounts(in: range)
            let days        = max(1, Calendar.current.dateComponents([.day], from: range.bounds.start, to: Date()).day ?? 1)

            // Equal-height cards using overlay + background trick
            VStack(spacing: 10) {
                InsightCard(
                    icon: "exclamationmark.triangle.fill", color: .red,
                    title: "Neglected Muscles",
                    detail: neglected.isEmpty ? "Great balance!" :
                        neglected.map { g in let n = MuscleGroupManager.shared.liveName(for: g); return "\(n) (\(counts[g] ?? 0))" }
                                  .joined(separator: " · ")
                )
                InsightCard(
                    icon: "flame.fill", color: .orange,
                    title: "Most Trained",
                    detail: overtrained.isEmpty ? "—" :
                        overtrained.map { g in let n = MuscleGroupManager.shared.liveName(for: g); return "\(n) (\(counts[g] ?? 0) sessions)" }
                                   .joined(separator: " · ")
                )
                InsightCard(
                    icon: "calendar", color: .blue,
                    title: "Training Frequency",
                    detail: String(format: "%.1f sessions / week",
                                   Double(logStore.totalSessions(in: range)) / Double(days) * 7)
                )
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Muscle breakdown bars
    var breakdown: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Muscle Breakdown")
                .font(.system(size: 18, weight: .bold)).foregroundColor(.white)
                .padding(.horizontal, 20)

            let stats  = logStore.muscleGroupStats(in: range)
            let maxVol = stats.map(\.totalVolume).max() ?? 1

            VStack(spacing: 10) {
                ForEach(stats, id: \.muscleGroup) { stat in
                    MuscleBarRow(stat: stat, maxVolume: maxVol)
                }
            }
            .padding(16).background(Color(hex: "1C1C1E")).cornerRadius(16)
            .padding(.horizontal, 20)
        }
    }
}

// MARK: - Volume Chart (bar + line)
struct VolumeChart: View {
    let data:   [(date: Date, volume: Double)]
    let style:  ProgressDashboardView.ChartStyle
    let accent: Color

    @State private var hovered: Int? = nil

    private var maxVol: Double { data.map(\.volume).max() ?? 1 }

    private var yTicks: [Double] {
        let step = niceStep(maxVol / 4)
        var ticks: [Double] = []
        var v = 0.0
        while v <= maxVol + step { ticks.append(v); v += step }
        return ticks
    }

    private func niceStep(_ raw: Double) -> Double {
        let e = pow(10, floor(log10(max(raw, 1))))
        let f = raw / e
        if f <= 1 { return e } else if f <= 2 { return 2*e } else if f <= 5 { return 5*e }
        return 10*e
    }

    var body: some View {
        VStack(spacing: 0) {
            // Tooltip row
            if let i = hovered, i < data.count {
                tooltipFor(data[i]).padding(.bottom, 8)
            } else {
                Spacer().frame(height: 44)
            }

            GeometryReader { geo in
                let w      = geo.size.width
                let h      = geo.size.height
                let chartW = w - 44
                let barW   = max(4, chartW / CGFloat(data.count) - 4)
                let yMax   = yTicks.last ?? 1

                ZStack(alignment: .bottomLeading) {
                    // Y-axis grid lines
                    ForEach(yTicks, id: \.self) { tick in
                        let y = h - CGFloat(tick / yMax) * h
                        HStack(spacing: 4) {
                            Text(tick >= 1000 ? "\(Int(tick/1000))k" : "\(Int(tick))")
                                .font(.system(size: 9)).foregroundColor(.gray)
                                .frame(width: 36, alignment: .trailing)
                            Rectangle()
                                .fill(Color.white.opacity(0.06)).frame(height: 0.5)
                        }
                        .frame(width: w).offset(y: y - 6)
                    }

                    HStack(alignment: .bottom, spacing: 4) {
                        Spacer().frame(width: 40)

                        if style == .bar {
                            ForEach(Array(data.enumerated()), id: \.offset) { idx, pt in
                                let bh = max(2, CGFloat(pt.volume / maxVol) * h)
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(LinearGradient(
                                        colors: [accent, accent.opacity(0.5)],
                                        startPoint: .top, endPoint: .bottom))
                                    .frame(width: barW, height: bh)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 5)
                                            .stroke(Color.white.opacity(hovered == idx ? 0.6 : 0),
                                                    lineWidth: 1.5)
                                    )
                            }
                        } else {
                            Canvas { ctx, size in
                                let pts = linePoints(in: CGSize(width: chartW, height: h))
                                // Fill area
                                var area = Path()
                                if let f = pts.first {
                                    area.move(to: CGPoint(x: f.x, y: h))
                                    pts.forEach { area.addLine(to: $0) }
                                    area.addLine(to: CGPoint(x: pts.last!.x, y: h))
                                    area.closeSubpath()
                                }
                                ctx.fill(area, with: .color(accent.opacity(0.15)))
                                // Line
                                var line = Path()
                                if let f = pts.first {
                                    line.move(to: f)
                                    pts.dropFirst().forEach { line.addLine(to: $0) }
                                }
                                ctx.stroke(line, with: .color(accent),
                                           style: StrokeStyle(lineWidth: 2, lineCap: .round))
                                // Dots
                                for (i, p) in pts.enumerated() {
                                    let r: CGFloat = hovered == i ? 6 : 4
                                    ctx.fill(
                                        Path(ellipseIn: CGRect(x: p.x-r, y: p.y-r,
                                                               width: r*2, height: r*2)),
                                        with: .color(accent)
                                    )
                                }
                            }
                            .frame(width: chartW, height: h)
                        }
                    }
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { v in
                            let x    = v.location.x - 40
                            let segW = chartW / CGFloat(max(data.count, 1))
                            hovered  = max(0, min(data.count - 1, Int(x / segW)))
                        }
                        .onEnded { _ in
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                hovered = nil
                            }
                        }
                )
            }
            .frame(height: 150)

            // X-axis labels with day / month / year
            HStack(spacing: 0) {
                Spacer().frame(width: 40)
                ForEach(xIndices, id: \.self) { idx in
                    Text(xLabel(data[idx].date))
                        .font(.system(size: 9)).foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.top, 5)
        }
        .padding(16)
        .background(Color(hex: "1C1C1E")).cornerRadius(16)
    }

    func linePoints(in size: CGSize) -> [CGPoint] {
        guard data.count > 1 else {
            return [CGPoint(x: size.width/2,
                            y: size.height - CGFloat((data.first?.volume ?? 0) / maxVol) * size.height)]
        }
        return data.enumerated().map { i, pt in
            CGPoint(
                x: CGFloat(i) / CGFloat(data.count - 1) * size.width,
                y: size.height - CGFloat(pt.volume / maxVol) * size.height
            )
        }
    }

    var xIndices: [Int] {
        guard !data.isEmpty else { return [] }
        if data.count <= 7 { return Array(0..<data.count) }
        let step = max(1, data.count / 5)
        return stride(from: 0, to: data.count, by: step).map { $0 }
    }

    // Show day/month on line 1, short year on line 2
    func xLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "d/M\n''yy"
        return f.string(from: date)
    }

    func tooltipFor(_ point: (date: Date, volume: Double)) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(point.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.system(size: 11)).foregroundColor(.gray)
                Text("\(Int(point.volume)) kg")
                    .font(.system(size: 16, weight: .bold)).foregroundColor(.white)
            }
            Spacer()
            Image(systemName: "flame.fill").foregroundColor(accent)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(Color(hex: "2C2C2C")).cornerRadius(12)
    }
}

// MARK: - Dashboard summary card
struct DashCard: View {
    let title: String; let value: String; let icon: String; let color: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(color.opacity(0.2))
                    .frame(width: 50, height: 50)
                Image(systemName: icon).font(.system(size: 22)).foregroundColor(color)
            }
            Text(value)
                .font(.system(size: 26, weight: .bold)).foregroundColor(.white)
                .lineLimit(1).minimumScaleFactor(0.55)
            Text(title).font(.system(size: 13)).foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18).background(Color(hex: "1C1C1E")).cornerRadius(18)
    }
}

// MARK: - Muscle breakdown bar row
struct MuscleBarRow: View {
    let stat: MuscleGroupStat; let maxVolume: Double
    var body: some View {
        let liveG = MuscleGroupManager.shared.liveGroup(for: stat.muscleGroup.id) ?? stat.muscleGroup
        VStack(spacing: 5) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: liveG.icon)
                        .font(.system(size: 12)).foregroundColor(liveG.color)
                    Text(liveG.rawValue)
                        .font(.system(size: 13)).foregroundColor(.white)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 1) {
                    Text("\(Int(stat.totalVolume)) kg")
                        .font(.system(size: 13, weight: .semibold)).foregroundColor(.white)
                    Text("\(stat.sessionCount) sessions")
                        .font(.system(size: 10)).foregroundColor(.gray)
                }
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4).fill(Color(hex: "2C2C2C"))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(LinearGradient(
                            colors: [liveG.color, liveG.color.opacity(0.5)],
                            startPoint: .leading, endPoint: .trailing))
                        .frame(width: maxVolume > 0
                               ? geo.size.width * CGFloat(stat.totalVolume / maxVolume) : 0)
                }
            }.frame(height: 8)
        }
    }
}

// MARK: - Insight card
struct InsightCard: View {
    let icon: String; let color: Color; let title: String; let detail: String
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).font(.system(size: 16)).foregroundColor(color)
                .frame(width: 38, height: 38)
                .background(color.opacity(0.15)).cornerRadius(10)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 14, weight: .semibold)).foregroundColor(.white)
                Text(detail).font(.system(size: 12)).foregroundColor(.gray)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14).background(Color(hex: "1C1C1E")).cornerRadius(14)
    }
}
