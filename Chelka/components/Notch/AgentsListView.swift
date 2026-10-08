//
//  AgentsListView.swift
//  boringNotch
//
//  Вкладка открытой «чёлки» со списком активных ИИ-агентов
//

import Defaults
import SwiftUI

struct AgentsListView: View {
    @ObservedObject private var manager = AgentActivityManager.shared
    @Default(.agentCompletionSound) private var completionSound

    var body: some View {
        Group {
            if manager.sessions.isEmpty && manager.currentPermission == nil {
                emptyState
                    .transition(.opacity)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        if let request = manager.currentPermission {
                            AgentPermissionView(
                                request: request, extraCount: manager.pendingPermissions.count - 1, width: nil)
                                .padding(.bottom, 6)
                        }
                        let sessions = manager.orderedSessions
                        ForEach(sessions) { session in
                            AgentRow(session: session)
                                .transition(.opacity.combined(with: .offset(y: -4)))
                            if session.id != sessions.last?.id {
                                Divider().overlay(Color.white.opacity(0.07)).padding(.leading, 26)
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 6)
        .overlay(alignment: .topTrailing) { soundButton }
        .animation(.smooth(duration: 0.35), value: manager.orderedSessions.map(\.id))
        .animation(.smooth(duration: 0.35), value: manager.sessions.isEmpty)
    }

    /// Быстро включить или выключить звук завершения, не заходя в настройки
    private var soundButton: some View {
        Button {
            completionSound.toggle()
        } label: {
            Image(systemName: completionSound ? "speaker.wave.2.fill" : "speaker.slash.fill")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(completionSound ? 0.7 : 0.4))
                .frame(width: 24, height: 24)
                .background(Circle().fill(.white.opacity(0.08)))
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.plain)
        .help(completionSound ? "Sound on: click to mute" : "Sound off: click to enable")
    }

    private var emptyState: some View {
        VStack(spacing: 5) {
            Image(systemName: "sparkle")
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(.white.opacity(0.3))
            Text("No active agents")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))
        }
    }
}

private struct AgentRow: View {
    let session: AgentSession
    @ObservedObject private var manager = AgentActivityManager.shared
    @State private var hovering = false

    /// «12s», «3m», «1h 5m»
    private func elapsed(from date: Date, now: Date) -> String {
        let seconds = max(0, Int(now.timeIntervalSince(date)))
        if seconds < 60 { return "\(seconds)s" }
        if seconds < 3600 { return "\(seconds / 60)m" }
        return "\(seconds / 3600)h \((seconds % 3600) / 60)m"
    }

    var body: some View {
        let tint = session.status.tint
        HStack(spacing: 10) {
            // Индикатор статуса: точка, при работе мягко «дышит»
            StatusDot(status: session.status, tint: tint)
                .frame(width: 16, height: 16)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(session.agent)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                    if let project = session.project {
                        Text(project)
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }
                .lineLimit(1)

                Text(session.task ?? session.status.label)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.5))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer(minLength: 8)

            // Статус цветом только когда нужно внимание, остальное — приглушённо
            HStack(spacing: 8) {
                Text(session.status.label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(session.status == .running ? .white.opacity(0.55) : tint)
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(elapsed(from: session.since, now: context.date))
                        .font(.system(size: 11).monospacedDigit())
                        .foregroundStyle(.white.opacity(0.35))
                        .frame(minWidth: 30, alignment: .trailing)
                }
            }

            Image(systemName: "arrow.up.forward.app")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(hovering ? 0.75 : 0.3))
                .help("Go to this agent")

            Button {
                manager.remove(session.id)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
                    .frame(width: 18, height: 18)
                    .background(Circle().fill(.white.opacity(0.1)))
            }
            .buttonStyle(.plain)
            .opacity(hovering ? 1 : 0)
            .help("Remove from list")
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture { manager.jump(to: session.id) }
        .animation(.smooth(duration: 0.2), value: hovering)
    }
}

private struct StatusDot: View {
    let status: AgentStatus
    let tint: Color

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let breath = status == .running ? (sin(t * 2.4) + 1) / 2 : 1
            ZStack {
                if status == .running || status == .waiting {
                    Circle()
                        .fill(tint.opacity(0.18 * (status == .running ? breath : 1)))
                        .scaleEffect(1.0 + 0.15 * (status == .running ? breath : 0))
                }
                Circle()
                    .fill(tint.opacity(status == .running ? 0.55 + 0.45 * breath : 1))
                    .frame(width: 7, height: 7)
            }
        }
    }
}
