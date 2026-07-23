import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/providers/timetable_provider.dart';
import 'package:university_timetable/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    StorageService().resetForTesting();
    SharedPreferences.setMockInitialValues({});
  });

  test('enabling an already-applied rule notifies listeners', () async {
    final provider = TimetableProvider(
      autoInitialize: false,
      enableLiveActivitySync: false,
    );
    await provider.initialize();

    final today = ScheduleDateRuleLogic.formatIsoDate(DateTime.now());
    final rule = await provider.createScheduleDateRule(
      name: '临时作息',
      timeSchemeId: provider.activeTimeScheme!.id,
      startDate: today,
      endDate: today,
      enabled: true,
    );
    await provider.updateScheduleDateRule(rule.copyWith(enabled: false));

    var notifications = 0;
    provider.addListener(() => notifications += 1);
    await provider.updateScheduleDateRule(rule.copyWith(enabled: true));

    expect(provider.scheduleDateRules.single.enabled, isTrue);
    expect(notifications, greaterThan(0));
  });
}
