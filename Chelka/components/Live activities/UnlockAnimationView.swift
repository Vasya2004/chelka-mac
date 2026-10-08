//
//  UnlockAnimationView.swift
//  boringNotch
//
//  Анимация замка в закрытой «чёлке»: закрытие при блокировке и открытие при разблокировке
//

import SwiftUI

struct UnlockAnimationView: View {
    let kind: LockAnimationKind
    let notchWidth: CGFloat

    /// true — замок в конечном состоянии анимации
    @State private var finished = false
    @State private var ringScale: CGFloat = 0.6
    @State private var ringOpacity: Double = 0.0

    private var isUnlocking: Bool { kind == .unlocking }
    private var accent: Color { isUnlocking ? .green : .blue }

    /// Разблокировка: закрытый замок -> открытый. Блокировка: открытый -> закрытый.
    private var symbolName: String {
        let open = isUnlocking ? finished : !finished
        return open ? "lock.open.fill" : "lock.fill"
    }

    var body: some View {
        HStack(spacing: 0) {
            // Левая часть: замок
            ZStack {
                Circle()
                    .stroke(accent.opacity(0.8), lineWidth: 2)
                    .frame(width: 22, height: 22)
                    .scaleEffect(ringScale)
                    .opacity(ringOpacity)

                Image(systemName: symbolName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(finished ? accent : Color.white)
                    .contentTransition(.symbolEffect(.replace))
                    .symbolEffect(.bounce, value: finished)
            }
            .frame(width: 56, alignment: .center)
            .offset(x: -5) // небольшой сдвиг замка влево

            // Место под физическую чёлку
            Rectangle()
                .fill(.black)
                .frame(width: notchWidth)

            // Правая часть: подпись
            Text(isUnlocking ? "Unlocked" : "Locked")
                .font(.caption.weight(.medium))
                .foregroundStyle(.white)
                .opacity(finished ? 1 : 0)
                .frame(width: 56, alignment: .center)
        }
        .onAppear {
            // Короткая пауза, чтобы было видно начальное состояние замка
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
                    finished = true
                }
                ringOpacity = 0.9
                withAnimation(.easeOut(duration: 0.6)) {
                    ringScale = 1.6
                    ringOpacity = 0.0
                }
            }
        }
    }
}
