import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';

import '../../l10n/app_localizations.dart';
import '../../models/bing_wallpaper.dart';
import '../../services/bing_wallpaper_service.dart';
import '../../services/bing_wallpaper_store.dart';
import '../../services/wallpaper_history_service.dart';
import '../../utils/bing_wallpaper_date_label.dart';
import '../../ui/hyperos/hyperos.dart';
import '../../utils/app_toast.dart';
import '../../utils/wallpaper_history.dart';

/// 图库里点中一张、已下好本地之后的收尾，由宿主实现。
///
/// 返回 `true` 表示用户**确认**了（宿主已落盘），`false` 表示他退出了。
typedef BingWallpaperImageHandler = Future<bool> Function(String imagePath);

/// 以全屏页方式打开 Bing 每日壁纸图库。
///
/// ## 为什么位置编辑页要压在**图库之上**（而不是先关图库再开它）
///
/// 用户 2026-10-06 口径：「点完大屏、点退出，应该回到壁纸列表，而不是最开始的地方」。
/// 早先的实现是「选图后先把图库页弹掉、再推位置页」，于是退出直接落回设置页 ——
/// 想再挑一张就得重新走一遍「设置 → Bing 每日壁纸」。所以这里让图库页**留在栈里**，
/// 由 [onImageDownloaded] 在它**之上**推位置编辑页：
/// * 位置页「退出」→ 回到图库，接着挑；
/// * 位置页「完成」→ 宿主落盘并返回 `true`，图库页这才自己退出。
///
/// 返回值恒为 null —— 交互结果一律通过 [onImageDownloaded] 回传，不用返回值。
Future<void> pushBingWallpaperGalleryPage(
  BuildContext context, {
  required BingWallpaperImageHandler onImageDownloaded,
  Iterable<String> protectedPaths = const <String>[],
}) => HyperosNavigation.push<void>(
  context,
  builder: (_) => BingWallpaperGalleryPage(
    onImageDownloaded: onImageDownloaded,
    protectedPaths: protectedPaths.toList(growable: false),
  ),
);

/// Bing 每日壁纸图库：浏览最近 8 天，点一张才下原图。
///
/// ## 为什么不把「落盘 + 应用」做完
///
/// 落盘之后还有一整套既有流程要走：位置编辑页（拖动取景 / 双指缩放）、补记「最近使用」、
/// 三处缓存失效。这些**全部**由 `_HomeBackdropFlow`（`settings_home_backdrop_flow.dart`）
/// 在 mixin 上实现着，两个宿主（课表页面设置 / 外观编辑的壁纸弹窗）共用。若本页自己写
/// 一遍，就会多出一条「能下载但没补记历史」的旁路 —— 那正是这套流程最忌讳的分叉。
/// 所以本页只负责「取到本地路径」，其余原样交回 [onApplied]。
///
/// ## 浏览不下载
///
/// 缩略图走 `BingWallpaperItem.thumbnailUrl()`（480×854，与最终取到的竖图同朝向，
/// 约 105 KB/张），8 张约 840 KB。只有点某一张才按当前档位下原图（`standard`
/// 322 KB / `tall` 492 KB / `high` 764 KB，都是竖屏）。
class BingWallpaperGalleryPage extends StatefulWidget {
  const BingWallpaperGalleryPage({
    required this.onImageDownloaded,
    this.protectedPaths = const <String>[],
    super.key,
  });

  /// 某张图已下好之后的收尾（宿主在**本页之上**推位置编辑页）。见
  /// [pushBingWallpaperGalleryPage]。
  final BingWallpaperImageHandler onImageDownloaded;

  /// 台账溢出要删文件时**绝不能删**的路径。
  ///
  /// 宿主必须把「所有课表正在用的壁纸 + 草稿那张」传进来（见
  /// `_HomeBackdropFlow._inUseWallpaperPaths`）：自动换写下的那张壁纸只在
  /// 台账（缓存）里、**不在「最近使用」里**（自动换不补记历史，见笔记），所以只按
  /// 历史当白名单会把它删掉 —— 首页当场裂图。「最近使用」那层白名单本页自己会读。
  final List<String> protectedPaths;

  @override
  State<BingWallpaperGalleryPage> createState() =>
      _BingWallpaperGalleryPageState();
}

