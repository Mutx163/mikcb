import 'package:uuid/uuid.dart';

import '../domain/course_domain.dart';
import '../models/course.dart';
import '../models/timetable_settings.dart';
import '../providers/timetable_provider.dart';
import '../utils/clock_time.dart';
import '../utils/course_color_palette.dart';
import 'lan_edit_host.dart';
import 'spreadsheet_import_service.dart';
import 'transfer_package.dart';
import 'unified_transfer_service.dart';
import 'week_expression_parser.dart';

/// Bridges [TimetableProvider] to [LanEditHost] for LAN HTTP handlers.
class LanEditProviderHost implements LanEditHost, LanTransferHost {
  final TimetableProvider _provider;
  final UnifiedTransferService _transferService = UnifiedTransferService();

  LanEditProviderHost(this._provider);

  static const String defaultLanCourseColor = '#2196F3';
  static final RegExp _lanCourseColorPattern = RegExp(r'^#?([0-9a-fA-F]{6})$');

  /// Restricts LAN-provided course colors to the hex format used by the app.
  ///
  /// LAN data is eventually rendered by the browser, so accepting arbitrary
  /// CSS values here would turn a presentation field into an HTML sink. A
  /// safe default also repairs legacy values when a course is edited.
  static String normalizeLanCourseColor(Object? rawColor) {
    if (rawColor is! String) {
      return defaultLanCourseColor;
    }
    final trimmedColor = rawColor.trim();
    final match = _lanCourseColorPattern.firstMatch(trimmedColor);
    if (match == null) {
      return defaultLanCourseColor;
    }
    return '#${match.group(1)!.toUpperCase()}';
  }

  /// 客户端自带的 id：只在是**非空字符串**时才采用。
  /// 空白 id 造出的行无法被 `/api/v1/courses/{id}` 寻址（路由段正则
  /// `([^/]+)` 匹配不到空串），非字符串 id 则会让整条请求 500。
  static String? _suppliedCourseId(Object? rawId) {
    if (rawId is! String) {
      return null;
    }
    final trimmed = rawId.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  /// 客户端送来的钟点必须是可解析的 `H:MM`，否则回落模板值。
  ///
  /// 表单清空时间、或送来 `25:00` 这类越界值时不能直接落库：`Course.startTime`
  /// 全仓按 `HH:MM` 解析（原生侧同样），而越界串会被
  /// `DateTime(y,m,d,hour,minute)` 静默归一到别的日子。规范化用
  /// [ClockTime.formatted]，于是 `8:00` 与模板的 `08:00` 能正确判等。
  static String _usableClockText(Object? rawTime, String fallback) {
    final parsed = ClockTime.tryParse(
      rawTime is String ? rawTime : null,
      allowEndOfDay: true,
    );
    return parsed?.formatted ?? fallback;
  }

  /// Removes unsafe colors from both top-level and profile-scoped transfers.
  static TransferPackage normalizeTransferCourseColors(
    TransferPackage package,
  ) {
    Course normalizeCourse(Course course) {
      return course.copyWith(color: normalizeLanCourseColor(course.color));
    }

    return package.copyWith(
      courses: package.courses.map(normalizeCourse).toList(growable: false),
      profiles: package.profiles
          .map(
            (profile) => profile.copyWith(
              courses: profile.courses
                  .map(normalizeCourse)
                  .toList(growable: false),
            ),
          )
          .toList(growable: false),
    );
  }

  @override
  Future<void> ensureInitialized() => _provider.initialize();

  @override
  String? get activeProfileId => _provider.activeProfile?.id;

  @override
  String? get activeProfileName => _provider.activeProfile?.name;

  @override
  List<Map<String, dynamic>> listProfilesSummary() {
    final activeId = _provider.activeProfile?.id;
    return _provider.profiles
        .where((profile) => !profile.isPartnerImported)
        .map(
          (profile) => <String, dynamic>{
            'id': profile.id,
            'name': profile.name,
            'courseCount': profile.courses.length,
            'currentWeek': profile.currentWeek,
            'isActive': profile.id == activeId,
          },
        )
        .toList(growable: false);
  }

  @override
  Future<void> switchProfile(String profileId) async {
    final trimmedId = profileId.trim();
    if (trimmedId.isEmpty) {
      throw ArgumentError('profile_id_required');
    }
    final exists = _provider.profiles.any(
      (profile) => profile.id == trimmedId && !profile.isPartnerImported,
    );
    if (!exists) {
      throw ArgumentError('profile_not_found');
    }
    await _provider.switchProfile(trimmedId);
    if (_provider.activeProfile?.id != trimmedId) {
      throw ArgumentError('profile_switch_failed');
    }
  }

  @override
  int get currentWeek => _provider.currentWeek;

  @override
  TimetableSettings get timetableSettings => _provider.settings;

  @override
  int get semesterWeekCount => _provider.settings.semesterWeekCount;

  @override
  List<Course> get courses => _provider.courses;

  @override
  Course? findCourse(String id) {
    for (final course in _provider.courses) {
      if (course.id == id) {
        return course;
      }
    }
    return null;
  }

  /// 局域网客户端可以自带课程 id（网页端用 `crypto.randomUUID()` 预生成，
  /// 好在一次批量编辑里按 id 引用同一门课）。但 id 是本机的行标识，
  /// 让外部值直接落地有两个可观察后果：`addCourse` 不查重复，于是同一 id
  /// 出现两行，而 `deleteCourse` 用 `removeWhere` —— 删一次掉两行、
  /// 批量删除的计数却只加 1；空 id 更糟，`/api/v1/courses/([^/]+)` 永远
  /// 寻址不到它，PATCH 只会命中第一条同 id 的课。
  /// 这里保留"客户端可指定新 id"的能力，只拒绝撞车与空值（400）。
  void _rejectIdConflict(String id) {
    final trimmed = id.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('course_id_required');
    }
    if (findCourse(trimmed) != null) {
      throw ArgumentError('course_id_conflict');
    }
  }

