import '../models/course_task.dart';

/// 日视图「待办带」的一个分档。
///
/// 三档是**取数口径**，不是时间排序：作业只有截止日期、没有时刻，把它塞进
/// 时间线要么编一个假钟点（污染「X 开始 · Y 结束」摘要与钟点排序），要么让它
/// 恒沉底。分档让「今天该交什么 / 欠着什么 / 已经交了」这三件事各自成立。
///
/// 主流日历产品（Google Tasks deadline、Apple 提醒事项、TickTick 全天任务条、
/// Todoist、Notion Calendar、FullCalendar 的 allDaySlot、Flutter 的
/// calendar_view）一律把「只有日期」的条目放在顶部全天区而不进时间线，
/// 本枚举就是那条边界在数据层的落点。
enum DayTaskBandKind {
  /// 到期日已过、且未完成。**必须单独一档**：`isOverdue` 与 `isDueOn` 天然互斥
  /// （见 `CourseTask.isDueOn` / `isOverdue`），只按「今天到期」取数，
  /// 逾期任务会静默消失。考试「考完即消失」是用户拍板过的，因为考试是已发生
  /// 的事件；作业是欠着的待办，消失直接等于漏交。
  overdue,

  /// 今天到期、未完成。这是「今天要做的行动项」主体。
  today,

  /// 今天到期、已完成。**留在原地**不删：学生第二常见的动作是「勾错了撤销」，
  /// 勾完就消失（Google 那条路）会让翻回昨天的日视图看不到「那天交了什么」。
  completed,
}

/// 待办带的一行。
class DayTaskBandRow {
  final CourseTask task;
  final DayTaskBandKind kind;

  /// 逾期天数；非逾期档为 0。
  final int overdueDays;

  const DayTaskBandRow({
    required this.task,
    required this.kind,
    this.overdueDays = 0,
  });
}

/// 待办带的完整内容：三档各自的行 + 逾期折叠信息。
class DayTaskBandData {
  final List<DayTaskBandRow> overdue;
  final List<DayTaskBandRow> today;
  final List<DayTaskBandRow> completed;

  /// 被折叠掉的逾期条数（逾期超过 [DayTaskBandLogic.maxOverdueRows] 时）。
  final int hiddenOverdueCount;

  const DayTaskBandData({
    required this.overdue,
    required this.today,
    required this.completed,
    required this.hiddenOverdueCount,
  });

  static const DayTaskBandData empty = DayTaskBandData(
    overdue: [],
    today: [],
    completed: [],
    hiddenOverdueCount: 0,
  );

  bool get isEmpty => overdue.isEmpty && today.isEmpty && completed.isEmpty;
  bool get isNotEmpty => !isEmpty;

  /// 带子上要显示的作业条数（不含被折叠的逾期）。
  int get visibleCount => overdue.length + today.length + completed.length;

  /// 今天的行动项条数：逾期 + 今天到期未完成。摘要卡的「N 项作业」用它，
  /// 已完成的**不算**——摘要卡回答的是「今天还有几件没做」。
  int get actionableCount => overdue.length + today.length;
}

/// 日视图待办带的分档与排序（纯 Dart，无 Flutter 依赖）。
///
/// ## 取数口径
///
/// - **无 `dueDate` 的任务不归任何一天，日视图不出现。** 归到「今天」会让同一条
///   任务在一年里重复出现 300 多次，比不显示更糟；模型也没有「创建日当到期日」
///   这条语义（`CourseTask` 只有 `createdAt`，那是审计字段）。
/// - **已完成的不排除，但降档。** `isDueOn` 本身不看完成态
///   （`CourseTask.isDueOn`），照抄作业列表页的「全量收进来再按完成态分区」
///   会把勾掉的旧作业全捞回来；直接过滤掉又会让「今天交了没」无处可查。
/// - **今天 vs 逾期按日期比较，不按时刻。** `CourseTask.isOverdue` 内部用
///   `dateOnly`，所以「今天到期」在 23:59 之前都不算逾期；模型也不支持
///   「今天 18:00 截止」，日视图不做「过了某个钟点就变红」。
///
/// ## 排序
///
/// 不依赖标题字母序（中文标题的字母序对用户毫无意义）：
///
/// - 逾期：最早到期在前（欠得最久的先看见）；同日期按有无课程关联（有课的先）。
/// - 今天：**有关联课程的在前**，同课程按创建时间；无关联的垫底——「哪门课的
///   作业」比「随手记的一件事」有更多上下文，值得先看见。
/// - 已完成：按创建时间。
///
/// 全部档内在最后退化到 `id` 比较，保证排序是全序、稳定、可复现。
class DayTaskBandLogic {
  DayTaskBandLogic._();

