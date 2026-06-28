# 局域网编辑课表（电脑浏览器改手机课表）— 开发方案

## 文档信息

| 项目 | 内容 |
|------|------|
| 功能名称 | 局域网编辑课表 |
| 创建日期 | 2026-06-27 |
| 状态 | 已实现（MVP） |
| 优先级 | P1 |
| 目标场景 | **A. 电脑浏览器改手机课表**（手机开热点 / 连宿舍 WiFi，PC 访问 `http://192.168.x.x:端口`） |

---

## 一、目标与边界

### 1.1 用户故事

> 我在手机上已经导入课表，但想在电脑大屏上批量改课程名、教师、地点、周次。手机和电脑连同一 WiFi（或手机开热点），电脑浏览器打开地址即可编辑，保存后直接写回手机 App，超级岛和小组件自动更新。

### 1.2 MVP 范围（v1）

| 包含 | 不包含（后续） |
|------|----------------|
| 仅编辑 **当前激活课表** | 多课表切换编辑 |
| 课程 **增删改查** | 日程、考试、主题、时间模板 |
| 周视图 **只读预览** + 课程表单编辑 | 完整复刻 App 内 `AddCourseScreen` 全部高级项 |
| 会话 PIN 鉴权 + 手动启停 | mDNS 自动发现、公网穿透 |
| 手机展示 IP / 端口 / PIN / 二维码 | 双手机实时协同编辑 |
| 前台通知保活（编辑会话进行中） | Web 端批量 Excel 粘贴 |

### 1.3 成功标准

1. 电脑 Chrome/Edge 访问手机地址，输入 PIN 后可看到当前课表周视图。
2. 新增/修改/删除一门课后，手机 App 内课表与 PC 刷新后一致。
3. 关闭会话或超时后，外网/其他 WiFi 设备无法继续访问。
4. 单元测试覆盖：鉴权、路由、JSON 读写、Provider 集成（不依赖真实网络）。

---

## 二、总体架构

```
┌──────────────── PC 浏览器 ────────────────┐
│  assets/lan_edit/web/  (静态 HTML+JS)    │
│  周视图网格 + 课程编辑表单                 │
└──────────────────┬──────────────────────┘
                   │ HTTP (同网段)
                   ▼
┌──────────── 手机 App (Flutter) ──────────┐
│  LanEditScreen (开关 / IP / PIN / QR)    │
│       │                                   │
│  LanEditServerService (dart:io HttpServer)│
│       │  REST + 静态资源                   │
│  LanEditSession (token / 过期 / 连接数)   │
│       │                                   │
│  TimetableProvider (已有 CRUD + 持久化)   │
│       │                                   │
│  StorageService + LiveUpdate + Widget     │
└──────────────────────────────────────────┘
```

### 分层职责

| 层 | 文件（建议） | 职责 |
|----|--------------|------|
| UI | `lib/screens/lan_edit_screen.dart` | 启停服务、展示连接信息、复制链接 |
| 会话 | `lib/services/lan_edit_session.dart` | PIN、token、过期、审计 |
| 服务 | `lib/services/lan_edit_server_service.dart` | `HttpServer` 绑定、路由分发 |
| 协议 | `lib/services/lan_edit_api_handlers.dart` | 解析请求、调用 Provider |
| Web | `assets/lan_edit/index.html` + `app.js` + `style.css` | 浏览器端 UI |
| 集成 | `lib/providers/timetable_provider.dart` | 仅新增薄封装，不内嵌 HTTP |

**原则**：HTTP 层不直接操作 `SharedPreferences`；所有写入走 `TimetableProvider`，保证超级岛 / 小组件 / 持久化与 App 内编辑一致。

---

## 三、用户流程

### 3.1 手机端

1. 设置 → **数据备份与迁移** 同区新增入口「局域网编辑」；或独立「局域网编辑」页。
2. 用户点击「开启局域网编辑」→ 生成 6 位 PIN + 随机端口（如 `49152–65535`）。
3. 页面展示：
   - 访问地址：`http://192.168.43.1:52841`（示例，自动检测 IPv4）
   - PIN：`482913`
   - 二维码（可选 v1.1，内容含 `?token=`）
   - 状态：已连接设备数、最近操作时间
