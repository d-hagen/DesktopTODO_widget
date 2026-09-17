# Desktop To-Do Widget — Implementation Plan

## Goal

A native macOS widget that lives on the desktop, behind every other app, on every
Space, at whatever position you drag it to. It renders a markdown checklist with
section headers, inline editing, checkboxes with strikethrough, a Done section
that auto-purges after 24 hours, a `•••` menu, a `×` hide button, a menu bar
icon, a color picker, resizing, and launch at login.

Look and feel follows the screenshot: solid purple card, rounded corners, large
heavy "TO DO:" title, square checkboxes, Avenir Next–style type.

## Decisions (already made)

| Question | Decision | Reason |
|---|---|---|
| Stack | Swift 5.9, AppKit window + SwiftUI content, SwiftPM | Only AppKit gives control over window level, Spaces and key focus. Electron/Tauri desktop-level windows cannot receive input. Builds with Command Line Tools only (no Xcode.app installed). |
| Editing | Inline per line | Click a line to edit it in place. |
| Storage | Plain markdown file, default `~/Library/Application Support/ToDo/todo.md` (Documents triggers a blocking privacy prompt on first launch; use Choose File… to move it) | Editable elsewhere, syncable, human-readable. Widget reloads on external change. |
| Done items | Moved to a `## Done` section at the bottom, crossed out, stamped with a completion time, purged after 24 h or when deleted manually | Your answer to the clarification question. |
| Extras in v1 | Launch at login, resizable, color picker, menu bar icon | Your answer. |
| Not in v1 | Drag-to-reorder, due dates, multiple lists, iCloud sync | Keep scope small; reorder is the most likely v2 feature. |

## Environment

- macOS 14.1 Sonoma (Apple silicon)
- Swift 5.9.2 via Command Line Tools at `/Library/Developer/CommandLineTools`
- No Xcode.app → build with `swift build`, assemble the `.app` bundle with a script
- Deployment target: macOS 14.0

## File format

The widget reads and writes plain markdown. Example of `todo.md`:

```markdown
# TO DO:

## Work
- [ ] Refresh vortex
- [ ] report 2.2 vs 2.3
- [ ] Cover Letter HTG

## Home
- [ ] 4g Wifi
- [ ] Drain Fix

## Done
- [x] Buy milk @done(2026-09-17 10:22) @from(Home)
```

Rules:
- First `# ` heading is the widget title. Missing → "TO DO:" is shown and written.
- `## ` headings are sections. Items before the first section go in an unnamed section.
- `- [ ]` / `- [x]` are tasks. Anything else (blank lines, stray text) is preserved
  verbatim in order so an externally edited file is never mangled.
- `@done(YYYY-MM-DD HH:mm)` records completion time; `@from(Section)` records the
  origin section so un-checking can move the task back. Both tags are hidden in the UI.
- `## Done` is auto-created when the first task is checked and always kept last.

## Window behavior (the make-or-break part)

`DesktopWindow: NSWindow`

- `styleMask = [.borderless, .resizable]` → no title bar, edge-drag resizing still works
- `level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)`
  → above wallpaper and desktop icons, below every normal app window
- `collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]`
  → same spot on every Space, untouched by Mission Control, skipped by Cmd+`
- `override var canBecomeKey: Bool { true }` → borderless window can take keyboard focus
- `isMovableByWindowBackground = true` → drag anywhere on the purple background
- `setFrameAutosaveName("ToDoWidget")` → position and size persist, multi-monitor aware
- `backgroundColor = .clear`, `isOpaque = false`, `hasShadow = false`; the rounded
  purple card is drawn by the content view
- `Info.plist` `LSUIElement = true` → no Dock icon, no app menu bar takeover
- Minimum size 220×200

Expected behavior to verify in the spike (step 1 below):
1. Open Finder/Safari over it → widget stays underneath.
2. Switch Spaces → widget is in the same place.
3. "Show Desktop" gesture / F11 → widget remains (it is not a normal window).
4. Click the widget → it becomes key and a text field accepts typing, without
   the widget jumping above other windows.
5. Quit and relaunch → same position and size.

Known limitation: not visible inside full-screen apps. That is inherent to Spaces.

## Architecture

```
ToDoTool/
  Package.swift
  build.sh                        # swift build → ToDo.app → codesign → /Applications
  Resources/Info.plist
  Sources/ToDo/
    App.swift                     # NSApplication setup, AppDelegate
    Window/DesktopWindow.swift    # NSWindow subclass (level, Spaces, key focus)
    Window/WidgetController.swift # creates window, hosts SwiftUI root, show/hide
    Model/Document.swift          # Title, Section, Task structs; markdown parse/serialize
    Model/Store.swift             # ObservableObject: load, debounced atomic save,
                                  #   file watcher, Done purge timer
    Views/RootView.swift          # card background, title, top bar (× and •••)
    Views/SectionView.swift       # header row + its tasks
    Views/TaskRow.swift           # checkbox + editable text, strikethrough
    Views/EditableText.swift      # NSTextField wrapper: Enter / Backspace-on-empty /
                                  #   Up / Down / Esc handling via NSTextFieldDelegate
    Menu/StatusItem.swift         # menu bar icon and its menu
    Menu/WidgetMenu.swift         # the ••• menu
    Settings/Preferences.swift    # UserDefaults: color, file path, hidden state
    Settings/LoginItem.swift      # SMAppService register/unregister
  Tests/ToDoTests/
    DocumentTests.swift           # parse ↔ serialize round-trips, Done rules
