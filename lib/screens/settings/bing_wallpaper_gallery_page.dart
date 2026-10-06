import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';

import '../../l10n/app_localizations.dart';
import '../../l10n/enum_localizations.dart';
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
  /// 宿主必须把「当前正在显示的那张壁纸」传进来：自动换写下的那张壁纸只在
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

  /// 正在下载的那张，键为 `dateKey@档位`；null = 没在下载。
  ///
  /// 用键而不是下标：清单可能被刷新重排，下标会指到别的图上。
  String? _downloadingKey;

  /// 拉取失败。给一条可重试的提示而不是空白页 —— 断网时的空白页最像「功能坏了」。
  bool _failed = false;

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
    final items = await BingWallpaperService.loadItems(
      forceRefresh: forceRefresh,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _items = items;
      _loading = false;
      // 空清单 = 拉不到（断网 / Bing 改格式）。「缓存过期」与「拉失败」在这一层
      // 分不开，也不必分：给同一条重试入口即可。
      _failed = items.isEmpty;
    });
  }

  /// 点某一张：先看有没有已下过的同款，没有才下载。
  Future<void> _pick(BingWallpaperItem item) async {
    if (_downloadingKey != null) {
      // 一次只下一张：并行下 3.5 MB 的图既费流量，也让进度提示乱成一团。
      return;
    }
    final resolution = BingWallpaperStore.instance.resolution;
    setState(() => _downloadingKey = _entryKey(item, resolution));
    var path = await BingWallpaperStore.instance.findExisting(
      item.dateKey,
      resolution,
    );
    // 命中已下过的复用路径时，「实际那一档」就是当初记账的那一档；只有真去下载
    // 才可能退档，所以初值取所选档。
    var downloadedResolution = resolution;
    var downgraded = false;
    // 失败时带 HTTP 状态码给用户看：2026-10-06 用户报「点大图下载失败」，而所有
    // 分支都只弹同一句、没有日志也没有细节 —— 那次完全无从下手。
    // 只有拿得到响应才有状态码（断网就没有），那种情况退回通用文案。
    var failureStatusCode = -1;
    if (path == null) {
      // 刻意走 `createTransient()` 而不是 `BingWallpaperService()`：这样单测的
      // client 注入钩子对这一处同样生效（理由见该方法的注释）。
      final service = BingWallpaperService.createTransient();
      try {
        final result = await service.download(item, resolution);
        path = result.path;
        if (result.succeeded) {
          downloadedResolution = result.resolution!;
          downgraded = result.downgraded;
          // 手动挑的也记账：目的是**封顶清理**（不记账的文件没人回收）与去重，
          // 但标记 `autoApplied: false`，免得顶掉自动换「今天已换过」的判据。
          // 记的是**实际**那档（退档后就是 standard），与文件名一致。
          final evicted = await BingWallpaperStore.instance.recordApplied(
            dateKey: item.dateKey,
            resolution: result.resolution!,
            path: result.path!,
            autoApplied: false,
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
    setState(() => _downloadingKey = null);
    if (path == null) {
      showAppToast(
        context,
        message: failureStatusCode < 0
            ? l10n.bingWallpaperDownloadFailed
            : l10n.bingWallpaperDownloadStatus(failureStatusCode),
        kind: AppToastKind.warning,
        showKindIcon: true,
      );
      return;
    }
    if (downgraded) {
      // 选的那一档 Bing 当天没生成，已退到默认档。如实说一句，别让用户以为
      // 自己选的画质生效了（也不必解释 Bing 为什么缺 —— 他只关心拿到什么）。
      showAppToast(
        context,
        message: l10n.bingWallpaperResolutionFallback(
          bingWallpaperResolutionLabel(l10n, downloadedResolution),
        ),
      );
    }
    // 带着路径退出，交给调用方在**本页之后**接位置编辑（见 pushBingWallpaperGalleryPage）。
    final applied = await widget.onImageDownloaded(path);
    if (!mounted) {
      return;
    }
    // 只有真落盘了才退出图库：用户从位置页「退出」回来时还要接着挑（2026-10-06）。
    if (applied) {
      Navigator.of(context).pop();
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

  static String _entryKey(
    BingWallpaperItem item,
    BingWallpaperResolution resolution,
  ) => '${item.dateKey}@${resolution.storageKey}';

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
          SliverToBoxAdapter(
            child: HyperosBlurredBodyInset(
              child: _buildResolutionSection(
                context,
                BingWallpaperStore.instance,
              ),
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
          else
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

  /// 画质档位一排胶囊。
  ///
  /// 只排**画质**、不排朝向：横屏档已删（横图铺竖屏会被裁掉七成），三档全是竖屏，
  /// 一排胶囊刚好放得下且互不重名。
  ///
  /// 放在图库页顶部而不是设置页：档位只在**下载那一刻**才起作用，而下载就发生在这个
  /// 页面（点某一张）。让用户在动作发生前就地改档，比先去设置页改一趟顺手。
  Widget _buildResolutionSection(
    BuildContext context,
    BingWallpaperStore store,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final current = store.resolution;
    return Padding(
      // top=4 与网格那一支、以及仓库里所有列表的顶距同源
      // （`HyperosMiuixSpec.listPadding`）；顶部那段设计间距由
      // [HyperosBlurredBodyInset] 的 inset 负责，见 `_buildBody` 里的说明。
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.bingWallpaperResolutionTitle,
            style: HyperosTypography.listDetail(context),
          ),
          const SizedBox(height: 8),
          HyperosChipRow(
            labels: <String>[
              for (final value in BingWallpaperResolution.values)
                bingWallpaperResolutionLabel(l10n, value),
            ],
            selectedIndex: current.index,
            onChanged: (index) =>
                unawaited(store.setResolution(BingWallpaperResolution.values[index])),
          ),
          const SizedBox(height: 6),
          // 一行实测像素 + 体积，就这么多。
          //
          // ⚠️ **不要再往这儿加解释性灰字**（2026-10-06 用户口径「不要在页面中加入
          // 过多的灰字，不符合软件规范」）。这里曾经挂过一整段解释「为什么竖屏壁纸必然
          // 被放大、换档位也去不掉」，结果就是一进图库先读一段小字、图都还没看到。
          //
          // 那条知识不是丢了，它在两处更该在的地方：`BingWallpaperResolution.high`
          // 的注释（讲清 2560→3200 是为了不让 App 二次放大），以及实现笔记
          // `.agents/notes/implemented/feature/2026-10-05-bing-daily-wallpaper-library.md`
          // （讲清「总放大倍数 = 屏幕高 / 原图高」这个上限）。**需要解释的，放注释和笔记，
          // 不放页面。**
          Text(
            l10n.bingWallpaperResolutionHint(
              current.pixelWidth,
              current.pixelHeight,
              current.approximateSizeLabel,
            ),
            style: HyperosTypography.listDetail(context).copyWith(
              color: HyperosColors.secondaryText(context),
            ),
          ),
        ],
      ),
    );
  }

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
    final resolution = BingWallpaperStore.instance.resolution;
    final busy = _downloadingKey == _entryKey(item, resolution);
    return MiuixPressable(
      onPressed: busy ? null : () => _pick(item),
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
                  // 缩略图：17 KB 的小图，网络直出。加载中与失败都垫一层底色，
                  // 免得网格里闪出一块纯白。
                  Image.network(
                    item.thumbnailUrl(),
                    fit: BoxFit.cover,
                    // 网格里每张约 180dp 宽，2x 解码足够，不必拉原图。
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
          Text(
            bingWallpaperDateLabel(l10n, item.dateKey),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: HyperosTypography.listDetail(context),
          ),
          const SizedBox(height: 2),
          Text(
            item.copyright.isEmpty ? item.title : item.copyright,
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
}