//
//  AgentActivityView.swift
//  boringNotch
//
//  Индикатор ИИ-агента в закрытой «чёлке»: компактный значок, совмещение с музыкой
//  и развёрнутое уведомление о завершении
//

import Defaults
import SwiftUI

/// Компактный значок агента: комета при работе, импульс на каждое действие, замыкание кольца при завершении
struct AgentBadge: View {
    let status: AgentStatus
    var size: CGFloat = 22

    @ObservedObject private var manager = AgentActivityManager.shared
    @Default(.agentRunningStyle) private var runningStyle
    @Default(.doneStyle) private var doneStyle
    @State private var rippleStart: Date?
    @State private var doneProgress: Double = 0
    @State private var wobble: Double = 0

    private func rippleProgress(_ now: Date) -> Double? {
        guard let start = rippleStart else { return nil }
        let p = now.timeIntervalSince(start) / 0.7
        return p < 1 ? p : nil
    }

    var body: some View {
        let tint = status.tint
        // Покадровая перерисовка нужна только пока что-то движется
        TimelineView(.animation(paused: !(status == .running || status == .waiting))) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Group {
                switch status {
                case .running:
                    AgentRunningArt(style: runningStyle, t: t, size: size, tint: tint, ripple: rippleProgress(timeline.date))
                case .waiting:
                    AgentBadgeArt.Waiting(t: t, size: size, tint: tint)
                case .done:
                    AgentDoneArt(style: doneStyle, progress: doneProgress, size: size, tint: tint)
                case .error:
                    AgentBadgeArt.Failed(size: size, tint: tint, wobble: wobble)
                case .end, .idle:
                    EmptyView()
                }
            }
        }
        .frame(width: size, height: size)
        .onAppear { if status == .done { doneProgress = 1 } }
        .onChange(of: status) { _, new in
            switch new {
            case .done:
                doneProgress = 0
                withAnimation(doneStyle == .check ? .easeOut(duration: doneStyle.duration) : .linear(duration: doneStyle.duration)) { doneProgress = 1 }
            case .error:
                wobble = 16
                withAnimation(.interpolatingSpring(stiffness: 260, damping: 4)) { wobble = 0 }
            default:
                break
            }
        }
        .onChange(of: manager.activityPulse) { _, _ in
            // Каждое действие агента (шаг, вызов инструмента) пускает волну; не чаще, чем волна успевает пройти
            guard status == .running else { return }
            if let start = rippleStart, Date().timeIntervalSince(start) < 0.6 { return }
            rippleStart = Date()
        }
    }
}

/// Обложка трека как пластинка: круглая, с тонкой светло-серой рамкой, целиком крутится на месте, пока играет музыка.
/// На паузе замирает в текущем положении.
struct SpinningAlbumDisc: View {
    let image: NSImage
    /// Диаметр самой обложки; рамка добавляется снаружи
    let size: CGFloat
    let isPlaying: Bool

    /// Угол хранится в ссылочном типе, чтобы не терять положение при паузе
    private final class SpinState {
        var angle: Double = 0
        var last: Date?
    }
    @State private var spin = SpinState()

    private let gap: CGFloat = 2.5
    private let lineWidth: CGFloat = 1
    /// Градусов в секунду (около 8 секунд на оборот)
    private let speed: Double = 45

    private func currentAngle(at date: Date) -> Double {
        if isPlaying {
            if let last = spin.last { spin.angle += date.timeIntervalSince(last) * speed }
            spin.last = date
        } else {
            spin.last = nil
        }
        return spin.angle.truncatingRemainder(dividingBy: 360)
    }

    var body: some View {
        let ringSize = size + 2 * (gap + lineWidth)
        // Рамка однородная, поэтому добавляем едва заметный блик: так видно, что диск именно крутится
        let gradient = Gradient(stops: [
            .init(color: Color(white: 0.9).opacity(0.9), location: 0.0),
            .init(color: Color.white.opacity(0.2), location: 0.3),
            .init(color: Color.white.opacity(0.2), location: 0.75),
            .init(color: Color(white: 0.9).opacity(0.9), location: 1.0),
        ])

        TimelineView(.animation(paused: !isPlaying)) { timeline in
            let angle = currentAngle(at: timeline.date)
            ZStack {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
                    .overlay {
                        // Отверстие пластинки в центре
                        Circle().fill(.black).frame(width: size * 0.2, height: size * 0.2)
                        Circle().stroke(Color.white.opacity(0.35), lineWidth: 0.5)
                            .frame(width: size * 0.2, height: size * 0.2)
                    }
                Circle()
                    .stroke(AngularGradient(gradient: gradient, center: .center), lineWidth: lineWidth)
                    .frame(width: ringSize, height: ringSize)
            }
            .rotationEffect(.degrees(angle))
        }
        .frame(width: ringSize, height: ringSize)
    }
}

