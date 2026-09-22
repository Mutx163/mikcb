import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui'
    as ui
    show
        Image,
        ImmutableBuffer,
        PlatformDispatcher,
        instantiateImageCodecFromBuffer;

import 'package:flutter/material.dart';

import '../models/timetable_settings.dart';
import 'hex_color.dart';

class HomePageBackgroundVisual {
  const HomePageBackgroundVisual({required this.color, this.imageProvider});

  final Color color;
  final ImageProvider? imageProvider;

  bool get hasImage => imageProvider != null;

  bool get isTransparent => color.a == 0;

  BoxDecoration get decoration => BoxDecoration(
    color: color,
    image: hasImage
        ? DecorationImage(image: imageProvider!, fit: BoxFit.cover)
        : null,
  );
}

/// Memoized wallpaper-file existence, keyed by absolute path.
///
/// `hasHomePageBackdropImage()` is read on every home build (directly and via
/// the region helpers); probing the disk synchronously each build stalls the
/// UI thread whenever no wallpaper is configured. Each path is probed at most
/// once per app run; wallpaper mutation points already call
/// [evictHomePageImageCache], which invalidates the memo for the touched path.
final Map<String, bool> _homePageBackdropFileExistsCache = {};

bool _homePageFileExistsSync(String path) {
  return _homePageBackdropFileExistsCache.putIfAbsent(
    path,
    () => File(path).existsSync(),
  );
}

/// Drop the memoized existence result for [path].
///
/// Call whenever a wallpaper file is created, replaced or deleted so the next
/// build re-probes instead of trusting a stale memo.
void invalidateHomePageBackdropFileExists(String? path) {
  if (path == null || path.isEmpty) {
    return;
  }
  _homePageBackdropFileExistsCache.remove(path);
}

ImageProvider? homePageImageProvider(String? path) {
  if (path == null || path.isEmpty) {
    return null;
  }
  if (!_homePageFileExistsSync(path)) {
    return null;
  }
  return FileImage(File(path));
}

/// Decode width for full-screen wallpaper (matches device, capped for memory).
int homePageBackdropDecodeWidth() {
  final views = ui.PlatformDispatcher.instance.views;
  if (views.isEmpty) {
    return 1440;
  }
  final view = views.first;
  return view.physicalSize.width.round().clamp(720, 2160);
}

ImageProvider? homePageBackdropImageProvider(String? path) {
  if (path == null || path.isEmpty) {
    return null;
  }
  if (!_homePageFileExistsSync(path)) {
    return null;
  }
  return ResizeImage(
    FileImage(File(path)),
    width: homePageBackdropDecodeWidth(),
  );
}

/// Warm the image cache so the home backdrop appears on the first frame.
Future<void> precacheHomePageBackdropImage(TimetableSettings settings) async {
  final provider = homePageBackdropProvider(settings);
  if (provider == null) {
    return;
  }

  final stream = provider.resolve(ImageConfiguration.empty);
  final completer = Completer<void>();
  late ImageStreamListener listener;
  listener = ImageStreamListener(
    (ImageInfo image, bool syncCall) {
      if (!completer.isCompleted) {
        completer.complete();
      }
      stream.removeListener(listener);
    },
    onError: (Object error, StackTrace? stackTrace) {
      if (!completer.isCompleted) {
        completer.complete();
      }
      stream.removeListener(listener);
    },
  );
  stream.addListener(listener);

  try {
    await completer.future.timeout(const Duration(seconds: 8));
  } on TimeoutException {
    stream.removeListener(listener);
  }
}

void evictHomePageImageCache(String? path) {
  invalidateHomePageBackdropFileExists(path);
  if (path == null || path.isEmpty) {
    return;
  }
  if (!_homePageFileExistsSync(path)) {
    return;
  }
  final file = File(path);
  PaintingBinding.instance.imageCache.evict(FileImage(file));
  PaintingBinding.instance.imageCache.evict(
    ResizeImage(FileImage(file), width: homePageBackdropDecodeWidth()),
  );
}

Color resolveHomePageBackgroundColor({
  required TimetableSettings settings,
  required bool isDark,
  required Color darkFallback,
}) {
  if (isDark) {
    return darkFallback;
  }
  return parseHexColorOrFallback(
    settings.timetablePageBackgroundColor,
    fallback: darkFallback,
  );
}

/// Representative status-bar background used to derive system icon polarity.
///
/// The status bar can be transparent over the wallpaper, so the page's opaque
/// background is not enough to choose black or white system icons. Use the
/// sampled top band when available; before sampling completes, follow the
/// active app theme so a light-theme transition never keeps white icons.
Color resolveHomePageStatusBarBackground({
  required Color pageBackground,
  required bool statusBarShowsBackdrop,
  required bool hasBackdrop,
  required bool isDark,
  required bool usesFrostedChrome,
  required double? wallpaperTopLuminance,
}) {
  if (!statusBarShowsBackdrop || !hasBackdrop) {
    return pageBackground;
  }

  final luminance = wallpaperTopLuminance;
  if (luminance != null) {
    return luminance > 0.5
        ? Colors.white
        : (usesFrostedChrome ? const Color(0xFF1A1A1A) : Colors.black);
  }

  if (!isDark) {
    return Colors.white;
  }
  return usesFrostedChrome ? const Color(0xFF1A1A1A) : Colors.black;
}

