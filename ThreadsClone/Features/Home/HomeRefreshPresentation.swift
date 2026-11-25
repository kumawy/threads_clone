import SwiftUI
import UIKit

struct FeedPullPreference: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

struct FeedPullObserver: ViewModifier {
    let onChange: (CGFloat) -> Void
    let onDragChange: (Bool, CGFloat?) -> Void

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.onScrollGeometryChange(for: CGFloat.self) { geometry in
                max(0, -geometry.contentOffset.y - geometry.contentInsets.top).rounded()
            } action: { _, distance in
                onChange(distance)
            }
            .onScrollPhaseChange { _, phase, context in
                let distance = max(0, -context.geometry.contentOffset.y - context.geometry.contentInsets.top)
                onDragChange(phase == .tracking || phase == .interacting, distance)
            }
        } else {
            content
                .onPreferenceChange(FeedPullPreference.self, perform: onChange)
                .simultaneousGesture(
                    DragGesture(minimumDistance: 8)
                        .onChanged { value in
                            if abs(value.translation.height) > abs(value.translation.width) {
                                onDragChange(true, nil)
                            }
                        }
                        .onEnded { _ in onDragChange(false, nil) }
                )
        }
    }
}

enum HomeRefreshMotion {
    /// Pull at which the logo is fully un-written; matches the 84 pt refresh threshold.
    static let fadeStart: CGFloat = 12
    static let fadeEnd: CGFloat = 84
    /// The logo stays dimmed while posts load, then writes itself back.
    static let loadDuration = Duration.milliseconds(1000)
    /// Symbol ≈ 0.4 s, then letters ≈ 0.75 s, as in the reference recording.
    static let rewriteDuration: Double = 1.15

    static func titleFade(for pull: CGFloat) -> CGFloat {
        min(1, max(0, (pull - fadeStart) / (fadeEnd - fadeStart)))
    }
}

struct RefreshingPostRow: View {
    let post: ThreadPost
    let isLoading: Bool
    let reduceMotion: Bool
    let onReply: (ThreadPost) -> Void

    var body: some View {
        ThreadPostRow(post: post, onReply: onReply)
            .opacity(isLoading ? 0 : 1)
            .allowsHitTesting(!isLoading)
            .accessibilityHidden(isLoading)
            .overlay {
                if isLoading {
                    RepeatingPostSkeleton(reduceMotion: reduceMotion)
                        .allowsHitTesting(false)
                }
            }
    }
}

private struct RepeatingPostSkeleton: View {
    let reduceMotion: Bool

    var body: some View {
        GeometryReader { geometry in
            TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: reduceMotion)) { timeline in
                let time = timeline.date.timeIntervalSinceReferenceDate
                VStack(spacing: 0) {
                    ForEach(SkeletonSlot.filling(geometry.size.height)) { slot in
                        // Each row pulses a little after the one above it, so the shimmer rolls down the feed.
                        let wave = (sin((time - Double(slot.id) * 0.12) * .pi * 2 / 0.9) + 1) / 2
                        PostSkeletonRow()
                            .frame(height: 118, alignment: .top)
                            .opacity(reduceMotion ? 1 : 0.25 + 0.75 * wave)
                    }
                }
            }
        }
        .clipped()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Загрузка публикаций")
    }
}

private struct SkeletonSlot: Identifiable {
    let id: Int

    static func filling(_ height: CGFloat) -> [Self] {
        (0..<max(1, Int(ceil(height / 118)))).map { Self(id: $0) }
    }
}

private struct PostSkeletonRow: View {
    private let fill = Color(white: 52.0 / 255.0)

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Circle().fill(fill).frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 4).fill(fill).frame(width: 120, height: 14)
                RoundedRectangle(cornerRadius: 4).fill(fill).frame(height: 14)
                RoundedRectangle(cornerRadius: 4).fill(fill)
                    .frame(height: 14)
                    .padding(.trailing, 66)
            }
            .padding(.top, 4)
        }
        .padding(.leading, 8).padding(.trailing, 32).padding(.top, 16)
    }
}


