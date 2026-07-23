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
import 'data_transfer_service.dart';
import 'holiday_service.dart';
import 'storage_service.dart';
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

  Future<String?> applySnapshot({
    required TimetableProvider provider,
    required AppSyncSnapshot snapshot,
  }) {
    return provider.runMutationExclusive(() async {
      if (snapshot.profiles.isEmpty) {
        return 'sync_snapshot_no_profiles';
      }

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
    });
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
