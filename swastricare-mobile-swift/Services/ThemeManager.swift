//
//  ThemeManager.swift
//  swastricare-mobile-swift
//
//  MVVM Architecture - Services Layer
//

import SwiftUI
import Combine

enum ThemeMode: String, CaseIterable {
    case light, dark, system, auto

    var displayName: String {
        switch self {
        case .light: return "Light"
        case .dark: return "Dark"
        case .system: return "System"
        case .auto: return "Auto"
        }
    }

    var description: String {
        switch self {
        case .light: return "Always light"
        case .dark: return "Always dark"
        case .system: return "Follow device"
        case .auto: return "Light 6AM–6PM"
        }
    }
}

@MainActor
final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    private static let key = "appThemePreference"

    @Published var currentTheme: ThemeMode {
        didSet {
            UserDefaults.standard.set(currentTheme.rawValue, forKey: Self.key)
            updateColorScheme()
        }
    }

    @Published private(set) var colorScheme: ColorScheme?

    private var timer: Timer?

    private init() {
        let stored = UserDefaults.standard.string(forKey: Self.key) ?? "system"
        self.currentTheme = ThemeMode(rawValue: stored) ?? .system
        self.colorScheme = nil
        updateColorScheme()
    }

    private func updateColorScheme() {
        switch currentTheme {
        case .light:
            colorScheme = .light
        case .dark:
            colorScheme = .dark
        case .system:
            colorScheme = nil
        case .auto:
            let hour = Calendar.current.component(.hour, from: Date())
            colorScheme = (hour >= 6 && hour < 18) ? .light : .dark
        }
        startAutoTimerIfNeeded()
    }

    private func startAutoTimerIfNeeded() {
        timer?.invalidate()
        timer = nil

        guard currentTheme == .auto else { return }

        let now = Date()
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: now)
        let targetHour = hour < 6 ? 6 : (hour < 18 ? 18 : 30)

        var target = calendar.date(bySettingHour: targetHour % 24, minute: 0, second: 0, of: now)!
        if targetHour >= 24 {
            target = calendar.date(byAdding: .day, value: 1, to: target)!
        }
        if target <= now {
            target = calendar.date(byAdding: .second, value: 1, to: target)!
        }

        let interval = target.timeIntervalSince(now)
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.updateColorScheme()
            }
        }
    }
}
