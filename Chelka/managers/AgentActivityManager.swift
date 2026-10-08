//
//  AgentActivityManager.swift
//  boringNotch
//
//  Состояние ИИ-агентов (Claude Code и др.). Агенты сообщают о себе короткими
//  HTTP-запросами на 127.0.0.1, приложение показывает активность в «чёлке».
//

import Foundation
import Network
import AppKit
import Defaults
import SwiftUI

enum AgentStatus: String, Codable {
    case running
    case waiting
    case done
    case error
    case end   // сессия закрыта — убрать из индикатора

    /// Чем выше число, тем важнее статус для показа в «чёлке»
    var priority: Int {
        switch self {
        case .waiting: return 4
        case .error: return 3
        case .running: return 2
        case .done: return 1
        case .end: return 0
        }
    }
}

/// Единый внешний вид статусов для закрытой и открытой «чёлки»
extension AgentStatus {
    /// Работа — нейтральный белый, цветные акценты только там, где нужно внимание
    var tint: Color {
        switch self {
        case .running: return Color.white.opacity(0.92)
        case .waiting: return Color(red: 1.0, green: 0.72, blue: 0.26)
        case .done: return Color(red: 0.38, green: 0.84, blue: 0.56)
        case .error: return Color(red: 1.0, green: 0.42, blue: 0.42)
        case .end: return .gray
        }
    }

    var symbol: String {
        switch self {
        case .running: return "sparkle"
        case .waiting: return "hand.raised.fill"
        case .done: return "checkmark"
        case .error: return "exclamationmark"
        case .end: return "circle"
        }
    }

    var label: String {
        switch self {
        case .running: return "Working"
        case .waiting: return "Waiting"
        case .done: return "Done"
        case .error: return "Error"
        case .end: return ""
        }
    }
}

struct AgentSession: Identifiable, Equatable {
    let id: String
    var agent: String
    var status: AgentStatus
    var task: String?
    var project: String?
    var updatedAt: Date
    /// Когда агент перешёл в текущее состояние
    var since: Date
    /// Цепочка родительских процессов агента (от ближайшего к дальнему) — по ней находим приложение с окном
    var hostPIDs: [Int] = []
    /// tty терминала, где идёт сессия (для точного перехода на вкладку Terminal/iTerm2)
    var tty: String?
    /// Рабочая папка (для перехода в окно проекта в IDE)
    var cwd: String?
}

/// Событие, которое «разворачивает» чёлку: агент закончил, упал или ждёт вас
struct AgentBanner: Identifiable, Equatable {
    let id = UUID()
    let sessionID: String
    let agent: String
    let project: String?
    let task: String?
    let status: AgentStatus
}

/// Запрос разрешения от агента: ждёт ответа пользователя в «чёлке»
struct AgentPermissionRequest: Identifiable, Equatable {
    let id = UUID()
    let sessionID: String
    let agent: String
    let project: String?
    let tool: String
    let detail: String
    let createdAt = Date()
}

/// Тело запроса /permission: {"id":"session","agent":"Claude Code","project":"...","tool":"Bash","detail":"rm -rf x"}
private struct PermissionPayload: Decodable {
    var id: String
    var agent: String?
    var project: String?
    var tool: String
    var detail: String?
    var cwd: String?
    var pids: [Int]?
    var tty: String?
}

/// Разобранный HTTP-запрос вместе с соединением (для отложенного ответа)
private struct HTTPRequest: @unchecked Sendable {
    let path: String
    let body: Data
    let connection: NWConnection
}

/// Формат тела запроса: {"id":"...","agent":"Claude Code","status":"running","task":"...","project":"..."}
private struct AgentEvent: Decodable {
    var id: String
    var agent: String?
    var status: AgentStatus
    var task: String?
    var project: String?
    var cwd: String?
    var pids: [Int]?
    var tty: String?
}

@MainActor
final class AgentActivityManager: ObservableObject {
    static let shared = AgentActivityManager()
    static let port: UInt16 = 48217

    @Published private(set) var sessions: [String: AgentSession] = [:]
    /// Растёт на каждое «рабочее» событие агента (шаг, инструмент): по нему значок пускает волну
    @Published private(set) var activityPulse = 0
    /// Текущее «развёрнутое» уведомление (nil — чёлка в обычном размере)
    @Published private(set) var banner: AgentBanner?
    private var bannerTask: Task<Void, Never>?
    private var lastCompletionSound = Date.distantPast

