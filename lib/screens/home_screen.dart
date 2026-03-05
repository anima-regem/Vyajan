import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../components/add_link.dart';
import '../providers/app_providers.dart';
import 'inbox_screen.dart';
import 'insights_screen.dart';
import 'library_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  var _tabIndex = 0;
  var _isBootstrapping = true;
  Object? _bootstrapError;

  static const _titles = [
    'Inbox',
    'Library',
    'Insights',
    'Settings',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bootstrap();
    });
  }

  Future<void> _bootstrap() async {
    final user = ref.read(authServiceProvider).currentUser;
    if (user == null) {
      setState(() {
        _isBootstrapping = false;
      });
      return;
    }

    try {
      final preferencesRepository = ref.read(preferencesRepositoryProvider);
      final currentPrefs = await preferencesRepository.getPreferences(user.uid);
      await preferencesRepository.setPreferences(user.uid, currentPrefs);

      await ref.read(migrationCoordinatorProvider).runIfNeeded(user.uid);

      final analytics = ref.read(analyticsServiceProvider);
      await analytics.setUserId(user.uid);
      await analytics.setInsightsConsent(currentPrefs.insightsOptIn);

      final notifications = ref.read(notificationsServiceProvider);
      await notifications.initialize();
      await notifications.syncDigestSchedules(currentPrefs);

      await analytics.logEssentialEvent('shell_bootstrapped');

      if (!mounted) return;
      setState(() {
        _isBootstrapping = false;
        _bootstrapError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isBootstrapping = false;
        _bootstrapError = error;
      });
    }
  }

  Future<void> _openQuickAdd() async {
    final user = ref.read(authServiceProvider).currentUser;
    if (user == null) return;

    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (_) => QuickAddSheet(userId: user.uid),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authServiceProvider).currentUser;
    if (user == null) {
      return const SizedBox.shrink();
    }

    if (_isBootstrapping) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_bootstrapError != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded, size: 48),
                const SizedBox(height: 12),
                Text(
                  'Failed to initialize workspace.',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  _bootstrapError.toString(),
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () {
                    setState(() {
                      _isBootstrapping = true;
                      _bootstrapError = null;
                    });
                    _bootstrap();
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final screens = [
      InboxScreen(userId: user.uid, onAddLink: _openQuickAdd),
      LibraryScreen(userId: user.uid, onAddLink: _openQuickAdd),
      InsightsScreen(userId: user.uid),
      SettingsScreen(userId: user.uid),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_tabIndex]),
        centerTitle: false,
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 240),
        transitionBuilder: (child, animation) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.04, 0),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
        child: KeyedSubtree(
          key: ValueKey<int>(_tabIndex),
          child: screens[_tabIndex].animate().fadeIn(duration: 180.ms),
        ),
      ),
      floatingActionButton: _tabIndex == 0 || _tabIndex == 1
          ? FloatingActionButton.extended(
              onPressed: _openQuickAdd,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Link'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (index) {
          setState(() {
            _tabIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.inbox_outlined),
            selectedIcon: Icon(Icons.inbox_rounded),
            label: 'Inbox',
          ),
          NavigationDestination(
            icon: Icon(Icons.collections_bookmark_outlined),
            selectedIcon: Icon(Icons.collections_bookmark_rounded),
            label: 'Library',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights_rounded),
            label: 'Insights',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
