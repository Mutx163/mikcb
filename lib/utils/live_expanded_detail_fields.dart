import '../models/timetable_settings.dart';

/// 「提醒显示」设置页各阶段可操作的展开详情字段全集（顺序即默认行序）。
///
/// 两条硬约束（见原生 `LiveUpdateService.expandedDetailLineList` 与
/// `promotedExpandedDetailDefaultOrder`）：
///
/// * 课前/下课提醒**恒为提升态**：`stage` 行的 `stageTitle` 传 null、
///   `status` 行要求 `!shouldPromote`（课前恒 true），两行永远渲染不出；
///   `progress` 块要求 `classProgress != null`，课前也是 null。因此在
///   「上课前提醒显示」页这三个字段不可见——列表上的每一行都必须对应
///   展开态里真实存在的一行，否则开关拨了预览没反应（假死开关）。
/// * 课中/下课页保留九字段，但默认顺序按**提升态**行序（progress 在
///   status 前、shortName 靠后），与展开态预览一致；`stage` 仅在关闭
///   「展示超级岛」的非提升态渲染，殿后。
///
/// 注意：这里的顺序**不是**存储枚举的默认序（`LiveExpandedDetailField.values`
/// 对应原生非提升态 `EXPANDED_DETAIL_DEFAULT_ORDER`，是存储兜底语义），
/// 两者各管一边，不要互相「纠正」。
List<LiveExpandedDetailField> liveExpandedDetailFieldsForStage({
  required bool forDuringEnd,
}) => forDuringEnd
    ? const [
        LiveExpandedDetailField.progress,
        LiveExpandedDetailField.status,
        LiveExpandedDetailField.time,
        LiveExpandedDetailField.location,
        LiveExpandedDetailField.teacher,
        LiveExpandedDetailField.shortName,
        LiveExpandedDetailField.nextCourse,
        LiveExpandedDetailField.note,
        LiveExpandedDetailField.stage,
      ]
    : const [
        LiveExpandedDetailField.time,
        LiveExpandedDetailField.location,
        LiveExpandedDetailField.teacher,
        LiveExpandedDetailField.shortName,
        LiveExpandedDetailField.nextCourse,
        LiveExpandedDetailField.note,
      ];

/// 按可见集解析展开详情的当前工作顺序。
///
/// 名单未设置（null = 未自定义）→ 可见集全开、按默认序；已设置 →
/// 取「名单 ∩ 可见集」，名单中没提到的可见字段即用户关掉的字段。
/// 存储里残留的不可见字段（如课前名单里的 stage）被剔除——渲染端本就
/// 不为它们成行，剔除只是让设置页与真机一致。
List<LiveExpandedDetailField> resolveExpandedDetailWorkOrder(
  LiveDisplaySettings display, {
  required bool forDuringEnd,
}) {
  final visible = liveExpandedDetailFieldsForStage(forDuringEnd: forDuringEnd);
  final configured = display.expandedDetailFields;
  if (configured == null) return List.of(visible);
  return [
    for (final field in configured)
      if (visible.contains(field)) field,
  ];
}
