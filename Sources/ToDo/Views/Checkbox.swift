import SwiftUI

struct Checkbox: View {
    let checked: Bool
    let size: CGFloat
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: size * 0.16, style: .continuous)
                    .stroke(color, lineWidth: max(1.5, size * 0.08))
                    .frame(width: size, height: size)
                if checked {
                    Image(systemName: "checkmark")
                        .font(.system(size: size * 0.58, weight: .bold))
                        .foregroundStyle(color)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(checked ? 0.5 : 1)
    }
}
