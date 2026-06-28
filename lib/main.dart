import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'models/timetable_settings.dart';
import 'providers/timetable_provider.dart';
import 'screens/course_import_screen.dart';
import 'screens/startup_flow_screens.dart';
import 'screens/user_guide_screen.dart';
import 'screens/timetable_screen.dart';
import 'screens/lan_edit_screen.dart';
import 'services/app_log_service.dart';
import 'services/lan_edit_foreground_service.dart';
import 'services/app_migration_service.dart';
import 'services/storage_service.dart';
import 'services/umeng_analytics_service.dart';
import 'utils/hex_color.dart';

Color _colorFromHex(String hexColor) {
  return parseHexColorOrFallback(hexColor, fallback: const Color(0xFF2563EB));
}

ThemeMode _themeModeFromSettings(AppThemeMode mode) {
  return switch (mode) {
    AppThemeMode.system => ThemeMode.system,
    AppThemeMode.light => ThemeMode.light,
    AppThemeMode.dark => ThemeMode.dark,
  };
}

String? _fontFamilyFromSettings(AppFontMode mode) {
  return switch (mode) {
    AppFontMode.system => null,
    AppFontMode.miSans => 'MiSans',
  };
}

Locale? _localeFromSettings(String localeTag) {
  final normalized = localeTag.trim();
  if (normalized.isEmpty) {
    return null;
  }
  final canonical = normalized.replaceAll('-', '_');
  for (final locale in AppLocalizations.supportedLocales) {
    final tag = locale.countryCode?.isNotEmpty == true
        ? '${locale.languageCode}_${locale.countryCode}'
        : locale.languageCode;
    if (tag.toLowerCase() == canonical.toLowerCase()) {
      return locale;
    }
  }
  final languageCode = canonical.split('_').first.toLowerCase();
  for (final locale in AppLocalizations.supportedLocales) {
    if (locale.languageCode.toLowerCase() == languageCode) {
      return locale;
    }
  }
  return Locale(languageCode);
}

ThemeData _buildAppTheme(
  Color seedColor,
  Brightness brightness, {
  String? fontFamily,
}) {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: seedColor,
    brightness: brightness,
  );
  final isDark = brightness == Brightness.dark;
  final tdTheme = TDTheme.defaultData();
  final tdExtensions = <ThemeExtension>[
    isDark ? (tdTheme.dark ?? tdTheme) : tdTheme,
  ];
  return ThemeData(
    useMaterial3: true,
    fontFamily: fontFamily,
    colorScheme: colorScheme,
    extensions: tdExtensions,
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
      contentTextStyle: TextStyle(color: colorScheme.onInverseSurface),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      side: BorderSide(color: colorScheme.outlineVariant),
    ),
  );
}

