
//
//  ExerciseChartView.swift
//  FitMetricsLog
//
//  Full-screen chart for a single exercise — volume over time (bar or line)
//

import SwiftUI

struct ExerciseChartView: View {
    let exercise: Exercise
    @EnvironmentObject var logStore: WorkoutLogStore
    @ObservedObject private var loc = LocalizationManager.shared
    @Environment(\.dismiss) var dismiss

    @State private var isBar  = false
    @State private var range: DateRange = .all
    @State private var showFullscreen = false

    var data: [(date: Date, volume: Double)] {
        logStore.dailyVolumesForExercise(id: exercise.id, in: range)
    }
    var maxVol: Double { data.map(\.volume).max() ?? 1 }
    var minVol: Double { data.map(\.volume).min() ?? 0 }
    var totalVol: Double { data.reduce(0) { $0 + $1.volume } }
    var avgVol:   Double { data.isEmpty ? 0 : totalVol / Double(data.count) }
    var peak:     Double { maxVol }

    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "111111").ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {

                        // ── Exercise info ──
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(exercise.muscleGroup.color.opacity(0.18))
                                    .frame(width: 52, height: 52)
                                if let img = exercise.thumbnail(maxPixelSize: 200) {
                                    Image(uiImage: img).resizable().scaledToFill()
                                        .frame(width: 52, height: 52).clipped().cornerRadius(12)
                                } else {
                                    Image(systemName: exercise.muscleGroup.icon)
                                        .font(.system(size: 22))
                                        .foregroundColor(exercise.muscleGroup.color)
                                }
                            }
                            VStack(alignment: .leading, spacing: 3) {
                                Text(exercise.name)
                                    .font(.system(size: 18, weight: .bold)).foregroundColor(.white)
                                Text(MuscleGroupManager.shared.liveName(for: exercise.muscleGroup))
                                    .font(.system(size: 13)).foregroundColor(.gray)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 20).padding(.top, 8)

                        // ── Stats row ──
                        HStack(spacing: 0) {
                            chartStat("Sessions", "\(data.count)")
                            Divider().background(Color.white.opacity(0.1)).frame(height: 36)
                            chartStat("Peak", "\(Int(peak)) kg")
                            Divider().background(Color.white.opacity(0.1)).frame(height: 36)
                            chartStat("Avg/Day", "\(Int(avgVol)) kg")
                        }
                        .padding(.vertical, 12)
                        .background(Color(hex: "1C1C1E")).cornerRadius(14)
                        .padding(.horizontal, 20)

                        // ── Controls ──
                        HStack(spacing: 10) {
                            // Range picker
                            Menu {
                                ForEach(DateRange.allCases, id: \.self) { r in
                                    Button(r.rawValue) { range = r }
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Text(range.rawValue)
                                        .font(.system(size: 13, weight: .semibold)).foregroundColor(.white)
                                    Image(systemName: "chevron.down").font(.system(size: 10)).foregroundColor(.gray)
                                }
                                .padding(.horizontal, 12).padding(.vertical, 7)
                                .background(Color(hex: "2C2C2C")).cornerRadius(10)
                            }
                            Spacer()
                            // Bar / Line toggle
                            HStack(spacing: 2) {
                                chartToggle(icon: "chart.bar.fill", active: isBar)  { isBar = true  }
                                chartToggle(icon: "chart.line.uptrend.xyaxis", active: !isBar) { isBar = false }
                            }
                            .padding(3).background(Color(hex: "1C1C1E")).cornerRadius(10)
                        }
                        .padding(.horizontal, 20)

                        // ── Chart ──
                        if data.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "chart.bar.xaxis")
                                    .font(.system(size: 44)).foregroundColor(.gray.opacity(0.3))
                                Text(L(.noDataForPeriod))
                                    .font(.system(size: 14)).foregroundColor(.gray)
                            }
                            .frame(maxWidth: .infinity).frame(height: 200)
                            .background(Color(hex: "1C1C1E")).cornerRadius(14)
                            .padding(.horizontal, 20)
                        } else {
                            ExerciseVolumeChart(data: data, isBar: isBar, onFullscreen: {
                                showFullscreen = true
                            })
                                .padding(.horizontal, 20)
                        }

                        Spacer(minLength: 60)
                    }
                }
            }
            .navigationTitle(exercise.name)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing:
                Button(L(.done)) { dismiss() }.foregroundColor(.orange)
            )
            .fullScreenCover(isPresented: $showFullscreen) {
                FullscreenChartView(data: data, title: exercise.name + " Volume", isBar: isBar)
                    .modifier(LandscapeModifier())
            }
        }
        .preferredColorScheme(.dark)
    }

    func chartStat(_ label: String, _ value: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.system(size: 18, weight: .bold)).foregroundColor(.orange)
            Text(label).font(.system(size: 11)).foregroundColor(.gray)
        }.frame(maxWidth: .infinity)
    }

    func chartToggle(icon: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 13))
                .foregroundColor(active ? .black : .gray)
                .frame(width: 30, height: 28)
                .background(active ? Color.orange : Color.clear)
                .cornerRadius(7)
        }
    }
}

