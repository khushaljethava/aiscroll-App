import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router/app_router.dart';
import 'core/router/deep_link.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_mode_provider.dart';
import 'data/providers/auth_provider.dart';
import 'data/providers/content_provider.dart';
import 'data/providers/news_provider.dart';
import 'data/providers/telemetry_provider.dart';
import 'data/providers/user_provider.dart';
import 'data/remote/news_push_service.dart';
import 'features/gamification/providers/quests_provider.dart';

class AIScrollApp extends ConsumerStatefulWidget {
  const AIScrollApp({super.key});

  @override
  ConsumerState<AIScrollApp> createState() => _AIScrollAppState();
}

class _AIScrollAppState extends ConsumerState<AIScrollApp>
    with WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // When the app is backgrounded, push any queued telemetry to the admin
    // so we don't lose events on a process kill, and stop foreground
    // schedulers so they don't burn cycles waiting for the isolate to wake.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // ignore: unawaited_futures
      ref.read(telemetryServiceProvider).flush(force: true);
      ref.read(newsProvider.notifier).scheduler.stop();
      ref.read(contentProvider.notifier).scheduler.stop();
    }
    // When the app returns to the foreground, pull anything we missed while
    // backgrounded, then resume the periodic timers.
    if (state == AppLifecycleState.resumed) {
      final news = ref.read(newsProvider.notifier);
      final content = ref.read(contentProvider.notifier);
      // ignore: unawaited_futures
      news.scheduler.refreshIfStale();
      // ignore: unawaited_futures
      content.scheduler.refreshIfStale();
      news.scheduler.start();
      content.scheduler.start();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // 1. Hydrate content from the on-disk manifest cache BEFORE anything
      //    else reads card/track lists. Synchronous-ish (one SharedPreferences
      //    read + JSON decode) — no network yet.
      await ref.read(contentProvider.notifier).hydrateFromCache();

      // 1b. Hydrate news cache too so the first tab paints instantly.
      await ref.read(newsProvider.notifier).hydrateFromCache();

      // 2. Load persisted profile. Daily counter rollover and streak repair
      //    happen inside `load()`. Quests load after so `recordEvent` sees
      //    the right starting counts.
      await ref.read(userProvider.notifier).load();
      await ref.read(questsProvider.notifier).load();

      // 2b. Prime the client JWT. This round-trips to Firebase App Check
      //     and `/api/client/token` on first run. Silent no-op when the
      //     admin URL isn't configured or Firebase isn't initialised;
      //     Dio interceptors still fire per-request if the cache is warm.
      final user = ref.read(userProvider);
      // ignore: unawaited_futures
      ref.read(authServiceProvider).getValidToken(guestId: user.id);

      // 3. Emit session_start telemetry — non-blocking, drops silently when
      //    no admin URL is configured.
      ref.read(telemetryServiceProvider).logSessionStart(
            guestId: user.id,
            userId: user.isGuest ? null : user.id,
          );

      // 5. Kick the network content refresh in the background, then start
      //    the periodic scheduler so tracks stay fresh while the app is
      //    foregrounded. If a newer manifest exists, feed providers will
      //    rebuild automatically; the current session's composed feed won't
      //    retroactively change — pull-to-refresh recomposes.
      final contentNotifier = ref.read(contentProvider.notifier);
      // ignore: unawaited_futures
      contentNotifier.refresh();
      contentNotifier.scheduler.start();

      // 6. Kick the initial news refresh and start the periodic scheduler
      //    (every 2 minutes while foregrounded).
      final newsNotifier = ref.read(newsProvider.notifier);
      // ignore: unawaited_futures
      newsNotifier.refresh();
      newsNotifier.scheduler.start();

      // 7. Mark the router ready so any notification tap that arrived
      //    before the first frame (cold start from terminated state)
      //    drains and navigates now.
      markRouterReady();

      // 8. Bring up FCM. Best-effort — never blocks UI. Subscribes to
      //    the `news` topic and registers foreground / background /
      //    terminated handlers.
      // ignore: unawaited_futures
      ref.read(newsPushServiceProvider).init();
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);

    // Keep the status-bar icons readable regardless of which theme is
    // active. MaterialApp's Builder gives us a context whose
    // Theme.of(...) has already been resolved.
    return MaterialApp.router(
      title: 'AIScroll',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: appRouter,
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness:
                isDark ? Brightness.light : Brightness.dark,
            statusBarBrightness:
                isDark ? Brightness.dark : Brightness.light,
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
