//
//  NudgeCardsView.swift
//  swastricare-mobile-swift
//
//  Horizontal scrollable strip of server-side AI health nudge cards
//

import SwiftUI

struct NudgeCardsView: View {
    let nudges: [ServerNudge]
    let onDismiss: (ServerNudge) -> Void
    let onAction: (ServerNudge) -> Void

    var body: some View {
        if !nudges.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(nudges) { nudge in
                        NudgeCard(nudge: nudge, onDismiss: { onDismiss(nudge) }, onAction: { onAction(nudge) })
                            .transition(.asymmetric(insertion: .slide, removal: .opacity))
                    }
                }
                .padding(.horizontal, 16)
            }
            .animation(.spring(response: 0.4), value: nudges.count)
        }
    }
}

struct NudgeCard: View {
    let nudge: ServerNudge
    let onDismiss: () -> Void
    let onAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: nudge.icon)
                    .foregroundColor(Color(hex: nudge.nudgeColor))
                    .font(.system(size: 16, weight: .semibold))

                Text(nudge.title)
                    .font(.system(size: 14, weight: .bold))
                    .lineLimit(1)

                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                }
            }

            Text(nudge.message)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .lineLimit(2)

            if nudge.actionDeeplink != nil {
                Button(action: onAction) {
                    Text("Take Action")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color(hex: nudge.nudgeColor))
                }
            }
        }
        .padding(14)
        .frame(width: 240)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
    }
}