Future<void> main() async {
  runZonedGuarded(() {
    WidgetsFlutterBinding.ensureInitialized();
    unawaited(AppLogService.instance.initialize());
    WidgetsBinding.instance.addObserver(_AppLifecycleLogObserver());

    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      final stackTrace = details.stack ?? StackTrace.current;
      unawaited(
        AppLogService.instance.error(
          'flutter_framework_error',
          details.exceptionAsString(),
          error: details.exception,
          stackTrace: stackTrace,
        ),
      );
      unawaited(
        UmengAnalyticsService.reportUnhandledError(
          details.exception,
          stackTrace,
          category: 'flutter_framework_error',
        ),
      );
    };

    PlatformDispatcher.instance.onError = (error, stackTrace) {
      unawaited(
        AppLogService.instance.error(
          'flutter_platform_error',
          error.toString(),
          error: error,
          stackTrace: stackTrace,
        ),
      );
      unawaited(
        UmengAnalyticsService.reportUnhandledError(
          error,
          stackTrace,
          category: 'flutter_platform_error',
        ),
      );
      return false;
    };

    runApp(const MyApp());
  }, (error, stackTrace) {
    unawaited(
      AppLogService.instance.error(
        'flutter_zone_error',
        error.toString(),
        error: error,
        stackTrace: stackTrace,
      ),
    );
    unawaited(
      UmengAnalyticsService.reportUnhandledError(
        error,
        stackTrace,
        category: 'flutter_zone_error',
      ),
    );
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => TimetableProvider(autoInitialize: false),
        ),
      ],
      child: Selector<TimetableProvider, ({String seedColor, String fontMode, String themeMode, String localeTag})>(
        selector: (_, p) => (
          seedColor: p.settings.themeSeedColor,
          fontMode: p.settings.appFontMode.name,
          themeMode: p.settings.appThemeMode.name,
          localeTag: p.settings.appLocaleTag,
        ),
        builder: (context, settings, child) {
          final seedColor = _colorFromHex(settings.seedColor);
          final fontFamily = _fontFamilyFromSettings(AppFontMode.values.asNameMap()[settings.fontMode] ?? AppFontMode.system);

          return MaterialApp(
            debugShowCheckedModeBanner: false,
            onGenerateTitle: (context) => kReleaseMode
                ? AppLocalizations.of(context)!.appTitle
                : AppLocalizations.of(context)!.appTitleDebug,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            locale: _localeFromSettings(settings.localeTag),
            themeMode: _themeModeFromSettings(AppThemeMode.values.asNameMap()[settings.themeMode] ?? AppThemeMode.system),
            theme: _buildAppTheme(
              seedColor,
              Brightness.light,
              fontFamily: fontFamily,
            ),
            darkTheme: _buildAppTheme(
              seedColor,
              Brightness.dark,
              fontFamily: fontFamily,
            ),
            navigatorObservers: <NavigatorObserver>[
              _AppRouteLogObserver(),
            ],
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
  final AppMigrationService _migrationService = AppMigrationService();
  bool _startupHandled = false;
  bool _isBootstrapping = true;

  @override
  void initState() {
    super.initState();
    unawaited(_handleStartupFlows());
  }

  Future<void> _handleStartupFlows() async {
    if (_startupHandled) {
      return;
    }
    _startupHandled = true;
    unawaited(
      AppLogService.instance.info(
        'startup_flow_started',
        'Startup flow handling started',
      ),
    );

    try {

    // --- 并行初始化和读取所有启动状态 ---
    final initFuture = _storageService.init();
    final legacyPackageFuture = _migrationService.findInstalledLegacyPackage();
    
    await initFuture;
    
    final startupResults = await Future.wait([
      _storageService.isAppDataEffectivelyEmpty(),
      _storageService.hasCompletedOnboarding(),
      _storageService.hasHandledPackageMigration(),
      _storageService.hasAcceptedPrivacyPolicy(),
      _storageService.hasSeenUserGuide(),
    ]);

    final isDataEmpty = startupResults[0];
    final hasHandledPackageMigration = startupResults[2];
    final hasAcceptedPrivacy = startupResults[3];
    final hasSeenGuide = startupResults[4];

    if (!mounted) {
      return;
    }
    final provider = context.read<TimetableProvider>();
    
    // 并行执行 provider 初始化和旧包检测
    await Future.wait([
      provider.initialize(),
      legacyPackageFuture,
    ]);
    final legacyPackage = await legacyPackageFuture;
    final shouldShowMigrationGuide =
        !hasHandledPackageMigration && isDataEmpty && legacyPackage != null;

    if (!mounted) {
      return;
    }

    if (shouldShowMigrationGuide) {
      final action = await Navigator.of(context).push<MigrationFlowAction>(
        MaterialPageRoute(
          builder: (_) => PackageMigrationGuideScreen(
            legacyPackageName: legacyPackage,
          ),
          fullscreenDialog: true,
        ),
      );
      if (!mounted) {
        return;
      }
      if (action == MigrationFlowAction.restoreBackup) {
        final imported = await _runBackupImportFlow(
          forcedMode: _BackupImportMode.replaceCurrent,
        );
        if (imported) {
          await _storageService.setHandledPackageMigration(true);
          await _storageService.setCompletedOnboarding(true);
        }
      } else if (action == MigrationFlowAction.skip) {
        await _storageService.setHandledPackageMigration(true);
        await _storageService.setCompletedOnboarding(true);
      }
    }

    if (hasAcceptedPrivacy && hasSeenGuide) {
      // 非关键初始化：后台执行，不阻塞首帧
      unawaited(AppLogService.instance.updatePrivacyAccepted(true));
      unawaited(UmengAnalyticsService.initializeIfNeeded());
      unawaited(_checkPendingIcsIntent());
      unawaited(_installLanEditNotificationHandler());
      unawaited(
        AppLogService.instance.info(
          'startup_flow_completed',
          'Startup flow completed without onboarding screens',
        ),
      );
      setState(() {
        _isBootstrapping = false;
      });
      return;
    }

    if (!mounted) {
      return;
    }

    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) {
      return;
    }

    final guideCompleted = await _openGuide(
      requirePrivacyConsent: !hasAcceptedPrivacy,
      initialPrivacyChecked: hasAcceptedPrivacy,
      markGuideSeenAfterExit: !hasSeenGuide,
    );
    if (!mounted || !guideCompleted) {
      return;
    }

    if (await _storageService.hasAcceptedPrivacyPolicy()) {
      unawaited(UmengAnalyticsService.initializeIfNeeded());
    }
    if (!mounted) {
      return;
    }

    unawaited(_checkPendingIcsIntent());
    unawaited(_installLanEditNotificationHandler());
    unawaited(
      AppLogService.instance.info(
        'startup_flow_completed',
        'Startup flow completed after guide/onboarding',
      ),
    );
    setState(() {
      _isBootstrapping = false;
    });
    } catch (e, stackTrace) {
      // 初始化失败时降级进入主界面，避免白屏 hang
      unawaited(
        AppLogService.instance.error(
          'startup_flow_failed',
          'Startup flow failed, entering degraded mode',
          error: e,
          stackTrace: stackTrace,
        ),
      );
      if (mounted) {
        setState(() {
          _isBootstrapping = false;
        });
      }
    }
  }

  Future<bool> _openGuide({
    required bool requirePrivacyConsent,
    required bool initialPrivacyChecked,
    required bool markGuideSeenAfterExit,
  }) async {
    final action = await Navigator.of(context).push<GuideAction>(
      MaterialPageRoute(
        settings: const RouteSettings(name: '/user-guide'),
        builder: (_) => UserGuideScreen(
          requirePrivacyConsent: requirePrivacyConsent,
          initialPrivacyChecked: initialPrivacyChecked,
          onImportCourses: _runCourseImportFlow,
          onRestoreBackup: () => _runBackupImportFlow(
            forcedMode: _BackupImportMode.replaceCurrent,
          ),
        ),
        fullscreenDialog: true,
      ),
    );

    if (!mounted) {
      return false;
    }

    if (requirePrivacyConsent) {
      if (action != null) {
        await _storageService.setAcceptedPrivacyPolicy(true);
        await AppLogService.instance.updatePrivacyAccepted(true);
        await UmengAnalyticsService.initializeIfNeeded();
      } else {
        return false;
      }
    }

    if (markGuideSeenAfterExit) {
      await _storageService.setHasSeenUserGuide(true);
    }

    await _storageService.setCompletedOnboarding(true);
    return true;
  }

  Future<bool> _runBackupImportFlow({
    _BackupImportMode? forcedMode,
  }) async {
    if (!mounted) {
      return false;
    }
    final l10n = AppLocalizations.of(context)!;
    final provider = context.read<TimetableProvider>();
    final importMode = forcedMode ??
        await showDialog<_BackupImportMode>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: Text(l10n.selectImportModeTitle),
              content: Text(l10n.selectImportModeMessage),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(l10n.cancelAction),
                ),
                FilledButton(
                  onPressed: () =>
                      Navigator.pop(context, _BackupImportMode.replaceCurrent),
                  child: Text(l10n.replaceCurrentTimetable),
                ),
                FilledButton.tonal(
                  onPressed: () =>
                      Navigator.pop(context, _BackupImportMode.importAsNew),
                  child: Text(l10n.importAsNewTimetable),
                ),
              ],
            );
          },
        );

    if (importMode == null || !mounted) {
      return false;
    }

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        withData: true,
        allowedExtensions: const ['json', 'mikcb'],
      );
      final file = result?.files.single;
      if (file == null) {
        return false;
      }
      final bytes = file.bytes;
      final content = bytes == null ? '' : utf8.decode(bytes);
      if (content.isEmpty) {
        throw FormatException(l10n.importFileReadFailed);
      }

      final message = switch (importMode) {
        _BackupImportMode.replaceCurrent =>
          await provider.importAppDataBackup(content),
        _BackupImportMode.importAsNew =>
          await provider.importAppDataBackupAsNewProfile(content),
      };

      if (!mounted) {
        return false;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message ??
                (importMode == _BackupImportMode.importAsNew
                    ? l10n.createdNewTimetableAfterImport
                    : l10n.backupRestoredSuccess),
          ),
        ),
      );
      return true;
    } on FormatException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.importFailedInvalidFile)),
        );
      }
    }
    return false;
  }

  Future<bool> _runCourseImportFlow() async {
    final imported = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        settings: const RouteSettings(name: '/courses/import'),
        builder: (_) => const CourseImportScreen(),
      ),
    );
    return imported == true;
  }

  Future<void> _checkPendingIcsIntent() async {
    try {
      const channel = MethodChannel('com.mutx163.qingyu/miui_live');
      channel.setMethodCallHandler((call) async {
        if (call.method == 'onIcsIntentReceived') {
          await Future.delayed(const Duration(milliseconds: 300));
          _checkPendingIcsIntent();
        }
      });
      final icsContent = await channel.invokeMethod<String?>('getInitialIcsIntent');
      if (icsContent != null && icsContent.isNotEmpty && mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            settings: const RouteSettings(name: '/courses/import/ics-external'),
            builder: (_) => IcsCourseImportScreen(initialIcsContent: icsContent),
          ),
        );
      }
    } catch (e) {
      // Silently ignore - this is a non-critical feature
    }
  }

  Future<void> _installLanEditNotificationHandler() async {
    await LanEditForegroundBridge.installNotificationTapHandler();
    LanEditForegroundBridge.onNotificationTapped = () {
      unawaited(_openLanEditFromNotification());
    };
    await _openLanEditFromNotification();
  }

  Future<void> _openLanEditFromNotification() async {
    try {
      final pending = await LanEditForegroundBridge.consumePendingOpen();
      if (!pending || !mounted) {
        return;
      }
      final navigator = Navigator.of(context);
      var alreadyOnLanEdit = false;
      navigator.popUntil((route) {
        if (route.settings.name == '/settings/lan-edit') {
          alreadyOnLanEdit = true;
          return true;
        }
        return route.isFirst;
      });
      if (alreadyOnLanEdit) {
        return;
      }
      await navigator.push(
        MaterialPageRoute(
          settings: const RouteSettings(name: '/settings/lan-edit'),
          builder: (_) => const LanEditScreen(),
        ),
      );
    } catch (_) {
      // Non-critical navigation helper.
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isBootstrapping) {
      return const Scaffold();
    }
    return const TimetableScreen();
  }
}

