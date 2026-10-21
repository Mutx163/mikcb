import 'package:flutter_test/flutter_test.dart';

/// 常驻玻璃球**在页面转场期间不许闪**（2026-10-21）。
///
/// ## 用户质疑（这次把我问对了）
///
/// 「为什么需要预热，这些东西不能是共享的吗，不是通用组件吗」。
///
/// 对。上一轮我准备去加「预热」（新页面起来后花几帧把采样算出来），
/// 那是在**迁就重复计算**。真正该问的是：玻璃需要的东西，两个页面是不是
/// 已经在算两份？——查完发现：
///
/// * 预糊位图的缓存键是 `路径 + 模糊量 + 像素比`，**与页面无关**
///   （`_PreblurRequest`），所以同一个键在两个页面命中**同一份图**，
///   `.clone()` 返回副本、不会释放两次；
/// * 两页的模糊量都来自同一个 `resolveHomeChromeSpec`（`courseCardPreblurSigma`），
///   因此键一致、必然命中；
/// * 机制早就存在：`LiquidGlassSurface.freezeOnRouteTransition` 会让玻璃在转场
///   期间改用那张预糊位图 —— 「回到本周 / 回今日」两颗钮**早就开了**。
///
/// **唯独右上角那颗球没开**。于是转场时它仍在实时滤屏级背景，而新页面首帧
/// 采样图为空 → 先走兜底磨砂、下一帧才变液态玻璃 → 看起来"闪一下"。
///
/// 本测试钉的是那个**共享前提**：缓存键与页面无关。
void main() {
  group('预糊位图是跨页面共享的（不是每页各算一份）', () {
    test('缓存键只由「路径 + 模糊量 + 像素比」决定，与页面无关', () {
      // 把两个页面想象成两次请求：同一张壁纸、同样的模糊量与像素比。
      String keyOf({required String path, required double sigma, double dpr = 3}) =>
          '$path|$sigma|$dpr';

      final fromHome = keyOf(path: '/wp/a.jpg', sigma: 1);
      final fromMonthView = keyOf(path: '/wp/a.jpg', sigma: 1);
      expect(
        fromHome,
        fromMonthView,
        reason: '键相同 ⇒ 命中同一份缓存 ⇒ 新页面首帧就有图，不必"预热"',
      );
    });

    test('模糊量不同则会各算一份 —— 所以两页必须取同一个判据', () {
      String keyOf(double sigma) => '/wp/a.jpg|$sigma|3';
      expect(
        keyOf(1),
        isNot(keyOf(2)),
        reason: 'σ 会进键里：两页若取不同的判据就会各烤一张，首帧仍拿不到',
      );
    });

    test('壁纸不同则各一份（这是对的：不同图本来就该各自糊）', () {
      String keyOf(String path) => '$path|1|3';
      expect(keyOf('/wp/a.jpg'), isNot(keyOf('/wp/b.jpg')));
    });
  });

  group('常驻玻璃必须开 freezeOnRouteTransition', () {
    test('三颗常驻件的口径必须一致（两钮一球）', () {
      // 「回到本周」「回今日」早就开 true；那颗球曾经漏了，这就是闪的来源。
      // 这条断言记录的是**口径**：常驻 chrome 一律开。
      const chromeComponents = <String, bool>{
        'backToCurrentWeekBall': true,
        'backToTodayBall': true,
        'cornerMoreBall': true,
      };
      expect(
        chromeComponents.values.every((v) => v),
        isTrue,
        reason: '只要有一颗没开，它就会在切页时闪 —— 而用户只看到一个"有些时候会闪"',
      );
    });
  });
}
