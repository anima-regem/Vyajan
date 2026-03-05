import 'package:cloud_firestore/cloud_firestore.dart';

enum LinkStatus {
  inbox,
  curated,
  archived,
  snoozed;

  String get value => switch (this) {
        LinkStatus.inbox => 'inbox',
        LinkStatus.curated => 'curated',
        LinkStatus.archived => 'archived',
        LinkStatus.snoozed => 'snoozed',
      };

  static LinkStatus fromValue(String? raw) {
    switch (raw) {
      case 'curated':
        return LinkStatus.curated;
      case 'archived':
        return LinkStatus.archived;
      case 'snoozed':
        return LinkStatus.snoozed;
      case 'inbox':
      default:
        return LinkStatus.inbox;
    }
  }
}

class LinkItem {
  const LinkItem({
    required this.id,
    required this.userId,
    required this.url,
    required this.title,
    required this.status,
    required this.createdAt,
    required this.tags,
    required this.openedCount,
    required this.createdBy,
    required this.schemaVersion,
    this.collectionId,
    this.summary,
    this.sourceDomain,
    this.lastOpenedAt,
    this.triagedAt,
    this.snoozedUntil,
    this.metadataTitle,
    this.metadataDescription,
    this.metadataImage,
    this.metadataSiteName,
    this.isPermanentLegacy = false,
    this.isArchivedLegacy = false,
  });

  final String id;
  final String userId;
  final String url;
  final String title;
  final LinkStatus status;
  final DateTime createdAt;
  final List<String> tags;
  final String? collectionId;
  final String? summary;
  final String? sourceDomain;
  final int openedCount;
  final DateTime? lastOpenedAt;
  final DateTime? triagedAt;
  final DateTime? snoozedUntil;
  final String createdBy;
  final int schemaVersion;
  final String? metadataTitle;
  final String? metadataDescription;
  final String? metadataImage;
  final String? metadataSiteName;

  // Temporary compatibility fields for older documents.
  final bool isPermanentLegacy;
  final bool isArchivedLegacy;

  bool get isActionableInbox {
    if (status == LinkStatus.inbox) return true;
    if (status != LinkStatus.snoozed) return false;
    if (snoozedUntil == null) return true;
    return snoozedUntil!.isBefore(DateTime.now()) ||
        snoozedUntil!.isAtSameMomentAs(DateTime.now());
  }

  factory LinkItem.fromMap(Map<String, dynamic> map, String id) {
    final createdAtRaw = map['createdAt'];
    final lastOpenedAtRaw = map['lastOpenedAt'];
    final triagedAtRaw = map['triagedAt'];
    final snoozedUntilRaw = map['snoozedUntil'];

    final isArchivedLegacy = map['isArchived'] == true;
    final isPermanentLegacy = map['isPermanent'] == true;

    final LinkStatus status;
    if (map['status'] is String) {
      status = LinkStatus.fromValue(map['status'] as String?);
    } else if (isArchivedLegacy) {
      status = LinkStatus.archived;
    } else if (isPermanentLegacy) {
      status = LinkStatus.curated;
    } else {
      status = LinkStatus.inbox;
    }

    final rawTags = map['tags'];
    final tags = rawTags is List
        ? rawTags.whereType<String>().map((tag) => tag.trim()).toList()
        : <String>[];

    return LinkItem(
      id: id,
      userId: (map['userId'] ?? '') as String,
      url: (map['url'] ?? '') as String,
      title: (map['title'] ?? 'Untitled Link') as String,
      status: status,
      createdAt: createdAtRaw is Timestamp
          ? createdAtRaw.toDate()
          : DateTime.fromMillisecondsSinceEpoch(0),
      tags: tags,
      collectionId: map['collectionId'] as String?,
      summary: map['summary'] as String?,
      sourceDomain: map['sourceDomain'] as String?,
      openedCount: (map['openedCount'] as num?)?.toInt() ?? 0,
      lastOpenedAt:
          lastOpenedAtRaw is Timestamp ? lastOpenedAtRaw.toDate() : null,
      triagedAt: triagedAtRaw is Timestamp ? triagedAtRaw.toDate() : null,
      snoozedUntil:
          snoozedUntilRaw is Timestamp ? snoozedUntilRaw.toDate() : null,
      createdBy: (map['createdBy'] ?? 'manual') as String,
      schemaVersion: (map['schemaVersion'] as num?)?.toInt() ?? 1,
      metadataTitle: map['metadataTitle'] as String?,
      metadataDescription: map['metadataDescription'] as String?,
      metadataImage: map['metadataImage'] as String?,
      metadataSiteName: map['metadataSiteName'] as String?,
      isPermanentLegacy: isPermanentLegacy,
      isArchivedLegacy: isArchivedLegacy,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'url': url,
      'title': title,
      'status': status.value,
      'createdAt': Timestamp.fromDate(createdAt),
      'tags': tags,
      'collectionId': collectionId,
      'summary': summary,
      'sourceDomain': sourceDomain,
      'openedCount': openedCount,
      'lastOpenedAt':
          lastOpenedAt != null ? Timestamp.fromDate(lastOpenedAt!) : null,
      'triagedAt': triagedAt != null ? Timestamp.fromDate(triagedAt!) : null,
      'snoozedUntil':
          snoozedUntil != null ? Timestamp.fromDate(snoozedUntil!) : null,
      'createdBy': createdBy,
      'schemaVersion': schemaVersion,
      'metadataTitle': metadataTitle,
      'metadataDescription': metadataDescription,
      'metadataImage': metadataImage,
      'metadataSiteName': metadataSiteName,

      // Keep compatibility fields until a later cleanup migration.
      'isPermanent': status == LinkStatus.curated,
      'isArchived': status == LinkStatus.archived,
    };
  }

