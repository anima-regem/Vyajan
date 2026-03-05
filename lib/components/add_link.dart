import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_providers.dart';
import '../services/helpers.dart';
import '../services/local_enrichment_service.dart';

class QuickAddSheet extends ConsumerStatefulWidget {
  const QuickAddSheet({
    super.key,
    required this.userId,
  });

  final String userId;

  @override
  ConsumerState<QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends ConsumerState<QuickAddSheet> {
  final _urlController = TextEditingController();

  Timer? _debounce;
  String? _clipboardUrl;
  bool _isCheckingClipboard = true;
  bool _isSaving = false;
  bool _isEnriching = false;
  String _createdBy = 'manual';
  LocalEnrichmentResult? _preview;
  int _enrichVersion = 0;

  @override
  void initState() {
    super.initState();
    _urlController.addListener(_handleUrlChanged);
    _loadClipboard();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _urlController.removeListener(_handleUrlChanged);
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _loadClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted) return;

    final clipboardText = data?.text?.trim();
    setState(() {
      _clipboardUrl = isValidUrl(clipboardText ?? '') ? clipboardText : null;
      _isCheckingClipboard = false;
    });
  }

  void _handleUrlChanged() {
    _debounce?.cancel();
    final url = _urlController.text.trim();
    if (!isValidUrl(url)) {
      setState(() {
        _preview = null;
        _isEnriching = false;
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 350), () {
      _enrich(url);
    });
  }

  Future<void> _enrich(String url) async {
    final currentVersion = ++_enrichVersion;

    setState(() {
      _isEnriching = true;
    });

    try {
      final collections = await ref
          .read(collectionRepositoryProvider)
          .getCollections(widget.userId);
      final result = await ref.read(localEnrichmentServiceProvider).enrich(
            url: url,
            collections: collections,
          );

      if (!mounted || currentVersion != _enrichVersion) {
        return;
      }

      setState(() {
        _preview = result;
      });
    } finally {
      if (mounted && currentVersion == _enrichVersion) {
        setState(() {
          _isEnriching = false;
        });
      }
    }
  }

  Future<void> _save() async {
    final url = _urlController.text.trim();
    if (!isValidUrl(url) || _isSaving) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await ref.read(linkActionsServiceProvider).captureLink(
            userId: widget.userId,
            rawUrl: url,
            createdBy: _createdBy,
          );

      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved to inbox.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 8, 16, viewInsets + 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                height: 4,
                width: 40,
                decoration: BoxDecoration(
                  color: Theme.of(context).dividerColor,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Quick Add',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 6),
            Text(
              'Everything lands in Inbox first, then you curate.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _urlController,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                hintText: 'Paste a link',
                suffixIcon: IconButton(
                  onPressed: () async {
                    final data = await Clipboard.getData(Clipboard.kTextPlain);
                    final text = data?.text?.trim();
                    if (!mounted || text == null || text.isEmpty) return;
                    _urlController.text = text;
                    _createdBy = 'clipboard';
                  },
                  icon: const Icon(Icons.content_paste_rounded),
                ),
              ),
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 10),
            if (!_isCheckingClipboard &&
                _clipboardUrl != null &&
                _urlController.text.trim().isEmpty)
              ActionChip(
                avatar: const Icon(Icons.auto_awesome_rounded, size: 18),
                label: const Text('Use clipboard URL'),
                onPressed: () {
                  _urlController.text = _clipboardUrl!;
                  _createdBy = 'clipboard';
                },
              ).animate().fadeIn(duration: 280.ms).slideX(begin: 0.08),
            if (_isEnriching) ...[
              const SizedBox(height: 12),
              const _PreviewSkeleton(),
            ] else if (_preview != null) ...[
              const SizedBox(height: 12),
              _PreviewCard(preview: _preview!),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                TextButton(
                  onPressed:
                      _isSaving ? null : () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: _isSaving ? null : _save,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: const Text('Save to Inbox'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.preview});

  final LocalEnrichmentResult preview;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Theme.of(context).cardColor,
        border: Border.all(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.3)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            preview.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            preview.summary,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (preview.sourceDomain != null)
                Chip(
                  label: Text(preview.sourceDomain!),
                  visualDensity: VisualDensity.compact,
                ),
              ...preview.tags.take(4).map(
                    (tag) => Chip(
                      label: Text('#$tag'),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PreviewSkeleton extends StatelessWidget {
  const _PreviewSkeleton();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).dividerColor.withValues(alpha: 0.2);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Theme.of(context).cardColor,
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(height: 14, width: 180, color: color),
          const SizedBox(height: 8),
          Container(height: 12, width: double.infinity, color: color),
          const SizedBox(height: 6),
          Container(height: 12, width: 220, color: color),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(height: 26, width: 70, color: color),
              const SizedBox(width: 8),
              Container(height: 26, width: 60, color: color),
            ],
          ),
        ],
      ),
    ).animate(onPlay: (controller) => controller.repeat(reverse: true)).fade(
          begin: 0.5,
          end: 1,
          duration: 900.ms,
        );
  }
}