// MARK: - Exercise Volume Chart (with min-based y-axis)
struct ExerciseVolumeChart: View {
    let data: [(date: Date, volume: Double)]
    let isBar: Bool
    var onFullscreen: (() -> Void)? = nil

    @State private var hovered: Int? = nil
    @GestureState private var isDragging = false

    var minVol: Double { (data.map(\.volume).min() ?? 0) }
    var maxVol: Double { (data.map(\.volume).max() ?? 1) }

    func yBase() -> Double {
        let pad = (maxVol - minVol) * 0.1
        return max(0, minVol - pad)
    }
    func yTop() -> Double { maxVol + (maxVol - minVol) * 0.1 + 1 }

    func yLabels() -> [Double] {
        let lo = yBase(); let hi = yTop()
        let span = hi - lo
        guard span > 0 else { return [lo] }
        let step = span / 3
        let nice = step <= 5 ? ceil(step/1)*1
                 : step <= 10 ? ceil(step/5)*5
                 : step <= 50 ? ceil(step/10)*10
                 : step <= 200 ? ceil(step/50)*50
                 : ceil(step/100)*100
        let base = floor(lo / nice) * nice
        return stride(from: base, through: hi, by: nice).map { $0 }
    }

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

    func xPos(index: Int, width: CGFloat) -> CGFloat {
        guard data.count > 1 else { return width / 2 }
        return CGFloat(index) / CGFloat(data.count - 1) * (width - 8) + 4
    }

    func yPos(volume: Double, height: CGFloat) -> CGFloat {
        let lo = yBase(); let span = yTop() - lo
        return (height - 4) * CGFloat(1 - (volume - lo) / span) + 2
    }

    func nearestIndex(x: CGFloat, width: CGFloat) -> Int {
        guard data.count > 1 else { return 0 }
        let segW = (width - 8) / CGFloat(data.count - 1)
        return max(0, min(data.count - 1, Int(((x - 4) / segW).rounded())))
    }

