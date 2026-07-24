import SwiftUI

struct RootView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        TabView(selection: $viewModel.selectedTab) {
            HomeView(viewModel: viewModel)
                .tabItem { Label("Home", systemImage: "house") }
                .tag(AppTab.home)

            AssistantView(viewModel: viewModel)
                .tabItem { Label("Nori", systemImage: "sparkles") }
                .tag(AppTab.assistant)

            DayView(viewModel: viewModel)
                .tabItem { Label("My day", systemImage: "list.bullet.rectangle") }
                .tag(AppTab.day)

            SettingsView(viewModel: viewModel)
                .tabItem { Label("You", systemImage: "person.crop.circle") }
                .tag(AppTab.settings)
        }
        .tint(Color.noriMint)
        .toolbarBackground(Color.noriSurface, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarColorScheme(.dark, for: .tabBar)
        .preferredColorScheme(.dark)
        .alert("Nori couldn’t complete that", isPresented: Binding(
            get: { viewModel.activeError != nil },
            set: { if !$0 { viewModel.activeError = nil } }
        )) {
            Button("OK", role: .cancel) { viewModel.activeError = nil }
        } message: {
            Text(viewModel.activeError ?? "Please try again.")
        }
    }
}