/// Обложка альбома выбранного вида. Занимает ровно столько же места, что и диск, поэтому размер «чёлки» не меняется.
struct AlbumCover: View {
    let image: NSImage
    /// Диаметр диска (как у SpinningAlbumDisc); у квадратных видов обложка занимает ту же площадку
    let size: CGFloat
    let isPlaying: Bool
    /// nil — брать выбранный в настройках; в превью вид задаётся явно
    var style: CoverStyle? = nil

    @Default(.coverStyle) private var selectedStyle

    var body: some View {
        switch style ?? selectedStyle {
        case .disc:
            SpinningAlbumDisc(image: image, size: size, isPlaying: isPlaying)
        case .rounded:
            SquareCover(image: image, size: size, glow: false, isPlaying: isPlaying)
        case .glow:
            SquareCover(image: image, size: size, glow: true, isPlaying: isPlaying)
        case .beat:
            BeatCover(image: image, size: size, isPlaying: isPlaying)
        case .radial:
            RadialCover(image: image, size: size, isPlaying: isPlaying)
        case .rainbow:
            RainbowDisc(image: image, size: size, isPlaying: isPlaying)
        case .cassette:
            CassetteCover(image: image, size: size, isPlaying: isPlaying)
        case .neon:
            NeonCover(image: image, size: size, isPlaying: isPlaying)
        case .pixelart:
            PixelArtCover(image: image, size: size, isPlaying: isPlaying)
        case .vinyl:
            VinylSleeveCover(image: image, size: size, isPlaying: isPlaying)
        case .polaroid:
            PolaroidCover(image: image, size: size, isPlaying: isPlaying)
        }
    }
}

/// Квадратная обложка со скруглением и тонкой светлой рамкой; в «светящемся» виде рамка дышит, пока играет музыка
struct SquareCover: View {
    let image: NSImage
    let size: CGFloat
    let glow: Bool
    let isPlaying: Bool

    var body: some View {
        // Площадка как у диска: размер + рамка (2,5 + 1) с каждой стороны
        let outer = size + 7
        let inner = outer - 4.5
        TimelineView(.animation(paused: !(glow && isPlaying))) { timeline in
            let breath = glow && isPlaying ? (sin(timeline.date.timeIntervalSinceReferenceDate * 2 * .pi / 2.4) + 1) / 2 : 0.35
            ZStack {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: inner, height: inner)
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                RoundedRectangle(cornerRadius: 6.5, style: .continuous)
                    .stroke(Color.white.opacity(glow ? 0.18 + 0.55 * breath : 0.22), lineWidth: 1)
                    .frame(width: outer - 1, height: outer - 1)
                    .shadow(color: .white.opacity(glow ? 0.55 * breath : 0), radius: 3)
            }
            .frame(width: outer, height: outer)
        }
    }
}

/// Строка закрытой «чёлки», когда работает только агент (без музыки)
struct AgentActivityView: View {
    @ObservedObject private var manager = AgentActivityManager.shared
    @Default(.agentSideStyle) private var sideStyle
    let notchWidth: CGFloat
    let rowWidth: CGFloat
    static let sideWidth = ClosedNotchLayout.sideWidth

    var body: some View {
        if let session = manager.primary {
            let tint = session.status.tint
            HStack(spacing: 0) {
                // Значок прижат к левому краю с небольшим отступом
                AgentBadge(status: session.status, size: 20)   // тот же размер, что справа рядом с музыкой
                    .overlay(alignment: .topTrailing) { countBadge }
                    .padding(.leading, 5)   // чуть ближе к левому краю
                    .frame(width: Self.sideWidth, alignment: .leading)

                Spacer(minLength: 0)
                Rectangle().fill(.black).frame(width: notchWidth)
                Spacer(minLength: 0)

                ZStack {
                    if session.status == .running {
                        AgentSideContent(style: sideStyle, since: session.since, task: session.task, tint: tint)
                            .transition(.opacity)
                    } else {
                        Text(session.status.label)
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundStyle(tint)
                            .lineLimit(1)   // подпись не переносится на вторую строку, при нехватке места слегка сжимается
                            .minimumScaleFactor(0.8)
                            .transition(.opacity.combined(with: .offset(x: -3)))
                    }
                }
                .padding(.trailing, 6)
                .frame(width: Self.sideWidth, alignment: .trailing)
            }
            .frame(width: rowWidth)
            .animation(.smooth(duration: 0.35), value: session.status)
            .help([session.agent, session.project, session.task].compactMap { $0 }.joined(separator: " · "))
        }
    }

    @ViewBuilder
    private var countBadge: some View {
        if manager.count > 1 {
            Text("\(manager.count)")
                .font(.system(size: 8.5, weight: .semibold).monospacedDigit())
                .foregroundStyle(.white.opacity(0.85))
                .frame(minWidth: 12, minHeight: 12)
                .background(Circle().fill(.white.opacity(0.18)))
                .offset(x: 5, y: -3)
                .transition(.scale.combined(with: .opacity))
        }
    }
}

