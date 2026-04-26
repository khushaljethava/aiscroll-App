# Implementation Plan: Fix `share_plus:compileDebugKotlin` "Unresolved reference" build failure

## Task Type
- [x] Backend / Build-toolchain (Android Gradle + Kotlin)
- [ ] Frontend
- [ ] Fullstack

## Diagnosis Summary

**Symptom**: `:share_plus:compileDebugKotlin` fails with multiple `Unresolved reference` errors for in-package symbols (`ShareSuccessManager`, `setCallback`, `SharePlusPendingIntent`, `unavailable`) and a generic-type inference error inside `Share.kt:126`.

**Key fact**: All referenced symbols **do exist** in the same package on disk:
```
C:/Users/ADMIN/AppData/Local/Pub/Cache/hosted/pub.dev/share_plus-12.0.2/android/src/main/kotlin/dev/fluttercommunity/plus/share/
├── MethodCallHandler.kt
├── Share.kt
├── ShareFileProvider.kt
├── SharePlusPendingIntent.kt
├── SharePlusPlugin.kt
└── ShareSuccessManager.kt   ← exists, internal class
```

When in-package symbols are missing only at compile-time, the cause is almost always one of:

1. **Stale Kotlin / Gradle incremental compilation cache.** A previous build saw an older share_plus or different sources; the daemon's KIC snapshot is now inconsistent with the on-disk sources. There is already a populated `build/share_plus/.transforms/...` tree under the project, confirming a prior build with different inputs.
2. **Toolchain version drift** between the project and what `share_plus 12.0.2` was published against:
   - share_plus 12.0.2 internal `build.gradle`: `kotlin_version = '2.2.0'`, AGP `8.12.1`
   - project `android/settings.gradle.kts`: Kotlin `2.2.20`, AGP `8.11.1`
   - project `gradle-wrapper.properties`: Gradle `8.14`
   The Kotlin K2 compiler in 2.2.x has occasionally tightened resolution rules across patch versions; combined with stale incremental data this manifests as in-package "unresolved reference" errors.
3. **Pub-cache file lock / corruption** on Windows. The package is sometimes left in a half-extracted state when an antivirus or another `pub get` writes during read; an `Unresolved reference` can appear if a `.kt` was momentarily zero-byte (we have already verified file contents, so this is the *least likely* cause here).

**Order of attack**: cheapest fix first, escalate only if it persists.

## Implementation Steps

### Step 1 — Full clean (kills stale caches)

Run from project root `C:\Users\ADMIN\random\test3\aiscroll`:

```bash
flutter clean
```

```bash
cd android
./gradlew --stop
./gradlew clean
cd ..
```

Then nuke the project-level build outputs and Gradle daemon scratch:

- Delete: `C:\Users\ADMIN\random\test3\aiscroll\build`
- Delete: `C:\Users\ADMIN\random\test3\aiscroll\android\.gradle`
- Delete: `C:\Users\ADMIN\random\test3\aiscroll\android\app\build`
- Delete (Kotlin daemon caches per user): `C:\Users\ADMIN\.gradle\caches\build-cache-1`
- Delete (Kotlin compiler caches per user): `C:\Users\ADMIN\.gradle\caches\transforms-*` is **not** required, but if Step 2 still fails delete it too.

**Expected deliverable**: clean working tree, no build artefacts.

### Step 2 — Refresh pub cache for share_plus only (handles half-extracted package)

```bash
flutter pub cache clean -p share_plus
flutter pub get
```

If `flutter pub cache clean -p` is unavailable on the installed Flutter version, fall back to:

```bash
rm -rf "C:/Users/ADMIN/AppData/Local/Pub/Cache/hosted/pub.dev/share_plus-12.0.2"
flutter pub get
```

Verify the six `.kt` files reappear under the freshly extracted `share_plus-12.0.2/android/src/main/kotlin/...` directory and that none are zero-byte.

**Expected deliverable**: pristine share_plus 12.0.2 in pub cache.

### Step 3 — Re-attempt the build

```bash
flutter run -d <device-id>
```

or

```bash
cd android && ./gradlew :app:assembleDebug --no-build-cache --no-configuration-cache --rerun-tasks
```

Flags `--no-build-cache --rerun-tasks` ensure the corrupted incremental snapshot is not re-used, even if Step 1 missed something.

**Expected deliverable**: APK built, no `Unresolved reference` errors. **If green → STOP here**, the issue was stale cache. Skip remaining steps.

### Step 4 — (Only if Step 3 still fails) Align Kotlin to the version share_plus was built against

Edit `android/settings.gradle.kts` line 23:

```kotlin
// before
id("org.jetbrains.kotlin.android") version "2.2.20" apply false

// after
id("org.jetbrains.kotlin.android") version "2.2.0" apply false
```

This matches `share_plus-12.0.2/android/build.gradle` (`ext.kotlin_version = '2.2.0'`). Other Flutter plugins on this project (`firebase_*`, `google_sign_in`, `flutter_local_notifications`, `cached_network_image`) are all compatible with Kotlin 2.2.0 — none of them require 2.2.20-specific features.

Re-run Step 1 + Step 3 after this edit.

**Expected deliverable**: build succeeds with Kotlin 2.2.0.

