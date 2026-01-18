# SwasthiCare Onboarding Experience
## "The App That Actually Gives a Damn About You"

---

# Design Philosophy

**Core Principle:** Every screen should feel like a conversation with a caring, slightly cheeky friend—not a medical form.

**Brand Voice:** Warm, witty, occasionally roast-worthy, but always genuine. We're the friend who tells you to drink water AND judges your 3am biryani.

**Visual Language:** Clean, breathing spaces. Soft gradients. Micro-animations that respond to input. Each screen should feel like a chapter in YOUR story.

---

# Screen-by-Screen Flow

---

## Screen 1: The Awakening
### "First Contact"

**Animation:** App logo forms from floating particles that pulse like a heartbeat

**Copy:**
```
hi.

i'm swastricare.

(but you can call me your health bestie 
who actually remembers to check on you)
```

**Subtext (subtle, smaller font):**
```
finally, an app that won't ghost you after day 3
```

**CTA Button:** `let's begin →`

**Micro-interaction:** Button has a gentle pulse, like breathing. Tapping creates a ripple effect.

---

## Screen 2: Existing User Check
### "Quick Question"

**Animation:** Two doors gently floating, one for existing users, one for new users

**Copy:**
```
are you an existing user?
```

**Options:**
```
[button] yes, i'm back
[button] no, i'm new
```

---

## Screen 3: The Tech Detective
### "Your Phone Says a Lot About You"

**Logic:** Detect iOS vs Android

---

### Version A: iOS Detected

**Animation:** Apple logo morphs into a heart

**Copy:**
```
ah, an apple person.

let me guess—
you have strong opinions about font choices,
your notes app is basically a diary,
and you've definitely judged someone 
for their green text bubbles.

i respect that energy.
```

**CTA Options:**
```
[Apple logo] sign in with apple
(keep it in the ecosystem, king/queen)

[Google logo] actually, google
(plot twist!)

[phone icon] just use my number
(mysterious. i like it.)
```

---

### Version B: Android Detected

**Animation:** Android robot doing a little wave

**Copy:**
```
android squad!

you probably have opinions about 
open-source software,
you've customized your home screen 
at least 47 times,
and you secretly feel superior 
about your charging port.

valid.
```

**CTA Options:**
```
[Google logo] sign in with google
(the obvious choice, the right choice)

[phone icon] just my number, please
(keeping things simple, i respect that)
```

---

## Screen 4: The Name Game
### "What Should I Call You?"

**Animation:** Cursor blinks invitingly in a cozy text field

**Copy:**
```
so...

what do people call you?

(your real name, nickname, 
what your mom yells when you skip breakfast—
whatever you vibe with)
```

**Input Field Placeholder:** `type here...`

**Validation Messages:**
- Empty: *"come on, even 'x' works"*
- Single letter: *"mysterious. i dig it."*
- Very long name: *"that's... a lot of letters. your parents went hard."*

**CTA:** `that's me →`

---

## Screen 5: The Welcome
### "The First Impression"

**Animation:** Name appears letter by letter, then gets a gentle glow

**Copy (Dynamic based on name length/style):**

**Standard names:**
```
hi {name}!

nice to finally meet you.

i've been waiting for someone 
who actually wants to feel better
and not just download health apps 
to feel productive.

you're already different.
```

**Short/Cool names (Max, Zoe, etc.):**
```
{name}.

short. sharp. memorable.

just like the changes we're 
about to make together.
```

**Long/Traditional names:**
```
{name}—

beautiful name.
your parents clearly put thought into this.

now let's put some thought 
into your health too, yeah?
```

**CTA:** `let's keep going →`

---

## Screen 6: The Identity
### "A Little About You"

**Animation:** Soft, non-binary gradient background that shifts colors

**Copy:**
```
quick one—

how do you identify?

(this helps me personalize things,
not judge things)
```

**Options (Cards, not dropdown):**
```
[icon: ♂] male
[icon: ♀] female  
[icon: ⚧] non-binary
[icon: 🤷] prefer not to say
```

**Subtext:**
```
this stays between us. 
pinky promise.
```

---

