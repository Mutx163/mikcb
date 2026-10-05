import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/utils/home_page_background.dart';

/// 回归钉（第 27 轮，壁纸亮度带的采样缓存键漏了「放大倍数」这一维）。
///
/// 亮度带的取值依赖取景：`sampleHomePageBackdropLuminanceBands`
/// （home_page_background.dart:936-951）内部按 `settings.homePageWallpaperScale`
/// 采样，几何上「缩放窗口 = 可见比例 ÷ 倍数」（:896-901），
/// `kWallpaperMaxScale = 4` —— 也就是说**只改放大倍数**也会换掉屏上那一条带。
/// 而缓存键有三份副本，其中两份只写 `路径|视口|alignX|alignY`：
/// - `timetable_screen.dart` 的 `_wallpaperLuminanceKey`（首页 chrome 墨色的门禁，
///   :2326-2330 与 :2376-2381 两处都按它判断「已经采过了就 return」）；
/// - `timetable_week_preview.dart` 的 `_sampleLuminance`（外观编辑页预览带）。
/// 只有取景页自己那份（`wallpaper_position_picker_sheet.dart`）带上了 `|$_scale`。
///
/// 可达路径：设置 → 首页壁纸 → 取景页**双指原地捏合**（`focalPointDelta≈0` 时
/// align 不变、只有 scale 变）→ 保存回首页。首页的顶栏标题、状态栏图标、星期条
/// 与卡片区墨色仍按放大前那条带判定：壁纸顶部从天空（亮）被放大成暗部时，
/// 白字压白底看不清，且**不会自愈** —— 要等用户再拖一次位置或冷启动。
/// 该键自己的注释也承诺「so a cover crop change cannot keep using a sample from an
/// off-screen part of the image」，而 zoom 正是 cover crop 的一部分。
void main() {
  String key({
    double alignX = 0,
    double alignY = 0,
    double scale = 1,
    String viewportKey = '393x852',
  }) {
    return homePageBackdropSampleKey(
      path: '/wallpapers/a.jpg',
      viewportKey: viewportKey,
      alignX: alignX,
      alignY: alignY,
      scale: scale,
    );
  }

  test('只改放大倍数也必须换键（亮度带依赖它）', () {
    expect(
      key(scale: 3),
      isNot(key()),
      reason: '修复前首页与预览页的键里没有 scale，纯缩放不会重采',
    );
    expect(key(scale: 1.0001), isNot(key(scale: 1.0002)));
  });

  test('取景三要素与视口共同决定键，全部相同才是同一个键', () {
    expect(key(alignX: -1), isNot(key(alignX: 1)));
    expect(key(alignY: 0.5), isNot(key(alignY: -0.5)));
    expect(key(viewportKey: '412x915'), isNot(key()));
    expect(key(), key());
  });

  test('越界的对齐值与倍数先归一，不产生额外档位', () {
    expect(key(alignX: 4), key(alignX: 1));
    expect(key(alignY: -9), key(alignY: -1));
    expect(
      key(scale: 9),
      key(scale: kWallpaperMaxScale),
      reason: '采样端按 kWallpaperMinScale..kWallpaperMaxScale 钳制，键必须同口径',
    );
  });

  test('三份采样缓存键副本必须都走这一个构造器', () {
    const sites = [
      'lib/screens/timetable_screen.dart',
      'lib/widgets/timetable_week_preview.dart',
      'lib/widgets/wallpaper_position_picker_sheet.dart',
    ];
    final offenders = <String>[];
    for (final path in sites) {
      final source = File(path).readAsStringSync();
      if (!source.contains('homePageBackdropSampleKey(')) {
        offenders.add(path);
      }
      if (RegExp(r'viewport(Size)?\.width\}x').hasMatch(source)) {
        offenders.add('$path（仍在手工拼视口段）');
      }
    }
    expect(offenders, isEmpty, reason: '亮度带缓存键只该有一份构造器');
  });
}
