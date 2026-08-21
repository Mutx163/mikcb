import 'dart:convert';

import '../models/course.dart';
import '../models/course_task.dart';
import '../models/exam.dart';
import '../models/location_time_group.dart';
import '../models/schedule_date_rule.dart';
import '../models/schedule_item.dart';
import '../models/time_scheme.dart';
import '../models/timetable_profile.dart';
import '../models/timetable_settings.dart';
import 'transfer_package.dart';

enum TransferChangeType { added, updated, removed }

extension TransferChangeTypeX on TransferChangeType {
  String get value => name;
}

class TransferEntityChange {
  final TransferEntityKind kind;
  final TransferChangeType type;
  final String id;
  final String label;
  /// Profile scope for profile-owned entities; null means package/global scope.
  final String? profileId;
  final Map<String, dynamic>? before;
  final Map<String, dynamic>? after;

  const TransferEntityChange({
    required this.kind,
    required this.type,
    required this.id,
    required this.label,
    this.profileId,
    this.before,
    this.after,
  });

  /// Stable, transport-independent text that can be shown in a preview list.
  /// Localization can replace the operation word without re-parsing payloads.
  String get description => profileId == null
      ? '${type.value}: $readableLabel ($id)'
      : '${type.value}: $readableLabel ($id) [$profileId]';

  String get readableLabel => label.trim().isEmpty ? id : label.trim();

  Map<String, dynamic> toJson() => {
    'kind': kind.value,
    'type': type.value,
    'id': id,
    'label': label,
    if (profileId != null) 'profileId': profileId,
    'description': description,
    if (before != null) 'before': before,
    if (after != null) 'after': after,
  };
}

class TransferEntityDiff {
  final TransferEntityKind kind;
  final List<TransferEntityChange> changes;

  const TransferEntityDiff({required this.kind, required this.changes});

  int get addedCount =>
      changes.where((item) => item.type == TransferChangeType.added).length;
  int get updatedCount =>
      changes.where((item) => item.type == TransferChangeType.updated).length;
  int get removedCount =>
      changes.where((item) => item.type == TransferChangeType.removed).length;
  int get totalCount => changes.length;
  bool get isEmpty => changes.isEmpty;

  Map<String, dynamic> toJson() => {
    'kind': kind.value,
    'added': addedCount,
    'updated': updatedCount,
    'removed': removedCount,
    'total': totalCount,
    'changes': changes.map((item) => item.toJson()).toList(),
  };
}

/// A complete import preview. The UI can display [summaries] without knowing
/// how a course/exam/time-rule/location is represented in JSON.
class TransferDiff {
  final TransferApplyMode mode;
  final List<TransferEntityDiff> summaries;

  const TransferDiff({required this.mode, required this.summaries});

  static const List<TransferEntityKind> allKinds = [
    TransferEntityKind.courses,
    TransferEntityKind.exams,
    TransferEntityKind.timeRules,
    TransferEntityKind.locations,
    TransferEntityKind.tasks,
    TransferEntityKind.scheduleItems,
    TransferEntityKind.timeSchemes,
    TransferEntityKind.settings,
  ];

  static const List<TransferEntityKind> primaryKinds = [
    TransferEntityKind.courses,
    TransferEntityKind.exams,
    TransferEntityKind.timeRules,
    TransferEntityKind.locations,
  ];

  TransferEntityDiff forKind(TransferEntityKind kind) {
    return summaries.firstWhere(
      (item) => item.kind == kind,
      orElse: () => TransferEntityDiff(kind: kind, changes: const []),
    );
  }

  /// The original four categories retained for older preview consumers.
  List<TransferEntityDiff> get primarySummaries => [
    for (final kind in primaryKinds) forKind(kind),
  ];

  /// All entity categories that can be changed by a transfer.
  ///
  /// Keep this separate from [primarySummaries] for compatibility with older
  /// callers that only rendered the four original timetable categories. New
  /// previews must use this getter so secondary data cannot be hidden.
  List<TransferEntityDiff> get allSummaries => [
    for (final kind in allKinds) forKind(kind),
  ];

