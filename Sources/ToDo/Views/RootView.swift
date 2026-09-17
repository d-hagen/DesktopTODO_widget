import SwiftUI

struct RootView: View {
    @ObservedObject var store: Store
    @ObservedObject var settings: WidgetSettings
    @ObservedObject var registry: WidgetRegistry
    let hide: () -> Void
    let remove: () -> Void

    @State private var handledDragStart: CGPoint?

    private var fg: NSColor { settings.foregroundColor }
    private var theme: Theme { settings.theme }

    /// Dragging on anything that is not a control moves the window.
    private var moveWindow: some Gesture {
        DragGesture(minimumDistance: 3, coordinateSpace: .global)
            .onChanged { value in
                guard handledDragStart != value.startLocation,
                      let event = NSApp.currentEvent, let window = event.window else { return }
                handledDragStart = value.startLocation
                window.performDrag(with: event)
            }
    }

    var body: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                .fill(Color(nsColor: settings.backgroundColor))

            VStack(alignment: .leading, spacing: 0) {
                topBar
                ScrollView(.vertical, showsIndicators: false) {
                    content
                        .padding(.horizontal, Theme.sidePadding)
                        .padding(.top, 8)
                        .padding(.bottom, 40)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                }
            }
        }
        .contentShape(Rectangle())
        .gesture(moveWindow)
        .contextMenu { menuItems }
        .ignoresSafeArea()
    }

    private var menuItems: some View {
        WidgetMenuItems(store: store, settings: settings, registry: registry, hide: hide, remove: remove)
    }

    private var topBar: some View {
        ZStack {
            Color.clear.contentShape(Rectangle())
            HStack {
                Button(action: hide) {
                    Image(systemName: "xmark")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Color(nsColor: fg))
                        .opacity(0.35)
                        .frame(width: 30, height: 30)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Hide widget (bring it back from the menu bar icon)")

                Spacer()

                Menu {
                    menuItems
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Color(nsColor: fg))
                        .opacity(0.45)
                        .frame(width: 34, height: 30)
                        .contentShape(Rectangle())
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
            }
            .padding(.horizontal, 14)
        }
        .frame(height: 46)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: theme.sectionSpacing) {
            EditableText(
                id: Document.titleID,
                kind: .title,
                text: store.doc.title,
                placeholder: Document.defaultTitle,
                font: theme.title,
                color: fg,
                strikethrough: false,
                store: store
            )
            .padding(.bottom, 6)

            ForEach(store.doc.sections) { section in
                SectionView(store: store, section: section, theme: theme, color: fg)
            }
        }
    }
}
