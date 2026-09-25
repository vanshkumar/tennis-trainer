## Deferred Items

- Existing Xcode 27 warnings in `VideoPlayerManager.swift` concern deprecated `AVAsset(url:)`, synchronous track/transform access, and the unused `isPlayable` local.
  status: open
  **Scope:** Pre-existing playback code; lifecycle/asset-loading work belongs to Phase 2. These warnings do not fail the Phase 1 tests.

- Existing `weakManager` mutability and AppIntents metadata-extraction warnings remain unchanged.
  status: open
  **Scope:** Compiler/build metadata advisories unrelated to the association and cue-state changes.
