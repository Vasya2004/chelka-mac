//
//  UsageStripView.swift
//  boringNotch
//
//  Полоса внизу главного экрана открытой «чёлки»: остаток лимитов Codex и Claude Code.
//  Две строки на сервис (5 часов и неделя), у каждой своя шкала, остаток и время до сброса.
//

import AppKit
import SwiftUI

struct UsageStripView: View {
    @ObservedObject private var usage = UsageManager.shared

    var body: some View {
        // Раз в 30 секунд пересчитываем «сколько осталось до сброса» и сброшенные окна
        TimelineView(.periodic(from: .now, by: 30)) { context in
            HStack(spacing: 0) {
                UsageProviderView(
                    name: "Codex", usage: usage.codex, now: context.date,
                    emptyHint: "No data yet",
                    pageURL: URL(string: "https://chatgpt.com/codex/settings/usage"))
                Rectangle().fill(.white.opacity(0.1)).frame(width: 1).padding(.vertical, 2).padding(.horizontal, 8)
                UsageProviderView(
                    name: "Claude", usage: usage.claude, now: context.date,
                    emptyHint: "No data yet",
                    pageURL: URL(string: "https://claude.ai/settings/usage"))
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 2)
        .onAppear { usage.refreshCodex() }
    }
}

// MARK: - Блок одного сервиса

private struct UsageProviderView: View {
    let name: String
    let usage: ProviderUsage?
    let now: Date
    let emptyHint: String
    let pageURL: URL?

    @State private var hovering = false

    private var hasLimits: Bool { usage?.fiveHour != nil || usage?.weekly != nil }

    /// «1.2M», «850K»
    static func tokenText(_ tokens: Int) -> String {
        if tokens >= 1_000_000 { return String(format: "%.1fM", Double(tokens) / 1_000_000) }
        if tokens >= 1_000 { return "\(tokens / 1_000)K" }
        return "\(tokens)"
    }

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            // Название и тариф
            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
                Text(usage?.plan?.capitalized ?? (hasLimits ? "" : " "))
                    .font(.system(size: 9))
                    .foregroundStyle(.white.opacity(0.4))
            }
            .frame(width: 42, alignment: .leading)

            if let usage, hasLimits {
                // Для Claude без прямых данных окна считает само приложение по калибровке — помечаем их «~»
                let estimate = usage.limitsAreEstimate == true
                VStack(spacing: 3) {
                    UsageRow(label: "5h", window: usage.fiveHour, now: now, approximate: estimate)
                    UsageRow(label: "Week", window: usage.weekly, now: now, approximate: estimate)
                }
            } else if let usage, let t5 = usage.tokens5h, let t7 = usage.tokens7d {
                // Настоящих лимитов нет (приложение Claude их не отдаёт). Шкала — расход относительно вашего рекордного окна
                VStack(spacing: 3) {
                    if let peak5 = usage.peak5h, peak5 > 0 {
                        UsageRow(
                            label: "5h", window: UsageWindow(usedPercent: Double(t5) / Double(peak5) * 100),
                            now: now, approximate: true, detail: Self.tokenText(t5))
                    } else {
                        TokenRow(label: "5h", tokens: t5)
                    }
                    if let peak7 = usage.peak7d, peak7 > 0 {
                        UsageRow(
                            label: "Week", window: UsageWindow(usedPercent: Double(t7) / Double(peak7) * 100),
                            now: now, approximate: true, detail: Self.tokenText(t7))
                    } else {
                        TokenRow(label: "Week", tokens: t7)
                    }
                }
            } else {
                Text(emptyHint)
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.35))
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
        .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(.white.opacity(hovering ? 0.07 : 0)))
        // Давно не обновлявшиеся данные тускнеют: цифра может быть устаревшей
        .opacity(isStale ? 0.55 : 1)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture { if let pageURL { NSWorkspace.shared.open(pageURL) } }
        .animation(.smooth(duration: 0.2), value: hovering)
        .help(helpText)
    }

    /// Данные старше часа
    private var isStale: Bool {
        guard let usage else { return false }
        let updated = hasLimits ? usage.updatedAt : (usage.tokensUpdatedAt ?? usage.updatedAt)
        return now.timeIntervalSince(updated) > 3600
    }

    private var helpText: String {
        guard let usage else { return "\(emptyHint). Click to open the usage page" }
        var lines: [String] = []
        if hasLimits {
            if let plan = usage.plan { lines.append("Plan: \(plan.capitalized)") }
            if let w = usage.fiveHour {
                lines.append("5h: \(Int(w.remaining(at: now).rounded()))% left\(resetText(w.resetsAt))")
            }
            if let w = usage.weekly {
                lines.append("Week: \(Int(w.remaining(at: now).rounded()))% left\(resetText(w.resetsAt))")
            }
            if usage.limitsAreEstimate == true {
                lines.append("Estimated from your local Claude Code usage, calibrated with claude.ai. Recalibrate in Settings → Advanced → Claude Limits.")
            } else {
                lines.append("The tick on the bar is where an even pace would be.")
            }
        } else if let t5 = usage.tokens5h, let t7 = usage.tokens7d {
            lines.append("Tokens used in Claude Code: \(t5.formatted()) in the last 5h, \(t7.formatted()) in the last 7 days.")
            if let p5 = usage.peak5h, let p7 = usage.peak7d {
                lines.append("The bar is an ESTIMATE: usage compared with your busiest windows of the last weeks (5h peak \(p5.formatted()), 7-day peak \(p7.formatted())). It is not the real plan limit.")
            }
            lines.append("Real remaining limits are not available: the Claude app does not expose them to other programs.")
        }
        let updated = hasLimits ? usage.updatedAt : (usage.tokensUpdatedAt ?? usage.updatedAt)
        let age = Int(now.timeIntervalSince(updated) / 60)
        let ageText = age < 1 ? "just now" : age < 60 ? "\(age) min ago" : age < 1440 ? "\(age / 60) h ago" : "\(age / 1440) d ago"
        lines.append("Updated \(ageText)" + (isStale ? " (may be outdated)" : ""))
        lines.append("Click to open the usage page")
        return lines.joined(separator: "\n")
    }

    private func resetText(_ date: Date?) -> String {
        guard let date, date > now else { return "" }
        return ", resets \(date.formatted(date: .abbreviated, time: .shortened))"
    }
}