    /// Запросы разрешений, ожидающие ответа (самый старый показывается первым)
    @Published private(set) var pendingPermissions: [AgentPermissionRequest] = []
    private var permissionConnections: [UUID: NWConnection] = [:]
    var currentPermission: AgentPermissionRequest? { pendingPermissions.first }

    private var listener: NWListener?
    private var expiryTasks: [String: Task<Void, Never>] = [:]

    /// Агент, которого нужно показать: сначала тот, кому нужно внимание, затем самый свежий
    var primary: AgentSession? {
        sessions.values.max { a, b in
            a.status.priority != b.status.priority
                ? a.status.priority < b.status.priority
                : a.updatedAt < b.updatedAt
        }
    }

    var count: Int { sessions.count }

    /// Список для открытой «чёлки»: сначала те, кому нужно внимание, затем по свежести
    var orderedSessions: [AgentSession] {
        sessions.values.sorted {
            $0.status.priority != $1.status.priority
                ? $0.status.priority > $1.status.priority
                : $0.updatedAt > $1.updatedAt
        }
    }

    /// Событие из внешнего источника внутри приложения (например, наблюдатель за логами Codex)
    func report(id: String, agent: String, status: AgentStatus, task: String?, project: String?, cwd: String?) {
        apply(AgentEvent(id: id, agent: agent, status: status, task: task, project: project, cwd: cwd, pids: nil, tty: nil))
    }

    /// Перейти в приложение и окно, где работает агент (клик по агенту)
    func jump(to sessionID: String) {
        guard let session = sessions[sessionID] else { return }
        if banner?.sessionID == sessionID { hideBanner() }
        AgentJumper.jump(to: session)
    }

    /// Убрать агента из списка вручную
    func remove(_ id: String) {
        if banner?.sessionID == id { hideBanner() }
        expiryTasks[id]?.cancel()
        withAnimation(.smooth(duration: 0.3)) { _ = sessions.removeValue(forKey: id) }
    }

    // MARK: - Сервер

    func start() {
        guard listener == nil else { return }
        let parameters = NWParameters.tcp
        // Только локальная петля: снаружи достучаться до сервера нельзя
        parameters.requiredInterfaceType = .loopback
        guard let port = NWEndpoint.Port(rawValue: Self.port),
              let listener = try? NWListener(using: parameters, on: port) else { return }

        listener.newConnectionHandler = { [weak self] connection in
            connection.start(queue: .global(qos: .userInitiated))
            Self.receive(on: connection, buffer: Data()) { request in
                guard let request else { return }
                Task { @MainActor in self?.route(request) }
            }
        }
        listener.start(queue: .global(qos: .userInitiated))
        self.listener = listener
    }

