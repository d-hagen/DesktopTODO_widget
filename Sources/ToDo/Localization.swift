import Foundation

/// Thin wrapper over the bundle lookup used for the interface strings.
///
/// English is the base language and its literal text doubles as the lookup key,
/// so `en.lproj` is not needed; `zh-Hans.lproj` provides the translation. When
/// the strings are not bundled (for example the command-line `--selftest` run)
/// the key itself is returned, which keeps the English wording.
///
/// Strings written into the markdown file (the `TO DO:` title and the `Done`
/// heading) are intentionally not localized: they are structural identifiers and
/// stay in English whatever the interface language is.
enum Localization {
    static func string(_ key: String) -> String {
        Bundle.main.localizedString(forKey: key, value: key, table: nil)
    }
}
