# i18n 繁化补齐清单（体检⑧）

> 生成于 PR #17 审计，基线 commit 6ed3c5ae。判定标准：**繁体文案与简体逐字相同且含 CJK 字符**（即未繁化）。不含 CJK 的相同文案（占位符、纯英文/数字）属正常，不在清单内。

| 语言 | key 总数 | 与简体逐字相同 | 其中含 CJK（真未繁化） |
|---|---|---|---|
| zh_HK | 3095 | 294 | **267** |
| zh_TW | 3095 | 771 | **744** |
| en | 3095 | 16 | 0（质量正常） |

TW 未繁化集合完全覆盖 HK 集合（交集 265/267），修复 TW 即可顺带覆盖绝大多数 HK 缺口。

## 建议的翻译流程

1. **机械预繁化**：对下方 key 用 OpenCC（`s2hk`/`s2twp`）批量转换，一次性消掉 90%+ 缺口
2. **人工校对 TW 用语**：`s2twp` 会做词汇转换（如 网络→網路、软件→軟體），但仍需抽查教学领域用语（課程/節/教務處 等两岸差异）
3. **HK 校对重点**：HK 用语更接近书面繁体 + 少量粤语习惯，OpenCC `s2hk` 后人工抽查即可
4. **防回归**：本清单可作为 CI 校验脚本的数据源（繁化率低于阈值即告警），或直接以「zh_HK/zh_TW 与 zh 逐字相同的含 CJK 条数 ≤ 当前基线」作为棘轮指标

## zh_TW 待繁化（744 条）