    /// Читает HTTP-запрос до конца тела и отдаёт путь, тело и соединение (ответ отправляет вызывающий)
    nonisolated private static func receive(
        on connection: NWConnection, buffer: Data, completion: @escaping @Sendable (HTTPRequest?) -> Void
    ) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 262_144) { data, _, isComplete, error in
            var buffer = buffer
            if let data { buffer.append(data) }

            let separator = Data("\r\n\r\n".utf8)
            if let range = buffer.range(of: separator) {
                let head = String(decoding: buffer[..<range.lowerBound], as: UTF8.self)
                let lowered = head.lowercased()
                let contentLength = lowered.split(separator: "\r\n")
                    .first { $0.hasPrefix("content-length:") }
                    .flatMap { Int($0.dropFirst("content-length:".count).trimmingCharacters(in: .whitespaces)) } ?? 0
                let body = buffer[range.upperBound...]

                if body.count >= contentLength {
                    // Первая строка: "POST /agent HTTP/1.1"
                    let parts = head.split(separator: "\r\n").first?.split(separator: " ") ?? []
                    let path = parts.count > 1 ? String(parts[1]) : "/"
                    completion(HTTPRequest(path: path, body: Data(body.prefix(contentLength)), connection: connection))
                    return
                }
            }

            if error != nil || isComplete || buffer.count > 524_288 {
                connection.cancel()
                completion(nil)
                return
            }
            receive(on: connection, buffer: buffer, completion: completion)
        }
    }

    nonisolated private static func respond(_ connection: NWConnection, status: String, body: String = "") {
        let response = "HTTP/1.1 \(status)\r\nContent-Type: application/json\r\nContent-Length: \(body.utf8.count)\r\nConnection: close\r\n\r\n\(body)"
        connection.send(content: Data(response.utf8), completion: .contentProcessed { _ in connection.cancel() })
    }

    private func route(_ request: HTTPRequest) {
        switch request.path {
        case "/agent":
            if let event = try? JSONDecoder().decode(AgentEvent.self, from: request.body) { apply(event) }
            Self.respond(request.connection, status: "204 No Content")
        case "/permission":
            handlePermission(request)
        case "/usage":
            UsageManager.shared.ingest(request.body)
            Self.respond(request.connection, status: "204 No Content")
        default:
            Self.respond(request.connection, status: "404 Not Found")
        }
    }

    // MARK: - Запросы разрешений

    private func handlePermission(_ request: HTTPRequest) {
        // Если запросы в «чёлке» выключены или данные некорректны — сразу пустой ответ, хук вернёт управление терминалу
        guard Defaults[.showAgentActivity], Defaults[.agentPermissionPrompts],
              let payload = try? JSONDecoder().decode(PermissionPayload.self, from: request.body) else {
            Self.respond(request.connection, status: "204 No Content")
            return
        }

        let permission = AgentPermissionRequest(
            sessionID: payload.id, agent: payload.agent ?? "Agent", project: payload.project,
            tool: payload.tool, detail: payload.detail ?? "")
        permissionConnections[permission.id] = request.connection
        withAnimation(.spring(response: 0.5, dampingFraction: 0.78)) { pendingPermissions.append(permission) }

        // Агент ждёт — отмечаем в индикаторе
        apply(AgentEvent(
            id: payload.id, agent: payload.agent, status: .waiting, task: payload.tool,
            project: payload.project, cwd: payload.cwd, pids: payload.pids, tty: payload.tty))

        // Следим за соединением: если хук завершён (ответили в терминале или время вышло), убираем карточку
        let id = permission.id
        request.connection.receive(minimumIncompleteLength: 1, maximumLength: 1) { [weak self] _, _, isComplete, error in
            if isComplete || error != nil {
                Task { @MainActor in self?.dropPermission(id) }
            }
        }
    }

    /// Ответ пользователя из «чёлки»
    func resolve(_ id: UUID, allow: Bool) {
        guard let permission = pendingPermissions.first(where: { $0.id == id }) else { return }
        if let connection = permissionConnections[id] {
            let body = allow
                ? "{\"behavior\":\"allow\"}"
                : "{\"behavior\":\"deny\",\"message\":\"Denied from Chelka\"}"
            Self.respond(connection, status: "200 OK", body: body)
        }
        finishPermission(id)
        // Агент продолжает работу (или остановился после отказа — это покажут следующие события хуков)
        if var session = sessions[permission.sessionID] {
            session.status = .running
            session.since = Date()
            session.updatedAt = Date()
            withAnimation(.smooth(duration: 0.3)) { sessions[permission.sessionID] = session }
        }
        if banner?.sessionID == permission.sessionID { hideBanner() }
    }

    /// Хук завершился без нашего ответа (например, ответили в терминале)
    private func dropPermission(_ id: UUID) {
        guard pendingPermissions.contains(where: { $0.id == id }) else { return }
        permissionConnections[id]?.cancel()
        finishPermission(id)
    }

    private func finishPermission(_ id: UUID) {
        permissionConnections[id] = nil
        withAnimation(.spring(response: 0.5, dampingFraction: 0.9)) {
            pendingPermissions.removeAll { $0.id == id }
        }
    }

    // MARK: - Развёрнутое уведомление

    private func showBanner(for session: AgentSession) {
        bannerTask?.cancel()
        withAnimation(.spring(response: 0.5, dampingFraction: 0.76)) {
            banner = AgentBanner(
                sessionID: session.id, agent: session.agent, project: session.project,
                task: session.task, status: session.status)
        }
        // Плашка держится заметно дольше: завершение — 8 секунд, ошибка и ожидание — 10
        let duration: Duration = session.status == .done ? .seconds(8) : .seconds(10)
        // Звук не чаще раза в 2,5 с: несколько сессий, закончившихся почти одновременно, дают один сигнал
        if session.status == .done, Defaults[.showAgentActivity], Defaults[.agentCompletionSound],
           Date().timeIntervalSince(lastCompletionSound) > 2.5 {
            lastCompletionSound = Date()
            LockSoundPlayer.shared.playAgentDone()
        }
        bannerTask = Task { [weak self] in
            try? await Task.sleep(for: duration)
            guard !Task.isCancelled else { return }
            self?.hideBanner()
        }
    }

    private func hideBanner() {
        bannerTask?.cancel()
        withAnimation(.spring(response: 0.5, dampingFraction: 0.9)) { banner = nil }
    }

    // MARK: - Состояние

    private func apply(_ event: AgentEvent) {
        expiryTasks[event.id]?.cancel()
        if event.status == .running { activityPulse &+= 1 }

        if event.status == .end {
            if banner?.sessionID == event.id { hideBanner() }
            withAnimation(.smooth(duration: 0.3)) { _ = sessions.removeValue(forKey: event.id) }
            return
        }

        let previous = sessions[event.id]
        let session = AgentSession(
            id: event.id,
            agent: event.agent ?? previous?.agent ?? "Agent",
            status: event.status,
            task: event.task ?? previous?.task,
            project: event.project ?? previous?.project,
            updatedAt: Date(),
            since: previous?.status == event.status ? (previous?.since ?? Date()) : Date(),
            hostPIDs: event.pids ?? previous?.hostPIDs ?? [],
            tty: event.tty ?? previous?.tty,
            cwd: event.cwd ?? previous?.cwd
        )
        withAnimation(.smooth(duration: 0.3)) { sessions[event.id] = session }

        // Смена статуса: завершение, ошибка или ожидание — разворачиваем чёлку, возобновление работы — сворачиваем
        if previous?.status != event.status {
            switch event.status {
            case .done, .error, .waiting:
                // «Завершено» показываем всегда, даже если приложение не видело начала работы (его могли перезапустить
                // посреди задачи, а запись об агенте могла устареть). От двойных сигналов защищает ограничение в showBanner.
                showBanner(for: session)
            case .running: if banner?.sessionID == event.id { hideBanner() }
            default: break
            }
        }

        // Автоудаление: «готово» и «ошибка» гаснут быстро, остальные — если агент давно молчит
        let lifetime: Duration
        switch event.status {
        // Запись агента должна жить дольше плашки, иначе плашка исчезнет вместе с ней
        case .done: lifetime = .seconds(11)
        case .error: lifetime = .seconds(13)
        case .waiting: lifetime = .seconds(30 * 60)
        default: lifetime = .seconds(15 * 60)
        }
        expiryTasks[event.id] = Task { [weak self] in
            try? await Task.sleep(for: lifetime)
            guard !Task.isCancelled else { return }
            withAnimation(.smooth(duration: 0.3)) { _ = self?.sessions.removeValue(forKey: event.id) }
        }
    }
}


