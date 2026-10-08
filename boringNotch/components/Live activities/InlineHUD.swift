//
//  InlineHUDs.swift
//  boringNotch
//
//  Created by Richard Kunkli on 14/09/2024.
//  Анимированная плашка громкости и яркости в закрытой «чёлке»: живая иконка, плавная шкала со свечением,
//  «перекатывающиеся» цифры процентов.
//

import SwiftUI
import Defaults

struct InlineHUD: View {
    @EnvironmentObject var vm: BoringViewModel
    @Binding var type: SneakContentType
    @Binding var value: CGFloat
    @Binding var icon: String
    @Binding var hoverAnimation: Bool
    @Binding var gestureProgress: CGFloat

    /// Ширина боковой зоны: одинаковая слева и справа, чтобы вырез «чёлки» оставался по центру
    private var slotWidth: CGFloat { 92 - (hoverAnimation ? 0 : 10) + gestureProgress / 2 }
    private var slotHeight: CGFloat { vm.closedNotchSize.height - (hoverAnimation ? 0 : 12) }

    private var gradient: [Color] {
        switch type {
        case .brightness, .backlight:
            return [Color(red: 1.0, green: 0.86, blue: 0.48), Color(red: 1.0, green: 0.97, blue: 0.85)]
        default:
            return [Color.white.opacity(0.78), Color(red: 0.62, green: 0.82, blue: 1.0)]
        }
    }

    private var isMuted: Bool { (type == .volume || type == .mic) && value.isZero }

    var body: some View {
        HStack(spacing: 0) {
            HUDIcon(type: type, value: Double(value), icon: icon)
                .padding(.leading, 12)
                .frame(width: slotWidth, height: slotHeight, alignment: .leading)

            Rectangle()
                .fill(.black)
                .frame(width: vm.closedNotchSize.width - 20)

            rightContent
                .padding(.trailing, 12)
                .frame(width: slotWidth, height: slotHeight, alignment: .trailing)
        }
        .frame(height: vm.closedNotchSize.height + (hoverAnimation ? 8 : 0), alignment: .center)
    }

    @ViewBuilder
    private var rightContent: some View {
        if type == .mic {
            Text(value.isZero ? "Muted" : "Live")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.65))
                .contentTransition(.interpolate)
        } else if isMuted {
            Text("Muted")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.55))
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
        } else {
            HStack(spacing: 7) {
                HUDBar(value: $value, colors: gradient) { v in
                    if type == .volume {
                        VolumeManager.shared.setAbsolute(Float32(v))
                    } else if type == .brightness {
                        BrightnessManager.shared.setAbsolute(value: Float32(v))
                    }
                }
                .frame(width: 42)

                if Defaults[.showClosedNotchHUDPercentage] {
                    Text("\(Int((value * 100).rounded()))")
                        .font(.system(size: 11, weight: .semibold).monospacedDigit())
                        .foregroundStyle(.white.opacity(0.88))
                        .contentTransition(.numericText(value: Double(value)))
                        .frame(width: 22, alignment: .trailing)
                }
            }
        }
    }
}

// MARK: - Иконка

/// Живая иконка: у громкости волны загораются по мере уровня, у яркости солнце «раскрывает» лучи и поворачивается
private struct HUDIcon: View {
    let type: SneakContentType
    let value: Double
    let icon: String

    @State private var pulse = 0

    var body: some View {
        Group {
            switch type {
            case .volume:
                if icon.isEmpty {
                    Image(systemName: value > 0 ? "speaker.wave.3.fill" : "speaker.slash.fill", variableValue: value)
                        .font(.system(size: 15, weight: .semibold))
                        .contentTransition(.symbolEffect(.replace))
                } else {
                    // Нестандартное устройство вывода (наушники и т. п.) — его собственная иконка
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .semibold))
                        .opacity(value.isZero ? 0.55 : 1)
                        .contentTransition(.symbolEffect(.replace))
                }
            case .brightness, .backlight:
                SunGlyph(value: value)
            case .mic:
                Image(systemName: value > 0 ? "mic.fill" : "mic.slash.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .contentTransition(.symbolEffect(.replace))
            default:
                EmptyView()
            }
        }
        .foregroundStyle(.white)
        .symbolEffect(.bounce, options: .speed(1.4), value: pulse)
        .opacity(value.isZero && type == .volume ? 0.6 : 1)
        .onChange(of: value) { _, _ in pulse += 1 }
        .frame(width: 22, height: 20)
    }
}

/// Солнце из круга и восьми лучей: растёт и поворачивается вместе с яркостью
private struct SunGlyph: View {
    let value: Double

    var body: some View {
        let v = min(max(value, 0), 1)
        ZStack {
            ForEach(0..<8, id: \.self) { i in
                Capsule()
                    .fill(.white)
                    .frame(width: 1.6, height: 2 + 3.5 * v)
                    .offset(y: -(6.2 + 1.8 * v))
                    .rotationEffect(.degrees(Double(i) * 45))
                    .opacity(0.45 + 0.55 * v)
            }
            Circle()
                .fill(.white)
                .frame(width: 5.5 + 2.5 * v, height: 5.5 + 2.5 * v)
        }
        .rotationEffect(.degrees(v * 80))
        .shadow(color: Color.yellow.opacity(0.12 + 0.55 * v), radius: 2 + 5 * v)
        .animation(.spring(response: 0.38, dampingFraction: 0.66), value: v)
        .frame(width: 22, height: 22)
    }
}

// MARK: - Шкала

/// Тонкая шкала со свечением: заливка плавно догоняет значение, при перетаскивании утолщается
private struct HUDBar: View {
    @Binding var value: CGFloat
    let colors: [Color]
    var onChange: ((CGFloat) -> Void)? = nil

    @State private var dragging = false

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.16))
                Capsule()
                    .fill(LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(0, min(geo.size.width * value, geo.size.width)))
                    .shadow(color: (colors.last ?? .white).opacity(dragging ? 0.8 : 0.5), radius: dragging ? 6 : 4)
                    .opacity(value.isZero ? 0 : 1)
            }
            .frame(maxHeight: .infinity, alignment: .center)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        dragging = true
                        let v = max(0, min(gesture.location.x / geo.size.width, 1))
                        value = v
                        onChange?(v)
                    }
                    .onEnded { _ in dragging = false }
            )
        }
        .frame(height: dragging ? 8 : 5)
        .animation(.spring(response: 0.3, dampingFraction: 0.78), value: value)
        .animation(.smooth(duration: 0.2), value: dragging)
    }
}

#Preview {
    InlineHUD(type: .constant(.brightness), value: .constant(0.4), icon: .constant(""), hoverAnimation: .constant(false), gestureProgress: .constant(0))
        .padding(.horizontal, 8)
        .background(Color.black)
        .padding()
        .environmentObject(BoringViewModel())
}
