import AppKit
import SwiftUI
import UniformTypeIdentifiers
import TopOfMindCore

// Name the property wrapper explicitly to avoid the newer SDK's State macro overload.
private typealias ViewState<Value> = SwiftUI.State<Value>

struct BoardView: View {
    @ObservedObject var store: BoardStore
    var onClose: () -> Void
    var onPinChange: () -> Void
    @ViewState private var draft = ""
    @ViewState private var editing: TaskEditor?
    @ViewState private var history: HistoryKind?
    @FocusState private var inputFocused: Bool
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                header
                if let error = store.errorMessage {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                        Text(error).font(.system(size: 11)).fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 4)
                        if store.isReadOnly {
                            Button("Try again", action: store.retryLoading).buttonStyle(.plain)
                        } else {
                            Button { store.errorMessage = nil } label: { Image(systemName: "xmark") }
                                .buttonStyle(.plain).accessibilityLabel("Dismiss save error")
                        }
                    }
                    .foregroundStyle(colorScheme == .dark ? Color.yellow : Color(red: 0.50, green: 0.28, blue: 0.04))
                    .padding(10)
                    .background(Color.orange.opacity(0.14), in: RoundedRectangle(cornerRadius: 9))
                    .padding(.horizontal, 18).padding(.bottom, 10)
                }
                HStack(alignment: .top, spacing: 12) {
                    inbox
                        .frame(width: max(205, min(260, geometry.size.width * 0.25)))
                    matrix
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 18)
            }
            .foregroundStyle(Color.primary)
            .font(.system(size: 13))
            .sheet(item: $editing) { editor in
                RenameTaskView(store: store, task: editor.task)
            }
            .sheet(item: $history) { kind in
                HistoryView(store: store, kind: kind)
            }
        }
        .onAppear { if store.tasks(in: .inbox).isEmpty { inputFocused = true } }
        .onChange(of: store.snapshot.isPinned) { _, _ in onPinChange() }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Text("Top of Mind").font(.system(size: 20, weight: .bold, design: .rounded))
            Spacer()
            headerButton(symbol: store.snapshot.isPinned ? "pin.fill" : "pin", label: store.snapshot.isPinned ? "Unpin panel" : "Keep panel open", active: store.snapshot.isPinned) {
                store.togglePin()
            }
            Menu {
                Toggle("Show matrix axis labels", isOn: Binding(get: { store.snapshot.showsMatrixLabels }, set: { _ in store.toggleLabels() }))
                Divider()
                Button("Completed tasks") { history = .completed }
                Button("Trash") { history = .trash }
                Divider()
                Button("Quit Top of Mind", systemImage: "power") { NSApplication.shared.terminate(nil) }
            } label: {
                Image(systemName: "slider.horizontal.3").font(.system(size: 13, weight: .medium))
                    .frame(width: 29, height: 29)
                    .background(Color.primary.opacity(0.065), in: Circle())
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("View options")
            .accessibilityLabel("View options")
            headerButton(symbol: "xmark", label: "Close panel", action: onClose)
        }
        .padding(.horizontal, 22)
        .padding(.top, 19)
        .padding(.bottom, 17)
    }

    private func headerButton(symbol: String, label: String, active: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 13, weight: .medium))
                .frame(width: 29, height: 29)
                .background(Color.primary.opacity(active ? 0.14 : 0.065), in: Circle())
        }
        .buttonStyle(.plain)
        .help(label)
        .accessibilityLabel(label)
        .accessibilityValue(active ? "On" : "Off")
    }

    private var inbox: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 5) {
                TextField("Add a task…", text: $draft)
                    .textFieldStyle(.plain)
                    .focused($inputFocused)
                    .onSubmit(addTask)
                    .accessibilityLabel("New task title")
                    .disabled(store.isReadOnly)
                Button(action: addTask) {
                    Image(systemName: "plus").font(.system(size: 13, weight: .semibold))
                        .frame(width: 23, height: 23)
                        .background(Color.primary.opacity(0.09), in: Circle())
                }
                .buttonStyle(.plain)
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || store.isReadOnly)
                .help("Add to inbox (Return)")
                .accessibilityLabel("Add task to inbox")
            }
            .padding(.horizontal, 12).padding(.vertical, 11)
            .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.primary.opacity(0.065)))
            .padding(12)
            TaskListView(store: store, destination: .inbox, tint: .primary, onEdit: { editing = TaskEditor(task: $0) })
                .padding(.horizontal, 10)
        }
    }

    private var matrix: some View {
        VStack(spacing: 8) {
            if store.snapshot.showsMatrixLabels {
                HStack {
                    Text("Urgent").frame(maxWidth: .infinity)
                    Text("Not urgent").frame(maxWidth: .infinity)
                }
                .font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary)
                .padding(.leading, 17)
            }
            HStack(spacing: 8) {
                if store.snapshot.showsMatrixLabels { verticalAxis("Important") }
                QuadrantView(store: store, destination: .doNow, onEdit: { editing = TaskEditor(task: $0) })
                QuadrantView(store: store, destination: .schedule, onEdit: { editing = TaskEditor(task: $0) })
            }
            HStack(spacing: 8) {
                if store.snapshot.showsMatrixLabels { verticalAxis("Less important") }
                QuadrantView(store: store, destination: .delegate, onEdit: { editing = TaskEditor(task: $0) })
                QuadrantView(store: store, destination: .discard, onEdit: { editing = TaskEditor(task: $0) })
            }
        }
    }

    private func verticalAxis(_ text: String) -> some View {
        Text(text).font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary)
            .fixedSize().rotationEffect(.degrees(-90)).frame(width: 10)
    }

    private func addTask() {
        if store.add(draft) { draft = ""; inputFocused = true }
    }
}

