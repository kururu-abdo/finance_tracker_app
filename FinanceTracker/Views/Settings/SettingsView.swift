//
//  SettingsView.swift
//  FinanceTracker
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var authService: FirebaseAuthService
    @EnvironmentObject private var biometricService: BiometricAuthService
    @ObservedObject private var syncService = SyncService.shared

    var body: some View {
        Form {
            Section("Security") {
                Toggle(isOn: $biometricService.biometricLockEnabled) {
                    Label(biometricLabel, systemImage: "faceid")
                }
            }

            Section("Sync") {
                HStack {
                    Text("Status")
                    Spacer()
                    if syncService.isSyncing {
                        ProgressView()
                    } else if let lastSyncedAt = syncService.lastSyncedAt {
                        Text(lastSyncedAt, format: .relative(presentation: .named))
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Never synced")
                            .foregroundStyle(.secondary)
                    }
                }
                if let error = syncService.lastSyncError {
                    Text(error).font(.footnote).foregroundStyle(.red)
                }
                Button("Sync Now") {
                    Task { await syncService.syncNow() }
                }
            }

            Section {
                Button("Sign Out", role: .destructive) {
                    try? authService.signOut()
                }
            }
        }
        .navigationTitle("Settings")
    }

    private var biometricLabel: String {
        switch biometricService.availableBiometricType {
        case .faceID: return "Require Face ID"
        case .touchID: return "Require Touch ID"
        case .opticID: return "Require Optic ID"
        case .none: return "Require Passcode Lock"
        }
    }
}
