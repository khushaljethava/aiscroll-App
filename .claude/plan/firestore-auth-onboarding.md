# Plan: Cloud Firestore + Email Auth + Onboarding Redesign

**Date:** 2026-04-26
**Scope:** Persist user profile to Cloud Firestore (Option A — fastest to ship), add email/password registration & login alongside existing Google sign-in, and redesign the onboarding flow to fit the new auth-first model.

---

## 1. Goals & Non-Goals

### Goals
1. **Firestore as source-of-truth for signed-in users.** Profile, progress, bookmarks, learned cards, SRS schedule, daily quests, badges all sync to `users/{uid}` in Firestore.
2. **Three auth paths:** Email+password (register / login), Google sign-in (existing), Continue as guest.
3. **Onboarding redesign:** Auth comes *first*, then preference setup. New "Login" path skips preference screens (pulled from Firestore). New users walk through preferences and land them in Firestore on completion.
4. **Multi-device continuity:** Sign in on a fresh device → progress restored from Firestore.
5. **Guest → account upgrade:** Guest can sign up later and their local progress merges into the new Firestore account.

### Non-Goals (this iteration)
- No password reset flow yet (defer; just surface "forgot password" disabled for v1).
- No email verification gate (allow access immediately; add a soft banner).
- No Apple sign-in implementation (button stays stubbed).
- No real-time multi-device listener (we sync on app start + on local mutation, not via Firestore snapshot streams). Adding live listeners is a follow-up.
- No Cloud Functions / server-side rules beyond standard Firestore rules.
- No anonymous auth migration via `linkWithCredential` — guest data merge handled in app code (simpler, but less atomic).

---

## 2. Current State Snapshot

| Layer | Today |
|---|---|
| Auth | `AuthService.signInWithGoogle()` (lib/data/remote/auth_service.dart) — Firebase Auth + Google provider only. |
| Persistence | `PreferencesService` writes `UserProfile.toMap()` JSON to SharedPreferences key `user_profile`. Daily quests, news, manifest also there. |
| Identity | `UserProfile.id` = stable guest UUID. `firebaseUid` populated when signed in. `isGuest` is the authoritative flag. |
| Onboarding | Splash → Persona → Knowledge Level → Topics → Goal → Auth (Google / Apple-stub / Skip) → news. Auth is the *last* step. |
| Firebase setup | `firebase_core`, `firebase_auth`, `firebase_app_check`, `firebase_messaging`, `google_sign_in` already in pubspec. App Check active. `google-services.json` wired. |
| Router | go_router with `refreshListenable` on `PreferencesService.revision` and a simple `onboarding_complete` boolean redirect. |

---

## 3. Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                          UI (Riverpod)                          │
│  WelcomeScreen → LoginScreen / RegisterScreen / OnboardingFlow  │
└────────────────────────────┬────────────────────────────────────┘
                             │
                ┌────────────┴────────────┐
                │                         │
        AuthService               UserNotifier
   (FirebaseAuth + Google)       (in-memory state)
                │                         │
                │                ┌────────┴────────┐
                │                │                 │
                │       PreferencesService   FirestoreService  (NEW)
                │           (local cache)    (cloud source)
                │                                   │
                ▼                                   ▼
          firebase_auth                      cloud_firestore
                                            users/{uid}/{...}