  bool get hasChanges => summaries.any((item) => item.changes.isNotEmpty);
  int get addedCount => summaries.fold(0, (sum, item) => sum + item.addedCount);
  int get updatedCount =>
      summaries.fold(0, (sum, item) => sum + item.updatedCount);
  int get removedCount =>
      summaries.fold(0, (sum, item) => sum + item.removedCount);
  int get totalCount => summaries.fold(0, (sum, item) => sum + item.totalCount);

  Map<String, dynamic> toJson() => {
    'mode': mode.name,
    'added': addedCount,
    'updated': updatedCount,
    'removed': removedCount,
    'total': totalCount,
    'summaries': allSummaries.map((item) => item.toJson()).toList(),
  };
}

class TransferDiffService {
  const TransferDiffService();

  TransferDiff compare({
    required TransferPackage current,
    required TransferPackage incoming,
    TransferApplyMode mode = TransferApplyMode.merge,
  }) {
    final summaries = <TransferEntityDiff>[];
    final reportRemovals =
        mode == TransferApplyMode.overwrite &&
        !incoming.scope.overwriteUsesMergeSemantics;
    for (final kind in TransferDiff.allKinds) {
      if (kind == TransferEntityKind.settings) {
        continue;
      }
      summaries.add(
        _compareList(
          kind: kind,
          current: _entitiesForKind(current, kind),
          incoming: _entitiesForKind(incoming, kind),
          reportRemovals: reportRemovals,
        ),
      );
    }

    final currentSettings = _settingsFor(current);
    final incomingSettings = _settingsFor(incoming);
    if (currentSettings != null && incomingSettings != null) {
      final before = currentSettings.toJson();
      final after = incomingSettings.toJson();
      summaries.add(
        TransferEntityDiff(
          kind: TransferEntityKind.settings,
          changes: _sameJson(before, after)
              ? const []
              : [
                  TransferEntityChange(
                    kind: TransferEntityKind.settings,
                    type: TransferChangeType.updated,
                    id: 'settings',
                    label: 'settings',
                    before: before,
                    after: after,
                  ),
                ],
        ),
      );
    }

    return TransferDiff(mode: mode, summaries: summaries);
  }

  TransferValidation validate(
    TransferPackage package, {
    TransferPackage? current,
  }) {
    final packageValidation = package.validate();
    final errors = <String>[...packageValidation.errors];
    final warnings = <String>[...packageValidation.warnings];
    if (package.scope == TransferScope.allData &&
        package.profiles.isEmpty &&
        package.courses.isEmpty &&
        package.exams.isEmpty &&
        package.tasks.isEmpty &&
        package.scheduleItems.isEmpty &&
        package.timeSchemes.isEmpty &&
        package.scheduleDateRules.isEmpty &&
        package.locationTimeGroups.isEmpty &&
        package.settings == null) {
      if (!errors.contains('transfer_package_empty')) {
        errors.add('transfer_all_data_empty');
      }
    }
    final incomingCourseIds = {
      ...package.courses.map((item) => item.id),
      ...package.profiles.expand((item) => item.courses).map((item) => item.id),
    };
    final incomingTimeSchemeIds = package.timeSchemes
        .map((item) => item.id)
        .toSet();
    final availableCourseIds = {
      ...incomingCourseIds,
      if (current != null) ..._courseIds(current),
    };
    final availableTimeSchemeIds = {
      ...incomingTimeSchemeIds,
      if (current != null) ..._timeSchemeIds(current),
    };
    void addMissingReference(String message, bool isResolved) {
      if (isResolved) {
        return;
      }
      (current == null ? warnings : errors).add(message);
    }

    final exams = [
      ...package.exams,
      ...package.profiles.expand((profile) => profile.exams),
    ];
    for (final exam in exams) {
      if (exam.courseId.isNotEmpty) {
        addMissingReference(
          'exam_course_missing:${exam.id}',
          availableCourseIds.contains(exam.courseId),
        );
      }
    }
    final tasks = [
      ...package.tasks,
      ...package.profiles.expand((profile) => profile.tasks),
    ];
    for (final task in tasks) {
      if (task.courseId != null) {
        addMissingReference(
          'task_course_missing:${task.id}',
          availableCourseIds.contains(task.courseId),
        );
      }
    }
    for (final rule in package.scheduleDateRules) {
      addMissingReference(
        'time_rule_scheme_missing:${rule.id}',
        rule.timeSchemeId.isNotEmpty &&
            availableTimeSchemeIds.contains(rule.timeSchemeId),
      );
    }
    for (final group in package.locationTimeGroups) {
      addMissingReference(
        'location_scheme_missing:${group.id}',
        group.timeSchemeId.isNotEmpty &&
            availableTimeSchemeIds.contains(group.timeSchemeId),
      );
    }
    final courses = [
      ...package.courses,
      ...package.profiles.expand((profile) => profile.courses),
    ];
    for (final course in courses) {
      final schemeId = course.timeSchemeIdOverride;
      if (schemeId != null && schemeId.isNotEmpty) {
        addMissingReference(
          'course_scheme_missing:${course.id}',
          availableTimeSchemeIds.contains(schemeId),
        );
      }
    }
    return TransferValidation(errors: errors, warnings: warnings);
  }

