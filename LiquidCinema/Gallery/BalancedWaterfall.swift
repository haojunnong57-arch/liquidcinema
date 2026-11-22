import SwiftUI

/// Two independent `LazyVStack`s fed by a greedy bin-packer, so the columns
/// balance on estimated height instead of taking turns. This is the allowed
/// non-library waterfall: true masonry, lazy, and every card keeps its own
/// aspect ratio.
struct BalancedWaterfall<Item: Identifiable, Content: View>: View {
    let items: [Item]
    let columnCount: Int
    let spacing: CGFloat
    let relativeHeight: (Item) -> CGFloat
    private let content: (Item) -> Content

    init(
        items: [Item],
        columnCount: Int,
        spacing: CGFloat,
        relativeHeight: @escaping (Item) -> CGFloat,
        @ViewBuilder content: @escaping (Item) -> Content
    ) {
        self.items = items
        self.columnCount = columnCount
        self.spacing = spacing
        self.relativeHeight = relativeHeight
        self.content = content
    }

    var body: some View {
        HStack(alignment: .top, spacing: spacing) {
            ForEach(buckets.indices, id: \.self) { column in
                LazyVStack(spacing: spacing) {
                    ForEach(buckets[column]) { item in
                        content(item)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .top)
            }
        }
    }

    private var buckets: [[Item]] {
        let count = max(columnCount, 1)
        var buckets = [[Item]](repeating: [], count: count)
        var heights = [CGFloat](repeating: 0, count: count)

        for item in items {
            var target = 0
            if count > 1 {
                for index in 1..<count where heights[index] < heights[target] - 0.02 {
                    target = index
                }
            }
            buckets[target].append(item)
            // Height in units of column width, plus the gap, so the packer
            // compares like with like.
            heights[target] += max(1 / max(relativeHeight(item), 0.3), 0.3) + 0.03
        }
        return buckets
    }
}
