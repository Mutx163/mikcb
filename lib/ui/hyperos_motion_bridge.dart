import '../services/android_animation_scale_service.dart';
import '../services/ui_runtime_prefs.dart';
import 'hyperos/hyperos_motion.dart';
import 'hyperos/hyperos_navigation.dart';
import 'hyperos/hyperos_overscroll.dart';
import 'hyperos/hyperos_zoom_route.dart';

/// Wires Android system animation scale into HyperOS motion (call after
/// [AndroidAnimationScaleService.ensureInitialized]).
void configureHyperosMotionFromAndroid() {
  HyperosMotionPlatform.durationScaler =
      AndroidAnimationScaleService.scaledDuration;
  HyperosMotionPlatform.displayCornerRadiusDp =
      AndroidAnimationScaleService.displayCornerRadiusDp;
  HyperosMotionPlatform.onUserTransitionSpeedChanged = (speed) {
    AndroidAnimationScaleService.setUserTransitionSpeed(speed);
    HyperosPageRoute.syncTransitionDurations();
    HyperosZoomPageRoute.syncTransitionDurations();
    notifyHyperosMotionChanged();
  };
  // provider 经 `services/ui_runtime_prefs.dart` 推来两个设置值（它不能 import
  // ui/）。这里把真正的界面层实现挂上去；端口会补发此前积压的值，所以注册
  // 早于/晚于 provider 首次推送都不影响最终状态。
  UiRuntimePrefs.bind(
    edgeHaptics: hyperosSetEdgeHapticsEnabled,
    transitionSpeed: applyHyperosUserTransitionSpeed,
  );
  notifyHyperosMotionChanged();
}

/// Persists page transition speed without a [BuildContext] (e.g. provider init).
void applyHyperosUserTransitionSpeed(double speed) {
  AndroidAnimationScaleService.setUserTransitionSpeed(speed);
  HyperosPageRoute.syncTransitionDurations();
  HyperosZoomPageRoute.syncTransitionDurations();
}

/// Refreshes corner radius / scale from the platform channel.
Future<void> refreshHyperosMotionFromAndroid() async {
  await AndroidAnimationScaleService.refresh();
  HyperosMotionPlatform.durationScaler =
      AndroidAnimationScaleService.scaledDuration;
  HyperosMotionPlatform.displayCornerRadiusDp =
      AndroidAnimationScaleService.displayCornerRadiusDp;
  HyperosPageRoute.syncTransitionDurations();
  HyperosZoomPageRoute.syncTransitionDurations();
  notifyHyperosMotionChanged();
}
