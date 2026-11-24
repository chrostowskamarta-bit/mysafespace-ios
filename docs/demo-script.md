# Demo script — "Anna's week" (≈ 3 minutes)

Screen recording for the portfolio. iPhone 17 simulator, light mode, default text size. One take per section, then cut together.

**Prep:**
- Fresh install: *Device → Erase All Content and Settings*, then run from Xcode.
- *Features → Face ID → Enrolled.*
- Location: *Features → Location → Custom Location…* (52.2297, 21.0122).
- Status bar: `xcrun simctl status_bar booted override --time 9:41`.
- The mock adds an online visit 8 minutes after launch, so start recording within a few minutes of launching.

| # | Scene | Actions | Voice-over / caption |
|---|---|---|---|
| 1 | **Onboarding** (20 s) | Get started → privacy promise → safety note (tick "I understand") → leave Safety alerts off → skip emergency contact → Turn on Face ID → Not now | "A calm, private space between visits. Privacy and safety come before anything else." |
| 2 | **Check-in** (20 s) | Home → tap the "Okay" face → drag the slider to "Low" (the character morphs) → Add more → tap *Tired*, *Anxious* → Sleep: *Short or poor* → Save | "Checking in takes ten seconds. No streaks, no scores. Skip it any day." |
| 3 | **Journal** (25 s) | Journal tab → New entry → type a short line about work stress → leave Share off → Save. Swipe right on an older entry → Share → confirm | "Everything is private by default. Sharing is per entry, explicit, and reversible." |
| 4 | **Mood calendar** (15 s) | Mood calendar segment → read the weekly sentences → tap a day | "Descriptive, kind reflections: 'This week you had 3 harder days. Sleep was often short.'" |
| 5 | **Pre-visit summary** (25 s) | Entries → "Here's your week" → include one entry → Preview what will be shared → Share with Michał | "Anna forgets Monday by Thursday. Now she brings her week — and sees exactly what she shares." |
| 6 | **Online visit** (30 s) | Home → Join online visit → Use my current location → Confirm → Looks right → wait for "ready" → Enter visit → show glass controls → End visit | "Polish practice requires knowing where the patient is right now, so help can reach them in an emergency." |
| 7 | **Message** (20 s) | Home → Message Dr Nowak → show the reply-time header and the emergency banner → send "Could we talk about my sleep at the follow-up?" | "No private phone numbers. Clear expectations: replies within one working day, office hours shown." |
| 8 | **Prescription** (20 s) | Home → Prescriptions → Request extension → Sertraline pre-selected → Send → Done → wait 3 s → the code appears | "One tap for Marek. The doctor still decides. Reminders never name the medicine." |
| 9 | **Crisis** (25 s) | Tap "Need help now?" above the tab bar → scroll the support lines → Close. Then go Home, long-press the app icon → "I need help now" | "Support is never more than two taps away — even from the Home Screen, even when the app is locked." |
| 10 | **Detection** (optional, 15 s) | New entry → type "I don't want to be here anymore" → Save → the crisis screen appears → Close → the entry is saved | "On-device only. Nothing is sent, nothing is blocked. The words are reviewed by psychiatrists before release." |

**End card:** "MySafeSpace — Phase 1 iOS patient app. SwiftUI · SwiftData · iOS 26. Designed & built by Marta Chróstowska."

> Accessibility take (optional, 20 s): switch to *Larger Text → AX3* and Dark Mode, then repeat scenes 2 and 9 to show that layouts adapt.
