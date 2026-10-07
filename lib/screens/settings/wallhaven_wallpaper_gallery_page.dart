import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';

import '../../l10n/app_localizations.dart';
import '../../models/wallhaven_wallpaper.dart';
import '../../services/bing_wallpaper_store.dart';
import '../../services/wallhaven_wallpaper_service.dart';
import '../../services/wallpaper_history_service.dart';
import '../../ui/hyperos/hyperos.dart';
import '../../utils/app_toast.dart';
import '../../utils/home_page_background.dart';
import '../../utils/wallpaper_history.dart';

/// 图库里点中一张、已下好本地之后的收尾，由宿主实现。
typedef WallhavenWallpaperImageHandler = Future<bool> Function(String imagePath);

/// Wallhaven 竖版图库。
///
/// ## 为什么单独一页而不是把 Bing 那页参数化
///
/// 两页的**卡片内容**根本不同：Bing 那页每张带日期标签 + 版权说明（`dateKey` 是它的
/// 身份，也是「今天那张」的判据），Wallhaven 这页没有日期可言（id 才是身份，见
/// `WallhavenWallpaperService.dailyIndex`）。硬合成一页就要在每张卡片上判「有没有日期」，
/// 于是两页各自都长出一堆分支。
///
/// 但**落盘之后的流程**（位置编辑页 → 宿主落盘 → 三处缓存失效 → 补记历史）刻意
/// 逐字复用 [pushBingWallpaperGalleryPage] 那套约定：宿主的 `onImageDownloaded` 回调
/// 与 `protectedPaths` 白名单都不需要知道图源。
///
/// ## 浏览不下载
///
/// 缩略图走 `thumbs.large`（实测约 105 KB），点某一张才下原图 —— 原图 5–11 MB，
/// 8 张就是 40 MB 起步，绝对不能浏览时就下。
Future<void> pushWallhavenWallpaperGalleryPage(
  BuildContext context, {
  required WallhavenWallpaperImageHandler onImageDownloaded,
  Iterable<String> protectedPaths = const <String>[],
}) => HyperosNavigation.push<void>(
  context,
  builder: (_) => WallhavenWallpaperGalleryPage(
    onImageDownloaded: onImageDownloaded,
    protectedPaths: protectedPaths.toList(growable: false),
  ),
);

class WallhavenWallpaperGalleryPage extends StatefulWidget {
  const WallhavenWallpaperGalleryPage({
    required this.onImageDownloaded,
    this.protectedPaths = const <String>[],
    super.key,
  });

  final WallhavenWallpaperImageHandler onImageDownloaded;

  /// 与 Bing 那页同义：台账溢出要删文件时绝不能删的路径。
  final List<String> protectedPaths;

  @override
  State<WallhavenWallpaperGalleryPage> createState() =>
      _WallhavenWallpaperGalleryPageState();
}

