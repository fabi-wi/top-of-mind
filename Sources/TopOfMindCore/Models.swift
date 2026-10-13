import Foundation

public enum TaskDestination: String, Codable, CaseIterable, Hashable, Sendable {
    case inbox
    case doNow
    case schedule
    case delegate
    case discard
}

public enum TaskLifecycle: String, Codable, CaseIterable, Hashable, Sendable {
    case active
    case completed
    case trashed
}

public enum ThemePreference: String, Codable, CaseIterable, Hashable, Sendable {
    case light
    case dark
}

public struct TaskItem: Identifiable, Codable, Equatable, Hashable, Sendable {
    public var id: UUID
    public var title: String
    public var destination: TaskDestination
    public var lifecycle: TaskLifecycle
    public var createdAt: Date
    public var updatedAt: Date
    public var order: Int

    public init(
        id: UUID = UUID(),
        title: String,
        destination: TaskDestination = .inbox,
        lifecycle: TaskLifecycle = .active,
        createdAt: Date = Date(),
        updatedAt: Date? = nil,
        order: Int = 0
    ) {
        self.id = id
        self.title = title
        self.destination = destination
        self.lifecycle = lifecycle
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
        self.order = order
    }
}

public struct BoardSnapshot: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var tasks: [TaskItem]
    public var theme: ThemePreference
    public var isPinned: Bool
    public var showsMatrixLabels: Bool

    public init(
        schemaVersion: Int = Self.currentSchemaVersion,
        tasks: [TaskItem] = [],
        theme: ThemePreference = .light,
        isPinned: Bool = false,
        showsMatrixLabels: Bool = false
    ) {
        self.schemaVersion = schemaVersion
        self.tasks = tasks
        self.theme = theme
        self.isPinned = isPinned
        self.showsMatrixLabels = showsMatrixLabels
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, tasks, theme, isPinned, showsMatrixLabels
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try values.decode(Int.self, forKey: .schemaVersion)
        tasks = try values.decode([TaskItem].self, forKey: .tasks)
        theme = try values.decodeIfPresent(ThemePreference.self, forKey: .theme) ?? .light
        isPinned = try values.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
        showsMatrixLabels = try values.decodeIfPresent(Bool.self, forKey: .showsMatrixLabels) ?? false
    }
}