private struct TaskEditor: Identifiable {
    var task: TaskItem
    var id: UUID { task.id }
}

struct QuadrantView: View {
    @ObservedObject var store: BoardStore
    let destination: TaskDestination
    var onEdit: (TaskItem) -> Void
    @ViewState private var targeted = false
    @Environment(\.colorScheme) private var colorScheme

    private var tint: Color {
        let colors: (light: Color, dark: Color)
        switch destination {
        case .doNow: colors = (Color(red: 0.12, green: 0.37, blue: 0.29), Color(red: 0.59, green: 0.86, blue: 0.70))
        case .schedule: colors = (Color(red: 0.48, green: 0.27, blue: 0.11), Color(red: 0.98, green: 0.76, blue: 0.49))
        case .delegate: colors = (Color(red: 0.14, green: 0.35, blue: 0.55), Color(red: 0.51, green: 0.75, blue: 0.96))
        case .discard: colors = (Color(red: 0.51, green: 0.20, blue: 0.26), Color(red: 0.98, green: 0.62, blue: 0.68))
        case .inbox: colors = (.gray, .gray)
        }
        return colorScheme == .dark ? colors.dark : colors.light
    }

    private var fill: Color {
        switch destination {
        case .doNow: Color(red: 0.58, green: 0.81, blue: 0.66)
        case .schedule: Color(red: 0.98, green: 0.72, blue: 0.48)
        case .delegate: Color(red: 0.48, green: 0.72, blue: 0.93)
        case .discard: Color(red: 0.92, green: 0.56, blue: 0.63)
        case .inbox: .gray
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(destination.displayName).font(.system(size: 20, weight: .bold, design: .rounded))
            .foregroundStyle(tint)
            .padding(.horizontal, 18).padding(.top, 17)
            Text(destination.explanation)
                .font(.system(size: 11))
                .foregroundStyle(tint.opacity(0.90))
                .lineLimit(2)
                .frame(height: 29, alignment: .topLeading)
                .padding(.horizontal, 18).padding(.top, 5)
            TaskListView(store: store, destination: destination, tint: tint, onEdit: onEdit)
                .padding(.horizontal, 10).padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(fill.opacity(colorScheme == .dark ? 0.12 : 0.22), in: RoundedRectangle(cornerRadius: 15))
        .overlay(RoundedRectangle(cornerRadius: 15).strokeBorder(tint.opacity(targeted ? 0.58 : 0), lineWidth: 2))
        .contentShape(RoundedRectangle(cornerRadius: 15))
        .dropDestination(for: String.self) { values, _ in
            guard let string = values.first, let id = UUID(uuidString: string) else { return false }
            return store.reorder(id, before: nil, in: destination)
        } isTargeted: { targeted = $0 }
    }
}

struct TaskListView: View {
    @ObservedObject var store: BoardStore
    let destination: TaskDestination
    let tint: Color
    var onEdit: (TaskItem) -> Void
    @ViewState private var targeted = false

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(store.tasks(in: destination), id: \.id) { task in
                    TaskRow(store: store, task: task, tint: tint, onEdit: { onEdit(task) })
                    Divider().padding(.horizontal, 6)
                }
                Spacer(minLength: 35)
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 15)
        }
        .scrollIndicators(.automatic)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(tint.opacity(targeted ? 0.12 : 0), in: RoundedRectangle(cornerRadius: 9))
        .contentShape(Rectangle())
        .dropDestination(for: String.self) { values, _ in
            guard let string = values.first, let id = UUID(uuidString: string) else { return false }
            return store.reorder(id, before: nil, in: destination)
        } isTargeted: { targeted = $0 }
        .accessibilityLabel("\(destination.displayName) task list")
    }
}