```

**Sync rule (write-through, last-write-wins per field for v1):**
- All `UserNotifier` mutations write to local SharedPreferences immediately (existing debounced behavior).
- When `state.firebaseUid != null`, the same mutation is *also* mirrored to Firestore via a debounced `FirestoreService.writeProfile(profile)` (500–1000 ms after last edit).
- On sign-in, Firestore is *pulled* and merged into local state (cloud wins for shared fields; local-only mutations made while offline since last sync are pushed up).
- Offline: Firestore SDK queues writes; local SharedPreferences keeps the UI snappy.

---

## 4. Firestore Data Model

### Collection: `users/{uid}`
Single document per signed-in user. Mirror of `UserProfile.toMap()` minus the local-only `id` field (we use `uid` as document id).

```jsonc
// users/abc123uid
{
  "schemaVersion": 1,
  "createdAt": <Timestamp>,
  "updatedAt": <Timestamp>,             // server timestamp, set on every write
  "lastSyncedClientAt": <Timestamp>,    // device-local time, for diagnostics

  // identity (mirrors UserProfile)
  "name": "Karan",
  "email": "user@example.com",
  "photoUrl": "https://...",
  "authProvider": "password" | "google",

  // gamification
  "totalXP": 240,
  "currentStreak": 5,
  "longestStreak": 12,
  "lastActiveDate": "2026-04-26",       // ISO date (no time)

  // progress
  "totalCardsRead": 87,
  "quizzesPassed": 12,
  "earnedBadgeIds": ["first_flame"],
  "bookmarkedCardIds": [...],
  "learnedCardIds": [...],
  "bookmarkedNewsIds": [...],
  "readNewsIds": [...],
  "trackProgress": { "ml_basics": 1 },

  // SRS map (subdocument-friendly; keep flat for v1)
  "cardReviews": {
    "card_xyz": { "ease": 2.5, "interval": 3, "nextReview": "2026-05-01" }
  },
  "dailyReviewCap": 20,

  // onboarding answers
  "persona": "student",
  "knowledgeLevel": "a_little",
  "selectedTopics": ["ai_basics","chatgpt_llms"],
  "dailyGoal": 10,

  // settings
  "isPremium": false,
  "hapticsEnabled": true,
  "soundEnabled": false,
  "notificationsEnabled": true,
  "reminderMinutesSinceMidnight": 480,
  "freezesAvailable": 1,
  "freezesUsedTotal": 0,
  "lastFreezeGrantedAt": null
}
```

**Daily-rollover-only fields stay local-only**, because they are noisy (every card read writes), not useful cross-device after rollover, and waste Firestore writes:
- `cardsReadToday`
- `readCardIdsToday`
- `reviewsDoneToday`

These are derived from / scoped to one calendar day; writing them to Firestore on every card read is expensive and gives no benefit when the user opens a second device the next day. They reset locally on rollover.

### Collection: `users/{uid}/dailyQuests/{yyyy-mm-dd}`
Per-day quest progress. Optional for v1 — quests are regenerated daily anyway, so we can skip this collection initially and only persist locally. **Decision: defer to v2.** Quests stay local-only.

### Indexes
None required for v1 — all reads are by document id (`users/{uid}`).

### Security Rules (`firestore.rules`)
```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    // Future-proof: deny everything else by default.
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

Deploy with `firebase deploy --only firestore:rules` (manual step, document in README).

---

## 5. Implementation Steps

### Phase A — Firestore plumbing (backend, no UI change)

#### Step A1: Add dependencies
**File:** `pubspec.yaml`
```yaml
dependencies:
  cloud_firestore: ^5.4.4   # match the firebase_core 3.6.0 family
```
Run `flutter pub get`.

**Acceptance:** `import 'package:cloud_firestore/cloud_firestore.dart'` resolves; no version conflicts with `firebase_core ^3.6.0`, `firebase_auth ^5.3.1`.

#### Step A2: Extend `UserProfile.toMap` / `fromMap` for cloud
**File:** `lib/data/models/user_model.dart`

- Add `static const schemaVersion = 1;`
- Add `UserProfile.fromFirestore(Map<String, dynamic> m, {required String uid})` — same as `fromMap` but uses `uid` as `id` and tolerates missing local-only fields.
- Add `Map<String, dynamic> toFirestoreMap()` — returns `toMap()` minus daily-rollover fields (`cardsReadToday`, `readCardIdsToday`, `reviewsDoneToday`) and minus `id` (Firestore key is `uid`). Adds `schemaVersion`, `updatedAt: FieldValue.serverTimestamp()`, `lastSyncedClientAt: DateTime.now().toIso8601String()`.

Pseudo:
```dart
Map<String, dynamic> toFirestoreMap() {
  final m = toMap();
  m.remove('id');
  m.remove('cardsReadToday');
  m.remove('readCardIdsToday');
  m.remove('reviewsDoneToday');
  m['schemaVersion'] = schemaVersion;
  m['updatedAt'] = FieldValue.serverTimestamp();
  m['lastSyncedClientAt'] = DateTime.now().toIso8601String();
  return m;
}
```

