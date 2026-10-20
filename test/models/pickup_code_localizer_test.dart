import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/domain/pickup_code_presets.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/l10n/pickup_code_localizer.dart';
import 'package:university_timetable/models/pickup_code_entry.dart';

/// 标题本地化的契约：预设靠 id 反查 l10n。
///
/// 这条测试的存在理由：新增一个入口却忘了加 l10n 键时，界面不会报错，只会
/// 静默显示成「未命名入口」—— 那种降级必须在测试里炸出来。
void main() {
  final zh = lookupAppLocalizations(const Locale('zh'));
  final en = lookupAppLocalizations(const Locale('en'));

  test('每条入口在中文/英文里都有非空标题', () {
    for (final preset in kPickupCodePresets) {
      final zhTitle = pickupCodePresetTitle(zh, preset.id);
      final enTitle = pickupCodePresetTitle(en, preset.id);
      expect(zhTitle, isNotEmpty, reason: '${preset.id} 缺中文标题');
      expect(enTitle, isNotEmpty, reason: '${preset.id} 缺英文标题');
      expect(pickupCodeEntryTitle(zh, preset), zhTitle);
    }
  });

  test('砖上只写平台名，不重复「身份码/待取快递」', () {
    // 分组标题已经说明这一组干什么；砖上再写一遍就是同一句话两处出现。
    for (final preset in kPickupCodePresets) {
      final title = pickupCodePresetTitle(zh, preset.id);
      expect(
        title.contains('身份码') || title.contains('待取') || title.contains('快递'),
        isFalse,
        reason: '${preset.id} 的砖标题「$title」与分组标题重复',
      );
      // 两个字的平台名才够短，能一行放下。
      expect(
        title.characters.length,
        lessThanOrEqualTo(4),
        reason: '${preset.id} 的砖标题「$title」太长，方格会截断',
      );
    }
  });

  test('同一个平台的身份码与待取快递用同一个平台名', () {
    // 菜鸟只出现在身份码组；淘宝/拼多多两组都有 —— 两组里的同平台名字必须一致，
    // 否则用户会以为是两个不同的东西。
    final byName = <String, Set<String>>{};
    for (final preset in kPickupCodePresets) {
      final name = pickupCodePresetTitle(zh, preset.id);
      byName.putIfAbsent(name, () => <String>{}).add(preset.id);
    }
    for (final entry in byName.entries) {
      if (entry.value.length > 1) {
        // 同名多条：必须是一条身份码 + 一条待取，不能两个都是身份码。
        final icons = <String>{
          for (final preset in kPickupCodePresets)
            if (entry.value.contains(preset.id))
              preset.icon,
        };
        expect(
          icons.length,
          entry.value.length,
          reason: '「${entry.key}」的多条入口功能重复了：${entry.value}',
        );
      }
    }
  });

  test('页面只保留分组标题与操作类文案，说明性灰字已删', () {
    for (final l10n in <AppLocalizations>[zh, en]) {
      // 留下的：两个分组标题 + 标题 + 失败原因 + 保存失败提示
      expect(l10n.pickupCodeTitle, isNotEmpty);
      expect(l10n.pickupCodeIdentitySectionTitle, isNotEmpty);
      expect(l10n.pickupCodeParcelsSectionTitle, isNotEmpty);
      expect(l10n.pickupCodeUntitledEntry, isNotEmpty);
    }
    // 删掉的：这些键已经不存在了（保留断言防止有人又把它们加回来）
    expect(
      () => (zh as dynamic).pickupCodeIntro,
      throwsNoSuchMethodError,
      reason: '「把取件身份码…收成一排」这类说明文字应当已删除',
    );
    expect(
      () => (zh as dynamic).pickupCodeIdentitySubtitle,
      throwsNoSuchMethodError,
      reason: '砖上的副标题应当已删除（与分组标题重复）',
    );
    expect(
      () => (zh as dynamic).pickupCodeFooterHint,
      throwsNoSuchMethodError,
      reason: '底部说明应当已删除（给开发者看的）',
    );
  });

  test('未知 id → 未命名入口（不返回空串）', () {
    const entry = PickupCodeEntry(
      id: 'unknown-id',
      icon: 'link',
      links: <PickupCodeLink>[],
    );
    expect(pickupCodeEntryTitle(zh, entry), zh.pickupCodeUntitledEntry);
    expect(pickupCodePresetTitle(zh, 'unknown-id'), isEmpty);
  });

  test('带占位符的文案按参数拼装', () {
    expect(
      zh.pickupCodeLaunchFailed('菜鸟', '超时'),
      allOf(contains('菜鸟'), contains('超时')),
    );
    expect(zh.pickupCodeOpenedAppToast('淘宝'), contains('淘宝'));
  });

  test('每条预置的 hint 在中/英文里都解析成非空说明', () {
    for (final preset in kPickupCodePresets) {
      final zhHint = pickupCodeEntryHint(zh, preset);
      final enHint = pickupCodeEntryHint(en, preset);
      expect(zhHint, isNotEmpty, reason: '${preset.id} 缺中文 hint');
      expect(enHint, isNotEmpty, reason: '${preset.id} 缺英文 hint');
    }
  });

  test('未知 hint 键返回空串（界面据此不渲染说明行）', () {
    final unknown = PickupCodeEntry(
      id: kPickupCodePresets.first.id,
      icon: kPickupCodePresets.first.icon,
      links: kPickupCodePresets.first.links,
      hint: 'no_such_hint_key',
    );
    expect(pickupCodeEntryHint(zh, unknown), isEmpty);
    expect(pickupCodeEntryHint(zh, kPickupCodePresets.first), isNotEmpty);
  });

}
