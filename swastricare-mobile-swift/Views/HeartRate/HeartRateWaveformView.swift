import SwiftUI

struct HeartRateWaveformView: View {
    var isRunning: Bool
    var bpm: Int
    
    // Configuration for the visual style
    private let lineWidth: CGFloat = 2.5
    private let gridColor = Color.red.opacity(0.1)
    private let traceColor = Color.red
    
    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let time = timeline.date.timeIntervalSinceReferenceDate
                let width = size.width
                let height = size.height
                let midY = height / 2
                
                // Draw Grid (Medical Monitor Style)
                drawGrid(context: context, size: size)
                
                // Wave parameters
                let baseSpeed = 2.0 // Slightly slower for smoothness
                // Smooth transition for speed could be handled by an external animated value, 
                // but for now direct BPM mapping is responsive.
                let speedMultiplier = isRunning && bpm > 0 ? Double(bpm) / 60.0 : 0.1
                let effectiveSpeed = baseSpeed * speedMultiplier
                
                // Target amplitude with smooth interpolation would require state, 
                // but we'll use a physics-based approach if we had a stateful view model driving this.
                // For now, we switch amplitude based on running state.
                let amplitude = isRunning ? 1.0 : 0.05
                
                // Create the path
                var path = Path()
                // Start slightly off-screen left
                path.move(to: CGPoint(x: 0, y: midY))
                
                // We'll draw from left to right.
                // The "time" parameter shifts the phase to make it scroll left.
                
                // Resolution: One point every 2 pixels is enough for smooth curves
                let step: CGFloat = 2
                
                for x in stride(from: 0, to: width, by: step) {
                    let relativeX = x / width
                    
                    // How many beats visible on screen?
                    let beatsOnScreen = 3.0
                    
                    // The position in the signal (t)
                    // x increases -> future (if we view it as a window)
                    // time increases -> signal moves left (so we subtract time)
                    let signalPosition = (relativeX * beatsOnScreen) - (time * effectiveSpeed)
                    
                    // Get the voltage (y-offset) at this signal position
                    let yOffset = ecgSignal(at: signalPosition)
                    
                    // Apply amplitude and scale to view
                    let y = midY + yOffset * amplitude * (height * 0.4) // Use 40% of height for max amplitude
                    
                    path.addLine(to: CGPoint(x: x, y: y))
                }
                
                // Draw the main trace with a gradient fade
                // The "newest" data is at the right, so it should be brightest.
                // The "oldest" data is at the left, so it should fade out.
                context.stroke(
                    path,
                    with: .linearGradient(
                        Gradient(colors: [
                            traceColor.opacity(0.0), // Fade out completely at left
                            traceColor.opacity(0.5),
                            traceColor,              // Bright at right
                            traceColor               // Keep bright edge
                        ]),
                        startPoint: CGPoint(x: 0, y: 0),
                        endPoint: CGPoint(x: width, y: 0)
                    ),
                    lineWidth: lineWidth
                )
                
                // Add a "Lead" dot at the end of the trace (right side) for that oscilloscope feel
                // We calculate the Y position at the very right edge (width)
                let rightmostSignalPos = (1.0 * 3.0) - (time * effectiveSpeed)
                let rightmostYOffset = ecgSignal(at: rightmostSignalPos)
                let leadY = midY + rightmostYOffset * amplitude * (height * 0.4)
                let leadPoint = CGPoint(x: width, y: leadY)
                
                // Glow for the lead point
                if isRunning {
                    let dotRect = CGRect(x: leadPoint.x - 4, y: leadPoint.y - 4, width: 8, height: 8)
                    context.addFilter(.blur(radius: 4))
                    context.fill(Path(ellipseIn: dotRect), with: .color(traceColor))
                    context.addFilter(.blur(radius: 0)) // Reset filter
                    
                    context.fill(Path(ellipseIn: CGRect(x: leadPoint.x - 2, y: leadPoint.y - 2, width: 4, height: 4)), with: .color(.white))
                }
            }
        }
        .frame(height: 80) // Slightly taller to accommodate the grid and peaks
        .background(Color.black.opacity(0.2)) // Dark background for contrast
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
    
    // Procedural ECG Signal Function
    // Returns a value roughly between -0.5 and 1.0
    private func ecgSignal(at t: Double) -> Double {
        // Normalize t to 0...1 cycle
        // t can be negative, so we handle the modulo carefully
        let cycle = t.truncatingRemainder(dividingBy: 1)
        let normalizedT = cycle < 0 ? cycle + 1 : cycle
        
        // Defined Intervals for P-Q-R-S-T
        // P: 0.10 - 0.20
        // Q: 0.25 - 0.28
        // R: 0.28 - 0.32
        // S: 0.32 - 0.35
        // T: 0.45 - 0.60
        
        var y: Double = 0
        
        if normalizedT >= 0.1 && normalizedT < 0.2 {
            // P Wave: Small smooth hump
            // Sine wave from 0 to PI
            let localT = (normalizedT - 0.1) / 0.1
            y = -0.15 * sin(localT * .pi)
        }
        else if normalizedT >= 0.24 && normalizedT < 0.28 {
            // Q Wave: Small dip
            let localT = (normalizedT - 0.24) / 0.04
            y = 0.15 * sin(localT * .pi)
        }
        else if normalizedT >= 0.28 && normalizedT < 0.32 {
            // R Wave: Sharp tall spike
            // Use a sharper function than sine, e.g., Gaussian or powered sine
            let localT = (normalizedT - 0.28) / 0.04
            // Spike going up (negative Y in SwiftUI is up, but let's stick to standard math and flip later if needed)
            // Wait, in Canvas (0,0) is top-left. So negative yOffset is UP.
            
            // Triangle-like spike
            if localT < 0.5 {
                y = -1.0 * (localT / 0.5)
            } else {
                y = -1.0 * ((1.0 - localT) / 0.5)
            }
        }
        else if normalizedT >= 0.32 && normalizedT < 0.36 {
            // S Wave: Small dip following R
            let localT = (normalizedT - 0.32) / 0.04
            y = 0.25 * sin(localT * .pi)
        }
        else if normalizedT >= 0.45 && normalizedT < 0.65 {
            // T Wave: Broader hump
            let localT = (normalizedT - 0.45) / 0.20
            y = -0.25 * sin(localT * .pi)
        }
        
        // Add some low-amplitude noise for realism
        let noise = sin(t * 50) * 0.02 + cos(t * 30) * 0.01
        
        // Smoothing between segments can be achieved by not having gaps, 
        // which we did by checking ranges. The gaps return 0 (baseline).
        
        return y + noise
    }
    
    private func drawGrid(context: GraphicsContext, size: CGSize) {
        let width = size.width
        let height = size.height
        
        var path = Path()
        
        // Vertical lines
        let vSpacing: CGFloat = 20
        for x in stride(from: 0, to: width, by: vSpacing) {
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: height))
        }
        
        // Horizontal lines
        let hSpacing: CGFloat = 20
        for y in stride(from: 0, to: height, by: hSpacing) {
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: width, y: y))
        }
        
        context.stroke(path, with: .color(gridColor), lineWidth: 0.5)
    }
}
