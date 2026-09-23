# SCRUM-208 — initial local design tokens

Implementation: `lib/theme.dart`. These are provisional Flutter values derived from the previously inspected design direction, not extracted or approved Figma variables.

| Role | Value |
|---|---|
| Primary action | `#4D7051` |
| Page background | `#F8F7F5` |
| Main text | `#20211F` |
| Supporting text | `#5B6059` |
| Card border | `#DADDD6` |
| Primary/secondary action minimum height | 56 logical pixels |
| Item checkbox and row-action minimum area | 48 × 48 logical pixels |
| Body typography | 16–18 logical pixels with 1.4 line height |
| Item title | 20 logical pixels |
| Page title | 26 logical pixels |

Use the platform font and respect system text scaling. Do not fetch fonts online. Main screens constrain content width on large windows; scrollable content and wrapping actions accommodate enlarged text.

The first flow has widget coverage at doubled text size. This does not establish full accessibility compliance; assistive technology, platform devices, keyboard focus and broader screen coverage still need review.
