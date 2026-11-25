import SwiftUI

struct MessagesScreen: View {
    @Environment(ThreadsStore.self) private var store
    @State private var searchText = ""
    @State private var selectedMailbox: MessageMailbox = .inbox
    @State private var unreadOnly = false
    @AppStorage("ThreadsClone.readConversationIDs.v1") private var readConversationIDsData = Data()
    @State private var selectedPersonID: String?
    @State private var isComposing = false

    private var readConversationIDs: Set<String> {
        ConversationReadState.ids(from: readConversationIDsData)
    }

    private var conversations: [MessageConversation] {
        var rows = MessageConversation.referenceInbox
        let existingIDs = Set(rows.map { resolvePersonID($0.personID) })
        for personID in Set(store.messages.map(\.personID)).sorted() where !existingIDs.contains(personID) {
            let person = store.person(id: personID)
            rows.insert(MessageConversation(id: personID, personID: personID, title: person.username,
                                            preview: "", time: "", avatar: .person(person.avatar)), at: 0)
        }
        guard selectedMailbox == .inbox else { return [] }
        return rows.filter { row in
            let isRead = readConversationIDs.contains(resolvePersonID(row.personID)) || readConversationIDs.contains(row.id)
            let matchesUnread = !unreadOnly || (row.isUnread && !isRead)
            let matchesSearch = searchText.isEmpty || row.title.localizedCaseInsensitiveContains(searchText)
                || preview(for: row).localizedCaseInsensitiveContains(searchText)
            return matchesUnread && matchesSearch
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            searchField
                .padding(.top, 8)
                .padding(.horizontal, 16)
            mailboxFilters
                .padding(.top, 14)
            conversationList
                .padding(.top, 20)
        }
        .padding(.top, 6)
        .background(ThreadTheme.background)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(selectedPersonID == nil ? .visible : .hidden, for: .tabBar)
        .navigationDestination(item: $selectedPersonID) { personID in
            ConversationScreen(personID: personID)
                .onDisappear {
                    if selectedPersonID == personID { selectedPersonID = nil }
                }
        }
        .sheet(isPresented: $isComposing) {
            NavigationStack {
                NewMessageScreen()
            }
            .preferredColorScheme(.dark)
        }
    }

