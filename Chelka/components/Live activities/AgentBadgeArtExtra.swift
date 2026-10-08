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
