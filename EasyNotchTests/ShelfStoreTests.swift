import Foundation
import Testing
@testable import EasyNotch

/// Uses real files in a temporary folder, so renaming and deleting are tested for real.
struct ShelfStoreTests {
    let t0 = Date(timeIntervalSinceReferenceDate: 800_000_000)

    /// A temporary folder holding the store's data and some test files. Removed afterwards.
    final class Sandbox {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("EasyNotchTests-\(UUID().uuidString)", isDirectory: true)
        var storeFolder: URL { root.appendingPathComponent("store", isDirectory: true) }
        /// The store's clock; tests move it forward.
        var now: Date

        init(now: Date) {
            self.now = now
            try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        }

        func file(_ name: String) -> URL {
            let url = root.appendingPathComponent(name)
            try? "hello".write(to: url, atomically: true, encoding: .utf8)
            return url
        }

        func store(_ settings: AppSettings) -> ShelfStore {
            ShelfStore(settings: settings, directory: storeFolder, now: { [unowned self] in now })
        }

        deinit {
            try? FileManager.default.removeItem(at: root)
        }
    }

    func names(_ store: ShelfStore) -> [String] {
        store.items.map(\.name)
    }

    @Test func newFilesGoFirstInTheOrderDropped() {
        withIsolatedDefaults { defaults in
            let sandbox = Sandbox(now: t0)
            let store = sandbox.store(AppSettings(defaults: defaults))
            store.add([sandbox.file("a.txt"), sandbox.file("b.txt")])
            store.add([sandbox.file("c.txt")])
            #expect(names(store) == ["c.txt", "a.txt", "b.txt"])
        }
    }

    @Test func addingAFileAgainMovesItToTheFrontInsteadOfRepeatingIt() {
        withIsolatedDefaults { defaults in
            let sandbox = Sandbox(now: t0)
            let store = sandbox.store(AppSettings(defaults: defaults))
            let a = sandbox.file("a.txt")
            store.add([a, sandbox.file("b.txt")])
            store.add([a])
            #expect(names(store) == ["a.txt", "b.txt"])
        }
    }

    @Test func theOldestFilesDropOffPastTheMaximum() {
        withIsolatedDefaults { defaults in
            let settings = AppSettings(defaults: defaults)
            settings.shelfMaxItems = 5
            let sandbox = Sandbox(now: t0)
            let store = sandbox.store(settings)
            for index in 1...7 {
                store.add([sandbox.file("\(index).txt")])
            }
            #expect(names(store) == ["7.txt", "6.txt", "5.txt", "4.txt", "3.txt"])
            #expect(store.availableURLs.count == 5)
        }
    }

    @Test func removingAndClearing() {
        withIsolatedDefaults { defaults in
            let sandbox = Sandbox(now: t0)
            let store = sandbox.store(AppSettings(defaults: defaults))
            store.add([sandbox.file("a.txt"), sandbox.file("b.txt")])

            store.remove([store.items[0].id])
            #expect(names(store) == ["b.txt"])

            store.removeAll()
            #expect(store.items.isEmpty)
        }
    }

    @Test func theShelfIsStillThereAfterRelaunching() {
        withIsolatedDefaults { defaults in
            let settings = AppSettings(defaults: defaults)
            let sandbox = Sandbox(now: t0)
            sandbox.store(settings).add([sandbox.file("a.txt")])

            let relaunched = sandbox.store(settings)
            #expect(names(relaunched) == ["a.txt"])
            #expect(relaunched.availableURLs.first?.lastPathComponent == "a.txt")
        }
    }

    @Test func aRenamedFileStaysOnTheShelf() throws {
        try withIsolatedDefaults { defaults in
            let sandbox = Sandbox(now: t0)
            let store = sandbox.store(AppSettings(defaults: defaults))
            let original = sandbox.file("draft.txt")
            store.add([original])

            try FileManager.default.moveItem(at: original, to: sandbox.root.appendingPathComponent("final.txt"))
            store.refresh()

            #expect(names(store) == ["final.txt"])
            #expect(store.availableURLs.first?.lastPathComponent == "final.txt")
        }
    }

    @Test func aDeletedFileShowsAsMissing() throws {
        try withIsolatedDefaults { defaults in
            let sandbox = Sandbox(now: t0)
            let store = sandbox.store(AppSettings(defaults: defaults))
            let file = sandbox.file("gone.txt")
            store.add([file])

            try FileManager.default.removeItem(at: file)
            store.refresh()

            let item = try #require(store.items.first)
            #expect(store.isMissing(item))
            #expect(item.name == "gone.txt")  // still shown, so you know what went missing
            #expect(store.availableURLs.isEmpty)
        }
    }

    @Test func aFileWeAreNotAllowedToReadShowsNoAccessRatherThanMissing() throws {
        try withIsolatedDefaults { defaults in
            let sandbox = Sandbox(now: t0)
            let store = sandbox.store(AppSettings(defaults: defaults))
            let folder = sandbox.root.appendingPathComponent("locked", isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let file = folder.appendingPathComponent("secret.txt")
            try "hello".write(to: file, atomically: true, encoding: .utf8)
            store.add([file])

            // Lock the folder, like macOS does for Downloads when access was declined.
            try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: folder.path)
            defer { try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: folder.path) }
            store.refresh()

            let item = try #require(store.items.first)
            #expect(store.status(of: item) == .noAccess)
        }
    }

    @Test func draggedOutFilesStayUnlessTheSettingIsOn() {
        withIsolatedDefaults { defaults in
            let settings = AppSettings(defaults: defaults)
            let sandbox = Sandbox(now: t0)
            let store = sandbox.store(settings)
            let a = sandbox.file("a.txt")
            store.add([a, sandbox.file("b.txt")])

            store.finishedDraggingOut([a])
            #expect(names(store) == ["a.txt", "b.txt"])  // off by default

            settings.shelfRemoveAfterDragOut = true
            store.finishedDraggingOut([a])
            #expect(names(store) == ["b.txt"])
        }
    }

    @Test func oldFilesAreRemovedWhenAutoRemoveIsOn() {
        withIsolatedDefaults { defaults in
            let settings = AppSettings(defaults: defaults)
            settings.shelfAutoRemoveDays = 1
            let sandbox = Sandbox(now: t0)
            let store = sandbox.store(settings)
            store.add([sandbox.file("old.txt")])

            sandbox.now = t0 + 12 * 3600
            store.add([sandbox.file("new.txt")])
            sandbox.now = t0 + 25 * 3600
            store.refresh()

            #expect(names(store) == ["new.txt"])
        }
    }

    @Test func webLinksAreIgnored() {
        withIsolatedDefaults { defaults in
            let sandbox = Sandbox(now: t0)
            let store = sandbox.store(AppSettings(defaults: defaults))
            store.add([URL(string: "https://example.com/file.pdf")!])
            #expect(store.items.isEmpty)
        }
    }
}
