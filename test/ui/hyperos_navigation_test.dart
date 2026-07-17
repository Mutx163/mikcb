import 'package:flutter/animation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/services/android_animation_scale_service.dart';
import 'package:university_timetable/ui/hyperos/hyperos_miuix_spec.dart';
import 'package:university_timetable/ui/hyperos/hyperos_navigation.dart';

void main() {
  test('Hyperos navigation uses tuned transition base duration', () {
    // applyUserTransitionSpeed now requires BuildContext; duration base is static.
    expect(HyperosMiuixNavigation.transitionDurationMs, 300);
    expect(
      AndroidAnimationScaleService.scaledDuration(
        HyperosMiuixNavigation.transitionDurationMs,
      ).inMilliseconds,
      300,
    );
  });

  test('user transition speed scales page transition duration', () {
    AndroidAnimationScaleService.setUserTransitionSpeed(2.0);
    expect(
      AndroidAnimationScaleService.scaledDuration(300).inMilliseconds,
      150,
    );
    AndroidAnimationScaleService.setUserTransitionSpeed(0.5);
    expect(
      AndroidAnimationScaleService.scaledDuration(300).inMilliseconds,
      600,
    );
  });

  test('transition shadow peaks mid-slide and rests at endpoints', () {
    expect(HyperosNavigation.transitionShadowStrength(0), 0);
    expect(HyperosNavigation.transitionShadowStrength(1), 0);
    expect(HyperosNavigation.transitionShadowStrength(0.5), closeTo(1, 0.001));
  });

  test(
    'transition corner radius rests at endpoints and stays full mid-slide',
    () {
      expect(HyperosNavigation.transitionCornerRadiusFactor(0), 0);
      expect(HyperosNavigation.transitionCornerRadiusFactor(1), 0);
      expect(
        HyperosNavigation.transitionCornerRadiusFactor(0.5),
        closeTo(1, 0.001),
      );
      // Near settle band: still fading, never stuck at a large residual radius.
      expect(
        HyperosNavigation.transitionCornerRadiusFactor(0.95),
        lessThan(0.5),
      );
      expect(
        HyperosNavigation.transitionCornerRadiusFactor(0.05),
        lessThan(0.5),
      );
    },
  );

  test('primary transition active only while forward or reverse', () {
    expect(
      HyperosNavigation.isPrimaryTransitionActive(AnimationStatus.forward),
      isTrue,
    );
    expect(
      HyperosNavigation.isPrimaryTransitionActive(AnimationStatus.reverse),
      isTrue,
    );
    expect(
      HyperosNavigation.isPrimaryTransitionActive(AnimationStatus.completed),
      isFalse,
    );
    expect(
      HyperosNavigation.isPrimaryTransitionActive(AnimationStatus.dismissed),
      isFalse,
    );
  });

  test('parallax bleed covers exit slide fraction', () {
    expect(HyperosNavigation.parallaxBleedWidth(400), 500);
    expect(
      HyperosNavigation.parallaxBleedWidth(400),
      400 * (1 + HyperosMiuixNavigation.exitSlideFraction),
    );
  });
}