  @override
  Future<Course> createCourse(Course draft) async {
    // 撞车检查与插入必须在**同一次持锁**里：`_rejectIdConflict` 读的是
    // `_provider.courses`，而锁原先在 `addCourse` 里才拿 —— 两个标签页同时新建
    // 同一个 id 时双双通过检查，造出两行同 id（删除按 id 等值摘除 ⇒ 删一次掉两行）。
    // 形状与 `mutateCourse`（:198-217）一致：`runMutationExclusive` 对同区可重入，
    // 所以回调里继续用 `addCourse` 不会被自己挡住。
    return _provider.runMutationExclusive(() async {
      _rejectIdConflict(draft.id);
      await _provider.addCourse(draft);
      return _provider.courses.firstWhere(
        (course) => course.id == draft.id,
        orElse: () => draft,
      );
    });
  }

  @override
  Future<void> updateCourse(Course course) async {
    await _provider.updateCourse(course);
    // provider.updateCourse 对找不到的 id 是**静默 return**
    // （`timetable_provider.dart:2592-2593` 的 `if (index != -1)`，
    // 返回类型 Future<void>，没有错误通道）。触发路径：手机停在编辑页时
    // 另一台设备把这门课删了，或一次「覆盖」导入重建了 id ——
    // 于是 PATCH 什么都没改，HTTP 却回 200 并把请求体原样回显，
    // 浏览器显示"已保存"、手机上一切如旧。
    // 写入是否落地用事后置条件判，不去动上帝类的返回类型。
    if (findCourse(course.id) == null) {
      throw StateError('course_not_found');
    }
  }

