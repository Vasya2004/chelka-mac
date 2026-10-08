//
//  UsageManager.swift
//  boringNotch
//
//  Остаток лимитов ИИ-сервисов (окно 5 часов и неделя) для полосы на главном экране открытой «чёлки».
//  Codex: читаем последний лог его сессии (~/.codex/sessions). Claude Code: данные присылает скрипт строки состояния.
//

import Foundation
import SwiftUI

/// Одно окно лимита: сколько израсходовано и когда сбросится
struct UsageWindow: Codable, Equatable {
    var usedPercent: Double
    var resetsAt: Date?
    /// Длина окна в минутах (300 — 5 часов, 10080 — неделя)
    var windowMinutes: Int?

    /// Сколько времени окна ещё осталось (1 — окно только началось, 0 — вот-вот сбросится)
    func timeRemainingFraction(at now: Date = Date()) -> Double? {
        guard let resetsAt, let minutes = windowMinutes, minutes > 0 else { return nil }
        return min(max(resetsAt.timeIntervalSince(now) / (Double(minutes) * 60), 0), 1)
    }

    /// Если окно уже сбросилось, расход считается нулевым
    func effectiveUsed(at now: Date = Date()) -> Double {
        if let resetsAt, resetsAt <= now { return 0 }
        return min(max(usedPercent, 0), 100)
    }

    func remaining(at now: Date = Date()) -> Double { 100 - effectiveUsed(at: now) }
}

struct ProviderUsage: Codable, Equatable {
    var fiveHour: UsageWindow?
    var weekly: UsageWindow?
    var plan: String?
    var updatedAt: Date
    /// Израсходованные токены за 5 часов и за неделю (когда настоящих лимитов нет)
    var tokens5h: Int?
    var tokens7d: Int?
    var tokensUpdatedAt: Date?
    /// Самое «тяжёлое» ваше окно (5 часов / 7 дней) за последние недели — масштаб для шкалы, когда настоящих лимитов нет
    var peak5h: Int?
    var peak7d: Int?
    /// true — окна посчитаны приложением по локальному расходу и калибровке, а не получены от Claude
    var limitsAreEstimate: Bool?
}

/// Калибровка оценки лимитов Claude: что показывал claude.ai в момент `capturedAt`
struct ClaudeCalibration: Codable, Equatable {
    /// Использовано в текущей 5-часовой сессии, % (как на claude.ai)
    var sessionPercent: Double
    /// Когда сбросится сессия (на момент калибровки)
    var sessionResetAt: Date
    /// Использовано за неделю, %
    var weekPercent: Double
    /// День недели сброса (1 — воскресенье … 7 — суббота) и время
    var weekResetWeekday: Int
    var weekResetHour: Int
    var weekResetMinute: Int
    var capturedAt: Date
    /// Сколько токенов соответствует 100% (вычисляется по истории расхода)
    var sessionCap: Double?
    var weekCap: Double?
}

/// Поиск логов сессий Codex. Файл лежит в папке дня, когда сессию создали, а продолжаться может днями,
/// поэтому свежесть определяем по времени изменения файла, а не по дате папки.
enum CodexSessionFiles {
    nonisolated static var realHome: String {
        if let pw = getpwuid(getuid()), let dir = pw.pointee.pw_dir { return String(cString: dir) }
        return NSHomeDirectory()
    }

    /// Логи, менявшиеся за последние `maxAge` секунд (или просто самые свежие, если `maxAge` не задан), от новых к старым
    nonisolated static func recent(maxAge: TimeInterval? = nil, limit: Int = 12) -> [(url: URL, modified: Date)] {
        let root = URL(fileURLWithPath: realHome).appendingPathComponent(".codex/sessions")
        let fm = FileManager.default
        let now = Date()

        func children(_ url: URL) -> [URL] {
            ((try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)) ?? [])
                .sorted { $0.lastPathComponent > $1.lastPathComponent }
        }

        // Просматриваем папки примерно за последние 3 недели
        var found: [(url: URL, modified: Date)] = []
        var days = 0
        outer: for year in children(root) {
            for month in children(year) {
                for day in children(month) {
                    for file in children(day) where file.pathExtension == "jsonl" {
                        let modified = (try? file.resourceValues(forKeys: [.contentModificationDateKey]))?
                            .contentModificationDate ?? .distantPast
                        if let maxAge, now.timeIntervalSince(modified) > maxAge { continue }
                        found.append((file, modified))
                    }
                    days += 1
                    if days >= 21 { break outer }
                }
            }
        }
        return Array(found.sorted { $0.modified > $1.modified }.prefix(limit))
    }
}

