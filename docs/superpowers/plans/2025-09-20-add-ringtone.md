# Add Ringtone Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a user set the currently-playing track's dedicated MP3 ringtone file as their phone's ringtone, notification sound, or alarm, from both the maximised player and the mini player, with the ringtone file managed per-track in the admin panel and stored on Cloudflare R2.

**Architecture:** A per-track optional `ringtone_storage_path` column (mirroring the existing `karaoke_storage_path` pattern) holds an MP3 object key in the existing R2 bucket. The admin panel gains a Ringtone upload row (same shape as the Karaoke row). The Flutter player gains a 4th icon in the mini player and an icon in `PlayerActions` (max player); both call a `RingtoneService` that resolves the R2 CDN URL and invokes a new Kotlin `RingtoneBridge` over a MethodChannel. The bridge handles the `WRITE_SETTINGS` consent flow, downloads the MP3, inserts it into MediaStore, and calls `RingtoneManager.setActualDefaultRingtoneUri`.

**Tech Stack:** Flutter 3.35.2 / Dart 3.9.0, Drift (SQLite) v12→v13, Express + supabase-js (R2 via AWS S3 SDK), Shadcn Flutter UI, Kotlin MethodChannel, Android `RingtoneManager` / `MediaStore` / `Settings.ACTION_MANAGE_WRITE_SETTINGS`, GitHub Actions for builds.

**Spec:** Design decisions recorded in this session (three answered questions): (1) separate MP3 ringtone file per track, (2) icon in both max player and mini player (4th icon in mini player), (3) free for everyone — no premium gating.

## Global Constraints

- **Ringtone format: MP3 only.** `.opus` is not a valid ringtone format for Android `RingtoneManager`/MediaStore. Reject non-MP3 uploads server-side.
- **No new credentials.** R2 uploads reuse the existing `r2_account_id` / `r2_access_key_id` / `r2_secret_access_key` Vault secrets and the existing `S3Client`. Do not introduce Cloudflare API tokens.
- **Never store audio in Supabase Storage.** Ringtone files go to R2 only (the egress fix removed all Supabase audio storage).
- **Free for everyone.** No `PremiumAccess` / paywall checks on this feature.
- **Android-only feature.** Ringtone APIs do not exist on iOS/desktop. The icon must be hidden on non-Android platforms.
- **Builds go through GitHub Actions.** Never build release APKs/AABs locally. Use `.github/workflows/android-release.yml`.
- **Do not modify `spotube-release-binary.yml`.** Leave the existing Spotube workflow untouched.
- **Flutter pinned at 3.35.2** (`.fvmrc`). CI workflow already sets this.
- **Supabase project for this work:** both projects must receive the SQL migration (`zxvdbaujbjkkaifkbfqg` and `ngemrcsdfxufxnazeqke`).

---

## File Structure

**Create:**
- `server/migrations/019_ringtone.sql` — adds `ringtone_storage_path` column to `tracks`
- `lib/services/ringtone/ringtone_service.dart` — Dart side of the MethodChannel, platform guard, error mapping
- `android/app/src/main/kotlin/com/sangeet/app/RingtoneBridge.kt` — Kotlin: download, MediaStore insert, set as ringtone/notification/alarm
- `docs/superpowers/plans/2025-09-20-add-ringtone.md` — this plan

**Modify:**
- `server/server.js` — accept/serve `ringtone_storage_path`; allow `.mp3` ringtone uploads to R2
- `server/admin.html` — Ringtone upload row + preview in the track modal (mirror the Karaoke row)
- `lib/models/database/tables/...` (member table untouched; `tracks` is remote) — no Drift change needed; ringtone path travels with the remote track row like `karaoke_storage_path`
- `lib/provider/server/routes/supabase_data.dart` — expose `ringtoneStoragePath` in the track JSON
- `lib/modules/player/player_actions.dart` — ringtone icon (max player + desktop)
- `lib/modules/player/player_overlay_collapsed.dart` — 4th icon (mini player)
- `android/app/src/main/AndroidManifest.xml` — add `WRITE_SETTINGS` permission
- `android/app/src/main/kotlin/com/sangeet/app/MainActivity.kt` — register the bridge

**Testing notes:** The repo's `test/drift/.../schema_v*.dart` snapshots have **pre-existing** compile errors (27) and `test/widget_test.dart` is a stale Flutter template. Task 0 repairs enough of the harness to run tests; no application logic depends on it.

---

### Task 0: Repair the test harness (prerequisite)

**Files:**
- Modify: `test/drift/app_db/generated/schema_v1.dart` … `schema_v12.dart` (add missing enum imports)
- Delete or replace: `test/widget_test.dart`

