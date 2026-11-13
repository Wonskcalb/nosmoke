import SwiftUI
import Combine

struct SOSView: View {
    @EnvironmentObject var store: Store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var running = false
    @State private var finished = false
    @State private var started = Date()
    @State private var left = 600
    @State private var level = 3
    @State private var shrink = 1.0
    @State private var phase = "Inspire 4 s · expire 6 s"

    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private let ideas: [(String, String)] = [
        ("drop", "Un verre d'eau"), ("figure.walk", "Marcher un peu"),
        ("mouth", "Se brosser les dents"), ("hand.raised", "Occuper ses mains"),
    ]

    private var recent: Craving? {
        guard let c = store.s.cravings.last, Date.now.timeIntervalSince(c.date) < 1800 else { return nil }
        return c
    }

    private var subtitle: String {
        guard let c = recent else { return "Une envie passe en quelques minutes. On la laisse passer ensemble." }
        let hm = c.date.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
        return "Une envie \(intensityLabels[min(max(c.intensity - 1, 0), 4)].lowercased()), notée à \(hm). On la laisse passer ensemble."
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Respirer").font(Jardin.serif(34)).padding(.top, 6)
                Text(subtitle).font(Jardin.sans(15)).foregroundStyle(Jardin.muted).lineSpacing(3).padding(.top, 8)
                breath.frame(maxWidth: .infinity).padding(.top, 20)
                Text(String(format: "%02d:%02d", left / 60, left % 60))
                    .font(Jardin.serif(56)).monospacedDigit()
                    .frame(maxWidth: .infinity).padding(.top, 14)
                Text(phase).font(Jardin.sans(14)).foregroundStyle(Jardin.muted)
                    .frame(maxWidth: .infinity).padding(.top, 8)
                Button(running ? "J'ai fini" : "Lancer 10 minutes") { running ? stop() : start() }
                    .buttonStyle(PrimaryButtonStyle())
                    .frame(maxWidth: .infinity).padding(.top, 18)
                Text("En attendant, une idée").font(Jardin.sans(13, weight: .semibold)).foregroundStyle(Jardin.muted).padding(.top, 24)
                VStack(spacing: 0) {
                    ForEach(Array(ideas.enumerated()), id: \.offset) { i, idea in
                        HStack(spacing: 14) {
                            Image(systemName: idea.0).font(.system(size: 18)).frame(width: 22).foregroundStyle(Jardin.ink)
                            Text(idea.1).font(Jardin.sans(15)).foregroundStyle(Jardin.ink)
                            Spacer()
                        }
                        .padding(.vertical, 11)
                        .overlay(alignment: .top) { if i > 0 { Rectangle().fill(Jardin.line).frame(height: 1) } }
                    }
                }
                .padding(.top, 6)
                HStack {
                    Button("Prendre un comprimé") { store.s.tablets.append(.now); store.tab = 0 }
                    Spacer()
                    Button("Noter cette envie") { store.tab = 2 }
                }
                .font(Jardin.sans(15, weight: .medium)).foregroundStyle(Jardin.terra)
                .padding(.top, 18)
            }
            .padding(.horizontal, 24).padding(.bottom, 32)
        }
        .screenBackground()
        .onAppear { level = recent.map { min(max($0.intensity - 1, 0), 4) } ?? 3 }
        .onReceive(tick) { _ in
            guard running else { return }
            left -= 1
            let t = 600 - left
            phase = t % 10 < 4 ? "Inspire…" : "Expire…"
            if t % 10 == 0 {
                withAnimation(.easeInOut(duration: 0.6)) { shrink = max(0.45, shrink * 0.85) }
                if level > 0 { level -= 1 }
            }
            if left <= 0 { stop() }
        }
    }

    private var breath: some View {
        TimelineView(.animation(paused: !running || reduceMotion)) { tl in
            let p = running && !reduceMotion ? tl.date.timeIntervalSince(started).truncatingRemainder(dividingBy: 10) / 10 : 0
            let w = p < 0.4 ? ease(p / 0.4) : 1 - ease((p - 0.4) / 0.6)
            let guide = running && !reduceMotion ? 0.8 + 0.2 * w : 0.86
            let cloud = running && !reduceMotion ? 0.9 + 0.22 * w : 1.0
            ZStack {
                Circle().stroke(Jardin.line, lineWidth: 1.5).frame(width: 240, height: 240)
                Circle().stroke(Jardin.terra, lineWidth: 2).frame(width: 236, height: 236).scaleEffect(guide)
                CravingCloud(level: level)
                    .frame(width: 132)
                    .scaleEffect(cloud)
                    .scaleEffect(finished ? shrink * 0.6 : shrink)
                    .offset(y: finished ? -150 : 0)
                    .opacity(finished ? 0 : 1)
                    .animation(reduceMotion ? .easeIn(duration: 1.4) : .timingCurve(0.5, 0, 0.75, 0, duration: 1.4), value: finished)
                Text("+1 envie traversée").font(Jardin.serif(22, weight: .regular)).foregroundStyle(Jardin.terra)
                    .opacity(finished ? 1 : 0)
                    .animation(.easeOut(duration: 0.6).delay(0.8), value: finished)
            }
            .frame(width: 244, height: 244)
        }
    }

    private func ease(_ x: Double) -> Double { x * x * (3 - 2 * x) }

    private func start() {
        left = 600; shrink = 1; finished = false
        level = recent.map { min(max($0.intensity - 1, 0), 4) } ?? 3
        started = .now; phase = "Inspire…"; running = true
    }

    private func stop() {
        running = false; level = 0; finished = true
        phase = "Bien joué · elle est passée"
    }
}
