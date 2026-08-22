import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/models/timetable_profile.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/services/storage_service.dart';
import 'package:university_timetable/ui/hyperos/frosted/frosted_appearance.dart';
import 'package:university_timetable/widgets/course_grid_surface_host.dart';
import 'package:university_timetable/widgets/timetable_week_preview.dart';

import '../helpers_test_app.dart';

void _seedInitializedPrefs() {
  final now = DateTime(2026, 4, 12);
  final profile = TimetableProfile(
    id: 'profile-1',
    name: '默认课表',
    courses: const [],
    settings: TimetableSettings.defaults(),
    currentWeek: 1,
    createdAt: now,
    lastUsedAt: now,
  );
  SharedPreferences.setMockInitialValues({
    'did_migrate_app_logs_default': true,
    'did_migrate_live_hide_prefix_default': true,
    'timetable_profiles': jsonEncode([profile.toJson()]),
    'active_timetable_profile_id': profile.id,
    'time_schemes': '[]',
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    StorageService().resetForTesting();
    _seedInitializedPrefs();
  });

  Future<void> pumpPreview(
    WidgetTester tester, {
    required TimetableSettings settings,
    bool? applyHomePageBackdrop,
  }) async {
    final provider = await createInitializedTestProvider(tester);
    await tester.pumpWidget(
      TestApp(
        home: FrostedAppearanceScope(
          appearance: FrostedAppearance(
            sheetBlurSigma: settings.frostedSheetBlurSigma,
            sheetTintAlpha: settings.frostedSheetTintAlpha,
            sheetBarrierAlpha: settings.frostedSheetBarrierAlpha,
            blurEnabled: settings.frostedBlurEnabled,
            glassMode: settings.frostedGlassMode,
            liquidGlassTuning: settings.liquidGlassTuning,
          ),
          child: SizedBox(
            width: 360,
            height: 320,
            child: TimetableWeekPreview(
              provider: provider,
              settings: settings,
              week: provider.currentWeek,
              maxVisibleSections: 4,
              applyHomePageBackdrop: applyHomePageBackdrop ?? true,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('applyHomePageBackdrop defaults to true', (tester) async {
    // Regression guard: the settings previews rely on the default to show the
    // wallpaper. Two of them used to render flat because no caller passed it.
    final provider = await createInitializedTestProvider(tester);
    final preview = TimetableWeekPreview(
      provider: provider,
      settings: TimetableSettings.defaults(),
      week: 1,
    );
    expect(preview.applyHomePageBackdrop, isTrue);
  });

  group('glass hosting matches the home grid', () {
    testWidgets('gaussian grid gets a shared BackdropGroup', (tester) async {
      await pumpPreview(
        tester,
        settings: TimetableSettings.defaults().copyWith(
          courseCardSurfaceStyle: CourseCardSurfaceStyle.gaussian,
        ),
      );

      expect(find.byType(CourseGridSurfaceHost), findsOneWidget);
      expect(find.byType(BackdropGroup), findsAtLeastNWidgets(1));
    });

    for (final style in [CourseCardSurfaceStyle.solid]) {
      testWidgets('$style grid needs no glass host', (tester) async {
        await pumpPreview(
          tester,
          settings: TimetableSettings.defaults().copyWith(
            courseCardSurfaceStyle: style,
          ),
        );

        expect(find.byType(CourseGridSurfaceHost), findsOneWidget);
      });
    }
  });

  testWidgets('renders every surface style without throwing', (tester) async {
    for (final style in CourseCardSurfaceStyle.values) {
      await pumpPreview(
        tester,
        settings: TimetableSettings.defaults().copyWith(
          courseCardSurfaceStyle: style,
        ),
      );
      expect(tester.takeException(), isNull, reason: 'style: $style');
    }
  });
}
