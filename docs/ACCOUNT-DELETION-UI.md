# "Delete account" as a link — policy check and design

Status: implemented on both surfaces (Android profile, web account page), after
verifying the requirement rather than assuming it.

---

## 1. What Play actually requires

Source: <https://support.google.com/googleplay/android-developer/answer/13327111>
(Understanding Google Play's app account deletion requirements).

| Requirement | Wording | Consequence here |
|---|---|---|
| In-app pathway | *"provide users with an in-app path to delete their app accounts and associated data"* | must exist — it does (`ClerkAuthNotifier.deleteAccount`) |
| How prominent | *"the pathway should be **prominent** (for example, within the account settings or a similar section). We recognize that there are many ways developers can implement this"* | **placement** matters, not the widget type |
| Link allowed? | *"As an alternative, you can choose to provide **a link within your app** that takes users to your app account deletion web resource"* | a link is explicitly sanctioned |
| Web resource | must be functional, *"the pathway to request account deletion should be **prominently featured and easily discoverable** on the page"*, reference the app name | `/account-deletion` does all of this (and offers an email route) |
| Data deletion questions | Data safety form answers required | unchanged by this work |

**Verdict:** turning the control into a link is compliant **provided it stays
findable and usable in the account section**. What would not be compliant is
demoting it to small, muted text in a peripheral place.

## 2. Android — `lib/pages/profile/profile.dart`

Before: a filled destructive card (trash icon, title, subtitle
"Permanently remove your account and data").

After: `_ProfileLink` — a labelled text link in the same **ACCOUNT ACTIONS**
section, immediately under *Sign out*. The properties that keep it compliant:

| Property | Value |
|---|---|
| Placement | same section ("account settings or a similar section") |
| Label | the exact string **"Delete account"** (referenced by name in `/account-deletion` and `/privacy`) |
| Touch target | `minHeight: 48` — a bare `Text` would be ~20dp |
| Affordance | destructive colour + **permanent** underline (no hover on phones) |
| Screen readers | `Semantics(button: true, label: "Delete account. Permanently remove your account and all of its data.")` — the removed subtitle's meaning lives here |
| Confirmation | unchanged `AlertDialog` ("This will permanently delete … cannot be undone.") before the irreversible call |
| Key | `profile_delete_link`, for the regression tests |

`_ProfileRow` lost its now-unused `danger` parameter.

## 3. Web — `app/(site)/account/components/AccountContent.tsx`

The filled red pill next to *Logout* became a text link (same wording, destructive
colour, underline, `py-3` target, focus ring). Google Search has no styling
requirement; the only policy-relevant web surface is the **declared deletion
resource**, and `/account-deletion` is untouched — it still prominently lists the
web, mobile and email routes.

The mojibake label `Deletingâ€¦` was replaced with `Deleting...`.

## 4. Verification

- `test/profile_screen_test.dart` (Android): the link exists, the subtitle is
  **gone**, the hit target measures **≥ 48dp**, and tapping opens
  `Delete account?`. 42 tests pass across the profile, performance, edge-to-edge,
  layout and plan-card suites; `flutter analyze` clean.
- Web: `npx tsc --noEmit` passes.

## 5. Before you ship to Play

- Keep the `/account-deletion` URL in Play Console → **App content → Data
  deletion** pointing at the live page.
- In the Data safety form, the answers about account deletion are unchanged
  (deletion offered in-app: yes; web resource: `/account-deletion`).
- After deploying the web branch, open `/account` signed in and confirm the link
  renders and the flow completes.
