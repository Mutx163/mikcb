package com.mutx163.qingyu.calendar

/**
 * 兼容别名（P1-11，2026-11-11）：日期规则模型**不再有第二份**。
 *
 * 真源是 [com.mutx163.qingyu.core.ScheduleDateRule]（落盘真源，JSON 契约在那里）。
 * 保留这个别名只是为了让 calendar 域既有的引用与 KDoc 不撕开；新代码直接引 core。
 *
 * 该文件原先还带一份日历侧副本（Dart 风格 `copy`、严格 `fromJson`、`toJsonString`），
 * 那些成员已并入 core 真源；`ScheduleDateRuleAutoApply` 里的
 * `toCalendarDateRule` / `toCoreDateRule` 两个转换函数随之删除（两边已是同一类型）。
 */
typealias ScheduleDateRule = com.mutx163.qingyu.core.ScheduleDateRule
