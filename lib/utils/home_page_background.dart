import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui'
    as ui
    show Image, ImageByteFormat, PlatformDispatcher, instantiateImageCodec;

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

ImageProvider? homePageImageProvider(String? path) {
  if (path == null || path.isEmpty) {
    return null;
  }
  final file = File(path);
  if (!file.existsSync()) {
    return null;
  }
  return FileImage(file);
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
  final file = File(path);
  if (!file.existsSync()) {
    return null;
  }
  return ResizeImage(FileImage(file), width: homePageBackdropDecodeWidth());
}

/// Warm the image cache so the home backdrop appears on the first frame.
Future<void> precacheHomePageBackdropImage(TimetableSettings settings) async {
  final provider = homePageBackdropImageProvider(
    resolveHomePageBackdropImagePath(settings),
  );
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
  if (path == null || path.isEmpty) {
    return;
  }
  final file = File(path);
  if (!file.existsSync()) {
    return;
  }
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
  if (!hasHomePageBackdropImage(settings)) {
    return HomePageVisualReadiness.empty;
  }
  return const HomePageVisualReadiness(hasBackdrop: true);
}

bool homePageRegionShowsBackdrop(TimetableSettings settings, int region) {
  if (!hasHomePageBackdropImage(settings)) {
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

  if (hasHomePageBackdropImage(settings)) {
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
Widget? homePageBackdropImageWidget({required TimetableSettings settings}) {
  final path = resolveHomePageBackdropImagePath(settings);
  final provider = homePageBackdropImageProvider(path);
  if (provider == null) {
    return null;
  }
  // 横向壁纸在 cover 下水平溢出，用用户拖选的对齐值决定显示哪一段。
  final alignX = settings.homePageWallpaperAlignX.clamp(-1.0, 1.0);
  final alignY = settings.homePageWallpaperAlignY.clamp(-1.0, 1.0);
  return Image(
    key: ValueKey(path),
    image: provider,
    fit: BoxFit.cover,
    gaplessPlayback: true,
    alignment: Alignment(alignX.toDouble(), alignY.toDouble()),
  );
}

/// Title row height under the status bar on the home timetable header.
///
/// Matches [FHeader] min height (44) plus a small frosted-chrome padding budget
/// so the continuous glass band meets the weekday bar without a 1鈥?px seam.
const homePageHeaderContentHeight = 46.0;

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
          final rawPage = controller.hasClients
              ? (controller.page ?? controller.initialPage.toDouble())
              : controller.initialPage.toDouble();
          final first = math.max(0, rawPage.floor() - 1);
          final last = math.min(pageCount - 1, rawPage.ceil() + 1);
          return Stack(
            clipBehavior: Clip.hardEdge,
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
///   would be unreadable over the wallpaper band: then the automatic black/
///   white flip takes over ([homePageInkHasSufficientContrast]).
/// - Still on the built-in default + dark/light wallpaper → same black/white
///   flip as the title logo ([homePageChromeForegroundForLuminance]).
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
    // invisible over the photo, so fall back to the auto black/white flip.
    // The custom colour returns as soon as the wallpaper (or this region's
    // view of it) is gone.
    final luminance = wallpaperLuminance;
    if (luminance != null &&
        !homePageInkHasSufficientContrast(configured, luminance)) {
      return homePageChromeForegroundForLuminance(
        luminance,
        darkThreshold: darkThreshold,
        fallback: configured,
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
/// Custom blues etc. stay as the user set them — unless they would be
/// unreadable over the wallpaper band (contrast below ~3:1), in which case
/// the automatic black/white flip takes over so the "today" column never
/// vanishes into the photo. The unset path falls back to [themeFallback]
/// (usually [ColorScheme.primary]).
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
  if (luminance != null &&
      !homePageInkHasSufficientContrast(configured, luminance)) {
    return homePageChromeForegroundForLuminance(
      luminance,
      darkThreshold: darkThreshold,
      fallback: configured,
    );
  }
  return configured;
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
}) async {
  return (await sampleHomePageWallpaperLuminanceBands(
    path,
    viewportSize: viewportSize,
    alignX: alignX,
    alignY: alignY,
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
  final left = (1.0 - visibleWidth) * (normalizedAlignX + 1.0) / 2.0;
  final top = (1.0 - visibleHeight) * (normalizedAlignY + 1.0) / 2.0;
  return (left: left, top: top, width: visibleWidth, height: visibleHeight);
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
}) async {
  if (path == null || path.isEmpty) {
    return null;
  }
  final file = File(path);
  if (!await file.exists()) {
    return null;
  }
  try {
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      return null;
    }
    final codec = await ui.instantiateImageCodec(
      bytes,
      // Keep a small but aspect-ratio-preserving decode. The visible crop is
      // applied below from the actual decoded dimensions and display viewport.
      targetWidth: 128,
    );
    final frame = await codec.getNextFrame();
    final image = frame.image;
    codec.dispose();
    return _averageBandLuminances(
      image,
      viewportSize: viewportSize,
      alignX: alignX,
      alignY: alignY,
    );
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
// values with linear luminance values.
double _linearizeSrgbComponent(double component) {
  if (component <= 0.03928) {
    return component / 12.92;
  }
  return math.pow((component + 0.055) / 1.055, 2.4) as double;
}

Future<({double top, double weekday, double body})?> _averageBandLuminances(
  ui.Image image, {
  Size? viewportSize,
  double alignX = 0,
  double alignY = 0,
}) async {
  final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  if (byteData == null) {
    image.dispose();
    return null;
  }
  final width = image.width;
  final height = image.height;
  image.dispose();
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
        final red = _linearizeSrgbComponent(buffer[offset] / 255.0);
        final green = _linearizeSrgbComponent(buffer[offset + 1] / 255.0);
        final blue = _linearizeSrgbComponent(buffer[offset + 2] / 255.0);
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
  final top = band(0.0, 0.09);
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
