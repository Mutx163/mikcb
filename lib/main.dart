import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/timetable_provider.dart';
import 'screens/timetable_screen.dart';

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
            title: '大学课程表',
            debugShowCheckedModeBanner: false,
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
              cardTheme: CardTheme(
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
                contentTextStyle: TextStyle(color: colorScheme.onInverseSurface),
              ),
              chipTheme: ChipThemeData(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                side: BorderSide(color: colorScheme.outlineVariant),
              ),
            ),
            home: const TimetableScreen(),
          );
        },
      ),
    );
  }
}
