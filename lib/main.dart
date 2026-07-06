import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'logging/app_log_messages.dart';
import 'models/timetable_settings.dart';
import 'providers/timetable_provider.dart';
import 'screens/course_import_screen.dart';
import 'screens/startup_flow_screens.dart';
import 'screens/user_guide_screen.dart';
import 'screens/timetable_screen.dart';
import 'screens/lan_edit_screen.dart';
import 'utils/app_toast.dart';
import 'services/app_log_service.dart';
import 'services/bundled_assets.dart';
import 'services/lan_edit_foreground_service.dart';
import 'services/app_migration_service.dart';
import 'services/storage_service.dart';
import 'services/user_data_sync_hooks.dart';
import 'services/webdav_sync_coordinator.dart';
import 'services/android_animation_scale_service.dart';
import 'services/umeng_analytics_service.dart';
import 'services/frosted_blur_service.dart';
import 'ui/debug/debug.dart';
import 'ui/hyperos/hyperos.dart';

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

FThemeData _foruiThemeData(ForuiTheme theme, Brightness brightness) {
  final pair = switch (theme) {
    ForuiTheme.neutral => FThemes.neutral,
    ForuiTheme.zinc => FThemes.zinc,
    ForuiTheme.slate => FThemes.slate,
    ForuiTheme.blue => FThemes.blue,
    ForuiTheme.green => FThemes.green,
    ForuiTheme.orange => FThemes.orange,
    ForuiTheme.red => FThemes.red,
    ForuiTheme.rose => FThemes.rose,
    ForuiTheme.violet => FThemes.violet,
    ForuiTheme.yellow => FThemes.yellow,
  };
  final base = brightness == Brightness.dark
      ? pair.dark.touch
      : pair.light.touch;
  return base.copyWith(
    headerStyles: FVariantsDelta.delta([
      FVariantOperation.all(
        FHeaderStyleDelta.delta(
          titleTextStyle: TextStyleDelta.delta(
            fontSize: 20,
            fontWeight: FontWeight.w400,
            height: 1.2,
          ),
        ),
      ),
    ]),
  );
}

ThemeData _appThemeData(FThemeData forui, {String? fontFamily}) {
  final material = forui.toApproximateMaterialTheme();
  final themed = material.copyWith(
    pageTransitionsTheme: HyperosNavigation.pageTransitionsTheme,
  );
  if (fontFamily == null || fontFamily.isEmpty) {
    return themed;
  }
  return themed.copyWith(
    textTheme: themed.textTheme.apply(fontFamily: fontFamily),
    primaryTextTheme: themed.primaryTextTheme.apply(fontFamily: fontFamily),
  );
}

String _bootSwitcherLabel(PackageInfo packageInfo) {
  if (packageInfo.packageName.endsWith('.profile')) {
    return '轻屿课表性能版';
  }
  if (packageInfo.packageName.endsWith('.debug')) {
    return '轻屿课表调试版';
  }
  final label = packageInfo.appName.trim();
  return label.isNotEmpty ? label : '轻屿课表';
}

String _windowTitleForPackage(PackageInfo packageInfo, AppLocalizations l10n) {
  if (kReleaseMode) {
    return l10n.appTitle;
  }
  if (packageInfo.packageName.endsWith('.profile')) {
    return l10n.appTitleProfile;
  }
  if (packageInfo.packageName.endsWith('.debug')) {
    return l10n.appTitleDebug;
  }
  final label = packageInfo.appName.trim();
  if (label.isNotEmpty) {
    return label;
  }
  return l10n.appTitle;
}

Future<void> main() async {
  runZonedGuarded(
    () {
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

      unawaited(() async {
        final packageInfo = await PackageInfo.fromPlatform();
        runApp(MyApp(packageInfo: packageInfo));
        unawaited(_warmUpAfterFirstFrame(packageInfo));
      }());
    },
    (error, stackTrace) {
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
    },
  );
}

