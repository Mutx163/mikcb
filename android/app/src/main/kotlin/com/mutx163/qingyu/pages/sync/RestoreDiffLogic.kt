package com.mutx163.qingyu.pages.sync

import com.mutx163.qingyu.sync.canonicalJson
import com.mutx163.qingyu.sync.canonicalize

/**
 * 云端恢复**差异概要**的纯逻辑：恢复前比较「云端快照」与「当前本机」，
 * 按档案 / 课程 / 时间方案三类给出「将新增、覆盖、删除」的数量概要。
 *
 * ## 口径
 *
 * 三类都**按 id 集合比对**（档案 `id`、课程 `id`、时间方案 `id`），只给数量不给清单
 * ——逐条 diff 列表是信息量过载，用户确认前只需要知道影响面：
 * - 新增 = 云端有、本机没有的 id 数；
 * - 删除 = 本机有、云端没有的 id 数；
 * - 覆盖 = 两边同 id 但内容不同（canonical JSON 不等）的 id 数。
 *
 * 课程内嵌在档案里：课程比对在**同 id 档案对**内做，再跨档案求和；只存在于
 * 本机的档案，其全部课程按「删除」计；只存在于云端的档案，其全部课程按「新增」计。
 *
 * ## 如实省略
 *
 * 某类在云端快照里**缺键或不是列表**时，该类计数置 null、界面整行省略——拿不到
 * 就不编。经协调器 [WebdavSyncCoordinator.fetchSnapshotBytes] 取到的正文已过信封门
 * （`profiles` / `timeSchemes` 必须是列表），实际恢复路径三类都可计算；本函数仍对
 * 缺键免疫（Dart 侧写的快照、将来的格式演进都直接落进省略分支）。解析不出 `id`
 * 的脏条目无法追踪归属，不参与计数（与 [CloudRestoreUndoPlanner] 同口径）。
 *
 * 本机没有用户数据（无档案）时按空表比对：全部计「新增」。
 */
object RestoreDiffLogic {

    /** 比对两份快照 payload，算三类概要。[local] 为 null = 本机没有用户数据。 */
    fun summarize(
        cloud: Map<String, Any?>,
        local: Map<String, Any?>?,
    ): RestoreDiffSummary {
        val localMap: Map<*, *> = local ?: emptyMap<Any?, Any?>()
        val cloudProfiles = cloud.list("profiles")
        return RestoreDiffSummary(
            profiles = cloudProfiles?.let { diffById(it, localMap.list("profiles").orEmpty()) },
            courses = cloudProfiles?.let { diffCourses(it, localMap.list("profiles").orEmpty()) },
            timeSchemes = cloud.list("timeSchemes")?.let { diffById(it, localMap.list("timeSchemes").orEmpty()) },
        )
    }

    /** 一类集合的按 id 概要计数。 */
    private fun diffById(cloud: List<Any?>, local: List<Any?>): RestoreDiffCounts {
        val cloudById = indexById(cloud)
        val localById = indexById(local)
        var overridden = 0
        for ((id, cloudItem) in cloudById) {
            val localItem = localById[id] ?: continue
            if (!sameJson(cloudItem, localItem)) overridden++
        }
        val added = cloudById.keys.count { it !in localById }
        val removed = localById.keys.count { it !in cloudById }
        return RestoreDiffCounts(added = added, overridden = overridden, removed = removed)
    }

    /** 课程概要：同 id 档案内按课程 id 比对后求和；单边档案的课程整档计入新增 / 删除。 */
    private fun diffCourses(cloudProfiles: List<Any?>, localProfiles: List<Any?>): RestoreDiffCounts {
        val localById = indexById(localProfiles)
        var added = 0
        var overridden = 0
        var removed = 0
        val cloudProfileIds = HashSet<String>()
        for (profile in cloudProfiles) {
            val profileId = idOf(profile) ?: continue
            cloudProfileIds.add(profileId)
            val localCourses = (localById[profileId] as? Map<*, *>)?.list("courses") ?: emptyList()
            val counts = diffById((profile as? Map<*, *>)?.list("courses") ?: emptyList(), localCourses)
            added += counts.added
            overridden += counts.overridden
            removed += counts.removed
        }
        for (profile in localProfiles) {
            val profileId = idOf(profile) ?: continue
            if (profileId in cloudProfileIds) continue
            removed += courseCount(profile)
        }
        return RestoreDiffCounts(added = added, overridden = overridden, removed = removed)
    }

    /** 档案内的课程条数（缺 / 坏按 0，与 [CloudBackupIndexCodec.countCoursesInSnapshot] 同口径）。 */
    private fun courseCount(profile: Any?): Int =
        (profile as? Map<*, *>)?.list("courses")?.size ?: 0

    private fun indexById(items: List<Any?>): Map<String, Any?> {
        val out = LinkedHashMap<String, Any?>()
        for (item in items) {
            val id = idOf(item) ?: continue
            out[id] = item
        }
        return out
    }

    private fun idOf(item: Any?): String? = (item as? Map<*, *>)?.get("id") as? String

    private fun sameJson(left: Any?, right: Any?): Boolean =
        canonicalJson(canonicalize(left)) == canonicalJson(canonicalize(right))

    /** 快照顶层的列表键；缺键 / 不是列表返回 null（调用方决定按省略还是按空表）。 */
    private fun Map<*, *>.list(key: String): List<Any?>? = this[key] as? List<Any?>
}

/** 一类数据的恢复影响计数（数量概要，不含条目清单）。 */
data class RestoreDiffCounts(
    /** 云端有、本机没有。 */
    val added: Int,
    /** 两边同 id 但内容不同。 */
    val overridden: Int,
    /** 本机有、云端没有。 */
    val removed: Int,
)

/** 三类概要；某类为 null = 云端快照里拿不到这类数据，界面整行省略。 */
data class RestoreDiffSummary(
    val profiles: RestoreDiffCounts?,
    val courses: RestoreDiffCounts?,
    val timeSchemes: RestoreDiffCounts?,
)

/** 恢复准备（下载 + 差异概要）的结局；字节已缓存待确认，不落任何盘。 */
sealed interface RestorePrepareOutcome {
    /** 已下载、已校验、概要已算好：确认后交 [CloudSyncController.confirmPreparedRestore] 应用。 */
    data class Ready(val diff: RestoreDiffSummary) : RestorePrepareOutcome

    /** 远端没有这条备份（与单步恢复同口径：不带错误码）。 */
    data object NotFound : RestorePrepareOutcome

    /** 未连接（拿不到协调器，与单步恢复同口径：不带错误码）。 */
    data object Missing : RestorePrepareOutcome

    /** 下载或校验失败；错误码已写进 `status.lastErrorCode`。 */
    data class Failed(val errorCode: String) : RestorePrepareOutcome
}
