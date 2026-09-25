// 各表面当前材质的推导口径测试（与渲染侧门控同口径）。
//
// 关键口径：
// - 首页顶栏材质独立自由选择，2026-09-20 起收成**「液态 / 实体」两档**
//   （与外观编辑器里那两个选项逐字一致）：非实体即液态，存量渐进/高斯/柔光
//   在设置层已归到液态，这里再兜一层；液态沿用模糊总开关的 useBlur 门
//   （关 → 实体衬底）；
// - 弹窗家族（底部弹窗与对话框 / 对话式全屏选择面板 / 下拉小弹窗 / 壁纸选点
//   按钮）自 2026-09-19 起**恒为液态玻璃**：锁标准档、不再看任何用户设置，
//   四个「作用范围」开关连同它们的分派逻辑一并删除（用户口径：「不允许用户
//   调整这些的材质」）；设备级 shader / 系统降级不在本推导范围内；
// - 玻璃坞跟随用户档位：「作用范围 → 底栏」关 → 回磨砂（实体档回实体）；
// - 子页顶栏永不走高级材质；高斯/液态卡在模糊关**或无壁纸**时降级实体
//   （与 effectiveCourseCardSurfaceStyle 的 hasHomePageBackdrop 口径同源）。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/surface_material.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/ui/hyperos/frosted/frosted_appearance.dart'
    show FrostedGlassMode;

