import 'dart:async' show unawaited;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:university_timetable/l10n/app_localizations.dart';

import '../models/course.dart';
import '../models/timetable_settings.dart';
import '../providers/timetable_provider.dart';
import '../ui/hyperos/hyperos.dart';
import '../ui/hyperos/liquid/hyperos_liquid_glass_surface.dart';
import 'home_page_region_blur.dart';
import '../utils/hex_color.dart';
import '../utils/course_color_palette.dart';
import '../utils/home_page_background.dart';
import 'course_card.dart';
import 'course_card_liquid_glass_host.dart';

/// Renders the home week timetable surface for settings previews.
class TimetableWeekPreview extends StatefulWidget {
  const TimetableWeekPreview({
    super.key,
    required this.provider,
    required this.settings,
    required this.week,
    this.maxVisibleSections,
    this.includeAppHeader = false,
    this.applyHomePageBackdrop = true,
    this.heightBudget,
  });

  final TimetableProvider provider;
  final TimetableSettings settings;
  final int week;
  final int? maxVisibleSections;
  final bool includeAppHeader;
  final bool applyHomePageBackdrop;
  final double? heightBudget;

  @override
  State<TimetableWeekPreview> createState() => _TimetableWeekPreviewState();
}

/// Samples the wallpaper band luminances once per path, shared by the glass
/// band's scrim polarity **and** the chrome ink auto-inversion — the same
/// pairs the home page derives from its own boot-time sample.
class _TimetableWeekPreviewState extends State<TimetableWeekPreview> {
  double? _topLuminance;
  double? _weekdayLuminance;
  double? _bodyLuminance;
  String? _sampledPath;

  @override
  void initState() {
    super.initState();
    _sampleLuminance();
  }

  @override
  void didUpdateWidget(covariant TimetableWeekPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sampleLuminance();
  }

