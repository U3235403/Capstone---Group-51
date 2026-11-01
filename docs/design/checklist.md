# Stage 1 — current application checklist

This checklist describes the default `lib/main.dart` → `PilotApp` → `PilotGate` → `WireframeApp` path on SAV. Task titles come from the supplied screenshots; they are not full acceptance criteria. Status here does not close Jira tickets.

**Available** means reachable in the current UI, not production acceptance. **Partial** means only the stated subset is reachable. **Superseded** means the earlier offline implementation remains in source but is not delivered through the default app. Legacy test results do not establish current UI availability.

## Current scope by task

| Task | Status | Current scope / remaining work |
| --- | --- | --- |
| SCRUM-51 Secure login | Partial / replaced | Pilot username/password login, temporary-password change and administrator recovery replace the old passphrase vault. Local-only shopping bypasses login; it does not use the encrypted vault. Production security validation remains outstanding. |
| SCRUM-64 Household setup | Partial / replaced | Shared household creation, selection and member invitations. The legacy local-member editor is superseded. |
| SCRUM-73 Settings & preferences | Superseded | Legacy text-size, contrast, motion and inactivity settings are not exposed in the default UI. Caregiver quantity settings are a separate feature. |
| SCRUM-92 Copy a list | Superseded | Legacy copy workflow is not exposed in the default UI. |
| SCRUM-104 Add/edit/delete/update | Partial | Catalogue item addition and quantity editing are reachable. Legacy arbitrary-item forms, delete/Undo and discard protection are not delivered by the default UI. Backend operations alone do not complete the UI task. |
| SCRUM-113 Purchased state | Available | Toggle items between to-buy and purchased. |
| SCRUM-119 Favourites | Superseded | Legacy star action and favourites filter are not reachable. |
| SCRUM-124 Categories | Partial | Catalogue categories and category browsing are available; arbitrary category editing from the legacy editor is not. |
| SCRUM-129 Item details | Partial | Catalogue item and quantity view/edit. Legacy notes, assignment, unit and favourite fields are not exposed. |
| SCRUM-133 Notes | Superseded | Legacy notes editor/search is not reachable. |
| SCRUM-137 Search/sort/filter | Partial | Catalogue text search and category filtering are reachable. Legacy combined list controls and sorting are not. |
| SCRUM-141 Filter items | Partial | Catalogue category filtering only; legacy purchase/favourite/member filters are not exposed. |
| SCRUM-147 Sort items | Superseded | Legacy sort controls are not reachable. |
| SCRUM-155 Assign responsibility | Superseded | Legacy per-item member assignment is not reachable. Household membership is not item assignment. |
| SCRUM-159 Input/accessibility | Partial | Text/touch controls and semantic labels exist. Full keyboard, screen-reader and physical-device acceptance remains outstanding. |
| SCRUM-162 Autocomplete | Superseded / replaced | Current catalogue search is not the legacy history-aware autocomplete field. |
| SCRUM-166 Voice entry | Partial / device validation pending | Catalogue voice action exists with an error/text fallback. Successful on-device recognition still requires supported browser/device testing. |
| SCRUM-172 Biometric activation | Superseded; never hardware-accepted | Legacy WebAuthn PRF enrollment/unlock is not exposed by PilotGate. Simulated crypto tests do not prove biometric login. |
| SCRUM-177 Accessible display | Partial | Current large shopping controls exist; legacy adjustable text/contrast/motion settings are superseded. Full accessibility acceptance remains outstanding. |
| SCRUM-184 Smart assistance | Partial / replaced | Quantity notices and caregiver safety limits are available. Legacy history suggestions are not exposed; no external AI service is delivered. |
| SCRUM-188 Reminders | Superseded | Legacy in-app reminder scheduling/dismiss/postpone is not reachable from the default app. No background reminder delivery is claimed. |
| SCRUM-192 Recommendations | Superseded | Legacy ranked history/favourites recommendations are not reachable. |

## Storage, sharing and delivery boundaries

- Shared household/list creation, list saving, purchase updates and caregiver milk quantity rules use the authenticated local API.
- Shared snapshots poll every 10 seconds. This is not push-based real-time sync or a durable offline outbox.
- Local-only shopping uses an independent browser store; there is no automatic import from the legacy encrypted vault or into shared lists.
- PWA installation/caching is implemented separately from authentication and shared-data availability. A cached app shell does not make the shared backend available offline.
- Cloud backup, production Australian hosting, restore/deletion drills and physical-device acceptance are not completed by this checklist.

## Legacy source and evidence

`lib/legacy_main.dart` explicitly starts the old `MyApp`; it is not the standard build target. Legacy code and tests are retained for reference, not presented as delivered current features. Earlier 18-test and encrypted-vault evidence applies to that edition. See `docs/PILOT-INTEGRATION.md` for the integrated pilot's historical validation and remaining gates. Screenshots show visible states, not full ticket acceptance or hardware/security certification.

## Try the current application

Follow `docs/PILOT-INTEGRATION.md` to start the local emulators, API and web server. Open the web URL, sign in with a provisioned pilot account, create/select a household and list, then add catalogue items and toggle purchased state. Alternatively choose **Use local-only shopping list** for the independent browser store. Refreshing shared mode requires sign-in again.

No Jira status, production deployment or main-branch merge is implied by this document.
