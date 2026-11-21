import SwiftUI

// MARK: - Koleksiyon

struct CollectionView: View {
    let kind: CollectionKind
    let viewModel: ExploreViewModel

    var body: some View {
        let words = viewModel.words(in: kind)
        ScrollView {
            VStack(alignment: .leading, spacing: LexaSpacing.l) {
                PageHeader(title: kind.title, subtitle: kind.subtitle)
                Text("\(words.count) kelime").font(LexaFont.ui(14, weight: .semibold)).foregroundStyle(LexaColor.ink2)
                if words.isEmpty {
                    EmptyStateCard(title: "Henüz kelime yok", message: kind.emptyMessage)
                } else {
                    VStack(spacing: LexaSpacing.s) {
                        ForEach(words) { word in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(word.term).font(LexaFont.display(22)).foregroundStyle(LexaColor.ink)
                                    Text(word.meaning).font(LexaFont.ui(15)).foregroundStyle(LexaColor.ink2)
                                }
                                Spacer()
                                CircleIconButton(
                                    symbol: kind == .saved ? "bookmark" : "minus.circle",
                                    label: kind == .saved ? "\(word.term) kelimesini Kelimelerim’den çıkar" : "\(word.term) kelimesini Öğreneceklerim’den çıkar",
                                    isOn: kind == .saved
                                ) {
                                    withAnimation(LexaMotion.base) { viewModel.remove(word, from: kind) }
                                }
                            }
                            .lexaCard(padding: 14, radius: LexaRadius.tile)
                        }
                    }
                }
            }
            .padding(.horizontal, LexaSpacing.gutter)
            .padding(.vertical, LexaSpacing.s)
        }
        .lexaScreenBackground()
    }
}

// MARK: - Yeni deste

struct NewDeckView: View {
    let viewModel: ExploreViewModel
    @State private var name = ""
    @FocusState private var focused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: LexaSpacing.xl) {
                PageHeader(title: "Yeni Deste Oluştur", subtitle: "Bir konu belirle ve kelime kartlarını bir araya getir.")
                FormField(label: "Deste adı", required: true) {
                    TextField("Örn. Fiiller", text: $name)
                        .focused($focused)
                        .submitLabel(.done)
                        .onChange(of: name) { _, new in if new.count > 40 { name = String(new.prefix(40)) } }
                }
                Button("Desteyi Oluştur", action: save)
                    .buttonStyle(.lexaPrimary)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, LexaSpacing.gutter)
            .padding(.vertical, LexaSpacing.s)
        }
        .lexaScreenBackground()
        .onAppear { focused = true }
    }

    private func save() {
        guard let id = viewModel.createDeck(named: name) else { return }
        viewModel.path.removeLast()
        viewModel.path.append(.deck(id))
    }
}

// MARK: - Deste detayı

struct DeckDetailView: View {
    let deckId: String
    let viewModel: ExploreViewModel
    @State private var confirmDelete = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: LexaSpacing.l) {
                if let deck = viewModel.deck(deckId) {
                    let cards = viewModel.cards(of: deck)
                    PageHeader(title: deck.name, subtitle: "\(cards.count) kelime kartı")
                    if cards.isEmpty {
                        Text("Henüz kelime kartın yok")
                            .font(LexaFont.ui(16)).foregroundStyle(LexaColor.ink2)
                            .frame(maxWidth: .infinity).padding(.vertical, 24)
                        NavigationLink("+ Kelime Kartı Ekle", value: ExploreRoute.deckCard(deckId)).buttonStyle(.lexaPrimary)
                    } else {
                        VStack(spacing: LexaSpacing.s) {
                            NavigationLink("Kartlarla Çalış", value: ExploreRoute.deckStudy(deckId)).buttonStyle(.lexaPrimary)
                            NavigationLink("+ Kelime Kartı Ekle", value: ExploreRoute.deckCard(deckId)).buttonStyle(.lexaQuiet)
                        }
                        VStack(spacing: LexaSpacing.s) {
                            ForEach(cards) { word in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(word.term).font(LexaFont.display(22)).foregroundStyle(LexaColor.ink)
                                    Text(word.meaning).font(LexaFont.ui(15)).foregroundStyle(LexaColor.ink2)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .lexaCard(padding: 14, radius: LexaRadius.tile)
                            }
                        }
                    }
                    Button("Desteyi Sil", role: .destructive) { confirmDelete = true }
                        .font(LexaFont.ui(15, weight: .semibold))
                        .foregroundStyle(LexaColor.danger)
                        .frame(maxWidth: .infinity)
                        .padding(.top, LexaSpacing.l)
                } else {
                    PageHeader(title: "Deste", subtitle: "Bu deste artık yok.")
                }
            }
            .padding(.horizontal, LexaSpacing.gutter)
            .padding(.vertical, LexaSpacing.s)
        }
        .lexaScreenBackground()
        .confirmationDialog("Bu deste silinsin mi?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Sil", role: .destructive) {
                viewModel.deleteDeck(deckId)
                viewModel.path.removeLast()
            }
        }
    }
}

