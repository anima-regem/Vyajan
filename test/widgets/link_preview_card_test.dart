import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vyajan/components/thumbnail.dart';
import 'package:vyajan/models/link_item.dart';

void main() {
  testWidgets('renders link preview metadata and tags', (tester) async {
    final link = LinkItem(
      id: 'id',
      userId: 'u1',
      url: 'https://example.com',
      title: 'Example title',
      status: LinkStatus.inbox,
      createdAt: DateTime.now(),
      tags: const ['read', 'design'],
      summary: 'A short summary',
      sourceDomain: 'example.com',
      openedCount: 0,
      createdBy: 'manual',
      schemaVersion: 2,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LinkPreviewCard(
            link: link,
            onTap: () {},
          ),
        ),
      ),
    );

    expect(find.text('Example title'), findsOneWidget);
    expect(find.textContaining('#read'), findsOneWidget);
    expect(find.text('Inbox'), findsOneWidget);
  });
}
