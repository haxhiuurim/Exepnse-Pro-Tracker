//
//  AppLockView.swift
//  iExpense
//

import SwiftUI

struct AppLockView: View {
    @ObservedObject var lockService: BiometricLockService
    @State private var isAuthenticating = false

    var body: some View {
        ZStack {
            AtmosphereBackground()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: InpensoTheme.Space.md) {
                    Text("Inpenso")
                        .font(InpensoTheme.brandFont(32, weight: .bold))
                        .foregroundStyle(InpensoTheme.ink)

                    Text("Locked")
                        .font(InpensoTheme.body(16))
                        .foregroundStyle(InpensoTheme.muted)
                }

                Image(systemName: lockService.biometrySymbol)
                    .font(.system(size: 48, weight: .regular))
                    .foregroundStyle(InpensoTheme.ink)
                    .padding(.top, InpensoTheme.Space.section)
                    .padding(.bottom, InpensoTheme.Space.xl)

                if let message = lockService.lastErrorMessage {
                    Text(message)
                        .font(InpensoTheme.label(13))
                        .foregroundStyle(InpensoTheme.danger)
                        .multilineTextAlignment(.center)
                        .inpensoScreenPadding()
                        .padding(.bottom, InpensoTheme.Space.md)
                }

                Button {
                    Task { await unlock() }
                } label: {
                    HStack(spacing: InpensoTheme.Space.xs) {
                        if isAuthenticating {
                            ProgressView()
                                .tint(.white)
                        }
                        Text("Unlock with \(lockService.biometryLabel)")
                    }
                }
                .buttonStyle(InpensoPrimaryButtonStyle(tint: InpensoTheme.copper))
                .disabled(isAuthenticating)
                .inpensoScreenPadding()

                Spacer()
                Spacer()
            }
        }
        .onAppear {
            Task { await unlock() }
        }
    }

    private func unlock() async {
        isAuthenticating = true
        _ = await lockService.authenticate()
        isAuthenticating = false
        if lockService.isUnlocked {
            HapticFeedback.success()
        } else {
            HapticFeedback.error()
        }
    }
}
