//
//  AgentBadgeArtExtra.swift
//  Chelka
//
//  Дополнительные варианты анимаций (Settings → Animations): индикатор работы, правая сторона,
//  эффект завершения и виды обложки. Как и в AgentBadgeArt, кадр определяется только временем и состоянием.
//

import AppKit
import SwiftUI

/// Палитра «северного сияния» для цветных вариантов
private let auroraColors: [Color] = [
    Color(red: 0.55, green: 0.40, blue: 1.00), Color(red: 0.25, green: 0.80, blue: 1.00),
    Color(red: 0.35, green: 1.00, blue: 0.75), Color(red: 1.00, green: 0.45, blue: 0.80),
    Color(red: 0.55, green: 0.40, blue: 1.00),
]

/// Детерминированное псевдослучайное число 0...1 (одинаковое в каждом кадре для одного и того же seed)
private func noise(_ seed: Int) -> Double {
    var x = UInt64(truncatingIfNeeded: seed &* 2654435761 &+ 12345)
    x ^= x >> 13; x = x &* 0x5bd1e995; x ^= x >> 15
    return Double(x % 10_000) / 10_000
}

extension AgentBadgeArt {

    // MARK: - Индикатор работы: «Аврора» — переливающееся цветное кольцо

    struct RunningAurora: View {
        let t: Double
        let size: CGFloat
        let tint: Color
        var ripple: Double? = nil

        var body: some View {
            let lw = AgentBadgeArt.lineWidth(size) * 1.25
            let ring = size * AgentBadgeArt.ringScale
            let spin = Angle.degrees((t * 110).truncatingRemainder(dividingBy: 360))
            let breathe = (sin(t * 2 * .pi / 2.0) + 1) / 2
            Frame(size: size) {
                // размытая копия кольца даёт цветное свечение
                Circle()
                    .stroke(AngularGradient(colors: auroraColors, center: .center), lineWidth: lw * 2.2)
                    .frame(width: ring, height: ring)
                    .rotationEffect(spin)
                    .blur(radius: lw * 1.4)
                    .opacity(0.45 + 0.35 * breathe)
                Circle()
                    .stroke(AngularGradient(colors: auroraColors, center: .center), lineWidth: lw)
                    .frame(width: ring, height: ring)
                    .rotationEffect(spin)
                SparkleShape()
                    .fill(AngularGradient(colors: auroraColors, center: .center))
                    .frame(width: size * (0.48 + 0.08 * breathe), height: size * (0.48 + 0.08 * breathe))
                    .rotationEffect(-spin * 0.5)
                    .overlay(SparkleShape().fill(Color.white.opacity(0.55)).frame(width: size * 0.22, height: size * 0.22))
                    .shadow(color: auroraColors[1].opacity(0.6), radius: size * 0.16)
                if let p = ripple, p < 1 {
                    AgentBadgeArt.rippleRing(p, ring: ring, lw: lw, tint: auroraColors[2], strength: 0.6)
                }
            }
        }
    }

    // MARK: - Индикатор работы: «Галактика» — частицы закручиваются к звёздочке

    struct RunningGalaxy: View {
        let t: Double
        let size: CGFloat
        let tint: Color
        var ripple: Double? = nil

        var body: some View {
            let lw = AgentBadgeArt.lineWidth(size)
            let ring = size * AgentBadgeArt.ringScale
            let twinkle = (sin(t * 2 * .pi / 1.5) + 1) / 2
            Frame(size: size) {
                Circle().stroke(tint.opacity(0.10), lineWidth: lw * 0.8).frame(width: ring, height: ring)
                Canvas { ctx, sz in
                    let c = CGPoint(x: sz.width / 2, y: sz.height / 2)
                    let maxR = ring / 2 - lw
                    for i in 0..<18 {
                        // каждая частица движется от края к центру по спирали и рождается заново
                        let life = (t * 0.45 + Double(i) / 18).truncatingRemainder(dividingBy: 1)
                        let r = maxR * (1 - life)
                        let a = Double(i) * 2.4 + life * 4.5 + t * 0.8
                        let p = CGPoint(x: c.x + r * cos(a), y: c.y + r * sin(a))
                        let d = lw * (0.35 + 0.65 * (1 - life))
                        let alpha = min(1, life * 4) * (1 - life * 0.7)
                        ctx.fill(Path(ellipseIn: CGRect(x: p.x - d, y: p.y - d, width: d * 2, height: d * 2)),
                                 with: .color(tint.opacity(alpha)))
                    }
                }
                .frame(width: ring, height: ring)
                SparkleShape()
                    .fill(tint)
                    .frame(width: size * (0.36 + 0.08 * twinkle), height: size * (0.36 + 0.08 * twinkle))
                    .rotationEffect(.degrees(t * 40))
                    .shadow(color: tint.opacity(0.5 + 0.4 * twinkle), radius: size * 0.18)
                if let p = ripple, p < 1 {
                    AgentBadgeArt.rippleRing(p, ring: ring, lw: lw, tint: tint, strength: 0.55)
                }
            }
        }
    }

    // MARK: - Правая сторона: «Волна» — несколько переплетающихся волн (как у Siri)

    struct Wave: View {
        let t: Double
        let tint: Color

        /// Параметры волн: частота, скорость, амплитуда, сдвиг фазы, яркость, толщина
        private static let layers: [(freq: Double, speed: Double, amp: Double, phase: Double, alpha: Double, width: CGFloat)] = [
            (8.5, 5.2, 0.95, 0.0, 1.00, 1.5),
            (11.0, -3.8, 0.70, 1.9, 0.55, 1.2),
            (6.0, 2.9, 0.55, 3.7, 0.35, 1.0),
        ]

