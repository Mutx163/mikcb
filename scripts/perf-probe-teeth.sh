#!/bin/bash
# 性能探针的咬合探针（反向验证）：把每条关键判据故意改坏，确认对应用例**真的会红**。
#
# 为什么必须跑它：只证明「改完变绿了」不够 —— 把断言整条删掉，测试也会绿。
# 没有这一步，无法区分「测试在正常工作」与「测试已经变成永远绿的摆设」。
# 本仓 AGENTS.md 的 TEST-POLICY 把这条列为改断言/守卫类改动的硬要求。
#
# 判定口径（三条，缺一条这条变异就不算数）：
#   RED          = 用例在**运行期**断言失败 → 有牙齿
#   TOOTHLESS    = 改坏了还是全绿 → 测试没守住这条判据（必须补用例）
#   NO-VERDICT   = 编译错/加载失败 → 「为错误的理由而红」，不算证据，要重写变异
#
# ⚠️ 只能**串行、单实例**跑：本脚本会就地改写被测源文件，两个实例并发会互相
#    覆盖，把「已还原」的时刻夹进另一个实例的测试窗口，产出假绿。
#    2026-10-24 实际踩过：同脚本起两个实例，四条判据全报绿，是假证据。
#
# 用法：bash scripts/perf-probe-teeth.sh
set -u
cd "$(dirname "$0")/.." || exit 1

LEDGER=lib/utils/perf_page_ledger.dart
PROC=lib/utils/perf_proc_reader.dart
PROBE=lib/utils/perf_probe.dart
DIFF=tool/perf_diff.dart

T_LEDGER=test/utils/perf_page_ledger_test.dart
T_PROC=test/utils/perf_proc_reader_test.dart
T_PROBE=test/utils/perf_probe_test.dart
T_DIFF=test/utils/perf_diff_test.dart

BAK=$(mktemp -d)
cp "$LEDGER" "$PROC" "$PROBE" "$DIFF" "$BAK/"
restore() { for f in "$LEDGER" "$PROC" "$PROBE" "$DIFF"; do cp "$BAK/$(basename "$f")" "$f"; done; }
trap 'restore; rm -rf "$BAK"' EXIT

mutate() { # <file> <from> <to> ; 非 1 次命中即失败（防锚点漂移后改错地方）
  python -c '
import sys, io
p, f, t = sys.argv[1], sys.argv[2], sys.argv[3]
s = io.open(p, encoding="utf-8").read()
n = s.count(f)
if n != 1:
    sys.stderr.write("PATTERN-OCCURS-%d\n" % n); sys.exit(3)
io.open(p, "w", encoding="utf-8", newline="").write(s.replace(f, t))
' "$1" "$2" "$3"
}

verdict() { # <testfile> -> 只回三档之一
  local out
  out=$(flutter test --no-pub --timeout 120s "$1" 2>&1 \
        | grep -oE "\+[0-9]+ -[0-9]+|All tests passed|Error: " | tail -1)
  case "$out" in
    *"Error: "*) echo "NO-VERDICT(编译错，不算证据)" ;;
    *"-"*) echo "RED" ;;
    *passed*) echo "TOOTHLESS" ;;
    *) echo "NO-VERDICT($out)" ;;
  esac
}

# 还原后的复验用**独立**函数：那时「全绿」才是期望结果，
# 复用 verdict() 会打出 TOOTHLESS（它问的是"改坏后该红吗"），误导读日志的人。
is_green() {
  local out
  out=$(flutter test --no-pub --timeout 120s "$1" 2>&1 | grep -oE "All tests passed|Some tests failed" | tail -1)
  [ "$out" = "All tests passed" ] && echo "GREEN(期望)" || echo "*** 还原后仍红 ***"
}

PASS=0; FAIL=0
probe() { # <name> <src> <test> <from> <to>
  local name="$1" src="$2" tst="$3"
  cp "$BAK/$(basename "$src")" "$src"
  if ! mutate "$src" "$4" "$5" 2>/dev/null; then
    echo "  [SKIP] $name —— 锚点不符（源码已变，需更新本脚本）"; FAIL=$((FAIL+1)); return
  fi
  local v; v=$(verdict "$tst")
  case "$v" in
    RED) echo "  [ OK ] $name"; PASS=$((PASS+1)) ;;
    *)   echo "  [!!] $name -> $v"; FAIL=$((FAIL+1)) ;;
  esac
}

