import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';

import '../models/timetable_settings.dart';
import '../ui/hyperos/hyperos.dart';
import '../widgets/home_menu_catalog.dart';
import '../widgets/home_top_menu.dart';
import '../widgets/home_top_menu_popup.dart' show kHomeMenuCollapseBudget;
import '../widgets/timetable/timetable_top_menu_shell.dart';

/// [HomeMenuController] 对宿主 State 的全部依赖。
///
/// 菜单自己只持有「开 / 合 / 采样源 / 退场等待」这一小撮状态；更新红点、锚点
/// 内容、选中项执行与圆钮切换内嵌页都要读首页 State，经这个端口回调。
abstract interface class HomeMenuHost {
  /// State 是否仍挂载（`State.mounted`）。
  bool get isMounted;

  /// 是否有可用更新（顶栏菜单条目上的点状角标 + 弹层内对应条目标记）。
  bool get hasAvailableUpdate;

  /// 打开菜单那一刻**现读**的设置。
  ///
  /// 不能在 build 期捕获后存着：菜单形态（列表 / 八宫格）与排布都是设置的
  /// 直接映射，而按钮的 `onPress` 与「设置刚改完、还没重建」可能隔着同一次
  /// 指针事件（组件测试里就是这条路径），读旧值会开错形态。
  TimetableSettings get menuSettings;

  /// 只触发一次重建（`setState(() {})`）。
  void rebuild();

  /// 「更多」按钮的可见内容：图标 + 更新红点（常驻球与弹层形变起点共用）。
  Widget buildMoreActionIcon({required Color dotBorderColor});

  /// 菜单项的实际分发（宿主按 id 接上首页专属的六条启动路径）。
  Future<void> runTopMenuSelection(String selectedId);

  /// 玻璃坞当前打开的内嵌页 id（非 null 时内容区切换为该页）。
  String? get dockInlinePageId;
  set dockInlinePageId(String? value);

  /// 打开添加课程三宫格弹层。
  Future<void> showAddCourseSheet();

  /// 菜单里的切换触感（受设置里的触觉开关控制）。
  void selectionClick(TimetableSettings settings);

  /// 推路由前先收掉底栏按压光斑（见 `_pushAfterDockGlowSettled`）。
  void pushAfterDockGlowSettled(Future<void> Function(BuildContext) open);
}

/// 首页顶栏「更多」菜单 / 圆钮入口控制器（2026-10-20 从
/// `_TimetableScreenState` 搬出）。
///
/// 负责：
/// - 列表态（OS4 玻璃弹层）菜单的开合、锚点与采样源持有；
/// - 「按下预热 / 抬手归还」录帧纪律；
/// - 「先收菜单、视觉收完再执行选中项」的等待预算；
/// - 圆钮按 `glassDockButtonEntryId` 落到添加弹层 / 内嵌页 / 目录条目；
/// - 列表态菜单的外壳装配（[buildShell]）。
///
/// 八宫格（底部弹层）形态的开合仍由宿主弹出，本控制器只接着它的选中分发。
/// 行为、退场等待预算与触觉口径均按原实现原样保留。
class HomeMenuController {
  HomeMenuController({required this.host});

  final HomeMenuHost host;

  /// 首页「更多」菜单（列表形态）的持有物。按上游约定：锚点与材质捕获容器
  /// 由宿主创建并持有（[MiuixGlassPopupAnchor.dispose] 在本类的 [dispose]
  /// 里释放）；弹层是「常驻挂载 + 切 show」的声明式组件，故用 [isOpen]
  /// 控制显隐。
  final MiuixGlassPopupAnchor anchor = MiuixGlassPopupAnchor();

  /// 首页整屏的玻璃采样源。首页自持（而不是让宿主自建）有两个原因：
  /// 1. 首页右上角菜单与首页内容不在同一棵子树里（菜单要在捕获之外，防反馈
  ///    采样），菜单必须拿到**首页这一屏**的 backdrop，而不是"注册表栈顶"
  ///    （玻璃坞里被盖住的内嵌页也会注册，栈顶可能是一屏不绘制的页面 →
  ///    快照为空 → 菜单透明）；
  /// 2. 「更多」按钮按下即 `acquire` 预热录帧，抬手打开菜单时快照已就绪，
  ///    弹层首帧就有玻璃（否则展开头一两帧是透明轮廓）。
  final HyperosGlassBackdropController glass = HyperosGlassBackdropController();

