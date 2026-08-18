import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/l10n/service_message_localizer.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_blackbox/flutter_blackbox.dart';

import 'blackbox_adapters.dart';
import 'logging/app_log_messages.dart';
import 'models/timetable_settings.dart';
import 'providers/timetable_provider.dart';
import 'screens/course_import_screen.dart';
import 'screens/startup_flow_screens.dart';
import 'screens/user_guide_screen.dart';
import 'screens/timetable_screen.dart';
import 'screens/timetable_settings_screen.dart';
import 'screens/lan_edit_screen.dart';
import 'utils/app_toast.dart';
import 'widgets/app_boot_branding.dart';
import 'widgets/miuix_font_weight_scope.dart';
import 'services/app_log_service.dart';
import 'services/bundled_assets.dart';
import 'services/fair_memory_service.dart';
import 'services/debug_deep_link_navigator.dart';
import 'services/debug_deep_link_service.dart';
import 'services/lan_edit_foreground_service.dart';
import 'services/app_migration_service.dart';
import 'services/storage_service.dart';
import 'services/user_data_sync_hooks.dart';
import 'services/webdav_sync_coordinator.dart';
import 'services/android_animation_scale_service.dart';
import 'services/umeng_analytics_service.dart';
import 'services/frosted_blur_service.dart';
import 'ui/app_fonts.dart';
import 'ui/debug/debug.dart';
import 'ui/hyperos/hyperos.dart';
import 'ui/hyperos/hyperos_motion.dart';
import 'ui/hyperos_motion_bridge.dart';
import 'utils/home_page_background.dart';

ThemeMode _themeModeFromSettings(AppThemeMode mode) {
  return switch (mode) {
    AppThemeMode.system => ThemeMode.system,
    AppThemeMode.light => ThemeMode.light,
    AppThemeMode.dark => ThemeMode.dark,
  };
}