/// Full-screen home backdrop path (wallpaper field; legacy background image fallback).
String? resolveHomePageBackdropImagePath(TimetableSettings settings) {
  final wallpaper = settings.homePageWallpaperPath;
  if (wallpaper != null && wallpaper.isNotEmpty) {
    return wallpaper;
  }
  final legacy = settings.homePageBackgroundImagePath;
  if (legacy != null && legacy.isNotEmpty) {
    return legacy;
  }
  return null;
}

/// Whether the wallpaper file exists and is usable on the home page.
///
/// Theme-agnostic: the wallpaper is shown in both light and dark mode (chrome
/// ink / glass scrim adapt via sampled luminance instead). Dark mode only
/// changes the *fallback* surface colour when no wallpaper is set.
bool hasHomePageBackdropImage(TimetableSettings settings) {
  return homePageImageProvider(resolveHomePageBackdropImagePath(settings)) !=
      null;
}

/// 当前生效的首页背景图提供者；无背景或文件缺失时返回 null。
ImageProvider? homePageBackdropProvider(TimetableSettings settings) {
  final key = homePageBackdropKey(settings);
  return key == null ? null : homePageBackdropImageProvider(key);
}

/// 首页是否有可用的背景（自选图片存在且可读）。
///
/// 背景文件丢失时（重装 / 清除数据 / 跨设备同步只带回 JSON）视为无背景，
/// 首页回退到纯色底，而不是停在一条失效路径上什么都不画。
bool hasHomePageBackdrop(TimetableSettings settings) {
  return homePageBackdropKey(settings) != null;
}

/// 背景身份键：用于亮度采样/预模糊缓存的幂等去重。
///
/// 返回可用的背景图片路径；无背景或文件不存在时返回 null，与
/// [hasHomePageBackdrop] / [homePageBackdropProvider] 保持同一口径。
String? homePageBackdropKey(TimetableSettings settings) {
  final path = resolveHomePageBackdropImagePath(settings);
  if (path != null && path.isNotEmpty && _homePageFileExistsSync(path)) {
    return path;
  }
  return null;
}

/// 课程卡片实际生效的表面样式。
///
/// 未设置壁纸（自选图片与内置壁纸都没有）时，「高斯模糊」没有可采样的
/// 磨砂背景，卡片统一降级为实体卡片渲染；设置了壁纸后才恢复用户选择的
/// [TimetableSettings.courseCardSurfaceStyle]（默认实体／高斯模糊），用户“设了壁纸后还要实体
/// 卡片”的切换选择始终保留。
///
/// [gaussianBlurAvailable] 为 false（模糊总开关关 = 全局材质「实体卡片」，
/// 或系统降级）时同样回落实体卡：高斯档寄生在全局模糊管线上，管线关闭
/// 后只剩裸 tint 过壁纸，读作透明卡片；且 [CourseCard] 的墨色规则
/// （玻璃档自动黑白 / 实体档对比度守卫）按这里的返回值分派，墨与面必须
/// 同源切换。默认 true 保持纯函数调用方（测试、预览）的原有行为。
///
/// 首页、日课表与设置页预览都走这一口径，避免无壁纸页把高斯卡片渲染成
/// 一团没有来源的透明水洗色。
CourseCardSurfaceStyle effectiveCourseCardSurfaceStyle(
  TimetableSettings settings, {
  bool gaussianBlurAvailable = true,
}) {
  if (!hasHomePageBackdrop(settings) || !gaussianBlurAvailable) {
    return CourseCardSurfaceStyle.solid;
  }
  return settings.courseCardSurfaceStyle;
}

/// 日视图**内容卡**（顶部摘要卡与议程卡）该用的材质档。
///
/// 就是课程卡那一档：输入只有卡片配置与「模糊管线当前可用吗」，**不看**顶栏 /
/// 信息栏 / 弹窗的材质。摘要卡曾经有一条例外（顶栏是玻璃时改成跟顶栏同款），
/// 2026-09-22 按用户口径删掉：「日视图顶部的日期卡片……也要跟日视图的课程卡片是
/// 一样的材质，选什么就是什么，不要第二种」。
///
/// 单独留这个函数是为了**可测**：真正的判据（有没有壁纸、模糊管线能不能跑）在组件
/// 测试里是环境绑定的（`HyperosBlurredHeader.liveBlurSupported` 只认 Android/iOS，
/// 测试宿主机上恒 false，于是任何玻璃档在组件测试里都算成实体）。把决策提成纯函数，
/// 这条口径才有一个不受环境影响的钉子。
CourseCardSurfaceStyle dayViewContentCardSurfaceStyle(
  TimetableSettings settings, {
  required bool backdropBlurOn,
}) => effectiveCourseCardSurfaceStyle(
  settings,
  gaussianBlurAvailable: backdropBlurOn,
);