/// The "@ threads" logo that un-writes itself while the feed is pulled and writes itself back after loading.
///
/// `erase` runs from 0 (fully white) to 1 (fully dimmed). Letters are erased one by one from the right,
/// each along its own outline, and the symbol is erased last along its centre line. Lowering `erase`
/// replays the same path backwards, so the symbol is redrawn first and the letters follow left to right.
struct ThreadsWordmark: View, Animatable {
    var erase: CGFloat

    var animatableData: CGFloat {
        get { erase }
        set { erase = newValue }
    }

    /// Share of `erase` spent on the letters; the symbol takes the remainder, with a small overlap.
    static let lettersEnd: CGFloat = 0.64
    static let symbolStart: CGFloat = 0.6
    static let dimOpacity: Double = 0.22

    private static let layout = WordmarkLayout()
    private static let bleed: CGFloat = 6

    var body: some View {
        let layout = Self.layout
        let bleed = Self.bleed
        Canvas { context, _ in
            context.translateBy(x: bleed, y: bleed)
            let dim = GraphicsContext.Shading.color(ThreadTheme.white.opacity(Self.dimOpacity))
            let lit = GraphicsContext.Shading.color(ThreadTheme.white)
            let progress = min(1, max(0, erase))

            // The symbol is drawn from its vector outline: asset images ignore Canvas shading and would stay white.
            let symbolVisible = 1 - Self.stage(progress, from: Self.symbolStart, to: 1)
            if symbolVisible >= 1 {
                context.fill(layout.symbol, with: lit)
            } else {
                context.fill(layout.symbol, with: dim)
                if symbolVisible > 0 {
                    context.drawLayer { layer in
                        layer.clip(to: layout.symbolStroke
                            .trimmedPath(from: 0, to: symbolVisible)
                            .strokedPath(StrokeStyle(lineWidth: layout.symbolBand, lineCap: .butt, lineJoin: .round)))
                        layer.fill(layout.symbol, with: lit)
                    }
                }
            }

            let count = layout.glyphs.count
            for (index, glyph) in layout.glyphs.enumerated() {
                // The last letter is erased first.
                let window = Self.letterWindow(order: count - 1 - index, count: count)
                let visible = 1 - Self.stage(progress, from: window.lowerBound, to: window.upperBound)
                if visible >= 1 {
                    context.fill(glyph, with: lit)
                    continue
                }
                context.fill(glyph, with: dim)
                guard visible > 0 else { continue }
                context.drawLayer { layer in
                    layer.clip(to: glyph
                        .trimmedPath(from: 0, to: visible)
                        .strokedPath(StrokeStyle(lineWidth: layout.letterBand, lineCap: .butt, lineJoin: .round)))
                    layer.fill(glyph, with: lit)
                }
            }
        }
        .frame(width: layout.size.width + bleed * 2, height: layout.size.height + bleed * 2)
        .padding(-bleed)
        .accessibilityElement()
        .accessibilityLabel("Threads")
    }

    static func stage(_ value: CGFloat, from start: CGFloat, to end: CGFloat) -> CGFloat {
        guard end > start else { return value >= end ? 1 : 0 }
        return min(1, max(0, (value - start) / (end - start)))
    }

    /// Overlapping windows so the next letter starts before the previous one is gone.
    static func letterWindow(order: Int, count: Int) -> ClosedRange<CGFloat> {
        let overlap: CGFloat = 1.6
        let step = lettersEnd / (CGFloat(count - 1) + overlap)
        let start = CGFloat(order) * step
        return start...(start + step * overlap)
    }
}

/// Glyph outlines for the wordmark in heavy italic system type, next to the 25 pt symbol with 3 pt spacing.
/// The real Threads logotype is a custom face; heavy italic is the closest system match to its stroke weight.
private struct WordmarkLayout {
    let glyphs: [Path]
    let size: CGSize
    let symbol: Path
    let symbolStroke: Path
    let symbolBand: CGFloat
    let letterBand: CGFloat = 8