### Step 5 — (Fallback if Step 4 still fails) Pin share_plus to a known-good version

If the toolchain alignment in Step 4 doesn't help, the pub-published 12.0.2 artefact may have a packaging bug for this Kotlin version. Downgrade in `pubspec.yaml`:

```yaml
# before
share_plus: ^12.0.0

# after
share_plus: 12.0.1
```

Versions `10.1.4`, `12.0.1`, and `9.0.0` are already present in the user's pub cache and have all built successfully on similar toolchains historically. Choose the highest of those that is API-compatible with the existing call-sites:

- Check `lib/**/*.dart` for `Share.share`, `Share.shareXFiles`, etc.
- 12.0.1 → 12.0.2 is patch-level, no API change expected.
- 10.x → 12.x changed `Share.share` to `SharePlus.instance.share(ShareParams(...))`. Only downgrade to 10.1.4 if 12.0.1 also fails AND we are willing to update call-sites.

Then:

```bash
flutter pub get
```

…and repeat Step 1 + Step 3.

**Expected deliverable**: build succeeds with a downgraded share_plus.

### Step 6 — Verification

After whichever step turned the build green:

```bash
flutter run -d <device>
```

In the running app, exercise any code path that calls share_plus (e.g. a "Share" button on a news card) and confirm the system share sheet opens and returns a result without crashing. This protects against silent runtime regressions caused by mismatched plugin / API versions.

**Expected deliverable**: app runs on `moto g13`, share sheet works.

## Key Files

| File | Operation | Description |
|---|---|---|
| `android/settings.gradle.kts:23` | Modify (Step 4 only) | Pin Kotlin Gradle plugin to `2.2.0` to match share_plus |
| `pubspec.yaml:17` | Modify (Step 5 only) | Pin `share_plus` to `12.0.1` (or lower) if 12.0.2 is the bad artefact |
| `pubspec.lock` | Auto-regenerated | by `flutter pub get` after Step 5 |
| `build/`, `android/.gradle/`, `android/app/build/` | Delete (Step 1) | Forces full recompile, kills stale incremental Kotlin cache |
| `C:/Users/ADMIN/AppData/Local/Pub/Cache/hosted/pub.dev/share_plus-12.0.2/` | Delete + re-fetch (Step 2) | Recovers from any pub-cache corruption |
| `lib/**/*.dart` | Read-only audit (Step 5 only) | Confirm `share_plus` API call-sites are compatible before downgrade |

No production Dart/Kotlin code in `aiscroll/lib/**` or `aiscroll/android/app/**` should need to change for Steps 1–4. Step 5 only changes one line in `pubspec.yaml` unless an API mismatch is discovered.

## Risks and Mitigation

| Risk | Mitigation |
|---|---|
| `flutter clean` removes generated files we depend on (e.g. firebase config) | Firebase config files (`google-services.json`, `GoogleService-Info.plist`) live in `android/app/` and `ios/Runner/`, not under `build/` — they are not touched by `flutter clean`. Verified via Flutter docs and project layout. |
| Kotlin 2.2.0 downgrade breaks another plugin that needs 2.2.20 | Audit `pubspec.lock` after the change for any plugin pinning Kotlin ≥ 2.2.20 in its own `build.gradle`. None of the listed deps do today, but re-check on `pub upgrade`. |
| share_plus 12.0.1 has API differences from 12.0.2 | They are patch-level on the same major; verify by running tests + manual smoke test in Step 6. If a test breaks, document the call-site change and pin to 12.0.1 in `pubspec.yaml`. |
| `pub cache clean -p` flag missing on older Flutter | Documented filesystem-level fallback (`rm -rf` of the version directory) in Step 2. |
| Deleting `~/.gradle/caches/build-cache-1` slows next build for **all** Gradle projects on this machine | Acceptable — it is a cache; rebuild is at most a few minutes per project and only on first build after the delete. Do not delete `~/.gradle/wrapper/` or `~/.gradle/caches/modules-2/`. |
| Antivirus locks files in pub cache during re-fetch on Windows | If `flutter pub get` errors with `os error 32 (sharing violation)`, exclude `C:\Users\ADMIN\AppData\Local\Pub\Cache` from real-time scanning, or run the command from an elevated shell. |

## Decision Tree (TL;DR)

```
Step 1 + 2 + 3
  ├── green → DONE
  └── still red
        └── Step 4 (Kotlin 2.2.20 → 2.2.0) → Step 1 + 3
              ├── green → DONE
              └── still red
                    └── Step 5 (share_plus 12.0.2 → 12.0.1) → Step 1 + 3 → Step 6

```

## SESSION_ID (for /ccg:execute use)

- CODEX_SESSION: not-used (codeagent-wrapper not installed in this environment)
- GEMINI_SESSION: not-used (codeagent-wrapper not installed in this environment)

> Note: this plan was synthesized by Claude only; the configured `codex` / `gemini` wrappers (`~/.claude/bin/codeagent-wrapper`) and `~/.claude/.ccg/prompts/...` are not installed on this machine, and `ace-tool` MCP is not registered. Phase 1 context retrieval used built-in `Read` / `Glob` / `Grep` / `Bash`. Phase 2 dual-model analysis was therefore performed by Claude alone.
