import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:metadata_fetch/metadata_fetch.dart';

import '../models/link_item.dart';
import '../repositories/firestore_link_repository.dart';
import '../repositories/link_repository.dart';

/// Legacy compatibility facade.
///
/// New code should use repositories directly from `lib/repositories/`.
@Deprecated(
    'Use LinkRepository + CollectionRepository + PreferencesRepository.')
class DatabaseService {
  DatabaseService({
    FirebaseFirestore? firestore,
    LinkRepository? linkRepository,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _linkRepository = linkRepository ??
            FirestoreLinkRepository(firestore ?? FirebaseFirestore.instance);

  final FirebaseFirestore _firestore;
  final LinkRepository _linkRepository;

  Stream<List<LinkItem>> getUserLinks(String userId) {
    return _linkRepository.watchAll(userId);
  }

  Stream<List<LinkItem>> getImportantLinks(String userId) {
    return _linkRepository.watchByStatus(userId, LinkStatus.curated);
  }

  Stream<List<LinkItem>> getArchivedLinks(String userId) {
    return _linkRepository.watchByStatus(userId, LinkStatus.archived);
  }

  Future<void> toggleArchived(String linkId, bool isArchived) async {
    await _linkRepository.updateStatus(
      linkId,
      isArchived ? LinkStatus.archived : LinkStatus.inbox,
    );
  }

  Future<String> addLink({
    required String url,
    required String title,
    required bool isPermanent,
    required bool isArchived,
    required String userId,
  }) async {
    final status = isArchived
        ? LinkStatus.archived
        : (isPermanent ? LinkStatus.curated : LinkStatus.inbox);

    return _linkRepository.addLink(
      userId: userId,
      url: url,
      title: title,
      createdBy: 'manual',
      status: status,
    );
  }

  Future<void> togglePermanent(String linkId, bool isPermanent) async {
    await _linkRepository.updateStatus(
      linkId,
      isPermanent ? LinkStatus.curated : LinkStatus.inbox,
    );
  }

  Future<void> updateMetadata(String linkId, MetaDataObject metadata) async {
    await _linkRepository.patchLink(linkId, {
      'title': metadata.title,
      'metadataTitle': metadata.title,
      'metadataDescription': metadata.description,
      'metadataImage': metadata.image,
      'metadataSiteName': metadata.siteName,
      'summary': metadata.description,
    });
  }

  Future<void> deleteLink(String linkId) {
    return _linkRepository.deleteLink(linkId);
  }

  Future<void> refreshMetadata(String linkId, String url) async {
    final metadata = await MetadataFetch.extract(url);
    if (metadata == null) return;

    await updateMetadata(
      linkId,
      MetaDataObject(
        title: metadata.title,
        description: metadata.description,
        image: metadata.image,
      ),
    );
  }

  Future<LinkItem?> getLink(String linkId) async {
    final doc = await _firestore.collection('links').doc(linkId).get();
    if (!doc.exists || doc.data() == null) {
      return null;
    }
    return LinkItem.fromMap(doc.data()!, doc.id);
  }

  Future<void> restoreLink(LinkItem link) async {
    await _firestore.collection('links').doc(link.id).set(link.toMap());
  }
}
