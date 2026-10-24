/// 新建日程的「快捷模板」数据表：**纯数据 + 一条纯函数**，不碰 UI 也不碰 l10n。
///
/// 为什么单独一层：
/// - 图标是 `IconData`、文案是 `AppLocalizations`，两者都不该进 `lib/domain`
///   （`dependency_guards_test` 里有「domain 保持无 UI 框架依赖」这条守卫）。
///   这里只留 id / 图标名 / 颜色 / 时长，图标名由
///   `widgets/schedule_quick_preset_rail.dart` 注册，标题由
///   `l10n/schedule_preset_localizer.dart` 反查——与 `pickup_code_presets.dart`
///   同一套分工。
/// - 时长换算要能无 UI 单测（跨午夜钳制这种边界，用组件测试跑代价太高）。
///
/// 维护约定：新增一个模板 = 这里加一条 + 六个 `app_*.arb` 各加一个标题键
/// （`scheduleQuickPreset` 前缀）+ 图标名在 rail 的注册表里登记。
/// 颜色必须取自 `utils/course_color_palette.dart` 的
/// `kCourseColorQuickPickHexes`：色块行只画那一族色，模板套用一个不在行里的
/// 颜色会让「外观」那张卡显示成没有选中项。
library;

/// 一条快捷模板。字段刻意只有四个：多一个「默认地点」就得再配六份文案，
/// 而地点本来就是最常被用户就地改掉的字段。
class ScheduleQuickPreset {
  const ScheduleQuickPreset({
    required this.id,
    required this.icon,
    required this.colorHex,
    required this.durationMinutes,
  });

  /// 稳定 id，同时是 l10n 键的语义名（`groupMeeting` →
  /// `scheduleQuickPresetGroupMeeting`）。写进 UI 的地方一律走 id 反查，
  /// 不在数据表里存中文。
  final String id;

  /// 图标名，由 rail 的注册表映射成 `IconData`；未知名字回落默认图标。
  final String icon;

  /// 套用时一并选中的日程颜色（`#RRGGBB`）。
  final String colorHex;

  /// 套用时给出的时长（分钟）。开始时刻保持用户当前选的那个不变，
  /// 只据此推算结束时刻——用户可能已经先定了时间，模板不该把它挪走。
  final int durationMinutes;
}

/// 顺序 = 「一天里最可能先想到的」从上往下：先学业事务，再生活安排。
///
/// 不放「考试」：那是独立模块（`add_exam_screen`），在这里再放一个同名模板
/// 会让用户以为两者等价，实际一个是日程条目、一个是考试实体。
const List<ScheduleQuickPreset> kScheduleQuickPresets = <ScheduleQuickPreset>[
  ScheduleQuickPreset(
    id: 'groupMeeting',
    icon: 'groups',
    colorHex: '#6366F1',
    durationMinutes: 60,
  ),
  ScheduleQuickPreset(
    id: 'lecture',
    icon: 'lecture',
    colorHex: '#0EA5E9',
    durationMinutes: 90,
  ),
  ScheduleQuickPreset(
    id: 'meeting',
    icon: 'meeting',
    colorHex: '#2196F3',
    durationMinutes: 60,
  ),
  ScheduleQuickPreset(
    id: 'defense',
    icon: 'defense',
    colorHex: '#8B5CF6',
    durationMinutes: 60,
  ),
  ScheduleQuickPreset(
    id: 'interview',
    icon: 'interview',
    colorHex: '#D946EF',
    durationMinutes: 30,
  ),
  ScheduleQuickPreset(
    id: 'dining',
    icon: 'dining',
    colorHex: '#F97316',
    durationMinutes: 120,
  ),
  ScheduleQuickPreset(
    id: 'workout',
    icon: 'workout',
    colorHex: '#22C55E',
    durationMinutes: 60,
  ),
  ScheduleQuickPreset(
    id: 'study',
    icon: 'study',
    colorHex: '#14B8A6',
    durationMinutes: 120,
  ),
  ScheduleQuickPreset(
    id: 'clinic',
    icon: 'clinic',
    colorHex: '#EF4444',
    durationMinutes: 60,
  ),
  ScheduleQuickPreset(
    id: 'commute',
    icon: 'commute',
    colorHex: '#F59E0B',
    durationMinutes: 120,
  ),
];

/// 按 id 取模板；未知 id 返回 null（调用方据此不套用，而不是猜一条）。
ScheduleQuickPreset? scheduleQuickPresetById(String id) {
  for (final preset in kScheduleQuickPresets) {
    if (preset.id == id) {
      return preset;
    }
  }
  return null;
}

/// 套用模板后的起止时刻（分钟数，0～1439）：给一个开始时刻和时长，算出一段
/// **一定落在当天、且结束晚于开始**的区间。
///
/// ## 为什么不让它跨午夜
///
/// 日程条目是「结束日期 + 结束时刻」两字段拼起来的。模板只改时刻、不动日期，
/// 所以一旦算出 01:00，就会变成「同一天 23:00 到 01:00」——保存时被
/// 「结束时间必须晚于开始时间」拦下，而用户根本不知道这个 01:00 是模板算的。
///
/// ## 放不下就整体前移，而不是把尾巴压平
///
/// 23:00 套「聚餐」（120 分钟）放不下当天。两种兜底：
/// - 把结束压到 23:59：区间只剩 59 分钟，卡片上写着 2 小时、实际给 59 分钟；
/// - **整体前移到 21:59–23:59**：时长保真，只是开始时刻比用户当前选的早。
///
/// 选后者。模板的意义就是「这段时长」，压缩它等于没套上；而开始时刻用户
/// 眼睛一扫就能看见（它就在紧邻的输入框里），改回来也只需一次点击。
///
/// [startMinutes] 超出 0～1439 时先夹回区间：外部数据里的 `25:00` 在上游
/// `_parseTime` 已被挡掉，这里再兜一层，避免算出负时刻或跨月偏移。
({int startMinutes, int endMinutes}) resolveSchedulePresetWindow({
  required int startMinutes,
  required int durationMinutes,
}) {
  const lastMinuteOfDay = 23 * 60 + 59;
  final start = startMinutes.clamp(0, lastMinuteOfDay);
  if (durationMinutes <= 0) {
    return (startMinutes: start, endMinutes: start);
  }
  final end = start + durationMinutes;
  if (end <= lastMinuteOfDay) {
    return (startMinutes: start, endMinutes: end);
  }
  // 放不下当天：整段前移，让结束恰好落在当天最后一分钟。
  final shiftedStart = lastMinuteOfDay - durationMinutes;
  return (
    startMinutes: shiftedStart < 0 ? 0 : shiftedStart,
    endMinutes: lastMinuteOfDay,
  );
}
