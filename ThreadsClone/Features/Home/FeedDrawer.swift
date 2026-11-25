import SwiftUI

struct LocalFeed: Identifiable, Codable, Hashable {
    var id = UUID().uuidString
    var name: String
    var detail: String
    var isPublic: Bool
    var personIDs: Set<String>

    static func decode(_ text: String) -> [LocalFeed] {
        (try? JSONDecoder().decode([LocalFeed].self, from: Data(text.utf8))) ?? []
    }
    static func encode(_ feeds: [LocalFeed]) -> String {
        (try? String(decoding: JSONEncoder().encode(feeds), as: UTF8.self)) ?? "[]"
    }
}

struct FeedDrawer: View {
    @Binding var selectedFeed: FeedDestination
    @Binding var customFeed: LocalFeed?
    let onClose: () -> Void
    @AppStorage("threads.customFeeds") private var feedData = "[]"
    @AppStorage("threads.feedOrder") private var orderData = "Для вас|Подписки|Исчезающие публикации"
    @State private var showCreate = false
    @State private var showEdit = false

    private var orderedFeeds: [FeedDestination] {
        orderData.split(separator: "|").compactMap { FeedDestination(rawValue: String($0)) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Ленты").font(.system(size: 24, weight: .bold))
                Spacer()
                Button { showCreate = true } label: { FigmaIcon("circle_plus").frame(width: 40, height: 44) }
                    .foregroundStyle(ThreadTheme.secondary)
                    .accessibilityLabel("Создать ленту")
                Button { showEdit = true } label: { FigmaIcon("pencil").frame(width: 38, height: 44) }
                    .foregroundStyle(ThreadTheme.secondary)
                    .accessibilityLabel("Редактировать ленты")
            }
            .padding(.top, 0)
            HStack(spacing: 9) {
                shortcut("heart", destination: .liked, label: "Нравится")
                shortcut("bookmark", destination: .saved, label: "Сохранённое")
            }
            VStack(spacing: 0) {
                ForEach(orderedFeeds) { feed in
                    if feed != orderedFeeds.first { ThreadDivider().padding(.leading, 16) }
                    Button { select(feed) } label: {
                        HStack(spacing: 8) {
                            Text(feed == .disappearing ? "Исчезающие публика..." : feed.rawValue)
                                .lineLimit(1)
                            Spacer(minLength: 0)
                            if feed == .disappearing { FigmaIcon("ghost", size: 22) }
                        }
                        .font(.system(size: 15, weight: .bold))
                        .padding(.horizontal, 20).frame(height: 66)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .accessibilityLabel(feed.rawValue)
                }
                ForEach(LocalFeed.decode(feedData)) { feed in
                    ThreadDivider().padding(.leading, 16)
                    Button {
                        customFeed = feed
                        selectedFeed = .following
                        onClose()
                    } label: {
                        Text(feed.name).font(.system(size: 15, weight: .bold))
                            .padding(.horizontal, 20).frame(height: 66).frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .background(ThreadTheme.surface, in: .rect(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(ThreadTheme.border, lineWidth: 1))
            Spacer()
        }
        .padding(.horizontal, 18)
        .foregroundStyle(ThreadTheme.white)
        .background(ThreadTheme.background.ignoresSafeArea())
        .buttonStyle(.plain)
        .sheet(isPresented: $showCreate) { CreateFeedScreen() }
        .sheet(isPresented: $showEdit) { EditFeedsScreen() }
        .onChange(of: feedData) {
            guard let selected = customFeed else { return }
            if let updated = LocalFeed.decode(feedData).first(where: { $0.id == selected.id }) {
                customFeed = updated
            } else {
                customFeed = nil
                selectedFeed = .forYou
            }
        }
    }

    private func shortcut(_ icon: String, destination: FeedDestination, label: String) -> some View {
        Button { select(destination) } label: {
            FigmaIcon(icon).frame(maxWidth: .infinity).frame(height: 50)
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(ThreadTheme.border, lineWidth: 1))
        }.accessibilityLabel(label)
    }
    private func select(_ feed: FeedDestination) {
        selectedFeed = feed
        customFeed = nil
        onClose()
    }
}

private struct EditFeedsScreen: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("threads.feedOrder") private var orderData = "Для вас|Подписки|Исчезающие публикации"
    @AppStorage("threads.customFeeds") private var feedData = "[]"
    @State private var order: [String] = []
    @State private var customFeeds: [LocalFeed] = []
    @State private var showCreate = false

    var body: some View {
        NavigationStack {
            List {
                Button { showCreate = true } label: {
                    HStack { Text("Создать новую ленту").fontWeight(.bold); Spacer(); FigmaIcon("circle_plus", size: 18) }
                        .padding(.vertical, 8)
                }.listRowBackground(ThreadTheme.surface)
                Section {
                    Text("Бета · Перетаскивайте ленты, чтобы изменить их порядок.")
                        .font(.system(size: 13, weight: .medium)).foregroundStyle(Color(red: 0.66, green: 0.53, blue: 0.76))
                        .padding(.vertical, 5)
                }.listRowBackground(Color(red: 0.13, green: 0.08, blue: 0.19))
                Section {
                    ForEach(order, id: \.self) { name in
                        Text(name).font(.system(size: 15, weight: .semibold)).padding(.vertical, 10)
                    }
                    .onMove { indices, destination in order.move(fromOffsets: indices, toOffset: destination) }
                }.listRowBackground(ThreadTheme.background)
                if !customFeeds.isEmpty {
                    Section("Мои ленты") {
                        ForEach(customFeeds) { feed in Text(feed.name) }
                            .onDelete { indices in
                                customFeeds.remove(atOffsets: indices)
                            }
                    }.listRowBackground(ThreadTheme.surface)
                }
            }
            .environment(\.editMode, .constant(.active))
            .scrollContentBackground(.hidden).background(ThreadTheme.background)
            .navigationTitle("Редактировать ленты").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Готово") { orderData = order.joined(separator: "|"); feedData = LocalFeed.encode(customFeeds); dismiss() } }
            }
            .onAppear { order = orderData.split(separator: "|").map(String.init); customFeeds = LocalFeed.decode(feedData) }
            .onChange(of: feedData) { customFeeds = LocalFeed.decode(feedData) }
            .sheet(isPresented: $showCreate) { CreateFeedScreen() }
        }
        .tint(ThreadTheme.white)
    }
}

private struct CreateFeedScreen: View {
    @Environment(ThreadsStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @AppStorage("threads.customFeeds") private var feedData = "[]"
    @State private var name = ""
    @State private var detail = ""
    @State private var isPublic = true
    @State private var selectedPeople: Set<String> = []
    @State private var showPeople = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Название ленты", text: $name).fontWeight(.bold)
                    TextField("Укажите краткое описание.", text: $detail)
                    Toggle(isOn: $isPublic) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Общедоступная лента")
                            Text("Когда эта настройка включена, любой человек может видеть эту ленту и делиться ею. Лента и её профили могут включаться в рекомендации подписки для других пользователей.")
                                .font(.system(size: 12)).foregroundStyle(ThreadTheme.secondary)
                        }
                    }.tint(ThreadTheme.white)
                }.listRowBackground(ThreadTheme.background)
                Section("В этой ленте") {
                    Button { showPeople = true } label: {
                        Label(selectedPeople.isEmpty ? "Добавить профили или темы" : "Выбрано профилей: \(selectedPeople.count)", systemImage: "plus.circle.fill")
                            .fontWeight(.semibold).padding(.vertical, 10)
                    }
                }.listRowBackground(ThreadTheme.background)
                Button {
                    let feed = LocalFeed(name: name.trimmingCharacters(in: .whitespacesAndNewlines), detail: detail, isPublic: isPublic, personIDs: selectedPeople)
                    feedData = LocalFeed.encode(LocalFeed.decode(feedData) + [feed])
                    dismiss()
                } label: { Text("Создайте ленту").fontWeight(.bold).frame(maxWidth: .infinity).padding(.vertical, 8) }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .listRowBackground(ThreadTheme.surface)
            }
            .scrollContentBackground(.hidden).background(ThreadTheme.surface)
            .navigationTitle("Создайте ленту").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } } }
            .sheet(isPresented: $showPeople) {
                NavigationStack {
                    List(store.people) { person in
                        Button {
                            if selectedPeople.contains(person.id) { selectedPeople.remove(person.id) }
                            else { selectedPeople.insert(person.id) }
                        } label: {
                            HStack { AvatarView(person.avatar, size: 36); Text(person.username); Spacer(); if selectedPeople.contains(person.id) { Image(systemName: "checkmark") } }
                        }
                    }
                    .navigationTitle("Добавить профили").navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Готово") { showPeople = false } } }
                }
            }
        }
        .tint(ThreadTheme.white)
    }
}
