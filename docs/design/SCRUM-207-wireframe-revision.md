# SCRUM-207 — first wireframe revision

Figma file: https://www.figma.com/design/DDuc0Lyan6x1m5nKEMvIWH/Untitled?node-id=0-1

Inspected Page 1: empty list, add item, item details, populated list, quantity warning, and caregiver limit settings. This is an initial revision, not completion of all backlog screens.

## Applied changes

- Add item (`28:6`): categories wrap so Pantry is visible rather than partly clipped offscreen.
- Six add buttons increased from 38 × 38 to 48 × 48 design units. Row padding adjusted to retain space above the home indicator.
- Quantity warning (`17:206`): replaced judgemental wording and the inconsistent “normally buy 4” claim with an explicit quantity question and the displayed limit of 2. The existing option to proceed remains, matching the illustrated Warn Only setting.
- Limit settings (`2:348`): replaced “Exceed Action Rule” with “When the limit is exceeded.”

Visual verification: screenshots checked after edits. The first enlarged-button pass pushed the last row into the bottom safe area; row padding was subsequently corrected and the screen rechecked.

## Remaining design questions and gaps

- Clarify whether a limit is per addition, per list, or per time period. Define how an existing quantity affects the proposed addition.
- Confirm caregiver authority and user consent for blocking additions; this behaviour appears in Figma but is not specified in the supplied ticket titles.
- Add a clearly labelled custom-item path, voice-entry states, input errors, and recovery flows.
- Review category, back, microphone and settings targets, text contrast, enlarged text behaviour, and accessible names during implementation. Enlarging add controls alone does not establish accessibility compliance.
- Add or identify login, household setup, multiple lists, persistence/sync status, assignment, preferences, reminders, and backup/restore flows.
- Prototype interactions and runtime behaviour have not been tested. No code changes have been made; local repository path is still needed.

Source rationale: workbook `Design_coping strategies`, rows 24, 29, 42, 52, 55, 59 and 61; see SCRUM-206 for the broader principles.