@MainActor
final class UsageManager: ObservableObject {
    static let shared = UsageManager()

    @Published private(set) var codex: ProviderUsage?
    @Published private(set) var claude: ProviderUsage?
    @Published private(set) var claudeCalibration: ClaudeCalibration?
    /// История расхода токенов Claude Code: (начало интервала, токены), от старых к новым
    private var claudeEvents: [(t: Double, tokens: Int)] = []

    private var timer: Timer?
    private let storeKey = "aiUsageSnapshot.v1"
    private let calibrationKey = "claudeCalibration.v1"
    private let eventsKey = "claudeEvents.v1"

    private struct Snapshot: Codable {
        var codex: ProviderUsage?
        var claude: ProviderUsage?
    }

    func start() {
        guard timer == nil else { return }
        load()
        loadClaudeState()
        refreshCodex()
        recomputeClaude()
        timer = Timer.scheduledTimer(withTimeInterval: 45, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshCodex()
                self?.recomputeClaude()   // сессия могла закончиться — окна пересчитываются со временем
            }
        }
    }

    // MARK: - Сохранение последних известных значений

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storeKey),
              let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) else { return }
        codex = snapshot.codex
        claude = snapshot.claude
    }

    private func loadClaudeState() {
        let defaults = UserDefaults.standard
        if let data = defaults.data(forKey: calibrationKey),
           let value = try? JSONDecoder().decode(ClaudeCalibration.self, from: data) { claudeCalibration = value }
        if let data = defaults.data(forKey: eventsKey),
           let raw = try? JSONDecoder().decode([[Double]].self, from: data) {
            claudeEvents = raw.compactMap { $0.count == 2 ? (t: $0[0], tokens: Int($0[1])) : nil }
        }
    }

    private func saveClaudeState() {
        let defaults = UserDefaults.standard
        if let calibration = claudeCalibration, let data = try? JSONEncoder().encode(calibration) { defaults.set(data, forKey: calibrationKey) }
        else { defaults.removeObject(forKey: calibrationKey) }
        if let data = try? JSONEncoder().encode(claudeEvents.map { [$0.t, Double($0.tokens)] }) { defaults.set(data, forKey: eventsKey) }
    }

    private func save() {
        let snapshot = Snapshot(codex: codex, claude: claude)
        if let data = try? JSONEncoder().encode(snapshot) {
            UserDefaults.standard.set(data, forKey: storeKey)
        }
    }

    // MARK: - Claude Code (данные присылает скрипт строки состояния на /usage)

    /// Тело запроса: {"provider":"claude","rate_limits":{"five_hour":{"used_percentage":7,"resets_at":1783779600},"seven_day":{...}}}
    func ingest(_ body: Data) {
        guard let root = try? JSONSerialization.jsonObject(with: body) as? [String: Any] else { return }

        // Расход токенов: обновляем только его, лимиты (если есть) не трогаем
        if let activity = root["activity"] as? [String: Any] {
            var usage = claude ?? ProviderUsage(fiveHour: nil, weekly: nil, plan: nil, updatedAt: Date())
            usage.tokens5h = (activity["tokens_5h"] as? NSNumber)?.intValue
            usage.tokens7d = (activity["tokens_7d"] as? NSNumber)?.intValue
            usage.peak5h = (activity["peak_5h"] as? NSNumber)?.intValue
            usage.peak7d = (activity["peak_7d"] as? NSNumber)?.intValue
            usage.tokensUpdatedAt = Date()
            claude = usage
            save()
            if let raw = activity["events"] as? [[NSNumber]] {
                claudeEvents = raw.compactMap { $0.count == 2 ? (t: $0[0].doubleValue, tokens: $0[1].intValue) : nil }
                    .sorted { $0.t < $1.t }
                saveClaudeState()
                recomputeClaude()
            }
            return
        }

        guard let limits = root["rate_limits"] as? [String: Any] else { return }

        func window(_ key: String) -> UsageWindow? {
            guard let dict = limits[key] as? [String: Any],
                  let used = (dict["used_percentage"] as? NSNumber)?.doubleValue else { return nil }
            var resets: Date?
            if let seconds = (dict["resets_at"] as? NSNumber)?.doubleValue {
                resets = Date(timeIntervalSince1970: seconds)
            } else if let iso = dict["resets_at"] as? String {
                resets = ISO8601DateFormatter().date(from: iso)
            }
            return UsageWindow(usedPercent: used, resetsAt: resets, windowMinutes: key == "five_hour" ? 300 : 10080)
        }

        var usage = ProviderUsage(fiveHour: window("five_hour"), weekly: window("seven_day"), plan: nil, updatedAt: Date())
        guard usage.fiveHour != nil || usage.weekly != nil else { return }
        usage.tokens5h = claude?.tokens5h
        usage.tokens7d = claude?.tokens7d
        usage.tokensUpdatedAt = claude?.tokensUpdatedAt
        usage.peak5h = claude?.peak5h
        usage.peak7d = claude?.peak7d
        usage.limitsAreEstimate = false
        claude = usage
        save()
    }

    // MARK: - Оценка лимитов Claude по локальному расходу и калибровке

    private func tokens(from start: Double, to end: Double) -> Int {
        claudeEvents.reduce(0) { $0 + ($1.t >= start && $1.t < end ? $1.tokens : 0) }
    }

    /// Последний момент не позже `date`, когда была заданная неделя/час/минута (начало текущей недели лимита)
    private func lastWeekAnchor(before date: Date, weekday: Int, hour: Int, minute: Int) -> Date? {
        var components = DateComponents(); components.weekday = weekday; components.hour = hour; components.minute = minute
        return Calendar.current.nextDate(after: date.addingTimeInterval(1), matching: components,
                                         matchingPolicy: .nextTime, direction: .backward)
    }

    /// Сохраняет калибровку и вычисляет, сколько токенов соответствует 100% сессии и недели
    func calibrateClaude(_ input: ClaudeCalibration) {
        var calibration = input
        let captured = input.capturedAt.timeIntervalSince1970
        // сессия: от (сброс − 5 часов) до момента калибровки
        let sessionStart = input.sessionResetAt.timeIntervalSince1970 - 5 * 3600
        let sessionTokens = tokens(from: sessionStart, to: captured + 1)
        calibration.sessionCap = input.sessionPercent >= 1 && sessionTokens > 0 ? Double(sessionTokens) / (input.sessionPercent / 100) : nil
        // неделя: от последнего якоря до момента калибровки
        if let anchor = lastWeekAnchor(before: input.capturedAt, weekday: input.weekResetWeekday,
                                       hour: input.weekResetHour, minute: input.weekResetMinute) {
            let weekTokens = tokens(from: anchor.timeIntervalSince1970, to: captured + 1)
            calibration.weekCap = input.weekPercent >= 1 && weekTokens > 0 ? Double(weekTokens) / (input.weekPercent / 100) : nil
        }
        claudeCalibration = calibration
        saveClaudeState()
        recomputeClaude()
    }

    func resetClaudeCalibration() {
        claudeCalibration = nil
        saveClaudeState()
        if claude?.limitsAreEstimate == true { claude?.fiveHour = nil; claude?.weekly = nil; claude?.limitsAreEstimate = nil; save() }
    }

    /// Пересчитывает окна Claude (сессию 5 часов и неделю) по истории расхода
    func recomputeClaude() {
        guard let calibration = claudeCalibration else { return }
        // Если от Claude Code приходят настоящие лимиты, оценка им не мешает
        if let real = claude, real.limitsAreEstimate == false, real.fiveHour != nil,
           Date().timeIntervalSince(real.updatedAt) < 900 { return }
        // Масштаб мог не вычислиться (не было истории) — пробуем ещё раз
        if (calibration.sessionCap == nil || calibration.weekCap == nil), !claudeEvents.isEmpty {
            calibrateClaude(calibration); return
        }
        let now = Date().timeIntervalSince1970

        // Сессия: сначала известная из калибровки, затем каждая следующая начинается с первого сообщения после сброса
        var start = calibration.sessionResetAt.timeIntervalSince1970 - 5 * 3600
        var reset = calibration.sessionResetAt.timeIntervalSince1970
        var sessionActive = true
        while now >= reset {
            guard let next = claudeEvents.first(where: { $0.t >= reset }) else { sessionActive = false; break }
            start = next.t; reset = start + 5 * 3600
        }
        var five: UsageWindow?
        if let cap = calibration.sessionCap, cap > 0 {
            if sessionActive {
                let used = min(100, Double(tokens(from: start, to: min(now, reset) + 1)) / cap * 100)
                five = UsageWindow(usedPercent: used, resetsAt: Date(timeIntervalSince1970: reset), windowMinutes: 300)
            } else {
                five = UsageWindow(usedPercent: 0, resetsAt: nil, windowMinutes: 300)   // сессии нет — до первого сообщения
            }
        }

        // Неделя
        var week: UsageWindow?
        if let cap = calibration.weekCap, cap > 0,
           let anchor = lastWeekAnchor(before: Date(), weekday: calibration.weekResetWeekday,
                                       hour: calibration.weekResetHour, minute: calibration.weekResetMinute) {
            let used = min(100, Double(tokens(from: anchor.timeIntervalSince1970, to: now + 1)) / cap * 100)
            week = UsageWindow(usedPercent: used, resetsAt: anchor.addingTimeInterval(7 * 86400), windowMinutes: 10080)
        }

        guard five != nil || week != nil else { return }
        var usage = claude ?? ProviderUsage(fiveHour: nil, weekly: nil, plan: nil, updatedAt: Date())
        usage.fiveHour = five
        usage.weekly = week
        usage.limitsAreEstimate = true
        usage.updatedAt = Date()
        if usage != claude { claude = usage; save() }
    }

    // MARK: - Codex (чтение последнего лога сессии)

    /// Перечитать лог Codex (вызывается при открытии «чёлки» и по таймеру)
    func refreshCodex() {
        Task.detached(priority: .utility) {
            let usage = Self.readLatestCodexUsage()
            await MainActor.run {
                guard let usage, usage != self.codex else { return }
                self.codex = usage
                self.save()
            }
        }
    }

    /// Настоящая домашняя папка (внутри песочницы NSHomeDirectory указывает на контейнер)
    nonisolated private static var realHome: String {
        if let pw = getpwuid(getuid()), let dir = pw.pointee.pw_dir { return String(cString: dir) }
        return NSHomeDirectory()
    }

    nonisolated private static func readLatestCodexUsage() -> ProviderUsage? {
        // Самые свежие по времени изменения логи: ищем в них последнюю запись с лимитами
        for file in CodexSessionFiles.recent(limit: 6) {
            if let usage = lastRateLimits(in: file.url) { return usage }
        }
        return nil
    }

    /// Читает «хвост» файла (последние ~512 КБ) и разбирает последнюю запись с rate_limits
    nonisolated private static func lastRateLimits(in file: URL) -> ProviderUsage? {
        guard let handle = try? FileHandle(forReadingFrom: file) else { return nil }
        defer { try? handle.close() }
        let size = (try? handle.seekToEnd()) ?? 0
        let chunk: UInt64 = 512 * 1024
        try? handle.seek(toOffset: size > chunk ? size - chunk : 0)
        guard let data = try? handle.readToEnd(), let text = String(data: data, encoding: .utf8) else { return nil }

        for line in text.split(separator: "\n").reversed() where line.contains("\"rate_limits\"") {
            guard let obj = try? JSONSerialization.jsonObject(with: Data(line.utf8)),
                  let limits = findRateLimits(in: obj) else { continue }

            func window(_ key: String) -> (UsageWindow, Int?)? {
                guard let dict = limits[key] as? [String: Any],
                      let used = (dict["used_percent"] as? NSNumber)?.doubleValue else { return nil }
                let resets = (dict["resets_at"] as? NSNumber).map { Date(timeIntervalSince1970: $0.doubleValue) }
                let minutes = (dict["window_minutes"] as? NSNumber)?.intValue
                return (UsageWindow(usedPercent: used, resetsAt: resets, windowMinutes: minutes), minutes)
            }

            var five: UsageWindow?
            var week: UsageWindow?
            for key in ["primary", "secondary"] {
                guard let (window, minutes) = window(key) else { continue }
                // Окно определяем по длине: до 6 часов — «5 часов», больше — «неделя»
                if let minutes, minutes > 360 { week = window } else { five = window }
            }
            guard five != nil || week != nil else { continue }

            var updated = Date()
            if let dict = try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any],
               let stamp = dict["timestamp"] as? String,
               let date = ISO8601DateFormatter.withFraction.date(from: stamp) {
                updated = date
            }
            return ProviderUsage(fiveHour: five, weekly: week, plan: limits["plan_type"] as? String, updatedAt: updated)
        }
        return nil
    }

    nonisolated private static func findRateLimits(in object: Any) -> [String: Any]? {
        if let dict = object as? [String: Any] {
            if let limits = dict["rate_limits"] as? [String: Any] { return limits }
            for value in dict.values { if let found = findRateLimits(in: value) { return found } }
        } else if let array = object as? [Any] {
            for value in array { if let found = findRateLimits(in: value) { return found } }
        }
        return nil
    }
}

private extension ISO8601DateFormatter {
    static let withFraction: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}
