import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';
import 'package:provider/provider.dart';

import '../../controllers/day_view_transition_controller.dart';
import '../../controllers/empty_slot_marker_controller.dart';
import '../../controllers/home_menu_controller.dart';
import '../../controllers/home_pull_controller.dart';
import '../../controllers/wallpaper_luminance_controller.dart';
import '../../controllers/week_pager_controller.dart';
import '../../domain/day_course_display_logic.dart';
import '../../domain/timetable_layout.dart';
import '../../domain/week_calculator.dart';
import '../../l10n/app_localizations.dart';
import '../../models/course.dart';
import '../../models/timetable_settings.dart';
import '../../providers/timetable_provider.dart';
import '../../providers/weather_provider.dart';
import '../../ui/home/home_chrome_spec.dart';
import '../../ui/hyperos/hyperos.dart';
import '../../ui/hyperos/liquid/liquid_glass_surface.dart'
    show LiquidGlassSurfaceState;
import '../course_grid_surface_host.dart';
import '../course_weather_display.dart';
import '../home_menu_catalog.dart';
import '../week_selector_picker_sheet.dart';
import 'timetable_glass_dock.dart';
import 'timetable_home_action_page_button.dart' show popupActionSourceRect;
import 'timetable_home_dock_shell.dart';
import 'timetable_home_header.dart';
import 'timetable_home_stack_builder.dart';
import 'timetable_profile_switch_flow.dart';
import 'timetable_profile_switcher_trigger.dart';
import 'timetable_week_grid.dart';
import 'timetable_week_page_body.dart';
import 'weekday_ink_contrast_guard.dart';

/// 首页标题左侧微调（沿用原 State 常量）。
const double _homeTitleHorizontalNudge = 4;

/// 课表首页每帧构建所需的宿主端口（2026-10-20 从 `timetable_screen.dart` 的
/// `build()` / `_buildHomeStackView` / `_buildDockShell` 三处搬出）。
///
/// 这里只收「数据 + 控制器 + 回调」：不 import `screens/`、也不读
/// [TimetableProvider]（provider 是参数），把组装逻辑与 State 解耦成可单测的
/// 组合根。真正持有状态的仍是页面 State，本类只在一帧内有效。
class TimetableHomePageInput {
  final BuildContext context;
  final TimetableProvider provider;
  final TimetableSettings settings;
  final AppLocalizations l10n;
  final bool Function() isMounted;

  final WeekPagerController weekPager;
  final DayViewTransitionController dayViewTransition;
  final HomePullController homePull;
  final EmptySlotMarkerController emptySlot;
  final WallpaperLuminanceController luminance;
  final WeekdayInkContrastGuard weekdayInkGuard;
  final HomeMenuController homeMenu;
  final AnimationController dayViewExpandAnimation;

  final ScrollPhysics homePullVerticalPhysics;
  final ScrollController? Function(String key) previewControllerFor;
  final Widget Function(String key, Widget child) reportHomeScroll;

  final GlobalKey timetableSurfaceKey;
  final GlobalKey topMenuButtonKey;
  final LayerLink moreBallLink;
  final LayerLink heartBallLink;
  final GlobalKey<LiquidGlassSurfaceState> glassDockKey;
  final GlobalKey<LiquidGlassSurfaceState> glassDockRoundKey;
  final Listenable glassDockCardRepaint;

  final String? dockInlinePageId;
  final bool isDayView;
  final bool hasSelectedDay;
  final bool coupleOverlayActive;
  final ValueListenable<(int, int)?> dayHeaderPreview;
  final double glassDockPillOccupancy;
  final double Function(TimetableSettings settings) glassDockContentScrollInset;

  final VoidCallback onToggleCoupleOverlay;
  final void Function(BuildContext hostContext, Rect sourceRect)
  openProfileManagePage;
  final bool Function(int week, int dayOfWeek) isSelectedDay;
  final ValueChanged<Offset> onDayTapDown;
  final void Function(
    int week,
    int dayOfWeek,
    int startSection,
    int endSection,
  )
  onOpenAddCourse;
  final Widget Function(int week) buildAnchoredDayViewOverlay;
  final void Function(
    Course course,
    int week, {
    DayCourseDisplayItem? displayItem,
  })
  showCourseActions;

