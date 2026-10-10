//
//  IdleAnimations.swift
//  Chelka
//
//  Анимации закрытой «чёлки» в простое — когда не работает ни одна нейросеть и не играет медиа.
//  Всё рисуется одним Canvas по времени t: никаких таймеров и состояния, превью в настройках
//  показывает ровно то же, что и «чёлка».
//

import SwiftUI

/// Строка простоя в закрытой «чёлке»: левая зона, сама чёлка, правая зона
struct IdleAnimationView: View {
    /// Ширина зоны по бокам от чёлки
    static let sideWidth = ClosedNotchLayout.sideWidth

    let style: IdleStyle
    let notchWidth: CGFloat
    let height: CGFloat

    var body: some View {
        // 30 кадров в секунду хватает для пиксельной графики и почти не нагружает процессор
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { timeline in
            IdleArt(style: style, t: timeline.date.timeIntervalSinceReferenceDate,
                    notchWidth: notchWidth, side: Self.sideWidth)
        }
        .frame(width: notchWidth + 2 * Self.sideWidth, height: height)
        .allowsHitTesting(false)
    }
}

/// Чистая отрисовка кадра: одна и та же для «чёлки» и превью
struct IdleArt: View {
    let style: IdleStyle
    let t: Double
    let notchWidth: CGFloat
    let side: CGFloat

    var body: some View {
        Canvas { context, size in
            let zones = IdleZones(size: size, side: side, notchWidth: notchWidth)
            // Всё, что попадает под саму чёлку, «уходит за неё»: рисуем только в боковых зонах
            var clip = Path()
            clip.addRect(zones.left)
            clip.addRect(zones.right)
            context.clip(to: clip)

            switch style {
            case .off: break
            case .cat: IdleCat.draw(in: &context, zones: zones, t: t)
            case .pong: IdlePong.draw(in: &context, zones: zones, t: t)
            case .fireflies: IdleFireflies.draw(in: &context, zones: zones, t: t)
            case .fish: IdleFish.draw(in: &context, zones: zones, t: t)
            case .snake: IdleSnake.draw(in: &context, zones: zones, t: t)
            case .clock: IdleClock.draw(in: &context, zones: zones, t: t)
            case .chomp: IdleChomp.draw(in: &context, zones: zones, t: t)
            case .matrix: IdleMatrix.draw(in: &context, zones: zones, t: t)
            case .rain: IdleRain.draw(in: &context, zones: zones, t: t)
            case .invaders: IdleInvaders.draw(in: &context, zones: zones, t: t)
            case .dino: IdleDino.draw(in: &context, zones: zones, t: t)
            case .blocks: IdleBlocks.draw(in: &context, zones: zones, t: t)
            case .puppy: IdlePuppy.draw(in: &context, zones: zones, t: t)
            case .fireworks: IdleFireworks.draw(in: &context, zones: zones, t: t)
            case .rocket: IdleRocket.draw(in: &context, zones: zones, t: t)
            case .train: IdleTrain.draw(in: &context, zones: zones, t: t)
            case .snow: IdleSnow.draw(in: &context, zones: zones, t: t)
            case .robot: IdleRobot.draw(in: &context, zones: zones, t: t)
            case .bats: IdleBats.draw(in: &context, zones: zones, t: t)
            case .tesla: IdleTesla.draw(in: &context, zones: zones, t: t)
            case .ocean: IdleOcean.draw(in: &context, zones: zones, t: t)
            case .jellyfish: IdleJellyfish.draw(in: &context, zones: zones, t: t)
            case .runner: IdleRunner.draw(in: &context, zones: zones, t: t)
            }
        }
    }
}

/// Геометрия строки: левая и правая зоны вокруг чёлки
struct IdleZones {
    let size: CGSize
    let left: CGRect
    let right: CGRect

    init(size: CGSize, side: CGFloat, notchWidth: CGFloat) {
        self.size = size
        // Зоны всегда прижаты к краям, середина — под чёлкой
        let side = min(side, size.width / 2)
        left = CGRect(x: 0, y: 0, width: side, height: size.height)
        right = CGRect(x: size.width - side, y: 0, width: side, height: size.height)
    }
}

// MARK: - Пиксельные спрайты

/// Спрайт из строк: «#» — пиксель цвета спрайта, «o» — второй цвет (нос), «-» — тёмный (закрытые глаза), остальное — пусто
private struct Sprite {
    let rows: [String]
    var width: Int { rows.map(\.count).max() ?? 0 }
    var height: Int { rows.count }

    /// Рисует спрайт так, что (x, bottom) — середина нижнего края; flip — смотрит влево
    func draw(in context: inout GraphicsContext, x: CGFloat, bottom: CGFloat, pixel: CGFloat,
              color: Color, accent: Color, flip: Bool, dark: Color = Color(red: 0.42, green: 0.2, blue: 0.06)) {
        let originX = (x - CGFloat(width) * pixel / 2).rounded()
        let originY = (bottom - CGFloat(height) * pixel).rounded()
        for (row, line) in rows.enumerated() {
            for (col, char) in line.enumerated() where char == "#" || char == "o" || char == "-" {
                let c = flip ? width - 1 - col : col
                // Чуть внахлёст: при дробном размере пикселя между клетками не видно швов
                let rect = CGRect(x: originX + CGFloat(c) * pixel, y: originY + CGFloat(row) * pixel,
                                  width: pixel + 0.3, height: pixel + 0.3)
                let fill = char == "#" ? color : char == "o" ? accent : dark
                context.fill(Path(rect), with: .color(fill))
            }
        }
    }
}

// MARK: - Котик

/// Рыжий пиксельный кот живёт своей жизнью: сидит, идёт сквозь чёлку, умывается, засыпает
private enum IdleCat {
    static let walkA = Sprite(rows: [
        ".........#...#",
        ".........#####",
        "#........#.#.#",
        ".#.......##o##",
        "..##########..",
        "..##########..",
        "..##########..",
        "..#..#...#..#.",
    ])
    static let walkB = Sprite(rows: [
        ".........#...#",
        ".........#####",
        "#........#.#.#",
        ".#.......##o##",
        "..##########..",
        "..##########..",
        "..##########..",
        "...##.....##..",
    ])
    static let sitA = Sprite(rows: [
        "......#...#",
        "......#####",
        "......#.#.#",
        "......##o##",
        ".....####..",
        "....#####..",
        "#..######..",
        ".#.######..",
        "..#######..",
    ])
    static let sitB = Sprite(rows: [
        "......#...#",
        "......#####",
        "......#.#.#",
        "......##o##",
        ".....####..",
        "....#####..",
        "...######..",
        "#..######..",
        ".########..",
    ])
    /// Умывается: глаза зажмурены, лапа у мордочки
    static let groom = Sprite(rows: [
        "......#...#",
        "......#####",
        "......#####",
        "......##o##",
        ".....####.#",
        "....#####.#",
        "#..######..",
        ".#.######..",
        "..#######..",
    ])
    /// Спит «буханкой»: голова над телом, глаза-щёлочки
    static let sleep = Sprite(rows: [
        "........#...#",
        "........#####",
        "........#-#-#",
        "...##########",
        "..###########",
        ".############",
        "#.##########.",
    ])

    static let fur = Color(red: 1.0, green: 0.64, blue: 0.28)
    static let nose = Color(red: 1.0, green: 0.45, blue: 0.55)

    /// Цикл 32 секунды: спит слева → идёт направо → сидит и умывается → идёт обратно
    static func draw(in context: inout GraphicsContext, zones: IdleZones, t: Double) {
        let h = zones.size.height
        let pixel = max(1.5, (h * 0.62 / 9).rounded(.down))
        let bottom = h - max(4, (h - 9 * pixel) / 2)
        let leftX = zones.left.midX
        let rightX = zones.right.midX
        let walkTime = 7.0
        let cycle = 32.0
        let local = t.truncatingRemainder(dividingBy: cycle)
        let step = Int(t * 6) % 2 == 0   // шаг лап 6 раз в секунду
        let tail = Int(t * 2) % 2 == 0   // хвост машет дважды в секунду

        func at(_ p: Double) -> CGFloat { leftX + (rightX - leftX) * CGFloat(p) }

        switch local {
        case ..<8:
            // Спит слева, над ним всплывают «z»
            sleep.draw(in: &context, x: leftX, bottom: bottom, pixel: pixel, color: fur, accent: nose, flip: false)
            drawZ(in: &context, x: leftX + 7, top: bottom - 8 * pixel, t: local)
        case ..<9:
            sitA.draw(in: &context, x: leftX, bottom: bottom, pixel: pixel, color: fur, accent: nose, flip: false)
        case ..<(9 + walkTime):
            let p = (local - 9) / walkTime
            (step ? walkA : walkB).draw(in: &context, x: at(p), bottom: bottom, pixel: pixel, color: fur, accent: nose, flip: false)
        case ..<(9 + walkTime + 7):
            // Справа: разворачивается к чёлке, машет хвостом и умывается
            let sitTime = local - 9 - walkTime
            let sprite = sitTime > 3 && sitTime < 5.5 ? (Int(t * 3) % 2 == 0 ? groom : sitA) : (tail ? sitA : sitB)
            sprite.draw(in: &context, x: rightX, bottom: bottom, pixel: pixel, color: fur, accent: nose, flip: true)
        case ..<(9 + 2 * walkTime + 7):
            let p = 1 - (local - 9 - walkTime - 7) / walkTime
            (step ? walkA : walkB).draw(in: &context, x: at(p), bottom: bottom, pixel: pixel, color: fur, accent: nose, flip: true)
        default:
            // Дошёл домой: садится, потом снова засыпает
            sitA.draw(in: &context, x: leftX, bottom: bottom, pixel: pixel, color: fur, accent: nose, flip: false)
        }
    }

    /// Три «z», всплывающие по очереди и тающие
    private static func drawZ(in context: inout GraphicsContext, x: CGFloat, top: CGFloat, t: Double) {
        for i in 0..<3 {
            let phase = (t / 2.4 + Double(i) / 3).truncatingRemainder(dividingBy: 1)
            let size = 5 + 3 * phase
            let text = Text("z").font(.system(size: size, weight: .heavy, design: .monospaced))
                .foregroundColor(Color.white.opacity(0.85 * sin(.pi * phase)))
            context.draw(text, at: CGPoint(x: x + CGFloat(phase) * 8, y: top - CGFloat(phase) * 9))
        }
    }
}

// MARK: - Пинг-понг

