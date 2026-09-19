import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/widgets/home_page_region_blur.dart';

/// 「顶栏/信息栏到底还算不算在走玻璃」的判定。
///
/// 它决定**下游**要不要跟着做玻璃：日课表顶上的摘要卡（日期 + 关闭叉）会据此
/// 决定自己与顶栏同款，还是跟课程卡一样走实底。判错的表现是真机上「课程卡
/// 是实心、上面那张日期卡还是透的」。
void main() {
  TimetableSettings settingsWith({
    required String bandMaterial,
    bool headerBlur = true,
    bool weekdayBarBlur = true,
  }) => TimetableSettings.defaults().copyWith(
    homeBandGlassMaterial: bandMaterial,
    homePageHeaderBlurEnabled: headerBlur,
    homePageWeekdayBarBlurEnabled: weekdayBarBlur,
  );

  test('顶栏材质选「实体」时不算铬玻璃在跑（带是不透明实心条）', () {
    final solid = settingsWith(bandMaterial: 'solid');
    // 两个旧开关仍开着 —— 它们只表达"要不要磨砂"，与材质档可以不一致，
    // 实体档必须压过它们，否则摘要卡会继续跟一条实心带"同款"。
    expect(solid.homePageHeaderBlurEnabled, isTrue);
    expect(solid.homePageWeekdayBarBlurEnabled, isTrue);
    expect(homePageHasAnyChromeBlur(solid, hasBackdrop: true), isFalse);
  });

  test('顶栏材质还是玻璃档时口径不变', () {
    for (final material in ['progressive', 'gaussian', 'soft', 'liquid']) {
      expect(
        homePageHasAnyChromeBlur(
          settingsWith(bandMaterial: material),
          hasBackdrop: true,
        ),
        isTrue,
        reason: '$material 档仍是玻璃，下游应继续跟顶栏同款',
      );
    }
  });

  test('没有壁纸 / 两个开关都关时不算玻璃', () {
    expect(
      homePageHasAnyChromeBlur(
        settingsWith(bandMaterial: 'gaussian'),
        hasBackdrop: false,
      ),
      isFalse,
    );
    expect(
      homePageHasAnyChromeBlur(
        settingsWith(
          bandMaterial: 'gaussian',
          headerBlur: false,
          weekdayBarBlur: false,
        ),
        hasBackdrop: true,
      ),
      isFalse,
    );
  });

  group('玻璃带的上下两条直边都往裁剪外多画一点', () {
    /// 着色器的受光高光与折射位移都挤在离形状边界 1~2px 的一圈里。形状边界
    /// 一旦**正好落在**可见区边界上，那一圈就直接读成一条发丝边——顶边早就靠
    /// `top: -4` 推到 ClipRect 之外，底边一直是 `bottom: 0`，于是只剩底边露着
    /// （真机：星期栏底边一条黑边）。
    Future<Positioned> bandGlassPositioned(WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 800,
              child: Stack(
                children: [
                  HomePageContinuousChromeFrostedOverlay(
                    headerBlurEnabled: true,
                    weekdayBarBlurEnabled: true,
                    includeStatusBar: false,
                    weekdayBarHeight: 40,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      return tester.widget<Positioned>(
        find
            .ancestor(
              of: find.byType(HomePageChromeGlassFill),
              matching: find.byType(Positioned),
            )
            .first,
      );
    }

    testWidgets('顶边与底边都在可见带之外', (tester) async {
      final positioned = await bandGlassPositioned(tester);
      expect(positioned.top, -homePageChromeGlassTopEdgeOverdraw);
      expect(positioned.bottom, -homePageChromeGlassBottomEdgeOverdraw);
    });

    testWidgets('底边外溢量必须小：大了会把整条底边折射一起切掉', (tester) async {
      // 底边折射是「玻璃带 → 课表」的过渡，原先那份 48.0 的常量就是为此没被启用
      // （注释写着「留作 API 完整性」）。量级上限钉在这里，防止有人顺手调大。
      expect(homePageChromeGlassBottomEdgeOverdraw, greaterThan(0));
      expect(homePageChromeGlassBottomEdgeOverdraw, lessThanOrEqualTo(8.0));
    });
  });
}
