part of '../timetable_settings_screen.dart';

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

  /// 宿主设置草稿的落盘入口（一般就是宿主的 `_updateDraft`）。
  void applyBackdropDraft(TimetableSettings next);

  /// 课表列表来源：算「在用壁纸白名单」用（历史是全局的，别的课表也可能在用）。
  TimetableProvider get backdropProvider;

  /// 宿主把壁纸 UI 放在**底部弹层**里时，返回该弹层的「请求收起」口子；
  /// 内联在设置页里的宿主返回 null（默认）。
  ///
  /// 只有「要推整页」的动作需要它，理由见 [_withHostSheetClosed]。
  MiuixBottomSheetClose? get backdropHostSheetClose => null;

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
    final closed = Completer<void>();
    close(afterDismiss: closed.complete);
    await closed.future;
    if (!mounted) {
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
    WallpaperHistoryService.notifier.removeListener(
      _onWallpaperHistoryChanged,
    );
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
    ...inUseWallpaperPaths(
      [for (final profile in backdropProvider.profiles) profile.settings],
    ),
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

  /// 壁纸弹窗（「外观编辑」页底部按钮）的正文。
  ///
  /// 内容与「课表页面」设置里的壁纸行**同一套 builder**：改一行两边一起改，
  /// 不存在「设置页能切历史、编辑页不能」这种分叉。
  Widget buildWallpaperSheetBody(
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
      ],
    );
  }

  /// 「最近使用」缩略图条：可一键切回最近设置过的 10 张壁纸。
  ///
  /// 列表 = **全局**历史（所有课表共用，最新在前）中当前可用者；历史还是空的老
  /// 用户，把当前生效的那一张补在最前，一进设置页就能看到自己正用着什么。
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
    final selectedKey = currentKey;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.homePageWallpaperRecentTitle,
            style: HyperosTypography.listTitle(context),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.homePageWallpaperRecentSubtitle,
            style: HyperosTypography.listDetail(context),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 116,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: entries.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final entry = entries[index];
                return _WallpaperThumbnailCard(
                  label: l10n.homePageWallpaperRecentImageLabel,
                  selected: entry.key == selectedKey,
                  onTap: () => _selectBackdropEntry(entry),
                  thumbnail: Image.file(
                    File(entry.key),
                    fit: BoxFit.cover,
                    cacheWidth: 240,
                    // 列表构建后文件被删/损坏时不崩帧。
                    errorBuilder: (context, error, stackTrace) =>
                        const SizedBox.shrink(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
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
        : path.split(Platform.pathSeparator).last;
    final hasWallpaper = path != null && path.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: HyperosTypography.listTitle(context)),
          const SizedBox(height: 4),
          Text(fileName, style: HyperosTypography.listDetail(context)),
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

  /// 清掉 [candidates] 里**没有任何设置 / 历史引用**的壁纸文件。
  ///
  /// 判据是「谁在引用它」，不是记「哪张是新的」：删错一张就是用户口径里的
  /// 「换过壁纸，但最近使用里那张打不开了」。所以正在用的那张（草稿里的）与
  /// 「最近使用」里的条目一律不动。
  Future<void> _discardUnreferencedBackdrops(Set<String> candidates) async {
    if (candidates.isEmpty) {
      return;
    }
    final referenced = <String>{
      ?resolveHomePageBackdropImagePath(backdropDraft),
      for (final entry in _wallpaperHistory) entry.key,
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
