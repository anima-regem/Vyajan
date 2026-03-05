import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vyajan/models/link_item.dart';

void main() {
  group('LinkItem.fromMap', () {
    test('maps legacy archived link to archived status', () {
      final link = LinkItem.fromMap(
        {
          'userId': 'u1',
          'url': 'https://example.com',
          'title': 'Example',
          'isArchived': true,
          'isPermanent': false,
          'createdAt': Timestamp.now(),
        },
        'id-1',
      );

      expect(link.status, LinkStatus.archived);
    });

    test('maps legacy permanent link to curated status', () {
      final link = LinkItem.fromMap(
        {
          'userId': 'u1',
          'url': 'https://example.com',
          'title': 'Example',
          'isArchived': false,
          'isPermanent': true,
          'createdAt': Timestamp.now(),
        },
        'id-2',
      );

      expect(link.status, LinkStatus.curated);
    });

    test('keeps explicit status when present', () {
      final link = LinkItem.fromMap(
        {
          'userId': 'u1',
          'url': 'https://example.com',
          'title': 'Example',
          'status': 'snoozed',
          'createdAt': Timestamp.now(),
        },
        'id-3',
      );

      expect(link.status, LinkStatus.snoozed);
    });
  });
}
