// 月视图「页面上到底画了什么」的契约测试（2026-10-20）。
//
// 为什么需要这一层：`flutter test` 里没有真实壁纸文件、也拿不到 GPU 模糊后端
// （`HyperosBlurredHeader.liveBlurSupported` 在测试宿主机上恒为 false），所以
// 「看起来有壁纸」是渲染断言测不出来的 —— 玻璃档会降级成实体卡，画面与线上完全不同。
//
// 因此这里钉的是**结构契约**，而且钉的正是那次事故的判据：
//
//   首版写的是 `homePageBackgroundLayer(visual: resolveHomePageRegionBackground(…))`，
//   以为这就是「铺壁纸」。实际那两个函数在本仓**从不画图**：
//   `resolveHomePageRegionBackground` 的返回点只有 color（全仓没有任何一处给
//   `HomePageBackgroundVisual` 传 `imageProvider`），有壁纸时它返回 transparent，
//   于是 `homePageBackgroundLayer` 直接 `return child` —— 一个像素都没铺。
//
// 第一条用例直接断言那个**反直觉的事实**：它红掉说明底层行为变了，而这是好事 ——
// 那时就该把这条用例连同外壳里的 `homePageBackdropLayer` 一起重新审一遍。
//
// 第二条用例钉外壳的判据链：没有壁纸时材质必须降级、且不请求任何预糊位图
// （否则等于给一张不存在的图白烤一份位图、白占显存）。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/ui/home/home_chrome_spec.dart';
import 'package:university_timetable/utils/home_page_background.dart';

const TimetableSettings _noWallpaper = TimetableSettings(sections: []);

void main() {
  group('壁纸底图的唯一画法', () {
    test('resolveHomePageRegionBackground 从不返回带图的 visual', () {
      // 这条钉的是「为什么首版没铺上壁纸」的最小事实。它看起来像在测一个缺陷，
      // 但钉的其实是**真实契约**：那个函数只回答「这一块要不要让出壁纸」，
      // 画图是 homePageBackdropLayer 的事。
      final visual = resolveHomePageRegionBackground(
        settings: _noWallpaper.copyWith(
          homePageBackgroundScope: HomePageBackgroundScope.defaultValue,
        ),
        isDark: false,
        darkFallback: const Color(0xFFFFFFFF),
        region: HomePageBackgroundScope.timetable,
      );
      expect(
        visual.hasImage,
        isFalse,
        reason:
            'resolveHomePageRegionBackground 从不携带图片。若这条变红，说明有人'
            '给它加了 imageProvider —— 请同步审 timetable_page_chrome_shell 里'
            ' _wallpaperLayer 的注释与调用。',
      );
    });

    testWidgets('homePageBackgroundLayer 在 transparent 时一层都不铺', (tester) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: homePageBackgroundLayer(
            visual: const HomePageBackgroundVisual(color: Colors.transparent),
            child: const SizedBox(
              key: ValueKey('payload'),
              width: 10,
              height: 10,
            ),
          ),
        ),
      );
      expect(find.byKey(const ValueKey('payload')), findsOneWidget);
      // transparent 分支原样返回 child：树上不新增任何装饰层。
      // （首版就卡在这里 —— 它以为自己在铺背景，其实什么都没铺。）
      expect(find.byType(DecoratedBox), findsNothing);
    });
  });

  group('HomeChromeSpec：独立页面与首页同一套判据', () {
    testWidgets('无壁纸时卡片材质回落实体档，且不请求预糊位图', (tester) async {
      late HomeChromeSpec chrome;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              chrome = resolveHomeChromeSpec(
                context: context,
                // 用户选了「液态玻璃」，但没有壁纸 —— 没有可采样的背景，
                // 材质必须降级（否则卡片读作一层没有来源的透明水洗色）。
                settings: const TimetableSettings(
                  sections: [],
                  courseCardSurfaceStyle: CourseCardSurfaceStyle.liquidGlass,
                ),
                isDark: false,
                darkFallback: const Color(0xFFFFFFFF),
                wallpaperTopLuminance: null,
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(chrome.hasBackdrop, isFalse);
      expect(
        chrome.cardStyle,
        CourseCardSurfaceStyle.solid,
        reason: '没有壁纸必须回落实体卡片（effectiveCourseCardSurfaceStyle 口径）',
      );
      expect(chrome.useCoursePreblur, isFalse, reason: '实体卡不需要预糊位图；烤一张就是白花显存');
      expect(chrome.useHomePreblur, isFalse, reason: '整页没有玻璃时，首页那份位图同样没人用');
      expect(
        chrome.chromeBandPaints,
        isFalse,
        reason: '没有壁纸就没有可采样的玻璃带，实心条也不该画（它只会盖出一条色带）',
      );
    });
  });
}
