import SwiftUI
import NoiseCore

struct SchedulesView: View {
    @Environment(PlayerController.self) private var controller
    @Environment(AppServices.self) private var services
    @State private var editing: ScheduleRule?

    var body: some View {
        List {
            Section {
                #if os(macOS)
                Label("Schedules run any time this Mac is awake and the app is open (it can stay in the menu bar).", systemImage: "checkmark.circle")
                #else
                Label("On iPhone and iPad, schedules only fire while the app is open or in appliance mode. To start with the screen locked, mirror the schedule as a Shortcuts automation: see Automations.", systemImage: "info.circle")
                #endif
            }
            .font(.footnote)
            .foregroundStyle(.secondary)

            ForEach(controller.schedules) { rule in
                Button { editing = rule } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(rule.name).font(.headline)
                            Text("\(rule.time.formatted) · \(rule.weekdaysDescription) · \(actionText(rule))")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { rule.enabled },
                            set: { on in
                                if let i = controller.schedules.firstIndex(where: { $0.id == rule.id }) {
                                    controller.schedules[i].enabled = on
                                }
                            })).labelsHidden()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .onDelete { controller.schedules.remove(atOffsets: $0) }

            if let next = ScheduleEngine.nextFire(controller.schedules, after: Date()) {
                Section { Text("Next: \(next.0.name) at \(next.1, format: .dateTime.weekday(.wide).hour().minute())") }
            }
        }
        .navigationTitle("Schedules")
        .toolbar {
            ToolbarItem {
                Button {
                    editing = ScheduleRule(name: "Morning", time: HourMinute(hour: 5, minute: 30),
                                           action: .start(presetID: controller.presets.first?.id ?? UUID()))
                } label: { Label("Add", systemImage: "plus") }
            }
        }
        .sheet(item: $editing) { rule in
            ScheduleEditorView(rule: rule) { saved in
                if let i = controller.schedules.firstIndex(where: { $0.id == saved.id }) {
                    controller.schedules[i] = saved
                } else {
                    controller.schedules.append(saved)
                }
            }
            #if os(macOS)
            .frame(minWidth: 420, minHeight: 420)
            #endif
        }
    }

    private func actionText(_ rule: ScheduleRule) -> String {
        switch rule.action {
        case .start(let id): return "start \(controller.preset(id: id)?.name ?? "?")"
        case .stop: return "stop"
        }
    }
}

struct ScheduleEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(PlayerController.self) private var controller
    @State var rule: ScheduleRule
    let onSave: (ScheduleRule) -> Void
    @State private var time: Date
    @State private var isStart: Bool
    @State private var presetID: UUID

    init(rule: ScheduleRule, onSave: @escaping (ScheduleRule) -> Void) {
        _rule = State(initialValue: rule)
        self.onSave = onSave
        let cal = Calendar.current
        _time = State(initialValue: cal.date(bySettingHour: rule.time.hour, minute: rule.time.minute, second: 0, of: Date()) ?? Date())
        if case .start(let id) = rule.action {
            _isStart = State(initialValue: true); _presetID = State(initialValue: id)
        } else {
            _isStart = State(initialValue: false); _presetID = State(initialValue: UUID())
        }
    }

    private let dayNames = ["S", "M", "T", "W", "T", "F", "S"]

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $rule.name)
                DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute)
                Section("Days") {
                    HStack {
                        ForEach(1...7, id: \.self) { day in
                            let on = rule.weekdays.isEmpty || rule.weekdays.contains(day)
                            Button(dayNames[day - 1]) {
                                var days = rule.weekdays.isEmpty ? Set(1...7) : rule.weekdays
                                if days.contains(day) { days.remove(day) } else { days.insert(day) }
                                rule.weekdays = days.count == 7 ? [] : days
                            }
                            .buttonStyle(.bordered)
                            .tint(on ? Color.accentColor : .gray)
                        }
                    }
                    Text(rule.weekdaysDescription).font(.caption).foregroundStyle(.secondary)
                }
                Section("Action") {
                    Picker("Do", selection: $isStart) {
                        Text("Start a preset").tag(true)
                        Text("Stop").tag(false)
                    }
                    if isStart {
                        Picker("Preset", selection: $presetID) {
                            ForEach(controller.presets) { Text($0.name).tag($0.id) }
                        }
                    }
                }
            }
            .navigationTitle("Schedule")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var r = rule
                        r.time = HourMinute(date: time)
                        r.action = isStart ? .start(presetID: presetID) : .stop
                        onSave(r)
                        dismiss()
                    }
                    .disabled(rule.name.isEmpty || (isStart && controller.preset(id: presetID) == nil))
                }
            }
        }
    }
}
