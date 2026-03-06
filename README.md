# Vyajan

Vyajan is where your links stop living in 47 open tabs and start behaving.

Built with Flutter, backed by Firebase, and organized around `Inbox`, `Library`, `Insights`, and `Settings`.

## What It Does

- Google Sign-In authentication
- Firestore-backed link storage and updates
- Link metadata/thumbnail enrichment
- Inbox-to-library workflow
- Insights and analytics-oriented tracking
- Notification scheduling support

## Stack

- Flutter + Dart
- Firebase Core, Auth, Firestore, Analytics
- Riverpod for state
- GoRouter for navigation

## Project Structure

Inside `lib/`:

- `components/` reusable UI pieces
- `models/` domain data models
- `providers/` Riverpod providers
- `repositories/` Firestore data access
- `screens/` app screens
- `services/` auth, analytics, notifications, enrichment, migrations
- `theme/` app theming

## Prerequisites

- Flutter SDK compatible with `sdk: >=3.4.4 <4.0.0`
- Android Studio + Android SDK
- Java 21 (Android Studio JBR recommended)
- Xcode + CocoaPods for iOS
- A configured Firebase project

## Setup

1. Clone and enter the repo:

```bash
git clone https://github.com/anima-regem/Vyajan.git
cd Vyajan
```

2. Install packages:

```bash
flutter pub get
```

3. Add local Firebase files (these are gitignored on purpose):

- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist`
- `lib/firebase_options.dart`

4. Register your debug key fingerprints for Android Google Sign-In:

```bash
keytool -list -v \
  -alias androiddebugkey \
  -keystore "$HOME/.android/debug.keystore" \
  -storepass android \
  -keypass android
```

Take both `SHA1` and `SHA256`, add them in Firebase Android app settings, and download a fresh `google-services.json`.

## Run

```bash
flutter run
```

## Build

Release APKs (split per ABI):

```bash
flutter build apk --release --split-per-abi
```

Outputs:

- `build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk`
- `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`
- `build/app/outputs/flutter-apk/app-x86_64-release.apk`

Release App Bundle:

```bash
flutter build appbundle --release
```

Output:

- `build/app/outputs/bundle/release/app-release.aab`

## Release Workflow (GitHub)

Create and push a tag:

```bash
git tag -a vX.Y -m "Release vX.Y"
git push origin vX.Y
```

Create release:

```bash
gh release create vX.Y --title "vX.Y" --generate-notes
```

Upload assets:

```bash
gh release upload vX.Y path/to/artifact --clobber
```

## What Must Stay Out Of Git

These are local-only or sensitive and should not be committed:

- `android/app/google-services*.json`
- `ios/Runner/GoogleService-Info*.plist`
- `lib/firebase_options.dart`
- `android/local.properties`
- `.env*`
- `*.jks`, `*.keystore`, `*.p8`, `*.p12`, `*.pem`, `*.cer`
- `release_assets/`
- `.gradle-local/`

## Troubleshooting

### Google Sign-In: `ApiException: 10`

This usually means Firebase OAuth fingerprints do not match your local signing key. Re-check SHA1/SHA256 in Firebase and replace `google-services.json`.

### Android build: `requires core library desugaring`

`android/app/build.gradle` must include:

- `coreLibraryDesugaringEnabled true` in `compileOptions`
- `coreLibraryDesugaring "com.android.tools:desugar_jdk_libs:2.1.5"` in `dependencies`

## License

MIT. See `LICENSE`.