  LinkItem copyWith({
    String? id,
    String? userId,
    String? url,
    String? title,
    LinkStatus? status,
    DateTime? createdAt,
    List<String>? tags,
    String? collectionId,
    String? summary,
    String? sourceDomain,
    int? openedCount,
    DateTime? lastOpenedAt,
    DateTime? triagedAt,
    DateTime? snoozedUntil,
    String? createdBy,
    int? schemaVersion,
    String? metadataTitle,
    String? metadataDescription,
    String? metadataImage,
    String? metadataSiteName,
    bool? isPermanentLegacy,
    bool? isArchivedLegacy,
    bool clearCollection = false,
    bool clearSummary = false,
    bool clearSnoozedUntil = false,
  }) {
    return LinkItem(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      url: url ?? this.url,
      title: title ?? this.title,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      tags: tags ?? this.tags,
      collectionId: clearCollection ? null : collectionId ?? this.collectionId,
      summary: clearSummary ? null : summary ?? this.summary,
      sourceDomain: sourceDomain ?? this.sourceDomain,
      openedCount: openedCount ?? this.openedCount,
      lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
      triagedAt: triagedAt ?? this.triagedAt,
      snoozedUntil:
          clearSnoozedUntil ? null : snoozedUntil ?? this.snoozedUntil,
      createdBy: createdBy ?? this.createdBy,
      schemaVersion: schemaVersion ?? this.schemaVersion,
      metadataTitle: metadataTitle ?? this.metadataTitle,
      metadataDescription: metadataDescription ?? this.metadataDescription,
      metadataImage: metadataImage ?? this.metadataImage,
      metadataSiteName: metadataSiteName ?? this.metadataSiteName,
      isPermanentLegacy: isPermanentLegacy ?? this.isPermanentLegacy,
      isArchivedLegacy: isArchivedLegacy ?? this.isArchivedLegacy,
    );
  }
}

class MetaDataObject {
  const MetaDataObject({
    this.title,
    this.description,
    this.image,
    this.siteName,
  });

  final String? title;
  final String? description;
  final String? image;
  final String? siteName;

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'image': image,
      'siteName': siteName,
    };
  }

  factory MetaDataObject.fromMap(Map<String, dynamic> map) {
    return MetaDataObject(
      title: map['title'] as String?,
      description: map['description'] as String?,
      image: map['image'] as String?,
      siteName: map['siteName'] as String?,
    );
  }
}
