//
//  AuthGateView.swift
//  FinanceTracker
//
//  Full-screen cover shown whenever the app is locked: on cold launch
//  and whenever it returns from background. Prevents financial data
//  from ever being visible without FaceID/TouchID/passcode.
//

import SwiftUI

struct AuthGateView: View {
    @EnvironmentObject private var biometricService: BiometricAuthService

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: biometricIconName)
                .font(.system(size: 56))
                .foregroundStyle(.blue)

            Text("FinanceTracker Locked")
                .font(.title2.bold())

            if let error = biometricService.lastError {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Button {
                Task { await biometricService.authenticate() }
            } label: {
                Label("Unlock", systemImage: biometricIconName)
                    .frame(maxWidth: 240)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.thinMaterial)
        .task {
            // Prompt immediately on appearance so the user isn't stuck
            // staring at a locked screen needing an extra tap.
            await biometricService.authenticate()
        }
    }

    private var biometricIconName: String {
        switch biometricService.availableBiometricType {
        case .faceID: return "faceid"
        case .touchID: return "touchid"
        case .opticID: return "opticid"
        case .none: return "lock.fill"
        }
    }
}
