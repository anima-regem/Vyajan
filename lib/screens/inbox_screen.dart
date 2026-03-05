import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../components/curate_link_sheet.dart';
import '../components/thumbnail.dart';
import '../models/link_item.dart';
import '../providers/app_providers.dart';

class InboxScreen extends ConsumerWidget {
  const InboxScreen({
    super.key,
    required this.userId,
    required this.onAddLink,
  });

  final String userId;
  final VoidCallback onAddLink;

  Future<void> _openLink(
    BuildContext context,
    WidgetRef ref,
    LinkItem link,
  ) async {
    final uri = Uri.tryParse(link.url);
    if (uri == null) return;

    await launchUrl(uri, mode: LaunchMode.externalApplication);
    await ref.read(linkActionsServiceProvider).recordOpen(link);
  }

  Future<void> _openCurateSheet(
    BuildContext context,
    LinkItem link,
  ) async {
    await HapticFeedback.mediumImpact();
    if (!context.mounted) return;
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (_) => CurateLinkSheet(userId: userId, link: link),
    );
  }

  Future<void> _archiveWithUndo(
    BuildContext context,
    WidgetRef ref,
    LinkItem link,
  ) async {
    await HapticFeedback.mediumImpact();
    await ref.read(linkActionsServiceProvider).archiveLink(link);
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Archived.'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            ref.read(linkActionsServiceProvider).moveToInbox(link);
          },
        ),
      ),
    );
  }

  Future<void> _snooze(
    BuildContext context,
    WidgetRef ref,
    LinkItem link,
  ) async {
    final selected = await showModalBottomSheet<Duration>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.timer_outlined),
              title: const Text('Snooze 24 hours'),
              onTap: () => Navigator.of(context).pop(const Duration(hours: 24)),
            ),
            ListTile(
              leading: const Icon(Icons.calendar_today_outlined),
              title: const Text('Snooze 3 days'),
              onTap: () => Navigator.of(context).pop(const Duration(days: 3)),
            ),
            ListTile(
              leading: const Icon(Icons.weekend_outlined),
              title: const Text('Snooze 7 days'),
              onTap: () => Navigator.of(context).pop(const Duration(days: 7)),
            ),
          ],
        ),
      ),
    );

    if (selected == null) return;
    await HapticFeedback.selectionClick();
    await ref.read(linkActionsServiceProvider).snoozeLink(link, selected);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Link snoozed.')),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final linksAsync = ref.watch(inboxLinksProvider(userId));

    return linksAsync.when(
      data: (links) {
        if (links.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.inbox_rounded, size: 56),
                  const SizedBox(height: 12),
                  Text(
                    'Inbox is clear',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Save a link to start a fresh triage cycle.',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: onAddLink,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add link'),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          itemCount: links.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final link = links[index];
            return Dismissible(
              key: ValueKey(link.id),
              direction: DismissDirection.horizontal,
              background: Container(
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                alignment: Alignment.centerLeft,
                child: const Icon(Icons.check_circle_outline_rounded),
              ),
              secondaryBackground: Container(
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                alignment: Alignment.centerRight,
                child: const Icon(Icons.archive_outlined),
              ),
              confirmDismiss: (direction) async {
                if (direction == DismissDirection.startToEnd) {
                  await _openCurateSheet(context, link);
                  return false;
                }

                await _archiveWithUndo(context, ref, link);
                return true;
              },
              child: LinkPreviewCard(
                link: link,
                onTap: () => _openLink(context, ref, link),
                trailing: PopupMenuButton<String>(
                  icon: const Icon(Icons.more_horiz_rounded),
                  onSelected: (value) async {
                    if (value == 'curate') {
                      await _openCurateSheet(context, link);
                      return;
                    }
                    if (value == 'archive') {
                      await _archiveWithUndo(context, ref, link);
                      return;
                    }
                    if (value == 'snooze') {
                      await _snooze(context, ref, link);
                      return;
                    }
                    if (value == 'open') {
                      await _openLink(context, ref, link);
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'curate',
                      child: Text('Curate'),
                    ),
                    PopupMenuItem(
                      value: 'snooze',
                      child: Text('Snooze'),
                    ),
                    PopupMenuItem(
                      value: 'archive',
                      child: Text('Archive'),
                    ),
                    PopupMenuItem(
                      value: 'open',
                      child: Text('Open'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
      loading: () => ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        itemCount: 5,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, __) => const _InboxSkeleton(),
      ),
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(error.toString()),
        ),
      ),
    );
  }
}

class _InboxSkeleton extends StatelessWidget {
  const _InboxSkeleton();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).dividerColor.withValues(alpha: 0.2);

    return Container(
      height: 96,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          Container(
            height: 72,
            width: 72,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(height: 14, width: 180, color: color),
                const SizedBox(height: 8),
                Container(height: 12, width: 220, color: color),
              ],
            ),
          )
        ],
      ),
    );
  }
}
