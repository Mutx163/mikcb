package com.mutx163.qingyu.pages.import

/**
 * ICS 表头 / 正文前缀的**功能识别串**（Lead 裁决 2026-11-04，结构收敛形态）。
 *
 * ## 这些字符串是什么
 *
 * ICS 文件的 `DESCRIPTION` / `SUMMARY` 等自由文本里，各教务系统写出的字段名并不统一
 * （「教师」也可能写成「老师」，「地点」也可能写成「教室」）；解析器用这些**中文匹配串**
 * 对文件内容做 `contains` / 前缀判断，再把值归到教师、地点、简介、备注等字段。
 * 它们逐字来自 Dart 侧的同名匹配表，改一个字就会让旧导出文件认不出字段。
 *
 * ## 硬规矩
 *
 * - **仅用于 ICS 表头匹配，禁止用于屏上文案**（UI 文案一律走 ARB / ImportStrings）；
 * - 本文件按 cjk 棘轮登记在 `cjk-literal-baseline-main.txt`（命中行即下方 const）；
 * - ⚠️ **文件名不得含 `Strings` / `Arb`**：门禁按文件名排除整文件，撞名会让基线行悬空，
 *   也会让这些匹配串从待办清单里隐身。
 *
 * 原先散在 [IcsImportModel] 的 16 处中文字面量（同别名重复出现）收敛为 9 个常量。
 */
internal object IcsHeaderKeywords {

    /** 「第 X-Y 节」节次写法的前缀。 */
    const val SECTION_OPEN = "第"

    /** 「第 X-Y 节」节次写法的后缀。 */
    const val SECTION_CLOSE = "节"

    /** 教师字段（主别名）。 */
    const val TEACHER = "教师"

    /** 教师字段（旧导出别名）。 */
    const val TEACHER_ALT = "老师"

    /** 地点字段（主别名）。 */
    const val LOCATION = "地点"

    /** 地点字段（旧导出别名）。 */
    const val LOCATION_ALT = "教室"

    /** 简介字段（主别名）。 */
    const val DESCRIPTION = "简介"

    /** 简介字段（旧导出别名）。 */
    const val DESCRIPTION_ALT = "描述"

    /** 备注字段。 */
    const val NOTE = "备注"
}