/// Пиксельный понг: мяч летает между ракетками по краям и пролетает «за» чёлкой
private enum IdlePong {
    static func draw(in context: inout GraphicsContext, zones: IdleZones, t: Double) {
        let h = zones.size.height
        let px: CGFloat = 2
        let paddleH = px * 5
        let leftPaddleX = zones.left.minX + 6
        let rightPaddleX = zones.right.maxX - 6 - px
        let minX = leftPaddleX + px
        let maxX = rightPaddleX - px * 2
        let top = h * 0.18
        let bottom = h * 0.82 - px * 2

        // Мяч: «треугольная волна» по x и по y с разными периодами — траектория не повторяется подолгу
        func triangle(_ value: Double) -> CGFloat { CGFloat(1 - abs(value.truncatingRemainder(dividingBy: 2) - 1)) }
        func ball(at time: Double) -> CGPoint {
            CGPoint(x: minX + (maxX - minX) * triangle(time / 1.6), y: top + (bottom - top) * triangle(time / 0.71))
        }
        let position = ball(at: t)

        // Шлейф
        for i in 1...3 {
            let p = ball(at: t - Double(i) * 0.035)
            context.fill(Path(CGRect(x: p.x, y: p.y, width: px * 2, height: px * 2)),
                         with: .color(.white.opacity(0.28 - Double(i) * 0.07)))
        }
        context.fill(Path(CGRect(x: position.x, y: position.y, width: px * 2, height: px * 2)), with: .color(.white))

        // Ракетки следят за мячом с небольшим отставанием, у каждой — своё
        for (x, lag) in [(leftPaddleX, 0.12), (rightPaddleX, 0.09)] {
            let target = ball(at: t - lag).y + px - paddleH / 2
            let y = min(max(target, h * 0.12), h * 0.88 - paddleH)
            context.fill(Path(CGRect(x: x, y: (y / px).rounded() * px, width: px, height: paddleH)),
                         with: .color(.white.opacity(0.9)))
        }
    }
}

// MARK: - Светлячки

/// Тёплые огоньки медленно парят по обе стороны чёлки, разгораются и гаснут
private enum IdleFireflies {
    static let glow = Color(red: 0.86, green: 1.0, blue: 0.45)

    static func draw(in context: inout GraphicsContext, zones: IdleZones, t: Double) {
        let h = zones.size.height
        for (zoneIndex, zone) in [zones.left, zones.right].enumerated() {
            for i in 0..<5 {
                // Псевдослучайные, но постоянные параметры каждого огонька
                let seed = Double(zoneIndex * 7 + i) * 1.618
                let x = zone.midX + CGFloat(sin(t * (0.31 + 0.07 * Double(i)) + seed * 3)) * zone.width * 0.38
                let y = h / 2 + CGFloat(sin(t * (0.43 + 0.05 * Double(i)) + seed * 5)) * h * 0.32
                let pulse = pow((sin(t * (0.9 + 0.2 * Double(i)) + seed * 2) + 1) / 2, 2)
                guard pulse > 0.02 else { continue }
                let halo = 4.5 * CGFloat(0.6 + 0.4 * pulse)
                context.fill(Path(ellipseIn: CGRect(x: x - halo, y: y - halo, width: halo * 2, height: halo * 2)),
                             with: .radialGradient(Gradient(colors: [glow.opacity(0.55 * pulse), glow.opacity(0)]),
                                                   center: CGPoint(x: x, y: y), startRadius: 0, endRadius: halo))
                let core: CGFloat = 1.3
                context.fill(Path(ellipseIn: CGRect(x: x - core, y: y - core, width: core * 2, height: core * 2)),
                             with: .color(Color.white.opacity(0.9 * pulse)))
            }
        }
    }
}

// MARK: - Аквариум

/// Пиксельная рыбка плавает туда-обратно сквозь чёлку, навстречу ей — мальки, со дна поднимаются пузырьки
private enum IdleFish {
    static let fish = Sprite(rows: [
        "....###...",
        "#..#####..",
        "##########",
        "##.#####o#",
        "#..#####..",
        "....###...",
    ])
    static let fry = Sprite(rows: [
        ".##.",
        "####",
        ".##.",
    ])
    static let body = Color(red: 1.0, green: 0.55, blue: 0.2)
    static let eye = Color.black

    static func draw(in context: inout GraphicsContext, zones: IdleZones, t: Double) {
        let w = zones.size.width
        let h = zones.size.height
        let pixel: CGFloat = 2

        // Пузырьки в обеих зонах
        for (index, zone) in [zones.left, zones.right].enumerated() {
            for i in 0..<3 {
                let seed = Double(index * 3 + i)
                let phase = (t / (2.6 + seed * 0.3) + seed * 0.37).truncatingRemainder(dividingBy: 1)
                let x = zone.minX + zone.width * CGFloat(0.2 + 0.3 * Double(i)) + CGFloat(sin(t * 2 + seed)) * 1.5
                let y = h - 2 - CGFloat(phase) * (h - 4)
                let r: CGFloat = 1 + CGFloat(phase) * 1.2
                context.stroke(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                               with: .color(.white.opacity(0.55 * (1 - phase))), lineWidth: 0.8)
            }
        }

        // Большая рыба: 9 секунд в одну сторону, разворот, обратно
        let cycle = 18.0
        let local = t.truncatingRemainder(dividingBy: cycle)
        let forward = local < cycle / 2
        let p = CGFloat(forward ? local / (cycle / 2) : 1 - (local - cycle / 2) / (cycle / 2))
        let x = -12 + (w + 24) * p
        let y = h * 0.55 + CGFloat(sin(t * 2.2)) * 2.5
        // Хвост виляет: раз в 0,25 с спрайт чуть сдвигается
        let wiggle: CGFloat = Int(t * 4) % 2 == 0 ? 0 : 0.5
        fish.draw(in: &context, x: x + wiggle, bottom: y + 6, pixel: pixel, color: body, accent: eye, flip: !forward)

        // Стайка мальков плывёт навстречу
        for i in 0..<3 {
            let q = CGFloat(((t / 11) + Double(i) * 0.06).truncatingRemainder(dividingBy: 1))
            let fx = forward ? w + 10 - (w + 20) * q : -10 + (w + 20) * q
            let fy = h * 0.32 + CGFloat(i) * 3 + CGFloat(sin(t * 3 + Double(i))) * 1.5
            fry.draw(in: &context, x: fx + CGFloat(i) * 5, bottom: fy, pixel: 1.5,
                     color: Color(red: 0.45, green: 0.85, blue: 1.0), accent: .white, flip: forward)
        }
    }
}

// MARK: - Змейка

/// Классическая змейка: ползёт по кругу сквозь чёлку и съедает яблоки, которые снова вырастают
private enum IdleSnake {
    static func draw(in context: inout GraphicsContext, zones: IdleZones, t: Double) {
        let cell: CGFloat = 3
        let w = zones.size.width
        let h = zones.size.height
        // Контур пути: верхняя линия → вниз в правой зоне → нижняя линия → вверх в левой зоне
        let left = (zones.left.minX + 6) / cell
        let right = (w - 6) / cell - 1
        let top = (h * 0.28 / cell).rounded()
        let bottom = (h * 0.72 / cell).rounded()
        let horizontal = right - left
        let vertical = bottom - top
        let length = 2 * (horizontal + vertical)

        func point(_ s: CGFloat) -> CGPoint {
            var s = s.truncatingRemainder(dividingBy: length)
            if s < 0 { s += length }
            if s < horizontal { return CGPoint(x: left + s, y: top) }
            s -= horizontal
            if s < vertical { return CGPoint(x: right, y: top + s) }
            s -= vertical
            if s < horizontal { return CGPoint(x: right - s, y: bottom) }
            s -= horizontal
            return CGPoint(x: left, y: bottom - s)
        }
        func rect(_ p: CGPoint) -> CGRect {
            CGRect(x: p.x.rounded() * cell, y: p.y.rounded() * cell, width: cell - 0.5, height: cell - 0.5)
        }

        let head = CGFloat(t * 14)   // клеток в секунду
        // Яблоки стоят в боковых зонах; съеденное вырастает через четверть круга
        let apples: [CGFloat] = [horizontal + vertical * 0.5, 2 * horizontal + vertical * 1.5]
        for apple in apples {
            var ahead = (apple - head).truncatingRemainder(dividingBy: length)
            if ahead < 0 { ahead += length }
            if ahead < length * 0.75 {
                context.fill(Path(rect(point(apple))), with: .color(Color(red: 1, green: 0.3, blue: 0.3)))
            }
        }
        // Тело: от хвоста к голове, голова ярче
        let segments = 9
        for i in stride(from: segments - 1, through: 0, by: -1) {
            let alpha = i == 0 ? 1 : 0.85 - Double(i) * 0.06
            context.fill(Path(rect(point(head.rounded(.down) - CGFloat(i)))),
                         with: .color(Color(red: 0.4, green: 0.95, blue: 0.45).opacity(alpha)))
        }
    }
}

// MARK: - Пиксельные часы

/// Часы слева от чёлки, минуты — справа; точки-разделители мигают раз в секунду
private enum IdleClock {
    /// Цифры 3×5
    static let digits: [[String]] = [
        ["###", "#.#", "#.#", "#.#", "###"], [".#.", "##.", ".#.", ".#.", "###"],
        ["###", "..#", "###", "#..", "###"], ["###", "..#", "###", "..#", "###"],
        ["#.#", "#.#", "###", "..#", "..#"], ["###", "#..", "###", "..#", "###"],
        ["###", "#..", "###", "#.#", "###"], ["###", "..#", ".#.", ".#.", ".#."],
        ["###", "#.#", "###", "#.#", "###"], ["###", "#.#", "###", "..#", "###"],
    ]

    static func draw(in context: inout GraphicsContext, zones: IdleZones, t: Double) {
        let date = Date(timeIntervalSinceReferenceDate: t)
        let parts = Calendar.current.dateComponents([.hour, .minute, .second], from: date)
        let hour = parts.hour ?? 0
        let minute = parts.minute ?? 0
        let pixel: CGFloat = 2
        let h = zones.size.height
        let top = ((h - 5 * pixel) / 2).rounded()
        let color = Color.white.opacity(0.92)
        let blink = t.truncatingRemainder(dividingBy: 1) < 0.5

        func drawNumber(_ value: Int, centerX: CGFloat) {
            let text = String(format: "%02d", value)
            let width = (3 * 2 + 1) * pixel
            var x = (centerX - width / 2).rounded()
            for char in text {
                let rows = digits[Int(String(char)) ?? 0]
                for (r, line) in rows.enumerated() {
                    for (c, ch) in line.enumerated() where ch == "#" {
                        context.fill(Path(CGRect(x: x + CGFloat(c) * pixel, y: top + CGFloat(r) * pixel, width: pixel, height: pixel)),
                                     with: .color(color))
                    }
                }
                x += 4 * pixel
            }
        }
        drawNumber(hour, centerX: zones.left.midX - 2)
        drawNumber(minute, centerX: zones.right.midX + 2)

        // Разделитель «:» разрезан чёлкой: по точке у внутреннего края каждой зоны
        if blink {
            for x in [zones.left.maxX - 5, zones.right.minX + 3] {
                for dy in [pixel * 1, pixel * 3] {
                    context.fill(Path(CGRect(x: x, y: top + dy, width: pixel, height: pixel)), with: .color(color))
                }
            }
        }
        // Секунды: тонкая полоска под минутами
        let progress = CGFloat(parts.second ?? 0) / 60
        let barWidth = zones.right.width - 10
        context.fill(Path(CGRect(x: zones.right.minX + 6, y: top + 5 * pixel + 3, width: barWidth * progress, height: 1)),
                     with: .color(.white.opacity(0.35)))
    }
}

