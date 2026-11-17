import SwiftUI

struct ExploreView: View {
    @State private var viewModel: ExploreViewModel
    @FocusState private var searchFocused: Bool

    init(app: AppState) {
        _viewModel = State(initialValue: ExploreViewModel(app: app))
    }

    var body: some View {
        NavigationStack(path: $viewModel.path) {
            ScrollView {
                VStack(alignment: .leading, spacing: LexaSpacing.xl) {
                    ScreenTitle(title: "Keşfet", lead: "Kelimeleri keşfet, öğrendiklerini biriktir.")
                    SearchField(text: $viewModel.query, isFocused: $searchFocused, onClear: viewModel.clearSearch)

                    if viewModel.isSearching {
                        SearchResultsSection(viewModel: viewModel)
                    } else {
                        CollectionsSection(viewModel: viewModel)
                        DecksSection(viewModel: viewModel)
                    }
                }
                .padding(.horizontal, LexaSpacing.gutter)
                .padding(.top, LexaSpacing.s)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .lexaScreenBackground()
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: ExploreRoute.self) { route in
                destination(for: route)
                    .toolbar(.hidden, for: .navigationBar)
            }
        }
    }

    @ViewBuilder
    private func destination(for route: ExploreRoute) -> some View {
        switch route {
        case .collection(let kind): CollectionView(kind: kind, viewModel: viewModel)
        case .newDeck: NewDeckView(viewModel: viewModel)
        case .deck(let id): DeckDetailView(deckId: id, viewModel: viewModel)
        case .deckCard(let id): DeckCardFormView(deckId: id, viewModel: viewModel)
        case .deckStudy(let id): DeckStudyView(deckId: id, viewModel: viewModel)
        }
    }
}

// MARK: - Bileşenler

struct SearchField: View {
    @Binding var text: String
    var isFocused: FocusState<Bool>.Binding
    let onClear: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundStyle(LexaColor.ink2)
            TextField("Kelime ara", text: $text)
                .font(LexaFont.ui(16))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .focused(isFocused)
            if !text.isEmpty {
                Button(action: onClear) {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(LexaColor.ink2)
                }
                .accessibilityLabel("Aramayı temizle")
            }
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 52)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(0.55)))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color.white.opacity(0.85)))
    }
}

private struct SearchResultsSection: View {
    let viewModel: ExploreViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: LexaSpacing.m) {
            if !viewModel.localResults.isEmpty || isRemoteFound {
                SectionTitle("Arama sonuçları")
            }
            ForEach(viewModel.localResults) { word in
                SearchHitRow(word: word, isSaved: viewModel.isSaved(word), source: nil,
                             onSave: { viewModel.toggleSave(word) }, onSpeak: { viewModel.speak(word) })
            }
            switch viewModel.remote {
            case .idle:
                if viewModel.localResults.isEmpty {
                    SearchEmpty(title: "Kelime bulunamadı", message: "En az iki harf yazarak ara.")
                }
            case .loading:
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Sözlükte aranıyor…").font(LexaFont.ui(15)).foregroundStyle(LexaColor.ink2)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            case .found(let word):
                SearchHitRow(word: word, isSaved: viewModel.isSaved(word), source: "Çevrim içi sözlük",
                             onSave: { viewModel.toggleSave(word) }, onSpeak: { viewModel.speak(word) })
            case .failed(let message):
                if viewModel.localResults.isEmpty {
                    SearchEmpty(title: "Kelime bulunamadı", message: message)
                }
            }
        }
        .animation(LexaMotion.base, value: viewModel.remote)
    }

    private var isRemoteFound: Bool {
        if case .found = viewModel.remote { return true }
        return false
    }
}

struct SearchHitRow: View {
    let word: Word
    let isSaved: Bool
    let source: String?
    let onSave: () -> Void
    let onSpeak: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: LexaSpacing.m) {
            VStack(alignment: .leading, spacing: 3) {
                Button(action: onSpeak) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(word.term).font(LexaFont.display(24)).foregroundStyle(LexaColor.ink)
                        if let ipa = word.ipa {
                            Text(ipa).font(LexaFont.ui(14)).foregroundStyle(LexaColor.ink2)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(word.term), dinle")
                Text(word.meaning).font(LexaFont.ui(16, weight: .semibold)).foregroundStyle(LexaColor.ink)
                if let pos = word.pos {
                    Text(pos).font(LexaFont.ui(13)).foregroundStyle(LexaColor.ink2)
                }
                if let example = word.example {
                    Text("“\(example)”").font(LexaFont.displayItalic(16)).foregroundStyle(LexaColor.ink2).padding(.top, 4)
                }
                if let source {
                    Text(source).font(LexaFont.ui(11, weight: .semibold)).foregroundStyle(LexaColor.accent).padding(.top, 4)
                }
            }
            Spacer(minLength: 0)
            CircleIconButton(symbol: "bookmark", label: isSaved ? "\(word.term) kelimesini Kelimelerim’den çıkar" : "\(word.term) kelimesini Kelimelerim’e kaydet", isOn: isSaved, action: onSave)
        }
        .lexaCard(padding: 16, radius: LexaRadius.tile)
    }
}

