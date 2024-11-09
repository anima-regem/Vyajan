// lib/services/database_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:metadata_fetch/metadata_fetch.dart';
import '../models/link_item.dart';

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String _linksCollection = 'links';

  // Get user's links
  Stream<List<LinkItem>> getUserLinks(String userId) {
    return _db
        .collection(_linksCollection)
        .where('userId', isEqualTo: userId)
        .where('isArchived', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => LinkItem.fromMap(doc.data(), doc.id))
            .toList());
  }

  Stream<List<LinkItem>> getImportantLinks(String userId) {
    return _db
        .collection(_linksCollection)
        .where('userId', isEqualTo: userId)
        .where('isPermanent', isEqualTo: true)
        .where('isArchived', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => LinkItem.fromMap(doc.data(), doc.id))
            .toList());
  }

  Stream<List<LinkItem>> getArchivedLinks(String userId) {
    return _db
        .collection(_linksCollection)
        .where('userId', isEqualTo: userId)
        .where('isArchived', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => LinkItem.fromMap(doc.data(), doc.id))
            .toList());
  }

  Stream<List<LinkItem>> getInboxLinks(String userId) {
    return Stream.value([]); // Empty stream for now
  }

  Future<void> toggleArchived(String linkId, bool isArchived) async {
    await _db
        .collection(_linksCollection)
        .doc(linkId)
        .update({'isArchived': isArchived});
  }

  // Add new link
  Future<String> addLink({
    required String url,
    required String title,
    required bool isPermanent,
    required String userId,
  }) async {
    // Fetch metadata
    Metadata? metadata;
    try {
      metadata = await MetadataFetch.extract(url);
    } catch (e) {
      print('Error fetching metadata: $e');
    }

    final docRef = await _db.collection(_linksCollection).add({
      'url': url,
      'title': title,
      'isPermanent': isPermanent,
      'isArchived': false,
      'createdAt': Timestamp.now(),
      'userId': userId,
      'metadataTitle': metadata?.title,
      'metadataDescription': metadata?.description,
      'metadataImage': metadata?.image,
    });

    return docRef.id;
  }

  // Update link permanent status
  Future<void> togglePermanent(String linkId, bool isPermanent) async {
    await _db
        .collection(_linksCollection)
        .doc(linkId)
        .update({'isPermanent': isPermanent});
  }

  // Update link metadata
  Future<void> updateMetadata(String linkId, Metadata metadata) async {
    await _db.collection(_linksCollection).doc(linkId).update({
      'metadataTitle': metadata.title,
      'metadataDescription': metadata.description,
      'metadataImage': metadata.image,
    });
  }

  // Delete link
  Future<void> deleteLink(String linkId) async {
    await _db.collection(_linksCollection).doc(linkId).delete();
  }

  // Refresh metadata for a link
  Future<void> refreshMetadata(String linkId, String url) async {
    try {
      final metadata = await MetadataFetch.extract(url);
      if (metadata != null) {
        await updateMetadata(linkId, metadata);
      }
    } catch (e) {
      print('Error refreshing metadata: $e');
      rethrow;
    }
  }

  // Get single link
  Future<LinkItem?> getLink(String linkId) async {
    final doc = await _db.collection(_linksCollection).doc(linkId).get();
    if (doc.exists) {
      return LinkItem.fromMap(doc.data()!, doc.id);
    }
    return null;
  }

  // Restore deleted link
  Future<void> restoreLink(LinkItem link) async {
    await _db.collection(_linksCollection).doc(link.id).set(link.toMap());
  }
}