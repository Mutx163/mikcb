# 接线说明：局域网编辑 HTTP 服务端（task-6，第一 + 第二切片）

> 由 `cap-webview` 在 **2026-10-28** 写。**接线由 Lead / 页面负责人执行**：
> `pages/transfer/**` 是 P3-G3-c 已交付的渲染层，本泳道只新建
> `android/app/src/{main,test}/kotlin/com/mutx163/qingyu/transfer/lan/` 下的文件。
>
> ## ⚠️ 接线时必须做的一件事
>
> **起服务时不要漏掉前台服务与静态资源**：本泳道只做 HTTP + API，不碰通知、不发网页文件。
> 少这两样，用户看到的是「服务起来了但浏览器打开是空的」。
>
> 空闲自动停服**已经做了，而且默认开启**（服务端默认 `sessionExpired = { router.isSessionExpired }`，
> 每 30 秒查一次，过期按 `idle_timeout` 停服）——接线方什么都不传也不会留下挂着的套接字。
> 只有测试里想完全手动控制时才显式传 `sessionExpired = null`。

## 一、已实现

真 HTTP 服务端（`java.net.ServerSocket` 手写 HTTP/1.1，**零新依赖**）：

| 文件 | 作用 |
|---|---|
| `LanEditHttp.kt` | 报文层纯函数：请求行/头/查询串/百分号解码、限额、响应序列化 |
| `LanEditApiRouter.kt` | 路由与业务规则 + `LanEditHost` 契约 + 审计出口 |
| `LanEditHttpServer.kt` | 监听、接受连接、一连接一工作线程、读头读体、写响应、停服、空闲看门狗 |

端点（状态码与响应体形状逐条对齐 Dart `lan_edit_api_handlers.dart`）：

| 方法与路径 | 行为 |
|---|---|
| `OPTIONS *` | 204（预检不吃鉴权） |
| `GET /api/v1/health` | 200 `{ok, serverTime}`，免鉴权 |
| `POST /api/v1/auth/verify` | 200 `{token, expiresAt}` / 401 `session_expired`·`invalid_pin` / 429 `rate_limited` |
| `GET /api/v1/session` | 200 `{profileId, profileName, profiles, activeWeek, semesterWeekCount, serverTime, expiresAt}` |
| `PATCH /api/v1/session` | 200 `{currentWeek}` / 400（周数 <1 或缺字段 / 超过学期周数） |
| `GET /api/v1/profiles` | 200 `{activeProfileId, profiles}` |
| `POST /api/v1/profiles/switch` | 200 `{profileId, profileName, profiles, meta}` / 400 / 404 |
| `GET /api/v1/meta` | 200 `host.buildMetaJson()` |
| `GET /api/v1/courses` | 200 `{courses:[…]}` |
| `POST /api/v1/courses` | 201 课程 JSON / 400 `course_name_required`·`profile_id_required`·`profile_id_mismatch` / 409 `profile_mismatch` |
| `GET/PATCH/DELETE /api/v1/courses/{id}` | 200 / 400 / 404 |
| `POST /api/v1/courses/batch-delete` | 200 `{deletedCount}` / 400 `ids_required` |
| `POST /api/v1/week-expression/parse` | 200 `{weeks, warnings}` / 400 `expression_required` |
| `POST /api/v1/import/preview` | 200 预览 / 400 `backup_content_required` / 501 `transfer_preview_not_supported`（Kotlin 侧还没有预览服务） |
| `GET /api/v1/profile/active` | 200 整份备份（传输包 JSON 对象，`scope=current_timetable`、`channel=lan`） |
| `PUT /api/v1/profile/active` | 200 `{imported:true}` / 400（校验不过，**一个字节都不写**） |
| `PUT /api/v1/courses/group` | 200 `{courses:[…]}`（按课名整组替换）/ 400 `at_least_one_schedule_slot`·`course_name_required`·`invalid_slot_entry` |
| `POST /api/v1/import/spreadsheet` | 200 `{importedCount, warnings, format}` / 400 `content_base64_required`·`content_base64_invalid` |
| `POST /api/v1/import/apply` | 200 应用结果 / 400 `transfer_content_and_mode_required` / 501 `transfer_apply_not_supported` |
| `POST /api/v1/import/merge` | **409 `transfer_preview_required`**（Dart 里这条端点就是故意拒的，照抄，不实现合并导入） |

