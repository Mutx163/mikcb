import 'dart:convert';

import 'app_log_service.dart';
import '../domain/week_calculator.dart';
import '../models/course.dart';
import '../models/course_task.dart';
import '../models/exam.dart';
import '../models/location_time_group.dart';
import '../models/schedule_date_rule.dart';
import '../models/schedule_item.dart';
import '../models/time_scheme.dart';
import '../models/timetable_settings.dart';
import '../providers/timetable_provider.dart';
import 'data_transfer_service.dart';
import 'transfer_diff_service.dart';
import 'transfer_package.dart';
import 'transfer_undo_service.dart';

class TransferApplyResult {
  final bool applied;
  final String? error;
  final TransferDiff preview;
  final TransferUndoToken? undoToken;

  const TransferApplyResult({
    required this.applied,
    required this.preview,
    this.error,
    this.undoToken,
  });
}

/// Coordinates package construction, preview, apply, backup and undo for all
/// transport adapters. QR/LAN/cloud code only needs to pass decoded package
/// bytes into this service.
class UnifiedTransferService {
  UnifiedTransferService({
    DataTransferService? dataTransferService,
    TransferDiffService? diffService,
    TransferUndoService? undoService,
  }) : _dataTransferService = dataTransferService ?? DataTransferService(),
       _diffService = diffService ?? const TransferDiffService(),
       undoService = undoService ?? TransferUndoService();

  final DataTransferService _dataTransferService;
  final TransferDiffService _diffService;
  final TransferUndoService undoService;

  DataTransferService get dataTransferService => _dataTransferService;

  TransferPackage buildCurrentPackage({
    required TimetableProvider provider,
    TransferChannel channel = TransferChannel.file,
    TransferScope scope = TransferScope.currentTimetable,
    Iterable<String> selectedCourseIds = const [],
  }) {
    final selected = selectedCourseIds.toSet();
    final sourceCourses = scope == TransferScope.weekTimetable
        ? provider.courses
              .where((item) => item.isActiveInWeek(provider.currentWeek))
              .toList()
        : provider.courses;
    final courses = scope == TransferScope.timeTemplate
        ? const <Course>[]
        : scope == TransferScope.selectedCourses ||
              scope == TransferScope.selectedCourse
        ? sourceCourses.where((item) => selected.contains(item.id)).toList()
        : selected.isEmpty
        ? sourceCourses
        : sourceCourses.where((item) => selected.contains(item.id)).toList();
    final courseIds = courses.map((item) => item.id).toSet();
    final tasks = scope == TransferScope.timeTemplate
        ? const <CourseTask>[]
        : selected.isEmpty &&
              scope != TransferScope.selectedCourses &&
              scope != TransferScope.selectedCourse
        ? provider.tasks
        : provider.tasks
              .where(
                (item) =>
                    item.courseId == null || courseIds.contains(item.courseId),
              )
              .toList();
    final exams = scope == TransferScope.timeTemplate
        ? const <Exam>[]
        : selected.isEmpty &&
              scope != TransferScope.selectedCourses &&
              scope != TransferScope.selectedCourse
        ? provider.exams
        : provider.exams
              .where((item) => courseIds.contains(item.courseId))
              .toList();
    final scopedMetadata = _selectScopedMetadata(
      provider: provider,
      scope: scope,
      courses: courses,
    );

    return _dataTransferService.buildTransferPackage(
      scope: scope,
      channel: channel,
      profileName: provider.activeProfile?.name,
      courses: courses,
      tasks: tasks,
      scheduleItems: scopedMetadata.scheduleItems,
      exams: exams,
      settings: scope == TransferScope.timeTemplate ? null : provider.settings,
      currentWeek: scope == TransferScope.timeTemplate
          ? null
          : provider.currentWeek,
      timeSchemes: scopedMetadata.timeSchemes,
      scheduleDateRules: scopedMetadata.scheduleDateRules,
      locationTimeGroups: scopedMetadata.locationTimeGroups,
    );
  }

