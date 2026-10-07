import 'package:flutter/foundation.dart';

import '../utils/home_page_background.dart';

/// resize 接口的**取图源**后缀：`_UHD.jpg`。
///
/// 竖屏三档里有两档 Bing 没预生成（`_1080x2400` / `_1440x2560` 都是 404），只能让它
/// 从**原图**现裁，而原图只有 `_UHD.jpg` 这一档（3840×2160，3.5 MB）。
///
/// ⚠️ 塞进 `id=` 的必须是**纯图片 id + 这个后缀**：拿裸 `urlbase` 当 `id` 实测 404，
/// 连 `/th?id=` 一起塞进去更会 404（那样整屏预览都是叉，2026-10-06 实报）。
const String _resizeSourceSuffix = '_UHD.jpg';

/// Bing 每日壁纸的下载档位（三档，**全是竖屏**）。
///
/// ## 为什么**只有**竖屏（2026-10-06 用户口径「不需要横屏的显示」）
///
/// 壁纸是 `BoxFit.cover` 铺满整屏的，而本 App 的首页是竖屏。一张 16:9 横图铺到 9:20
/// 的竖屏上，**横向会被裁掉七成以上** —— 用户看到的是原图中间一条窄带，构图基本被毁。
/// 所以横屏档位在这个 App 里不是「备选项」而是**没用**：留着白占一排胶囊的位置，
/// 还因为两档共用「高清」这个名字被用户指出「有两个高清档位」（2026-10-06）。
///
/// ## 两种取图方式并存
///
/// * [sizeSuffix] 非空 → 用 Bing **预生成**的那一张（同尺寸下体积最小：实测
///   `_1080x1920.jpg` 322 KB，而走 resize 同一尺寸要 481 KB，白多五成）；
/// * [sizeSuffix] 为空 → 走 **resize 接口**（见 `BingWallpaperItem.resizeUrl`），
///   要 Bing 现裁。Bing 并不预生成这些尺寸（实测 `_1440x2560`、`_1080x2400`
///   都是 404），但 resize 接口 8 天 × 3 档共 24 次全部返回精确尺寸。
enum BingWallpaperResolution {
  /// 1080×1920（9:16，约 322 KB）。Bing 预生成，可见 8 天全中。默认档。
  standard(
    width: 1080,
    height: 1920,
    kilobytes: 322,
    sizeSuffix: '_1080x1920.jpg',
  ),

  /// 1080×2400（9:20，约 492 KB）。**正好是现代手机的比例**：cover 之后既不裁也不
  /// 拉伸，是「铺满全屏」这件事最干净的一档。走 resize。
  tall(width: 1080, height: 2400, kilobytes: 492),

  /// 1440×3200（约 764 KB）。给高分屏看细节。走 resize。
  ///
  /// ⚠️ 为什么顶档是 **3200** 而不是 2560（2026-10-06 用户报「最高清还是有点糊」）：
  /// Bing 的原图 `_UHD.jpg` 是**横屏 3840×2160**（实测）。任何竖屏壁纸都是从它中间裁
  /// 一条竖出来、再放大得到的，所以「屏幕有多高」决定了必须放大多少倍：
  ///
  /// * 1080×2400 屏：`tall` 正好合身 → Bing 放大 2400/2160 = 1.11×，**App 不再放大**；
  /// * 1440×3200 屏：早先的 1440×2560 只到 2560，App 为了铺满 3200 **还要再放大 1.25×**
  ///   —— 于是 Bing 先放大 1.19×、App 再放大 1.25×，**两次放大叠在一起**，糊上加糊。
  ///
  /// 改成 3200 之后，App 不再参与放大，总放大次数从两段变一段（1.48×，一次做完）。
  /// 数学上「总放大倍数 = 屏幕高 / 原图高 = 3200/2160」省不掉（见
  /// `bingWallpaperResolutionSourceNote` 那句提示），但**两段放大比一段更糊**。
  ///
  /// ⚠️ 别把这一档说成「细节更多」：它与 2560 是同一批像素（源图就那么多），多出来的
  /// 高度是 Bing 补出来的。文案因此不写「极清/超清」，仍叫「高清」。
  high(width: 1440, height: 3200, kilobytes: 764);

