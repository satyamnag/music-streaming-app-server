# Getting the phone visible to ADB (realme C3)

`adb devices` returns nothing on this machine, so on-device verification of the
card border is currently impossible. This documents the exact diagnosis and the
fix, so it does not have to be re-derived.

## The diagnosis (measured, not guessed)

```
> adb devices -l
List of devices attached
                                   <- empty

> flutter devices
Found 2 connected devices:
  Windows (desktop) ...
  Edge (web)        ...             <- no Android target
```

Windows *does* see the phone, but only as a media device:

```
FriendlyName          Status   Class
realme C3             Unknown  WPD
MTP USB Device        Unknown  WPD
ADB Interface         Unknown  USBDevice   (x5)
```

Every `ADB Interface` entry reports:

```
Problem            : CM_PROB_PHANTOM
```

**`CM_PROB_PHANTOM` means these are stale registry records, not live devices.**
They are leftovers from other phones connected previously: the hardware IDs are
`VID_2717` (Xiaomi) and `VID_22D9` (OPPO/realme). Because they are phantoms,
they say nothing about the current connection and cannot be "fixed" — ignore
them.

The realme C3 itself (`VID_22D9`) appears **only** as a WPD/MTP device with
status `Unknown`. It has never presented a working ADB interface to this
machine. That is why nothing shows as `unauthorized` either — the phone is not
even reaching the point where it would ask for authorization.

## The fix, in order

1. **USB mode on the phone.** Pull down the notification shade, tap the USB
   notification, and choose **File transfer / MTP**. A "Charging only" mode
   does not expose the ADB interface at all.

2. **USB debugging on the phone.**
   Settings → About phone → tap **Build number** 7 times to unlock Developer
   options → Settings → System → Developer options → enable **USB debugging**.
   (On realme/ColorOS this lives under Settings → System settings → Developer
   options.)

3. **Reconnect and authorize.** Unplug, replug. A dialog **"Allow USB
   debugging?"** should appear on the phone with an RSA fingerprint. Tick
   *Always allow from this computer* and tap **Allow**.

4. **Check:**
   ```
   adb devices -l
   ```
   Expected, in order of progress:
   - `unauthorized` → the dialog is waiting to be accepted on the phone.
   - `device` → working.

5. **If it still shows nothing, install/repair the USB driver.** On Windows the
   phone may need an explicit driver bind:
   - Install **Google USB Driver** via Android SDK Manager (SDK Tools tab), or
     the realme/OPPO USB driver from the manufacturer.
   - Device Manager → find the realme C3 (likely under *Other devices* with a
     warning icon) → **Update driver** → *Browse my computer* → point at
     `<Android SDK>\extras\google\usb_driver`.
   - After binding, `adb devices` should list it.

6. **If it shows `unauthorized` and no dialog appears:** revoke the stale keys
   on the phone (Developer options → **Revoke USB debugging authorizations**),
   then unplug/replug. On the PC you may also delete
   `%USERPROFILE%\.android\adbkey` and `adbkey.pub`, then restart the adb server
   (`adb kill-server; adb start-server`) to force a fresh key exchange.

## Verifying the card border once the device is up

The change is in `lib/components/track_card/`, and it affects every surface that
renders `HomeAlbumCard` / `HomeTrackCard`:

- the home carousel and its shelves,
- the "see all" grids,
- the search tabs and sections,
- the stats/analytics album and track items.

Confirm on each: the gradient rim follows the card's rounded corners, the rim is
a thin edge and **not** a wash across the cover, the play control still sits
flush in the bottom-right corner, and nothing is clipped at the tile edge in a
three-column grid.

The two things a device check specifically settles, which the headless tests
cannot:

1. **The rim is a rim, not a flood fill.** An intermediate implementation painted
   the gradient across the whole card; the pixel harness could not isolate the
   edge reliably. This is the first thing to look at.
2. **The halo reads well.** `haloOpacity` (0.22) and `haloWidth` (2dp) in
   `card_border.dart` are taste calls that should be judged on a real screen, in
   both light and dark mode. Light mode matters most: there the card and the page
   are both pure white and the border is doing the most work.