  @override
  Future<Course?> mutateCourse(
    String courseId,
    Future<Course> Function(Course existing) mutate,
  ) {
    // 基线在门内读，覆盖写也在门内完成：`runMutationExclusive` 对同区是重入的，
    // 所以回调里继续用 `updateCourse`（含它的事后置条件）不会被自己挡住。
    return _provider.runMutationExclusive(() async {
      final existing = findCourse(courseId);
      if (existing == null) {
        return null;
      }
      final updated = await mutate(existing);
      // 写也放在这里做，而不是交给回调：读-改-写三段必须在同一次持锁里，
      // 且回调只负责"算出新值"。让回调自己写，漏写一次就变成"返回了却什么都没落"
      // 的静默失败（本仓第一轮写这版时就是这样，被 `lan_edit_patch_lock_test` 的
      // "网页改的老师"断言当场抓到）。
      await updateCourse(updated);
      return updated;
    });
  }

  @override
  Future<void> deleteCourse(String courseId) async {
    await _provider.deleteCourse(courseId);
  }

  @override
  Future<int> deleteCoursesBatch(List<String> courseIds) async {
    var removed = 0;
    for (final id in courseIds) {
      if (findCourse(id) == null) {
        continue;
      }
      await _provider.deleteCourse(id);
      removed += 1;
    }
    return removed;
  }

  @override
  Future<List<Course>> replaceCourseGroup({
    required String? originalName,
    required List<Course> slots,
  }) async {
    if (slots.isEmpty) {
      throw ArgumentError('at_least_one_schedule_slot');
    }
    final trimmedOriginal = originalName?.trim();
    // 请求内自查（同 id 两个 slot）+ 查库 + 写库三段必须在**同一次持锁**里完成
    // （2026-10-08 收口）。原先 `ownedIds` 是裸读 `_provider.courses`，锁要到
    // `updateCourseGroup` / `addCourseGroup` 里才拿：另一个标签页（或本机别处的写）
    // 落在「已读完、未加锁」这个窗口里，两边都判「不冲突」，于是同 id 两行、
    // 删一次掉两行。形状与 `mutateCourse`（:198-217）同一份判据。
    return _provider.runMutationExclusive(() async {
      // 同一请求里两个 slot 用同一个 id 也要拦：`_rejectIdConflict` 只查
      // 「库里有没有」，两个新 id 互相撞它一条都看不见（两道检查原本都漏这一维）。
      final seen = <String>{};
      for (final slot in slots) {
        if (!seen.add(slot.id.trim())) {
          throw ArgumentError('course_id_conflict');
        }
      }
      if (trimmedOriginal == null || trimmedOriginal.isEmpty) {
        // 新建分组：整组都是插入，id 撞车同样会造出重复行。
        for (final slot in slots) {
          _rejectIdConflict(slot.id);
        }
        await _provider.addCourseGroup(slots);
      } else {
        // 改组分支同样要撞车检查：slot 可以把 id 写成**另一门不相干课程**的 id，
        // 整组替换后就出现两行同 id —— 删除按 id 等值摘除，"删一次掉两行"，
        // 与新建分支拒绝的是同一件事。
        // 属于本组自己的 id 不算冲突（改课次、改组名都沿用原 id）。
        final groupKey = buildSharedCourseNameKey(trimmedOriginal);
        final ownedIds = <String>{
          for (final course in _provider.courses)
            if (buildSharedCourseNameKey(course.name) == groupKey) course.id,
        };
        for (final slot in slots) {
          if (!ownedIds.contains(slot.id)) {
            _rejectIdConflict(slot.id);
          }
        }
        await _provider.updateCourseGroup(trimmedOriginal, slots);
      }
      return slots;
    });
  }

  /// 局域网会话只绑定一个课表档（`_ensureWriteProfileTarget` 逐请求校验），
  /// 所以整设备作用域的包在这里永远不该出现。
  ///
  /// 原先只拦 `profiles 非空` 的 all_data：把手里的 `/api/v1/profile/active`
  /// 包改个 `scope` 并把 `profiles` 留空就能绕过，而
  /// `UnifiedTransferService._replaceRulesAndLocations` 判的是
  /// `incoming.scope == TransferScope.allData`（不看数组是否为空），
  /// 于是一次 200 applied 的覆盖导入把**全设备**的地点分组与日期规则清空，
  /// 连带 `resync: true` 改写了这台机器上其他课表档的上课钟点 ——
  /// 那些档在 `listProfilesSummary` 里是隐藏的，配对端根本看不见。
  /// 全量备份（`backupType: 'full'`）与带档的 all_data 一起拒，
  /// 让用户改用「导入课表档」而不是整设备覆盖。
  void _rejectWholeDeviceWrite(TransferPackage incoming) {
    if (incoming.isFullBackup || incoming.scope == TransferScope.allData) {
      throw const FormatException('use_profile_backup_not_full');
    }
  }

