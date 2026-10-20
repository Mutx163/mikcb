import '../models/timetable_profile.dart';

/// 服务端口共用状态面的**唯一声明处**。
///
/// ## 为什么有这个东西
///
/// provider 拆分那一轮之后，13/14 个服务端口各自把宿主的状态面抄了一份
/// （`settings` / `courses` / `profiles` / `notifyStateChanged` / `initialize` …），
/// 实测 232 条声明里只有 97 个不同名字，**重复 135 条（58%）**。同一批成员在
/// 10 个端口里各写一遍，改一次签名要动十几处，而且谁都不会注意到漏了哪个。
///
/// `provider 拆分诚实定界` 笔记给的判据是「端口由消费方定义、每族 ≤ 自身 distinct 数」。
/// 重复声明正是这条判据的反面：端口不是按「我真需要什么」裁的，是把宿主有的东西
/// 原样列了一遍。
///
/// ## 归并口径（重要）
///
/// 这里只收**签名完全一致**、且被至少 4 个端口重复声明的成员。当前是三条：
///
/// | 成员 | 原重复端口数 |
/// |---|---:|
/// | `notifyStateChanged()` | 11 |
/// | `List<TimetableProfile> get profiles` | 9 |
/// | `initialize()` | 8 |
///
/// 归并后这三条只声明一次，由 8 个端口 `implements` 继承，重复声明净减 **21 条**。
///
/// ## 不收什么（这条比收什么更重要）
///
/// **不重蹈 `TimetableScheduleDateRulePort implements TimetableTimeSchemePort`
/// 那个坑**：当时为了少写几行，白继承整份作息端口的 23 个成员、其中 7 个根本用不到。
/// 本文件因此守三条：
///
/// 1. **只收签名完全一致的成员**。`persistActiveProfileState` 在
///    `TimetableImportExportPort` 里带 `{touchLastUsedAt, notifySync}` 两个具名参数、
///    在其余端口里是无参，硬收就得给所有端口塞上那两个参数——那是新的谎话。
///    同理 `updateLiveActivity`（有的带 `syncScheduleSnapshot`、有的不带）。
///    这两条**留在各自端口里**，等哪天真统一了签名再收。
/// 2. **只让「本来就完整拥有这三条」的端口 implements 本端口**。当前 8 个端口全部满足，
///    所以**白背 0 条**；有任何一个端口缺一条，就不让它 implements，
///    而不是让核心端口将就它。
/// 3. **只收状态读写与生命周期**，不收注入依赖（那一批已按「注入依赖不进端口」
///    由 `repository` / `storage` / `icsImporter` / `analytics` 四刀移出）、
///    不收 `liveRuntime` 那批原生面句柄（属方案 B「状态真搬走」范畴）。
///
/// ## 使用方式
///
/// ```dart
/// abstract interface class TimetableXxxPort implements TimetableCoreStatePort {
///   // 只写本族自己的成员；notifyStateChanged / profiles(get) / initialize
///   // 由本端口提供，不必再抄。
/// }
/// ```
///
/// 注意 `implements` 与 `extends` 在 Dart 里对 interface class 都表示「引入成员契约、
/// 不继承实现」，这里用 `implements` 与仓库其余端口写法保持一致。
///
/// 新增端口时：**先查本文件再决定要不要写这三条**。若新端口确实只需要其中一条，
/// 也让它 `implements` 本端口（三条都是宿主现成的一行适配，成本可忽略），
/// 不要退回去各抄一份。
abstract interface class TimetableCoreStatePort {
  /// 通知 UI 状态已变（宿主侧最终落到 `ChangeNotifier.notifyListeners`）。
  ///
  /// 写入口约定：内存改完 + 落盘成功后调用；失败回滚路径同样要调一次，
  /// 否则界面会停在失败导入/失败写入的那一版。
  void notifyStateChanged();

  /// 当前课表列表（只读视图）。
  ///
  /// 端口实现方返回的是不可变副本，服务无法原地改宿主的列表，只能
  /// 「复制 → 改副本 → 整体赋回」——这正是各服务写入口普遍出现该形态的原因。
  /// 需要写入时由各族端口自己声明 `set profiles(...)`（不在本核心端口内，
  /// 因为并非所有消费者都要写）。
  List<TimetableProfile> get profiles;

  /// 宿主初始化（服务入口在动手前先确保数据已就绪）。
  Future<void> initialize();
}
