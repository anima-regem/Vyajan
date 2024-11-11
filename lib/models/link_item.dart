import 'package:cloud_firestore/cloud_firestore.dart';

class LinkItem {
  final String id;
  final String url;
  final String title;
  final bool isPermanent;
  final bool isArchived;
  final DateTime createdAt;
  final String userId;
  final String? metadataTitle;
  final String? metadataDescription;
  final String? metadataImage;
  final String? metadataSiteName;

  LinkItem({
    required this.id,
    required this.url,
    required this.title,
    required this.isPermanent,
    this.isArchived = false,
    required this.createdAt,
    required this.userId,
    this.metadataTitle,
    this.metadataDescription,
    this.metadataImage,
    this.metadataSiteName,
  });

  // Update fromMap
  factory LinkItem.fromMap(Map<String, dynamic> map, String id) {
    return LinkItem(
      id: id,
      url: map['url'] ?? '',
      title: map['title'] ?? '',
      isPermanent: map['isPermanent'] ?? false,
      isArchived: map['isArchived'] ?? false,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      userId: map['userId'] ?? '',
      metadataTitle: map['metadataTitle'],
      metadataDescription: map['metadataDescription'],
      metadataImage: map['metadataImage'],
      metadataSiteName: map['metadataSiteName'],
    );
  }

  // Update toMap
  Map<String, dynamic> toMap() {
    return {
      'url': url,
      'title': title,
      'isPermanent': isPermanent,
      'isArchived': isArchived,
      'createdAt': Timestamp.fromDate(createdAt),
      'userId': userId,
      'metadataTitle': metadataTitle,
      'metadataDescription': metadataDescription,
      'metadataImage': metadataImage,
      'metadataSiteName': metadataSiteName,
    };
  }

  // Update copyWith
  LinkItem copyWith({
    String? id,
    String? url,
    String? title,
    bool? isPermanent,
    bool? isArchived,
    DateTime? createdAt,
    String? userId,
    String? metadataTitle,
    String? metadataDescription,
    String? metadataImage,
    String? metadataSiteName,
  }) {
    return LinkItem(
      id: id ?? this.id,
      url: url ?? this.url,
      title: title ?? this.title,
      isPermanent: isPermanent ?? this.isPermanent,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt ?? this.createdAt,
      userId: userId ?? this.userId,
      metadataTitle: metadataTitle ?? this.metadataTitle,
      metadataDescription: metadataDescription ?? this.metadataDescription,
      metadataImage: metadataImage ?? this.metadataImage,
      metadataSiteName: metadataSiteName ?? this.metadataSiteName,
    );
  }
}
