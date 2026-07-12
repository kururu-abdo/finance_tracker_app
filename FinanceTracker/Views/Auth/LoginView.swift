//
//  LoginView.swift
//  FinanceTracker
//

import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var authService: FirebaseAuthService

    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false
    @State private var errorMessage: String?
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Spacer()

                Image(systemName: "chart.pie.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.blue)

                Text("FinanceTracker")
                    .font(.largeTitle.bold())

                VStack(spacing: 12) {
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textFieldStyle(.roundedBorder)

                    SecureField("Password", text: $password)
                        .textContentType(isSignUp ? .newPassword : .password)
                        .textFieldStyle(.roundedBorder)
                }
                .padding(.horizontal)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                Button {
                    Task { await submit() }
                } label: {
                    if isLoading {
                        ProgressView()
                    } else {
                        Text(isSignUp ? "Create Account" : "Sign In")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.horizontal)
                .disabled(email.isEmpty || password.isEmpty || isLoading)

                Button(isSignUp ? "Already have an account? Sign In" : "New here? Create an account") {
                    isSignUp.toggle()
                }
                .font(.footnote)

                Divider().padding(.horizontal, 40)

                // Offline-first: a guest can use the entire app — local
                // persistence works with zero account. This is the
                // strongest demonstration that Firebase is optional
                // infrastructure, not a hard dependency.
                Button {
                    Task { await continueAsGuest() }
                } label: {
                    Label("Continue Without Account", systemImage: "wifi.slash")
                }
                .font(.footnote)

                Spacer()
                Spacer()
            }
            .padding()
        }
    }

    private func submit() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            if isSignUp {
                try await authService.signUp(email: email, password: password)
            } else {
                try await authService.signIn(email: email, password: password)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func continueAsGuest() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            try await authService.continueAsGuest()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
