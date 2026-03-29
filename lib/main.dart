import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'models/timetable_settings.dart';
import 'providers/timetable_provider.dart';
import 'screens/startup_flow_screens.dart';
import 'screens/user_guide_screen.dart';
import 'screens/timetable_screen.dart';
import 'services/app_migration_service.dart';
import 'services/storage_service.dart';
import 'services/umeng_analytics_service.dart';

Color _colorFromHex(String hexColor) {
  final normalized = hexColor.replaceFirst('#', '');
  return Color(int.parse('FF$normalized', radix: 16));
}

ThemeMode _themeModeFromSettings(AppThemeMode mode) {
  return switch (mode) {
    AppThemeMode.system => ThemeMode.system,
    AppThemeMode.light => ThemeMode.light,
    AppThemeMode.dark => ThemeMode.dark,
  };
}

ThemeData _buildAppTheme(Color seedColor, Brightness brightness) {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: seedColor,
    brightness: brightness,
  );
  return ThemeData(
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

    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      final stackTrace = details.stack ?? StackTrace.current;
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

  String get _appTitle => kReleaseMode ? '轻屿课表' : '轻屿课表调试版';

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => TimetableProvider(autoInitialize: false),
        ),
      ],
      child: Consumer<TimetableProvider>(
        builder: (context, provider, child) {
          final seedColor = _colorFromHex(provider.settings.themeSeedColor);

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
            themeMode: _themeModeFromSettings(provider.settings.appThemeMode),
            theme: _buildAppTheme(seedColor, Brightness.light),
            darkTheme: _buildAppTheme(seedColor, Brightness.dark),
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
  bool _hasScheduledGuide = false;
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

    await _storageService.init();
    final isDataEmpty = await _storageService.isAppDataEffectivelyEmpty();
    final hasCompletedOnboarding =
        await _storageService.hasCompletedOnboarding();
    final hasHandledPackageMigration =
        await _storageService.hasHandledPackageMigration();
    final hasAcceptedPrivacy = await _storageService.hasAcceptedPrivacyPolicy();
    final hasSeenGuide = await _storageService.hasSeenUserGuide();
    final legacyPackage = await _migrationService.findInstalledLegacyPackage();
    final shouldShowMigrationGuide =
        !hasHandledPackageMigration && isDataEmpty && legacyPackage != null;

    if (!mounted) {
      return;
    }

    final provider = context.read<TimetableProvider>();
    await provider.initialize();

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
    } else if (!hasCompletedOnboarding) {
      final action = await Navigator.of(context).push<WelcomeFlowAction>(
        MaterialPageRoute(
          builder: (_) => const StartupWelcomeScreen(),
          fullscreenDialog: true,
        ),
      );
      if (!mounted) {
        return;
      }
      if (action != null) {
        var completedOnboarding = false;
        switch (action) {
          case WelcomeFlowAction.importCourses:
            completedOnboarding = await _runCourseImportFlow();
            break;
          case WelcomeFlowAction.restoreBackup:
            completedOnboarding = await _runBackupImportFlow(
              forcedMode: _BackupImportMode.replaceCurrent,
            );
            break;
          case WelcomeFlowAction.viewGuide:
          case WelcomeFlowAction.startUsing:
            completedOnboarding = true;
            break;
        }
        if (completedOnboarding) {
          await _storageService.setCompletedOnboarding(true);
        }
      }
    }

    if (hasAcceptedPrivacy && hasSeenGuide) {
      await UmengAnalyticsService.initializeIfNeeded();
      if (!mounted) {
        return;
      }
      setState(() {
        _isBootstrapping = false;
      });
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

    setState(() {
      _isBootstrapping = false;
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

  Future<bool> _runBackupImportFlow({
    _BackupImportMode? forcedMode,
  }) async {
    if (!mounted) {
      return false;
    }
    final provider = context.read<TimetableProvider>();
    final importMode = forcedMode ??
        await showDialog<_BackupImportMode>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('选择导入方式'),
              content: const Text('你可以覆盖当前课表，或者把备份导入成一个新的独立课表。'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () =>
                      Navigator.pop(context, _BackupImportMode.replaceCurrent),
                  child: const Text('覆盖当前课表'),
                ),
                FilledButton.tonal(
                  onPressed: () =>
                      Navigator.pop(context, _BackupImportMode.importAsNew),
                  child: const Text('导入为新课表'),
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
        throw const FormatException('文件读取失败');
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
                    ? '导入成功，已创建新的课表'
                    : '导入成功，备份数据已恢复'),
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
          const SnackBar(content: Text('导入失败，请确认文件有效')),
        );
      }
    }
    return false;
  }

  Future<bool> _runCourseImportFlow() async {
    final provider = context.read<TimetableProvider>();
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['ics'],
      withData: true,
    );
    if (result == null || result.files.isEmpty || !mounted) {
      return false;
    }

    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('无法读取所选文件')),
      );
      return false;
    }

    final replaceExisting = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('导入课程'),
          content: Text('导入 ${file.name} 时，是否替换现有课程？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('追加导入'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('替换现有'),
            ),
          ],
        );
      },
    );

    if (replaceExisting == null || !mounted) {
      return false;
    }

    final content = utf8.decode(bytes, allowMalformed: true);
    final requiredSectionCount =
        provider.previewWakeUpImportRequiredSectionCount(
      content,
      replaceExisting: replaceExisting,
    );
    var sectionCapacityExpanded = false;
    if (requiredSectionCount > provider.settings.sectionCount) {
      final shouldContinue = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('时间模板节次不足'),
            content: Text(
              '当前课表时间模板只有 ${provider.settings.sectionCount} 节，但导入课表需要到第 $requiredSectionCount 节。是否自动补齐后继续导入？',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('自动补齐并导入'),
              ),
            ],
          );
        },
      );

      if (shouldContinue != true || !mounted) {
        return false;
      }

      final ensureMessage =
          await provider.ensureSectionCapacityForImport(requiredSectionCount);
      if (ensureMessage != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(ensureMessage)),
          );
        }
        return false;
      }
      sectionCapacityExpanded = true;
    }

    final importedCount = await provider.importWakeUpCalendar(
      content,
      replaceExisting: replaceExisting,
    );

    if (!mounted) {
      return false;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          importedCount > 0
              ? sectionCapacityExpanded
                  ? '已自动补齐到第 $requiredSectionCount 节，并导入 $importedCount 条课程'
                  : '已导入 $importedCount 条课程'
              : '未识别到可导入课程',
        ),
      ),
    );
    return importedCount > 0;
  }

  @override
  Widget build(BuildContext context) {
    if (_isBootstrapping) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return const TimetableScreen();
  }
}

enum _BackupImportMode {
  replaceCurrent,
  importAsNew,
}