/// Рисует индикатор работы выбранного варианта (комета, пульс, орбита)
struct AgentRunningArt: View {
    let style: AgentRunningStyle
    let t: Double
    let size: CGFloat
    let tint: Color
    var ripple: Double? = nil

    var body: some View {
        switch style {
        case .comet: AgentBadgeArt.Running(t: t, size: size, tint: tint, ripple: ripple)
        case .pulse: AgentBadgeArt.RunningPulse(t: t, size: size, tint: tint, ripple: ripple)
        case .orbit: AgentBadgeArt.RunningOrbit(t: t, size: size, tint: tint, ripple: ripple)
        case .aurora: AgentBadgeArt.RunningAurora(t: t, size: size, tint: tint, ripple: ripple)
        case .galaxy: AgentBadgeArt.RunningGalaxy(t: t, size: size, tint: tint, ripple: ripple)
        case .atom: AgentBadgeArt.RunningAtom(t: t, size: size, tint: tint, ripple: ripple)
        case .neural: AgentBadgeArt.RunningNeural(t: t, size: size, tint: tint, ripple: ripple)
        case .helix: AgentBadgeArt.RunningHelix(t: t, size: size, tint: tint, ripple: ripple)
        case .pixel: AgentBadgeArt.RunningPixel(t: t, size: size, tint: tint, ripple: ripple)
        case .cube: AgentBadgeArt.RunningCube(t: t, size: size, tint: tint, ripple: ripple)
        case .plasma: AgentBadgeArt.RunningPlasma(t: t, size: size, tint: tint, ripple: ripple)
        case .binary: AgentBadgeArt.RunningBinary(t: t, size: size, tint: tint, ripple: ripple)
        }
    }
}

/// Эффект завершения выбранного варианта (галочка, конфетти, вспышка)
struct AgentDoneArt: View {
    let style: DoneStyle
    let progress: Double
    let size: CGFloat
    let tint: Color

    var body: some View {
        switch style {
        case .check: AgentBadgeArt.Done(progress: progress, size: size, tint: tint)
        case .confetti: AgentBadgeArt.DoneConfetti(progress: progress, size: size, tint: tint)
        case .starburst: AgentBadgeArt.DoneStarburst(progress: progress, size: size, tint: tint)
        case .rocket: AgentBadgeArt.DoneRocket(progress: progress, size: size, tint: tint)
        case .shockwave: AgentBadgeArt.DoneShockwave(progress: progress, size: size, tint: tint)
        case .trophy: AgentBadgeArt.DoneTrophy(progress: progress, size: size, tint: tint)
        case .fireworks: AgentBadgeArt.DoneFireworks(progress: progress, size: size, tint: tint)
        case .medal: AgentBadgeArt.DoneMedal(progress: progress, size: size, tint: tint)
        }
    }
}

/// Содержимое правой стороны в режиме «только нейросеть» (таймер, эквалайзер, точки, волна, дождь или блик)
struct AgentSideContent: View {
    let style: AgentSideStyle
    let since: Date
    let task: String?
    let tint: Color

    var body: some View {
        switch style {
        case .timer:
            AgentElapsedTimer(since: since, tint: tint)
        case .equalizer:
            TimelineView(.animation) { AgentBadgeArt.Equalizer(t: $0.date.timeIntervalSinceReferenceDate, tint: tint) }
        case .dots:
            TimelineView(.animation) { AgentBadgeArt.TypingDots(t: $0.date.timeIntervalSinceReferenceDate, tint: tint) }
        case .wave:
            TimelineView(.animation) { AgentBadgeArt.Wave(t: $0.date.timeIntervalSinceReferenceDate, tint: tint) }
        case .rain:
            TimelineView(.animation) { AgentBadgeArt.Rain(t: $0.date.timeIntervalSinceReferenceDate, tint: tint) }
        case .shimmer:
            TimelineView(.animation) { AgentBadgeArt.Shimmer(t: $0.date.timeIntervalSinceReferenceDate, tint: tint) }
        case .code:
            TimelineView(.animation) { AgentBadgeArt.TypingCode(t: $0.date.timeIntervalSinceReferenceDate, tint: tint) }
        case .runner:
            TimelineView(.animation) { AgentBadgeArt.PixelRunner(t: $0.date.timeIntervalSinceReferenceDate, tint: tint) }
        case .sparkles:
            TimelineView(.animation) { AgentBadgeArt.Sparkles(t: $0.date.timeIntervalSinceReferenceDate, tint: tint) }
        case .gears:
            TimelineView(.animation) { AgentBadgeArt.Gears(t: $0.date.timeIntervalSinceReferenceDate, tint: tint) }
        case .thought:
            TimelineView(.animation) { AgentBadgeArt.Thinking(t: $0.date.timeIntervalSinceReferenceDate, tint: tint) }
        }
    }
}

