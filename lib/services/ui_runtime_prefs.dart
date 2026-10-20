/// 界面层的**运行时偏好端口**：provider 把「设置变了」推到这里，界面层在启动时
/// 注册真正的实现。
///
/// 为什么需要它：`TimetableProvider`（`providers/`）要把两个设置值送进界面层的
/// 全局状态 ——
/// * 列表边缘触感开关（`enableHaptics`）→ `hyperosSetEdgeHapticsEnabled`；
/// * 页面转场速度（`pageTransitionSpeed`）→ `applyHyperosUserTransitionSpeed`。
///
/// 直接 import 就是 `providers → ui` 反向依赖（层序里 providers 在 ui 之下）。
/// 端口放在 `services/`：`providers → services` 与 `ui → services` 都是合法方向，
/// 依赖被真正倒过来了 —— 不是把 import 挪进某个免检目录把账做平。
///
/// 先例：`services/timetable_settings_writer.dart` 的
/// `TimetableSettingsWritePort.applyEdgeHaptics`，注释写着「只在宿主侧存在 UI
/// 依赖，服务不 import ui/」。这里是把同一个思路用在反方向。
///
/// **注册顺序无关**（这条是刻意设计，不是附带的）：provider 往往在
/// `configureHyperosMotionFromAndroid()` 之前就初始化并推过一次设置（冷启动时
/// 首页构建早于首帧暖机作业）。所以端口会**记住最后一次的入参**，等实现注册
/// 上来的那一刻补发一次。否则用户上次关掉触感后，冷启动到暖机之间那段时间
/// 边缘触感会短暂恢复默认开。
library;

/// 边缘触感开关的处理实现（注册方：`ui/hyperos_motion_bridge.dart`）。
typedef EdgeHapticsHandler = void Function(bool enabled);

/// 页面转场速度的处理实现（注册方同上）。
typedef PageTransitionSpeedHandler = void Function(double speed);

/// 见库注释。所有成员都是进程级静态状态，与 `TimetableSettings` 的全局性一致。
abstract final class UiRuntimePrefs {
  static EdgeHapticsHandler? _edgeHapticsHandler;
  static PageTransitionSpeedHandler? _transitionSpeedHandler;

  /// 最近一次入参；实现尚未注册时先存着，注册时补发。
  static bool? _pendingEdgeHaptics;
  static double? _pendingTransitionSpeed;

  /// 注册真正的界面层实现，并立刻补发此前积压的值。
  ///
  /// 幂等：重复注册会把实现换成新的（热重载 / 重新暖机），积压值按当前状态重发。
  static void bind({
    required EdgeHapticsHandler edgeHaptics,
    required PageTransitionSpeedHandler transitionSpeed,
  }) {
    _edgeHapticsHandler = edgeHaptics;
    _transitionSpeedHandler = transitionSpeed;
    final pendingHaptics = _pendingEdgeHaptics;
    if (pendingHaptics != null) {
      edgeHaptics(pendingHaptics);
    }
    final pendingSpeed = _pendingTransitionSpeed;
    if (pendingSpeed != null) {
      transitionSpeed(pendingSpeed);
    }
  }

  /// 列表边缘触感跟随设置开关。
  static void setEdgeHapticsEnabled(bool enabled) {
    _pendingEdgeHaptics = enabled;
    _edgeHapticsHandler?.call(enabled);
  }

  /// 页面转场速度（0.5×–2.5×）。
  static void setPageTransitionSpeed(double speed) {
    _pendingTransitionSpeed = speed;
    _transitionSpeedHandler?.call(speed);
  }

  /// 清空积压与实现（测试用：防止静态状态在用例之间串味）。
  static void resetForTesting() {
    _edgeHapticsHandler = null;
    _transitionSpeedHandler = null;
    _pendingEdgeHaptics = null;
    _pendingTransitionSpeed = null;
  }
}
