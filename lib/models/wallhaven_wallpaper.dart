import 'package:flutter/foundation.dart';

import '../utils/home_page_background.dart';

/// Wallhaven 免费图源的一条竖版壁纸。
///
/// ## 与 Bing 那条链路的关键差别：原生竖图
///
/// Bing 每日壁纸的原图**永远只有 2160 高**（实测 `_UHD.jpg` 是横屏 3840×2160，且接口
/// 不提供更高的），于是任何竖屏壁纸都得从中间裁一条竖出来再放大 —— 屏幕上 2622 高就
/// 要放大 1.21 倍，这是**去不掉的算术上限**（用户 2026-10-07：「明显就是……留下了最糊
/// 的画面」）。
///
/// Wallhaven 是**摄影社区**，「手机壁纸」本来就是它的主要用途之一，竖图是原生供给：
/// 实测竖图常见 2250×4000、2944×5232、4320×7680。**所以在这条链路上放大倍数是 1.0。**
/// 这是它相对 Bing 唯一但也决定性的优势，其余（每天一张、无鉴权、免费）Bing 都有。
///
/// ## 免费与无版权的口径
///
/// 接口免密钥、免鉴权、免 Cookie（实测），`purity=100` 可只要 SFW 内容。内容由社区
/// 投稿，按 wallhaven.cc 的条款「用户保证自己有权投稿」。我们**不**在界面上承诺
/// 「无版权」——那不是能由本 App 担保的事实，只承诺「免费、无需注册」。
@immutable
class WallhavenWallpaperItem {
  const WallhavenWallpaperItem({
    required this.id,
    required this.width,
    required this.height,
    required this.fileUrl,
    this.thumbnailUrl,
    this.fileSizeBytes = 0,
    this.category,
  });

  /// Wallhaven 的短 id（如 `w53vkq`）。**同时是身份**：同一天同一 id 只会下一次。
  final String id;

  /// 原图宽（实测 2250 / 2944 / 4320 …）。
  final int width;

  /// 原图高。竖图常见 4000 以上 —— 这正是「原生竖图」的量化体现。
  final int height;

  /// 原图绝对地址（`w.wallhaven.cc/full/...`）。
  final String fileUrl;

  /// 缩略图地址（`th.wallhaven.cc/lg/...`）；没有时回落到 [fileUrl]。
  final String? thumbnailUrl;

  /// 原图体积（字节）；0 = 接口没给。
  final int fileSizeBytes;

  /// `general` / `anime` / `people`。`anime` 一律丢弃，见 [fromJson]。
  final String? category;

  /// 是不是竖图（高 > 宽）。
  bool get isPortrait => height > width;

  /// 体积的人类可读写法（界面那行「每张约 …」用）。
  String get sizeLabel {
    if (fileSizeBytes <= 0) {
      return '';
    }
    final mb = fileSizeBytes / (1024 * 1024);
    return mb >= 1 ? '${mb.toStringAsFixed(1)} MB' : '${(mb * 1024).round()} KB';
  }

  /// 浏览图库用的小图（竖屏比例，约 180dp 宽的卡片够用）。
  String get galleryThumbnailUrl => thumbnailUrl ?? fileUrl;

  /// 原图 URL。
  ///
  /// **不向 Wallhaven 要 resize**：它的 `th?w=&h=` 只会重新编码同一张源图，而竖图
  /// 本来就大于屏幕，缩下来只会平白丢细节、并让「原生竖图」这个优势作废。
  String get downloadUrl => fileUrl;

  /// 落盘文件名（不含目录）：`wallpaper_wh_<id>.jpg`。
  ///
  /// ## 为什么带 `wallpaper_` 前缀
  ///
  /// 与 Bing 那条同一原因（见 `BingWallpaperItem.fileName`）：`deleteManagedImage` 与
  /// `deleteEvictedWallpaperFiles` 按 `kHomePageWallpaperFilePrefix`（`wallpaper`）
  /// 判定「这张图归我管」，换个开头就会变成永不回收的孤儿文件。
  ///
  /// 用 [id] 而不是时间戳，于是同一天重复下载直接覆盖，不攒重复图。
  String get fileName => 'wallpaper_wh_$id.jpg';

