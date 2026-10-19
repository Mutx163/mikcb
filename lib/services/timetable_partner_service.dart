import '../domain/couple_timetable_logic.dart';
import '../models/partner_timetable_binding.dart';
import '../models/timetable_profile.dart';
import 'partner_timetable_service.dart';

/// 情侣课表写入口需要的最小依赖面。
///
/// 由 `TimetableProvider` 侧的适配器实现：读写绑定、读写课表档案列表与活跃
/// 课表、统一 mutation 门、TA 课表导入/解绑、落盘、同步钩子、界面通知、
/// 考试提醒与绑定卡片重推。服务本身不碰 provider 私有字段，可用假端口单测。
abstract interface class TimetablePartnerPort {
  PartnerTimetableBinding? get partnerBinding;
  set partnerBinding(PartnerTimetableBinding? value);
  List<TimetableProfile> get profiles;
  String? get activeProfileId;
  set activeProfileId(String? value);
  Future<void> initialize();
  Future<T> runMutation<T>(Future<T> Function() operation);
  Future<PartnerImportResult> importFromContent(
    String content, {
    String? partnerName,
  });
  Future<void> unlinkImport();
  Future<void> reloadProfilesFromStorage();
  void applyProfileState(TimetableProfile profile);
  void mergeActiveProfileIntoProfilesList();
  Future<void> saveProfiles(List<TimetableProfile> profiles);
  Future<void> setActiveProfileId(String profileId);
  Future<void> savePartnerBinding(PartnerTimetableBinding? binding);
  void notifySyncHooks();
  void notifyStateChanged();
  void syncExamReminders();
  void pushPartnerLiveSurface();
}

/// 情侣课表域用例：导入 TA 课表、周偏移、三色、保存点恢复与解绑。
///
/// 2026-10-19 从 `TimetableProvider` 的情侣课表族方法搬出；写入纪律与副作用
/// 保持原样：
/// - 全部入口走 mutation 门串行化，避免与云恢复 / LAN 应用等门内写者交错
///   读写绑定（check-then-act 竞态）；
/// - 绑定一族（周偏移 / 三色 / 恢复保存点）同一条契约：改内存 → await 落盘 →
///   失败整体退回并上抛。`runMutation` 只是互斥锁、不含回滚，漏了回滚时内存会
///   留着没存下的绑定，下一次任意保存把它坐实，而界面报的是「保存失败」；
/// - 解绑后若当前活跃档案就是情侣档，要切回普通档案并落盘，否则界面停在
///   一个已被删除的课表上。
class TimetablePartnerService {
  TimetablePartnerService(this._port);

  final TimetablePartnerPort _port;

  Future<PartnerImportResult> importPartnerTimetable(
    String content, {
    String? partnerName,
  }) {
    return _port.runMutation(() async {
      await _port.initialize();
      final result = await _port.importFromContent(
        content,
        partnerName: partnerName,
      );
      await _port.reloadProfilesFromStorage();
      _port.partnerBinding = result.binding;
      _port.notifySyncHooks();
      _port.notifyStateChanged();
      // TA 数据变了：绑定 TA 课表/情侣课表的桌面卡片立即重推专属快照，
      // 不等下一次课程边界（scheduleSnapshot 与我方课表无关，跳过）。
      _port.pushPartnerLiveSurface();
      return result;
    });
  }

  /// 与其他用户写入一致走 mutation 门：避免与云恢复/LAN 应用等
  /// 门内写者交错读写绑定（check-then-act 竞态）。
  Future<void> updatePartnerWeekOffset(int offset) {
    return _port.runMutation(() async {
      await _port.initialize();
      final binding = _port.partnerBinding;
      if (binding == null) {
        return;
      }
      final clamped = CoupleTimetableLogic.clampWeekOffset(offset);
      if (clamped == binding.weekOffset) {
        return;
      }
      final previousBinding = _port.partnerBinding;
      _port.partnerBinding = binding.copyWith(weekOffset: clamped);
      try {
        await _port.savePartnerBinding(_port.partnerBinding);
      } catch (_) {
        _port.partnerBinding = previousBinding;
        rethrow;
      }
      _port.notifySyncHooks();
      _port.notifyStateChanged();
      // 周偏移改变 TA 课的对应周次：情侣绑定卡片立即重推（同上跳过
      // scheduleSnapshot）。
      _port.pushPartnerLiveSurface();
    });
  }