        var body: some View {
            Canvas { ctx, sz in
                let mid = sz.height / 2
                // общая «громкость»: волны то нарастают, то стихают
                let swell = 0.75 + 0.25 * sin(t * 2.1)
                for (k, layer) in Self.layers.enumerated().reversed() {
                    var path = Path()
                    let n = 54
                    for i in 0...n {
                        let u = Double(i) / Double(n)
                        let env = pow(sin(u * .pi), 1.4)          // к краям волна затухает
                        let wobble = 1 + 0.25 * sin(t * (1.3 + Double(k) * 0.7) + Double(k))
                        let y = mid - CGFloat(env * swell * wobble * layer.amp
                                              * sin(u * layer.freq - t * layer.speed + layer.phase)) * sz.height * 0.42
                        let p = CGPoint(x: CGFloat(u) * sz.width, y: y)
                        i == 0 ? path.move(to: p) : path.addLine(to: p)
                    }
                    ctx.stroke(path,
                               with: .linearGradient(Gradient(colors: [tint.opacity(0.0), tint.opacity(layer.alpha), tint.opacity(0.0)]),
                                                     startPoint: .zero, endPoint: CGPoint(x: sz.width, y: 0)),
                               style: StrokeStyle(lineWidth: layer.width, lineCap: .round, lineJoin: .round))
                }
            }
            .frame(width: 38, height: 18)
        }
    }

    // MARK: - Правая сторона: «Дождь» — падающие капли в стиле «Матрицы»

    struct Rain: View {
        let t: Double
        let tint: Color

        var body: some View {
            Canvas { ctx, sz in
                let cols = 6
                for c in 0..<cols {
                    let x = (CGFloat(c) + 0.5) * sz.width / CGFloat(cols)
                    let speed = 0.7 + noise(c * 13) * 0.8
                    let head = ((t * speed + noise(c * 5)) .truncatingRemainder(dividingBy: 1.4)) / 1.0 * (sz.height + 10) - 4
                    for k in 0..<4 {   // голова и затухающий хвост
                        let y = head - CGFloat(k) * 3.6
                        guard y > -2, y < sz.height + 2 else { continue }
                        let a = (k == 0 ? 1.0 : 0.75 - Double(k) * 0.16)
                        ctx.fill(Path(roundedRect: CGRect(x: x - 1, y: y - 1.3, width: 2, height: 2.6), cornerRadius: 1),
                                 with: .color(tint.opacity(a)))
                    }
                }
            }
            .frame(width: 36, height: 18)
            .mask(LinearGradient(colors: [.clear, .black, .black, .clear], startPoint: .top, endPoint: .bottom))
        }
    }

    // MARK: - Правая сторона: «Блик» — полоска с бегущим светом

    struct Shimmer: View {
        let t: Double
        let tint: Color

        var body: some View {
            let p = (t / 1.3).truncatingRemainder(dividingBy: 1)
            ZStack(alignment: .leading) {
                Capsule().fill(tint.opacity(0.14))
                Capsule()
                    .fill(LinearGradient(gradient: Gradient(stops: [
                        .init(color: tint.opacity(0), location: max(0, p - 0.35)),
                        .init(color: tint.opacity(0.95), location: p),
                        .init(color: tint.opacity(0), location: min(1, p + 0.12)),
                    ]), startPoint: .leading, endPoint: .trailing))
            }
            .frame(width: 36, height: 4.5)
        }
    }

    // MARK: - Завершение: «Конфетти»

    struct DoneConfetti: View, Animatable {
        var progress: Double
        let size: CGFloat
        let tint: Color
        var animatableData: Double {
            get { progress }
            set { progress = newValue }
        }

        var body: some View {
            let ring = size * AgentBadgeArt.ringScale
            let burst = min(1, progress * 1.15)
            let eased = 1 - pow(1 - burst, 3)
            let palette: [Color] = [tint, auroraColors[0], auroraColors[1], auroraColors[3], Color(red: 1, green: 0.85, blue: 0.3)]
            ZStack {
                AgentBadgeArt.Done(progress: min(1, progress * 1.6), size: size, tint: tint)
                Frame(size: size) {
                    Canvas { ctx, sz in
                        let c = CGPoint(x: sz.width / 2, y: sz.height / 2)
                        for i in 0..<20 {
                            let a = Double(i) / 20 * 2 * .pi + noise(i) * 0.5
                            let dist = (ring * 0.35) + (sz.width / 2 - ring * 0.35) * CGFloat(eased) * (0.75 + 0.25 * noise(i + 40))
                            let p = CGPoint(x: c.x + dist * cos(a), y: c.y + dist * sin(a) + CGFloat(burst * burst) * 2)
                            let alpha = burst < 1 ? 1 - burst * burst : 0
                            var piece = Path(roundedRect: CGRect(x: -2.2, y: -1.1, width: 4.4, height: 2.2), cornerRadius: 0.8)
                            piece = piece.applying(CGAffineTransform(rotationAngle: a + burst * 6).concatenating(CGAffineTransform(translationX: p.x, y: p.y)))
                            ctx.fill(piece, with: .color(palette[i % palette.count].opacity(alpha)))
                        }
                    }
                    .frame(width: size * AgentBadgeArt.reach, height: size * AgentBadgeArt.reach)
                }
            }
        }
    }

    // MARK: - Завершение: «Вспышка» — галочка выпрыгивает, расходятся лучи

    struct DoneStarburst: View, Animatable {
        var progress: Double
        let size: CGFloat
        let tint: Color
        var animatableData: Double {
            get { progress }
            set { progress = newValue }
        }

        var body: some View {
            let ring = size * AgentBadgeArt.ringScale
            let lw = AgentBadgeArt.lineWidth(size)
            // пружинистое появление: перелёт до 1.18 и возврат к 1
            let pop = progress < 0.55 ? progress / 0.55 * 1.18 : 1.18 - 0.18 * min(1, (progress - 0.55) / 0.45)
            ZStack {
                AgentBadgeArt.Done(progress: min(1, progress * 1.3), size: size, tint: tint)
                    .scaleEffect(pop)
                Frame(size: size) {
                    Canvas { ctx, sz in
                        let c = CGPoint(x: sz.width / 2, y: sz.height / 2)
                        let rays = 8
                        let r0 = ring * 0.42 + CGFloat(progress) * ring * 0.18
                        let len = lw * 2.2 * CGFloat(1 - progress)
                        for i in 0..<rays {
                            let a = Double(i) / Double(rays) * 2 * .pi
                            var ray = Path()
                            ray.move(to: CGPoint(x: c.x + r0 * cos(a), y: c.y + r0 * sin(a)))
                            ray.addLine(to: CGPoint(x: c.x + (r0 + len) * cos(a), y: c.y + (r0 + len) * sin(a)))
                            ctx.stroke(ray, with: .color(tint.opacity(1 - progress)), style: StrokeStyle(lineWidth: lw, lineCap: .round))
                        }
                    }
                    .frame(width: size * AgentBadgeArt.reach, height: size * AgentBadgeArt.reach)
                }
            }
        }
    }
}

