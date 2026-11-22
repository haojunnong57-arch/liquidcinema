import Kinetics
import LiquidPhotos
import SwiftUI
import UIKit

struct LightboxPresentation: Identifiable {
    let id = UUID()
    let items: [PhotoItem]
    let start: Int
}

/// Full-screen album stage. The photo itself is LiquidPhotos' pixel-morph
/// renderer; everything around it is chrome, and only chrome ever gets glass.
struct LightboxView: View {
    let paths: LibraryPaths
    let onClose: () -> Void
    let onDelete: (PhotoItem) -> Void
    let onSetFavourite: (PhotoItem, Bool) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var items: [PhotoItem]
    @State private var index: Int

    @State private var windowBase = 0
    @State private var windowImages: [UIImage] = []
    @State private var imageCache: [UUID: UIImage] = [:]
    @State private var isLoading = true
    @State private var loadFailed = false

    @State private var entered = false
    @State private var closing = false
    @State private var chromeVisible = true

    @State private var isDragging = false
    @State private var dragOffset: CGFloat = 0
    @State private var hintTarget: Double = 0
    @State private var hintCurrent: Double = 0
    @State private var hintSpring = KineticsSpring.snappy

    @State private var favouritePulse = 0
    @State private var settleWork: Task<Void, Never>?
    @State private var tapWork: Task<Void, Never>?
    @State private var lastTapTime: Double = 0

