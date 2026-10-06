import '../models/warehouse_repository_models.dart';

/// 把「轻屿专属条目」并进同一份脚本的标准条目，用户不再需要二选一。
///
/// ## 为什么要合
///
/// `qingyu_only/<目录>/adapters.yaml` 里那条专属条目，声明的 `asset_js_path` 与
/// `resources/` 下那条**完全同一份**上游标准脚本（刻意不另存副本），区别只是多挂了
/// `time_schemes_file` 这类宿主专属字段。把它单列成第二条，用户就得在同一所学校的
/// 列表里做一次没有信息量的二选一：选了标准那条，等于主动放弃「按教学楼分流作息」；
/// 选了专属那条，又得先知道学校有没有做这个增强。
///
/// 而用户视角里这两条是**同一件事**。合并之后列表里只有一条、功能一个不少，且
/// 不管用户从哪个入口发起导入，专属数据都会生效。
///
/// ## 什么时候不合
///
/// 专属条目如果与任何标准条目都不对应同一份脚本——那是**真的另一条适配**（不同脚本、
/// 不同导入方式），吃掉它等于删功能。所以只在「同一份脚本」时合并，其余照旧追加。
///
/// ## 合并后为什么把 `isQingyuOnly` 置真
///
/// 这个标记在 App 里只有两处用途：套用专属作息的判断（`course_import_screen`）与脚本
/// 查找顺序（`fetchAdapterScript`，先专属目录、找不到回落 `resources/`）。置真之后
/// 导入侧**一字不改**就生效；而查找顺序多出的那一跳对本仓库无害：专属脚本副本存在就
/// 用它，不存在就回落 `resources/` 下那份（回落逻辑本来就在）。
List<WarehouseAdapterEntry> mergeQingyuOnlyUpgrades({
  required List<WarehouseAdapterEntry> standard,
  required List<WarehouseAdapterEntry> extras,
}) {
  if (extras.isEmpty) return standard;

  // 逐条专属条目判定去向：合掉（进 upgrades）还是原样保留（留给列表追加）。
  final upgrades = <String, WarehouseAdapterEntry>{};
  final merged = <int>{};
  for (var i = 0; i < extras.length; i++) {
    final extra = extras[i];
    if (extra.assetJsPath.isEmpty) continue;
    if (standard.any((it) => it.adapterId == extra.adapterId)) continue;
    final targets = standard
        .where((it) => it.assetJsPath == extra.assetJsPath && !upgrades.containsKey(it.adapterId))
        .toList(growable: false);
    // 专属条目没带任何专属字段时没什么可合的：合了只会让脚本查找多绕一跳
    // `qingyu_only/`（那份文件并不存在），而功能上一点变化都没有。
    if (targets.isEmpty || extra.timeSchemesFile.isEmpty) continue;
    for (final target in targets) {
      upgrades[target.adapterId] = target.copyWith(
        timeSchemesFile: extra.timeSchemesFile,
        isQingyuOnly: true,
      );
    }
    merged.add(i);
  }

  return [
    for (final item in standard) upgrades[item.adapterId] ?? item,
    // 追加的必须同时满足两条：没被合掉、且 id 不与标准条目撞（撞了就是同一个适配
    // 出现两次，用户点哪张卡都分不清是哪条）。
    for (var i = 0; i < extras.length; i++)
      if (!merged.contains(i) &&
          !standard.any((it) => it.adapterId == extras[i].adapterId))
        extras[i],
  ];
}
