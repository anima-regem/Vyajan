import '../models/link_item.dart';
import '../repositories/collection_repository.dart';
import '../repositories/link_repository.dart';
import '../services/analytics_service.dart';
import '../services/helpers.dart';
import '../services/local_enrichment_service.dart';

class LinkActionsService {
  LinkActionsService({
    required LinkRepository linkRepository,
    required CollectionRepository collectionRepository,
    required LocalEnrichmentService localEnrichmentService,
    required AnalyticsService analyticsService,
  })  : _linkRepository = linkRepository,
        _collectionRepository = collectionRepository,
        _localEnrichmentService = localEnrichmentService,
        _analyticsService = analyticsService;

  final LinkRepository _linkRepository;
  final CollectionRepository _collectionRepository;
  final LocalEnrichmentService _localEnrichmentService;
  final AnalyticsService _analyticsService;

  Future<String> captureLink({
    required String userId,
    required String rawUrl,
    required String createdBy,
  }) async {
    final url = rawUrl.trim();
    if (!isValidUrl(url)) {
      throw Exception('Enter a valid URL.');
    }

    final collections = await _collectionRepository.getCollections(userId);
    final enrichment = await _localEnrichmentService.enrich(
      url: url,
      collections: collections,
    );

    final linkId = await _linkRepository.addLink(
      userId: userId,
      url: url,
      title: enrichment.title,
      createdBy: createdBy,
      status: LinkStatus.inbox,
      tags: enrichment.tags,
      summary: enrichment.summary,
      sourceDomain: enrichment.sourceDomain,
      metadataTitle: enrichment.title,
      metadataDescription: enrichment.description,
      metadataImage: enrichment.image,
      metadataSiteName: enrichment.siteName,
    );

    await _analyticsService.logEssentialEvent(
      'link_captured',
      parameters: {
        'source': createdBy,
      },
    );

    return linkId;
  }

  Future<void> curateLink({
    required LinkItem link,
    List<String>? tags,
    String? collectionId,
    String? summary,
  }) async {
    final updated = link.copyWith(
      status: LinkStatus.curated,
      tags: tags ?? link.tags,
      collectionId: collectionId ?? link.collectionId,
      summary: summary ?? link.summary,
      triagedAt: DateTime.now(),
      clearSnoozedUntil: true,
    );

    await _linkRepository.updateLink(updated.copyWith(schemaVersion: 2));

    await _analyticsService.logEssentialEvent(
      'link_curated',
      parameters: {
        'tag_count': updated.tags.length,
        'has_collection': updated.collectionId != null,
      },
    );
  }

  Future<void> archiveLink(LinkItem link) async {
    await _linkRepository.updateStatus(
      link.id,
      LinkStatus.archived,
      triagedAt: DateTime.now(),
    );

    await _analyticsService.logEssentialEvent('link_archived');
  }

  Future<void> moveToInbox(LinkItem link) async {
    await _linkRepository.updateStatus(
      link.id,
      LinkStatus.inbox,
    );

    await _analyticsService.logEssentialEvent('link_reopened_inbox');
  }

  Future<void> snoozeLink(LinkItem link, Duration duration) async {
    final until = DateTime.now().add(duration);
    await _linkRepository.updateStatus(
      link.id,
      LinkStatus.snoozed,
      snoozedUntil: until,
      triagedAt: DateTime.now(),
    );

    await _analyticsService.logEssentialEvent(
      'link_snoozed',
      parameters: {'hours': duration.inHours},
    );
  }

  Future<void> recordOpen(LinkItem link) async {
    await _linkRepository.incrementOpenCount(link.id);
  }

  Future<void> batchArchive(List<String> ids) async {
    if (ids.isEmpty) return;
    await _linkRepository.batchUpdateStatus(ids, LinkStatus.archived);
    await _analyticsService.logEssentialEvent(
      'batch_archive',
      parameters: {'count': ids.length},
    );
  }

  Future<void> deleteLink(LinkItem link) async {
    await _linkRepository.deleteLink(link.id);
    await _analyticsService.logEssentialEvent(
      'link_deleted',
      parameters: {'status': link.status.value},
    );
  }
}