**Acceptance:** Round-trip test: `UserProfile.fromFirestore(profile.toFirestoreMap(), uid: 'x')` equals the original (modulo daily counters).

#### Step A3: Create `FirestoreService`
**New file:** `lib/data/remote/firestore_service.dart`

Responsibilities:
- `Future<UserProfile?> fetchProfile(String uid)` — reads `users/{uid}`, returns null if missing.
- `Future<void> writeProfile(UserProfile profile)` — `set(...)` with `SetOptions(merge: true)` so partial writes don't blow away other fields.
- `Future<void> createInitialProfile(UserProfile profile)` — `set(...)` without merge, sets `createdAt`. Called on registration / first sign-in.
- `Future<void> mergeGuestProgressIntoCloud(UserProfile cloud, UserProfile local)` — field-by-field merge (max of streaks, union of bookmark sets, sum of `totalCardsRead` if cloud is empty/zero else max, etc.). Returns merged profile and writes it.
- All writes are `try/catch` and never throw to UI — on failure, log via debugPrint, leave local state intact, retry on next mutation. Firestore SDK already handles offline queueing.

Pseudo:
```dart
class FirestoreService {
  FirestoreService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _users => _db.collection('users');

  Future<UserProfile?> fetchProfile(String uid) async {
    final doc = await _users.doc(uid).get();
    if (!doc.exists) return null;
    return UserProfile.fromFirestore(doc.data()!, uid: uid);
  }

  Future<void> writeProfile(UserProfile profile) async {
    final uid = profile.firebaseUid;
    if (uid == null) return;            // never write for guests
    try {
      await _users.doc(uid).set(profile.toFirestoreMap(), SetOptions(merge: true));
    } catch (e) { debugPrint('Firestore write failed: $e'); }
  }

  Future<void> createInitialProfile(UserProfile profile) async { /* ... */ }
}
```

Provider:
```dart
final firestoreServiceProvider = Provider<FirestoreService>((_) => FirestoreService());
```

**Acceptance:** Unit test against `cloud_firestore_mocks` (or a thin fake): write → read returns equivalent profile.

#### Step A4: Wire write-through into `UserNotifier`
**File:** `lib/data/providers/user_provider.dart`

- Inject `FirestoreService` via Ref.
- Add `Timer? _cloudSaveTimer; static const _cloudSaveDebounce = Duration(seconds: 1);`
- New helper `_scheduleCloudSave()` — only fires when `state.firebaseUid != null && !state.isGuest`.
- Modify `_scheduleSave()` to also kick `_scheduleCloudSave()` after the local debounce.
- On `_flushSave()` flush both timers.

Pseudo:
```dart
void _scheduleCloudSave() {
  if (state.isGuest || state.firebaseUid == null) return;
  _cloudSaveTimer?.cancel();
  _cloudSaveTimer = Timer(_cloudSaveDebounce, () {
    _cloudSaveTimer = null;
    _ref?.read(firestoreServiceProvider).writeProfile(state);
  });
}
```

Add `_scheduleCloudSave()` call to `_scheduleSave()` (which already runs after every mutation).

**Acceptance:** Adding XP locally triggers exactly one Firestore write within ~1.5 s; bursts coalesce into a single write.

#### Step A5: Pull-on-sign-in
Add `Future<void> pullFromCloudAndMerge(UserProfile cloud)` to `UserNotifier`:
- If local `isGuest` is false and `firebaseUid` matches incoming → simple cloud-wins replace, preserving local-only daily counters (`cardsReadToday`, `readCardIdsToday`, `reviewsDoneToday`).
- If local `isGuest` is true → merge: keep the bigger of each scalar (XP, streak, totalCardsRead, etc.), union of list/map fields (bookmarks, learnedCardIds, trackProgress, cardReviews — for SRS take per-card max of `nextReview`), then set identity fields (uid, email, name, photoUrl, isGuest=false).