// MARK: - Переход в окно агента

/// Выводит на передний план приложение, в котором работает агент:
/// Terminal/iTerm2 — на нужную вкладку по tty, IDE — на окно проекта, остальные — просто активирует приложение.
@MainActor
enum AgentJumper {
    private static let ideBundlePrefixes = ["com.microsoft.VSCode", "com.todesktop.", "com.exafunction.windsurf", "dev.zed.", "com.jetbrains."]

    static func jump(to session: AgentSession) {
        // Ближайший к процессу агента «обычный» процесс с окном в Dock — это и есть нужное приложение
        let app = session.hostPIDs
            .compactMap { NSRunningApplication(processIdentifier: pid_t($0)) }
            .first { $0.activationPolicy == .regular }
        guard let app, let appURL = app.bundleURL else { return }
        let bundleID = app.bundleIdentifier ?? ""

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true

        // IDE: открываем папку проекта — окно с этим проектом выйдет вперёд
        if let cwd = session.cwd, ideBundlePrefixes.contains(where: { bundleID.hasPrefix($0) }) {
            NSWorkspace.shared.open([URL(fileURLWithPath: cwd)], withApplicationAt: appURL, configuration: configuration)
        } else {
            NSWorkspace.shared.openApplication(at: appURL, configuration: configuration)
        }

        // Terminal / iTerm2: выбираем вкладку по tty (tty проверяем строго — он попадает в AppleScript)
        guard let tty = session.tty, tty.range(of: #"^/dev/ttys\d+$"#, options: .regularExpression) != nil else { return }
        let script: String?
        switch bundleID {
        case "com.apple.Terminal":
            script = """
            tell application "Terminal"
                repeat with w in windows
                    repeat with t in tabs of w
                        if tty of t is "\(tty)" then
                            set selected of t to true
                            set index of w to 1
                            activate
                            return
                        end if
                    end repeat
                end repeat
            end tell
            """
        case "com.googlecode.iterm2":
            script = """
            tell application "iTerm"
                repeat with w in windows
                    repeat with t in tabs of w
                        repeat with s in sessions of t
                            if tty of s is "\(tty)" then
                                select t
                                tell w to select
                                activate
                                return
                            end if
                        end repeat
                    end repeat
                end repeat
            end tell
            """
        default:
            script = nil
        }
        if let script {
            Task { try? await AppleScriptHelper.executeVoid(script) }
        }
    }
}