struct TaskRow: View {
    @ObservedObject var store: BoardStore
    let task: TaskItem
    let tint: Color
    var onEdit: () -> Void
    @ViewState private var targeted = false

    var body: some View {
        HStack(spacing: 9) {
            Button { store.complete(task.id) } label: {
                Image(systemName: "circle").font(.system(size: 17, weight: .light))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Complete task")
            .accessibilityLabel("Complete \(task.title)")
            Text(task.title).font(.system(size: 13))
                .foregroundStyle(.primary)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 10)
            Menu {
                actions
            } label: {
                Image(systemName: "ellipsis").font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary).frame(width: 23, height: 27)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .accessibilityLabel("Options for \(task.title)")
            .help("Task options")
        }
        .frame(minHeight: 41)
        .padding(.horizontal, 6)
        .contentShape(Rectangle())
        .background(tint.opacity(targeted ? 0.12 : 0), in: RoundedRectangle(cornerRadius: 7))
        .overlay(alignment: .top) {
            if targeted { Rectangle().fill(tint.opacity(0.65)).frame(height: 2) }
        }
        .contextMenu { actions }
        .onDrag {
            NSItemProvider(object: task.id.uuidString as NSString)
        } preview: {
            Text(task.title).font(.system(size: 13)).padding(10)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 9))
        }
        .dropDestination(for: String.self) { values, _ in
            guard let string = values.first, let id = UUID(uuidString: string) else { return false }
            return store.reorder(id, before: task.id, in: task.destination)
        } isTargeted: { targeted = $0 }
    }

    @ViewBuilder
    private var actions: some View {
        Button("Edit title…", systemImage: "pencil", action: onEdit)
        Divider()
        ForEach(TaskDestination.allCases.filter { $0 != task.destination }, id: \.self) { destination in
            Button(destination == .inbox ? "Return to Inbox" : "Move to \(destination.displayName)", systemImage: destination.symbol) {
                store.move(task.id, to: destination)
            }
        }
        Divider()
        Button("Complete", systemImage: "checkmark.circle") { store.complete(task.id) }
        Button("Move to Trash", systemImage: "trash") { store.trash(task.id) }
    }
}

enum HistoryKind: String, Identifiable {
    case completed, trash
    var id: String { rawValue }
    var title: String { self == .completed ? "Completed" : "Trash" }
    var lifecycle: TaskLifecycle { self == .completed ? .completed : .trashed }
}

struct HistoryView: View {
    @ObservedObject var store: BoardStore
    let kind: HistoryKind
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Text(kind.title).font(.system(size: 20, weight: .bold, design: .rounded))
                Spacer()
                Button("Done") { dismiss() }.keyboardShortcut(.cancelAction)
            }
            Text("Restore a task to its previous location.").font(.system(size: 12)).foregroundStyle(.secondary)
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(store.history(kind.lifecycle), id: \.id) { task in
                        HStack(spacing: 10) {
                            Image(systemName: kind == .completed ? "checkmark.circle" : "trash")
                                .foregroundStyle(.secondary)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(task.title).font(.system(size: 13))
                                Text(task.destination.displayName).font(.system(size: 10)).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Restore") { store.restore(task.id) }.font(.system(size: 11))
                        }
                        .padding(.vertical, 11)
                        Divider()
                    }
                }
            }
        }
        .padding(24).frame(width: 430, height: 370)
    }
}

struct RenameTaskView: View {
    @ObservedObject var store: BoardStore
    let task: TaskItem
    @ViewState private var title = ""
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 17) {
            Text("Edit task").font(.system(size: 20, weight: .bold, design: .rounded))
            TextField("Task title", text: $title).textFieldStyle(.roundedBorder).focused($focused)
                .onSubmit(save)
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Save", action: save).keyboardShortcut(.defaultAction)
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24).frame(width: 390)
        .onAppear { title = task.title; focused = true }
    }

    private func save() { if store.rename(task.id, to: title) { dismiss() } }
}