ThemeData _appThemeData(
  Brightness brightness, {
  required AppFontSpec fontSpec,
}) {
  final theme = ThemeData(
    brightness: brightness,
    useMaterial3: true,
    pageTransitionsTheme: HyperosNavigation.pageTransitionsTheme,
  );
  final fontFamily = fontSpec.fontFamily;
  if (fontFamily == null || fontFamily.isEmpty) {
    return theme;
  }
  return theme.copyWith(
    textTheme: theme.textTheme.apply(
      fontFamily: fontFamily,
      fontFamilyFallback: fontSpec.fontFamilyFallback,
    ),
  );
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

String _bootSwitcherLabel(PackageInfo packageInfo, AppLocalizations l10n) {
  if (packageInfo.packageName.endsWith('.profile')) {
    return l10n.appTitleProfile;
  }
  if (packageInfo.packageName.endsWith('.debug')) {
    return l10n.appTitleDebug;
  }
  final label = packageInfo.appName.trim();
  return label.isNotEmpty ? label : l10n.appTitle;
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
  // Keep Android's native SplashLayerDrawable visible until the Flutter brand
  // layer can render with the real launcher bitmap on its very first frame.
  WidgetsFlutterBinding.ensureInitialized();
  await BundledAssets.warmUpLauncherIcon();
  // Pre-warm the liquid_glass_widgets fragment/indicator shaders so the first
  // glass bar frame does not stall on shader compilation.
  await LiquidGlassWidgets.initialize();
  runZonedGuarded(
    () {
      WidgetsFlutterBinding.ensureInitialized();
      unawaited(AppLogService.instance.initialize());
      FairMemoryService.instance.ensureInitialized();
      WidgetsBinding.instance.addObserver(_AppLifecycleLogObserver());

      FlutterError.onError = (details) {
        // Debug 构建下 presentError 会把异常重新抛进 zone，中断当前帧导致
        // UI 卡死但"看起来没报错"。这里强制落盘（force: true），并同步
        // 打印到终端，方便定位这类「卡死无响应」的框架异常。
        debugPrint(
          '[FlutterError.onError] ${details.exceptionAsString()}\n'
          '${details.stack ?? StackTrace.current}',
        );
        // 仍保留默认呈现，让开发者工具/IDE 也能看到异常。
        FlutterError.presentError(details);
        final stackTrace = details.stack ?? StackTrace.current;
        unawaited(
          AppLogService.instance.error(
            'flutter_framework_error',
            details.exceptionAsString(),
            error: details.exception,
            stackTrace: stackTrace,
            force: true,
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

      if (!kReleaseMode) {
        setupBlackBox();
      }
      // liquid_glass_widgets 的 AdaptiveGlass 自行处理引擎自适应
      // （Impeller 真折射 / Skia 轻量 shader / frosted 回退），无需启动探测。
      runApp(
        LiquidGlassWidgets.wrap(
          child: const _PackageInfoLoader(),
          // MaterialApp 集成：让玻璃组件跟随应用 ThemeMode（而非系统亮度）。
          brightnessResolver: Theme.maybeBrightnessOf,
        ),
      );
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
    configureHyperosMotionFromAndroid();
    if (!kReleaseMode) {
      await loadBlackBoxOverlayPreferencesIfNeeded();
    }
    final l10n = lookupAppLocalizations(PlatformDispatcher.instance.locale);
    await SystemChrome.setApplicationSwitcherDescription(
      ApplicationSwitcherDescription(
        label: _bootSwitcherLabel(packageInfo, l10n),
        // Android 14+ rejects null primaryColor in the platform channel envelope.
        primaryColor: HyperosMiuixLightColors.primary.toARGB32(),
      ),
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
            ({AppFontMode fontMode, AppThemeMode themeMode, String localeTag})
          >(
            selector: (_, p) => (
              fontMode: p.settings.appFontMode,
              themeMode: p.settings.appThemeMode,
              localeTag: p.settings.appLocaleTag,
            ),
            builder: (context, settings, child) {
              final fontSpec = settings.fontMode.fontSpec;

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
                theme: _appThemeData(Brightness.light, fontSpec: fontSpec),
                darkTheme: _appThemeData(Brightness.dark, fontSpec: fontSpec),
                // Android VIEW deep links (mikcb-debug://...) are also delivered
                // as Flutter pushNamed routes. We navigate via MethodChannel +
                // DebugDeepLinkNavigator; swallow unknown platform routes so
                // WidgetsApp does not assert "Could not find a generator".
                onUnknownRoute: _buildUnknownPlatformRoute,
                navigatorObservers: <NavigatorObserver>[
                  _AppRouteLogObserver(),
                  FairMemoryService.instance.routeObserver,
                  hyperosRouteObserver,
                  if (!kReleaseMode) BlackBox.journeyObserver,
                ],
                builder: (context, child) {
                  final frostedAppearance = context
                      .watch<TimetableProvider>()
                      .settings
                      .frostedAppearance;
                  return BlackBoxOverlayHost(
                    child: HyperosMotionHost(
                      child: FrostedAppearanceScope(
                        appearance: frostedAppearance,
                        child: ScaffoldMessenger(
                          child: Scaffold(
                            backgroundColor: Colors.transparent,
                            resizeToAvoidBottomInset: false,
                            body: MiuixFontWeightScope(child: child!),
                          ),
                        ),
                      ),
                    ),
                  );
                },
                home: AppEntryScreen(packageInfo: packageInfo),
              );
            },
          ),
    );
  }
}

/// Ghost route for platform deep links that Flutter auto pushNamed's.
///
/// Immediately removes itself so the navigation stack stays clean while our
/// debug MethodChannel handler performs the real navigation.
Route<dynamic> _buildUnknownPlatformRoute(RouteSettings settings) {
  return PageRouteBuilder<void>(
    settings: settings,
    opaque: false,
    barrierDismissible: true,
    transitionDuration: Duration.zero,
    reverseTransitionDuration: Duration.zero,
    pageBuilder: (context, animation, secondaryAnimation) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) {
          return;
        }
        final route = ModalRoute.of(context);
        if (route != null && route.isActive) {
          final navigator = Navigator.of(context);
          if (navigator.canPop()) {
            navigator.removeRoute(route);
          }
        }
      });
      return const SizedBox.shrink();
    },
  );
}

class AppEntryScreen extends StatefulWidget {
  const AppEntryScreen({super.key, required this.packageInfo});

