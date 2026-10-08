// 本文件由 course_import_screen.dart 拆分而来（2026-10-06）。
// 适配器网页登录页
// 内嵌 WebView 完成教务登录并把账号状态回传。
// 拆分只搬移代码、不改逻辑；符号可见性与 import 由拆分统一补齐。

import '../../../l10n/service_message_localizer.dart';
import '../../../logging/app_debug_log.dart';
import 'dart:async';
import 'package:university_timetable/ui/hyperos/hyperos.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import '../../../models/course.dart';
import '../../../models/location_time_group.dart';
import '../../../models/time_scheme.dart';
import '../../../models/timetable_settings.dart';
import '../../../models/warehouse_macro_models.dart';
import '../../../models/warehouse_repository_models.dart';
import '../../../providers/timetable_provider.dart';
import '../../../domain/warehouse_course_import_logic.dart';
import '../../../domain/warehouse_location_time_schemes.dart';
import '../../../domain/warehouse_macro_dialog_replay.dart';
import '../../../domain/warehouse_session_probe.dart';
import '../../../services/import_time_scheme_restore_point.dart';
import '../../../services/import_week_alignment_service.dart';
import '../../../services/warehouse_bridge_compat.dart';
import '../../../services/warehouse_import_preferences_service.dart';
import '../../../services/warehouse_import_session_log.dart';
import '../../../services/warehouse_macro_service.dart';
import '../../../services/warehouse_repository_service.dart';
import '../../../utils/app_toast.dart';
import '../../../widgets/app_dialogs.dart';
import '../../../widgets/warehouse_macro_recorder.dart';
import '../../../widgets/warehouse_macro_replayer.dart';
import '../../../widgets/warehouse_playback_overlay.dart';
import '../import_shared.dart';
import 'warehouse_shared.dart';
import 'warehouse_import_policy.dart';

class WarehouseAdapterWebLoginScreen extends StatefulWidget {
  final String title;
  final String initialUrl;
  final WarehouseRepositorySource source;
  final WarehouseSchoolEntry school;
  final WarehouseAdapterEntry adapter;
  final WarehouseFetchOptions fetchOptions;
  final String? debugScriptOverride;
  final String? debugScriptName;
  final WarehouseMacroRecord? macroRecord;
  final bool autoRecord;

  /// When true, the WebView runs off-screen and UI chrome is hidden. Used by
  /// home pull-to-refresh quick import so the page never appears.
  final bool runInBackground;

  /// Called when background playback needs user input (captcha / password).
  final VoidCallback? onBackgroundNeedsManualAction;

  /// Called when background import finishes (success or failure).
  final ValueChanged<bool>? onBackgroundFinished;

  /// Reports that the background import is still making progress.
  final VoidCallback? onBackgroundProgress;

  /// Background session cancellation probe. The host uses this to stop before
  /// the irreversible timetable write starts.
  final bool Function()? isBackgroundImportCancelled;

  /// Marks the point where the host's timetable write has become irreversible.
  final VoidCallback? onBackgroundImportStarted;

  const WarehouseAdapterWebLoginScreen({
    super.key,
    required this.title,
    required this.initialUrl,
    required this.source,
    required this.school,
    required this.adapter,
    required this.fetchOptions,
    this.debugScriptOverride,
    this.debugScriptName,
    this.macroRecord,
    this.autoRecord = false,
    this.runInBackground = false,
    this.onBackgroundNeedsManualAction,
    this.onBackgroundFinished,
    this.onBackgroundProgress,
    this.isBackgroundImportCancelled,
    this.onBackgroundImportStarted,
  });

  @override
  State<WarehouseAdapterWebLoginScreen> createState() =>
      _WarehouseAdapterWebLoginScreenState();
}

