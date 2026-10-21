import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/ui/hyperos/hyperos_glass_backdrop_host.dart';

/// 玻璃「冻结态」聚合信号的判据（2026-10-21）。
///
/// ## 用户口径
///
/// 「切进去不闪，切出来到日视图会闪」。
///
/// ## 为什么「进去不闪、出来闪」
///
/// 内嵌页切换**不是路由转场**（代码里写明「点底栏闪现直切，无滑动转场」），
/// 所以 `routeTransitionRunning` 全程不变，玻璃的冻结那条路根本不会触发：
///
/// * **进去时**：首页被 `Visibility(visible: false)` 停止绘制，球的玻璃仍在
///   采样 —— 但画面本来没变，所以看不出来；
/// * **出来时**：首页恢复绘制，球的采样图却还是那一张旧图，要等下一次回读才
///   更新 —— 那一帧就是"闪"。
///
/// 修法：把「路由转场」与「首页被内嵌页盖住」汇聚成**一个**信号
/// （`glassFrozen`）。两者对玻璃是同一件事：现在别依赖实时采样。
void main() {
  setUp(() {
    HyperosGlassBackdropController.setHomeScreenCovered(false);
    // 把转场计数清回 0（它内部是计数，测试间不串味）。
    while (HyperosGlassBackdropController.setRouteTransitionRunning(false) >
        0) {
      // 一直放到 0。
    }
  });

  test('两个来源都为假时：不冻结（正常实时采样）', () {
    expect(HyperosGlassBackdropController.glassFrozen.value, isFalse);
  });

  test('首页被内嵌页盖住 → 冻结（这正是"切进月视图"那一刻）', () {
    HyperosGlassBackdropController.setHomeScreenCovered(true);
    expect(
      HyperosGlassBackdropController.glassFrozen.value,
      isTrue,
      reason: '不冻结的话，退出内嵌页时首页刚恢复绘制、玻璃还是旧采样 → 闪一下',
    );
  });

  test('路由转场 → 冻结（与内嵌页是同一件事）', () {
    HyperosGlassBackdropController.setRouteTransitionRunning(true);
    expect(HyperosGlassBackdropController.glassFrozen.value, isTrue);
    HyperosGlassBackdropController.setRouteTransitionRunning(false);
    expect(HyperosGlassBackdropController.glassFrozen.value, isFalse);
  });

  test('两个来源取并集：任一个为真就冻结，都退了才解冻', () {
    HyperosGlassBackdropController.setRouteTransitionRunning(true);
    HyperosGlassBackdropController.setHomeScreenCovered(true);
    expect(HyperosGlassBackdropController.glassFrozen.value, isTrue);

    // 转场结束，但内嵌页还盖着 —— 必须继续冻结。
    HyperosGlassBackdropController.setRouteTransitionRunning(false);
    expect(
      HyperosGlassBackdropController.glassFrozen.value,
      isTrue,
      reason: '只看转场信号的话，内嵌页盖着时会被误判成"可以采样了"',
    );

    // 内嵌页退出 —— 这时才解冻。
    HyperosGlassBackdropController.setHomeScreenCovered(false);
    expect(HyperosGlassBackdropController.glassFrozen.value, isFalse);
  });

  test('重复设置同值不发通知（信号自身去重，避免多余重建）', () {
    var notifications = 0;
    void listener() => notifications++;
    HyperosGlassBackdropController.glassFrozen.addListener(listener);
    addTearDown(
      () => HyperosGlassBackdropController.glassFrozen.removeListener(listener),
    );

    HyperosGlassBackdropController.setHomeScreenCovered(true);
    HyperosGlassBackdropController.setHomeScreenCovered(true);
    HyperosGlassBackdropController.setHomeScreenCovered(true);
    expect(notifications, 1, reason: '重复同值只该通知一次');
  });
}
