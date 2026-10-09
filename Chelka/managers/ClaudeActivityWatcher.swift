//
//  ClaudeActivityWatcher.swift
//  Chelka
//
//  Подстраховка для Claude Code: находит работающие сессии по их логам (~/.claude/projects),
//  если хук ещё не успел о них сообщить — например, после перезапуска Chelka посреди долгой задачи.
//  Обычно сессии приходят через хуки, наблюдатель только подхватывает пропущенные.
//

import Foundation

@MainActor
final class ClaudeActivityWatcher {
    static let shared = ClaudeActivityWatcher()

    private var timer: Timer?

    func start() {
        guard timer == nil else { return }
        poll()
        timer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.poll() }
        }
    }

    private struct Candidate {
        let id: String
        let path: String
        let cwd: String?
    }

    private func poll() {
        Task.detached(priority: .utility) {
            let candidates = Self.scan()
            await MainActor.run { self.apply(candidates) }
        }
    }

    private func apply(_ candidates: [Candidate]) {
        let manager = AgentActivityManager.shared
        for candidate in candidates {
            // Уже известна как работающая или ждущая — хуки сами ведут её состояние
            if let status = manager.status(of: candidate.id), status == .running || status == .waiting { continue }
            // Только что завершилась по хуку: лог ещё может дописываться, повторно не поднимаем
            if manager.status(of: candidate.id) == .done || manager.status(of: candidate.id) == .error { continue }
            manager.report(
                id: candidate.id, agent: "Claude Code", status: .running, task: nil,
                project: candidate.cwd.map { ($0 as NSString).lastPathComponent }, cwd: candidate.cwd,
                transcript: candidate.path)
        }
    }

    // MARK: - Чтение логов (в фоновом потоке)

    nonisolated private static func scan() -> [Candidate] {
        let root = URL(fileURLWithPath: CodexSessionFiles.realHome).appendingPathComponent(".claude/projects")
        let fm = FileManager.default
        guard let folders = try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: nil) else { return [] }
        let now = Date()
        var result: [Candidate] = []

        for folder in folders {
            guard let files = try? fm.contentsOfDirectory(
                at: folder, includingPropertiesForKeys: [.contentModificationDateKey]) else { continue }
            for file in files where file.pathExtension == "jsonl" {
                // Лог менялся недавно: работающий Claude Code пишет в него каждые несколько секунд
                guard let modified = try? file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate,
                      now.timeIntervalSince(modified) < 45 else { continue }
                // Ход ещё идёт (последняя запись — не конец ответа и не прерывание)
                guard !AgentActivityManager.turnFinished(transcript: file.path) else { continue }
                let id = file.deletingPathExtension().lastPathComponent
                result.append(Candidate(id: id, path: file.path, cwd: cwd(in: file)))
            }
        }
        return result
    }

    /// Рабочая папка сессии: поле cwd в первых записях лога
    nonisolated private static func cwd(in file: URL) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: file) else { return nil }
        defer { try? handle.close() }
        guard let data = try? handle.read(upToCount: 64 * 1024), let text = String(data: data, encoding: .utf8) else { return nil }
        for line in text.split(separator: "\n").prefix(40) {
            if let object = try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any],
               let cwd = object["cwd"] as? String { return cwd }
        }
        return nil
    }
}
