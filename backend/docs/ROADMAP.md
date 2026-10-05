# Backend delivery order

| Milestone | Deliverable | Acceptance gate | State |
|---|---|---|---|
| 1. Database | Firestore schema, indexes, access rules, local emulators, seed | Member/outsider/revocation/privilege tests pass | Implemented locally |
| 2. Identity and household | Firebase Auth integration, verified email, recovery, sign-out, create household, expiring single-use invitations, roles, ownership transfer | Auth and invite replay tests, atomic owner invariant | Backend token/household APIs tested; sign-in/recovery UI and emails pending |
| 3. Mutation API | Transactional list/item CRUD, list copy, favourites, assignment, safety limits, revisions, idempotency, audit | Concurrent edits/limit bypass/retries tested | Pending |
| 4. PWA integration | Repository adapter, live listeners, IndexedDB outbox, conflict UI, explicit local-data import | Two-device sync, offline reconnect, revoked sessions | Pending |
| 5. Production operations | Staging/prod projects, region, HTTPS, App Check, server rate limits, secret/IAM policy, backups/PITR, restore drill, logs/alerts, budget alerts, CI/deployment, rollback | Security review, load tests, restore and rollback proven | Pending |

## Product decisions before integration

The six Figma screens have no sign-in, invitation, household-switching, account recovery or conflict states. Genuine shared/private households require those interactions. Preserve the shopping wireframes and agree a small account/household flow before implementing client integration; never silently replace the direct-entry local mode with unsecured sharing.

Decide who can be a caregiver, whether members may invite others, the data region and retention policy, required recovery time/data-loss tolerance, and pilot size/budget. Starting defaults in SCHEMA.md are implementation proposals, not settled product requirements.

A domain is not needed for local work. A real Firebase project, deployment region and hosting configuration will be needed for staging. Provider-generated HTTPS URLs can precede a custom domain. No infrastructure costs or cloud changes are authorised by these local scripts.

## Past task mapping

SCRUM-209 Firebase setup is started locally. SCRUM-51 secure login and SCRUM-64 household setup belong to milestone 2. SCRUM-81/88/92 and item tasks map to milestone 3; SCRUM-96 and SCRUM-152 map to milestone 4; SCRUM-196 secure cloud backup belongs to milestone 5. Voice, biometrics, reminders and AI recommendations are separate product capabilities, not automatically completed by adding a database.

Production readiness is a release gate, not a description of this first milestone.