Pseudo:
```dart
Future<void> pullFromCloudAndMerge({
  required String uid,
  required String? email,
  required String? displayName,
  required String? photoUrl,
}) async {
  final cloud = await _ref!.read(firestoreServiceProvider).fetchProfile(uid);
  if (cloud == null) {
    // First sign-in for this account — adopt local state, write up.
    state = state.copyWith(isGuest: false, firebaseUid: uid, email: email, name: displayName, photoUrl: photoUrl);
    await _flushSave();
    await _ref!.read(firestoreServiceProvider).createInitialProfile(state);
    return;
  }
  final merged = _mergeForUpgrade(local: state, cloud: cloud, uid: uid, email: email, displayName: displayName, photoUrl: photoUrl);
  state = merged;
  await _flushSave();
  await _ref!.read(firestoreServiceProvider).writeProfile(merged);
}
```

`_mergeForUpgrade` is a pure function — easy to unit test.

**Acceptance:**
- Fresh-device sign-in: cloud profile fully restored.
- Guest → sign-in upgrade: streak == max(local, cloud), bookmarks union, no data loss.

---

### Phase B — Email + Password auth

#### Step B1: Extend `AuthService`
**File:** `lib/data/remote/auth_service.dart`

Add:
```dart
Future<User> registerWithEmailPassword({
  required String email,
  required String password,
  required String displayName,
}) async {
  try {
    final cred = await _auth.createUserWithEmailAndPassword(email: email.trim(), password: password);
    await cred.user!.updateDisplayName(displayName);
    return cred.user!;
  } on FirebaseAuthException catch (e) {
    throw AuthFailed(_friendlyMessage(e));   // include weak-password / email-already-in-use cases
  }
}

Future<User> signInWithEmailPassword({
  required String email,
  required String password,
}) async {
  try {
    final cred = await _auth.signInWithEmailAndPassword(email: email.trim(), password: password);
    return cred.user!;
  } on FirebaseAuthException catch (e) {
    throw AuthFailed(_friendlyMessage(e));
  }
}
```

Extend `_friendlyMessage` to cover `email-already-in-use`, `weak-password`, `invalid-email`, `user-not-found`, `wrong-password`.

**Acceptance:** Manual test: register a new email, force-quit, sign in again — Firebase user persists.

---

### Phase C — Onboarding redesign

#### New flow

```
Launch → SplashScreen (decide based on persisted state)
   │
   ├─ already-onboarded & signed-in  → /news
   ├─ already-onboarded & guest      → /news
   └─ not onboarded                  → /onboarding/welcome

WelcomeScreen
   ├─ "Sign in"        → /onboarding/login
   ├─ "Create account" → /onboarding/register   (email path)
   ├─ "Continue with Google" → google sign-in   (inline)
   └─ "Continue as guest"    → /onboarding/persona

LoginScreen        (email + password, link to forgot/register)
   on success: pull cloud profile → if has persona/topics → /news
                                  → else continue at /onboarding/persona

RegisterScreen     (name + email + password + confirm)
   on success: createInitialProfile → /onboarding/persona

PersonaScreen → KnowledgeLevelScreen → TopicPickerScreen → DailyGoalScreen
   on Continue (last screen): completeOnboarding → /news
```

Key change: **Auth happens *before* preference screens, not after.** Returning users (sign-in path) skip preferences entirely if they exist in Firestore.

#### Step C1: Update routes
**File:** `lib/core/router/app_router.dart`

Replace:
```dart
static const onboardingAuth = '/onboarding/auth';
```
with:
```dart
static const onboardingWelcome   = '/onboarding/welcome';
static const onboardingLogin     = '/onboarding/login';
static const onboardingRegister  = '/onboarding/register';
// keep persona/level/topics/goal as-is
```

Update `SplashScreen` to redirect to `onboardingWelcome` instead of `onboardingPersona` when `!onboarded`. Update redirect logic so authenticated users with completed onboarding land on `/news`.

#### Step C2: WelcomeScreen
**New file:** `lib/features/onboarding/screens/welcome_screen.dart`

Marketing-y header with the 🤖 mark + "Learn AI in seconds." Three primary buttons:
1. **Create account** (filled primary) → `/onboarding/register`
2. **Sign in** (outlined) → `/onboarding/login`
3. **Continue with Google** → inline Google sign-in, then route based on cloud profile presence
4. Tertiary text button: **Skip — try without account** → `/onboarding/persona`

