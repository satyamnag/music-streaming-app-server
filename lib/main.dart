import 'dart:async';
import 'dart:ui';
import 'dart:io';

import 'package:desktop_webview_window/desktop_webview_window.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter/services.dart';
import 'package:flutter_discord_rpc/flutter_discord_rpc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:home_widget/home_widget.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:media_kit/media_kit.dart';
import 'package:metadata_god/metadata_god.dart';
import 'package:smtc_windows/smtc_windows.dart';

import 'package:sangeet/collections/env.dart';
import 'package:sangeet/collections/http-override.dart';
import 'package:sangeet/collections/intents.dart';
import 'package:sangeet/collections/routes.dart';
import 'package:sangeet/hooks/configurators/use_close_behavior.dart';

import 'package:sangeet/hooks/configurators/use_fix_window_stretching.dart';
import 'package:sangeet/hooks/configurators/use_get_storage_perms.dart';
import 'package:sangeet/hooks/configurators/use_has_touch.dart';
import 'package:sangeet/models/database/database.dart';
import 'package:sangeet/modules/auth/clerk_auth_view.dart';
import 'package:sangeet/modules/settings/color_scheme_picker_dialog.dart';
import 'package:sangeet/modules/settings/bhakti_color_scheme.dart';
import 'package:sangeet/modules/splash/splash_screen.dart';
import 'package:sangeet/provider/audio_player/audio_player_streams.dart';
import 'package:sangeet/provider/auth/clerk_auth_provider.dart';
import 'package:sangeet/provider/database/database.dart';
import 'package:sangeet/provider/glance/glance.dart';
import 'package:sangeet/provider/metadata_plugin/metadata_plugin_provider.dart';
import 'package:sangeet/provider/metadata_plugin/updater/update_checker.dart';
import 'package:sangeet/provider/server/bonsoir.dart';
import 'package:sangeet/provider/server/server.dart';
import 'package:sangeet/provider/tray_manager/tray_manager.dart';
import 'package:sangeet/l10n/l10n.dart';
import 'package:sangeet/l10n/app_localizations_fallback_delegate.dart';
import 'package:sangeet/provider/connect/clients.dart';
import 'package:sangeet/provider/user_preferences/user_preferences_provider.dart';
import 'package:sangeet/services/audio_player/audio_player.dart';
import 'package:sangeet/services/cli/cli.dart';
import 'package:sangeet/services/kv_store/encrypted_kv_store.dart';
import 'package:sangeet/services/kv_store/kv_store.dart';
import 'package:sangeet/services/logger/logger.dart';
import 'package:sangeet/services/wm_tools/wm_tools.dart';
import 'package:sangeet/utils/migrations/sandbox.dart';
import 'package:sangeet/utils/platform.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:window_manager/window_manager.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:superwallkit_flutter/superwallkit_flutter.dart';
import 'package:yt_dlp_dart/yt_dlp_dart.dart';
import 'package:flutter_new_pipe_extractor/flutter_new_pipe_extractor.dart';

