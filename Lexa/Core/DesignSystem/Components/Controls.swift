import SwiftUI

/// Seçim kartı (onboarding: dil, hedef, sıklık). Radio davranışı gösterir.
struct ChoiceCard: View {
    let title: String
    var subtitle: String?
    var symbol: String?
    var emoji: String?
    var iconTint: Color = LexaColor.glass
    var cardTint: Color?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: LexaSpacing.m) {
                if let emoji {
                    Text(emoji).font(.system(size: 28))
                } else if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(LexaColor.ink)
                        .frame(width: 40, height: 40)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(iconTint.opacity(0.75)))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(LexaFont.ui(17, weight: .semibold))
                        .foregroundStyle(LexaColor.ink)
                    if let subtitle {
                        Text(subtitle)
                            .font(LexaFont.ui(14))
                            .foregroundStyle(LexaColor.ink2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                RadioMark(isOn: isSelected)
            }
            .multilineTextAlignment(.leading)
            .lexaCard(padding: 14, radius: LexaRadius.tile, tint: cardTint)
            .overlay {
                RoundedRectangle(cornerRadius: LexaRadius.tile, style: .continuous)
                    .strokeBorder(LexaColor.accent, lineWidth: isSelected ? 2 : 0)
            }
        }
        .buttonStyle(PressableStyle())
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

struct RadioMark: View {
    let isOn: Bool

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(isOn ? LexaColor.accent : LexaColor.line, lineWidth: 1.5)
                .background(Circle().fill(isOn ? LexaColor.accent : LexaColor.glass.opacity(0.5)))
            if isOn {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(LexaColor.onAccent)
            }
        }
        .frame(width: 24, height: 24)
        .animation(LexaMotion.fast, value: isOn)
        .accessibilityHidden(true)
    }
}

/// Basınca hafifçe küçülen sade stil.
struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(LexaMotion.fast, value: configuration.isPressed)
    }
}

/// İki seçenekli kapsül sekme: "Günlük Pratik | Alıştırmalar".
struct SegmentedTabs<Value: Hashable>: View {
    let options: [(Value, String)]
    @Binding var selection: Value
    @Namespace private var ns

    var body: some View {
        HStack(spacing: 4) {
            ForEach(options, id: \.0) { value, label in
                let on = value == selection
                Button {
                    withAnimation(LexaMotion.spring) { selection = value }
                } label: {
                    Text(label)
                        .font(LexaFont.ui(15, weight: on ? .semibold : .medium))
                        .foregroundStyle(on ? LexaColor.accent : LexaColor.ink)
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .background {
                            if on {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(LexaColor.accentSoft)
                                    .matchedGeometryEffect(id: "seg", in: ns)
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(on ? [.isSelected] : [])
            }
        }
        .padding(4)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(LexaColor.glass.opacity(0.5)))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(LexaColor.glass.opacity(0.8)))
    }
}

/// Ayar satırı: ikon · etiket · değer · ›
struct SettingRow: View {
    var symbol: String?
    let label: String
    var value: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: LexaSpacing.m) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(LexaColor.accent)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(LexaColor.glass.opacity(0.7)))
                }
                Text(label)
                    .font(LexaFont.ui(16, weight: .semibold))
                    .foregroundStyle(LexaColor.ink)
                Spacer(minLength: 8)
                if let value {
                    Text(value)
                        .font(LexaFont.ui(15))
                        .foregroundStyle(LexaColor.ink2)
                        .lineLimit(1)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(LexaColor.ink2)
            }
            .frame(minHeight: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Onboarding ilerleme çubuğu.
struct StepProgressBar: View {
    let value: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(LexaColor.ink.opacity(0.12))
                Capsule().fill(LexaColor.accent)
                    .frame(width: geo.size.width * min(max(value, 0), 1))
            }
        }
        .frame(height: 5)
        .animation(LexaMotion.base, value: value)
        .accessibilityElement()
        .accessibilityLabel("İlerleme")
        .accessibilityValue("Yüzde \(Int(value * 100))")
    }
}

/// Boş durum kartı.
struct EmptyStateCard: View {
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: LexaSpacing.s) {
            Text(title)
                .font(LexaFont.ui(18, weight: .semibold))
                .foregroundStyle(LexaColor.ink)
            Text(message)
                .font(LexaFont.ui(15))
                .foregroundStyle(LexaColor.ink2)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.lexaPrimary)
                    .padding(.top, LexaSpacing.s)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .lexaCard()
    }
}

/// Alttan çıkan bildirim (toast).
struct ToastView: View {
    let message: ToastMessage

    var body: some View {
        HStack(spacing: LexaSpacing.m) {
            Image(systemName: message.symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(LexaColor.accent)
                .frame(width: 32, height: 32)
                .background(Circle().fill(tint.opacity(0.8)))
            VStack(alignment: .leading, spacing: 1) {
                Text(message.title)
                    .font(LexaFont.ui(15, weight: .semibold))
                if let detail = message.detail {
                    Text(detail).font(LexaFont.ui(13)).foregroundStyle(LexaColor.ink2)
                }
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(LexaColor.ink)
        .lexaCard(padding: 12, radius: 18)
        .accessibilityElement(children: .combine)
    }

    private var tint: Color {
        switch message.tone {
        case .neutral: LexaColor.accentSoft
        case .mint: LexaColor.mint
        case .lilac: LexaColor.lavender
        }
    }
}
