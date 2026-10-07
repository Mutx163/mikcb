part of '../timetable_settings_screen.dart';

/// 一次「长按删除最近使用」的撤销凭据：删之前的整份历史 + 被删的那张图。
///
/// 存**整份旧列表**而不是「那一条 + 它的下标」：撤销期间历史不会变（用户没有
/// 别的入口改它），而"原样放回"天然把顺序、使用时间、取景值全还原了；顺带也
/// 省掉"插回原位"这种要算下标的活（列表在撤销窗口内可能已被别的删除动过，
/// 下标早就不可信了）。
class _BackdropRemoval {
  const _BackdropRemoval({
    required this.previousHistory,
    required this.removedPath,
  });

  final List<WallpaperHistoryEntry> previousHistory;
  final String removedPath;
}

/// 「最近使用」缩略图条的固定高度。
///
/// 卡内是「缩略图（Expanded）+ 6px + 标签/确认按钮」三段，高度定死才不会因为
/// 其中一张卡进了确认态（标签位换成两颗 24px 按钮）而把整条撑高、邻卡错位。
const double _recentWallpaperStripHeight = 116;

/// 卡内标签位的高度：常态是标签（最多两行 11px），确认态是那颗按钮行。
///
/// 定高的意义是缩略图在两种状态间**尺寸不变** —— 不定高的话 `Expanded` 会把
/// 高度差吃掉，进确认态那一帧缩略图会肉眼可见地缩一下。
const double _recentCardLabelHeight = 26;

