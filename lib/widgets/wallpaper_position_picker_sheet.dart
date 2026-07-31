import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../ui/hyperos/hyperos.dart';
import '../utils/home_page_background.dart';

/// 壁纸位置选择页的返回结果。
///
/// [confirmed] 为 false 表示用户通过系统返回/左上角退出按钮离开，
/// 此时调用方不应应用任何对齐改动。
class WallpaperPositionPickerResult {
  const WallpaperPositionPickerResult({
    required this.path,
    required this.alignX,
    required this.alignY,
    required this.confirmed,
  });

  final String path;
  final double alignX;
  final double alignY;
  final bool confirmed;
}

/// 以 BoxFit.cover 布局时，图片沿指定轴相对视口溢出的逻辑像素量。
///
/// 图片在该轴不溢出（例如横向壁纸在垂直方向）时返回 0。
double wallpaperOverflowDragExtent({
  required Size viewportSize,
  required Size imageSize,
  required bool horizontal,
}) {
  final coverScale = _coverScale(viewportSize: viewportSize, imageSize: imageSize);
  final scaledImageWidth = imageSize.width * coverScale;
  final scaledImageHeight = imageSize.height * coverScale;
  final overflow = horizontal
      ? scaledImageWidth - viewportSize.width
      : scaledImageHeight - viewportSize.height;
  return overflow < 0 ? 0 : overflow;
}

double _coverScale({required Size viewportSize, required Size imageSize}) {
  final widthScale = viewportSize.width / imageSize.width;
  final heightScale = viewportSize.height / imageSize.height;
  return widthScale > heightScale ? widthScale : heightScale;
}

/// 根据拖动偏移量计算新的对齐坐标（范围 -1..1）。
///
/// 拖动方向与 alignment 正方向一致：alignment 从 0 走到 1 对应图片移动
/// 溢出量的一半。超出范围时钳制到 [-1, 1]。
double wallpaperAlignAfterDrag({
  required double previousAlign,
  required double dragDelta,
  required double overflowExtent,
}) {
  if (overflowExtent <= 0) {
    return 0;
  }
  final next = previousAlign + 2 * dragDelta / overflowExtent;
  return next.clamp(-1.0, 1.0);
}

/// 以全屏页方式打开壁纸位置选择器。
///
/// [initialAlignX] / [initialAlignY] 为进入时已保存的对齐值；传入
/// [onPickNewImage] 时页面底部会显示「换壁纸」按钮，用于从相册重新选择图片。
Future<WallpaperPositionPickerResult?> pushWallpaperPositionPickerPage(
  BuildContext context, {
  required String imagePath,
  required double initialAlignX,
  required double initialAlignY,
  Future<String?> Function()? onPickNewImage,
}) {
  return HyperosNavigation.push<WallpaperPositionPickerResult>(
    context,
    builder: (_) => WallpaperPositionPickerPage(
      imagePath: imagePath,
      initialAlignX: initialAlignX,
      initialAlignY: initialAlignY,
      onPickNewImage: onPickNewImage,
    ),
  );
}

/// 壁纸位置选择全屏页。
///
/// 预览铺满整个页面，与首页壁纸一样全屏显示（同屏幕尺寸、同 cover、
/// 同对齐），所见即所得；拖动图片可同时调整水平和垂直对齐，
/// 状态栏也透出壁纸；顶部悬浮「退出 / 标题 / 完成」，底部为「换壁纸」。
class WallpaperPositionPickerPage extends StatefulWidget {
  const WallpaperPositionPickerPage({
    super.key,
    required this.imagePath,
    required this.initialAlignX,
    required this.initialAlignY,
    this.onPickNewImage,
  });

  final String imagePath;
  final double initialAlignX;
  final double initialAlignY;

  /// 非空时显示「换壁纸」按钮；返回 null 表示用户取消。
  final Future<String?> Function()? onPickNewImage;

  @override
  State<WallpaperPositionPickerPage> createState() =>
      _WallpaperPositionPickerPageState();
}

