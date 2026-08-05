import 'dart:convert';

import 'app_log_service.dart';
import '../models/course.dart';
import '../models/course_task.dart';
import '../models/exam.dart';
import '../models/time_scheme.dart';
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

    return _dataTransferService.buildTransferPackage(
      scope: scope,
      channel: channel,
      profileName: provider.activeProfile?.name,
      courses: courses,
      tasks: tasks,
      scheduleItems: scope == TransferScope.timeTemplate
          ? const []
          : provider.scheduleItems,
      exams: exams,
      settings: scope == TransferScope.timeTemplate ? null : provider.settings,
      currentWeek: scope == TransferScope.timeTemplate
          ? null
          : provider.currentWeek,
      timeSchemes: provider.timeSchemes,
      scheduleDateRules: scope == TransferScope.timeTemplate
          ? const []
          : provider.scheduleDateRules,
      locationTimeGroups: scope == TransferScope.timeTemplate
          ? const []
          : provider.locationTimeGroups,
    );
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
        await _mergeTimeSchemes(
          provider,
          incoming.timeSchemes,
          incomingScope: incoming.scope,
        );
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

    final json = _dataTransferService.buildBackupJson(
      packageId: incoming.packageId,
      scope: incoming.scope,
      channel: incoming.channel,
      profileName: incoming.profileName,
      courses: incoming.courses,
      tasks: incoming.tasks,
      scheduleItems: incoming.scheduleItems,
      exams: incoming.exams,
      settings: incoming.settings ?? provider.settings,
      currentWeek: incoming.currentWeek ?? provider.currentWeek,
      timeSchemes: incoming.timeSchemes,
      scheduleDateRules: incoming.scheduleDateRules,
      locationTimeGroups: incoming.locationTimeGroups,
    );
    final error = await provider.importAppDataBackup(json);
    if (error != null) {
      throw StateError(error);
    }
    await _replaceRulesAndLocations(provider, incoming);
  }

  Future<void> _merge(
    TimetableProvider provider,
    TransferPackage incoming,
  ) async {
    if (incoming.courses.isNotEmpty) {
      await provider.importParsedCourses(
        incoming.courses,
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
      await provider.updateSettings(incoming.settings!);
    }
    if (incoming.currentWeek != null &&
        incoming.scope != TransferScope.selectedCourse &&
        incoming.scope != TransferScope.selectedCourses) {
      await provider.setCurrentWeek(incoming.currentWeek!);
    }
    await _mergeTimeSchemes(
      provider,
      incoming.timeSchemes,
      incomingScope: incoming.scope,
    );
    await _mergeRulesAndLocations(provider, incoming);
  }

  Future<void> _mergeTimeSchemes(
    TimetableProvider provider,
    List<TimeScheme> incoming, {
    required TransferScope incomingScope,
  }) async {
    for (final scheme in incoming) {
      final existing = provider.timeSchemes.where(
        (item) => item.id == scheme.id,
      );
      if (existing.isEmpty) {
        // A standalone time-template share has no course/rule references that
        // need the source UUID. Provider-generated identity is intentional;
        // references are only accepted when the source scheme already exists.
        if (incomingScope != TransferScope.timeTemplate) {
          throw StateError('transfer_time_scheme_not_found');
        }
        await provider.createTimeScheme(
          name: scheme.name,
          sections: scheme.sections,
        );
        continue;
      }
      final error = await provider.updateTimeScheme(
        schemeId: scheme.id,
        name: scheme.name,
        sections: scheme.sections,
      );
      if (error != null) {
        throw StateError(error);
      }
    }
  }

  Future<void> _mergeRulesAndLocations(
    TimetableProvider provider,
    TransferPackage incoming,
  ) async {
    if (incoming.locationTimeGroups.isNotEmpty) {
      final byId = {
        for (final item in provider.locationTimeGroups) item.id: item,
        for (final item in incoming.locationTimeGroups) item.id: item,
      };
      await provider.replaceLocationTimeGroups(byId.values.toList());
    }
    if (incoming.scheduleDateRules.isNotEmpty) {
      final byId = {
        for (final item in provider.scheduleDateRules) item.id: item,
        for (final item in incoming.scheduleDateRules) item.id: item,
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
