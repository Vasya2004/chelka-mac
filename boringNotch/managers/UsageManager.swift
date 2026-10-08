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

    private var timer: Timer?
    private let storeKey = "aiUsageSnapshot.v1"

    private struct Snapshot: Codable {
        var codex: ProviderUsage?
        var claude: ProviderUsage?
    }

    func start() {
        guard timer == nil else { return }
        load()
        refreshCodex()
        timer = Timer.scheduledTimer(withTimeInterval: 45, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshCodex() }
        }
    }

    // MARK: - Сохранение последних известных значений

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storeKey),
              let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) else { return }
        codex = snapshot.codex
        claude = snapshot.claude
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
        claude = usage
        save()
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