Future<void> main(List<String> rawArgs) async {
  if (rawArgs.contains("web_view_title_bar")) {
    WidgetsFlutterBinding.ensureInitialized();
    if (runWebViewTitleBarWidget(rawArgs)) {
      return;
    }
  }
  final arguments = await startCLI(rawArgs);
  AppLogger.initialize(arguments["verbose"]);

  AppLogger.runZoned(() async {
    final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();

    HttpOverrides.global = BadCertificateAllowlistOverrides();

    // await registerWindowsScheme("spotify");

    tz.initializeTimeZones();

    MediaKit.ensureInitialized();

    await migrateMacOsFromSandboxToNoSandbox();

    // force High Refresh Rate on some Android devices (like One Plus)
    if (kIsAndroid) {
      await FlutterDisplayMode.setHighRefreshRate();
    }
    if (kIsAndroid || kIsDesktop) {
      await NewPipeExtractor.init();
    }

    if (!kIsWeb) {
      MetadataGod.initialize();
    }

    await KVStoreService.initialize();

    if (kIsDesktop) {
      await windowManager.setPreventClose(true);
      await YtDlp.instance
          .setBinaryLocation(
            KVStoreService.getYoutubeEnginePath(YoutubeClientEngine.ytDlp) ??
                "yt-dlp${kIsWindows ? '.exe' : ''}",
          )
          .catchError((e, stack) => null);
      await FlutterDiscordRPC.initialize(Env.discordAppId);
    }

    if (kIsWindows) {
      await SMTCWindows.initialize();
    }

    await EncryptedKvStoreService.initialize();

    final database = AppDatabase();

    if (kIsDesktop) {
      await localNotifier.setup(appName: "Soulful Bhakti");
      await WindowManagerTools.initialize();
    }

    if (kIsIOS) {
      HomeWidget.setAppGroupId("group.sangeet_home_player_widget");
    }

    // Superwall paywall/monetization SDK. The publishable key is public by
    // design; configure only when present so the app runs without a key.
    if (Env.superwallApiKey.isNotEmpty) {
      final superwallOptions = SuperwallOptions();
      superwallOptions.paywalls.shouldPreload = true;
      superwallOptions.logging.level = LogLevel.error;
      Superwall.configure(
        Env.superwallApiKey,
        options: superwallOptions,
      );
    }

    runApp(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWith((ref) => database),
        ],
        observers: const [
          AppLoggerProviderObserver(),
        ],
        child: const Sangeet(),
      ),
    );
  });
}

