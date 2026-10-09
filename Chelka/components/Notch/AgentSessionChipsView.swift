//
//  AgentSessionChipsView.swift
//  Chelka
//
//  Ряд активных сессий нейросетей на главном экране открытой «чёлки»:
//  нажатие на сессию переносит в приложение, где она идёт (Claude, Codex, Cursor, терминал).
//

import SwiftUI

struct AgentSessionChipsView: View {
    @ObservedObject private var manager = AgentActivityManager.shared

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(manager.orderedSessions) { session in
                    AgentSessionChip(session: session)
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }
            }
            .padding(.horizontal, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(.smooth(duration: 0.3), value: manager.orderedSessions.map(\.id))
    }
}

private struct AgentSessionChip: View {
    let session: AgentSession
    @State private var hovering = false
    @State private var hoveringRemove = false

    var body: some View {
        let tint = session.status.tint
        HStack(spacing: 4) {
            // Основная часть: нажатие переносит в приложение сессии
            Button {
                AgentActivityManager.shared.jump(to: session.id)
            } label: {
                HStack(spacing: 7) {
                    StatusPulse(status: session.status, tint: tint)
                        .frame(width: 14, height: 14)

                    Text(session.agent)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(session.status == .idle ? 0.6 : 1))
                    if let project = session.project, !project.isEmpty {
                        Text(project)
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(session.status == .idle ? 0.3 : 0.45))
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .frame(maxWidth: 110, alignment: .leading)
                    }
                    // Подпись статуса только когда нужно внимание: «работает» видно по точке, «неактивна» — по приглушённому виду
                    if session.status != .running && session.status != .idle {
                        Text(session.status.label)
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundStyle(tint)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help([session.agent, session.project, session.task].compactMap { $0 }.joined(separator: " · ") + "\nClick to open")

            // Убрать сессию из списка (например, проект, в котором уже не работаешь)
            Button {
                AgentActivityManager.shared.remove(session.id)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 8.5, weight: .bold))
                    .foregroundStyle(.white.opacity(hoveringRemove ? 0.95 : (hovering ? 0.6 : 0.35)))
                    .frame(width: 16, height: 16)
                    .background(Circle().fill(.white.opacity(hoveringRemove ? 0.2 : 0)))
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .onHover { hoveringRemove = $0 }
            .help("Remove from the list")
        }
        .padding(.leading, 10)
        .padding(.trailing, 5)
        .frame(height: 24)
        .background(Capsule().fill(.white.opacity(hovering ? 0.14 : 0.08)))
        .overlay(Capsule().stroke(session.status == .waiting ? tint.opacity(0.6) : .clear, lineWidth: 1))
        .onHover { hovering = $0 }
        .animation(.smooth(duration: 0.2), value: hovering)
    }
}

/// Точка статуса: при работе мягко «дышит»
private struct StatusPulse: View {
    let status: AgentStatus
    let tint: Color

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let breath = status == .running ? (sin(t * 2.4) + 1) / 2 : 1
            ZStack {
                if status == .idle {
                    Circle().stroke(tint, lineWidth: 1.2).frame(width: 7, height: 7)
                } else if status == .running || status == .waiting {
                    Circle()
                        .fill(tint.opacity(0.18 * (status == .running ? breath : 1)))
                        .scaleEffect(1.0 + 0.15 * (status == .running ? breath : 0))
                }
                if status != .idle {
                    Circle()
                        .fill(tint.opacity(status == .running ? 0.55 + 0.45 * breath : 1))
                        .frame(width: 7, height: 7)
                }
            }
        }
    }
}