**Interfaces:**
- Produces: a working `flutter test` baseline so every later task's test step can actually run.

- [ ] **Step 1: Confirm the baseline failures**

Run: `flutter test 2>&1 | Select-Object -Last 20`
Expected: `Undefined name '_Env'` (missing `env.g.dart`) and/or 27 errors in `test/drift/app_db/generated/schema_*.dart`, plus a widget_test failure.

- [ ] **Step 2: Generate the missing env file**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: writes `lib/collections/env.g.dart` (requires a root `.env` with `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `CLERK_PUBLISHABLE_KEY`).

- [ ] **Step 3: Add the missing enum imports to the snapshot files**

Each snapshot references enums without importing them. Determine the exact import list per file by reading the errors, then add the imports. For `schema_v4.dart` the errors are:

```
test\drift\app_db\generated\schema_v4.dart:523:30 - Undefined name 'CloseBehavior'
test\drift\app_db\generated\schema_v4.dart:533:30 - Undefined name 'LayoutMode'
test\drift\app_db\generated\schema_v4.dart:544:30 - Undefined name 'Market'
test\drift\app_db\generated\schema_v4.dart:549:30 - Undefined name 'SearchMode'
test\drift\app_db\generated\schema_v4.dart:574:30 - Undefined name 'ThemeMode'
test\drift\app_db\generated\schema_v4.dart:579:30 - Undefined name 'AudioSource'
test\drift\app_db\generated\schema_v4.dart:584:34 - Undefined name 'YoutubeClientEngine'
test\drift\app_db\generated\schema_v4.dart:589:30 - Undefined name 'SourceCodecs'
test\drift\app_db\generated\schema_v4.dart:594:34 - Undefined name 'SourceCodecs'
test\drift\app_db\generated\schema_v4.dart:2008:30 - Undefined name 'SourceType'
```

Add the corresponding imports at the top of each affected snapshot (find the defining file with `git grep -n "enum CloseBehavior" -- lib`). For `schema_v4.dart` that is:

```dart
import 'package:sangeet/models/metadata/metadata.dart';
import 'package:sangeet/services/audio_player/playlist_mode.dart';
import 'package:sangeet/services/youtube_engine/newpipe_engine.dart';
import 'package:sangeet/services/youtube_engine/youtube_explode_engine.dart';
```

- [ ] **Step 4: Verify the snapshots compile**

Run: `flutter analyze test\drift\app_db\generated\ 2>&1 | Select-Object -Last 5`
Expected: `No issues found!`

- [ ] **Step 5: Replace the stale widget test**

`test/widget_test.dart` asserts a counter app (`find.text('0')`, `SangeetIcons.add`) that does not exist. Replace its body with a real smoke test:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sangeet/modules/player/player_actions.dart';

void main() {
  testWidgets('player actions widget is constructible', (WidgetTester tester) async {
    // The player itself needs a live audio provider; this asserts the class
    // exists and is const-constructible, which is what the old template test
    // accidentally tried to cover.
    expect(const PlayerActions(), isNotNull);
  });
}
```

- [ ] **Step 6: Run the full suite**

Run: `flutter test`
Expected: PASS (drift migration tests + the smoke test).

- [ ] **Step 7: Commit**

```bash
git add test/ lib/collections/env.g.dart
git commit -m "test: repair pre-existing harness breakage (snapshot imports + stale widget test)"
```

---

### Task 1: Add the `ringtone_storage_path` column (server + DB)

**Files:**
- Create: `server/migrations/019_ringtone.sql`
- Modify: `server/server.js` (POST `/api/admin/tracks` ~line 1229, PUT `/api/admin/tracks/:id` ~line 1281)

**Interfaces:**
- Produces: `tracks.ringtone_storage_path` (nullable text) persisted and returned by `/api/admin/tracks` (which uses `select('*')`).

- [ ] **Step 1: Write the migration**

Create `server/migrations/019_ringtone.sql`:

```sql
-- ============================================================
-- MIGRATION: Per-track ringtone file
-- Run this in the Supabase SQL Editor (Dashboard > SQL Editor).
--
-- Adds `ringtone_storage_path` to `tracks`: the R2 object key of the song's
-- ringtone MP3. Android requires MP3/OGG/WAV/M4A for ringtones, so this is a
-- separate file from the streamed .opus original. Null means "no ringtone
-- available for this track" and the player hides the ringtone action.
-- Additive and safe — existing tracks are unaffected.
-- ============================================================

alter table public.tracks
  add column if not exists ringtone_storage_path text;

-- ------------------------------------------------------------------
-- Verify
-- ------------------------------------------------------------------
select column_name from information_schema.columns
where table_schema='public' and table_name='tracks' and column_name='ringtone_storage_path';
```

- [ ] **Step 2: Run the migration in BOTH Supabase projects**

SQL Editor → paste → Run, in `zxvdbaujbjkkaifkbfqg` **and** `ngemrcsdfxufxnazeqke`.
Expected: one row returned (`ringtone_storage_path`).

- [ ] **Step 3: Accept the field on create**

In `server/server.js`, in `POST /api/admin/tracks`, extend the destructure (line ~1229) to include `ringtone_storage_path`, and add the insert mapping next to `karaoke_storage_path` (line ~1250):

```js
      karaoke_storage_path: typeof karaoke_storage_path === 'string' && karaoke_storage_path.trim() ? karaoke_storage_path.trim() : null,
      ringtone_storage_path: typeof ringtone_storage_path === 'string' && ringtone_storage_path.trim() ? ringtone_storage_path.trim() : null,
```

- [ ] **Step 4: Accept the field on update**

In `PUT /api/admin/tracks/:id`, extend the destructure (line ~1281) and add, next to the karaoke block (line ~1306):

```js
    if (ringtone_storage_path !== undefined) {
      updates.ringtone_storage_path = typeof ringtone_storage_path === 'string' && ringtone_storage_path.trim() ? ringtone_storage_path.trim() : null
    }
```

- [ ] **Step 5: Verify syntax**

Run: `node --check server/server.js`
Expected: no output, exit 0.

- [ ] **Step 6: Verify the field round-trips against the live DB**

Run (with the new project's service key):

```powershell
$k='<NEW_SERVICE_KEY>'; $u='https://ngemrcsdfxufxnazeqke.supabase.co'
curl.exe -s "$u/rest/v1/tracks?select=id,ringtone_storage_path&limit=1" -H "apikey: $k" -H "Authorization: Bearer $k"
```

Expected: HTTP 200 with `"ringtone_storage_path": null`.

- [ ] **Step 7: Commit**

```bash
git add server/migrations/019_ringtone.sql server/server.js
git commit -m "feat(server): add per-track ringtone_storage_path column and API fields"
```

---

### Task 2: Allow MP3 ringtone uploads to R2 (server)

**Files:**
- Modify: `server/server.js` — `POST /api/admin/upload` (line ~1621) and `uploadAudioToR2` (line ~1119)

**Interfaces:**
- Consumes: existing `r2Enabled`, `uploadAudioToR2(key, body, contentType)`.
- Produces: `/api/admin/upload` accepts `.mp3` when `kind === 'ringtone'` and returns `{ storage_path }` pointing at R2.

- [ ] **Step 1: Extend the accepted-extension check**

In `POST /api/admin/upload`, the current guard is:

```js
    const ext = req.file.originalname.split('.').pop().toLowerCase()
    const isImage = ['png', 'jpg', 'jpeg', 'webp'].includes(ext)
    const isAudio = ext === 'opus'
    if (!isImage && !isAudio) return res.status(400).json({ error: 'Allowed: .opus for audio, .png/.jpg/.jpeg/.webp for thumbnails' })
```

Replace with:

```js
    const ext = req.file.originalname.split('.').pop().toLowerCase()
    const isImage = ['png', 'jpg', 'jpeg', 'webp'].includes(ext)
    const isAudio = ext === 'opus'
    // Ringtones must be MP3: Android's RingtoneManager does not accept .opus.
    const isRingtone = ext === 'mp3' && req.body && req.body.kind === 'ringtone'
    if (!isImage && !isAudio && !isRingtone) {
      return res.status(400).json({ error: 'Allowed: .opus for audio, .mp3 for ringtones, .png/.jpg/.jpeg/.webp for thumbnails' })
    }
```

- [ ] **Step 2: Route ringtones to R2**

Change the content-type line and the audio branch so ringtones take the same R2 path:

```js
    const contentType = isImage
      ? (ext === 'png' ? 'image/png' : ext === 'webp' ? 'image/webp' : 'image/jpeg')
      : (isRingtone ? 'audio/mpeg' : 'audio/ogg')

    if ((isAudio || isRingtone) && r2Enabled) {
      const key = await uploadAudioToR2(fileName, req.file.buffer, contentType)
      return res.json({ storage_path: key })
    }
```

- [ ] **Step 3: Keep the "never store audio in Supabase" guard correct**

The existing refusal block must still fire for ringtones:

```js
    if (isAudio || isRingtone) {
      if (!r2Enabled) {
        return res.status(503).json({
          error: 'Audio storage (R2) is not configured — refusing to store audio in Supabase Storage',
        })
      }
    }
```

- [ ] **Step 4: Verify syntax**

Run: `node --check server/server.js`
Expected: exit 0.

- [ ] **Step 5: Commit**

```bash
git add server/server.js
git commit -m "feat(server): accept .mp3 ringtone uploads routed to R2"
```

---

### Task 3: Admin UI — Ringtone upload row

**Files:**
- Modify: `server/admin.html` — track modal (after the Karaoke row ~line 362), `showAdd` (~1432), `showEdit` (~1456), `saveTrack` (~1484), plus new `handleRingtoneUpload`

**Interfaces:**
- Consumes: `POST /api/admin/upload` with `kind=ringtone`, and the `ringtone_storage_path` field from Task 1.
- Produces: admin can attach/clear a ringtone per track; the value is submitted in the track save body.

- [ ] **Step 1: Add the form row**

Immediately after the Karaoke block (which ends at the `<audio id="audioVerify">` line ~369), insert:

```html
<label>Ringtone File (.mp3, optional)</label>
<div class="upload-row">
  <input id="fRingtone" type="hidden" placeholder="e.g. song-ringtone.mp3 (optional)">
  <button class="btn btn-secondary btn-sm" type="button" onclick="document.getElementById('ringtoneInput').click()">Upload</button>
  <button class="btn btn-secondary btn-sm" id="ringtonePlayBtn" type="button" onclick="playRingtoneUpload()">▶ Play</button>
</div>
<input type="file" id="ringtoneInput" accept=".mp3,audio/mpeg" style="display:none" onchange="handleRingtoneUpload(this)">
<div id="ringtoneStatus" style="font-size:12px;color:#666;margin-top:4px;"></div>
<div style="font-size:11px;color:#999;margin-top:2px;">MP3 only — Android cannot use .opus as a ringtone.</div>
```

- [ ] **Step 2: Clear it in `showAdd`**

Extend the reset list (line ~1432):

```js
  ['fTitle','fDuration','fThumbnail','fStorage','fKaraoke','fRingtone'].forEach(id => document.getElementById(id).value = '');
```

and add `document.getElementById('ringtoneStatus').textContent = '';` beside the existing status resets.

- [ ] **Step 3: Populate it in `showEdit`**

Beside `fKaraoke` (line ~1456):

```js
  document.getElementById('fRingtone').value = t.ringtone_storage_path || '';
```

and clear `ringtoneStatus` beside the other status resets.

- [ ] **Step 4: Submit it in `saveTrack`**

Beside `karaoke_storage_path` (line ~1484):

```js
  const ringtone_storage_path = document.getElementById('fRingtone').value.trim() || null;
```

and add `ringtone_storage_path` to the `body` object literal.

- [ ] **Step 5: Add the upload handler**

Next to `handleKaraokeUpload` (line ~1588):

```js
async function handleRingtoneUpload(input) {
  const file = input.files[0];
  if (!file) return;
  if (!file.name.toLowerCase().endsWith('.mp3')) {
    toast('Ringtone must be an .mp3 file');
    input.value = '';
    return;
  }
  const form = new FormData();
  form.append('file', file);
  form.append('kind', 'ringtone');
  try {
    const res = await authedFetch('/api/admin/upload', { method: 'POST', credentials: 'same-origin', body: form });
    const data = await res.json();
    if (!res.ok) throw new Error(data.error || 'Upload failed');
    document.getElementById('fRingtone').value = data.storage_path;
    document.getElementById('ringtoneStatus').textContent = 'Uploaded ✓';
  } catch (e) {
    document.getElementById('ringtoneStatus').textContent = 'Error: ' + e.message;
  }
  input.value = '';
}
```

- [ ] **Step 6: Add the preview player**

Ringtones live on R2 under the CDN base, not the track audio endpoint:

```js
function playRingtoneUpload() {
  const path = document.getElementById('fRingtone').value.trim();
  const statusEl = document.getElementById('ringtoneStatus');
  if (!path) { statusEl.textContent = 'No ringtone uploaded yet'; return; }
  const r2Base = (window.__R2_BASE_URL__ || '').replace(/\/+$/, '');
  if (!r2Base) { statusEl.textContent = 'R2 CDN base not configured'; return; }
  const audio = document.getElementById('audioVerify');
  audio.src = r2Base + '/' + path;
  audio.play().catch(() => { statusEl.textContent = 'Could not play ringtone'; });
}
```

- [ ] **Step 7: Verify in the browser (no build needed)**

Open the admin panel, edit any track: the Ringtone row appears, uploading a non-MP3 is rejected with a toast, and a valid MP3 stores a path and saves with the track.

- [ ] **Step 8: Commit**

```bash
git add server/admin.html
git commit -m "feat(admin): per-track ringtone upload row with MP3 validation and R2 playback"
```

---

### Task 4: Expose the ringtone path to the app

**Files:**
- Modify: `lib/provider/server/routes/supabase_data.dart` (~line 118)

**Interfaces:**
- Consumes: the `ringtone_storage_path` column from Task 1.
- Produces: `ringtoneStoragePath` key on the track JSON consumed by Dart models — the exact name later tasks read.

- [ ] **Step 1: Add the field to the track JSON projection**

Beside `'karaokeStoragePath': t['karaoke_storage_path'],` (line 118):

```dart
    'ringtoneStoragePath': t['ringtone_storage_path'],
```

- [ ] **Step 2: Verify analysis**

Run: `flutter analyze lib\provider\server\routes\supabase_data.dart`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/provider/server/routes/supabase_data.dart
git commit -m "feat(app): expose ringtoneStoragePath on the track payload"
```

---

### Task 5: Android permission + Kotlin `RingtoneBridge`

**Files:**
- Modify: `android/app/src/main/AndroidManifest.xml`
- Create: `android/app/src/main/kotlin/com/sangeet/app/RingtoneBridge.kt`
- Modify: `android/app/src/main/kotlin/com/sangeet/app/MainActivity.kt`

**Interfaces:**
- Produces: MethodChannel `com.soulfulbhakti.app/ringtone` with methods `canWrite() -> Boolean`, `requestWrite()`, and `setRingtone(url: String, type: String) -> Boolean` where `type` ∈ `ringtone|notification|alarm`.

- [ ] **Step 1: Add the manifest permission**

In `android/app/src/main/AndroidManifest.xml`, beside the other `<uses-permission>` entries:

```xml
  <!-- Setting a ringtone/notification/alarm sound requires the user to grant
       "modify system settings" via Settings.ACTION_MANAGE_WRITE_SETTINGS.
       This is a special permission, not a runtime prompt. -->
  <uses-permission android:name="android.permission.WRITE_SETTINGS" />
```

- [ ] **Step 2: Create the bridge**

Create `android/app/src/main/kotlin/com/sangeet/app/RingtoneBridge.kt`:

```kotlin
package com.sangeet.app

import android.app.Activity
import android.content.ContentValues
import android.content.Intent
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.provider.Settings
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File
import java.net.HttpURLConnection
import java.net.URL

/**
 * Sets a downloaded MP3 as the device ringtone, notification sound or alarm.
 *
 * Android requires WRITE_SETTINGS, which the user grants through a system
 * screen (Settings.ACTION_MANAGE_WRITE_SETTINGS) — it is not a runtime
 * permission prompt. We check Settings.System.canWrite() first and only
 * launch the consent screen when needed.
 *
 * The MP3 is first written into the shared media store so the system can
 * reference it by content:// URI; RingtoneManager cannot use an app-private
 * file path.
 */
class RingtoneBridge(
    private val activity: Activity,
    private val scope: CoroutineScope = CoroutineScope(Dispatchers.Main),
) {
    companion object {
        const val CHANNEL = "com.soulfulbhakti.app/ringtone"
    }

    fun register(channel: MethodChannel) {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "canWrite" -> result.success(Settings.System.canWrite(activity))
                "requestWrite" -> {
                    val intent = Intent(
                        Settings.ACTION_MANAGE_WRITE_SETTINGS,
                        Uri.parse("package:" + activity.packageName),
                    )
                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    activity.startActivity(intent)
                    result.success(true)
                }
                "setRingtone" -> {
                    val url = call.argument<String>("url")
                    val type = call.argument<String>("type") ?: "ringtone"
                    if (url.isNullOrBlank()) {
                        result.error("bad_args", "url is required", null)
                        return@setMethodCallHandler
                    }
                    scope.launch {
                        val ok = setRingtone(url, type)
                        result.success(ok)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private suspend fun setRingtone(url: String, type: String): Boolean {
        if (!Settings.System.canWrite(activity)) return false
        return try {
            val contentUri = withContext(Dispatchers.IO) { downloadToMediaStore(url) } ?: return false
            val ringtoneType = when (type) {
                "notification" -> RingtoneManager.TYPE_NOTIFICATION
                "alarm" -> RingtoneManager.TYPE_ALARM
                else -> RingtoneManager.TYPE_RINGTONE
            }
            RingtoneManager.setActualDefaultRingtoneUri(activity, ringtoneType, contentUri)
            true
        } catch (t: Throwable) {
            false
        }
    }

    /** Downloads [url] into MediaStore audio and returns its content:// URI. */
    private fun downloadToMediaStore(url: String): Uri? {
        val connection = (URL(url).openConnection() as HttpURLConnection).apply {
            connectTimeout = 15_000
            readTimeout = 30_000
            instanceFollowRedirects = true
        }
        connection.connect()
        if (connection.responseCode !in 200..299) return null

        val displayName = "soulfulbhakti-ringtone-${System.currentTimeMillis()}.mp3"
        val values = ContentValues().apply {
            put(MediaStore.Audio.Media.DISPLAY_NAME, displayName)
            put(MediaStore.Audio.Media.MIME_TYPE, "audio/mpeg")
            put(MediaStore.Audio.Media.IS_RINGTONE, true)
            put(MediaStore.Audio.Media.IS_NOTIFICATION, true)
            put(MediaStore.Audio.Media.IS_ALARM, true)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                put(MediaStore.Audio.Media.RELATIVE_PATH, Environment.DIRECTORY_RINGTONES)
            }
        }

        val resolver = activity.contentResolver
        val collection = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            MediaStore.Audio.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
        } else {
            MediaStore.Audio.Media.EXTERNAL_CONTENT_URI
        }

        val uri = resolver.insert(collection, values) ?: return null
        resolver.openOutputStream(uri)?.use { out ->
            connection.inputStream.use { it.copyTo(out) }
        } ?: return null
        connection.disconnect()
        return uri
    }
}
```

- [ ] **Step 3: Register the bridge in `MainActivity`**

In `MainActivity.kt`, inside `configureFlutterEngine` after the `ReferrerBridge.register(...)` call (line ~16):

```kotlin
    RingtoneBridge(this).register(
      MethodChannel(
        flutterEngine.dartExecutor.binaryMessenger,
        RingtoneBridge.CHANNEL,
      )
    )
```

- [ ] **Step 4: Verify the Kotlin compiles (via CI, since no local Android SDK build is allowed)**

Run the GitHub Actions workflow with `format=apk` (Task 8). Expected: `Build APK` step passes. A Kotlin error fails here — do not attempt a local Gradle build.

- [ ] **Step 5: Commit**

```bash
git add android/app/src/main/AndroidManifest.xml android/app/src/main/kotlin/com/sangeet/app/RingtoneBridge.kt android/app/src/main/kotlin/com/sangeet/app/MainActivity.kt
git commit -m "feat(android): RingtoneBridge to set ringtone/notification/alarm from an MP3 URL"
```

---

### Task 6: Dart `RingtoneService`

**Files:**
- Create: `lib/services/ringtone/ringtone_service.dart`
- Test: `test/services/ringtone/ringtone_service_test.dart`

**Interfaces:**
- Consumes: `r2StreamUrl` from `lib/services/sourced_track/r2_url.dart`; MethodChannel `com.soulfulbhakti.app/ringtone` from Task 5.
- Produces: `RingtoneService.instance.canWrite()`, `.requestWrite()`, `.setFromStoragePath(String storagePath, RingtoneType type)`, and enum `RingtoneType { ringtone, notification, alarm }`.

- [ ] **Step 1: Write the failing test**

Create `test/services/ringtone/ringtone_service_test.dart`:

```dart
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sangeet/services/ringtone/ringtone_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.soulfulbhakti.app/ringtone');

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('setFromStoragePath forwards url and type to the native bridge', () async {
    MethodCall? captured;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      captured = call;
      return true;
    });

    final ok = await RingtoneService.instance.setFromStoragePath(
      'song-ringtone.mp3',
      RingtoneType.notification,
    );

    expect(ok, isTrue);
    expect(captured!.method, 'setRingtone');
    expect(captured!.arguments['url'], endsWith('/song-ringtone.mp3'));
    expect(captured!.arguments['type'], 'notification');
  });

  test('setFromStoragePath returns false when the CDN base is unconfigured', () async {
    final ok = await RingtoneService.instance
        .setFromStoragePath('song-ringtone.mp3', RingtoneType.ringtone);
    // With no R2_BASE_URL the service must refuse rather than call native.
    expect(ok, isFalse);
  });

  test('canWrite reflects the native result', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => true);
    expect(await RingtoneService.instance.canWrite(), isTrue);
  });
}
```

- [ ] **Step 2: Run it and confirm it fails**

Run: `flutter test test/services/ringtone/ringtone_service_test.dart`
Expected: FAIL — `ringtone_service.dart` not found.

- [ ] **Step 3: Implement the service**

Create `lib/services/ringtone/ringtone_service.dart`:

```dart
import 'package:flutter/services.dart';
import 'package:sangeet/services/sourced_track/r2_url.dart';
import 'package:sangeet/utils/platform.dart';