| key | 简体文案（= 当前繁体文案） |
|---|---|
| `aboutAlreadyLatestHeadline` | 已是最新版本 |
| `aboutContributorsScreenTitle` | 代码贡献者 |
| `aboutDownloadChannelSectionTitle` | 下载渠道 |
| `aboutDownloadPackageMethodTitle` | 下载安装包方式 |
| `aboutEditCustomMirrorAction` | 修改自定义地址 |
| `aboutInAppDownloadTitle` | 应用内下载 |
| `aboutLatestVersionLabel` | 最新版本 |
| `aboutMirrorProbeFailedLabel` | 失败 |
| `aboutRecommended` | 推荐 |
| `aboutSwitchToRecommendedAction` | 切到推荐：{label} |
| `aboutSystemDownloaderTitle` | 系统管理器 |
| `aboutUnavailable` | 不可用 |
| `aboutUpdateAvailableHeadline` | 有版本更新 |
| `aboutUpdateNowTitle` | 立即更新 |
| `aboutUpdateScreenTitle` | 版本更新 |
| `aboutUpdatesTitle` | 版本更新 |
| `aboutVersionChannelLabel` | 版本通道 |
| `aboutViewReleaseAction` | 查看 Release |
| `addMethodTitle` | 添加方式 |
| `aiParseErrorTitle` | 解析错误 |
| `aiParseFailedChip` | 解析失败 |
| `aiPasteJsonFirst` | 请先粘贴 AI 返回的 JSON |
| `aiPasteJsonHintShort` | 粘贴 AI 返回的 JSON |
| `aiPasteJsonTitle` | 粘贴 AI 返回的 JSON |
| `aiPromptShortAction` | 提示词 |
| `aiWarningCountSuffix` | ，{count} 条提醒 |
| `allWeeksFilter` | 全部 |
| `allWeeksLabel` | 全部 |
| `appUpdateDownloadChannelGithub` | GitHub 下载 |
| `appUpdateDownloadChannelGithubDescription` | GitHub 原生 + 国内镜像 |
| `appUpdateDownloadChannelPgyer` | 蒲公英下载 |
| `appUpdateDownloadChannelPgyerDescription` | 国内高速下载，推荐使用 |
| `appUpdateDownloadSourceMirror` | 国内镜像 |
| `appUpdateDownloadSourceOriginal` | GitHub 原版 |
| `appUpdateMirrorPresetCustom` | 自定义 |
| `appUpdateMirrorPresetCustomDescription` | 填写自定义镜像地址前缀 |
| `appUpdateMirrorPresetGhLlkk` | 备用镜像 2 |
| `appUpdateMirrorPresetGhProxyCom` | 备用镜像 3 |
| `appUpdateMirrorPresetGhfast` | 默认镜像 |
| `appUpdateMirrorPresetGhproxyCn` | 备用镜像 1 |
| `appUpdateMirrorPresetGhproxyNet` | 备用镜像 4 |
| `availableWeeksCount` | 共 {count} 周 |
| `backToTodayAction` | 回到今天 |
| `beforeEndSecondsOption` | {seconds} 秒 |
| `breakDurationMinutesLabel` | 休息多久(分) |
| `brightnessLabel` | 明度 {value}% |
| `cancelAction` | 取消 |
| `classAlarmLeadTitle` | 提前量 |
| `clearAction` | 清空 |
| `clearCustomLoginAddressAction` | 清除自定义地址 |
| `clearSearchTooltip` | 清空 |
| `cloudBackupManualProtectedSubtitle` | 开启后，手动创建的备份不会被自动清理 |
| `cloudBackupManualProtectedTitle` | 手动备份永不过期 |
| `cloudBackupMaxAgeOption` | {days} 天 |
| `cloudBackupMaxAgeSubtitle` | 超过后自动删除过期备份 |
| `cloudBackupMaxAgeTitle` | 最长保留天数 |
| `cloudBackupMaxCountOption` | {count} 份 |
| `cloudBackupMaxCountSubtitle` | 超过后自动删除最旧的备份 |
| `cloudBackupMaxCountTitle` | 最多保留份数 |
| `cloudBackupRetentionTitle` | 备份保留策略 |
| `cloudSyncEntrySyncing` | 同步中 |
| `cloudSyncLastSyncedAt` | 上次同步：{time} |
| `cloudSyncLastSyncedLabel` | 上次同步 |
| `cloudSyncModeTitle` | 同步方式 |
| `cloudSyncResultCancelled` | 已取消同步 |
| `cloudSyncSyncNow` | 立即同步 |
| `cloudSyncSyncing` | 正在同步… |
| `colorGroupDeep` | 深色系 |
| `colorGroupDopamine` | 多巴胺系 |
| `colorGroupOcean` | 海洋系 |
| `colorGroupSunset` | 落日系 |
| `conflictLabel` | 冲突 |
| `coupleTimetableSharedFreeMeta` | 共 {count} 段 |
| `coupleWebdavLastPulledAt` | 上次拉取：{time} |
| `coupleWebdavSlotOne` | 槽位 1 |
| `coupleWebdavSlotTwo` | 槽位 2 |
| `courseCardHorizontalAlignCenter` | 居中 |
| `courseCardHorizontalAlignLeft` | 居左 |
| `courseCardHorizontalAlignRight` | 居右 |
| `courseCardSurfaceStyleGaussian` | 高斯模糊 |
| `courseCardVerticalAlignBottom` | 底部对齐 |
| `courseCardVerticalAlignCenter` | 垂直居中 |
| `courseCardVerticalAlignSpaceEvenly` | 上下均布 |
| `courseCardVerticalAlignTop` | 顶部对齐 |
| `courseImportAutoFillAndImportAction` | 自动补齐并导入 |
| `courseImportCalendarWeekLabel` | 校历第 {week} 周 |
| `courseImportContinueAction` | 继续导入 |
| `courseImportFirstWeekMappingLabel` | 课表第 1 周对应校历第几周 |
| `courseImportFirstWeekMappingSubtitle` | 如果学校第一周没课，就选第 2 周；前两周都没课就选第 3 周 |
| `courseImportFirstWeekNoShift` | 导入后会直接把课表第 1 周当作校历第 1 周 |
| `courseImportFirstWeekShifted` | 导入后会把所有课程周次整体顺延 {weeks} 周，让课表第 1 周落在校历第 {targetWeek} 周 |
| `courseImportLocationNotFilled` | 未填写地点 |
| `courseImportOverwriteAction` | 覆盖导入 |
| `courseImportPortalUrlHint` | 保存后下次会直接使用，也可以在适配器信息页里修改 |
| `courseImportPortalUrlInvalid` | 登录地址格式不正确 |
| `courseImportPortalUrlLabel` | 教务网址 |
| `courseImportPortalUrlMissingBody` | “{schoolName} / {adapterName}” 没有默认登录地址，请先输入学校教务系统网址 |
| `courseImportPortalUrlSaveContinue` | 保存并继续 |
| `courseImportPortalUrlTitle` | 输入教务网址 |
| `courseImportPreviewLine` | 周{weekday} 第{startSection}-{endSection}节  {name}  {location}  周次：{weekText} |
| `courseImportQuickImportDescription` | 快捷导入 {schoolName} {adapterName} |
| `courseImportRecordingEmptyStatus` | 未录制到任何操作 |
| `courseImportRecordingEmptyTip` | 未录制到任何操作 |
| `courseImportRecordingSavedStatus` | 录制已保存（{count} 步） |
| `courseImportRecordingStartedTip` | 录制已开始，请按正常流程操作教务网站 |
| `courseImportRecordingStatus` | 录制中…点击停止完成录制 |
| `courseImportSaveRecordingMessage` | 录制了 {count} 个操作步骤，是否保存为快捷导入？ |
| `courseImportSaveRecordingTitle` | 保存录制 |
| `courseImportScriptFailed` | 脚本执行失败 |
| `courseImportScriptNoCourses` | 导入脚本未返回课程数据 |
| `courseImportSectionCountInsufficientMessage` | 当前课表时间模板只有 {current} 节，但导入数据需要到第 {required} 节，是否自动补齐后继续导入？ |
| `courseImportSectionCountInsufficientTitle` | 时间模板节次不足 |
| `courseImportTermStartDateTitle` | 开学日期 |
| `courseImportUpdateRecommendedAction` | 更新课表（推荐） |
| `courseImportWeekNotProvided` | 未提供周次 |
| `courseNatureRequired` | 必修 |
| `courseNoteDoneEditingAction` | 完成 |
| `courseRecolorNext` | 下一套 |
| `courseRecolorPrevious` | 上一套 |
| `courseRecolorSchemePosition` | 第 {index}/{total} 套 |
| `courseWeekCustomDescription` | 第{weeks}周 |
| `courseWeekEvenModeSuffix` |  双周 |
| `courseWeekListLabel` | 第{weeks}周 |
| `courseWeekOddModeSuffix` |  单周 |
| `courseWeekRangeDescription` | 第{startWeek}-{endWeek}周{mode} |
| `courseWeekRangeLabel` | 第{startWeek}-{endWeek}周{mode} |
| `courseWeekSuspendedLabel` | 第{weeks}周停课 |
| `courseWeekSuspensionDescription` | 第{weeks}周停课 |
| `crossDayBadgeLabel` | 跨日 |
| `currentProfileTimeSchemeName` | 当前课表时间 |
| `currentWeekCompact` | {week}周 |
| `dailyUsageSectionTitle` | 日常使用 |
| `dataTransferFullBackupShareSubject` | 轻屿课表 - 全部数据备份 |
| `dataTransferFullBackupShareText` | 这是轻屿课表的全部数据备份文件，包含所有课表、当前选中课表和时间模板 |
| `dataTransferProfileShareSubject` | 轻屿课表备份 |
| `dataTransferProfileShareSubjectNamed` | {profileName} - 轻屿课表备份 |
| `dataTransferProfileShareText` | 这是轻屿课表当前课表的完整备份文件，导入后可直接恢复课程和设置 |
| `debugScriptLength` | 脚本 {count} 字符 |
| `detailAction` | 详情 |
| `diagnosticsLevelAll` | 全部 |
| `diagnosticsLevelWarn` | 警告 |
| `diagnosticsMessage` | 消息 |
| `diagnosticsRawTab` | 原文 |
| `diagnosticsTimeSortAscending` | 正序 |
| `diagnosticsTimeSortDescending` | 倒序 |
| `editAction` | 编辑 |
| `editActionShort` | 编辑 |
| `editCustomLoginAddressAction` | 修改自定义地址 |
| `examCountdownToday` | 今天 |
| `examOverviewUntilTime` | 至 {time} |
| `examReminderAddCustom` | 添加提醒 |
| `examReminderAddCustomHint` | 设置距离考试开始前多久提醒，可添加多个 |
| `examReminderAddCustomTitle` | 自定义提醒时间 |
| `examReminderCustom` | 自定义 |
| `examReminderCustomAlreadyAdded` | 该提醒时间已添加 |
| `examReminderCustomEmpty` | 请至少选择一个提醒时间 |
| `examReminderCustomEmptyHint` | 还没有自定义提醒，点下方添加 |
| `examReminderCustomInvalid` | 请设置大于 0 的提醒时间 |
| `examReminderDay1` | 考前 1 天 |
| `examReminderDay1AndHour1` | 考前 1 天 + 1 小时 |
| `examReminderHour1` | 考前 1 小时 |
| `examReminderHour1AndMin30` | 考前 1 小时 + 30 分钟 |
| `examReminderMin30` | 考前 30 分钟 |
| `examReminderNone` | 不提醒 |
| `examReminderOffsetDays` | 考前 {days} 天 |
| `examReminderOffsetHours` | 考前 {hours} 小时 |
| `examReminderOffsetMinutes` | 考前 {minutes} 分钟 |
| `examReminderPickerDays` | 天 |
| `examReminderPickerHours` | 小时 |
| `examReminderPickerMinutes` | 分钟 |
| `feedbackCoolapkSubtitle` | 酷安号：{id} |
| `feedbackCoolapkTitle` | 酷安 |
| `feedbackQqGroupSubtitle` | 群号：{id} |
| `feedbackQqGroupTitle` | QQ 群 |
| `foruiThemeNeutral` | 中性灰 |
| `foruiThemeOrange` | 橙 |
| `foruiThemeSlate` | 石板灰 |
| `foruiThemeViolet` | 紫 |
| `frostedGlassModeGaussian` | 高斯模糊 |
| `frostedGlassModeLabel` | 玻璃模式 |
| `frostedGlassModeTranslucent` | 半透明 |
| `frostedSheetSectionTitle` | 磨砂玻璃 |
| `frostedSheetTintLabel` | 磨砂亮度 |
| `generateAction` | 生成 |
| `goAction` | 前往 |
| `goToWeekLabel` | 第 {week} 周 |
| `gotItAction` | 知道了 |
| `guideChipReadyCount` | {count}/3 已完成 |
| `guideNextButton` | 下一步 |
| `guidePermissionsProgressLabel` | 已就绪 {ready}/{total} |
| `guidePrevButton` | 上一步 |
| `guideShortNameNotRecommended` | 不推荐 |
| `guideShortNameRecommended` | 推荐示例 |
| `guideStatusAndroidVersion` | Android 版本 |
| `guideStatusBatteryRestricted` | 仍受限制 |
| `guideStatusIslandSystemRequirement` | 需 HyperOS 3.0.300 及以上 |
| `guideTipsHeader` | 使用技巧 |
| `guideTipsPageTitle` | 使用技巧 |
| `higherByValue` | 更高 {value} |
| `holidayDataYear` | 年份 |
| `holidayDateDiffMonth` | {startMonth}月{startDay}日 - {endMonth}月{endDay}日 |
| `holidayDateSameDay` | {month}月{day}日 |
| `holidayDateSameMonth` | {month}月{start}日 - {end}日 |
| `holidayLogBackgroundNoData` | {year}年：后台更新未获取到新数据 |
| `holidayLogBackgroundSuccess` | {year}年：后台更新成功（{count} 条），已覆盖缓存 |
| `holidayLogBuiltinLoaded` | {year}年：加载内置资产（{count} 条） |
| `holidayLogFallbackApiError` | 备用 API 返回错误 |
| `holidayLogFallbackApiException` | 备用 API 异常：{error} |
| `holidayLogFallbackApiParsing` | 备用 API 返回 {count} 条原始数据，正在解析… |
| `holidayLogFallbackApiStatus` | 备用 API 响应 {statusCode}，跳过 |
| `holidayLogLocalCacheHit` | {year}年：命中本地缓存（{count} 条），后台刷新中… |
| `holidayLogMemoryCacheHit` | {year}年：命中内存缓存（{count} 条），后台刷新中… |
| `holidayLogNoCacheFetching` | {year}年：无缓存，正在拉取远程数据… |
| `holidayLogNoValidEntries` | 解析后无有效条目，跳过 |
| `holidayLogPrimaryApiError` | 主 API 返回错误：{message} |
| `holidayLogPrimaryApiException` | 主 API 异常：{error} |
| `holidayLogPrimaryApiFailed` | 主 API 失败，尝试备用 API… |
| `holidayLogPrimaryApiParsing` | 主 API 返回 {count} 条原始数据，正在解析… |
| `holidayLogPrimaryApiStatus` | 主 API 响应 {statusCode}，跳过 |
| `holidayLogRemoteFailedBuiltin` | {year}年：远程拉取失败，使用内置资产兜底 |
| `holidayLogRemoteSuccess` | {year}年：远程拉取成功（{count} 条），已缓存 |
| `holidayLogRequesting` | 正在请求 {uri} … |
| `holidayNameDragonBoat` | 端午节 |
| `holidayNameLaborDay` | 劳动节 |
| `holidayNameMidAutumn` | 中秋节 |
| `holidayNameNationalDay` | 国庆节 |
| `holidayNameNewYear` | 元旦 |
| `holidayNameQingming` | 清明节 |
| `holidayNameSpringFestival` | 春节 |
| `homeGridEditorRemoveTooltip` | 移除 |
| `homeMenuCategoryFeatures` | 功能入口 |
| `homePageBackgroundFillLabel` | 背景填充 |
| `homeTitleStyleBrandLabel` | 大 Logo |
| `homeWidgetBackgroundStyleLabel` | 背景样式 |
| `homeWidgetCornerRadiusTitle` | 卡片圆角 |
| `homeWidgetQuickAddTitle` | 快速添加到桌面 |
| `homeWidgetTargetCompact22` | 主卡 2×2 |
| `hueLabel` | 色相 {value} |
| `hyperosShowcaseAccordionSection1` | 第一节 |
| `hyperosShowcaseAccordionSection1Body` | 展开后显示的内容区域 |
| `hyperosShowcaseAccordionSection2` | 第二节 |
| `hyperosShowcaseAccordionSection2Body` | 可折叠分组，替代 FAccordion |
| `hyperosShowcaseActionButton` | 操作按钮 |
| `hyperosShowcaseAlreadyInSubpage` | 已在 Subpage 中 |
| `hyperosShowcaseCheckboxSubtitle` | 多选偏好行 |
| `hyperosShowcaseConfirmTitle` | 确认操作 |
| `hyperosShowcaseConfirmed` | 已确认 |
| `hyperosShowcaseControlsSubtitle` | 滑条、分段、按钮 |
| `hyperosShowcaseDialogMessage` | 系统风格对话框示例 |
| `hyperosShowcaseDividerRowTitle` | 第二行（上方有缩进分割线） |
| `hyperosShowcaseEmptySubtitle` | 列表无数据时的占位 |
| `hyperosShowcaseFooterNote` | 此页仅在非 Release 构建设置首页可见，用于组件视觉验收 |
| `hyperosShowcaseInputCardLabel` | 卡片内输入 |
| `hyperosShowcaseInputHint` | 请输入内容 |
| `hyperosShowcaseKitSubtitle` | mikcb 澎湃风格组件一览 |
| `hyperosShowcaseMenuCopy` | 复制 |
| `hyperosShowcaseMenuDelete` | 删除 |
| `hyperosShowcaseMenuShare` | 分享 |
| `hyperosShowcaseNavHome` | 首页 |
| `hyperosShowcaseNavRowDetails` | 详情 |
| `hyperosShowcaseNavRowNoIconSubtitle` | 无左侧彩图标 |
| `hyperosShowcaseNavRowWithIcon` | 带图标 |
| `hyperosShowcaseNavSettings` | 设置 |
| `hyperosShowcaseNavTimetable` | 课表 |
| `hyperosShowcaseOptionA` | 选项 A |
| `hyperosShowcaseOptionB` | 选项 B |
| `hyperosShowcaseOptionC` | 选项 C |
| `hyperosShowcasePickerCurrentValue` | 当前值：{value} |
| `hyperosShowcasePushSubtitle` | 通过 HyperosNavigation.push 进入 |
| `hyperosShowcaseRefreshDone` | 刷新完成 |
| `hyperosShowcaseRootPageDetails` | 无返回键根页 |
| `hyperosShowcaseRootShellLabel` | 根页壳层 |
| `hyperosShowcaseSampleText` | 示例文本 |
| `hyperosShowcaseSearchTooltip` | 搜索 |
| `hyperosShowcaseSectionChoiceRows` | 列表行 · 单选 / 选择 / 日期 |
| `hyperosShowcaseSectionColorChip` | 颜色选择 · ColorChip |
| `hyperosShowcaseSectionControls` | 控件卡片 |
| `hyperosShowcaseSectionEmpty` | 空态 / 分割线 / 装饰 |
| `hyperosShowcaseSectionFeedback` | 反馈 · 弹层 |
| `hyperosShowcaseSectionFrosted` | 模糊顶栏 · 滚动物理 |
| `hyperosShowcaseSectionIconColors` | 主题色 · HyperosIconColors |
| `hyperosShowcaseSectionInline` | 基础控件 · 行内 |
| `hyperosShowcaseSectionInput` | 输入 |
| `hyperosShowcaseSectionNavActions` | 导航与操作 |
| `hyperosShowcaseSectionNavBar` | 底部导航 · HyperosNavigationBar |
| `hyperosShowcaseSectionNavRows` | 列表行 · 导航 |
| `hyperosShowcaseSectionPicker` | 滚轮选择器 |
| `hyperosShowcaseSectionPressable` | 底层行 · HyperosPressableRow |
| `hyperosShowcaseSectionProgress` | 进度与刷新 |
| `hyperosShowcaseSectionShell` | 页面壳层 |
| `hyperosShowcaseSectionSummary` | 概要卡片 |
| `hyperosShowcaseSectionSwitchRows` | 列表行 · 开关 / 危险 |
| `hyperosShowcaseSectionTags` | 标签 / 手风琴 / 提示 |
| `hyperosShowcaseSegmentLeft` | 左 |
| `hyperosShowcaseSegmentRight` | 右 |
| `hyperosShowcaseSelectSizeTitle` | 选择尺寸 |
| `hyperosShowcaseSizeLarge` | 大 |
| `hyperosShowcaseSizeMedium` | 中 |
| `hyperosShowcaseSizeSmall` | 小 |
| `hyperosShowcaseSubpageSubtitle` | 当前页即 Subpage + HyperosListView |
| `hyperosShowcaseSwitchRowPlain` | 纯文字开关行 |
| `hyperosShowcaseSwitchRowSubtitle` | 带图标开关行 |
| `hyperosShowcaseTitle` | 澎湃 UI 组件库 |
| `hyperosShowcaseToastDescription` | 带图标与副标题，App Toast 同款 |
| `hyperosShowcaseTooltipButton` | 带 Tooltip 的按钮 |
| `hyperosShowcaseUndoAction` | 撤销 |
| `icsExportSchedules` | 日程 |
| `importSemesterStartDateTitle` | 开学日期 |
| `inputRequiredTitle` | 需要输入 |
| `lanEditConnectedClientsValue` | {count} 台 |
| `lanEditStop` | 停止 |
| `layoutHorizontalAlignLabel` | 水平排版 |
| `layoutVerticalAlignLabel` | 垂直排版 |
| `liquidGlassChromaticAberrationLabel` | 色差 |
| `liquidGlassLightAngleLabel` | 光照角度 |
| `liquidGlassPresetClear` | 清澈 |
| `liquidGlassRefractiveIndexLabel` | 折射率 |
| `liquidGlassThicknessLabel` | 厚度 |
| `liveBeforeClassQuickActionDoNotDisturb` | 打开免打扰 |
| `liveBeforeClassQuickActionNone` | 不显示 |
| `liveBeforeClassQuickActionSilent` | 打开静音 |
| `liveCountdownTextStyleMinuteOnlyCn` | 纯分钟（5分钟） |
| `liveCountdownTextStyleMinuteSecondCn` | 分秒（5分钟19秒） |
| `liveCountdownTextStyleSecondOnlyCn` | 纯秒（5秒） |
| `liveCountdownTextStyleSmart` | 智能（中文） |
| `liveCountdownTextStyleSmartMinS` | 智能（英文） |
| `liveDisplayConfigModeTitle` | 配置方式 |
| `liveDisplayModeTitle` | 展示方式 |
| `liveDuringClassTimeNearest` | 最近时间 |
| `liveDuringClassTimeTotal` | 总时间 |
| `liveGroupReminders` | 提醒 |
| `liveIslandPreviewSampleLocation` | 三教-401 |
| `liveTestingClearingLogs` | 清空中 |
| `liveTestingNotRefreshed` | 尚未刷新 |
| `liveTestingRefreshedAt` | 上次刷新：{time} |
| `liveTestingRefreshing` | 刷新中 |
| `liveTestingSectionNotification` | 通知判定结果 |
| `locationTimeMatchAddAllBuildings` | 一键添加全部未配置楼栋 |
| `locationTimeMatchAddBuilding` | 添加 |
| `locationTimeMatchAddKeyword` | 手动添加关键词 |
| `locationTimeMatchApplyConfirm` | 重新匹配 |
| `locationTimeMatchApplyOverflowHint` | 未套用示例：{names} |
| `locationTimeMatchBoundScheme` | 时间模板：{name} |
| `locationTimeMatchBoundSchemeLabel` | 绑定时间模板 |
| `locationTimeMatchBuildingGateTags` | 标签：{tags} |
| `locationTimeMatchBuildingRoomCount` | {count} 间教室 |
| `locationTimeMatchBuildingSuggestions` | 从课表识别的楼栋 |
| `locationTimeMatchCreateGroup` | 新建地点组 |
| `locationTimeMatchDeleteTitle` | 删除地点组？ |
| `locationTimeMatchDeleted` | 已删除地点组 |
| `locationTimeMatchEditGroup` | 编辑地点组 |
| `locationTimeMatchEnabledLabel` | 启用此地点组 |
| `locationTimeMatchGroupNameHint` | 例如：主教学楼 / 其他教学楼 |
| `locationTimeMatchGroupNameLabel` | 地点组名称 |
| `locationTimeMatchKeywordAlreadyExists` | 关键词已存在 |
| `locationTimeMatchKeywordExtracted` | 已从地点提取关键词 {keyword} |
| `locationTimeMatchKeywordHint` | A1 / A主 / 六教 |
| `locationTimeMatchKeywordLabel` | 关键词 |
| `locationTimeMatchKeywordRequired` | 请至少添加一个关键词 |
| `locationTimeMatchKeywordTooShort` | 关键词过短，容易误匹配 |
| `locationTimeMatchKeywordsHelp` | 可从课表地点一键识别楼栋，或手动填写关键词（如 A主、A1、A6）。匹配模式建议用「前缀」，更长的关键词优先。 |
| `locationTimeMatchKeywordsLine` | 关键词：{keywords} |
| `locationTimeMatchKeywordsSection` | 地点关键词 |
| `locationTimeMatchModeContains` | 包含 |
| `locationTimeMatchModeExact` | 精确 |
| `locationTimeMatchModeLabel` | 匹配模式 |
| `locationTimeMatchModePrefix` | 前缀 |
| `locationTimeMatchNameRequired` | 请填写地点组名称 |
| `locationTimeMatchNeedTimeScheme` | 请先创建至少一套时间模板 |
| `locationTimeMatchNoBuildingSuggestions` | 当前课表没有可识别的楼栋地点 |
| `locationTimeMatchNoKeywords` | 未设置关键词 |
| `locationTimeMatchNoSelectedKeywords` | 尚未添加关键词 |
| `locationTimeMatchPickFromLocations` | 从课表地点选择 |
| `locationTimeMatchPreviewHint` | 例如 A1062 或 A主201 |
| `locationTimeMatchPreviewLabel` | 试匹配地点 |
| `locationTimeMatchPreviewNoMatch` | 未命中任何地点组，将使用课表默认时间模板 |
| `locationTimeMatchPreviewResult` | 将匹配：{group} · {scheme}（关键词 {keyword}） |
| `locationTimeMatchSaveFailed` | 保存失败 |
| `locationTimeMatchSaved` | 地点组已保存 |
| `locationTimeMatchSelectedKeywords` | 已选关键词 |
| `locationTimeMatchUnknownScheme` | 未知时间模板 |
| `locationTimeMatchWeekAxisNote` | 说明：首页左侧时间列仍显示课表默认模板；卡片/详情/实况上的钟点以地点匹配结果为准。 |
| `locationUnset` | 未置 |
| `logAppLifecycleChanged` | 应用生命周期已变更 |
| `logAppLogRecordingEnabled` | 应用日志记录已开启 |
| `logAppLogRecordingRemainsEnabled` | 应用日志记录保持开启 |
| `logAppLoggerInitialized` | 应用日志服务已初始化 |
| `logAppLogsDefaultMigrated` | 迁移时已默认开启应用日志记录 |
| `logCatAppLifecycleStateChanged` | 应用生命周期 |
| `logCatAppLogRecordingEnabled` | 应用日志：记录开关 |
| `logCatAppLoggerInitialized` | 应用日志：初始化 |
| `logCatAppLogsDefaultMigrated` | 应用日志：迁移 |
| `logCatDebugSnapshot` | 调试快照 |
| `logCatDiagnosticsBootstrap` | 诊断：引导 |
| `logCatDiagnosticsCleared` | 诊断：已清空 |
| `logCatDiagnosticsEnabled` | 诊断：已开启 |
| `logCatFlutterDiagnostic` | Flutter 诊断 |
| `logCatFlutterDiagnosticEvent` | Flutter 诊断事件 |
| `logCatFlutterFrameworkError` | Flutter 框架错误 |
| `logCatFlutterPlatformError` | Flutter 平台错误 |
| `logCatFlutterZoneError` | Flutter Zone 错误 |
| `logCatHomeWidgetClearFailed` | 桌面小组件：清空失败 |
| `logCatHomeWidgetPinRequestFailed` | 桌面小组件：请求固定 |
| `logCatHomeWidgetPinSupportFailed` | 桌面小组件：检查固定支持 |
| `logCatHomeWidgetScheduleFailed` | 桌面小组件：调度刷新 |
| `logCatHomeWidgetSyncFailed` | 桌面小组件：同步失败 |
| `logCatKeepAliveAccessibilityConnected` | 保活：无障碍已连接 |
| `logCatLanEditAuthFailed` | 局域网编辑：认证 |
| `logCatLanEditCourseCreated` | 局域网编辑：创建课程 |
| `logCatLanEditCourseDeleted` | 局域网编辑：删除课程 |
| `logCatLanEditCourseGroupSaved` | 局域网编辑：保存课程组 |
| `logCatLanEditCourseUpdated` | 局域网编辑：更新课程 |
| `logCatLanEditCoursesBatchDeleted` | 局域网编辑：批量删除 |
| `logCatLanEditCurrentWeekSet` | 局域网编辑：设置周次 |
| `logCatLanEditMergeImported` | 局域网编辑：合并导入 |
| `logCatLanEditSessionStarted` | 局域网编辑：会话启动 |
| `logCatLanEditSessionStopped` | 局域网编辑：会话停止 |
| `logCatLanEditSpreadsheetImported` | 局域网编辑：表格导入 |
| `logCatLiveUpdateAlarmTriggered` | 超级岛：闹钟触发 |
| `logCatLiveUpdateBeforeClassQuickAction` | 超级岛：课前快捷操作 |
| `logCatLiveUpdateBeforeClassQuickActionRestored` | 超级岛：课前快捷操作已恢复 |
| `logCatLiveUpdateDebugStatusFailed` | 超级岛：调试状态失败 |
| `logCatLiveUpdateFlutterInitializeFailed` | 超级岛：Flutter 初始化失败 |
| `logCatLiveUpdateNotPromoted` | 超级岛：未提升通知 |
| `logCatLiveUpdatePayloadSelected` | 超级岛：已选负载 |
| `logCatLiveUpdatePromotedNotShown` | 超级岛：提升未显示 |
| `logCatLiveUpdateRescheduleActive` | 超级岛：立即启动 |
| `logCatLiveUpdateRescheduleHoliday` | 超级岛：节假日跳过 |
| `logCatLiveUpdateRescheduleScheduled` | 超级岛：已调度 |
| `logCatLiveUpdateSchedulerResume` | 超级岛：调度恢复 |
| `logCatLiveUpdateSchedulerStartFailed` | 超级岛：调度启动失败 |
| `logCatLiveUpdateServiceMissingPayload` | 超级岛：服务缺少负载 |
| `logCatLiveUpdateServiceStartFailed` | 超级岛：服务启动失败 |
| `logCatLiveUpdateServiceStarted` | 超级岛：服务已启动 |
| `logCatLiveUpdateServiceStopped` | 超级岛：服务已停止 |
| `logCatLiveUpdateSettingsSynced` | 超级岛：设置已同步 |
| `logCatLiveUpdateSnapshotClearFailed` | 超级岛：快照清空失败 |
| `logCatLiveUpdateSnapshotCleared` | 超级岛：快照已清空 |
| `logCatLiveUpdateSnapshotInvalidatedAfterUpgrade` | 超级岛：升级后快照失效 |
| `logCatLiveUpdateSnapshotParseFailed` | 超级岛：快照解析失败 |
| `logCatLiveUpdateSnapshotSettings` | 超级岛：快照设置 |
| `logCatLiveUpdateSnapshotSyncFailed` | 超级岛：快照同步失败 |
| `logCatLiveUpdateSnapshotSynced` | 超级岛：快照已同步 |
| `logCatLiveUpdateStartFailed` | 超级岛：启动失败 |
| `logCatLiveUpdateStartRequested` | 超级岛：请求启动 |
| `logCatLiveUpdateStatusBarDismissed` | 超级岛：状态栏通知已关闭 |
| `logCatLiveUpdateStopFailed` | 超级岛：停止失败 |
| `logCatLiveUpdateStopRequested` | 超级岛：请求停止 |
| `logCatLiveUpdateTaskRemoved` | 超级岛：任务被移除 |
| `logCatLiveUpdateTaskRemovedResumed` | 超级岛：任务移除后恢复 |
| `logCatLiveUpdateTestFailed` | 超级岛测试：失败 |
| `logCatLiveUpdateTestNoSelection` | 超级岛测试：无课程 |
| `logCatLiveUpdateTestRequested` | 超级岛测试：请求 |
| `logCatLiveUpdateTestSelectionReady` | 超级岛测试：已选课程 |
| `logCatLiveUpdateTestStarted` | 超级岛测试：已启动 |
| `logCatLiveUpdateTestStarting` | 超级岛测试：启动中 |
| `logCatLiveUpdateTestSuspendSync` | 超级岛测试：暂停同步 |
| `logCatMiuiLiveHideFromRecentsFailed` | 超级岛：隐藏最近任务 |
| `logCatMiuiLiveInitializeFailed` | 超级岛：初始化失败 |
| `logCatMiuiLiveOpenAccessibilitySettingsFailed` | 超级岛：打开无障碍设置 |
| `logCatMiuiLiveOpenAutostartSettingsFailed` | 超级岛：打开自启动设置 |
| `logCatMiuiLiveOpenBatterySettingsFailed` | 超级岛：打开电池优化 |
| `logCatMiuiLiveOpenNotificationSettingsFailed` | 超级岛：打开通知设置 |
| `logCatMiuiLiveOpenPromotedSettingsFailed` | 超级岛：打开权限设置 |
| `logCatPrivacyConsentUpdated` | 应用日志：隐私协议 |
| `logCatRenderFailed` | 渲染失败 |
| `logCatRoutePopped` | 路由：出栈 |
| `logCatRoutePushed` | 路由：入栈 |
| `logCatRouteReplaced` | 路由：替换 |
| `logCatStartupFlowCompleted` | 启动流程：完成 |
| `logCatStartupFlowFailed` | 启动流程：失败 |
| `logCatStartupFlowStarted` | 启动流程：开始 |
| `logCatTimetableLoadCoursesFailed` | 课表：加载课程失败 |
| `logCatTimetableLoadCurrentWeekFailed` | 课表：加载周次失败 |
| `logCatTimetableLoadSettingsFailed` | 课表：加载设置失败 |
| `logExportTitle` | 轻屿课表 - 应用日志 |
| `logFieldAccepted` | 已同意 |
| `logFieldAction` | 操作 |
| `logFieldAutoStartStatus` | 自启动状态 |
| `logFieldBrand` | 品牌 |
| `logFieldBuildNumber` | 构建号 |
| `logFieldCanPostPromotedNotifications` | 可发布提升通知 |
| `logFieldChannel` | 渠道 |
| `logFieldClientIp` | 客户端 IP |
| `logFieldContext` | 设备上下文 |
| `logFieldCount` | 数量 |
| `logFieldCourseName` | 课程名 |
| `logFieldCurrentWeek` | 当前周次 |
| `logFieldDeletedCount` | 删除数量 |
| `logFieldError` | 错误 |
| `logFieldExtras` | 附加信息 |
| `logFieldFrom` | 来源页面 |
| `logFieldHasNotificationPermission` | 通知权限 |
| `logFieldHasPromotedPermissionDeclared` | 已声明提升通知权限 |
| `logFieldHideFromRecentsEnabled` | 从最近任务隐藏 |
| `logFieldIgnoringBatteryOptimizations` | 忽略电池优化 |
| `logFieldIntentIsNull` | Intent 为空 |
| `logFieldKeepAliveAccessibilityEnabled` | 无障碍保活已启用 |
| `logFieldLastTaskRemovedAt` | 上次任务移除时间 |
| `logFieldLiveClassReminderStartMinutes` | 上课提醒开始分钟 |
| `logFieldLiveDuringClassTimeDisplayMode` | 课中时间显示模式 |
| `logFieldLiveEnableBeforeClass` | 课前超级岛 |
| `logFieldLiveEnableBeforeEnd` | 下课前超级岛 |
| `logFieldLiveEnableDuringClass` | 课中超级岛 |
| `logFieldLiveEnableMiuiIslandLabelImage` | 岛标签图片 |
| `logFieldLiveEndSecondsCountdownThreshold` | 下课秒倒计时阈值 |
| `logFieldLiveHidePrefixText` | 隐藏前缀文字 |
| `logFieldLiveMiuiIslandExpandedIconMode` | 展开图标模式 |
| `logFieldLiveMiuiIslandLabelContent` | 岛标签内容 |
| `logFieldLiveMiuiIslandLabelFontColor` | 岛标签字体颜色 |
| `logFieldLiveMiuiIslandLabelFontSize` | 岛标签字号 |
| `logFieldLiveMiuiIslandLabelFontWeight` | 岛标签字重 |
| `logFieldLiveMiuiIslandLabelOffsetX` | 岛标签 X 偏移 |
| `logFieldLiveMiuiIslandLabelOffsetY` | 岛标签 Y 偏移 |
| `logFieldLiveMiuiIslandLabelRenderQuality` | 岛标签渲染质量 |
| `logFieldLiveMiuiIslandLabelStyle` | 岛标签样式 |
| `logFieldLivePromoteDuringClass` | 课中提升通知 |
| `logFieldLiveShowBeforeClassMinutes` | 课前显示分钟数 |
| `logFieldLiveShowCountdown` | 显示倒计时 |
| `logFieldLiveShowCourseName` | 显示课程名 |
| `logFieldLiveShowDuringClassNotification` | 课中状态栏通知 |
| `logFieldLiveShowLocation` | 显示地点 |
| `logFieldLiveShowStageText` | 显示阶段文字 |
| `logFieldLiveUseShortName` | 使用简称 |
| `logFieldLoggingEnabled` | 日志记录 |
| `logFieldManufacturer` | 制造商 |
| `logFieldMergedCourseCount` | 合并课程数 |
| `logFieldModel` | 型号 |
| `logFieldPlatform` | 平台 |
| `logFieldPort` | 端口 |
| `logFieldPrevious` | 先前状态 |
| `logFieldPreviousRoute` | 先前路由 |
| `logFieldPrivacyAccepted` | 隐私协议 |
| `logFieldProcessImportance` | 进程重要性 |
| `logFieldProfileId` | 课表配置 ID |
| `logFieldReason` | 原因 |
| `logFieldRequested` | 请求数量 |
| `logFieldRoute` | 路由 |
| `logFieldSdkInt` | SDK 版本 |
| `logFieldSnapshotLength` | 快照长度 |
| `logFieldSource` | 来源 |
| `logFieldStage` | 阶段 |
| `logFieldStartAtMillis` | 开始时间 |
| `logFieldState` | 状态 |
| `logFieldStep` | 步骤 |
| `logFieldStoredSnapshotVersion` | 存储快照版本 |
| `logFieldTarget` | 目标 |
| `logFieldTaskRemovedRecently` | 近期任务被移除 |
| `logFieldThrowable` | 异常 |
| `logFieldTruncated` | 已截断 |
| `logFieldTruncatedHint` | 截断提示 |
| `logFieldUntilMillis` | 暂停截止时间 |
| `logFieldValue` | 值 |
| `logFieldVersion` | 版本 |
| `logFieldVersionName` | 版本名 |
| `logFieldWeekday` | 星期 |
| `logHomeWidgetClearFailed` | 清空桌面小组件快照失败 |
| `logHomeWidgetPinRequestFailed` | 请求固定桌面小组件失败 |
| `logHomeWidgetPinSupportFailed` | 检查桌面小组件固定支持失败 |
| `logHomeWidgetScheduleFailed` | 调度桌面小组件刷新失败 |
| `logHomeWidgetSyncFailed` | 同步桌面小组件快照失败 |
| `logLanEditAuthFailed` | 局域网编辑：认证失败 |
| `logLanEditCourseCreated` | 局域网编辑：已创建课程 |
| `logLanEditCourseDeleted` | 局域网编辑：已删除课程 |
| `logLanEditCourseGroupSaved` | 局域网编辑：已保存课程组 |
| `logLanEditCourseUpdated` | 局域网编辑：已更新课程 |
| `logLanEditCoursesBatchDeleted` | 局域网编辑：已批量删除课程 |
| `logLanEditCurrentWeekSet` | 局域网编辑：已设置当前周次 |
| `logLanEditMergeImported` | 局域网编辑：已导入合并备份 |
| `logLanEditProfileSwitched` | 局域网编辑：已切换课表 |
| `logLanEditSessionStarted` | 局域网编辑：会话已启动 |
| `logLanEditSessionStopped` | 局域网编辑：会话已停止 |
| `logLanEditSpreadsheetImported` | 局域网编辑：已导入表格 |
| `logLiveUpdateDebugStatusFailed` | 获取原生超级岛调试状态失败 |
| `logLiveUpdateSettingsSynced` | Flutter 超级岛设置已同步：课前={beforeClass}，课中={duringClass}，下课前={beforeEnd}，提升={promote}，通知={notification}，倒计时={countdown}，课程名={courseName}，地点={location} |
| `logLiveUpdateSnapshotClearFailed` | 清空超级岛课表快照失败 |
| `logLiveUpdateSnapshotSyncFailed` | 同步超级岛课表快照失败 |
| `logLiveUpdateStartFailed` | 从 Flutter 启动超级岛失败 |
| `logLiveUpdateStopFailed` | 从 Flutter 停止超级岛失败 |
| `logLiveUpdateSuspendTriggersFailed` | 挂起超级岛课表调度失败 |
| `logLiveUpdateTestFailed` | 手动超级岛测试：原生超级岛出现前失败 |
| `logLiveUpdateTestNoSelection` | 手动超级岛测试：未找到可用课程 |
| `logLiveUpdateTestRequested` | 用户请求手动超级岛测试通知 |
| `logLiveUpdateTestSelectionReady` | 手动超级岛测试：已解析目标课程 |
| `logLiveUpdateTestStarted` | 手动超级岛测试：已成功请求原生超级岛 |
| `logLiveUpdateTestStarting` | 手动超级岛测试：正在启动原生超级岛 |
| `logLiveUpdateTestSuspendSync` | 手动超级岛测试：已临时暂停定时同步 |
| `logMiuiLiveHideFromRecentsFailed` | 更新「从最近任务隐藏」失败 |
| `logMiuiLiveInitializeFailed` | 初始化 MIUI 超级岛通道失败 |
| `logMiuiLiveOpenAccessibilitySettingsFailed` | 打开无障碍设置失败 |
| `logMiuiLiveOpenAutostartSettingsFailed` | 打开自启动设置失败 |
| `logMiuiLiveOpenBatterySettingsFailed` | 打开电池优化设置失败 |
| `logMiuiLiveOpenNotificationSettingsFailed` | 打开通知设置失败 |
| `logMiuiLiveOpenPromotedSettingsFailed` | 打开超级岛权限设置失败 |
| `logNavigatorRouteChanged` | 导航路由已变更 |
| `logNavigatorRouteReplaced` | 导航路由已替换 |
| `logPrivacyConsentUpdated` | 隐私协议同意状态已更新 |
| `logStartupFlowCompletedAfterGuide` | 启动流程已完成（经过引导页） |
| `logStartupFlowCompletedNoOnboarding` | 启动流程已完成（无需引导页） |
| `logStartupFlowFailed` | 启动流程失败，进入降级模式 |
| `logStartupFlowStarted` | 启动流程处理已开始 |
| `logTimetableLoadCoursesFailed` | 加载课程数据失败 |
| `logTimetableLoadCurrentWeekFailed` | 加载当前周次失败 |
| `logTimetableLoadSettingsFailed` | 加载课表设置失败 |
| `lowerByValue` | 更矮 {value} |
| `macroReplayAcceleratedFallbackTip` | 快捷路径失败，正在使用完整录制步骤重试… |
| `macroReplayClickNotFound` | 未找到点击元素: {selector} |
| `macroReplayEmptyClickSelector` | 点击元素的选择器为空 |
| `macroReplayEmptyFillSelector` | 填充字段的选择器为空 |
| `macroReplayEmptyNavigateUrl` | 导航 URL 为空 |
| `macroReplayEmptyWaitSelector` | 等待元素的选择器为空 |
| `macroReplayFieldNotFound` | 未找到表单字段: {selector} |
| `macroReplayInvalidUrl` | 无效的 URL: {url} |
| `macroReplayManualActionRequired` | 需要手动操作 |
| `macroReplayNavigateTo` | 导航到 {url} |
| `macroReplayNoSteps` | 没有录制的步骤 |
| `macroReplayStatusFailed` | 失败: {error} |
| `macroReplayStatusPaused` | 等待手动操作: {reason} |
| `macroReplayStepClicking` | 正在点击... |
| `macroReplayStepDelay` | 等待中... |
| `macroReplayStepExecuteScript` | 正在执行导入脚本... |
| `macroReplayStepFailed` | 第 {current}/{total} 步失败: {error} |
| `macroReplayStepFilling` | 正在填充表单... |
| `macroReplayStepNavigating` | 正在导航... |
| `macroReplayStepWaitManual` | 等待用户操作 |
| `macroReplayStepWaitSelector` | 等待页面元素... |
| `macroReplayStepWaitUrl` | 等待页面跳转... |
| `macroReplayUserCancelled` | 用户取消 |
| `macroReplayWaitDomReady` | 等待 DOM 就绪 |
| `macroReplayWaitPageLoad` | 等待页面加载 |
| `macroReplayWaitSelector` | 等待元素: {selector} |
| `macroReplayWaitUrlPattern` | 等待 URL 匹配: {pattern} |
| `miuiIslandExpandedIconAppIcon` | 应用图标 |
| `miuiIslandExpandedIconCustomImage` | 自定义图片 |
| `miuiIslandExpandedIconHidden` | 不显示 |
| `miuiIslandLabelContentCourseName` | 课程名 |
| `miuiIslandLabelContentCourseNameAndLocation` | 课程名+教室 |
| `miuiIslandLabelContentLocation` | 教室 |
| `miuiIslandLabelFontWeightBold` | 加粗 |
| `miuiIslandLabelFontWeightMedium` | 中等 |
| `miuiIslandLabelFontWeightRegular` | 常规 |
| `miuiIslandLabelRenderQualityHigh` | 高清 |
| `miuiIslandLabelRenderQualityStandard` | 标准 |
| `miuiIslandLabelRenderQualityUltra` | 超高清 |
| `miuiIslandLabelStyleIconAndText` | 图标+文字 |
| `miuiIslandLabelStyleTextOnly` | 仅文字 |
| `moreActionsTooltip` | 更多操作 |
| `moreTooltip` | 更多 |
| `noLabel` | 否 |
| `noMatchingSchools` | 没有找到匹配的学校 |
| `nonCurrentWeekLabel` | 非本周 |
| `pasteAction` | 粘贴 |
| `platformLabel` | 平台 |
| `profileTimeSchemeName` | {profileName} 时间 |
| `qrTransferReceiveSpeed` | 接收速度 |
| `qrTransferSelectCoursesDone` | 完成 |
| `quickGenerateAction` | 快捷生成 |
| `quickImportCancelPlaybackAction` | 取消 |
| `quickImportDismissAction` | 完成 |
| `quickImportMacroSteps` | {adapterName} · {stepCount} 步 |
| `recentSchoolLabel` | 最近使用 |
| `saturationLabel` | 饱和度 {value}% |
| `saveAction` | 保存 |
| `savingAction` | 保存中… |
| `scheduleBadgeLabel` | 日程 |
| `scheduleDateLabel` | 日期 |
| `scheduleReminderOff` | 不提醒 |
| `scheduleRepeatDaily` | 每天 |
| `scheduleUpdatedHint` | 日程已更新 |
| `schoolLabel` | 学校 |
| `sectionTimeDisplayHidden` | 不显示 |
| `sectionTimeDisplayStartAndEnd` | 显示上下课时间 |
| `sectionTimeDisplayStartOnly` | 仅显示上课时间 |
| `semesterWeekCountAction` | {count} 周 |
| `sortAction` | 排序 |
| `stableOnly` | 正式版 |
| `statisticsAchievementDetailConfirm` | 知道了 |
| `statisticsAchievementExplorerName` | 教室探索家 |
| `statisticsAchievementsTitle` | 成就徽章 |
| `statisticsMoreTitle` | 深度分析 |
| `statisticsSemesterProgressAsOf` | 今天 {date} |
| `statisticsShareText` | 来自轻屿课表的学期统计 |
| `statisticsStoryBusiestDayTitle` | 最忙的一天 |
| `statisticsStoryFavoriteRoomTitle` | 最常去的教室 |
| `statisticsVenueTopRooms` | 常去教室 |
| `statisticsVenueVisits` | {count} 次 |
| `statisticsWeekBusiestDay` | 最忙的一天 |
| `stepLabel` | 步骤 {step} |
| `supportConfirmedShort` | 已支持 |
| `supportSaveShort` | 保存 |
| `suspendedBadgeLabel` | 停 |
| `switchAction` | 切换 |
| `syncedCurrentWeekMessage` | 已同步到第 {week} 周 |
| `taskAllFilter` | 全部 |
| `taskCompletedSection` | 已完成 |
| `taskDueDateLabel` | 截止日期 |
| `taskOverdueSection` | 已逾期 |
| `taskTodayFilter` | 今日 |
| `teacherUnset` | 未置 |
| `themeDuplicateCopyName` | {name} 副本 |
| `themeModeDark` | 深色模式 |
| `themeMoreActions` | 更多操作 |
| `themePresetPurple` | 暗夜紫 |
| `timeSchemeImportSupplementName` | {name}（导入补齐） |
| `timeSchemeNameHint` | 例如：本校夏季作息 |
| `timeSchemeSetCountValue` | {count} 套 |
| `timeSchemeStartsAt` | {start} 起 |
| `timetableCourseSpacingNarrow` | 窄 |
| `timetableCourseSpacingWide` | 宽 |
| `timetableNameHint` | 例如：大二下 |
| `timetablePageSectionBackground` | 背景 |
| `timetablePageSectionDensity` | 密度 |
| `timetableTimeColumnWidthNarrow` | 窄 |
| `timetableTimeColumnWidthWide` | 宽 |
| `unnamedTimetableProfile` | 未命名课表 |
| `unsetConfigLabel` | 未配置 |
| `updateLabel` | 更新 |
| `usingNow` | 正在使用 |
| `versionLabel` | 版本 {version} |
| `viewDetailsAction` | 查看详情 |
| `wallpaperPositionPickerDone` | 完成 |
| `wallpaperPositionPickerExit` | 退出 |
| `wechatLabel` | 微信 |
| `weekCountItem` | {count} 周 |
| `weekLabel` | 第 {week} 周 |
| `weekdayFieldLabel` | 星期 |
| `weekdayFri` | 周五 |
| `weekdayLabel` | 星期 |
| `weekdayMon` | 周一 |
| `weekdaySat` | 周六 |
| `weekdayShortFriday` | 五 |
| `weekdayShortMonday` | 一 |
| `weekdayShortSaturday` | 六 |
| `weekdayShortSunday` | 日 |
| `weekdayShortThursday` | 四 |
| `weekdayShortTuesday` | 二 |
| `weekdayShortWednesday` | 三 |
| `weekdaySun` | 周日 |
| `weekdayThu` | 周四 |
| `weekdayTue` | 周二 |
| `weekdayWed` | 周三 |
| `weeklyReportNextFire` | 下次推送 {date} {time} |
| `widgetBackgroundStyleGlass` | 半透明玻璃感 |
| `yesLabel` | 是 |