  ({
    List<ScheduleItem> scheduleItems,
    List<ScheduleDateRule> scheduleDateRules,
    List<LocationTimeGroup> locationTimeGroups,
    List<TimeScheme> timeSchemes,
  })
  _selectScopedMetadata({
    required TimetableProvider provider,
    required TransferScope scope,
    required List<Course> courses,
  }) {
    if (scope == TransferScope.timeTemplate) {
      return (
        scheduleItems: const [],
        scheduleDateRules: const [],
        locationTimeGroups: const [],
        timeSchemes: provider.timeSchemes.toList(),
      );
    }

    final isScoped =
        scope == TransferScope.selectedCourse ||
        scope == TransferScope.selectedCourses ||
        scope == TransferScope.weekTimetable;
    if (!isScoped) {
      return (
        scheduleItems: provider.scheduleItems.toList(),
        scheduleDateRules: provider.scheduleDateRules.toList(),
        locationTimeGroups: provider.locationTimeGroups.toList(),
        timeSchemes: provider.timeSchemes.toList(),
      );
    }

    final window = _buildScopeWindow(
      provider: provider,
      scope: scope,
      courses: courses,
    );
    final scheduleItems = window.isEmpty
        ? const <ScheduleItem>[]
        : provider.scheduleItems
              .where((item) => _scheduleItemIntersects(item, window))
              .toList();
    final scheduleDateRules = window.isEmpty
        ? const <ScheduleDateRule>[]
        : provider.scheduleDateRules.where((rule) {
            final start = ScheduleDateRuleLogic.parseIsoDate(rule.startDate);
            final end = ScheduleDateRuleLogic.parseIsoDate(rule.endDate);
            return start != null &&
                end != null &&
                window.overlapsDateRange(start: start, end: end);
          }).toList();

    final locationGroupIds = <String>{};
    for (final course in courses) {
      final match = LocationTimeMatchLogic.match(
        course.location,
        provider.locationTimeGroups,
      );
      if (match != null) {
        locationGroupIds.add(match.groupId);
      }
    }
    final locationTimeGroups = provider.locationTimeGroups
        .where((group) => locationGroupIds.contains(group.id))
        .toList();

    // A scoped package only needs schemes referenced by its courses or by the
    // scoped rule/location records. This also carries explicit course
    // overrides, whose IDs are not necessarily the target device's IDs.
    final timeSchemeIds = <String>{};
    for (final course in courses) {
      final overrideId = course.timeSchemeIdOverride?.trim();
      if (overrideId != null && overrideId.isNotEmpty) {
        timeSchemeIds.add(overrideId);
        continue;
      }
      final locationMatch = LocationTimeMatchLogic.match(
        course.location,
        provider.locationTimeGroups,
      );
      final locationGroup = locationMatch == null
          ? null
          : provider.locationTimeGroups.firstWhere(
              (group) => group.id == locationMatch.groupId,
              orElse: () =>
                  const LocationTimeGroup(id: '', name: '', timeSchemeId: ''),
            );
      final locationSchemeId = locationGroup?.timeSchemeId.trim() ?? '';
      final defaultSchemeId =
          provider.settings.activeTimeSchemeId?.trim() ?? '';
      timeSchemeIds.add(
        locationSchemeId.isNotEmpty ? locationSchemeId : defaultSchemeId,
      );
    }
    timeSchemeIds.addAll(
      locationTimeGroups
          .map((group) => group.timeSchemeId.trim())
          .where((id) => id.isNotEmpty),
    );
    timeSchemeIds.addAll(
      scheduleDateRules
          .map((rule) => rule.timeSchemeId.trim())
          .where((id) => id.isNotEmpty),
    );
    final timeSchemes = provider.timeSchemes
        .where((scheme) => timeSchemeIds.contains(scheme.id))
        .toList();

    return (
      scheduleItems: scheduleItems,
      scheduleDateRules: scheduleDateRules,
      locationTimeGroups: locationTimeGroups,
      timeSchemes: timeSchemes,
    );
  }

