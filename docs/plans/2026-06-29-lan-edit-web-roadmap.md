# 局域网 Web 控制台演进路线图

> 关联：`docs/plans/2026-06-27-lan-edit-plan.md`、App 表格导入 `SpreadsheetImportService`、周次 `WeekExpressionParser`  
> 状态：按阶段逐项实现；每阶段需 `flutter analyze` + `flutter test`（含 `lan_edit_server_service_test.dart`）通过。

## 目标

在 **不引入前端构建链**（仍用 `assets/lan_edit/` 静态资源）的前提下，让电脑端能力与 App 近期能力对齐，并补齐编辑体验缺口。

---

## 阶段总览

| 阶段 | 内容 | 状态 |
|------|------|------|
| **P0-1** | 表格 CSV/XLSX 导入 API + Web 上传（合并 / 覆盖） | 已完成 |
| **P0-2** | 周次表达式（服务端解析 + 表单 + 预览 API） | 已完成 |
| **P0-3** | 自定义周次 / 停课周编辑 UI（表达式字段） | 已完成 |
| **P1-1** | 同步手机「当前周」（PATCH session） | 已完成 |
| **P1-2** | 课表网格「设为手机当前周」快捷按钮 | 已完成 |
| **P2** | 批量删除、合并导入备份、本地字体、手机端二维码 | 已完成 |

---

## P0-1：表格导入

### API

- `POST /api/v1/import/spreadsheet`
- Body: `{ "fileName": "x.csv", "contentBase64": "...", "replaceExisting": false }`
- 响应: `{ "importedCount", "warnings", "format" }`
- 实现：复用 `SpreadsheetImportService.parseBytes` + `TimetableProvider.importParsedCourses`（`source: spreadsheet`）

### Web

- 「导入与备份」页增加 **表格导入** 卡片：接受 `.csv` / `.xlsx`，勾选「覆盖现有课程」

### 测试

- `lan_edit_server_service_test.dart`：合法 mikcb CSV → 课程入库；非法格式 → 400

### 完成标准

- 与 `assets/templates/mikcb_course_import_template.csv` 真机/LAN E2E 导入一致；合并模式不删未匹配本地课。

---

## P0-2：周次表达式

### API

- `POST /api/v1/week-expression/parse`  
  Body: `{ "expression": "1-8、10-16(单)", "itemName": "课程名" }`  
  响应: `{ "weeks": [1,2,...] }` 或 400

### 数据写入

- 课程时间段 JSON 可选字段 `weekExpression`；保存 `courses/group` 时若存在则解析为 `customWeeks`，并推导 `startWeek`/`endWeek`/`isOddWeek`/`isEvenWeek`（与 App 导入逻辑一致）

### Web

- 每个时间段增加「上课周（表达式）」输入框 + 「预览」按钮

### 完成标准

- 与 `week_expression_parser_test.dart` 用例代表式在 LAN API 上结果一致

---

## P0-3：自定义周次 / 停课周

### Web

- 时间段表单：**上课周 / 停课周表达式** + 预览 API（与 App `WeekExpressionParser` 一致）；保存写回 `customWeeks` / `suspendedWeeks`

### API

- 已有 `customWeeks` / `suspendedWeeks` 字段，无需新路由

### 完成标准

- 含 `customWeeks` 的课在网格 `viewWeek` 过滤与 App 一致

---

## P1-1 / P1-2：当前周

### API

- `PATCH /api/v1/session` Body: `{ "currentWeek": 5 }`

### Host

- `LanEditProviderHost` → `TimetableProvider.setCurrentWeek`

### Web

- 课表工具栏：「将第 N 周设为手机当前周」

---

## P2（已完成）

- `POST /api/v1/courses/batch-delete` + 课程库多选批量删除  
- `POST /api/v1/import/merge`（备份 JSON 仅合并课程，`importParsedCourses` merge）  
- 去掉 Google Fonts 外链（系统字体栈）  
- 手机 `LanEditScreen` 展示 `qr_flutter` 二维码（`encodeLanEditUrl`）  

---

## 实现顺序（本次 Goal）

1. 本文档 ✓  
2. P0-1 后端 + 测试 + Web  
3. P0-2 后端 + 测试 + Web  
4. P0-3 Web  
5. P1-1 + P1-2  
6. 全量 `flutter test` + `flutter analyze`