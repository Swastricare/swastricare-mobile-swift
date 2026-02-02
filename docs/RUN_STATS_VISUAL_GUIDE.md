# Run Stats & Analytics - Visual Design Guide

## 🎨 Design System

### Color Palette
```
Primary Blue:    #4F46E5 (Distance, Pace, Primary Actions)
Success Green:   #22C55E (Steps, Streaks, Positive Trends)
Warning Orange:  #FF6B00 (Calories, Time)
Accent Yellow:   #FFD700 (Points, Records)
Insight Purple:  #9333EA (AI Insights)
Error Red:       #EF4444 (Negative Trends)
```

### Typography Scale
```
Large Display:   56pt, Bold, Rounded (Main step counter)
Extra Large:     48pt, Bold, Rounded (Share card distance)
Display:         32pt, Bold, Rounded (Stat card values)
Title 1:         28pt, Bold (Section headers)
Title 2:         24pt, Bold (Card values)
Title 3:         20pt, Bold (Subsection headers)
Headline:        18pt, Semibold (Activity names)
Body:            16pt, Regular (Descriptions)
Subheadline:     14pt, Medium (Labels)
Caption:         12pt, Regular (Supporting text)
```

---

## 📱 Screen Layouts

### 1. Overview Tab
```
┌─────────────────────────────────────┐
│  [Overview] Performance Calendar Activities │ <- Tab Bar
├─────────────────────────────────────┤
│                                     │
│  ┌────────────┐  ┌────────────┐   │
│  │ 🚶 Steps   │  │ 🗺️ Distance│   │ <- Enhanced Stat Cards
│  │ 12,500     │  │ 8.5 km     │   │    with Progress Rings
│  │ ↗️ +12.5%  │  │ ↗️ +8.3%   │   │    and Trend Badges
│  │ ⭕️ 83%     │  │            │   │
│  └────────────┘  └────────────┘   │
│                                     │
│  ┌────────────┐  ┌────────────┐   │
│  │ 🔥 Calories│  │ ⭐ Points  │   │
│  │ 2,450      │  │ 1,250      │   │
│  │ ↗️ +15.7%  │  │ ↘️ -2.1%   │   │
│  └────────────┘  └────────────┘   │
│                                     │
│  ┌─────────────────────────────┐  │
│  │ Weekly Distance        15.2km│  │ <- Weekly Bar Chart
│  │ ║░░░░                       │  │
│  │ ║███  Distance by Day       │  │
│  │ ║░░   Mon Tue Wed Thu Fri...│  │
│  └─────────────────────────────┘  │
│                                     │
│  ┌─────────────────────────────┐  │
│  │ 🔥 Current  │ 🏆 Best       │  │ <- Streak Card
│  │    5 Days   │   12 Days     │  │
│  │ Keep it up! You're on roll  │  │
│  └─────────────────────────────┘  │
│                                     │
│  Quick Stats                        │
│  ┌──────────┐ ┌──────────┐        │
│  │⚡5:30/km │ │❤️ 145bpm │        │ <- Quick Stats Grid
│  └──────────┘ └──────────┘        │
│                                     │
└─────────────────────────────────────┘
```

