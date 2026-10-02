import SwiftUI

@main struct PhotoCleanerApp: App {
    @StateObject private var model = AppModel()
    @Environment(\.scenePhase) private var scenePhase
    var body: some Scene {
        WindowGroup {
            HomeView().environmentObject(model)
                .task { model.refresh() }
                .onChange(of: scenePhase) { phase in
                    if phase == .active { model.refresh() }
                    if phase == .background { model.stop() }
                }
                .alert("Hinweis", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) {
                    Button("OK") { model.error = nil }
                } message: { Text(model.error ?? "") }
        }
    }
}
