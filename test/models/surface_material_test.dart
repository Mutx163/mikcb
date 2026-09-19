// 各表面当前材质的推导口径测试（与渲染侧门控同口径）。
//
// 关键口径：
// - 首页顶栏材质独立自由五档（2026-09-12）：渐进/高斯/柔光/液态/实体，
//   不随全局玻璃模式或「作用范围」开关；柔光/液态沿用模糊总开关的
//   useBlur 门（关 → 实体衬底）；
// - 弹窗家族（底部弹窗与对话框 / 对话式全屏选择面板 / 下拉小弹窗 / 壁纸选点
//   按钮）自 2026-09-19 起**恒为液态玻璃**：锁标准档、不再看任何用户设置，
//   四个「作用范围」开关连同它们的分派逻辑一并删除（用户口径：「不允许用户
//   调整这些的材质」）；设备级 shader / 系统降级不在本推导范围内；
// - 玻璃坞跟随用户档位：「作用范围 → 底栏」关 → 回磨砂（实体档回实体）；
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
    test('各表面落在基础磨砂系，弹窗家族已是液态玻璃', () {
      expect(homeBandSurfaceMaterial(s), SurfaceMaterial.frostProgressive);
      expect(subpageHeaderSurfaceMaterial(s), SurfaceMaterial.frostProgressive);
      expect(dockSurfaceMaterial(s), SurfaceMaterial.frost);
      // 弹窗家族锁标准档：全局还是磨砂，它们也已经是液态玻璃。
      expect(pinnedChromeSurfaceMaterial(), SurfaceMaterial.liquidGlass);
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
        expect(homeBandSurfaceMaterial(s), expected, reason: '$material 档');
      });
    });

    test('模糊关：柔光/液态回落实体，其余仍是磨砂系', () {
      final s = TimetableSettings.defaults().copyWith(
        frostedBlurEnabled: false,
        homeBandGlassMaterial: 'liquid',
      );
      expect(homeBandSurfaceMaterial(s), SurfaceMaterial.solid);
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
      // 弹窗家族仍是液态玻璃（锁标准档，与全局模式无关）。
      expect(pinnedChromeSurfaceMaterial(), SurfaceMaterial.liquidGlass);
    });
  });

  group('玻璃坞跟随用户档位', () {
    test('全局柔光：坞范围开走柔光，范围关回磨砂', () {
      final open = TimetableSettings.defaults().copyWith(
        frostedGlassMode: FrostedGlassMode.softGlass,
      );
      expect(dockSurfaceMaterial(open), SurfaceMaterial.softGlass);
      expect(
        dockSurfaceMaterial(open.copyWith(liquidGlassDockEnabled: false)),
        SurfaceMaterial.frost,
      );
    });

    test('全局液态：坞范围开走液态，范围关回磨砂', () {
      final s = TimetableSettings.defaults().copyWith(
        frostedGlassMode: FrostedGlassMode.liquidGlass,
      );
      expect(dockSurfaceMaterial(s), SurfaceMaterial.liquidGlass);
      expect(
        dockSurfaceMaterial(s.copyWith(liquidGlassDockEnabled: false)),
        SurfaceMaterial.frost,
      );
    });
  });

  group('弹窗家族锁标准档：与用户设置无关', () {
    test('读数不看设置，恒为液态玻璃', () {
      // 这条不是「在很多设置下都成立」的循环 —— [pinnedChromeSurfaceMaterial]
      // 压根不收 TimetableSettings，用户侧没有任何旋钮能改到它。写不下来才怪，
      // 所以这里只钉住返回值本身。
      expect(pinnedChromeSurfaceMaterial(), SurfaceMaterial.liquidGlass);
    });
  });

  group('模糊总开关关（实体档）', () {
    final s = TimetableSettings.defaults().copyWith(frostedBlurEnabled: false);
    test('基础材质表面全部实体；顶栏玻璃开关另关时玻璃带为「已关闭」', () {
      expect(subpageHeaderSurfaceMaterial(s), SurfaceMaterial.solid);
      expect(dockSurfaceMaterial(s), SurfaceMaterial.solid);
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