void main() {
  group('出厂默认（全局磨砂 + 顶栏液态玻璃）', () {
    final s = TimetableSettings.defaults();
    test('顶栏已按界面承诺落在液态玻璃，其余表面落在基础磨砂系', () {
      expect(homeBandSurfaceMaterial(s), SurfaceMaterial.liquidGlass);
      expect(subpageHeaderSurfaceMaterial(s), SurfaceMaterial.frostProgressive);
      expect(dockSurfaceMaterial(s), SurfaceMaterial.frost);
      // 弹窗家族锁标准档：全局还是磨砂，它们也已经是液态玻璃。
      expect(pinnedChromeSurfaceMaterial(), SurfaceMaterial.liquidGlass);
      expect(courseCardSurfaceMaterial(s), SurfaceMaterial.solid);
    });
  });

  group('首页顶栏材质两档（独立于全局）', () {
    test('模糊开：两档逐一映射，存量中间档也读成液态', () {
      final cases = {
        'liquid': SurfaceMaterial.liquidGlass,
        'solid': SurfaceMaterial.solid,
        // 存量中间档：界面早就把它们显示成液态，推导必须同口径，
        // 否则「各表面当前材质」地图卡会显示成用户根本选不到的档位。
        'progressive': SurfaceMaterial.liquidGlass,
        'gaussian': SurfaceMaterial.liquidGlass,
        'soft': SurfaceMaterial.liquidGlass,
      };
      cases.forEach((material, expected) {
        final s = TimetableSettings.defaults().copyWith(
          homeBandGlassMaterial: material,
        );
        expect(homeBandSurfaceMaterial(s), expected, reason: '$material 档');
      });
    });

    test('跟随默认（2026-09-23）：按默认档解析，地图显示生效材质', () {
      final base = TimetableSettings.defaults().copyWith(
        homeBandGlassMaterial: 'follow',
      );
      // 默认档高斯 → 磨砂带（渐进模糊链路）。
      expect(homeBandSurfaceMaterial(base), SurfaceMaterial.frostProgressive);
      // 默认档液态 → 液态带。
      expect(
        homeBandSurfaceMaterial(
          base.copyWith(frostedGlassMode: FrostedGlassMode.liquidGlass),
        ),
        SurfaceMaterial.liquidGlass,
      );
      // 默认档实体（模糊总开关关）→ 实心带。
      expect(
        homeBandSurfaceMaterial(base.copyWith(frostedBlurEnabled: false)),
        SurfaceMaterial.solid,
      );
    });

    test('模糊关：液态回落实体，实体档仍是实体', () {
      final liquid = TimetableSettings.defaults().copyWith(
        frostedBlurEnabled: false,
        homeBandGlassMaterial: 'liquid',
      );
      expect(homeBandSurfaceMaterial(liquid), SurfaceMaterial.solid);

      final solid = TimetableSettings.defaults().copyWith(
        frostedBlurEnabled: false,
        homeBandGlassMaterial: 'solid',
      );
      expect(homeBandSurfaceMaterial(solid), SurfaceMaterial.solid);
    });

    test('「顶栏玻璃」开关关 → 已关闭', () {
      final s = TimetableSettings.defaults().copyWith(
        homeBandGlassMaterial: 'liquid',
        homePageHeaderBlurEnabled: false,
      );
      expect(homeBandSurfaceMaterial(s), SurfaceMaterial.off);
    });

    test('顶栏材质不随全局玻璃模式走（自由选择的回归钉）', () {
      // 全局柔光 + 顶栏液态：顶栏是液态，不是柔光。
      final s = TimetableSettings.defaults().copyWith(
        frostedGlassMode: FrostedGlassMode.liquidGlass,
        homeBandGlassMaterial: 'liquid',
      );
      expect(homeBandSurfaceMaterial(s), SurfaceMaterial.liquidGlass);
      // 弹窗家族仍是液态玻璃（锁标准档，与全局模式无关）。
      expect(pinnedChromeSurfaceMaterial(), SurfaceMaterial.liquidGlass);
    });
  });

  group('玻璃坞跟随用户档位', () {
    test('全局柔光：坞范围开走柔光，范围关回磨砂', () {
      final open = TimetableSettings.defaults().copyWith(
        frostedGlassMode: FrostedGlassMode.liquidGlass,
      );
      expect(dockSurfaceMaterial(open), SurfaceMaterial.liquidGlass);
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
    test('子页顶栏锁死渐进：模糊开着就报渐进，不可能是高斯', () {
      // 2026-09-23 起子页顶栏那把轴（渐进 / 高斯）整体撤下，设置里不再有
      // subpageHeaderBlurStyle —— 所以这里只剩「模糊开 / 关」两种结果。
      final s = TimetableSettings.defaults();
      expect(s.frostedBlurEnabled, isTrue, reason: '前提：出厂模糊是开的');
      expect(subpageHeaderSurfaceMaterial(s), SurfaceMaterial.frostProgressive);
      expect(
        subpageHeaderSurfaceMaterial(
          s.copyWith(frostedBlurEnabled: false),
        ),
        SurfaceMaterial.solid,
      );
    });
  });

  test('玻璃档依赖壁纸：无壁纸降级实体，有壁纸才报高斯/液态', () async {
    final gaussianCard = TimetableSettings.defaults().copyWith(
      courseCardSurfaceStyle: CourseCardSurfaceStyle.gaussian,
    );
    final liquidCard = TimetableSettings.defaults().copyWith(
      courseCardSurfaceStyle: CourseCardSurfaceStyle.liquidGlass,
    );
    // 无壁纸：渲染侧真实出图是实体卡，地图必须同口径（就地归真，
    // 2026-09-25），不许挂着「高斯/液态」招摇。
    expect(courseCardSurfaceMaterial(gaussianCard), SurfaceMaterial.solid);
    expect(courseCardSurfaceMaterial(liquidCard), SurfaceMaterial.solid);

    final dir = await Directory.systemTemp.createTemp('surface_material_wall');
    final file = File('${dir.path}/wall.png')..writeAsBytesSync([1, 2, 3, 4]);
    addTearDown(() => dir.deleteSync(recursive: true));
    final withWall = gaussianCard.copyWith(homePageWallpaperPath: file.path);
    final liquidWithWall = liquidCard.copyWith(
      homePageWallpaperPath: file.path,
    );

    expect(courseCardSurfaceMaterial(withWall), SurfaceMaterial.frostGaussian);
    expect(
      courseCardSurfaceMaterial(liquidWithWall),
      SurfaceMaterial.liquidGlass,
    );
    // 模糊总开关关（全局实体档）：有壁纸也照样降级实体。
    expect(
      courseCardSurfaceMaterial(
        withWall.copyWith(frostedBlurEnabled: false),
      ),
      SurfaceMaterial.solid,
    );
  });
}
