import Foundation
import Observation

@Observable
final class AppRouter {
    var path: [AppRoute] = []
    var sheet: SheetDestination?

    func push(_ route: AppRoute) {
        path.append(route)
    }

    func present(sheet destination: SheetDestination) {
        sheet = destination
    }

    func dismissSheet() {
        sheet = nil
    }
}