// MARK: - Пожиратель точек

/// Жёлтый «колобок» с открывающимся ртом съедает дорожку точек, за ним гонится привидение
private enum IdleChomp {
    static let ghost = Sprite(rows: [
        "..####..",
        ".######.",
        "#oo##oo#",
        "#-o##-o#",
        "########",
        "########",
        "##.##.##",
    ])
    static let ghostAlt = Sprite(rows: [
        "..####..",
        ".######.",
        "#oo##oo#",
        "#-o##-o#",
        "########",
        "########",
        "#.##.##.",
    ])

    static func draw(in context: inout GraphicsContext, zones: IdleZones, t: Double) {
        let w = zones.size.width
        let h = zones.size.height
        let y = h / 2
        let travel = w + 60
        let speed = 26.0
        let x = CGFloat((t * speed).truncatingRemainder(dividingBy: Double(travel))) - 20

        // Точки впереди целы, позади — съедены (на новом круге всё восстанавливается)
        var dot = CGFloat(6)
        while dot < w - 3 {
            if dot > x + 2 {
                context.fill(Path(CGRect(x: dot - 1, y: y - 1, width: 2, height: 2)), with: .color(Color(red: 1, green: 0.85, blue: 0.7)))
            }
            dot += 7
        }

        // Рот открывается и закрывается 8 раз в секунду
        let radius: CGFloat = 6
        let mouth = Angle.degrees(4 + 36 * abs(sin(t * .pi * 4)))
        var body = Path()
        body.move(to: CGPoint(x: x, y: y))
        body.addArc(center: CGPoint(x: x, y: y), radius: radius, startAngle: mouth, endAngle: -mouth, clockwise: false)
        body.closeSubpath()
        context.fill(body, with: .color(Color(red: 1, green: 0.86, blue: 0.2)))

        let ghostSprite = Int(t * 5) % 2 == 0 ? ghost : ghostAlt
        ghostSprite.draw(in: &context, x: x - 24, bottom: y + 7 + CGFloat(sin(t * 6)), pixel: 1.75,
                         color: Color(red: 1, green: 0.45, blue: 0.75), accent: .white, flip: false,
                         dark: Color(red: 0.15, green: 0.2, blue: 0.75))
    }
}

// MARK: - Матрица

/// Зелёные символы стекают колонками по бокам чёлки
private enum IdleMatrix {
    static let glyphs = Array("01アイウエオカキクケコサシスセソﾊﾐﾋｰｳｼﾅﾓﾆ<>*+")

    static func draw(in context: inout GraphicsContext, zones: IdleZones, t: Double) {
        let h = zones.size.height
        let step: CGFloat = 6
        let green = Color(red: 0.2, green: 0.95, blue: 0.4)
        for (zoneIndex, zone) in [zones.left, zones.right].enumerated() {
            let columns = Int(zone.width / step) - 1
            // Нижняя граница еле заметно подсвечена всегда, а в места «приземления» символов вспыхивает ярче
            context.fill(Path(CGRect(x: zone.minX + 2, y: h - 1.5, width: zone.width - 4, height: 1.5)), with: .color(green.opacity(0.14)))
            for column in 0..<columns {
                let seed = Double(zoneIndex * 31 + column * 7)
                let speed = 18 + (seed.truncatingRemainder(dividingBy: 5)) * 4
                let span = Double(h) + 30
                let headY = CGFloat((t * speed + seed * 13).truncatingRemainder(dividingBy: span)) - 6
                let x = zone.minX + step * (CGFloat(column) + 0.9)

                // Вспышка внизу: нарастает, когда голова колонки подходит к нижней границе, и затухает после «приземления»
                let d = headY - (h - 3)
                let glow: Double = d >= 0 ? exp(-Double(d) / 7) : max(0, 1 + Double(d) / 9) * 0.35
                if glow > 0.02 {
                    context.fill(Path(ellipseIn: CGRect(x: x - 9, y: h - 9, width: 18, height: 18)),
                                 with: .radialGradient(Gradient(colors: [green.opacity(0.75 * glow), .clear]),
                                                       center: CGPoint(x: x, y: h), startRadius: 0, endRadius: 9))
                    context.fill(Path(CGRect(x: x - 5, y: h - 1.8, width: 10, height: 1.8)),
                                 with: .color(Color(red: 0.7, green: 1, blue: 0.78).opacity(0.9 * glow)))
                }

                for i in 0..<5 {
                    let y = headY - CGFloat(i) * step
                    guard y > -step, y < h + step else { continue }
                    // Символ меняется со временем, но не каждый кадр
                    let index = abs(Int(seed) * 17 + i * 5 + Int(t * 3) * (i == 0 ? 7 : 1)) % glyphs.count
                    let color = i == 0 ? Color(red: 0.85, green: 1, blue: 0.88) : Color(red: 0.2, green: 0.95, blue: 0.4).opacity(1 - Double(i) * 0.19)
                    let text = Text(String(glyphs[index])).font(.system(size: 6, weight: .bold, design: .monospaced)).foregroundColor(color)
                    context.draw(text, at: CGPoint(x: x, y: y))
                }
            }
        }
    }
}

// MARK: - Дождь

/// Над каждой зоной — пиксельная тучка: идёт дождь, капли разбиваются о «пол», иногда бьёт молния
private enum IdleRain {
    static let cloud = Sprite(rows: [
        "...####.....",
        ".#########..",
        "############",
        ".##########.",
    ])

    static func draw(in context: inout GraphicsContext, zones: IdleZones, t: Double) {
        let h = zones.size.height
        let pixel: CGFloat = 2
        let cloudBottom: CGFloat = 4 + 4 * pixel
        // Молния: раз в 7 секунд по очереди в одной из зон, с двойной вспышкой
        let flashCycle = t.truncatingRemainder(dividingBy: 7)
        let flashZone = Int(t / 7) % 2
        let flashing = flashCycle < 0.12 || (flashCycle > 0.2 && flashCycle < 0.3)

        for (index, zone) in [zones.left, zones.right].enumerated() {
            let lit = flashing && index == flashZone
            cloud.draw(in: &context, x: zone.midX, bottom: cloudBottom, pixel: pixel,
                       color: lit ? .white : Color(white: 0.62), accent: .white, flip: index == 1)

            if lit {
                var bolt = Path()
                let x = zone.midX + 2
                bolt.move(to: CGPoint(x: x, y: cloudBottom))
                bolt.addLine(to: CGPoint(x: x - 4, y: cloudBottom + 7))
                bolt.addLine(to: CGPoint(x: x + 1, y: cloudBottom + 7))
                bolt.addLine(to: CGPoint(x: x - 3, y: h - 2))
                context.stroke(bolt, with: .color(Color(red: 1, green: 0.95, blue: 0.5)), lineWidth: 1.5)
            }

            // Капли: короткие черточки, у пола — брызги
            for i in 0..<6 {
                let seed = Double(index * 6 + i)
                let fall = (t * 1.6 + seed * 0.37).truncatingRemainder(dividingBy: 1)
                let x = zone.minX + 6 + CGFloat(i) * (zone.width - 12) / 5
                let y = cloudBottom + CGFloat(fall) * (h - cloudBottom - 2)
                if fall < 0.92 {
                    context.fill(Path(CGRect(x: x, y: y, width: 1, height: 3)),
                                 with: .color(Color(red: 0.55, green: 0.75, blue: 1).opacity(0.85)))
                } else {
                    for dx in [-2.0, 2.0] {
                        context.fill(Path(CGRect(x: x + CGFloat(dx), y: h - 3, width: 1, height: 1)),
                                     with: .color(Color(red: 0.55, green: 0.75, blue: 1).opacity(0.6)))
                    }
                }
            }
        }
    }
}

// MARK: - Космический бой

/// Кораблик слева по очереди сбивает пришельцев справа; лазер летит сквозь чёлку, сбитый взрывается и возрождается
private enum IdleInvaders {
    static let ship = Sprite(rows: [
        "##.....",
        "###....",
        "#######",
        "###....",
        "##.....",
    ])
    static let alienA = Sprite(rows: [
        "..#..#..",
        "...##...",
        ".######.",
        "##.##.##",
        "########",
        ".#....#.",
    ])
    static let alienB = Sprite(rows: [
        "..#..#..",
        "#..##..#",
        "########",
        "##.##.##",
        ".######.",
        "#......#",
    ])

    static func draw(in context: inout GraphicsContext, zones: IdleZones, t: Double) {
        let h = zones.size.height
        let px: CGFloat = 1.5
        let slots: [CGFloat] = [h * 0.32, h * 0.7]
        let alienX: [CGFloat] = [zones.right.midX + 3, zones.right.midX - 3]
        let colors = [Color(red: 0.45, green: 1, blue: 0.5), Color(red: 1, green: 0.42, blue: 0.85)]
        let period = 2.0
        let fireAt = 0.45
        let flight = 0.5

        let shot = Int(floor(t / period))
        let local = t - Double(shot) * period
        let target = ((shot % 2) + 2) % 2

        // Кораблик плавно наводится на следующую цель
        let k = CGFloat(min(1, local / 0.4))
        let eased = k * k * (3 - 2 * k)
        let shipY = slots[1 - target] + (slots[target] - slots[1 - target]) * eased
        let shipX = zones.left.minX + 10
        ship.draw(in: &context, x: shipX, bottom: shipY + 2.5 * px, pixel: px, color: .white, accent: .white, flip: false)
        // Огонёк двигателя
        if Int(t * 12) % 2 == 0 {
            context.fill(Path(CGRect(x: shipX - 7.5, y: shipY - 0.75, width: 1.5, height: 1.5)), with: .color(.orange))
        }

        // Лазер
        if local >= fireAt && local < fireAt + flight {
            let p = CGFloat((local - fireAt) / flight)
            let from = shipX + 6
            let to = alienX[target] - 6
            context.fill(Path(CGRect(x: from + (to - from) * p, y: slots[target] - 0.6, width: 5, height: 1.2)),
                         with: .color(Color(red: 1, green: 0.9, blue: 0.3)))
        }

        // Пришельцы: шевелятся, сбитый разлетается на пиксели и через секунду возрождается
        let frame = Int(t * 2) % 2 == 0
        for i in 0..<2 {
            let lastShot = target == i ? shot : shot - 1
            let since = t - (Double(lastShot) * period + fireAt + flight)
            let center = CGPoint(x: alienX[i], y: slots[i] + CGFloat(sin(t * 2 + Double(i) * 2)) * 1.2)
            if since >= 0 && since < 0.55 {
                let q = since / 0.55
                for j in 0..<10 {
                    let angle = Double(j) / 10 * 2 * .pi + Double(i)
                    let r = CGFloat(q) * (7 + CGFloat(j % 3) * 2)
                    context.fill(Path(CGRect(x: center.x + CGFloat(cos(angle)) * r, y: center.y + CGFloat(sin(angle)) * r,
                                             width: 1.5, height: 1.5)),
                                 with: .color((j % 2 == 0 ? colors[i] : .white).opacity(1 - q)))
                }
                continue
            }
            let alpha = since >= 0.55 && since < 1.2 ? (since - 0.55) / 0.65 : 1
            (frame ? alienA : alienB).draw(in: &context, x: center.x, bottom: center.y + 3 * px, pixel: px,
                                           color: colors[i].opacity(alpha), accent: .white, flip: false)
        }
    }
}

