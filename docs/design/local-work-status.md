# Stage 1 — local work

Stage 1 source is prepared on branch `SAV` for the user-authorized branch-only push. Main is not merged or modified. No Figma or Jira changes were made after the user's local-only instruction.

## Architecture

- Flutter web application with a local JavaScript bridge for browser Web Crypto, encrypted storage, optional on-device speech and optional platform-authenticator key wrapping.
- One encrypted household vault per browser profile/origin; member names identify item responsibility, not separate authenticated users or remotely invited accounts.
- AES-256-GCM protects the serialized data. A random data key is wrapped with a PBKDF2-SHA-256 passphrase key (600,000 iterations, random salt). Fresh nonces are used per encryption. Neither passphrase nor plaintext lists are stored in localStorage.
- Device unlock, when supported, wraps the data key using a WebAuthn PRF result from a platform authenticator requiring user verification. Passphrase unlock remains available.
- Writes are serialized. Storage failures remain visible and block locking until retry succeeds or the user explicitly discards unsaved edits. Stale tabs cannot silently overwrite a newer vault.
- Locking removes the key and visible household data from the session. An inactivity timer locks the app; background browser timer throttling can delay it. Use the Lock button when leaving a shared device.
- No production security audit has been performed. An unlocked browser session or compromised local code/device can access plaintext; this is local at-rest protection.
- Local resources only: bundled fonts and CanvasKit, a same-origin content security policy, no app analytics or cloud API calls.

## Local behaviour and limits

- Lists, preferences, household members, reminders and items survive refresh after successful save.
- Copies use fresh IDs, preserve item detail, reset purchase status and do not copy reminders.
- Removing a member unassigns their items. Item removal requires confirmation and provides Undo.
- Recommendations rank previous items and favourites while excluding items already on the active list. This is a local rules-based recommender, not a language model.
- Reminders appear while open/unlocked, and overdue reminders reappear on the next unlock. They can be dismissed, cancelled or postponed by an hour. No closed-app system notifications.
- Voice recognition requires an installed on-device en-US model and supporting browser API. Unsupported cases retain text entry. Recognised text is reviewed before adding.
- Real voice capture and device unlock still require hardware/browser acceptance testing. No microphone recording or credential enrollment was initiated on the user's behalf.
- Browser data clearing loses the vault. No password recovery, cross-device sync, cloud backups, account roles or native-platform adapters are claimed.

## Validation

Flutter analysis, model/widget tests and a local web release build are recorded in the delivery checklist. JavaScript tests cover encrypted account creation, incorrect passwords, refresh persistence, locked-write rejection, tamper rejection, storage exhaustion, stale-tab protection, unsupported speech/device fallbacks and simulated PRF wrapping.

A simulated authenticator test does not verify physical biometrics. Passing a doubled-text widget test does not establish full accessibility compliance.

## Review

Use the release on http://127.0.0.1:5188 and create a passphrase directly in the app. The earlier memory-only preview on 5187 is superseded. Approval to merge or publish has not been given.

## Stage 1 final review

Fixed autocomplete category refresh, explicit recovery from failed/stale saves, device-setting coordination with pending saves, cross-tab write races, cancellation during speech capability detection, and offline heading/button fonts. Both the theme font and Flutter default Roboto are bundled; fallback URLs stay on the local origin.

Task evidence is saved outside the repository in Documents/capstone tasks. It contains screenshots for all 22 IDs in the latest supplied list; voice and physical biometric completion are explicitly unverified. App labels use Stage 1. The Git branch remains SAV and the legacy storage identifier remains unchanged to preserve the existing encrypted vault.
