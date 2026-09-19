// 玻璃采样比例的换算：图上的点 / 屏幕逻辑像素。
//
// 背景：捕获按捕获节点的**本地空间**出图，玻璃按**屏幕逻辑像素**贴图，两者差一个
// 祖先缩放。真机踩过的坑（外观编辑页把真首页缩成卡片）：不折算时玻璃把这张图按错误
// 尺度铺开 —— 玻璃带发白死板、或一条条横线。
//
// 这里只钉纯函数那一层：捕获本身（`toImageSync`）在测试环境没有 shader / GPU 后端，
// 跑不出真图，只能靠真机验收。
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/ui/hyperos/hyperos_glass_backdrop_host.dart';

void main() {
  test('祖先没有缩放：原样返回（平时所有页面走这条，行为不变）', () {
    expect(glassCapturePixelRatio(0.8125, 1), closeTo(0.8125, 1e-9));
  });

  test('页面被整体缩小：按祖先缩放折算（图上的点相对屏幕变密）', () {
    // 首页缩成 0.653 倍卡片：每屏幕逻辑像素对应 0.8125/0.653 ≈ 1.244 个点。
    expect(glassCapturePixelRatio(0.8125, 0.653), closeTo(1.2443, 1e-3));
    // 放大（入场动画里的 >1）同理，方向相反。
    expect(glassCapturePixelRatio(0.5, 1.25), closeTo(0.4, 1e-9));
  });

  test('取不到 / 退化的缩放：按 1 处理，不产生 NaN 或负比例', () {
    expect(glassCapturePixelRatio(0.8, 0), closeTo(0.8, 1e-9));
    expect(glassCapturePixelRatio(0.8, -2), closeTo(0.8, 1e-9));
    expect(glassCapturePixelRatio(0.8, double.nan), closeTo(0.8, 1e-9));
    expect(
      glassCapturePixelRatio(0.8, double.infinity),
      closeTo(0.8, 1e-9),
    );
  });
}