// MARK: - Динозавр

/// Пиксельный динозавр бежит слева, кактусы едут к нему из-за чёлки — он их перепрыгивает
private enum IdleDino {
    static let body = [
        ".....#####",
        ".....#.###",
        ".....#####",
        ".....###..",
        "#...#####.",
        "##.######.",
        "#########.",
        ".#######..",
    ]
    static let runA = Sprite(rows: body + ["..##..#...", "..#...##.."])
    static let runB = Sprite(rows: body + ["..#..##...", "..##..#..."])
    static let jump = Sprite(rows: body + ["..##.##...", "..#...#..."])
    static let cactus = Sprite(rows: [
        "..#..",
        "..#.#",
        "#.#.#",
        "#.###",
        "###..",
        "..#..",
        "..#..",
    ])

    static func draw(in context: inout GraphicsContext, zones: IdleZones, t: Double) {
        let w = zones.size.width
        let h = zones.size.height
        let px: CGFloat = 1.5
        let ground = h - 4
        let dinoX = zones.left.minX + 12
        let speed = 55.0
        let period = 2.6

        // Земля и бегущие камешки
        for zone in [zones.left, zones.right] {
            context.fill(Path(CGRect(x: zone.minX, y: ground, width: zone.width, height: 1)), with: .color(.white.opacity(0.45)))
        }
        for i in 0..<12 {
            let x = w - CGFloat((t * speed + Double(i) * 23).truncatingRemainder(dividingBy: Double(w)))
            context.fill(Path(CGRect(x: x, y: ground + 2 + CGFloat(i % 2), width: i % 3 == 0 ? 2 : 1, height: 1)),
                         with: .color(.white.opacity(0.35)))
        }

        // Кактусы и прыжок перед ближайшим
        var lift: CGFloat = 0
        let newest = Int(floor(t / period))
        for k in (newest - 4)...newest {
            let x = w + 4 - CGFloat((t - Double(k) * period) * speed)
            guard x > -10 else { continue }
            cactus.draw(in: &context, x: x, bottom: ground + 0.5, pixel: px,
                        color: Color(red: 0.4, green: 0.85, blue: 0.4), accent: .white, flip: false)
            let d = x - dinoX
            if d > -12 && d < 22 {
                lift = max(lift, CGFloat(sin(.pi * Double((22 - d) / 34))) * 11)
            }
        }
        let sprite = lift > 0.5 ? jump : (Int(t * 10) % 2 == 0 ? runA : runB)
        sprite.draw(in: &context, x: dinoX, bottom: ground + 0.5 - lift, pixel: px, color: Color(white: 0.88), accent: .white, flip: false)
    }
}

// MARK: - Тетрис

/// Фигуры падают в «стаканы» по бокам чёлки; играет простой автопилот: собирает линии, они вспыхивают и исчезают
private enum IdleBlocks {
    static let baseShapes: [[(Int, Int)]] = [
        [(0, 0), (1, 0), (2, 0), (3, 0)],  // I
        [(0, 0), (1, 0), (0, 1), (1, 1)],  // O
        [(0, 0), (1, 0), (2, 0), (1, 1)],  // T
        [(1, 0), (2, 0), (0, 1), (1, 1)],  // S
        [(0, 0), (1, 0), (1, 1), (2, 1)],  // Z
        [(0, 0), (0, 1), (0, 2), (1, 2)],  // L
        [(1, 0), (1, 1), (1, 2), (0, 2)],  // J
    ]
    /// Все повороты каждой фигуры, клетки сдвинуты к (0, 0)
    static let rotations: [[[(Int, Int)]]] = baseShapes.map { shape in
        var result: [[(Int, Int)]] = []
        var cells = shape
        for _ in 0..<4 {
            let minX = cells.map(\.0).min()!
            let minY = cells.map(\.1).min()!
            result.append(cells.map { ($0.0 - minX, $0.1 - minY) })
            cells = cells.map { ($0.1, -$0.0) }
        }
        return result
    }
    static let palette: [Color] = [
        Color(red: 0.35, green: 0.9, blue: 1), Color(red: 1, green: 0.85, blue: 0.25), Color(red: 0.75, green: 0.45, blue: 1),
        Color(red: 0.4, green: 0.95, blue: 0.45), Color(red: 1, green: 0.4, blue: 0.4), Color(red: 1, green: 0.62, blue: 0.2),
        Color(red: 0.4, green: 0.55, blue: 1),
    ]
    static let cols = 10
    static let pieceTime = 0.8

    /// Состояние партии в одном «стакане»; пересчитывается только при падении новой фигуры
    final class Game {
        let rows: Int
        let seed: Int
        var start: Double
        var grid: [Int]
        var placed = 0
        var flashRows: [Int] = []
        var flashTime = -10.0

        init(rows: Int, seed: Int, start: Double) {
            self.rows = rows
            self.seed = seed
            self.start = start
            grid = Array(repeating: 0, count: rows * IdleBlocks.cols)
        }
    }
    nonisolated(unsafe) static var games: [String: Game] = [:]

    static func draw(in context: inout GraphicsContext, zones: IdleZones, t: Double) {
        let cell: CGFloat = 3
        let rows = Int(zones.size.height / cell)
        for (index, zone) in [zones.left, zones.right].enumerated() {
            let key = "\(index)-\(rows)"
            let game = games[key] ?? Game(rows: rows, seed: index * 1000, start: t)
            games[key] = game

            let elapsed = (t - game.start) / pieceTime
            // Давно не показывались (или время пошло назад) — начинаем новую партию
            if elapsed < 0 || Int(elapsed) - game.placed > 40 {
                game.start = t
                game.placed = 0
                game.grid = Array(repeating: 0, count: rows * cols)
            }
            let n = Int(max(0, (t - game.start) / pieceTime))
            while game.placed < n { place(game, at: game.start + Double(game.placed + 1) * pieceTime) }

            let originX = zone.minX + (zone.width - CGFloat(cols) * cell) / 2
            let originY = zones.size.height - CGFloat(rows) * cell
            func fill(_ x: Int, _ y: Int, _ color: Color) {
                context.fill(Path(CGRect(x: originX + CGFloat(x) * cell, y: originY + CGFloat(y) * cell,
                                         width: cell - 0.5, height: cell - 0.5)), with: .color(color))
            }
            // Стакан
            for y in 0..<rows { for x in 0..<cols where game.grid[y * cols + x] > 0 { fill(x, y, palette[game.grid[y * cols + x] - 1]) } }
            // Падающая фигура: опускается по клеткам до места посадки
            if let move = bestMove(game, piece: piece(game, game.placed)) {
                let fraction = min(1, ((t - game.start) / pieceTime - Double(game.placed)) / 0.85)
                let y = Int((-2 + Double(move.y + 2) * fraction).rounded(.down))
                for (cx, cy) in rotations[move.piece][move.rotation] where y + cy >= 0 {
                    fill(move.x + cx, y + cy, palette[move.piece])
                }
            }
            // Вспышка собранных линий
            let flash = t - game.flashTime
            if flash >= 0 && flash < 0.25 {
                for row in game.flashRows {
                    context.fill(Path(CGRect(x: originX, y: originY + CGFloat(row) * cell, width: CGFloat(cols) * cell, height: cell - 0.5)),
                                 with: .color(.white.opacity(1 - flash / 0.25)))
                }
            }
        }
    }

    private static func piece(_ game: Game, _ number: Int) -> Int {
        Int(idleRandom(game.seed + number * 7919) * 7) % 7
    }

    private struct Move { let piece: Int; let rotation: Int; let x: Int; let y: Int }

    /// Лучший ход по простой оценке: ниже, ровнее, без дыр, с собранными линиями
    private static func bestMove(_ game: Game, piece: Int) -> Move? {
        var best: (score: Double, move: Move)?
        for (r, cells) in rotations[piece].enumerated() {
            let width = cells.map(\.0).max()! + 1
            for x in 0...(cols - width) {
                guard fits(game, cells, x, 0) else { continue }
                var y = 0
                while fits(game, cells, x, y + 1) { y += 1 }
                var grid = game.grid
                for (cx, cy) in cells { grid[(y + cy) * cols + x + cx] = piece + 1 }
                let score = evaluate(grid, rows: game.rows)
                if best == nil || score > best!.score { best = (score, Move(piece: piece, rotation: r, x: x, y: y)) }
            }
        }
        return best?.move
    }

    private static func fits(_ game: Game, _ cells: [(Int, Int)], _ x: Int, _ y: Int) -> Bool {
        cells.allSatisfy { cx, cy in
            let gy = y + cy
            return gy < game.rows && game.grid[gy * cols + x + cx] == 0
        }
    }

    private static func evaluate(_ grid: [Int], rows: Int) -> Double {
        var lines = 0
        for y in 0..<rows where (0..<cols).allSatisfy({ grid[y * cols + $0] > 0 }) { lines += 1 }
        var heights = [Int](repeating: 0, count: cols)
        var holes = 0
        for x in 0..<cols {
            var seen = false
            for y in 0..<rows {
                if grid[y * cols + x] > 0 {
                    if !seen { heights[x] = rows - y; seen = true }
                } else if seen { holes += 1 }
            }
        }
        let bumpiness = zip(heights, heights.dropFirst()).map { abs($0 - $1) }.reduce(0, +)
        return -0.51 * Double(heights.reduce(0, +)) + 0.76 * Double(lines) - 0.36 * Double(holes) - 0.18 * Double(bumpiness)
    }