/// Result of pre-resolving the home page's wallpaper backdrop before first
/// paint, so chrome frost does not flash a stale/blank capture.
class HomePageVisualReadiness {
  const HomePageVisualReadiness({this.hasBackdrop = false});

  /// Nothing to prepare (no wallpaper, or missing file).
  static const HomePageVisualReadiness empty = HomePageVisualReadiness();

  /// Whether a usable wallpaper backdrop image was resolved.
  final bool hasBackdrop;

  bool get isEmpty => !hasBackdrop;
}

/// Pre-resolves whether the home page needs wallpaper backdrop work.
///
/// Returns [HomePageVisualReadiness.empty] when no wallpaper path is
/// configured or the file is missing; those paths never paint a wallpaper
/// backdrop so no preparation is required. Runs in both themes — dark mode
/// shows the wallpaper just like light mode.
Future<HomePageVisualReadiness> prepareHomePageVisualReadiness(
  TimetableSettings settings,
) async {
  if (!hasHomePageBackdrop(settings)) {
    return HomePageVisualReadiness.empty;
  }
  return const HomePageVisualReadiness(hasBackdrop: true);
}

bool homePageRegionShowsBackdrop(TimetableSettings settings, int region) {
  if (!hasHomePageBackdrop(settings)) {
    return false;
  }
  return HomePageBackgroundScope.includes(
    settings.homePageBackgroundScope,
    region,
  );
}

HomePageBackgroundVisual resolveHomePageRegionBackground({
  required TimetableSettings settings,
  required bool isDark,
  required Color darkFallback,
  required int region,
}) {
  final baseColor = resolveHomePageBackgroundColor(
    settings: settings,
    isDark: isDark,
    darkFallback: darkFallback,
  );

  if (!HomePageBackgroundScope.includes(
    settings.homePageBackgroundScope,
    region,
  )) {
    return HomePageBackgroundVisual(color: baseColor);
  }

  if (hasHomePageBackdrop(settings)) {
    return const HomePageBackgroundVisual(color: Colors.transparent);
  }

  return HomePageBackgroundVisual(color: baseColor);
}

Widget homePageBackgroundLayer({
  required HomePageBackgroundVisual visual,
  required Widget child,
}) {
  if (visual.isTransparent) {
    return child;
  }
  if (!visual.hasImage) {
    return ColoredBox(color: visual.color, child: child);
  }
  return DecoratedBox(decoration: visual.decoration, child: child);
}

/// One continuous [BoxFit.cover] layer for wallpaper / background image.
Widget homePageBackdropLayer({required TimetableSettings settings}) {
  final image = homePageBackdropImageWidget(settings: settings);
  if (image == null) {
    return const SizedBox.shrink();
  }
  return Positioned.fill(child: image);
}

/// Full-bleed backdrop image for embedding inside a week page.
///
/// 背景图始终是静态 [Image]：内置壁纸（光斑漂移动画）已于 2026-09-13 整体
/// 移除，图片壁纸不存在动画路径。动态壁纸每 tick 都会改写玻璃的 backdrop，
/// 使首页每块玻璃跟着重做一次采样 + 模糊 + 折射，真机实测静置也以 15.2fps
/// 持续空转；静态壁纸下静置降到 0fps、滚动跟手感明显变好。
Widget? homePageBackdropImageWidget({required TimetableSettings settings}) {
  final provider = homePageBackdropProvider(settings);
  if (provider == null) {
    return null;
  }
  // 横向壁纸在 cover 下水平溢出，用用户拖选的对齐值决定显示哪一段。
  final alignX = settings.homePageWallpaperAlignX.clamp(-1.0, 1.0);
  final alignY = settings.homePageWallpaperAlignY.clamp(-1.0, 1.0);
  final alignment = Alignment(alignX.toDouble(), alignY.toDouble());
  final image = Image(
    key: ValueKey(homePageBackdropKey(settings)),
    image: provider,
    fit: BoxFit.cover,
    gaplessPlayback: true,
    alignment: alignment,
  );
  final scale = settings.homePageWallpaperScale.clamp(
    kWallpaperMinScale,
    kWallpaperMaxScale,
  );
  if (scale == 1) {
    // 出厂档（也是存量数据的读数）：不加那层变换，绘制路径与加缩放之前逐帧一致。
    return image;
  }
  // 缩放**绕对齐点**做：`cover` 已经按 alignment 选好显示哪一段，这里把这段整体
  // 放大，对齐点（左上 / 中心 / 右下）保持不动 —— 与编辑页取景一致。溢出量随之
  // 变大（放大 s 倍后是 `s × 封面尺寸 − 视口尺寸`，不是「基础溢出 × s」），所以可
  // 拖动范围也跟着变大 —— 编辑页按同一个值折算拖动位移，手指与内容始终 1:1。
  return Transform.scale(scale: scale, alignment: alignment, child: image);
}

/// 壁纸缩放的上下限（编辑页与渲染侧共用一份口径）。
///
/// 下限 1 = 刚好铺满（`cover` 的原始大小）：再小就露出底色，没有意义；
/// 上限 4 = 够看细节，再大只是糊。
const double kWallpaperMinScale = 1;
const double kWallpaperMaxScale = 4;

