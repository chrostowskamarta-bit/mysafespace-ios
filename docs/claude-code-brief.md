# MySafeSpace – Claude Code Brief
### Phase 1: iOS Patient App (portfolio build, 3 days)

> **How to use this brief:** Read the whole document before writing code. Build in the order given in §13. When something here conflicts with a convenience shortcut, **safety, privacy and accessibility win**. If a requirement is unclear, choose the calmer, more private, more accessible option and leave a `// DECISION:` comment.

---

## 1. Context

**MySafeSpace** is a mental health app for a Polish outpatient mental health clinic (*poradnia zdrowia psychicznego*: psychiatrists + psychologists/psychotherapists). The full product will have three personas (Patient, Doctor, Admin) on iOS, Android and web, and will eventually be sold to mental health centers.

**Phase 1 (this brief)** is the **Patient app for iOS only**, built in **3 days** as a **high-quality portfolio piece**: a polished, fully clickable SwiftUI app running on **mock data** with no real backend. It must *look and behave* like a real, safe, legally aware product, so that the later production build can reuse its architecture and design system.

- **Language:** English only for now. All user-facing strings go in a **String Catalog (`Localizable.xcstrings`)** – no hard-coded strings – so Polish can be added later.
- **Setting:** The app is set in **Poland**: Polish crisis numbers, the Polish e-prescription (e-Recepta) flow, Polish law, all described in English.
- **Owner:** Marta Chróstowska (designer). Portfolio-quality visuals matter as much as working code.

---

## 2. Non-negotiable principles

1. **Mental health safety first.** Trauma-informed design: safety, user control, no surprise content, no forced interactions, no punitive mechanics (no streaks, no scores like "Discipline 88%", no guilt copy).
2. **The journal is private by default.** Nothing from the journal is shared without explicit, visible, revocable consent from the patient.
3. **Crisis support is never more than 2 taps away** from any screen.
4. **The app never contacts police or emergency services automatically**, and never sends journal content anywhere automatically (see §8).
5. **Apple Human Interface Guidelines** (Designing for iOS), especially:
   - Limit on-screen controls; keep secondary actions discoverable with minimal interaction.
   - Adapt to **Dark Mode, Dynamic Type and orientation**.
   - Put key controls in the **middle/bottom reach zone**; support swipe-back and swipe actions in lists.
   - With permission, use platform capabilities (**Face ID**, **location**) instead of asking people to type.
6. **One primary action per screen. Plain, warm language** – no clinical jargon.
7. **Accessibility is part of "done"**, not polish (see §11).

---

## 3. Personas (design for these people)

**Anna, 29 – patient, weekly therapy for anxiety.** UX designer, heavy iPhone user.
- *Pain:* By Thursday's session she has forgotten what upset her on Monday, and between sessions she has no way to reach her therapist.
- *Needs:* Quick in-the-moment journaling, a pre-visit summary she can choose to share, and messaging that doesn't feel like intruding.
- *Fear:* "What if someone reads my journal?"

**Marek, 52 – patient, on psychiatric medication for depression.** Logistics manager, low tech confidence, uses large text.
- *Pain:* His prescriptions run out between visits; renewing means phoning during work hours. On bad days, opening an app is hard.
- *Needs:* One-tap "request extension", discreet reminders, low-effort screens.
- *Fear:* His employer or family finding out.

**Dr Katarzyna, 41 – psychiatrist** *(Phase 2 user; shapes patient-side features).*
- *Pain:* She won't give out her private phone number but feels guilty leaving patients without contact, and has no view of how patients do between visits.
- *Needs:* Bounded messaging (office hours), shared mood trends, red-flag alerts that support her clinical judgement.

**Ewa, 45 – clinic administrator** *(Phase 2/3 user).*
- *Pain:* She has no easy way to manage staff, rooms and schedules.
- *Needs:* One place for staff, roles, rooms and access, with an audit trail.

**Core pain points this app must visibly solve**
1. Doctor won't share a private phone number, but the patient needs contact → **secure in-app messaging with clear response expectations**.
2. Patient forgets what bothered them between weekly visits → **journal + mood tracking + pre-visit summary**.
3. Patient lacks ad-hoc contact → **messaging + crisis resources always available**.
4. *(Admin pain point – out of scope for Phase 1, but keep the data model ready for it.)*

---