// MARK: - Обложки

/// «Бит»: круглая обложка пульсирует в такт и пускает волны
struct BeatCover: View {
    let image: NSImage
    let size: CGFloat
    let isPlaying: Bool

    var body: some View {
        let outer = size + 7
        TimelineView(.animation(paused: !isPlaying)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let phase = (t * 1.9).truncatingRemainder(dividingBy: 1)     // ~114 ударов в минуту
            let beat = isPlaying ? pow(max(0, cos(phase * 2 * .pi)), 6) : 0
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(isPlaying ? (1 - phase) * 0.5 : 0), lineWidth: 1)
                    .frame(width: size, height: size)
                    .scaleEffect(1 + 0.32 * phase)
                Image(nsImage: image)
                    .resizable().scaledToFill()
                    .frame(width: size + 1, height: size + 1)
                    .clipShape(Circle())
                    .scaleEffect(1 + 0.07 * beat)
                Circle().stroke(Color.white.opacity(0.25), lineWidth: 1).frame(width: size + 2, height: size + 2)
            }
            .frame(width: outer, height: outer)
        }
    }
}

/// «Круговой эквалайзер»: вокруг круглой обложки пульсируют короткие лучи
struct RadialCover: View {
    let image: NSImage
    let size: CGFloat
    let isPlaying: Bool

    var body: some View {
        let outer = size + 7
        let core = size - 3
        TimelineView(.animation(paused: !isPlaying)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            ZStack {
                Canvas { ctx, sz in
                    let c = CGPoint(x: sz.width / 2, y: sz.height / 2)
                    let bars = 18
                    let r0 = core / 2 + 1.2
                    let maxLen = outer / 2 - r0 - 0.3
                    for i in 0..<bars {
                        let a = Double(i) / Double(bars) * 2 * .pi - .pi / 2
                        let level = isPlaying
                            ? 0.25 + 0.75 * (0.5 + 0.5 * sin(t * (4 + noise(i) * 5) + Double(i)))
                            : 0.2
                        var bar = Path()
                        bar.move(to: CGPoint(x: c.x + r0 * cos(a), y: c.y + r0 * sin(a)))
                        bar.addLine(to: CGPoint(x: c.x + (r0 + maxLen * CGFloat(level)) * cos(a), y: c.y + (r0 + maxLen * CGFloat(level)) * sin(a)))
                        ctx.stroke(bar, with: .color(.white.opacity(0.75)), style: StrokeStyle(lineWidth: 1.1, lineCap: .round))
                    }
                }
                .frame(width: outer, height: outer)
                Image(nsImage: image)
                    .resizable().scaledToFill()
                    .frame(width: core, height: core)
                    .clipShape(Circle())
            }
            .frame(width: outer, height: outer)
        }
    }
}

/// «Радужный диск»: вращающаяся круглая обложка с переливающимся ободком
struct RainbowDisc: View {
    let image: NSImage
    let size: CGFloat
    let isPlaying: Bool

    var body: some View {
        let outer = size + 7
        TimelineView(.animation(paused: !isPlaying)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let spin = isPlaying ? Angle.degrees((t * 45).truncatingRemainder(dividingBy: 360)) : .zero
            ZStack {
                Circle()
                    .stroke(AngularGradient(colors: auroraColors, center: .center), lineWidth: 1.8)
                    .frame(width: size + 4, height: size + 4)
                    .rotationEffect(-spin * 2)
                    .shadow(color: auroraColors[1].opacity(0.6), radius: 2.5)
                Image(nsImage: image)
                    .resizable().scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
                    .overlay(Circle().fill(Color.black).frame(width: size * 0.2, height: size * 0.2))
                    .rotationEffect(spin)
            }
            .frame(width: outer, height: outer)
        }
    }
}

// MARK: - Новые индикаторы работы, правые стороны и эффекты завершения

extension AgentBadgeArt {

    // MARK: Индикатор работы: «Атом» — три электрона на наклонённых орбитах вокруг ядра

    struct RunningAtom: View {
        let t: Double
        let size: CGFloat
        let tint: Color
        var ripple: Double? = nil

        var body: some View {
            let lw = AgentBadgeArt.lineWidth(size)
            let ring = size * AgentBadgeArt.ringScale
            let beat = (sin(t * 2 * .pi / 1.4) + 1) / 2
            Frame(size: size) {
                Canvas { ctx, sz in
                    let c = CGPoint(x: sz.width / 2, y: sz.height / 2)
                    let rx = ring * 0.44, ry = ring * 0.16
                    for k in 0..<3 {
                        var layer = ctx
                        layer.translateBy(x: c.x, y: c.y)
                        layer.rotate(by: .radians(Double(k) * .pi / 3 + t * 0.3))
                        layer.stroke(Path(ellipseIn: CGRect(x: -rx, y: -ry, width: rx * 2, height: ry * 2)),
                                     with: .color(tint.opacity(0.3)), lineWidth: lw * 0.5)
                        // электрон с коротким хвостом
                        for tail in 0..<4 {
                            let a = t * (2.3 + 0.55 * Double(k)) + Double(k) * 2.1 - Double(tail) * 0.18
                            let e = CGPoint(x: rx * cos(a), y: ry * sin(a))
                            let r = lw * (0.95 - Double(tail) * 0.18)
                            layer.fill(Path(ellipseIn: CGRect(x: e.x - r, y: e.y - r, width: r * 2, height: r * 2)),
                                       with: .color(tint.opacity(1 - Double(tail) * 0.26)))
                        }
                    }
                    let core = lw * (1.2 + 0.4 * beat)
                    ctx.fill(Path(ellipseIn: CGRect(x: c.x - core * 2, y: c.y - core * 2, width: core * 4, height: core * 4)),
                             with: .radialGradient(Gradient(colors: [tint.opacity(0.45), .clear]), center: c, startRadius: 0, endRadius: core * 2))
                    ctx.fill(Path(ellipseIn: CGRect(x: c.x - core, y: c.y - core, width: core * 2, height: core * 2)), with: .color(tint))
                }
                .frame(width: ring, height: ring)
                if let p = ripple, p < 1 {
                    AgentBadgeArt.rippleRing(p, ring: ring, lw: lw, tint: tint, strength: 0.55)
                }
            }
        }
    }

