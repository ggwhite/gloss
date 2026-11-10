import SwiftUI

struct GlossApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        MenuBarExtra {
            PopoverRoot()
                .environmentObject(delegate.model)
                .environmentObject(delegate.router)
                .popoverChrome()
                .trackWindowVisibility()
                .preferredColorScheme(.dark)
                .tint(Theme.accent)
        } label: {
            MenuBarLabel(model: delegate.model)
        }
        .menuBarExtraStyle(.window)
    }
}