  final TimetableCoursesForDay coursesForDay;
  final TimetableBuildDisplayItems buildDisplayItems;
  final DateTime? Function(TimetableSettings settings, int week, int dayOfWeek)
  dateForWeekDay;
  final List<DayCourseDisplayItem> Function(
    List<DayCourseDisplayItem> items,
    int section,
  )
  startingAt;
  final String? Function(
    DayCourseDisplayItem item, {
    required TimetableSettings settings,
  })
  resolveColor;

  final void Function(String id, TimetableSettings settings) onDockTap;
  final Widget Function({required Color dotBorderColor}) buildMoreActionIcon;

  final bool Function(
    TimetableProvider provider,
    TimetableSettings settings,
    int visibleWeek,
  )
  shouldShowBackToCurrentWeek;
  final VoidCallback onJumpToCurrentWeek;
  final bool Function(TimetableProvider provider) shouldShowBackToToday;
  final double Function(TimetableSettings settings) backToTodayBottomInset;
  final VoidCallback onNavigateToday;

  const TimetableHomePageInput({
    required this.context,
    required this.provider,
    required this.settings,
    required this.l10n,
    required this.isMounted,
    required this.weekPager,
    required this.dayViewTransition,
    required this.homePull,
    required this.emptySlot,
    required this.luminance,
    required this.weekdayInkGuard,
    required this.homeMenu,
    required this.dayViewExpandAnimation,
    required this.homePullVerticalPhysics,
    required this.previewControllerFor,
    required this.reportHomeScroll,
    required this.timetableSurfaceKey,
    required this.topMenuButtonKey,
    required this.moreBallLink,
    required this.heartBallLink,
    required this.glassDockKey,
    required this.glassDockRoundKey,
    required this.glassDockCardRepaint,
    required this.dockInlinePageId,
    required this.isDayView,
    required this.hasSelectedDay,
    required this.coupleOverlayActive,
    required this.dayHeaderPreview,
    required this.glassDockPillOccupancy,
    required this.glassDockContentScrollInset,
    required this.onToggleCoupleOverlay,
    required this.openProfileManagePage,
    required this.isSelectedDay,
    required this.onDayTapDown,
    required this.onOpenAddCourse,
    required this.buildAnchoredDayViewOverlay,
    required this.showCourseActions,
    required this.coursesForDay,
    required this.buildDisplayItems,
    required this.dateForWeekDay,
    required this.startingAt,
    required this.resolveColor,
    required this.onDockTap,
    required this.buildMoreActionIcon,
    required this.shouldShowBackToCurrentWeek,
    required this.onJumpToCurrentWeek,
    required this.shouldShowBackToToday,
    required this.backToTodayBottomInset,
    required this.onNavigateToday,
  });
}

