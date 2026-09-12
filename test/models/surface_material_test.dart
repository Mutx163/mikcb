// 各表面当前材质的推导口径测试（与渲染侧门控同口径）。
//
// 关键口径：
// - 弹窗面板（底部弹窗 / 选择面板 / 下拉小弹窗）在高级材质范围关时回**实体**
//   （HyperosSheetFrame solid 分支）；玻璃坞 / 选择器按钮回**磨砂**；
// - 首页玻璃带在模糊总开关关时不上高级材质（useBlur 门），回实体衬底；
// - 子页顶栏永不走高级材质；高斯卡在模糊关时降级实体。
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/header_blur_style.dart';
import 'package:university_timetable/models/surface_material.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/ui/hyperos/frosted/frosted_appearance.dart'
    show FrostedGlassMode;

void main() {
  group('出厂默认（全局磨砂 + 范围开关默认档）', () {
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

  group('全局液态：范围开关逐面生效', () {
    final s = TimetableSettings.defaults().copyWith(
      frostedGlassMode: FrostedGlassMode.liquidGlass,
    );
    test('范围开 → 液态；范围关 → 按各表面回退口径', () {
      expect(homeBandSurfaceMaterial(s), SurfaceMaterial.liquidGlass);
      expect(sheetDialogSurfaceMaterial(s), SurfaceMaterial.liquidGlass);
      expect(popupSurfaceMaterial(s), SurfaceMaterial.liquidGlass);
      expect(dockSurfaceMaterial(s), SurfaceMaterial.liquidGlass);
      // 选择面板默认关 → 实体；选择器按钮默认开 → 液态。
      expect(selectSheetSurfaceMaterial(s), SurfaceMaterial.solid);
      expect(pickerButtonsSurfaceMaterial(s), SurfaceMaterial.liquidGlass);
    });
  });

  group('全局柔光：范围关的坞回磨砂', () {
    final s = TimetableSettings.defaults().copyWith(
      frostedGlassMode: FrostedGlassMode.softGlass,
      liquidGlassDockEnabled: false,
    );
    test('带/弹窗走柔光，坞回磨砂', () {
      expect(homeBandSurfaceMaterial(s), SurfaceMaterial.softGlass);
      expect(sheetDialogSurfaceMaterial(s), SurfaceMaterial.softGlass);
      expect(dockSurfaceMaterial(s), SurfaceMaterial.frost);
    });
  });

  group('模糊总开关关（实体档）', () {
    final s = TimetableSettings.defaults().copyWith(
      frostedBlurEnabled: false,
    );
    test('全部表面实体；顶栏玻璃开关另关时玻璃带为「已关闭」', () {
      expect(homeBandSurfaceMaterial(s), SurfaceMaterial.solid);
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

  group('顶栏风格映射', () {
    test('首页高斯档 / 子页高斯档各自映射', () {
      final s = TimetableSettings.defaults().copyWith(
        headerBlurStyle: HeaderBlurStyle.gaussian,
      );
      expect(homeBandSurfaceMaterial(s), SurfaceMaterial.frostGaussian);
      expect(subpageHeaderSurfaceMaterial(s), SurfaceMaterial.frostProgressive);
      expect(
        subpageHeaderSurfaceMaterial(
          s.copyWith(subpageHeaderBlurStyle: HeaderBlurStyle.gaussian),
        ),
        SurfaceMaterial.frostGaussian,
      );
    });
  });

  test('高斯卡在模糊关时降级实体', () {
    final gaussianCard = TimetableSettings.defaults().copyWith(
      courseCardSurfaceStyle: CourseCardSurfaceStyle.gaussian,
    );
    expect(courseCardSurfaceMaterial(gaussianCard), SurfaceMaterial.frostGaussian);
    expect(
      courseCardSurfaceMaterial(
        gaussianCard.copyWith(frostedBlurEnabled: false),
      ),
      SurfaceMaterial.solid,
    );
  });
}