class _BingWallpaperGalleryPageState
    extends State<BingWallpaperGalleryPage> {
  List<BingWallpaperItem> _items = const [];

  /// 首次加载 / 下拉刷新进行中。
  bool _loading = true;

  /// 正在下载的那张；null = 没在下载。
  ///
  /// 用条目而不是下标：清单可能被刷新重排，下标会指到别的图上。
  BingWallpaperItem? _downloadingItem;

  /// 下载中点击的那张（排队）：当前这张完成后自动接着下。
  String? _queuedItemId;

  /// 下载进度（已收 / 总字节；CDN 没给总长时 total 为 null → 只转圈不报百分比）。
  int? _downloadingBytes;
  int? _downloadingTotalBytes;

  /// 上次 setState 用掉的整数百分比（1% 粒度节流，见 `_downloadAndApply`）。
  int get _downloadingPercent {
    final total = _downloadingTotalBytes;
    if (total == null || total <= 0) {
      return -1;
    }
    return ((_downloadingBytes ?? 0) * 100) ~/ total;
  }

  /// 缩略图加载失败的 dateKey 集合：失败显示「重试」角标，点了再拉一次。
  ///
  /// Flutter 的 `Image.network` 失败后**不会自己重试**——弱网下超时那张就永远是
  /// 占位色块，看起来像「没加载出来」。给一个手动重试的口子（2026-10-14 用户
  /// 报「有一些加载不出来」）。
  final Set<String> _failedThumbs = <String>{};

  /// 缩略图重载的代数：retry 时递增，`KeyedSubtree` 用它换 key 强制重建 `Image`
  /// （`Image.network` 对失败 URL 的结果有缓存，不换 key 重试不发起请求）。
  int _thumbRetryEpoch = 0;

  /// 拉取失败。给一条可重试的提示而不是空白页 —— 断网时的空白页最像「功能坏了」。
  bool _failed = false;

  /// 当前显示的是**上次拉到的清单**（这次网络没给新数据）。
  ///
  /// 与 `_failed` 分开：「一次都没成功过」才是失败；「上次成功过、这次没拿到」该照常
  /// 显示旧的并说明来路 —— 否则网络一抖用户就得重新挑一遍。
  bool _showingCached = false;

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
    final items = await BingWallpaperService.loadItems(
      forceRefresh: forceRefresh,
      // 展示路径才允许回落到过期缓存；自动换那条路**不能**开（会把换源机会抢掉，
      // 见 `loadItems` 上面对 `allowStaleFallback` 的说明）。
      allowStaleFallback: true,
    );
    if (!mounted) {
      return;
    }
    final cachedAt = BingWallpaperStore.instance.cachedItemsFetchedAt;
    setState(() {
      _items = items;
      _showingCached =
          items.isNotEmpty && (cachedAt == null || cachedAt.isBefore(startedAt));
      _loading = false;
      // 空清单 = 一次都没成功过（断网 / Bing 改格式），这时才真的没东西可显示。
      // 「有过缓存但这次没拿到」走上面那条 `_showingCached` 提示条，不算失败。
      _failed = items.isEmpty;
    });
  }

  /// 点某一张：先看有没有已下过的同款，没有才下载。
  ///
  /// ## 「一次只下一张」改成了**排队**（2026-10-14）
  ///
  /// 早先下载中点其他图是**静默忽略**（这里 `return`，一个字不提示）——用户看到的就是
  /// 「点了没反应」，转而去连点好几下。现在下载中的点击把那张**排进队列**（[Widget] 层
  /// 只记 id），当前这张完成后自动接着下；排队时目标卡片立刻显示「排队中」的转圈，
  /// 用户看得见它已被接住。
  Future<void> _pick(BingWallpaperItem item) async {
    // 缩略图失败的那张：第一次点击**只重试缩略图**，不下大图（用户点的是「这块
    // 怎么空了」，不是「我要这张当壁纸」）。重试成功后角标消失，再点才是下载。
    if (_failedThumbs.contains(item.dateKey) && _downloadingItem == null) {
      setState(() {
        _failedThumbs.remove(item.dateKey);
        _thumbRetryEpoch++;
      });
      return;
    }
    if (_downloadingItem != null) {
      if (_queuedItemId != item.dateKey) {
        setState(() => _queuedItemId = item.dateKey);
        showAppToast(
          context,
          message: AppLocalizations.of(context)!.bingWallpaperDownloadQueued,
        );
      }
      return;
    }
    await _downloadAndApply(item);
  }

  /// 下载 [item] 并走宿主落盘回调；完成后自动开跑排队的下一张。
  Future<void> _downloadAndApply(BingWallpaperItem item) async {
    final resolution = BingWallpaperStore.instance.resolution;
    // 实际要下的像素（屏幕分辨率与档位下限取大者，见
    // [BingWallpaperResolution.downloadTargetSize]）。查询台账与下载都要用**这一组**，
    // 否则会拿旧尺寸那张糊的当命中、或下到与文件名不一致的尺寸。
    final targetSize = resolution.downloadTargetSize;
    setState(() {
      _downloadingItem = item;
      _downloadingBytes = null;
      _downloadingTotalBytes = null;
      _queuedItemId = null;
    });
    var path = await BingWallpaperStore.instance.findExisting(
      item.dateKey,
      resolution,
      targetSize: targetSize,
    );
    // 失败时带 HTTP 状态码给用户看：2026-10-06 用户报「点大图下载失败」，而所有
    // 分支都只弹同一句、没有日志也没有细节 —— 那次完全无从下手。
    // 只有拿得到响应才有状态码（断网就没有），那种情况退回通用文案。
    var failureStatusCode = -1;
    if (path == null) {
      // 刻意走 `createTransient()` 而不是 `BingWallpaperService()`：这样单测的
      // client 注入钩子对这一处同样生效（理由见该方法的注释）。
      final service = BingWallpaperService.createTransient();
      try {
        final result = await service.download(
          item,
          resolution,
          // ⭐ 真实字节进度：流式下载每收一块回调一次。 setState 节流到
          // 1% 粒度（整数百分比变化才重建），不然 2 MB 图在好网下每块都
          // 触发重建，网格白抖。
          onProgress: (received, total) {
            if (!mounted || total == null || total <= 0) {
              return;
            }
            final percent = (received * 100) ~/ total;
            if (percent != _downloadingPercent) {
              setState(() {
                _downloadingBytes = received;
                _downloadingTotalBytes = total;
              });
            }
          },
        );
        path = result.path;
        if (result.succeeded) {
          // 手动挑的也记账：目的是**封顶清理**（不记账的文件没人回收）与去重，
          // 但标记 `autoApplied: false`，免得顶掉自动换「今天已换过」的判据。
          // 记的是**实际**那档（缺档退档后就是 standard），与文件名一致；
          // 两个字段都必须取 `result.resolution`，写成外面那个 `resolution`
          // 会让台账记着一个不存在的文件尺寸。
          final evicted = await BingWallpaperStore.instance.recordApplied(
            dateKey: item.dateKey,
            resolution: result.resolution!,
            path: result.path!,
            autoApplied: false,
            targetSize: result.resolution!.downloadTargetSize,
          );
          unawaited(_deleteEvicted(evicted, keep: result.path));
        } else {
          failureStatusCode = result.statusCode ?? -1;
        }
      } finally {
        service.dispose();
      }
    }
    if (!mounted) {
      return;
    }
    setState(() => _downloadingItem = null);
    if (path == null) {
      showAppToast(
        context,
        message: failureStatusCode < 0
            ? l10n.bingWallpaperDownloadFailed
            : l10n.bingWallpaperDownloadStatus(failureStatusCode),
        kind: AppToastKind.warning,
        showKindIcon: true,
      );
    } else {
      // 带着路径退出，交给调用方在**本页之后**接位置编辑（见 pushBingWallpaperGalleryPage）。
      final applied = await widget.onImageDownloaded(path);
      if (!mounted) {
        return;
      }
      // 只有真落盘了才退出图库：用户从位置页「退出」回来时还要接着挑（2026-10-06）。
      if (applied) {
        Navigator.of(context).pop();
        return;
      }
      // 位置编辑页「退出」回来了：清掉排队标记 —— 那次交互已经结束，用户回到图库
      // 是要**重新挑**，自动开跑排队的下一张反而抢走控制权。
      if (_queuedItemId != null) {
        setState(() => _queuedItemId = null);
      }
      return;
    }
    // 只有「下载失败」这条路才自动开跑排队的下一张：用户没拿到图，替他把排队的
    // 那张补上。位置页退出不走这里（见上）。
    final queued = _queuedItemId == null
        ? null
        : _items.where((e) => e.dateKey == _queuedItemId).firstOrNull;
    if (queued != null) {
      await _downloadAndApply(queued);
    }
  }

  /// 台账溢出要删的文件。
  ///
  /// 白名单三路并集：[keep]（刚挑中的那张）、[BingWallpaperGalleryPage.protectedPaths]
  /// （宿主传进来的「当前壁纸」—— 自动换写下的那张**不在历史里**，只按历史当白名单会
  /// 把它删掉、首页当场裂图）、以及「最近使用」（别的课表可能正拿某张当壁纸）。
  /// 口径与 `settings_home_backdrop_flow.dart` 的 `_inUseWallpaperPaths` 一致。
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
      title: Text(l10n.bingWallpaperGalleryTitle),
      onBack: () => Navigator.of(context).maybePop(),
      child: _buildBody(context),
    );
  }

  /// 图库正文。
  ///
  /// ## 顶栏是**悬浮**的，正文必须自己让开它的高度
  ///
  /// `HyperosSubpage` 的顶栏浮在内容**之上**，内容不自带顶部留白。仓库里让位的两条
  /// 正路是 [HyperosListView]（读 [HyperosBlurredHeaderScope] 补顶部 padding，见
  /// `hyperos_page.dart:911`）与 [HyperosBlurredBodyInset]（同一份 inset 的纯 padding 版）。
  ///
  /// 这里用后者，理由有两条：
  /// * 本页要的是**两列惰性网格**（`SliverGrid`），`HyperosListView` 只有列表形态；
  /// * **必须在 `child` 里面**读 inset，不能在本页自己的 `build` 里读。
  ///   [HyperosSubpage] 是**往下**提供那份 scope 的，而本页的 context 在它**上面** ——
  ///   在那儿读 `insetOf` 恒为 0，于是让位的那份 padding 悄悄变成 0、顶部照样被顶栏
  ///   盖住，而**页面上看不出任何异常**（这个坑真踩过一次，回归钉在
  ///   `test/widgets/bing_wallpaper_gallery_header_inset_test.dart`）。
  ///   [HyperosBlurredBodyInset] 在自己的 `build` 里读，位置天然落在 scope 之内。
  Widget _buildBody(BuildContext context) {
    // 走 HyperOS 那份而不是 Material 原生 `RefreshIndicator`：后者用默认强调色 +
    // 默认 surface 底色，与页面其余部分的强调色/材质对不上（仓库统一口径见
    // `ui/hyperos/hyperos_pull_to_refresh.dart`）。
    return HyperosRefreshIndicator(
      onRefresh: () => _load(forceRefresh: true),
      child: CustomScrollView(
        // ⚠️ 必须显式给 `AlwaysScrollableScrollPhysics`：图库只有 8 张、两列网格在
        // 大屏 / 横屏下**填不满**一屏，而 `CustomScrollView` 默认「内容不足一屏时
        // 不可滚」—— 下拉手势于是根本不被识别，用户在没填满的网格上怎么拉都没反应。
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // ⚠️ 这里**不要再补顶部留白**。[HyperosBlurredBodyInset] 给的那份 inset 已经
          // 含了「标题 → 正文」的设计间距（[HyperosMiuixTopAppBar.largeTitleContentGap]，
          // 8，见 `hyperos_blurred_header.dart:159`）。再加一层（本页一度在外面套 12、
          // 里面又套 12）就叠成 32，看着像「标题被顶到天上去」，2026-10-06 用户报
          // 「标题和下面空一大截」。页面其余部分统一按 [HyperosMiuixSpec.listPadding]
          // 的 top=4 走，所以这一块只补那 4。
          //
          // 2026-10-14 起画质不再是用户选项（恒按 high），原来包在这儿的
          // `_buildResolutionSection`（档位胶囊 + 像素说明）整段删除，但
          // [HyperosBlurredBodyInset] 这层**必须留着** —— 网格的顶部让位靠它。
          const SliverToBoxAdapter(
            child: HyperosBlurredBodyInset(
              child: SizedBox(height: 4),
            ),
          ),
          if (_loading && _items.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _bodyArea(
                context,
                const Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
              ),
            )
          else if (_failed)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _bodyArea(context, _buildFailure(context)),
            )
          else ... <Widget>[
            // 「显示的是上次结果」提示条。与 Bing 图库页同一句文案、同一位置。
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
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 12,
                  // 卡片 = 竖屏缩略图 + 日期一行 + 版权说明两行。
                  // 刻意用**竖**卡片：横卡片里塞一张竖图会上下留白，而这一页的
                  // 卖点就是「竖图铺满竖屏」，预览必须先立住这个印象。
                  // 0.56 ≈ 图占七成、字占三成；图的真实高度由 Expanded 兜。
                  childAspectRatio: 0.56,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _buildTile(context, _items[index]),
                  childCount: _items.length,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 「加载中 / 拉失败」那种**居中一块**的状态需要再让开一次顶栏。
  ///
  /// `SliverFillRemaining` 从当前滚动位置起填满剩余空间，而顶栏是浮在它上面 ——
  /// 不补这份 inset，那个 `Center` 的视觉中心会偏到顶栏底下，看着像没居中。
  /// 网格那一支不需要：它从顶部按正常节奏排下来，越往下离顶栏越远。
  Widget _bodyArea(BuildContext context, Widget child) =>
      HyperosBlurredBodyInset(child: child);

  Widget _buildFailure(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
              l10n.bingWallpaperGalleryFailed,
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

  Widget _buildTile(BuildContext context, BingWallpaperItem item) {
    final l10n = AppLocalizations.of(context)!;
    final busy = _downloadingItem?.dateKey == item.dateKey;
    final queued = _queuedItemId == item.dateKey;
    final thumbFailed = _failedThumbs.contains(item.dateKey);
    return MiuixPressable(
      onPressed: () => _pick(item),
      borderRadius: BorderRadius.circular(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // ⚠️ 缩略图必须走 [Expanded] 而不是 `AspectRatio`：卡片高度由网格的
      // `childAspectRatio` 定死，而下面两行文字的高度随文案行数变（版权说明
      // 1~2 行、中日韩与拉丁文行数还不一样）。写成固定比例的图 + 固定文字，
      // 文案长一档就 `RenderFlex overflowed` —— 2026-10-06 换竖版卡片时真炸过
      // （22px）。让图去吃掉剩余高度，任何文案长度都不会溢出。
      Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  // 缩略图：105 KB 的小图，网络直出。加载中与失败都垫一层底色，
                  // 免得网格里闪出一块纯白。
                  //
                  // ⚠️ 加载中给一颗**小号** `HyperosInfiniteProgress`（外观编辑页
                  // 加载罩同款转圈）：8 张小图到达顺序天然不同（8 个独立请求并发
                  // 竞速），只有底色的卡片看起来像「坏了」——有转圈就是「还在来」。
                  // key 带上 `_thumbRetryEpoch`：重试时强制重建 `Image`，否则
                  // `Image.network` 对失败 URL 的结果有缓存、重试不发起请求。
                  KeyedSubtree(
                    key: ValueKey('thumb_${item.dateKey}_$_thumbRetryEpoch'),
                    child: Image.network(
                      item.thumbnailUrl(),
                      fit: BoxFit.cover,
                      // 网格里每张约 180dp 宽，2x 解码足够，不必拉原图。
                      cacheWidth: 360,
                      loadingBuilder: (context, child, progress) =>
                          progress == null
                          ? child
                          : ColoredBox(
                              color: HyperosColors.rowHighlight(context),
                              child: const Center(
                                child: HyperosInfiniteProgress(size: 18),
                              ),
                            ),
                      errorBuilder: (context, error, stackTrace) {
                        if (!_failedThumbs.contains(item.dateKey)) {
                          scheduleMicrotask(() {
                            if (mounted) {
                              setState(() => _failedThumbs.add(item.dateKey));
                            }
                          });
                        }
                        return ColoredBox(
                          color: HyperosColors.rowHighlight(context),
                          child: Center(
                            child: Icon(
                              Icons.image_not_supported_outlined,
                              size: 20,
                              color: HyperosColors.secondaryText(context),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  // 下载中：暗化 + 外观编辑页同款转圈 + 百分比。
                  if (busy)
                    ColoredBox(
                      color: Colors.black.withValues(alpha: 0.45),
                      child: Center(
                        child: _downloadProgressLabel(l10n),
                      ),
                    )
                  // 排队中：只给转圈，不暗化到看不清（排队时那张缩略图多半已加载完）。
                  else if (queued)
                    ColoredBox(
                      color: Colors.black.withValues(alpha: 0.45),
                      child: const Center(
                        child: HyperosInfiniteProgress(
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            bingWallpaperDateLabel(l10n, item.dateKey),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: HyperosTypography.listDetail(context),
          ),
          const SizedBox(height: 2),
          Text(
            thumbFailed
                ? '${item.copyright.isEmpty ? item.title : item.copyright}'
                    '（${l10n.wallpaperThumbRetryHint}）'
                : (item.copyright.isEmpty ? item.title : item.copyright),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: HyperosTypography.listDetail(
              context,
            ).copyWith(color: HyperosColors.secondaryText(context)),
          ),
        ],
      ),
    );
  }

  /// 下载中那块的中心内容：能算百分比时是「转圈 + 正在下载 N%」，算不出
  /// （CDN 没给总长）就是转圈 + 不带数字的「正在下载」。
  ///
  /// ⚠️ 转圈必须是 `HyperosInfiniteProgress`（外观编辑页加载罩同款：细环 + 绕行
  /// 小圆点），不是 Material 的 `CircularProgressIndicator` —— 用户点名要那个效果。
  Widget _downloadProgressLabel(AppLocalizations l10n) {
    final percent = _downloadingPercent;
    final text = percent >= 0
        ? l10n.bingWallpaperDownloadProgress('$percent%')
        : l10n.bingWallpaperDownloadProgress('…');
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const HyperosInfiniteProgress(color: Colors.white, size: 28),
        const SizedBox(height: 8),
        Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}