## 4. Scope

### In scope (Phase 1)
- Onboarding with consent screens
- Home
- Visits calendar + visit details
- Online visit flow (location check → waiting room → mock video call)
- Journal: mood check-in, entries, sharing controls, mood calendar, pre-visit summary
- On-device crisis detection + full-screen crisis support
- Prescriptions with "request extension"
- Secure messaging with the assigned clinician
- Profile & privacy settings (Face ID lock, emergency contact, notifications, safety-alert consent, data export/delete – simulated)
- Home Screen quick action: **"I need help now"**
- Portfolio deliverables (§14)

### Out of scope (Phase 1) – but architect for it
- Real backend, real auth, real video calls, real E2EE (simulate with clear `// MOCK:` boundaries behind protocols)
- Doctor and Admin apps
- Android and web
- P1 / e-Recepta / e-ZLA integration, identity verification
- Polish localisation (String Catalog only)

---

## 5. Tech stack & architecture

- **Swift 6, SwiftUI**, latest stable Xcode. **Deployment target: iOS 26** (use system materials/Liquid Glass for tab bar and navigation where it suits the calm look; do not over-use glass effects).
- **Architecture:** feature-based folders, `@Observable` view models, and protocol-based services with mock implementations injected via the environment, so real services can replace them later.
- **Persistence:** **SwiftData** for journal entries and mood check-ins (so the demo feels real across launches); static JSON/Swift fixtures for visits, prescriptions, messages and the clinician.
- **No third-party dependencies.**
- **File protection:** set Data Protection to `NSFileProtectionComplete` for the app's stored data.

**Suggested structure**
```
MySafeSpace/
  App/                 (MySafeSpaceApp, AppState, QuickActions, PrivacyShield)
  DesignSystem/        (Colors, Typography, Spacing, Radius, Components/, MoodCharacters/)
  Features/
    Onboarding/
    Home/
    Visits/
    OnlineVisit/
    Journal/
    Crisis/
    Prescriptions/
    Messages/
    Profile/
  Services/            (protocols + Mock*: VisitService, JournalStore, CrisisDetector,
                        PrescriptionService, MessagingService, LocationService, AuthService)
  Models/
  Resources/           (Localizable.xcstrings, Assets.xcassets, MockData/)
  Tests/               (CrisisDetector unit tests, view-model tests)
```

---

## 6. Design system

**Inspiration folder:** a private moodboard of 9 reference images (not included in this repo). If it is in your working directory, open them before designing.
- **Take from the healthcare-app shots:** soft lavender backgrounds, large-radius cards (24–32 pt), pill-shaped CTAs with a circular arrow button, a horizontal week strip for date picking, a big hero "Next visit" card on Home, and a floating bottom tab bar.
- **Do NOT take:** doctor prices, star ratings, "choose your doctor" marketplace patterns. The patient has an **assigned clinician**.
- **Take from the mood shots:** friendly face characters, a mood calendar grid, colourful bento stat cards, a face slider whose expression morphs, and emotion word chips (general mood → specific feeling).
- **IP rule:** create **original** mood characters, drawn as simple SwiftUI shapes (rounded blobs, eyes and mouths as paths). Do not copy any existing brand's characters (one reference resembles Headspace's; do not imitate it).

### Colour tokens (Asset Catalog, light + dark variants)
| Token | Light | Use |
|---|---|---|
| `brandPrimary` (violet) | `#6C4CF5` | Primary buttons, links, selected tab. 5.3:1 on white ✔ |
| `brandPrimaryStrong` | `#5B3FD9` | Small violet text (6.7:1 on white) |
| `brandSecondary` (lemon green) | `#D4F55A` | **Fills/highlights only**: "today" chip, selected day, "Shared" badge, positive moments. Text on it must be `ink`. |
| `ink` | `#1E1636` | Primary text (15.8:1 on background) |
| `background` | `#F6F4FF` | App background (soft lavender) |
| `surface` | `#FFFFFF` | Cards |
| `mood1…mood5` | soft, desaturated scale | Mood levels – no aggressive saturated red |

- ⚠️ **Never use lemon green as text or icon colour on white/light surfaces (1.2:1 – fails).**
- Provide Dark Mode equivalents (deep violet-ink background, lifted violet, lemon green stays a highlight) and verify contrast ≥ 4.5:1 for body text and ≥ 3:1 for large text/UI.
- **Crisis screen:** calm and plain – neutral background, violet/ink only, no lemon green, no playful characters.