// MARK: - Kart ekleme

struct DeckCardFormView: View {
    let deckId: String
    let viewModel: ExploreViewModel
    @State private var draft = CardDraft()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: LexaSpacing.l) {
                PageHeader(title: "Kelime Kartı Ekle", subtitle: "\(viewModel.deck(deckId)?.name ?? "") destesine ekleniyor.")
                FormField(label: "Kelime", required: true) {
                    TextField("Örn. run", text: $draft.word)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                }
                FormField(label: "Türkçe anlamı", required: true) {
                    TextField("Örn. koşmak", text: $draft.meaning)
                }
                FormField(label: "Kelime türü", required: false) {
                    Picker("Kelime türü", selection: $draft.pos) {
                        Text("Seçilmedi").tag("")
                        ForEach(CardDraft.partsOfSpeech, id: \.self) { Text($0).tag($0) }
                    }
                    .pickerStyle(.menu)
                    .tint(LexaColor.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                FormField(label: "Örnek cümle", required: false) {
                    TextField("Kelimeyi bir cümlede kullan", text: $draft.example, axis: .vertical).lineLimit(2...4)
                }
                FormField(label: "Cümlenin Türkçesi", required: false) {
                    TextField("Cümlenin Türkçe karşılığı", text: $draft.exampleTr, axis: .vertical).lineLimit(2...4)
                }
                CardPreview(draft: draft)
                Button("Kartı Kaydet") {
                    viewModel.addCard(to: deckId, draft: draft)
                    dismiss()
                }
                .buttonStyle(.lexaPrimary)
                .disabled(!draft.isReady)
            }
            .padding(.horizontal, LexaSpacing.gutter)
            .padding(.vertical, LexaSpacing.s)
        }
        .scrollDismissesKeyboard(.interactively)
        .lexaScreenBackground()
    }
}

struct FormField<Content: View>: View {
    let label: String
    let required: Bool
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label).font(LexaFont.ui(15, weight: .semibold)).foregroundStyle(LexaColor.ink)
                Spacer()
                Text(required ? "Zorunlu" : "İsteğe bağlı").font(LexaFont.ui(12)).foregroundStyle(LexaColor.ink2)
            }
            content
                .font(LexaFont.ui(16))
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .frame(minHeight: 50)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(LexaColor.glass.opacity(0.6)))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(LexaColor.glass.opacity(0.9)))
        }
    }
}

private struct CardPreview: View {
    let draft: CardDraft

