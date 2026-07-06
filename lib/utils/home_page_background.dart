import 'dart:async';
import 'dart:io';
import 'dart:ui' show PlatformDispatcher;

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
  final views = PlatformDispatcher.instance.views;
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

bool hasHomePageBackdropImage(
  TimetableSettings settings, {
  required bool isDark,
}) {
  if (isDark) {
    return false;
  }
  return homePageImageProvider(resolveHomePageBackdropImagePath(settings)) !=
      null;
}

bool homePageRegionShowsBackdrop(
  TimetableSettings settings,
  int region, {
  required bool isDark,
}) {
  if (!hasHomePageBackdropImage(settings, isDark: isDark)) {
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

  if (isDark ||
      !HomePageBackgroundScope.includes(
        settings.homePageBackgroundScope,
        region,
      )) {
    return HomePageBackgroundVisual(color: baseColor);
  }

  if (hasHomePageBackdropImage(settings, isDark: isDark)) {
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
Widget homePageBackdropLayer({
  required TimetableSettings settings,
  required bool isDark,
}) {
  final image = homePageBackdropImageWidget(settings: settings, isDark: isDark);
  if (image == null) {
    return const SizedBox.shrink();
  }
  return Positioned.fill(child: image);
}

/// Full-bleed backdrop image for embedding inside a week page.
Widget? homePageBackdropImageWidget({
  required TimetableSettings settings,
  required bool isDark,
}) {
  if (isDark) {
    return null;
  }
  final path = resolveHomePageBackdropImagePath(settings);
  final provider = homePageBackdropImageProvider(path);
  if (provider == null) {
    return null;
  }
  return Image(
    key: ValueKey(path),
    image: provider,
    fit: BoxFit.cover,
    gaplessPlayback: true,
  );
}

/// Title row height under the status bar on the home timetable header.
const homePageHeaderContentHeight = 46.0;

/// Approximate stacked header band: optional status bar + title row.
double homePageHeaderBandHeight(
  BuildContext context, {
  bool includeStatusBar = true,
}) {
  final safeTop = includeStatusBar ? MediaQuery.paddingOf(context).top : 0;
  return safeTop + homePageHeaderContentHeight;
}

/// [Stack] geometry for [HomePageHeaderBlurBand].
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

@Deprecated('Use homePageBackdropLayer')
Widget homePageWallpaperLayer({required String? wallpaperPath}) {
  final image = homePageImageProvider(wallpaperPath);
  if (image == null) {
    return const SizedBox.shrink();
  }
  return Positioned.fill(
    child: Image(image: image, fit: BoxFit.cover, gaplessPlayback: true),
  );
}