/// 构建课表首页的一帧：解析 chrome → 常驻玻璃球 → 首页栈 → 玻璃坞外壳。
///
/// 与搬迁前 `build()` 内的顺序逐项一致（亮度 seed → chrome 解析 → 亮度采样
/// 排程 → 帧末墨色提示 → 玻璃球 → 首页栈 → 坞外壳），任何一步的时序变化都
/// 会影响首帧墨色 / 玻璃采样，故保持原位不动。
Widget buildTimetableHomePage(TimetableHomePageInput input) {
  final context = input.context;
  final provider = input.provider;
  final settings = input.settings;
  final l10n = input.l10n;
  final luminance = input.luminance;
  final homeMenu = input.homeMenu;
  final weekPager = input.weekPager;
  final dayViewTransition = input.dayViewTransition;
  final homePull = input.homePull;

  final colorScheme = Theme.of(context).colorScheme;
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final darkFallback = colorScheme.surface;
  final viewportSize = MediaQuery.sizeOf(context);
  // 启动预热器 / 本进程里任意一份首页采过的亮度带，只要这一份键对得上就
  // 首帧直接采用：标题/状态栏/星期栏/底栏的黑白墨极性第一帧即正确，不出现
  // 「按主题兜底再翻面」的闪变（缩尺预览那份首页靠的就是这条）。仅在本页
  // 尚未开始采样时生效；异步精确采样照常运行并以同值幂等收敛。
  luminance.seedFromPrimerOrShare(settings, viewportSize: viewportSize);
  final chrome = resolveHomeChromeSpec(
    context: context,
    settings: settings,
    isDark: isDark,
    darkFallback: darkFallback,
    wallpaperTopLuminance: luminance.top,
  );
  final glassDockForm = chrome.glassDockForm;
  final hasBackdrop = chrome.hasBackdrop;
  final chromeForeground = chrome.chromeForeground;
  final chromeMutedForeground = chrome.chromeMutedForeground;
  final chromeDotBorderColor = chrome.chromeDotBorderColor;
  final followsWeekPager = chrome.followsWeekPager;
  final useHomePreblur = chrome.useHomePreblur;
  final homePreblurSigma = chrome.homePreblurSigma;
  final courseCardPreblurSigma = chrome.courseCardPreblurSigma;
  luminance.schedule(settings, viewportSize: viewportSize);
  // After the sample lands: a hand-picked weekday ink can be invisible over
  // this wallpaper — never silently override it, explain instead.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (input.isMounted()) {
      input.weekdayInkGuard.maybeWarn(
        context: context,
        provider: provider,
        settings: settings,
        luminance: luminance.weekdayInk(settings),
      );
    }
  });
  // 顶栏「更多」「爱心」的常驻玻璃球（[FHeaderActionBall]）。**必须画在采样
  // 宿主之外**（[HomeMenuController.buildShell] 的 Stack 里、Host 的兄弟层）：
  // 页内玻璃的采样快照录自捕获节点的图层，球若长在捕获子树里，它自己的输出
  // 会被烘进下一次采样 —— 打开菜单时按钮被上游隐藏，快照是干净的，关闭后
  // 按钮重绘即触发重采样，球就"变一次材质"并稳定在烘过自己一层的样子
  //（2026-09-14 真机现象）。
  final homeChromeBalls = buildTimetableHomeChromeBalls(
    homeMenuAnchor: homeMenu.anchor,
    moreLink: input.moreBallLink,
    heartLink: input.heartBallLink,
    hasPartnerBinding: provider.hasPartnerBinding,
    coupleOverlayActive: input.coupleOverlayActive,
    moreIcon: input.buildMoreActionIcon(
      dotBorderColor: chromeDotBorderColor,
    ),
    chromeActionBallInk: context.theme.colors.foreground,
  );
  final labels = _dayCourseDisplayLabels(l10n);
  final homeStack = TimetableHomeStackBuilder(
    host: TimetableHomeStackHost(
      provider: provider,
      settings: settings,
      l10n: l10n,
      chrome: chrome,
      chromeForeground: chromeForeground,
      chromeMutedForeground: chromeMutedForeground,
      hasBackdrop: hasBackdrop,
      glassDockForm: glassDockForm,
      weekPageController: weekPager.pageController,
      title: TimetableProfileSwitcherTrigger(
        style: settings.homeTitleStyle,
        activeProfileName: provider.activeProfile?.name.trim(),
        onTap: () => showTimetableProfileQuickSwitchFlow(
          context,
          provider: provider,
          popupSourceRect: popupActionSourceRect,
          openManagePage: input.openProfileManagePage,
        ),
        foreground: chromeForeground,
        mutedForeground: chromeMutedForeground,
        leftPadding: _homeTitleHorizontalNudge,
      ),
      suffixes: buildTimetableHomeHeaderActions(
        l10n: l10n,
        hasPartnerBinding: provider.hasPartnerBinding,
        coupleOverlayActive: input.coupleOverlayActive,
        heartLink: input.heartBallLink,
        moreLink: input.moreBallLink,
        homeMenuAnchor: homeMenu.anchor,
        topMenuButtonKey: input.topMenuButtonKey,
        onToggleCoupleOverlay: input.onToggleCoupleOverlay,
        onPrewarmGlass: homeMenu.prewarmGlass,
        onReleaseGlass: homeMenu.releaseGlassAfterTap,
        onShowTopActions: () => homeMenu.showTopActionsSheet(context),
      ),
      timetableSurfaceKey: input.timetableSurfaceKey,
      isPullRunning: homePull.isRunning,
      pullDragDistance: homePull.dragDistance,
      pullTriggerDistance: HomePullController.triggerDistance,
      isDayView: input.isDayView,
      glassDockContentScrollInset: input.glassDockContentScrollInset(settings),
      onScrollNotification: homePull.handleScrollNotification,
      onPullUpdate: homePull.updateDrag,
      onPullEnd: homePull.finishDrag,
      onPullCancel: homePull.cancelDrag,
      resetFreeze: homePull.resetFreeze,
      onPointerMove: homePull.onPointerMove,
      dayViewPageController: dayViewTransition.pageController,
      visibleDayViewWeek: dayViewTransition.visibleWeek,
      shouldShowDayViewOverlay:
          input.hasSelectedDay &&
          (input.isDayView || input.dayViewExpandAnimation.isAnimating),
      wallpaperTopLuminance: luminance.top,
      wallpaperWeekdayLuminance: luminance.weekday,
      wallpaperBodyLuminance: luminance.body,
      timeColumnWidth: timeColumnWidth(settings),
      visibleDays: visibleDayNumbers(settings),
      cardInset: courseCardInset(settings),
      isSelectedDay: input.isSelectedDay,
      hasExamOnDate: provider.hasExamOnDate,
      onShowWeekSelector: () => _showWeekSelector(input),
      onDayTapDown: input.onDayTapDown,
      onDayTap: (week, dayOfWeek) {
        dayViewTransition.toggle(
          week: week,
          dayOfWeek: dayOfWeek,
          settings: settings,
        );
      },
      onFinalizeWeekPageSettled: () =>
          weekPager.finalizeWeekPageSettled(provider),
      onHandleWeekPageChanged: (page) =>
          weekPager.handleWeekPageChanged(page, settings.semesterWeekCount),
      emptySlot: input.emptySlot,
      coursesForDay: input.coursesForDay,
      buildDisplayItems: input.buildDisplayItems,
      wrapSurfaceHost: ({required settings, required child}) =>
          CourseGridSurfaceHost(settings: settings, child: child),
      dateForWeekDay: input.dateForWeekDay,
      startingAt: input.startingAt,
      resolveColor: input.resolveColor,
      overline: (item, showConflictBadge) => resolveCompactOverlineText(
        item,
        labels: labels,
        showConflictBadge: showConflictBadge,
      ),
      badge: (item, showConflictBadge) => resolveCompactBadgeText(
        item,
        labels: labels,
        showConflictBadge: showConflictBadge,
      ),
      weather: (item, date, week) => _weekCardWeatherDisplay(
        l10n: l10n,
        weather: context.watch<WeatherProvider?>(),
        settings: settings,
        course: item.course,
        date: date,
        week: week,
        isPartnerCourse: item.isPartnerCourse,
      ),
      showActions: input.showCourseActions,
      onOpenAddCourse: (week, dayOfWeek, startSection, endSection) =>
          input.onOpenAddCourse(week, dayOfWeek, startSection, endSection),
      buildBody: (settings, week, grid) =>
          _buildWeekPageBody(input, settings: settings, week: week, grid: grid),
      buildAnchoredOverlay: (week) => _buildAnchoredDayViewOverlay(
        input,
        week: week,
      ),
      onWeekdayBarDragStart: dayViewTransition.startWeekdayBarDrag,
      onWeekdayBarDragUpdate: dayViewTransition.updateWeekdayBarDrag,
      onWeekdayBarDragEnd: dayViewTransition.endWeekdayBarDrag,
      onWeekdayBarDragCancel: dayViewTransition.cancelWeekdayBarDrag,
      visibleWeekListenable: weekPager.visibleWeekListenable,
      shouldShowBackToCurrentWeek: input.shouldShowBackToCurrentWeek,
      onJumpToCurrentWeek: input.onJumpToCurrentWeek,
      glassDockPillOccupancy: input.glassDockPillOccupancy,
      dayHeaderPreview: input.dayHeaderPreview,
      shouldShowBackToToday: input.shouldShowBackToToday,
      backToTodayBottomInset: input.backToTodayBottomInset,
      onNavigateToday: input.onNavigateToday,
    ),
  );

  // 玻璃坞形态下课表（含壁纸）与设置页都常驻挂载，用 Offstage 切换：
  // - 设置页的滚动位置与大标题折叠状态不随 Tab 切换丢失（切走再切回，
  //   标题保持离开时的折叠态）；
  // - 壁纸层随 homeStack 常驻，解码缓存不失效，切回课表不黑闪。
  // 玻璃坞导航始终由 [TimetableGlassDockLayer] 浮在最上层（画在采样宿主之外）。
  final inlineId = input.dockInlinePageId;
  return TimetableHomeDockShell(
    homeStack: homeStack,
    useHomePreblur: useHomePreblur,
    settings: settings,
    homePreblurSigma: homePreblurSigma,
    courseCardPreblurSigma: courseCardPreblurSigma,
    isDayView: input.isDayView,
    weekPageController: weekPager.pageController,
    ensureDayViewPageController: dayViewTransition.ensurePageController,
    followsWeekPager: followsWeekPager,
    repaint: input.glassDockCardRepaint,
    glassDockForm: glassDockForm,
    inlinePageBuilder: inlineId == null ? null : inlineDockPageFor(inlineId),
    glassDockScrollInset: input.glassDockContentScrollInset(settings),
    dockLayer: glassDockForm
        ? TimetableGlassDockLayer(
            settings: settings,
            isInlinePage: inlineId != null,
            wallpaperBodyLuminance: luminance.body,
            selectedIndex: _dockSelectedIndex(
              inlineId,
              input.isDayView,
              resolveGlassDockActionIds(settings),
            ),
            roundButtonIcon: _roundButtonIcon(settings),
            onTabSelected: (id) => input.onDockTap(id, settings),
            onRoundButtonTap: () => homeMenu.handleRoundButtonTap(settings),
            pillKey: input.glassDockKey,
            roundKey: input.glassDockRoundKey,
          )
        : null,
    wrapHome: (content, {dockLayer}) => homeMenu.buildShell(
      content: content,
      settings: settings,
      chromeBalls: homeChromeBalls,
      chromeDotBorderColor: chromeDotBorderColor,
      dockLayer: dockLayer,
    ),
  );
}

