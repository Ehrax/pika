import Foundation

struct AppEnvironment: Equatable {
    static let environmentNameInfoDictionaryKey = "BILLBI_ENVIRONMENT_NAME"
    static let cloudKitContainerIdentifierInfoDictionaryKey = "BILLBI_CLOUDKIT_CONTAINER_IDENTIFIER"

    static let development = AppEnvironment(
        name: "dev",
        cloudKitContainerIdentifier: "iCloud.ehrax.dev.billbi.dev"
    )
    static let production = AppEnvironment(
        name: "prod",
        cloudKitContainerIdentifier: "iCloud.ehrax.dev.billbi"
    )

    let name: String
    let cloudKitContainerIdentifier: String

    static func resolve(
        infoDictionary: [String: Any] = Bundle.main.infoDictionary ?? [:]
    ) throws -> AppEnvironment {
        let name = try resolvedString(
            for: environmentNameInfoDictionaryKey,
            in: infoDictionary
        )
        let cloudKitContainerIdentifier = try resolvedString(
            for: cloudKitContainerIdentifierInfoDictionaryKey,
            in: infoDictionary
        )

        return AppEnvironment(
            name: name,
            cloudKitContainerIdentifier: cloudKitContainerIdentifier
        )
    }

    private static func resolvedString(
        for key: String,
        in infoDictionary: [String: Any]
    ) throws -> String {
        guard let value = infoDictionary[key] as? String else {
            throw ResolveError.missingInfoDictionaryValue(key: key)
        }

        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedValue.isEmpty == false else {
            throw ResolveError.emptyInfoDictionaryValue(key: key)
        }
        guard trimmedValue.contains("$(") == false else {
            throw ResolveError.unresolvedBuildSetting(key: key, value: trimmedValue)
        }

        return trimmedValue
    }
}

extension AppEnvironment {
    enum ResolveError: Error, Equatable, CustomStringConvertible {
        case missingInfoDictionaryValue(key: String)
        case emptyInfoDictionaryValue(key: String)
        case unresolvedBuildSetting(key: String, value: String)

        var description: String {
            switch self {
            case let .missingInfoDictionaryValue(key):
                "Missing Info.plist value for \(key)."
            case let .emptyInfoDictionaryValue(key):
                "Empty Info.plist value for \(key)."
            case let .unresolvedBuildSetting(key, value):
                "Unresolved build setting for \(key): \(value)."
            }
        }
    }
}
