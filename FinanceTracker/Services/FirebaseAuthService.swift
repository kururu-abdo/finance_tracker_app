//
//  FirebaseAuthService.swift
//  FinanceTracker
//
//  Firebase is used ONLY for identity + as a remote sync backend.
//  It is never on the critical path for reading/writing a transaction —
//  the app must be 100% usable with airplane mode on.
//
//  Requires: FirebaseAuth, FirebaseFirestore (Swift Package Manager)
//  and a GoogleService-Info.plist added to the app target.
//

import Foundation
import FirebaseAuth
import FirebaseCore
import Combine

enum AuthError: LocalizedError {
    case notAuthenticated
    case invalidCredentials
    case underlying(Error)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated: return "You're not signed in."
        case .invalidCredentials: return "Invalid email or password."
        case .underlying(let error): return error.localizedDescription
        }
    }
}


final class FirebaseAuthService: ObservableObject {
    static let shared = FirebaseAuthService()

    @Published private(set) var currentUserID: String?
    @Published private(set) var isSignedIn: Bool = false

    private var authListenerHandle: AuthStateDidChangeListenerHandle?

    private init() {
        authListenerHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.currentUserID = user?.uid
                self?.isSignedIn = user != nil
            }
        }
    }

    deinit {
        if let handle = authListenerHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }

    func signUp(email: String, password: String) async throws {
        do {
            _ = try await Auth.auth().createUser(withEmail: email, password: password)
        } catch {
            throw AuthError.underlying(error)
        }
    }

    func signIn(email: String, password: String) async throws {
        do {
            _ = try await Auth.auth().signIn(withEmail: email, password: password)
        } catch {
            throw AuthError.underlying(error)
        }
    }

    /// Anonymous auth lets the app be fully usable offline-first from
    /// first launch, with an optional later upgrade to a real account
    /// (Auth.auth().currentUser?.link(with:)) without losing sync history.
    func continueAsGuest() async throws {
        do {
            _ = try await Auth.auth().signInAnonymously()
        } catch {
            throw AuthError.underlying(error)
        }
    }

    func signOut() throws {
        do {
            try Auth.auth().signOut()
        } catch {
            throw AuthError.underlying(error)
        }
    }
}
