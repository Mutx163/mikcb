# 轻屿课表

![Flutter](https://img.shields.io/badge/Flutter-3.44.8-02569B?logo=flutter&logoColor=white)
![Android](https://img.shields.io/badge/Android-Only-34A853?logo=android&logoColor=white)
![HyperOS](https://img.shields.io/badge/Focus-HyperOS%20%E8%B6%85%E7%BA%A7%E5%B2%9B-FF6A00)
![Release](https://img.shields.io/github/v/release/Mutx163/mikcb?display_name=tag)
![CI](https://img.shields.io/github/actions/workflow/status/Mutx163/mikcb/ci.yml?branch=main&label=CI)

<p align="center">
  <img src="https://163366.xyz/app-icon.png" width="96" alt="轻屿课表">
</p>

一个面向校园场景的 Android 课表应用，优先适配小米 / HyperOS。

官网：<https://163366.xyz> · [使用文档](https://docs.163366.xyz/docs/) · [下载](https://github.com/Mutx163/mikcb/releases) · [更新日志](https://github.com/Mutx163/mikcb/releases)

课表本身不难做，难的是那几个每天都要回答的问题：还有多久上课、这节上到哪了、下一节在哪、不打开应用能不能知道。轻屿课表把课表、分阶段提醒、通知、桌面小组件和 HyperOS 超级岛接在一起，围绕这几件事做。应用截图见[官网](https://163366.xyz)。

## 功能

### 课表与课程

- 周视图左右滑切周、一键回本周；日视图聚焦当天安排
- 课程增删改查，可填简称、颜色、单双周、备注等
- 多套课表独立保存、快速切换，提醒与超级岛跟随当前课表
- 情侣课表：导入 TA 的课表后合并显示，同时段同名课合为「一起课」，桌面小组件也能显示
- 时间模板：按自己学校的作息定义节次；周视图长按空白格可直接加课（可关）
- 教务系统网页登录导入、`.ics` 导入与导出、完整备份导出与恢复
- 二维码面对面传输（喷泉码多帧，不依赖网络）

### 提醒与系统联动

- 上课前 / 课中 / 下课前分阶段提醒
- 上课闹钟：走系统时钟应用，按真实课表批量添加（适合早八）
- HyperOS / 小米超级岛、通知栏、焦点通知联动；超级岛展开的每一行可单独显隐与排序
- 今日桌面小组件、课程统计 2×2 / 2×4 小组件，与课程快照同步
- 应用内检测更新，选好渠道后直接下载安装

### 外观与个性化

- 玻璃四档：实体卡片 / 高斯模糊 / 柔光玻璃 / 液态玻璃
- 首页顶栏玻璃独立选材质（渐进磨砂 / 高斯磨砂 / 柔光 / 液态 / 实体），另有「质感方案」一键套用整套搭配
- 壁纸用自己选的图片，可拖动调整显示位置；「最近使用」保留最近 10 张，切换课表不会跟着变
- 应用形态：经典形态 / 玻璃坞（液态玻璃底部导航）
- 课程统计：学期 / 周双视图、趋势、热力图、教师与教室排行、多课表对比
- 界面语言：简体中文、繁体中文（台湾 / 香港）、English、日本語、한국어

## 下载与更新

| 渠道 | 用途 |
|------|------|
| [GitHub Releases](https://github.com/Mutx163/mikcb/releases) | 正式版与预发布版 |
| [GitCode](https://gitcode.com/mutx/qingyu) | 国内下载（`mutx/qingyu`） |
| [蒲公英](https://www.pgyer.com/qingyu) | 测试分发 |

正式包当前以 `arm64-v8a` 为主。应用内可切换更新源，检测到新版本后直接下载安装。
发行流程见 [docs/RELEASE.md](./docs/RELEASE.md)。

## 教务导入与适配

- 已经支持一部分学校的教务系统网页登录导入，适配脚本来自 `qingyu_warehouse`
- 学校暂时没适配也不影响使用：可以先走 `.ics` 导入或完整备份迁移
- 教务适配仓库：<https://github.com/Mutx163/qingyu_warehouse>
- 如果你会网页调试、抓包、JavaScript，或者愿意维护自己学校的教务系统，欢迎直接参与适配补充

## 开发者

### 环境版本

版本真源：[`.fvmrc`](./.fvmrc) 与 GitHub Actions。当前稳定版为 **Flutter 3.44.8**，最低支持 **Flutter 3.44.2 / Dart 3.12.2**。

| 工具 | 版本 |
|------|------|
| Flutter（当前稳定） | 3.44.8 |
| Flutter（最低支持） | 3.44.2 |
| Dart SDK | >=3.12.2 <4.0.0 |
| JDK | 17 |
| Android SDK | compileSdk 36 / targetSdk 36 / minSdk 26 |
| Android NDK | 28.2.13676358 |
| Gradle | 8.14 |
| Android Gradle Plugin | 8.11.1 |
| Kotlin | 2.2.20 |

### 本地开发

```bash
flutter pub get
flutter run -d android --flavor dev
```

### 质量检查

```bash
flutter test
flutter analyze --no-fatal-infos
```

### 发布构建

```bash
flutter build apk --release --flavor prod --target-platform android-arm64
```

### 命名说明

| 名称 | 说明 |
|------|------|
| 仓库 `mikcb` | GitHub 仓库名 |
| Dart 包 `university_timetable` | 历史包名（pubspec），与仓库名不同 |
| Android 包名 `com.mutx163.qingyu` | 应用 ID |
| 产品名「轻屿课表」 | 用户可见名称 |

## 相关文档

- 贡献指南：[CONTRIBUTING.md](./CONTRIBUTING.md)
- 行为准则：[CODE_OF_CONDUCT.md](./CODE_OF_CONDUCT.md)
- 安全报告：[SECURITY.md](./SECURITY.md)
- 隐私说明：[docs/PRIVACY.md](./docs/PRIVACY.md)
- 第三方许可：[docs/THIRD_PARTY_LICENSES.md](./docs/THIRD_PARTY_LICENSES.md)
- 产品说明（存档）：[docs/PRODUCT.md](./docs/PRODUCT.md)
- 发布流程：[docs/RELEASE.md](./docs/RELEASE.md)
- 网站与国际化协作约定：[docs/WEB_AND_L10N_WORKFLOW.md](./docs/WEB_AND_L10N_WORKFLOW.md)
- 变更日志：[GitHub Releases](https://github.com/Mutx163/mikcb/releases) / [docs/releases/](./docs/releases/)

## 技术栈

- Flutter
- Provider
- SharedPreferences
- 自研液态玻璃材质（Fragment Shader，Impeller）
- fl_chart（统计图表）
- flutter_miuix（HyperOS 风格组件）
- mobile_scanner / fountain_codes（二维码传输）
- Android Notification / Foreground Service / AlarmClock
- GitHub Actions
- GitHub Releases
- 友盟移动统计 / U-APM

## 使用建议

如果你主要用超级岛或实时通知，建议在系统里同时打开这些能力：

- 通知权限
- 自启动
- 电池无限制
- 焦点通知 / promoted ongoing 权限

这些说明已经放进应用内的「使用引导与权限」页面。

## 当前状态

近期主要在做：玻璃与壁纸的稳定性（进场闪变、静止时的性能开销）、首页菜单与弹层的交互细节、桌面小组件配色，以及发版与官网数据同步的自动化。

## 贡献者

感谢每一位让轻屿课表变得更好的人。

<a href="https://github.com/Mutx163/mikcb/graphs/contributors">
  <img src="https://contrib.rocks/image?repo=Mutx163/mikcb" alt="轻屿课表贡献者" />
</a>

### 教务适配贡献者

教务适配脚本来自 [qingyu_warehouse](https://github.com/Mutx163/qingyu_warehouse)，其主体持续从上游 [shiguang_warehouse](https://github.com/XingHeYuZhuan/shiguang_warehouse) 同步——绝大多数学校适配在它那边完成，感谢这些贡献者：

<!-- CONTRIBUTORS:AUTO:START -->
<a href="https://github.com/XingHeYuZhuan"><img src="https://github.com/XingHeYuZhuan.png?size=64" width="64" alt="@XingHeYuZhuan" title="@XingHeYuZhuan" /></a>
<a href="https://github.com/HaoZai000"><img src="https://github.com/HaoZai000.png?size=64" width="64" alt="@HaoZai000" title="@HaoZai000" /></a>
<a href="https://github.com/dezige131"><img src="https://github.com/dezige131.png?size=64" width="64" alt="@dezige131" title="@dezige131" /></a>
<a href="https://github.com/Xuan-Xuann"><img src="https://github.com/Xuan-Xuann.png?size=64" width="64" alt="@Xuan-Xuann" title="@Xuan-Xuann" /></a>
<a href="https://github.com/Jursin"><img src="https://github.com/Jursin.png?size=64" width="64" alt="@Jursin" title="@Jursin" /></a>
<a href="https://github.com/glxgo"><img src="https://github.com/glxgo.png?size=64" width="64" alt="@glxgo" title="@glxgo" /></a>
<a href="https://github.com/Vera-zero"><img src="https://github.com/Vera-zero.png?size=64" width="64" alt="@Vera-zero" title="@Vera-zero" /></a>
<a href="https://github.com/Mercury000"><img src="https://github.com/Mercury000.png?size=64" width="64" alt="@Mercury000" title="@Mercury000" /></a>
<a href="https://github.com/xiaomanjun233"><img src="https://github.com/xiaomanjun233.png?size=64" width="64" alt="@xiaomanjun233" title="@xiaomanjun233" /></a>
<a href="https://github.com/jinnianliuxing"><img src="https://github.com/jinnianliuxing.png?size=64" width="64" alt="@jinnianliuxing" title="@jinnianliuxing" /></a>
<a href="https://github.com/forer-lika777"><img src="https://github.com/forer-lika777.png?size=64" width="64" alt="@forer-lika777" title="@forer-lika777" /></a>
<a href="https://github.com/xhhli06"><img src="https://github.com/xhhli06.png?size=64" width="64" alt="@xhhli06" title="@xhhli06" /></a>
<a href="https://github.com/wlzx1"><img src="https://github.com/wlzx1.png?size=64" width="64" alt="@wlzx1" title="@wlzx1" /></a>
<a href="https://github.com/sLingli"><img src="https://github.com/sLingli.png?size=64" width="64" alt="@sLingli" title="@sLingli" /></a>
<a href="https://github.com/gongfuture"><img src="https://github.com/gongfuture.png?size=64" width="64" alt="@gongfuture" title="@gongfuture" /></a>
<a href="https://github.com/wykwey"><img src="https://github.com/wykwey.png?size=64" width="64" alt="@wykwey" title="@wykwey" /></a>
<a href="https://github.com/Selffox"><img src="https://github.com/Selffox.png?size=64" width="64" alt="@Selffox" title="@Selffox" /></a>
<a href="https://github.com/axelpln"><img src="https://github.com/axelpln.png?size=64" width="64" alt="@axelpln" title="@axelpln" /></a>
<a href="https://github.com/linlinli000"><img src="https://github.com/linlinli000.png?size=64" width="64" alt="@linlinli000" title="@linlinli000" /></a>
<a href="https://github.com/larryyan"><img src="https://github.com/larryyan.png?size=64" width="64" alt="@larryyan" title="@larryyan" /></a>
<a href="https://github.com/Daoguan-king"><img src="https://github.com/Daoguan-king.png?size=64" width="64" alt="@Daoguan-king" title="@Daoguan-king" /></a>
<a href="https://github.com/qq3327008209"><img src="https://github.com/qq3327008209.png?size=64" width="64" alt="@qq3327008209" title="@qq3327008209" /></a>
<a href="https://github.com/aryunm"><img src="https://github.com/aryunm.png?size=64" width="64" alt="@aryunm" title="@aryunm" /></a>
<a href="https://github.com/WindDrift"><img src="https://github.com/WindDrift.png?size=64" width="64" alt="@WindDrift" title="@WindDrift" /></a>
<a href="https://github.com/LucasAndrew0120"><img src="https://github.com/LucasAndrew0120.png?size=64" width="64" alt="@LucasAndrew0120" title="@LucasAndrew0120" /></a>
<a href="https://github.com/Kredenk"><img src="https://github.com/Kredenk.png?size=64" width="64" alt="@Kredenk" title="@Kredenk" /></a>
<a href="https://github.com/Yihe-ng"><img src="https://github.com/Yihe-ng.png?size=64" width="64" alt="@Yihe-ng" title="@Yihe-ng" /></a>
<a href="https://github.com/White-Dew-Boy"><img src="https://github.com/White-Dew-Boy.png?size=64" width="64" alt="@White-Dew-Boy" title="@White-Dew-Boy" /></a>
<a href="https://github.com/Cure2004"><img src="https://github.com/Cure2004.png?size=64" width="64" alt="@Cure2004" title="@Cure2004" /></a>
<a href="https://github.com/wuko233"><img src="https://github.com/wuko233.png?size=64" width="64" alt="@wuko233" title="@wuko233" /></a>
<a href="https://github.com/moyu-by"><img src="https://github.com/moyu-by.png?size=64" width="64" alt="@moyu-by" title="@moyu-by" /></a>
<a href="https://github.com/BernardYan2357"><img src="https://github.com/BernardYan2357.png?size=64" width="64" alt="@BernardYan2357" title="@BernardYan2357" /></a>
<a href="https://github.com/lhgr"><img src="https://github.com/lhgr.png?size=64" width="64" alt="@lhgr" title="@lhgr" /></a>
<a href="https://github.com/chenran0408"><img src="https://github.com/chenran0408.png?size=64" width="64" alt="@chenran0408" title="@chenran0408" /></a>
<a href="https://github.com/zknb-666"><img src="https://github.com/zknb-666.png?size=64" width="64" alt="@zknb-666" title="@zknb-666" /></a>
<a href="https://github.com/salt-fishes"><img src="https://github.com/salt-fishes.png?size=64" width="64" alt="@salt-fishes" title="@salt-fishes" /></a>
<a href="https://github.com/xiaobai12354567"><img src="https://github.com/xiaobai12354567.png?size=64" width="64" alt="@xiaobai12354567" title="@xiaobai12354567" /></a>
<a href="https://github.com/kemi-20"><img src="https://github.com/kemi-20.png?size=64" width="64" alt="@kemi-20" title="@kemi-20" /></a>
<a href="https://github.com/yukoimi"><img src="https://github.com/yukoimi.png?size=64" width="64" alt="@yukoimi" title="@yukoimi" /></a>
<a href="https://github.com/J-X-C-Z"><img src="https://github.com/J-X-C-Z.png?size=64" width="64" alt="@J-X-C-Z" title="@J-X-C-Z" /></a>
<a href="https://github.com/Mccurtain"><img src="https://github.com/Mccurtain.png?size=64" width="64" alt="@Mccurtain" title="@Mccurtain" /></a>
<a href="https://github.com/Shallow-Y"><img src="https://github.com/Shallow-Y.png?size=64" width="64" alt="@Shallow-Y" title="@Shallow-Y" /></a>
<a href="https://github.com/Mutx666"><img src="https://github.com/Mutx666.png?size=64" width="64" alt="@Mutx666" title="@Mutx666" /></a>
<a href="https://github.com/yvmu"><img src="https://github.com/yvmu.png?size=64" width="64" alt="@yvmu" title="@yvmu" /></a>
<a href="https://github.com/lixu-030506"><img src="https://github.com/lixu-030506.png?size=64" width="64" alt="@lixu-030506" title="@lixu-030506" /></a>
<a href="https://github.com/zt11125"><img src="https://github.com/zt11125.png?size=64" width="64" alt="@zt11125" title="@zt11125" /></a>
<a href="https://github.com/zengzoxiong"><img src="https://github.com/zengzoxiong.png?size=64" width="64" alt="@zengzoxiong" title="@zengzoxiong" /></a>
<a href="https://github.com/yuexps"><img src="https://github.com/yuexps.png?size=64" width="64" alt="@yuexps" title="@yuexps" /></a>
<a href="https://github.com/wild0408"><img src="https://github.com/wild0408.png?size=64" width="64" alt="@wild0408" title="@wild0408" /></a>
<a href="https://github.com/Weedy233"><img src="https://github.com/Weedy233.png?size=64" width="64" alt="@Weedy233" title="@Weedy233" /></a>
<a href="https://github.com/ca1q1an"><img src="https://github.com/ca1q1an.png?size=64" width="64" alt="@ca1q1an" title="@ca1q1an" /></a>
<a href="https://github.com/739C1AE2"><img src="https://github.com/739C1AE2.png?size=64" width="64" alt="@739C1AE2" title="@739C1AE2" /></a>
<a href="https://github.com/TiaoFeng"><img src="https://github.com/TiaoFeng.png?size=64" width="64" alt="@TiaoFeng" title="@TiaoFeng" /></a>
<a href="https://github.com/igugyj"><img src="https://github.com/igugyj.png?size=64" width="64" alt="@igugyj" title="@igugyj" /></a>
<a href="https://github.com/dong-dong6"><img src="https://github.com/dong-dong6.png?size=64" width="64" alt="@dong-dong6" title="@dong-dong6" /></a>
<a href="https://github.com/Corundum-Ling"><img src="https://github.com/Corundum-Ling.png?size=64" width="64" alt="@Corundum-Ling" title="@Corundum-Ling" /></a>
<a href="https://github.com/yalerove"><img src="https://github.com/yalerove.png?size=64" width="64" alt="@yalerove" title="@yalerove" /></a>
<a href="https://github.com/Foraes"><img src="https://github.com/Foraes.png?size=64" width="64" alt="@Foraes" title="@Foraes" /></a>
<a href="https://github.com/HJWqa"><img src="https://github.com/HJWqa.png?size=64" width="64" alt="@HJWqa" title="@HJWqa" /></a>
<a href="https://github.com/lc6464"><img src="https://github.com/lc6464.png?size=64" width="64" alt="@lc6464" title="@lc6464" /></a>
<a href="https://github.com/LiquoriceHy"><img src="https://github.com/LiquoriceHy.png?size=64" width="64" alt="@LiquoriceHy" title="@LiquoriceHy" /></a>
<a href="https://github.com/xsddszrc"><img src="https://github.com/xsddszrc.png?size=64" width="64" alt="@xsddszrc" title="@xsddszrc" /></a>
<a href="https://github.com/Guzheng3"><img src="https://github.com/Guzheng3.png?size=64" width="64" alt="@Guzheng3" title="@Guzheng3" /></a>
<a href="https://github.com/JellyfisHawthorn"><img src="https://github.com/JellyfisHawthorn.png?size=64" width="64" alt="@JellyfisHawthorn" title="@JellyfisHawthorn" /></a>
<a href="https://github.com/JiaLiFuNia"><img src="https://github.com/JiaLiFuNia.png?size=64" width="64" alt="@JiaLiFuNia" title="@JiaLiFuNia" /></a>
<a href="https://github.com/CialloM"><img src="https://github.com/CialloM.png?size=64" width="64" alt="@CialloM" title="@CialloM" /></a>
<a href="https://github.com/Leimeng52mc"><img src="https://github.com/Leimeng52mc.png?size=64" width="64" alt="@Leimeng52mc" title="@Leimeng52mc" /></a>
<a href="https://github.com/Linho1219"><img src="https://github.com/Linho1219.png?size=64" width="64" alt="@Linho1219" title="@Linho1219" /></a>
<a href="https://github.com/moondish"><img src="https://github.com/moondish.png?size=64" width="64" alt="@moondish" title="@moondish" /></a>
<a href="https://github.com/qwwshs"><img src="https://github.com/qwwshs.png?size=64" width="64" alt="@qwwshs" title="@qwwshs" /></a>
<a href="https://github.com/b1n23"><img src="https://github.com/b1n23.png?size=64" width="64" alt="@b1n23" title="@b1n23" /></a>
<a href="https://github.com/abyss-stars"><img src="https://github.com/abyss-stars.png?size=64" width="64" alt="@abyss-stars" title="@abyss-stars" /></a>
<a href="https://github.com/Zellon0w0"><img src="https://github.com/Zellon0w0.png?size=64" width="64" alt="@Zellon0w0" title="@Zellon0w0" /></a>
<a href="https://github.com/ying-ck"><img src="https://github.com/ying-ck.png?size=64" width="64" alt="@ying-ck" title="@ying-ck" /></a>
<a href="https://github.com/LilyCarry"><img src="https://github.com/LilyCarry.png?size=64" width="64" alt="@LilyCarry" title="@LilyCarry" /></a>
<a href="https://github.com/Panda35064"><img src="https://github.com/Panda35064.png?size=64" width="64" alt="@Panda35064" title="@Panda35064" /></a>
<a href="https://github.com/ReGoMark"><img src="https://github.com/ReGoMark.png?size=64" width="64" alt="@ReGoMark" title="@ReGoMark" /></a>
<a href="https://github.com/superman32432432"><img src="https://github.com/superman32432432.png?size=64" width="64" alt="@superman32432432" title="@superman32432432" /></a>
<a href="https://github.com/localhosts-A"><img src="https://github.com/localhosts-A.png?size=64" width="64" alt="@localhosts-A" title="@localhosts-A" /></a>
<a href="https://github.com/llingqing"><img src="https://github.com/llingqing.png?size=64" width="64" alt="@llingqing" title="@llingqing" /></a>
<a href="https://github.com/kncatl"><img src="https://github.com/kncatl.png?size=64" width="64" alt="@kncatl" title="@kncatl" /></a>
<a href="https://github.com/jesse-s4"><img src="https://github.com/jesse-s4.png?size=64" width="64" alt="@jesse-s4" title="@jesse-s4" /></a>
<a href="https://github.com/hydrofluoric07"><img src="https://github.com/hydrofluoric07.png?size=64" width="64" alt="@hydrofluoric07" title="@hydrofluoric07" /></a>
<a href="https://github.com/NoobLLiu"><img src="https://github.com/NoobLLiu.png?size=64" width="64" alt="@NoobLLiu" title="@NoobLLiu" /></a>
<a href="https://github.com/YewFence"><img src="https://github.com/YewFence.png?size=64" width="64" alt="@YewFence" title="@YewFence" /></a>
<a href="https://github.com/haha12358"><img src="https://github.com/haha12358.png?size=64" width="64" alt="@haha12358" title="@haha12358" /></a>
<a href="https://github.com/ewiro"><img src="https://github.com/ewiro.png?size=64" width="64" alt="@ewiro" title="@ewiro" /></a>
<a href="https://github.com/zixij644-elaborate"><img src="https://github.com/zixij644-elaborate.png?size=64" width="64" alt="@zixij644-elaborate" title="@zixij644-elaborate" /></a>
<a href="https://github.com/dffzcqs78694"><img src="https://github.com/dffzcqs78694.png?size=64" width="64" alt="@dffzcqs78694" title="@dffzcqs78694" /></a>
<a href="https://github.com/cstkn"><img src="https://github.com/cstkn.png?size=64" width="64" alt="@cstkn" title="@cstkn" /></a>
<a href="https://github.com/Yumu-banxia"><img src="https://github.com/Yumu-banxia.png?size=64" width="64" alt="@Yumu-banxia" title="@Yumu-banxia" /></a>
<a href="https://github.com/co1ton7427Official"><img src="https://github.com/co1ton7427Official.png?size=64" width="64" alt="@co1ton7427Official" title="@co1ton7427Official" /></a>
<a href="https://github.com/cdcdccd"><img src="https://github.com/cdcdccd.png?size=64" width="64" alt="@cdcdccd" title="@cdcdccd" /></a>
<a href="https://github.com/wwwhyDB"><img src="https://github.com/wwwhyDB.png?size=64" width="64" alt="@wwwhyDB" title="@wwwhyDB" /></a>
<a href="https://github.com/lztttt"><img src="https://github.com/lztttt.png?size=64" width="64" alt="@lztttt" title="@lztttt" /></a>
<a href="https://github.com/oneepointer"><img src="https://github.com/oneepointer.png?size=64" width="64" alt="@oneepointer" title="@oneepointer" /></a>
<a href="https://github.com/penguinway"><img src="https://github.com/penguinway.png?size=64" width="64" alt="@penguinway" title="@penguinway" /></a>
<a href="https://github.com/platinumyrh"><img src="https://github.com/platinumyrh.png?size=64" width="64" alt="@platinumyrh" title="@platinumyrh" /></a>
<a href="https://github.com/psenY"><img src="https://github.com/psenY.png?size=64" width="64" alt="@psenY" title="@psenY" /></a>
<a href="https://github.com/qizeyunyu-ai"><img src="https://github.com/qizeyunyu-ai.png?size=64" width="64" alt="@qizeyunyu-ai" title="@qizeyunyu-ai" /></a>
<a href="https://github.com/suiren0219"><img src="https://github.com/suiren0219.png?size=64" width="64" alt="@suiren0219" title="@suiren0219" /></a>
<a href="https://github.com/weiwei221206"><img src="https://github.com/weiwei221206.png?size=64" width="64" alt="@weiwei221206" title="@weiwei221206" /></a>
<a href="https://github.com/xBefore"><img src="https://github.com/xBefore.png?size=64" width="64" alt="@xBefore" title="@xBefore" /></a>
<a href="https://github.com/xiekeqing"><img src="https://github.com/xiekeqing.png?size=64" width="64" alt="@xiekeqing" title="@xiekeqing" /></a>
<a href="https://github.com/yang01-droid"><img src="https://github.com/yang01-droid.png?size=64" width="64" alt="@yang01-droid" title="@yang01-droid" /></a>
<a href="https://github.com/lose2me"><img src="https://github.com/lose2me.png?size=64" width="64" alt="@lose2me" title="@lose2me" /></a>
<a href="https://github.com/yisibuwang"><img src="https://github.com/yisibuwang.png?size=64" width="64" alt="@yisibuwang" title="@yisibuwang" /></a>
<a href="https://github.com/yusancky"><img src="https://github.com/yusancky.png?size=64" width="64" alt="@yusancky" title="@yusancky" /></a>
<a href="https://github.com/INFO-studio"><img src="https://github.com/INFO-studio.png?size=64" width="64" alt="@INFO-studio" title="@INFO-studio" /></a>
<a href="https://github.com/sdpd2333"><img src="https://github.com/sdpd2333.png?size=64" width="64" alt="@sdpd2333" title="@sdpd2333" /></a>
<a href="https://github.com/Kurisu90"><img src="https://github.com/Kurisu90.png?size=64" width="64" alt="@Kurisu90" title="@Kurisu90" /></a>
<a href="https://github.com/Hui0069"><img src="https://github.com/Hui0069.png?size=64" width="64" alt="@Hui0069" title="@Hui0069" /></a>
<a href="https://github.com/Hollow468"><img src="https://github.com/Hollow468.png?size=64" width="64" alt="@Hollow468" title="@Hollow468" /></a>
<a href="https://github.com/haooz"><img src="https://github.com/haooz.png?size=64" width="64" alt="@haooz" title="@haooz" /></a>
<a href="https://github.com/FaQxD233"><img src="https://github.com/FaQxD233.png?size=64" width="64" alt="@FaQxD233" title="@FaQxD233" /></a>
<a href="https://github.com/Enthusjast"><img src="https://github.com/Enthusjast.png?size=64" width="64" alt="@Enthusjast" title="@Enthusjast" /></a>
<a href="https://github.com/REnss3536"><img src="https://github.com/REnss3536.png?size=64" width="64" alt="@REnss3536" title="@REnss3536" /></a>
<a href="https://github.com/EnderHCO3"><img src="https://github.com/EnderHCO3.png?size=64" width="64" alt="@EnderHCO3" title="@EnderHCO3" /></a>
<a href="https://github.com/EarOfWheat"><img src="https://github.com/EarOfWheat.png?size=64" width="64" alt="@EarOfWheat" title="@EarOfWheat" /></a>
<a href="https://github.com/E7G"><img src="https://github.com/E7G.png?size=64" width="64" alt="@E7G" title="@E7G" /></a>
<a href="https://github.com/Chr0n0stasis"><img src="https://github.com/Chr0n0stasis.png?size=64" width="64" alt="@Chr0n0stasis" title="@Chr0n0stasis" /></a>
<a href="https://github.com/Candle152"><img src="https://github.com/Candle152.png?size=64" width="64" alt="@Candle152" title="@Candle152" /></a>
<a href="https://github.com/CagierAsh123"><img src="https://github.com/CagierAsh123.png?size=64" width="64" alt="@CagierAsh123" title="@CagierAsh123" /></a>
<a href="https://github.com/chu8877d3"><img src="https://github.com/chu8877d3.png?size=64" width="64" alt="@chu8877d3" title="@chu8877d3" /></a>
<a href="https://github.com/Alph4rc"><img src="https://github.com/Alph4rc.png?size=64" width="64" alt="@Alph4rc" title="@Alph4rc" /></a>
<a href="https://github.com/airline233"><img src="https://github.com/airline233.png?size=64" width="64" alt="@airline233" title="@airline233" /></a>
<a href="https://github.com/ARK-VALLEY"><img src="https://github.com/ARK-VALLEY.png?size=64" width="64" alt="@ARK-VALLEY" title="@ARK-VALLEY" /></a>
<a href="https://github.com/OT-WuLong"><img src="https://github.com/OT-WuLong.png?size=64" width="64" alt="@OT-WuLong" title="@OT-WuLong" /></a>
<a href="https://github.com/wang1wang1"><img src="https://github.com/wang1wang1.png?size=64" width="64" alt="@wang1wang1" title="@wang1wang1" /></a>
<a href="https://github.com/dclindev"><img src="https://github.com/dclindev.png?size=64" width="64" alt="@dclindev" title="@dclindev" /></a>
<a href="https://github.com/UVhyx"><img src="https://github.com/UVhyx.png?size=64" width="64" alt="@UVhyx" title="@UVhyx" /></a>
<a href="https://github.com/thanatosmoe"><img src="https://github.com/thanatosmoe.png?size=64" width="64" alt="@thanatosmoe" title="@thanatosmoe" /></a>
<a href="https://github.com/sbVAN"><img src="https://github.com/sbVAN.png?size=64" width="64" alt="@sbVAN" title="@sbVAN" /></a>
<a href="https://github.com/NoxiousKoala1"><img src="https://github.com/NoxiousKoala1.png?size=64" width="64" alt="@NoxiousKoala1" title="@NoxiousKoala1" /></a>
<a href="https://github.com/ZnonEn"><img src="https://github.com/ZnonEn.png?size=64" width="64" alt="@ZnonEn" title="@ZnonEn" /></a>
<a href="https://github.com/Gr11nJ"><img src="https://github.com/Gr11nJ.png?size=64" width="64" alt="@Gr11nJ" title="@Gr11nJ" /></a>
<a href="https://github.com/NIFS1729"><img src="https://github.com/NIFS1729.png?size=64" width="64" alt="@NIFS1729" title="@NIFS1729" /></a>
<a href="https://github.com/Mutx163"><img src="https://github.com/Mutx163.png?size=64" width="64" alt="@Mutx163" title="@Mutx163" /></a>
<a href="https://github.com/shixiaogaoya"><img src="https://github.com/shixiaogaoya.png?size=64" width="64" alt="@shixiaogaoya" title="@shixiaogaoya" /></a>
<a href="https://github.com/MX703DR"><img src="https://github.com/MX703DR.png?size=64" width="64" alt="@MX703DR" title="@MX703DR" /></a>
<a href="https://github.com/Lucas04-nhr"><img src="https://github.com/Lucas04-nhr.png?size=64" width="64" alt="@Lucas04-nhr" title="@Lucas04-nhr" /></a>
<a href="https://github.com/JR2714"><img src="https://github.com/JR2714.png?size=64" width="64" alt="@JR2714" title="@JR2714" /></a>
<a href="https://github.com/LittleArray"><img src="https://github.com/LittleArray.png?size=64" width="64" alt="@LittleArray" title="@LittleArray" /></a>
<a href="https://github.com/LanRhyme"><img src="https://github.com/LanRhyme.png?size=64" width="64" alt="@LanRhyme" title="@LanRhyme" /></a>
<!-- CONTRIBUTORS:AUTO:END -->

其中直接向教务仓库提交过的同学：

<!-- CONTRIBUTORS_DIRECT:AUTO:START -->
<a href="https://github.com/jiqian-bbop"><img src="https://github.com/jiqian-bbop.png?size=64" width="64" alt="@jiqian-bbop" title="@jiqian-bbop" /></a>
<a href="https://github.com/lmy18837613075"><img src="https://github.com/lmy18837613075.png?size=64" width="64" alt="@lmy18837613075" title="@lmy18837613075" /></a>
<a href="https://github.com/mcxufly"><img src="https://github.com/mcxufly.png?size=64" width="64" alt="@mcxufly" title="@mcxufly" /></a>
<!-- CONTRIBUTORS_DIRECT:AUTO:END -->

> 贡献者名单由 [tool/generate_contributors.py](./tool/generate_contributors.py) 每周自动更新，无需手动维护。

## Star History

<a href="https://www.star-history.com/?repos=mutx163%2Fmikcb&type=timeline&logscale=&releases=&legend=bottom-right">
 <picture>
   <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/chart?repos=mutx163/mikcb&type=timeline&theme=dark&legend=bottom-right" />
   <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/chart?repos=mutx163/mikcb&type=timeline&legend=bottom-right" />
   <img alt="Star History Chart" src="https://api.star-history.com/chart?repos=mutx163/mikcb&type=timeline&legend=bottom-right" />
 </picture>
</a>

## 许可证

本仓库源码使用 [GNU General Public License v3.0](./LICENSE)（SPDX: `GPL-3.0-or-later`）。

随应用分发的第三方 SDK 与资源许可见 [docs/THIRD_PARTY_LICENSES.md](./docs/THIRD_PARTY_LICENSES.md)。