/// Title row height under the status bar on the home timetable header.
///
/// 就是根标题栏自己的最小高度（`HyperosRootHeader.minHeight` = 44）：星期行紧接着
/// 在它下面开始，而「chrome↔课表」那段间隙**不折进这个常量** ——
/// `homePageChromeGlassLayout` 会把它显式加进带高。
///
/// 旧值是 46（= 44 + 2px「预算」，想顺手盖掉那条缝）。后果：玻璃带比真正的
/// 标题行高 2px，而那条缝有 4px，于是带子下沿留下 **2px 完全没有玻璃覆盖**。
/// 模糊 = 0 时玻璃跟原图几乎一样、看不出来；模糊一开，玻璃被糊了、变亮了，
/// 这 2px 就成了一条横贯屏幕的黑线（真机 2026-09-20：星期栏底边一条黑线，
/// 且改上下外溢对它没有任何影响 —— 因为它根本不在玻璃形状里）。
const homePageHeaderContentHeight = 44.0;

/// The pager's live page, or null when it cannot be read safely.
///
/// Wallpaper toggles (first wallpaper set, follow-the-pager switch, blur
/// gates) swap conditional Stack children and can wrap the whole home stack
/// in [PreblurredWallpaperScope], rebuilding the week pager in place. The old
/// PageView element is deactivated immediately but its scroll position only
/// detaches at end-of-frame unmount, so the fresh PageView attaches while the
/// stale one is still attached — `positions.length == 2` for that one frame.
/// [PageController.page] asserts in that window; callers fall back to
/// [PageController.initialPage] until the replacement tree settles.
double? controllerPageOrNull(PageController controller) {
  if (!controller.hasClients || controller.positions.length != 1) {
    return null;
  }
  return controller.page;
}

/// Full-screen wallpaper strip driven by a week [PageController].
///
/// Each page paints the same cover image at full-screen size. Translating the
/// strip with [controller.page] keeps the title-bar band continuous with the
/// body while the user swipes weeks.
class HomePageSlidingBackdropLayer extends StatelessWidget {
  const HomePageSlidingBackdropLayer({
    required this.controller,
    required this.pageCount,
    required this.settings,
    super.key,
  });

  final PageController controller;
  final int pageCount;
  final TimetableSettings settings;

  @override
  Widget build(BuildContext context) {
    final image = homePageBackdropImageWidget(settings: settings);
    if (image == null || pageCount <= 0) {
      return const SizedBox.shrink();
    }

    return Positioned.fill(
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, child) {
          final size = MediaQuery.sizeOf(context);
          final pageWidth = size.width;
          if (!pageWidth.isFinite || pageWidth <= 0) {
            return const SizedBox.shrink();
          }
          final rawPage =
              controllerPageOrNull(controller) ??
              controller.initialPage.toDouble();
          final first = math.max(0, rawPage.floor() - 1);
          final last = math.min(pageCount - 1, rawPage.ceil() + 1);
          return Stack(
            children: [
              for (var index = first; index <= last; index++)
                Positioned(
                  left: (index - rawPage) * pageWidth,
                  top: 0,
                  width: pageWidth,
                  height: size.height,
                  child: child!,
                ),
            ],
          );
        },
        child: image,
      ),
    );
  }
}

/// Foreground on a light wallpaper.
const homePageChromeForegroundOnLight = Color(0xFF1A1A1A);

/// Foreground on a dark wallpaper (title / menu icons).
const homePageChromeForegroundOnDark = Color(0xFFFFFFFF);

/// Contrast ink for home chrome over a wallpaper sample.
Color homePageChromeForegroundForLuminance(
  double? luminance, {
  double darkThreshold = 0.45,
  Color fallback = homePageChromeForegroundOnLight,
}) {
  if (luminance == null) {
    return fallback;
  }
  return luminance < darkThreshold
      ? homePageChromeForegroundOnDark
      : homePageChromeForegroundOnLight;
}

/// Secondary/muted ink derived from the primary chrome foreground.
Color homePageChromeMutedForeground(Color foreground) {
  final isLightInk = foreground == homePageChromeForegroundOnDark;
  return foreground.withValues(alpha: isLightInk ? 0.72 : 0.62);
}

/// Whether [configuredHex] is unset or matches the built-in default.
///
/// Used so wallpaper auto-contrast only replaces **default** ink; a user-picked
/// hex (including a deliberate black/white that equals a default of the other
/// theme mode) is left alone when it differs from [defaultHex].
bool homePageInkUsesBuiltInDefault(String? configuredHex, String defaultHex) {
  final configured = tryParseHexColor(configuredHex);
  if (configured == null) {
    return true;
  }
  final builtIn = tryParseHexColor(defaultHex);
  if (builtIn == null) {
    return false;
  }
  return configured.toARGB32() == builtIn.toARGB32();
}