  _TransferScopeWindow _buildScopeWindow({
    required TimetableProvider provider,
    required TransferScope scope,
    required List<Course> courses,
  }) {
    final fallbackWeekStart = WeekCalculator.startOfWeek(DateTime.now());
    final isSelectedScope =
        scope == TransferScope.selectedCourse ||
        scope == TransferScope.selectedCourses;
    if (isSelectedScope && courses.isEmpty) {
      return _TransferScopeWindow.empty(fallbackWeekStart: fallbackWeekStart);
    }

    final weeks = scope == TransferScope.weekTimetable
        ? <int>{provider.currentWeek}
        : courses.expand((course) => course.activeWeeks).toSet();
    if (weeks.isEmpty) {
      return _TransferScopeWindow.empty(fallbackWeekStart: fallbackWeekStart);
    }

    final semesterStart = provider.settings.semesterStartDate;
    return _TransferScopeWindow(
      weeks: weeks,
      semesterStartWeek: semesterStart == null
          ? null
          : WeekCalculator.startOfWeek(semesterStart),
      fallbackWeekStart: fallbackWeekStart,
    );
  }

  bool _scheduleItemIntersects(ScheduleItem item, _TransferScopeWindow window) {
    final instances = item.expandInstances(
      fromDate: window.startDate,
      toDate: window.endDate,
    );
    return instances.any((instance) => window.containsDate(instance.date));
  }

  TransferPackage buildFullPackage({
    required TimetableProvider provider,
    TransferChannel channel = TransferChannel.file,
  }) {
    return _dataTransferService.buildTransferPackage(
      scope: TransferScope.allData,
      channel: channel,
      profiles: provider.profiles,
      activeProfileId: provider.activeProfileId,
      timeSchemes: provider.timeSchemes,
      scheduleDateRules: provider.scheduleDateRules,
      locationTimeGroups: provider.locationTimeGroups,
      isFullBackup: true,
    );
  }

  TransferPackage parse(String content) {
    return _dataTransferService.parseTransferPackageJson(content);
  }

  /// Parses the current envelope and normalizes the two legacy backup shapes
  /// used by older file, QR and LAN clients into the same package boundary.
  TransferPackage parseCompatible(String content, {TransferChannel? channel}) {
    try {
      final parsed = parse(content);
      return channel == null ? parsed : parsed.copyWith(channel: channel);
    } on FormatException {
      // A current envelope must fail closed. Falling through to the legacy
      // readers here could turn a malformed or older schema into an import.
      if (_isTransferEnvelope(content)) {
        rethrow;
      }
      if (_dataTransferService.isFullBackupJson(content)) {
        final full = _dataTransferService.parseFullBackupJson(content);
        return _dataTransferService.buildTransferPackage(
          packageId: full.packageId,
          scope: TransferScope.allData,
          channel: channel ?? full.channel,
          profiles: full.profiles,
          activeProfileId: full.activeProfileId,
          timeSchemes: full.timeSchemes,
          scheduleDateRules: full.scheduleDateRules,
          locationTimeGroups: full.locationTimeGroups,
          isFullBackup: true,
          exportedAt: full.exportedAt,
        );
      }

      final backup = _dataTransferService.parseBackupJson(content);
      return _dataTransferService.buildTransferPackage(
        packageId: backup.packageId,
        scope: backup.scope ?? TransferScope.currentTimetable,
        channel: channel ?? backup.channel,
        profileName: backup.profileName,
        courses: backup.courses,
        tasks: backup.tasks,
        scheduleItems: backup.scheduleItems,
        exams: backup.exams,
        settings: backup.settings,
        currentWeek: backup.currentWeek,
        timeSchemes: backup.timeSchemes,
        scheduleDateRules: backup.scheduleDateRules,
        locationTimeGroups: backup.locationTimeGroups,
        exportedAt: backup.exportedAt,
      );
    }
  }

  static bool _isTransferEnvelope(String content) {
    try {
      final decoded = jsonDecode(content);
      return decoded is Map &&
          decoded['app'] == TransferPackage.appId &&
          decoded['packageType'] == TransferPackage.packageType;
    } on Object {
      return false;
    }
  }

  TransferDiff preview({
    required TransferPackage current,
    required TransferPackage incoming,
    TransferApplyMode mode = TransferApplyMode.merge,
  }) {
    return _diffService.compare(
      current: current,
      incoming: incoming,
      mode: mode,
    );
  }

