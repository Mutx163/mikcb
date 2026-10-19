// 亮度带共享（`HomeWallpaperLuminanceShare`）的键匹配语义。
//
// 这份共享存在的唯一理由：**第二份首页实例**（「外观编辑」页的缩尺预览）首帧
// 要拿到真首页此刻已经在用的墨色极性，而不是按主题猜一遍再翻面（用户 2026-10-10
// 报的「白字闪黑又白」）。所以这里要钉住的正是"键对得上才给"。
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/utils/home_wallpaper_luminance_share.dart';

void main() {
  // 每条用例自己清一次：这是一份进程级静态登记。
  setUp(HomeWallpaperLuminanceShare.resetForTesting);

  const key = 'wallpaper.png|393.8x852.9|0.0|0.0|1.0';
  const bands = (top: 1.0, weekday: 0.1, body: 0.0);

  test('没登记过：任何键都给 null（取用方回落到主题兜底）', () {
    expect(HomeWallpaperLuminanceShare.bandsFor(key), isNull);
  });

  test('同一个键：拿到登记的那一份', () {
    HomeWallpaperLuminanceShare.publish(key, bands);
    final got = HomeWallpaperLuminanceShare.bandsFor(key)!;
    expect(got.top, 1.0);
    expect(got.weekday, 0.1);
    expect(got.body, 0.0);
  });

  test('换了取景（同路径、不同键）：不许把旧取景的带子给出去', () {
    // 只按路径索引就会撞上这条：拖动位置 / 双指缩放后，同一条路径上的亮度带
    // 会变，旧带子会让新取景的墨色极性反着来。
    HomeWallpaperLuminanceShare.publish(key, bands);
    const movedKey = 'wallpaper.png|393.8x852.9|-1.0|0.0|1.0';
    expect(HomeWallpaperLuminanceShare.bandsFor(movedKey), isNull);
  });

  test('换壁纸 / 换视口：同样按未命中处理', () {
    HomeWallpaperLuminanceShare.publish(key, bands);
    expect(
      HomeWallpaperLuminanceShare.bandsFor('other.png|393.8x852.9|0.0|0.0|1.0'),
      isNull,
    );
    expect(
      HomeWallpaperLuminanceShare.bandsFor('wallpaper.png|400x900|0.0|0.0|1.0'),
      isNull,
    );
  });

  test('只留最新一份：后一次登记覆盖前一次', () {
    HomeWallpaperLuminanceShare.publish(key, bands);
    const newer = (top: 0.0, weekday: 0.0, body: 0.0);
    HomeWallpaperLuminanceShare.publish(key, newer);
    expect(HomeWallpaperLuminanceShare.bandsFor(key)!.top, 0.0);
  });

  // `resolve` 是取用侧真正该调的那个：键不命中时**只放掉视口**再比一次。
  // 用户 2026-10-19 报的「进设置时星期栏 / 标题闪白再闪回来」就是"本来知道、
  // 却因为视口变了退回去按主题猜"。
  test('resolve：只有视口变了 → 沿用上一次的带子（不再回落到猜）', () {
    HomeWallpaperLuminanceShare.publish(key, bands);
    const otherViewport = 'wallpaper.png|400x900|0.0|0.0|1.0';
    expect(
      HomeWallpaperLuminanceShare.bandsFor(otherViewport),
      isNull,
      reason: '精确键仍然不给 —— 这是既有语义，别被兜底带坏',
    );
    expect(HomeWallpaperLuminanceShare.resolve(otherViewport)!.top, 1.0);
  });

  test('resolve：换壁纸 / 改取景 / 改倍率仍然作废（旧带子不许冒充新取景）', () {
    HomeWallpaperLuminanceShare.publish(key, bands);
    for (final stale in const [
      'other.png|393.8x852.9|0.0|0.0|1.0',
      'wallpaper.png|393.8x852.9|-1.0|0.0|1.0',
      'wallpaper.png|393.8x852.9|0.0|1.0|1.0',
      'wallpaper.png|393.8x852.9|0.0|0.0|1.5',
    ]) {
      expect(HomeWallpaperLuminanceShare.resolve(stale), isNull, reason: stale);
    }
  });

  test('resolve：没登记过 → null（取用方照旧走主题兜底）', () {
    expect(HomeWallpaperLuminanceShare.resolve(key), isNull);
  });
}
