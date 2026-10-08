//
//  AgentBadgeArt.swift
//  boringNotch
//
//  Чистое рисование значка ИИ-агента: каждый кадр целиком определяется временем и состоянием,
//  без зависимостей от остального приложения (поэтому легко проверять отдельно).
//

import SwiftUI

/// Четырёхлучевая звезда с вогнутыми сторонами (звёздочка агента)
struct SparkleShape: Shape {
    var pinch: CGFloat = 0.20
    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let s = min(rect.width, rect.height) / 2
        let k = s * pinch
        var p = Path()
        p.move(to: CGPoint(x: c.x, y: c.y - s))
        p.addQuadCurve(to: CGPoint(x: c.x + s, y: c.y), control: CGPoint(x: c.x + k, y: c.y - k))
        p.addQuadCurve(to: CGPoint(x: c.x, y: c.y + s), control: CGPoint(x: c.x + k, y: c.y + k))
        p.addQuadCurve(to: CGPoint(x: c.x - s, y: c.y), control: CGPoint(x: c.x - k, y: c.y + k))
        p.addQuadCurve(to: CGPoint(x: c.x, y: c.y - s), control: CGPoint(x: c.x - k, y: c.y - k))
        p.closeSubpath()
        return p
    }
}

/// Галочка, которую можно «дорисовывать» через trim
struct CheckStrokeShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.55))
        p.addLine(to: CGPoint(x: rect.minX + rect.width * 0.38, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        return p
    }
}

enum AgentBadgeArt {
    /// Диаметр кольца относительно параметра `size` (так выглядит одобренный размер значка)
    static let ringScale: CGFloat = 1.3
    /// Размер области, в которую обрезаются все эффекты, относительно `size`. Строка «чёлки» (32 пт) при size 20 как раз 1,6:
    /// волны видны на всю высоту строки, но не выходят за границы «чёлки».
    static let reach: CGFloat = 1.6
    /// Во сколько раз волна вырастает от кольца до края области
    static var rippleGrowth: CGFloat { reach / ringScale - 1 }

    /// Толщина кольца относительно размера значка
    static func lineWidth(_ size: CGFloat) -> CGFloat { max(1.2, size * 0.07) }

    /// Общая обёртка: рисуем в области `reach`, обрезаем по кругу и сообщаем верстке размер `size`
    struct Frame<Content: View>: View {
        let size: CGFloat
        @ViewBuilder let content: () -> Content
        var body: some View {
            ZStack { content() }
                .frame(width: size * AgentBadgeArt.reach, height: size * AgentBadgeArt.reach)
                .clipShape(Circle())
                .frame(width: size, height: size)
        }
    }

    /// Волна от кольца (прогресс p от 0 до 1)
    static func rippleRing(_ p: Double, ring: CGFloat, lw: CGFloat, tint: Color, strength: Double) -> some View {
        Circle()
            .stroke(tint.opacity((1 - p) * strength), lineWidth: lw * (1 - 0.5 * p))
            .frame(width: ring, height: ring)
            .scaleEffect(1 + rippleGrowth * p)
    }

    // MARK: - Работа: «Комета» (бегущая дуга с хвостом, дышащая звёздочка)

    /// - Parameters:
    ///   - t: время в секундах
    ///   - ripple: прогресс волны от 0 до 1 (nil — волны нет), запускается на каждое действие агента
    struct Running: View {
        let t: Double
        let size: CGFloat
        let tint: Color
        var ripple: Double? = nil

