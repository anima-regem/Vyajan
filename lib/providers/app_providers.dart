import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/collection_item.dart';
import '../models/link_item.dart';
import '../models/user_preferences.dart';
import '../repositories/collection_repository.dart';
import '../repositories/firestore_collection_repository.dart';
import '../repositories/firestore_link_repository.dart';
import '../repositories/firestore_preferences_repository.dart';
import '../repositories/link_repository.dart';
import '../repositories/preferences_repository.dart';
import '../services/analytics_service.dart';
import '../services/auth_service.dart';
import '../services/insights_service.dart';
import '../services/link_actions_service.dart';
import '../services/local_enrichment_service.dart';
import '../services/migration_coordinator.dart';
import '../services/notifications_service.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(auth: ref.watch(firebaseAuthProvider));
});

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

final linkRepositoryProvider = Provider<LinkRepository>((ref) {
  return FirestoreLinkRepository(ref.watch(firestoreProvider));
});

final collectionRepositoryProvider = Provider<CollectionRepository>((ref) {
  return FirestoreCollectionRepository(ref.watch(firestoreProvider));
});

final preferencesRepositoryProvider = Provider<PreferencesRepository>((ref) {
  return FirestorePreferencesRepository(ref.watch(firestoreProvider));
});

final analyticsServiceProvider = Provider<AnalyticsService>((ref) {
  return AnalyticsService(FirebaseAnalytics.instance);
});

final localEnrichmentServiceProvider = Provider<LocalEnrichmentService>((ref) {
  return HeuristicLocalEnrichmentService();
});

final insightsServiceProvider = Provider<InsightsService>((ref) {
  return LocalInsightsService();
});

final notificationsPluginProvider =
    Provider<FlutterLocalNotificationsPlugin>((ref) {
  return FlutterLocalNotificationsPlugin();
});

final notificationsServiceProvider = Provider<NotificationsService>((ref) {
  return NotificationsService(ref.watch(notificationsPluginProvider));
});

final migrationCoordinatorProvider = Provider<MigrationCoordinator>((ref) {
  return MigrationCoordinator(
    linkRepository: ref.watch(linkRepositoryProvider),
    preferencesRepository: ref.watch(preferencesRepositoryProvider),
  );
});

final linkActionsServiceProvider = Provider<LinkActionsService>((ref) {
  return LinkActionsService(
    linkRepository: ref.watch(linkRepositoryProvider),
    collectionRepository: ref.watch(collectionRepositoryProvider),
    localEnrichmentService: ref.watch(localEnrichmentServiceProvider),
    analyticsService: ref.watch(analyticsServiceProvider),
  );
});

final inboxLinksProvider =
    StreamProvider.family<List<LinkItem>, String>((ref, userId) {
  return ref.watch(linkRepositoryProvider).watchInboxQueue(userId);
});

final curatedLinksProvider =
    StreamProvider.family<List<LinkItem>, String>((ref, userId) {
  return ref.watch(linkRepositoryProvider).watchCurated(userId);
});

final allLinksProvider =
    StreamProvider.family<List<LinkItem>, String>((ref, userId) {
  return ref.watch(linkRepositoryProvider).watchAll(userId);
});

final archivedLinksProvider =
    StreamProvider.family<List<LinkItem>, String>((ref, userId) {
  return ref
      .watch(linkRepositoryProvider)
      .watchByStatus(userId, LinkStatus.archived);
});

final collectionsProvider =
    StreamProvider.family<List<CollectionItem>, String>((ref, userId) {
  return ref.watch(collectionRepositoryProvider).watchCollections(userId);
});

final userPreferencesProvider =
    StreamProvider.family<UserPreferences, String>((ref, userId) {
  return ref.watch(preferencesRepositoryProvider).watchPreferences(userId);
});

final themeModeProvider = AsyncNotifierProvider<ThemeModeController, ThemeMode>(
    ThemeModeController.new);

class ThemeModeController extends AsyncNotifier<ThemeMode> {
  @override
  Future<ThemeMode> build() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('theme_mode') ?? 'system';
    return _parse(raw);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = AsyncValue.data(mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode', _toRaw(mode));
  }

  ThemeMode _parse(String raw) {
    switch (raw) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }

  String _toRaw(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }
}

class StreamTick extends ChangeNotifier {
  StreamTick(Stream<dynamic> stream) {
    _subscription = stream.asBroadcastStream().listen((_) {
      notifyListeners();
    });
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
