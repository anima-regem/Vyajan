import '../models/link_item.dart';
import '../repositories/link_repository.dart';
import '../repositories/preferences_repository.dart';
import '../services/constants.dart';
import '../services/helpers.dart';

class MigrationCoordinator {
  MigrationCoordinator({
    required LinkRepository linkRepository,
    required PreferencesRepository preferencesRepository,
  })  : _linkRepository = linkRepository,
        _preferencesRepository = preferencesRepository;

  final LinkRepository _linkRepository;
  final PreferencesRepository _preferencesRepository;

  Future<void> runIfNeeded(String userId) async {
    final preferences = await _preferencesRepository.getPreferences(userId);
    if (preferences.schemaVersion >= latestSchemaVersion) {
      return;
    }

    final links = await _linkRepository.fetchBatchForMigration(
      userId,
      limit: 200,
    );

    for (final link in links) {
      if (link.schemaVersion >= latestSchemaVersion) {
        continue;
      }

      final mappedStatus = _mapLegacyStatus(link);
      final patched = link.copyWith(
        status: mappedStatus,
        sourceDomain: link.sourceDomain ?? extractSourceDomain(link.url),
        openedCount: link.openedCount,
        schemaVersion: latestSchemaVersion,
      );

      await _linkRepository.updateLink(patched);
    }

    await _preferencesRepository.patchPreferences(userId, {
      'schemaVersion': latestSchemaVersion,
    });
  }

  LinkStatus _mapLegacyStatus(LinkItem link) {
    if (link.status != LinkStatus.inbox ||
        (!link.isArchivedLegacy && !link.isPermanentLegacy)) {
      return link.status;
    }

    if (link.isArchivedLegacy) {
      return LinkStatus.archived;
    }

    if (link.isPermanentLegacy) {
      return LinkStatus.curated;
    }

    return LinkStatus.inbox;
  }
}