private struct SearchEmpty: View {
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "magnifyingglass").font(.system(size: 22)).foregroundStyle(LexaColor.ink2)
            Text(title).font(LexaFont.ui(17, weight: .semibold)).foregroundStyle(LexaColor.ink)
            Text(message).font(LexaFont.ui(15)).foregroundStyle(LexaColor.ink2).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}

private struct CollectionsSection: View {
    let viewModel: ExploreViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: LexaSpacing.m) {
            SectionTitle("Koleksiyonlarım")
            HStack(spacing: LexaSpacing.m) {
                CollectionTile(kind: .saved, count: viewModel.words(in: .saved).count, symbol: "bookmark", tint: LexaColor.lavender)
                CollectionTile(kind: .toLearn, count: viewModel.words(in: .toLearn).count, symbol: "book", tint: LexaColor.mint)
            }
        }
    }
}

private struct CollectionTile: View {
    let kind: CollectionKind
    let count: Int
    let symbol: String
    let tint: Color

    var body: some View {
        NavigationLink(value: ExploreRoute.collection(kind)) {
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: 15))
                    .foregroundStyle(LexaColor.accent)
                    .frame(width: 34, height: 34)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.8)))
                Text(kind.title).font(LexaFont.ui(17, weight: .semibold)).foregroundStyle(LexaColor.ink)
                Text(kind.subtitle).font(LexaFont.ui(13)).foregroundStyle(LexaColor.ink2).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(count)").font(LexaFont.display(28)).foregroundStyle(LexaColor.ink)
                    Text("kelime").font(LexaFont.ui(13)).foregroundStyle(LexaColor.ink2)
                }
            }
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
            .lexaCard(padding: 16, radius: LexaRadius.tile, tint: tint)
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel("\(kind.title), \(count) kelime")
    }
}

private struct DecksSection: View {
    let viewModel: ExploreViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: LexaSpacing.m) {
            SectionTitle("Destelerim") {
                NavigationLink("+ Yeni deste", value: ExploreRoute.newDeck)
                    .font(LexaFont.ui(15, weight: .semibold))
                    .foregroundStyle(LexaColor.ink)
            }
            if viewModel.decks.isEmpty {
                VStack(alignment: .leading, spacing: LexaSpacing.s) {
                    Text("Henüz bir desten yok").font(LexaFont.ui(18, weight: .semibold)).foregroundStyle(LexaColor.ink)
                    Text("Kelimelerini konularına göre grupla ve flashcard'larla çalış.").font(LexaFont.ui(15)).foregroundStyle(LexaColor.ink2)
                    NavigationLink("İlk desteni oluştur", value: ExploreRoute.newDeck)
                        .buttonStyle(.lexaPrimary)
                        .padding(.top, LexaSpacing.s)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .lexaCard()
            } else {
                VStack(spacing: LexaSpacing.s) {
                    ForEach(viewModel.decks) { deck in
                        NavigationLink(value: ExploreRoute.deck(deck.id)) {
                            HStack(spacing: LexaSpacing.m) {
                                Image(systemName: "square.stack.3d.up")
                                    .foregroundStyle(LexaColor.accent)
                                    .frame(width: 38, height: 38)
                                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.8)))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(deck.name).font(LexaFont.ui(16, weight: .semibold)).foregroundStyle(LexaColor.ink)
                                    Text("\(deck.wordIds.count) kelime").font(LexaFont.ui(13)).foregroundStyle(LexaColor.ink2)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").foregroundStyle(LexaColor.ink2)
                            }
                            .lexaCard(padding: 12, radius: LexaRadius.tile)
                        }
                        .buttonStyle(PressableStyle())
                    }
                }
            }
        }
    }
}

#Preview {
    ExploreView(app: .preview)
}
