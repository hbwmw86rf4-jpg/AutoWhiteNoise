import AppIntents
import NoiseCore

/// How a preset appears inside Shortcuts: a pickable value with a name.
struct PresetEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Preset"
    static var defaultQuery = PresetQuery()

    var id: UUID
    var name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }

    init(_ preset: Preset) {
        id = preset.id
        name = preset.name
    }
}

/// Lets Shortcuts list presets, resolve them by id, and match "Rain" typed or
/// spoken to Siri.
struct PresetQuery: EntityStringQuery {
    @Dependency var controller: PlayerController

    @MainActor
    func entities(for identifiers: [UUID]) async throws -> [PresetEntity] {
        controller.presets.filter { identifiers.contains($0.id) }.map(PresetEntity.init)
    }

    @MainActor
    func suggestedEntities() async throws -> [PresetEntity] {
        controller.presets.map(PresetEntity.init)
    }

    @MainActor
    func entities(matching string: String) async throws -> [PresetEntity] {
        let needle = Preset.normalize(string)
        return controller.presets
            .filter { Preset.normalize($0.name).contains(needle) }
            .map(PresetEntity.init)
    }
}
