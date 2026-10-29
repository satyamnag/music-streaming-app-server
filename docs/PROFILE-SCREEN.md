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