横切规则：跨源 403、Bearer 令牌、`Content-Type: application/json` 强制、请求体 5 MiB 上限、
并发上限 16（超出 503）、头 431 / 体 413 / 超时 408、异常不回显原文（500 `internal_error`）、
host 未实现的可选能力一律 501（错误码 = 能力名）、`IllegalArgumentException` → 400
（对齐 Dart 各处 `on ArgumentError`）、
**空闲 30 秒轮询 + 会话过期自动停服（默认开启）**。

### 数据层：`LanEditRepositoryHost`（新增）

`LanEditRepositoryHost.kt` 是 `LanEditHost` 的**仓储实现**：局域网编辑的读写全部走
`TimetableRepository` / `TimetableCourseService`，**一个字节都不直接写 prefs**。

```kotlin
val host = LanEditRepositoryHost(
    repository = timetableRepository,                 // Phase 3.5 的 app/TimetableRepository
    parseSpreadsheet = { bytes, name, settings ->     // 注入：pages/import 不在 L0 共享名单里
        val r = SpreadsheetImportModel.parseBytes(bytes, name, settings)
        LanEditSpreadsheetParse(r.courses, r.warnings, r.format)
    },
)
val router = LanEditApiRouter(host = host, session = session, audit = audit)
```

三个必须知道的点：

1. **整份备份导入是「先校验后落盘」**：`validateTransferPackageJson` → 解析全部课程 →
   才 `clearActiveProfileCourses` + 逐门 `addCourse`。校验失败时盘上一字未变
   （有测试钉着，含真 HTTP 端到端）。
2. **恢复课程必须逐门 `addCourse`，不能用 `addGroup`**：`addGroup` 是「同一门课排在不同天」
   的工具，它会把整组名字统一成第一门课的名字——拿它恢复一份含多门不同课的备份，
   所有课名会被压成第一个。这是 2026-10-28 实测踩到的坑，测试当场变红。
3. **多档案整份恢复明确拒绝**（`profile_backup_profiles_unsupported`）：备份里 `profiles`
   非空时直接 400，不静默只恢复活动档案（那会无声吞掉用户其它课表）。
   要支持得给仓储加「替换整份档案表」的入口，属 Lead 决定的范围。

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
    override fun deleteCoursesBatch(courseIds: List<String>): Int = ...
    override fun setCurrentWeek(week: Int) = ...
    override fun switchProfile(profileId: String) = ...         // 失败抛 IllegalArgumentException("profile_not_found")
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

### 3. 静态资源（网页本体）

Dart 从 Flutter asset 发 `index.html` / `app.js` / `i18n.js` / 样式 / 图标。
Kotlin 侧要发的是 Android `assets/lan_edit/**`（需把这些前端产物放进 `assets/`，属接线），
实现方式是给 `LanEditApiRouter` 加一个「非 `/api/` 前缀」的分支，
或在外面包一层 `LanEditStaticAssets`（建议后者：本泳道的路由只管 API）。
**CSP 头必须照 Dart `_lanEditContentSecurityPolicy` 原样带上**（那段头是防注入的实际防线）。

## 三、**未移植清单**（逐条给原因）

### A. 已补上（原「等数据层」那 5 条，2026-10-28 第三切片完成）

| # | 端点 | 现状 |
|---|---|---|
| 1 | `GET /api/v1/profile/active` | ✅ 导出当前课表的传输包（用 `sync/buildTransferPackageJson`，不自拼 JSON） |
| 2 | `PUT /api/v1/profile/active` | ✅ 导入（先校验后落盘）。⚠️ 与 Dart 有一处**有意差异**：Dart 在 host 具备传输包能力时这条回 409（强制先 preview 再 apply），Kotlin 侧还没有 apply 服务，所以走 legacy 导入；等 apply 落地后应改成 409 |
| 3 | `PUT /api/v1/courses/group` | ✅ 走 `TimetableCourseService.updateGroup` |
| 4 | `POST /api/v1/import/spreadsheet` | ✅ 解析器由接线方注入，落盘逐门 `addCourse` |
| 5 | `POST /api/v1/import/merge` | ✅ **照 Dart 只回 409**，不实现合并导入 |
| 6 | `POST /api/v1/import/apply` | ❌ 501：Kotlin 侧没有传输包 diff/应用服务（`pages/transfer` 只有渲染层模型）。这是**唯一还缺的能力**，需要单开一批做 `applyTransferJson` |

