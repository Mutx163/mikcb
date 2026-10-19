import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/partner_timetable_binding.dart';
import 'package:university_timetable/models/timetable_profile.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/services/partner_timetable_service.dart';
import 'package:university_timetable/services/timetable_partner_service.dart';

PartnerTimetableBinding _binding({
  String partnerName = 'TA',
  int weekOffset = 0,
  String mineColorHex = '#2196F3',
  String partnerColorHex = '#E91E63',
  String togetherColorHex = '#9C27B0',
}) => PartnerTimetableBinding(
  partnerProfileId: PartnerTimetableService.partnerProfileId,
  partnerName: partnerName,
  linkedAt: DateTime.parse('2026-09-01'),
  weekOffset: weekOffset,
  mineColorHex: mineColorHex,
  partnerColorHex: partnerColorHex,
  togetherColorHex: togetherColorHex,
);

TimetableProfile _profile({
  required String id,
  TimetableProfileKind kind = TimetableProfileKind.normal,
}) => TimetableProfile(
  id: id,
  name: id,
  courses: const [],
  settings: TimetableSettings.defaults(),
  currentWeek: 1,
  createdAt: DateTime(2026),
  lastUsedAt: DateTime(2026),
  profileKind: kind,
);

class _FakePartnerPort implements TimetablePartnerPort {
  @override
  PartnerTimetableBinding? partnerBinding;

  @override
  List<TimetableProfile> profiles = [];

  @override
  String? activeProfileId;

  bool failSave = false;
  bool failImport = false;
  PartnerImportResult? importResult;
  List<TimetableProfile> reloadedProfiles = [];

  int saveCount = 0;
  int reloadCount = 0;
  int importCount = 0;
  int unlinkCount = 0;
  int saveProfilesCount = 0;
  int setActiveCount = 0;
  int applyProfileCount = 0;
  int mergeCount = 0;
  int syncHookCount = 0;
  int notifyCount = 0;
  int liveCount = 0;
  int examSyncCount = 0;

  @override
  Future<void> initialize() async {}

  @override
  Future<T> runMutation<T>(Future<T> Function() operation) => operation();

  @override
  Future<PartnerImportResult> importFromContent(
    String content, {
    String? partnerName,
  }) async {
    importCount += 1;
    if (failImport) {
      throw StateError('bad partner file');
    }
    return importResult!;
  }

  @override
  Future<void> unlinkImport() async {
    unlinkCount += 1;
  }

  @override
  Future<void> reloadProfilesFromStorage() async {
    reloadCount += 1;
    profiles = reloadedProfiles;
  }

  @override
  void applyProfileState(TimetableProfile profile) => applyProfileCount += 1;

  @override
  void mergeActiveProfileIntoProfilesList() => mergeCount += 1;

  @override
  Future<void> saveProfiles(List<TimetableProfile> profiles) async {
    saveProfilesCount += 1;
  }

  @override
  Future<void> setActiveProfileId(String profileId) async {
    setActiveCount += 1;
    activeProfileId = profileId;
  }

  @override
  Future<void> savePartnerBinding(PartnerTimetableBinding? binding) async {
    saveCount += 1;
    if (failSave) {
      throw StateError('disk full');
    }
  }

  @override
  void notifySyncHooks() => syncHookCount += 1;

  @override
  void notifyStateChanged() => notifyCount += 1;

  @override
  void syncExamReminders() => examSyncCount += 1;

  @override
  void pushPartnerLiveSurface() => liveCount += 1;
}

