// 读 `/proc/self/stat` 拿进程 CPU 时间与 RSS，作为「每页能耗代理」的原始读数。
//
// 为什么是「能耗代理」而不是「功耗」：未 root 的设备读不到
// `/sys/class/power_supply/*/current_now`（2026-10-24 在 25060RK16C 实测
// Permission denied），也没有电量计的直接接口。进程 CPU 时间与驻留内存是
// 同源可测的替代量——它们衡量「这一页让硬件多干了多久、占了多少内存」，
// 与耗电正相关，且两版本差分可比。汇报里不许把它写成 mAh/瓦。
//
// 解析与读文件**分开**：`parseProcSelfStat` 是纯函数，用写死的 stat 行就能
// 逐字段判定（见 `test/utils/perf_proc_reader_test.dart`）；`readSelfCost`
// 只做 I/O，任何异常都吞掉给空读数。
library;

/// 一次 `/proc/self/stat` 读数。任一字段读不到/解析不出就是 null。
///
/// null 而不是 0：0 会被账本读成「这段时间没费 CPU」，而真实含义是
/// 「没量到」。把「零成本」与「未测到」混为一谈是差分表最坏的失真。
class ProcStatReading {
  const ProcStatReading({required this.cpuMicros, required this.rssKb});

  static const ProcStatReading empty = ProcStatReading(
    cpuMicros: null,
    rssKb: null,
  );

  /// 进程累计 CPU 时间（utime + stime，微秒）。
  final int? cpuMicros;

  /// 常驻内存 RSS（KB）。
  final int? rssKb;
}

/// man proc 里 `/proc/[pid]/stat` 的整行字段序号（从 1 起算，pid 是第 1 个）。
const int _utimeFieldIndex = 14;
const int _stimeFieldIndex = 15;
const int _rssFieldIndex = 24;

/// 解析一行 stat 文本。**comm 字段（第 2 个）可能含空格与括号**，
/// 所以必须先定位**最后一个 `)`**，再在其后的 token 上按序号偏移取值——
/// 直接按空格 split 会让其后所有字段整体挪位，把 minflt 当成 utime 读。
///
/// [clockTicksPerSecond] 是 USER_HZ（Linux 传统为 100，部分 Android 内核为
/// 128 或更高）；[pageBytes] 是内存页大小（通常 4096，部分 ARM 为 16384）。
/// 两者任一非正即视为不可换算，对应字段给 null。
ProcStatReading parseProcSelfStat(
  String statLine, {
  required int clockTicksPerSecond,
  required int pageBytes,
}) {
  // comm 是 `( … )` 形式，内部空格不算字段分隔。取**最后一个**右括号，
  // 因为 comm 本身可能含 `)`（例如 `pkg (sub) x)`）。
  final closeParen = statLine.lastIndexOf(')');
  if (closeParen < 0) {
    return ProcStatReading.empty;
  }
  final rest = statLine.substring(closeParen + 1).trim();
  final restTokens = rest.split(RegExp(r'\s+'));
  // restTokens[0] 是 state，即整行第 3 个字段。
  // 所以整行第 k 个字段 = restTokens[k - 3]。
  int? fieldAt(int oneBasedIndex) {
    final i = oneBasedIndex - 3;
    if (i < 0 || i >= restTokens.length) {
      return null;
    }
    return int.tryParse(restTokens[i]);
  }

  final utime = fieldAt(_utimeFieldIndex);
  final stime = fieldAt(_stimeFieldIndex);
  final rssPages = fieldAt(_rssFieldIndex);

  int? cpuMicros;
  if (utime != null && stime != null && clockTicksPerSecond > 0) {
    // 先乘后除：`1000000 ~/ 128` 会先把比例截成 7812（真值 7812.5），
    // 每 tick 少算半微秒——perf_proc_reader_test 里 128 tick 的用例
    // 抓到了这个（期望 1,000,000us，截断实现给 999,936）。
    cpuMicros = (utime + stime) * 1000000 ~/ clockTicksPerSecond;
  }

  int? rssKb;
  if (rssPages != null && pageBytes > 0) {
    // rss 字段是页数。× pageBytes 得字节，÷ 1024 得 KB。
    rssKb = (rssPages * pageBytes) ~/ 1024;
  }

  return ProcStatReading(cpuMicros: cpuMicros, rssKb: rssKb);
}
