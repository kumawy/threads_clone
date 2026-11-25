import SwiftUI
import PhotosUI
import ImageIO
import UniformTypeIdentifiers

struct ComposerScreen: View {
    @Environment(ThreadsStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var replyTo: ThreadPost? = nil
    var isDisappearing = false
    @AppStorage("threads.draft") private var savedDraft = ""
    @State private var text = ""
    @State private var attachments: [String] = []
    @State private var photoSelection: [PhotosPickerItem] = []
    @State private var ghost = false
    @State private var showOptions = false
    @State private var showDrafts = false
    @State private var showLink = false
    @State private var link = ""
    @State private var showMusic = false
    @State private var music = ""
    @State private var showStickers = false
    @State private var photoError = false
    @State private var isLoadingPhotos = false
    @State private var didPublish = false
    @State private var importTask: Task<Void, Never>?
    @State private var replyPermission = "Все"
    @FocusState private var focused: Bool

    private var canPublish: Bool {
        (!text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !attachments.isEmpty) && text.count <= 500 && !isLoadingPhotos
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            ThreadDivider()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let replyTo {
                        HStack(alignment: .top, spacing: 8) {
                            AvatarView(store.person(id: replyTo.authorID).avatar)
                            VStack(alignment: .leading, spacing: 6) {
                                Text(store.person(id: replyTo.authorID).username).font(.system(size: 14, weight: .bold))
                                Text(replyTo.text).font(.system(size: 14)).lineLimit(4)
                            }
                        }.foregroundStyle(ThreadTheme.secondary)
                    }
                    HStack(alignment: .top, spacing: 8) {
                        VStack(spacing: 4) {
                            AvatarView("avatar_muratov_clean")
                            Rectangle().fill(ThreadTheme.border).frame(width: 1.5, height: 48)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 4) {
                                Text(store.currentUser.username).font(.system(size: 14, weight: .heavy))
                                Image(systemName: "chevron.right").font(.system(size: 8)).foregroundStyle(ThreadTheme.secondary)
                                Text(replyTo == nil ? "Сообщество или тема" : "Ответ")
                                    .font(.system(size: 14)).foregroundStyle(ThreadTheme.secondary)
                            }
                            TextField("Что нового?", text: $text, axis: .vertical)
                                .font(.system(size: 14))
                                .lineLimit(1...12)
                                .focused($focused)
                                .accessibilityIdentifier("postTextField")
                                .padding(.bottom, 16)
                            if !attachments.isEmpty {
                                ScrollView(.horizontal) {
                                    HStack(spacing: 8) {
                                        ForEach(attachments, id: \.self) { attachment in
                                            LocalPostImage(name: attachment).frame(width: 140, height: 180)
                                                .clipShape(.rect(cornerRadius: 12))
                                                .overlay(alignment: .topTrailing) {
                                                    Button {
                                                        attachments.removeAll { $0 == attachment }
                                                        try? FileManager.default.removeItem(atPath: attachment)
                                                    } label: {
                                                        Image(systemName: "xmark.circle.fill").font(.system(size: 22)).padding(6).shadow(radius: 3)
                                                    }.accessibilityLabel("Удалить фото")
                                                }
                                        }
                                    }
                                }.scrollIndicators(.hidden)
                            }
                            attachmentToolbar
                        }
                    }
                    Button {
                        if !text.isEmpty { text += "\n\n" }
                        focused = true
                    } label: {
                        HStack(spacing: 12) {
                            AvatarView("avatar_muratov_clean", size: 14).padding(.leading, 15)
                            Text("Дополните ветку").font(.system(size: 14))
                        }.foregroundStyle(ThreadTheme.secondary.opacity(text.isEmpty ? 0.45 : 1))
                    }
                    .disabled(text.isEmpty)
                }
                .padding(.horizontal, 8).padding(.top, 14)
            }
        }
        .background(Color(red: 24/255, green: 24/255, blue: 24/255))
        .foregroundStyle(ThreadTheme.white)
        .safeAreaInset(edge: .bottom, spacing: 0) { bottomBar }
        .buttonStyle(.plain)
        .onAppear { text = replyTo == nil ? savedDraft : ""; ghost = isDisappearing; focused = true }
        .onChange(of: text) { if replyTo == nil { savedDraft = text } }
        .onChange(of: photoSelection) {
            guard !photoSelection.isEmpty else { return }
            importTask?.cancel()
            let selected = photoSelection
            importTask = Task { await importPhotos(selected) }
        }
        .onDisappear {
            importTask?.cancel()
            if !didPublish {
                for attachment in attachments { try? FileManager.default.removeItem(atPath: attachment) }
            }
        }
        .alert("Не удалось загрузить фото", isPresented: $photoError) { Button("OK", role: .cancel) {} } message: { Text("Выберите другое изображение и попробуйте ещё раз.") }
        .alert("Добавить ссылку", isPresented: $showLink) {
            TextField("https://", text: $link).textInputAutocapitalization(.never).keyboardType(.URL)
            Button("Добавить") { if !link.isEmpty { text += (text.isEmpty ? "" : "\n") + link }; link = "" }
            Button("Отмена", role: .cancel) {}
        }
        .alert("Добавить музыку", isPresented: $showMusic) {
            TextField("Исполнитель — название", text: $music)
            Button("Добавить") { if !music.isEmpty { text += (text.isEmpty ? "" : "\n") + "♫ " + music }; music = "" }
            Button("Отмена", role: .cancel) {}
        } message: { Text("Укажите трек, которым хотите поделиться.") }
        .sheet(isPresented: $showOptions) { publicationOptions }
        .sheet(isPresented: $showDrafts) { drafts }
        .sheet(isPresented: $showStickers) { stickers }
    }

    private var header: some View {
        HStack {
            Button("Отмена") { dismiss() }.font(.system(size: 15))
                .accessibilityIdentifier("cancelCompose")
            Spacer(minLength: 8)
            Text(replyTo == nil ? "Новая ветка" : "Ответить").font(.system(size: 17, weight: .heavy))
            Spacer(minLength: 8)
            HStack(spacing: 20) {
                Button { showDrafts = true } label: { FigmaIcon("document", size: 23) }.accessibilityLabel("Черновики")
                Menu {
                    Toggle("Исчезающая публикация", isOn: $ghost)
                    Button("Параметры публикации", systemImage: "slider.horizontal.3") { showOptions = true }
                    Button("Очистить текст", systemImage: "trash", role: .destructive) { text = "" }
                } label: { FigmaIcon("more_circle", size: 23) }.accessibilityLabel("Ещё")
            }
            .padding(.horizontal, 10).frame(height: 44)
            .background(Color(white: 0.21), in: .capsule)
            .overlay(Capsule().stroke(Color(white: 0.35), lineWidth: 0.5))
        }
        .padding(.horizontal, 16).frame(height: 70)
    }

    private var attachmentToolbar: some View {
        HStack(spacing: 18) {
            PhotosPicker(selection: $photoSelection, maxSelectionCount: max(1, 4 - attachments.count), matching: .images) {
                FigmaIcon("photo", size: 21)
            }.disabled(attachments.count >= 4).accessibilityLabel("Добавить фото")
            Button { showStickers = true } label: { FigmaIcon("sticker", size: 21) }.accessibilityLabel("Добавить стикер")
            PhotosPicker(selection: $photoSelection, maxSelectionCount: 1, matching: .images) {
                FigmaIcon("gif", size: 21)
            }.disabled(attachments.count >= 4).accessibilityLabel("Выбрать GIF из Фото")
            Button { showMusic = true } label: { FigmaIcon("music", size: 21) }.accessibilityLabel("Добавить музыку")
            Menu {
                Button("Добавить ссылку", systemImage: "link") { showLink = true }
                Button("Параметры публикации", systemImage: "slider.horizontal.3") { showOptions = true }
            } label: { FigmaIcon("more_circle", size: 21) }.accessibilityLabel("Ещё вложения")
            if isLoadingPhotos { ProgressView().controlSize(.small) }
        }.foregroundStyle(ThreadTheme.secondary)
    }

    private var bottomBar: some View {
        HStack(spacing: 12) {
            Button { showOptions = true } label: {
                HStack(spacing: 8) {
                    FigmaIcon("sliders", size: 22)
                    Text("Параметры\nпубликации").font(.system(size: 12, weight: .bold))
                }.foregroundStyle(ThreadTheme.secondary)
            }
            Spacer(minLength: 0)
            if text.count > 450 { Text("\(500 - text.count)").font(.system(size: 12)).foregroundStyle(text.count > 500 ? .red : ThreadTheme.secondary) }
            Toggle("Исчезающая публикация", isOn: $ghost).labelsHidden().tint(ThreadTheme.secondary)
                .toggleStyle(GhostToggleStyle())
            Button {
                if store.publish(text: text, attachments: attachments, replyTo: replyTo?.id, isDisappearing: ghost, replyPermission: replyPermission) {
                    didPublish = true
                    if replyTo == nil { savedDraft = "" }
                    dismiss()
                }
            } label: {
                Text("Опубликовать").font(.system(size: 14, weight: .bold))
                    .foregroundStyle(ThreadTheme.background)
                    .padding(.horizontal, 12).frame(height: 38)
                    .background(canPublish ? ThreadTheme.white : Color(white: 0.35), in: .rect(cornerRadius: 10))
            }
            .disabled(!canPublish).accessibilityIdentifier("publishButton")
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(Color(red: 24/255, green: 24/255, blue: 24/255))
    }

    private var publicationOptions: some View {
        NavigationStack {
            Form {
                Section("Кто может отвечать") {
                    Picker("Ответы", selection: $replyPermission) {
                        Text("Все").tag("Все")
                        Text("Профили, на которые вы подписаны").tag("Подписки")
                        Text("Только упомянутые профили").tag("Упомянутые")
                    }
                }
                Section {
                    Toggle("Исчезающая публикация", isOn: $ghost)
                } footer: { Text("Публикация будет скрыта из ленты через 24 часа.") }
            }
            .navigationTitle("Параметры публикации").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Готово") { showOptions = false } } }
        }.presentationDetents([.medium])
    }

    private var drafts: some View {
        NavigationStack {
            List {
                if savedDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    ContentUnavailableView("Пока нет черновиков", systemImage: "doc.text", description: Text("Текст новой ветки сохраняется автоматически."))
                } else {
                    Button { text = savedDraft; showDrafts = false } label: {
                        VStack(alignment: .leading, spacing: 8) { Text("Черновик").font(.headline); Text(savedDraft).font(.body).lineLimit(5) }
                    }
                    Button("Удалить черновик", role: .destructive) { savedDraft = ""; text = "" }
                }
            }
            .navigationTitle("Черновики").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Готово") { showDrafts = false } } }
        }.presentationDetents([.medium, .large])
    }

    private var stickers: some View {
        NavigationStack {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 24) {
                ForEach(["🫶", "✨", "😂", "🤍", "🔥", "👀", "🙌", "💭", "🥹", "💯", "🧵", "☕️"], id: \.self) { emoji in
                    Button(emoji) { text += emoji; showStickers = false }.font(.system(size: 36))
                }
            }.padding(24)
                .navigationTitle("Стикеры").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Готово") { showStickers = false } } }
        }.presentationDetents([.medium])
    }

    @MainActor private func importPhotos(_ selection: [PhotosPickerItem]) async {
        isLoadingPhotos = true
        defer { if !Task.isCancelled { isLoadingPhotos = false; photoSelection = [] } }
        for item in selection.prefix(max(0, 4 - attachments.count)) {
            do {
                guard let data = try await item.loadTransferable(type: Data.self) else { throw CocoaError(.fileReadCorruptFile) }
                try Task.checkCancellation()
                guard
                      let source = CGImageSourceCreateWithData(data as CFData, nil),
                      let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                        kCGImageSourceCreateThumbnailFromImageAlways: true,
                        kCGImageSourceThumbnailMaxPixelSize: 1600,
                        kCGImageSourceCreateThumbnailWithTransform: true
                      ] as CFDictionary),
                      let encoded = UIImage(cgImage: thumbnail).jpegData(compressionQuality: 0.85) else { throw CocoaError(.fileReadCorruptFile) }
                let directory = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("Attachments", isDirectory: true)
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                let file = directory.appendingPathComponent(UUID().uuidString + ".jpg")
                try encoded.write(to: file, options: .atomic)
                attachments.append(file.path)
            } catch is CancellationError { return }
            catch { if !Task.isCancelled { photoError = true } }
        }
    }
}

private struct GhostToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button { configuration.isOn.toggle() } label: {
            Capsule().fill(Color(white: 0.35))
                .overlay(alignment: configuration.isOn ? .trailing : .leading) {
                    Capsule().fill(ThreadTheme.background)
                        .overlay { FigmaIcon("ghost", size: 22).foregroundStyle(configuration.isOn ? ThreadTheme.white : ThreadTheme.secondary) }
                        .frame(width: 50, height: 34).padding(2)
                }
                .frame(width: 88, height: 38)
        }
        .accessibilityLabel("Исчезающая публикация")
        .accessibilityValue(configuration.isOn ? "Включено" : "Выключено")
    }
}
