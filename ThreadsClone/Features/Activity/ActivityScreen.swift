import SwiftUI

struct ActivityScreen: View {
    @Environment(ThreadsStore.self) private var store
    @State private var selectedFilter: ActivityFilter = .all
    @State private var selectedPersonID: String?

    private var visibleActivities: [ActivityItem] {
        store.activities.filter { activity in
            switch selectedFilter {
            case .all: true
            case .following: activity.kind == .following
            case .replies: activity.kind == .reply
            case .mentions: activity.kind == .mention
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Действия")
                .font(.system(size: 32, weight: .heavy))
                .tracking(0.5)
                .foregroundStyle(ThreadTheme.white)
                .frame(height: 40, alignment: .leading)
                .padding(.horizontal, 16)
            filterBar
                .padding(.top, 9)
            Text("Последние 30 дней")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(ThreadTheme.white)
                .frame(height: 22, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 24)
            activityList
                .padding(.top, 6)
        }
        .padding(.top, 6)
        .background(ThreadTheme.background)
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(item: $selectedPersonID) { personID in
            ConversationScreen(personID: personID)
        }
        .onAppear {
            store.markActivitiesRead()
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 7) {
                ForEach(ActivityFilter.allCases) { filter in
                    Button {
                        selectedFilter = filter
                    } label: {
                        Text(filter.title)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(ThreadTheme.white)
                            .frame(width: filter.width, height: 35)
                            .background(selectedFilter == filter ? ThreadTheme.surface : .clear, in: Capsule())
                            .overlay {
                                if selectedFilter != filter {
                                    Capsule().strokeBorder(ThreadTheme.border, lineWidth: 1)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selectedFilter == filter ? .isSelected : [])
                }
            }
            .padding(.horizontal, 14)
        }
        .frame(height: 35)
    }

    @ViewBuilder
    private var activityList: some View {
        if visibleActivities.isEmpty {
            ContentUnavailableView {
                Label(selectedFilter.emptyTitle, systemImage: selectedFilter.emptySymbol)
            } description: {
                Text("Новые уведомления появятся здесь.")
            }
            .foregroundStyle(ThreadTheme.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.bottom, 16)
        } else {
            List(visibleActivities) { activity in
                let person = store.person(id: activity.personID)
                ActivityRow(activity: activity, person: person,
                            isFollowing: store.followedIDs.contains(person.id),
                            onMessage: { selectedPersonID = person.id },
                            onFollow: { store.toggleFollow(person.id) })
                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 10, trailing: 16))
                    .listRowBackground(ThreadTheme.background)
                    .listRowSeparatorTint(ThreadTheme.divider)
                    .alignmentGuide(.listRowSeparatorLeading) { _ in 52 }
                    .alignmentGuide(.listRowSeparatorTrailing) { dimensions in dimensions.width + 16 }
            }
            .listStyle(.plain)
            .environment(\.defaultMinListRowHeight, 0)
            .scrollContentBackground(.hidden)
            .contentMargins(.top, 0, for: .scrollContent)
            .contentMargins(.bottom, 16, for: .scrollContent)
        }
    }
}

private enum ActivityFilter: String, CaseIterable, Identifiable {
    case all, following, replies, mentions
    var id: Self { self }

    var title: String {
        switch self {
        case .all: "Все"
        case .following: "Подписки"
        case .replies: "Переписки"
        case .mentions: "Упоминания"
        }
    }

    var width: CGFloat {
        switch self {
        case .all: 66
        case .following: 114
        case .replies: 122
        case .mentions: 125
        }
    }

    var emptyTitle: String {
        switch self {
        case .all: "Пока нет действий"
        case .following: "Пока нет новых подписок"
        case .replies: "Пока нет ответов"
        case .mentions: "Пока нет упоминаний"
        }
    }

    var emptySymbol: String {
        switch self {
        case .all: "heart"
        case .following: "person.badge.plus"
        case .replies: "bubble.left.and.bubble.right"
        case .mentions: "at"
        }
    }
}

private struct ActivityRow: View {
    let activity: ActivityItem
    let person: Person
    let isFollowing: Bool
    let onMessage: () -> Void
    let onFollow: () -> Void

    private var hasCalendarDate: Bool {
        activity.time.filter(\.isNumber).count >= 6
    }

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            avatar
                .overlay(alignment: .topLeading) {
                    ActivityBadge(kind: activity.kind)
                        .offset(x: 22, y: 19)
                }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(person.username)
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundStyle(ThreadTheme.white)
                        .lineLimit(1)
                        .layoutPriority(1)
                    if !hasCalendarDate {
                        Text(activity.time)
                            .font(.system(size: 14))
                            .foregroundStyle(ThreadTheme.secondary)
                            .fixedSize()
                    }
                }
                .frame(height: 20, alignment: .leading)
                if hasCalendarDate {
                    Text(activity.time)
                        .font(.system(size: 14))
                        .foregroundStyle(ThreadTheme.secondary)
                        .frame(height: 19, alignment: .leading)
                }
                Text(activity.text)
                    .font(.system(size: 14))
                    .foregroundStyle(ThreadTheme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(minHeight: 19, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            actionButton
                .padding(.top, hasCalendarDate ? 13 : 3)
        }
        .contextMenu {
            Button(isFollowing ? "Отменить подписку" : "Подписаться", action: onFollow)
            Button("Написать сообщение", action: onMessage)
        }
    }

    @ViewBuilder
    private var avatar: some View {
        if person.username == "erkebulan_090924" || person.avatar.isEmpty {
            Image("social_avatar_default36")
                .resizable()
                .frame(width: 36, height: 36)
                .accessibilityHidden(true)
        } else {
            AvatarView(person.avatar, size: 36)
        }
    }

    private var actionButton: some View {
        Button(action: isFollowing ? onMessage : onFollow) {
            Text(isFollowing ? "Сообщение" : "Подписаться")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(ThreadTheme.white)
                .frame(width: 112, height: 33)
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(ThreadTheme.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isFollowing ? "Написать \(person.username)" : "Подписаться на \(person.username)")
    }
}

private struct ActivityBadge: View {
    let kind: ActivityKind

    var body: some View {
        ZStack {
            Image("social_badge_knockout")
                .resizable()
                .frame(width: 19, height: 19)
            Image("social_badge_purple")
                .resizable()
                .frame(width: 16.15, height: 16.15)
            if kind == .following {
                Image("social_badge_person")
                    .resizable()
                    .frame(width: 10.45, height: 10.45)
            } else {
                Image(systemName: kind == .like ? "heart.fill" : (kind == .mention ? "at" : "bubble.left.fill"))
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(ThreadTheme.white)
            }
        }
        .frame(width: 19, height: 19)
        .accessibilityHidden(true)
    }
}