### Typography
- **SF Pro** (system) for all body/UI text using semantic text styles (`.body`, `.headline`, …) so **Dynamic Type works everywhere**.
- Optional: SF Pro Rounded (`.fontDesign(.rounded)`) for large headings – warm but not childish.

### Spacing, shape, motion
- 4-pt grid (4/8/12/16/24/32); 16-pt screen margins; respect safe areas.
- Card radius 24–28 pt, buttons fully rounded (capsule).
- Gentle, short animations; **respect Reduce Motion** (swap morphs/slides for fades).
- Haptics: light, sparing; none on the crisis screen except the call button.

### Tone of voice
Warm, calm, adult, non-judgmental. Examples: "How are you today?", "Skip for now", "That sounds really hard.", "Your doctor usually replies within 1 working day." Avoid exclamation-heavy cheerfulness, and avoid "You failed / missed".

---

## 7. Screens & flows

### 7.1 Onboarding (first launch)
1. **Welcome** – app name, one-line promise ("A calm, private space between your visits"), "Get started".
2. **Privacy promise** – plain-language bullets: the journal is private by default; you choose what to share; your doctor does **not** read your journal in real time.
3. **Important safety note** (must be acknowledged): "MySafeSpace is not monitored 24/7. If your life or someone else's is in danger, call **112**." Show the support numbers (§8.4).
4. **Optional: Safety alert consent** (separate toggle, default **off**, explained honestly – see §8.3).
5. **Optional: Emergency contact (ICE)** – name + phone, "Recommended", skippable.
6. **Face ID app lock** – recommended, skippable; uses `LocalAuthentication` with a passcode fallback.
7. **Notifications** – explain discreet reminders before requesting permission.
- No account creation (mock patient "Anna Kowalska" is signed in). Don't ask for setup data that isn't needed.

### 7.2 Home
- Greeting + date.
- **Mood check-in card** (skippable, *not* a blocking modal – see §12). After check-in it collapses to "Checked in today 🙂 · Edit".
- **Next visit hero card** (clinician, date/time, in-person/online, "Join" when online and within 10 min).
- Quick actions: "Write in journal", "Message Dr …", "Prescriptions".
- **Persistent, quiet "Need help now?" entry** (e.g. a small pill in the top bar or above the tab bar) → Crisis screen.
- Tab bar: **Home · Visits · Journal · Messages · Profile** (Prescriptions reachable from Home and Profile).

### 7.3 Visits
- Month calendar + horizontal week strip; days with visits are marked; today uses a lemon-green highlight with ink text.
- List of upcoming/past visits (type: in-person/online, clinician, room/address or "Online").
- **Visit detail:** time, clinician, type, location/room, "Add to Calendar" (EventKit, with permission), "Prepare for this visit" → pre-visit summary (§7.5), cancel/reschedule request (mock).

### 7.4 Online visit (teleconsultation)
1. **Location check (required by law – the doctor must know where to send help in an emergency):** "Where are you right now?" Offer "Use my current location" (CoreLocation, when-in-use, with permission) **or** manual address entry. Explain why in one sentence. *Current location, not registered address.*
2. **Check-in:** confirm the emergency contact is up to date (editable, skippable).
3. **Waiting room:** calm screen, camera/mic preview toggles (mock), "Dr … will join shortly".
4. **Mock call screen:** placeholder video tiles, mute/camera/end buttons, an "End-to-end encrypted" label (`// MOCK:` – no real E2EE in Phase 1). A Crisis entry stays reachable.

### 7.5 Journal (core feature)
- **Mood check-in (≤ 10 seconds):**
  1. Face slider with 5 levels (original morphing character) – the only required step.
  2. Optional emotion word chips (e.g. calm, grateful, anxious, sad, angry, numb, overwhelmed, hopeful…).
  3. Optional tags (sleep quality, anxiety level, meds taken, energy) + optional free-text note.
