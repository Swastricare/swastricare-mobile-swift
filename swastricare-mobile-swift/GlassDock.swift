import SwiftUI

struct GlassDock: View {
    @Binding var currentTab: Tab
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases, id: \.self) { tab in
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        currentTab = tab
                    }
                }) {
                    VStack(spacing: 6) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 24))
                            .symbolVariant(currentTab == tab ? .fill : .none)
                            .foregroundColor(currentTab == tab ? .blue : .secondary.opacity(0.6))
                            .scaleEffect(currentTab == tab ? 1.1 : 1.0)
                        
                        Text(tab.title)
                            .font(.system(size: 10, weight: currentTab == tab ? .semibold : .medium))
                            .foregroundColor(currentTab == tab ? .primary : .secondary.opacity(0.6))
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
            }
        }
        .padding(.top, 12)
        .padding(.bottom, 4) // Add some bottom padding for the content before safe area usually handles the rest, but we want a specific look
        .background(
            ZStack {
                // Adaptive Glass effect
                VisualEffectBlur(blurStyle: .systemChromeMaterial)
                
                // Content tint/gradient overlay for more "glass" feel (Adaptive)
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.1),
                        Color.white.opacity(0.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .ignoresSafeArea()
        )
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Color.primary.opacity(0.1))
                .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1),
            alignment: .top
        )
    }
}

// Helper for standard UIVisualEffectView usage in SwiftUI
struct VisualEffectBlur: UIViewRepresentable {
    var blurStyle: UIBlurEffect.Style
    
    func makeUIView(context: Context) -> UIVisualEffectView {
        return UIVisualEffectView(effect: UIBlurEffect(style: blurStyle))
    }
    
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: blurStyle)
    }
}

enum Tab: String, CaseIterable {
    case home = "Home"
    case tracker = "Tracker"
    case ai = "AI"
    case vault = "Vault"
    case profile = "Profile"
    
    var title: String { rawValue }
    
    var icon: String {
        switch self {
        case .home: return "house"
        case .tracker: return "chart.bar"
        case .ai: return "sparkles"
        case .vault: return "lock.doc"
        case .profile: return "person.circle"
        }
    }
}