### 2. Performance Tab
```
┌─────────────────────────────────────┐
│  Overview [Performance] Calendar Activities │
├─────────────────────────────────────┤
│                                     │
│  ┌─────────────────────────────┐  │
│  │ ✨ Performance Insights     │  │
│  ├─────────────────────────────┤  │
│  │ ✓ Consistency                │  │ <- Insights Card
│  │   Active on 15 days          │  │    (Purple gradient)
│  │                               │  │
│  │ ↗️ Distance Improved         │  │
│  │   Up 18.5% vs last period    │  │
│  │                               │  │
│  │ 🌅 Morning Person            │  │
│  │   Most workouts before noon  │  │
│  └─────────────────────────────┘  │
│                                     │
│  ┌─────────────────────────────┐  │
│  │ 🏆 Personal Records          │  │
│  ├─────────────────────────────┤  │
│  │ 🗺️ Longest Distance         │  │ <- Records Card
│  │    12.5 km • Jan 28, 2026   │  │    (Yellow gradient)
│  │                               │  │
│  │ ⏱️ Longest Duration          │  │
│  │    1h 25m • Jan 25, 2026    │  │
│  │                               │  │
│  │ 👣 Most Steps                │  │
│  │    18,500 • Jan 20, 2026    │  │
│  └─────────────────────────────┘  │
│                                     │
│  ┌─────────────────────────────┐  │
│  │ Pace Distribution            │  │
│  │ ▓▓▓▓▓▓▓▓░░ < 5:00    (8)   │  │ <- Horizontal Bar Chart
│  │ ▓▓▓▓▓░░░░░ 5:00-6:00 (5)   │  │
│  │ ▓▓▓░░░░░░░ 6:00-7:00 (3)   │  │
│  └─────────────────────────────┘  │
│                                     │
│  ┌─────────────────────────────┐  │
│  │ 🕐 Preferred Workout Time    │  │
│  │ Morning    ▓▓▓▓▓▓▓▓▓░  12   │  │ <- Time Distribution
│  │ Afternoon  ▓▓▓▓░░░░░░   5   │  │
│  │ Evening    ▓▓▓▓▓▓░░░░   8   │  │
│  │ Night      ▓░░░░░░░░░   2   │  │
│  └─────────────────────────────┘  │
│                                     │
└─────────────────────────────────────┘
```

### 3. Calendar Tab
```
┌─────────────────────────────────────┐
│  Overview Performance [Calendar] Activities │
├─────────────────────────────────────┤
│                                     │
│  ┌─────────────────────────────┐  │
│  │  ← January 2026 →           │  │
│  │     15 active days           │  │
│  ├─────────────────────────────┤  │
│  │  S  M  T  W  T  F  S        │  │
│  │           1  2  3  4  5     │  │ <- Calendar Grid
│  │  6  7  8  9 10 11 12        │  │    • = activity
│  │ 13 14 15 16 17 18 19        │  │    ⭕ = selected
│  │ 20 21 22 23 24 25 26        │  │    🔵 = today
│  │ 27 28 29 30 31              │  │
│  │  •  •     •  •  •  •  •     │  │
│  └─────────────────────────────┘  │
│                                     │
│  Selected: Wednesday, Jan 15       │
│  ┌─────────────────────────────┐  │
│  │ 🏃 Morning Run | 5.2 km     │  │ <- Day Activities
│  │    8:30 AM - 9:15 AM        │  │
│  │                          →   │  │
│  └─────────────────────────────┘  │
│                                     │
│  Monthly Summary                   │
│  ┌────────┐┌────────┐┌────────┐  │
│  │🗺️ 45.2││🏃 18   ││📅 15   │  │ <- Summary Cards
│  │   km  ││activities││ days  │  │
│  └────────┘└────────┘└────────┘  │
│                                     │
└─────────────────────────────────────┘
```

---

## 🎯 Component Details

### Enhanced Stat Card
```
┌────────────────────────┐
│ 🚶                 ↗️+12.5% │ <- Icon + Trend Badge
│                        │
│ 12,500      ⭕ 83%    │ <- Value + Progress Ring
│ steps                  │ <- Subtitle
│                        │
│ Total Steps            │ <- Title (bottom)
└────────────────────────┘
   20px padding, rounded corners
   Glass effect background
```

### Trend Badge
```
 ↗️ +12.5%   or   ↘️ -2.1%
 Green bg         Red bg
 Bold text        Bold text
```

### Progress Ring
```
    ⭕
   /  \
  |83% |  <- Percentage
   \  /
    ‾‾
Gray background
Colored progress arc
Animated fill
```

### Insight Row
```
┌──────────────────────────────┐
│ [🎯] Consistency             │
│      You've been active on   │
│      15 different days       │
└──────────────────────────────┘
  Icon in colored circle
  Title bold, description secondary
```

### Personal Record Row
```
🗺️  Longest Distance    12.5 km
    Jan 28, 2026
    
    Icon | Title + Date | Value
```

---

## 🎭 Animations

