# Plan: Root-cause "NEWS fetch failed: HTTP 404" + remediation

**Date:** 2026-04-26
**Symptom:** Banner reads `Showing cached stories — NEWS fetch failed: HTTP 404`. App Check is healthy (no more `App attestation failed`), JWT-exchange now succeeds, but `/api/news` itself returns 404.

---

## 1. End-to-end trace (what we know)

### Flutter side — request URL composition

`lib/data/remote/news_service.dart:96`:
```dart
_dio.get<dynamic>(
  '$_baseUrl/api/news',
  queryParameters: {'limit': _defaultLimit},
  options: _reqOptions(),
);
```
where `_baseUrl = String.fromEnvironment('ADMIN_API_URL')` (line 38).

So the request URL is literally:
```
<ADMIN_API_URL>/api/news?limit=30
```

`_reqOptions()` (line 189) sets `validateStatus: (s) => s != null && s < 500`, meaning **404 does NOT throw a `DioException`** — it returns the response, the code reaches line 109 (`statusCode != 200`) and writes `_lastError = 'News fetch failed: HTTP 404'`. That string is what's painted on the banner.

### Admin side — route exists

`apps/admin/app/api/news/route.ts:20`:
```ts
export async function GET(req: Request) { ... }
```
Returns 200 + JSON envelope `{ success, data, meta }`. No `dynamic` lockdown, no auth (auth is at the middleware layer).

`apps/admin/middleware.ts:29` has `/api/news` in `CLIENT_SCOPED_PREFIXES`, requiring `Authorization: Bearer <client-jwt>`. On bad/missing JWT it returns **401 JSON**, *not* 404.

`apps/admin/next.config.mjs` — no `trailingSlash`, no `redirects`, no `rewrites`, no `basePath`. Middleware `matcher: ["/((?!_next/static|_next/image|favicon.ico).*)"]`.

### Earlier evidence in this thread

- `TelemetryService: admin rejected batch (HTTP 308)` — telemetry hits `/api/events/ingest` (also a `CLIENT_SCOPED_PREFIX`) and gets 308 PermanentRedirect.
- News path `/api/news` now returns 404.

**308 + 404 from a Next.js deployment that has no `redirects`/`trailingSlash`/`basePath` set ⇒ the requests are not reaching the Next route handlers at all.** The redirect/404 are coming from a layer in front of Next: a hosting-edge rewrite, the wrong host, or a path-prefix mismatch.

---

## 2. Root-cause hypotheses, ranked

### H1 (highest likelihood) — `ADMIN_API_URL` points at the wrong host

The Flutter run is being launched with something like:
```
flutter run --dart-define=ADMIN_API_URL=https://aiscroll.app
```
If `aiscroll.app` is the marketing domain (or a stale preview / a domain alias) and the actual admin API lives at `https://aiscroll-admin.vercel.app` (or `https://admin.aiscroll.app`), then:
- Marketing site doesn't have `/api/events/ingest` → 308 chain or 404
- Marketing site doesn't have `/api/news` → 404

This is the canonical root-cause. **Verifiable in 30 seconds** (see §3).

### H2 — trailing slash in `ADMIN_API_URL`

```
flutter run --dart-define=ADMIN_API_URL=https://aiscroll-admin.vercel.app/
```
Flutter then concatenates → `https://aiscroll-admin.vercel.app//api/news`. Vercel collapses the double slash to `/api/news` for some routes (returns 200) but for others returns a 308 that points to a path that 404s, depending on the platform's normalisation. This is environment-dependent and inconsistent — exactly matches the 308/404 split.

### H3 — `ADMIN_API_URL` points to an old deployment that pre-dates the news route

If the user's `ADMIN_API_URL` is a fixed Vercel preview URL from before `app/api/news/route.ts` existed, that deployment will 404 on the path even though source has it.

### H4 — Vercel domain forwarding

If the user has registered `aiscroll.app` → forwards to `aiscroll-admin.vercel.app/admin` (with the `/admin` *prefix* baked into the forward), then `https://aiscroll.app/api/news` becomes `https://aiscroll-admin.vercel.app/admin/api/news` which doesn't exist → 404.

### H5 — App not actually building with the new `ADMIN_API_URL` value

`String.fromEnvironment` is **compile-time**. If the user changed the URL but ran `flutter run` from an IDE that re-uses a cached build, the binary still embeds the old value. The 404 may come from a host that doesn't exist in DNS / returns its 404 page. A clean `flutter clean && flutter run --dart-define=...` is required after every URL change.

