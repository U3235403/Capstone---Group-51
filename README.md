# Capstone Group 51 — Stage 1 pilot PWA

The default entry point is `lib/main.dart`, which starts `PilotApp`. It offers pilot username/password sign-in and an independent local-only shopping mode. It does not open the legacy encrypted passphrase vault.

## Local setup

Install Flutter on PATH and Node.js 22+. Resolve the Flutter dependencies before building:

```sh
flutter pub get
node scripts/build-pwa.mjs
node scripts/serve-pwa.mjs
```

The build script uses `flutter` from PATH. Alternatively set `FLUTTER_BIN` to the Flutter executable (not its directory). Dependencies must already be resolved because the release build uses `--no-pub`. Offline dependency resolution with `flutter pub get --offline` requires all packages to be cached first.

Open http://127.0.0.1:5188/. Local-only shopping uses browser storage for that origin. Shared mode additionally requires the local database emulators, API, catalogue and provisioned pilot accounts: follow [pilot setup](docs/PILOT-INTEGRATION.md) and [backend instructions](backend/README.md). Shared mode polls every 10 seconds and does not support durable offline edits. Production services are not provisioned by these commands.

## Feature status

Use the [current checklist](docs/design/checklist.md) for available, partial and superseded workflows. Reminders, biometric unlock, favourites, copying, per-item assignment and several preferences belong to the earlier offline edition and are not exposed by the default app. The retained `lib/legacy_main.dart` entry point is for that historical edition; its tests do not certify the current UI.

## Verification

```sh
flutter analyze --no-pub
flutter test --no-pub
node test/pwa_test.mjs
node test/install_test.mjs
node test/local_services_test.mjs
```

See [PWA delivery notes](PWA-DELIVERY.md) for packaging context. Historical machine-specific URLs/certificate notes are not portable setup requirements. No public deployment or merge to main is implied.
