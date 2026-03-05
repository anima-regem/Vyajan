import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/link_item.dart';
import '../models/productivity_insights.dart';
import '../providers/app_providers.dart';

class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({
    super.key,
    required this.userId,
  });

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final linksAsync = ref.watch(allLinksProvider(userId));
    final collectionsAsync = ref.watch(collectionsProvider(userId));
    final preferencesAsync = ref.watch(userPreferencesProvider(userId));

    final loading = linksAsync.isLoading ||
        collectionsAsync.isLoading ||
        preferencesAsync.isLoading;

    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (linksAsync.hasError) {
      return Center(child: Text(linksAsync.error.toString()));
    }

    if (collectionsAsync.hasError) {
      return Center(child: Text(collectionsAsync.error.toString()));
    }

    if (preferencesAsync.hasError) {
      return Center(child: Text(preferencesAsync.error.toString()));
    }

    final preferences = preferencesAsync.value!;

    if (!preferences.insightsOptIn) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.insights_outlined, size: 56),
              const SizedBox(height: 12),
              Text(
                'Insights are off',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Turn on productivity insights to see triage quality and backlog health.',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () async {
                  await ref
                      .read(preferencesRepositoryProvider)
                      .patchPreferences(
                    userId,
                    {'insightsOptIn': true},
                  );
                  await ref
                      .read(analyticsServiceProvider)
                      .setInsightsConsent(true);
                },
                child: const Text('Enable insights'),
              ),
            ],
          ),
        ),
      );
    }

    final links = linksAsync.value!;
    final collections = collectionsAsync.value!;
    final insights =
        ref.watch(insightsServiceProvider).calculate(links, collections);

    final staleInboxLinks = links
        .where((link) =>
            link.status == LinkStatus.inbox &&
            DateTime.now().difference(link.createdAt).inDays >= 7)
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        _MetricGrid(insights: insights),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your inbox is aging',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  '${insights.staleInboxCount} links are older than 7 days in Inbox.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                FilledButton.tonal(
                  onPressed: staleInboxLinks.isEmpty
                      ? null
                      : () async {
                          final ids =
                              staleInboxLinks.map((link) => link.id).toList();
                          await ref
                              .read(linkRepositoryProvider)
                              .batchUpdateStatus(ids, LinkStatus.archived);
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content:
                                  Text('Archived ${ids.length} stale links.'),
                            ),
                          );
                        },
                  child: const Text('Archive stale inbox links'),
                )
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Top sources this week',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                if (insights.topSources.isEmpty)
                  Text(
                    'No source activity yet.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ...insights.topSources.map(
                  (source) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('• $source'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Collections with zero activity',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                if (insights.zeroActivityCollections.isEmpty)
                  Text(
                    'All collections have activity.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ...insights.zeroActivityCollections.map(
                  (name) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('• $name'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.insights});

  final ProductivityInsights insights;

  @override
  Widget build(BuildContext context) {
    final metrics = [
      (
        'Inbox -> Organized',
        '${(insights.inboxToOrganizedRate * 100).toStringAsFixed(1)}%',
      ),
      (
        'Median Capture -> Triage',
        '${insights.medianCaptureToTriageHours.toStringAsFixed(1)}h',
      ),
      (
        'Curation Depth',
        insights.curationDepth.toStringAsFixed(1),
      ),
      (
        'Reopen Rate',
        '${(insights.reopenRate * 100).toStringAsFixed(1)}%',
      ),
    ];

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: metrics.map((metric) {
        return SizedBox(
          width: (MediaQuery.of(context).size.width - 42) / 2,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    metric.$1,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    metric.$2,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