## Screen 7: The Time Traveler
### "When Did Your Story Begin?"

**Animation:** Vintage calendar pages flipping, then settling

**Copy:**
```
when were you born?

(not to calculate your age 
and silently judge your skincare routine—
okay maybe a little)
```

**Date Picker:** Modern scroll wheel with gentle haptics

**Dynamic Reactions (shown after selection):**

**Ages 13-17:**
```
gen z! you probably found this app 
through a tiktok. valid.
```

**Ages 18-25:**
```
prime years! let's not waste them 
on instant noodles and regret.
```

**Ages 26-35:**
```
the "i should probably start 
taking care of myself" era. 
welcome, friend.
```

**Ages 36-45:**
```
experienced enough to know better,
young enough to actually do better.
perfect timing.
```

**Ages 46-55:**
```
the wisdom years. 
let's make sure you're around 
to share all of it.
```

**Ages 56+:**
```
living legend status.
let's keep you thriving.
```

---

## Screen 8: The Measure
### "The Numbers (Don't Worry, No Judgment)"

**Animation:** Soft ruler/scale graphics floating

**Copy:**
```
let's get the basics—

these help me understand 
what "healthy" looks like for YOU.

not instagram healthy.
not gym-bro healthy.
YOUR healthy.
```

**Input Fields (Stacked, with smooth transitions):**

**Height:**
```
how tall are you?
[toggle: cm / ft'in]
```
*Placeholder:* "170 cm" or "5'7""

**Weight:**
```
and weight?
(we've all lied to our doctor. 
be honest with me though)
[toggle: kg / lbs]
```
*Placeholder:* "70 kg" or "154 lbs"

**Dynamic Response After Entry:**
```
noted. and just so you know—
i'm not here to make you "lose weight"
or "gain muscle" unless YOU want that.
i'm here to make you feel good.
```

---

## Screen 9: The Location
### "Where Are You?"

**Animation:** Minimalist map pin dropping

**Copy:**
```
where in the world are you?

(helps me with local health tips,
weather-based reminders,
and knowing when to tell you 
to drink water because it's 42°C outside)
```

**Input:** City search with autocomplete

**Location Detection Option:**
```
[location icon] or just detect it
(i'm not a stalker, promise)
```

**After Selection:**
```
{city}! 
[Dynamic response based on city]
```

**City-specific reactions:**
- **Chennai:** *"surviving the humidity is already cardio. respect."*
- **Mumbai:** *"the city that never sleeps... neither does your hustle, apparently."*
- **Bangalore:** *"traffic so bad, your stress levels need their own app."*
- **Coimbatore:** *"ah, great weather, great filter coffee, great choice."*
- **Delhi:** *"lungs of steel. you're already a warrior."*
- **Hyderabad:** *"biryani city. we'll manage that together."*
- **Generic:** *"nice! i'll keep your local context in mind."*

---

## Screen 10: The Contact
### "Your Number" (Age-Adaptive Tone)

**Logic:** Tone completely changes based on age captured earlier

---

### Version A: Ages 13-22 (Gen Z Casual)

**Copy:**
```
drop your digits

(for otp and reminders,
not for sliding into your dms—
unless water reminders count)
```

**Placeholder:** `your number bestie`

**Subtext:** *"we text. but like, helpful texts. not 'wyd' at 2am."*

---

### Version B: Ages 23-35 (Millennial Witty)

**Copy:**
```
your phone number?

don't worry, i'm not going to—
• send "u up?" texts
• share it with 47 marketing companies  
• call you. ever. (who calls anymore?)

just for verification and the occasional 
"hey, drink water" reminder.
```

**Placeholder:** `10 digits of trust`

---

### Version C: Ages 36-50 (Professional Warm)

**Copy:**
```
may i have your phone number?

this is purely for:
• secure login verification
• important health reminders
• emergency features (if you enable them)

your privacy is important to us—
no spam, no calls, no nonsense.
```

**Placeholder:** `your mobile number`

---

### Version D: Ages 51+ (Respectful & Clear)