// MARK: - Строка окна: шкала, остаток, время до сброса

private struct UsageRow: View {
    let label: String
    let window: UsageWindow?
    let now: Date
    /// Оценка (а не настоящий лимит): к проценту добавляется «~»
    var approximate = false
    /// Подпись справа вместо времени до сброса (например, расход токенов)
    var detail: String?

    /// Цвет шкалы по остатку: много — зелёный, меньше 60% — оранжевый, меньше 20% — красный
    private func color(remaining: Double) -> Color {
        if remaining < 20 { return Color(red: 1.0, green: 0.38, blue: 0.38) }
        if remaining < 60 { return Color(red: 1.0, green: 0.62, blue: 0.22) }
        return Color(red: 0.38, green: 0.84, blue: 0.56)
    }

    /// «4h 12m», «35m», «3d 4h»
    private func untilReset(_ date: Date) -> String {
        let minutes = max(0, Int(date.timeIntervalSince(now) / 60))
        if minutes >= 1440 { return "\(minutes / 1440)d \((minutes % 1440) / 60)h" }
        if minutes >= 60 { return "\(minutes / 60)h \(minutes % 60)m" }
        return "\(minutes)m"
    }

    var body: some View {
        HStack(spacing: 5) {
            Text(label)
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
                .frame(width: 28, alignment: .leading)

            if let window {
                let remaining = window.remaining(at: now)
                let expected = window.timeRemainingFraction(at: now).map { $0 * 100 }
                let tint = color(remaining: remaining)

                // Шкала остатка с меткой «равномерного темпа»
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.12))
                        Capsule()
                            .fill(tint)
                            .frame(width: max(2, geo.size.width * remaining / 100))
                        if let expected {
                            Rectangle()
                                .fill(.white.opacity(0.55))
                                .frame(width: 1, height: 7)
                                .offset(x: min(max(geo.size.width * expected / 100 - 0.5, 0), geo.size.width - 1))
                        }
                    }
                    .frame(maxHeight: .infinity, alignment: .center)
                }
                .frame(width: 78, height: 7)

                Text("\(approximate ? "~" : "")\(Int(remaining.rounded()))%")
                    .font(.system(size: 10.5, weight: .semibold).monospacedDigit())
                    .foregroundStyle(tint)
                    .frame(width: 32, alignment: .trailing)

                Text(detail ?? window.resetsAt.map { $0 > now ? untilReset($0) : "reset" } ?? "")
                    .font(.system(size: 9.5).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.38))
                    .frame(width: 40, alignment: .leading)
                    .lineLimit(1)
            } else {
                Text("—").font(.system(size: 10)).foregroundStyle(.white.opacity(0.3))
                Spacer(minLength: 0)
            }
        }
        .frame(height: 12)
    }
}

/// Строка расхода токенов (когда настоящих лимитов нет)
private struct TokenRow: View {
    let label: String
    let tokens: Int

    private var text: String {
        if tokens >= 1_000_000 { return String(format: "%.1fM", Double(tokens) / 1_000_000) }
        if tokens >= 1_000 { return "\(tokens / 1_000)K" }
        return "\(tokens)"
    }

