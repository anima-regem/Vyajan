import 'package:cloud_firestore/cloud_firestore.dart';

class CollectionItem {
  const CollectionItem({
    required this.id,
    required this.userId,
    required this.name,
    required this.colorHex,
    required this.iconKey,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String name;
  final String colorHex;
  final String iconKey;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory CollectionItem.fromMap(Map<String, dynamic> map, String id) {
    final createdAtRaw = map['createdAt'];
    final updatedAtRaw = map['updatedAt'];

    return CollectionItem(
      id: id,
      userId: (map['userId'] ?? '') as String,
      name: (map['name'] ?? 'Untitled') as String,
      colorHex: (map['colorHex'] ?? '#2E6B4C') as String,
      iconKey: (map['iconKey'] ?? 'folder') as String,
      createdAt: createdAtRaw is Timestamp
          ? createdAtRaw.toDate()
          : DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: updatedAtRaw is Timestamp
          ? updatedAtRaw.toDate()
          : DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'name': name,
      'colorHex': colorHex,
      'iconKey': iconKey,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  CollectionItem copyWith({
    String? id,
    String? userId,
    String? name,
    String? colorHex,
    String? iconKey,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CollectionItem(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      colorHex: colorHex ?? this.colorHex,
      iconKey: iconKey ?? this.iconKey,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