/// Ink for weekday / time-axis chrome over the home wallpaper.
///
/// - No wallpaper → [themeFallback] (or the configured hex when set).
/// - User customized away from [defaultHex] → the configured colour, unless it
///   would be unreadable over the wallpaper band: then its lightness is pushed
///   with the hue kept ([readableColorOnLuminance]). The pick is never thrown
///   away for black/white anymore — that read as "my text colour setting
///   stopped working".
/// - Still on the built-in default + dark/light wallpaper → same black/white
///   flip as the title logo ([homePageChromeForegroundForLuminance]): nothing
///   was picked here, and auto-flipping IS that default's behaviour.
Color homePageOverWallpaperInk({
  required String? configuredHex,
  required String defaultHex,
  required Color themeFallback,
  required bool hasBackdrop,
  required double? wallpaperLuminance,
  double darkThreshold = 0.45,
}) {
  final configured = tryParseHexColor(configuredHex);
  final usesDefault = homePageInkUsesBuiltInDefault(configuredHex, defaultHex);

  if (!hasBackdrop) {
    return configured ?? themeFallback;
  }
  if (!usesDefault && configured != null) {
    // A user-picked colour stays as long as it keeps ~3:1 contrast against
    // the wallpaper band behind this chrome; below that the ink would render
    // invisible over the photo, so its lightness is pushed (hue preserved).
    // The custom colour returns untouched as soon as the wallpaper (or this
    // region's view of it) is gone.
    final luminance = wallpaperLuminance;
    if (luminance != null &&
        !homePageInkHasSufficientContrast(configured, luminance)) {
      return readableColorOnLuminance(
        configured,
        luminance,
        darkThreshold: darkThreshold,
      );
    }
    return configured;
  }
  return homePageChromeForegroundForLuminance(
    wallpaperLuminance,
    darkThreshold: darkThreshold,
    fallback: configured ?? themeFallback,
  );
}

/// Whether [ink] keeps at least ~3:1 contrast against a wallpaper band of
/// [wallpaperLuminance].
///
/// Photos are busy, so anything above 3:1 is left alone; below it the ink is
/// treated as invisible over the wallpaper and auto-contrast takes over.
/// Mirrors the threshold used by the home page's low-contrast explainer.
bool homePageInkHasSufficientContrast(
  Color ink,
  double wallpaperLuminance, {
  double minContrastRatio = 3.0,
}) {
  final inkLuminance = ink.computeLuminance();
  final hi = math.max(inkLuminance, wallpaperLuminance);
  final lo = math.min(inkLuminance, wallpaperLuminance);
  return (hi + 0.05) / (lo + 0.05) >= minContrastRatio;
}

/// Accent (today / selected day) over wallpaper.
///
/// Custom blues etc. stay exactly as the user set them — unless they would be
/// unreadable over the wallpaper band (contrast below ~3:1), in which case the
/// accent **keeps its hue** and only its lightness is pushed
/// ([readableColorOnLuminance]). Replacing the user's colour with pure
/// black/white reads as "my accent setting stopped working", which is exactly
/// the complaint that retired the old flip.
/// The unset path falls back to [themeFallback] (usually [ColorScheme.primary]).
Color homePageOverWallpaperAccent({
  required String? configuredHex,
  required Color themeFallback,
  bool hasBackdrop = false,
  double? wallpaperLuminance,
  double darkThreshold = 0.45,
}) {
  final configured = tryParseHexColor(configuredHex) ?? themeFallback;
  if (!hasBackdrop) {
    return configured;
  }
  final luminance = wallpaperLuminance;
  if (luminance == null ||
      homePageInkHasSufficientContrast(configured, luminance)) {
    return configured;
  }
  return readableColorOnLuminance(
    configured,
    luminance,
    darkThreshold: darkThreshold,
  );
}

/// Below this HSL saturation a pick counts as grey (white/black included):
/// there is no hue worth preserving, so it gets the black/white pole instead of
/// a "just 3:1" intermediate grey.
const double _achromaticSaturation = 0.02;

/// Readable variant of a user-picked colour (weekday ink or accent) over a
/// wallpaper band of [wallpaperLuminance], hue preserved.
///
/// - Grey / white / black picks (no hue to keep) go straight to
///   [homePageChromeForegroundForLuminance]. Stopping such a pick at "just
///   3:1" would turn a dark grey into a mid grey, which reads far worse than
///   the pure white it used to get.
/// - Coloured picks are walked toward white and toward black in 5% steps (the
///   granularity [readableAccentOnCardInk] uses for course-card accents); the
///   side that clears [minContrastRatio] in the **fewest steps wins**, i.e.
///   the smallest deviation from the colour the user picked. The band's ink
///   polarity ([homePageChromeForegroundForLuminance]) only breaks a tie: it
///   keeps the colour on the same side as the chrome next to it, but never
///   beats a colour that moved less.
///
/// A band sitting right next to the colour in luminance can make one side
/// unusable (pure white tops out at ~2.3:1 against a 0.4 band); the other side
/// is then the only option and is taken. Colour identity is the goal, ink
/// polarity is a preference.
Color readableColorOnLuminance(
  Color accent,
  double wallpaperLuminance, {
  double minContrastRatio = 3.0,
  double darkThreshold = 0.45,
}) {
  if (HSLColor.fromColor(accent).saturation < _achromaticSaturation) {
    return homePageChromeForegroundForLuminance(
      wallpaperLuminance,
      darkThreshold: darkThreshold,
      fallback: accent,
    );
  }
  final towardLight = _pushAccentTowardPole(
    accent,
    Colors.white,
    wallpaperLuminance,
    minContrastRatio,
  );
  final towardDark = _pushAccentTowardPole(
    accent,
    Colors.black,
    wallpaperLuminance,
    minContrastRatio,
  );
  if (towardLight == null || towardDark == null) {
    final only = towardLight ?? towardDark;
    if (only != null) {
      return only.$1;
    }
    // Neither pole reaches the floor (needs a band that no 5%-step walk can
    // clear): fall back to the band's own polarity, like the old flip did.
    return wallpaperLuminance < darkThreshold ? Colors.white : Colors.black;
  }
  if (towardLight.$2 != towardDark.$2) {
    return towardLight.$2 < towardDark.$2 ? towardLight.$1 : towardDark.$1;
  }
  return wallpaperLuminance < darkThreshold ? towardLight.$1 : towardDark.$1;
}

