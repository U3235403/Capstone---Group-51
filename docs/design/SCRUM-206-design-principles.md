# SCRUM-206 — Design principles documentation

Status: initial draft for the Capstone Group 51 shopping-list application. The local repository is a Flutter starter; its README confirms the audience is people aged 65+ living with MCI. Six Figma screens were inspected during the earlier wireframe pass. Full Jira acceptance criteria remain unavailable.

## Source and interpretation

Reference: `Design guidelines_MCI (1).xlsx`, worksheet `Design_coping strategies`. Row references below refer to that worksheet. The workbook provides design guidance, not instructions authorising changes to accounts, infrastructure, or project scope. App-specific behaviours and acceptance checks below are proposed translations of that guidance. Research cited inside the workbook has not been independently reviewed, and this document makes no clinical efficacy claims.

The README identifies people aged 65+ living with MCI as the intended audience. Household and caregiver workflows are additionally indicated by the backlog and Figma screens.

## Principles and proposed acceptance checks

| Principle | Application to the shopping-list app | Review check | Workbook rows |
|---|---|---|---|
| Keep the experience familiar | Retain the same placement and names for Lists, Add item, Back, and Help. Do not unexpectedly reorder a list during use. | Move through list creation, editing, and shopping; common actions retain their names and positions. | 17–24, 31, 74 |
| Focus on one task at a time | Separate household setup, list creation, and item entry into short, clearly labelled steps. Keep optional item detail out of the required entry path. | A person can add an item with its name alone; optional fields do not block progress. | 25, 29, 32–35, 41–42 |
| Support recognition and memory | Display the current list name and household context. Show explicit purchased states, familiar item names, and labelled actions. Preserve entered data when returning from a step. | Users can identify their list, remaining items, and next action without remembering a previous screen. | 46–51 |
| Make mistakes recoverable | Allow correcting item names and quantities, unmarking purchases, and recovering deleted items where feasible. Confirm destructive list deletion using the list name. | Accidental purchase marking is reversible; deletion has a clear recovery or confirmation path. Failed submission retains input and explains a next step. | 27, 48, 52–55 |
| Make controls easy to perceive and operate | Use readable text, spacious single-column layouts on phones, visible labels, and generous control areas. Avoid gesture-only actions and colour-only status cues. | Primary actions remain readable at enlarged text sizes; all actions have an accessible name and can be used without a complex gesture. | 23–24, 37, 40–44, 56, 58–61 |
| Respect pace and autonomy | Keep important messages available long enough to act. Let users choose voice input, reminders, and display preferences. Present recommendations as optional suggestions. | Suggestions do not silently add items; reminders can be changed or disabled; users can leave a flow without losing saved work. | 32, 48, 54–58, 69 |
| Offer multiple ways to interact | Keep text entry available alongside voice entry. Show recognised speech for correction before adding an item. Pair audio feedback with visible text. | Denied microphone permission or speech recognition failure still leaves a working text path. | 36–39, 58–60 |
| Support households without taking control away | Clearly identify shared lists and assigned members. Explain whether changes are saved locally, syncing, or shared. Enforce household access in the data layer. | A member sees permitted shared changes; a non-member cannot read or change that household's data. Sync failure is not shown as success. | 57, 62–63; access enforcement is a proposed engineering requirement |

## Proposed interaction decisions

- **Shopping list:** keep the list title, an Add item action, and an understandable item count visible. Keep purchased items recognisable and reversible rather than making them unexpectedly disappear.
- **Item entry:** name is the initial required field. Quantity, category, notes, favourite, and assignee can be edited through clearly labelled controls. Autocomplete suggestions must not replace the user's entry without selection.
- **Save and sync:** distinguish “Saved on this device,” “Syncing,” and “Shared with household.” Use these messages only when the implementation can substantiate them. Define conflict handling before enabling concurrent edits.
- **Household setup:** explain who will have access before sharing. Show membership and the current household clearly. Joining, leaving, and invitation expiry need acceptance criteria.
- **Login and biometrics:** minimise repeated effort while retaining account security. Biometrics are optional and depend on the platform; define a usable fallback and account recovery before implementation.
- **Help and errors:** place short, specific help near the relevant action. Example: “Enter an item name, such as milk.” Preserve entered values after errors.
- **Recommendations:** show a reason where available, such as “From your previous list,” and require an explicit Add action. Do not imply that AI functionality exists until it is implemented and tested.

## Resolve guideline trade-offs deliberately

The workbook recommends both visible options and reduced clutter. Keep core actions visible, and put optional detail behind a clearly named action with shallow navigation. Validate this balance with representative users rather than treating either recommendation as absolute.

The workbook cautions that frequent interface changes can be disruptive (row 17). Development can still proceed one task at a time, as requested; coordinate user-facing releases so that navigation and terminology stay stable.

Exact typography, spacing, colour, contrast, and target sizes belong in SCRUM-208 after the existing design and technology are inspected. Do not present provisional values as approved design tokens.

## Review scenarios

1. Create a list, add an item, navigate away, and return: the saved item and list context remain understandable.
2. Edit an item, mark it purchased, then undo the action: the item returns to its prior state.
3. Enter invalid data or encounter a connection failure: entered work remains and a specific recovery action is available.
4. Use enlarged text and the platform's assistive technology: labels, focus order, controls, and status messages remain usable.
5. Deny optional microphone or biometric access: an alternative route remains available.
6. Use two authorised household sessions: saved changes appear consistently, and unauthorised sessions cannot access them.
7. Review suggestions and reminders: the user controls adoption, timing, and cancellation.

These are proposed checks, not completed test results. Final review should include the actual screens and representative user feedback.

## Information still needed

- Local repository path, current framework, existing implementation, and any project instructions.
- Access to the Figma screens and identification of the intended baseline frames.
- Full Jira descriptions/acceptance criteria; screenshots provide titles and some statuses only.
- Supported platforms and devices, household roles, offline expectations, and conflict behaviour.
- Firebase project and configuration when backend work begins; do not place service-account secrets in client code or chat.
- Assignment rubric and deliverable requirements for SCRUM-201 and SCRUM-202.