    var body: some View {
        VStack(alignment: .leading, spacing: LexaSpacing.s) {
            SectionTitle("Kart ön izlemesi")
            VStack(alignment: .leading, spacing: 4) {
                if !draft.pos.isEmpty {
                    Text(draft.pos.lowercased(with: Locale(identifier: "tr"))).font(LexaFont.ui(14)).foregroundStyle(LexaColor.ink2)
                }
                Text(draft.word.isEmpty ? "Kelime" : draft.word)
                    .font(LexaFont.display(32))
                    .foregroundStyle(draft.word.isEmpty ? LexaColor.ink2.opacity(0.6) : LexaColor.ink)
                Text(draft.meaning.isEmpty ? "Türkçe anlamı" : draft.meaning)
                    .font(LexaFont.ui(17, weight: .semibold))
                    .foregroundStyle(draft.meaning.isEmpty ? LexaColor.ink2.opacity(0.6) : LexaColor.ink)
                if !draft.example.isEmpty {
                    Text("“\(draft.example)”").font(LexaFont.displayItalic(17)).foregroundStyle(LexaColor.ink).padding(.top, 6)
                }
                if !draft.exampleTr.isEmpty {
                    Text(draft.exampleTr).font(LexaFont.ui(14)).foregroundStyle(LexaColor.ink2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .lexaCard()
            .accessibilityElement(children: .combine)
        }
    }
}

// MARK: - Kartlarla çalış

struct DeckStudyView: View {
    let deckId: String
    let viewModel: ExploreViewModel
    @State private var index = 0
    @State private var showBack = false

    var body: some View {
        let cards = viewModel.deck(deckId).map(viewModel.cards(of:)) ?? []
        VStack(alignment: .leading, spacing: LexaSpacing.l) {
            PageHeader(title: viewModel.deck(deckId)?.name ?? "Kartlarla Çalış", subtitle: cards.isEmpty ? "0 kelime kartı" : "\(index + 1) / \(cards.count)")
            if cards.indices.contains(index) {
                FlipCard(word: cards[index], showBack: showBack)
                    .onTapGesture {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { showBack.toggle() }
                    }
                    .accessibilityAddTraits(.isButton)
                    .accessibilityHint("Çevirmek için dokun")
                HStack(spacing: LexaSpacing.m) {
                    Button("Önceki") { step(-1) }.buttonStyle(.lexaSecondary).disabled(index == 0)
                    Button("Sonraki") { step(1) }.buttonStyle(.lexaPrimary).disabled(index >= cards.count - 1)
                }
            }
            Spacer()
        }
        .padding(.horizontal, LexaSpacing.gutter)
        .padding(.vertical, LexaSpacing.s)
        .lexaScreenBackground()
    }

    private func step(_ delta: Int) {
        showBack = false
        withAnimation(LexaMotion.base) { index += delta }
    }
}

struct FlipCard: View {
    let word: Word
    let showBack: Bool

    var body: some View {
        ZStack {
            face {
                VStack(spacing: LexaSpacing.m) {
                    if let pos = word.pos { Text(pos).font(LexaFont.ui(15)).foregroundStyle(LexaColor.ink2) }
                    Text(word.term).font(LexaFont.display(44)).foregroundStyle(LexaColor.ink).multilineTextAlignment(.center)
                    Label("Çevirmek için dokun", systemImage: "arrow.triangle.2.circlepath")
                        .font(LexaFont.ui(13)).foregroundStyle(LexaColor.ink2)
                }
            }
            .opacity(showBack ? 0 : 1)

            face {
                VStack(spacing: LexaSpacing.m) {
                    Text(word.meaning).font(LexaFont.ui(26, weight: .semibold)).foregroundStyle(LexaColor.ink)
                    if let ex = word.example { Text(ex).font(LexaFont.displayItalic(18)).foregroundStyle(LexaColor.ink) }
                    if let tr = word.exampleTr { Text(tr).font(LexaFont.ui(15)).foregroundStyle(LexaColor.ink2) }
                }
                .multilineTextAlignment(.center)
            }
            .rotation3DEffect(.degrees(180), axis: (0, 1, 0))
            .opacity(showBack ? 1 : 0)
        }
        .rotation3DEffect(.degrees(showBack ? 180 : 0), axis: (0, 1, 0), perspective: 0.5)
    }

    private func face<C: View>(@ViewBuilder _ content: () -> C) -> some View {
        content()
            .padding(24)
            .frame(maxWidth: .infinity, minHeight: 320)
            .lexaCard(radius: 26)
    }
}