  Future<TransferApplyResult> applyToProvider({
    required TimetableProvider provider,
    required TransferPackage incoming,
    required TransferApplyMode mode,
    TransferPackage? current,
  }) async {
    await provider.initialize();
    final currentPackage =
        current ??
        buildCurrentPackage(provider: provider, channel: incoming.channel);
    final preview = _diffService.compare(
      current: currentPackage,
      incoming: incoming,
      mode: mode,
    );
    final validation = _diffService.validate(incoming, current: currentPackage);
    if (!validation.isValid) {
      return TransferApplyResult(
        applied: false,
        error: validation.errors.first,
        preview: preview,
      );
    }

    final backupJson = _dataTransferService.buildFullBackupJson(
      profiles: provider.profiles,
      activeProfileId: provider.activeProfileId,
      timeSchemes: provider.timeSchemes,
      scheduleDateRules: provider.scheduleDateRules,
      locationTimeGroups: provider.locationTimeGroups,
      channel: incoming.channel,
    );
    final token = undoService.create(
      backupJson: backupJson,
      incoming: incoming,
      mode: mode,
      preview: preview,
    );

    try {
      await provider.runMutationExclusive(() async {
        if (mode == TransferApplyMode.overwrite) {
          await _overwrite(provider, incoming);
        } else {
          await _merge(provider, incoming);
        }
      });
      await AppLogService.instance.info(
        'transfer_import_completed',
        'transfer import completed',
        extras: {
          'transferId': incoming.packageId,
          'channel': incoming.channel.value,
          'scope': incoming.scope.value,
          'mode': mode.name,
          'added': preview.addedCount,
          'updated': preview.updatedCount,
          'removed': preview.removedCount,
          'undoId': token.id,
        },
      );
      return TransferApplyResult(
        applied: true,
        preview: preview,
        undoToken: token,
      );
    } catch (error, stackTrace) {
      await _restore(provider, token);
      undoService.clear();
      await AppLogService.instance.error(
        'transfer_import_failed',
        'transfer import failed',
        error: error,
        stackTrace: stackTrace,
        extras: {
          'transferId': incoming.packageId,
          'channel': incoming.channel.value,
          'scope': incoming.scope.value,
          'mode': mode.name,
        },
      );
      return TransferApplyResult(
        applied: false,
        error: 'transfer_import_failed',
        preview: preview,
      );
    }
  }

  Future<bool> undoLast(TimetableProvider provider) async {
    final token = undoService.pending;
    if (token == null) {
      return false;
    }
    return undoToken(provider, token.id);
  }

  Future<bool> undoToken(TimetableProvider provider, String tokenId) async {
    final token = undoService.take(tokenId);
    if (token == null) {
      return false;
    }
    try {
      await provider.runMutationExclusive(() => _restore(provider, token));
      await AppLogService.instance.info(
        'transfer_import_undone',
        'transfer import undone',
        extras: {
          'undoId': token.id,
          'channel': token.channel.value,
          'scope': token.scope.value,
          'mode': token.mode.name,
        },
      );
      return true;
    } catch (error, stackTrace) {
      undoService.restore(token);
      await AppLogService.instance.error(
        'transfer_import_undo_failed',
        'transfer import undo failed',
        error: error,
        stackTrace: stackTrace,
        extras: {'undoId': token.id},
      );
      return false;
    }
  }

