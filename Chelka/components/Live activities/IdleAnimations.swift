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
    static let sideWidth: CGFloat = 36

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
            case .campfire: IdleCampfire.draw(in: &context, zones: zones, t: t)
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
                let rect = CGRect(x: originX + CGFloat(c) * pixel, y: originY + CGFloat(row) * pixel,
                                  width: pixel, height: pixel)
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
        for (zoneIndex, zone) in [zones.left, zones.right].enumerated() {
            let columns = Int(zone.width / step) - 1
            for column in 0..<columns {
                let seed = Double(zoneIndex * 31 + column * 7)
                let speed = 18 + (seed.truncatingRemainder(dividingBy: 5)) * 4
                let span = Double(h) + 30
                let headY = CGFloat((t * speed + seed * 13).truncatingRemainder(dividingBy: span)) - 6
                let x = zone.minX + step * (CGFloat(column) + 0.9)
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

// MARK: - Костёр

/// Пиксельные костры по бокам: языки пламени пляшут, искры улетают вверх
private enum IdleCampfire {
    static func draw(in context: inout GraphicsContext, zones: IdleZones, t: Double) {
        let h = zones.size.height
        let pixel: CGFloat = 2
        let base = h - 4
        let palette = [Color(red: 1, green: 0.95, blue: 0.6), Color(red: 1, green: 0.78, blue: 0.2),
                       Color(red: 1, green: 0.45, blue: 0.1), Color(red: 0.85, green: 0.18, blue: 0.08)]
        for (index, zone) in [zones.left, zones.right].enumerated() {
            // Поленья крест-накрест
            let logs = Color(red: 0.5, green: 0.28, blue: 0.12)
            context.fill(Path(CGRect(x: zone.midX - 9, y: base, width: 18, height: pixel)), with: .color(logs))
            context.fill(Path(CGRect(x: zone.midX - 6, y: base + pixel, width: 12, height: pixel)), with: .color(logs.opacity(0.8)))

            // Пламя: столбики разной высоты, кадр меняется 10 раз в секунду
            let frame = Int(t * 10)
            for col in -3...3 {
                let falloff = 1 - abs(Double(col)) / 4.2
                let noise = (sin(Double(frame) * 1.7 + Double(col) * 2.3 + Double(index) * 5) + 1) / 2
                let height = Int((3 + 5 * falloff * (0.6 + 0.4 * noise)).rounded())
                for row in 0..<height {
                    let level = Double(row) / Double(max(1, height - 1))
                    let colorIndex = min(3, Int(level * 3.2 + (abs(col) >= 2 ? 1 : 0)))
                    context.fill(Path(CGRect(x: zone.midX + CGFloat(col) * pixel - pixel / 2, y: base - CGFloat(row + 1) * pixel,
                                             width: pixel, height: pixel)), with: .color(palette[colorIndex]))
                }
            }
            // Искры
            for i in 0..<4 {
                let seed = Double(index * 4 + i)
                let phase = (t / 1.6 + seed * 0.29).truncatingRemainder(dividingBy: 1)
                let x = zone.midX + CGFloat(sin(seed * 3 + phase * 6)) * 6
                let y = base - 10 - CGFloat(phase) * (base - 12)
                context.fill(Path(CGRect(x: x, y: y, width: 1.2, height: 1.2)),
                             with: .color(Color(red: 1, green: 0.7, blue: 0.3).opacity(1 - phase)))
            }
            // Тёплый отсвет вокруг огня
            context.fill(Path(ellipseIn: CGRect(x: zone.midX - 16, y: base - 18, width: 32, height: 26)),
                         with: .radialGradient(Gradient(colors: [Color.orange.opacity(0.18), .clear]),
                                               center: CGPoint(x: zone.midX, y: base - 4), startRadius: 0, endRadius: 16))
        }
    }
}
