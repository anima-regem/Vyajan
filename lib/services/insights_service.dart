import 'package:collection/collection.dart';

import '../models/collection_item.dart';
import '../models/link_item.dart';
import '../models/productivity_insights.dart';
import '../services/helpers.dart';

abstract class InsightsService {
  ProductivityInsights calculate(
    List<LinkItem> links,
    List<CollectionItem> collections,
  );
}

class LocalInsightsService implements InsightsService {
  @override
  ProductivityInsights calculate(
    List<LinkItem> links,
    List<CollectionItem> collections,
  ) {
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));

    final capturedThisWeek =
        links.where((link) => link.createdAt.isAfter(weekAgo)).toList();

    final triagedThisWeek = capturedThisWeek
        .where((link) =>
            link.status == LinkStatus.curated ||
            link.status == LinkStatus.archived)
        .toList();

    final inboxToOrganizedRate = capturedThisWeek.isEmpty
        ? 0.0
        : triagedThisWeek.length / capturedThisWeek.length;

    final captureToTriageHours = triagedThisWeek
        .where((link) => link.triagedAt != null)
        .map((link) =>
            link.triagedAt!.difference(link.createdAt).inMinutes / 60.0)
        .toList();

    final staleInboxCount = links
        .where((link) =>
            link.status == LinkStatus.inbox &&
            now.difference(link.createdAt).inDays >= 7)
        .length;

    final curated =
        links.where((link) => link.status == LinkStatus.curated).toList();

    final curationDepth = curated.isEmpty
        ? 0.0
        : curated
                .map((link) {
                  final tagScore = link.tags.length;
                  final collectionScore = link.collectionId == null ? 0 : 1;
                  return tagScore + collectionScore;
                })
                .sum
                .toDouble() /
            curated.length;

    final opened = links.where((link) => link.openedCount > 0).toList();
    final reopened = opened.where((link) => link.openedCount > 1).toList();

    final reopenRate = opened.isEmpty ? 0.0 : reopened.length / opened.length;

    final sourceCounts = <String, int>{};
    for (final link in links) {
      final source = link.sourceDomain;
      if (source == null || source.isEmpty) continue;
      sourceCounts.update(source, (count) => count + 1, ifAbsent: () => 1);
    }

    final topSources = sourceCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final activeCollectionIds =
        curated.map((link) => link.collectionId).whereType<String>().toSet();

    final zeroActivityCollections = collections
        .where((collection) => !activeCollectionIds.contains(collection.id))
        .map((collection) => collection.name)
        .toList();

    return ProductivityInsights(
      inboxToOrganizedRate: inboxToOrganizedRate,
      medianCaptureToTriageHours: medianHours(captureToTriageHours),
      staleInboxCount: staleInboxCount,
      curationDepth: curationDepth,
      reopenRate: reopenRate,
      topSources: topSources.take(3).map((entry) => entry.key).toList(),
      zeroActivityCollections: zeroActivityCollections,
    );
  }
}