4. 显示常驻通知：「局域网编辑已开启，点击返回 App」。
5. 用户点击「停止」或 30 分钟无请求 → 服务关闭、通知消失。

### 3.2 电脑端

1. 连接与手机同一网络（或连手机热点）。
2. 浏览器打开地址 → 登录页输入 PIN（或 URL 已带 `?token=` 则跳过）。
3. 进入编辑页：顶栏显示课表名、当前周；主体为周视图；点击格子/课程弹出侧栏表单。
4. 保存后 toast 提示；手机 App 若在前台可 `notifyListeners` 即时刷新。

### 3.3 失败提示

| 情况 | 提示 |
|------|------|
| 校园网 AP 隔离 | 「无法连接？尝试用手机开热点，电脑连热点后再访问」 |
| 电脑不在同网段 | 「请确认电脑与手机连接同一 WiFi」 |
| PIN 错误 | HTTP 401 + Web 登录页错误文案 |
| 会话已过期 | 「编辑会话已结束，请在手机上重新开启」 |

---

## 四、API 设计

基础路径：`/api/v1`  
鉴权：Header `Authorization: Bearer <sessionToken>`（PIN 验证成功后下发，有效期与会话一致）

### 4.1 会话

| 方法 | 路径 | 说明 |
|------|------|------|
| `POST` | `/api/v1/auth/verify` | Body: `{ "pin": "482913" }` → `{ "token": "...", "expiresAt": "..." }` |
| `GET` | `/api/v1/session` | `{ "profileName", "activeWeek", "semesterWeekCount", "serverTime" }` |

### 4.2 课表快照（复用现有 schema）

| 方法 | 路径 | 说明 |
|------|------|------|
| `GET` | `/api/v1/profile/active` | 等同 `DataTransferService.buildBackupJson` 结构（单课表） |
| `PUT` | `/api/v1/profile/active` | Body 为完整单课表备份 JSON → `parseBackupJson` → 覆盖当前课表课程+设置+周次（**不含**多课表） |

> v1 推荐：**单课 CRUD 为主**，`PUT` 全量作为「导入覆盖」备用（需 Web 二次确认）。

### 4.3 课程 CRUD

| 方法 | 路径 | 说明 |
|------|------|------|
| `GET` | `/api/v1/courses` | 当前课表全部课程 |
| `GET` | `/api/v1/courses/:id` | 单条 |
| `POST` | `/api/v1/courses` | Body: `Course.toJson()`（服务端生成 `id` 若缺失） |
| `PATCH` | `/api/v1/courses/:id` | 部分更新 |
| `DELETE` | `/api/v1/courses/:id` | 删除 |

### 4.4 辅助元数据（供 Web 表单）

| 方法 | 路径 | 说明 |
|------|------|------|
| `GET` | `/api/v1/meta` | `{ sectionCount, sections[], currentWeek, semesterWeekCount, colors[] }` |

### 4.5 静态资源

| 路径 | 说明 |
|------|------|
| `/` | `assets/lan_edit/index.html` |
| `/assets/*` | 同目录 CSS/JS |

### 4.6 错误格式

```json
{ "error": "invalid_pin", "message": "PIN 不正确" }
```

| HTTP | error |
|------|-------|
| 401 | `unauthorized` / `invalid_pin` / `session_expired` |
| 404 | `not_found` |
| 409 | `conflict`（预留乐观锁） |
| 500 | `internal_error` |

---

## 五、Web 端 MVP 界面

### 5.1 页面

1. **login.html**（或 index 内切换）— PIN 输入
2. **editor** — 周视图 + 编辑抽屉

### 5.2 周视图