    /// Кладёт очередную фигуру, убирает собранные линии; если стакан переполнен — начинает заново
    private static func place(_ game: Game, at time: Double) {
        defer { game.placed += 1 }
        guard let move = bestMove(game, piece: piece(game, game.placed)) else {
            game.grid = Array(repeating: 0, count: game.rows * cols)
            return
        }
        for (cx, cy) in rotations[move.piece][move.rotation] { game.grid[(move.y + cy) * cols + move.x + cx] = move.piece + 1 }
        let full = (0..<game.rows).filter { y in (0..<cols).allSatisfy { game.grid[y * cols + $0] > 0 } }
        if !full.isEmpty {
            game.flashRows = full
            game.flashTime = time
            var kept = (0..<game.rows).filter { !full.contains($0) }.flatMap { y in game.grid[(y * cols)..<(y * cols + cols)] }
            kept.insert(contentsOf: Array(repeating: 0, count: full.count * cols), at: 0)
            game.grid = kept
        }
        // Верх стакана занят — новая партия
        if (0..<(2 * cols)).contains(where: { game.grid[$0] > 0 }) {
            game.grid = Array(repeating: 0, count: game.rows * cols)
        }
    }
}

// MARK: - Щенок

/// Щенок пинает мячик сквозь чёлку, бежит за ним, приносит обратно в зубах и радостно виляет хвостом
private enum IdlePuppy {
    static let walkA = Sprite(rows: [
        ".........##.",
        "#.......####",
        "#......##.#-",
        ".#######-##.",
        ".#########..",
        ".#########..",
        ".#.#...#.#..",
    ])
    static let walkB = Sprite(rows: [
        ".........##.",
        "#.......####",
        "#......##.#-",
        ".#######-##.",
        ".#########..",
        ".#########..",
        "..#.#.#.#...",
    ])
    static let sitA = Sprite(rows: [
        "......##.",
        "#....####",
        "#...##.#-",
        ".#..#-##.",
        "..#####..",
        ".######..",
        ".######..",
        ".##.##...",
    ])
    static let sitB = Sprite(rows: [
        "......##.",
        ".....####",
        "....##.#-",
        "....#-##.",
        "#.#####..",
        "#######..",
        ".######..",
        ".##.##...",
    ])
    static let fur = Color(red: 0.96, green: 0.8, blue: 0.55)
    static let dark = Color(red: 0.45, green: 0.25, blue: 0.1)
    static let ballColor = Color(red: 1, green: 0.3, blue: 0.3)

    static func draw(in context: inout GraphicsContext, zones: IdleZones, t: Double) {
        let h = zones.size.height
        let px: CGFloat = 2
        let ground = h - 4
        let leftX = zones.left.midX - 5
        let rightX = zones.right.midX
        let cycle = 9.6
        let local = t.truncatingRemainder(dividingBy: cycle)
        let step = Int(t * 8) % 2 == 0
        let wag = Int(t * 6) % 2 == 0

        func ball(_ x: CGFloat, _ y: CGFloat) {
            context.fill(Path(ellipseIn: CGRect(x: x - 2, y: y - 4, width: 4, height: 4)), with: .color(ballColor))
        }
        func lerp(_ a: CGFloat, _ b: CGFloat, _ p: Double) -> CGFloat { a + (b - a) * CGFloat(min(1, max(0, p))) }
        /// Пробег под чёлкой быстрее, чем у краёв: в середине пути (за чёлкой) скорость в 1,3 раза выше средней, у краёв — в 0,7
        func run(_ a: CGFloat, _ b: CGFloat, _ p: Double) -> CGFloat {
            let q = min(1, max(0, p))
            return a + (b - a) * CGFloat(q - 0.3 * sin(2 * .pi * q) / (2 * .pi))
        }

        // Мяч
        switch local {
        case ..<1.5, 7.0...:
            ball(leftX + 15, ground)
        case ..<3.5:
            let p = (local - 1.5) / 2
            let bounce = abs(sin(p * .pi * 2.5)) * 11 * (1 - p * 0.7)
            ball(lerp(leftX + 15, rightX + 6, p), ground - CGFloat(bounce))
        case ..<4.2:
            ball(rightX + 6, ground)
        default: break
        }

        // Щенок
        switch local {
        case ..<2:
            (wag ? sitA : sitB).draw(in: &context, x: leftX, bottom: ground, pixel: px, color: fur, accent: fur, flip: false, dark: dark)
        case ..<4.2:
            let x = run(leftX, rightX - 4, (local - 2) / 2.2)
            (step ? walkA : walkB).draw(in: &context, x: x, bottom: ground, pixel: px, color: fur, accent: fur, flip: false, dark: dark)
        case ..<4.8:
            walkA.draw(in: &context, x: rightX - 4, bottom: ground, pixel: px, color: fur, accent: fur, flip: false, dark: dark)
            ball(rightX + 8, ground - 6)
        case ..<7.0:
            // Обратно с мячом в зубах
            let x = run(rightX - 4, leftX, (local - 4.8) / 2.2)
            (step ? walkA : walkB).draw(in: &context, x: x, bottom: ground, pixel: px, color: fur, accent: fur, flip: true, dark: dark)
            ball(x - 12, ground - 6)
        default:
            (wag ? sitA : sitB).draw(in: &context, x: leftX, bottom: ground, pixel: px, color: fur, accent: fur, flip: false, dark: dark)
        }
    }
}

// MARK: - Фейерверк

/// Ракеты взлетают по бокам чёлки и рассыпаются разноцветными пиксельными искрами
private enum IdleFireworks {
    static let palette: [Color] = [
        Color(red: 1, green: 0.4, blue: 0.7), Color(red: 1, green: 0.85, blue: 0.3), Color(red: 0.4, green: 0.9, blue: 1),
        Color(red: 0.5, green: 1, blue: 0.5), Color(red: 1, green: 0.55, blue: 0.25), Color(red: 0.8, green: 0.6, blue: 1),
    ]

    static func draw(in context: inout GraphicsContext, zones: IdleZones, t: Double) {
        let h = zones.size.height
        let period = 2.4
        for (index, zone) in [zones.left, zones.right].enumerated() {
            for shell in 0..<2 {
                let shifted = t + Double(index) * 1.1 + Double(shell) * 1.25
                let number = Int(floor(shifted / period))
                let local = shifted - Double(number) * period
                let seed = number * 31 + index * 7 + shell * 3
                let x = zone.minX + 7 + (zone.width - 14) * CGFloat(idleRandom(seed))
                let burstY = h * CGFloat(0.28 + 0.18 * idleRandom(seed + 1))
                let color = palette[Int(idleRandom(seed + 2) * Double(palette.count)) % palette.count]

                if local < 0.45 {
                    // Взлёт: огонёк со следом
                    let y = h - (h - burstY) * CGFloat(local / 0.45)
                    context.fill(Path(CGRect(x: x, y: y, width: 1.5, height: 1.5)), with: .color(.white))
                    context.fill(Path(CGRect(x: x + 0.25, y: y + 1.5, width: 1, height: 3)), with: .color(color.opacity(0.5)))
                } else if local < 1.6 {
                    let q = (local - 0.45) / 1.15
                    let spread = CGFloat(1 - pow(1 - q, 2)) * 11
                    for j in 0..<12 {
                        let angle = Double(j) / 12 * 2 * .pi + idleRandom(seed + 3) * 2
                        let px = x + CGFloat(cos(angle)) * spread
                        let py = burstY + CGFloat(sin(angle)) * spread + CGFloat(q * q) * 6
                        // Искры мерцают перед тем как погаснуть
                        let flicker = q > 0.6 && (Int(t * 20) + j) % 3 == 0 ? 0.3 : 1
                        context.fill(Path(CGRect(x: px, y: py, width: 1.5, height: 1.5)),
                                     with: .color((j % 3 == 0 ? .white : color).opacity((1 - q) * flicker)))
                    }
                }
            }
        }
    }
}

// MARK: - Ракета

/// Звёзды плывут мимо тремя слоями, время от времени ракета с пламенем пролетает сквозь чёлку (в одну сторону, потом в другую)
private enum IdleRocket {
    static let ship = Sprite(rows: [
        "..##....",
        "#####...",
        "#########",
        "#####..o.",
        "..##....",
    ])

    static func draw(in context: inout GraphicsContext, zones: IdleZones, t: Double) {
        let w = zones.size.width
        let h = zones.size.height
        // Звёзды: чем дальше слой, тем медленнее и тусклее
        for layer in 0..<3 {
            let speed = [5.0, 11.0, 21.0][layer]
            for i in 0..<10 {
                let seed = layer * 20 + i + 1
                let x = idleWrap(idleRandom(seed) * w - t * speed, w)
                let y = h * (0.1 + 0.8 * idleRandom(seed + 99))
                let twinkle = 0.55 + 0.45 * sin(t * 3 + Double(seed))
                let size: CGFloat = layer == 2 ? 1.6 : 1.1
                context.fill(Path(CGRect(x: x, y: y, width: size, height: size)),
                             with: .color(.white.opacity((0.25 + 0.25 * Double(layer)) * twinkle)))
            }
        }

        // Ракета: пролёт 3 секунды, цикл 10 с, лететь по очереди то вправо, то влево
        let period = 10.0
        let number = Int(floor(t / period))
        let local = t - Double(number) * period
        guard local < 3.2 else { return }
        let rightward = number % 2 == 0
        let p = CGFloat(local / 3.2)
        let progress = rightward ? p : 1 - p
        let x = -14 + (w + 28) * progress
        let y = h * 0.5 + CGFloat(sin(t * 6)) * 1.1
        let dir: CGFloat = rightward ? 1 : -1
        // Пламя сзади: длина мерцает
        let flame = 5 + CGFloat(abs(sin(t * 40))) * 3
        context.fill(Path(CGRect(x: rightward ? x - 9 - flame : x + 9, y: y - 1.5, width: flame, height: 3)),
                     with: .color(Color(red: 1, green: 0.5, blue: 0.12)))
        context.fill(Path(CGRect(x: rightward ? x - 9 - flame * 0.55 : x + 9, y: y - 0.8, width: flame * 0.55, height: 1.6)),
                     with: .color(Color(red: 1, green: 0.9, blue: 0.4)))
        // Искры от двигателя
        for k in 0..<4 {
            let sx = x - dir * (10 + CGFloat(k) * 4 + CGFloat(idleRandom(Int(t * 10) + k) * 3))
            context.fill(Path(CGRect(x: sx, y: y + CGFloat(idleRandom(k + 7) - 0.5) * 6, width: 1.2, height: 1.2)),
                         with: .color(Color(red: 1, green: 0.7, blue: 0.3).opacity(0.7 - Double(k) * 0.15)))
        }
        ship.draw(in: &context, x: x, bottom: y + 4, pixel: 1.6, color: Color(white: 0.92),
                  accent: Color(red: 0.4, green: 0.85, blue: 1), flip: !rightward)
    }
}

// MARK: - Поезд

