import PhotosUI
import SwiftUI

struct GalleryView: View {
    @Environment(PhotoLibrary.self) private var library
    @Environment(FrameMeter.self) private var meter

    @State private var presentation: LightboxPresentation?
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var showPicker = false
    @State private var showMeter = false

    var body: some View {
        @Bindable var library = library

        ZStack {
            Palette.background.ignoresSafeArea()
            AmbientGlow()

            VStack(spacing: 0) {
                GalleryHeader(
                    count: library.items.count,
                    favourites: library.favouriteCount,
                    filter: $library.filter,
                    onImport: {
                        Haptics.tap()
                        showPicker = true
                    },
                    onRevealMeter: toggleMeter
                )
                content
            }
        }
        .overlay(alignment: .topTrailing) {
            if showMeter {
                FrameHUD(meter: meter)
                    .padding(.top, 52)
                    .padding(.trailing, Metrics.screenPadding)
            }
        }
        .overlay(alignment: .bottom) { undoToast }
        .overlay(alignment: .top) { noticeBanner }
        .overlay { importOverlay }
        .overlay { lightbox }
        .photosPicker(
            isPresented: $showPicker,
            selection: $pickerItems,
            maxSelectionCount: nil,
            matching: .images
        )
        .onChange(of: pickerItems) { _, newItems in
            guard !newItems.isEmpty, !library.isImporting else { return }
            let batch = newItems
            pickerItems = []
            Task { await runImport(batch) }
        }
        .animation(.easeInOut(duration: 0.24), value: library.progress)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if library.items.isEmpty {
            EmptyLibraryView {
                Haptics.tap()
                showPicker = true
            }
        } else if library.visibleItems.isEmpty {
            favouritesPlaceholder
        } else {
            grid
        }
    }

    private var grid: some View {
        ScrollView(.vertical) {
            BalancedWaterfall(
                items: library.visibleItems,
                columnCount: 2,
                spacing: Metrics.gutter,
                relativeHeight: { item in
                    1 / max(item.aspectRatio, 0.3)
                }
            ) { item in
                PhotoCard(
                    item: item,
                    paths: library.paths,
                    onOpen: { open(item) },
                    onToggleFavourite: {
                        library.toggleFavourite(item)
                        Haptics.whisper()
                    },
                    onDelete: { library.delete(item) }
                )
                .scrollTransition(.interactive, axis: .vertical) { view, phase in
                    view
                        .offset(y: phase.value * 6)
                        .opacity(1 - abs(phase.value) * 0.04)
                }
            }
            .padding(.horizontal, Metrics.screenPadding)
            .padding(.top, 4)
            .padding(.bottom, 130)
        }
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(.basedOnSize)
    }

    private var favouritesPlaceholder: some View {
        VStack(spacing: 12) {
            Image(systemName: "heart")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(Palette.textTertiary)
            Text("还没有收藏")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Palette.textSecondary)
            Button {
                withAnimation(.spring(response: 0.34, dampingFraction: 0.84)) {
                    library.filter = .all
                }
            } label: {
                Text("看全部")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Palette.textPrimary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .contentShape(Capsule())
            }
            .buttonStyle(PressScaleButtonStyle(scale: 0.95))
            .glassChrome(in: Capsule())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Overlays

    @ViewBuilder
    private var undoToast: some View {
        if let record = library.undoRecord {
            UndoToast(record: record) {
                library.undoDelete()
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 14)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    @ViewBuilder
    private var noticeBanner: some View {
        if let notice = library.notice {
            Text(notice)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Palette.textPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .glassChrome(in: Capsule(), tint: Palette.coral)
                .padding(.top, 96)
                .transition(.move(edge: .top).combined(with: .opacity))
                .onTapGesture { library.clearNotice() }
                .task(id: notice) {
                    try? await Task.sleep(nanoseconds: 4_000_000_000)
                    guard !Task.isCancelled else { return }
                    library.clearNotice()
                }
        }
    }

    @ViewBuilder
    private var importOverlay: some View {
        if let progress = library.progress {
            ImportOverlay(progress: progress)
        }
    }

    @ViewBuilder
    private var lightbox: some View {
        if let active = presentation {
            LightboxView(
                presentation: active,
                paths: library.paths,
                onClose: {
                    presentation = nil
                },
                onDelete: { item in
                    library.delete(item)
                },
                onSetFavourite: { item, value in
                    library.setFavourite(item.id, to: value)
                }
            )
        }
    }

    // MARK: - Actions

    private func open(_ item: PhotoItem) {
        let visible = library.visibleItems
        guard let position = visible.firstIndex(where: { $0.id == item.id }) else { return }
        presentation = LightboxPresentation(items: visible, start: position)
    }

    private func toggleMeter() {
        showMeter.toggle()
        if showMeter {
            meter.start()
        } else {
            meter.stop()
        }
        Haptics.whisper()
    }

    @MainActor
    private func runImport(_ batch: [PhotosPickerItem]) async {
        library.beginImport(total: batch.count)
        for item in batch {
            if let data = try? await item.loadTransferable(type: Data.self) {
                await library.importOne(data)
            } else {
                library.markImportFailure()
            }
        }
        library.finishImport()
    }
}