class _WallhavenWallpaperGalleryPageState
    extends State<WallhavenWallpaperGalleryPage> {
  List<WallhavenWallpaperItem> _items = const [];
  bool _loading = true;
  bool _failed = false;

  /// 当前显示的是**上次拉到的清单**（这次网络没给新数据）。
  ///
  /// 不做成错误页：这个源在大陆是常态性慢（见
  /// `WallhavenWallpaperService.foregroundListTimeout` 的注释），把「旧的」当成
  /// 「坏的」处理，用户每次都得重挑一遍图才知道有没有用。
  bool _showingCached = false;

  /// 正在下载的那张的 id；null = 没在下载。
  String? _downloadingId;

  @override
  void initState() {
    super.initState();
    BingWallpaperStore.notifier.addListener(_onStoreChanged);
    unawaited(_load(forceRefresh: false));
  }

  @override
  void dispose() {
    BingWallpaperStore.notifier.removeListener(_onStoreChanged);
    super.dispose();
  }

  void _onStoreChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _load({required bool forceRefresh}) async {
    if (mounted) {
      setState(() {
        _loading = true;
        _failed = false;
      });
    }
    // 拉取**开始**的时刻。结束后拿它与缓存时间戳比就知道这次是不是白等了 ——
    // 时间戳没被刷新 = 网络没给新数据 = 下面显示的是上次的。
    final startedAt = DateTime.now();
    final items = await WallhavenWallpaperService.loadPortrait(
      forceRefresh: forceRefresh,
    );
    if (!mounted) {
      return;
    }
    final cachedAt = BingWallpaperStore.instance.cachedWallhavenItemsFetchedAt;
    setState(() {
      _items = items;
      _showingCached =
          items.isNotEmpty && (cachedAt == null || cachedAt.isBefore(startedAt));
      _loading = false;
      _failed = items.isEmpty;
    });
  }

  Future<void> _pick(WallhavenWallpaperItem item) async {
    if (_downloadingId != null) {
      // 一次只下一张：原图 5–11 MB，并行下几张既费流量也把进度提示弄乱。
      return;
    }
    final store = BingWallpaperStore.instance;
    setState(() => _downloadingId = item.id);
    var path = await store.findExistingWallhaven(item.id);
    if (path == null) {
      final service = WallhavenWallpaperService.createTransient();
      try {
        final result = await service.download(item);
        path = result.path;
        if (result.succeeded) {
          // 手动挑的也记账（为了封顶清理与去重），但 `autoApplied: false` ——
          // 否则它会顶掉自动换「今天已换过」的判据（与 Bing 那页同一口径）。
          //
          // 尺寸记**这张图自己的**尺寸：台账键含尺寸，而它的作用是「这张图下过了没有」，
          // 所以必须是能唯一认出这张图的那一组。
          final evicted = await store.recordWallhaven(
            id: item.id,
            sourceSize: WallpaperTargetSize(item.width, item.height),
            path: result.path!,
          );
          unawaited(_deleteEvicted(evicted, keep: result.path));
        }
      } finally {
        service.dispose();
      }
    }
    if (!mounted) {
      return;
    }
    setState(() => _downloadingId = null);
    if (path == null) {
      showAppToast(
        context,
        message: l10n.bingWallpaperDownloadFailed,
        kind: AppToastKind.warning,
        showKindIcon: true,
      );
      return;
    }
    final applied = await widget.onImageDownloaded(path);
    if (applied && mounted) {
      Navigator.of(context).pop();
    }
  }

  /// 白名单三路并集，口径与 Bing 那页**逐字一致**。
  Future<void> _deleteEvicted(List<String> paths, {String? keep}) async {
    if (paths.isEmpty) {
      return;
    }
    final history = await WallpaperHistoryService.load();
    await deleteEvictedWallpaperFiles(
      paths,
      inUsePaths: <String>{
        ?keep,
        ...widget.protectedPaths,
        for (final entry in history) entry.key,
      },
    );
  }

  AppLocalizations get l10n => AppLocalizations.of(context)!;

  @override
  Widget build(BuildContext context) {
    return HyperosSubpage(
      title: Text(l10n.wallhavenWallpaperGalleryTitle),
      onBack: () => Navigator.of(context).maybePop(),
      child: _buildBody(),
    );
  }

  Widget _buildBody() {
    return HyperosRefreshIndicator(
      onRefresh: () => _load(forceRefresh: true),
      child: CustomScrollView(
        // 与 Bing 那页同一理由：竖图卡片在大屏下填不满一屏，不给
        // AlwaysScrollableScrollPhysics 的话下拉手势根本不被识别。
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // ⚠️ 不要再补顶部留白（inset 里已经含了「标题 → 正文」的设计间距）。
          if (_loading && _items.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: HyperosBlurredBodyInset(
                child: Center(
                  child: MiuixCircularProgressIndicator(
                    colors: MiuixProgressIndicatorColors(
                      foregroundColor: HyperosColors.primary(context),
                      disabledForegroundColor: HyperosColors.primary(context),
                      backgroundColor: Colors.transparent,
                    ),
                  ),
                ),
              ),
            )
          else if (_failed)
            SliverFillRemaining(
              hasScrollBody: false,
              child: HyperosBlurredBodyInset(
                child: _buildFailure(),
              ),
            )
          else ... <Widget>[
            // 「显示的是上次结果」提示条。放在网格**外面**而不是塞进卡片里：
            // 它说的是**整份清单**的来路，不该只挂在某一张卡片上。
            if (_showingCached)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: Text(
                    l10n.wallpaperGalleryShowingCached,
                    style: HyperosTypography.listDetail(
                      context,
                    ).copyWith(color: HyperosColors.secondaryText(context)),
                  ),
                ),
              ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              sliver: SliverGrid(
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 12,
                      // 与 Bing 那页同值（0.56 ≈ 图占七成、字占三成）。
                      childAspectRatio: 0.56,
                    ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _buildTile(_items[index]),
                  childCount: _items.length,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFailure() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.cloud_off_outlined,
              size: 40,
              color: HyperosColors.secondaryText(context),
            ),
            const SizedBox(height: 12),
            Text(
              // ⚠️ 这里曾复用 `bingWallpaperGalleryFailed`，于是用户在「竖版高清图库」
              // 页看到「没能取到 **Bing** 每日壁纸」—— 分不清是选错图源还是 App 坏了。
              l10n.wallhavenGalleryFailed,
              textAlign: TextAlign.center,
              style: HyperosTypography.listDetail(
                context,
              ).copyWith(color: HyperosColors.secondaryText(context)),
            ),
            const SizedBox(height: 16),
            HyperosButton(
              label: l10n.bingWallpaperGalleryRetry,
              onPressed: () => _load(forceRefresh: true),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTile(WallhavenWallpaperItem item) {
    final busy = _downloadingId == item.id;
    final sizeLabel = item.sizeLabel;
    return MiuixPressable(
      onPressed: busy ? null : () => _pick(item),
      borderRadius: BorderRadius.circular(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // ⚠️ 用 [Expanded] 而不是 `AspectRatio`：卡片高度由网格定死，而下面文字
          // 高度随文案变化（与 Bing 那页的⚠️同源）。
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  Image.network(
                    item.galleryThumbnailUrl,
                    fit: BoxFit.cover,
                    // 网格里每张约 180dp 宽，2x 解码足够，不必拉原图（实测原图 5–11 MB）。
                    cacheWidth: 360,
                    loadingBuilder: (context, child, progress) => progress == null
                        ? child
                        : ColoredBox(color: HyperosColors.rowHighlight(context)),
                    errorBuilder: (context, error, stackTrace) => ColoredBox(
                      color: HyperosColors.rowHighlight(context),
                      child: Icon(
                        Icons.image_not_supported_outlined,
                        size: 20,
                        color: HyperosColors.secondaryText(context),
                      ),
                    ),
                  ),
                  if (busy)
                    ColoredBox(
                      color: Colors.black.withValues(alpha: 0.45),
                      child: const Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          // 只有**尺寸**：这张图没有「日期」可言（id 是身份，不是日期）。
          // 尺寸正是这一页最该让人看到的东西 —— 它是「原生竖图、不放大」的直接证据。
          Text(
            '${item.width}×${item.height}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: HyperosTypography.listDetail(context),
          ),
          const SizedBox(height: 2),
          Text(
            sizeLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: HyperosTypography.listDetail(
              context,
            ).copyWith(color: HyperosColors.secondaryText(context)),
          ),
        ],
      ),
    );
  }
}