---

## 3. Diagnostic plan (run these in order, stop at first hit)

### D1 — Reveal the actual URL the binary is hitting

Add one debug `print` to `news_service.dart` (NOT shipping — only for diagnosis). Insert at line 93 right after `if (!isAdminConfigured) return false;`:

```dart
debugPrint('DIAG news fetch URL = ' + _baseUrl + '/api/news?limit=' + _defaultLimit.toString());
```

Hot-restart the app, scroll to News, watch logcat. The printed URL is **the** ground truth — no more guessing. Compare it to what you see when you `curl` the admin in D2.

### D2 — Curl the admin directly from your dev box

From the same network the device uses (or just from your laptop), with **the exact value of `ADMIN_API_URL`**:

```bash
# Replace with the URL from D1
curl -i "<URL_FROM_D1>"
```

Three possible signals:
- **`HTTP/2 401 unauthorized`** → middleware reached the route handler. Server is healthy. The 404 you saw earlier means the path is *now* different — re-check D1.
- **`HTTP/2 308 ...`** + `location: <other URL>` header → host-level redirect in front of Next. Note the `location` value — that's where requests actually go, and probably where /api/news doesn't exist.
- **`HTTP/2 404`** → path is genuinely unmapped on that host. Either wrong host (H1) or stale deployment (H3).

### D3 — Verify which deployment owns that host

```bash
curl -i -X POST "<ADMIN_BASE>/api/client/token" \
  -H "Content-Type: application/json" \
  -d '{"appCheckToken":"x","guestId":"diag"}'
```
If this returns 200/400 (real route), the deployment has the API. If 404, the host is wrong.

### D4 — Sanity-check the actual deployment from Vercel

Open Vercel dashboard → project `aiscroll-admin` → **Deployments** tab. The **production** alias domain is the one to use. If it's `https://aiscroll-admin.vercel.app`:
```
flutter clean
flutter run --dart-define=ADMIN_API_URL=https://aiscroll-admin.vercel.app
```
Note: **no trailing slash**.

### D5 — If running against a local dev admin

The admin runs on `http://localhost:3000` by default. From an Android **emulator** that's `http://10.0.2.2:3000`. From a **real device** (your moto g13) on the same Wi-Fi, you must use the host machine's LAN IP, e.g. `http://192.168.1.42:3000`, AND start admin with `next dev -H 0.0.0.0` so it listens on the LAN, not just loopback.

```bash
# In the admin repo
pnpm --filter @aiscroll/admin dev -- -H 0.0.0.0 -p 3000
# Get your laptop's LAN IP
ipconfig | findstr IPv4
# In Flutter
flutter clean
flutter run --dart-define=ADMIN_API_URL=http://192.168.1.42:3000
```
Note Android **debug** builds tolerate `http://` LAN URLs because `usesCleartextTraffic` defaults to true in debug. Release builds will block plain http — you must use https in production.

---

## 4. Solution matrix

| Diagnostic outcome | Fix |
|---|---|
| D1 reveals `https://aiscroll.app/api/news` (apex, not admin) | Re-launch with `ADMIN_API_URL=https://aiscroll-admin.vercel.app` (or whatever the production alias is in Vercel). |
| D1 reveals trailing slash → `…//api/news` | Re-launch with the trailing slash stripped. Optional belt-and-suspenders: in `news_service.dart:38` change `static const _baseUrl = …` to a getter that calls `_baseUrl.replaceAll(RegExp(r'/+\$'), '')`. |
| D2 returns 308 → another host | The `location` header tells you where to point. Use that as `ADMIN_API_URL`. |
| D2 returns 404 from production alias | Run `pnpm --filter @aiscroll/admin build` locally to confirm the route exists in build output, then `vercel --prod` (or `git push` triggering a deploy) to refresh production. |
| D5 (local dev) — admin on localhost, real device | Use LAN IP + `next dev -H 0.0.0.0`. Confirm Windows Firewall allows inbound 3000 on the active profile. |

**One-line code hardening (recommended regardless):** strip trailing slash from `_baseUrl` so any `dart-define` that happens to include one is silently corrected.

`lib/data/remote/news_service.dart:38–39`, `lib/data/remote/content_service.dart:32` (same field), `lib/data/remote/auth_service.dart:66`, `lib/data/remote/telemetry_service.dart:37` — same fix in all four:

