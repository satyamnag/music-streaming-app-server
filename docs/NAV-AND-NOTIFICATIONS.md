# Bottom navigation + OneSignal notifications inbox

Status: navigation done (v106), notifications done (v107).
Later phases (the specials/deity banner screens) are tracked separately.

## 1. Bottom bar: Home / Library / My Bhakti / Profile

`lib/collections/side_bar_tiles.dart` (`getNavbarTileList`) and
`lib/modules/root/spotube_navigation_bar.dart`.

| Tab | Icon | Route |
| --- | --- | --- |
| Home | `SangeetIcons.home` (house) | `/home` |
| Library | `SangeetIcons.library` (books) | the user playlists under `/library` |
| My Bhakti | `SangeetIcons.music` (music note) | `/stats` (listening stats) |
| Profile | `SangeetIcons.user` (person) | `/profile` |

Labels are always visible under the icons (`labelType.all`, position `bottom`,
size `small`); the selected tab is tinted with the brand primary.

**"Home" and "My Bhakti" are literals**, deliberately: there is no `home` l10n
key, and "My Bhakti" is a product name that is not translated. Library and
Profile reuse the existing localised strings.

**Search is no longer a tab.** It moved to the home header (top-right), exactly
as the reference design shows. The `SearchRoute` itself is untouched, so the
desktop sidebar and the search intents still reach it.

### The defect that only the device showed

At the old 50dp bar height the label was laid out but **clipped away** by the bar
itself, so the device still showed four bare icons. The height was also
duplicated in three places: the provider default, the player's slide maths
(`50 * invertedPosition`) and its collapse test (`== 50`). There is now one
`kNavigationBarHeight` (64) constant feeding all three, with a test that fails if
the magic numbers come back.

## 2. Notifications: bell + unseen count + dedicated screen

The OneSignal Flutter SDK (5.5.2) exposes **no notification history and no
unread count**. It reports an arrival/click event, and for an in-app message
**only a message id** (`src/inappmessage.dart`: `OSInAppMessage` carries just
`messageId`). A browsable inbox and an unseen badge therefore have to be built
app-side, which is what this feature does.

- `lib/modules/notifications/app_notification.dart` — the entry model
  (`kind` push|inApp, title, body, deep link, receivedAt, read) with tolerant
  JSON: one corrupt row is dropped instead of losing the inbox.
- `lib/modules/notifications/notifications_store.dart` — SharedPreferences
  storage (`sb_notifications_v1`), newest first, de-duplicated by id, capped at
  100. Exposed through a `ValueNotifier` because the writers in `main.dart` hold
  no `WidgetRef`. A re-delivered push **keeps its read flag** rather than
  becoming unseen again.
- `lib/pages/notifications/notifications.dart` — the screen: back + title,
  unseen count, "mark all read", empty state, relative ages.
- `lib/components/notifications/notification_bell.dart` — the header bell with a
  counted badge (capped at `99+`), right of search.
- `lib/main.dart` — records (a) foreground push arrivals via
  `addForegroundWillDisplayListener`, (b) push opens, which is the only way a
  **background** delivery can reach the inbox, and (c) in-app message displays via
  the `onDidDisplay` lifecycle listener.

### Honest limits (SDK, not the app)

- A push received while the app is **not running** is only recorded once the user
  taps it. The SDK never hands Dart an event for it otherwise.
- An in-app entry cannot show the message's title or body, because the SDK
  exposes only its id. The row is therefore labelled "In-app message".
- The unseen count is per device, since it is nothing but this local list.

## Verification

`flutter-verify` 40848310530 + `android-release` 40848316859 green on
`ed0804d0`; installed on the device as versionCode 107. On-device checks: the
bar shows the four labelled tabs; the header shows search and the bell; tapping
the bell opens the screen with its title, back button and empty state.

Tests: `test/modules/notifications/notifications_store_test.dart` (JSON round
trip, ordering, de-duplication preserving read, unread counting, the 100 cap,
restore from disk) and `test/bottom_nav_and_header_test.dart` (the four labels
and icons in order, no search tab, header search, and the shared bar height).