        var body: some View {
            let lw = AgentBadgeArt.lineWidth(size)
            let ring = size * AgentBadgeArt.ringScale
            let breathe = (sin(t * 2 * .pi / 2.2) + 1) / 2
            let twinkle = sin(t * 2 * .pi / 1.7)
            Frame(size: size) {
                // мягкое «дыхание» свечения за кольцом
                Circle()
                    .fill(RadialGradient(colors: [tint.opacity(0.07 + 0.05 * breathe), .clear],
                                         center: .center, startRadius: 0, endRadius: ring / 2))
                    .frame(width: ring, height: ring)

                Circle().stroke(tint.opacity(0.14), lineWidth: lw).frame(width: ring, height: ring)

                // комета: голова движется неравномерно (чуть замедляется наверху), за ней затухающий хвост
                Canvas { ctx, sz in
                    let c = CGPoint(x: sz.width / 2, y: sz.height / 2)
                    let r = sz.width / 2 - lw / 2
                    let phase = (t / 1.2).truncatingRemainder(dividingBy: 1)
                    let eased = phase - sin(2 * .pi * phase) * 0.30 / (2 * .pi)
                    let head = eased * 2 * .pi - .pi / 2
                    let tail = 2.6
                    let n = 56
                    func point(_ a: Double) -> CGPoint { CGPoint(x: c.x + r * cos(a), y: c.y + r * sin(a)) }
                    for i in 0..<n {
                        // небольшое перекрытие соседних сегментов, чтобы не было просветов; концы ровные — без «бус»
                        let a0 = head - tail * Double(i) / Double(n) + 0.012
                        let a1 = head - tail * Double(i + 1) / Double(n)
                        var seg = Path()
                        seg.addArc(center: c, radius: r, startAngle: .radians(a1), endAngle: .radians(a0), clockwise: false)
                        let alpha = pow(1 - Double(i) / Double(n), 1.9)
                        ctx.stroke(seg, with: .color(tint.opacity(alpha)),
                                   style: StrokeStyle(lineWidth: lw * (1.15 - 0.45 * Double(i) / Double(n)), lineCap: .butt))
                    }
                    // яркая голова со свечением
                    let hp = point(head)
                    ctx.drawLayer { layer in
                        layer.addFilter(.shadow(color: tint.opacity(0.9), radius: lw * 1.6))
                        layer.fill(Path(ellipseIn: CGRect(x: hp.x - lw * 0.8, y: hp.y - lw * 0.8, width: lw * 1.6, height: lw * 1.6)),
                                   with: .color(tint))
                    }
                }
                .frame(width: ring, height: ring)

                // звёздочка в центре: дышит и чуть покачивается
                SparkleShape()
                    .fill(tint)
                    .frame(width: size * (0.50 + 0.07 * twinkle), height: size * (0.50 + 0.07 * twinkle))
                    .rotationEffect(.degrees(10 * sin(t * 2 * .pi / 3.4)))
                    .shadow(color: tint.opacity(0.55 + 0.25 * twinkle), radius: size * 0.16)

                // волна на каждое действие агента
                if let p = ripple, p < 1 {
                    AgentBadgeArt.rippleRing(p, ring: ring, lw: lw, tint: tint, strength: 0.55)
                }
            }
        }
    }

    // MARK: - Работа: «Пульс» (кольцо дышит, от него расходятся волны)

    struct RunningPulse: View {
        let t: Double
        let size: CGFloat
        let tint: Color
        var ripple: Double? = nil

        var body: some View {
            let lw = AgentBadgeArt.lineWidth(size)
            let ring = size * AgentBadgeArt.ringScale
            let breathe = (sin(t * 2 * .pi / 1.8) + 1) / 2
            Frame(size: size) {
                Circle()
                    .stroke(tint.opacity(0.28 + 0.5 * breathe), lineWidth: lw)
                    .frame(width: ring, height: ring)
                    .scaleEffect(0.97 + 0.04 * breathe)
                // две волны со сдвигом по фазе: всегда одна идёт, пока другая гаснет
                ForEach(0..<2, id: \.self) { i in
                    let p = (t / 1.7 + Double(i) * 0.5).truncatingRemainder(dividingBy: 1)
                    AgentBadgeArt.rippleRing(p, ring: ring, lw: lw, tint: tint, strength: 0.45)
                }
                SparkleShape()
                    .fill(tint)
                    .frame(width: size * (0.46 + 0.10 * breathe), height: size * (0.46 + 0.10 * breathe))
                    .shadow(color: tint.opacity(0.4 + 0.3 * breathe), radius: size * 0.14)
                if let p = ripple, p < 1 {
                    AgentBadgeArt.rippleRing(p, ring: ring, lw: lw, tint: tint, strength: 0.6)
                }
            }
        }
    }

