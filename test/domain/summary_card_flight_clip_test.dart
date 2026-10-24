import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';
import 'package:university_timetable/widgets/timetable/summary_card_flight.dart';
import 'package:university_timetable/widgets/timetable/timetable_anchored_day_overlay.dart';

/// 摘要卡在**层上方**那一段不会被祖先裁掉（2026-10-23 审核补）。
///
/// ## 这条测试抓的是什么
///
/// 摘要卡的飞行起点在转场层**上方**（`top = -星期栏高`）—— 它要把自己压在星期栏
/// 那一格上，这是用户要的「从当日的星期里面长出来」。
///
/// 而外层那个 `Stack` 默认 `Clip.hardEdge`：负区间那段**布局正确、绘制被裁**。
/// 于是「从星期格里长出来」的前 40% 在真机上什么都看不到，卡凭空出现在层顶。
///
/// ## 为什么之前 19 例测试全绿却没发现
///
/// 它们全部基于 `tester.getRect(...)` —— 只读**布局**，不读**绘制**。布局里那张
/// 卡的位置一直是对的（实测 `t=0.3` 时卡顶边 y=13.1，而第一个被画出的像素在
/// y=40，中间 27dp 被裁掉）。
///
/// ## 判据
///
/// 沿 [SummaryFlightCard] 的渲染对象往上走，找出**所有会裁剪的祖先**，逐个确认
/// 卡（在它上方那一段）落在裁剪区内。这是 `getRect` 抓不到、而像素能抓到的那一层
/// 语义，且不依赖 `toImage`（那个在 widget 测试的 fake async 里会挂死）。
void main() {
  const headerHeight = 40.0;
  const settings = TimetableSettings(sections: <SectionTime>[]);
  const endRect = Rect.fromLTWH(14, headerHeight + 14, 364, 107);

  Future<void> pumpOverlay(WidgetTester tester, double t) async {
    await tester.binding.setSurfaceSize(const Size(392, 740));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        home: FrostedAppearanceScope(
          appearance: FrostedAppearance.defaults,
          child: Scaffold(
            body: Column(
              children: [
                // 真正的星期栏占位（40 高），下面才是转场层。
                Container(
                  height: headerHeight,
                  color: const Color(0xFF0000FF),
                ),
                Expanded(
                  child: TimetableAnchoredDayOverlay(
                    panel: const SizedBox.expand(
                      child: ColoredBox(color: Color(0xFFEEEEEE)),
                    ),
                    expandAnimation: AlwaysStoppedAnimation(t),
                    weekTimeColumnWidth: 40,
                    visibleDayCount: 7,
                    selectedDayIndex: 4,
                    sectionHeight: 60,
                    settings: settings,
                    cardInset: 0,
                    summaryFlight: const SummaryFlightInput(
                      endRectOnScreen: endRect,
                      weekdayLabel: '周五',
                      cellDateLabel: '03/20',
                      titleLabel: '03月20日 周五',
                      metaLabel: '第 3 周',
                      lowerSection: null,
                      fill: Color(0xFFFFFFFF),
                      ink: Color(0xFF000000),
                      mutedInk: Color(0x8A000000),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  /// 收集 [SummaryFlightCard] 上方所有**真的会裁**的祖先（label + 屏幕矩形）。
  ///
  /// ## 为什么要看 widget 参数而不是渲染对象类型
  ///
  /// 第一版这里找 `RenderClipRect`，**反向验证直接失败**：删掉 `Clip.none` 之后
  /// 测试照样绿。原因是 `RenderStack` 的裁剪不是靠 clipper 实现的 —— 它在
  /// `paint` 里 `context.pushClipRect(...)`，祖先链里根本没有 `RenderClipRect`
  ///（实测链：`RenderDecoratedBox <- RenderStack <- RenderIgnorePointer <- ...`）。
  ///
  /// 所以判据回到 widget 参数：`Stack.clipBehavior` / `ClipRect` 这些**声明**才是
  /// 决定画不画的那一层。同时把卡片自身那层的圆角裁剪排除（`ClipRRect` 在卡内，
  /// 裁剪区就是卡本身）。
  List<(String, Rect)> clippingAncestors(WidgetTester tester) {
    final found = <(String, Rect)>[];
    final cardElement = tester.element(find.byType(SummaryFlightCard));
    // 从卡自己往上，逐个看 widget 是不是「会裁剪的容器」。
    cardElement.visitAncestorElements((element) {
      final widget = element.widget;
      var clips = false;
      if (widget is Stack) {
        clips = widget.clipBehavior != Clip.none;
      } else if (widget is ClipRect) {
        clips = widget.clipBehavior != Clip.none;
      } else if (widget is ClipPath) {
        clips = widget.clipBehavior != Clip.none;
      }
      if (clips) {
        final box = element.renderObject;
        if (box is RenderBox && box.hasSize) {
          found.add((
            widget.runtimeType.toString(),
            box.localToGlobal(Offset.zero) & box.size,
          ));
        }
      }
      return true;
    });
    return found;
  }

  testWidgets('前 40%：卡在层上方，没有被任何祖先裁掉', (tester) async {
    await pumpOverlay(tester, 0.3);
    final card = tester.getRect(find.byType(SummaryFlightCard));

    expect(
      card.top,
      lessThan(headerHeight),
      reason: '前提：t=0.3 时卡顶边应在层顶（y=$headerHeight）之上，实测 ${card.top}。'
          '若这条不成立，说明几何变了，下面的裁剪断言就没有意义。',
    );

    for (final (label, clip) in clippingAncestors(tester)) {
      expect(
        clip.top,
        lessThanOrEqualTo(card.top + 0.5),
        reason:
            '有一层裁剪（$label）顶边在 y=${clip.top}，而卡的顶边在 y=${card.top} —— '
            '卡在上方那一段会被裁掉，「从星期格里长出来」的前 40% 就看不见了。'
            '该层裁剪区：$clip。',
      );
    }
  });

  testWidgets('全部可见帧：都没有祖先把卡裁掉', (tester) async {
    for (final t in [0.05, 0.2, 0.35, 0.5, 0.7, 0.9]) {
      await pumpOverlay(tester, t);
      final card = tester.getRect(find.byType(SummaryFlightCard));
      for (final (label, clip) in clippingAncestors(tester)) {
        expect(
          clip.top,
          lessThanOrEqualTo(card.top + 0.5),
          reason: 't=$t：$label 的顶边 ${clip.top} 高于卡顶边 ${card.top}，卡被裁。',
        );
        expect(
          clip.left,
          lessThanOrEqualTo(card.left + 0.5),
          reason: 't=$t：$label 的左边 ${clip.left} 在卡左边 ${card.left} 之内，卡被裁。',
        );
        expect(
          clip.right,
          greaterThanOrEqualTo(card.right - 0.5),
          reason: 't=$t：$label 的右边 ${clip.right} 在卡右边 ${card.right} 之内，卡被裁。',
        );
      }
    }
  });
}
