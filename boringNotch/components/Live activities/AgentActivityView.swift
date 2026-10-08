//
//  AgentActivityView.swift
//  boringNotch
//
//  Индикатор ИИ-агента в закрытой «чёлке»: компактный значок, совмещение с музыкой
//  и развёрнутое уведомление о завершении
//

import SwiftUI

/// Компактный значок агента: комета при работе, импульс на каждое действие, замыкание кольца при завершении
struct AgentBadge: View {
    let status: AgentStatus
    var size: CGFloat = 22

    @ObservedObject private var manager = AgentActivityManager.shared
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
                    AgentBadgeArt.Running(t: t, size: size, tint: tint, ripple: rippleProgress(timeline.date))
                case .waiting:
                    AgentBadgeArt.Waiting(t: t, size: size, tint: tint)
                case .done:
                    AgentBadgeArt.Done(progress: doneProgress, size: size, tint: tint)
                case .error:
                    AgentBadgeArt.Failed(size: size, tint: tint, wobble: wobble)
                case .end:
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
                withAnimation(.easeOut(duration: 0.55)) { doneProgress = 1 }
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

/// Строка закрытой «чёлки», когда работает только агент (без музыки)
struct AgentActivityView: View {
    @ObservedObject private var manager = AgentActivityManager.shared
    let notchWidth: CGFloat
    let rowWidth: CGFloat
    static let sideWidth: CGFloat = 50

    var body: some View {
        if let session = manager.primary {
            let tint = session.status.tint
            HStack(spacing: 0) {
                // Значок прижат к левому краю с небольшим отступом
                AgentBadge(status: session.status)
                    .overlay(alignment: .topTrailing) { countBadge }
                    .padding(.leading, 8)
                    .frame(width: Self.sideWidth, alignment: .leading)

                Spacer(minLength: 0)
                Rectangle().fill(.black).frame(width: notchWidth)
                Spacer(minLength: 0)

                ZStack {
                    if session.status == .running {
                        AgentEqualizer(tint: tint).transition(.opacity)
                    } else {
                        Text(session.status.label)
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundStyle(tint)
                            .lineLimit(1)
                            .fixedSize()   // подпись никогда не переносится на вторую строку
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

/// Эквалайзер «только агент»: пять столбиков с неравномерным ритмом
struct AgentEqualizer: View {
    let tint: Color

    var body: some View {
        TimelineView(.animation) { timeline in
            AgentBadgeArt.Equalizer(t: timeline.date.timeIntervalSinceReferenceDate, tint: tint)
        }
    }
}

// MARK: - Развёрнутое уведомление

private struct CheckmarkShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.55))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.38, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        return path
    }
}

/// Блок под строкой «чёлки»: чёлка разворачивается и показывает, что агент закончил (или ждёт вас)
struct AgentBannerView: View {
    let banner: AgentBanner
    static let width: CGFloat = 280

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
            ZStack {
                // Волна, расходящаяся от значка один раз
                Circle()
                    .stroke(tint.opacity(ripple ? 0 : 0.5), lineWidth: 1.4)
                    .scaleEffect(ripple ? 2.2 : 1)
                Circle().stroke(tint.opacity(0.4), lineWidth: 1.4)

                switch banner.status {
                case .done:
                    CheckmarkShape()
                        .trim(from: 0, to: drawn ? 1 : 0)
                        .stroke(tint, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                        .frame(width: 11, height: 8)
                case .error:
                    Image(systemName: "exclamationmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(tint)
                        .scaleEffect(drawn ? 1 : 0.3)
                case .waiting:
                    Image(systemName: "hand.raised.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(tint)
                        .scaleEffect(drawn ? 1 : 0.3)
                default:
                    EmptyView()
                }
            }
            .frame(width: 26, height: 26)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(.white)
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
        .frame(width: Self.width, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture { AgentActivityManager.shared.jump(to: banner.sessionID) }
        .transition(.opacity.combined(with: .scale(scale: 0.92, anchor: .top)))
        .onAppear {
            withAnimation(.easeOut(duration: 0.45).delay(0.12)) { drawn = true }
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
