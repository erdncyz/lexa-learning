import SwiftUI

struct RootView: View {
    let app: AppState

    var body: some View {
        ZStack {
            switch app.phase {
            case .launching:
                PastelBackground()
            case .landing:
                LandingView(app: app)
                    .transition(.opacity)
            case .onboarding:
                OnboardingView(app: app)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            case .ready:
                ReadyView(app: app)
                    .transition(.opacity)
            case .main:
                MainTabView(app: app)
                    .transition(.opacity)
            }
        }
        .animation(LexaMotion.base, value: app.phase)
        .tint(LexaColor.accent)
        .overlay(alignment: .bottom) { ToastHost(app: app) }
    }
}

struct MainTabView: View {
    @Bindable var app: AppState

    var body: some View {
        TabView(selection: $app.selectedTab) {
            TodayView(app: app)
                .tabItem { Label(MainTab.today.title, systemImage: MainTab.today.symbol) }
                .tag(MainTab.today)
            ExploreView(app: app)
                .tabItem { Label(MainTab.explore.title, systemImage: MainTab.explore.symbol) }
                .tag(MainTab.explore)
            PracticeView(app: app)
                .tabItem { Label(MainTab.practice.title, systemImage: MainTab.practice.symbol) }
                .tag(MainTab.practice)
            WidgetsView(app: app)
                .tabItem { Label(MainTab.widgets.title, systemImage: MainTab.widgets.symbol) }
                .tag(MainTab.widgets)
            ProfileView(app: app)
                .tabItem { Label(MainTab.profile.title, systemImage: MainTab.profile.symbol) }
                .tag(MainTab.profile)
        }
    }
}

/// Toast'ı 2 sn gösterip kendiliğinden kapatır.
private struct ToastHost: View {
    @Bindable var app: AppState

    var body: some View {
        ZStack {
            if let toast = app.toast {
                ToastView(message: toast)
                    .padding(.horizontal, LexaSpacing.gutter)
                    .padding(.bottom, 96)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .id(toast.id)
                    .task(id: toast.id) {
                        try? await Task.sleep(for: .seconds(2))
                        if app.toast?.id == toast.id { app.toast = nil }
                    }
                    .onTapGesture { app.toast = nil }
            }
        }
        .animation(LexaMotion.spring, value: app.toast)
    }
}
