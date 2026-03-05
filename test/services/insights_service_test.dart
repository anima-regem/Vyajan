import 'package:flutter_test/flutter_test.dart';
import 'package:vyajan/models/collection_item.dart';
import 'package:vyajan/models/link_item.dart';
import 'package:vyajan/services/insights_service.dart';

void main() {
  test('calculates inbox-to-organized and stale count', () {
    final service = LocalInsightsService();
    final now = DateTime.now();

    final links = [
      LinkItem(
        id: '1',
        userId: 'u1',
        url: 'https://a.com',
        title: 'A',
        status: LinkStatus.inbox,
        createdAt: now.subtract(const Duration(days: 2)),
        tags: const [],
        openedCount: 0,
        createdBy: 'manual',
        schemaVersion: 2,
      ),
      LinkItem(
        id: '2',
        userId: 'u1',
        url: 'https://b.com',
        title: 'B',
        status: LinkStatus.curated,
        createdAt: now.subtract(const Duration(days: 1)),
        triagedAt: now,
        tags: const ['read'],
        openedCount: 2,
        createdBy: 'manual',
        schemaVersion: 2,
      ),
      LinkItem(
        id: '3',
        userId: 'u1',
        url: 'https://c.com',
        title: 'C',
        status: LinkStatus.inbox,
        createdAt: now.subtract(const Duration(days: 9)),
        tags: const [],
        openedCount: 0,
        createdBy: 'manual',
        schemaVersion: 2,
      ),
    ];

    final collections = [
      CollectionItem(
        id: 'col-1',
        userId: 'u1',
        name: 'Reading',
        colorHex: '#2E6B4C',
        iconKey: 'folder',
        createdAt: now,
        updatedAt: now,
      )
    ];

    final insights = service.calculate(links, collections);

    expect(insights.inboxToOrganizedRate, closeTo(1 / 2, 0.001));
    expect(insights.staleInboxCount, 1);
    expect(insights.reopenRate, 1);
  });
}