### B. 有意的行为差异（不是漏，是有取舍）

| # | 差异 | 理由 / 影响 |
|---|---|---|
| 7 | **每连接只处理一个请求**（响应恒 `Connection: close`） | keep-alive 要完整连接复用状态机（流水线、半关连接）；局域网页面一次加载几个请求，收益远小于风险 |
| 8 | **不支持 `Transfer-Encoding: chunked`** | 明确 400；自己写 chunked 解码器或信对端长度都不划算 |
| 9 | 请求体上限 5 MiB、并发 16、空闲 60 秒 | 与 Dart 数值一致（`_maxRequestBodyBytes` / `_maxConcurrentRequests` / `idleTimeout`） |
| 10 | 四条错误 message 改成等义错误码串 | Dart 用中文（`currentWeek 无效` / `currentWeek 不能超过学期周数 N` / `expression 不能为空` / `ids 不能为空` / `contentBase64 不能为空`），Kotlin 侧按仓库 i18n 纪律不写中文字面量：改成 `current_week_invalid` / `current_week_exceeds_semester_weeks:N` / `expression_required` / `ids_required` / `content_base64_required`。**状态码与 `error` 码不变**，只有 message 文本不同 |
| 11 | `itemName` 缺省空串 | Dart 缺省是本地化的「课程」；它只影响 warning 文案，网页端每次都带 |
| 12 | 周次表达式联动未做 | Dart `courseFromApiJson` / `mergeCoursePatch` 会调 `applyWeekExpressionFields`（`weekExpression` → 周次数组）；本层建/改课只走 `Course.fromJson` 的既有归一化。**后果**：网页端发 `weekExpression` 字段会被忽略 |
| 13 | 对端可控的学期周数未做收敛 | Dart `_safeSemesterWeekCount` 把对端给的 `semesterWeekCount` 收敛到 1..60（防 `List.generate(10^9)` OOM）。本层**不从对端取这个值**（只用 host 自己的），所以该 OOM 面不存在；但第 12 条补上时**必须**一起补这个收敛 |
| 14 | 备份里的 `tasks` / `exams`：**导出带上、导入不写回** | 导出按 Dart 口径带上（信封格式完整）；写回需要 `TimetableCourseService` 上没有的批量入口，留待 Lead 拍板 |
| 15 | 多档案整份恢复不支持 | 见上面「数据层」第 3 点：明确 400，不静默丢档案 |

### C. 只有真机能验

真机上的表现（手机热点下电脑连得上、浏览器页面能不能正常交互、前台服务通知、
息屏后连接是否还在）本泳道**未验**——设备铁律：未经用户明确允许不碰真机。

## 四、验收命令

```bash
# L0：真 socket 往返 + 真仓储端到端（200/400/401/403/404/409/429/431/413、畸形请求行、
#     超长头、超长体、半途断连、空连接、一个连接卡住时另一个照样 200、空闲看门狗、
#     坏备份不落盘、组替换后消失的课真的没了、导出再导入课程真的落盘）
#
# ⚠️ -ExtraSources 必须走 pwsh -Command 的**数组**形式：
#    pwsh -File ... -ExtraSources 'a','b','c' 会被绑成一个含逗号的字符串（报「找不到路径」）。
pwsh -NoProfile -Command "& './scripts/test-kotlin-module.ps1' -Module 'pages/transfer' \
  -ExtraSources 'android/app/src/test/kotlin/com/mutx163/qingyu/transfer/lan/LanEditHttpParseTest.kt',\
'android/app/src/test/kotlin/com/mutx163/qingyu/transfer/lan/LanEditApiRouterTest.kt',\
'android/app/src/test/kotlin/com/mutx163/qingyu/transfer/lan/LanEditHttpServerTest.kt',\
'android/app/src/test/kotlin/com/mutx163/qingyu/transfer/lan/LanEditRepositoryHostTest.kt',\
'android/app/src/test/kotlin/com/mutx163/qingyu/transfer/lan/LanEditRepositoryEndToEndTest.kt'"

# 真 Gradle（L0 绿不算数：`com.sun.*` 那次教训；这条同时编译测试源集）
pwsh -NoProfile -File scripts/safe-gradle.ps1 :app:compileProdDebugUnitTestKotlin
```