  @override
  String buildProfileBackupJson() {
    return _transferService
        .buildCurrentPackage(provider: _provider, channel: TransferChannel.lan)
        .encode();
  }

  @override
  LanTransferPreview? previewTransferJson(String content) {
    final incoming = normalizeTransferCourseColors(
      _transferService.parseCompatible(content, channel: TransferChannel.lan),
    );
    _rejectWholeDeviceWrite(incoming);
    final current = _transferService.buildCurrentPackage(
      provider: _provider,
      channel: TransferChannel.lan,
    );
    return LanTransferPreview(
      incoming: incoming,
      mergeDiff: _transferService.preview(
        current: current,
        incoming: incoming,
      ),
      overwriteDiff: _transferService.preview(
        current: current,
        incoming: incoming,
        mode: TransferApplyMode.overwrite,
      ),
    );
  }

  @override
  Future<TransferApplyResult> applyTransferJson(
    String content, {
    required TransferApplyMode mode,
  }) async {
    final incoming = normalizeTransferCourseColors(
      _transferService.parseCompatible(content, channel: TransferChannel.lan),
    );
    _rejectWholeDeviceWrite(incoming);
    return _transferService.applyToProvider(
      provider: _provider,
      incoming: incoming,
      mode: mode,
    );
  }

  @override
  Future<void> importProfileBackupJson(String content) async {
    final incoming = normalizeTransferCourseColors(
      _transferService.parseCompatible(content, channel: TransferChannel.lan),
    );
    _rejectWholeDeviceWrite(incoming);
    final result = await _transferService.applyToProvider(
      provider: _provider,
      incoming: incoming,
      mode: TransferApplyMode.overwrite,
    );
    if (!result.applied) {
      throw FormatException(result.error ?? 'transfer_import_failed');
    }
  }

  @override
  Future<int> importMergeBackupJson(String content) async {
    final incoming = normalizeTransferCourseColors(
      _transferService.parseCompatible(content, channel: TransferChannel.lan),
    );
    _rejectWholeDeviceWrite(incoming);
    final result = await _transferService.applyToProvider(
      provider: _provider,
      incoming: incoming,
      mode: TransferApplyMode.merge,
    );
    if (!result.applied) {
      throw FormatException(result.error ?? 'transfer_import_failed');
    }
    final courseDiff = result.preview.forKind(TransferEntityKind.courses);
    return courseDiff.addedCount + courseDiff.updatedCount;
  }

  @override
  Future<int> importSpreadsheetCourses(
    SpreadsheetImportResult result, {
    required bool replaceExisting,
  }) {
    return _provider.importParsedCourses(
      result.courses,
      replaceExisting: replaceExisting,
      source: 'spreadsheet',
    );
  }

  @override
  Future<void> setCurrentWeek(int week) => _provider.setCurrentWeek(week);

  @override
  Map<String, dynamic> buildMetaJson() {
    final settings = _provider.settings;
    return {
      'profileId': activeProfileId,
      'profileName': activeProfileName,
      'currentWeek': currentWeek,
      'semesterWeekCount': settings.semesterWeekCount,
      'sectionCount': settings.sectionCount,
      'sections': settings.sections.map((section) => section.toJson()).toList(),
      'presetColors': kPresetCourseColorHexes,
      'weekdayLabels': const ['周一', '周二', '周三', '周四', '周五', '周六', '周日'],
      'profiles': listProfilesSummary(),
    };
  }

