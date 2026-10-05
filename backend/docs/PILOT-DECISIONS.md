# Confirmed pilot configuration — 5 October 2026

- Small university pilot; no public release or cloud deployment yet.
- Business data, credentials, API compute and backups must be located in Australia. Target Sydney (australia-southeast1), subject to provider terms review. No real project has been created.
- Unique case-insensitive usernames plus passwords, separate display names. No email or Google sign-in required.
- Pilot administrator provisions accounts and resets passwords. Temporary passwords must be changed before household access. The person performing recovery must verify the participant out of band.
- Only the pilot administrator assigns/removes caregiver privileges. Owners may invite ordinary members/viewers. Ownership transfer changes the previous owner to member, not caregiver.
- Deleted items recoverable for three calendar months. UTC month arithmetic clamps the day at month-end. Restore removes the expiry field; expired tombstones are omitted from API snapshots. Firestore TTL declarations are supplied but not deployed or emulated automatically.
- Backups should expire after three calendar months. This is a policy, not a running backup service. Backup scheduling, a restoration drill and erasure of deleted data from restored backups remain release requirements. A live tombstone plus snapshot retention can otherwise extend actual recoverability beyond three months; the production design must explicitly prevent this if three months is the total erasure deadline.

## Authentication change

Firebase documents that Firebase Authentication processes data exclusively in the US: https://firebase.google.com/support/privacy . It is therefore not approved for production under this requirement. Existing Firebase Auth usage is restricted to local legacy regression tests. The default local API now uses its own Firestore-backed pilot account/session store and does not call Firebase Authentication for participant login.

Credentials use salted scrypt (N=32768, r=8, p=1); session tokens use 32 random bytes and only their SHA-256 digests are stored. Sessions expire after eight hours. Password reset/change increments sessionVersion, immediately invalidating previous tokens. Database client rules deny account/session access. Production must add distributed login throttling, credential/security review, TLS, restricted database IAM, secrets management and a secure deployment-only admin bootstrap. Australian hosting alone does not prove that all provider service metadata and support processing stay in Australia; review those terms before enrolling real people.

## Implemented API additions

POST /api/login — username/password.
POST /api/logout — revoke current bearer session.
POST /api/password — currentPassword/newPassword, then sign in again.
POST /api/admin/accounts — provision username/displayName/password (temporary).
POST /api/admin/reset — username/temporaryPassword.
POST /api/admin/households/:hid/caregiver — username/enabled.
POST /api/me — profile and authorised household discovery.
POST /api/households/:hid/snapshot — listId; coherent list/items/rules read.
POST /api/households/:hid/lists — name/requestId.
POST /api/households/:hid/lists/:lid/items — full item mutation, requestId, expectedRevision, ruleRevision.
POST /api/households/:hid/lists/:lid/items/:iid/delete or /restore.
POST /api/households/:hid/safety-rules/:productKey — maximum/mode/expectedRevision/requestId.

List mutations are transactional, household/role checked, revision checked and idempotent. Quantity limits aggregate all unpurchased active rows of the same product. A stale rule revision cannot confirm a warning. Deletion and restore share list concurrency control. Audit events avoid private notes and password/token payloads.

## Remaining before an end-to-end pilot

1. Login/admin/recovery screens and the shared-data adapter. Existing six shopping wireframes remain unchanged; the current PWA still uses its old local store.
2. Real-time delivery, offline command outbox, conflict presentation and explicit local-data import.
3. Remaining list operations (copy/rename/archive), rule deletion, retention-worker staging verification, and full recovery/export workflows.
4. Production account provisioning, administrator identity, Australian infrastructure, budget, backups/restore, monitoring, distributed throttling and load/security review.

Do not claim all Jira tasks or production readiness are complete. No participant accounts have been provisioned by the assistant. The tests create disposable local accounts only.
