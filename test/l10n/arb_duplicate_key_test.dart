import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/l10n/app_localizations_en.dart';
import 'package:university_timetable/l10n/app_localizations_ja.dart';
import 'package:university_timetable/l10n/app_localizations_ko.dart';
import 'package:university_timetable/l10n/app_localizations_zh.dart';
import 'package:university_timetable/l10n/enum_localizations.dart';
import 'package:university_timetable/models/bing_wallpaper.dart';
import 'package:university_timetable/models/wallpaper_daily_source.dart';

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
    /// ⚠️ 断言必须钉在 `bingWallpaperResolutionLabel(...)` 这种**用户看得见的返回值**上。
    /// 早先那条断言查的是枚举内部键 `value.storageKey`，内部键当然互不相同，于是恒绿
    /// 而界面上真的出现了两个「高清」（见文件头那段说明）。
    Map<String, AppLocalizations> allLocales() => <String, AppLocalizations>{
      'zh': AppLocalizationsZh(),
      'zh_TW': AppLocalizationsZhTw(),
      'zh_HK': AppLocalizationsZhHk(),
      'en': AppLocalizationsEn(),
      'ja': AppLocalizationsJa(),
      'ko': AppLocalizationsKo(),
    };

    test('每种语言下三个画质档位都给出三个不同的名字', () {
      for (final entry in allLocales().entries) {
        final labels = <String>[
          for (final value in BingWallpaperResolution.values)
            bingWallpaperResolutionLabel(entry.value, value),
        ];
        expect(
          labels.toSet().length,
          labels.length,
          reason:
              '${entry.key}：${labels.join(' / ')} —— 有重名，用户分不清选的是哪一档。',
        );
      }
    });

    test('⭐ 每种语言下两个图源都给出两个不同的名字', () {
      // 2026-10-07 加第二个图源时新踩的同一个坑：图源胶囊是两个，若文案重名，用户
      // 完全不知道自己切的是哪个源（而「切了源没反应」正是最难查的一类报障）。
      for (final entry in allLocales().entries) {
        final labels = <String>[
          for (final value in WallpaperDailySource.values)
            wallpaperDailySourceLabel(entry.value, value),
        ];
        expect(
          labels.toSet().length,
          labels.length,
          reason: '${entry.key}：${labels.join(' / ')} —— 两个图源重名了。',
        );
      }
    });

    test('图库入口行标题随图源变（两源不能共用同一个标题）', () {
      // 入口行原来写死「Bing 每日壁纸」。加了第二个源之后那行会说谎：用户点进去看到
      // 的是另一个图库，标题却还写着 Bing。
      for (final entry in allLocales().entries) {
        final labels = <String>[
          for (final value in WallpaperDailySource.values)
            wallpaperDailySourceGalleryLabel(entry.value, value),
        ];
        expect(
          labels.toSet().length,
          labels.length,
          reason: '${entry.key}：两个图源共用同一个图库标题，点进去会认不出来。',
        );
        // 且不得为空串 —— 空标题在按钮上就是一片空白。
        for (final label in labels) {
          expect(label.trim(), isNotEmpty, reason: '${entry.key}：图库标题是空的。');
        }
      }
    });
  });
}