import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';

import '../../helpers_test_app.dart';

/// OS4 玻璃弹层与宿主页之间的滚动手势 / 通知隔离。
///
/// 上游 `GlassPopupPresenter` 自带一个 `SingleChildScrollView` 包住弹层内容，而
/// `OverlayPortal` 的 overlay child 在元素树上仍挂在调用处：它会继承宿主页的
/// `HyperosScrollBehavior`（`AlwaysScrollableScrollPhysics` + 橡皮筋，内容没超高
/// 也能拖），它发出的 `ScrollNotification` 也会冒泡回宿主页，被页面的滚动监听
/// 当成"页面在滚"来驱动大标题收起 —— 但页面其实没滚，状态对不上。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('拖弹层里的列表：不冒泡到宿主页、不晃、不动页面大标题', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    var leaked = 0;
    await tester.pumpWidget(
      TestApp(
        home: NotificationListener<ScrollNotification>(
          onNotification: (_) {
            leaked++;
            return false;
          },
          child: HyperosSubpage(
            title: const Text('卡片外观设置'),
            onBack: () {},
            child: HyperosListView(
              children: [
                HyperosSelectTile<String>(
                  label: '卡片外观',
                  items: const {'实体卡片': 'solid', '高斯模糊': 'gaussian'},
                  value: 'solid',
                  onChanged: (_) {},
                ),
                for (var i = 0; i < 30; i++) const SizedBox(height: 64),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final titleBefore = tester.getRect(find.text('卡片外观设置').first);

    await tester.tap(find.text('卡片外观'));
    await tester.pumpAndSettle();
    expect(find.byType(MiuixGlassDropdownPopup), findsOneWidget);

    final popupPosition = tester
        .state<ScrollableState>(
          find
              .descendant(
                of: find.byType(MiuixGlassDropdownPopup),
                matching: find.byType(Scrollable),
              )
              .first,
        )
        .position;
    // 只有两条、放得下：这个滚动视图不该接管手势（页面的 AlwaysScrollable 会）。
    expect(popupPosition.physics.shouldAcceptUserOffset(popupPosition), isFalse);

    leaked = 0;
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('高斯模糊').last),
    );
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(const Offset(0, -40));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pumpAndSettle();

    expect(leaked, 0, reason: '弹层的滚动通知不应冒泡到宿主页');
    expect(popupPosition.pixels, 0, reason: '弹层列表内容放得下，不该被拖动');
    final titleAfter = tester.getRect(find.text('卡片外观设置').first);
    expect(titleAfter.top, closeTo(titleBefore.top, 0.5));
  });
}
