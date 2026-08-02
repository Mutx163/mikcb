import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/ui/hyperos/frosted/frosted_appearance.dart';
import 'package:university_timetable/ui/hyperos/liquid/hyperos_liquid_glass_surface.dart';
import 'package:university_timetable/widgets/course_card_liquid_glass_host.dart';

void main() {
  testWidgets(
    'course-card host uses real layer when settled and removes it during motion',
    (tester) async {
      final motion = ValueNotifier<bool>(false);
      addTearDown(motion.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: FrostedAppearanceScope(
            appearance: FrostedAppearance.defaults,
            child: CourseCardGlassMotionScope(
              motion: motion,
              child: CourseGridGlassHost(
                settings: TimetableSettings.defaults().copyWith(
                  courseCardSurfaceStyle: CourseCardSurfaceStyle.liquidGlass,
                ),
                child: const SizedBox(width: 120, height: 80),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(HyperosLiquidGlassLayer), findsOneWidget);

      motion.value = true;
      await tester.pump();
      expect(find.byType(HyperosLiquidGlassLayer), findsNothing);
      expect(find.byType(CourseCardLiquidGlassScope), findsOneWidget);
      expect(
        (tester.widget<CourseCardLiquidGlassScope>(
          find.byType(CourseCardLiquidGlassScope),
        )).motionFallback,
        isTrue,
      );

      motion.value = false;
      await tester.pump();
      expect(find.byType(HyperosLiquidGlassLayer), findsOneWidget);
    },
  );
}