void main() {
  test('importPartnerTimetable 走门内导入：重载档案、写入绑定并按序通知', () async {
    final port = _FakePartnerPort();
    final binding = _binding(partnerName: '小明');
    final importedProfile = _profile(
      id: PartnerTimetableService.partnerProfileId,
      kind: TimetableProfileKind.partnerImported,
    );
    port.importResult = PartnerImportResult(
      kind: PartnerImportResultKind.created,
      binding: binding,
      profile: importedProfile,
      droppedTotal: 2,
    );
    port.reloadedProfiles = [importedProfile];
    final service = TimetablePartnerService(port);

    final result = await service.importPartnerTimetable('{}');

    expect(result.droppedTotal, 2, reason: '部分损坏的条目数必须透传给调用方');
    expect(port.partnerBinding, same(binding));
    expect(port.profiles, [importedProfile]);
    expect(port.notifyCount, 1);
    expect(port.syncHookCount, 1);
    expect(port.liveCount, 1, reason: 'TA 数据变了，绑定卡片要立即重推');
  });

  test('导入失败时绑定不变、不通知', () async {
    final port = _FakePartnerPort();
    final existing = _binding(partnerName: '旧 TA');
    port.partnerBinding = existing;
    port.failImport = true;
    final service = TimetablePartnerService(port);

    await expectLater(
      service.importPartnerTimetable('{}'),
      throwsA(isA<StateError>()),
    );
    expect(port.partnerBinding, same(existing));
    expect(port.notifyCount, 0);
    expect(port.liveCount, 0);
  });

  test('updatePartnerWeekOffset 钳制到边界，同值不落盘', () async {
    final port = _FakePartnerPort()..partnerBinding = _binding();
    final service = TimetablePartnerService(port);

    await service.updatePartnerWeekOffset(99);
    expect(port.partnerBinding!.weekOffset, 15);
    expect(port.saveCount, 1);
    expect(port.notifyCount, 1);
    expect(port.liveCount, 1);

    await service.updatePartnerWeekOffset(15);
    expect(port.saveCount, 1, reason: '值没变就不该再写盘');
  });

  test('周偏移落盘失败：绑定整体退回并上抛', () async {
    final original = _binding(weekOffset: 2);
    final port = _FakePartnerPort()
      ..partnerBinding = original
      ..failSave = true;
    final service = TimetablePartnerService(port);

    await expectLater(
      service.updatePartnerWeekOffset(5),
      throwsA(isA<StateError>()),
    );
    expect(port.partnerBinding, same(original));
    expect(port.notifyCount, 0, reason: '失败路径不得通知界面');
    expect(port.liveCount, 0);
  });

  test('三色落盘失败：绑定整体退回并上抛', () async {
    final original = _binding();
    final port = _FakePartnerPort()
      ..partnerBinding = original
      ..failSave = true;
    final service = TimetablePartnerService(port);

    await expectLater(
      service.updatePartnerCoupleColors(mineColorHex: '#000000'),
      throwsA(isA<StateError>()),
    );
    expect(port.partnerBinding, same(original));
    expect(port.partnerBinding!.mineColorHex, '#2196F3');
  });

  test('没有绑定周偏移与三色都是 no-op', () async {
    final port = _FakePartnerPort();
    final service = TimetablePartnerService(port);

    await service.updatePartnerWeekOffset(3);
    await service.updatePartnerCoupleColors(togetherColorHex: '#000000');

    expect(port.saveCount, 0);
    expect(port.notifyCount, 0);
  });

  test('restorePartnerBinding 相同值不落盘，失败退回原来那份', () async {
    final original = _binding(partnerName: '原 TA');
    final port = _FakePartnerPort()..partnerBinding = original;
    final service = TimetablePartnerService(port);

    await service.restorePartnerBinding(original);
    expect(port.saveCount, 0);

    port.failSave = true;
    final snapshot = _binding(partnerName: '保存点里的 TA');
    await expectLater(
      service.restorePartnerBinding(snapshot),
      throwsA(isA<StateError>()),
    );
    expect(port.partnerBinding, same(original));
  });

  test('unlinkPartner：活跃档是情侣档时切回落档并重排考试提醒', () async {
    final normal = _profile(id: 'normal-1');
    final port = _FakePartnerPort()
      ..partnerBinding = _binding()
      ..activeProfileId = PartnerTimetableService.partnerProfileId
      ..reloadedProfiles = [normal];
    final service = TimetablePartnerService(port);

    await service.unlinkPartner();

    expect(port.unlinkCount, 1);
    expect(port.partnerBinding, isNull);
    expect(port.activeProfileId, 'normal-1');
    expect(port.applyProfileCount, 1);
    expect(port.mergeCount, 1);
    expect(port.saveProfilesCount, 1);
    expect(port.setActiveCount, 1);
    expect(port.examSyncCount, 1);
    expect(port.liveCount, 1);
  });

  test('unlinkPartner：活跃档不是情侣档时不动档案', () async {
    final normal = _profile(id: 'normal-1');
    final port = _FakePartnerPort()
      ..partnerBinding = _binding()
      ..activeProfileId = 'normal-1'
      ..reloadedProfiles = [normal];
    final service = TimetablePartnerService(port);

    await service.unlinkPartner();

    expect(port.partnerBinding, isNull);
    expect(port.applyProfileCount, 0);
    expect(port.saveProfilesCount, 0);
    expect(port.examSyncCount, 0);
    expect(port.notifyCount, 1);
  });
}