/// 首页壁纸流程（选图 / 最近使用 / 位置 / 清除）的**唯一实现**。
///
/// 为什么要抽成 mixin：这段流程同时挂在两个宿主上 —— 「课表页面」设置里的
/// 壁纸行，和「外观编辑」页底部那颗「调整壁纸」按钮打开的弹窗。两处必须**逐
/// 字同源**：历史补记、被淘汰文件的白名单、失效路径的兜底、位置编辑页的确认
/// / 取消语义，任何一处抄错都会造成「换过壁纸但历史没记上」或「误删别的课表
/// 正在用的图」。
///
/// 宿主只需提供四件它本来就有的事：
/// * 当前草稿读写（[backdropDraft] / [applyBackdropDraft]）；
/// * 落盘入口（[applyBackdropDraft] 内部调宿主的 `_updateDraft`）；
/// * 课表列表来源（[backdropProvider]，用于算「哪些文件还在用」）；
/// * 本页是否还挂着（mixin 自己用 `mounted`，不需要宿主额外提供）。
///
/// 历史列表本身由 mixin 持有（[_wallpaperHistory]）：它订阅全局
/// [WallpaperHistoryService]，宿主不必各自接线。
mixin _HomeBackdropFlow<T extends StatefulWidget> on State<T> {
  /// 当前草稿设置（宿主页面持有）。
  TimetableSettings get backdropDraft;

  /// Bing 图库入口那一行的水平内缩。
  ///
  /// 默认**跟随** [backdropRowHorizontalInset]（两个宿主自然一致），但单独开一个口子：
  /// 图库那一行内部要放一颗满宽按钮加一颗开关行，它与选图行/「最近使用」是一套版式，
  /// 万一日后要把它挪到卡片里或挪到弹层外，不必再动 mixin 里那几块的公共逻辑。
  double get bingWallpaperRowInset => backdropRowHorizontalInset;

  /// 宿主设置草稿的落盘入口（一般就是宿主的 `_updateDraft`）。
  void applyBackdropDraft(TimetableSettings next);

  /// 课表列表来源：算「在用壁纸白名单」用（历史是全局的，别的课表也可能在用）。
  TimetableProvider get backdropProvider;

  /// 本宿主给壁纸那两块（选图行 / 最近使用）**额外**留的左右内缩。
  ///
  /// 两个宿主的答案不同，而且**都必须保留各自那个**：
  ///
  /// * 「课表页面」（默认 16）：这两块在 `HyperosListGroup` 卡片里，那 16 是
  ///   **卡片自己的行内缩**，与 `settingsRowPadding` 同口径。去掉的话内容会贴到
  ///   卡片边上。
  /// * 「外观编辑」的壁纸弹窗（0）：那一处**没有任何容器**，左右由面板的
  ///   [hyperosMiuixBottomSheetInsideMargin]（16）提供。两块自己再垫一层 16，
  ///   内容就距边 32 —— 比兄弟弹窗（选周、删除确认、课程备注…标题与按钮都从
  ///   16 起）多缩一截，同一颗按钮旁边的「材质」弹窗又是另一套版式，读起来
  ///   就不协调（用户口径 2026-09-27）。弹窗那一侧改成 0，与兄弟弹窗齐平。
  ///
  /// ⚠️ 只动**左右**；上下由各块自己排（14/14），别一起改。
  double get backdropRowHorizontalInset => 16;

  /// 宿主放壁纸那几块的正文里**有没有卡片底**。
  ///
  /// 「课表页面」那几块在 [HyperosListGroup] 卡片里（默认 true）；「外观编辑」的
  /// 壁纸弹窗整段刻意无容器（false，见 [backdropRowHorizontalInset] 的说明）。
  ///
  /// 只有开关行需要它：[HyperosSwitchTile] 默认会画一层卡片色的行底（"这行住在设置
  /// 卡片里"的意思），在无容器那一侧要显式关掉，否则磨砂面板上凭空多出一块不透明
  /// 色块 —— 就是这块壁纸弹窗一直在消的那种不协调。
  bool get backdropRowsHaveCardBackground => true;

  /// 宿主把壁纸 UI 放在**底部弹层**里时，返回该弹层的「请求收起」口子；
  /// 内联在设置页里的宿主返回 null（默认）。
  ///
  /// 只有「要推整页」的动作需要它，理由见 [_withHostSheetClosed]。
  MiuixBottomSheetClose? get backdropHostSheetClose => null;

  /// 宿主正在退出（`_popSelf` 已置位）：等待弹层收起的推页必须放弃，
  /// 否则会在已退栈的页面上再推一页（「回魂」）。
  bool get backdropFlowExiting => false;

  /// 推整页之前先把宿主弹层收起来；宿主没有弹层就直接执行。
  ///
  /// **为什么必须等它收完**：弹层面板是上游 `MiuixWindowBottomSheet` 插进**根覆盖层**
  /// 的条目，而 `OverlayState.rearrange` 把「非路由条目」排在所有路由**之上**
  /// （`_insertionIndex(null, null) == _entries.length`）。弹层开着时推的路由会落在
  /// 面板**下面**，被它那层全屏透明屏障挡住 —— 真机口径就是「页面在弹窗背后，什么都
  /// 点不到」（2026-09-20 用户报的「调整壁纸显示位置」被壁纸弹窗压住）。
  ///
  /// 走 `afterDismiss` 而不是固定延时：它在退场动画真正结束、条目摘掉之后才回调。
  Future<R?> _withHostSheetClosed<R>(Future<R?> Function() push) async {
    final close = backdropHostSheetClose;
    if (close == null) {
      return push();
    }
    final closed = Completer<bool>();
    close(
      afterDismiss: () {
        if (!closed.isCompleted) {
          closed.complete(false);
        }
      },
      // 退场期间若已有更新路由压上来，旧面板不能再推整页；但等待方仍要结束，
      // 不能让这个 Future 永远挂起。
      onSuperseded: () {
        if (!closed.isCompleted) {
          closed.complete(true);
        }
      },
    );
    final superseded = await closed.future;
    if (!mounted || superseded || backdropFlowExiting) {
      return null;
    }
    return push();
  }

  /// 壁纸「最近使用」历史 —— **全局**（设备级，所有课表共用同一条）。
  ///
  /// 真源是 [WallpaperHistoryService]：mixin 只是它的读者与写者。草稿里那份
  /// `wallpaperHistory` 是给备份 / 云同步留的**镜像**（payload 只带 profiles），
  /// 读取一律走这里。
  List<WallpaperHistoryEntry> _wallpaperHistory = const [];

  /// 「长按删除」后**等着删**的图片路径（给用户反悔的窗口，见
  /// [_scheduleBackdropFileDeletion]）。
  final Set<String> _pendingBackdropDeletions = <String>{};

  /// 待撤销的删除（后进先出）。反悔窗口一过就整体清空 —— 那时文件已经删了，
  /// 再"撤销"只会放回一条永远打不开的死路径。
  final List<_BackdropRemoval> _pendingRemovals = <_BackdropRemoval>[];

  Timer? _backdropDeletionTimer;

  /// 删除后留给「撤销」的时间。取 2.5s：比 toast 的动作按钮常驻时长
  /// （2s）宽一点，避免用户手指刚抬起来按钮就消失。
  static const _backdropDeletionGrace = Duration(milliseconds: 2500);

  @override
  void initState() {
    super.initState();
    // 全局历史是 prefs 里的异步数据：先按空列表渲染，载入完再刷一次；
    // 之后的变更（本页自己写的、别处写的）都靠 notifier 推过来。
    WallpaperHistoryService.notifier.addListener(_onWallpaperHistoryChanged);
    unawaited(_loadWallpaperHistory());
  }

  @override
  void dispose() {
    WallpaperHistoryService.notifier.removeListener(_onWallpaperHistoryChanged);
    // ⚠️ 这里**冲刷**而不是取消：留着定时器等于把这批文件永远忘掉，
    // 「删了历史条目却没人删文件」就是壁纸目录攒垃圾的入口。
    _flushBackdropFileDeletions();
    super.dispose();
  }

  Future<void> _loadWallpaperHistory() async {
    final entries = await WallpaperHistoryService.load();
    if (!mounted || listEquals(entries, _wallpaperHistory)) {
      return;
    }
    setState(() => _wallpaperHistory = entries);
  }

  void _onWallpaperHistoryChanged() {
    final entries = WallpaperHistoryService.notifier.value;
    if (!mounted || listEquals(entries, _wallpaperHistory)) {
      return;
    }
    setState(() => _wallpaperHistory = entries);
  }

  /// 失效一张背景的缓存：图片缓存、文件存在性 memo 与预模糊位图。
  ///
  /// [key] 是背景图绝对路径；null / 空串安全跳过（无背景）。
  void _evictBackdropCaches(String? key) {
    if (key == null || key.isEmpty) {
      return;
    }
    evictHomePageImageCache(key);
    invalidateHomePageBackdropFileExists(key);
    PreblurredWallpaperCache.instance.evict(key);
  }

  /// 当前生效背景对应的历史条目；没有背景时返回 null。
  ///
  /// 带上当前的对齐值，切回时要还原当时的裁剪位置。
  WallpaperHistoryEntry? _currentBackdropEntry() {
    final key = homePageBackdropKey(backdropDraft);
    if (key == null) {
      return null;
    }
    return WallpaperHistoryEntry(
      key: key,
      alignX: backdropDraft.homePageWallpaperAlignX,
      alignY: backdropDraft.homePageWallpaperAlignY,
      scale: backdropDraft.homePageWallpaperScale,
    );
  }

  /// 把 [entries]（按「旧 → 新」顺序）补记进「最近使用」，返回带镜像的设置。
  ///
  /// 历史是**全局**的：以全局那一份为基准算，写完落回全局；同时抄一份进 settings
  /// 当镜像 —— 备份 / 云同步 / 局域网传输的 payload 只序列化 `profiles`，settings
  /// 里留一份，历史才继续随备份走（导入时由 provider 并回全局）。
  ///
  /// 被挤出上限的图片文件不再被任何历史条目引用，异步删除释放空间；删除失败不
  /// 阻断主流程（deleteManagedImage 自身吞掉异常）。删之前必须过一遍在用白名单：
  /// 全局历史里可能有**别的课表**正在用的壁纸。
  TimetableSettings _rememberBackdrops(
    TimetableSettings next,
    List<WallpaperHistoryEntry> entries,
  ) {
    if (entries.isEmpty) {
      return next;
    }
    final result = rememberWallpaperHistoryBatch(
      history: _wallpaperHistory,
      entries: entries,
    );
    unawaited(
      deleteEvictedWallpaperFiles(
        result.evictedPaths,
        inUsePaths: _inUseWallpaperPaths(),
      ),
    );
    unawaited(WallpaperHistoryService.save(result.history));
    _wallpaperHistory = result.history;
    return next.copyWith(wallpaperHistory: result.history);
  }

  /// 删淘汰文件时的白名单：**所有课表**当前的壁纸 + 本页草稿里刚选中的那张。
  ///
  /// 历史全局、壁纸每个课表各自一张，"被历史淘汰"因此不等于"没人用"；草稿里刚
  /// 选中的那张也还没落盘，同样要护住（见 [deleteEvictedWallpaperFiles]）。
  Set<String> _inUseWallpaperPaths() => <String>{
    ...inUseWallpaperPaths([
      for (final profile in backdropProvider.profiles) profile.settings,
    ]),
    ?resolveHomePageBackdropImagePath(backdropDraft),
  };

  /// 应用一次背景切换的收尾：缓存失效 + 补记「最近使用」+ 落盘。
  ///
  /// [next] 已带好背景字段（路径 / 内置预设 / 对齐）；[remembered] 是按
  /// 「旧 → 新」顺序要补记的条目。背景身份没变（只挪裁剪位置）时不动缓存：
  /// 预模糊位图只按路径缓存，与对齐无关。
  void _applyBackdropChange(
    TimetableSettings next, {
    List<WallpaperHistoryEntry> remembered = const [],
  }) {
    final previousKey = homePageBackdropKey(backdropDraft);
    final nextKey = homePageBackdropKey(next);
    if (previousKey != nextKey) {
      _evictBackdropCaches(previousKey);
      _evictBackdropCaches(nextKey);
    }
    applyBackdropDraft(_rememberBackdrops(next, remembered));
  }

  /// 切回「最近使用」里的某一条背景。
  ///
  /// 图片条目恢复当时的裁剪位置；文件已丢失 / 预设已下线的条目不可用，
  /// 直接忽略（下一次重建时它也不会再出现在列表里）。
  void _selectBackdropEntry(WallpaperHistoryEntry entry) {
    final next = settingsWithWallpaperHistoryEntry(backdropDraft, entry);
    if (next == null) {
      return;
    }
    final previous = _currentBackdropEntry();
    _applyBackdropChange(
      next,
      remembered: [
        ?previous,
        WallpaperHistoryEntry(
          key: entry.key,
          alignX: entry.alignX,
          alignY: entry.alignY,
          scale: entry.scale,
        ),
      ],
    );
  }

  /// 「最近使用」里某一张**确认删除之后**的收尾：摘条目 + 落盘 + 排删文件。
  ///
  /// 调用方（条上的确认态）已经挡住了"正在用的那张"，这里不再重复判断 ——
  /// 两处各判一次的话，改一边就会漏另一边。
  ///
  /// 「撤销」仍然留着，但它是**兜底**而不是主防线：主防线是条上那颗要按两次的
  /// 删除（见 [_RecentWallpaperStrip]）。
  void _removeBackdropHistoryEntry(
    BuildContext context,
    WallpaperHistoryEntry entry, {
    required AppLocalizations l10n,
  }) {
    final next = removeWallpaperHistoryEntry(_wallpaperHistory, entry.key);
    if (identical(next, _wallpaperHistory)) {
      return;
    }
    // 撤销凭据必须在改 `_wallpaperHistory` **之前**取：它要存的正是删除前那一份。
    final historyBeforeRemoval = _wallpaperHistory;
    unawaited(WallpaperHistoryService.save(next));
    _wallpaperHistory = next;
    // 镜像同步进设置：备份 / 云同步的 payload 只带 profiles，历史要继续随备份
    // 走得靠这份镜像（真源仍是全局那份，理由同 [_rememberBackdrops]）。
    applyBackdropDraft(backdropDraft.copyWith(wallpaperHistory: next));
    _pendingRemovals.add(
      _BackdropRemoval(
        previousHistory: historyBeforeRemoval,
        removedPath: entry.key,
      ),
    );
    _scheduleBackdropFileDeletion(entry.key);
    showAppToastWithAction(
      context,
      message: l10n.wallpaperHistoryRemovedToast,
      actionLabel: l10n.wallpaperHistoryRemoveUndo,
      onAction: _undoRemoveBackdropHistoryEntry,
    );
  }

  /// 撤销最近一次「长按删除」：整份历史原样放回，并把这张图从待删清单里摘掉。
  void _undoRemoveBackdropHistoryEntry() {
    // toast 的 actionLabel 活在本页之外（2s 反悔窗口），页面被 pop 之后
    // 它仍然可点：宿主 dispose 时 `_flushBackdropFileDeletions` 已经把文件删了，
    // 而这里第 3、4 步会先把全局历史放回、指向那个已经不存在的文件，
    // 第 5 步 `applyBackdropDraft` 才在宿主的 setState 上抛
    // —— 结果正是本文件注释说最忌讳的状态：「最近使用」里留一条打不开的死路径。
    // 页面都没了，撤销无处可放，整条跳过才是自洽的（全局历史保持删除后的样子）。
    if (!mounted) {
      return;
    }
    if (_pendingRemovals.isEmpty) {
      return;
    }
    final removal = _pendingRemovals.removeLast();
    _pendingBackdropDeletions.remove(removal.removedPath);
    unawaited(WallpaperHistoryService.save(removal.previousHistory));
    _wallpaperHistory = removal.previousHistory;
    // 镜像一起回退，否则下一次备份会把"已删除"这条又带回来。
    applyBackdropDraft(
      backdropDraft.copyWith(wallpaperHistory: removal.previousHistory),
    );
  }

  /// 把 [path] 排进「待删」：给 [_backdropDeletionGrace] 的反悔窗口。
  ///
  /// 为什么不立刻删：撤销要把这一条放回列表，文件已经没了的话那一条就是一条
  /// 永远打不开的死路径 —— 而「最近使用」里出现打不开的条目正是这套流程历来
  /// 最忌讳的事（见 [_discardUnreferencedBackdrops] 的注释）。
  void _scheduleBackdropFileDeletion(String path) {
    // 白名单按**删除那一刻**的课表状态算：别的课表可能正拿这张图当壁纸，删了
    // 对方首页就缺图。宿主自己不用算进去 —— 上面已经把"正在用"挡掉了。
    final inUse = <String>{
      for (final profile in backdropProvider.profiles)
        if (profile.id != backdropProvider.activeProfileId)
          ?resolveHomePageBackdropImagePath(profile.settings),
    };
    if (deletableWallpaperPaths([path], inUsePaths: inUse).isEmpty) {
      return;
    }
    _pendingBackdropDeletions.add(path);
    _backdropDeletionTimer?.cancel();
    // 每次删除都重新起算：连着删两张时，第二张按下就说明第一张的反悔窗口
    // 用户已经用过了（或者根本不要），从这一下起重新给满窗口。
    _backdropDeletionTimer = Timer(
      _backdropDeletionGrace,
      _flushBackdropFileDeletions,
    );
  }

  /// 真删待删清单里的文件（反悔窗口已过 / 页面正在退出）。
  void _flushBackdropFileDeletions() {
    _backdropDeletionTimer?.cancel();
    _backdropDeletionTimer = null;
    _pendingRemovals.clear();
    if (_pendingBackdropDeletions.isEmpty) {
      return;
    }
    final paths = _pendingBackdropDeletions.toList(growable: false);
    _pendingBackdropDeletions.clear();
    unawaited(deleteEvictedWallpaperFiles(paths, inUsePaths: _inUseWallpaperPaths()));
  }

  /// 壁纸弹窗的正文 —— 2026-09-28 起**分成两页**，见下面两个 builder。
  ///
  /// 共同点：内容与「课表页面」设置里的壁纸行**同一套 builder**，改一行两边一起改，
  /// 不存在「设置页能切历史、编辑页不能」这种分叉。左右内缩由
  /// [backdropRowHorizontalInset] 按宿主给（弹窗这一侧是 0，见那里的注释）。
  ///
  /// 底部那颗「背景随周次滑动」开关（[_buildBackdropFollowsWeekPagerTile]）同样
  /// 走这条路：2026-09-28 起在「调壁纸」的地方就能决定背景要不要跟着周次动，
  /// 不必先跳去「课表页面」设置才找得到。
  ///
  /// ## 为什么拆两页
  ///
  /// 外观编辑的壁纸弹窗改成**左右两页**（与材质面板同一个形状，见
  /// `_WallpaperSheetBody`）：第一页放选图与「最近使用」，第二页放「背景随周次滑动」
  /// 这类开关。原先三块挤在一页，弹窗被顶得很高，底下那颗开关永远要滚很久才够得着。
  ///
  /// 两页各一个入口、内容仍由下面这三个 builder 生成，所以换宿主不会让它们分叉。
  /// （原先那个把三块合起来的 `buildWallpaperSheetBody` 已随之删除 —— 分页之后
  /// 没有任何调用方，留着就是一份没人跑的「第三个版本」。）

  /// 壁纸弹窗的**第一页「壁纸」**：选图行 + 「最近使用」缩略图条。
  Widget buildWallpaperSheetSelectionPage(
    BuildContext context, {
    required AppLocalizations l10n,
  }) {
    final currentPath = resolveHomePageBackdropImagePath(backdropDraft);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHomePageImageTile(
          context,
          l10n: l10n,
          title: l10n.homePageWallpaperTitle,
          path: currentPath,
          // 「选择图片」不再看状态分岔：永远是"选图 → 定位 → 确认"。只想调
          // 当前位置的走它旁边那颗「调整位置」。
          onPick: _pickAndPositionHomePageBackdrop,
          onAdjustPosition: _editHomePageBackdropPosition,
          onClear: () {
            final stalePath = resolveHomePageBackdropImagePath(backdropDraft);
            _evictBackdropCaches(stalePath);
            // 文件不再被当前背景引用，但多半还在「最近使用」里：改由历史淘汰
            // （挤出上限 / 恢复默认）负责删除。若在这里直接删，用户从历史切回
            // 时只会拿到一条死路径。
            applyBackdropDraft(
              backdropDraft.copyWith(
                clearHomePageWallpaperPath: true,
                clearHomePageBackgroundImagePath: true,
              ),
            );
          },
        ),
        _buildRecentWallpaperTile(context, l10n: l10n),
        _buildBingWallpaperTile(context, l10n: l10n),
      ],
    );
  }

  /// 「Bing 每日壁纸」入口行 + 自动换开关。
  ///
  /// 放在「最近使用」之后：相册选图与历史回放是**用户自己的图**，Bing 是**外部来源**，
  /// 顺序上后者在后。开关紧跟入口行 —— 用户在图库页挑上瘾了，顺手就能把自动换打开。
  Widget _buildBingWallpaperTile(
    BuildContext context, {
    required AppLocalizations l10n,
  }) {
    final inset = bingWallpaperRowInset;
    return Padding(
      padding: EdgeInsets.fromLTRB(inset, 4, inset, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: double.infinity,
            child: HyperosButton(
              label: l10n.bingWallpaperGalleryTitle,
              variant: HyperosButtonVariant.secondary,
              onPressed: _openBingWallpaperGallery,
            ),
          ),
          const SizedBox(height: 4),
          // ⚠️ 这颗开关**必须自己订阅台账通知**，不能靠宿主 `setState`。
          //
          // 壁纸弹层的正文插在**根覆盖层**里，**不在宿主的 widget 树下**（见
          // `settings_appearance_editor.dart` 里那张 `ValueListenableBuilder` 上方的
          // 注释：「弹层正文不在本页 widget 树下，页面 setState 带不动它」）。那边为此
          // 专门监听了一个「草稿版本号」，而自动换开关写的是 `BingWallpaperStore`、
          // **不走草稿**，那条通知对它完全无感。
          //
          // 于是 `_setBingAutoApply` 里那句 `setState` 对本宿主是**空操作**：开关值
          // 其实已经写进台账（所以下载会跑、提示会弹），但画面纹丝不动 —— 用户看到
          // 的就是「点了一下没反应，过一会冒出一句莫名其妙的提示」（2026-10-06 实报）。
          //
          // 自己挂一个 [ValueListenableBuilder] 就与「这段代码被挂在哪棵树上」无关：
          // 无论在弹层里还是在页面里，台账一变就重建。
          ValueListenableBuilder<int>(
            valueListenable: BingWallpaperStore.notifier,
            builder: (context, _, _) => HyperosSwitchTile(
              title: l10n.bingWallpaperAutoApplyTitle,
              subtitle: l10n.bingWallpaperAutoApplySubtitle,
              backgroundColor: backdropRowsHaveCardBackground
                  ? null
                  : Colors.transparent,
              value: BingWallpaperStore.instance.autoApplyEnabled,
              onChanged: _setBingAutoApply,
            ),
          ),
        ],
      ),
    );
  }

  /// 写自动换开关。
  ///
  /// **打开时立即换一次**（当场兑现承诺），不等下一次启动：用户刚打开这颗开关就该看到
  /// 壁纸变了，才知道它真的在工作；否则要等到下次打开 App 才有反馈，而那时他已经忘了
  /// 刚才开了什么。直接落盘，**不推位置页**（见 [_applyDailyBingWallpaper]）。
  Future<void> _setBingAutoApply(bool value) async {
    await BingWallpaperStore.instance.setAutoApplyEnabled(value);
    // ⚠️ `HyperosSwitchTile` 是**无状态**组件，画面全靠父级传进去的 `value`。
    // 而两个宿主都**不能**靠 `setState` 把它带亮：弹层正文在根覆盖层里、不在本页
    // widget 树下（见 `_buildBingWallpaperTile` 里那段⚠️）。真正让它动起来的是那里
    // 给开关挂的 `ValueListenableBuilder` —— 本方法只负责把值写进台账（那份通知
    // 自然会触发重建）。这里仍留一句 `setState` 给将来把这一行内联进页面的宿主。
    if (mounted) {
      setState(() {});
    }
    if (!mounted || !value) {
      return;
    }
    showAppToast(
      context,
      message: AppLocalizations.of(context)!.bingWallpaperAutoApplyApplying,
    );
    await _applyDailyBingWallpaper();
  }

  /// 自动换的执行体：拉最新那张 → 下到本地 → **直接落盘**。
  ///
  /// ## 为什么**不**走手动选图那条路（不推位置页）
  ///
  /// 早先这里是复用 [_openBackdropPositionEditor] 的，于是打开开关会弹一页要用户拖动
  /// 取景再点「完成」，把一个**自动**功能做成了半手动，还会顺手把壁纸设置弹层收掉。
  /// 用户 2026-10-06 的口径就是「自动换今日壁纸就应该在默认状态下直接应用」。
  ///
  /// 落盘仍走 [_applyBackdropChange]：新旧两张的缓存失效由它统一负责（与手动那条路
  /// 同一套，不会出现"首页画旧位图直到重启"）。
  ///
  /// 自动换**不补记「被换下的那一张」**（`remembered` 留空）：历史是全局 10 条，若每天
  /// 自动换都记两条，10 天后用户自己从相册存的那几张会被挤出并**连带删掉文件**。当前
  /// 这张仍会出现在「最近使用」里 —— [_buildRecentWallpaperTile] 会把「当前生效但
  /// 历史里没有」那张补在最前。
  Future<void> _applyDailyBingWallpaper() async {
    final result = await BingWallpaperService.maybeApplyDaily(
      // 白名单三路已在 `_deleteEvictedWallpapers` 里并起来，这里给"所有课表当前壁纸
      // + 本页草稿那张"那一路。新图由那个方法自己加进白名单。
      inUsePaths: _inUseWallpaperPaths(),
    );
    if (!mounted) {
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    switch (result.outcome) {
      case BingAutoApplyOutcome.failed:
        // ⚠️ 这里**必须**出声。用户刚点了开关、亲眼看过「正在换成今天的壁纸」，
        // 早先的实现在这里直接 return，于是无论断网、拉不到、还是「Bing 还没出今天的
        // 图」，用户看到的都是同一句提示之后**什么都没有** —— 也就是用户报的原话
        // 「点了没反应」（2026-10-06）。
        showAppToast(
          context,
          message: l10n.bingWallpaperGalleryFailed,
          kind: AppToastKind.warning,
          showKindIcon: true,
        );
        return;
      case BingAutoApplyOutcome.alreadyApplied:
        // 今天已经换过了。这不是错误，但用户是**刚点了开关**才走到这里的，
        // 同样不能一句话都不给。
        showAppToast(
          context,
          message: l10n.bingWallpaperAutoApplyAlreadyDone,
        );
        return;
      case BingAutoApplyOutcome.appliedStale:
        // 换成了，只是换的不是今天那张 —— 说清楚是哪一天，别让用户以为程序出错。
        showAppToast(
          context,
          message: l10n.bingWallpaperAutoApplyStale(
            bingWallpaperDateLabel(l10n, result.dateKey ?? ''),
          ),
        );
      case BingAutoApplyOutcome.disabled:
      case BingAutoApplyOutcome.appliedToday:
        break;
    }
    final path = result.path!;
    // ⚠️ **直接落盘，不推位置页**（2026-10-06 用户口径：「自动换今日壁纸就应该在默认
    // 状态下直接应用」）。早先这里复用手动选图那条路、会弹一页要用户拖动取景再点
    // 「完成」，把一个**自动**功能做成了半手动 —— 而且它还顺手把壁纸设置弹层收掉了，
    // 让人以为「点了没反应」。
    //
    // 与启动/回前台那条路径（`main.dart` 的 `_maybeAutoApplyDailyBingWallpaper`）
    // 现在是**同一套语义**：居中起步、直接写草稿、不进「最近使用」。
    //
    // 不进「最近使用」的理由：历史是全局 10 条，自动换每天记一条的话，10 天后用户
    // 自己从相册挑的那几张会被挤出去并**连带删掉文件**。当前这张仍会出现在「最近
    // 使用」里 —— `_buildRecentWallpaperTile` 会把「当前生效但历史里没有」那张补在最前。
    //
    // 「今天已换过」的认领也不再需要撤回：没有用户确认这一步，不存在「认领了却没
    // 换上」的可能。
    _applyBackdropChange(
      backdropDraft.copyWith(
        homePageWallpaperPath: path,
        homePageWallpaperAlignX: 0,
        homePageWallpaperAlignY: 0,
        homePageWallpaperScale: 1,
        clearHomePageBackgroundImagePath: true,
      ),
    );
  }

  /// 推图库页 → 点一张 → **位置编辑页压在图库之上**。
  ///
  /// ## 退栈顺序（2026-10-06 用户口径）
  ///
  /// 「点完大屏、点退出，应该回到壁纸列表，而不是最开始的地方」—— 所以图库页**留在栈里**，
  /// 由 [_applyBingDownloadedImage] 在它之上推位置编辑页：
  /// * 位置页「退出」→ 回到图库，接着挑；
  /// * 位置页「完成」→ 落盘并返回 true，图库页这才自己退出。
  ///
  /// 早先的实现是「选图后先弹掉图库、再推位置页」，退出就直接落回设置页，想换一张得
  /// 重走一遍「设置 → Bing 每日壁纸」。那条推理写在代码注释里也留了记录，别再改回去。
  ///
  /// 必须走 [_withHostSheetClosed]：与 [_openBackdropPositionEditor] 同一个理由 ——
  /// 壁纸弹窗那一侧若还开着，推上去的整页会落在弹层面板**下面**，被它的全屏透明屏障
  /// 挡住（2026-09-20 真机口径：「页面在弹窗背后，什么都点不到」）。
  Future<void> _openBingWallpaperGallery() async {
    await _withHostSheetClosed(() async {
      if (!mounted) {
        return;
      }
      await pushBingWallpaperGalleryPage(
        context,
        onImageDownloaded: _applyBingDownloadedImage,
        // 白名单必须与 `_inUseWallpaperPaths` 同口径（所有课表 + 草稿）：
        // 自动换写下的壁纸**不在「最近使用」里**，只传当前这一张会在台账溢出时
        // 删掉别的课表正在用的那张，首页当场裂图。
        protectedPaths: _inUseWallpaperPaths(),
      );
    });
  }

  /// 图库里点中一张之后的收尾：在**图库之上**推位置编辑页，返回是否已落盘。
  ///
  /// 用宿主自己的 [context] 推 —— 图库页是同一个 navigator 上更靠上的一条路由，从这里推
  /// 自然落在它**之上**，于是「退出」回图库、「完成」关两张页。
  Future<bool> _applyBingDownloadedImage(String imagePath) async {
    final result = await pushWallpaperPositionPickerPage(
      context,
      imagePath: imagePath,
      initialAlignX: 0,
      initialAlignY: 0,
    );
    if (!mounted) {
      return false;
    }
    // 本次交互可能产生的文件：新下的那张 + 页内「换壁纸」再选的那张。
    final candidates = <String>{imagePath, ?result?.path};
    if (result == null || !result.confirmed) {
      // 退出：一张都没被采用 —— 删掉，别在壁纸目录里攒垃圾。图库页留着让用户再挑。
      await _discardUnreferencedBackdrops(candidates);
      return false;
    }
    final previous = _currentBackdropEntry();
    _applyBackdropChange(
      backdropDraft.copyWith(
        homePageWallpaperPath: result.path,
        homePageWallpaperAlignX: result.alignX,
        homePageWallpaperAlignY: result.alignY,
        homePageWallpaperScale: result.scale,
        clearHomePageBackgroundImagePath: true,
      ),
      remembered: [
        ?previous,
        WallpaperHistoryEntry(
          key: result.path,
          alignX: result.alignX,
          alignY: result.alignY,
          scale: result.scale,
        ),
      ],
    );
    // 落盘**之后**才清：这时"在用的那张"已经是 result.path、前一张进了「最近
    // 使用」，两者都会被下面的引用集合护住。
    await _discardUnreferencedBackdrops(candidates);
    return true;
  }

  /// 壁纸弹窗的**第二页「设置」**：开关类设置（目前只有「背景随周次滑动」）。
  Widget buildWallpaperSheetSettingsPage(
    BuildContext context, {
    required AppLocalizations l10n,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [_buildBackdropFollowsWeekPagerTile(context, l10n: l10n)],
    );
  }

  /// 「背景随周次滑动」开关行 —— 与「课表页面」设置里的那行**同一个 builder、
  /// 同一份设置**（2026-09-28 用户要求：外观编辑页的壁纸弹窗里也要有这开关，
  /// 且默认关）。
  ///
  /// 挂在 mixin 上而不是各宿主各抄一份，理由和上面两块一样：它是**同一个开关**，
  /// 在弹窗里切了，课表页面那行立刻跟上（反之亦然）。两个宿主都要它，也就顺带拿到
  /// 了各自的版式（行高与内缩由 [HyperosSwitchTile] 自己按行位算）。
  Widget _buildBackdropFollowsWeekPagerTile(
    BuildContext context, {
    required AppLocalizations l10n,
  }) {
    // ⚠️ **外面不要再垫任何 `Padding`**（2026-09-28 用户报「上下空白太多，尤其是到
    // 底部小白条那一截」）：这一行是 [HyperosSwitchTile]，自带 `hyperosRowPadding`
    // 的 13/13（两行行高 72 = 13 + 文字 43.9 + 13，剩 2 摊在文字上下各 1），而上面
    // 两块（选图行 / 最近使用）的 14/14 是**它们自己那一份**的留白。两边各有一份，
    // 再垫一层 14 就是同一段留白算两遍：
    //
    //   缩略图标签底 → 开关标题顶：14 + 14 + 14 = 42（改后 14 + 14 = 28）
    //   开关副标题底 → 面板内容底：14 + 14 + 16(面板统一呼吸) = 44（改后 14 + 16 = 30）
    //
    // 而它又是**最后一块**，多出来的全堆在它后面，所以下面那截尤其显眼。改后的两个数
    // 与「课表页面」卡片里同一行完全一致（那一侧本来就没有这层 Padding）。
    //
    // 左右同理：不要再垫 [backdropRowHorizontalInset]，行自己那 16 正好与兄弟弹窗齐平。
    return HyperosSwitchTile(
      title: l10n.homePageBackdropFollowsWeekPagerTitle,
      subtitle: l10n.homePageBackdropFollowsWeekPagerSubtitle,
      // 无容器那一侧要关掉行底色（见 [backdropRowsHaveCardBackground]）。
      backgroundColor: backdropRowsHaveCardBackground
          ? null
          : Colors.transparent,
      value: backdropDraft.homePageBackdropFollowsWeekPager,
      onChanged: (value) => applyBackdropDraft(
        backdropDraft.copyWith(homePageBackdropFollowsWeekPager: value),
      ),
    );
  }

  /// 「最近使用」缩略图条：可一键切回最近设置过的 10 张壁纸。
  ///
  /// 列表 = **全局**历史（所有课表共用，最新在前）中当前可用者；历史还是空的老
  /// 用户，把当前生效的那一张补在最前，一进设置页就能看到自己正用着什么。
  ///
  /// 整块（标题 + 条 + 移除确认条）都是 [_RecentWallpaperSection]：确认态是
  /// 这一段的 widget 状态，条本身是无状态的，所以确认按钮能画在**条外面**。
  Widget _buildRecentWallpaperTile(
    BuildContext context, {
    required AppLocalizations l10n,
  }) {
    final currentKey = homePageBackdropKey(backdropDraft);
    final entries = <WallpaperHistoryEntry>[
      if (currentKey != null &&
          !_wallpaperHistory.any((entry) => entry.key == currentKey))
        WallpaperHistoryEntry(
          key: currentKey,
          alignX: backdropDraft.homePageWallpaperAlignX,
          alignY: backdropDraft.homePageWallpaperAlignY,
          scale: backdropDraft.homePageWallpaperScale,
        ),
      ...availableWallpaperHistory(_wallpaperHistory),
    ];
    if (entries.isEmpty) {
      return const SizedBox.shrink();
    }
    return _RecentWallpaperSection(
      entries: entries,
      selectedKey: currentKey,
      l10n: l10n,
      horizontalInset: backdropRowHorizontalInset,
      onSelect: _selectBackdropEntry,
      // 「正在用的那张不给移除」这一关放在**发起之前**：它连角标都没有，唯一的
      // 入口是长按，而长按的解释只能由这里给。
      onBlockedRemove: (context, entry) =>
          _warnBackdropHistoryInUse(context, entry, l10n: l10n),
      onConfirmRemove: (context, entry) => _removeBackdropHistoryEntry(
        context,
        entry,
        l10n: l10n,
      ),
    );
  }

  /// 「正在用的那张不给移除」的提示。
  ///
  /// 那一行没有角标（可移除入口靠角标表达），所以这条只可能来自长按 —— 长按
  /// 之后除了解释一句，不做任何改动。
  void _warnBackdropHistoryInUse(
    BuildContext context,
    WallpaperHistoryEntry entry, {
    required AppLocalizations l10n,
  }) {
    if (resolveHomePageBackdropImagePath(backdropDraft) != entry.key) {
      return;
    }
    showAppToast(
      context,
      message: l10n.wallpaperHistoryRemoveInUseToast,
      kind: AppToastKind.warning,
      showKindIcon: true,
    );
  }

  Widget _buildHomePageImageTile(
    BuildContext context, {
    required AppLocalizations l10n,
    required String title,
    required String? path,
    required Future<void> Function() onPick,
    required Future<void> Function() onAdjustPosition,
    required VoidCallback onClear,
  }) {
    final fileName = path == null || path.isEmpty
        ? l10n.homePageImageNotSelected
        // 两种分隔符都切，而不是 `Platform.pathSeparator`：这条路径可能是**别的
        // 平台**存下来的（设置能跨设备同步，本仓也有 linux / macos / windows
        // 目标），只按当前系统的分隔符切，整条路径会被当成文件名显示出来。
        : path.split(RegExp(r'[\\/]')).last;
    final hasWallpaper = path != null && path.isNotEmpty;
    // 路径还在、文件已经没了（换机 / 清理数据 / 云同步只带回设置不带图）。
    //
    // 此前这一格只显示文件名，用户看不出"图没了"，而首页早就静悄悄退回纯色底 ——
    // 表现就是"壁纸功能坏了"。这里把这件事说出来，并让整块可点回「选择图片」。
    //
    // 存在性判据走 `homePageImageProvider`（渲染侧判"有没有壁纸"用的同一条，
    // 背后是按路径记忆的 memo，不摸盘）：判据分叉过一次就会出现"提示说没了、
    // 首页却画着图"这种自相矛盾。刻意不直接 `File(path).existsSync()`。
    final fileMissing = hasWallpaper && homePageImageProvider(path) == null;
    // 左右按宿主给（弹窗那一侧是 0，见 [backdropRowHorizontalInset]）；上下照旧。
    final inset = backdropRowHorizontalInset;
    return Padding(
      padding: EdgeInsets.fromLTRB(inset, 14, inset, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: HyperosTypography.listTitle(context)),
          const SizedBox(height: 4),
          Text(fileName, style: HyperosTypography.listDetail(context)),
          if (fileMissing) ...[
            const SizedBox(height: 10),
            _buildMissingWallpaperNotice(context, l10n: l10n, onTap: onPick),
          ],
          const SizedBox(height: 12),
          // 「选择图片」独占一行、占满宽度（主操作）；已有壁纸时，次级的
          //「调整位置」「清除图片」在第二行平分。
          //
          // ⚠️ **别把三颗挤回一行**：真机上（约 405dp 宽）扣掉「面板 + 内容」各一份
          // 左右内边距后，每颗只剩约 105dp，四字文案放不下 —— 用户口径 2026-09-20
          //「这三个按钮每一个都掉下去一个字，都有换行」。宁可多一行，也不让字折行。
          SizedBox(
            width: double.infinity,
            child: HyperosButton(
              label: l10n.homePagePickImageAction,
              onPressed: onPick,
            ),
          ),
          if (hasWallpaper) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                // 「调整位置」只在已有壁纸时有意义（没壁纸时先选图）。
                //
                // 它补的是 2026-09-20 那次改动腾出来的能力：改之前这颗「选择图片」
                // 在已有壁纸时直接进位置页，所以"只想微调位置"点它就够了；改成
                // 「一律先开相册」之后，没有这颗就等于"想调位置必须重选一张图"。
                Expanded(
                  child: HyperosButton(
                    label: l10n.homePageAdjustPositionAction,
                    variant: HyperosButtonVariant.secondary,
                    onPressed: onAdjustPosition,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: HyperosButton(
                    label: l10n.homePageClearImageAction,
                    variant: HyperosButtonVariant.secondary,
                    onPressed: onClear,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// 「壁纸文件已丢失」的提示条：一行警示色说明 + 点按回到选图。
  ///
  /// 刻意做成**可点**而不是纯文字：这一格的正下方就是「选择图片」按钮，把提示
  /// 本身做成同一个动作，用户看到警示时手指已经在正确的位置上了。
  Widget _buildMissingWallpaperNotice(
    BuildContext context, {
    required AppLocalizations l10n,
    required Future<void> Function() onTap,
  }) {
    return MiuixPressable(
      onPressed: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          // 警示底用 error 色的一点点，够被认出来又不至于像报错弹窗。
          color: HyperosColors.error(context).withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.broken_image_outlined,
              size: 18,
              color: HyperosColors.error(context),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.homePageWallpaperFileMissingTitle,
                    style: HyperosTypography.listDetail(context).copyWith(
                      color: HyperosColors.error(context),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l10n.homePageWallpaperFileMissingSubtitle,
                    style: HyperosTypography.listDetail(context).copyWith(
                      color: HyperosColors.secondaryText(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 选图入口：**永远先开相册**，选完统一进位置编辑页确认。
  ///
  /// 口径（2026-09-20 用户拍板）：改之前这颗按钮按「当前有没有壁纸」分岔 ——
  /// 没壁纸时选完**直接生效**（新选的图从没机会调位置），有壁纸时反而直接跳位置
  /// 页、相册要进页后再点「换壁纸」。同一个按钮两套语义，而文案写着「选择图片」
  /// 却不选图。现在收敛成一条：**选图 → 定位 → 确认**。
  ///
  /// 「只想微调当前这张图的位置」走另一颗「调整位置」钮
  /// （[_editHomePageBackdropPosition]），不再靠这颗按钮兼职。
  Future<void> _pickAndPositionHomePageBackdrop() async {
    final targetPath = await _pickHomePageBackdropImage();
    if (!mounted || targetPath == null) {
      return;
    }
    await _openBackdropPositionEditor(
      imagePath: targetPath,
      // 全新的图从**居中**起步（位置页内「换壁纸」也是这个口径）。
      initialAlignX: 0,
      initialAlignY: 0,
      pickedPaths: {targetPath},
    );
  }

  /// 开相册并把选中的图落进本 app 管理的壁纸目录；取消 / 失败返回 null。
  ///
  /// 「最近使用」要留住前几张壁纸，所以不能沿用「选新图就删光本目录」的清理
  /// 模式；淘汰交给历史上限（[kMaxWallpaperHistoryEntries]）。
  Future<String?> _pickHomePageBackdropImage() => pickAndStoreManagedImage(
    directoryName: kHomePageWallpaperDirectoryName,
    filePrefix: kHomePageWallpaperFilePrefix,
    cleanupArtifacts: false,
  );

  /// 进位置编辑页 → 按结果落盘 → 清掉这次交互里**没人引用**的图。
  ///
  /// [pickedPaths] 是进页**之前**由相册新产生的文件（就是刚选的那张）；页内
  /// 「换壁纸」再选的那张由页面返回的 path 带回来。两者合起来算"本次交互的产物"，
  /// 退出时凡是不被引用的都删掉 —— 否则壁纸目录里会攒下谁都不引用的垃圾。
  ///
  /// ## 这里只服务**手动**选图
  ///
  /// 自动换**不走这里**（它直接落盘、不弹位置页，见 [_applyDailyBingWallpaper]）。
  /// 所以本方法不需要返回"是否真的落盘了"：手动那两条调用方只关心副作用，而早先那个
  /// `Future<bool>` 是为自动换的"用户点退出 → 撤回认领"准备的，那条路已经没了。
  Future<void> _openBackdropPositionEditor({
    required String imagePath,
    required double initialAlignX,
    required double initialAlignY,
    required Set<String> pickedPaths,
    double initialScale = 1,
  }) async {
    final result = await _withHostSheetClosed(
      () => pushWallpaperPositionPickerPage(
        context,
        imagePath: imagePath,
        initialAlignX: initialAlignX,
        initialAlignY: initialAlignY,
        initialScale: initialScale,
        // 页内「换壁纸」与外面同一套选图（落进本 app 目录、不清理旧文件）。
        onPickNewImage: _pickHomePageBackdropImage,
      ),
    );
    if (!mounted) {
      return;
    }
    final candidates = <String>{...pickedPaths, ?result?.path};
    if (result == null || !result.confirmed) {
      // 取消：这次选的图一张都没被采用 —— 删掉，别留在壁纸目录里。
      await _discardUnreferencedBackdrops(candidates);
      return;
    }
    final previous = _currentBackdropEntry();
    _applyBackdropChange(
      backdropDraft.copyWith(
        homePageWallpaperPath: result.path,
        homePageWallpaperAlignX: result.alignX,
        homePageWallpaperAlignY: result.alignY,
        homePageWallpaperScale: result.scale,
        clearHomePageBackgroundImagePath: true,
      ),
      remembered: [
        ?previous,
        WallpaperHistoryEntry(
          key: result.path,
          alignX: result.alignX,
          alignY: result.alignY,
          scale: result.scale,
        ),
      ],
    );
    // 落盘**之后**才清：这时"在用的那张"已经是 result.path、前一张进了「最近
    // 使用」，两者都会被下面的引用集合护住。
    await _discardUnreferencedBackdrops(candidates);
  }

  /// 清掉 [candidates] 里**没有任何设置 / 历史 / 图库缓存引用**的壁纸文件。
  ///
  /// 判据是「谁在引用它」，不是记「哪张是新的」：删错一张就是用户口径里的
  /// 「换过壁纸，但最近使用里那张打不开了」。所以正在用的那张（草稿里的）与
  /// 「最近使用」里的条目一律不动。
  ///
  /// ## 图库缓存里的也算「有人引用」（2026-10-06）
  ///
  /// 用户问「看过的图重新打开要重新下载吗」—— 早先这里会把「下过但没确认应用」的那张
  /// 直接删掉（它既不在设置里也不在历史里），于是下次点回同一张必然重新下载一遍，
  /// 白花流量。台账（`BingWallpaperStore`）就是**图库下载缓存**，它记着的路径一律
  /// 视为被引用；真正该删的由台账自己的上限负责（`kMaxDownloadedEntries`）。
  Future<void> _discardUnreferencedBackdrops(Set<String> candidates) async {
    if (candidates.isEmpty) {
      return;
    }
    final referenced = <String>{
      ?resolveHomePageBackdropImagePath(backdropDraft),
      for (final entry in _wallpaperHistory) entry.key,
      ...BingWallpaperStore.instance.downloadedPaths,
    };
    for (final path in candidates) {
      if (path.isEmpty || referenced.contains(path)) {
        continue;
      }
      final file = File(path);
      if (!file.existsSync()) {
        continue;
      }
      await file.delete();
      _evictBackdropCaches(path);
    }
  }

  /// 「调整位置」入口：进位置编辑页，初始值取自上次保存的对齐。
  Future<void> _editHomePageBackdropPosition() async {
    final existingPath = resolveHomePageBackdropImagePath(backdropDraft);
    if (existingPath == null || existingPath.isEmpty) {
      await _pickAndPositionHomePageBackdrop();
      return;
    }
    // 壁纸文件可能已丢失（重装/清除数据后设置被备份恢复、跨设备同步只带回
    // JSON 不带文件等）：此时进入位置编辑页会在读取图片时抛
    // PathNotFoundException。改为清掉失效路径，直接走重新选图流程。
    //
    // 清掉之前先说一声：这一步会**改掉用户的设置**，而症状（首页变纯色底）
    // 此前是静悄悄的。不说的话，用户只会觉得"点调整位置把壁纸弄丢了"。
    if (!File(existingPath).existsSync()) {
      _evictBackdropCaches(existingPath);
      if (!mounted) {
        return;
      }
      applyBackdropDraft(
        backdropDraft.copyWith(
          clearHomePageWallpaperPath: true,
          clearHomePageBackgroundImagePath: true,
        ),
      );
      showAppToast(
        context,
        message: AppLocalizations.of(context)!.homePageWallpaperFileMissingToast,
        kind: AppToastKind.warning,
        showKindIcon: true,
      );
      await _pickAndPositionHomePageBackdrop();
      return;
    }
    if (!mounted) {
      return;
    }
    await _openBackdropPositionEditor(
      imagePath: existingPath,
      initialAlignX: backdropDraft.homePageWallpaperAlignX,
      initialAlignY: backdropDraft.homePageWallpaperAlignY,
      initialScale: backdropDraft.homePageWallpaperScale,
      // 进页前没有新选文件：本次交互的产物只有页内可能「换壁纸」的那张。
      // 当前这张正在用，会被 [_discardUnreferencedBackdrops] 的引用集合护住；
      // 被换下的旧图也不在这里删 —— 它在「最近使用」里留档，用户可以随时切回，
      // 只有被挤出上限（或恢复默认）时才真正落盘删除。
      pickedPaths: const {},
    );
  }
}
