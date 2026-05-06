//
//  ThemeSettingsView.swift
//  swastricare-mobile-swift
//

import SwiftUI

struct ThemeSettingsView: View {
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        ZStack {
            PremiumBackground()

            List {
                Section {
                    ForEach(ThemeMode.allCases, id: \.self) { mode in
                        Button {
                            themeManager.currentTheme = mode
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(mode.displayName)
                                        .font(.poppins(.regular, size: 17))
                                        .foregroundColor(.primary)
                                    Text(mode.description)
                                        .font(.poppins(.regular, size: 12))
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                if themeManager.currentTheme == mode {
                                    Image(systemName: "checkmark")
                                        .font(.poppins(.semiBold, size: 17))
                                        .foregroundColor(AppColors.aiTeal)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Appearance")
                } footer: {
                    Text("Auto mode switches between light and dark based on time of day (light 6 AM – 6 PM).")
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Theme")
        .navigationBarTitleDisplayMode(.inline)
        .trackScreen("ThemeSettings")
    }
}
