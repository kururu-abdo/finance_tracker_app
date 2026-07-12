//
//  RootView.swift
//  FinanceTracker
//

import SwiftUI
import SwiftData

struct RootView: View {
    @EnvironmentObject private var authService: FirebaseAuthService
    @EnvironmentObject private var biometricService: BiometricAuthService
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    private var container: ModelContainer { modelContext.container }

    var body: some View {
        Group {
            if !authService.isSignedIn {
                LoginView()
            } else {
                TabView {
                    NavigationStack {
                        DashboardView(container: container)
                    }
                    .tabItem { Label("Dashboard", systemImage: "chart.pie.fill") }

                    NavigationStack {
                        TransactionListView(container: container)
                    }
                    .tabItem { Label("Transactions", systemImage: "list.bullet") }

                    NavigationStack {
                        SettingsView()
                    }
                    .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                }
            }
        }
        .fullScreenCover(isPresented: .constant(authService.isSignedIn && !biometricService.isUnlocked)) {
            AuthGateView()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                biometricService.lockOnBackground()
            }
        }
        .task {
            await SyncService.shared.syncNow()
        }
    }
}
