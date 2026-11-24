import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if appState.settings.hasCompletedOnboarding {
                MainTabView()
                    .transition(.opacity)
            } else {
                OnboardingFlow()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: appState.settings.hasCompletedOnboarding)
        // Belt and braces alongside SceneDelegate: both calls are idempotent.
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active: appState.sceneDidBecomeActive()
            case .inactive: appState.sceneWillResignActive()
            case .background: appState.sceneDidEnterBackground()
            @unknown default: break
            }
        }
    }
}

struct MainTabView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppServices.self) private var services
    @Query(sort: \JournalEntry.createdAt, order: .reverse) private var entries: [JournalEntry]
    @State private var showModalCheckIn = false

    var body: some View {
        @Bindable var appState = appState
        TabView(selection: $appState.selectedTab) {
            Tab("Home", systemImage: "house", value: AppTab.home) { HomeView() }
            // Calendar = visits + mood + the note for each day (replaces Visits and Journal).
            Tab("Calendar", systemImage: "calendar", value: AppTab.calendar) { CalendarView() }
            Tab("Meds", systemImage: "pills", value: AppTab.prescriptions) {
                NavigationStack { PrescriptionsView() }
            }
            Tab("Messages", systemImage: "bubble.left.and.bubble.right", value: AppTab.messages) { MessagesView() }
            Tab("Profile", systemImage: "person.crop.circle", value: AppTab.profile) { ProfileView() }
        }
        // Crisis entry one tap away on every tab: a floating lifebuoy above the tab bar.
        // VERIFY on device: bottom offset clears the iOS 26 floating tab bar.
        .overlay(alignment: .bottomTrailing) {
            if appState.floatingHelpHiders == 0 {
                FloatingHelpButton()
                    .padding(.trailing, Spacing.screen)
                    .padding(.bottom, 72)
                    .transition(.opacity)
            }
        }
        .task { appState.registerLaunch() }
        .sheet(isPresented: $showModalCheckIn) {
            CheckInView(entry: nil, initialMood: nil)
        }
        .onAppear(perform: presentModalCheckInIfNeeded)
    }

    /// Research variant only (`moodCheckInStyle == .modal`). Shown at most once a day,
    /// and always dismissible. The default is the non-blocking Home card.
    private func presentModalCheckInIfNeeded() {
        let settings = appState.settings
        guard settings.moodCheckInStyle == .modal else { return }
        let calendar = Calendar.clinic
        let checkedInToday = entries.contains { $0.isCheckIn && calendar.isDateInToday($0.createdAt) }
        let shownToday = settings.checkInModalShownOn.map(calendar.isDateInToday) ?? false
        guard !checkedInToday, !shownToday else { return }
        appState.settings.checkInModalShownOn = .now
        showModalCheckIn = true
    }
}

#Preview("Main") {
    MainTabView().previewEnvironment()
}
