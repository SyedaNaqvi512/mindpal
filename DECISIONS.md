# MindPal decisions

Where the build deliberately differs from SRS v1.1, it is recorded here.

## D-01 AI quota counts successful reflections only

NFR-13 limits reflections per hour and per day. The server counts only successful
reflections toward 10 per hour and 30 per day, so a failed attempt (AI down, timeout)
does not use up the user's allowance. A separate cap of 30 attempts per hour stops abuse.

## D-02 Routes have no /api/v1 prefix

The SRS lists paths such as `/api/v1/me` and `/api/v1/reflections`. The build uses
`/auth/...`, `/me`, `/me/consents/...` and `/reflect`. The behaviour is the same.
Versioning can be added at the reverse proxy if it is ever needed.

## D-03 Quick reflection is rule-based, not AI

When the cloud is unavailable, the app offers a basic reflection built from phrase
matching and a fixed template, using the nine patterns of FR-21. It needs no model
and no network, and it is labelled as basic. The on-device Gemma model (about 3 GB)
stays an optional Private mode (FR-26, Could priority).

## D-04 Consent is checked before the first cloud use and enforced by the server

The app shows the consent sheet before the first cloud reflection (FR-17). The server
stores the consent with a timestamp and a policy version, and `/reflect` returns 403
`consent_required` without an active consent. Safety screening runs before the consent
check, so a high-risk entry always gets the support message, with or without consent.

## D-05 Gender and code-attempt columns added to the server schema

`users.gender` (female, male, unspecified) chooses which avatar set the profile shows,
and `one_time_tokens.attempts` counts wrong guesses so a code stops working after five.
Both are small additions to the Section 8.2 tables.

## D-06 Emailed one-time code instead of an emailed link

FR-03 and FR-06 say "link". The app uses a six-digit code that expires in 10 minutes.
A link needs deep-link setup on the phone; a code does the same job and works the same
on every device. A new code can be requested after 60 seconds, and a code dies after five
wrong guesses.

## D-07 Verification is on by default

`Auth:RequireEmailVerification` defaults to true. Register sends a code and returns no
tokens; the user gets tokens only after entering the code. Setting it to false skips the
check (for local testing only).

## D-08 Mood shown as emoji + word, stored as 1-5

**SRS:** FR-10 says a mood rating from 1 (very low) to 5 (very good).
**Decision:** The app shows five emojis, each with a word (Very low, Low, Okay, Good, Very good).
The database and the server contract still use the number 1-5, so the SRS rule and the Insights
calculations are unchanged. The word is always shown with the emoji so the choice is clear and accessible.

## D-09 Entry is saved before any reflection

**SRS:** FR-09 and FR-10 require saving an entry; the earlier build saved only after a reflection.
**Decision:** "Save entry" stores the entry on the phone without any AI. "Save and reflect" saves
first, then asks for the reflection, so a failed or refused reflection never loses the text.
One reflection is kept per entry; reflecting again replaces it.

## D-10 Voice dictation uses the phone's speech recognition

**SRS:** FR-11, FR-12.
**Decision:** The `speech_to_text` plugin returns text only; MindPal never records, keeps or uploads
an audio file. The Android recogniser may use the phone's speech service (often Google's) to
convert speech, which the screen explains in one line.

## D-11 Reflection is a draft until the user decides, and is rated separately

**SRS:** FR-23, FR-24.
**Decision:** A new reflection is saved on the phone as a draft, so it survives closing the app.
The user can Accept, Edit or Dismiss it; Dismiss deletes it. An edited reflection is kept as plain text.
The rating (helpful or not helpful, with an optional reason category) is stored on the phone and sent to
`POST /reflections/{id}/feedback`. Only the rating and the reason are sent, never the entry text.
Quick and on-device reflections have no server record, so their rating stays on the phone.

## D-12 Campus-support information is not shown

**SRS:** FR-19 asks for verified helpline and campus-support information.
**Decision:** PTUT has no counselling or campus-support service we can verify, so the support card
shows the verified helpline, the emergency-services line and the "trusted person" advice only.
A campus contact will be added in `support_info.dart` if one is confirmed later. Nothing is invented.

## D-13 Android backup is off for the encrypted journal

The journal database is encrypted with a key kept in the phone's secure storage. Android cannot
back that key up, so a restored database file could never be opened. `allowBackup="false"` avoids
that broken state. Journal text stays only on the device by design, so uninstalling the app removes
it. A user-controlled export and import is the planned way to move entries to a new phone.

## D-14 Insights are worked out on the phone

