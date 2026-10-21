import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/models/warehouse_macro_models.dart';
import 'package:university_timetable/widgets/warehouse_macro_replayer.dart';
import 'package:webview_flutter/webview_flutter.dart';
// ignore: depend_on_referenced_packages
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

/// 回放引擎「什么时候才动手」的契约。
///
/// 真机日志（2026-10-21，重庆城市科技学院 CQCST）里的形状是：打开网页 46.483s、
/// 回放 46.485s 就开始（只隔 2ms），460ms 后第一步填账号报
/// `macro_element_not_found|selector=#userAccount`，整条回放当场失败。
///
/// 两处根因都在引擎里，且都只能在「假 WebView 有时间轴」的条件下复现：
/// 1. 回放启动时没等入口页成为完整文档（还在 about:blank / loading 就开跑）；
/// 2. 填 / 点只固定等 300ms 再查一次，查不到立刻判整条失败，没有轮询预算。
///
/// 本文件站在 WebView 边界外面钉住这两条：注入的脚本一条都别在「页面没就绪」
/// 之前跑到元素步骤上，以及「元素晚到」时回放要等它，而不是当场判死。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final l10n = lookupAppLocalizations(const Locale('zh'));

  late WebViewPlatform? previousPlatform;

  setUp(() {
    previousPlatform = WebViewPlatform.instance;
  });

  tearDown(() {
    if (previousPlatform != null) {
      WebViewPlatform.instance = previousPlatform;
    }
  });

  WarehouseMacroRecord buildMacro(List<MacroStep> steps) {
    final now = DateTime(2026, 10, 21, 21);
    return WarehouseMacroRecord(
      schoolId: 'CQCST',
      adapterId: 'CQCST_01',
      schoolName: '重庆城市科技学院',
      adapterName: '重庆城市科技学院强智适配',
      importUrl: 'http://jw.cqcst.edu.cn/cqdxcskjxy_jsxsd/',
      schoolResourceFolder: 'CQCST',
      adapterAssetJsPath: 'assets/CQCST.js',
      steps: steps,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// 构造一个挂在假 WebView 上的回放引擎，并把回调结果收进 [_ReplayOutcome]。
  ({WarehouseMacroReplayer replayer, _ReplayOutcome outcome}) buildReplayer(
    _TimelineWebView timeline, {
    int elementWaitMs = 1500,
    Duration entryReady = const Duration(seconds: 3),
  }) {
    // 每次构造都装一遍：漏装时 WebViewController() 会撞上平台断言，
    // 反复用上一台时间轴则会让「页面还没就绪」的用例读到别人的状态。
    WebViewPlatform.instance = _FakeWebViewPlatform(timeline);
    final outcome = _ReplayOutcome();
    final replayer = WarehouseMacroReplayer(
      controller: WebViewController(),
      l10n: l10n,
      defaultElementWaitMs: elementWaitMs,
      entryReadyTimeout: entryReady,
      callbacks: ReplayCallbacks(
        onProgress: outcome.progress.add,
        onPauseForManualInput: (_, _) async => true,
        onShowTip: outcome.tips.add,
        onComplete: (success, errorMessage) {
          outcome.success = success;
          outcome.errorMessage = errorMessage;
        },
      ),
    );
    return (replayer: replayer, outcome: outcome);
  }

  group('回放启动前必须先等入口页', () {
    test('入口页还在 loading 时不碰任何元素步骤，就绪后才动手', () async {
      final timeline = _TimelineWebView()
        // WebView 刚创建：空白文档，请求还没回来。这正是日志里那 2ms 的状态。
        ..href = 'about:blank'
        ..readyState = 'loading';

      // 400ms 后请求回来了，页面成为完整文档。
      Timer(const Duration(milliseconds: 400), () {
        timeline
          ..href = 'http://jw.cqcst.edu.cn/cqdxcskjxy_jsxsd/'
          ..readyState = 'complete';
      });

      final built = buildReplayer(timeline);
      await built.replayer.execute(
        buildMacro([
          MacroStep.fillField(selector: '#userAccount', value: '2024001'),
          MacroStep.delay(10),
        ]),
      );

      expect(built.outcome.success, isTrue, reason: '等到了就该成功');
      // 关键断言：元素脚本第一次执行时，页面必须已经是完整文档。
      expect(timeline.elementScriptFirstRunAt, isNotNull);
      expect(
        timeline.documentReadyAt,
        isNotNull,
        reason: '时间轴本身要成立：页面确实在途中变成了 complete',
      );
      expect(
        timeline.elementScriptFirstRunAt!.isAfter(timeline.documentReadyAt!),
        isTrue,
        reason: '元素步骤抢在页面就绪之前跑了，就是日志里那种「一开场就失败」',
      );
    });

    test('等页面期间进度条就有真实步数，不是「第 1 / 0 步」', () async {
      final timeline = _TimelineWebView()
        ..href = 'about:blank'
        ..readyState = 'loading';
      final built = buildReplayer(
        timeline,
        entryReady: const Duration(milliseconds: 300),
      );
      final steps = [
        MacroStep.fillField(selector: '#userAccount', value: '2024001'),
        MacroStep.fillField(selector: '#userPassword', value: 'x'),
        MacroStep.click('#btnSubmit'),
      ];

      // 不等整条跑完：只要看「等待期间」的进度读数。
      final future = built.replayer.execute(buildMacro(steps));
      await Future<void>.delayed(const Duration(milliseconds: 120));
      final duringWait = built.outcome.progress.last;
      expect(duringWait.totalSteps, steps.length);
      expect(duringWait.currentStepIndex, 0);
      expect(duringWait.status, ReplayStepStatus.pending);

      // 收尾：让页面就绪，等整条跑完，避免留下悬挂的异步任务。
      timeline
        ..href = 'http://jw.cqcst.edu.cn/cqdxcskjxy_jsxsd/'
        ..readyState = 'complete'
        ..elementAppearsAfterRuns = 0;
      await future;
    });

    test('入口页永远不就绪：超时后仍继续跑，不把回放判成「宏坏了」', () async {
      // 空白文档上当然也查不到账号框：两条失败理由要在同一次运行里区分开。
      final timeline = _TimelineWebView()
        ..href = 'about:blank'
        ..readyState = 'loading'
        ..elementNeverAppears = true;
      final built = buildReplayer(
        timeline,
        elementWaitMs: 120,
        entryReady: const Duration(milliseconds: 200),
      );
      await built.replayer.execute(
        buildMacro([
          MacroStep.fillField(selector: '#userAccount', value: '2024001'),
        ]),
      );

      // 元素确实没出现：这一步该失败，但失败理由是「找不到元素」，
      // 而不是被入口页等待抢先判死（那会让用户以为宏坏了）。
      expect(built.outcome.success, isFalse);
      expect(built.outcome.errorMessage, contains('macro_element_not_found'));
      expect(built.outcome.errorMessage, contains('#userAccount'));
      expect(timeline.elementStepRuns, greaterThan(0));
    });
  });

  group('旧宏里那步「点表单」已经不作了：跳过而不是整条失败', () {
    test('点按钮后页面翻走，随后找不到的表单点击被跳过，宏继续跑完', () async {
      // 城科旧宏形状：fill → click(#btnSubmit) → delay → click(#Form1)。
      // 第一下点击把页面带到 xsMain.jsp，#Form1 在新页面并不存在。
      final timeline = _TimelineWebView()
        ..href = 'http://jw.cqcst.edu.cn/cqdxcskjxy_jsxsd/'
        ..readyState = 'complete'
        ..clickTargets = {'#btnSubmit'}
        ..navigateOnClickSelector = '#btnSubmit';

      final built = buildReplayer(timeline, elementWaitMs: 200);
      await built.replayer.execute(
        buildMacro([
          MacroStep.click('#btnSubmit'),
          MacroStep.delay(10),
          MacroStep.click('#Form1'),
          MacroStep.delay(10),
        ]),
      );

      expect(
        built.outcome.success,
        isTrue,
        reason: '作废的那一步应被跳过，而不是让整条宏失败',
      );
      expect(timeline.missingLookups, contains('#Form1'));
    });

    test('页面没翻过就说找不到：照旧如实失败，不跳过', () async {
      final timeline = _TimelineWebView()
        ..href = 'http://jw.cqcst.edu.cn/cqdxcskjxy_jsxsd/'
        ..readyState = 'complete'
        // 点了不跳页，第二个元素确实不存在。
        ..clickTargets = {'#btnSubmit'};

      final built = buildReplayer(timeline, elementWaitMs: 200);
      await built.replayer.execute(
        buildMacro([
          MacroStep.click('#btnSubmit'),
          MacroStep.delay(10),
          MacroStep.click('#Form1'),
        ]),
      );

      expect(built.outcome.success, isFalse);
      expect(built.outcome.errorMessage, contains('#Form1'));
    });

    test('填充步骤找不到元素绝不跳过：那说明页面根本没走到该到的地方', () async {
      final timeline = _TimelineWebView()
        ..href = 'http://jw.cqcst.edu.cn/cqdxcskjxy_jsxsd/'
        ..readyState = 'complete'
        ..clickTargets = {'#btnSubmit'}
        ..navigateOnClickSelector = '#btnSubmit';

      final built = buildReplayer(timeline, elementWaitMs: 200);
      await built.replayer.execute(
        buildMacro([
          MacroStep.click('#btnSubmit'),
          MacroStep.delay(10),
          MacroStep.fillField(selector: '#userAccount', value: 'x'),
        ]),
      );

      expect(built.outcome.success, isFalse);
      expect(built.outcome.errorMessage, contains('#userAccount'));
    });
  });

  group('元素晚到要等，不能查一次就判死', () {
    test('元素在第 3 拍才出现：回放要等到它，而不是立刻失败', () async {
      final timeline = _TimelineWebView()
        ..href = 'http://jw.cqcst.edu.cn/cqdxcskjxy_jsxsd/'
        ..readyState = 'complete'
        // 前两次查询报「没找到」，第三次开始报找到——模拟表单渲染稍慢。
        ..elementAppearsAfterRuns = 2;
      final built = buildReplayer(timeline, elementWaitMs: 3000);
      await built.replayer.execute(
        buildMacro([
          MacroStep.fillField(selector: '#userAccount', value: '2024001'),
          MacroStep.delay(10),
        ]),
      );

      expect(built.outcome.success, isTrue);
      expect(
        timeline.elementStepRuns,
        greaterThan(2),
        reason: '旧实现只查一次（固定等 300ms），这里必须真的轮询',
      );
    });

    test('元素始终不出现：报「找不到元素」而不是当成成功往下跑', () async {
      final timeline = _TimelineWebView()
        ..href = 'http://jw.cqcst.edu.cn/cqdxcskjxy_jsxsd/'
        ..readyState = 'complete'
        ..elementNeverAppears = true;
      final built = buildReplayer(timeline, elementWaitMs: 200);
      await built.replayer.execute(
        buildMacro([
          MacroStep.fillField(selector: '#userAccount', value: '2024001'),
        ]),
      );

      expect(built.outcome.success, isFalse);
      expect(built.outcome.errorMessage, contains('macro_element_not_found'));
      expect(built.outcome.progress.last.status, ReplayStepStatus.failed);
    });

    test('点击步骤同样等元素：登录按钮晚渲染也能点下去', () async {
      final timeline = _TimelineWebView()
        ..href = 'http://jw.cqcst.edu.cn/cqdxcskjxy_jsxsd/'
        ..readyState = 'complete'
        ..elementAppearsAfterRuns = 1;
      final built = buildReplayer(timeline, elementWaitMs: 3000);
      await built.replayer.execute(
        buildMacro([MacroStep.click('#btnSubmit'), MacroStep.delay(10)]),
      );

      expect(built.outcome.success, isTrue);
      expect(timeline.clicked, isTrue);
    });
  });
}

/// 回放跑完之后我们关心的那几个结果。
class _ReplayOutcome {
  final List<ReplayProgress> progress = [];
  final List<String> tips = [];
  bool? success;
  String? errorMessage;
}

/// 一台「有时间轴」的假 WebView。
///
/// 它不执行 JS，只按脚本形态回话：`location.href` / `document.readyState` 读
/// 当前字段，元素类脚本按 [elementAppearsAfterRuns] 决定第几拍开始报找到。
class _TimelineWebView {
  String href = 'about:blank';
  String readyState = 'loading';

  /// 元素脚本执行到第几次才算「找到了」。0 表示第一次就找到。
  int elementAppearsAfterRuns = 0;

  /// 元素永远不出现（失败路径）。
  bool elementNeverAppears = false;

  /// 页面上「存在」的元素选择器；非空时按这份名单判定找没找到。
  Set<String> clickTargets = <String>{};

  /// 点这个选择器会把页面带走（模拟表单提交跳转）。
  String? navigateOnClickSelector;

  /// 查过但页面上没有的选择器，按出现顺序记下来。
  final List<String> missingLookups = <String>[];

  int elementStepRuns = 0;
  DateTime? elementScriptFirstRunAt;
  DateTime? documentReadyAt;
  bool clicked = false;

  /// 元素脚本的执行：判定它属于填充还是点击，并回报 found。
  ///
  /// [script] 是引擎真正生成的那段 JS，[candidates] 是它查的候选选择器。
  String runElementScript(String script, List<String> candidates) {
    elementStepRuns++;
    elementScriptFirstRunAt ??= DateTime.now();
    final isClick = script.contains('el.click');
    final first = candidates.isEmpty ? '' : candidates.first;
    if (elementNeverAppears) {
      return '{"found":false,"selector":"$first"}';
    }
    if (clickTargets.isNotEmpty) {
      final hit = candidates.where(clickTargets.contains);
      if (hit.isEmpty) {
        missingLookups.add(first);
        return '{"found":false,"selector":"$first"}';
      }
      final matched = hit.first;
      if (isClick) {
        clicked = true;
        if (navigateOnClickSelector == matched) {
          // 表单提交：点到就换页，旧页面的元素随之作废。
          href = 'http://jw.cqcst.edu.cn/cqdxcskjxy_jsxsd/framework/xsMain.jsp';
        }
        return '{"found":true,"tag":"INPUT"}';
      }
      return '{"found":true,"tag":"INPUT","type":"text"}';
    }
    if (elementStepRuns <= elementAppearsAfterRuns) {
      missingLookups.add(first);
      return '{"found":false,"selector":"$first"}';
    }
    if (isClick) {
      clicked = true;
      return '{"found":true,"tag":"INPUT"}';
    }
    return '{"found":true,"tag":"INPUT","type":"text"}';
  }

  void noteDocumentState() {
    if (readyState == 'complete' && href != 'about:blank') {
      documentReadyAt ??= DateTime.now();
    }
  }
}

class _FakeWebViewPlatform extends WebViewPlatform {
  _FakeWebViewPlatform(this.timeline);

  final _TimelineWebView timeline;

  @override
  PlatformWebViewController createPlatformWebViewController(
    PlatformWebViewControllerCreationParams params,
  ) {
    return _FakePlatformController(params, timeline);
  }

  @override
  PlatformWebViewWidget createPlatformWebViewWidget(
    PlatformWebViewWidgetCreationParams params,
  ) {
    return _FakeWebViewWidget(params);
  }
}

class _FakePlatformController extends PlatformWebViewController {
  // ignore: use_super_parameters, the platform interface requires a named protected constructor.
  _FakePlatformController(
    PlatformWebViewControllerCreationParams params,
    this.timeline,
  ) : super.implementation(params);

  final _TimelineWebView timeline;

  @override
  Future<void> loadRequest(LoadRequestParams params) async {
    timeline.href = params.uri.toString();
  }

  @override
  Future<String?> currentUrl() async => timeline.href;

  @override
  Future<Object> runJavaScriptReturningResult(String javaScript) async {
    final script = javaScript.trim();
    if (script == 'location.href') {
      timeline.noteDocumentState();
      return timeline.href;
    }
    if (script == 'document.readyState') {
      return timeline.readyState;
    }
    if (script.contains('document.querySelector(sels')) {
      // 从引擎生成的脚本里取出它真正查的候选选择器名单，让假页面按同一份
      // 名单说话（否则测的是「我以为的脚本」而不是「真跑的那段」）。
      final match = RegExp(r'const sels = (\[.*?\]);').firstMatch(script);
      List<String> candidates = const [];
      if (match != null) {
        try {
          final decoded = jsonDecode(match.group(1)!);
          if (decoded is List) {
            candidates = decoded.map((e) => e.toString()).toList();
          }
        } catch (_) {
          // 解析不出来就当没候选：这条会走失败路径，断言自己会说话。
        }
      }
      return timeline.runElementScript(script, candidates);
    }
    // 其余脚本（登录探测、viewport 改写等）在引擎里不该出现；真出现也别炸，
    // 返回一个「什么都没找到」的形状，让断言自己说话。
    return '{"found":false}';
  }
}

class _FakeWebViewWidget extends PlatformWebViewWidget {
  // ignore: use_super_parameters, the platform interface requires a named protected constructor.
  _FakeWebViewWidget(PlatformWebViewWidgetCreationParams params)
    : super.implementation(params);

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}
