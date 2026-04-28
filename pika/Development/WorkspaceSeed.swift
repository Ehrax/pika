import Foundation

enum WorkspaceSeed: String, CaseIterable, Equatable {
    case empty
    case sample
    case bikeparkThunersee

    nonisolated static let namedArgument = "--pika-workspace-seed"
    nonisolated static let environmentKey = "PIKA_WORKSPACE_SEED"
    nonisolated static let legacyEnvironmentKey = "PIKA_SEED_WORKSPACE"

    nonisolated static let emptyArgument = "--empty"
    nonisolated static let sampleArgument = "--pika-seed-workspace"
    nonisolated static let bikeparkArgument = "--pika-seed-bikepark-thunersee"

    nonisolated init?(seedValue: String) {
        switch seedValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "empty":
            self = .empty
        case "sample", "demo", "seeded", "1", "true", "yes":
            self = .sample
        case "bikepark-thunersee", "bikepark", "bikeparkthunersee":
            self = .bikeparkThunersee
        default:
            return nil
        }
    }

    nonisolated static func resolve(arguments: [String], environment: [String: String]) -> WorkspaceSeed {
        if arguments.contains(emptyArgument) {
            return .empty
        }

        if let argumentSeed = seedValue(after: namedArgument, in: arguments).flatMap(WorkspaceSeed.init(seedValue:)) {
            return argumentSeed
        }

        if arguments.contains(bikeparkArgument) {
            return .bikeparkThunersee
        }

        if arguments.contains(sampleArgument) {
            return .sample
        }

        if let environmentSeed = environment[environmentKey].flatMap(WorkspaceSeed.init(seedValue:)) {
            return environmentSeed
        }

        if let legacyEnvironmentSeed = environment[legacyEnvironmentKey].flatMap(WorkspaceSeed.init(seedValue:)) {
            return legacyEnvironmentSeed
        }

        return .empty
    }

    var initialWorkspace: WorkspaceSnapshot {
        switch self {
        case .empty:
            .empty
#if DEBUG
        case .sample:
            WorkspaceSeedLibrary.demoWorkspace
        case .bikeparkThunersee:
            WorkspaceSeedLibrary.bikeparkThunersee
#else
        case .sample, .bikeparkThunersee:
            .empty
#endif
        }
    }

    nonisolated private static func seedValue(after argument: String, in arguments: [String]) -> String? {
        guard let argumentIndex = arguments.firstIndex(of: argument) else {
            return nil
        }

        let valueIndex = arguments.index(after: argumentIndex)
        guard arguments.indices.contains(valueIndex) else {
            return nil
        }

        return arguments[valueIndex]
    }
}