/// One shared backdrop group for gaussian cards on this week page.
Widget _buildWeekPageBody(
  TimetableHomePageInput input, {
  required TimetableSettings settings,
  required int week,
  required Widget grid,
}) {
  final scrollKey = 'week-scroll-$week';
  return TimetableWeekPageBody(
    grid: grid,
    scrollRelief: input.glassDockContentScrollInset(settings),
    autoFit: settings.timetableAutoFitSectionHeight,
    scrollKey: scrollKey,
    controller: input.previewControllerFor(scrollKey),
    physics: input.homePullVerticalPhysics,
    expandAnimation: input.dayViewExpandAnimation,
    reportScroll: input.reportHomeScroll,
  );
}

/// 日视图锚点展开壳（面板本体由同库分片提供，经 [input] 回调传入）。
Widget _buildAnchoredDayViewOverlay(
  TimetableHomePageInput input, {
  required int week,
}) {
  return input.buildAnchoredDayViewOverlay(week);
}

Future<void> _showWeekSelector(TimetableHomePageInput input) async {
  final provider = input.provider;
  final availableWeeks = input.settings.availableWeeks;
  final currentSemesterWeek = _resolveCurrentSemesterWeek(input.settings);
  final selectedWeek = await showWeekSelectorPickerSheet(
    input.context,
    availableWeeks: availableWeeks,
    visibleWeek: input.weekPager.visibleWeek,
    currentSemesterWeek: currentSemesterWeek,
  );

  if (!input.isMounted() || selectedWeek == null) {
    return;
  }

  await input.weekPager.jumpToWeek(provider, selectedWeek);
}