  const BingWallpaperResolution({
    required this.width,
    required this.height,
    required this.kilobytes,
    this.sizeSuffix,
  });

  final int width;
  final int height;

  /// 单张约多大（实测，见枚举注释）。
  final int kilobytes;

  /// Bing 预生成尺寸的后缀；null = 要走 resize 接口现裁。
  final String? sizeSuffix;

  int get pixelWidth => width;
  int get pixelHeight => height;
  int get approximateKilobytes => kilobytes;

  /// 该档缺失时能退到哪一档（`null` = 无处可退，只能报错）。
  ///
  /// ## 为什么需要退路
  ///
  /// Bing 是按**当天那张源图**预生成尺寸的，可用的尺寸集合随源图比例变化。缺档时只报
  /// 「下载失败」等于让功能看起来坏了，所以按枚举顺序退到**紧邻的下一档** —— 退一档是
  /// 「从清晰变略糊」，可以接受。
  BingWallpaperResolution? get fallbackResolution =>
      index == 0 ? null : BingWallpaperResolution.values[index - 1];

  /// 实际该向 Bing 要的像素尺寸（2026-10-07 起）。
  ///
  /// ## 口径：档位是**下限**，屏幕是**下限之上**
  ///
  /// 早先直接用 `width`/`height`（1080×1920 这类写死值），于是只要屏幕比它大，
  /// App 就得为铺满**再放大一次** —— 图源那次放大之外又叠一段，两段放大比一段更糊
  /// （用户 2026-10-07：「也太糊了」）。更要命的是比例对不上会留出多余的竖向余量：
  /// 9:20 的图铺到 9:19.5 的屏上会**上下能拖**，而拖到的每段都是被放大过的最糊处。
  ///
  /// 所以：**先按屏幕真实分辨率取尺寸，再按当前档位抬到不低于档位**。用户选低档位
  /// 省流量 / 省空间的意图仍然成立（档位下限在），但不会换来「让 App 二次放大」——
  /// 那从来不是「清晰度低」，只是**多糊一段**。
  ///
  /// 仍要保留 [width] / [pixelHeight] 作为**档位下限**与界面文案里的实测值，
  /// 不要因为「实际请求尺寸不再等于它」就把这两个字段改掉。
  WallpaperTargetSize get downloadTargetSize => wallpaperTargetSize().atLeast(
    width,
    height,
  );

  /// [kilobytes] 的人类可读写法（l10n 的 `size` 占位符要 String）。
  ///
  /// 「0.3 MB」这种数在选画质时反而不如「322 KB」有概念，所以不到 1 MB 保留 KB。
  String get approximateSizeLabel =>
      kilobytes < 1024 ? '$kilobytes KB' : '${(kilobytes / 1024).toStringAsFixed(1)} MB';

  /// 持久化用的键（`name` 即 enum 名，枚举顺序变了也不会读错旧值）。
  String get storageKey => name;

  /// 反解 [storageKey]；未知键回退 [BingWallpaperResolution.standard]。
  ///
  /// 存档可能被手改、被旧版本写过（更早的 `native` / `uhd` / `portraitStandard` 之类
  /// 都落不到新枚举上），统一回退到默认档 —— 别让一个坏值把设置页整个炸掉，与
  /// `WallpaperHistoryEntry._numOrNull` 同一口径。
  static BingWallpaperResolution fromStorageKey(String? raw) {
    for (final value in BingWallpaperResolution.values) {
      if (value.storageKey == raw) {
        return value;
      }
    }
    return BingWallpaperResolution.standard;
  }
}

/// Bing 每日壁纸库里的一天。
///
/// 对应 `HPImageArchive.aspx?format=js` 返回的 `images[]` 某一项。
/// [urlBase] 是关键：它不带尺寸后缀，拼档位与拼缩略图都从它出发
/// （见 [fullUrl] 与 [thumbnailUrl]）。
@immutable
class BingWallpaperItem {
  const BingWallpaperItem({
    required this.dateKey,
    required this.urlBase,
    required this.title,
    required this.copyright,
  });

  /// 当天的 `startdate`，形如 `20261005`。
  ///
  /// 它同时是**身份**：同一天永远是同一张图，重复下载靠它去重
  /// （见 `BingWallpaperStore`）。
  final String dateKey;