- **Entries list:** chronological, each with mood face, time, preview, and a clear **Private 🔒 / Shared** state.
- **Entry editor:** free text; mood optional; "Share with Dr …" toggle per entry (default off). Swipe actions: share/unshare, delete (with confirmation).
- **Mood calendar:** month grid of mood faces + gentle weekly summary in descriptive, non-judgmental words ("This week you had 3 harder days. Sleep was often short.") – never a score.
- **Pre-visit summary** (fixes Anna's pain point): before each visit, offer "Here's your week" – mood trend, most frequent emotion words, entries she *chose* to include. **Preview exactly what will be shared**, then "Share with Dr …" or "Keep private". Sharing is revocable in Profile → Privacy.
- **Crisis detection** runs on save/pause of entries (§8).

### 7.6 Prescriptions
- List of active prescriptions: medication name, dose, days remaining (progress), prescribing doctor.
- **"Request extension"** → sheet: pick prescription(s), optional note → "Request sent. Dr … will review it. When approved, you'll receive your e-prescription code (by SMS/e-mail and in the IKP patient account)." Status: Requested → Approved (mock) → shows a 4-digit access code (mock).
- Explain that the doctor decides (a request, not an automatic renewal). Psychotropic medications may need a visit first – show that as a possible status ("Dr … would like to see you before renewing").
- **Medication reminders:** local notifications with **generic text only** ("MySafeSpace: a gentle reminder"). Never show drug names in notifications or on the lock screen.

### 7.7 Messages (no phone numbers exchanged)
- One thread with the assigned clinician (plus a "Clinic reception" thread).
- Header shows **response expectations**: "Dr Nowak usually replies within 1 working day · Mon–Fri 9:00–17:00".
- Banner (always visible, small): "Not for emergencies. If you're in danger, call 112." → tap opens the Crisis screen.
- Composer with text and mock attachment; "Encrypted" label (`// MOCK:`).
- Outside office hours: a gentle auto-note ("Dr Nowak will see this on Monday").
- **Crisis detection also runs on outgoing messages** (shows support; still allows sending).

### 7.8 Crisis screen (full screen)
- Reached from: the Home pill, the Messages banner, the onboarding note, the Profile item, the **Home Screen quick action "I need help now"** (`UIApplicationShortcutItem`) and the crisis-detection trigger.
- Content (calm, plain, large tap targets):
  - Heading: "You don't have to go through this alone."
  - **Call 112** (emergency – primary button)
  - **116 123** – Crisis Support Line for adults (free)
  - **800 70 2222** – 24/7 Support Centre for Adults in Mental Crisis (free)
  - **116 111** – Helpline for Children and Young People (free)
  - "Call my emergency contact (Name)" if set
  - "Message my clinic" (with the note "replies are not immediate")
  - Optional: a simple grounding exercise (e.g. a 4-7-8 breathing animation, Reduce Motion aware)
- Use `tel:` links. **Note for the build:** verify the helpline numbers are current before release.
- Never auto-dial. Never shame. The "Close" button is always available.

### 7.9 Profile & Privacy
- Personal details (mock), assigned clinician, emergency contact (edit).
- **Privacy centre:** Face ID lock toggle; list of everything currently shared with the doctor (revoke each); Safety alert consent toggle with explanation; "Export my data" (mock: generates a JSON/PDF preview); "Delete my journal" (strong confirmation).
- Notifications settings (reminder times, discreet text preview).
- "About the safety features" – plain explanation of crisis detection (on-device, what it does and doesn't do).
- Legal: Terms (incl. "not monitored 24/7"), Privacy Policy (GDPR Art. 9 special-category data) – placeholder text.

---

## 8. Crisis detection – logic & rules

Based on Polish law and practice (Mental Health Protection Act, medical confidentiality, GDPR): **automatic reporting to police/services is not the standard and would risk breaching confidentiality**, especially when an entry expresses passive ideation rather than imminent intent. The clinical decision belongs to a human clinician.

### 8.1 Detection (Phase 1)
- `CrisisDetector` protocol with an **on-device** implementation: a keyword/phrase matcher (English) with normalisation (lowercase, diacritics, simple stemming) and two categories:
  - **Self-harm / suicidal ideation** (e.g. "kill myself", "end my life", "want to die", "no reason to live", "hurt myself", "suicide", "better off without me"…)
  - **Harm to others** (e.g. "hurt someone", "kill him/her/them"…)
- Include basic negation awareness where cheap ("I would never…" lowers confidence), but **err on the side of showing support**.
- Runs when an entry is saved or after typing pauses; also on outgoing messages.
- **Nothing leaves the device** as a result of detection, unless the Safety alert consent is on (§8.3).
- Unit-test the detector (true positives, obvious negatives, negation cases).
- Mark the keyword list `// CLINICAL REVIEW REQUIRED` – it must be validated by psychiatrists before production.

### 8.2 Patient-facing response
- Immediately show the **full-screen Crisis screen (§7.8)** with a gentle lead-in: "It sounds like you might be going through something really painful. Would you like to talk to someone now?"
- **Never block saving or sending.** Never delete or alter the entry. No alarmist language.
- Do not re-trigger repeatedly for the same entry within a short window (avoid nagging), but keep the Crisis entry reachable.

### 8.3 Optional "Safety alert" (consent-based, off by default)
- If the patient opted in: send the clinic a **flag only** ("Anna may need contact – detected [date, time]"), **never the entry text**. In Phase 1 this is mocked, and the patient sees a confirmation: "Your clinic has been notified that you may need support. They are not reading your journal."
- The clinician (Phase 2) decides whether to call the patient, contact the ICE person, or call emergency services.
- The patient can see and revoke this consent at any time.

### 8.4 Always-on disclosures
- In onboarding, Terms and the "About safety features" page: **"MySafeSpace is not monitored in real time (24/7). If your life or someone else's life is in danger, call 112."**

---

## 9. Privacy & security (Phase 1 – real on-device measures + mocked server ones)

**Real in Phase 1**
- Face ID / passcode app lock (`LocalAuthentication`), auto-lock after N minutes in background.
- **Privacy shield:** blur/cover the UI when the app goes to the background (no journal visible in the app switcher).
- Journal content is **never** indexed in Spotlight, never shown in widgets, never in notification text.
- Generic notification copy; no medication names on the lock screen.
- Data Protection: complete file protection for stored data.
- Location used **only** for the online-visit check, when-in-use, with clear purpose strings.
- All permission prompts are pre-explained in-app before the system dialog.

**Mocked in Phase 1 (behind protocols, labelled `// MOCK:`)** – required for production
- End-to-end encryption for video, chat and attachments (no access for platform admins).
- 2FA: mandatory for staff, recommended for patients.
- Audit log of every access to medical records (who, when, what was viewed/edited).
- Role-based access: psychiatrist vs psychologist; psychotherapy notes stricter than the general visit record.

---

## 10. Mock data
- Patient: **Anna Kowalska**, 29, Warsaw.
- Clinicians: **Dr Katarzyna Nowak** (psychiatrist), **Michał Wiśniewski** (psychotherapist, weekly Thursday sessions).
- Clinic: "MySafeSpace Mental Health Clinic, ul. Przykładowa 12, Warsaw" (fictional), rooms 1–3.
- Visits: weekly online/in-person therapy for the past 6 weeks and the next 4, plus a psychiatric follow-up in 3 weeks.
- Journal: ~25 entries over 6 weeks with a realistic mood variation (including some harder days, **no crisis content in the seed data**).
- Prescriptions: 2 active (e.g. sertraline 50 mg – 9 days left; hydroxyzine 25 mg as needed – 20 days left), 1 with a pending extension.
- Messages: a short, realistic thread with reply-time stamps.
- Use **illustrated avatars or initials** for clinicians – no stock photos of real people.

---

## 11. Accessibility & HIG checklist (part of Definition of Done)
- [ ] Dynamic Type up to the largest accessibility sizes, no truncated critical text (test at AX5)
- [ ] VoiceOver labels/hints on every control; mood faces announce their meaning ("Mood: low")
- [ ] Tap targets ≥ 44×44 pt
- [ ] Contrast ≥ 4.5:1 body / 3:1 large text & UI, in light **and** dark mode
- [ ] Reduce Motion and Reduce Transparency respected
- [ ] Meaning never conveyed by colour alone (mood = face + label)
- [ ] Key actions within thumb reach; swipe-back works everywhere; swipe actions on lists
- [ ] Portrait-first; layouts don't break in landscape
- [ ] Safe areas respected; 16-pt margins

---

## 12. Research task: daily mood pop-up
**Question:** Would patients be frustrated if a daily mood pop-up greeted them when they open the app?
- **Phase 1 default:** a **non-blocking, skippable mood card on Home** (no modal). Add a setting "Daily check-in reminder" (off / notification at chosen time).
- **Put a feature flag in place** (`moodCheckInStyle: .card | .modal`) so both variants can be shown in usability tests.
- **Deliver `docs/research/mood-checkin-study.md`** containing:
  - Hypothesis (a blocking modal increases friction and guilt, especially on low-mood days, for patients like Marek; the card is preferred).
  - A 5-minute unmoderated test script comparing both variants (tasks + Likert questions + 2 open questions).
  - A short survey (≤ 8 questions) for patients of the clinic.
  - Trauma-informed research notes: informed consent, opt-out at any time, no triggering tasks, debrief, crisis numbers in the participant info sheet.

---

## 13. Build plan (3 days)

**Day 1 – Foundation & design system**
- Xcode project, folder structure, String Catalog, Asset Catalog colour tokens (light/dark), typography helpers, core components (cards, capsule buttons, week strip, mood character + slider, chips, banners).
- Mock services + seed data; SwiftData models.
- Onboarding flow, tab bar, Home screen.

**Day 2 – Core features**
- Visits (calendar, list, detail), Online visit flow (location check → waiting room → mock call).
- Journal (check-in, entries, editor, sharing, mood calendar, pre-visit summary).
- Prescriptions (list, request extension, statuses, discreet reminders).
- Messages (thread, response hours, emergency banner).

**Day 3 – Safety, privacy, polish, portfolio**
- CrisisDetector + tests, Crisis screen, Home Screen quick action, Safety alert consent flow.
- Face ID lock, privacy shield, Profile & Privacy centre.
- Accessibility pass (§11), Dark Mode pass, motion polish.
- Research doc (§12), portfolio deliverables (§14).

If time runs short, cut in this order: data export mock → grounding exercise → Add to Calendar → reception thread. **Never cut:** crisis screen, privacy defaults, consent screens, accessibility basics.

---

## 14. Portfolio deliverables
- `README.md` as a short **case study**: problem, personas, pain points → solutions, key design decisions (privacy-by-default journal, consent-based safety alert, no-streak mood tracking, bounded messaging), accessibility, what's mocked vs production-ready, roadmap.
- **Screenshots** of every key screen, light + dark, at default and large Dynamic Type (use Xcode previews / simulator; store in `docs/screenshots/`).
- SwiftUI `#Preview`s for every screen and component.
- A short screen recording script (`docs/demo-script.md`) walking through Anna's week: check-in → journal → pre-visit summary → online visit → message → prescription extension → crisis screen.

---

## 15. Later phases (keep the architecture ready – do not build now)
- **Phase 2 – Doctor & Admin (web first):**
  - Doctor: patient list, schedule, shared journal/mood trends, red-flag inbox (flags only), messaging with office hours and auto-replies, visit notes with role-based access.
  - Admin: staff and roles, rooms (*gabinety*), schedules, access grants and revocation, audit log viewer.
- **Phase 3 – Production backend & Android:** E2EE messaging/video, 2FA, audit logs, encryption at rest, EU hosting, GDPR Art. 9 processes (DPIA, records of processing, data processing agreement with the clinic).
- **Phase 4 – Polish health system integration:** P1 / Centrum e-Zdrowia – e-Recepta (incl. psychotropic medicines) and e-ZLA (sick leave) issued by doctors using a ZUS certificate / Profil Zaufany; patient identity verification at the first online visit (ID shown on camera, or mojeID / Węzeł Krajowy); intake triage questionnaire (psychologist first vs psychiatrist directly). Polish localisation. Pilot with one clinic.
- **Before selling:** have a lawyer check whether symptom tracking + crisis detection makes the app medical-device software under EU MDR; get psychiatrists to clinically validate the crisis logic and copy.

---

## 16. Definition of Done (Phase 1)
- App builds and runs on the latest iOS simulator with no warnings that matter; no third-party dependencies.
- Every screen in §7 is reachable and works with mock data; journal data persists across launches.
- Crisis screen is reachable in ≤ 2 taps from every screen and via the Home Screen quick action; the detector triggers on the test phrases and never blocks saving or sending.
- Journal is private by default; every share is explicit, previewed and revocable.
- No drug names or journal text appear in notifications, Spotlight, widgets or the app switcher.
- §11 checklist passes in light and dark mode.
- All strings live in `Localizable.xcstrings`.
- README case study, screenshots, research doc and demo script are delivered.
