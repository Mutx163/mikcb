import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/domain/home_view_mode.dart';
import 'package:university_timetable/models/timetable_settings.dart';

/// 「首页三视图（周 / 日 / 月）」的模式 ↔ 底栏内嵌页 id 映射契约。
///
/// 为什么单独成一个 domain 文件并直接断言返回值（而不是泵首页看页面打开了）：
/// AGENTS.md 的 TEST-POLICY 里「参数透传类改动」那条 —— `find.byType(页面)` 全绿
/// 不等于参数到位。这里钉的是**算出来的那个值**，期望值是人推出来的。
void main() {
  TimetableSettings settingsWith({
    HomeNavigationForm form = HomeNavigationForm.glassDock,
    TimetableHomeViewMode mode = TimetableHomeViewMode.month,
  }) => TimetableSettings.defaults().copyWith(
    homeNavigationForm: form,
    timetableHomeViewMode: mode,
  );

  group('restoreInlinePageId', () {
    test('玻璃坞 + month ⇒ 摆回月视图内嵌页', () {
      expect(restoreInlinePageId(settingsWith()), kMonthViewInlinePageId);
      expect(
        restoreInlinePageId(settingsWith()),
        'monthView',
        reason: '这个字符串是 kInlineDockPages 的注册键，改了要去登记表同步',
      );
    });

    test('经典形态 + month ⇒ 不摆（内嵌层连建都不建）', () {
      expect(
        restoreInlinePageId(settingsWith(form: HomeNavigationForm.classic)),
        isNull,
      );
    });

    test('week / day ⇒ 一律 null（课表本体自己表达，不占内嵌页）', () {
      for (final mode in [
        TimetableHomeViewMode.week,
        TimetableHomeViewMode.day,
      ]) {
        expect(restoreInlinePageId(settingsWith(mode: mode)), isNull);
      }
    });
  });

  group('homeViewModeForInlinePage', () {
    // 依据是**当前画面**（isDayView），不是持久化值：持久化值可能停在 month
    // 而画面上内嵌页已经关了，拿它当依据就写成「关掉月视图 → 又落回月视图」。
    test('月视图内嵌页 ⇒ month（哪怕画面正处于日视图）', () {
      expect(
        homeViewModeForInlinePage(
          inlineId: kMonthViewInlinePageId,
          isDayView: true,
        ),
        TimetableHomeViewMode.month,
      );
      expect(
        homeViewModeForInlinePage(
          inlineId: kMonthViewInlinePageId,
          isDayView: false,
        ),
        TimetableHomeViewMode.month,
      );
    });

    test('别的内嵌页（设置 / 统计…）不改浏览模式，照画面状态走', () {
      for (final id in ['settings', 'statistics', 'tasks', 'whatever']) {
        expect(
          homeViewModeForInlinePage(inlineId: id, isDayView: true),
          TimetableHomeViewMode.day,
          reason: '底栏可以放很多内嵌页，只有月视图是「视图」',
        );
        expect(
          homeViewModeForInlinePage(inlineId: id, isDayView: false),
          TimetableHomeViewMode.week,
        );
      }
    });

    test('收回课表本体（null）⇒ 此路不可能得到 month', () {
      expect(
        homeViewModeForInlinePage(inlineId: null, isDayView: false),
        TimetableHomeViewMode.week,
      );
      expect(
        homeViewModeForInlinePage(inlineId: null, isDayView: true),
        TimetableHomeViewMode.day,
      );
    });
  });

  test('isMonthInlinePage 只认月视图那一个 id', () {
    expect(isMonthInlinePage(kMonthViewInlinePageId), isTrue);
    expect(isMonthInlinePage('monthViewPage'), isFalse);
    expect(isMonthInlinePage('settings'), isFalse);
    expect(isMonthInlinePage(null), isFalse);
  });
}