Reuse `_AuthButton` style from existing `auth_screen.dart` (extract to a shared widget under `lib/features/onboarding/widgets/auth_button.dart`).

#### Step C3: LoginScreen
**New file:** `lib/features/onboarding/screens/login_screen.dart`

Form fields:
- Email (TextFormField, email keyboard, validator: regex)
- Password (TextFormField, obscured, min length 6)
- Submit button (disabled until form valid + not loading)
- "Forgot password?" link (disabled / "Coming soon" snackbar — defer)
- Bottom row: "No account? Create one" → `/onboarding/register`

On submit:
1. Call `AuthService.signInWithEmailPassword`.
2. Call `userProvider.notifier.pullFromCloudAndMerge(...)`.
3. Inspect resulting profile:
   - If `selectedTopics.isNotEmpty && persona != null && dailyGoal > 0` → `prefs.saveOnboardingComplete(true)` → `context.go('/news')`.
   - Otherwise → `context.go('/onboarding/persona')` (cloud profile incomplete; finish onboarding).

Error handling: show snackbar with `AuthFailed.message`. Loading state disables form.

#### Step C4: RegisterScreen
**New file:** `lib/features/onboarding/screens/register_screen.dart`

Form fields:
- Name (TextFormField, min 2 chars)
- Email
- Password
- Confirm password (must match)
- Submit button

On submit:
1. `AuthService.registerWithEmailPassword(...)`.
2. `userProvider.notifier.signInWithFirebaseUser(...)` (existing helper — flips isGuest, stamps fields).
3. `firestoreService.createInitialProfile(state)` — creates the doc.
4. `context.go('/onboarding/persona')` — new account always walks the preference flow.

Bottom: "Already have an account? Sign in" → `/onboarding/login`.

#### Step C5: Update `DailyGoalScreen` "Continue" handler
**File:** `lib/features/onboarding/screens/daily_goal_screen.dart`

Currently: `onPressed: () => context.go(AppRoutes.onboardingAuth)` (sends user to auth at the end).

New behavior: Daily Goal is now the **last** preference screen, so completing it should call `OnboardingNotifier.completeOnboarding(stayGuest: state.firebaseUid == null)` and route to `/news`.

```dart
onPressed: () async {
  final user = ref.read(userProvider);
  await ref.read(onboardingProvider.notifier)
      .completeOnboarding(stayGuest: user.isGuest);
  if (context.mounted) context.go(AppRoutes.news);
}
```

`OnboardingNotifier.completeOnboarding` already exists and writes through `setOnboardingData` → `_flushSave()` → triggers `_scheduleCloudSave()`. 

#### Step C6: Delete (or repurpose) `auth_screen.dart`
- Move the Google button widget into the new `WelcomeScreen`.
- Remove the route `/onboarding/auth`.
- Keep `_AuthButton` as a shared widget under `lib/features/onboarding/widgets/auth_button.dart` to avoid duplication.

#### Step C7: Make persona/level/topics screens auth-aware
No code change needed for the screens themselves — they read/write `OnboardingNotifier` state. But the **back button** behavior should send users to `/onboarding/welcome`, not pop into auth (since auth is upstream now).

Verify go_router back stack is correct: from `WelcomeScreen → Persona → Level → Topics → Goal` the system back button should walk back through these naturally with `context.go`. If users get stuck, switch to `context.push` for these so back works without re-implementation. **Simplest:** keep `go` and accept that hardware back from Goal exits the app. Users won't typically backtrack through onboarding.

---

### Phase D — Sign-out & data hygiene

#### Step D1: Update `signOutKeepProgress`
**File:** `lib/data/providers/user_provider.dart`

Currently the sign-out clears identity fields but keeps progress. Behavior is correct; no change needed.

But add: after sign-out, `_cloudSaveTimer` should be cancelled (no more cloud writes for this guest). Already handled by the `state.firebaseUid == null` guard in `_scheduleCloudSave`.

