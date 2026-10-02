import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/models/time_scheme.dart';
import 'package:university_timetable/providers/timetable_provider.dart';

/// 空位（placeholder）与节次校验之间的冲突（回归钉，2026-10-02）。
///
/// 「按位补空」是这轮修复确立的口径：节次表按**位置下标**被 `Course.startSection`
/// 使用，所以坏条目必须补空位而不是删掉（删掉会让后面每一节指向相邻后一节的
/// 时间，用户按错时间去教室）。补出来的空位会真的存进课表（`SectionTime('', '')`，
/// 作息页渲染成 `-`）。
///
/// 但 `validateSectionTimes` 对每一项无条件调 `_clockMinutes`，而 `_clockMinutes('')`
/// 抛 `FormatException('invalid_time_format')` —— 于是**任何含空位的作息都存不进去**：
/// 外部 payload 走 `updateTimeScheme` 会让整个导入异常；作息管理页里含空位的表单一
/// 保存就报错（`time_scheme_management_screen.dart:1223`）。也就是说"按位补空"
/// 只在读取侧成立，写入侧被自己的校验挡死了。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const hole = SectionTime(startTime: '', endTime: '');

  Future<TimetableProvider> booted() async {
    SharedPreferences.setMockInitialValues({});
    final provider = TimetableProvider(
      autoInitialize: false,
      enableLiveActivitySync: false,
    );
    await provider.initialize();
    return provider;
  }

  test('validateSectionTimes 允许整条空位，但仍拒绝半空与越界', () {
    expect(
      validateSectionTimes(const [
        hole,
        SectionTime(startTime: '09:00', endTime: '09:45'),
      ]),
      isNull,
      reason: '空位是补出来的合法形状，必须能存',
    );

    // 半空说明这一格只填了一半，是真错误，不能当空位放过。
    expect(
      () => validateSectionTimes(const [
        SectionTime(startTime: '', endTime: '09:45'),
      ]),
      throwsFormatException,
    );

    // 全空等于没有可用的节次表。
    expect(
      validateSectionTimes(const [hole, hole]),
      'at_least_one_section_required',
    );

    // 顺序校验要跨过空位继续比：第 1、3 节之间有洞不影响 3 必须晚于 1。
    expect(
      validateSectionTimes(const [
        SectionTime(startTime: '08:00', endTime: '08:45'),
        hole,
        SectionTime(startTime: '08:30', endTime: '09:45'),
      ]),
      contains('section_start_before_previous_end'),
    );
  });

  test('含空位的作息可以创建、应用并原样读回', () async {
    final provider = await booted();
    addTearDown(provider.dispose);

    final scheme = await provider.createTimeScheme(
      name: '带洞作息',
      sections: const [
        SectionTime(startTime: '08:00', endTime: '08:45'),
        hole,
        SectionTime(startTime: '10:00', endTime: '10:45'),
      ],
    );

    final error = await provider.updateTimeScheme(
      schemeId: scheme.id,
      name: '带洞作息改后',
      sections: const [
        SectionTime(startTime: '08:00', endTime: '08:45'),
        hole,
        SectionTime(startTime: '11:00', endTime: '11:45'),
      ],
    );
    expect(error, isNull, reason: 'updateTimeScheme 不该因为空位而失败');

    // 出厂就带一个默认作息，所以按名字取而不是 single。
    final stored = provider.timeSchemes.firstWhere(
      (item) => item.id == scheme.id,
    );
    expect(stored.sections, hasLength(3));
    expect(stored.sections[1].startTime, isEmpty);
    expect(stored.sections[2].startTime, '11:00');

    // 落盘再读回：位置必须还是三个，第 3 节仍是 11:00（不被压缩成第 2 节）。
    final reopened = TimetableProvider(
      autoInitialize: false,
      enableLiveActivitySync: false,
    );
    addTearDown(reopened.dispose);
    await reopened.initialize();
    final restored = reopened.timeSchemes.firstWhere(
      (item) => item.id == scheme.id,
    );
    expect(restored.sections, hasLength(3));
    expect(restored.sections[2].startTime, '11:00');
  });

  test('空位不会被应用成生效节次表时丢掉位置', () async {
    final provider = await booted();
    addTearDown(provider.dispose);

    final scheme = await provider.createTimeScheme(
      name: '两节带洞',
      sections: const [
        hole,
        SectionTime(startTime: '09:00', endTime: '09:45'),
      ],
      applyToActiveProfile: true,
    );

    expect(provider.settings.sections, hasLength(2));
    expect(provider.settings.activeTimeSchemeId, scheme.id);
    expect(provider.settings.sections[1].startTime, '09:00');
    expect(
      TimetableSettings.fromJson(
        Map<String, dynamic>.from(provider.settings.toJson()),
      ).sections,
      hasLength(2),
    );
  });
}
