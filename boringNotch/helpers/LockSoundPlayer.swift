//
//  LockSoundPlayer.swift
//  boringNotch
//
//  Короткие мягкие щелчки блокировки и разблокировки, синтезируются в коде
//

import AVFoundation

@MainActor
final class LockSoundPlayer {
    static let shared = LockSoundPlayer()

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let sampleRate: Double = 44_100
    private lazy var format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
    private var isConfigured = false

    private lazy var unlockBuffer = makeClick(toneFreq: 2200, bodyFreq: 260, volume: 0.32)
    private lazy var lockBuffer = makeClick(toneFreq: 1300, bodyFreq: 170, volume: 0.36)
    /// Завершение работы агента: короткое мягкое арпеджио вверх (соль → до → ми)
    private lazy var agentDoneBuffer = makeBell(
        notes: [(783.99, 0.0), (1046.5, 0.1), (1318.51, 0.2)], duration: 1.2, peak: 0.4)

    /// Прогрев: заранее собираем буферы и запускаем движок, чтобы при блокировке звук шёл без задержки
    func prewarm() {
        configureIfNeeded()
        _ = unlockBuffer
        _ = lockBuffer
        _ = agentDoneBuffer
        startEngineIfNeeded()
        player.play()
    }

    func playAgentDone() {
        configureIfNeeded()
        startEngineIfNeeded()
        player.scheduleBuffer(agentDoneBuffer, at: nil, options: .interrupts, completionHandler: nil)
        if !player.isPlaying { player.play() }
    }

    func play(_ kind: LockAnimationKind) {
        configureIfNeeded()
        startEngineIfNeeded()
        let buffer = kind == .unlocking ? unlockBuffer : lockBuffer
        player.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
        if !player.isPlaying { player.play() }
    }

    private func startEngineIfNeeded() {
        guard !engine.isRunning else { return }
        engine.prepare()
        try? engine.start()
    }

    private func configureIfNeeded() {
        guard !isConfigured else { return }
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        // Если система сбросила аудиоустройство (смена выхода, сон), перезапускаем движок
        NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.startEngineIfNeeded()
                self?.player.play()
            }
        }
        isConfigured = true
    }

    /// Колокольчик: синус с обертонами и экспоненциальным затуханием, ноты стартуют со сдвигом по времени.
    /// `peak` — пиковая громкость итогового звука (0...1): буфер нормализуется, чтобы громкость не зависела от числа нот.
    private func makeBell(notes: [(freq: Double, start: Double)], duration: Double, peak: Float) -> AVAudioPCMBuffer {
        let frames = AVAudioFrameCount(duration * sampleRate)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        buffer.frameLength = frames
        let samples = buffer.floatChannelData![0]

        var maxAbs: Float = 0
        for i in 0..<Int(frames) {
            let t = Double(i) / sampleRate
            var value = 0.0
            for note in notes where t >= note.start {
                let nt = t - note.start
                let attack = min(1.0, nt / 0.006)
                let envelope = attack * exp(-nt * 5.0)
                value += envelope * (sin(2 * .pi * note.freq * nt)
                    + 0.22 * sin(2 * .pi * note.freq * 2 * nt) * exp(-nt * 4))
            }
            let fadeOut = min(1.0, (duration - t) / 0.06)
            samples[i] = Float(value) * Float(fadeOut)
            maxAbs = max(maxAbs, abs(samples[i]))
        }
        let gain = maxAbs > 0 ? peak / maxAbs : 0
        for i in 0..<Int(frames) { samples[i] *= gain }
        return buffer
    }

    /// Мягкий щелчок: короткий шумовой импульс + затухающий тон + низкий «стук».
    /// Шум пропускается через фильтр низких частот, чтобы щелчок не звучал резко.
    private func makeClick(toneFreq: Double, bodyFreq: Double, volume: Float) -> AVAudioPCMBuffer {
        let duration = 0.12
        let frames = AVAudioFrameCount(duration * sampleRate)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        buffer.frameLength = frames
        let samples = buffer.floatChannelData![0]

        var filteredNoise = 0.0
        for i in 0..<Int(frames) {
            let t = Double(i) / sampleRate
            let attack = min(1.0, t / 0.0008)
            filteredNoise += 0.25 * (Double.random(in: -1...1) - filteredNoise)
            let transient = filteredNoise * exp(-t * 700)
            let tone = sin(2 * .pi * toneFreq * t) * exp(-t * 110)
            let body = sin(2 * .pi * bodyFreq * t) * exp(-t * 65)
            let value = attack * (0.9 * transient + 0.45 * tone + 0.55 * body)
            let fadeOut = min(1.0, (duration - t) / 0.02)
            samples[i] = Float(value) * volume * Float(fadeOut)
        }
        return buffer
    }
}
