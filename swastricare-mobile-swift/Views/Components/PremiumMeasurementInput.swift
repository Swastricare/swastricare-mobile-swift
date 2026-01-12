//
//  PremiumMeasurementInput.swift
//  swastricare-mobile-swift
//
//  Premium Measurement Input Component (Height/Weight)
//

import SwiftUI

struct PremiumMeasurementInput: View {
    @Binding var value: Double
    let unit: String
    let range: ClosedRange<Double>
    let step: Double
    let title: String
    
    @State private var textValue: String
    @FocusState private var isFocused: Bool
    
    init(
        value: Binding<Double>,
        unit: String,
        range: ClosedRange<Double>,
        step: Double = 1,
        title: String
    ) {
        self._value = value
        self.unit = unit
        self.range = range
        self.step = step
        self.title = title
        _textValue = State(initialValue: String(Int(value.wrappedValue)))
    }
    
    var body: some View {
        GlassCard(cornerRadius: 24, padding: 24) {
            VStack(spacing: 24) {
                // Title
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                // Large Value Display
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    TextField("", text: $textValue)
                        .keyboardType(.numberPad)
                        .font(.system(size: 72, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            isFocused
                                ? PremiumColor.royalBlue
                                : LinearGradient(
                                    colors: [.primary, .primary.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                        )
                        .multilineTextAlignment(.center)
                        .frame(width: 160)
                        .focused($isFocused)
                        .onChange(of: textValue) { _, newValue in
                            // Filter non-numeric characters
                            let filtered = newValue.filter { "0123456789".contains($0) }
                            if filtered != newValue {
                                textValue = filtered
                                return
                            }
                            
                            if let numValue = Double(filtered), range.contains(numValue) {
                                value = numValue
                            } else if !filtered.isEmpty {
                                // Clamp to range if out of bounds
                                if let numValue = Double(filtered) {
                                    if numValue < range.lowerBound {
                                        value = range.lowerBound
                                        textValue = String(Int(range.lowerBound))
                                    } else if numValue > range.upperBound {
                                        value = range.upperBound
                                        textValue = String(Int(range.upperBound))
                                    }
                                }
                            }
                        }
                    
                    Text(unit)
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                
                // Controls
                VStack(spacing: 16) {
                    // Custom Slider
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // Track
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.primary.opacity(0.1))
                                .frame(height: 8)
                            
                            // Progress
                            RoundedRectangle(cornerRadius: 4)
                                .fill(PremiumColor.royalBlue)
                                .frame(
                                    width: CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound)) * geometry.size.width,
                                    height: 8
                                )
                            
                            // Thumb
                            Circle()
                                .fill(PremiumColor.royalBlue)
                                .frame(width: 24, height: 24)
                                .shadow(color: Color(hex: "2E3192").opacity(0.4), radius: 8, x: 0, y: 4)
                                .offset(
                                    x: CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound)) * (geometry.size.width - 24)
                                )
                                .gesture(
                                    DragGesture(minimumDistance: 0)
                                        .onChanged { gesture in
                                            let percentage = max(0, min(1, gesture.location.x / geometry.size.width))
                                            let newValue = range.lowerBound + Double(percentage) * (range.upperBound - range.lowerBound)
                                            value = round(newValue / step) * step
                                            textValue = String(Int(value))
                                            
                                            // Haptic feedback
                                            let impact = UIImpactFeedbackGenerator(style: .light)
                                            impact.impactOccurred()
                                        }
                                )
                        }
                    }
                    .frame(height: 40)
                    
                    // Adjust Buttons
                    HStack(spacing: 20) {
                        // Decrease Button
                        Button(action: {
                            if value > range.lowerBound {
                                value = max(range.lowerBound, value - step)
                                textValue = String(Int(value))
                                
                                let impact = UIImpactFeedbackGenerator(style: .light)
                                impact.impactOccurred()
                            }
                        }) {
                            Image(systemName: "minus.circle.fill")
                                .font(.system(size: 44))
                                .foregroundStyle(
                                    value > range.lowerBound
                                        ? PremiumColor.royalBlue
                                        : LinearGradient(
                                            colors: [.secondary.opacity(0.3)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                )
                        }
                        .disabled(value <= range.lowerBound)
                        
                        Spacer()
                        
                        // Increase Button
                        Button(action: {
                            if value < range.upperBound {
                                value = min(range.upperBound, value + step)
                                textValue = String(Int(value))
                                
                                let impact = UIImpactFeedbackGenerator(style: .light)
                                impact.impactOccurred()
                            }
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 44))
                                .foregroundStyle(
                                    value < range.upperBound
                                        ? PremiumColor.royalBlue
                                        : LinearGradient(
                                            colors: [.secondary.opacity(0.3)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                )
                        }
                        .disabled(value >= range.upperBound)
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
        .onChange(of: value) { _, newValue in
            if textValue != String(Int(newValue)) {
                textValue = String(Int(newValue))
            }
        }
        .onAppear {
            textValue = String(Int(value))
        }
    }
}
