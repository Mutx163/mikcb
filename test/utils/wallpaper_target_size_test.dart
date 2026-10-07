import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/utils/home_page_background.dart';

/// 壁纸**下载尺寸**的取值规则（2026-10-07 新增）。
///
/// 这些断言钉的是「不同时再叠一段 App 侧放大」那条决定：
/// 壁纸是 `BoxFit.cover` 铺满整屏，图片只要**小于**屏幕，App 就得再放大一次，而
/// 用户看到的正是那一段被放大的模糊（用户原话：「上下也缩小了，留下了最糊的画面」）。
void main() {
  group('WallpaperTargetSize', () {
    test('反推尺寸时对齐到偶数（JPEG 换色度采样要偶数）', () {
      // ⚠️ 构造器**不**做取整：它是 `const`，而取整要读参数（不是编译期常量）。
      // 所以偶数这条不变量由两个反推方法与 `wallpaperTargetSize()` 负责 ——
      // 下面这两条就是钉它们的。
      final fromOddWidth = const WallpaperTargetSize(1205, 2622).withWidth(1205);
      expect(fromOddWidth.width, 1206);
      final fromOddHeight = const WallpaperTargetSize(1206, 2621).withHeight(2621);
      expect(fromOddHeight.height, 2622);
      // 已经偶数时不动它。
      expect(const WallpaperTargetSize(1206, 2622).withWidth(1206).width, 1206);
      expect(const WallpaperTargetSize(1206, 2622).withHeight(2622).height, 2622);
    });

    test('按比例由高度反推宽度 —— 比例必须跟着屏幕走', () {
      // 9:19.5 的屏（实测常见机 1206×2622）。
      const target = WallpaperTargetSize(1206, 2622);
      final taller = target.withHeight(3200);
      // 比例不该被「凑成 9:20」—— 那正是多余竖向余量的来源。
      expect(taller.height, 3200);
      expect(
        taller.width,
        (3200 * 1206 / 2622).round(),
        reason: '宽度按屏幕比例算，不是按某个写死档位',
      );
      expect(
        taller.width / taller.height,
        closeTo(1206 / 2622, 0.002),
        reason: '反推后比例必须仍是屏幕比例',
      );
    });

    test('按比例由宽度反推高度', () {
      const target = WallpaperTargetSize(1080, 1920);
      final wider = target.withWidth(1440);
      expect(wider.width, 1440);
      expect(wider.height, 2560);
    });

    test('atLeast：档位是下限，但永远不小于屏幕', () {
      const small = WallpaperTargetSize(1080, 1920);
      // 屏幕比档位大 → 取屏幕（这一档就是「消除二次放大」）。
      final lifted = small.atLeast(1080, 2400);
      expect(lifted.height, greaterThanOrEqualTo(2400));
      expect(lifted.width, greaterThanOrEqualTo(1080));
      // 屏幕比档位小 → 保住档位（用户选低档省流量的意图仍成立）。
      final kept = const WallpaperTargetSize(1080, 1920).atLeast(1440, 3200);
      expect(kept.width, greaterThanOrEqualTo(1440));
      expect(kept.height, greaterThanOrEqualTo(3200));
    });

    test('atLeast 两维都不足时以高度为准（cover 的瓶颈永远是高度）', () {
      // 1440×3200 那档比任何手机都大，而屏幕只有 1080×2400 —— 此时应保屏幕比例、
      // 把尺寸抬到至少 3200 高。
      final result = const WallpaperTargetSize(1080, 2400).atLeast(1440, 3200);
      expect(result.height, greaterThanOrEqualTo(3200));
      // 宽度按比例跟着抬，不能停在 1080（那会变成一张比例不对的图）。
      expect(result.width / result.height, closeTo(1080 / 2400, 0.01));
    });

    test('atLeast 已经满足时原样返回（不无谓放大）', () {
      const target = WallpaperTargetSize(1440, 3200);
      expect(target.atLeast(1080, 1920), target);
      expect(target.atLeast(1440, 3200), target);
    });

    test('相等判定按值 —— 台账键与文件名都靠它', () {
      expect(
        const WallpaperTargetSize(1206, 2622),
        const WallpaperTargetSize(1206, 2622),
      );
      expect(
        const WallpaperTargetSize(1206, 2622).hashCode,
        const WallpaperTargetSize(1206, 2622).hashCode,
      );
      expect(
        const WallpaperTargetSize(1206, 2622),
        isNot(const WallpaperTargetSize(1204, 2620)),
      );
    });
  });

  group('wallpaperTargetSize', () {
    test('读得到真实视口时，宽高都在合理范围内且为偶数', () {
      final size = wallpaperTargetSize();
      expect(size.width, inInclusiveRange(720, 2160));
      expect(size.height, inInclusiveRange(1280, 3840));
      expect(size.width.isEven, isTrue, reason: 'JPEG 采样要求偶数宽');
      expect(size.height.isEven, isTrue, reason: 'JPEG 采样要求偶数高');
    });

    test('⭐ 视口是横的也必须给竖尺寸（测试环境视口正是横的）', () {
      // `flutter test` 的默认视口是 2400×1800（横的）。照抄它会得到 2160×1800 这个
      // **横**目标，于是按横比例去裁图 —— 而首页是竖屏，结果就是「一张横图铺在竖屏上」，
      // 正是 2026-10-06 用户拍板删掉横屏档位要避免的结局。
      final size = wallpaperTargetSize();
      expect(
        size.height,
        greaterThan(size.width),
        reason: '壁纸必须按竖屏前提取尺寸；横屏视口下也要交换',
      );
    });

    test('上下限被钳住，不会照着异常视口去要一张离谱大的图', () {
      // ⚠️ 测试环境的视口是 `800×600 逻辑像素 ×3` = 2400×1800（**横**的），所以这里
      // 绝不能断言「比某台真机大」—— 那是拿测试视口冒充真机。真机上界才有意义：
      // 折叠屏内屏 / 2K 屏的壁纸不该下到 3840 高以上（源图没那么多像素，只会更糊）。
      expect(wallpaperTargetSize().height, lessThanOrEqualTo(3840));
      expect(wallpaperTargetSize().width, lessThanOrEqualTo(2160));
    });
  });
}