  Future<void> _overwrite(
    TimetableProvider provider,
    TransferPackage incoming,
  ) async {
    if (incoming.scope.overwriteUsesMergeSemantics) {
      // Scoped overwrite updates only entities inside the package boundary.
      // The remaining local timetable is outside that boundary.
      if (incoming.scope == TransferScope.timeTemplate) {
        await _mergeTimeSchemes(provider, incoming.timeSchemes);
      } else {
        await _merge(provider, incoming);
      }
      return;
    }
    if (incoming.isFullBackup ||
        (incoming.scope == TransferScope.allData &&
            incoming.profiles.isNotEmpty)) {
      final fullJson = _dataTransferService.buildFullBackupJson(
        profiles: incoming.profiles,
        activeProfileId: incoming.activeProfileId,
        timeSchemes: incoming.timeSchemes,
        scheduleDateRules: incoming.scheduleDateRules,
        locationTimeGroups: incoming.locationTimeGroups,
        channel: incoming.channel,
        packageId: incoming.packageId,
      );
      final error = await provider.importFullAppDataBackup(fullJson);
      if (error != null) {
        throw StateError(error);
      }
      await _replaceRulesAndLocations(provider, incoming);
      return;
    }

    // The legacy profile backup importer receives the source scheme IDs in
    // its payload, so create/resolve schemes first and rewrite every reference
    // that it will apply. Full backups intentionally replace the scheme table
    // as a whole and take the branch above.
    final timeSchemeIdMap = await _mergeTimeSchemes(
      provider,
      incoming.timeSchemes,
    );
    final courses = _remapCourseTimeSchemeReferences(
      incoming.courses,
      timeSchemeIdMap,
    );
    final settings = incoming.settings == null
        ? provider.settings
        : _remapSettingsTimeSchemeReference(
            incoming.settings!,
            timeSchemeIdMap,
          );
    final scheduleDateRules = _remapScheduleDateRules(
      incoming.scheduleDateRules,
      timeSchemeIdMap,
    );
    final locationTimeGroups = _remapLocationTimeGroups(
      incoming.locationTimeGroups,
      timeSchemeIdMap,
    );
    final json = _dataTransferService.buildBackupJson(
      packageId: incoming.packageId,
      scope: incoming.scope,
      channel: incoming.channel,
      profileName: incoming.profileName,
      courses: courses,
      tasks: incoming.tasks,
      scheduleItems: incoming.scheduleItems,
      exams: incoming.exams,
      settings: settings,
      currentWeek: incoming.currentWeek ?? provider.currentWeek,
      timeSchemes: incoming.timeSchemes,
      scheduleDateRules: scheduleDateRules,
      locationTimeGroups: locationTimeGroups,
    );
    final error = await provider.importAppDataBackup(json);
    if (error != null) {
      throw StateError(error);
    }
    await _replaceRulesAndLocations(
      provider,
      incoming.copyWith(
        scheduleDateRules: scheduleDateRules,
        locationTimeGroups: locationTimeGroups,
      ),
    );
  }

  Future<void> _merge(
    TimetableProvider provider,
    TransferPackage incoming,
  ) async {
    // Time-scheme IDs are generated locally and therefore cannot be used as
    // cross-device identities. Resolve them before importing any payload that
    // can reference a scheme.
    final timeSchemeIdMap = await _mergeTimeSchemes(
      provider,
      incoming.timeSchemes,
    );
    final courses = _remapCourseTimeSchemeReferences(
      incoming.courses,
      timeSchemeIdMap,
    );

    if (courses.isNotEmpty) {
      await provider.importParsedCourses(
        courses,
        replaceExisting: false,
        source: 'transfer_${incoming.channel.value}',
      );
    }
    final courseIds = provider.courses.map((item) => item.id).toSet();
    for (final task in incoming.tasks) {
      if (task.courseId != null && !courseIds.contains(task.courseId)) {
        throw StateError('task_course_missing:${task.id}');
      }
      if (provider.getTaskById(task.id) == null) {
        await provider.addTask(task);
      } else {
        await provider.updateTask(task);
      }
    }
    for (final item in incoming.scheduleItems) {
      if (provider.getScheduleItemById(item.id) == null) {
        await provider.addScheduleItem(item);
      } else {
        await provider.updateScheduleItem(item);
      }
    }
    for (final exam in incoming.exams) {
      if (provider.getCourseById(exam.courseId) == null) {
        throw StateError('exam_course_missing:${exam.id}');
      }
      if (provider.exams.any((item) => item.id == exam.id)) {
        await provider.updateExam(exam);
      } else {
        await provider.addExam(exam);
      }
    }
    if (incoming.settings != null &&
        (incoming.scope == TransferScope.currentTimetable ||
            incoming.scope == TransferScope.allData ||
            incoming.scope == TransferScope.timeTemplate)) {
      await provider.updateSettings(
        _remapSettingsTimeSchemeReference(incoming.settings!, timeSchemeIdMap),
      );
    }
    if (incoming.currentWeek != null &&
        incoming.scope != TransferScope.selectedCourse &&
        incoming.scope != TransferScope.selectedCourses) {
      await provider.setCurrentWeek(incoming.currentWeek!);
    }
    await _mergeRulesAndLocations(
      provider,
      incoming,
      timeSchemeIdMap: timeSchemeIdMap,
    );
  }