**SRS:** FR-27 to FR-29.
The calendar, the weekly and monthly trend and the common patterns are calculated from the local
database. Only the mood number, the date and the pattern name are read; the entry text is not. The
server is not involved. The week starts on Monday. A day with several entries shows their average mood.

## D-15 Account deletion: sign-in blocked at once, data purged within 24 hours

**SRS:** FR-34, NFR-16 (server data removed within 7 days).
**Decision:** `POST /me/delete` (the user confirms with the password) marks the account
`pending_deletion`, revokes every refresh token and one-time code, and from that moment the account
cannot sign in or refresh, and existing access tokens stop working (they are checked against the
account status on every request). A background job runs every hour and deletes accounts 24 hours
after the request; the database's ON DELETE CASCADE removes tokens, consents, usage logs, ratings and
activity days. 24 hours is well inside the 7-day limit. The app then erases the local database, its
key and the saved settings (the theme is kept). Anonymous counts (safety and exercise events) hold
no user id and stay.

## D-16 App lock (FR-32)

The app lock is a screen lock: a 4-digit PIN with optional fingerprint (local_auth, biometric only). The PIN and the answers to three recovery questions are stored only as salted PBKDF2-SHA256 hashes in the phone's secure storage. A PIN can never be shown, so "forgot PIN" lets the user choose a new one after answering all three questions correctly. After every 5 wrong tries (PIN or answers) the lock waits 1, then 5, then 15 minutes. The lock engages on start and whenever the app goes to the background. The journal is already encrypted with its own key (D-13), so the PIN does not encrypt data; this is stated so it is not mistaken for encryption. Turning the lock off or changing the PIN needs the current PIN. Account deletion clears the lock data.

## D-17 Daily reminder (FR-30)

The reminder is a local notification (flutter_local_notifications) with fixed, non-sensitive text, scheduled with inexact allow-while-idle timing, so no exact-alarm permission is needed. It may arrive a few minutes late on some phones. It is re-scheduled on every app start and after a reboot. Nothing about it is sent to the server.

## D-18 Email delivery through Brevo's HTTPS API

Verification and password-reset codes go through an `IEmailSender`. In deployment the sender is `BrevoEmailSender`, which calls Brevo's HTTPS API, as SRS section 2.7 requires, because the free web host blocks SMTP ports. `SmtpEmailSender` (Gmail) remains for local development only and is chosen with `Email:Provider` (default `Smtp`, deployment sets `Brevo`). Only the recipient address, display name and the message text are sent (TB-D); the code is never logged. Known limit of the free beta: mail sent from a Gmail address as sender may reach the spam folder, because Gmail's policy distrusts mail from its addresses sent by other servers. Reliable delivery needs a sender on a domain owned by the project with SPF/DKIM set up; this is planned before real users.
## D-19 Guided exercises (SRS 3.5)

**SRS:** FR-35 to FR-53, FR-70 to FR-73.
**Decision:** The Exercise Library is reached from Home and holds 13 exercises: Facts vs Assumptions Sort (M); Thought Balance Scale, Belief Slider, Breathing Bubble and 5-4-3-2-1 Grounding (S); Thought Record, Gratitude, Self-Compassion, Problem-Solving, Daily Check-In, STOP, Anchoring phrase and Body scan (C). Each exercise is a list of steps built from touch controls (drag, slide, tap) with an introduction and estimated time first, a Skip button when a step is left empty, and "Finish later" at any time. Nothing shows points, levels, ranks, lives, penalties or failure messages, and every screen carries the label "Guided self-reflection activity. Not therapy or treatment."
**Storage:** one table, `exercise_sessions`, in the existing SQLCipher database (version 5). An unfinished session keeps its answers and current step so it can be resumed or discarded; a finished one is the Exercise Progress list. Answers can be deleted one by one or all at once, deleting a journal entry removes the exercises attached to it (ON DELETE CASCADE), and account deletion removes the whole database (FR-34). Nothing about exercises is sent to the server.
**Safety:** every free-text box in an exercise uses `SafeTextField`, which runs the same on-device screening as journal entries (FR-18) and shows the support message (FR-19) when it triggers.
**Suggestions:** after an accepted reflection, one Suggested Exercise card is chosen from the named thinking pattern with the table in SRS 3.5; if that exercise is not in the app the fallback is used, and if neither is, no card is shown. STOP, Anchoring phrase and Body scan are never suggested. The user may dismiss the card.
**Prefill (FR-47):** an exercise opened from an entry asks "Use the words from your journal entry?" and only copies the text if the user taps Use it.
**Balanced thought (FR-48):** the thought-based exercises end with an optional balanced-thought step; it is saved with the exercise and shown under "Exercises for this entry" on the entry.
**Reduce motion (FR-53):** the breathing bubble stays still and only its words change, the scale does not animate, and the timer bars are hidden. Every function still works.

