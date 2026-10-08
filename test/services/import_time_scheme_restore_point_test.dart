import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/providers/timetable_provider.dart';
import 'package:university_timetable/services/import_time_scheme_restore_point.dart';
import 'package:university_timetable/services/storage_service.dart';

/// 教务导入**中止**时，被脚本换掉的作息必须切回去（2026-10-08）。
///
/// 适配器脚本下发的作息表在**课程写库之前**就被切成当前生效的那套
/// （`warehouse_adapter_web_login_screen` 的 `_applyImportedSections`），
/// 而中止路径有 8 条（用户取消、容量弹窗返回 false、学期映射取消、写盘抛错、
/// 中途 unmount …）。原先只补了「写盘失败」那一半（`095a372e`），中止这一半漏了：
/// 用户"什么都没干"，作息却被永久换成教务那套，重启后 `_ensureTimeSchemes`
/// 还会照着盘上那份把节次对齐进各课表。
///
/// 这里钉的是恢复动作本身的两条承诺：
/// 1. **连节次一起退**，不只是把 `activeTimeSchemeId` 切回去；
/// 2. 原本 `activeTimeSchemeId` 是什么就退回什么 —— 包括 `null`。这一条决定了
///    实现必须写回整份设置对象：`TimetableSettings.copyWith` 的参数是
///    `?? this.activeTimeSchemeId`，**清不掉**一个非 null 的 id。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TimetableProvider provider;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    provider = TimetableProvider(
      storageService: StorageService.forTesting(),
      autoInitialize: false,
      enableLiveActivitySync: false,
    );
    await provider.initialize();
  });

  tearDown(() => provider.dispose());

  const mineSections = [
    SectionTime(startTime: '08:00', endTime: '08:45'),
    SectionTime(startTime: '09:00', endTime: '09:45'),
  ];
  const schoolSections = [
    SectionTime(startTime: '07:30', endTime: '08:15'),
    SectionTime(startTime: '08:25', endTime: '09:10'),
    SectionTime(startTime: '19:00', endTime: '21:00'),
  ];

  test('中止后切回原来那套模板与节次', () async {
    final mine = await provider.createTimeScheme(
      name: '我的作息',
      sections: mineSections,
      applyToActiveProfile: true,
    );
    expect(provider.settings.activeTimeSchemeId, mine.id);

    final point = ImportTimeSchemeRestorePoint.capture(provider);

    // 脚本那一套：新建并切走（这正是 `_applyImportedSections` 干的事）。
    final school = await provider.createTimeScheme(
      name: '某大学作息',
      sections: schoolSections,
      applyToActiveProfile: true,
    );
    expect(provider.settings.activeTimeSchemeId, school.id);
    expect(provider.settings.sections, hasLength(schoolSections.length));

    await point.restore();

    expect(
      provider.settings.activeTimeSchemeId,
      mine.id,
      reason: '只退节次不退 id，用户仍被留在教务模板上',
    );
    expect(
      provider.settings.sections.map((section) => section.startTime).toList(),
      mineSections.map((section) => section.startTime).toList(),
    );
    // 教务那套模板本身留着没关系（用户可能还要用），但**不能**是当前生效的。
    expect(provider.timeSchemes.map((scheme) => scheme.id), contains(school.id));
  });

  test('捕获时是什么就退回什么（含 activeTimeSchemeId 为 null 的情形）', () async {
    // 不预设初始值：`initialize()` 之后可能已有一套默认模板，也可能是 null
    // （"没有启用任何模板、节次直接来自设置"）。两种都必须原样退回。
    final capturedId = provider.settings.activeTimeSchemeId;
    final capturedStarts = provider.settings.sections
        .map((section) => section.startTime)
        .toList();

    final point = ImportTimeSchemeRestorePoint.capture(provider);

    await provider.createTimeScheme(
      name: '某大学作息',
      sections: schoolSections,
      applyToActiveProfile: true,
    );
    expect(provider.settings.activeTimeSchemeId, isNotNull);

    await point.restore();

    expect(
      provider.settings.activeTimeSchemeId,
      capturedId,
      reason: '写回整份设置对象才对：copyWith 的 `?? this.x` 清不掉一个非 null 的 id，'
          '捕获到 null 的情形只能靠整份写回',
    );
    expect(
      provider.settings.sections.map((section) => section.startTime).toList(),
      capturedStarts,
    );
  });

  test('捕获时为 null（从没启用过模板）⇒ 必须清回 null', () async {
    // 造出「没有启用任何模板、节次直接来自设置」这一档：
    // `_normalizeSettingsWithTimeScheme` 在 activeTimeSchemeId 查不到模板时原样返回，
    // 所以这个状态能真的落进 provider。
    await provider.updateTimetableSettings(
      TimetableSettings.fromJson(<String, dynamic>{}),
    );
    expect(
      provider.settings.activeTimeSchemeId,
      isNull,
      reason: '前提检查：本条用例要的就是 activeTimeSchemeId 为 null 那一档',
    );
    final capturedStarts = provider.settings.sections
        .map((section) => section.startTime)
        .toList();

    final point = ImportTimeSchemeRestorePoint.capture(provider);

    await provider.createTimeScheme(
      name: '某大学作息',
      sections: schoolSections,
      applyToActiveProfile: true,
    );
    expect(provider.settings.activeTimeSchemeId, isNotNull);

    await point.restore();

    expect(
      provider.settings.activeTimeSchemeId,
      isNull,
      reason: '`copyWith` 的 `?? this.activeTimeSchemeId` 清不掉一个非 null 的 id，'
          '所以"只切回 id"的实现会把本来没有模板的用户永久留在一个教务模板上 —— '
          '只能整份设置写回',
    );
    expect(
      provider.settings.sections.map((section) => section.startTime).toList(),
      capturedStarts,
    );
  });
}
