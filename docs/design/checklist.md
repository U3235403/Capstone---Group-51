# Stage 1 local delivery checklist

Source: the two task screenshots supplied by the user. The screenshots contain titles, not detailed acceptance criteria. A tick below means the stated **offline local scope** has been implemented and tested; it does not update or close a Jira ticket.

## Implemented locally

- [x] SCRUM-51 — Secure login: local passphrase account, encrypted saved vault, lock/unlock and inactivity lock. No cloud identity or password recovery.
- [x] SCRUM-64 — Household setup: household name, local member names, duplicate-name validation and safe member removal. No remote invitations.
- [x] SCRUM-73 — Settings & preferences: saved text size, contrast, motion and inactivity timeout.
- [x] SCRUM-92 — Copy an existing list: independent IDs, retained details and cleared purchased status.
- [x] SCRUM-104 — Add, edit, delete, update items: validated forms, discard protection, delete confirmation and Undo.
- [x] SCRUM-113 — Mark item as purchased: reversible state and remaining/purchased counts.
- [x] SCRUM-119 — Mark item as favourite: persisted star action and favourites filter.
- [x] SCRUM-124 — Categorise items: eight selectable categories and category-aware autocomplete.
- [x] SCRUM-129 — Item details: name, quantity, unit, category, assignment, purchase and favourite status.
- [x] SCRUM-133 — Notes on items: editable notes, saved with each item and searchable.
- [x] SCRUM-137 — Search, Sort & Filter: combined controls with visible reset action and no-match state.
- [x] SCRUM-141 — Filter items: category, purchase state, favourite and responsible member.
- [x] SCRUM-147 — Sort items: added order, name, category and quantity without changing saved order.
- [x] SCRUM-155 — Assign responsibility: household member selection and unassignment when a member is removed.
- [x] SCRUM-159 — Input Methods & Accessibility: labelled text/touch controls, keyboard-ready Flutter controls, scrollable forms, validation, and text fallback. Voice/device limitations remain below.
- [x] SCRUM-162 — Text entry with autocomplete: local common items and saved history; selection remains optional.
- [x] SCRUM-177 — Accessible display: larger text, higher contrast, reduced motion and a passing doubled-text phone-layout test. Full assistive-technology review remains recommended.
- [x] SCRUM-184 — AI & Smart Assistance: offline rules-based suggestions, explained to the user and never added automatically. No external AI or generative model.
- [x] SCRUM-188 — Shopping reminders: persistent scheduled in-app reminders, overdue display, cancel, dismiss and postpone. App must be open/unlocked for a reminder to appear.
- [x] SCRUM-192 — Intelligent list recommendations: ranked previous items/favourites, excluding items already on the current list.

## Implemented paths, not yet accepted as complete

- [ ] SCRUM-166 — Voice entry: on-device-only recognition path and graceful fallback implemented. Actual microphone/transcription requires a supporting browser and installed English model. No cloud fallback.
- [ ] SCRUM-172 — Biometric activation: platform-authenticator PRF enrollment/unlock path implemented. Actual supported device verification is outstanding; an authenticator may use a device PIN rather than biometrics. Simulated cryptographic tests are not a physical biometric test.

## Validation evidence

- Flutter static analysis: no issues.
- Flutter model/widget suite: all 18 tests passed, covering persistence serialization, copies, combined filters/sorting, household settings, member removal, recommendations, failed-save recovery, queued writes, item flows, large text, voice fallback, reminders and lock.
- JavaScript service tests: encrypted storage, wrong passphrase, reload, tampering, storage failure, stale tabs, unsupported capability paths and simulated PRF wrapping.
- Release build: local fonts/renderer with CDN resources disabled.
- Browser evidence is recorded separately by task ID; screenshots illustrate visible states and do not independently prove cryptographic or hardware behavior.
- Only the `SAV` source branch is authorized for push. No merge, deployment or online Jira/Figma edits.

## Try the app

1. Open http://127.0.0.1:5188 and create your own passphrase.
2. Open Household & settings, name the household and add a member.
3. Add Milk, select a category/member, add a note, and mark it favourite.
4. Mark it purchased, edit it, remove it and use Undo.
5. Copy the list; copied items start unpurchased. Create a fresh list to see history suggestions.
6. Try search and combined filters. Set a reminder and change display preferences.
7. Lock and unlock or refresh: saved data returns after successful authentication.

Keep the same URL/port and browser profile to access the same local vault. Clearing site data removes it.
