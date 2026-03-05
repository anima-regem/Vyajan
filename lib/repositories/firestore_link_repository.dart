import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/link_item.dart';
import 'link_repository.dart';

class FirestoreLinkRepository implements LinkRepository {
  FirestoreLinkRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _links =>
      _firestore.collection('links');

  @override
  Stream<List<LinkItem>> watchInboxQueue(String userId) {
    return _links
        .where('userId', isEqualTo: userId)
        .where('status', whereIn: const ['inbox', 'snoozed'])
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => LinkItem.fromMap(doc.data(), doc.id))
              .where((link) => link.isActionableInbox)
              .toList();
        });
  }

  @override
  Stream<List<LinkItem>> watchCurated(String userId) {
    return watchByStatus(userId, LinkStatus.curated);
  }

  @override
  Stream<List<LinkItem>> watchByStatus(String userId, LinkStatus status) {
    return _links
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: status.value)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => LinkItem.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  @override
  Stream<List<LinkItem>> watchAll(String userId) {
    return _links
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => LinkItem.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  @override
  Future<List<LinkItem>> getAll(String userId) async {
    final snapshot = await _links
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => LinkItem.fromMap(doc.data(), doc.id))
        .toList();
  }

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
    final createdAt = DateTime.now();
    final docRef = await _links.add({
      'userId': userId,
      'url': url,
      'title': title,
      'status': status.value,
      'createdAt': Timestamp.fromDate(createdAt),
      'tags': tags,
      'collectionId': collectionId,
      'summary': summary,
      'sourceDomain': sourceDomain,
      'openedCount': 0,
      'lastOpenedAt': null,
      'triagedAt': null,
      'snoozedUntil':
          snoozedUntil != null ? Timestamp.fromDate(snoozedUntil) : null,
      'createdBy': createdBy,
      'schemaVersion': 2,
      'metadataTitle': metadataTitle,
      'metadataDescription': metadataDescription,
      'metadataImage': metadataImage,
      'metadataSiteName': metadataSiteName,

      // legacy compatibility
      'isPermanent': status == LinkStatus.curated,
      'isArchived': status == LinkStatus.archived,
    });

    return docRef.id;
  }

  @override
  Future<void> updateLink(LinkItem link) async {
    await _links.doc(link.id).set(link.toMap(), SetOptions(merge: true));
  }

  @override
  Future<void> patchLink(
    String linkId,
    Map<String, dynamic> patch,
  ) async {
    await _links.doc(linkId).set(patch, SetOptions(merge: true));
  }

  @override
  Future<void> updateStatus(
    String linkId,
    LinkStatus status, {
    DateTime? snoozedUntil,
    DateTime? triagedAt,
  }) async {
    final patch = <String, dynamic>{
      'status': status.value,
      'isPermanent': status == LinkStatus.curated,
      'isArchived': status == LinkStatus.archived,
      'schemaVersion': 2,
      'triagedAt': status == LinkStatus.inbox
          ? null
          : Timestamp.fromDate(triagedAt ?? DateTime.now()),
      'snoozedUntil':
          snoozedUntil != null ? Timestamp.fromDate(snoozedUntil) : null,
    };
    await _links.doc(linkId).set(patch, SetOptions(merge: true));
  }

  @override
  Future<void> incrementOpenCount(String linkId) async {
    await _links.doc(linkId).set(
      {
        'openedCount': FieldValue.increment(1),
        'lastOpenedAt': Timestamp.now(),
      },
      SetOptions(merge: true),
    );
  }

  @override
  Future<void> batchUpdateStatus(
      List<String> linkIds, LinkStatus status) async {
    final batch = _firestore.batch();
    for (final linkId in linkIds) {
      batch.set(
        _links.doc(linkId),
        {
          'status': status.value,
          'isPermanent': status == LinkStatus.curated,
          'isArchived': status == LinkStatus.archived,
          'triagedAt': Timestamp.now(),
          'schemaVersion': 2,
        },
        SetOptions(merge: true),
      );
    }
    await batch.commit();
  }

  @override
  Future<void> deleteLink(String linkId) async {
    await _links.doc(linkId).delete();
  }

  @override
  Future<List<LinkItem>> fetchBatchForMigration(
    String userId, {
    int limit = 200,
  }) async {
    final snapshot = await _links
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs
        .map((doc) => LinkItem.fromMap(doc.data(), doc.id))
        .toList();
  }
}