    // MARK: Индикатор работы: «Нейросеть» — узлы соединены связями, по которым бегут импульсы

    struct RunningNeural: View {
        let t: Double
        let size: CGFloat
        let tint: Color
        var ripple: Double? = nil

        var body: some View {
            let lw = AgentBadgeArt.lineWidth(size)
            let ring = size * AgentBadgeArt.ringScale
            Frame(size: size) {
                Canvas { ctx, sz in
                    let c = CGPoint(x: sz.width / 2, y: sz.height / 2)
                    let radius = ring * 0.34
                    var nodes: [CGPoint] = [c]
                    for k in 0..<6 {
                        let a = Double(k) * .pi / 3 + .pi / 6 + sin(t * 0.7 + Double(k)) * 0.08
                        nodes.append(CGPoint(x: c.x + radius * cos(a), y: c.y + radius * sin(a)))
                    }
                    // связи: спицы от центра и кольцо между соседями
                    var edges: [(Int, Int)] = (1...6).map { (0, $0) }
                    edges += (1...6).map { ($0, $0 % 6 + 1) }
                    for (a, b) in edges {
                        var line = Path()
                        line.move(to: nodes[a]); line.addLine(to: nodes[b])
                        ctx.stroke(line, with: .color(tint.opacity(0.24)), lineWidth: lw * 0.4)
                    }
                    // импульсы бегут по связям
                    for (i, edge) in edges.enumerated() {
                        let phase = (t * 0.85 + Double(i) * 0.173).truncatingRemainder(dividingBy: 1)
                        let from = nodes[edge.0], to = nodes[edge.1]
                        let p = CGPoint(x: from.x + (to.x - from.x) * phase, y: from.y + (to.y - from.y) * phase)
                        let r = lw * 0.55
                        ctx.fill(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)),
                                 with: .color(tint.opacity(sin(phase * .pi))))
                    }
                    for (i, node) in nodes.enumerated() {
                        let glow = 0.55 + 0.45 * sin(t * 2.2 + Double(i) * 1.3)
                        let r = lw * (i == 0 ? 1.25 : 0.9)
                        ctx.fill(Path(ellipseIn: CGRect(x: node.x - r, y: node.y - r, width: r * 2, height: r * 2)),
                                 with: .color(tint.opacity(glow)))
                    }
                }
                .frame(width: ring, height: ring)
                if let p = ripple, p < 1 {
                    AgentBadgeArt.rippleRing(p, ring: ring, lw: lw, tint: tint, strength: 0.55)
                }
            }
        }
    }

    // MARK: Индикатор работы: «ДНК» — вращающаяся двойная спираль с перекладинами

    struct RunningHelix: View {
        let t: Double
        let size: CGFloat
        let tint: Color
        var ripple: Double? = nil

        var body: some View {
            let lw = AgentBadgeArt.lineWidth(size)
            let ring = size * AgentBadgeArt.ringScale
            Frame(size: size) {
                Canvas { ctx, sz in
                    let c = CGPoint(x: sz.width / 2, y: sz.height / 2)
                    let amp = ring * 0.2
                    let half = ring * 0.42
                    // перекладины
                    var y = -half
                    while y <= half {
                        let phase = Double(y) * 0.48 + t * 2.6
                        let x1 = c.x + amp * CGFloat(sin(phase)), x2 = c.x - amp * CGFloat(sin(phase))
                        var rung = Path()
                        rung.move(to: CGPoint(x: x1, y: c.y + y)); rung.addLine(to: CGPoint(x: x2, y: c.y + y))
                        ctx.stroke(rung, with: .color(tint.opacity(0.22)), lineWidth: lw * 0.4)
                        y += ring * 0.1
                    }
                    // две нити точками: ближняя к зрителю ярче и крупнее
                    for strand in 0..<2 {
                        let shift = Double(strand) * .pi
                        var yy = -half
                        while yy <= half {
                            let phase = Double(yy) * 0.48 + t * 2.6 + shift
                            let depth = (cos(phase) + 1) / 2
                            let r = lw * (0.4 + 0.5 * depth)
                            let x = c.x + amp * CGFloat(sin(phase))
                            ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: c.y + yy - r, width: r * 2, height: r * 2)),
                                     with: .color(tint.opacity(0.35 + 0.65 * depth)))
                            yy += ring * 0.035
                        }
                    }
                }
                .frame(width: ring, height: ring)
                if let p = ripple, p < 1 {
                    AgentBadgeArt.rippleRing(p, ring: ring, lw: lw, tint: tint, strength: 0.55)
                }
            }
        }
    }

    // MARK: Индикатор работы: «Пиксельный загрузчик» — сетка 3×3, по ободу бежит огонёк

    struct RunningPixel: View {
        let t: Double
        let size: CGFloat
        let tint: Color
        var ripple: Double? = nil

        var body: some View {
            let lw = AgentBadgeArt.lineWidth(size)
            let ring = size * AgentBadgeArt.ringScale
            Frame(size: size) {
                Canvas { ctx, sz in
                    let c = CGPoint(x: sz.width / 2, y: sz.height / 2)
                    let cell = ring * 0.2, gap = ring * 0.04
                    let step = cell + gap
                    // 8 внешних клеток по часовой стрелке
                    let order: [(Int, Int)] = [(-1, -1), (0, -1), (1, -1), (1, 0), (1, 1), (0, 1), (-1, 1), (-1, 0)]
                    let head = t * 9
                    for (i, pos) in order.enumerated() {
                        let behind = (head - Double(i)).truncatingRemainder(dividingBy: 8)
                        let d = behind < 0 ? behind + 8 : behind
                        let alpha = max(0.14, 1 - d * 0.22)
                        let rect = CGRect(x: c.x + CGFloat(pos.0) * step - cell / 2, y: c.y + CGFloat(pos.1) * step - cell / 2, width: cell, height: cell)
                        ctx.fill(Path(roundedRect: rect, cornerRadius: cell * 0.18), with: .color(tint.opacity(alpha)))
                    }
                    let pulse = 0.5 + 0.5 * sin(t * 3)
                    let rect = CGRect(x: c.x - cell / 2, y: c.y - cell / 2, width: cell, height: cell)
                    ctx.fill(Path(roundedRect: rect, cornerRadius: cell * 0.18), with: .color(tint.opacity(0.35 + 0.6 * pulse)))
                }
                .frame(width: ring, height: ring)
                if let p = ripple, p < 1 {
                    AgentBadgeArt.rippleRing(p, ring: ring, lw: lw, tint: tint, strength: 0.55)
                }
            }
        }
    }

    // MARK: Правая сторона: «Печатает код» — строки появляются кусочками, мигает курсор

    struct TypingCode: View {
        let t: Double
        let tint: Color

        var body: some View {
            Canvas { ctx, sz in
                let lines: [[CGFloat]] = [[5, 3, 7], [3, 9], [6, 4, 3]]
                let indent: [CGFloat] = [0, 4, 0]
                let cycle = 6.4
                let local = t.truncatingRemainder(dividingBy: cycle)
                let fade = local > 5.6 ? max(0, 1 - (local - 5.6) / 0.8) : 1
                let lineHeight: CGFloat = 3, spacing: CGFloat = 3.2
                let top = (sz.height - (3 * lineHeight + 2 * spacing)) / 2
                var cursor: CGPoint?
                for (row, segments) in lines.enumerated() {
                    let started = Double(row) * 1.5
                    let progress = CGFloat(min(1, max(0, (local - started) / 1.3)))
                    let total = segments.reduce(0, +) + CGFloat(segments.count - 1) * 1.6
                    var visible = total * progress
                    var x = indent[row]
                    let y = top + CGFloat(row) * (lineHeight + spacing)
                    for (i, width) in segments.enumerated() {
                        guard visible > 0 else { break }
                        let w = min(width, visible)
                        let color = i == 0 ? tint : tint.opacity(0.55 + 0.1 * Double(i))
                        ctx.fill(Path(roundedRect: CGRect(x: x, y: y, width: w, height: lineHeight), cornerRadius: 1.2),
                                 with: .color(color.opacity(fade)))
                        x += width + 1.6
                        visible -= width + 1.6
                    }
                    if progress > 0 && progress < 1 || (row == 2 && progress >= 1) {
                        cursor = CGPoint(x: min(x - (visible < 0 ? 1.6 + (-visible) - 1.6 : 0), indent[row] + total) + 1.2, y: y)
                    }
                }
                if let cursor, Int(t * 2.4) % 2 == 0 {
                    ctx.fill(Path(CGRect(x: cursor.x, y: cursor.y - 0.5, width: 1.6, height: lineHeight + 1)), with: .color(tint.opacity(fade)))
                }
            }
            .frame(width: 30, height: 17)
        }
    }

    // MARK: Правая сторона: «Пиксельный бегун» — человечек бежит на месте, земля едет

    struct PixelRunner: View {
        let t: Double
        let tint: Color

        private static let stride1 = ["..##.", "..##.", ".###.", "#.##.", "..#..", ".#.#.", "#...#"]
        private static let stride2 = ["..##.", "..##.", ".###.", ".##.#", "..#..", "..##.", ".#..#"]

        var body: some View {
            Canvas { ctx, sz in
                let px: CGFloat = 1.8
                let frame = Int(t * 8) % 2 == 0 ? Self.stride1 : Self.stride2
                let heroH = CGFloat(frame.count) * px
                let ground = sz.height - 2.5
                let originX: CGFloat = 4, originY = ground - heroH - 1
                for (row, line) in frame.enumerated() {
                    for (col, ch) in line.enumerated() where ch == "#" {
                        ctx.fill(Path(CGRect(x: originX + CGFloat(col) * px, y: originY + CGFloat(row) * px, width: px + 0.2, height: px + 0.2)),
                                 with: .color(tint))
                    }
                }
                // Бегущая земля и пыль
                ctx.fill(Path(CGRect(x: 0, y: ground, width: sz.width, height: 0.8)), with: .color(tint.opacity(0.35)))
                var x = -CGFloat((t * 26).truncatingRemainder(dividingBy: 7))
                while x < sz.width {
                    ctx.fill(Path(CGRect(x: x, y: ground + 1.2, width: 2.4, height: 0.7)), with: .color(tint.opacity(0.28)))
                    x += 7
                }
                for k in 0..<3 {
                    let age = (t * 3 + Double(k) / 3).truncatingRemainder(dividingBy: 1)
                    ctx.fill(Path(ellipseIn: CGRect(x: originX - CGFloat(age) * 6, y: ground - 1.5 - CGFloat(age) * 1.5, width: 1.4, height: 1.4)),
                             with: .color(tint.opacity(0.5 * (1 - age))))
                }
            }
            .frame(width: 30, height: 17)
        }
    }

    // MARK: Правая сторона: «Искры» — звёздочки то вспыхивают, то гаснут

    struct Sparkles: View {
        let t: Double
        let tint: Color

        var body: some View {
            ZStack {
                ForEach(0..<4, id: \.self) { i in
                    let phase = (t * (0.6 + 0.1 * Double(i)) + Double(i) * 0.27).truncatingRemainder(dividingBy: 1)
                    let pulse = sin(phase * .pi)
                    let positions: [CGPoint] = [CGPoint(x: -8, y: -3), CGPoint(x: 3, y: 4), CGPoint(x: 9, y: -4), CGPoint(x: -2, y: -6)]
                    SparkleShape()
                        .fill(tint.opacity(0.35 + 0.65 * pulse))
                        .frame(width: 4 + 6 * pulse, height: 4 + 6 * pulse)
                        .rotationEffect(.degrees(phase * 90))
                        .offset(x: positions[i].x, y: positions[i].y)
                }
            }
            .frame(width: 30, height: 17)
        }
    }

    // MARK: Завершение: «Ракета» — ракета взлетает по диагонали, а на её месте рисуется галочка

    struct DoneRocket: View, Animatable {
        var progress: Double
        let size: CGFloat
        let tint: Color
        var animatableData: Double {
            get { progress }
            set { progress = newValue }
        }

        var body: some View {
            let ring = size * AgentBadgeArt.ringScale
            ZStack {
                AgentBadgeArt.Done(progress: max(0, (progress - 0.5) / 0.5), size: size, tint: tint)
                Frame(size: size) {
                    Canvas { ctx, sz in
                        guard progress < 0.72 else { return }
                        let p = CGFloat(progress / 0.72)
                        let c = CGPoint(x: sz.width / 2, y: sz.height / 2)
                        let travel = ring * 0.95
                        let pos = CGPoint(x: c.x - travel / 2 + travel * p * 1.05, y: c.y + travel / 2 - travel * p * 1.05)
                        var layer = ctx
                        layer.translateBy(x: pos.x, y: pos.y)
                        layer.rotate(by: .radians(.pi / 4))
                        let u = size * 0.055
                        let alpha = Double(1 - max(0, (p - 0.75) / 0.25))
                        // пламя
                        let flame = u * (3.5 + 2 * CGFloat(abs(sin(progress * 60))))
                        layer.fill(Path { path in
                            path.move(to: CGPoint(x: -u * 0.9, y: u * 3)); path.addLine(to: CGPoint(x: 0, y: u * 3 + flame)); path.addLine(to: CGPoint(x: u * 0.9, y: u * 3)); path.closeSubpath()
                        }, with: .color(Color(red: 1, green: 0.6, blue: 0.2).opacity(alpha)))
                        // корпус, нос и крылья
                        layer.fill(Path(roundedRect: CGRect(x: -u * 1.1, y: -u * 3, width: u * 2.2, height: u * 6), cornerRadius: u), with: .color(.white.opacity(alpha)))
                        layer.fill(Path { path in
                            path.move(to: CGPoint(x: -u * 1.1, y: -u * 2)); path.addLine(to: CGPoint(x: 0, y: -u * 4.4)); path.addLine(to: CGPoint(x: u * 1.1, y: -u * 2)); path.closeSubpath()
                        }, with: .color(Color(red: 1, green: 0.35, blue: 0.3).opacity(alpha)))
                        for side in [-1.0, 1.0] {
                            layer.fill(Path { path in
                                path.move(to: CGPoint(x: CGFloat(side) * u * 1.1, y: u * 1)); path.addLine(to: CGPoint(x: CGFloat(side) * u * 2.4, y: u * 3.2)); path.addLine(to: CGPoint(x: CGFloat(side) * u * 1.1, y: u * 2.6)); path.closeSubpath()
                            }, with: .color(Color(red: 1, green: 0.35, blue: 0.3).opacity(alpha)))
                        }
                    }
                    .frame(width: ring, height: ring)
                }
            }
        }
    }

    // MARK: Завершение: «Ударная волна» — галочка и расходящиеся кольца

    struct DoneShockwave: View, Animatable {
        var progress: Double
        let size: CGFloat
        let tint: Color
        var animatableData: Double {
            get { progress }
            set { progress = newValue }
        }

        var body: some View {
            let ring = size * AgentBadgeArt.ringScale
            let lw = AgentBadgeArt.lineWidth(size)
            ZStack {
                AgentBadgeArt.Done(progress: min(1, progress * 1.4), size: size, tint: tint)
                Frame(size: size) {
                    Canvas { ctx, sz in
                        let c = CGPoint(x: sz.width / 2, y: sz.height / 2)
                        for k in 0..<2 {
                            let p = min(1, max(0, (progress - Double(k) * 0.14) / 0.86))
                            guard p > 0, p < 1 else { continue }
                            let r = ring * 0.35 + CGFloat(p) * ring * 0.6
                            ctx.stroke(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)),
                                       with: .color(tint.opacity((1 - p) * 0.8)), lineWidth: lw * CGFloat(1 - 0.6 * p))
                        }
                    }
                    .frame(width: size * AgentBadgeArt.reach, height: size * AgentBadgeArt.reach)
                }
            }
        }
    }

    // MARK: Завершение: «Кубок» — золотой кубок выпрыгивает и блестит

    struct DoneTrophy: View, Animatable {
        var progress: Double
        let size: CGFloat
        let tint: Color
        var animatableData: Double {
            get { progress }
            set { progress = newValue }
        }

        var body: some View {
            let ring = size * AgentBadgeArt.ringScale
            let pop = progress < 0.5 ? progress / 0.5 * 1.2 : 1.2 - 0.2 * min(1, (progress - 0.5) / 0.3)
            Frame(size: size) {
                Canvas { ctx, sz in
                    let c = CGPoint(x: sz.width / 2, y: sz.height / 2)
                    let u = size * 0.05 * CGFloat(pop)
                    let gold = Color(red: 1, green: 0.82, blue: 0.2)
                    let dark = Color(red: 0.85, green: 0.6, blue: 0.1)
                    var layer = ctx
                    layer.translateBy(x: c.x, y: c.y + u * 0.5)
                    // ручки
                    for side in [-1.0, 1.0] {
                        var handle = Path()
                        handle.move(to: CGPoint(x: CGFloat(side) * u * 3.2, y: -u * 3.4))
                        handle.addQuadCurve(to: CGPoint(x: CGFloat(side) * u * 2.4, y: -u * 0.4), control: CGPoint(x: CGFloat(side) * u * 5.4, y: -u * 2.4))
                        layer.stroke(handle, with: .color(dark), lineWidth: u * 0.8)
                    }
                    // чаша, ножка, основание
                    layer.fill(Path { p in
                        p.move(to: CGPoint(x: -u * 3.2, y: -u * 4.4)); p.addLine(to: CGPoint(x: u * 3.2, y: -u * 4.4))
                        p.addQuadCurve(to: CGPoint(x: 0, y: u * 0.4), control: CGPoint(x: u * 3.2, y: -u * 0.4))
                        p.addQuadCurve(to: CGPoint(x: -u * 3.2, y: -u * 4.4), control: CGPoint(x: -u * 3.2, y: -u * 0.4))
                        p.closeSubpath()
                    }, with: .color(gold))
                    layer.fill(Path(CGRect(x: -u * 0.6, y: u * 0.2, width: u * 1.2, height: u * 1.8)), with: .color(dark))
                    layer.fill(Path(roundedRect: CGRect(x: -u * 2, y: u * 1.9, width: u * 4, height: u * 1.2), cornerRadius: u * 0.3), with: .color(gold))
                    layer.fill(Path(ellipseIn: CGRect(x: -u * 2.1, y: -u * 3.8, width: u * 1, height: u * 2.4)), with: .color(Color.white.opacity(0.55)))
                    // блеск
                    if progress > 0.55 {
                        let q = (progress - 0.55) / 0.45
                        for (dx, dy) in [(-4.5, -5.5), (4.8, -3.6), (0.5, -7.2)] {
                            let r = u * 1.3 * CGFloat(sin(q * .pi))
                            var spark = Path()
                            spark.move(to: CGPoint(x: CGFloat(dx) * u - r, y: CGFloat(dy) * u)); spark.addLine(to: CGPoint(x: CGFloat(dx) * u + r, y: CGFloat(dy) * u))
                            spark.move(to: CGPoint(x: CGFloat(dx) * u, y: CGFloat(dy) * u - r)); spark.addLine(to: CGPoint(x: CGFloat(dx) * u, y: CGFloat(dy) * u + r))
                            layer.stroke(spark, with: .color(.white), lineWidth: 0.9)
                        }
                    }
                }
                .frame(width: ring, height: ring)
            }
        }
    }
}