    init() {
        let base = UIFont.systemFont(ofSize: 26, weight: .heavy)
        // Add italic to the existing traits; replacing them would drop the weight.
        let traits = base.fontDescriptor.symbolicTraits.union(.traitItalic)
        let font = base.fontDescriptor.withSymbolicTraits(traits).map { UIFont(descriptor: $0, size: 26) } ?? base
        let height = ceil(font.lineHeight)
        let symbolSide: CGFloat = 25
        let textX = symbolSide + 3

        let line = CTLineCreateWithAttributedString(NSAttributedString(string: "threads", attributes: [.font: font]))
        let textWidth = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
        let baseline = (height - font.lineHeight) / 2 + font.ascender

        var glyphs: [Path] = []
        for run in (CTLineGetGlyphRuns(line) as? [CTRun]) ?? [] {
            let count = CTRunGetGlyphCount(run)
            var ids = [CGGlyph](repeating: 0, count: count)
            var positions = [CGPoint](repeating: .zero, count: count)
            CTRunGetGlyphs(run, CFRange(location: 0, length: count), &ids)
            CTRunGetPositions(run, CFRange(location: 0, length: count), &positions)
            let attributes = CTRunGetAttributes(run) as NSDictionary
            let runFont: CTFont = attributes[kCTFontAttributeName].map { $0 as! CTFont } ?? font
            for (glyph, position) in zip(ids, positions) {
                // Core Text draws y-up; flip onto the baseline.
                var transform = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: textX + position.x, ty: baseline - position.y)
                if let path = CTFontCreatePathForGlyph(runFont, glyph, &transform) {
                    glyphs.append(Path(path))
                }
            }
        }
        self.glyphs = glyphs
        size = CGSize(width: ceil(textX + textWidth), height: max(height, symbolSide))

        // The symbol asset is 21.4677 × 25.2562, fitted into a 25 pt square.
        let scale = symbolSide / 25.2562
        let symbolWidth = 21.4677 * scale
        let origin = CGPoint(x: (symbolSide - symbolWidth) / 2, y: (size.height - symbolSide) / 2)
        let placement = CGAffineTransform(translationX: origin.x, y: origin.y).scaledBy(x: scale, y: scale)
        symbol = ThreadsSymbolOutline.path.applying(placement)
        symbolStroke = ThreadsSymbolCentreLine.path.applying(placement)
        symbolBand = 2.16 * scale * 1.4
    }
}

/// Outline of `threads_symbol.svg` (21.4677 × 25.2562), parsed once from its path data.
private enum ThreadsSymbolOutline {
    static let data = "M16.705 11.7057C16.5975 11.6536 16.4884 11.6034 16.3778 11.5554C16.1852 7.96335 14.246 5.90692 10.9899 5.88587C10.9751 5.88578 10.9605 5.88578 10.9457 5.88578C8.99814 5.88578 7.37838 6.7272 6.38142 8.25833L8.17218 9.50169C8.91694 8.35799 10.0858 8.11417 10.9466 8.11417C10.9565 8.11417 10.9665 8.11417 10.9763 8.11427C12.0484 8.12119 12.8575 8.43669 13.3811 9.05197C13.7621 9.49991 14.017 10.1189 14.1432 10.9001C13.1926 10.7366 12.1646 10.6863 11.0657 10.7501C7.96992 10.9306 5.97972 12.758 6.11339 15.2973C6.18122 16.5854 6.8152 17.6935 7.89848 18.4174C8.81437 19.0293 9.99399 19.3286 11.22 19.2609C12.839 19.171 14.1091 18.5458 14.9952 17.4025C15.6682 16.5344 16.0938 15.4093 16.2817 13.9917C17.0533 14.463 17.6251 15.0832 17.9409 15.8288C18.4779 17.0962 18.5093 19.1789 16.8303 20.8768C15.3592 22.3643 13.591 23.0078 10.9186 23.0277C7.95426 23.0055 5.71235 22.0432 4.25473 20.1677C2.88978 18.4115 2.18437 15.8748 2.15805 12.6281C2.18437 9.38132 2.88978 6.84463 4.25473 5.08842C5.71235 3.21291 7.95422 2.25069 10.9186 2.2284C13.9044 2.25086 16.1854 3.21771 17.6988 5.10227C18.4409 6.02644 19.0004 7.18864 19.3692 8.54373L21.4677 7.97703C21.0207 6.30907 20.3172 4.87177 19.3599 3.67977C17.4197 1.26369 14.5821 0.0256703 10.9259 0H10.9113C7.26252 0.0255811 4.45669 1.26831 2.57174 3.69362C0.894389 5.85185 0.0291636 8.85488 9.09734e-05 12.6192L0 12.6281L9.09734e-05 12.637C0.0291636 16.4012 0.894389 19.4044 2.57174 21.5626C4.45669 23.9878 7.26252 25.2306 10.9113 25.2562H10.9259C14.1698 25.2334 16.4564 24.3738 18.3401 22.4689C20.8045 19.9768 20.7303 16.8531 19.9181 14.9355C19.3353 13.5603 18.2243 12.4434 16.705 11.7057ZM11.1041 17.0357C9.74726 17.113 8.33767 16.4966 8.26817 15.1763C8.21665 14.1974 8.95648 13.1051 11.1873 12.9749C11.4428 12.96 11.6935 12.9527 11.9398 12.9527C12.7501 12.9527 13.5082 13.0324 14.1974 13.1849C13.9403 16.4343 12.4325 16.9619 11.1041 17.0357Z"

