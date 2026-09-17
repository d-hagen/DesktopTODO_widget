import SwiftUI

struct ItemRow: View {
    @ObservedObject var store: Store
    let item: Item
    let theme: Theme
    let color: NSColor

    var body: some View {
        HStack(alignment: .top, spacing: round(theme.base * 0.7)) {
            if item.isTask {
                Checkbox(checked: item.done, size: theme.checkbox, color: Color(nsColor: color)) {
                    store.toggle(item.id)
                }
                .padding(.top, 2)
            }
            EditableText(
                id: item.id,
                kind: .item,
                text: item.text,
                placeholder: "New task",
                font: theme.item,
                color: color,
                strikethrough: item.done,
                store: store
            )
            .opacity(item.done ? 0.5 : 1)
        }
        .frame(minHeight: theme.checkbox + 6)
    }
}
