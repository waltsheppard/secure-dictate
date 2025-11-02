# Secure Dictate

Secure Dictate extends the original AuthApp1 authentication client with a HIPAA-oriented dictation workflow.  
The app still integrates with AWS Cognito via Amplify for identity, and now layers in high-fidelity audio capture, offline-safe uploads to S3, and DynamoDB metadata synchronization.

## Prerequisites
- Flutter 3.7.0 or newer (`flutter --version` to confirm)
- Node.js 20+ (aligns with the latest Amplify CLI overrides tooling)
- AWS CLI configured with an IAM user/role that can create Cognito resources (`aws configure`)
- Amplify CLI (`npm install -g @aws-amplify/cli`)
- Xcode (for iOS) and/or Android Studio SDK/NDK (for Android)

## 1. Clone & bootstrap the repo
```bash
git clone <repo-url>
cd secure-dictate
flutter pub get
```

## 2. Configure Amplify backend
1. Initialize Amplify in the project root:
   ```bash
   amplify init
   ```
   - Choose **Flutter** as the default editor, enable iOS/Android (and Web if needed), then pick your AWS profile.

2. Add the Cognito auth resource:
   ```bash
   amplify add auth
   ```
   - Select **Walkthrough all the auth configurations** so you can set email + phone sign-in and update password policy/MFA as needed.

3. Deploy the baseline backend:
   ```bash
   amplify push
   ```
   - This provisions the Cognito User Pool/Identity Pool and uploads the generated configuration to S3.

4. Pull the updated backend metadata locally:
   ```bash
   amplify pull
   ```
   - This refreshes `amplify/backend/auth/*/cli-inputs.json`, `parameters.json`, and `team-provider-info.json` so the repo reflects the console changes.

## 3. Update the Flutter config
1. Copy the generated values from `amplify/team-provider-info.json` or `amplify/backend/amplify-meta.json` into `lib/amplifyconfiguration.dart`.  
   Replace the placeholder strings:
   ```json
   "PoolId": "us-east-1_XXXXXXXXX",
   "AppClientId": "XXXXXXXXXXXXXXXXXXXXXXXXXX",
   "Region": "us-east-1",
   "cognito_identity_pool_id": "us-east-1:xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
   ```
2. For apps with an App Client secret disabled (recommended for native apps), remove the `AppClientSecret` property completely.
3. Confirm that the Cognito app client exposes `email`, `phone_number`, and the verification flags; if you make changes later, rerun `amplify pull` and update this file again.