#### Step D2: `reset()` (hard erase)
Already calls `PreferencesService.clearAll()` and creates a fresh guest. No Firestore deletion — user can sign back in and pull cloud data. Document this clearly in the danger-zone copy: "Erase all data on this device. Cloud data is unaffected — sign in to restore."

Optional: add a separate "Delete account" tile that calls `firestoreService.deleteProfile(uid)` + `currentFirebaseUser.delete()`. **Defer to follow-up.**

---

### Phase E — Firestore deploy

#### Step E1: Initialize Firestore in the Firebase console
Manual step (one-time):
1. Open Firebase console → Firestore Database → Create database (production mode, region: closest to user base, e.g., `asia-south1`).
2. Paste the security rules from §4 above into the Rules tab.
3. Document this in `README.md` under "Backend setup."

#### Step E2: Local emulator (optional, recommended for dev)
Add `firebase.json`:
```json
{
  "firestore": { "rules": "firestore.rules" },
  "emulators": {
    "firestore": { "port": 8080 },
    "auth":      { "port": 9099 },
    "ui":        { "enabled": true, "port": 4000 }
  }
}
```
In debug builds, point Firestore + Auth to emulator: in `main.dart` after `Firebase.initializeApp`:
```dart
if (kDebugMode && const bool.fromEnvironment('USE_FIREBASE_EMULATOR')) {
  FirebaseFirestore.instance.useFirestoreEmulator('10.0.2.2', 8080); // 10.0.2.2 = host loopback for Android emulator
  await FirebaseAuth.instance.useAuthEmulator('10.0.2.2', 9099);
}
```
Run with `--dart-define=USE_FIREBASE_EMULATOR=true`.

---

## 6. Key Files

| File | Operation | Description |
|---|---|---|
| `pubspec.yaml` | Edit | Add `cloud_firestore: ^5.4.4`. |
| `lib/data/models/user_model.dart` | Edit | Add `schemaVersion`, `toFirestoreMap`, `fromFirestore`. |
| `lib/data/remote/firestore_service.dart` | **New** | Read/write profile, merge helper. |
| `lib/data/providers/firestore_provider.dart` | **New** | `firestoreServiceProvider`. (Or co-locate inside the service file.) |
| `lib/data/providers/user_provider.dart` | Edit | Add `_scheduleCloudSave`, `pullFromCloudAndMerge`, hook into `_scheduleSave`. |
| `lib/data/remote/auth_service.dart` | Edit | Add `registerWithEmailPassword`, `signInWithEmailPassword`, expanded error mapping. |
| `lib/core/router/app_router.dart` | Edit | New routes: welcome, login, register. Remove `/onboarding/auth`. Update splash redirect. |
| `lib/features/onboarding/screens/welcome_screen.dart` | **New** | Entry hub: sign-in / register / google / guest. |
| `lib/features/onboarding/screens/login_screen.dart` | **New** | Email+password sign-in. |
| `lib/features/onboarding/screens/register_screen.dart` | **New** | Account creation. |
| `lib/features/onboarding/widgets/auth_button.dart` | **New** | Shared button widget extracted from old `auth_screen.dart`. |
| `lib/features/onboarding/screens/daily_goal_screen.dart` | Edit | Last step now completes onboarding instead of routing to auth. |
| `lib/features/onboarding/screens/auth_screen.dart` | Delete | Replaced by welcome/login/register. |
| `lib/features/onboarding/screens/splash_screen.dart` | Edit | Redirect to `/onboarding/welcome` instead of `/onboarding/persona`. |
| `firestore.rules` | **New** | Security rules. |
| `firebase.json` | **New** (optional) | Emulator config. |
| `README.md` | Edit | "Backend setup" section: enable Firestore, deploy rules. |

---

## 7. Risks & Mitigation

