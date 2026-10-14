import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 防回归：ARB 里同一个键只能出现一次。
///
/// ## 为什么要单独盯这个
///
/// JSON 解析**不报错**，重复的键按「后出现的赢」静默取一个。所以这不是编译期或运行期
/// 能发现的问题，只会在界面上冒出来：2026-10-06 Bing 壁纸页那排画质胶囊里有两个
/// 「高清」，原因就是 6 个 `app_*.arb` 都把 `bingWallpaperResolutionStandard` 写了
/// 两遍（先「标准」后「高清」），后一遍把前一遍吃掉了。
///
/// 所以这里**不**走 `jsonDecode`（那正是会把重复键吞掉的东西），而是按仓库统一的
/// 两空格缩进格式直接扫原文里的键。
void main() {
  const locales = <String>['zh', 'zh_TW', 'zh_HK', 'en', 'ja', 'ko'];

  // 顶层键一律两空格缩进；嵌套对象（`@key` 的内容）缩进更深，不会被这个模式捞到。
  // 键名里允许 `\"` 这种转义，于是匹配的是「键值对引号闭合后紧跟冒号」的那一行。
  final topLevelKey = RegExp(r'^ {2}(?!\s)"((?:[^"\\]|\\.)*)"\s*:');

  group('ARB 键不能重复', () {
    for (final locale in locales) {
      test('app_$locale.arb 里没有重复的键', () {
        final path = 'lib/l10n/app_$locale.arb';
        final file = File(path);
        expect(file.existsSync(), isTrue, reason: '$path 不存在');

        final firstLine = <String, int>{};
        final duplicates = <String>[];
        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final match = topLevelKey.firstMatch(lines[i]);
          if (match == null) {
            continue;
          }
          final key = match.group(1)!;
          final previous = firstLine[key];
          if (previous != null) {
            duplicates.add('$key（第 $previous 行与第 ${i + 1} 行）');
          } else {
            firstLine[key] = i + 1;
          }
        }

        expect(
          duplicates,
          isEmpty,
          reason:
              '$path 里有重复的键。JSON 会**静默**取最后一个，界面上就变成「两个键共用'
              '一个名字」（Bing 壁纸的画质胶囊曾因此出现两个「高清」）。删掉多出来的那一行。',
        );
      });
    }
  });

  group('界面上的胶囊文案不能重名', () {
    /// 界面症状的直接断言：胶囊一行几个，名字就必须能区分开。
    ///
    /// 六个语言都要过 —— 重复键是**逐语言**写进去的，只查中文会漏掉另外五个。
    ///
    /// ⚠️ 断言必须钉在**用户看得见的返回值**上。
    /// 早先那条断言查的是枚举内部键 `value.storageKey`，内部键当然互不相同，于是恒绿
    /// 而界面上真的出现了两个「高清」（见文件头那段说明）。

    // 画质档位胶囊与图源胶囊的两个「不能重名」测试随 2026-10-14 的功能移除删除：
    // 画质不再有选项、图源只剩 Bing，胶囊本身没了。（历史教训保留在上面的注释里。）
  });
}