**Copy:**
```
your phone number, please

we'll use this to:
✓ send you a one-time verification code
✓ send helpful health reminders (only if you want)
✓ keep your account secure

we will never share your number 
or disturb you unnecessarily.
```

**Placeholder:** `enter your 10-digit mobile number`

**Additional:** Larger text, clearer buttons

---

## Screen 11: The Personality
### "How Should I Talk to You?"

**Animation:** Three character avatars with distinct personalities

**Copy:**
```
important question—

what vibe do you want from me?

(you can change this later 
if you get tired of my personality)
```

**Options (Large cards with examples):**

---

### Option 1: Roast Mode 🔥
**Card Title:** "roast me into health"

**Preview:**
```
"oh, you had a samosa at 11pm?
that's not a snack, that's self-sabotage 
wrapped in crispy pastry.
drink water and think about 
your choices."
```

**Subtext:** *tough love, but make it funny*

---

### Option 2: Soft Mode 💝
**Card Title:** "be gentle with me"

**Preview:**
```
"hey love, noticed you haven't 
logged your water today.
it's okay, life gets busy!
just a gentle nudge—your body 
is doing so much for you,
maybe give it some hydration? 💧"
```

**Subtext:** *supportive bestie energy*

---

### Option 3: Professional Mode 📊
**Card Title:** "just the facts"

**Preview:**
```
"reminder: daily water intake target
not yet met. current: 4/8 glasses.
recommended action: consume 
500ml in next 2 hours for 
optimal hydration levels."
```

**Subtext:** *clinical. clean. no fluff.*

---

**Footer note:**
```
pick what motivates you—
some people need hugs,
some people need roasts,
some just need data.
all valid.
```

---

## Screen 12: The Purpose
### "Why Are You Here?"

**Animation:** Soft illustrations depicting different care scenarios

**Copy:**
```
let's get to the heart of it—

why swastricare?
what brought you here today?
```

**Options (Expandable cards):**

---

### Option A: Self-Care
**Card:** "i want someone to care for ME"

**Icon:** Single person with heart

**Expanded view:**
```
"i'm tired of being the one 
who has everyone's back
while no one checks on me.

i want an app that actually 
reminds ME to eat, sleep, 
drink water, and breathe."
```

**Subtext:** *it's not selfish. it's survival.*

---

### Option B: Caregiver
**Card:** "i want to care for someone else"

**Icon:** Two people, one supporting other

**Expanded view:**
```
"i have someone i love who needs 
a little extra looking after.

i want to help track their health,
remind them about medicines,
and make sure they're okay—
even when i can't be there."
```

**Follow-up question:**
```
who do you want to care for?

[Parent/s] - "they took care of you. 
             your turn now."

[Partner]  - "love is also making sure 
             they took their vitamins."

[Friend]   - "real ones check on 
             each other's health."

[Child]    - "building healthy habits 
             starts young."

[Other]    - "care doesn't need a label."
```

---

### Option C: Be Cared For
**Card:** "my partner/family wants to care for ME"

**Icon:** Person receiving care

**Expanded view:**
```
"someone who loves me is worried 
about my health and asked me 
to use this app.

fine. i'll try. 
(secretly touched that they care)
```

**Subtext:** *someone loves you. that's already a win.*

---

### Option D: Both Ways
**Card:** "care together"

**Icon:** Two people with connecting hearts

**Expanded view:**
```
"my partner and i want to keep 
each other healthy.

shared goals, shared reminders,
shared judging each other 
for skipping leg day."
```

**Subtext:** *couple goals, but make it healthy*

---

## Screen 13: The Promise
### "The Commitment"

**Animation:** Hand-drawn style commitment card forming, with user's name appearing

**Visual:** Looks like a handwritten pledge on beautiful paper

**Copy:**
```
one last thing, {name}.

before we begin,
i need you to make a promise.

not to me.
to yourself.
```