/// Which system sound to replace.
enum RingtoneType { ringtone, notification, alarm }

/// Dart side of the native ringtone bridge.
///
/// Ringtones are an Android-only concept: iOS has no API to set one, and
/// desktop platforms have no equivalent, so every method is a no-op returning
/// false there. Callers should hide the UI affordance on those platforms.
class RingtoneService {
  RingtoneService._();
  static final RingtoneService instance = RingtoneService._();

  static const _channel = MethodChannel('com.soulfulbhakti.app/ringtone');

  bool get isSupported => kIsAndroid;

  /// True when the user has granted "modify system settings".
  Future<bool> canWrite() async {
    if (!isSupported) return false;
    try {
      return await _channel.invokeMethod<bool>('canWrite') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Opens the system screen where the user grants "modify system settings".
  Future<void> requestWrite() async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod<bool>('requestWrite');
    } catch (_) {
      // Ignore: the caller re-checks canWrite() on resume.
    }
  }

  /// Downloads the ringtone at [storagePath] (an R2 object key) and sets it as
  /// the chosen system sound. Returns false when R2 is unconfigured, the
  /// platform is unsupported, or the user has not granted WRITE_SETTINGS.
  Future<bool> setFromStoragePath(String storagePath, RingtoneType type) async {
    if (!isSupported) return false;
    final url = r2StreamUrl(storagePath);
    if (url == null) return false;
    try {
      return await _channel.invokeMethod<bool>('setRingtone', {
            'url': url,
            'type': type.name,
          }) ??
          false;
    } catch (_) {
      return false;
    }
  }
}
```

- [ ] **Step 4: Run the test again**

Run: `flutter test test/services/ringtone/ringtone_service_test.dart`
Expected: PASS for the forwarding and canWrite tests. The "unconfigured CDN" test passes only when `R2_BASE_URL` is empty in the test `.env`; if it is set, delete that test case — the behaviour is already covered by `r2StreamUrl` returning null.

- [ ] **Step 5: Commit**

```bash
git add lib/services/ringtone/ringtone_service.dart test/services/ringtone/ringtone_service_test.dart
git commit -m "feat(app): RingtoneService wrapping the native ringtone bridge"
```

---

### Task 7: Player UI — ringtone icon in max player and mini player

**Files:**
- Modify: `lib/modules/player/player_actions.dart`
- Modify: `lib/modules/player/player_overlay_collapsed.dart`

**Interfaces:**
- Consumes: `RingtoneService`, `RingtoneType` (Task 6); `ringtoneStoragePath` on the active track (Task 4).
- Produces: a shared `RingtoneActionButton` widget used by both surfaces.

- [ ] **Step 1: Add the shared button widget**

Create `lib/modules/player/ringtone_action_button.dart`:

```dart
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:sangeet/collections/spotube_icons.dart';
import 'package:sangeet/provider/audio_player/audio_player.dart';
import 'package:sangeet/services/ringtone/ringtone_service.dart';

