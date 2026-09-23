# Capstone Group 51 — proposed work sequence

This sequence records the visible screenshot tasks and orders implementation by dependencies. Ticket titles alone do not establish detailed acceptance criteria. No Jira status has been changed.

| Step | Tickets | Deliverable / dependency |
|---|---|---|
| 1 | SCRUM-206 Design Principles Documentation | Initial draft created in `SCRUM-206-design-principles.md`; repository and design review pending. |
| 2 | SCRUM-207 Wireframe Revision | Inspect current Figma frames; revise the list, item, household and login flows using the principles. Requires design access. |
| 3 | SCRUM-208 Style Sheet / Design Tokens | Map approved colours, typography, spacing, controls and states into the repository's existing styling system. |
| 4 | SCRUM-209 Firebase setup; SCRUM-51 Secure login; SCRUM-64 Household setup | Inspect existing architecture first. Define authenticated household access, data model, configuration and access-rule tests. |
| 5 | SCRUM-81 Shopping List Management; SCRUM-88 Save a list; SCRUM-92 Copy an existing list | Implement list creation, persistence and duplication with clear ownership and recovery behaviour. |
| 6 | SCRUM-104 Add, edit, delete, update items; SCRUM-113 Mark item as purchased; SCRUM-119 Mark item as favorite; SCRUM-124 Categorise items; SCRUM-129 Item details; SCRUM-133 Notes on items | Complete the core shopping workflow and verify persisted changes. |
| 7 | SCRUM-137 Search, Sort & Filter; SCRUM-141 Filter items; SCRUM-147 Sort items | Treat the umbrella task and child capabilities together; keep ordering predictable. |
| 8 | SCRUM-96 Real-time sync; SCRUM-152 Cross-device visibility for household members; SCRUM-155 Assign responsibility for items | Verify two-session behaviour, offline recovery, membership enforcement and conflicts. |
| 9 | SCRUM-196 Secure cloud backup | Define retention, recovery and access; distinguish backup/restore from live cloud synchronisation. |
| 10 | SCRUM-73 Settings & preferences; SCRUM-159 Input Methods & Accessibility; SCRUM-162 Text entry with autocomplete; SCRUM-166 Voice entry; SCRUM-172 Biometric activation; SCRUM-177 Accessible display | Apply accessibility from the first implemented screen; this stage adds and verifies optional modalities and preferences. |
| 11 | SCRUM-184 AI & Smart Assistance; SCRUM-188 Shopping reminders; SCRUM-192 Intelligent list recommendations | Define optional behaviour, notification handling, recommendation inputs and service requirements. |
| 12 | SCRUM-201 Poster; SCRUM-202 Deliverable and Report | Assemble evidence from verified work against the assignment rubric. SCRUM-202 is only partly visible in the screenshot. |

Next executable step: inspect the local clone and Figma baseline. Until access is available, the documentation is a draft and no application implementation is claimed.
