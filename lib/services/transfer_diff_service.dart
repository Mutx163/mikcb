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
  final Map<String, dynamic>? before;
  final Map<String, dynamic>? after;

  const TransferEntityChange({
    required this.kind,
    required this.type,
    required this.id,
    required this.label,
    this.before,
    this.after,
  });

  /// Stable, transport-independent text that can be shown in a preview list.
  /// Localization can replace the operation word without re-parsing payloads.
  String get description => '${type.value}: $readableLabel ($id)';

  String get readableLabel => label.trim().isEmpty ? id : label.trim();

  Map<String, dynamic> toJson() => {
    'kind': kind.value,
    'type': type.value,
    'id': id,
    'label': label,
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

  /// The four user-facing categories required by every transfer preview.
  List<TransferEntityDiff> get primarySummaries => [
    for (final kind in primaryKinds) forKind(kind),
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
    'summaries': summaries.map((item) => item.toJson()).toList(),
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
    for (final kind in const [
      TransferEntityKind.courses,
      TransferEntityKind.exams,
      TransferEntityKind.timeRules,
      TransferEntityKind.locations,
      TransferEntityKind.tasks,
      TransferEntityKind.scheduleItems,
      TransferEntityKind.timeSchemes,
    ]) {
      summaries.add(
        _compareList(
          kind: kind,
          current: _entitiesForKind(current, kind),
          incoming: _entitiesForKind(incoming, kind),
          mode: mode,
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

  TransferValidation validate(TransferPackage package) {
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
    final courseIds = {
      ...package.courses.map((item) => item.id),
      ...package.profiles.expand((item) => item.courses).map((item) => item.id),
    };
    final timeSchemeIds = package.timeSchemes.map((item) => item.id).toSet();
    final exams = [
      ...package.exams,
      ...package.profiles.expand((profile) => profile.exams),
    ];
    for (final exam in exams) {
      if (exam.courseId.isNotEmpty && !courseIds.contains(exam.courseId)) {
        warnings.add('exam_course_missing:${exam.id}');
      }
    }
    final tasks = [
      ...package.tasks,
      ...package.profiles.expand((profile) => profile.tasks),
    ];
    for (final task in tasks) {
      if (task.courseId != null && !courseIds.contains(task.courseId)) {
        warnings.add('task_course_missing:${task.id}');
      }
    }
    for (final rule in package.scheduleDateRules) {
      if (rule.timeSchemeId.isEmpty ||
          !timeSchemeIds.contains(rule.timeSchemeId)) {
        warnings.add('time_rule_scheme_missing:${rule.id}');
      }
    }
    for (final group in package.locationTimeGroups) {
      if (group.timeSchemeId.isEmpty ||
          !timeSchemeIds.contains(group.timeSchemeId)) {
        warnings.add('location_scheme_missing:${group.id}');
      }
    }
    final courses = [
      ...package.courses,
      ...package.profiles.expand((profile) => profile.courses),
    ];
    for (final course in courses) {
      final schemeId = course.timeSchemeIdOverride;
      if (schemeId != null &&
          schemeId.isNotEmpty &&
          !timeSchemeIds.contains(schemeId)) {
        warnings.add('course_scheme_missing:${course.id}');
      }
    }
    return TransferValidation(errors: errors, warnings: warnings);
  }

  TransferEntityDiff _compareList({
    required TransferEntityKind kind,
    required List<_TransferEntity> current,
    required List<_TransferEntity> incoming,
    required TransferApplyMode mode,
  }) {
    final currentById = {for (final item in current) item.id: item};
    final incomingById = {for (final item in incoming) item.id: item};
    final changes = <TransferEntityChange>[];

    for (final item in incoming) {
      final before = currentById[item.id];
      if (before == null) {
        changes.add(
          TransferEntityChange(
            kind: kind,
            type: TransferChangeType.added,
            id: item.id,
            label: item.label,
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
            before: before.json,
            after: item.json,
          ),
        );
      }
    }
    if (mode == TransferApplyMode.overwrite) {
      for (final item in current) {
        if (!incomingById.containsKey(item.id)) {
          changes.add(
            TransferEntityChange(
              kind: kind,
              type: TransferChangeType.removed,
              id: item.id,
              label: item.label,
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
        return _flatten(package, (profile) => profile.courses)
          ..addAll(package.courses.map(_TransferEntity.fromCourse));
      case TransferEntityKind.exams:
        return _flatten(package, (profile) => profile.exams)
          ..addAll(package.exams.map(_TransferEntity.fromExam));
      case TransferEntityKind.tasks:
        return _flatten(package, (profile) => profile.tasks)
          ..addAll(package.tasks.map(_TransferEntity.fromTask));
      case TransferEntityKind.scheduleItems:
        return _flatten(package, (profile) => profile.scheduleItems)
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
    List<T> Function(TimetableProfile) selector,
  ) {
    final values = <T>[];
    for (final profile in package.profiles) {
      values.addAll(selector(profile));
    }
    return values
        .map((value) => _TransferEntity.fromValue(value as Object))
        .toList();
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

  const _TransferEntity({
    required this.id,
    required this.label,
    required this.json,
  });

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
