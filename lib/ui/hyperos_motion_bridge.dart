import '../services/android_animation_scale_service.dart';
import '../utils/glass_debug_probe.dart';
import 'hyperos/hyperos_motion.dart';
import 'hyperos/hyperos_navigation.dart';

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
    notifyHyperosMotionChanged();
  };
  notifyHyperosMotionChanged();
}

/// Persists page transition speed without a [BuildContext] (e.g. provider init).
void applyHyperosUserTransitionSpeed(double speed) {
  AndroidAnimationScaleService.setUserTransitionSpeed(speed);
  HyperosPageRoute.syncTransitionDurations();
}

/// Refreshes corner radius / scale from the platform channel.
Future<void> refreshHyperosMotionFromAndroid() async {
  await AndroidAnimationScaleService.refresh();
  // [临时诊断] 截图若引发一次 pause/resume 周期，resume 会重拉系统动效参数，
  // 与 lifecycle 日志对齐可以确认截图是否造成了生命周期翻转。
  GlassDebugProbe.log(
    'motion.refresh '
    'transitionScale=${AndroidAnimationScaleService.transitionScale} '
    'cornerDp=${AndroidAnimationScaleService.displayCornerRadiusDp}',
  );
  HyperosMotionPlatform.durationScaler =
      AndroidAnimationScaleService.scaledDuration;
  HyperosMotionPlatform.displayCornerRadiusDp =
      AndroidAnimationScaleService.displayCornerRadiusDp;
  HyperosPageRoute.syncTransitionDurations();
  notifyHyperosMotionChanged();
}
