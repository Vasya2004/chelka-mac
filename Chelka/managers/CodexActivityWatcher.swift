//
//  CodexActivityWatcher.swift
//  boringNotch
//
//  Определяет работу Codex по логам его сессий (~/.codex/sessions): события task_started и task_complete.
//  Работает без хуков (их Codex пропускает, пока пользователь не одобрит), в терминале и в приложении.
//

import Foundation

@MainActor
final class CodexActivityWatcher {
    static let shared = CodexActivityWatcher()

    private var timer: Timer?
    /// Последнее состояние каждой сессии, о котором мы сообщили
    private var known: [String: AgentStatus] = [:]
    /// Когда мы в последний раз напоминали менеджеру, что сессия ещё работает
    private var heartbeat: [String: Date] = [:]

    func start() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.poll() }
        }
    }

    private struct Snapshot {
        let id: String
        let status: AgentStatus
        let project: String?
        let cwd: String?
    }

    private func poll() {
        Task.detached(priority: .utility) {
            let snapshots = Self.scan()
            await MainActor.run { self.apply(snapshots) }
        }
    }

    private func apply(_ snapshots: [Snapshot]) {
        let manager = AgentActivityManager.shared
        var seen = Set<String>()

        for snap in snapshots {
            seen.insert(snap.id)
            let previous = known[snap.id]
            switch snap.status {
            case .running where previous != .running:
                heartbeat[snap.id] = Date()
                // Новый ход: возвращает и сессию, которую пользователь убрал из списка
                manager.report(id: snap.id, agent: "Codex", status: .running, task: nil, project: snap.project, cwd: snap.cwd, revive: true)
            case .done where previous == .running:
                // «Закончил» показываем только если видели, как он работал (иначе это старая сессия)
                manager.report(id: snap.id, agent: "Codex", status: .done, task: nil, project: snap.project, cwd: snap.cwd)
            case .end where previous == .running:
                manager.report(id: snap.id, agent: "Codex", status: .idle, task: nil, project: snap.project, cwd: snap.cwd)
            case .running where previous == .running:
                // Долгий ход: раз в минуту подтверждаем «работает», чтобы запись в менеджере не истекла до завершения.
                // Если менеджер при этом считает сессию неактивной, поправляем сразу: лог говорит, что она работает
                let managed = manager.status(of: snap.id)
                if managed != .running && managed != .waiting
                    || Date().timeIntervalSince(heartbeat[snap.id] ?? .distantPast) > 60 {
                    heartbeat[snap.id] = Date()
                    manager.report(id: snap.id, agent: "Codex", status: .running, task: nil, project: snap.project, cwd: snap.cwd)
                }
            default:
                break
            }
            known[snap.id] = snap.status
        }

        // Лог давно не менялся (сессия закрыта): если она «работала», убираем из индикатора
        for (id, status) in known where !seen.contains(id) {
            if status == .running {
                manager.report(id: id, agent: "Codex", status: .idle, task: nil, project: nil, cwd: nil)
            }
            known[id] = nil
        }
    }

    // MARK: - Чтение логов (в фоновом потоке)

    nonisolated private static func scan() -> [Snapshot] {
        let now = Date()
        // Логи, менявшиеся за последние 15 минут (папка дня создания сессии значения не имеет)
        let files = CodexSessionFiles.recent(maxAge: 15 * 60).map { ($0.url, $0.modified) }

        return files.compactMap { file, modified -> Snapshot? in
            guard let state = lastLifecycleEvent(in: file) else { return nil }
            var status: AgentStatus
            switch state {
            case "task_started":
                // Если лог давно не обновлялся, считаем, что сессию прервали
                status = now.timeIntervalSince(modified) > 180 ? .end : .running
            case "task_complete": status = .done
            default: status = .end
            }
            let meta = sessionMeta(in: file)
            let base = file.deletingPathExtension().lastPathComponent
            // rollout-ДАТА-ВРЕМЯ-<uuid сессии>: берём последние 36 символов, это тот же идентификатор, что присылают хуки
            let sessionID = base.count >= 36 ? String(base.suffix(36)) : base
            return Snapshot(
                id: "codex:\(sessionID)", status: status,
                project: meta.cwd.map { ($0 as NSString).lastPathComponent }, cwd: meta.cwd)
        }
    }

    /// Последнее событие жизненного цикла в «хвосте» файла: task_started / task_complete / turn_aborted
    nonisolated private static func lastLifecycleEvent(in file: URL) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: file) else { return nil }
        defer { try? handle.close() }
        let size = (try? handle.seekToEnd()) ?? 0
        let wanted: Set<String> = ["task_started", "task_complete", "turn_aborted"]

        // Сначала небольшой хвост, при необходимости читаем глубже
        for chunk in [UInt64(96 * 1024), UInt64(768 * 1024)] {
            try? handle.seek(toOffset: size > chunk ? size - chunk : 0)
            guard let data = try? handle.readToEnd(), let text = String(data: data, encoding: .utf8) else { continue }
            for line in text.split(separator: "\n").reversed() where line.count < 20_000 {
                guard line.contains("task_") || line.contains("turn_aborted") else { continue }
                guard let object = try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any],
                      object["type"] as? String == "event_msg",
                      let payload = object["payload"] as? [String: Any],
                      let type = payload["type"] as? String, wanted.contains(type) else { continue }
                return type
            }
            if size <= chunk { break }
        }
        return nil
    }

    /// Рабочая папка сессии из первой строки лога (session_meta)
    nonisolated private static func sessionMeta(in file: URL) -> (cwd: String?, Void) {
        guard let handle = try? FileHandle(forReadingFrom: file) else { return (nil, ()) }
        defer { try? handle.close() }
        guard let data = try? handle.read(upToCount: 64 * 1024), let text = String(data: data, encoding: .utf8),
              let first = text.split(separator: "\n").first,
              let object = try? JSONSerialization.jsonObject(with: Data(first.utf8)) as? [String: Any],
              let payload = object["payload"] as? [String: Any] else { return (nil, ()) }
        return (payload["cwd"] as? String, ())
    }
}
