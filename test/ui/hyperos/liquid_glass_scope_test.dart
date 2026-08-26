import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/screens/timetable_settings_screen.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';
import 'package:university_timetable/ui/hyperos/liquid/hyperos_liquid_glass_surface.dart';

import '../../helpers_test_app.dart';

/// 「液态玻璃作用范围」逐表面开关：默认值、持久化与各表面家族的材质判定。
///
/// 默认约定（外观与配色 → 磨砂玻璃）：
/// - 下拉选择弹窗（玻璃模式等设置行的小气泡）→ 开；
/// - 全屏选择面板（预设主题/字体等长列表弹窗）→ 关；
/// - 弹窗与对话框 / 首页玻璃带 / 玻璃坞导航 → 维持既有行为（开）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  FrostedAppearance liquidAppearance({
    bool popup = true,
    bool selectSheet = false,
    bool sheetDialog = true,
    bool homeChrome = true,
    bool dock = true,
    bool pickerButtons = true,
  }) {
    final settings = TimetableSettings.defaults().copyWith(
      frostedBlurEnabled: true,
      frostedGlassMode: FrostedGlassMode.liquidGlass,
      liquidGlassPopupEnabled: popup,
      liquidGlassSelectSheetEnabled: selectSheet,
      liquidGlassSheetDialogEnabled: sheetDialog,
      liquidGlassHomeChromeEnabled: homeChrome,
      liquidGlassDockEnabled: dock,
      liquidGlassPickerButtonsEnabled: pickerButtons,
    );
    return settings.frostedAppearance;
  }

  group('液态玻璃作用范围：模型层', () {
    test('默认值：下拉弹窗开、全屏选择面板关、其余开', () {
      final d = TimetableSettings.defaults();
      expect(d.liquidGlassPopupEnabled, isTrue);
      expect(d.liquidGlassSelectSheetEnabled, isFalse);
      expect(d.liquidGlassSheetDialogEnabled, isTrue);
      expect(d.liquidGlassHomeChromeEnabled, isTrue);
      expect(d.liquidGlassDockEnabled, isTrue);
      expect(d.liquidGlassPickerButtonsEnabled, isTrue);
    });

    test('frostedAppearance 映射六个开关', () {
      final a = liquidAppearance(selectSheet: false, dock: false);
      expect(a.glassMode, FrostedGlassMode.liquidGlass);
      expect(a.liquidGlassPopupEnabled, isTrue);
      expect(a.liquidGlassSelectSheetEnabled, isFalse);
      expect(a.liquidGlassSheetDialogEnabled, isTrue);
      expect(a.liquidGlassHomeChromeEnabled, isTrue);
      expect(a.liquidGlassDockEnabled, isFalse);
      expect(a.liquidGlassPickerButtonsEnabled, isTrue);
    });

    test('JSON 往返保留开关；老档案缺键回退默认值', () {
      final custom = TimetableSettings.defaults().copyWith(
        liquidGlassPopupEnabled: false,
        liquidGlassSelectSheetEnabled: true,
        liquidGlassSheetDialogEnabled: false,
        liquidGlassHomeChromeEnabled: false,
        liquidGlassDockEnabled: false,
        liquidGlassPickerButtonsEnabled: false,
      );
      final restored = TimetableSettings.fromJson(custom.toJson());
      expect(restored.liquidGlassPopupEnabled, isFalse);
      expect(restored.liquidGlassSelectSheetEnabled, isTrue);
      expect(restored.liquidGlassSheetDialogEnabled, isFalse);
      expect(restored.liquidGlassHomeChromeEnabled, isFalse);
      expect(restored.liquidGlassDockEnabled, isFalse);
      expect(restored.liquidGlassPickerButtonsEnabled, isFalse);

      final legacy = TimetableSettings.fromJson(const {'sections': []});
      expect(legacy.liquidGlassPopupEnabled, isTrue);
      expect(legacy.liquidGlassSelectSheetEnabled, isFalse);
      expect(legacy.liquidGlassSheetDialogEnabled, isTrue);
      expect(legacy.liquidGlassHomeChromeEnabled, isTrue);
      expect(legacy.liquidGlassDockEnabled, isTrue);
      expect(legacy.liquidGlassPickerButtonsEnabled, isTrue);
    });

    test('外观恢复默认作用域覆盖五个开关', () {
      final dirty = TimetableSettings.defaults().copyWith(
        liquidGlassPopupEnabled: false,
        liquidGlassSelectSheetEnabled: true,
        liquidGlassSheetDialogEnabled: false,
        liquidGlassHomeChromeEnabled: false,
        liquidGlassDockEnabled: false,
        liquidGlassPickerButtonsEnabled: false,
      );
      final reset = applySettingsReset(dirty, SettingsResetScope.appearance);
      expect(reset.liquidGlassPopupEnabled, isTrue);
      expect(reset.liquidGlassSelectSheetEnabled, isFalse);
      expect(reset.liquidGlassSheetDialogEnabled, isTrue);
      expect(reset.liquidGlassHomeChromeEnabled, isTrue);
      expect(reset.liquidGlassDockEnabled, isTrue);
      expect(reset.liquidGlassPickerButtonsEnabled, isTrue);
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

    testWidgets('玻璃模式选择小弹窗：默认跟随液态玻璃', (tester) async {
      await openSelectPopup(tester, appearanceValue: liquidAppearance());
      expect(find.byType(HyperosLiquidGlassSurface), findsOneWidget);
    });

    testWidgets('玻璃模式选择小弹窗：开关关闭回退磨砂', (tester) async {
      await openSelectPopup(
        tester,
        appearanceValue: liquidAppearance(popup: false),
      );
      expect(find.byType(HyperosLiquidGlassSurface), findsNothing);
      expect(find.text('Option A'), findsOneWidget);
    });

    testWidgets('预设主题式全屏选择面板：默认保持磨砂', (tester) async {
      await openSelectSheet(tester, appearanceValue: liquidAppearance());
      expect(find.byType(HyperosLiquidGlassSurface), findsNothing);
      expect(find.byType(HyperosSheetFrame), findsOneWidget);
    });

    testWidgets('全屏选择面板：打开后应用液态玻璃', (tester) async {
      await openSelectSheet(
        tester,
        appearanceValue: liquidAppearance(selectSheet: true),
      );
      expect(find.byType(HyperosLiquidGlassSurface), findsOneWidget);
    });

    testWidgets('弹窗与对话框：默认仍为液态玻璃', (tester) async {
      await openDemoSheet(tester, appearanceValue: liquidAppearance());
      expect(find.byType(HyperosLiquidGlassSurface), findsOneWidget);
    });

    testWidgets('弹窗与对话框：开关关闭回退磨砂', (tester) async {
      await openDemoSheet(
        tester,
        appearanceValue: liquidAppearance(sheetDialog: false),
      );
      expect(find.byType(HyperosLiquidGlassSurface), findsNothing);
      expect(find.byType(HyperosSheetFrame), findsOneWidget);
    });
  });
}
