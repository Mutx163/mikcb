import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'providers/timetable_provider.dart';
import 'screens/user_guide_screen.dart';
import 'screens/timetable_screen.dart';
import 'services/storage_service.dart';

Color _colorFromHex(String hexColor) {
  final normalized = hexColor.replaceFirst('#', '');
  return Color(int.parse('FF$normalized', radix: 16));
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  String get _appTitle => kReleaseMode ? '大学课程表' : '大学课程表测试';

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

  @override
  void initState() {
    super.initState();
    _scheduleFirstLaunchGuide();
  }

  Future<void> _scheduleFirstLaunchGuide() async {
    final hasSeenGuide = await _storageService.hasSeenUserGuide();
    if (hasSeenGuide || _hasScheduledGuide || !mounted) {
      return;
    }

    _hasScheduledGuide = true;
    await _storageService.setHasSeenUserGuide(true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const UserGuideScreen(),
          fullscreenDialog: true,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return const TimetableScreen();
  }
}
