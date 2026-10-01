import 'package:sangeet/provider/auth/clerk_auth_provider.dart';
import 'package:test/test.dart';

void main() {
  group('ClerkAuthState.fromMap', () {
    test('maps every field (including the new fullName)', () {
      final state = ClerkAuthState.fromMap({
        'initialized': true,
        'signedIn': true,
        'userId': 'user_123',
        'email': 'arjun@example.com',
        'username': 'arjun',
        'fullName': 'Arjun Sharma',
        'imageUrl': 'https://example.com/avatar.png',
        'emailVerified': true,
      });

      expect(state.initialized, isTrue);
      expect(state.signedIn, isTrue);
      expect(state.userId, 'user_123');
      expect(state.email, 'arjun@example.com');
      expect(state.username, 'arjun');
      expect(state.fullName, 'Arjun Sharma');
      expect(state.imageUrl, 'https://example.com/avatar.png');
      expect(state.emailVerified, isTrue);
    });

    test('empty strings are stored as null', () {
      final state = ClerkAuthState.fromMap({
        'initialized': false,
        'signedIn': false,
        'userId': '',
        'email': '',
        'username': '',
        'fullName': '',
        'imageUrl': '',
        'emailVerified': false,
      });

      expect(state.userId, isNull);
      expect(state.email, isNull);
      expect(state.username, isNull);
      expect(state.fullName, isNull);
      expect(state.imageUrl, isNull);
    });

    test('long-running sessions without fullName still parse (back-compat)',
        () {
      // Simulates a state map that predates the fullName field.
      final state = ClerkAuthState.fromMap({
        'signedIn': true,
        'userId': 'user_1',
        'email': 'a@b.co',
        'username': 'legacy-user',
        'emailVerified': true,
      });

      expect(state.fullName, isNull);
      expect(state.displayName, 'legacy-user');
    });
  });

  group('ClerkAuthState.displayName', () {
    test('prefers the composed Google profile name', () {
      const state = ClerkAuthState(signedIn: true, fullName: 'Arjun Sharma');
      expect(state.displayName, 'Arjun Sharma');
    });

    test('falls back to the Clerk username when fullName is absent', () {
      const state = ClerkAuthState(signedIn: true, username: 'arjun');
      expect(state.displayName, 'arjun');
    });

    test('falls back to the Clerk username when fullName is blank/whitespace',
        () {
      const state = ClerkAuthState(
        signedIn: true,
        fullName: '   ',
        username: 'arjun',
      );
      expect(state.displayName, 'arjun');
    });

    test('is null when the profile carries no name at all', () {
      const state = ClerkAuthState(signedIn: true, email: 'x@y.z');
      expect(state.displayName, isNull);
    });
  });
}
