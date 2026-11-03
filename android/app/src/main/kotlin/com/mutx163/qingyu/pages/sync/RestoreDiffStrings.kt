package com.mutx163.qingyu.pages.sync

/**
 * 恢复差异概要的**临时文案表**（待 ARB 通道开放后并入 [SyncStrings]）。
 *
 * 为什么不直接进 [SyncStrings]：那里每一条都被 `SyncStringsParityTest` 与
 * `lib/l10n/app_zh.arb` 机械对拍，ARB 通道当前由另一路独占、本批不得改。
 * 三条键名已按 ARB 命名规范拟好（见各 [ArbText].key），Lead 入库后把
 * [all] 里的条目迁进 SyncStrings、渲染引用同步替换，本文件即可删除。
 *
 * 这些行是**对话框整宽段落**，不适用「行内文案单行宽度」口径（右侧无控件）。
 */
object RestoreDiffStrings {

    val cloudRestoreDiffProfiles = ArbText(
        "cloudRestoreDiffProfiles",
        "课表：新增 {added}、覆盖 {overridden}、删除 {removed}",
    )
    val cloudRestoreDiffCourses = ArbText(
        "cloudRestoreDiffCourses",
        "课程：新增 {added}、覆盖 {overridden}、删除 {removed}",
    )
    val cloudRestoreDiffTimeSchemes = ArbText(
        "cloudRestoreDiffTimeSchemes",
        "作息时间：新增 {added}、覆盖 {overridden}、删除 {removed}",
    )

    /** 待 Lead 入 ARB 的全部条目（迁移时逐条对照，勿漏）。 */
    val all: List<ArbText> = listOf(cloudRestoreDiffProfiles, cloudRestoreDiffCourses, cloudRestoreDiffTimeSchemes)

    /**
     * 差异概要行（按 课表 → 课程 → 作息时间 排序）。
     * 某类拿不到（null）时整行省略，不给「0 0 0」假装能算。
     */
    fun buildDiffLines(summary: RestoreDiffSummary): List<String> {
        val out = ArrayList<String>(3)
        summary.profiles?.let { out.add(cloudRestoreDiffProfiles.filled(it)) }
        summary.courses?.let { out.add(cloudRestoreDiffCourses.filled(it)) }
        summary.timeSchemes?.let { out.add(cloudRestoreDiffTimeSchemes.filled(it)) }
        return out
    }

    private fun ArbText.filled(counts: RestoreDiffCounts): String = filled(
        "added" to counts.added.toString(),
        "overridden" to counts.overridden.toString(),
        "removed" to counts.removed.toString(),
    )
}
