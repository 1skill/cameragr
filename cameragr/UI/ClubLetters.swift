import SwiftUI

/// Letters (S5): a sheet of letter paper laid over the bag (GPT art,
/// design/community/club_letter_src.png). Without anyone chosen it lists one's
/// conversations; with someone, the letters between the two, oldest first, and
/// the place to write — or why one can't now. Only between two people who
/// follow each other; the first letter waits for an answer (user 11/25).
struct ClubLetterPanel: View {
    @ObservedObject private var club = ClubModel.shared
    @State private var draft = ""
    @FocusState private var writing: Bool
    @Environment(\.scenePhase) private var phase
    static let paper = UIImage(named: "club_letter") ?? UIImage()
    private let ink = KitArt.ink
    private func type(_ size: CGFloat) -> Font { .custom("American Typewriter", size: size, relativeTo: .body) }

    var body: some View {
        GeometryReader { geo in
            let ratio = Self.paper.size.height / max(Self.paper.size.width, 1)
            let h = min(geo.size.height * 0.92, geo.size.width * 0.9 * ratio)
            let w = h / max(ratio, 0.1)
            ZStack {
                Color.black.opacity(0.6).ignoresSafeArea()
                    .onTapGesture { if writing { writing = false } else { close() } }
                VStack(alignment: .leading, spacing: 10) {
                    header
                    if let who = club.letterWith { conversation(who) } else { threadList }
                }
                .foregroundStyle(ink)
                .padding(.horizontal, w * 0.08).padding(.top, h * 0.07).padding(.bottom, h * 0.05)
                .frame(width: w, height: h)
                .background(Image(uiImage: Self.paper).resizable())
                .shadow(color: .black.opacity(0.45), radius: 10, y: 6)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .onChange(of: club.letterWith?.id, initial: true) { _, id in
            draft = id.map { club.letterDraft(to: $0) } ?? ""
        }
        .onAppear { club.letterPanelActive = phase == .active }
        .onDisappear { club.letterPanelLeft() }
        .onChange(of: phase) { _, p in if p == .active { Task { await club.letterPanelBack() } } else { club.letterPanelLeft() } }
        .onChange(of: club.letterDraftCleared) { _, _ in if let id = club.letterWith?.id { draft = club.letterDraft(to: id) } }
    }

    private func close() {
        writing = false
        withAnimation(.easeIn(duration: 0.2)) { club.lettersOpen = false }
    }

    @ViewBuilder private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            if club.letterWith != nil {
                Button { writing = false; Task { await club.openLetters() } } label: {
                    Image(systemName: "chevron.left").font(.system(size: 17, weight: .semibold))
                        .frame(width: 44, height: 44).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("All letters"))
            }
            Group {
                if let who = club.letterWith { Text(verbatim: who.name) } else { Text("Letters") }
            }
            .font(type(24).weight(.semibold)).lineLimit(1)
            Spacer(minLength: 8)
            if club.letterWith != nil { moreMenu }
            Button("Close") { close() }.font(type(17)).buttonStyle(.plain)
                .frame(minHeight: 44)
        }
    }

    /// Report or block, from the conversation itself.
    private var moreMenu: some View {
        Menu {
            Menu {
                ForEach(Community.ReportReason.allCases, id: \.self) { r in
                    Button { Task { await club.reportLetters(reason: r, letter: club.letters.last(where: { !$0.mine })?.id) } } label: { reasonText(r) }
                }
            } label: { Label("Report", systemImage: "flag") }
            Button(role: .destructive) { Task { await club.blockLetterPerson() } } label: { Label("Block", systemImage: "hand.raised") }
        } label: {
            Image(systemName: "ellipsis").font(.system(size: 18, weight: .semibold))
                .frame(width: 44, height: 44).contentShape(Rectangle())
        }
        .accessibilityLabel(Text("More"))
    }

    private func reasonText(_ r: Community.ReportReason) -> Text {
        switch r {
        case .nudity: Text("Nudity or sexual")
        case .violence: Text("Violence")
        case .hate: Text("Hate or harassment")
        case .spam: Text("Spam")
        case .notKoco: Text("Not taken with Koco")
        case .other: Text("Something else")
        }
    }

    // MARK: The list

