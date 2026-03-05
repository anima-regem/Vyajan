import 'package:flutter_test/flutter_test.dart';
import 'package:vyajan/services/local_enrichment_service.dart';

void main() {
  late HeuristicLocalEnrichmentService service;

  setUp(() {
    service = HeuristicLocalEnrichmentService();
  });

  test('summarize clamps to concise form', () {
    final summary = service.summarize(
      title: 'A title',
      description:
          'This is a long description for a saved link. It should be collapsed into a short summary for quick scanning in the inbox.',
    );

    expect(summary.length <= 143, isTrue);
  });

  test('suggestTags infers domain and keywords', () {
    final tags = service.suggestTags(
      title: 'Building performant Flutter architecture for large apps',
      description: 'A deep dive into architecture and state management.',
      sourceDomain: 'github.com',
    );

    expect(tags, contains('dev'));
    expect(tags, contains('github'));
  });
}
