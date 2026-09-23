# Capstone Group 51 — Stage 1 offline edition

Shopping app for people aged 65+ living with MCI. Stage 1 runs entirely on this device. Source work is on branch `SAV`; the user has authorized pushing this branch only. Do not merge into main or deploy.

## Run the offline release

Run `./run-local.command` from this repository, then open **http://127.0.0.1:5188**.
Python 3 is required. The release is served only on this computer's loopback interface. Keep the terminal running; Ctrl+C stops the server. If port 5188 is already in use by this app, use the existing preview.

Create your own passphrase (at least 12 characters). Your encrypted lists remain in this browser's local storage after restarting or refreshing. Use the same browser/profile and URL/port each time. Private browsing or clearing site data removes the stored account. No online password reset or backup is available.

## Features

Local passphrase unlock and automatic inactivity lock; household member names; persistent multiple lists and copying; item name, quantity, units, category, notes, assignment, favourite and purchase status; search, filters and sorting; local autocomplete; adjustable text/contrast/motion; reminders while open; and suggestions from local history.

Voice input requires installed on-device English recognition. It never falls back to cloud speech or downloads models. Device unlock requires a compatible platform authenticator with WebAuthn PRF; it may use biometrics or a device PIN. These two hardware-dependent features are not marked complete until tested on a supported device.

This delivery targets the **local web build**. Native macOS/iOS/Android storage adapters are not implemented. No Firebase, cloud sync, remote household invitations or external AI service is configured.

## Offline build

```sh
FLUTTER_SUPPRESS_ANALYTICS=true DART_SUPPRESS_ANALYTICS=true /Users/ups/Documents/Flutter/flutter/bin/flutter --suppress-analytics pub get --offline
FLUTTER_SUPPRESS_ANALYTICS=true DART_SUPPRESS_ANALYTICS=true /Users/ups/Documents/Flutter/flutter/bin/flutter --suppress-analytics build web --no-pub --no-wasm-dry-run --no-web-resources-cdn
```

Fonts and CanvasKit are bundled. The page's content-security policy restricts resources and connections to its own local origin. Use this release build for offline review, not the earlier debug server on port 5187.

## Verification

```sh
/Users/ups/Documents/Flutter/flutter/bin/flutter --suppress-analytics analyze --no-pub
/Users/ups/Documents/Flutter/flutter/bin/flutter --suppress-analytics test --no-pub
node test/local_services_test.mjs
```

See `docs/design/checklist.md` for ticket-by-ticket scope and `docs/design/local-work-status.md` for implementation details and limitations.
