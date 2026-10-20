import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/domain/campus_tool_presets.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/l10n/campus_tool_localizer.dart';
import 'package:university_timetable/models/campus_tool_entry.dart';

/// 标题本地化的契约：预设靠 id 反查 l10n，自建项靠用户标题。
///
/// 这条测试的存在理由：新增一个预置项却忘了加 l10n 键时，界面不会报错，
/// 只会显示成「未命名入口」—— 那种静默降级必须在测试里炸出来。
void main() {
  final zh = lookupAppLocalizations(const Locale('zh'));
  final en = lookupAppLocalizations(const Locale('en'));

  test('每个预置 id 在中文/英文里都有非空标题', () {
    for (final preset in kCampusToolPresets) {
      final zhTitle = campusToolPresetTitle(zh, preset.id);
      final enTitle = campusToolPresetTitle(en, preset.id);
      expect(zhTitle, isNotEmpty, reason: '${preset.id} 缺中文标题');
      expect(enTitle, isNotEmpty, reason: '${preset.id} 缺英文标题');
      expect(
        campusToolEntryTitle(zh, preset),
        zhTitle,
        reason: 'title 为空的预设应显示 l10n 标题',
      );
    }
  });

  test('用户改过标题时优先生效，预设标题不再覆盖它', () {
    final renamed = kCampusToolPresets.first.copyWith(title: '我的名字');
    expect(campusToolEntryTitle(zh, renamed), '我的名字');
  });

  test('未知 id 且没有标题 → 未命名入口（不返回空串）', () {
    const entry = CampusToolEntry(id: 'unknown-id');
    expect(campusToolEntryTitle(zh, entry), zh.campusToolsUntitledEntry);
    expect(campusToolPresetTitle(zh, 'unknown-id'), isEmpty);
  });

  test('带占位符的文案按参数拼装', () {
    expect(
      zh.campusToolsTargetCount(3),
      contains('3'),
    );
    expect(
      zh.campusToolsLaunchFailed('菜鸟', '超时'),
      allOf(contains('菜鸟'), contains('超时')),
    );
  });
}
