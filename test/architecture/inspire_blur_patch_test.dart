import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:inspire_blur/inspire_blur.dart';

/// `inspire_blur` 补丁守卫：分布图像素的记忆化。
///
/// ## 为什么会有这个补丁
///
/// 上游 `IntensityBasedDistributionMap.getBlurDistributionImage` 每次都重新
/// `_generatePixels()`：width×height 的双重循环（size 取屏幕逻辑长边 × 0.75，
/// 上限 1024），逐像素求 `intensityAt` 并写满一份 RGBA8888 缓冲。真机实测
/// （1280×2772 / dpr 2.75 → size 820）这一句是 **674k 次求值 + 2.7MB 分配**，
/// 且它跑在第一个 `await` 之前 —— **同步**占住 UI 线程 36~49ms。
/// `_InspireBlurWrapperState.didChangeDependencies` 每个新挂载的顶栏都会调一次，
/// 于是「每进一个子页，首帧就多花约 40 毫秒」（`[first-frame]` 探针实测：
/// `headerShell` 与 `header` 之间恒定空掉 36~49ms）。
///
/// 补丁把像素按 `(distribution, size)` 记忆化。**只缓存像素、不缓存 `ui.Image`**，
/// 所以图像的所有权与释放时机与上游逐字一致。
///
/// ## 这些用例同时是「补丁依赖还在不在」的守卫
///
/// 本文件 import 了 `BlurDistributionPixelsCache` —— 一旦 `pubspec.yaml` 的
/// `dependency_overrides.inspire_blur` 被换回 pub.dev，这个名字不存在，**本文件
/// 直接编译失败**。比读 pubspec 字符串更硬，也不依赖谁记得去跑哪条检查。
///
/// 上游修好后删本文件、fork 与 `dependency_overrides` 里的条目。
void main() {
  setUp(BlurDistributionPixelsCache.clear);

  /// 计数用的假生成器：真正的像素内容与缓存语义无关。
  Uint8List Function() countingGenerator(List<int> counter) {
    return () {
      counter[0]++;
      return Uint8List(4);
    };
  }

  test('同配置 + 同尺寸：第二次不再重新生成，且复用同一份缓冲', () {
    final calls = <int>[0];
    final distribution = InspireBlurConfig.topToBottom(
      sigma: 20,
    ).distribution;

    final first = BlurDistributionPixelsCache.pixelsFor(
      distribution,
      64,
      countingGenerator(calls),
    );
    final second = BlurDistributionPixelsCache.pixelsFor(
      distribution,
      64,
      countingGenerator(calls),
    );

    expect(calls[0], 1, reason: '第二次命中缓存就不该再跑那 67 万次循环');
    expect(identical(first, second), isTrue);
  });

  test('等值但不同实例的配置也命中同一条（顶栏每帧都会重建配置对象）', () {
    final calls = <int>[0];
    // 逐帧重建出来的两个对象：字段相同、实例不同。
    final a = InspireBlurConfig.topToBottom(sigma: 22).distribution;
    final b = InspireBlurConfig.topToBottom(sigma: 22).distribution;
    expect(identical(a, b), isFalse, reason: '前提：上游每帧都会新建配置对象');

    BlurDistributionPixelsCache.pixelsFor(a, 64, countingGenerator(calls));
    BlurDistributionPixelsCache.pixelsFor(b, 64, countingGenerator(calls));

    expect(calls[0], 1, reason: '键必须靠值相等命中，否则缓存等于没有');
  });

  test('σ 变了不产生新条目 —— 分布图只编码渐隐形状', () {
    final calls = <int>[0];
    final gen = countingGenerator(calls);

    BlurDistributionPixelsCache.pixelsFor(
      InspireBlurConfig.topToBottom(sigma: 8).distribution,
      64,
      gen,
    );
    BlurDistributionPixelsCache.pixelsFor(
      InspireBlurConfig.topToBottom(sigma: 40).distribution,
      64,
      gen,
    );

    // 这条是跑测试时才发现的：`sigma` 落在 `InspireBlurConfig.sigma`（shader 用），
    // 分布对象只装 begin/end/values/stops，也就是「渐隐形状」。所以拖模糊强度滑杆
    // 根本不会让这张图重算 —— 只有 extent / 渐隐曲线变了才会。
    expect(calls[0], 1);
  });

  test('渐隐形状或尺寸变了就各自生成', () {
    final calls = <int>[0];
    final gen = countingGenerator(calls);
    final base = InspireBlurConfig.topToBottom(sigma: 20).distribution;
    final otherShape = InspireBlurConfig.topToBottom(
      sigma: 20,
      extent: 0.5,
    ).distribution;
    expect(base == otherShape, isFalse, reason: '前提：extent 会改到分布对象');

    BlurDistributionPixelsCache.pixelsFor(base, 64, gen);
    BlurDistributionPixelsCache.pixelsFor(base, 128, gen); // 尺寸不同
    BlurDistributionPixelsCache.pixelsFor(otherShape, 64, gen); // 形状不同

    expect(calls[0], 3);
  });

  test('缓存有上限：条目多了按插入顺序丢最旧的', () {
    final calls = <int>[0];
    final gen = countingGenerator(calls);
    const cap = BlurDistributionPixelsCache.maxEntries;

    // 每个 extent 都是一份不同的渐隐形状 —— 等价于用户反复改设置。
    for (var i = 1; i <= cap + 4; i++) {
      BlurDistributionPixelsCache.pixelsFor(
        InspireBlurConfig.topToBottom(sigma: 20, extent: i / 10).distribution,
        64,
        gen,
      );
    }

    expect(calls[0], cap + 4, reason: '前提：这些 extent 确实各自生成了新图');
    expect(
      BlurDistributionPixelsCache.entryCount,
      cap,
      reason: '每份缓冲约 2.7MB，无上限会让反复改设置变成内存增长',
    );
  });
}