// MARK: - Новые обложки

/// «Кассета»: прямоугольная кассета, в окошке-этикетке обложка альбома, катушки крутятся, пока играет музыка
struct CassetteCover: View {
    let image: NSImage
    let size: CGFloat
    let isPlaying: Bool

    var body: some View {
        let outer = size + 7
        TimelineView(.animation(paused: !isPlaying)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let spin = isPlaying ? t * 5 : 0
            ZStack {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(Color(white: 0.2))
                    .frame(width: outer, height: outer * 0.68)
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .stroke(Color.white.opacity(0.3), lineWidth: 0.8)
                    .frame(width: outer, height: outer * 0.68)
                // Этикетка с обложкой
                Image(nsImage: image)
                    .resizable().scaledToFill()
                    .frame(width: outer - 7, height: outer * 0.28)
                    .clipShape(RoundedRectangle(cornerRadius: 1.5, style: .continuous))
                    .offset(y: -outer * 0.17)
                // Окошко с катушками
                Canvas { ctx, sz in
                    let c = CGPoint(x: sz.width / 2, y: sz.height / 2)
                    ctx.fill(Path(roundedRect: CGRect(x: c.x - outer * 0.37, y: c.y - outer * 0.1, width: outer * 0.74, height: outer * 0.2), cornerRadius: outer * 0.1),
                             with: .color(Color.black.opacity(0.85)))
                    for side in [-1.0, 1.0] {
                        let reel = CGPoint(x: c.x + CGFloat(side) * outer * 0.2, y: c.y)
                        let r = outer * 0.085
                        ctx.stroke(Path(ellipseIn: CGRect(x: reel.x - r, y: reel.y - r, width: r * 2, height: r * 2)), with: .color(.white.opacity(0.9)), lineWidth: 0.8)
                        for k in 0..<3 {
                            let a = spin * (side < 0 ? 1 : 1.2) + Double(k) * 2 * .pi / 3
                            var spoke = Path()
                            spoke.move(to: reel)
                            spoke.addLine(to: CGPoint(x: reel.x + r * CGFloat(cos(a)), y: reel.y + r * CGFloat(sin(a))))
                            ctx.stroke(spoke, with: .color(.white.opacity(0.9)), lineWidth: 0.7)
                        }
                    }
                }
                .frame(width: outer, height: outer)
                .offset(y: outer * 0.14)
            }
            .frame(width: outer, height: outer)
        }
    }
}