**The Pledge Card:**
```
┌─────────────────────────────────────┐
│                                     │
│    i, {name},                       │
│                                     │
│    promise to take my health        │
│    a little more seriously.         │
│                                     │
│    not perfectly.                   │
│    not obsessively.                 │
│    just... a little more.           │
│                                     │
│    i'll drink water when reminded.  │
│    i'll log my meals (sometimes).   │
│    i'll forgive myself when i slip. │
│    i'll celebrate small wins.       │
│                                     │
│    because i deserve to feel good.  │
│                                     │
│    signed: _______________          │
│    date: {today's date}             │
│                                     │
└─────────────────────────────────────┘
```

**CTA:** User taps signature area, their name appears in a handwritten font

**Animation:** Stamp effect with "PROMISE MADE" and a heart

---

## Screen 14: The Beginning
### "Welcome Home"

**Animation:** Confetti burst, then settles into clean home screen preview

**Copy (Age + Tone Adaptive):**

**Roast Mode:**
```
alright {name}, you did it.

you actually finished an onboarding 
without rage-quitting.
that's more follow-through than 
your gym membership ever got.

i'm proud of you.
now let's see if you last longer 
than your new year's resolutions.

(jk, i believe in you)
```

**Soft Mode:**
```
welcome home, {name} 💝

this is the beginning of something 
really, really good.

i'm here for you.
on your good days and your hard days.
when you crush your goals 
and when you eat ice cream at midnight.

no judgment. just support.
let's grow together.
```

**Professional Mode:**
```
setup complete, {name}.

your personalized health dashboard 
is now active.

key features enabled:
• hydration tracking
• meal logging
• medication reminders
• health insights

tap below to explore your dashboard.
```

**CTA:** `let's go! →`

---

# Design Specifications

## Color Palette
- **Primary:** Warm coral (#FF6B6B) — energetic but not aggressive
- **Secondary:** Soft teal (#4ECDC4) — calming, health-associated
- **Background:** Off-white (#FAF9F6) — easy on eyes
- **Text:** Soft black (#2D3436) — readable, not harsh
- **Accent:** Sunshine yellow (#FFE66D) — for celebrations/highlights

## Typography
- **Headings:** Rounded sans-serif (like Nunito or Quicksand)
- **Body:** Clean sans-serif (like Inter or DM Sans)
- **Handwritten elements:** Casual script for promise card

## Micro-Interactions
1. **Button taps:** Gentle scale + haptic feedback
2. **Screen transitions:** Smooth fade + slight slide
3. **Input focus:** Soft glow around text fields
4. **Progress:** Subtle breathing animation on progress dots
5. **Success states:** Confetti/sparkle bursts
6. **Error states:** Gentle shake + kind message

## Progress Indicator
- **Style:** Dots at top of screen (not a bar)
- **Behavior:** Current dot pulses gently
- **Skip option:** Only available on optional screens

---

# Success Metrics to Track

1. **Completion Rate:** % of users who finish onboarding
2. **Drop-off Points:** Which screens lose users
3. **Time per Screen:** Engagement vs friction indicator
4. **Tone Selection Distribution:** Which personality resonates
5. **Care Type Distribution:** Self vs caregiver split
6. **Promise Screen Engagement:** Do users spend time reading it?

---

# A/B Test Ideas

1. **Screen 3 (Login):** Playful device detection vs simple options
2. **Screen 7 (Age):** With reactions vs without
3. **Screen 13 (Promise):** With signature interaction vs simple checkbox
4. **Overall:** 14 screens vs condensed 8-screen version

---

# Edge Cases

1. **User goes back:** Don't lose data, show "welcome back" micro-copy
2. **User force-closes:** Save progress, resume from last screen
3. **User takes days:** "you're back! let's pick up where we left off"
4. **Accessibility:** Voice-over compatible, high contrast mode
5. **Offline:** Allow completion, sync when online

---

# Final Notes

This onboarding isn't just data collection—it's relationship building.

Every screen should make the user feel:
- Understood (not judged)
- Entertained (not bored)
- Cared for (not processed)
- Excited (not obligated)

The goal: By screen 14, the user should WANT to use this app.
Not because they should.
Because it already feels like it gets them.

---

*"The best health app isn't the one with the most features. It's the one people actually open."*

— SwasthiCare Design Philosophy

---

Document Version: 1.0
Created: January 2026
For: Nikhil / SwasthiCare Team