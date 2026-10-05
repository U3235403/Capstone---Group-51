# Database contract, version 1

Firestore is the source of truth for the future shared mode. All documents carry `schemaVersion: 1`; all mutable entities carry a monotonically increasing integer `revision`, server `createdAt` / `updatedAt` timestamps and an authenticated creator/updater UID. IDs are server-generated opaque strings, not the local Flutter counter. The present app is not connected to this database yet.

| Path | Required business fields | Reads | Writes |
|---|---|---|---|
| users/{uid} | displayName (1–80 characters), createdAt | verified self only | server |
| users/{uid}/households/{hid} | name | verified self only | server; discovery projection, never an authority |
| households/{hid} | name (1–80), ownerUid, revision | active verified members, direct get | server |
| households/{hid}/members/{uid} | displayName, role, status, joinedAt | active verified members | server |
| households/{hid}/lists/{lid} | name (1–80), archived, createdBy, revision | active verified members | server |
| households/{hid}/lists/{lid}/items/{iid} | productKey, name (1–120), quantity (integer 1–999), unit (1–24), category (1–80), notes (0–1000), purchased, favourite, assigneeUid or null, deleted, revision | active verified members | server |
| households/{hid}/safetyRules/{productKey} | maximum (integer 1–999), mode (warn/block), revision | active verified members | owner/caregiver through server |
| households/{hid}/audit/{eventId} | actorUid, command, targetId, timestamp, minimal changes | owner/caregiver | server, append only |
| invitations/{sha256Token} | householdId, invitedEmail, role, createdBy, expiresAt, usedAt | server only | owner through server |
| households/{hid}/receipts/{requestId} | actorUid, payloadHash, response, expiresAt | server only | server transaction |
| catalogue/{productKey} | name, category, active | verified accounts | trusted administration |

Do not store raw invite tokens, passwords, Auth ID tokens, private notes in audit records, or service credentials in client-readable documents. Email verification is required for shared data. Member records expose a display name and UID, not private email/profile fields.

## Roles and lifecycle

- `owner`: manages household and invitations, transfers ownership, assigns caregiver roles, edits lists and safety rules.
- `caregiver`: edits lists and safety rules; no ownership transfer or role grants.
- `member`: edits shopping lists and items, cannot alter limits or roles.
- `viewer`: read only.
- Membership status is `active` or `revoked`. Unknown roles are denied. Removing membership denies subsequent server reads. Data previously cached on a device cannot be remotely erased by Firestore rules; shared mode must clear its local cache on sign-out/revocation.

There must always be exactly one active owner. The server must atomically update household.ownerUid and member roles during ownership transfer. The browser cannot create membership itself. Account deletion needs an ownership-transfer or household-deletion policy before enabling it.

## Command invariants for milestone 2/3

The Admin SDK bypasses Firestore security rules. Every command must independently validate authenticated verified identity, active membership, role, strict input fields, quotas and expected revision. Do not expose a generic document-write endpoint. Each mutation transaction includes its audit event and idempotency receipt; a repeated request ID with a different payload must fail.

Safety limits apply to the total non-purchased, non-deleted quantity for a product **within one list**. All item mutations and purchase toggles must read/update the list revision, serialising simultaneous changes. Query relevant items and rule inside that transaction. Warn mode requires explicit confirmation bound to the product, proposed quantity and current revision; block mode has no member override. Rule changes are also revisioned. Do not trust quantities, roles or totals supplied by a client.

Use stable product keys instead of display names to prevent spelling-based limit bypasses. Preserve tombstones for a defined sync window; permanently prune only after the retention policy is agreed. Proposed initial bounds: 50 active lists per household, 500 active items per list, 20 members; confirm these during command implementation.

## Offline boundary

Firestore cache is not the command outbox. Queue authenticated, household-bound commands in IndexedDB with UUID request IDs, expected revision and payload hash. Do not optimistically label a command as saved to the household before acknowledgement. Surface conflict, revoked access and blocked-limit outcomes without silently overwriting another member's change. Stage 1's previous local/encrypted stores remain intact; cloud import must be explicit and idempotent.

## Indexes and migration

Indexes cover archive/date list queries and purchased/category/product item queries. Firestore emulator tests do not enforce every production composite-index requirement; deploy and verify indexes in staging before release. Version document schemas and migrate with a server-only, resumable script after a tested backup. No production project has been created or configured in this milestone.

Identity commands now also store user-scoped creation receipts at `users/{uid}/commands/{requestId}`. These are server-only and bind request ID to a payload hash and result. Invitation tokens are returned once; only their SHA-256 hashes are used as document IDs. Invites expire after 24 hours, require matching verified email, and become invalid when their inviter is no longer owner. Creation of invitations is not idempotent yet; do not automatically retry that endpoint.