  Future<Map<String, String>> _mergeTimeSchemes(
    TimetableProvider provider,
    List<TimeScheme> incoming,
  ) async {
    final localSchemesById = {
      for (final scheme in provider.timeSchemes) scheme.id: scheme,
    };
    final localSchemeIdsBySignature = {
      for (final scheme in provider.timeSchemes)
        _timeSchemeSectionsSignature(scheme): scheme.id,
    };
    final resolvedSchemeIds = <String, String>{};

    for (final incomingScheme in incoming) {
      final incomingSignature = _timeSchemeSectionsSignature(incomingScheme);
      final existingSchemeId = localSchemeIdsBySignature[incomingSignature];
      final existingScheme =
          localSchemesById[incomingScheme.id] ??
          (existingSchemeId == null
              ? null
              : localSchemesById[existingSchemeId]);

      if (existingScheme == null) {
        final createdScheme = await provider.createTimeScheme(
          name: incomingScheme.name,
          sections: incomingScheme.sections,
        );
        localSchemesById[createdScheme.id] = createdScheme;
        localSchemeIdsBySignature[incomingSignature] = createdScheme.id;
        resolvedSchemeIds[incomingScheme.id] = createdScheme.id;
        continue;
      }

      final error = await provider.updateTimeScheme(
        schemeId: existingScheme.id,
        name: incomingScheme.name,
        sections: incomingScheme.sections,
      );
      if (error != null) {
        throw StateError(error);
      }
      resolvedSchemeIds[incomingScheme.id] = existingScheme.id;
      localSchemeIdsBySignature[incomingSignature] = existingScheme.id;
    }

    return resolvedSchemeIds;
  }

  String _timeSchemeSectionsSignature(TimeScheme scheme) {
    return jsonEncode(
      scheme.sections.map((section) => section.toJson()).toList(),
    );
  }

  List<Course> _remapCourseTimeSchemeReferences(
    List<Course> courses,
    Map<String, String> timeSchemeIdMap,
  ) {
    return courses.map((course) {
      final sourceSchemeId = course.timeSchemeIdOverride;
      if (sourceSchemeId == null) {
        return course;
      }
      final targetSchemeId = timeSchemeIdMap[sourceSchemeId];
      if (targetSchemeId == null || targetSchemeId == sourceSchemeId) {
        return course;
      }
      return course.copyWith(timeSchemeIdOverride: targetSchemeId);
    }).toList();
  }

  TimetableSettings _remapSettingsTimeSchemeReference(
    TimetableSettings settings,
    Map<String, String> timeSchemeIdMap,
  ) {
    final sourceSchemeId = settings.activeTimeSchemeId;
    if (sourceSchemeId == null) {
      return settings;
    }
    final targetSchemeId = timeSchemeIdMap[sourceSchemeId];
    if (targetSchemeId == null || targetSchemeId == sourceSchemeId) {
      return settings;
    }
    return settings.copyWith(activeTimeSchemeId: targetSchemeId);
  }

  List<ScheduleDateRule> _remapScheduleDateRules(
    List<ScheduleDateRule> rules,
    Map<String, String> timeSchemeIdMap,
  ) {
    return rules
        .map(
          (rule) => rule.copyWith(
            timeSchemeId:
                timeSchemeIdMap[rule.timeSchemeId] ?? rule.timeSchemeId,
          ),
        )
        .toList();
  }

  List<LocationTimeGroup> _remapLocationTimeGroups(
    List<LocationTimeGroup> groups,
    Map<String, String> timeSchemeIdMap,
  ) {
    return groups
        .map(
          (group) => group.copyWith(
            timeSchemeId:
                timeSchemeIdMap[group.timeSchemeId] ?? group.timeSchemeId,
          ),
        )
        .toList();
  }

  Future<void> _mergeRulesAndLocations(
    TimetableProvider provider,
    TransferPackage incoming, {
    Map<String, String> timeSchemeIdMap = const {},
  }) async {
    if (incoming.locationTimeGroups.isNotEmpty) {
      final locationTimeGroups = _remapLocationTimeGroups(
        incoming.locationTimeGroups,
        timeSchemeIdMap,
      );
      final byId = {
        for (final item in provider.locationTimeGroups) item.id: item,
        for (final item in locationTimeGroups) item.id: item,
      };
      await provider.replaceLocationTimeGroups(byId.values.toList());
    }
    if (incoming.scheduleDateRules.isNotEmpty) {
      final scheduleDateRules = _remapScheduleDateRules(
        incoming.scheduleDateRules,
        timeSchemeIdMap,
      );
      final byId = {
        for (final item in provider.scheduleDateRules) item.id: item,
        for (final item in scheduleDateRules) item.id: item,
      };
      await provider.replaceScheduleDateRules(byId.values.toList());
    }
  }