  bool _glassHeld = false;

  /// 列表态菜单是否展开。
  bool isOpen = false;

  /// 正在等「菜单退场动画走完」的那个信号（见 [closeAndWait]）。
  ///
  /// 由弹层的 `onDismissFinished` 收口（上游 `GlassPopupPresenter._finish`：
  /// 面板已从覆盖层摘掉、锚点那颗球的图标也交还了）。它比
  /// [kHomeMenuCollapseBudget] 晚（弹簧要收敛到 0.0015，实测 ≈670ms，而视觉
  /// 上 ≈240ms 就收完了），所以只当**提前放行**用（关动效那条路是瞬时的），
  /// 常态是预算到期继续。
  Completer<void>? _dismissed;

  void dispose() {
    anchor.dispose();
    glass.dispose();
  }

  /// 「更多」按钮按下即预热：采样区快照在帧末录制，早一拍才能保证菜单首帧
  /// 有玻璃。
  ///
  /// 用 [HyperosGlassBackdropController.holdRecording] 而不是 `acquire()`：
  /// 首页菜单两块面板都走注入面（读"玻璃背后那条带"），整层图没人读 —— 而
  /// `acquire()` 会在**整个开合动画期间每帧录一张全屏**（按 dpr ≈ 6.7MB/帧）。
  void prewarmGlass() {
    if (_glassHeld) return;
    _glassHeld = true;
    glass.holdRecording();
  }

  /// 抬手未展开 / 菜单关闭后归还录帧请求（配对 [holdRecording]，避免首页
  /// 一直录帧）。
  void releaseGlass() {
    if (!_glassHeld) return;
    _glassHeld = false;
    glass.releaseRecording();
  }

