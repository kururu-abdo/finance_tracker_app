import SwiftUI
import SwiftData
import FirebaseCore

@main
struct FinanceTrackerApp: App {
    @StateObject private var authService = FirebaseAuthService.shared
    @StateObject private var biometricService = BiometricAuthService.shared

    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authService)
                .environmentObject(biometricService)
        }
        .modelContainer(PersistenceController.shared.container)
    }
}