  /// Applies [weekExpression] / [suspendedWeekExpression] on a slot JSON map.
  static void applyWeekExpressionFields(
    Map<String, dynamic> slotMap, {
    required String courseName,
    required int semesterWeekCount,
    List<String>? warnings,
  }) {
    final weekExpression =
        slotMap.remove('weekExpression')?.toString().trim() ?? '';
    if (weekExpression.isNotEmpty) {
      final weeks = WeekExpressionParser.parse(
        weekExpression,
        itemName: courseName,
        semesterWeekCount: semesterWeekCount,
        warnings: warnings,
      );
      slotMap['customWeeks'] = weeks;
      if (weeks.isNotEmpty) {
        slotMap['startWeek'] = weeks.first;
        slotMap['endWeek'] = weeks.last;
      }
      slotMap['isOddWeek'] = false;
      slotMap['isEvenWeek'] = false;
    }
    final suspendedExpression =
        slotMap.remove('suspendedWeekExpression')?.toString().trim() ?? '';
    if (suspendedExpression.isNotEmpty) {
      slotMap['suspendedWeeks'] = WeekExpressionParser.parse(
        suspendedExpression,
        itemName: '$courseName 停课周',
        semesterWeekCount: semesterWeekCount,
        warnings: warnings,
      );
    }
  }

  /// Builds a [Course] from API JSON, filling required defaults.
  static Course courseFromApiJson(
    Map<String, dynamic> json, {
    required List<SectionTime> sections,
    required int semesterWeekCount,
    String? existingId,
  }) {
    final safeSections = sections.isEmpty
        ? TimetableSettings.defaults().sections
        : sections;
    final normalizedSections = Course.normalizeSections(
      startSection: (json['startSection'] as num?)?.toInt() ?? 1,
      endSection:
          (json['endSection'] as num?)?.toInt() ??
          ((json['startSection'] as num?)?.toInt() ?? 1),
      maxSection: safeSections.length,
    );
    final startIndex = normalizedSections.startSection - 1;
    final endIndex = normalizedSections.endSection - 1;
    final templateStartTime = safeSections[startIndex].startTime;
    final templateEndTime = safeSections[endIndex].endTime;
    final startTime = _usableClockText(json['startTime'], templateStartTime);
    final endTime = _usableClockText(json['endTime'], templateEndTime);
    // hasCustomTime 决定 provider 会不会按作息模板重写钟点
    // （TimeSchemeLogic：`if (course.hasCustomTime) return course` 原样保留）。
    // 这里原先根本不读它，于是 PATCH 只改地点时：existing.toJson() 带着
    // hasCustomTime=true 进来却被丢掉 → 造出的对象是 false →
    // `_syncCourseWithEffectiveTimeScheme` 把这门课的时间重写回模板，
    // 而 HTTP 响应回显的还是请求里那份自定义时间 —— 手机与浏览器从此
    // 各显示一个时间。缺字段的老客户端按"送来的时间与模板是否一致"推导，
    // 保证响应即落库。
    final hasCustomTime =
        json['hasCustomTime'] as bool? ??
        (startTime != templateStartTime || endTime != templateEndTime);
    final normalizedWeeks = Course.normalizeWeeks(
      startWeek: (json['startWeek'] as num?)?.toInt() ?? 1,
      endWeek: (json['endWeek'] as num?)?.toInt() ?? semesterWeekCount,
      maxWeek: semesterWeekCount < 1 ? 1 : semesterWeekCount,
    );
    // 与 Course.fromJson 同口径的写侧归一：越界项丢弃、去重、升序、超量整表作废。
    // 裸列表进构造函数时消费侧（isInWeek / activeWeeks）会钳到 1..30，
    // 于是 [999] 变成"这门课哪周都不在"——界面上消失却仍计入统计与伴侣同步。
    final customWeeks = Course.normalizeWeekList(
      (json['customWeeks'] as List<dynamic>?)
          ?.map((item) => (item as num).toInt())
          .toList(),
    );
    final suspendedWeeks = Course.normalizeWeekList(
      (json['suspendedWeeks'] as List<dynamic>?)
          ?.map((item) => (item as num).toInt())
          .toList(),
    );

    return Course(
      // `existingId` 是 handler 从请求体里原样取的（`slotMap['id'] as String?`），
      // 空串是非 null → 旧写法 `existingId ?? _suppliedCourseId(...)` 会让归一函数
      // 根本没机会跑，于是造出 id 为空的行：`/api/v1/courses/([^/]+)` 永远寻址不到它，
      // 而删除按 id 等值摘除（`timetable/course_repository.dart` 的
      // `removeWhere((c) => c.id == courseId)`）会一次删掉所有空 id 行。
      // 两个来源统一过一次归一才是对的口径。
      id:
          _suppliedCourseId(existingId ?? json['id']) ?? const Uuid().v4(),
      name: (json['name'] as String?)?.trim() ?? '',
      shortName: json['shortName'] as String?,
      teacher: (json['teacher'] as String?)?.trim() ?? '',
      location: (json['location'] as String?)?.trim() ?? '',
      dayOfWeek: Course.normalizeDayOfWeek(
        (json['dayOfWeek'] as num?)?.toInt() ?? 1,
      ),
      startSection: normalizedSections.startSection,
      endSection: normalizedSections.endSection,
      startTime: startTime,
      endTime: endTime,
      hasCustomTime: hasCustomTime,
      color: normalizeLanCourseColor(json['color']),
      startWeek: normalizedWeeks.startWeek,
      endWeek: normalizedWeeks.endWeek,
      isOddWeek: json['isOddWeek'] as bool? ?? false,
      isEvenWeek: json['isEvenWeek'] as bool? ?? false,
      customWeeks: customWeeks,
      suspendedWeeks: suspendedWeeks,
      note: json['note'] as String?,
      description: json['description'] as String? ?? json['note'] as String?,
      courseNature: CourseNatureX.fromValue(json['courseNature'] as String?),
      timeSchemeIdOverride: json['timeSchemeIdOverride'] as String?,
    );
  }

