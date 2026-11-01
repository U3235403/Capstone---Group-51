# Shared Shopping List

### Capstone Project · Group 51

An installable Flutter web application for coordinating household shopping. Participants can manage shared shopping lists, track purchases and use caregiver-configured quantity limits. A local Node.js API and Firestore emulator support the pilot environment.

**Project status:** local development and demonstration. Public hosting and production infrastructure are not configured.

## Contents

1. [Application overview](#1-application-overview)
2. [Prerequisites](#2-prerequisites)
3. [Installation](#3-installation)
4. [Running locally](#4-running-locally)
5. [Administrator setup](#5-administrator-setup)
6. [Using the application](#6-using-the-application)
7. [Development and testing](#7-development-and-testing)
8. [Troubleshooting](#8-troubleshooting)
9. [Current limitations](#9-current-limitations)

## 1. Application overview

Shared mode requires the web application, API and database emulators to run together.

The backend is a Node.js service that provides the API on port **8787**, writing to a local Firestore emulator on **8080**. An Auth emulator starts alongside it on **9099**, and an emulator UI on **4000** lets you inspect stored data in a browser. Participant username/password login uses the application's pilot account store.

The web application is the built Flutter app, served on port **5188**. That web server proxies requests beginning with `/api/` to the backend on 8787.

Use the supplied web server for shared mode. Opening the app through `flutter run -d chrome` does not provide the API proxy, and the configured Content-Security-Policy can also interfere with debug mode.

### Operating modes

| Mode | Storage | Connectivity |
| --- | --- | --- |
| Shared household | Local Firestore emulator through the authenticated API | Requires the API and emulators |
| Local-only shopping | Independent browser storage | Can operate offline after application assets are cached |

Local-only mode is available from the login screen. Data is not automatically transferred between modes.

### Local services

| Service | Default address |
| --- | --- |
| Web application | http://127.0.0.1:5188 |
| API | http://127.0.0.1:8787 |
| Firestore emulator | 127.0.0.1:8080 |
| Auth emulator | 127.0.0.1:9099 |
| Emulator dashboard | http://127.0.0.1:4000 |

## 2. Prerequisites

| Tool | Requirement |
| --- | --- |
| Git | Repository checkout and version control |
| Node.js | Version 22 or later |
| pnpm | Install with `npm install -g pnpm` |
| Java | Version 21 or later; required by the Firestore emulator |
| Flutter | Dart SDK compatible with `pubspec.yaml` (currently `^3.13.3`) |
| Python 3 | Optional; used by the macOS/Linux administrator setup example |

Put Flutter and Java on PATH. Set `JAVA_HOME` if required by your Java installation. Check the installations with `flutter --version`, `node --version`, `pnpm --version` and `java -version`.

### Windows shell compatibility

If PowerShell reports that running scripts is disabled for `npm` or `pnpm`, use `npm.cmd` and `pnpm.cmd` instead, or run the commands in Command Prompt. You do not need to change your execution policy to use those commands.

Initial dependency and emulator downloads require internet access. Offline development requires those dependencies to be cached first.

## 3. Installation

Clone the repository to retain its history and allow future updates:

```sh
git clone https://github.com/U3235403/Capstone---Group-51.git
cd Capstone---Group-51
```

Use the application release supplied by the project team. Git preserves repository history and supports subsequent updates.

Install dependencies:

```sh
flutter pub get
cd backend
pnpm install --frozen-lockfile
cd ..
```

## 4. Running locally

Start the following processes in **three separate terminals**, in order. Each terminal begins at the repository root. Keep the processes running while using shared mode.

### Terminal 1 — database emulators

```sh
cd backend
pnpm emulators
```

Wait until Firestore and Auth report that they are listening. The emulator UI is at <http://127.0.0.1:4000>.

### Terminal 2 — seed the database and start the API

PowerShell:

```powershell
cd backend
$env:GCLOUD_PROJECT = 'demo-stage1'
$env:FIRESTORE_EMULATOR_HOST = '127.0.0.1:8080'
$env:FIREBASE_AUTH_EMULATOR_HOST = '127.0.0.1:9099'
pnpm seed
pnpm api
```

macOS/Linux:

```sh
cd backend
export GCLOUD_PROJECT=demo-stage1
export FIRESTORE_EMULATOR_HOST=127.0.0.1:8080
export FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099
pnpm seed
pnpm api
```

Seeding creates demo records and populates the product catalogue. It is restricted to the demo project on a loopback Firestore emulator. It does not create a pilot login account.

Run it for an empty emulator session or when deliberately updating demo seed data. Rerunning it can overwrite records with the fixed demo IDs. The launcher does not configure persistent emulator import/export, so do not rely on data surviving a restart.

**Keep `pnpm api` running.** Starting the emulators and seeding the database alone does not start the API.

### Terminal 3 — build and serve the app

With Flutter on PATH:

```sh
flutter build web --release --no-pub --pwa-strategy=none
node scripts/build-pwa.mjs --package-only
node scripts/serve-pwa.mjs
```

The Flutter command compiles the release; the packaging command generates the versioned offline service worker. This sequence supports Flutter installations available on PATH, including Windows batch-file launchers.

On macOS/Linux, you can instead build and package in one command by supplying your Flutter executable explicitly:

```sh
FLUTTER_BIN=/absolute/path/to/flutter node scripts/build-pwa.mjs
node scripts/serve-pwa.mjs
```

Replace the example path with your installation's executable. Open **<http://127.0.0.1:5188>**.

## 5. Administrator setup

Accounts are provisioned by an administrator; there is no self-registration. The first run needs an administrator account, created once per database.

Open a temporary fourth terminal, enter `backend`, and set the same **three environment variables** shown for Terminal 2. Environment variables must be set in each terminal that needs them.

**Never pass a password as a command-line argument or commit it to the repository.** The bootstrap script reads JSON from standard input. Passwords must be 12–128 characters.

PowerShell:

```powershell
$secure = Read-Host 'Administrator password (12–128 characters)' -AsSecureString
try {
  $plain = [System.Net.NetworkCredential]::new('', $secure).Password
  @{ username='admin'; displayName='Pilot administrator'; password=$plain } |
    ConvertTo-Json -Compress | node scripts/bootstrap-admin.mjs
} finally {
  $plain = $null
  $secure = $null
}
```

macOS/Linux, with Python 3 installed:

```sh
python3 -c 'import getpass,json; print(json.dumps({"username":"admin","displayName":"Pilot administrator","password":getpass.getpass("Administrator password (12–128 characters): ")}))' | node scripts/bootstrap-admin.mjs
```

The examples read the password interactively and serialize it as JSON.

On success, the script prints `Local pilot administrator created.` A second attempt in the same database reports that an administrator has already been bootstrapped. If emulator data is lost, bootstrap is needed again. No default administrator password is bundled.

Sign in at <http://127.0.0.1:5188> and use the administration controls to create participant accounts or recover access. Each new participant receives a temporary password and must change it at first sign-in.

## 6. Using the application

1. Sign in with a provisioned account and complete any required password change.
2. Create or choose a household and a shopping list.
3. Search or browse the catalogue, select an item, set its quantity and add it.
4. Edit quantities, mark items as purchased or remove items from the shared list.
5. Open **Settings → Safety limits** to configure quantity warnings or blocks. Only authorized owners or caregivers can change shared safety rules; the pilot administrator assigns caregiver roles.
6. Explore the household, shop and display settings. Some additional settings use local model state and still need shared-mode persistence verification.

### Synchronization and sessions

Open the same list in separate browser sessions to observe shared updates. The application polls approximately every ten seconds. Session tokens remain in memory, so refreshing the page requires signing in again.

Voice entry requires a supporting browser/device and an installed on-device English speech model. Text entry remains available when voice recognition is unsupported.

### Installing the web application

Use the in-app installation instructions or your browser's **Install app / Add to Home Screen** option when available. A cached app shell does not make the shared backend available offline. Local-only shopping uses its own browser store and does not automatically import shared lists or an older encrypted vault.

## 7. Development and testing

### Rebuilding the web application

After changing Dart source or files under `web/`, rebuild and package:

```sh
flutter build web --release --no-pub --pwa-strategy=none
node scripts/build-pwa.mjs --package-only
```

If you change backend code, restart the API with `pnpm api`. If you change the seed script, re-seed only when you intend to update disposable demo records.

The web server reads files from disk, so it does not need restarting after a rebuild. The browser may still have an older service worker active; use the app's update/reload prompt or close and reopen app tabs.

### Validation

After resolving dependencies and packaging the application, run:

```sh
flutter analyze --no-pub
flutter test --no-pub
node test/pwa_test.mjs
node test/install_test.mjs
node test/local_services_test.mjs
```

The PWA tests require generated `build/web` files. Run backend emulator tests only against disposable test data; inspect `backend/README.md` and the test launcher first.

## 8. Troubleshooting

**The app shows an old version after rebuilding.**

Rebuild and package together so the service worker receives a new content version. Use the update prompt or reopen the app. If a development reset is needed, inspect/unregister the worker in browser developer tools. Do not routinely clear all site data: that deletes local-only lists and any legacy browser vault. Preserve data you need before an intentional reset.

**“Local backend unavailable. Start the backend and retry.”**

Check that both emulators are ready, all three environment variables are set in the API terminal, and `pnpm api` is running on 8787.

**“Seed is restricted to demo-stage1 on a loopback Firestore emulator.”**

Check `GCLOUD_PROJECT` and `FIRESTORE_EMULATOR_HOST`. In PowerShell, set each environment variable on a separate line before running the command.

**`pnpm` is not recognised, or scripts are disabled.**

Check that pnpm is installed and on PATH. On Windows, use `pnpm.cmd` if the PowerShell wrapper is blocked.

**Flutter is not found when running the build script.**

Use the direct Flutter build followed by `--package-only`, or supply `FLUTTER_BIN` explicitly on macOS/Linux. Run `flutter pub get` first because the release commands use `--no-pub`.

**Administrator creation fails.**

Check both emulator host variables, project ID, password length and whether bootstrap has already run against this database.

**Sign-in fails although the backend is running.**

Check that you opened <http://127.0.0.1:5188>, that the pilot account was provisioned, and that you are not using a standalone Flutter development server without the API proxy.

**A save reports a conflict.**

The API rejects stale list or safety-rule revisions with HTTP 409. Reload and review the current data before retrying. Concurrent editing remains subject to end-to-end validation.

**Voice entry says a speech model is not installed.**

Recognition requires supported on-device speech capabilities and an installed English model. Use text entry when unavailable; no cloud recognition fallback is provided.

**The phone cannot open the local address.**

`127.0.0.1` on a phone refers to that phone. Testing on a real phone requires a reachable server hostname on the network and correctly configured, trusted HTTPS. Do not bypass certificate warnings. The server must be awake and reachable for shared operations.

## 9. Current limitations

- **Not deployed.** There is no provisioned public instance. Run the application on a prepared machine as described above.
- **Emulator storage.** Persistence across shutdowns is not configured by the supplied launcher. Do not use this setup as a production database or backup.
- **Mobile-focused layout.** A separate responsive desktop layout is not part of this application version.
- **Catalogue-based items.** Shared items must exist in the seeded catalogue; catalogue search is not unrestricted free-text item creation.
- **Polling synchronization.** Shared lists refresh approximately every ten seconds. Durable offline shared editing and automatic local-to-shared migration are not implemented.
- **Settings persistence.** Some additional settings belong to the local model and need shared-mode persistence and authorization verification. A local carer/account-type selection does not grant server permissions.
- **Notifications and reminders.** These are not delivered by the default application; a settings placeholder does not provide reminder scheduling or delivery.
- **Legacy functionality.** The default `lib/main.dart` starts the pilot application. The separate `lib/legacy_main.dart` starts an earlier encrypted-vault edition. Legacy biometric/device unlock and other legacy-only workflows must not be treated as current delivered features.
- **Production readiness.** Physical-device installation, accessibility, concurrent editing, security and backup/restore testing remain required before production use.
