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
    final hasWallpaper = currentPath != null && currentPath.isNotEmpty;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHomePageImageTile(
          context,
          l10n: l10n,
          title: l10n.homePageWallpaperTitle,
          path: currentPath,
          onPick: hasWallpaper
              ? _editHomePageBackdropPosition
              : _pickHomePageBackdropImage,
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
          Row(
            children: [
              Expanded(
                child: HyperosButton(
                  label: l10n.homePagePickImageAction,
                  onPressed: onPick,
                ),
              ),
              if (hasWallpaper) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: HyperosButton(
                    label: l10n.homePageClearImageAction,
                    variant: HyperosButtonVariant.secondary,
                    onPressed: onClear,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _pickHomePageBackdropImage() async {
    final targetPath = await pickAndStoreManagedImage(
      directoryName: kHomePageWallpaperDirectoryName,
      filePrefix: kHomePageWallpaperFilePrefix,
      // 「最近使用」要留住前几张壁纸，不能再沿用「选新图就删光本目录」
      // 的清理模式；淘汰交给历史上限（kMaxWallpaperHistoryEntries）。
      cleanupArtifacts: false,
    );
    if (!mounted || targetPath == null) {
      return;
    }
    final previous = _currentBackdropEntry();
    _applyBackdropChange(
      backdropDraft.copyWith(
        homePageWallpaperPath: targetPath,
        clearHomePageBackgroundImagePath: true,
      ),
      remembered: [
        ?previous,
        WallpaperHistoryEntry(key: targetPath),
      ],
    );
  }

  /// 已存在壁纸时点击入口：直接进入位置编辑页，初始值取自上次保存的对齐。
  Future<void> _editHomePageBackdropPosition() async {
    final existingPath = resolveHomePageBackdropImagePath(backdropDraft);
    if (existingPath == null || existingPath.isEmpty) {
      await _pickHomePageBackdropImage();
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
      await _pickHomePageBackdropImage();
      return;
    }
    if (!mounted) {
      return;
    }
    final result = await pushWallpaperPositionPickerPage(
      context,
      imagePath: existingPath,
      initialAlignX: backdropDraft.homePageWallpaperAlignX,
      initialAlignY: backdropDraft.homePageWallpaperAlignY,
      onPickNewImage: () => pickAndStoreManagedImage(
        directoryName: 'home_page_wallpaper',
        filePrefix: 'wallpaper',
        // 编辑页内换图：保留上一张，等确认后再清理。
        cleanupArtifacts: false,
      ),
    );
    if (!mounted || result == null) {
      return;
    }
    if (!result.confirmed) {
      // 用户取消：若在编辑页里换了图，清理那张未被采用的新文件。
      if (result.path != existingPath) {
        final newFile = File(result.path);
        if (newFile.existsSync()) {
          await newFile.delete();
        }
        invalidateHomePageBackdropFileExists(result.path);
      }
      return;
    }
    final previous = _currentBackdropEntry();
    _applyBackdropChange(
      backdropDraft.copyWith(
        homePageWallpaperPath: result.path,
        homePageWallpaperAlignX: result.alignX,
        homePageWallpaperAlignY: result.alignY,
        clearHomePageBackgroundImagePath: true,
      ),
      remembered: [
        ?previous,
        WallpaperHistoryEntry(
          key: result.path,
          alignX: result.alignX,
          alignY: result.alignY,
        ),
      ],
    );
    // 被换下的旧图不再删除：它在「最近使用」里留档，用户可以随时切回，
    // 只有被挤出上限（或恢复默认）时才真正落盘删除。
  }
}
