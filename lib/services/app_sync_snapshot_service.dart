import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../models/holiday_entry.dart';
import '../models/location_time_group.dart';
import '../models/partner_timetable_binding.dart';
import '../models/schedule_date_rule.dart';
import '../models/time_scheme.dart';
import '../models/timetable_profile.dart';
import '../models/warehouse_macro_models.dart';
import '../providers/timetable_provider.dart';
import 'app_log_service.dart';
import 'data_transfer_service.dart';
import 'holiday_service.dart';
import 'storage_service.dart';
import 'transfer_diff_service.dart';
import 'transfer_package.dart';
import 'unified_transfer_service.dart';
import 'warehouse_import_preferences_service.dart';
import 'warehouse_macro_service.dart';

class AppSyncSnapshot {
  final List<TimetableProfile> profiles;
  final String? activeProfileId;
  final List<TimeScheme> timeSchemes;
  final List<LocationTimeGroup> locationTimeGroups;
  final List<ScheduleDateRule> scheduleDateRules;
  final List<String> teacherRecords;
  final List<String> locationRecords;
  final WarehouseSyncBundle warehouse;
  final List<WarehouseMacroRecord> macros;
  final List<HolidayEntry> customHolidays;
  final DateTime exportedAt;
  final String deviceId;
  final String contentSha256;
  final PartnerTimetableBinding? partnerTimetableBinding;
  final bool includesPartnerTimetableBinding;

  /// Last successful seasonal date-rule bulk-apply signature (ruleId|scheme|range).
  /// Absent on older snapshots; treated as null so apply can re-run once if needed.
  final String? scheduleDateRuleLastAppliedSignature;

  const AppSyncSnapshot({
    required this.profiles,
    required this.activeProfileId,
    required this.timeSchemes,
    this.locationTimeGroups = const [],
    this.scheduleDateRules = const [],
    required this.teacherRecords,
    required this.locationRecords,
    required this.warehouse,
    required this.macros,
    required this.customHolidays,
    required this.exportedAt,
    required this.deviceId,
    required this.contentSha256,
    this.partnerTimetableBinding,
    this.includesPartnerTimetableBinding = false,
    this.scheduleDateRuleLastAppliedSignature,
  });

  /// True when this snapshot contains user-authored business data that must
  /// not be silently overwritten on first-sync background pull.
  ///
  /// Covers full snapshot identity fields (courses, schemes, place-routing,
  /// date rules, warehouse prefs, macros, holidays, partner binding), not
  /// only non-empty timetable lists.
  bool get hasUserAuthoredData {
    if (teacherRecords.isNotEmpty || locationRecords.isNotEmpty) {
      return true;
    }
    if (locationTimeGroups.isNotEmpty || scheduleDateRules.isNotEmpty) {
      return true;
    }
    if (customHolidays.isNotEmpty || macros.isNotEmpty) {
      return true;
    }
    if (partnerTimetableBinding != null) {
      return true;
    }
    if (warehouse.rememberedLogins.isNotEmpty ||
        warehouse.customImportUrls.isNotEmpty ||
        warehouse.recentSchoolIds.isNotEmpty ||
        warehouse.customDebugRecords.isNotEmpty) {
      return true;
    }
    if (timeSchemes.length > 1) {
      return true;
    }
    if (profiles.length > 1) {
      return true;
    }
    for (final profile in profiles) {
      if (profile.courses.isNotEmpty ||
          profile.exams.isNotEmpty ||
          profile.scheduleItems.isNotEmpty) {
        return true;
      }
      if (profile.isPartnerImported) {
        return true;
      }
      // Renamed away from the factory default profile name.
      if (profile.name.trim().isNotEmpty && profile.name.trim() != '默认课表') {
        return true;
      }
    }
    return false;
  }
}

class AppSyncSnapshotMeta {
  final DateTime exportedAt;
  final String contentSha256;
  final String deviceId;
  final String? appVersion;

  const AppSyncSnapshotMeta({
    required this.exportedAt,
    required this.contentSha256,
    required this.deviceId,
    this.appVersion,
  });

  Map<String, dynamic> toJson() => {
    'exportedAt': exportedAt.toIso8601String(),
    'contentSha256': contentSha256,
    'deviceId': deviceId,
    if (appVersion != null) 'appVersion': appVersion,
  };