  /// 非法输入返回 null 而不是抛错：接口 JSON 可能被改字段或存档被手改。
  static WallhavenWallpaperItem? fromJson(Object? raw) {
    if (raw is! Map) {
      return null;
    }
    final id = raw['id'];
    final path = raw['path'];
    final width = raw['dimension_x'];
    final height = raw['dimension_y'];
    if (id is! String || path is! String) {
      return null;
    }
    if (id.trim().isEmpty || !path.startsWith('http')) {
      return null;
    }
    if (width is! int || height is! int || width <= 0 || height <= 0) {
      // 尺寸是这条链路的**全部意义**（拿不到就判断不了是不是够大的竖图），所以
      // 缺尺寸的条目直接丢，而不是当 0 宽高放行。
      return null;
    }
    final category = raw['category'];
    // ⚠️ `anime` 一律丢：二次元插画当课程表背景，文字压在人物脸上很难读，而它在这
    // 个库里占比不低。用户要的是能衬底的图，不是图。
    if (category is String && category.toLowerCase() == 'anime') {
      return null;
    }
    if (category is! String) {
      return null;
    }
    final thumbs = raw['thumbs'];
    String? large;
    if (thumbs is Map && thumbs['large'] is String) {
      large = thumbs['large'] as String;
    }
    final fileSize = raw['file_size'];
    return WallhavenWallpaperItem(
      id: id.trim(),
      width: width,
      height: height,
      fileUrl: path,
      thumbnailUrl: large,
      fileSizeBytes: fileSize is int ? fileSize : 0,
      category: category,
    );
  }

  static List<WallhavenWallpaperItem> listFromJson(Object? raw) {
    if (raw is! List) {
      return const [];
    }
    return <WallhavenWallpaperItem>[
      for (final item in raw)
        if (fromJson(item) case final WallhavenWallpaperItem parsed) parsed,
    ];
  }

  /// 存档用（只存得下真正会被按天判据用到的字段）。
  /// 存档字段名**必须与接口一致**（`dimension_x` / `path` / `category` / `thumbs`），
  /// 与 [fromJson] 走同一个解析器。
  ///
  /// 早先写成 `width`/`height`/`fileUrl` 那套「自己的名字」，于是 `toJson()` 的产物
  /// **喂不进 `fromJson`**（尺寸取不到 → 整条被丢），往返测试立刻变红。
  /// 教训与 `BingWallpaperItem` 那条一致：两套命名都要认，就**别自己造第二套**。
  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'dimension_x': width,
    'dimension_y': height,
    'path': fileUrl,
    'file_size': fileSizeBytes,
    'category': category,
    'thumbs': <String, Object?>{'large': thumbnailUrl},
  };

  /// 按今天的日期 + 档位算出文件名。
  ///
  /// ## 为什么**不含**尺寸
  ///
  /// 与 Bing 那条相反：这里的图是**原生竖图**，尺寸由图源决定、与设备无关，所以把
  /// 尺寸写进名字没有意义（同一天换设备也该复用同一张）。而 [fileName] 里的 [id]
  /// 已经保证唯一。
  static String fileNameFor(String id) => 'wallpaper_wh_$id.jpg';

  @override
  bool operator ==(Object other) =>
      other is WallhavenWallpaperItem && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'WallhavenWallpaperItem($id, ${width}x$height)';
}

/// Wallhaven 清单请求的筛选条件。
///
/// ## ⚠️ `ratios` 的值必须是 `<宽>x<高>` 这种**像素尺寸**，不能写 `9:16` 或 `0.5`
///
/// 实测（2026-10-07）：`ratios=0.5` 与 `ratios=9:16` **都不报错，但静默返回横图**
/// （实测第一条 6666×6666、第二条 6666×3750）。只有 `ratios=1080x1920` 这种「写成
/// 竖向像素尺寸」的写法才真的只给竖图（实测全列表 `ratio=0.56`）。
///
/// 这类「参数写错不报错、只是给错结果」的接口最容易让人以为筛生效了 —— 所以这里
/// 把可用值**写死在枚举里**，不给界面拼字符串的机会。
@immutable
class WallhavenQuery {
  const WallhavenQuery({
    required this.ratios,
    required this.minimumSize,
    this.sort = WallhavenSort.toplist,
    this.page = 1,
  });

  /// 比例筛选（像素尺寸写法，见类注释）。
  final List<String> ratios;

  /// 尺寸下限（`atleast=`）。低于它的一律不要。
  final WallpaperTargetSize minimumSize;

  final WallhavenSort sort;
  final int page;

  /// 每次取多少条（`page_size` 上限 24，实测按 24 返回）。
  static const int pageSize = 24;

  Map<String, String> toQueryParameters() => <String, String>{
    'categories': '100',
    // 只要 SFW：壁纸是每天自动换上的，用户不该被一张 NSFW 图刷屏。
    'purity': '100',
    'ratios': ratios.join(','),
    'atleast': '${minimumSize.width}x${minimumSize.height}',
    'sort': sort.wire,
    'page': '$page',
    'page_size': '$pageSize',
  };
}

/// Wallhaven 支持的排序。
///
/// ⚠️ **没有 `random` / `featured` 这类端点**（实测 `/api/v1/random` 与
/// `/api/v1/featured` 都是 404）。`sort=random` 在 search 里**有效**（实测可用），
/// 但它每次调用都给出不同结果，于是同一天内两次拉取会拿到**不同**清单 ——
/// 这对「图库要能上下翻」是坏事（列表会在用户眼前重排），所以这里只列两个稳定排序。
enum WallhavenSort {
  toplist('toplist'),
  toplevel('toplevel');

  const WallhavenSort(this.wire);

  final String wire;
}