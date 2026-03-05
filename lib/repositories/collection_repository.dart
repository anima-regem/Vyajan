import '../models/collection_item.dart';

abstract class CollectionRepository {
  Stream<List<CollectionItem>> watchCollections(String userId);

  Future<List<CollectionItem>> getCollections(String userId);

  Future<String> createCollection({
    required String userId,
    required String name,
    required String colorHex,
    required String iconKey,
  });

  Future<void> updateCollection(CollectionItem collection);

  Future<void> deleteCollection(String collectionId);
}
