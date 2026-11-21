import SwiftUI

/// Sekme ekranlarının büyük başlığı: "Pratik / Her gün biraz daha ilerle."
struct ScreenTitle: View {
    let title: String
    var lead: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(LexaFont.ui(32, weight: .bold, relativeTo: .largeTitle))
                .foregroundStyle(LexaColor.ink)
                .accessibilityAddTraits(.isHeader)
            if let lead {
                Text(lead)
                    .font(LexaFont.ui(15))
                    .foregroundStyle(LexaColor.ink2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// İtilen (push) ekranlar için geri butonlu başlık.
struct PageHeader: View {
    let title: String
    var subtitle: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: LexaSpacing.m) {
            CircleIconButton(symbol: "chevron.left", label: "Geri") { dismiss() }
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(LexaFont.ui(30, weight: .bold, relativeTo: .largeTitle))
                    .foregroundStyle(LexaColor.ink)
                    .accessibilityAddTraits(.isHeader)
                if let subtitle {
                    Text(subtitle)
                        .font(LexaFont.ui(15))
                        .foregroundStyle(LexaColor.ink2)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Kart içi bölüm başlığı.
struct SectionTitle: View {
    let text: String
    var trailing: AnyView?

    init(_ text: String) {
        self.text = text
        self.trailing = nil
    }

    init<T: View>(_ text: String, @ViewBuilder trailing: () -> T) {
        self.text = text
        self.trailing = AnyView(trailing())
    }

    var body: some View {
        HStack {
            Text(text)
                .font(LexaFont.ui(19, weight: .semibold, relativeTo: .title3))
                .foregroundStyle(LexaColor.ink)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 8)
            trailing
        }
    }
}

/// Seviye etiketi (A1…C2), seviye rengiyle.
struct LevelTag: View {
    let level: Level?

    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(LexaColor.level(level?.rawValue ?? "")).frame(width: 6, height: 6)
            Text(level?.rawValue ?? "Özel")
                .font(LexaFont.ui(12, weight: .semibold))
                .foregroundStyle(LexaColor.ink)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(LexaColor.glass.opacity(0.6)))
    }
}

/// Seri rozeti: "🔥 3 günlük seri"
struct StreakBadge: View {
    let days: Int

    var body: some View {
        Label("\(days) günlük seri", systemImage: "flame")
            .font(LexaFont.ui(14, weight: .semibold))
            .foregroundStyle(LexaColor.ink)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Capsule().fill(LexaColor.glass.opacity(0.7)))
    }
}