echo "===== perf_page_ledger.dart ====="
probe "fps 分子改用帧数（60Hz 稳定帧会被读成 72fps）" "$LEDGER" "$T_LEDGER" \
  '(frames < 2 || spanUs < 1000) ? null : (frames - 1) * 1000000 / spanUs;' \
  '(frames < 2 || spanUs < 1000) ? null : frames * 1000000 / spanUs;'
probe "不再用实测 vsync 收紧预算" "$LEDGER" "$T_LEDGER" \
  '    _sampleVsyncPeriod(vsyncUs);
' \
  '    if (vsyncUs != null) {
      _lastVsyncUs = vsyncUs;
    }
'
probe "短访问不再并入前一页" "$LEDGER" "$T_LEDGER" \
  'if (short && _seg.frames > 0) {' 'if (false) {'
probe "跨度改算墙上时间（含别页占走的）" "$LEDGER" "$T_LEDGER" \
  'agg.spanUs += lastFrameUs - firstFrameUs;' 'agg.spanUs += lastFrameUs - startUs;'
probe "读不到的成本被填成 0" "$LEDGER" "$T_LEDGER" \
  '    if (cpuStart != null && cost.cpuMicros != null) {
      agg.cpuMicros = (agg.cpuMicros ?? 0) + (cost.cpuMicros! - cpuStart!);
    }' \
  '    agg.cpuMicros = (agg.cpuMicros ?? 0) + ((cost.cpuMicros ?? 0) - (cpuStart ?? 0));'
probe "verdict 不再处理单边为 0" "$LEDGER" "$T_LEDGER" \
  'if (worstRasterUs == 0 || worstBuildUs >= worstRasterUs * 1.3) {' \
  'if (worstRasterUs > 0 && worstBuildUs >= worstRasterUs * 1.3) {'

echo "===== perf_proc_reader.dart ====="
probe "comm 用首个 ) 而非最后一个（进程名带括号即串位）" "$PROC" "$T_PROC" \
  "final closeParen = statLine.lastIndexOf(')');" \
  "final closeParen = statLine.indexOf(')');"
probe "漏算 stime（内核态 CPU 不计入）" "$PROC" "$T_PROC" \
  'cpuMicros = (utime + stime) * 1000000 ~/ clockTicksPerSecond;' \
  'cpuMicros = utime * 1000000 ~/ clockTicksPerSecond;'
probe "先除后乘的截断（128Hz 上每 tick 少半微秒）" "$PROC" "$T_PROC" \
  'cpuMicros = (utime + stime) * 1000000 ~/ clockTicksPerSecond;' \
  'cpuMicros = (utime + stime) * (1000000 ~/ clockTicksPerSecond);'
probe "clockTicks 非正不再拦（除零防护丢失）" "$PROC" "$T_PROC" \
  'if (utime != null && stime != null && clockTicksPerSecond > 0) {' \
  'if (utime != null && stime != null && clockTicksPerSecond >= 0) {'
probe "rss 单位改成字节（KB 口径失效）" "$PROC" "$T_PROC" \
  'rssKb = (rssPages * pageBytes) ~/ 1024;' 'rssKb = (rssPages * pageBytes);'

