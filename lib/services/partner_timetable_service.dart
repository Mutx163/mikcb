import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../models/partner_timetable_binding.dart';
import '../models/timetable_profile.dart';
import '../providers/timetable/couple_timetable_logic.dart';
import 'data_transfer_service.dart';
import 'storage_service.dart';

enum PartnerImportResultKind {
  created,
  updated,
}

class PartnerImportResult {
  final PartnerImportResultKind kind;
  final PartnerTimetableBinding binding;
  final TimetableProfile profile;

  const PartnerImportResult({
    required this.kind,
    required this.binding,
    required this.profile,
  });
}

class PartnerTimetableService {
  static const String partnerProfileId = 'partner-imported';

  PartnerTimetableService({
    StorageService? storageService,
    DataTransferService? dataTransferService,
  }) : _storageService = storageService ?? StorageService(),
       _dataTransferService = dataTransferService ?? DataTransferService();

  final StorageService _storageService;
  final DataTransferService _dataTransferService;

  String computeContentHash(String content) {
    return sha256.convert(utf8.encode(content)).toString();
  }

  Future<PartnerImportResult> importFromContent(
    String content, {
    String? partnerName,
  }) async {
    if (_dataTransferService.isFullBackupJson(content)) {
      throw const FormatException('partner_import_requires_single_profile');
    }

    final backup = _dataTransferService.parseBackupJson(content);
    final now = DateTime.now();
    final profiles = await _storageService.getProfiles();
    final existingBinding = await _storageService.getPartnerTimetableBinding();
    final isUpdate = existingBinding != null &&
        profiles.any((profile) => profile.id == partnerProfileId);

    final displayName = partnerName?.trim().isNotEmpty == true
        ? partnerName!.trim()
        : backup.profileName?.trim().isNotEmpty == true
        ? backup.profileName!.trim()
        : 'TA的课表';

    final partnerProfile = TimetableProfile(
      id: partnerProfileId,
      name: displayName,
      courses: backup.courses,
      scheduleItems: const [],
      exams: const [],
      settings: backup.settings,
      currentWeek: backup.currentWeek,
      createdAt: isUpdate
          ? profiles
                .firstWhere((profile) => profile.id == partnerProfileId)
                .createdAt
          : now,
      lastUsedAt: now,
      profileKind: TimetableProfileKind.partnerImported,
    );

    final nextProfiles = [
      for (final profile in profiles)
        if (profile.id != partnerProfileId) profile,
      partnerProfile,
    ];

    final binding = PartnerTimetableBinding(
      partnerProfileId: partnerProfileId,
      partnerName: displayName,
      linkedAt: existingBinding?.linkedAt ?? now,
      lastImportedAt: now,
      sourceFileHash: computeContentHash(content),
      weekOffset: existingBinding?.weekOffset ?? 0,
      mineColorHex: existingBinding?.mineColorHex ??
          CoupleTimetableLogic.mineColorHexDefault,
      partnerColorHex: existingBinding?.partnerColorHex ??
          CoupleTimetableLogic.partnerColorHexDefault,
      togetherColorHex: existingBinding?.togetherColorHex ??
          CoupleTimetableLogic.togetherColorHexDefault,
    );

    await _storageService.saveProfiles(nextProfiles);
    await _storageService.savePartnerTimetableBinding(binding);

    return PartnerImportResult(
      kind: isUpdate
          ? PartnerImportResultKind.updated
          : PartnerImportResultKind.created,
      binding: binding,
      profile: partnerProfile,
    );
  }

  Future<void> unlink() async {
    final profiles = await _storageService.getProfiles();
    final nextProfiles = profiles
        .where((profile) => profile.id != partnerProfileId)
        .toList();
    await _storageService.saveProfiles(nextProfiles);
    await _storageService.savePartnerTimetableBinding(null);
  }
}