/// «Неон»: квадратная обложка в рамке, по которой бежит радужное свечение
struct NeonCover: View {
    let image: NSImage
    let size: CGFloat
    let isPlaying: Bool

    var body: some View {
        let outer = size + 7
        let inner = outer - 4.5
        TimelineView(.animation(paused: !isPlaying)) { timeline in
            let angle = (timeline.date.timeIntervalSinceReferenceDate * 110).truncatingRemainder(dividingBy: 360)
            let gradient = AngularGradient(colors: [.pink, .purple, .blue, .cyan, .green, .yellow, .orange, .pink],
                                           center: .center, angle: .degrees(angle))
            ZStack {
                RoundedRectangle(cornerRadius: 6.5, style: .continuous)
                    .strokeBorder(gradient, lineWidth: 1.8)
                    .frame(width: outer - 1, height: outer - 1)
                    .blur(radius: 2.2)
                    .opacity(isPlaying ? 0.9 : 0.35)
                Image(nsImage: image)
                    .resizable().scaledToFill()
                    .frame(width: inner, height: inner)
                    .clipShape(RoundedRectangle(cornerRadius: 4.5, style: .continuous))
                RoundedRectangle(cornerRadius: 6.5, style: .continuous)
                    .strokeBorder(gradient, lineWidth: 1.2)
                    .frame(width: outer - 1, height: outer - 1)
                    .opacity(isPlaying ? 1 : 0.4)
            }
            .frame(width: outer, height: outer)
        }
    }
}

