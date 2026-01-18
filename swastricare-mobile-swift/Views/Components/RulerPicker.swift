//
//  RulerPicker.swift
//  swastricare-mobile-swift
//
//  Created by Assistant on 17/01/26.
//

import SwiftUI
import UIKit

// Interactive Ruler Picker for Weight/Height
struct InteractiveRulerPicker: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let unit: String
    
    @State private var previousTranslation: CGFloat = 0
    @State private var isDragging: Bool = false
    @GestureState private var dragState: CGFloat = 0
    
    private let tickWidth: CGFloat = 2
    private let tickSpacing: CGFloat = 12
    
    var body: some View {
        VStack(spacing: 32) {
            // Value Display
            valueDisplay
            
            // Ruler
            rulerView
        }
    }
    
    private var valueDisplay: some View {
        VStack(spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(String(format: "%.0f", value))
                    .font(.system(size: 72, weight: .heavy, design: .rounded))
                    .foregroundStyle(PremiumColor.royalBlue)
                
                Text(unit)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.secondary)
            }
            
            Text(valueDescription)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var rulerView: some View {
        ZStack {
            GeometryReader { geometry in
                let midX = geometry.size.width / 2
                let steps = Int((range.upperBound - range.lowerBound))
                
                HStack(spacing: 0) {
                    ForEach(0...steps, id: \.self) { index in
                        tickView(for: index)
                    }
                }
                .offset(x: midX - (CGFloat(value - range.lowerBound) * tickSpacing) - (tickWidth / 2))
                .highPriorityGesture(dragGesture)
            }
            
            // Center Indicator
            centerIndicator
        }
        .frame(height: 120)
        .contentShape(Rectangle())
        .background(
            Color.primary.opacity(0.03)
                .clipShape(RoundedRectangle(cornerRadius: 20))
        )
    }
    
    private func tickView(for index: Int) -> some View {
        let itemValue = range.lowerBound + Double(index)
        let isMajor = Int(itemValue) % 10 == 0
        
        return VStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 1)
                .fill(isMajor ? Color.primary : Color.primary.opacity(0.2))
                .frame(width: tickWidth, height: isMajor ? 40 : 24)
            
            if isMajor {
                Text("\(Int(itemValue))")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                    .fixedSize()
            }
        }
        .frame(width: tickSpacing)
    }
    
    private var centerIndicator: some View {
        VStack(spacing: 0) {
            Image(systemName: "arrowtriangle.down.fill")
                .font(.system(size: 16))
                .foregroundStyle(PremiumColor.royalBlue)
                .offset(y: -4)
            
            Rectangle()
                .fill(PremiumColor.royalBlue)
                .frame(width: 4, height: 60)
                .clipShape(Capsule())
                .shadow(color: Color(hex: "2E3192").opacity(0.4), radius: 6)
        }
    }
    
    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 5)
            .onChanged { gesture in
                isDragging = true
                let translation = gesture.translation.width
                let delta = translation - previousTranslation
                previousTranslation = translation
                
                let deltaSteps = -delta / tickSpacing
                let newValue = value + Double(deltaSteps)
                let clamped = min(max(newValue, range.lowerBound), range.upperBound)
                
                value = clamped
            }
            .onEnded { _ in
                isDragging = false
                previousTranslation = 0
                withAnimation(.easeOut(duration: 0.2)) {
                    value = round(value)
                }
                let impact = UIImpactFeedbackGenerator(style: .medium)
                impact.impactOccurred()
            }
    }
    
    private var valueDescription: String {
        if unit == "kg" {
            return "Slide to adjust weight"
        } else if unit == "cm" {
            return "Slide to adjust height"
        }
        return ""
    }
}
