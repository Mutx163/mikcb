package com.mutx163.qingyu.app

/**
 * 通知 / 超级岛标题与副标题的拼装（纯函数，本文件无 Android 依赖，JVM 单测直接钉）。
 *
 * 2026-11-15 用户口径：**用户输入的课名必须原样显示**，宽度放不下只能末尾省略，
 * 不许自己截断、不许改写。于是标题只放课名（原来按 8 字截断成 `…`、岛上按 5 字
 * 截断，两处都删了）；阶段前缀（即将上课 / 即将下课 / 上课中）挪到副标题槽
 * （超级岛 `baseInfo.subTitle`、系统通知 `setSubText`）。
 *
 * 放不下的处理交给系统：通知标题与岛标题都是单行末尾省略，不需要我们补 `..`。
 */

/**
 * 标题用的课名：开了「岛内使用简称」且简称非空时用简称，否则用**完整课名**。
 *
 * 这里**不做任何长度处理**——截断是上一版的做法，会吃掉括号里的楼栋/教室号，
 * 也会让「同一门课不同周次」的名字看起来像别的课。
 *
 * @param courseName 课名原文（用户输入，永远不改写）
 * @param shortName 用户配的简称（可能为空）
 * @param useShortName 「岛内使用课名简称」开关
 */
fun liveNotificationCourseName(
    courseName: String,
    shortName: String,
    useShortName: Boolean,
): String = if (useShortName && shortName.isNotBlank()) shortName else courseName

/**
 * 副标题槽：阶段前缀 + 原有明细（时间 / 地点），中间用两个空格加间隔点连起来。
 *
 * 两段都可能为空：明细为空时只留前缀（开课前还没算出行程），前缀为空时只留明细，
 * 两段都空返回空串（调用方据此决定是否 `setSubText`）。
 */
fun liveNotificationSubText(prefix: String, detail: String): String =
    listOf(prefix, detail)
        .filter { it.isNotBlank() }
        .joinToString("  ·  ")
