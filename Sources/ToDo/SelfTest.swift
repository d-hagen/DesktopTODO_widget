import Foundation

/// Model checks, run with `ToDo --selftest`. XCTest is not available without Xcode.
enum SelfTest {
    private static var failures = 0
    private static var count = 0

    private static func check(_ cond: Bool, _ msg: String, file: String = #file, line: Int = #line) {
        count += 1
        if !cond {
            failures += 1
            print("FAIL \((file as NSString).lastPathComponent):\(line): \(msg)")
        }
    }

    private static func equal<T: Equatable>(_ a: T, _ b: T, _ msg: String = "", line: Int = #line) {
        check(a == b, "\(msg) expected \(b) got \(a)", line: line)
    }

    static let sample = """
    # TO DO:

    ## Work
    - [ ] Refresh vortex
    - [ ] report 2.2 vs 2.3

    ## Home
    - [ ] 4g Wifi
    some note

    ## Done
    - [x] Buy milk @done(2026-09-17 10:22) @from(Home)

    """

    static func run() -> Int32 {
        roundTrip()
        unnamedLeading()
        toggle()
        uncheckLastDone()
        purge()
        normalize()
        convert()
        deleteSection()
        navigation()
        emptyTasks()
        print("\(count - failures)/\(count) checks passed")
        return failures == 0 ? 0 : 1
    }

    static func roundTrip() {
        let doc = Document.parse(sample)
        equal(doc.title, "TO DO:")
        equal(doc.sections.map(\.title), ["Work", "Home", "Done"])
        equal(doc.sections[1].items[1].isTask, false)
        equal(doc.sections[2].items[0].from, "Home")
        check(doc.sections[2].items[0].doneAt != nil, "doneAt parsed")
        equal(doc.serialized(), sample, "round trip")
    }

    static func unnamedLeading() {
        let doc = Document.parse("- [ ] a\n- [ ] b\n## S\n- [ ] c\n")
        equal(doc.title, "TO DO:")
        check(doc.sections[0].title == nil, "unnamed first section")
        equal(doc.sections[0].items.count, 2)
        equal(doc.serialized(), "# TO DO:\n\n- [ ] a\n- [ ] b\n\n## S\n- [ ] c\n")
    }

    static func toggle() {
        var doc = Document.parse(sample)
        let id = doc.sections[0].items[0].id
        let now = Date()
        doc.toggle(id, now: now)
        equal(doc.sections[0].items.count, 1)
        let done = doc.sections[2].items.last!
        equal(done.id, id)
        check(done.done, "done flag")
        equal(done.from, "Work")
        equal(done.doneAt, now)

        doc.toggle(id)
        equal(doc.sections[0].items.last?.id, id, "moved back to Work")
        check(!doc.sections[0].items.last!.done, "undone")
        check(doc.sections[0].items.last!.from == nil, "from cleared")
        equal(doc.sections[2].items.count, 1)
    }

    static func uncheckLastDone() {
        var doc = Document.parse(sample)
        let id = doc.sections[2].items[0].id
        doc.toggle(id)
        check(doc.doneIndex == nil, "Done section removed when empty")
        equal(doc.sections[1].items.last?.text, "Buy milk")
    }

    static func purge() {
        var doc = Document.parse(sample)
        let stamp = doc.sections[2].items[0].doneAt!
        check(!doc.purge(now: stamp.addingTimeInterval(3600), maxAge: 86400), "not purged after 1h")
        check(doc.purge(now: stamp.addingTimeInterval(90000), maxAge: 86400), "purged after 25h")
        check(doc.doneIndex == nil, "Done removed after purge")
    }

    static func normalize() {
        var doc = Document.parse("# T\n\n## A\n- [x] x\n- [ ] y\n")
        check(doc.normalize(), "normalize changed")
        equal(doc.sections[0].items.map(\.text), ["y"])
        equal(doc.sections[1].title, "Done")
        equal(doc.sections[1].items[0].from, "A")
        check(doc.sections[1].items[0].doneAt != nil, "stamped")
        check(!doc.normalize(), "idempotent")
    }

    static func convert() {
        var doc = Document.parse("# T\n\n## A\n- [ ] a\n- [ ] b\n- [ ] c\n")
        let b = doc.sections[0].items[1].id
        doc.convertToSection(b, title: "B")
        equal(doc.sections.map(\.title), ["A", "B"])
        equal(doc.sections[0].items.map(\.text), ["a"])
        equal(doc.sections[1].items.map(\.text), ["c"])
    }

    static func deleteSection() {
        var doc = Document.parse("# T\n\n## A\n- [ ] a\n\n## B\n- [ ] b\n")
        doc.deleteSection(doc.sections[1].id)
        equal(doc.sections.count, 1)
        equal(doc.sections[0].items.map(\.text), ["a", "b"])

        var doc2 = Document.parse("# T\n\n## A\n- [ ] a\n")
        doc2.deleteSection(doc2.sections[0].id)
        check(doc2.sections[0].title == nil, "first section becomes unnamed")
        equal(doc2.sections[0].items.map(\.text), ["a"])
    }

    static func navigation() {
        let doc = Document.parse(sample)
        let ids = doc.editableIDs
        equal(ids.first, Document.titleID)
        equal(ids.count, 8, "title, Work, 2, Home, 2, 1 done item")
        equal(doc.nextEditable(after: Document.titleID), doc.sections[0].id)
        check(doc.previousEditable(before: Document.titleID) == nil, "nothing before title")
    }

    static func emptyTasks() {
        var doc = Document.parse("# T\n\n- [ ] a\n")
        doc.appendItem()
        equal(doc.serialized(), "# T\n\n- [ ] a\n")
    }
}
