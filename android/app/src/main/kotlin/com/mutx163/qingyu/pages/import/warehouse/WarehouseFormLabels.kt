package com.mutx163.qingyu.pages.import.warehouse

/**
 * 网页表单 label 的**功能识别串**（Lead 拍板 2026-11-03，方案 A 收敛形态；
 * 见 `docs/plans/2026-11-03-night-autopilot-log.md`「九、决定与理由」需Lead#9）。
 *
 * ## 这些字符串是什么
 *
 * 教务站登录页的输入框经常把 `type` 改成 text、name 换成混淆串（kmbm 一类）规避识别；
 * 录制/回放引擎靠 `placeholder` / `aria-label` / `name` 里的**中文提示词**判断
 * 「这是验证码框还是密码框」。本对象集中这些**匹配串**——它们是对网页文本与
 * Dart 旧存档做 `contains` 比对的**功能字符**，逐字来自 Dart
 * `warehouse_macro_models.dart` / 录制 JS，改一个字就和 Dart 写出的旧宏对不上。
 *
 * ## 硬规矩
 *
 * - **禁止用于屏上文案**（UI 文案走 ARB / WarehouseStrings）；
 * - 本文件按 cjk 棘轮登记在 `cjk-literal-baseline-main.txt`（3 条，换行不加行）；
 * - ⚠️ **文件名不得含 `Strings`/`Arb`**：门禁按文件名排除整文件，名字撞排除标记
 *   会让基线行悬空（「已修复但基线未下调」红），也会让这三条从待办清单里隐身——
 *   Lead 拍板明确要求它们留在基线里可见。
 */
internal object WarehouseFormLabelStrings {
    /** 验证码框识别（「验证码」）。 */
    const val CAPTCHA_PRIMARY = "验证码"

    /** 验证码框识别（「校验码」）。 */
    const val CAPTCHA_SECONDARY = "校验码"

    /** 密码框识别（「密码」）。 */
    const val PASSWORD = "密码"
}