  final PackageInfo packageInfo;

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
  bool _fairMemoryRecoveryHandled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final provider = context.read<TimetableProvider>();
    FairMemoryService.instance.registerSnapshotProvider(() async {
      return <String, Object?>{
        'activeProfileId': provider.activeProfileId,
        'currentWeek': provider.currentWeek,
        'currentDateWeek': provider.currentDateWeek,
        'currentDayOfWeek': provider.currentDayOfWeek,
      };
    });
    scheduleCloudSyncUpload = _cloudSyncCoordinator.scheduleUpload;
    // Shared MethodChannel handler for external import + debug deep links.
    // Installed early so routes that arrive during splash are not dropped.
    unawaited(_installSharedMethodChannelHandler());
    if (!kReleaseMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        DebugDeepLinkNavigator.attach(context);
        unawaited(DebugDeepLinkService.drainPending());
      });
    }
    unawaited(_handleStartupFlows());
  }

  Future<void> _installSharedMethodChannelHandler() async {
    const channel = MethodChannel('com.mutx163.qingyu/miui_live');
    channel.setMethodCallHandler((call) async {
      if (call.method == 'onExternalImportReceived') {
        await Future.delayed(const Duration(milliseconds: 300));
        await _checkPendingExternalImport();
      } else if (call.method == 'onDebugRouteReceived' && !kReleaseMode) {
        await DebugDeepLinkService.onNativeRouteReceived();
      }
    });
  }

  @override
  void dispose() {
    if (!kReleaseMode) {
      DebugDeepLinkNavigator.detach();
    }
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(refreshHyperosMotionFromAndroid());
      // Pull first, then live resync. Concurrent pull apply + handleAppResumed
      // can push stale schedule snapshots to the island / home widget.
      unawaited(_handleAppResumedWithCloudPull());
    }
  }

  /// Serializes WebDAV auto-pull and live-activity resume recovery.
  Future<void> _handleAppResumedWithCloudPull() async {
    await _cloudSyncCoordinator.maybePullRemote();
    if (!mounted) {
      return;
    }
    await context.read<TimetableProvider>().handleAppResumed();
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
      await _storageService.init();
      if (!mounted) {
        return;
      }

      final hasAcceptedPrivacy = await _storageService
          .hasAcceptedPrivacyPolicy();
      final hasSeenGuide = await _storageService.hasSeenUserGuide();
      if (!mounted) {
        return;
      }
      final provider = context.read<TimetableProvider>();

      // 老用户快速路径：等待本地课表快照完成后再进入主界面。
      if (hasAcceptedPrivacy && hasSeenGuide) {
        _cloudSyncCoordinator.bindProvider(provider);
        // Do not fade the brand layer until the local timetable snapshot is
        // ready; otherwise the first visible frame can be an empty/default
        // timetable while storage is still being read.
        await provider.initialize();
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
        unawaited(_maybeShowDeferredMigrationGuide());
        await _revealMainContent();
        // Remote sync is intentionally post-reveal: local data drives the
        // first correct frame, while network work can update it afterward.
        unawaited(_cloudSyncCoordinator.maybePullRemote());
        return;
      }

      final legacyPackageFuture = _migrationService
          .findInstalledLegacyPackage();
      final providerInitFuture = provider.initialize();

      final startupResults = await Future.wait([
        _storageService.isAppDataEffectivelyEmpty(),
        _storageService.hasCompletedOnboarding(),
        _storageService.hasHandledPackageMigration(),
        Future<bool>.value(hasAcceptedPrivacy),
        Future<bool>.value(hasSeenGuide),
      ]);

      final isDataEmpty = startupResults[0];
      final hasHandledPackageMigration = startupResults[2];

      await Future.wait([providerInitFuture, legacyPackageFuture]);
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

  /// 快速启动路径下，极少数未完成迁移的老用户仍可能在后台弹出迁移引导。
  Future<void> _maybeShowDeferredMigrationGuide() async {
    try {
      if (!mounted) {
        return;
      }
      if (await _storageService.hasHandledPackageMigration()) {
        return;
      }
      if (!await _storageService.isAppDataEffectivelyEmpty()) {
        return;
      }
      final legacyPackage = await _migrationService
          .findInstalledLegacyPackage();
      if (!mounted || legacyPackage == null) {
        return;
      }

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
    } catch (_) {
      // Non-critical deferred migration helper.
    }
  }

  /// Mount [TimetableScreen] under the boot overlay, paint one frame, then remove the overlay.
  Future<void> _revealMainContent() async {
    if (!mounted) {
      return;
    }

    // The provider intentionally starts wallpaper decoding in the background
    // so normal settings changes stay responsive. Startup is different: if the
    // home backdrop is not decoded yet, the first timetable frame is an opaque
    // dark surface and the wallpaper/glass appears one frame later. Keep the
    // branding layer up until the image provider has delivered its first frame.
    await precacheHomePageBackdropImage(
      context.read<TimetableProvider>().settings,
    );
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
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) {
      await _restoreFairMemoryScene();
    }
  }

  Future<void> _restoreFairMemoryScene() async {
    if (_fairMemoryRecoveryHandled) {
      return;
    }
    _fairMemoryRecoveryHandled = true;
    final snapshot = await FairMemoryService.instance
        .takePendingRecoverySnapshot();
    if (!mounted) {
      return;
    }
    if (snapshot != null) {
      await _restoreFairMemoryBusinessState(snapshot.businessState);
      if (!mounted) {
        return;
      }
    }
    final lastRoute = snapshot?.lastNamedRoute;
    if (lastRoute == null || lastRoute == '/') {
      return;
    }

    final navigator = Navigator.of(context);
    if (lastRoute == '/settings/lan-edit') {
      unawaited(
        navigator.push<void>(
          HyperosPageRoute(
            settings: const RouteSettings(name: '/settings/lan-edit'),
            builder: (_) => const LanEditScreen(),
          ),
        ),
      );
      return;
    }
    if (lastRoute.startsWith('/settings')) {
      unawaited(
        navigator.push<void>(
          HyperosPageRoute(
            settings: const RouteSettings(name: '/settings'),
            builder: (_) => const TimetableSettingsScreen(),
          ),
        ),
      );
      return;
    }
    if (lastRoute.startsWith('/courses/import')) {
      unawaited(
        navigator.push<void>(
          HyperosPageRoute(
            settings: const RouteSettings(name: '/courses/import'),
            builder: (_) => const CourseImportScreen(),
          ),
        ),
      );
    }
  }

  Future<void> _restoreFairMemoryBusinessState(
    Map<String, Object?> businessState,
  ) async {
    final provider = context.read<TimetableProvider>();
    try {
      await provider.initialize();
      final profileId = businessState['activeProfileId'];
      if (profileId is String &&
          profileId.isNotEmpty &&
          profileId != provider.activeProfileId &&
          provider.profiles.any((profile) => profile.id == profileId)) {
        await provider.switchProfile(profileId);
      }
      final weekValue = businessState['currentWeek'];
      final week = weekValue is num ? weekValue.toInt() : 0;
      if (week > 0 && week != provider.currentWeek) {
        await provider.setCurrentWeek(week);
      }
    } catch (_) {
      // Normal startup state remains the fallback if recovery is incomplete.
    }
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
        final result = await FilePicker.pickFiles(
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
        message: message != null
            ? localizeServiceMessage(l10n, message)
            : (importMode == _BackupImportMode.importAsNew
                  ? l10n.createdNewTimetableAfterImport
                  : l10n.backupRestoredSuccess),
        kind: message != null ? AppToastKind.error : AppToastKind.success,
      );
      return message == null;
    } on FormatException catch (e) {
      if (mounted) {
        showAppToast(
          context,
          message: localizeServiceMessage(l10n, e.message),
          kind: AppToastKind.error,
        );
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;
    final appLabel = AppBootBranding.resolveAppLabel(widget.packageInfo, l10n);
    return Stack(
      fit: StackFit.expand,
      children: [
        if (_mainContentReady) TimetableScreen(packageInfo: widget.packageInfo),
        // Do not alpha-fade this full-screen layer.  In dark mode the opaque
        // branding background would be composited over the already-rendered
        // home page during the fade, making wallpaper and liquid-glass cards
        // look black before the layer disappears.  The main page is mounted
        // and painted for one frame in [_revealMainContent] before this layer
        // is removed, so the handoff is an atomic swap instead.
        if (_isBootstrapping)
          IgnorePointer(
            child: ColoredBox(
              color: AppBootBranding.backgroundColor(isDark: isDark),
              child: AppBootBranding(appLabel: appLabel, isDark: isDark),
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

/// Loads [PackageInfo] after the first frame so [runApp] is not blocked.
class _PackageInfoLoader extends StatefulWidget {
  const _PackageInfoLoader();

  @override
  State<_PackageInfoLoader> createState() => _PackageInfoLoaderState();
}

class _PackageInfoLoaderState extends State<_PackageInfoLoader> {
  PackageInfo? _packageInfo;

  @override
  void initState() {
    super.initState();
    unawaited(_loadPackageInfo());
  }

  Future<void> _loadPackageInfo() async {
    final packageInfo = await PackageInfo.fromPlatform();
    if (!mounted) {
      return;
    }
    setState(() => _packageInfo = packageInfo);
    unawaited(_warmUpAfterFirstFrame(packageInfo));
  }

  @override
  Widget build(BuildContext context) {
    final packageInfo = _packageInfo;
    if (packageInfo == null) {
      // PackageInfo not loaded yet — show only the background colour so the
      // native SplashLayerDrawable (window background) remains visible with
      // the correct manifest label.  Showing AppBootBranding here would
      // display l10n.appTitle ("轻屿课表") instead of the flavor-aware label
      // ("轻屿课表调试版"), causing a visible label flicker.
      final isDark =
          PlatformDispatcher.instance.platformBrightness == Brightness.dark;
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: ColoredBox(
          color: AppBootBranding.backgroundColor(isDark: isDark),
        ),
      );
    }
    return MyApp(packageInfo: packageInfo);
  }
}
