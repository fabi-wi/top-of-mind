import AppKit
import Combine
import Foundation
import TopOfMindCore

@MainActor
final class BoardStore: ObservableObject {
    @Published private(set) var engine: BoardEngine
    @Published var errorMessage: String?
    @Published private(set) var isReadOnly = false
    private let repository: JSONBoardRepository?

    var snapshot: BoardSnapshot { engine.snapshot }
    var isDark: Bool { snapshot.theme == .dark }

    init(demo: Bool, theme: ThemePreference?) {
        if demo {
            repository = nil
            var demoEngine = BoardEngine()
            let samples: [(String, TaskDestination)] = [
                ("Plan a weekend trip", .inbox), ("Read saved article", .inbox),
                ("Organize photos", .inbox), ("Buy a desk lamp", .inbox),
                ("Review monthly budget", .inbox), ("Learn a new recipe", .inbox),
                ("Submit assignment", .doNow), ("Send project proposal", .doNow),
                ("Plan next semester", .schedule), ("Back up project files", .schedule),
                ("Book meeting room", .delegate), ("Request invoice copy", .delegate),
                ("Browse new gadgets", .discard), ("Reorganize old folders", .discard)
            ]
            for (title, destination) in samples {
                if let task = demoEngine.add(title: title) {
                    _ = demoEngine.move(id: task.id, to: destination)
                }
            }
            demoEngine.setTheme(theme ?? .light)
            engine = demoEngine
        } else {
            let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            let repository = JSONBoardRepository(url: support.appendingPathComponent("Top of Mind/tasks.json"))
            self.repository = repository
            do {
                engine = BoardEngine(snapshot: try repository.load())
            } catch {
                engine = BoardEngine()
                errorMessage = "Your saved tasks could not be opened. Your file is untouched. \(error.localizedDescription)"
                isReadOnly = true
            }
            if let theme, !isReadOnly { setTheme(theme) }
        }
    }

    func tasks(in destination: TaskDestination) -> [TaskItem] {
        engine.tasks(for: destination)
    }

    func history(_ lifecycle: TaskLifecycle) -> [TaskItem] {
        TaskDestination.allCases.flatMap { engine.tasks(for: $0, lifecycle: lifecycle) }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    @discardableResult
    func add(_ title: String) -> Bool {
        commit { $0.add(title: title) != nil }
    }

    func move(_ id: UUID, to destination: TaskDestination) {
        _ = commit { $0.move(id: id, to: destination) }
    }

    @discardableResult
    func reorder(_ id: UUID, before beforeID: UUID?, in destination: TaskDestination) -> Bool {
        guard snapshot.tasks.contains(where: { $0.id == id }) else { return false }
        return commit(acceptUnchanged: true) { $0.reorder(id: id, beforeID: beforeID, destination: destination) }
    }

    func complete(_ id: UUID) { _ = commit { $0.complete(id: id) } }
    func trash(_ id: UUID) { _ = commit { $0.trash(id: id) } }
    func restore(_ id: UUID) { _ = commit { $0.restore(id: id) } }

    @discardableResult
    func rename(_ id: UUID, to title: String) -> Bool {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              snapshot.tasks.contains(where: { $0.id == id }) else { return false }
        return commit(acceptUnchanged: true) { $0.rename(id: id, title: title) }
    }

    func setTheme(_ theme: ThemePreference) {
        _ = commit { $0.setTheme(theme); return true }
    }

    func toggleTheme() { setTheme(isDark ? .light : .dark) }
    func togglePin() { _ = commit { $0.setPinned(!snapshot.isPinned); return true } }
    func toggleLabels() { _ = commit { $0.setMatrixLabels(!snapshot.showsMatrixLabels); return true } }

    func retryLoading() {
        guard let repository else { return }
        do {
            engine = BoardEngine(snapshot: try repository.load())
            errorMessage = nil
            isReadOnly = false
        } catch {
            errorMessage = "Your saved tasks could not be opened. Your file is untouched. \(error.localizedDescription)"
        }
    }

    private func commit(acceptUnchanged: Bool = false, _ mutation: (inout BoardEngine) -> Bool) -> Bool {
        guard !isReadOnly else { return false }
        var candidate = engine
        guard mutation(&candidate) else { return acceptUnchanged }
        do {
            try repository?.save(candidate.snapshot)
            engine = candidate
            errorMessage = nil
            return true
        } catch {
            errorMessage = "This change could not be saved, so your tasks are unchanged. \(error.localizedDescription)"
            return false
        }
    }
}

extension TaskDestination {
    var displayName: String {
        switch self {
        case .inbox: "Inbox"
        case .doNow: "Do"
        case .schedule: "Schedule"
        case .delegate: "Delegate"
        case .discard: "Discard"
        }
    }

    var explanation: String {
        switch self {
        case .inbox: "Sort whenever you’re ready."
        case .doNow: "Important + urgent. Do it soon."
        case .schedule: "Important, not urgent. Plan it."
        case .delegate: "Urgent, less important. Can someone else do it?"
        case .discard: "Neither urgent nor important. Let it go."
        }
    }

    var symbol: String {
        switch self {
        case .inbox: "tray"
        case .doNow: "bolt"
        case .schedule: "calendar"
        case .delegate: "person.2"
        case .discard: "leaf"
        }
    }
}