/// First 5%-step interpolate of [accent] toward [pole] that clears
/// [minContrastRatio] against [wallpaperLuminance], with its step count; null
/// when even the pole itself falls short.
(Color, int)? _pushAccentTowardPole(
  Color accent,
  Color pole,
  double wallpaperLuminance,
  double minContrastRatio,
) {
  for (var i = 1; i <= 20; i++) {
    final candidate = Color.lerp(accent, pole, i / 20)!;
    if (homePageInkHasSufficientContrast(
      candidate,
      wallpaperLuminance,
      minContrastRatio: minContrastRatio,
    )) {
      return (candidate, i);
    }
  }
  return null;
}

/// Secondary/muted label derived from an already-resolved primary ink.
Color homePageOverWallpaperMutedInk(
  Color primaryInk, {
  double lightInkAlpha = 0.72,
  double darkInkAlpha = 0.70,
}) {
  final isLightInk =
      primaryInk.toARGB32() == homePageChromeForegroundOnDark.toARGB32() ||
      primaryInk.computeLuminance() > 0.55;
  return primaryInk.withValues(
    alpha: isLightInk ? lightInkAlpha : darkInkAlpha,
  );
}

/// 卡面内强调色文字（如情侣课表「共同空闲」绿 `#4CAF50`）的可读变体。
///
/// 卡面玻璃透壁纸，#4CAF50 这类中明度强调色在浅色卡面上文字对比仅
/// ~2.8:1（亮粉壁纸上更低），小字号几乎不可读。按母卡墨色 [cardInk]
/// 判断卡面明暗极性后只调明度、不换色相——浅色卡面向黑压暗（亮度压到
/// ≤0.12，对白底 ≥ ~6:1），深色卡面向白提亮（亮度抬到 ≥0.50，对深色
/// 玻璃 ≥ ~3:1），保住强调色语义（绿色=空闲），区别于 chrome 强调色
/// 对比不足时整体回落黑白墨。本就可读的强调色原样返回。
Color readableAccentOnCardInk(Color accent, Color cardInk) {
  final cardIsLight = cardInk.computeLuminance() <= 0.5;
  bool readable(double luminance) =>
      cardIsLight ? luminance <= 0.12 : luminance >= 0.50;
  if (readable(accent.computeLuminance())) {
    return accent;
  }
  final target = cardIsLight ? Colors.black : Colors.white;
  for (var i = 1; i <= 20; i++) {
    final candidate = Color.lerp(accent, target, i / 20)!;
    if (readable(candidate.computeLuminance())) {
      return candidate;
    }
  }
  return target;
}

/// Average luminance of the top band of a wallpaper file (for chrome contrast).
///
/// [viewportSize] and alignment must match the widget that displays the image
/// when the caller uses [BoxFit.cover]. Without them, the whole source image is
/// sampled, which is kept as a useful fallback for non-rendering callers.
///
/// Returns null when the file is missing or decoding fails.
Future<double?> sampleHomePageWallpaperTopLuminance(
  String? path, {
  Size? viewportSize,
  double alignX = 0,
  double alignY = 0,
  double scale = 1,
}) async {
  return (await sampleHomePageWallpaperLuminanceBands(
    path,
    viewportSize: viewportSize,
    alignX: alignX,
    alignY: alignY,
    scale: scale,
  ))?.top;
}

