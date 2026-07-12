//
//  BiometricAuthService.swift
//  FinanceTracker
//
//  Wraps LocalAuthentication. This gates app entry AND re-locks on
//  background — money apps should never leave sensitive data visible
//  in the app switcher or after backgrounding.
//

import Foundation
import LocalAuthentication
import SwiftUI
import Combine

enum BiometricType {
    case none
    case touchID
    case faceID
    case opticID
}

final class BiometricAuthService: ObservableObject {
    static let shared = BiometricAuthService()

    @Published private(set) var isUnlocked = false
    @Published private(set) var lastError: String?

    /// Whether the user has opted into requiring biometrics at all.
    /// Persisted outside SwiftData (UserDefaults) since it's app config,
    /// not user financial data.
    @AppStorage("biometricLockEnabled") var biometricLockEnabled: Bool = true

    var availableBiometricType: BiometricType {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return .none
        }
        switch context.biometryType {
        case .faceID: return .faceID
        case .touchID: return .touchID
        case .opticID: return .opticID
        default: return .none
        }
    }

    func lock() {
        isUnlocked = false
    }

    /// Called from scenePhase .background so a snooped screenshot / app
    /// switcher preview never shows real balances.
    func lockOnBackground() {
        guard biometricLockEnabled else { return }
        isUnlocked = false
    }

    @discardableResult
    func authenticate(reason: String = "Unlock your finances") async -> Bool {
        guard biometricLockEnabled else {
            isUnlocked = true
            return true
        }

        let context = LAContext()
        context.localizedFallbackTitle = "Use Passcode"
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            lastError = error?.localizedDescription ?? "Biometrics unavailable"
            // No biometrics/passcode configured on device at all —
            // fail closed rather than silently unlocking.
            isUnlocked = false
            return false
        }

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: reason
            )
            isUnlocked = success
            lastError = nil
            return success
        } catch {
            lastError = error.localizedDescription
            isUnlocked = false
            return false
        }
    }
}
