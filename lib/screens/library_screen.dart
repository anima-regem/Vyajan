import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../components/thumbnail.dart';
import '../models/collection_item.dart';
import '../models/link_item.dart';
import '../providers/app_providers.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({
    super.key,
    required this.userId,
    required this.onAddLink,
  });

  final String userId;
  final VoidCallback onAddLink;

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  final _searchController = TextEditingController();
  final Set<String> _selectedIds = <String>{};

  bool _batchMode = false;
  String? _tagFilter;
  String? _sourceFilter;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleSelection(String linkId) {
    setState(() {
      if (_selectedIds.contains(linkId)) {
        _selectedIds.remove(linkId);
      } else {
        _selectedIds.add(linkId);
      }

      if (_selectedIds.isEmpty) {
        _batchMode = false;
      }
    });
  }

  Future<void> _openLink(LinkItem link) async {
    final uri = Uri.tryParse(link.url);
    if (uri == null) return;

    await launchUrl(uri, mode: LaunchMode.externalApplication);
    await ref.read(linkActionsServiceProvider).recordOpen(link);
  }

  Future<void> _batchArchive() async {
    final count = _selectedIds.length;
    await ref
        .read(linkActionsServiceProvider)
        .batchArchive(_selectedIds.toList());

    if (!mounted) return;
    setState(() {
      _selectedIds.clear();
      _batchMode = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Archived $count selected links.')),
    );
  }

  Future<void> _assignCollection(
    List<LinkItem> links,
    List<CollectionItem> collections,
  ) async {
    if (_selectedIds.isEmpty) return;

    final selected = await showModalBottomSheet<String?>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(
                title: Text('Assign collection'),
              ),
              ListTile(
                title: const Text('No collection'),
                onTap: () => Navigator.pop(context, ''),
              ),
              ...collections.map((collection) {
                return ListTile(
                  title: Text(collection.name),
                  onTap: () => Navigator.pop(context, collection.id),
                );
              }),
            ],
          ),
        );
      },
    );

    if (selected == null) return;

    final linkRepository = ref.read(linkRepositoryProvider);

    for (final link in links.where((item) => _selectedIds.contains(item.id))) {
      await linkRepository.patchLink(link.id, {
        'collectionId': selected.isEmpty ? null : selected,
      });
    }

    if (!mounted) return;

    setState(() {
      _selectedIds.clear();
      _batchMode = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Collection assignment updated.')),
    );
  }

  Future<void> _addTagToSelected(List<LinkItem> links) async {
    final controller = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add tag'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: 'Enter tag'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Apply'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    final tag = controller.text.trim().toLowerCase();
    if (tag.isEmpty) return;

    final linkRepository = ref.read(linkRepositoryProvider);

    for (final link in links.where((item) => _selectedIds.contains(item.id))) {
      final tags = {...link.tags, tag}.toList();
      await linkRepository.patchLink(link.id, {'tags': tags});
    }

    if (!mounted) return;

    setState(() {
      _selectedIds.clear();
      _batchMode = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Tag applied to selected links.')),
    );
  }

  List<LinkItem> _filteredLinks(List<LinkItem> links) {
    final query = _searchController.text.trim().toLowerCase();

    return links.where((link) {
      if (_tagFilter != null && !link.tags.contains(_tagFilter)) {
        return false;
      }

      if (_sourceFilter != null && link.sourceDomain != _sourceFilter) {
        return false;
      }

      if (query.isEmpty) return true;

      final text = [
        link.title,
        link.metadataTitle,
        link.summary,
        link.url,
        link.tags.join(' '),
      ].whereType<String>().join(' ').toLowerCase();

      return text.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final curatedAsync = ref.watch(curatedLinksProvider(widget.userId));
    final collectionsAsync = ref.watch(collectionsProvider(widget.userId));

    return curatedAsync.when(
      data: (links) {
        final filtered = _filteredLinks(links);
        final sources = links
            .map((link) => link.sourceDomain)
            .whereType<String>()
            .toSet()
            .toList()
          ..sort();
        final tags = links.expand((link) => link.tags).toSet().toList()..sort();

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search curated links',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            setState(() {
                              _searchController.clear();
                            });
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            if (sources.isNotEmpty || tags.isNotEmpty)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(
                  children: [
                    FilterChip(
                      label: const Text('All'),
                      selected: _sourceFilter == null && _tagFilter == null,
                      onSelected: (_) {
                        setState(() {
                          _sourceFilter = null;
                          _tagFilter = null;
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    ...sources.take(6).map((source) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(source),
                          selected: _sourceFilter == source,
                          onSelected: (_) {
                            setState(() {
                              _sourceFilter =
                                  _sourceFilter == source ? null : source;
                            });
                          },
                        ),
                      );
                    }),
                    ...tags.take(6).map((tag) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text('#$tag'),
                          selected: _tagFilter == tag,
                          onSelected: (_) {
                            setState(() {
                              _tagFilter = _tagFilter == tag ? null : tag;
                            });
                          },
                        ),
                      );
                    }),
                  ],
                ),
              ),
            if (_batchMode)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: Theme.of(context)
                          .dividerColor
                          .withValues(alpha: 0.35)),
                ),
                child: Row(
                  children: [
                    Text('${_selectedIds.length} selected'),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Add tag',
                      onPressed: () => _addTagToSelected(filtered),
                      icon: const Icon(Icons.sell_outlined),
                    ),
                    IconButton(
                      tooltip: 'Assign collection',
                      onPressed: () {
                        collectionsAsync.whenData(
                          (collections) =>
                              _assignCollection(filtered, collections),
                        );
                      },
                      icon: const Icon(Icons.collections_bookmark_outlined),
                    ),
                    IconButton(
                      tooltip: 'Archive',
                      onPressed: _batchArchive,
                      icon: const Icon(Icons.archive_outlined),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () {
                        setState(() {
                          _batchMode = false;
                          _selectedIds.clear();
                        });
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.library_books_outlined, size: 56),
                            const SizedBox(height: 12),
                            Text(
                              'No curated links yet',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Curate from Inbox to build your long-term library.',
                              style: Theme.of(context).textTheme.bodyMedium,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            FilledButton.tonalIcon(
                              onPressed: widget.onAddLink,
                              icon: const Icon(Icons.add_rounded),
                              label: const Text('Add link'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final link = filtered[index];
                        final selected = _selectedIds.contains(link.id);

                        return LinkPreviewCard(
                          link: link,
                          selected: selected,
                          onTap: () {
                            if (_batchMode) {
                              _toggleSelection(link.id);
                              return;
                            }
                            _openLink(link);
                          },
                          onLongPress: () async {
                            await HapticFeedback.selectionClick();
                            setState(() {
                              _batchMode = true;
                            });
                            _toggleSelection(link.id);
                          },
                          trailing: _batchMode
                              ? Checkbox(
                                  value: selected,
                                  onChanged: (_) => _toggleSelection(link.id),
                                )
                              : PopupMenuButton<String>(
                                  onSelected: (value) async {
                                    if (value == 'archive') {
                                      await ref
                                          .read(linkActionsServiceProvider)
                                          .archiveLink(link);
                                    } else if (value == 'inbox') {
                                      await ref
                                          .read(linkActionsServiceProvider)
                                          .moveToInbox(link);
                                    } else if (value == 'open') {
                                      await _openLink(link);
                                    }
                                  },
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(
                                      value: 'open',
                                      child: Text('Open'),
                                    ),
                                    PopupMenuItem(
                                      value: 'inbox',
                                      child: Text('Move to Inbox'),
                                    ),
                                    PopupMenuItem(
                                      value: 'archive',
                                      child: Text('Archive'),
                                    ),
                                  ],
                                ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text(error.toString())),
    );
  }
}
