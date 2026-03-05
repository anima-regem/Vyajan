import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/collection_item.dart';
import 'collection_repository.dart';

class FirestoreCollectionRepository implements CollectionRepository {
  FirestoreCollectionRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collections =>
      _firestore.collection('collections');

  @override
  Stream<List<CollectionItem>> watchCollections(String userId) {
    return _collections
        .where('userId', isEqualTo: userId)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => CollectionItem.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  @override
  Future<List<CollectionItem>> getCollections(String userId) async {
    final snapshot = await _collections
        .where('userId', isEqualTo: userId)
        .orderBy('updatedAt', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => CollectionItem.fromMap(doc.data(), doc.id))
        .toList();
  }

  @override
  Future<String> createCollection({
    required String userId,
    required String name,
    required String colorHex,
    required String iconKey,
  }) async {
    final now = DateTime.now();

    final docRef = await _collections.add({
      'userId': userId,
      'name': name,
      'colorHex': colorHex,
      'iconKey': iconKey,
      'createdAt': Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
    });

    return docRef.id;
  }

  @override
  Future<void> updateCollection(CollectionItem collection) async {
    await _collections.doc(collection.id).set(
          collection.copyWith(updatedAt: DateTime.now()).toMap(),
          SetOptions(merge: true),
        );
  }

  @override
  Future<void> deleteCollection(String collectionId) async {
    await _collections.doc(collectionId).delete();
  }
}
