import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/domain/campus_tool_presets.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/l10n/campus_tool_localizer.dart';
import 'package:university_timetable/models/campus_tool_entry.dart';

/// 标题本地化的契约：预设靠 id 反查 l10n。
///
/// 这条测试的存在理由：新增一个入口却忘了加 l10n 键时，界面不会报错，只会
/// 静默显示成「未命名入口」—— 那种降级必须在测试里炸出来。
void main() {
  final zh = lookupAppLocalizations(const Locale('zh'));
  final en = lookupAppLocalizations(const Locale('en'));

  test('每条入口在中文/英文里都有非空标题', () {
    for (final preset in kCampusToolPresets) {
      final zhTitle = campusToolPresetTitle(zh, preset.id);
      final enTitle = campusToolPresetTitle(en, preset.id);
      expect(zhTitle, isNotEmpty, reason: '${preset.id} 缺中文标题');
      expect(enTitle, isNotEmpty, reason: '${preset.id} 缺英文标题');
      expect(campusToolEntryTitle(zh, preset), zhTitle);
    }
  });

  test('分组标题与说明都不是空串', () {
    for (final l10n in <AppLocalizations>[zh, en]) {
      expect(l10n.campusToolsTitle, isNotEmpty);
      expect(l10n.campusToolsIntro, isNotEmpty);
      expect(l10n.campusToolsIdentitySectionTitle, isNotEmpty);
      expect(l10n.campusToolsIdentitySectionHint, isNotEmpty);
      expect(l10n.campusToolsIdentitySubtitle, isNotEmpty);
      expect(l10n.campusToolsParcelsSectionTitle, isNotEmpty);
      expect(l10n.campusToolsParcelsSectionHint, isNotEmpty);
      expect(l10n.campusToolsParcelsSubtitle, isNotEmpty);
      expect(l10n.campusToolsFooterHint, isNotEmpty);
    }
  });

  test('未知 id → 未命名入口（不返回空串）', () {
    const entry = CampusToolEntry(
      id: 'unknown-id',
      icon: 'link',
      links: <CampusToolLink>[],
    );
    expect(campusToolEntryTitle(zh, entry), zh.campusToolsUntitledEntry);
    expect(campusToolPresetTitle(zh, 'unknown-id'), isEmpty);
  });

  test('带占位符的文案按参数拼装', () {
    expect(
      zh.campusToolsLaunchFailed('菜鸟', '超时'),
      allOf(contains('菜鸟'), contains('超时')),
    );
    expect(zh.campusToolsOpenedAppToast('淘宝'), contains('淘宝'));
  });
}
