# Stage 1 installable web app — local delivery

The six existing Figma shopping screens are preserved. Added a dismissible installation dialog, Android browser install-event support, iPhone/Safari instructions, standalone manifest, locally bundled assets, versioned offline caching and an explicit update/reload prompt. This is a Progressive Web App (PWA), not a native App Store binary.

## Open and install

Mac: http://127.0.0.1:5188/
Installation guide: http://127.0.0.1:5188/?install=1
Phone on the same Wi-Fi: https://UPSs-MacBook-Air.local:5443/

The local HTTPS certificate has been renewed. AirDrop `Stage-1-local-test.cer` to your iPhone. Install the downloaded profile in Settings > General > VPN & Device Management, then enable its trust in Settings > General > About > Certificate Trust Settings. You must perform these device trust steps yourself. This certificate is only for this Mac's local testing and expires November 3, 2026. Do not bypass certificate warnings. Remove the test profile when local testing is finished.

In iPhone Safari use Share > Add to Home Screen, keeping Open as Web App enabled if offered. On Android use the app's Install button when the browser makes it available, or the browser menu's Install app / Add to Home screen option. Browser installation availability varies; an installation prompt cannot be forced by a website. Open the installed icon after setup. Wait for “Ready to open offline” before disconnecting. The first visit requires the server; subsequent launches can use the cached version. The Mac must be awake and reachable for initial loading and updates.

Use `?install=1` to reopen the instructions after dismissing them. Normal prompts are suppressed for seven days after dismissal and hidden in standalone mode. No notifications, camera, microphone or device trust permission is granted automatically.

## Source and repeatable build

Repository: /Users/ups/Documents/Capstone/Capstone---Group-51
Branch: SAV. This update is local/uncommitted; no push, public deployment or merge into main.

From the repository, with Node.js and Flutter installed:

```
node scripts/build-pwa.mjs
node scripts/serve-pwa.mjs
```

Set `FLUTTER_BIN` to your Flutter executable if needed. On this Mac, the Xcode command shim currently requires an unaccepted licence; the installed Git binary can be used for Flutter by prefixing PATH with `/Applications/Xcode.app/Contents/Developer/usr/bin`. No licence was accepted by the assistant.

The build script generates `build/web/sw.js` with a content version and complete precache. Always use this script for a release; plain `flutter build web` alone does not package the custom offline worker. Deploy the contents of `build/web` together to an HTTPS static host. Keep `sw.js`, `index.html`, and bootstrap files revalidated/no-cache, serve WASM as application/wasm, and do not apply an HTML fallback to missing asset requests. Keep the app on one stable origin and base path. No backend secret or private certificate belongs in the hosted directory. A provider URL can be used before buying a custom domain.

The zip contains the complete static build, not local TLS private keys. Serve it through HTTP localhost or HTTPS; opening index.html as a file is unsupported.

## Validation completed

- 30 Flutter tests passed; Flutter analyzer reported no issues.
- Existing JavaScript encrypted-vault and local-store tests passed.
- New worker tests passed: atomic precaching, failed-update recovery, subpath/query handling, explicit update activation and unrelated-cache preservation.
- New install tests passed: iPhone instructions, Android event flow, installed-mode suppression, dismissal persistence and pointer isolation (simulated browser events).
- Release build completed and all local cache assets installed successfully in the browser.
- Browser reopened with the local server stopped and rendered the app. Existing saved list survived reload.
- Installation guide rendered at 440 × 956; its dismissal was checked.
- Local HTTPS returned 200 with certificate validation.

Actual Add to Home Screen installation and launch on physical iPhone and Android remain manual acceptance tests. The in-app desktop browser does not reproduce a phone's native installation UI.

## Remaining product gaps / improvements

1. Sharing the app link does not share household lists. Real-time sync, household membership, accounts and cloud backup require a backend and access rules. This direct-entry version intentionally retains local unencrypted storage, separate from the previous encrypted vault.
2. The six-screen Figma flow has a six-item catalogue and milk-focused caregiver settings. Arbitrary item creation/deletion, extra categories, settings for every item, backups/export and recovery would need agreed interactions beyond those wireframes. Previous richer functionality remains in legacy source, not exposed in this design.
3. Caregiver mode is a UI preference, not authenticated role protection. Do not present its limits as an enforceable security boundary.
4. Browser storage can be cleared or evicted, and Safari versus a Home Screen installation may use separate storage. Install first, then enter important lists; add backup/export before relying on it for irreplaceable data.
5. Voice entry remains dependent on on-device browser speech support. Typing remains available. Native biometrics, scheduled reminders and AI recommendations are not newly implemented by making this a PWA.
6. Review the current app icon/branding and complete real-device accessibility testing (VoiceOver, TalkBack, text scaling and keyboard). Decorative phone status/home bars remain as drawn in Figma; removing them in an installed app would be a future design decision.

Reference: https://web.dev/articles/customize-install and https://web.dev/learn/pwa/installation-prompt explain browser-controlled installation prompts. No public hosting has been configured.
