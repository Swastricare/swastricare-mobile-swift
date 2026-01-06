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

**Premium dark, clinical-tech.** Rounded cards, soft borders, minimal glow.

### Logo system

* **Primary mark:** Teal heart icon + wordmark "Swastricare"
* **Icon-only:** Teal heart icon (for app icon, favicon)

**Clear space:** Keep at least the icon width around the mark.

**Do not:**

* Stretch or skew
* Add gradients to the logo
* Put the logo on noisy backgrounds

---

## 5) Color system

### Core palette (dark-first)

**Primary Teal:** `#2ECDB9`

**Alert Orange (alerts only):** `#D56F3F`

**Neutrals:**

* **BG 0:** `#0D0E10`
* **BG 1:** `#17191B`
* **Surface 2:** `#1F2226`
* **Border:** `#343839`
* **Text Primary:** `#F1F2F3`
* **Text Secondary:** `#A3A7AE`
* **Text Tertiary:** `#6A6F77`

### Gradient (hero only)

Use only on landing hero headings, not inside product UI.

* `#6A7EC4` → `#7F7BAC` → `#4F5B85`

### Usage rules (strict)

* **All primary CTAs are Teal.**
* **Orange is only for urgent states:** SOS, Overdue, Critical.
* Avoid adding new accent colors inside core product screens.

---

## 6) Typography

### Fonts

* **Primary:** Inter (web + Android)
* **iOS:** SF Pro (native)

### Type scale

* **H1:** 32
* **H2:** 24
* **H3:** 20
* **Body:** 16
* **Small:** 14
* **Micro:** 12

**Line height:** 1.4 to 1.6

**Weights:** 400, 500, 600

---

## 7) Layout tokens

### Spacing

Use a consistent 8pt grid.

* 4, 8, 12, 16, 24, 32

### Radius

* **Card L:** 16
* **Card:** 12
* **Input:** 10

### Elevation

* Prefer borders over heavy shadows.
* Shadow only for primary surfaces (very subtle).

---

## 8) UI components

### Buttons

**Primary**

* Fill: `#2ECDB9`
* Text: `#0D0E10`
* Height: 52
* Radius: 16

**Secondary**

* Background: transparent
* Border: `#343839`
* Text: `#F1F2F3`

**Ghost**

* No border
* Text: `#A3A7AE`

**Destructive**

* Use red only for irreversible actions (delete, remove member)

### Cards

* Background: `#17191B`
* Border: `#343839` at low opacity
* Padding: 16

### Lists

* Row: icon + title + subtitle + trailing time or chevron

### Chips and badges

* Use for tech/compliance labels: ABDM, HIPAA, FHIR

### Navigation

* Bottom nav for patient app: 4–5 tabs
  Suggested tabs: **Home, Vault, Track, AI, SOS**

---

## 9) Accessibility and readability

* Minimum body text size: 14
* Keep secondary text contrast readable on BG 1
* Touch targets: 44px minimum
* Avoid teal on dark for long paragraphs; use teal for highlights

---

## 10) Product mockup style guide

### Device renders

* Prefer iPhone frames for premium feel
* Use subtle teal rim glow
* Background: dark grid or soft vignette

### Screens to showcase (MVP)

* Home (health overview)
* Vault (reports, categories)
* Add report (scan/upload)
* Ask AI (summary, Q&A)
* SOS (emergency contacts)

---

## 11) Developer handoff tokens

```json
{
  "colors": {
    "primary": "#2ECDB9",
    "alert": "#D56F3F",
    "bg0": "#0D0E10",
    "bg1": "#17191B",
    "surface2": "#1F2226",
    "border": "#343839",
    "textPrimary": "#F1F2F3",
    "textSecondary": "#A3A7AE",
    "textTertiary": "#6A6F77",
    "heroGradient": ["#6A7EC4", "#7F7BAC", "#4F5B85"]
  },
  "radius": { "cardLg": 16, "card": 12, "input": 10 },
  "spacing": [4, 8, 12, 16, 24, 32],
  "button": { "height": 52, "radius": 16 },
  "type": {
    "h1": 32,
    "h2": 24,
    "h3": 20,
    "body": 16,
    "small": 14,
    "micro": 12,
    "lineHeight": 1.5
  }
}
```

---

## 12) Non-negotiables

1. Teal is the only primary CTA color.
2. Orange only for urgent states.
3. Keep screens uncluttered: one primary action per view.
4. Make the AI experience feel safe and medical-grade, not chatbot-y.