    var body: some View {
        let ylbls = yLabels()
        let xlbls = xLabels()
        let lo    = yBase()
        let hi    = yTop()
        let ySpan = hi - lo
        let yLW: CGFloat = 44
        let xLH: CGFloat = 18

        VStack(spacing: 0) {
            HStack(alignment: .bottom, spacing: 0) {
                // Y labels
                VStack(alignment: .trailing, spacing: 0) {
                    ForEach(ylbls.reversed(), id: \.self) { v in
                        Text(v >= 1000 ? String(format: "%.0fk", v/1000) : "\(Int(v))")
                            .font(.system(size: 9)).foregroundColor(.gray)
                            .frame(maxHeight: .infinity, alignment: .center)
                    }
                }
                .frame(width: yLW, height: 200)

                // Chart
                GeometryReader { geo in
                    let w = geo.size.width
                    let h = geo.size.height
                    ZStack {
                        Color(hex: "1C1C1E")
                        // Grid lines
                        ForEach(ylbls, id: \.self) { v in
                            let y = h * CGFloat(1 - (v - lo) / ySpan)
                            Path { p in p.move(to: .init(x: 0, y: y)); p.addLine(to: .init(x: w, y: y)) }
                                .stroke(Color.white.opacity(0.07), lineWidth: 0.5)
                        }

                        if isBar {
                            // ── Bar chart ──
                            let bw = max(3, (w - 8) / CGFloat(max(data.count, 1)) - 2)
                            HStack(alignment: .bottom, spacing: 2) {
                                ForEach(Array(data.enumerated()), id: \.offset) { idx, pt in
                                    let bh = max(3, (h - 4) * CGFloat((pt.volume - lo) / ySpan))
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(hovered == idx ? Color.orange : Color.orange.opacity(0.8))
                                        .frame(width: bw, height: bh)
                                }
                            }
                            .padding(.horizontal, 4).padding(.bottom, 2)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                        } else {
                            // ── Line chart ──
                            let pts: [CGPoint] = data.enumerated().map { i, pt in
                                CGPoint(x: xPos(index: i, width: w), y: yPos(volume: pt.volume, height: h))
                            }
                            // Fill
                            Path { path in
                                guard let f = pts.first, let l = pts.last else { return }
                                path.move(to: .init(x: f.x, y: h))
                                path.addLine(to: f)
                                pts.dropFirst().forEach { path.addLine(to: $0) }
                                path.addLine(to: .init(x: l.x, y: h))
                            }
                            .fill(LinearGradient(colors: [Color.orange.opacity(0.3), .clear],
                                                  startPoint: .top, endPoint: .bottom))
                            // Line
                            Path { path in
                                for (i, pt) in pts.enumerated() {
                                    if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
                                }
                            }
                            .stroke(Color.orange, style: .init(lineWidth: 2, lineCap: .round, lineJoin: .round))
                        }

                        // ── Hover indicator ──
                        if let idx = hovered, idx < data.count {
                            let dp = data[idx]
                            let xP = xPos(index: idx, width: w)
                            let yP: CGFloat = {
                                if isBar {
                                    let bh = max(3, (h - 4) * CGFloat((dp.volume - lo) / ySpan))
                                    return h - bh - 2
                                } else {
                                    return yPos(volume: dp.volume, height: h)
                                }
                            }()

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
                                .frame(width: 20, height: 20)
                                .position(x: xP, y: yP)
                            // Inner dot
                            Circle()
                                .fill(Color.orange)
                                .frame(width: 9, height: 9)
                                .position(x: xP, y: yP)

                            // Floating tooltip card
                            let tooltipW: CGFloat = 120
                            let tooltipX = min(max(tooltipW/2 + 4, xP), w - tooltipW/2 - 4)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Volume")
                                    .font(.system(size: 9)).foregroundColor(.gray)
                                Text(dp.volume >= 1000 ? String(format: "%.1fk", dp.volume/1000) : "\(Int(dp.volume)) kg")
                                    .font(.system(size: 20, weight: .black)).foregroundColor(.white)
                                Divider().background(Color.white.opacity(0.15))
                                Text(fullDateFormatter.string(from: dp.date))
                                    .font(.system(size: 9)).foregroundColor(.gray)
                            }
                            .padding(.horizontal, 12).padding(.vertical, 10)
                            .frame(width: tooltipW)
                            .background(Color(hex: "1A1A1A"))
                            .cornerRadius(12)
                            .shadow(color: .black.opacity(0.5), radius: 10, y: 4)
                            .position(x: tooltipX, y: max(48, yP - 60))
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
                .frame(height: 200)
                .onChange(of: isBar) { _ in hovered = nil }
            }
            // X labels
            HStack(alignment: .top, spacing: 0) {
                Spacer().frame(width: yLW)
                GeometryReader { geo in
                    let w = geo.size.width
                    ZStack(alignment: .topLeading) {
                        ForEach(xlbls, id: \.0) { idx, date in
                            let x = data.count > 1
                                ? CGFloat(idx)/CGFloat(data.count-1)*(w-8)+4 : w/2
                            Text(dateFormatter.string(from: date))
                                .font(.system(size: 9)).foregroundColor(.gray)
                                .fixedSize().position(x: x, y: 8)
                        }
                    }
                }
                .frame(height: xLH)
            }

            // Fullscreen button
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