Future<void> _warmUpAfterFirstFrame(PackageInfo packageInfo) async {
  try {
    await Future.wait([
      BundledAssets.warmUp(),
      AndroidAnimationScaleService.ensureInitialized(),
      FrostedBlurService.probeNativeSupport(),
    ]);
    if (!kReleaseMode) {
      registerHyperosLayoutDebugTuning();
      await loadDebugTuningPreferencesIfNeeded();
    }
    await SystemChrome.setApplicationSwitcherDescription(
      ApplicationSwitcherDescription(label: _bootSwitcherLabel(packageInfo)),
    );
  } catch (error, stackTrace) {
    unawaited(
      AppLogService.instance.error(
        'startup_warmup_failed',
        error.toString(),
        error: error,
        stackTrace: stackTrace,
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.packageInfo});

  final PackageInfo packageInfo;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => TimetableProvider(autoInitialize: false),
        ),
      ],
      child:
          Selector<
            TimetableProvider,
            ({
              ForuiTheme foruiTheme,
              AppFontMode fontMode,
              AppThemeMode themeMode,
              String localeTag,
            })
          >(
            selector: (_, p) => (
              foruiTheme: p.settings.foruiTheme,
              fontMode: p.settings.appFontMode,
              themeMode: p.settings.appThemeMode,
              localeTag: p.settings.appLocaleTag,
            ),
            builder: (context, settings, child) {
              final fontFamily = _fontFamilyFromSettings(settings.fontMode);
              final foruiLight = _foruiThemeData(
                settings.foruiTheme,
                Brightness.light,
              );
              final foruiDark = _foruiThemeData(
                settings.foruiTheme,
                Brightness.dark,
              );

              return MaterialApp(
                debugShowCheckedModeBanner: false,
                onGenerateTitle: (context) => _windowTitleForPackage(
                  packageInfo,
                  AppLocalizations.of(context)!,
                ),
                localizationsDelegates: const [
                  AppLocalizations.delegate,
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                supportedLocales: AppLocalizations.supportedLocales,
                locale: _localeFromSettings(settings.localeTag),
                themeMode: _themeModeFromSettings(settings.themeMode),
                theme: _appThemeData(foruiLight, fontFamily: fontFamily),
                darkTheme: _appThemeData(foruiDark, fontFamily: fontFamily),
                navigatorObservers: <NavigatorObserver>[
                  _AppRouteLogObserver(),
                  hyperosRouteObserver,
                ],
                builder: (context, child) {
                  final isDark =
                      Theme.of(context).brightness == Brightness.dark;
                  final frostedAppearance = FrostedAppearance.fromSettings(
                    context.watch<TimetableProvider>().settings,
                  );
                  return FrostedAppearanceScope(
                    appearance: frostedAppearance,
                    child: FTheme(
                      data: isDark ? foruiDark : foruiLight,
                      child: FTooltipGroup(
                        child: ScaffoldMessenger(
                          child: Scaffold(
                            backgroundColor: Colors.transparent,
                            resizeToAvoidBottomInset: false,
                            body: DebugTuningOverlayHost(child: child!),
                          ),
                        ),
                      ),
                    ),
                  );
                },
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

class _AppEntryScreenState extends State<AppEntryScreen>
    with WidgetsBindingObserver {
  final StorageService _storageService = StorageService();
  final AppMigrationService _migrationService = AppMigrationService();
  final WebdavSyncCoordinator _cloudSyncCoordinator =
      WebdavSyncCoordinator.instance();
  bool _startupHandled = false;
  bool _isBootstrapping = true;
  bool _mainContentReady = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    scheduleCloudSyncUpload = _cloudSyncCoordinator.scheduleUpload;
    unawaited(_handleStartupFlows());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(AndroidAnimationScaleService.refresh());
      unawaited(_cloudSyncCoordinator.maybePullRemote());
    }
  }

  Future<void> _handleStartupFlows() async {
    if (_startupHandled) {
      return;
    }
    _startupHandled = true;
    unawaited(
      AppLogService.instance.info(
        'startup_flow_started',
        AppLogMessages.startupFlowStarted,
      ),
    );

    try {
      // --- 并行初始化和读取所有启动状态 ---
      final initFuture = _storageService.init();
      final legacyPackageFuture = _migrationService
          .findInstalledLegacyPackage();

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
      await Future.wait([provider.initialize(), legacyPackageFuture]);
      _cloudSyncCoordinator.bindProvider(provider);
      unawaited(_cloudSyncCoordinator.maybePullRemote());
      final legacyPackage = await legacyPackageFuture;
      final shouldShowMigrationGuide =
          !hasHandledPackageMigration && isDataEmpty && legacyPackage != null;

      if (!mounted) {
        return;
      }

      if (shouldShowMigrationGuide) {
        final action = await Navigator.of(context).push<MigrationFlowAction>(
          HyperosPageRoute(
            builder: (_) =>
                PackageMigrationGuideScreen(legacyPackageName: legacyPackage),
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
        unawaited(_checkPendingExternalImport());
        unawaited(_installLanEditNotificationHandler());
        unawaited(
          AppLogService.instance.info(
            'startup_flow_completed',
            AppLogMessages.startupFlowCompletedNoOnboarding,
          ),
        );
        await _revealMainContent();
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

      unawaited(_checkPendingExternalImport());
      unawaited(_installLanEditNotificationHandler());
      unawaited(
        AppLogService.instance.info(
          'startup_flow_completed',
          AppLogMessages.startupFlowCompletedAfterGuide,
        ),
      );
      await _revealMainContent();
    } catch (e, stackTrace) {
      // 初始化失败时降级进入主界面，避免白屏 hang
      unawaited(
        AppLogService.instance.error(
          'startup_flow_failed',
          AppLogMessages.startupFlowFailed,
          error: e,
          stackTrace: stackTrace,
        ),
      );
      if (mounted) {
        await _revealMainContent();
      }
    }
  }

  /// Mount [TimetableScreen] under the boot overlay, paint one frame, then fade.
  Future<void> _revealMainContent() async {
    if (!mounted) {
      return;
    }
    if (!_mainContentReady) {
      setState(() => _mainContentReady = true);
      await WidgetsBinding.instance.endOfFrame;
    }
    if (!mounted || !_isBootstrapping) {
      return;
    }
    setState(() => _isBootstrapping = false);
  }

  Future<bool> _openGuide({
    required bool requirePrivacyConsent,
    required bool initialPrivacyChecked,
    required bool markGuideSeenAfterExit,
  }) async {
    final action = await Navigator.of(context).push<GuideAction>(
      HyperosPageRoute(
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
    String? initialContent,
  }) async {
    if (!mounted) {
      return false;
    }
    final l10n = AppLocalizations.of(context)!;
    final provider = context.read<TimetableProvider>();
    final importMode =
        forcedMode ??
        await showHyperosDialog<_BackupImportMode>(
          context: context,
          title: l10n.selectImportModeTitle,
          message: l10n.selectImportModeMessage,
          actions: [
            HyperosDialogAction(
              label: l10n.cancelAction,
              onPressed: () => Navigator.pop(context),
            ),
            HyperosDialogAction(
              label: l10n.replaceCurrentTimetable,
              isPrimary: true,
              onPressed: () =>
                  Navigator.pop(context, _BackupImportMode.replaceCurrent),
            ),
            HyperosDialogAction(
              label: l10n.importAsNewTimetable,
              onPressed: () =>
                  Navigator.pop(context, _BackupImportMode.importAsNew),
            ),
          ],
        );

    if (importMode == null || !mounted) {
      return false;
    }

    try {
      late final String content;
      if (initialContent != null) {
        content = initialContent;
      } else {
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
        content = bytes == null ? '' : utf8.decode(bytes);
      }
      if (content.isEmpty) {
        throw FormatException(l10n.importFileReadFailed);
      }

      final message = switch (importMode) {
        _BackupImportMode.replaceCurrent => await provider.importAppDataBackup(
          content,
        ),
        _BackupImportMode.importAsNew =>
          await provider.importAppDataBackupAsNewProfile(content),
      };

      if (!mounted) {
        return false;
      }
      showAppToast(
        context,
        message:
            message ??
            (importMode == _BackupImportMode.importAsNew
                ? l10n.createdNewTimetableAfterImport
                : l10n.backupRestoredSuccess),
        kind: AppToastKind.success,
      );
      return true;
    } on FormatException catch (e) {
      if (mounted) {
        showAppToast(context, message: e.message, kind: AppToastKind.error);
      }
    } catch (_) {
      if (mounted) {
        showAppToast(
          context,
          message: l10n.importFailedInvalidFile,
          kind: AppToastKind.error,
        );
      }
    }
    return false;
  }

  Future<bool> _runCourseImportFlow() async {
    final imported = await Navigator.of(context).push<bool>(
      HyperosPageRoute(
        settings: const RouteSettings(name: '/courses/import'),
        builder: (_) => const CourseImportScreen(),
      ),
    );
    return imported == true;
  }

  Future<void> _checkPendingExternalImport() async {
    try {
      const channel = MethodChannel('com.mutx163.qingyu/miui_live');
      channel.setMethodCallHandler((call) async {
        if (call.method == 'onExternalImportReceived') {
          await Future.delayed(const Duration(milliseconds: 300));
          await _checkPendingExternalImport();
        }
      });
      final payload = await channel.invokeMethod<Map<Object?, Object?>>(
        'getPendingExternalImport',
      );
      if (payload == null || !mounted) {
        return;
      }

      final kind = payload['kind'] as String?;
      switch (kind) {
        case 'ics':
          final icsContent = payload['textContent'] as String?;
          if (icsContent != null && icsContent.isNotEmpty) {
            await Navigator.of(context).push(
              HyperosPageRoute(
                settings: const RouteSettings(
                  name: '/courses/import/ics-external',
                ),
                builder: (_) =>
                    IcsCourseImportScreen(initialIcsContent: icsContent),
              ),
            );
          }
        case 'backup':
          final backupContent = payload['textContent'] as String?;
          if (backupContent != null && backupContent.isNotEmpty) {
            await _runBackupImportFlow(initialContent: backupContent);
          }
        case 'spreadsheet':
          final filePath = payload['filePath'] as String?;
          final fileName = payload['fileName'] as String?;
          if (filePath != null && filePath.isNotEmpty) {
            await Navigator.of(context).push(
              HyperosPageRoute(
                settings: const RouteSettings(
                  name: '/courses/import/spreadsheet-external',
                ),
                builder: (_) => SpreadsheetCourseImportScreen(
                  initialFilePath: filePath,
                  initialFileName: fileName,
                ),
              ),
            );
          }
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
        HyperosPageRoute(
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
    final overlayColor = HyperosColors.scaffoldBackground(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        if (_mainContentReady) const TimetableScreen(),
        AnimatedOpacity(
          opacity: _isBootstrapping ? 1 : 0,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
          child: IgnorePointer(
            ignoring: !_isBootstrapping,
            child: ColoredBox(
              color: overlayColor,
              child: const Center(child: CircularProgressIndicator()),
            ),
          ),
        ),
      ],
    );
  }
}

enum _BackupImportMode { replaceCurrent, importAsNew }

class _AppLifecycleLogObserver with WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    unawaited(
      AppLogService.instance.info(
        'app_lifecycle_state_changed',
        AppLogMessages.appLifecycleChanged,
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
        AppLogMessages.navigatorRouteReplaced,
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
        AppLogMessages.navigatorRouteChanged,
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