/// Normalized source rectangle visible when [imageSize] is rendered into
/// [viewportSize] with [BoxFit.cover] and the given alignment.
///
/// The returned coordinates are fractions of the source image. This is the
/// same crop used by [homePageBackdropImageWidget], so luminance samples do
/// not accidentally inspect an off-screen part of a wide/tall wallpaper.
({double left, double top, double width, double height})
homePageWallpaperVisibleSourceRect({
  required Size viewportSize,
  required Size imageSize,
  double alignX = 0,
  double alignY = 0,
  double zoom = 1,
}) {
  if (!viewportSize.width.isFinite ||
      !viewportSize.height.isFinite ||
      viewportSize.width <= 0 ||
      viewportSize.height <= 0 ||
      !imageSize.width.isFinite ||
      !imageSize.height.isFinite ||
      imageSize.width <= 0 ||
      imageSize.height <= 0) {
    return (left: 0, top: 0, width: 1, height: 1);
  }

  final viewportAspect = viewportSize.width / viewportSize.height;
  final imageAspect = imageSize.width / imageSize.height;
  final visibleWidth = imageAspect > viewportAspect
      ? viewportAspect / imageAspect
      : 1.0;
  final visibleHeight = imageAspect < viewportAspect
      ? imageAspect / viewportAspect
      : 1.0;
  final normalizedAlignX = alignX.clamp(-1.0, 1.0).toDouble();
  final normalizedAlignY = alignY.clamp(-1.0, 1.0).toDouble();
  // 用户放大倍数：取景窗口按比例缩小（可见比例 ÷ 倍数），位置仍由对齐值决定
  // ——与 `Transform.scale(alignment: 对齐点)` 那套几何等价（推导见
  // `homePageBackdropImageWidget`）：align = -1 / 0 / +1 三处与不放大时完全一致。
  final zoomed = zoom.clamp(kWallpaperMinScale, kWallpaperMaxScale);
  final visibleWidthAtZoom = visibleWidth / zoomed;
  final visibleHeightAtZoom = visibleHeight / zoomed;
  final left =
      (1.0 - visibleWidthAtZoom) * (normalizedAlignX + 1.0) / 2.0;
  final top =
      (1.0 - visibleHeightAtZoom) * (normalizedAlignY + 1.0) / 2.0;
  return (
    left: left,
    top: top,
    width: visibleWidthAtZoom,
    height: visibleHeightAtZoom,
  );
}

Future<ui.Image?> _decodeHomePageWallpaperSample(String path) async {
  // Transfer ownership to the engine decoder instead of materializing the
  // complete file as a Dart Uint8List. The returned sample is bounded to a
  // small width and is independent of ImageCache/listener timing.
  final buffer = await ui.ImmutableBuffer.fromFilePath(path);
  final codec = await ui.instantiateImageCodecFromBuffer(
    buffer,
    targetWidth: 128,
    allowUpscaling: false,
  );
  try {
    final frame = await codec.getNextFrame();
    return frame.image;
  } finally {
    codec.dispose();
  }
}

/// 背景亮度带入口：读取当前背景图的 top / weekday / body 三条亮度带。
///
/// 无背景时返回 null（由 [sampleHomePageWallpaperLuminanceBands] 处理空路径）。
Future<({double top, double weekday, double body})?>
sampleHomePageBackdropLuminanceBands(
  TimetableSettings settings, {
  Size? viewportSize,
  double alignX = 0,
  double alignY = 0,
}) {
  return sampleHomePageWallpaperLuminanceBands(
    resolveHomePageBackdropImagePath(settings),
    viewportSize: viewportSize,
    alignX: alignX,
    alignY: alignY,
    // 缩放直接读 settings（不发参数）：三个调用点（首页 chrome 墨色 / 启动预热 /
    // 设置页预览带）本来就该按**当前取景**采样，多一个参数只会有人漏传。
    scale: settings.homePageWallpaperScale,
  );
}

/// Top-band + weekday-band + card-region WCAG luminance of a wallpaper file, from one decode.
///
/// `top` covers the status bar / title region (header chrome ink), `weekday`
/// the band behind the weekday / date chrome bar, `body` the vertical band
/// where day-view cards live. A wallpaper can be bright at the very top and
/// dark behind the weekday bar (or vice versa), so each chrome region must
/// judge its ink from the band actually behind it, not one shared sample —
/// the top band alone mis-ink the weekday bar on sky/ground photos.
Future<({double top, double weekday, double body})?>
sampleHomePageWallpaperLuminanceBands(
  String? path, {
  Size? viewportSize,
  double alignX = 0,
  double alignY = 0,
  double scale = 1,
}) async {
  if (path == null || path.isEmpty) {
    return null;
  }
  final file = File(path);
  if (!file.existsSync()) {
    return null;
  }
  try {
    final image = await _decodeHomePageWallpaperSample(path);
    if (image == null) {
      return null;
    }
    try {
      // Must await: releasing the handle in `finally` while
      // [_averageBandLuminances] is still suspended inside
      // `image.toByteData()` would be a use-after-dispose.
      return await _averageBandLuminances(
        image,
        viewportSize: viewportSize,
        alignX: alignX,
        alignY: alignY,
        scale: scale,
      );
    } finally {
      image.dispose();
    }
  } catch (error, stackTrace) {
    debugPrint(
      'sampleHomePageWallpaperLuminanceBands failed: $error\n$stackTrace',
    );
    return null;
  }
}

// Keep wallpaper samples in the same WCAG relative-luminance space as
// Color.computeLuminance(). This is intentionally the Flutter engine's
// threshold (0.03928), so text contrast decisions do not mix encoded sRGB
// values with linear luminance values. (WCAG 2.x later corrected the
// threshold to 0.04045; the difference only affects near-black values and
// stays consistent with Color.computeLuminance(), so the engine value is
// kept on purpose.)
double _linearizeSrgbComponent(double component) {
  if (component <= 0.03928) {
    return component / 12.92;
  }
  return math.pow((component + 0.055) / 1.055, 2.4) as double;
}

