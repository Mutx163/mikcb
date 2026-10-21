import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/utils/home_page_background.dart';
import 'package:university_timetable/utils/home_startup_visual_primer.dart';
import 'package:university_timetable/utils/home_wallpaper_luminance_share.dart';
import 'package:university_timetable/utils/page_wallpaper_luminance.dart';

/// 进入月视图时**不许先闪一次错误墨色**（2026-10-21 报）。
///
/// ## 症状与根因
///
/// 用户：「为什么底栏切到月视图的时候，这个页面的字都会闪黑再闪白」。
///
/// 根因是首帧**不知道壁纸亮度**：采样器 `_value` 初始 null，所有判墨（顶栏标题、
/// 工具行、网格日期、议程卡）都回落到主题色；等读图解码完成（几十到几百毫秒）
/// 才 setState 换成壁纸极性 —— 于是「先一个极性、再另一个极性」。
///
/// 首页早在 2026-10-19 踩过同一个坑（进设置时星期栏闪白再闪回来），解法是
/// `HomeWallpaperLuminanceShare` + `HomeStartupVisualPrimer` 两级缓存。
/// 月视图之前**两级都没接**，所以每次进入必闪。
///
/// 本测试钉的就是「首帧能拿到缓存里的读数，不必等解码」。
void _noop() {}

void main() {
  // 壁纸路径必须**真实存在**：`homePageBackdropKey` 会同步 stat 一次，
  // 文件不在就当作"没有壁纸"，`pull` 直接早退（本仓口径见该函数注释）。
  late Directory tmp;
  late String path;
  late TimetableSettings settings;

  setUp(() {
    HomeWallpaperLuminanceShare.resetForTesting();
    tmp = Directory.systemTemp.createTempSync('pg_lum_');
    final wallpaper = File('${tmp.path}/wallpaper.png')
      ..writeAsBytesSync(const [137, 80, 78, 71, 13, 10, 26, 10]);
    path = wallpaper.path;
    settings = TimetableSettings(
      sections: const [],
      homePageWallpaperPath: path,
    );
  });

  tearDown(() {
    if (tmp.existsSync()) {
      tmp.deleteSync(recursive: true);
    }
  });

  String keyFor(Size viewport) => homePageBackdropSampleKey(
    path: path,
    viewportKey: homePageBackdropViewportKey(viewport),
    alignX: settings.homePageWallpaperAlignX,
    alignY: settings.homePageWallpaperAlignY,
    scale: settings.homePageWallpaperScale,
  );

  test('共享缓存命中时：pull 立刻给出读数，不必等异步采样', () {
    const viewport = Size(393, 852);
    HomeWallpaperLuminanceShare.publish(
      keyFor(viewport),
      (top: 0.12, weekday: 0.2, body: 0.3),
    );

    final sampler = PageWallpaperLuminanceSampler()..setViewport(viewport);
    var changes = 0;
    void onChange() => changes++;
    sampler.pull(settings, onChange);

    // 关键：**同步**就有值 —— 首帧就能按正确极性画，不会先主题色再翻面。
    expect(
      sampler.value,
      isNotNull,
      reason: '缓存命中却仍返回 null ⇒ 首帧回落主题色 ⇒ 用户看到闪黑闪白',
    );
    expect(sampler.value!.top, closeTo(0.12, 1e-9));
    expect(sampler.value!.body, closeTo(0.3, 1e-9));
    expect(changes, 1, reason: '拿到值要通知页面重建（一次即可）');
    sampler.dispose();
  });

  test('视口不同但取景相同：忽略视口仍命中（进出页面 inset 变化）', () {
    HomeWallpaperLuminanceShare.publish(
      keyFor(const Size(393, 852)),
      (top: 0.1, weekday: 0.1, body: 0.1),
    );
    final sampler = PageWallpaperLuminanceSampler()
      ..setViewport(const Size(393, 800));
    sampler.pull(settings, _noop);
    expect(
      sampler.value,
      isNotNull,
      reason: '视口差几个像素就回落猜极性，正是"闪一次"的经典场景',
    );
    sampler.dispose();
  });

  test('启动预热可作为第二级兜底', () {
    HomeStartupVisualPrimer.debugSeedBands(
      path,
      (top: 0.9, weekday: 0.9, body: 0.9),
    );
    final sampler = PageWallpaperLuminanceSampler()
      ..setViewport(const Size(393, 852));
    sampler.pull(settings, _noop);
    // 预热只看路径，所以即使视口不同也能直接用。
    expect(sampler.value, isNotNull, reason: '冷启动首帧也要有不闪的极值');
    sampler.dispose();
  });

  test('采样键必须与首页 chrome 同格式（路径|视口|alignX|alignY|scale）', () {
    final key = keyFor(const Size(393, 852));
    expect(
      key.split('|').length,
      5,
      reason:
          '少一维就会让 HomeWallpaperLuminanceShare 把 alignX 当视口挖掉，'
          '缓存永不命中、首帧照样回落主题色',
    );
    expect(key.split('|')[1], '393.0x852.0');
  });
}
