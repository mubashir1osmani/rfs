import SwiftUI

@main
struct NoriApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var viewModel = AppViewModel()

    var body: some Scene {
        WindowGroup {
            RootView(viewModel: viewModel)
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await viewModel.refreshSchedule() }
        }
        .backgroundTask(.appRefresh(ProactiveNotificationService.backgroundRefreshIdentifier)) {
            await viewModel.refreshSchedule()
        }
    }
}
