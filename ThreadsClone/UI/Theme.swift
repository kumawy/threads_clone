import SwiftUI

enum ThreadTheme {
    static let background = Color(red: 16/255, green: 16/255, blue: 16/255)
    static let surface = Color(red: 30/255, green: 30/255, blue: 30/255)
    static let white = Color(red: 243/255, green: 245/255, blue: 247/255)
    static let secondary = Color(red: 119/255, green: 119/255, blue: 119/255)
    static let border = Color(red: 48/255, green: 50/255, blue: 51/255)
    static let divider = Color(white: 0.14)
}

struct FigmaIcon: View {
    let name: String
    let size: CGFloat

    init(_ name: String, size: CGFloat = 24) {
        self.name = name
        self.size = size
    }

    var body: some View {
        Image(name)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

struct AvatarView: View {
    let asset: String
    let size: CGFloat

    init(_ asset: String, size: CGFloat = 44) {
        self.asset = asset
        self.size = size
    }

    var body: some View {
        Image(asset)
            .resizable()
            .scaledToFill()
            .frame(width: size, height: size)
            .clipShape(.circle)
            .accessibilityHidden(true)
    }
}

struct ThreadDivider: View {
    var body: some View {
        Rectangle().fill(ThreadTheme.divider).frame(height: 0.5)
    }
}

struct ThreadEmptyState: View {
    let title: String
    let detail: String
    var icon: String = "text.bubble"

    var body: some View {
        VStack(spacing: 18) {
            if !icon.isEmpty { Image(systemName: icon).font(.system(size: 44, weight: .light)) }
            Text(title).font(.system(size: 23, weight: .bold)).multilineTextAlignment(.center)
            Text(detail).font(.system(size: 14)).multilineTextAlignment(.center).lineSpacing(4)
        }
        .foregroundStyle(ThreadTheme.secondary)
        .padding(.horizontal, 28)
        .frame(maxWidth: .infinity)
    }
}

struct ThreadPillStyle: ButtonStyle {
    var selected = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(selected ? ThreadTheme.background : ThreadTheme.white)
            .padding(.horizontal, 20).frame(minHeight: 36)
            .background(selected ? ThreadTheme.white : .clear, in: .rect(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(ThreadTheme.border, lineWidth: 1))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}
