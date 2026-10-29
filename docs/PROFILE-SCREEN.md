# Profile screen

The Profile tab (`/profile`, `lib/pages/profile/profile.dart`) is the app's
account surface. It replaced the profile **popup** that used to hang off the home
header's avatar: the home header now carries only the brand mark, Search and the
notification bell, and the account has exactly one entry point — the fourth
bottom-nav tab.

## What is on the screen

Laid out as the reference design:

| block | contents | action |
| --- | --- | --- |
| identity | avatar (96 dp, ringed), display name, email | — |
| `ACCOUNT` | **Settings** — "Manage your app preferences" | opens `/settings` |
| | **Your subscription** card: plan name + `CURRENT PLAN` badge, one line of description or the plan's dates, "Upgrade to Pro" on the free plan | Superwall paywall (`PremiumAccess.promptForPaidPlan`) |
| | **Notifications** — "Stay updated with new bhajans and releases" | switch, see below |
| `ACCOUNT ACTIONS` | **Sign out** | confirmation, then `ClerkAuthNotifier.signOut` |
| | **Delete account** (destructive) — "Permanently remove your account and data" | confirmation, then `ClerkAuthNotifier.deleteAccount` |

Signed out, the identity block shows the generic person icon, "You are not signed
in", "Sign in to access your account" and a **Sign in** button that opens the
Google-only `ClerkAuthView`. The `ACCOUNT ACTIONS` group is hidden (there is no
session to end); Settings, the plan card and the notifications row stay exactly
as the popup had them.

## Two deliberate deviations from the reference

1. **No camera badge and no "Edit profile" pill.** `ClerkBridge.kt` exposes
   `setPublishableKey`, `getState`, `signInWithGoogle`, `signOut` and
   `deleteAccount` — nothing that changes the name, email or Google avatar. A
   button that cannot change anything on a live screen is worse than no button.
   Adding native `Clerk.user.update` support is a separate, testable change.
2. **No back arrow.** The reference shows `‹ Profile`, but Profile here is a
   bottom-nav tab: it is not pushed on a stack, so an arrow would have to invent
   a destination. It follows the Library and My Bhakti tabs instead — a centred
   title, and hardware back returns to Home (`PopScope`), which is what every
   other tab does.

## The notifications switch is honest

The switch reads `OneSignal.Notifications.permission` — the SDK's cached answer,
kept in step with the OS by its own permission observer (the service forwards
both: `hasPushPermission`, `addPermissionObserver`).

* Off → tapping it calls `OneSignalService.requestPermission(fallbackToSettings:
  true)`, the only place the app prompts, and adopts the result.
* On → Android has no API to revoke push permission from inside an app, so the
  row opens this app's system notification settings (`openAppSettings()` from
  `permission_handler`) and re-reads the real state, with a short dialog that
  explains where the switch actually lives. It never pretends to have turned
  something off.

## The bottom-bar tab shows who is signed in

`SangeetNavigationBar` watches `clerkAuthProvider`:

* signed in **and** the profile carries an image URL → the tab's icon is replaced
  by that photo in a 24 dp ringed circle;
* signed out, or signed in without a photo → the tab keeps `SangeetIcons.user`,
  exactly as before.

Only the rendered tab changes. The tile list in `collections/side_bar_tiles.dart`
(four tabs, four labels, four icons) is untouched, so `bottom_nav_and_header_test`
still describes the bar correctly, and the other three tabs never change.

## Tests

`test/profile_screen_test.dart`:

* no `ProfileDialog` exists or is referenced anywhere, and the home header no
  longer reads the account while keeping Search and the bell;
* the bar shows the photo only for a signed-in listener who has one, and falls
  back to `tile.icon`;
* the screen, pumped with a fake auth state: signed out shows the sign-in block
  and no actions group; signed in shows the name, email, both account actions and
  the free-plan card with `CURRENT PLAN` and "Upgrade to Pro";
* signing out asks for confirmation before anything happens.

## Verified on the reported phone

Xiaomi 2302EPCC4I, Android 13, 720x1600 @2x, release APK built by CI from this
commit. Each state was measured from screenshots (pixel probes, because the
distinction that matters is visual), then the session was restored:

| check | measurement |
| --- | --- |
| home header has no account avatar | green share of the header's right slot: **22.6 % before** the change (the photo avatar) -> **0.0 % after** |
| bar shows the photo signed in | Profile-tab cell: green **6.6 %** (the Google "K" photo) |
| profile page, signed in | title text `x[289,396]`, centred like the Library tab; identity block, ACCOUNT group, `YOUR SUBSCRIPTION` card with a full-width maroon "Upgrade to Pro" run `x[66,653]`, notifications switch on |
| ACCOUNT ACTIONS | Sign out row, and the red Delete-account card |
| title was glued to the edge before the fix | `x[3,106]`, centroid **54** -> after centring `x[289,396]`, centroid **342** (identical to Library's "Playlists") |
| sign-out confirmation | page dims (corner brightness 228 -> **46**), destructive pill found at `x[460,636] y[844,910]` |
| signed out | Profile-tab cell green **0.0 %**, saturation 1.7 % (person glyph); page shows a centred maroon "Sign in" button at `y=392`; no ACCOUNT ACTIONS group |
| sign back in | `ClerkBridge: signInWithGoogle success`, Profile-tab green returns to **6.6 %** |

### One backend limitation this pass surfaced

Deleting the account on this build reports
`Self deletion is not enabled for this user` (Clerk's own refusal, logged by
`ClerkBridge`). The screen surfaces it in its error dialog and stays usable; the
popup this replaced would have shown exactly the same message. Enabling
self-deletion is a Clerk dashboard setting, not an app change.

### Evidence

`_v111_home_no_header_avatar.png`, `_v111_profile_signed_in.png`,
`_v111_profile_account_actions.png`, `_v111_profile_signed_out.png`,
`_v111_profile_signout_confirm.png`, `_v111_profile_delete_error.png`,
`_v111_profile_signed_in_again.png` (workspace root).