/// Precomputed sRGB -> linear table for all 256 8-bit component values.
///
/// Band sampling runs 3 lookups per pixel over a 128px-wide decode; a table
/// removes the per-pixel `pow` calls (3-5x faster) while producing values
/// identical to [_linearizeSrgbComponent], which is the single source of
/// truth for the curve above.
final Float64List _srgbLinearizeLut = _buildSrgbLinearizeLut();

Float64List _buildSrgbLinearizeLut() {
  final lut = Float64List(256);
  for (var value = 0; value < 256; value++) {
    lut[value] = _linearizeSrgbComponent(value / 255.0);
  }
  return lut;
}

/// 按 cover 裁剪从 [image] 采样三条亮度带（top / weekday / body）。
///
/// **所有权契约**：本函数只读 [image]，**不** dispose 它 —— 调用方创建、
/// 调用方释放。
///
/// 历史教训：早期版本在此函数内部 dispose 传入的 handle，而另一个调用方
/// 同时又在 `finally` 里 dispose 同一个 handle，于是同一个 handle 被释放
/// 两次，命中 `dart:ui/painting.dart` 中 `Image.dispose` 的断言（debug 直接
/// 崩；release 下会经 `_handles.isEmpty` 再次调用 `_image.dispose()`，触碰
/// native `Image::dispose` 双重释放）。所有调用路径必须共用同一条所有权规则。
Future<({double top, double weekday, double body})?> _averageBandLuminances(
  ui.Image image, {
  Size? viewportSize,
  double alignX = 0,
  double alignY = 0,
  double scale = 1,
}) async {
  final byteData = await image.toByteData();
  if (byteData == null) {
    return null;
  }
  final width = image.width;
  final height = image.height;
  if (width <= 0 || height <= 0) {
    return null;
  }
  final buffer = byteData.buffer.asUint8List();
  final sourceRect = viewportSize == null
      ? (left: 0.0, top: 0.0, width: 1.0, height: 1.0)
      : homePageWallpaperVisibleSourceRect(
          viewportSize: viewportSize,
          imageSize: Size(width.toDouble(), height.toDouble()),
          alignX: alignX,
          alignY: alignY,
          zoom: scale,
        );

  double? band(double fromFraction, double toFraction) {
    final sourceTop = sourceRect.top + sourceRect.height * fromFraction;
    final sourceBottom = sourceRect.top + sourceRect.height * toFraction;
    final fromRow = (height * sourceTop).floor().clamp(0, height - 1);
    final toRow = (height * sourceBottom).ceil().clamp(fromRow + 1, height);
    final sourceLeft = sourceRect.left;
    final sourceRight = sourceRect.left + sourceRect.width;
    final fromColumn = (width * sourceLeft).floor().clamp(0, width - 1);
    final toColumn = (width * sourceRight).ceil().clamp(fromColumn + 1, width);
    var total = 0.0;
    var count = 0;
    for (var row = fromRow; row < toRow; row++) {
      final rowOffset = row * width * 4;
      for (var column = fromColumn; column < toColumn; column++) {
        final offset = rowOffset + column * 4;
        final red = _srgbLinearizeLut[buffer[offset]];
        final green = _srgbLinearizeLut[buffer[offset + 1]];
        final blue = _srgbLinearizeLut[buffer[offset + 2]];
        total += 0.2126 * red + 0.7152 * green + 0.0722 * blue;
        count++;
      }
    }
    return count == 0 ? null : total / count;
  }

  // Values are relative luminance, matching Color.computeLuminance().
  // Top: the status bar + title strip of a cover-fitted wallpaper (header
  // ink). Weekday: the band the weekday/date chrome bar sits over — its ink
  // must not follow the header's band, they can differ on the same photo.
  // Body: the band the day-view summary/agenda cards sit over.
  final top = band(0, 0.09);
  final weekday = band(0.07, 0.20);
  final body = band(0.22, 0.72);
  if (top == null || weekday == null || body == null) {
    return null;
  }
  return (top: top, weekday: weekday, body: body);
}

/// Approximate stacked header band: optional status bar + title row.
double homePageHeaderBandHeight(
  BuildContext context, {
  bool includeStatusBar = true,
}) {
  final safeTop = includeStatusBar ? MediaQuery.paddingOf(context).top : 0;
  return safeTop + homePageHeaderContentHeight;
}

/// [Stack] geometry for a home chrome blur band.
///
/// When the status bar is masked (scope off), the band starts below [safeAreaTop]
/// so it aligns with [FHeader] content instead of the status bar inset.
({double top, double height}) homePageHeaderBlurBandRect({
  required double safeAreaTop,
  required bool includeStatusBar,
  double extendBottom = 0,
}) {
  if (includeStatusBar) {
    return (
      top: 0,
      height: safeAreaTop + homePageHeaderContentHeight + extendBottom,
    );
  }
  return (top: safeAreaTop, height: homePageHeaderContentHeight + extendBottom);
}
