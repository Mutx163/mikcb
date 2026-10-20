import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/services/ui_runtime_prefs.dart';

/// 界面层运行时偏好端口（`services/ui_runtime_prefs.dart`）的契约。
///
/// 它存在的理由：`TimetableProvider`（`providers/`）要把两个设置值送进界面层
/// 全局状态，而 `providers → ui` 是反向依赖（层序 providers 在 ui 之下）。
/// 端口住 `services/`，两个方向都合法，依赖被真正倒过来 —— 不是把 import
/// 搬进免检目录把账做平。
///
/// **最要紧的一条是「注册顺序无关」**：冷启动时首页会先构建、provider 先推一次
/// 设置，而 `configureHyperosMotionFromAndroid()` 跑在首帧之后的暖机作业里。
/// 若端口不积压补发，用户上次关掉的边缘触感会在这段时间里短暂恢复默认开 ——
/// 这正是本测试第 2 条钉的场景。
void main() {
  setUp(UiRuntimePrefs.resetForTesting);
  tearDown(UiRuntimePrefs.resetForTesting);

  test('注册之后：值直接送达实现', () {
    final haptics = <bool>[];
    final speeds = <double>[];

    UiRuntimePrefs.bind(
      edgeHaptics: haptics.add,
      transitionSpeed: speeds.add,
    );

    UiRuntimePrefs.setEdgeHapticsEnabled(false);
    UiRuntimePrefs.setPageTransitionSpeed(1.5);

    expect(haptics, [false]);
    expect(speeds, [1.5]);
  });

  test('注册之前推过的值：注册时补发（否则冷启动短暂回到默认）', () {
    // 顺序与冷启动一致：provider 先推，暖机作业后才 bind。
    UiRuntimePrefs.setEdgeHapticsEnabled(false);
    UiRuntimePrefs.setPageTransitionSpeed(2);

    final haptics = <bool>[];
    final speeds = <double>[];
    UiRuntimePrefs.bind(
      edgeHaptics: haptics.add,
      transitionSpeed: speeds.add,
    );

    expect(
      haptics,
      [false],
      reason:
          '补发失效 ⇒ 用户关掉的边缘触感在暖机完成前会一直是默认的「开」',
    );
    expect(speeds, [2]);
  });

  test('重复注册：实现被换掉，积压值按当前状态重发（幂等）', () {
    UiRuntimePrefs.setEdgeHapticsEnabled(true);

    final first = <bool>[];
    UiRuntimePrefs.bind(
      edgeHaptics: first.add,
      transitionSpeed: (_) {},
    );
    expect(first, [true], reason: '首次注册应补发积压值');

    final second = <bool>[];
    UiRuntimePrefs.bind(
      edgeHaptics: second.add,
      transitionSpeed: (_) {},
    );
    expect(second, [true], reason: '重新注册（热重载/再次暖机）后新实现也要拿到当前值');

    // 旧的实现不再被调用。
    final firstCount = first.length;
    UiRuntimePrefs.setEdgeHapticsEnabled(false);
    expect(first.length, firstCount, reason: '换绑之后旧实现不该再收到推送');
    expect(second.last, isFalse);
  });

  test('没有注册时推送不抛错（provider 可能在无人接听时初始化）', () {
    expect(
      () {
        UiRuntimePrefs.setEdgeHapticsEnabled(true);
        UiRuntimePrefs.setPageTransitionSpeed(0.5);
      },
      returnsNormally,
    );
  });

  test('一次推送只补发一次：bind 之后不会把历史全量重放', () {
    final haptics = <bool>[];
    UiRuntimePrefs.setEdgeHapticsEnabled(true);
    UiRuntimePrefs.setEdgeHapticsEnabled(false);

    UiRuntimePrefs.bind(
      edgeHaptics: haptics.add,
      transitionSpeed: (_) {},
    );

    expect(
      haptics,
      [false],
      reason: '只该补发「最后一次」，重放整段历史会让实现反复抖动',
    );
  });
}
