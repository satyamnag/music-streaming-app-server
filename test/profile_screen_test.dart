// Guards the Profile screen and the two rules that came with it:
//
//   1. The account lives on the Profile SCREEN (the fourth bottom-nav tab). The
//      profile POPUP that used to hang off the home header's avatar is gone, so
//      the home header must not open it any more — while Search and the
//      notification bell stay exactly where they were.
//   2. The bar's Profile tab carries the listener's identity: their photo once
//      signed in, the generic person icon while signed out. Only the rendered
//      tab changes; the tile list (four tabs, four labels, four icons) does not.
//
// The widget tests pump the real screen with a fake auth state, so the
// signed-in and signed-out layouts are asserted against what a listener
// actually sees rather than against the source.
import 'package:flutter/material.dart' as material;
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:sangeet/l10n/l10n.dart';
import 'package:sangeet/modules/auth/profile_plan_status.dart';
import 'package:sangeet/modules/settings/bhakti_color_scheme.dart';
import 'package:sangeet/pages/profile/profile.dart';
import 'package:sangeet/provider/auth/clerk_auth_provider.dart';
import 'dart:io';

/// A [ClerkAuthNotifier] that answers with a fixed state instead of talking to
/// the native Clerk bridge (which a widget test cannot reach).
class _FakeAuth extends ClerkAuthNotifier {
  final ClerkAuthState value;
  _FakeAuth(this.value);

  @override
  Future<ClerkAuthState> build() async => value;

  @override
  Future<String?> signOut() async => null;

  @override
  Future<String?> deleteAccount() async => null;
}

Widget _harness(ClerkAuthState state) {
  return ProviderScope(
    overrides: [
      clerkAuthProvider.overrideWith(() => _FakeAuth(state)),
    ],
    child: material.MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: L10n.all,
      locale: const Locale('en'),
      home: Builder(
        builder: (context) => Theme(
          data: ThemeData(
            radius: .5,
            iconTheme: const IconThemeProperties(),
            colorScheme: BhaktiColorSchemes.lightMaroon(),
            surfaceOpacity: .8,
            surfaceBlur: 10,
          ),
          child: MediaQuery(
            data: const MediaQueryData(size: Size(400, 900)),
            child: const ProfilePage(),
          ),
        ),
      ),
    ),
  );
}

const _signedIn = ClerkAuthState(
  initialized: true,
  signedIn: true,
  userId: 'user_1',
  email: 'satyamnag642@gmail.com',
  fullName: 'Satyamnag642',
  imageUrl: 'https://example.com/avatar.png',
  emailVerified: true,
);

void main() {
  group('the profile popup is gone and the home header no longer opens it', () {
    test('no ProfileDialog anywhere in the app', () {
      expect(
        File('lib/modules/auth/profile_dialog.dart').existsSync(),
        isFalse,
        reason: 'the popup was replaced by the Profile screen',
      );

      final declarers = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .where((f) => f.readAsStringSync().contains('ProfileDialog'))
          .map((f) => f.path.replaceAll(r'\', '/'))
          .toList();
      expect(declarers, isEmpty, reason: 'nothing may still reference it');
    });

    test('the header keeps search and the bell, and drops the account avatar',
        () {
      final home = File('lib/pages/home/home.dart').readAsStringSync();
      expect(home.contains('SangeetIcons.search'), isTrue,
          reason: 'search stays in the top-right corner');
      expect(home.contains('NotificationBell('), isTrue,
          reason: 'the bell stays next to search');
      expect(home.contains('clerkAuthProvider'), isFalse,
          reason: 'the header no longer reads the account at all');
    });
  });

  group('the Profile tab carries the listener identity', () {
    test('the bar shows the photo only when signed in, the icon otherwise', () {
      final bar = File(
        'lib/modules/root/spotube_navigation_bar.dart',
      ).readAsStringSync();

      expect(bar.contains('clerkAuthProvider'), isTrue,
          reason: 'the tab needs the real auth state');
      expect(bar.contains("tile.id == 'profile'"), isTrue,
          reason: 'only the Profile tab may become a photo; the other three '
              'tabs keep their icons');
      expect(bar.contains('UniversalImage('), isTrue,
          reason: 'the photo comes from the Clerk profile image URL');
      expect(bar.contains('tile.icon'), isTrue,
          reason: 'signed out (or no photo) must fall back to the person icon');
    });
  });

  group('the Profile screen', () {
    testWidgets('signed out: identity block, ACCOUNT group, no actions group',
        (tester) async {
      await tester.pumpWidget(_harness(const ClerkAuthState()));
      await tester.pumpAndSettle();

      expect(find.text('You are not signed in'), findsOneWidget);
      expect(find.text('Sign in to access your account'), findsOneWidget);
      expect(find.text('Sign in'), findsOneWidget);

      // The reference's ACCOUNT group, in order.
      expect(find.text('ACCOUNT'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Manage your app preferences'), findsOneWidget);
      expect(find.text('Notifications'), findsOneWidget);
      expect(find.byType(ProfilePlanStatus), findsOneWidget);

      // Nothing to sign out of.
      expect(find.text('ACCOUNT ACTIONS'), findsNothing);
      expect(find.text('Sign out'), findsNothing);
      expect(find.text('Delete account'), findsNothing);
    });

    testWidgets('signed in: name, email, plan card and both account actions',
        (tester) async {
      await tester.pumpWidget(_harness(_signedIn));
      await tester.pumpAndSettle();

      expect(find.text('Satyamnag642'), findsOneWidget);
      expect(find.text('satyamnag642@gmail.com'), findsOneWidget);
      expect(find.text('You are not signed in'), findsNothing);

      expect(find.text('ACCOUNT'), findsOneWidget);
      expect(find.text('ACCOUNT ACTIONS'), findsOneWidget);
      expect(find.text('Sign out'), findsOneWidget);
      expect(find.text('Delete account'), findsOneWidget);
      expect(
        find.text('Permanently remove your account and data'),
        findsOneWidget,
      );

      // The plan card still reports the free plan with the upgrade entry point.
      expect(find.text('Free plan'), findsOneWidget);
      expect(find.text('CURRENT PLAN'), findsOneWidget);
      expect(find.text('Upgrade to Pro'), findsOneWidget);
    });

    testWidgets('Sign out asks for confirmation first', (tester) async {
      // A phone-sized view: the actions group sits below the fold on a small
      // test surface, and a tap on an off-screen row would silently miss.
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_harness(_signedIn));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Sign out'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();

      expect(find.text('Sign out?'), findsOneWidget,
          reason: 'the session must never be destroyed without an explicit '
              'confirmation');
      expect(find.text('Cancel'), findsOneWidget);
    });
  });
}
