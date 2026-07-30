//
//  AccountAuthView.swift
//  iExpense
//
//  Login / register — full-screen Obsidian + Jade banking style.
//  Present with .fullScreenCover for the intended full-bleed look; if presented
//  as a .sheet, pair with .presentationDetents([.large]) and a visible drag indicator.
//

import SwiftUI

struct AccountAuthView: View {
    enum Mode: String, CaseIterable, Identifiable {
        case login
        case register

        var id: String { rawValue }

        var title: String {
            switch self {
            case .login: return "Sign in"
            case .register: return "Create account"
            }
        }
    }

    var onSuccess: (() -> Void)?
    var showsGuestHint = false
    var initialMode: Mode = .login

    @ObservedObject private var auth = AuthSession.shared
    @State private var mode: Mode = .login
    @State private var email = ""
    @State private var password = ""
    @State private var displayName = ""
    @State private var isWorking = false
    @State private var errorMessage: String?
    @State private var showPassword = false
    @FocusState private var focusedField: Field?
    @Environment(\.dismiss) private var dismiss

    private enum Field: Hashable {
        case name, email, password
    }

    var body: some View {
        ZStack {
            BankingHeroBackground(radius: 0)
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    closeRow

                    hero

                    modeSwitcher

                    formFields

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(InpensoTheme.danger)
                            .padding(.horizontal, 4)
                    }

                    if showsGuestHint {
                        Text("Without an account, data stays only on this device and can be lost.")
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.6))
                            .padding(.horizontal, 4)
                    }

                    Button(action: submit) {
                        Group {
                            if isWorking {
                                ProgressView().tint(.white)
                            } else {
                                Text(mode == .login ? "Sign in" : "Create account")
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(InpensoPrimaryButtonStyle(enabled: canSubmit && !isWorking, tint: InpensoTheme.tide))
                    .disabled(!canSubmit || isWorking)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .navigationBarHidden(true)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focusedField = nil }
            }
        }
        .onAppear {
            mode = initialMode
            // Prefill email/name only — never password (avoids sticky autofill).
            if email.isEmpty { email = auth.email }
            if displayName.isEmpty { displayName = auth.displayName }
            password = ""
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                focusedField = mode == .register ? .name : .email
            }
        }
        .onChange(of: mode) { _, _ in
            password = ""
            errorMessage = nil
            showPassword = false
        }
    }

    private var closeRow: some View {
        HStack {
            Text(AppBrand.name)
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .tracking(1.4)
                .foregroundStyle(InpensoTheme.seafoam)

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(.white.opacity(0.14)))
            }
            .accessibilityLabel("Close")
        }
        .padding(.top, 4)
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ACCOUNT")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .tracking(0.9)
                .foregroundStyle(.white.opacity(0.55))

            Text(mode == .login ? "Welcome back" : "Create your account")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text("Trips and cloud backup need an \(AppBrand.name) account. Your ledger syncs when you’re signed in.")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.72))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 12)
        .padding(.bottom, 6)
    }

    private var modeSwitcher: some View {
        HStack(spacing: 8) {
            ForEach(Mode.allCases) { item in
                Button {
                    withAnimation(InpensoTheme.Motion.snappy) { mode = item }
                } label: {
                    Text(item.title)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(mode == item ? InpensoTheme.ink : .white.opacity(0.85))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(mode == item ? Color.white : Color.white.opacity(0.12))
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var formFields: some View {
        VStack(alignment: .leading, spacing: 14) {
            if mode == .register {
                labeledField("Display name") {
                    TextField("Your name", text: $displayName)
                        .textContentType(.name)
                        .textInputAutocapitalization(.words)
                        .focused($focusedField, equals: .name)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .email }
                }
            }

            labeledField("Email") {
                TextField("you@email.com", text: $email)
                    .textContentType(.username)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .email)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .password }
            }

            labeledField("Password") {
                HStack(spacing: 10) {
                    Group {
                        if showPassword {
                            TextField("Min. 8 characters", text: $password)
                        } else {
                            SecureField("Min. 8 characters", text: $password)
                        }
                    }
                    // Avoid .newPassword — Simulator strong-password UI blocks editing.
                    .textContentType(.oneTimeCode)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .focused($focusedField, equals: .password)
                    .submitLabel(.go)
                    .onSubmit { if canSubmit { submit() } }

                    Button {
                        showPassword.toggle()
                    } label: {
                        Image(systemName: showPassword ? "eye.slash" : "eye")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(InpensoTheme.muted)
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(showPassword ? "Hide password" : "Show password")
                }
            }
            .id("password-\(mode.rawValue)-\(showPassword)")
        }
    }

    private func labeledField<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))
            content()
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(InpensoTheme.ink)
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(InpensoTheme.panelFill)
                        .shadow(color: Color.black.opacity(0.18), radius: 10, y: 4)
                )
        }
    }

    private var canSubmit: Bool {
        let e = email.trimmingCharacters(in: .whitespacesAndNewlines)
        return e.contains("@") && password.count >= 8
    }

    private func submit() {
        errorMessage = nil
        focusedField = nil
        isWorking = true
        Task {
            do {
                if mode == .login {
                    try await SharedTripAPI.shared.login(email: email, password: password)
                } else {
                    let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
                    try await SharedTripAPI.shared.register(
                        email: email,
                        password: password,
                        displayName: name.isEmpty ? String(email.split(separator: "@").first ?? "User") : name
                    )
                }
                // Apply caller state (e.g. onboarding cash/income) before any sync.
                onSuccess?()
                // Upload local ledger first so a pull cannot wipe freshly applied onboarding values.
                await CloudSyncService.shared.pushAll()
                if mode == .login {
                    await CloudSyncService.shared.pullIfAvailable()
                }
                // Refresh remote config + admin-granted Pro entitlement.
                await RemoteConfigService.shared.refresh()
                HapticFeedback.success()
                dismiss()
            } catch let SharedTripAPIError.accountBanned(message) {
                AuthSession.shared.rememberEmail(email)
                RemoteConfigService.shared.applyAccountBan(message: message)
                HapticFeedback.error()
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                HapticFeedback.error()
            }
            isWorking = false
        }
    }
}
