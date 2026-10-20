// 「改设置 → 杀进程重开 → 设置还在」两阶段测试共用的定义。
//
// 与 `persist_fixture.dart`（课程持久化那条）同理：写阶段与读阶段必须用
// 完全一样的值，各抄一份迟早写歪，而那种错会以「测试莫名变红」的形式出现。
//
// 注意：本文件不含 `main()`，不是测试文件本身——被两个测试文件 import。

import 'package:university_timetable/models/settings/timetable_settings_enums.dart';

/// 本组测试要切换到的目标值。
///
/// ## 为什么选「玻璃坞」而不是 `classic`
///
/// 仓库里 `homeNavigationForm` 的默认值是 `classic`（timetable_settings.dart:781）。
/// 如果测试把目标定成 `classic`，那么「根本没写进去、读到默认值」这个 bug
/// 会让断言**照样通过**——测了个寂寞。选非默认值才能让断言有牙齿。
///
/// 这个理由值得记住：**持久化测试的目标值必须偏离默认值**，
/// 否则「写失败」与「写成功」在结果上不可区分。
const HomeNavigationForm kPersistedNavigationForm = HomeNavigationForm.glassDock;

/// 给阶段二比对的、人能读懂的名字（失败信息里用）。
const String kPersistedNavigationFormLabel = '玻璃坞（glassDock）';