## zh_HK 待繁化（267 条）

| key | 简体文案（= 当前繁体文案） |
|---|---|
| `aboutAlreadyLatestHeadline` | 已是最新版本 |
| `aboutLatestVersionLabel` | 最新版本 |
| `aboutUnavailable` | 不可用 |
| `aboutUpdateAvailableHeadline` | 有版本更新 |
| `aboutUpdateNowTitle` | 立即更新 |
| `aboutUpdateScreenTitle` | 版本更新 |
| `aboutUpdatesTitle` | 版本更新 |
| `aboutVersionChannelLabel` | 版本通道 |
| `aboutViewReleaseAction` | 查看 Release |
| `addMethodTitle` | 添加方式 |
| `aiPasteJsonHintShort` | 粘贴 AI 返回的 JSON |
| `aiPasteJsonTitle` | 粘贴 AI 返回的 JSON |
| `allWeeksFilter` | 全部 |
| `allWeeksLabel` | 全部 |
| `appUpdateDownloadSourceOriginal` | GitHub 原版 |
| `availableWeeksCount` | 共 {count} 周 |
| `backToTodayAction` | 回到今天 |
| `beforeEndSecondsOption` | {seconds} 秒 |
| `breakDurationMinutesLabel` | 休息多久(分) |
| `brightnessLabel` | 明度 {value}% |
| `cancelAction` | 取消 |
| `classAlarmLeadTitle` | 提前量 |
| `clearAction` | 清空 |
| `clearSearchTooltip` | 清空 |
| `cloudBackupMaxAgeOption` | {days} 天 |
| `cloudBackupMaxCountOption` | {count} 份 |
| `cloudSyncEntrySyncing` | 同步中 |
| `cloudSyncLastSyncedAt` | 上次同步：{time} |
| `cloudSyncLastSyncedLabel` | 上次同步 |
| `cloudSyncModeTitle` | 同步方式 |
| `cloudSyncResultCancelled` | 已取消同步 |
| `cloudSyncSyncNow` | 立即同步 |
| `cloudSyncSyncing` | 正在同步… |
| `colorGroupDeep` | 深色系 |
| `colorGroupDopamine` | 多巴胺系 |
| `colorGroupOcean` | 海洋系 |
| `colorGroupSunset` | 落日系 |
| `coupleTimetableSharedFreeMeta` | 共 {count} 段 |
| `coupleWebdavLastPulledAt` | 上次拉取：{time} |
| `coupleWebdavSlotOne` | 槽位 1 |
| `coupleWebdavSlotTwo` | 槽位 2 |
| `courseCardHorizontalAlignCenter` | 居中 |
| `courseCardHorizontalAlignLeft` | 居左 |
| `courseCardHorizontalAlignRight` | 居右 |
| `courseCardSurfaceStyleGaussian` | 高斯模糊 |
| `courseCardVerticalAlignCenter` | 垂直居中 |
| `courseCardVerticalAlignSpaceEvenly` | 上下均布 |
| `courseImportWeekNotProvided` | 未提供周次 |
| `courseNatureRequired` | 必修 |
| `courseNoteDoneEditingAction` | 完成 |
| `courseRecolorNext` | 下一套 |
| `courseRecolorPrevious` | 上一套 |
| `courseRecolorSchemePosition` | 第 {index}/{total} 套 |
| `courseWeekCustomDescription` | 第{weeks}周 |
| `courseWeekListLabel` | 第{weeks}周 |
| `courseWeekRangeDescription` | 第{startWeek}-{endWeek}周{mode} |
| `courseWeekRangeLabel` | 第{startWeek}-{endWeek}周{mode} |
| `crossDayBadgeLabel` | 跨日 |
| `currentWeekCompact` | {week}周 |
| `dailyUsageSectionTitle` | 日常使用 |
| `debugScriptLength` | 脚本 {count} 字符 |
| `diagnosticsLevelAll` | 全部 |
| `diagnosticsLevelWarn` | 警告 |
| `diagnosticsMessage` | 消息 |
| `diagnosticsRawTab` | 原文 |
| `diagnosticsTimeSortAscending` | 正序 |
| `diagnosticsTimeSortDescending` | 倒序 |
| `examCountdownToday` | 今天 |
| `examOverviewUntilTime` | 至 {time} |
| `examReminderAddCustom` | 添加提醒 |
| `examReminderDay1` | 考前 1 天 |
| `examReminderNone` | 不提醒 |
| `examReminderOffsetDays` | 考前 {days} 天 |
| `examReminderPickerDays` | 天 |
| `feedbackCoolapkTitle` | 酷安 |
| `feedbackQqGroupTitle` | QQ 群 |
| `foruiThemeNeutral` | 中性灰 |
| `foruiThemeOrange` | 橙 |
| `foruiThemeSlate` | 石板灰 |
| `foruiThemeViolet` | 紫 |
| `frostedGlassModeGaussian` | 高斯模糊 |
| `frostedGlassModeLabel` | 玻璃模式 |
| `frostedGlassModeTranslucent` | 半透明 |
| `frostedSheetSectionTitle` | 磨砂玻璃 |
| `frostedSheetTintLabel` | 磨砂亮度 |
| `generateAction` | 生成 |
| `goAction` | 前往 |
| `goToWeekLabel` | 第 {week} 周 |
| `gotItAction` | 知道了 |
| `guideChipReadyCount` | {count}/3 已完成 |
| `guideNextButton` | 下一步 |
| `guidePrevButton` | 上一步 |
| `guideStatusAndroidVersion` | Android 版本 |
| `guideStatusBatteryRestricted` | 仍受限制 |
| `guideStatusIslandSystemRequirement` | 需 HyperOS 3.0.300 及以上 |
| `guideTipsHeader` | 使用技巧 |
| `guideTipsPageTitle` | 使用技巧 |
| `higherByValue` | 更高 {value} |
| `holidayDataYear` | 年份 |
| `holidayDateDiffMonth` | {startMonth}月{startDay}日 - {endMonth}月{endDay}日 |
| `holidayDateSameDay` | {month}月{day}日 |
| `holidayDateSameMonth` | {month}月{start}日 - {end}日 |
| `holidayNameNewYear` | 元旦 |
| `holidayStatusLabel` | 假期 |
| `homeGridEditorRemoveTooltip` | 移除 |
| `homeMenuCategoryFeatures` | 功能入口 |
| `homePageBackgroundFillLabel` | 背景填充 |
| `homeTitleStyleBrandLabel` | 大 Logo |
| `homeWidgetQuickAddTitle` | 快速添加到桌面 |
| `homeWidgetTargetCompact22` | 主卡 2×2 |
| `hueLabel` | 色相 {value} |
| `hyperosShowcaseActionButton` | 操作按钮 |
| `hyperosShowcaseAlreadyInSubpage` | 已在 Subpage 中 |
| `hyperosShowcaseMenuShare` | 分享 |
| `hyperosShowcaseRefreshDone` | 刷新完成 |
| `hyperosShowcaseSampleText` | 示例文本 |
| `hyperosShowcaseSearchTooltip` | 搜索 |
| `hyperosShowcaseSectionControls` | 控件卡片 |
| `hyperosShowcaseSectionSummary` | 概要卡片 |
| `hyperosShowcaseSegmentLeft` | 左 |
| `hyperosShowcaseSegmentRight` | 右 |
| `hyperosShowcaseSizeLarge` | 大 |
| `hyperosShowcaseSizeMedium` | 中 |
| `hyperosShowcaseSizeSmall` | 小 |
| `icsExportSchedules` | 日程 |
| `lanEditConnectedClientsValue` | {count} 台 |
| `lanEditStop` | 停止 |
| `layoutHorizontalAlignLabel` | 水平排版 |
| `layoutVerticalAlignLabel` | 垂直排版 |
| `liquidGlassChromaticAberrationLabel` | 色差 |
| `liquidGlassLightAngleLabel` | 光照角度 |
| `liquidGlassPresetClear` | 清澈 |
| `liquidGlassRefractiveIndexLabel` | 折射率 |
| `liquidGlassThicknessLabel` | 厚度 |
| `liveCountdownTextStyleSmart` | 智能（中文） |
| `liveCountdownTextStyleSmartMinS` | 智能（英文） |
| `liveDisplayConfigModeTitle` | 配置方式 |
| `liveDisplayModeTitle` | 展示方式 |
| `liveGroupReminders` | 提醒 |
| `liveIslandPreviewSampleLocation` | 三教-401 |
| `liveTestingClearingLogs` | 清空中 |
| `liveTestingNotRefreshed` | 尚未刷新 |
| `liveTestingRefreshedAt` | 上次刷新：{time} |
| `liveTestingRefreshing` | 刷新中 |
| `locationTimeMatchAddBuilding` | 添加 |
| `locationTimeMatchApplyConfirm` | 重新匹配 |
| `locationTimeMatchApplyOverflowHint` | 未套用示例：{names} |
| `locationTimeMatchKeywordHint` | A1 / A主 / 六教 |
| `locationTimeMatchModeContains` | 包含 |
| `locationTimeMatchModeLabel` | 匹配模式 |
| `locationTimeMatchModePrefix` | 前缀 |
| `locationTimeMatchPreviewHint` | 例如 A1062 或 A主201 |
| `locationUnset` | 未置 |
| `logCatRoutePopped` | 路由：出栈 |
| `logCatRoutePushed` | 路由：入栈 |
| `logFieldAccepted` | 已同意 |
| `logFieldAction` | 操作 |
| `logFieldBrand` | 品牌 |
| `logFieldChannel` | 渠道 |
| `logFieldExtras` | 附加信息 |
| `logFieldManufacturer` | 制造商 |
| `logFieldPlatform` | 平台 |
| `logFieldPort` | 端口 |
| `logFieldPreviousRoute` | 先前路由 |
| `logFieldReason` | 原因 |
| `logFieldRoute` | 路由 |
| `logFieldSdkInt` | SDK 版本 |
| `logFieldValue` | 值 |
| `logFieldVersion` | 版本 |
| `logFieldVersionName` | 版本名 |
| `logFieldWeekday` | 星期 |
| `lowerByValue` | 更矮 {value} |
| `macroReplayStepDelay` | 等待中... |
| `macroReplayWaitSelector` | 等待元素: {selector} |
| `macroReplayWaitUrlPattern` | 等待 URL 匹配: {pattern} |
| `miuiIslandLabelContentLocation` | 教室 |
| `miuiIslandLabelFontWeightBold` | 加粗 |
| `miuiIslandLabelFontWeightMedium` | 中等 |
| `miuiIslandLabelRenderQualityHigh` | 高清 |
| `miuiIslandLabelRenderQualityUltra` | 超高清 |
| `moreActionsTooltip` | 更多操作 |
| `moreTooltip` | 更多 |
| `noLabel` | 否 |
| `nonCurrentWeekLabel` | 非本周 |
| `pasteAction` | 粘贴 |
| `platformLabel` | 平台 |
| `qrTransferReceiveSpeed` | 接收速度 |
| `qrTransferSelectCoursesDone` | 完成 |
| `quickGenerateAction` | 快捷生成 |
| `quickImportCancelPlaybackAction` | 取消 |
| `quickImportDismissAction` | 完成 |
| `quickImportMacroSteps` | {adapterName} · {stepCount} 步 |
| `recentSchoolLabel` | 最近使用 |
| `saturationLabel` | 饱和度 {value}% |
| `saveAction` | 保存 |
| `savingAction` | 保存中… |
| `scheduleBadgeLabel` | 日程 |
| `scheduleDateLabel` | 日期 |
| `scheduleReminderOff` | 不提醒 |
| `scheduleReminderSectionTitle` | 日程提醒 |
| `scheduleRepeatDaily` | 每天 |
| `scheduleUpdatedHint` | 日程已更新 |
| `semesterWeekCountAction` | {count} 周 |
| `sortAction` | 排序 |
| `stableOnly` | 正式版 |
| `statisticsAchievementDetailConfirm` | 知道了 |
| `statisticsAchievementExplorerName` | 教室探索家 |
| `statisticsAchievementsTitle` | 成就徽章 |
| `statisticsMoreTitle` | 深度分析 |
| `statisticsSemesterProgressAsOf` | 今天 {date} |
| `statisticsStoryBusiestDayTitle` | 最忙的一天 |
| `statisticsStoryFavoriteRoomTitle` | 最常去的教室 |
| `statisticsVenueTopRooms` | 常去教室 |
| `statisticsVenueVisits` | {count} 次 |
| `statisticsWeekBusiestDay` | 最忙的一天 |
| `supportConfirmedShort` | 已支持 |
| `supportSaveShort` | 保存 |
| `suspendedBadgeLabel` | 停 |
| `syncedCurrentWeekMessage` | 已同步到第 {week} 周 |
| `taskAllFilter` | 全部 |
| `taskCompletedSection` | 已完成 |
| `taskDueDateLabel` | 截止日期 |
| `taskOverdueSection` | 已逾期 |
| `taskTodayFilter` | 今日 |
| `teacherUnset` | 未置 |
| `themeDuplicateCopyName` | {name} 副本 |
| `themeModeDark` | 深色模式 |
| `themeMoreActions` | 更多操作 |
| `themePresetPurple` | 暗夜紫 |
| `timeSchemeNameHint` | 例如：本校夏季作息 |
| `timeSchemeSetCountValue` | {count} 套 |
| `timeSchemeStartsAt` | {start} 起 |
| `timetableCourseSpacingNarrow` | 窄 |
| `timetableCourseSpacingWide` | 宽 |
| `timetableNameHint` | 例如：大二下 |
| `timetablePageSectionBackground` | 背景 |
| `timetablePageSectionDensity` | 密度 |
| `timetableTimeColumnWidthNarrow` | 窄 |
| `timetableTimeColumnWidthWide` | 宽 |
| `unsetConfigLabel` | 未配置 |
| `updateLabel` | 更新 |
| `usingNow` | 正在使用 |
| `versionLabel` | 版本 {version} |
| `wallpaperPositionPickerDone` | 完成 |
| `wallpaperPositionPickerExit` | 退出 |
| `wechatLabel` | 微信 |
| `weekCountItem` | {count} 周 |
| `weekLabel` | 第 {week} 周 |
| `weekdayFieldLabel` | 星期 |
| `weekdayFri` | 周五 |
| `weekdayLabel` | 星期 |
| `weekdayMon` | 周一 |
| `weekdaySat` | 周六 |
| `weekdayShortFriday` | 五 |
| `weekdayShortMonday` | 一 |
| `weekdayShortSaturday` | 六 |
| `weekdayShortSunday` | 日 |
| `weekdayShortThursday` | 四 |
| `weekdayShortTuesday` | 二 |
| `weekdayShortWednesday` | 三 |
| `weekdaySun` | 周日 |
| `weekdayThu` | 周四 |
| `weekdayTue` | 周二 |
| `weekdayWed` | 周三 |
| `weeklyReportNextFire` | 下次推送 {date} {time} |
| `widgetBackgroundStyleGlass` | 半透明玻璃感 |
| `yesLabel` | 是 |