/// Чёлка — тоннель: паровозик с вагончиками выезжает из-за чёлки, пыхтит дымом и уезжает в тоннель с другой стороны
private enum IdleTrain {
    static func draw(in context: inout GraphicsContext, zones: IdleZones, t: Double) {
        let w = zones.size.width
        let h = zones.size.height
        let ground = h - 5

        // Рельсы и шпалы
        for zone in [zones.left, zones.right] {
            context.fill(Path(CGRect(x: zone.minX, y: ground, width: zone.width, height: 1)), with: .color(.white.opacity(0.4)))
            var x = zone.minX + 1
            while x < zone.maxX {
                context.fill(Path(CGRect(x: x, y: ground + 1, width: 1.3, height: 1.8)), with: .color(Color(red: 0.55, green: 0.4, blue: 0.25).opacity(0.7)))
                x += 4
            }
        }

        let period = 13.0
        let run = 6.4
        let number = Int(floor(t / period))
        let local = t - Double(number) * period
        guard local < run else { return }

        // Нечётные проезды — в обратную сторону: рисуем то же самое, отразив холст
        var layer = context
        if number % 2 == 1 {
            layer.translateBy(x: w, y: 0)
            layer.scaleBy(x: -1, y: 1)
        }
        let length: CGFloat = 54
        let head = -6 + (w + length + 12) * CGFloat(local / run)
        let red = Color(red: 0.9, green: 0.25, blue: 0.22)
        let dark = Color(red: 0.55, green: 0.12, blue: 0.12)

        // Дым из трубы: клубы остаются позади, растут и тают
        for k in 0..<7 {
            let age = Double(k) * 0.16 + idleWrap(t * 2.5, 0.16)
            let px = head - 3 - CGFloat(age) * 26
            let py = ground - 15 - CGFloat(age) * 9
            let r = 1.6 + CGFloat(age) * 2.2
            layer.fill(Path(ellipseIn: CGRect(x: px - r, y: py - r, width: r * 2, height: r * 2)),
                       with: .color(Color(white: 0.9).opacity(0.5 * max(0, 1 - age / 1.1))))
        }
        // Паровоз
        layer.fill(Path(CGRect(x: head - 17, y: ground - 10, width: 17, height: 6)), with: .color(red))
        layer.fill(Path(CGRect(x: head - 17, y: ground - 15, width: 7, height: 5)), with: .color(dark))
        layer.fill(Path(CGRect(x: head - 5, y: ground - 14, width: 3.5, height: 4)), with: .color(Color(white: 0.2)))
        layer.fill(Path(ellipseIn: CGRect(x: head - 1.8, y: ground - 8.4, width: 2.6, height: 2.6)), with: .color(Color(red: 1, green: 0.9, blue: 0.4)))
        // Вагончики
        let wagonColors = [Color(red: 0.3, green: 0.6, blue: 1), Color(red: 0.4, green: 0.85, blue: 0.5), Color(red: 1, green: 0.75, blue: 0.25)]
        for k in 0..<3 {
            let wx = head - 19 - CGFloat(k) * 13
            layer.fill(Path(CGRect(x: wx - 11.5, y: ground - 9, width: 11.5, height: 5)), with: .color(wagonColors[k]))
            layer.fill(Path(CGRect(x: wx - 1.5, y: ground - 7, width: 2.2, height: 1)), with: .color(Color(white: 0.7)))
            for dx in [-8.0, -3.0] {
                layer.fill(Path(ellipseIn: CGRect(x: wx + CGFloat(dx) - 1.6, y: ground - 3.2, width: 3.2, height: 3.2)), with: .color(Color(white: 0.15)))
            }
        }
        // Колёса паровоза с бегущей спицей
        for dx in [-14.0, -8.0, -2.5] {
            let cx = head + CGFloat(dx)
            layer.fill(Path(ellipseIn: CGRect(x: cx - 2.2, y: ground - 4.4, width: 4.4, height: 4.4)), with: .color(Color(white: 0.15)))
            let a = t * 14
            var spoke = Path()
            spoke.move(to: CGPoint(x: cx, y: ground - 2.2))
            spoke.addLine(to: CGPoint(x: cx + CGFloat(cos(a)) * 1.8, y: ground - 2.2 + CGFloat(sin(a)) * 1.8))
            layer.stroke(spoke, with: .color(.white.opacity(0.8)), lineWidth: 0.7)
        }
    }
}

// MARK: - Снегопад

/// Падает снег и копится сугробами по бокам; слева стоит снеговик, справа ёлка. Раз в 28 секунд всё тает и начинается заново
private enum IdleSnow {
    static let snowman = Sprite(rows: [
        "..###..",
        ".#-#-#.",
        "..#o#..",
        ".#####.",
        "#######",
        "#######",
        ".#####.",
    ])
    static let tree = Sprite(rows: [
        "...#...",
        "..###..",
        "..###..",
        ".#####.",
        ".#####.",
        "#######",
        "...-...",
    ])

    static func draw(in context: inout GraphicsContext, zones: IdleZones, t: Double) {
        let h = zones.size.height
        let cycle = 28.0
        let local = t.truncatingRemainder(dividingBy: cycle)
        // Сугроб растёт 20 секунд и тает последние 5
        let growth = CGFloat(min(1, local / 20))
        let melt = CGFloat(max(0, (local - 23) / 5))
        let pile = (1.2 + 5 * growth) * (1 - melt)

        for (index, zone) in [zones.left, zones.right].enumerated() {
            // Сугроб: холмики разной высоты
            var path = Path()
            path.move(to: CGPoint(x: zone.minX, y: h))
            let steps = 8
            for i in 0...steps {
                let x = zone.minX + zone.width * CGFloat(i) / CGFloat(steps)
                let bump = CGFloat(0.55 + 0.45 * sin(Double(i) * 1.7 + Double(index) * 2))
                path.addLine(to: CGPoint(x: x, y: h - pile * bump - 0.5))
            }
            path.addLine(to: CGPoint(x: zone.maxX, y: h))
            path.closeSubpath()
            context.fill(path, with: .color(Color(white: 0.95).opacity(0.95)))

            // Снежинки
            for i in 0..<14 {
                let seed = Double(index * 14 + i) + 1
                let speed = 7 + 7 * idleRandom(Int(seed) + 50)
                let y = CGFloat(idleWrap(t * speed + seed * 9, Double(h) + 6)) - 3
                let x = zone.minX + zone.width * CGFloat(idleRandom(Int(seed)))
                    + CGFloat(sin(t * 0.9 + seed)) * 3
                let size: CGFloat = 0.9 + CGFloat(idleRandom(Int(seed) + 80)) * 1.0
                context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: size, height: size)), with: .color(.white.opacity(0.85)))
            }
        }

        // Снеговик слева и ёлка справа сидят на сугробе
        let base = h - pile * 0.5 - 0.5
        snowman.draw(in: &context, x: zones.left.midX - 2, bottom: base, pixel: 1.6, color: .white,
                     accent: Color(red: 1, green: 0.55, blue: 0.2), flip: false, dark: Color(white: 0.15))
        tree.draw(in: &context, x: zones.right.midX + 2, bottom: base, pixel: 1.6, color: Color(red: 0.25, green: 0.75, blue: 0.4),
                  accent: .white, flip: false, dark: Color(red: 0.5, green: 0.32, blue: 0.15))
    }
}

// MARK: - Робот

/// Пиксельный робот шагает сквозь чёлку, на другой стороне останавливается, мигает антенной и машет рукой, потом идёт обратно
private enum IdleRobot {
    static let head = [
        "...o...",
        "...#...",
        ".#####.",
        ".#o#o#.",
        ".#####.",
    ]
    static let walkA = Sprite(rows: head + ["#######", "#-###-#", "#######", ".#####.", ".#...#.", "##...##"])
    static let walkB = Sprite(rows: head + ["#######", "#-###-#", "#######", ".#####.", "..#.#..", "..#.#.."])
    /// Машет: правая рука поднята
    static let wave = Sprite(rows: [
        "...o..#",
        "...#..#",
        ".#####.",
        ".#o#o#.",
        ".#####.",
        "#######",
        "#-###..",
        "#######",
        ".#####.",
        ".#...#.",
        "##...##",
    ])
    static let body = Color(red: 0.72, green: 0.78, blue: 0.86)
    static let glow = Color(red: 0.3, green: 0.95, blue: 1)

    static func draw(in context: inout GraphicsContext, zones: IdleZones, t: Double) {
        let h = zones.size.height
        let px: CGFloat = 1.8
        let ground = h - 3
        let leftX = zones.left.midX - 3
        let rightX = zones.right.midX + 3
        let cycle = 16.0
        let local = t.truncatingRemainder(dividingBy: cycle)
        let step = Int(t * 7) % 2 == 0

        func lerp(_ a: CGFloat, _ b: CGFloat, _ p: Double) -> CGFloat { a + (b - a) * CGFloat(min(1, max(0, p))) }
        func draw(_ sprite: Sprite, x: CGFloat, flip: Bool) {
            sprite.draw(in: &context, x: x, bottom: ground, pixel: px, color: body, accent: glow, flip: flip,
                        dark: Color(red: 0.3, green: 0.35, blue: 0.45))
        }

        switch local {
        case ..<1.5:
            draw(walkA, x: leftX, flip: false)
        case ..<4.5:
            draw(step ? walkA : walkB, x: lerp(leftX, rightX, (local - 1.5) / 3), flip: false)
        case ..<8.5:
            // Остановился справа и приветствует
            let waving = Int(t * 4) % 2 == 0
            draw(waving ? wave : walkA, x: rightX, flip: true)
            // Реплика: «бип» из двух мигающих точек
            if Int(t * 3) % 2 == 0 {
                for k in 0..<2 {
                    context.fill(Path(CGRect(x: rightX - 15 + CGFloat(k) * 4, y: 3, width: 2, height: 2)), with: .color(glow.opacity(0.9)))
                }
            }
        case ..<11.5:
            draw(step ? walkA : walkB, x: lerp(rightX, leftX, (local - 8.5) / 3), flip: true)
        default:
            draw(walkA, x: leftX, flip: false)
        }
    }
}

// MARK: - Летучие мыши

/// Мыши порхают через чёлку, слева светится тыква, справа покачивается привидение
private enum IdleBats {
    static let up = Sprite(rows: ["#.....#", "##.#.##", ".#####.", "..#.#.."])
    static let down = Sprite(rows: ["..###..", ".#####.", "##.#.##", "#.....#"])

