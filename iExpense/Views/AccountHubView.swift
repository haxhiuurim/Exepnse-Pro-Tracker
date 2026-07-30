//
//  AccountHubView.swift
//  iExpense
//
//  More → Account — sign in, sync, sign out.
//

import SwiftUI

struct AccountHubView: View {
    @ObservedObject private var auth = AuthSession.shared
    @State private var showAuth = false
    @State private var isSyncing = false
    @State private var statusMessage: String?

    var body: some View {
        ZStack {
            AtmosphereBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    hero

                    if auth.isLoggedIn {
                        signedInPanel
                    } else {
                        signedOutPanel
                    }

                    if let statusMessage {
                        Text(statusMessage)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(InpensoTheme.muted)
                            .padding(.horizontal, 4)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, InpensoTheme.Space.bottomClearance)
            }
        }
        .navigationTitle("Account")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(InpensoTheme.foam, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .sheet(isPresented: $showAuth) {
            AccountAuthView()
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ACCOUNT")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .tracking(0.9)
                .foregroundStyle(.white.opacity(0.55))

            Text(auth.isLoggedIn ? "You’re signed in" : "Sign in to sync")
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text(auth.isLoggedIn
                 ? "Your ledger syncs to \(AppBrand.name) servers. Trips use this account."
                 : "Create an account to back up data and unlock Trips. Guest data stays on this device only.")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.72))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BankingHeroBackground())
    }

    private var signedInPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(auth.displayName.isEmpty ? "Signed in" : auth.displayName)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(InpensoTheme.ink)
                if !auth.email.isEmpty {
                    Text(auth.email)
                        .font(.system(size: 13))
                        .foregroundStyle(InpensoTheme.muted)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(InpensoTheme.panelFill)
            )

            Button {
                Task { await syncNow() }
            } label: {
                Group {
                    if isSyncing {
                        ProgressView()
                    } else {
                        Text("Sync now")
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(InpensoPrimaryButtonStyle(enabled: !isSyncing))
            .disabled(isSyncing)

            Button(role: .destructive) {
                Task {
                    await SharedTripAPI.shared.logout()
                    statusMessage = "Signed out."
                }
            } label: {
                Text("Sign out")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(InpensoSecondaryButtonStyle())
        }
    }

    private var signedOutPanel: some View {
        VStack(spacing: 10) {
            Button {
                showAuth = true
            } label: {
                Text("Sign in or create account")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(InpensoPrimaryButtonStyle())

            Text("Without an account, Trips stay locked and data isn’t backed up.")
                .font(.system(size: 13))
                .foregroundStyle(InpensoTheme.muted)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func syncNow() async {
        isSyncing = true
        defer { isSyncing = false }
        await CloudSyncService.shared.pushAll()
        await CloudSyncService.shared.pullIfAvailable()
        statusMessage = "Synced."
        HapticFeedback.success()
    }
}