  Future<void> _replaceRulesAndLocations(
    TimetableProvider provider,
    TransferPackage incoming,
  ) async {
    if (incoming.locationTimeGroups.isNotEmpty ||
        incoming.scope == TransferScope.allData) {
      await provider.replaceLocationTimeGroups(
        incoming.locationTimeGroups,
        resync: false,
      );
    }
    if (incoming.scheduleDateRules.isNotEmpty ||
        incoming.scope == TransferScope.allData) {
      await provider.replaceScheduleDateRules(
        incoming.scheduleDateRules,
        resync: false,
      );
    }
  }

  Future<void> _restore(
    TimetableProvider provider,
    TransferUndoToken token,
  ) async {
    final backup = _dataTransferService.parseFullBackupJson(token.backupJson);
    final error = await provider.importFullAppDataBackup(token.backupJson);
    if (error != null) {
      throw StateError(error);
    }
    await provider.replaceLocationTimeGroups(
      backup.locationTimeGroups,
      resync: false,
    );
    await provider.replaceScheduleDateRules(
      backup.scheduleDateRules,
      resync: false,
    );
  }
}

class _TransferScopeWindow {
  final Set<int> weeks;
  final DateTime? semesterStartWeek;
  final DateTime fallbackWeekStart;

  const _TransferScopeWindow({
    required this.weeks,
    required this.semesterStartWeek,
    required this.fallbackWeekStart,
  });

  const _TransferScopeWindow.empty({required this.fallbackWeekStart})
    : weeks = const {},
      semesterStartWeek = null;

  bool get isEmpty => weeks.isEmpty;

  DateTime get startDate {
    if (semesterStartWeek == null || weeks.isEmpty) {
      return fallbackWeekStart;
    }
    final firstWeek = weeks.reduce(
      (left, right) => left < right ? left : right,
    );
    return semesterStartWeek!.add(Duration(days: (firstWeek - 1) * 7));
  }

  DateTime get endDate {
    if (semesterStartWeek == null || weeks.isEmpty) {
      return fallbackWeekStart.add(const Duration(days: 6));
    }
    final lastWeek = weeks.reduce((left, right) => left > right ? left : right);
    return semesterStartWeek!.add(Duration(days: lastWeek * 7 - 1));
  }

  bool containsDate(DateTime value) {
    if (isEmpty) {
      return false;
    }
    final date = DateTime(value.year, value.month, value.day);
    if (semesterStartWeek == null) {
      final lastDate = fallbackWeekStart.add(const Duration(days: 6));
      return !date.isBefore(fallbackWeekStart) && !date.isAfter(lastDate);
    }

    final alignedDate = WeekCalculator.startOfWeek(date);
    final diffDays =
        DateTime.utc(alignedDate.year, alignedDate.month, alignedDate.day)
            .difference(
              DateTime.utc(
                semesterStartWeek!.year,
                semesterStartWeek!.month,
                semesterStartWeek!.day,
              ),
            )
            .inDays;
    if (diffDays < 0) {
      return false;
    }
    return weeks.contains(diffDays ~/ 7 + 1);
  }

  bool overlapsDateRange({required DateTime start, required DateTime end}) {
    if (isEmpty) {
      return false;
    }
    final rangeStart = DateTime(start.year, start.month, start.day);
    final rangeEnd = DateTime(end.year, end.month, end.day);
    if (rangeEnd.isBefore(rangeStart)) {
      return false;
    }
    if (semesterStartWeek == null) {
      final windowEnd = fallbackWeekStart.add(const Duration(days: 6));
      return !rangeEnd.isBefore(fallbackWeekStart) &&
          !rangeStart.isAfter(windowEnd);
    }

    for (final week in weeks) {
      final weekStart = semesterStartWeek!.add(Duration(days: (week - 1) * 7));
      final weekEnd = weekStart.add(const Duration(days: 6));
      if (!rangeEnd.isBefore(weekStart) && !rangeStart.isAfter(weekEnd)) {
        return true;
      }
    }
    return false;
  }
}
