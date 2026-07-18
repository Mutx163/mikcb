import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/providers/timetable_provider.dart';
import 'package:university_timetable/ui/hyperos/hyperos_navigation.dart';

class TestApp extends StatelessWidget {
  final Widget home;
  const TestApp({super.key, required this.home});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      navigatorObservers: [hyperosRouteObserver],
      builder: (context, child) {
        return FTheme(
          data: FThemes.zinc.light.touch,
          child: ScaffoldMessenger(
            child: Scaffold(
              backgroundColor: Colors.transparent,
              resizeToAvoidBottomInset: false,
              body: child ?? const SizedBox.shrink(),
            ),
          ),
        );
      },
      home: home,
    );
  }
}

/// Escape the testWidgets FakeAsync zone for SharedPreferences / HTTP.
Future<T> runRealAsync<T>(
  WidgetTester tester,
  Future<T> Function() action,
) async {
  final result = await tester.runAsync(action);
  return result as T;
}

/// Provider ready for widget tests without hanging on FakeAsync I/O.
Future<TimetableProvider> createInitializedTestProvider(
  WidgetTester tester,
) async {
  late TimetableProvider provider;
  await tester.runAsync(() async {
    provider = TimetableProvider(
      autoInitialize: false,
      enableLiveActivitySync: false,
    );
    await provider.initialize();
    // Drain background holiday / surface bootstrap so later mutations
    // (setCurrentWeek, addCourse) are not raced by residual I/O.
    await Future<void>.delayed(const Duration(milliseconds: 150));
  });
  return provider;
}
