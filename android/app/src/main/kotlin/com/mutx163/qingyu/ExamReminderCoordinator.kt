package com.mutx163.qingyu

import android.content.Context
import com.mutx163.qingyu.app.TimetableRepository
import com.mutx163.qingyu.pages.exam.ExamReminderLogic

/**
 * 把「考试变化 → 重排考试提醒」接起来（Compose 壳侧）。
 *
 * ## 链路
 *
 * `TimetableExamService` / `TimetableCourseService` / `ScheduleItemService`（增 / 改 / 删）
 * → `TimetableRepository.syncExamReminders()` → 本协调器安装的纯 Kotlin 回调
 * → [ExamReminderScheduler.reconcile]。
 *
 * 分层与 `ScheduleReminderCoordinator` 同一套：仓储在 `app/` 包必须保持纯 Kotlin，
 * 调度器用到 AlarmManager / Notification，只能待在 Android 侧；回调是两边唯一
 * 不互相依赖的接缝。
 *
 * ## 幂等
 *
 * 安装时立刻排一次（冷启动补排），之后每次相关变更再排一次；
 * `ExamReminderScheduler.reconcile` 整表替换、可重复调用。
 *
 * ## 只写考试源
 *
 * 本侧 payload 只含考试响点（日程提醒由 `ScheduleReminderScheduler` 的独立 prefs /
 * 渠道接管，单节课提醒走系统时钟）。若用户之前在 Dart 壳排过日程 / 单节课提醒，
 * 那些旧条目会在首次对账时被整表替换清掉——它们的接管方各在其位，不会丢提醒，
 * 只是换了管线。开机 / 换时区补排走 `ExamReminderReceiver`（清单已注册），
 * 读的是本协调器持久化的同一份快照，不受影响。
 */
object ExamReminderCoordinator {

    fun install(context: Context, repository: TimetableRepository) {
        val appContext = context.applicationContext
        repository.onExamRemindersChanged = {
            reconcileNow(appContext, repository)
        }
        // 冷启动补排：上次进程被杀时排好的闹钟仍在系统里，按当前数据整表对齐。
        reconcileNow(appContext, repository)
    }

    private fun reconcileNow(appContext: Context, repository: TimetableRepository) {
        val payload = ExamReminderLogic.buildPayload(
            exams = repository.exams,
            resolveCourse = { exam -> repository.getCourseById(exam.courseId) },
        )
        ExamReminderScheduler.reconcile(
            appContext,
            payload.fires,
            payload.activeExamIds,
            payload.activeFireKeys,
        )
    }
}
