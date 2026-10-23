import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'guard_source.dart';

/// 架构守卫：飞行卡（转场中那张）**必须走真卡的材质出口**，不许自己画色块
/// （2026-10-23 立）。
///
/// ## 为什么需要这道守卫
///
/// 用户口径：「这个新卡的是实体卡材质不一样」。
///
/// 摘要卡的飞行卡第一版自己画了个 `DecoratedBox(color: 纯白)`，而真摘要卡走
/// `CourseSurface`。玻璃档下：真卡是磨砂、飞行卡是实心白卡 —— 起飞那一瞬间
/// 材质就换了，落定又换回来。判墨还写死了 `CourseCardSurfaceStyle.solid`，
/// 于是字色也按实体卡面判。
///
/// ## 为什么是源码守卫而不是像素断言
///
/// 组件测试宿主上玻璃档**渲染不出来**：`HyperosBlurredHeader.liveBlurSupported`
/// 只认 Android/iOS，且壁纸文件不存在 ⇒ `CourseSurface` 一律降级成实体卡
/// （本仓已知边界，见 `dayViewContentCardSurfaceStyle` 的注释）。
///
/// 所以「玻璃档下材质是否一致」在测试里比不出来。能钉住的是**走哪条路**：
/// 飞行卡必须经由 `DayViewAgendaSurface` / `CourseSurface`（与真卡同一个出口），
/// 且判墨必须传 `dayViewContentCardSurfaceStyle(...)` 而不是常量 `solid`。
///
/// 这一点等价于真机上的正确性：只要走同一个出口，档位 / 磨砂 / 染色 / 描边 /
/// 投影就必然同源，不可能「只剩飞行卡是白的」。
void main() {
  const flightPath = 'lib/widgets/timetable/summary_card_flight.dart';
  const courseFlightPath = 'lib/widgets/timetable/flight_card_body.dart';

  String sourceOf(String path) {
    final file = File(GuardSource.resolve(path));
    expect(file.existsSync(), isTrue, reason: '$path 不存在，守卫已空转');
    return file.readAsStringSync();
  }

  /// 去掉注释，避免「注释里写了 DecoratedBox」被误判。
  String codeOnly(String source) => source
      .split('\n')
      .where((line) => !line.trimLeft().startsWith('//'))
      .join('\n');

  test('飞行摘要卡必须走 CourseSurface / DayViewAgendaSurface', () {
    final code = codeOnly(sourceOf(flightPath));
    expect(
      code.contains('DayViewAgendaSurface(') ||
          code.contains('CourseSurface('),
      isTrue,
      reason:
          '飞行摘要卡必须经由真卡同一个材质出口。自己画 DecoratedBox 的话，玻璃档'
          '下真卡是磨砂、飞行卡是实心白 —— 用户 2026-10-23 报的「材质不一样」。',
    );
    // 卡面不许自己刷底色。
    //
    // 判据：卡面那条**主出口**必须是带 `settings:` 的表面组件（
    // `DayViewAgendaSurface`），且它的 alpha 来自可插值的入参，不是写死的常量色。
    // 内部内容（计数胶囊）当然允许有自己的 `BoxDecoration(color:)` —— 它是内容，
    // 不是卡面，所以不能全扫一遍。
    final cardBody = code.substring(code.indexOf('class SummaryFlightCard'));
    expect(
      RegExp(r'return\s+DayViewAgendaSurface\s*\(').hasMatch(cardBody),
      isTrue,
      reason:
          'SummaryFlightCard 的主出口必须是 DayViewAgendaSurface（= 真卡同一个'
          'CourseSurface 通道）。换回自绘 DecoratedBox 的话，玻璃档下真卡是磨砂、'
          '飞行卡是实心白 —— 用户 2026-10-23 报的「材质不一样」就是它。',
    );
    // 卡面颜色必须随 `surfaceOpacity` 变化：写死 `Colors.white` / 常量 alpha 会让
    // 起点就出现一块不透明卡面（星期栏那一格本来没有卡面）。
    expect(
      cardBody.contains('surfaceOpacity'),
      isTrue,
      reason:
          '卡面必须按 `surfaceOpacity` 淡入。起点直接画不透明卡面，会在星期栏上'
          '凭空冒出一块白卡（那一格本来只是几行字）。',
    );
  });

  test('飞行摘要卡的判墨必须跟随真实材质档，不许写死 solid', () {
    final code = codeOnly(sourceOf(flightPath));
    final inkCall = code.indexOf('resolveSummaryCardInk(');
    expect(inkCall, greaterThan(0), reason: '飞行卡应该走 resolveSummaryCardInk，守卫已空转');
    // 取这次调用之后的 900 字符（参数区），看 surfaceStyle 传的是什么。
    final tail = code.substring(
      inkCall,
      (inkCall + 900).clamp(0, code.length),
    );
    expect(
      tail.contains('dayViewContentCardSurfaceStyle('),
      isTrue,
      reason:
          '判墨的 surfaceStyle 必须是 `dayViewContentCardSurfaceStyle(settings, '
          'backdropBlurOn:)` —— 与真摘要卡同一个入口。写死 `solid` 的话，玻璃档'
          '下飞行卡按实体卡面判字色，落定那一帧会翻一次（用户口径「材质不一样」'
          '的字色那一半）。',
    );
  });

  test('飞行课程卡也必须走 CourseSurface', () {
    final code = codeOnly(sourceOf(courseFlightPath));
    expect(
      code.contains('DayViewAgendaSurface(') ||
          code.contains('CourseSurface('),
      isTrue,
      reason:
          '飞行课程卡必须经由 CourseSurface（与议程卡同一个材质出口），'
          '否则同样会「动画是实体、落定是玻璃」。',
    );
  });

  test('两端不许把玻璃面塞进 Opacity（磨砂会塌）', () {
    for (final path in [flightPath, courseFlightPath]) {
      final code = codeOnly(sourceOf(path));
      // 只认「Opacity 直接包住表面」这种写法：同一行里出现 Opacity 与 surface
      // 构造函数即视为违规；分行写的由 `_render_test` 里的 widget 树检查兜住。
      final badLine = RegExp(
        r'Opacity\s*\([^)]*(DayViewAgendaSurface|CourseSurface)\s*\(',
      );
      expect(
        badLine.hasMatch(code),
        isFalse,
        reason:
            '$path 里把玻璃面直接包进了 Opacity。BackdropFilter 进半透明层采不到'
            '身后内容，磨砂会塌成透明（`CourseSurface` 类注释的原文铁律）。',
      );
    }
  });
}