  static Set<String> _courseIds(TransferPackage package) {
    return {
      ...package.courses.map((item) => item.id),
      ...package.profiles.expand((item) => item.courses).map((item) => item.id),
    };
  }

  static Set<String> _timeSchemeIds(TransferPackage package) {
    return package.timeSchemes.map((item) => item.id).toSet();
  }

  TransferEntityDiff _compareList({
    required TransferEntityKind kind,
    required List<_TransferEntity> current,
    required List<_TransferEntity> incoming,
    required bool reportRemovals,
  }) {
    final currentById = {for (final item in current) item.key: item};
    final incomingById = {for (final item in incoming) item.key: item};
    final changes = <TransferEntityChange>[];

    for (final item in incoming) {
      final before = currentById[item.key];
      if (before == null) {
        changes.add(
          TransferEntityChange(
            kind: kind,
            type: TransferChangeType.added,
            id: item.id,
            label: item.label,
            profileId: item.profileId,
            after: item.json,
          ),
        );
      } else if (!_sameJson(before.json, item.json)) {
        changes.add(
          TransferEntityChange(
            kind: kind,
            type: TransferChangeType.updated,
            id: item.id,
            label: item.label,
            profileId: item.profileId,
            before: before.json,
            after: item.json,
          ),
        );
      }
    }
    if (reportRemovals) {
      for (final item in current) {
        if (!incomingById.containsKey(item.key)) {
          changes.add(
            TransferEntityChange(
              kind: kind,
              type: TransferChangeType.removed,
              id: item.id,
              label: item.label,
              profileId: item.profileId,
              before: item.json,
            ),
          );
        }
      }
    }
    return TransferEntityDiff(kind: kind, changes: changes);
  }

  static List<_TransferEntity> _entitiesForKind(
    TransferPackage package,
    TransferEntityKind kind,
  ) {
    switch (kind) {
      case TransferEntityKind.courses:
        return _flatten(package, (profile) => profile.courses, profileId: true)
          ..addAll(package.courses.map(_TransferEntity.fromCourse));
      case TransferEntityKind.exams:
        return _flatten(package, (profile) => profile.exams, profileId: true)
          ..addAll(package.exams.map(_TransferEntity.fromExam));
      case TransferEntityKind.tasks:
        return _flatten(package, (profile) => profile.tasks, profileId: true)
          ..addAll(package.tasks.map(_TransferEntity.fromTask));
      case TransferEntityKind.scheduleItems:
        return _flatten(package, (profile) => profile.scheduleItems, profileId: true)
          ..addAll(package.scheduleItems.map(_TransferEntity.fromScheduleItem));
      case TransferEntityKind.timeSchemes:
        return package.timeSchemes.map(_TransferEntity.fromTimeScheme).toList();
      case TransferEntityKind.timeRules:
        return package.scheduleDateRules
            .map(_TransferEntity.fromTimeRule)
            .toList();
      case TransferEntityKind.locations:
        return package.locationTimeGroups
            .map(_TransferEntity.fromLocationGroup)
            .toList();
      case TransferEntityKind.settings:
        return const [];
    }
  }