class _WallpaperPositionPickerPageState
    extends State<WallpaperPositionPickerPage> {
  late String _imagePath;
  late double _alignX;
  late double _alignY;

  Size? _imageSize;
  bool _switching = false;
  double? _topLuminance;

  @override
  void initState() {
    super.initState();
    _imagePath = widget.imagePath;
    _alignX = widget.initialAlignX;
    _alignY = widget.initialAlignY;
    _resolveImageSize();
    _sampleTopLuminance();
  }

  /// 只读图片头部拿原始宽高，不解码像素，进入页面无需等待整图解码。
  Future<void> _resolveImageSize() async {
    final bytes = await File(_imagePath).readAsBytes();
    if (!mounted) {
      return;
    }
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    final descriptor = await ui.ImageDescriptor.encoded(buffer);
    final width = descriptor.width;
    final height = descriptor.height;
    descriptor.dispose();
    buffer.dispose();
    if (!mounted) {
      return;
    }
    setState(() {
      _imageSize = Size(width.toDouble(), height.toDouble());
    });
  }

  /// 采样壁纸顶部亮度，决定状态栏图标与标题的对比色（与首页逻辑一致）。
  Future<void> _sampleTopLuminance() async {
    final luminance = await sampleHomePageWallpaperTopLuminance(_imagePath);
    if (!mounted || luminance == null) {
      return;
    }
    setState(() {
      _topLuminance = luminance;
    });
  }

  Future<void> _switchWallpaper() async {
    final onPickNewImage = widget.onPickNewImage;
    if (onPickNewImage == null || _switching) {
      return;
    }
    setState(() {
      _switching = true;
    });
    try {
      final nextPath = await onPickNewImage();
      if (!mounted || nextPath == null) {
        return;
      }
      setState(() {
        _imagePath = nextPath;
        // 换图后回到居中，重新选择显示区域。
        _alignX = 0;
        _alignY = 0;
        _imageSize = null;
      });
      await _resolveImageSize();
      await _sampleTopLuminance();
    } finally {
      if (mounted) {
        setState(() {
          _switching = false;
        });
      }
    }
  }

  void _exit() {
    Navigator.of(context).pop(
      WallpaperPositionPickerResult(
        path: _imagePath,
        alignX: _alignX,
        alignY: _alignY,
        confirmed: false,
      ),
    );
  }

  void _confirm() {
    Navigator.of(context).pop(
      WallpaperPositionPickerResult(
        path: _imagePath,
        alignX: _alignX,
        alignY: _alignY,
        confirmed: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final inkColor = homePageChromeForegroundForLuminance(_topLuminance);
    final statusBarIconBrightness =
        _topLuminance != null && _topLuminance! < 0.45
        ? Brightness.light
        : Brightness.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: statusBarIconBrightness,
      ),
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) {
            _exit();
          }
        },
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            fit: StackFit.expand,
            children: [
              // 壁纸铺满全屏（含状态栏区域），与首页完全一致。
              _buildPreviewArea(context),
              // 顶部操作栏悬浮在壁纸上，位于状态栏下方。
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      _HyperosHeaderTextButton(
                        label: l10n.wallpaperPositionPickerExit,
                        onPressed: _exit,
                        isCompact: true,
                        foregroundColor: inkColor,
                      ),
                      const Spacer(),
                      Flexible(
                        child: Text(
                          l10n.wallpaperPositionPickerTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: inkColor,
                          ),
                        ),
                      ),
                      const Spacer(),
                      _HyperosHeaderTextButton(
                        label: l10n.wallpaperPositionPickerDone,
                        onPressed: _confirm,
                        isCompact: true,
                        foregroundColor: inkColor,
                      ),
                    ],
                  ),
                ),
              ),
              if (widget.onPickNewImage != null)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 24 + MediaQuery.paddingOf(context).bottom,
                  child: Center(child: _buildSwitchWallpaperButton(context)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSwitchWallpaperButton(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final inkColor = homePageChromeForegroundForLuminance(_topLuminance);
    return Center(
      child: _HyperosHeaderTextButton(
        label: l10n.wallpaperPositionPickerSwitchWallpaper,
        onPressed: _switching ? null : _switchWallpaper,
        isCompact: false,
        foregroundColor: inkColor,
      ),
    );
  }

  Widget _buildPreviewArea(BuildContext context) {
    final imageSize = _imageSize;
    if (imageSize == null) {
      return Center(
        child: CircularProgressIndicator(
          color: HyperosColors.primary(context),
        ),
      );
    }
    // 视口与首页一致：全屏大小。首页壁纸以 BoxFit.cover 铺满整屏，
    // 裁剪窗口完全由屏幕尺寸决定，这里用同尺寸才能保证拖动结果一致。
    final screenSize = MediaQuery.sizeOf(context);
    final viewportSize = Size(screenSize.width, screenSize.height);
    final overflowX = wallpaperOverflowDragExtent(
      viewportSize: viewportSize,
      imageSize: imageSize,
      horizontal: true,
    );
    final overflowY = wallpaperOverflowDragExtent(
      viewportSize: viewportSize,
      imageSize: imageSize,
      horizontal: false,
    );
    return Stack(
      fit: StackFit.expand,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanUpdate: (details) {
            setState(() {
              _alignX = wallpaperAlignAfterDrag(
                previousAlign: _alignX,
                dragDelta: details.delta.dx,
                overflowExtent: overflowX,
              );
              _alignY = wallpaperAlignAfterDrag(
                previousAlign: _alignY,
                dragDelta: details.delta.dy,
                overflowExtent: overflowY,
              );
            });
          },
          child: Image(
            // 限宽解码（首页同款尺寸），避免整图解码导致的进入卡顿。
            image: ResizeImage(
              FileImage(File(_imagePath)),
              width: homePageBackdropDecodeWidth(),
            ),
            fit: BoxFit.cover,
            gaplessPlayback: true,
            alignment: Alignment(
              _alignX.clamp(-1.0, 1.0),
              _alignY.clamp(-1.0, 1.0),
            ),
          ),
        ),
      ],
    );
  }
}

/// 顶部栏的描边文字按钮，圆角与 HyperOS 按钮一致。
///
/// [isCompact] 控制更小的尺寸，用于左上角/右上角按钮。
class _HyperosHeaderTextButton extends StatelessWidget {
  const _HyperosHeaderTextButton({
    required this.label,
    required this.onPressed,
    this.isCompact = false,
    this.foregroundColor,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isCompact;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    final minHeight = isCompact ? 36.0 : HyperosMiuixButton.minHeight;
    final cornerRadius = HyperosRadius.clampCornerRadius(
      HyperosMiuixButton.cornerRadius,
      minHeight,
    );
    final borderColor = foregroundColor ?? HyperosColors.outline(context);
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor:
            foregroundColor ?? HyperosColors.primary(context),
        side: BorderSide(color: borderColor),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cornerRadius),
        ),
        minimumSize: Size(
          isCompact ? 56 : 120,
          minHeight,
        ),
        padding: EdgeInsets.symmetric(
          horizontal: isCompact ? 16 : 24,
          vertical: 4,
        ),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
      child: Text(label),
    );
  }
}
