# Research: Daily mood check-in — card or pop-up?

**Question:** Would patients be frustrated if a daily mood pop-up greeted them when they open the app?

**Phase 1 default:** a non-blocking, skippable mood card on Home. A feature flag (`AppSettings.moodCheckInStyle: .card | .modal`, exposed under *Profile → Research & demo*) switches to a launch pop-up so both variants can be tested with the same build.

---

## 1. Hypothesis

> A blocking check-in modal on launch increases friction and guilt — especially on low-mood days and for patients with low energy or low tech confidence (persona: *Marek, 52*). Patients will prefer the non-blocking Home card, report less pressure, and check in at a similar or higher rate.

| | Card (A) | Modal (B) |
|---|---|---|
| Expected time-to-goal for non-check-in tasks | Lower | Higher (extra dismissal) |
| Expected perceived pressure | Lower | Higher, esp. on hard days |
| Expected check-in rate | Similar | Similar or slightly higher short-term, lower long-term (avoidance) |

**Success signals for the card:** pressure rating ≤ 2/5 on average; no increase in "I'd avoid opening the app" responses; check-in completion within 10 % of the modal.

---

## 2. Five-minute unmoderated test (within-subjects, counterbalanced)

**Setup:** TestFlight build with demo data. Half the participants see A then B, half see B then A. The flag is switched by the facilitator script, not the participant. Screen + tap recording only — **no face camera, no audio of free speech**.

**Before starting (on screen):** "This is a test of the app, not of you. There are no right or wrong answers. You can stop at any time by closing the app – nothing you did will be kept beyond the recording you agreed to. Please don't type anything personal; pretend to be 'Anna'."

### Tasks (per variant)

1. *Open the app and find out when your next visit is.* (Measures: time to Next Visit card; whether the check-in was done, skipped or dismissed.)
2. *You're having an okay day. Record how you feel, if you want to.* (Measures: time to save; number of taps.)
3. *Imagine it's a hard day and you only opened the app to message your clinic. Do that.* (Measures: time to Messages; dismissal behaviour.)

### After each variant — Likert (1 = strongly disagree … 5 = strongly agree)

1. Opening the app felt calm.
2. I felt pressured to record my mood.
3. On a hard day, this would make me less likely to open the app.
4. It was easy to get to what I came for.

### After both variants — open questions

1. Which version would you rather use every day, and why?
2. Was there any moment you felt judged or rushed? What happened?

**Analysis:** Wilcoxon signed-rank on Likert items (paired); median task times; thematic coding of open answers (two coders, agreement check). Report effect sizes, not just p-values — the sample will be small (target 12–16).

---

## 3. Short survey for clinic patients (≤ 8 questions, anonymous)

Distributed by reception on paper or via a link; no login, no names, no clinical data.

1. How often would you like to record how you feel? *(Several times a day / Once a day / A few times a week / Only when something happens / Never)*
2. If the app asked "How are you today?" every time you opened it, how would you feel? *(Supported / Neutral / Pressured / Annoyed / Not sure)*
3. On difficult days, how much effort would answering one question feel like? *(1 = no effort … 5 = too much)*
4. Would you prefer to be reminded with a notification at a time you choose? *(Yes / No / Not sure)*
5. If you skipped a few days, how would you want the app to respond? *(Say nothing / A gentle "welcome back" / Show what I missed / Not sure)*
6. Who should be able to see your mood records? *(Only me / Me, and my clinician if I choose / My clinician always / Not sure)*
7. How comfortable are you using apps on your phone? *(1–5)*
8. Anything else you'd like us to know? *(free text, optional)*

---

## 4. Trauma-informed research notes

- **Informed consent:** plain-language information sheet; explicit consent for screen recording; separate optional consent for quotes. Participants may withdraw up to 14 days after the session, and their data is deleted.
- **Opt-out at any time:** every screen of the test says how to stop. Stopping is never questioned or followed up with pressure.
- **No triggering tasks:** participants role-play "Anna" with fictional data. No task asks them to recall or describe their own difficult experiences. The crisis screen is **not** a test task.
- **Recruitment through the clinic, not by clinicians treating the participant**, so no one feels their care depends on taking part. Participation is voluntary and has no effect on treatment.
- **Debrief:** after the session, a short thank-you screen explains what was tested and why, and invites questions to a named researcher (not the participant's clinician).
- **Crisis numbers on the participant information sheet and debrief screen:** 112 (emergency), 116 123 (crisis support line for adults), 800 70 2222 (24/7 support centre for adults in mental crisis), 116 111 (children and young people). *Verify before use.*
- **Data minimisation:** no names in recordings; participant IDs only; recordings stored encrypted in the EU and deleted after analysis (max. 6 months).
- **Accessibility:** offer large-text and VoiceOver participants the same tasks; allow extra time; provide the survey in Polish when localisation lands.
- **Ethics:** check with the clinic whether review by a bioethics committee is required for research with patients; involve a clinician in reviewing materials.
