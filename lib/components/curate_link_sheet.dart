import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/link_item.dart';
import '../providers/app_providers.dart';

class CurateLinkSheet extends ConsumerStatefulWidget {
  const CurateLinkSheet({
    super.key,
    required this.userId,
    required this.link,
  });

  final String userId;
  final LinkItem link;

  @override
  ConsumerState<CurateLinkSheet> createState() => _CurateLinkSheetState();
}

class _CurateLinkSheetState extends ConsumerState<CurateLinkSheet> {
  late final TextEditingController _summaryController;
  late final TextEditingController _tagsController;
  String? _collectionId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _summaryController = TextEditingController(text: widget.link.summary ?? '');
    _tagsController = TextEditingController(text: widget.link.tags.join(', '));
    _collectionId = widget.link.collectionId;
  }

  @override
  void dispose() {
    _summaryController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  List<String> _parseTags(String raw) {
    return raw
        .split(',')
        .map((tag) => tag.trim().toLowerCase())
        .where((tag) => tag.isNotEmpty)
        .toSet()
        .toList();
  }

  Future<void> _save() async {
    if (_saving) return;

    setState(() {
      _saving = true;
    });

    try {
      await ref.read(linkActionsServiceProvider).curateLink(
            link: widget.link,
            tags: _parseTags(_tagsController.text),
            collectionId: _collectionId,
            summary: _summaryController.text.trim(),
          );
      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Link curated.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final collectionsAsync = ref.watch(collectionsProvider(widget.userId));
    final insets = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 8, 16, insets + 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).dividerColor,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text('Curate Link',
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 12),
            TextField(
              controller: _summaryController,
              minLines: 2,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Summary',
                hintText: 'Short note about why this matters',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _tagsController,
              decoration: const InputDecoration(
                labelText: 'Tags',
                hintText: 'design, product, reading',
              ),
            ),
            const SizedBox(height: 12),
            collectionsAsync.when(
              data: (collections) => DropdownButtonFormField<String?>(
                initialValue: _collectionId,
                decoration: const InputDecoration(labelText: 'Collection'),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('No collection'),
                  ),
                  ...collections.map((collection) {
                    return DropdownMenuItem<String?>(
                      value: collection.id,
                      child: Text(collection.name),
                    );
                  }),
                ],
                onChanged: (value) {
                  setState(() {
                    _collectionId = value;
                  });
                },
              ),
              loading: () => const LinearProgressIndicator(minHeight: 2),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                TextButton(
                  onPressed:
                      _saving ? null : () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_rounded),
                  label: const Text('Curate'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
