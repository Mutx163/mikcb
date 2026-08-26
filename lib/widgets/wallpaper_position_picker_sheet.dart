import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_miuix/miuix.dart';

import '../l10n/app_localizations.dart';
import '../ui/hyperos/hyperos.dart';
import '../ui/hyperos/liquid/hyperos_liquid_glass_surface.dart';
import '../utils/home_page_background.dart';
import 'home_page_region_blur.dart' show HomePageChromeGlassFill;

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
  final coverScale = _coverScale(
    viewportSize: viewportSize,
    imageSize: imageSize,
  );
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
/// 壁纸跟随手指移动：手指向右拖动（dragDelta > 0）时壁纸内容右移，
/// 露出图片左侧，因此对齐值减小；向左拖动时对齐值增大。超出范围时
/// 钳制到 [-1, 1]。
double wallpaperAlignAfterDrag({
  required double previousAlign,
  required double dragDelta,
  required double overflowExtent,
}) {
  if (overflowExtent <= 0) {
    return 0;
  }
  final next = previousAlign - 2 * dragDelta / overflowExtent;
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
/// 三个按钮的材质跟随全局「玻璃模式」设置（液态玻璃 ↔ 高斯模糊），
/// 与首页玻璃带、弹窗保持同一条材质路径。
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

  /// 壁纸文件读取/解码失败（如设置残留了已被删除文件的旧路径）。
  bool _imageLoadFailed = false;
  bool _switching = false;
  double? _topLuminance;
  String? _luminanceSampleKey;

  @override
  void initState() {
    super.initState();
    _imagePath = widget.imagePath;
    _alignX = widget.initialAlignX;
    _alignY = widget.initialAlignY;
    _resolveImageSize();
    _scheduleTopLuminanceSample();
  }

  /// 只读图片头部拿原始宽高，不解码像素，进入页面无需等待整图解码。
  ///
  /// 文件缺失或损坏时置 [_imageLoadFailed] 显示占位，而不是让
  /// PathNotFoundException 一路抛到全局错误处理。
  Future<void> _resolveImageSize() async {
    try {
      final file = File(_imagePath);
      if (!await file.exists()) {
        if (mounted) {
          setState(() {
            _imageLoadFailed = true;
            _imageSize = null;
          });
        }
        return;
      }
      final bytes = await file.readAsBytes();
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
        _imageLoadFailed = false;
      });
    } catch (error, stackTrace) {
      // 解码失败同样降级为占位；保留日志便于定位坏图来源。
      debugPrint(
        'WallpaperPositionPicker resolve image failed: $error\n$stackTrace',
      );
      if (mounted) {
        setState(() {
          _imageLoadFailed = true;
          _imageSize = null;
        });
      }
    }
  }

  /// 采样壁纸顶部亮度，决定状态栏图标与标题的对比色（与首页逻辑一致）。
  ///
  /// The picker renders the same [BoxFit.cover] crop as the home page, so the
  /// sample must use the current viewport and alignment instead of averaging
  /// the source image's unrendered top edge.
  void _scheduleTopLuminanceSample() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _sampleTopLuminance();
      }
    });
  }

  Future<void> _sampleTopLuminance() async {
    if (!mounted) {
      return;
    }
    final viewportSize = MediaQuery.sizeOf(context);
    final key =
        '$_imagePath|${viewportSize.width}x${viewportSize.height}|'
        '$_alignX|$_alignY';
    if (_luminanceSampleKey == key) {
      return;
    }
    _luminanceSampleKey = key;
    final luminance = await sampleHomePageWallpaperTopLuminance(
      _imagePath,
      viewportSize: viewportSize,
      alignX: _alignX,
      alignY: _alignY,
    );
    if (!mounted || _luminanceSampleKey != key || luminance == null) {
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
      _scheduleTopLuminanceSample();
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
              // 必须用 Positioned 固定到顶部：StackFit.expand 会把非定位
              // 子节点拉满整个 Stack 高度，导致内部 Row 垂直居中到屏幕中间。
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
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
                          surfaceLuminance: _topLuminance,
                        ),
                        // 标题用 Expanded 独占两按钮之间的全部剩余宽度：
                        // 之前是 [Spacer][Flexible][Spacer] 三者均分剩余空间，
                        // 每份只有约 70-80px，「调整壁纸显示位置」8 个字放不下，
                        // 被 ellipsis 截成「调整壁纸...」。Expanded 让标题拿到
                        // 全部余量后仍居中（左右按钮等宽），极端字号才兜底截断。
                        Expanded(
                          child: Text(
                            l10n.wallpaperPositionPickerTitle,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: inkColor,
                            ),
                          ),
                        ),
                        _HyperosHeaderTextButton(
                          label: l10n.wallpaperPositionPickerDone,
                          onPressed: _confirm,
                          isCompact: true,
                          foregroundColor: inkColor,
                          surfaceLuminance: _topLuminance,
                        ),
                      ],
                    ),
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
        surfaceLuminance: _topLuminance,
      ),
    );
  }

  Widget _buildPreviewArea(BuildContext context) {
    final imageSize = _imageSize;
    if (imageSize == null) {
      return Center(
        // 文件缺失/损坏时显示占位图标，而不是永远转圈或抛异常。
        child: _imageLoadFailed
            ? const Icon(
                Icons.broken_image_outlined,
                size: 56,
                color: Colors.white38,
              )
            : MiuixCircularProgressIndicator(
                colors: MiuixProgressIndicatorColors(
                  foregroundColor: HyperosColors.primary(context),
                  disabledForegroundColor: HyperosColors.primary(context),
                  backgroundColor: Colors.transparent,
                ),
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
          onPanEnd: (_) => _scheduleTopLuminanceSample(),
          onPanCancel: _scheduleTopLuminanceSample,
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
            // 解码失败的兜底：保持黑底不崩帧，错误态由占位逻辑负责。
            errorBuilder: (context, error, stackTrace) {
              debugPrint('WallpaperPositionPicker preview failed: $error');
              return const SizedBox.shrink();
            },
          ),
        ),
      ],
    );
  }
}