    // MARK: - Работа: «Орбита» (две точки кружат вокруг звёздочки)

    struct RunningOrbit: View {
        let t: Double
        let size: CGFloat
        let tint: Color
        var ripple: Double? = nil

        var body: some View {
            let lw = AgentBadgeArt.lineWidth(size)
            let ring = size * AgentBadgeArt.ringScale
            let twinkle = sin(t * 2 * .pi / 1.9)
            let r = ring / 2 - lw
            Frame(size: size) {
                Circle().stroke(tint.opacity(0.12), lineWidth: lw * 0.8).frame(width: ring, height: ring)
                // две точки с коротким хвостом: быстрая по часовой и медленная против
                Canvas { ctx, sz in
                    let c = CGPoint(x: sz.width / 2, y: sz.height / 2)
                    func dot(_ angle: Double, _ radius: CGFloat, _ alpha: Double) {
                        let p = CGPoint(x: c.x + r * cos(angle), y: c.y + r * sin(angle))
                        ctx.fill(Path(ellipseIn: CGRect(x: p.x - radius, y: p.y - radius, width: radius * 2, height: radius * 2)),
                                 with: .color(tint.opacity(alpha)))
                    }
                    let a = t * 2 * .pi / 1.25 - .pi / 2
                    let b = -t * 2 * .pi / 2.1 + .pi / 2
                    for k in 0..<5 {   // хвост из пяти затухающих точек
                        let f = Double(k)
                        dot(a - f * 0.20, lw * (1.0 - f * 0.14), 0.95 - f * 0.18)
                        dot(b + f * 0.20, lw * 0.8 * (1.0 - f * 0.14), 0.6 - f * 0.11)
                    }
                }
                .frame(width: ring, height: ring)
                SparkleShape()
                    .fill(tint)
                    .frame(width: size * (0.34 + 0.05 * twinkle), height: size * (0.34 + 0.05 * twinkle))
                    .rotationEffect(.degrees(-90 * ((t / 4).truncatingRemainder(dividingBy: 1))))
                    .shadow(color: tint.opacity(0.5), radius: size * 0.12)
                if let p = ripple, p < 1 {
                    AgentBadgeArt.rippleRing(p, ring: ring, lw: lw, tint: tint, strength: 0.55)
                }
            }
        }
    }

    // MARK: - Ожидание: «дышащее» кольцо и машущая рука

    struct Waiting: View {
        let t: Double
        let size: CGFloat
        let tint: Color