- 列：周一至周日；行：节次（来自 `meta.sections`）
- 单元格渲染课程块（名称、地点缩写、颜色）
- 点击空白格 → 新建课程（预填星期、节次）
- 点击已有块 → 编辑

### 5.3 课程表单字段（v1）

与 `Course` 模型对齐的最小集：

| 字段 | 必填 |
|------|------|
| name | ✅ |
| teacher | |
| location | |
| dayOfWeek | ✅ |
| startSection / endSection | ✅ |
| startWeek / endWeek | ✅ |
| isOddWeek / isEvenWeek | |
| color | |
| note | |

**v1 不做**：同名课程组批量编辑、`customWeeks` 可视化、`timeSchemeIdOverride`、停课周。

### 5.4 技术选型

- 纯静态 **HTML + CSS + Vanilla JS**（无构建链，打进 `assets/`）
- `fetch` 调 API；不引入 React/Vue，控制体积与维护成本
- 响应式：最小宽度 1024px 优先（电脑），手机浏览器可只读

---

## 六、安全设计

1. **默认关闭**，无后台常驻监听。
2. **随机端口 + PIN**：PIN 6 位数字，会话级 token（UUID）。
3. **仅监听 `InternetAddress.anyIPv4`**，不 UPnP、不穿透 NAT。
4. **会话 TTL**：30 分钟无 API 请求自动停止；单次最长 2 小时硬上限（可配置常量）。
5. **限流**：同 IP 每分钟 PIN 错误 ≤ 5 次。
6. **CORS**：仅允许同源（静态与 API 同服）；不开放跨域。
7. **日志**：写入 `AppLogService`（连接、鉴权失败、写操作摘要，不含 PIN 明文）。
8. **隐私文案**：设置页说明「仅在您开启时，同一 WiFi 下的设备可访问；不会上传云端」。

---

## 七、Android 平台要点

### 7.1 权限与清单

当前已有 `INTERNET`、`ACCESS_WIFI_STATE`、`FOREGROUND_SERVICE`。

**v1 建议新增**：

```xml
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_CONNECTED_DEVICE"/>
<uses-permission android:name="android.permission.CHANGE_WIFI_STATE"/>
```

`LanEditForegroundService`（新建 Kotlin 或复用模式）：

- `foregroundServiceType="connectedDevice"`
- 通知渠道：「局域网编辑」
- 用户点击通知回到 `LanEditScreen`

> 超级岛已占用 `specialUse`；LAN 服务单独一条 FGS，避免类型混用。

### 7.2 IP 获取

```dart
for (final interface in await NetworkInterface.list(
  type: InternetAddressType.IPv4,
  includeLinkLocal: false,
)) {
  // 优先 192.168.x.x / 10.x / 172.16-31
}
```

热点场景下通常为 `192.168.43.x`（Android 默认）。

### 7.3 明文 HTTP

已配置 `usesCleartextTraffic` + `network_security_config` 允许明文；局域网 HTTP 可接受。

### 7.4 进程被杀

用户切到后台仅浏览 Web 时，依赖前台服务保活；若仍被杀，Web 端显示断开，手机 App 恢复后需重新开启会话。

---

## 八、与现有代码的集成点

### 8.1 复用

| 现有模块 | 用法 |
|----------|------|
| `DataTransferService.buildBackupJson` / `parseBackupJson` | 全量读写 |
| `Course.toJson` / `fromJson` | 单条 CRUD |
| `TimetableProvider.addCourse` / `updateCourse` / `deleteCourse` | 写入 |
| `TimetableProvider.settings.sections` | Web 节次轴 |
| `AppLogService` | 审计 |

### 8.2 Provider 补充（建议）

```dart
// 供 LanEdit 在 isolate 外安全调用（已有 mutex 可复用 storage 锁）
Future<Course> lanEditCreateCourse(Course draft);
Future<void> lanEditUpdateCourse(Course course);
Future<void> lanEditDeleteCourse(String id);
AppDataBackup lanEditExportActiveProfile();
Future<void> lanEditImportActiveProfile(AppDataBackup backup);
```