```

Why the NSTextField wrapper instead of SwiftUI `TextField`: SwiftUI's field
consumes key events before `onKeyPress` sees them reliably. The AppKit delegate
method `control(_:textView:doCommandBy:)` receives `insertNewline:`,
`deleteBackward:`, `moveUp:`, `moveDown:` and `cancelOperation:` directly.

## Interaction spec

Rendering
- Title: heavy weight, ~34 pt. Sections: bold, ~18 pt. Tasks: regular, ~20 pt.
- Checkbox: 26 pt rounded square, 2 pt border, filled with a tick when checked.
- Checked tasks: strikethrough, 50 % opacity.
- Text color chosen automatically (black or white) from background luminance.

Editing
- Click a task's text or a header → that line becomes an editable field.
- Enter → save line and create a new empty task directly below (on a header:
  new task as the first item of that section).
- Backspace on an empty line → delete the line and focus the previous one.
- Up / Down → move focus to the previous / next editable line.
- Esc or click elsewhere → end editing; an empty task is removed.
- Typing `## ` (or `# `) at the start of a task and pressing Enter converts it
  to a section header. Deleting a header's text and pressing Backspace removes
  the header; its tasks join the section above.
- Click the empty area below the last line → new task at the end of the last
  section (Done excluded).
- ⌘N → new task in the first section. ⌘S → force save (autosave already runs).

Checking off
- Click checkbox → task marked `[x]`, stamped `@done(now) @from(Section)`,
  moved to the end of `## Done`.
- Uncheck in Done → tags removed, task moved back to the end of `@from` section
  (or first section if it no longer exists).
- Purge: on load and every 10 minutes, delete Done tasks whose `@done` is older
  than 24 h. Manual delete works as for any line. "Clear completed" removes all.

Persistence
- Save: 300 ms debounce after any change, plus on window resign key and on quit.
  Written atomically (temp file + rename).
- Reload: directory watcher (DispatchSource on the parent folder, because most
  editors save atomically and replace the inode). Ignore events for content the
  widget itself just wrote (compare hash). Debounce 200 ms. External edits while
  a line is being edited are merged after editing ends.
- First run: if the file does not exist, write a starter file with the sample
  content above.

Top bar and menus
- `×` (top-left) → hides the widget. Bring back from the menu bar icon.
- `•••` (top-right) → menu: New Task, New Section, Clear Completed, ─, Color…,
  Open todo.md, Choose File…, ─, Launch at Login (toggle), ─, Quit.
- Right-click anywhere → same menu.
- Menu bar icon (checkmark SF Symbol) → Show/Hide Widget, Open todo.md, Quit.

Settings
- Color…: opens `NSColorPanel`; live-updates the card; stored in UserDefaults.
  Default is the screenshot purple (#BC6BC0 approx).
- Launch at Login: `SMAppService.mainApp.register()` / `unregister()`.
  Requires the app to live in `/Applications` (build script copies it there).
- Choose File…: `NSOpenPanel` to pick a different `.md`; path stored in UserDefaults.

## Build and packaging (no Xcode)

`Package.swift`: one executable target `ToDo`, `platforms: [.macOS(.v14)]`,
one test target.

`build.sh`:
1. `swift build -c release`
2. Create `build/ToDo.app/Contents/{MacOS,Resources}`
3. Copy binary and `Info.plist` (bundle id `com.danhagen.todo`, `LSUIElement`,
   `LSMinimumSystemVersion 14.0`, `NSHighResolutionCapable`)
4. `codesign --force --sign - build/ToDo.app` (ad-hoc)
5. Optional `--install`: kill running instance, copy to `/Applications`, relaunch

Tests: `swift test` for the parser and Done rules. Window behavior is verified
manually with the checklist in the spike.

## Implementation order

1. **Spike the window.** Borderless purple card at desktop level, all Spaces,
   draggable, frame autosave, with one throwaway text field. Run the five checks
   above. If focus or level misbehaves on Sonoma, fix it here before anything
   else, because every other feature depends on it.
2. **Model and parser.** `Document` structs, markdown parse/serialize preserving
   unknown lines, `@done`/`@from` tags. Unit tests for round-trips.
3. **Store.** Load, debounced atomic save, directory watcher with self-write
   suppression, starter file on first run.
4. **Rendering.** Title, sections, task rows, checkboxes, strikethrough, colors.
5. **Inline editing.** `EditableText` wrapper and the keyboard rules above.
6. **Done flow.** Move on check, restore on uncheck, 24 h purge timer,
   Clear Completed.
7. **Menus.** `×` hide, `•••` menu, right-click menu, menu bar status item.
8. **Settings.** Color picker, Choose File…, Launch at Login.
9. **Packaging.** `build.sh`, install to `/Applications`, verify launch at login
   after a reboot.

## Risks

- **Desktop-level window focus on Sonoma.** Should work with `canBecomeKey`, but
  this is the one thing that could force a change of approach (e.g. a level of
  `.normal - 1` with `orderBack` on activation). Hence step 1.
- **Ad-hoc signing and `SMAppService`.** Usually fine for apps in
  `/Applications`; if registration is refused, fall back to adding the app
  manually under System Settings → General → Login Items.
- **Concurrent edits.** Widget editing a line while an external editor rewrites
  the file. Mitigated by merging after editing ends; last writer wins.
- **Gatekeeper.** Ad-hoc signed apps run locally without issue since they are
  built on this machine, not downloaded.
