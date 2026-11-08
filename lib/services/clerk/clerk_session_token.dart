import 'package:flutter/services.dart';

/// Method channel shared with the native Clerk bridge
/// (`android/app/src/main/kotlin/com/sangeet/app/ClerkBridge.kt`).
///
/// Declared here rather than imported from the auth provider so a service that
/// only needs a token does not have to depend on the whole auth notifier.
const MethodChannel _clerkChannel = MethodChannel('com.soulfulbhakti.app/clerk');

/// Returns a short-lived Clerk session JWT for the signed-in user, or null.
///
/// The token is minted on demand by the native SDK and expires in about a
/// minute; it is never stored. The server verifies it on every request, so a
/// leaked token has a very small blast radius and a short life.
///
/// Returns null (never throws) when:
///  - the platform has no Clerk bridge (desktop, iOS, tests);
///  - the user is signed out;
///  - the token fetch failed.
///
/// Callers must treat null as "not authenticated" and must NOT grant access.
Future<String?> clerkSessionToken() async {
  try {
    final token = await _clerkChannel.invokeMethod<String>('getToken');
    if (token == null || token.isEmpty) return null;
    return token;
  } on MissingPluginException {
    // No native bridge on this platform (desktop/iOS/web/test).
    return null;
  } on PlatformException {
    // The native side reported a failure; the caller treats it as signed out.
    return null;
  }
}
