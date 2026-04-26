import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/local/preferences_service.dart';
import '../../data/models/card_model.dart';
import '../../data/models/news_model.dart';
import '../../features/feed/screens/learn_detail_screen.dart';
import '../../features/feed/screens/track_learn_screen.dart';
import '../../features/news/screens/news_detail_screen.dart';
import '../../features/news/screens/news_screen.dart';
import '../../features/onboarding/screens/daily_goal_screen.dart';
import '../../features/onboarding/screens/knowledge_level_screen.dart';
import '../../features/onboarding/screens/login_screen.dart';
import '../../features/onboarding/screens/persona_screen.dart';
import '../../features/onboarding/screens/register_screen.dart';
import '../../features/onboarding/screens/splash_screen.dart';
import '../../features/onboarding/screens/topic_picker_screen.dart';
import '../../features/onboarding/screens/welcome_screen.dart';
import '../../features/profile/screens/edit_profile_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/saved/screens/saved_screen.dart';
import '../../features/tracks/screens/boss_quiz_screen.dart';
import '../../features/tracks/screens/tracks_screen.dart';

// ---------------------------------------------------------------------------
// Route path constants
// ---------------------------------------------------------------------------

class AppRoutes {
  AppRoutes._();

  static const splash = '/onboarding/splash';
  static const onboarding = '/onboarding';
  static const onboardingWelcome = '/onboarding/welcome';
  static const onboardingLogin = '/onboarding/login';
  static const onboardingRegister = '/onboarding/register';
  static const onboardingPersona = '/onboarding/persona';
  static const onboardingLevel = '/onboarding/level';
  static const onboardingTopics = '/onboarding/topics';
  static const onboardingGoal = '/onboarding/goal';

  static const news = '/news';

  /// Learn tab landing — now shows the tracks grid. Tapping a track opens
  /// [learnTrack] which renders the full-screen PageView scroll for that
  /// track's cards.
  static const learn = '/learn';
  static const saved = '/saved';
  static const profile = '/profile';
  static const profileEdit = '/profile/edit';

  static const root = '/';

  static String newsDetail(String id) => '$news/$id';

  /// Detail reader for a single learning card (Save / Share / Learned live
  /// here since the feed card is pure reading).
  static String learnCard(String id) => '$learn/card/$id';

  /// Full-screen scroll of a single track's cards.
  static String learnTrack(String id) => '$learn/track/$id';

  /// Boss quiz at the end of a track.
  static String learnTrackQuiz(String id) => '$learn/track/$id/quiz';
}

// ---------------------------------------------------------------------------
// Bottom nav shell
// ---------------------------------------------------------------------------

