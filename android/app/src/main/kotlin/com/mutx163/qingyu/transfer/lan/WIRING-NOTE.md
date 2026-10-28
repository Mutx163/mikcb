# 接线说明：局域网编辑 HTTP 服务端（task-6 第一切片）

> 由 `cap-webview` 在 **2026-10-28** 写。**接线由 Lead / 页面负责人执行**：
> `pages/transfer/**` 是 P3-G3-c 已交付的渲染层，本泳道只新建
> `android/app/src/{main,test}/kotlin/com/mutx163/qingyu/transfer/lan/` 下的文件。
>
> 本文件按「**怎么接**」+「**没接什么**」两段写。第二段是硬要求，别当成免责声明跳过：
> 里面有 5 个**能接但本切片没接**的端点（Kotlin 侧依赖已就绪），接线时按需补。

## 一、这一片做了什么

真 HTTP 服务端（`java.net.ServerSocket` 手写 HTTP/1.1，**零新依赖**）：

| 文件 | 作用 |
|---|---|
| `LanEditHttp.kt` | 报文层纯函数：请求行/头/查询串/百分号解码、限额、响应序列化 |
| `LanEditApiRouter.kt` | 路由与业务规则 + `LanEditHost` 契约 + 审计出口 |
| `LanEditHttpServer.kt` | 监听、接受连接、一连接一工作线程、读头读体、写响应、停服 |

已实现的端点（状态码与响应体形状逐条对齐 Dart `lan_edit_api_handlers.dart`）：

| 方法与路径 | 行为 |
|---|---|
| `OPTIONS *` | 204（预检不吃鉴权） |
| `GET /api/v1/health` | 200 `{ok, serverTime}`，免鉴权 |
| `POST /api/v1/auth/verify` | 200 `{token, expiresAt}` / 401 `session_expired`·`invalid_pin` / 429 `rate_limited` |
| `GET /api/v1/session` | 200 `{profileId, profileName, profiles, activeWeek, semesterWeekCount, serverTime, expiresAt}` |
| `GET /api/v1/courses` | 200 `{courses:[…]}` |
| `POST /api/v1/courses` | 201 课程 JSON / 400 `course_name_required`·`profile_id_required`·`profile_id_mismatch` / 409 `profile_mismatch` |
| `GET/PATCH/DELETE /api/v1/courses/{id}` | 200 / 400 / 404 |
| `POST /api/v1/import/preview` | 200 预览 / 400 `backup_content_required` / 501 `transfer_preview_not_supported` |

横切规则：跨源 403、Bearer 令牌、`Content-Type: application/json` 强制、请求体 5 MiB 上限、
并发上限 16（超出 503）、头 431 / 体 413 / 超时 408、异常不回显原文（500 `internal_error`）。

## 二、怎么接（三步）

### 1. 实现 `LanEditHost`（数据面适配器）

`LanEditApiRouter` 只依赖接口。真实实现要接 `course/TimetableCourseService` +
`TimetableCoursePort` + provider（**同步**：服务端一个连接一个工作线程，若底层是
`suspend` 就在适配器里 `runBlocking`，那个线程不是主线程）。

```kotlin
class ProviderLanEditHost(...) : LanEditHost {
    override fun ensureInitialized() { /* 确保 provider 已加载 */ }
    override val activeProfileId: String? get() = ...
    override val courses: List<Course> get() = ...
    override fun createCourse(draft: Course): Course = ...
    override fun updateCourse(course: Course): Boolean = ...   // false = 记录已不在
    override fun deleteCourse(id: String): Boolean = ...
    override fun previewTransferJson(content: String): Map<String, Any?>? = ...  // 不支持就返回 null
    ...
}
```

### 2. 起停服务

```kotlin
val session = LanEditSession.create()                 // 已有：share/LanEditSession.kt（PIN/令牌/限速/过期）
val audit = LanEditAuditRingBuffer()                   // 或自己实现 LanEditAuditSink 落到 AppLog
val router = LanEditApiRouter(host = ProviderLanEditHost(...), session = session, audit = audit)
val server = LanEditHttpServer(router = router, audit = audit)   // 绑 0.0.0.0，端口由系统分配
val port = server.start()                              // 页面显示 http://<ip>:<port>
...
server.stop("manual")                                  // 页面关闭 / 用户点停止
```

- 局域网 IP 展示：`share/LanAddressScoring.kt`（`pickPreferredLanIPv4`）+ 网卡枚举（IO 部分自备）。
- **前台服务**：Android 侧已有 `LanEditForegroundService.kt`（Dart `LanEditForegroundBridge` 的对应物），
  接线时要在 `start()` 成功后拉起、`stop()` 后收起；本泳道的服务端**不碰通知**。
- **空闲自动停服**：见下面「未移植」第 12 条。

### 3. 静态资源（网页本体）

Dart 从 Flutter asset 发 `index.html` / `app.js` / `i18n.js` / 样式 / 图标。
Kotlin 侧要发的是 Android `assets/lan_edit/**`（需把这些前端产物放进 `assets/`，属接线），
实现方式是给 `LanEditApiRouter` 加一个「非 `/api/` 前缀」的分支，
或在外面包一层 `LanEditStaticAssets`（建议后者：本泳道的路由只管 API）。
**CSP 头必须照 Dart `_lanEditContentSecurityPolicy` 原样带上**（那段头是防注入的实际防线）。

