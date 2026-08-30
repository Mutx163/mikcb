import '../services/android_animation_scale_service.dart';
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
  HyperosMotionPlatform.durationScaler =
      AndroidAnimationScaleService.scaledDuration;
  HyperosMotionPlatform.displayCornerRadiusDp =
      AndroidAnimationScaleService.displayCornerRadiusDp;
  HyperosPageRoute.syncTransitionDurations();
  notifyHyperosMotionChanged();
}