/// «Пиксель-арт»: обложка превращена в мозаику 9×9 и подпрыгивает на ритм
struct PixelArtCover: View {
    let image: NSImage
    let size: CGFloat
    let isPlaying: Bool

    private static let cache = NSCache<NSImage, NSImage>()

    private static func mosaic(_ image: NSImage, grid: Int) -> NSImage {
        if let cached = cache.object(forKey: image) { return cached }
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: grid, pixelsHigh: grid, bitsPerSample: 8, samplesPerPixel: 4,
            hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { return image }
        NSGraphicsContext.saveGraphicsState()
        if let context = NSGraphicsContext(bitmapImageRep: rep) {
            NSGraphicsContext.current = context
            context.imageInterpolation = .high
            image.draw(in: NSRect(x: 0, y: 0, width: grid, height: grid), from: .zero, operation: .copy, fraction: 1)
        }
        NSGraphicsContext.restoreGraphicsState()
        let result = NSImage(size: NSSize(width: grid, height: grid))
        result.addRepresentation(rep)
        cache.setObject(result, forKey: image)
        return result
    }

    var body: some View {
        let outer = size + 7
        let inner = outer - 4.5
        TimelineView(.animation(paused: !isPlaying)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let phase = (t * 1.9).truncatingRemainder(dividingBy: 1)
            let beat = isPlaying ? pow(max(0, cos(phase * 2 * .pi)), 6) : 0
            ZStack {
                Image(nsImage: Self.mosaic(image, grid: 9))
                    .resizable()
                    .interpolation(.none)
                    .frame(width: inner, height: inner)
                    .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
                    .scaleEffect(1 + 0.08 * beat)
                RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    .frame(width: outer - 3, height: outer - 3)
            }
            .frame(width: outer, height: outer)
        }
    }
}

