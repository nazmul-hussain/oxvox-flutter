# oxvox (Flutter, Android)

Android version of the oxvox English learning app. No backend server: content comes from
[oxvox-cdn](https://github.com/nazmul-hussain/oxvox-cdn) and user data stays on the device
(MongoDB Atlas sync planned, see `oxvox-cdn/SCHEMA.md`).

## Run
    flutter pub get
    flutter run

## Release (Play Store)
1. Keep `android/upload-keystore.jks` and `android/key.properties` backed up somewhere safe. They are git-ignored. **If you lose them, you cannot update the app.**
2. Bump `version:` in `pubspec.yaml` (e.g. `1.0.1+2`). The `+N` must increase every upload.
3. `flutter build appbundle --release`
4. Upload `build/app/outputs/bundle/release/app-release.aab` in Play Console.

## Structure
- `lib/core/` theme palettes (copied from the web app), SRS scheduling, config
- `lib/data/` content loading (bundled, then CDN cache), user state (SharedPreferences)
- `lib/services/` daily reminder (local notifications, no exact-alarm permission)
- `lib/screens/` Today, Words, Review, Progress (badges), Settings, Listening lesson
- `assets/data/` bundled copy of the content so the app works offline on first launch

## Play Store checklist
- [x] Package name `com.oxvox.app`, label `oxvox`
- [x] Release signing with upload key, debug fallback blocked from uploads
- [x] Only `INTERNET` and `POST_NOTIFICATIONS` permissions (no exact alarms, no location, no contacts)
- [x] Privacy policy: https://nazmul-hussain.github.io/oxvox-cdn/privacy.html (enable GitHub Pages on oxvox-cdn, `main` branch, root folder)
- [x] App icon and 512x512 store icon (done)
- [x] Support email set to shadhinrcrg@gmail.com in `oxvox-cdn/privacy.html`
- [ ] Fill in the Data safety form: account data (name, email/phone, password) and learning progress are collected, encrypted in transit, and deletable in-app
- [ ] Add screenshots (phone, at least 2)
- [ ] Confirm content rights for word lists and listening lessons
- [ ] Install NDK (`flutter doctor`) to remove the "failed to strip debug symbols" advisory from the bundle

## Roadmap (suggested features, data already planned in SCHEMA.md)
Reminders, streaks, badges and XP are done locally. Next: leaderboard and weekly leagues (Atlas `leaderboard`), account sync (`users`, `progress`, `activity`), certificates, and a home screen widget.