class Sangeet extends HookConsumerWidget {
  const Sangeet({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final themeMode =
        ref.watch(userPreferencesProvider.select((s) => s.themeMode));
    final locale = ref.watch(userPreferencesProvider.select((s) => s.locale));
    final accentMaterialColor =
        ref.watch(userPreferencesProvider.select((s) => s.accentColorScheme));
    final router = useMemoized(() => AppRouter(ref), []);
    final hasTouchSupport = useHasTouch();

    ref.listen(audioPlayerStreamListenersProvider, (_, __) {});
    ref.listen(bonsoirProvider, (_, __) {});
    ref.listen(connectClientsProvider, (_, __) {});
    ref.listen(serverProvider, (_, __) {});
    ref.read(serverProvider);
    ref.listen(trayManagerProvider, (_, __) {});
    ref.listen(metadataPluginsProvider, (_, __) {});
    ref.listen(metadataPluginProvider, (_, __) {});
    ref.listen(audioSourcePluginProvider, (_, __) {});
    ref.listen(metadataPluginUpdateCheckerProvider, (_, __) {});
    ref.listen(audioSourcePluginUpdateCheckerProvider, (_, __) {});

    useFixWindowStretching();
    useCloseBehavior(ref);
    useGetStoragePermissions(ref);

    useEffect(() {
      if (kIsMobile) {
        HomeWidget.registerInteractivityCallback(glanceBackgroundCallback);
      }

      return () {
        /// For enabling hot reload for audio player
        if (!kDebugMode) return;
        audioPlayer.dispose();
      };
    }, []);

    return ShadcnApp.router(
      supportedLocales: L10n.all,
      locale: locale.languageCode == "system" ? null : locale,
      localizationsDelegates: const [
        AppLocalizationsFallbackDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router.config(),
      debugShowCheckedModeBanner: false,
      title: 'Soulful Bhakti',
      builder: (context, child) {
        child = ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(
            dragDevices: hasTouchSupport
                ? {
                    PointerDeviceKind.touch,
                    PointerDeviceKind.stylus,
                    PointerDeviceKind.invertedStylus,
                  }
                : null,
          ),
          child: child!,
        );

        if (kIsLinux) {
          child = DragToResizeArea(
            resizeEdgeSize: 2.5,
            child: child,
          );
        }

        // Show the splash screen until the metadata plugin and local playback
        // server have finished initializing, then transition to the app.
        final pluginLoading = ref.watch(
          metadataPluginProvider.select((s) => s.isLoading),
        );
        final serverLoading = ref.watch(
          serverProvider.select((s) => s.isLoading),
        );
        if (pluginLoading || serverLoading) {
          child = const SplashScreen();
        }

        // On Android, gate the app behind Clerk auth: signed-out users see
        // the sign-in view as a modal popup over the app until they
        // authenticate.
        if (!kIsAndroid || child is! SplashScreen) {
          final clerkAuth = ref.watch(clerkAuthProvider);
          final clerkState = clerkAuth.value ?? const ClerkAuthState();
          if (!clerkAuth.isLoading &&
              clerkState.initialized &&
              !clerkState.signedIn) {
            child = Stack(
              children: [
                child,
                const ClerkAuthView(),
              ],
            );
          }
        }

        return child;
      },
      scaling: const AdaptiveScaling(1),
      theme: ThemeData(
        radius: .5,
        iconTheme: const IconThemeProperties(),
        colorScheme:
            colorSchemeMap[accentMaterialColor.name]?.call(ThemeMode.light) ??
                BhaktiColorSchemes.lightMaroon(),
        surfaceOpacity: .8,
        surfaceBlur: 10,
      ),
      darkTheme: ThemeData(
        radius: .5,
        iconTheme: const IconThemeProperties(),
        colorScheme:
            colorSchemeMap[accentMaterialColor.name]?.call(ThemeMode.dark) ??
                BhaktiColorSchemes.darkMaroon(),
        surfaceOpacity: .8,
        surfaceBlur: 10,
      ),
      materialTheme: material.ThemeData(
        brightness: switch (themeMode) {
          ThemeMode.system => MediaQuery.platformBrightnessOf(context),
          ThemeMode.light => Brightness.light,
          ThemeMode.dark => Brightness.dark,
        },
        splashFactory: material.NoSplash.splashFactory,
        appBarTheme: const material.AppBarTheme(
          surfaceTintColor: Colors.transparent,
          scrolledUnderElevation: 0,
          shadowColor: Colors.transparent,
          elevation: 0,
        ),
      ),
      themeMode: themeMode,
      shortcuts: {
        ...WidgetsApp.defaultShortcuts.map((key, value) {
          return MapEntry(
            LogicalKeySet.fromSet(key.triggers?.toSet() ?? {}),
            value,
          );
        }),
        LogicalKeySet(LogicalKeyboardKey.space): PlayPauseIntent(ref),
        LogicalKeySet(LogicalKeyboardKey.comma, LogicalKeyboardKey.control):
            NavigationIntent(router, "/settings"),
        LogicalKeySet(
          LogicalKeyboardKey.digit1,
          LogicalKeyboardKey.control,
          LogicalKeyboardKey.shift,
        ): HomeTabIntent(router, tab: HomeTabs.browse),
        LogicalKeySet(
          LogicalKeyboardKey.digit2,
          LogicalKeyboardKey.control,
          LogicalKeyboardKey.shift,
        ): HomeTabIntent(router, tab: HomeTabs.search),
        LogicalKeySet(
          LogicalKeyboardKey.digit3,
          LogicalKeyboardKey.control,
          LogicalKeyboardKey.shift,
        ): HomeTabIntent(router, tab: HomeTabs.lyrics),
        LogicalKeySet(
          LogicalKeyboardKey.digit4,
          LogicalKeyboardKey.control,
          LogicalKeyboardKey.shift,
        ): HomeTabIntent(router, tab: HomeTabs.userPlaylists),
        LogicalKeySet(
          LogicalKeyboardKey.digit5,
          LogicalKeyboardKey.control,
          LogicalKeyboardKey.shift,
        ): HomeTabIntent(router, tab: HomeTabs.userArtists),
        LogicalKeySet(
          LogicalKeyboardKey.keyW,
          LogicalKeyboardKey.control,
          LogicalKeyboardKey.shift,
        ): CloseAppIntent(),
      },
      actions: {
        ...WidgetsApp.defaultActions,
        PlayPauseIntent: PlayPauseAction(),
        NavigationIntent: NavigationAction(),
        HomeTabIntent: HomeTabAction(),
        CloseAppIntent: CloseAppAction(),
      },
    );
  }
}