| Risk | Mitigation |
|---|---|
| **Firestore write costs explode** if every card-read writes the doc. | Debounce cloud writes to 1 s after last local mutation; exclude daily-rollover fields from cloud schema. |
| **Conflict on guest→signed-in upgrade** (e.g. cloud has streak 10, local guest has streak 12). | Field-by-field merge with sensible policies (max for streaks/XP/totals, union for sets). Pure function; well-tested. |
| **User registers with email already in use.** | Surface friendly error (`email-already-in-use` → "That email is already registered. Try signing in."). |
| **Offline sign-in attempt.** | Firebase Auth surfaces `network-request-failed`; show "No internet" snackbar; do not navigate. Don't clear the form. |
| **Cloud Firestore SDK version drift** vs. firebase_core 3.6. | Pin `cloud_firestore: ^5.4.4` (same family); run `flutter pub deps -- --no-dev` after upgrade. If conflict, bump firebase_core to latest 3.x. |
| **Security rule misconfiguration** could expose all user docs. | Default-deny rule at the bottom; integration test reads/writes against another user's uid and confirms denial. |
| **Existing users with `onboarding_complete=true` hit the new welcome screen** on update. | Splash already gates on `isOnboardingCompleteSync()`. They land on `/news`; their profile syncs to Firestore on the next mutation if signed in, or stays local if guest. No data loss. |
| **Email/password account is "weak"** (just an email and a password). | Document in security follow-up that we should add: email verification gate, optional MFA, password-reset link. Not a v1 blocker. |
| **Firestore rules blocking offline writes.** | Firebase SDK queues offline mutations and replays when online; rules are evaluated on the server, so the local cache is always writable. No mitigation needed. |

---

## 8. Testing Strategy

### Unit
- `UserProfile.toFirestoreMap` ↔ `fromFirestore` round-trip (excluding daily-rollover fields).
- `_mergeForUpgrade(local, cloud)` for: empty cloud + populated local; populated cloud + empty local guest; both populated (verify max-of-streak, union-of-bookmarks, max-nextReview per SRS card).
- `AuthService` error mapping: feed `FirebaseAuthException(code: 'email-already-in-use')` → assert `_friendlyMessage` returns the friendly string.

### Widget
- `LoginScreen`: invalid email shows validator error; submit disabled while loading; error snackbar on `AuthFailed`.
- `RegisterScreen`: password mismatch blocks submit; successful submit navigates to persona.
- `WelcomeScreen`: each button routes correctly.

### Integration (manual)
1. Fresh install → Welcome → Register → Persona/Level/Topics/Goal → /news. Verify Firestore doc exists with `users/{uid}`.
2. Force-quit, reinstall → Welcome → Sign in (same email) → /news directly (skips preference screens). All XP, bookmarks, streak restored.
3. Fresh install → Continue as guest → complete preferences → earn 50 XP → bookmark 3 cards → Welcome (via sign-out reset path)… actually test by: install → guest path → 50 XP → "Sign up" CTA (we'll wire from profile screen in a follow-up; for v1 just sign out + register fresh) → expect: cloud profile creates with the local 50 XP & 3 bookmarks merged in.
4. Sign in on device A → earn XP → sign in on device B → XP visible after pull (eventual; live listener is v2).

### Security rules (firebase emulator)
- User `alice` cannot read/write `users/bob`.
- Unauthenticated request denied.

---

## 9. Rollout Plan

1. **Phase A** ships first behind feature flag (`--dart-define=ENABLE_FIRESTORE=true`). Sync runs but UI is unchanged. Watch Firestore write counts in console.
2. **Phase B + C** (auth + onboarding) ships together as one release. Old `auth_screen.dart` deleted; new welcome flow live.
3. **Phase D** (sign-out hygiene) — verify in QA.
4. **Phase E** — ensure Firestore is enabled in production project + rules deployed BEFORE binary release.

---

## 10. Out-of-Scope Follow-ups

- Real-time multi-device sync via `snapshots()` listener.
- Password reset / email verification flow.
- Apple sign-in (already stubbed).
- Anonymous → permanent account via `linkWithCredential` (cleaner than app-side merge).
- "Delete account" entry point (Firestore doc + Firebase Auth user deletion).
- Cloud-stored daily quests for cross-device daily-goal continuity.
- Cloud Functions: nightly streak-repair / leaderboard aggregation.

---

## SESSION_ID (for /ccg:execute use)
- CODEX_SESSION: (skipped — wrapper not installed)
- GEMINI_SESSION: (skipped — wrapper not installed)
