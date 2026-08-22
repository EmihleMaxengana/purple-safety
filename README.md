# Purple Safety

Purple Safety is a Flutter personal-safety application for Android and iOS. It combines SOS alerts, live location and trip sharing, trusted contacts, community incident reporting, direct messaging, danger-zone awareness, and emergency evidence capture. Firebase provides authentication, application data, file storage, notifications, and callable backend functions.

## Current features

- Email/password authentication with email OTP verification
- Biometric or PIN reauthentication
- SOS activation, deactivation, and community alerts
- Offline SOS queuing and delivery when connectivity returns
- Live location and trip sharing
- Community map with incident reports and South African danger-zone data
- Trusted contacts, invitations, and next-of-kin management
- Direct messages, media messages, and shared trip IDs
- Photo, video, and audio evidence capture
- Firebase Cloud Messaging and local notifications
- Android shake and power-button emergency triggers

The main authenticated interface contains five sections: Home, Emergency, Community, Tools, and Settings.

## Technology

- Flutter and Dart
- Firebase Authentication, Cloud Firestore, Realtime Database, Storage, Cloud Messaging, and Cloud Functions
- Google Maps and device location services
- Android native foreground services for shake and power-button detection
- TypeScript Firebase Functions for OTP email and push-notification delivery

## Supported platforms

Android and iOS are the intended mobile targets. Flutter-generated web, macOS, Linux, and Windows scaffolding is present, but those targets are not currently documented or verified and several mobile/device features will not work on them without additional implementation.

## Prerequisites

- A Flutter SDK that includes Dart `>=3.10.0 <4.0.0`
- Android Studio/Android SDK with Java 17 for Android development
- Xcode and CocoaPods on macOS for iOS development
- A Firebase project and Firebase CLI
- Node.js 24 and npm when developing or deploying Firebase Cloud Functions
- A Google Maps API key with the Maps SDK enabled for each target platform
- A physical device for reliable testing of notifications, biometrics, background location, sensors, camera, microphone, and SOS triggers

Confirm the installed toolchain before continuing:

```bash
flutter doctor
dart --version
node --version
firebase --version
```

Node.js and Firebase CLI are only required for work involving Cloud Functions or Firebase deployment.

## Initial setup

1. Install Flutter dependencies:

   ```bash
   flutter pub get
   ```

2. Configure the project for your Firebase environment as described below.

3. Start an Android emulator, iOS simulator, or connected device:

   ```bash
   flutter devices
   flutter run
   ```

## Firebase configuration

The app calls `Firebase.initializeApp()` using native platform configuration. It therefore requires a valid configuration file for each mobile target:

- Android: `android/app/google-services.json`
- iOS: `ios/Runner/GoogleService-Info.plist`

Configuration files may already exist in a checkout, but they are tied to a specific Firebase project. Replace them when using another Firebase project and ensure their package/bundle identifiers match the application.

The current Android application ID is `com.emihle.purplesafety`. The iOS bundle ID is defined by the Runner target in Xcode.

Enable and configure these Firebase products:

- Authentication (including the sign-in providers used by the app)
- Cloud Firestore
- Realtime Database
- Cloud Storage
- Cloud Messaging
- Cloud Functions

Firestore security rules and indexes must permit the app's authenticated workflows. The application uses data for users, contacts, invitations, alerts, incidents, active SOS events, chats/direct messages, trips, media, and global alerts. Production rules should grant only the minimum access required for each workflow.

### Cloud Functions

The `functions/` directory contains the Firebase Cloud Functions source. Function methods are implemented and exported from `functions/src/`; they are then deployed to Firebase. The project currently provides:

- `sendOTPEmail` for registration OTP delivery
- `sendNotification` for authenticated FCM notification delivery

When working on Cloud Functions, install their dependencies once:

```bash
cd functions
npm ci
cd ..
```

Implement or update functions in `functions/src/`. The following command can be used to validate that the TypeScript source compiles before deployment:

```bash
cd functions
npm run build
cd ..
```

To deploy the functions, log into Firebase and select the intended project from the repository root:

```bash
firebase login
firebase use <project-id>
firebase deploy --only functions
```

To run the functions locally with the Firebase emulator:

```bash
cd functions
npm run serve
```

Do not commit mail passwords, service-account credentials, or unrestricted API keys. Configure email credentials with Firebase Secret Manager/environment configuration and update the Function to read those values at runtime before deploying. Any credential that has previously been committed should be revoked and replaced.

## Google Maps

Enable the appropriate Google Maps SDKs in Google Cloud and restrict each API key to the relevant application identifier and API.

The Android map key is currently read from the `com.google.android.geo.API_KEY` metadata entry in `android/app/src/main/AndroidManifest.xml`. Replace the development value for your environment and avoid committing an unrestricted production key. iOS also requires its Maps SDK/API-key configuration before map features can run there.

## Platform setup

### Android

The manifest includes permissions for location, background location, contacts, biometrics, SMS, camera, microphone, notifications, wake locks, and foreground services. It also declares native foreground services for shake and power-button SOS triggers.

Review permission and foreground-service requirements against the Android SDK version you target. Background location and notification permissions must be granted by the user, and the emergency triggers should be tested on a real device. Configure a proper release signing key before publishing; the current release build uses debug signing for development convenience.

### iOS

Open `ios/Runner.xcworkspace` in Xcode and configure:

- The correct development team and bundle identifier
- Push Notifications capability
- Background Modes required by the final app behavior, including remote notifications and location where applicable
- APNs credentials in Firebase Cloud Messaging
- Google Maps SDK/API key

Camera, microphone, photo-library, contacts, Face ID, and location usage descriptions are already present in `Info.plist`. Verify all background behavior and notification flows on a physical device.

## Running and building

Run in development:

```bash
flutter run
```

Build Android:

```bash
flutter build apk --release
# or
flutter build appbundle --release
```

Build iOS on macOS:

```bash
flutter build ios --release
```

## Tests and static analysis

```bash
flutter analyze
flutter test
```

The current test suite includes widget coverage and an SOS activation guard test. Device integrations and Firebase-backed workflows still require integration/manual testing against a configured environment.

## Project structure

```text
lib/
  authentication/  Sign-in, registration, OTP, and reauthentication
  contacts/        Trusted contacts and invitation workflows
  emergency/       Emergency state and SOS alert handling
  home/            Home dashboard and location overview
  incidents/       Community incident creation and display
  map/             Community map, presence, and location sharing
  messaging/       Direct messaging and shared trips
  safety/          Safety tools, biometrics, and evidence capture
  services/        Firebase, storage, notification, and location services
  settings/        Profile, next-of-kin, alerts, and preferences
  trip/            Live trip sharing and full-map tracking
functions/src/     Firebase Cloud Function implementations
assets/            Branding and South African danger-zone data
android/, ios/     Native mobile configuration and integrations
test/              Flutter unit and widget tests
```

## Security and production readiness

Before a production release:

- Revoke any credentials or API keys that were committed to source control.
- Move backend credentials to Firebase Secret Manager.
- Restrict Google Maps and Firebase keys by application and API.
- Review Firestore, Realtime Database, and Storage security rules.
- Replace Android debug signing with a protected release signing configuration.
- Review cleartext-network and broad transport-security exceptions.
- Validate SOS behavior, background location, notifications, and offline delivery on supported OS versions.
- Add automated integration tests for critical emergency workflows.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for the contribution workflow and coding guidelines.

## License

No `LICENSE` file is currently included. Confirm the intended license with the project maintainers before distributing or reusing the code.