  /// Bing 的图片基址，形如 `/th?id=OHR.AdelieTeacher_EN-US5343194378`。
  final String urlBase;

  /// 当天的标题（英文，Bing 不提供本地化标题）。
  final String title;

  /// 版权说明；`mkt=zh-CN` 时是中文，形如「阿德利企鹅，南极洲 (? 摄影师/图库)」。
  final String copyright;

  /// Bing 的**图片 id**（形如 `OHR.AdelieTeacher_ZH-CN2201820679`），去掉 `/th?id=` 前缀。
  ///
  /// ⚠️ 这一层不能省。接口给的 [urlBase] 是 `/th?id=OHR.…` 这种**相对地址**，
  /// 拿它去拼**另一个**查询串（缩略图的 `id=` 参数）就会得到
  /// `…&id=/th?id=OHR.…` —— 第二个 `?id=` 之后全是多余的，参数值被截成 `/th?id`
  /// 实测 404，于是图库**整屏都是叉**（2026-10-06 用户报「预览图全部都显示叉叉」）。
  /// 所以凡是要把 id 填进查询串的地方，一律用这个已经剥好前缀的纯 id。
  String get imageId {
    final marker = urlBase.indexOf('?id=');
    return marker >= 0 ? urlBase.substring(marker + '?id='.length) : urlBase;
  }

  /// 绝对化的基址（`urlBase` 可能是相对地址）。
  ///
  /// 从 [imageId] 重新拼而不是拼 [urlBase]：后者会把 `/th?id=` 带进来，
  /// 后面再追加尺寸后缀就成了 `/th?id=OHR.X` + `_UHD.jpg`，看着对、实际靠运气。
  String get absoluteUrlBase => 'https://www.bing.com/th?id=$imageId';

  /// 指定档位的原图绝对地址。
  ///
  /// 两条路（见 [BingWallpaperResolution] 的说明）：预生成尺寸走后缀，Bing 没预生成
  /// 的尺寸走 resize 接口**并且必须带 `c=4`**，否则 Bing 会补白边而不是裁切。
  ///
  /// [target] 给定时按它要尺寸（见 [bingWallpaperDownloadTargetSize]）：档位只当**保底**，
  /// 实际请求不小于屏幕，于是 App 侧不再二次放大。
  String fullUrl(
    BingWallpaperResolution resolution, {
    WallpaperTargetSize? target,
  }) {
    final suffix = resolution.sizeSuffix;
    // 预生成档只在「尺寸刚好够」时走后缀：档位尺寸小于屏幕时走后缀等于**主动**要一张
    // 更小的图，App 还得再放大一次 —— 正是要消除的那一层。
    if (suffix != null &&
        (target == null || target.height <= resolution.height)) {
      return '$absoluteUrlBase$suffix';
    }
    final size =
        target ?? WallpaperTargetSize(resolution.width, resolution.height);
    return resizeUrl(width: size.width, height: size.height);
  }

  /// 让 Bing 按 [width]×[height] **填满裁切**出一张。
  ///
  /// `c=4` 是「填满」的开关：实测不带它时 Bing 会把整张图缩进去、上下留白边
  /// （竖图会变成一张窄条浮在白底里），当壁纸极其难看。带上之后它会保留画面有内容的
  /// 部分去裁，不是盲切正中间一条。
  String resizeUrl({required int width, required int height}) {
    final id = '$imageId$_resizeSourceSuffix';
    return 'https://www.bing.com/th?w=$width&h=$height&rs=1&c=4&id=$id';
  }

  /// 浏览图库用的小图地址。
  ///
  /// ⚠️ `id` 必须是**纯图片 id**（[imageId]）+ `_UHD.jpg`：直接拿裸 [urlBase] 当
  /// `id` 实测 404，把它连 `/th?id=` 一起塞进去更会 404（见 [imageId] 的坑）。
  ///
  /// 默认取**竖屏**比例（480×854，约 105 KB）：图库卡片也是竖的，缩略图必须与
  /// 最终拿到的那张同朝向，否则用户点进去才发现「预览是横的、成品是竖的」。
  String thumbnailUrl({int width = 480, int height = 854}) => resizeUrl(
    width: width,
    height: height,
  );

