# Dictation Feature Architecture

## Objectives
- Capture high fidelity audio (48 kHz+ PCM/CAF) with resilience against interruptions.
- Guarantee no data loss by persisting recordings and metadata locally until S3/DynamoDB updates succeed.
- Support large uploads (≤100 MB) with retry/backoff and background completion.
- Maintain HIPAA-oriented controls: encryption at rest, authenticated transports, audit-friendly metadata.

## Key Components

### Recording Pipeline
- `DictationRecorder` abstraction wraps the platform recorder (`record` package) and enforces:
  - Elevated audio quality profile (uncompressed WAV on iOS/macOS, PCM/FLAC on Android).
  - Recording to an app-private directory surfaced by `path_provider`.
- On start: pre-generate a `DictationId` (UUID v4), allocate the next sequential number, generate a 12-character alphanumeric tag, and reserve a file path (`<seq>_<tag>_<uuid>.wav`).
  - On pause/resume: maintain a rolling segment list so an interrupted session can be resumed.
  - On stop: mux segments into a single file (using platform merge or simple concatenation for PCM).

### Playback Pipeline
- `DictationPlayer` abstraction (backed by `just_audio`) plays the in-progress file.
- Supports scrub/seek and exposes buffered position updates for the UI.

### Persistence & Queue
- `DictationRepository` coordinates:
  1. Persist metadata (`DictationRecord`) to a local store as soon as recording starts.
  2. Persist audio to disk in the `dictations/` directory.
  3. Expose Riverpod streams/selectors for UI state.
- `DictationQueueStore`
  - Backed by a lightweight local database (initially JSON via `File`; upgrade path to SQLite/Isar).
  - Each `QueuedUpload` tracks:
    - `dictationId`
    - local file path + checksum (SHA256 of file)
    - status (`recording`, `ready`, `held`, `uploading`, `failed`, `synced`)
    - retries, last error, timestamps
  - Writes are `fsync`-ed to prevent data loss on crash.
- On resume/app launch the queue is rehydrated and pending uploads are revived.

### Upload & Metadata Sync
- `DictationUploader` handles transfer:
  - Upload audio to S3 using `Amplify.Storage.uploadFile`.
  - Write metadata to DynamoDB via REST endpoint (`Amplify.API.post`) or AppSync GraphQL.
  - Both operations wrapped in a single transactional workflow: metadata marked as uploaded only once S3+DB succeed.
  - Retries use exponential backoff with jitter; fatal errors move to `failed` state surfaced to the UI.
  - After a successful upload, the queue worker deletes the local audio file and removes the queue entry so the device only retains in-progress dictations.
- Queue processing runs through a background worker (`DictationSyncWorker`) triggered by:
  - Successful recording completion.
  - Connectivity regained (`Connectivity().onStatusChange`).
  - Manual retry from UI.

### Security Considerations
- Local files encrypted at rest (defer to `flutter_secure_storage`-managed symmetric key with `file_cipher` helper).
- Metadata and audio share the same dictation ID for audit traceability.
- Upload pipeline enforces TLS (handled by Amplify) and avoids writing PHI to logs.

### Riverpod Surface
- `dictationStateProvider` (notifier) drives the recorder UI.
- `dictationQueueProvider` exposes pending/completed uploads.
- `dictationPlayerProvider` wraps playback controls.

## User Flow Summary
1. User hits **Record**: controller creates entry, starts recorder.
2. **Pause/Resume** toggles capture without losing buffered audio.
3. The active session is labeled in UI and metadata as `#<sequence> • <tag>` for cross-system traceability.
4. **Hold** pauses the active dictation locally (no upload attempts) and lets clinicians resume recording later.
5. **Delete** removes current dictation (wipes file + metadata).
6. **Submit** stops recording (if active), enqueues for upload, and initiates sync worker.
7. If backend unreachable, dictation remains queued; sync worker retries when connectivity returns.
8. Playback area streams the current file so user can review before submitting.

## Next Implementation Steps
1. Add dependencies: `record`, `just_audio`, `path_provider`, `uuid`, `amplify_storage_s3`, (future) `connectivity_plus`.
2. Implement `dictation` feature module mirroring existing `auth` layout.
3. Replace `HomeScreen` body with `DictationScreen` built on Riverpod controllers.
4. Integrate offline queue persistence and sync worker.
5. Wire Amplify Storage/API once backend endpoints exist and update environment config accordingly.