## 4. Dictation module overview
- High-quality audio capture powered by the [`record`](https://pub.dev/packages/record) plugin (48 kHz WAV by default).
- Playback handled through [`just_audio`](https://pub.dev/packages/just_audio).
- Files are persisted to an app-private `dictations/` directory with SHA-256 checksums before upload.
- Each dictation receives an incrementing sequence number and 12-character clinician-facing tag (`#000123 • ABCD34…`) that travels with the audio and metadata.
- Offline queue stored locally (JSON-backed today; upgrade path to SQLite/Isar) ensures large files (≤100 MB) are never lost.
- Once an upload succeeds, the worker deletes the local audio file and queue entry so only in-flight dictations remain on device.
- Upload pipeline uses Amplify Storage (S3) plus Amplify API/AppSync for DynamoDB metadata writes.
- Connectivity-aware worker retries failed uploads with exponential backoff; held dictations stay local until clinicians resume them.
- See [`docs/dictation_architecture.md`](docs/dictation_architecture.md) for detailed component design.

### Dictation screen controls
| Control | Description |
| --- | --- |
| Record / Pause | Large toggle button to start/pause capture. |
| Submit | Finalizes recording, enqueues it for upload, and triggers the sync worker. |
| Hold / Resume Hold | Moves the dictation to a held state so it stays local until explicitly resumed. |
| Delete | Discards the current dictation and removes local artifacts. |
| Playback | Review the in-progress dictation before submitting. |

### Additional dependencies
Add these to your local environment before running the dictation build:
- `amplify_storage_s3`, `amplify_api` (Amplify plugins for uploads + metadata)
- `record`, `just_audio`, `path_provider`, `path`, `uuid`, `connectivity_plus`

After updating `pubspec.yaml`, run:
```bash
flutter pub get
```

## 5. Platform-specific setup
### iOS
- In `ios/Runner/Info.plist` add the following keys if missing:
  ```xml
  <key>NSFaceIDUsageDescription</key>
  <string>Used to enable biometric sign-in.</string>
  <key>NSUserTrackingUsageDescription</key>
  <string>Used for authentication analytics.</string>
  ```
- Run `cd ios && pod install && cd ..` after any dependency changes.

### Android
- Ensure `android/app/build.gradle.kts` sets `minSdk = 23` (required by `local_auth` and Amplify).
- If using biometric auth, confirm `android/app/src/main/AndroidManifest.xml` includes:
  ```xml
  <uses-permission android:name="android.permission.USE_BIOMETRIC" />
  <uses-permission android:name="android.permission.USE_FINGERPRINT" />
  ```

## 6. Run the app
```bash
flutter run
```
- The splash screen configures Amplify automatically; on success, you should land on the login screen. Accounts are provisioned centrally—use the username/password provided by your administrator. First-time users will be prompted to set a new password and confirm their contact details.

## 7. Managing environments
- Use `amplify env add` to create additional AWS environments (e.g., dev/stage/prod).
- Pull backend updates from teammates with `amplify pull`.
- After backend changes, confirm `lib/amplifyconfiguration.dart` reflects the latest values.

## 8. Runtime configuration
- Authentication rules (email/phone regex, password length, default Remember Me) are centralized in `lib/config/app_environment.dart`.
- For local testing the `dev` environment skips phone verification—only email must be confirmed. Flip `requirePhoneVerification` to `true` for dev (or run with `APP_ENV=staging|prod`) once SMS delivery is ready.
- Select an environment at runtime with `--dart-define APP_ENV=<dev|staging|prod>`, e.g.:
  ```bash
  flutter run --dart-define APP_ENV=staging
  ```
  Each environment overrides the `AuthConfig` provided through Riverpod so future apps can tailor policies without touching UI code.

## 9. Useful commands
| Command | Description |
| --- | --- |
| `amplify status` | Shows categories to be deployed |
| `amplify console auth` | Opens the Cognito console in a browser |
| `amplify push` | Deploys the local backend changes |
| `amplify pull --restore` | Restores backend environment configuration |

## 10. Troubleshooting
- **Amplify not configured**: Ensure `_AmplifyBootstrapper.ensureConfigured()` runs before `runApp` (already handled in `lib/main.dart`).
- **`AmplifyAlreadyConfiguredException`**: Safe to ignore; the app protects against double configuration.
- **Biometric sign-in fails**: Check that `local_auth` is correctly configured per platform and that the device supports biometrics.
- **Widgets tests failing**: Update or remove the default `widget_test.dart`; it still references the counter template.
- **`NotAuthorizedException: attempted to write unauthorized attribute`**: Typically appears if an admin disables the required attributes in Cognito. Re-enable email/phone updates (or remove them from the client permissions) and run `amplify pull`.

- **Styling tweaks**: Update `lib/theme/app_theme.dart` for shared colors, typography, and spacing. Auth screens reuse `AuthScaffold` (`lib/theme/layout/auth_layout.dart`) so downstream apps can swap themes without rewriting forms.
- **CI/CD templates**: Use the provided workflows:
  - `.github/workflows/ci.yml` – main branch validation (format, analyze, test, Android release build).
  - `.github/workflows/cd-android.yml` – manual deploy template with keystore + Play Store placeholders.
  - `.github/workflows/cd-ios.yml` – manual deploy template with signing asset placeholders.

## 11. Security controls
- **Device attestation**: The app blocks rooted/jailbroken, emulator, and mock-location devices (see `safe_device` checks in `lib/state/security_controller.dart`). For development builds (`flutter run`), the guard is relaxed; release builds enforce it.
- **OS passcode/biometric enforcement**: On launch/resume the session gate (`lib/security/security_gate.dart`) requires LocalAuth to succeed with biometric or device passcode. Devices without a secure lock screen are rejected with remediation guidance.
- **Idle session lock**: User interaction is monitored via `InactivityGuard`; after two minutes of inactivity the session locks and re-prompts for authentication. Backgrounding the app immediately locks the session.
- **Sign-out fallback**: When access is blocked or the user can’t re-authenticate, the security screen offers a managed sign-out that clears local credentials while preserving “Remember me” preference.
- **Operational checklist**: Pair these client controls with MDM enforcement, Cognito MFA, audit logging, and incident response policies before handling PHI in production.
- **Profile settings**: The in-app profile only exposes password rotation and security PIN management; email/phone changes and contact verification remain administrator workflows in Cognito.
- **Biometric quick sign-in**: By default biometrics simply unlock an existing remembered session; set `allowBiometricCredentialLogin` in `AuthConfig` to `true` if policy allows caching passwords for full biometric login.
- **Federated login (optional)**: Switch `AuthConfig.authMode` to `AuthMode.saml` for environments that authenticate through Cognito Hosted UI + SAML IdPs (e.g., Microsoft Entra). The login screen swaps to a single "Sign in with Microsoft" button and hides the local password reset flow.

## 12. User provisioning
- **Create users centrally** using the Cognito console, CLI (`amplify auth add-user`), or AdminCreateUser API. Supply email and phone so preprovisioned accounts match the app’s required attributes.
- **Distribute temporary credentials** to clinicians and require them to set a new password at first login. The app already handles the `NEW_PASSWORD_REQUIRED` challenge during sign-in.
- **Contact verification**: First login triggers an email/SMS code challenge; the home screen also reminds users to verify their contact info until both email and phone are confirmed. Administrators can resend verification codes from Cognito if needed.
- **Profile updates**: Clinicians can change their Cognito password from the Profile screen and set/reset the app security PIN; all other profile edits (name, title, contact changes) are handled centrally by administrators.
- **Disable self sign-up** in Cognito (no Hosted UI) and keep the app’s self-registration UI hidden, ensuring only pre-authorized staff receive access.

For deeper customization, review the official docs:
- [Amplify Flutter Auth Guide](https://docs.amplify.aws/flutter/build-a-backend/auth/)
- [AWS Cognito User Pools](https://docs.aws.amazon.com/cognito/latest/developerguide/cognito-user-identity-pools.html)

With Amplify and Cognito configured, continue iterating on the UI, state management, and API integrations as needed. Happy building!