class _MainShell extends StatelessWidget {
  const _MainShell({required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  // Outlined icons while inactive, filled/rounded when selected — keeps the
  // nav bar quiet but still gives a clear affordance at the current tab.
  static const _tabs = <({IconData icon, IconData selectedIcon, String label})>[
    (
      icon: Icons.article_outlined,
      selectedIcon: Icons.article_rounded,
      label: 'News',
    ),
    (
      icon: Icons.menu_book_outlined,
      selectedIcon: Icons.menu_book_rounded,
      label: 'Learn',
    ),
    (
      icon: Icons.bookmark_outline_rounded,
      selectedIcon: Icons.bookmark_rounded,
      label: 'Saved',
    ),
    (
      icon: Icons.person_outline_rounded,
      selectedIcon: Icons.person_rounded,
      label: 'Profile',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
        destinations: _tabs
            .map(
              (t) => NavigationDestination(
                icon: Icon(t.icon),
                selectedIcon: Icon(t.selectedIcon),
                label: t.label,
              ),
            )
            .toList(),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Router
// ---------------------------------------------------------------------------

final appRouter = GoRouter(
  debugLogDiagnostics: false,
  initialLocation: AppRoutes.splash,
  refreshListenable: PreferencesService.revision,
  redirect: (context, state) {
    final onboarded = PreferencesService.instance.isOnboardingCompleteSync();
    final loc = state.matchedLocation;
    final inOnboarding = loc.startsWith('/onboarding');

    // Splash is allowed in either state — it decides where to go itself.
    if (loc == AppRoutes.splash) return null;

    // Auth screens (welcome / login / register) are always reachable —
    // a guest who already finished onboarding may want to sign in later
    // from the profile screen.
    const alwaysOpen = {
      AppRoutes.onboardingWelcome,
      AppRoutes.onboardingLogin,
      AppRoutes.onboardingRegister,
    };
    if (alwaysOpen.contains(loc)) return null;

    if (!onboarded && !inOnboarding) return AppRoutes.splash;
    if (onboarded && inOnboarding) return AppRoutes.news;
    return null;
  },
  routes: [
    // -----------------------------------------------------------------------
    // Onboarding shell
    // -----------------------------------------------------------------------
    GoRoute(
      path: AppRoutes.onboarding,
      // Only bounce bare "/onboarding" to splash. A parent route's redirect
      // also fires for child matches, so without this guard "/onboarding/persona"
      // would get redirected back to splash and loop. matchedLocation is the
      // parent's path here, so we check state.uri.path for the full request.
      redirect: (context, state) => state.uri.path == AppRoutes.onboarding
          ? AppRoutes.splash
          : null,
      routes: [
        GoRoute(
          path: 'splash',
          builder: (context, state) => const SplashScreen(),
        ),
        GoRoute(
          path: 'welcome',
          builder: (context, state) => const WelcomeScreen(),
        ),
        GoRoute(
          path: 'login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: 'register',
          builder: (context, state) => const RegisterScreen(),
        ),
        GoRoute(
          path: 'persona',
          builder: (context, state) => const PersonaScreen(),
        ),
        GoRoute(
          path: 'level',
          builder: (context, state) => const KnowledgeLevelScreen(),
        ),
        GoRoute(
          path: 'topics',
          builder: (context, state) => const TopicPickerScreen(),
        ),
        GoRoute(
          path: 'goal',
          builder: (context, state) => const DailyGoalScreen(),
        ),
      ],
    ),

    // -----------------------------------------------------------------------
    // Profile edit (full-screen, no bottom nav)
    // -----------------------------------------------------------------------
    GoRoute(
      path: AppRoutes.profileEdit,
      builder: (context, state) => const EditProfileScreen(),
    ),

    // -----------------------------------------------------------------------
    // Main shell with bottom navigation.
    //
    // Exactly four branches — one per visible tab in _MainShell._tabs. The
    // Learn tab landing is the tracks grid; tapping a track pushes the
    // full-screen scroll experience and the boss quiz sits under that.
    // -----------------------------------------------------------------------
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          _MainShell(navigationShell: navigationShell),
      branches: [
        // News — main/default tab.
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.news,
              builder: (context, state) => const NewsScreen(),
              routes: [
                GoRoute(
                  path: ':id',
                  builder: (context, state) => NewsDetailScreen(
                    articleId: state.pathParameters['id']!,
                    initialArticle: state.extra is NewsArticle
                        ? state.extra as NewsArticle
                        : null,
                  ),
                ),
              ],
            ),
          ],
        ),

        // Learn — tracks grid, then per-track PageView scroll.
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.learn,
              builder: (context, state) => const TracksScreen(),
              routes: [
                // /learn/track/:trackId   — scroll the track
                // /learn/track/:trackId/quiz — boss quiz for the track
                GoRoute(
                  path: 'track/:trackId',
                  builder: (context, state) => TrackLearnScreen(
                    trackId: state.pathParameters['trackId']!,
                  ),
                  routes: [
                    GoRoute(
                      path: 'quiz',
                      builder: (context, state) => BossQuizScreen(
                        trackId: state.pathParameters['trackId']!,
                      ),
                    ),
                  ],
                ),
                // /learn/card/:cardId — detail reader (Save / Share / Learned)
                GoRoute(
                  path: 'card/:cardId',
                  builder: (context, state) => LearnDetailScreen(
                    cardId: state.pathParameters['cardId']!,
                    initialCard: state.extra is LearningCard
                        ? state.extra as LearningCard
                        : null,
                  ),
                ),
              ],
            ),
          ],
        ),

        // Saved / bookmarks
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.saved,
              builder: (context, state) => const SavedScreen(),
            ),
          ],
        ),

        // Profile
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.profile,
              builder: (context, state) => const ProfileScreen(),
            ),
          ],
        ),
      ],
    ),
  ],
);
