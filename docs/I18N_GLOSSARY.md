# i18n 术语表

一句话：**同一样东西，六份 ARB 里不许有两种叫法。**

表里每一行都是从 `i18n/app_*.arb` 的现有取值反查出来的，并注明**依据键**——写现状，不写偏好。
改一行等于同时改六份 ARB 和所有用到它的屏，请当接口变更处理：改完跑
`python tool/gen_compose_arb_catalog.py`，再跑 `python scripts/i18n-copy-gap.py --check`。

- 真源：`i18n/app_*.arb`（`zh` 是原文，其余五份是译文）；链路与固定步骤见 [WEB_AND_L10N_WORKFLOW.md](WEB_AND_L10N_WORKFLOW.md)。
- 新概念**先在这张表加一行，再写文案**。不加，下一个人一定会再造一个叫法。
- 「待定」区是还没定的口径：出现分歧时先问，别擅自选一个。

## 已定

| 概念 | zh | en | ja | ko | zh_TW | zh_HK | 依据键 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 课表 | 课表 | timetable | 時間割 | 시간표 | 課表 | 課表 | `allTimetablesBullet` |
| 学期 | 学期 | semester | 学期 | 학기 | 學期 | 學期 | `selectSemesterWeekCountTitle` |
| 开学日期 | 开学日期 | Semester Start Date | 学期開始日 | 학기 시작일 | 開學日期 | 開學日期 | `semesterStartDateLabel` |
| 校历 | 校历 | calendar | 校暦 | 학사일정 | 校曆 | 校曆 | `icsStep3Subtitle`、`importSemesterMappingNoShiftHint` |
| 周次 | 周次 | week | 週次 | 주차 | 週次 | 週次 | `importCourseWeeksTrimmed` |
| 节次 | 节次 | section | 時限 | 교시 | 節次 | 節次 | `aiPreviewMaxSection` |
| 导入 | 导入 | Import | インポート | 가져오기 | 匯入 | 匯入 | `importFromFileAction` |
| 导出 | 导出 | Export | エクスポート | 내보내기 | 匯出 | 匯出 | `appLogsExportAction` |
| 教务系统 | 教务系统 | School system | 教務システム | 교무 시스템 | 教務系統 | 教務系統 | `importMethodWarehouseTitle` |
| 日志 | 日志 | log | ログ | 로그 | 日誌 | 日誌 | `warehouseImportExecutionLogTitle` |
| 重试 | 重试 | Retry | 再試行 | 재시도 | 重試 | 重試 | `cloudBackupRetryAction` |
| 校区 | 校区 | campus | キャンパス | 캠퍼스 | 校區 | 校區 | `executeStageAwaitSelection` |

「校区」是 3.0.1 才进文案的新概念：仓库里原来只有代码注释用「校区」，六份 ARB 一次都没出现过，
所以这六种写法是**新定**的，不是沿用旧口径。

## 两个容易写错的字

- **曆 ≠ 歷**：日历、校历、行事历用 `曆`；经历、历史用 `歷`。繁中曾有两处把「校曆」写成「校歷」。
- **周 → 週（只改繁中）**：週次、每週、一週用 `週`；`周圍 / 周邊 / 周全 / 周到 / 周知 / 周長 / 周而復始`
  这类词根仍写 `周`。判据是词义不是字形，机械替换会改坏后者。

## 已知不一致（还没统一，别照着抄）

| 概念 | 现状 | 备注 |
| --- | --- | --- |
| 导出（繁中） | `匯出` 36 / 35 处，`導出` 8 / 9 处，同一份文件里都有 | 以 `匯出` 为主，但没清理干净；统一前先问 |
| 添加 / 新增（简中） | 两种都有 | 同一个动作用了两套词 |
| 保存 / 儲存 | 简中「保存」，繁中「儲存」 | 是否统一取决于繁中用户习惯 |
| 超级岛（英文） | Live Island / Super Island / Island 三套 | 英文名未定 |
