// 各表面当前材质的推导口径测试（与渲染侧门控同口径）。
//
// 关键口径：
// - 首页顶栏材质独立自由五档（2026-09-12）：渐进/高斯/柔光/液态/实体，
//   不随全局玻璃模式或「作用范围」开关；柔光/液态沿用模糊总开关的
//   useBlur 门（关 → 实体衬底）；
// - 弹窗面板（底部弹窗 / 选择面板 / 下拉小弹窗）在高级材质范围关时回**实体**
//   （HyperosSheetFrame solid 分支）；玻璃坞 / 选择器按钮回**磨砂**；
// - 子页顶栏永不走高级材质；高斯卡在模糊关时降级实体。
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/header_blur_style.dart';
import 'package:university_timetable/models/surface_material.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/ui/hyperos/frosted/frosted_appearance.dart'
    show FrostedGlassMode;

void main() {
  group('出厂默认（全局磨砂 + 顶栏渐进磨砂）', () {
    final s = TimetableSettings.defaults();
    test('各表面落在基础磨砂系', () {
      expect(homeBandSurfaceMaterial(s), SurfaceMaterial.frostProgressive);
      expect(subpageHeaderSurfaceMaterial(s), SurfaceMaterial.frostProgressive);
      expect(dockSurfaceMaterial(s), SurfaceMaterial.frost);
      expect(sheetDialogSurfaceMaterial(s), SurfaceMaterial.frost);
      // 选择面板范围开关默认关，但全局非高级材质时不受它影响。
      expect(selectSheetSurfaceMaterial(s), SurfaceMaterial.frost);
      expect(popupSurfaceMaterial(s), SurfaceMaterial.frost);
      expect(pickerButtonsSurfaceMaterial(s), SurfaceMaterial.frost);
      expect(courseCardSurfaceMaterial(s), SurfaceMaterial.solid);
    });
  });

  group('首页顶栏材质五档（独立于全局）', () {
    test('模糊开：五档逐一映射', () {
      final cases = {
        'progressive': SurfaceMaterial.frostProgressive,
        'gaussian': SurfaceMaterial.frostGaussian,
        'soft': SurfaceMaterial.softGlass,
        'liquid': SurfaceMaterial.liquidGlass,
        'solid': SurfaceMaterial.solid,
      };
      cases.forEach((material, expected) {
        final s = TimetableSettings.defaults().copyWith(
          homeBandGlassMaterial: material,
        );
        expect(homeBandSurfaceMaterial(s), expected, reason: material);
      });
    });

    test('模糊总开关关：全部回实体衬底', () {
      for (final material in TimetableSettings.homeBandGlassMaterialValues) {
        final s = TimetableSettings.defaults().copyWith(
          homeBandGlassMaterial: material,
          frostedBlurEnabled: false,
        );
        expect(homeBandSurfaceMaterial(s), SurfaceMaterial.solid,
            reason: material);
      }
    });

    test('「顶栏玻璃」开关关 → 已关闭', () {
      final s = TimetableSettings.defaults().copyWith(
        homeBandGlassMaterial: 'liquid',
        homePageHeaderBlurEnabled: false,
      );
      expect(homeBandSurfaceMaterial(s), SurfaceMaterial.off);
    });

    test('顶栏材质不随全局玻璃模式走（自由选择的回归钉）', () {
      // 全局柔光 + 顶栏高斯磨砂：顶栏是磨砂，不是柔光。
      final s = TimetableSettings.defaults().copyWith(
        frostedGlassMode: FrostedGlassMode.softGlass,
        homeBandGlassMaterial: 'gaussian',
      );
      expect(homeBandSurfaceMaterial(s), SurfaceMaterial.frostGaussian);
      // 其他表面仍跟随全局柔光。
      expect(sheetDialogSurfaceMaterial(s), SurfaceMaterial.softGlass);
    });
  });

  group('全局柔光：范围关的坞回磨砂', () {
    final s = TimetableSettings.defaults().copyWith(
      frostedGlassMode: FrostedGlassMode.softGlass,
      liquidGlassDockEnabled: false,
    );
    test('弹窗走柔光，坞回磨砂', () {
      expect(sheetDialogSurfaceMaterial(s), SurfaceMaterial.softGlass);
      expect(dockSurfaceMaterial(s), SurfaceMaterial.frost);
    });
  });

  group('全局液态：范围开关逐面生效', () {
    final s = TimetableSettings.defaults().copyWith(
      frostedGlassMode: FrostedGlassMode.liquidGlass,
    );
    test('范围开 → 液态；范围关 → 按各表面回退口径', () {
      expect(sheetDialogSurfaceMaterial(s), SurfaceMaterial.liquidGlass);
      expect(popupSurfaceMaterial(s), SurfaceMaterial.liquidGlass);
      expect(dockSurfaceMaterial(s), SurfaceMaterial.liquidGlass);
      // 选择面板默认关 → 实体；选择器按钮默认开 → 液态。
      expect(selectSheetSurfaceMaterial(s), SurfaceMaterial.solid);
      expect(pickerButtonsSurfaceMaterial(s), SurfaceMaterial.liquidGlass);
    });
  });

  group('模糊总开关关（实体档）', () {
    final s = TimetableSettings.defaults().copyWith(
      frostedBlurEnabled: false,
    );
    test('弹窗/坞等全部实体；顶栏玻璃开关另关时玻璃带为「已关闭」', () {
      expect(subpageHeaderSurfaceMaterial(s), SurfaceMaterial.solid);
      expect(dockSurfaceMaterial(s), SurfaceMaterial.solid);
      expect(sheetDialogSurfaceMaterial(s), SurfaceMaterial.solid);
      expect(courseCardSurfaceMaterial(s), SurfaceMaterial.solid);
      expect(
        homeBandSurfaceMaterial(s.copyWith(homePageHeaderBlurEnabled: false)),
        SurfaceMaterial.off,
      );
    });
  });

  group('顶栏风格映射（子页）', () {
    test('子页高斯档映射 frostGaussian', () {
      final s = TimetableSettings.defaults().copyWith(
        subpageHeaderBlurStyle: HeaderBlurStyle.gaussian,
      );
      expect(subpageHeaderSurfaceMaterial(s), SurfaceMaterial.frostGaussian);
    });
  });

  test('高斯卡在模糊关时降级实体', () {
    final gaussianCard = TimetableSettings.defaults().copyWith(
      courseCardSurfaceStyle: CourseCardSurfaceStyle.gaussian,
    );
    expect(
        courseCardSurfaceMaterial(gaussianCard), SurfaceMaterial.frostGaussian);
    expect(
      courseCardSurfaceMaterial(
        gaussianCard.copyWith(frostedBlurEnabled: false),
      ),
      SurfaceMaterial.solid,
    );
  });
}
