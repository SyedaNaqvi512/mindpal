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
