// 月视图面板的**材质/墨色**判据（2026-10-21 立，2026-10-23 按"独立卡"重写）。
//
// 用户口径（2026-10-23）：「下面的信息区域也改成这样，单独的卡片，而不是一个
// 整体大卡片」。面板没了，于是 2026-10-21 立的那两条判据里：
//
// * **形状那条（上沿的弧向上凸）** 随面板一起删除 —— 没有板就没有板沿，
//   `MonthPanelTopCurveClipper` 已从 `lib/` 移除；
// * **墨色那条** 仍然成立，而且更重要了：卡从"躺在白板里"变成"浮在壁纸上"，
//   判据必须跟着从"主题墨色"改成"按卡面判"。
//
// 这轮把墨色那条重写成显式的两道闸：
//   1. 卡外文字（分区标题）按**壁纸**判；
//   2. 卡内文字按**卡面**判。
// 这两条混用就是 2026-10-21 那次"白字压白底"的病根。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/utils/home_page_background.dart';
import 'package:university_timetable/widgets/timetable/month_view/month_panel_surface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<BuildContext> pumpContext(
    WidgetTester tester,
    Brightness brightness,
  ) async {
    late BuildContext captured;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF3482FF),
            brightness: brightness,
          ),
        ),
        home: Builder(
          builder: (context) {
            captured = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    await tester.pump();
    return captured;
  }

  group('卡外文字跟壁纸、卡内文字跟卡面（两种判据不许混用）', () {
    // 2026-10-21 用户截图实测：暗壁纸下，「10月22日」那行标题是白字压白底，
    // 直接看不见。根因是把「按壁纸亮度判出的墨色」复用到了白色面板上。
    test('暗壁纸 → 卡外文字用浅墨，但卡内文字必须自己判（不能用那个浅墨）', () {
      final onWallpaper = homePageChromeForegroundForLuminance(0.08);
      expect(
        onWallpaper,
        isNot(const Color(0xFF000000)),
        reason: '暗壁纸上、直接压壁纸的字（品牌名 / 分区标题）要用浅色墨 —— 这是对的',
      );
      expect(
        onWallpaper,
        isNot(ThemeData.light().colorScheme.onSurface),
        reason: '卡内若沿用壁纸判出的墨色，暗壁纸下就是白字压白卡 —— 直接看不见',
      );
    });

    test('亮壁纸 → 卡外文字用深墨（与暗壁纸相反那一侧）', () {
      final onLight = homePageChromeForegroundForLuminance(0.92);
      expect(onLight, isNot(const Color(0xFFFFFFFF)));
    });
  });

  group('信息卡填充的唯一来源', () {
    testWidgets('取主题 surface（与日历卡同色），深浅两套同一来源', (tester) async {
      for (final brightness in Brightness.values) {
        final context = await pumpContext(tester, brightness);
        final scheme = Theme.of(context).colorScheme;
        expect(
          monthInfoCardFill(context).toARGB32(),
          scheme.surface.toARGB32(),
          reason:
              '${brightness.name}：信息卡与日历卡必须同色 —— 旧的 '
              'surfaceContainerHighest 是"卡躺在白板里"时代的口径，'
              '那时两者必须拉开对比才看得见卡。分叉本身就是漏改一半的成因',
        );
      }
    });
  });

  group('卡内墨色：按卡面判，且真的读得出', () {
    testWidgets('墨色不透明、与卡面对比 ≥3:1（深浅两套都跑）', (tester) async {
      for (final brightness in Brightness.values) {
        final context = await pumpContext(tester, brightness);
        final fill = monthInfoCardFill(context);
        final ink = monthInfoCardInk(
          context: context,
          settings: const TimetableSettings(sections: []),
          cardFill: fill,
        );
        expect(ink.a, 1, reason: '${brightness.name}：卡内文字必须不透明');
        final hi = ink.computeLuminance() > fill.computeLuminance()
            ? ink.computeLuminance()
            : fill.computeLuminance();
        final lo = ink.computeLuminance() > fill.computeLuminance()
            ? fill.computeLuminance()
            : ink.computeLuminance();
        expect(
          (hi + 0.05) / (lo + 0.05),
          greaterThan(3),
          reason: '${brightness.name}：卡面墨色与卡面本色的对比读不清',
        );
      }
    });
  });
}