// MARK: - Визуализатор музыки

/// Визуализатор справа от «чёлки», пока играет музыка (вид выбирается в настройках; «Classic» — настоящий спектр звука)
struct MusicVisualizerArt: View {
    let style: MusicVisualStyle
    let t: Double
    let isPlaying: Bool
    let tint: Color

    private func level(_ i: Int) -> Double {
        guard isPlaying else { return 0.1 }
        let p = Double(i)
        let a = sin(t * (3.1 + p * 0.55) + p * 1.7)
        let b = sin(t * (5.3 - p * 0.35) + p * 0.9)
        return 0.5 + 0.5 * (0.62 * a + 0.38 * b)
    }

    var body: some View {
        Canvas { ctx, sz in
            let w = sz.width, h = sz.height
            switch style {
            case .classic:
                for i in 0..<4 {
                    let x = CGFloat(i) * (w / 4) + 1
                    let bar = 2 + (h - 2) * level(i)
                    ctx.fill(Path(roundedRect: CGRect(x: x, y: (h - bar) / 2, width: 3, height: bar), cornerRadius: 1.5), with: .color(tint))
                }
            case .pixelBars:
                let columns = 5, rows = 5
                let cw = (w - 4) / CGFloat(columns), ch = h / CGFloat(rows)
                for i in 0..<columns {
                    let lit = Int((level(i) * Double(rows)).rounded())
                    for r in 0..<rows {
                        let y = h - CGFloat(r + 1) * ch + 0.6
                        let top = r == lit - 1
                        ctx.fill(Path(CGRect(x: 2 + CGFloat(i) * cw, y: y, width: cw - 1.1, height: ch - 1.1)),
                                 with: .color(r < lit ? (top ? Color.white : tint) : tint.opacity(0.14)))
                    }
                }
            case .wave:
                let energy = isPlaying ? 0.35 + 0.65 * level(2) : 0.08
                for layer in 0..<2 {
                    var path = Path()
                    var x: CGFloat = 0
                    while x <= w {
                        let phase = Double(x) * (0.5 + Double(layer) * 0.15) + t * (6 + Double(layer) * 2.5)
                        let envelope = sin(Double(x) / Double(w) * .pi)
                        let y = h / 2 + CGFloat(sin(phase) * envelope * energy) * h * 0.46
                        if x == 0 { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }
                        x += 1
                    }
                    ctx.stroke(path, with: .color(tint.opacity(layer == 0 ? 1 : 0.45)), lineWidth: layer == 0 ? 1.5 : 1)
                }
            case .rings:
                let c = CGPoint(x: w / 2, y: h / 2)
                for k in 0..<3 {
                    let p = isPlaying ? (t * 0.9 + Double(k) / 3).truncatingRemainder(dividingBy: 1) : 0.0
                    let r = 2 + CGFloat(p) * (min(w, h) / 2 + 3)
                    ctx.stroke(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)),
                               with: .color(tint.opacity(isPlaying ? (1 - p) * 0.9 : 0.2)), lineWidth: 1.1)
                }
                let core = 2 + 1.4 * CGFloat(isPlaying ? max(0, sin(t * 11)) : 0)
                ctx.fill(Path(ellipseIn: CGRect(x: c.x - core, y: c.y - core, width: core * 2, height: core * 2)), with: .color(tint))
            case .dots:
                for i in 0..<5 {
                    let lift = CGFloat(level(i)) * (h - 4)
                    let x = 2.5 + CGFloat(i) * (w - 5) / 4
                    ctx.fill(Path(ellipseIn: CGRect(x: x - 1.9, y: h - 2 - lift - 1.9, width: 3.8, height: 3.8)), with: .color(tint.opacity(0.55 + 0.45 * level(i))))
                }
            case .mirror:
                let bars = 7
                for i in 0..<bars {
                    let bar = 1.5 + (h - 1.5) * level(i)
                    let x = CGFloat(i) * (w / CGFloat(bars)) + 0.6
                    ctx.fill(Path(roundedRect: CGRect(x: x, y: (h - bar) / 2, width: 1.7, height: bar), cornerRadius: 0.85),
                             with: .color(tint.opacity(0.5 + 0.5 * level(i))))
                }
            }
        }
        .frame(width: 22, height: 15)
    }
}
