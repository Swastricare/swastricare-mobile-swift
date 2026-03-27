import SwiftUI

struct OfflineBanner: View {
    @ObservedObject private var networkMonitor = NetworkMonitorService.shared

    var body: some View {
        if !networkMonitor.isConnected {
            bannerContent(
                icon: "wifi.slash",
                text: "You're offline. Some features may be limited.",
                color: .orange
            )
        } else if networkMonitor.isSyncing {
            bannerContent(
                icon: nil,
                text: "Syncing your data...",
                color: Color(red: 0.31, green: 0.19, blue: 0.57) // purple
            )
        }
    }

    private func bannerContent(icon: String?, text: String, color: Color) -> some View {
        HStack(spacing: 8) {
            if let icon {
                Image(systemName: icon)
                    .font(.subheadline)
            } else {
                ProgressView()
                    .tint(.white)
                    .scaleEffect(0.7)
            }
            Text(text)
                .font(.subheadline)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(color)
        .transition(.move(edge: .top).combined(with: .opacity))
        .animation(.easeInOut(duration: 0.3), value: networkMonitor.isConnected)
        .animation(.easeInOut(duration: 0.3), value: networkMonitor.isSyncing)
    }
}
