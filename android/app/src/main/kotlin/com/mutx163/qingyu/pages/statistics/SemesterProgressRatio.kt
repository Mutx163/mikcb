package com.mutx163.qingyu.pages.statistics

import com.mutx163.qingyu.statistics.SemesterProgress

/**
 * 学期进度比例（0..1），**唯一**的钳位入口。
 *
 * 这是**有意偏离 Dart**的一处：
 * `lib/widgets/statistics/semester_progress_card.dart:85` 直接印
 * `(progress.percent * 100).round()%`，已上节数超过计划（换课/加课）时会显示 `156%`。
 * 学期进度 > 100% 意味着当前周次已越过学期总周数，属**数据不自洽**；
 * 展示 156% 会让用户以为计算错误。故本项目统一钳到 0..100（比例 0..1）。
 *
 * 硬要求：`SemesterProgressModel`（图表规格）与 `CourseStatisticsModel`（主页视图）
 * 都调本函数，**不许两处各写 `coerceIn`**——两处各自钳的写法已经漂移过一次
 * （一处钳、一处敞开展示 156%）。
 *
 * @param progress 统计进度；`null`（无统计数据）或计划总课时为 0
 *   （无开学日且无课表）时返回 0，既表示「算不出进度」，也避免除零。
 */
fun semesterProgressRatio(progress: SemesterProgress?): Double {
    if (progress == null) return 0.0
    if (progress.sectionsTotal <= 0) return 0.0
    return (progress.sectionsDone.toDouble() / progress.sectionsTotal).coerceIn(0.0, 1.0)
}