    private var header: some View {
        HStack {
            Text("Сообщения")
                .font(.system(size: 32, weight: .heavy))
                .tracking(0.5)
                .foregroundStyle(ThreadTheme.white)
            Spacer()
            Button {
                isComposing = true
            } label: {
                FigmaIcon("compose", size: 24)
                    .foregroundStyle(ThreadTheme.white)
                    .frame(width: 44, height: 40, alignment: .trailing)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Новое сообщение")
        }
        .frame(height: 40)
        .padding(.horizontal, 16)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            FigmaIcon("search", size: 16)
                .foregroundStyle(ThreadTheme.secondary)
            TextField("", text: $searchText, prompt: Text("Поиск").foregroundStyle(ThreadTheme.secondary))
                .font(.system(size: 14))
                .foregroundStyle(ThreadTheme.white)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .accessibilityLabel("Поиск сообщений")
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(ThreadTheme.secondary)
                }
                .accessibilityLabel("Очистить поиск")
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 44)
        .background(ThreadTheme.surface, in: RoundedRectangle(cornerRadius: 16))
    }

    private var mailboxFilters: some View {
        HStack(spacing: 7) {
            Menu {
                Button {
                    unreadOnly = false
                } label: {
                    Label("Все сообщения", systemImage: unreadOnly ? "envelope" : "checkmark")
                }
                Button {
                    unreadOnly = true
                } label: {
                    Label("Непрочитанные", systemImage: unreadOnly ? "checkmark" : "envelope.badge")
                }
            } label: {
                FigmaIcon("filter", size: 18)
                    .foregroundStyle(ThreadTheme.white)
                    .frame(width: 51, height: 35)
                    .background(unreadOnly ? ThreadTheme.surface : .clear, in: Capsule())
                    .overlay(Capsule().strokeBorder(ThreadTheme.border, lineWidth: 1))
            }
            .accessibilityLabel("Фильтр сообщений")
            .accessibilityValue(unreadOnly ? "Непрочитанные" : "Все сообщения")
            ForEach(MessageMailbox.allCases) { mailbox in
                Button {
                    selectedMailbox = mailbox
                } label: {
                    Text(mailbox.title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(ThreadTheme.white)
                        .frame(width: mailbox == .inbox ? 108 : 97, height: 35)
                        .background(selectedMailbox == mailbox ? ThreadTheme.surface : .clear, in: Capsule())
                        .overlay {
                            if selectedMailbox != mailbox {
                                Capsule().strokeBorder(ThreadTheme.border, lineWidth: 1)
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selectedMailbox == mailbox ? .isSelected : [])
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
    }

    @ViewBuilder
    private var conversationList: some View {
        if conversations.isEmpty {
            ContentUnavailableView {
                Label(emptyTitle, systemImage: selectedMailbox == .requests ? "tray" : "magnifyingglass")
            } description: {
                Text(emptyDescription)
            }
            .foregroundStyle(ThreadTheme.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.bottom, 16)
        } else {
            List(conversations) { conversation in
                Button {
                    markConversationRead(resolvePersonID(conversation.personID))
                    selectedPersonID = resolvePersonID(conversation.personID)
                } label: {
                    MessageConversationRow(conversation: conversation, preview: preview(for: conversation),
                                           time: previewTime(for: conversation))
                }
                .buttonStyle(.plain)
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 24, trailing: 16))
                .listRowSeparator(.hidden)
                .listRowBackground(ThreadTheme.background)
            }
            .listStyle(.plain)
            .environment(\.defaultMinListRowHeight, 0)
            .scrollContentBackground(.hidden)
            .contentMargins(.top, 0, for: .scrollContent)
            .contentMargins(.bottom, 16, for: .scrollContent)
            .scrollDismissesKeyboard(.interactively)
        }
    }

    private var emptyTitle: String {
        if !searchText.isEmpty { return "Ничего не найдено" }
        if selectedMailbox == .requests { return "Нет запросов" }
        return "Нет непрочитанных сообщений"
    }

    private var emptyDescription: String {
        if !searchText.isEmpty { return "Попробуйте другое имя или текст сообщения." }
        if selectedMailbox == .requests { return "Здесь появятся сообщения от людей, на которых вы не подписаны." }
        return "Вы прочитали все сообщения." 
    }

    private func resolvePersonID(_ key: String) -> String {
        let aliases = ["to.tln": "to_tln", "nazkaa.kampit": "nazkaa_kampit"]
        return store.people.first { $0.id == key || $0.username == key }?.id ?? aliases[key] ?? key
    }

    private func markConversationRead(_ id: String) {
        readConversationIDsData = ConversationReadState.marking(id, in: readConversationIDsData)
    }

    private func preview(for conversation: MessageConversation) -> String {
        guard let message = store.messages(for: resolvePersonID(conversation.personID)).last,
              message.isOutgoing, message.id != conversation.referenceMessageID else { return conversation.preview }
        return "Вы: \(message.text)"
    }

    private func previewTime(for conversation: MessageConversation) -> String {
        guard let message = store.messages(for: resolvePersonID(conversation.personID)).last,
              message.isOutgoing, message.id != conversation.referenceMessageID else { return conversation.time }
        return "сейчас"
    }
}

private enum MessageMailbox: String, CaseIterable, Identifiable {
    case inbox, requests
    var id: Self { self }
    var title: String { self == .inbox ? "Входящие" : "Запросы" }
}

private struct MessageConversation: Identifiable {
    let id: String
    let personID: String
    let title: String
    let preview: String
    let time: String
    let avatar: MessageAvatar
    var referenceMessageID: String? = nil
    var isUnread = false

    static let referenceInbox: [MessageConversation] = [
        MessageConversation(id: "soulbelief", personID: "soulbelief_", title: "soulbelief_",
                            preview: "🤣🤣🤣🤣🤣🤣", time: "8 ч.", avatar: .defaultAvatar,
                            referenceMessageID: "message-soulbelief", isUnread: true),
        MessageConversation(id: "group-akzhest", personID: "akzhest", title: "akzhest, shukimanova_m",
                            preview: "Вы отправили публикацию", time: "15 ч.", avatar: .group,
                            referenceMessageID: "message-akzhest"),
        MessageConversation(id: "shukimanova", personID: "shukimanova_m", title: "shukimanova_m",
                            preview: "осы сияқты жауап берген бола...", time: "2 нед.", avatar: .defaultAvatar,
                            referenceMessageID: "message-shukimanova"),
        MessageConversation(id: "to-tln", personID: "to.tln", title: "to.tln",
                            preview: "Уалейкум", time: "4 нед.", avatar: .person("avatar_to_tln"),
                            referenceMessageID: "message-to-tln"),
        MessageConversation(id: "nazkaa", personID: "nazkaa.kampit", title: "nazkaa.kampit",
                            preview: "Есть билеты?", time: "4 нед.", avatar: .person("avatar_nazkaa_kampit"),
                            referenceMessageID: "message-nazkaa"),
        MessageConversation(id: "skyinaz", personID: "skyinaz", title: "skyinaz",
                            preview: "Кернк", time: "4 нед.", avatar: .person("avatar_skyinaz"),
                            referenceMessageID: "message-skyinaz"),
        MessageConversation(id: "shukimanova-archive", personID: "shukimanova_m", title: "shukimanova_m",
                            preview: "…", time: "13 нед.", avatar: .defaultAvatar,
                            referenceMessageID: "message-shukimanova")
    ]
}

private enum MessageAvatar {
    case defaultAvatar
    case group
    case person(String)
}

private struct MessageConversationRow: View {
    let conversation: MessageConversation
    let preview: String
    let time: String

    var body: some View {
        HStack(spacing: 10) {
            avatar
            VStack(alignment: .leading, spacing: 0) {
                Text(conversation.title)
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(ThreadTheme.white)
                    .frame(height: 20, alignment: .leading)
                Text("\(Text(preview).font(.system(size: conversation.id == "soulbelief" ? 15 : 14)))\(Text(time.isEmpty ? "" : " · \(time)").font(.system(size: 14)))")
                    .foregroundStyle(ThreadTheme.secondary)
                    .lineLimit(1)
                    .frame(height: 20, alignment: .leading)
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        }
        .frame(height: 64)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var avatar: some View {
        switch conversation.avatar {
        case .defaultAvatar:
            Image("social_avatar_default64")
                .resizable()
                .frame(width: 64, height: 64)
                .accessibilityHidden(true)
        case .group:
            ZStack(alignment: .topLeading) {
                Image("social_avatar_group_back44")
                    .resizable()
                    .frame(width: 44, height: 44)
                Image("social_avatar_group_front44")
                    .resizable()
                    .frame(width: 44, height: 44)
                    .offset(x: 18, y: 18)
            }
            .frame(width: 64, height: 64, alignment: .topLeading)
            .accessibilityHidden(true)
        case .person(let asset):
            AvatarView(asset, size: 64)
        }
    }
}

struct ConversationScreen: View {
    @Environment(ThreadsStore.self) private var store
    @State private var messageText = ""
    @AppStorage("ThreadsClone.readConversationIDs.v1") private var readConversationIDsData = Data()
    @FocusState private var isMessageFocused: Bool
    let personID: String

    private var person: Person { store.person(id: personID) }
    private var conversationMessages: [ChatMessage] { store.messages(for: personID) }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    conversationIntro
                        .padding(.bottom, 20)
                    ForEach(conversationMessages) { message in
                        MessageBubble(message: message)
                            .id(message.id)
                    }
                }
                .padding(16)
            }
            .scrollDismissesKeyboard(.interactively)
            .defaultScrollAnchor(.bottom)
            .onChange(of: conversationMessages.count) {
                guard let latest = conversationMessages.last else { return }
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo(latest.id, anchor: .bottom)
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                messageComposer
            }
        }
        .background(ThreadTheme.background)
        .navigationTitle(person.username)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(ThreadTheme.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .tint(ThreadTheme.white)
        .toolbar(.hidden, for: .tabBar)
        .onAppear {
            readConversationIDsData = ConversationReadState.marking(personID, in: readConversationIDsData)
        }
    }

    private var conversationIntro: some View {
        VStack(spacing: 9) {
            if person.avatar.isEmpty || person.avatar.hasPrefix("social_avatar_default") {
                Image("social_avatar_default64")
                    .resizable()
                    .frame(width: 64, height: 64)
            } else {
                AvatarView(person.avatar, size: 64)
            }
            Text(person.name)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(ThreadTheme.white)
            Text("@\(person.username)")
                .font(.system(size: 14))
                .foregroundStyle(ThreadTheme.secondary)
            if conversationMessages.isEmpty {
                Text("Начните переписку с \(person.username)")
                    .font(.system(size: 14))
                    .foregroundStyle(ThreadTheme.secondary)
                    .padding(.top, 12)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 24)
    }

    private var messageComposer: some View {
        HStack(alignment: .bottom, spacing: 12) {
            TextField("Сообщение…", text: $messageText, axis: .vertical)
                .font(.system(size: 16))
                .foregroundStyle(ThreadTheme.white)
                .lineLimit(1...5)
                .focused($isMessageFocused)
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .background(ThreadTheme.surface, in: RoundedRectangle(cornerRadius: 24))
                .accessibilityIdentifier("messageInput")
            Button(action: send) {
                FigmaIcon("send", size: 24)
                    .foregroundStyle(canSend ? ThreadTheme.white : ThreadTheme.secondary)
                    .frame(width: 44, height: 44)
                    .background(ThreadTheme.surface, in: Circle())
            }
            .disabled(!canSend)
            .accessibilityLabel("Отправить сообщение")
            .accessibilityIdentifier("sendMessage")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(ThreadTheme.background)
    }

    private var canSend: Bool { !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    private func send() {
        guard canSend else { return }
        store.sendMessage(messageText.trimmingCharacters(in: .whitespacesAndNewlines), to: personID)
        messageText = ""
    }
}

private enum ConversationReadState {
    static func ids(from data: Data) -> Set<String> {
        Set((try? JSONDecoder().decode([String].self, from: data)) ?? [])
    }

    static func marking(_ personID: String, in data: Data) -> Data {
        var readIDs = ids(from: data)
        readIDs.insert(personID)
        return (try? JSONEncoder().encode(readIDs.sorted())) ?? data
    }
}

private struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.isOutgoing { Spacer(minLength: 48) }
            Text(message.text)
                .font(.system(size: 16))
                .foregroundStyle(ThreadTheme.white)
                .padding(.horizontal, 15)
                .padding(.vertical, 11)
                .background(message.isOutgoing ? Color(red: 0.22, green: 0.22, blue: 0.22) : ThreadTheme.surface,
                            in: RoundedRectangle(cornerRadius: 20))
                .textSelection(.enabled)
                .accessibilityLabel((message.isOutgoing ? "Вы: " : "") + message.text)
            if !message.isOutgoing { Spacer(minLength: 48) }
        }
    }
}

private struct NewMessageScreen: View {
    @Environment(ThreadsStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var recipients: [Person] {
        store.people.filter { person in
            person.id != store.currentUser.id && (searchText.isEmpty
                || person.username.localizedCaseInsensitiveContains(searchText)
                || person.name.localizedCaseInsensitiveContains(searchText))
        }
    }

    var body: some View {
        List(recipients) { person in
            NavigationLink(value: person.id) {
                HStack(spacing: 12) {
                    AvatarView(person.avatar, size: 44)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(person.username)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(ThreadTheme.white)
                        Text(person.name)
                            .font(.system(size: 14))
                            .foregroundStyle(ThreadTheme.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
            .listRowBackground(ThreadTheme.background)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(ThreadTheme.background)
        .searchable(text: $searchText, prompt: "Кому написать?")
        .navigationTitle("Новое сообщение")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: String.self) { personID in
            ConversationScreen(personID: personID)
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                }
                .accessibilityLabel("Закрыть")
            }
        }
        .tint(ThreadTheme.white)
        .toolbar(.hidden, for: .tabBar)
        .overlay {
            if recipients.isEmpty {
                ContentUnavailableView.search(text: searchText)
            }
        }
    }
}