    /// Supports the absolute commands this artwork uses: M, L, H, V, C and Z.
    static let path: Path = {
        var path = Path()
        let scanner = Scanner(string: data)
        scanner.charactersToBeSkipped = CharacterSet(charactersIn: " ,\n")
        var current = CGPoint.zero
        func number() -> CGFloat { CGFloat(scanner.scanDouble() ?? 0) }
        while !scanner.isAtEnd, let command = scanner.scanCharacter() {
            switch command {
            case "M": current = CGPoint(x: number(), y: number()); path.move(to: current)
            case "L": current = CGPoint(x: number(), y: number()); path.addLine(to: current)
            case "H": current.x = number(); path.addLine(to: current)
            case "V": current.y = number(); path.addLine(to: current)
            case "C":
                let c1 = CGPoint(x: number(), y: number())
                let c2 = CGPoint(x: number(), y: number())
                current = CGPoint(x: number(), y: number())
                path.addCurve(to: current, control1: c1, control2: c2)
            case "Z": path.closeSubpath()
            default: break
            }
        }
        return path
    }()
}

/// Centre line of the Threads symbol in its 21.4677 × 25.2562 artwork space, starting at the inner end of the
/// "a" arch and finishing at the outer end of the ring — the order in which the symbol is drawn.
private enum ThreadsSymbolCentreLine {
    static let path: Path = {
        var path = Path()
        path.move(to: CGPoint(x: 7.28, y: 8.88))
        let segments: [[CGFloat]] = [
            [8.15, 7.55, 9.5, 7.0, 10.95, 7.0],
            [13.4, 7.0, 15.1, 8.6, 15.26, 11.23],
            [15.27, 11.9, 15.25, 12.7, 15.24, 13.6],
            [15.0, 17.0, 13.3, 18.0, 11.16, 18.15],
            [9.0, 18.2, 7.26, 16.8, 7.19, 15.24],
            [7.1, 13.48, 8.46, 12.02, 11.13, 11.86],
            [12.1, 11.8, 13.2, 11.83, 14.17, 12.04],
            [15.2, 12.05, 15.9, 12.4, 16.5, 12.85],
            [17.64, 13.45, 18.48, 14.32, 18.93, 15.39],
            [19.6, 16.98, 19.66, 19.58, 17.59, 21.68],
            [15.91, 23.37, 13.88, 24.12, 10.92, 24.14],
            [7.6, 24.12, 5.08, 23.01, 3.41, 20.87],
            [1.89, 18.9, 1.10, 16.14, 1.079, 12.63],
            [1.10, 9.12, 1.89, 6.35, 3.41, 4.39],
            [5.08, 2.24, 7.6, 1.14, 10.92, 1.114],
            [14.24, 1.14, 16.80, 2.24, 18.53, 4.39],
            [19.38, 5.45, 20.01, 6.75, 20.418, 8.26]
        ]
        for s in segments {
            path.addCurve(to: CGPoint(x: s[4], y: s[5]),
                          control1: CGPoint(x: s[0], y: s[1]),
                          control2: CGPoint(x: s[2], y: s[3]))
        }
        return path
    }()
}