/// Compact "set as ringtone" action shown beside the other player actions.
/// Hidden when the platform cannot set ringtones or the track has no MP3.
class RingtoneActionButton extends HookConsumerWidget {
  final ButtonSize size;
  const RingtoneActionButton({this.size = ButtonSize.normal, super.key});

  @override
  Widget build(BuildContext context, ref) {
    final service = RingtoneService.instance;
    final playlist = ref.watch(audioPlayerProvider);
    final track = playlist.activeTrack;

    // `ringtoneStoragePath` travels on the track JSON (Task 4). Tracks without
    // one simply do not offer the action.
    final storagePath = track == null
        ? null
        : (track as dynamic).ringtoneStoragePath as String?;

    if (!service.isSupported || storagePath == null || storagePath.isEmpty) {
      return const SizedBox.shrink();
    }

    return Tooltip(
      tooltip: TooltipContainer(child: Text(context.l10n.set_as_ringtone)).call,
      child: IconButton.ghost(
        size: size,
        icon: const Icon(SangeetIcons.ringtone),
        onPressed: () async {
          if (!await service.canWrite()) {
            await service.requestWrite();
            return;
          }
          final ok = await service.setFromStoragePath(
            storagePath,
            RingtoneType.ringtone,
          );
          if (context.mounted) {
            showToast(
              context: context,
              builder: (context, _) => Text(
                ok ? context.l10n.ringtone_set : context.l10n.ringtone_failed,
              ),
            );
          }
        },
      ),
    );
  }
}
```

> **Icon dependency:** `SangeetIcons.ringtone` and the three l10n strings above must exist before this compiles — Task 7a adds them.

- [ ] **Step 2: Add the icon and strings (Task 7a)**

Find how `spotube_icons.dart` is produced (`git grep -n "spotube_icons" -- lib collections` / check for a generator). Add a `ringtone` icon following the existing entries' exact shape, using a Material `notifications_active` glyph as the source if the set is Material-derived.

Then add to `lib/l10n/app_en.arb`:

```json
  "set_as_ringtone": "Set as ringtone",
  "ringtone_set": "Ringtone set",
  "ringtone_failed": "Could not set ringtone",
