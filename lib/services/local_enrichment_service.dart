import 'package:metadata_fetch/metadata_fetch.dart';

import '../models/collection_item.dart';
import '../services/helpers.dart';

class LocalEnrichmentResult {
  const LocalEnrichmentResult({
    required this.title,
    required this.summary,
    required this.tags,
    required this.sourceDomain,
    this.image,
    this.siteName,
    this.suggestedCollectionId,
    this.description,
  });

  final String title;
  final String summary;
  final List<String> tags;
  final String? sourceDomain;
  final String? image;
  final String? siteName;
  final String? suggestedCollectionId;
  final String? description;
}

abstract class LocalEnrichmentService {
  Future<LocalEnrichmentResult> enrich({
    required String url,
    required List<CollectionItem> collections,
  });

  List<String> suggestTags({
    required String? title,
    required String? description,
    required String? sourceDomain,
  });

  String summarize({
    required String? title,
    required String? description,
  });

  String? suggestCollectionId({
    required List<CollectionItem> collections,
    required List<String> tags,
    required String? sourceDomain,
  });
}

class HeuristicLocalEnrichmentService implements LocalEnrichmentService {
  static const _stopWords = <String>{
    'a',
    'an',
    'and',
    'are',
    'as',
    'at',
    'be',
    'by',
    'for',
    'from',
    'in',
    'is',
    'it',
    'of',
    'on',
    'or',
    'that',
    'the',
    'to',
    'with'
  };

  static const _domainTagMap = <String, List<String>>{
    'youtube.com': ['video', 'watch'],
    'youtu.be': ['video', 'watch'],
    'github.com': ['dev', 'code'],
    'medium.com': ['article', 'reading'],
    'substack.com': ['newsletter', 'reading'],
    'linkedin.com': ['career', 'network'],
    'x.com': ['social'],
    'twitter.com': ['social'],
    'reddit.com': ['community'],
    'docs': ['reference'],
  };

  @override
  Future<LocalEnrichmentResult> enrich({
    required String url,
    required List<CollectionItem> collections,
  }) async {
    final metadata = await MetadataFetch.extract(url);
    final title = normalizeWhitespace(
      metadata?.title ?? extractSourceDomain(url) ?? 'Untitled Link',
    );
    final description = metadata?.description;
    final sourceDomain = extractSourceDomain(url);

    final tags = suggestTags(
      title: title,
      description: description,
      sourceDomain: sourceDomain,
    );

    final summary = summarize(title: title, description: description);

    final suggestedCollectionId = suggestCollectionId(
      collections: collections,
      tags: tags,
      sourceDomain: sourceDomain,
    );

    return LocalEnrichmentResult(
      title: title,
      summary: summary,
      tags: tags,
      sourceDomain: sourceDomain,
      image: metadata?.image,
      siteName: sourceDomain,
      suggestedCollectionId: suggestedCollectionId,
      description: description,
    );
  }

  @override
  List<String> suggestTags({
    required String? title,
    required String? description,
    required String? sourceDomain,
  }) {
    final inferred = <String>{};

    if (sourceDomain != null) {
      for (final entry in _domainTagMap.entries) {
        if (sourceDomain.contains(entry.key)) {
          inferred.addAll(entry.value);
        }
      }

      final hostParts = sourceDomain.split('.');
      if (hostParts.isNotEmpty) {
        inferred.add(hostParts.first);
      }
    }

    final text = '${title ?? ''} ${description ?? ''}'.toLowerCase();
    final words = text
        .split(RegExp(r'[^a-z0-9]+'))
        .where((word) => word.length > 3 && !_stopWords.contains(word));

    final frequencies = <String, int>{};
    for (final word in words) {
      frequencies.update(word, (count) => count + 1, ifAbsent: () => 1);
    }

    final topKeywords = frequencies.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    for (final entry in topKeywords.take(4)) {
      inferred.add(entry.key);
    }

    return inferred.take(6).toList();
  }

  @override
  String summarize({
    required String? title,
    required String? description,
  }) {
    final base = description?.trim().isNotEmpty == true ? description! : title;
    if (base == null || base.trim().isEmpty) {
      return 'Saved for later curation.';
    }

    final cleaned = normalizeWhitespace(base);

    final sentence = cleaned.split(RegExp(r'(?<=[.!?])\s+')).first;
    return summarizeToLength(sentence, maxChars: 140);
  }

  @override
  String? suggestCollectionId({
    required List<CollectionItem> collections,
    required List<String> tags,
    required String? sourceDomain,
  }) {
    if (collections.isEmpty) {
      return null;
    }

    String? winnerId;
    var bestScore = 0;

    for (final collection in collections) {
      final name = collection.name.toLowerCase();
      var score = 0;

      for (final tag in tags) {
        if (name.contains(tag.toLowerCase())) {
          score += 2;
        }
      }

      if (sourceDomain != null &&
          name.contains(sourceDomain.split('.').first)) {
        score += 2;
      }

      if (score > bestScore) {
        bestScore = score;
        winnerId = collection.id;
      }
    }

    return winnerId;
  }
}
