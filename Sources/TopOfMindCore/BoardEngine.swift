import Foundation

/// Value-based board operations, independent of storage and user interface state.
public struct BoardEngine: Sendable {
    public private(set) var snapshot: BoardSnapshot

    public init(snapshot: BoardSnapshot = BoardSnapshot()) {
        self.snapshot = snapshot
    }

    public func tasks(
        for destination: TaskDestination,
        lifecycle: TaskLifecycle = .active
    ) -> [TaskItem] {
        snapshot.tasks
            .filter { $0.destination == destination && $0.lifecycle == lifecycle }
            .sorted(by: Self.isOrderedBefore)
    }

    @discardableResult
    public mutating func add(title: String, now: Date = Date()) -> TaskItem? {
        let normalized = Self.normalizeTitle(title)
        guard !normalized.isEmpty else { return nil }
        normalizeOrders(destination: .inbox, lifecycle: .active)
        let task = TaskItem(
            title: normalized,
            createdAt: now,
            order: tasks(for: .inbox).count
        )
        snapshot.tasks.append(task)
        return task
    }

    /// Moving an archived task deliberately brings it back to the active board.
    @discardableResult
    public mutating func move(
        id: UUID,
        to destination: TaskDestination,
        now: Date = Date()
    ) -> Bool {
        guard let task = snapshot.tasks.first(where: { $0.id == id }) else { return false }
        guard task.destination != destination || task.lifecycle != .active else { return false }
        return reorder(id: id, beforeID: nil, destination: destination, now: now)
    }

    @discardableResult
    public mutating func complete(id: UUID, now: Date = Date()) -> Bool {
        transition(id: id, to: .completed, now: now)
    }

    @discardableResult
    public mutating func restore(id: UUID, now: Date = Date()) -> Bool {
        transition(id: id, to: .active, now: now)
    }

    @discardableResult
    public mutating func trash(id: UUID, now: Date = Date()) -> Bool {
        transition(id: id, to: .trashed, now: now)
    }

    @discardableResult
    public mutating func rename(id: UUID, title: String, now: Date = Date()) -> Bool {
        let normalized = Self.normalizeTitle(title)
        guard !normalized.isEmpty,
              let index = snapshot.tasks.firstIndex(where: { $0.id == id }),
              snapshot.tasks[index].title != normalized else { return false }
        snapshot.tasks[index].title = normalized
        snapshot.tasks[index].updatedAt = now
        return true
    }

    /// Inserts before an active task in the destination, or appends for a missing/invalid anchor.
    /// A task may be reordered within its list, moved across lists, or restored from an archive.
    @discardableResult
    public mutating func reorder(
        id: UUID,
        beforeID: UUID?,
        destination: TaskDestination,
        now: Date = Date()
    ) -> Bool {
        guard let index = snapshot.tasks.firstIndex(where: { $0.id == id }) else { return false }
        let original = snapshot.tasks[index]
        if beforeID == id && original.destination == destination && original.lifecycle == .active {
            return false
        }

        let existing = tasks(for: destination)
        var arranged = existing.filter { $0.id != id }
        let insertionIndex = beforeID.flatMap { anchor in
            arranged.firstIndex(where: { $0.id == anchor })
        } ?? arranged.endIndex
        arranged.insert(original, at: insertionIndex)

        guard original.destination != destination || original.lifecycle != .active ||
                existing.map(\.id) != arranged.map(\.id) else { return false }

        for (order, task) in arranged.enumerated() {
            guard let taskIndex = snapshot.tasks.firstIndex(where: { $0.id == task.id }) else { continue }
            snapshot.tasks[taskIndex].order = order
            if task.id == id {
                snapshot.tasks[taskIndex].destination = destination
                snapshot.tasks[taskIndex].lifecycle = .active
                snapshot.tasks[taskIndex].updatedAt = now
            }
        }

        if original.destination != destination || original.lifecycle != .active {
            normalizeOrders(destination: original.destination, lifecycle: original.lifecycle)
        }
        return true
    }

    @discardableResult
    public mutating func setTheme(_ theme: ThemePreference) -> Bool {
        guard snapshot.theme != theme else { return false }
        snapshot.theme = theme
        return true
    }

    @discardableResult
    public mutating func setPinned(_ isPinned: Bool) -> Bool {
        guard snapshot.isPinned != isPinned else { return false }
        snapshot.isPinned = isPinned
        return true
    }

    @discardableResult
    public mutating func setMatrixLabels(_ showsLabels: Bool) -> Bool {
        guard snapshot.showsMatrixLabels != showsLabels else { return false }
        snapshot.showsMatrixLabels = showsLabels
        return true
    }

    private mutating func transition(id: UUID, to lifecycle: TaskLifecycle, now: Date) -> Bool {
        guard let index = snapshot.tasks.firstIndex(where: { $0.id == id }) else { return false }
        let original = snapshot.tasks[index]
        guard original.lifecycle != lifecycle else { return false }
        normalizeOrders(destination: original.destination, lifecycle: lifecycle)
        let targetCount = tasks(for: original.destination, lifecycle: lifecycle).count
        snapshot.tasks[index].lifecycle = lifecycle
        snapshot.tasks[index].order = targetCount
        snapshot.tasks[index].updatedAt = now
        normalizeOrders(destination: original.destination, lifecycle: original.lifecycle)
        normalizeOrders(destination: original.destination, lifecycle: lifecycle)
        return true
    }

    private mutating func normalizeOrders(destination: TaskDestination, lifecycle: TaskLifecycle) {
        for (order, task) in tasks(for: destination, lifecycle: lifecycle).enumerated() {
            guard let index = snapshot.tasks.firstIndex(where: { $0.id == task.id }) else { continue }
            snapshot.tasks[index].order = order
        }
    }

    private static func normalizeTitle(_ title: String) -> String {
        title.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    private static func isOrderedBefore(_ lhs: TaskItem, _ rhs: TaskItem) -> Bool {
        if lhs.order != rhs.order { return lhs.order < rhs.order }
        if lhs.createdAt != rhs.createdAt { return lhs.createdAt < rhs.createdAt }
        return lhs.id.uuidString < rhs.id.uuidString
    }
}
