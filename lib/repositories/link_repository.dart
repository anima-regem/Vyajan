import '../models/link_item.dart';

abstract class LinkRepository {
  Stream<List<LinkItem>> watchInboxQueue(String userId);

  Stream<List<LinkItem>> watchCurated(String userId);

  Stream<List<LinkItem>> watchByStatus(String userId, LinkStatus status);

  Stream<List<LinkItem>> watchAll(String userId);

  Future<List<LinkItem>> getAll(String userId);

  Future<String> addLink({
    required String userId,
    required String url,
    required String title,
    required String createdBy,
    required LinkStatus status,
    List<String> tags,
    String? collectionId,
    String? summary,
    String? sourceDomain,
    String? metadataTitle,
    String? metadataDescription,
    String? metadataImage,
    String? metadataSiteName,
    DateTime? snoozedUntil,
  });

  Future<void> updateLink(LinkItem link);

  Future<void> patchLink(
    String linkId,
    Map<String, dynamic> patch,
  );

  Future<void> updateStatus(
    String linkId,
    LinkStatus status, {
    DateTime? snoozedUntil,
    DateTime? triagedAt,
  });

  Future<void> incrementOpenCount(String linkId);

  Future<void> batchUpdateStatus(List<String> linkIds, LinkStatus status);

  Future<void> deleteLink(String linkId);

  Future<List<LinkItem>> fetchBatchForMigration(String userId,
      {int limit = 200});
}
