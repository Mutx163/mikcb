import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/utils/app_update_dot_share.dart';

/// 「有更新」红点的跨页面一致性（2026-10-21）。
///
/// 用户口径：「为什么切换到月视图，右上角的球会闪一下，本来有更新红点，闪一下
/// 又不显示了」。
///
/// 根因不是动画：红点画在「更多」那颗球上，值来自 `UpdateCheckController`，
/// 而那个 controller **只有首页创建**。独立页面此前一律传
/// `showUpdateDot: false` —— 切过去红点凭空消失。用户读成"球闪了一下、点丢了"。
///
/// 本文件钉住共享登记的三态语义：**没查过 / 查过没有 / 查过有**。
/// 三者必须可区分，否则独立页只能二选一（一律画点或一律不画），两种都错。
void main() {
  setUp(AppUpdateDotShare.resetForTesting);

  test('还没查过：不画点，且能区分于"查过但没有"', () {
    expect(AppUpdateDotShare.isKnown, isFalse);
    expect(AppUpdateDotShare.hasUpdate, isFalse);
    // 关键：未查过 ≠ 查过没有。前者调用方不该画点（与首页首帧一致，
    // 避免"别的页面有点、回首页反而没有"的倒挂）。
    AppUpdateDotShare.publish(hasUpdate: false);
    expect(AppUpdateDotShare.isKnown, isTrue, reason: '查过之后必须标记为已知');
    expect(AppUpdateDotShare.hasUpdate, isFalse);
  });

  test('首页查到有更新 → 独立页读到同一个 true', () {
    AppUpdateDotShare.publish(hasUpdate: true);
    expect(
      AppUpdateDotShare.hasUpdate,
      isTrue,
      reason: '这正是用户要的：切到月视图，红点还在',
    );
  });

  test('更新被装掉之后 → 两边同时消失（不会一边有一点没有）', () {
    AppUpdateDotShare.publish(hasUpdate: true);
    AppUpdateDotShare.publish(hasUpdate: false);
    expect(AppUpdateDotShare.hasUpdate, isFalse);
    expect(AppUpdateDotShare.isKnown, isTrue);
  });

  test('reset 清干净（测试间不串味）', () {
    AppUpdateDotShare.publish(hasUpdate: true);
    AppUpdateDotShare.resetForTesting();
    expect(AppUpdateDotShare.isKnown, isFalse);
    expect(AppUpdateDotShare.hasUpdate, isFalse);
  });
}
