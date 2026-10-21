part of 'timetable_screen.dart';

/// 日视图议程族（2026-10-10 自 `timetable_screen.dart` 原样搬入）。
///
/// `_TimetableScreenState` 的成员扩展：相关字段与 `TimetableDayAgendaItem` 等数据类
/// 仍在主文件。
///
/// 2026-10-20：**视图构建已从本分片搬进 `lib/widgets/timetable/day_view/` 的
/// 独立库**（摘要卡 / 空态 / 课程卡 / 考试卡 / 日程卡 / 卡面与徽标部件），本分片
/// 只保留 State 胶水：
/// - 数据组装：当日课程 → `DayCourseDisplayItem` → 议程条目混排（`_buildDayAgendaItems`）；
/// - 依赖 State 私有状态的判定：壁纸亮度快照（[_dayViewInkEnvironment]）、
///   进行时进度与调色板（要主文件的 `_quantizeDayAgendaProgress` 与 `_luminance`）；
/// - 导航动作：关闭日视图、课程操作面板、日程/考试编辑页（展开动作仍在卡片里，
///   但入口回调与返回语义由这里给）。
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
                    _dayPagerFlickProbes[event.pointer] = TimetableDayPagerFlickProbe(
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
    // 待办带只算一次：摘要卡的作业计数与列表里那条带子必须同源，
    // 各算一遍就会漂（卡片说 3 项、滚下去只有 2 条）。
    if (_TimetableScreenState.logDayViewBuilds) {
      debugPrint(
        '[DayView] page=$page items: courses=${displayItems.length} '
        'agenda=${agendaItems.length} schedule=${scheduleItems.length}',
      );
    }
    final isActivePage =
        target.week == _selectedWeekForDayView &&
        target.dayOfWeek == _selectedDayOfWeek;
    // 摘要卡吸顶 + 内容同一条滚动体（见 [TimetableDayViewScrollShell]）。
    final key = ValueKey('day-content-${target.week}-${target.dayOfWeek}');
    final scrollKey = _TimetableScreenState._dayAgendaScrollKey(
      target.week,
      target.dayOfWeek,
    );
    return TimetableDayViewScrollShell(
      contentKey: key,
      columnKey: ValueKey('day-column-${target.week}-${target.dayOfWeek}'),
      scrollKey: scrollKey,
      controller: _previewControllerFor(scrollKey),
      physics: _homePullVerticalPhysics,
      settings: settings,
      reportScroll: _reportHomeScroll,
      summary: _buildDayViewSummary(
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
        taskCount: _buildDayTaskBand(
          provider, settings, target.week, target.dayOfWeek).actionableCount,
      ),
      slivers: _buildDayAgendaSlivers(
        provider: provider, settings: settings,
        week: target.week, dayOfWeek: target.dayOfWeek,
      ),
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

  List<TimetableDayAgendaItem> _buildDayAgendaItems({
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
    final items = <TimetableDayAgendaItem>[
      ...courseItems.map(TimetableDayAgendaItem.course),
      ..._getScheduleItemsForWeekDay(
        provider: provider,
        settings: settings,
        week: week,
        dayOfWeek: dayOfWeek,
      ).map(
        (instance) => TimetableDayAgendaItem.scheduleForDate(
          instance: instance,
          targetDate: targetDate,
        ),
      ),
      ...provider.exams
          .where((e) => !e.isExpired && _isSameDate(e.dateTime, targetDate))
          .map(TimetableDayAgendaItem.exam),
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

  /// 待办带：目标日期与 _buildDayAgendaItems 同一条解析（翻到别的周时，
  /// 课程按 A 日、作业按 B 日就错了）。
  DayTaskBandData _buildDayTaskBand(TimetableProvider p, TimetableSettings s, int w, int d) =>
      DayTaskBandLogic.resolve(tasks: p.tasks, date: _resolveDisplayDateForWeekDay(provider: p, settings: s, week: w, dayOfWeek: d));
  /// 壁纸亮度 / 模糊管线快照（日视图 view 库判墨与判材质要用）。
  ///
  /// 只有 State 拿得到这三条亮度带（`WallpaperLuminanceController`）；搬到独立
  /// widget 后由这里取一次传下去，view 层不反向读 State、也不读 provider。
  ///
  /// [DayViewInkEnvironment.profile] / [DayViewInkEnvironment.screenHeight] 是
  /// 2026-10-21 新增的：有了逐行剖面，每张卡才能按**自己压在哪一行**判黑白，
  /// 而不是吃整屏一个平均值（两张真机截图因此判错字色）。
  DayViewInkEnvironment _dayViewInkEnvironment(TimetableSettings settings) {
    return DayViewInkEnvironment(
      backdropBlurOn: HyperosBlurredHeader.backdropBlurEnabled(context),
      wallpaperBodyLuminance: _luminance.body,
      wallpaperTopLuminance: _luminance.top,
      wallpaperWeekdayInkLuminance: _luminance.weekdayInk(settings),
      profile: _luminance.profile,
      screenHeight: MediaQuery.sizeOf(context).height,
    );
  }

  /// 日视图顶部摘要卡的 State 胶水：取数 + 日期格式化 + 判墨环境。
  ///
  /// 卡片本体在 [TimetableDayViewSummaryCard]（`widgets/timetable/day_view/`）。
  /// 当日考试排序留在这里：钟点字段的字典序比较只允许出现在主文件 / 本分片
  /// （见 `test/architecture/clock_field_compare_guard_test.dart`），排好的列表
  /// 作为参数交给卡片，卡片自己不再排序。
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
    required List<TimetableDayAgendaItem> agendaItems,
    required int taskCount,
  }) {
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
    final isToday = _isSelectedDayToday(
      provider: provider,
      settings: settings,
      week: week,
      dayOfWeek: dayOfWeek,
    );
    return MeasuredScreenRect(
      builder: (context, rect) => TimetableDayViewSummaryCard(
        surfaceKey: key,
        settings: settings,
        week: week,
        dateLabel: dateLabel,
        isToday: isToday,
        currentCourse: currentCourse,
        courseItems: courseItems,
        scheduleItems: scheduleItems,
        agendaItems: agendaItems,
        dayExams: dayExams,
        taskCount: taskCount,
        inkEnvironment: _dayViewInkEnvironment(settings),
        cardRect: rect,
        radius: _TimetableScreenState._dayViewCardRadius,
        onClose: () => _closeDayView(settings),
        // 情侣空闲摘要要读 State 的展开态、又要用摘要卡算出的墨色：给一个
        // 「给墨色、还我 widget」的回调，卡片只负责摆位置。浮层未启用时传 null。
        sharedFreeSummaryBuilder: _isCoupleOverlayActive(provider)
            ? (ink) => _buildDayViewSharedFreeSummary(
                provider: provider,
                settings: settings,
                week: week,
                dayOfWeek: dayOfWeek,
                isToday: isToday,
                ink: ink,
              )
            : null,
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

  String _formatDayViewSummaryDate(
    DateTime date, {
    required int dayOfWeek,
    required String localeName,
  }) {
    final formattedDate = DateFormat.MMMd(localeName).format(date);
    return '$formattedDate ${_weekdayLabel(context, dayOfWeek)}';
  }

  /// 当日议程的 sliver 列表（2026-10-21 由 `_buildExpandedDayColumnView` 改来，
  /// 不再自带滚动体；滚动 key/controller/physics 上移到调用方）。
  List<Widget> _buildDayAgendaSlivers({
    required TimetableProvider provider,
    required TimetableSettings settings,
    required int week,
    required int dayOfWeek,
  }) {
    final courses = _getCoursesForDay(provider.courses, week, dayOfWeek, settings);
    final isToday = _isSelectedDayToday(
      provider: provider, settings: settings, week: week, dayOfWeek: dayOfWeek);
    final currentCourseIds = isToday
        ? provider
              .getCoursesInProgress(dayOfWeek: dayOfWeek, week: week)
              .map((course) => course.id)
              .toSet()
        : const <String>{};
    final displayItems = _buildHomeDayDisplayItems(
      provider: provider, settings: settings, week: week,
      dayOfWeek: dayOfWeek, myCourses: courses,
      currentCourseIds: currentCourseIds,
    );
    final agendaItems = _buildDayAgendaItems(
      provider: provider, settings: settings, week: week,
      dayOfWeek: dayOfWeek, courseItems: displayItems,
    );
    final taskBand = _buildDayTaskBand(provider, settings, week, dayOfWeek);
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
    // 空态是居中块：浮钮避让带上它会让"今天 ↔ 非今天"换位置、文字跳一下
    //（2026-09-29 真机反馈），所以空态只留药丸避让。
    final emptyBottomContentInset = 8 + dockScrollAvoidance;
    // 待办带是第 0 项、跟着滚走（钉住会让一天八条作业永久吃掉半屏）；为空时整条不渲染。
    final bandCount = taskBand.isEmpty ? 0 : 1;
    if (agendaItems.isEmpty && bandCount == 0) {
      return <Widget>[
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(14, 0, 14, emptyBottomContentInset),
            child: _buildDayViewEmptyColumn(week: week, settings: settings),
          ),
        ),
      ];
    }
    return <Widget>[
      SliverPadding(
        // 左右 14 与改前一致；底距 = 玻璃坞 + 回今日浮钮的滚动余量。
        padding: EdgeInsets.fromLTRB(14, 0, 14, listBottomContentInset),
        sliver: SliverList.separated(
          itemCount: bandCount + agendaItems.length,
          separatorBuilder: (context, index) => const SizedBox(height: 8),
          itemBuilder: (context, itemIndex) {
            if (bandCount == 1 && itemIndex == 0) {
              return MeasuredScreenRect(
                builder: (context, rect) => DayViewTaskBand(
                  data: taskBand,
                  settings: settings,
                  inkEnvironment: _dayViewInkEnvironment(settings),
                  cardRect: rect,
                  radius: _TimetableScreenState._dayViewCardRadius,
                  courseResolver: provider.getCourseForTask,
                  onToggleCompleted: (task) => toggleTaskFromBand(
                      context, provider.toggleTaskCompleted, task.id),
                  taskFormBuilder: (task) =>
                      timetableFormPages.taskForm(task: task),
                ),
              );
            }
            final item = agendaItems[itemIndex - bandCount];
            final entry = MeasuredScreenRect(
              builder: (context, rect) => _buildDayAgendaEntry(
                provider: provider,
                week: week,
                settings: settings,
                item: item,
                cardRect: rect,
              ),
            );
            // 飞行终点：议程卡真实屏幕矩形（不量化、只量一次；量化过的终点会让卡片落地偏几像素）
            final courseId = item.courseItem?.course.id;
            return courseId == null
                ? entry
                : MeasureFlightTarget(
                    onMeasured: (r) {
                      // 写缓存本身不触发重建，而转场壳是在 build 期间读它的
                      // —— 不主动标记一次，终点永远不会生效（飞行卡不出现）。
                      // 这里已经过了首帧多个帧，且只在「真正拿到新值」时置脏，
                      // 不会变成每帧重建。
                      final changed = _flightTargets.record(courseId, r);
                      if (changed && mounted) {
                        // extension 里不能直接 setState（protected），走宿主的
                        // 端口（`setStateMutations` 内部就是判 mounted 后 setState）。
                        rebuild();
                      }
                    },
                    child: entry,
                  );
          },
        ),
      ),
    ];
  }

  Widget _buildDayViewEmptyColumn({


    required int week,
    required TimetableSettings settings,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
      child: TimetableDayViewEmptyState(
        week: week,
        settings: settings,
        inkEnvironment: _dayViewInkEnvironment(settings),
      ),
    );
  }

  /// 飞行卡（转场中那一张）：**颜色与材质与议程卡同源**。
  ///
  /// 用户 2026-10-21 报：「动画过程中的卡片颜色和课程卡片颜色不一样，材质不一样」。
  /// 根因是飞行卡另走了一条取色路径（`resolveDisplayCourseColor`）并强制实体材质，
  /// 而议程卡走的是 `resolveDayAgendaPalette` + 用户设置的材质档。
  ///
  /// 这里改成与议程卡**同一个** `resolveDayAgendaPalette`：飞行终点就是议程卡，
  /// 同源才能读成「同一张卡在长大」。
  Widget _buildFlightCardFor(
    TimetableProvider provider,
    TimetableSettings settings,
    List<Course> dayCourses,
    String courseId,
    double t,
  ) {
    final course = dayCourses.where((c) => c.id == courseId).firstOrNull;
    if (course == null) {
      return const SizedBox.shrink();
    }
    final item = DayCourseDisplayItem(course: course);
    final palette = resolveDayAgendaPalette(
      _colorFromHex(resolveDisplayCourseColor(item, settings: settings,
            coupleColorForKind: provider.coupleColorForKind) ?? course.color, Theme.of(context).colorScheme.primary),
      foregroundHex: course.textColor,
      settings: settings,
      env: _dayViewInkEnvironment(settings),
      washAlpha: dayAgendaWashAlpha(context, settings),
    );
    return FlightCardBody(course: course, settings: settings, progress: t,
      color: palette.fillColor);
  }

  /// 日视图议程条目路由：考试 / 日程 / 课程三种卡片的数据组装与动作接线。
  ///
  /// 卡片本体的 widget 树在 `widgets/timetable/day_view/` 下；这里只做
  /// 「取数 → 算调色板/进度 → 传回调」：
  /// - 课程：`_resolveDisplayCourseColor` + 调色板（要 State 的壁纸亮度），
  ///   播放中再算一次进度（要主文件的进度量化）；对方课程点击走课程操作面板。
  /// - 考试：关联课程由 provider 解析后传入（卡片只做展示）。
  /// - 日程：底色在这里解析（进度调理也用同一个），编辑页由卡片自己开。
  Widget _buildDayAgendaEntry({
    required TimetableProvider provider,
    required int week,
    required TimetableSettings settings,
    required TimetableDayAgendaItem item,
    Rect? cardRect,
  }) {
    if (item.isExam) {
      if (_TimetableScreenState.logDayViewBuilds) {
        debugPrint('[DayView] build agenda entry: exam id=${item.exam?.id}');
      }
      return TimetableDayExamAgendaCard(
        exam: item.exam!,
        settings: settings,
        linkedCourse: provider.getCourseForExam(item.exam!),
        inkEnvironment: _dayViewInkEnvironment(settings),
        cardRect: cardRect,
        radius: _TimetableScreenState._dayViewCardRadius,
      );
    }
    if (item.isScheduleItem) {
      if (_TimetableScreenState.logDayViewBuilds) {
        debugPrint(
          '[DayView] build agenda entry: schedule id=${item.scheduleItem?.id}',
        );
      }
      final scheduleItem = item.scheduleItem!;
      final baseColor = _colorFromHex(
        scheduleItem.color,
        Theme.of(context).colorScheme.primary,
      );
      return TimetableDayScheduleAgendaCard(
        agendaItem: item,
        settings: settings,
        baseColor: baseColor,
        progressInfo: _resolveScheduleAgendaProgressInfo(
          scheduleItem,
          baseColor,
        ),
        inkEnvironment: _dayViewInkEnvironment(settings),
        cardRect: cardRect,
        radius: _TimetableScreenState._dayViewCardRadius,
      );
    }

    final courseItem = item.courseItem!;
    if (_TimetableScreenState.logDayViewBuilds) {
      debugPrint(
        '[DayView] build agenda entry: course id=${courseItem.course.id} '
        'name=${courseItem.course.name}',
      );
    }
    final colorHex = _resolveDisplayCourseColor(courseItem, settings: settings);
    final resolvedColor = _colorFromHex(
      colorHex ?? courseItem.course.color,
      Colors.blue,
    );
    final palette = resolveDayAgendaPalette(
      resolvedColor,
      foregroundHex: courseItem.course.textColor,
      settings: settings,
      env: _dayViewInkEnvironment(settings),
      cardRect: cardRect,
      // 真实染色比例从这里（拿得到 context）算，与 `CourseSurface` 渲染同源：
      // 判色若用出厂常数，用户把染色拖薄后会把卡面判得比实际亮得多。
      washAlpha: dayAgendaWashAlpha(context, settings),
    );
    return TimetableDayCourseAgendaCard(
      item: courseItem,
      week: week,
      settings: settings,
      provider: provider,
      palette: palette,
      progressInfo: courseItem.isCurrentCourse
          ? _resolveDayAgendaProgressInfo(courseItem.course, palette: palette)
          : null,
      inkEnvironment: _dayViewInkEnvironment(settings),
      radius: _TimetableScreenState._dayViewCardRadius,
      courseDate: _dateForWeekDay(settings, week, courseItem.course.dayOfWeek),
      onOpenCourseActions: () {
        _showCourseActions(courseItem.course, week, displayItem: courseItem);
      },
    );
  }


  TimetableDayAgendaProgressInfo? _resolveDayAgendaProgressInfo(
    Course course, {
    required TimetableDayAgendaPalette palette,
  }) {
    final now = DateTime.now();
    final startMinutes = clockTextToMinutes(course.startTime);
    final endMinutes = clockTextToMinutes(course.endTime);
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
    return TimetableDayAgendaProgressInfo(
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

  TimetableDayAgendaProgressInfo? _resolveScheduleAgendaProgressInfo(
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

    return TimetableDayAgendaProgressInfo(
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
    final minutes = clockTextToMinutes(clock);
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

}