/// Calendar week of today relative to [TimetableSettings.semesterStartDate].
///
/// 只认配置的 [TimetableSettings.semesterWeekCount] 范围，绝不为了「回到今天」
/// 自动扩学期（搬迁前 `_resolveCurrentSemesterWeek` 的原注释口径）。
int? _resolveCurrentSemesterWeek(TimetableSettings settings) {
  final semesterStart = settings.semesterStartDate;
  if (semesterStart == null) {
    return null;
  }

  final normalizedNow = DateTime.now();
  final normalizedToday = DateTime(
    normalizedNow.year,
    normalizedNow.month,
    normalizedNow.day,
  );
  final normalizedStart = DateTime(
    semesterStart.year,
    semesterStart.month,
    semesterStart.day,
  ).subtract(Duration(days: semesterStart.weekday - 1));
  final week =
      (WeekCalculator.daysBetween(normalizedStart, normalizedToday) ~/ 7) + 1;
  if (week < 1 || week > settings.semesterWeekCount) {
    return null;
  }
  return week;
}

/// 圆钮图标：用户自选的 Miuix 矢量图标优先；未选时 addCourse 显示
/// 加号、其余功能显示目录图标（与搬迁前 `_roundButtonIcon` 同口径）。
Widget _roundButtonIcon(TimetableSettings settings) {
  final customName = settings.glassDockButtonIconName;
  if (customName != null && customName.isNotEmpty) {
    final vector = MiuixIcons.extended.byName(customName);
    if (vector != null) {
      return MiuixIcon(vector: vector);
    }
  }
  final id = settings.glassDockButtonEntryId;
  if (id != 'addCourse' && id.isNotEmpty) {
    final entry = homeMenuEntryById(id);
    if (entry != null && entry.visible()) {
      return Icon(entry.icon);
    }
  }
  return const Icon(Icons.add_rounded);
}

