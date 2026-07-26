//
//  AppLockView.swift
//  iExpense
//

import SwiftUI

struct AppLockView: View {
    @ObservedObject var lockService: BiometricLockService
    @State private var isAuthenticating = false
    @State private var appeared = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [InpensoTheme.ink, InpensoTheme.inkSoft, InpensoTheme.tide.opacity(0.9)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()

                VStack(spacing: 12) {
                    Text("Inpenso")
                        .font(InpensoTheme.brandFont(44, weight: .bold))
                        .foregroundStyle(.white)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 12)

                    Text("Your ledger is locked")
                        .font(InpensoTheme.body(16))
                        .foregroundStyle(.white.opacity(0.75))
                }

                Image(systemName: lockService.biometrySymbol)
                    .font(.system(size: 56, weight: .medium))
                    .foregroundStyle(InpensoTheme.seafoam)
                    .padding(.vertical, 8)

                if let message = lockService.lastErrorMessage {
                    Text(message)
                        .font(InpensoTheme.label(13))
                        .foregroundStyle(InpensoTheme.copperSoft)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                Button {
                    Task { await unlock() }
                } label: {
                    HStack(spacing: 8) {
                        if isAuthenticating {
                            ProgressView().tint(.white)
                        }
                        Text("Unlock with \(lockService.biometryLabel)")
                    }
                    .font(InpensoTheme.label(16, weight: .bold))
                    .foregroundStyle(InpensoTheme.ink)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(.white)
                    )
                }
                .disabled(isAuthenticating)
                .padding(.horizontal, 28)

                Spacer()
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                appeared = true
            }
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
