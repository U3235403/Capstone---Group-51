# Stage 1 backend — database and household APIs

Local Firebase database and security foundation. The Flutter PWA remains on its existing local store until the account UI, shared-item commands and sync integration are implemented. This is **not yet a production backend**.

## Prerequisites

Node.js 22+; Java 21+; pnpm. This folder uses a locked dependency graph and disables dependency install hooks. The downloaded Java runtime used for local testing is outside the repository, under the chat workspace; no system Java or licence settings were changed.

```
pnpm install --frozen-lockfile
pnpm test
pnpm emulators
```

The scripts always select the Firebase demo project `demo-stage1`. Emulator files and CLI config stay in ignored `.local/`. Auth listens on loopback 9099, Firestore 8080 and the local console 4000. No Firebase login, billing account, cloud deployment or production credentials are needed.

With emulators running, seed explicit demo documents:

```
FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 pnpm seed
```

Seed refuses non-demo projects and non-loopback hosts, writes only fixed demo IDs, and does not clear collections. Re-running replaces those demo records. It creates no Auth account. Test identities in the rules suite are mocked; they are not real users or passwords.

## Implemented

- Firestore access rules: verified membership isolation, four roles, revocation, private profile/discovery reads, restricted audit access, default-deny unknown paths.
- All client writes denied; privileged server commands will own mutations.
- Composite index definitions, versioned database contract, six-product demo catalogue.
- Emulator-based security regression suite, including negative permission tests.
- Local-only emulator runner and guarded seed utility.

See `docs/SCHEMA.md` for the database and transaction contract, and `docs/ROADMAP.md` for remaining milestones. Admin SDK commands must enforce authorization independently: rules do not protect server SDK writes.

## Authenticated household API (local)

With emulators running: `FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099 pnpm api`. The API binds only to 127.0.0.1:8787 and refuses non-demo/non-loopback configuration. Sign-up, verification and recovery will use Firebase Auth client APIs during app integration; the API verifies bearer ID tokens, verification state and revocation. No production credential is needed.

POST endpoints: `/api/households` (name, requestId), `/api/households/:id/invitations` (email, role), `/api/invitations/redeem` (token), `/api/households/:id/members/:uid` (role, status), `/api/households/:id/transfer` (newOwnerUid). Body must be JSON; unknown fields are rejected. All require a verified Firebase ID token in Authorization: Bearer. Invitations are returned to the caller, not sent by email. Creation request IDs support safe retries; invitation creation does not yet.

The HTTP server is a loopback development harness, not a public production server. Its in-memory rate limit is a local safeguard; production needs a distributed limiter, TLS ingress, request observability and a production-only admin configuration with App Check/IAM. Never enable emulator flags in production.

## Pilot decision update

Read `docs/PILOT-DECISIONS.md` first: it supersedes earlier email-login and owner-assigned-caregiver assumptions. Default API login now uses the regional pilot account implementation. Firebase Authentication is local regression-test infrastructure only, not the production account plan. The new account/list APIs are tested, but the PWA adapter and account/admin UI remain pending.

For a first local administrator, `scripts/bootstrap-admin.mjs` accepts a JSON object with username, displayName and password via standard input under the emulator environment. It refuses a second bootstrap and never prints a password. Do not paste passwords into chat or command-line arguments. No real administrator account has been created yet.

## Integrated frontend update

The account UI and shared-list adapter are now connected to this API. See ../docs/PILOT-INTEGRATION.md for current setup and limitations; this supersedes earlier notes that the PWA is not connected. Shared refresh currently uses 10-second polling, not push events. Durable offline shared edits remain pending.
