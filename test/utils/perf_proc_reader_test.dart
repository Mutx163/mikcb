// `/proc/self/stat` 解析（`lib/utils/perf_proc_reader.dart`）的行为契约。
//
// 能耗代理指标的 CPU / RSS 就靠它。这是纯字符串解析，所以能脱离真机、
// 用写死的样本逐字段判定——期望值按 man proc 的字段序号**人工推出来**：
// 第 14 是 utime、第 15 是 stime（单位是 clock tick，不是微秒）、
// 第 24 是 rss（单位是内存页，不是字节）。
//
// 特意钉这个坑：第 2 个字段 comm 形如 `(name with spaces)`，直接按空格
// split 会把后面所有字段的序号整体挪位。真实进程名带空格/括号时，
// 「第 14 个 token」根本不是 utime——读数会静默错到别的字段上。
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/utils/perf_proc_reader.dart';

void main() {
  group('comm 带空格/括号的字段挪位坑', () {
    test('进程名带空格和括号时仍从最后一个 ) 之后取字段', () {
      // comm = "(my app (x))"：内部有空格又有括号。若按空格 naive split，
      // "app"、"(x))" 会被当成独立 token，其后所有字段序号整体挪位，
      // 「第 14 个 token」就不是 utime 了——这是 /proc/self/stat 的经典坑。
      // 真实 Android 进程名确实可能带空格（如多进程 `pkg:sub`）。
      final reading = parseProcSelfStat(
        _buildStat(
          comm: 'my app (x)',
          utimeTicks: 500,
          stimeTicks: 600,
          rssPages: 250,
        ),
        clockTicksPerSecond: 100,
        pageBytes: 4096,
      );
      // utime+stime = 1100 tick × (1e6/100) = 11,000,000 us
      expect(reading.cpuMicros, 11000000);
      // rss = 250 页 × 4096 字节 ÷ 1024 = 1000 KB
      expect(reading.rssKb, 1000);
    });
  });

  group('单位换算', () {
    test('tick → 微秒按 clockTicksPerSecond 折算（128Hz 设备不是 100）', () {
      final stat = _buildStat(comm: 'app', utimeTicks: 128, stimeTicks: 0, rssPages: 1);
      final reading = parseProcSelfStat(
        stat,
        clockTicksPerSecond: 128,
        pageBytes: 4096,
      );
      // 128 tick × (1e6/128) = 1,000,000 us
      expect(reading.cpuMicros, 1000000);
    });

    test('rss 页 → KB 按 pageBytes 折算', () {
      final stat = _buildStat(comm: 'app', utimeTicks: 0, stimeTicks: 0, rssPages: 100);
      final reading = parseProcSelfStat(
        stat,
        clockTicksPerSecond: 100,
        pageBytes: 4096,
      );
      expect(reading.rssKb, 400); // 100 × 4096 / 1024
    });

    test('utime 与 stime 都计入 CPU 时间（系统调用时间也是耗电）', () {
      final onlyUser = parseProcSelfStat(
        _buildStat(comm: 'a', utimeTicks: 700, stimeTicks: 0, rssPages: 1),
        clockTicksPerSecond: 100,
        pageBytes: 4096,
      );
      final onlySys = parseProcSelfStat(
        _buildStat(comm: 'a', utimeTicks: 0, stimeTicks: 700, rssPages: 1),
        clockTicksPerSecond: 100,
        pageBytes: 4096,
      );
      expect(onlyUser.cpuMicros, 7000000);
      expect(onlySys.cpuMicros, 7000000); // 内核时间同样算进 CPU 账
    });
  });

  group('坏输入一律给 null 字段，绝不抛', () {
    test('缺字段（行数被截断）→ 两栏都 null', () {
      final reading = parseProcSelfStat(
        '1234 (app) R 1',
        clockTicksPerSecond: 100,
        pageBytes: 4096,
      );
      expect(reading.cpuMicros, isNull);
      expect(reading.rssKb, isNull);
    });

    test('utime 位置是非数字 → null', () {
      final tokens = _buildStat(
        comm: 'app',
        utimeTicks: 100,
        stimeTicks: 0,
        rssPages: 10,
      ).split(' ');
      tokens[13] = 'garbage'; // 第 14 字段（下标 13）= utime
      final reading = parseProcSelfStat(
        tokens.join(' '),
        clockTicksPerSecond: 100,
        pageBytes: 4096,
      );
      expect(reading.cpuMicros, isNull);
    });

    test('空串 → 两栏 null（读 /proc 失败时上层拿到 null 而非崩）', () {
      final reading = parseProcSelfStat(
        '',
        clockTicksPerSecond: 100,
        pageBytes: 4096,
      );
      expect(reading.cpuMicros, isNull);
      expect(reading.rssKb, isNull);
    });

    test('clockTicksPerSecond / pageBytes 非法（0 或负）→ null 而不是除零', () {
      final stat = _buildStat(comm: 'app', utimeTicks: 100, stimeTicks: 0, rssPages: 10);
      expect(
        parseProcSelfStat(stat, clockTicksPerSecond: 0, pageBytes: 4096).cpuMicros,
        isNull,
      );
      expect(
        parseProcSelfStat(stat, clockTicksPerSecond: 100, pageBytes: 0).rssKb,
        isNull,
      );
    });
  });
}

/// 按 man proc 的真实字段序拼一行 stat。utime=第14、stime=第15、rss=第24。
/// ) 之后到 utime 之间隔着 11 个字段（state…starttime 之后才是 utime），
/// stime 与 rss 之间隔着 9 个字段。用占位大数 12345 便于 replaceFirst 定位。
String _buildStat({
  required String comm,
  required int utimeTicks,
  required int stimeTicks,
  required int rssPages,
}) {
  // 字段：pid comm state ppid pgrp session tty tpgid prio policy nice
  //       num_threads it_realtime starttime vruntime utime stime
  //       cutime cstime priority nice_prio num_threads2 ... rss
  // 精确数到 utime=14、stime=15、rss=24（整行、含 pid 与 comm）。
  final tokens = <String>[
    '1234', // 1 pid
    '($comm)', // 2 comm
    'R', // 3 state
    '1', // 4 ppid
    '1234', // 5 pgrp
    '0', // 6 session
    '-1', // 7 tty
    '0', // 8 tpgid
    '0', // 9 flags
    '12345', // 10 minflt
    '12345', // 11 cminflt
    '12345', // 12 majflt
    '12345', // 13 cmajflt
    '$utimeTicks', // 14 utime
    '$stimeTicks', // 15 stime
    '12345', // 16 cutime
    '12345', // 17 cstime
    '12345', // 18 priority
    '12345', // 19 nice
    '12345', // 20 num_threads
    '12345', // 21 itrealvalue
    '12345', // 22 starttime
    '12345', // 23 vsize
    '$rssPages', // 24 rss
  ];
  return tokens.join(' ');
}