    var body: some View {
        HStack(spacing: 5) {
            Text(label)
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
                .frame(width: 28, alignment: .leading)
            Text(text)
                .font(.system(size: 11, weight: .semibold).monospacedDigit())
                .foregroundStyle(.white.opacity(0.85))
            Text("tokens used")
                .font(.system(size: 9.5))
                .foregroundStyle(.white.opacity(0.38))
            Spacer(minLength: 0)
        }
        .frame(height: 12)
    }
}


// MARK: - Калибровка лимитов Claude (настройки)

/// Форма: вводите то, что сейчас показывает claude.ai → Настройки → Использование, и Chelka ведёт оба лимита сама
struct ClaudeCalibrationForm: View {
    @ObservedObject private var usage = UsageManager.shared

    @State private var sessionPercent = ""
    @State private var sessionReset = Date()
    @State private var weekPercent = ""
    @State private var weekday = 7
    @State private var weekTime = Calendar.current.date(bySettingHour: 7, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var message: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Claude does not share its limits with other apps. Open claude.ai → Settings → Usage and enter what it shows right now. Chelka will then track both limits on its own and mark them with ~. Recalibrate whenever the numbers drift (for example after using claude.ai chats).")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                Text("Session used")
                TextField("64", text: $sessionPercent).frame(width: 52).multilineTextAlignment(.trailing)
                Text("%")
                Spacer()
                Text("resets at")
                DatePicker("", selection: $sessionReset, displayedComponents: .hourAndMinute).labelsHidden()
            }
            HStack(spacing: 8) {
                Text("Week used")
                TextField("54", text: $weekPercent).frame(width: 52).multilineTextAlignment(.trailing)
                Text("%")
                Spacer()
                Text("resets on")
                Picker("", selection: $weekday) {
                    ForEach(1...7, id: \.self) { Text(Calendar.current.weekdaySymbols[$0 - 1]).tag($0) }
                }
                .labelsHidden().frame(width: 130)
                DatePicker("", selection: $weekTime, displayedComponents: .hourAndMinute).labelsHidden()
            }
            HStack(spacing: 10) {
                Button("Calibrate", action: calibrate).keyboardShortcut(.defaultAction)
                Button("Reset") { usage.resetClaudeCalibration(); message = "Calibration cleared" }
                    .disabled(usage.claudeCalibration == nil)
                Button("Open claude.ai usage") {
                    if let url = URL(string: "https://claude.ai/settings/usage") { NSWorkspace.shared.open(url) }
                }
                Spacer()
            }
            if let text = message ?? status {
                Text(text).font(.caption).foregroundStyle(.secondary)
            }
        }
        .onAppear(perform: load)
    }

    private var status: String? {
        guard let c = usage.claudeCalibration else { return "Not calibrated: Claude shows token usage only." }
        let when = c.capturedAt.formatted(date: .abbreviated, time: .shortened)
        if c.sessionCap == nil || c.weekCap == nil { return "Calibrated \(when). Waiting for usage history from Claude Code…" }
        return "Calibrated \(when)."
    }

    private func load() {
        guard let c = usage.claudeCalibration else { return }
        sessionPercent = String(Int(c.sessionPercent.rounded()))
        weekPercent = String(Int(c.weekPercent.rounded()))
        sessionReset = c.sessionResetAt
        weekday = c.weekResetWeekday
        weekTime = Calendar.current.date(bySettingHour: c.weekResetHour, minute: c.weekResetMinute, second: 0, of: Date()) ?? Date()
    }

    private func calibrate() {
        func percent(_ text: String) -> Double? {
            guard let v = Double(text.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces)),
                  v >= 1, v <= 100 else { return nil }
            return v
        }
        guard let session = percent(sessionPercent), let week = percent(weekPercent) else {
            message = "Enter both percentages as numbers from 1 to 100."
            return
        }
        // Время сброса сессии — ближайшее такое время (сегодня или завтра)
        let calendar = Calendar.current
        let hm = calendar.dateComponents([.hour, .minute], from: sessionReset)
        var reset = calendar.date(bySettingHour: hm.hour ?? 0, minute: hm.minute ?? 0, second: 0, of: Date()) ?? Date()
        if reset < Date().addingTimeInterval(-60) { reset = reset.addingTimeInterval(86400) }
        let wt = calendar.dateComponents([.hour, .minute], from: weekTime)
        usage.calibrateClaude(ClaudeCalibration(
            sessionPercent: session, sessionResetAt: reset, weekPercent: week,
            weekResetWeekday: weekday, weekResetHour: wt.hour ?? 7, weekResetMinute: wt.minute ?? 0,
            capturedAt: Date()))
        message = nil
    }
}
