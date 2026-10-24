import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/domain/schedule_quick_presets.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/l10n/schedule_preset_localizer.dart';

/// 六个语言的 locale（zh 的三个变体靠 countryCode 区分）。
const _locales = <String, Locale>{
  'zh': Locale('zh'),
  'zh_HK': Locale('zh', 'HK'),
  'zh_TW': Locale('zh', 'TW'),
  'en': Locale('en'),
  'ja': Locale('ja'),
  'ko': Locale('ko'),
};

void main() {
  test('数据表里每一条在每种语言下都有非空标题', () {
    // 这条就是「加了模板却漏配六个 ARB」的探针：新增条目后这里立刻红，
    // 而不是等到用户看见一张空标题的卡。
    for (final entry in _locales.entries) {
      final l10n = lookupAppLocalizations(entry.value);
      for (final preset in kScheduleQuickPresets) {
        final title = scheduleQuickPresetTitle(l10n, preset.id);
        expect(
          title.trim(),
          isNotEmpty,
          reason: '${entry.key} 缺少 ${preset.id} 的标题文案',
        );
      }
    }
  });

  test('中文下十条标题互不相同（防拷贝粘贴错行）', () {
    final l10n = lookupAppLocalizations(const Locale('zh'));
    final titles = {
      for (final preset in kScheduleQuickPresets)
        scheduleQuickPresetTitle(l10n, preset.id),
    };
    expect(titles.length, kScheduleQuickPresets.length);
  });

  test('未知 id 返回空串（界面据此不渲染那张卡，而不是显示空标题）', () {
    final l10n = lookupAppLocalizations(const Locale('zh'));
    expect(scheduleQuickPresetTitle(l10n, 'no-such-preset'), isEmpty);
    expect(scheduleQuickPresetLabel(l10n, kScheduleQuickPresets.first), isNotEmpty);
  });

  group('时长说明', () {
    final zh = lookupAppLocalizations(const Locale('zh'));

    test('整小时不带 0 分', () {
      expect(scheduleQuickPresetDurationLabel(zh, 60), '1 小时');
      expect(scheduleQuickPresetDurationLabel(zh, 120), '2 小时');
    });

    test('不足一小时只给分钟', () {
      expect(scheduleQuickPresetDurationLabel(zh, 30), '30 分钟');
    });

    test('半小时余数写成「小时 + 分」', () {
      expect(scheduleQuickPresetDurationLabel(zh, 90), '1 小时 30 分');
      expect(scheduleQuickPresetDurationLabel(zh, 150), '2 小时 30 分');
    });

    test('0 或负数返回空串（界面不画说明行）', () {
      expect(scheduleQuickPresetDurationLabel(zh, 0), isEmpty);
      expect(scheduleQuickPresetDurationLabel(zh, -30), isEmpty);
    });

    test('六种语言都给出了非空且不含 0 分的写法', () {
      for (final entry in _locales.entries) {
        final l10n = lookupAppLocalizations(entry.value);
        for (final preset in kScheduleQuickPresets) {
          final label = scheduleQuickPresetDurationLabel(
            l10n,
            preset.durationMinutes,
          );
          expect(label.trim(), isNotEmpty, reason: entry.key);
          // 「60 分钟」这种整小时却用分钟的写法：英文会得到 “60 min”，
          // 与同语言的 “1 hr” 并存时读起来是两种量纲。
          if (preset.durationMinutes % 60 == 0) {
            expect(
              label,
              isNot(contains('60')),
              reason: '${entry.key} / ${preset.id} 整小时却按分钟写：$label',
            );
          }
        }
      }
    });
  });

  group('选中态判定（套用后用户又改了标题）', () {
    final zh = lookupAppLocalizations(const Locale('zh'));
    final groupTitle = scheduleQuickPresetTitle(zh, 'groupMeeting');

    test('套用过、标题仍是模板标题 → 选中', () {
      expect(
        scheduleQuickPresetActiveId(
          zh,
          appliedId: 'groupMeeting',
          currentTitle: groupTitle,
        ),
        'groupMeeting',
      );
    });

    test('标题被改掉 → 不再选中（卡片不能声称用户选的是组会）', () {
      expect(
        scheduleQuickPresetActiveId(
          zh,
          appliedId: 'groupMeeting',
          currentTitle: '和导师讨论课题',
        ),
        isNull,
      );
    });

    test('改回模板标题 → 选中态自己回来（撤销输入不该留下脏状态）', () {
      expect(
        scheduleQuickPresetActiveId(
          zh,
          appliedId: 'groupMeeting',
          currentTitle: '  $groupTitle  ',
        ),
        'groupMeeting',
        reason: '首尾空白应被忽略，用户多打一个空格不该掉选中态',
      );
    });

    test('没套用过 → null', () {
      expect(
        scheduleQuickPresetActiveId(
          zh,
          appliedId: null,
          currentTitle: groupTitle,
        ),
        isNull,
      );
    });

    test('套用的是未知 id（数据表删了条目）→ null，不留幽灵选中态', () {
      expect(
        scheduleQuickPresetActiveId(
          zh,
          appliedId: 'no-such-preset',
          currentTitle: '随便什么',
        ),
        isNull,
      );
    });
  });
}
