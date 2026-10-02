import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/models/location_time_group.dart';
import 'package:university_timetable/models/schedule_date_rule.dart';
import 'package:university_timetable/models/schedule_item.dart';
import 'package:university_timetable/models/time_scheme.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/providers/timetable_provider.dart';
import 'package:university_timetable/services/storage_service.dart';
import 'package:university_timetable/services/transfer_package.dart';
import 'package:university_timetable/services/unified_transfer_service.dart';

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

  const customSections = [
    SectionTime(startTime: '08:00', endTime: '08:45'),
    SectionTime(startTime: '08:55', endTime: '09:40'),
  ];

  Course buildCourse(String timeSchemeId) {
    return Course(
      id: 'transferred-course',
      name: '跨设备课程',
      teacher: '张老师',
      location: 'A101',
      dayOfWeek: 1,
      startSection: 1,
      endSection: 2,
      startTime: '08:00',
      endTime: '09:40',
      timeSchemeIdOverride: timeSchemeId,
    );
  }

  test('scoped packages do not carry device settings', () async {
    final provider = await createProvider();
    await provider.updateTimetableSettings(
      provider.settings.copyWith(appLocaleTag: 'ja'),
    );
    final service = UnifiedTransferService();

    for (final scope in [
      TransferScope.selectedCourses,
      TransferScope.selectedCourse,
      TransferScope.weekTimetable,
      TransferScope.timeTemplate,
    ]) {
      final package = service.buildCurrentPackage(
        provider: provider,
        scope: scope,
      );
      expect(package.settings, isNull, reason: scope.value);
    }

    final current = service.buildCurrentPackage(provider: provider);
    expect(current.settings?.appLocaleTag, 'ja');
  });

  test('跨设备导入不得改写设备级更新信任锚', () async {
    // 回归钉（CODE_REVIEW 2026-10-01 A3）：appUpdateMirrorPreset /
    // appUpdateMirrorUrlPrefix 夹在 TimetableSettings 里，而 scope=currentTimetable
    // 的传输包允许携带 settings（TransferScope.carriesSettings）。于是局域网配对端
    // 一次 import/apply、一份被篡改的云快照，都能把机主的自动更新通道指向攻击者
    // 域名；而清单摘要与 APK 下载地址又同时出自那个域名，完整性校验变成自证。
    final provider = await createProvider();
    await provider.updateTimetableSettings(
      provider.settings.copyWith(
        appUpdateMirrorPreset: 'custom',
        appUpdateMirrorUrlPrefix: 'https://mirror.my-school.example',
      ),
    );

    final incoming = UnifiedTransferService()
        .buildCurrentPackage(
          provider: provider,
          // scope 默认即 currentTimetable（属于 carriesSettings），只显式给通道。
          channel: TransferChannel.lan,
        )
        .copyWith(
          settings: provider.settings.copyWith(
            appUpdateMirrorUrlPrefix: 'https://evil.example',
            appLocaleTag: 'en',
          ),
        );
    expect(
      incoming.settings?.appUpdateMirrorUrlPrefix,
      'https://evil.example',
      reason: '构造用例本身要成立：外来包里确实带着攻击者域名',
    );

    final result = await UnifiedTransferService().applyToProvider(
      provider: provider,
      incoming: incoming,
      mode: TransferApplyMode.overwrite,
    );

    expect(result.applied, isTrue, reason: result.error);
    // 信任锚保持本机值……
    expect(provider.settings.appUpdateMirrorPreset, 'custom');
    expect(
      provider.settings.appUpdateMirrorUrlPrefix,
      'https://mirror.my-school.example',
    );
    // ……而同包的普通设置照常应用，说明不是整份拒绝导入。
    expect(provider.settings.appLocaleTag, 'en');
  });

  test('merge ignores settings on a legacy scoped package', () async {
    final provider = await createProvider();
    final before = provider.settings.appLocaleTag;
    final incoming = TransferPackage(
      packageId: 'legacy-scoped-settings',
      scope: TransferScope.selectedCourses,
      settings: TimetableSettings.defaults().copyWith(appLocaleTag: 'ja'),
    );

    final result = await UnifiedTransferService().applyToProvider(
      provider: provider,
      incoming: incoming,
      mode: TransferApplyMode.merge,
    );

    expect(result.applied, isTrue, reason: result.error);
    expect(provider.settings.appLocaleTag, before);
  });

  test('merge maps a device-local scheme ID by section signature', () async {
    final provider = await createProvider();
    final localScheme = await provider.createTimeScheme(
      name: '目标设备模板',
      sections: customSections,
    );
    final sourceScheme = localScheme.copyWith(
      id: 'source-device-scheme',
      name: '源设备模板',
    );

    final incoming = TransferPackage(
      packageId: 'cross-device-signature-match',
      scope: TransferScope.currentTimetable,
      courses: [buildCourse(sourceScheme.id)],
      settings: TimetableSettings.defaults().copyWith(
        activeTimeSchemeId: sourceScheme.id,
        sections: sourceScheme.sections,
      ),
      timeSchemes: [sourceScheme],
      scheduleDateRules: const [
        ScheduleDateRule(
          id: 'source-rule',
          name: '源设备规则',
          timeSchemeId: 'source-device-scheme',
          startDate: '2026-09-01',
          endDate: '2026-09-07',
        ),
      ],
      locationTimeGroups: const [
        LocationTimeGroup(
          id: 'source-location-group',
          name: '源设备地点',
          timeSchemeId: 'source-device-scheme',
        ),
      ],
    );

    final result = await UnifiedTransferService().applyToProvider(
      provider: provider,
      incoming: incoming,
      mode: TransferApplyMode.merge,
    );

    expect(result.applied, isTrue, reason: result.error);
    expect(provider.courses.single.timeSchemeIdOverride, localScheme.id);
    expect(provider.settings.activeTimeSchemeId, localScheme.id);
    expect(provider.scheduleDateRules.single.timeSchemeId, localScheme.id);
    expect(provider.locationTimeGroups.single.timeSchemeId, localScheme.id);
    expect(
      provider.timeSchemes.where((scheme) => scheme.id == sourceScheme.id),
      isEmpty,
    );
    // 合并按"节次签名"认表（跨设备的 id 不是身份），但签名相同、名字不同的
    // 两张表是**两张表**：机主自己命名的那张不该被对端的叫法顶掉。
    // 课程/规则/地点分组都只是改指向，没有任何东西依赖这个名字，
    // 改名只会把本机别的课表档里同一张表的标题一起换掉。
    expect(
      provider.timeSchemes.firstWhere((scheme) => scheme.id == localScheme.id)
          .name,
      '目标设备模板',
      reason: '按签名复用本机作息时不得用外来的名字覆盖',
    );
  });

  test(
    'merge creates and remaps a scheme absent on the target device',
    () async {
      final provider = await createProvider();
      final sourceScheme = TimeScheme(
        id: 'source-only-scheme',
        name: '源设备专属模板',
        sections: const [
          SectionTime(startTime: '10:00', endTime: '10:45'),
          SectionTime(startTime: '10:55', endTime: '11:40'),
          SectionTime(startTime: '11:50', endTime: '12:35'),
        ],
        createdAt: DateTime(2026, 8),
        updatedAt: DateTime(2026, 8),
      );

      final incoming = TransferPackage(
        packageId: 'cross-device-new-scheme',
        scope: TransferScope.currentTimetable,
        courses: [buildCourse(sourceScheme.id)],
        settings: TimetableSettings.defaults().copyWith(
          activeTimeSchemeId: sourceScheme.id,
          sections: sourceScheme.sections,
        ),
        timeSchemes: [sourceScheme],
      );

      final result = await UnifiedTransferService().applyToProvider(
        provider: provider,
        incoming: incoming,
        mode: TransferApplyMode.merge,
      );

      expect(result.applied, isTrue, reason: result.error);
      final importedScheme = provider.timeSchemes.firstWhere(
        (scheme) => scheme.name == sourceScheme.name,
      );
      expect(importedScheme.id, isNot(sourceScheme.id));
      expect(provider.courses.single.timeSchemeIdOverride, importedScheme.id);
      expect(provider.settings.activeTimeSchemeId, importedScheme.id);
    },
  );

  test('overwrite maps foreign scheme IDs before legacy restore', () async {
    final provider = await createProvider();
    final sourceScheme = TimeScheme(
      id: 'source-overwrite-scheme',
      name: '覆盖导入作息',
      sections: const [
        SectionTime(startTime: '14:00', endTime: '14:45'),
        SectionTime(startTime: '14:55', endTime: '15:40'),
      ],
      createdAt: DateTime(2026, 8),
      updatedAt: DateTime(2026, 8),
    );
    final incoming = TransferPackage(
      packageId: 'cross-device-overwrite',
      scope: TransferScope.currentTimetable,
      courses: [buildCourse(sourceScheme.id)],
      settings: TimetableSettings.defaults().copyWith(
        activeTimeSchemeId: sourceScheme.id,
        sections: sourceScheme.sections,
      ),
      currentWeek: 1,
      timeSchemes: [sourceScheme],
    );

    final result = await UnifiedTransferService().applyToProvider(
      provider: provider,
      incoming: incoming,
      mode: TransferApplyMode.overwrite,
    );

    expect(result.applied, isTrue, reason: result.error);
    final importedScheme = provider.timeSchemes.firstWhere(
      (scheme) => scheme.name == sourceScheme.name,
    );
    expect(provider.courses.single.timeSchemeIdOverride, importedScheme.id);
    expect(provider.settings.activeTimeSchemeId, importedScheme.id);
  });

  test(
    'week package keeps only in-week records and referenced schemes',
    () async {
      final provider = await createProvider();
      // 所有日期锚在「本周一」，不写死 2026-09：createScheduleDateRule 会对
      // **区间覆盖今天**的那条规则立即批量套用作息，写死的 09-28~10-04 只有在不
      // 含今天时才无害 —— 2026-10-02 跑这条测试时，那条只有 1 节的「其他作息」
      // 被设成了生效作息，随后 addCourse(endSection: 2) 抛
      // time_scheme_sections_insufficient，等于「一年里有一周会红」。锚到今天之后
      // 两条规则的区间都在未来，批量套用不会触发，周次过滤仍然只认 currentWeek。
      final now = DateTime.now();
      final weekAnchor = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: now.weekday - 1));
      DateTime dayOf(int offset) =>
          DateTime(weekAnchor.year, weekAnchor.month, weekAnchor.day + offset);
      String textOf(int offset) {
        final date = dayOf(offset);
        return '${date.year.toString().padLeft(4, '0')}-'
            '${date.month.toString().padLeft(2, '0')}-'
            '${date.day.toString().padLeft(2, '0')}';
      }

      await provider.updateTimetableSettings(
        provider.settings.copyWith(
          semesterStartDate: dayOf(0),
          semesterWeekCount: 16,
        ),
      );
      await provider.setCurrentWeek(2);

      final inWeekScheme = await provider.createTimeScheme(
        name: '本周作息',
        sections: customSections,
      );
      final outOfWeekScheme = await provider.createTimeScheme(
        name: '其他作息',
        sections: const [SectionTime(startTime: '13:00', endTime: '13:45')],
      );
      final inWeekGroup = await provider.createLocationTimeGroup(
        name: '本周教学楼',
        timeSchemeId: inWeekScheme.id,
        keywords: const [LocationKeyword(pattern: 'A')],
      );
      final outOfWeekGroup = await provider.createLocationTimeGroup(
        name: '其他教学楼',
        timeSchemeId: outOfWeekScheme.id,
        keywords: const [LocationKeyword(pattern: 'B')],
      );
      final inWeekRule = await provider.createScheduleDateRule(
        name: '本周规则',
        timeSchemeId: inWeekScheme.id,
        startDate: textOf(7),
        endDate: textOf(13),
      );
      final outOfWeekRule = await provider.createScheduleDateRule(
        name: '其他规则',
        timeSchemeId: outOfWeekScheme.id,
        startDate: textOf(21),
        endDate: textOf(27),
      );
      final inWeekItem = ScheduleItem(
        id: 'in-week-item',
        title: '本周日程',
        startDate: dayOf(8),
        endDate: dayOf(8),
        startTime: '10:00',
        endTime: '11:00',
        createdAt: dayOf(0),
        updatedAt: dayOf(0),
      );
      final outOfWeekItem = inWeekItem.copyWith(
        id: 'out-of-week-item',
        title: '其他日程',
        startDate: dayOf(22),
        endDate: dayOf(22),
      );
      await provider.addScheduleItem(inWeekItem);
      await provider.addScheduleItem(outOfWeekItem);
      await provider.addCourse(
        Course(
          id: 'in-week-course',
          name: '本周课程',
          teacher: '张老师',
          location: 'A101',
          dayOfWeek: 1,
          startSection: 1,
          endSection: 2,
          startTime: '08:00',
          endTime: '09:40',
          startWeek: 2,
          endWeek: 2,
        ),
      );
      await provider.addCourse(
        Course(
          id: 'out-of-week-course',
          name: '其他课程',
          teacher: '李老师',
          location: 'B201',
          dayOfWeek: 1,
          startSection: 1,
          endSection: 1,
          startTime: '13:00',
          endTime: '13:45',
          startWeek: 4,
          endWeek: 4,
        ),
      );

      final package = UnifiedTransferService().buildCurrentPackage(
        provider: provider,
        scope: TransferScope.weekTimetable,
      );

      expect(package.courses.map((course) => course.id), ['in-week-course']);
      expect(package.scheduleItems.map((item) => item.id), ['in-week-item']);
      expect(package.scheduleDateRules.map((rule) => rule.id), [
        inWeekRule.rule.id,
      ]);
      expect(package.locationTimeGroups.map((group) => group.id), [
        inWeekGroup.id,
      ]);
      expect(
        package.timeSchemes.map((scheme) => scheme.id),
        contains(inWeekScheme.id),
      );
      expect(
        package.timeSchemes.map((scheme) => scheme.id),
        isNot(contains(outOfWeekScheme.id)),
      );
      expect(
        package.scheduleDateRules.map((rule) => rule.id),
        isNot(contains(outOfWeekRule.rule.id)),
      );
      expect(
        package.locationTimeGroups.map((group) => group.id),
        isNot(contains(outOfWeekGroup.id)),
      );
    },
  );

  test(
    'timeTemplate scope with selectedTimeSchemeIds keeps only the chosen scheme',
    () async {
      final provider = await createProvider();
      final morning = await provider.createTimeScheme(
        name: '夏季作息',
        sections: const [
          SectionTime(startTime: '08:00', endTime: '08:45'),
          SectionTime(startTime: '08:55', endTime: '09:40'),
        ],
      );
      final evening = await provider.createTimeScheme(
        name: '冬季作息',
        sections: const [SectionTime(startTime: '19:00', endTime: '19:45')],
      );
      await provider.addCourse(
        Course(
          id: 'shared-scheme-course',
          name: '跨设备课程',
          teacher: '张老师',
          location: 'A101',
          dayOfWeek: 1,
          startSection: 1,
          endSection: 1,
          startTime: '08:00',
          endTime: '08:45',
        ),
      );

      final package = UnifiedTransferService().buildCurrentPackage(
        provider: provider,
        scope: TransferScope.timeTemplate,
        selectedTimeSchemeIds: [morning.id],
      );

      expect(package.courses, isEmpty);
      expect(package.tasks, isEmpty);
      expect(package.exams, isEmpty);
      expect(package.settings, isNull);
      expect(package.currentWeek, isNull);
      expect(package.timeSchemes.map((scheme) => scheme.id), [morning.id]);
      expect(
        package.timeSchemes.map((scheme) => scheme.id),
        isNot(contains(evening.id)),
      );
    },
  );

  test(
    'timeTemplate scope without selection shares every time scheme',
    () async {
      final provider = await createProvider();
      final first = await provider.createTimeScheme(
        name: '模板一',
        sections: const [SectionTime(startTime: '09:00', endTime: '09:45')],
      );
      final second = await provider.createTimeScheme(
        name: '模板二',
        sections: const [SectionTime(startTime: '14:00', endTime: '14:45')],
      );

      final package = UnifiedTransferService().buildCurrentPackage(
        provider: provider,
        scope: TransferScope.timeTemplate,
      );

      expect(
        package.timeSchemes.map((scheme) => scheme.id),
        containsAll([first.id, second.id]),
      );
    },
  );
}
