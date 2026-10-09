import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../models/partner_timetable_binding.dart';
import '../data/timetable_repository.dart';
import '../models/timetable_profile.dart';
import '../domain/couple_timetable_logic.dart';
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

  /// 2026-10-08：导入时被跳过的条目数（部分损坏）。`parseBackupJson` 现在会
  /// 带回它，这条路径原先也静默吞掉：100 门里坏 40 门会安静导入 60 门、报
  /// 「已导入」，用户下次打开才发现少了几十节。这里透传给调用方如实提示。
  final int droppedTotal;

  const PartnerImportResult({
    required this.kind,
    required this.binding,
    required this.profile,
    this.droppedTotal = 0,
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

  /// profiles 变更统一走仓储（阶段 2 收口）：partner RMW 与 provider
  /// 写路径共享同一入口，为后续批量提交 / 分片存储保留单一协调点。
  late final TimetableRepository _profileRepository = TimetableRepository(
    _storageService,
  );

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
    final existingBinding = await _profileRepository.getPartnerTimetableBinding();
    final contentHash = computeContentHash(content);

    final displayName = partnerName?.trim().isNotEmpty == true
        ? partnerName!.trim()
        : backup.profileName?.trim().isNotEmpty == true
        ? backup.profileName!.trim()
        : 'TA的课表';

    late final bool isUpdate;
    late final TimetableProfile partnerProfile;

    await _profileRepository.updateProfiles((profiles) {
      isUpdate = existingBinding != null &&
          profiles.any((profile) => profile.id == partnerProfileId);

      partnerProfile = TimetableProfile(
        id: partnerProfileId,
        name: displayName,
        courses: backup.courses,
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

      return [
        for (final profile in profiles)
          if (profile.id != partnerProfileId) profile,
        partnerProfile,
      ];
    });

    final binding = PartnerTimetableBinding(
      partnerProfileId: partnerProfileId,
      partnerName: displayName,
      linkedAt: existingBinding?.linkedAt ?? now,
      lastImportedAt: now,
      sourceFileHash: contentHash,
      weekOffset: existingBinding?.weekOffset ?? 0,
      mineColorHex: existingBinding?.mineColorHex ??
          CoupleTimetableLogic.mineColorHexDefault,
      partnerColorHex: existingBinding?.partnerColorHex ??
          CoupleTimetableLogic.partnerColorHexDefault,
      togetherColorHex: existingBinding?.togetherColorHex ??
          CoupleTimetableLogic.togetherColorHexDefault,
    );

    await _profileRepository.savePartnerTimetableBinding(binding);

    return PartnerImportResult(
      kind: isUpdate
          ? PartnerImportResultKind.updated
          : PartnerImportResultKind.created,
      binding: binding,
      profile: partnerProfile,
      droppedTotal: backup.droppedTotal,
    );
  }

  Future<void> unlink() async {
    await _profileRepository.updateProfiles((profiles) {
      return profiles
          .where((profile) => profile.id != partnerProfileId)
          .toList();
    });
    await _profileRepository.savePartnerTimetableBinding(null);
  }
}
