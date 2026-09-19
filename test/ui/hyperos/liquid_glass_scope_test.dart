import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/screens/timetable_settings_screen.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';
import 'package:university_timetable/ui/hyperos/liquid/liquid_glass_surface.dart';

import '../../helpers_test_app.dart';

/// 「液态玻璃作用范围」开关：**2026-09-19 起只剩底栏一条**。
///
/// 历史：这里曾有五个逐表面开关（下拉小弹窗 / 全屏选择面板 / 弹窗与对话框 /
/// 玻璃坞 / 壁纸选点按钮）。弹窗家族的四个整体删除 —— 那些表面锁成「永远液态
/// 玻璃的标准档」（[LiquidGlassRole.pinnedChrome]），用户改不动，开关存不存在
/// 都不影响出图；「首页玻璃带」开关更早（2026-09-12）随顶栏材质五档自由选择
/// 退役。坞跟随用户档位，故保留。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  FrostedAppearance liquidAppearance({bool dock = true}) {
    final settings = TimetableSettings.defaults().copyWith(
      frostedBlurEnabled: true,
      frostedGlassMode: FrostedGlassMode.liquidGlass,
      liquidGlassDockEnabled: dock,
    );
    return settings.frostedAppearance;
  }

  group('液态玻璃作用范围：模型层', () {
    test('默认值：只剩底栏开关，默认为开', () {
      final d = TimetableSettings.defaults();
      expect(d.liquidGlassDockEnabled, isTrue);
    });

    test('frostedAppearance 映射底栏开关', () {
      final a = liquidAppearance(dock: false);
      expect(a.glassMode, FrostedGlassMode.liquidGlass);
      expect(a.liquidGlassDockEnabled, isFalse);
      expect(liquidAppearance().liquidGlassDockEnabled, isTrue);
    });

    test('JSON 往返保留开关；老档案缺键回退默认值', () {
      final custom = TimetableSettings.defaults().copyWith(
        liquidGlassDockEnabled: false,
      );
      final restored = TimetableSettings.fromJson(custom.toJson());
      expect(restored.liquidGlassDockEnabled, isFalse);

      final legacy = TimetableSettings.fromJson(const {'sections': []});
      expect(legacy.liquidGlassDockEnabled, isTrue);
    });

    test('老档案里删掉的那四个开关键被静默忽略（不再读回）', () {
      // 升级路径：用户旧存档里写着「全屏选择面板关 / 壁纸选点按钮关」，那些
      // 家族现在锁标准档，这些键必须被丢掉而不是报错或改变矩阵。
      final legacy = TimetableSettings.fromJson(const {
        'sections': [],
        'liquidGlassPopupEnabled': false,
        'liquidGlassSelectSheetEnabled': true,
        'liquidGlassSheetDialogEnabled': false,
        'liquidGlassPickerButtonsEnabled': false,
      });
      expect(legacy.liquidGlassDockEnabled, isTrue);
      expect(
        legacy.toJson().keys.where((k) => k.startsWith('liquidGlass')),
        contains('liquidGlassDockEnabled'),
      );
    });

    test('外观恢复默认作用域覆盖底栏开关', () {
      final dirty = TimetableSettings.defaults().copyWith(
        liquidGlassDockEnabled: false,
      );
      final reset = applySettingsReset(dirty, SettingsResetScope.appearance);
      expect(reset.liquidGlassDockEnabled, isTrue);
    });
  });

  group('液态玻璃作用范围：表面材质判定', () {
    Future<void> pumpAndOpen(
      WidgetTester tester, {
      required FrostedAppearance appearanceValue,
      required void Function(BuildContext) onOpen,
    }) async {
      await tester.pumpWidget(
        TestApp(
          home: FrostedAppearanceScope(
            appearance: appearanceValue,
            child: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => onOpen(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    Future<void> openSelectPopup(
      WidgetTester tester, {
      required FrostedAppearance appearanceValue,
    }) {
      return pumpAndOpen(
        tester,
        appearanceValue: appearanceValue,
        onOpen: (context) => showHyperosSelectPopup<String>(
          context: context,
          anchorRect: const Rect.fromLTWH(24, 24, 160, 48),
          items: const {'Option A': 'a'},
          currentValue: 'a',
        ),
      );
    }

    Future<void> openSelectSheet(
      WidgetTester tester, {
      required FrostedAppearance appearanceValue,
    }) {
      return pumpAndOpen(
        tester,
        appearanceValue: appearanceValue,
        onOpen: (context) => showHyperosSelectSheet<String>(
          context: context,
          title: 'Preset Themes',
          items: const {'Option A': 'a', 'Option B': 'b'},
          currentValue: 'a',
          cancelLabel: 'Cancel',
        ),
      );
    }

    Future<void> openDemoSheet(
      WidgetTester tester, {
      required FrostedAppearance appearanceValue,
    }) {
      return pumpAndOpen(
        tester,
        appearanceValue: appearanceValue,
        onOpen: (context) => showHyperosSheet<void>(
          context: context,
          builder: (_) => const HyperosSheetFrame(
            child: SizedBox(width: 180, height: 120),
          ),
        ),
      );
    }

    testWidgets('玻璃模式选择小弹窗：永远是标准档液态玻璃', (tester) async {
      await openSelectPopup(tester, appearanceValue: liquidAppearance());
      expect(find.byType(LiquidGlassSurface), findsOneWidget);
      expect(
        tester.widget<LiquidGlassSurface>(find.byType(LiquidGlassSurface)).role,
        LiquidGlassRole.pinnedChrome,
      );
      expect(find.text('Option A'), findsOneWidget);
    });

    testWidgets('预设主题式全屏选择面板：同样锁标准档液态玻璃', (tester) async {
      await openSelectSheet(tester, appearanceValue: liquidAppearance());
      expect(find.byType(LiquidGlassSurface), findsOneWidget);
      expect(
        tester.widget<LiquidGlassSurface>(find.byType(LiquidGlassSurface)).role,
        LiquidGlassRole.pinnedChrome,
      );
      expect(find.byType(HyperosSheetFrame), findsOneWidget);
    });

    testWidgets('弹窗与对话框：永远是标准档液态玻璃', (tester) async {
      await openDemoSheet(tester, appearanceValue: liquidAppearance());
      expect(find.byType(LiquidGlassSurface), findsOneWidget);
      expect(
        tester.widget<LiquidGlassSurface>(find.byType(LiquidGlassSurface)).role,
        LiquidGlassRole.pinnedChrome,
      );
      expect(find.byType(HyperosSheetFrame), findsOneWidget);
    });
  });
}
