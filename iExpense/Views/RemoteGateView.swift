//
//  RemoteGateView.swift
//  iExpense
//
//  Full-screen maintenance / force-update gate driven by remote config.
//

import SwiftUI

struct RemoteGateView: View {
    @ObservedObject var remote: RemoteConfigService

    var body: some View {
        ZStack {
            AtmosphereBackground()

            VStack(alignment: .leading, spacing: 20) {
                Spacer()

                Text(AppBrand.name)
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundStyle(InpensoTheme.tide)

                Image(systemName: remote.config.maintenanceMode ? "wrench.and.screwdriver" : "arrow.down.app")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(InpensoTheme.tide)
                    .frame(width: 64, height: 64)
                    .background(InpensoTheme.tideSoft, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                Text(remote.config.maintenanceMode ? "Under maintenance" : "Update required")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(InpensoTheme.ink)

                Text(remote.config.maintenanceMode
                     ? remote.config.maintenanceMessage
                     : "Please update \(AppBrand.name) to continue. Minimum version \(remote.config.minAppVersion) (iOS \(remote.config.minIOSVersion)+).")
                    .font(.system(size: 16))
                    .foregroundStyle(InpensoTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)

                if !remote.config.maintenanceMode {
                    Button {
                        if let url = URL(string: remote.config.appStoreURL) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Text("Open App Store")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(InpensoPrimaryButtonStyle())
                }

                Button {
                    Task { await remote.refresh() }
                } label: {
                    Text("Try again")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(InpensoSecondaryButtonStyle())

                Spacer()
            }
            .padding(20)
        }
    }
}
