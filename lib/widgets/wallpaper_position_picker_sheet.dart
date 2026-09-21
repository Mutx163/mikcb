import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_miuix/miuix.dart';

import '../l10n/app_localizations.dart';
import '../ui/hyperos/hyperos.dart';
import '../ui/hyperos/liquid/liquid_glass_surface.dart';
import '../utils/home_page_background.dart';
import '../utils/home_startup_visual_primer.dart';
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
    this.scale = 1,
    required this.confirmed,
  });

  final String path;
  final double alignX;
  final double alignY;

  /// 用户选定的放大倍数（1 = 刚好铺满；上下限见 `kWallpaperMinScale` /
  /// `kWallpaperMaxScale`）。
  final double scale;

  final bool confirmed;
}

/// 以 BoxFit.cover 布局、并叠加用户放大倍数 [scale] 后，图片沿指定轴相对视口
/// 溢出的逻辑像素量。
///
/// 这个值同时就是「对齐值从 -1 扫到 +1 时，图片在屏幕上真正走过的距离」——拖动
/// 映射的分母（见 [wallpaperAlignAfterDrag]），也就是「拖多少才能走完全程」。
///
/// ⚠️ **不是「基础溢出 × 倍数」**：缩放是绕**对齐点**做的，视口那一份不跟着放大
/// （见 `homePageBackdropImageWidget`），所以放大 s 倍后的真实溢出是
/// `s × 封面尺寸 − 视口尺寸` = `s × 基础溢出 + (s−1) × 视口`，比「基础溢出 × s」
/// 更大。分母取小了，同一段手指位移换来的对齐变化就更大 —— 内容跑得比手指快，
/// 真机口径正是「放大后拖一点就飞了」（2026-09-21）。
///
/// 图片在该轴不溢出（例如横向壁纸在垂直方向）时返回 0。
double wallpaperOverflowDragExtent({
  required Size viewportSize,
  required Size imageSize,
  required bool horizontal,
  double scale = 1,
}) {
  final coverScale = _coverScale(
    viewportSize: viewportSize,
    imageSize: imageSize,
  );
  final fittedWidth = imageSize.width * coverScale * scale;
  final fittedHeight = imageSize.height * coverScale * scale;
  final overflow = horizontal
      ? fittedWidth - viewportSize.width
      : fittedHeight - viewportSize.height;
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
///
/// [overflowExtent] 必须是**当前倍数下**的溢出量（[wallpaperOverflowDragExtent]
/// 的 `scale` 参数），这样「内容跟着手指走」在任意倍数下都是 1:1。
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
/// [initialAlignX] / [initialAlignY] / [initialScale] 为进入时已保存的取景；
/// 传入 [onPickNewImage] 时页面底部会显示「换壁纸」按钮，用于从相册重新选择
/// 图片。
Future<WallpaperPositionPickerResult?> pushWallpaperPositionPickerPage(
  BuildContext context, {
  required String imagePath,
  required double initialAlignX,
  required double initialAlignY,
  double initialScale = 1,
  Future<String?> Function()? onPickNewImage,
}) {
  return HyperosNavigation.push<WallpaperPositionPickerResult>(
    context,
    builder: (_) => WallpaperPositionPickerPage(
      imagePath: imagePath,
      initialAlignX: initialAlignX,
      initialAlignY: initialAlignY,
      initialScale: initialScale,
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
    this.initialScale = 1,
    this.onPickNewImage,
  });

  final String imagePath;
  final double initialAlignX;
  final double initialAlignY;

  /// 进入时的放大倍数（1 = 刚好铺满）。
  final double initialScale;

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
  late double _scale;

  /// 本次缩放手势开始时的倍数基准：`ScaleUpdateDetails.scale` 是**相对本手势
  /// 起点**的倍率，不能直接当绝对倍数用。
  double _scaleAtGestureStart = 1;

  Size? _imageSize;

  /// 壁纸文件读取/解码失败（如设置残留了已被删除文件的旧路径）。
  bool _imageLoadFailed = false;
  bool _switching = false;
  double? _topLuminance;
  String? _luminanceSampleKey;

  /// 诊断时间线（定位玻璃闪变用；问题收敛后可整块删）。
  ///
  /// 每条带 `[wpp-glass]` 前缀，方便从 `flutter_0*.log` / `flutter run` 输出里
  /// grep；消息是英文的（CJK 硬编码审计按行计数，日志串不该加进去）。
  /// 定时器要在 [dispose] 里取消：widget 测试结束时留着 pending timer 会直接失败。
  ///
  /// ⚠️ 2026-09-21 起四颗按钮锁标准档**实时**折射（不吃快照），所以本页自己的
  /// `zones` 常态是 0 —— 这条时间线现在只在「本页之上弹了吃快照的 modal」时才有读数。
  static const String _traceTag = '[wpp-glass]';
  final Stopwatch _traceClock = Stopwatch();
  final List<Timer> _traceTimers = <Timer>[];
  bool _tracedPreviewFrame = false;

  /// 这条诊断最多轮询多少帧。
  ///
  /// 图永远不来（模糊总开关关闭时本屏根本没有采样区）时必须有上界，否则整页生命
  /// 周期里每帧都排一次回调。120 帧 ≈ 2s，够覆盖真机上首帧偏慢的那一段。
  static const int _traceMaterialPollFrames = 120;

  /// 第一张采样图落地的时刻是否已经打过（只诊断，不门控绘制）。
  ///
  /// 这个时点是「悬浮玻璃按钮能不能在**首帧**就画成玻璃」的唯一判据：吃快照的玻璃在
  /// paint 里读快照，采样宿主必须同帧先写完（见 `HyperosGlassBackdropCapture.paint`
  /// 里"首次采样必须本帧完成"那段）。修好之前真机实测是 +81~134ms —— 按钮先是
  /// 一块平的、再变玻璃；修好之后应当落在首帧（+0~20ms）。
  bool _tracedMaterialReady = false;

  /// 本页自己的屏级玻璃采样源。
  ///
  /// 这一页是裸 `Scaffold`，不是 [HyperosPage]，**没有宿主**。它的存在有两条理由：
  ///
  /// 1. **给本页之上的 modal 用**：宿主会把自己注册进
  ///    [HyperosGlassBackdropRegistry]，弹在本页之上的 sheet / dialog 取到的才是
  ///    **本页**画面；缺了它，注册表会回落到压在下面的设置页（路由仍挂载，且已被
  ///    视差左移，被盖住后连 paint 都停了），采样带录的就是**别屏**的画面。
  /// 2. 本页自己那层玻璃（四颗悬浮按钮）**不再需要它**：2026-09-21 起它们锁标准档
  ///    实时折射（`LiquidGlassRole.pinnedChrome`），不读任何快照。历史现象（真机
  ///    「按钮左半边灰、右半边透出壁纸」）就是当年柔光玻璃按注册表取到别屏采样源
  ///    造成的（快照盖住的那半边显示"模糊后的设置页"，盖不到的那半边上游直接画透明）。
  ///
  /// 与首页同一个口径：**本屏的玻璃只采本屏的画面**（同族记录见
  /// `timetable_screen.dart` 的 `_wrapHomeWithTopMenu`）。
  final HyperosGlassBackdropController _glass =
      HyperosGlassBackdropController();

  @override
  void dispose() {
    // 退出这一侧也要留一条：闪变发生在采样落地那一刻，而"落地"是相对进页算的，
    // 有这条才能与进页时间对齐、判断闪的是进还是出。
    _traceGlass('dispose');
    for (final timer in _traceTimers) {
      timer.cancel();
    }
    _traceTimers.clear();
    // 顺序安全：子节点先 unmount（捕获节点在自己的 detach/dispose 里摘掉监听与
    // 登记），本 State 的 dispose 在最后跑，此时才轮到释放控制器。
    _glass.dispose();
    super.dispose();
  }

  /// 打一条玻璃诊断时间线：亮度 / 墨色极性 / 各采样区有没有图、图多大、原点在哪。
  ///
  /// 进页后光看"有没有闪"说不清是哪一层：极性翻转、采样带迟到、覆盖不全都会表现为
  /// 观感变化，而这三件事在上面的字段里是可分辨的。
  void _traceGlass(String event) {
    final zones = _glass.zones;
    final images = zones
        .map(
          (zone) => zone.image == null
              ? 'none'
              : '${zone.image!.width}x${zone.image!.height}',
        )
        .join('|');
    final origins = zones.map((zone) => zone.origin).join('|');
    final ink = homePageChromeForegroundForLuminance(_topLuminance);
    debugPrint(
      '$_traceTag +${_traceClock.elapsedMilliseconds}ms $event '
      'lum=${_topLuminance?.toStringAsFixed(3) ?? 'null'} '
      'ink=0x${ink.toARGB32().toRadixString(16)} '
      'bg=${_tracedPreviewFrame ? 'wallpaper' : 'placeholder'} '
      'zones=${zones.length} images=[$images] origins=[$origins]',
    );
  }

  /// 打一条"第一张采样图落地"的时间线（见 [_tracedMaterialReady]）。
  ///
  /// 每帧查一次而不是听控制器：材质是写进"区"里的，控制器只在有人要录帧时通知，
  /// 图到了不会额外通知页面。按帧查的代价可忽略，且落地一次就停。
  void _traceMaterialLanding({int frames = 0}) {
    if (_tracedMaterialReady || frames > _traceMaterialPollFrames) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _tracedMaterialReady) {
        return;
      }
      if (_glass.zones.any((zone) => zone.image != null)) {
        _tracedMaterialReady = true;
        _traceGlass('first snapshot -> buttons paint as glass');
        return;
      }
      _traceMaterialLanding(frames: frames + 1);
    });
  }

  @override
  void initState() {
    super.initState();
    _imagePath = widget.imagePath;
    _alignX = widget.initialAlignX;
    _alignY = widget.initialAlignY;
    _scale = widget.initialScale.clamp(kWallpaperMinScale, kWallpaperMaxScale);
    // 首帧极性直接用启动期预热好的亮度带（与首页首帧同一条口径，
    // `HomeStartupVisualPrimer` 的注释里就叫它"消除墨色极性闪变"）。
    //
    // 不这么做的话：亮度只能异步采样（要解码一次壁纸），落地前按主题明暗猜一个
    // 极性、落地后再修正 —— 那次修正就是真机反馈"进 / 出页面闪一下"（浅色实底
    // → 玻璃，见 [SoftGlassPolarityFade]）。预热是按居中采样的，拖动过壁纸时这里
    // 可能与实际不符，随后的精确采样会带着渐变平滑纠正。
    _topLuminance = HomeStartupVisualPrimer.seededBandsFor(_imagePath)?.top;
    _resolveImageSize();
    _scheduleTopLuminanceSample();

    // 诊断时间线：进页后的几个关键时点各打一条（都带 `[wpp-glass]` 前缀）。
    _traceClock.start();
    _traceGlass(
      'init seeded=${_topLuminance != null} '
      'align=${_alignX.toStringAsFixed(2)},${_alignY.toStringAsFixed(2)} '
      'scale=${_scale.toStringAsFixed(2)}',
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _traceGlass('frame1');
      }
    });
    _traceMaterialLanding();
    for (final ms in const <int>[32, 64, 120, 400, 900]) {
      _traceTimers.add(
        Timer(Duration(milliseconds: ms), () {
          if (mounted) {
            _traceGlass('t+${ms}ms');
          }
        }),
      );
    }
  }

  /// 只读图片头部拿原始宽高，不解码像素，进入页面无需等待整图解码。
  ///
  /// 文件缺失或损坏时置 [_imageLoadFailed] 显示占位，而不是让
  /// PathNotFoundException 一路抛到全局错误处理。
  Future<void> _resolveImageSize() async {
    try {
      final file = File(_imagePath);
      if (!file.existsSync()) {
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
      _traceGlass('size=${width}x$height');
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
        '$_alignX|$_alignY|$_scale';
    if (_luminanceSampleKey == key) {
      return;
    }
    _luminanceSampleKey = key;
    final luminance = await sampleHomePageWallpaperTopLuminance(
      _imagePath,
      viewportSize: viewportSize,
      alignX: _alignX,
      alignY: _alignY,
      scale: _scale,
    );
    if (!mounted || _luminanceSampleKey != key || luminance == null) {
      _traceGlass('sample dropped (luminance=$luminance)');
      return;
    }
    // 与预热 / 上一次采样一致时不必重画，也不该触发一次极性渐变。
    if (_topLuminance == luminance) {
      _traceGlass('sample=$luminance unchanged');
      return;
    }
    _traceGlass('sample=$luminance PREV=${_topLuminance?.toStringAsFixed(3)}');
    setState(() {
      _topLuminance = luminance;
    });
    _traceGlass('polarity applied');
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
        // 换图后回到「居中 + 原大小」，重新选择显示区域。
        _alignX = 0;
        _alignY = 0;
        _scale = 1;
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

  /// 重置取景：回到「居中 + 原大小」。位置与缩放一起归位 —— 用户按的是"重置"，
  /// 只重置一半会得到既不是默认、也不是自己刚调的那一版的第三种取景。
  void _resetFraming() {
    if (_alignX == 0 && _alignY == 0 && _scale == 1) {
      return;
    }
    setState(() {
      _alignX = 0;
      _alignY = 0;
      _scale = 1;
    });
    _scheduleTopLuminanceSample();
  }

  void _exit() {
    Navigator.of(context).pop(
      WallpaperPositionPickerResult(
        path: _imagePath,
        alignX: _alignX,
        alignY: _alignY,
        scale: _scale,
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
        scale: _scale,
        confirmed: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final inkColor = homePageChromeForegroundForLuminance(_topLuminance);
    // 衬底与墨色同源（都是"壁纸顶部亮度"），到按钮那一层只传算好的颜色 ——
    // 这样 [SoftGlassPolarityFade] 给出的渐变中间值才能一路传下去。
    final washColor = HomePageChromeGlassFill.scrimColor(
      context,
      wallpaperTopLuminance: _topLuminance,
    );
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
              // 捕获节点只包这一层：本页玻璃采样对象就是它，且**不含玻璃自身**
              // （上游要求，否则玻璃会把自己上一帧的合成结果采进去）。
              HyperosGlassBackdropHost(
                controller: _glass,
                child: _buildPreviewArea(context),
              ),
              // 悬浮玻璃按钮层：画在捕获子树**之外**、显式钉在本页采样源上
              // （见 [_buildOverlayLayer]），外面套一层极性渐变 —— 衬底与墨色要等
              // 壁纸顶部亮度**异步采样**落地才能定，落地前只能按主题猜；直接切换
              // 就是真机反馈的"进 / 出页面闪一下"（浅色实底 → 玻璃）。
              //
              // 不要再"等材质就绪再淡入"：那只是把"先冒一块平的"换成"按钮迟到
              // 半秒才淡进来"，慢放下同样是一下跳。首帧就画成玻璃的正确做法是让采样
              // 宿主**同帧**先写完快照（见 `HyperosGlassBackdropCapture.paint`）。
              SoftGlassPolarityFade(
                ink: inkColor,
                wash: washColor,
                builder: _buildOverlayLayer,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 悬浮玻璃按钮层（顶部操作栏 + 底部「换壁纸」）。
  ///
  /// 两个约束都不能少：
  ///
  /// 1. 画在 `HyperosGlassBackdropHost` 的捕获子树**之外** —— 上游要求玻璃不能被
  ///    自己的采样捕获，否则会把上一帧的合成结果采进去（自我叠加）。
  /// 2. 显式用 [HyperosGlassBackdropScope] 钉在本页采样源上：这一层里将来只要有
  ///    吃快照的玻璃面，就不能靠全局注册表的"栈顶"取源（被压住的路由仍然挂载，
  ///    栈顶会指向别的屏，见 [_glass]）。
  ///
  /// 本页自己的四颗按钮走**实时**折射（锁标准档），不吃快照，所以上面第 2 条对它们
  /// 是空转；留着是这一层玻璃的取源规矩。
  ///
  /// [ink] / [wash] 由 [SoftGlassPolarityFade] 传入，可能是极性渐变中的中间值。
  Widget _buildOverlayLayer(BuildContext context, Color ink, Color wash) {
    final l10n = AppLocalizations.of(context)!;
    return HyperosGlassBackdropScope(
      controller: _glass,
      child: Stack(
        fit: StackFit.expand,
        children: [
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
                      foregroundColor: ink,
                      wash: wash,
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
                          color: ink,
                        ),
                      ),
                    ),
                    _HyperosHeaderTextButton(
                      label: l10n.wallpaperPositionPickerDone,
                      onPressed: _confirm,
                      isCompact: true,
                      foregroundColor: ink,
                      wash: wash,
                    ),
                  ],
                ),
              ),
            ),
          ),
          // 底部一排：「重置」＋「换壁纸」（这颗页面没有换图能力时只留重置）。
          //
          // 「重置」把**位置与缩放一起**归位（用户 2026-09-20 要的：加了双指缩放
          // 之后得有个一键回到默认取景的出口）。文案 key 历史上叫
          // `...ResetTooltip`（当年是个没接上的 tooltip），现在是这颗按钮的标签。
          Positioned(
            left: 0,
            right: 0,
            bottom: 24 + MediaQuery.paddingOf(context).bottom,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _HyperosHeaderTextButton(
                  label: l10n.wallpaperPositionPickerResetTooltip,
                  onPressed: _resetFraming,
                  foregroundColor: ink,
                  wash: wash,
                ),
                if (widget.onPickNewImage != null) ...[
                  const SizedBox(width: 12),
                  _buildSwitchWallpaperButton(context, ink: ink, wash: wash),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 底部「换壁纸」按钮。极性由调用方（[SoftGlassPolarityFade] 的渐变值）给。
  Widget _buildSwitchWallpaperButton(
    BuildContext context, {
    required Color ink,
    required Color wash,
  }) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: _HyperosHeaderTextButton(
        label: l10n.wallpaperPositionPickerSwitchWallpaper,
        onPressed: _switching ? null : _switchWallpaper,
        foregroundColor: ink,
        wash: wash,
      ),
    );
  }

  Widget _buildPreviewArea(BuildContext context) {
    // 文件缺失/损坏：占位图标，而不是永远转圈或抛异常。
    if (_imageLoadFailed) {
      return const Center(
        child: Icon(
          Icons.broken_image_outlined,
          size: 56,
          color: Colors.white38,
        ),
      );
    }
    // 视口与首页一致：全屏大小。首页壁纸以 BoxFit.cover 铺满整屏，
    // 裁剪窗口完全由屏幕尺寸决定，这里用同尺寸才能保证拖动结果一致。
    final imageSize = _imageSize;
    final screenSize = MediaQuery.sizeOf(context);
    final viewportSize = Size(screenSize.width, screenSize.height);
    // 拖动范围要等图片尺寸才知道；尺寸没到之前拖动是空操作
    // （`wallpaperAlignAfterDrag(overflowExtent: 0)` 恒返回 0，不会跳）。
    //
    // 按**当前倍数**现算（缩放与拖动在同一个手势里，倍数随时在变，溢出量跟着变）：
    // 现算出来的才是「手指走多远、内容就走多远」的那一份（见
    // [wallpaperOverflowDragExtent] 里为什么不是「基础溢出 × 倍数」）。
    double dragOverflow(bool horizontal, double scale) {
      if (imageSize == null) {
        return 0;
      }
      return wallpaperOverflowDragExtent(
        viewportSize: viewportSize,
        imageSize: imageSize,
        horizontal: horizontal,
        scale: scale,
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // ⚠️ `Image` 必须**第一帧就建**，不能挡在"尺寸已知"后面：读尺寸 + 解码
        // 要几十到几百毫秒，挡住就是白白多黑 1~4 帧（真机日志 `[wpp-glass] size=`
        // 之前正是这个窗口），玻璃采到的那条带也跟着是"黑底 + 转圈"。
        // 壁纸通常已在缓存里（启动预热 + 首页显示过，同款
        // `ResizeImage(FileImage, width: homePageBackdropDecodeWidth())`），
        // 命中时第一帧就有像素；没命中则由 `frameBuilder` 兜一层转圈。
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          // 单指拖动与双指缩放走**同一个** scale 手势：单指时倍率恒为 1、
          // `focalPointDelta` 就是拖动位移；双指时两者一起给（捏合时也能挪）。
          onScaleStart: (_) {
            _scaleAtGestureStart = _scale;
          },
          onScaleUpdate: (details) {
            final nextScale = (_scaleAtGestureStart * details.scale).clamp(
              kWallpaperMinScale,
              kWallpaperMaxScale,
            );
            setState(() {
              _scale = nextScale;
              // 拖动位移按**当前倍数下的真实溢出**折算：内容与手指始终 1:1。
              // 曾经用「基础溢出 × 倍数」当分母，分母偏小 ⇒ 放大后内容跑得比
              // 手指快（真机口径「拖一点就飞了」）。
              _alignX = wallpaperAlignAfterDrag(
                previousAlign: _alignX,
                dragDelta: details.focalPointDelta.dx,
                overflowExtent: dragOverflow(true, nextScale),
              );
              _alignY = wallpaperAlignAfterDrag(
                previousAlign: _alignY,
                dragDelta: details.focalPointDelta.dy,
                overflowExtent: dragOverflow(false, nextScale),
              );
            });
          },
          onScaleEnd: (_) => _scheduleTopLuminanceSample(),
          // 缩放与首页同一套几何：`cover` 先按对齐值选好显示段，这里绕**对齐点**
          // 把这段整体放大（`Transform.scale(alignment:)`，对齐点不动）——
          // 与 `homePageBackdropImageWidget` 同源，编辑页看到的取景就是首页的。
          child: Transform.scale(
            scale: _scale,
            alignment: Alignment(
              _alignX.clamp(-1.0, 1.0),
              _alignY.clamp(-1.0, 1.0),
            ),
            child: Image(
              // 限宽解码（首页同款尺寸），避免整图解码导致的进入卡顿。
              image: ResizeImage(
                FileImage(File(_imagePath)),
                width: homePageBackdropDecodeWidth(),
              ),
              fit: BoxFit.cover,
              gaplessPlayback: true,
              // 诊断 + 兜底：壁纸第一帧什么时候真的画出来（在那之前玻璃采到的是一条
              // "黑底 + 转圈占位"的带）。`frame == null` 时在下面垫一层转圈 ——
              // `Image` 本身可以第一帧就建（见上面的说明），但解码没完时页面会是纯黑。
              frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                if (frame == null) {
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      Center(
                        child: MiuixCircularProgressIndicator(
                          colors: MiuixProgressIndicatorColors(
                            foregroundColor: HyperosColors.primary(context),
                            disabledForegroundColor: HyperosColors.primary(context),
                            backgroundColor: Colors.transparent,
                          ),
                        ),
                      ),
                      child,
                    ],
                  );
                }
                if (!_tracedPreviewFrame) {
                  _tracedPreviewFrame = true;
                  _traceGlass(
                    'preview frame=$frame sync=$wasSynchronouslyLoaded',
                  );
                }
                return child;
              },
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
        ),
      ],
    );
  }
}