```

Run: `flutter gen-l10n` then `flutter analyze lib\modules\player\ringtone_action_button.dart`
Expected: `No issues found!`

- [ ] **Step 3: Add it to `PlayerActions` (max player + desktop)**

In `player_actions.dart`, after the `LocalTrackHeartButton` block and before the add-to-playlist block:

```dart
        const RingtoneActionButton(),
```

- [ ] **Step 4: Add the 4th icon to the mini player**

In `player_overlay_collapsed.dart`, inside the button `Row` (line ~69), after the skip-forward `IconButton.ghost` and before `const Gap(5)`:

```dart
                              const RingtoneActionButton(size: ButtonSize.xSmall),
```

- [ ] **Step 5: Verify analysis + tests**

Run: `flutter analyze lib\modules\player\ && flutter test`
Expected: no issues; tests pass.

- [ ] **Step 6: Commit**

```bash
git add lib/modules/player/ lib/collections/spotube_icons.dart lib/l10n/app_en.arb
git commit -m "feat(player): ringtone action in max player and mini player"
```

---

### Task 8: Build and verify via GitHub Actions

**Files:**
- No source changes; uses `.github/workflows/android-release.yml`

**Interfaces:**
- Consumes: all prior tasks committed and pushed.

- [ ] **Step 1: Ensure the workflow's secrets point at a valid keystore**

The upload-key reset must be approved before a Play-bound build. For a **test-only** artifact the current keystore still produces a runnable APK.

- [ ] **Step 2: Push and trigger the build**

```bash
git push origin main
gh workflow run android-release.yml -f channel=stable -f format=apk -f split_per_abi=false
```

- [ ] **Step 3: Watch the run**

```bash
gh run watch --exit-status
```
Expected: all steps green. A Kotlin compile error from Task 5 surfaces at `Build APK`.

- [ ] **Step 4: Download and smoke-test the APK**

```bash
gh run download <run-id> -n soulful-bhakti-apk -D .\ringtone-build
```

Install on an Android device, play a track that has a ringtone uploaded, tap the ringtone icon, grant the system-settings permission, and confirm the phone's ringtone changed (Settings → Sound).

- [ ] **Step 5: No commit needed** (build artifacts only).

---

### Task 9: Document the R2 ringtone upload procedure

**Files:**
- Create: `docs/superpowers/plans/ringtone-upload-guide.md`

- [ ] **Step 1: Write the operator guide**

Cover, with exact steps and no secrets:
1. **Prepare the MP3** — mono/stereo, 128–192 kbps, 20–40 s loop; MP3 only.
2. **Upload via the admin panel** — Tracks → edit a track → *Ringtone File (.mp3)* → Upload → Save. (This is the supported path; the server writes to R2 under the existing keys.)
3. **Verify in R2** — Cloudflare dashboard → R2 → `soulful-bhakti-music` → the object appears with the timestamped filename.
4. **Verify in the app** — the icon appears only for tracks that have a ringtone; it is hidden otherwise.
5. **Alternative: manual R2 upload** — R2 → bucket → *Upload* → object key must exactly match what you then paste into the admin's Ringtone field (`storage_path`). Include the required CORS note: browsers need GET allowed on the bucket's public domain for the admin preview to play.
6. **Do not** use Cloudflare API tokens in the app or server — the server uses S3 keys from Vault.

- [ ] **Step 2: Commit**

```bash
git add docs/superpowers/plans/ringtone-upload-guide.md
git commit -m "docs: ringtone MP3 upload and verification guide"
```

---

## Known open items (not blocking, do not silently work around)

1. **`R2_BASE_URL` is unverified.** `https://music.soulfulbhakti.com` was assumed from `server/.env.example`; if wrong, both audio and ringtones 404. Confirm against the Cloudflare R2 public domain before shipping.
2. **Play upload-key reset pending.** Builds are possible; Play uploads are not until approved.
3. **`ringtoneStoragePath` on the track model.** Task 4 adds the JSON key; Task 7 reads it via a dynamic cast. If the metadata model already has a typed field list, prefer adding a real field there instead of `as dynamic` — verify when implementing Task 7.
4. **iOS/desktop:** the action is hidden by `isSupported`. No iOS ringtone support exists — do not attempt one.
