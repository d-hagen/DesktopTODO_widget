import SwiftUI

struct SectionView: View {
    @ObservedObject var store: Store
    let section: Section
    let theme: Theme
    let color: NSColor

    var body: some View {
        VStack(alignment: .leading, spacing: theme.rowSpacing) {
            if let title = section.title {
                if section.isDone {
                    Text(title)
                        .font(Font(theme.header))
                        .foregroundStyle(Color(nsColor: color))
                        .opacity(0.6)
                        .padding(.bottom, 4)
                } else {
                    EditableText(
                        id: section.id,
                        kind: .header,
                        text: title,
                        placeholder: "Section",
                        font: theme.header,
                        color: color,
                        strikethrough: false,
                        store: store
                    )
                    .padding(.bottom, 4)
                }
            }
            ForEach(section.items) { item in
                ItemRow(store: store, item: item, theme: theme, color: color)
            }
        }
    }
}
