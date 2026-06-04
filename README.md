# Purple Safety

Purple Safety is a Flutter-based mobile application providing personal safety features such as emergency alerts, contact management, location sharing, and safety tools. It supports Android and iOS and includes platform-specific native code and integrations for Firebase and device services.

<!-- # Purple Safety -->

![Build](https://img.shields.io/badge/build-passing-brightgreen)
![Flutter](https://img.shields.io/badge/flutter-%3E=_3.0-blue?logo=flutter)
![License](https://img.shields.io/badge/license-MIT-blue)
![Firebase](https://img.shields.io/badge/firebase-config-orange)

Purple Safety is a Flutter mobile application providing personal safety features such as emergency alerts, contact management, location sharing, and safety tools. It supports Android and iOS and includes platform-specific native code and integrations for Firebase and device services.

## Features

- Emergency alerts and incident reporting
- Manage emergency contacts and next-of-kin
- Location sharing and live map view
- Biometric / fingerprint setup for secure access
- Integration with Firebase (Auth, Firestore, Messaging)

## Prerequisites

- Flutter SDK (recommended >= 3.0)
- Android SDK / Android Studio for Android builds
- Xcode for iOS builds (macOS only)
- A Firebase project for your app (you'll add platform-specific config files)

## Getting Started

1. Clone the repository:

   ```bash
   git clone <https://github.com/EmihleMaxengana/purple-safety.git>
   cd purple-safety
   ```

2. Install dependencies:

   ```bash
   flutter pub get
   ```

3. Add platform Firebase config files (detailed steps below).

4. Run on an emulator or device:

   ```bash
   flutter run
   ```

## Detailed Firebase Setup

Follow these steps to connect the app to Firebase and enable required services.

1. Create a Firebase project
   - Visit <https://console.firebase.google.com> and create a new project.

2. Add Android app in Firebase
   - Register package name (match `applicationId` in `android/app/build.gradle.kts`).
   - Add a nickname (optional).
   - Add debug and release SHA-1 keys (important for authentication and Google Sign-In):

   ```bash
   # Get debug SHA-1
   keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
   ```

   - Download `google-services.json` and place it at `android/app/google-services.json` (or `android/app/`).
   - Update `android/build.gradle.kts` and `android/app/build.gradle.kts` as required by Firebase Android setup (the project already includes Gradle KTS files; follow Firebase console instructions if needed).

3. Android permissions and setup
   - Ensure required permissions are present in `android/app/src/main/AndroidManifest.xml` (location, internet, contacts, camera, etc.).
   - If using Google Maps, enable Maps SDK in Google Cloud Console and add your API key to the appropriate manifest or Gradle properties.

4. Add iOS app in Firebase
   - In the Firebase console, add an iOS app and register the `iOS bundle ID` (found in `ios/Runner/Info.plist`).
   - Download `GoogleService-Info.plist` and add it to `ios/Runner/` in Xcode (ensure it is included in the Runner target).
   - For push notifications (FCM) you'll need to configure APNs:
     - Create an APNs Authentication Key (.p8) in Apple Developer account.
     - Upload the key to Firebase (Project Settings > Cloud Messaging) and note the Key ID and Team ID.

5. Enable Firebase services
   - In the Firebase console, enable Authentication (Email, Phone, or other providers you need).
   - Enable Firestore and create required collections/rules.
   - Enable Cloud Messaging for push notifications.

6. iOS entitlements and capabilities
   - In Xcode, enable Push Notifications and Background Modes (Remote notifications) for the Runner target.

7. Optional: Cloud Functions / Server keys
   - If the app uses server-side Firebase features or needs server keys, store keys securely outside the repo and follow best practices.

8. Verify
   - Run the app on a real device and verify authentication, Firestore reads/writes, and FCM push notifications work.

## Building

- Android (release):

```bash
flutter build apk --release
```

- iOS (release, macOS):

```bash
flutter build ios --release
```

## Project Structure

- `lib/` — Dart source files and app UI
- `android/`, `ios/` — platform-specific native code and configs
- `assets/` — images and other static assets

## Testing

Run unit/widget tests with:

```bash
flutter test
```

## Notes

- Ensure you configure Firebase and enable required APIs (Authentication, Firestore, Cloud Messaging) in the Firebase console.
- Some plugins require additional platform setup (permissions in `AndroidManifest.xml` and iOS Info.plist entries). Check plugin docs for details.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for contribution guidelines, code style, and PR process.

## License

Specify your project license in `CONTRIBUTING.md` or add a `LICENSE` file.
