import SwiftUI

/// One ordered narrative — enter, count down, leave — driven by PhaseAnimator
/// instead of a pile of unrelated `.animation()` calls. The countdown bar's
/// 1 → 0 sweep *is* the five-second window in which Undo still exists.
struct UndoToast: View {
    let record: UndoRecord
    let onUndo: () -> Void

    private enum Phase: CaseIterable, Equatable {
        case enter
        case countdown
        case exit
    }

    var body: some View {
        PhaseAnimator(Phase.allCases, trigger: record.id) { phase in
            content
                .opacity(phase == .exit ? 0 : 1)
                .offset(y: phase == .enter ? 26 : 0)
                .overlay(alignment: .bottomLeading) {
                    Capsule()
                        .fill(Palette.accentGradient)
                        .frame(height: 1.5)
                        .scaleEffect(x: phase == .enter ? 1 : 0, y: 1, anchor: .leading)
                        .padding(.horizontal, 18)
                        .padding(.bottom, 7)
                }
        } animation: { phase in
            switch phase {
            case .enter: .spring(response: 0.42, dampingFraction: 0.8)
            case .countdown: .linear(duration: 5)
            case .exit: .easeIn(duration: 0.22)
            }
        }
    }

    private var content: some View {
        HStack(spacing: 11) {
            Image(systemName: "trash")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Palette.textSecondary)
            Text("已移到最近删除")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Palette.textPrimary)
            Spacer(minLength: 6)
            Button(action: onUndo) {
                Text("撤销")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.accentGradient)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 6)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .glassChrome(in: Capsule())
    }
}
