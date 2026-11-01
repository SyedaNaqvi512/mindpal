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