## 三、**未移植清单**（本切片刻意没做，逐条给原因）

### A. 能接、且 Kotlin 侧依赖已就绪（接线时按需补，工作量都是「加一个分支」）

| # | 端点 / 能力 | 依赖现状 |
|---|---|---|
| 1 | `GET /api/v1/meta` | `LanEditHost.buildMetaJson()` 已在契约里 |
| 2 | `POST /api/v1/week-expression/parse` | `calendar/WeekExpressionParser.kt` 已存在 |
| 3 | `PATCH /api/v1/session`（切当前周） | 需给 `LanEditHost` 加 `setCurrentWeek(Int)` |
| 4 | `GET /api/v1/profiles` + `POST /api/v1/profiles/switch` | 需给契约加 `switchProfile(String)` |
| 5 | `POST /api/v1/courses/batch-delete` | 需给契约加 `deleteCoursesBatch(List<String>)` |

### B. 需要更深的数据面（本切片不碰）

| # | 端点 | 缺什么 |
|---|---|---|
| 6 | `GET/PUT /api/v1/profile/active`（整份档案备份导出/导入） | `buildProfileBackupJson` / `importProfileBackupJson` 未进契约 |
| 7 | `PUT /api/v1/courses/group`（按课名整组替换） | `replaceCourseGroup` 未进契约 |
| 8 | `POST /api/v1/import/spreadsheet` | 需要表格解析结果类型 + `importSpreadsheetCourses` |
| 9 | `POST /api/v1/import/apply` | 需要 `LanTransferHost.applyTransferJson` + `TransferApplyMode` + 撤销令牌 |
| 10 | `POST /api/v1/import/merge` | Dart 里这条**本来就被 409 `transfer_preview_required` 拒掉**（强制先 preview 再 apply）；要照抄这个拒绝行为，不是照抄功能 |

### C. 有意的行为差异（不是漏，是有取舍，逐条给理由）

| # | 差异 | 理由 / 影响 |
|---|---|---|
| 11 | **每连接只处理一个请求**（响应恒 `Connection: close`） | keep-alive 要完整连接复用状态机（流水线、半关连接）；局域网页面一次加载几个请求，收益远小于风险 |
| 12 | **没有空闲自动停服定时器**（Dart 每 30 秒查 `session.isExpired` → `stop('idle_timeout')`） | 会话**授权**仍然会过期：`isExpired` 为真时每个请求都回 401 `session_expired`，所以不是安全缺口；只是套接字不会自己关。接线方若要复刻，起一个 30 秒的调度调 `server.stop("idle_timeout")` 即可 |
| 13 | **不支持 `Transfer-Encoding: chunked`** | 明确 400；自己写 chunked 解码器或信对端长度都不划算 |
| 14 | 请求体上限 5 MiB、并发 16、空闲 60 秒 | 与 Dart 数值一致（`_maxRequestBodyBytes` / `_maxConcurrentRequests` / `idleTimeout`） |
| 15 | 时间戳用 `Instant.toString()`（UTC，带 `Z`） | Dart `toIso8601String()` 给本地时间且不带时区；两者都是 ISO-8601，前端 `new Date()` 都能解。要逐字对齐就改成 `SimpleDateFormat` 本地时区 |
| 16 | 周次表达式联动未做 | Dart `courseFromApiJson` / `mergeCoursePatch` 会调 `applyWeekExpressionFields`（`weekExpression` → 周次数组）；本切片建/改课只走 `Course.fromJson` 的既有归一化。**后果**：网页端发 `weekExpression` 字段会被忽略 |
| 17 | 对端可控的学期周数未做收敛 | Dart `_safeSemesterWeekCount` 把对端给的 `semesterWeekCount` 收敛到 1..60（防 `List.generate(10^9)` OOM）。本切片**不从对端取这个值**（只用 host 自己的），所以该 OOM 面不存在；但第 16 条补上时**必须**一起补这个收敛 |

### D. 只有真机能验

真机上的表现（手机热点下电脑连得上、浏览器页面能不能正常交互、前台服务通知、
息屏后连接是否还在）本泳道**未验**——设备铁律：未经用户明确允许不碰真机。

## 四、验收命令

```bash
# L0：真 socket 往返（含 200/400/401/403/404/429/431/413、畸形请求行、半途断连、并发）
pwsh -NoProfile -Command "& './scripts/test-kotlin-module.ps1' -Module 'pages/transfer' \
  -ExtraSources 'android/app/src/test/kotlin/com/mutx163/qingyu/transfer/lan/LanEditHttpParseTest.kt',\
'android/app/src/test/kotlin/com/mutx163/qingyu/transfer/lan/LanEditApiRouterTest.kt',\
'android/app/src/test/kotlin/com/mutx163/qingyu/transfer/lan/LanEditHttpServerTest.kt'"

# 真 Gradle（L0 绿不算数：`com.sun.*` 那次教训）
pwsh -NoProfile -File scripts/safe-gradle.ps1 :app:compileProdDebugUnitTestKotlin
```