```dart
// Before
static const _baseUrl = String.fromEnvironment('ADMIN_API_URL');

// After: keep raw const, use trimmed accessor
static const _rawBaseUrl = String.fromEnvironment('ADMIN_API_URL');
static String get _baseUrl {
  if (_rawBaseUrl.isEmpty) return '';
  return _rawBaseUrl.endsWith('/')
      ? _rawBaseUrl.substring(0, _rawBaseUrl.length - 1)
      : _rawBaseUrl;
}
```
…then `_dio.get('$_baseUrl/api/news', …)` is safe regardless of how the env is supplied. (Note: `static const` can't reference a non-const getter, so accept that one indirection.)

**Better client error messages**: surface the *URL* in the error string so the user banner makes the misconfig obvious next time. In `news_service.dart:110`:

```dart
_lastError = 'News fetch failed: HTTP ${articlesResp.statusCode} '
    'from ${articlesResp.requestOptions.uri}';
```

---

## 5. Implementation steps (after diagnosis confirms which fix)

### Step 1: Run D1 (one-line print) and capture the printed URL
Hot-restart, scroll to News, copy the URL from logcat.

### Step 2: Run D2 with that URL
Capture status code + `location` header (if 3xx).

### Step 3: Apply the matching fix from §4
Either change the `--dart-define`, redeploy admin, or fix the host config.

### Step 4: Apply the hardening edits from §4
Trim trailing slash + include URL in error banner. These prevent future misconfig from being silent.

### Step 5: Verify
- `flutter clean && flutter run --dart-define=ADMIN_API_URL=<correct>`
- Open News tab → no banner → fresh articles paint.
- Open Profile → telemetry events flush without 308.

---

## 6. Key files

| File | Operation | Description |
|---|---|---|
| `lib/data/remote/news_service.dart:93` | Add temporary `debugPrint` | Reveals the actual URL the binary is hitting (D1). Remove after diagnosis. |
| `lib/data/remote/news_service.dart:38` | Edit | Trim trailing slash from `_baseUrl`. |
| `lib/data/remote/content_service.dart:32` | Edit | Same trailing-slash fix. |
| `lib/data/remote/auth_service.dart:66` | Edit | Same. |
| `lib/data/remote/telemetry_service.dart:37` | Edit | Same. |
| `lib/data/remote/news_service.dart:110` | Edit | Include URI in `_lastError`. |
| (Run config) | External | Update `--dart-define=ADMIN_API_URL=…` to the correct host. |

---

## 7. Risks & mitigation

| Risk | Mitigation |
|---|---|
| Trailing-slash strip accidentally removes a *meaningful* path component (`/admin/`) | We only strip a single trailing `/`, not segments. `https://x/admin` stays unchanged. |
| User can't change `--dart-define` because they invoke `flutter run` via an IDE shortcut | Document the IDE-side change. VS Code: `.vscode/launch.json` `args`. Android Studio: Run Configuration → Additional run args. |
| Vercel preview URLs rotate per deployment | Always use the **production alias** (e.g. `aiscroll-admin.vercel.app`), not the `…-git-main-…` preview. |
| Real device on different Wi-Fi than dev box | Either reverse-tether via `adb reverse tcp:3000 tcp:3000` (then keep `ADMIN_API_URL=http://localhost:3000`), or get on same network. |

---

## 8. The "TL;DR" answer

The 404 means the request is reaching a host that doesn't have `/api/news` mounted. Three things to check **right now**:

1. **What URL** are you launching the build with? Run `flutter run` and check logs. If `--dart-define=ADMIN_API_URL=…` isn't in the command, the var is empty and the service is a no-op (it would just say "ADMIN_API_URL not configured" — the fact that you see a 404 means it *is* set, just to the wrong place).
2. **`curl` that exact URL** from your laptop. If it 404s in curl too, you've confirmed the host/path is wrong — find the right one in the Vercel deployments tab.
3. **No trailing slash.** `https://host` not `https://host/`.

Once those line up, the news tab loads. Add the trailing-slash trim + URL-in-error edits so the next person to hit this sees the URL in the banner instead of a generic "HTTP 404".

---

## SESSION_ID (for /ccg:execute use)
- CODEX_SESSION: (skipped — wrapper not installed)
- GEMINI_SESSION: (skipped — wrapper not installed)