避免 `LanEditServerService` 直接持有 `BuildContext`。

### 8.3 入口

在 `timetable_settings_screen.dart` 数据区增加：

```
数据备份与迁移
局域网编辑          ← 新增
  在电脑浏览器中编辑当前课表
```

---

## 九、文件变更清单

| 操作 | 路径 | 说明 |
|------|------|------|
| **新增** | `lib/services/lan_edit_session.dart` | 会话/PIN/token |
| **新增** | `lib/services/lan_edit_server_service.dart` | HttpServer |
| **新增** | `lib/services/lan_edit_api_handlers.dart` | 路由表 |
| **新增** | `lib/screens/lan_edit_screen.dart` | 手机端 UI |
| **新增** | `assets/lan_edit/index.html` | Web 入口 |
| **新增** | `assets/lan_edit/app.js` | Web 逻辑 |
| **新增** | `assets/lan_edit/style.css` | Web 样式 |
| **新增** | `android/.../LanEditForegroundService.kt` | 前台保活 |
| **修改** | `lib/providers/timetable_provider.dart` | LanEdit 写接口 |
| **修改** | `lib/screens/timetable_settings_screen.dart` | 入口 |
| **修改** | `pubspec.yaml` | 声明 `assets/lan_edit/` |
| **修改** | `android/app/src/main/AndroidManifest.xml` | FGS + 权限 |
| **修改** | `lib/l10n/app_zh.arb` 等 | 文案 |
| **新增** | `test/services/lan_edit_server_service_test.dart` | 单元测试 |
| **新增** | `test/services/lan_edit_api_handlers_test.dart` | API 测试 |

---

## 十、实现步骤

### Phase 1：服务骨架（2 天）

1. `LanEditSession`：生成 PIN/token、过期判断
2. `LanEditServerService`：`HttpServer.bind(ANY_IPV4, 0)`，健康检查 `GET /api/v1/health`
3. `LanEditScreen`：显示 IP/端口/PIN，启停按钮
4. 单元测试：绑定 loopback、鉴权失败/成功

### Phase 2：API + Provider（2 天）

5. 实现 `GET/POST/PATCH/DELETE /api/v1/courses*`
6. `GET /api/v1/meta`、`GET /api/v1/profile/active`
7. Provider 薄封装 + 写后 `notifyListeners`、`_updateLiveActivity`
8. API handler 测试（mock Provider）

### Phase 3：Web 编辑页（3 天）

9. 静态登录页 + token 存 `sessionStorage`
10. 周视图渲染 + 课程抽屉表单
11. 联调：真机热点 + PC 浏览器

### Phase 4：Android 保活与打磨（1–2 天）

12. `LanEditForegroundService` + 通知
13. 超时自动停止、错误文案、设置页说明
14. 国际化、AppLog、关于页补充一句能力说明

### Phase 5：收尾（1 天）

15. 手动测试矩阵（热点 / 宿舍 WiFi / AP 隔离）
16. release note
17. 更新本方案状态为「已实现」

**合计：约 9–10 人天**

---

## 十一、测试用例

### 11.1 单元测试

- PIN 正确/错误/过期
- 未带 token 访问 API → 401
- POST 课程后 GET 列表包含新课程
- DELETE 后 Provider 持久化（mock SharedPreferences）
- 会话空闲 30min 后 `isActive == false`

### 11.2 手动测试

| # | 步骤 | 期望 |
|---|------|------|
| 1 | 手机开热点，电脑连接，访问 IP:端口 | 出现登录页 |
| 2 | 输入错误 PIN 5 次 | 限流提示 |
| 3 | 正确 PIN，新增课程 | 手机 App 可见 |
| 4 | Web 修改课程地点 | 超级岛下次刷新用新地点 |
| 5 | 手机点停止服务 | Web 后续请求失败 |
| 6 | 校园网 AP 隔离 | 提示换热点 |

---

## 十二、风险与对策