echo "===== perf_probe.dart ====="
probe "首页不再收敛行名（home 与 home:day 拆两行）" "$PROBE" "$T_PROBE" \
  "    if (normalized == 'TimetableScreen' ||
        normalized == 'AppEntryScreen' ||
        normalized == kHomeViewPagePrefix) {" \
  '    if (false) {'
probe "归一化不剥泛型参数" "$PROBE" "$T_PROBE" \
  "    final angle = value.indexOf('<');
    if (angle > 0) {
      value = value.substring(0, angle);
    }" \
  "    final angle = value.indexOf('<');
    if (false) {
      value = value.substring(0, angle);
    }"
probe "归一化不压平空白（换行会劈开报表行）" "$PROBE" "$T_PROBE" \
  "    value = value.replaceAll(RegExp(r'\s+'), ' ').trim();" \
  '    value = value.trim();'
probe "泛型兜底不排除 void" "$PROBE" "$T_PROBE" \
  "        const <String>{'void', 'dynamic', 'null'}.contains(normalized)) {" \
  '        const <String>{}.contains(normalized)) {'
probe "归一化不剥库前缀" "$PROBE" "$T_PROBE" \
  "    final dot = value.lastIndexOf('.');
    if (dot >= 0) {
      value = value.substring(dot + 1);
    }" \
  "    final dot = value.lastIndexOf('.');
    if (false) {
      value = value.substring(dot + 1);
    }"
probe "视图追踪器不再补记当前视图" "$PROBE" "$T_PROBE" \
  '    // 装好时用户可能已经停在日视图，先补记一次，否则那段帧全记到 boot 头上。
    _applyHomeView(modeName);' \
  '    // mutated: 跳过首记'

echo "===== tool/perf_diff.dart ====="
probe "样本下限防护失效（噪音页被报成恶化）" "$DIFF" "$T_DIFF" \
  '  if (lowSample && (jankyBad || cpuBad || jankyGood || cpuGood)) {' \
  '  if (false) {'
probe "缺读数回落成 0 而非 null" "$DIFF" "$T_DIFF" \
  '      ? (headCpu - baseCpu) * 100 / baseCpu
      : null;' \
  '      ? (headCpu - baseCpu) * 100 / baseCpu
      : 0.0;'
probe "frames 坏值被吞成 0 继续算（而非 SKIPPED）" "$DIFF" "$T_DIFF" \
  'int? _int(Object? value) => value is int ? value : null;' \
  'int? _int(Object? value) => value is int ? value : 0;'
probe "判据不一致不再警告" "$DIFF" "$T_DIFF" \
  '  if (bBudget is String && hBudget is String && bBudget != hBudget) {' \
  '  if (false) {'
probe "单侧页读数一律记到 base 栏" "$DIFF" "$T_DIFF" \
  '    baseFps: onBase ? fps : null,
    headFps: onBase ? null : fps,' \
  '    baseFps: fps,
    headFps: null,'

echo "===== 真机实测暴露的四条（2026-10-25 补） ====="
probe "启动打点不再缓冲（install 之前的 mainEnter 又丢了）" "$PROBE" "$T_PROBE" \
  '    _pendingStartup.add((label, _nowUs()));' \
  '    // mutated: 丢弃 install 之前的打点'
probe "会话轮转把 live 文件也当成可删的（巡检数据当场被清）" "$PROBE" "$T_PROBE" \
  '    final sessions = existingNames.where(_sessionNamePattern.hasMatch).toList()' \
  '    final sessions = existingNames.toList()'
probe "认不出页面时又拿路由类型名收工（真页面记成 MaterialPageRoute）" "$PROBE" "$T_PROBE" \
  '    return _genericArgumentOf(routeTypeString);
  }

  /// 从路由信息推出页面 id，按「越具体越优先」兜底：' \
  '    return _genericArgumentOf(routeTypeString) ??
        normalizePageId(null, widgetType: routeTypeString);
  }

  /// 从路由信息推出页面 id，按「越具体越优先」兜底：'
probe "报表头不再带 CPU 核数（cpuMs 读数没法解释）" "$PROBE" "$T_PROBE" \
  "      'cpuCount': Platform.numberOfProcessors," \
  "      // mutated: 去掉核数"

echo "===== 第二轮真机实测暴露的两条（2026-10-25 补） ====="
probe "vsync 不再按面板模式过滤（采到 6.2ms 就把预算压 26%）" "$LEDGER" "$T_LEDGER" \
  '    if (!_isPanelPeriod(gap)) {
      return;
    }' \
  '    // mutated: 跳过模式过滤'
probe "首页根 AppEntryScreen 不再收敛（拆成两行，启动账记到陌生类名下）" "$PROBE" "$T_PROBE" \
  "        normalized == 'AppEntryScreen' ||
" \
  ''

echo "===== 还原并复验全绿 ====="
restore
for f in "$LEDGER" "$PROC" "$PROBE" "$DIFF"; do
  cmp -s "$BAK/$(basename "$f")" "$f" || echo "  *** 还原不一致: $f ***"
done
echo "  源文件已字节级还原"
for pair in "$T_LEDGER" "$T_PROC" "$T_PROBE" "$T_DIFF"; do
  printf '  %-42s %s\n' "$(basename "$pair")" "$(is_green "$pair")"
done

echo "===== 合计：有牙齿 $PASS / 不达标 $FAIL ====="
[ "$FAIL" -eq 0 ] || exit 1