  /// 落盘文件名（不含目录）：`wallpaper_bing_20261005_standard.jpg`。
  ///
  /// ## 为什么带 `wallpaper_` 前缀
  ///
  /// 不是为了好看：`deleteManagedImage` 只删「本目录内 + 文件名以 `filePrefix` 开头」
  /// 的文件（`managed_image_storage.dart:62` 的双保险），而 `deleteEvictedWallpaperFiles`
  /// 传进来的 `filePrefix` 是 `kHomePageWallpaperFilePrefix`（值 `wallpaper`）。
  /// 若这里叫 `bing_…`，Bing 壁纸一旦被「最近使用」挤出去就会**删不掉**（静默跳过），
  /// 变成永不被回收的孤儿文件。共用前缀才能让既有清理逻辑原样生效。
  ///
  /// 用 [dateKey] 与档位而不是时间戳，于是「同一天同一档位」天然落在同一个文件名上，
  /// 重复下载会直接覆盖而不是攒出一串重复图 —— 这是台账之外的一道保险。
  ///
  /// [target] 非空时把**实际像素**也写进文件名（2026-10-07）。原因见
  /// [BingWallpaperResolution.downloadTargetSize]：实际请求尺寸已经跟着设备变了，
  /// 文件名再只按档位区分，就会让「1080 宽那张」和「1206 宽那张」共用一个名字 ——
  /// 台账（键含尺寸）认为是两张，磁盘上却是同一个文件，后者覆盖前者，
  /// 而**正在显示的**首页壁纸可能正是被覆盖掉的那张尺寸。
  ///
  /// 尺寸只在与该档**默认**尺寸不同时才写进名字：绝大多数设备用默认尺寸，
  /// 保持旧名字不变，存量文件与台账不受影响。
  String fileName(
    BingWallpaperResolution resolution, {
    WallpaperTargetSize? target,
  }) {
    final size = target ?? resolution.downloadTargetSize;
    final base = WallpaperTargetSize(resolution.width, resolution.height);
    final suffix = size == base ? '' : '_${size.width}x${size.height}';
    return 'wallpaper_bing_${dateKey}_${resolution.storageKey}$suffix.jpg';
  }

  /// 非法输入返回 null 而不是抛错：接口 JSON 可能被 Bing 改字段或手改存档。
  static BingWallpaperItem? fromJson(Object? raw) {
    if (raw is! Map) {
      return null;
    }
    // ⚠️ 两个键都要读：接口（`format=js`）里叫 `urlbase` / `startdate`，而本模型的
    // [toJson] 写的是 `urlBase` / `dateKey`。两套命名都要认，否则 **prefs 里自己写的
    // 缓存读不回来**（读出来全是坏条目 → 图库永远空 → 每次都走网络）。
    final urlBase = raw['urlBase'] ?? raw['urlbase'];
    final dateKey = raw['dateKey'] ?? raw['startdate'];
    if (urlBase is! String || dateKey is! String) {
      return null;
    }
    final trimmedBase = urlBase.trim();
    final trimmedDate = dateKey.trim();
    if (trimmedBase.isEmpty || trimmedDate.isEmpty) {
      return null;
    }
    return BingWallpaperItem(
      dateKey: trimmedDate,
      urlBase: trimmedBase,
      title: _stringOrEmpty(raw['title']),
      copyright: _stringOrEmpty(raw['copyright']),
    );
  }

  /// 只放行 [String]；其余类型一律当空串（副标题可以不显示，但条目本身有效）。
  static String _stringOrEmpty(Object? value) => value is String ? value : '';

  static List<BingWallpaperItem> listFromJson(Object? raw) {
    if (raw is! List) {
      return const [];
    }
    return <BingWallpaperItem>[
      for (final item in raw)
        if (fromJson(item) case final BingWallpaperItem parsed) parsed,
    ];
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'dateKey': dateKey,
    'urlBase': urlBase,
    'title': title,
    'copyright': copyright,
  };

  @override
  bool operator ==(Object other) =>
      other is BingWallpaperItem &&
      other.dateKey == dateKey &&
      other.urlBase == urlBase &&
      other.title == title &&
      other.copyright == copyright;

  @override
  int get hashCode => Object.hash(dateKey, urlBase, title, copyright);

  @override
  String toString() => 'BingWallpaperItem($dateKey, $urlBase)';
}