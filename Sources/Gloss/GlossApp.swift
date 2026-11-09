import SwiftUI

struct GlossApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        MenuBarExtra {
            QuizView()
                .environmentObject(delegate.model)
                .environmentObject(delegate.router)
        } label: {
            MenuBarLabel(model: delegate.model)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(settings: delegate.settings)
                .environmentObject(delegate.model)
        }
    }
}
