# Push notifications (FCM) setup

This app can send push notifications via the backend endpoint `POST /api/push/register`.

## What is already implemented

- The backend stores device tokens in the `device_tokens` table and sends pushes via FCM (legacy HTTP API) when `FCM_SERVER_KEY` is configured.
- The Flutter app registers a previously-known token with the backend:
  - `PushService.registerSavedTokenWithBackend()`
  - `PushService.saveFcmToken(token)` (saves + registers)

## What is missing

The app currently does **not** obtain an FCM token automatically.
To enable real push notifications you must integrate Firebase Messaging (FCM) in Flutter.

## Required steps (Android + iOS)

1) Add Firebase config files

- Android: download `google-services.json` and place it at:
  - `software1/android/app/google-services.json`
- iOS: download `GoogleService-Info.plist` and add it to:
  - `software1/ios/Runner/GoogleService-Info.plist` (via Xcode, Runner target)

2) Enable Firebase packages

Uncomment (or add) these dependencies in `software1/pubspec.yaml` and run `flutter pub get`:

- `firebase_core`
- `firebase_messaging`

3) Initialize Firebase + request permissions + read token

Typical flow (high level):

- Call `Firebase.initializeApp()` on startup
- Request notification permission (iOS)
- Call `FirebaseMessaging.instance.getToken()`
- Pass the result into `PushService.saveFcmToken(token)`

4) Backend configuration

Set the backend env var:

- `FCM_SERVER_KEY=<your firebase server key>`

Then pushes will be delivered to any registered tokens.

## Quick verification

- Use the backend endpoint `POST /api/push/test` while logged in.
- Confirm the device token exists in DB table `device_tokens`.