## D-20 History search and token cleanup

**SRS:** FR-15 (search and filtering), NFR-16 (data kept no longer than needed).
**Search:** the text typed in History is split into words. An entry matches only if every word is found, in any order and ignoring case, in the entry text, in one of its feeling tags, or in the name of its thinking pattern (for example "all-or-nothing" finds the pattern all_or_nothing). The found words are marked in the list and the list starts near the first match when it is far into a long entry. The result count is shown. The mood and date filters can be combined with the words. All of this runs on the phone against the encrypted database. An earlier version of the query had a missing bracket and failed whenever a word was typed; this is fixed.
**Cleanup job:** `TokenCleanupService` runs every 6 hours and deletes refresh tokens and e-mail codes that expired more than one day ago. A token is kept until it expires so reuse of a revoked token is still noticed. Users do not see this job.

## D-21 Admin portal access and RBAC (FR-54)

**SRS:** FR-54, NFR security.
**Decision:** The admin portal is a separate web app (React, Vite, TypeScript) that signs in through the same `/auth/login` endpoint as the phone app. Access is role-based: the access token carries a `role` claim (`user` or `admin`), and every `/admin/*` route needs the `admin` policy. A route filter then checks the database on every request that the caller still exists, is an `admin` and is `active`, so a demoted or suspended admin loses access at once instead of when the token expires. A non-admin who signs in to the portal is signed out straight away and sees "This account does not have admin access". Admin routes are rate limited (120 per minute per user).
**First admin:** there is no sign-up for admins. `AdminSeeder` reads `Admin:Email` and `Admin:Password` (user secrets or environment variables) at start-up and creates the account, or promotes an existing one. It never changes the password of an existing account, and does nothing if the settings are empty.
**Browser access:** CORS is allowed only for the origins in `Cors:AdminOrigins` (localhost:5173 and 4173 in development).
**Tokens in the portal:** the access token is kept in memory and the refresh token in sessionStorage, which is cleared when the tab closes.

## D-22 Admin statistics are counts only (FR-55, FR-57 to FR-61)

**Decision:** The portal never receives journal text, reflection text or exercise answers. It shows: total users, new registrations, daily active users and reflections per day (FR-55); AI requests, average response time of successful requests, errors and rate-limit counts (FR-57); anonymous safety-screening counts per day (FR-58); API and database status with recent error counts (FR-59); the share of reflections rated helpful and the reason categories (FR-60); and completed exercises per type (FR-61).
**Days:** a day is an Asia/Karachi day (UTC+5, no daylight saving). Events are fetched as UTC times and grouped into Karachi days in memory, so the rule is plain C# that is unit tested, and every day in the range is filled with zero when nothing happened. A daily active user is a person who signed in or refreshed a token that day. Ranges are limited to 7, 14, 30 or 90 days (maximum 90).
**Health:** unexpected server errors are counted by `ErrorCounter` (time stamps only, kept 24 hours, in memory, so it resets when the server restarts). AI errors and rate limits come from the usage log.
**Exercises (FR-61):** the phone sends `POST /telemetry/exercise` with only the exercise type after a local save. The server accepts only the 13 known type names, writes an `ExerciseEvent` with no user id and rate limits the endpoint. If the request fails the exercise is not affected.

## D-23 Managing users (FR-56)

**Decision:** The portal lists users (newest first, 15 per page) and searches by part of the e-mail address. Suspend, Reactivate and Process deletion each ask for confirmation. Rules (unit tested): an admin cannot suspend themselves or another admin; only an `active` account can be suspended; only a `suspended` account can be reactivated; only a `pending_deletion` account can be deleted by an admin. Suspending sets the status and revokes all the user's refresh tokens, so they are signed out everywhere. Processing a deletion removes the user row and everything that cascades from it, the same result as the automatic purge. Admin actions are logged with user ids only, never with e-mail or text.

## D-24 Learn about mindfulness (FR-64 to FR-69) and UX polish