/// 悬浮在壁纸上的玻璃按钮，圆角与 HyperOS 按钮一致。
///
/// 材质**锁液态玻璃的标准档**（[LiquidGlassRole.pinnedChrome]），与设置页左上角
/// 返回键 [HyperosBackButton] 同一档（用户 2026-09-21 口径「这个应该和设置界面
/// 左上角返回键保持强制同材质」）：全局材质档位（柔光 / 高斯 / 实体）、模糊总开关、
/// 自定义滑杆都不参与 —— 这一页是裸壁纸背景，这几颗按钮的观感必须与其他固定小件
/// 一致，而不是跟着用户档位变成另一种玻璃。
///
/// 只剩技术 / 系统门禁（[LiquidGlassSurface.isAvailable]）会把它摘下来，那时：
///
/// - 只是画不出折射（没有 shader 后端，如桌面 / 测试环境）：仍是**实时磨砂玻璃**
///   （模糊强度跟随「模糊强度」滑杆；关闭模糊或系统降级时
///   [FrostedHeaderBackground] 自动只画衬底），与弹层族的回落口径一致；
/// - 采不到背景（平台视图上方 / 系统无障碍降级）：实体卡片，不再透明。
///
/// 衬底与墨色都由调用方给（同源于壁纸顶部亮度采样，与首页玻璃带
/// [HomePageChromeGlassFill.scrimColor] 同一条规则）—— 由
/// [SoftGlassPolarityFade] 传进来，可能是极性渐变中的中间值。这里不再自己按亮度
/// 现算：那样极性一变就是一次跳变（真机反馈的"进 / 出页面闪一下"）。
///
/// [isCompact] 控制更小的尺寸，用于左上角/右上角按钮。
class _HyperosHeaderTextButton extends StatelessWidget {
  const _HyperosHeaderTextButton({
    required this.label,
    required this.onPressed,
    required this.wash,
    this.isCompact = false,
    this.foregroundColor,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isCompact;
  final Color? foregroundColor;

  /// 衬底色（压在玻璃上的可读性水洗），由调用方按壁纸亮度算好。
  final Color wash;

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
      // ⚠️ [IntrinsicWidth] 不能省：`Container` 一旦带 `alignment`，在**有界**
      // 约束下会撑满可用宽度（`Align` 的行为），`minWidth` 只是下限、管不住上限。
      // 底部「换壁纸」的父级是 `Positioned(left: 0, right: 0)`，于是这个盒子拿到
      // 的 maxWidth 就是整屏宽 → 玻璃形状被拉成一条横贯整屏的长条（顺带整条底边
      // 都变成它的点击区）。顶部两个在 `Row` 里拿到的是无界约束，回退到内容宽度，
      // 所以只有底部能看出来。
      //
      // `IntrinsicWidth` 让它回到「minWidth 与文字实际宽度取大」：文字仍由
      // `Container.alignment` 居中（所以两个入参都要保留）。
      child: IntrinsicWidth(
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
      ),
    );

    // 与首页玻璃带同一判定：backdropBlurEnabled 已包含系统降级策略
    // （LiquidGlassDegradation：无障碍/减动效/高对比时回退实底材质）。
    final appearance = FrostedAppearanceScope.of(context);
    final blurEnabled = HyperosBlurredHeader.backdropBlurEnabled(context);

    // 画不出折射时的回落：仍是**实时磨砂玻璃**（模糊强度跟随设置；关闭模糊或系统
    // 降级时 FrostedHeaderBackground 自动只画衬底）。描边保留，纯衬底状态下按钮
    // 轮廓仍然可辨 —— 这一页背景是整张壁纸，没有顶栏那条实底带可垫，所以不能像
    // 返回键那样直接退成一块实色。
    Widget frostButton() => ClipRRect(
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

    // 液态玻璃：折射 shader 与弹窗/首页顶部完全同参，档位锁标准档
    // （[LiquidGlassRole.pinnedChrome]，见类注释）。
    return LiquidGlassSurface(
      borderRadius: cornerRadius,
      role: LiquidGlassRole.pinnedChrome,
      // 同屏可能有多颗悬浮玻璃按钮：进祖先 BackdropGroup 的共享捕获点，
      // 避免后画的那颗把先画的那颗玻璃折射进去。本页没有祖先组时退化为
      // 普通实时采样。
      grouped: true,
      // 剩下两档门禁的落点（与弹层族同一条口径）：采不到背景 → 实体卡片；
      // 只是画不出折射 → 仍是磨砂玻璃观感。
      fallbackBuilder: (fallbackContext) =>
          LiquidGlassDegradation.shouldDegrade(fallbackContext)
          ? Material(
              color: HyperosColors.surfaceContainer(fallbackContext),
              borderRadius: radius,
              clipBehavior: Clip.antiAlias,
              child: content,
            )
          : frostButton(),
      // 液态玻璃自带边缘高光，不再叠加描边；衬底压在玻璃上保证文字对比度
      // （与课程玻璃卡片叠课程色 tint 同一做法）。
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
}