  static TimetableSettings? _settingsFor(TransferPackage package) {
    if (package.settings != null) {
      return package.settings;
    }
    if (package.profiles.length == 1) {
      return package.profiles.single.settings;
    }
    return null;
  }

  static List<_TransferEntity> _flatten<T>(
    TransferPackage package,
    List<T> Function(TimetableProfile) selector, {
    bool profileId = false,
  }) {
    final entities = <_TransferEntity>[];
    for (final profile in package.profiles) {
      for (final value in selector(profile)) {
        final entity = _TransferEntity.fromValue(value as Object);
        entities.add(profileId ? entity.withScope(profile.id) : entity);
      }
    }
    return entities;
  }

  static bool _sameJson(Map<String, dynamic> left, Map<String, dynamic> right) {
    return jsonEncode(_canonicalize(left)) == jsonEncode(_canonicalize(right));
  }

  static Object? _canonicalize(Object? value) {
    if (value is Map) {
      final entries = value.entries.toList()
        ..sort((a, b) => a.key.toString().compareTo(b.key.toString()));
      return <String, Object?>{
        for (final entry in entries)
          entry.key.toString(): _canonicalize(entry.value),
      };
    }
    if (value is Iterable) {
      return value.map(_canonicalize).toList();
    }
    return value;
  }
}

class TransferValidation {
  final List<String> errors;
  final List<String> warnings;

  const TransferValidation({this.errors = const [], this.warnings = const []});

  bool get isValid => errors.isEmpty;
  bool get hasWarnings => warnings.isNotEmpty;
  String? get firstError => errors.isEmpty ? null : errors.first;
}

class _TransferEntity {
  final String id;
  final String label;
  final Map<String, dynamic> json;
  final String? profileId;

  /// Encode both components structurally so IDs containing the separator
  /// cannot alias another profile/entity pair.
  String get key => jsonEncode(<Object?>[profileId, id]);

  const _TransferEntity({
    required this.id,
    required this.label,
    required this.json,
    this.profileId,
  });

  _TransferEntity withScope(String scope) => _TransferEntity(
        id: id,
        label: label,
        json: json,
        profileId: scope,
      );

  factory _TransferEntity.fromValue(Object value) {
    return switch (value) {
      final Course item => _TransferEntity.fromCourse(item),
      final CourseTask item => _TransferEntity.fromTask(item),
      final ScheduleItem item => _TransferEntity.fromScheduleItem(item),
      final Exam item => _TransferEntity.fromExam(item),
      _ => throw ArgumentError('unsupported_transfer_entity'),
    };
  }

  factory _TransferEntity.fromCourse(Course item) =>
      _TransferEntity(id: item.id, label: item.name, json: item.toJson());

  factory _TransferEntity.fromTask(CourseTask item) =>
      _TransferEntity(id: item.id, label: item.title, json: item.toJson());

  factory _TransferEntity.fromScheduleItem(ScheduleItem item) =>
      _TransferEntity(id: item.id, label: item.title, json: item.toJson());

  factory _TransferEntity.fromExam(Exam item) =>
      _TransferEntity(id: item.id, label: item.name, json: item.toJson());

  factory _TransferEntity.fromTimeScheme(TimeScheme item) =>
      _TransferEntity(id: item.id, label: item.name, json: item.toJson());

  factory _TransferEntity.fromTimeRule(ScheduleDateRule item) =>
      _TransferEntity(id: item.id, label: item.name, json: item.toJson());

  factory _TransferEntity.fromLocationGroup(LocationTimeGroup item) =>
      _TransferEntity(id: item.id, label: item.name, json: item.toJson());
}
