import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/page_corner_radius.dart';
import 'package:university_timetable/ui/hyperos/hyperos_miuix_spec.dart';

/// 屏幕圆角兜底值的口径钉。
///
/// task-10 把「这个数是多少」从 `ui/hyperos/hyperos_miuix_spec.dart` 下沉到中性的
/// `models/page_corner_radius.dart`：`AndroidAnimationScaleService`（`services/`）
/// 是它的另一个使用方，而服务层 import `ui/` 是反向依赖。
///
/// 搬家只是改归属，**值不许动**：它决定转场前缘那个几十 dp 的小窗口形状，
/// 偏一点就是用户口径的「圆角闪现消失」。
void main() {
  test('兜底值逐位不变（28dp）', () {
    expect(kPageCornerRadiusFallbackDp, 28.0);
  });

  test('models 与 ui 两侧读的是同一个数（一份真源，不会漂）', () {
    expect(
      HyperosMiuixNavigation.pageCornerRadiusFallback,
      kPageCornerRadiusFallbackDp,
      reason:
          '两边漂了：服务层（平台读数失败时的初值）与界面层（转场圆角形状）'
          '会用不同半径，前缘缺口与机身圆角对不上',
    );
  });
}
