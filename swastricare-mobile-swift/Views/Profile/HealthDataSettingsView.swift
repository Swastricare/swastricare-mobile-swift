import SwiftUI
import HealthKit

struct HealthDataSettingsView: View {
    @StateObject private var homeVM = DependencyContainer.shared.homeViewModel
    @State private var isRequesting = false

    private let dataTypes: [(name: String, icon: String, description: String)] = [
        ("Steps & Distance", "figure.walk", "Daily step count and distance walked"),
        ("Heart Rate", "heart.fill", "Heart rate measurements"),
        ("Calories", "flame.fill", "Active and total calories burned"),
        ("Sleep", "bed.double.fill", "Sleep sessions and duration"),
        ("Exercise", "figure.run", "Workout sessions and activities"),
        ("Body Measurements", "scalemass.fill", "Weight data"),
        ("Hydration", "drop.fill", "Water intake logging")
    ]

    var body: some View {
        List {
            // Status Section
            Section {
                HStack(spacing: 16) {
                    Image(systemName: homeVM.isAuthorized ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(AppColors.accentBlue)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(homeVM.isAuthorized ? "Connected" : "Not Connected")
                            .font(.headline)
                        Text(homeVM.isAuthorized ? "SwasthiCare can read your health data" : "Grant permissions to sync health data")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 4)

                if !homeVM.isAuthorized {
                    Button(action: requestPermissions) {
                        HStack {
                            if isRequesting {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "lock.open.fill")
                            }
                            Text("Grant All Permissions")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .disabled(isRequesting)
                }
            } header: {
                Text("Status")
            }

            // Data Types Section
            Section {
                ForEach(dataTypes, id: \.name) { dataType in
                    HStack(spacing: 12) {
                        Image(systemName: dataType.icon)
                            .font(.body)
                            .foregroundColor(AppColors.accentBlue)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(dataType.name)
                                .font(.body)
                            Text(dataType.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        if homeVM.isAuthorized {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(AppColors.accentBlue)
                                .font(.subheadline)
                        }
                    }
                    .padding(.vertical, 2)
                }
            } header: {
                Text("Data Permissions")
            }

            // Open Apple Health
            Section {
                Button(action: {
                    if let url = URL(string: "x-apple-health://") {
                        UIApplication.shared.open(url)
                    }
                }) {
                    HStack {
                        Label("Open Apple Health", systemImage: "heart.text.square")
                        Spacer()
                        Image(systemName: "arrow.up.forward.app")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } footer: {
                Text("To revoke permissions, open Apple Health → Sharing → Apps → SwasthiCare.")
            }
        }
        .navigationTitle("Health Data")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func requestPermissions() {
        isRequesting = true
        Task {
            await homeVM.requestAuthorization()
            await homeVM.loadTodaysData()
            isRequesting = false
        }
    }
}
