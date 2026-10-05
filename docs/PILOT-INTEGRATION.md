# Integrated pilot: current state

The default web entry now offers username sign-in, forced temporary-password change, household creation/selection, member invitations, list selection/creation and pilot administration. Six Figma shopping screens are reused behind an account-navigation bar. Local-only mode retains the previous independent browser store.

Shared lists use authenticated API snapshots every 10 seconds. Saves are acknowledged by the server; revision conflicts surface as errors. An uncertain network save can be retried with its original idempotency key while this page stays open. Shared mode does **not** implement durable offline editing or push-based real-time sync. Use local-only mode for independent offline lists. Session tokens stay in memory; refresh requires sign-in again. No automatic local-to-shared import occurs.

Run Java 21+ and Node 22+, install locked backend dependencies with pnpm, then start three processes:
1. In backend: `pnpm emulators`.
2. In backend: `FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099 pnpm api`.
3. At repository root: `node scripts/build-pwa.mjs`, then `node scripts/serve-pwa.mjs`.

Open http://127.0.0.1:5188/. The web server proxies /api to loopback port 8787 and checks request Origin. API traffic is excluded from service-worker caching. Use the same server with TLS_CERT/TLS_KEY/HOST/PORT for local phone testing.

Seed the six-product catalogue using the guarded backend seed script. Provision the first administrator with backend/scripts/bootstrap-admin.mjs, supplying JSON through stdin, never putting passwords in command arguments or Git. Administrator account creation and recovery are available in the account UI after sign-in. No permanent real administrator or participant account is bundled. Emulator data is disposable, not a production database.

Validation: 50 backend/emulator tests including a browser-JavaScript-to-HTTP integration test, 30 Flutter tests, analyzer, PWA/installation/storage tests and release build. The HTTP bridge test covers login, household/list selection, item save, purchase toggle, rule creation/deletion, refresh and logout. Physical-device, cross-device conflict UX and production infrastructure validation remain outstanding.

Production gates: Australian credential/data/compute/backup placement review, distributed abuse protection, real account provisioning, backup/restore and deletion drills, durable offline outbox, migration UX, load/security testing. Firebase Auth is local legacy test infrastructure only; participant login uses the pilot account store. Nothing is publicly deployed by pushing the source branch.
