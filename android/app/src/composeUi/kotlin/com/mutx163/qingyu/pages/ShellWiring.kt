package com.mutx163.qingyu.pages

import android.content.Context
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.platform.LocalContext
import com.mutx163.qingyu.app.TimetableRepository
import com.mutx163.qingyu.app.TimetableSaveDispatcher
import com.mutx163.qingyu.app.TimetableStore
import com.mutx163.qingyu.core.Course
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
 * 1. **课程详情入口**：Dart 点课程弹的是**操作弹层**（`course_action_sheet.dart`，6 个动作：
 *    编辑 / 调课 / 停课复课 / 删除 / 加作业 / 单节课提醒）。Kotlin 侧其中 4 个动作**全仓 0 命中**，
 *    且弹层要落在 `pages/course/`。补一个只剩「编辑 + 删除」的残弹层是负价值，
 *    所以本轮**不补**——这两个动作现在都能用（点课程进编辑页，编辑页里能删）。
 *    建议单列一批「课程操作弹层」。
 * 2. **档案管理 / 切档案**：只做到「能跳过去」，页内动作尚未接全。
 * 3. **显示偏好**（隐藏周末 / 时间列宽 / 节次行高 / 长按空档加课）来自宿主默认值，
 *    不是从用户存档读的——等设置族完整模型到位后改（见 `TimetableHostDisplayPrefs` KDoc）。
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
        // **整组替换**，不是逐课 update：编辑态删掉的课次必须真的从仓储消失。
        // 判据等价关系由 `TimetableHostLogicTest` 的跨层契约测试钉住：
        // 编辑 ⟺ `payload.targetGroupName != null`（所以这里只传组名，不传 mode）。
        TimetableSaveDispatcher.applySave(
            port = timetable,
            originalGroupName = payload.targetGroupName,
            courses = payload.courses,
        )
    }

    /**
     * 编辑态删除。
     *
     * 壳目前只以**单课形态**进编辑页（没有 courseGroup 上下文），所以走 SingleCourse
     * （Dart `add_course_screen.dart:448-473`）；将来接组编辑入口时，
     * 这里把 `originalGroupName` 传成组名就会自动走整组删除（`:1406-1425`），分派器不用改。
     *
     * @return true 表示删除成功（调用方据此决定是否关页）
     */
    fun deleteEditingCourse(): Boolean {
        val target = TimetableSaveDispatcher.resolveDeleteTarget(
            originalGroupName = null,
            initialCourse = pendingEditCourse,
        ) ?: return false
        return try {
            TimetableSaveDispatcher.applyDelete(timetable, target)
            true
        } catch (_: Exception) {
            // Dart 口径：落盘失败**不报成功、不关页**，由页面弹 deleteFailed。
            false
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