    @ViewBuilder private var threadList: some View {
        if club.letterThreadsFailed && club.letterThreads.isEmpty {
            Button { Task { await club.refreshLetterThreads() } } label: {
                Text("Couldn’t load. Tap to try again.").font(type(15)).opacity(0.7).frame(minHeight: 44)
            }.buttonStyle(.plain)
        } else if club.letterThreads.isEmpty {
            Text("No letters yet. Write from someone's page once you follow each other.")
                .font(type(16)).opacity(0.7).fixedSize(horizontal: false, vertical: true)
        }
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                ForEach(club.letterThreads) { t in
                    Button { Task { await club.openLetter(with: t.with) } } label: {
                        HStack(alignment: .top, spacing: 10) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(verbatim: t.with.name).font(type(17).weight(.semibold))
                                Text(verbatim: (t.last.mine ? "↗ " : "") + t.last.text).font(type(15)).opacity(0.75).lineLimit(1)
                            }
                            Spacer(minLength: 6)
                            if t.unread > 0 {
                                Image(uiImage: ClubThemePage.wax).resizable().frame(width: 14, height: 14).accessibilityHidden(true)
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityValue(t.unread > 0 ? Text("New") : Text(verbatim: ""))
                }
                if club.letterThreadsNext != nil {
                    Button { Task { await club.moreLetterThreads() } } label: {
                        Text("More letters").font(type(15)).underline().frame(minHeight: 44)
                    }.buttonStyle(.plain)
                }
            }
        }
        .refreshable { await club.refreshLetterThreads() }
    }

    // MARK: One conversation

    @ViewBuilder private func conversation(_ who: Community.Notice.Who) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    if club.letterNext != nil {
                        Button { Task { await club.earlierLetters() } } label: {
                            Text("Earlier letters").font(type(15)).underline().frame(minHeight: 44)
                        }.buttonStyle(.plain)
                    }
                    if club.lettersFailed && club.letters.isEmpty {
                        Button { Task { await club.reloadLetters() } } label: {
                            Text("Couldn’t load. Tap to try again.").font(type(15)).opacity(0.7).frame(minHeight: 44)
                        }.buttonStyle(.plain)
                    }
                    ForEach(club.letters) { l in
                        VStack(alignment: .leading, spacing: 4) {
                            ((l.mine ? Text("You") : Text(verbatim: who.name)).font(type(13).weight(.semibold))
                             + Text(verbatim: "  " + l.at.formatted(date: .abbreviated, time: .shortened)).font(type(12)))
                                .foregroundStyle(ink.opacity(0.55))
                            Text(verbatim: l.text).font(type(17))
                                .fixedSize(horizontal: false, vertical: true)
                                .textSelection(.enabled)
                        }
                        .padding(.leading, l.mine ? 24 : 0)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .id(l.id)
                        // Any letter of theirs can be reported, not only the last.
                        .contextMenu {
                            if !l.mine {
                                Menu {
                                    ForEach(Community.ReportReason.allCases, id: \.self) { r in
                                        Button { Task { await club.reportLetters(reason: r, letter: l.id) } } label: { reasonText(r) }
                                    }
                                } label: { Label("Report this letter", systemImage: "flag") }
                            }
                        }
                        // Read once most of it is really on screen (retro 13).
                        .onScrollVisibilityChange(threshold: 0.6) { if $0 { club.letterShown(l) } }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .onChange(of: club.letters.last?.id, initial: true) { _, id in
                if let id { DispatchQueue.main.async { proxy.scrollTo(id, anchor: .bottom) } }
            }
            .refreshable { await club.reloadLetters() }
        }
        Divider().overlay(ink.opacity(0.25))
        writeArea(who)
    }

    @ViewBuilder private func writeArea(_ who: Community.Notice.Who) -> some View {
        if club.letterState.canWrite {
            HStack(alignment: .bottom, spacing: 10) {
                TextField("", text: $draft, prompt: Text("Write to \(who.name)").foregroundStyle(ink.opacity(0.45)), axis: .vertical)
                    .lineLimit(1...4)
                    .font(type(17))
                    .focused($writing)
                    .disabled(club.letterSending)
                    .onChange(of: draft) { _, new in
                        if new.count > Community.letterLimit { draft = String(new.prefix(Community.letterLimit)) }
                        club.keepLetterDraft(draft, to: who.id)
                    }
                Button {
                    let text = draft, to = who.id
                    // Cleared only if still the same conversation (the server's yes decides).
                    Task { if await club.sendLetter(text), club.letterWith?.id == to { draft = "" } }
                } label: {
                    Text(club.letterSending ? "Sending…" : "Send").font(type(17).weight(.semibold))
                        .frame(minWidth: 44, minHeight: 44)
                }
                .buttonStyle(.plain)
                .disabled(club.letterSending || draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        } else if club.letterState.waiting {
            Text("Wait for their answer before writing again.").font(type(15)).opacity(0.7)
                .frame(minHeight: 44)
        } else if club.letterLoaded {
            Text("You can write once you follow each other.").font(type(15)).opacity(0.7)
                .frame(minHeight: 44)
        }
    }
}
