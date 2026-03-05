import 'package:flutter_test/flutter_test.dart';
import 'package:vyajan/models/link_item.dart';
import 'package:vyajan/models/user_preferences.dart';
import 'package:vyajan/repositories/link_repository.dart';
import 'package:vyajan/repositories/preferences_repository.dart';
import 'package:vyajan/services/migration_coordinator.dart';

class InMemoryLinkRepository implements LinkRepository {
  InMemoryLinkRepository(this.links);

  final List<LinkItem> links;

  @override
  Future<String> addLink({
    required String userId,
    required String url,
    required String title,
    required String createdBy,
    required LinkStatus status,
    List<String> tags = const <String>[],
    String? collectionId,
    String? summary,
    String? sourceDomain,
    String? metadataTitle,
    String? metadataDescription,
    String? metadataImage,
    String? metadataSiteName,
    DateTime? snoozedUntil,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<void> batchUpdateStatus(
      List<String> linkIds, LinkStatus status) async {}

  @override
  Future<void> deleteLink(String linkId) async {}

  @override
  Future<List<LinkItem>> fetchBatchForMigration(String userId,
      {int limit = 200}) async {
    return links.where((link) => link.userId == userId).take(limit).toList();
  }

  @override
  Future<List<LinkItem>> getAll(String userId) async => links;

  @override
  Future<void> incrementOpenCount(String linkId) async {}

  @override
  Future<void> patchLink(String linkId, Map<String, dynamic> patch) async {}

  @override
  Future<void> updateLink(LinkItem link) async {
    final index = links.indexWhere((item) => item.id == link.id);
    links[index] = link;
  }

  @override
  Future<void> updateStatus(String linkId, LinkStatus status,
      {DateTime? snoozedUntil, DateTime? triagedAt}) async {}

  @override
  Stream<List<LinkItem>> watchAll(String userId) => const Stream.empty();

  @override
  Stream<List<LinkItem>> watchByStatus(String userId, LinkStatus status) =>
      const Stream.empty();

  @override
  Stream<List<LinkItem>> watchCurated(String userId) => const Stream.empty();

  @override
  Stream<List<LinkItem>> watchInboxQueue(String userId) => const Stream.empty();
}

class InMemoryPreferencesRepository implements PreferencesRepository {
  InMemoryPreferencesRepository(this.preferences);

  UserPreferences preferences;

  @override
  Future<UserPreferences> getPreferences(String userId) async => preferences;

  @override
  Future<void> patchPreferences(
      String userId, Map<String, dynamic> patch) async {
    preferences = preferences.copyWith(
      schemaVersion:
          patch['schemaVersion'] as int? ?? preferences.schemaVersion,
    );
  }

  @override
  Future<void> setPreferences(
      String userId, UserPreferences preferences) async {
    this.preferences = preferences;
  }

  @override
  Stream<UserPreferences> watchPreferences(String userId) =>
      const Stream.empty();
}

void main() {
  test('migrates legacy links to schema v2', () async {
    final oldLink = LinkItem(
      id: '1',
      userId: 'u1',
      url: 'https://example.com/page',
      title: 'Legacy',
      status: LinkStatus.inbox,
      createdAt: DateTime.now(),
      tags: const [],
      openedCount: 0,
      createdBy: 'manual',
      schemaVersion: 1,
      isArchivedLegacy: true,
    );

    final linkRepo = InMemoryLinkRepository([oldLink]);
    final prefsRepo =
        InMemoryPreferencesRepository(const UserPreferences(schemaVersion: 1));

    final coordinator = MigrationCoordinator(
      linkRepository: linkRepo,
      preferencesRepository: prefsRepo,
    );

    await coordinator.runIfNeeded('u1');

    expect(linkRepo.links.first.schemaVersion, 2);
    expect(linkRepo.links.first.status, LinkStatus.archived);
    expect(linkRepo.links.first.sourceDomain, 'example.com');
    expect(prefsRepo.preferences.schemaVersion, 2);
  });
}
