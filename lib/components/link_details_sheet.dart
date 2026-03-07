import 'package:flutter/material.dart';

import '../models/link_item.dart';

class LinkDetailsSheet extends StatelessWidget {
  const LinkDetailsSheet({
    super.key,
    required this.link,
  });

  final LinkItem link;

  String? _firstNonEmpty(List<String?> values) {
    for (final value in values) {
      final trimmed = value?.trim();
      if (trimmed != null && trimmed.isNotEmpty) {
        return trimmed;
      }
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title =
        _firstNonEmpty([link.metadataTitle, link.title]) ?? 'Untitled link';
    final description =
        _firstNonEmpty([link.summary, link.metadataDescription]);

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.dividerColor,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text('Link details', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 14),
              Flexible(
                child: SingleChildScrollView(
                  child: SelectionArea(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: theme.textTheme.titleLarge),
                        const SizedBox(height: 8),
                        Text(
                          link.url,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text('Description', style: theme.textTheme.titleMedium),
                        const SizedBox(height: 6),
                        Text(
                          description ??
                              'No detailed description was found for this link.',
                          style: theme.textTheme.bodyMedium,
                        ),
                        if (link.tags.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Text('Tags', style: theme.textTheme.titleMedium),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: link.tags.map((tag) {
                              return Chip(label: Text('#$tag'));
                            }).toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> showLinkDetailsSheet(BuildContext context, LinkItem link) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    builder: (_) => LinkDetailsSheet(link: link),
  );
}
