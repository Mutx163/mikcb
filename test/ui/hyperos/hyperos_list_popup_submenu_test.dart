import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';
import 'package:university_timetable/widgets/home_top_menu.dart';

import '../../helpers_test_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // 高斯磨砂定值外观：测试环境无真实玻璃采样，固定参数保证确定性。
  const gaussianAppearance = FrostedAppearance(
    sheetBlurSigma: 15,
    sheetTintAlpha: 0.7,
    sheetBarrierAlpha: 0.2,
    glassMode: FrostedGlassMode.gaussian,
  );

  group('hyperos list popup submenu', () {
    const items = [
      HyperosPopupMenuItem(label: '普通项', value: 'a'),
      HyperosPopupMenuItem(
        label: '视图父项',
        value: 'parent',
        children: [
          HyperosPopupMenuItem(label: '子项一', value: 'child:1'),
          HyperosPopupMenuItem(label: '子项二', value: 'child:2'),
        ],
      ),
      HyperosPopupMenuItem(label: '尾项', value: 'c'),
    ];

    // 打开弹窗并收集它的回传 Future。注意：返回的是「装 Future 的列表」
    // 而非 Future 本身——async 函数 return Future 会被 Dart 自动 flatten
    // （内部隐式 await），而弹窗 result 只有关闭时才完成，测试体没关弹窗
    // 就会永久挂起。
    Future<List<Future<String?>?>> pumpPopup(
      WidgetTester tester, {
      required List<HyperosPopupMenuItem<String>> items,
    }) async {
      final opened = <Future<String?>?>[];
      await tester.pumpWidget(
        TestApp(
          home: FrostedAppearanceScope(
            appearance: gaussianAppearance,
            child: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  opened.add(
                    showHyperosListPopup<String>(
                      context: context,
                      position: const RelativeRect.fromLTRB(200, 80, 24, 200),
                      items: items,
                    ),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return opened;
    }

    testWidgets('收起态只显示父行与右向箭头，子行不可见', (tester) async {
      await pumpPopup(tester, items: items);

      expect(find.text('视图父项'), findsOneWidget);
      expect(find.text('子项一'), findsNothing);
      expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
      expect(
        tester.widget<AnimatedRotation>(find.byType(AnimatedRotation)).turns,
        0,
      );
    });

    testWidgets('点父行浮出二级列表（父行在卡内原位重复），再点收起且弹窗不关', (tester) async {
      await pumpPopup(tester, items: items);

      await tester.tap(find.text('视图父项'));
      await tester.pumpAndSettle();

      // 浮层卡里父行原样重复 + 两个子行都可见。
      expect(find.text('视图父项'), findsNWidgets(2));
      expect(find.text('子项一'), findsOneWidget);
      expect(find.text('子项二'), findsOneWidget);
      // 展开态箭头翻转为朝上（-90°），主面板行与卡内行同步。
      for (final rotation in tester.widgetList<AnimatedRotation>(
        find.byType(AnimatedRotation),
      )) {
        expect(rotation.turns, closeTo(-0.25, 0.0001));
      }

      // 主面板父行与卡内父行同位（卡片锚定在父行原位），点哪个都收起。
      await tester.tap(find.text('视图父项').first);
      await tester.pumpAndSettle();

      expect(find.text('子项一'), findsNothing);
      // 弹窗仍开着（父行点按是展开开关，不回传不关闭）。
      expect(find.text('普通项'), findsOneWidget);
    });

    testWidgets('点子行立即回传子项 value 关闭弹窗', (tester) async {
      final opened = await pumpPopup(tester, items: items);

      await tester.tap(find.text('视图父项'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('子项二'));
      await tester.pump();
      expect(await opened.single, 'child:2');
      expect(find.text('普通项'), findsNothing);
    });

    testWidgets('展开态点主面板暗区只收起子列表，弹窗不关', (tester) async {
      await pumpPopup(tester, items: items);

      await tester.tap(find.text('视图父项'));
      await tester.pumpAndSettle();
      expect(find.text('子项一'), findsOneWidget);

      // 「普通项」行在父行上方、被暗层覆盖：点它=收起。
      await tester.tap(find.text('普通项'));
      await tester.pumpAndSettle();

      expect(find.text('子项一'), findsNothing);
      expect(find.text('普通项'), findsOneWidget);
    });

    testWidgets('展开态按返回键先收子列表，再按才关弹窗', (tester) async {
      await pumpPopup(tester, items: items);

      await tester.tap(find.text('视图父项'));
      await tester.pumpAndSettle();

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('子项一'), findsNothing);
      expect(find.text('普通项'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('普通项'), findsNothing);
    });

    testWidgets('展开态点面板外遮罩整窗关闭', (tester) async {
      await pumpPopup(tester, items: items);

      await tester.tap(find.text('视图父项'));
      await tester.pumpAndSettle();

      // 面板右对齐（x≈412..776、y≈80..248），左下角远端必在遮罩上。
      await tester.tapAt(const Offset(30, 520));
      await tester.pumpAndSettle();

      expect(find.text('普通项'), findsNothing);
      expect(find.text('视图父项'), findsNothing);
    });
  });

  group('home top menu add-course submenu wiring', () {
    final entries = [
      HomeMenuEntry(
        id: 'addCourse',
        title: (l10n) => l10n.homeMenuAddCourseTitle,
        icon: Icons.add_circle_outline_rounded,
        category: HomeMenuEntryCategory.features,
        open: (_) async {},
      ),
      HomeMenuEntry(
        id: 'settings',
        title: (l10n) => l10n.homeMenuSettingsTitle,
        icon: Icons.tune_rounded,
        category: HomeMenuEntryCategory.preferences,
        open: (_) async {},
      ),
    ];

    // 同 pumpPopup：返回装 Future 的列表，避免 async flatten 挂死。
    // anchorKey 必须挂在已布局的按钮上（hyperosPopupPositionBelow 依赖
    // 它的 RenderBox 定位；未挂载的 key 返回 null，弹窗静默 no-op）。
    Future<List<Future<String?>?>> pumpMenu(WidgetTester tester) async {
      final opened = <Future<String?>?>[];
      final anchorKey = GlobalKey();
      await tester.pumpWidget(
        TestApp(
          home: FrostedAppearanceScope(
            appearance: gaussianAppearance,
            child: Builder(
              builder: (context) => ElevatedButton(
                key: anchorKey,
                onPressed: () {
                  opened.add(
                    showHomeTopMenuSheet(
                      context,
                      hasAvailableUpdate: false,
                      entries: entries,
                      anchorKey: anchorKey,
                    ),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return opened;
    }

    testWidgets('「添加课程」行挂二级列表，其余行没有展开箭头', (tester) async {
      await pumpMenu(tester);

      expect(find.text('添加课程'), findsOneWidget);
      expect(find.text('课表设置'), findsOneWidget);
      // 收起态只有添加课程行有箭头。
      expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
      expect(find.text('添加日程'), findsNothing);
      expect(find.text('添加考试'), findsNothing);

      await tester.tap(find.text('添加课程'));
      await tester.pumpAndSettle();

      // 主面板父行 + 卡内父行副本 + 同名子项（child「添加课程」标签复用
      // 弹层按钮文案），共 3 处。
      expect(find.text('添加课程'), findsNWidgets(3));
      expect(find.text('添加日程'), findsOneWidget);
      expect(find.text('添加考试'), findsOneWidget);
      // 「课表设置」行不重复出现（无子列表，不在浮层卡里）。
      expect(find.text('课表设置'), findsOneWidget);
    });

    testWidgets('点「添加考试」子项回传宿主分发 id', (tester) async {
      final opened = await pumpMenu(tester);

      await tester.tap(find.text('添加课程'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('添加考试'));
      await tester.pump();
      expect(await opened.single, kAddCourseSubmenuExamId);
    });
  });
}
