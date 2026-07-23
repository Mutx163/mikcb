import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/services/fair_memory_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  PageRoute<void> route(String name) {
    return PageRouteBuilder<void>(
      settings: RouteSettings(name: name),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
    );
  }

  test('route observer snapshots active routes in stack order', () {
    final observer = FairMemoryRouteObserver();
    final home = route('/');
    final settings = route('/settings');
    final memory = route('/settings/memory-stats');

    observer.didPush(home, null);
    observer.didPush(settings, home);
    observer.didPush(memory, settings);
    expect(observer.snapshot, <String>[
      '/',
      '/settings',
      '/settings/memory-stats',
    ]);

    observer.didRemove(settings, home);
    expect(observer.snapshot, <String>['/', '/settings/memory-stats']);

    observer.didPop(memory, home);
    expect(observer.snapshot, <String>['/']);
  });

  test('route observer replaces the matching route', () {
    final observer = FairMemoryRouteObserver();
    final oldRoute = route('/old');
    final newRoute = route('/new');

    observer.didPush(oldRoute, null);
    observer.didReplace(newRoute: newRoute, oldRoute: oldRoute);

    expect(observer.snapshot, <String>['/new']);
  });

  test('kill recovery snapshot persists protocol and business state', () async {
    final service = FairMemoryService.instance;
    service.registerSnapshotProvider(() async {
      return <String, Object?>{
        'activeProfileId': 'profile-a',
        'currentWeek': 7,
      };
    });

    await service.persistRecoverySnapshotForTesting(<String, dynamic>{
      'action': 'KILL',
      'notifyType': 1000,
      'notifyId': 42,
      'reason': 'pss_limit',
    });

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('fair_memory_recovery_snapshot_v1');
    final snapshot = jsonDecode(raw!) as Map<String, dynamic>;

    expect(snapshot['version'], 1);
    expect(snapshot['action'], 'KILL');
    expect(snapshot['notifyType'], 1000);
    expect(snapshot['notifyId'], 42);
    expect(snapshot['reason'], 'pss_limit');
    expect(snapshot['businessState'], <String, dynamic>{
      'activeProfileId': 'profile-a',
      'currentWeek': 7,
    });

    final pending = await service.takePendingRecoverySnapshot();
    expect(pending, isNotNull);
    expect(pending!.lastNamedRoute, isNull);
    expect(pending.businessState['activeProfileId'], 'profile-a');
    expect(prefs.getString('fair_memory_recovery_snapshot_v1'), isNull);
  });

  test('stale recovery snapshot is consumed without being restored', () async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime(2026, 7, 23, 12);
    await prefs.setString(
      'fair_memory_recovery_snapshot_v1',
      jsonEncode(<String, Object?>{
        'version': 1,
        'savedAtMillis': now
            .subtract(const Duration(days: 2))
            .millisecondsSinceEpoch,
        'routes': <String>['/', '/settings'],
        'businessState': const <String, Object?>{},
      }),
    );

    final pending = await FairMemoryService.instance
        .takePendingRecoverySnapshot(now: now);

    expect(pending, isNull);
    expect(prefs.getString('fair_memory_recovery_snapshot_v1'), isNull);
  });
}