| 风险 | 对策 |
|------|------|
| WiFi AP 隔离 | 文档 + UI 引导用手机热点 |
| 前台服务被系统杀 | 通知 + 会话可恢复（重开即可） |
| Web 与 App 字段不一致 | v1 限制字段集；schema 版本号 |
| 全量 PUT 误覆盖 | 默认隐藏，需勾选确认 |
| 同名课程组逻辑复杂 | v1 按单条 `Course` 编辑，不暴露组操作 |
| targetSdk 升高本地网络权限 | 预留 `ACCESS_LOCAL_NETWORK` 调研项 |

---

## 十三、后续演进（非 MVP）

- 二维码一键打开（`qr_flutter`）
- mDNS 服务名 `mikcb-lan.local`（`multicast_dns`）
- 日程 / 考试编辑
- Web 端周次切换、批量删除
- 乐观锁 `profileRevision` 防双端覆盖
- 可选 HTTPS 自签证书（一般 LAN 不必）

---

## 十四、与备份迁移的关系

| | 备份迁移 | 局域网编辑 |
|--|----------|------------|
| 协议 | `.mikcb` JSON v1 | 同一 JSON 结构 + REST |
| 场景 | 换机、发文件 | 同网电脑实时改 |
| 入口 | 数据备份与迁移 | 局域网编辑（建议相邻） |

两者共用 `DataTransferService` 可减少协议分叉。

---

## 十五、实现备注（MVP 收尾）

### Android FGS

- `LanEditForegroundService` 使用 `foregroundServiceType="connectedDevice"`（与超级岛 `specialUse` 分离）。
- 权限：`FOREGROUND_SERVICE_CONNECTED_DEVICE`；启停经 `LanEditForegroundBridge`（MethodChannel）由 Dart 侧 `LanEditServerService` 调用。

### AppLog 审计类别

经 `lan_edit_audit_log.dart` → `AppLogService`，**不含 PIN/token 明文**：

| category | 触发 |
|----------|------|
| `lan_edit_session_started` | 服务绑定成功 |
| `lan_edit_session_stopped` | 手动停止或 idle 超时 |
| `lan_edit_auth_failed` | 过期 / 限流 / PIN 错误 / token 缺失或无效（extras 仅 `reason` + `clientIp`） |
| `lan_edit_course_created` | POST 课程 |
| `lan_edit_course_updated` | PATCH 课程 |
| `lan_edit_course_deleted` | DELETE 课程 |

### 本地构建

若本机设置了 TUNA 镜像环境变量，`flutter build`/`run` 可能因 `flutter_infra_release` 404 失败；见 [BUILD_TROUBLESHOOTING.md](../BUILD_TROUBLESHOOTING.md)「TUNA 镜像 404」节。CI/验证前建议 `Remove-Item Env:FLUTTER_STORAGE_BASE_URL` 与 `PUB_HOSTED_URL`。

---

## 十六、实现进展（2026-06-27）

### 状态

- MVP 已完成；单元测试 **8/8** 通过
- 变更尚未提交；真机热点 + PC 浏览器 **E2E 待验证**

### Web UI v1.1

- 周次导航（`meta.currentWeek` / `semesterWeekCount`）
- 跨节 `rowspan` 合并显示
- 侧栏课程搜索
- Toast 反馈、保存/加载态
- 表单字段：`courseNature`、`shortName`
- 复制课程（duplicate）
- 顶栏 session badge（课表名 / 当前周）
- 快捷键：`Esc` 关闭侧栏，`Ctrl+S` 保存

### Android FGS 踩坑

- **Android 16+**：`foregroundServiceType="connectedDevice"` 除 `FOREGROUND_SERVICE_CONNECTED_DEVICE` 外，还须声明 **`CHANGE_NETWORK_STATE`**，否则 `startForeground` 抛 `SecurityException`（堆栈在 `adb logcat -b crash`，不在 Dart 控制台）

### API / 数据

- `courseFromApiJson`（Web `app.js`）已解析 `courseNature`，与 `Course.toJson` 对齐
