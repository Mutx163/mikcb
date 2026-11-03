package com.mutx163.qingyu.pages.settings

import com.mutx163.qingyu.app.TimetableSettingsModel

/**
 * 课程卡片 / 课表页面两页顶部挖洞预览的**入参唯一出口**：预览拿到的永远是宿主当前草稿。
 *
 * ## 为什么必须是一条「只认草稿」的窄函数
 *
 * 这两页的预览槽由壳注入（`ShellPageIndex.SettingsTimetablePreviewSlot`），旧实现自己在
 * `remember(wiring) { wiring.settingsModel.load() }` 里读了一次盘 —— 于是页面里改开关、
 * 拖滑杆只动了宿主内存草稿（写盘还是 250ms 防抖，甚至根本没写），预览一直停进页那一刻的
 * 存档，**必须退出重进才变**（2026-11-03 用户实报）。
 *
 * 修法是把草稿顺着宿主的 `preview(model)` 传进去。函数签名里**只有 `draft` 一个参数**，
 * 没有「盘上存档」这条路可走：将来谁想「等落盘再刷预览」，要么改签名（守卫会红），
 * 要么绕开本函数（源码守卫会红）。
 *
 * ## 语义（与外观编辑页一致）
 *
 * - 滑杆拖动中：宿主每 tick 改内存草稿 → 这里就返回哪一档，逐帧跟手，**不等落盘**；
 * - 普通开关：宿主落盘校验通过后换草稿 → 预览用新草稿；
 * - 落盘失败：宿主把草稿拉回盘上真值 → 预览跟着回滚，不会停在没存下的档位。
 *
 * 本函数不写盘、不做防抖，纯值传递 —— JVM 单测直接钉这三条。
 */
fun settingsPreviewDraft(draft: TimetableSettingsModel): TimetableSettingsModel = draft