    private static let rubber = RubberBandConfig(
        constant: 0.55,
        dimension: 300,
        mode: .outside(bounds: 0 ... 200, freeOvershoot: 20)
    )

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy 年 M 月 d 日"
        return formatter
    }()

    init(
        presentation: LightboxPresentation,
        paths: LibraryPaths,
        onClose: @escaping () -> Void,
        onDelete: @escaping (PhotoItem) -> Void,
        onSetFavourite: @escaping (PhotoItem, Bool) -> Void
    ) {
        self.paths = paths
        self.onClose = onClose
        self.onDelete = onDelete
        self.onSetFavourite = onSetFavourite
        _items = State(initialValue: presentation.items)
        _index = State(
            initialValue: min(
                max(presentation.start, 0),
                max(presentation.items.count - 1, 0)
            )
        )
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            backdrop
            VStack(spacing: 6) {
                stage
                bottomBar
            }
        }
        .overlay(alignment: .top) { topBar }
        .overlay { FavoriteBurst(trigger: favouritePulse) }
        .opacity(entered ? 1 : 0)
        .onAppear(perform: appear)
        .task(id: windowKey) { await reloadWindow() }
    }

    private var windowKey: String {
        "\(index)-\(items.count)"
    }

    private var currentItem: PhotoItem? {
        items.indices.contains(index) ? items[index] : nil
    }

    // MARK: - Backdrop

    private var backdrop: some View {
        FilmBackdrop(intensity: 0.85) {
            ZStack {
                Color.black
                if let tint = currentItem?.tint {
                    RadialGradient(
                        colors: [
                            Color(red: tint.red, green: tint.green, blue: tint.blue).opacity(0.34),
                            Color(red: tint.red, green: tint.green, blue: tint.blue).opacity(0.04),
                            .clear
                        ],
                        center: .center,
                        startRadius: 12,
                        endRadius: 640
                    )
                    .animation(.easeInOut(duration: 0.7), value: index)
                }
                LinearGradient(
                    colors: [.clear, .black.opacity(0.75)],
                    startPoint: .center,
                    endPoint: .bottom
                )
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    // MARK: - Stage

    private var stage: some View {
        ZStack {
            if windowImages.isEmpty {
                placeholder
            } else {
                StageSurface(
                    images: windowImages,
                    base: windowBase,
                    selection: min(max(index - windowBase, 0), windowImages.count - 1),
                    style: stageStyle,
                    onSelect: { relative in
                        select(windowBase + relative)
                    }
                )
                .equatable()
            }

            // Gesture catcher: guarantees touches land here, not inside the
            // Metal view, so the swipe is never split between two responders.
            Color.clear.contentShape(Rectangle())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .offset(x: hintCurrent, y: dragOffset)
        .scaleEffect(stageScale)
        .kinetics(target: $hintTarget, current: $hintCurrent, spring: $hintSpring)
        .highPriorityGesture(dismissGesture)
        .onTapGesture(perform: handleTap)
    }

    private var stageScale: CGFloat {
        let presence: CGFloat = entered ? 1 : 0.94
        let shrink = 1 - min(abs(dragOffset) / 2400, 0.06)
        return presence * shrink
    }

    private var stageStyle: LiquidPhotosStyle {
        LiquidPhotosStyle(
            transitionDuration: reduceMotion ? 0.02 : 1.35,
            holdDuration: 1.8,
            loops: false,
            morph: 0.82,
            cornerRadius: 0
        )
    }

    @ViewBuilder
    private var placeholder: some View {
        VStack(spacing: 12) {
            if loadFailed {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 32, weight: .light))
                    .foregroundStyle(Palette.textTertiary)
                Text("这张照片无法读取")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Palette.textTertiary)
            } else {
                ProgressView()
                    .tint(.white)
            }
        }
    }

    // MARK: - Chrome

    private var topBar: some View {
        GlassGroup(spacing: 14) {
            HStack(spacing: 9) {
                circleButton("xmark", label: "关闭") { close() }
                Spacer(minLength: 0)
                counter
                Spacer(minLength: 0)
                circleButton(
                    isFavourite ? "heart.fill" : "heart",
                    label: isFavourite ? "取消收藏" : "收藏",
                    tint: isFavourite ? Palette.coral : nil
                ) {
                    toggleFavourite()
                }
                circleButton("trash", label: "删除") { deleteCurrent() }
            }
            .padding(.horizontal, Metrics.screenPadding)
        }
        .opacity(chromeVisible ? 1 : 0)
        .offset(y: chromeVisible ? 0 : -26)
        .animation(.easeInOut(duration: 0.26), value: chromeVisible)
    }

    private var counter: some View {
        HStack(spacing: 4) {
            Text("\(min(index + 1, items.count))")
                .foregroundStyle(Palette.textPrimary)
            Text("/")
                .foregroundStyle(Palette.textTertiary)
            Text("\(items.count)")
                .foregroundStyle(Palette.textSecondary)
        }
        .font(.system(size: 12, weight: .semibold))
        .monospacedDigit()
        .padding(.horizontal, 13)
        .padding(.vertical, 8)
        .glassChrome(in: Capsule())
    }

    private var bottomBar: some View {
        VStack(spacing: 8) {
            if !windowImages.isEmpty {
                StripSurface(
                    images: windowImages,
                    selection: min(max(index - windowBase, 0), windowImages.count - 1),
                    size: 34,
                    onSelect: { relative in
                        select(windowBase + relative)
                    }
                )
                .equatable()
                .frame(height: 72)
            }

            HStack(spacing: 7) {
                Text(dateText)
                Text("·")
                Text(sizeText)
            }
            .font(.system(size: 10, weight: .medium))
            .monospacedDigit()
            .foregroundStyle(Palette.textTertiary)
            .padding(.bottom, 4)
        }
        .opacity(chromeVisible ? 1 : 0)
        .offset(y: chromeVisible ? 0 : 22)
        .animation(.easeInOut(duration: 0.26), value: chromeVisible)
    }

    private var dateText: String {
        guard let currentItem else { return "" }
        return Self.dateFormatter.string(from: currentItem.displayDate)
    }

    private var sizeText: String {
        guard let currentItem else { return "" }
        return "\(currentItem.pixelWidth) × \(currentItem.pixelHeight)"
    }

    private var isFavourite: Bool {
        currentItem?.isFavorite ?? false
    }

    private func circleButton(
        _ systemName: String,
        label: String,
        tint: Color? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint ?? Palette.textPrimary)
                .frame(width: 42, height: 42)
                .contentShape(Circle())
        }
        .buttonStyle(PressScaleButtonStyle(scale: 0.9))
        .glassChrome(in: Circle(), tint: tint ?? .clear, interactive: true)
        .accessibilityLabel(label)
    }

    // MARK: - Gestures

    private var dismissGesture: some Gesture {
        DragGesture(minimumDistance: 12, coordinateSpace: .local)
            .onChanged { value in
                if !isDragging {
                    isDragging = true
                    Haptics.prepareAll()
                }

                let dx = value.translation.width
                let dy = value.translation.height

                if abs(dx) > abs(dy) * 1.15 {
                    // Horizontal: a retargetable hint, not a free offset. Reversing
                    // direction mid-gesture flips the target and the spring
                    // redirects from its current velocity instead of snapping.
                    let target: Double
                    if dx > 26 {
                        target = 18
                    } else if dx < -26 {
                        target = -18
                    } else {
                        target = 0
                    }
                    if hintTarget != target { hintTarget = target }
                    if dragOffset != 0 {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            dragOffset = 0
                        }
                    }
                } else if dy > 0 {
                    if hintTarget != 0 { hintTarget = 0 }
                    dragOffset = CGFloat(
                        RubberBand.map(Double(dy), cfg: Self.rubber)
                    )
                }
            }
            .onEnded { value in
                isDragging = false
                let dx = value.translation.width
                let dy = value.translation.height
                let projectedX = value.predictedEndTranslation.width
                let projectedY = value.predictedEndTranslation.height

                if abs(dx) > abs(dy) * 1.15 {
                    if projectedX < -90 || dx < -64 {
                        step(1)
                    } else if projectedX > 90 || dx > 64 {
                        step(-1)
                    }
                    hintTarget = 0
                    withAnimation(.spring(response: 0.36, dampingFraction: 0.82)) {
                        dragOffset = 0
                    }
                } else if projectedY > 300 || dy > 160 {
                    Haptics.peak()
                    close()
                } else {
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
                        dragOffset = 0
                    }
                }
            }
    }

    // MARK: - Actions

    private func appear() {
        guard !entered else { return }
        Haptics.prepareAll()
        withAnimation(.spring(response: 0.48, dampingFraction: 0.86)) {
            entered = true
        }
        // The peak is the moment the photo lands full-bleed, not the tap.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.34) {
            Haptics.peak()
        }
    }

    /// Single tap hides chrome, double tap favourites. Resolved by hand with a
    /// 320 ms window so the two never both fire — a pair of overlapping
    /// UITapGestureRecognizers is exactly the kind of thing that feels broken.
    private func handleTap() {
        let now = CACurrentMediaTime()
        if now - lastTapTime < 0.32 {
            lastTapTime = 0
            tapWork?.cancel()
            toggleFavourite()
        } else {
            lastTapTime = now
            tapWork?.cancel()
            tapWork = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 320_000_000)
                guard !Task.isCancelled else { return }
                toggleChrome()
            }
        }
    }

    private func toggleChrome() {
        withAnimation(.easeInOut(duration: 0.26)) {
            chromeVisible.toggle()
        }
        Haptics.whisper()
    }

    private func toggleFavourite() {
        guard items.indices.contains(index) else { return }
        items[index].isFavorite.toggle()
        onSetFavourite(items[index], items[index].isFavorite)
        favouritePulse += 1
        Haptics.tap()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            Haptics.whisper()
        }
    }

    private func deleteCurrent() {
        guard items.indices.contains(index) else { return }
        let victim = items[index]
        onDelete(victim)
        items.remove(at: index)
        imageCache[victim.id] = nil

        if items.isEmpty {
            close()
            return
        }
        index = min(index, items.count - 1)
    }

    private func close() {
        guard !closing else { return }
        closing = true
        settleWork?.cancel()
        withAnimation(.easeIn(duration: 0.22)) {
            entered = false
            dragOffset = max(dragOffset, 50)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            onClose()
        }
    }

    private func step(_ direction: Int) {
        let target = min(max(index + direction, 0), items.count - 1)
        guard target != index else {
            Haptics.whisper()
            return
        }
        select(target)
    }

    private func select(_ target: Int) {
        guard items.indices.contains(target), target != index else { return }
        index = target
        settleWork?.cancel()
        settleWork = Task { @MainActor in
            let delay = reduceMotion ? 0.06 : 1.12
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            Haptics.whisper()
        }
    }

    // MARK: - Image window

    /// Centre first so the photo appears immediately, then the neighbours
    /// extend the window one at a time. Sequential by design: one decode in
    /// flight keeps peak memory at a single image and keeps UIKit objects on
    /// one thread instead of scattering them across concurrency domains.
    @MainActor
    private func reloadWindow() async {
        guard !items.isEmpty else { return }
        let centre = min(max(index, 0), items.count - 1)
        isLoading = true
        loadFailed = false

        guard let centreImage = await loadImage(centre) else {
            guard !Task.isCancelled else { return }
            isLoading = false
            loadFailed = true
            windowImages = []
            return
        }
        guard !Task.isCancelled else { return }

        windowBase = centre
        windowImages = [centreImage]
        isLoading = false

        let upper = min(items.count - 1, centre + 4)
        var forward = centre + 1
        while forward <= upper {
            guard let image = await loadImage(forward) else { break }
            guard !Task.isCancelled else { return }
            windowImages.append(image)
            forward += 1
        }

        let lower = max(0, centre - 4)
        var backward = centre - 1
        while backward >= lower {
            guard let image = await loadImage(backward) else { break }
            guard !Task.isCancelled else { return }
            windowImages.insert(image, at: 0)
            windowBase = backward
            backward -= 1
        }

        trimCache(around: centre)
    }

    @MainActor
    private func loadImage(_ position: Int) async -> UIImage? {
        guard items.indices.contains(position) else { return nil }
        let item = items[position]
        if let cached = imageCache[item.id] { return cached }
        guard let image = await StageImageLoader.load(item, paths: paths) else { return nil }
        imageCache[item.id] = image
        return image
    }

    @MainActor
    private func trimCache(around centre: Int) {
        guard imageCache.count > 10 else { return }
        let lower = max(0, centre - 5)
        let upper = min(items.count - 1, centre + 5)
        var keep = Set<UUID>()
        if lower <= upper {
            for position in lower ... upper {
                keep.insert(items[position].id)
            }
        }
        imageCache = imageCache.filter { keep.contains($0.key) }
    }
}