        var body: some View {
            let lw = AgentBadgeArt.lineWidth(size)
            let ring = size * AgentBadgeArt.ringScale
            let breath = (sin(t * 2 * .pi / 1.6) + 1) / 2
            // рука машет короткими сериями
            let wave = sin(t * 9) * 13 * max(0, sin(t * 2 * .pi / 2.4))
            Frame(size: size) {
                Circle()
                    .fill(RadialGradient(colors: [tint.opacity(0.10 * (0.5 + breath)), .clear],
                                         center: .center, startRadius: 0, endRadius: ring / 2))
                    .frame(width: ring, height: ring)
                Circle()
                    .stroke(tint.opacity(0.30 + 0.55 * breath), lineWidth: lw)
                    .frame(width: ring, height: ring)
                    .scaleEffect(0.95 + 0.07 * breath)
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: size * 0.46, weight: .semibold))
                    .foregroundStyle(tint)
                    .rotationEffect(.degrees(wave), anchor: .bottom)
            }
        }
    }

    // MARK: - Готово: кольцо замыкается, галочка дорисовывается

    /// - Parameter progress: 0...1 — насколько замкнуто кольцо и нарисована галочка
    struct Done: View, Animatable {
        var progress: Double
        let size: CGFloat
        let tint: Color
        var animatableData: Double {
            get { progress }
            set { progress = newValue }
        }

        var body: some View {
            let lw = AgentBadgeArt.lineWidth(size)
            let ring = size * AgentBadgeArt.ringScale
            Frame(size: size) {
                ZStack {
                    Circle().stroke(tint.opacity(0.18), lineWidth: lw).frame(width: ring, height: ring)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(tint, style: StrokeStyle(lineWidth: lw, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: ring, height: ring)
                    CheckStrokeShape()
                        .trim(from: 0, to: max(0, (progress - 0.35) / 0.65))
                        .stroke(tint, style: StrokeStyle(lineWidth: lw * 1.2, lineCap: .round, lineJoin: .round))
                        .frame(width: size * 0.42, height: size * 0.32)
                        .offset(y: size * 0.01)
                }
                .scaleEffect(0.8)   // значок «готово» чуть компактнее остальных состояний
                .shadow(color: tint.opacity(0.45 * progress), radius: size * 0.12)
            }
        }
    }

    // MARK: - Ошибка: красное кольцо, «!» с вздрагиванием

    struct Failed: View {
        let size: CGFloat
        let tint: Color
        /// Угол вздрагивания в градусах (затухает до нуля)
        var wobble: Double = 0

        var body: some View {
            let lw = AgentBadgeArt.lineWidth(size)
            let ring = size * AgentBadgeArt.ringScale
            Frame(size: size) {
                Circle().stroke(tint.opacity(0.75), lineWidth: lw).frame(width: ring, height: ring)
                VStack(spacing: size * 0.05) {
                    Capsule().fill(tint).frame(width: size * 0.12, height: size * 0.26)
                    Circle().fill(tint).frame(width: size * 0.12, height: size * 0.12)
                }
                .rotationEffect(.degrees(wobble))
            }
            .shadow(color: tint.opacity(0.4), radius: size * 0.12)
        }
    }

    // MARK: - Эквалайзер (вариант правой стороны)

    struct Equalizer: View {
        let t: Double
        let tint: Color

        var body: some View {
            HStack(alignment: .center, spacing: 2.6) {
                ForEach(0..<5, id: \.self) { i in
                    let p = Double(i)
                    let a = sin(t * (3.1 + p * 0.55) + p * 1.7)
                    let b = sin(t * (5.3 - p * 0.35) + p * 0.9)
                    let level = 0.5 + 0.5 * (0.62 * a + 0.38 * b)
                    Capsule()
                        .fill(LinearGradient(colors: [tint, tint.opacity(0.55)], startPoint: .top, endPoint: .bottom))
                        .frame(width: 2.2, height: 3 + 11.5 * level)
                }
            }
            .frame(height: 17)
        }
    }

    // MARK: - Точки «печатает» (вариант правой стороны)

    struct TypingDots: View {
        let t: Double
        let tint: Color

        var body: some View {
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { i in
                    let wave = max(0, sin(t * 2 * .pi / 1.0 - Double(i) * 0.9))
                    Circle()
                        .fill(tint)
                        .frame(width: 4.4, height: 4.4)
                        .offset(y: -4 * wave)
                        .opacity(0.45 + 0.55 * wave)
                }
            }
            .frame(height: 17)
        }
    }

    // MARK: - Таймер работы (вариант правой стороны)

    /// «2:14» до часа, затем «1.2ч», а после 10 часов «12ч» (компактно, чтобы помещалось в боковую зону)
    static func elapsedText(_ seconds: Int) -> String {
        let s = max(0, seconds)
        if s >= 36000 { return String(format: "%dч", s / 3600) }
        if s >= 3600 { return String(format: "%.1fч", Double(s) / 3600) }
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    /// Пульсирующая точка и тикающий таймер: сколько уже работает агент
    struct Elapsed: View {
        let seconds: Int
        let tint: Color
        /// 0...1 — фаза пульсации точки
        var pulse: Double = 1

        var body: some View {
            HStack(spacing: 4) {
                Circle()
                    .fill(tint)
                    .frame(width: 4.5, height: 4.5)
                    .opacity(0.45 + 0.55 * pulse)
                    .shadow(color: tint.opacity(0.7 * pulse), radius: 3)
                Text(AgentBadgeArt.elapsedText(seconds))
                    .font(.system(size: 11, weight: .medium).monospacedDigit())
                    .foregroundStyle(tint.opacity(0.88))
                    .contentTransition(.numericText(value: Double(seconds)))
                    .lineLimit(1)
                    .fixedSize()
            }
        }
    }
}
