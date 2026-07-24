import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/models/schedule_date_rule.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/providers/timetable_provider.dart';
import 'package:university_timetable/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    StorageService().resetForTesting();
    SharedPreferences.setMockInitialValues({});
  });

  Future<TimetableProvider> createProvider() async {
    final provider = TimetableProvider(
      autoInitialize: false,
      enableLiveActivitySync: false,
    );
    await provider.initialize();
    return provider;
  }

  String todayIso() => ScheduleDateRuleLogic.formatIsoDate(DateTime.now());

  List<SectionTime> shortSections({int count = 2}) {
    return List<SectionTime>.generate(
      count,
      (index) => SectionTime(
        startTime: '${(8 + index).toString().padLeft(2, '0')}:00',
        endTime: '${(8 + index).toString().padLeft(2, '0')}:45',
      ),
    );
  }

  test('enabling an already-applied rule notifies listeners', () async {
    final provider = await createProvider();

    final today = todayIso();
    final saveResult = await provider.createScheduleDateRule(
      name: '临时作息',
      timeSchemeId: provider.activeTimeScheme!.id,
      startDate: today,
      endDate: today,
      enabled: true,
    );
    final rule = saveResult.rule;
    await provider.updateScheduleDateRule(rule.copyWith(enabled: false));

    var notifications = 0;
    provider.addListener(() => notifications += 1);
    await provider.updateScheduleDateRule(rule.copyWith(enabled: true));

    expect(provider.scheduleDateRules.single.enabled, isTrue);
    expect(notifications, greaterThan(0));
  });

  test('applyDue returns notDue when no matching rule', () async {
    final provider = await createProvider();

    final detailed = await provider.applyDueScheduleDateRulesDetailed();
    final didApply = await provider.applyDueScheduleDateRules();

    expect(detailed.outcome, ScheduleDateRuleApplyOutcome.notDue);
    expect(detailed.didApply, isFalse);
    expect(detailed.failedWhileDue, isFalse);
    expect(didApply, isFalse);
  });

  test('applyDue returns applied then notDue after signature match', () async {
    final provider = await createProvider();
    final scheme = await provider.createTimeScheme(
      name: '夏令时模板',
      sections: shortSections(count: 4),
    );
    final today = todayIso();

    final saveResult = await provider.createScheduleDateRule(
      name: '今日切表',
      timeSchemeId: scheme.id,
      startDate: today,
      endDate: today,
      enabled: true,
    );

    expect(
      saveResult.applyResult.outcome,
      ScheduleDateRuleApplyOutcome.applied,
    );
    expect(saveResult.didApply, isTrue);
    expect(saveResult.failedWhileDue, isFalse);
    expect(provider.settings.activeTimeSchemeId, scheme.id);

    final secondDetailed = await provider.applyDueScheduleDateRulesDetailed();
    final secondBool = await provider.applyDueScheduleDateRules();

    expect(secondDetailed.outcome, ScheduleDateRuleApplyOutcome.notDue);
    expect(secondDetailed.didApply, isFalse);
    expect(secondBool, isFalse);
  });

  test(
    'applyDue returns schemeMissing when rule points at deleted scheme',
    () async {
      final provider = await createProvider();
      final today = todayIso();

      // Bypass createScheduleDateRule scheme check so we can stage a dangling id.
      await provider.replaceScheduleDateRules([
        ScheduleDateRule(
          id: 'orphan-rule',
          name: '孤儿规则',
          timeSchemeId: 'scheme-does-not-exist',
          startDate: today,
          endDate: today,
          enabled: true,
        ),
      ], resync: false);

      final detailed = await provider.applyDueScheduleDateRulesDetailed();
      final didApply = await provider.applyDueScheduleDateRules();

      expect(detailed.outcome, ScheduleDateRuleApplyOutcome.schemeMissing);
      expect(detailed.failedWhileDue, isTrue);
      expect(detailed.didApply, isFalse);
      // Bool facade must stay in lockstep with detailed (no path drift).
      expect(didApply, isFalse);
    },
  );

  test(
    'applyDue returns sectionOverflow when courses need more sections',
    () async {
      final provider = await createProvider();
      final shortScheme = await provider.createTimeScheme(
        name: '仅两节',
        sections: shortSections(count: 2),
      );

      await provider.addCourse(
        Course(
          id: 'long-course',
          name: '晚课',
          teacher: '李老师',
          location: 'B201',
          dayOfWeek: 1,
          startSection: 1,
          endSection: 4,
          startTime: '08:00',
          endTime: '11:30',
          startWeek: 1,
          endWeek: 16,
        ),
      );

      final today = todayIso();
      final saveResult = await provider.createScheduleDateRule(
        name: '节次不足',
        timeSchemeId: shortScheme.id,
        startDate: today,
        endDate: today,
        enabled: true,
      );

      expect(
        saveResult.applyResult.outcome,
        ScheduleDateRuleApplyOutcome.sectionOverflow,
      );
      expect(saveResult.failedWhileDue, isTrue);
      expect(saveResult.didApply, isFalse);
      expect(saveResult.applyResult.requiredMaxSection, 4);
      expect(saveResult.applyResult.schemeSectionCount, 2);

      // Rule must still be persisted even when apply fails while due.
      expect(provider.scheduleDateRules, hasLength(1));
      expect(provider.scheduleDateRules.single.name, '节次不足');

      final boolPath = await provider.applyDueScheduleDateRules();
      expect(boolPath, isFalse);
    },
  );

  test('ScheduleDateRuleSaveResult exposes applyResult getters', () async {
    final provider = await createProvider();
    final tomorrow = ScheduleDateRuleLogic.formatIsoDate(
      DateTime.now().add(const Duration(days: 1)),
    );
    final dayAfter = ScheduleDateRuleLogic.formatIsoDate(
      DateTime.now().add(const Duration(days: 2)),
    );

    final saveResult = await provider.createScheduleDateRule(
      name: '未来规则',
      timeSchemeId: provider.activeTimeScheme!.id,
      startDate: tomorrow,
      endDate: dayAfter,
      enabled: true,
    );

    expect(saveResult.applyResult.outcome, ScheduleDateRuleApplyOutcome.notDue);
    expect(saveResult.didApply, saveResult.applyResult.didApply);
    expect(saveResult.failedWhileDue, saveResult.applyResult.failedWhileDue);
    expect(saveResult.didApply, isFalse);
    expect(saveResult.failedWhileDue, isFalse);
  });
}