  /// 同 [updatePartnerWeekOffset]：纳入 mutation 门串行化、失败整体退回。
  Future<void> updatePartnerCoupleColors({
    String? mineColorHex,
    String? partnerColorHex,
    String? togetherColorHex,
  }) {
    return _port.runMutation(() async {
      await _port.initialize();
      final binding = _port.partnerBinding;
      if (binding == null) {
        return;
      }
      final previousBinding = _port.partnerBinding;
      _port.partnerBinding = binding.copyWith(
        mineColorHex: mineColorHex,
        partnerColorHex: partnerColorHex,
        togetherColorHex: togetherColorHex,
      );
      try {
        await _port.savePartnerBinding(_port.partnerBinding);
      } catch (_) {
        _port.partnerBinding = previousBinding;
        rethrow;
      }
      _port.notifySyncHooks();
      _port.notifyStateChanged();
      // 情侣三色改变 TA/一起课的着色：情侣绑定卡片立即重推。
      _port.pushPartnerLiveSurface();
    });
  }

  /// 把情侣绑定写回保存点里那一份（导入撤销 / 自动回滚用）。
  ///
  /// 为什么需要单独一个入口：全量备份的 schema **不含**情侣绑定，而导入路径在恢复出的
  /// 课表里找不到情侣档时会把它清掉并落盘（`import_export_service.dart:650-658`）。
  /// 撤销时重新导入那份快照自然带不回绑定 —— 保存点里单独存了一份，由这里写回。
  /// 传 null 表示「快照里本来就没有绑定」。
  ///
  /// 与 [updatePartnerWeekOffset] / [updatePartnerCoupleColors] 同一把门与落盘链路。
  Future<void> restorePartnerBinding(PartnerTimetableBinding? binding) {
    return _port.runMutation(() async {
      await _port.initialize();
      if (_port.partnerBinding == binding) {
        return;
      }
      // 同族（本方法就是为「导入回滚」加的入口，所以更不能自己漏掉回滚）：
      // 落盘失败要把内存退回原来那份绑定，否则「恢复失败」反而把绑定留在半路上。
      final previousBinding = _port.partnerBinding;
      _port.partnerBinding = binding;
      try {
        await _port.savePartnerBinding(binding);
      } catch (_) {
        _port.partnerBinding = previousBinding;
        rethrow;
      }
      _port.notifySyncHooks();
      _port.notifyStateChanged();
      _port.pushPartnerLiveSurface();
    });
  }

  Future<void> unlinkPartner() {
    return _port.runMutation(() async {
      await _port.initialize();
      await _port.unlinkImport();
      await _port.reloadProfilesFromStorage();
      _port.partnerBinding = null;
      if (_port.activeProfileId == PartnerTimetableService.partnerProfileId) {
        final fallback = _port.profiles
            .where((profile) => !profile.isPartnerImported)
            .firstOrNull;
        if (fallback != null) {
          _port.activeProfileId = fallback.id;
          _port.applyProfileState(fallback);
          _port.mergeActiveProfileIntoProfilesList();
          await _port.saveProfiles(_port.profiles);
          await _port.setActiveProfileId(fallback.id);
          _port.syncExamReminders();
        }
      }
      _port.notifySyncHooks();
      _port.notifyStateChanged();
      // TA 解绑：TA/情侣绑定卡片的专属快照随本次同步清理回落。
      _port.pushPartnerLiveSurface();
    });
  }
}
