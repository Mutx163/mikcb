part of 'timetable_screen.dart';

/// 日视图议程族（2026-10-10 自 `timetable_screen.dart` 原样搬入）。
///
/// `_TimetableScreenState` 的成员扩展：相关字段与 `_DayAgendaItem` 等数据类
/// 仍在主文件。搬移是**原样移动**——除本头注释与 extension 包裹外，方法体
/// 一个字符都没有改。
///
/// 留在主类的同族成员：`_buildSharedFreeTimeChip`（体内 setState 会触发
/// extension 的 protected lint）、`_groupedDayColumnBorderRadius` 与
/// `_weekCardWeatherDisplay`（周视图网格共用）。
extension _TimetableScreenDayView on _TimetableScreenState {
  Widget _buildDayViewPanel({
    required TimetableProvider provider,
    required TimetableSettings settings,
    required int week,
    required int dayOfWeek,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final darkFallback = colorScheme.surface;
    // Not forced opaque: the panel shows the wallpaper exactly like a week page
    // does, so glass / frosted agenda cards have real content to sample. The
    // week grid underneath is faded to 0 while the day view is up
    // (see _buildWeekPageBody), so nothing shows through but the wallpaper.
    // With no wallpaper this resolver already returns an opaque colour.
    final backgroundVisual = resolveHomePageRegionBackground(
      settings: settings,
      isDark: isDark,
      darkFallback: darkFallback,
      region: HomePageBackgroundScope.timetable,
    );
    final controller = _ensureDayViewPageController(settings);
    _syncDayViewPageWithSelection(settings);
    final pageCount = _dayViewPageCount(settings);

    return homePageBackgroundLayer(
      visual: backgroundVisual,
      child: Container(
        key: const ValueKey('timetable-day-view-panel'),
        child: Column(
          children: [
            const SizedBox(height: 14),
            SizedBox(key: ValueKey('timetable-day-view-$week-$dayOfWeek')),
            Expanded(
              child: IgnorePointer(
                ignoring: _isDaySwipeAnimating,
                // Same as week grid: default PageView.builder keeps per-page
                // RepaintBoundary so horizontal swipes composite cheaply.
                // Pre-blur fills still repaint via pager markNeedsPaint.
                child: Listener(
                  // Raw-pointer fling meter + rescue arming. Touch batching
                  // under jank starves the framework's VelocityTracker (2–5
                  // samples per 50–100ms flick → zero velocity → snap-back);
                  // the probes keep the true displacement/duration so
                  // _dayPagerPhysics can redo the snap with it.
                  behavior: HitTestBehavior.translucent,
                  onPointerDown: (event) {
                    // A new touch invalidates any leftover rescue velocity.
                    _dayPagerRescueVelocityX = 0;
                    _dayPagerRescueArmedAt = null;
                    // 新手势重新允许一次日切换点击震感。
                    _daySwipeHapticFired = false;
                    _dayPagerFlickProbes[event.pointer] = _DayPagerFlickProbe(
                      VelocityTracker.withKind(event.kind)
                        ..addPosition(event.timeStamp, event.position),
                      event.timeStamp,
                      event.position,
                    );
                    if (kDebugMode && _dayPagerFlickProbes.length > 1) {
                      debugPrint(
                        '[DayPager] multi-touch: '
                        'pointers=${_dayPagerFlickProbes.keys.toList()}',
                      );
                    }
                  },
                  onPointerMove: (event) {
                    final probe = _dayPagerFlickProbes[event.pointer];
                    if (probe != null) {
                      probe.tracker.addPosition(
                        event.timeStamp,
                        event.position,
                      );
                      probe.samples++;
                      probe.lastTime = event.timeStamp;
                    }
                  },
                  onPointerUp: (event) {
                    final probe = _dayPagerFlickProbes.remove(event.pointer);
                    if (probe == null) {
                      return;
                    }
                    final path = event.position - probe.downPosition;
                    final pressDuration = event.timeStamp - probe.downTime;
                    final durationMs = pressDuration.inMilliseconds;
                    if (kDebugMode) {
                      final velocity = probe.tracker.getVelocity();
                      final gapMs =
                          (event.timeStamp - probe.lastTime).inMilliseconds;
                      debugPrint(
                        '[DayPager] lift(p${event.pointer}): '
                        'vx=${velocity.pixelsPerSecond.dx.toStringAsFixed(1)} '
                        'dx=${path.dx.toStringAsFixed(1)} '
                        'dur=${durationMs}ms '
                        'samples=${probe.samples} '
                        'gapBeforeUp=${gapMs}ms '
                        'concurrent=${_dayPagerFlickProbes.length} '
                        'minFling=${kMinFlingVelocity.toStringAsFixed(1)}',
                      );
                    }
                    // Arm the rescue: single remaining finger, short and
                    // horizontal-dominant swipes only. The drag recognizer
                    // runs right after this handler and consumes it.
                    if (_dayPagerFlickProbes.isEmpty &&
                        durationMs >= 16 &&
                        durationMs <= 300 &&
                        path.dx.abs() >= 24 &&
                        path.dx.abs() > path.dy.abs()) {
                      final pointerVx =
                          path.dx / (pressDuration.inMicroseconds / 1e6);
                      if (pointerVx.abs() >= kMinFlingVelocity) {
                        // Pointer moving right drags the pager toward the
                        // previous page: scroll velocity is the negation.
                        _dayPagerRescueVelocityX = -pointerVx;
                        _dayPagerRescueArmedAt = DateTime.now();
                      }
                    }
                  },
                  onPointerCancel: (event) {
                    _dayPagerRescueVelocityX = 0;
                    _dayPagerRescueArmedAt = null;
                    final probe = _dayPagerFlickProbes.remove(event.pointer);
                    if (probe != null && kDebugMode) {
                      final durationMs =
                          (event.timeStamp - probe.downTime).inMilliseconds;
                      debugPrint(
                        '[DayPager] CANCEL(p${event.pointer}) after '
                        '${durationMs}ms — gesture stolen '
                        '(system nav / palm rejection?)',
                      );
                    }
                  },
                  child: NotificationListener<ScrollNotification>(
                    // Week-pager settle model: nothing commits until the swipe
                    // has fully stopped (see _settleDayViewPage).
                    onNotification: (notification) {
                      if (notification.metrics.axis != Axis.horizontal) {
                        return false;
                      }
                      if (notification is ScrollUpdateNotification) {
                        // 拦截 update 继续冒泡：HyperosRootPage 的触边震动
                        // 监听会在学期首/末日到达页边界时再计一次
                        // selectionClick，与上面的页中点点击叠加成一次滑动
                        // 双震动。日切换反馈已在页中点给过，这里就地消费。
                        return true;
                      }
                      if (notification is ScrollStartNotification) {
                        if (kDebugMode) {
                          final metrics = notification.metrics;
                          final page = metrics.viewportDimension == 0
                              ? 0.0
                              : metrics.pixels / metrics.viewportDimension;
                          debugPrint(
                            '[DayPager] start: page=${page.toStringAsFixed(3)} '
                            'drag=${notification.dragDetails != null}',
                          );
                        }
                      } else if (notification is ScrollEndNotification) {
                        if (kDebugMode) {
                          final metrics = notification.metrics;
                          final page = metrics.viewportDimension == 0
                              ? 0.0
                              : metrics.pixels / metrics.viewportDimension;
                          debugPrint(
                            '[DayPager] end: page=${page.toStringAsFixed(3)}',
                          );
                        }
                        _settleDayViewPage(provider, settings);
                      }
                      return false;
                    },
                    child: PageView.builder(
                      key: const ValueKey('day-view-swipe-area'),
                      controller: controller,
                      // pageSnapping off on purpose: PageView would otherwise
                      // wrap its own PageScrollPhysics OUTSIDE ours and the
                      // rescue would never run. _dayPagerPhysics IS the snap.
                      physics: _dayPagerPhysics,
                      pageSnapping: false,
                      itemCount: pageCount,
                      // Same as the week pager: keep neighbours pre-built so a
                      // swipe never hits an itemBuilder spike mid-gesture.
                      allowImplicitScrolling: true,
                      onPageChanged: (page) =>
                          _handleDayViewPageChanged(provider, settings, page),
                      itemBuilder: (context, page) {
                        // 1 Hz progress heartbeat rebuilds only this page's
                        // content (ongoing badges / progress), not the State.
                        return ValueListenableBuilder<int>(
                          valueListenable: _dayAgendaProgressTick,
                          builder: (context, _, _) => _buildDayViewPageContent(
                            provider: provider,
                            settings: settings,
                            page: page,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// One day-pager page: summary card + agenda column.
  ///
  /// Extracted from the pager itemBuilder so [_dayAgendaProgressTick] can
  /// rebuild exactly this subtree once a second instead of the whole home
  /// screen (week pager included), which used to drop day-view FPS.
  Widget _buildDayViewPageContent({
    required TimetableProvider provider,
    required TimetableSettings settings,
    required int page,
  }) {
    final target = _dayViewTargetForPage(settings, page);
    if (_TimetableScreenState.logDayViewBuilds) {
      debugPrint(
        '[DayView] build page=$page -> week=${target.week} '
        'day=${target.dayOfWeek}',
      );
    }
    final selectedDate = _dateForWeekDay(
      settings,
      target.week,
      target.dayOfWeek,
    );
    final courses = _getCoursesForDay(
      provider.courses,
      target.week,
      target.dayOfWeek,
      settings,
    );
    final currentCourse =
        _isSelectedDayToday(
          provider: provider,
          settings: settings,
          week: target.week,
          dayOfWeek: target.dayOfWeek,
        )
        ? provider.getCourseInProgress(
            dayOfWeek: target.dayOfWeek,
            week: target.week,
          )
        : null;
    final currentCourseIds =
        _isSelectedDayToday(
          provider: provider,
          settings: settings,
          week: target.week,
          dayOfWeek: target.dayOfWeek,
        )
        ? provider
              .getCoursesInProgress(
                dayOfWeek: target.dayOfWeek,
                week: target.week,
              )
              .map((course) => course.id)
              .toSet()
        : const <String>{};
    final displayItems = _buildHomeDayDisplayItems(
      provider: provider,
      settings: settings,
      week: target.week,
      dayOfWeek: target.dayOfWeek,
      myCourses: courses,
      currentCourseIds: currentCourseIds,
    );
    final agendaItems = _buildDayAgendaItems(
      provider: provider,
      settings: settings,
      week: target.week,
      dayOfWeek: target.dayOfWeek,
      courseItems: displayItems,
    );
    final scheduleItems = agendaItems
        .where((item) => item.isScheduleItem)
        .map((item) => item.scheduleItem!)
        .toList(growable: false);
    if (_TimetableScreenState.logDayViewBuilds) {
      debugPrint(
        '[DayView] page=$page items: courses=${displayItems.length} '
        'agenda=${agendaItems.length} schedule=${scheduleItems.length}',
      );
    }
    final isActivePage =
        target.week == _selectedWeekForDayView &&
        target.dayOfWeek == _selectedDayOfWeek;
    return Column(
      key: ValueKey('day-content-${target.week}-${target.dayOfWeek}'),
      children: [
        // Keep original side inset / card width; only the
        // surface material matches chrome glass (below).
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: _buildDayViewSummary(
            key: isActivePage ? const ValueKey('day-view-summary') : null,
            provider: provider,
            settings: settings,
            week: target.week,
            dayOfWeek: target.dayOfWeek,
            selectedDate: selectedDate,
            currentCourse: currentCourse,
            courseItems: displayItems,
            scheduleItems: scheduleItems,
            agendaItems: agendaItems,
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _buildExpandedDayColumnView(
            key: ValueKey('day-column-${target.week}-${target.dayOfWeek}'),
            provider: provider,
            settings: settings,
            week: target.week,
            dayOfWeek: target.dayOfWeek,
          ),
        ),
      ],
    );
  }

  bool _isSelectedDayToday({
    required TimetableProvider provider,
    required TimetableSettings settings,
    required int week,
    required int dayOfWeek,
  }) {
    final resolvedDate = _dateForWeekDay(settings, week, dayOfWeek);
    if (resolvedDate != null) {
      return _isSameDate(resolvedDate, DateTime.now());
    }
    final now = DateTime.now();
    return dayOfWeek == now.weekday && week == _visibleWeek;
  }

  DateTime _resolveDisplayDateForWeekDay({
    required TimetableProvider provider,
    required TimetableSettings settings,
    required int week,
    required int dayOfWeek,
  }) {
    final resolvedDate = _dateForWeekDay(settings, week, dayOfWeek);
    if (resolvedDate != null) {
      return resolvedDate;
    }

    final now = DateTime.now();
    final normalizedToday = DateTime(now.year, now.month, now.day);
    final dayDelta = (week - _visibleWeek) * 7 + dayOfWeek - now.weekday;
    return normalizedToday.add(Duration(days: dayDelta));
  }

  List<ScheduleItemInstance> _getScheduleItemsForWeekDay({
    required TimetableProvider provider,
    required TimetableSettings settings,
    required int week,
    required int dayOfWeek,
  }) {
    final targetDate = _resolveDisplayDateForWeekDay(
      provider: provider,
      settings: settings,
      week: week,
      dayOfWeek: dayOfWeek,
    );
    return provider.getScheduleItemInstancesForDate(targetDate);
  }

  _DayAgendaItem _buildScheduleAgendaItemForDate({
    required ScheduleItemInstance instance,
    required DateTime targetDate,
  }) {
    final item = instance.effectiveItem;
    final normalizedTargetDate = DateTime(
      targetDate.year,
      targetDate.month,
      targetDate.day,
    );
    final continuesFromPreviousDay = item.startDate.isBefore(
      normalizedTargetDate,
    );
    final continuesToNextDay = item.endDate.isAfter(normalizedTargetDate);
    return _DayAgendaItem.schedule(
      item,
      instance: instance,
      startTime: continuesFromPreviousDay ? '00:00' : item.startTime,
      endTime: continuesToNextDay ? '23:59' : item.endTime,
      continuesFromPreviousDay: continuesFromPreviousDay,
      continuesToNextDay: continuesToNextDay,
    );
  }

  List<_DayAgendaItem> _buildDayAgendaItems({
    required TimetableProvider provider,
    required TimetableSettings settings,
    required int week,
    required int dayOfWeek,
    required List<DayCourseDisplayItem> courseItems,
  }) {
    final targetDate = _resolveDisplayDateForWeekDay(
      provider: provider,
      settings: settings,
      week: week,
      dayOfWeek: dayOfWeek,
    );
    final items = <_DayAgendaItem>[
      ...courseItems.map(_DayAgendaItem.course),
      ..._getScheduleItemsForWeekDay(
        provider: provider,
        settings: settings,
        week: week,
        dayOfWeek: dayOfWeek,
      ).map(
        (instance) => _buildScheduleAgendaItemForDate(
          instance: instance,
          targetDate: targetDate,
        ),
      ),
      ...provider.exams
          .where((e) => !e.isExpired && _isSameDate(e.dateTime, targetDate))
          .map(_DayAgendaItem.exam),
    ];

    items.sort((left, right) {
      // 当日议程是**课程 + 考试 + 日程**的混排，而 `Course.fromJson`
      // （models/course.dart:298）与 `ScheduleItem.fromJson`（:226）都原样收下钟点串：
      // 外来存档里的 `9:00` 在字典序下比 `10:00` 大，同一天会排反。
      // 正源是 `domain/clock_order.dart` 的 `compareClockText`；
      // 这条规则在本仓已经修过三轮，剩下的位置由
      // `test/architecture/clock_field_compare_guard_test.dart` 钉住。
      final startCompare = compareClockText(left.startTime, right.startTime);
      if (startCompare != 0) {
        return startCompare;
      }
      final endCompare = compareClockText(left.endTime, right.endTime);
      if (endCompare != 0) {
        return endCompare;
      }
      final leftType = left.isExam ? 2 : (left.isScheduleItem ? 1 : 0);
      final rightType = right.isExam ? 2 : (right.isScheduleItem ? 1 : 0);
      if (leftType != rightType) {
        return leftType.compareTo(rightType);
      }
      return left.id.compareTo(right.id);
    });
    return items;
  }

  Widget _buildDayViewSummary({
    Key? key,
    required TimetableProvider provider,
    required TimetableSettings settings,
    required int week,
    required int dayOfWeek,
    required DateTime? selectedDate,
    required Course? currentCourse,
    required List<DayCourseDisplayItem> courseItems,
    required List<ScheduleItem> scheduleItems,
    required List<_DayAgendaItem> agendaItems,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final foruiTheme = context.theme;
    final colorScheme = theme.colorScheme;
    final isToday = _isSelectedDayToday(
      provider: provider,
      settings: settings,
      week: week,
      dayOfWeek: dayOfWeek,
    );
    final courseCount = courseItems.length;
    final scheduleCount = scheduleItems.length;
    final hasAgenda = agendaItems.isNotEmpty;
    final currentWeekItems = courseItems
        .where((item) => item.isCurrentWeekCourse)
        .toList();
    final nonCurrentWeekCourseCount = courseCount - currentWeekItems.length;
    final conflictCount = courseItems
        .where((item) => item.isConflicting)
        .length;
    final firstAgenda = hasAgenda ? agendaItems.first : null;
    final lastAgenda = hasAgenda ? agendaItems.last : null;
    final locale = Localizations.localeOf(context);
    final localeName = locale.countryCode?.isNotEmpty == true
        ? '${locale.languageCode}_${locale.countryCode}'
        : locale.languageCode;
    final dateLabel = selectedDate != null
        ? _formatDayViewSummaryDate(
            selectedDate,
            dayOfWeek: dayOfWeek,
            localeName: localeName,
          )
        : _weekdayLabel(context, dayOfWeek);
    final targetDate =
        selectedDate ??
        _resolveDisplayDateForWeekDay(
          provider: provider,
          settings: settings,
          week: week,
          dayOfWeek: dayOfWeek,
        );
    final dayExams =
        provider.exams
            .where((e) => !e.isExpired && _isSameDate(e.dateTime, targetDate))
            .toList()
          ..sort((a, b) => a.startTime.compareTo(b.startTime));

    final isDark = theme.brightness == Brightness.dark;
    final hasBackdrop = hasHomePageBackdrop(settings);
    final backdropBlurOn =
        hasBackdrop && HyperosBlurredHeader.backdropBlurEnabled(context);
    final courseCardStyle = dayViewContentCardSurfaceStyle(
      settings,
      backdropBlurOn: backdropBlurOn,
    );
    // 摘要卡跟**课程卡**同材质（用户口径 2026-09-22：「日视图顶部的日期卡片……
    // 也要跟日视图的课程卡片是一样的材质，选什么就是什么，不要第二种」）：
    // 材质一律由 CourseSurface 按 effectiveCourseCardSurfaceStyle 出 —— 与下方
    // 议程卡走**同一条路径、同一档、同一份预糊位图、同一套调参**。
    //
    // 这里曾经有一条例外分支（`chromeGlass` 亮磨砂替身：跟顶栏铬玻璃带同款）：
    // 课程卡是玻璃档时给摘要卡贴一块固定的亮色 wash，读作"顶栏同款"而不是
    // "课程卡同款"——用户实测两张卡材质不一致。例外已删除，
    // `homePageHasAnyChromeBlur` 也不再参与这张卡的材质判定。
    //
    // 实体档那条老口径自然仍成立：无壁纸 / 全局模糊关掉时
    // [effectiveCourseCardSurfaceStyle] 就回落实体，摘要卡跟着实底，不会出现
    // 「课程卡实心、顶上的日期卡还透」。
    // Ink: 卡面**真的把壁纸透出来**时才自动黑白；否则卡面是主题底色
    // 的实底，墨色必须跟主题走 —— 按壁纸亮度翻白会让白墨落在亮色卡面上
    // 不可读。判据是**卡实际用的材质**，不是顶栏状态。
    //
    // 自动黑白判的是**卡面**亮度（卡自己的底色 + 壁纸那条带按染色强度混合，
    // 见 [contentCardInkOverWallpaper]），不是裸壁纸亮度：2026-09-22 真机反馈
    // "浅色主题下卡面发白、字也是浅色糊在一起"，就是漏了卡面那层 32%~42% 的
    // 自有底色所致。
    //
    // 壁纸那条带取的是 `_weekdayInkLuminance`（信息栏与顶栏带用的就是它）：
    // 这张卡的墨色本来就是信息栏那套
    //（configuredHex 取的就是 weekdayBarFontColor*）。
    // 早先这里用 body 带（整屏下半部，常含壁纸的深色区），于是出现"带是
    // 浅色、卡片也是亮卡，却按深色壁纸翻成白墨"——白字落在亮卡上读不出来
    // （真机反馈：高斯档下日课表那张日期卡）。
    final glassOverWallpaper = backdropBlurOn && courseCardStyle.isGlass;
    final summaryInk = glassOverWallpaper
        ? contentCardInkOverWallpaper(
            // 判据是**卡面**亮度，不是裸壁纸：卡面上还压着
            // `CourseSurface.washAlpha` 比例的自有底色（就是这里的
            // `foruiTheme.colors.background`）。只看壁纸会在浅色主题下把白字
            // 判到被冲白的卡面上（2026-09-22 真机反馈），详见该函数。
            cardFill: foruiTheme.colors.background,
            washAlpha: CourseSurface.washAlpha(context, courseCardStyle),
            configuredHex: isDark
                ? settings.weekdayBarFontColorDark
                : settings.weekdayBarFontColorLight,
            defaultHex: isDark
                ? TimetableSettings.defaultWeekdayBarFontColorDark
                : TimetableSettings.defaultWeekdayBarFontColorLight,
            themeFallback: foruiTheme.colors.foreground,
            hasBackdrop: hasBackdrop,
            wallpaperLuminance: _weekdayInkLuminance(settings),
          )
        : foruiTheme.colors.foreground;
    final summaryMutedInk = homePageOverWallpaperMutedInk(summaryInk);
    // 课程计数胶囊与「X 节日程」胶囊同款中性墨：跟摘要卡其余文字一样走
    // 壁纸自动黑白，有课与否不再切换主题蓝强调色。
    final countBadgeColor = summaryInk.withValues(alpha: 0.10);
    final countBadgeTextColor = summaryMutedInk;
    return _dayAgendaSurface(
      key: key,
      // 材质全部交给 CourseSurface 按 effectiveCourseCardSurfaceStyle 判
      //（无壁纸 / 全局模糊关掉时它自己回落实体），这里不再覆盖卡片档。
      settings: settings,
      // Neutral wash (not a course hue); CourseSurface owns glass vs solid.
      color: foruiTheme.colors.background,
      gradient: LinearGradient(
        colors: [foruiTheme.colors.background, foruiTheme.colors.background],
      ),
      // 摘要卡没有课程色填充可依托：无壁纸（纯色页面）时填充色与页面底色
      // 相同，无边框无阴影会整张隐形（下方课程卡靠 hue + outerShadow 保持
      // 边界）。补一套中性细描边 + 柔和投影，几何参数与 agenda 卡片一致，
      // 让两种卡片在纯白底上读作同一个卡片系统。
      border: Border.all(color: summaryInk.withValues(alpha: 0.12)),
      shadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.08),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      // 「回到今天」已挪到日视图底部的悬浮按钮（见
                      // [_buildFloatingBackToTodayButton]）：这张摘要卡只留
                      // 「今天 · 第几周」，不再放可点胶囊，避免两个入口。
                      if (isToday) ...[
                        Text(
                          l10n.todayTimetableTitle,
                          style: foruiTheme.typography.body.sm.copyWith(
                            color: summaryMutedInk,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Text(
                            '·',
                            style: foruiTheme.typography.body.sm.copyWith(
                              color: summaryMutedInk,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                      Text(
                        l10n.weekLabel(week),
                        style: foruiTheme.typography.body.sm.copyWith(
                          color: summaryMutedInk,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  key: const ValueKey('back-to-week-view-button'),
                  onPressed: () => _closeDayView(settings),
                  icon: const Icon(Icons.close_rounded, size: 18),
                  tooltip: l10n.backToWeekViewAction,
                  style: IconButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.all(6),
                    minimumSize: const Size(32, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    foregroundColor: summaryMutedInk,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              dateLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: foruiTheme.typography.display.lg.copyWith(
                fontWeight: FontWeight.w400,
                letterSpacing: 0.1,
                height: 1.15,
                color: summaryInk,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: countBadgeColor,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text(
                    hasAgenda
                        ? (courseCount > 0
                              ? l10n.courseCountSummary(courseCount)
                              : l10n.scheduleCountSummary(scheduleCount))
                        : l10n.courseCountSummary(0),
                    style: foruiTheme.typography.body.xs2.copyWith(
                      color: countBadgeTextColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (scheduleCount > 0 && courseCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: summaryInk.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Text(
                      l10n.scheduleCountSummary(scheduleCount),
                      style: foruiTheme.typography.body.xs2.copyWith(
                        color: summaryMutedInk,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                if (firstAgenda != null)
                  Text(
                    '${l10n.classStartsAtLabel(firstAgenda.startTime)} · ${l10n.classEndsAtLabel(lastAgenda!.endTime)}',
                    style: foruiTheme.typography.body.xs2.copyWith(
                      color: summaryMutedInk,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
            if (currentCourse != null ||
                conflictCount > 0 ||
                nonCurrentWeekCourseCount > 0 ||
                dayExams.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (currentCourse != null)
                    _buildDayViewSummaryChip(
                      icon: Icons.bolt_rounded,
                      text:
                          '${l10n.ongoingCourseBadge} · ${currentCourse.name}',
                      accentColor: colorScheme.primary,
                    ),
                  if (conflictCount > 0)
                    _buildDayViewSummaryChip(
                      icon: Icons.warning_amber_rounded,
                      text: l10n.conflictCountLabel(conflictCount),
                      accentColor: colorScheme.error,
                    ),
                  if (nonCurrentWeekCourseCount > 0)
                    _buildDayViewSummaryChip(
                      icon: Icons.visibility_rounded,
                      text:
                          '${l10n.nonCurrentWeekLabel} ${l10n.courseCountSummary(nonCurrentWeekCourseCount)}',
                    ),
                  ...dayExams.map(
                    (exam) => _buildDayViewSummaryChip(
                      icon: Icons.school_outlined,
                      text:
                          '${exam.name} · ${exam.daysUntil == 0 ? l10n.examCountdownToday : l10n.examCountdownDays(exam.daysUntil)}',
                      accentColor: colorScheme.error,
                    ),
                  ),
                ],
              ),
            ],
            if (_isCoupleOverlayActive(provider)) ...[
              const SizedBox(height: 12),
              _buildDayViewSharedFreeSummary(
                provider: provider,
                settings: settings,
                week: week,
                dayOfWeek: dayOfWeek,
                isToday: isToday,
                ink: summaryInk,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDayViewSummaryChip({
    required IconData icon,
    required String text,
    Color? accentColor,
  }) {
    final foruiTheme = context.theme;
    final resolvedAccent = accentColor ?? foruiTheme.colors.mutedForeground;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: resolvedAccent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: resolvedAccent),
          const SizedBox(width: 5),
          Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: foruiTheme.typography.body.xs.copyWith(
              color: resolvedAccent,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  List<SectionTime> _sectionsForSharedFree(
    TimetableProvider provider,
    TimetableSettings settings,
  ) {
    final schemeSections = provider.activeTimeScheme?.sections;
    if (schemeSections != null && schemeSections.isNotEmpty) {
      return schemeSections;
    }
    return settings.sections;
  }

  bool _isPartnerScheduleStale(TimetableProvider provider) {
    final importedAt = provider.partnerBinding?.lastImportedAt;
    if (importedAt == null) {
      return true;
    }
    return DateTime.now().difference(importedAt) > _TimetableScreenState._partnerScheduleStaleAfter;
  }

  List<MinuteInterval> _sharedFreeIntervalsForDayView({
    required TimetableProvider provider,
    required TimetableSettings settings,
    required int week,
    required int dayOfWeek,
  }) {
    final sections = _sectionsForSharedFree(provider, settings);
    return CoupleTimetableLogic.sharedFreeIntervalsForDay(
      myCourses: provider.courses,
      partnerCourses: provider.partnerCourses,
      dayOfWeek: dayOfWeek,
      week: week,
      partnerWeekOffset: provider.partnerWeekOffset,
      sections: sections,
    );
  }

  Widget _buildSharedFreeSummaryShell({
    required Key key,
    required Color ink,
    required Widget child,
  }) {
    return DecoratedBox(
      key: key,
      decoration: BoxDecoration(
        // 摘要卡内的嵌套面板跟随摘要墨色：浅洗底 + 细描边，玻璃/实心、
        // 明暗主题都与母卡同极性。此前误用 colorScheme.secondary（M3 基线
        // 浅色 #625B71 近黑），高斯模糊下整张卡在亮磨砂上读作发黑的一块，
        // 标题墨色（onSurface 近黑）也低于可读下限。
        color: ink.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ink.withValues(alpha: 0.10)),
      ),
      child: Padding(
        // 与摘要卡内其它区块同一套水平节奏，避免再套一层 14 造成左右过空。
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: child,
      ),
    );
  }

  String _formatDayViewSummaryDate(
    DateTime date, {
    required int dayOfWeek,
    required String localeName,
  }) {
    final formattedDate = DateFormat.MMMd(localeName).format(date);
    return '$formattedDate ${_weekdayLabel(context, dayOfWeek)}';
  }

  Widget _buildDayViewEmptyState({
    required int week,
    required TimetableSettings settings,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasBackdrop = hasHomePageBackdrop(settings);
    final colorScheme = Theme.of(context).colorScheme;
    // Same wallpaper auto-contrast as weekday / time-axis chrome: default ink
    // flips black↔white over dark photos; a custom hex keeps its hue and only
    // gets its lightness pushed. The empty state sits mid-screen, so judge
    // from the card-region band.
    final titleColor = homePageOverWallpaperInk(
      configuredHex: isDark
          ? settings.weekdayBarFontColorDark
          : settings.weekdayBarFontColorLight,
      defaultHex: isDark
          ? TimetableSettings.defaultWeekdayBarFontColorDark
          : TimetableSettings.defaultWeekdayBarFontColorLight,
      themeFallback: colorScheme.onSurface,
      hasBackdrop: hasBackdrop,
      wallpaperLuminance: _wallpaperBodyLuminance ?? _wallpaperTopLuminance,
    );
    final subtitleColor = homePageOverWallpaperMutedInk(titleColor);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.dayViewEmptyTitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: titleColor,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.weekLabel(week),
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: subtitleColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandedDayColumnView({
    required Key key,
    required TimetableProvider provider,
    required TimetableSettings settings,
    required int week,
    required int dayOfWeek,
  }) {
    final courses = _getCoursesForDay(
      provider.courses,
      week,
      dayOfWeek,
      settings,
    );
    final currentCourseIds =
        _isSelectedDayToday(
          provider: provider,
          settings: settings,
          week: week,
          dayOfWeek: dayOfWeek,
        )
        ? provider
              .getCoursesInProgress(dayOfWeek: dayOfWeek, week: week)
              .map((course) => course.id)
              .toSet()
        : const <String>{};
    final displayItems = _buildHomeDayDisplayItems(
      provider: provider,
      settings: settings,
      week: week,
      dayOfWeek: dayOfWeek,
      myCourses: courses,
      currentCourseIds: currentCourseIds,
    );
    final agendaItems = _buildDayAgendaItems(
      provider: provider,
      settings: settings,
      week: week,
      dayOfWeek: dayOfWeek,
      courseItems: displayItems,
    );
    // 玻璃坞避让（含底部安全区）：日课表视口全屏，避让以滚动 padding
    // 实现——静止在列表底部时最后一项仍停在玻璃坞上方，滚动中卡片则
    // 连续穿过避让带，不再在边界被硬裁出与磨砂卡片色差明显的空带。
    // 满屏悬浮（overlay）同样取滚动余量（药丸占用兜底）：此前 overlay
    // 余量为 0，下滑到底最后一张卡仍压在药丸后面，无法滑出来看。
    final dockScrollAvoidance = _glassDockContentScrollInset(settings);
    // 再叠一层「回今日」浮钮的占用：浮钮浮在药丸上方居中，不补这段余量
    // 时滑到底的最后一张卡会被它压住（同底栏遮内容的道理，见
    // [_backToTodayButtonScrollInset]）。
    final todayButtonAvoidance = _backToTodayButtonScrollInset(provider);
    final listBottomContentInset =
        8 + dockScrollAvoidance + todayButtonAvoidance;
    // 空态是**居中块**，不是能滚的列表：那份浮钮余量存在的前提是"最后一张卡
    // 要能滑到钮上方"，而空态里唯一的像素是屏幕中间那两行字，离屏幕底部的
    // 浮钮还有大半屏，避让与否都碰不到。带上它反而害它在**今天 ↔ 非今天**之间
    // 换位置：浮钮只在非今天出现，那多出来的余量在滑动落定、整屏重建那一刻
    // 才被算进去，把居中的文字往上顶掉半个余量（玻璃坞 29px），用户读到的
    // 就是"没课那天滑过去，加载一结束'暂无课程'往上跳一下"
    // （2026-09-29 真机反馈）。所以空态只留药丸避让——与它是否今天无关。
    final emptyBottomContentInset = 8 + dockScrollAvoidance;
    // 预览那份要按宿主给的滚动位置起步（见 [_previewControllerFor]）。
    final scrollKey = _TimetableScreenState._dayAgendaScrollKey(week, dayOfWeek);
    final scrollController = _previewControllerFor(scrollKey);
    if (agendaItems.isEmpty) {
      // 空白天同样要能下拉导入：空态本身不是滚动体，外面套一层
      // AlwaysScrollable 的滚动视图，下拉才有着力点（有课那天走的是
      // ListView，两条路都必须能触发）。physics 与有课那天同源，
      // 「下拉开着时冻结」的手感一致。
      return _reportHomeScroll(
        scrollKey,
        CustomScrollView(
          key: key,
          controller: scrollController,
          physics: _homePullVerticalPhysics,
          slivers: [
            // SliverFillRemaining 让空态仍占满视口（内部 Center 照旧居中），
            // 底距留在 child 的 Padding 上——与改动前"Expanded + Padding"的
            // 布局逐像素一致，坞避让那条既有断言（找 bottom = 8 + 药丸占用
            // 的 Padding）也照旧成立。
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  14,
                  0,
                  14,
                  emptyBottomContentInset,
                ),
                child: _buildDayViewEmptyColumn(week: week, settings: settings),
              ),
            ),
          ],
        ),
      );
    }
    // Gaussian cards sample the cached wallpaper bitmap while the day view
    // moves; the shared host keeps their BackdropFilter capture at grid scope.
    final agendaList = ListView.separated(
      key: PageStorageKey<String>(scrollKey),
      controller: scrollController,
      padding: EdgeInsets.fromLTRB(14, 0, 14, listBottomContentInset),
      // 下拉开着时冻结纵向滚动（见 _HomePullFreezeScrollPhysics）：
      // 回拉取消只收下拉，不把列表一起滚走。
      physics: _homePullVerticalPhysics,
      itemCount: agendaItems.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, itemIndex) {
        final item = agendaItems[itemIndex];
        return _buildDayAgendaEntry(week: week, settings: settings, item: item);
      },
    );
    return CourseGridSurfaceHost(
      settings: settings,
      child: _reportHomeScroll(scrollKey, agendaList),
    );
  }

  Widget _buildDayViewEmptyColumn({
    required int week,
    required TimetableSettings settings,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
      child: _buildDayViewEmptyState(week: week, settings: settings),
    );
  }

  /// Day-view card surface honouring [TimetableSettings.courseCardSurfaceStyle]
  /// (falling back to solid whenever there is no wallpaper backdrop to blur).
  ///
  /// Shares [CourseSurface] with the week grid so the two views cannot drift.
  /// The tap target sits *inside* the surface behind a transparent [Material]
  /// so ink ripples paint above the frost rather than on the far page Material
  /// (which is what `Ink(decoration:)` used to buy us on an opaque card).
  Widget _dayAgendaSurface({
    required TimetableSettings settings,
    required Color color,
    required Widget child,
    Key? key,
    Gradient? gradient,
    Border? border,
    List<BoxShadow>? shadow,
    double radius = _TimetableScreenState._dayViewCardRadius,
    VoidCallback? onTap,
    double opacityScale = 1,
  }) {
    final content = onTap == null
        ? child
        : Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(radius),
              child: child,
            ),
          );
    return CourseSurface(
      key: key,
      // Effective style: without a wallpaper or without the blur pipeline
      // (global solid / degraded) the gaussian look has no source to sample,
      // so every agenda card falls back to solid. 与顶部摘要卡**同源**
      // （[dayViewContentCardSurfaceStyle]）：日视图两种内容卡一个材质口径，
      // 见那里的说明。
      style: dayViewContentCardSurfaceStyle(
        settings,
        backdropBlurOn: HyperosBlurredHeader.backdropBlurEnabled(context),
      ),
      color: color,
      borderRadius: radius,
      opacityScale: opacityScale,
      solidGradient: gradient,
      border: border,
      outerShadow: shadow,
      child: content,
    );
  }

  Widget _buildDayAgendaEntry({
    required int week,
    required TimetableSettings settings,
    required _DayAgendaItem item,
  }) {
    if (item.isExam) {
      if (_TimetableScreenState.logDayViewBuilds) {
        debugPrint('[DayView] build agenda entry: exam id=${item.exam?.id}');
      }
      return _buildExamAgendaEntry(
        item.exam!,
        provider: context.read<TimetableProvider>(),
      );
    }
    if (item.isScheduleItem) {
      if (_TimetableScreenState.logDayViewBuilds) {
        debugPrint(
          '[DayView] build agenda entry: schedule id=${item.scheduleItem?.id}',
        );
      }
      return _buildScheduleAgendaEntry(item, settings: settings);
    }

    final courseItem = item.courseItem!;
    if (_TimetableScreenState.logDayViewBuilds) {
      debugPrint(
        '[DayView] build agenda entry: course id=${courseItem.course.id} '
        'name=${courseItem.course.name}',
      );
    }
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final colorHex = _resolveDisplayCourseColor(courseItem, settings: settings);
    final resolvedColor = _colorFromHex(
      colorHex ?? courseItem.course.color,
      Colors.blue,
    );
    final palette = _resolveDayAgendaPalette(
      resolvedColor,
      foregroundHex: courseItem.course.textColor,
      settings: settings,
    );
    final onCardColor = palette.foregroundColor;
    final statusBadges = <Widget>[
      if (courseItem.isCurrentCourse)
        _buildDayAgendaStatusBadge(
          text: l10n.ongoingCourseBadge,
          textColor: onCardColor,
          backgroundColor: Colors.white.withValues(alpha: 0.18),
        ),
      if (courseItem.isConflicting && settings.showConflictBadgeOnTimetable)
        _buildDayAgendaStatusBadge(
          text: l10n.conflictLabel,
          textColor: Colors.white,
          backgroundColor: colorScheme.error,
        ),
      if (courseItem.coupleKind == CoupleCourseKind.together)
        _buildDayAgendaStatusBadge(
          text: l10n.coupleTimetableLegendTogether,
          textColor: Colors.white,
          backgroundColor: _colorFromHex(
            context.read<TimetableProvider>().coupleColorForKind(
              CoupleCourseKind.together,
            ),
            Colors.purple,
          ),
        ),
      if (courseItem.coupleKind == CoupleCourseKind.partner)
        _buildDayAgendaStatusBadge(
          text: l10n.coupleTimetableLegendPartner,
          textColor: Colors.white,
          backgroundColor: _colorFromHex(
            context.read<TimetableProvider>().coupleColorForKind(
              CoupleCourseKind.partner,
            ),
            Colors.pink,
          ),
        ),
      if (!courseItem.isCurrentWeekCourse)
        _buildDayAgendaStatusBadge(
          text: l10n.nonCurrentWeekLabel,
          textColor: onCardColor,
          backgroundColor: Colors.white.withValues(alpha: 0.14),
        ),
      if (courseItem.course.isSuspendedInWeek(week))
        _buildDayAgendaStatusBadge(
          text: l10n.suspendedBadgeLabel,
          textColor: Colors.white,
          backgroundColor: Colors.red.shade700,
        ),
      if (!courseItem.isPartnerCourse &&
          courseItem.course.hasHomeworkInWeek(week))
        _buildDayAgendaHomeworkDot(),
    ];
    final cardDecoration = BoxDecoration(
      color: palette.baseColor,
      borderRadius: BorderRadius.circular(_TimetableScreenState._dayViewCardRadius),
      border: courseItem.isConflicting
          ? Border.all(
              color: colorScheme.error.withValues(alpha: 0.30),
              width: 1.4,
            )
          : null,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          palette.baseColor,
          if (courseItem.isConflicting)
            Color.lerp(palette.fillColor, colorScheme.error, 0.12) ??
                palette.fillColor
          else
            palette.fillColor,
        ],
      ),
      boxShadow: [
        BoxShadow(
          color:
              (courseItem.isConflicting ? colorScheme.error : palette.fillColor)
                  .withValues(alpha: courseItem.isConflicting ? 0.20 : 0.18),
          blurRadius: courseItem.isConflicting ? 18 : 16,
          offset: const Offset(0, 4),
        ),
      ],
    );
    final progressInfo = courseItem.isCurrentCourse
        ? _resolveDayAgendaProgressInfo(courseItem.course, palette: palette)
        : null;

    final isSuspended = courseItem.course.isSuspendedInWeek(week);
    // Keep frost readable; only a light dim for suspended / conflict states.
    final effectiveOpacity = isSuspended ? 0.84 : courseItem.opacity;

    Future<void> openCourseNotes() {
      return showCourseNoteSheet(
        context,
        course: courseItem.course,
        week: week,
        readOnly: courseItem.isPartnerCourse,
      );
    }

    if (courseItem.isPartnerCourse) {
      void openCoursePreview() {
        _showCourseActions(courseItem.course, week, displayItem: courseItem);
      }

      final partnerCard = progressInfo != null
          ? _buildCurrentDayAgendaCard(
              item: courseItem,
              week: week,
              settings: settings,
              progressInfo: progressInfo,
              l10n: l10n,
              colorScheme: colorScheme,
              ink: palette.foregroundColor,
              openContainer: openCoursePreview,
              onOpenNotes: openCourseNotes,
              opacityScale: effectiveOpacity,
            )
          : _buildDefaultDayAgendaCard(
              item: courseItem,
              week: week,
              settings: settings,
              l10n: l10n,
              palette: palette,
              statusBadges: statusBadges,
              cardDecoration: cardDecoration,
              openContainer: openCoursePreview,
              onOpenNotes: openCourseNotes,
              opacityScale: effectiveOpacity,
            );

      return Material(color: Colors.transparent, child: partnerCard);
    }

    // Released behaviour: tap expands the card into the editor via a container
    // transform. Dimming stays on opacityScale (not an Opacity wrapper) so
    // glass surfaces can still sample the backdrop.
    return OpenContainer<void>(
      key: ValueKey('day-view-edit-card-${courseItem.course.id}'),
      tappable: false,
      transitionType: ContainerTransitionType.fadeThrough,
      transitionDuration: const Duration(milliseconds: 420),
      openColor: theme.scaffoldBackgroundColor,
      closedColor: Colors.transparent,
      closedElevation: 0,
      openElevation: 0,
      closedShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_TimetableScreenState._dayViewCardRadius),
      ),
      openShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
      ),
      openBuilder: (context, _) => ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: AddCourseScreen(
          courseGroup: context.read<TimetableProvider>().courseGroupForCourse(
            courseItem.course,
          ),
          initialCourse: courseItem.course,
        ),
      ),
      closedBuilder: (context, openContainer) {
        final content = progressInfo != null
            ? _buildCurrentDayAgendaCard(
                item: courseItem,
                week: week,
                settings: settings,
                progressInfo: progressInfo,
                l10n: l10n,
                colorScheme: colorScheme,
                ink: palette.foregroundColor,
                openContainer: openContainer,
                onOpenNotes: openCourseNotes,
                opacityScale: effectiveOpacity,
              )
            : _buildDefaultDayAgendaCard(
                item: courseItem,
                week: week,
                settings: settings,
                l10n: l10n,
                palette: palette,
                statusBadges: statusBadges,
                cardDecoration: cardDecoration,
                openContainer: openContainer,
                onOpenNotes: openCourseNotes,
                opacityScale: effectiveOpacity,
              );
        return Material(color: Colors.transparent, child: content);
      },
    );
  }

  Widget _buildDefaultDayAgendaCard({
    required DayCourseDisplayItem item,
    required int week,
    required TimetableSettings settings,
    required AppLocalizations l10n,
    required _DayAgendaPalette palette,
    required List<Widget> statusBadges,
    required BoxDecoration cardDecoration,
    required VoidCallback openContainer,
    required VoidCallback onOpenNotes,
    double opacityScale = 1,
  }) {
    final sectionLabel = l10n.sectionRangeLabel(
      item.course.startSection,
      item.course.endSection,
    );
    final teacherValue = item.course.teacher.trim().isNotEmpty
        ? item.course.teacher.trim()
        : l10n.unknownTeacher;
    final teacherLine = '${l10n.teacherPrefix(teacherValue)} · $sectionLabel';
    final locationValue = item.course.location.trim().isNotEmpty
        ? item.course.location.trim()
        : l10n.unknownLocation;
    final locationLine = l10n.locationPrefix(locationValue);
    final sessionNote = item.course.sessionNoteForWeek(week);
    final sessionPreview = sessionNote?.trimmedText;
    final ink = palette.foregroundColor;
    return _dayAgendaSurface(
      settings: settings,
      color: palette.baseColor,
      opacityScale: opacityScale,
      // Reuse the legacy decoration's pieces so `solid` stays pixel-identical.
      gradient: cardDecoration.gradient,
      border: cardDecoration.border as Border?,
      shadow: cardDecoration.boxShadow,
      onTap: openContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: _dayAgendaInkWash(ink, lightAlpha: 0.18),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.schedule_rounded, size: 13, color: ink),
                            const SizedBox(width: 5),
                            Text(
                              '${item.course.startTime} - ${item.course.endTime}',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: ink,
                                    fontWeight: FontWeight.w400,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      ...statusBadges,
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                _buildDayAgendaNoteAction(
                  l10n: l10n,
                  ink: ink,
                  onPressed: onOpenNotes,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              item.course.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                // Auto ink: flips black/white against the wallpaper band
                // behind glass cards (white-on-white mist was unreadable).
                color: ink,
                fontWeight: FontWeight.w400,
                height: 1.10,
              ),
            ),
            const SizedBox(height: 10),
            _buildCurrentDayAgendaInfoRow(
              icon: Icons.person_outline_rounded,
              text: teacherLine,
              ink: ink,
            ),
            const SizedBox(height: 5.5),
            _buildCurrentDayAgendaInfoRow(
              icon: Icons.location_on_outlined,
              text: locationLine,
              ink: ink,
            ),
            DayCourseWeatherRow(
              date: _dateForWeekDay(settings, week, item.course.dayOfWeek),
              startTime: item.course.startTime,
              endTime: item.course.endTime,
              ink: ink,
              // 天气是「那一天」的属性，只有这节课这一周真的要上才有意义。
              // 非本周的灰卡（单双周错位、还没开课）代表的那一天并不上课，挂上
              // 那天的天气会让人以为当天要带伞；对方课程则是在别的城市，拿本地
              // 天气同样不对。教师、地点是课程属性，与哪一周无关，照常显示。
              visible:
                  settings.weatherShowOnDayCard &&
                  !item.isPartnerCourse &&
                  item.course.isActiveInWeek(week),
              showPhenomenon: settings.weatherShowPhenomenon,
              showTemperature: settings.weatherShowTemperature,
              showProbability: settings.weatherShowProbability,
            ),
            if (sessionPreview != null && sessionPreview.isNotEmpty) ...[
              const SizedBox(height: 5.5),
              _buildCurrentDayAgendaInfoRow(
                icon: Icons.sticky_note_2_outlined,
                text: sessionPreview,
                ink: ink,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentDayAgendaCard({
    required DayCourseDisplayItem item,
    required int week,
    required TimetableSettings settings,
    required _DayAgendaProgressInfo progressInfo,
    required AppLocalizations l10n,
    required ColorScheme colorScheme,
    required Color ink,
    required VoidCallback openContainer,
    required VoidCallback onOpenNotes,
    double opacityScale = 1,
  }) {
    final theme = Theme.of(context);
    final sectionLabel = l10n.sectionRangeLabel(
      item.course.startSection,
      item.course.endSection,
    );
    final teacherValue = item.course.teacher.trim().isNotEmpty
        ? item.course.teacher.trim()
        : l10n.unknownTeacher;
    final teacherLine = '${l10n.teacherPrefix(teacherValue)} · $sectionLabel';
    final locationValue = item.course.location.trim().isNotEmpty
        ? item.course.location.trim()
        : l10n.unknownLocation;
    final locationLine = l10n.locationPrefix(locationValue);
    final borderColor = item.isConflicting
        ? colorScheme.error.withValues(alpha: 0.30)
        : Colors.transparent;
    final sessionNote = item.course.sessionNoteForWeek(week);
    final sessionPreview = sessionNote?.trimmedText;

    // Over glass the elapsed-progress fill has to stay see-through, or that
    // part of the card turns into a flat opaque block and the frost disappears.
    final progressFill =
        effectiveCourseCardSurfaceStyle(
              settings,
              gaussianBlurAvailable: HyperosBlurredHeader.backdropBlurEnabled(
                context,
              ),
            ) ==
            CourseCardSurfaceStyle.solid
        ? progressInfo.fillColor
        : progressInfo.fillColor.withValues(alpha: 0.55);

    return _dayAgendaSurface(
      settings: settings,
      color: progressInfo.baseColor,
      opacityScale: opacityScale,
      // Flat fill, matching the legacy decoration (this card has no gradient).
      gradient: LinearGradient(
        colors: [progressInfo.baseColor, progressInfo.baseColor],
      ),
      border: Border.all(color: borderColor, width: 1.2),
      shadow: [
        BoxShadow(
          color: progressInfo.fillColor.withValues(alpha: 0.18),
          blurRadius: 18,
          offset: const Offset(0, 4),
        ),
      ],
      onTap: openContainer,
      child: ClipRRect(
        key: ValueKey('day-agenda-progress-card-${item.course.id}'),
        borderRadius: BorderRadius.circular(_TimetableScreenState._dayViewCardRadius),
        child: Stack(
          children: [
            Positioned.fill(
              // Isolated: the animating fill must not invalidate the card's
              // glass surface / text layers on every animation frame.
              child: RepaintBoundary(
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(
                    end: progressInfo.progress.clamp(0.0, 1.0),
                  ),
                  // Must stay below the 1 s progress tick, or the tween is
                  // retargeted before it settles and day view animates every
                  // frame forever (see _quantizeDayAgendaProgress).
                  duration: const Duration(milliseconds: 600),
                  builder: (context, animatedProgress, child) {
                    return FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: animatedProgress,
                      child: child,
                    );
                  },
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: progressFill,
                      borderRadius: BorderRadius.circular(_TimetableScreenState._dayViewCardRadius),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: _dayAgendaInkWash(ink, lightAlpha: 0.18),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.schedule_rounded,
                                    size: 13,
                                    color: ink,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    '${item.course.startTime} - ${item.course.endTime}',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: ink,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            _buildDayAgendaStatusBadge(
                              text: progressInfo.statusText,
                              textColor: progressInfo.statusTextColor,
                              backgroundColor:
                                  progressInfo.statusBackgroundColor,
                            ),
                            if (item.isConflicting)
                              _buildDayAgendaStatusBadge(
                                text: l10n.conflictLabel,
                                textColor: Colors.white,
                                backgroundColor: colorScheme.error,
                              ),
                            if (!item.isPartnerCourse &&
                                item.course.hasHomeworkInWeek(week))
                              _buildDayAgendaHomeworkDot(),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      _buildDayAgendaNoteAction(
                        l10n: l10n,
                        ink: ink,
                        onPressed: onOpenNotes,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.course.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: ink,
                      fontWeight: FontWeight.w400,
                      height: 1.10,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildCurrentDayAgendaInfoRow(
                    icon: Icons.person_outline_rounded,
                    text: teacherLine,
                    ink: ink,
                  ),
                  const SizedBox(height: 5.5),
                  _buildCurrentDayAgendaInfoRow(
                    icon: Icons.location_on_outlined,
                    text: locationLine,
                    ink: ink,
                  ),
                  DayCourseWeatherRow(
                    date: _dateForWeekDay(
                      settings,
                      week,
                      item.course.dayOfWeek,
                    ),
                    startTime: item.course.startTime,
                    endTime: item.course.endTime,
                    ink: ink,
                    // 同普通课卡：这一周真的上才有天气。判据用 isActiveInWeek
                    // （= 不在停课周 且 在本周上课范围内），一处覆盖两种情况。
                    visible:
                        settings.weatherShowOnDayCard &&
                        !item.isPartnerCourse &&
                        item.course.isActiveInWeek(week),
                    showPhenomenon: settings.weatherShowPhenomenon,
                    showTemperature: settings.weatherShowTemperature,
                    showProbability: settings.weatherShowProbability,
                  ),
                  if (sessionPreview != null && sessionPreview.isNotEmpty) ...[
                    const SizedBox(height: 5.5),
                    _buildCurrentDayAgendaInfoRow(
                      icon: Icons.sticky_note_2_outlined,
                      text: sessionPreview,
                      ink: ink,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayAgendaHomeworkDot() {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.2),
      ),
      alignment: Alignment.center,
      child: const Icon(
        Icons.assignment_outlined,
        size: 11,
        color: HyperosColors.destructive,
      ),
    );
  }

  Widget _buildDayAgendaNoteAction({
    required AppLocalizations l10n,
    required Color ink,
    required VoidCallback onPressed,
  }) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(999),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _dayAgendaInkWash(ink, lightAlpha: 0.16),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: _dayAgendaInkWash(ink, lightAlpha: 0.22),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.sticky_note_2_outlined, size: 14, color: ink),
                const SizedBox(width: 5),
                Text(
                  l10n.courseNoteAction,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: ink,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExamAgendaEntry(
    Exam exam, {
    required TimetableProvider provider,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    // 高斯模糊档下错误红只有 ~42% tint，亮色壁纸会透成浅粉底，写死的
    // 白墨会洗没；与课程/日程卡一致改用自动黑白墨色。
    final ink = _dayAgendaAutoInk(
      colorScheme.error,
      settings: provider.settings,
    );
    final course = provider.getCourseForExam(exam);
    final courseName = course?.name ?? '';
    final location = exam.location ?? course?.location ?? '';
    final daysUntil = exam.daysUntil;
    final countdownText = daysUntil == 0
        ? l10n.examCountdownToday
        : l10n.examCountdownDays(daysUntil);

    return OpenContainer<void>(
      key: ValueKey('day-view-exam-card-${exam.id}'),
      tappable: false,
      transitionType: ContainerTransitionType.fadeThrough,
      transitionDuration: const Duration(milliseconds: 360),
      openColor: theme.scaffoldBackgroundColor,
      closedColor: Colors.transparent,
      closedElevation: 0,
      openElevation: 0,
      closedShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      openShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
      ),
      openBuilder: (context, _) => ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: AddExamScreen(exam: exam),
      ),
      closedBuilder: (context, openContainer) {
        return _dayAgendaSurface(
          settings: provider.settings,
          color: colorScheme.error,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.error,
              Color.lerp(colorScheme.error, colorScheme.errorContainer, 0.25) ??
                  colorScheme.error,
            ],
          ),
          shadow: [
            BoxShadow(
              color: colorScheme.error.withValues(alpha: 0.20),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
          onTap: openContainer,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: _dayAgendaInkWash(ink, lightAlpha: 0.18),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.school_outlined, size: 14, color: ink),
                          const SizedBox(width: 4),
                          Text(
                            l10n.examBadgeLabel,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: _dayAgendaInkWash(ink, lightAlpha: 0.16),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        countdownText,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: ink,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  exam.name,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: ink,
                  ),
                ),
                const SizedBox(height: 3.5),
                if (exam.startTime.isNotEmpty && exam.endTime.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      '${exam.startTime} - ${exam.endTime}',
                      style: TextStyle(
                        fontSize: 13,
                        color: ink.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                if (location.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      location,
                      style: TextStyle(
                        fontSize: 13,
                        color: ink.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                if (courseName.isNotEmpty)
                  Text(
                    courseName,
                    style: TextStyle(
                      fontSize: 12,
                      color: ink.withValues(alpha: 0.7),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildScheduleAgendaEntry(
    _DayAgendaItem agendaItem, {
    required TimetableSettings settings,
  }) {
    final item = agendaItem.scheduleItem!;
    final sourceItem = agendaItem.scheduleInstance?.item ?? item;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final baseColor = _colorFromHex(item.color, colorScheme.primary);
    final cardColor = Color.lerp(baseColor, Colors.black, 0.10) ?? baseColor;
    final l10n = AppLocalizations.of(context)!;
    final hasLocation = item.location?.trim().isNotEmpty == true;
    final hasNote = item.note?.trim().isNotEmpty == true;
    final isCrossDay = item.endDate.isAfter(item.startDate);
    final progressInfo = _resolveScheduleAgendaProgressInfo(item, baseColor);
    // Same auto black/white as course agenda cards (glass over bright mist).
    final ink = _dayAgendaAutoInk(cardColor, settings: settings);

    return OpenContainer<void>(
      key: ValueKey('day-view-schedule-card-${agendaItem.id}'),
      tappable: false,
      transitionType: ContainerTransitionType.fadeThrough,
      transitionDuration: const Duration(milliseconds: 360),
      openColor: theme.scaffoldBackgroundColor,
      closedColor: Colors.transparent,
      closedElevation: 0,
      openElevation: 0,
      closedShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_TimetableScreenState._dayViewCardRadius),
      ),
      openShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
      ),
      openBuilder: (context, _) => ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: AddScheduleItemScreen(
          scheduleItem: sourceItem,
          occurrenceDate: agendaItem.scheduleInstance?.occurrenceDate,
        ),
      ),
      closedBuilder: (context, openContainer) {
        if (progressInfo != null) {
          return Material(
            color: Colors.transparent,
            child: _buildCurrentScheduleAgendaCard(
              item: item,
              agendaItem: agendaItem,
              settings: settings,
              progressInfo: progressInfo,
              l10n: l10n,
              colorScheme: colorScheme,
              ink: ink,
              openContainer: openContainer,
            ),
          );
        }
        return _dayAgendaSurface(
          settings: settings,
          color: cardColor,
          gradient: LinearGradient(colors: [cardColor, cardColor]),
          shadow: [
            BoxShadow(
              color: cardColor.withValues(alpha: 0.20),
              blurRadius: 18,
              offset: const Offset(0, 4),
            ),
          ],
          onTap: openContainer,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: _dayAgendaInkWash(ink, lightAlpha: 0.18),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.event_note_rounded, size: 13, color: ink),
                          const SizedBox(width: 5),
                          Text(
                            '${agendaItem.startTime} - ${agendaItem.endTime}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: ink,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildDayAgendaStatusBadge(
                      text: l10n.scheduleBadgeLabel,
                      textColor: ink,
                      backgroundColor: _dayAgendaInkWash(ink, lightAlpha: 0.18),
                    ),
                    if (isCrossDay)
                      _buildDayAgendaStatusBadge(
                        text: l10n.crossDayBadgeLabel,
                        textColor: ink,
                        backgroundColor: _dayAgendaInkWash(
                          ink,
                          lightAlpha: 0.18,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: ink,
                    fontWeight: FontWeight.w800,
                    height: 1.10,
                  ),
                ),
                if (hasLocation) ...[
                  const SizedBox(height: 10),
                  _buildCurrentDayAgendaInfoRow(
                    icon: Icons.location_on_outlined,
                    text: l10n.locationPrefix(item.location!.trim()),
                    ink: ink,
                  ),
                ],
                if (hasNote) ...[
                  const SizedBox(height: 5.5),
                  _buildCurrentDayAgendaInfoRow(
                    icon: Icons.notes_rounded,
                    text: item.note!.trim(),
                    ink: ink,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCurrentScheduleAgendaCard({
    required ScheduleItem item,
    required _DayAgendaItem agendaItem,
    required TimetableSettings settings,
    required _DayAgendaProgressInfo progressInfo,
    required AppLocalizations l10n,
    required ColorScheme colorScheme,
    required Color ink,
    required VoidCallback openContainer,
  }) {
    final theme = Theme.of(context);
    final hasLocation = item.location?.trim().isNotEmpty == true;
    final hasNote = item.note?.trim().isNotEmpty == true;
    final isCrossDay = item.endDate.isAfter(item.startDate);
    // See _buildCurrentDayAgendaCard: the fill must stay see-through on glass.
    final progressFill =
        effectiveCourseCardSurfaceStyle(
              settings,
              gaussianBlurAvailable: HyperosBlurredHeader.backdropBlurEnabled(
                context,
              ),
            ) ==
            CourseCardSurfaceStyle.solid
        ? progressInfo.fillColor
        : progressInfo.fillColor.withValues(alpha: 0.55);

    return _dayAgendaSurface(
      settings: settings,
      color: progressInfo.baseColor,
      // Flat fill, matching the legacy decoration (no gradient here).
      gradient: LinearGradient(
        colors: [progressInfo.baseColor, progressInfo.baseColor],
      ),
      shadow: [
        BoxShadow(
          color: progressInfo.fillColor.withValues(alpha: 0.18),
          blurRadius: 18,
          offset: const Offset(0, 4),
        ),
      ],
      onTap: openContainer,
      child: ClipRRect(
        key: ValueKey('day-agenda-progress-schedule-card-${item.id}'),
        borderRadius: BorderRadius.circular(_TimetableScreenState._dayViewCardRadius),
        child: Stack(
          children: [
            Positioned.fill(
              // Isolated: the animating fill must not invalidate the card's
              // glass surface / text layers on every animation frame.
              child: RepaintBoundary(
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(
                    end: progressInfo.progress.clamp(0.0, 1.0),
                  ),
                  // Below the 1 s tick so the tween settles between steps
                  // (see _quantizeDayAgendaProgress).
                  duration: const Duration(milliseconds: 600),
                  builder: (context, animatedProgress, child) {
                    return FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: animatedProgress,
                      child: child,
                    );
                  },
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: progressFill,
                      borderRadius: BorderRadius.circular(_TimetableScreenState._dayViewCardRadius),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: _dayAgendaInkWash(ink, lightAlpha: 0.18),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.event_note_rounded,
                              size: 13,
                              color: ink,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              '${agendaItem.startTime} - ${agendaItem.endTime}',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: ink,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _buildDayAgendaStatusBadge(
                        text: progressInfo.statusText,
                        textColor: progressInfo.statusTextColor,
                        backgroundColor: progressInfo.statusBackgroundColor,
                      ),
                      _buildDayAgendaStatusBadge(
                        text: l10n.scheduleBadgeLabel,
                        textColor: ink,
                        backgroundColor: _dayAgendaInkWash(
                          ink,
                          lightAlpha: 0.18,
                        ),
                      ),
                      if (isCrossDay)
                        _buildDayAgendaStatusBadge(
                          text: l10n.crossDayBadgeLabel,
                          textColor: ink,
                          backgroundColor: _dayAgendaInkWash(
                            ink,
                            lightAlpha: 0.18,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: ink,
                      fontWeight: FontWeight.w800,
                      height: 1.10,
                    ),
                  ),
                  if (hasLocation) ...[
                    const SizedBox(height: 10),
                    _buildCurrentDayAgendaInfoRow(
                      icon: Icons.location_on_outlined,
                      text: l10n.locationPrefix(item.location!.trim()),
                      ink: ink,
                    ),
                  ],
                  if (hasNote) ...[
                    const SizedBox(height: 5.5),
                    _buildCurrentDayAgendaInfoRow(
                      icon: Icons.notes_rounded,
                      text: item.note!.trim(),
                      ink: ink,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 日视图日程信息行。实现已提到 [DayAgendaInfoRow]（天气行要复用同一套排版），
  /// 这里保留同名同签名的转发，调用点不必改动。
  Widget _buildCurrentDayAgendaInfoRow({
    required IconData icon,
    required String text,
    required Color ink,
  }) {
    return DayAgendaInfoRow(icon: icon, text: text, ink: ink);
  }

  /// Translucent chip/pill glaze under [ink]-coloured content.
  ///
  /// White ink keeps the legacy white glaze; dark ink flips to a dark glaze —
  /// a white wash under dark text over a bright wallpaper adds no contrast.
  Color _dayAgendaInkWash(Color ink, {required double lightAlpha}) {
    return ink.computeLuminance() > 0.5
        ? Colors.white.withValues(alpha: lightAlpha)
        : Colors.black.withValues(alpha: lightAlpha * 0.55);
  }

  _DayAgendaProgressInfo? _resolveDayAgendaProgressInfo(
    Course course, {
    required _DayAgendaPalette palette,
  }) {
    final now = DateTime.now();
    final startMinutes = _parseDayAgendaClockMinutes(course.startTime);
    final endMinutes = _parseDayAgendaClockMinutes(course.endTime);
    if (startMinutes == null ||
        endMinutes == null ||
        endMinutes <= startMinutes) {
      return null;
    }
    final currentMinutes =
        now.hour * 60 +
        now.minute +
        (now.second / 60) +
        (now.millisecond / 60000);
    if (currentMinutes < startMinutes || currentMinutes >= endMinutes) {
      return null;
    }
    final elapsedMinutes = currentMinutes - startMinutes;
    final totalMinutes = endMinutes - startMinutes;
    final remainingMinutes = math.max(0, (endMinutes - currentMinutes).ceil());
    final progress = _TimetableScreenState._quantizeDayAgendaProgress(elapsedMinutes / totalMinutes);
    final isEndingSoon = remainingMinutes <= 10;
    return _DayAgendaProgressInfo(
      progress: progress,
      remainingMinutes: remainingMinutes,
      statusText: isEndingSoon
          ? AppLocalizations.of(
              context,
            )!.dayAgendaEndingSoonStatus(remainingMinutes)
          : AppLocalizations.of(
              context,
            )!.dayAgendaInProgressStatus(remainingMinutes),
      statusBackgroundColor: Colors.white,
      statusTextColor: isEndingSoon
          ? HyperosColors.destructive
          : palette.fillColor,
      baseColor: palette.baseColor,
      fillColor: palette.fillColor,
    );
  }

  _DayAgendaProgressInfo? _resolveScheduleAgendaProgressInfo(
    ScheduleItem item,
    Color background,
  ) {
    final now = DateTime.now();
    final start = _buildScheduleDateTime(item.startDate, item.startTime);
    final end = _buildScheduleDateTime(item.endDate, item.endTime);
    if (start == null || end == null || !end.isAfter(start)) {
      return null;
    }
    if (now.isBefore(start) || !now.isBefore(end)) {
      return null;
    }

    final fillColor = Color.lerp(background, Colors.black, 0.18) ?? background;
    final baseColor = Color.lerp(fillColor, Colors.white, 0.10) ?? fillColor;
    final elapsedMinutes = now.difference(start).inMilliseconds / 60000;
    final totalMinutes = end.difference(start).inMilliseconds / 60000;
    final remainingMinutes = math.max(
      0,
      end.difference(now).inMinutes +
          (end.difference(now).inSeconds % 60 > 0 ? 1 : 0),
    );
    final progress = _TimetableScreenState._quantizeDayAgendaProgress(elapsedMinutes / totalMinutes);
    final isEndingSoon = remainingMinutes <= 10;

    return _DayAgendaProgressInfo(
      progress: progress,
      remainingMinutes: remainingMinutes,
      statusText: isEndingSoon
          ? AppLocalizations.of(
              context,
            )!.scheduleAgendaEndingSoonStatus(remainingMinutes)
          : AppLocalizations.of(
              context,
            )!.scheduleAgendaInProgressStatus(remainingMinutes),
      statusBackgroundColor: Colors.white,
      statusTextColor: isEndingSoon ? HyperosColors.destructive : fillColor,
      baseColor: baseColor,
      fillColor: fillColor,
    );
  }

  DateTime? _buildScheduleDateTime(DateTime date, String clock) {
    final minutes = _parseDayAgendaClockMinutes(clock);
    if (minutes == null) {
      return null;
    }
    return DateTime(
      date.year,
      date.month,
      date.day,
      minutes ~/ 60,
      minutes % 60,
    );
  }

  int? _parseDayAgendaClockMinutes(String value) {
    final parts = value.split(':');
    if (parts.length != 2) {
      return null;
    }
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) {
      return null;
    }
    return hour * 60 + minute;
  }

  _DayAgendaPalette _resolveDayAgendaPalette(
    Color background, {
    String? foregroundHex,
    TimetableSettings? settings,
  }) {
    // Keep pastel import colors light; only a tiny white lift for depth.
    final fillColor = background;
    final baseColor = Color.lerp(fillColor, Colors.white, 0.06) ?? fillColor;
    final customInk = foregroundHex == null || foregroundHex.trim().isEmpty
        ? null
        : _colorFromHex(foregroundHex, Colors.white);
    // 自定义字色（导入/LAN 同步携带）在实心卡面上做可读性兜底：与卡色
    // 同色系时（如蓝字配蓝卡）替换为黑白最优墨色。玻璃档按壁纸亮度走玻璃
    // 规则（彩色墨回落自动黑白、中性墨对比度门槛），与 CourseCard 行为
    // 一致；壁纸亮度未知时保留用户选择。
    final showsWallpaper =
        settings != null &&
        courseCardSurfaceShowsWallpaper(
          effectiveCourseCardSurfaceStyle(
            settings,
            gaussianBlurAvailable: HyperosBlurredHeader.backdropBlurEnabled(
              context,
            ),
          ),
        );
    final foregroundColor = customInk == null
        ? _dayAgendaAutoInk(fillColor, settings: settings)
        : resolveReadableCourseCardTitleColor(
            preferred: customInk,
            cardColor: fillColor,
            surfaceShowsWallpaper: showsWallpaper,
            wallpaperLuminance: showsWallpaper
                ? (_wallpaperBodyLuminance ?? _wallpaperTopLuminance)
                : null,
          );
    return _DayAgendaPalette(
      baseColor: baseColor,
      fillColor: fillColor,
      foregroundColor: foregroundColor,
    );
  }

  /// Default agenda-card ink when the course has no custom text colour.
  ///
  /// Opaque styles keep the legacy white-on-hue. The gaussian style shows
  /// mostly wallpaper through a ~40% tint, so the ink flips black/white against
  /// the blend of course hue and the wallpaper band behind the cards — a bright
  /// wallpaper region otherwise gives white-on-white.
  Color _dayAgendaAutoInk(Color fill, {TimetableSettings? settings}) {
    if (settings == null) {
      return Colors.white;
    }
    final glassOverWallpaper = effectiveCourseCardSurfaceStyle(
      settings,
      gaussianBlurAvailable: HyperosBlurredHeader.backdropBlurEnabled(context),
    ).isGlass;
    if (!glassOverWallpaper) {
      return Colors.white;
    }
    final wallpaperLuminance =
        _wallpaperBodyLuminance ?? _wallpaperTopLuminance;
    if (wallpaperLuminance == null) {
      return Colors.white;
    }
    final effectiveLuminance =
        fill.computeLuminance() * 0.5 + wallpaperLuminance * 0.5;
    return homePageChromeForegroundForLuminance(
      effectiveLuminance,
      fallback: Colors.white,
    );
  }

  Widget _buildDayAgendaStatusBadge({
    required String text,
    required Color textColor,
    required Color backgroundColor,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.labelSmall?.copyWith(
          color: textColor,
          fontWeight: FontWeight.w400,
          fontSize: 10.5,
          height: 1,
        ),
      ),
    );
  }

}