/// 当前所在视图（日/周）在排列中的下标；排列未含该视图时高亮 0，
/// 避免库断言越界（此时底栏全是页面入口，无「当前页」语义）。
int _dockSelectedIndex(String? inlineId, bool isDayView, List<String> ids) {
  if (inlineId != null && ids.contains(inlineId)) {
    return ids.indexOf(inlineId);
  }
  final current = isDayView ? kGlassDockActionDay : kGlassDockActionWeek;
  final index = ids.indexOf(current);
  return index >= 0 ? index : 0;
}

DayCourseDisplayLabels _dayCourseDisplayLabels(AppLocalizations l10n) {
  return DayCourseDisplayLabels(
    nonCurrentWeek: l10n.nonCurrentWeekLabel,
    conflict: l10n.conflictLabel,
    coupleTogether: l10n.coupleTimetableLegendTogether,
    couplePartner: l10n.coupleTimetableLegendPartner,
    ongoingCourse: l10n.ongoingCourseBadge,
  );
}

/// 周网格课卡上那一行天气；不该显示时返回 null（[CourseCard] 据此不加这一行）。
///
/// 三道闸按「成本从低到高」排：先看开关与课程状态（纯内存判断），都过了才去
/// 查预报摘要。判据与日视图完全一致：**天气是「那一天」的属性**，只有这节课
/// 这一周真的要上才有意义；对方课程在别的城市，拿本地天气同样不对。
///
/// 摘要为空但「数据会自己来」时返回**预留的空位**
///（`CourseWeatherDisplay.reserved`）而不是 null：这一格确实该有天气，先按真行
/// 占好位置，预报到达时卡片不会长高一格把整屏内容顶一下。
CourseWeatherDisplay? _weekCardWeatherDisplay({
  required AppLocalizations? l10n,
  required WeatherProvider? weather,
  required TimetableSettings settings,
  required Course course,
  required DateTime? date,
  required int week,
  required bool isPartnerCourse,
}) {
  if (l10n == null ||
      weather == null ||
      date == null ||
      isPartnerCourse ||
      !settings.weatherShowOnWeekCard ||
      !course.isActiveInWeek(week)) {
    return null;
  }
  final display = courseWeatherDisplayFor(
    l10n: l10n,
    summary: weather.summaryForCourse(
      date: date,
      startTime: course.startTime,
      endTime: course.endTime,
    ),
    showPhenomenon: settings.weatherShowPhenomenon,
    showTemperature: settings.weatherShowTemperature,
    showProbability: settings.weatherShowProbability,
    // 周网格的天格太窄（7 天模式下扣掉图标只剩约 27 点，默认字号 8 时约合
    // 三个汉字），写全「现象 · 温度 · 概率」必然折行；折行又会把整张卡缩小。
    // 这里只写一项，详见 `WeatherTextDensity.compact`。
    textDensity: WeatherTextDensity.compact,
  );
  if (display != null) {
    return display;
  }
  return weather.isAwaitingData ? const CourseWeatherDisplay.reserved() : null;
}