  /// Home drives chrome ink and scrim polarity from wallpaper luminance
  /// samples; without them the preview falls back to theme brightness and can
  /// paint the opposite ink or wash — visibly unlike the home page.
  void _sampleLuminance() {
    final path = resolveHomePageBackdropImagePath(widget.settings);
    if (path == _sampledPath) {
      return;
    }
    _sampledPath = path;
    if (path == null || path.isEmpty) {
      _topLuminance = null;
      _weekdayLuminance = null;
      _bodyLuminance = null;
      return;
    }
    unawaited(
      sampleHomePageWallpaperLuminanceBands(path).then((value) {
        if (!mounted || _sampledPath != path) {
          return;
        }
        setState(() {
          _topLuminance = value?.top;
          _weekdayLuminance = value?.weekday;
          _bodyLuminance = value?.body;
        });
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _TimetableWeekPreviewBody(
      provider: widget.provider,
      settings: widget.settings,
      week: widget.week,
      maxVisibleSections: widget.maxVisibleSections,
      includeAppHeader: widget.includeAppHeader,
      applyHomePageBackdrop: widget.applyHomePageBackdrop,
      heightBudget: widget.heightBudget,
      wallpaperTopLuminance: _topLuminance,
      wallpaperWeekdayLuminance: _weekdayLuminance,
      wallpaperBodyLuminance: _bodyLuminance,
    );
  }
}

class _TimetableWeekPreviewBody extends StatelessWidget {
  const _TimetableWeekPreviewBody({
    required this.provider,
    required this.settings,
    required this.week,
    required this.maxVisibleSections,
    required this.includeAppHeader,
    required this.applyHomePageBackdrop,
    required this.heightBudget,
    required this.wallpaperTopLuminance,
    required this.wallpaperWeekdayLuminance,
    required this.wallpaperBodyLuminance,
  });

  final TimetableProvider provider;
  final TimetableSettings settings;
  final int week;
  final int? maxVisibleSections;
  final bool includeAppHeader;
  final bool applyHomePageBackdrop;
  final double? heightBudget;

  /// Top-band wallpaper luminance from [_TimetableWeekPreviewState]'s sample
  /// (null while sampling / no wallpaper).
  final double? wallpaperTopLuminance;

  /// Weekday-band luminance (the band behind the weekday/date chrome bar).
  final double? wallpaperWeekdayLuminance;

  /// Body-band luminance (the band behind the time column / course cards).
  final double? wallpaperBodyLuminance;

  /// Chrome glass band for the preview, mirroring the home page's continuous
  /// band but using the preview's own scaled-down header heights.
  ///
  /// [HomePageContinuousChromeFrostedOverlay] cannot be reused directly — it
  /// derives its geometry from the real status-bar inset and the home-page
  /// header constants, neither of which holds inside a preview box. So the band
  /// is positioned here and painted with the same material the home page uses
  /// ([HomePageChromeGlassFill]): a real liquid-glass surface that captures the
  /// wallpaper behind it and responds to every glass tuning knob (light
  /// intensity, thickness, visibility, …), with the specular fringe the old
  /// pre-blurred stand-in could not render.
  List<Widget>? _buildChromeGlassBand({required double appHeaderHeight}) {
    final hasHeaderBand =
        settings.homePageHeaderBlurEnabled && appHeaderHeight > 0;
    final hasWeekdayBand = settings.homePageWeekdayBarBlurEnabled;
    if (!hasHeaderBand && !hasWeekdayBand) {
      return null;
    }

    final double top;
    final double height;
    if (hasHeaderBand && hasWeekdayBand) {
      top = 0;
      height = appHeaderHeight + _headerHeight;
    } else if (hasHeaderBand) {
      top = 0;
      height = appHeaderHeight;
    } else {
      top = appHeaderHeight;
      height = _headerHeight;
    }
    if (height <= 0) {
      return null;
    }

    // Overdraw the glass above the band's top so the liquid-glass specular
    // fringe on that edge lands outside the ClipRect and is clipped — same
    // trick as HomePageContinuousChromeFrostedOverlay — otherwise the band's
    // interior top edge reads as a 1px hairline seam.
    return [
      Positioned(
        top: top,
        left: 0,
        right: 0,
        height: height,
        child: IgnorePointer(
          child: ClipRect(
            clipBehavior: Clip.hardEdge,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Positioned(
                  top: -homePageChromeGlassTopEdgeOverdraw,
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: HomePageChromeGlassFill(
                    wallpaperTopLuminance: wallpaperTopLuminance,
                    // The band is a small interior rectangle inside this
                    // preview, unlike the home page's screen-edge band: its
                    // own-bounds backdrop capture would clamp refraction
                    // displacement against the band edges and streak them
                    // into a "picture frame". Sample the grouped full-size
                    // wallpaper capture instead (see the BackdropGroup below).
                    useAncestorBackdropGroup: true,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ];
  }

  static const double _headerHeight = 40;
  static const double _appHeaderHeight = 44;
  static const double _homeHeaderHeightEstimate = 44;
  static const double _homeSurfaceBottomPadding = 8;
  static const int _previewMorningSectionCount = 4;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final darkFallback = colorScheme.surface;
    final hasBackdrop =
        applyHomePageBackdrop &&
        hasHomePageBackdropImage(settings, isDark: isDark);
    final backgroundColor = isDark
        ? colorScheme.surface
        : parseHexColorOrFallback(
            settings.timetablePageBackgroundColor,
            fallback: colorScheme.surface,
          );
    final showsFloatingButton =
        settings.timetableBackToCurrentWeekButtonStyle ==
        BackToCurrentWeekButtonStyle.floating;
    final visibleSectionCount = _resolveVisibleSectionCount();
    final appHeaderHeight = includeAppHeader ? _appHeaderHeight : 0.0;
    final weekdayChromeBlurEnabled =
        hasBackdrop && settings.homePageWeekdayBarBlurEnabled;
    // Same clearance the home page reserves, so the first course row never sits
    // flush against the weekday glass band.
    final chromeGridClearance = weekdayChromeBlurEnabled
        ? homePageFrostedRegionSeamOverlap
        : 0.0;

    late final double sectionHeight;
    late final double bodyHeight;
    if (heightBudget != null) {
      bodyHeight =
          (heightBudget! -
                  appHeaderHeight -
                  _headerHeight -
                  chromeGridClearance)
              .clamp(0.0, double.infinity);
      sectionHeight = visibleSectionCount > 0
          ? bodyHeight / visibleSectionCount
          : settings.sectionHeight;
    } else {
      sectionHeight = _resolveHomeSectionHeight(context);
      bodyHeight = sectionHeight * visibleSectionCount;
    }

    final totalHeight =
        heightBudget ??
        (appHeaderHeight + _headerHeight + chromeGridClearance + bodyHeight);

    return ColoredBox(
      color: hasBackdrop ? Colors.transparent : backgroundColor,
      child: Padding(
        padding: EdgeInsets.only(bottom: heightBudget == null ? 8 : 0),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final grid = _buildTimetableGrid(
              context: context,
              availableWidth: constraints.maxWidth,
              week: week,
              sectionHeight: sectionHeight,
              visibleSectionCount: visibleSectionCount,
              isDark: isDark,
              darkFallback: darkFallback,
              hasBackdrop: hasBackdrop,
            );

            final weekdayHeader = homePageBackgroundLayer(
              // Must match the home page: when the weekday glass band is on,
              // this has to resolve to transparent or the bar paints an opaque
              // fill straight over the band. `resolveHomePageRegionBackground`
              // alone only goes transparent when the weekday region is inside
              // the wallpaper scope, so blur-on + scope-off used to hide it.
              visual: homePageRegionChromeVisual(
                settings: settings,
                isDark: isDark,
                darkFallback: darkFallback,
                region: HomePageBackgroundScope.weekdayBar,
                chromeBlurEnabled: weekdayChromeBlurEnabled,
              ),
              child: _buildWeekDayHeader(
                context: context,
                week: week,
                timeColumnWidth: _resolveTimeColumnWidth(settings),
                hasBackdrop: hasBackdrop,
                hideBottomBorder:
                    hasBackdrop &&
                    (homePageRegionShowsBackdrop(
                          settings,
                          HomePageBackgroundScope.weekdayBar,
                          isDark: isDark,
                        ) ||
                        settings.homePageWeekdayBarBlurEnabled),
              ),
            );

            final surface = SizedBox(
              height: totalHeight,
              child: BackdropGroup(
                child: Stack(
                  clipBehavior: Clip.hardEdge,
                  children: [
                    if (hasBackdrop)
                      homePageBackdropLayer(settings: settings, isDark: isDark),
                    // First filter inside the group: caches the full-size
                    // wallpaper backdrop so the chrome band's glass below can
                    // sample beyond its own narrow bounds without clamping
                    // against the band edges into "picture frame" streaks.
                    if (hasBackdrop)
                      const Positioned.fill(child: UndimmedBackdropCapture()),
                    if (hasBackdrop)
                      ...?_buildChromeGlassBand(
                        appHeaderHeight: appHeaderHeight,
                      ),
                    Column(
                      children: [
                        if (includeAppHeader)
                          _buildAppHeader(
                            context: context,
                            isDark: isDark,
                            darkFallback: darkFallback,
                            hasBackdrop: hasBackdrop,
                          ),
                        weekdayHeader,
                        // Home reserves the same gap under the weekday glass.
                        if (chromeGridClearance > 0)
                          SizedBox(height: chromeGridClearance),
                        SizedBox(
                          height: bodyHeight,
                          // Same glass hosting as the home grid: one shared
                          // backdrop capture for the whole preview instead of one
                          // per card. Matters doubly here because the settings
                          // header's CFH pass rasterises this subtree offscreen.
                          child: CourseGridGlassHost(
                            settings: settings,
                            child: IgnorePointer(child: grid),
                          ),
                        ),
                      ],
                    ),
                    if (showsFloatingButton &&
                        _canReturnToCurrentWeek(settings, week))
                      Positioned(
                        right: 20,
                        bottom: 12,
                        child: IgnorePointer(
                          child: Material(
                            color: colorScheme.surfaceContainerHigh.withValues(
                              alpha: settings
                                  .timetableFloatingBackToCurrentWeekButtonOpacity,
                            ),
                            elevation: 2,
                            shadowColor: Colors.black.withValues(
                              alpha: isDark ? 0.12 : 0.06,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                              side: BorderSide(
                                color: context.theme.colors.border,
                                width: 1,
                              ),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.my_location_rounded,
                                    size: 15,
                                    color: colorScheme.primary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    l10n.backToCurrentWeekAction,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: colorScheme.onSurface,
                                      height: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );

            return surface;
          },
        ),
      ),
    );
  }

  Widget _buildAppHeader({
    required BuildContext context,
    required bool isDark,
    required Color darkFallback,
    required bool hasBackdrop,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final foruiTheme = context.theme;
    final colorScheme = Theme.of(context).colorScheme;
    final headerShowsBackdrop = homePageRegionShowsBackdrop(
      settings,
      HomePageBackgroundScope.header,
      isDark: isDark,
    );
    final headerUsesFrostedChrome =
        hasBackdrop &&
        (headerShowsBackdrop || settings.homePageHeaderBlurEnabled);
    final headerBackground = resolveHomePageRegionBackground(
      settings: settings,
      isDark: isDark,
      darkFallback: darkFallback,
      region: HomePageBackgroundScope.header,
    );
    final headerBarColor = headerUsesFrostedChrome
        ? Colors.transparent
        : headerBackground.color;
    // Same auto-contrast as the home title: only invert the default ink when
    // the header band actually shows wallpaper / frosted glass under it.
    final chromeForeground = headerUsesFrostedChrome
        ? homePageChromeForegroundForLuminance(
            wallpaperTopLuminance,
            fallback: foruiTheme.colors.foreground,
          )
        : foruiTheme.colors.foreground;
    final chromeMutedForeground = headerUsesFrostedChrome
        ? homePageChromeMutedForeground(chromeForeground)
        : colorScheme.onSurfaceVariant;

    Widget title;
    switch (settings.homeTitleStyle) {
      case HomeTitleStyle.classic:
        title = Text(
          l10n.appTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: foruiTheme.typography.display.xl.copyWith(
            fontWeight: FontWeight.w400,
            height: 1.1,
            color: chromeForeground,
          ),
        );
      case HomeTitleStyle.brand:
        title = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.appTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: foruiTheme.typography.display.xl.copyWith(
                fontWeight: FontWeight.w900,
                height: 1.0,
                color: chromeForeground,
              ),
            ),
            Text(
              l10n.defaultTimetablePreviewName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: foruiTheme.typography.body.xs.copyWith(
                color: chromeMutedForeground,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        );
    }

    final headerChild = Container(
      height: _appHeaderHeight,
      color: headerBarColor,
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 2),
      child: Row(
        children: [
          Expanded(child: title),
          Icon(Icons.more_vert_rounded, color: chromeForeground),
        ],
      ),
    );

    if (headerUsesFrostedChrome && settings.homePageHeaderBlurEnabled) {
      // The frost itself is painted by the chrome glass band stacked above the
      // wallpaper (_buildChromeGlassBand); the header row only supplies content.
      return headerChild;
    }

    return homePageBackgroundLayer(
      visual: headerBackground,
      child: headerChild,
    );
  }

  double _resolveHomeTimetableSurfaceHeight(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return mediaQuery.size.height -
        mediaQuery.padding.top -
        _homeHeaderHeightEstimate -
        mediaQuery.padding.bottom -
        _homeSurfaceBottomPadding;
  }

  double _resolveHomeSectionHeight(BuildContext context) {
    final bodyAvailableHeight =
        (_resolveHomeTimetableSurfaceHeight(context) - _headerHeight).clamp(
          0.0,
          double.infinity,
        );
    if (settings.timetableAutoFitSectionHeight && settings.sectionCount > 0) {
      return bodyAvailableHeight / settings.sectionCount;
    }
    return settings.sectionHeight;
  }

  int _resolveVisibleSectionCount() {
    if (settings.sectionCount <= 0) {
      return 0;
    }
    final cap = maxVisibleSections ?? _previewMorningSectionCount;
    return math.min(cap, settings.sectionCount);
  }

  Widget _buildWeekDayHeader({
    required BuildContext context,
    required int week,
    required double timeColumnWidth,
    required bool hasBackdrop,
    bool hideBottomBorder = false,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subtleBorder = context.theme.colors.border;
    final visibleDays = _visibleDayNumbers(settings);
    final canReturnToCurrentWeek = _canReturnToCurrentWeek(settings, week);
    final showsInlineBackToCurrentWeek =
        canReturnToCurrentWeek &&
        settings.timetableBackToCurrentWeekButtonStyle ==
            BackToCurrentWeekButtonStyle.inline;
    final weekdayChromeOverWallpaper =
        hasBackdrop &&
        (homePageRegionShowsBackdrop(
              settings,
              HomePageBackgroundScope.weekdayBar,
              isDark: isDark,
            ) ||
            settings.homePageWeekdayBarBlurEnabled);
    // Judge ink from the band actually behind the weekday bar, not the
    // status/title strip above it. With the weekday glass band on, follow the
    // band's scrim polarity (derived from the top sample) so ink and wash
    // never fight.
    final weekdayLuminance = settings.homePageWeekdayBarBlurEnabled
        ? wallpaperTopLuminance
        : wallpaperWeekdayLuminance ?? wallpaperTopLuminance;
    // Same rules as the home weekday chrome: default black/white ink flips
    // with the wallpaper luminance, user-custom hex is kept, accent is never
    // auto-inverted.
    final weekLabelColor = homePageOverWallpaperInk(
      configuredHex: isDark
          ? settings.weekdayBarFontColorDark
          : settings.weekdayBarFontColorLight,
      defaultHex: isDark
          ? TimetableSettings.defaultWeekdayBarFontColorDark
          : TimetableSettings.defaultWeekdayBarFontColorLight,
      themeFallback: colorScheme.onSurface,
      hasBackdrop: weekdayChromeOverWallpaper,
      wallpaperLuminance: weekdayLuminance,
    );
    final weekLabelMutedColor = homePageOverWallpaperMutedInk(weekLabelColor);

    return Container(
      height: _headerHeight,
      padding: EdgeInsets.zero,
      decoration: BoxDecoration(
        border: hideBottomBorder
            ? null
            : Border(bottom: BorderSide(color: subtleBorder, width: 1)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: timeColumnWidth,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  l10n.currentWeekCompact(week),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: weekLabelColor,
                  ),
                ),
                if (showsInlineBackToCurrentWeek)
                  Text(
                    l10n.backToCurrentWeekAction,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 8, color: weekLabelMutedColor),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Row(
              children: visibleDays.map((dayOfWeek) {
                final date = _dateForWeekDay(settings, week, dayOfWeek);
                final isToday =
                    date != null && _isSameDate(date, DateTime.now());
                final weekdayColor = homePageOverWallpaperInk(
                  configuredHex: isDark
                      ? settings.weekdayBarFontColorDark
                      : settings.weekdayBarFontColorLight,
                  defaultHex: isDark
                      ? TimetableSettings.defaultWeekdayBarFontColorDark
                      : TimetableSettings.defaultWeekdayBarFontColorLight,
                  themeFallback: colorScheme.onSurface,
                  hasBackdrop: weekdayChromeOverWallpaper,
                  wallpaperLuminance: weekdayLuminance,
                );
                final accentColor = homePageOverWallpaperAccent(
                  configuredHex: isDark
                      ? settings.weekdayBarAccentColorDark
                      : settings.weekdayBarAccentColorLight,
                  themeFallback: colorScheme.primary,
                );
                final labelColor = isToday ? accentColor : weekdayColor;
                final subLabelColor = isToday
                    ? accentColor.withValues(alpha: 0.78)
                    : homePageOverWallpaperMutedInk(weekdayColor);

                return Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _weekdayLabel(context, dayOfWeek),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: isToday
                              ? FontWeight.w800
                              : FontWeight.w600,
                          color: labelColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        date == null
                            ? ''
                            : '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}',
                        style: TextStyle(fontSize: 8.5, color: subLabelColor),
                      ),
                      if (date != null && provider.hasExamOnDate(date))
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Container(
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(
                              color: colorScheme.error,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimetableGrid({
    required BuildContext context,
    required double availableWidth,
    required int week,
    required double sectionHeight,
    required int visibleSectionCount,
    required bool isDark,
    required Color darkFallback,
    required bool hasBackdrop,
  }) {
    final visibleDays = _visibleDayNumbers(settings);
    final timeColumnWidth = _resolveTimeColumnWidth(settings);
    final cardInset = _resolveCourseCardInset(settings);
    final dayWidth = (availableWidth - timeColumnWidth) / visibleDays.length;
    final conflictMap = provider.courseConflictMapForWeek(week);
    final courses = _effectiveCourses(context);
    final sectionRows = math.min(visibleSectionCount, settings.sectionCount);

    Widget timeColumn = SizedBox(
      width: timeColumnWidth,
      child: Column(
        children: List.generate(sectionRows, (index) {
          final section = settings.sections[index];
          return SizedBox(
            height: sectionHeight,
            child: Center(
              child: _buildSectionTimeCell(
                context,
                index + 1,
                section,
                sectionHeight,
                hasBackdrop: hasBackdrop,
              ),
            ),
          );
        }),
      ),
    );

    // The time column never uses blur / liquid glass on the real home page, so
    // the preview must not either — it only carries the region background.
    if (hasBackdrop) {
      timeColumn = homePageBackgroundLayer(
        visual: resolveHomePageRegionBackground(
          settings: settings,
          isDark: isDark,
          darkFallback: darkFallback,
          region: HomePageBackgroundScope.timetable,
        ),
        child: timeColumn,
      );
    }

    Widget dayColumns = Row(
      children: visibleDays.map((dayOfWeek) {
        final dayCourses = _getCoursesForDay(courses, week, dayOfWeek);
        final displayItems = _buildDayCourseDisplayItems(
          context: context,
          courses: dayCourses,
          week: week,
          conflictMap: conflictMap,
        );
        return SizedBox(
          width: dayWidth,
          child: _buildDayColumn(
            context: context,
            week: week,
            dayOfWeek: dayOfWeek,
            displayItems: displayItems,
            sectionHeight: sectionHeight,
            cardInset: cardInset,
            visibleSectionCount: sectionRows,
          ),
        );
      }).toList(),
    );

    if (hasBackdrop) {
      dayColumns = homePageBackgroundLayer(
        visual: resolveHomePageRegionBackground(
          settings: settings,
          isDark: isDark,
          darkFallback: darkFallback,
          region: HomePageBackgroundScope.timetable,
        ),
        child: dayColumns,
      );
    }

    return SizedBox(
      width: availableWidth,
      height: sectionHeight * sectionRows,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          timeColumn,
          Expanded(child: dayColumns),
        ],
      ),
    );
  }

  Widget _buildDayColumn({
    required BuildContext context,
    required int week,
    required int dayOfWeek,
    required List<_DayCourseDisplayItem> displayItems,
    required double sectionHeight,
    required double cardInset,
    required int visibleSectionCount,
  }) {
    final courseCards = <Widget>[];
    final date = _dateForWeekDay(settings, week, dayOfWeek);
    final isDayHoliday = date != null && provider.isHoliday(date);

    for (
      var sectionIndex = 0;
      sectionIndex < visibleSectionCount;
      sectionIndex++
    ) {
      final section = sectionIndex + 1;
      final startingCourses = displayItems
          .where((item) => item.course.startSection == section)
          .toList();

      for (final item in startingCourses) {
        courseCards.add(
          Positioned(
            top: sectionIndex * sectionHeight,
            left: 0,
            right: 0,
            height: item.course.sectionCount * sectionHeight,
            // Same as home grid: never wrap frosted cards in Opacity.
            child: CourseCard(
              course: item.course,
              overrideColorHex: _resolveDisplayCourseColor(item),
              compactOverlineText: _resolveCompactOverlineText(context, item),
              topRightBadgeText: _resolveCompactBadgeText(context, item),
              isHoliday: isDayHoliday,
              isSuspended: item.course.isSuspendedInWeek(week),
              isCompact: true,
              showName: settings.courseCardShowName,
              showTeacher: settings.courseCardShowTeacher,
              showLocation: settings.courseCardShowLocation,
              showTime: settings.courseCardShowTime,
              showTimeLabels: settings.courseCardShowTimeLabels,
              showWeeks: settings.courseCardShowWeeks,
              showDescription: settings.courseCardShowDescription,
              verticalAlign: settings.courseCardVerticalAlign,
              horizontalAlign: settings.courseCardHorizontalAlign,
              compactTitleFontSize: settings.courseCardFontSize,
              compactSubtitleFontSize: (settings.courseCardFontSize - 1).clamp(
                7.0,
                14.0,
              ),
              compactVerticalPadding: sectionHeight < 64 ? 4 : 6,
              compactOuterInset: cardInset,
              surfaceStyle: settings.courseCardSurfaceStyle,
              surfaceOpacity: item.opacity,
              titleColorHex: resolveCourseCardTitleColorHex(
                courseTextColorHex: item.course.textColor,
                settingsTitleColorLight: settings.courseCardTitleColorLight,
                settingsTitleColorDark: settings.courseCardTitleColorDark,
                isDark: Theme.of(context).brightness == Brightness.dark,
              ),
              detailColorHex: resolveCourseCardDetailColorHex(
                courseTextColorHex: item.course.textColor,
                settingsDetailColorLight: settings.courseCardDetailColorLight,
                settingsDetailColorDark: settings.courseCardDetailColorDark,
                settingsTitleColorLight: settings.courseCardTitleColorLight,
                settingsTitleColorDark: settings.courseCardTitleColorDark,
                isDark: Theme.of(context).brightness == Brightness.dark,
              ),
            ),
          ),
        );
      }
    }

    // No per-column glass host here: this method builds one weekday column, so
    // hosting at this level meant seven separate layers — and therefore seven
    // backdrop captures — for one preview. The whole grid is hosted once by
    // CourseGridGlassHost instead, matching the home page.
    return Container(
      height: visibleSectionCount * sectionHeight,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
      child: Stack(clipBehavior: Clip.hardEdge, children: courseCards),
    );
  }

  Widget _buildSectionTimeCell(
    BuildContext context,
    int sectionNumber,
    SectionTime section,
    double sectionHeight, {
    required bool hasBackdrop,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Same auto-contrast as the home time axis: judged from whether the
    // timetable region actually shows the wallpaper, never replacing a
    // user-custom hex. The time column spans the body band, not the
    // status/title strip, so judge from the card-region sample.
    final timeAxisOverWallpaper =
        hasBackdrop &&
        homePageRegionShowsBackdrop(
          settings,
          HomePageBackgroundScope.timetable,
          isDark: isDark,
        );
    final timeAxisColor = homePageOverWallpaperInk(
      configuredHex: isDark
          ? settings.timeAxisFontColorDark
          : settings.timeAxisFontColorLight,
      defaultHex: isDark
          ? TimetableSettings.defaultTimeAxisFontColorDark
          : TimetableSettings.defaultTimeAxisFontColorLight,
      themeFallback: isDark ? Colors.white : Colors.grey.shade800,
      hasBackdrop: timeAxisOverWallpaper,
      wallpaperLuminance: wallpaperBodyLuminance ?? wallpaperTopLuminance,
    );
    final timeAxisMutedColor = homePageOverWallpaperMutedInk(timeAxisColor);
    final compactTextStyle = TextStyle(
      fontSize: (settings.compactFontSize - 2).clamp(6.0, 10.0),
      color: timeAxisMutedColor,
      height: 1.0,
    );

    return SizedBox(
      height: sectionHeight,
      width: double.infinity,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$sectionNumber',
              style: TextStyle(
                fontSize: settings.compactFontSize.clamp(8.0, 11.0),
                fontWeight: FontWeight.bold,
                height: 1.0,
                color: timeAxisColor,
              ),
            ),
            if (settings.timetableSectionTimeDisplayMode !=
                SectionTimeDisplayMode.hidden)
              Text(section.startTime, style: compactTextStyle),
            if (settings.timetableSectionTimeDisplayMode ==
                SectionTimeDisplayMode.startAndEnd)
              Text(section.endTime, style: compactTextStyle),
          ],
        ),
      ),
    );
  }

  List<Course> _effectiveCourses(BuildContext context) {
    if (provider.courses.isNotEmpty) {
      return provider.courses;
    }
    return _fallbackCourses(context);
  }

  List<Course> _fallbackCourses(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return [
      Course(
        id: 'layout-preview-1',
        name: l10n.sampleCourseAdvancedMath,
        shortName: l10n.sampleCourseAdvancedMath,
        teacher: l10n.sampleTeacherZhang,
        location: 'A101',
        dayOfWeek: 1,
        startSection: 1,
        endSection: 2,
        startTime: '08:00',
        endTime: '09:40',
        color: '#2563EB',
      ),
      Course(
        id: 'layout-preview-2',
        name: l10n.sampleCourseEnglish,
        shortName: l10n.sampleCourseEnglish,
        teacher: l10n.sampleTeacherLi,
        location: 'B203',
        dayOfWeek: 2,
        startSection: 2,
        endSection: 3,
        startTime: '08:55',
        endTime: '10:45',
        color: '#10B981',
      ),
    ];
  }

  List<_DayCourseDisplayItem> _buildDayCourseDisplayItems({
    required BuildContext context,
    required List<Course> courses,
    required int week,
    required Map<String, List<Course>> conflictMap,
  }) {
    return courses
        .where((course) {
          final isCurrentWeekCourse = course.isInWeek(week);
          if (isCurrentWeekCourse) {
            return true;
          }
          if (_hasCurrentWeekOverlap(courses, course, week)) {
            return false;
          }
          return _isPreferredNonCurrentCourse(courses, course, week);
        })
        .map((course) {
          final isCurrentWeekCourse = course.isInWeek(week);
          final isConflicting = conflictMap.containsKey(course.id);
          return _DayCourseDisplayItem(
            course: course,
            isCurrentWeekCourse: isCurrentWeekCourse,
            isConflicting: isConflicting,
            opacity: !isCurrentWeekCourse
                ? 0.62
                : (isConflicting ? settings.timetableConflictCourseOpacity : 1),
          );
        })
        .toList()
      ..sort((left, right) {
        final startCompare = left.course.startSection.compareTo(
          right.course.startSection,
        );
        if (startCompare != 0) {
          return startCompare;
        }
        final leftCurrent = left.isCurrentWeekCourse;
        final rightCurrent = right.isCurrentWeekCourse;
        if (leftCurrent != rightCurrent) {
          return leftCurrent ? 1 : -1;
        }
        final endCompare = left.course.endSection.compareTo(
          right.course.endSection,
        );
        if (endCompare != 0) {
          return endCompare;
        }
        return left.course.id.compareTo(right.course.id);
      });
  }

  String? _resolveDisplayCourseColor(_DayCourseDisplayItem item) {
    if (!item.isCurrentWeekCourse) {
      return '#94A3B8';
    }
    return settings.timetableUseUnifiedCardColor
        ? settings.timetableUnifiedCardColor
        : null;
  }

  String? _resolveCompactOverlineText(
    BuildContext context,
    _DayCourseDisplayItem item,
  ) {
    final l10n = AppLocalizations.of(context)!;
    if (!item.isCurrentWeekCourse) {
      return l10n.nonCurrentWeekLabel;
    }
    if (item.isConflicting && settings.showConflictBadgeOnTimetable) {
      return l10n.conflictLabel;
    }
    return null;
  }

  String? _resolveCompactBadgeText(
    BuildContext context,
    _DayCourseDisplayItem item,
  ) {
    final l10n = AppLocalizations.of(context)!;
    if (item.isConflicting && settings.showConflictBadgeOnTimetable) {
      return l10n.conflictLabel;
    }
    return null;
  }

  List<Course> _getCoursesForDay(
    List<Course> allCourses,
    int week,
    int dayOfWeek,
  ) {
    return allCourses.where((course) {
      if (course.dayOfWeek != dayOfWeek) {
        return false;
      }
      final isCurrentWeek = course.isInWeek(week);
      if (isCurrentWeek) {
        return true;
      }
      return settings.timetableShowNonCurrentWeekCourses;
    }).toList()..sort((a, b) {
      final startCompare = a.startSection.compareTo(b.startSection);
      if (startCompare != 0) return startCompare;
      final aCurrent = a.isInWeek(week);
      final bCurrent = b.isInWeek(week);
      if (aCurrent != bCurrent) {
        return aCurrent ? 1 : -1;
      }
      final endCompare = a.endSection.compareTo(b.endSection);
      if (endCompare != 0) return endCompare;
      return a.id.compareTo(b.id);
    });
  }

  bool _hasCurrentWeekOverlap(List<Course> courses, Course target, int week) {
    return courses.any(
      (course) =>
          course.id != target.id &&
          course.isInWeek(week) &&
          !(course.endSection < target.startSection ||
              target.endSection < course.startSection),
    );
  }

  bool _isPreferredNonCurrentCourse(
    List<Course> courses,
    Course target,
    int week,
  ) {
    final overlappingNonCurrentCourses =
        courses
            .where(
              (course) =>
                  !course.isInWeek(week) &&
                  !(course.endSection < target.startSection ||
                      target.endSection < course.startSection),
            )
            .toList()
          ..sort((left, right) {
            final leftDistance = _distanceToNearestActiveWeek(left, week);
            final rightDistance = _distanceToNearestActiveWeek(right, week);
            if (leftDistance != rightDistance) {
              return leftDistance.compareTo(rightDistance);
            }
            final startCompare = left.startWeek.compareTo(right.startWeek);
            if (startCompare != 0) {
              return startCompare;
            }
            final endCompare = left.endWeek.compareTo(right.endWeek);
            if (endCompare != 0) {
              return endCompare;
            }
            return left.id.compareTo(right.id);
          });

    return overlappingNonCurrentCourses.isNotEmpty &&
        overlappingNonCurrentCourses.first.id == target.id;
  }

  int _distanceToNearestActiveWeek(Course course, int week) {
    for (var offset = 0; offset <= 60; offset++) {
      final previousWeek = week - offset;
      if (previousWeek >= 1 && course.isInWeek(previousWeek)) {
        return offset;
      }
      final nextWeek = week + offset;
      if (offset > 0 && course.isInWeek(nextWeek)) {
        return offset;
      }
    }
    return 999;
  }

  List<int> _visibleDayNumbers(TimetableSettings settings) {
    return settings.timetableHideWeekends
        ? const [1, 2, 3, 4, 5]
        : const [1, 2, 3, 4, 5, 6, 7];
  }

  double _resolveTimeColumnWidth(TimetableSettings settings) {
    return switch (settings.timetableTimeColumnWidthMode) {
      TimetableTimeColumnWidthMode.narrow => 34,
      TimetableTimeColumnWidthMode.wide => 40,
    };
  }

  double _resolveCourseCardInset(TimetableSettings settings) {
    return settings.timetableCourseCardGap.clamp(0.0, 3.0);
  }

  DateTime? _dateForWeekDay(
    TimetableSettings settings,
    int week,
    int dayOfWeek,
  ) {
    final semesterStart = settings.semesterStartDate;
    if (semesterStart == null) {
      return null;
    }

    final normalizedStart = DateTime(
      semesterStart.year,
      semesterStart.month,
      semesterStart.day,
    ).subtract(Duration(days: semesterStart.weekday - 1));

    return normalizedStart.add(Duration(days: (week - 1) * 7 + dayOfWeek - 1));
  }

  /// Calendar week of today within the configured semester, or null if unset /
  /// before week 1 / after [semesterWeekCount] (vacation / after term).
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
    final resolvedWeek =
        (normalizedToday.difference(normalizedStart).inDays ~/ 7) + 1;
    if (resolvedWeek < 1 || resolvedWeek > settings.semesterWeekCount) {
      return null;
    }
    return resolvedWeek;
  }

  bool _canReturnToCurrentWeek(TimetableSettings settings, int week) {
    final currentSemesterWeek = _resolveCurrentSemesterWeek(settings);
    return currentSemesterWeek != null && currentSemesterWeek != week;
  }

  String _weekdayLabel(BuildContext context, int dayOfWeek) {
    final l10n = AppLocalizations.of(context)!;
    final labels = [
      l10n.weekdayMon,
      l10n.weekdayTue,
      l10n.weekdayWed,
      l10n.weekdayThu,
      l10n.weekdayFri,
      l10n.weekdaySat,
      l10n.weekdaySun,
    ];
    if (dayOfWeek < 1 || dayOfWeek > labels.length) {
      return dayOfWeek.toString();
    }
    return labels[dayOfWeek - 1];
  }

  bool _isSameDate(DateTime left, DateTime right) {
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
  }
}

class _DayCourseDisplayItem {
  const _DayCourseDisplayItem({
    required this.course,
    required this.isCurrentWeekCourse,
    required this.isConflicting,
    required this.opacity,
  });

  final Course course;
  final bool isCurrentWeekCourse;
  final bool isConflicting;
  final double opacity;
}
