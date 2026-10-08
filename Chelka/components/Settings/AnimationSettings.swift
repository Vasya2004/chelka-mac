//
//  AnimationSettings.swift
//  Chelka
//
//  Settings → Animations: выбор вариантов анимаций с живым превью каждого варианта.
//

import AppKit
import Defaults
import SwiftUI

struct AnimationSettings: View {
    @Default(.agentRunningStyle) private var runningStyle
    @Default(.agentSideStyle) private var sideStyle
    @Default(.coverStyle) private var coverStyle
    @Default(.doneStyle) private var doneStyle
    @Default(.idleStyle) private var idleStyle
    @ObservedObject private var music = MusicManager.shared
    /// Момент «начала работы» для превью таймера
    @State private var previewStart = Date().addingTimeInterval(-74)

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 12)]
    private let white = Color.white.opacity(0.92)

    var body: some View {
        Form {
            Section {
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(AgentRunningStyle.allCases) { style in
                        StyleCard(title: style.title, selected: runningStyle == style, action: { runningStyle = style }) {
                            TimelineView(.animation) { timeline in
                                AgentRunningArt(style: style, t: timeline.date.timeIntervalSinceReferenceDate,
                                                size: 40, tint: white, ripple: nil)
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Text("Agent working indicator")
            } footer: {
                Text("The ring shown while an AI agent is working, next to the music or on its own. Every agent action sends a ripple through it.")
            }

            Section {
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(AgentSideStyle.allCases) { style in
                        StyleCard(title: style.title, selected: sideStyle == style, action: { sideStyle = style }) {
                            HStack(spacing: 0) {
                                TimelineView(.animation) { timeline in
                                    AgentRunningArt(style: runningStyle, t: timeline.date.timeIntervalSinceReferenceDate,
                                                    size: 26, tint: white, ripple: nil)
                                }
                                Spacer(minLength: 0)
                                AgentSideContent(style: style, since: previewStart, task: "Bash", tint: white)
                                    .scaleEffect(1.15)
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Text("Right side when only an agent is active")
            } footer: {
                Text("Shown to the right of the notch while an agent works and no music is playing.")
            }

            Section {
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(CoverStyle.allCases) { style in
                        StyleCard(title: style.title, selected: coverStyle == style, action: { coverStyle = style }) {
                            HStack(spacing: 0) {
                                AlbumCover(image: music.albumArt, size: 26, isPlaying: true, style: style)
                                Spacer(minLength: 0)
                                TimelineView(.animation) { timeline in
                                    AgentBadgeArt.Equalizer(t: timeline.date.timeIntervalSinceReferenceDate, tint: Color.gray)
                                        .scaleEffect(0.9)
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Text("Album cover")
            } footer: {
                Text("The cover in the closed notch while music plays. The notch keeps the same size for every style.")
            }

            Section {
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(DoneStyle.allCases) { style in
                        StyleCard(title: style.title, selected: doneStyle == style, action: { doneStyle = style }) {
                            TimelineView(.animation) { timeline in
                                // превью повторяется: эффект, пауза, снова эффект
                                let cycle = style.duration + 1.4
                                let local = timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: cycle)
                                AgentDoneArt(style: style, progress: min(1, local / style.duration), size: 34,
                                             tint: Color(red: 0.38, green: 0.84, blue: 0.56))
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Text("Completion effect")
            } footer: {
                Text("Plays on the agent badge when an agent finishes its work.")
            }

            Section {
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(IdleStyle.allCases) { style in
                        StyleCard(title: style.title, selected: idleStyle == style, action: { idleStyle = style }) {
                            if style == .off {
                                Image(systemName: "moon.zzz")
                                    .font(.system(size: 20))
                                    .foregroundStyle(.white.opacity(0.35))
                            } else {
                                // Мини-«чёлка»: чёрная плашка посередине, анимация вокруг неё
                                TimelineView(.animation(minimumInterval: 1.0 / 30)) { timeline in
                                    IdleArt(style: style, t: timeline.date.timeIntervalSinceReferenceDate,
                                            notchWidth: 56, side: IdleAnimationView.sideWidth)
                                }
                                .frame(width: 56 + 2 * IdleAnimationView.sideWidth, height: 32)
                                .background(alignment: .center) {
                                    Capsule().fill(Color.white.opacity(0.06)).frame(width: 52, height: 6)
                                }
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Text("When nothing is active")
            } footer: {
                Text("Plays around the closed notch while no AI agent is working and no media is playing. The eyes follow your cursor.")
            }

            Section {
                Button("Restore defaults") {
                    runningStyle = .comet
                    sideStyle = .timer
                    coverStyle = .disc
                    doneStyle = .check
                    idleStyle = .cat
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Animations")
    }
}

/// Карточка варианта: чёрное «поле» с живым превью и подпись; выбранный вариант обведён акцентным цветом
private struct StyleCard<Preview: View>: View {
    let title: String
    let selected: Bool
    let action: () -> Void
    @ViewBuilder let preview: () -> Preview

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.black)
                    preview()
                }
                .frame(height: 78)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(selected ? Color.effectiveAccent : Color.white.opacity(0.12), lineWidth: selected ? 2.5 : 1)
                )
                .overlay(alignment: .topTrailing) {
                    if selected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(Color.effectiveAccent, .white)
                            .padding(6)
                    }
                }
                Text(title)
                    .font(.caption.weight(selected ? .semibold : .regular))
                    .foregroundStyle(selected ? .primary : .secondary)
            }
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .animation(.smooth(duration: 0.2), value: selected)
    }
}
