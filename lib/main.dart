import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'providers/timetable_provider.dart';
import 'screens/user_guide_screen.dart';
import 'screens/timetable_screen.dart';
import 'services/app_analytics.dart';
import 'services/storage_service.dart';
import 'services/umeng_analytics_service.dart';

Color _colorFromHex(String hexColor) {
  final normalized = hexColor.replaceFirst('#', '');
  return Color(int.parse('FF$normalized', radix: 16));
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppAnalytics.instance.initialize();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  String get _appTitle => kReleaseMode ? '轻屿课表' : '轻屿课表测试';

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TimetableProvider()),
      ],
      child: Consumer<TimetableProvider>(
        builder: (context, provider, child) {
          final seedColor = _colorFromHex(provider.settings.themeSeedColor);
          final colorScheme = ColorScheme.fromSeed(
            seedColor: seedColor,
            brightness: Brightness.light,
          );

          return MaterialApp(
            title: _appTitle,
            debugShowCheckedModeBanner: false,
            navigatorObservers: AppAnalytics.instance.navigatorObservers,
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('zh', 'CN'),
              Locale('en', 'US'),
            ],
            theme: ThemeData(
              useMaterial3: true,
              colorScheme: colorScheme,
              scaffoldBackgroundColor: colorScheme.surface,
              appBarTheme: AppBarTheme(
                centerTitle: false,
                elevation: 0,
                scrolledUnderElevation: 0,
                backgroundColor: colorScheme.surface,
                foregroundColor: colorScheme.onSurface,
                titleTextStyle: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: colorScheme.onSurface,
                ),
              ),
              cardTheme: CardThemeData(
                elevation: 0,
                margin: EdgeInsets.zero,
                color: colorScheme.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              snackBarTheme: SnackBarThemeData(
                behavior: SnackBarBehavior.floating,
                backgroundColor: colorScheme.inverseSurface,
                contentTextStyle:
                    TextStyle(color: colorScheme.onInverseSurface),
              ),
              chipTheme: ChipThemeData(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                side: BorderSide(color: colorScheme.outlineVariant),
              ),
            ),
            home: const AppEntryScreen(),
          );
        },
      ),
    );
  }
}

class AppEntryScreen extends StatefulWidget {
  const AppEntryScreen({super.key});

  @override
  State<AppEntryScreen> createState() => _AppEntryScreenState();
}

class _AppEntryScreenState extends State<AppEntryScreen> {
  final StorageService _storageService = StorageService();
  bool _hasScheduledGuide = false;
  bool _startupHandled = false;

  @override
  void initState() {
    super.initState();
    _handleStartupFlows();
  }

  Future<void> _handleStartupFlows() async {
    if (_startupHandled) {
      return;
    }
    _startupHandled = true;

    final hasAcceptedPrivacy = await _storageService.hasAcceptedPrivacyPolicy();
    final hasSeenGuide = await _storageService.hasSeenUserGuide();

    if (hasAcceptedPrivacy && hasSeenGuide) {
      await UmengAnalyticsService.initializeIfNeeded();
      return;
    }

    if (_hasScheduledGuide || !mounted) {
      return;
    }

    _hasScheduledGuide = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(
        _openGuide(
          requirePrivacyConsent: !hasAcceptedPrivacy,
          initialPrivacyChecked: hasAcceptedPrivacy,
          markGuideSeenAfterExit: !hasSeenGuide,
        ),
      );
    });
  }

  Future<void> _openGuide({
    required bool requirePrivacyConsent,
    required bool initialPrivacyChecked,
    required bool markGuideSeenAfterExit,
  }) async {
    final accepted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        settings: const RouteSettings(name: '/user-guide'),
        builder: (_) => UserGuideScreen(
          requirePrivacyConsent: requirePrivacyConsent,
          initialPrivacyChecked: initialPrivacyChecked,
        ),
        fullscreenDialog: true,
      ),
    );

    if (!mounted) {
      return;
    }

    if (requirePrivacyConsent) {
      if (accepted == true) {
        await _storageService.setAcceptedPrivacyPolicy(true);
        await UmengAnalyticsService.initializeIfNeeded();
      } else {
        return;
      }
    }

    if (markGuideSeenAfterExit) {
      await _storageService.setHasSeenUserGuide(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return const TimetableScreen();
  }
}