class _WarehouseAdapterWebLoginScreenState
    extends State<WarehouseAdapterWebLoginScreen> {
  static const String _desktopUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';
  static const String _mobileUserAgent =
      'Mozilla/5.0 (Linux; Android 14; 25060RK16C) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/131.0.0.0 Mobile Safari/537.36';

  final WarehouseRepositoryService _repositoryService =
      WarehouseRepositoryService();
  final WarehouseImportPreferencesService _preferencesService =
      WarehouseImportPreferencesService();
  final ImportWeekAlignmentService _weekAlignmentService =
      const ImportWeekAlignmentService();
  late final WebViewController _controller;
  late final TextEditingController _addressController;
  final FocusNode _addressFocusNode = FocusNode();
  final GlobalKey _webLoginMoreMenuKey = GlobalKey();

  /// 教务登录页「更多」菜单（上游 OS4 玻璃弹层，常驻挂载）。2026-09-28 从
  /// `showHyperosListPopup`（手搓旧实现）迁来。
  bool _webLoginMenuVisible = false;

  /// 锚点窗口坐标 + 冻结的条目，收起后**保留**到退场结束。条目冻结是必须的：
  /// 「填入 / 清除」两行的禁用态依赖 [_rememberedLogin]，现算的话它一变，
  /// 退场中的菜单会当场改内容。
  Rect? _webLoginMenuAnchorBounds;
  List<HyperosAnchorMenuEntry> _webLoginMenuEntries = const [];
  int _loadingProgress = 0;
  String? _currentUrl;
  bool _isExecutingImport = false;
  Timer? _importTimeoutTimer;
  static const _importTimeout = Duration(seconds: 30);
  String? _lastScriptStatus;
  /// 本次导入里没能进来的课程记录（按原因计数），用于如实告诉用户少了课，
  /// 而不是让它们无声消失。见 [WarehouseCourseSkipReason]。
  final Map<WarehouseCourseSkipReason, int> _warehouseCourseSkips = {};
  List<SectionTime>? _pendingImportedSections;

  /// 脚本通过 `savePresetTimeSlots` 下发的那套作息（apply 之后仍保留）。
  ///
  /// 轻屿专属条目用它反推用户选了哪一套：脚本在「选择学校作息时间表」里给的是
  /// 节次时间，数据文件里也是节次时间，两边逐节相同即同一个方案。这样专属条目
  /// **不额外问一句**，复用脚本已经问过的那一次——两个问题问同一个用户是本轮
  /// 方案设计里明确要避开的。
  List<SectionTime>? _scriptSuppliedSections;  String? _pendingImportedSectionsSignature;
  String? _appliedImportedSectionsSignature;
  Future<void>? _pendingImportedSectionsApplyFuture;
  WarehouseRememberedLogin? _rememberedLogin;
  WarehouseRememberedLogin? _latestLoginCandidate;
  bool _hasPromptedAutofill = false;
  bool _hasPromptedSave = false;
  bool _isPromptShowing = false;
  String? _lastLoginStateDecisionKey;
  bool _useDesktopMode = true;

  // --- 教务会话探针（qingyu_only/<学校>/session_probe.json）---
  //
  // 目的：让 App 说出「其实还登录着」。强智一类系统的登录页不看会话，无条件返回
  // 登录表单，光看页面永远只能得出「请登录」这个错误结论；而适配脚本抓课表用的
  // 是带 Cookie 的 fetch，会话还在就照样抓得到。探针把这件事提前问出来。
  //
  // 三条自律：
  // 1. **不自动跳转**。判错了把人从登录页踹走比让人多登一次糟得多，跳不跳交给用户。
  // 2. **判不出来就闭嘴**。取不到配置 / 网络失败 / 被跨源重定向一律 unavailable，
  //    行为与今天完全一致（200+ 所没配这个文件）。
  // 3. **不多打请求**。每次开页最多探一次，换站才重探，同站翻页不再探。
  WarehouseSessionProbeConfig? _sessionProbeConfig;
  WarehouseSessionProbeVerdict _sessionProbeVerdict =
      WarehouseSessionProbeVerdict.unknown;
  String? _sessionProbeOrigin;
  bool _sessionProbeInFlight = false;
  DateTime? _sessionProbeLastAttemptAt;
  Timer? _sessionProbeTimer;

  /// 两次探活之间的最小间隔。探活是**自动发起**的请求，学校站点有限流/验证码的
  /// 可能性存在，失败重试也不能连着打。
  static const Duration _sessionProbeCooldown = Duration(seconds: 20);

  /// 等页面回话的上限。超时后不算「没登录」，只算这次没探成（见 [_maybeRunSessionProbe]）。
  static const Duration _sessionProbeTimeout = Duration(seconds: 12);

  /// 探针在途时被推迟的「要不要帮你填密码」决定（最近一条 loginState 消息）。
  ///
  /// 探针出结论（或 12s 超时）时补判；页销毁即弃。只留最新一条——探针在途
  /// 期间 MutationObserver 可能连发多条，旧的那条没有判的价值。
  Map<String, dynamic>? _pendingAutofillLoginState;

  /// 后台导入是否已经进入不可安全取消的写入阶段。
  ///
  /// 这不等同于「课程列表正在写」：时间方案、节次容量和学期设置也可能
  /// 先落盘。只要其中任何一项已经开始，取消就只能等真实结果，不能再伪装
  /// 成「已取消」。
  bool _backgroundWriteStarted = false;

  /// 返回动画跑到尾段时，平台视图是否已摘出树（见
  /// [_detachPlatformViewIfExitReached]）。
  bool _platformViewDetachedForExit = false;

  /// 本页路由的主动画，用来盯"开始返回"这一位（见 [didChangeDependencies]）。
  Animation<double>? _exitRouteAnimation;
  VoidCallback? _exitRouteAnimationListener;

  // --- 宏录制相关 ---
  final WarehouseMacroService _macroService = WarehouseMacroService();
  MacroRecordingState _macroRecordingState = MacroRecordingState.idle;
  List<Map<String, dynamic>> _macroRawEvents = [];
  final Map<String, dynamic> _macroDialogResponses = {};

  /// 根据弹窗类型和内容生成匹配 key，用于录制时关联操作和回放时自动响应
  String _dialogResponseKey(String type, Map<String, dynamic> message) =>
      warehouseDialogResponseKey(type, message);

  // --- 宏回放相关 ---
  PlaybackUiState _playbackState = PlaybackUiState.hidden;
  ReplayProgress _playbackProgress = const ReplayProgress(
    currentStepIndex: 0,
    totalSteps: 0,
    currentStep: MacroStep(type: MacroStepType.delay),
    status: ReplayStepStatus.pending,
  );
  WarehouseMacroReplayer? _replayer;
  bool _quickImportResultHandled = false;

  bool get _isUsingLocalDebugScript =>
      (widget.debugScriptOverride ?? '').trim().isNotEmpty;

  void _debugImportLog(String message, {String level = 'info'}) {
    final detail =
        'macro=$_isMacroReplay '
        'playback=$_playbackState '
        'executing=$_isExecutingImport '
        'recording=$_macroRecordingState '
        'status="${_lastScriptStatus ?? ''}" '
        '$message';
    WarehouseImportSessionLog.instance.append(
      message: detail,
      level: level,
      extras: {
        'schoolId': widget.school.id,
        'schoolName': widget.school.name,
        'adapterId': widget.adapter.adapterId,
        'adapterName': widget.adapter.adapterName,
        'url': _currentUrl ?? widget.initialUrl,
        'macroReplay': _isMacroReplay,
        'executingImport': _isExecutingImport,
        'playbackState': '$_playbackState',
        'recordingState': '$_macroRecordingState',
      },
    );
    if (!kDebugMode) return;
    appDebugLog('WarehouseImportDebug', detail);
  }

  void _notifyBackgroundProgress() {
    if (widget.runInBackground) {
      widget.onBackgroundProgress?.call();
    }
  }

  String _bridgeMessageSummary(Map<String, dynamic> message) {
    final type = message['type'];
    final keys = message.keys.join(',');
    final payload = message['payload'];
    final payloadLength = payload is String ? payload.length : null;
    final errorMessage = message['message'];
    return 'type=$type keys=[$keys] payloadLength=$payloadLength message=$errorMessage';
  }

  /// Adapter scripts often toast "成功导入 N 条课程" right before the host shows
  /// the quick-import completion sheet. Match common success phrasings so we
  /// can suppress the redundant light tip during macro replay.
  bool _isScriptImportSuccessToast(String message) {
    final text = message.trim();
    if (text.isEmpty) {
      return false;
    }
    final lower = text.toLowerCase();
    return text.contains('成功导入') ||
        text.contains('导入成功') ||
        text.contains('导入完成') ||
        (text.contains('导入') && text.contains('条课程')) ||
        lower.contains('import success') ||
        lower.contains('imported') && lower.contains('course');
  }

  /// Progress toasts from adapter scripts ("正在获取课表…") are redundant with
  /// the quick-import playback overlay / completion sheet.
  bool _isScriptImportProgressToast(String message) {
    final text = message.trim();
    if (text.isEmpty) {
      return false;
    }
    return text.contains('正在通过接口') ||
        text.contains('正在获取') ||
        text.contains('正在导入') ||
        text.contains('请稍候') ||
        text.contains('请稍等');
  }

  @override
  void initState() {
    super.initState();
    // 可见登录页的 WebView 是平台视图：玻璃的背景采集拿不到它的像素（采到
    // 黑/透明），路由存续期间全局降级玻璃为实色，覆盖其上的全部弹窗、菜单
    // 与表单。下拉快捷导入的 runInBackground 实例挂在 Offstage 1×1 里，paint
    // 整棵跳过、平台视图不进合成帧，玻璃背后仍是纯 Flutter 内容——置位闸门
    // 只会让首页玻璃白白陪葬降级，故仅可见页置位。
    if (!widget.runInBackground) {
      LiquidGlassDegradation.beginPlatformViewUnsafeSurface();
    }
    _useDesktopMode = widget.macroRecord?.useDesktopMode ?? true;
    _currentUrl = widget.initialUrl;
    _addressController = TextEditingController(text: widget.initialUrl);
    _startSessionProbeConfigLoad();
    WarehouseImportSessionLog.instance.append(
      message:
          'open web login school=${widget.school.name}(${widget.school.id}) '
          'adapter=${widget.adapter.adapterName}(${widget.adapter.adapterId}) '
          'url=${widget.initialUrl} macro=${widget.macroRecord != null} '
          'autoRecord=${widget.autoRecord} localDebug=$_isUsingLocalDebugScript',
      extras: {
        'schoolId': widget.school.id,
        'adapterId': widget.adapter.adapterId,
        'url': widget.initialUrl,
      },
    );
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..enableZoom(true)
      ..setUserAgent(_useDesktopMode ? _desktopUserAgent : _mobileUserAgent)
      ..addJavaScriptChannel(
        'QingyuBridge',
        onMessageReceived: (message) {
          _handleBridgeMessage(message.message);
        },
      )
      ..setOnConsoleMessage((consoleMessage) {
        WarehouseImportSessionLog.instance.append(
          message:
              'console.${consoleMessage.level.name}: ${consoleMessage.message}',
          level: consoleMessage.level.name == 'error' ? 'error' : 'debug',
          extras: {
            'schoolId': widget.school.id,
            'adapterId': widget.adapter.adapterId,
            'url': _currentUrl ?? widget.initialUrl,
          },
        );
      })
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            if (!mounted) {
              return;
            }
            setState(() {
              _loadingProgress = progress;
            });
          },
          onPageStarted: (url) {
            if (!mounted) {
              return;
            }
            // 页面导航会销毁已注入脚本的执行上下文（强智登录后固定跳「学生个人中心」，
            // 适配脚本常需要先 location.href 跳到课表页、再让用户重跑一次）。此时脚本
            // 不可能再回调宿主，继续等导入超时只会给出「timeout」假报错，直接收尾。
            //
            // 只认「整个文档被替换」：部分教务站点用 # 切页签，同文档跳转不会销毁
            // 脚本上下文，若也收尾会把进行中的导入误判为中断。
            final importAbandonedByNavigation =
                _isExecutingImport &&
                !_isMacroReplay &&
                !widget.runInBackground &&
                warehouseDocumentKey(_currentUrl) != warehouseDocumentKey(url);
            if (importAbandonedByNavigation) {
              _debugImportLog(
                'navigation during import -> stop waiting url=$url',
              );
              _cancelImportTimeout();
            }
            setState(() {
              if (importAbandonedByNavigation) {
                _isExecutingImport = false;
                _lastScriptStatus = null;
              }
              _currentUrl = url;
              _hasPromptedAutofill = false;
              _lastLoginStateDecisionKey = null;
              if (!_addressFocusNode.hasFocus) {
                _addressController.text = url;
              }
            });
          },
          onPageFinished: (url) {
            if (!mounted) {
              return;
            }
            setState(() {
              _currentUrl = url;
              _loadingProgress = 100;
              if (!_addressFocusNode.hasFocus) {
                _addressController.text = url;
              }
            });
            // 先注入录制 JS（如果在录制中），再探测登录状态——这样填充事件也能被录制到
            if (_macroRecordingState == MacroRecordingState.recording) {
              _injectMacroRecorderJs();
            }
            _injectImeScrollHelperJs();
            _applyViewportOverrideJs();
            _requestLoginStateProbe();
            _maybeRunSessionProbe(url);
          },
          onWebResourceError: (error) {
            // 安全配置收紧后（release 仅放行 NSC 白名单内的 HTTP 域），
            // 白名单外的明文站点会被拦成 ERR_CLEARTEXT_NOT_PERMITTED。
            // 不提示的话 WebView 只会白屏，用户会以为教务导入坏了。
            if (!mounted) {
              return;
            }
            WarehouseImportSessionLog.instance.append(
              message:
                  'webview.error: ${error.errorCode} ${error.description} '
                  '(url: ${error.url ?? _currentUrl ?? widget.initialUrl})',
              level: 'error',
              extras: {
                'schoolId': widget.school.id,
                'adapterId': widget.adapter.adapterId,
                'url': error.url ?? _currentUrl ?? widget.initialUrl,
              },
            );
            final isCleartextBlocked = error.description.contains(
              'ERR_CLEARTEXT_NOT_PERMITTED',
            );
            if (isCleartextBlocked) {
              final errorL10n = AppLocalizations.of(context);
              if (errorL10n != null) {
                showAppToast(
                  context,
                  message: errorL10n.importCleartextBlockedHint,
                  kind: AppToastKind.error,
                );
              }
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.initialUrl));
    // 键盘弹出时让网页布局保持与系统浏览器一致：Chromium WebView 收到 IME
    // insets 后会压缩网页视口去"避开"键盘，强智等教务登录页的底部版权条
    // （fixed 定位）会被顶到「登录」按钮上，导致按钮点不到。让网页内容忽略
    // IME insets 后，键盘直接悬浮在网页上方，页面不再挤压变形。
    final webviewPlatform = _controller.platform;
    if (webviewPlatform is AndroidWebViewController) {
      unawaited(
        webviewPlatform.setInsetsForWebContentToIgnore(
          <AndroidWebViewInsets>[AndroidWebViewInsets.ime],
        ),
      );
      // 插件默认 useWideViewPort=false：viewport meta 被忽略、布局视口锁死
      // 设备宽度，桌面/移动切换只剩 UA 差异，页面渲染必然一模一样。恢复
      // 标准 viewport 语义后，布局宽度才随 meta（及下方的 JS 改写）变化。
      unawaited(webviewPlatform.setUseWideViewPort(true));
    }
    _loadRememberedLogin();

    // 如果是自动录制模式，延迟一帧后自动开始录制
    if (widget.autoRecord && widget.macroRecord == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startMacroRecording();
      });
    }

    // 如果是回放模式，延迟一帧后自动开始
    if (widget.macroRecord != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startPlayback(widget.macroRecord!);
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _bindExitRouteAnimation();
  }

  /// 盯住"本页开始返回"这一位：反向动画走到尾段时把平台视图摘出树。
  ///
  /// 用路由自己的动画，而不是给每个 pop 调用点各包一层：左上角返回键、系统返回、
  /// 导入成功后这一页自己 pop，全都走同一条反向动画。
  ///
  /// `runInBackground` 实例挂在 Overlay 里（没有本页路由），这里一并挡掉：后台
  /// 导入正是靠这个平台视图继续跑，不能摘。
  void _bindExitRouteAnimation() {
    if (widget.runInBackground) {
      return;
    }
    final animation = ModalRoute.of(context)?.animation;
    if (identical(animation, _exitRouteAnimation)) {
      return;
    }
    _unbindExitRouteAnimation();
    if (animation == null) {
      return;
    }
    void onChanged() => _detachPlatformViewIfExitReached(animation);
    _exitRouteAnimation = animation;
    _exitRouteAnimationListener = onChanged;
    animation.addListener(onChanged);
  }

  void _unbindExitRouteAnimation() {
    final listener = _exitRouteAnimationListener;
    if (listener != null) {
      _exitRouteAnimation?.removeListener(listener);
    }
    _exitRouteAnimationListener = null;
    _exitRouteAnimation = null;
  }

  /// 反向动画滑出大半时，把 WebView 摘出树（换空白占位）。
  ///
  /// Hybrid Composition 的 WebView 是**真实 Android 视图**，不在 Flutter 图层
  /// 树里：返回动画挪的是 Flutter 的图层，它跟不上；路由销毁时才发起的移除又是
  /// 异步的，于是动画落地后它还会在"滑到一半"的位置停一两帧（真机现象：返回动画
  /// 结束又闪回半页，然后才消失）。提前摘掉，移除的异步延迟就落在动画还在跑的时
  /// 候，落地时它早就不在了；顺带把 HC 在剩余滑行里的逐帧合成开销一并免掉。
  ///
  /// ⚠️ 这里**只摘平台视图，不动玻璃闸门**。闸门结束会让全 app 的玻璃一次性重建
  /// 材质（这套玻璃里最贵的一步），放在动画中间做就是把掉帧摊在用户眼前 —— 真机
  /// 反馈「网页退出明显比别的页面卡顿」就是这么来的。闸门仍留在 [dispose] 归零。
  void _detachPlatformViewIfExitReached(Animation<double> animation) {
    if (_platformViewDetachedForExit) {
      return;
    }
    if (!shouldDetachPlatformViewOnExit(
      status: animation.status,
      value: animation.value,
    )) {
      return;
    }
    _platformViewDetachedForExit = true;
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _unbindExitRouteAnimation();
    _replayer?.cancel();
    _replayContinueCompleter?.complete(false);
    _replayContinueCompleter = null;
    _importTimeoutTimer?.cancel();
    _disposeSessionProbe();
    _addressController.dispose();
    _addressFocusNode.dispose();
    // 与 initState 的置位对称：runInBackground 实例从未置位，不得复位别人
    // 的计数（endPlatformViewUnsafeSurface 虽有下限守卫，仍不应虚减）。
    // 归零时机就在路由销毁这一帧：不提前到返回动画中间（见
    // [_detachPlatformViewIfExitReached]）。
    if (!widget.runInBackground) {
      LiquidGlassDegradation.endPlatformViewUnsafeSurface();
    }
    super.dispose();
  }

  void _resetPendingImportedArtifacts() {
    _pendingImportedSections = null;
    _pendingImportedSectionsSignature = null;
    _appliedImportedSectionsSignature = null;
    _pendingImportedSectionsApplyFuture = null;
  }

  String _buildSectionSignature(List<SectionTime> sections) => sections
      .map((section) => '${section.startTime}-${section.endTime}')
      .join('|');

  List<SectionTime> _decodeImportedSections(String payload) {
    final decoded = jsonDecode(payload);
    if (decoded is! List) {
      throw FormatException(
        AppLocalizations.of(context)!.invalidSectionTimeFormat,
      );
    }
    // 按位对齐：坏位留空而不是压缩掉，否则它之后的每一节时间整体前移一档
    //（见 import_shared.dart 的 decodeAlignedImportedSections）。
    final sections = decodeAlignedImportedSections(decoded);
    if (sections == null) {
      throw FormatException(AppLocalizations.of(context)!.noSectionTimesToSave);
    }
    return sections;
  }

  Future<void> _waitForCompanionImportSections() async {
    if (_pendingImportedSections != null) {
      return;
    }
    for (var attempt = 0; attempt < 8; attempt++) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      if (_pendingImportedSections != null) {
        return;
      }
    }
  }

  Future<void> _applyImportedSections(List<SectionTime> sections) async {
    _markBackgroundWriteStarted();
    final provider = context.read<TimetableProvider>();
    final schemeName = AppLocalizations.of(
      context,
    )!.warehouseImportedTimeSchemeName(widget.school.name);
    TimeScheme? existingScheme;
    for (final scheme in provider.timeSchemes) {
      if (scheme.name == schemeName) {
        existingScheme = scheme;
        break;
      }
    }
    if (existingScheme == null) {
      final created = await provider.createTimeScheme(
        name: schemeName,
        sections: sections,
        applyToActiveProfile: true,
      );
      final applyError = await provider.applyTimeScheme(created.id);
      if (applyError != null) {
        throw FormatException(applyError);
      }
      return;
    }
    final result = await provider.updateTimeScheme(
      schemeId: existingScheme.id,
      name: existingScheme.name,
      sections: sections,
    );
    if (result != null) {
      throw FormatException(result);
    }
    final applyError = await provider.applyTimeScheme(existingScheme.id);
    if (applyError != null) {
      throw FormatException(applyError);
    }
  }

  Future<void> _applyPendingImportedSectionsIfNeeded() async {
    final sections = _pendingImportedSections;
    final signature = _pendingImportedSectionsSignature;
    if (sections == null || sections.isEmpty) {
      return;
    }
    if (signature != null && signature == _appliedImportedSectionsSignature) {
      return;
    }
    final inFlight = _pendingImportedSectionsApplyFuture;
    if (inFlight != null) {
      await inFlight;
      return;
    }
    final future = _applyImportedSections(sections);
    _pendingImportedSectionsApplyFuture = future;
    try {
      await future;
      _appliedImportedSectionsSignature = signature;
    } finally {
      if (identical(_pendingImportedSectionsApplyFuture, future)) {
        _pendingImportedSectionsApplyFuture = null;
      }
    }
  }

  Future<void> _showWebLoginMoreMenu() async {
    final l10n = AppLocalizations.of(context)!;
    final anchorRect = measurePopupAnchorRect(_webLoginMoreMenuKey);
    if (!mounted || anchorRect == null) {
      return;
    }
    final hasRemembered = _rememberedLogin != null;
    setState(() {
      _webLoginMenuVisible = true;
      _webLoginMenuAnchorBounds = anchorRect;
      _webLoginMenuEntries = [
        HyperosAnchorMenuEntry(
          label: l10n.executeImportScriptAction,
          value: 'execute',
          enabled: !_isExecutingImport,
        ),
        HyperosAnchorMenuEntry(
          label: l10n.rememberCurrentInputTooltip,
          value: 'remember',
        ),
        HyperosAnchorMenuEntry(
          label: l10n.fillRememberedTooltip,
          value: 'fill',
          enabled: hasRemembered,
        ),
        HyperosAnchorMenuEntry(
          label: l10n.clearRememberedTooltip,
          value: 'clear',
          enabled: hasRemembered,
        ),
        HyperosAnchorMenuEntry(
          label: l10n.copyCurrentAddressTooltip,
          value: 'copy',
        ),
        HyperosAnchorMenuEntry(
          label: l10n.warehouseImportExecutionLogMenuLabel,
          value: 'executionLog',
        ),
      ];
    });
  }

  void _closeWebLoginMenu() {
    if (!_webLoginMenuVisible) {
      return;
    }
    setState(() => _webLoginMenuVisible = false);
  }

  /// 菜单收完后执行被点的那一项（时序由 `HyperosAnchorMenuPopup` 内置）。
  Future<void> _handleWebLoginMenuSelection(Object value) async {
    if (!mounted) {
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    switch (value) {
      case 'execute':
        _executeImportScript();
        break;
      case 'remember':
        _rememberCurrentLogin();
        break;
      case 'fill':
        _autofillRememberedLogin();
        break;
      case 'clear':
        _clearRememberedLogin();
        break;
      case 'copy':
        final url = _currentUrl ?? widget.initialUrl;
        await Clipboard.setData(ClipboardData(text: url));
        if (mounted) {
          showAppToast(
            context,
            message: l10n.copiedCurrentAddress,
            kind: AppToastKind.success,
          );
        }
        break;
      case 'executionLog':
        await openWarehouseImportExecutionLogViewer(context);
        break;
    }
  }

  Widget _buildWebLoginMenu() {
    return HyperosAnchorMenuPopup(
      show: _webLoginMenuVisible,
      anchorBounds: _webLoginMenuAnchorBounds,
      entries: _webLoginMenuEntries,
      // 悬在 WebView 上方：玻璃背景采集不到平台视图内容会渲染成黑块，用实底。
      opaqueSurface: true,
      onCollapseRequested: _closeWebLoginMenu,
      onDismissRequest: _closeWebLoginMenu,
      onSelected: _handleWebLoginMenuSelection,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final effectiveDebugScriptName =
        (widget.debugScriptName?.trim().isNotEmpty ?? false)
        ? widget.debugScriptName!.trim()
        : l10n.unnamedScript;
    final currentStatus =
        _lastScriptStatus ??
        (_isUsingLocalDebugScript
            ? l10n.localDebugModeScriptStatus(effectiveDebugScriptName)
            : null);
    if (widget.runInBackground) {
      // Keep the platform WebView attached (size > 0) but fully off-screen so
      // JS / cookies / navigation still work without showing any UI chrome.
      return Offstage(
        child: SizedBox(
          width: 1,
          height: 1,
          child: _buildWebViewWidget(),
        ),
      );
    }
    return Stack(
      children: [
        Positioned.fill(
          child: _buildWebLoginBody(
            l10n,
            effectiveDebugScriptName,
            currentStatus,
          ),
        ),
        // ⚠️ 常驻挂载，条件插拔会让上游 presenter 的 State 重建、入场动画重放。
        _buildWebLoginMenu(),
      ],
    );
  }

  Widget _buildWebLoginBody(
    AppLocalizations l10n,
    String effectiveDebugScriptName,
    String? currentStatus,
  ) {
    return HyperosSubpage(
      onBack: () => Navigator.pop(context),
      // 顶栏不摆标题：这一页标题是「学校名 + 适配器名」（如「重庆城市科技
      // 学院强智通适配」，14 个字 ≈ 237dp），而顶栏右侧常年挂着 4 个动作
      // 图标（录制 / 桌面切换 / 刷新 / 更多，合计 160dp）——360dp 宽的机器上
      // 标题只剩 100dp 出头，塞不下就是省略号，看不出是哪所学校；干脆不摆
      // （2026-09-28 用户拍板）。要看学校名退回上一层就是，网页本身也在
      // 地址栏里露了教务域名。
      title: const SizedBox.shrink(),
      // 校名收进返回按钮那一行的小标题：可折叠大标题在网页场景永远不会被
      // 滚动收起（滚动发生在 WebView 内部），只会常驻占用约一整行高度。
      collapsibleLargeTitle: false,
      suffixes: [
        if (widget.macroRecord == null)
          FHeaderAction(
            icon: _macroRecordingState == MacroRecordingState.recording
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: HyperosCircularProgress(size: 18, strokeWidth: 2),
                  )
                : const Icon(Icons.fiber_manual_record_rounded),
            semanticsLabel:
                _macroRecordingState == MacroRecordingState.recording
                ? l10n.stopRecordingTooltip
                : l10n.startRecordingTooltip,
            onPress: _isExecutingImport ? null : _toggleMacroRecording,
          ),
        if (widget.macroRecord == null)
          FHeaderAction(
            icon: Icon(
              _useDesktopMode
                  ? Icons.smartphone_rounded
                  : Icons.desktop_windows_rounded,
            ),
            semanticsLabel: _useDesktopMode
                ? l10n.switchToMobileWebTooltip
                : l10n.switchToDesktopWebTooltip,
            onPress: _toggleWebPageMode,
          ),
        FHeaderAction(
          icon: const Icon(Icons.refresh_rounded),
          semanticsLabel: l10n.reloadAction,
          onPress: _controller.reload,
        ),
        Builder(
          key: _webLoginMoreMenuKey,
          builder: (context) => FHeaderAction(
            icon: const Icon(Icons.more_vert_rounded),
            semanticsLabel: l10n.moreActionsTooltip,
            onPress: _showWebLoginMoreMenu,
          ),
        ),
      ],
      child: Material(
        type: MaterialType.transparency,
        child: HyperosBlurredBodyInset(
          child: Stack(
            children: [
              Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                    color: HyperosColors.card(context),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // URL 地址栏（压缩为单行：桌面/移动模式由头部切换按钮
                        // 表达，本地调试脚本名由状态行 currentStatus 表达，
                        // 不再常驻占一行提示）
                        //
                        // IntrinsicHeight + stretch：「前往」跟着输入框等高。
                        // 按钮规格高 40、输入框 58，按默认的居中对齐会上下各
                        // 空 6，看着像没对齐（2026-09-28 真机反馈）。行高交给
                        // 输入框定，按钮不反向影响它。
                        IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: HyperosTextField(
                                  controller: _addressController,
                                  focusNode: _addressFocusNode,
                                  hint: l10n.webAddressHint,
                                  keyboardType: TextInputType.url,
                                  textInputAction: TextInputAction.go,
                                  onSubmitted: (_) => _loadAddressBarUrl(),
                                ),
                              ),
                              const SizedBox(width: 8),
                              HyperosButton(
                                label: l10n.goAction,
                                onPressed: _loadAddressBarUrl,
                              ),
                            ],
                          ),
                        ),
                        // 状态/提示行
                        if ((currentStatus ?? '').isNotEmpty ||
                            _rememberedLogin != null ||
                            (_macroRecordingState ==
                                MacroRecordingState.recording) ||
                            (_macroRecordingState ==
                                    MacroRecordingState.stopped &&
                                _lastScriptStatus != null))
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              _lastScriptStatus ??
                                  currentStatus ??
                                  (_rememberedLogin != null
                                      ? l10n.rememberedAccountLabel(
                                          _rememberedLogin!.username,
                                        )
                                      : ''),
                              style: HyperosTypography.listDetail(
                                context,
                              ).copyWith(color: HyperosColors.primary(context)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (_loadingProgress < 100)
                    HyperosLinearProgress(value: _loadingProgress / 100),
                  Expanded(child: _buildWebViewSlot()),
                  if (_showImportScriptBar)
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // 探针确认会话还在时的一句话说明。放在按钮正上方而不是
                            // 顶部状态行：状态行归导入过程所有，而这条说的是「你现在
                            // 不必登录」，两者混在一行会互相覆盖。
                            if (_isSessionActive) ...[
                              Text(
                                l10n.warehouseSessionAlreadyActive,
                                style: HyperosTypography.listDetail(
                                  context,
                                ).copyWith(
                                  color: HyperosColors.primary(context),
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                            ],
                            HyperosButton(
                              label: _isExecutingImport
                                  ? l10n.importingAction
                                  : (_isUsingLocalDebugScript
                                        ? l10n.executeLocalDebugScriptAction
                                        : l10n.executeImportScriptAction),
                              expand: true,
                              loading: _isExecutingImport,
                              onPressed: _isExecutingImport
                                  ? null
                                  : _executeImportScript,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              Positioned.fill(
                child: PlaybackOverlay(
                  progress: _playbackProgress,
                  state: _playbackState,
                  schoolName: widget.school.name,
                  adapterName: widget.adapter.adapterName,
                  onCancel: _cancelPlayback,
                  onRetry: _retryPlayback,
                  onDismiss: _dismissPlaybackResult,
                  onContinueAfterPause: _resumePlaybackAfterPause,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _loadAddressBarUrl() async {
    final text = _addressController.text.trim();
    final uri = Uri.tryParse(text);
    if (uri == null || uri.host.isEmpty) {
      if (!mounted) return;
      showImportLightTip(context, AppLocalizations.of(context)!.invalidWebAddress);
      return;
    }
    _addressFocusNode.unfocus();
    setState(() {
      _currentUrl = uri.toString();
      _loadingProgress = 0;
    });
    await _controller.loadRequest(uri);
  }

  Future<void> _toggleWebPageMode() async {
    final nextDesktopMode = !_useDesktopMode;
    setState(() {
      _useDesktopMode = nextDesktopMode;
      _loadingProgress = 0;
    });
    await _controller.setUserAgent(
      nextDesktopMode ? _desktopUserAgent : _mobileUserAgent,
    );
    final target = Uri.tryParse(_currentUrl ?? widget.initialUrl);
    if (target != null) {
      await _controller.loadRequest(target);
    }
  }

  /// 键盘弹出时网页不再收到 IME insets（见 initState 的
  /// setInsetsForWebContentToIgnore），Chromium 因此不会像浏览器那样把聚焦的
  /// 输入框滚动进可见区域。这里注入 focusin 兜底：输入框聚焦后，若其位于
  /// 视口下部（键盘大致遮挡区域）就把自身滚动到视口中部，保证输入内容可见；
  /// 页面整体不可滚动（如固定定位的教务登录页）时 scrollIntoView 静默无效。
  /// 用 Hybrid Composition 承载 WebView。默认的 TLHC/虚拟屏实现在窗口
  /// insets 变化（键盘弹出/收起）时可能留下内容缩放、裁切的失步画面
  /// （新版 WebView + 高版本 Android 上更明显）；HC 是真实视图，insets
  /// 按普通视图链路分发，配合 setInsetsForWebContentToIgnore 行为最稳定。
  /// 登录导入页不是性能敏感场景，代价可接受。非 Android 平台回退默认实现。
  /// 网页槽位：正常是 WebView；返回动画跑到尾段时换成空白占位（见
  /// [_detachPlatformViewIfExitReached]），让平台视图在动画结束前就离开合成帧。
  Widget _buildWebViewSlot() {
    if (!_platformViewDetachedForExit) {
      return _buildWebViewWidget();
    }
    // 用页面自己的底色而不是透明：这块占页面主体，透明会让后面的首页从"洞"里
    // 透出来。这一刻页面已滑出大半，能看见它的时间只有几十毫秒。
    return ColoredBox(color: HyperosColors.scaffoldBackground(context));
  }

  Widget _buildWebViewWidget() {
    final platform = _controller.platform;
    if (platform is! AndroidWebViewController) {
      return WebViewWidget(controller: _controller);
    }
    return WebViewWidget.fromPlatformCreationParams(
      params: AndroidWebViewWidgetCreationParams(
        controller: platform,
        displayWithHybridComposition: true,
      ),
    );
  }

  /// 桌面/移动切换的另一半：浏览器的「桌面版网站」除了换 UA，还会把布局
  /// 视口强制为宽屏并让页面自身的 viewport meta 失效，页面才按桌面版重排。
  /// WebView 换 UA 不改布局视口，两种模式渲染完全相同。这里在每次页面加载
  /// 后按模式改写 viewport meta 复刻该行为：桌面强制 width=1024（略宽于
  /// Chrome 的 980，避免强智这类固定 1000px 模板出现横向滚动）；移动恢复
  /// 页面原始 meta（无 meta 回退 device-width）。配合 initState 恢复的
  /// useWideViewPort 才能生效。
  Future<void> _applyViewportOverrideJs() async {
    final desktop = _useDesktopMode;
    try {
      await _controller.runJavaScript('''
(() => {
  const KEY = '__qingyuOriginalViewport';
  let meta = document.querySelector('meta[name="viewport"]');
  if (!meta) {
    meta = document.createElement('meta');
    meta.setAttribute('name', 'viewport');
    (document.head || document.documentElement).appendChild(meta);
  }
  if (window[KEY] === undefined) {
    window[KEY] = meta.getAttribute('content');
  }
  const content = $desktop
      ? 'width=1024'
      : (window[KEY] || 'width=device-width, initial-scale=1');
  if (meta.getAttribute('content') !== content) {
    meta.setAttribute('content', content);
  }
})();
''');
    } catch (error) {
      WarehouseImportSessionLog.instance.append(
        message: 'viewport override inject failed: $error',
        level: 'debug',
        extras: {
          'schoolId': widget.school.id,
          'adapterId': widget.adapter.adapterId,
        },
      );
    }
  }

  Future<void> _injectImeScrollHelperJs() async {
    try {
      await _controller.runJavaScript('''
(() => {
  if (window.__qingyuImeScrollInstalled) return;
  window.__qingyuImeScrollInstalled = true;
  document.addEventListener('focusin', () => {
    setTimeout(() => {
      const el = document.activeElement;
      if (!el || (el.tagName !== 'INPUT' && el.tagName !== 'TEXTAREA')) return;
      const rect = el.getBoundingClientRect();
      if (rect.bottom > window.innerHeight * 0.6) {
        try { el.scrollIntoView({ block: 'center', inline: 'nearest' }); } catch (e) {}
      }
    }, 250);
  }, true);
})();
''');
    } catch (error) {
      WarehouseImportSessionLog.instance.append(
        message: 'ime scroll helper inject failed: $error',
        level: 'debug',
        extras: {
          'schoolId': widget.school.id,
          'adapterId': widget.adapter.adapterId,
        },
      );
    }
  }

  Future<void> _installLoginWatcher() async {
    try {
      await _controller.runJavaScript('''
(() => {
  const collect = () => {
    const textInputs = Array.from(document.querySelectorAll('input')).filter((input) => {
      const type = (input.type || 'text').toLowerCase();
      return ['text','email','tel','number'].includes(type) && !input.disabled;
    });
    const passwordInput = Array.from(document.querySelectorAll('input[type="password"]')).find((input) => !input.disabled);
    QingyuBridge.postMessage(JSON.stringify({
      type: 'loginState',
      username: textInputs[0] ? String(textInputs[0].value || '') : '',
      password: passwordInput ? String(passwordInput.value || '') : '',
      hasPasswordField: !!passwordInput
    }));
  };
  window.__qingyuCollectLoginState = collect;
  if (!window.__qingyuLoginWatcherInstalled) {
    window.__qingyuLoginWatcherInstalled = true;
    document.addEventListener('input', (event) => {
      if (event.target && event.target.tagName === 'INPUT') collect();
    }, true);
    document.addEventListener('change', (event) => {
      if (event.target && event.target.tagName === 'INPUT') collect();
    }, true);
    document.addEventListener('click', (event) => {
      const target = event.target;
      if (!(target instanceof HTMLElement)) return;
      const text = (target.innerText || target.textContent || target.value || '').trim().toLowerCase();
      if (/登录|login|sign in|signin|进入教务|提交/.test(text)) {
        collect();
        QingyuBridge.postMessage(JSON.stringify({ type: 'loginAttempt' }));
      }
    }, true);
    document.addEventListener('submit', () => {
      collect();
      QingyuBridge.postMessage(JSON.stringify({ type: 'loginAttempt' }));
    }, true);
    let loginProbeTimer = null;
    const scheduleCollect = () => {
      window.clearTimeout(loginProbeTimer);
      loginProbeTimer = window.setTimeout(collect, 120);
    };
    const observer = new MutationObserver(scheduleCollect);
    observer.observe(document.documentElement || document.body, {
      childList: true,
      subtree: true,
      attributes: true,
      attributeFilter: ['type', 'disabled', 'style', 'class']
    });
  }
  collect();
  window.setTimeout(collect, 0);
  window.setTimeout(collect, 300);
  window.setTimeout(collect, 1000);
  window.setTimeout(collect, 2000);
})();
''');
    } catch (e) {
      // WebView 已销毁或桥不可用：登录探测整条链路失效，但导入主流程
      // 会按超时兜底。留痕便于排查「登录探测不工作」类反馈。
      _debugImportLog('login watcher inject failed: $e', level: 'warn');
    }
  }

  Future<void> _requestLoginStateProbe() async {
    await _installLoginWatcher();
    try {
      await _controller.runJavaScript('window.__qingyuCollectLoginState?.();');
    } catch (e) {
      // 同上：探测脚本执行失败不影响导入主流程，留痕即可。
      _debugImportLog('login state probe failed: $e', level: 'warn');
    }
  }

  /// 探针配置的读取时机。
  ///
  /// 绝大多数学校没有 `session_probe.json`（222 所里目前 1 所），这一次读取对它们
  /// 是一次必然的 404。所以它**不在渲染关键路径上**：开页就发起、回来再判有没有
  /// 配置，绝不让整个登录页陪着这一次探测等。读失败一律降级为「没配置」。
  void _startSessionProbeConfigLoad() {
    if (widget.runInBackground) {
      // 后台导入没有界面、也没有人需要看「你还登录着」这句提示，别为它多打请求。
      return;
    }
    _repositoryService
        .fetchQingyuOnlySessionProbeText(widget.source, widget.school)
        .then((raw) {
      if (!mounted) {
        return;
      }
      final config = parseWarehouseSessionProbeConfig(raw);
      setState(() {
        _sessionProbeConfig = config;
      });
      _debugImportLog(
        'session probe config loaded configured=${config != null}',
        level: 'debug',
      );
    }, onError: (Object error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _sessionProbeConfig = null;
      });
      _debugImportLog('session probe config load failed: $error', level: 'warn');
    });
  }

  /// 页面加载完就问一次「会话还在吗」。判据与取舍见
  /// `lib/domain/warehouse_session_probe.dart`。
  Future<void> _maybeRunSessionProbe(String pageUrl) async {
    final config = _sessionProbeConfig;
    if (config == null) {
      // 没配置 = 这所学校不探，行为与今天完全一致。
      return;
    }
    if (widget.runInBackground ||
        _isMacroReplay ||
        _macroRecordingState == MacroRecordingState.recording) {
      // 宏回放按录制好的步骤自己走；录制中更不能有外来脚本在页面上活动。
      return;
    }
    if (_sessionProbeInFlight) {
      return;
    }
    final origin = warehouseSessionProbeOrigin(pageUrl);
    if (origin == null) {
      return;
    }
    if (_sessionProbeOrigin != null && _sessionProbeOrigin != origin) {
      // 换站了：之前那份结论作数不得，重新探。
      setState(() {
        _sessionProbeVerdict = WarehouseSessionProbeVerdict.unknown;
      });
    }
    _sessionProbeOrigin = origin;
    final hasVerdict = _sessionProbeVerdict != WarehouseSessionProbeVerdict.unknown;
    if (hasVerdict && _sessionProbeVerdict != WarehouseSessionProbeVerdict.unavailable) {
      // 登录中/未登录是可信结论：同一站里翻页不会让会话凭空消失，不重复探。
      return;
    }
    // unavailable（网络失败 / 403 一类）只是「这次没探成」：允许冷却期后重试，
    // 否则一次偶发失败就把「已登录」提示永久关掉。可信结论不受冷却限制。
    final lastAttempt = _sessionProbeLastAttemptAt;
    if (lastAttempt != null &&
        (!hasVerdict ||
            _sessionProbeVerdict == WarehouseSessionProbeVerdict.unavailable) &&
        DateTime.now().difference(lastAttempt) < _sessionProbeCooldown) {
      return;
    }
    final target = resolveWarehouseSessionProbeTarget(
      entryUrl: widget.initialUrl,
      pageUrl: pageUrl,
      probeUrl: config.probeUrl,
    );
    if (target == null) {
      _debugImportLog(
        'session probe skipped: target not same-origin page=$pageUrl '
        'probe=${config.probeUrl}',
        level: 'debug',
      );
      return;
    }
    _sessionProbeLastAttemptAt = DateTime.now();
    _sessionProbeInFlight = true;
    _debugImportLog('session probe start target=$target');
    // 兜底：页面脚本可能因为导航/销毁而永远不回调。没有这个计时器，
    // _sessionProbeInFlight 会一直挂着，本次开页再也不会探第二次。
    //
    // ⚠️ 必须装在注入**之前**：runJavaScript 的 Future 挂住时既不完成也不抛，
    // catch 走不到，装在它后面就等于「注入一卡住就没有任何兜底 → 在途标记永不
    // 清 → 本次开页「要不要帮你填密码」再也不弹」。
    _sessionProbeTimer?.cancel();
    _sessionProbeTimer = Timer(_sessionProbeTimeout, () {
      _sessionProbeInFlight = false;
      // 判为 unknown 而不是 unavailable：网络抖动、页面还没稳住都可能造成超时，
      // 留给下一次翻页重试（冷却期挡住立刻重打）。
      _debugImportLog('session probe timeout', level: 'warn');
      // 等探针等到了超时：被推迟的弹窗决定此刻放行（按「没探成」原行为）。
      unawaited(_evaluatePendingAutofillPrompt());
    });
    try {
      await _controller.runJavaScript(_sessionProbeScript(target));
    } catch (e) {
      _sessionProbeTimer?.cancel();
      _sessionProbeTimer = null;
      _sessionProbeInFlight = false;
      _debugImportLog('session probe inject failed: $e', level: 'warn');
      return;
    }
  }

  /// 页面内发起探活请求，只回传**最小信号**，判定留给 Dart（那边才能单测）。
  ///
  /// 结果走既有 [QingyuBridge] 通道、以 `sessionProbe` 类型回来：这是**宿主自己
  /// 注入的**脚本，不是学校适配脚本，因此不碰上游协议——脚本保持 100% 上游标准、
  /// 可原样回馈的约定不受影响。
  String _sessionProbeScript(String target) {
    return '''
(() => {
  const target = ${jsonEncode(target)};
  const post = (payload) => {
    try {
      QingyuBridge.postMessage(JSON.stringify({
        type: 'sessionProbe',
        payload: JSON.stringify(payload)
      }));
    } catch (e) { /* bridge torn down: probe result dropped, import unaffected */ }
  };
  (async () => {
    try {
      const resp = await fetch(target, {
        credentials: 'include',
        redirect: 'follow',
        cache: 'no-store'
      });
      let html = '';
      try { html = await resp.text(); } catch (e) { html = ''; }
      let hasPasswordField = false;
      try {
        const doc = new DOMParser().parseFromString(html, 'text/html');
        hasPasswordField = !!doc.querySelector('input[type="password"]');
      } catch (e) { /* unparseable HTML counts as no password field; the Dart-side length check is the backstop */ }
      post({
        ok: true,
        status: Number(resp.status || 0),
        finalUrl: String(resp.url || ''),
        hasPasswordField: hasPasswordField,
        bodyLength: html.length
      });
    } catch (e) {
      post({
        ok: false,
        status: 0,
        finalUrl: '',
        hasPasswordField: false,
        bodyLength: 0,
        error: String((e && e.message) || e)
      });
    }
  })();
  return true;
})();
''';
  }

  void _handleSessionProbeMessage(Map<String, dynamic> message) {
    _sessionProbeTimer?.cancel();
    _sessionProbeTimer = null;
    if (!_sessionProbeInFlight) {
      return;
    }
    _sessionProbeInFlight = false;
    final signal = parseWarehouseSessionProbeSignal(
      message['payload'] as String?,
    );
    final verdict = classifyWarehouseSessionProbe(
      signal: signal,
      pageUrl: _currentUrl ?? widget.initialUrl,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _sessionProbeVerdict = verdict;
    });
    _debugImportLog(
      'session probe verdict=${verdict.name} '
      'status=${signal?.status} bytes=${signal?.bodyLength} '
      'passwordField=${signal?.hasPasswordField}',
    );
    // 结论落地：补判探针在途期间被推迟的弹窗决定（verdict 已非 unknown，
    // 重入 _handleLoginStateMessage 不会再被推迟）。
    unawaited(_evaluatePendingAutofillPrompt());
  }

  /// 探针出结论（或超时）后，补判被推迟的「要不要帮你填密码」决定。
  ///
  /// 超时路径的 verdict 仍是 unknown、inFlight 已收：重入时
  /// [sessionProbeMayStillSettle] 为假，按「这次没探成」的原行为放行弹窗——
  /// 等不到结论就退回今天的做法，绝不会把决定永远悬着。
  Future<void> _evaluatePendingAutofillPrompt() async {
    final pending = _pendingAutofillLoginState;
    if (pending == null) {
      return;
    }
    _pendingAutofillLoginState = null;
    await _handleLoginStateMessage(pending);
  }

  /// 用户刚尝试过登录，旧结论立刻作废（登录成功与否都要重探）。
  void _invalidateSessionProbeVerdict() {
    if (_sessionProbeVerdict == WarehouseSessionProbeVerdict.unknown) {
      return;
    }
    _sessionProbeOrigin = null;
    if (mounted) {
      setState(() {
        _sessionProbeVerdict = WarehouseSessionProbeVerdict.unknown;
      });
    }
  }

  void _disposeSessionProbe() {
    _sessionProbeTimer?.cancel();
    _sessionProbeTimer = null;
    // 页面在销毁，被推迟的弹窗决定随之作废——绝不能在 dispose 后弹对话框。
    _pendingAutofillLoginState = null;
  }

  /// 会话确实还在（探针判的，不是看页面猜的）。
  bool get _isSessionActive =>
      _sessionProbeVerdict == WarehouseSessionProbeVerdict.loggedIn;

  bool get _isBackgroundImportCancelled =>
      widget.runInBackground &&
      (widget.isBackgroundImportCancelled?.call() ?? false);

  /// 标记后台导入已经跨过取消边界。
  ///
  /// 取消边界必须覆盖时间方案、节次容量等前置写入，而不只是最后的课程写入；
  /// 一旦标记，取消按钮只等待真实结果，导入计时器也不再报告假失败。
  void _markBackgroundWriteStarted() {
    if (!widget.runInBackground || _backgroundWriteStarted) {
      return;
    }
    _backgroundWriteStarted = true;
    _cancelImportTimeout();
    widget.onBackgroundImportStarted?.call();
  }

  void _startImportTimeout() {
    if (widget.runInBackground && _backgroundWriteStarted) {
      _debugImportLog('skip import timeout after background write started');
      _cancelImportTimeout();
      return;
    }
    _notifyBackgroundProgress();
    _debugImportLog('start import timeout duration=$_importTimeout');
    _importTimeoutTimer?.cancel();
    _importTimeoutTimer = Timer(_importTimeout, () {
      _debugImportLog(
        'import timeout fired mounted=$mounted shouldRun=${mounted && _isExecutingImport}',
      );
      if (!mounted ||
          !_isExecutingImport ||
          (widget.runInBackground && _backgroundWriteStarted)) {
        return;
      }
      final waitingForMacroCourses =
          _isMacroReplay && _playbackState == PlaybackUiState.executingImport;
      final message = waitingForMacroCourses
          ? AppLocalizations.of(context)!.courseImportScriptNoCourses
          : AppLocalizations.of(context)!.executeFailedWithError('timeout');
      _debugImportLog(
        'timeout -> mark import failed waitingForMacroCourses=$waitingForMacroCourses message="$message"',
      );
      setState(() {
        _isExecutingImport = false;
        _lastScriptStatus = waitingForMacroCourses
            ? message
            : AppLocalizations.of(context)!.scriptInjectionFailed;
      });
      _showMacroReplayImportError(message);
      showImportLightTip(context, message);
    });
  }

  void _cancelImportTimeout() {
    _debugImportLog(
      'cancel import timeout hadTimer=${_importTimeoutTimer != null}',
    );
    _importTimeoutTimer?.cancel();
    _importTimeoutTimer = null;
  }

  bool get _isMacroReplay => widget.macroRecord != null;

  bool get _showImportScriptBar =>
      !_isMacroReplay || _playbackState == PlaybackUiState.hidden;

  void _showMacroReplayImportError(String message) {
    if (kDebugMode) {
      _debugImportLog(
        'show macro replay error message="$message"\n${StackTrace.current}',
      );
    }
    if (!_isMacroReplay || !mounted) return;
    setState(() {
      _playbackProgress = ReplayProgress(
        currentStepIndex: _playbackProgress.currentStepIndex,
        totalSteps: _playbackProgress.totalSteps == 0
            ? 1
            : _playbackProgress.totalSteps,
        currentStep: MacroStep.executeScript,
        status: ReplayStepStatus.failed,
        errorMessage: message,
      );
      _playbackState = PlaybackUiState.error;
    });
    if (widget.runInBackground) {
      _debugImportLog('background import error message="$message"');
      widget.onBackgroundFinished?.call(false);
    }
  }

  Future<void> _markMacroImportCompleted({
    required bool countSuccessfulImport,
  }) async {
    _debugImportLog(
      'mark macro import completed countSuccessfulImport=$countSuccessfulImport',
    );
    if (!_isMacroReplay) return;
    if (countSuccessfulImport) {
      final existing = await _macroService.getMacro(
        widget.school.id,
        widget.adapter.adapterId,
      );
      if (existing != null) {
        await _macroService.saveMacro(
          existing.copyWith(
            successfulImportCount: existing.successfulImportCount + 1,
            updatedAt: DateTime.now(),
            scriptPageUrl:
                sanitizeWarehouseScriptPageUrl(
                  _currentUrl ?? widget.initialUrl,
                ) ??
                existing.scriptPageUrl,
          ),
        );
      }
    }
    if (!mounted) return;
    setState(() {
      _playbackState = PlaybackUiState.hidden;
      _isExecutingImport = false;
    });
    await _showQuickImportFinishedSheet();
  }

  Future<void> _showQuickImportFinishedSheet() async {
    if (!mounted || _quickImportResultHandled) {
      return;
    }
    _quickImportResultHandled = true;
    if (widget.runInBackground) {
      _debugImportLog('background quick import finished successfully');
      widget.onBackgroundFinished?.call(true);
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    final status = (_lastScriptStatus ?? '').trim();
    final description = [
      '${widget.school.name} · ${widget.adapter.adapterName}',
      if (status.isNotEmpty) status,
    ].join('\n');

    await showHyperosSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      builder: (sheetContext) {
        return HyperosSheet(
          title: l10n.quickImportFinishedTitle,
          // Put result text above the dismiss button. HyperosSheet renders
          // [child] before [description], so compose layout in [child].
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              HyperosSectionDescription(text: description),
              const SizedBox(height: 16),
              HyperosButton(
                label: l10n.quickImportDismissAction,
                expand: true,
                onPressed: () => Navigator.pop(sheetContext),
              ),
            ],
          ),
        );
      },
    );

    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _executeImportScript() async {
    final l10n = AppLocalizations.of(context)!;
    _debugImportLog('execute import script start');
    _resetPendingImportedArtifacts();
    setState(() {
      _isExecutingImport = true;
      _lastScriptStatus = _isUsingLocalDebugScript
          ? l10n.injectingLocalDebugScript
          : l10n.injectingAdapterScript;
    });
    try {
      final script = _isUsingLocalDebugScript
          ? widget.debugScriptOverride!.trim()
          : await _repositoryService.fetchAdapterScript(
              widget.source,
              school: widget.school,
              adapter: widget.adapter,
              options: widget.fetchOptions,
            );
      if (script.trim().isEmpty) {
        _debugImportLog('execute import script rejected: empty script');
        if (!mounted) {
          return;
        }
        final emptyScriptMessage = l10n.courseImportScriptFailed;
        _cancelImportTimeout();
        setState(() {
          _isExecutingImport = false;
          _lastScriptStatus = emptyScriptMessage;
        });
        _showMacroReplayImportError(emptyScriptMessage);
        showImportLightTip(context, emptyScriptMessage);
        return;
      }
      final wrappedScript =
          '''
(() => {
  window.__qingyuResolvers = window.__qingyuResolvers || {};
  window.AndroidBridge = {
    showToast: (msg) => QingyuBridge.postMessage(JSON.stringify({type: 'toast', message: String(msg ?? '')})),
    notifyTaskCompletion: () => QingyuBridge.postMessage(JSON.stringify({type: 'complete'}))
  };
  window.AndroidBridgePromise = {
    showAlert: async (title, message, confirmText) => {
      const requestId = 'confirm_' + Date.now() + '_' + Math.random().toString(36).slice(2);
      return await new Promise((resolve) => {
        window.__qingyuResolvers[requestId] = resolve;
        QingyuBridge.postMessage(JSON.stringify({
          type: 'confirm',
          requestId,
          title: String(title ?? ''),
          message: String(message ?? ''),
          confirmText: String(confirmText ?? '${l10n.confirmImportAction}')
        }));
      });
    },
    showPrompt: async (title, message, defaultValue, validatorName) => {
      const requestId = 'prompt_' + Date.now() + '_' + Math.random().toString(36).slice(2);
      return await new Promise((resolve) => {
        window.__qingyuResolvers[requestId] = resolve;
        QingyuBridge.postMessage(JSON.stringify({
          type: 'prompt',
          requestId,
          title: String(title ?? ''),
          message: String(message ?? ''),
          defaultValue: String(defaultValue ?? ''),
          validatorName: String(validatorName ?? '')
        }));
      });
    },
    showSingleSelection: async (title, optionsJson, selectedIndex, dialogId) => {
      const requestId = 'single_selection_' + Date.now() + '_' + Math.random().toString(36).slice(2);
      return await new Promise((resolve) => {
        window.__qingyuResolvers[requestId] = resolve;
        QingyuBridge.postMessage(JSON.stringify({
          type: 'singleSelection',
          requestId,
          title: String(title ?? ''),
          optionsJson: String(optionsJson ?? '[]'),
          selectedIndex: Number(selectedIndex ?? 0),
          dialogId: dialogId ? String(dialogId) : undefined
        }));
      });
    },
    saveCourseConfig: async (json) => {
      const requestId = 'course_config_' + Date.now() + '_' + Math.random().toString(36).slice(2);
      return await new Promise((resolve) => {
        window.__qingyuResolvers[requestId] = resolve;
        QingyuBridge.postMessage(JSON.stringify({
          type: 'saveCourseConfig',
          requestId,
          payload: String(json ?? '{}')
        }));
      });
    },
    savePresetTimeSlots: async (json) => {
      const requestId = 'preset_time_slots_' + Date.now() + '_' + Math.random().toString(36).slice(2);
      return await new Promise((resolve) => {
        window.__qingyuResolvers[requestId] = resolve;
        QingyuBridge.postMessage(JSON.stringify({
          type: 'savePresetTimeSlots',
          requestId,
          payload: String(json ?? '[]')
        }));
      });
    },
    saveImportedCourses: async (json) => {
      QingyuBridge.postMessage(JSON.stringify({type: 'courses', payload: String(json ?? '[]')}));
      return true;
    }
  };
$kWarehouseBridgeCompatShim  try {
    $script
  } catch (error) {
    QingyuBridge.postMessage(JSON.stringify({type: 'error', message: String(error)}));
  }
})();
''';
      _debugImportLog('run import script scriptLength=${script.length}');
      await _controller.runJavaScript(wrappedScript);
      if (!mounted) {
        _debugImportLog('run import script finished after dispose');
        return;
      }
      _debugImportLog('run import script injected');
      setState(() {
        _lastScriptStatus = _isUsingLocalDebugScript
            ? AppLocalizations.of(context)!.localDebugScriptInjected
            : AppLocalizations.of(context)!.scriptInjected;
      });
      _startImportTimeout();
    } catch (error) {
      _debugImportLog('execute import script caught error=$error');
      if (!mounted) {
        return;
      }
      _cancelImportTimeout();
      final l10n = AppLocalizations.of(context)!;
      final message = l10n.executeFailedWithError(
        localizeServiceError(l10n, error),
      );
      setState(() {
        _isExecutingImport = false;
        _lastScriptStatus = l10n.scriptInjectionFailed;
      });
      _showMacroReplayImportError(message);
      showImportLightTip(context, message);
    }
  }

  /// Privileged bridge ops that mutate timetable data may only run while an
  /// import script (manual or macro replay) is actively executing.
  bool get _isPrivilegedBridgeContextActive =>
      _isExecutingImport ||
      (_isMacroReplay && _playbackState == PlaybackUiState.executingImport);

  Future<void> _handleBridgeMessage(String rawMessage) async {
    // 桥消息经平台通道异步派发，页面退出后仍可能到达；此时 State 已
    // defunct，WebView 也随之销毁，任何分支都不应再取 context 或回包。
    if (!mounted) {
      return;
    }
    _notifyBackgroundProgress();
    Map<String, dynamic>? message;
    try {
      message = jsonDecode(rawMessage) as Map<String, dynamic>;
    } catch (_) {
      return;
    }

    _debugImportLog('bridge ${_bridgeMessageSummary(message)}');
    final type = message['type'] as String? ?? '';
    switch (type) {
      case 'macro:event':
        _handleMacroEvent(message);
        break;
      case 'loginState':
        await _handleLoginStateMessage(message);
        break;
      case 'sessionProbe':
        // 宿主自己注入的探活脚本回话（不是学校脚本发的，见 [_sessionProbeScript]）。
        _handleSessionProbeMessage(message);
        break;
      case 'loginAttempt':
        await _handleLoginAttempt();
        break;
      case 'toast':
        if (!mounted) return;
        final toastMessage = (message['message'] as String?)?.trim() ?? '';
        if (toastMessage.isEmpty) {
          break;
        }
        // During quick-import / macro replay the host already shows a
        // completion sheet; suppress script success toasts that only report
        // "imported N courses" so users are not hit by two stacked tips.
        if (_isMacroReplay &&
            (_isScriptImportSuccessToast(toastMessage) ||
                _isScriptImportProgressToast(toastMessage))) {
          _debugImportLog(
            'bridge toast suppressed during macro replay message="$toastMessage"',
          );
          break;
        }
        showImportLightTip(context, toastMessage);
        break;
      case 'confirm':
        await _showScriptConfirmDialog(message);
        break;
      case 'prompt':
        await _showScriptPromptDialog(message);
        break;
      case 'singleSelection':
        await _showScriptSingleSelectionDialog(message);
        break;
      case 'saveCourseConfig':
        if (!_isPrivilegedBridgeContextActive) {
          _debugImportLog(
            'bridge saveCourseConfig ignored outside import execution',
          );
          break;
        }
        await _handleSaveCourseConfig(message);
        break;
      case 'savePresetTimeSlots':
        if (!_isPrivilegedBridgeContextActive) {
          _debugImportLog(
            'bridge savePresetTimeSlots ignored outside import execution',
          );
          break;
        }
        await _handleSavePresetTimeSlots(message);
        break;
      case 'error':
        if (!mounted) return;
        final l10n = AppLocalizations.of(context)!;
        final errorMessage =
            (message['message'] as String?) ?? l10n.courseImportScriptFailed;
        _debugImportLog('bridge error -> mark failed message="$errorMessage"');
        _cancelImportTimeout();
        setState(() {
          _isExecutingImport = false;
          _lastScriptStatus = l10n.courseImportScriptFailed;
        });
        _showMacroReplayImportError(errorMessage);
        showImportLightTip(context, errorMessage);
        break;
      case 'courses':
        if (!_isPrivilegedBridgeContextActive) {
          _debugImportLog('bridge courses ignored outside import execution');
          break;
        }
        final payload = (message['payload'] as String?) ?? '[]';
        _debugImportLog(
          'bridge courses -> handle payloadLength=${payload.length}',
        );
        await _handleImportedCoursesJson(payload);
        break;
      case 'complete':
        if (!mounted) return;
        final status = AppLocalizations.of(context)!.importFlowFinished;
        _debugImportLog('bridge complete entered');
        if (_isMacroReplay) {
          if (_playbackState == PlaybackUiState.executingImport) {
            _debugImportLog(
              'bridge complete ignored for macro replay while waiting for courses',
            );
            setState(() {
              _lastScriptStatus = status;
            });
            break;
          }
          if (_quickImportResultHandled) {
            _debugImportLog(
              'bridge complete ignored because quick import result already shown',
            );
            break;
          }
        }
        _debugImportLog('bridge complete -> finish non-macro import flow');
        _cancelImportTimeout();
        setState(() {
          _isExecutingImport = false;
          _lastScriptStatus = status;
        });
        break;
    }
  }

  Future<void> _showScriptConfirmDialog(Map<String, dynamic> message) async {
    if (!mounted) {
      return;
    }
    final requestId = (message['requestId'] as String?) ?? '';
    // 回放模式：使用录制的响应或自动确认
    final macroRecord = widget.macroRecord;
    if (macroRecord != null) {
      final key = _dialogResponseKey('confirm', message);
      final recorded = macroRecord.dialogResponses[key];
      // Unrecorded confirms default to true so automated import scripts are
      // not cancelled just because the old macro never saw this dialog.
      final shouldConfirm = recorded == null ? true : recorded == true;
      await _resolveJavaScriptRequest(requestId, shouldConfirm);
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showAppConfirmDialog(
      context,
      title: (message['title'] as String?)?.trim().isNotEmpty == true
          ? (message['title'] as String)
          : l10n.confirmImportAction,
      message: (message['message'] as String?) ?? l10n.defaultContinuePrompt,
      confirmLabel:
          (message['confirmText'] as String?) ?? l10n.confirmImportAction,
    );
    // 录制模式：记住用户的选择
    if (_macroRecordingState == MacroRecordingState.recording) {
      final key = _dialogResponseKey('confirm', message);
      _macroDialogResponses[key] = confirmed == true;
    }
    await _resolveJavaScriptRequest(requestId, confirmed == true);
  }

  Future<void> _showScriptPromptDialog(Map<String, dynamic> message) async {
    if (!mounted) {
      return;
    }
    final requestId = (message['requestId'] as String?) ?? '';
    // 回放模式：使用录制的响应或默认值
    final macroRecord = widget.macroRecord;
    if (macroRecord != null) {
      final key = _dialogResponseKey('prompt', message);
      final recorded = macroRecord.dialogResponses[key];
      await _resolveJavaScriptRequest(
        requestId,
        '${recorded ?? (message['defaultValue'] as String? ?? '')}',
      );
      return;
    }
    final validatorName = (message['validatorName'] as String?) ?? '';
    final l10n = AppLocalizations.of(context)!;
    final result = await showAppTextInputDialog(
      context,
      title: (message['title'] as String?) ?? l10n.inputRequiredTitle,
      confirmLabel: l10n.saveAction,
      initialValue: (message['defaultValue'] as String?) ?? '',
      validate: (text) {
        if (validatorName == 'validateYearInput' &&
            !RegExp(r'^[0-9]{4}$').hasMatch(text)) {
          showImportLightTip(context, l10n.pleaseEnterFourDigitYear);
          return false;
        }
        return true;
      },
      bodyBuilder: (controller) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text((message['message'] as String?) ?? ''),
          const SizedBox(height: 12),
          HyperosTextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.number,
          ),
        ],
      ),
    );
    // 录制模式：记住用户输入
    if (_macroRecordingState == MacroRecordingState.recording) {
      final key = _dialogResponseKey('prompt', message);
      if (result != null) _macroDialogResponses[key] = result;
    }
    await _resolveJavaScriptRequest(requestId, result);
  }

  Future<void> _showScriptSingleSelectionDialog(
    Map<String, dynamic> message,
  ) async {
    if (!mounted) {
      return;
    }
    final requestId = (message['requestId'] as String?) ?? '';
    final macroRecord = widget.macroRecord;
    if (macroRecord != null) {
      final key = _dialogResponseKey('singleSelection', message);
      final recorded = macroRecord.dialogResponses[key];
      final optionsRaw = (message['optionsJson'] as String?) ?? '[]';
      final selectedIndex = (message['selectedIndex'] as num?)?.toInt() ?? 0;
      List<String> options = const [];
      try {
        final decoded = jsonDecode(optionsRaw);
        if (decoded is List) {
          options = decoded.map((item) => item.toString()).toList(growable: false);
        }
      } catch (_) {
        // 与下方正式弹窗同一套兜底：解析失败按空选项处理，不中断导入。
      }
      if (recorded != null) {
        // 录制侧存的是**用户选的那一项的文字**（这样宿主调整选项顺序也不会选错），
        // 而脚本要的是**序号**。直接回文字会让每个按序号解析的脚本在录制导入下立刻
        // 变成「导入已取消」（2026-09-29 城科真机：弹窗出现后 10ms 就返回取消）。
        // 这里把文字还原成下标；答案已过期（选项变了）时退回脚本给的默认值。
        final resolved = resolveRecordedSelectionIndex(
          recorded: recorded,
          options: options,
          fallbackIndex: selectedIndex,
        );
        _debugImportLog(
          'singleSelection replay recorded=$recorded options=${options.length} '
          'resolved=$resolved fallback=$selectedIndex',
        );
        await _resolveJavaScriptRequest(requestId, resolved);
        return;
      }
      if (widget.runInBackground) {
        // Prefer the script-provided selection; fall back to first option.
        await _resolveJavaScriptRequest(requestId, selectedIndex);
        return;
      }
    }
    final optionsRaw = (message['optionsJson'] as String?) ?? '[]';
    final selectedIndex = (message['selectedIndex'] as num?)?.toInt() ?? 0;
    List<String> options = const [];
    try {
      final decoded = jsonDecode(optionsRaw);
      if (decoded is List) {
        options = decoded
            .map((item) => item.toString())
            .toList(growable: false);
      }
    } catch (_) {
      // 解析失败按空选项兜底（下方对话框以空列表呈现），此处属脚本侧
      // 数据异常而非关键路径，留兜底不中断导入。
    }
    final currentSelection = selectedIndex.clamp(
      0,
      options.isEmpty ? 0 : options.length - 1,
    );
    final l10n = AppLocalizations.of(context)!;
    final result = await showAppSingleChoiceDialog(
      context,
      title: (message['title'] as String?) ?? l10n.pleaseChooseTitle,
      options: options,
      initialIndex: currentSelection,
      confirmLabel: l10n.saveAction,
    );
    // 录制模式：记住用户的选择
    if (_macroRecordingState == MacroRecordingState.recording &&
        result != null &&
        options.isNotEmpty) {
      final key = _dialogResponseKey('singleSelection', message);
      if (result >= 0 && result < options.length) {
        _macroDialogResponses[key] = options[result];
      }
    }
    await _resolveJavaScriptRequest(requestId, result);
  }

  Future<void> _handleSaveCourseConfig(Map<String, dynamic> message) async {
    final requestId = (message['requestId'] as String?) ?? '';
    try {
      final decoded = jsonDecode((message['payload'] as String?) ?? '{}');
      if (decoded is! Map) {
        throw FormatException(
          AppLocalizations.of(context)!.invalidCourseConfigFormat,
        );
      }
      final provider = context.read<TimetableProvider>();
      // 解析与「无效值不覆盖用户设置」的判定都在纯函数里（此前这段逻辑内联在
      // 屏幕上，配套测试又把同样的判断在测试里重写了一遍，生产逻辑改反也照样绿）。
      final resolvedConfig = WarehouseCourseConfigLogic.resolve(decoded);
      final semesterTotalWeeks = resolvedConfig.semesterWeekCount;
      final semesterStartDate = resolvedConfig.semesterStartDate;
      // 上游 184 个脚本还会下发这三项，但本 App 没有对应设置可落：
      // firstDayOfWeek —— 周起始日在 week_calculator / statistics / 考试排期
      //   三处均硬编码为周一，没有可配置项；
      // defaultClassDuration / defaultBreakDuration —— 只在
      //   buildQuickSectionTimes 生成模板时当入参用，模型不持久化。
      // 记一笔到执行日志便于日后定位，不静默丢弃。
      final ignoredKeys = warehouseUnsupportedCourseConfigKeys
          .where((key) => decoded[key] != null)
          .toList(growable: false);
      if (ignoredKeys.isNotEmpty) {
        _debugImportLog(
          'courseConfig received-but-unsupported keys=$ignoredKeys',
        );
      }
      final hasWeekCount = semesterTotalWeeks != null;
      if (resolvedConfig.hasAnything) {
        if (_isBackgroundImportCancelled) {
          await _resolveJavaScriptRequest(requestId, false);
          return;
        }
        _markBackgroundWriteStarted();
        // copyWith 对 null 取「保持原值」，所以脚本没下发的字段不会被清空。
        final result = await provider.updateTimetableSettings(
          provider.settings.copyWith(
            semesterWeekCount: hasWeekCount ? semesterTotalWeeks : null,
            semesterStartDate: semesterStartDate,
          ),
        );
        if (result != null) {
          throw FormatException(result);
        }
        _debugImportLog(
          'courseConfig applied weeks=${hasWeekCount ? semesterTotalWeeks : "keep"} '
          'startDate=${semesterStartDate?.toIso8601String() ?? "keep"}',
        );
      }
      await _resolveJavaScriptRequest(requestId, true);
    } catch (error) {
      if (widget.runInBackground) {
        widget.onBackgroundFinished?.call(false);
      }
      if (!mounted) return;
      showImportLightTip(
        context,
        AppLocalizations.of(context)!.saveCourseConfigFailedWithError('$error'),
      );
      await _resolveJavaScriptRequest(requestId, false);
    }
  }

  Future<void> _handleSavePresetTimeSlots(Map<String, dynamic> message) async {
    final requestId = (message['requestId'] as String?) ?? '';
    try {
      final sections = _decodeImportedSections(
        (message['payload'] as String?) ?? '[]',
      );
      _pendingImportedSections = sections;
      _pendingImportedSectionsSignature = _buildSectionSignature(sections);
      // 脚本自己选中的那套作息留一份副本。轻屿专属条目（`qingyu_only/`）靠它
      // 判断用户在脚本的「选择作息」里选的是哪一套 —— 见
      // `_applyQingyuOnlyLocationTimeSchemes`。放在这里而不是等要用时再从
      // _pendingImportedSections 取，是因为那套 pending 生命周期很短，apply 之后
      // 就不在了。
      _scriptSuppliedSections = List<SectionTime>.from(sections);
      if (_isBackgroundImportCancelled) {
        await _resolveJavaScriptRequest(requestId, false);
        return;
      }
      await _applyPendingImportedSectionsIfNeeded();
      await _resolveJavaScriptRequest(requestId, true);
    } catch (error) {
      if (widget.runInBackground) {
        widget.onBackgroundFinished?.call(false);
      }
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      showImportLightTip(
        context,
        l10n.saveSectionTimesFailedWithError(localizeServiceError(l10n, error)),
      );
      await _resolveJavaScriptRequest(requestId, false);
    }
  }


  Future<void> _resolveJavaScriptRequest(
    String requestId,
    Object? value,
  ) async {
    if (!_isSafeBridgeRequestId(requestId)) {
      _debugImportLog('reject unsafe bridge requestId');
      return;
    }
    final encodedValue = jsonEncode(value);
    final encodedRequestId = jsonEncode(requestId);
    await _controller.runJavaScript(
      'window.__qingyuResolvers = window.__qingyuResolvers || {}; '
      'window.__qingyuResolvers[$encodedRequestId]?.($encodedValue); '
      'delete window.__qingyuResolvers[$encodedRequestId];',
    );
  }

  /// Bridge request ids must be alphanumeric tokens (no quotes / script).
  bool _isSafeBridgeRequestId(String requestId) {
    if (requestId.isEmpty || requestId.length > 128) {
      return false;
    }
    for (var index = 0; index < requestId.length; index++) {
      final codeUnit = requestId.codeUnitAt(index);
      final isUpperLetter = codeUnit >= 65 && codeUnit <= 90;
      final isLowerLetter = codeUnit >= 97 && codeUnit <= 122;
      final isDigit = codeUnit >= 48 && codeUnit <= 57;
      final isAllowedSymbol =
          codeUnit == 95 || codeUnit == 46 || codeUnit == 45;
      if (!isUpperLetter && !isLowerLetter && !isDigit && !isAllowedSymbol) {
        return false;
      }
    }
    return true;
  }

  Future<void> _handleImportedCoursesJson(String payload) async {
    _debugImportLog('handle courses start payloadLength=${payload.length}');
    // 每次课程导入重新计数。这里是协议里唯一的课程入口
    // （`saveImportedCourses`），所以在它开头清零比在解析函数里清零更准确：
    // 即使某个脚本连发两次，第二次的计数也会累加上来而不是覆盖掉。
    _warehouseCourseSkips.clear();
    // 作息恢复点 + 「课程是否真的落地」标志：教务脚本下发的作息表在**课程写库之前**
    // 就被切/建成当前生效的那套，所以只要课程没落地，下面 finally 就必须把作息切回去
    // （否则用户什么都没干，作息却被永久换成了教务那套）。理由见
    // [_TimeSchemeRestorePoint] 的注释。
    ImportTimeSchemeRestorePoint? schemeRestorePoint;
    var coursesImported = false;    try {
      final decoded = jsonDecode(payload);
      _debugImportLog('courses decoded type=${decoded.runtimeType}');
      if (decoded is! List) {
        throw FormatException(
          AppLocalizations.of(context)!.invalidCourseDataFormat,
        );
      }
      final parsedCourses = _parseWarehouseCourses(decoded);
      _debugImportLog('courses parsed count=${parsedCourses.length}');
      if (parsedCourses.isEmpty) {
        throw FormatException(
          AppLocalizations.of(context)!.noImportableCoursesFromScript,
        );
      }

      final provider = context.read<TimetableProvider>();
      // 回放/录制模式：使用录制的替换/合并选择
      bool? recordedReplaceExisting;
      ImportSemesterConfig? recordedSemesterConfig;
      final recording = _macroRecordingState == MacroRecordingState.recording;
      final replaying = widget.macroRecord != null;

      if (replaying) {
        final r = widget.macroRecord!.dialogResponses['replaceExisting'];
        if (r is bool) recordedReplaceExisting = r;
        final s = widget.macroRecord!.dialogResponses['semesterConfig'];
        if (s is Map) {
          final startDate = DateTime.tryParse(s['startDate'] as String? ?? '');
          final week = s['firstCourseWeek'] as int?;
          if (startDate != null && week != null) {
            recordedSemesterConfig = ImportSemesterConfig(
              semesterStartDate: startDate,
              firstCourseWeek: week,
            );
          }
        }
      }

      final replaceExisting = provider.courses.isEmpty
          ? true
          : recordedReplaceExisting ??
                (widget.runInBackground
                    ? false
                    : await askImportReplaceExisting(
                        context,
                        title: AppLocalizations.of(context)!.courseImportTitle,
                        content: AppLocalizations.of(
                          context,
                        )!.importCourseCountPrompt(parsedCourses.length),
                      ));
      if (replaceExisting == null || !mounted) {
        _debugImportLog(
          'courses import aborted at replaceExisting mounted=$mounted value=$replaceExisting',
        );
        _cancelImportTimeout();
        if (!mounted) return;
        final status = AppLocalizations.of(context)!.importCancelledStatus;
        setState(() {
          _isExecutingImport = false;
          _lastScriptStatus = status;
        });
        _showMacroReplayImportError(status);
        return;
      }
      if (recording) {
        _macroDialogResponses['replaceExisting'] = replaceExisting;
      }

      final semesterConfig =
          recordedSemesterConfig ??
          (widget.runInBackground
              ? ImportSemesterConfig(
                  semesterStartDate:
                      provider.settings.semesterStartDate ?? DateTime.now(),
                  firstCourseWeek: 1,
                )
              : await pickImportSemesterConfig(
                  context,
                  initialSemesterStartDate:
                      provider.settings.semesterStartDate ?? DateTime.now(),
                  initialFirstCourseWeek: 1,
                  title: AppLocalizations.of(
                    context,
                  )!.importConfirmSemesterMappingTitle,
                  subtitle: AppLocalizations.of(
                    context,
                  )!.importConfirmSemesterMappingSubtitleWarehouse,
                ));
      if (semesterConfig == null || !mounted) {
        _debugImportLog(
          'courses import aborted at semesterConfig mounted=$mounted hasConfig=${semesterConfig != null}',
        );
        _cancelImportTimeout();
        if (!mounted) return;
        final status = AppLocalizations.of(context)!.importCancelledStatus;
        setState(() {
          _isExecutingImport = false;
          _lastScriptStatus = status;
        });
        _showMacroReplayImportError(status);
        return;
      }
      if (recording) {
        _macroDialogResponses['semesterConfig'] = {
          'startDate': semesterConfig.semesterStartDate.toIso8601String(),
          'firstCourseWeek': semesterConfig.firstCourseWeek,
        };
      }

      final alignedCourses = _weekAlignmentService.shiftCoursesToSemesterWeeks(
        parsedCourses,
        firstCourseWeek: semesterConfig.firstCourseWeek,
      );
      await _waitForCompanionImportSections();
      if (!mounted) {
        return;
      }
      if (_isBackgroundImportCancelled && _pendingImportedSections != null) {
        widget.onBackgroundFinished?.call(false);
        return;
      }
      // 记下"切作息之前"那份设置：后面任何一条中止路径都靠它把作息切回来。
      schemeRestorePoint = ImportTimeSchemeRestorePoint.capture(provider);
      try {
        await _applyPendingImportedSectionsIfNeeded();
      } catch (error) {
        if (mounted) {
          final l10n = AppLocalizations.of(context)!;
          showImportLightTip(
            context,
            l10n.applyReturnedTimeSchemeFailed(
              localizeServiceError(l10n, error),
            ),
          );
        }
      }
      // 轻屿专属作息：脚本那套全局作息只覆盖校区/教学楼都相同的情形，这里按
      // 教室名把每门课分到各自那套。放在脚本那套之后 —— 专属数据要覆盖它，
      // 否则课程会读到脚本选的那一套。
      //
      // 失败不中断导入：脚本已经下发了一套可用作息，退回那套比整次导入失败好。
      try {
        await _applyQingyuOnlyLocationTimeSchemes();
      } catch (error) {
        _debugImportLog('qingyu_only time schemes skipped: $error');
      }
      final requiredSectionCount = provider
          .previewImportedCourseRequiredSectionCount(
            alignedCourses,
            replaceExisting: replaceExisting,
          );
      if (!mounted) {
        return;
      }
      final capacityReady = await ensureImportSectionCapacity(
        context,
        requiredSectionCount: requiredSectionCount,
        provider: provider,
        onWriteStart: _markBackgroundWriteStarted,
        isCancelled: () => _isBackgroundImportCancelled,
      );
      if (!capacityReady || !mounted) {
        _debugImportLog(
          'courses import aborted at capacity mounted=$mounted capacityReady=$capacityReady requiredSectionCount=$requiredSectionCount',
        );
        _cancelImportTimeout();
        // 收尾回调：这条路径必须和同函数里其余 5 条结束路径（取消、写盘失败、课表
        // 为空 …）做同一个动作，否则后台导入的会话永不结束——用户点取消后首页要
        // 空转到看门狗兜底（2 分钟），走错误码那条更久（5 分钟），而且看到的是
        // 「需要手动操作」这种并不存在的失败。语义上它是「正常结束」，不是崩溃。
        if (widget.runInBackground) {
          widget.onBackgroundFinished?.call(false);
        }
        if (!mounted) return;
        final status = AppLocalizations.of(context)!.importInterruptedStatus;
        setState(() {
          _isExecutingImport = false;
          _lastScriptStatus = status;
        });
        _showMacroReplayImportError(status);
        return;
      }

      final coursesToImport = await coursesWithOptionalRandomColors(
        alignedCourses,
      );
      if (!mounted) {
        return;
      }
      final preserveLocalColors = await shouldPreserveLocalColorsOnImport(
        replaceExisting: replaceExisting,
      );
      if (!mounted) {
        if (widget.runInBackground) {
          widget.onBackgroundFinished?.call(false);
        }
        return;
      }
      if (_isBackgroundImportCancelled && !_backgroundWriteStarted) {
        widget.onBackgroundFinished?.call(false);
        return;
      }
      _debugImportLog(
        'importParsedCourses start alignedCount=${coursesToImport.length} replaceExisting=$replaceExisting semesterStart=${semesterConfig.semesterStartDate.toIso8601String()}',
      );
      _notifyBackgroundProgress();
      if (coursesToImport.isNotEmpty) {
        _markBackgroundWriteStarted();
      }
      final importedCount = await provider.importParsedCourses(
        coursesToImport,
        replaceExisting: replaceExisting,
        semesterStart: semesterConfig.semesterStartDate,
        source: 'warehouse',
        preserveLocalColors: preserveLocalColors,
      );
      _debugImportLog('importParsedCourses done importedCount=$importedCount');
      // 课程已经落库：这套作息就是它们的依据，之后任何失败都不再回滚作息。
      coursesImported = true;
      _notifyBackgroundProgress();
      if (!mounted) {
        if (widget.runInBackground) {
          widget.onBackgroundFinished?.call(true);
        }
        return;
      }
      await _preferencesService.addRecentSchool(widget.school.id);
      _notifyBackgroundProgress();
      if (!mounted) {
        if (widget.runInBackground) {
          widget.onBackgroundFinished?.call(true);
        }
        return;
      }
      final l10n = AppLocalizations.of(context)!;
      final baseStatus = importedCount > 0
          ? l10n.importUpdatedCount(importedCount)
          : l10n.importNoCourseChanges;
      // 如实补一句少了什么。「一门课数据脏一点」不该由用户在课表上凭空发现。
      final skipNotice = _warehouseSkipNotice(l10n, importedCount);
      final status = skipNotice == null ? baseStatus : '$baseStatus $skipNotice';
      setState(() {
        _lastScriptStatus = status;
      });
      final navigator = Navigator.of(context);
      // Quick-import replay already shows a completion sheet with the same
      // status text; skip the 2s light tip to avoid a double toast.
      if (!replaying) {
        showImportLightTip(context, status);
      }
      _cancelImportTimeout();
      _debugImportLog('courses import success path -> set executing false');
      setState(() {
        _isExecutingImport = false;
      });
      if (importedCount > 0) {
        _debugImportLog(
          'courses import positive result recording=$recording replaying=$replaying',
        );
        // 导入成功，如果正在录制宏则自动结束录制并保存
        if (_macroRecordingState == MacroRecordingState.recording) {
          await _completeMacroAndPop();
        } else if (replaying) {
          await _markMacroImportCompleted(countSuccessfulImport: true);
        } else {
          navigator.pop(true);
        }
      } else if (replaying) {
        _debugImportLog(
          'courses import no changes but replaying -> mark completed without count',
        );
        await _markMacroImportCompleted(countSuccessfulImport: false);
      }
    } catch (error) {
      if (kDebugMode) {
        _debugImportLog(
          'handle courses caught error=$error\n${StackTrace.current}',
        );
      }
      if (widget.runInBackground) {
        widget.onBackgroundFinished?.call(false);
      }
      if (!mounted) return;
      _cancelImportTimeout();
      final message = AppLocalizations.of(
        context,
      )!.importFailedWithError('$error');
      setState(() {
        _isExecutingImport = false;
        _lastScriptStatus = AppLocalizations.of(context)!.importFailedStatus;
      });
      _showMacroReplayImportError(message);
      showImportLightTip(context, message);
    } finally {
      // 中止路径统一收口：课程没落地就把作息切回去。放在 finally 而不是逐个 return
      // 加一句，是因为这个函数有 8 个提前 return（未挂载 / 取消 / 容量弹窗 false /
      // 学期映射取消 …），逐处补一定会漏一处 —— 漏掉的那条就是"什么都没干但作息被
      // 换掉"。
      final point = schemeRestorePoint;
      if (!coursesImported && point != null) {
        await point.restore();
      }
    }
  }

  /// 按名 upsert 一条时间模板，返回它的 id。名字相同视为同一套（重复导入不会
  /// 攒出一堆同名模板）。
  Future<String> _upsertImportedTimeScheme(
    String name,
    List<SectionTime> sections,
  ) async {
    final provider = context.read<TimetableProvider>();
    for (final scheme in provider.timeSchemes) {
      if (scheme.name != name) {
        continue;
      }
      final result = await provider.updateTimeScheme(
        schemeId: scheme.id,
        name: scheme.name,
        sections: sections,
      );
      if (result != null) {
        throw FormatException(result);
      }
      return scheme.id;
    }
    final created = await provider.createTimeScheme(
      name: name,
      sections: sections,
    );
    return created.id;
  }

  /// 应用轻屿专属作息（`qingyu_only/<目录>/time_schemes.json`）。
  ///
  /// 做三件事：把该校区下每套作息各存成一条时间模板；给带关键词的那几套建「地点
  /// 时间分组」，按教室名路由；最后套用兜底那套作为课表默认。
  ///
  /// **校区不问用户**：脚本自己已经问过「选择学校作息时间表」，这里用脚本下发的
  /// 节次时间与数据文件逐节比对反推（见 `campusForSections`）。判不出来时按
  /// 「唯一校区直接用，否则不套用专属作息」处理——宁可退回脚本那套全局作息，
  /// 也不要替用户猜一个校区然后把作息套错。
  ///
  /// 分组按名 upsert：脚本提到的同名分组被覆盖；**他校自动建的分组一并清除**
  /// （教学楼名跨校撞车，留着会把新校教室错分到旧校作息——组上带来源标记，
  /// 见 [mergeLocationTimeGroupsForImport]）；用户手建的分组不带标记，一律保留。
  Future<void> _applyQingyuOnlyLocationTimeSchemes() async {
    final adapter = widget.adapter;
    if (!adapter.isQingyuOnly || adapter.timeSchemesFile.isEmpty) {
      return;
    }
    final raw = await _repositoryService.fetchQingyuOnlyText(
      widget.source,
      widget.school,
      adapter.timeSchemesFile,
      options: widget.fetchOptions,
    );
    final parsed = QingyuOnlyTimeSchemesLogic.parse(jsonDecode(raw));
    final campus =
        parsed.campusForSections(_scriptSuppliedSections ?? const []) ??
        parsed.soleCampus;
    if (campus == null) {
      _debugImportLog(
        'qingyu_only campus undetermined campuses=${parsed.campuses.length} '
        'scriptSections=${_scriptSuppliedSections?.length ?? 0}',
      );
      return;
    }
    _debugImportLog(
      'qingyu_only applying campus=${campus.id} schemes=${campus.schemes.length}',
    );

    if (!mounted) {
      return;
    }
    final provider = context.read<TimetableProvider>();
    if (_isBackgroundImportCancelled) {
      return;
    }
    _markBackgroundWriteStarted();

    final incoming = <LocationTimeGroup>[];
    String? fallbackSchemeId;
    for (final scheme in campus.schemes) {
      final schemeId = await _upsertImportedTimeScheme(scheme.name, scheme.sections);
      if (scheme.isFallback) {
        fallbackSchemeId = schemeId;
        continue;
      }
      incoming.add(
        LocationTimeGroup(
          id: const Uuid().v4(),
          name: scheme.name,
          timeSchemeId: schemeId,
          priority: incoming.length,
          keywords: scheme.keywords,
          // 来源标记：换校导入时据此清掉他校自动组（教学楼名跨校撞车）。
          // 手建组不带标记、永不清理。见 mergeLocationTimeGroupsForImport。
          sourceSchoolId: widget.school.id,
        ),
      );
    }
    if (fallbackSchemeId == null) {
      // 解析层已保证每校区恰好一套兜底，走到这里说明数据与代码的约定脱节了。
      // 什么都不改比只改一半好。
      _debugImportLog('qingyu_only campus has no fallback scheme, skipped');
      return;
    }

    final merged = mergeLocationTimeGroupsForImport(
      existing: provider.locationTimeGroups,
      incoming: incoming,
      schoolId: widget.school.id,
    );
    await provider.replaceLocationTimeGroups(merged);
    final applyError = await provider.applyTimeScheme(fallbackSchemeId);
    if (applyError != null) {
      throw FormatException(applyError);
    }
  }

  /// 教务凭据允许自动填充的站点：适配器在仓库里登记的登录地址，加上用户为它  /// 自定义的地址。两者都是 App 自己会把 WebView 带过去的地方。
  ///
  /// Why this exists: `host` 从 v2.1.3.2 起才随凭据一起落盘，在那之前
  /// 存下的每一条凭据 host 都是空的。门禁原本对空 host 一律放行，于是**升级
  /// 到修好之后的版本的老用户，门禁依然是全开的**。改成"只认 App 会导航过去
  /// 的站点"之后，存量数据也纳入了保护；用户下次保存密码时 host 会自动补上。
  Future<List<String>> _warehouseAutofillTrustedHosts() async {
    final hosts = <String>[];
    final registered = extractUrlHost(widget.adapter.importUrl);
    if (registered != null) {
      hosts.add(registered);
    }
    try {
      final custom = await _preferencesService.getCustomImportUrl(
        widget.adapter.adapterId,
      );
      // ⚠️ 2026-08~10 补这道校验：自定义地址**随云同步下发**
      // （`WarehouseSyncBundle.customImportUrls` → `AppSyncSnapshot.warehouse`），
      // 而 `setCustomImportUrl` 原本只 `trim()` 就落盘。原先这里无条件把它的
      // host 加进自动填充白名单 ⇒ 一份构造过的云端快照就能让已保存的教务
      // 密码自动填到攻击者站点上。
      // 判据见 `isTrustedCustomImportUrl`：必须 https，且必须是登记地址本身
      // 或其子域（学校常把教务挂在 `jwxt.example.edu.cn`，登记的是
      // `example.edu.cn`；`example.edu.cn.evil.com` 这种后缀伪装则被拒）。
      if (isTrustedCustomImportUrl(
        url: custom ?? '',
        registeredHost: registered,
      )) {
        final customHost = extractUrlHost(custom);
        if (customHost != null) {
          hosts.add(customHost);
        }
      }
    } catch (_) {
      // 读不到自定义地址就只认登记地址。门禁因此更严，不会更松。
    }
    return hosts;
  }

  void _recordWarehouseCourseSkip(
    WarehouseCourseSkipReason reason,
    String? name, {
    Object? error,
  }) {
    _warehouseCourseSkips.update(
      reason,
      (count) => count + 1,
      ifAbsent: () => 1,
    );
    // 解析层的 catch 是「全抓」的：一条脏记录不该毁掉整批。代价是真正的编程
    // bug（字段形状变了导致 TypeError）也会走这条路，所以异常对象必须记下来 ——
    // 否则它和「脚本数据脏」在日志里长得一模一样，堆栈就永久丢了。
    _debugImportLog(
      'course record skipped reason=${reason.name} name=${name ?? '-'}'
      '${error == null ? '' : ' error=$error'}',
    );
  }

  /// 本次导入里「整条没进来」的条数（[WarehouseCourseSkipReason.unusable] 与
  /// [WarehouseCourseSkipReason.malformed]），以及「进来了但周次被削」的条数。
  ///
  /// 两者分开报：前者是课表上凭空少课，后者是课上着但少显示几周——后者更隐蔽，
  /// 学生只会以为自己那几周没课。
  ({int dropped, int trimmedWeeks}) _warehouseSkipSummary() {
    var dropped = 0;
    var trimmed = 0;
    _warehouseCourseSkips.forEach((reason, count) {
      if (reason == WarehouseCourseSkipReason.partialWeeks) {
        trimmed += count;
      } else {
        dropped += count;
      }
    });
    return (dropped: dropped, trimmedWeeks: trimmed);
  }

  /// 在导入结果后面如实补一句少了什么。返回 null 表示没什么要补的。
  String? _warehouseSkipNotice(AppLocalizations l10n, int importedCount) {
    final summary = _warehouseSkipSummary();
    if (summary.dropped == 0 && summary.trimmedWeeks == 0) {
      return null;
    }
    final parts = <String>[];
    if (summary.dropped > 0) {
      parts.add(
        l10n.importCourseRecordsDropped(summary.dropped, importedCount),
      );
    }
    if (summary.trimmedWeeks > 0) {
      parts.add(l10n.importCourseWeeksTrimmed(summary.trimmedWeeks));
    }
    return parts.join(' ');
  }

  List<Course> _parseWarehouseCourses(List<dynamic> rawCourses) {
    final l10n = AppLocalizations.of(context)!;
    return WarehouseCourseImportLogic.parse(
      rawCourses,
      idFactory: () => const Uuid().v4(),
      unknownTeacher: l10n.unknownTeacher,
      unknownLocation: l10n.unknownLocation,
      onSkip: _recordWarehouseCourseSkip,
    );
  }

  /// 诊断：登录页自动填充决策日志。loginState 消息在页面存活期内会高频
  /// 到达（定时探针 + DOM 监听），因此同一状态组合只记一条，换页重置；
  /// 只含布尔，不含凭据值。缺了它，「这次为什么没自动填密码」无法从
  /// 日志定位——所有门禁分支此前都是静默 return。
  void _logLoginStateAutofillDecision({
    required bool gateAllows,
    required bool hasPasswordField,
    required bool rememberedExists,
    required bool rememberedPasswordEmpty,
    required bool candidatePasswordEmpty,
    required bool hasPromptedAutofill,
    required bool sessionActive,
  }) {
    final key = 'gateAllows=$gateAllows hasPasswordField=$hasPasswordField '
        'remembered=$rememberedExists '
        'rememberedPasswordEmpty=$rememberedPasswordEmpty '
        'candidatePasswordEmpty=$candidatePasswordEmpty '
        'hasPromptedAutofill=$hasPromptedAutofill '
        'sessionActive=$sessionActive';
    if (key == _lastLoginStateDecisionKey) {
      return;
    }
    _lastLoginStateDecisionKey = key;
    _debugImportLog('loginState autofill decision $key');
  }

  Future<void> _handleLoginStateMessage(Map<String, dynamic> message) async {
    final hasPasswordField = message['hasPasswordField'] == true;
    final candidate = WarehouseRememberedLogin(
      username: (message['username'] as String? ?? '').trim(),
      password: (message['password'] as String? ?? '').trim(),
    );
    _latestLoginCandidate = candidate;

    // W7 凭据绑定站点：自动填充只允许发生在凭据来源的同一 host。
    // 跨源页面（钓鱼页 / 换站）不提示也不回放填充；手动「填充」菜单
    // 属于用户看清当前页面后的显式动作，不受此门禁限制。
    final gateAllows = rememberedLoginAllowsUrl(
      _rememberedLogin,
      await _resolveCurrentUrl(),
      trustedHosts: await _warehouseAutofillTrustedHosts(),
    );
    _logLoginStateAutofillDecision(
      gateAllows: gateAllows,
      hasPasswordField: hasPasswordField,
      rememberedExists: _rememberedLogin != null,
      rememberedPasswordEmpty: _rememberedLogin?.password.isEmpty ?? true,
      candidatePasswordEmpty: candidate.password.isEmpty,
      hasPromptedAutofill: _hasPromptedAutofill,
      sessionActive: _isSessionActive,
    );
    if (!gateAllows) {
      return;
    }
    if (!mounted) {
      return;
    }
    // 探针还在路上：把弹窗决定推迟到它出结论（或超时）再判，否则「会话还在
    // → 不弹」的抑制永远输给网络往返（见 sessionProbeMayStillSettle）。
    if (sessionProbeMayStillSettle(
      config: _sessionProbeConfig,
      verdict: _sessionProbeVerdict,
      inFlight: _sessionProbeInFlight,
    )) {
      _pendingAutofillLoginState = message;
      _debugImportLog('autofill prompt deferred: session probe in flight');
      return;
    }

    if (shouldPromptRememberedLoginAutofill(
      hasPasswordField: hasPasswordField,
      rememberedLogin: _rememberedLogin,
      candidate: candidate,
      hasPromptedAutofill: _hasPromptedAutofill,
      isPromptShowing: _isPromptShowing,
      sessionActive: _isSessionActive,
    )) {
      _hasPromptedAutofill = true;
      // 回放模式：直接填充，不弹对话框
      if (widget.macroRecord != null) {
        await _autofillRememberedLogin();
        return;
      }
      _isPromptShowing = true;
      final l10n = AppLocalizations.of(context)!;
      final shouldAutofill = await showAppConfirmDialog(
        context,
        title: l10n.autofillLoginTitle,
        message: l10n.autofillLoginMessage(_rememberedLogin!.username),
        cancelLabel: l10n.notNowAction,
        confirmLabel: l10n.autofillAction,
      );
      _isPromptShowing = false;
      if (shouldAutofill == true) {
        await _autofillRememberedLogin();
      }
      return;
    }
  }

  Future<void> _handleLoginAttempt() async {
    // 登录动作（点登录 / 提交表单）之后，之前那份「会话还在不在」的结论就过期了：
    // 登录可能成功、也可能失败。无论哪种，都得让下一次探活重新判。
    _invalidateSessionProbeVerdict();
    final candidate = _latestLoginCandidate;
    if (candidate == null) {
      return;
    }
    if (!shouldPromptRememberedLoginSave(
      rememberedLogin: _rememberedLogin,
      hasPromptedSave: _hasPromptedSave,
      isPromptShowing: _isPromptShowing,
      candidateUsername: candidate.username,
      candidatePassword: candidate.password,
    )) {
      _debugImportLog(
        'loginAttempt save prompt suppressed '
        'remembered=${_rememberedLogin != null} '
        'rememberedPasswordEmpty=${_rememberedLogin?.password.isEmpty ?? true} '
        'hasPromptedSave=$_hasPromptedSave '
        'isPromptShowing=$_isPromptShowing '
        'candidateUsernameEmpty=${candidate.username.isEmpty} '
        'candidatePasswordEmpty=${candidate.password.isEmpty}',
      );
      return;
    }
    // 后台回放不打断流程、不弹对话框（Offstage 里对话框会永远挂着）；
    // 前台回放与普通网页登录都允许补录提示。
    if (widget.runInBackground) {
      return;
    }
    _hasPromptedSave = true;
    _isPromptShowing = true;
    final l10n = AppLocalizations.of(context)!;
    final shouldPersist = await showAppConfirmDialog(
      context,
      title: l10n.rememberPasswordTitle,
      message: l10n.rememberPasswordMessage(candidate.username),
      cancelLabel: l10n.dontRememberAction,
      confirmLabel: l10n.rememberAndAutofillAction,
    );
    _isPromptShowing = false;
    if (shouldPersist == true) {
      // 存盘与内存必须放同一份「已绑定 host」的副本。之前这里存的是
      // _bindCurrentHostToLogin(candidate)（对的），却把未绑定的 candidate
      // 留在 _rememberedLogin 里 —— 而 rememberedLoginAllowsUrl 对空 host
      // 的旧数据是放行的，于是用户刚存完密码，门禁当场失效：任何站点都能
      // 触发自动填充。手动录入路径（下方）本来就是用 boundLogin，没有这个问题。
      final boundLogin = await _bindCurrentHostToLogin(candidate);
      await _preferencesService.setRememberedLogin(
        widget.adapter.adapterId,
        boundLogin,
      );
      if (!mounted) return;
      setState(() {
        _rememberedLogin = boundLogin;
        _lastScriptStatus = AppLocalizations.of(
          context,
        )!.savedRememberedLoginStatus;
      });
    }
  }

  Future<void> _loadRememberedLogin() async {
    final login = await _preferencesService.getRememberedLogin(
      widget.adapter.adapterId,
    );
    if (!mounted) return;
    setState(() {
      _rememberedLogin = login;
    });
    await _autofillRememberedLoginIfNeeded();
  }

  Future<void> _autofillRememberedLoginIfNeeded() async {
    if (_rememberedLogin == null || _hasPromptedAutofill || _isPromptShowing) {
      return;
    }
    await _requestLoginStateProbe();
  }

  /// W7：读取 WebView 当前 URL；桥接不可用时退回状态里维护的地址。
  Future<String?> _resolveCurrentUrl() async {
    try {
      return await _controller.currentUrl();
    } catch (_) {
      return _currentUrl;
    }
  }

  /// W7：保存凭据时绑定其来源站点 host（已绑定的保持不变）。
  Future<WarehouseRememberedLogin> _bindCurrentHostToLogin(
    WarehouseRememberedLogin login,
  ) async {
    if (login.host.isNotEmpty) {
      return login;
    }
    final host = extractUrlHost(await _resolveCurrentUrl());
    if (host == null) {
      return login;
    }
    return WarehouseRememberedLogin(
      username: login.username,
      password: login.password,
      host: host,
    );
  }

  Future<void> _autofillRememberedLogin() async {
    final login = _rememberedLogin;
    if (login == null) return;
    final js =
        '''
(() => {
  const textInputs = Array.from(document.querySelectorAll('input')).filter((input) => {
    const type = (input.type || 'text').toLowerCase();
    return ['text','email','tel','number'].includes(type) && !input.disabled;
  });
  const passwordInput = Array.from(document.querySelectorAll('input[type="password"]')).find((input) => !input.disabled);
  const setInputValue = (input, nextValue) => {
    if (!input) return false;
    // 已是目标值则不改写，避免触发页面「清空再输入」监听。
    if (String(input.value || '') === nextValue) return false;
    input.focus();
    input.value = nextValue;
    input.dispatchEvent(new Event('input', { bubbles: true }));
    input.dispatchEvent(new Event('change', { bubbles: true }));
    return true;
  };
  if (textInputs[0]) {
    setInputValue(textInputs[0], ${jsonEncode(login.username)});
  }
  if (passwordInput) {
    setInputValue(passwordInput, ${jsonEncode(login.password)});
  }
})();
''';
    await _controller.runJavaScript(js);
    if (!mounted) return;
    setState(() {
      _lastScriptStatus = AppLocalizations.of(
        context,
      )!.autofilledRememberedLoginStatus;
    });
  }

  Future<void> _rememberCurrentLogin() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final raw = await _controller.runJavaScriptReturningResult('''
(() => {
  const textInputs = Array.from(document.querySelectorAll('input')).filter((input) => {
    const type = (input.type || 'text').toLowerCase();
    return ['text','email','tel','number'].includes(type) && !input.disabled;
  });
  const passwordInput = Array.from(document.querySelectorAll('input[type="password"]')).find((input) => !input.disabled);
  return JSON.stringify({
    username: textInputs[0] ? String(textInputs[0].value || '') : '',
    password: passwordInput ? String(passwordInput.value || '') : ''
  });
})();
''');
      if (!mounted) return;
      final normalized = _normalizeJavaScriptResult(raw);
      final decoded = jsonDecode(normalized);
      if (decoded is! Map<String, dynamic>) {
        throw FormatException(l10n.noRecognizedLoginInputs);
      }
      final login = WarehouseRememberedLogin.fromJson(decoded);
      if (login.username.isEmpty && login.password.isEmpty) {
        showImportLightTip(context, l10n.noUsernameOrPasswordRecognized);
        return;
      }
      final boundLogin = await _bindCurrentHostToLogin(login);
      await _preferencesService.setRememberedLogin(
        widget.adapter.adapterId,
        boundLogin,
      );
      if (!mounted) return;
      setState(() {
        _rememberedLogin = boundLogin;
        _lastScriptStatus = l10n.rememberedCurrentLoginStatus;
      });
      showImportLightTip(context, l10n.rememberedCurrentLoginSuccess);
    } catch (error) {
      if (!mounted) return;
      showImportLightTip(context, l10n.rememberLoginFailedWithError('$error'));
    }
  }

  Future<void> _clearRememberedLogin() async {
    await _preferencesService.clearRememberedLogin(widget.adapter.adapterId);
    if (!mounted) return;
    setState(() {
      _rememberedLogin = null;
      _lastScriptStatus = AppLocalizations.of(
        context,
      )!.clearedRememberedLoginStatus;
    });
    showImportLightTip(
      context,
      AppLocalizations.of(context)!.clearedRememberedLoginSuccess,
    );
  }

  // ============ 宏录制方法 ============

  Future<void> _injectMacroRecorderJs() async {
    try {
      await _controller.runJavaScript(MacroRecorderJs.injectScript);
    } catch (e) {
      // 注入失败意味着本次录制收不到任何事件（Dart 侧表现为 0 步骤），
      // 不中断流程但必须留痕，否则用户「录完是空的」无从归因。
      _debugImportLog('macro recorder inject failed: $e', level: 'warn');
    }
  }

  void _handleMacroEvent(Map<String, dynamic> message) {
    if (_macroRecordingState != MacroRecordingState.recording) return;
    try {
      final payloadRaw = message['payload'] as String?;
      if (payloadRaw == null || payloadRaw.isEmpty) return;
      final decoded = jsonDecode(payloadRaw);
      if (decoded is! Map) return;
      setState(() {
        _macroRawEvents.add(Map<String, dynamic>.from(decoded));
      });
    } catch (e) {
      // 单条事件损坏只丢这一条，不中断录制；留痕便于核对事件数差异。
      _debugImportLog('macro event decode failed: $e', level: 'warn');
    }
  }

  Future<void> _toggleMacroRecording() async {
    if (_macroRecordingState == MacroRecordingState.recording) {
      await _stopMacroRecording();
    } else {
      _startMacroRecording();
    }
  }

  void _startMacroRecording() {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _macroRecordingState = MacroRecordingState.recording;
      _macroRawEvents = [];
      _lastScriptStatus = l10n.courseImportRecordingStatus;
    });
    // Each recording session must start with a clean dialog map so a previous
    // stop-and-discard (or re-record on the same WebView) cannot leak answers.
    _macroDialogResponses.clear();
    // 在当前页面注入录制 JS
    _injectMacroRecorderJs();
    // First-import auto-record uses a lighter tip so users are not startled.
    showImportLightTip(
      context,
      widget.autoRecord
          ? l10n.courseImportAutoRecordingStartedTip
          : l10n.courseImportRecordingStartedTip,
    );
  }

  /// 导入成功时自动完成录制并返回
  Future<void> _completeMacroAndPop() async {
    // 从 JS 获取剩余事件
    try {
      final result = await _controller.runJavaScriptReturningResult(
        MacroRecorderJs.dumpScript,
      );
      final normalized = _normalizeJavaScriptResult(result);
      if (normalized.isNotEmpty && normalized != '[]') {
        final decoded = jsonDecode(normalized);
        if (decoded is List) {
          _macroRawEvents.addAll(
            decoded.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map)),
          );
        }
      }
    } catch (e) {
      // dump 失败 = 用户刚录制的尾部事件静默丢失，导入流程不中断
      //（已通过事件通道收到的步骤仍有效），但必须留痕便于核对步骤缺失。
      _debugImportLog('macro dump on complete failed: $e', level: 'warn');
    }

    final capturedEvents = List<Map<String, dynamic>>.from(_macroRawEvents);
    final steps = MacroRecordingConverter.convert(capturedEvents);

    if (!mounted) {
      return;
    }

    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _macroRecordingState = MacroRecordingState.stopped;
    });

    // No steps captured: finish import without offering to save a path.
    if (steps.isEmpty) {
      setState(() {
        _macroRecordingState = MacroRecordingState.idle;
        _macroRawEvents = [];
      });
      _macroDialogResponses.clear();
      Navigator.of(context).pop(true);
      return;
    }

    // Ask whether to keep this first-import (or explicit-record) path.
    final shouldSave = await showAppConfirmDialog(
      context,
      title: l10n.courseImportSaveRecordingTitle,
      message: widget.autoRecord
          ? l10n.courseImportSaveAutoRecordingMessage(steps.length)
          : l10n.courseImportSaveRecordingMessage(steps.length),
      confirmLabel: l10n.saveAction,
    );

    if (!mounted) {
      return;
    }

    if (shouldSave == true) {
      final now = DateTime.now();
      final record = WarehouseMacroRecord(
        schoolId: widget.school.id,
        adapterId: widget.adapter.adapterId,
        schoolName: widget.school.name,
        adapterName: widget.adapter.adapterName,
        importUrl: widget.initialUrl,
        scriptPageUrl: sanitizeWarehouseScriptPageUrl(
          _currentUrl ?? widget.initialUrl,
        ),
        schoolResourceFolder: widget.school.resourceFolder,
        adapterAssetJsPath: widget.adapter.assetJsPath,
        steps: steps,
        dialogResponses: Map<String, dynamic>.from(_macroDialogResponses),
        createdAt: now,
        updatedAt: now,
        successfulImportCount: 1,
        useDesktopMode: _useDesktopMode,
      );
      _macroDialogResponses.clear();
      await _macroService.saveMacro(record);
      if (!mounted) {
        return;
      }
      setState(() {
        _macroRecordingState = MacroRecordingState.idle;
        _macroRawEvents = [];
        _lastScriptStatus = l10n.courseImportRecordingSavedStatus(steps.length);
      });
    } else {
      setState(() {
        _macroRecordingState = MacroRecordingState.idle;
        _macroRawEvents = [];
        _lastScriptStatus = null;
      });
      _macroDialogResponses.clear();
    }

    if (mounted) {
      // Import already succeeded; always return true so parent can close.
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _stopMacroRecording() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _macroRecordingState = MacroRecordingState.stopped;
    });

    // 尝试从页面获取剩余的录制事件
    try {
      final result = await _controller.runJavaScriptReturningResult(
        MacroRecorderJs.dumpScript,
      );
      final normalized = _normalizeJavaScriptResult(result);
      if (normalized.isNotEmpty && normalized != '[]') {
        final decoded = jsonDecode(normalized);
        if (decoded is List) {
          setState(() {
            _macroRawEvents.addAll(
              decoded.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map)),
            );
          });
        }
      }
    } catch (e) {
      // dump 失败 = 录制尾部事件丢失，用户保存的宏可能缺步骤且无感知；
      // 不中断停止流程，留痕便于排查「宏步骤缺失」类反馈。
      _debugImportLog('macro dump on stop failed: $e', level: 'warn');
    }

    // 转换为 MacroStep 列表
    final capturedEvents = List<Map<String, dynamic>>.from(_macroRawEvents);
    final steps = MacroRecordingConverter.convert(capturedEvents);
    if (!mounted) return;

    if (steps.isEmpty) {
      setState(() {
        _macroRecordingState = MacroRecordingState.idle;
        _macroRawEvents = [];
        _lastScriptStatus = l10n.courseImportRecordingEmptyStatus;
      });
      _macroDialogResponses.clear();
      showImportLightTip(context, l10n.courseImportRecordingEmptyTip);
      return;
    }

    // 询问用户是否要保存
    final shouldSave = await showAppConfirmDialog(
      context,
      title: l10n.courseImportSaveRecordingTitle,
      message: l10n.courseImportSaveRecordingMessage(steps.length),
      confirmLabel: l10n.saveAction,
    );

    if (shouldSave != true || !mounted) {
      setState(() {
        _macroRecordingState = MacroRecordingState.idle;
        _macroRawEvents = [];
        _lastScriptStatus = null;
      });
      _macroDialogResponses.clear();
      return;
    }

    // 保存宏录制
    final now = DateTime.now();
    final record = WarehouseMacroRecord(
      schoolId: widget.school.id,
      adapterId: widget.adapter.adapterId,
      schoolName: widget.school.name,
      adapterName: widget.adapter.adapterName,
      importUrl: widget.initialUrl,
      scriptPageUrl: sanitizeWarehouseScriptPageUrl(
        _currentUrl ?? widget.initialUrl,
      ),
      schoolResourceFolder: widget.school.resourceFolder,
      adapterAssetJsPath: widget.adapter.assetJsPath,
      steps: steps,
      dialogResponses: Map<String, dynamic>.from(_macroDialogResponses),
      createdAt: now,
      updatedAt: now,
      useDesktopMode: _useDesktopMode,
    );

    _macroDialogResponses.clear();
    await _macroService.saveMacro(record);
    if (!mounted) return;

    setState(() {
      _macroRecordingState = MacroRecordingState.idle;
      _macroRawEvents = [];
      _lastScriptStatus = l10n.courseImportRecordingSavedStatus(steps.length);
    });
    // 保存后自动返回适配器列表，用户即可看到快捷导入按钮
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  // ============ 宏回放方法 ============

  Future<void> _startPlayback(WarehouseMacroRecord macro) async {
    final acceleratedPreview = buildAcceleratedMacroSteps(
      compactMacroFillSteps(macro.steps),
      scriptPageUrl: macro.scriptPageUrl,
      importUrl: macro.importUrl,
    );
    final willAccelerate =
        acceleratedPreview.length < compactMacroFillSteps(macro.steps).length;
    _debugImportLog(
      'start playback macro steps=${macro.steps.length} '
      'acceleratedSteps=${acceleratedPreview.length} '
      'willAccelerate=$willAccelerate '
      'scriptPageUrl=${macro.scriptPageUrl ?? "(null)"} '
      'importUrl=${macro.importUrl} '
      'adapter=${macro.adapterId}',
    );
    setState(() {
      _playbackState = PlaybackUiState.playing;
      _playbackProgress = const ReplayProgress(
        currentStepIndex: 0,
        totalSteps: 0,
        currentStep: MacroStep(type: MacroStepType.delay),
        status: ReplayStepStatus.pending,
      );
      _isExecutingImport = false;
    });

    final replayer = WarehouseMacroReplayer(
      controller: _controller,
      l10n: AppLocalizations.of(context)!,
      callbacks: ReplayCallbacks(
        onProgress: (progress) {
          _notifyBackgroundProgress();
          if (!mounted) return;
          setState(() {
            _playbackProgress = progress;
          });
        },
        onPauseForManualInput: (step, reason) async {
          if (!mounted) return false;
          final passwordLike = shouldUseRememberedPasswordForManualStep(
            step,
            reason,
            AppLocalizations.of(context)!,
          );
          if (passwordLike) {
            final remembered =
                _rememberedLogin ??
                await _preferencesService.getRememberedLogin(
                  widget.adapter.adapterId,
                );
            if (!mounted) return false;
            // W7：回放中的自动填充同样受站点绑定约束。
            if (!rememberedLoginAllowsUrl(
              remembered,
              await _resolveCurrentUrl(),
              trustedHosts: await _warehouseAutofillTrustedHosts(),
            )) {
              _debugImportLog(
                'playback password step autofill blocked by host gate '
                'remembered=${remembered != null} '
                'rememberedPasswordEmpty=${remembered?.password.isEmpty ?? true}',
              );
              return false;
            }
            if (remembered != null && remembered.password.isNotEmpty) {
              if (_rememberedLogin == null) {
                setState(() {
                  _rememberedLogin = remembered;
                });
              }
              // 始终走 autofill：内部 setInputValue 对已有正确值会跳过改写，
              // 但不会连带跳过学号/用户名（避免密码已满、用户名为空）。
              await _autofillRememberedLogin();
              await Future.delayed(const Duration(milliseconds: 300));
              if (!mounted) return false;
              setState(() {
                _playbackState = PlaybackUiState.playing;
              });
              return true;
            }
          }
          _debugImportLog(
            'playback paused for manual input reason="$reason" '
            'fieldType=${step.fieldType ?? ''} passwordLike=$passwordLike '
            'remembered=${_rememberedLogin != null} '
            'rememberedPasswordEmpty=${_rememberedLogin?.password.isEmpty ?? true} '
            'runInBackground=${widget.runInBackground}',
          );
          if (widget.runInBackground) {
            _debugImportLog(
              'background playback needs manual input reason=$reason',
            );
            widget.onBackgroundNeedsManualAction?.call();
            widget.onBackgroundFinished?.call(false);
            return false;
          }
          setState(() {
            _playbackState = PlaybackUiState.pausedForInput;
          });
          // 使用 Completer 等待用户点击继续
          final completer = Completer<bool>();
          _replayContinueCompleter = completer;
          return completer.future;
        },
        onShowTip: (message) {
          if (!mounted) return;
          showImportLightTip(context, message);
        },
        onComplete: (success, errorMessage) async {
          _debugImportLog(
            'playback onComplete success=$success errorMessage=$errorMessage mounted=$mounted',
          );
          if (!mounted) return;
          if (success) {
            _debugImportLog('playback success -> executing import');
            setState(() {
              _playbackState = PlaybackUiState.executingImport;
            });
            await _autoExecuteImportAfterPlayback();
          } else {
            if (!mounted) return;
            _debugImportLog('playback failed -> playback error');
            if (widget.runInBackground) {
              widget.onBackgroundFinished?.call(false);
              return;
            }
            setState(() {
              _playbackState = PlaybackUiState.error;
            });
          }
        },
      ),
    );
    _replayer = replayer;
    await replayer.execute(macro);
  }

  Completer<bool>? _replayContinueCompleter;

  void _resumePlaybackAfterPause() {
    if (_replayContinueCompleter == null) return;
    _replayContinueCompleter!.complete(true);
    _replayContinueCompleter = null;
    if (mounted) {
      setState(() {
        _playbackState = PlaybackUiState.playing;
      });
    }
  }

  void _cancelPlayback() {
    _replayer?.cancel();
    _replayContinueCompleter?.complete(false);
    _replayContinueCompleter = null;
    if (mounted) {
      setState(() {
        _playbackState = PlaybackUiState.hidden;
      });
    }
  }

  Future<void> _dismissPlaybackResult() async {
    if (mounted) {
      setState(() {
        _playbackState = PlaybackUiState.hidden;
      });
    }
  }

  Future<void> _retryPlayback() async {
    final macro =
        widget.macroRecord ??
        await _macroService.getMacro(
          widget.school.id,
          widget.adapter.adapterId,
        );
    if (macro == null || !mounted) return;
    // 重新加载初始 URL
    final uri = Uri.tryParse(widget.initialUrl);
    if (uri != null) {
      await _controller.loadRequest(uri);
    }
    if (!mounted) return;
    _startPlayback(macro);
  }

  /// 回放导航完成后，自动执行导入脚本
  Future<void> _autoExecuteImportAfterPlayback() async {
    // 给页面一点稳定时间
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    // 自动执行导入脚本
    await _executeImportScript();
  }
}


String _normalizeJavaScriptResult(Object? raw) {
  if (raw == null) {
    return '';
  }
  final text = raw.toString();
  try {
    final decoded = jsonDecode(text);
    if (decoded is String) {
      return decoded;
    }
  } catch (_) {
    // WebView 返回的字符串可能带外层引号；解码失败说明本就是裸文本，
    // 原样返回属预期分支，不是错误。
  }
  return text;
}


