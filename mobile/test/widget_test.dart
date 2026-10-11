import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bus_alarm/shared/widgets/status_badge.dart';
import 'package:bus_alarm/data/models/saved_link.dart';
import 'package:bus_alarm/data/models/local_geofence.dart';

void main() {
  testWidgets('StatusBadge displays correct label for online and offline', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              StatusBadge(label: 'ONLINE', variant: BadgeVariant.online),
              StatusBadge(label: 'OFFLINE', variant: BadgeVariant.offline),
            ],
          ),
        ),
      ),
    );

    expect(find.text('ONLINE'), findsOneWidget);
    expect(find.text('OFFLINE'), findsOneWidget);
  });

  test('SavedLink model serialization and copyWith', () {
    final now = DateTime.now();
    final link = SavedLink(
      id: 'link-123',
      shareUrl: 'https://mock.busalarm.local/location?token=xyz',
      nickname: 'College Route A',
      addedAtUtc: now,
      updatedAtUtc: now,
      isFavorite: true,
      lastKnownStatus: 'active',
    );

    final map = link.toMap();
    expect(map['id'], 'link-123');
    expect(map['nickname'], 'College Route A');
    expect(map['is_favorite'], 1);
    expect(map['last_known_status'], 'active');

    final restored = SavedLink.fromMap(map);
    expect(restored.id, 'link-123');
    expect(restored.nickname, 'College Route A');
    expect(restored.isFavorite, true);
    expect(restored.lastKnownStatus, 'active');
  });

  test('LocalGeofence model serialization', () {
    final now = DateTime.now();
    final fence = LocalGeofence(
      id: 'fence-1',
      linkedSavedLinkId: 'link-123',
      name: 'Main Gate',
      latitude: 12.9716,
      longitude: 77.5946,
      radiusMeters: 200,
      cooldownSeconds: 300,
      enabled: true,
      createdAtUtc: now,
      updatedAtUtc: now,
    );

    final map = fence.toMap();
    expect(map['name'], 'Main Gate');
    expect(map['radius_meters'], 200);

    final restored = LocalGeofence.fromMap(map);
    expect(restored.name, 'Main Gate');
    expect(restored.latitude, 12.9716);
    expect(restored.enabled, true);
  });
}