    static func draw(in context: inout GraphicsContext, zones: IdleZones, t: Double) {
        let w = zones.size.width
        let h = zones.size.height

        // Тыква слева: огонёк внутри мерцает
        let pumpkin = CGPoint(x: zones.left.midX - 4, y: h - 6)
        let flicker = 0.7 + 0.3 * sin(t * 9) * sin(t * 5.3)
        context.fill(Path(ellipseIn: CGRect(x: pumpkin.x - 12, y: pumpkin.y - 11, width: 24, height: 22)),
                     with: .radialGradient(Gradient(colors: [Color.orange.opacity(0.22 * flicker), .clear]),
                                           center: pumpkin, startRadius: 0, endRadius: 12))
        context.fill(Path(ellipseIn: CGRect(x: pumpkin.x - 6.5, y: pumpkin.y - 5, width: 13, height: 10)), with: .color(Color(red: 1, green: 0.5, blue: 0.1)))
        context.fill(Path(CGRect(x: pumpkin.x - 1, y: pumpkin.y - 7, width: 2, height: 2.5)), with: .color(Color(red: 0.3, green: 0.6, blue: 0.2)))
        for dx in [-3.0, 2.2] {
            var eye = Path()
            eye.move(to: CGPoint(x: pumpkin.x + CGFloat(dx), y: pumpkin.y - 2.5))
            eye.addLine(to: CGPoint(x: pumpkin.x + CGFloat(dx) + 1.6, y: pumpkin.y - 2.5))
            eye.addLine(to: CGPoint(x: pumpkin.x + CGFloat(dx) + 0.8, y: pumpkin.y - 0.6))
            eye.closeSubpath()
            context.fill(eye, with: .color(Color(red: 1, green: 0.95, blue: 0.4).opacity(flicker)))
        }
        var mouth = Path()
        mouth.move(to: CGPoint(x: pumpkin.x - 3, y: pumpkin.y + 1.5))
        mouth.addQuadCurve(to: CGPoint(x: pumpkin.x + 3, y: pumpkin.y + 1.5), control: CGPoint(x: pumpkin.x, y: pumpkin.y + 4.5))
        context.stroke(mouth, with: .color(Color(red: 1, green: 0.95, blue: 0.4).opacity(flicker)), lineWidth: 1)

        // Привидение справа: плавно парит, иногда моргает
        let ghost = CGPoint(x: zones.right.midX + 3, y: h * 0.5 + CGFloat(sin(t * 1.6)) * 3.5)
        var body = Path()
        body.move(to: CGPoint(x: ghost.x - 5, y: ghost.y + 6))
        body.addLine(to: CGPoint(x: ghost.x - 5, y: ghost.y - 1))
        body.addQuadCurve(to: CGPoint(x: ghost.x + 5, y: ghost.y - 1), control: CGPoint(x: ghost.x, y: ghost.y - 13))
        body.addLine(to: CGPoint(x: ghost.x + 5, y: ghost.y + 6))
        for k in 0..<3 {
            let x1 = ghost.x + 5 - CGFloat(k) * 3.33 - 1.67
            let x2 = ghost.x + 5 - CGFloat(k + 1) * 3.33
            body.addQuadCurve(to: CGPoint(x: x2, y: ghost.y + 6),
                              control: CGPoint(x: x1, y: ghost.y + 6 + CGFloat(sin(t * 5 + Double(k))) * 1.5 + 2))
        }
        body.closeSubpath()
        context.fill(body, with: .color(Color(white: 0.95).opacity(0.88)))
        let blink = t.truncatingRemainder(dividingBy: 4) < 0.15
        for dx in [-2.4, 2.4] {
            context.fill(Path(ellipseIn: CGRect(x: ghost.x + CGFloat(dx) - 0.9, y: ghost.y - 4, width: 1.8, height: blink ? 0.4 : 2.4)),
                         with: .color(Color(white: 0.1)))
        }

        // Мыши: у каждой своя высота, скорость и направление
        for i in 0..<4 {
            let seed = i * 11 + 3
            let speed = 14 + 8 * idleRandom(seed)
            let direction: Double = i % 2 == 0 ? 1 : -1
            let progress = idleWrap(t * speed / Double(w + 30) + idleRandom(seed + 1), 1)
            let x = CGFloat(direction > 0 ? progress : 1 - progress) * (w + 30) - 15
            let y = h * (0.3 + 0.35 * CGFloat(idleRandom(seed + 2))) + CGFloat(sin(t * 3 + Double(seed))) * 4
            let flap = Int(t * 9 + Double(i)) % 2 == 0
            (flap ? up : down).draw(in: &context, x: x, bottom: y + 3, pixel: 1.4, color: Color(red: 0.55, green: 0.35, blue: 0.85),
                                    accent: Color(red: 1, green: 0.3, blue: 0.3), flip: direction < 0)
        }
    }
}

// MARK: - Катушка Тесла

/// Две катушки по краям чёлки: разряды бьют вверх и тянутся друг к другу — вспышки на внутренних краях, когда дуга «замыкается» за чёлкой
private enum IdleTesla {
    private static func bolt(from a: CGPoint, to b: CGPoint, seed: Int, jitter: CGFloat) -> Path {
        var path = Path()
        path.move(to: a)
        let segments = 6
        for i in 1..<segments {
            let k = CGFloat(i) / CGFloat(segments)
            let normal = CGPoint(x: -(b.y - a.y), y: b.x - a.x)
            let length = max(1, hypot(normal.x, normal.y))
            let offset = (CGFloat(idleRandom(seed + i * 17)) - 0.5) * 2 * jitter
            path.addLine(to: CGPoint(x: a.x + (b.x - a.x) * k + normal.x / length * offset,
                                     y: a.y + (b.y - a.y) * k + normal.y / length * offset))
        }
        path.addLine(to: b)
        return path
    }

    private static func strike(_ context: inout GraphicsContext, _ path: Path, alpha: Double) {
        context.stroke(path, with: .color(Color(red: 0.55, green: 0.5, blue: 1).opacity(0.35 * alpha)), lineWidth: 3.5)
        context.stroke(path, with: .color(Color(red: 0.7, green: 0.85, blue: 1).opacity(0.9 * alpha)), lineWidth: 1.2)
        context.stroke(path, with: .color(.white.opacity(alpha)), lineWidth: 0.5)
    }

    static func draw(in context: inout GraphicsContext, zones: IdleZones, t: Double) {
        let h = zones.size.height
        let base = h - 3
        let frame = Int(t * 14)
        let phase = t.truncatingRemainder(dividingBy: 5)
        // Каждые 5 секунд на 1,2 с дуга замыкается между катушками (за чёлкой)
        let connected = phase > 3.4 && phase < 4.6
        var tops: [CGPoint] = []

        for (index, zone) in [zones.left, zones.right].enumerated() {
            let x = zone.midX + (index == 0 ? -6 : 6)
            let top = CGPoint(x: x, y: base - 17)
            tops.append(top)
            // Катушка: основание, витки, шар
            context.fill(Path(CGRect(x: x - 5, y: base - 2, width: 10, height: 2)), with: .color(Color(white: 0.35)))
            for k in 0..<4 {
                context.fill(Path(CGRect(x: x - 3.4 + CGFloat(k) * 0.5, y: base - 4 - CGFloat(k) * 2.8, width: 6.8 - CGFloat(k), height: 2)),
                             with: .color(Color(red: 0.75, green: 0.5, blue: 0.25)))
            }
            let pulse = 0.8 + 0.2 * sin(t * 12)
            context.fill(Path(ellipseIn: CGRect(x: x - 7, y: top.y - 7, width: 14, height: 14)),
                         with: .radialGradient(Gradient(colors: [Color(red: 0.6, green: 0.6, blue: 1).opacity(0.5 * pulse), .clear]),
                                               center: top, startRadius: 0, endRadius: 7))
            context.fill(Path(ellipseIn: CGRect(x: x - 3, y: top.y - 3, width: 6, height: 6)), with: .color(Color(white: 0.9)))

            // Случайные разряды в воздух (кадр меняется 14 раз в секунду, поэтому мерцают)
            if frame % 3 != 0 {
                let angle = idleRandom(frame * 3 + index) * .pi - .pi
                let end = CGPoint(x: x + CGFloat(cos(angle)) * 15, y: top.y + CGFloat(sin(angle)) * 11 * -1 - 2)
                strike(&context, bolt(from: top, to: end, seed: frame * 7 + index * 31, jitter: 3), alpha: 0.9)
            }
        }

        // Дуга между катушками: видна у внутренних краёв, остальное закрывает чёлка
        if connected {
            let alpha = 0.6 + 0.4 * abs(sin(t * 30))
            strike(&context, bolt(from: tops[0], to: CGPoint(x: zones.size.width / 2, y: h * 0.5), seed: frame * 5, jitter: 4), alpha: alpha)
            strike(&context, bolt(from: tops[1], to: CGPoint(x: zones.size.width / 2, y: h * 0.5), seed: frame * 5 + 99, jitter: 4), alpha: alpha)
            // Вспышка на внутренних краях
            for edgeX in [zones.left.maxX, zones.right.minX] {
                context.fill(Path(CGRect(x: edgeX - 8, y: 0, width: 16, height: h)),
                             with: .radialGradient(Gradient(colors: [Color(red: 0.7, green: 0.8, blue: 1).opacity(0.28 * alpha), .clear]),
                                                   center: CGPoint(x: edgeX, y: h / 2), startRadius: 0, endRadius: 14))
            }
        }
    }
}

// MARK: - Океан