/// Таймер работы агента справа в режиме «только нейросеть»: считает секунды от начала работы
struct AgentElapsedTimer: View {
    let since: Date
    let tint: Color

    var body: some View {
        // Раз в 0,5 секунды: цифры тикают раз в секунду, а точка успевает мягко пульсировать
        TimelineView(.periodic(from: .now, by: 0.5)) { timeline in
            let seconds = Int(timeline.date.timeIntervalSince(since))
            let phase = (sin(timeline.date.timeIntervalSinceReferenceDate * 2 * .pi / 1.4) + 1) / 2
            AgentBadgeArt.Elapsed(seconds: seconds, tint: tint, pulse: phase)
                .animation(.easeInOut(duration: 0.4), value: phase)
                .animation(.smooth(duration: 0.3), value: seconds)
        }
    }
}

// MARK: - Развёрнутое уведомление

/// Блок под строкой «чёлки»: чёлка разворачивается и показывает, что агент закончил (или ждёт вас)
struct AgentBannerView: View {
    let banner: AgentBanner
    /// Ширина плашки равна ширине строки «чёлки», в которой она показана
    let width: CGFloat

    @State private var drawn = false
    @State private var ripple = false

    private var title: String {
        switch banner.status {
        case .done: return "\(banner.agent) finished"
        case .error: return "\(banner.agent) failed"
        case .waiting: return "\(banner.agent) needs you"
        default: return banner.agent
        }
    }

    private var subtitle: String? {
        let parts = [banner.project, banner.task].compactMap { $0 }.filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    var body: some View {
        let tint = banner.status.tint
        HStack(spacing: 12) {
            // Слева «аватар» агента (звёздочка), а не значок статуса: галочка/«!»/рука уже есть в значке справа вверху,
            // поэтому здесь они не повторяются
            ZStack {
                // Волна, расходящаяся от значка один раз
                Circle()
                    .stroke(tint.opacity(ripple ? 0 : 0.45), lineWidth: 1.4)
                    .scaleEffect(ripple ? 1.9 : 1)
                Circle().fill(tint.opacity(0.16))
                SparkleShape(pinch: 0.22)
                    .fill(tint)
                    .frame(width: 15, height: 15)
                    .scaleEffect(drawn ? 1 : 0.2)
                    .rotationEffect(.degrees(drawn ? 0 : -50))
                    .shadow(color: tint.opacity(0.6), radius: 4)
            }
            .frame(width: 26, height: 26)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.5))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.top, 2)
        .padding(.bottom, 10)
        .frame(width: width, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture { AgentActivityManager.shared.jump(to: banner.sessionID) }
        .transition(.opacity.combined(with: .scale(scale: 0.92, anchor: .top)))
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.1)) { drawn = true }
            withAnimation(.easeOut(duration: 0.9).delay(0.1)) { ripple = true }
        }
    }
}

// MARK: - Запрос разрешения

/// Карточка «Разрешить / Отклонить» для запроса агента
struct AgentPermissionView: View {
    let request: AgentPermissionRequest
    var extraCount: Int = 0
    /// nil — растянуть на всю доступную ширину (вкладка Agents)
    var width: CGFloat? = Self.width
    static let width: CGFloat = 320

    @ObservedObject private var manager = AgentActivityManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                AgentBadge(status: .waiting, size: 18)
                Text([request.agent, request.project].compactMap { $0 }.joined(separator: " · "))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Spacer(minLength: 4)
                if extraCount > 0 {
                    Text("+\(extraCount)")
                        .font(.system(size: 10, weight: .medium).monospacedDigit())
                        .foregroundStyle(.white.opacity(0.5))
                }
                Button { manager.jump(to: request.sessionID) } label: {
                    Image(systemName: "arrow.up.forward.app")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.6))
                }
                .buttonStyle(.plain)
                .help("Go to this agent")
                Text(request.tool)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.75))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(.white.opacity(0.12)))
            }

            if !request.detail.isEmpty {
                Text(request.detail)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(3)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(.white.opacity(0.07)))
            }

            HStack(spacing: 8) {
                Button { manager.resolve(request.id, allow: false) } label: {
                    Text("Deny")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 26)
                        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(.white.opacity(0.12)))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Button { manager.resolve(request.id, allow: true) } label: {
                    Text("Allow")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity, minHeight: 26)
                        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(.white))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 2)
        .padding(.bottom, 12)
        .frame(width: width, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture {} // клики по карточке не должны открывать «чёлку»
        .transition(.opacity.combined(with: .scale(scale: 0.94, anchor: .top)))
    }
}