  /// 逾期档最多显示这么多条，其余折叠成「还有 N 项逾期」。
  ///
  /// 一天忘交三份以上作业时，逾期带会把今天的内容顶下去；而逾期任务在补交
  /// 或改期之前**每天都会出现**，不设上限等于让一次疏忽永久占屏。
  static const int maxOverdueRows = 3;

  /// 组装某一天的待办带。
  ///
  /// [date] 是**日视图当页的目标日期**，必须由调用方用与课程同一条路径算出来
  /// （`_resolveDisplayDateForWeekDay`），不要另行 `DateTime.now()`——
  /// 日视图翻到别的周时两者不同。
  static DayTaskBandData resolve({
    required List<CourseTask> tasks,
    required DateTime date,
  }) {
    final today = CourseTask.dateOnly(date);
    final overdueRows = <DayTaskBandRow>[];
    final todayRows = <DayTaskBandRow>[];
    final completedRows = <DayTaskBandRow>[];

    for (final task in tasks) {
      final due = task.dueDate;
      if (due == null) {
        continue;
      }
      final dueDay = CourseTask.dateOnly(due);
      if (task.isCompleted) {
        // 已完成的只在**它自己到期那天**留一行记录；逾期完成的也一样——
        // 勾完就消失会让翻回昨天看不到「那天交了什么」。
        if (dueDay == today) {
          completedRows.add(
            DayTaskBandRow(task: task, kind: DayTaskBandKind.completed),
          );
        }
        continue;
      }
      if (dueDay == today) {
        todayRows.add(
          DayTaskBandRow(task: task, kind: DayTaskBandKind.today),
        );
        continue;
      }
      if (dueDay.isBefore(today)) {
        overdueRows.add(
          DayTaskBandRow(
            task: task,
            kind: DayTaskBandKind.overdue,
            overdueDays: today.difference(dueDay).inDays,
          ),
        );
      }
      // dueDay 在未来：不在这条带的语义里（那是「以后要交的」，不是今天的事）。
    }

    overdueRows.sort(_compareOverdue);
    todayRows.sort(_compareToday);
    completedRows.sort(_compareCompleted);

    final hidden = overdueRows.length > maxOverdueRows
        ? overdueRows.length - maxOverdueRows
        : 0;
    final visibleOverdue = hidden > 0
        ? overdueRows.sublist(0, maxOverdueRows)
        : overdueRows;

    return DayTaskBandData(
      overdue: visibleOverdue,
      today: todayRows,
      completed: completedRows,
      hiddenOverdueCount: hidden,
    );
  }

  /// 逾期：最早到期在前；同日期有课程关联的在前；最后按 id。
  static int _compareOverdue(DayTaskBandRow left, DayTaskBandRow right) {
    final dueCompare = left.task.dueDate!.compareTo(right.task.dueDate!);
    if (dueCompare != 0) {
      return dueCompare;
    }
    final courseCompare = _courseRank(left.task).compareTo(
      _courseRank(right.task),
    );
    if (courseCompare != 0) {
      return courseCompare;
    }
    return left.task.id.compareTo(right.task.id);
  }

  /// 今天到期：有课程关联的在前；同课程按创建时间；最后按 id。
  static int _compareToday(DayTaskBandRow left, DayTaskBandRow right) {
    final courseCompare = _courseRank(left.task).compareTo(
      _courseRank(right.task),
    );
    if (courseCompare != 0) {
      return courseCompare;
    }
    final courseIdCompare = (left.task.courseId ?? '').compareTo(
      right.task.courseId ?? '',
    );
    if (courseIdCompare != 0) {
      return courseIdCompare;
    }
    final createdCompare = left.task.createdAt.compareTo(right.task.createdAt);
    if (createdCompare != 0) {
      return createdCompare;
    }
    return left.task.id.compareTo(right.task.id);
  }

  /// 已完成：按创建时间；最后按 id。
  static int _compareCompleted(DayTaskBandRow left, DayTaskBandRow right) {
    final createdCompare = left.task.createdAt.compareTo(right.task.createdAt);
    if (createdCompare != 0) {
      return createdCompare;
    }
    return left.task.id.compareTo(right.task.id);
  }

  /// 0 = 有课程关联（排前面），1 = 无关联（垫底）。
  static int _courseRank(CourseTask task) {
    final courseId = task.courseId;
    return courseId == null || courseId.trim().isEmpty ? 1 : 0;
  }

  /// 这一天的标题文案该用哪个默认标题兜底（`title` 为空时）。
  ///
  /// `homeworkMark` 来源的作业允许标题为空（课程备注里只勾了「有作业」没写字，
  /// 见 `syncHomeworkTasksWithCourses`：`noteTitle.isEmpty && existing == null`
  /// 时才会跳过，换言之已有任务就这么保持空标题）。空标题在日视图上会显示成
  /// 一片空白行，必须有兜底。
  static bool needsDefaultTitle(CourseTask task) =>
      task.title.trim().isEmpty;
}