**Learn:** five original articles (what mindfulness is; why it may help; how it connects to CBT reframing in MindPal; simple ways to practise; not therapy and when to get help) are bundled as Dart constants. They work offline, use no server and no AI, and store nothing about the reader. The wording is careful ("may help"), makes no health claims, quotes no study (a study may be added only with its original source named), and recommends no product. Every article ends with the note "MindPal is not therapy...". The practice article opens a five-minute Breathing Bubble (25 breaths of 12 seconds, nothing saved); the help article opens a Help & support screen with the verified helpline. Learn is reached from a Home card and from the Exercise Library, and the bottom bar stays at four items.
**Toasts:** `Toast` shows short results (saved, deleted, password changed, could not save) as a floating card with an icon (green, red or purple), on top of the existing snack bar theme.
**Responsive:** `ResponsiveFrame`, installed in `MaterialApp.builder`, limits the app to 720 px wide and centres it on tablets and landscape phones. On a normal phone it changes nothing.

## D-25 On-device AI model removed from the screens

**Decision:** The "On this phone" reflection option was removed from the entry screen. The model (Gemma, about 3 GB) is too large to download for most users, is slow on ordinary phones, and was not working on the test phone. The Part 3 follow-up conversation also runs on the server, so a second mode would behave differently. **What stays:** the entry is checked for safety on the phone first, text is sent to the AI only after the user agrees, the server stores no journal text, and the offline Quick reflection (no model, no download) is offered when there is no connection or the AI fails. The on-device code is kept in the repository but cannot be reached from any screen, so it can be restored later.

## D-26 Exercises: completion rules and guided steps

**Decision:** Every step can still be skipped (FR-41), but an exercise is saved as Completed, and its telemetry sent, only when the answers that matter for it were given. `evaluateCompletion` (pure, unit tested) holds one rule per exercise: for example a thought record needs a situation, a thought, a feeling and evidence for and against; gratitude needs three things and a reason; the breathing bubble and anchor phrase need the bubble to finish; the body scan needs at least 80% of its areas read for most of the suggested time. Filler such as "aaa" or "..." does not count. When the rule is not met, the last step shows what is still needed and offers Save for later instead of Finish. **Content:** every step has a short "why this helps" note and, where useful, an example. After finishing, a summary shows what the user did, how many steps were skipped, and an optional "How do you feel now?" (no scoring, FR-43). The not-therapy label is kept.

## D-27 Typography: a display serif for titles, Nunito for everything else

**Decision:** Titles (the display, headline and large title styles, so screen titles, greetings, sheet titles and article titles) use Fraunces, a soft serif with a warm, journal-like feel. Body text, buttons, labels and controls stay in Nunito. Both are open fonts under the SIL Open Font License (the licence files are in assets/fonts). They are bundled, so nothing is downloaded and the app works offline. Static weights were generated from the variable fonts: Nunito 400, 500, 600, 700 and 800; Fraunces 500, 600 and 700. **Scale:** body 16 sp with a 1.5 line height (SRS 5.3); section titles Nunito 800 at 17 sp; labels 700. **Loading:** lists and charts show soft placeholder cards (skeletons) instead of a spinner, so the screen keeps its shape. They rest after 60 s and stay still with Reduce motion.

## D-28 Four complete looks, one for each theme

**Decision:** A theme is now a whole look, not only a set of colours. `AppLook` (`core/theme/app_look.dart`) is carried in `ThemeData` and read with `AppLook.of(context)`. Each palette has its own look: **Lavender Dream = Soft & Rounded** (Fraunces and Nunito, 28 px raised cards with a soft shadow, pill buttons, colour blobs behind the screens, a floating rounded navigation bar, round illustrations, springy movement); **Rose & Cream = Paper Journal** (Playfair Display and Lora, 6 px cards with a thin ink outline and no shadow, ruled-paper background, notebook-tab navigation, framed "stamp" illustrations, calm page-turn fades); **Sky Mist = Clean & Minimal** (Manrope, flat 4 px cards with a hairline, square buttons and fields, a flat single-colour header with a straight edge, plain background, a flat bar with a line over the chosen item, dot-grid illustrations, short quick movements with almost no travel); **Midnight Lavender = Night Glow** (Cormorant Garamond and Nunito, glowing card edges, a still star field, a glowing dark navigation bar, moon-like illustrations, slow drifting movement). System follows the phone (Soft by day, Night at night).
**What follows the look:** card, field, button, sheet and header shapes; heading and body fonts (four new open fonts bundled, licences in assets/fonts); the page background (`AppBackdrop`, painted once under every page route, so a page never shows the one behind it while it slides in); header and empty-state art (`HeaderArt`, `LookBadge`); the navigation bar; and all motion (enter curve, slide distance, pop curve, press size, float distance, speed, and the shape of the finish celebration: confetti, petals, rings or sparkles).
**Rules kept:** no endless animations (every loop still rests), Reduce motion switches movement off in every look, all colours still pass the WCAG contrast tests, nothing about privacy or exercises changed.