/// 悬浮在壁纸上的玻璃按钮，圆角与 HyperOS 按钮一致。
///
/// 材质跟随全局「玻璃模式」设置（[FrostedAppearanceScope.glassMode]），
/// 判定与首页玻璃带 / 底部玻璃坞完全同一条路径：
///
/// - **液态玻璃**：[HyperosLiquidGlassSurface]（nestedTile 角色）折射材质，
///   与弹窗/首页顶部同参；文字浮在玻璃上，只叠一层极性衬底保证可读性。
/// - **经典磨砂 / 高斯模糊 / 半透明**：实时 [BackdropFilter] 高斯模糊 +
///   极性衬底（模糊强度跟随「模糊强度」滑杆）。
/// - 系统降级（无障碍/减动效/高对比）或关闭「毛玻璃效果」时：只画衬底，
///   与 [FrostedHeaderBackground] 的降级行为一致。
///
/// 衬底极性跟随 [surfaceLuminance]（壁纸顶部亮度采样），与首页玻璃带
/// [HomePageChromeGlassFill.scrimColor] 同一条规则；文字颜色仍由调用方
/// 通过 [foregroundColor]（同源采样）决定。
///
/// [isCompact] 控制更小的尺寸，用于左上角/右上角按钮。
class _HyperosHeaderTextButton extends StatelessWidget {
  const _HyperosHeaderTextButton({
    required this.label,
    required this.onPressed,
    this.isCompact = false,
    this.foregroundColor,
    this.surfaceLuminance,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isCompact;
  final Color? foregroundColor;

  /// 所在表面（壁纸预览）的顶部亮度；为 null 时按主题明暗回退极性。
  final double? surfaceLuminance;

  @override
  Widget build(BuildContext context) {
    final minHeight = isCompact ? 36.0 : HyperosMiuixButton.minHeight;
    final cornerRadius = HyperosRadius.clampCornerRadius(
      HyperosMiuixButton.cornerRadius,
      minHeight,
    );
    final radius = BorderRadius.circular(cornerRadius);
    final fgColor = foregroundColor ?? HyperosColors.primary(context);
    final borderColor = foregroundColor ?? HyperosColors.outline(context);
    final enabled = onPressed != null;
    final content = MiuixPressable(
      onPressed: onPressed,
      borderRadius: radius,
      child: Container(
        constraints: BoxConstraints(
          minWidth: isCompact ? 56 : 120,
          minHeight: minHeight,
        ),
        alignment: Alignment.center,
        padding: EdgeInsets.symmetric(
          horizontal: isCompact ? 16 : 24,
          vertical: 4,
        ),
        child: Text(
          label,
          maxLines: 1,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: enabled ? fgColor : fgColor.withValues(alpha: 0.45),
          ),
        ),
      ),
    );

    // 与首页玻璃带同一判定：backdropBlurEnabled 已包含系统降级策略
    // （LiquidGlassDegradation：无障碍/减动效/高对比时回退实底材质）。
    final appearance = FrostedAppearanceScope.of(context);
    final blurEnabled = HyperosBlurredHeader.backdropBlurEnabled(context);
    final wash = HomePageChromeGlassFill.scrimColor(
      context,
      wallpaperTopLuminance: surfaceLuminance,
    );

    // 「液态玻璃作用范围 → 壁纸选点按钮」关闭时回退磨砂材质。
    if (blurEnabled &&
        appearance.glassMode == FrostedGlassMode.liquidGlass &&
        appearance.liquidGlassPickerButtonsEnabled) {
      // 液态玻璃：折射 shader 与弹窗/首页顶部完全同参。液态玻璃自带
      // 边缘高光，不再叠加描边；衬底压在玻璃上保证文字对比度
      // （与课程玻璃卡片叠课程色 tint 同一做法）。
      return HyperosLiquidGlassSurface(
        role: HyperosLiquidGlassRole.nestedTile,
        borderRadius: cornerRadius,
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            Positioned.fill(
              child: IgnorePointer(child: ColoredBox(color: wash)),
            ),
            content,
          ],
        ),
      );
    }

    // 高斯模糊路径（经典磨砂/高斯模糊/半透明共用）：模糊强度跟随设置；
    // 关闭模糊或系统降级时 FrostedHeaderBackground 自动只画衬底。
    // 描边保留，保证纯衬底状态下按钮轮廓仍然可辨。
    return ClipRRect(
      borderRadius: radius,
      child: FrostedHeaderBackground(
        blurEnabled: blurEnabled,
        blurSigma: appearance.sheetBlurSigma,
        tint: wash,
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: radius,
                  border: Border.all(color: borderColor),
                ),
              ),
            ),
            content,
          ],
        ),
      ),
    );
  }
}
