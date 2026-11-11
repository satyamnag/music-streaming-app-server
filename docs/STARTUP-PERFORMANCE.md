# Android startup performance

Measured on a real device (`RMX2027`, Android 11), cold start, `am start -W`,
force-stopped between runs.

| Build | Run | TotalTime |
|---|---|---|
| before `28ad4b94` | cold | 5750 ms |
| `28ad4b94` | cold #1 | 4756 ms |
| `28ad4b94` | cold #2 (warm engine) | 1464 ms |

Startup timeline before the fix showed three gaps with no Dart logging:
543 ms, 1236 ms and 930 ms, then `Displayed +5s750ms`.

## Cause

Two awaited calls ran BEFORE `runApp()`:

- OneSignal initialize, bounded at 10 s;
- Google Play Install Referrer read, bounded at 5 s (its own comment named it as
  the splash-screen stall).

## Fix (shipped, `28ad4b94`)

Both now run inside `unawaited(() async { ... }())`. Nothing else moved:
OneSignal listeners are still attached only after a successful initialize, and
every failure path is unchanged.

## Rejected: making `Clerk.initialize` lazy

`SoulfulBhaktiApp.onCreate()` initialises Clerk eagerly. Making it lazy looks
like a 1-1.5 s win but is unsafe in this codebase:

- `ensureClerkInitialized` is called from exactly ONE place (`ClerkBridge.kt:178`);
- the bridge exposes at least five other entry points (`getState`, `getToken`,
  sign-in paths) that assume it already ran.

Removing the eager init would silently break session restore and the
entitlement rail - presenting as `"the app forgot my account`", not as an error.
**Do not do it** without first making every bridge method initialise defensively.

## Next safe step

A Baseline Profile (`baseline-prof.txt` + `androidx.profileinstaller`) is
additive, changes no behaviour, and is verifiable with the same measurement.
Hand-written profiles are fragile; generate one with a macrobenchmark rather
than authoring it by guesswork.