Shared Shopping List — Group 51

A shared household shopping list, built as an installable web application (PWA) in Flutter, with a local backend service.

This document will explain how to run the application from a clean machine. It was written from a first time setup on Windows 11; macOS and Linux notes are included where the commands differ.

## 1. What you are running

The product has two halves, and both must be running

The first is the backend, a Node service that provides the API on port **8787**, writing to a local Firestore emulator on port **8080**. An Auth emulator starts alongside it on **9099**, and an emulator UI on **4000** lets you look at the stored data in a browser.
 
The second is the web application, the built Flutter app, served on port **5188**. That web server proxies anything beginning with `/api/` through to the backend on 8787.
 
Opening the built app any other way — including `flutter run -d chrome` will load the interface but fail at sign-in, because nothing proxies the API and the page's Content-Security-Policy blocks Flutter's debug mode.
 
**There is no hosted instance because everything runs on one machine.**


## 2. What you need

Install Node.js 22 or later, Java 21 or later, pnpm (`npm install -g pnpm`), Flutter 3.47.7 stable, and Git. Java is required by the Firestore emulator rather than by the application itself, so it is easy to overlook, the emulator wont start without it.

### Windows only, once

PowerShell blocks `npm` and `pnpm` by default. If you see *"running scripts is disabled on this system"*, run the following and answer `Y`:

```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
```


This affects your user account only.

## 3. First time setup

Clone the repository. **Do not download it as a ZIP**, because the build reads Git metadata, and you will not be able to pull changes.

```powershell
git clone https://github.com/u3235403/Capstone--Group-51.git
cd Capstone---Group-51
```

Install dependencies:

```powershell
flutter pub get
cd backend
pnpm install
cd ..
```

## 4. Running it

You need **three terminals**, started in this order. Leave each running.

### On Terminal 1, The emulators
 
```powershell
cd backend
pnpm emulators
```

Wait until it reports that Firestore and Auth are listening. The emulator UI is at <http://127.0.0.1:4000> if you want to look at the data.

### On Terminal 2, seeding the database
 
This only needs doing once per emulator session, and again whenever you restart the emulators (their data is not persisted).

```powershell
cd backend
$env:GCLOUD_PROJECT="demo-stage1"
$env:FIRESTORE_EMULATOR_HOST="127.0.0.1:8080"
pnpm seed
```

You should see 153 product names scroll past, then a confirmation line.
 
> On macOS or Linux, the two variables go on one line with the command:
> `GCLOUD_PROJECT=demo-stage1 FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 pnpm seed`
> In PowerShell they **must** be separate lines. The bash style `$env:X="y" pnpm seed` does not work.
 
The seed script refuses to run against anything other than the local emulator, so it cannot touch real data by accident.

### On Terminal 3, build and serve the app

On Windows, build in two steps. Node cannot execute a `.bat` file directly, so the build script cannot invoke Flutter for you

```powershell
cd <repository root>
flutter build web --release --pwa-strategy=none
node scripts\build-pwa.mjs --package-only
node scripts\serve-pwa.mjs
```

On **macOS and Linux** the script can invoke Flutter itself, provided `flutter` is on your PATH or `FLUTTER_BIN` points at the executable

```bash
node scripts/build-pwa.mjs
node scripts/serve-pwa.mjs
```

Open <http://127.0.0.1:5188>.

## 5. Creating the pilot administrator

Accounts are provisioned by an administrator, there is no self-registration. The first run needs an administrator account, created once.
 
**Never pass a password as a command-line argument.** It would be recorded in your shell history. The script reads JSON from standard input instead.

 
```powershell
cd backend
$env:GCLOUD_PROJECT="demo-stage1"
$env:FIRESTORE_EMULATOR_HOST="127.0.0.1:8080"
$p = Read-Host "Password"
'{"username":"admin","displayName":"Pilot administrator","password":"' + $p + '"}' | node scripts\bootstrap-admin.mjs
```

It prints `Local pilot administrator created.` and nothing else. It can only be run once; a second attempt reports that the administrator already exists.

From there, sign in at <http://127.0.0.1:5188> and create household accounts from the administration screen. Each new account is given a temporary password and must change it at first sign-in. 

## 6. Using the app

1. Sign in with a provisioned account.
2. Choose a household and a list.
3. Add items by typing, by choosing a suggestion, or by voice.
4. Safety limits are set under **Settings → Safety limits** and can only be changed by an owner or caregiver.

To see synchronisation, open the same list in two browser windows. Changes appear in the other window within about ten seconds.

## 7. After changing the code

If you changed any Dart file, or anything under `web/` — `pilot.js`, `local_services.js`, `index.html` — rebuild with `node scripts\build-pwa.mjs`.
If you changed anything under `backend/`, restart the backend with `pnpm api`. If you changed `backend/scripts/seed.mjs`, re-run `pnpm seed` as well.
`serve-pwa.mjs` reads files from disk on each request, so it does **not** need restarting after a rebuild — but see the service worker note in troubleshooting, because the browser may still serve you the previous version.

## Troubleshooting

**The app shows an old version after rebuilding.**

The packaged service worker caches application files. If the service worker was not regenerated, the browser keeps serving the previous version indefinitely. In DevTools: **Application → Service Workers → Unregister**, then **Application → Storage → Clear site data**, then reload. 
A full `node scripts\build-pwa.mjs` regenerates the service worker and avoids this; copying individual files into `build/web` by hand does not.

**"Local backend unavailable. Start the backend and retry."**

The backend on 8787 is not running, or the emulators it depends on are not.

**"Seed is restricted to demo-stage1 on a loopback Firestore emulator."**

One of the two environment variables is missing. In PowerShell they must be on separate lines from the command.

**`pnpm` is not recognised or scripts are disabled.**

See the execution policy step in section 2.

**`build-pwa.mjs` can't start Flutter.**

On Windows this fails with `ENOENT` or `EINVAL` whatever you set, because Node refuses to execute a `.bat` file without a shell. Use the two step build in section 4. On macOS and Linux, put `flutter` on your PATH or set `FLUTTER_BIN`.

**Sign-in fails even though the backend is running.**

Check you opened <http://127.0.0.1:5188> and not a `flutter run` address. Only `serve-pwa.mjs` proxies the API.

**Voice entry says a speech model is not installed.**
Voice recognition runs entirely on the device, with no cloud service. The browser must have an English speech model installed. This prompt can reappear in later sessions on the same machine.

## Known limitations

- **Not deployed.** There is no hosted instance and no download link. The application must be run on a prepared machine as described above.
- **The database is an emulator.** Data does not survive restarting the emulators, and must be re-seeded.
- **One layout.** The interface is laid out on a fixed 420-pixel page and scaled. There are no separate tablet or desktop layouts.
- **Items must exist in the catalogue.** Free-text items cannot be added.The catalogue is seeded from `backend/scripts/seed.mjs`.
- **Synchronisation polls every ten seconds.** An edit held open longer than
  one interval can overwrite another session's change without warning.
- **Notifications and reminders are not implemented.** The settings entry opens a placeholder screen.
- **Some features belong to a superseded edition.** Reminders, biometric unlock, favourites, list copying and several preferences come from the earlier offline edition and are not reachable from the default entry point. `lib/legacy_main.dart` is retained for that historical edition.

## Verification

```powershell
flutter analyze --no-pub
flutter test --no-pub
node test\pwa_test.mjs
node test\install_test.mjs
node test\local_services_test.mjs
```
