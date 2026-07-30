//
//  AccountBannedView.swift
//  iExpense
//
//  Full-screen lock when the signed-in account is banned by an admin.
//

import SwiftUI

struct AccountBannedView: View {
    @ObservedObject var remote: RemoteConfigService
    @ObservedObject private var auth = AuthSession.shared
    @State private var isChecking = false
    @State private var checkMessage: String?

    var body: some View {
        ZStack {
            AtmosphereBackground()

            VStack(alignment: .leading, spacing: 20) {
                Spacer()

                Text(AppBrand.name)
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundStyle(InpensoTheme.tide)

                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(InpensoTheme.danger)
                    .frame(width: 64, height: 64)
                    .background(InpensoTheme.danger.opacity(0.12), in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                Text("Account suspended")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(InpensoTheme.ink)

                Text(remote.bannedMessage)
                    .font(.system(size: 16))
                    .foregroundStyle(InpensoTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)

                if !auth.email.isEmpty {
                    Text(auth.email)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(InpensoTheme.ink)
                        .padding(.top, 4)
                }

                if let checkMessage {
                    Text(checkMessage)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(InpensoTheme.danger)
                }

                Button {
                    Task { await checkAgain() }
                } label: {
                    Group {
                        if isChecking {
                            ProgressView().tint(.white)
                        } else {
                            Text("Try again")
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(InpensoPrimaryButtonStyle())
                .disabled(isChecking)

                Button {
                    if let url = URL(string: "mailto:\(remote.config.supportEmail)") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Text("Contact support")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(InpensoSecondaryButtonStyle())

                Button {
                    Task {
                        await SharedTripAPI.shared.logout()
                        remote.clearAccountBan()
                    }
                } label: {
                    Text("Sign out")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(InpensoSecondaryButtonStyle())

                Spacer()
            }
            .padding(20)
        }
        .interactiveDismissDisabled()
        .task {
            // Re-check on appear (covers admin unban + app reopen).
            await checkAgain()
        }
    }

    private func checkAgain() async {
        isChecking = true
        checkMessage = nil
        defer { isChecking = false }

        if !SharedTripAPI.shared.isLoggedIn {
            // No session left to re-verify — unlock so they can sign in again.
            remote.clearAccountBan()
            return
        }

        await remote.refresh()
        if remote.isAccountBanned {
            checkMessage = "This account is still suspended."
        }
    }
}
