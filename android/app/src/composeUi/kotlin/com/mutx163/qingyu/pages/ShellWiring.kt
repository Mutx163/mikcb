package com.mutx163.qingyu.pages

import android.content.Context
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.platform.LocalContext
import com.mutx163.qingyu.app.TimetableRepository
import com.mutx163.qingyu.app.TimetableStore
import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.pages.course.AddCourseSaveMode
import com.mutx163.qingyu.pages.course.AddCourseSavePayload
import com.mutx163.qingyu.platform.PrefsKeyValueStore

/**
 * 壳的**接线层**（Phase 3.5 · L5，Lead 专属写作用域）。
 *
 * ## 它解决什么
 *
 * Phase 3 把 78 屏页面搬完了，但页面是「纯函数 + 数据入口」形态：状态从哪来、
 * 点了写到哪，都留给宿主。壳以前的做法是**喂演示数据 + 空回调**（137 处 `{}`），
 * 所以「点了没反应」。这一层把真仓储接上去。
 *
 * ## 为什么放在 composeUi 而不是 `composeP1/.../app/`
 *
 * 那里放的是**可复用的宿主层**（`TimetableHost`，将来正式包也用）。
 * 这里放的是**壳专属的装配**：壳有自己的包名、自己的 prefs、自己的导航语义
 * （底部四个槽位 + 页面层），这些东西正式包一样都不要。
 *
 * ## 数据落点
 *
 * 壳的包名带 `.ui`，所以它读写的是**自己的** `FlutterSharedPreferences`——
 * 与正式版（Flutter）的数据互不可见，这是 Android 的包隔离，不是 bug。
 * 好处是：格式是**同一套冻结格式**，将来正式包换成 Compose 时，
 * 把这一层原样搬过去就能直接读用户已有数据。
 *
 * ## 已知未接线（诚实清单）
 *
 * 1. **组编辑**（`UPDATE_GROUP`）只按单课逐个更新，**不做「整组替换」**：
 *    `TimetableCourseService.updateGroup` 需要原始组名，而壳从课表点进课程时
 *    只带得到那一门课。真做要先把「课程 → 所属组」的上下文传进来。
 * 2. **删课**：`AddCoursePage` 的 `onDelete` 还是空的（同一原因：需要组上下文）。
 * 3. 课程详情、档案管理、切档案这些入口只做到「能跳过去」，页内动作尚未接全。
 */
class ShellWiring(context: Context) {

    /** 课表仓储：壳里所有课表相关状态都从它来。 */
    val timetable: TimetableRepository =
        TimetableRepository(TimetableStore(PrefsKeyValueStore(context)))

    /**
     * 从课表空档进加课页时要预填的 `(星期, 节次)`。
     *
     * 放这里而不是 `remember` 在 Composable 里，是因为「点空档」发生在课表槽位，
     * 而加课页在页面层渲染——两者不是同一棵子树，共享不到局部状态。
     * 用完即清（见 [clearAddCourseSeed]），否则下次从按钮进加课页会被上次的坑位污染。
     */
    var pendingAddCourseSeed: Pair<Int, Int>? = null

    /** 从课表点某门课进加课页时要带进去的编辑对象；null = 新建。 */
    var pendingEditCourse: Course? = null

    fun clearAddCourseIntent() {
        pendingAddCourseSeed = null
        pendingEditCourse = null
    }

    /**
     * 加课页的保存载荷 → 仓储。
     *
     * `AddCoursePage` 的 KDoc 明确写着「保存载荷交给壳层落盘，由壳层按 mode 分派」，
     * 所以这个分派属于宿主职责，不是页面职责。
     */
    fun applyAddCourseSave(payload: AddCourseSavePayload) {
        when (payload.mode) {
            AddCourseSaveMode.ADD -> payload.courses.forEach(timetable::addCourse)
            // 组编辑：逐课更新（rename 由 `previousSharedName` 表达，这里没有那个上下文）。
            // ⚠️ 这**不等于**整组替换——组里被删掉的课不会被移除。见类注释「已知未接线」第 1 条。
            AddCourseSaveMode.UPDATE_GROUP -> payload.courses.forEach {
                timetable.updateCourse(it, previousSharedName = null)
            }
        }
    }
}

/**
 * 取（并在首次组合时构造）壳的接线层。
 *
 * 用 `applicationContext`：仓储要活过 Activity 重建，持有 Activity 的 Context 会泄漏。
 */
@Composable
fun rememberShellWiring(): ShellWiring {
    val context = LocalContext.current.applicationContext
    return remember { ShellWiring(context) }
}
