# ToDo — desktop to-do widget for macOS

A purple sticky-note style checklist that sits on the desktop, behind every other
app window, on every Space, at whatever spot you drag it to. The list is a plain
markdown file you can also edit anywhere else.

## Build and install

Needs only the Xcode Command Line Tools (Swift 5.9+), macOS 14 or later.

```
./build.sh            # builds build/ToDo.app
./build.sh --install  # builds, copies to /Applications, launches
./build.sh --run      # builds and launches from build/
swift build && .build/debug/ToDo --selftest   # model checks
```

## Using it

- **Edit**: click any line (title, header, task) and type.
- **New task**: press Enter at the end of a line, click the empty area below the
  list, use ••• → New Task, or ⌘N while the widget is focused.
- **New header**: type `## Name` on a task line and press Enter, or ••• → New Section.
- **Delete**: clear a line and press Backspace. Deleting a header merges its tasks
  into the section above.
- **Navigate**: Up / Down move between lines, Esc stops editing.
- **Inline styling**: `*bold*` renders bold and `_kursiv_` renders italic, live
  while you type. The markers are hidden once you leave the line and reappear,
  dimmed, when you click into it again. They stay in the file.
- **Check off**: click the box. The task is crossed out and moved to a `Done`
  section at the bottom. It is deleted automatically 24 hours later, or sooner
  with ••• → Clear Completed. Unchecking moves it back to its original section.
  Done lines stay editable: clear one and press Backspace to delete just that line.
- **Text size**: ••• → Text Size, or ⌘= / ⌘- / ⌘0 while the widget is focused.
  Each widget has its own size.
- **More widgets**: ••• → New Widget (or ⌘⇧N, or the menu bar icon). Each widget
  has its own list file, color, text size and position. ••• → Remove This Widget…
  removes one; its file is kept.
- **Move / resize**: drag the top strip or any empty space; drag the edges to resize.
  Position and size are remembered.
- **Hide / show**: the × hides the widget; the checklist icon in the menu bar
  lists every widget to show or hide it again. Hidden widgets stay hidden across
  relaunches.
- **Color**: ••• → Color… (text switches between black and white automatically).
- **Launch at login**: ••• → Launch at Login. Works when the app is in /Applications.
- **Right-click** anywhere for the same menu as •••.

## The file

Default location: `~/Library/Application Support/ToDo/todo.md`; additional
widgets get `todo-2.md`, `todo-3.md`, and so on.
Use ••• → Choose File… to point the widget at any other `.md` file, for example
one in Documents or a synced folder. The widget reloads when the file changes.

```markdown
# TO DO:

## Work
- [ ] Refresh vortex
- [ ] report 2.2 vs 2.3

## Done
- [x] Buy milk @done(2026-09-17 10:22) @from(Work)
```

`@done(...)` and `@from(...)` are hidden in the widget; they drive the 24-hour
purge and the "uncheck moves back" behavior. Lines that are neither headings nor
`- [ ]` tasks are shown as plain notes.

## Limitations

- Not visible inside full-screen apps (a Spaces limitation for any desktop widget).
- Editing is per line; a task cannot contain a line break.
- Done items are not editable; uncheck them first.

## Debug hooks

- `ToDo --render list.md out.png [fontSize]` renders a widget for any markdown
  file to a PNG without touching your widgets. Good for checking layout changes.
- `kill -USR1 <pid>` writes the rendered widget to `$TMPDIR/todo-snapshot.png`.
- `kill -USR2 <pid>` runs a scripted editing session and logs to `$TMPDIR/todo-debug.log`.
  It edits the live list, so it is only armed when the app was launched with
  `--debug-script` (`open build/ToDo.app --args --debug-script`).
