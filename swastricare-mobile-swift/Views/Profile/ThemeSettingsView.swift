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
                                        .font(.body)
                                        .foregroundColor(.primary)
                                    Text(mode.description)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                if themeManager.currentTheme == mode {
                                    Image(systemName: "checkmark")
                                        .font(.body.weight(.semibold))
                                        .foregroundColor(Color(hex: "4F46E5"))
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
    }
}
