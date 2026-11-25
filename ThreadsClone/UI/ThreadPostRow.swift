import SwiftUI
import UIKit

struct ThreadPostRow: View {
    @Environment(ThreadsStore.self) private var store
    let post: ThreadPost
    var onReply: ((ThreadPost) -> Void)? = nil
    @State private var showReply = false

    private var author: Person { store.person(id: post.authorID) }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            avatar
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(author.username).font(.system(size: 14, weight: .heavy))
                    if author.isVerified {
                        Image(systemName: "checkmark.seal.fill").foregroundStyle(.blue).font(.system(size: 12))
                    }
                    Text(post.timestamp).font(.system(size: 14)).foregroundStyle(ThreadTheme.secondary)
                    Spacer(minLength: 4)
                    Menu {
                        Button(post.isSaved ? "Убрать из сохранённого" : "Сохранить", systemImage: post.isSaved ? "bookmark.slash" : "bookmark") { store.toggleSave(post.id) }
                        Button(post.isReposted ? "Отменить репост" : "Репост", systemImage: "arrow.2.squarepath") { store.toggleRepost(post.id) }
                        ShareLink(item: "\(author.username)\n\n\(post.text)") { Label("Поделиться", systemImage: "square.and.arrow.up") }
                    } label: {
                        FigmaIcon("threads_symbol", size: 19).frame(width: 28, height: 20)
                    }
                    .accessibilityLabel("Действия с публикацией \(author.username)")
                }
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(post.text.components(separatedBy: "\n\n").enumerated()), id: \.offset) { _, paragraph in
                        Text(paragraph)
                            .font(.system(size: 14, weight: .medium))
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                            .textSelection(.enabled)
                    }
                }
                if !post.images.isEmpty {
                    ScrollView(.horizontal) {
                        HStack(spacing: 10) {
                            ForEach(post.images, id: \.self) { image in
                                LocalPostImage(name: image)
                                    .frame(width: 180, height: 240)
                                    .clipShape(.rect(cornerRadius: 14))
                            }
                        }
                    }
                    .scrollIndicators(.hidden)
                    .accessibilityIdentifier("postMedia_\(post.id)")
                    .background {
                        GeometryReader { geometry in
                            Color.clear.preference(key: FeedMediaGestureExclusion.self,
                                                   value: [geometry.frame(in: .global)])
                        }
                    }
                    .padding(.top, 5)
                }
                HStack(spacing: 25) {
                    Button { store.toggleLike(post.id) } label: {
                        HStack(spacing: 4) {
                            if post.isLiked { Image(systemName: "heart.fill").font(.system(size: 18)).foregroundStyle(.red) }
                            else { FigmaIcon("heart", size: 18) }
                            if post.likes > 0 { Text(post.likes.formatted()).font(.system(size: 12)) }
                        }
                    }
                    .accessibilityLabel(post.isLiked ? "Убрать отметку нравится" : "Нравится")
                    .accessibilityIdentifier("like_\(post.id)")
                    .sensoryFeedback(.selection, trigger: post.isLiked)
                    Button {
                        if let onReply { onReply(post) } else { showReply = true }
                    } label: {
                        HStack(spacing: 4) {
                            FigmaIcon("reply", size: 18)
                            if post.replies > 0 { Text(post.replies.formatted()).font(.system(size: 12)) }
                        }
                    }
                    .accessibilityLabel("Ответить")
                    Button { store.toggleRepost(post.id) } label: {
                        FigmaIcon("repost", size: 18)
                            .foregroundStyle(post.isReposted ? .green : ThreadTheme.white)
                    }
                    .accessibilityLabel(post.isReposted ? "Отменить репост" : "Репост")
                    ShareLink(item: "\(author.username)\n\n\(post.text)") {
                        FigmaIcon("send", size: 18)
                    }
                    .accessibilityLabel("Поделиться публикацией")
                    Spacer(minLength: 0)
                }
                .foregroundStyle(ThreadTheme.white.opacity(0.82))
                .frame(minHeight: 32)
                .padding(.top, 2)
            }
        }
        .padding(.leading, 8).padding(.trailing, 12)
        .padding(.vertical, 14)
        .buttonStyle(.plain)
        .foregroundStyle(ThreadTheme.white)
        .sheet(isPresented: $showReply) { ComposerScreen(replyTo: post) }
    }

    private var avatar: some View {
        AvatarView(author.id == store.currentUser.id ? "avatar_muratov_clean" : author.avatar)
            .overlay(alignment: .bottomTrailing) {
                if author.id != store.currentUser.id && !store.followedIDs.contains(author.id) {
                    Button { store.toggleFollow(author.id) } label: {
                        ZStack {
                            Image("follow_knockout").resizable().frame(width: 22, height: 22)
                            Image("follow_white").resizable().frame(width: 18, height: 18)
                            Image("follow_plus").resizable().frame(width: 12, height: 12)
                        }
                        .frame(width: 22, height: 22)
                    }
                    .offset(x: 5, y: 5)
                    .accessibilityLabel("Подписаться на \(author.username)")
                }
            }
    }
}

struct LocalPostImage: View {
    let name: String
    var body: some View {
        Group {
            if name.hasPrefix("/") {
                if let image = UIImage(contentsOfFile: name) {
                    Image(uiImage: image).resizable().scaledToFill()
                } else {
                    Image(systemName: "photo").foregroundStyle(ThreadTheme.secondary)
                }
            } else {
                Image(name).resizable().scaledToFill()
            }
        }
        .clipped()
    }
}