  static Course mergeCoursePatch(
    Course existing,
    Map<String, dynamic> patch, {
    required List<SectionTime> sections,
    required int semesterWeekCount,
  }) {
    final merged = Map<String, dynamic>.from(existing.toJson());
    for (final entry in patch.entries) {
      merged[entry.key] = entry.value;
    }
    // 合并 existing.toJson() 会带来两类过期值，必须显式作废，
    // 否则客户端的意图会被旧标志/旧钟点吃掉：
    // 1) 补丁自带钟点（用户在网页上改了时间）：existing 的 hasCustomTime
    //    可能是 false，留着它 courseFromApiJson 就只会取 false，
    //    provider 随即按模板把客户端给的时间重烤掉 ——
    //    响应 200 回显 07:15、手机上却是 08:00，正是本文件要避免的"响应≠落库"。
    // 2) 补丁只改了节次：merged 里留的是**旧节次**的钟点与旧标志，
    //    移课就等于"跟着新节次的铃点走"，旧的自定义钉法不该跟过去。
    // 两种情况都把钟点/标志交回 courseFromApiJson 重新推导
    // （它与模板一致就 false，客户端显式送了不同时间就 true）。
    final suppliesClock =
        patch['startTime'] != null || patch['endTime'] != null;
    final requestedStartSection = (patch['startSection'] as num?)?.toInt();
    final requestedEndSection = (patch['endSection'] as num?)?.toInt();
    final sectionsChanged =
        (requestedStartSection != null &&
            requestedStartSection != existing.startSection) ||
        (requestedEndSection != null &&
            requestedEndSection != existing.endSection);
    if (suppliesClock) {
      merged.remove('hasCustomTime');
    } else if (sectionsChanged) {
      merged.remove('startTime');
      merged.remove('endTime');
      merged.remove('hasCustomTime');
    }
    return courseFromApiJson(
      merged,
      sections: sections,
      semesterWeekCount: semesterWeekCount,
      existingId: existing.id,
    );
  }

  List<SectionTime> get sections => _provider.settings.sections;

  int get semesterWeekCountValue => _provider.settings.semesterWeekCount;
}