  factory AppSyncSnapshotMeta.fromJson(Map<String, dynamic> json) {
    return AppSyncSnapshotMeta(
      exportedAt:
          DateTime.tryParse(json['exportedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      contentSha256: json['contentSha256'] as String? ?? '',
      deviceId: json['deviceId'] as String? ?? '',
      appVersion: json['appVersion'] as String?,
    );
  }
}

class AppSyncSnapshotService {
  static const int schemaVersion = 2;
  static const String backupType = 'sync';

  AppSyncSnapshotService({
    StorageService? storageService,
    WarehouseImportPreferencesService? warehousePreferencesService,
    WarehouseMacroService? warehouseMacroService,
    HolidayService? holidayService,
    DataTransferService? dataTransferService,
  }) : _storageService = storageService ?? StorageService(),
       _warehousePreferencesService =
           warehousePreferencesService ?? WarehouseImportPreferencesService(),
       _warehouseMacroService =
           warehouseMacroService ?? WarehouseMacroService(),
       _holidayService = holidayService ?? HolidayService(),
       _dataTransferService = dataTransferService ?? DataTransferService();

  final StorageService _storageService;
  final WarehouseImportPreferencesService _warehousePreferencesService;
  final WarehouseMacroService _warehouseMacroService;
  final HolidayService _holidayService;
  final DataTransferService _dataTransferService;
  final TransferDiffService _transferDiffService = const TransferDiffService();
  late final UnifiedTransferService _unifiedTransferService =
      UnifiedTransferService(dataTransferService: _dataTransferService);
  AppSyncSnapshot? _lastRollbackSnapshot;
  String? _lastRollbackId;

  Future<AppSyncSnapshot> collectSnapshot({
    required TimetableProvider provider,
    required String deviceId,
    DateTime? exportedAt,
  }) async {
    await provider.initialize();
    final warehouse = await _warehousePreferencesService.exportSyncBundle();
    final macros = await _warehouseMacroService.exportAllMacros();
    final customHolidays = await _holidayService.loadCustomHolidays();
    final teacherRecords = await _storageService.getTeacherRecords();
    final locationRecords = await _storageService.getLocationRecords();
    final partnerTimetableBinding = await _storageService
        .getPartnerTimetableBinding();
    final timestamp = exportedAt ?? DateTime.now();

    final profilesForSync = stripLiveTestingFixtureCourses(provider.profiles);
    final lastAppliedSignature = provider.scheduleDateRuleLastAppliedSignature;

    final payload = _buildPayloadMap(
      profiles: profilesForSync,
      activeProfileId: provider.activeProfileId,
      timeSchemes: provider.timeSchemes,
      locationTimeGroups: provider.locationTimeGroups,
      scheduleDateRules: provider.scheduleDateRules,
      teacherRecords: teacherRecords,
      locationRecords: locationRecords,
      warehouse: warehouse,
      macros: macros,
      customHolidays: customHolidays,
      exportedAt: timestamp,
      deviceId: deviceId,
      partnerTimetableBinding: partnerTimetableBinding,
      scheduleDateRuleLastAppliedSignature: lastAppliedSignature,
    );
    final contentSha256 = computeContentSha256(payload);

    return AppSyncSnapshot(
      profiles: profilesForSync,
      activeProfileId: provider.activeProfileId,
      timeSchemes: provider.timeSchemes,
      locationTimeGroups: provider.locationTimeGroups,
      scheduleDateRules: provider.scheduleDateRules,
      teacherRecords: teacherRecords,
      locationRecords: locationRecords,
      warehouse: warehouse,
      macros: macros,
      customHolidays: customHolidays,
      exportedAt: timestamp,
      deviceId: deviceId,
      contentSha256: contentSha256,
      partnerTimetableBinding: partnerTimetableBinding,
      includesPartnerTimetableBinding: true,
      scheduleDateRuleLastAppliedSignature: lastAppliedSignature,
    );
  }

  Future<String> buildSnapshotJson({
    required TimetableProvider provider,
    required String deviceId,
    DateTime? exportedAt,
  }) async {
    final snapshot = await collectSnapshot(
      provider: provider,
      deviceId: deviceId,
      exportedAt: exportedAt,
    );
    return buildSnapshotJsonFromSnapshot(snapshot);
  }

  String buildSnapshotJsonFromSnapshot(AppSyncSnapshot snapshot) {
    final payload = _buildPayloadMap(
      profiles: snapshot.profiles,
      activeProfileId: snapshot.activeProfileId,
      timeSchemes: snapshot.timeSchemes,
      locationTimeGroups: snapshot.locationTimeGroups,
      scheduleDateRules: snapshot.scheduleDateRules,
      teacherRecords: snapshot.teacherRecords,
      locationRecords: snapshot.locationRecords,
      warehouse: snapshot.warehouse,
      macros: snapshot.macros,
      customHolidays: snapshot.customHolidays,
      exportedAt: snapshot.exportedAt,
      deviceId: snapshot.deviceId,
      partnerTimetableBinding: snapshot.partnerTimetableBinding,
      scheduleDateRuleLastAppliedSignature:
          snapshot.scheduleDateRuleLastAppliedSignature,
    );
    payload['contentSha256'] = snapshot.contentSha256;
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  AppSyncSnapshotMeta buildMetaFromSnapshot(
    AppSyncSnapshot snapshot, {
    String? appVersion,
  }) {
    return AppSyncSnapshotMeta(
      exportedAt: snapshot.exportedAt,
      contentSha256: snapshot.contentSha256,
      deviceId: snapshot.deviceId,
      appVersion: appVersion,
    );
  }

  AppSyncSnapshot parseSnapshotJson(String content) {
    final json = jsonDecode(content) as Map<String, dynamic>;
    final app = json['app'] as String?;
    final version = (json['schemaVersion'] as num?)?.toInt() ?? 0;
    final type = json['backupType'] as String?;

    if (app != 'mikcb' || version != schemaVersion || type != backupType) {
      throw const FormatException('unrecognized_sync_snapshot');
    }

    final rawProfiles = json['profiles'];
    final rawTimeSchemes = json['timeSchemes'];
    if (rawProfiles is! List || rawTimeSchemes is! List) {
      throw const FormatException('missing_sync_timetable_data');
    }

    final payload = Map<String, dynamic>.from(json)..remove('contentSha256');
    final expectedHash = json['contentSha256'] as String? ?? '';
    final actualHash = computeContentSha256(payload);
    if (expectedHash.isNotEmpty && expectedHash != actualHash) {
      throw const FormatException('sync_snapshot_checksum_failed');
    }

    final warehouseRaw = json['warehouse'];
    final warehouse = warehouseRaw is Map
        ? WarehouseSyncBundle.fromJson(Map<String, dynamic>.from(warehouseRaw))
        : const WarehouseSyncBundle();

    final includesPartnerTimetableBinding = json.containsKey(
      'partnerTimetableBinding',
    );
    PartnerTimetableBinding? partnerTimetableBinding;
    final rawPartnerBinding = json['partnerTimetableBinding'];
    if (includesPartnerTimetableBinding && rawPartnerBinding is Map) {
      partnerTimetableBinding = PartnerTimetableBinding.fromJson(
        Map<String, dynamic>.from(rawPartnerBinding),
      );
    }

    return AppSyncSnapshot(
      profiles: rawProfiles
          .map(
            (item) => TimetableProfile.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList()
          .map(_stripLiveTestingFixtureCoursesFromProfile)
          .toList(),
      activeProfileId: json['activeProfileId'] as String?,
      timeSchemes: rawTimeSchemes
          .map(
            (item) =>
                TimeScheme.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList(),
      locationTimeGroups:
          (json['locationTimeGroups'] as List<dynamic>? ?? const [])
              .whereType<Map>()
              .map(
                (item) =>
                    LocationTimeGroup.fromJson(Map<String, dynamic>.from(item)),
              )
              .toList(),
      scheduleDateRules:
          (json['scheduleDateRules'] as List<dynamic>? ?? const [])
              .whereType<Map>()
              .map(
                (item) =>
                    ScheduleDateRule.fromJson(Map<String, dynamic>.from(item)),
              )
              .toList(),
      teacherRecords: (json['teacherRecords'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .where((item) => item.isNotEmpty)
          .toList(),
      locationRecords: (json['locationRecords'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .where((item) => item.isNotEmpty)
          .toList(),
      warehouse: warehouse,
      macros:
          (json['warehouse']?['macros'] as List<dynamic>? ??
                  json['macros'] as List<dynamic>? ??
                  const [])
              .whereType<Map>()
              .map(
                (item) => WarehouseMacroRecord.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList(),
      customHolidays: (json['customHolidays'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((item) => HolidayEntry.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
      exportedAt:
          DateTime.tryParse(json['exportedAt'] as String? ?? '') ??
          DateTime.now(),
      deviceId: json['deviceId'] as String? ?? '',
      contentSha256: expectedHash.isEmpty ? actualHash : expectedHash,
      partnerTimetableBinding: partnerTimetableBinding,
      includesPartnerTimetableBinding: includesPartnerTimetableBinding,
      scheduleDateRuleLastAppliedSignature:
          (json['scheduleDateRuleLastAppliedSignature'] as String?)
                  ?.trim()
                  .isEmpty ==
              true
          ? null
          : (json['scheduleDateRuleLastAppliedSignature'] as String?)?.trim(),
    );
  }

  AppSyncSnapshotMeta parseMetaJson(String content) {
    final json = jsonDecode(content) as Map<String, dynamic>;
    return AppSyncSnapshotMeta.fromJson(json);
  }

  String buildMetaJson(AppSyncSnapshotMeta meta) {
    return const JsonEncoder.withIndent('  ').convert(meta.toJson());
  }

  /// Builds the same entity-level preview used by file, QR and LAN imports.
  /// Cloud snapshots retain their existing envelope because they also carry
  /// warehouse, holiday and partner-binding data outside the timetable core.
  /// Converts a cloud snapshot to the same transport-neutral package used by
  /// file, QR and LAN previews. Extra cloud fields stay on [AppSyncSnapshot]
  /// and are applied by this service after the timetable core is validated.
  TransferPackage buildTransferPackageFromSnapshot({
    required AppSyncSnapshot snapshot,
    TransferChannel channel = TransferChannel.cloud,
  }) {
    return _buildTransferPackage(
      profiles: snapshot.profiles,
      activeProfileId: snapshot.activeProfileId,
      timeSchemes: snapshot.timeSchemes,
      scheduleDateRules: snapshot.scheduleDateRules,
      locationTimeGroups: snapshot.locationTimeGroups,
    ).copyWith(channel: channel);
  }

  /// Builds the active profile as a scoped package for an explicit merge.
  /// Cloud snapshots may contain several profiles, while a merge must not
  /// replace unrelated local profiles.
  TransferPackage buildMergeTransferPackageFromSnapshot({
    required AppSyncSnapshot snapshot,
    TransferChannel channel = TransferChannel.cloud,
  }) {
    if (snapshot.profiles.isEmpty) {
      throw const FormatException('sync_snapshot_no_profiles');
    }
    final profile = snapshot.profiles.firstWhere(
      (item) => item.id == snapshot.activeProfileId,
      orElse: () => snapshot.profiles.first,
    );
    return _dataTransferService.buildTransferPackage(
      scope: TransferScope.currentTimetable,
      channel: channel,
      profileName: profile.name,
      courses: profile.courses,
      tasks: profile.tasks,
      scheduleItems: profile.scheduleItems,
      exams: profile.exams,
      settings: profile.settings,
      currentWeek: profile.currentWeek,
      timeSchemes: snapshot.timeSchemes,
      scheduleDateRules: snapshot.scheduleDateRules,
      locationTimeGroups: snapshot.locationTimeGroups,
    );
  }

  TransferDiff previewSnapshot({
    required TimetableProvider provider,
    required AppSyncSnapshot snapshot,
    TransferApplyMode mode = TransferApplyMode.overwrite,
  }) {
    final current = _buildTransferPackage(
      profiles: provider.profiles,
      activeProfileId: provider.activeProfileId,
      timeSchemes: provider.timeSchemes,
      scheduleDateRules: provider.scheduleDateRules,
      locationTimeGroups: provider.locationTimeGroups,
    );
    final incoming = mode == TransferApplyMode.merge
        ? buildMergeTransferPackageFromSnapshot(snapshot: snapshot)
        : buildTransferPackageFromSnapshot(snapshot: snapshot);
    return _transferDiffService.compare(
      current: current,
      incoming: incoming,
      mode: mode,
    );
  }

  Future<String?> applySnapshot({
    required TimetableProvider provider,
    required AppSyncSnapshot snapshot,
    TransferPackage? transferPackage,
  }) {
    return provider.runMutationExclusive(() async {
      if (snapshot.profiles.isEmpty) {
        return 'sync_snapshot_no_profiles';
      }

      AppSyncSnapshot? rollbackSnapshot;
      String? applyError;
      final incomingPackage =
          transferPackage ??
          buildTransferPackageFromSnapshot(snapshot: snapshot);
      final preview = previewSnapshot(provider: provider, snapshot: snapshot);
      final undoId = TransferPackage.newPackageId();
      try {
        rollbackSnapshot = await _captureRollbackSnapshot(provider);
        await AppLogService.instance.info(
          'cloud_transfer_restore_started',
          'cloud transfer restore started',
          extras: {
            'contentSha256': snapshot.contentSha256,
            'transferId': incomingPackage.packageId,
            'channel': incomingPackage.channel.value,
            'scope': incomingPackage.scope.value,
            'mode': TransferApplyMode.overwrite.name,
            'undoId': undoId,
            'added': preview.addedCount,
            'updated': preview.updatedCount,
            'removed': preview.removedCount,
          },
        );

        // Keep cloud-only fields (warehouse, holidays and partner binding)
        // in the snapshot applier; the package is the shared schema/diff
        // boundary and has already been previewed above.
        applyError = await _applySnapshotData(
          provider: provider,
          snapshot: snapshot,
        );
        if (applyError != null) {
          throw StateError(applyError);
        }

        _lastRollbackSnapshot = rollbackSnapshot;
        _lastRollbackId = undoId;
        await AppLogService.instance.info(
          'cloud_transfer_restore_completed',
          'cloud transfer restore completed',
          extras: {
            'contentSha256': snapshot.contentSha256,
            'transferId': incomingPackage.packageId,
            'channel': incomingPackage.channel.value,
            'scope': incomingPackage.scope.value,
            'mode': TransferApplyMode.overwrite.name,
            'undoId': undoId,
            'added': preview.addedCount,
            'updated': preview.updatedCount,
            'removed': preview.removedCount,
          },
        );
        return null;
      } catch (error, stackTrace) {
        if (rollbackSnapshot != null) {
          try {
            await _applySnapshotData(
              provider: provider,
              snapshot: rollbackSnapshot,
            );
          } catch (rollbackError, rollbackStackTrace) {
            await AppLogService.instance.error(
              'cloud_transfer_rollback_failed',
              'cloud transfer rollback failed',
              error: rollbackError,
              stackTrace: rollbackStackTrace,
              extras: {'contentSha256': snapshot.contentSha256},
            );
          }
        }
        await AppLogService.instance.error(
          'cloud_transfer_restore_failed',
          'cloud transfer restore failed',
          error: error,
          stackTrace: stackTrace,
          extras: {
            'contentSha256': snapshot.contentSha256,
            'transferId': incomingPackage.packageId,
            'channel': incomingPackage.channel.value,
            'scope': incomingPackage.scope.value,
            'mode': TransferApplyMode.overwrite.name,
            'undoId': undoId,
            'added': preview.addedCount,
            'updated': preview.updatedCount,
            'removed': preview.removedCount,
          },
        );
        return applyError ?? 'sync_snapshot_apply_failed';
      }
    });
  }

  /// Applies a cloud snapshot through the shared transfer service when the
  /// caller explicitly selected merge. The rollback snapshot still includes
  /// cloud-only data so undo remains lossless.
  Future<String?> applySnapshotWithMode({
    required TimetableProvider provider,
    required AppSyncSnapshot snapshot,
    required TransferApplyMode mode,
    TransferPackage? transferPackage,
  }) async {
    if (mode == TransferApplyMode.overwrite) {
      return applySnapshot(
        provider: provider,
        snapshot: snapshot,
        transferPackage: transferPackage,
      );
    }

    return provider.runMutationExclusive(() async {
      final package =
          transferPackage ??
          buildMergeTransferPackageFromSnapshot(snapshot: snapshot);
      final current = _unifiedTransferService.buildCurrentPackage(
        provider: provider,
        channel: TransferChannel.cloud,
      );
      final preview = _transferDiffService.compare(
        current: current,
        incoming: package,
        mode: mode,
      );
      final rollback = await _captureRollbackSnapshot(provider);
      final undoId = TransferPackage.newPackageId();
      await AppLogService.instance.info(
        'cloud_transfer_restore_started',
        'cloud transfer restore started',
        extras: {
          'transferId': package.packageId,
          'channel': package.channel.value,
          'scope': package.scope.value,
          'mode': mode.name,
          'undoId': undoId,
          'added': preview.addedCount,
          'updated': preview.updatedCount,
          'removed': preview.removedCount,
        },
      );
      try {
        final result = await _unifiedTransferService.applyToProvider(
          provider: provider,
          incoming: package,
          mode: mode,
          current: current,
        );
        if (!result.applied) {
          return result.error ?? 'sync_snapshot_apply_failed';
        }
        _lastRollbackSnapshot = rollback;
        _lastRollbackId = undoId;
        await AppLogService.instance.info(
          'cloud_transfer_restore_completed',
          'cloud transfer restore completed',
          extras: {
            'transferId': package.packageId,
            'channel': package.channel.value,
            'scope': package.scope.value,
            'mode': mode.name,
            'undoId': undoId,
            'added': preview.addedCount,
            'updated': preview.updatedCount,
            'removed': preview.removedCount,
          },
        );
        return null;
      } catch (error, stackTrace) {
        try {
          await _applySnapshotData(provider: provider, snapshot: rollback);
        } catch (rollbackError, rollbackStackTrace) {
          await AppLogService.instance.error(
            'cloud_transfer_rollback_failed',
            'cloud transfer rollback failed',
            error: rollbackError,
            stackTrace: rollbackStackTrace,
            extras: {'transferId': package.packageId, 'undoId': undoId},
          );
        }
        await AppLogService.instance.error(
          'cloud_transfer_restore_failed',
          'cloud transfer restore failed',
          error: error,
          stackTrace: stackTrace,
          extras: {
            'transferId': package.packageId,
            'channel': package.channel.value,
            'scope': package.scope.value,
            'mode': mode.name,
            'undoId': undoId,
            'added': preview.addedCount,
            'updated': preview.updatedCount,
            'removed': preview.removedCount,
          },
        );
        return 'sync_snapshot_apply_failed';
      }
    });
  }

  /// Reverts the most recent cloud apply during this process session.
  Future<bool> undoLastApply({required TimetableProvider provider}) async {
    final rollbackSnapshot = _lastRollbackSnapshot;
    if (rollbackSnapshot == null) {
      return false;
    }
    try {
      await provider.runMutationExclusive(() async {
        final error = await _applySnapshotData(
          provider: provider,
          snapshot: rollbackSnapshot,
        );
        if (error != null) {
          throw StateError(error);
        }
      });
      final undoId = _lastRollbackId;
      _lastRollbackSnapshot = null;
      _lastRollbackId = null;
      await AppLogService.instance.info(
        'cloud_transfer_restore_undone',
        'cloud transfer restore undone',
        extras: {'undoId': ?undoId},
      );
      return true;
    } catch (error, stackTrace) {
      await AppLogService.instance.error(
        'cloud_transfer_undo_failed',
        'cloud transfer undo failed',
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  Future<String?> _applySnapshotData({
    required TimetableProvider provider,
    required AppSyncSnapshot snapshot,
  }) async {
    // Seed location groups (and schemes) before profile import so
    // _syncCoursesWithEffectiveTimeSchemes resolves remote place-routing
    // instead of rewriting clocks with the device's previous groups (B1).
    // resync:false avoids applying rules against the still-local profile list.
    await provider.replaceLocationTimeGroups(
      snapshot.locationTimeGroups,
      resync: false,
    );
    await provider.replaceScheduleDateRules(
      snapshot.scheduleDateRules,
      resync: false,
    );

    final fullBackupJson = _dataTransferService.buildFullBackupJson(
      profiles: snapshot.profiles,
      activeProfileId: snapshot.activeProfileId,
      timeSchemes: snapshot.timeSchemes,
      scheduleDateRules: snapshot.scheduleDateRules,
      locationTimeGroups: snapshot.locationTimeGroups,
      channel: TransferChannel.cloud,
    );
    final timetableError = await provider.importFullAppDataBackup(
      fullBackupJson,
    );
    if (timetableError != null) {
      return timetableError;
    }

    await _storageService.saveTeacherRecords(snapshot.teacherRecords);
    await _storageService.saveLocationRecords(snapshot.locationRecords);
    await _storageService.saveLocationTimeGroups(snapshot.locationTimeGroups);
    await _storageService.saveScheduleDateRules(snapshot.scheduleDateRules);
    await _storageService.saveScheduleDateRuleLastAppliedSignature(
      snapshot.scheduleDateRuleLastAppliedSignature,
    );
    await _warehousePreferencesService.importSyncBundle(snapshot.warehouse);
    await _warehouseMacroService.importAllMacros(snapshot.macros);
    await _holidayService.saveCustomHolidays(snapshot.customHolidays);

    if (snapshot.includesPartnerTimetableBinding) {
      await _storageService.savePartnerTimetableBinding(
        snapshot.partnerTimetableBinding,
      );
    }

    // Force full in-memory reload: initialize() is process-idempotent and
    // would skip partner/teachers/locations after the first start (C4).
    await provider.reloadFromStorageAfterExternalApply();
    return null;
  }

  Future<AppSyncSnapshot> _captureRollbackSnapshot(
    TimetableProvider provider,
  ) async {
    final externalData = await collectSnapshot(
      provider: provider,
      deviceId: 'local-rollback',
    );
    final now = DateTime.now();
    return AppSyncSnapshot(
      profiles: List<TimetableProfile>.from(provider.profiles),
      activeProfileId: provider.activeProfileId,
      timeSchemes: List<TimeScheme>.from(provider.timeSchemes),
      locationTimeGroups: List<LocationTimeGroup>.from(
        provider.locationTimeGroups,
      ),
      scheduleDateRules: List<ScheduleDateRule>.from(
        provider.scheduleDateRules,
      ),
      teacherRecords: List<String>.from(externalData.teacherRecords),
      locationRecords: List<String>.from(externalData.locationRecords),
      warehouse: externalData.warehouse,
      macros: List<WarehouseMacroRecord>.from(externalData.macros),
      customHolidays: List<HolidayEntry>.from(externalData.customHolidays),
      exportedAt: now,
      deviceId: 'local-rollback',
      contentSha256: '',
      partnerTimetableBinding: externalData.partnerTimetableBinding,
      includesPartnerTimetableBinding:
          externalData.includesPartnerTimetableBinding,
      scheduleDateRuleLastAppliedSignature:
          provider.scheduleDateRuleLastAppliedSignature,
    );
  }

  TransferPackage _buildTransferPackage({
    required List<TimetableProfile> profiles,
    required String? activeProfileId,
    required List<TimeScheme> timeSchemes,
    required List<ScheduleDateRule> scheduleDateRules,
    required List<LocationTimeGroup> locationTimeGroups,
  }) {
    return _dataTransferService.buildTransferPackage(
      scope: TransferScope.allData,
      channel: TransferChannel.cloud,
      profiles: profiles,
      activeProfileId: activeProfileId,
      timeSchemes: timeSchemes,
      scheduleDateRules: scheduleDateRules,
      locationTimeGroups: locationTimeGroups,
      isFullBackup: true,
    );
  }

  Future<String?> applySnapshotJson({
    required TimetableProvider provider,
    required String content,
  }) async {
    try {
      final snapshot = parseSnapshotJson(content);
      return applySnapshot(provider: provider, snapshot: snapshot);
    } on FormatException catch (error) {
      return error.message;
    } catch (_) {
      return 'sync_snapshot_unrecognized';
    }
  }

  /// Content identity for sync baseline / conflict detection.
  ///
  /// Excludes [exportedAt] and [deviceId] so collecting the same business
  /// data at different times does not look like a local change (C2).
  static String computeContentSha256(Map<String, dynamic> payload) {
    final forHash = Map<String, dynamic>.from(payload)
      ..remove('exportedAt')
      ..remove('deviceId')
      ..remove('contentSha256');
    final canonical = jsonEncode(_canonicalize(forHash));
    return sha256.convert(utf8.encode(canonical)).toString();
  }

  static Map<String, dynamic> _buildPayloadMap({
    required List<TimetableProfile> profiles,
    required String? activeProfileId,
    required List<TimeScheme> timeSchemes,
    List<LocationTimeGroup> locationTimeGroups = const [],
    List<ScheduleDateRule> scheduleDateRules = const [],
    required List<String> teacherRecords,
    required List<String> locationRecords,
    required WarehouseSyncBundle warehouse,
    required List<WarehouseMacroRecord> macros,
    required List<HolidayEntry> customHolidays,
    required DateTime exportedAt,
    required String deviceId,
    PartnerTimetableBinding? partnerTimetableBinding,
    String? scheduleDateRuleLastAppliedSignature,
  }) {
    return {
      'app': 'mikcb',
      'schemaVersion': schemaVersion,
      'backupType': backupType,
      'exportedAt': exportedAt.toIso8601String(),
      'deviceId': deviceId,
      'activeProfileId': activeProfileId,
      'profiles': profiles.map((profile) => profile.toJson()).toList(),
      'timeSchemes': timeSchemes.map((scheme) => scheme.toJson()).toList(),
      'locationTimeGroups': locationTimeGroups
          .map((group) => group.toJson())
          .toList(),
      'scheduleDateRules': scheduleDateRules
          .map((rule) => rule.toJson())
          .toList(),
      'scheduleDateRuleLastAppliedSignature':
          scheduleDateRuleLastAppliedSignature,
      'teacherRecords': teacherRecords,
      'locationRecords': locationRecords,
      // Never put teaching-system passwords into cloud sync JSON (C3).
      'warehouse': {
        ...warehouse.withoutPasswords().toJson(),
        'macros': macros.map((macro) => macro.toJson()).toList(),
      },
      'customHolidays': customHolidays.map((entry) => entry.toJson()).toList(),
      'partnerTimetableBinding': partnerTimetableBinding?.toJson(),
    };
  }

  /// Drops debug-only `live_test_*` courses so they never leave the device via cloud sync.
  static List<TimetableProfile> stripLiveTestingFixtureCourses(
    List<TimetableProfile> profiles,
  ) {
    return profiles.map(_stripLiveTestingFixtureCoursesFromProfile).toList();
  }

  static TimetableProfile _stripLiveTestingFixtureCoursesFromProfile(
    TimetableProfile profile,
  ) {
    final filtered = profile.courses
        .where((course) => !course.id.startsWith('live_test_'))
        .toList();
    if (filtered.length == profile.courses.length) {
      return profile;
    }
    return profile.copyWith(courses: filtered);
  }

  static dynamic _canonicalize(dynamic value) {
    if (value is Map) {
      final keys = value.keys.map((key) => key.toString()).toList()..sort();
      return {for (final key in keys) key: _canonicalize(value[key])};
    }
    if (value is List) {
      return value.map(_canonicalize).toList();
    }
    return value;
  }
}

enum SyncConflictChoice { keepLocal, keepRemote, cancel }

class SyncConflictInfo {
  final DateTime localExportedAt;
  final DateTime remoteExportedAt;
  final String localHash;
  final String remoteHash;

  const SyncConflictInfo({
    required this.localExportedAt,
    required this.remoteExportedAt,
    required this.localHash,
    required this.remoteHash,
  });
}

SyncConflictChoice resolveSyncConflictAutomatically(SyncConflictInfo info) {
  if (info.remoteExportedAt.isAfter(info.localExportedAt)) {
    return SyncConflictChoice.keepRemote;
  }
  if (info.localExportedAt.isAfter(info.remoteExportedAt)) {
    return SyncConflictChoice.keepLocal;
  }
  return info.remoteHash.compareTo(info.localHash) >= 0
      ? SyncConflictChoice.keepRemote
      : SyncConflictChoice.keepLocal;
}

/// Background / auto-pull path: never silently upload local over remote (C1).
///
/// Local [exportedAt] is often `DateTime.now()` at collect time, so LWW would
/// prefer empty new devices and wipe the cloud. Prefer remote without UI.
///
/// Callers must still refuse first-sync divergence when local already has
/// user data (see [webdavBackgroundPullShouldCancel]) — this helper alone
/// must not be used to silently wipe a non-empty device.
SyncConflictChoice resolveSyncConflictForBackground(SyncConflictInfo info) {
  final automatic = resolveSyncConflictAutomatically(info);
  if (automatic == SyncConflictChoice.keepLocal) {
    return SyncConflictChoice.keepRemote;
  }
  return automatic;
}

/// Whether background auto-pull must cancel instead of applying remote.
///
/// Protects non-empty local data on first sync (no baseline hashes) and when
/// local has diverged from last upload without a UI conflict prompt.
bool webdavBackgroundPullShouldCancel({
  required String? lastUploadedLocalHash,
  required String? lastAppliedRemoteHash,
  required String localContentSha256,
  required bool localHasUserData,
}) {
  final isFirstSyncWithoutBaseline =
      lastUploadedLocalHash == null && lastAppliedRemoteHash == null;
  if (isFirstSyncWithoutBaseline && localHasUserData) {
    return true;
  }
  final localChangedSinceUpload =
      lastUploadedLocalHash != null &&
      localContentSha256 != lastUploadedLocalHash;
  return localChangedSinceUpload;
}

/// Whether auto-upload may PUT over the current remote snapshot.
///
/// Auto path must never silently overwrite a remote that drifted away from
/// our last known baseline (last applied / last uploaded hash).
enum WebdavAutoUploadDecision {
  /// Remote missing or still our baseline — PUT allowed.
  allow,

  /// Remote content already matches local — skip upload.
  upToDate,

  /// Remote changed by another client — do not PUT.
  remoteDrifted,
}

WebdavAutoUploadDecision decideWebdavAutoUpload({
  required String? remoteContentSha256,
  required String? lastAppliedRemoteHash,
  required String? lastUploadedLocalHash,
  required String localContentSha256,
}) {
  final remoteHash = remoteContentSha256?.trim();
  if (remoteHash == null || remoteHash.isEmpty) {
    return WebdavAutoUploadDecision.allow;
  }
  if (remoteHash == localContentSha256) {
    return WebdavAutoUploadDecision.upToDate;
  }
  final matchesBaseline =
      remoteHash == lastAppliedRemoteHash ||
      remoteHash == lastUploadedLocalHash;
  if (matchesBaseline) {
    return WebdavAutoUploadDecision.allow;
  }
  return WebdavAutoUploadDecision.remoteDrifted;
}

bool webdavPullHasSyncConflict({
  required String? lastUploadedLocalHash,
  required String? lastAppliedRemoteHash,
  required String localContentSha256,
  required String remoteContentSha256,
}) {
  final localChangedSinceSync =
      lastUploadedLocalHash != null &&
      localContentSha256 != lastUploadedLocalHash;
  final remoteChangedSinceSync =
      lastAppliedRemoteHash != null &&
      remoteContentSha256 != lastAppliedRemoteHash;
  final divergedOnFirstSync =
      lastUploadedLocalHash == null &&
      lastAppliedRemoteHash == null &&
      localContentSha256 != remoteContentSha256;
  return (localChangedSinceSync && remoteChangedSinceSync) ||
      divergedOnFirstSync;
}