### Page Load
```
Component 1: opacity 0→1, offset Y +20→0, delay 0ms
Component 2: opacity 0→1, offset Y +20→0, delay 100ms
Component 3: opacity 0→1, offset Y +20→0, delay 200ms
...
Spring animation (0.5s response, 0.8 damping)
```

### Tab Switch
```
Quick spring animation (0.3s response)
Content fades out → new content fades in
Haptic feedback on tap
```

### Progress Ring Fill
```
Trim from 0% → target%
Spring animation (0.6s response)
Smooth arc drawing
```

### Trend Badge Pulse
```
Subtle scale animation on appear
1.0 → 1.05 → 1.0
```

---

## 📐 Spacing & Layout

### Vertical Spacing
```
Between sections:      24px
Between cards:         16px
Card padding:          20px
Section title margin:  16px bottom
```

### Horizontal Spacing
```
Screen margin:         20px left/right
Grid item spacing:     12-16px
Inside card:           12-16px
```

### Card Dimensions
```
Corner radius:         20px (large cards), 12px (small)
Border width:          1px (subtle)
Shadow:                Subtle, 10-20px blur
```

---

## 🌈 Color Usage Guide

### When to Use Each Color

**Blue (#4F46E5)**
- Distance metrics
- Pace information
- Primary CTAs
- Selected tabs

**Green (#22C55E)**
- Steps
- Positive trends (↗️)
- Streaks
- Goals achieved

**Orange (#FF6B00)**
- Calories
- Time/duration
- Warnings
- Best streak

**Yellow (#FFD700)**
- Points/rewards
- Personal records
- Achievements

**Purple (#9333EA)**
- AI insights
- Special features
- Premium content

**Red (#EF4444)**
- Negative trends (↘️)
- Alerts
- Delete actions

---

## 💡 UX Patterns

### Information Hierarchy
1. **Hero Number**: Largest, most important metric
2. **Supporting Stats**: Medium size, contextual
3. **Details**: Smaller, secondary information
4. **Actions**: Clear CTAs with icons

### Empty States
```
┌────────────────────────┐
│         📊             │
│   No activities yet    │
│                        │
│  Start a workout to    │
│  track your activities │
└────────────────────────┘
  Large icon (48pt)
  Primary message (headline)
  Secondary message (body)
```

### Loading States
```
┌────────────────────────┐
│         ⟳              │
│ Loading analytics...   │
└────────────────────────┘
  Spinner (1.2x scale)
  Message below
```

---

## ✨ Polish Details

### Micro-interactions
- Button press: Scale 0.97
- Tab switch: Haptic feedback
- Card tap: Subtle scale + shadow
- Number change: Smooth transition

### Accessibility
- VoiceOver labels on all elements
- High contrast mode support
- Dynamic type support
- Semantic color meanings

### Performance
- Lazy loading for charts
- Cached calculations
- Debounced updates
- 60fps animations

---

## 🎨 Design Inspiration

The design follows modern iOS design principles:
- **Glass morphism**: Translucent cards with blur
- **Neumorphism**: Subtle depth and shadows
- **Material Design**: Bold colors and typography
- **Apple HIG**: Native iOS patterns and behaviors

### Similar Apps Reference
- Apple Fitness+
- Strava
- Nike Run Club
- Apple Health

---

## 🔧 Developer Notes

### SwiftUI Modifiers Used
```swift
.ultraThinMaterial          // Glass effect
.clipShape(RoundedRectangle(cornerRadius: 20))
.shadow(color: .black.opacity(0.1), radius: 10)
.padding(20)
.animation(.spring(response: 0.5))
.opacity(isAnimating ? 1 : 0)
.offset(y: isAnimating ? 0 : 20)
```

### Charts Configuration
```swift
Chart {
    BarMark(x: .value(), y: .value())
        .foregroundStyle(.gradient)
        .cornerRadius(8)
}
.chartXAxis { ... }
.chartYAxis { ... }
.frame(height: 180)
```

### Color Extensions
```swift
Color(hex: "4F46E5")  // Custom hex colors
color.opacity(0.15)    // Transparent backgrounds
color.gradient         // Automatic gradients
```

---

*This visual guide should be used alongside the actual implementation to understand the design decisions and maintain consistency.*
