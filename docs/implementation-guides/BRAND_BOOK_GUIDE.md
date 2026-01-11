# Swastricare Brand Book v1

## 1) Brand essence

**Category:** Health OS (patients, families, doctors, pharmacists)

**Promise:** All your health information, organized, synced, and instantly understandable.

**Positioning:** A unified health vault + tracking + AI summary layer.

**What we are not:** A "wellness quotes" app, a hospital-only EMR, or a marketplace-first product.

**Tagline options (pick one and freeze):**

* **HealthOS**
* **The A to Z of Healthcare**
* **Your health, unified**

**Pillars:**

1. **Trust** (privacy, control, auditability)
2. **Clarity** (simple, readable, no clutter)
3. **Speed** (one-tap actions, fast flows)
4. **Human** (supportive, calm, never judgemental)

---

## 2) Audience and use cases

### Primary: Patients and families

* Store and access reports instantly
* Track vitals, meds, food, sleep
* Reminders and refill tracking
* Share records with doctors
* SOS and emergency contacts

### Secondary: Doctors and clinics

* Patient queue and scheduling
* EMR-lite (structured notes, templates)
* E-prescription and WhatsApp follow ups
* Billing and revenue dashboards

---

## 3) Brand voice

### Tone

* Calm, confident, respectful
* Short sentences
* No fear language
* No hype

### Copy rules

* Prefer verbs: **Add, Track, Upload, Sync, Share, Export, Ask AI, SOS**
* Use concrete labels, not vague words

### Microcopy examples

* "Add report"
* "Share with doctor"
* "Sync vitals"
* "Remind me"
* "Ask Swastricare AI"
* "Send to family"

### AI assistant voice

* Helpful, neutral, medical-safe
* Always suggests verification with a clinician when needed
* Never diagnoses with certainty

---

## 4) Visual identity

### Overall style

**Premium Glassmorphism & Vibrant Gradients.**
A high-end, futuristic medical interface. It combines deep, rich backgrounds with frosted glass elements (glassmorphism), vibrant animated gradients, and fluid motion. It feels alive, breathing, and technologically advanced while maintaining clinical trust.

### Logo system

* **Primary mark:** Teal heart icon + wordmark "Swastricare"
* **Icon-only:** Teal heart icon (for app icon, favicon)

**Clear space:** Keep at least the icon width around the mark.

**Do not:**
* Stretch or skew
* Put the logo on noisy backgrounds

---

## 5) Color system

### Premium Gradients (Core)

We moved away from single flat colors to rich, meaningful gradients.

* **Royal Blue (Primary Action/Brand):**
  `#2E3192` → `#1BFFFF` (TopLeading → BottomTrailing)
  *Used for: Primary buttons, active tabs, hero icons.*

* **Sunset (Alert/Warmth):**
  `#FF512F` → `#DD2476` (TopLeading → BottomTrailing)
  *Used for: Alerts, health warnings, warm highlights.*

* **Neon Green (Success/Safe):**
  `#11998e` → `#38ef7d` (TopLeading → BottomTrailing)
  *Used for: Vitals good, success states, positive trends.*

* **Deep Purple (Subtle/Secondary):**
  `#654ea3` → `#eaafc8` (TopLeading → BottomTrailing)
  *Used for: Subtitles, secondary accents, premium headers.*

* **Midnight (Background Depth):**
  `#232526` → `#414345` (Top → Bottom)
  *Used for: Deep card backgrounds, dark mode depth.*

### Usage rules

* **Glass over Solid:** Prefer glass layers over solid opaque backgrounds.
* **Gradients for Emphasis:** Use gradients for interactive elements and key indicators.
* **Text:** Keep primary text white/light (`#F1F2F3`) for readability against dark/glass backgrounds.

---

## 6) Glassmorphism & Depth

### The Glass Standard (`GlassModifier`)

All floating panels, cards, and docks use a consistent glass effect to create depth and hierarchy.

* **Blur Style:** `systemUltraThinMaterial`
* **Opacity:** White @ 10% (adjust based on depth)
* **Stroke/Border:**
  * Linear Gradient: `White (40%)` → `White (10%)` → `Clear`
  * Width: `1px`
  * *Purpose: Simulates a light edge reflection.*
* **Shadow:** `Black @ 10%`, Radius 10, Y: 5

### Premium Background (Animated)

The app background is not static. It features slowly moving, blurred "Orbs" to make the app feel alive.

* **Orb 1 (Blue):** Moves TL ↔ BR
* **Orb 2 (Purple):** Moves Top ↔ Bottom
* **Orb 3 (Cyan):** Moves Left ↔ Right
* **Blur Radius:** 60-80px (Creates a soft, ambient glow)

---

## 7) Typography

### Fonts

* **Primary:** Inter (Web) / SF Pro (iOS Native)

### Hierarchy

* **Hero Titles:** 34pt Bold, Gradient Fill (Primary → Primary 70%)
* **Headers:** 24pt Bold
* **Subtitles:** 12-14pt, Uppercase, Tracking 1.5, Deep Purple Gradient
* **Body:** 16pt, Regular, White/Light Gray

---

## 8) UI Components

### Glass Dock (Navigation)

A floating, glass-morphic bottom navigation bar.

* **Background:** Adaptive Glass (`systemChromeMaterial`) + White Tint Gradient (10% → 0%)
* **Active Tab:**
  * Icon: Filled, Blue Gradient text, Scaled 1.1x
  * Text: Semibold, Primary Color
* **Inactive Tab:**
  * Icon: Outline, Secondary Color (60% opacity)
  * Text: Medium, Secondary Color

### Buttons

* **Scale Button:**
  * Interactive spring animation on press (Scale 0.95).
  * Spring: Response 0.3, Damping 0.6.

* **Hero Icons:**
  * Surrounded by a circular glass layer (`Material.ultraThin`).
  * Drop shadow for lift.

### Cards & Lists

* **Glass Cards:** Rounded corners (20px default), glass background, subtle white border gradient.
* **Lists:** Clear separation with adequate padding, often housed within glass containers.

---

## 9) Motion & Interaction

### Animation Principles

* **Fluidity:** Use `spring` animations for interactions (buttons, tabs).
  * *Standard Spring:* Response 0.3, Damping 0.7
* **Aliveness:** Background orbs move continuously (loops of 8-12 seconds).
* **Transitions:** Smooth fades and scales. No harsh cuts.

---

## 10) Developer Handoff Tokens

```swift
// Premium Colors
static let royalBlue = LinearGradient(colors: [Color(hex: "2E3192"), Color(hex: "1BFFFF")], ...)
static let sunset = LinearGradient(colors: [Color(hex: "FF512F"), Color(hex: "DD2476")], ...)
static let neonGreen = LinearGradient(colors: [Color(hex: "11998e"), Color(hex: "38ef7d")], ...)

// Glass Modifier
.background(VisualEffectBlur(blurStyle: .systemUltraThinMaterial))
.overlay(
    RoundedRectangle(cornerRadius: cornerRadius)
        .stroke(LinearGradient(colors: [.white.opacity(0.4), ...]), lineWidth: 1)
)
```

---

## 11) Non-negotiables

1. **Wow Factor:** Every screen must have depth (glass) and life (animation).
2. **Readability:** Despite the fancy backgrounds, text contrast must remain high (White text on dark glass).
3. **Consistency:** Use the `GlassModifier` and `PremiumColor` structs. Do not hardcode hexes or custom blur styles.
4. **Performance:** Ensure animations (like the background orbs) are efficient and don't drain battery excessively.