/// Волны накатывают по всей ширине, кораблик с парусом плывёт сквозь чёлку, над водой кружат чайки
private enum IdleOcean {
    static func draw(in context: inout GraphicsContext, zones: IdleZones, t: Double) {
        let w = zones.size.width
        let h = zones.size.height

        func waveY(_ x: CGFloat, layer: Int, t: Double) -> CGFloat {
            let k = [0.09, 0.13][layer]
            let speed = [1.6, 2.4][layer]
            return h - [9.0, 5.5][layer] + CGFloat(sin(Double(x) * k + t * speed)) * [2.2, 1.8][layer]
        }

        // Кораблик: 14 секунд туда, потом обратно; качается на волне
        let period = 14.0
        let number = Int(floor(t / period))
        let local = (t - Double(number) * period) / period
        let rightward = number % 2 == 0
        let boatX = CGFloat(rightward ? local : 1 - local) * (w + 40) - 20
        let boatY = waveY(boatX, layer: 0, t: t)
        let tilt = (waveY(boatX + 3, layer: 0, t: t) - waveY(boatX - 3, layer: 0, t: t)) / 6
        var layer = context
        layer.translateBy(x: boatX, y: boatY - 2)
        layer.rotate(by: .radians(Double(tilt) * 0.5))
        let dir: CGFloat = rightward ? 1 : -1
        layer.fill(Path { p in
            p.move(to: CGPoint(x: -7, y: -1)); p.addLine(to: CGPoint(x: 7, y: -1))
            p.addLine(to: CGPoint(x: 5, y: 3)); p.addLine(to: CGPoint(x: -5, y: 3)); p.closeSubpath()
        }, with: .color(Color(red: 0.62, green: 0.38, blue: 0.2)))
        layer.fill(Path(CGRect(x: -0.5, y: -13, width: 1, height: 12)), with: .color(Color(white: 0.7)))
        layer.fill(Path { p in
            p.move(to: CGPoint(x: dir * 0.8, y: -12)); p.addLine(to: CGPoint(x: dir * 7, y: -2)); p.addLine(to: CGPoint(x: dir * 0.8, y: -2)); p.closeSubpath()
        }, with: .color(.white))
        layer.fill(Path { p in
            p.move(to: CGPoint(x: dir * -0.8, y: -10)); p.addLine(to: CGPoint(x: dir * -4.5, y: -2)); p.addLine(to: CGPoint(x: dir * -0.8, y: -2)); p.closeSubpath()
        }, with: .color(Color(red: 1, green: 0.85, blue: 0.85)))

        // Две волны перед корабликом
        for l in 0..<2 {
            var path = Path()
            path.move(to: CGPoint(x: 0, y: h))
            var x: CGFloat = 0
            while x <= w {
                path.addLine(to: CGPoint(x: x, y: waveY(x, layer: l, t: t)))
                x += 2
            }
            path.addLine(to: CGPoint(x: w, y: h))
            path.closeSubpath()
            context.fill(path, with: .color(l == 0 ? Color(red: 0.12, green: 0.45, blue: 0.85).opacity(0.85) : Color(red: 0.2, green: 0.6, blue: 1).opacity(0.9)))
        }
        // Пена
        for i in 0..<12 {
            let x = CGFloat(idleWrap(Double(i) * 19 + t * 6, Double(w)))
            context.fill(Path(CGRect(x: x, y: waveY(x, layer: 1, t: t) - 0.6, width: 3, height: 1)), with: .color(.white.opacity(0.7)))
        }

        // Чайки
        for i in 0..<2 {
            let x = CGFloat(idleWrap(t * (9 + Double(i) * 4) + Double(i) * 70, Double(w + 20))) - 10
            let y = h * 0.28 + CGFloat(i) * 5 + CGFloat(sin(t * 1.3 + Double(i))) * 2
            let flap = CGFloat(sin(t * 7 + Double(i) * 2)) * 2
            var wings = Path()
            wings.move(to: CGPoint(x: x - 4, y: y + flap))
            wings.addQuadCurve(to: CGPoint(x: x, y: y), control: CGPoint(x: x - 2, y: y - 2 - flap))
            wings.addQuadCurve(to: CGPoint(x: x + 4, y: y + flap), control: CGPoint(x: x + 2, y: y - 2 - flap))
            context.stroke(wings, with: .color(.white.opacity(0.9)), lineWidth: 1)
        }
    }
}

// MARK: - Медузы

/// Светящиеся медузы пульсируют куполом и медленно плывут: слева голубая, справа розовая
private enum IdleJellyfish {
    static func draw(in context: inout GraphicsContext, zones: IdleZones, t: Double) {
        let h = zones.size.height
        for (index, zone) in [zones.left, zones.right].enumerated() {
            let tint = index == 0 ? Color(red: 0.3, green: 0.85, blue: 1) : Color(red: 1, green: 0.45, blue: 0.85)

            // Планктон
            for i in 0..<8 {
                let seed = Double(index * 8 + i) + 1
                let x = zone.minX + zone.width * CGFloat(idleRandom(Int(seed) * 3)) + CGFloat(sin(t * 0.4 + seed)) * 3
                let y = h * CGFloat(idleRandom(Int(seed) * 5)) - CGFloat(idleWrap(t * 1.5 + seed * 4, 8))
                let twinkle = 0.3 + 0.7 * abs(sin(t * 1.2 + seed))
                context.fill(Path(ellipseIn: CGRect(x: x, y: idleWrapCG(y, h), width: 1.1, height: 1.1)), with: .color(tint.opacity(0.5 * twinkle)))
            }

            // Купол сжимается с толчком и расправляется; вместе с толчком медуза всплывает
            let seed = Double(index) * 2.3
            let beat = (sin(t * 2.6 + seed) + 1) / 2
            let squeeze = 1 + 0.18 * CGFloat(beat)
            let cx = zone.midX + CGFloat(sin(t * 0.5 + seed)) * 7
            let cy = h * 0.42 + CGFloat(sin(t * 0.9 + seed)) * 5 - CGFloat(beat) * 1.5
            let bw = 13 / squeeze
            let bh = 8 * squeeze

            // Щупальца: волнистые линии, тянущиеся вслед
            for k in 0..<5 {
                let offset = CGFloat(k - 2) * bw / 5
                var tentacle = Path()
                tentacle.move(to: CGPoint(x: cx + offset, y: cy))
                for s in 1...5 {
                    let sy = cy + CGFloat(s) * 3.1
                    let sx = cx + offset + CGFloat(sin(t * 3 - Double(s) * 0.9 + Double(k))) * (1 + CGFloat(s) * 0.45)
                    tentacle.addLine(to: CGPoint(x: sx, y: sy))
                }
                context.stroke(tentacle, with: .color(tint.opacity(0.55)), lineWidth: 0.9)
            }
            // Купол — полукруг с внутренним свечением
            var bell = Path()
            bell.move(to: CGPoint(x: cx - bw / 2, y: cy))
            bell.addQuadCurve(to: CGPoint(x: cx + bw / 2, y: cy), control: CGPoint(x: cx, y: cy - bh * 1.7))
            bell.addQuadCurve(to: CGPoint(x: cx - bw / 2, y: cy), control: CGPoint(x: cx, y: cy + 2.2))
            context.fill(bell, with: .linearGradient(Gradient(colors: [tint.opacity(0.95), tint.opacity(0.35)]),
                                                     startPoint: CGPoint(x: cx, y: cy - bh), endPoint: CGPoint(x: cx, y: cy + 2)))
            context.fill(Path(ellipseIn: CGRect(x: cx - bw / 2 - 5, y: cy - bh - 4, width: bw + 10, height: bh + 10)),
                         with: .radialGradient(Gradient(colors: [tint.opacity(0.25), .clear]), center: CGPoint(x: cx, y: cy - bh / 2),
                                               startRadius: 0, endRadius: bw))
            context.fill(Path(ellipseIn: CGRect(x: cx - 2, y: cy - bh * 0.75, width: 4, height: 1.8)), with: .color(.white.opacity(0.55)))
        }
    }

    private static func idleWrapCG(_ value: CGFloat, _ period: CGFloat) -> CGFloat {
        CGFloat(idleWrap(Double(value), Double(period)))
    }
}

// MARK: - Бегун

/// Платформер: герой бежит на месте, мир едет мимо — монетки выстраиваются дугой, он подпрыгивает и собирает их, звёздочки вспыхивают
private enum IdleRunner {
    static let hero = Sprite(rows: [
        "..##..",
        ".####.",
        "..oo..",
        ".####.",
        "#-##-#",
        "..--..",
        ".-..-.",
        "##..##",
    ])
    static let coinGold = Color(red: 1, green: 0.82, blue: 0.2)

    static func draw(in context: inout GraphicsContext, zones: IdleZones, t: Double) {
        let w = zones.size.width
        let h = zones.size.height
        let ground = h - 5
        let heroX = zones.left.midX - 4
        let speed = 34.0

        // Земля из кирпичиков едет влево
        context.fill(Path(CGRect(x: 0, y: ground, width: w, height: 5)), with: .color(Color(red: 0.55, green: 0.3, blue: 0.15)))
        var brick = -idleWrap(t * speed, 8)
        while brick < w {
            context.fill(Path(CGRect(x: brick, y: ground, width: 0.8, height: 5)), with: .color(Color(red: 0.3, green: 0.15, blue: 0.08)))
            brick += 8
        }
        context.fill(Path(CGRect(x: 0, y: ground, width: w, height: 1)), with: .color(Color(red: 0.4, green: 0.8, blue: 0.35)))

        // Прыжок раз в 2 секунды, монетки приходят под вершину прыжка
        let period = 2.0
        let airTime = 0.85
        let jumpHeight: CGFloat = 13
        let number = Int(floor(t / period))
        let phase = t - Double(number) * period
        var lift: CGFloat = 0
        if phase < airTime { lift = CGFloat(sin(.pi * phase / airTime)) * jumpHeight }

        for k in (number - 1)...(number + 6) {
            let apexTime = Double(k) * period + airTime / 2
            let baseX = heroX + CGFloat((apexTime - t) * speed)
            for (j, dx) in [-9.0, 0.0, 9.0].enumerated() {
                let x = baseX + CGFloat(dx)
                guard x > -6, x < w + 6 else { continue }
                // Дуга: боковые монетки чуть ниже
                let y = ground - 8 - jumpHeight + (j == 1 ? 0 : 3.5)
                let collectedAt = (apexTime - t) + Double(dx) / speed
                if collectedAt < 0 && collectedAt > -0.35 {
                    // Собрана: вспыхивает звёздочкой и тает
                    let q = CGFloat(-collectedAt / 0.35)
                    context.fill(Path(ellipseIn: CGRect(x: x - 3 - q * 3, y: y - 3 - q * 3, width: 6 + q * 6, height: 6 + q * 6)),
                                 with: .color(coinGold.opacity(0.5 * Double(1 - q))))
                    continue
                } else if collectedAt <= -0.35 { continue }
                // Монетка вращается: меняется ширина
                let spin = CGFloat(abs(cos(t * 6 + Double(k * 3 + j))))
                context.fill(Path(ellipseIn: CGRect(x: x - 2.6 * spin - 0.4, y: y - 3, width: 5.2 * spin + 0.8, height: 6)), with: .color(coinGold))
                context.fill(Path(CGRect(x: x - 0.4, y: y - 1.5, width: 0.8, height: 3)), with: .color(Color(red: 0.8, green: 0.55, blue: 0.1)))
            }
        }

        // Герой: в воздухе ноги вместе, на земле бежит
        let running = Int(t * 10) % 2 == 0
        _ = running
        hero.draw(in: &context, x: heroX, bottom: ground - lift, pixel: 1.7, color: Color(red: 0.9, green: 0.2, blue: 0.2),
                  accent: Color(red: 1, green: 0.8, blue: 0.62), flip: false, dark: Color(red: 0.2, green: 0.35, blue: 0.9))
    }
}

/// Воспроизводимое «случайное» число 0…1 по целому зерну
private func idleRandom(_ seed: Int) -> Double {
    var x = UInt64(bitPattern: Int64(seed)) &* 0x9E3779B97F4A7C15
    x ^= x >> 31
    x = x &* 0xBF58476D1CE4E5B9
    x ^= x >> 29
    return Double(x % 10_000) / 10_000
}

/// Положительный остаток от деления (для бегущих по кругу узоров)
private func idleWrap(_ value: Double, _ period: Double) -> Double {
    let r = value.truncatingRemainder(dividingBy: period)
    return r < 0 ? r + period : r
}