enum _BackupImportMode {
  replaceCurrent,
  importAsNew,
}

class _AppLifecycleLogObserver with WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    unawaited(
      AppLogService.instance.info(
        'app_lifecycle_state_changed',
        'App lifecycle changed',
        extras: {'state': state.name},
      ),
    );
  }
}

class _AppRouteLogObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _log('route_pushed', route, previousRoute);
    super.didPush(route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _log('route_popped', route, previousRoute);
    super.didPop(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    unawaited(
      AppLogService.instance.info(
        'route_replaced',
        'Navigator route replaced',
        extras: {
          'route': _describeRoute(newRoute),
          'previousRoute': _describeRoute(oldRoute),
        },
      ),
    );
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }

  void _log(
    String category,
    Route<dynamic>? route,
    Route<dynamic>? previousRoute,
  ) {
    unawaited(
      AppLogService.instance.debug(
        category,
        'Navigator route changed',
        extras: {
          'route': _describeRoute(route),
          'previousRoute': _describeRoute(previousRoute),
        },
      ),
    );
  }

  String _describeRoute(Route<dynamic>? route) {
    if (route == null) {
      return '';
    }
    final name = route.settings.name?.trim();
    if (name != null && name.isNotEmpty) {
      return name;
    }
    return route.runtimeType.toString();
  }
}