  /// 「更多」按钮抬手后**帧末**再判要不要归还。
  ///
  /// 不能在抬手当场归还：`Listener.onPointerUp` 早于按钮的 `onPress`，而
  /// [isOpen] 是在 `onPress` 里才置 true 的 —— 当场归还就会
  /// arm → release → arm 走一遍，中间那次让首页正文白重录一次、还多排一次
  /// 空转录帧（2026-10-19 日志里 `holds=1 → 0 → 1` 就是这个）。推到帧末，
  /// 这一下 tap 真开了菜单就保持不还。
  ///
  /// 显式 `scheduleFrame()`：指针事件本身不保证排帧，而帧末回调只在有帧时跑，
  /// 漏排一次就等于「这次抬手没归还」，首页会一直录帧。
  void releaseGlassAfterTap() {
    if (isOpen) return;
    WidgetsBinding.instance.scheduleFrame();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (host.isMounted && !isOpen) releaseGlass();
    });
  }

  /// 弹层退场结束：唤醒 [closeAndWait] 里的等待。
  void noteDismissFinished() {
    final completer = _dismissed;
    if (completer == null || completer.isCompleted) {
      return;
    }
    _dismissed = null;
    completer.complete();
  }

  /// 立刻收起菜单（遮罩点击 / 返回键 / 菜单项执行前的统一收口）。
  void closeNow() {
    if (isOpen) {
      isOpen = false;
      host.rebuild();
    }
    releaseGlass();
  }

  /// 首页主体 + 顶栏「更多」弹层。
  ///
  /// 布局与采样源次序（采样宿主、玻璃坞、常驻球、菜单四层的位次与理由）见
  /// [TimetableHomeTopMenuShell]；本方法只把菜单状态与回调接上去。
  Widget buildShell({
    required Widget content,
    required TimetableSettings settings,
    required List<Widget> chromeBalls,
    required Color chromeDotBorderColor,
    Widget? dockLayer,
  }) {
    return TimetableHomeTopMenuShell(
      content: content,
      glassController: glass,
      showMenu: isOpen,
      anchor: anchor,
      // 形变动效要从按钮位置长出来，故传入按钮内容的**副本**（不含 GlobalKey，
      // 避免与真实按钮抢同一个 key）：与常驻球**共用同一份**可见内容
      // （宿主 `buildMoreActionIcon`，含更新红点与同一墨色）。两者不能有差异：
      // 早先这里只给裸图标，关闭菜单交接那一瞬圆钮会闪一下（2026-09-14 真机
      // 反馈）。
      anchorContent: host.buildMoreActionIcon(
        dotBorderColor: chromeDotBorderColor,
      ),
      entries: resolveHomeGridMenuEntries(settings),
      hasAvailableUpdate: host.hasAvailableUpdate,
      onDismissRequest: closeNow,
      onSelected: dispatchSelection,
      onDismissFinished: noteDismissFinished,
      dockLayer: dockLayer,
      chromeBalls: chromeBalls,
    );
  }

  /// 打开顶栏「更多」：列表形态走常驻玻璃弹层，八宫格形态弹底部弹层。
  Future<void> showTopActionsSheet(BuildContext context) async {
    final settings = host.menuSettings;
    // 菜单形态由设置分流：「八宫格」是 v2.0.5.5 已发布版本的底部弹层；
    // 「列表」自 2026-09-13 起改用上游 flutter_miuix OS4 玻璃弹层
    // （HomeTopMenuPopup：形变动效 + 不再逐帧重采整页组捕获）。两种形态
    // 共享同一份自定义排列（homeGridMenuActions），统一以入口 id 回传，
    // 再经 [dispatchSelection] 分发到全应用任意二级页面/功能。
    if (settings.homeMenuStyle != HomeMenuStyle.grid) {
      prewarmGlass();
      isOpen = true;
      host.rebuild();
      return;
    }
    // 八宫格是底部弹层，不吃首页采样源：抬手即归还预热。
    releaseGlass();

    final selectedId = await showHomeTopGridMenuSheet(
      context,
      hasAvailableUpdate: host.hasAvailableUpdate,
      entries: resolveHomeGridMenuEntries(settings),
      themeSeedHex: settings.themeSeedColor,
    );
    if (selectedId == null) {
      return;
    }
    await dispatchSelection(selectedId);
  }

  /// 顶栏菜单选中项分发：八宫格与列表（OS4 玻璃弹层）两种形态共用入口。
  ///
  /// **时序：菜单先收完，再执行选中项。** 用户 2026-10-19 口径：「先进行收缩，
  /// 收缩完了才弹出新的页面，比如进入设置页面」。以前只有缩放转场那条这么干，
  /// 通用条目走的是「先推页、等新页盖满再收」（那条为的是避开 2026-09-15 真机
  /// 反馈的「菜单先收、页面后盖，中间几帧首页顶栏两颗球闪一下」）。
  ///
  /// 菜单没开着（八宫格底部弹层形态）时不等，行为与从前一致。
  Future<void> dispatchSelection(String selectedId) async {
    if (!host.isMounted) {
      return;
    }

    // Let the sheet route finish closing before pushing the next page.
    await Future<void>.delayed(Duration.zero);
    if (!host.isMounted) {
      return;
    }

    await closeAndWait();
    if (!host.isMounted) {
      return;
    }

    await host.runTopMenuSelection(selectedId);
  }

  /// 收起菜单，并等它**视觉上收完**（缩回锚点那颗球）才返回。
  ///
  /// 用户 2026-10-19 口径：点菜单项之后先收缩、收缩完才弹新页面。所有条目
  /// （推路由 / 弹层 / 分享）统一走这里，[dispatchSelection] 只等它返回。
  ///
  /// 菜单没开着（八宫格底部弹层形态）时立即返回：底部弹层那格是 `Navigator.pop`
  /// 直接摘路由（没有退场动画残留），[isOpen] 一直是 false。
  ///
  /// 等待口径 = **菜单视觉收完**，不是弹层动画的数学收敛：
  /// * 面板退场是弹簧（上游 `transformBounds(false)` = folmeSpring 阻尼 .8 /
  ///   response .28s），逐帧实测 200×16ms 测试帧里面板宽从 65px 缩到 12px 用
  ///   15 帧（≈240ms），此后只剩亚像素抖动 —— 12px 的点趴在锚点那颗球上，肉眼
  ///   与「没了」无异。
  /// * 而上游那条 `HomeTopMenuPopup.onDismissFinished` 挂在 `animateGlassTo` 的
  ///   收敛容差（0.0015）上，实测要 **≈670ms** 才回调。照它等 = 凭空加半秒空档。
  /// 所以取 [kHomeMenuCollapseBudget] 作上限，弹层若**先**报退场结束（关动效那条
  ///   路是瞬时的）就立刻走。
  Future<void> closeAndWait() async {
    // completer 必须**先**挂上再收起：`closeNow` 只翻 `show`，退场是弹层在
    // 后续帧里跑的，不会同步回调，但先挂可杜绝任何"信号先到、等待后建"。
    final waiting = isOpen ? (_dismissed = Completer<void>()) : null;
    closeNow();
    if (waiting == null) {
      return;
    }
    await Future.any<void>([
      waiting.future,
      Future<void>.delayed(kHomeMenuCollapseBudget),
    ]);
    if (identical(_dismissed, waiting)) {
      _dismissed = null;
    }
    if (!host.isMounted) {
      return;
    }
    // 边缘时序：这 280ms 里用户又点了球、把菜单重开了（收起期第一帧锚点就收回
    // 输入，见上游 fork 的口径）。此时不再等第二遍 —— 直接收掉就继续，绝不能
    // 带着一张张开的菜单去推页面。
    if (isOpen) {
      closeNow();
    }
    // 锚点那颗球的**图标**上游要等退场动画彻底结束才交还
    // （`MiuixGlassAnchor.contentHidden` ← `GlassPopupPresenter._finish`，≈670ms）。
    // 那时转场早就走完，首页（或首页快照）上的「更多」球会是个**没有图标的空球**。
    // 此刻交还正是上游想做的那次视觉交接 —— 弹层自己的形变副本 80ms 就淡完了、
    // 面板也缩成球了 —— 只是不去等那条数学收敛。写已释放的 anchor 会被它自己的
    // `_disposed` 挡掉，这里也先判 mounted。
    if (anchor.contentHidden) {
      anchor.contentHidden = false;
    }
  }

  /// 圆钮点击分发：addCourse/空走添加弹层；内嵌注册页在首页栈内
  /// 切换（坞常驻，再点同钮收回）；其余目录条目普通推入。
  void handleRoundButtonTap(TimetableSettings settings) {
    final id = settings.glassDockButtonEntryId;
    if (id == 'addCourse' || id.isEmpty) {
      unawaited(host.showAddCourseSheet());
      return;
    }
    final catalogEntry = homeMenuEntryById(id);
    if (catalogEntry?.visible() == true && inlineDockPageFor(id) != null) {
      host.dockInlinePageId = host.dockInlinePageId == id ? null : id;
      // 圆钮保留 toggle 收回（Tab 侧再点当前页已改无动作：收回时**圆钮会灭**、
      // 药丸高亮会重新落回日/周，开/收都有可见反馈，按钮式「再点撤销」成立）；
      // 开/收/换页都是真实切换，给触觉。
      host.selectionClick(settings);
      return;
    }
    final entry = homeMenuEntryById(id);
    if (entry != null && entry.visible()) {
      host.selectionClick(settings);
      // 圆钮是另一块液态玻璃、自带光斑，也必须先收掉再推（否则光斑照样被
      // 快照定格）。
      host.pushAfterDockGlowSettled(entry.open);
      return;
    }

    // 旧版本可能保存了已经撤掉的入口 id。图标层会回退成加号，
    // 点击也必须走同一个新增课程回退，不能显示一个无响应按钮。
    unawaited(host.showAddCourseSheet());
  }
}
