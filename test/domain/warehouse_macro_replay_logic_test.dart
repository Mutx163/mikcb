import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/domain/warehouse_macro_replay_logic.dart';

void main() {
  group('单选项：录制存标签、脚本要下标', () {
    test('旧回放把标签原样 resolve，脚本收到的类型与真人路径不同', () {
      // 真人路径：_resolveJavaScriptRequest(requestId, result)，result 是
      // showAppSingleChoiceDialog 返回的 int? 下标。
      const liveValue = 2;
      // 旧回放路径（course_import_screen.dart:5414）resolve 的是 '$recorded'，
      // recorded 取自 macroRecord.dialogResponses，静态类型就是 Object?。
      const key = 'singleSelection|选择周次|';
      final recorded = const <String, Object?>{key: '周三'}[key];
      final legacyReplayValue = '$recorded';

      // resolve 走 jsonEncode，所以这一步就是脚本实际收到的字面量。
      const options = ['周一', '周二', '周三'];
      expect(jsonEncode(liveValue), '2');
      expect(jsonEncode(legacyReplayValue), '"周三"');
      // 脚本里写 `options[i]`：真人时 i 是 2 取到 '周三'，回放时 i 是 "周三"，
      // JS 里 options["周三"] 是 undefined —— 同一句代码两种结果，回放会静默
      // 选错校区/学期，并把错的数据导进来。
      expect(options[liveValue], '周三');
      // 修后：回放也 resolve 下标，脚本收到的字面量与真人路径一致。
      expect(jsonEncode(matchRecordedOptionIndex(options, recorded)), '2');
    });

    test('换算helper 把录制的标签还原成与真人同型的下标', () {
      const options = ['周一', '周二', '周三'];
      final index = matchRecordedOptionIndex(options, '周三');
      expect(index, 2);
      expect(jsonEncode(index), '2');
    });
  });

  group('matchRecordedOptionIndex', () {
    test('标签不在当前选项里时返回 null，绝不给越界下标', () {
      const options = ['主校区', '东校区'];
      expect(matchRecordedOptionIndex(options, '已停用的校区'), isNull);
    });

    test('重复标签取第一个，与 List.indexOf 同语义', () {
      const options = ['2025秋', '2025秋', '2026春'];
      expect(matchRecordedOptionIndex(options, '2025秋'), 0);
      expect(matchRecordedOptionIndex(options, '2026春'), 2);
    });

    test('旧录制里若存的是数字：范围内按下标接受，越界返回 null', () {
      const options = ['a', 'b', 'c'];
      expect(matchRecordedOptionIndex(options, 1), 1);
      expect(matchRecordedOptionIndex(options, 1.0), 1);
      expect(matchRecordedOptionIndex(options, 3), isNull);
      expect(matchRecordedOptionIndex(options, -1), isNull);
    });

    test('空选项或没录到值都返回 null', () {
      expect(matchRecordedOptionIndex(const [], 'a'), isNull);
      expect(matchRecordedOptionIndex(const ['a'], null), isNull);
    });

    test('往返不变量：每个选项的标签都能换回它自己的下标', () {
      for (final options in [
        const ['单一'],
        const ['甲', '乙', '丙', '丁'],
        const ['', '空串也算一项'],
      ]) {
        for (var i = 0; i < options.length; i++) {
          expect(matchRecordedOptionIndex(options, options[i]), i);
        }
      }
    });
  });

  group('parseScriptOptionLabels', () {
    test('数组元素统一 toString，坏输入按空选项兜底', () {
      expect(parseScriptOptionLabels('["a","b"]'), ['a', 'b']);
      expect(
        parseScriptOptionLabels('[1,2,true,null]'),
        ['1', '2', 'true', 'null'],
      );
      expect(parseScriptOptionLabels('{"a":1}'), isEmpty);
      expect(parseScriptOptionLabels('not json'), isEmpty);
      expect(parseScriptOptionLabels(''), isEmpty);
      expect(parseScriptOptionLabels(null), isEmpty);
    });

    test('嵌套结构不抛异常，退化成空选项', () {
      expect(parseScriptOptionLabels('[[1],[2]]'), ['[1]', '[2]']);
      expect(() => parseScriptOptionLabels('{"a":[1]}'), returnsNormally);
    });

    test('脚本直接塞数组（没 stringify）也接得住，不再靠 as String? 抛断回调', () {
      expect(parseScriptOptionLabels(['主校区', '东校区']), ['主校区', '东校区']);
      expect(parseScriptOptionLabels([1, 2]), ['1', '2']);
      expect(parseScriptOptionLabels(42), isEmpty);
      expect(parseScriptOptionLabels({'a': 1}), isEmpty);
    });

    test('标签列表可以整份换算回下标', () {
      const options = ['主校区', '东校区', '南校区'];
      for (var i = 0; i < options.length; i++) {
        expect(matchRecordedOptionIndex(options, options[i]), i);
      }
      // 脚本发数组、录制存标签，两头同一条口径。
      final parsed = parseScriptOptionLabels(options);
      expect(parsed, options);
      expect(matchRecordedOptionIndex(parsed, '南校区'), 2);
    });
  });

  group('decodeBridgeMessage', () {
    test('JSON 对象才是合法桥消息', () {
      expect(
        decodeBridgeMessage('{"type":"toast","message":"ok"}'),
        {'type': 'toast', 'message': 'ok'},
      );
      expect(decodeBridgeMessage('{"type":"courses"}'), {'type': 'courses'});
    });

    test('合法但不是对象的 JSON：返回 null，而不是抛后被静默吞掉', () {
      // 旧写法 `jsonDecode(raw) as Map<String, dynamic>` 对这几种输入都抛
      // TypeError，然后被 `catch (_) { return; }` 吞掉：消息凭空消失，
      // 连一条日志都不留，脚本侧的失败无从追溯。
      for (final raw in ['[1,2]', '"text"', '42', 'true', 'null']) {
        expect(
          () => jsonDecode(raw) as Map<String, dynamic>,
          throwsA(isA<TypeError>()),
          reason: raw,
        );
        expect(decodeBridgeMessage(raw), isNull, reason: raw);
      }
    });

    test('坏 JSON 与空串返回 null 不抛', () {
      expect(() => decodeBridgeMessage(''), returnsNormally);
      expect(decodeBridgeMessage(''), isNull);
      expect(decodeBridgeMessage('not json'), isNull);
      expect(decodeBridgeMessage('{"type":'), isNull);
    });

    test('嵌套对象照常交出去，由调用方按字段各自取值', () {
      expect(
        decodeBridgeMessage('{"type":"x","payload":{"a":[1,2]}}'),
        {'type': 'x', 'payload': {'a': [1, 2]}},
      );
    });
  });

  group('normalizeWebScriptResult', () {
    // Android 的 evaluateJavascript 对字符串表达式返回 JSON 编码后的值：
    // 外层带引号，内层引号被转义成 \"。
    const quotedFoundFalse =
        r'"{\"found\":false,\"selector\":\"#user\"}"';
    const quotedFoundTrue = r'"{\"found\":true,\"tag\":\"INPUT\"}"';

    test('平台送回的 JSON 编码字符串要整体解码，不能只切首尾引号', () {
      expect(
        normalizeWebScriptResult(quotedFoundFalse),
        r'{"found":false,"selector":"#user"}',
      );
      // 只切首尾引号（旧回放实现）留下的是半截转义，下游 jsonDecode 必抛，
      // 于是 ensureMacroElementFound 的 on FormatException 把「没找到元素」
      // 当成「不是 JSON，忽略」放过去了。
      final legacyStripQuotesOnly = quotedFoundFalse.substring(
        1,
        quotedFoundFalse.length - 1,
      );
      expect(
        () => jsonDecode(legacyStripQuotesOnly),
        throwsA(isA<FormatException>()),
      );
    });

    test('解码后能真的判出 found:false', () {
      expect(
        jsonDecode(normalizeWebScriptResult(quotedFoundFalse)),
        isA<Map<String, dynamic>>().having(
          (m) => m['found'],
          'found',
          false,
        ),
      );
      final okDecoded = jsonDecode(
        normalizeWebScriptResult(quotedFoundTrue),
      ) as Map;
      expect(okDecoded['found'], isTrue);
    });

    test('裸文本原样返回：布尔、对象 JSON、readyState、空串、null', () {
      expect(normalizeWebScriptResult(r'{"found":false}'), r'{"found":false}');
      expect(normalizeWebScriptResult('true'), 'true');
      expect(normalizeWebScriptResult('"complete"'), 'complete');
      expect(normalizeWebScriptResult('complete'), 'complete');
      expect(normalizeWebScriptResult(''), '');
      expect(normalizeWebScriptResult(null), '');
      expect(normalizeWebScriptResult(42), '42');
    });

    test('JS 返回的页面文本里的引号不再被误切', () {
      // 脚本读一段带引号的文本时会 stringify 成 JSON 字符串送回；旧实现切掉
      // 首尾引号后，转义符会原样留在业务文本里。
      expect(
        normalizeWebScriptResult(r'"标题\"周几\""'),
        '标题"周几"',
      );
    });
  });

  group('bridgeOptionalString', () {
    test('只有真的是字符串才取，其它类型当没给', () {
      expect(bridgeOptionalString('周三'), '周三');
      expect(bridgeOptionalString(''), '');
      expect(bridgeOptionalString(null), isNull);
      // 这三条是原来 `as String?` 会直接抛 TypeError、把整条桥回调打断的输入。
      expect(() => bridgeOptionalString({'code': 500}), returnsNormally);
      expect(bridgeOptionalString({'code': 500}), isNull);
      expect(bridgeOptionalString([1, 2]), isNull);
      expect(bridgeOptionalString(500), isNull);
      expect(bridgeOptionalString(true), isNull);
    });
  });

  group('isTargetDocumentLoaded', () {
    test('旧判据（URL 非空）在旧文档还在时就通过，新判据不通过', () {
      const beforeHref = 'https://jwgl.example.edu.cn/login';
      // 导航已经发起，但页面还没提交，读到的仍是登录页。
      final legacyPredicateSays = beforeHref.isNotEmpty; // currentUrl 非空即通过
      expect(legacyPredicateSays, isTrue);
      expect(
        isTargetDocumentLoaded(
          beforeHref: beforeHref,
          currentHref: beforeHref,
          readyState: 'complete',
          targetHref: 'https://jwgl.example.edu.cn/portal/scriptPage',
        ),
        isFalse,
      );
    });

    test('文档没加载完不算好，哪怕 href 已经是目标', () {
      const target = 'https://jwgl.example.edu.cn/portal/scriptPage';
      expect(
        isTargetDocumentLoaded(
          beforeHref: 'https://jwgl.example.edu.cn/login',
          currentHref: target,
          readyState: 'interactive',
          targetHref: target,
        ),
        isFalse,
      );
      expect(
        isTargetDocumentLoaded(
          beforeHref: 'https://jwgl.example.edu.cn/login',
          currentHref: target,
          readyState: null,
          targetHref: target,
        ),
        isFalse,
      );
    });

    test('href 读不到时一律不算好（首次导航、导航瞬间都算没就绪）', () {
      expect(
        isTargetDocumentLoaded(
          beforeHref: 'https://a/x',
          currentHref: null,
          readyState: 'complete',
          targetHref: 'https://a/y',
        ),
        isFalse,
      );
      expect(
        isTargetDocumentLoaded(
          beforeHref: 'https://a/x',
          currentHref: '',
          readyState: 'complete',
          targetHref: 'https://a/y',
        ),
        isFalse,
      );
    });

    test('落到目标页且 complete 才算就绪；重定向到子路径同样认', () {
      expect(
        isTargetDocumentLoaded(
          beforeHref: 'https://a/login',
          currentHref: 'https://a/portal/scriptPage',
          readyState: 'complete',
          targetHref: 'https://a/portal/scriptPage',
        ),
        isTrue,
      );
      expect(
        isTargetDocumentLoaded(
          beforeHref: 'https://a/login',
          currentHref: 'https://a/portal/home?from=redirect',
          readyState: 'complete',
          targetHref: 'https://a/portal/scriptPage',
        ),
        isTrue,
      );
    });

    test('目标就是当前页（重载）时不要求 href 变化，避免必定等超时', () {
      const same = 'https://a/portal/scriptPage';
      expect(
        isTargetDocumentLoaded(
          beforeHref: same,
          currentHref: same,
          readyState: 'complete',
          targetHref: same,
        ),
        isTrue,
      );
      expect(
        isTargetDocumentLoaded(
          beforeHref: same,
          currentHref: same,
          readyState: 'loading',
          targetHref: same,
        ),
        isFalse,
      );
    });

    test('只差 fragment 不算换页，hash 路由导航能立刻通过', () {
      expect(
        isTargetDocumentLoaded(
          beforeHref: 'https://a/app#/timetable',
          currentHref: 'https://a/app#/import',
          readyState: 'complete',
          targetHref: 'https://a/app#/import',
        ),
        isTrue,
      );
      expect(
        isTargetDocumentLoaded(
          beforeHref: 'https://a/app#/timetable',
          currentHref: 'https://a/app#/timetable',
          readyState: 'complete',
          targetHref: 'https://a/app#/timetable',
        ),
        isTrue,
      );
    });

    test('导航前读不到 URL（冷启动）时，complete 即就绪', () {
      expect(
        isTargetDocumentLoaded(
          beforeHref: null,
          currentHref: 'https://a/portal',
          readyState: 'complete',
          targetHref: 'https://a/portal',
        ),
        isTrue,
      );
      expect(
        isTargetDocumentLoaded(
          beforeHref: '   ',
          currentHref: 'https://a/portal',
          readyState: 'complete',
          targetHref: 'https://a/portal',
        ),
        isTrue,
      );
    });
  });

  group('importCompletionAction', () {
    // 旧判定（course_import_screen.dart 的 case 'complete'）只看宏回放的两种
    // 情形，其余一律 finalize，完全不看本轮导入是否已经定局。
    ImportCompletionAction legacy({
      required bool isMacroReplay,
      required bool waitingForCourses,
      required bool quickResultHandled,
    }) {
      if (isMacroReplay) {
        if (waitingForCourses) return ImportCompletionAction.showStatusOnly;
        if (quickResultHandled) return ImportCompletionAction.ignore;
      }
      return ImportCompletionAction.finalize;
    }

    test('取消之后迟到的 complete 不再把状态刷成已完成', () {
      // 用户在「替换还是合并」里点了取消：屏幕把 _isExecutingImport 复位、
      // 状态写成「导入已取消」并弹错误提示。而 saveImportedCourses 在 JS 侧是
      // fire-and-forget（postMessage 后立刻 return true），脚本接着就发 complete
      // —— 旧口径据此把状态改成「导入流程已完成」，取消掉的导入在状态栏里
      // 显示成功。
      expect(
        importCompletionAction(
          isExecutingImport: false,
          isMacroReplay: false,
          playbackWaitingForCourses: false,
          quickResultHandled: false,
        ),
        ImportCompletionAction.ignore,
      );
      expect(
        legacy(
          isMacroReplay: false,
          waitingForCourses: false,
          quickResultHandled: false,
        ),
        ImportCompletionAction.finalize,
      );
    });

    test('失败/超时后同样忽略；定局判定排在宏回放之前', () {
      expect(
        importCompletionAction(
          isExecutingImport: false,
          isMacroReplay: true,
          playbackWaitingForCourses: true,
          quickResultHandled: false,
        ),
        ImportCompletionAction.ignore,
      );
    });

    test('正常执行中仍照常收尾，宏回放的两种既有分支不变', () {
      expect(
        importCompletionAction(
          isExecutingImport: true,
          isMacroReplay: false,
          playbackWaitingForCourses: false,
          quickResultHandled: false,
        ),
        ImportCompletionAction.finalize,
      );
      expect(
        importCompletionAction(
          isExecutingImport: true,
          isMacroReplay: true,
          playbackWaitingForCourses: true,
          quickResultHandled: false,
        ),
        ImportCompletionAction.showStatusOnly,
      );
      expect(
        importCompletionAction(
          isExecutingImport: true,
          isMacroReplay: true,
          playbackWaitingForCourses: false,
          quickResultHandled: true,
        ),
        ImportCompletionAction.ignore,
      );
    });

    test('全组合不变量：不在执行中就一定忽略；非宏回放绝不只刷状态', () {
      for (final executing in [true, false]) {
        for (final macro in [true, false]) {
          for (final waiting in [true, false]) {
            for (final quickHandled in [true, false]) {
              final action = importCompletionAction(
                isExecutingImport: executing,
                isMacroReplay: macro,
                playbackWaitingForCourses: waiting,
                quickResultHandled: quickHandled,
              );
              if (!executing) {
                expect(action, ImportCompletionAction.ignore);
              }
              if (!macro) {
                expect(action, isNot(ImportCompletionAction.showStatusOnly));
              }
              if (executing && macro && waiting) {
                expect(action, ImportCompletionAction.showStatusOnly);
              }
            }
          }
        }
      }
    });
  });

  group('isEntryDocumentReady（回放别抢跑）', () {
    test('空白文档不算就绪：about:blank 与空 href 都挡掉', () {
      // WebView 刚创建、请求还没回来时的真实形态。
      expect(
        isEntryDocumentReady(href: 'about:blank', readyState: 'complete'),
        isFalse,
      );
      expect(
        isEntryDocumentReady(href: 'about:srcdoc', readyState: 'complete'),
        isFalse,
      );
      expect(isEntryDocumentReady(href: null, readyState: 'complete'), isFalse);
      expect(isEntryDocumentReady(href: '   ', readyState: 'complete'), isFalse);
    });

    test('真实页面但还在加载也不算就绪（旧实现这一步根本不存在）', () {
      for (final state in ['loading', 'interactive', null, '']) {
        expect(
          isEntryDocumentReady(
            href: 'http://jw.cqcst.edu.cn/cqdxcskjxy_jsxsd/',
            readyState: state,
          ),
          isFalse,
          reason: 'readyState=$state 时不该放行',
        );
      }
    });

    test('页面到位且 complete 才放行，http 明文站也算', () {
      expect(
        isEntryDocumentReady(
          href: 'http://jw.cqcst.edu.cn/cqdxcskjxy_jsxsd/',
          readyState: 'complete',
        ),
        isTrue,
      );
      expect(
        isEntryDocumentReady(
          href: 'https://jwgl.example.edu.cn/login',
          readyState: 'complete',
        ),
        isTrue,
      );
    });

    test('实测日志那一刻的组合必须判「没就绪」', () {
      // 日志里页面打开 46.483s、回放 46.485s 就开始；那一刻 46.795s 宿主还探到
      // hasPasswordField=false，说明读到的根本不是登录页。
      expect(
        isEntryDocumentReady(href: 'about:blank', readyState: 'loading'),
        isFalse,
      );
    });
  });

  group('macroElementFound（只有明确找到才算找到）', () {
    test('found:true 才算找到', () {
      expect(macroElementFound('{"found":true,"tag":"INPUT"}'), isTrue);
      expect(macroElementFound('{"found":true,"skipped":true}'), isTrue);
    });

    test('found:false 不算找到，继续轮到超时', () {
      expect(macroElementFound('{"found":false,"selector":"#userAccount"}'), isFalse);
    });

    test('读不懂的返回值一律按「没找到」处理，绝不当成功', () {
      for (final raw in ['', 'true', 'complete', '{}', '[1,2]', 'null',
        r'{\"found\":false}']) {
        expect(macroElementFound(raw), isFalse, reason: 'raw=$raw');
      }
    });

    test('JSON 编码过的返回值先归一化再判，仍能认出 found:false', () {
      const androidQuoted = r'"{\"found\":false,\"selector\":\"#user\"}"';
      expect(macroElementFound(normalizeWebScriptResult(androidQuoted)), isFalse);
    });
  });

  group('macroElementExplicitlyMissing（断言口径）', () {
    test('只有 found:false 才算「明确没找到」', () {
      expect(
        macroElementExplicitlyMissing('{"found":false,"selector":"#user"}'),
        isTrue,
      );
      expect(macroElementExplicitlyMissing('{"found":true}'), isFalse);
      // 读不懂不等于没找到：断言路径不能凭这个凭空报错。
      for (final raw in ['', 'true', 'complete', '{}', '[1]']) {
        expect(macroElementExplicitlyMissing(raw), isFalse, reason: 'raw=$raw');
      }
    });

    test('两个口径在读不懂时明确分开', () {
      // 同一个输入，断言口径说不报错，轮询口径说要继续等。
      const unreadable = 'complete';
      expect(macroElementExplicitlyMissing(unreadable), isFalse);
      expect(macroElementFound(unreadable), isFalse);
      // 而 found:false 两边一致：断言报错、轮询继续等。
      const missing = '{"found":false}';
      expect(macroElementExplicitlyMissing(missing), isTrue);
      expect(macroElementFound(missing), isFalse);
    });
  });

  group('macroSelectorCandidates（坏兜底的替代）', () {
    test('纯 id 选择器额外派生同名的 name 选择器', () {
      expect(macroSelectorCandidates('#userAccount'), [
        '#userAccount',
        'input[name="userAccount"]',
      ]);
    });

    test('旧兜底拼出来的那条永远匹配不上，新派生才正确', () {
      const selector = '#userAccount';
      // 旧实现：document.querySelector('input[name="#userAccount"]')
      const legacyFallback = 'input[name="#userAccount"]';
      expect(legacyFallback, 'input[name="#userAccount"]');
      expect(
        macroSelectorCandidates(selector),
        isNot(contains(legacyFallback)),
      );
      // 真页面（重庆城市科技学院强智模板）只有 id，没有 name：
      // <input type="text" id="userAccount" value="" />
      expect(macroSelectorCandidates(selector).last, 'input[name="userAccount"]');
    });

    test('复合选择器不派生根不存在的 name 变体', () {
      for (final selector in [
        'input#userAccount',
        '.login form > input',
        'input[name="userAccount"]',
        '#a b',
        '#',
        '',
        '  ',
      ]) {
        expect(
          macroSelectorCandidates(selector).length,
          selector.trim().isEmpty ? 0 : 1,
          reason: 'selector=$selector',
        );
      }
    });

    test('选择器里的引号不会拼出可注入的 name 变体', () {
      expect(macroSelectorCandidates('#a"b'), ['#a"b']);
    });

    test('首个候选就是原选择器，行为与旧实现的前半段一致', () {
      expect(macroSelectorCandidates('  #userAccount  ').first, '#userAccount');
    });
  });

  group('defaultMacroElementWaitMs（等元素的预算）', () {
    test('预算是 10 秒：旧实现只固定等 300ms', () {
      expect(defaultMacroElementWaitMs, 10000);
      expect(defaultMacroElementWaitMs, greaterThan(300));
    });
  });
}
