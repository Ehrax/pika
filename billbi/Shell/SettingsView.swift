import SwiftUI

struct SettingsView: View {
    let profile: BusinessProfileProjection

    var body: some View {
        SettingsFeatureView(profile: profile)
    }
}
