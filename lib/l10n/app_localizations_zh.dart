// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => '轻屿课表';

  @override
  String get appTitleDebug => '轻屿课表调试版';

  @override
  String get appTitleProfile => '轻屿课表性能版';

  @override
  String get appearanceTitle => '外观与配色';

  @override
  String get previewTitle => '预览';

  @override
  String get timetableBackgroundPreview => '课表背景';

  @override
  String get displayModeTitle => '显示模式';

  @override
  String get displayModeSubtitle => '支持跟随系统、浅色模式和深色模式';

  @override
  String get themeModeLabel => '主题模式';

  @override
  String get themeModeSystem => '跟随系统';

  @override
  String get themeModeLight => '浅色模式';

  @override
  String get themeModeDark => '深色模式';

  @override
  String get fontSectionTitle => '应用字体';

  @override
  String get fontSectionSubtitle => '内置 Inter 默认；也可选用系统已安装的字体';

  @override
  String get fontSectionFootnote =>
      '厂商字体未内置，需系统已预装才生效，小米通常只有 MiSans 明显；没变化时会自动回退，一般不必自行安装';

  @override
  String get fontModeLabel => '字体选择';

  @override
  String get fontModeSystem => '应用默认';

  @override
  String get fontModeSansSerif => '系统无衬线';

  @override
  String get fontModeMiSans => 'MiSans';

  @override
  String get fontModeHarmonyOS => '鸿蒙黑体';

  @override
  String get fontModeOppoSans => 'OPPO Sans';

  @override
  String get fontModePingFang => '苹方';

  @override
  String get fontModeNotoSans => 'Noto Sans';

  @override
  String get fontModeSerif => '衬线体';

  @override
  String get fontModeSongti => '宋体';

  @override
  String get fontModeMonospace => '等宽体';

  @override
  String get languageSectionTitle => '应用语言';

  @override
  String get languageSectionSubtitle => '可跟随系统，或手动切换到已适配语言';

  @override
  String get languageModeLabel => '语言选择';

  @override
  String get languageModeSystem => '跟随系统';

  @override
  String get settingsTitle => '课表设置';

  @override
  String get dailyUsageSectionTitle => '日常使用';

  @override
  String get appearanceEntryTitle => '外观与配色';

  @override
  String get appearanceEntrySubtitle => '主题模式、字体、首页标题与弹窗磨砂玻璃';

  @override
  String get appearanceThemeDisplaySectionTitle => '主题与显示';

  @override
  String get layoutSectionEntryTitle => '布局与节次';

  @override
  String get layoutSectionEntrySubtitle => '节次时间、行高、时间列、周末显示与卡片布局';

  @override
  String get homeWidgetEntryTitle => '桌面小组件';

  @override
  String get homeWidgetEntrySubtitle => '今日课程卡片、小组件背景与显示信息';

  @override
  String get reminderNotificationSectionTitle => '提醒与通知';

  @override
  String get userGuideEntryTitle => '使用引导与权限';

  @override
  String get userGuideEntrySubtitle => '简称建议、通知、自启动、电池策略';

  @override
  String get timetableManagementSectionTitle => '课表管理';

  @override
  String get timeSchemeEntryTitle => '时间模板';

  @override
  String get timeSchemeEntrySubtitleNoneSelected => '切换、编辑节次、复制和管理时间模板';

  @override
  String get timeSchemeEntryNotSelected => '未选择';

  @override
  String timeSchemeEntrySubtitleSelected(String name) {
    return '当前：$name · 切换、编辑节次和复制';
  }

  @override
  String get dataTransferEntryTitle => '数据备份与迁移';

  @override
  String get dataTransferEntrySubtitle => '导出完整课表文件，给别人直接导入使用';

  @override
  String get coupleTimetableEntryTitle => '情侣课表';

  @override
  String get coupleTimetableEntryBound => '已绑定';

  @override
  String get coupleTimetableModeEnableTooltip => '开启情侣课表';

  @override
  String get coupleTimetableModeDisableTooltip => '关闭情侣课表';

  @override
  String get coupleTimetableTitle => '情侣课表';

  @override
  String get coupleTimetableIntro =>
      '导出你的课表发给 TA，或导入 TA 分享的课表文件，导入后可在叠加视图中查看双方课程';

  @override
  String get coupleTimetableBoundTitle => '已绑定对方课表';

  @override
  String get coupleTimetableUnboundTitle => '尚未绑定对方课表';

  @override
  String get coupleTimetablePartnerNameLabel => '对方名称';

  @override
  String coupleTimetableLastImportedAt(String time) {
    return '上次导入：$time';
  }

  @override
  String get coupleTimetableExportForPartner => '导出我的课表给对方';

  @override
  String get coupleTimetableImportPartner => '导入对方课表';

  @override
  String get coupleTimetableUnlink => '解除绑定';

  @override
  String get coupleTimetableOpenOverlay => '进入叠加视图';

  @override
  String get coupleTimetableImportSuccess => '已导入对方课表';

  @override
  String get coupleTimetableImportUpdated => '已更新对方课表';

  @override
  String get coupleTimetableUnlinkConfirmTitle => '解除情侣课表绑定？';

  @override
  String get coupleTimetableUnlinkConfirmMessage => '解除后将删除本地保存的对方课表，叠加视图也会关闭';

  @override
  String get coupleTimetableUnlinkSuccess => '已解除绑定';

  @override
  String get coupleTimetablePrivacyHint => '对方只能看到你导出文件中包含的课表内容';

  @override
  String get coupleTimetableOverlayTitle => '情侣叠加';

  @override
  String get coupleTimetableLegendMine => '我的课';

  @override
  String get coupleTimetableLegendPartner => 'TA的课';

  @override
  String get coupleTimetableLegendTogether => '一起上课';

  @override
  String get coupleTimetableLegendFree => '共同空闲';

  @override
  String get coupleTimetableSharedFreeTitle => '今日共同空闲';

  @override
  String get coupleTimetableSharedFreeTitleOtherDay => '该日共同空闲';

  @override
  String get coupleTimetableNoSharedFree => '今天没有共同空闲时段';

  @override
  String get coupleTimetableNoSharedFreeOtherDay => '该日没有共同空闲时段';

  @override
  String coupleTimetableSharedFreeMeta(int count) {
    return '共 $count 段';
  }

  @override
  String coupleTimetableSharedFreeMoreCount(int count) {
    return '还有 $count 段';
  }

  @override
  String get coupleTimetableSharedFreeUnavailable => '暂时算不出共同空闲';

  @override
  String get coupleTimetableSharedFreeStaleHint => '对方课表可能不是最新';

  @override
  String get coupleTimetablePartnerReadOnlyBadge => '对方课表（只读）';

  @override
  String get coupleTimetableNotBoundMessage => '请先导入对方课表后再查看叠加视图';

  @override
  String get coupleTimetableShareText => '这是我的课表，导入到轻屿课表的情侣课表即可一起查看';

  @override
  String get coupleTimetableShareSubject => '轻屿课表 · 情侣课表分享';

  @override
  String get coupleTimetableWeekOffsetTitle => '周次偏移';

  @override
  String get coupleTimetableWeekOffsetSubtitle =>
      '查看你的第 N 周时，读取对方课表的第 N+偏移 周，例如 +1 表示对方学期进度比你快一周';

  @override
  String get coupleTimetableWeekOffsetZero => '无偏移';

  @override
  String coupleTimetableWeekOffsetSigned(String offset) {
    return '$offset 周';
  }

  @override
  String coupleTimetableWeekOffsetPreview(int myWeek, int partnerWeek) {
    return '查看你的第 $myWeek 周时，显示对方第 $partnerWeek 周的课';
  }

  @override
  String get coupleTimetableColorsTitle => '叠加颜色';

  @override
  String get coupleTimetableColorsSubtitle =>
      '自定义「我的课」「TA的课」「一起上课」在叠加视图中的显示颜色，可按喜好自由搭配';

  @override
  String get partnerImportRequiresSingleProfile => '请导入单课表备份文件，不支持全量备份';

  @override
  String get coupleWebdavTitle => '坚果云拉取';

  @override
  String get coupleWebdavSubtitle =>
      '登录对方（或你们共用的）坚果云账号，自动下载对方上传的课表文件，与「云同步」账号独立，互不影响';

  @override
  String get coupleWebdavNotConnected => '尚未连接坚果云';

  @override
  String coupleWebdavConnectedAs(String username) {
    return '已连接：$username';
  }

  @override
  String coupleWebdavRemotePathHint(String path) {
    return '远程文件路径：$path';
  }

  @override
  String coupleWebdavLastPulledAt(String time) {
    return '上次拉取：$time';
  }

  @override
  String get coupleWebdavConnect => '连接坚果云';

  @override
  String get coupleWebdavDisconnect => '断开连接';

  @override
  String get coupleWebdavPullNow => '立即拉取对方课表';

  @override
  String get coupleWebdavUploadForPartner => '上传我的课表到坚果云';

  @override
  String get coupleWebdavLoginSheetTitle => '连接坚果云（情侣课表）';

  @override
  String get coupleWebdavLoginSheetSubtitle =>
      '请使用应用专用密码，对方需先将课表上传到约定路径，或由你在对方设备上登录同一账号并上传';

  @override
  String get coupleWebdavConfirmConnect => '连接并拉取';

  @override
  String get coupleWebdavMySlotLabel => '本机槽位';

  @override
  String get coupleWebdavMySlotHint => '双方必须选不同槽位：一方选 1，另一方选 2，否则会互相读不到课表';

  @override
  String get coupleWebdavSlotOne => '槽位 1';

  @override
  String get coupleWebdavSlotTwo => '槽位 2';

  @override
  String get coupleWebdavTestSuccess => '坚果云连接成功';

  @override
  String get coupleWebdavTestFailed => '连接失败，请检查账号、应用专用密码与网络';

  @override
  String get coupleWebdavPullImported => '已从坚果云导入对方课表';

  @override
  String get coupleWebdavPullUpdated => '已从坚果云更新对方课表';

  @override
  String get coupleWebdavPullUnchanged => '对方课表无变化';

  @override
  String get coupleWebdavUploadSuccess => '已上传课表，对方可拉取';

  @override
  String get coupleWebdavPartnerFileMissing => '未找到对方课表文件，请让对方先上传';

  @override
  String get coupleWebdavPullFailed => '拉取对方课表失败，请稍后重试';

  @override
  String get coupleWebdavNotConnectedError => '请先连接坚果云';

  @override
  String get cloudSyncEntryTitle => '云同步';

  @override
  String get cloudSyncEntrySubtitle => '通过坚果云等多设备同步课表与导入数据';

  @override
  String get cloudSyncEntryDisabled => '已关闭';

  @override
  String get cloudSyncEntryEnabled => '已开启';

  @override
  String get cloudSyncEntrySyncing => '同步中';

  @override
  String get cloudSyncEntryError => '上次同步失败';

  @override
  String get cloudSyncTitle => '云同步';

  @override
  String get cloudSyncIntroTitle => '多设备同步';

  @override
  String get cloudSyncIntroSubtitle =>
      '配置坚果云 WebDAV 后，可在手机、平板之间自动同步课表、仓库账号与相关设置';

  @override
  String get cloudSyncSettingsSectionTitle => '同步设置';

  @override
  String get cloudSyncSettingsSectionSubtitle => '可切换手动或自动同步';

  @override
  String get cloudSyncEnabledTitle => '启用云同步';

  @override
  String get cloudSyncEnabledSubtitle => '关闭后不会上传或下载云端快照';

  @override
  String get cloudSyncProviderTitle => '服务提供商';

  @override
  String get cloudSyncProviderJianguoyun => '坚果云';

  @override
  String get cloudSyncProviderCustom => '自定义 WebDAV';

  @override
  String get cloudSyncModeTitle => '同步方式';

  @override
  String get cloudSyncModeAuto => '自动同步';

  @override
  String get cloudSyncModeManual => '手动同步';

  @override
  String get cloudSyncAccountTitle => '账号配置';

  @override
  String get cloudSyncAccountSubtitle => '请使用坚果云应用专用密码，而不是登录密码，快照会包含仓库记住的学校账号';

  @override
  String get cloudSyncUsernameLabel => '邮箱 / 用户名';

  @override
  String get cloudSyncUsernameHint => '坚果云注册邮箱';

  @override
  String get cloudSyncPasswordLabel => '应用专用密码';

  @override
  String get cloudSyncPasswordHint => '在坚果云账户安全选项中生成';

  @override
  String get cloudSyncPasswordStoredHint => '已保存密码；留空表示继续使用已保存的密码';

  @override
  String get cloudSyncAdvancedTitle => '高级设置';

  @override
  String get cloudSyncBaseUrlLabel => 'WebDAV 地址';

  @override
  String get cloudSyncBaseUrlSecurityNote =>
      '建议使用 HTTPS 加密连接；HTTP 明文连接仅建议在可信网络环境下使用';

  @override
  String get cloudSyncRemoteFolderLabel => '远程目录';

  @override
  String get cloudSyncStatusTitle => '同步状态';

  @override
  String get cloudSyncLastSyncedLabel => '上次同步';

  @override
  String get cloudSyncLastErrorLabel => '最近错误';

  @override
  String cloudSyncLastSyncedAt(String time) {
    return '上次同步：$time';
  }

  @override
  String get cloudSyncSyncing => '正在同步…';

  @override
  String cloudSyncLastError(String message) {
    return '最近错误：$message';
  }

  @override
  String get cloudSyncHelpTitle => '如何获取坚果云应用密码';

  @override
  String get cloudSyncHelpBody =>
      '打开坚果云网页或客户端 → 账户信息 → 安全选项 → 添加应用密码，WebDAV 地址默认为 https://dav.jianguoyun.com/dav/ ';

  @override
  String get cloudSyncTestConnection => '测试连接';

  @override
  String get cloudSyncSyncNow => '立即同步';

  @override
  String get cloudSyncSyncNowSubtitle => '与其他设备对齐课表：先拉取云端更新，再上传本机修改';

  @override
  String get cloudSyncTestSuccess => 'WebDAV 连接成功';

  @override
  String get cloudSyncTestFailed => 'WebDAV 连接失败，请检查账号、应用密码和网络';

  @override
  String get cloudSyncResultUploaded => '已上传到云端';

  @override
  String get cloudSyncResultDownloaded => '已从云端恢复';

  @override
  String get cloudSyncResultUpToDate => '本地与云端已一致';

  @override
  String get cloudSyncResultCancelled => '已取消同步';

  @override
  String cloudSyncResultFailed(String message) {
    return '同步失败：$message';
  }

  @override
  String get cloudSyncConflictTitle => '检测到同步冲突';

  @override
  String get cloudSyncConflictBody => '本机和云端都有新的修改，请选择保留哪一边的数据';

  @override
  String get cloudSyncUseRemoteAction => '使用云端';

  @override
  String get cloudSyncKeepLocalAction => '保留本机';

  @override
  String get cloudSyncAccountSectionTitle => '云账号';

  @override
  String get cloudSyncNotConnectedHint => '连接坚果云后，可在多设备间同步课表与导入数据';

  @override
  String get cloudSyncConnectAccount => '连接坚果云';

  @override
  String cloudSyncConnectedAs(String email) {
    return '已连接：$email';
  }

  @override
  String get cloudSyncDisconnect => '断开连接';

  @override
  String get cloudSyncDisconnectTitle => '断开云同步账号';

  @override
  String get cloudSyncDisconnectBody =>
      '断开后将清除本机保存的 WebDAV 凭据，课表数据仍保留在本机，是否继续？';

  @override
  String get cloudSyncLoginSheetTitle => '连接坚果云';

  @override
  String get cloudSyncLoginSheetSubtitle => '请使用应用专用密码，不要使用坚果云登录密码';

  @override
  String get cloudSyncConfirmConnect => '确认连接';

  @override
  String get cloudSyncConnectSuccess => '账号连接成功';

  @override
  String get cloudBackupSectionTitle => '可恢复版本';

  @override
  String get cloudBackupSectionSubtitle => '每次同步都会自动保留可恢复版本';

  @override
  String get cloudBackupCurrentLabel => '当前版本';

  @override
  String get cloudBackupCurrentBadge => '当前';

  @override
  String get cloudBackupCreateNow => '立即备份';

  @override
  String get cloudBackupViewAll => '查看全部可恢复版本';

  @override
  String get cloudBackupEmpty => '暂无可恢复版本，同步后会自动生成';

  @override
  String get cloudBackupSourceAuto => '自动备份';

  @override
  String get cloudBackupSourceManual => '手动备份';

  @override
  String get cloudBackupDefaultDeviceLabel => '本机';

  @override
  String get cloudBackupDeviceLabelTitle => '设备名称';

  @override
  String get cloudBackupDeviceLabelHint => '在备份列表中显示，例如「我的手机」';

  @override
  String cloudBackupSummary(int profileCount, int courseCount) {
    return '$profileCount 个课表 · $courseCount 门课程';
  }

  @override
  String get cloudBackupRestoreTitle => '恢复到此备份';

  @override
  String cloudBackupRestoreBody(String time) {
    return '将恢复到 $time 的课表，本地未同步的修改会丢失，是否继续？';
  }

  @override
  String get cloudBackupRestoreAction => '恢复';

  @override
  String get cloudBackupRestoreSuccess => '已恢复到此备份';

  @override
  String cloudBackupRestoreFailed(String message) {
    return '恢复失败：$message';
  }

  @override
  String get cloudBackupDeleteTitle => '删除此备份';

  @override
  String cloudBackupDeleteBody(String time) {
    return '确定删除 $time 的云端备份吗？此操作不可撤销';
  }

  @override
  String get cloudBackupDeleteSuccess => '备份已删除';

  @override
  String cloudBackupDeleteFailed(String message) {
    return '删除失败：$message';
  }

  @override
  String get cloudBackupCreateSuccess => '备份已保存到云端';

  @override
  String cloudBackupCreateFailed(String message) {
    return '备份失败：$message';
  }

  @override
  String get cloudBackupUploadAsCurrentTitle => '设为当前云端版本';

  @override
  String get cloudBackupUploadAsCurrentBody =>
      '是否将此备份设为当前云端版本？建议开启，可避免其他设备同步冲突';

  @override
  String get cloudBackupUploadAsCurrentYes => '设为当前版本';

  @override
  String get cloudBackupUploadAsCurrentNo => '仅恢复本地';

  @override
  String get cloudBackupDetailDevice => '设备';

  @override
  String get cloudBackupDetailSource => '来源';

  @override
  String get cloudBackupDetailSummary => '内容';

  @override
  String get lanEditEntryTitle => '局域网编辑';

  @override
  String get lanEditEntrySubtitle => '在电脑浏览器中编辑当前课表';

  @override
  String get lanEditTitle => '局域网编辑';

  @override
  String get lanEditIntro =>
      '开启后，同一 WiFi 或手机热点下的电脑可通过浏览器编辑当前课表，数据不会上传云端，关闭后即停止访问';

  @override
  String get lanEditStart => '开启局域网编辑';

  @override
  String get lanEditStop => '停止';

  @override
  String get lanEditStatusRunning => '编辑会话进行中';

  @override
  String get lanEditAddressLabel => '访问地址';

  @override
  String get lanEditAddressUnavailable => '未检测到局域网 IP，请确认已连接 WiFi 或已开启热点';

  @override
  String get lanEditPinLabel => 'PIN';

  @override
  String get lanEditPortLabel => '端口';

  @override
  String get lanEditCopyAddress => '复制地址';

  @override
  String get lanEditCopied => '地址已复制';

  @override
  String get lanEditHotspotHint => '如果宿舍 WiFi 无法访问，请尝试用手机开热点，再让电脑连接该热点';

  @override
  String get lanEditQrHint => '电脑浏览器扫描上方二维码可打开控制台（链接已含 PIN，需同一局域网）';

  @override
  String get lanEditStartFailed => '启动失败';

  @override
  String get lanEditConnectedClientsLabel => '已连接';

  @override
  String get lanEditConnectedClientsNone => '暂无';

  @override
  String lanEditConnectedClientsValue(int count) {
    return '$count 台';
  }

  @override
  String get lanEditLastActivityLabel => '最近活动';

  @override
  String get lanEditKeepAliveWhenLeavingTitle => '离开后保持开启';

  @override
  String get lanEditKeepAliveWhenLeavingSubtitle =>
      '开启后，返回设置页不会自动关闭局域网编辑；关闭后离开本页即停止';

  @override
  String get aboutSupportSectionTitle => '关于与支持';

  @override
  String get feedbackEntryTitle => '问题反馈';

  @override
  String get feedbackEntrySubtitle => 'Issue、社区渠道和建议反馈入口';

  @override
  String get aboutEntryTitle => '关于软件';

  @override
  String get aboutEntrySubtitle => '开源说明、版本更新和 GitHub 仓库';

  @override
  String get setSemesterStartDateAction => '设置开学日期';

  @override
  String get semesterStartDateAction => '开学日期';

  @override
  String get syncCurrentWeekAction => '同步当前周';

  @override
  String semesterWeekCountAction(int count) {
    return '$count 周';
  }

  @override
  String get selectSemesterWeekCountTitle => '选择学期周数';

  @override
  String get selectSemesterWeekCountSubtitle => '不同学校可按实际教学周数调整';

  @override
  String get unifiedCourseCardColorTitle => '统一课程卡片颜色';

  @override
  String get unifiedCourseCardColorSubtitle => '关闭后继续使用每门课程自己的颜色';

  @override
  String get importRandomCourseColorTitle => '随机课程颜色';

  @override
  String get importRandomCourseColorSubtitle => '按课程名与教师自动分配预设色';

  @override
  String get importRandomColorGroupTitle => '随机配色组';

  @override
  String get colorGroupAll => '全部颜色';

  @override
  String get colorGroupPastel => '马卡龙系';

  @override
  String get colorGroupVibrant => '活泼系';

  @override
  String get colorGroupDeep => '深色系';

  @override
  String get colorGroupDopamine => '多巴胺系';

  @override
  String get colorGroupSunset => '落日系';

  @override
  String get colorGroupOcean => '海洋系';

  @override
  String get courseRecolorTileTitle => '课表重新配色';

  @override
  String get courseRecolorTileSubtitle => '不用重新导入，随时一键给全部课程换套颜色';

  @override
  String get courseRecolorSheetTitle => '课表重新配色';

  @override
  String get courseRecolorSheetDescription =>
      '每次「换一批」都会给全部课程刷一套随机颜色；不满意可以切回上一套，或回到导入时的原色。';

  @override
  String get courseRecolorNewBatchButton => '换一批颜色';

  @override
  String get courseRecolorPrevious => '上一套';

  @override
  String get courseRecolorNext => '下一套';

  @override
  String courseRecolorSchemePosition(int index, int total) {
    return '第 $index/$total 套';
  }

  @override
  String get courseRecolorNoCoursesToast => '暂无课程，先导入或添加课程再换颜色';

  @override
  String get courseImportTitle => '导入课程';

  @override
  String get chooseImportMethodTitle => '选择导入方式';

  @override
  String get chooseImportMethodSubtitle =>
      '现在支持传统 .ics 日历导入、识图导入，以及从仓库读取适配器的教务系统导入';

  @override
  String get importMethodIcsTitle => '.ics 日历导入';

  @override
  String get importMethodIcsSubtitle => '从其他课表应用导出的日历文件';

  @override
  String get importMethodIcsFooter => '进入后直接选择 .ics 文件，可追加导入或替换现有课程';

  @override
  String get importMethodAiTitle => '识图导入';

  @override
  String get importMethodAiSubtitle => '从课表截图识别并导入';

  @override
  String get importMethodAiFooter =>
      '先复制提示词，再到豆包专家模式发送截图和提示词，把返回的 JSON 复制回来导入，最后选择开学日期';

  @override
  String get importMethodWarehouseTitle => '教务系统导入';

  @override
  String get importMethodWarehouseSubtitle => '登录学校教务系统导入';

  @override
  String get importMethodWarehouseFooter => '进入后选择学校和适配器，可直接打开教务网页登录并执行导入';

  @override
  String get importMethodSpreadsheetTitle => '表格导入';

  @override
  String get importMethodSpreadsheetSubtitle => '填写 Excel / CSV 模板后导入';

  @override
  String get importMethodSpreadsheetFooter =>
      '支持 .csv 与 .xlsx，可下载官方模板填写后选择文件导入';

  @override
  String get spreadsheetImportTitle => '表格导入';

  @override
  String get spreadsheetScenarioIntro =>
      '轻屿模板按表头识别列：必填列为课程名、星期、开始节、结束节及周次；其余列为可选，可下载完整模板，也可只保留必要列，也兼容 WakeUp 7 列格式';

  @override
  String get spreadsheetStep1Subtitle => '下载完整模板填写，或只保留必填列与上课周（或开始周+结束周）做最小导入';

  @override
  String get spreadsheetStep2Subtitle => '填写完成后另存为 .csv 或直接保留 .xlsx';

  @override
  String get spreadsheetStep3Subtitle => '选择文件导入；如有识别提醒会先展示，再选择追加或替换';

  @override
  String get spreadsheetSupportedFilesSuffix => '支持 .csv 与 .xlsx（仅读取第一个工作表）';

  @override
  String get chooseSpreadsheetFileAction => '选择表格文件';

  @override
  String get downloadSpreadsheetTemplateAction => '下载轻屿课表模板';

  @override
  String get spreadsheetImportWarningsTitle => '导入提醒';

  @override
  String get spreadsheetImportWarningsMessage => '以下行未能导入，其余课程可继续：';

  @override
  String get spreadsheetImportWarningsContinue => '继续导入';

  @override
  String get spreadsheetFormatUnrecognized =>
      '未识别表格格式，请使用轻屿课表模板；也兼容 WakeUp 等同列格式';

  @override
  String get icsImportTitle => '.ics 日历导入';

  @override
  String get applicableScenarioTitle => '适用场景';

  @override
  String get icsScenarioIntro =>
      '如果你已经能在 WakeUp 等课表应用里导入教务系统课程，再导出为 .ics 文件，这条路最稳';

  @override
  String stepLabel(String step) {
    return '步骤 $step';
  }

  @override
  String get icsStep1Subtitle => '先在其他课表应用里导出 .ics 日历文件';

  @override
  String get icsStep2Subtitle => '回到这里选择文件，可选“追加导入”或“替换现有”';

  @override
  String get icsStep3Subtitle => '导入前还会让你确认开学日期，以及课表第 1 周对应校历第几周';

  @override
  String get supportedFilesTitle => '支持的文件';

  @override
  String get supportedFilesSuffix => '文件后缀必须是 .ics';

  @override
  String get supportedFilesImageHint => '如果你手里只有截图，不要走这里，请返回上一页选择“识图导入”';

  @override
  String get chooseIcsFileAction => '选择 .ics 文件';

  @override
  String get timetableAppName => '轻屿课表';

  @override
  String get switchProfileHint => '点击切换课表';

  @override
  String get moreTooltip => '更多';

  @override
  String get pleaseSetSemesterStartDate => '请先在课表设置里填写开学日期';

  @override
  String get deleteScheduleTitle => '删除日程';

  @override
  String get deleteLessonTitle => '删除这节课';

  @override
  String get cancelAction => '取消';

  @override
  String get confirmAction => '确认';

  @override
  String get deleteAction => '删除';

  @override
  String deletedCourseMessage(String name) {
    return '已删除：$name';
  }

  @override
  String get deleteFailed => '删除失败';

  @override
  String get rescheduleFailed => '调课失败';

  @override
  String get timetableManagement => '课表管理';

  @override
  String weekLabel(int week) {
    return '第 $week 周';
  }

  @override
  String sectionLabel(int section) {
    return '第 $section 节';
  }

  @override
  String get feedbackTitle => '问题反馈';

  @override
  String get feedbackIntro => '如果你遇到崩溃、课程显示异常、导入问题，或者想提交功能建议，可以通过下面这些渠道反馈';

  @override
  String get feedbackIssueHint => '涉及复现步骤、截图、版本号和日志的问题，建议优先走 GitHub Issue';

  @override
  String get githubIssueTitle => 'GitHub Issue';

  @override
  String get githubIssueSubtitle => '打开仓库 Issue 页面，可提交问题、建议或查看已有反馈记录';

  @override
  String get openIssuePage => '打开 Issue 页面';

  @override
  String get copyAddress => '复制地址';

  @override
  String get copiedIssueAddress => '已复制 Issue 地址';

  @override
  String get copyXiaohongshuId => '复制小红书号';

  @override
  String get copiedXiaohongshuId => '已复制小红书号';

  @override
  String get copyCoolapkId => '复制酷安号';

  @override
  String get copiedCoolapkId => '已复制酷安号';

  @override
  String get copyQqGroupId => '复制群号';

  @override
  String get copiedQqGroupId => '已复制 QQ 群号';

  @override
  String get copiedWechatOaName => '已复制公众号名称';

  @override
  String get feedbackWechatOaOpenHint => '已复制公众号名称，请到微信中粘贴搜索';

  @override
  String get feedbackOpeningChannel => '正在打开…';

  @override
  String get feedbackOpenChannelFailed => '无法打开，已复制相关信息';

  @override
  String get timetableProfilesTitle => '课表管理';

  @override
  String get createTimetableTooltip => '新建课表';

  @override
  String coursesAndWeekSummary(int count, int week) {
    return '$count 门课程 · 第 $week 周';
  }

  @override
  String get moreActionsTooltip => '更多操作';

  @override
  String get switchToThisTimetable => '切换到此课表';

  @override
  String get renameAction => '重命名';

  @override
  String get duplicateAction => '复制';

  @override
  String get clearCoursesAction => '清空课程';

  @override
  String get usingNow => '正在使用';

  @override
  String switchedToProfile(String name) {
    return '已切换到 $name';
  }

  @override
  String get createTimetableTitle => '新建课表';

  @override
  String get timetableNameLabel => '课表名称';

  @override
  String get timetableNameHint => '例如：大二下';

  @override
  String get createAction => '创建';

  @override
  String createdProfile(String name) {
    return '已创建课表：$name';
  }

  @override
  String get renameTimetableTitle => '重命名课表';

  @override
  String get saveAction => '保存';

  @override
  String renamedProfile(String name) {
    return '已重命名为 $name';
  }

  @override
  String get clearCurrentTimetableTitle => '清空当前课表';

  @override
  String clearCurrentTimetableMessage(String name) {
    return '确定清空“$name”的全部课程吗？课表设置会保留';
  }

  @override
  String get clearAction => '清空';

  @override
  String clearedProfile(String name) {
    return '已清空课表：$name';
  }

  @override
  String get noCoursesInCurrentProfile => '当前课表已经没有课程';

  @override
  String get deleteTimetableTitle => '删除课表';

  @override
  String deleteTimetableMessage(String name) {
    return '确定删除“$name”吗？';
  }

  @override
  String deletedProfile(String name) {
    return '已删除课表：$name';
  }

  @override
  String get keepAtLeastOneProfile => '至少保留一个课表';

  @override
  String get dataTransferTitle => '数据备份与迁移';

  @override
  String get qrTransferSectionTitle => '二维码面对面传输';

  @override
  String get qrTransferSectionSubtitle => '两台手机靠近，扫码即可直接传输课表与全部设置，无需网络';

  @override
  String get qrTransferSendCurrent => '二维码发送当前课表';

  @override
  String get qrTransferSendAll => '二维码发送全部数据';

  @override
  String get qrTransferScanReceive => '扫码接收课表数据';

  @override
  String qrTransferFrameProgress(int sent, int total) {
    return '已发送 $sent 帧，约需 $total 帧';
  }

  @override
  String get qrTransferSendHint => '请对方打开「扫码接收」，将摄像头对准此屏幕，保持到接收完成';

  @override
  String get qrTransferStop => '停止发送';

  @override
  String get qrTransferScanTitle => '扫码接收';

  @override
  String get qrTransferScanHint => '将摄像头对准对方手机屏幕，保持稳定，等待进度完成';

  @override
  String qrTransferReceiveProgress(int received, int decoded, int total) {
    return '已接收 $received 帧 · 已解出 $decoded/$total';
  }

  @override
  String get qrTransferReceiveComplete => '数据接收完成，正在导入…';

  @override
  String get qrTransferSessionMismatch => '检测到不同传输内容，请确认只对准一份数据';

  @override
  String get qrTransferChecksumFailed => '传输校验失败，请重新开始';

  @override
  String get qrTransferRawLengthMismatch => '接收数据长度校验失败，请重新开始';

  @override
  String get qrTransferDecompressionFailed => '数据解压失败，请重新开始';

  @override
  String get qrTransferPlaintextWarning =>
      '二维码传输是明文，附近摄像头可能读取内容。请确认来源，未经确认不会覆盖数据。';

  @override
  String get qrTransferResourceLimit => '接收数据超过二维码传输资源上限，请重新开始并使用更小的备份。';

  @override
  String get qrTransferSessionExpired => '二维码传输已超时，请重新开始并只对准一台设备。';

  @override
  String get qrTransferFullBackupWarning => '确认后，该完整备份会替换本设备上的数据。';

  @override
  String get qrTransferImportFullBackup => '导入完整备份';

  @override
  String get qrTransferDecodeFailed => '二维码数据解码失败，请重新开始';

  @override
  String get qrTransferRestart => '重新开始';

  @override
  String get qrTransferSampleFps => '采样帧率';

  @override
  String get qrTransferDecodeFps => '解码帧率';

  @override
  String get qrTransferReceiveSpeed => '接收速度';

  @override
  String get qrTransferElapsed => '已用时间';

  @override
  String get qrTransferNewFrames => '新增帧';

  @override
  String get qrTransferDuplicateFrames => '重复帧';

  @override
  String get qrTransferBlockSize => '单块大小';

  @override
  String get qrTransferBlockCount => '数据块数';

  @override
  String get qrTransferFileData => '文件数据';

  @override
  String qrTransferFileDataDetail(String rawSize, String compressedSize) {
    return '原始 $rawSize · 压缩 $compressedSize';
  }

  @override
  String get qrTransferShareWeek => '分享本周课表';

  @override
  String get qrTransferShareSelectedCourses => '分享勾选的课程';

  @override
  String get qrTransferShareTimeTemplate => '分享时间模板';

  @override
  String get qrTransferSelectCoursesDone => '完成';

  @override
  String get dataTransferUndoSuccess => '已撤销本次导入';

  @override
  String get dataTransferUndoFailed => '撤销失败';

  @override
  String get selectImportModeMerge => '合并更改';

  @override
  String get fullExportTitle => '完整导出';

  @override
  String get fullExportSubtitle => '支持导出当前课表，或一次导出全部课表、时间模板和当前选中状态';

  @override
  String get exportCurrentTimetable => '导出当前课表';

  @override
  String get exportAllData => '导出全部数据';

  @override
  String get fullImportTitle => '完整导入';

  @override
  String get fullImportSubtitle => '导入时可以选择覆盖当前课表，或直接导入为一个新课表，建议先导出自己的备份';

  @override
  String get chooseFileAndImport => '选择文件并导入';

  @override
  String get transferOverviewTitle => '当前可迁移内容';

  @override
  String courseCountBullet(int count) {
    return '课程数量：$count 门';
  }

  @override
  String currentTimetableBullet(String name) {
    return '当前课表：$name';
  }

  @override
  String allTimetablesBullet(int count) {
    return '全部课表：$count 个';
  }

  @override
  String timeSchemeCountBullet(int count) {
    return '时间模板：$count 套';
  }

  @override
  String currentWeekBullet(int week) {
    return '当前周：第 $week 周';
  }

  @override
  String get semesterStartUnsetBullet => '开学日期：未设置';

  @override
  String semesterStartBullet(String date) {
    return '开学日期：$date';
  }

  @override
  String fileExtensionBullet(String extension) {
    return '文件后缀：.$extension';
  }

  @override
  String get selectImportModeTitle => '选择导入方式';

  @override
  String get selectImportModeMessage => '你可以覆盖当前课表，或者把备份导入成一个新的独立课表';

  @override
  String get replaceCurrentTimetable => '覆盖当前课表';

  @override
  String get importAsNewTimetable => '导入为新课表';

  @override
  String get createdNewTimetableAfterImport => '导入成功，已创建新的课表';

  @override
  String get backupRestoredSuccess => '导入成功，备份数据已恢复';

  @override
  String get importFailedInvalidFile => '导入失败，请确认文件有效';

  @override
  String get welcomeTitle => '欢迎使用';

  @override
  String get welcomeAppName => '轻屿课表';

  @override
  String get welcomeSubtitle => '你可以先开始使用，也可以直接导入课程或从备份恢复';

  @override
  String get thirdPartyDisclaimer =>
      '特此声明：本应用由第三方开发者独立开发，仅用于学习研究用途，不属于小米官方软件，与小米科技有限责任公司无任何隶属、合作或授权关系。如涉及内容侵权，请权利方联系作者，我们将第一时间下架并删除相关内容。';

  @override
  String get startUsingTitle => '开始使用';

  @override
  String get startUsingSubtitle => '直接进入软件，并继续完成首次使用说明';

  @override
  String get importTimetableTitle => '导入课表';

  @override
  String get importTimetableSubtitle => '从 .ics 文件或 AI 解析结果导入课程';

  @override
  String get restoreBackupTitle => '从备份恢复';

  @override
  String get restoreBackupSubtitle => '从 .mikcb 备份文件恢复旧数据';

  @override
  String get viewGuideTitle => '查看功能说明';

  @override
  String get viewGuideSubtitle => '先了解权限、超级岛和基础设置';

  @override
  String get migrationTitle => '迁移旧数据';

  @override
  String get migrationSafeTitle => '别担心，这不是数据丢失';

  @override
  String get migrationSafeSubtitle =>
      '我们更换了应用包名，所以桌面上会暂时出现两个应用图标，这是正常现象，旧数据仍在旧版应用里，请先去旧版备份，再回到新版导入';

  @override
  String get migrationStep1Title => '打开旧版应用';

  @override
  String get migrationStep1Subtitle =>
      '进入“数据备份与迁移”页面后，请点“导出全部数据”，不要点“导出当前课表”，也不要先卸载旧版';

  @override
  String get migrationStep2Title => '保存备份文件';

  @override
  String get migrationStep2Subtitle =>
      '旧版导出后会弹出系统分享面板，优先选择“保存到文件”，建议存到 下载 / Download 文件夹';

  @override
  String get migrationStep3Title => '回到当前版本导入';

  @override
  String get migrationStep3Subtitle =>
      '回到新版后，通过系统文件选择器到 下载 / Download 文件夹选中 .mikcb 备份文件即可恢复，确认新版数据正常后，再卸载旧版应用';

  @override
  String get migrationNoSaveToFilesTitle => '如果没有“保存到文件”';

  @override
  String get migrationNoSaveToFilesSubtitle =>
      '可以先分享到微信任意一个聊天，然后在微信里点开这个备份文件并保存，保存后通常会出现在 Download / WeiXin 文件夹里，再回到新版选择这个 .mikcb 文件导入';

  @override
  String get openingOldApp => '正在打开旧版...';

  @override
  String get openOldAppForBackup => '打开旧版去备份';

  @override
  String get backupDoneGoImport => '我已完成备份，去导入';

  @override
  String get startFreshWithoutMigration => '以全新应用开始，不迁移';

  @override
  String get openOldAppFailed => '未能打开旧版应用，请手动返回桌面打开旧版';

  @override
  String get supportCreatorTitle => '请作者喝杯咖啡';

  @override
  String get supportHeroTitle => '支持轻屿课表继续更新';

  @override
  String get supportHeroSubtitle => '你的支持会直接用于维护课表、教务导入适配与体验优化';

  @override
  String get supportChipFixes => '修复问题';

  @override
  String get supportChipAdapters => '教务适配';

  @override
  String get supportChipPolish => '体验优化';

  @override
  String get supportMethodTitle => '选择支持方式';

  @override
  String get wechatLabel => '微信';

  @override
  String get alipayLabel => '支付宝';

  @override
  String get supportWeChatHint => '使用微信扫一扫支持作者';

  @override
  String get supportAlipayHint => '使用支付宝扫一扫支持作者';

  @override
  String get viewLargeImage => '查看大图';

  @override
  String get saveToGallery => '保存到相册';

  @override
  String get supportCompleteThanks => '感谢你支持轻屿课表继续打磨 ❤️';

  @override
  String get supportConfirmed => '我已经支持了';

  @override
  String get donorListTitle => '鸣谢名单';

  @override
  String get donorListLoadFailed => '暂时无法加载在线鸣谢名单';

  @override
  String get reloadAction => '重新加载';

  @override
  String updatedAtLabel(String time) {
    return '更新于 $time';
  }

  @override
  String get donorListEmpty => '名单还没有填写，你可以直接编辑 docs/donors.json 后重新发布';

  @override
  String get savedToGallery => '已保存到相册';

  @override
  String get saveToGalleryFailed => '保存到相册失败';

  @override
  String saveFailedWithError(String error) {
    return '保存失败：$error';
  }

  @override
  String get supportRunningBadge => '运行中';

  @override
  String get supportTapQrHint => '点击放大扫码';

  @override
  String get supportSaveShort => '保存';

  @override
  String get supportConfirmedShort => '已支持';

  @override
  String get donorSearchHint => '搜昵称/寄语...';

  @override
  String get donorSortLargeFirst => '大额优先';

  @override
  String get donorSortSmallFirst => '小额优先';

  @override
  String get supportMonthlyGoalLabel => '本月服务器和证书续期进度';

  @override
  String supportGoalRaised(String raised, String goal) {
    return '已筹: $raised / 目标 $goal';
  }

  @override
  String supportBackerCount(int count) {
    return '已有 $count 人献出爱心';
  }

  @override
  String get supportDonorListFooter => '名单永久保留 💖';

  @override
  String supportMarqueeThanks(String name, String amount) {
    return '🎉 感谢 $name 赞助 $amount';
  }

  @override
  String get supportMarqueeTail => '轻屿课表正在稳定运行中，期待你的每一次陪伴与爱心！';

  @override
  String get scanQrWechatTitle => '使用微信扫描二维码';

  @override
  String get scanQrAlipayTitle => '使用支付宝扫描二维码';

  @override
  String get scanQrSubtitle => '截图并导入扫一扫，感谢支持！';

  @override
  String get courseOverviewTitle => '课程总览与编辑';

  @override
  String get addNewCourseTooltip => '添加新课程';

  @override
  String get emptyCourseOverviewHint => '长按课表或点击右上角添加课程';

  @override
  String conflictDetectedMessage(int count) {
    return '检测到 $count 门排课存在实际冲突，课程列表已标记冲突项';
  }

  @override
  String conflictCountLabel(int count) {
    return '冲突 $count 节';
  }

  @override
  String scheduledCountLabel(int count) {
    return '共排课 $count 节';
  }

  @override
  String scheduledCountWithConflictHint(int count) {
    return '共排课 $count 节 · 展开查看冲突详情';
  }

  @override
  String courseTimeSummary(int day, int start, int end) {
    return '时间: 星期$day 第$start-$end节';
  }

  @override
  String get teacherUnset => '未置';

  @override
  String get locationUnset => '未置';

  @override
  String courseDetailSummary(
    String weekDescription,
    String teacher,
    String location,
  ) {
    return '$weekDescription  教师: $teacher  教室: $location';
  }

  @override
  String courseDetailSummaryWithConflict(
    String weekDescription,
    String teacher,
    String location,
    String conflictSummary,
  ) {
    return '$weekDescription  教师: $teacher  教室: $location\n冲突课程: $conflictSummary';
  }

  @override
  String get confirmDeleteTitle => '确认删除';

  @override
  String confirmDeleteCourseMessage(String name) {
    return '确定要删除课程“$name”吗？';
  }

  @override
  String get currentScheduleTitle => '当前排课';

  @override
  String get currentScheduleSubtitle => '这里的星期、节次、教室、周次和单双周只影响当前这一条排课';

  @override
  String get timeSchemeLabel => '上课时间方案';

  @override
  String followCurrentTimetableWithName(String name) {
    return '跟随当前课表（$name）';
  }

  @override
  String get followCurrentTimetableDescription =>
      '未手动指定时，按上课地点自动匹配时间模板；未命中则跟随课表主时间模板';

  @override
  String get overrideTimeSchemeDescription => '这门课会单独使用所选时间模板，不跟随当前课表主时间模板';

  @override
  String get weekdayLabel => '星期';

  @override
  String get startSectionLabel => '开始节次';

  @override
  String get endSectionLabel => '结束节次';

  @override
  String timeRangeLabel(String start, String end) {
    return '时间: $start - $end';
  }

  @override
  String get locationLabel => '上课地点';

  @override
  String get singleLessonWeekTitle => '上课周次';

  @override
  String get singleLessonWeekSubtitle => '单节课只会出现在一个周次里，适合补课、临时加课';

  @override
  String get selectWeekLabel => '选择周次';

  @override
  String get weekSettingsTitle => '周次设置';

  @override
  String get rangeWeeksLabel => '连续周';

  @override
  String get customWeeksLabel => '自定义周';

  @override
  String get startWeekLabel => '开始周';

  @override
  String get endWeekLabel => '结束周';

  @override
  String get allWeeksFilter => '全部';

  @override
  String get oddWeeksFilter => '单周';

  @override
  String get evenWeeksFilter => '双周';

  @override
  String get rangeWeeksAllHint => '按开始周到结束周连续排课';

  @override
  String get rangeWeeksOddHint => '只保留范围内的单周';

  @override
  String get rangeWeeksEvenHint => '只保留范围内的双周';

  @override
  String get selectAllAction => '全选';

  @override
  String get selectOddWeeksAction => '单周';

  @override
  String get selectEvenWeeksAction => '双周';

  @override
  String selectedWeeksSummary(int count, String weeks) {
    return '已选 $count 周：第$weeks周';
  }

  @override
  String get courseColorTitle => '课程颜色';

  @override
  String get courseColorQuickSection => '常用颜色';

  @override
  String get customPaletteAction => '调色盘自定义颜色';

  @override
  String get colorPaletteTitle => '调色盘';

  @override
  String get colorHexLabel => '颜色 Hex';

  @override
  String get weekdayMon => '周一';

  @override
  String get weekdayTue => '周二';

  @override
  String get weekdayWed => '周三';

  @override
  String get weekdayThu => '周四';

  @override
  String get weekdayFri => '周五';

  @override
  String get weekdaySat => '周六';

  @override
  String get weekdaySun => '周日';

  @override
  String hueLabel(int value) {
    return '色相 $value';
  }

  @override
  String saturationLabel(int value) {
    return '饱和度 $value%';
  }

  @override
  String brightnessLabel(int value) {
    return '明度 $value%';
  }

  @override
  String get useThisColor => '使用这个颜色';

  @override
  String get selectAtLeastOneWeek => '请至少选择一个上课周次';

  @override
  String get saveFailed => '保存失败';

  @override
  String get courseAddedSuccess => '课程添加成功';

  @override
  String get courseUpdatedSuccess => '课程更新成功';

  @override
  String get aboutTitle => '关于软件';

  @override
  String get loadingText => '读取中';

  @override
  String versionLabel(String version) {
    return '版本 $version';
  }

  @override
  String get aboutHeroSubtitle =>
      '一个围绕课表查看、课程提醒和 HyperOS 超级岛体验打磨的 Android 开源项目';

  @override
  String get platformLabel => '平台';

  @override
  String get focusLabel => '重点';

  @override
  String get updateLabel => '更新';

  @override
  String get prereleaseIncluded => '含预发布';

  @override
  String get stableOnly => '正式版';

  @override
  String get aboutUpdatesTitle => '版本更新';

  @override
  String get aboutUpdatesSubtitle => '检查更新与立即下载';

  @override
  String get aboutChangelogTitle => '更新日志';

  @override
  String get aboutChangelogSubtitle => '查看所有版本的更新内容';

  @override
  String get aboutPositioningTitle => '项目定位';

  @override
  String get aboutPositioningSubtitle => '这是什么、适合谁、核心能力是什么';

  @override
  String get aboutPositioningBullet1 => '支持周视图课表、课程增删改、.ics 导入';

  @override
  String get aboutPositioningBullet2 => '已支持适配学校的教务系统网页登录导入与完整备份迁移';

  @override
  String get aboutPositioningBullet3 =>
      '支持实时通知；HyperOS 3.0.300 起支持超级岛 / 焦点通知展示';

  @override
  String get aboutPositioningBullet4 => '支持多课表、时间模板、主题色和卡片样式自定义';

  @override
  String get aboutImportMigrationTitle => '导入与迁移';

  @override
  String get aboutImportMigrationSubtitle => '当前导入方式、备份恢复和迁移建议';

  @override
  String get aboutImportMigrationBullet1 =>
      '当前版本已经支持适配学校的教务系统网页登录导入；进入“导入课程 > 教务系统导入”后选择学校和适配器即可';

  @override
  String get aboutImportMigrationBullet2 =>
      '如果你的学校暂时还没适配，仍然可以先在 WakeUp 等课表应用里导入课程，再导出为日历格式，然后在本应用导入';

  @override
  String get aboutImportMigrationBullet3 =>
      '如果其他人已经在用本应用，也可以直接让对方导出完整备份文件，你在“数据备份与迁移”里导入即可直接恢复';

  @override
  String get aboutImportMigrationBullet4 =>
      '如果你会抓包、网页调试或 JavaScript，也欢迎去 qingyu_warehouse 参与教务适配补充';

  @override
  String get aboutContributorsTitle => '代码贡献者';

  @override
  String get aboutContributorsSubtitle => '开发人员与教务导入适配者名单';

  @override
  String get aboutRepositoryTitle => '开源仓库';

  @override
  String get aboutRepositorySubtitle => 'GitHub 仓库地址、源码、Release 和反馈入口';

  @override
  String get aboutOpenSourceLicensesTitle => '开源许可';

  @override
  String get aboutOpenSourceLicensesSubtitle => '本应用协议与第三方组件许可证';

  @override
  String get aboutOpenSourceLicensesSearchHint => '搜索组件名称';

  @override
  String get aboutOpenSourceLicensesAppSectionTitle => '许可说明';

  @override
  String get aboutOpenSourceLicensesAppLicenseLabel =>
      '轻屿课表源码以 GPL-3.0-or-later 发布。';

  @override
  String get aboutOpenSourceLicensesIntro => '下方列表为本应用使用的开源组件及其许可证，点进可查看全文。';

  @override
  String get aboutOpenSourceLicensesExtraSectionTitle => '许可说明';

  @override
  String get aboutOpenSourceLicensesExtraUmeng =>
      '友盟统计等分析服务仅在你同意隐私政策后启用，适用友盟自身的用户协议与隐私政策。';

  @override
  String get aboutOpenSourceLicensesExtraNote => '';

  @override
  String aboutOpenSourceLicensesPackagesSectionTitle(int count) {
    return '开源组件（$count）';
  }

  @override
  String aboutOpenSourceLicensesPackageSubtitle(int count) {
    return '$count 份许可证文本';
  }

  @override
  String get aboutOpenSourceLicensesLoadFailed => '加载许可证失败，请稍后重试';

  @override
  String get aboutOpenSourceLicensesEmpty => '没有匹配的组件';

  @override
  String get aboutAppLogsTitle => '应用日志';

  @override
  String get aboutAppLogsSubtitle => '查看运行日志';

  @override
  String get appLogsShareText =>
      '这是轻屿课表导出的应用日志，包含整个软件的本地运行记录，可用于排查更新、导入、通知、页面和崩溃问题';

  @override
  String get appLogsShareSubject => '轻屿课表 - 应用日志';

  @override
  String get appLogsRecordingEnabled => '正在记录应用日志';

  @override
  String get appLogsRecordingDisabled => '应用日志记录已关闭';

  @override
  String get appLogsCopyAction => '复制日志';

  @override
  String get appLogsCopied => '已复制当前日志';

  @override
  String get appLogsExportAction => '导出日志';

  @override
  String get appLogsClearAction => '清空日志';

  @override
  String get appLogsCleared => '已清空应用日志';

  @override
  String get appLogsClearFailed => '清空应用日志失败';

  @override
  String get appLogsSourceApp => '应用';

  @override
  String get appLogsSourceNative => '超级岛';

  @override
  String get appLogsRecordingPausedHint => '记录已关闭，下方为历史日志，关闭后不再新增';

  @override
  String get timeSchemeTitle => '时间模板';

  @override
  String get newSchemeTooltip => '新建模板';

  @override
  String timeSchemeSummary(
    int sections,
    int profiles,
    int courses,
    int overrideCourses,
  ) {
    return '$sections 节 · $profiles 个课表 · $courses 节课程 · $overrideCourses 节副时间表';
  }

  @override
  String get viewUsageAction => '查看使用情况';

  @override
  String get applyToCurrentTimetable => '应用到当前课表';

  @override
  String get editSectionsAction => '编辑节次';

  @override
  String get createTimeSchemeTitle => '新建时间模板';

  @override
  String get timeSchemeNameLabel => '模板名称';

  @override
  String get timeSchemeNameHint => '例如：本校夏季作息';

  @override
  String get renameTimeSchemeTitle => '重命名时间模板';

  @override
  String renamedToMessage(String name) {
    return '已重命名为 $name';
  }

  @override
  String get deleteTimeSchemeTitle => '删除时间模板';

  @override
  String deleteTimeSchemeMessage(String name) {
    return '确定删除“$name”吗？正在使用中的模板不能删除';
  }

  @override
  String deletedTimeSchemeMessage(String name) {
    return '已删除时间模板：$name';
  }

  @override
  String get timeSchemeInUseMessage => '该模板正在被课表使用';

  @override
  String get copiedTimeSchemeMessage => '已复制时间模板';

  @override
  String appliedTimeSchemeMessage(String name) {
    return '已应用时间模板：$name';
  }

  @override
  String timeSchemeUsageTitle(String name) {
    return '“$name”的使用情况';
  }

  @override
  String get timeSchemeUsageIntro => '先看总影响范围，再决定是直接编辑这套模板，还是先复制一套再改';

  @override
  String get profileCountLabel => '课表';

  @override
  String get courseCountLabel => '课程';

  @override
  String get overrideTimeSchemeLabel => '副时间表';

  @override
  String get directlyBoundProfilesTitle => '直接绑定这套模板的课表';

  @override
  String get directlyBoundProfilesEmpty => '当前没有课表直接使用这套模板';

  @override
  String get directlyBoundProfilesSubtitle => '这些课表切到这套模板后，默认都会按这套节次时间显示';

  @override
  String get followMainSchemeCoursesTitle => '跟随课表主时间表的课程';

  @override
  String get followMainSchemeCoursesEmpty => '当前没有课程通过课表主时间表间接使用它';

  @override
  String get followMainSchemeCoursesSubtitle =>
      '这些课程没有单独设置副时间表，而是跟着所属课表一起用这套模板';

  @override
  String get overrideSchemeCoursesTitle => '把它作为副时间表的课程';

  @override
  String get overrideSchemeCoursesEmpty => '当前没有课程把它作为副时间表';

  @override
  String get overrideSchemeCoursesSubtitle => '这些课程即使所在课表切换了主模板，也会继续单独使用这套时间';

  @override
  String get closeAction => '关闭';

  @override
  String get editTimeSchemeTitle => '编辑时间模板';

  @override
  String get backToSchemeList => '返回模板列表';

  @override
  String get currentInUse => '当前使用';

  @override
  String get quickGenerateAction => '快捷生成';

  @override
  String get addSectionAction => '新增一节';

  @override
  String get removeLastSectionAction => '删除末节';

  @override
  String get resetDefaultAction => '恢复默认';

  @override
  String get sectionTimesTitle => '节次时间';

  @override
  String get sectionTimesSubtitle => '如果当前课表正在使用这套模板，节次数量不能小于已使用的最大节次';

  @override
  String get schemeListCurrentLabel => '当前';

  @override
  String get schemeListCountLabel => '数量';

  @override
  String get sectionCountLabel => '节数';

  @override
  String get quickGenerateTimeSchemeTitle => '快捷生成课表时间';

  @override
  String get addBreakRuleAction => '新增大课间规则';

  @override
  String get afterSectionLabel => '第几节后';

  @override
  String get breakDurationMinutesLabel => '休息多久(分)';

  @override
  String get fillNumbersValidationMessage => '请把节数和时长填写为数字';

  @override
  String get timeSchemeEditorActiveAndCoursesHint =>
      '当前课表和部分课程正在使用这套时间模板，保存后会同步更新所有相关课表和课程';

  @override
  String get timeSchemeEditorActiveHint => '当前课表正在使用这套时间模板，保存后会同步更新所有使用它的课表';

  @override
  String get timeSchemeEditorOverrideHint =>
      '有课程正在把这套模板作为副时间表使用，保存后会同步更新所有引用课程';

  @override
  String get editTimeAction => '编辑时间';

  @override
  String editingSchemeLabel(String name) {
    return '正在编辑：$name';
  }

  @override
  String get copiedTimeSchemeShortMessage => '已复制时间模板';

  @override
  String get unnamedTimeScheme => '未命名模板';

  @override
  String get unsetLabel => '未选择';

  @override
  String get timeSchemeUsageCourseRefPrefix => '课程引用：';

  @override
  String get mainTimeSchemeLabel => '主时间表';

  @override
  String get overrideTimeSchemeShortLabel => '副时间表';

  @override
  String timeSchemeBottomUsageSingle(String first) {
    return '$first';
  }

  @override
  String timeSchemeBottomUsageMulti(String first, int count) {
    return '$first 等 $count 节课程';
  }

  @override
  String get morningSectionCountLabel => '上午几节';

  @override
  String get morningFirstSectionTimeLabel => '早上第一节时间';

  @override
  String get afternoonSectionCountLabel => '下午几节';

  @override
  String get afternoonFirstSectionTimeLabel => '下午第一节时间';

  @override
  String get eveningSectionCountLabel => '晚上几节';

  @override
  String get eveningFirstSectionTimeLabel => '晚上第一节时间';

  @override
  String get classDurationMinutesLabel => '单节课时长（分钟）';

  @override
  String get smallBreakDurationMinutesLabel => '小课间时长（分钟）';

  @override
  String get largeBreakRulesTitle => '大课间规则';

  @override
  String get noLargeBreakRulesHint => '未设置大课间规则，将全部使用小课间时长';

  @override
  String get deleteRuleTooltip => '删除规则';

  @override
  String get generateAction => '生成';

  @override
  String get liveSettingsTitle => '超级岛与通知';

  @override
  String get liveGroupReminders => '提醒';

  @override
  String get liveGroupDisplay => '显示内容';

  @override
  String get liveGroupMaintenance => '维护与自检';

  @override
  String get liveReminderTimingEntryTitle => '提醒时段';

  @override
  String get liveReminderTimingEntrySubtitle => '上课前、课中与下课提醒，以及重点提醒切入时机';

  @override
  String get liveBeforeClassDisplayEntryTitle => '上课前提醒显示';

  @override
  String get liveDuringEndDisplayEntryTitle => '课中与下课提醒显示';

  @override
  String get liveKeepAliveEntryTitle => '后台保活';

  @override
  String get liveKeepAliveEntrySubtitle => '隐藏后台、后台保活辅助服务和权限入口';

  @override
  String get liveTestingEntryTitle => '测试与诊断';

  @override
  String get liveTestingEntrySubtitle => '发送测试通知，检查超级岛和本地诊断日志';

  @override
  String get followBeforeClassSetting => '跟随上课前提醒';

  @override
  String get liveReminderTimingTitle => '提醒时段';

  @override
  String get liveReminderSwitchesTitle => '提醒开关';

  @override
  String get liveReminderSwitchesSubtitle => '可自由组合，互不影响';

  @override
  String get beforeClassReminderTitle => '上课前提醒';

  @override
  String beforeClassReminderSubtitle(int minutes) {
    return '课程开始前 $minutes 分钟弹出';
  }

  @override
  String get duringClassReminderTitle => '课中与下课提醒';

  @override
  String get duringClassReminderSubtitle => '上课后到下课前的展示';

  @override
  String get liveClassReminderLeadTitle => '重点提醒切入时机';

  @override
  String get liveClassReminderLeadOptionImmediate => '一上课就切换';

  @override
  String liveClassReminderLeadOptionMinutes(int minutes) {
    return '下课前 $minutes 分钟';
  }

  @override
  String get liveDisplayModeTitle => '展示方式';

  @override
  String get liveDisplayModeSubtitle => '对已开启的提醒生效';

  @override
  String get duringClassStatusNotificationTitle => '课中状态栏通知';

  @override
  String get duringClassStatusNotificationImmediate => '上课后保留状态栏通知';

  @override
  String get duringClassStatusNotificationBeforeEnd => '重点提醒前保留普通通知';

  @override
  String get duringClassStatusNotificationPersistent => '课中持续显示普通通知';

  @override
  String get enableIslandDisplayTitle => '展示超级岛';

  @override
  String get enableIslandDisplaySubtitle => '关闭后不触发系统超级岛';

  @override
  String get liveTimeThresholdTitle => '时间阈值';

  @override
  String get liveTimeThresholdSubtitle => '控制课前弹出与秒级倒计时';

  @override
  String get beforeClassPopupLabel => '上课前弹出时间';

  @override
  String beforeClassMinutesOption(int minutes) {
    return '$minutes 分钟';
  }

  @override
  String get beforeEndSecondsLabel => '下课前秒级阈值';

  @override
  String beforeEndSecondsOption(int seconds) {
    return '$seconds 秒';
  }

  @override
  String timeCorrectionLabel(String value) {
    return '铃声时间矫正：$value';
  }

  @override
  String get timeCorrectionTitle => '铃声时间矫正';

  @override
  String get timeCorrectionHelp => '铃声比课表快则提前，慢则延后';

  @override
  String get duringEndTimeDisplayLabel => '课中时间样式';

  @override
  String get duringEndTimeDisplayHelp => '紧凑提醒显示最近时间或总时长';

  @override
  String get liveDisplayContentTitle => '显示内容';

  @override
  String get liveDisplayContentSubtitle => '这组设置只影响当前阶段，不会改动另一组提醒显示';

  @override
  String get showCourseNameTitle => '显示课程名';

  @override
  String get preferShortNameTitle => '优先显示课程简称';

  @override
  String get preferShortNameSubtitle => '建议简称控制在 3 个字以内';

  @override
  String get showLocationTitle => '显示地点';

  @override
  String get showCountdownTitle => '显示倒计时';

  @override
  String get countdownFormatLabel => '倒计时格式';

  @override
  String get countdownFormatHelp => '纯分钟样式按分钟刷新，带秒样式按秒刷新';

  @override
  String get showStageTextTitle => '显示阶段状态文案';

  @override
  String get showStageTextSubtitle => '关闭倒计时后，可继续显示“即将上课 / 上课中 / 下课提醒”';

  @override
  String get hidePrefixTextTitle => '隐藏前缀文案';

  @override
  String get hidePrefixTextSubtitle => '例如隐藏“即将上课”这类前缀';

  @override
  String get liveIslandPreviewTitle => '超级岛预览';

  @override
  String get liveIslandPreviewFollowBadge => '正在跟随“课前提醒显示”设置，调整课前提醒即可生效';

  @override
  String get liveIslandPreviewStageBeforeClass => '即将上课';

  @override
  String get liveIslandPreviewStageInClass => '上课中';

  @override
  String get liveIslandPreviewStageBeforeEnd => '下课提醒';

  @override
  String liveIslandPreviewUntilClassStart(String time) {
    return '距上课$time';
  }

  @override
  String liveIslandPreviewUntilClassEnd(String time) {
    return '距下课$time';
  }

  @override
  String get liveIslandPreviewSampleCourse => '高等数学';

  @override
  String get liveIslandPreviewSampleCourseShort => '高数';

  @override
  String get liveIslandPreviewSampleLocation => '三教-401';

  @override
  String get beforeClassQuickActionTitle => '上课前快捷操作';

  @override
  String get beforeClassQuickActionSubtitle =>
      '只在上课前提醒的展开通知里显示，静音/免打扰会在下课后自动恢复，重启手机也会恢复；免打扰首次可能会跳到系统授权页';

  @override
  String get liveBeforeClassQuickActionAutoTitle => '自动执行';

  @override
  String get liveBeforeClassQuickActionAutoSubtitle =>
      '上课前自动打开所选模式，下课后自动恢复，重启手机也会恢复；免打扰需要先在系统设置中授权';

  @override
  String get liveBeforeClassQuickActionAutoOptionOff => '不自动执行';

  @override
  String liveBeforeClassQuickActionAutoOptionMinutes(int minutes) {
    return '上课前 $minutes 分钟';
  }

  @override
  String liveMiuiLabelSizePreview(String value) {
    return '$value';
  }

  @override
  String get liveIslandVisualTitle => '左侧图标与展开态';

  @override
  String get liveIslandVisualSubtitle => '左侧文字图、展开态大图标和自定义图片都按当前阶段单独保存';

  @override
  String get liveMiuiLabelImageTitle => '小米岛左侧文字图标';

  @override
  String get liveMiuiLabelImageSubtitle => '仅小米手机样式生效，会把课程名或地点生成到左侧图标位';

  @override
  String get liveMiuiLabelContentLabel => '左侧文字内容';

  @override
  String get liveMiuiLabelStyleLabel => '左侧图标样式';

  @override
  String get liveMiuiLabelLogoTitle => '左侧图标 Logo';

  @override
  String get liveMiuiLabelLogoSubtitle => '仅在“图标+文字”样式下生效；未选择时继续使用应用图标';

  @override
  String liveMiuiLabelLogoCornerRadiusLabel(String value) {
    return '左侧图标圆角 $value';
  }

  @override
  String get liveMiuiLabelLogoCornerRadiusTitle => '左侧图标圆角';

  @override
  String liveMiuiLabelFontSizeLabel(String value) {
    return '左侧文字大小 $value';
  }

  @override
  String get liveMiuiLabelFontSizeTitle => '左侧文字大小';

  @override
  String liveMiuiLabelOffsetXLabel(String value) {
    return '左侧文字水平偏移 $value';
  }

  @override
  String get liveMiuiLabelOffsetXTitle => '左侧文字水平偏移';

  @override
  String liveMiuiLabelOffsetYLabel(String value) {
    return '左侧文字垂直偏移 $value';
  }

  @override
  String get liveMiuiLabelOffsetYTitle => '左侧文字垂直偏移';

  @override
  String get liveMiuiLabelFontWeightLabel => '左侧文字粗细';

  @override
  String get liveMiuiLabelRenderQualityLabel => '左侧文字清晰度';

  @override
  String get liveMiuiExpandedIconLabel => '展开态大图标';

  @override
  String get selectImageAction => '选择图片';

  @override
  String get replaceImageAction => '更换图片';

  @override
  String get liveDisplayConfigModeTitle => '配置方式';

  @override
  String get liveDisplayConfigModeSubtitle =>
      '打开后，课中和下课提醒会完全跟随上课前提醒显示，下面的独立设置暂时不可编辑';

  @override
  String get followBeforeClassDisplayTitle => '跟随上课前提醒设置';

  @override
  String get liveKeepAliveTitle => '后台保活';

  @override
  String get liveKeepAliveOptionsTitle => '保活选项';

  @override
  String get liveKeepAliveOptionsSubtitle => '用于提升超级岛和提醒在后台场景下的稳定性';

  @override
  String get hideFromRecentsTitle => '从最近任务中隐藏应用';

  @override
  String get hideFromRecentsSubtitle => '开启后应用会尽量不显示在最近任务列表中';

  @override
  String get keepAliveServiceTitle => '轻屿课表后台保活服务';

  @override
  String get keepAliveServiceEnabledSubtitle => '当前已开启，系统会保持后台保活辅助服务处于可用状态';

  @override
  String get keepAliveServiceDisabledSubtitle =>
      '当前未开启，可进入系统无障碍设置手动打开轻屿课表后台保活服务';

  @override
  String get goEnableAction => '去开启';

  @override
  String get keepAliveConfirmTitle => '开启后台保活服务';

  @override
  String get keepAliveConfirmBody =>
      '该服务仅用于在后台刷新桌面小组件与重排课程提醒，不会读取屏幕内容，也不会代替你执行任何点击操作。开启需要在系统设置中授予「无障碍」权限，可随时关闭。';

  @override
  String get keepAliveConfirmGoAction => '去开启';

  @override
  String get layoutEntryTitle => '布局与节次';

  @override
  String get layoutEntrySubtitle => '节次时间、行高、时间列、周末显示与卡片布局';

  @override
  String get remindersSectionTitle => '提醒与通知';

  @override
  String get liveGuideEntryTitle => '使用引导与权限';

  @override
  String get liveGuideEntrySubtitle => '简称建议、通知、自启动、电池策略';

  @override
  String get managementSectionTitle => '课表管理';

  @override
  String timeSchemeEntryCurrentPrefix(String name) {
    return '当前：$name · 切换、编辑节次和复制';
  }

  @override
  String get timeSchemeEntrySubtitle => '切换、编辑节次、复制和管理时间模板';

  @override
  String semesterOverviewCurrentWeek(int current, int total) {
    return '当前第 $current 周 / 共 $total 周';
  }

  @override
  String get semesterStartUnset => '未设置开学日期';

  @override
  String semesterStartSet(String date) {
    return '开学日期：$date';
  }

  @override
  String get setSemesterStartDate => '设置开学日期';

  @override
  String get semesterStartDateLabel => '开学日期';

  @override
  String syncedCurrentWeekMessage(int week) {
    return '已同步到第 $week 周';
  }

  @override
  String get pickSemesterWeekCountTitle => '选择学期周数';

  @override
  String get pickSemesterWeekCountSubtitle => '不同学校可按实际教学周数调整';

  @override
  String weekCountItem(int count) {
    return '$count 周';
  }

  @override
  String get diagnosticsLogIntro => '支持 Markdown 与原文两种查看方式，排查时可以直接在手机上看完整日志';

  @override
  String get diagnosticsRawTab => '原文';

  @override
  String get diagnosticsStructuredTab => '结构化';

  @override
  String get diagnosticsLevelLabel => '等级';

  @override
  String get diagnosticsLevelAll => '全部';

  @override
  String get diagnosticsLevelError => '错误';

  @override
  String get diagnosticsLevelWarn => '警告';

  @override
  String get diagnosticsLevelInfo => '信息';

  @override
  String get diagnosticsLevelDebug => '调试';

  @override
  String get diagnosticsLevelVerbose => '详细';

  @override
  String diagnosticsShowingCount(int shown, int total) {
    return '显示 $shown / $total 条日志';
  }

  @override
  String get diagnosticsNoMatchingTitle => '当前筛选下没有日志';

  @override
  String get diagnosticsNoMatchingSubtitle => '可以切换到“全部”，或改看原文继续排查';

  @override
  String diagnosticsLoadEarlierLabel(int count) {
    return '加载更早日志（还有 $count 条）';
  }

  @override
  String get diagnosticsLevelInferred => '推断等级';

  @override
  String get diagnosticsRawFilteredHint => '原文视图会跟随当前等级筛选，只显示对应日志块';

  @override
  String get diagnosticsTimeSortAscending => '正序';

  @override
  String get diagnosticsTimeSortDescending => '倒序';

  @override
  String get diagnosticsDisplayOptionsTitle => '查看与排序';

  @override
  String get diagnosticsStreamingHint => '实时更新中，新日志会自动追加显示';

  @override
  String get diagnosticsEmptyTitle => '暂无日志';

  @override
  String get diagnosticsEmptySubtitle => '当前没有可显示的应用日志';

  @override
  String get diagnosticsLogTitleFallback => '超级岛诊断日志';

  @override
  String get diagnosticsDeviceInfoTitle => '设备与导出信息';

  @override
  String get diagnosticsContentTitle => '日志内容';

  @override
  String get diagnosticsRecentLogsTitle => '最近日志';

  @override
  String get diagnosticsUnknownCategory => '未分类事件';

  @override
  String get diagnosticsExportedAt => '导出时间';

  @override
  String get diagnosticsTime => '时间';

  @override
  String get diagnosticsCategory => '类别';

  @override
  String get diagnosticsMessage => '消息';

  @override
  String get diagnosticsStackTrace => '堆栈';

  @override
  String get firstUseGuideTitle => '首次使用引导';

  @override
  String get guideAndPermissionsTitle => '使用引导与权限';

  @override
  String get refreshStatusTooltip => '刷新状态';

  @override
  String get guideHeroTitle => '先把这页做完，再开始用';

  @override
  String get guideHeroSubtitle => '首屏先授权，下面还会明确说明系统版本支持、简称设置和导入方式，记得继续下滑';

  @override
  String get guideChipPermissions => '权限准备';

  @override
  String get guideChipShortName => '简称设置';

  @override
  String get guideChipImport => '导入课表';

  @override
  String guideChipReadyCount(int count) {
    return '$count/3 已完成';
  }

  @override
  String get guideBottomReachedHint => '你已经滑到最后了，确认无误后就可以开始使用';

  @override
  String get guideScrollHint => '向下滑动继续，下面还有 HyperOS 版本说明、权限清单、简称设置和导入方式';

  @override
  String get guideRequestNotificationFirst => '先申请通知权限';

  @override
  String get quickSetupTitle => '首屏快速设置';

  @override
  String get quickSetupSubtitle => '先把最关键的 5 个入口放在前面，不用翻到下面再找';

  @override
  String get quickActionNotificationsTitle => '通知设置';

  @override
  String get quickActionNotificationsSubtitle => '先确保能发通知';

  @override
  String get quickActionIslandTitle => '超级岛权限';

  @override
  String get quickActionIslandSubtitle => '检查 promoted 通知';

  @override
  String get quickActionAutoStartTitle => '自启动';

  @override
  String get quickActionAutoStartSubtitle => '避免后台被杀';

  @override
  String get quickActionBatteryTitle => '电池无限制';

  @override
  String get quickActionBatterySubtitle => '避免提醒中断';

  @override
  String get quickActionKeepAliveTitle => '后台保活辅助';

  @override
  String get quickActionKeepAliveSubtitle => '提升后台稳定性';

  @override
  String get guidePrivacyConsentLabel => '我已阅读并同意友盟相关隐私说明';

  @override
  String get guideRequireConsentHint => '请先滑到底部阅读说明，并勾选同意后开始使用';

  @override
  String get guideContinueHint => '继续下滑查看完整引导内容';

  @override
  String get exitAppAction => '退出应用';

  @override
  String get continueReadingAction => '继续查看';

  @override
  String get agreeAndStartAction => '同意并开始使用';

  @override
  String get startUsingAction => '开始使用';

  @override
  String get editSingleLessonTitle => '编辑单节课';

  @override
  String get editCourseTitle => '编辑课程';

  @override
  String get addSingleLessonTitle => '添加单节课';

  @override
  String get addCourseTitle => '添加课程';

  @override
  String get deleteCourseTitle => '删除课程';

  @override
  String get courseDeleted => '课程已删除';

  @override
  String get addMethodTitle => '添加方式';

  @override
  String get singleLessonLabel => '单节课';

  @override
  String get recurringLessonLabel => '多节课';

  @override
  String get singleLessonHint => '适合补课、临时加课，课程只会落在一个周次';

  @override
  String get recurringLessonHint => '适合同一时间连续上很多周的常规课程';

  @override
  String get sharedInfoTitle => '共享信息';

  @override
  String get sharedInfoHint => '查看共享字段说明';

  @override
  String get sharedInfoSheetItemCourseName =>
      '课程名称：课程唯一标识，名称相同的多条排课视为同一课程；更改名称将形成独立课程记录';

  @override
  String get sharedInfoSheetItemShortName =>
      '课程简称：用于超级岛等场景的简短展示，需手动填写，系统不会自动生成，启用「优先显示课程简称」后生效；建议控制在 3 个汉字以内';

  @override
  String get sharedInfoSheetItemSharedSync =>
      '共享同步：课程简称、颜色、性质、简介等字段将同步至同名课程的其他排课记录';

  @override
  String get reuseExistingCourseLabel => '沿用已有课程';

  @override
  String get reuseExistingCourseHelper => '选一个已有课程，自动带入课程名、老师和其他共享信息';

  @override
  String get manualInputLabel => '手动填写';

  @override
  String get noTemplateCoursesHint => '当前课表里还没有现成课程，先手动录入一门，后面临时加课就能直接选了';

  @override
  String get courseNameLabel => '课程名称';

  @override
  String get courseNameHelper => '作为课程唯一标识；名称相同的多条排课将归为同一课程，请填写完整名称，请勿为界面显示而缩写';

  @override
  String get pleaseEnterCourseName => '请输入课程名称';

  @override
  String get courseShortNameOptional => '课程简称';

  @override
  String get courseShortNameHelper =>
      '建议填写，用于超级岛等场景的简短展示，简称不会自动生成；启用「优先显示课程简称」后生效，建议控制在 3 个汉字以内';

  @override
  String get courseShortNameAutoFillAction => '取前两字';

  @override
  String get teacherLabel => '授课教师';

  @override
  String get courseNatureLabel => '课程性质';

  @override
  String get courseDescriptionOptional => '课程简介 (可选)';

  @override
  String get currentScheduleHint => '这里的星期、节次、教室、周次和单双周只影响当前这一条排课';

  @override
  String followProfileTimeScheme(String name) {
    return '跟随当前课表（$name）';
  }

  @override
  String get timeSchemeOverrideLabel => '上课时间方案';

  @override
  String get lessonWeeksTitle => '上课周次';

  @override
  String get singleLessonWeekHint => '单节课只会出现在一个周次里，适合补课、临时加课';

  @override
  String get rangeWeekLabel => '连续周';

  @override
  String get customWeekLabel => '自定义周';

  @override
  String get allWeeksLabel => '全部';

  @override
  String get oddWeeksLabel => '单周';

  @override
  String get evenWeeksLabel => '双周';

  @override
  String get allWeeksHint => '按开始周到结束周连续排课';

  @override
  String get oddWeeksHint => '只保留范围内的单周';

  @override
  String get evenWeeksHint => '只保留范围内的双周';

  @override
  String get customPaletteColor => '调色盘自定义颜色';

  @override
  String timeSchemeSetCountValue(int count) {
    return '$count 套';
  }

  @override
  String profileCountValue(int count) {
    return '$count 个';
  }

  @override
  String courseSectionCountValue(int count) {
    return '$count 节';
  }

  @override
  String timeSchemeStartsAt(String start) {
    return '$start 起';
  }

  @override
  String get weekdayShortMonday => '一';

  @override
  String get weekdayShortTuesday => '二';

  @override
  String get weekdayShortWednesday => '三';

  @override
  String get weekdayShortThursday => '四';

  @override
  String get weekdayShortFriday => '五';

  @override
  String get weekdayShortSaturday => '六';

  @override
  String get weekdayShortSunday => '日';

  @override
  String weekdaySectionRange(String weekday, int startSection, int endSection) {
    return '周$weekday $startSection-$endSection节';
  }

  @override
  String timeSchemeUsageReference(
    String profileName,
    String courseName,
    String weekday,
    int startSection,
    int endSection,
    String usageType,
  ) {
    return '$profileName · $courseName（周$weekday $startSection-$endSection节，$usageType）';
  }

  @override
  String weekdaySectionSummary(
    String weekday,
    int startSection,
    int endSection,
  ) {
    return '周$weekday $startSection-$endSection节';
  }

  @override
  String get timeRangeValidationNoCrossDay => '结束时间必须晚于开始时间';

  @override
  String get timeSchemeNameEmptyValidation => '时间模板名称不能为空';

  @override
  String get liveTimeCorrectionNone => '不矫正';

  @override
  String liveTimeCorrectionDelay(int seconds) {
    return '整体延后 $seconds 秒';
  }

  @override
  String liveTimeCorrectionAdvance(int seconds) {
    return '整体提前 $seconds 秒';
  }

  @override
  String liveClassReminderLeadSummaryImmediate(int seconds) {
    return '一上课进入重点提醒，下课前 $seconds 秒秒级倒数';
  }

  @override
  String liveClassReminderLeadSummaryKeepNormal(int minutes, int seconds) {
    return '课中普通通知，下课前 $minutes 分钟重点提醒';
  }

  @override
  String liveClassReminderLeadSummaryIsland(int minutes, int seconds) {
    return '下课前 $minutes 分钟切到超级岛与重点提醒';
  }

  @override
  String liveClassReminderLeadSummaryFocused(int minutes, int seconds) {
    return '下课前 $minutes 分钟开始重点提醒';
  }

  @override
  String get liveSettingsEntrySubtitle => '提醒时段、岛展示、通知栏和显示内容';

  @override
  String get timetableProfilesEntrySubtitle => '新建、切换、复制、重命名和删除课表';

  @override
  String get homeTitleSectionTitle => '首页标题';

  @override
  String get homeTitleSectionSubtitle => '控制首页左上角课表切换入口的样式';

  @override
  String get homeTitleStyleLabel => '标题样式';

  @override
  String get themeSeedSectionTitle => '应用主题色';

  @override
  String get themeSeedSectionSubtitle => '影响顶部栏、强调色和全局主色调';

  @override
  String get frostedSheetSectionTitle => '磨砂玻璃';

  @override
  String get frostedSheetSectionSubtitle =>
      '调节首页弹出面板的高斯模糊强度与磨砂亮度，滑块越靠右，白色磨砂层越明显';

  @override
  String get frostedBlurEnabledTitle => '启用模糊';

  @override
  String get frostedBlurEnabledSubtitle =>
      '关闭后，弹窗、首页模糊区域与「回本周」按钮仅保留半透明底色，不再采样模糊';

  @override
  String get frostedSheetPreviewOpenAction => '打开预览面板';

  @override
  String get frostedSheetPreviewDemoTitle => '预览';

  @override
  String get frostedSheetPreviewDemoSubtitle => '磨砂玻璃效果实时预览';

  @override
  String get frostedSheetBlurLabel => '模糊强度';

  @override
  String get frostedSheetTintLabel => '磨砂亮度';

  @override
  String get timetableBackgroundColorSectionTitle => '课表背景色';

  @override
  String get timetableBackgroundColorSectionSubtitle =>
      '纯色模式下作用于已选显示区域；可与背景图搭配使用';

  @override
  String get homePageBackgroundFillLabel => '背景填充';

  @override
  String get homePageBackgroundFillColor => '纯色';

  @override
  String get homePageBackgroundFillImage => '图片';

  @override
  String get homePageBackgroundImageTitle => '背景图';

  @override
  String get homePageBackgroundImageSubtitle => '在「图片」模式下，作用于下方勾选的显示区域';

  @override
  String get homePageWallpaperTitle => '背景图片';

  @override
  String get homePageWallpaperSubtitle => '全屏铺底一张图；勾选下方区域决定透出范围，未勾选区域仍显示课表背景色';

  @override
  String get homePageBackdropFollowsWeekPagerTitle => '背景随周次滑动';

  @override
  String get homePageBackdropFollowsWeekPagerSubtitle => '左右切换周次时，背景图与课表页面一起移动';

  @override
  String get homePageBackgroundScopeTitle => '背景显示区域';

  @override
  String get homePageBackgroundScopeSubtitle =>
      '从上到下依次控制各区域是否透出背景图；未勾选区域仍显示课表背景色';

  @override
  String get homePageBackgroundScopeStatusBar => '状态栏';

  @override
  String get homePageBackgroundScopeTimetable => '课表区域';

  @override
  String get homePageBackgroundScopeWeekdayBar => '信息栏';

  @override
  String get homePageBackgroundScopeHeader => '顶栏';

  @override
  String get homePageHeaderBlurTitle => '顶栏高斯模糊';

  @override
  String get homePageHeaderBlurSubtitle => '模糊标题栏（轻屿课表）区域；勾选「状态栏」时一并模糊状态栏';

  @override
  String get homePageWeekdayBarBlurTitle => '信息栏高斯模糊';

  @override
  String get homePageWeekdayBarBlurSubtitle => '模糊周次与星期信息栏，透出下方背景图';

  @override
  String get homePageTimeColumnBlurTitle => '时间栏高斯模糊';

  @override
  String get homePageTimeColumnBlurSubtitle => '模糊左侧节次/时间列，透出下方背景图';

  @override
  String get homePageRegionBlurSectionSubtitle => '需配合背景图使用；模糊强度跟随「弹窗磨砂玻璃」设置';

  @override
  String get homePagePickImageAction => '选择图片';

  @override
  String get homePageSwitchImageAction => '切换照片';

  @override
  String get homePageClearImageAction => '清除图片';

  @override
  String get homePageImageNotSelected => '未选择';

  @override
  String get wallpaperPositionPickerTitle => '调整壁纸显示位置';

  @override
  String get wallpaperPositionPickerResetTooltip => '重置居中';

  @override
  String get wallpaperPositionPickerDragHint => '拖动壁纸调整位置';

  @override
  String get wallpaperPositionPickerSwitchWallpaper => '换壁纸';

  @override
  String get wallpaperPositionPickerDone => '完成';

  @override
  String get wallpaperPositionPickerExit => '退出';

  @override
  String get appearanceTextColorsSectionTitle => '文字颜色';

  @override
  String get appearanceTextColorsSectionSubtitle => '自定义课程卡片、星期栏与时间轴文字颜色';

  @override
  String get defaultTimetablePreviewName => '默认课表';

  @override
  String get beforeClassDisplaySettingsTitle => '上课前提醒显示';

  @override
  String get duringEndDisplaySettingsTitle => '课中/下课提醒显示';

  @override
  String get liveDisplaySummaryShortName => '简称';

  @override
  String get liveDisplaySummaryCourseName => '课程名';

  @override
  String get liveDisplaySummaryLocation => '地点';

  @override
  String liveDisplaySummaryCountdown(String style) {
    return '倒计时（$style）';
  }

  @override
  String get liveDisplaySummaryStageText => '阶段文字';

  @override
  String get liveDisplaySummaryLeftLabelImage => '图标';

  @override
  String get liveDisplaySummaryMinimal => '最简显示';

  @override
  String get liveDisplaySummaryCountdownShort => '倒计时';

  @override
  String liveDisplaySummaryMore(String first, int count) {
    return '$first等$count项';
  }

  @override
  String get guideHyperOsChip => 'HyperOS 3.0.300+';

  @override
  String get guideStatusTitle => '当前状态';

  @override
  String get guideStatusNotificationPermission => '通知权限';

  @override
  String get guideStatusEnabled => '已开启';

  @override
  String get guideStatusDisabled => '未开启';

  @override
  String get guideStatusIslandSupport => '焦点通知 / 超级岛';

  @override
  String get guideStatusSystemAllowed => '系统已允许';

  @override
  String get guideStatusEnabledPending => '已开启但系统暂未确认';

  @override
  String get guideStatusSuggestedCheck => '建议检查';

  @override
  String get guideStatusBatteryOptimization => '电池优化';

  @override
  String get guideStatusBatteryUnrestricted => '无限制';

  @override
  String get guideStatusBatteryRestricted => '仍受限制';

  @override
  String get guideStatusKeepAlive => '后台保活辅助';

  @override
  String get guideStatusAndroidVersion => 'Android 版本';

  @override
  String get guideStatusVersionUnknown => '未识别';

  @override
  String get guideStatusIslandSystemSupport => '超级岛系统支持';

  @override
  String get guideStatusIslandSystemRequirement => '需 HyperOS 3.0.300 及以上';

  @override
  String get guideStatusIslandHint =>
      '如果你主要想用超级岛，先确认系统版本至少是 HyperOS 3.0.300，再继续把下面权限清单按顺序点完';

  @override
  String get guidePermissionChecklistTitle => '权限清单';

  @override
  String get guidePermissionChecklistSubtitle => '按这个顺序检查，最省事，也最不容易漏';

  @override
  String get guideChecklistRequestNotificationTitle => '申请通知权限';

  @override
  String get guideChecklistRequestNotificationSubtitle => '这是所有提醒的前提';

  @override
  String get guideChecklistOpenNotificationTitle => '打开通知设置';

  @override
  String get guideChecklistOpenNotificationSubtitle => '检查通知总开关、锁屏展示和实时通知权限';

  @override
  String get guideChecklistOpenIslandTitle => '打开焦点通知设置';

  @override
  String get guideChecklistOpenIslandSubtitle =>
      'HyperOS 3.0.300 及以上再检查 promoted / 超级岛通知';

  @override
  String get guideChecklistOpenAutoStartTitle => '打开自启动设置';

  @override
  String get guideChecklistOpenAutoStartSubtitle => '允许应用开机自启和后台常驻';

  @override
  String get guideChecklistOpenBatteryTitle => '打开电池策略设置';

  @override
  String get guideChecklistOpenBatterySubtitle => '建议改成无限制，避免上课提醒被中断';

  @override
  String get guideChecklistOpenKeepAliveTitle => '打开后台保活辅助';

  @override
  String get guideChecklistOpenKeepAliveSubtitle => '进一步提升超级岛和提醒在后台场景下的稳定性';

  @override
  String get guideShortNameAdviceTitle => '课程简称建议';

  @override
  String get guideShortNameAdviceSubtitle =>
      '超级岛支持显示课程简称，简称不是自动生成的，需要你在课程编辑里自己填写，建议控制在 3 个字以内，显示会更稳定';

  @override
  String get guideShortNameRecommended => '推荐示例';

  @override
  String get guideShortNameNotRecommended => '不推荐';

  @override
  String get guideShortNameRecommendedExample => '高数 / 概率 / 数控';

  @override
  String get guideShortNameNotRecommendedExample => '高等数学A(1) / 数控技术及应用';

  @override
  String get guideSetCourseShortNameAction => '去设置课程简称';

  @override
  String get guideImportMethodsTitle => '课表导入方式';

  @override
  String get guideImportMethodsSubtitle =>
      '当前版本已经支持部分学校的教务系统网页登录导入；如果你的学校还没适配，也还有其他迁移方式';

  @override
  String get guideImportMethodStep1 =>
      '优先进入“导入课程 > 教务系统导入”，选择学校和适配器后，直接在应用内打开教务网页完成导入。';

  @override
  String get guideImportMethodStep2 =>
      '如果你的学校暂时没有适配，可以先在 WakeUp 等课表应用里导入教务系统课程，再导出日历格式，最后回到本应用导入。';

  @override
  String get guideImportMethodStep3 =>
      '如果别人已经在用本应用，也可以让对方导出完整备份文件，你直接导入就能恢复课程和设置。';

  @override
  String get guideImportMethodExtra =>
      '如果你会抓包、网页调试或 JavaScript，也欢迎参与学校教务适配补充，让更多学校能直接导入。';

  @override
  String get guideFinalTipsTitle => '最后再看这 3 条';

  @override
  String get guideFinalTip1 =>
      '1. HyperOS 3.0.300 及以上才支持超级岛；如果系统版本不够，应用仍可正常发普通提醒。';

  @override
  String get guideFinalTip2 => '2. 先在设置页调整“上课前弹出”和“课中与临近下课提醒”的阈值。';

  @override
  String get guideFinalTip3 => '3. 完成系统权限设置后，再用测试通知验证；如果岛区还是偶尔消失，优先检查自启动和省电策略。';

  @override
  String get guidePrivacyHelperRequireConsent =>
      '你勾选同意后，代表你已阅读并同意上述友盟相关说明、隐私内容与免责提示';

  @override
  String get guidePrivacyHelperViewOnly =>
      '这里保留与首次启动一致的隐私、第三方 SDK 与免责说明，方便你随时查看；当前页面不需要再次勾选同意';

  @override
  String get guidePrivacySectionTitle => '隐私、第三方 SDK 与免责说明';

  @override
  String get guidePrivacyParagraph1 =>
      '本应用主体功能按本地运行方式设计，课表、时间模板、课程记录和大部分设置默认保存在你的设备本地。';

  @override
  String get guidePrivacyParagraph2 =>
      '只有在你主动使用检查更新、下载更新、导入导出等联网功能，或你勾选同意后初始化友盟相关 SDK 时，应用才会与外部服务发生数据交互。';

  @override
  String get guidePrivacyParagraph3 =>
      '本应用接入友盟移动统计 SDK、友盟应用性能监控 SDK 以及高级运营分析依赖库。它们的服务用途包括移动统计分析、应用性能监控以及高级运营分析相关能力；只有在你勾选同意后，这些 SDK 才会正式初始化。';

  @override
  String get guidePrivacyParagraph4 =>
      '按友盟官方说明，这些 SDK 可能处理的信息包括：设备信息（如 IMEI、MAC、Android ID、OAID、IDFA、OpenUDID、GUID、SIM 卡 IMSI 等）、网络状态、设备标识，以及高级运营分析依赖库涉及的应用列表和地理位置相关信息。';

  @override
  String get guideRiskTitle => '免责与风险提示';

  @override
  String get guideRiskParagraph1 =>
      '1. 超级岛、焦点通知、后台提醒和保活效果依赖系统版本、机型、厂商策略、权限、自启动、电池策略等外部条件，无法保证所有设备表现完全一致。';

  @override
  String get guideRiskParagraph2 =>
      '2. 检查更新、镜像下载、系统下载器、导入导出与分享等能力依赖网络环境、第三方服务和系统文件能力；若出现失败、限速或文件异常，请以 Release 页面、你自己保存的备份文件和系统提示为准。';

  @override
  String get guideRiskParagraph3 =>
      '3. 在迁移、导入或覆盖数据前，请先自行确认备份文件完整可用，并妥善保管含有课表信息的文件；因用户自行删除、覆盖、分享或保管不当造成的数据问题，需要由用户自行承担相应风险。';

  @override
  String get guideUmengPrivacyLink =>
      '友盟隐私政策：https://www.umeng.com/page/policy';

  @override
  String get liveDiagnosticsUnavailable => '当前还没有可查看的应用日志';

  @override
  String get liveDiagnosticsViewerTitle => '超级岛日志';

  @override
  String get liveDiagnosticsShareText => '这是轻屿课表导出的超级岛相关日志，可用于排查“超级岛没有弹出”等问题';

  @override
  String get liveDiagnosticsShareSubject => '轻屿课表 - 超级岛日志';

  @override
  String get liveDiagnosticsSnapshotShareText =>
      '这是轻屿课表当前测试诊断页导出的超级岛状态快照，可用于排查“超级岛没有弹出”等问题';

  @override
  String get liveDiagnosticsSnapshotShareSubject => '轻屿课表 - 超级岛状态快照';

  @override
  String get liveDiagnosticsNothingToExport => '当前没有可导出的日志文件，也没有可导出的状态快照';

  @override
  String get liveDiagnosticsCleared => '已清空应用日志';

  @override
  String get liveDiagnosticsClearFailed => '清空应用日志失败';

  @override
  String get liveTestingNotRefreshed => '尚未刷新';

  @override
  String get liveTestingTitle => '测试与诊断';

  @override
  String get liveTestingNotificationTitle => '测试通知';

  @override
  String get liveTestingNotificationSubtitle => '用于验证超级岛、通知栏和课程简称等显示效果';

  @override
  String get liveTestingStartAction => '开始测试';

  @override
  String get liveTestingCancelAction => '取消测试';

  @override
  String get liveTestingSessionRunning => '自检测试进行中';

  @override
  String get liveTestingSessionCanceled => '已取消自检测试';

  @override
  String get liveTestingUmengHint => '下面两个按钮仅测试版显示，用于验证友盟 U-APM 崩溃和卡顿上报';

  @override
  String get liveTestingCrashAction => '崩溃测试';

  @override
  String get liveTestingAnrAction => '异常卡顿测试';

  @override
  String get liveTestingIslandStatusTitle => '上岛状态诊断';

  @override
  String get liveTestingIslandStatusSubtitle => '这里直接显示原生实时服务、通知构造结果和不上岛原因';

  @override
  String get liveTestingServiceStatusRunning => '服务运行中';

  @override
  String get liveTestingServiceStatusStopped => '服务未运行';

  @override
  String get liveTestingNoIslandReasonTitle => '不上岛原因';

  @override
  String get liveTestingNoIslandReasonEmpty => '当前无拦截原因';

  @override
  String get liveTestingRefreshAction => '刷新诊断';

  @override
  String get liveTestingRefreshing => '刷新中';

  @override
  String get liveTestingExportAction => '导出并分享日志';

  @override
  String get liveTestingExporting => '导出中';

  @override
  String get liveTestingAutoRefreshTitle => '自动刷新';

  @override
  String liveTestingAutoRefreshOn(int seconds) {
    return '每 $seconds 秒自动拉取一次诊断状态';
  }

  @override
  String get liveTestingAutoRefreshOff => '关闭后只在手动刷新时更新，便于稳定查看当前状态';

  @override
  String liveTestingRefreshedAt(String time) {
    return '上次刷新：$time';
  }

  @override
  String get liveTestingSectionEnvironment => '环境与权限';

  @override
  String get liveTestingSectionService => '服务状态';

  @override
  String get liveTestingSectionCourse => '课程数据';

  @override
  String get liveTestingSectionTiming => '时间与阶段';

  @override
  String get liveTestingSectionSwitches => '阶段开关';

  @override
  String get liveTestingSectionDisplay => '岛显示配置';

  @override
  String get liveTestingSectionNotification => '通知判定结果';

  @override
  String get liveTestingSectionRecentLogs => '最近诊断日志';

  @override
  String get liveTestingRawDataTitle => '原始调试数据';

  @override
  String get liveTestingRawDataSubtitle => '默认折叠，排查时再展开核对完整原生字段';

  @override
  String get liveTestingExpandRawJson => '展开原始 JSON';

  @override
  String get liveTestingExpandRawJsonSubtitle => '避免大段原始字段一直占满页面';

  @override
  String get liveTestingLocalLogsTitle => '本地诊断日志';

  @override
  String get liveTestingLocalLogsSubtitle =>
      '一键导出日志文件，直接通过系统分享发给开发者；也可以清空后重新收集';

  @override
  String get liveTestingClearLogsAction => '清空日志';

  @override
  String get liveTestingClearingLogs => '清空中';

  @override
  String get liveTestingViewPhoneLogsAction => '查看手机日志';

  @override
  String get liveTestingMoreTesterOptionsAction => '更多测试者选项';

  @override
  String get yesLabel => '是';

  @override
  String get noLabel => '否';

  @override
  String get liveTestingCurrentNativeFieldsSubtitle => '显示当前原生诊断字段';

  @override
  String get liveTestingCrashSoon => '即将触发友盟 U-APM 测试崩溃，请重新打开应用查看后台是否收到上报';

  @override
  String get liveTestingAnrSoon =>
      '即将触发约 30 秒主线程卡死，请脱离 flutter run 测试，并在卡死后重新打开应用查看友盟后台';

  @override
  String get liveTestingNoCourseAvailable => '当前没有可测试的课程';

  @override
  String get liveTestingPresetArmedButHidden =>
      '已注入自检预设课程，但超级岛此刻不会弹出——若「上课前提醒」已关闭，岛会在课程真正开始后（约 1 分钟后）才出现';

  @override
  String get liveTestingHolidayBlocked =>
      '当前在假期范围内，超级岛在假期期间不显示；如需测试，请先在「课表设置 → 节假日标记」中移除覆盖今天的假期';

  @override
  String get liveTestingNotIslandHoliday =>
      '当前在假期范围内——超级岛在假期期间不显示，可在「课表设置 → 节假日标记」中管理假期';

  @override
  String get liveTestingCourseTestAction => '选课测试';

  @override
  String get liveTestingCourseTestPickerTitle => '选择要测试的课程';

  @override
  String get liveTestingCourseTestStageTitle => '选择要预览的阶段';

  @override
  String get liveTestingCourseTestStageBeforeClass => '课前倒计时（岛保持约 3 分钟）';

  @override
  String get liveTestingCourseTestStageDuringClass => '上课中（岛保持约 4 分钟）';

  @override
  String liveTestingCourseTestActiveChip(String course) {
    return '选课测试中 · $course';
  }

  @override
  String get liveTestingCourseTestStopAction => '停止测试';

  @override
  String liveTestingCourseTestStartedToast(String course, String stage) {
    return '已强制启动「$course」的超级岛测试（$stage）。请按 Home 键回桌面查看；岛会在测试窗口结束后自动收岛并恢复正式调度';
  }

  @override
  String get liveTestingCourseTestStoppedToast => '已停止选课测试，正式调度已恢复';

  @override
  String get liveTestingInFlight => '测试进行中，请勿重复点击，请稍后再试';

  @override
  String get liveTestingProductionHomeHint =>
      '已走正式超级岛选课路径。请按 Home 键回到桌面查看（停留在应用内时系统通常不会弹出）';

  @override
  String get liveTestingPresetFallbackNote => '（未检测到可测试的真实课程，已改用自检预设课程，不会写入课表）';

  @override
  String get liveTestingTestCourseNote => '此处显示备注，可以在课程编辑页进行设置';

  @override
  String get liveTestingNotificationSent => '已发送上课提醒测试通知，约 8 秒内会进入上课前提醒阶段';

  @override
  String sendFailedWithError(String error) {
    return '发送失败: $error';
  }

  @override
  String get homeWidgetSettingsTitle => '桌面小组件';

  @override
  String get homeWidgetTodayCourseTitle => '今日课程组件';

  @override
  String get homeWidgetTodayCourseSubtitle =>
      '首批支持 2×2、2×4、4×4 三种尺寸，点击小组件会直接打开首页，课程开始和结束时会主动刷新';

  @override
  String get homeWidgetQuickAddTitle => '快速添加到桌面';

  @override
  String get homeWidgetCheckingPinSupport => '正在检查当前桌面是否支持应用内添加小组件…';

  @override
  String get homeWidgetPinSupported => '支持的话会直接弹出系统添加确认，不是单独的权限弹窗；确认后即可固定到桌面';

  @override
  String get homeWidgetPinUnsupported =>
      '当前桌面不支持应用内直接添加时，仍可长按桌面 → 小组件 → 轻屿课表 手动添加';

  @override
  String get homeWidgetBackgroundStyleLabel => '背景样式';

  @override
  String get homeWidgetShowLocationTitle => '显示地点';

  @override
  String get homeWidgetShowLocationSubtitle => '关闭后改显周次与课程数';

  @override
  String get homeWidgetShowCountdownTitle => '显示倒计时';

  @override
  String get homeWidgetShowCountdownSubtitle => '显示下节课倒计时';

  @override
  String get homeWidgetCountdownLeadTitle => '倒计时提前量';

  @override
  String get homeWidgetCountdownLeadSubtitle => '设置上课前多少分钟自动切换到倒计时模式';

  @override
  String get homeWidgetCountdownLeadAlways => '始终显示';

  @override
  String homeWidgetCountdownLeadMinutes(String minutes) {
    return '上课前 $minutes 分钟';
  }

  @override
  String get widgetCountdownStyleTitle => '倒计时样式';

  @override
  String get homeWidgetHideCompletedTitle => '隐藏已上完课程';

  @override
  String get homeWidgetHideCompletedSubtitle => '只显示未结束的课程';

  @override
  String get homeWidgetShowTomorrowTitle => '课后显示明日课程';

  @override
  String get homeWidgetShowTomorrowSubtitle => '今日课后自动显示明天课程';

  @override
  String get homeWidgetAppearanceTitle => '卡片外观';

  @override
  String get homeWidgetHeightAdjustTitle => '卡片高度';

  @override
  String get homeWidgetHeightAdjustHint => '范围 -16 ~ 16，0 为默认档：正数比默认更高，负数更矮';

  @override
  String get defaultLabel => '默认';

  @override
  String higherByValue(String value) {
    return '更高 $value';
  }

  @override
  String lowerByValue(String value) {
    return '更矮 $value';
  }

  @override
  String get homeWidgetCornerRadiusTitle => '卡片圆角';

  @override
  String get homeWidgetDescriptionTitle => '说明';

  @override
  String get homeWidgetDescriptionText =>
      '小组件目前优先展示今日课程，无课状态会保持完整卡片，不会出现空白；如果你切换课表或修改样式，桌面组件也会跟着刷新';

  @override
  String homeWidgetPinRequested(String label) {
    return '已发起“$label”添加请求，请在系统弹窗里确认并放到桌面';
  }

  @override
  String homeWidgetPinUnsupportedManual(String label) {
    return '当前系统桌面不支持应用内直接添加小组件，请长按桌面 → 小组件 → 轻屿课表，再手动添加“$label”';
  }

  @override
  String get homeWidgetInvalidType => '小组件类型无效，请稍后重试';

  @override
  String homeWidgetPinFailedManual(String label) {
    return '发起添加失败，请长按桌面 → 小组件 → 轻屿课表，再手动添加“$label”';
  }

  @override
  String get homeWidgetBindingSectionTitle => '各卡片绑定管理';

  @override
  String get homeWidgetBindingFollowActive => '跟随当前课表';

  @override
  String get homeWidgetBindingEmpty => '桌面上还没有今日课程卡片，先添加一张再回来绑定';

  @override
  String get homeWidgetBindingSaveFailed => '保存卡片绑定失败，请稍后重试';

  @override
  String get homeWidgetBindingMissingToast => '这张卡片绑定的课表已失效，已按普通方式打开';

  @override
  String get homeWidgetExactAlarmBannerTitle => '精确闹钟权限未授予';

  @override
  String get homeWidgetExactAlarmBannerText =>
      '未授予「闹钟和提醒」权限时，课程边界只能非精确刷新，桌面卡片可能延迟更新，建议授权以保证按课程时间精确刷新';

  @override
  String get homeWidgetExactAlarmGrantAction => '去授权';

  @override
  String get homeWidgetExactAlarmOpenFailed => '打开授权页失败，请到系统设置中手动开启「闹钟和提醒」权限';

  @override
  String get homeWidgetExactAlarmFallbackHint =>
      '已在系统设置中打开应用信息，请在其中开启「闹钟和提醒」权限';

  @override
  String get layoutSettingsTitle => '布局与节次';

  @override
  String get layoutDensityTitle => '课表密度';

  @override
  String get layoutAutoFitHeightTitle => '自动充满屏幕高度';

  @override
  String get layoutAutoFitHeightSubtitle => '开启后会按当前节数自动铺满页面底部，不再保留下方空隙';

  @override
  String get layoutHideWeekendsTitle => '隐藏周六周日';

  @override
  String get layoutHideWeekendsSubtitle => '开启后首页只显示周一到周五，剩余列宽会自动铺满';

  @override
  String get layoutEnableHapticsTitle => '启用应用内震动反馈';

  @override
  String get layoutEnableHapticsSubtitle => '关闭后，页码切换等交互不再触发轻微震动';

  @override
  String pageTransitionSpeedLabel(String speed) {
    return '页面转场速度 $speed×';
  }

  @override
  String get pageTransitionSpeedTitle => '页面转场速度';

  @override
  String get pageTransitionSpeedSubtitle =>
      '调节进入和返回子页面时的滑动动画快慢，数值越大越快，越小越慢；会叠加系统「过渡动画缩放」设置';

  @override
  String pageTransitionSpeedDurationHint(int milliseconds) {
    return '约 $milliseconds 毫秒';
  }

  @override
  String get layoutTimeColumnDisplayLabel => '首页时间列显示';

  @override
  String get layoutTimeColumnWidthLabel => '时间栏宽度';

  @override
  String get layoutBackToCurrentWeekButtonStyleLabel => '“回本周”按钮样式';

  @override
  String get layoutBackToCurrentWeekButtonStyleHelper =>
      '默认保持现在的内嵌样式；也可以改成周视图右下角的小型悬浮按钮';

  @override
  String get layoutBackToCurrentWeekButtonStyleInline => '时间栏内嵌';

  @override
  String get layoutBackToCurrentWeekButtonStyleFloating => '右下角悬浮';

  @override
  String layoutBackToCurrentWeekButtonOpacityLabel(int value) {
    return '悬浮按钮不透明度 $value%';
  }

  @override
  String get layoutBackToCurrentWeekButtonOpacityTitle => '悬浮按钮不透明度';

  @override
  String get layoutBackToCurrentWeekButtonOpacitySubtitle => '只对右下角悬浮样式生效';

  @override
  String layoutCourseCardGapLabel(String value) {
    return '课程卡片间距 $value';
  }

  @override
  String get layoutCourseCardGapTitle => '课程卡片间距';

  @override
  String layoutSectionHeightLabel(String value) {
    return '课表行高 $value';
  }

  @override
  String get layoutSectionHeightTitle => '课表行高';

  @override
  String layoutCompactFontSizeLabel(String value) {
    return '紧凑字号 $value';
  }

  @override
  String get layoutCompactFontSizeTitle => '紧凑字号';

  @override
  String layoutCourseCardFontSizeLabel(String value) {
    return '课程卡片字号 $value';
  }

  @override
  String get layoutCourseCardFontSizeTitle => '课程卡片字号';

  @override
  String get layoutCourseCardDisplayTitle => '课程卡片显示';

  @override
  String get layoutCourseCardDisplaySubtitle => '默认显示课程名、老师和教室；其他信息可按课表自由开关组合';

  @override
  String get layoutShowTeacherTitle => '显示老师';

  @override
  String get layoutShowClassroomTitle => '显示教室';

  @override
  String get layoutShowTimeTitle => '显示时间';

  @override
  String get layoutShowTimeLabelsTitle => '显示上下课字样';

  @override
  String get layoutShowTimeLabelsSubtitle => '关闭后仅显示时间点，不显示“上课”“下课”文字';

  @override
  String get layoutShowWeeksTitle => '显示周数';

  @override
  String get layoutShowWeeksSubtitle => '例如第 1-16 周、单双周';

  @override
  String get layoutShowDescriptionTitle => '显示课程简介';

  @override
  String get layoutShowDescriptionSubtitle => '默认关闭，空间不足时会最先被压缩';

  @override
  String get layoutShowOtherWeeksTitle => '显示非本周课程';

  @override
  String get layoutShowOtherWeeksSubtitle => '非本周课程以半透明灰色显示';

  @override
  String get layoutVerticalAlignLabel => '垂直排版';

  @override
  String get layoutHorizontalAlignLabel => '水平排版';

  @override
  String get layoutShowConflictBadgeTitle => '首页显示冲突小胶囊';

  @override
  String get layoutShowConflictBadgeSubtitle => '关闭后，首页课表不再对冲突课程显示“冲突”小胶囊';

  @override
  String layoutConflictOpacityLabel(int value) {
    return '冲突课程透明度 $value%';
  }

  @override
  String get layoutConflictOpacityTitle => '冲突课程透明度';

  @override
  String get layoutConflictOpacitySubtitle => '冲突课程会自动层叠显示，调低透明度后能同时看到多节课';

  @override
  String get layoutTipsText =>
      '时间模板已移到设置首页，这里主要调课表行高、时间列、周末显示和课程卡片布局；如果你想只改当前课表的时间，先在时间模板里复制一套再应用';

  @override
  String currentWeekCompact(int week) {
    return '$week周';
  }

  @override
  String get sampleCourseNumericalControl => '数控';

  @override
  String get sampleCourseAdvancedMath => '高数';

  @override
  String get sampleTeacherZhang => '张老师';

  @override
  String get sampleCourseEnglish => '英语';

  @override
  String get sampleTeacherLi => '李老师';

  @override
  String get aboutRepositorySheetTitle => '开源仓库';

  @override
  String get aboutRepositorySheetHint =>
      '如果你想补学校教务导入适配，建议同时查看教务适配仓 qingyu_warehouse';

  @override
  String get aboutOpenGitHubAction => '打开 GitHub';

  @override
  String get aboutOpenWarehouseRepoAction => '打开教务适配仓';

  @override
  String get copiedRepositoryAddress => '已复制仓库地址';

  @override
  String get copiedWarehouseRepositoryAddress => '已复制教务适配仓地址';

  @override
  String get aboutUpdateScreenTitle => '版本更新';

  @override
  String get aboutUpdateStatusTitle => '更新状态';

  @override
  String get aboutRefreshCheckTooltip => '重新检查';

  @override
  String get aboutCheckingLatestVersion => '正在检查最新版本信息…';

  @override
  String get aboutCheckingForUpdate => '正在检测更新…';

  @override
  String get aboutReadVersionFailed => '暂时无法读取版本信息，请稍后重试';

  @override
  String get aboutReadVersionFailedHint =>
      '如果你当前网络访问 GitHub 不稳定，可稍后再试，或切到下面的国内下载方式后重试';

  @override
  String get aboutViewReleaseAction => '查看 Release';

  @override
  String get aboutDownloadNowAction => '立即下载';

  @override
  String get aboutOpenDownloadPageAction => '打开下载页';

  @override
  String get aboutCurrentVersionLabel => '当前版本';

  @override
  String get aboutLatestVersionLabel => '最新版本';

  @override
  String get aboutUnreleasedLabel => '未发布';

  @override
  String get aboutVersionChannelLabel => '版本通道';

  @override
  String get aboutPrereleaseChannel => '测试版';

  @override
  String get aboutUpdateAvailableHint =>
      '你现在只需要点下面的“立即下载”即可，测速、镜像和测试版都已经收进后面的高级选项里';

  @override
  String get aboutUpdateNoUpdateHint =>
      '当前版本已经可正常使用；如果你要体验测试版，可以在后面的高级选项里打开测试版检测';

  @override
  String aboutUpdatedAt(String time) {
    return '更新时间：$time';
  }

  @override
  String get aboutUpdateNowTitle => '立即更新';

  @override
  String get aboutUpdateNowAndroidSubtitle =>
      '普通使用只需要点一次立即下载，下载慢、下载失败、要换线路时，再去下面的高级选项';

  @override
  String get aboutUpdateNowOtherSubtitle => '当前平台会直接打开下载页面，不会在应用内安装';

  @override
  String get aboutMirrorDownloadHint => '当前会优先使用国内下载，大多数国内网络直接点“立即下载”就行';

  @override
  String get aboutOriginalDownloadHint => '当前会优先使用国际源下载，如果下载慢或打不开，建议先切回“国内下载”';

  @override
  String get aboutUseSystemDownloaderAction => '使用系统下载器下载';

  @override
  String get aboutOpenReleasePageAction => '打开 Release 页面';

  @override
  String get aboutDownloadMethodTitle => '下载方式';

  @override
  String get aboutDownloadMethodSubtitle =>
      '默认推荐国内下载，只有你能稳定访问 GitHub 时，再切到国际源下载';

  @override
  String get aboutDownloadMethodMirror => '国内下载';

  @override
  String get aboutDownloadMethodOriginal => '国际源下载';

  @override
  String aboutMirrorModeHintRecommended(String current, String recommended) {
    return '当前使用国内下载 · $current，系统最近测速更推荐“$recommended”，需要时可在后面的高级选项里切换';
  }

  @override
  String aboutMirrorModeHintCurrent(String current) {
    return '当前使用国内下载 · $current，如果下载慢或失败，再到后面的高级选项里测速、换线路或填写自定义地址';
  }

  @override
  String get aboutOriginalModeHint =>
      '当前使用国际源下载，只有你网络能稳定访问 GitHub 时才建议这样设置；否则请切回国内下载';

  @override
  String get aboutReleaseNotesTitle => '本次更新说明';

  @override
  String get aboutReleaseNotesSubtitle => '显示当前检测到版本的 Release 说明';

  @override
  String get aboutAdvancedOptionsTitle => '高级选项';

  @override
  String get aboutAdvancedOptionsSubtitle => '只有下载慢、要手动切线路、或要检测测试版时再展开';

  @override
  String get aboutMirrorSectionTitle => '下载线路与镜像';

  @override
  String get aboutMirrorSectionMirrorHint =>
      '当前使用国内下载，这里可以手动切线路、测速推荐，或填写自定义下载地址';

  @override
  String get aboutMirrorSectionOriginalHint =>
      '你现在使用的是国际源下载，下面的线路设置只有在切回“国内下载”后才会生效';

  @override
  String get aboutFillCustomMirrorFirst => '先填写自定义下载地址';

  @override
  String get aboutCurrentCustomMirrorTitle => '当前自定义下载地址';

  @override
  String get aboutCurrentMirrorTitle => '当前下载线路地址';

  @override
  String get aboutCurrentCustomMirrorHint => '当前正在使用你手动填写的下载地址';

  @override
  String get aboutCurrentMirrorHint => '如果当前线路访问失败，可以切到其他内置线路，或改用自定义地址';

  @override
  String get aboutProbeMirrorsAction => '测速并推荐';

  @override
  String get aboutProbingMirrors => '测速中…';

  @override
  String get aboutEditCustomMirrorAction => '修改自定义地址';

  @override
  String get aboutSetCustomMirrorAction => '填写自定义地址';

  @override
  String aboutSwitchToRecommendedAction(String label) {
    return '切到推荐：$label';
  }

  @override
  String get aboutMirrorDisabledHint =>
      '当前没有使用国内下载，所以这里的线路设置暂时不会生效，需要的话，请先在上面的“下载方式”里切回国内下载';

  @override
  String get aboutRecentProbeResultsTitle => '最近测速结果';

  @override
  String get aboutUnavailable => '不可用';

  @override
  String get aboutRecommended => '推荐';

  @override
  String get aboutCheckPrereleaseTitle => '检测测试版本';

  @override
  String get aboutCheckPrereleaseSubtitle => '打开后会把测试版也纳入更新检查；普通使用建议关闭';

  @override
  String get aboutUpdatePromptTitle => '弹窗提醒';

  @override
  String get aboutUpdatePromptSubtitle => '发现新版本时在首页自动弹窗，关闭后仅显示红点角标';

  @override
  String get aboutDiagnosticsTitle => '测试与诊断';

  @override
  String get aboutDiagnosticsSubtitle => '只有遇到“超级岛没弹出”或需要给开发者反馈时再展开';

  @override
  String get aboutRecordDiagnosticsTitle => '记录应用日志';

  @override
  String get aboutRecordDiagnosticsSubtitle =>
      '打开后会在本地持续记录应用运行日志；超级岛相关日志会单独标注来源';

  @override
  String get aboutExportDiagnosticsAction => '导出应用日志';

  @override
  String get aboutViewPhoneLogsAction => '打开日志页';

  @override
  String get aboutClearAndRecollectAction => '清空并重新收集';

  @override
  String get aboutLiveDiagnosticsEnabled => '已开启应用日志记录';

  @override
  String get aboutLiveDiagnosticsDisabled => '已关闭应用日志记录';

  @override
  String get aboutNoDiagnosticsExportYet => '还没有可导出的应用日志';

  @override
  String get aboutProbeNoMirrorFound => '测速完成，但暂时没有发现可用镜像线路';

  @override
  String aboutProbeCurrentFastest(String label) {
    return '测速完成，当前线路“$label”已是最快可用线路';
  }

  @override
  String aboutProbeRecommendSwitch(String label) {
    return '测速完成，推荐切换到“$label”';
  }

  @override
  String get switchAction => '切换';

  @override
  String aboutSwitchToMirrorAfterError(String error) {
    return '$error，可切到国内镜像后再试';
  }

  @override
  String aboutSwitchPresetAfterError(String error, String label) {
    return '$error，建议切换到“$label”后重试';
  }

  @override
  String get aboutSetMirrorSourceTitle => '设置镜像源';

  @override
  String get aboutMirrorPrefixLabel => '镜像前缀';

  @override
  String get aboutMirrorPrefixInvalid => '镜像源格式不正确，请输入完整的 http 或 https 地址';

  @override
  String get aboutMirrorSaved => '镜像源已保存';

  @override
  String get aboutDownloadCancelled => '已取消下载';

  @override
  String get aboutInstallReady => '安装包已准备好，已尝试打开安装界面；如果系统没有弹出，请稍后从通知或文件管理器手动安装';

  @override
  String get aboutUpdatePackageTitle => '轻屿课表更新包';

  @override
  String get aboutUpdatePackageDescription => '已交给系统下载管理器下载，完成后可直接从系统通知安装';

  @override
  String get aboutSystemDownloaderQueued => '已交给系统下载管理器，请在系统通知或下载列表里查看进度';

  @override
  String get aboutSystemDownloaderFailed => '调用系统下载管理器失败';

  @override
  String get aboutDownloadCancelling => '正在取消下载…';

  @override
  String aboutDownloadingBytes(String value) {
    return '正在下载更新 $value';
  }

  @override
  String aboutDownloadingPercent(String value) {
    return '正在下载更新 $value%';
  }

  @override
  String get aboutMirrorUnknownSizeHint => '镜像源未返回文件总大小，先显示已下载体积';

  @override
  String get aboutCancelDownloadAction => '取消下载';

  @override
  String get aboutContinueDownloadAction => '继续下载';

  @override
  String get aboutDismissDialogAction => '关闭弹窗';

  @override
  String get aboutContributorsScreenTitle => '代码贡献者';

  @override
  String get aboutDevelopersTitle => '开发人员';

  @override
  String get aboutDeveloperMaintainerSubtitle => '轻屿课表开发与维护';

  @override
  String get aboutWarehouseMaintainersTitle => '教务导入适配者';

  @override
  String get aboutWarehouseMaintainersIntro =>
      '以下名单来自 qingyu_warehouse 适配仓的 maintainer 字段汇总，若本地已有缓存，会先显示缓存，再后台刷新';

  @override
  String aboutWarehouseMaintainersLoadFailed(String error) {
    return '暂时无法读取适配者名单：$error';
  }

  @override
  String get aboutWarehouseMaintainersEmpty => '当前还没有读取到适配者信息';

  @override
  String aboutWarehouseMaintainerCount(int count) {
    return '$count 个适配项';
  }

  @override
  String get aboutParticipateWarehouseTitle => '参与教务适配';

  @override
  String get aboutParticipateWarehouseSubtitle =>
      '如果你会抓包、网页调试、JavaScript，或者愿意长期维护自己学校的教务系统，欢迎去 qingyu_warehouse 提交新的学校适配与修复';

  @override
  String get importFileReadFailed => '无法读取所选文件';

  @override
  String get importCleartextBlockedHint => '该站点暂不支持 HTTPS 访问且未在明文白名单内，无法在此打开';

  @override
  String get importReplaceExistingTitle => '导入课程';

  @override
  String importReplaceExistingMessage(String name) {
    return '导入 $name 时，是否替换现有课程？此操作也会清空当前课表上的独立日程（如自习、会议等）。';
  }

  @override
  String get importNoCoursesRecognized => '未识别到可导入课程';

  @override
  String get importConfirmSemesterMappingTitle => '确认开学日期和周次对应';

  @override
  String get importConfirmSemesterMappingSubtitleIcs =>
      '请选择学校校历的开学日期，系统已根据文件里最早的上课日期给出默认周次对应，你也可以手动调整';

  @override
  String importOverwriteCount(int count) {
    return '已覆盖导入 $count 条课程';
  }

  @override
  String importUpdatedCount(int count) {
    return '已更新课表：新增或更新 $count 条课程';
  }

  @override
  String get importNoCourseChanges => '没有需要新增或更新的课程';

  @override
  String get aiImportTitle => '识图导入';

  @override
  String aiPreviewSummary(
    int courseCount,
    int sectionCount,
    String warningSuffix,
  ) {
    return '识别到 $courseCount 门课，最高到第 $sectionCount 节$warningSuffix';
  }

  @override
  String aiWarningCountSuffix(int count) {
    return '，$count 条提醒';
  }

  @override
  String get aiWorkflowCompactTitle => '复制提示词 -> 豆包识图 -> 导入';

  @override
  String get aiWorkflowCompactSubtitle => '豆包专家模式 -> 复制 JSON -> 选择开学日期';

  @override
  String get aiWorkflowTitle => '复制提示词 -> 豆包识图 -> 粘贴 JSON -> 导入';

  @override
  String get aiWorkflowSubtitle =>
      '先复制提示词，再到豆包左下角切换为专家模式，把课表截图和提示词一起发过去，把豆包返回的 JSON 复制回这里，点击导入后再选择开学日期';

  @override
  String get aiPromptShortAction => '提示词';

  @override
  String get aiExpertModeSuggestion => '建议豆包专家模式，支持多图，截图需带星期表头';

  @override
  String get aiHintExpertMode => '先切到豆包专家模式';

  @override
  String get aiHintSendScreenshot => '截图和提示词一起发';

  @override
  String get aiHintCopyJsonBack => '返回结果复制 JSON';

  @override
  String get aiHintPickSemesterAfterImport => '导入后再选开学日期';

  @override
  String get jsonLabelShort => 'JSON';

  @override
  String get aiPasteJsonTitle => '粘贴 AI 返回的 JSON';

  @override
  String aiCourseCountChip(int count) {
    return '$count 门课';
  }

  @override
  String get aiParseFailedChip => '解析失败';

  @override
  String get aiPasteJsonHintShort => '粘贴 AI 返回的 JSON';

  @override
  String get aiPasteJsonHintLong =>
      '把豆包返回的 JSON 原样粘贴到这里，然后点击导入，支持纯 JSON，也兼容 ```json 代码块';

  @override
  String get detailAction => '详情';

  @override
  String get aiParseErrorTitle => '解析错误';

  @override
  String get viewDetailsAction => '查看详情';

  @override
  String get aiWorkflowFooter =>
      '复制提示词 -> 豆包发送截图和提示词 -> 把 JSON 贴回这里 -> 点击导入 -> 选择开学日期';

  @override
  String get previewAction => '预览';

  @override
  String get confirmImportAction => '确认导入';

  @override
  String get promptCopiedHint => '提示词已复制，去豆包发送截图和提示词';

  @override
  String get clipboardNoText => '剪贴板里没有可用文本';

  @override
  String get aiPromptSheetTitle => '识图提示词';

  @override
  String get aiPromptSheetSubtitle =>
      '建议使用豆包，先把豆包左下角切换为专家模式，再把下面整段提示词和课表截图一起发过去，让它只返回 JSON，生成后把 JSON 复制回本页，点击导入后再选择开学日期';

  @override
  String get aiPreviewTitle => '解析预览';

  @override
  String get aiPasteJsonFirst => '请先粘贴 AI 返回的 JSON';

  @override
  String get aiParseFailedIncompleteJson => '解析失败，请确认粘贴的是完整 JSON';

  @override
  String get importAiResultTitle => '导入 AI 解析结果';

  @override
  String get importAiReplaceMessage =>
      '是否用当前这份 AI 解析结果替换现有课程？此操作也会清空当前课表上的独立日程（如自习、会议等）。';

  @override
  String get importConfirmSemesterMappingSubtitleAi =>
      '请选择学校校历的开学日期，再确认课表里的第 1 周对应校历第几周，如果学校第一周没课，这里通常要改成第 2 周';

  @override
  String aiWarningExtraSuffix(int count) {
    return '，另有 $count 条识别提醒';
  }

  @override
  String get pasteAction => '粘贴';

  @override
  String get importConfirmSemesterMappingSubtitleWarehouse =>
      '教务脚本已返回课程周次，请确认校历开学日期；如果学校前几周没有课，可把“课表第 1 周”对应到校历后面的周次';

  @override
  String aiPreviewCourseCount(int count) {
    return '课程数量：$count';
  }

  @override
  String aiPreviewMaxSection(int section) {
    return '最大节次：第 $section 节';
  }

  @override
  String get aiPreviewWarningsTitle => '识别提醒';

  @override
  String get aiPreviewCoursesTitle => '课程预览';

  @override
  String aiPreviewRemainingCourses(int count) {
    return '其余 $count 条将在导入后写入当前课表';
  }

  @override
  String get warehouseMissingSchoolTitle => '学校列表里没有你的学校？';

  @override
  String get warehouseMissingSchoolSubtitle =>
      '去反馈页提一个 Issue 就行，建议一起写上学校名称、教务系统网址、登录后课表页链接或截图，这样更方便补适配';

  @override
  String get laterAction => '稍后再说';

  @override
  String get goFeedbackAction => '去反馈页';

  @override
  String get warehouseFeedbackMissingSchoolTitle => '缺少学校？去反馈';

  @override
  String get warehouseCustomDebugTitle => '自定义调试';

  @override
  String get warehouseImportExecutionLogTitle => '课表导入执行日志';

  @override
  String get warehouseImportExecutionLogMenuLabel => '课表导入执行日志';

  @override
  String get warehouseImportExecutionLogShareText =>
      '这是轻屿课表导出的教务导入执行日志，包含脚本注入、桥接消息、超时与导入结果等过程记录，可直接反馈给开发人员排查问题';

  @override
  String get warehouseImportExecutionLogShareSubject => '轻屿课表 - 课表导入执行日志';

  @override
  String get warehouseImportExecutionLogEmpty =>
      '暂无导入执行记录。请先打开教务网页并执行导入脚本，再回来查看。';

  @override
  String get warehouseRootLoadFailedTitle => '暂时无法读取适配仓';

  @override
  String get searchSchoolHint => '搜索学校名称、首字母或代码';

  @override
  String get clearSearchTooltip => '清空';

  @override
  String get noMatchingSchools => '没有找到匹配的学校';

  @override
  String get noAvailableSchools => '暂无可用学校';

  @override
  String get searchSchoolSuggestion => '试试学校全称、首字母或仓库里的学校代码';

  @override
  String get deleteDebugRecordTitle => '删除调试记录';

  @override
  String deleteDebugRecordMessage(String name) {
    return '确认删除“$name”？删除后不会影响已经导入的课程';
  }

  @override
  String deletedDebugRecord(String name) {
    return '已删除调试记录：$name';
  }

  @override
  String get customDebugName => '自定义调试';

  @override
  String get localDebugMaintainer => '本地调试';

  @override
  String get customDebugDescription => '用户保存的自定义教务调试脚本';

  @override
  String get addDebugRecordTooltip => '新增调试记录';

  @override
  String get customDebugIntroTitle => '这里放你自己的教务调试记录';

  @override
  String get customDebugIntroSubtitle =>
      '每条记录都可以保存自定义网址和整段脚本，保存后下次直接点“开始调试”就能复用，不需要再去某个学校详情页里找入口';

  @override
  String get addDebugRecordAction => '新增调试记录';

  @override
  String get noSavedDebugRecords => '还没有保存的调试记录';

  @override
  String get noSavedDebugRecordsHint => '先新增一条，把网址和脚本贴进去，以后就能直接复用';

  @override
  String debugScriptLength(int count) {
    return '脚本 $count 字符';
  }

  @override
  String get startDebugAction => '开始调试';

  @override
  String get editAction => '编辑';

  @override
  String get scriptFileReadFailed => '无法读取脚本文件';

  @override
  String scriptFileImported(String name) {
    return '已导入脚本文件：$name';
  }

  @override
  String scriptFileImportFailed(String error) {
    return '导入脚本文件失败：$error';
  }

  @override
  String get debugRecordNameRequired => '请先填写调试记录名称';

  @override
  String get invalidImportUrl => '请输入有效的教务网址';

  @override
  String get debugScriptRequired => '请先填写或导入脚本';

  @override
  String get editDebugRecordTitle => '编辑调试记录';

  @override
  String get addDebugRecordTitle => '新增调试记录';

  @override
  String get savingAction => '保存中…';

  @override
  String get debugRecordFormula => '一条记录 = 一个网址 + 一段脚本';

  @override
  String get debugRecordFormulaSubtitle =>
      '适合你反复调试同一个学校，或者不同学校保留多套脚本，保存后会一直保留，后面可随时修改';

  @override
  String get debugRecordNameLabel => '记录名称';

  @override
  String get debugRecordNameHint => '例如：重庆机电-新版教务';

  @override
  String get importUrlLabel => '教务网址';

  @override
  String get debugScriptLabel => '调试脚本';

  @override
  String get importFromFileAction => '从文件导入';

  @override
  String get debugScriptHint => '把浏览器扩展导出的完整脚本粘贴到这里';

  @override
  String get saveDebugRecordAction => '保存调试记录';

  @override
  String get fillUrlThenImport => '填写网址后导入';

  @override
  String get webLoginImport => '网页登录导入';

  @override
  String get fillUrlThenRecord => '填写网址后录制';

  @override
  String get recordImportAction => '录制导入';

  @override
  String get quickImportAction => '⚡ 快捷导入';

  @override
  String get quickImportTooltip => '快捷导入';

  @override
  String get selectQuickImportTitle => '选择快捷导入';

  @override
  String quickImportMacroSteps(String adapterName, int stepCount) {
    return '$adapterName · $stepCount 步';
  }

  @override
  String quickImportTitle(String name) {
    return '快捷导入 - $name';
  }

  @override
  String get noSavedQuickImportRecords => '暂无已保存的快捷导入记录';

  @override
  String get noValidWarehouseLoginUrl => '未找到有效的教务登录地址';

  @override
  String get noMacroRecordFound => '未找到录制记录，请先完成一次录制';

  @override
  String get quickImportPlayingTitle => '自动导入中…';

  @override
  String get quickImportExecutingScriptTitle => '回放完成，正在执行导入脚本…';

  @override
  String get quickImportManualInputTitle => '需要手动操作';

  @override
  String get quickImportManualInputHint => '请完成当前需要的手动操作，完成后点击继续';

  @override
  String get quickImportCancelImportAction => '取消导入';

  @override
  String get quickImportContinueAction => '继续';

  @override
  String get quickImportFinishedTitle => '导入完成';

  @override
  String get quickImportDismissAction => '完成';

  @override
  String get quickImportRetryAction => '重试';

  @override
  String get homePullQuickImportTitle => '首页下拉快捷导入';

  @override
  String get homePullQuickImportSubtitle => '在首页下拉时自动执行教务快捷导入';

  @override
  String get homePullQuickImportFetchingCourses => '正在获取新课程…';

  @override
  String get homePullQuickImportNeedsManualAction => '需要手动操作，请前往教务导入页面继续';

  @override
  String quickImportPlaybackStepProgress(int current, int total) {
    return '步骤 $current / $total';
  }

  @override
  String get quickImportCancelPlaybackAction => '取消';

  @override
  String get quickImportUnknownError => '发生未知错误';

  @override
  String get recentSchoolLabel => '最近使用';

  @override
  String get warehouseSchoolTapHint => '点击进入，选择适配器导入';

  @override
  String get warehouseAdaptersLoadFailedTitle => '暂时无法读取适配器列表';

  @override
  String get stopRecordingTooltip => '停止录制';

  @override
  String get startRecordingTooltip => '录制操作';

  @override
  String get savedImportUrlHint => '已保存教务网址，下次可直接导入';

  @override
  String get adapterIntroSubtitle => '可查看适配器信息、登录入口与脚本状态';

  @override
  String get schoolLabel => '学校';

  @override
  String get categoryLabel => '类别';

  @override
  String get maintainerLabel => '维护者';

  @override
  String get adapterInfoTitle => '适配器信息';

  @override
  String get scriptPathLabel => '脚本路径';

  @override
  String get loginEntryLabel => '登录入口';

  @override
  String get unsetConfigLabel => '未配置';

  @override
  String get adapterOverrideImportUrlHint => '当前使用你手动覆盖的登录地址';

  @override
  String get repositoryLabel => '仓库';

  @override
  String get scriptStatusTitle => '脚本状态';

  @override
  String scriptLoadedLength(int count) {
    return '脚本已成功读取，长度 $count 字符';
  }

  @override
  String get scriptEmpty => '脚本为空';

  @override
  String get openLoginInAppAction => '应用内打开登录入口';

  @override
  String get openInSystemBrowserAction => '系统浏览器打开';

  @override
  String get copiedImportLoginUrl => '已复制教务登录地址';

  @override
  String get copyLoginAddressAction => '复制登录地址';

  @override
  String get copiedScriptRawUrl => '已复制脚本原始地址';

  @override
  String get copyScriptAddressAction => '复制脚本地址';

  @override
  String get customLoginAddressAction => '自定义登录地址';

  @override
  String get editCustomLoginAddressAction => '修改自定义地址';

  @override
  String get clearCustomLoginAddressAction => '清除自定义地址';

  @override
  String get restoreRepositoryAddressAction => '恢复仓库地址';

  @override
  String get invalidLoginEntryUrl => '登录入口地址无效';

  @override
  String get savedCustomLoginAddress => '已保存自定义登录地址';

  @override
  String get clearedCustomLoginAddress => '已清除自定义登录地址';

  @override
  String get restoredRepositoryImportUrl => '已恢复仓库里的登录地址';

  @override
  String get backToCurrentWeekAction => '回本周';

  @override
  String get nonCurrentWeekLabel => '非本周';

  @override
  String get conflictLabel => '冲突';

  @override
  String get courseConflictSectionTitle => '冲突课程';

  @override
  String get courseNormalSectionTitle => '其他课程';

  @override
  String get courseConflictDetailTitle => '冲突详情';

  @override
  String get courseConflictDetailEntryTitle => '查看冲突详情';

  @override
  String get courseConflictDetailEntrySubtitle => '查看互撞排课与重叠时段';

  @override
  String courseConflictWithCourse(String name) {
    return '与「$name」冲突';
  }

  @override
  String get courseConflictOpenPartnerAction => '查看对方排课';

  @override
  String get courseConflictEmpty => '当前没有检测到冲突';

  @override
  String get courseConflictPairTitle => '冲突组合';

  @override
  String get selectWeekTitle => '选择周次';

  @override
  String availableWeeksCount(int count) {
    return '共 $count 周';
  }

  @override
  String goToWeekLabel(int week) {
    return '第 $week 周';
  }

  @override
  String get homeMenuUpdateTitle => '软件更新';

  @override
  String get homeMenuProfilesTitle => '课表管理';

  @override
  String get homeMenuOverviewTitle => '课程总览';

  @override
  String get homeMenuAddCourseTitle => '添加课程';

  @override
  String get homeMenuImportTitle => '导入课程';

  @override
  String get homeMenuSettingsTitle => '课表设置';

  @override
  String get homeMenuCoffeeTitle => '请喝咖啡';

  @override
  String get homeMenuFeedbackTitle => '问题反馈';

  @override
  String get switchTimetableTitle => '切换课表';

  @override
  String get todayTimetableTitle => '今日课表';

  @override
  String get dayTimetableTitle => '单日时间轴';

  @override
  String get backToWeekViewAction => '返回周视图';

  @override
  String get backToTodayAction => '回到今天';

  @override
  String get ongoingCourseBadge => '正在上课';

  @override
  String get dayViewEmptyTitle => '暂无课程';

  @override
  String shortNamePrefix(String value) {
    return '简称：$value';
  }

  @override
  String teacherPrefix(String value) {
    return '老师：$value';
  }

  @override
  String locationPrefix(String value) {
    return '地点：$value';
  }

  @override
  String courseDialogCurrentWeekHint(int week) {
    return '当前查看第 $week 周，可直接对这一周这节课调课';
  }

  @override
  String courseDialogNotThisWeekHint(int week) {
    return '当前查看第 $week 周，这门课这周没有上课，因此不能按“本周这节”调课';
  }

  @override
  String get editActionShort => '编辑';

  @override
  String get rescheduleAction => '调课';

  @override
  String get deleteActionShort => '删除';

  @override
  String get deleteModeTitle => '删除方式';

  @override
  String get deleteModeSubtitle => '你可以删掉整条排课，也可以只删当前看到的这一周这一节';

  @override
  String get deleteCourseAction => '删这个课';

  @override
  String get deleteOccurrenceAction => '删这节课';

  @override
  String deleteModeHintCurrentWeek(int week) {
    return '“删这个课”会删除这条排课的全部周次；“删这节课”只会删除第 $week 周这一次';
  }

  @override
  String deleteModeHintUnavailable(int week) {
    return '当前卡片不是第 $week 周的实际排课，所以只能删除整条排课';
  }

  @override
  String deleteScheduleConfirmMessage(String name, String detail) {
    return '确定删除“$name”这条排课吗？\n$detail';
  }

  @override
  String deleteOccurrenceConfirmMessage(String name, int week, String detail) {
    return '确定删除“$name”在第 $week 周的这一节吗？\n$detail';
  }

  @override
  String occurrenceDeletedMessage(int week) {
    return '已删除第 $week 周这节课';
  }

  @override
  String get noChangesDetected => '未检测到变更';

  @override
  String get rescheduleCurrentOccurrenceTitle => '调本周这节课';

  @override
  String rescheduleCurrentOccurrenceSubtitle(int week) {
    return '仅改第 $week 周本节，原课该周移除，其他周不变';
  }

  @override
  String get rescheduleTargetWeekLabel => '调到第几周';

  @override
  String get weekdayFieldLabel => '星期';

  @override
  String get startSectionFieldLabel => '开始节次';

  @override
  String get endSectionFieldLabel => '结束节次';

  @override
  String get courseLocationFieldLabel => '上课地点';

  @override
  String get confirmRescheduleAction => '确认调课';

  @override
  String get homeTitleStyleClassicLabel => '经典文字';

  @override
  String get homeTitleStyleBrandLabel => '大 Logo';

  @override
  String get homeTitleStyleClassicDescription => '保持原本标题样式，只显示文字，点击即可切换课表';

  @override
  String get homeTitleStyleBrandDescription => '显示大 Logo 和小课表名称，更强调品牌感';

  @override
  String get widgetBackgroundStyleGlass => '半透明玻璃感';

  @override
  String get widgetBackgroundStyleSolid => '纯色卡片';

  @override
  String get widgetBackgroundStyleGradient => '渐变卡片';

  @override
  String get homeWidgetTargetCompact22 => '主卡 2×2';

  @override
  String get homeWidgetTargetMiniList22 => '迷你列表 2×2';

  @override
  String get homeWidgetTargetMedium24 => '概览 2×4';

  @override
  String get homeWidgetTargetLarge44 => '列表 4×4';

  @override
  String get homeWidgetTargetStats22 => '统计 2×2';

  @override
  String get homeWidgetTargetStats24 => '统计概览 2×4';

  @override
  String get homeWidgetTargetTodayStrip41 => '今日横条 4×1';

  @override
  String get homeWidgetTargetStatsStrip41 => '统计横条 4×1';

  @override
  String get homeWidgetTargetExamCard22 => '考试倒计时 2×2';

  @override
  String get homeWidgetTargetTodayWide42 => '今日横宽 4×2';

  @override
  String get addCourseSheetTitle => '添加内容';

  @override
  String get addCourseSheetSubtitle =>
      '空白课表区域不响应点击，请从这里明确选择是加一节临时课、整学期重复课，还是插入一条单次日程';

  @override
  String courseWeekdaySectionSummary(
    String weekDescription,
    String weekday,
    int startSection,
    int endSection,
  ) {
    return '$weekDescription · $weekday 第$startSection-$endSection节';
  }

  @override
  String weekdaySectionTimeSummary(
    String weekday,
    int startSection,
    int endSection,
    String startTime,
    String endTime,
  ) {
    return '$weekday 第$startSection-$endSection节 · $startTime-$endTime';
  }

  @override
  String rescheduledToMessage(
    int week,
    String weekday,
    int startSection,
    int endSection,
  ) {
    return '已调到第 $week 周 $weekday 第$startSection-$endSection节';
  }

  @override
  String courseCountSummary(int count) {
    return '$count 门课';
  }

  @override
  String dayAgendaInProgressStatus(int minutes) {
    return '进行中 · 剩余 $minutes 分钟';
  }

  @override
  String dayAgendaEndingSoonStatus(int minutes) {
    return '快下课了 · 剩余 $minutes 分钟';
  }

  @override
  String scheduleAgendaInProgressStatus(int minutes) {
    return '进行中 · 剩余 $minutes 分钟';
  }

  @override
  String scheduleAgendaEndingSoonStatus(int minutes) {
    return '即将结束 · 剩余 $minutes 分钟';
  }

  @override
  String get currentBadge => '当前';

  @override
  String get feedbackXiaohongshuTitle => '小红书';

  @override
  String feedbackXiaohongshuSubtitle(String id) {
    return '小红书号：$id';
  }

  @override
  String get feedbackCoolapkTitle => '酷安';

  @override
  String feedbackCoolapkSubtitle(String id) {
    return '酷安号：$id';
  }

  @override
  String get feedbackQqGroupTitle => 'QQ 群';

  @override
  String feedbackQqGroupSubtitle(String id) {
    return '群号：$id';
  }

  @override
  String get feedbackWechatOaTitle => '微信公众号';

  @override
  String feedbackWechatOaSubtitle(String name) {
    return '$name';
  }

  @override
  String get copiedCurrentTimetable => '已复制当前课表';

  @override
  String sectionRangeLabel(int startSection, int endSection) {
    return '第$startSection-$endSection节';
  }

  @override
  String classStartsAtLabel(String time) {
    return '$time 开始';
  }

  @override
  String classEndsAtLabel(String time) {
    return '$time 结束';
  }

  @override
  String get invalidSectionTimeFormat => '节次时间格式不正确';

  @override
  String get noSectionTimesToSave => '没有可保存的节次时间';

  @override
  String warehouseImportedTimeSchemeName(String schoolName) {
    return '$schoolName 导入节次';
  }

  @override
  String get unnamedScript => '未命名脚本';

  @override
  String localDebugModeScriptStatus(String scriptName) {
    return '本地调试模式：$scriptName';
  }

  @override
  String get executeImportScriptTooltip => '执行导入脚本';

  @override
  String get switchToMobileWebTooltip => '切换到移动端页面';

  @override
  String get switchToDesktopWebTooltip => '切换到桌面端页面';

  @override
  String get rememberCurrentInputTooltip => '记住当前输入';

  @override
  String get fillRememberedTooltip => '填充已记住账号';

  @override
  String get clearRememberedTooltip => '清除已记住账号';

  @override
  String get copyCurrentAddressTooltip => '复制当前地址';

  @override
  String get copiedCurrentAddress => '已复制当前地址';

  @override
  String get warehouseLoginHintLocalDebug => '当前为本地调试脚本模式';

  @override
  String get warehouseLoginHintImport => '在此登录教务系统后执行导入';

  @override
  String get currentPageModeDesktop => '当前页面模式：桌面端';

  @override
  String get currentPageModeMobile => '当前页面模式：移动端';

  @override
  String localScriptLabel(String scriptName) {
    return '本地脚本：$scriptName';
  }

  @override
  String get webAddressHint => '输入网页地址';

  @override
  String get goAction => '前往';

  @override
  String rememberedAccountLabel(String username) {
    return '已记住账号：$username';
  }

  @override
  String get importingAction => '导入中...';

  @override
  String get executeLocalDebugScriptAction => '执行本地调试脚本';

  @override
  String get executeImportScriptAction => '执行导入脚本';

  @override
  String get invalidWebAddress => '网页地址无效';

  @override
  String get injectingLocalDebugScript => '正在注入本地调试脚本';

  @override
  String get injectingAdapterScript => '正在注入适配器脚本';

  @override
  String get localDebugScriptInjected => '本地调试脚本已注入';

  @override
  String get scriptInjected => '脚本已注入';

  @override
  String get scriptInjectionFailed => '脚本注入失败';

  @override
  String executeFailedWithError(String error) {
    return '执行失败：$error';
  }

  @override
  String get importFlowFinished => '导入流程已完成';

  @override
  String get defaultContinuePrompt => '请按提示继续操作';

  @override
  String get inputRequiredTitle => '需要输入';

  @override
  String get pleaseEnterFourDigitYear => '请输入 4 位年份';

  @override
  String get pleaseChooseTitle => '请选择';

  @override
  String get invalidCourseConfigFormat => '课程配置格式不正确';

  @override
  String saveCourseConfigFailedWithError(String error) {
    return '保存课程配置失败：$error';
  }

  @override
  String saveSectionTimesFailedWithError(String error) {
    return '保存节次时间失败：$error';
  }

  @override
  String get invalidCourseDataFormat => '课程数据格式不正确';

  @override
  String get noImportableCoursesFromScript => '脚本未返回可导入课程';

  @override
  String importCourseCountPrompt(int count) {
    return '识别到 $count 门课程，是否导入？';
  }

  @override
  String get importCancelledStatus => '已取消导入';

  @override
  String applyReturnedTimeSchemeFailed(String error) {
    return '应用返回的节次模板失败：$error';
  }

  @override
  String get importInterruptedStatus => '导入已中断';

  @override
  String get importFailedStatus => '导入失败';

  @override
  String importFailedWithError(String error) {
    return '导入失败：$error';
  }

  @override
  String get unknownTeacher => '未知教师';

  @override
  String get unknownLocation => '未知地点';

  @override
  String get autofillLoginTitle => '自动填充登录信息';

  @override
  String autofillLoginMessage(String username) {
    return '检测到已记住账号 $username，是否自动填充？';
  }

  @override
  String get notNowAction => '暂不';

  @override
  String get autofillAction => '自动填充';

  @override
  String get rememberPasswordTitle => '记住密码';

  @override
  String rememberPasswordMessage(String username) {
    return '是否记住账号 $username 的登录信息，并在下次自动填充？';
  }

  @override
  String get dontRememberAction => '不记住';

  @override
  String get rememberAndAutofillAction => '记住并自动填充';

  @override
  String get savedRememberedLoginStatus => '已保存记住的登录信息';

  @override
  String get autofilledRememberedLoginStatus => '已自动填充记住的登录信息';

  @override
  String get noRecognizedLoginInputs => '未识别到登录输入项';

  @override
  String get noUsernameOrPasswordRecognized => '未识别到用户名或密码';

  @override
  String get rememberedCurrentLoginStatus => '已记住当前登录信息';

  @override
  String get rememberedCurrentLoginSuccess => '已记住当前登录信息';

  @override
  String rememberLoginFailedWithError(String error) {
    return '记住登录信息失败：$error';
  }

  @override
  String get clearedRememberedLoginStatus => '已清除记住的登录信息';

  @override
  String get clearedRememberedLoginSuccess => '已清除记住的登录信息';

  @override
  String get addScheduleTitle => '添加日程';

  @override
  String get editScheduleTitle => '编辑日程';

  @override
  String get addScheduleAction => '添加日程';

  @override
  String get scheduleTitleLabel => '日程标题';

  @override
  String get scheduleTitleHint => '例如：开组会、办证件、拿快递';

  @override
  String get scheduleTitleRequired => '请输入日程标题';

  @override
  String get scheduleInfoSectionTitle => '日程信息';

  @override
  String get scheduleInfoSectionSubtitle => '日程会按具体日期插入日视图时间线里，不会改动课程本身';

  @override
  String get scheduleTimeSectionTitle => '时间安排';

  @override
  String get scheduleTimeSectionSubtitle => '选择这条日程实际发生的日期和起止时间';

  @override
  String get scheduleAppearanceSectionTitle => '显示样式';

  @override
  String get scheduleAppearanceSectionSubtitle => '选择一个更容易和课程区分的日程颜色';

  @override
  String get scheduleLocationLabel => '地点';

  @override
  String get scheduleLocationHint => '选填';

  @override
  String get scheduleDateLabel => '日期';

  @override
  String get scheduleStartGroupLabel => '开始';

  @override
  String get scheduleEndGroupLabel => '结束';

  @override
  String get scheduleStartDateLabel => '开始日期';

  @override
  String get scheduleEndDateLabel => '结束日期';

  @override
  String get scheduleStartTimeLabel => '开始时间';

  @override
  String get scheduleEndTimeLabel => '结束时间';

  @override
  String get scheduleColorLabel => '日程颜色';

  @override
  String get scheduleNoteLabel => '备注';

  @override
  String get scheduleNoteHint => '选填';

  @override
  String get scheduleBadgeLabel => '日程';

  @override
  String scheduleCountSummary(int count) {
    return '日程 $count 项';
  }

  @override
  String get scheduleTimeRangeInvalid => '结束时间必须晚于开始时间';

  @override
  String get scheduleDateRangeInvalid => '结束日期不能早于开始日期';

  @override
  String get scheduleSingleDayHint => '同日结束时，结束时间必须晚于开始时间';

  @override
  String get scheduleCrossDayHint => '跨日日程会按当天切片显示在日视图里';

  @override
  String get scheduleSavedHint => '日程已添加';

  @override
  String get scheduleUpdatedHint => '日程已更新';

  @override
  String get crossDayBadgeLabel => '跨日';

  @override
  String deleteScheduleMessage(String title) {
    return '删除日程“$title”？';
  }

  @override
  String get scheduleDeletedHint => '日程已删除';

  @override
  String get scheduleListTitle => '日程安排';

  @override
  String get scheduleListEmptyTitle => '暂无日程';

  @override
  String get scheduleUpcomingSection => '即将到来';

  @override
  String get schedulePastSection => '已过期';

  @override
  String get schedulePausedSection => '已暂停';

  @override
  String get scheduleOngoingLabel => '进行中';

  @override
  String scheduleTimeRange(String start, String end) {
    return '$start – $end';
  }

  @override
  String scheduleWeeklyWithDay(String day) {
    return '每周$day';
  }

  @override
  String get examListTitle => '考试安排';

  @override
  String get addExam => '添加考试';

  @override
  String get editExam => '编辑考试';

  @override
  String get saveExam => '保存考试';

  @override
  String get noExams => '暂无考试安排';

  @override
  String get examToday => '今天有考试';

  @override
  String daysUntilExam(int days) {
    return '距离考试还有 $days 天';
  }

  @override
  String get examPassed => '已结束';

  @override
  String get linkCourse => '关联课程';

  @override
  String get linkCourseRequired => '请选择关联课程';

  @override
  String get examNameLabel => '考试名称';

  @override
  String get examNameRequired => '请输入考试名称';

  @override
  String get examDateLabel => '考试日期';

  @override
  String get examDateHint => '请选择日期';

  @override
  String get examDateRequired => '请选择考试日期';

  @override
  String get examEndTimeBeforeStart => '结束时间不能早于开始时间';

  @override
  String get examStartTimeLabel => '开始时间';

  @override
  String get examEndTimeLabel => '结束时间';

  @override
  String get examLocationLabel => '考场';

  @override
  String get examLocationHint => '留空则使用上课教室';

  @override
  String get sameAsClassroom => '同上课教室';

  @override
  String get examSeatLabel => '座位号';

  @override
  String get examReminderLabel => '提醒设置';

  @override
  String get examNoteLabel => '备注';

  @override
  String get deleteExam => '删除考试';

  @override
  String deleteExamConfirm(String name) {
    return '删除考试「$name」？';
  }

  @override
  String get examBadgeLabel => '考试';

  @override
  String get examCountdownToday => '今天';

  @override
  String examCountdownDays(int days) {
    return '$days天后';
  }

  @override
  String get examOverviewCountdown => '倒计时';

  @override
  String get examOverviewCountdownUnit => '天后';

  @override
  String examOverviewTodayCount(int count) {
    return '今日 $count 场';
  }

  @override
  String examOverviewUpcomingCount(int count) {
    return '共 $count 场';
  }

  @override
  String get examOverviewInProgress => '考试进行中';

  @override
  String get examOverviewLiveBadge => '进行中';

  @override
  String examOverviewStartsAt(String time) {
    return '$time 开始';
  }

  @override
  String examOverviewUntilTime(String time) {
    return '至 $time';
  }

  @override
  String get examOverviewReminderOn => '已设提醒';

  @override
  String get examOverviewReminderOff => '未设提醒';

  @override
  String examTimeRange(String start, String end) {
    return '$start – $end';
  }

  @override
  String get sortAction => '排序';

  @override
  String get sortByAdded => '按添加顺序';

  @override
  String get sortByName => '按课程名称';

  @override
  String get sortBySchedule => '按排课时间';

  @override
  String scheduleEntryTitle(int index) {
    return '排课记录 $index';
  }

  @override
  String get scheduleEntrySingleTitle => '上课安排';

  @override
  String get scheduleEntryCardSubtitle => '设置这门课在何时、哪些周、由谁在哪里上课';

  @override
  String get scheduleEntryTimeSectionTitle => '什么时候上';

  @override
  String get scheduleEntryTimeSectionSubtitle => '选择星期几和第几节课；连堂请填写起止节次，单节课起止相同';

  @override
  String get scheduleEntryWeeksSectionTitle => '哪些周上';

  @override
  String get scheduleEntryPeopleSectionTitle => '谁在哪里上';

  @override
  String get scheduleEntryTimeSchemeSectionTitle => '特殊时间方案';

  @override
  String get scheduleEntryTimeSchemeSectionSubtitle =>
      '默认跟随当前课表；仅当本节课上下课时间与课表不同时才需要修改';

  @override
  String scheduleSectionNumberLabel(int section) {
    return '$section节';
  }

  @override
  String get addScheduleEntryAction => '添加排课时间';

  @override
  String get deleteScheduleEntryAction => '删除排课';

  @override
  String get holidaySettingsEntryTitle => '节假日标记';

  @override
  String get holidaySettingsEntrySubtitle => '在课表上标记法定节假日和调休补班';

  @override
  String get holidayMakeupWorkday => '补班';

  @override
  String get holidaySettingsTitle => '节假日标记';

  @override
  String get holidayEnableTitle => '启用节假日标记';

  @override
  String get holidayEnableSubtitle => '开启后会在课表上标记法定节假日和调休补班日';

  @override
  String get holidayDataSectionTitle => '节假日数据';

  @override
  String get holidayDataYear => '年份';

  @override
  String get holidayDataCount => '条数';

  @override
  String get holidayDataEmpty => '暂无节假日数据';

  @override
  String get holidayCheckUpdate => '检查更新';

  @override
  String get holidayAdvancedTitle => '节假日数据更新';

  @override
  String get holidayUpcomingSectionTitle => '近期节假日';

  @override
  String get holidayNoUpcoming => '近期没有节假日';

  @override
  String get holidayBadgeLabel => '假';

  @override
  String get holidayStatusLabel => '假期';

  @override
  String get suspendedBadgeLabel => '停';

  @override
  String get suspendedStatusLabel => '停课';

  @override
  String get courseActionSuspend => '停课';

  @override
  String get courseActionUnsuspend => '恢复';

  @override
  String get courseActionEditPrimary => '编辑课程';

  @override
  String get courseActionRescheduleSecondary => '调课';

  @override
  String get courseActionSuspendSecondary => '停课';

  @override
  String get courseActionDeleteSecondary => '删除';

  @override
  String get courseNoteSheetTitle => '课程备注';

  @override
  String get courseNoteAction => '备注';

  @override
  String get courseNoteSaveAction => '保存';

  @override
  String get courseNoteTabWholeCourse => '课程简介';

  @override
  String get courseNoteTabThisSession => '本节课';

  @override
  String get courseNoteWholeCourseLabel => '课程简介';

  @override
  String get courseNoteWholeCourseHint => '同名课程共享，长期有效（例如课程说明、课堂注意点）。';

  @override
  String get courseNoteWholeCoursePlaceholder => '例如：这个老师容易点名、教室在新楼…';

  @override
  String get courseNoteSessionLabel => '本节课备注';

  @override
  String courseNoteSessionHint(int week) {
    return '仅对第 $week 周这一次课生效，适合记录作业或携带物品。';
  }

  @override
  String get courseNoteSessionPlaceholder => '例如：交第三章习题、带电脑…';

  @override
  String get courseNoteHasHomeworkTitle => '有作业';

  @override
  String get courseNoteHasHomeworkSubtitle => '开启后，周视图课程卡片会显示作业圆标';

  @override
  String get courseNoteHomeworkMarked => '本节有作业';

  @override
  String get courseNoteTileSubtitleEmpty => '记录作业、带电脑或课堂提醒';

  @override
  String get courseNoteTileSubtitleWhole => '已有课程简介';

  @override
  String get courseNoteTileSubtitleSession => '已有本节课备注';

  @override
  String get courseNoteTileSubtitleBoth => '课程简介与本节课均有备注';

  @override
  String get courseNoteReadOnlyNotice => '对方课程仅可查看备注，无法编辑。';

  @override
  String get courseNoteDoneEditingAction => '完成';

  @override
  String courseActionSheetNotice(int week) {
    return '您正在查看第 $week 周，如该时段突发考试或冲突，可立即在下方执行快速调课或停课';
  }

  @override
  String get courseActionOddWeekShort => '单周';

  @override
  String get courseActionEvenWeekShort => '双周';

  @override
  String get courseActionConflictExpandHint => '展开查看其他冲突课程，点击可切换操作对象';

  @override
  String get courseActionConflictCollapseHint => '点击收起冲突课程列表';

  @override
  String get courseActionConflictSwitchAction => '切换';

  @override
  String courseActionCoupleRelatedCount(int count) {
    return '还有 $count 节情侣课表课程';
  }

  @override
  String get courseActionCoupleExpandHint => '展开查看 TA 的课或一起上课，点击可切换预览';

  @override
  String get courseActionCoupleCollapseHint => '点击收起情侣课表课程列表';

  @override
  String courseActionMixedRelatedCount(int count) {
    return '还有 $count 节相关课程';
  }

  @override
  String get courseActionPartnerReadOnlyNotice => '这是对方课表中的课程，仅供查看，无法编辑或调课';

  @override
  String get suspendSheetTitle => '停课';

  @override
  String get suspendSheetSubtitle => '选择停课范围';

  @override
  String get suspendThisWeek => '停本周';

  @override
  String get suspendThisWeekDesc => '仅暂停当前周';

  @override
  String get suspendAllWeeks => '全部停';

  @override
  String get suspendAllWeeksDesc => '暂停所有周次';

  @override
  String get unsuspendAllWeeks => '恢复全部';

  @override
  String get unsuspendAllWeeksDesc => '恢复所有周次';

  @override
  String get customHolidayTitle => '自定义假期';

  @override
  String get customHolidayAdd => '添加假期';

  @override
  String get customHolidayEdit => '编辑假期';

  @override
  String get customHolidayDelete => '删除';

  @override
  String get customHolidayDeleteConfirm => '确定删除这个自定义假期吗？';

  @override
  String get customHolidayNameLabel => '假期名称';

  @override
  String get customHolidayStartDate => '开始日期';

  @override
  String get customHolidayEndDate => '结束日期';

  @override
  String get customHolidayType => '类型';

  @override
  String get customHolidayTypeVacation => '假期';

  @override
  String get customHolidayTypeWorkday => '调休上班';

  @override
  String get customHolidayEmpty => '暂无自定义假期';

  @override
  String get customHolidayCorrupted => '自定义假期数据读取异常，已暂停读写以防覆盖丢失';

  @override
  String get customHolidayNameRequired => '请输入假期名称';

  @override
  String customHolidayDateRange(Object start, Object end) {
    return '$start ~ $end';
  }

  @override
  String get selectTeacherTitle => '选择教师';

  @override
  String get selectLocationTitle => '选择教室';

  @override
  String get historyRecordsLabel => '历史记录';

  @override
  String get noHistoryRecords => '暂无历史记录';

  @override
  String get weekPickerTitle => '选择上课周次';

  @override
  String get selectTimeSchemeTitle => '选择时间方案';

  @override
  String get manageTimeSchemesAction => '管理时间方案';

  @override
  String get examDefaultName => '期末考试';

  @override
  String get examDateWeekPickerTitle => '选择考试日期';

  @override
  String get weekPickerCalendarTooltip => '使用日历选择';

  @override
  String get thisWeekLabel => '本周';

  @override
  String get guidePrivacyPageTitle => '隐私协议';

  @override
  String get guidePermissionsPageTitle => '系统权限';

  @override
  String get guideTipsPageTitle => '使用技巧';

  @override
  String get guidePersonalizePageTitle => '个性化定制';

  @override
  String get guidePersonalizeSubtitle => '以下选择立即生效，之后可随时在「设置 → 外观」中调整';

  @override
  String get guidePersonalizeMenuStyleTitle => '菜单样式';

  @override
  String get guidePersonalizeNavFormTitle => '导航形态';

  @override
  String get guidePersonalizeVisualEffectTitle => '视觉效果';

  @override
  String get guidePersonalizeVisualEffectSolid => '实体卡片';

  @override
  String get guideVisualEffectGaussianDesc => '背景实时高斯模糊，通透有层次';

  @override
  String get guideVisualEffectLiquidDesc => '液态玻璃折射，更具质感（功耗略高）';

  @override
  String get guideVisualEffectSolidDesc => '不启用模糊效果，性能最好';

  @override
  String get guidePersonalizeThemeModeTitle => '深浅色模式';

  @override
  String get guidePersonalizeSeedColorTitle => '主题色';

  @override
  String get guidePrevButton => '上一步';

  @override
  String get guideNextButton => '下一步';

  @override
  String get guidePermissionsHeader => '系统权限设置';

  @override
  String get guidePermissionsSubtitle => '完成这些设置，超级岛和提醒才能正常使用';

  @override
  String get guidePermissionsFooterHint =>
      '点击后跳转到系统设置，返回应用后可识别的状态会自动刷新；自启动受系统限制，请以系统页面开关为准';

  @override
  String get guideTipsHeader => '使用技巧';

  @override
  String get guideTipsSubtitle => '这些随时可以在「设置」里找到';

  @override
  String get guidePrivacyReadBeforeUse => '使用前请阅读并同意以下内容';

  @override
  String get guidePrivacyViewOnly => '隐私、第三方 SDK 与免责说明';

  @override
  String holidayDataYearLabel(Object year) {
    return '$year年法定节假日';
  }

  @override
  String get holidayUpdateLog => '更新日志';

  @override
  String holidayUpdateLogCount(int count) {
    return '$count条';
  }

  @override
  String holidayDateSameMonth(int month, int start, int end) {
    return '$month月$start日 - $end日';
  }

  @override
  String holidayDateSameDay(int month, int day) {
    return '$month月$day日';
  }

  @override
  String holidayDateDiffMonth(
    int startMonth,
    int startDay,
    int endMonth,
    int endDay,
  ) {
    return '$startMonth月$startDay日 - $endMonth月$endDay日';
  }

  @override
  String get liveTestingHolidayOverride => '假期状态覆盖';

  @override
  String get liveTestingHolidayOverrideSubtitle =>
      '开启后模拟假期状态，用于测试提醒和小组件是否正确隐藏课程';

  @override
  String get liveTestingHolidayModeEnabled => '假期模式已开启';

  @override
  String get liveTestingHolidayModeDisabled => '假期模式已关闭';

  @override
  String get liveTestingHolidayModeEnabledDesc => '课程提醒和小组件将隐藏所有课程';

  @override
  String get liveTestingHolidayModeDisabledDesc => '当前使用正常假期数据';

  @override
  String get textColorTitle => '文字颜色';

  @override
  String get textColorSubtitle => '自定义课表各区域的文字颜色';

  @override
  String get textColorIndependentDetail => '独立设置详情颜色';

  @override
  String get textColorCourseCardTitle => '课程卡片标题颜色';

  @override
  String get textColorCourseCardDetail => '课程卡片详情颜色';

  @override
  String get textColorWeekdayBar => '星期栏字体颜色';

  @override
  String get textColorWeekdayBarAccent => '星期栏强调色';

  @override
  String get textColorTimeAxis => '时间轴字体颜色';

  @override
  String get textColorSelectColor => '选择颜色';

  @override
  String get textColorCurrentColor => '当前颜色';

  @override
  String get themeExport => '导出主题';

  @override
  String get themeImport => '导入主题';

  @override
  String get themeExportSuccess => '主题已复制到剪贴板';

  @override
  String get themeImportSuccess => '主题已导入';

  @override
  String get themeImportFailed => '剪贴板内容格式错误';

  @override
  String get themeManageTitle => '主题管理';

  @override
  String get themeManageSubtitle => '导出、导入和切换主题';

  @override
  String get themePreset => '预设主题';

  @override
  String get themeSaved => '我的主题';

  @override
  String get themeSaveCurrent => '保存当前主题';

  @override
  String get themeApply => '应用';

  @override
  String get themeDelete => '删除';

  @override
  String themeDeleteConfirmMessage(String name) {
    return '确定要删除主题“$name”吗？';
  }

  @override
  String get textColorLowContrastWarning => '颜色对比度较低，可能影响可读性';

  @override
  String get themeCurrentTheme => '当前主题';

  @override
  String themeBasedOnModified(String baseName) {
    return '基于$baseName（已修改）';
  }

  @override
  String get themeResetToPreset => '重置';

  @override
  String get themeUnsavedChangesTitle => '未保存的修改';

  @override
  String get themeUnsavedChangesMessage => '当前主题有未保存的修改，是否保存？';

  @override
  String get themeDiscardAndApply => '放弃并应用';

  @override
  String get themeNameHint => '输入主题名称';

  @override
  String get themePresetBlue => '默认蓝';

  @override
  String get themePresetPurple => '暗夜紫';

  @override
  String get themePresetGreen => '森林绿';

  @override
  String get themePresetOrange => '暖阳橙';

  @override
  String get themePresetEyeCare => '护眼模式';

  @override
  String get themePresetHighContrast => '高对比度';

  @override
  String get themePresetDarkMinimal => '深色极简';

  @override
  String get foruiThemeNeutral => '中性灰';

  @override
  String get foruiThemeZinc => '锌灰';

  @override
  String get foruiThemeSlate => '石板灰';

  @override
  String get foruiThemeBlue => '蓝';

  @override
  String get foruiThemeGreen => '绿';

  @override
  String get foruiThemeOrange => '橙';

  @override
  String get foruiThemeRed => '红';

  @override
  String get foruiThemeRose => '玫红';

  @override
  String get foruiThemeViolet => '紫';

  @override
  String get foruiThemeYellow => '黄';

  @override
  String get themeUndo => '撤销';

  @override
  String themeChanged(String themeName) {
    return '已切换到 $themeName';
  }

  @override
  String get themeRename => '重命名';

  @override
  String get themeDuplicate => '复制';

  @override
  String themeDuplicateCopyName(String name) {
    return '$name 副本';
  }

  @override
  String get themeMoreActions => '更多操作';

  @override
  String get courseNatureRequired => '必修';

  @override
  String get courseNatureElective => '选修';

  @override
  String get homeMenuStatisticsTitle => '课程统计';

  @override
  String get statisticsTitle => '课程统计';

  @override
  String get statisticsOverview => '本周概览';

  @override
  String get statisticsCourseCount => '课程门数';

  @override
  String get statisticsSectionCount => '本周课时';

  @override
  String get statisticsWeeklyCourses => '本周课程';

  @override
  String get statisticsDailyDistribution => '每日课时分布';

  @override
  String get statisticsNatureRatio => '必修 / 选修';

  @override
  String get statisticsCourseList => '课程列表';

  @override
  String get statisticsSectionsUnit => '节';

  @override
  String get statisticsSectionUnit => '节';

  @override
  String get statisticsNoData => '暂无课程数据';

  @override
  String get statisticsCourseCountRatio => '门数比例';

  @override
  String get statisticsSectionCountRatio => '课时比例';

  @override
  String statisticsWeekSelector(int week) {
    return '第 $week 周';
  }

  @override
  String get statisticsStoryBusiestDayTitle => '最忙的一天';

  @override
  String statisticsStoryBusiestDayContent(int week, String day, String avg) {
    return '截至第$week周，这学期你最忙的一天是 **$day**，平均 **$avg** 节课';
  }

  @override
  String get statisticsStoryLightestDayTitle => '最轻松的一天';

  @override
  String statisticsStoryLightestDayContent(int week, String day, String avg) {
    return '截至第$week周，你最轻松的一天是 **$day**，只有 **$avg** 节课';
  }

  @override
  String get statisticsStoryFavoriteRoomTitle => '最常去的教室';

  @override
  String statisticsStoryFavoriteRoomContent(int week, String room, int count) {
    return '截至第$week周，你最常去的教室是 **$room**，共去了 **$count** 次';
  }

  @override
  String get statisticsStoryBuildingCountTitle => '教学楼探险';

  @override
  String statisticsStoryBuildingCountContent(int week, int count) {
    return '截至第$week周，你的课程分布在 **$count** 栋不同的教学楼';
  }

  @override
  String get statisticsStoryTimeRangeTitle => '时间跨度';

  @override
  String statisticsStoryTimeRangeContent(String earliest, String latest) {
    return '你最早的课是 **$earliest**，最晚的课是 **$latest**';
  }

  @override
  String get statisticsSemesterLabelCourses => '门课程';

  @override
  String get statisticsSemesterLabelSections => '节课';

  @override
  String get statisticsSemesterLabelWeeks => '周';

  @override
  String get statisticsSemesterLabelDayStreak => '天连续';

  @override
  String get statisticsAchievementsTitle => '成就徽章';

  @override
  String get statisticsStoriesTitle => '数据故事';

  @override
  String get statisticsRankingTitle => '课程排行';

  @override
  String get statisticsNoDataHint => '添加课程后即可查看统计';

  @override
  String get statisticsShareLabel => '分享统计';

  @override
  String get statisticsExportTitle => '导出统计';

  @override
  String get statisticsExportModulesSection => '包含模块';

  @override
  String get statisticsExportFormatSection => '导出格式';

  @override
  String get statisticsExportFormatImage => '长图 (PNG)';

  @override
  String get statisticsExportFormatPdf => 'PDF 文档';

  @override
  String get statisticsExportAction => '开始导出';

  @override
  String get statisticsExportSelectModuleHint => '请至少选择一个模块';

  @override
  String get statisticsExportModuleOverview => '学期总览';

  @override
  String get statisticsExportBrandTagline => '把课程信息做成系统体验';

  @override
  String statisticsExportGithubHint(String url) {
    return 'GitHub 搜索项目：$url';
  }

  @override
  String get statisticsExportQrScanHint => '扫码访问官网';

  @override
  String statisticsExportRankingMore(int count) {
    return '另有 $count 门课程未展示';
  }

  @override
  String get statisticsShareTitle => '我的学期统计';

  @override
  String statisticsRankingSlotDetail(
    String day,
    int startSection,
    int endSection,
  ) {
    return '$day 第$startSection-$endSection节';
  }

  @override
  String get statisticsAchievementEarlyBirdName => '早八战士';

  @override
  String get statisticsAchievementEarlyBirdDescription => '有 8:00 的课，真棒！';

  @override
  String get statisticsAchievementPerfectAttendanceName => '全勤达人';

  @override
  String get statisticsAchievementPerfectAttendanceDescription => '某门课每周都有';

  @override
  String get statisticsAchievementWeekendWarriorName => '周末战士';

  @override
  String get statisticsAchievementWeekendWarriorDescription => '周末有课';

  @override
  String get statisticsAchievementClassKingName => '课王';

  @override
  String get statisticsAchievementClassKingDescription => '某天 ≥ 6 节课';

  @override
  String get statisticsAchievementScholarName => '学霸';

  @override
  String get statisticsAchievementScholarDescription => '总课时 ≥ 100';

  @override
  String get statisticsAchievementBalancedName => '均衡大师';

  @override
  String get statisticsAchievementBalancedDescription => '每天课时差距 ≤ 2';

  @override
  String get statisticsAchievementNightOwlName => '夜猫子';

  @override
  String get statisticsAchievementNightOwlDescription => '有 18:00 以后的课';

  @override
  String get statisticsAchievementExplorerName => '教室探索家';

  @override
  String get statisticsAchievementExplorerDescription => '使用过 ≥ 5 个不同教室';

  @override
  String statisticsNatureLegendDetail(int count, int sections) {
    return '$count 门 · $sections 节';
  }

  @override
  String get statisticsWeekCurrentHint => '本周';

  @override
  String get weeklyReportTitle => '本周课程小结';

  @override
  String weeklyReportBody(
    int week,
    int sections,
    int courses,
    String delta,
    String busiestDay,
  ) {
    return '第$week周 · 共$sections节 · $courses门课\n较上周 $delta 节\n最忙的一天是 $busiestDay';
  }

  @override
  String get weeklyReportBodyEmpty => '本周暂无课程，好好休息吧';

  @override
  String weeklyReportNextFire(String date, String time) {
    return '下次推送 $date $time';
  }

  @override
  String get weeklyReportEnabledHint => '已开启每周周报推送';

  @override
  String get weeklyReportDisabledHint => '已关闭每周周报推送';

  @override
  String get statisticsCompareTitle => '课表对比';

  @override
  String get statisticsCompareActive => '当前课表';

  @override
  String get statisticsCompareNone => '暂无其他课表，可在课表管理中新建';

  @override
  String statisticsCompareDelta(String delta) {
    return '较当前 $delta 节';
  }

  @override
  String get statisticsCompareDetailTitle => '课表对比详情';

  @override
  String get statisticsCompareWeek => '当前周';

  @override
  String get statisticsMoreTitle => '深度分析';

  @override
  String get statisticsMoreGroupTrend => '趋势 · 分布';

  @override
  String get statisticsMoreGroupPeople => '教室 · 教师 · 排行';

  @override
  String get statisticsNatureNoneRequired => '暂无必修';

  @override
  String get statisticsNatureNoneElective => '暂无选修';

  @override
  String get statisticsAchievementMorningPersonName => '早起鸟';

  @override
  String get statisticsAchievementMorningPersonDescription => '早间课时占比 ≥ 50%';

  @override
  String get statisticsAchievementGapMasterName => '时间管理大师';

  @override
  String get statisticsAchievementGapMasterDescription => '最长课间空档 ≤ 2 节';

  @override
  String get statisticsAchievementEarlyBirdDetail =>
      '解锁条件：课表中有 08:00 或更早开始的课程。';

  @override
  String get statisticsAchievementPerfectAttendanceDetail =>
      '解锁条件：至少一门课程在开课周期内每周都有课（无停课、无单双周跳课）。';

  @override
  String get statisticsAchievementWeekendWarriorDetail => '解锁条件：周末（周六或周日）有课。';

  @override
  String get statisticsAchievementClassKingDetail => '解锁条件：某一天排课达到 6 节及以上。';

  @override
  String get statisticsAchievementScholarDetail => '解锁条件：学期累计课时达到 100 节。';

  @override
  String get statisticsAchievementBalancedDetail =>
      '解锁条件：每天课时差距不超过 2 节，课表安排均衡。';

  @override
  String get statisticsAchievementNightOwlDetail => '解锁条件：有 18:00 以后才结束的课。';

  @override
  String get statisticsAchievementExplorerDetail => '解锁条件：使用过 5 个及以上不同的教室。';

  @override
  String get statisticsAchievementFullDayKingDetail =>
      '解锁条件：某一天排课达到 8 节及以上，全天满课。';

  @override
  String get statisticsAchievementBuildingHopperDetail =>
      '解锁条件：同一天内去过 3 栋及以上不同的教学楼。';

  @override
  String get statisticsAchievementMorningPersonDetail =>
      '解锁条件：早间（12:00 前开始）课时占总课时的一半以上。';

  @override
  String get statisticsAchievementGapMasterDetail =>
      '解锁条件：每天课间最长空档不超过 2 节，时间安排紧凑。';

  @override
  String get statisticsAchievementDetailConfirm => '知道了';

  @override
  String get statisticsAchievementLocked => '未达成';

  @override
  String get statisticsSettingsTitle => '统计设置';

  @override
  String get statisticsTabSemester => '学期';

  @override
  String get statisticsTabWeek => '周';

  @override
  String get statisticsSemesterProgressTitle => '学期进度';

  @override
  String statisticsSemesterProgressRange(String start, String end) {
    return '学期 $start - $end';
  }

  @override
  String statisticsSemesterProgressAsOf(String date) {
    return '今天 $date';
  }

  @override
  String statisticsSemesterProgressDetail(int week, int done, int total) {
    return '截至第 $week 周，已上 $done 节 / 共 $total 节';
  }

  @override
  String statisticsSemesterProgressRemaining(int count) {
    return '剩余 $count 节';
  }

  @override
  String get statisticsSemesterProgressNotStarted => '还未开学，尚未上课';

  @override
  String get statisticsSemesterProgressEstimated => '按周估算';

  @override
  String get statisticsTrendTitle => '每周课时趋势';

  @override
  String statisticsTrendTooltip(int week, int sections) {
    return '第 $week 周 · $sections 节';
  }

  @override
  String get statisticsComparisonTitle => '本周小结';

  @override
  String get statisticsComparisonLastWeek => '上周课时';

  @override
  String get statisticsComparisonAverage => '学期周均';

  @override
  String statisticsComparisonVsLastWeek(String delta) {
    return '较上周 $delta 节';
  }

  @override
  String statisticsComparisonVsAverage(String delta) {
    return '较周均 $delta 节';
  }

  @override
  String get statisticsComparisonNew => '新学期第一周';

  @override
  String get statisticsHeatmapTitle => '学期热力图';

  @override
  String get statisticsHeatmapHint => '颜色越深，课时越多';

  @override
  String get statisticsTimeUtilTitle => '时间利用';

  @override
  String get statisticsTimeEarliest => '最早课';

  @override
  String get statisticsTimeLatest => '最晚课';

  @override
  String get statisticsTimeMorning => '早间课时';

  @override
  String get statisticsTimeNoon => '午间课时';

  @override
  String get statisticsTimeEvening => '晚间课时';

  @override
  String get statisticsTimeWeekend => '周末课时';

  @override
  String get statisticsTimeGap => '最长课间空档';

  @override
  String statisticsTimeGapValue(int sections) {
    return '$sections 节';
  }

  @override
  String get statisticsVenueTitle => '教室与教学楼';

  @override
  String get statisticsVenueTopRooms => '常去教室';

  @override
  String get statisticsVenueBuildings => '教学楼课时';

  @override
  String statisticsVenueVisits(int count) {
    return '$count 次';
  }

  @override
  String get statisticsTeacherTitle => '教师课时排行';

  @override
  String statisticsTeacherCourseCount(int count) {
    return '$count 门课';
  }

  @override
  String get statisticsAchievementFullDayKingName => '满课日之王';

  @override
  String get statisticsAchievementFullDayKingDescription => '单日 ≥ 8 节课';

  @override
  String get statisticsAchievementBuildingHopperName => '跨楼达人';

  @override
  String get statisticsAchievementBuildingHopperDescription => '单日跨 ≥ 3 栋教学楼';

  @override
  String statisticsAchievementProgress(int current, int target) {
    return '$current/$target';
  }

  @override
  String get statisticsAchievementDone => '已达成';

  @override
  String statisticsWeekDailyHint(int week) {
    return '点击查看第 $week 周详情';
  }

  @override
  String get weekListSeparator => '、';

  @override
  String courseWeekListLabel(String weeks) {
    return '第$weeks周';
  }

  @override
  String courseWeekRangeLabel(int startWeek, int endWeek, String mode) {
    return '第$startWeek-$endWeek周$mode';
  }

  @override
  String courseWeekSuspendedLabel(String weeks) {
    return '第$weeks周停课';
  }

  @override
  String get importSemesterStartDateTitle => '开学日期';

  @override
  String get importSemesterStartDateSubtitle => '按这一天所在周作为校历第 1 周';

  @override
  String get importFirstCourseWeekMappingLabel => '课表第 1 周对应校历第几周';

  @override
  String get importFirstCourseWeekMappingSubtitle =>
      '如果学校第一周没课，就选第 2 周；前两周都没课就选第 3 周';

  @override
  String get importSemesterMappingNoShiftHint => '导入后会直接把课表第 1 周当作校历第 1 周';

  @override
  String importSemesterMappingShiftHint(int shiftedWeeks, int calendarWeek) {
    return '导入后会把所有课程周次整体顺延 $shiftedWeeks 周，让课表第 1 周落在校历第 $calendarWeek 周';
  }

  @override
  String calendarWeekOption(int week) {
    return '校历第 $week 周';
  }

  @override
  String get aboutDownloadPackageMethodTitle => '下载安装包方式';

  @override
  String get aboutInAppDownloadTitle => '应用内下载';

  @override
  String get aboutInAppDownloadSubtitle => '下载完成后直接在应用内安装';

  @override
  String get aboutSystemDownloaderTitle => '系统管理器';

  @override
  String get aboutSystemDownloaderChoiceSubtitle => '交给系统下载管理器处理';

  @override
  String get syncErrorAuthFailed => '账号或密码错误';

  @override
  String get syncErrorAccessDenied => '没有访问权限';

  @override
  String get syncErrorCertificateError => '证书校验失败';

  @override
  String get syncErrorConnectionTimeout => '连接超时';

  @override
  String get syncErrorConnectionFailed => '无法连接服务器';

  @override
  String get syncErrorNetworkError => '网络异常';

  @override
  String get syncErrorInvalidResponse => '服务器响应无效';

  @override
  String get syncErrorLocalChangesPendingSync => '本地有未同步修改，已跳过自动覆盖';

  @override
  String get syncErrorMissingCredentials => '请先配置云同步账号';

  @override
  String get syncErrorBackupNotFound => '备份不存在';

  @override
  String get syncErrorMissingBackupSnapshot => '备份快照缺失';

  @override
  String get syncErrorCannotDeleteCurrentBackup => '不能删除当前备份';

  @override
  String get syncErrorProviderNotReady => '课表尚未就绪';

  @override
  String get syncErrorInsecureUrl => '仅支持 HTTPS 加密连接，HTTP 明文协议已被禁用';

  @override
  String get syncErrorSyncFailed => '同步失败';

  @override
  String get sectionTimeDisplayHidden => '不显示';

  @override
  String get sectionTimeDisplayStartOnly => '仅显示上课时间';

  @override
  String get sectionTimeDisplayStartAndEnd => '显示上下课时间';

  @override
  String get examReminderNone => '不提醒';

  @override
  String get examReminderMin30 => '考前 30 分钟';

  @override
  String get examReminderHour1 => '考前 1 小时';

  @override
  String get examReminderHour1AndMin30 => '考前 1 小时 + 30 分钟';

  @override
  String get examReminderDay1 => '考前 1 天';

  @override
  String get examReminderDay1AndHour1 => '考前 1 天 + 1 小时';

  @override
  String get examReminderCustom => '自定义';

  @override
  String examReminderOffsetMinutes(int minutes) {
    return '考前 $minutes 分钟';
  }

  @override
  String examReminderOffsetHours(int hours) {
    return '考前 $hours 小时';
  }

  @override
  String examReminderOffsetDays(int days) {
    return '考前 $days 天';
  }

  @override
  String get examReminderCustomEmpty => '请至少选择一个提醒时间';

  @override
  String get examReminderAddCustom => '添加提醒';

  @override
  String get examReminderAddCustomTitle => '自定义提醒时间';

  @override
  String get examReminderAddCustomHint => '设置距离考试开始前多久提醒，可添加多个';

  @override
  String get examReminderPickerDays => '天';

  @override
  String get examReminderPickerHours => '小时';

  @override
  String get examReminderPickerMinutes => '分钟';

  @override
  String get examReminderCustomAlreadyAdded => '该提醒时间已添加';

  @override
  String get examReminderCustomInvalid => '请设置大于 0 的提醒时间';

  @override
  String get examReminderCustomEmptyHint => '还没有自定义提醒，点下方添加';

  @override
  String get debugCopiedJson => '已复制 JSON';

  @override
  String get liveDuringClassTimeNearest => '最近时间';

  @override
  String get liveDuringClassTimeTotal => '总时间';

  @override
  String get liveCountdownTextStyleSmart => '智能（中文）';

  @override
  String get liveCountdownTextStyleSmartMinS => '智能（英文）';

  @override
  String get liveCountdownTextStyleMinuteSecondCn => '分秒（5分钟19秒）';

  @override
  String get liveCountdownTextStyleMinuteSecondColon => 'mm:ss（05:19）';

  @override
  String get liveCountdownTextStyleMinuteSecondMinS => 'min+s（5min19s）';

  @override
  String get liveCountdownTextStyleMinuteSecondMinSlashS => 'min/s（5min/19s）';

  @override
  String get liveCountdownTextStyleMinuteOnlyCn => '纯分钟（5分钟）';

  @override
  String get liveCountdownTextStyleMinuteOnlyMin => 'min（5min）';

  @override
  String get liveCountdownTextStyleMinuteOnlySlash => '/min（5/min）';

  @override
  String get liveCountdownTextStyleSecondOnlyCn => '纯秒（5秒）';

  @override
  String get liveCountdownTextStyleSecondOnlyShort => 's（5s）';

  @override
  String get liveCountdownTextStyleSecondOnlySlash => '/s（5/s）';

  @override
  String get miuiIslandLabelStyleTextOnly => '仅文字';

  @override
  String get miuiIslandLabelStyleIconAndText => '图标+文字';

  @override
  String get miuiIslandLabelContentCourseName => '课程名';

  @override
  String get miuiIslandLabelContentLocation => '教室';

  @override
  String get miuiIslandLabelContentCourseNameAndLocation => '课程名+教室';

  @override
  String get miuiIslandLabelFontWeightRegular => '常规';

  @override
  String get miuiIslandLabelFontWeightMedium => '中等';

  @override
  String get miuiIslandLabelFontWeightBold => '加粗';

  @override
  String get miuiIslandLabelRenderQualityStandard => '标准';

  @override
  String get miuiIslandLabelRenderQualityHigh => '高清';

  @override
  String get miuiIslandLabelRenderQualityUltra => '超高清';

  @override
  String get miuiIslandExpandedIconAppIcon => '应用图标';

  @override
  String get miuiIslandExpandedIconCustomImage => '自定义图片';

  @override
  String get miuiIslandExpandedIconHidden => '不显示';

  @override
  String get liveBeforeClassQuickActionNone => '不显示';

  @override
  String get liveBeforeClassQuickActionSilent => '打开静音';

  @override
  String get liveBeforeClassQuickActionDoNotDisturb => '打开免打扰';

  @override
  String get liveBeforeClassQuickActionBoth => '静音和免打扰';

  @override
  String get courseCardVerticalAlignTop => '顶部对齐';

  @override
  String get courseCardVerticalAlignCenter => '垂直居中';

  @override
  String get courseCardVerticalAlignBottom => '底部对齐';

  @override
  String get courseCardVerticalAlignSpaceEvenly => '上下均布';

  @override
  String get courseCardHorizontalAlignLeft => '居左';

  @override
  String get courseCardHorizontalAlignCenter => '居中';

  @override
  String get courseCardHorizontalAlignRight => '居右';

  @override
  String get timetableTimeColumnWidthNarrow => '窄';

  @override
  String get timetableTimeColumnWidthWide => '宽';

  @override
  String get timetableCourseSpacingNarrow => '窄';

  @override
  String get timetableCourseSpacingWide => '宽';

  @override
  String get appUpdateDownloadSourceOriginal => 'GitHub 原版';

  @override
  String get appUpdateDownloadSourceMirror => '国内镜像';

  @override
  String get appUpdateDownloadChannelPgyer => '蒲公英下载';

  @override
  String get appUpdateDownloadChannelGithub => 'GitHub 下载';

  @override
  String get appUpdateDownloadChannelPgyerDescription => '国内高速下载，推荐使用';

  @override
  String get appUpdateDownloadChannelGithubDescription => 'GitHub 原生 + 国内镜像';

  @override
  String get appUpdateDownloadChannelGitcode => 'GitCode 直连';

  @override
  String get appUpdateDownloadChannelGitcodeDescription =>
      'GitCode 发行版直连下载，国内速度快';

  @override
  String get holidayStatutoryLabel => '法定节假日';

  @override
  String get serviceMsgImportFileUnrecognized => '导入失败，文件内容无法识别';

  @override
  String get serviceMsgImportUseOverwriteForFullBackup =>
      '这是全部数据备份，请使用“覆盖当前课表”方式导入';

  @override
  String get serviceMsgImportNoProfilesInBackup => '备份文件中没有可恢复的课表';

  @override
  String get serviceMsgUnrecognizedMikcbDataFile => '不是可识别的 mikcb 数据文件';

  @override
  String get serviceMsgMissingSettingsData => '缺少设置数据';

  @override
  String get serviceMsgUnrecognizedMikcbFullBackup => '不是可识别的 mikcb 全量备份文件';

  @override
  String get serviceMsgMissingFullBackupData => '缺少完整备份数据';

  @override
  String get serviceMsgUseProfileBackupNotFull => '请使用课表档案备份 JSON，而非全部数据备份';

  @override
  String get serviceMsgUnrecognizedSyncSnapshot => '不是可识别的 mikcb 云同步快照';

  @override
  String get serviceMsgMissingSyncTimetableData => '缺少云同步课表数据';

  @override
  String get serviceMsgSyncSnapshotChecksumFailed => '云同步快照校验失败';

  @override
  String get serviceMsgSyncSnapshotNoProfiles => '云同步快照中没有可恢复的课表';

  @override
  String get serviceMsgSyncSnapshotUnrecognized => '云同步快照无法识别';

  @override
  String get serviceMsgTimeSchemeNotFound => '时间模板不存在';

  @override
  String get serviceMsgTimeSchemeConfigUnavailable => '当前课表时间配置不可用';

  @override
  String get serviceMsgTimeSchemeNotFoundSelected => '未找到所选时间模板';

  @override
  String serviceMsgTimeSchemeSectionsInsufficient(
    int startSection,
    int endSection,
  ) {
    return '所选时间模板节次数不足，无法覆盖第 $startSection-$endSection 节';
  }

  @override
  String serviceMsgSectionCountBelowUsage(int requiredMaxSection) {
    return '有课排到第$requiredMaxSection节';
  }

  @override
  String serviceMsgSectionCountBelowUsageDetail(
    int requiredMaxSection,
    String profileName,
    String courseName,
    int dayOfWeek,
    int startSection,
    int endSection,
    String usageType,
  ) {
    return '节次数量不能小于当前已使用的最大节次（第$requiredMaxSection节），正在使用：$profileName · $courseName（周$dayOfWeek $startSection-$endSection节，$usageType）';
  }

  @override
  String get serviceMsgAtLeastOneSectionRequired => '至少需要保留一节课的时间';

  @override
  String serviceMsgSectionEndMustAfterStart(int sectionNumber) {
    return '第 $sectionNumber 节结束时间必须晚于开始时间，暂不支持跨 0 点课程';
  }

  @override
  String serviceMsgSectionStartBeforePreviousEnd(int sectionNumber) {
    return '第 $sectionNumber 节开始时间不能早于上一节的结束时间';
  }

  @override
  String get serviceMsgPeriodStartTimeRequired => '请为有节次的时段设置第一节开始时间';

  @override
  String serviceMsgSectionCrossesMidnight(int sectionNumber) {
    return '第 $sectionNumber 节会跨到次日，当前暂不支持跨 0 点课程';
  }

  @override
  String get serviceMsgClassDurationMustPositive => '上课时长必须大于 0';

  @override
  String get serviceMsgBreakDurationMustNonNegative => '课间时长不能小于 0';

  @override
  String get serviceMsgAtLeastOnePeriodSection => '至少需要设置一个时段的节次数';

  @override
  String get serviceMsgInvalidTimeFormat => '时间格式不正确';

  @override
  String get serviceMsgLinkedCourseNotFound => '关联的课程不存在';

  @override
  String get serviceMsgCourseNotFoundForDelete => '未找到要删除的课程';

  @override
  String serviceMsgCourseNotScheduledWeek(int sourceWeek) {
    return '这门课在第 $sourceWeek 周没有排课';
  }

  @override
  String get serviceMsgCourseNotFoundForReschedule => '未找到要调课的课程';

  @override
  String get serviceMsgTargetWeekOutOfRange => '目标周次超出当前学期范围';

  @override
  String get serviceMsgAtLeastOneScheduleSlot => '至少需要保留一个上课时间段';

  @override
  String get serviceMsgCourseNameRequired => '课程名称不能为空';

  @override
  String get serviceMsgBackupContentRequired => '备份内容不能为空';

  @override
  String get serviceMsgSpreadsheetFormatOrEncodingUnrecognized =>
      '无法识别表格格式或编码，请将 CSV 另存为 UTF-8 后重试';

  @override
  String serviceMsgSpreadsheetXlsxParseFailed(String error) {
    return 'XLSX 文件解析失败：$error';
  }

  @override
  String serviceMsgSpreadsheetRowWarning(int rowNumber, String message) {
    return '第 $rowNumber 行：$message';
  }

  @override
  String serviceMsgSpreadsheetWakeupInsufficientColumns(
    int rowNumber,
    int columnCount,
  ) {
    return 'WakeUp 格式需要至少 7 列，但第 $rowNumber 行只有 $columnCount 列';
  }

  @override
  String get serviceMsgWeekdayMustBe1To7 => '星期必须是 1-7';

  @override
  String get serviceMsgCustomWeeksRequired => '周数 不能为空';

  @override
  String get serviceMsgClassWeeksRequired => '上课周 不能为空';

  @override
  String get serviceMsgStartWeekMustBeAtLeast1 => '开始周 必须大于等于 1';

  @override
  String serviceMsgStartWeekExceedsSemester(
    int startWeek,
    int semesterWeekCount,
  ) {
    return '开始周 $startWeek 超过学期周数 $semesterWeekCount';
  }

  @override
  String get serviceMsgEndWeekBeforeStartWeek => '结束周 不能小于开始周';

  @override
  String get serviceMsgWeeksRangeRequired => '上课周 或 开始周+结束周 必须填写';

  @override
  String serviceMsgFieldMustBeAtLeast1(String field) {
    return '$field 必须大于等于 1';
  }

  @override
  String serviceMsgFieldCannotBeLessThan(String startField, String endField) {
    return '$endField 不能小于$startField';
  }

  @override
  String serviceMsgSectionOutOfRange(int section, int maxSection) {
    return '节次 $section 超出时间模板范围（1-$maxSection）';
  }

  @override
  String serviceMsgFieldMustBeInteger(String field) {
    return '$field 必须是整数';
  }

  @override
  String serviceMsgFieldCannotBeEmpty(String field) {
    return '$field 不能为空';
  }

  @override
  String serviceMsgSpreadsheetEndWeekClamped(
    int rowNumber,
    int endWeek,
    int semesterWeekCount,
  ) {
    return '第 $rowNumber 行：结束周 $endWeek 超过学期周数 $semesterWeekCount，已调整为 $semesterWeekCount';
  }

  @override
  String serviceMsgSpreadsheetOddEvenBoth(int rowNumber) {
    return '第 $rowNumber 行：单周与双周不能同时勾选，已按单周处理';
  }

  @override
  String get serviceMsgFieldCourseName => '课程名称';

  @override
  String get serviceMsgFieldWeekday => '星期';

  @override
  String get serviceMsgFieldStartSection => '开始节数';

  @override
  String get serviceMsgFieldEndSection => '结束节数';

  @override
  String get serviceMsgFieldCustomWeeks => '周数';

  @override
  String get serviceMsgFieldClassWeeks => '上课周';

  @override
  String get serviceMsgFieldStartWeek => '开始周';

  @override
  String get serviceMsgFieldEndWeek => '结束周';

  @override
  String serviceMsgWeekStartInvalid(String itemName) {
    return '$itemName 周次起始值不合法';
  }

  @override
  String serviceMsgWeekRangeInvalid(String itemName) {
    return '$itemName 周次范围不合法';
  }

  @override
  String serviceMsgWeekRangeTooLarge(String itemName) {
    return '$itemName 周次范围过大，请检查';
  }

  @override
  String serviceMsgWeekTokenUnrecognized(String itemName, String token) {
    return '$itemName 含有无法识别的周次：$token';
  }

  @override
  String serviceMsgWeeksExceedSemesterClamped(
    String itemName,
    int semesterWeekCount,
    String weeks,
  ) {
    return '$itemName 含有超过学期周数 $semesterWeekCount 的周次（$weeks），已忽略超出部分';
  }

  @override
  String get serviceMsgAiResultNotObject => 'AI 结果不是合法对象，请重新复制完整 JSON';

  @override
  String serviceMsgAiSchemaMustBe(String schema) {
    return 'schema 必须为 $schema';
  }

  @override
  String get serviceMsgAiCoursesMustBeArray => 'courses 必须是数组';

  @override
  String get serviceMsgAiWarningsMustBeArray => 'warnings 必须是字符串数组';

  @override
  String get serviceMsgAiWarningItemMustBeString => 'warnings 中的每一项都必须是字符串';

  @override
  String serviceMsgAiCourseNotObject(int index) {
    return 'courses[$index] 不是合法对象';
  }

  @override
  String serviceMsgAiCourseNameEmpty(int index) {
    return 'courses[$index].name 不能为空';
  }

  @override
  String serviceMsgAiCourseDayOfWeekInvalid(int index) {
    return 'courses[$index].dayOfWeek 必须是 1-7';
  }

  @override
  String serviceMsgAiCourseStartSectionInvalid(int index) {
    return 'courses[$index].startSection 必须大于等于 1';
  }

  @override
  String serviceMsgAiCourseEndSectionInvalid(int index) {
    return 'courses[$index].endSection 不能小于 startSection';
  }

  @override
  String serviceMsgAiCourseCustomWeeksEmpty(int index) {
    return 'courses[$index].customWeeks 不能为空';
  }

  @override
  String serviceMsgAiCourseNatureInvalid(int index) {
    return 'courses[$index].courseNature 只能是 required 或 elective';
  }

  @override
  String serviceMsgAiUnknownFields(String targetName, String fields) {
    return '$targetName 包含不支持的字段：$fields';
  }

  @override
  String serviceMsgAiFieldMustBeString(String field) {
    return '$field 必须是字符串';
  }

  @override
  String serviceMsgAiFieldMustBeInteger(String field) {
    return '$field 必须是整数';
  }

  @override
  String serviceMsgAiWeekListInvalid(String itemName) {
    return '$itemName 只能包含大于等于 1 的整数';
  }

  @override
  String serviceMsgAiWeekListTypeInvalid(String field) {
    return '$field 必须是整数数组或周次字符串';
  }

  @override
  String get serviceMsgNoReleaseAvailable => '仓库还没有发布 Release';

  @override
  String get serviceMsgNoReleaseWithPrerelease => '还没有可用的正式版或预发布版本';

  @override
  String serviceMsgUpdateCheckHttpFailed(int statusCode) {
    return '检查更新失败（HTTP $statusCode）';
  }

  @override
  String get serviceMsgUpdateCheckNetworkFailed => '网络异常，暂时无法检查更新';

  @override
  String get serviceMsgUpdateDownloadHashMismatch =>
      '安装包校验失败，为防止安装被篡改的文件已取消本次更新';

  @override
  String get serviceMsgUpdateSha256UnverifiedRefused =>
      '无法校验安装包完整性（缺少官方 SHA-256），已取消应用内更新，请前往发布页手动下载';

  @override
  String get serviceMsgUpdateDownloadUrlUntrusted => '更新下载地址未通过安全校验';

  @override
  String serviceMsgUpdateDownloadHttpFailed(int statusCode) {
    return '下载失败（HTTP $statusCode）';
  }

  @override
  String serviceMsgUpdateOpenInstallerFailed(String detail) {
    return '打开安装包失败: $detail';
  }

  @override
  String serviceMsgUpdateDownloadInstallError(String detail) {
    return '下载或安装过程中出现错误: $detail';
  }

  @override
  String get serviceMsgInvalidUrl => '地址无效';

  @override
  String get serviceMsgUpdateAvailablePrerelease => '发现新的预发布版本';

  @override
  String get serviceMsgUpdateAvailable => '发现新版本';

  @override
  String get serviceMsgAlreadyLatest => '当前已经是最新版本';

  @override
  String get serviceMsgShareBackupText => '这是轻屿课表当前课表的完整备份文件，导入后可直接恢复课程和设置';

  @override
  String get serviceMsgShareBackupSubject => '轻屿课表备份';

  @override
  String serviceMsgShareBackupSubjectNamed(String profileName) {
    return '$profileName - 轻屿课表备份';
  }

  @override
  String get serviceMsgShareFullBackupText =>
      '这是轻屿课表的全部数据备份文件，包含所有课表、当前选中课表和时间模板';

  @override
  String get serviceMsgShareFullBackupSubject => '轻屿课表 - 全部数据备份';

  @override
  String get serviceMsgInvalidRepositoryUrl => '仓库地址格式不正确';

  @override
  String get serviceMsgIncompleteGithubRepoUrl => 'GitHub 仓库地址不完整';

  @override
  String get serviceMsgIncompleteRawGithubUrl =>
      'raw.githubusercontent.com 地址不完整';

  @override
  String get serviceMsgGithubOnlySupported => '当前只支持 GitHub 仓库地址';

  @override
  String get serviceMsgWarehouseNoSchoolsIndex => '未读取到任何学校或工具索引';

  @override
  String serviceMsgWarehouseNoAdapters(String schoolName) {
    return '未读取到 $schoolName 的适配器信息';
  }

  @override
  String serviceMsgWarehouseFetchFailedMirror(int candidatesCount) {
    return '暂时无法读取适配仓，已尝试 $candidatesCount 个镜像线路均失败，请检查网络，或到「版本更新」里切到其他镜像线路后重试';
  }

  @override
  String get serviceMsgWarehouseFetchFailedGithub =>
      '暂时无法读取适配仓，当前正在使用 GitHub 原始线路，请检查网络，或在「版本更新」里切到国内镜像后重试';

  @override
  String get serviceMsgWarehouseScriptChecksumFailed =>
      '适配器脚本完整性校验失败：下载内容与仓库声明的 SHA-256 不一致，已阻止执行。请刷新学校列表后重试；若反复出现，请到 qingyu_warehouse 反馈该适配器';

  @override
  String get serviceMsgManualInputCaptcha => '请手动输入验证码；完成后点击继续';

  @override
  String get serviceMsgManualInputPassword => '请手动输入密码；如已自动填充请直接继续';

  @override
  String get serviceMsgMacroNoSteps => '没有录制的步骤';

  @override
  String get serviceMsgMacroUserCancelled => '用户取消';

  @override
  String serviceMsgMacroStepFailed(
    int stepIndex,
    int totalSteps,
    String detail,
  ) {
    return '第 $stepIndex/$totalSteps 步失败: $detail';
  }

  @override
  String get serviceMsgMacroNavigateUrlEmpty => '导航 URL 为空';

  @override
  String serviceMsgMacroNavigateUrlInvalid(String url) {
    return '无效的 URL: $url';
  }

  @override
  String get serviceMsgMacroFillSelectorEmpty => '填充字段的选择器为空';

  @override
  String serviceMsgMacroElementNotFound(String selector) {
    return '未找到元素: $selector';
  }

  @override
  String get serviceMsgMacroClickSelectorEmpty => '点击元素的选择器为空';

  @override
  String get serviceMsgMacroUrlPatternEmpty => 'URL 模式为空';

  @override
  String get serviceMsgMacroWaitSelectorEmpty => '等待元素的选择器为空';

  @override
  String get serviceMsgMacroManualInputDefault => '需要手动操作';

  @override
  String serviceMsgMacroPollTimeout(
    String stepLabel,
    int timeoutSeconds,
    String lastError,
  ) {
    return '$stepLabel 超时（$timeoutSeconds秒）$lastError';
  }

  @override
  String get serviceMsgMacroReplayNavigate => '正在导航...';

  @override
  String get serviceMsgMacroReplayFillField => '正在填充表单...';

  @override
  String get serviceMsgMacroReplayClick => '正在点击...';

  @override
  String get serviceMsgMacroReplayWaitUrl => '等待页面跳转...';

  @override
  String get serviceMsgMacroReplayWaitSelector => '等待页面元素...';

  @override
  String get serviceMsgMacroReplayWaitManual => '等待用户操作';

  @override
  String get serviceMsgMacroReplayExecuteScript => '正在执行导入脚本...';

  @override
  String get serviceMsgMacroReplayDelay => '等待中...';

  @override
  String serviceMsgMacroReplayFailed(String detail) {
    return '失败: $detail';
  }

  @override
  String serviceMsgMacroReplayPaused(String reason) {
    return '等待手动操作: $reason';
  }

  @override
  String serviceMsgSupportDonorsLoadFailed(String detail) {
    return '加载鸣谢名单失败：$detail';
  }

  @override
  String serviceMsgStatisticsShareFailed(String detail) {
    return '分享失败: $detail';
  }

  @override
  String get serviceMsgAuthFailed => '账号或密码错误';

  @override
  String get serviceMsgAccessDenied => '没有访问权限';

  @override
  String get serviceMsgCertificateError => '证书校验失败';

  @override
  String get serviceMsgConnectionTimeout => '连接超时';

  @override
  String get serviceMsgConnectionFailed => '无法连接服务器';

  @override
  String get serviceMsgInvalidResponse => '服务器响应无效';

  @override
  String get serviceMsgSyncFailed => '同步失败';

  @override
  String get serviceMsgUsageTypeOverride => '副时间表';

  @override
  String get serviceMsgUsageTypeProfile => '课表主时间表';

  @override
  String get dataTransferProfileShareText => '这是轻屿课表当前课表的完整备份文件，导入后可直接恢复课程和设置';

  @override
  String get dataTransferProfileShareSubject => '轻屿课表备份';

  @override
  String dataTransferProfileShareSubjectNamed(String profileName) {
    return '$profileName - 轻屿课表备份';
  }

  @override
  String get dataTransferFullBackupShareText =>
      '这是轻屿课表的全部数据备份文件，包含所有课表、当前选中课表和时间模板';

  @override
  String get dataTransferFullBackupShareSubject => '轻屿课表 - 全部数据备份';

  @override
  String courseWeekCustomDescription(String weeks) {
    return '第$weeks周';
  }

  @override
  String courseWeekRangeDescription(int startWeek, int endWeek, String mode) {
    return '第$startWeek-$endWeek周$mode';
  }

  @override
  String get courseWeekOddModeSuffix => ' 单周';

  @override
  String get courseWeekEvenModeSuffix => ' 双周';

  @override
  String courseWeekSuspensionDescription(String weeks) {
    return '第$weeks周停课';
  }

  @override
  String get courseWeekListSeparator => '、';

  @override
  String holidayLogMemoryCacheHit(int year, int count) {
    return '$year年：命中内存缓存（$count 条），后台刷新中…';
  }

  @override
  String holidayLogLocalCacheHit(int year, int count) {
    return '$year年：命中本地缓存（$count 条），后台刷新中…';
  }

  @override
  String holidayLogNoCacheFetching(int year) {
    return '$year年：无缓存，正在拉取远程数据…';
  }

  @override
  String holidayLogRemoteSuccess(int year, int count) {
    return '$year年：远程拉取成功（$count 条），已缓存';
  }

  @override
  String holidayLogRemoteFailedBuiltin(int year) {
    return '$year年：远程拉取失败，使用内置资产兜底';
  }

  @override
  String holidayLogBuiltinLoaded(int year, int count) {
    return '$year年：加载内置资产（$count 条）';
  }

  @override
  String holidayLogBackgroundSuccess(int year, int count) {
    return '$year年：后台更新成功（$count 条），已覆盖缓存';
  }

  @override
  String holidayLogBackgroundNoData(int year) {
    return '$year年：后台更新未获取到新数据';
  }

  @override
  String get holidayLogPrimaryApiFailed => '主 API 失败，尝试备用 API…';

  @override
  String holidayLogRequesting(String uri) {
    return '正在请求 $uri …';
  }

  @override
  String holidayLogPrimaryApiStatus(int statusCode) {
    return '主 API 响应 $statusCode，跳过';
  }

  @override
  String holidayLogPrimaryApiError(String message) {
    return '主 API 返回错误：$message';
  }

  @override
  String holidayLogPrimaryApiException(String error) {
    return '主 API 异常：$error';
  }

  @override
  String holidayLogPrimaryApiParsing(int count) {
    return '主 API 返回 $count 条原始数据，正在解析…';
  }

  @override
  String get holidayLogNoValidEntries => '解析后无有效条目，跳过';

  @override
  String holidayLogFallbackApiStatus(int statusCode) {
    return '备用 API 响应 $statusCode，跳过';
  }

  @override
  String get holidayLogFallbackApiError => '备用 API 返回错误';

  @override
  String holidayLogFallbackApiParsing(int count) {
    return '备用 API 返回 $count 条原始数据，正在解析…';
  }

  @override
  String holidayLogFallbackApiException(String error) {
    return '备用 API 异常：$error';
  }

  @override
  String get holidayNameNewYear => '元旦';

  @override
  String get holidayNameLaborDay => '劳动节';

  @override
  String get holidayNameNationalDay => '国庆节';

  @override
  String get holidayNameSpringFestival => '春节';

  @override
  String get holidayNameQingming => '清明节';

  @override
  String get holidayNameDragonBoat => '端午节';

  @override
  String get holidayNameMidAutumn => '中秋节';

  @override
  String macroReplayStatusFailed(String error) {
    return '失败: $error';
  }

  @override
  String macroReplayStatusPaused(String reason) {
    return '等待手动操作: $reason';
  }

  @override
  String get macroReplayStepNavigating => '正在导航...';

  @override
  String get macroReplayStepFilling => '正在填充表单...';

  @override
  String get macroReplayStepClicking => '正在点击...';

  @override
  String get macroReplayStepWaitUrl => '等待页面跳转...';

  @override
  String get macroReplayStepWaitSelector => '等待页面元素...';

  @override
  String get macroReplayStepWaitManual => '等待用户操作';

  @override
  String get macroReplayStepExecuteScript => '正在执行导入脚本...';

  @override
  String get macroReplayStepDelay => '等待中...';

  @override
  String get macroReplayAcceleratedFallbackTip => '快捷路径失败，正在使用完整录制步骤重试…';

  @override
  String get macroReplayNoSteps => '没有录制的步骤';

  @override
  String get macroReplayUserCancelled => '用户取消';

  @override
  String macroReplayStepFailed(int current, int total, String error) {
    return '第 $current/$total 步失败: $error';
  }

  @override
  String get macroReplayEmptyNavigateUrl => '导航 URL 为空';

  @override
  String macroReplayInvalidUrl(String url) {
    return '无效的 URL: $url';
  }

  @override
  String get macroReplayEmptyFillSelector => '填充字段的选择器为空';

  @override
  String macroReplayFieldNotFound(String selector) {
    return '未找到表单字段: $selector';
  }

  @override
  String get macroReplayEmptyClickSelector => '点击元素的选择器为空';

  @override
  String macroReplayClickNotFound(String selector) {
    return '未找到点击元素: $selector';
  }

  @override
  String macroReplayWaitUrlPattern(String pattern) {
    return '等待 URL 匹配: $pattern';
  }

  @override
  String get macroReplayEmptyWaitSelector => '等待元素的选择器为空';

  @override
  String macroReplayWaitSelector(String selector) {
    return '等待元素: $selector';
  }

  @override
  String get macroReplayManualActionRequired => '需要手动操作';

  @override
  String macroReplayNavigateTo(String url) {
    return '导航到 $url';
  }

  @override
  String get macroReplayWaitPageLoad => '等待页面加载';

  @override
  String get macroReplayWaitDomReady => '等待 DOM 就绪';

  @override
  String get hyperosShowcaseTitle => '澎湃 UI 组件库';

  @override
  String get hyperosShowcaseSectionSummary => '概要卡片';

  @override
  String get hyperosShowcaseKitSubtitle => 'mikcb 澎湃风格组件一览';

  @override
  String get hyperosShowcaseSectionTags => '标签 / 手风琴 / 提示';

  @override
  String get hyperosShowcaseAccordionSection1 => '第一节';

  @override
  String get hyperosShowcaseAccordionSection1Body => '展开后显示的内容区域';

  @override
  String get hyperosShowcaseAccordionSection2 => '第二节';

  @override
  String get hyperosShowcaseAccordionSection2Body => '可折叠分组，替代 FAccordion';

  @override
  String get hyperosShowcaseSectionNavRows => '列表行 · 导航';

  @override
  String get hyperosShowcaseNavRowWithIcon => '带图标';

  @override
  String get hyperosShowcaseNavRowNoIconSubtitle => '无左侧彩图标';

  @override
  String get hyperosShowcaseNavRowDetails => '详情';

  @override
  String get hyperosShowcaseSectionSwitchRows => '列表行 · 开关 / 危险';

  @override
  String get hyperosShowcaseSwitchRowSubtitle => '带图标开关行';

  @override
  String get hyperosShowcaseSwitchRowPlain => '纯文字开关行';

  @override
  String get hyperosShowcaseSectionChoiceRows => '列表行 · 单选 / 选择 / 日期';

  @override
  String get hyperosShowcaseOptionA => '选项 A';

  @override
  String get hyperosShowcaseOptionB => '选项 B';

  @override
  String get hyperosShowcaseOptionC => '选项 C';

  @override
  String get hyperosShowcaseSelectSizeTitle => '选择尺寸';

  @override
  String get hyperosShowcaseSizeSmall => '小';

  @override
  String get hyperosShowcaseSizeMedium => '中';

  @override
  String get hyperosShowcaseSizeLarge => '大';

  @override
  String get hyperosShowcaseSectionControls => '控件卡片';

  @override
  String get hyperosShowcaseControlsSubtitle => '滑条、分段、按钮';

  @override
  String get hyperosShowcaseSegmentLeft => '左';

  @override
  String get hyperosShowcaseSegmentRight => '右';

  @override
  String get hyperosShowcaseSectionInput => '输入';

  @override
  String get hyperosShowcaseInputHint => '请输入内容';

  @override
  String get hyperosShowcaseInputCardLabel => '卡片内输入';

  @override
  String get hyperosShowcaseSectionPicker => '滚轮选择器';

  @override
  String hyperosShowcasePickerCurrentValue(int value) {
    return '当前值：$value';
  }

  @override
  String get hyperosShowcaseSectionInline => '基础控件 · 行内';

  @override
  String get hyperosShowcaseCheckboxSubtitle => '多选偏好行';

  @override
  String get hyperosShowcaseSectionNavActions => '导航与操作';

  @override
  String get hyperosShowcaseTooltipButton => '带 Tooltip 的按钮';

  @override
  String get hyperosShowcaseSectionProgress => '进度与刷新';

  @override
  String get hyperosShowcaseSectionColorChip => '颜色选择 · ColorChip';

  @override
  String get hyperosShowcaseSectionNavBar => '底部导航 · HyperosNavigationBar';

  @override
  String get hyperosShowcaseNavHome => '首页';

  @override
  String get hyperosShowcaseNavTimetable => '课表';

  @override
  String get hyperosShowcaseNavSettings => '设置';

  @override
  String get hyperosShowcaseSectionEmpty => '空态 / 分割线 / 装饰';

  @override
  String get hyperosShowcaseEmptySubtitle => '列表无数据时的占位';

  @override
  String get hyperosShowcaseActionButton => '操作按钮';

  @override
  String get hyperosShowcaseDividerRowTitle => '第二行（上方有缩进分割线）';

  @override
  String get hyperosShowcaseSectionPressable => '底层行 · HyperosPressableRow';

  @override
  String get hyperosShowcaseSectionShell => '页面壳层';

  @override
  String get hyperosShowcaseRootPageDetails => '无返回键根页';

  @override
  String get hyperosShowcaseSubpageSubtitle => '当前页即 Subpage + HyperosListView';

  @override
  String get hyperosShowcaseAlreadyInSubpage => '已在 Subpage 中';

  @override
  String get hyperosShowcaseSectionFrosted => '模糊顶栏 · 滚动物理';

  @override
  String get hyperosShowcaseSectionFeedback => '反馈 · 弹层';

  @override
  String get hyperosShowcaseSectionIconColors => '主题色 · HyperosIconColors';

  @override
  String get hyperosShowcaseFooterNote => '此页仅在非 Release 构建设置首页可见，用于组件视觉验收';

  @override
  String get hyperosShowcaseUndoAction => '撤销';

  @override
  String get hyperosShowcaseDialogMessage => '系统风格对话框示例';

  @override
  String get hyperosShowcaseConfirmTitle => '确认操作';

  @override
  String get hyperosShowcaseConfirmed => '已确认';

  @override
  String get hyperosShowcaseToastDescription => '带图标与副标题，App Toast 同款';

  @override
  String get hyperosShowcaseMenuCopy => '复制';

  @override
  String get hyperosShowcaseMenuShare => '分享';

  @override
  String get hyperosShowcaseMenuDelete => '删除';

  @override
  String get hyperosShowcaseRefreshDone => '刷新完成';

  @override
  String get hyperosShowcaseSearchTooltip => '搜索';

  @override
  String get hyperosShowcaseRootShellLabel => '根页壳层';

  @override
  String get hyperosShowcasePushSubtitle => '通过 HyperosNavigation.push 进入';

  @override
  String get hyperosShowcaseSampleText => '示例文本';

  @override
  String courseImportQuickImportDescription(
    String schoolName,
    String adapterName,
  ) {
    return '快捷导入 $schoolName $adapterName';
  }

  @override
  String get courseImportScriptNoCourses => '导入脚本未返回课程数据';

  @override
  String get courseImportScriptFailed => '脚本执行失败';

  @override
  String get courseImportRecordingStatus => '录制中…点击停止完成录制';

  @override
  String get courseImportRecordingStartedTip => '录制已开始，请按正常流程操作教务网站';

  @override
  String get courseImportAutoRecordingStartedTip => '已在后台记录操作，导入成功后可保存为快捷导入';

  @override
  String get courseImportRecordingEmptyStatus => '未录制到任何操作';

  @override
  String get courseImportRecordingEmptyTip => '未录制到任何操作';

  @override
  String get courseImportSaveRecordingTitle => '保存录制';

  @override
  String courseImportSaveRecordingMessage(int count) {
    return '录制了 $count 个操作步骤，是否保存为快捷导入？';
  }

  @override
  String courseImportSaveAutoRecordingMessage(int count) {
    return '导入成功。已记录 $count 个操作步骤，是否保存本次导入路径，以便下次快捷导入？';
  }

  @override
  String courseImportRecordingSavedStatus(int count) {
    return '录制已保存（$count 步）';
  }

  @override
  String get courseImportWeekNotProvided => '未提供周次';

  @override
  String get courseImportLocationNotFilled => '未填写地点';

  @override
  String courseImportPreviewLine(
    String weekday,
    int startSection,
    int endSection,
    String name,
    String location,
    String weekText,
  ) {
    return '周$weekday 第$startSection-$endSection节  $name  $location  周次：$weekText';
  }

  @override
  String courseImportCalendarWeekLabel(int week) {
    return '校历第 $week 周';
  }

  @override
  String get courseImportTermStartDateTitle => '开学日期';

  @override
  String get courseImportFirstWeekMappingLabel => '课表第 1 周对应校历第几周';

  @override
  String get courseImportFirstWeekMappingSubtitle =>
      '如果学校第一周没课，就选第 2 周；前两周都没课就选第 3 周';

  @override
  String get courseImportFirstWeekNoShift => '导入后会直接把课表第 1 周当作校历第 1 周';

  @override
  String courseImportFirstWeekShifted(int weeks, int targetWeek) {
    return '导入后会把所有课程周次整体顺延 $weeks 周，让课表第 1 周落在校历第 $targetWeek 周';
  }

  @override
  String get courseImportContinueAction => '继续导入';

  @override
  String get courseImportUpdateRecommendedAction => '更新课表（推荐）';

  @override
  String get courseImportOverwriteAction => '覆盖导入';

  @override
  String get courseImportSectionCountInsufficientTitle => '时间模板节次不足';

  @override
  String courseImportSectionCountInsufficientMessage(
    int current,
    int required,
  ) {
    return '当前课表时间模板只有 $current 节，但导入数据需要到第 $required 节，是否自动补齐后继续导入？';
  }

  @override
  String get courseImportAutoFillAndImportAction => '自动补齐并导入';

  @override
  String get courseImportPortalUrlTitle => '输入教务网址';

  @override
  String get courseImportPortalUrlSaveContinue => '保存并继续';

  @override
  String get courseImportPortalUrlLabel => '教务网址';

  @override
  String get courseImportPortalUrlHint => '保存后下次会直接使用，也可以在适配器信息页里修改';

  @override
  String get courseImportPortalUrlInvalid => '登录地址格式不正确';

  @override
  String get logAppLoggerInitialized => '应用日志服务已初始化';

  @override
  String get logPrivacyConsentUpdated => '隐私协议同意状态已更新';

  @override
  String get logAppLogRecordingEnabled => '应用日志记录已开启';

  @override
  String get logAppLogRecordingRemainsEnabled => '应用日志记录保持开启';

  @override
  String get logStartupFlowStarted => '启动流程处理已开始';

  @override
  String get logStartupFlowCompletedNoOnboarding => '启动流程已完成（无需引导页）';

  @override
  String get logStartupFlowCompletedAfterGuide => '启动流程已完成（经过引导页）';

  @override
  String get logStartupFlowFailed => '启动流程失败，进入降级模式';

  @override
  String get logAppLifecycleChanged => '应用生命周期已变更';

  @override
  String get logNavigatorRouteReplaced => '导航路由已替换';

  @override
  String get logNavigatorRouteChanged => '导航路由已变更';

  @override
  String get logAppLogsDefaultMigrated => '迁移时已默认开启应用日志记录';

  @override
  String get logTimetableLoadSettingsFailed => '加载课表设置失败';

  @override
  String get logTimetableLoadCoursesFailed => '加载课程数据失败';

  @override
  String get logTimetableLoadCurrentWeekFailed => '加载当前周次失败';

  @override
  String get logHomeWidgetPinSupportFailed => '检查桌面小组件固定支持失败';

  @override
  String get logHomeWidgetPinRequestFailed => '请求固定桌面小组件失败';

  @override
  String get logHomeWidgetSyncFailed => '同步桌面小组件快照失败';

  @override
  String get logHomeWidgetClearFailed => '清空桌面小组件快照失败';

  @override
  String get logHomeWidgetScheduleFailed => '调度桌面小组件刷新失败';

  @override
  String get logHomeWidgetExactAlarmCheckFailed => '检查精确闹钟权限失败';

  @override
  String get logHomeWidgetExactAlarmRequestFailed => '请求精确闹钟授权失败';

  @override
  String get logMiuiLiveInitializeFailed => '初始化 MIUI 超级岛通道失败';

  @override
  String get logMiuiLiveOpenPromotedSettingsFailed => '打开超级岛权限设置失败';

  @override
  String get logMiuiLiveOpenNotificationSettingsFailed => '打开通知设置失败';

  @override
  String get logMiuiLiveOpenAutostartSettingsFailed => '打开自启动设置失败';

  @override
  String get logMiuiLiveOpenBatterySettingsFailed => '打开电池优化设置失败';

  @override
  String get logMiuiLiveOpenAccessibilitySettingsFailed => '打开无障碍设置失败';

  @override
  String get logMiuiLiveHideFromRecentsFailed => '更新「从最近任务隐藏」失败';

  @override
  String get logLiveUpdateStartFailed => '从 Flutter 启动超级岛失败';

  @override
  String get logLiveUpdateStopFailed => '从 Flutter 停止超级岛失败';

  @override
  String get logLiveUpdateDebugStatusFailed => '获取原生超级岛调试状态失败';

  @override
  String get logLiveUpdateSnapshotSyncFailed => '同步超级岛课表快照失败';

  @override
  String get logLiveUpdateSnapshotClearFailed => '清空超级岛课表快照失败';

  @override
  String get logLiveUpdateSuspendTriggersFailed => '挂起超级岛课表调度失败';

  @override
  String get logLanEditAuthFailed => '局域网编辑：认证失败';

  @override
  String get logLanEditCourseCreated => '局域网编辑：已创建课程';

  @override
  String get logLanEditCourseUpdated => '局域网编辑：已更新课程';

  @override
  String get logLanEditCourseDeleted => '局域网编辑：已删除课程';

  @override
  String get logLanEditCourseGroupSaved => '局域网编辑：已保存课程组';

  @override
  String get logLanEditMergeImported => '局域网编辑：已导入合并备份';

  @override
  String get logLanEditCoursesBatchDeleted => '局域网编辑：已批量删除课程';

  @override
  String get logLanEditCurrentWeekSet => '局域网编辑：已设置当前周次';

  @override
  String get logLanEditProfileSwitched => '局域网编辑：已切换课表';

  @override
  String get logLanEditSpreadsheetImported => '局域网编辑：已导入表格';

  @override
  String get logLanEditSessionStarted => '局域网编辑：会话已启动';

  @override
  String get logLanEditSessionStopped => '局域网编辑：会话已停止';

  @override
  String get logLiveUpdateTestRequested => '用户请求手动超级岛测试通知';

  @override
  String get logLiveUpdateTestNoSelection => '手动超级岛测试：未找到可用课程';

  @override
  String get logLiveUpdateTestSelectionReady => '手动超级岛测试：已解析目标课程';

  @override
  String get logLiveUpdateTestSuspendSync => '手动超级岛测试：已临时暂停定时同步';

  @override
  String get logLiveUpdateTestStarting => '手动超级岛测试：正在启动原生超级岛';

  @override
  String get logLiveUpdateTestStarted => '手动超级岛测试：已成功请求原生超级岛';

  @override
  String get logLiveUpdateTestFailed => '手动超级岛测试：原生超级岛出现前失败';

  @override
  String logLiveUpdateSettingsSynced(
    String beforeClass,
    String duringClass,
    String beforeEnd,
    String promote,
    String notification,
    String countdown,
    String courseName,
    String location,
  ) {
    return 'Flutter 超级岛设置已同步：课前=$beforeClass，课中=$duringClass，下课前=$beforeEnd，提升=$promote，通知=$notification，倒计时=$countdown，课程名=$courseName，地点=$location';
  }

  @override
  String get logFieldSource => '来源';

  @override
  String get logFieldPlatform => '平台';

  @override
  String get logFieldVersion => '版本';

  @override
  String get logFieldBuildNumber => '构建号';

  @override
  String get logFieldLoggingEnabled => '日志记录';

  @override
  String get logFieldPrivacyAccepted => '隐私协议';

  @override
  String get logFieldAccepted => '已同意';

  @override
  String get logFieldPrevious => '先前状态';

  @override
  String get logFieldTruncated => '已截断';

  @override
  String get logFieldTruncatedHint => '截断提示';

  @override
  String get logFieldThrowable => '异常';

  @override
  String get logFieldExtras => '附加信息';

  @override
  String get logFieldContext => '设备上下文';

  @override
  String get logFieldError => '错误';

  @override
  String get logFieldBrand => '品牌';

  @override
  String get logFieldManufacturer => '制造商';

  @override
  String get logFieldModel => '型号';

  @override
  String get logFieldSdkInt => 'SDK 版本';

  @override
  String get logFieldVersionName => '版本名';

  @override
  String get logFieldChannel => '渠道';

  @override
  String get logFieldHasNotificationPermission => '通知权限';

  @override
  String get logFieldHasPromotedPermissionDeclared => '已声明提升通知权限';

  @override
  String get logFieldCanPostPromotedNotifications => '可发布提升通知';

  @override
  String get logFieldIgnoringBatteryOptimizations => '忽略电池优化';

  @override
  String get logFieldKeepAliveAccessibilityEnabled => '无障碍保活已启用';

  @override
  String get logFieldHideFromRecentsEnabled => '从最近任务隐藏';

  @override
  String get logFieldTaskRemovedRecently => '近期任务被移除';

  @override
  String get logFieldLastTaskRemovedAt => '上次任务移除时间';

  @override
  String get logFieldProcessImportance => '进程重要性';

  @override
  String get logFieldAutoStartStatus => '自启动状态';

  @override
  String get logFieldLiveEnableBeforeClass => '课前超级岛';

  @override
  String get logFieldLiveEnableDuringClass => '课中超级岛';

  @override
  String get logFieldLiveEnableBeforeEnd => '下课前超级岛';

  @override
  String get logFieldLivePromoteDuringClass => '课中提升通知';

  @override
  String get logFieldLiveShowDuringClassNotification => '课中状态栏通知';

  @override
  String get logFieldLiveShowCountdown => '显示倒计时';

  @override
  String get logFieldLiveShowStageText => '显示阶段文字';

  @override
  String get logFieldLiveShowCourseName => '显示课程名';

  @override
  String get logFieldLiveShowLocation => '显示地点';

  @override
  String get logFieldLiveUseShortName => '使用简称';

  @override
  String get logFieldLiveHidePrefixText => '隐藏前缀文字';

  @override
  String get logFieldLiveDuringClassTimeDisplayMode => '课中时间显示模式';

  @override
  String get logFieldLiveEnableMiuiIslandLabelImage => '岛标签图片';

  @override
  String get logFieldLiveMiuiIslandLabelStyle => '岛标签样式';

  @override
  String get logFieldLiveMiuiIslandLabelContent => '岛标签内容';

  @override
  String get logFieldLiveMiuiIslandLabelFontColor => '岛标签字体颜色';

  @override
  String get logFieldLiveMiuiIslandLabelFontWeight => '岛标签字重';

  @override
  String get logFieldLiveMiuiIslandLabelRenderQuality => '岛标签渲染质量';

  @override
  String get logFieldLiveMiuiIslandLabelFontSize => '岛标签字号';

  @override
  String get logFieldLiveMiuiIslandLabelOffsetX => '岛标签 X 偏移';

  @override
  String get logFieldLiveMiuiIslandLabelOffsetY => '岛标签 Y 偏移';

  @override
  String get logFieldLiveMiuiIslandExpandedIconMode => '展开图标模式';

  @override
  String get logFieldLiveShowBeforeClassMinutes => '课前显示分钟数';

  @override
  String get logFieldLiveClassReminderStartMinutes => '上课提醒开始分钟';

  @override
  String get logFieldLiveEndSecondsCountdownThreshold => '下课秒倒计时阈值';

  @override
  String get logFieldState => '状态';

  @override
  String get logFieldRoute => '路由';

  @override
  String get logFieldPreviousRoute => '先前路由';

  @override
  String get logFieldProfileId => '课表配置 ID';

  @override
  String get logFieldReason => '原因';

  @override
  String get logFieldClientIp => '客户端 IP';

  @override
  String get logFieldPort => '端口';

  @override
  String get logFieldCourseName => '课程名';

  @override
  String get logFieldStage => '阶段';

  @override
  String get logFieldFrom => '来源页面';

  @override
  String get logFieldCurrentWeek => '当前周次';

  @override
  String get logFieldWeekday => '星期';

  @override
  String get logFieldUntilMillis => '暂停截止时间';

  @override
  String get logFieldStartAtMillis => '开始时间';

  @override
  String get logFieldMergedCourseCount => '合并课程数';

  @override
  String get logFieldDeletedCount => '删除数量';

  @override
  String get logFieldRequested => '请求数量';

  @override
  String get logFieldTarget => '目标';

  @override
  String get logFieldCount => '数量';

  @override
  String get logFieldValue => '值';

  @override
  String get logFieldSnapshotLength => '快照长度';

  @override
  String get logFieldStoredSnapshotVersion => '存储快照版本';

  @override
  String get logFieldIntentIsNull => 'Intent 为空';

  @override
  String get logFieldAction => '操作';

  @override
  String get logFieldStep => '步骤';

  @override
  String get logCatAppLoggerInitialized => '应用日志：初始化';

  @override
  String get logCatPrivacyConsentUpdated => '应用日志：隐私协议';

  @override
  String get logCatAppLogRecordingEnabled => '应用日志：记录开关';

  @override
  String get logCatStartupFlowStarted => '启动流程：开始';

  @override
  String get logCatStartupFlowCompleted => '启动流程：完成';

  @override
  String get logCatStartupFlowFailed => '启动流程：失败';

  @override
  String get logCatAppLifecycleStateChanged => '应用生命周期';

  @override
  String get logCatRoutePushed => '路由：入栈';

  @override
  String get logCatRoutePopped => '路由：出栈';

  @override
  String get logCatRouteReplaced => '路由：替换';

  @override
  String get logCatFlutterFrameworkError => 'Flutter 框架错误';

  @override
  String get logCatFlutterPlatformError => 'Flutter 平台错误';

  @override
  String get logCatFlutterZoneError => 'Flutter Zone 错误';

  @override
  String get logCatAppLogsDefaultMigrated => '应用日志：迁移';

  @override
  String get logCatTimetableLoadSettingsFailed => '课表：加载设置失败';

  @override
  String get logCatTimetableLoadCoursesFailed => '课表：加载课程失败';

  @override
  String get logCatTimetableLoadCurrentWeekFailed => '课表：加载周次失败';

  @override
  String get logCatHomeWidgetPinSupportFailed => '桌面小组件：检查固定支持';

  @override
  String get logCatHomeWidgetPinRequestFailed => '桌面小组件：请求固定';

  @override
  String get logCatHomeWidgetSyncFailed => '桌面小组件：同步失败';

  @override
  String get logCatHomeWidgetClearFailed => '桌面小组件：清空失败';

  @override
  String get logCatHomeWidgetScheduleFailed => '桌面小组件：调度刷新';

  @override
  String get logCatMiuiLiveInitializeFailed => '超级岛：初始化失败';

  @override
  String get logCatMiuiLiveOpenPromotedSettingsFailed => '超级岛：打开权限设置';

  @override
  String get logCatMiuiLiveOpenNotificationSettingsFailed => '超级岛：打开通知设置';

  @override
  String get logCatMiuiLiveOpenAutostartSettingsFailed => '超级岛：打开自启动设置';

  @override
  String get logCatMiuiLiveOpenBatterySettingsFailed => '超级岛：打开电池优化';

  @override
  String get logCatMiuiLiveOpenAccessibilitySettingsFailed => '超级岛：打开无障碍设置';

  @override
  String get logCatMiuiLiveHideFromRecentsFailed => '超级岛：隐藏最近任务';

  @override
  String get logCatLiveUpdateFlutterInitializeFailed => '超级岛：Flutter 初始化失败';

  @override
  String get logCatLiveUpdateStartFailed => '超级岛：启动失败';

  @override
  String get logCatLiveUpdateStopFailed => '超级岛：停止失败';

  @override
  String get logCatLiveUpdateDebugStatusFailed => '超级岛：调试状态失败';

  @override
  String get logCatLiveUpdateSettingsSynced => '超级岛：设置已同步';

  @override
  String get logCatLiveUpdateSnapshotSyncFailed => '超级岛：快照同步失败';

  @override
  String get logCatLiveUpdateSnapshotClearFailed => '超级岛：快照清空失败';

  @override
  String get logCatLanEditAuthFailed => '局域网编辑：认证';

  @override
  String get logCatLanEditCourseCreated => '局域网编辑：创建课程';

  @override
  String get logCatLanEditCourseUpdated => '局域网编辑：更新课程';

  @override
  String get logCatLanEditCourseDeleted => '局域网编辑：删除课程';

  @override
  String get logCatLanEditCourseGroupSaved => '局域网编辑：保存课程组';

  @override
  String get logCatLanEditMergeImported => '局域网编辑：合并导入';

  @override
  String get logCatLanEditCoursesBatchDeleted => '局域网编辑：批量删除';

  @override
  String get logCatLanEditCurrentWeekSet => '局域网编辑：设置周次';

  @override
  String get logCatLanEditSpreadsheetImported => '局域网编辑：表格导入';

  @override
  String get logCatLanEditSessionStarted => '局域网编辑：会话启动';

  @override
  String get logCatLanEditSessionStopped => '局域网编辑：会话停止';

  @override
  String get logCatLiveUpdateTestRequested => '超级岛测试：请求';

  @override
  String get logCatLiveUpdateTestNoSelection => '超级岛测试：无课程';

  @override
  String get logCatLiveUpdateTestSelectionReady => '超级岛测试：已选课程';

  @override
  String get logCatLiveUpdateTestSuspendSync => '超级岛测试：暂停同步';

  @override
  String get logCatLiveUpdateTestStarting => '超级岛测试：启动中';

  @override
  String get logCatLiveUpdateTestStarted => '超级岛测试：已启动';

  @override
  String get logCatLiveUpdateTestFailed => '超级岛测试：失败';

  @override
  String get logCatLiveUpdateSnapshotSettings => '超级岛：快照设置';

  @override
  String get logCatLiveUpdateSnapshotSynced => '超级岛：快照已同步';

  @override
  String get logCatLiveUpdateSnapshotCleared => '超级岛：快照已清空';

  @override
  String get logCatLiveUpdateAlarmTriggered => '超级岛：闹钟触发';

  @override
  String get logCatLiveUpdateSchedulerResume => '超级岛：调度恢复';

  @override
  String get logCatLiveUpdateRescheduleHoliday => '超级岛：节假日跳过';

  @override
  String get logCatLiveUpdateRescheduleActive => '超级岛：立即启动';

  @override
  String get logCatLiveUpdateRescheduleScheduled => '超级岛：已调度';

  @override
  String get logCatLiveUpdateSnapshotParseFailed => '超级岛：快照解析失败';

  @override
  String get logCatLiveUpdateSnapshotInvalidatedAfterUpgrade => '超级岛：升级后快照失效';

  @override
  String get logCatLiveUpdatePayloadSelected => '超级岛：已选负载';

  @override
  String get logCatLiveUpdateSchedulerStartFailed => '超级岛：调度启动失败';

  @override
  String get logCatLiveUpdateStartRequested => '超级岛：请求启动';

  @override
  String get logCatLiveUpdateStopRequested => '超级岛：请求停止';

  @override
  String get logCatLiveUpdateServiceMissingPayload => '超级岛：服务缺少负载';

  @override
  String get logCatLiveUpdateServiceStarted => '超级岛：服务已启动';

  @override
  String get logCatLiveUpdateServiceStartFailed => '超级岛：服务启动失败';

  @override
  String get logCatLiveUpdateServiceFgsStartDenied =>
      '超级岛：服务内 startForeground 被拒';

  @override
  String get logCatLiveUpdateFgsRetryScheduled => '超级岛：前台服务被拒，已排退避重试';

  @override
  String get logCatLiveUpdateFgsStartGaveUp => '超级岛：重试耗尽，已降级为普通通知';

  @override
  String get logCatLiveUpdateTaskRemoved => '超级岛：任务被移除';

  @override
  String get logCatLiveUpdateTaskRemovedResumed => '超级岛：任务移除后恢复';

  @override
  String get logCatLiveUpdateBeforeClassQuickAction => '超级岛：课前快捷操作';

  @override
  String get logCatLiveUpdateBeforeClassQuickActionRestored => '超级岛：课前快捷操作已恢复';

  @override
  String get logCatLiveUpdateStatusBarDismissed => '超级岛：状态栏通知已关闭';

  @override
  String get logCatLiveUpdateNotPromoted => '超级岛：未提升通知';

  @override
  String get logCatLiveUpdatePromotedNotShown => '超级岛：提升未显示';

  @override
  String get logCatLiveUpdateServiceStopped => '超级岛：服务已停止';

  @override
  String get logCatKeepAliveAccessibilityConnected => '保活：无障碍已连接';

  @override
  String get logCatDiagnosticsEnabled => '诊断：已开启';

  @override
  String get logCatDiagnosticsCleared => '诊断：已清空';

  @override
  String get logCatDiagnosticsBootstrap => '诊断：引导';

  @override
  String get logCatFlutterDiagnostic => 'Flutter 诊断';

  @override
  String get logCatFlutterDiagnosticEvent => 'Flutter 诊断事件';

  @override
  String get logCatRenderFailed => '渲染失败';

  @override
  String get logCatDebugSnapshot => '调试快照';

  @override
  String get logExportTitle => '轻屿课表 - 应用日志';

  @override
  String get appUpdateMirrorPresetGhfast => '默认镜像';

  @override
  String get appUpdateMirrorPresetGhproxyCn => '备用镜像 1';

  @override
  String get appUpdateMirrorPresetGhLlkk => '备用镜像 2';

  @override
  String get appUpdateMirrorPresetGhProxyCom => '备用镜像 3';

  @override
  String get appUpdateMirrorPresetGhproxyNet => '备用镜像 4';

  @override
  String get appUpdateMirrorPresetCustom => '自定义';

  @override
  String get appUpdateMirrorPresetCustomDescription => '填写自定义镜像地址前缀';

  @override
  String get cloudBackupRetentionTitle => '备份保留策略';

  @override
  String get cloudBackupMaxCountTitle => '最多保留份数';

  @override
  String get cloudBackupMaxCountSubtitle => '超过后自动删除最旧的备份';

  @override
  String cloudBackupMaxCountOption(int count) {
    return '$count 份';
  }

  @override
  String get cloudBackupMaxAgeTitle => '最长保留天数';

  @override
  String get cloudBackupMaxAgeSubtitle => '超过后自动删除过期备份';

  @override
  String cloudBackupMaxAgeOption(int days) {
    return '$days 天';
  }

  @override
  String get statisticsShareText => '来自轻屿课表的学期统计';

  @override
  String get aboutUpdateAvailableHeadline => '有版本更新';

  @override
  String get aboutAlreadyLatestHeadline => '已是最新版本';

  @override
  String get aboutDownloadChannelSectionTitle => '下载渠道';

  @override
  String get aboutMirrorProbeFailedLabel => '失败';

  @override
  String timeSchemeImportSupplementName(String name) {
    return '$name（导入补齐）';
  }

  @override
  String profileTimeSchemeName(String profileName) {
    return '$profileName 时间';
  }

  @override
  String get currentProfileTimeSchemeName => '当前课表时间';

  @override
  String get unnamedTimetableProfile => '未命名课表';

  @override
  String get cloudBackupManualProtectedTitle => '手动备份永不过期';

  @override
  String get cloudBackupManualProtectedSubtitle => '开启后，手动创建的备份不会被自动清理';

  @override
  String courseImportPortalUrlMissingBody(
    String schoolName,
    String adapterName,
  ) {
    return '“$schoolName / $adapterName” 没有默认登录地址，请先输入学校教务系统网址';
  }

  @override
  String guidePermissionsProgressLabel(int ready, int total) {
    return '已就绪 $ready/$total';
  }

  @override
  String get locationTimeMatchEntryTitle => '地点作息匹配';

  @override
  String get locationTimeMatchEntrySubtitle => '按上课地点关键词自动选用时间模板';

  @override
  String get locationTimeMatchTitle => '地点作息匹配';

  @override
  String get locationTimeMatchSubtitle =>
      '按地点关键词自动匹配时间模板。重新匹配仅更新命中课程的钟点，未命中课程保持不变。';

  @override
  String get locationTimeMatchWeekAxisNote =>
      '说明：首页左侧时间列仍显示课表默认模板；卡片/详情/实况上的钟点以地点匹配结果为准。';

  @override
  String get locationTimeMatchPreviewLabel => '试匹配地点';

  @override
  String get locationTimeMatchPreviewHint => '例如 A1062 或 A主201';

  @override
  String get locationTimeMatchPreviewNoMatch => '未命中任何地点组，将使用课表默认时间模板';

  @override
  String locationTimeMatchPreviewResult(
    String group,
    String scheme,
    String keyword,
  ) {
    return '将匹配：$group · $scheme（关键词 $keyword）';
  }

  @override
  String get locationTimeMatchApplyActive => '重新匹配当前课表';

  @override
  String get locationTimeMatchApplyTitle => '重新匹配当前课表？';

  @override
  String locationTimeMatchApplyMessage(int count) {
    return '当前有 $count 门课程命中地点规则。节次适配的课程会恢复自动匹配并同步钟点；此前手动指定的模板将被清除，未命中的课程不会改变。';
  }

  @override
  String get locationTimeMatchApplyConfirm => '重新匹配';

  @override
  String locationTimeMatchApplyUpdated(int matched, int updated) {
    return '已重新匹配 $matched 门，更新 $updated 门钟点';
  }

  @override
  String locationTimeMatchApplyAlreadyAligned(int matched) {
    return '已重新匹配 $matched 门，钟点无需改写';
  }

  @override
  String get locationTimeMatchApplyNoneMatched => '没有匹配到可套用的课程';

  @override
  String locationTimeMatchApplyOverflowResult(int matched, int count) {
    return '有 $count 门课节次无法对号入座（模板节数不足），已拒绝套用';
  }

  @override
  String locationTimeMatchApplyOverflowHint(String names) {
    return '未套用示例：$names';
  }

  @override
  String get locationTimeMatchEmpty => '还没有地点组';

  @override
  String get locationTimeMatchCreateGroup => '新建地点组';

  @override
  String get locationTimeMatchEditGroup => '编辑地点组';

  @override
  String get locationTimeMatchUnknownScheme => '未知时间模板';

  @override
  String get locationTimeMatchNoKeywords => '未设置关键词';

  @override
  String locationTimeMatchBoundScheme(String name) {
    return '时间模板：$name';
  }

  @override
  String locationTimeMatchKeywordsLine(String keywords) {
    return '关键词：$keywords';
  }

  @override
  String get locationTimeMatchDeleteTitle => '删除地点组？';

  @override
  String locationTimeMatchDeleteMessage(String name) {
    return '确定删除「$name」？自动匹配的课程将恢复课表默认模板；手动指定模板的课程不受影响。';
  }

  @override
  String get locationTimeMatchDeleted => '已删除地点组';

  @override
  String get locationTimeMatchGroupNameLabel => '地点组名称';

  @override
  String get locationTimeMatchGroupNameHint => '例如：主教学楼 / 其他教学楼';

  @override
  String get locationTimeMatchBoundSchemeLabel => '绑定时间模板';

  @override
  String get locationTimeMatchNeedTimeScheme => '请先创建至少一套时间模板';

  @override
  String get locationTimeMatchEnabledLabel => '启用此地点组';

  @override
  String get locationTimeMatchKeywordsSection => '地点关键词';

  @override
  String get locationTimeMatchKeywordsHelp =>
      '可从课表地点一键识别楼栋，或手动填写关键词（如 A主、A1、A6）。匹配模式建议用「前缀」，更长的关键词优先。';

  @override
  String get locationTimeMatchSelectedKeywords => '已选关键词';

  @override
  String get locationTimeMatchNoSelectedKeywords => '尚未添加关键词';

  @override
  String get locationTimeMatchPickFromLocations => '从课表地点选择';

  @override
  String get locationTimeMatchBuildingSuggestions => '从课表识别的楼栋';

  @override
  String get locationTimeMatchNoBuildingSuggestions => '当前课表没有可识别的楼栋地点';

  @override
  String get locationTimeMatchAddBuilding => '添加';

  @override
  String get locationTimeMatchAddAllBuildings => '一键添加全部未配置楼栋';

  @override
  String locationTimeMatchBuildingRoomCount(int count) {
    return '$count 间教室';
  }

  @override
  String locationTimeMatchBuildingGateTags(String tags) {
    return '标签：$tags';
  }

  @override
  String locationTimeMatchKeywordExtracted(String keyword) {
    return '已从地点提取关键词 $keyword';
  }

  @override
  String get locationTimeMatchKeywordAlreadyExists => '关键词已存在';

  @override
  String locationTimeMatchKeywordUsedByGroup(String group) {
    return '关键词已被「$group」使用';
  }

  @override
  String get locationTimeMatchAddKeyword => '手动添加关键词';

  @override
  String get locationTimeMatchKeywordLabel => '关键词';

  @override
  String get locationTimeMatchKeywordHint => 'A1 / A主 / 六教';

  @override
  String get locationTimeMatchModeLabel => '匹配模式';

  @override
  String get locationTimeMatchModePrefix => '前缀';

  @override
  String get locationTimeMatchModeContains => '包含';

  @override
  String get locationTimeMatchModeExact => '精确';

  @override
  String get locationTimeMatchKeywordTooShort => '关键词过短，容易误匹配';

  @override
  String get locationTimeMatchNameRequired => '请填写地点组名称';

  @override
  String get locationTimeMatchKeywordRequired => '请至少添加一个关键词';

  @override
  String get locationTimeMatchSaved => '地点组已保存';

  @override
  String get locationTimeMatchSaveFailed => '保存失败';

  @override
  String get followLocationAutoTimeScheme => '跟随课表 / 地点自动';

  @override
  String get followLocationAutoTimeSchemeDescription =>
      '未手动指定时，按上课地点关键词自动匹配时间模板；未命中则用课表默认模板';

  @override
  String locationTimeMatchedSchemeHint(String scheme) {
    return '地点匹配 · $scheme';
  }

  @override
  String locationTimeAutoResolvedByGroup(String group, String scheme) {
    return '地点组「$group」→ $scheme';
  }

  @override
  String locationTimeAutoResolvedByTimetable(String scheme) {
    return '课表默认 → $scheme';
  }

  @override
  String get scheduleDateRuleSectionTitle => '日期作息规则';

  @override
  String get scheduleDateRuleSectionSubtitle =>
      '开始日自动将所选模板套用为全部课表默认作息。最多 2 条且区间不重叠；地点作息匹配优先。';

  @override
  String get scheduleDateRuleAdd => '添加日期规则';

  @override
  String get scheduleDateRuleEdit => '编辑日期规则';

  @override
  String get scheduleDateRuleEmpty => '未设置日期规则';

  @override
  String get scheduleDateRuleNameLabel => '规则名称';

  @override
  String get scheduleDateRuleNameHint => '例如：夏令时 / 冬令时';

  @override
  String get scheduleDateRuleStartDate => '开始日期';

  @override
  String get scheduleDateRuleEndDate => '结束日期';

  @override
  String get scheduleDateRuleBoundScheme => '使用时间模板';

  @override
  String get scheduleDateRuleEnabled => '启用';

  @override
  String get scheduleDateRuleActiveToday => '今天在区间内';

  @override
  String scheduleDateRuleRangeSummary(String start, String end) {
    return '$start ~ $end';
  }

  @override
  String get scheduleDateRuleMaxReached => '最多只能添加 2 条日期规则';

  @override
  String get scheduleDateRuleNeedScheme => '请先创建至少一套时间模板';

  @override
  String get scheduleDateRuleNameRequired => '请填写规则名称';

  @override
  String get scheduleDateRuleSaved => '日期规则已保存';

  @override
  String get scheduleDateRuleSavedAndApplied => '日期规则已保存，今天已更新所有课表的默认作息';

  @override
  String get scheduleDateRuleSavedForFuture => '日期规则已保存，将在开始日期更新所有课表的默认作息';

  @override
  String get scheduleDateRuleSavedButApplyFailed =>
      '日期规则已保存，但今天自动套用失败（请检查模板节次是否足够）';

  @override
  String get scheduleDateRuleDeleted => '已删除日期规则';

  @override
  String get scheduleDateRuleDeleteTitle => '删除日期规则？';

  @override
  String scheduleDateRuleDeleteMessage(String name) {
    return '确定删除「$name」？删除后不会自动恢复已套用的作息，需手动调整。';
  }

  @override
  String scheduleDateRuleSaveFailed(String reason) {
    return '保存失败：$reason';
  }

  @override
  String get scheduleDateRuleErrorMax => '已达到 2 条上限';

  @override
  String get scheduleDateRuleErrorOverlap => '日期区间与已有规则重叠';

  @override
  String get scheduleDateRuleErrorInvalidDate => '日期格式无效';

  @override
  String get scheduleDateRuleErrorEndBeforeStart => '结束日期不能早于开始日期';

  @override
  String get scheduleDateRuleErrorSchemeRequired => '请选择时间模板';

  @override
  String get scheduleDateRuleErrorNameRequired => '请填写名称';

  @override
  String get scheduleDateRuleNote => '地点匹配优先于日期规则。';

  @override
  String get frostedGlassModeLabel => '玻璃模式';

  @override
  String get liquidGlassScopeSectionTitle => '液态玻璃作用范围';

  @override
  String get liquidGlassScopePopupTitle => '下拉选择弹窗';

  @override
  String get liquidGlassScopePopupSubtitle => '玻璃模式等设置行弹出的小气泡菜单';

  @override
  String get liquidGlassScopeSelectSheetTitle => '全屏选择面板';

  @override
  String get liquidGlassScopeSelectSheetSubtitle => '预设主题、字体等长列表选择弹窗，默认保持磨砂';

  @override
  String get liquidGlassScopeSheetDialogTitle => '弹窗与对话框';

  @override
  String get liquidGlassScopeSheetDialogSubtitle => '底部弹窗、确认对话框与操作菜单';

  @override
  String get liquidGlassScopeHomeChromeTitle => '首页玻璃带';

  @override
  String get liquidGlassScopeHomeChromeSubtitle => '标题栏与星期栏的玻璃背景带';

  @override
  String get liquidGlassScopeDockTitle => '玻璃坞导航';

  @override
  String get liquidGlassScopeDockSubtitle => '底部悬浮药丸与加课圆钮';

  @override
  String get liquidGlassScopePickerButtonsTitle => '壁纸选点按钮';

  @override
  String get liquidGlassScopePickerButtonsSubtitle => '壁纸位置选择页悬浮在壁纸上的玻璃按钮';

  @override
  String get frostedGlassModeFrosted => '经典磨砂';

  @override
  String get frostedGlassModeLiquid => '液态玻璃';

  @override
  String get frostedGlassModeGaussian => '高斯模糊';

  @override
  String get frostedGlassModeTranslucent => '半透明';

  @override
  String get frostedLiquidGlassHint => '液态玻璃需要高性能设备支持';

  @override
  String get advancedMaterialTitle => '高级材质';

  @override
  String get advancedMaterialEntrySubtitle => '液态玻璃参数微调';

  @override
  String get liquidGlassPresetLabel => '液态玻璃预设';

  @override
  String get liquidGlassPresetClear => '清澈';

  @override
  String get liquidGlassPresetLight => '轻雾';

  @override
  String get liquidGlassPresetStandard => '标准';

  @override
  String get liquidGlassPresetDense => '浓密';

  @override
  String get liquidGlassPresetCustom => '自定义';

  @override
  String get courseCardSettingsTitle => '课程卡片';

  @override
  String get courseCardSectionFields => '显示字段';

  @override
  String get courseCardSectionLayout => '布局';

  @override
  String get courseCardSurfaceStyleLabel => '卡片外观';

  @override
  String get courseCardSurfaceStyleSolid => '实体卡片';

  @override
  String get courseCardSurfaceStyleGaussian => '高斯模糊';

  @override
  String get courseCardSectionColor => '颜色';

  @override
  String get liveSelfCheckTitle => '自检';

  @override
  String get collapsibleLargeTitle => '折叠大标题';

  @override
  String get liquidGlassCustomExpandedTitle => '自定义参数';

  @override
  String get liquidGlassThicknessLabel => '厚度';

  @override
  String get liquidGlassBlurLabel => '模糊强度';

  @override
  String get liquidGlassTintLabel => '染色强度';

  @override
  String get liquidGlassLightIntensityLabel => '灯光强度';

  @override
  String get liquidGlassAmbientStrengthLabel => '环境光强度';

  @override
  String get liquidGlassRefractiveIndexLabel => '折射率';

  @override
  String get liquidGlassSaturationLabel => '饱和度';

  @override
  String get liquidGlassChromaticAberrationLabel => '色差';

  @override
  String get liquidGlassLightAngleLabel => '光照角度';

  @override
  String get liquidGlassVisibilityLabel => '可见性';

  @override
  String get liquidGlassResetAction => '恢复默认';

  @override
  String get diagnosticsEntryTitle => '诊断';

  @override
  String get memoryStatsEntryTitle => '内存状态';

  @override
  String get generalSettingsTitle => '通用';

  @override
  String get settingsResetDefaultsTitle => '恢复默认设置';

  @override
  String get settingsResetDefaultsConfirmTitle => '确认恢复';

  @override
  String get settingsResetConfirmBodyCourseCard => '将把课程卡片的显示字段、布局与颜色恢复为默认值。';

  @override
  String get settingsResetConfirmBodyTimetablePage =>
      '将把课表页面的密度、回到当前周按钮与背景（含清除壁纸）恢复为默认值。';

  @override
  String get settingsResetConfirmBodyAppearance => '将把主题模式、字体、主题色与玻璃质感恢复为默认值。';

  @override
  String get settingsResetConfirmBodyHomeWidget => '将把桌面小组件的显示项与外观恢复为默认值。';

  @override
  String get settingsResetConfirmBodyHomeNavigation => '将把底栏、菜单与首页标题设置恢复为默认值。';

  @override
  String get settingsResetDoneMessage => '设置已重置';

  @override
  String get timetablePageSettingsTitle => '课表页面';

  @override
  String get timetablePageSectionDensity => '密度';

  @override
  String get timetablePageSectionBackToWeek => '回到当前周';

  @override
  String get timetablePageSectionBackground => '背景';

  @override
  String get largeTitleContentGap => '16.0';

  @override
  String get selectTimeTitle => '选择时间';

  @override
  String get liveSelfCheckSubtitle => '运行自检';

  @override
  String get frostedSheetPreviewShowTitle => '显示预览';

  @override
  String get frostedSheetPreviewShowSubtitle => '在顶部显示磨砂玻璃预览';

  @override
  String get aboutSupportUpdatesSectionTitle => '支持与更新';

  @override
  String get aboutProductSectionTitle => '产品';

  @override
  String get aboutCommunitySectionTitle => '社区';

  @override
  String get selectStartTimeTitle => '选择开始时间';

  @override
  String get selectEndTimeTitle => '选择结束时间';

  @override
  String get weekdayInkContrastTitle => '文字对比度不足';

  @override
  String get weekdayInkContrastBodyDark =>
      '你的信息栏文字颜色在深色壁纸上对比度不足，已临时切换为自动白色保证可读。可在「课表页面 → 文字颜色」中更换颜色或恢复默认。';

  @override
  String get weekdayInkContrastBodyLight =>
      '你的信息栏文字颜色在浅色壁纸上对比度不足，已临时切换为自动黑色保证可读。可在「课表页面 → 文字颜色」中更换颜色或恢复默认。';

  @override
  String get gotItAction => '知道了';

  @override
  String get settingsTimetableSectionTitle => '课表';

  @override
  String get liveIslandLabelEntryEnabled => '已开启';

  @override
  String get liveIslandLabelEntryDisabled => '已关闭';

  @override
  String get settingsDisplayAppearanceSectionTitle => '课表显示';

  @override
  String get settingsReminderDesktopSectionTitle => '提醒与桌面';

  @override
  String get settingsAppSectionTitle => '应用';

  @override
  String get settingsDataShareSectionTitle => '数据与共享';

  @override
  String get coupleTimetableEntryUnboundLabel => '未绑定';

  @override
  String get settingsAboutSectionTitle => '关于';

  @override
  String get diagnosticsEntrySubtitle => '日志 · 自检 · 内存';

  @override
  String get settingsSemesterScreenTitle => '学期设置';

  @override
  String get syncCurrentWeekNeedsStartDate => '请先设置开学日期';

  @override
  String get liveNotificationPermissionMissing => '缺少通知权限';

  @override
  String get developerSectionTitle => '开发者选项';

  @override
  String get liveTestingFixtureEntryTitle => '实况测试样例';

  @override
  String get hyperosShowcaseEntryTitle => 'HyperOS 组件展示';

  @override
  String get hyperosShowcaseEntrySubtitle => 'HyperOS 组件预览';

  @override
  String get miuixShowcaseEntryTitle => 'Miuix 组件展示';

  @override
  String get miuixShowcaseEntrySubtitle => 'Miuix 组件预览';

  @override
  String get debugUiOverlayToggleTitle => '调试 UI 叠层';

  @override
  String get scheduleRepeatSectionTitle => '重复设置';

  @override
  String get scheduleRepeatNone => '不重复';

  @override
  String get scheduleRepeatDaily => '每天';

  @override
  String get scheduleRepeatWeekly => '每周';

  @override
  String get scheduleRepeatEndDateLabel => '重复结束日期';

  @override
  String get scheduleRepeatEndDateHint => '重复日程需要设置结束日期';

  @override
  String get scheduleRepeatWeeklyHint => '按开始日期对应的星期重复';

  @override
  String get scheduleReminderSectionTitle => '日程提醒';

  @override
  String get scheduleReminderOff => '不提醒';

  @override
  String scheduleReminderMinutes(int minutes) {
    return '提前 $minutes 分钟';
  }

  @override
  String get scheduleReminderPermissionMissing => '通知权限未开启，日程仍会保存，但提醒可能无法送达';

  @override
  String get scheduleReminderPermissionAction => '检查通知权限';

  @override
  String get scheduleEnabledTitle => '启用日程';

  @override
  String get scheduleDisabledSubtitle => '已暂停，不会显示提醒';

  @override
  String get scheduleEditScopeTitle => '编辑范围';

  @override
  String get scheduleEditScopeThis => '仅本次';

  @override
  String get scheduleEditScopeAll => '全部重复日程';

  @override
  String get scheduleDeleteScopeTitle => '删除范围';

  @override
  String get scheduleDeleteScopeThis => '仅删除本次';

  @override
  String get scheduleDeleteScopeAll => '删除全部重复日程';

  @override
  String get scheduleOccurrenceEditHint => '你正在编辑这条重复日程的一次实例';

  @override
  String get scheduleRepeatEndRequired => '请选择重复结束日期';

  @override
  String get homeMenuTasksTitle => '任务清单';

  @override
  String get taskListTitle => '任务清单';

  @override
  String get addTask => '添加任务';

  @override
  String get editTask => '编辑任务';

  @override
  String get saveTask => '保存任务';

  @override
  String get taskTitleLabel => '任务标题';

  @override
  String get taskTitleHint => '例如：完成第三章习题';

  @override
  String get taskTitleRequired => '请输入任务标题';

  @override
  String get taskNoteLabel => '备注';

  @override
  String get taskNoteHint => '补充说明（可选）';

  @override
  String get taskDueDateLabel => '截止日期';

  @override
  String get taskNoDueDate => '无截止日期';

  @override
  String get taskCourseLabel => '来源课程';

  @override
  String get taskCourseFilter => '课程筛选';

  @override
  String get taskAllCourses => '全部课程';

  @override
  String get taskNoCourse => '无关联课程';

  @override
  String get taskAllFilter => '全部';

  @override
  String get taskTodayFilter => '今日';

  @override
  String get taskWeekFilter => '本周';

  @override
  String get taskOverdueSection => '已逾期';

  @override
  String get taskCompletedSection => '已完成';

  @override
  String get taskNoTasks => '还没有任务';

  @override
  String get taskNoTasksForToday => '今日没有待办任务';

  @override
  String get taskNoTasksForWeek => '本周没有待办任务';

  @override
  String get taskNoTasksForCourse => '这个课程暂无任务';

  @override
  String get taskDelete => '删除任务';

  @override
  String get taskDeleteConfirm => '确定删除这个任务吗？';

  @override
  String get taskHomeworkDefaultTitle => '课程作业';

  @override
  String get taskAddFromCourse => '添加任务';

  @override
  String get taskViewCourse => '查看课程';

  @override
  String get taskSaved => '任务已保存';

  @override
  String get taskUpdated => '任务已更新';

  @override
  String get taskDeleted => '任务已删除';

  @override
  String get icsExportSectionTitle => '导出日历';

  @override
  String get icsExportSectionSubtitle => '选择课程、考试和日程，生成 ICS 日历并分享';

  @override
  String get icsExportTitle => '导出日历';

  @override
  String get icsExportProfileLabel => '课表';

  @override
  String get icsExportProfileSelectTitle => '选择课表';

  @override
  String get icsExportDateRangeTitle => '日期范围';

  @override
  String get icsExportStartDate => '开始日期';

  @override
  String get icsExportEndDate => '结束日期';

  @override
  String get icsExportTypesTitle => '日历内容';

  @override
  String get icsExportCourses => '课程';

  @override
  String get icsExportExams => '考试';

  @override
  String get icsExportSchedules => '日程';

  @override
  String get icsExportButton => '导出并分享';

  @override
  String get icsExportSharing => '准备日历…';

  @override
  String get icsExportNoProfiles => '暂无可导出的课表';

  @override
  String get icsExportDateRangeInvalid => '请选择不早于开始日期的结束日期';

  @override
  String get icsExportNoSelection => '至少选择一种日历内容';

  @override
  String get icsExportSemesterStartRequired => '导出课程前，请先设置学期开始日期';

  @override
  String get icsExportNoEvents => '所选日期范围内没有日历事件';

  @override
  String get icsExportCancelled => '已取消分享日历';

  @override
  String get icsExportFailed => '日历导出失败，请稍后重试';

  @override
  String icsExportShared(int count) {
    return '已导出并分享 $count 个日历事件';
  }

  @override
  String get icsExportShareText => '这是来自轻屿课表的日历文件';

  @override
  String get icsExportShareSubject => '轻屿课表日历';

  @override
  String get homeNavigationTitle => '首页与导航';

  @override
  String get homeMenuCustomizeSectionTitle => '右上角菜单';

  @override
  String get homeNavigationSubtitle => '底栏形态、菜单与首页标题';

  @override
  String get homeNavigationFormLabel => '应用形态';

  @override
  String get homeNavigationFormClassic => '经典形态';

  @override
  String get homeNavigationFormClassicSubtitle => '保持现有的页面与导航方式';

  @override
  String get homeNavigationFormGlassDock => '玻璃坞';

  @override
  String get homeNavigationFormGlassDockSubtitle => '悬浮玻璃底栏，切换日/周课表';

  @override
  String get glassDockTabWeek => '周课表';

  @override
  String get glassDockTabDay => '日课表';

  @override
  String get glassDockLayoutLabel => '玻璃坞内容布局';

  @override
  String get glassDockLayoutOverlay => '满屏悬浮';

  @override
  String get glassDockLayoutOverlaySubtitle => '课表满屏显示，底栏浮动在课表之上';

  @override
  String get glassDockLayoutInset => '内容避让';

  @override
  String get glassDockLayoutInsetSubtitle => '课表底部预留空间，底栏悬浮在下方';

  @override
  String get glassDockInsetClearanceLabel => '避让高度';

  @override
  String get glassDockRoundActionLabel => '圆钮功能';

  @override
  String get glassDockButtonIconTitle => '圆钮图标';

  @override
  String get glassDockButtonIconDefault => '默认（加号）';

  @override
  String get glassDockButtonIconSearchHint => '搜索图标名称';

  @override
  String get glassDockCustomizeSectionTitle => '底部导航栏';

  @override
  String get glassDockCustomizeTitle => '自定义底栏按钮';

  @override
  String get homeDockEditorViewCategory => '视图切换';

  @override
  String get glassDockEntriesSectionTitle => '底栏入口';

  @override
  String get glassDockShowDayTabTitle => '显示日课表入口';

  @override
  String get glassDockShowWeekTabTitle => '显示周课表入口';

  @override
  String get glassDockShowAddButtonTitle => '显示圆钮';

  @override
  String get glassDockShowAddButtonSubtitle => '在药丸右侧显示独立圆钮，功能与图标可在下方自定义';

  @override
  String get glassDockButtonBackToWeekLabel => '回本周 / 今天';

  @override
  String get glassDockExtraButtonSemanticLabel => '添加课程';

  @override
  String get homeMenuStyleLabel => '右上角菜单样式';

  @override
  String get homeMenuStyleList => '列表菜单';

  @override
  String get homeMenuStyleGrid => '八宫格菜单';

  @override
  String get homeMenuStyleListSubtitle => '锚定列表，可自定义';

  @override
  String get homeMenuStyleGridSubtitle => '图标瓷贴，可自定义';

  @override
  String get homeMenuCustomizeTitle => '自定义菜单按钮';

  @override
  String homeGridCustomizeDetails(int count, int max) {
    return '已启用 $count/$max 个';
  }

  @override
  String homeGridEditorHintBody(int max) {
    return '最多放置 $max 个按钮；按住条目拖动即可排序。';
  }

  @override
  String get homeGridEditorEnabledTitle => '已启用';

  @override
  String get homeGridEditorAvailableTitle => '可添加';

  @override
  String get homeGridEditorRemoveTooltip => '移除';

  @override
  String get homeGridEditorAddTooltip => '添加';

  @override
  String get homeGridEditorResetAction => '恢复默认排列';

  @override
  String get homeGridEditorAllAdded => '所有入口都已启用';

  @override
  String get homeGridEditorMaxReached => '已达上限';

  @override
  String get homeGridEditorPinnedTooltip => '此入口用于重新打开本页，不能移除';

  @override
  String get homeMenuCategoryFeatures => '功能入口';

  @override
  String get homeMenuCategoryData => '数据与同步';

  @override
  String get homeMenuCategoryPreferences => '偏好设置';

  @override
  String get homeMenuCategoryAbout => '关于与支持';

  @override
  String classAlarmLeadMinutesLabel(int minutes) {
    return '提前 $minutes 分钟';
  }

  @override
  String get classAlarmInvalidTimeToast => '这门课的节次超出时间模板，无法设置闹钟';

  @override
  String get classAlarmSheetTitle => '上课提醒';

  @override
  String classAlarmQuickOption(Object minutes) {
    return '上课前 $minutes 分钟提醒';
  }

  @override
  String get classAlarmCustomOption => '自定义提醒时间…';

  @override
  String classAlarmExistingLabel(Object time) {
    return '已设提醒：$time';
  }

  @override
  String get classAlarmSetToast => '提醒已设置';

  @override
  String get classAlarmRemovedToast => '已取消这节课的提醒';

  @override
  String get classAlarmPastToast => '所选时间已经过了，请换一个时间';

  @override
  String get classAlarmNoSemesterToast => '请先在设置中填写学期开始日期';

  @override
  String get classAlarmActionLabel => '设这节课的闹钟';

  @override
  String classAlarmConfirmMessage(String detail) {
    return '将在系统时钟创建：$detail。系统闹钟无法识别假期与调休，停课期间照常响铃；删除请在系统时钟中完成。';
  }

  @override
  String classAlarmVariableSuffix(String days) {
    return '另外，$days的第一节课时间在不同周不一致，这些天未创建闹钟。';
  }

  @override
  String get classAlarmEntryTitle => '上课闹钟';

  @override
  String get classAlarmGroupSetup => '添加闹钟';

  @override
  String get classAlarmGroupBehavior => '响铃行为';

  @override
  String get classAlarmAddAllTitle => '批量添加上课闹钟';

  @override
  String get classAlarmRangeNext4Weeks => '未来 4 周';

  @override
  String get classAlarmRangeNext8Weeks => '未来 8 周';

  @override
  String get classAlarmRangeLabel => '添加范围';

  @override
  String get classAlarmRangeRemaining => '本周起至学期结束';

  @override
  String get classAlarmRangeWhole => '整学期';

  @override
  String get classAlarmLeadTitle => '提前量';

  @override
  String get classAlarmSkipUiTitle => '跳过确认页';

  @override
  String get classAlarmSkipUiSubtitle => '尝试直接写入闹钟，不弹出时钟确认页（部分机型不支持）';

  @override
  String get classAlarmOpenClock => '打开系统时钟';

  @override
  String get classAlarmConfirmTitle => '创建重复闹钟？';

  @override
  String get classAlarmNoSchemeToast => '请先在设置中选择时间模板';

  @override
  String get classAlarmNoDataToast => '所选范围内没有找到课表';

  @override
  String get classAlarmAddedToast => '已交给系统时钟处理';

  @override
  String get classAlarmLaunchFailedToast => '未找到可处理的时钟应用';

  @override
  String get classAlarmCourseConfirmTitle => '添加这节课的重复闹钟？';

  @override
  String classAlarmCourseConfirmMessage(
    String weekday,
    String time,
    int lead,
    String weeks,
  ) {
    return '将在系统时钟创建每周$weekday $time 的重复闹钟（比上课提前$lead分钟响铃；上课周次：$weeks）。假期与非上课周仍会响铃，删除需在系统时钟中完成。';
  }

  @override
  String get classAlarmDaySeparator => '、';

  @override
  String get classAlarmDetailSeparator => '；';
}

/// The translations for Chinese, as used in Hong Kong (`zh_HK`).
class AppLocalizationsZhHk extends AppLocalizationsZh {
  AppLocalizationsZhHk() : super('zh_HK');

  @override
  String get appTitle => '輕嶼課表';

  @override
  String get appTitleDebug => '輕嶼課表偵錯版';

  @override
  String get appTitleProfile => '輕嶼課表效能版';

  @override
  String get appearanceTitle => '外觀與配色';

  @override
  String get previewTitle => '預覽';

  @override
  String get timetableBackgroundPreview => '課表背景';

  @override
  String get displayModeTitle => '顯示模式';

  @override
  String get displayModeSubtitle => '支持跟隨系統、淺色模式和深色模式';

  @override
  String get themeModeLabel => '主題模式';

  @override
  String get themeModeSystem => '跟隨系統';

  @override
  String get themeModeLight => '淺色模式';

  @override
  String get themeModeDark => '深色模式';

  @override
  String get fontSectionTitle => '應用字體';

  @override
  String get fontSectionSubtitle => '內建 Inter 預設；也可選用系統已安裝的字體';

  @override
  String get fontSectionFootnote =>
      '廠商字體未內建，需系統已預裝才生效，小米通常只有 MiSans 明顯；沒變化時會自動回退，一般不必自行安裝';

  @override
  String get fontModeLabel => '字體選擇';

  @override
  String get fontModeSystem => '應用預設';

  @override
  String get fontModeSansSerif => '系統無襯線';

  @override
  String get fontModeMiSans => 'MiSans';

  @override
  String get fontModeHarmonyOS => '鴻蒙黑體';

  @override
  String get fontModeOppoSans => 'OPPO Sans';

  @override
  String get fontModePingFang => '蘋方';

  @override
  String get fontModeNotoSans => 'Noto Sans';

  @override
  String get fontModeSerif => '襯線體';

  @override
  String get fontModeSongti => '宋體';

  @override
  String get fontModeMonospace => '等寬體';

  @override
  String get languageSectionTitle => '應用語言';

  @override
  String get languageSectionSubtitle => '可跟隨系統，或手動切換到已適配語言';

  @override
  String get languageModeLabel => '語言選擇';

  @override
  String get languageModeSystem => '跟隨系統';

  @override
  String get settingsTitle => '課表設定';

  @override
  String get dailyUsageSectionTitle => '日常使用';

  @override
  String get appearanceEntryTitle => '外觀與配色';

  @override
  String get appearanceEntrySubtitle => '主題模式、字型、首頁標題與彈出視窗磨砂玻璃';

  @override
  String get appearanceThemeDisplaySectionTitle => '主題與顯示';

  @override
  String get layoutSectionEntryTitle => '布局與節次';

  @override
  String get layoutSectionEntrySubtitle => '節次時間、行高、時間列、周末顯示與卡片布局';

  @override
  String get homeWidgetEntryTitle => '桌面小組件';

  @override
  String get homeWidgetEntrySubtitle => '今日課程卡片、小組件背景與顯示資訊';

  @override
  String get reminderNotificationSectionTitle => '提醒與通知';

  @override
  String get userGuideEntryTitle => '使用引導與權限';

  @override
  String get userGuideEntrySubtitle => '簡稱建議、通知、自啟動、電池策略';

  @override
  String get timetableManagementSectionTitle => '課表管理';

  @override
  String get timeSchemeEntryTitle => '時間範本';

  @override
  String get timeSchemeEntrySubtitleNoneSelected => '切換、編輯節次、複製和管理時間範本';

  @override
  String get timeSchemeEntryNotSelected => '未選擇';

  @override
  String timeSchemeEntrySubtitleSelected(String name) {
    return '目前：$name · 切換、編輯節次和複製';
  }

  @override
  String get dataTransferEntryTitle => '資料備份與遷移';

  @override
  String get dataTransferEntrySubtitle => '匯出完整課表檔案，給別人直接匯入使用';

  @override
  String get coupleTimetableEntryTitle => '情侶課表';

  @override
  String get coupleTimetableEntryBound => '已綁定';

  @override
  String get coupleTimetableModeEnableTooltip => '開啟情侶課表';

  @override
  String get coupleTimetableModeDisableTooltip => '關閉情侶課表';

  @override
  String get coupleTimetableTitle => '情侶課表';

  @override
  String get coupleTimetableIntro =>
      '匯出你的課表發給對方，或匯入對方分享的課表檔案，匯入後可在疊加檢視中查看雙方的課程';

  @override
  String get coupleTimetableBoundTitle => '已綁定對方課表';

  @override
  String get coupleTimetableUnboundTitle => '尚未綁定對方課表';

  @override
  String get coupleTimetablePartnerNameLabel => '對方名稱';

  @override
  String coupleTimetableLastImportedAt(String time) {
    return '上次匯入：$time';
  }

  @override
  String get coupleTimetableExportForPartner => '匯出我的課表給對方';

  @override
  String get coupleTimetableImportPartner => '匯入對方課表';

  @override
  String get coupleTimetableUnlink => '解除綁定';

  @override
  String get coupleTimetableOpenOverlay => '進入疊加檢視';

  @override
  String get coupleTimetableImportSuccess => '已匯入對方課表';

  @override
  String get coupleTimetableImportUpdated => '已更新對方課表';

  @override
  String get coupleTimetableUnlinkConfirmTitle => '解除情侶課表綁定？';

  @override
  String get coupleTimetableUnlinkConfirmMessage => '解除後將刪除本機儲存的對方課表，疊加檢視也會關閉';

  @override
  String get coupleTimetableUnlinkSuccess => '已解除綁定';

  @override
  String get coupleTimetablePrivacyHint => '對方只能看到你匯出檔案中所包含的課表內容';

  @override
  String get coupleTimetableOverlayTitle => '情侶疊加';

  @override
  String get coupleTimetableLegendMine => '我的課';

  @override
  String get coupleTimetableLegendPartner => '對方課程';

  @override
  String get coupleTimetableLegendTogether => '一起上課';

  @override
  String get coupleTimetableLegendFree => '共同空閒';

  @override
  String get coupleTimetableSharedFreeTitle => '今日共同空閒';

  @override
  String get coupleTimetableSharedFreeTitleOtherDay => '當日共同空閒';

  @override
  String get coupleTimetableNoSharedFree => '今天沒有共同空閒時段';

  @override
  String get coupleTimetableNoSharedFreeOtherDay => '當日沒有共同空閒時段';

  @override
  String coupleTimetableSharedFreeMeta(int count) {
    return '共 $count 段';
  }

  @override
  String coupleTimetableSharedFreeMoreCount(int count) {
    return '還有 $count 段';
  }

  @override
  String get coupleTimetableSharedFreeUnavailable => '暫時算不出共同空閒';

  @override
  String get coupleTimetableSharedFreeStaleHint => '對方課表可能不是最新';

  @override
  String get coupleTimetablePartnerReadOnlyBadge => '對方課表（唯讀）';

  @override
  String get coupleTimetableNotBoundMessage => '請先匯入對方課表後再查看疊加檢視';

  @override
  String get coupleTimetableShareText => '這是我的課表，匯入到輕嶼課表的情侶課表即可一起查看';

  @override
  String get coupleTimetableShareSubject => '輕嶼課表・情侶課表分享';

  @override
  String get coupleTimetableWeekOffsetTitle => '週次偏移';

  @override
  String get coupleTimetableWeekOffsetSubtitle =>
      '查看你的第 N 週時，讀取對方課表的第 N+偏移 週，例如 +1 表示對方學期進度比你快一週';

  @override
  String get coupleTimetableWeekOffsetZero => '無偏移';

  @override
  String coupleTimetableWeekOffsetSigned(String offset) {
    return '$offset 週';
  }

  @override
  String coupleTimetableWeekOffsetPreview(int myWeek, int partnerWeek) {
    return '查看你的第 $myWeek 週時，顯示對方第 $partnerWeek 週的課';
  }

  @override
  String get coupleTimetableColorsTitle => '疊加顏色';

  @override
  String get coupleTimetableColorsSubtitle =>
      '自訂「我的課」「對方課程」「一起上課」在疊加檢視中的顯示顏色，可按喜好自由搭配';

  @override
  String get partnerImportRequiresSingleProfile => '請匯入單一課表備份檔案，不支援全量備份';

  @override
  String get coupleWebdavTitle => '堅果雲拉取';

  @override
  String get coupleWebdavSubtitle =>
      '登入對方（或你們共用的）堅果雲帳號，自動下載對方上傳的課表檔案，與「雲端同步」帳號獨立，互不蠅響';

  @override
  String get coupleWebdavNotConnected => '尚未連接堅果雲';

  @override
  String coupleWebdavConnectedAs(String username) {
    return '已連接：$username';
  }

  @override
  String coupleWebdavRemotePathHint(String path) {
    return '遠端檔案路徑：$path';
  }

  @override
  String coupleWebdavLastPulledAt(String time) {
    return '上次拉取：$time';
  }

  @override
  String get coupleWebdavConnect => '連接堅果雲';

  @override
  String get coupleWebdavDisconnect => '中斷連接';

  @override
  String get coupleWebdavPullNow => '立即拉取對方課表';

  @override
  String get coupleWebdavUploadForPartner => '上傳我的課表到堅果雲';

  @override
  String get coupleWebdavLoginSheetTitle => '連接堅果雲（情侶課表）';

  @override
  String get coupleWebdavLoginSheetSubtitle =>
      '請使用應用程式專用密碼，對方需先將課表上傳到約定路徑，或由你在對方裝置上登入同一帳號並上傳';

  @override
  String get coupleWebdavConfirmConnect => '連接並拉取';

  @override
  String get coupleWebdavMySlotLabel => '本機槽位';

  @override
  String get coupleWebdavMySlotHint => '雙方必須選不同槽位：一方選 1，另一方選 2，否則會互相讀不到課表';

  @override
  String get coupleWebdavSlotOne => '槽位 1';

  @override
  String get coupleWebdavSlotTwo => '槽位 2';

  @override
  String get coupleWebdavTestSuccess => '堅果雲連接成功';

  @override
  String get coupleWebdavTestFailed => '連接失敗，請檢查帳號、應用程式專用密碼與網路';

  @override
  String get coupleWebdavPullImported => '已從堅果雲匯入對方課表';

  @override
  String get coupleWebdavPullUpdated => '已從堅果雲更新對方課表';

  @override
  String get coupleWebdavPullUnchanged => '對方課表無變化';

  @override
  String get coupleWebdavUploadSuccess => '已上傳課表，對方可拉取';

  @override
  String get coupleWebdavPartnerFileMissing => '找不到對方課表檔案，請讓對方先上傳';

  @override
  String get coupleWebdavPullFailed => '拉取對方課表失敗，請稍後重試';

  @override
  String get coupleWebdavNotConnectedError => '請先連接堅果雲';

  @override
  String get cloudSyncEntryTitle => '雲端同步';

  @override
  String get cloudSyncEntrySubtitle => '透過堅果雲等多裝置同步課表與匯入資料';

  @override
  String get cloudSyncEntryDisabled => '已關閉';

  @override
  String get cloudSyncEntryEnabled => '已開啟';

  @override
  String get cloudSyncEntrySyncing => '同步中';

  @override
  String get cloudSyncEntryError => '上次同步失敗';

  @override
  String get cloudSyncTitle => '雲端同步';

  @override
  String get cloudSyncIntroTitle => '多裝置同步';

  @override
  String get cloudSyncIntroSubtitle =>
      '設定堅果雲 WebDAV 後，可在手機、平板之間自動同步課表、倉庫帳號與相關設定';

  @override
  String get cloudSyncSettingsSectionTitle => '同步設定';

  @override
  String get cloudSyncSettingsSectionSubtitle => '可切換手動或自動同步';

  @override
  String get cloudSyncEnabledTitle => '啟用雲端同步';

  @override
  String get cloudSyncEnabledSubtitle => '關閉後不會上傳或下載雲端快照';

  @override
  String get cloudSyncProviderTitle => '服務提供商';

  @override
  String get cloudSyncProviderJianguoyun => '堅果雲';

  @override
  String get cloudSyncProviderCustom => '自訂 WebDAV';

  @override
  String get cloudSyncModeTitle => '同步方式';

  @override
  String get cloudSyncModeAuto => '自動同步';

  @override
  String get cloudSyncModeManual => '手動同步';

  @override
  String get cloudSyncAccountTitle => '帳號設定';

  @override
  String get cloudSyncAccountSubtitle =>
      '請使用堅果雲應用程式專用密碼，而不是登入密碼，快照會包含倉庫記住的學校帳號';

  @override
  String get cloudSyncUsernameLabel => '電郵 / 用戶名稱';

  @override
  String get cloudSyncUsernameHint => '堅果雲註冊電郵';

  @override
  String get cloudSyncPasswordLabel => '應用程式專用密碼';

  @override
  String get cloudSyncPasswordHint => '在堅果雲帳戶安全選項中產生';

  @override
  String get cloudSyncPasswordStoredHint => '已儲存密碼；留空表示繼續使用已儲存的密碼';

  @override
  String get cloudSyncAdvancedTitle => '進階設定';

  @override
  String get cloudSyncBaseUrlLabel => 'WebDAV 網址';

  @override
  String get cloudSyncBaseUrlSecurityNote =>
      '建議使用 HTTPS 加密連線；HTTP 明文連線僅建議在可信網路環境下使用';

  @override
  String get cloudSyncRemoteFolderLabel => '遠端目錄';

  @override
  String get cloudSyncStatusTitle => '同步狀態';

  @override
  String get cloudSyncLastSyncedLabel => '上次同步';

  @override
  String get cloudSyncLastErrorLabel => '最近錯誤';

  @override
  String cloudSyncLastSyncedAt(String time) {
    return '上次同步：$time';
  }

  @override
  String get cloudSyncSyncing => '正在同步…';

  @override
  String cloudSyncLastError(String message) {
    return '最近錯誤：$message';
  }

  @override
  String get cloudSyncHelpTitle => '如何取得堅果雲應用程式密碼';

  @override
  String get cloudSyncHelpBody =>
      '開啟堅果雲網頁或客戶端 → 帳戶資料 → 安全選項 → 新增應用程式密碼，WebDAV 網址預設為 https://dav.jianguoyun.com/dav/ ';

  @override
  String get cloudSyncTestConnection => '測試連線';

  @override
  String get cloudSyncSyncNow => '立即同步';

  @override
  String get cloudSyncSyncNowSubtitle => '與其他設備對齊課表：先拉取雲端更新，再上傳本地修改';

  @override
  String get cloudSyncTestSuccess => 'WebDAV 連線成功';

  @override
  String get cloudSyncTestFailed => 'WebDAV 連線失敗，請檢查帳號、應用程式密碼和網絡';

  @override
  String get cloudSyncResultUploaded => '已上傳到雲端';

  @override
  String get cloudSyncResultDownloaded => '已從雲端還原';

  @override
  String get cloudSyncResultUpToDate => '本機與雲端已一致';

  @override
  String get cloudSyncResultCancelled => '已取消同步';

  @override
  String cloudSyncResultFailed(String message) {
    return '同步失敗：$message';
  }

  @override
  String get cloudSyncConflictTitle => '偵測到同步衝突';

  @override
  String get cloudSyncConflictBody => '本機和雲端都有新的修改，請選擇保留哪一邊的資料';

  @override
  String get cloudSyncUseRemoteAction => '使用雲端';

  @override
  String get cloudSyncKeepLocalAction => '保留本機';

  @override
  String get cloudSyncAccountSectionTitle => '雲端帳號';

  @override
  String get cloudSyncNotConnectedHint => '連接堅果雲後，可在多裝置間同步課表與匯入資料';

  @override
  String get cloudSyncConnectAccount => '連接堅果雲';

  @override
  String cloudSyncConnectedAs(String email) {
    return '已連接：$email';
  }

  @override
  String get cloudSyncDisconnect => '中斷連線';

  @override
  String get cloudSyncDisconnectTitle => '中斷雲端同步帳號';

  @override
  String get cloudSyncDisconnectBody =>
      '中斷後將清除本機儲存的 WebDAV 憑證，課表資料仍保留在本機，是否繼續？';

  @override
  String get cloudSyncLoginSheetTitle => '連接堅果雲';

  @override
  String get cloudSyncLoginSheetSubtitle => '請使用應用程式專用密碼，不要使用堅果雲登入密碼';

  @override
  String get cloudSyncConfirmConnect => '確認連接';

  @override
  String get cloudSyncConnectSuccess => '帳號連接成功';

  @override
  String get cloudBackupSectionTitle => '可恢復版本';

  @override
  String get cloudBackupSectionSubtitle => '每次同步都會自動保留可恢復版本';

  @override
  String get cloudBackupCurrentLabel => '當前版本';

  @override
  String get cloudBackupCurrentBadge => '當前';

  @override
  String get cloudBackupCreateNow => '立即備份';

  @override
  String get cloudBackupViewAll => '查看全部可恢復版本';

  @override
  String get cloudBackupEmpty => '暫無可恢復版本，同步後會自動生成';

  @override
  String get cloudBackupSourceAuto => '自動備份';

  @override
  String get cloudBackupSourceManual => '手動備份';

  @override
  String get cloudBackupDefaultDeviceLabel => '本機';

  @override
  String get cloudBackupDeviceLabelTitle => '裝置名稱';

  @override
  String get cloudBackupDeviceLabelHint => '在備份列表中顯示，例如「我的手機」';

  @override
  String cloudBackupSummary(int profileCount, int courseCount) {
    return '$profileCount 個課表 · $courseCount 門課程';
  }

  @override
  String get cloudBackupRestoreTitle => '恢復到此備份';

  @override
  String cloudBackupRestoreBody(String time) {
    return '將恢復到 $time 的課表，本地未同步的修改會丟失，是否繼續？';
  }

  @override
  String get cloudBackupRestoreAction => '恢復';

  @override
  String get cloudBackupRestoreSuccess => '已恢復到此備份';

  @override
  String cloudBackupRestoreFailed(String message) {
    return '恢復失敗：$message';
  }

  @override
  String get cloudBackupDeleteTitle => '刪除此備份';

  @override
  String cloudBackupDeleteBody(String time) {
    return '確定刪除 $time 的雲端備份嗎？此操作不可撤銷';
  }

  @override
  String get cloudBackupDeleteSuccess => '備份已刪除';

  @override
  String cloudBackupDeleteFailed(String message) {
    return '刪除失敗：$message';
  }

  @override
  String get cloudBackupCreateSuccess => '備份已保存到雲端';

  @override
  String cloudBackupCreateFailed(String message) {
    return '備份失敗：$message';
  }

  @override
  String get cloudBackupUploadAsCurrentTitle => '設為當前雲端版本';

  @override
  String get cloudBackupUploadAsCurrentBody =>
      '是否將此備份設為當前雲端版本？建議開啟，可避免其他設備同步衝突';

  @override
  String get cloudBackupUploadAsCurrentYes => '設為當前版本';

  @override
  String get cloudBackupUploadAsCurrentNo => '僅恢復本地';

  @override
  String get cloudBackupDetailDevice => '設備';

  @override
  String get cloudBackupDetailSource => '來源';

  @override
  String get cloudBackupDetailSummary => '內容';

  @override
  String get lanEditEntryTitle => '局域網編輯';

  @override
  String get lanEditEntrySubtitle => '在電腦瀏覽器中編輯當前課表';

  @override
  String get lanEditTitle => '局域網編輯';

  @override
  String get lanEditIntro =>
      '開啟後，同一 Wi-Fi 或手機熱點下的電腦可透過瀏覽器編輯當前課表，資料不會上傳雲端，關閉後即停止存取';

  @override
  String get lanEditStart => '開啟局域網編輯';

  @override
  String get lanEditStop => '停止';

  @override
  String get lanEditStatusRunning => '編輯會話進行中';

  @override
  String get lanEditAddressLabel => '存取網址';

  @override
  String get lanEditAddressUnavailable => '未偵測到局域網 IP，請確認已連接 Wi-Fi 或已開啟熱點';

  @override
  String get lanEditPinLabel => 'PIN';

  @override
  String get lanEditPortLabel => '連接埠';

  @override
  String get lanEditCopyAddress => '複製網址';

  @override
  String get lanEditCopied => '網址已複製';

  @override
  String get lanEditHotspotHint => '若宿舍 Wi-Fi 無法存取，請嘗試用手機開熱點，再讓電腦連接該熱點';

  @override
  String get lanEditQrHint => '電腦瀏覽器掃描上方二維碼可開啟控制台（連結已含 PIN，需同一區域網路）';

  @override
  String get lanEditStartFailed => '啟動失敗';

  @override
  String get lanEditConnectedClientsLabel => '已連接';

  @override
  String get lanEditConnectedClientsNone => '暫無';

  @override
  String lanEditConnectedClientsValue(int count) {
    return '$count 台';
  }

  @override
  String get lanEditLastActivityLabel => '最近活動';

  @override
  String get lanEditKeepAliveWhenLeavingTitle => '離開後保持開啟';

  @override
  String get lanEditKeepAliveWhenLeavingSubtitle =>
      '開啟後，返回設定頁不會自動關閉局域網編輯；關閉後離開本頁即停止';

  @override
  String get aboutSupportSectionTitle => '關於與支持';

  @override
  String get feedbackEntryTitle => '問題回饋';

  @override
  String get feedbackEntrySubtitle => 'Issue、社區渠道和建議反饋入口';

  @override
  String get aboutEntryTitle => '關於軟件';

  @override
  String get aboutEntrySubtitle => '開源說明、版本更新和 GitHub 倉庫';

  @override
  String get setSemesterStartDateAction => '設定開學日期';

  @override
  String get semesterStartDateAction => '開學日期';

  @override
  String get syncCurrentWeekAction => '同步目前周';

  @override
  String semesterWeekCountAction(int count) {
    return '$count 周';
  }

  @override
  String get selectSemesterWeekCountTitle => '選擇學期周數';

  @override
  String get selectSemesterWeekCountSubtitle => '不同學校可按實際教學周數調整';

  @override
  String get unifiedCourseCardColorTitle => '統一課程卡片顏色';

  @override
  String get unifiedCourseCardColorSubtitle => '關閉後繼續使用每門課程自己的顏色';

  @override
  String get importRandomCourseColorTitle => '隨機課程顏色';

  @override
  String get importRandomCourseColorSubtitle => '依課程名與教師自動分配預設色';

  @override
  String get importRandomColorGroupTitle => '隨機配色組';

  @override
  String get colorGroupAll => '全部顏色';

  @override
  String get colorGroupPastel => '馬卡龍系';

  @override
  String get colorGroupVibrant => '活潑系';

  @override
  String get colorGroupDeep => '深色系';

  @override
  String get colorGroupDopamine => '多巴胺系';

  @override
  String get colorGroupSunset => '落日系';

  @override
  String get colorGroupOcean => '海洋系';

  @override
  String get courseRecolorTileTitle => '課表重新配色';

  @override
  String get courseRecolorTileSubtitle => '不用重新匯入，隨時一鍵為全部課程換一套顏色';

  @override
  String get courseRecolorSheetTitle => '課表重新配色';

  @override
  String get courseRecolorSheetDescription =>
      '每次「換一批」都會為全部課程刷一套隨機顏色；不滿意可以切回上一套，或回到匯入時的原色。';

  @override
  String get courseRecolorNewBatchButton => '換一批顏色';

  @override
  String get courseRecolorPrevious => '上一套';

  @override
  String get courseRecolorNext => '下一套';

  @override
  String courseRecolorSchemePosition(int index, int total) {
    return '第 $index/$total 套';
  }

  @override
  String get courseRecolorNoCoursesToast => '尚無課程，請先匯入或新增課程再換顏色';

  @override
  String get courseImportTitle => '匯入課程';

  @override
  String get chooseImportMethodTitle => '選擇匯入方式';

  @override
  String get chooseImportMethodSubtitle =>
      '現在支持傳統 .ics 日歷匯入、識圖匯入，以及從倉庫讀取適配器的教務系統匯入';

  @override
  String get importMethodIcsTitle => '.ics 日歷匯入';

  @override
  String get importMethodIcsSubtitle => '從其他課表應用匯出的日歷檔案';

  @override
  String get importMethodIcsFooter => '進入後直接選擇 .ics 檔案，可追加匯入或替換現有課程';

  @override
  String get importMethodAiTitle => '識圖匯入';

  @override
  String get importMethodAiSubtitle => '從課表截圖識別並匯入';

  @override
  String get importMethodAiFooter =>
      '先複製提示詞，再到豆包專家模式發送截圖和提示詞，把返回的 JSON 複製回來匯入，最後選擇開學日期';

  @override
  String get importMethodWarehouseTitle => '教務系統匯入';

  @override
  String get importMethodWarehouseSubtitle => '登入學校教務系統匯入';

  @override
  String get importMethodWarehouseFooter => '進入後選擇學校和適配器，可直接打開教務網頁登錄並執行匯入';

  @override
  String get importMethodSpreadsheetTitle => '表格匯入';

  @override
  String get importMethodSpreadsheetSubtitle => '填寫 Excel / CSV 模板後匯入';

  @override
  String get importMethodSpreadsheetFooter =>
      '支持 .csv 與 .xlsx，可下載官方模板填寫後選擇檔案匯入';

  @override
  String get spreadsheetImportTitle => '表格匯入';

  @override
  String get spreadsheetScenarioIntro =>
      '輕嶼模板依表頭辨識欄位：必填為課程名、星期、開始節、結束節及週次；其餘為可選，可下載完整模板，或只保留必要欄，亦相容 WakeUp 7 欄格式';

  @override
  String get spreadsheetStep1Subtitle => '下載完整模板填寫，或只保留必填欄與上課週（或開始週+結束週）做最小匯入';

  @override
  String get spreadsheetStep2Subtitle => '填寫完成後另存為 .csv 或直接保留 .xlsx';

  @override
  String get spreadsheetStep3Subtitle => '選擇檔案匯入；如有識別提醒會先展示，再選擇追加或替換';

  @override
  String get spreadsheetSupportedFilesSuffix => '支持 .csv 與 .xlsx（僅讀取第一個工作表）';

  @override
  String get chooseSpreadsheetFileAction => '選擇表格檔案';

  @override
  String get downloadSpreadsheetTemplateAction => '下載輕嶼課表模板';

  @override
  String get spreadsheetImportWarningsTitle => '匯入提醒';

  @override
  String get spreadsheetImportWarningsMessage => '以下行未能匯入，其餘課程可繼續：';

  @override
  String get spreadsheetImportWarningsContinue => '繼續匯入';

  @override
  String get spreadsheetFormatUnrecognized =>
      '未識別表格格式，請使用輕嶼課表模板；也相容 WakeUp 等同列格式';

  @override
  String get icsImportTitle => '.ics 日歷匯入';

  @override
  String get applicableScenarioTitle => '適用場景';

  @override
  String get icsScenarioIntro =>
      '如果你已經能在 WakeUp 等課表應用裡匯入教務系統課程，再匯出為 .ics 檔案，這條路最穩';

  @override
  String stepLabel(String step) {
    return '步晝 $step';
  }

  @override
  String get icsStep1Subtitle => '先在其他課表應用裡匯出 .ics 日歷檔案';

  @override
  String get icsStep2Subtitle => '回到這裡選擇檔案，可選“追加匯入”或“替換現有”';

  @override
  String get icsStep3Subtitle => '匯入前還會讓你確認開學日期，以及課表第 1 周對應校歷第幾周';

  @override
  String get supportedFilesTitle => '支持的檔案';

  @override
  String get supportedFilesSuffix => '檔案後綴必須是 .ics';

  @override
  String get supportedFilesImageHint => '如果你手裡只有截圖，不要走這裡，請返回上一頁選擇“識圖匯入”';

  @override
  String get chooseIcsFileAction => '選擇 .ics 檔案';

  @override
  String get timetableAppName => '輕嶼課表';

  @override
  String get switchProfileHint => '點擊切換課表';

  @override
  String get moreTooltip => '更多';

  @override
  String get pleaseSetSemesterStartDate => '請先在課表設定裡填寫開學日期';

  @override
  String get deleteScheduleTitle => '刪除日程';

  @override
  String get deleteLessonTitle => '刪除這節課';

  @override
  String get cancelAction => '取消';

  @override
  String get confirmAction => '確認';

  @override
  String get deleteAction => '刪除';

  @override
  String deletedCourseMessage(String name) {
    return '已刪除：$name';
  }

  @override
  String get deleteFailed => '刪除失敗';

  @override
  String get rescheduleFailed => '調課失敗';

  @override
  String get timetableManagement => '課表管理';

  @override
  String weekLabel(int week) {
    return '第 $week 周';
  }

  @override
  String sectionLabel(int section) {
    return '第 $section 節';
  }

  @override
  String get feedbackTitle => '問題回饋';

  @override
  String get feedbackIntro => '如果你遇到崩溃、課程顯示異常、匯入問題，或者想提交功能建議，可以通過下面這些渠道反饋';

  @override
  String get feedbackIssueHint => '涉及複現步晝、截圖、版本號和日誌的問題，建議優先走 GitHub Issue';

  @override
  String get githubIssueTitle => 'GitHub Issue';

  @override
  String get githubIssueSubtitle => '打開倉庫 Issue 頁面，可提交問題、建議或查看已有反饋記錄';

  @override
  String get openIssuePage => '打開 Issue 頁面';

  @override
  String get copyAddress => '複製地址';

  @override
  String get copiedIssueAddress => '已複製 Issue 地址';

  @override
  String get copyXiaohongshuId => '複製小紅書號';

  @override
  String get copiedXiaohongshuId => '已複製小紅書號';

  @override
  String get copyCoolapkId => '複製酷安號';

  @override
  String get copiedCoolapkId => '已複製酷安號';

  @override
  String get copyQqGroupId => '複製群號';

  @override
  String get copiedQqGroupId => '已複製 QQ 群號';

  @override
  String get copiedWechatOaName => '已複製公眾號名稱';

  @override
  String get feedbackWechatOaOpenHint => '已複製公眾號名稱，請到微信中貼上搜尋';

  @override
  String get feedbackOpeningChannel => '正在打開…';

  @override
  String get feedbackOpenChannelFailed => '無法打開，已複製相關資訊';

  @override
  String get timetableProfilesTitle => '課表管理';

  @override
  String get createTimetableTooltip => '新建課表';

  @override
  String coursesAndWeekSummary(int count, int week) {
    return '$count 門課程 · 第 $week 周';
  }

  @override
  String get moreActionsTooltip => '更多操作';

  @override
  String get switchToThisTimetable => '切換到此課表';

  @override
  String get renameAction => '重新命名';

  @override
  String get duplicateAction => '複製';

  @override
  String get clearCoursesAction => '清空課程';

  @override
  String get usingNow => '正在使用';

  @override
  String switchedToProfile(String name) {
    return '已切換到 $name';
  }

  @override
  String get createTimetableTitle => '新建課表';

  @override
  String get timetableNameLabel => '課表名稱';

  @override
  String get timetableNameHint => '例如：大二下';

  @override
  String get createAction => '建立';

  @override
  String createdProfile(String name) {
    return '已建立課表：$name';
  }

  @override
  String get renameTimetableTitle => '重新命名課表';

  @override
  String get saveAction => '保存';

  @override
  String renamedProfile(String name) {
    return '已重新命名為 $name';
  }

  @override
  String get clearCurrentTimetableTitle => '清空目前課表';

  @override
  String clearCurrentTimetableMessage(String name) {
    return '確定清空“$name”的全部課程嗎？課表設定會保留';
  }

  @override
  String get clearAction => '清空';

  @override
  String clearedProfile(String name) {
    return '已清空課表：$name';
  }

  @override
  String get noCoursesInCurrentProfile => '目前課表已經沒有有課程';

  @override
  String get deleteTimetableTitle => '刪除課表';

  @override
  String deleteTimetableMessage(String name) {
    return '確定刪除“$name”嗎？';
  }

  @override
  String deletedProfile(String name) {
    return '已刪除課表：$name';
  }

  @override
  String get keepAtLeastOneProfile => '至少保留一個課表';

  @override
  String get dataTransferTitle => '資料備份與遷移';

  @override
  String get qrTransferSectionTitle => 'QR 碼面對面傳輸';

  @override
  String get qrTransferSectionSubtitle => '兩部手機靠近，掃碼即可直接傳輸課表與全部設定，無需網絡';

  @override
  String get qrTransferSendCurrent => 'QR 碼發送目前課表';

  @override
  String get qrTransferSendAll => 'QR 碼發送全部資料';

  @override
  String get qrTransferScanReceive => '掃碼接收課表資料';

  @override
  String qrTransferFrameProgress(int sent, int total) {
    return '已發送 $sent 幀，約需 $total 幀';
  }

  @override
  String get qrTransferSendHint => '請對方開啟「掃碼接收」，將相機對準此螢幕，保持到接收完成';

  @override
  String get qrTransferStop => '停止發送';

  @override
  String get qrTransferScanTitle => '掃碼接收';

  @override
  String get qrTransferScanHint => '將相機對準對方手機螢幕，保持穩定，等待進度完成';

  @override
  String qrTransferReceiveProgress(int received, int decoded, int total) {
    return '已接收 $received 幀 · 已解出 $decoded/$total';
  }

  @override
  String get qrTransferReceiveComplete => '資料接收完成，正在匯入…';

  @override
  String get qrTransferSessionMismatch => '偵測到不同傳輸內容，請確認只對準一份資料';

  @override
  String get qrTransferChecksumFailed => '傳輸校驗失敗，請重新開始';

  @override
  String get qrTransferRawLengthMismatch => '接收資料長度校驗失敗，請重新開始';

  @override
  String get qrTransferDecompressionFailed => '資料解壓失敗，請重新開始';

  @override
  String get qrTransferPlaintextWarning =>
      'QR 碼傳輸是明文，附近相機可能讀取內容。請先確認來源，未經確認不會覆蓋資料。';

  @override
  String get qrTransferResourceLimit => '接收資料超過 QR 碼傳輸資源上限，請重新開始並使用較小的備份。';

  @override
  String get qrTransferSessionExpired => 'QR 碼傳輸已逾時，請重新開始並只對準一台裝置。';

  @override
  String get qrTransferFullBackupWarning => '確認後，此完整備份會取代本裝置上的資料。';

  @override
  String get qrTransferImportFullBackup => '匯入完整備份';

  @override
  String get qrTransferDecodeFailed => 'QR 碼資料解碼失敗，請重新開始';

  @override
  String get qrTransferRestart => '重新開始';

  @override
  String get qrTransferSampleFps => '取樣幀率';

  @override
  String get qrTransferDecodeFps => '解碼幀率';

  @override
  String get qrTransferReceiveSpeed => '接收速度';

  @override
  String get qrTransferElapsed => '已用時間';

  @override
  String get qrTransferNewFrames => '新增幀';

  @override
  String get qrTransferDuplicateFrames => '重複幀';

  @override
  String get qrTransferBlockSize => '單塊大小';

  @override
  String get qrTransferBlockCount => '資料塊數';

  @override
  String get qrTransferFileData => '檔案資料';

  @override
  String qrTransferFileDataDetail(String rawSize, String compressedSize) {
    return '原始 $rawSize · 壓縮 $compressedSize';
  }

  @override
  String get qrTransferShareWeek => '分享本週課表';

  @override
  String get qrTransferShareSelectedCourses => '分享勾選的課程';

  @override
  String get qrTransferShareTimeTemplate => '分享時間範本';

  @override
  String get qrTransferSelectCoursesDone => '完成';

  @override
  String get dataTransferUndoSuccess => '已撤銷本次匯入';

  @override
  String get dataTransferUndoFailed => '撤銷失敗';

  @override
  String get selectImportModeMerge => '合併變更';

  @override
  String get fullExportTitle => '完整匯出';

  @override
  String get fullExportSubtitle => '支持匯出目前課表，或一次匯出全部課表、時間範本和目前選中狀態';

  @override
  String get exportCurrentTimetable => '匯出目前課表';

  @override
  String get exportAllData => '匯出全部資料';

  @override
  String get fullImportTitle => '完整匯入';

  @override
  String get fullImportSubtitle => '匯入時可以選擇覆蓋目前課表，或直接匯入為一個新課表，建議先匯出自己的備份';

  @override
  String get chooseFileAndImport => '選擇檔案並匯入';

  @override
  String get transferOverviewTitle => '目前可遷移內容';

  @override
  String courseCountBullet(int count) {
    return '課程數量：$count 門';
  }

  @override
  String currentTimetableBullet(String name) {
    return '目前課表：$name';
  }

  @override
  String allTimetablesBullet(int count) {
    return '全部課表：$count 個';
  }

  @override
  String timeSchemeCountBullet(int count) {
    return '時間範本：$count 套';
  }

  @override
  String currentWeekBullet(int week) {
    return '目前周：第 $week 周';
  }

  @override
  String get semesterStartUnsetBullet => '開學日期：未設定';

  @override
  String semesterStartBullet(String date) {
    return '開學日期：$date';
  }

  @override
  String fileExtensionBullet(String extension) {
    return '檔案後綴：.$extension';
  }

  @override
  String get selectImportModeTitle => '選擇匯入方式';

  @override
  String get selectImportModeMessage => '你可以覆蓋目前課表，或者把備份匯入成一個新的獨立課表';

  @override
  String get replaceCurrentTimetable => '覆蓋目前課表';

  @override
  String get importAsNewTimetable => '匯入為新課表';

  @override
  String get createdNewTimetableAfterImport => '匯入成功，已建立新的課表';

  @override
  String get backupRestoredSuccess => '匯入成功，備份資料已還原';

  @override
  String get importFailedInvalidFile => '匯入失敗，請確認檔案有效';

  @override
  String get welcomeTitle => '歡迎使用';

  @override
  String get welcomeAppName => '輕嶼課表';

  @override
  String get welcomeSubtitle => '你可以先開始使用，也可以直接匯入課程或從備份還原';

  @override
  String get thirdPartyDisclaimer =>
      '特此聲明：本應用由第三方開發者獨立開發，僅用於學習研究用途，不屬於小米官方軟件，與小米科技有限責任公司無任何隸屬、合作或授權關係。如涉及內容侵權，請權利方聯繫作者，我們將第一時間下架並刪除相關內容。';

  @override
  String get startUsingTitle => '開始使用';

  @override
  String get startUsingSubtitle => '直接進入軟件，並繼續完成首次使用說明';

  @override
  String get importTimetableTitle => '匯入課表';

  @override
  String get importTimetableSubtitle => '從 .ics 檔案或 AI 解析結果匯入課程';

  @override
  String get restoreBackupTitle => '從備份還原';

  @override
  String get restoreBackupSubtitle => '從 .mikcb 備份檔案還原舊資料';

  @override
  String get viewGuideTitle => '查看功能說明';

  @override
  String get viewGuideSubtitle => '先了解權限、超級島和基礎設定';

  @override
  String get migrationTitle => '遷移舊資料';

  @override
  String get migrationSafeTitle => '別擔心，這不是資料丢失';

  @override
  String get migrationSafeSubtitle =>
      '我們更換了應用包名，所以桌面上會暫時出現兩個應用圖示，這是正常現象，舊資料仍在舊版應用裡，請先去舊版備份，再回到新版匯入';

  @override
  String get migrationStep1Title => '打開舊版應用';

  @override
  String get migrationStep1Subtitle =>
      '進入“資料備份與遷移”頁面後，請點“匯出全部資料”，不要點“匯出目前課表”，也不要先卸載舊版';

  @override
  String get migrationStep2Title => '保存備份檔案';

  @override
  String get migrationStep2Subtitle =>
      '舊版匯出後會彈出系統分享面板，優先選擇“保存到檔案”，建議存到 下載 / Download 檔案夾';

  @override
  String get migrationStep3Title => '回到目前版本匯入';

  @override
  String get migrationStep3Subtitle =>
      '回到新版後，通過系統檔案選擇器到 下載 / Download 檔案夾選中 .mikcb 備份檔案即可還原，確認新版資料正常後，再卸載舊版應用';

  @override
  String get migrationNoSaveToFilesTitle => '如果沒有有“保存到檔案”';

  @override
  String get migrationNoSaveToFilesSubtitle =>
      '可以先分享到微信任意一個聊天，然後在微信裡點開這個備份檔案並保存，保存後通常會出現在 Download / WeiXin 檔案夾裡，再回到新版選擇這個 .mikcb 檔案匯入';

  @override
  String get openingOldApp => '正在打開舊版...';

  @override
  String get openOldAppForBackup => '打開舊版去備份';

  @override
  String get backupDoneGoImport => '我已完成備份，去匯入';

  @override
  String get startFreshWithoutMigration => '以全新應用開始，不遷移';

  @override
  String get openOldAppFailed => '未能打開舊版應用，請手動返回桌面打開舊版';

  @override
  String get supportCreatorTitle => '請作者喝杯咖啡';

  @override
  String get supportHeroTitle => '支持輕嶼課表繼續更新';

  @override
  String get supportHeroSubtitle => '你的支持會直接用於維護課表、教務匯入適配與體驗優化';

  @override
  String get supportChipFixes => '修複問題';

  @override
  String get supportChipAdapters => '教務適配';

  @override
  String get supportChipPolish => '體驗優化';

  @override
  String get supportMethodTitle => '選擇支持方式';

  @override
  String get wechatLabel => '微信';

  @override
  String get alipayLabel => '支付寶';

  @override
  String get supportWeChatHint => '使用微信掃一掃支持作者';

  @override
  String get supportAlipayHint => '使用支付寶掃一掃支持作者';

  @override
  String get viewLargeImage => '查看大圖';

  @override
  String get saveToGallery => '保存到相冊';

  @override
  String get supportCompleteThanks => '感谢你支持輕嶼課表繼續打磨 ❤️';

  @override
  String get supportConfirmed => '我已經支持了';

  @override
  String get donorListTitle => '鳴谢名單';

  @override
  String get donorListLoadFailed => '暫時無法加載在線鳴谢名單';

  @override
  String get reloadAction => '重新加載';

  @override
  String updatedAtLabel(String time) {
    return '更新於 $time';
  }

  @override
  String get donorListEmpty => '名單還沒有有填寫，你可以直接編輯 docs/donors.json 後重新發布';

  @override
  String get savedToGallery => '已保存到相冊';

  @override
  String get saveToGalleryFailed => '保存到相冊失敗';

  @override
  String saveFailedWithError(String error) {
    return '保存失敗：$error';
  }

  @override
  String get supportRunningBadge => '運行中';

  @override
  String get supportTapQrHint => '點擊放大掃碼';

  @override
  String get supportSaveShort => '保存';

  @override
  String get supportConfirmedShort => '已支持';

  @override
  String get donorSearchHint => '搜暱稱/寄語...';

  @override
  String get donorSortLargeFirst => '大額優先';

  @override
  String get donorSortSmallFirst => '小額優先';

  @override
  String get supportMonthlyGoalLabel => '本月伺服器和證書續期進度';

  @override
  String supportGoalRaised(String raised, String goal) {
    return '已籌: $raised / 目標 $goal';
  }

  @override
  String supportBackerCount(int count) {
    return '已有 $count 人獻出愛心';
  }

  @override
  String get supportDonorListFooter => '名單永久保留 💖';

  @override
  String supportMarqueeThanks(String name, String amount) {
    return '🎉 感謝 $name 贊助 $amount';
  }

  @override
  String get supportMarqueeTail => '輕嶼課表正在穩定運行中，期待你的每一次陪伴與愛心！';

  @override
  String get scanQrWechatTitle => '使用微信掃描二維碼';

  @override
  String get scanQrAlipayTitle => '使用支付寶掃描二維碼';

  @override
  String get scanQrSubtitle => '截圖並導入掃一掃，感謝支持！';

  @override
  String get courseOverviewTitle => '課程總覽與編輯';

  @override
  String get addNewCourseTooltip => '添加新課程';

  @override
  String get emptyCourseOverviewHint => '長按課表或點擊右上角添加課程';

  @override
  String conflictDetectedMessage(int count) {
    return '檢測到 $count 門排課存在實際衝突，課程列表已標記衝突項';
  }

  @override
  String conflictCountLabel(int count) {
    return '衝突 $count 節';
  }

  @override
  String scheduledCountLabel(int count) {
    return '共排課 $count 節';
  }

  @override
  String scheduledCountWithConflictHint(int count) {
    return '共排課 $count 節 · 展開查看衝突詳情';
  }

  @override
  String courseTimeSummary(int day, int start, int end) {
    return '時間: 星期$day 第$start-$end節';
  }

  @override
  String get teacherUnset => '未置';

  @override
  String get locationUnset => '未置';

  @override
  String courseDetailSummary(
    String weekDescription,
    String teacher,
    String location,
  ) {
    return '$weekDescription  教師: $teacher  教室: $location';
  }

  @override
  String courseDetailSummaryWithConflict(
    String weekDescription,
    String teacher,
    String location,
    String conflictSummary,
  ) {
    return '$weekDescription  教師: $teacher  教室: $location\n衝突課程: $conflictSummary';
  }

  @override
  String get confirmDeleteTitle => '確認刪除';

  @override
  String confirmDeleteCourseMessage(String name) {
    return '確定要刪除課程“$name”嗎？';
  }

  @override
  String get currentScheduleTitle => '目前排課';

  @override
  String get currentScheduleSubtitle => '這裡的星期、節次、教室、周次和單雙周只蠅響目前這一條排課';

  @override
  String get timeSchemeLabel => '上課時間方案';

  @override
  String followCurrentTimetableWithName(String name) {
    return '跟隨目前課表（$name）';
  }

  @override
  String get followCurrentTimetableDescription =>
      '未手動指定時，依上課地點自動匹配時間範本；未命中則跟隨課表主時間範本';

  @override
  String get overrideTimeSchemeDescription => '這門課會單獨使用所選時間範本，不跟隨目前課表主時間範本';

  @override
  String get weekdayLabel => '星期';

  @override
  String get startSectionLabel => '開始節次';

  @override
  String get endSectionLabel => '結束節次';

  @override
  String timeRangeLabel(String start, String end) {
    return '時間: $start - $end';
  }

  @override
  String get locationLabel => '上課地點';

  @override
  String get singleLessonWeekTitle => '上課周次';

  @override
  String get singleLessonWeekSubtitle => '單節課只會出現在一個周次裡，適合補課、臨時加課';

  @override
  String get selectWeekLabel => '選擇周次';

  @override
  String get weekSettingsTitle => '周次設定';

  @override
  String get rangeWeeksLabel => '連續周';

  @override
  String get customWeeksLabel => '自定義周';

  @override
  String get startWeekLabel => '開始周';

  @override
  String get endWeekLabel => '結束周';

  @override
  String get allWeeksFilter => '全部';

  @override
  String get oddWeeksFilter => '單周';

  @override
  String get evenWeeksFilter => '雙周';

  @override
  String get rangeWeeksAllHint => '按開始周到結束周連續排課';

  @override
  String get rangeWeeksOddHint => '只保留範圍內的單周';

  @override
  String get rangeWeeksEvenHint => '只保留範圍內的雙周';

  @override
  String get selectAllAction => '全選';

  @override
  String get selectOddWeeksAction => '單周';

  @override
  String get selectEvenWeeksAction => '雙周';

  @override
  String selectedWeeksSummary(int count, String weeks) {
    return '已選 $count 周：第$weeks周';
  }

  @override
  String get courseColorTitle => '課程顏色';

  @override
  String get courseColorQuickSection => '常用顏色';

  @override
  String get customPaletteAction => '調色盤自定義顏色';

  @override
  String get colorPaletteTitle => '調色盤';

  @override
  String get colorHexLabel => '顏色 Hex';

  @override
  String get weekdayMon => '周一';

  @override
  String get weekdayTue => '周二';

  @override
  String get weekdayWed => '周三';

  @override
  String get weekdayThu => '周四';

  @override
  String get weekdayFri => '周五';

  @override
  String get weekdaySat => '周六';

  @override
  String get weekdaySun => '周日';

  @override
  String hueLabel(int value) {
    return '色相 $value';
  }

  @override
  String saturationLabel(int value) {
    return '饱和度 $value%';
  }

  @override
  String brightnessLabel(int value) {
    return '明度 $value%';
  }

  @override
  String get useThisColor => '使用這個顏色';

  @override
  String get selectAtLeastOneWeek => '請至少選擇一個上課周次';

  @override
  String get saveFailed => '保存失敗';

  @override
  String get courseAddedSuccess => '課程添加成功';

  @override
  String get courseUpdatedSuccess => '課程更新成功';

  @override
  String get aboutTitle => '關於軟件';

  @override
  String get loadingText => '讀取中';

  @override
  String versionLabel(String version) {
    return '版本 $version';
  }

  @override
  String get aboutHeroSubtitle =>
      '一個圍繞課表查看、課程提醒和 HyperOS 超級島體驗打磨的 Android 開源項目';

  @override
  String get platformLabel => '平台';

  @override
  String get focusLabel => '重點';

  @override
  String get updateLabel => '更新';

  @override
  String get prereleaseIncluded => '含預發布';

  @override
  String get stableOnly => '正式版';

  @override
  String get aboutUpdatesTitle => '版本更新';

  @override
  String get aboutUpdatesSubtitle => '檢查更新與立即下載';

  @override
  String get aboutChangelogTitle => '更新日誌';

  @override
  String get aboutChangelogSubtitle => '查看所有版本的更新內容';

  @override
  String get aboutPositioningTitle => '項目定位';

  @override
  String get aboutPositioningSubtitle => '這是什麼、適合誰、核心能力是什麼';

  @override
  String get aboutPositioningBullet1 => '支持周視圖課表、課程增刪改、.ics 匯入';

  @override
  String get aboutPositioningBullet2 => '已支持適配學校的教務系統網頁登錄匯入與完整備份遷移';

  @override
  String get aboutPositioningBullet3 =>
      '支持實時通知；HyperOS 3.0.300 起支持超級島 / 焦點通知展示';

  @override
  String get aboutPositioningBullet4 => '支持多課表、時間範本、主題色和卡片樣式自定義';

  @override
  String get aboutImportMigrationTitle => '匯入與遷移';

  @override
  String get aboutImportMigrationSubtitle => '目前匯入方式、備份還原和遷移建議';

  @override
  String get aboutImportMigrationBullet1 =>
      '目前版本已經支持適配學校的教務系統網頁登錄匯入；進入“匯入課程 > 教務系統匯入”後選擇學校和適配器即可';

  @override
  String get aboutImportMigrationBullet2 =>
      '如果你的學校暫時還沒有適配，仍然可以先在 WakeUp 等課表應用裡匯入課程，再匯出為日歷格式，然後在本應用匯入';

  @override
  String get aboutImportMigrationBullet3 =>
      '如果其他人已經在用本應用，也可以直接讓對方匯出完整備份檔案，你在“資料備份與遷移”裡匯入即可直接還原';

  @override
  String get aboutImportMigrationBullet4 =>
      '如果你會抓包、網頁偵錯或 JavaScript，也歡迎去 qingyu_warehouse 參與教務適配補充';

  @override
  String get aboutContributorsTitle => '代碼貢獻者';

  @override
  String get aboutContributorsSubtitle => '開發人員與教務匯入適配者名單';

  @override
  String get aboutRepositoryTitle => '開源倉庫';

  @override
  String get aboutRepositorySubtitle => 'GitHub 倉庫地址、源碼、Release 和反饋入口';

  @override
  String get aboutOpenSourceLicensesTitle => '開源許可';

  @override
  String get aboutOpenSourceLicensesSubtitle => '本應用協議與第三方組件許可證';

  @override
  String get aboutOpenSourceLicensesSearchHint => '搜尋組件名稱';

  @override
  String get aboutOpenSourceLicensesAppSectionTitle => '許可說明';

  @override
  String get aboutOpenSourceLicensesAppLicenseLabel =>
      '輕嶼課表源碼以 GPL-3.0-or-later 發佈。';

  @override
  String get aboutOpenSourceLicensesIntro => '下方列表為本應用使用的開源組件及其許可證，點進可查看全文。';

  @override
  String get aboutOpenSourceLicensesExtraSectionTitle => '許可說明';

  @override
  String get aboutOpenSourceLicensesExtraUmeng =>
      '友盟統計等分析服務僅在你同意隱私政策後啟用，適用友盟自身的用戶協議與隱私政策。';

  @override
  String get aboutOpenSourceLicensesExtraNote => '';

  @override
  String aboutOpenSourceLicensesPackagesSectionTitle(int count) {
    return '開源組件（$count）';
  }

  @override
  String aboutOpenSourceLicensesPackageSubtitle(int count) {
    return '$count 份許可證文本';
  }

  @override
  String get aboutOpenSourceLicensesLoadFailed => '加載許可證失敗，請稍後重試';

  @override
  String get aboutOpenSourceLicensesEmpty => '沒有匹配的組件';

  @override
  String get aboutAppLogsTitle => '應用日誌';

  @override
  String get aboutAppLogsSubtitle => '查看運行日誌';

  @override
  String get appLogsShareText =>
      '這是輕嶼課表匯出的應用日誌，包含整個軟件的本地運行記錄，可用於排查更新、匯入、通知、頁面與崩潰問題';

  @override
  String get appLogsShareSubject => '輕嶼課表 - 應用日誌';

  @override
  String get appLogsRecordingEnabled => '正在記錄應用日誌';

  @override
  String get appLogsRecordingDisabled => '應用日誌記錄已關閉';

  @override
  String get appLogsCopyAction => '複製日誌';

  @override
  String get appLogsCopied => '已複製目前日誌';

  @override
  String get appLogsExportAction => '導出日誌';

  @override
  String get appLogsClearAction => '清空日誌';

  @override
  String get appLogsCleared => '已清空應用日誌';

  @override
  String get appLogsClearFailed => '清空應用日誌失敗';

  @override
  String get appLogsSourceApp => '應用程式';

  @override
  String get appLogsSourceNative => '超級島';

  @override
  String get appLogsRecordingPausedHint => '記錄已關閉，下方為歷史紀錄，關閉後不再新增';

  @override
  String get timeSchemeTitle => '時間範本';

  @override
  String get newSchemeTooltip => '新建範本';

  @override
  String timeSchemeSummary(
    int sections,
    int profiles,
    int courses,
    int overrideCourses,
  ) {
    return '$sections 節 · $profiles 個課表 · $courses 節課程 · $overrideCourses 節副時間表';
  }

  @override
  String get viewUsageAction => '查看使用情況';

  @override
  String get applyToCurrentTimetable => '應用到目前課表';

  @override
  String get editSectionsAction => '編輯節次';

  @override
  String get createTimeSchemeTitle => '新建時間範本';

  @override
  String get timeSchemeNameLabel => '範本名稱';

  @override
  String get timeSchemeNameHint => '例如：本校夏季作息';

  @override
  String get renameTimeSchemeTitle => '重新命名時間範本';

  @override
  String renamedToMessage(String name) {
    return '已重新命名為 $name';
  }

  @override
  String get deleteTimeSchemeTitle => '刪除時間範本';

  @override
  String deleteTimeSchemeMessage(String name) {
    return '確定刪除“$name”嗎？正在使用中的範本不能刪除';
  }

  @override
  String deletedTimeSchemeMessage(String name) {
    return '已刪除時間範本：$name';
  }

  @override
  String get timeSchemeInUseMessage => '該範本正在被課表使用';

  @override
  String get copiedTimeSchemeMessage => '已複製時間範本';

  @override
  String appliedTimeSchemeMessage(String name) {
    return '已應用時間範本：$name';
  }

  @override
  String timeSchemeUsageTitle(String name) {
    return '“$name”的使用情況';
  }

  @override
  String get timeSchemeUsageIntro => '先看總蠅響範圍，再決定是直接編輯這套範本，還是先複製一套再改';

  @override
  String get profileCountLabel => '課表';

  @override
  String get courseCountLabel => '課程';

  @override
  String get overrideTimeSchemeLabel => '副時間表';

  @override
  String get directlyBoundProfilesTitle => '直接綁定這套範本的課表';

  @override
  String get directlyBoundProfilesEmpty => '目前沒有有課表直接使用這套範本';

  @override
  String get directlyBoundProfilesSubtitle => '這些課表切到這套範本後，預設都會按這套節次時間顯示';

  @override
  String get followMainSchemeCoursesTitle => '跟隨課表主時間表的課程';

  @override
  String get followMainSchemeCoursesEmpty => '目前沒有有課程通過課表主時間表間接使用它';

  @override
  String get followMainSchemeCoursesSubtitle =>
      '這些課程沒有有單獨設定副時間表，而是跟著所屬課表一起用這套範本';

  @override
  String get overrideSchemeCoursesTitle => '把它作為副時間表的課程';

  @override
  String get overrideSchemeCoursesEmpty => '目前沒有有課程把它作為副時間表';

  @override
  String get overrideSchemeCoursesSubtitle => '這些課程即使所在課表切換了主範本，也會繼續單獨使用這套時間';

  @override
  String get closeAction => '關閉';

  @override
  String get editTimeSchemeTitle => '編輯時間範本';

  @override
  String get backToSchemeList => '返回範本列表';

  @override
  String get currentInUse => '目前使用';

  @override
  String get quickGenerateAction => '快捷生成';

  @override
  String get addSectionAction => '新增一節';

  @override
  String get removeLastSectionAction => '刪除末節';

  @override
  String get resetDefaultAction => '還原預設';

  @override
  String get sectionTimesTitle => '節次時間';

  @override
  String get sectionTimesSubtitle => '如果目前課表正在使用這套範本，節次數量不能小於已使用的最大節次';

  @override
  String get schemeListCurrentLabel => '目前';

  @override
  String get schemeListCountLabel => '數量';

  @override
  String get sectionCountLabel => '節數';

  @override
  String get quickGenerateTimeSchemeTitle => '快捷生成課表時間';

  @override
  String get addBreakRuleAction => '新增大課間規則';

  @override
  String get afterSectionLabel => '第幾節後';

  @override
  String get breakDurationMinutesLabel => '休息多久(分)';

  @override
  String get fillNumbersValidationMessage => '請把節數和時長填寫為數字';

  @override
  String get timeSchemeEditorActiveAndCoursesHint =>
      '目前課表和部分課程正在使用這套時間範本，保存後會同步更新所有相關課表和課程';

  @override
  String get timeSchemeEditorActiveHint => '目前課表正在使用這套時間範本，保存後會同步更新所有使用它的課表';

  @override
  String get timeSchemeEditorOverrideHint =>
      '有課程正在把這套範本作為副時間表使用，保存後會同步更新所有引用課程';

  @override
  String get editTimeAction => '編輯時間';

  @override
  String editingSchemeLabel(String name) {
    return '正在編輯：$name';
  }

  @override
  String get copiedTimeSchemeShortMessage => '已複製時間範本';

  @override
  String get unnamedTimeScheme => '未命名範本';

  @override
  String get unsetLabel => '未選擇';

  @override
  String get timeSchemeUsageCourseRefPrefix => '課程引用：';

  @override
  String get mainTimeSchemeLabel => '主時間表';

  @override
  String get overrideTimeSchemeShortLabel => '副時間表';

  @override
  String timeSchemeBottomUsageSingle(String first) {
    return '$first';
  }

  @override
  String timeSchemeBottomUsageMulti(String first, int count) {
    return '$first 等 $count 節課程';
  }

  @override
  String get morningSectionCountLabel => '上午幾節';

  @override
  String get morningFirstSectionTimeLabel => '早上第一節時間';

  @override
  String get afternoonSectionCountLabel => '下午幾節';

  @override
  String get afternoonFirstSectionTimeLabel => '下午第一節時間';

  @override
  String get eveningSectionCountLabel => '晚上幾節';

  @override
  String get eveningFirstSectionTimeLabel => '晚上第一節時間';

  @override
  String get classDurationMinutesLabel => '單節課時長（分鐘）';

  @override
  String get smallBreakDurationMinutesLabel => '小課間時長（分鐘）';

  @override
  String get largeBreakRulesTitle => '大課間規則';

  @override
  String get noLargeBreakRulesHint => '未設定大課間規則，將全部使用小課間時長';

  @override
  String get deleteRuleTooltip => '刪除規則';

  @override
  String get generateAction => '生成';

  @override
  String get liveSettingsTitle => '超級島與通知';

  @override
  String get liveGroupReminders => '提醒';

  @override
  String get liveGroupDisplay => '顯示內容';

  @override
  String get liveGroupMaintenance => '維護與自檢';

  @override
  String get liveReminderTimingEntryTitle => '提醒時段';

  @override
  String get liveReminderTimingEntrySubtitle => '上課前、課中與下課提醒，以及重點提醒切入時機';

  @override
  String get liveBeforeClassDisplayEntryTitle => '上課前提醒顯示';

  @override
  String get liveDuringEndDisplayEntryTitle => '課中與下課提醒顯示';

  @override
  String get liveKeepAliveEntryTitle => '後台保活';

  @override
  String get liveKeepAliveEntrySubtitle => '隱藏後台、後台保活輔助服務和權限入口';

  @override
  String get liveTestingEntryTitle => '測試與診斷';

  @override
  String get liveTestingEntrySubtitle => '發送測試通知，檢查超級島和本地診斷日誌';

  @override
  String get followBeforeClassSetting => '跟隨上課前提醒';

  @override
  String get liveReminderTimingTitle => '提醒時段';

  @override
  String get liveReminderSwitchesTitle => '提醒開關';

  @override
  String get liveReminderSwitchesSubtitle => '不同提醒時段可以自由組合；這些開關互不替代';

  @override
  String get beforeClassReminderTitle => '上課前提醒';

  @override
  String beforeClassReminderSubtitle(int minutes) {
    return '在課程開始前 $minutes 分鐘彈出';
  }

  @override
  String get duringClassReminderTitle => '課中與下課提醒';

  @override
  String get duringClassReminderSubtitle => '只蠅響上課後到下課前的展示';

  @override
  String get liveClassReminderLeadTitle => '下課前多久切到超級島 / 重點提醒';

  @override
  String get liveClassReminderLeadOptionImmediate => '一上課就切換';

  @override
  String liveClassReminderLeadOptionMinutes(int minutes) {
    return '下課前 $minutes 分鐘切換';
  }

  @override
  String get liveDisplayModeTitle => '展示方式';

  @override
  String get liveDisplayModeSubtitle => '對已啟用的提醒時段生效';

  @override
  String get duringClassStatusNotificationTitle => '課中狀態欄通知';

  @override
  String get duringClassStatusNotificationImmediate => '上課後保留狀態欄通知';

  @override
  String get duringClassStatusNotificationBeforeEnd => '在下課提醒開始前保留普通通知文案';

  @override
  String get duringClassStatusNotificationPersistent =>
      '上課後持續顯示普通課中通知，到下課提醒前再切換';

  @override
  String get enableIslandDisplayTitle => '展示超級島';

  @override
  String get enableIslandDisplaySubtitle => '關閉後不會再嘗試觸發系統超級島';

  @override
  String get liveTimeThresholdTitle => '時間阈值';

  @override
  String get liveTimeThresholdSubtitle => '控製上課前彈出、下課前多久切到超級島 / 重點提醒，以及最後秒級倒計時';

  @override
  String get beforeClassPopupLabel => '上課前彈出時間';

  @override
  String beforeClassMinutesOption(int minutes) {
    return '$minutes 分鐘';
  }

  @override
  String get beforeEndSecondsLabel => '下課前秒級提醒阈值';

  @override
  String beforeEndSecondsOption(int seconds) {
    return '$seconds 秒';
  }

  @override
  String timeCorrectionLabel(String value) {
    return '鈴聲時間矯正：$value';
  }

  @override
  String get timeCorrectionTitle => '鈴聲時間校正';

  @override
  String get timeCorrectionHelp => '如果學校鈴聲比課表快幾秒，就調成提前；如果鈴聲慢幾秒，就調成延後';

  @override
  String get duringEndTimeDisplayLabel => '課中 / 下課提醒時間樣式';

  @override
  String get duringEndTimeDisplayHelp => '控製緊湊提醒裡顯示最近時間還是整段總時間';

  @override
  String get liveDisplayContentTitle => '顯示內容';

  @override
  String get liveDisplayContentSubtitle => '這組設定只蠅響目前階段，不會改動另一組提醒顯示';

  @override
  String get showCourseNameTitle => '顯示課程名';

  @override
  String get preferShortNameTitle => '優先顯示課程簡稱';

  @override
  String get preferShortNameSubtitle => '建議簡稱控製在 3 個字以內';

  @override
  String get showLocationTitle => '顯示地點';

  @override
  String get showCountdownTitle => '顯示倒計時';

  @override
  String get countdownFormatLabel => '倒計時格式';

  @override
  String get countdownFormatHelp => '純分鐘樣式按分鐘刷新，帶秒樣式按秒刷新';

  @override
  String get showStageTextTitle => '顯示階段狀態文案';

  @override
  String get showStageTextSubtitle => '關閉倒計時後，可繼續顯示“即將上課 / 上課中 / 下課提醒”';

  @override
  String get hidePrefixTextTitle => '隱藏前綴文案';

  @override
  String get hidePrefixTextSubtitle => '例如隱藏“即將上課”這類前綴';

  @override
  String get liveIslandPreviewTitle => '超級島預覽';

  @override
  String get liveIslandPreviewFollowBadge => '正在跟隨「課前提醒顯示」設定，調整課前提醒即可生效';

  @override
  String get liveIslandPreviewStageBeforeClass => '即將上課';

  @override
  String get liveIslandPreviewStageInClass => '上課中';

  @override
  String get liveIslandPreviewStageBeforeEnd => '下課提醒';

  @override
  String liveIslandPreviewUntilClassStart(String time) {
    return '距上課$time';
  }

  @override
  String liveIslandPreviewUntilClassEnd(String time) {
    return '距下課$time';
  }

  @override
  String get liveIslandPreviewSampleCourse => '高等數學';

  @override
  String get liveIslandPreviewSampleCourseShort => '高數';

  @override
  String get liveIslandPreviewSampleLocation => '三教-401';

  @override
  String get beforeClassQuickActionTitle => '上課前快捷操作';

  @override
  String get beforeClassQuickActionSubtitle =>
      '只在上課前提醒的展開通知裡顯示，靜音/免打擾會在下課後自動恢復，重啟手機也會恢復；免打擾首次可能會跳到系統授權頁';

  @override
  String get liveBeforeClassQuickActionAutoTitle => '自動執行';

  @override
  String get liveBeforeClassQuickActionAutoSubtitle =>
      '在上課前自動打開所選模式，下課後自動恢復，重啟手機也會恢復；免打擾需要先在系統設定中授權';

  @override
  String get liveBeforeClassQuickActionAutoOptionOff => '不自動執行';

  @override
  String liveBeforeClassQuickActionAutoOptionMinutes(int minutes) {
    return '上課前 $minutes 分鐘';
  }

  @override
  String liveMiuiLabelSizePreview(String value) {
    return '$value';
  }

  @override
  String get liveIslandVisualTitle => '左側圖示與展開態';

  @override
  String get liveIslandVisualSubtitle => '左側文字圖、展開態大圖示和自定義圖片都按目前階段單獨保存';

  @override
  String get liveMiuiLabelImageTitle => '小米島左側文字圖示';

  @override
  String get liveMiuiLabelImageSubtitle => '僅小米手機樣式生效，會把課程名或地點生成到左側圖示位';

  @override
  String get liveMiuiLabelContentLabel => '左側文字內容';

  @override
  String get liveMiuiLabelStyleLabel => '左側圖示樣式';

  @override
  String get liveMiuiLabelLogoTitle => '左側圖示 Logo';

  @override
  String get liveMiuiLabelLogoSubtitle => '僅在「圖示+文字」樣式下生效；未選擇時會繼續使用應用圖示';

  @override
  String liveMiuiLabelLogoCornerRadiusLabel(String value) {
    return '左側圖示圓角 $value';
  }

  @override
  String get liveMiuiLabelLogoCornerRadiusTitle => '左側圖示圓角';

  @override
  String liveMiuiLabelFontSizeLabel(String value) {
    return '左側文字大小 $value';
  }

  @override
  String get liveMiuiLabelFontSizeTitle => '左側文字大小';

  @override
  String liveMiuiLabelOffsetXLabel(String value) {
    return '左側文字水平偏移 $value';
  }

  @override
  String get liveMiuiLabelOffsetXTitle => '左側文字水平偏移';

  @override
  String liveMiuiLabelOffsetYLabel(String value) {
    return '左側文字垂直偏移 $value';
  }

  @override
  String get liveMiuiLabelOffsetYTitle => '左側文字垂直偏移';

  @override
  String get liveMiuiLabelFontWeightLabel => '左側文字粗細';

  @override
  String get liveMiuiLabelRenderQualityLabel => '左側文字清晰度';

  @override
  String get liveMiuiExpandedIconLabel => '展開態大圖示';

  @override
  String get selectImageAction => '選擇圖片';

  @override
  String get replaceImageAction => '更換圖片';

  @override
  String get liveDisplayConfigModeTitle => '配置方式';

  @override
  String get liveDisplayConfigModeSubtitle =>
      '打開後，課中和下課提醒會完全跟隨上課前提醒顯示，下面的獨立設定暫時不可編輯';

  @override
  String get followBeforeClassDisplayTitle => '跟隨上課前提醒設定';

  @override
  String get liveKeepAliveTitle => '後台保活';

  @override
  String get liveKeepAliveOptionsTitle => '保活選項';

  @override
  String get liveKeepAliveOptionsSubtitle => '用於提升超級島和提醒在後台場景下的穩定性';

  @override
  String get hideFromRecentsTitle => '從最近任務中隱藏應用';

  @override
  String get hideFromRecentsSubtitle => '開啟後應用會盡量不顯示在最近任務列表中';

  @override
  String get keepAliveServiceTitle => '輕嶼課表後台保活服務';

  @override
  String get keepAliveServiceEnabledSubtitle => '目前已開啟，系統會保持後台保活輔助服務處於可用狀態';

  @override
  String get keepAliveServiceDisabledSubtitle =>
      '目前未開啟，可進入系統無漲礙設定手動打開輕嶼課表後台保活服務';

  @override
  String get goEnableAction => '去開啟';

  @override
  String get keepAliveConfirmTitle => '開啟後台保活服務';

  @override
  String get keepAliveConfirmBody =>
      '該服務僅用於在後台刷新桌面小組件與重排課程提醒，不會讀取屏幕內容，也不會代替你執行任何點擊操作。開啟需要在系統設定中授予「無障礙」權限，可隨時關閉。';

  @override
  String get keepAliveConfirmGoAction => '去開啟';

  @override
  String get layoutEntryTitle => '布局與節次';

  @override
  String get layoutEntrySubtitle => '節次時間、行高、時間列、周末顯示與卡片布局';

  @override
  String get remindersSectionTitle => '提醒與通知';

  @override
  String get liveGuideEntryTitle => '使用引導與權限';

  @override
  String get liveGuideEntrySubtitle => '簡稱建議、通知、自啟動、電池策略';

  @override
  String get managementSectionTitle => '課表管理';

  @override
  String timeSchemeEntryCurrentPrefix(String name) {
    return '目前：$name · 切換、編輯節次和複製';
  }

  @override
  String get timeSchemeEntrySubtitle => '切換、編輯節次、複製和管理時間範本';

  @override
  String semesterOverviewCurrentWeek(int current, int total) {
    return '目前第 $current 周 / 共 $total 周';
  }

  @override
  String get semesterStartUnset => '未設定開學日期';

  @override
  String semesterStartSet(String date) {
    return '開學日期：$date';
  }

  @override
  String get setSemesterStartDate => '設定開學日期';

  @override
  String get semesterStartDateLabel => '開學日期';

  @override
  String syncedCurrentWeekMessage(int week) {
    return '已同步到第 $week 周';
  }

  @override
  String get pickSemesterWeekCountTitle => '選擇學期周數';

  @override
  String get pickSemesterWeekCountSubtitle => '不同學校可按實際教學周數調整';

  @override
  String weekCountItem(int count) {
    return '$count 周';
  }

  @override
  String get diagnosticsLogIntro => '支持 Markdown 與原文兩種查看方式，排查時可以直接在手機上看完整日誌';

  @override
  String get diagnosticsRawTab => '原文';

  @override
  String get diagnosticsStructuredTab => '結構化';

  @override
  String get diagnosticsLevelLabel => '等級';

  @override
  String get diagnosticsLevelAll => '全部';

  @override
  String get diagnosticsLevelError => '錯誤';

  @override
  String get diagnosticsLevelWarn => '警告';

  @override
  String get diagnosticsLevelInfo => '資訊';

  @override
  String get diagnosticsLevelDebug => '除錯';

  @override
  String get diagnosticsLevelVerbose => '詳細';

  @override
  String diagnosticsShowingCount(int shown, int total) {
    return '顯示 $shown / $total 條日誌';
  }

  @override
  String get diagnosticsNoMatchingTitle => '目前篩選下沒有日誌';

  @override
  String get diagnosticsNoMatchingSubtitle => '可切換回「全部」，或改看原文繼續排查';

  @override
  String diagnosticsLoadEarlierLabel(int count) {
    return '載入更早日誌（還有 $count 條）';
  }

  @override
  String get diagnosticsLevelInferred => '推斷等級';

  @override
  String get diagnosticsRawFilteredHint => '原文視圖會跟隨目前等級篩選，只顯示對應日誌區塊';

  @override
  String get diagnosticsTimeSortAscending => '正序';

  @override
  String get diagnosticsTimeSortDescending => '倒序';

  @override
  String get diagnosticsDisplayOptionsTitle => '檢視與排序';

  @override
  String get diagnosticsStreamingHint => '即時更新中，新日誌會自動追加顯示';

  @override
  String get diagnosticsEmptyTitle => '暫無日誌';

  @override
  String get diagnosticsEmptySubtitle => '目前沒有有可顯示的超級島診斷日誌';

  @override
  String get diagnosticsLogTitleFallback => '超級島診斷日誌';

  @override
  String get diagnosticsDeviceInfoTitle => '設備與匯出資訊';

  @override
  String get diagnosticsContentTitle => '日誌內容';

  @override
  String get diagnosticsRecentLogsTitle => '最近日誌';

  @override
  String get diagnosticsUnknownCategory => '未分類事件';

  @override
  String get diagnosticsExportedAt => '匯出時間';

  @override
  String get diagnosticsTime => '時間';

  @override
  String get diagnosticsCategory => '類別';

  @override
  String get diagnosticsMessage => '消息';

  @override
  String get diagnosticsStackTrace => '堆棧';

  @override
  String get firstUseGuideTitle => '首次使用引導';

  @override
  String get guideAndPermissionsTitle => '使用引導與權限';

  @override
  String get refreshStatusTooltip => '刷新狀態';

  @override
  String get guideHeroTitle => '先把這頁做完，再開始用';

  @override
  String get guideHeroSubtitle => '首屏先授權，下面還會明確說明系統版本支持、簡稱設定和匯入方式，記得繼續下滑';

  @override
  String get guideChipPermissions => '權限準備';

  @override
  String get guideChipShortName => '簡稱設定';

  @override
  String get guideChipImport => '匯入課表';

  @override
  String guideChipReadyCount(int count) {
    return '$count/3 已完成';
  }

  @override
  String get guideBottomReachedHint => '你已經滑到最後了，確認無誤後就可以開始使用';

  @override
  String get guideScrollHint => '向下滑動繼續，下面還有 HyperOS 版本說明、權限清單、簡稱設定和匯入方式';

  @override
  String get guideRequestNotificationFirst => '先申請通知權限';

  @override
  String get quickSetupTitle => '首屏快速設定';

  @override
  String get quickSetupSubtitle => '先把最關鍵的 5 個入口放在前面，不用翻到下面再找';

  @override
  String get quickActionNotificationsTitle => '通知設定';

  @override
  String get quickActionNotificationsSubtitle => '先確保能發通知';

  @override
  String get quickActionIslandTitle => '超級島權限';

  @override
  String get quickActionIslandSubtitle => '檢查 promoted 通知';

  @override
  String get quickActionAutoStartTitle => '自啟動';

  @override
  String get quickActionAutoStartSubtitle => '避免後台被殺';

  @override
  String get quickActionBatteryTitle => '電池無限製';

  @override
  String get quickActionBatterySubtitle => '避免提醒中斷';

  @override
  String get quickActionKeepAliveTitle => '後台保活輔助';

  @override
  String get quickActionKeepAliveSubtitle => '提升後台穩定性';

  @override
  String get guidePrivacyConsentLabel => '我已閱讀並同意友盟相關隱私說明';

  @override
  String get guideRequireConsentHint => '請先滑到底部閱讀說明，並勾選同意後開始使用';

  @override
  String get guideContinueHint => '繼續下滑查看完整引導內容';

  @override
  String get exitAppAction => '退出應用';

  @override
  String get continueReadingAction => '繼續查看';

  @override
  String get agreeAndStartAction => '同意並開始使用';

  @override
  String get startUsingAction => '開始使用';

  @override
  String get editSingleLessonTitle => '編輯單節課';

  @override
  String get editCourseTitle => '編輯課程';

  @override
  String get addSingleLessonTitle => '添加單節課';

  @override
  String get addCourseTitle => '添加課程';

  @override
  String get deleteCourseTitle => '刪除課程';

  @override
  String get courseDeleted => '課程已刪除';

  @override
  String get addMethodTitle => '添加方式';

  @override
  String get singleLessonLabel => '單節課';

  @override
  String get recurringLessonLabel => '多節課';

  @override
  String get singleLessonHint => '適合補課、臨時加課，課程只會落在一個周次';

  @override
  String get recurringLessonHint => '適合同一時間連續上很多周的常規課程';

  @override
  String get sharedInfoTitle => '共享資訊';

  @override
  String get sharedInfoHint => '查看共享欄位說明';

  @override
  String get sharedInfoSheetItemCourseName =>
      '課程名稱：課程唯一標識，名稱相同的多條排課視為同一課程；更改名稱將形成獨立課程記錄';

  @override
  String get sharedInfoSheetItemShortName =>
      '課程簡稱：用於超級島等場景的簡短展示，需手動填寫，系統不會自動生成，啟用「優先顯示課程簡稱」後生效；建議控制在 3 個漢字以內';

  @override
  String get sharedInfoSheetItemSharedSync =>
      '共享同步：課程簡稱、顏色、性質、簡介等欄位將同步至同名課程的其他排課記錄';

  @override
  String get reuseExistingCourseLabel => '沿用已有課程';

  @override
  String get reuseExistingCourseHelper => '選一個已有課程，自動帶入課程名、老師和其他共享資訊';

  @override
  String get manualInputLabel => '手動填寫';

  @override
  String get noTemplateCoursesHint => '目前課表裡還沒有有現成課程，先手動錄入一門，後面臨時加課就能直接選了';

  @override
  String get courseNameLabel => '課程名稱';

  @override
  String get courseNameHelper => '作為課程唯一標識；名稱相同的多條排課將歸為同一課程，請填寫完整名稱，請勿為介面顯示而縮寫';

  @override
  String get pleaseEnterCourseName => '請輸入課程名稱';

  @override
  String get courseShortNameOptional => '課程簡稱';

  @override
  String get courseShortNameHelper =>
      '建議填寫，用於超級島等場景的簡短展示，簡稱不會自動生成；啟用「優先顯示課程簡稱」後生效，建議控制在 3 個漢字以內';

  @override
  String get courseShortNameAutoFillAction => '取前兩字';

  @override
  String get teacherLabel => '授課教師';

  @override
  String get courseNatureLabel => '課程性質';

  @override
  String get courseDescriptionOptional => '課程簡介 (可選)';

  @override
  String get currentScheduleHint => '這裡的星期、節次、教室、周次和單雙周只蠅響目前這一條排課';

  @override
  String followProfileTimeScheme(String name) {
    return '跟隨目前課表（$name）';
  }

  @override
  String get timeSchemeOverrideLabel => '上課時間方案';

  @override
  String get lessonWeeksTitle => '上課周次';

  @override
  String get singleLessonWeekHint => '單節課只會出現在一個周次裡，適合補課、臨時加課';

  @override
  String get rangeWeekLabel => '連續周';

  @override
  String get customWeekLabel => '自定義周';

  @override
  String get allWeeksLabel => '全部';

  @override
  String get oddWeeksLabel => '單周';

  @override
  String get evenWeeksLabel => '雙周';

  @override
  String get allWeeksHint => '按開始周到結束周連續排課';

  @override
  String get oddWeeksHint => '只保留範圍內的單周';

  @override
  String get evenWeeksHint => '只保留範圍內的雙周';

  @override
  String get customPaletteColor => '調色盤自定義顏色';

  @override
  String timeSchemeSetCountValue(int count) {
    return '$count 套';
  }

  @override
  String profileCountValue(int count) {
    return '$count 個';
  }

  @override
  String courseSectionCountValue(int count) {
    return '$count 節';
  }

  @override
  String timeSchemeStartsAt(String start) {
    return '$start 起';
  }

  @override
  String get weekdayShortMonday => '一';

  @override
  String get weekdayShortTuesday => '二';

  @override
  String get weekdayShortWednesday => '三';

  @override
  String get weekdayShortThursday => '四';

  @override
  String get weekdayShortFriday => '五';

  @override
  String get weekdayShortSaturday => '六';

  @override
  String get weekdayShortSunday => '日';

  @override
  String weekdaySectionRange(String weekday, int startSection, int endSection) {
    return '週$weekday $startSection-$endSection節';
  }

  @override
  String timeSchemeUsageReference(
    String profileName,
    String courseName,
    String weekday,
    int startSection,
    int endSection,
    String usageType,
  ) {
    return '$profileName · $courseName（週$weekday $startSection-$endSection節，$usageType）';
  }

  @override
  String weekdaySectionSummary(
    String weekday,
    int startSection,
    int endSection,
  ) {
    return '周$weekday $startSection-$endSection節';
  }

  @override
  String get timeRangeValidationNoCrossDay => '結束時間必須晚於開始時間';

  @override
  String get timeSchemeNameEmptyValidation => '時間模板名稱不能為空';

  @override
  String get liveTimeCorrectionNone => '不校正';

  @override
  String liveTimeCorrectionDelay(int seconds) {
    return '整體延後 $seconds 秒';
  }

  @override
  String liveTimeCorrectionAdvance(int seconds) {
    return '整體提前 $seconds 秒';
  }

  @override
  String liveClassReminderLeadSummaryImmediate(int seconds) {
    return '從上課開始就進入重點提醒顯示，並在距離下課 $seconds 秒切到秒級倒數';
  }

  @override
  String liveClassReminderLeadSummaryKeepNormal(int minutes, int seconds) {
    return '上課後先保留普通課中通知，在距離下課前 $minutes 分鐘切到重點提醒 / 下課提醒，並在最後 $seconds 秒切到秒級倒數';
  }

  @override
  String liveClassReminderLeadSummaryIsland(int minutes, int seconds) {
    return '在距離下課前 $minutes 分鐘切到超級島與重點提醒，並在最後 $seconds 秒切到秒級倒數';
  }

  @override
  String liveClassReminderLeadSummaryFocused(int minutes, int seconds) {
    return '在距離下課前 $minutes 分鐘開始顯示重點提醒，並在最後 $seconds 秒切到秒級倒數';
  }

  @override
  String get liveSettingsEntrySubtitle => '提醒時段、島顯示、通知欄和顯示內容';

  @override
  String get timetableProfilesEntrySubtitle => '新建、切換、複製、重新命名和刪除課表';

  @override
  String get homeTitleSectionTitle => '首頁標題';

  @override
  String get homeTitleSectionSubtitle => '控制首頁左上角課表切換入口的樣式';

  @override
  String get homeTitleStyleLabel => '標題樣式';

  @override
  String get themeSeedSectionTitle => '應用主題色';

  @override
  String get themeSeedSectionSubtitle => '蠅響頂部欄、強調色和全局主色調';

  @override
  String get frostedSheetSectionTitle => '磨砂玻璃';

  @override
  String get frostedSheetSectionSubtitle =>
      '調整首頁彈出面板的高斯模糊強度與磨砂亮度，滑桿越靠右，白色磨砂層越明顯';

  @override
  String get frostedBlurEnabledTitle => '啟用模糊';

  @override
  String get frostedBlurEnabledSubtitle =>
      '關閉後，彈窗、首頁模糊區域與「回到本週」按鈕僅保留半透明底色，不再取樣模糊';

  @override
  String get frostedSheetPreviewOpenAction => '開啟預覽面板';

  @override
  String get frostedSheetPreviewDemoTitle => '預覽';

  @override
  String get frostedSheetPreviewDemoSubtitle => '磨砂玻璃效果即時預覽';

  @override
  String get frostedSheetBlurLabel => '模糊強度';

  @override
  String get frostedSheetTintLabel => '磨砂亮度';

  @override
  String get timetableBackgroundColorSectionTitle => '課表背景色';

  @override
  String get timetableBackgroundColorSectionSubtitle => '只作用於課表頁面的大背景';

  @override
  String get homePageBackgroundFillLabel => '背景填充';

  @override
  String get homePageBackgroundFillColor => '純色';

  @override
  String get homePageBackgroundFillImage => '圖片';

  @override
  String get homePageBackgroundImageTitle => '背景圖';

  @override
  String get homePageBackgroundImageSubtitle => '在「圖片」模式下，套用於下方勾選的顯示區域';

  @override
  String get homePageWallpaperTitle => '背景圖片';

  @override
  String get homePageWallpaperSubtitle => '全螢幕鋪底一張圖；勾選下方區域決定透出範圍，未勾選區域仍顯示課表背景色';

  @override
  String get homePageBackdropFollowsWeekPagerTitle => '背景隨週次滑動';

  @override
  String get homePageBackdropFollowsWeekPagerSubtitle => '左右切換週次時，背景圖與課表頁面一起移動';

  @override
  String get homePageBackgroundScopeTitle => '背景顯示區域';

  @override
  String get homePageBackgroundScopeSubtitle =>
      '從上到下依序控制各區域是否透出背景圖；未勾選區域仍顯示課表背景色';

  @override
  String get homePageBackgroundScopeStatusBar => '狀態列';

  @override
  String get homePageBackgroundScopeTimetable => '課表區域';

  @override
  String get homePageBackgroundScopeWeekdayBar => '資訊欄';

  @override
  String get homePageBackgroundScopeHeader => '頂欄';

  @override
  String get homePageHeaderBlurTitle => '頂欄高斯模糊';

  @override
  String get homePageHeaderBlurSubtitle => '模糊標題欄（輕嶼課表）區域；勾選「狀態列」時一併模糊狀態列';

  @override
  String get homePageWeekdayBarBlurTitle => '資訊欄高斯模糊';

  @override
  String get homePageWeekdayBarBlurSubtitle => '模糊週次與星期資訊欄，透出下方背景圖';

  @override
  String get homePageTimeColumnBlurTitle => '時間欄高斯模糊';

  @override
  String get homePageTimeColumnBlurSubtitle => '模糊左側節次/時間列，透出下方背景圖';

  @override
  String get homePageRegionBlurSectionSubtitle => '需搭配背景圖使用；模糊強度跟隨「彈窗磨砂玻璃」設定';

  @override
  String get homePagePickImageAction => '選擇圖片';

  @override
  String get homePageSwitchImageAction => '切換照片';

  @override
  String get homePageClearImageAction => '清除圖片';

  @override
  String get homePageImageNotSelected => '未選擇';

  @override
  String get wallpaperPositionPickerTitle => '調整桌布顯示位置';

  @override
  String get wallpaperPositionPickerResetTooltip => '重設置中';

  @override
  String get wallpaperPositionPickerDragHint => '拖曳桌布調整位置';

  @override
  String get wallpaperPositionPickerSwitchWallpaper => '更換桌布';

  @override
  String get wallpaperPositionPickerDone => '完成';

  @override
  String get wallpaperPositionPickerExit => '退出';

  @override
  String get appearanceTextColorsSectionTitle => '文字顏色';

  @override
  String get appearanceTextColorsSectionSubtitle => '自訂課程卡片、星期欄與時間軸文字顏色';

  @override
  String get defaultTimetablePreviewName => '預設課表';

  @override
  String get beforeClassDisplaySettingsTitle => '上課前提醒顯示';

  @override
  String get duringEndDisplaySettingsTitle => '課中／下課提醒顯示';

  @override
  String get liveDisplaySummaryShortName => '簡稱';

  @override
  String get liveDisplaySummaryCourseName => '課程名';

  @override
  String get liveDisplaySummaryLocation => '地點';

  @override
  String liveDisplaySummaryCountdown(String style) {
    return '倒數（$style）';
  }

  @override
  String get liveDisplaySummaryStageText => '階段文字';

  @override
  String get liveDisplaySummaryLeftLabelImage => '圖示';

  @override
  String get liveDisplaySummaryMinimal => '最簡顯示';

  @override
  String get liveDisplaySummaryCountdownShort => '倒數';

  @override
  String liveDisplaySummaryMore(String first, int count) {
    return '$first等$count項';
  }

  @override
  String get guideHyperOsChip => 'HyperOS 3.0.300+';

  @override
  String get guideStatusTitle => '目前狀態';

  @override
  String get guideStatusNotificationPermission => '通知權限';

  @override
  String get guideStatusEnabled => '已開啟';

  @override
  String get guideStatusDisabled => '未開啟';

  @override
  String get guideStatusIslandSupport => '焦點通知 / 超級島';

  @override
  String get guideStatusSystemAllowed => '系統已允許';

  @override
  String get guideStatusEnabledPending => '已開啟但系統暫未確認';

  @override
  String get guideStatusSuggestedCheck => '建議檢查';

  @override
  String get guideStatusBatteryOptimization => '電池優化';

  @override
  String get guideStatusBatteryUnrestricted => '無限制';

  @override
  String get guideStatusBatteryRestricted => '仍受限制';

  @override
  String get guideStatusKeepAlive => '後台保活輔助';

  @override
  String get guideStatusAndroidVersion => 'Android 版本';

  @override
  String get guideStatusVersionUnknown => '未識別';

  @override
  String get guideStatusIslandSystemSupport => '超級島系統支持';

  @override
  String get guideStatusIslandSystemRequirement => '需 HyperOS 3.0.300 及以上';

  @override
  String get guideStatusIslandHint =>
      '如果你主要想用超級島，先確認系統版本至少是 HyperOS 3.0.300，再繼續把下面權限清單按順序點完';

  @override
  String get guidePermissionChecklistTitle => '權限清單';

  @override
  String get guidePermissionChecklistSubtitle => '按這個順序檢查，最省事，也最不容易漏';

  @override
  String get guideChecklistRequestNotificationTitle => '申請通知權限';

  @override
  String get guideChecklistRequestNotificationSubtitle => '這是所有提醒的前提';

  @override
  String get guideChecklistOpenNotificationTitle => '打開通知設定';

  @override
  String get guideChecklistOpenNotificationSubtitle => '檢查通知總開關、锁屏展示和實時通知權限';

  @override
  String get guideChecklistOpenIslandTitle => '打開焦點通知設定';

  @override
  String get guideChecklistOpenIslandSubtitle =>
      'HyperOS 3.0.300 及以上再檢查 promoted / 超級島通知';

  @override
  String get guideChecklistOpenAutoStartTitle => '打開自啟動設定';

  @override
  String get guideChecklistOpenAutoStartSubtitle => '允許應用開機自啟和後台常驻';

  @override
  String get guideChecklistOpenBatteryTitle => '打開電池策略設定';

  @override
  String get guideChecklistOpenBatterySubtitle => '建議改成無限制，避免上課提醒被中斷';

  @override
  String get guideChecklistOpenKeepAliveTitle => '打開後台保活輔助';

  @override
  String get guideChecklistOpenKeepAliveSubtitle => '進一步提升超級島和提醒在後台場景下的穩定性';

  @override
  String get guideShortNameAdviceTitle => '課程簡稱建議';

  @override
  String get guideShortNameAdviceSubtitle =>
      '超級島支持顯示課程簡稱，簡稱不是自動生成的，需要你在課程編輯裡自己填寫，建議控制在 3 個字以內，顯示會更穩定';

  @override
  String get guideShortNameRecommended => '推薦示例';

  @override
  String get guideShortNameNotRecommended => '不推薦';

  @override
  String get guideShortNameRecommendedExample => '高數 / 概率 / 數控';

  @override
  String get guideShortNameNotRecommendedExample => '高等數學A(1) / 數控技術及應用';

  @override
  String get guideSetCourseShortNameAction => '去設定課程簡稱';

  @override
  String get guideImportMethodsTitle => '課表導入方式';

  @override
  String get guideImportMethodsSubtitle =>
      '目前版本已經支持部分學校的教務系統網頁登入導入；如果你的學校還没適配，也還有其他遷移方式';

  @override
  String get guideImportMethodStep1 =>
      '優先進入“導入課程 > 教務系統導入”，選擇學校和適配器後，直接在應用內打開教務網頁完成導入。';

  @override
  String get guideImportMethodStep2 =>
      '如果你的學校暫時没有適配，可以先在 WakeUp 等課表應用裡導入教務系統課程，再導出日歷格式，最後回到本應用導入。';

  @override
  String get guideImportMethodStep3 =>
      '如果別人已經在用本應用，也可以讓對方導出完整備份文件，你直接導入就能恢複課程和設定。';

  @override
  String get guideImportMethodExtra =>
      '如果你會抓包、網頁偵錯或 JavaScript，也歡迎參與學校教務適配補充，讓更多學校能直接導入。';

  @override
  String get guideFinalTipsTitle => '最後再看這 3 條';

  @override
  String get guideFinalTip1 =>
      '1. HyperOS 3.0.300 及以上才支持超級島；如果系統版本不夠，應用仍可正常發普通提醒。';

  @override
  String get guideFinalTip2 => '2. 先在設定頁調整「上課前彈出」和「課中與臨近下課提醒」的閾值。';

  @override
  String get guideFinalTip3 => '3. 完成系統權限設定後，再用測試通知驗證；如果島區還是偶尔消失，優先檢查自啟動和省電策略。';

  @override
  String get guidePrivacyHelperRequireConsent =>
      '你勾選同意後，代表你已阅讀並同意上述友盟相關說明、隱私內容與免責提示';

  @override
  String get guidePrivacyHelperViewOnly =>
      '這裡保留與首次啟動一致的隱私、第三方 SDK 與免責說明，方便你隨時查看；目前頁面不需要再次勾選同意';

  @override
  String get guidePrivacySectionTitle => '隱私、第三方 SDK 與免責說明';

  @override
  String get guidePrivacyParagraph1 =>
      '本應用主體功能按本地運行方式設計，課表、時間模板、課程記錄和大部分設定預設保存在你的裝置本地。';

  @override
  String get guidePrivacyParagraph2 =>
      '只有在你主動使用檢查更新、下載更新、導入導出等聯網功能，或你勾選同意後初始化友盟相關 SDK 時，應用才會與外部服務發生資料交互。';

  @override
  String get guidePrivacyParagraph3 =>
      '本應用接入友盟移動統計 SDK、友盟應用性能監控 SDK 以及高級運櫻分析依赖庫。它們的服務用途包括移動統計分析、應用性能監控以及高級運櫻分析相關能力；只有在你勾選同意後，這些 SDK 才會正式初始化。';

  @override
  String get guidePrivacyParagraph4 =>
      '按友盟官方說明，這些 SDK 可能處理的資訊包括：裝置資訊（如 IMEI、MAC、Android ID、OAID、IDFA、OpenUDID、GUID、SIM 卡 IMSI 等）、網路狀態、裝置標識，以及高級運櫻分析依赖庫涉及的應用列表和地理位置相關資訊。';

  @override
  String get guideRiskTitle => '免責與風险提示';

  @override
  String get guideRiskParagraph1 =>
      '1. 超級島、焦點通知、後台提醒和保活效果依赖系統版本、機型、廠商策略、權限、自啟動、電池策略等外部條件，無法保證所有裝置表現完全一致。';

  @override
  String get guideRiskParagraph2 =>
      '2. 檢查更新、鏡像下載、系統下載器、導入導出與分享等能力依赖網路環境、第三方服務和系統文件能力；若出現失敗、限速或文件異常，請以 Release 頁面、你自己保存的備份文件和系統提示為準。';

  @override
  String get guideRiskParagraph3 =>
      '3. 在遷移、導入或覆蓋資料前，請先自行確認備份文件完整可用，並妥善保管含有課表資訊的文件；因用戶自行刪除、覆蓋、分享或保管不當造成的資料問題，需要由用戶自行承擔相應風险。';

  @override
  String get guideUmengPrivacyLink =>
      '友盟隱私政策：https://www.umeng.com/page/policy';

  @override
  String get liveDiagnosticsUnavailable => '目前還没有可查看的超級島診斷日誌';

  @override
  String get liveDiagnosticsViewerTitle => '超級島診斷日誌';

  @override
  String get liveDiagnosticsShareText => '這是輕嶼課表導出的超級島診斷日誌，可用于排查“超級島没有彈出”等問題';

  @override
  String get liveDiagnosticsShareSubject => '輕嶼課表 - 超級島診斷日誌';

  @override
  String get liveDiagnosticsSnapshotShareText =>
      '這是輕嶼課表目前測試診斷頁導出的超級島狀態快照，可用于排查“超級島没有彈出”等問題';

  @override
  String get liveDiagnosticsSnapshotShareSubject => '輕嶼課表 - 超級島狀態快照';

  @override
  String get liveDiagnosticsNothingToExport => '目前没有可導出的日誌文件，也没有可導出的狀態快照';

  @override
  String get liveDiagnosticsCleared => '已清空超級島診斷日誌，後續會重新開始收集';

  @override
  String get liveDiagnosticsClearFailed => '清空超級島診斷日誌失敗';

  @override
  String get liveTestingNotRefreshed => '尚未刷新';

  @override
  String get liveTestingTitle => '測試與診斷';

  @override
  String get liveTestingNotificationTitle => '測試通知';

  @override
  String get liveTestingNotificationSubtitle => '用于驗證超級島、通知欄和課程簡稱等顯示效果';

  @override
  String get liveTestingStartAction => '開始測試';

  @override
  String get liveTestingCancelAction => '取消測試';

  @override
  String get liveTestingSessionRunning => '自檢測試進行中';

  @override
  String get liveTestingSessionCanceled => '已取消自檢測試';

  @override
  String get liveTestingUmengHint => '下面兩個按鈕僅測試版顯示，用于驗證友盟 U-APM 崩溃和卡頓上報';

  @override
  String get liveTestingCrashAction => '崩溃測試';

  @override
  String get liveTestingAnrAction => '異常卡頓測試';

  @override
  String get liveTestingIslandStatusTitle => '上島狀態診斷';

  @override
  String get liveTestingIslandStatusSubtitle => '這裡直接顯示原生實時服務、通知構造結果和不上島原因';

  @override
  String get liveTestingServiceStatusRunning => '服務運行中';

  @override
  String get liveTestingServiceStatusStopped => '服務未運行';

  @override
  String get liveTestingNoIslandReasonTitle => '不上島原因';

  @override
  String get liveTestingNoIslandReasonEmpty => '目前無攔截原因';

  @override
  String get liveTestingRefreshAction => '刷新診斷';

  @override
  String get liveTestingRefreshing => '刷新中';

  @override
  String get liveTestingExportAction => '導出並分享日誌';

  @override
  String get liveTestingExporting => '導出中';

  @override
  String get liveTestingAutoRefreshTitle => '自動刷新';

  @override
  String liveTestingAutoRefreshOn(int seconds) {
    return '每 $seconds 秒自動拉取一次診斷狀態';
  }

  @override
  String get liveTestingAutoRefreshOff => '關閉後只在手動刷新時更新，便于穩定查看目前狀態';

  @override
  String liveTestingRefreshedAt(String time) {
    return '上次刷新：$time';
  }

  @override
  String get liveTestingSectionEnvironment => '環境與權限';

  @override
  String get liveTestingSectionService => '服務狀態';

  @override
  String get liveTestingSectionCourse => '課程資料';

  @override
  String get liveTestingSectionTiming => '時間與階段';

  @override
  String get liveTestingSectionSwitches => '階段開關';

  @override
  String get liveTestingSectionDisplay => '島顯示配置';

  @override
  String get liveTestingSectionNotification => '通知判定結果';

  @override
  String get liveTestingSectionRecentLogs => '最近診斷日誌';

  @override
  String get liveTestingRawDataTitle => '原始偵錯資料';

  @override
  String get liveTestingRawDataSubtitle => '預設折疊，排查時再展開核對完整原生字段';

  @override
  String get liveTestingExpandRawJson => '展開原始 JSON';

  @override
  String get liveTestingExpandRawJsonSubtitle => '避免大段原始字段一直佔滿頁面';

  @override
  String get liveTestingLocalLogsTitle => '本地診斷日誌';

  @override
  String get liveTestingLocalLogsSubtitle =>
      '一鍵導出日誌文件，直接通過系統分享發給開發者；也可以清空後重新收集';

  @override
  String get liveTestingClearLogsAction => '清空日誌';

  @override
  String get liveTestingClearingLogs => '清空中';

  @override
  String get liveTestingViewPhoneLogsAction => '查看手機日誌';

  @override
  String get liveTestingMoreTesterOptionsAction => '更多測試者選項';

  @override
  String get yesLabel => '是';

  @override
  String get noLabel => '否';

  @override
  String get liveTestingCurrentNativeFieldsSubtitle => '顯示目前原生診斷字段';

  @override
  String get liveTestingCrashSoon => '即將觸發友盟 U-APM 測試崩溃，請重新打開應用查看後台是否收到上報';

  @override
  String get liveTestingAnrSoon =>
      '即將觸發約 30 秒主線程卡死，請脫離 flutter run 測試，並在卡死後重新打開應用查看友盟後台';

  @override
  String get liveTestingNoCourseAvailable => '目前没有可測試的課程';

  @override
  String get liveTestingPresetArmedButHidden =>
      '已注入自檢預設課程，但超級島此刻不會彈出——若「上課前提醒」已關閉，島會在課程真正開始後（約 1 分鐘後）才出現';

  @override
  String get liveTestingHolidayBlocked =>
      '目前在假期範圍內，超級島在假期期間不會顯示；如需測試，請先在「課表設定 → 假日標記」中移除涵蓋今天的假期';

  @override
  String get liveTestingNotIslandHoliday =>
      '目前在假期範圍內——超級島在假期期間不會顯示，可在「課表設定 → 假日標記」中管理假期';

  @override
  String get liveTestingCourseTestAction => '選課測試';

  @override
  String get liveTestingCourseTestPickerTitle => '選擇要測試的課程';

  @override
  String get liveTestingCourseTestStageTitle => '選擇要預覽的階段';

  @override
  String get liveTestingCourseTestStageBeforeClass => '課前倒數（島保持約 3 分鐘）';

  @override
  String get liveTestingCourseTestStageDuringClass => '上課中（島保持約 4 分鐘）';

  @override
  String liveTestingCourseTestActiveChip(String course) {
    return '選課測試中 · $course';
  }

  @override
  String get liveTestingCourseTestStopAction => '停止測試';

  @override
  String liveTestingCourseTestStartedToast(String course, String stage) {
    return '已強制啟動「$course」的超級島測試（$stage）。請按 Home 鍵回桌面查看；島會在測試視窗結束後自動收島並恢復正式調度';
  }

  @override
  String get liveTestingCourseTestStoppedToast => '已停止選課測試，正式調度已恢復';

  @override
  String get liveTestingInFlight => '測試進行中，請勿重複點擊，請稍後再試';

  @override
  String get liveTestingProductionHomeHint =>
      '已走正式超級島選課路徑。請按 Home 鍵回到桌面查看（停留在應用內時系統通常不會彈出）';

  @override
  String get liveTestingPresetFallbackNote => '（未檢測到可測試的真實課程，已改用自檢預設課程，不會寫入課表）';

  @override
  String get liveTestingTestCourseNote => '此處顯示備注，可以在課程編輯頁進行設定';

  @override
  String get liveTestingNotificationSent => '已發送上課提醒測試通知，約 8 秒內會進入上課前提醒階段';

  @override
  String sendFailedWithError(String error) {
    return '發送失敗: $error';
  }

  @override
  String get homeWidgetSettingsTitle => '桌面小組件';

  @override
  String get homeWidgetTodayCourseTitle => '今日課程組件';

  @override
  String get homeWidgetTodayCourseSubtitle =>
      '首批支持 2×2、2×4、4×4 三種尺寸，點擊小組件會直接打開首頁，課程開始和結束時會主動刷新';

  @override
  String get homeWidgetQuickAddTitle => '快速添加到桌面';

  @override
  String get homeWidgetCheckingPinSupport => '正在檢查目前桌面是否支持應用內添加小組件…';

  @override
  String get homeWidgetPinSupported => '支持的話會直接彈出系統添加確認，不是單獨的權限彈窗；確認後即可固定到桌面';

  @override
  String get homeWidgetPinUnsupported =>
      '目前桌面不支持應用內直接添加時，仍可長按桌面 → 小組件 → 輕嶼課表 手動添加';

  @override
  String get homeWidgetBackgroundStyleLabel => '背景養式';

  @override
  String get homeWidgetShowLocationTitle => '顯示地點';

  @override
  String get homeWidgetShowLocationSubtitle => '關閉後改顯週次與課程數';

  @override
  String get homeWidgetShowCountdownTitle => '顯示倒計時';

  @override
  String get homeWidgetShowCountdownSubtitle => '顯示下一節課倒計時';

  @override
  String get homeWidgetCountdownLeadTitle => '倒計時提前量';

  @override
  String get homeWidgetCountdownLeadSubtitle => '設置上課前多少分鐘自動切換到倒計時模式';

  @override
  String get homeWidgetCountdownLeadAlways => '始終顯示';

  @override
  String homeWidgetCountdownLeadMinutes(String minutes) {
    return '上課前 $minutes 分鐘';
  }

  @override
  String get widgetCountdownStyleTitle => '倒計時樣式';

  @override
  String get homeWidgetHideCompletedTitle => '隱藏已上完課程';

  @override
  String get homeWidgetHideCompletedSubtitle => '只顯示未結束的課程';

  @override
  String get homeWidgetShowTomorrowTitle => '課後顯示明日課程';

  @override
  String get homeWidgetShowTomorrowSubtitle => '今日課後自動顯示明天課程';

  @override
  String get homeWidgetAppearanceTitle => '卡片外觀';

  @override
  String get homeWidgetHeightAdjustTitle => '卡片高度';

  @override
  String get homeWidgetHeightAdjustHint => '範圍 -16 ~ 16，0 為預設檔：正數比預設更高，負數更矮';

  @override
  String get defaultLabel => '預設';

  @override
  String higherByValue(String value) {
    return '更高 $value';
  }

  @override
  String lowerByValue(String value) {
    return '更矮 $value';
  }

  @override
  String get homeWidgetCornerRadiusTitle => '卡片圓角';

  @override
  String get homeWidgetDescriptionTitle => '說明';

  @override
  String get homeWidgetDescriptionText =>
      '小組件目前優先展示今日課程，無課狀態會保持完整卡片，不會出現空白；如果你切換課表或修改養式，桌面組件也會跟着刷新';

  @override
  String homeWidgetPinRequested(String label) {
    return '已發起“$label”添加請求，請在系統彈窗裡確認並放到桌面';
  }

  @override
  String homeWidgetPinUnsupportedManual(String label) {
    return '目前系統桌面不支持應用內直接添加小組件，請長按桌面 → 小組件 → 輕嶼課表，再手動添加“$label”';
  }

  @override
  String get homeWidgetInvalidType => '小組件類型無效，請稍後重試';

  @override
  String homeWidgetPinFailedManual(String label) {
    return '發起添加失敗，請長按桌面 → 小組件 → 輕嶼課表，再手動添加“$label”';
  }

  @override
  String get homeWidgetBindingSectionTitle => '各卡片綁定管理';

  @override
  String get homeWidgetBindingFollowActive => '跟隨目前課表';

  @override
  String get homeWidgetBindingEmpty => '桌面上還沒有今日課程卡片，先新增一張再返嚟綁定';

  @override
  String get homeWidgetBindingSaveFailed => '儲存卡片綁定失敗，請稍後重試';

  @override
  String get homeWidgetBindingMissingToast => '這張卡片綁定的課表已失效，已按普通方式打開';

  @override
  String get homeWidgetExactAlarmBannerTitle => '精確鬧鐘權限未授予';

  @override
  String get homeWidgetExactAlarmBannerText =>
      '未授予「鬧鐘和提醒」權限時，課程邊界只能非精確刷新，桌面卡片可能延遲更新，建議授權以保證按課程時間精確刷新';

  @override
  String get homeWidgetExactAlarmGrantAction => '去授權';

  @override
  String get homeWidgetExactAlarmOpenFailed => '無法開啟授權頁，請到系統設定中手動開啟「鬧鐘和提醒」權限';

  @override
  String get homeWidgetExactAlarmFallbackHint =>
      '已在系統設定中開啟應用程式資訊，請在其中開啟「鬧鐘和提醒」權限';

  @override
  String get layoutSettingsTitle => '布局與節次';

  @override
  String get layoutDensityTitle => '課表密度';

  @override
  String get layoutAutoFitHeightTitle => '自動充滿屏幕高度';

  @override
  String get layoutAutoFitHeightSubtitle => '開啟後會按目前節數自動鋪滿頁面底部，不再保留下方空隙';

  @override
  String get layoutHideWeekendsTitle => '隱藏周六周日';

  @override
  String get layoutHideWeekendsSubtitle => '開啟後首頁只顯示周一到周五，剩餘列宽會自動鋪滿';

  @override
  String get layoutEnableHapticsTitle => '啟用應用內震動反饋';

  @override
  String get layoutEnableHapticsSubtitle => '關閉後，頁碼切換等交互不再觸發輕微震動';

  @override
  String pageTransitionSpeedLabel(String speed) {
    return '頁面轉場速度 $speed×';
  }

  @override
  String get pageTransitionSpeedTitle => '頁面轉場速度';

  @override
  String get pageTransitionSpeedSubtitle =>
      '調節進入和返回子頁面時的滑動動畫快慢，數值越大越快，越小越慢；會疊加系統「過渡動畫縮放」設定';

  @override
  String pageTransitionSpeedDurationHint(int milliseconds) {
    return '約 $milliseconds 毫秒';
  }

  @override
  String get layoutTimeColumnDisplayLabel => '首頁時間列顯示';

  @override
  String get layoutTimeColumnWidthLabel => '時間欄宽度';

  @override
  String get layoutBackToCurrentWeekButtonStyleLabel => '「返回本週」按鈕樣式';

  @override
  String get layoutBackToCurrentWeekButtonStyleHelper =>
      '預設維持現在的內嵌樣式；也可以改成周視圖右下角的小型懸浮按鈕';

  @override
  String get layoutBackToCurrentWeekButtonStyleInline => '時間欄內嵌';

  @override
  String get layoutBackToCurrentWeekButtonStyleFloating => '右下角懸浮';

  @override
  String layoutBackToCurrentWeekButtonOpacityLabel(int value) {
    return '懸浮按鈕不透明度 $value%';
  }

  @override
  String get layoutBackToCurrentWeekButtonOpacityTitle => '懸浮按鈕不透明度';

  @override
  String get layoutBackToCurrentWeekButtonOpacitySubtitle => '只對右下角懸浮樣式生效';

  @override
  String layoutCourseCardGapLabel(String value) {
    return '課程卡片間距 $value';
  }

  @override
  String get layoutCourseCardGapTitle => '課程卡片間距';

  @override
  String layoutSectionHeightLabel(String value) {
    return '課表行高 $value';
  }

  @override
  String get layoutSectionHeightTitle => '課表行高';

  @override
  String layoutCompactFontSizeLabel(String value) {
    return '緊湊字級 $value';
  }

  @override
  String get layoutCompactFontSizeTitle => '緊湊字級';

  @override
  String layoutCourseCardFontSizeLabel(String value) {
    return '課程卡片字級 $value';
  }

  @override
  String get layoutCourseCardFontSizeTitle => '課程卡片字級';

  @override
  String get layoutCourseCardDisplayTitle => '課程卡片顯示';

  @override
  String get layoutCourseCardDisplaySubtitle => '預設顯示課程名、老師和教室；其他資訊可按課表自由開關組合';

  @override
  String get layoutShowTeacherTitle => '顯示老師';

  @override
  String get layoutShowClassroomTitle => '顯示教室';

  @override
  String get layoutShowTimeTitle => '顯示時間';

  @override
  String get layoutShowTimeLabelsTitle => '顯示上下課字樣';

  @override
  String get layoutShowTimeLabelsSubtitle => '關閉後僅顯示時間點，不顯示“上課”“下課”文字';

  @override
  String get layoutShowWeeksTitle => '顯示週數';

  @override
  String get layoutShowWeeksSubtitle => '例如第 1-16 周、單雙周';

  @override
  String get layoutShowDescriptionTitle => '顯示課程簡介';

  @override
  String get layoutShowDescriptionSubtitle => '預設關閉，空間不足時會最先被壓縮';

  @override
  String get layoutShowOtherWeeksTitle => '顯示非本周課程';

  @override
  String get layoutShowOtherWeeksSubtitle => '非本週課程以半透明灰色顯示';

  @override
  String get layoutVerticalAlignLabel => '垂直排版';

  @override
  String get layoutHorizontalAlignLabel => '水平排版';

  @override
  String get layoutShowConflictBadgeTitle => '首頁顯示衝突小膠囊';

  @override
  String get layoutShowConflictBadgeSubtitle => '關閉後，首頁課表不再對衝突課程顯示“衝突”小膠囊';

  @override
  String layoutConflictOpacityLabel(int value) {
    return '衝突課程透明度 $value%';
  }

  @override
  String get layoutConflictOpacityTitle => '衝突課程透明度';

  @override
  String get layoutConflictOpacitySubtitle => '衝突課程會自動層疊顯示，調低透明度後能同時看到多節課';

  @override
  String get layoutTipsText =>
      '時間模板已移到設定首頁，這裡主要調課表行高、時間列、周末顯示和課程卡片布局；如果你想只改目前課表的時間，先在時間模板裡複制一套再應用';

  @override
  String currentWeekCompact(int week) {
    return '$week周';
  }

  @override
  String get sampleCourseNumericalControl => '數控';

  @override
  String get sampleCourseAdvancedMath => '高數';

  @override
  String get sampleTeacherZhang => '張老師';

  @override
  String get sampleCourseEnglish => '英語';

  @override
  String get sampleTeacherLi => '李老師';

  @override
  String get aboutRepositorySheetTitle => '開源倉庫';

  @override
  String get aboutRepositorySheetHint =>
      '如果你想補學校教務匯入適配，建議同時查看教務適配倉 qingyu_warehouse';

  @override
  String get aboutOpenGitHubAction => '打開 GitHub';

  @override
  String get aboutOpenWarehouseRepoAction => '打開教務適配倉';

  @override
  String get copiedRepositoryAddress => '已複制倉庫地址';

  @override
  String get copiedWarehouseRepositoryAddress => '已複制教務適配倉地址';

  @override
  String get aboutUpdateScreenTitle => '版本更新';

  @override
  String get aboutUpdateStatusTitle => '更新狀態';

  @override
  String get aboutRefreshCheckTooltip => '重新檢查';

  @override
  String get aboutCheckingLatestVersion => '正在檢查最新版本資訊…';

  @override
  String get aboutCheckingForUpdate => '正在檢測更新…';

  @override
  String get aboutReadVersionFailed => '暫時無法讀取版本資訊，請稍後重試';

  @override
  String get aboutReadVersionFailedHint =>
      '如果你目前網路訪問 GitHub 不穩定，可稍後再試，或切到下面的國內下載方式後重試';

  @override
  String get aboutViewReleaseAction => '查看 Release';

  @override
  String get aboutDownloadNowAction => '立即下載';

  @override
  String get aboutOpenDownloadPageAction => '打開下載頁';

  @override
  String get aboutCurrentVersionLabel => '目前版本';

  @override
  String get aboutLatestVersionLabel => '最新版本';

  @override
  String get aboutUnreleasedLabel => '未發布';

  @override
  String get aboutVersionChannelLabel => '版本通道';

  @override
  String get aboutPrereleaseChannel => '測試版';

  @override
  String get aboutUpdateAvailableHint =>
      '你現在只需要點下面的“立即下載”即可，測速、鏡像和測試版都已經收進後面的高級選項裡';

  @override
  String get aboutUpdateNoUpdateHint =>
      '目前版本已經可正常使用；如果你要體驗測試版，可以在後面的高級選項裡打開測試版檢測';

  @override
  String aboutUpdatedAt(String time) {
    return '更新時間：$time';
  }

  @override
  String get aboutUpdateNowTitle => '立即更新';

  @override
  String get aboutUpdateNowAndroidSubtitle =>
      '普通使用只需要點一次立即下載，下載慢、下載失敗、要換線路時，再去下面的高級選項';

  @override
  String get aboutUpdateNowOtherSubtitle => '目前平台會直接打開下載頁面，不會在應用內安裝';

  @override
  String get aboutMirrorDownloadHint => '目前會優先使用國內下載，大多數國內網路直接點“立即下載”就行';

  @override
  String get aboutOriginalDownloadHint => '目前會優先使用國際源下載，如果下載慢或打不開，建議先切回“國內下載”';

  @override
  String get aboutUseSystemDownloaderAction => '使用系統下載器下載';

  @override
  String get aboutOpenReleasePageAction => '打開 Release 頁面';

  @override
  String get aboutDownloadMethodTitle => '下載方式';

  @override
  String get aboutDownloadMethodSubtitle =>
      '預設推薦國內下載，只有你能穩定訪問 GitHub 時，再切到國際源下載';

  @override
  String get aboutDownloadMethodMirror => '國內下載';

  @override
  String get aboutDownloadMethodOriginal => '國際源下載';

  @override
  String aboutMirrorModeHintRecommended(String current, String recommended) {
    return '目前使用國內下載 · $current，系統最近測速更推薦“$recommended”，需要時可在後面的高級選項裡切換';
  }

  @override
  String aboutMirrorModeHintCurrent(String current) {
    return '目前使用國內下載 · $current，如果下載慢或失敗，再到後面的高級選項裡測速、換線路或填寫自定義地址';
  }

  @override
  String get aboutOriginalModeHint =>
      '目前使用國際源下載，只有你網路能穩定訪問 GitHub 時才建議這養設定；否則請切回國內下載';

  @override
  String get aboutReleaseNotesTitle => '本次更新說明';

  @override
  String get aboutReleaseNotesSubtitle => '顯示目前檢測到版本的 Release 說明';

  @override
  String get aboutAdvancedOptionsTitle => '高級選項';

  @override
  String get aboutAdvancedOptionsSubtitle => '只有下載慢、要手動切線路、或要檢測測試版時再展開';

  @override
  String get aboutMirrorSectionTitle => '下載線路與鏡像';

  @override
  String get aboutMirrorSectionMirrorHint =>
      '目前使用國內下載，這裡可以手動切線路、測速推薦，或填寫自定義下載地址';

  @override
  String get aboutMirrorSectionOriginalHint =>
      '你現在使用的是國際源下載，下面的線路設定只有在切回“國內下載”後才會生效';

  @override
  String get aboutFillCustomMirrorFirst => '先填寫自定義下載地址';

  @override
  String get aboutCurrentCustomMirrorTitle => '目前自定義下載地址';

  @override
  String get aboutCurrentMirrorTitle => '目前下載線路地址';

  @override
  String get aboutCurrentCustomMirrorHint => '目前正在使用你手動填寫的下載地址';

  @override
  String get aboutCurrentMirrorHint => '如果目前線路訪問失敗，可以切到其他內置線路，或改用自定義地址';

  @override
  String get aboutProbeMirrorsAction => '測速並推薦';

  @override
  String get aboutProbingMirrors => '測速中…';

  @override
  String get aboutEditCustomMirrorAction => '修改自定義地址';

  @override
  String get aboutSetCustomMirrorAction => '填寫自定義地址';

  @override
  String aboutSwitchToRecommendedAction(String label) {
    return '切到推薦：$label';
  }

  @override
  String get aboutMirrorDisabledHint =>
      '目前没有使用國內下載，所以這裡的線路設定暫時不會生效，需要的話，請先在上面的“下載方式”裡切回國內下載';

  @override
  String get aboutRecentProbeResultsTitle => '最近測速結果';

  @override
  String get aboutUnavailable => '不可用';

  @override
  String get aboutRecommended => '推薦';

  @override
  String get aboutCheckPrereleaseTitle => '檢測測試版本';

  @override
  String get aboutCheckPrereleaseSubtitle => '打開後會把測試版也纳入更新檢查；普通使用建議關閉';

  @override
  String get aboutUpdatePromptTitle => '彈窗提醒';

  @override
  String get aboutUpdatePromptSubtitle => '發現新版本時在首頁自動彈窗，關閉後僅顯示紅點角標';

  @override
  String get aboutDiagnosticsTitle => '測試與診斷';

  @override
  String get aboutDiagnosticsSubtitle => '只有遇到“超級島没彈出”或需要給開發者反饋時再展開';

  @override
  String get aboutRecordDiagnosticsTitle => '記錄應用日誌';

  @override
  String get aboutRecordDiagnosticsSubtitle => '打開後會在本地持續記錄關鍵日誌，僅用于排查“該彈不彈”等問題';

  @override
  String get aboutExportDiagnosticsAction => '匯出診斷日誌';

  @override
  String get aboutViewPhoneLogsAction => '查看手機日誌';

  @override
  String get aboutClearAndRecollectAction => '清空並重新收集';

  @override
  String get aboutLiveDiagnosticsEnabled => '已開啟超級島診斷日誌';

  @override
  String get aboutLiveDiagnosticsDisabled => '已關閉超級島診斷日誌';

  @override
  String get aboutNoDiagnosticsExportYet => '還没有可匯出的超級島診斷日誌';

  @override
  String get aboutProbeNoMirrorFound => '測速完成，但暫時没有發現可用鏡像線路';

  @override
  String aboutProbeCurrentFastest(String label) {
    return '測速完成，目前線路“$label”已是最快可用線路';
  }

  @override
  String aboutProbeRecommendSwitch(String label) {
    return '測速完成，推薦切換到“$label”';
  }

  @override
  String get switchAction => '切換';

  @override
  String aboutSwitchToMirrorAfterError(String error) {
    return '$error，可切到國內鏡像後再試';
  }

  @override
  String aboutSwitchPresetAfterError(String error, String label) {
    return '$error，建議切換到“$label”後重試';
  }

  @override
  String get aboutSetMirrorSourceTitle => '設定鏡像源';

  @override
  String get aboutMirrorPrefixLabel => '鏡像前缀';

  @override
  String get aboutMirrorPrefixInvalid => '鏡像源格式不正確，請輸入完整的 http 或 https 地址';

  @override
  String get aboutMirrorSaved => '鏡像源已保存';

  @override
  String get aboutDownloadCancelled => '已取消下載';

  @override
  String get aboutInstallReady => '安裝包已準備好，已嘗試打開安裝界面；如果系統没有彈出，請稍後從通知或文件管理器手動安裝';

  @override
  String get aboutUpdatePackageTitle => '輕嶼課表更新包';

  @override
  String get aboutUpdatePackageDescription => '已交給系統下載管理器下載，完成後可直接從系統通知安裝';

  @override
  String get aboutSystemDownloaderQueued => '已交給系統下載管理器，請在系統通知或下載列表裡查看進度';

  @override
  String get aboutSystemDownloaderFailed => '調用系統下載管理器失敗';

  @override
  String get aboutDownloadCancelling => '正在取消下載…';

  @override
  String aboutDownloadingBytes(String value) {
    return '正在下載更新 $value';
  }

  @override
  String aboutDownloadingPercent(String value) {
    return '正在下載更新 $value%';
  }

  @override
  String get aboutMirrorUnknownSizeHint => '鏡像源未返回文件總大小，先顯示已下載體積';

  @override
  String get aboutCancelDownloadAction => '取消下載';

  @override
  String get aboutContinueDownloadAction => '繼續下載';

  @override
  String get aboutDismissDialogAction => '關閉彈窗';

  @override
  String get aboutContributorsScreenTitle => '代碼贡獻者';

  @override
  String get aboutDevelopersTitle => '開發人員';

  @override
  String get aboutDeveloperMaintainerSubtitle => '輕嶼課表開發與維護';

  @override
  String get aboutWarehouseMaintainersTitle => '教務匯入適配者';

  @override
  String get aboutWarehouseMaintainersIntro =>
      '以下名單來自 qingyu_warehouse 適配倉的 maintainer 字段匯總，若本地已有緩存，會先顯示緩存，再後台刷新';

  @override
  String aboutWarehouseMaintainersLoadFailed(String error) {
    return '暫時無法讀取適配者名單：$error';
  }

  @override
  String get aboutWarehouseMaintainersEmpty => '目前還没有讀取到適配者資訊';

  @override
  String aboutWarehouseMaintainerCount(int count) {
    return '$count 個適配項';
  }

  @override
  String get aboutParticipateWarehouseTitle => '參與教務適配';

  @override
  String get aboutParticipateWarehouseSubtitle =>
      '如果你會抓包、網頁偵錯、JavaScript，或者願意長期維護自己學校的教務系統，歡迎去 qingyu_warehouse 提交新的學校適配與修複';

  @override
  String get importFileReadFailed => '無法讀取所選文件';

  @override
  String get importCleartextBlockedHint => '該站點暫不支持 HTTPS 訪問且未在明文白名單內，無法在此打開';

  @override
  String get importReplaceExistingTitle => '匯入課程';

  @override
  String importReplaceExistingMessage(String name) {
    return '匯入 $name 時，是否替換現有課程？此操作也會清空目前課表上的獨立日程（如自習、會議等）。';
  }

  @override
  String get importNoCoursesRecognized => '未識別到可匯入課程';

  @override
  String get importConfirmSemesterMappingTitle => '確認開學日期和周次對應';

  @override
  String get importConfirmSemesterMappingSubtitleIcs =>
      '請選擇學校校歷的開學日期，系統已根據文件裡最早的上課日期給出預設周次對應，你也可以手動調整';

  @override
  String importOverwriteCount(int count) {
    return '已覆蓋匯入 $count 條課程';
  }

  @override
  String importUpdatedCount(int count) {
    return '已更新課表：新增或更新 $count 條課程';
  }

  @override
  String get importNoCourseChanges => '没有需要新增或更新的課程';

  @override
  String get aiImportTitle => '識圖匯入';

  @override
  String aiPreviewSummary(
    int courseCount,
    int sectionCount,
    String warningSuffix,
  ) {
    return '識別到 $courseCount 門課，最高到第 $sectionCount 節$warningSuffix';
  }

  @override
  String aiWarningCountSuffix(int count) {
    return '，$count 條提醒';
  }

  @override
  String get aiWorkflowCompactTitle => '複制提示詞 -> 豆包識圖 -> 匯入';

  @override
  String get aiWorkflowCompactSubtitle => '豆包專家模式 -> 複制 JSON -> 選擇開學日期';

  @override
  String get aiWorkflowTitle => '複制提示詞 -> 豆包識圖 -> 粘贴 JSON -> 匯入';

  @override
  String get aiWorkflowSubtitle =>
      '先複制提示詞，再到豆包左下角切換為專家模式，把課表截圖和提示詞一起發過去，把豆包返回的 JSON 複制回這裡，點擊匯入後再選擇開學日期';

  @override
  String get aiPromptShortAction => '提示詞';

  @override
  String get aiExpertModeSuggestion => '建議豆包專家模式，支持多圖，截圖需帶星期表頭';

  @override
  String get aiHintExpertMode => '先切到豆包專家模式';

  @override
  String get aiHintSendScreenshot => '截圖和提示詞一起發';

  @override
  String get aiHintCopyJsonBack => '返回結果複制 JSON';

  @override
  String get aiHintPickSemesterAfterImport => '匯入後再選開學日期';

  @override
  String get jsonLabelShort => 'JSON';

  @override
  String get aiPasteJsonTitle => '粘贴 AI 返回的 JSON';

  @override
  String aiCourseCountChip(int count) {
    return '$count 門課';
  }

  @override
  String get aiParseFailedChip => '解析失敗';

  @override
  String get aiPasteJsonHintShort => '粘贴 AI 返回的 JSON';

  @override
  String get aiPasteJsonHintLong =>
      '把豆包返回的 JSON 原養粘贴到這裡，然後點擊匯入，支持純 JSON，也兼容 ```json 代碼塊';

  @override
  String get detailAction => '詳情';

  @override
  String get aiParseErrorTitle => '解析錯誤';

  @override
  String get viewDetailsAction => '查看詳情';

  @override
  String get aiWorkflowFooter =>
      '複制提示詞 -> 豆包發送截圖和提示詞 -> 把 JSON 贴回這裡 -> 點擊匯入 -> 選擇開學日期';

  @override
  String get previewAction => '預覽';

  @override
  String get confirmImportAction => '確認匯入';

  @override
  String get promptCopiedHint => '提示詞已複制，去豆包發送截圖和提示詞';

  @override
  String get clipboardNoText => '剪贴板裡没有可用文本';

  @override
  String get aiPromptSheetTitle => '識圖提示詞';

  @override
  String get aiPromptSheetSubtitle =>
      '建議使用豆包，先把豆包左下角切換為專家模式，再把下面整段提示詞和課表截圖一起發過去，讓它只返回 JSON，生成後把 JSON 複制回本頁，點擊匯入後再選擇開學日期';

  @override
  String get aiPreviewTitle => '解析預覽';

  @override
  String get aiPasteJsonFirst => '請先粘贴 AI 返回的 JSON';

  @override
  String get aiParseFailedIncompleteJson => '解析失敗，請確認粘贴的是完整 JSON';

  @override
  String get importAiResultTitle => '匯入 AI 解析結果';

  @override
  String get importAiReplaceMessage =>
      '是否用目前這份 AI 解析結果替換現有課程？此操作也會清空目前課表上的獨立日程（如自習、會議等）。';

  @override
  String get importConfirmSemesterMappingSubtitleAi =>
      '請選擇學校校歷的開學日期，再確認課表裡的第 1 周對應校歷第幾周，如果學校第一周没課，這裡通常要改成第 2 周';

  @override
  String aiWarningExtraSuffix(int count) {
    return '，另有 $count 條識別提醒';
  }

  @override
  String get pasteAction => '粘贴';

  @override
  String get importConfirmSemesterMappingSubtitleWarehouse =>
      '教務脚本已返回課程周次，請確認校歷開學日期；如果學校前幾周没有課，可把“課表第 1 周”對應到校歷後面的周次';

  @override
  String aiPreviewCourseCount(int count) {
    return '課程數量：$count';
  }

  @override
  String aiPreviewMaxSection(int section) {
    return '最大節次：第 $section 節';
  }

  @override
  String get aiPreviewWarningsTitle => '識別提醒';

  @override
  String get aiPreviewCoursesTitle => '課程預覽';

  @override
  String aiPreviewRemainingCourses(int count) {
    return '其餘 $count 條將在匯入後寫入目前課表';
  }

  @override
  String get warehouseMissingSchoolTitle => '學校列表裡没有你的學校？';

  @override
  String get warehouseMissingSchoolSubtitle =>
      '去反饋頁提一個 Issue 就行，建議一起寫上學校名稱、教務系統網址、登入後課表頁連結或截圖，這養更方便補適配';

  @override
  String get laterAction => '稍後再說';

  @override
  String get goFeedbackAction => '去反饋頁';

  @override
  String get warehouseFeedbackMissingSchoolTitle => '缺少學校？去反饋';

  @override
  String get warehouseCustomDebugTitle => '自訂偵錯';

  @override
  String get warehouseImportExecutionLogTitle => '課表匯入執行日誌';

  @override
  String get warehouseImportExecutionLogMenuLabel => '課表匯入執行日誌';

  @override
  String get warehouseImportExecutionLogShareText =>
      '這是輕嶼課表匯出的教務匯入執行日誌，包含腳本注入、橋接訊息、逾時與匯入結果等過程記錄，可直接回饋給開發人員排查問題';

  @override
  String get warehouseImportExecutionLogShareSubject => '輕嶼課表 - 課表匯入執行日誌';

  @override
  String get warehouseImportExecutionLogEmpty =>
      '暫無匯入執行記錄。請先開啟教務網頁並執行匯入腳本，再回來查看。';

  @override
  String get warehouseRootLoadFailedTitle => '暫時無法讀取適配倉';

  @override
  String get searchSchoolHint => '搜索學校名稱、首字母或代碼';

  @override
  String get clearSearchTooltip => '清空';

  @override
  String get noMatchingSchools => '没有找到匹配的學校';

  @override
  String get noAvailableSchools => '暫無可用學校';

  @override
  String get searchSchoolSuggestion => '試試學校全稱、首字母或倉庫裡的學校代碼';

  @override
  String get deleteDebugRecordTitle => '刪除偵錯記錄';

  @override
  String deleteDebugRecordMessage(String name) {
    return '確認刪除“$name”？刪除後不會蠅响已經匯入的課程';
  }

  @override
  String deletedDebugRecord(String name) {
    return '已刪除偵錯記錄：$name';
  }

  @override
  String get customDebugName => '自定義偵錯';

  @override
  String get localDebugMaintainer => '本地偵錯';

  @override
  String get customDebugDescription => '用戶保存的自定義教務偵錯脚本';

  @override
  String get addDebugRecordTooltip => '新增偵錯記錄';

  @override
  String get customDebugIntroTitle => '這裡放你自己的教務偵錯記錄';

  @override
  String get customDebugIntroSubtitle =>
      '每條記錄都可以保存自定義網址和整段脚本，保存後下次直接點“開始偵錯”就能複用，不需要再去某個學校詳情頁裡找入口';

  @override
  String get addDebugRecordAction => '新增偵錯記錄';

  @override
  String get noSavedDebugRecords => '還没有保存的偵錯記錄';

  @override
  String get noSavedDebugRecordsHint => '先新增一條，把網址和脚本贴進去，以後就能直接複用';

  @override
  String debugScriptLength(int count) {
    return '脚本 $count 字符';
  }

  @override
  String get startDebugAction => '開始偵錯';

  @override
  String get editAction => '編輯';

  @override
  String get scriptFileReadFailed => '無法讀取脚本文件';

  @override
  String scriptFileImported(String name) {
    return '已匯入脚本文件：$name';
  }

  @override
  String scriptFileImportFailed(String error) {
    return '匯入脚本文件失敗：$error';
  }

  @override
  String get debugRecordNameRequired => '請先填寫偵錯記錄名稱';

  @override
  String get invalidImportUrl => '請輸入有效的教務網址';

  @override
  String get debugScriptRequired => '請先填寫或匯入脚本';

  @override
  String get editDebugRecordTitle => '編輯偵錯記錄';

  @override
  String get addDebugRecordTitle => '新增偵錯記錄';

  @override
  String get savingAction => '保存中…';

  @override
  String get debugRecordFormula => '一條記錄 = 一個網址 + 一段脚本';

  @override
  String get debugRecordFormulaSubtitle =>
      '適合你反複偵錯同一個學校，或者不同學校保留多套脚本，保存後會一直保留，後面可隨時修改';

  @override
  String get debugRecordNameLabel => '記錄名稱';

  @override
  String get debugRecordNameHint => '例如：重慶機電-新版教務';

  @override
  String get importUrlLabel => '教務網址';

  @override
  String get debugScriptLabel => '偵錯脚本';

  @override
  String get importFromFileAction => '從文件匯入';

  @override
  String get debugScriptHint => '把瀏覽器擴展匯出的完整脚本粘贴到這裡';

  @override
  String get saveDebugRecordAction => '保存偵錯記錄';

  @override
  String get fillUrlThenImport => '填寫網址後匯入';

  @override
  String get webLoginImport => '網頁登入匯入';

  @override
  String get fillUrlThenRecord => '填寫網址後錄製';

  @override
  String get recordImportAction => '錄製匯入';

  @override
  String get quickImportAction => '⚡ 快捷匯入';

  @override
  String get quickImportTooltip => '快捷匯入';

  @override
  String get selectQuickImportTitle => '選擇快捷匯入';

  @override
  String quickImportMacroSteps(String adapterName, int stepCount) {
    return '$adapterName · $stepCount 步';
  }

  @override
  String quickImportTitle(String name) {
    return '快捷匯入 - $name';
  }

  @override
  String get noSavedQuickImportRecords => '暫無已保存的快捷匯入記錄';

  @override
  String get noValidWarehouseLoginUrl => '未找到有效的教務登入網址';

  @override
  String get noMacroRecordFound => '未找到錄製記錄，請先完成一次錄製';

  @override
  String get quickImportPlayingTitle => '自動匯入中…';

  @override
  String get quickImportExecutingScriptTitle => '回放完成，正在執行匯入腳本…';

  @override
  String get quickImportManualInputTitle => '需要手動操作';

  @override
  String get quickImportManualInputHint => '請完成當前需要的手動操作，完成後點擊繼續';

  @override
  String get quickImportCancelImportAction => '取消匯入';

  @override
  String get quickImportContinueAction => '繼續';

  @override
  String get quickImportFinishedTitle => '匯入完成';

  @override
  String get quickImportDismissAction => '完成';

  @override
  String get quickImportRetryAction => '重試';

  @override
  String get homePullQuickImportTitle => '首頁下拉快捷匯入';

  @override
  String get homePullQuickImportSubtitle => '在首頁下拉時自動執行教務快捷匯入';

  @override
  String get homePullQuickImportFetchingCourses => '正在獲取新課程…';

  @override
  String get homePullQuickImportNeedsManualAction => '需要手動操作，請前往教務匯入頁面繼續';

  @override
  String quickImportPlaybackStepProgress(int current, int total) {
    return '步驟 $current / $total';
  }

  @override
  String get quickImportCancelPlaybackAction => '取消';

  @override
  String get quickImportUnknownError => '發生未知錯誤';

  @override
  String get recentSchoolLabel => '最近使用';

  @override
  String get warehouseSchoolTapHint => '點擊進入，選擇適配器匯入';

  @override
  String get warehouseAdaptersLoadFailedTitle => '暫時無法讀取適配器列表';

  @override
  String get stopRecordingTooltip => '停止錄製';

  @override
  String get startRecordingTooltip => '錄製操作';

  @override
  String get savedImportUrlHint => '已保存教務網址，下次可直接匯入';

  @override
  String get adapterIntroSubtitle => '可查看適配器資訊、登入入口與脚本狀態';

  @override
  String get schoolLabel => '學校';

  @override
  String get categoryLabel => '類別';

  @override
  String get maintainerLabel => '維護者';

  @override
  String get adapterInfoTitle => '適配器資訊';

  @override
  String get scriptPathLabel => '脚本路徑';

  @override
  String get loginEntryLabel => '登入入口';

  @override
  String get unsetConfigLabel => '未配置';

  @override
  String get adapterOverrideImportUrlHint => '目前使用你手動覆蓋的登入地址';

  @override
  String get repositoryLabel => '倉庫';

  @override
  String get scriptStatusTitle => '脚本狀態';

  @override
  String scriptLoadedLength(int count) {
    return '脚本已成功讀取，長度 $count 字符';
  }

  @override
  String get scriptEmpty => '脚本為空';

  @override
  String get openLoginInAppAction => '應用內打開登入入口';

  @override
  String get openInSystemBrowserAction => '系統瀏覽器打開';

  @override
  String get copiedImportLoginUrl => '已複制教務登入地址';

  @override
  String get copyLoginAddressAction => '複制登入地址';

  @override
  String get copiedScriptRawUrl => '已複制脚本原始地址';

  @override
  String get copyScriptAddressAction => '複制脚本地址';

  @override
  String get customLoginAddressAction => '自定義登入地址';

  @override
  String get editCustomLoginAddressAction => '修改自定義地址';

  @override
  String get clearCustomLoginAddressAction => '清除自定義地址';

  @override
  String get restoreRepositoryAddressAction => '恢複倉庫地址';

  @override
  String get invalidLoginEntryUrl => '登入入口地址無效';

  @override
  String get savedCustomLoginAddress => '已保存自定義登入地址';

  @override
  String get clearedCustomLoginAddress => '已清除自定義登入地址';

  @override
  String get restoredRepositoryImportUrl => '已恢複倉庫裡的登入地址';

  @override
  String get backToCurrentWeekAction => '返回本週';

  @override
  String get nonCurrentWeekLabel => '非本周';

  @override
  String get conflictLabel => '衝突';

  @override
  String get courseConflictSectionTitle => '衝突課程';

  @override
  String get courseNormalSectionTitle => '其他課程';

  @override
  String get courseConflictDetailTitle => '衝突詳情';

  @override
  String get courseConflictDetailEntryTitle => '查看衝突詳情';

  @override
  String get courseConflictDetailEntrySubtitle => '查看互撞排課與重疊時段';

  @override
  String courseConflictWithCourse(String name) {
    return '與「$name」衝突';
  }

  @override
  String get courseConflictOpenPartnerAction => '查看對方排課';

  @override
  String get courseConflictEmpty => '目前沒有偵測到衝突';

  @override
  String get courseConflictPairTitle => '衝突組合';

  @override
  String get selectWeekTitle => '選擇周次';

  @override
  String availableWeeksCount(int count) {
    return '共 $count 周';
  }

  @override
  String goToWeekLabel(int week) {
    return '第 $week 周';
  }

  @override
  String get homeMenuUpdateTitle => '軟體更新';

  @override
  String get homeMenuProfilesTitle => '課表管理';

  @override
  String get homeMenuOverviewTitle => '課程總覽';

  @override
  String get homeMenuAddCourseTitle => '新增課程';

  @override
  String get homeMenuImportTitle => '匯入課程';

  @override
  String get homeMenuSettingsTitle => '課表設定';

  @override
  String get homeMenuCoffeeTitle => '請喝咖啡';

  @override
  String get homeMenuFeedbackTitle => '問題回饋';

  @override
  String get switchTimetableTitle => '切換課表';

  @override
  String get todayTimetableTitle => '今日課表';

  @override
  String get dayTimetableTitle => '單日時間軸';

  @override
  String get backToWeekViewAction => '返回周視圖';

  @override
  String get backToTodayAction => '回到今天';

  @override
  String get ongoingCourseBadge => '正在上課';

  @override
  String get dayViewEmptyTitle => '暫無課程';

  @override
  String shortNamePrefix(String value) {
    return '簡稱：$value';
  }

  @override
  String teacherPrefix(String value) {
    return '老師：$value';
  }

  @override
  String locationPrefix(String value) {
    return '地點：$value';
  }

  @override
  String courseDialogCurrentWeekHint(int week) {
    return '目前查看第 $week 周，可直接對這一周這節課調課';
  }

  @override
  String courseDialogNotThisWeekHint(int week) {
    return '目前查看第 $week 周，這門課這周没有上課，因此不能按“本周這節”調課';
  }

  @override
  String get editActionShort => '編輯';

  @override
  String get rescheduleAction => '調課';

  @override
  String get deleteActionShort => '刪除';

  @override
  String get deleteModeTitle => '刪除方式';

  @override
  String get deleteModeSubtitle => '你可以刪掉整條排課，也可以只刪目前看到的這一周這一節';

  @override
  String get deleteCourseAction => '刪這個課';

  @override
  String get deleteOccurrenceAction => '刪這節課';

  @override
  String deleteModeHintCurrentWeek(int week) {
    return '“刪這個課”會刪除這條排課的全部周次；“刪這節課”只會刪除第 $week 周這一次';
  }

  @override
  String deleteModeHintUnavailable(int week) {
    return '目前卡片不是第 $week 周的實際排課，所以只能刪除整條排課';
  }

  @override
  String deleteScheduleConfirmMessage(String name, String detail) {
    return '確定刪除“$name”這條排課嗎？\n$detail';
  }

  @override
  String deleteOccurrenceConfirmMessage(String name, int week, String detail) {
    return '確定刪除“$name”在第 $week 周的這一節嗎？\n$detail';
  }

  @override
  String occurrenceDeletedMessage(int week) {
    return '已刪除第 $week 周這節課';
  }

  @override
  String get noChangesDetected => '未檢測到變更';

  @override
  String get rescheduleCurrentOccurrenceTitle => '調本周這節課';

  @override
  String rescheduleCurrentOccurrenceSubtitle(int week) {
    return '僅改第 $week 週本節，原課該週移除，其他週不變';
  }

  @override
  String get rescheduleTargetWeekLabel => '調到第幾周';

  @override
  String get weekdayFieldLabel => '星期';

  @override
  String get startSectionFieldLabel => '開始節次';

  @override
  String get endSectionFieldLabel => '結束節次';

  @override
  String get courseLocationFieldLabel => '上課地點';

  @override
  String get confirmRescheduleAction => '確認調課';

  @override
  String get homeTitleStyleClassicLabel => '經典文字';

  @override
  String get homeTitleStyleBrandLabel => '大 Logo';

  @override
  String get homeTitleStyleClassicDescription => '維持原本標題樣式，只顯示文字，點一下即可切換課表';

  @override
  String get homeTitleStyleBrandDescription => '顯示大 Logo 和較小的課表名稱，更強調品牌感';

  @override
  String get widgetBackgroundStyleGlass => '半透明玻璃感';

  @override
  String get widgetBackgroundStyleSolid => '純色卡片';

  @override
  String get widgetBackgroundStyleGradient => '漸變卡片';

  @override
  String get homeWidgetTargetCompact22 => '主卡 2×2';

  @override
  String get homeWidgetTargetMiniList22 => '迷你清單 2×2';

  @override
  String get homeWidgetTargetMedium24 => '概覽 2×4';

  @override
  String get homeWidgetTargetLarge44 => '清單 4×4';

  @override
  String get homeWidgetTargetStats22 => '統計 2×2';

  @override
  String get homeWidgetTargetStats24 => '統計概覽 2×4';

  @override
  String get homeWidgetTargetTodayStrip41 => '今日橫條 4×1';

  @override
  String get homeWidgetTargetStatsStrip41 => '統計橫條 4×1';

  @override
  String get homeWidgetTargetExamCard22 => '考試倒數 2×2';

  @override
  String get homeWidgetTargetTodayWide42 => '今日橫寬 4×2';

  @override
  String get addCourseSheetTitle => '新增內容';

  @override
  String get addCourseSheetSubtitle =>
      '空白課表區域不響應點擊，請從這裡明確選擇是加一節臨時課、整學期重複課，還是插入一條單次日程';

  @override
  String courseWeekdaySectionSummary(
    String weekDescription,
    String weekday,
    int startSection,
    int endSection,
  ) {
    return '$weekDescription · $weekday 第$startSection-$endSection節';
  }

  @override
  String weekdaySectionTimeSummary(
    String weekday,
    int startSection,
    int endSection,
    String startTime,
    String endTime,
  ) {
    return '$weekday 第$startSection-$endSection節 · $startTime-$endTime';
  }

  @override
  String rescheduledToMessage(
    int week,
    String weekday,
    int startSection,
    int endSection,
  ) {
    return '已調到第 $week 周 $weekday 第$startSection-$endSection節';
  }

  @override
  String courseCountSummary(int count) {
    return '$count 門課';
  }

  @override
  String dayAgendaInProgressStatus(int minutes) {
    return '進行中 · 剩餘 $minutes 分鐘';
  }

  @override
  String dayAgendaEndingSoonStatus(int minutes) {
    return '快下課了 · 剩餘 $minutes 分鐘';
  }

  @override
  String scheduleAgendaInProgressStatus(int minutes) {
    return '進行中 · 剩餘 $minutes 分鐘';
  }

  @override
  String scheduleAgendaEndingSoonStatus(int minutes) {
    return '即將結束 · 剩餘 $minutes 分鐘';
  }

  @override
  String get currentBadge => '當前';

  @override
  String get feedbackXiaohongshuTitle => '小紅書';

  @override
  String feedbackXiaohongshuSubtitle(String id) {
    return '小紅書號：$id';
  }

  @override
  String get feedbackCoolapkTitle => '酷安';

  @override
  String feedbackCoolapkSubtitle(String id) {
    return '酷安號：$id';
  }

  @override
  String get feedbackQqGroupTitle => 'QQ 群';

  @override
  String feedbackQqGroupSubtitle(String id) {
    return '群號：$id';
  }

  @override
  String get feedbackWechatOaTitle => '微信公眾號';

  @override
  String feedbackWechatOaSubtitle(String name) {
    return '$name';
  }

  @override
  String get copiedCurrentTimetable => '已複製當前課表';

  @override
  String sectionRangeLabel(int startSection, int endSection) {
    return '第$startSection-$endSection節';
  }

  @override
  String classStartsAtLabel(String time) {
    return '$time 開始';
  }

  @override
  String classEndsAtLabel(String time) {
    return '$time 結束';
  }

  @override
  String get invalidSectionTimeFormat => '節次時間格式不正確';

  @override
  String get noSectionTimesToSave => '沒有可保存的節次時間';

  @override
  String warehouseImportedTimeSchemeName(String schoolName) {
    return '$schoolName 匯入節次';
  }

  @override
  String get unnamedScript => '未命名腳本';

  @override
  String localDebugModeScriptStatus(String scriptName) {
    return '本地偵錯模式：$scriptName';
  }

  @override
  String get executeImportScriptTooltip => '執行匯入腳本';

  @override
  String get switchToMobileWebTooltip => '切換到移動端頁面';

  @override
  String get switchToDesktopWebTooltip => '切換到桌面端頁面';

  @override
  String get rememberCurrentInputTooltip => '記住當前輸入';

  @override
  String get fillRememberedTooltip => '填充已記住賬號';

  @override
  String get clearRememberedTooltip => '清除已記住賬號';

  @override
  String get copyCurrentAddressTooltip => '複製當前地址';

  @override
  String get copiedCurrentAddress => '已複製當前地址';

  @override
  String get warehouseLoginHintLocalDebug => '當前為本地偵錯腳本模式';

  @override
  String get warehouseLoginHintImport => '在此登入教務系統後執行匯入';

  @override
  String get currentPageModeDesktop => '當前頁面模式：桌面端';

  @override
  String get currentPageModeMobile => '當前頁面模式：移動端';

  @override
  String localScriptLabel(String scriptName) {
    return '本地腳本：$scriptName';
  }

  @override
  String get webAddressHint => '輸入網頁地址';

  @override
  String get goAction => '前往';

  @override
  String rememberedAccountLabel(String username) {
    return '已記住賬號：$username';
  }

  @override
  String get importingAction => '匯入中...';

  @override
  String get executeLocalDebugScriptAction => '執行本地偵錯腳本';

  @override
  String get executeImportScriptAction => '執行匯入腳本';

  @override
  String get invalidWebAddress => '網頁地址無效';

  @override
  String get injectingLocalDebugScript => '正在注入本地偵錯腳本';

  @override
  String get injectingAdapterScript => '正在注入適配器腳本';

  @override
  String get localDebugScriptInjected => '本地偵錯腳本已注入';

  @override
  String get scriptInjected => '腳本已注入';

  @override
  String get scriptInjectionFailed => '腳本注入失敗';

  @override
  String executeFailedWithError(String error) {
    return '執行失敗：$error';
  }

  @override
  String get importFlowFinished => '匯入流程已完成';

  @override
  String get defaultContinuePrompt => '請按提示繼續操作';

  @override
  String get inputRequiredTitle => '需要輸入';

  @override
  String get pleaseEnterFourDigitYear => '請輸入 4 位年份';

  @override
  String get pleaseChooseTitle => '請選擇';

  @override
  String get invalidCourseConfigFormat => '課程配置格式不正確';

  @override
  String saveCourseConfigFailedWithError(String error) {
    return '保存課程配置失敗：$error';
  }

  @override
  String saveSectionTimesFailedWithError(String error) {
    return '保存節次時間失敗：$error';
  }

  @override
  String get invalidCourseDataFormat => '課程資料格式不正確';

  @override
  String get noImportableCoursesFromScript => '腳本未返回可匯入課程';

  @override
  String importCourseCountPrompt(int count) {
    return '識別到 $count 門課程，是否匯入？';
  }

  @override
  String get importCancelledStatus => '已取消匯入';

  @override
  String applyReturnedTimeSchemeFailed(String error) {
    return '應用返回的節次模板失敗：$error';
  }

  @override
  String get importInterruptedStatus => '匯入已中斷';

  @override
  String get importFailedStatus => '匯入失敗';

  @override
  String importFailedWithError(String error) {
    return '匯入失敗：$error';
  }

  @override
  String get unknownTeacher => '未知教師';

  @override
  String get unknownLocation => '未知地點';

  @override
  String get autofillLoginTitle => '自動填充登入資訊';

  @override
  String autofillLoginMessage(String username) {
    return '檢測到已記住賬號 $username，是否自動填充？';
  }

  @override
  String get notNowAction => '暫不';

  @override
  String get autofillAction => '自動填充';

  @override
  String get rememberPasswordTitle => '記住密碼';

  @override
  String rememberPasswordMessage(String username) {
    return '是否記住賬號 $username 的登入資訊，並在下次自動填充？';
  }

  @override
  String get dontRememberAction => '不記住';

  @override
  String get rememberAndAutofillAction => '記住並自動填充';

  @override
  String get savedRememberedLoginStatus => '已保存記住的登入資訊';

  @override
  String get autofilledRememberedLoginStatus => '已自動填充記住的登入資訊';

  @override
  String get noRecognizedLoginInputs => '未識別到登入輸入項';

  @override
  String get noUsernameOrPasswordRecognized => '未識別到用戶名或密碼';

  @override
  String get rememberedCurrentLoginStatus => '已記住當前登入資訊';

  @override
  String get rememberedCurrentLoginSuccess => '已記住當前登入資訊';

  @override
  String rememberLoginFailedWithError(String error) {
    return '記住登入資訊失敗：$error';
  }

  @override
  String get clearedRememberedLoginStatus => '已清除記住的登入資訊';

  @override
  String get clearedRememberedLoginSuccess => '已清除記住的登入資訊';

  @override
  String get addScheduleTitle => '新增日程';

  @override
  String get editScheduleTitle => '編輯日程';

  @override
  String get addScheduleAction => '新增日程';

  @override
  String get scheduleTitleLabel => '日程標題';

  @override
  String get scheduleTitleHint => '例如：開組會、辦證件、取快遞';

  @override
  String get scheduleTitleRequired => '請輸入日程標題';

  @override
  String get scheduleInfoSectionTitle => '日程資訊';

  @override
  String get scheduleInfoSectionSubtitle => '日程會按具體日期插入日視圖時間線，不會改動課程本身';

  @override
  String get scheduleTimeSectionTitle => '時間安排';

  @override
  String get scheduleTimeSectionSubtitle => '選擇這條日程實際發生的日期和起止時間';

  @override
  String get scheduleAppearanceSectionTitle => '顯示樣式';

  @override
  String get scheduleAppearanceSectionSubtitle => '選一個更容易和課程區分的日程顏色';

  @override
  String get scheduleLocationLabel => '地點';

  @override
  String get scheduleLocationHint => '選填';

  @override
  String get scheduleDateLabel => '日期';

  @override
  String get scheduleStartGroupLabel => '開始';

  @override
  String get scheduleEndGroupLabel => '結束';

  @override
  String get scheduleStartDateLabel => '開始日期';

  @override
  String get scheduleEndDateLabel => '結束日期';

  @override
  String get scheduleStartTimeLabel => '開始時間';

  @override
  String get scheduleEndTimeLabel => '結束時間';

  @override
  String get scheduleColorLabel => '日程顏色';

  @override
  String get scheduleNoteLabel => '備註';

  @override
  String get scheduleNoteHint => '選填';

  @override
  String get scheduleBadgeLabel => '日程';

  @override
  String scheduleCountSummary(int count) {
    return '日程 $count 項';
  }

  @override
  String get scheduleTimeRangeInvalid => '結束時間必須晚於開始時間';

  @override
  String get scheduleDateRangeInvalid => '結束日期不能早於開始日期';

  @override
  String get scheduleSingleDayHint => '同日結束時，結束時間必須晚於開始時間';

  @override
  String get scheduleCrossDayHint => '跨日日程會按當天切片顯示在日視圖時間線裡';

  @override
  String get scheduleSavedHint => '日程已新增';

  @override
  String get scheduleUpdatedHint => '日程已更新';

  @override
  String get crossDayBadgeLabel => '跨日';

  @override
  String deleteScheduleMessage(String title) {
    return '刪除日程「$title」？';
  }

  @override
  String get scheduleDeletedHint => '日程已刪除';

  @override
  String get scheduleListTitle => '日程安排';

  @override
  String get scheduleListEmptyTitle => '暫無日程';

  @override
  String get scheduleUpcomingSection => '即將到來';

  @override
  String get schedulePastSection => '已過期';

  @override
  String get schedulePausedSection => '已暫停';

  @override
  String get scheduleOngoingLabel => '進行中';

  @override
  String scheduleTimeRange(String start, String end) {
    return '$start – $end';
  }

  @override
  String scheduleWeeklyWithDay(String day) {
    return '每週$day';
  }

  @override
  String get examListTitle => '考試安排';

  @override
  String get addExam => '添加考試';

  @override
  String get editExam => '編輯考試';

  @override
  String get saveExam => '儲存考試';

  @override
  String get noExams => '暫無考試安排';

  @override
  String get examToday => '今天有考試';

  @override
  String daysUntilExam(int days) {
    return '距離考試還有 $days 天';
  }

  @override
  String get examPassed => '已結束';

  @override
  String get linkCourse => '關聯課程';

  @override
  String get linkCourseRequired => '請選擇關聯課程';

  @override
  String get examNameLabel => '考試名稱';

  @override
  String get examNameRequired => '請輸入考試名稱';

  @override
  String get examDateLabel => '考試日期';

  @override
  String get examDateHint => '請選擇日期';

  @override
  String get examDateRequired => '請選擇考試日期';

  @override
  String get examEndTimeBeforeStart => '結束時間不能早於開始時間';

  @override
  String get examStartTimeLabel => '開始時間';

  @override
  String get examEndTimeLabel => '結束時間';

  @override
  String get examLocationLabel => '考場';

  @override
  String get examLocationHint => '留空則使用上課教室';

  @override
  String get sameAsClassroom => '同上課教室';

  @override
  String get examSeatLabel => '座位號';

  @override
  String get examReminderLabel => '提醒設定';

  @override
  String get examNoteLabel => '備註';

  @override
  String get deleteExam => '刪除考試';

  @override
  String deleteExamConfirm(String name) {
    return '刪除考試「$name」？';
  }

  @override
  String get examBadgeLabel => '考試';

  @override
  String get examCountdownToday => '今天';

  @override
  String examCountdownDays(int days) {
    return '$days天後';
  }

  @override
  String get examOverviewCountdown => '倒數';

  @override
  String get examOverviewCountdownUnit => '天後';

  @override
  String examOverviewTodayCount(int count) {
    return '今日 $count 場';
  }

  @override
  String examOverviewUpcomingCount(int count) {
    return '共 $count 場';
  }

  @override
  String get examOverviewInProgress => '考試進行中';

  @override
  String get examOverviewLiveBadge => '進行中';

  @override
  String examOverviewStartsAt(String time) {
    return '$time 開始';
  }

  @override
  String examOverviewUntilTime(String time) {
    return '至 $time';
  }

  @override
  String get examOverviewReminderOn => '已設提醒';

  @override
  String get examOverviewReminderOff => '未設提醒';

  @override
  String examTimeRange(String start, String end) {
    return '$start – $end';
  }

  @override
  String get sortAction => '排序';

  @override
  String get sortByAdded => '按加入次序';

  @override
  String get sortByName => '按課程名稱';

  @override
  String get sortBySchedule => '按上課時間';

  @override
  String scheduleEntryTitle(int index) {
    return '排課記錄 $index';
  }

  @override
  String get scheduleEntrySingleTitle => '上課安排';

  @override
  String get scheduleEntryCardSubtitle => '設定這門課在何時、哪些週、由誰在哪裡上課';

  @override
  String get scheduleEntryTimeSectionTitle => '什麼時候上';

  @override
  String get scheduleEntryTimeSectionSubtitle => '選擇星期幾和第幾節課；連堂請填寫起止節次，單節課起止相同';

  @override
  String get scheduleEntryWeeksSectionTitle => '哪些週上';

  @override
  String get scheduleEntryPeopleSectionTitle => '誰在哪裡上';

  @override
  String get scheduleEntryTimeSchemeSectionTitle => '特殊時間方案';

  @override
  String get scheduleEntryTimeSchemeSectionSubtitle =>
      '預設跟隨當前課表；僅當本節課上下課時間與課表不同時才需要修改';

  @override
  String scheduleSectionNumberLabel(int section) {
    return '$section節';
  }

  @override
  String get addScheduleEntryAction => '新增排課時段';

  @override
  String get deleteScheduleEntryAction => '刪除排課';

  @override
  String get holidaySettingsEntryTitle => '假日標記';

  @override
  String get holidaySettingsEntrySubtitle => '在課表上標記公眾假期和調休補班';

  @override
  String get holidayMakeupWorkday => '補班';

  @override
  String get holidaySettingsTitle => '假日標記';

  @override
  String get holidayEnableTitle => '啟用假日標記';

  @override
  String get holidayEnableSubtitle => '啟用後會在課表上標記公眾假期和調休補班';

  @override
  String get holidayDataSectionTitle => '假期資料';

  @override
  String get holidayDataYear => '年份';

  @override
  String get holidayDataCount => '數量';

  @override
  String get holidayDataEmpty => '暫無假期資料';

  @override
  String get holidayCheckUpdate => '檢查更新';

  @override
  String get holidayAdvancedTitle => '假期資料更新';

  @override
  String get holidayUpcomingSectionTitle => '近期假期';

  @override
  String get holidayNoUpcoming => '近期沒有假期';

  @override
  String get holidayBadgeLabel => '休';

  @override
  String get holidayStatusLabel => '假期';

  @override
  String get suspendedBadgeLabel => '停';

  @override
  String get suspendedStatusLabel => '停課';

  @override
  String get courseActionSuspend => '停課';

  @override
  String get courseActionUnsuspend => '恢復上課';

  @override
  String get courseActionEditPrimary => '編輯課程';

  @override
  String get courseActionRescheduleSecondary => '調課';

  @override
  String get courseActionSuspendSecondary => '停課';

  @override
  String get courseActionDeleteSecondary => '刪除';

  @override
  String get courseNoteSheetTitle => '課程備註';

  @override
  String get courseNoteAction => '備註';

  @override
  String get courseNoteSaveAction => '儲存';

  @override
  String get courseNoteTabWholeCourse => '課程簡介';

  @override
  String get courseNoteTabThisSession => '本節課';

  @override
  String get courseNoteWholeCourseLabel => '課程簡介';

  @override
  String get courseNoteWholeCourseHint => '同名課程共享，長期有效（例如課程說明、課堂注意事項）。';

  @override
  String get courseNoteWholeCoursePlaceholder => '例如：這個老師容易點名、教室在新大樓…';

  @override
  String get courseNoteSessionLabel => '本節課備註';

  @override
  String courseNoteSessionHint(int week) {
    return '僅對第 $week 週這一次課生效，適合記錄作業或攜帶物品。';
  }

  @override
  String get courseNoteSessionPlaceholder => '例如：交第三章習題、帶電腦…';

  @override
  String get courseNoteHasHomeworkTitle => '有作業';

  @override
  String get courseNoteHasHomeworkSubtitle => '開啟後，週檢視課程卡片會顯示作業圓標';

  @override
  String get courseNoteHomeworkMarked => '本節有作業';

  @override
  String get courseNoteTileSubtitleEmpty => '記錄作業、帶電腦或課堂提醒';

  @override
  String get courseNoteTileSubtitleWhole => '已有課程簡介';

  @override
  String get courseNoteTileSubtitleSession => '已有本節課備註';

  @override
  String get courseNoteTileSubtitleBoth => '課程簡介與本節課均有備註';

  @override
  String get courseNoteReadOnlyNotice => '對方課程僅可查看備註，無法編輯。';

  @override
  String get courseNoteDoneEditingAction => '完成';

  @override
  String courseActionSheetNotice(int week) {
    return '您正在查看第 $week 周，如該時段突發考試或衝突，可立即在下方執行快速調課或停課';
  }

  @override
  String get courseActionOddWeekShort => '單周';

  @override
  String get courseActionEvenWeekShort => '雙周';

  @override
  String get courseActionConflictExpandHint => '展開查看其他衝突課程，點擊可切換操作對象';

  @override
  String get courseActionConflictCollapseHint => '點擊收起衝突課程列表';

  @override
  String get courseActionConflictSwitchAction => '切換';

  @override
  String courseActionCoupleRelatedCount(int count) {
    return '還有 $count 節情侶課表課程';
  }

  @override
  String get courseActionCoupleExpandHint => '展開查看對方的課或一起上課，點擊可切換預覽';

  @override
  String get courseActionCoupleCollapseHint => '點擊收起情侶課表課程列表';

  @override
  String courseActionMixedRelatedCount(int count) {
    return '還有 $count 節相關課程';
  }

  @override
  String get courseActionPartnerReadOnlyNotice => '這是對方課表中的課程，僅供查看，無法編輯或調課';

  @override
  String get suspendSheetTitle => '停課';

  @override
  String get suspendSheetSubtitle => '選擇停課範圍';

  @override
  String get suspendThisWeek => '本週停課';

  @override
  String get suspendThisWeekDesc => '只停本週';

  @override
  String get suspendAllWeeks => '全部週次停課';

  @override
  String get suspendAllWeeksDesc => '套用到所有週次';

  @override
  String get unsuspendAllWeeks => '恢復全部週次';

  @override
  String get unsuspendAllWeeksDesc => '恢復所有週次';

  @override
  String get customHolidayTitle => '自訂假期';

  @override
  String get customHolidayAdd => '新增假期';

  @override
  String get customHolidayEdit => '編輯假期';

  @override
  String get customHolidayDelete => '刪除';

  @override
  String get customHolidayDeleteConfirm => '確定要刪除此自訂假期嗎？';

  @override
  String get customHolidayNameLabel => '假期名稱';

  @override
  String get customHolidayStartDate => '開始日期';

  @override
  String get customHolidayEndDate => '結束日期';

  @override
  String get customHolidayType => '類型';

  @override
  String get customHolidayTypeVacation => '放假';

  @override
  String get customHolidayTypeWorkday => '調休補班';

  @override
  String get customHolidayEmpty => '暫無自訂假期';

  @override
  String get customHolidayCorrupted => '自訂假期資料讀取異常，已暫停讀寫以防覆蓋丟失';

  @override
  String get customHolidayNameRequired => '請輸入假期名稱';

  @override
  String customHolidayDateRange(Object start, Object end) {
    return '$start ~ $end';
  }

  @override
  String get selectTeacherTitle => '選擇老師';

  @override
  String get selectLocationTitle => '選擇地點';

  @override
  String get historyRecordsLabel => '歷史記錄';

  @override
  String get noHistoryRecords => '暫無歷史記錄';

  @override
  String get weekPickerTitle => '選擇上課週次';

  @override
  String get selectTimeSchemeTitle => '選擇時間方案';

  @override
  String get manageTimeSchemesAction => '管理時間方案';

  @override
  String get examDefaultName => '期末考試';

  @override
  String get examDateWeekPickerTitle => '選擇考試日期';

  @override
  String get weekPickerCalendarTooltip => '使用日曆選擇';

  @override
  String get thisWeekLabel => '本週';

  @override
  String get guidePrivacyPageTitle => '私隱條款';

  @override
  String get guidePermissionsPageTitle => '系統權限';

  @override
  String get guideTipsPageTitle => '使用技巧';

  @override
  String get guidePersonalizePageTitle => '個人化設定';

  @override
  String get guidePersonalizeSubtitle => '以下選擇立即生效，之後可隨時在「設定 → 外觀」中調整';

  @override
  String get guidePersonalizeMenuStyleTitle => '選單樣式';

  @override
  String get guidePersonalizeNavFormTitle => '導覽形態';

  @override
  String get guidePersonalizeVisualEffectTitle => '視覺效果';

  @override
  String get guidePersonalizeVisualEffectSolid => '實體卡片';

  @override
  String get guideVisualEffectGaussianDesc => '背景即時高斯模糊，通透有層次';

  @override
  String get guideVisualEffectLiquidDesc => '液態玻璃折射，更具質感（功耗略高）';

  @override
  String get guideVisualEffectSolidDesc => '不啟用模糊效果，效能最佳';

  @override
  String get guidePersonalizeThemeModeTitle => '深淺色模式';

  @override
  String get guidePersonalizeSeedColorTitle => '主題色';

  @override
  String get guidePrevButton => '上一步';

  @override
  String get guideNextButton => '下一步';

  @override
  String get guidePermissionsHeader => '系統權限設置';

  @override
  String get guidePermissionsSubtitle => '完成這些設置，超級島和提醒才能正常使用';

  @override
  String get guidePermissionsFooterHint =>
      '點擊後跳轉到系統設置，返回應用後可識別的狀態會自動刷新；自啟動受系統限制，請以系統頁面開關為準';

  @override
  String get guideTipsHeader => '使用技巧';

  @override
  String get guideTipsSubtitle => '這些隨時可以在「設置」裡找到';

  @override
  String get guidePrivacyReadBeforeUse => '使用前請閱讀並同意以下內容';

  @override
  String get guidePrivacyViewOnly => '私隱、第三方 SDK 與免責聲明';

  @override
  String holidayDataYearLabel(Object year) {
    return '$year年公眾假期';
  }

  @override
  String get holidayUpdateLog => '更新日誌';

  @override
  String holidayUpdateLogCount(int count) {
    return '$count條';
  }

  @override
  String holidayDateSameMonth(int month, int start, int end) {
    return '$month月$start日 - $end日';
  }

  @override
  String holidayDateSameDay(int month, int day) {
    return '$month月$day日';
  }

  @override
  String holidayDateDiffMonth(
    int startMonth,
    int startDay,
    int endMonth,
    int endDay,
  ) {
    return '$startMonth月$startDay日 - $endMonth月$endDay日';
  }

  @override
  String get liveTestingHolidayOverride => '假期狀態覆蓋';

  @override
  String get liveTestingHolidayOverrideSubtitle =>
      '開啟後模擬假期狀態，用於測試提醒和小工具是否正確隱藏課程';

  @override
  String get liveTestingHolidayModeEnabled => '假期模式已開啟';

  @override
  String get liveTestingHolidayModeDisabled => '假期模式已關閉';

  @override
  String get liveTestingHolidayModeEnabledDesc => '課程提醒和小工具將隱藏所有課程';

  @override
  String get liveTestingHolidayModeDisabledDesc => '當前使用正常假期數據';

  @override
  String get textColorTitle => '文字顏色';

  @override
  String get textColorSubtitle => '自訂課表各區域嘅文字顏色';

  @override
  String get textColorIndependentDetail => '獨立設定詳情顏色';

  @override
  String get textColorCourseCardTitle => '課程卡片標題顏色';

  @override
  String get textColorCourseCardDetail => '課程卡片詳情顏色';

  @override
  String get textColorWeekdayBar => '星期欄字體顏色';

  @override
  String get textColorWeekdayBarAccent => '星期欄強調顏色';

  @override
  String get textColorTimeAxis => '時間軸字體顏色';

  @override
  String get textColorSelectColor => '選擇顏色';

  @override
  String get textColorCurrentColor => '目前顏色';

  @override
  String get themeExport => '匯出主題';

  @override
  String get themeImport => '匯入主題';

  @override
  String get themeExportSuccess => '主題已複製到剪貼簿';

  @override
  String get themeImportSuccess => '主題已匯入';

  @override
  String get themeImportFailed => '剪貼簿內容格式錯誤';

  @override
  String get themeManageTitle => '主題管理';

  @override
  String get themeManageSubtitle => '匯出、匯入和切換主題';

  @override
  String get themePreset => '預設主題';

  @override
  String get themeSaved => '我的主題';

  @override
  String get themeSaveCurrent => '儲存當前主題';

  @override
  String get themeApply => '套用';

  @override
  String get themeDelete => '刪除';

  @override
  String themeDeleteConfirmMessage(String name) {
    return '確定要刪除主題「$name」嗎？';
  }

  @override
  String get textColorLowContrastWarning => '顏色對比度較低，可能會蠅響可讀性';

  @override
  String get themeCurrentTheme => '當前主題';

  @override
  String themeBasedOnModified(String baseName) {
    return '基於$baseName（已修改）';
  }

  @override
  String get themeResetToPreset => '重設';

  @override
  String get themeUnsavedChangesTitle => '未儲存的修改';

  @override
  String get themeUnsavedChangesMessage => '當前主題有未儲存的修改，是否儲存？';

  @override
  String get themeDiscardAndApply => '放棄並套用';

  @override
  String get themeNameHint => '輸入主題名稱';

  @override
  String get themePresetBlue => '預設藍';

  @override
  String get themePresetPurple => '暗夜紫';

  @override
  String get themePresetGreen => '森林綠';

  @override
  String get themePresetOrange => '暖陽橙';

  @override
  String get themePresetEyeCare => '護眼模式';

  @override
  String get themePresetHighContrast => '高對比度';

  @override
  String get themePresetDarkMinimal => '深色極簡';

  @override
  String get foruiThemeNeutral => '中性灰';

  @override
  String get foruiThemeZinc => '鋅灰';

  @override
  String get foruiThemeSlate => '石板灰';

  @override
  String get foruiThemeBlue => '藍';

  @override
  String get foruiThemeGreen => '綠';

  @override
  String get foruiThemeOrange => '橙';

  @override
  String get foruiThemeRed => '紅';

  @override
  String get foruiThemeRose => '玫紅';

  @override
  String get foruiThemeViolet => '紫';

  @override
  String get foruiThemeYellow => '黃';

  @override
  String get themeUndo => '撤銷';

  @override
  String themeChanged(String themeName) {
    return '已切換到 $themeName';
  }

  @override
  String get themeRename => '重新命名';

  @override
  String get themeDuplicate => '複製';

  @override
  String themeDuplicateCopyName(String name) {
    return '$name 副本';
  }

  @override
  String get themeMoreActions => '更多操作';

  @override
  String get courseNatureRequired => '必修';

  @override
  String get courseNatureElective => '選修';

  @override
  String get homeMenuStatisticsTitle => '課程統計';

  @override
  String get statisticsTitle => '課程統計';

  @override
  String get statisticsOverview => '本週概覽';

  @override
  String get statisticsCourseCount => '課程門數';

  @override
  String get statisticsSectionCount => '本週課時';

  @override
  String get statisticsWeeklyCourses => '本週課程';

  @override
  String get statisticsDailyDistribution => '每日課時分佈';

  @override
  String get statisticsNatureRatio => '必修 / 選修';

  @override
  String get statisticsCourseList => '課程列表';

  @override
  String get statisticsSectionsUnit => '節';

  @override
  String get statisticsSectionUnit => '節';

  @override
  String get statisticsNoData => '暫無課程數據';

  @override
  String get statisticsCourseCountRatio => '門數比例';

  @override
  String get statisticsSectionCountRatio => '課時比例';

  @override
  String statisticsWeekSelector(int week) {
    return '第 $week 週';
  }

  @override
  String get statisticsStoryBusiestDayTitle => '最忙的一天';

  @override
  String statisticsStoryBusiestDayContent(int week, String day, String avg) {
    return '截至第$week週，這學期你最忙的一天是 **$day**，平均 **$avg** 節課';
  }

  @override
  String get statisticsStoryLightestDayTitle => '最輕鬆的一天';

  @override
  String statisticsStoryLightestDayContent(int week, String day, String avg) {
    return '截至第$week週，你最輕鬆的一天是 **$day**，只有 **$avg** 節課';
  }

  @override
  String get statisticsStoryFavoriteRoomTitle => '最常去的教室';

  @override
  String statisticsStoryFavoriteRoomContent(int week, String room, int count) {
    return '截至第$week週，你最常去的教室是 **$room**，共去了 **$count** 次';
  }

  @override
  String get statisticsStoryBuildingCountTitle => '教學樓探險';

  @override
  String statisticsStoryBuildingCountContent(int week, int count) {
    return '截至第$week週，你的課程分佈在 **$count** 棟不同的教學樓';
  }

  @override
  String get statisticsStoryTimeRangeTitle => '時間跨度';

  @override
  String statisticsStoryTimeRangeContent(String earliest, String latest) {
    return '你最早的課是 **$earliest**，最晚的課是 **$latest**';
  }

  @override
  String get statisticsSemesterLabelCourses => '門課程';

  @override
  String get statisticsSemesterLabelSections => '節課';

  @override
  String get statisticsSemesterLabelWeeks => '週';

  @override
  String get statisticsSemesterLabelDayStreak => '天連續';

  @override
  String get statisticsAchievementsTitle => '成就徽章';

  @override
  String get statisticsStoriesTitle => '數據故事';

  @override
  String get statisticsRankingTitle => '課程排行';

  @override
  String get statisticsNoDataHint => '添加課程後即可查看統計';

  @override
  String get statisticsShareLabel => '分享統計';

  @override
  String get statisticsExportTitle => '匯出統計';

  @override
  String get statisticsExportModulesSection => '包含模組';

  @override
  String get statisticsExportFormatSection => '匯出格式';

  @override
  String get statisticsExportFormatImage => '長圖 (PNG)';

  @override
  String get statisticsExportFormatPdf => 'PDF 文件';

  @override
  String get statisticsExportAction => '開始匯出';

  @override
  String get statisticsExportSelectModuleHint => '請至少選擇一個模組';

  @override
  String get statisticsExportModuleOverview => '學期總覽';

  @override
  String get statisticsExportBrandTagline => '把課程資訊做成系統體驗';

  @override
  String statisticsExportGithubHint(String url) {
    return 'GitHub 搜尋專案：$url';
  }

  @override
  String get statisticsExportQrScanHint => '掃碼造訪官網';

  @override
  String statisticsExportRankingMore(int count) {
    return '另有 $count 門課程未展示';
  }

  @override
  String get statisticsShareTitle => '我的學期統計';

  @override
  String statisticsRankingSlotDetail(
    String day,
    int startSection,
    int endSection,
  ) {
    return '$day 第$startSection-$endSection節';
  }

  @override
  String get statisticsAchievementEarlyBirdName => '早八戰士';

  @override
  String get statisticsAchievementEarlyBirdDescription => '有 8:00 的課，真棒！';

  @override
  String get statisticsAchievementPerfectAttendanceName => '全勤達人';

  @override
  String get statisticsAchievementPerfectAttendanceDescription => '某門課每週都有';

  @override
  String get statisticsAchievementWeekendWarriorName => '週末戰士';

  @override
  String get statisticsAchievementWeekendWarriorDescription => '週末有課';

  @override
  String get statisticsAchievementClassKingName => '課王';

  @override
  String get statisticsAchievementClassKingDescription => '某天 ≥ 6 節課';

  @override
  String get statisticsAchievementScholarName => '學霸';

  @override
  String get statisticsAchievementScholarDescription => '總課時 ≥ 100';

  @override
  String get statisticsAchievementBalancedName => '均衡大師';

  @override
  String get statisticsAchievementBalancedDescription => '每天課時差距 ≤ 2';

  @override
  String get statisticsAchievementNightOwlName => '夜貓子';

  @override
  String get statisticsAchievementNightOwlDescription => '有 18:00 以後的課';

  @override
  String get statisticsAchievementExplorerName => '教室探索家';

  @override
  String get statisticsAchievementExplorerDescription => '使用過 ≥ 5 個不同教室';

  @override
  String statisticsNatureLegendDetail(int count, int sections) {
    return '$count 門 · $sections 節';
  }

  @override
  String get statisticsWeekCurrentHint => '本週';

  @override
  String get weeklyReportTitle => '本週課程小結';

  @override
  String weeklyReportBody(
    int week,
    int sections,
    int courses,
    String delta,
    String busiestDay,
  ) {
    return '第$week週 · 共$sections節 · $courses門課\n較上週 $delta 節\n最忙的一天是 $busiestDay';
  }

  @override
  String get weeklyReportBodyEmpty => '本週暫無課程，好好休息吧';

  @override
  String weeklyReportNextFire(String date, String time) {
    return '下次推送 $date $time';
  }

  @override
  String get weeklyReportEnabledHint => '已開啟每週週報推送';

  @override
  String get weeklyReportDisabledHint => '已關閉每週週報推送';

  @override
  String get statisticsCompareTitle => '課表對比';

  @override
  String get statisticsCompareActive => '當前課表';

  @override
  String get statisticsCompareNone => '暫無其他課表，可在課表管理中新建';

  @override
  String statisticsCompareDelta(String delta) {
    return '較當前 $delta 節';
  }

  @override
  String get statisticsCompareDetailTitle => '課表對比詳情';

  @override
  String get statisticsCompareWeek => '當前週';

  @override
  String get statisticsMoreTitle => '深度分析';

  @override
  String get statisticsMoreGroupTrend => '趨勢 · 分佈';

  @override
  String get statisticsMoreGroupPeople => '教室 · 教師 · 排行';

  @override
  String get statisticsNatureNoneRequired => '暫無必修';

  @override
  String get statisticsNatureNoneElective => '暫無選修';

  @override
  String get statisticsAchievementMorningPersonName => '早起鳥';

  @override
  String get statisticsAchievementMorningPersonDescription => '早間課時佔比 ≥ 50%';

  @override
  String get statisticsAchievementGapMasterName => '時間管理大師';

  @override
  String get statisticsAchievementGapMasterDescription => '最長課間空檔 ≤ 2 節';

  @override
  String get statisticsAchievementEarlyBirdDetail =>
      '解鎖條件：課表中有 08:00 或更早開始的課程。';

  @override
  String get statisticsAchievementPerfectAttendanceDetail =>
      '解鎖條件：至少一門課程在開課週期內每週都有課（無停課、無單雙週跳課）。';

  @override
  String get statisticsAchievementWeekendWarriorDetail => '解鎖條件：週末（週六或週日）有課。';

  @override
  String get statisticsAchievementClassKingDetail => '解鎖條件：某一天排課達到 6 節及以上。';

  @override
  String get statisticsAchievementScholarDetail => '解鎖條件：學期累計課時達到 100 節。';

  @override
  String get statisticsAchievementBalancedDetail =>
      '解鎖條件：每天課時差距不超過 2 節，課表安排均衡。';

  @override
  String get statisticsAchievementNightOwlDetail => '解鎖條件：有 18:00 以後才結束的課。';

  @override
  String get statisticsAchievementExplorerDetail => '解鎖條件：使用過 5 個及以上不同的教室。';

  @override
  String get statisticsAchievementFullDayKingDetail =>
      '解鎖條件：某一天排課達到 8 節及以上，全天滿課。';

  @override
  String get statisticsAchievementBuildingHopperDetail =>
      '解鎖條件：同一天內去過 3 棟及以上不同的教學樓。';

  @override
  String get statisticsAchievementMorningPersonDetail =>
      '解鎖條件：早間（12:00 前開始）課時佔總課時的一半以上。';

  @override
  String get statisticsAchievementGapMasterDetail =>
      '解鎖條件：每天課間最長空檔不超過 2 節，時間安排緊湊。';

  @override
  String get statisticsAchievementDetailConfirm => '知道了';

  @override
  String get statisticsAchievementLocked => '未達成';

  @override
  String get statisticsSettingsTitle => '統計設定';

  @override
  String get statisticsTabSemester => '學期';

  @override
  String get statisticsTabWeek => '週';

  @override
  String get statisticsSemesterProgressTitle => '學期進度';

  @override
  String statisticsSemesterProgressRange(String start, String end) {
    return '學期 $start - $end';
  }

  @override
  String statisticsSemesterProgressAsOf(String date) {
    return '今天 $date';
  }

  @override
  String statisticsSemesterProgressDetail(int week, int done, int total) {
    return '截至第 $week 週，已上 $done 節 / 共 $total 節';
  }

  @override
  String statisticsSemesterProgressRemaining(int count) {
    return '剩餘 $count 節';
  }

  @override
  String get statisticsSemesterProgressNotStarted => '還未開學，尚未上課';

  @override
  String get statisticsSemesterProgressEstimated => '按週估算';

  @override
  String get statisticsTrendTitle => '每週課時趨勢';

  @override
  String statisticsTrendTooltip(int week, int sections) {
    return '第 $week 週 · $sections 節';
  }

  @override
  String get statisticsComparisonTitle => '本週小結';

  @override
  String get statisticsComparisonLastWeek => '上週課時';

  @override
  String get statisticsComparisonAverage => '學期週均';

  @override
  String statisticsComparisonVsLastWeek(String delta) {
    return '較上週 $delta 節';
  }

  @override
  String statisticsComparisonVsAverage(String delta) {
    return '較週均 $delta 節';
  }

  @override
  String get statisticsComparisonNew => '新學期第一週';

  @override
  String get statisticsHeatmapTitle => '學期熱力圖';

  @override
  String get statisticsHeatmapHint => '顏色越深，課時越多';

  @override
  String get statisticsTimeUtilTitle => '時間利用';

  @override
  String get statisticsTimeEarliest => '最早課';

  @override
  String get statisticsTimeLatest => '最晚課';

  @override
  String get statisticsTimeMorning => '早間課時';

  @override
  String get statisticsTimeNoon => '午間課時';

  @override
  String get statisticsTimeEvening => '晚間課時';

  @override
  String get statisticsTimeWeekend => '週末課時';

  @override
  String get statisticsTimeGap => '最長課間空檔';

  @override
  String statisticsTimeGapValue(int sections) {
    return '$sections 節';
  }

  @override
  String get statisticsVenueTitle => '教室與教學樓';

  @override
  String get statisticsVenueTopRooms => '常去教室';

  @override
  String get statisticsVenueBuildings => '教學樓課時';

  @override
  String statisticsVenueVisits(int count) {
    return '$count 次';
  }

  @override
  String get statisticsTeacherTitle => '教師課時排行';

  @override
  String statisticsTeacherCourseCount(int count) {
    return '$count 門課';
  }

  @override
  String get statisticsAchievementFullDayKingName => '滿課日之王';

  @override
  String get statisticsAchievementFullDayKingDescription => '單日 ≥ 8 節課';

  @override
  String get statisticsAchievementBuildingHopperName => '跨樓達人';

  @override
  String get statisticsAchievementBuildingHopperDescription => '單日跨 ≥ 3 棟教學樓';

  @override
  String statisticsAchievementProgress(int current, int target) {
    return '$current/$target';
  }

  @override
  String get statisticsAchievementDone => '已達成';

  @override
  String statisticsWeekDailyHint(int week) {
    return '點擊查看第 $week 週詳情';
  }

  @override
  String get weekListSeparator => '、';

  @override
  String courseWeekListLabel(String weeks) {
    return '第$weeks周';
  }

  @override
  String courseWeekRangeLabel(int startWeek, int endWeek, String mode) {
    return '第$startWeek-$endWeek周$mode';
  }

  @override
  String courseWeekSuspendedLabel(String weeks) {
    return '第$weeks周停課';
  }

  @override
  String get importSemesterStartDateTitle => '開學日期';

  @override
  String get importSemesterStartDateSubtitle => '按這一天所在週作為校曆第 1 週';

  @override
  String get importFirstCourseWeekMappingLabel => '課表第 1 週對應校曆第幾週';

  @override
  String get importFirstCourseWeekMappingSubtitle =>
      '如果學校第一週沒課，就選第 2 週；前兩週都沒課就選第 3 週';

  @override
  String get importSemesterMappingNoShiftHint => '匯入後會直接把課表第 1 週當作校曆第 1 週';

  @override
  String importSemesterMappingShiftHint(int shiftedWeeks, int calendarWeek) {
    return '匯入後會把所有課程週次整體順延 $shiftedWeeks 週，讓課表第 1 週落在校曆第 $calendarWeek 週';
  }

  @override
  String calendarWeekOption(int week) {
    return '校曆第 $week 週';
  }

  @override
  String get aboutDownloadPackageMethodTitle => '下載安裝包方式';

  @override
  String get aboutInAppDownloadTitle => '應用內下載';

  @override
  String get aboutInAppDownloadSubtitle => '下載完成後直接在應用內安裝';

  @override
  String get aboutSystemDownloaderTitle => '系統管理器';

  @override
  String get aboutSystemDownloaderChoiceSubtitle => '交給系統下載管理器處理';

  @override
  String get syncErrorAuthFailed => '帳號或密碼錯誤';

  @override
  String get syncErrorAccessDenied => '沒有存取權限';

  @override
  String get syncErrorCertificateError => '憑證校驗失敗';

  @override
  String get syncErrorConnectionTimeout => '連線逾時';

  @override
  String get syncErrorConnectionFailed => '無法連線伺服器';

  @override
  String get syncErrorNetworkError => '網路異常';

  @override
  String get syncErrorInvalidResponse => '伺服器回應無效';

  @override
  String get syncErrorLocalChangesPendingSync => '本機有未同步修改，已跳過自動覆蓋';

  @override
  String get syncErrorMissingCredentials => '請先設定雲同步帳號';

  @override
  String get syncErrorBackupNotFound => '備份不存在';

  @override
  String get syncErrorMissingBackupSnapshot => '備份快照缺失';

  @override
  String get syncErrorCannotDeleteCurrentBackup => '不能刪除目前備份';

  @override
  String get syncErrorProviderNotReady => '課表尚未就緒';

  @override
  String get syncErrorInsecureUrl => '僅支援 HTTPS 加密連線，HTTP 明文協定已被停用';

  @override
  String get syncErrorSyncFailed => '同步失敗';

  @override
  String get sectionTimeDisplayHidden => '不顯示';

  @override
  String get sectionTimeDisplayStartOnly => '僅顯示上課時間';

  @override
  String get sectionTimeDisplayStartAndEnd => '顯示上下課時間';

  @override
  String get examReminderNone => '不提醒';

  @override
  String get examReminderMin30 => '考前 30 分鐘';

  @override
  String get examReminderHour1 => '考前 1 小時';

  @override
  String get examReminderHour1AndMin30 => '考前 1 小時 + 30 分鐘';

  @override
  String get examReminderDay1 => '考前 1 天';

  @override
  String get examReminderDay1AndHour1 => '考前 1 天 + 1 小時';

  @override
  String get examReminderCustom => '自定義';

  @override
  String examReminderOffsetMinutes(int minutes) {
    return '考前 $minutes 分鐘';
  }

  @override
  String examReminderOffsetHours(int hours) {
    return '考前 $hours 小時';
  }

  @override
  String examReminderOffsetDays(int days) {
    return '考前 $days 天';
  }

  @override
  String get examReminderCustomEmpty => '請至少選擇一個提醒時間';

  @override
  String get examReminderAddCustom => '添加提醒';

  @override
  String get examReminderAddCustomTitle => '自定義提醒時間';

  @override
  String get examReminderAddCustomHint => '設置距離考試開始前多久提醒，可添加多個';

  @override
  String get examReminderPickerDays => '天';

  @override
  String get examReminderPickerHours => '小時';

  @override
  String get examReminderPickerMinutes => '分鐘';

  @override
  String get examReminderCustomAlreadyAdded => '該提醒時間已添加';

  @override
  String get examReminderCustomInvalid => '請設置大于 0 的提醒時間';

  @override
  String get examReminderCustomEmptyHint => '還没有自定義提醒，點下方添加';

  @override
  String get debugCopiedJson => '已複製 JSON';

  @override
  String get liveDuringClassTimeNearest => '最近時間';

  @override
  String get liveDuringClassTimeTotal => '總時間';

  @override
  String get liveCountdownTextStyleSmart => '智能（中文）';

  @override
  String get liveCountdownTextStyleSmartMinS => '智能（英文）';

  @override
  String get liveCountdownTextStyleMinuteSecondCn => '分秒（5分鐘19秒）';

  @override
  String get liveCountdownTextStyleMinuteSecondColon => 'mm:ss（05:19）';

  @override
  String get liveCountdownTextStyleMinuteSecondMinS => 'min+s（5min19s）';

  @override
  String get liveCountdownTextStyleMinuteSecondMinSlashS => 'min/s（5min/19s）';

  @override
  String get liveCountdownTextStyleMinuteOnlyCn => '純分鐘（5分鐘）';

  @override
  String get liveCountdownTextStyleMinuteOnlyMin => 'min（5min）';

  @override
  String get liveCountdownTextStyleMinuteOnlySlash => '/min（5/min）';

  @override
  String get liveCountdownTextStyleSecondOnlyCn => '純秒（5秒）';

  @override
  String get liveCountdownTextStyleSecondOnlyShort => 's（5s）';

  @override
  String get liveCountdownTextStyleSecondOnlySlash => '/s（5/s）';

  @override
  String get miuiIslandLabelStyleTextOnly => '僅文字';

  @override
  String get miuiIslandLabelStyleIconAndText => '圖標+文字';

  @override
  String get miuiIslandLabelContentCourseName => '課程名';

  @override
  String get miuiIslandLabelContentLocation => '教室';

  @override
  String get miuiIslandLabelContentCourseNameAndLocation => '課程名+教室';

  @override
  String get miuiIslandLabelFontWeightRegular => '常規';

  @override
  String get miuiIslandLabelFontWeightMedium => '中等';

  @override
  String get miuiIslandLabelFontWeightBold => '加粗';

  @override
  String get miuiIslandLabelRenderQualityStandard => '標準';

  @override
  String get miuiIslandLabelRenderQualityHigh => '高清';

  @override
  String get miuiIslandLabelRenderQualityUltra => '超高清';

  @override
  String get miuiIslandExpandedIconAppIcon => '應用圖標';

  @override
  String get miuiIslandExpandedIconCustomImage => '自定義圖片';

  @override
  String get miuiIslandExpandedIconHidden => '不顯示';

  @override
  String get liveBeforeClassQuickActionNone => '不顯示';

  @override
  String get liveBeforeClassQuickActionSilent => '打開靜音';

  @override
  String get liveBeforeClassQuickActionDoNotDisturb => '打開免打擾';

  @override
  String get liveBeforeClassQuickActionBoth => '靜音和免打擾';

  @override
  String get courseCardVerticalAlignTop => '頂部對齊';

  @override
  String get courseCardVerticalAlignCenter => '垂直居中';

  @override
  String get courseCardVerticalAlignBottom => '底部對齊';

  @override
  String get courseCardVerticalAlignSpaceEvenly => '上下均布';

  @override
  String get courseCardHorizontalAlignLeft => '居左';

  @override
  String get courseCardHorizontalAlignCenter => '居中';

  @override
  String get courseCardHorizontalAlignRight => '居右';

  @override
  String get timetableTimeColumnWidthNarrow => '窄';

  @override
  String get timetableTimeColumnWidthWide => '宽';

  @override
  String get timetableCourseSpacingNarrow => '窄';

  @override
  String get timetableCourseSpacingWide => '宽';

  @override
  String get appUpdateDownloadSourceOriginal => 'GitHub 原版';

  @override
  String get appUpdateDownloadSourceMirror => '國內镜像';

  @override
  String get appUpdateDownloadChannelPgyer => '蒲公英下載';

  @override
  String get appUpdateDownloadChannelGithub => 'GitHub 下載';

  @override
  String get appUpdateDownloadChannelPgyerDescription => '國內高速下載，推薦使用';

  @override
  String get appUpdateDownloadChannelGithubDescription => 'GitHub 原生 + 國內镜像';

  @override
  String get appUpdateDownloadChannelGitcode => 'GitCode 直連';

  @override
  String get appUpdateDownloadChannelGitcodeDescription =>
      'GitCode 發行版直連下載，國內速度快';

  @override
  String get holidayStatutoryLabel => '法定假日';

  @override
  String get serviceMsgImportFileUnrecognized =>
      'Import failed. The file content could not be recognized.';

  @override
  String get serviceMsgImportUseOverwriteForFullBackup =>
      'This is a full data backup. Please import using overwrite current timetable.';

  @override
  String get serviceMsgImportNoProfilesInBackup =>
      'No recoverable timetables were found in the backup file.';

  @override
  String get serviceMsgUnrecognizedMikcbDataFile =>
      'Not a recognizable mikcb data file.';

  @override
  String get serviceMsgMissingSettingsData => 'Settings data is missing.';

  @override
  String get serviceMsgUnrecognizedMikcbFullBackup =>
      'Not a recognizable mikcb full backup file.';

  @override
  String get serviceMsgMissingFullBackupData =>
      'Complete backup data is missing.';

  @override
  String get serviceMsgUseProfileBackupNotFull =>
      'Use a timetable profile backup JSON, not a full data backup.';

  @override
  String get serviceMsgUnrecognizedSyncSnapshot =>
      'Not a recognizable mikcb cloud sync snapshot.';

  @override
  String get serviceMsgMissingSyncTimetableData =>
      'Cloud sync timetable data is missing.';

  @override
  String get serviceMsgSyncSnapshotChecksumFailed =>
      'Cloud sync snapshot verification failed.';

  @override
  String get serviceMsgSyncSnapshotNoProfiles =>
      'No recoverable timetables in the cloud sync snapshot.';

  @override
  String get serviceMsgSyncSnapshotUnrecognized =>
      'Cloud sync snapshot could not be recognized.';

  @override
  String get serviceMsgTimeSchemeNotFound => 'Time scheme not found.';

  @override
  String get serviceMsgTimeSchemeConfigUnavailable =>
      'Current timetable time configuration is unavailable.';

  @override
  String get serviceMsgTimeSchemeNotFoundSelected =>
      'Selected time scheme was not found.';

  @override
  String serviceMsgTimeSchemeSectionsInsufficient(
    int startSection,
    int endSection,
  ) {
    return 'Selected time scheme does not have enough sections for sections $startSection-$endSection.';
  }

  @override
  String serviceMsgSectionCountBelowUsage(int requiredMaxSection) {
    return '有課排到第$requiredMaxSection節';
  }

  @override
  String serviceMsgSectionCountBelowUsageDetail(
    int requiredMaxSection,
    String profileName,
    String courseName,
    int dayOfWeek,
    int startSection,
    int endSection,
    String usageType,
  ) {
    return 'Section count cannot be less than the maximum section in use (section $requiredMaxSection). In use: $profileName · $courseName (weekday $dayOfWeek sections $startSection-$endSection, $usageType)';
  }

  @override
  String get serviceMsgAtLeastOneSectionRequired =>
      'At least one section time must be kept.';

  @override
  String serviceMsgSectionEndMustAfterStart(int sectionNumber) {
    return 'Section $sectionNumber end time must be later than start time. Overnight classes are not supported.';
  }

  @override
  String serviceMsgSectionStartBeforePreviousEnd(int sectionNumber) {
    return 'Section $sectionNumber start time cannot be earlier than the previous section end time.';
  }

  @override
  String get serviceMsgPeriodStartTimeRequired =>
      'Set the first section start time for periods that have sections.';

  @override
  String serviceMsgSectionCrossesMidnight(int sectionNumber) {
    return 'Section $sectionNumber would cross midnight. Overnight classes are not supported.';
  }

  @override
  String get serviceMsgClassDurationMustPositive =>
      'Class duration must be greater than 0.';

  @override
  String get serviceMsgBreakDurationMustNonNegative =>
      'Break duration cannot be less than 0.';

  @override
  String get serviceMsgAtLeastOnePeriodSection =>
      'At least one period must have sections.';

  @override
  String get serviceMsgInvalidTimeFormat => 'Time format is invalid.';

  @override
  String get serviceMsgLinkedCourseNotFound => 'Linked course was not found.';

  @override
  String get serviceMsgCourseNotFoundForDelete =>
      'Course to delete was not found.';

  @override
  String serviceMsgCourseNotScheduledWeek(int sourceWeek) {
    return 'This course is not scheduled in week $sourceWeek.';
  }

  @override
  String get serviceMsgCourseNotFoundForReschedule =>
      'Course to reschedule was not found.';

  @override
  String get serviceMsgTargetWeekOutOfRange =>
      'Target week is outside the current semester range.';

  @override
  String get serviceMsgAtLeastOneScheduleSlot =>
      'At least one class time slot must be kept.';

  @override
  String get serviceMsgCourseNameRequired => 'Course name cannot be empty.';

  @override
  String get serviceMsgBackupContentRequired =>
      'Backup content cannot be empty.';

  @override
  String get serviceMsgSpreadsheetFormatOrEncodingUnrecognized =>
      'Could not recognize spreadsheet format or encoding. Save CSV as UTF-8 and try again.';

  @override
  String serviceMsgSpreadsheetXlsxParseFailed(String error) {
    return 'Failed to parse XLSX file: $error';
  }

  @override
  String serviceMsgSpreadsheetRowWarning(int rowNumber, String message) {
    return 'Row $rowNumber: $message';
  }

  @override
  String serviceMsgSpreadsheetWakeupInsufficientColumns(
    int rowNumber,
    int columnCount,
  ) {
    return 'WakeUp format needs at least 7 columns, but row $rowNumber has only $columnCount.';
  }

  @override
  String get serviceMsgWeekdayMustBe1To7 => 'Weekday must be between 1 and 7.';

  @override
  String get serviceMsgCustomWeeksRequired => 'Weeks cannot be empty.';

  @override
  String get serviceMsgClassWeeksRequired => 'Class weeks cannot be empty.';

  @override
  String get serviceMsgStartWeekMustBeAtLeast1 =>
      'Start week must be at least 1.';

  @override
  String serviceMsgStartWeekExceedsSemester(
    int startWeek,
    int semesterWeekCount,
  ) {
    return 'Start week $startWeek exceeds semester week count $semesterWeekCount.';
  }

  @override
  String get serviceMsgEndWeekBeforeStartWeek =>
      'End week cannot be earlier than start week.';

  @override
  String get serviceMsgWeeksRangeRequired =>
      'Class weeks or start week + end week must be provided.';

  @override
  String serviceMsgFieldMustBeAtLeast1(String field) {
    return '$field must be at least 1.';
  }

  @override
  String serviceMsgFieldCannotBeLessThan(String startField, String endField) {
    return '$endField cannot be less than $startField.';
  }

  @override
  String serviceMsgSectionOutOfRange(int section, int maxSection) {
    return 'Section $section is outside the time scheme range (1-$maxSection).';
  }

  @override
  String serviceMsgFieldMustBeInteger(String field) {
    return '$field must be an integer.';
  }

  @override
  String serviceMsgFieldCannotBeEmpty(String field) {
    return '$field cannot be empty.';
  }

  @override
  String serviceMsgSpreadsheetEndWeekClamped(
    int rowNumber,
    int endWeek,
    int semesterWeekCount,
  ) {
    return 'Row $rowNumber: end week $endWeek exceeds semester week count $semesterWeekCount; adjusted to $semesterWeekCount.';
  }

  @override
  String serviceMsgSpreadsheetOddEvenBoth(int rowNumber) {
    return 'Row $rowNumber: odd and even weeks cannot both be selected; treated as odd weeks.';
  }

  @override
  String get serviceMsgFieldCourseName => 'Course name';

  @override
  String get serviceMsgFieldWeekday => 'Weekday';

  @override
  String get serviceMsgFieldStartSection => 'Start section';

  @override
  String get serviceMsgFieldEndSection => 'End section';

  @override
  String get serviceMsgFieldCustomWeeks => 'Weeks';

  @override
  String get serviceMsgFieldClassWeeks => 'Class weeks';

  @override
  String get serviceMsgFieldStartWeek => 'Start week';

  @override
  String get serviceMsgFieldEndWeek => 'End week';

  @override
  String serviceMsgWeekStartInvalid(String itemName) {
    return '$itemName: week range start is invalid.';
  }

  @override
  String serviceMsgWeekRangeInvalid(String itemName) {
    return '$itemName: week range is invalid.';
  }

  @override
  String serviceMsgWeekRangeTooLarge(String itemName) {
    return '$itemName: week range is too large. Please check.';
  }

  @override
  String serviceMsgWeekTokenUnrecognized(String itemName, String token) {
    return '$itemName: unrecognized week token: $token';
  }

  @override
  String serviceMsgWeeksExceedSemesterClamped(
    String itemName,
    int semesterWeekCount,
    String weeks,
  ) {
    return '$itemName contains weeks beyond semester week count $semesterWeekCount ($weeks); excess weeks were ignored.';
  }

  @override
  String get serviceMsgAiResultNotObject =>
      'AI result is not a valid JSON object. Copy the full JSON again.';

  @override
  String serviceMsgAiSchemaMustBe(String schema) {
    return 'schema must be $schema';
  }

  @override
  String get serviceMsgAiCoursesMustBeArray => 'courses must be an array.';

  @override
  String get serviceMsgAiWarningsMustBeArray =>
      'warnings must be a string array.';

  @override
  String get serviceMsgAiWarningItemMustBeString =>
      'Each warnings item must be a string.';

  @override
  String serviceMsgAiCourseNotObject(int index) {
    return 'courses[$index] is not a valid object.';
  }

  @override
  String serviceMsgAiCourseNameEmpty(int index) {
    return 'courses[$index].name cannot be empty.';
  }

  @override
  String serviceMsgAiCourseDayOfWeekInvalid(int index) {
    return 'courses[$index].dayOfWeek must be between 1 and 7.';
  }

  @override
  String serviceMsgAiCourseStartSectionInvalid(int index) {
    return 'courses[$index].startSection must be at least 1.';
  }

  @override
  String serviceMsgAiCourseEndSectionInvalid(int index) {
    return 'courses[$index].endSection cannot be less than startSection.';
  }

  @override
  String serviceMsgAiCourseCustomWeeksEmpty(int index) {
    return 'courses[$index].customWeeks cannot be empty.';
  }

  @override
  String serviceMsgAiCourseNatureInvalid(int index) {
    return 'courses[$index].courseNature must be required or elective.';
  }

  @override
  String serviceMsgAiUnknownFields(String targetName, String fields) {
    return '$targetName contains unsupported fields: $fields';
  }

  @override
  String serviceMsgAiFieldMustBeString(String field) {
    return '$field must be a string.';
  }

  @override
  String serviceMsgAiFieldMustBeInteger(String field) {
    return '$field must be an integer.';
  }

  @override
  String serviceMsgAiWeekListInvalid(String itemName) {
    return '$itemName can only contain integers greater than or equal to 1.';
  }

  @override
  String serviceMsgAiWeekListTypeInvalid(String field) {
    return '$field must be an integer array or week string.';
  }

  @override
  String get serviceMsgNoReleaseAvailable =>
      'No release has been published yet.';

  @override
  String get serviceMsgNoReleaseWithPrerelease =>
      'No stable or prerelease version is available yet.';

  @override
  String serviceMsgUpdateCheckHttpFailed(int statusCode) {
    return 'Update check failed (HTTP $statusCode).';
  }

  @override
  String get serviceMsgUpdateCheckNetworkFailed =>
      'Network error. Unable to check for updates right now.';

  @override
  String get serviceMsgUpdateDownloadHashMismatch =>
      '安裝包校驗失敗，為防止安裝被篡改的文件已取消本次更新';

  @override
  String get serviceMsgUpdateSha256UnverifiedRefused =>
      '無法校驗安裝包完整性（缺少官方 SHA-256），已取消應用內更新，請前往發佈頁手動下載';

  @override
  String get serviceMsgUpdateDownloadUrlUntrusted =>
      'Update download URL failed security validation.';

  @override
  String serviceMsgUpdateDownloadHttpFailed(int statusCode) {
    return 'Download failed (HTTP $statusCode).';
  }

  @override
  String serviceMsgUpdateOpenInstallerFailed(String detail) {
    return 'Failed to open installer: $detail';
  }

  @override
  String serviceMsgUpdateDownloadInstallError(String detail) {
    return 'Download or installation error: $detail';
  }

  @override
  String get serviceMsgInvalidUrl => 'Invalid URL.';

  @override
  String get serviceMsgUpdateAvailablePrerelease =>
      'A new prerelease version is available.';

  @override
  String get serviceMsgUpdateAvailable => 'A new version is available.';

  @override
  String get serviceMsgAlreadyLatest =>
      'You are already on the latest version.';

  @override
  String get serviceMsgShareBackupText =>
      'This is a full backup of the current timetable. Import it to restore courses and settings.';

  @override
  String get serviceMsgShareBackupSubject => 'Qingyu Timetable backup';

  @override
  String serviceMsgShareBackupSubjectNamed(String profileName) {
    return '$profileName - Qingyu Timetable backup';
  }

  @override
  String get serviceMsgShareFullBackupText =>
      'This is a full data backup containing all timetables, the active timetable, and time schemes.';

  @override
  String get serviceMsgShareFullBackupSubject =>
      'Qingyu Timetable - full data backup';

  @override
  String get serviceMsgInvalidRepositoryUrl =>
      'Repository URL format is invalid.';

  @override
  String get serviceMsgIncompleteGithubRepoUrl =>
      'GitHub repository URL is incomplete.';

  @override
  String get serviceMsgIncompleteRawGithubUrl =>
      'raw.githubusercontent.com URL is incomplete.';

  @override
  String get serviceMsgGithubOnlySupported =>
      'Only GitHub repository URLs are supported.';

  @override
  String get serviceMsgWarehouseNoSchoolsIndex =>
      'No school or tool index was found.';

  @override
  String serviceMsgWarehouseNoAdapters(String schoolName) {
    return 'No adapter information was found for $schoolName.';
  }

  @override
  String serviceMsgWarehouseFetchFailedMirror(int candidatesCount) {
    return 'Unable to read the adapter repository. Tried $candidatesCount mirror endpoints. Check your network or switch mirror in Version Update.';
  }

  @override
  String get serviceMsgWarehouseFetchFailedGithub =>
      'Unable to read the adapter repository on GitHub. Check your network or switch to a mirror in Version Update.';

  @override
  String get serviceMsgWarehouseScriptChecksumFailed =>
      'Adapter script integrity check failed: downloaded content does not match the repository\'s declared SHA-256, so execution was blocked. Refresh the school list and try again; if it keeps happening, report the adapter to qingyu_warehouse.';

  @override
  String get serviceMsgManualInputCaptcha =>
      'Enter the captcha manually, then tap Continue.';

  @override
  String get serviceMsgManualInputPassword =>
      'Enter the password manually. If it was auto-filled, tap Continue.';

  @override
  String get serviceMsgMacroNoSteps => 'No recorded steps.';

  @override
  String get serviceMsgMacroUserCancelled => 'Cancelled by user.';

  @override
  String serviceMsgMacroStepFailed(
    int stepIndex,
    int totalSteps,
    String detail,
  ) {
    return 'Step $stepIndex/$totalSteps failed: $detail';
  }

  @override
  String get serviceMsgMacroNavigateUrlEmpty => 'Navigation URL is empty.';

  @override
  String serviceMsgMacroNavigateUrlInvalid(String url) {
    return 'Invalid URL: $url';
  }

  @override
  String get serviceMsgMacroFillSelectorEmpty =>
      'Fill-field selector is empty.';

  @override
  String serviceMsgMacroElementNotFound(String selector) {
    return 'Element not found: $selector';
  }

  @override
  String get serviceMsgMacroClickSelectorEmpty => 'Click selector is empty.';

  @override
  String get serviceMsgMacroUrlPatternEmpty => 'URL pattern is empty.';

  @override
  String get serviceMsgMacroWaitSelectorEmpty => 'Wait selector is empty.';

  @override
  String get serviceMsgMacroManualInputDefault => 'Manual action required.';

  @override
  String serviceMsgMacroPollTimeout(
    String stepLabel,
    int timeoutSeconds,
    String lastError,
  ) {
    return '$stepLabel timed out (${timeoutSeconds}s)$lastError';
  }

  @override
  String get serviceMsgMacroReplayNavigate => 'Navigating…';

  @override
  String get serviceMsgMacroReplayFillField => 'Filling form…';

  @override
  String get serviceMsgMacroReplayClick => 'Clicking…';

  @override
  String get serviceMsgMacroReplayWaitUrl => 'Waiting for navigation…';

  @override
  String get serviceMsgMacroReplayWaitSelector => 'Waiting for page element…';

  @override
  String get serviceMsgMacroReplayWaitManual => 'Waiting for user action…';

  @override
  String get serviceMsgMacroReplayExecuteScript => 'Running import script…';

  @override
  String get serviceMsgMacroReplayDelay => 'Waiting…';

  @override
  String serviceMsgMacroReplayFailed(String detail) {
    return 'Failed: $detail';
  }

  @override
  String serviceMsgMacroReplayPaused(String reason) {
    return 'Waiting for manual action: $reason';
  }

  @override
  String serviceMsgSupportDonorsLoadFailed(String detail) {
    return 'Failed to load supporters list: $detail';
  }

  @override
  String serviceMsgStatisticsShareFailed(String detail) {
    return 'Share failed: $detail';
  }

  @override
  String get serviceMsgAuthFailed => 'Invalid username or password.';

  @override
  String get serviceMsgAccessDenied => 'Access denied.';

  @override
  String get serviceMsgCertificateError => 'Certificate validation failed.';

  @override
  String get serviceMsgConnectionTimeout => 'Connection timed out.';

  @override
  String get serviceMsgConnectionFailed => 'Could not connect to the server.';

  @override
  String get serviceMsgInvalidResponse => 'Invalid server response.';

  @override
  String get serviceMsgSyncFailed => 'Sync failed.';

  @override
  String get serviceMsgUsageTypeOverride => 'override time scheme';

  @override
  String get serviceMsgUsageTypeProfile => 'profile main time scheme';

  @override
  String get dataTransferProfileShareText => '這是輕誘課表當前課表的完整備份文件，導入後可直接恢復課程和設置';

  @override
  String get dataTransferProfileShareSubject => '輕誘課表備份';

  @override
  String dataTransferProfileShareSubjectNamed(String profileName) {
    return '$profileName - 輕誘課表備份';
  }

  @override
  String get dataTransferFullBackupShareText =>
      '這是輕誘課表的全部數據備份文件，包含所有課表、當前選中課表和時間模板';

  @override
  String get dataTransferFullBackupShareSubject => '輕誘課表 - 全部數據備份';

  @override
  String courseWeekCustomDescription(String weeks) {
    return '第$weeks周';
  }

  @override
  String courseWeekRangeDescription(int startWeek, int endWeek, String mode) {
    return '第$startWeek-$endWeek周$mode';
  }

  @override
  String get courseWeekOddModeSuffix => ' 單周';

  @override
  String get courseWeekEvenModeSuffix => ' 雙周';

  @override
  String courseWeekSuspensionDescription(String weeks) {
    return '第$weeks周停課';
  }

  @override
  String get courseWeekListSeparator => '、';

  @override
  String holidayLogMemoryCacheHit(int year, int count) {
    return '$year年：命中內存緩存（$count 條），後台刷新中…';
  }

  @override
  String holidayLogLocalCacheHit(int year, int count) {
    return '$year年：命中本地緩存（$count 條），後台刷新中…';
  }

  @override
  String holidayLogNoCacheFetching(int year) {
    return '$year年：無緩存，正在拉取圓程數據…';
  }

  @override
  String holidayLogRemoteSuccess(int year, int count) {
    return '$year年：圓程拉取成功（$count 條），已緩存';
  }

  @override
  String holidayLogRemoteFailedBuiltin(int year) {
    return '$year年：圓程拉取失敗，使用內置資產兜底';
  }

  @override
  String holidayLogBuiltinLoaded(int year, int count) {
    return '$year年：加載內置資產（$count 條）';
  }

  @override
  String holidayLogBackgroundSuccess(int year, int count) {
    return '$year年：後台更新成功（$count 條），已覆蓋緩存';
  }

  @override
  String holidayLogBackgroundNoData(int year) {
    return '$year年：後台更新未获取到新數據';
  }

  @override
  String get holidayLogPrimaryApiFailed => '主 API 失敗，嘗試備用 API…';

  @override
  String holidayLogRequesting(String uri) {
    return '正在請求 $uri …';
  }

  @override
  String holidayLogPrimaryApiStatus(int statusCode) {
    return '主 API 响應 $statusCode，跳過';
  }

  @override
  String holidayLogPrimaryApiError(String message) {
    return '主 API 返回錯誤：$message';
  }

  @override
  String holidayLogPrimaryApiException(String error) {
    return '主 API 異常：$error';
  }

  @override
  String holidayLogPrimaryApiParsing(int count) {
    return '主 API 返回 $count 條原始數據，正在解析…';
  }

  @override
  String get holidayLogNoValidEntries => '解析後無有效條目，跳過';

  @override
  String holidayLogFallbackApiStatus(int statusCode) {
    return '備用 API 响應 $statusCode，跳過';
  }

  @override
  String get holidayLogFallbackApiError => '備用 API 返回錯誤';

  @override
  String holidayLogFallbackApiParsing(int count) {
    return '備用 API 返回 $count 條原始數據，正在解析…';
  }

  @override
  String holidayLogFallbackApiException(String error) {
    return '備用 API 異常：$error';
  }

  @override
  String get holidayNameNewYear => '元旦';

  @override
  String get holidayNameLaborDay => '勞動節';

  @override
  String get holidayNameNationalDay => '國慶節';

  @override
  String get holidayNameSpringFestival => '春節';

  @override
  String get holidayNameQingming => '清明節';

  @override
  String get holidayNameDragonBoat => '端午節';

  @override
  String get holidayNameMidAutumn => '中秋節';

  @override
  String macroReplayStatusFailed(String error) {
    return '失敗: $error';
  }

  @override
  String macroReplayStatusPaused(String reason) {
    return '等待手動操作: $reason';
  }

  @override
  String get macroReplayStepNavigating => '正在導航...';

  @override
  String get macroReplayStepFilling => '正在填充表單...';

  @override
  String get macroReplayStepClicking => '正在點擊...';

  @override
  String get macroReplayStepWaitUrl => '等待頁面跳轉...';

  @override
  String get macroReplayStepWaitSelector => '等待頁面元素...';

  @override
  String get macroReplayStepWaitManual => '等待用戶操作';

  @override
  String get macroReplayStepExecuteScript => '正在執行導入脚本...';

  @override
  String get macroReplayStepDelay => '等待中...';

  @override
  String get macroReplayAcceleratedFallbackTip => '快捷路徑失敗，正在使用完整錄制步晝重試…';

  @override
  String get macroReplayNoSteps => '没有錄制的步晝';

  @override
  String get macroReplayUserCancelled => '用戶取消';

  @override
  String macroReplayStepFailed(int current, int total, String error) {
    return '第 $current/$total 步失敗: $error';
  }

  @override
  String get macroReplayEmptyNavigateUrl => '導航 URL 為空';

  @override
  String macroReplayInvalidUrl(String url) {
    return '無效的 URL: $url';
  }

  @override
  String get macroReplayEmptyFillSelector => '填充字段的選擇器為空';

  @override
  String macroReplayFieldNotFound(String selector) {
    return '未找到表單字段: $selector';
  }

  @override
  String get macroReplayEmptyClickSelector => '點擊元素的選擇器為空';

  @override
  String macroReplayClickNotFound(String selector) {
    return '未找到點擊元素: $selector';
  }

  @override
  String macroReplayWaitUrlPattern(String pattern) {
    return '等待 URL 匹配: $pattern';
  }

  @override
  String get macroReplayEmptyWaitSelector => '等待元素的選擇器為空';

  @override
  String macroReplayWaitSelector(String selector) {
    return '等待元素: $selector';
  }

  @override
  String get macroReplayManualActionRequired => '需要手動操作';

  @override
  String macroReplayNavigateTo(String url) {
    return '導航到 $url';
  }

  @override
  String get macroReplayWaitPageLoad => '等待頁面加載';

  @override
  String get macroReplayWaitDomReady => '等待 DOM 就緒';

  @override
  String get hyperosShowcaseTitle => '澎湃 UI 組件庫';

  @override
  String get hyperosShowcaseSectionSummary => '概要卡片';

  @override
  String get hyperosShowcaseKitSubtitle => 'mikcb 澎湃風格組件一覽';

  @override
  String get hyperosShowcaseSectionTags => '標簽 / 手風琴 / 提示';

  @override
  String get hyperosShowcaseAccordionSection1 => '第一節';

  @override
  String get hyperosShowcaseAccordionSection1Body => '展開後顯示的內容區域';

  @override
  String get hyperosShowcaseAccordionSection2 => '第二節';

  @override
  String get hyperosShowcaseAccordionSection2Body => '可折疊分組，替代 FAccordion';

  @override
  String get hyperosShowcaseSectionNavRows => '列表行 · 導航';

  @override
  String get hyperosShowcaseNavRowWithIcon => '帶圖標';

  @override
  String get hyperosShowcaseNavRowNoIconSubtitle => '無左側彩圖標';

  @override
  String get hyperosShowcaseNavRowDetails => '詳情';

  @override
  String get hyperosShowcaseSectionSwitchRows => '列表行 · 開關 / 危险';

  @override
  String get hyperosShowcaseSwitchRowSubtitle => '帶圖標開關行';

  @override
  String get hyperosShowcaseSwitchRowPlain => '純文字開關行';

  @override
  String get hyperosShowcaseSectionChoiceRows => '列表行 · 單選 / 選擇 / 日期';

  @override
  String get hyperosShowcaseOptionA => '選項 A';

  @override
  String get hyperosShowcaseOptionB => '選項 B';

  @override
  String get hyperosShowcaseOptionC => '選項 C';

  @override
  String get hyperosShowcaseSelectSizeTitle => '選擇尺寸';

  @override
  String get hyperosShowcaseSizeSmall => '小';

  @override
  String get hyperosShowcaseSizeMedium => '中';

  @override
  String get hyperosShowcaseSizeLarge => '大';

  @override
  String get hyperosShowcaseSectionControls => '控件卡片';

  @override
  String get hyperosShowcaseControlsSubtitle => '滑條、分段、按钮';

  @override
  String get hyperosShowcaseSegmentLeft => '左';

  @override
  String get hyperosShowcaseSegmentRight => '右';

  @override
  String get hyperosShowcaseSectionInput => '輸入';

  @override
  String get hyperosShowcaseInputHint => '請輸入內容';

  @override
  String get hyperosShowcaseInputCardLabel => '卡片內輸入';

  @override
  String get hyperosShowcaseSectionPicker => '滾輪選擇器';

  @override
  String hyperosShowcasePickerCurrentValue(int value) {
    return '當前值：$value';
  }

  @override
  String get hyperosShowcaseSectionInline => '基礎控件 · 行內';

  @override
  String get hyperosShowcaseCheckboxSubtitle => '多選偏好行';

  @override
  String get hyperosShowcaseSectionNavActions => '導航猶操作';

  @override
  String get hyperosShowcaseTooltipButton => '帶 Tooltip 的按钮';

  @override
  String get hyperosShowcaseSectionProgress => '進度猶刷新';

  @override
  String get hyperosShowcaseSectionColorChip => '顏色選擇 · ColorChip';

  @override
  String get hyperosShowcaseSectionNavBar => '底部導航 · HyperosNavigationBar';

  @override
  String get hyperosShowcaseNavHome => '首頁';

  @override
  String get hyperosShowcaseNavTimetable => '課表';

  @override
  String get hyperosShowcaseNavSettings => '設置';

  @override
  String get hyperosShowcaseSectionEmpty => '空態 / 分割線 / 裝飾';

  @override
  String get hyperosShowcaseEmptySubtitle => '列表無數據時的佔位';

  @override
  String get hyperosShowcaseActionButton => '操作按钮';

  @override
  String get hyperosShowcaseDividerRowTitle => '第二行（上方有縮進分割線）';

  @override
  String get hyperosShowcaseSectionPressable => '底層行 · HyperosPressableRow';

  @override
  String get hyperosShowcaseSectionShell => '頁面殼層';

  @override
  String get hyperosShowcaseRootPageDetails => '無返回鍵根頁';

  @override
  String get hyperosShowcaseSubpageSubtitle => '當前頁即 Subpage + HyperosListView';

  @override
  String get hyperosShowcaseAlreadyInSubpage => '已在 Subpage 中';

  @override
  String get hyperosShowcaseSectionFrosted => '模糊頂欄 · 滾動物理';

  @override
  String get hyperosShowcaseSectionFeedback => '反饋 · 彈層';

  @override
  String get hyperosShowcaseSectionIconColors => '主題色 · HyperosIconColors';

  @override
  String get hyperosShowcaseFooterNote => '此頁僅在非 Release 構建設置首頁可見，用于組件視覺驗收';

  @override
  String get hyperosShowcaseUndoAction => '撤銷';

  @override
  String get hyperosShowcaseDialogMessage => '系統風格對話框示例';

  @override
  String get hyperosShowcaseConfirmTitle => '確認操作';

  @override
  String get hyperosShowcaseConfirmed => '已確認';

  @override
  String get hyperosShowcaseToastDescription => '帶圖標猶副標題，App Toast 同款';

  @override
  String get hyperosShowcaseMenuCopy => '複製';

  @override
  String get hyperosShowcaseMenuShare => '分享';

  @override
  String get hyperosShowcaseMenuDelete => '刪除';

  @override
  String get hyperosShowcaseRefreshDone => '刷新完成';

  @override
  String get hyperosShowcaseSearchTooltip => '搜索';

  @override
  String get hyperosShowcaseRootShellLabel => '根頁殼層';

  @override
  String get hyperosShowcasePushSubtitle => '通過 HyperosNavigation.push 進入';

  @override
  String get hyperosShowcaseSampleText => '示例文本';

  @override
  String courseImportQuickImportDescription(
    String schoolName,
    String adapterName,
  ) {
    return '快捷導入 $schoolName $adapterName';
  }

  @override
  String get courseImportScriptNoCourses => '導入脚本未返回課程數據';

  @override
  String get courseImportScriptFailed => '脚本執行失敗';

  @override
  String get courseImportRecordingStatus => '錄制中…點擊停止完成錄制';

  @override
  String get courseImportRecordingStartedTip => '錄制已開始，請按正常流程操作教務網站';

  @override
  String get courseImportAutoRecordingStartedTip => '已在背景記錄操作，匯入成功後可儲存為快捷匯入';

  @override
  String get courseImportRecordingEmptyStatus => '未錄制到任何操作';

  @override
  String get courseImportRecordingEmptyTip => '未錄制到任何操作';

  @override
  String get courseImportSaveRecordingTitle => '保存錄制';

  @override
  String courseImportSaveRecordingMessage(int count) {
    return '錄制了 $count 個操作步晝，是否保存為快捷導入？';
  }

  @override
  String courseImportSaveAutoRecordingMessage(int count) {
    return '匯入成功。已記錄 $count 個操作步驟，是否儲存本次匯入路徑，以便下次快捷匯入？';
  }

  @override
  String courseImportRecordingSavedStatus(int count) {
    return '錄制已保存（$count 步）';
  }

  @override
  String get courseImportWeekNotProvided => '未提供周次';

  @override
  String get courseImportLocationNotFilled => '未填寫地點';

  @override
  String courseImportPreviewLine(
    String weekday,
    int startSection,
    int endSection,
    String name,
    String location,
    String weekText,
  ) {
    return '周$weekday 第$startSection-$endSection節  $name  $location  周次：$weekText';
  }

  @override
  String courseImportCalendarWeekLabel(int week) {
    return '校曆第 $week 周';
  }

  @override
  String get courseImportTermStartDateTitle => '開學日期';

  @override
  String get courseImportFirstWeekMappingLabel => '課表第 1 周對應校曆第幾周';

  @override
  String get courseImportFirstWeekMappingSubtitle =>
      '如果學校第一周没課，就選第 2 周；前兩周都没課就選第 3 周';

  @override
  String get courseImportFirstWeekNoShift => '導入後會直接把課表第 1 周當作校曆第 1 周';

  @override
  String courseImportFirstWeekShifted(int weeks, int targetWeek) {
    return '導入後會把所有課程周次整體順延 $weeks 周，讓課表第 1 周落在校曆第 $targetWeek 周';
  }

  @override
  String get courseImportContinueAction => '繼續導入';

  @override
  String get courseImportUpdateRecommendedAction => '更新課表（推薦）';

  @override
  String get courseImportOverwriteAction => '覆蓋導入';

  @override
  String get courseImportSectionCountInsufficientTitle => '時間模板節次不足';

  @override
  String courseImportSectionCountInsufficientMessage(
    int current,
    int required,
  ) {
    return '當前課表時間模板只有 $current 節，但導入數據需要到第 $required 節，是否自動補齊後繼續導入？';
  }

  @override
  String get courseImportAutoFillAndImportAction => '自動補齊並導入';

  @override
  String get courseImportPortalUrlTitle => '輸入教務網址';

  @override
  String get courseImportPortalUrlSaveContinue => '保存並繼續';

  @override
  String get courseImportPortalUrlLabel => '教務網址';

  @override
  String get courseImportPortalUrlHint => '保存後下次會直接使用，也可以在適配器信息頁里修改';

  @override
  String get courseImportPortalUrlInvalid => '登錄地址格式不正確';

  @override
  String get logAppLoggerInitialized => '應用日志服務已初始化';

  @override
  String get logPrivacyConsentUpdated => '隱私協議同意壯態已更新';

  @override
  String get logAppLogRecordingEnabled => '應用日志記錄已開啟';

  @override
  String get logAppLogRecordingRemainsEnabled => '應用日志記錄保持開啟';

  @override
  String get logStartupFlowStarted => '啟動流程處理已開始';

  @override
  String get logStartupFlowCompletedNoOnboarding => '啟動流程已完成（無需引導頁）';

  @override
  String get logStartupFlowCompletedAfterGuide => '啟動流程已完成（經過引導頁）';

  @override
  String get logStartupFlowFailed => '啟動流程失敗，進入降級模式';

  @override
  String get logAppLifecycleChanged => '應用生命周期已變更';

  @override
  String get logNavigatorRouteReplaced => '導航路由已替換';

  @override
  String get logNavigatorRouteChanged => '導航路由已變更';

  @override
  String get logAppLogsDefaultMigrated => '遷移時已默認開啟應用日志記錄';

  @override
  String get logTimetableLoadSettingsFailed => '加載課表設置失敗';

  @override
  String get logTimetableLoadCoursesFailed => '加載課程數據失敗';

  @override
  String get logTimetableLoadCurrentWeekFailed => '加載當前周次失敗';

  @override
  String get logHomeWidgetPinSupportFailed => '檢查桌面小組件固定支持失敗';

  @override
  String get logHomeWidgetPinRequestFailed => '請求固定桌面小組件失敗';

  @override
  String get logHomeWidgetSyncFailed => '同步桌面小組件快照失敗';

  @override
  String get logHomeWidgetClearFailed => '清空桌面小組件快照失敗';

  @override
  String get logHomeWidgetScheduleFailed => '調度桌面小組件刷新失敗';

  @override
  String get logHomeWidgetExactAlarmCheckFailed => '檢查精確鬧鐘權限失敗';

  @override
  String get logHomeWidgetExactAlarmRequestFailed => '請求精確鬧鐘授權失敗';

  @override
  String get logMiuiLiveInitializeFailed => '初始化 MIUI 超級島通道失敗';

  @override
  String get logMiuiLiveOpenPromotedSettingsFailed => '打開超級島權限設置失敗';

  @override
  String get logMiuiLiveOpenNotificationSettingsFailed => '打開通知設置失敗';

  @override
  String get logMiuiLiveOpenAutostartSettingsFailed => '打開自啟動設置失敗';

  @override
  String get logMiuiLiveOpenBatterySettingsFailed => '打開電池優化設置失敗';

  @override
  String get logMiuiLiveOpenAccessibilitySettingsFailed => '打開無漲礙設置失敗';

  @override
  String get logMiuiLiveHideFromRecentsFailed => '更新「從最近任務隱藏」失敗';

  @override
  String get logLiveUpdateStartFailed => '從 Flutter 啟動超級島失敗';

  @override
  String get logLiveUpdateStopFailed => '從 Flutter 停止超級島失敗';

  @override
  String get logLiveUpdateDebugStatusFailed => '获取原生超級島調試壯態失敗';

  @override
  String get logLiveUpdateSnapshotSyncFailed => '同步超級島課表快照失敗';

  @override
  String get logLiveUpdateSnapshotClearFailed => '清空超級島課表快照失敗';

  @override
  String get logLiveUpdateSuspendTriggersFailed => '掛起超級島課表調度失敗';

  @override
  String get logLanEditAuthFailed => '局域網編輯：認證失敗';

  @override
  String get logLanEditCourseCreated => '局域網編輯：已創建課程';

  @override
  String get logLanEditCourseUpdated => '局域網編輯：已更新課程';

  @override
  String get logLanEditCourseDeleted => '局域網編輯：已刪除課程';

  @override
  String get logLanEditCourseGroupSaved => '局域網編輯：已保存課程組';

  @override
  String get logLanEditMergeImported => '局域網編輯：已導入合並備份';

  @override
  String get logLanEditCoursesBatchDeleted => '局域網編輯：已批量刪除課程';

  @override
  String get logLanEditCurrentWeekSet => '局域網編輯：已設置當前周次';

  @override
  String get logLanEditProfileSwitched => '局域網編輯：已切換課表';

  @override
  String get logLanEditSpreadsheetImported => '局域網編輯：已導入表格';

  @override
  String get logLanEditSessionStarted => '局域網編輯：會話已啟動';

  @override
  String get logLanEditSessionStopped => '局域網編輯：會話已停止';

  @override
  String get logLiveUpdateTestRequested => '用戶請求手動超級島測試通知';

  @override
  String get logLiveUpdateTestNoSelection => '手動超級島測試：未找到可用課程';

  @override
  String get logLiveUpdateTestSelectionReady => '手動超級島測試：已解析目標課程';

  @override
  String get logLiveUpdateTestSuspendSync => '手動超級島測試：已臨時暂停定時同步';

  @override
  String get logLiveUpdateTestStarting => '手動超級島測試：正在啟動原生超級島';

  @override
  String get logLiveUpdateTestStarted => '手動超級島測試：已成功請求原生超級島';

  @override
  String get logLiveUpdateTestFailed => '手動超級島測試：原生超級島出現前失敗';

  @override
  String logLiveUpdateSettingsSynced(
    String beforeClass,
    String duringClass,
    String beforeEnd,
    String promote,
    String notification,
    String countdown,
    String courseName,
    String location,
  ) {
    return 'Flutter 超級島設置已同步：課前=$beforeClass，課中=$duringClass，下課前=$beforeEnd，提升=$promote，通知=$notification，倒計時=$countdown，課程名=$courseName，地點=$location';
  }

  @override
  String get logFieldSource => '來源';

  @override
  String get logFieldPlatform => '平台';

  @override
  String get logFieldVersion => '版本';

  @override
  String get logFieldBuildNumber => '構建號';

  @override
  String get logFieldLoggingEnabled => '日志記錄';

  @override
  String get logFieldPrivacyAccepted => '隱私協議';

  @override
  String get logFieldAccepted => '已同意';

  @override
  String get logFieldPrevious => '先前壯態';

  @override
  String get logFieldTruncated => '已截斷';

  @override
  String get logFieldTruncatedHint => '截斷提示';

  @override
  String get logFieldThrowable => '異常';

  @override
  String get logFieldExtras => '附加信息';

  @override
  String get logFieldContext => '設備上下文';

  @override
  String get logFieldError => '錯誤';

  @override
  String get logFieldBrand => '品牌';

  @override
  String get logFieldManufacturer => '制造商';

  @override
  String get logFieldModel => '型號';

  @override
  String get logFieldSdkInt => 'SDK 版本';

  @override
  String get logFieldVersionName => '版本名';

  @override
  String get logFieldChannel => '渠道';

  @override
  String get logFieldHasNotificationPermission => '通知權限';

  @override
  String get logFieldHasPromotedPermissionDeclared => '已聲明提升通知權限';

  @override
  String get logFieldCanPostPromotedNotifications => '可發布提升通知';

  @override
  String get logFieldIgnoringBatteryOptimizations => '忽略電池優化';

  @override
  String get logFieldKeepAliveAccessibilityEnabled => '無漲礙保活已啟用';

  @override
  String get logFieldHideFromRecentsEnabled => '從最近任務隱藏';

  @override
  String get logFieldTaskRemovedRecently => '近期任務被移除';

  @override
  String get logFieldLastTaskRemovedAt => '上次任務移除時間';

  @override
  String get logFieldProcessImportance => '進程重要性';

  @override
  String get logFieldAutoStartStatus => '自啟動壯態';

  @override
  String get logFieldLiveEnableBeforeClass => '課前超級島';

  @override
  String get logFieldLiveEnableDuringClass => '課中超級島';

  @override
  String get logFieldLiveEnableBeforeEnd => '下課前超級島';

  @override
  String get logFieldLivePromoteDuringClass => '課中提升通知';

  @override
  String get logFieldLiveShowDuringClassNotification => '課中壯態欄通知';

  @override
  String get logFieldLiveShowCountdown => '顯示倒計時';

  @override
  String get logFieldLiveShowStageText => '顯示階段文字';

  @override
  String get logFieldLiveShowCourseName => '顯示課程名';

  @override
  String get logFieldLiveShowLocation => '顯示地點';

  @override
  String get logFieldLiveUseShortName => '使用簡稱';

  @override
  String get logFieldLiveHidePrefixText => '隱藏前缀文字';

  @override
  String get logFieldLiveDuringClassTimeDisplayMode => '課中時間顯示模式';

  @override
  String get logFieldLiveEnableMiuiIslandLabelImage => '島標簽圖片';

  @override
  String get logFieldLiveMiuiIslandLabelStyle => '島標簽養式';

  @override
  String get logFieldLiveMiuiIslandLabelContent => '島標簽內容';

  @override
  String get logFieldLiveMiuiIslandLabelFontColor => '島標簽字體顏色';

  @override
  String get logFieldLiveMiuiIslandLabelFontWeight => '島標簽字重';

  @override
  String get logFieldLiveMiuiIslandLabelRenderQuality => '島標簽渲染質量';

  @override
  String get logFieldLiveMiuiIslandLabelFontSize => '島標簽字號';

  @override
  String get logFieldLiveMiuiIslandLabelOffsetX => '島標簽 X 偏移';

  @override
  String get logFieldLiveMiuiIslandLabelOffsetY => '島標簽 Y 偏移';

  @override
  String get logFieldLiveMiuiIslandExpandedIconMode => '展開圖標模式';

  @override
  String get logFieldLiveShowBeforeClassMinutes => '課前顯示分鐘數';

  @override
  String get logFieldLiveClassReminderStartMinutes => '上課提醒開始分鐘';

  @override
  String get logFieldLiveEndSecondsCountdownThreshold => '下課秒倒計時阈值';

  @override
  String get logFieldState => '壯態';

  @override
  String get logFieldRoute => '路由';

  @override
  String get logFieldPreviousRoute => '先前路由';

  @override
  String get logFieldProfileId => '課表配置 ID';

  @override
  String get logFieldReason => '原因';

  @override
  String get logFieldClientIp => '客戶端 IP';

  @override
  String get logFieldPort => '端口';

  @override
  String get logFieldCourseName => '課程名';

  @override
  String get logFieldStage => '階段';

  @override
  String get logFieldFrom => '來源頁面';

  @override
  String get logFieldCurrentWeek => '當前周次';

  @override
  String get logFieldWeekday => '星期';

  @override
  String get logFieldUntilMillis => '暂停截止時間';

  @override
  String get logFieldStartAtMillis => '開始時間';

  @override
  String get logFieldMergedCourseCount => '合並課程數';

  @override
  String get logFieldDeletedCount => '刪除數量';

  @override
  String get logFieldRequested => '請求數量';

  @override
  String get logFieldTarget => '目標';

  @override
  String get logFieldCount => '數量';

  @override
  String get logFieldValue => '值';

  @override
  String get logFieldSnapshotLength => '快照長度';

  @override
  String get logFieldStoredSnapshotVersion => '存儲快照版本';

  @override
  String get logFieldIntentIsNull => 'Intent 為空';

  @override
  String get logFieldAction => '操作';

  @override
  String get logFieldStep => '步晝';

  @override
  String get logCatAppLoggerInitialized => '應用日志：初始化';

  @override
  String get logCatPrivacyConsentUpdated => '應用日志：隱私協議';

  @override
  String get logCatAppLogRecordingEnabled => '應用日志：記錄開關';

  @override
  String get logCatStartupFlowStarted => '啟動流程：開始';

  @override
  String get logCatStartupFlowCompleted => '啟動流程：完成';

  @override
  String get logCatStartupFlowFailed => '啟動流程：失敗';

  @override
  String get logCatAppLifecycleStateChanged => '應用生命周期';

  @override
  String get logCatRoutePushed => '路由：入栈';

  @override
  String get logCatRoutePopped => '路由：出栈';

  @override
  String get logCatRouteReplaced => '路由：替換';

  @override
  String get logCatFlutterFrameworkError => 'Flutter 框架錯誤';

  @override
  String get logCatFlutterPlatformError => 'Flutter 平台錯誤';

  @override
  String get logCatFlutterZoneError => 'Flutter Zone 錯誤';

  @override
  String get logCatAppLogsDefaultMigrated => '應用日志：遷移';

  @override
  String get logCatTimetableLoadSettingsFailed => '課表：加載設置失敗';

  @override
  String get logCatTimetableLoadCoursesFailed => '課表：加載課程失敗';

  @override
  String get logCatTimetableLoadCurrentWeekFailed => '課表：加載周次失敗';

  @override
  String get logCatHomeWidgetPinSupportFailed => '桌面小組件：檢查固定支持';

  @override
  String get logCatHomeWidgetPinRequestFailed => '桌面小組件：請求固定';

  @override
  String get logCatHomeWidgetSyncFailed => '桌面小組件：同步失敗';

  @override
  String get logCatHomeWidgetClearFailed => '桌面小組件：清空失敗';

  @override
  String get logCatHomeWidgetScheduleFailed => '桌面小組件：調度刷新';

  @override
  String get logCatMiuiLiveInitializeFailed => '超級島：初始化失敗';

  @override
  String get logCatMiuiLiveOpenPromotedSettingsFailed => '超級島：打開權限設置';

  @override
  String get logCatMiuiLiveOpenNotificationSettingsFailed => '超級島：打開通知設置';

  @override
  String get logCatMiuiLiveOpenAutostartSettingsFailed => '超級島：打開自啟動設置';

  @override
  String get logCatMiuiLiveOpenBatterySettingsFailed => '超級島：打開電池優化';

  @override
  String get logCatMiuiLiveOpenAccessibilitySettingsFailed => '超級島：打開無漲礙設置';

  @override
  String get logCatMiuiLiveHideFromRecentsFailed => '超級島：隱藏最近任務';

  @override
  String get logCatLiveUpdateFlutterInitializeFailed => '超級島：Flutter 初始化失敗';

  @override
  String get logCatLiveUpdateStartFailed => '超級島：啟動失敗';

  @override
  String get logCatLiveUpdateStopFailed => '超級島：停止失敗';

  @override
  String get logCatLiveUpdateDebugStatusFailed => '超級島：調試壯態失敗';

  @override
  String get logCatLiveUpdateSettingsSynced => '超級島：設置已同步';

  @override
  String get logCatLiveUpdateSnapshotSyncFailed => '超級島：快照同步失敗';

  @override
  String get logCatLiveUpdateSnapshotClearFailed => '超級島：快照清空失敗';

  @override
  String get logCatLanEditAuthFailed => '局域網編輯：認證';

  @override
  String get logCatLanEditCourseCreated => '局域網編輯：創建課程';

  @override
  String get logCatLanEditCourseUpdated => '局域網編輯：更新課程';

  @override
  String get logCatLanEditCourseDeleted => '局域網編輯：刪除課程';

  @override
  String get logCatLanEditCourseGroupSaved => '局域網編輯：保存課程組';

  @override
  String get logCatLanEditMergeImported => '局域網編輯：合並導入';

  @override
  String get logCatLanEditCoursesBatchDeleted => '局域網編輯：批量刪除';

  @override
  String get logCatLanEditCurrentWeekSet => '局域網編輯：設置周次';

  @override
  String get logCatLanEditSpreadsheetImported => '局域網編輯：表格導入';

  @override
  String get logCatLanEditSessionStarted => '局域網編輯：會話啟動';

  @override
  String get logCatLanEditSessionStopped => '局域網編輯：會話停止';

  @override
  String get logCatLiveUpdateTestRequested => '超級島測試：請求';

  @override
  String get logCatLiveUpdateTestNoSelection => '超級島測試：無課程';

  @override
  String get logCatLiveUpdateTestSelectionReady => '超級島測試：已選課程';

  @override
  String get logCatLiveUpdateTestSuspendSync => '超級島測試：暂停同步';

  @override
  String get logCatLiveUpdateTestStarting => '超級島測試：啟動中';

  @override
  String get logCatLiveUpdateTestStarted => '超級島測試：已啟動';

  @override
  String get logCatLiveUpdateTestFailed => '超級島測試：失敗';

  @override
  String get logCatLiveUpdateSnapshotSettings => '超級島：快照設置';

  @override
  String get logCatLiveUpdateSnapshotSynced => '超級島：快照已同步';

  @override
  String get logCatLiveUpdateSnapshotCleared => '超級島：快照已清空';

  @override
  String get logCatLiveUpdateAlarmTriggered => '超級島：鬧鐘觸發';

  @override
  String get logCatLiveUpdateSchedulerResume => '超級島：調度恢復';

  @override
  String get logCatLiveUpdateRescheduleHoliday => '超級島：節假日跳過';

  @override
  String get logCatLiveUpdateRescheduleActive => '超級島：立即啟動';

  @override
  String get logCatLiveUpdateRescheduleScheduled => '超級島：已調度';

  @override
  String get logCatLiveUpdateSnapshotParseFailed => '超級島：快照解析失敗';

  @override
  String get logCatLiveUpdateSnapshotInvalidatedAfterUpgrade => '超級島：升級後快照失效';

  @override
  String get logCatLiveUpdatePayloadSelected => '超級島：已選負載';

  @override
  String get logCatLiveUpdateSchedulerStartFailed => '超級島：調度啟動失敗';

  @override
  String get logCatLiveUpdateStartRequested => '超級島：請求啟動';

  @override
  String get logCatLiveUpdateStopRequested => '超級島：請求停止';

  @override
  String get logCatLiveUpdateServiceMissingPayload => '超級島：服務缺少負載';

  @override
  String get logCatLiveUpdateServiceStarted => '超級島：服務已啟動';

  @override
  String get logCatLiveUpdateServiceStartFailed => '超級島：服務啟動失敗';

  @override
  String get logCatLiveUpdateServiceFgsStartDenied =>
      '超級島：服務內 startForeground 被拒';

  @override
  String get logCatLiveUpdateFgsRetryScheduled => '超級島：前台服務被拒，已排退避重試';

  @override
  String get logCatLiveUpdateFgsStartGaveUp => '超級島：重試耗盡，已降級為普通通知';

  @override
  String get logCatLiveUpdateTaskRemoved => '超級島：任務被移除';

  @override
  String get logCatLiveUpdateTaskRemovedResumed => '超級島：任務移除後恢復';

  @override
  String get logCatLiveUpdateBeforeClassQuickAction => '超級島：課前快捷操作';

  @override
  String get logCatLiveUpdateBeforeClassQuickActionRestored => '超級島：課前快捷操作已恢復';

  @override
  String get logCatLiveUpdateStatusBarDismissed => '超級島：壯態欄通知已關閉';

  @override
  String get logCatLiveUpdateNotPromoted => '超級島：未提升通知';

  @override
  String get logCatLiveUpdatePromotedNotShown => '超級島：提升未顯示';

  @override
  String get logCatLiveUpdateServiceStopped => '超級島：服務已停止';

  @override
  String get logCatKeepAliveAccessibilityConnected => '保活：無漲礙已連接';

  @override
  String get logCatDiagnosticsEnabled => '偵斷：已開啟';

  @override
  String get logCatDiagnosticsCleared => '偵斷：已清空';

  @override
  String get logCatDiagnosticsBootstrap => '偵斷：引導';

  @override
  String get logCatFlutterDiagnostic => 'Flutter 偵斷';

  @override
  String get logCatFlutterDiagnosticEvent => 'Flutter 偵斷事件';

  @override
  String get logCatRenderFailed => '渲染失敗';

  @override
  String get logCatDebugSnapshot => '調試快照';

  @override
  String get logExportTitle => '輕誘課表 - 應用日志';

  @override
  String get appUpdateMirrorPresetGhfast => '默認镜像';

  @override
  String get appUpdateMirrorPresetGhproxyCn => '備用镜像 1';

  @override
  String get appUpdateMirrorPresetGhLlkk => '備用镜像 2';

  @override
  String get appUpdateMirrorPresetGhProxyCom => '備用镜像 3';

  @override
  String get appUpdateMirrorPresetGhproxyNet => '備用镜像 4';

  @override
  String get appUpdateMirrorPresetCustom => '自定義';

  @override
  String get appUpdateMirrorPresetCustomDescription => '填寫自定義镜像地址前缀';

  @override
  String get cloudBackupRetentionTitle => '備份保留策略';

  @override
  String get cloudBackupMaxCountTitle => '最多保留份數';

  @override
  String get cloudBackupMaxCountSubtitle => '超過後自動刪除最舊的備份';

  @override
  String cloudBackupMaxCountOption(int count) {
    return '$count 份';
  }

  @override
  String get cloudBackupMaxAgeTitle => '最長保留天數';

  @override
  String get cloudBackupMaxAgeSubtitle => '超過後自動刪除過期備份';

  @override
  String cloudBackupMaxAgeOption(int days) {
    return '$days 天';
  }

  @override
  String get statisticsShareText => '來自輕誘課表的學期統計';

  @override
  String get aboutUpdateAvailableHeadline => '有版本更新';

  @override
  String get aboutAlreadyLatestHeadline => '已是最新版本';

  @override
  String get aboutDownloadChannelSectionTitle => '下載渠道';

  @override
  String get aboutMirrorProbeFailedLabel => '失敗';

  @override
  String timeSchemeImportSupplementName(String name) {
    return '$name（導入補齊）';
  }

  @override
  String profileTimeSchemeName(String profileName) {
    return '$profileName 時間';
  }

  @override
  String get currentProfileTimeSchemeName => '當前課表時間';

  @override
  String get unnamedTimetableProfile => '未命名課表';

  @override
  String get cloudBackupManualProtectedTitle => '手動備份永不過期';

  @override
  String get cloudBackupManualProtectedSubtitle => '開啟後，手動創建的備份不會被自動清理';

  @override
  String courseImportPortalUrlMissingBody(
    String schoolName,
    String adapterName,
  ) {
    return '“$schoolName / $adapterName” 没有默認登錄地址，請先輸入學校教務系統網址';
  }

  @override
  String guidePermissionsProgressLabel(int ready, int total) {
    return '已就緒 $ready/$total';
  }

  @override
  String get locationTimeMatchEntryTitle => '地點作息匹配';

  @override
  String get locationTimeMatchEntrySubtitle => '按上課地點關鍵詞自動選用時間範本';

  @override
  String get locationTimeMatchTitle => '地點作息匹配';

  @override
  String get locationTimeMatchSubtitle =>
      '按地點關鍵詞自動匹配時間範本。重新匹配僅更新命中課程的鐘點，未命中課程保持不變。';

  @override
  String get locationTimeMatchWeekAxisNote =>
      '說明：首頁左側時間列仍顯示課表默認模板；卡片/詳情/實況上的鐘點以地點匹配結果為準。';

  @override
  String get locationTimeMatchPreviewLabel => '試匹配地點';

  @override
  String get locationTimeMatchPreviewHint => '例如 A1062 或 A主201';

  @override
  String get locationTimeMatchPreviewNoMatch => '未命中任何地點組，將使用課表默認時間模板';

  @override
  String locationTimeMatchPreviewResult(
    String group,
    String scheme,
    String keyword,
  ) {
    return '將匹配：$group · $scheme（關鍵詞 $keyword）';
  }

  @override
  String get locationTimeMatchApplyActive => '重新匹配目前課表';

  @override
  String get locationTimeMatchApplyTitle => '重新匹配目前課表？';

  @override
  String locationTimeMatchApplyMessage(int count) {
    return '目前有 $count 門課程命中地點規則。節次適配的課程會恢復自動匹配並同步鐘點；此前手動指定的模板將被清除，未命中的課程不會改變。';
  }

  @override
  String get locationTimeMatchApplyConfirm => '重新匹配';

  @override
  String locationTimeMatchApplyUpdated(int matched, int updated) {
    return '已重新匹配 $matched 門，更新 $updated 門鐘點';
  }

  @override
  String locationTimeMatchApplyAlreadyAligned(int matched) {
    return '已重新匹配 $matched 門，鐘點無需改寫';
  }

  @override
  String get locationTimeMatchApplyNoneMatched => '沒有匹配到可套用的課程';

  @override
  String locationTimeMatchApplyOverflowResult(int matched, int count) {
    return '有 $count 門課節次無法對號入座（範本節數不足），已拒絕套用';
  }

  @override
  String locationTimeMatchApplyOverflowHint(String names) {
    return '未套用示例：$names';
  }

  @override
  String get locationTimeMatchEmpty => '還沒有地點組';

  @override
  String get locationTimeMatchCreateGroup => '新建地點組';

  @override
  String get locationTimeMatchEditGroup => '編輯地點組';

  @override
  String get locationTimeMatchUnknownScheme => '未知時間模板';

  @override
  String get locationTimeMatchNoKeywords => '未設置關鍵詞';

  @override
  String locationTimeMatchBoundScheme(String name) {
    return '時間模板：$name';
  }

  @override
  String locationTimeMatchKeywordsLine(String keywords) {
    return '關鍵詞：$keywords';
  }

  @override
  String get locationTimeMatchDeleteTitle => '刪除地點組？';

  @override
  String locationTimeMatchDeleteMessage(String name) {
    return '確定刪除「$name」？自動匹配的課程將恢復課表預設模板；手動指定模板的課程不受蠅響。';
  }

  @override
  String get locationTimeMatchDeleted => '已刪除地點組';

  @override
  String get locationTimeMatchGroupNameLabel => '地點組名稱';

  @override
  String get locationTimeMatchGroupNameHint => '例如：主教學樓 / 其他教學樓';

  @override
  String get locationTimeMatchBoundSchemeLabel => '綁定時間模板';

  @override
  String get locationTimeMatchNeedTimeScheme => '請先創建至少一套時間模板';

  @override
  String get locationTimeMatchEnabledLabel => '啟用此地點組';

  @override
  String get locationTimeMatchKeywordsSection => '地點關鍵詞';

  @override
  String get locationTimeMatchKeywordsHelp =>
      '可從課表地點一鍵識別樓棟，或手動填寫關鍵詞（如 A主、A1、A6）。匹配模式建議用「前缀」，更長的關鍵詞優先。';

  @override
  String get locationTimeMatchSelectedKeywords => '已選關鍵詞';

  @override
  String get locationTimeMatchNoSelectedKeywords => '尚未添加關鍵詞';

  @override
  String get locationTimeMatchPickFromLocations => '從課表地點選擇';

  @override
  String get locationTimeMatchBuildingSuggestions => '從課表識別的樓棟';

  @override
  String get locationTimeMatchNoBuildingSuggestions => '當前課表没有可識別的樓棟地點';

  @override
  String get locationTimeMatchAddBuilding => '添加';

  @override
  String get locationTimeMatchAddAllBuildings => '一鍵添加全部未配置樓棟';

  @override
  String locationTimeMatchBuildingRoomCount(int count) {
    return '$count 間教室';
  }

  @override
  String locationTimeMatchBuildingGateTags(String tags) {
    return '標簽：$tags';
  }

  @override
  String locationTimeMatchKeywordExtracted(String keyword) {
    return '已從地點提取關鍵詞 $keyword';
  }

  @override
  String get locationTimeMatchKeywordAlreadyExists => '關鍵詞已存在';

  @override
  String locationTimeMatchKeywordUsedByGroup(String group) {
    return '關鍵詞已被「$group」使用';
  }

  @override
  String get locationTimeMatchAddKeyword => '手動添加關鍵詞';

  @override
  String get locationTimeMatchKeywordLabel => '關鍵詞';

  @override
  String get locationTimeMatchKeywordHint => 'A1 / A主 / 六教';

  @override
  String get locationTimeMatchModeLabel => '匹配模式';

  @override
  String get locationTimeMatchModePrefix => '前缀';

  @override
  String get locationTimeMatchModeContains => '包含';

  @override
  String get locationTimeMatchModeExact => '精確';

  @override
  String get locationTimeMatchKeywordTooShort => '關鍵詞過短，容易誤匹配';

  @override
  String get locationTimeMatchNameRequired => '請填寫地點組名稱';

  @override
  String get locationTimeMatchKeywordRequired => '請至少添加一個關鍵詞';

  @override
  String get locationTimeMatchSaved => '地點組已保存';

  @override
  String get locationTimeMatchSaveFailed => '保存失敗';

  @override
  String get followLocationAutoTimeScheme => '跟隨課表 / 地點自動';

  @override
  String get followLocationAutoTimeSchemeDescription =>
      '未手動指定時，依上課地點關鍵詞自動匹配時間範本；未命中則用課表預設範本';

  @override
  String locationTimeMatchedSchemeHint(String scheme) {
    return '自動 · $scheme';
  }

  @override
  String locationTimeAutoResolvedByGroup(String group, String scheme) {
    return '地點組「$group」→ $scheme';
  }

  @override
  String locationTimeAutoResolvedByTimetable(String scheme) {
    return '課表預設 → $scheme';
  }

  @override
  String get scheduleDateRuleSectionTitle => '日期作息規則';

  @override
  String get scheduleDateRuleSectionSubtitle =>
      '開始日自動將所選模板套用為全部課表預設作息。最多 2 條且區間不重疊；地點作息匹配優先。';

  @override
  String get scheduleDateRuleAdd => '新增日期規則';

  @override
  String get scheduleDateRuleEdit => '編輯日期規則';

  @override
  String get scheduleDateRuleEmpty => '未設定日期規則';

  @override
  String get scheduleDateRuleNameLabel => '規則名稱';

  @override
  String get scheduleDateRuleNameHint => '例如：夏令時 / 冬令時';

  @override
  String get scheduleDateRuleStartDate => '開始日期';

  @override
  String get scheduleDateRuleEndDate => '結束日期';

  @override
  String get scheduleDateRuleBoundScheme => '使用時間模板';

  @override
  String get scheduleDateRuleEnabled => '啟用';

  @override
  String get scheduleDateRuleActiveToday => '今天在區間內';

  @override
  String scheduleDateRuleRangeSummary(String start, String end) {
    return '$start ~ $end';
  }

  @override
  String get scheduleDateRuleMaxReached => '最多只能新增 2 條日期規則';

  @override
  String get scheduleDateRuleNeedScheme => '請先建立至少一套時間模板';

  @override
  String get scheduleDateRuleNameRequired => '請填寫規則名稱';

  @override
  String get scheduleDateRuleSaved => '日期規則已儲存';

  @override
  String get scheduleDateRuleSavedAndApplied => '日期規則已儲存，今天已更新所有課表的預設作息';

  @override
  String get scheduleDateRuleSavedForFuture => '日期規則已儲存，將在開始日期更新所有課表的預設作息';

  @override
  String get scheduleDateRuleSavedButApplyFailed =>
      '日期規則已儲存，但今天自動套用失敗（請檢查模板節次是否足夠）';

  @override
  String get scheduleDateRuleDeleted => '已刪除日期規則';

  @override
  String get scheduleDateRuleDeleteTitle => '刪除日期規則？';

  @override
  String scheduleDateRuleDeleteMessage(String name) {
    return '確定刪除「$name」？刪除後不會自動還原已套用的作息，需手動調整。';
  }

  @override
  String scheduleDateRuleSaveFailed(String reason) {
    return '儲存失敗：$reason';
  }

  @override
  String get scheduleDateRuleErrorMax => '已達到 2 條上限';

  @override
  String get scheduleDateRuleErrorOverlap => '日期區間與已有規則重疊';

  @override
  String get scheduleDateRuleErrorInvalidDate => '日期格式無效';

  @override
  String get scheduleDateRuleErrorEndBeforeStart => '結束日期不能早於開始日期';

  @override
  String get scheduleDateRuleErrorSchemeRequired => '請選擇時間模板';

  @override
  String get scheduleDateRuleErrorNameRequired => '請填寫名稱';

  @override
  String get scheduleDateRuleNote => '地點匹配優先於日期規則。';

  @override
  String get frostedGlassModeLabel => '玻璃模式';

  @override
  String get liquidGlassScopeSectionTitle => '液態玻璃作用範圍';

  @override
  String get liquidGlassScopePopupTitle => '下拉選擇彈窗';

  @override
  String get liquidGlassScopePopupSubtitle => '玻璃模式等設定列彈出的小氣泡選單';

  @override
  String get liquidGlassScopeSelectSheetTitle => '全螢幕選擇面板';

  @override
  String get liquidGlassScopeSelectSheetSubtitle => '預設主題、字體等長列表選擇彈窗，預設保持磨砂';

  @override
  String get liquidGlassScopeSheetDialogTitle => '彈窗與對話框';

  @override
  String get liquidGlassScopeSheetDialogSubtitle => '底部彈窗、確認對話框與動作選單';

  @override
  String get liquidGlassScopeHomeChromeTitle => '首頁玻璃帶';

  @override
  String get liquidGlassScopeHomeChromeSubtitle => '標題列與星期列的玻璃背景帶';

  @override
  String get liquidGlassScopeDockTitle => '玻璃塢導航';

  @override
  String get liquidGlassScopeDockSubtitle => '底部懸浮藥丸與加課圓鈕';

  @override
  String get liquidGlassScopePickerButtonsTitle => '壁紙選點按鈕';

  @override
  String get liquidGlassScopePickerButtonsSubtitle => '壁紙位置選擇頁懸浮在壁紙上的玻璃按鈕';

  @override
  String get frostedGlassModeFrosted => '經典磨砂';

  @override
  String get frostedGlassModeLiquid => '液態玻璃';

  @override
  String get frostedGlassModeGaussian => '高斯模糊';

  @override
  String get frostedGlassModeTranslucent => '半透明';

  @override
  String get frostedLiquidGlassHint => '液態玻璃需要高效能裝置';

  @override
  String get advancedMaterialTitle => '進階材質';

  @override
  String get advancedMaterialEntrySubtitle => '液態玻璃參數微調';

  @override
  String get liquidGlassPresetLabel => '液態玻璃預設';

  @override
  String get liquidGlassPresetClear => '清澈';

  @override
  String get liquidGlassPresetLight => '輕霧';

  @override
  String get liquidGlassPresetStandard => '標準';

  @override
  String get liquidGlassPresetDense => '濃密';

  @override
  String get liquidGlassPresetCustom => '自訂';

  @override
  String get courseCardSettingsTitle => '課程卡片';

  @override
  String get courseCardSectionFields => '顯示欄位';

  @override
  String get courseCardSectionLayout => '版面配置';

  @override
  String get courseCardSurfaceStyleLabel => '卡片外觀';

  @override
  String get courseCardSurfaceStyleSolid => '實體卡片';

  @override
  String get courseCardSurfaceStyleGaussian => '高斯模糊';

  @override
  String get courseCardSectionColor => '顏色';

  @override
  String get liveSelfCheckTitle => '自檢';

  @override
  String get collapsibleLargeTitle => '摺疊大標題';

  @override
  String get liquidGlassCustomExpandedTitle => '自訂參數';

  @override
  String get liquidGlassThicknessLabel => '厚度';

  @override
  String get liquidGlassBlurLabel => '模糊強度';

  @override
  String get liquidGlassTintLabel => '染色強度';

  @override
  String get liquidGlassLightIntensityLabel => '燈光強度';

  @override
  String get liquidGlassAmbientStrengthLabel => '環境光強度';

  @override
  String get liquidGlassRefractiveIndexLabel => '折射率';

  @override
  String get liquidGlassSaturationLabel => '飽和度';

  @override
  String get liquidGlassChromaticAberrationLabel => '色差';

  @override
  String get liquidGlassLightAngleLabel => '光照角度';

  @override
  String get liquidGlassVisibilityLabel => '可見性';

  @override
  String get liquidGlassResetAction => '還原預設';

  @override
  String get diagnosticsEntryTitle => '診斷';

  @override
  String get memoryStatsEntryTitle => '記憶體狀態';

  @override
  String get generalSettingsTitle => '一般';

  @override
  String get settingsResetDefaultsTitle => '還原預設設定';

  @override
  String get settingsResetDefaultsConfirmTitle => '確認還原';

  @override
  String get settingsResetConfirmBodyCourseCard => '將把課程卡片的顯示欄位、版面與顏色恢復為預設值。';

  @override
  String get settingsResetConfirmBodyTimetablePage =>
      '將把課表頁面的密度、回到當前週按鈕與背景（含清除桌布）恢復為預設值。';

  @override
  String get settingsResetConfirmBodyAppearance => '將把主題模式、字型、主題色與玻璃質感恢復為預設值。';

  @override
  String get settingsResetConfirmBodyHomeWidget => '將把桌面小組件的顯示項目與外觀恢復為預設值。';

  @override
  String get settingsResetConfirmBodyHomeNavigation => '將把底欄、選單與首頁標題設定恢復為預設值。';

  @override
  String get settingsResetDoneMessage => '設定已重設';

  @override
  String get timetablePageSettingsTitle => '課表頁面';

  @override
  String get timetablePageSectionDensity => '密度';

  @override
  String get timetablePageSectionBackToWeek => '返回目前週次';

  @override
  String get timetablePageSectionBackground => '背景';

  @override
  String get largeTitleContentGap => '16.0';

  @override
  String get selectTimeTitle => '選擇時間';

  @override
  String get liveSelfCheckSubtitle => '執行自檢';

  @override
  String get frostedSheetPreviewShowTitle => '顯示預覽';

  @override
  String get frostedSheetPreviewShowSubtitle => '在頂部顯示磨砂玻璃預覽';

  @override
  String get aboutSupportUpdatesSectionTitle => '支援與更新';

  @override
  String get aboutProductSectionTitle => '產品';

  @override
  String get aboutCommunitySectionTitle => '社群';

  @override
  String get selectStartTimeTitle => '選擇開始時間';

  @override
  String get selectEndTimeTitle => '選擇結束時間';

  @override
  String get weekdayInkContrastTitle => '文字對比度不足';

  @override
  String get weekdayInkContrastBodyDark =>
      '你的資訊欄文字顏色在深色桌布上對比度不足，已暫時切換為自動白色以保證可讀。可在「課表頁面 → 文字顏色」中更換顏色或恢復預設。';

  @override
  String get weekdayInkContrastBodyLight =>
      '你的資訊欄文字顏色在淺色桌布上對比度不足，已暫時切換為自動黑色以保證可讀。可在「課表頁面 → 文字顏色」中更換顏色或恢復預設。';

  @override
  String get gotItAction => '知道了';

  @override
  String get settingsTimetableSectionTitle => '課表';

  @override
  String get liveIslandLabelEntryEnabled => '已開啟';

  @override
  String get liveIslandLabelEntryDisabled => '已關閉';

  @override
  String get settingsDisplayAppearanceSectionTitle => '課表顯示';

  @override
  String get settingsReminderDesktopSectionTitle => '提醒與桌面';

  @override
  String get settingsAppSectionTitle => '應用程式';

  @override
  String get settingsDataShareSectionTitle => '資料與共享';

  @override
  String get coupleTimetableEntryUnboundLabel => '未綁定';

  @override
  String get settingsAboutSectionTitle => '關於';

  @override
  String get diagnosticsEntrySubtitle => '日誌 · 自檢 · 記憶體';

  @override
  String get settingsSemesterScreenTitle => '學期設定';

  @override
  String get syncCurrentWeekNeedsStartDate => '請先設定開學日期';

  @override
  String get liveNotificationPermissionMissing => '缺少通知權限';

  @override
  String get developerSectionTitle => '開發者選項';

  @override
  String get liveTestingFixtureEntryTitle => '實況測試樣例';

  @override
  String get hyperosShowcaseEntryTitle => 'HyperOS 組件展示';

  @override
  String get hyperosShowcaseEntrySubtitle => 'HyperOS 組件預覽';

  @override
  String get miuixShowcaseEntryTitle => 'Miuix 組件展示';

  @override
  String get miuixShowcaseEntrySubtitle => 'Miuix 組件預覽';

  @override
  String get debugUiOverlayToggleTitle => '除錯 UI 疊層';

  @override
  String get scheduleRepeatSectionTitle => '重複設定';

  @override
  String get scheduleRepeatNone => '不重複';

  @override
  String get scheduleRepeatDaily => '每天';

  @override
  String get scheduleRepeatWeekly => '每週';

  @override
  String get scheduleRepeatEndDateLabel => '重複結束日期';

  @override
  String get scheduleRepeatEndDateHint => '重複日程需要設定結束日期';

  @override
  String get scheduleRepeatWeeklyHint => '按開始日期對應的星期重複';

  @override
  String get scheduleReminderSectionTitle => '日程提醒';

  @override
  String get scheduleReminderOff => '不提醒';

  @override
  String scheduleReminderMinutes(int minutes) {
    return '提前 $minutes 分鐘';
  }

  @override
  String get scheduleReminderPermissionMissing => '通知權限未開啟，日程仍會儲存，但提醒可能無法送達';

  @override
  String get scheduleReminderPermissionAction => '檢查通知權限';

  @override
  String get scheduleEnabledTitle => '啟用日程';

  @override
  String get scheduleDisabledSubtitle => '已暫停，不會顯示提醒';

  @override
  String get scheduleEditScopeTitle => '編輯範圍';

  @override
  String get scheduleEditScopeThis => '僅本次';

  @override
  String get scheduleEditScopeAll => '全部重複日程';

  @override
  String get scheduleDeleteScopeTitle => '刪除範圍';

  @override
  String get scheduleDeleteScopeThis => '僅刪除本次';

  @override
  String get scheduleDeleteScopeAll => '刪除全部重複日程';

  @override
  String get scheduleOccurrenceEditHint => '你正在編輯這條重複日程的一次實例';

  @override
  String get scheduleRepeatEndRequired => '請選擇重複結束日期';

  @override
  String get homeMenuTasksTitle => '任務清單';

  @override
  String get taskListTitle => '任務清單';

  @override
  String get addTask => '新增任務';

  @override
  String get editTask => '編輯任務';

  @override
  String get saveTask => '儲存任務';

  @override
  String get taskTitleLabel => '任務標題';

  @override
  String get taskTitleHint => '例如：完成第三章習題';

  @override
  String get taskTitleRequired => '請輸入任務標題';

  @override
  String get taskNoteLabel => '備註';

  @override
  String get taskNoteHint => '補充說明（可選）';

  @override
  String get taskDueDateLabel => '截止日期';

  @override
  String get taskNoDueDate => '無截止日期';

  @override
  String get taskCourseLabel => '來源課程';

  @override
  String get taskCourseFilter => '課程篩選';

  @override
  String get taskAllCourses => '全部課程';

  @override
  String get taskNoCourse => '無關聯課程';

  @override
  String get taskAllFilter => '全部';

  @override
  String get taskTodayFilter => '今日';

  @override
  String get taskWeekFilter => '本週';

  @override
  String get taskOverdueSection => '已逾期';

  @override
  String get taskCompletedSection => '已完成';

  @override
  String get taskNoTasks => '還沒有任務';

  @override
  String get taskNoTasksForToday => '今日沒有待辦任務';

  @override
  String get taskNoTasksForWeek => '本週沒有待辦任務';

  @override
  String get taskNoTasksForCourse => '這個課程暫無任務';

  @override
  String get taskDelete => '刪除任務';

  @override
  String get taskDeleteConfirm => '確定刪除這個任務嗎？';

  @override
  String get taskHomeworkDefaultTitle => '課程作業';

  @override
  String get taskAddFromCourse => '新增任務';

  @override
  String get taskViewCourse => '查看課程';

  @override
  String get taskSaved => '任務已儲存';

  @override
  String get taskUpdated => '任務已更新';

  @override
  String get taskDeleted => '任務已刪除';

  @override
  String get icsExportSectionTitle => '匯出日曆';

  @override
  String get icsExportSectionSubtitle => '選擇課程、考試和日程，生成 ICS 日曆並分享';

  @override
  String get icsExportTitle => '匯出日曆';

  @override
  String get icsExportProfileLabel => '課表';

  @override
  String get icsExportProfileSelectTitle => '選擇課表';

  @override
  String get icsExportDateRangeTitle => '日期範圍';

  @override
  String get icsExportStartDate => '開始日期';

  @override
  String get icsExportEndDate => '結束日期';

  @override
  String get icsExportTypesTitle => '日曆內容';

  @override
  String get icsExportCourses => '課程';

  @override
  String get icsExportExams => '考試';

  @override
  String get icsExportSchedules => '日程';

  @override
  String get icsExportButton => '匯出並分享';

  @override
  String get icsExportSharing => '準備日曆…';

  @override
  String get icsExportNoProfiles => '暫無可匯出的課表';

  @override
  String get icsExportDateRangeInvalid => '請選擇不早於開始日期的結束日期';

  @override
  String get icsExportNoSelection => '至少選擇一種日曆內容';

  @override
  String get icsExportSemesterStartRequired => '匯出課程前，請先設定學期開始日期';

  @override
  String get icsExportNoEvents => '所選日期範圍內沒有日曆事件';

  @override
  String get icsExportCancelled => '已取消分享日曆';

  @override
  String get icsExportFailed => '日曆匯出失敗，請稍後再試';

  @override
  String icsExportShared(int count) {
    return '已匯出並分享 $count 個日曆事件';
  }

  @override
  String get icsExportShareText => '這是來自輕誘課表的日曆檔案';

  @override
  String get icsExportShareSubject => '輕誘課表日曆';

  @override
  String get homeNavigationTitle => '首頁與導覽';

  @override
  String get homeMenuCustomizeSectionTitle => '右上角選單';

  @override
  String get homeNavigationSubtitle => '底欄形態、選單與首頁標題';

  @override
  String get homeNavigationFormLabel => '應用形態';

  @override
  String get homeNavigationFormClassic => '經典形態';

  @override
  String get homeNavigationFormClassicSubtitle => '保持現有的頁面與導覽方式';

  @override
  String get homeNavigationFormGlassDock => '玻璃塢';

  @override
  String get homeNavigationFormGlassDockSubtitle => '懸浮玻璃底欄，切換日/週課表';

  @override
  String get glassDockTabWeek => '週課表';

  @override
  String get glassDockTabDay => '日課表';

  @override
  String get glassDockLayoutLabel => '玻璃塢內容佈局';

  @override
  String get glassDockLayoutOverlay => '滿屏懸浮';

  @override
  String get glassDockLayoutOverlaySubtitle => '課表滿屏顯示，底欄浮動在課表之上';

  @override
  String get glassDockLayoutInset => '內容避讓';

  @override
  String get glassDockLayoutInsetSubtitle => '課表底部預留空間，底欄懸浮在下方';

  @override
  String get glassDockInsetClearanceLabel => '避讓高度';

  @override
  String get glassDockRoundActionLabel => '圓鈕功能';

  @override
  String get glassDockButtonIconTitle => '圓鈕圖示';

  @override
  String get glassDockButtonIconDefault => '預設（加號）';

  @override
  String get glassDockButtonIconSearchHint => '搜尋圖示名稱';

  @override
  String get glassDockCustomizeSectionTitle => '底部導覽列';

  @override
  String get glassDockCustomizeTitle => '自訂底欄按鈕';

  @override
  String get homeDockEditorViewCategory => '檢視切換';

  @override
  String get glassDockEntriesSectionTitle => '底欄入口';

  @override
  String get glassDockShowDayTabTitle => '顯示日課表入口';

  @override
  String get glassDockShowWeekTabTitle => '顯示週課表入口';

  @override
  String get glassDockShowAddButtonTitle => '顯示圓鈕';

  @override
  String get glassDockShowAddButtonSubtitle => '在藥丸右側顯示獨立圓鈕，功能與圖示可在下方自訂';

  @override
  String get glassDockButtonBackToWeekLabel => '回本週 / 今天';

  @override
  String get glassDockExtraButtonSemanticLabel => '新增課程';

  @override
  String get homeMenuStyleLabel => '右上角選單樣式';

  @override
  String get homeMenuStyleList => '列表選單';

  @override
  String get homeMenuStyleGrid => '八宮格選單';

  @override
  String get homeMenuStyleListSubtitle => '錨定清單，可自訂';

  @override
  String get homeMenuStyleGridSubtitle => '圖示瓷貼，可自訂';

  @override
  String get homeMenuCustomizeTitle => '自訂選單按鈕';

  @override
  String homeGridCustomizeDetails(int count, int max) {
    return '已啟用 $count/$max 個';
  }

  @override
  String homeGridEditorHintBody(int max) {
    return '最多放置 $max 個按鈕；按住項目拖動即可排序。';
  }

  @override
  String get homeGridEditorEnabledTitle => '已啟用';

  @override
  String get homeGridEditorAvailableTitle => '可新增';

  @override
  String get homeGridEditorRemoveTooltip => '移除';

  @override
  String get homeGridEditorAddTooltip => '新增';

  @override
  String get homeGridEditorResetAction => '恢復預設排列';

  @override
  String get homeGridEditorAllAdded => '所有入口都已啟用';

  @override
  String get homeGridEditorMaxReached => '已達上限';

  @override
  String get homeGridEditorPinnedTooltip => '此入口用於重新開啟本頁，無法移除';

  @override
  String get homeMenuCategoryFeatures => '功能入口';

  @override
  String get homeMenuCategoryData => '資料與同步';

  @override
  String get homeMenuCategoryPreferences => '偏好設定';

  @override
  String get homeMenuCategoryAbout => '關於與支援';

  @override
  String classAlarmLeadMinutesLabel(int minutes) {
    return '提前 $minutes 分鐘';
  }

  @override
  String get classAlarmInvalidTimeToast => '這門課的節次超出時間模板，無法設定鬧鐘';

  @override
  String get classAlarmSheetTitle => '上課提醒';

  @override
  String classAlarmQuickOption(Object minutes) {
    return '上課前 $minutes 分鐘提醒';
  }

  @override
  String get classAlarmCustomOption => '自訂提醒時間…';

  @override
  String classAlarmExistingLabel(Object time) {
    return '已設提醒：$time';
  }

  @override
  String get classAlarmSetToast => '提醒已設定';

  @override
  String get classAlarmRemovedToast => '已取消這堂課的提醒';

  @override
  String get classAlarmPastToast => '所選時間已過，請換一個時間';

  @override
  String get classAlarmNoSemesterToast => '請先在設定中填寫學期開始日期';

  @override
  String get classAlarmActionLabel => '設這節課的鬧鐘';

  @override
  String classAlarmConfirmMessage(String detail) {
    return '將在系統時鐘創建：$detail。系統鬧鐘無法識別假期與調休，停課期間照常響鈴；刪除請在系統時鐘中完成。';
  }

  @override
  String classAlarmVariableSuffix(String days) {
    return '另外，$days的第一節課時間在不同周不一致，這些天未創建鬧鐘。';
  }

  @override
  String get classAlarmEntryTitle => '上課鬧鐘';

  @override
  String get classAlarmGroupSetup => '添加鬧鐘';

  @override
  String get classAlarmGroupBehavior => '響鈴行為';

  @override
  String get classAlarmAddAllTitle => '批量添加上課鬧鐘';

  @override
  String get classAlarmRangeNext4Weeks => '未來 4 周';

  @override
  String get classAlarmRangeNext8Weeks => '未來 8 周';

  @override
  String get classAlarmRangeLabel => '添加範圍';

  @override
  String get classAlarmRangeRemaining => '本週起至學期結束';

  @override
  String get classAlarmRangeWhole => '整學期';

  @override
  String get classAlarmLeadTitle => '提前量';

  @override
  String get classAlarmSkipUiTitle => '跳過確認頁';

  @override
  String get classAlarmSkipUiSubtitle => '嘗試直接寫入鬧鐘，不彈出時鐘確認頁（部分機型不支持）';

  @override
  String get classAlarmOpenClock => '打開系統時鐘';

  @override
  String get classAlarmConfirmTitle => '創建重複鬧鐘？';

  @override
  String get classAlarmNoSchemeToast => '請先在設置中選擇時間模板';

  @override
  String get classAlarmNoDataToast => '所選範圍內沒有找到課表';

  @override
  String get classAlarmAddedToast => '已交給系統時鐘處理';

  @override
  String get classAlarmLaunchFailedToast => '未找到可處理的時鐘應用';

  @override
  String get classAlarmCourseConfirmTitle => '添加這節課的重複鬧鐘？';

  @override
  String classAlarmCourseConfirmMessage(
    String weekday,
    String time,
    int lead,
    String weeks,
  ) {
    return '將在系統時鐘創建每週$weekday $time 的重複鬧鐘（比上課提前$lead分鐘響鈴；上課週次：$weeks）。假期與非上課週仍會響鈴，刪除需在系統時鐘中完成。';
  }

  @override
  String get classAlarmDaySeparator => '、';

  @override
  String get classAlarmDetailSeparator => '；';
}

/// The translations for Chinese, as used in Taiwan (`zh_TW`).
class AppLocalizationsZhTw extends AppLocalizationsZh {
  AppLocalizationsZhTw() : super('zh_TW');

  @override
  String get appTitle => '輕嶼課表';

  @override
  String get appTitleDebug => '輕嶼課表偵錯版';

  @override
  String get appTitleProfile => '輕嶼課表效能版';

  @override
  String get appearanceTitle => '外觀與配色';

  @override
  String get previewTitle => '預覽';

  @override
  String get timetableBackgroundPreview => '課表背景';

  @override
  String get displayModeTitle => '顯示模式';

  @override
  String get displayModeSubtitle => '支持跟隨系統、淺色模式和深色模式';

  @override
  String get themeModeLabel => '主題模式';

  @override
  String get themeModeSystem => '跟隨系統';

  @override
  String get themeModeLight => '淺色模式';

  @override
  String get themeModeDark => '深色模式';

  @override
  String get fontSectionTitle => '應用字體';

  @override
  String get fontSectionSubtitle => '內建 Inter 預設；也可選用系統已安裝的字體';

  @override
  String get fontSectionFootnote =>
      '廠商字體未內建，需系統已預裝才生效，小米通常只有 MiSans 明顯；沒變化時會自動回退，一般不必自行安裝';

  @override
  String get fontModeLabel => '字體選擇';

  @override
  String get fontModeSystem => '應用預設';

  @override
  String get fontModeSansSerif => '系統無襯線';

  @override
  String get fontModeMiSans => 'MiSans';

  @override
  String get fontModeHarmonyOS => '鴻蒙黑體';

  @override
  String get fontModeOppoSans => 'OPPO Sans';

  @override
  String get fontModePingFang => '蘋方';

  @override
  String get fontModeNotoSans => 'Noto Sans';

  @override
  String get fontModeSerif => '襯線體';

  @override
  String get fontModeSongti => '宋體';

  @override
  String get fontModeMonospace => '等寬體';

  @override
  String get languageSectionTitle => '應用語言';

  @override
  String get languageSectionSubtitle => '可跟隨系統，或手動切換到已適配語言';

  @override
  String get languageModeLabel => '語言選擇';

  @override
  String get languageModeSystem => '跟隨系統';

  @override
  String get settingsTitle => '課表設定';

  @override
  String get dailyUsageSectionTitle => '日常使用';

  @override
  String get appearanceEntryTitle => '外觀與配色';

  @override
  String get appearanceEntrySubtitle => '主題模式、字型、首頁標題與彈出視窗磨砂玻璃';

  @override
  String get appearanceThemeDisplaySectionTitle => '主題與顯示';

  @override
  String get layoutSectionEntryTitle => '布局與節次';

  @override
  String get layoutSectionEntrySubtitle => '節次時間、行高、時間列、周末顯示與卡片布局';

  @override
  String get homeWidgetEntryTitle => '桌面小工具';

  @override
  String get homeWidgetEntrySubtitle => '今日課程卡片、小工具背景與顯示資訊';

  @override
  String get reminderNotificationSectionTitle => '提醒與通知';

  @override
  String get userGuideEntryTitle => '使用引導與權限';

  @override
  String get userGuideEntrySubtitle => '簡稱建議、通知、自啟動、電池策略';

  @override
  String get timetableManagementSectionTitle => '課表管理';

  @override
  String get timeSchemeEntryTitle => '時間範本';

  @override
  String get timeSchemeEntrySubtitleNoneSelected => '切換、編輯節次、複製和管理時間範本';

  @override
  String get timeSchemeEntryNotSelected => '未選擇';

  @override
  String timeSchemeEntrySubtitleSelected(String name) {
    return '目前：$name · 切換、編輯節次和複製';
  }

  @override
  String get dataTransferEntryTitle => '資料備份與遷移';

  @override
  String get dataTransferEntrySubtitle => '匯出完整課表檔案，給別人直接匯入使用';

  @override
  String get coupleTimetableEntryTitle => '情侶課表';

  @override
  String get coupleTimetableEntryBound => '已綁定';

  @override
  String get coupleTimetableModeEnableTooltip => '開啟情侶課表';

  @override
  String get coupleTimetableModeDisableTooltip => '關閉情侶課表';

  @override
  String get coupleTimetableTitle => '情侶課表';

  @override
  String get coupleTimetableIntro =>
      '匯出你的課表發給對方，或匯入對方分享的課表檔案，匯入後可在疊加檢視中查看雙方的課程';

  @override
  String get coupleTimetableBoundTitle => '已綁定對方課表';

  @override
  String get coupleTimetableUnboundTitle => '尚未綁定對方課表';

  @override
  String get coupleTimetablePartnerNameLabel => '對方名稱';

  @override
  String coupleTimetableLastImportedAt(String time) {
    return '上次匯入：$time';
  }

  @override
  String get coupleTimetableExportForPartner => '匯出我的課表給對方';

  @override
  String get coupleTimetableImportPartner => '匯入對方課表';

  @override
  String get coupleTimetableUnlink => '解除綁定';

  @override
  String get coupleTimetableOpenOverlay => '進入疊加檢視';

  @override
  String get coupleTimetableImportSuccess => '已匯入對方課表';

  @override
  String get coupleTimetableImportUpdated => '已更新對方課表';

  @override
  String get coupleTimetableUnlinkConfirmTitle => '解除情侶課表綁定？';

  @override
  String get coupleTimetableUnlinkConfirmMessage => '解除後將刪除本機儲存的對方課表，疊加檢視也會關閉';

  @override
  String get coupleTimetableUnlinkSuccess => '已解除綁定';

  @override
  String get coupleTimetablePrivacyHint => '對方只能看到你匯出檔案中所包含的課表內容';

  @override
  String get coupleTimetableOverlayTitle => '情侶疊加';

  @override
  String get coupleTimetableLegendMine => '我的課';

  @override
  String get coupleTimetableLegendPartner => '對方課程';

  @override
  String get coupleTimetableLegendTogether => '一起上課';

  @override
  String get coupleTimetableLegendFree => '共同空閒';

  @override
  String get coupleTimetableSharedFreeTitle => '今日共同空閒';

  @override
  String get coupleTimetableSharedFreeTitleOtherDay => '當日共同空閒';

  @override
  String get coupleTimetableNoSharedFree => '今天沒有共同空閒時段';

  @override
  String get coupleTimetableNoSharedFreeOtherDay => '當日沒有共同空閒時段';

  @override
  String coupleTimetableSharedFreeMeta(int count) {
    return '共 $count 段';
  }

  @override
  String coupleTimetableSharedFreeMoreCount(int count) {
    return '還有 $count 段';
  }

  @override
  String get coupleTimetableSharedFreeUnavailable => '暫時算不出共同空閒';

  @override
  String get coupleTimetableSharedFreeStaleHint => '對方課表可能不是最新';

  @override
  String get coupleTimetablePartnerReadOnlyBadge => '對方課表（唯讀）';

  @override
  String get coupleTimetableNotBoundMessage => '請先匯入對方課表後再查看疊加檢視';

  @override
  String get coupleTimetableShareText => '這是我的課表，匯入到輕嶼課表的情侶課表即可一起查看';

  @override
  String get coupleTimetableShareSubject => '輕嶼課表・情侶課表分享';

  @override
  String get coupleTimetableWeekOffsetTitle => '週次偏移';

  @override
  String get coupleTimetableWeekOffsetSubtitle =>
      '查看你的第 N 週時，讀取對方課表的第 N+偏移 週，例如 +1 表示對方學期進度比你快一週';

  @override
  String get coupleTimetableWeekOffsetZero => '無偏移';

  @override
  String coupleTimetableWeekOffsetSigned(String offset) {
    return '$offset 週';
  }

  @override
  String coupleTimetableWeekOffsetPreview(int myWeek, int partnerWeek) {
    return '查看你的第 $myWeek 週時，顯示對方第 $partnerWeek 週的課';
  }

  @override
  String get coupleTimetableColorsTitle => '疊加顏色';

  @override
  String get coupleTimetableColorsSubtitle =>
      '自訂「我的課」「對方課程」「一起上課」在疊加檢視中的顯示顏色，可按喜好自由搭配';

  @override
  String get partnerImportRequiresSingleProfile => '請匯入單一課表備份檔案，不支援全量備份';

  @override
  String get coupleWebdavTitle => '堅果雲拉取';

  @override
  String get coupleWebdavSubtitle =>
      '登入對方（或你們共用的）堅果雲帳號，自動下載對方上傳的課表檔案，與「雲端同步」帳號獨立，互不影響';

  @override
  String get coupleWebdavNotConnected => '尚未連接堅果雲';

  @override
  String coupleWebdavConnectedAs(String username) {
    return '已連接：$username';
  }

  @override
  String coupleWebdavRemotePathHint(String path) {
    return '遠端檔案路徑：$path';
  }

  @override
  String coupleWebdavLastPulledAt(String time) {
    return '上次拉取：$time';
  }

  @override
  String get coupleWebdavConnect => '連接堅果雲';

  @override
  String get coupleWebdavDisconnect => '中斷連接';

  @override
  String get coupleWebdavPullNow => '立即拉取對方課表';

  @override
  String get coupleWebdavUploadForPartner => '上傳我的課表到堅果雲';

  @override
  String get coupleWebdavLoginSheetTitle => '連接堅果雲（情侶課表）';

  @override
  String get coupleWebdavLoginSheetSubtitle =>
      '請使用應用程式專用密碼，對方需先將課表上傳到約定路徑，或由你在對方裝置上登入同一帳號並上傳';

  @override
  String get coupleWebdavConfirmConnect => '連接並拉取';

  @override
  String get coupleWebdavMySlotLabel => '本機槽位';

  @override
  String get coupleWebdavMySlotHint => '雙方必須選不同槽位：一方選 1，另一方選 2，否則會互相讀不到課表';

  @override
  String get coupleWebdavSlotOne => '槽位 1';

  @override
  String get coupleWebdavSlotTwo => '槽位 2';

  @override
  String get coupleWebdavTestSuccess => '堅果雲連接成功';

  @override
  String get coupleWebdavTestFailed => '連接失敗，請檢查帳號、應用程式專用密碼與網路';

  @override
  String get coupleWebdavPullImported => '已從堅果雲匯入對方課表';

  @override
  String get coupleWebdavPullUpdated => '已從堅果雲更新對方課表';

  @override
  String get coupleWebdavPullUnchanged => '對方課表無變化';

  @override
  String get coupleWebdavUploadSuccess => '已上傳課表，對方可拉取';

  @override
  String get coupleWebdavPartnerFileMissing => '找不到對方課表檔案，請讓對方先上傳';

  @override
  String get coupleWebdavPullFailed => '拉取對方課表失敗，請稍後重試';

  @override
  String get coupleWebdavNotConnectedError => '請先連接堅果雲';

  @override
  String get cloudSyncEntryTitle => '雲端同步';

  @override
  String get cloudSyncEntrySubtitle => '透過堅果雲等多裝置同步課表與匯入資料';

  @override
  String get cloudSyncEntryDisabled => '已關閉';

  @override
  String get cloudSyncEntryEnabled => '已開啟';

  @override
  String get cloudSyncEntrySyncing => '同步中';

  @override
  String get cloudSyncEntryError => '上次同步失敗';

  @override
  String get cloudSyncTitle => '雲端同步';

  @override
  String get cloudSyncIntroTitle => '多裝置同步';

  @override
  String get cloudSyncIntroSubtitle =>
      '設定堅果雲 WebDAV 後，可在手機、平板之間自動同步課表、倉庫帳號與相關設定';

  @override
  String get cloudSyncSettingsSectionTitle => '同步設定';

  @override
  String get cloudSyncSettingsSectionSubtitle => '可切換手動或自動同步';

  @override
  String get cloudSyncEnabledTitle => '啟用雲端同步';

  @override
  String get cloudSyncEnabledSubtitle => '關閉後不會上傳或下載雲端快照';

  @override
  String get cloudSyncProviderTitle => '服務提供商';

  @override
  String get cloudSyncProviderJianguoyun => '堅果雲';

  @override
  String get cloudSyncProviderCustom => '自訂 WebDAV';

  @override
  String get cloudSyncModeTitle => '同步方式';

  @override
  String get cloudSyncModeAuto => '自動同步';

  @override
  String get cloudSyncModeManual => '手動同步';

  @override
  String get cloudSyncAccountTitle => '帳號設定';

  @override
  String get cloudSyncAccountSubtitle =>
      '請使用堅果雲應用程式專用密碼，而不是登入密碼，快照會包含倉庫記住的學校帳號';

  @override
  String get cloudSyncUsernameLabel => '電子郵件 / 使用者名稱';

  @override
  String get cloudSyncUsernameHint => '堅果雲註冊電子郵件';

  @override
  String get cloudSyncPasswordLabel => '應用程式專用密碼';

  @override
  String get cloudSyncPasswordHint => '在堅果雲帳戶安全選項中產生';

  @override
  String get cloudSyncPasswordStoredHint => '已儲存密碼；留空表示繼續使用已儲存的密碼';

  @override
  String get cloudSyncAdvancedTitle => '進階設定';

  @override
  String get cloudSyncBaseUrlLabel => 'WebDAV 網址';

  @override
  String get cloudSyncBaseUrlSecurityNote =>
      '建議使用 HTTPS 加密連線；HTTP 明文連線僅建議在可信網路環境下使用';

  @override
  String get cloudSyncRemoteFolderLabel => '遠端目錄';

  @override
  String get cloudSyncStatusTitle => '同步狀態';

  @override
  String get cloudSyncLastSyncedLabel => '上次同步';

  @override
  String get cloudSyncLastErrorLabel => '最近錯誤';

  @override
  String cloudSyncLastSyncedAt(String time) {
    return '上次同步：$time';
  }

  @override
  String get cloudSyncSyncing => '正在同步…';

  @override
  String cloudSyncLastError(String message) {
    return '最近錯誤：$message';
  }

  @override
  String get cloudSyncHelpTitle => '如何取得堅果雲應用程式密碼';

  @override
  String get cloudSyncHelpBody =>
      '開啟堅果雲網頁或客戶端 → 帳戶資訊 → 安全選項 → 新增應用程式密碼，WebDAV 網址預設為 https://dav.jianguoyun.com/dav/ ';

  @override
  String get cloudSyncTestConnection => '測試連線';

  @override
  String get cloudSyncSyncNow => '立即同步';

  @override
  String get cloudSyncSyncNowSubtitle => '與其他裝置對齊課表：先拉取雲端更新，再上傳本機修改';

  @override
  String get cloudSyncTestSuccess => 'WebDAV 連線成功';

  @override
  String get cloudSyncTestFailed => 'WebDAV 連線失敗，請檢查帳號、應用程式密碼和網路';

  @override
  String get cloudSyncResultUploaded => '已上傳到雲端';

  @override
  String get cloudSyncResultDownloaded => '已從雲端還原';

  @override
  String get cloudSyncResultUpToDate => '本機與雲端已一致';

  @override
  String get cloudSyncResultCancelled => '已取消同步';

  @override
  String cloudSyncResultFailed(String message) {
    return '同步失敗：$message';
  }

  @override
  String get cloudSyncConflictTitle => '偵測到同步衝突';

  @override
  String get cloudSyncConflictBody => '本機和雲端都有新的修改，請選擇保留哪一邊的資料';

  @override
  String get cloudSyncUseRemoteAction => '使用雲端';

  @override
  String get cloudSyncKeepLocalAction => '保留本機';

  @override
  String get cloudSyncAccountSectionTitle => '雲端帳號';

  @override
  String get cloudSyncNotConnectedHint => '連接堅果雲後，可在多裝置間同步課表與匯入資料';

  @override
  String get cloudSyncConnectAccount => '連接堅果雲';

  @override
  String cloudSyncConnectedAs(String email) {
    return '已連接：$email';
  }

  @override
  String get cloudSyncDisconnect => '中斷連線';

  @override
  String get cloudSyncDisconnectTitle => '中斷雲端同步帳號';

  @override
  String get cloudSyncDisconnectBody =>
      '中斷後將清除本機儲存的 WebDAV 憑證，課表資料仍保留在本機，是否繼續？';

  @override
  String get cloudSyncLoginSheetTitle => '連接堅果雲';

  @override
  String get cloudSyncLoginSheetSubtitle => '請使用應用程式專用密碼，不要使用堅果雲登入密碼';

  @override
  String get cloudSyncConfirmConnect => '確認連接';

  @override
  String get cloudSyncConnectSuccess => '帳號連接成功';

  @override
  String get cloudBackupSectionTitle => '可恢復版本';

  @override
  String get cloudBackupSectionSubtitle => '每次同步都會自動保留可恢復版本';

  @override
  String get cloudBackupCurrentLabel => '目前版本';

  @override
  String get cloudBackupCurrentBadge => '目前';

  @override
  String get cloudBackupCreateNow => '立即備份';

  @override
  String get cloudBackupViewAll => '查看全部可恢復版本';

  @override
  String get cloudBackupEmpty => '暫無可恢復版本，同步後會自動生成';

  @override
  String get cloudBackupSourceAuto => '自動備份';

  @override
  String get cloudBackupSourceManual => '手動備份';

  @override
  String get cloudBackupDefaultDeviceLabel => '本機';

  @override
  String get cloudBackupDeviceLabelTitle => '裝置名稱';

  @override
  String get cloudBackupDeviceLabelHint => '在備份列表中顯示，例如「我的手機」';

  @override
  String cloudBackupSummary(int profileCount, int courseCount) {
    return '$profileCount 個課表 · $courseCount 門課程';
  }

  @override
  String get cloudBackupRestoreTitle => '恢復到此備份';

  @override
  String cloudBackupRestoreBody(String time) {
    return '將恢復到 $time 的課表，本機未同步的修改會遺失，是否繼續？';
  }

  @override
  String get cloudBackupRestoreAction => '恢復';

  @override
  String get cloudBackupRestoreSuccess => '已恢復到此備份';

  @override
  String cloudBackupRestoreFailed(String message) {
    return '恢復失敗：$message';
  }

  @override
  String get cloudBackupDeleteTitle => '刪除此備份';

  @override
  String cloudBackupDeleteBody(String time) {
    return '確定刪除 $time 的雲端備份嗎？此操作不可撤銷';
  }

  @override
  String get cloudBackupDeleteSuccess => '備份已刪除';

  @override
  String cloudBackupDeleteFailed(String message) {
    return '刪除失敗：$message';
  }

  @override
  String get cloudBackupCreateSuccess => '備份已儲存到雲端';

  @override
  String cloudBackupCreateFailed(String message) {
    return '備份失敗：$message';
  }

  @override
  String get cloudBackupUploadAsCurrentTitle => '設為目前雲端版本';

  @override
  String get cloudBackupUploadAsCurrentBody =>
      '是否將此備份設為目前雲端版本？建議開啟，可避免其他裝置同步衝突';

  @override
  String get cloudBackupUploadAsCurrentYes => '設為目前版本';

  @override
  String get cloudBackupUploadAsCurrentNo => '僅恢復本機';

  @override
  String get cloudBackupDetailDevice => '裝置';

  @override
  String get cloudBackupDetailSource => '來源';

  @override
  String get cloudBackupDetailSummary => '內容';

  @override
  String get lanEditEntryTitle => '區域網路編輯';

  @override
  String get lanEditEntrySubtitle => '在電腦瀏覽器中編輯目前課表';

  @override
  String get lanEditTitle => '區域網路編輯';

  @override
  String get lanEditIntro =>
      '開啟後，同一 Wi-Fi 或手機熱點下的電腦可透過瀏覽器編輯目前課表，資料不會上傳雲端，關閉後即停止存取';

  @override
  String get lanEditStart => '開啟區域網路編輯';

  @override
  String get lanEditStop => '停止';

  @override
  String get lanEditStatusRunning => '編輯工作階段進行中';

  @override
  String get lanEditAddressLabel => '存取網址';

  @override
  String get lanEditAddressUnavailable => '未偵測到區域網路 IP，請確認已連接 Wi-Fi 或已開啟熱點';

  @override
  String get lanEditPinLabel => 'PIN';

  @override
  String get lanEditPortLabel => '連接埠';

  @override
  String get lanEditCopyAddress => '複製網址';

  @override
  String get lanEditCopied => '網址已複製';

  @override
  String get lanEditHotspotHint => '若宿舍 Wi-Fi 無法存取，請嘗試用手機開熱點，再讓電腦連接該熱點';

  @override
  String get lanEditQrHint => '電腦瀏覽器掃描上方二維碼可開啟控制台（連結已含 PIN，需同一區域網路）';

  @override
  String get lanEditStartFailed => '啟動失敗';

  @override
  String get lanEditConnectedClientsLabel => '已連接';

  @override
  String get lanEditConnectedClientsNone => '暫無';

  @override
  String lanEditConnectedClientsValue(int count) {
    return '$count 台';
  }

  @override
  String get lanEditLastActivityLabel => '最近活動';

  @override
  String get lanEditKeepAliveWhenLeavingTitle => '離開後保持開啟';

  @override
  String get lanEditKeepAliveWhenLeavingSubtitle =>
      '開啟後，返回設定頁不會自動關閉區域網路編輯；關閉後離開本頁即停止';

  @override
  String get aboutSupportSectionTitle => '關於與支持';

  @override
  String get feedbackEntryTitle => '問題回饋';

  @override
  String get feedbackEntrySubtitle => 'Issue、社区渠道和建議反饋入口';

  @override
  String get aboutEntryTitle => '關於軟件';

  @override
  String get aboutEntrySubtitle => '開源說明、版本更新和 GitHub 倉庫';

  @override
  String get setSemesterStartDateAction => '設定開學日期';

  @override
  String get semesterStartDateAction => '開學日期';

  @override
  String get syncCurrentWeekAction => '同步目前周';

  @override
  String semesterWeekCountAction(int count) {
    return '$count 周';
  }

  @override
  String get selectSemesterWeekCountTitle => '選擇學期周數';

  @override
  String get selectSemesterWeekCountSubtitle => '不同學校可按實際教學周數調整';

  @override
  String get unifiedCourseCardColorTitle => '統一課程卡片顏色';

  @override
  String get unifiedCourseCardColorSubtitle => '關閉後繼續使用每門課程自己的顏色';

  @override
  String get importRandomCourseColorTitle => '隨機課程顏色';

  @override
  String get importRandomCourseColorSubtitle => '依課程名與教師自動分配預設色';

  @override
  String get importRandomColorGroupTitle => '隨機配色組';

  @override
  String get colorGroupAll => '全部顏色';

  @override
  String get colorGroupPastel => '馬卡龍系';

  @override
  String get colorGroupVibrant => '活潑系';

  @override
  String get colorGroupDeep => '深色系';

  @override
  String get colorGroupDopamine => '多巴胺系';

  @override
  String get colorGroupSunset => '落日系';

  @override
  String get colorGroupOcean => '海洋系';

  @override
  String get courseRecolorTileTitle => '課表重新配色';

  @override
  String get courseRecolorTileSubtitle => '不用重新匯入，隨時一鍵為全部課程換一套顏色';

  @override
  String get courseRecolorSheetTitle => '課表重新配色';

  @override
  String get courseRecolorSheetDescription =>
      '每次「換一批」都會為全部課程刷一套隨機顏色；不滿意可以切回上一套，或回到匯入時的原色。';

  @override
  String get courseRecolorNewBatchButton => '換一批顏色';

  @override
  String get courseRecolorPrevious => '上一套';

  @override
  String get courseRecolorNext => '下一套';

  @override
  String courseRecolorSchemePosition(int index, int total) {
    return '第 $index/$total 套';
  }

  @override
  String get courseRecolorNoCoursesToast => '尚無課程，請先匯入或新增課程再換顏色';

  @override
  String get courseImportTitle => '匯入課程';

  @override
  String get chooseImportMethodTitle => '選擇匯入方式';

  @override
  String get chooseImportMethodSubtitle =>
      '現在支持傳統 .ics 日歷匯入、識圖匯入，以及從倉庫讀取適配器的教務系統匯入';

  @override
  String get importMethodIcsTitle => '.ics 日歷匯入';

  @override
  String get importMethodIcsSubtitle => '從其他課表應用匯出的日歷檔案';

  @override
  String get importMethodIcsFooter => '進入後直接選擇 .ics 檔案，可追加匯入或替換現有課程';

  @override
  String get importMethodAiTitle => '識圖匯入';

  @override
  String get importMethodAiSubtitle => '從課表截圖識別並匯入';

  @override
  String get importMethodAiFooter =>
      '先複製提示詞，再到豆包專家模式發送截圖和提示詞，把返回的 JSON 複製回來匯入，最後選擇開學日期';

  @override
  String get importMethodWarehouseTitle => '教務系統匯入';

  @override
  String get importMethodWarehouseSubtitle => '登入學校教務系統匯入';

  @override
  String get importMethodWarehouseFooter => '進入後選擇學校和適配器，可直接打開教務網頁登錄並執行匯入';

  @override
  String get importMethodSpreadsheetTitle => '表格匯入';

  @override
  String get importMethodSpreadsheetSubtitle => '填寫 Excel / CSV 模板後匯入';

  @override
  String get importMethodSpreadsheetFooter =>
      '支持 .csv 與 .xlsx，可下載官方模板填寫後選擇檔案匯入';

  @override
  String get spreadsheetImportTitle => '表格匯入';

  @override
  String get spreadsheetScenarioIntro =>
      '輕嶼模板依表頭辨識欄位：必填為課程名、星期、開始節、結束節及週次；其餘為可選，可下載完整模板，或只保留必要欄，亦相容 WakeUp 7 欄格式';

  @override
  String get spreadsheetStep1Subtitle => '下載完整模板填寫，或只保留必填欄與上課週（或開始週+結束週）做最小匯入';

  @override
  String get spreadsheetStep2Subtitle => '填寫完成後另存為 .csv 或直接保留 .xlsx';

  @override
  String get spreadsheetStep3Subtitle => '選擇檔案匯入；如有識別提醒會先展示，再選擇追加或替換';

  @override
  String get spreadsheetSupportedFilesSuffix => '支持 .csv 與 .xlsx（僅讀取第一個工作表）';

  @override
  String get chooseSpreadsheetFileAction => '選擇表格檔案';

  @override
  String get downloadSpreadsheetTemplateAction => '下載輕嶼課表模板';

  @override
  String get spreadsheetImportWarningsTitle => '匯入提醒';

  @override
  String get spreadsheetImportWarningsMessage => '以下行未能匯入，其餘課程可繼續：';

  @override
  String get spreadsheetImportWarningsContinue => '繼續匯入';

  @override
  String get spreadsheetFormatUnrecognized =>
      '未識別表格格式，請使用輕嶼課表模板；也相容 WakeUp 等同列格式';

  @override
  String get icsImportTitle => '.ics 日歷匯入';

  @override
  String get applicableScenarioTitle => '適用場景';

  @override
  String get icsScenarioIntro =>
      '如果你已經能在 WakeUp 等課表應用裡匯入教務系統課程，再匯出為 .ics 檔案，這條路最穩';

  @override
  String stepLabel(String step) {
    return '步骤 $step';
  }

  @override
  String get icsStep1Subtitle => '先在其他課表應用裡匯出 .ics 日歷檔案';

  @override
  String get icsStep2Subtitle => '回到這裡選擇檔案，可選“追加匯入”或“替換現有”';

  @override
  String get icsStep3Subtitle => '匯入前還會讓你確認開學日期，以及課表第 1 周對應校歷第几周';

  @override
  String get supportedFilesTitle => '支持的檔案';

  @override
  String get supportedFilesSuffix => '檔案後綴必須是 .ics';

  @override
  String get supportedFilesImageHint => '如果你手裡只有截圖，不要走這裡，請返回上一頁選擇“識圖匯入”';

  @override
  String get chooseIcsFileAction => '選擇 .ics 檔案';

  @override
  String get timetableAppName => '輕嶼課表';

  @override
  String get switchProfileHint => '點擊切換課表';

  @override
  String get moreTooltip => '更多';

  @override
  String get pleaseSetSemesterStartDate => '請先在課表設定裡填寫開學日期';

  @override
  String get deleteScheduleTitle => '刪除日程';

  @override
  String get deleteLessonTitle => '刪除這節課';

  @override
  String get cancelAction => '取消';

  @override
  String get confirmAction => '確認';

  @override
  String get deleteAction => '刪除';

  @override
  String deletedCourseMessage(String name) {
    return '已刪除：$name';
  }

  @override
  String get deleteFailed => '刪除失敗';

  @override
  String get rescheduleFailed => '調課失敗';

  @override
  String get timetableManagement => '課表管理';

  @override
  String weekLabel(int week) {
    return '第 $week 周';
  }

  @override
  String sectionLabel(int section) {
    return '第 $section 節';
  }

  @override
  String get feedbackTitle => '問題回饋';

  @override
  String get feedbackIntro => '如果你遇到崩溃、課程顯示異常、匯入問題，或者想提交功能建議，可以通過下面這些渠道反饋';

  @override
  String get feedbackIssueHint => '涉及複現步骤、截圖、版本號和日誌的問題，建議優先走 GitHub Issue';

  @override
  String get githubIssueTitle => 'GitHub Issue';

  @override
  String get githubIssueSubtitle => '打開倉庫 Issue 頁面，可提交問題、建議或查看已有反饋記錄';

  @override
  String get openIssuePage => '打開 Issue 頁面';

  @override
  String get copyAddress => '複製地址';

  @override
  String get copiedIssueAddress => '已複製 Issue 地址';

  @override
  String get copyXiaohongshuId => '複製小紅書號';

  @override
  String get copiedXiaohongshuId => '已複製小紅書號';

  @override
  String get copyCoolapkId => '複製酷安號';

  @override
  String get copiedCoolapkId => '已複製酷安號';

  @override
  String get copyQqGroupId => '複製群號';

  @override
  String get copiedQqGroupId => '已複製 QQ 群號';

  @override
  String get copiedWechatOaName => '已複製公眾號名稱';

  @override
  String get feedbackWechatOaOpenHint => '已複製公眾號名稱，請到微信中貼上搜尋';

  @override
  String get feedbackOpeningChannel => '正在打開…';

  @override
  String get feedbackOpenChannelFailed => '無法打開，已複製相關資訊';

  @override
  String get timetableProfilesTitle => '課表管理';

  @override
  String get createTimetableTooltip => '新建課表';

  @override
  String coursesAndWeekSummary(int count, int week) {
    return '$count 門課程 · 第 $week 周';
  }

  @override
  String get moreActionsTooltip => '更多操作';

  @override
  String get switchToThisTimetable => '切換到此課表';

  @override
  String get renameAction => '重新命名';

  @override
  String get duplicateAction => '複製';

  @override
  String get clearCoursesAction => '清空課程';

  @override
  String get usingNow => '正在使用';

  @override
  String switchedToProfile(String name) {
    return '已切換到 $name';
  }

  @override
  String get createTimetableTitle => '新建課表';

  @override
  String get timetableNameLabel => '課表名稱';

  @override
  String get timetableNameHint => '例如：大二下';

  @override
  String get createAction => '建立';

  @override
  String createdProfile(String name) {
    return '已建立課表：$name';
  }

  @override
  String get renameTimetableTitle => '重新命名課表';

  @override
  String get saveAction => '保存';

  @override
  String renamedProfile(String name) {
    return '已重新命名為 $name';
  }

  @override
  String get clearCurrentTimetableTitle => '清空目前課表';

  @override
  String clearCurrentTimetableMessage(String name) {
    return '確定清空“$name”的全部課程嗎？課表設定會保留';
  }

  @override
  String get clearAction => '清空';

  @override
  String clearedProfile(String name) {
    return '已清空課表：$name';
  }

  @override
  String get noCoursesInCurrentProfile => '目前課表已經沒有有課程';

  @override
  String get deleteTimetableTitle => '刪除課表';

  @override
  String deleteTimetableMessage(String name) {
    return '確定刪除“$name”嗎？';
  }

  @override
  String deletedProfile(String name) {
    return '已刪除課表：$name';
  }

  @override
  String get keepAtLeastOneProfile => '至少保留一個課表';

  @override
  String get dataTransferTitle => '資料備份與遷移';

  @override
  String get qrTransferSectionTitle => 'QR 碼面對面傳輸';

  @override
  String get qrTransferSectionSubtitle => '兩台手機靠近，掃碼即可直接傳輸課表與全部設定，無需網路';

  @override
  String get qrTransferSendCurrent => 'QR 碼發送目前課表';

  @override
  String get qrTransferSendAll => 'QR 碼發送全部資料';

  @override
  String get qrTransferScanReceive => '掃碼接收課表資料';

  @override
  String qrTransferFrameProgress(int sent, int total) {
    return '已發送 $sent 幀，約需 $total 幀';
  }

  @override
  String get qrTransferSendHint => '請對方開啟「掃碼接收」，將相機對準此螢幕，保持到接收完成';

  @override
  String get qrTransferStop => '停止發送';

  @override
  String get qrTransferScanTitle => '掃碼接收';

  @override
  String get qrTransferScanHint => '將相機對準對方手機螢幕，保持穩定，等待進度完成';

  @override
  String qrTransferReceiveProgress(int received, int decoded, int total) {
    return '已接收 $received 幀 · 已解出 $decoded/$total';
  }

  @override
  String get qrTransferReceiveComplete => '資料接收完成，正在匯入…';

  @override
  String get qrTransferSessionMismatch => '偵測到不同傳輸內容，請確認只對準一份資料';

  @override
  String get qrTransferChecksumFailed => '傳輸校驗失敗，請重新開始';

  @override
  String get qrTransferRawLengthMismatch => '接收資料長度校驗失敗，請重新開始';

  @override
  String get qrTransferDecompressionFailed => '資料解壓失敗，請重新開始';

  @override
  String get qrTransferPlaintextWarning =>
      'QR 碼傳輸是明文，附近相機可能讀取內容。請先確認來源，未經確認不會覆蓋資料。';

  @override
  String get qrTransferResourceLimit => '接收資料超過 QR 碼傳輸資源上限，請重新開始並使用較小的備份。';

  @override
  String get qrTransferSessionExpired => 'QR 碼傳輸已逾時，請重新開始並只對準一台裝置。';

  @override
  String get qrTransferFullBackupWarning => '確認後，此完整備份會取代本裝置上的資料。';

  @override
  String get qrTransferImportFullBackup => '匯入完整備份';

  @override
  String get qrTransferDecodeFailed => 'QR 碼資料解碼失敗，請重新開始';

  @override
  String get qrTransferRestart => '重新開始';

  @override
  String get qrTransferSampleFps => '取樣幀率';

  @override
  String get qrTransferDecodeFps => '解碼幀率';

  @override
  String get qrTransferReceiveSpeed => '接收速度';

  @override
  String get qrTransferElapsed => '已用時間';

  @override
  String get qrTransferNewFrames => '新增幀';

  @override
  String get qrTransferDuplicateFrames => '重複幀';

  @override
  String get qrTransferBlockSize => '單塊大小';

  @override
  String get qrTransferBlockCount => '資料塊數';

  @override
  String get qrTransferFileData => '檔案資料';

  @override
  String qrTransferFileDataDetail(String rawSize, String compressedSize) {
    return '原始 $rawSize · 壓縮 $compressedSize';
  }

  @override
  String get qrTransferShareWeek => '分享本週課表';

  @override
  String get qrTransferShareSelectedCourses => '分享勾選的課程';

  @override
  String get qrTransferShareTimeTemplate => '分享時間範本';

  @override
  String get qrTransferSelectCoursesDone => '完成';

  @override
  String get dataTransferUndoSuccess => '已撤銷本次匯入';

  @override
  String get dataTransferUndoFailed => '撤銷失敗';

  @override
  String get selectImportModeMerge => '合併變更';

  @override
  String get fullExportTitle => '完整匯出';

  @override
  String get fullExportSubtitle => '支持匯出目前課表，或一次匯出全部課表、時間範本和目前選中狀態';

  @override
  String get exportCurrentTimetable => '匯出目前課表';

  @override
  String get exportAllData => '匯出全部資料';

  @override
  String get fullImportTitle => '完整匯入';

  @override
  String get fullImportSubtitle => '匯入時可以選擇覆蓋目前課表，或直接匯入為一個新課表，建議先匯出自己的備份';

  @override
  String get chooseFileAndImport => '選擇檔案並匯入';

  @override
  String get transferOverviewTitle => '目前可遷移內容';

  @override
  String courseCountBullet(int count) {
    return '課程數量：$count 門';
  }

  @override
  String currentTimetableBullet(String name) {
    return '目前課表：$name';
  }

  @override
  String allTimetablesBullet(int count) {
    return '全部課表：$count 個';
  }

  @override
  String timeSchemeCountBullet(int count) {
    return '時間範本：$count 套';
  }

  @override
  String currentWeekBullet(int week) {
    return '目前周：第 $week 周';
  }

  @override
  String get semesterStartUnsetBullet => '開學日期：未設定';

  @override
  String semesterStartBullet(String date) {
    return '開學日期：$date';
  }

  @override
  String fileExtensionBullet(String extension) {
    return '檔案後綴：.$extension';
  }

  @override
  String get selectImportModeTitle => '選擇匯入方式';

  @override
  String get selectImportModeMessage => '你可以覆蓋目前課表，或者把備份匯入成一個新的独立課表';

  @override
  String get replaceCurrentTimetable => '覆蓋目前課表';

  @override
  String get importAsNewTimetable => '匯入為新課表';

  @override
  String get createdNewTimetableAfterImport => '匯入成功，已建立新的課表';

  @override
  String get backupRestoredSuccess => '匯入成功，備份資料已還原';

  @override
  String get importFailedInvalidFile => '匯入失敗，請確認檔案有效';

  @override
  String get welcomeTitle => '歡迎使用';

  @override
  String get welcomeAppName => '輕嶼課表';

  @override
  String get welcomeSubtitle => '你可以先開始使用，也可以直接匯入課程或從備份還原';

  @override
  String get thirdPartyDisclaimer =>
      '特此聲明：本應用由第三方開發者獨立開發，僅用於學習研究用途，不屬於小米官方軟件，與小米科技有限責任公司無任何隸屬、合作或授權關係。如涉及內容侵權，請權利方聯繫作者，我們將第一時間下架並刪除相關內容。';

  @override
  String get startUsingTitle => '開始使用';

  @override
  String get startUsingSubtitle => '直接進入軟件，並繼續完成首次使用說明';

  @override
  String get importTimetableTitle => '匯入課表';

  @override
  String get importTimetableSubtitle => '從 .ics 檔案或 AI 解析結果匯入課程';

  @override
  String get restoreBackupTitle => '從備份還原';

  @override
  String get restoreBackupSubtitle => '從 .mikcb 備份檔案還原舊資料';

  @override
  String get viewGuideTitle => '查看功能說明';

  @override
  String get viewGuideSubtitle => '先了解權限、超級島和基础設定';

  @override
  String get migrationTitle => '遷移舊資料';

  @override
  String get migrationSafeTitle => '別擔心，這不是資料丢失';

  @override
  String get migrationSafeSubtitle =>
      '我們更換了應用包名，所以桌面上會暫時出現兩個應用圖示，這是正常現象，舊資料仍在舊版應用裡，請先去舊版備份，再回到新版匯入';

  @override
  String get migrationStep1Title => '打開舊版應用';

  @override
  String get migrationStep1Subtitle =>
      '進入“資料備份與遷移”頁面後，請點“匯出全部資料”，不要點“匯出目前課表”，也不要先卸載舊版';

  @override
  String get migrationStep2Title => '保存備份檔案';

  @override
  String get migrationStep2Subtitle =>
      '舊版匯出後會彈出系統分享面板，優先選擇“保存到檔案”，建議存到 下載 / Download 檔案夾';

  @override
  String get migrationStep3Title => '回到目前版本匯入';

  @override
  String get migrationStep3Subtitle =>
      '回到新版後，通過系統檔案選擇器到 下載 / Download 檔案夾選中 .mikcb 備份檔案即可還原，確認新版資料正常後，再卸載舊版應用';

  @override
  String get migrationNoSaveToFilesTitle => '如果沒有有“保存到檔案”';

  @override
  String get migrationNoSaveToFilesSubtitle =>
      '可以先分享到微信任意一個聊天，然後在微信裡點開這個備份檔案並保存，保存後通常會出現在 Download / WeiXin 檔案夾裡，再回到新版選擇這個 .mikcb 檔案匯入';

  @override
  String get openingOldApp => '正在打開舊版...';

  @override
  String get openOldAppForBackup => '打開舊版去備份';

  @override
  String get backupDoneGoImport => '我已完成備份，去匯入';

  @override
  String get startFreshWithoutMigration => '以全新應用開始，不遷移';

  @override
  String get openOldAppFailed => '未能打開舊版應用，請手動返回桌面打開舊版';

  @override
  String get supportCreatorTitle => '請作者喝杯咖啡';

  @override
  String get supportHeroTitle => '支持輕嶼課表繼續更新';

  @override
  String get supportHeroSubtitle => '你的支持會直接用於維護課表、教務匯入適配與體驗優化';

  @override
  String get supportChipFixes => '修複問題';

  @override
  String get supportChipAdapters => '教務適配';

  @override
  String get supportChipPolish => '體驗優化';

  @override
  String get supportMethodTitle => '選擇支持方式';

  @override
  String get wechatLabel => '微信';

  @override
  String get alipayLabel => '支付寶';

  @override
  String get supportWeChatHint => '使用微信掃一掃支持作者';

  @override
  String get supportAlipayHint => '使用支付寶掃一掃支持作者';

  @override
  String get viewLargeImage => '查看大圖';

  @override
  String get saveToGallery => '保存到相冊';

  @override
  String get supportCompleteThanks => '感谢你支持輕嶼課表繼續打磨 ❤️';

  @override
  String get supportConfirmed => '我已經支持了';

  @override
  String get donorListTitle => '鳴谢名單';

  @override
  String get donorListLoadFailed => '暫時無法加載在線鳴谢名單';

  @override
  String get reloadAction => '重新加載';

  @override
  String updatedAtLabel(String time) {
    return '更新於 $time';
  }

  @override
  String get donorListEmpty => '名單還沒有有填寫，你可以直接編輯 docs/donors.json 後重新發布';

  @override
  String get savedToGallery => '已保存到相冊';

  @override
  String get saveToGalleryFailed => '保存到相冊失敗';

  @override
  String saveFailedWithError(String error) {
    return '保存失敗：$error';
  }

  @override
  String get supportRunningBadge => '運行中';

  @override
  String get supportTapQrHint => '點擊放大掃碼';

  @override
  String get supportSaveShort => '保存';

  @override
  String get supportConfirmedShort => '已支持';

  @override
  String get donorSearchHint => '搜暱稱/寄語...';

  @override
  String get donorSortLargeFirst => '大額優先';

  @override
  String get donorSortSmallFirst => '小額優先';

  @override
  String get supportMonthlyGoalLabel => '本月伺服器和證書續期進度';

  @override
  String supportGoalRaised(String raised, String goal) {
    return '已籌: $raised / 目標 $goal';
  }

  @override
  String supportBackerCount(int count) {
    return '已有 $count 人獻出愛心';
  }

  @override
  String get supportDonorListFooter => '名單永久保留 💖';

  @override
  String supportMarqueeThanks(String name, String amount) {
    return '🎉 感謝 $name 贊助 $amount';
  }

  @override
  String get supportMarqueeTail => '輕嶼課表正在穩定運行中，期待你的每一次陪伴與愛心！';

  @override
  String get scanQrWechatTitle => '使用微信掃描二維碼';

  @override
  String get scanQrAlipayTitle => '使用支付寶掃描二維碼';

  @override
  String get scanQrSubtitle => '截圖並導入掃一掃，感謝支持！';

  @override
  String get courseOverviewTitle => '課程總覽與編輯';

  @override
  String get addNewCourseTooltip => '添加新課程';

  @override
  String get emptyCourseOverviewHint => '長按課表或點擊右上角添加課程';

  @override
  String conflictDetectedMessage(int count) {
    return '檢測到 $count 門排課存在實際衝突，課程列表已標記衝突項';
  }

  @override
  String conflictCountLabel(int count) {
    return '衝突 $count 節';
  }

  @override
  String scheduledCountLabel(int count) {
    return '共排課 $count 節';
  }

  @override
  String scheduledCountWithConflictHint(int count) {
    return '共排課 $count 節 · 展開查看衝突詳情';
  }

  @override
  String courseTimeSummary(int day, int start, int end) {
    return '時間: 星期$day 第$start-$end節';
  }

  @override
  String get teacherUnset => '未置';

  @override
  String get locationUnset => '未置';

  @override
  String courseDetailSummary(
    String weekDescription,
    String teacher,
    String location,
  ) {
    return '$weekDescription  教師: $teacher  教室: $location';
  }

  @override
  String courseDetailSummaryWithConflict(
    String weekDescription,
    String teacher,
    String location,
    String conflictSummary,
  ) {
    return '$weekDescription  教師: $teacher  教室: $location\n衝突課程: $conflictSummary';
  }

  @override
  String get confirmDeleteTitle => '確認刪除';

  @override
  String confirmDeleteCourseMessage(String name) {
    return '確定要刪除課程“$name”嗎？';
  }

  @override
  String get currentScheduleTitle => '目前排課';

  @override
  String get currentScheduleSubtitle => '這裡的星期、節次、教室、周次和單雙周只影響目前這一條排課';

  @override
  String get timeSchemeLabel => '上課時間方案';

  @override
  String followCurrentTimetableWithName(String name) {
    return '跟隨目前課表（$name）';
  }

  @override
  String get followCurrentTimetableDescription =>
      '未手動指定時，依上課地點自動匹配時間範本；未命中則跟隨課表主時間範本';

  @override
  String get overrideTimeSchemeDescription => '這門課會單独使用所選時間範本，不跟隨目前課表主時間範本';

  @override
  String get weekdayLabel => '星期';

  @override
  String get startSectionLabel => '開始節次';

  @override
  String get endSectionLabel => '結束節次';

  @override
  String timeRangeLabel(String start, String end) {
    return '時間: $start - $end';
  }

  @override
  String get locationLabel => '上課地點';

  @override
  String get singleLessonWeekTitle => '上課周次';

  @override
  String get singleLessonWeekSubtitle => '單節課只會出現在一個周次裡，適合補課、臨時加課';

  @override
  String get selectWeekLabel => '選擇周次';

  @override
  String get weekSettingsTitle => '周次設定';

  @override
  String get rangeWeeksLabel => '連續周';

  @override
  String get customWeeksLabel => '自定義周';

  @override
  String get startWeekLabel => '開始周';

  @override
  String get endWeekLabel => '結束周';

  @override
  String get allWeeksFilter => '全部';

  @override
  String get oddWeeksFilter => '單周';

  @override
  String get evenWeeksFilter => '雙周';

  @override
  String get rangeWeeksAllHint => '按開始周到結束周連續排課';

  @override
  String get rangeWeeksOddHint => '只保留范圍內的單周';

  @override
  String get rangeWeeksEvenHint => '只保留范圍內的雙周';

  @override
  String get selectAllAction => '全選';

  @override
  String get selectOddWeeksAction => '單周';

  @override
  String get selectEvenWeeksAction => '雙周';

  @override
  String selectedWeeksSummary(int count, String weeks) {
    return '已選 $count 周：第$weeks周';
  }

  @override
  String get courseColorTitle => '課程顏色';

  @override
  String get courseColorQuickSection => '常用顏色';

  @override
  String get customPaletteAction => '調色盤自定義顏色';

  @override
  String get colorPaletteTitle => '調色盤';

  @override
  String get colorHexLabel => '顏色 Hex';

  @override
  String get weekdayMon => '周一';

  @override
  String get weekdayTue => '周二';

  @override
  String get weekdayWed => '周三';

  @override
  String get weekdayThu => '周四';

  @override
  String get weekdayFri => '周五';

  @override
  String get weekdaySat => '周六';

  @override
  String get weekdaySun => '周日';

  @override
  String hueLabel(int value) {
    return '色相 $value';
  }

  @override
  String saturationLabel(int value) {
    return '饱和度 $value%';
  }

  @override
  String brightnessLabel(int value) {
    return '明度 $value%';
  }

  @override
  String get useThisColor => '使用這個顏色';

  @override
  String get selectAtLeastOneWeek => '請至少選擇一個上課周次';

  @override
  String get saveFailed => '保存失敗';

  @override
  String get courseAddedSuccess => '課程添加成功';

  @override
  String get courseUpdatedSuccess => '課程更新成功';

  @override
  String get aboutTitle => '關於軟件';

  @override
  String get loadingText => '讀取中';

  @override
  String versionLabel(String version) {
    return '版本 $version';
  }

  @override
  String get aboutHeroSubtitle =>
      '一個圍繞課表查看、課程提醒和 HyperOS 超級島體驗打磨的 Android 開源項目';

  @override
  String get platformLabel => '平台';

  @override
  String get focusLabel => '重點';

  @override
  String get updateLabel => '更新';

  @override
  String get prereleaseIncluded => '含預發布';

  @override
  String get stableOnly => '正式版';

  @override
  String get aboutUpdatesTitle => '版本更新';

  @override
  String get aboutUpdatesSubtitle => '檢查更新與立即下載';

  @override
  String get aboutChangelogTitle => '更新日誌';

  @override
  String get aboutChangelogSubtitle => '查看所有版本的更新內容';

  @override
  String get aboutPositioningTitle => '項目定位';

  @override
  String get aboutPositioningSubtitle => '這是什麼、適合誰、核心能力是什麼';

  @override
  String get aboutPositioningBullet1 => '支持周視圖課表、課程增刪改、.ics 匯入';

  @override
  String get aboutPositioningBullet2 => '已支持適配學校的教務系統網頁登錄匯入與完整備份遷移';

  @override
  String get aboutPositioningBullet3 =>
      '支持實時通知；HyperOS 3.0.300 起支持超級島 / 焦點通知展示';

  @override
  String get aboutPositioningBullet4 => '支持多課表、時間範本、主題色和卡片樣式自定義';

  @override
  String get aboutImportMigrationTitle => '匯入與遷移';

  @override
  String get aboutImportMigrationSubtitle => '目前匯入方式、備份還原和遷移建議';

  @override
  String get aboutImportMigrationBullet1 =>
      '目前版本已經支持適配學校的教務系統網頁登錄匯入；進入“匯入課程 > 教務系統匯入”後選擇學校和適配器即可';

  @override
  String get aboutImportMigrationBullet2 =>
      '如果你的學校暫時還沒有適配，仍然可以先在 WakeUp 等課表應用裡匯入課程，再匯出為日歷格式，然後在本應用匯入';

  @override
  String get aboutImportMigrationBullet3 =>
      '如果其他人已經在用本應用，也可以直接讓對方匯出完整備份檔案，你在“資料備份與遷移”裡匯入即可直接還原';

  @override
  String get aboutImportMigrationBullet4 =>
      '如果你會抓包、網頁偵錯或 JavaScript，也歡迎去 qingyu_warehouse 參與教務適配補充';

  @override
  String get aboutContributorsTitle => '代碼貢獻者';

  @override
  String get aboutContributorsSubtitle => '開發人員與教務匯入適配者名單';

  @override
  String get aboutRepositoryTitle => '開源倉庫';

  @override
  String get aboutRepositorySubtitle => 'GitHub 倉庫地址、源碼、Release 和反饋入口';

  @override
  String get aboutOpenSourceLicensesTitle => '開源許可';

  @override
  String get aboutOpenSourceLicensesSubtitle => '本應用協議與第三方元件授權';

  @override
  String get aboutOpenSourceLicensesSearchHint => '搜尋元件名稱';

  @override
  String get aboutOpenSourceLicensesAppSectionTitle => '許可說明';

  @override
  String get aboutOpenSourceLicensesAppLicenseLabel =>
      '輕嶼課表原始碼以 GPL-3.0-or-later 釋出。';

  @override
  String get aboutOpenSourceLicensesIntro => '下方列表為本應用使用的開源元件及其授權，點進可查看全文。';

  @override
  String get aboutOpenSourceLicensesExtraSectionTitle => '許可說明';

  @override
  String get aboutOpenSourceLicensesExtraUmeng =>
      '友盟統計等分析服務僅在你同意隱私政策後啟用，適用友盟自身的使用者協議與隱私政策。';

  @override
  String get aboutOpenSourceLicensesExtraNote => '';

  @override
  String aboutOpenSourceLicensesPackagesSectionTitle(int count) {
    return '開源元件（$count）';
  }

  @override
  String aboutOpenSourceLicensesPackageSubtitle(int count) {
    return '$count 份授權文字';
  }

  @override
  String get aboutOpenSourceLicensesLoadFailed => '載入授權失敗，請稍後再試';

  @override
  String get aboutOpenSourceLicensesEmpty => '沒有符合的元件';

  @override
  String get aboutAppLogsTitle => '應用日誌';

  @override
  String get aboutAppLogsSubtitle => '查看執行日誌';

  @override
  String get appLogsShareText =>
      '這是輕嶼課表匯出的應用日誌，包含整個軟體的本地執行記錄，可用於排查更新、匯入、通知、頁面與崩潰問題';

  @override
  String get appLogsShareSubject => '輕嶼課表 - 應用日誌';

  @override
  String get appLogsRecordingEnabled => '正在記錄應用日誌';

  @override
  String get appLogsRecordingDisabled => '應用日誌記錄已關閉';

  @override
  String get appLogsCopyAction => '複製日誌';

  @override
  String get appLogsCopied => '已複製目前日誌';

  @override
  String get appLogsExportAction => '匯出日誌';

  @override
  String get appLogsClearAction => '清空日誌';

  @override
  String get appLogsCleared => '已清空應用日誌';

  @override
  String get appLogsClearFailed => '清空應用日誌失敗';

  @override
  String get appLogsSourceApp => '應用程式';

  @override
  String get appLogsSourceNative => '超級島';

  @override
  String get appLogsRecordingPausedHint => '記錄已關閉，下方為歷史紀錄，關閉後不再新增';

  @override
  String get timeSchemeTitle => '時間範本';

  @override
  String get newSchemeTooltip => '新建範本';

  @override
  String timeSchemeSummary(
    int sections,
    int profiles,
    int courses,
    int overrideCourses,
  ) {
    return '$sections 節 · $profiles 個課表 · $courses 節課程 · $overrideCourses 節副時間表';
  }

  @override
  String get viewUsageAction => '查看使用情況';

  @override
  String get applyToCurrentTimetable => '應用到目前課表';

  @override
  String get editSectionsAction => '編輯節次';

  @override
  String get createTimeSchemeTitle => '新建時間範本';

  @override
  String get timeSchemeNameLabel => '範本名稱';

  @override
  String get timeSchemeNameHint => '例如：本校夏季作息';

  @override
  String get renameTimeSchemeTitle => '重新命名時間範本';

  @override
  String renamedToMessage(String name) {
    return '已重新命名為 $name';
  }

  @override
  String get deleteTimeSchemeTitle => '刪除時間範本';

  @override
  String deleteTimeSchemeMessage(String name) {
    return '確定刪除“$name”嗎？正在使用中的範本不能刪除';
  }

  @override
  String deletedTimeSchemeMessage(String name) {
    return '已刪除時間範本：$name';
  }

  @override
  String get timeSchemeInUseMessage => '該範本正在被課表使用';

  @override
  String get copiedTimeSchemeMessage => '已複製時間範本';

  @override
  String appliedTimeSchemeMessage(String name) {
    return '已應用時間範本：$name';
  }

  @override
  String timeSchemeUsageTitle(String name) {
    return '“$name”的使用情況';
  }

  @override
  String get timeSchemeUsageIntro => '先看總影響范圍，再決定是直接編輯這套範本，還是先複製一套再改';

  @override
  String get profileCountLabel => '課表';

  @override
  String get courseCountLabel => '課程';

  @override
  String get overrideTimeSchemeLabel => '副時間表';

  @override
  String get directlyBoundProfilesTitle => '直接綁定這套範本的課表';

  @override
  String get directlyBoundProfilesEmpty => '目前沒有有課表直接使用這套範本';

  @override
  String get directlyBoundProfilesSubtitle => '這些課表切到這套範本後，預設都會按這套節次時間顯示';

  @override
  String get followMainSchemeCoursesTitle => '跟隨課表主時間表的課程';

  @override
  String get followMainSchemeCoursesEmpty => '目前沒有有課程通過課表主時間表間接使用它';

  @override
  String get followMainSchemeCoursesSubtitle =>
      '這些課程沒有有單独設定副時間表，而是跟著所屬課表一起用這套範本';

  @override
  String get overrideSchemeCoursesTitle => '把它作為副時間表的課程';

  @override
  String get overrideSchemeCoursesEmpty => '目前沒有有課程把它作為副時間表';

  @override
  String get overrideSchemeCoursesSubtitle => '這些課程即使所在課表切換了主範本，也會繼續單独使用這套時間';

  @override
  String get closeAction => '關閉';

  @override
  String get editTimeSchemeTitle => '編輯時間範本';

  @override
  String get backToSchemeList => '返回範本列表';

  @override
  String get currentInUse => '目前使用';

  @override
  String get quickGenerateAction => '快捷生成';

  @override
  String get addSectionAction => '新增一節';

  @override
  String get removeLastSectionAction => '刪除末節';

  @override
  String get resetDefaultAction => '還原預設';

  @override
  String get sectionTimesTitle => '節次時間';

  @override
  String get sectionTimesSubtitle => '如果目前課表正在使用這套範本，節次數量不能小於已使用的最大節次';

  @override
  String get schemeListCurrentLabel => '目前';

  @override
  String get schemeListCountLabel => '數量';

  @override
  String get sectionCountLabel => '節數';

  @override
  String get quickGenerateTimeSchemeTitle => '快捷生成課表時間';

  @override
  String get addBreakRuleAction => '新增大課間規則';

  @override
  String get afterSectionLabel => '第几節後';

  @override
  String get breakDurationMinutesLabel => '休息多久(分)';

  @override
  String get fillNumbersValidationMessage => '請把節數和時長填寫為數字';

  @override
  String get timeSchemeEditorActiveAndCoursesHint =>
      '目前課表和部分課程正在使用這套時間範本，保存後會同步更新所有相關課表和課程';

  @override
  String get timeSchemeEditorActiveHint => '目前課表正在使用這套時間範本，保存後會同步更新所有使用它的課表';

  @override
  String get timeSchemeEditorOverrideHint =>
      '有課程正在把這套範本作為副時間表使用，保存後會同步更新所有引用課程';

  @override
  String get editTimeAction => '編輯時間';

  @override
  String editingSchemeLabel(String name) {
    return '正在編輯：$name';
  }

  @override
  String get copiedTimeSchemeShortMessage => '已複製時間範本';

  @override
  String get unnamedTimeScheme => '未命名範本';

  @override
  String get unsetLabel => '未選擇';

  @override
  String get timeSchemeUsageCourseRefPrefix => '課程引用：';

  @override
  String get mainTimeSchemeLabel => '主時間表';

  @override
  String get overrideTimeSchemeShortLabel => '副時間表';

  @override
  String timeSchemeBottomUsageSingle(String first) {
    return '$first';
  }

  @override
  String timeSchemeBottomUsageMulti(String first, int count) {
    return '$first 等 $count 節課程';
  }

  @override
  String get morningSectionCountLabel => '上午几節';

  @override
  String get morningFirstSectionTimeLabel => '早上第一節時間';

  @override
  String get afternoonSectionCountLabel => '下午几節';

  @override
  String get afternoonFirstSectionTimeLabel => '下午第一節時間';

  @override
  String get eveningSectionCountLabel => '晚上几節';

  @override
  String get eveningFirstSectionTimeLabel => '晚上第一節時間';

  @override
  String get classDurationMinutesLabel => '單節課時長（分鐘）';

  @override
  String get smallBreakDurationMinutesLabel => '小課間時長（分鐘）';

  @override
  String get largeBreakRulesTitle => '大課間規則';

  @override
  String get noLargeBreakRulesHint => '未設定大課間規則，將全部使用小課間時長';

  @override
  String get deleteRuleTooltip => '刪除規則';

  @override
  String get generateAction => '生成';

  @override
  String get liveSettingsTitle => '超級島與通知';

  @override
  String get liveGroupReminders => '提醒';

  @override
  String get liveGroupDisplay => '顯示內容';

  @override
  String get liveGroupMaintenance => '維護與自檢';

  @override
  String get liveReminderTimingEntryTitle => '提醒時段';

  @override
  String get liveReminderTimingEntrySubtitle => '上課前、課中與下課提醒，以及重點提醒切入時機';

  @override
  String get liveBeforeClassDisplayEntryTitle => '上課前提醒顯示';

  @override
  String get liveDuringEndDisplayEntryTitle => '課中與下課提醒顯示';

  @override
  String get liveKeepAliveEntryTitle => '後台保活';

  @override
  String get liveKeepAliveEntrySubtitle => '隱藏後台、後台保活輔助服務和權限入口';

  @override
  String get liveTestingEntryTitle => '測試與診斷';

  @override
  String get liveTestingEntrySubtitle => '發送測試通知，檢查超級島和本地診斷日誌';

  @override
  String get followBeforeClassSetting => '跟隨上課前提醒';

  @override
  String get liveReminderTimingTitle => '提醒時段';

  @override
  String get liveReminderSwitchesTitle => '提醒開關';

  @override
  String get liveReminderSwitchesSubtitle => '不同提醒時段可以自由組合；這些開關互不替代';

  @override
  String get beforeClassReminderTitle => '上課前提醒';

  @override
  String beforeClassReminderSubtitle(int minutes) {
    return '在課程開始前 $minutes 分鐘彈出';
  }

  @override
  String get duringClassReminderTitle => '課中與下課提醒';

  @override
  String get duringClassReminderSubtitle => '只影響上課後到下課前的展示';

  @override
  String get liveClassReminderLeadTitle => '下課前多久切到超級島 / 重點提醒';

  @override
  String get liveClassReminderLeadOptionImmediate => '一上課就切換';

  @override
  String liveClassReminderLeadOptionMinutes(int minutes) {
    return '下課前 $minutes 分鐘切換';
  }

  @override
  String get liveDisplayModeTitle => '展示方式';

  @override
  String get liveDisplayModeSubtitle => '對已啟用的提醒時段生效';

  @override
  String get duringClassStatusNotificationTitle => '課中狀態栏通知';

  @override
  String get duringClassStatusNotificationImmediate => '上課後保留狀態栏通知';

  @override
  String get duringClassStatusNotificationBeforeEnd => '在下課提醒開始前保留普通通知文案';

  @override
  String get duringClassStatusNotificationPersistent =>
      '上課後持續顯示普通課中通知，到下課提醒前再切換';

  @override
  String get enableIslandDisplayTitle => '展示超級島';

  @override
  String get enableIslandDisplaySubtitle => '關閉後不會再尝試觸發系統超級島';

  @override
  String get liveTimeThresholdTitle => '時間阈值';

  @override
  String get liveTimeThresholdSubtitle => '控製上課前彈出、下課前多久切到超級島 / 重點提醒，以及最後秒級倒計時';

  @override
  String get beforeClassPopupLabel => '上課前彈出時間';

  @override
  String beforeClassMinutesOption(int minutes) {
    return '$minutes 分鐘';
  }

  @override
  String get beforeEndSecondsLabel => '下課前秒級提醒阈值';

  @override
  String beforeEndSecondsOption(int seconds) {
    return '$seconds 秒';
  }

  @override
  String timeCorrectionLabel(String value) {
    return '鈴声時間矯正：$value';
  }

  @override
  String get timeCorrectionTitle => '鈴聲時間校正';

  @override
  String get timeCorrectionHelp => '如果學校鈴声比課表快几秒，就調成提前；如果鈴声慢几秒，就調成延後';

  @override
  String get duringEndTimeDisplayLabel => '課中 / 下課提醒時間樣式';

  @override
  String get duringEndTimeDisplayHelp => '控製緊湊提醒裡顯示最近時間還是整段總時間';

  @override
  String get liveDisplayContentTitle => '顯示內容';

  @override
  String get liveDisplayContentSubtitle => '這組設定只影響目前階段，不會改動另一組提醒顯示';

  @override
  String get showCourseNameTitle => '顯示課程名';

  @override
  String get preferShortNameTitle => '優先顯示課程簡稱';

  @override
  String get preferShortNameSubtitle => '建議簡稱控製在 3 個字以內';

  @override
  String get showLocationTitle => '顯示地點';

  @override
  String get showCountdownTitle => '顯示倒計時';

  @override
  String get countdownFormatLabel => '倒計時格式';

  @override
  String get countdownFormatHelp => '純分鐘樣式按分鐘刷新，帶秒樣式按秒刷新';

  @override
  String get showStageTextTitle => '顯示階段狀態文案';

  @override
  String get showStageTextSubtitle => '關閉倒計時後，可繼續顯示“即將上課 / 上課中 / 下課提醒”';

  @override
  String get hidePrefixTextTitle => '隱藏前綴文案';

  @override
  String get hidePrefixTextSubtitle => '例如隱藏“即將上課”這類前綴';

  @override
  String get liveIslandPreviewTitle => '超級島預覽';

  @override
  String get liveIslandPreviewFollowBadge => '正在跟隨「課前提醒顯示」設定，調整課前提醒即可生效';

  @override
  String get liveIslandPreviewStageBeforeClass => '即將上課';

  @override
  String get liveIslandPreviewStageInClass => '上課中';

  @override
  String get liveIslandPreviewStageBeforeEnd => '下課提醒';

  @override
  String liveIslandPreviewUntilClassStart(String time) {
    return '距上課$time';
  }

  @override
  String liveIslandPreviewUntilClassEnd(String time) {
    return '距下課$time';
  }

  @override
  String get liveIslandPreviewSampleCourse => '高等數學';

  @override
  String get liveIslandPreviewSampleCourseShort => '高數';

  @override
  String get liveIslandPreviewSampleLocation => '三教-401';

  @override
  String get beforeClassQuickActionTitle => '上課前快捷操作';

  @override
  String get beforeClassQuickActionSubtitle =>
      '只在上課前提醒的展開通知裡顯示，靜音/免打擾會在下課後自動恢復，重啟手機也會恢復；免打擾首次可能會跳到系統授權頁';

  @override
  String get liveBeforeClassQuickActionAutoTitle => '自動執行';

  @override
  String get liveBeforeClassQuickActionAutoSubtitle =>
      '在上課前自動打開所選模式，下課後自動恢復，重啟手機也會恢復；免打擾需要先在系統設定中授權';

  @override
  String get liveBeforeClassQuickActionAutoOptionOff => '不自動執行';

  @override
  String liveBeforeClassQuickActionAutoOptionMinutes(int minutes) {
    return '上課前 $minutes 分鐘';
  }

  @override
  String liveMiuiLabelSizePreview(String value) {
    return '$value';
  }

  @override
  String get liveIslandVisualTitle => '左側圖示與展開態';

  @override
  String get liveIslandVisualSubtitle => '左側文字圖、展開態大圖示和自定義圖片都按目前階段單独保存';

  @override
  String get liveMiuiLabelImageTitle => '小米島左側文字圖示';

  @override
  String get liveMiuiLabelImageSubtitle => '僅小米手機樣式生效，會把課程名或地點生成到左側圖示位';

  @override
  String get liveMiuiLabelContentLabel => '左側文字內容';

  @override
  String get liveMiuiLabelStyleLabel => '左側圖示樣式';

  @override
  String get liveMiuiLabelLogoTitle => '左側圖示 Logo';

  @override
  String get liveMiuiLabelLogoSubtitle => '僅在「圖示+文字」樣式下生效；未選擇時會繼續使用應用圖示';

  @override
  String liveMiuiLabelLogoCornerRadiusLabel(String value) {
    return '左側圖示圓角 $value';
  }

  @override
  String get liveMiuiLabelLogoCornerRadiusTitle => '左側圖示圓角';

  @override
  String liveMiuiLabelFontSizeLabel(String value) {
    return '左側文字大小 $value';
  }

  @override
  String get liveMiuiLabelFontSizeTitle => '左側文字大小';

  @override
  String liveMiuiLabelOffsetXLabel(String value) {
    return '左側文字水平偏移 $value';
  }

  @override
  String get liveMiuiLabelOffsetXTitle => '左側文字水平偏移';

  @override
  String liveMiuiLabelOffsetYLabel(String value) {
    return '左側文字垂直偏移 $value';
  }

  @override
  String get liveMiuiLabelOffsetYTitle => '左側文字垂直偏移';

  @override
  String get liveMiuiLabelFontWeightLabel => '左側文字粗細';

  @override
  String get liveMiuiLabelRenderQualityLabel => '左側文字清晰度';

  @override
  String get liveMiuiExpandedIconLabel => '展開態大圖示';

  @override
  String get selectImageAction => '選擇圖片';

  @override
  String get replaceImageAction => '更換圖片';

  @override
  String get liveDisplayConfigModeTitle => '配置方式';

  @override
  String get liveDisplayConfigModeSubtitle =>
      '打開後，課中和下課提醒會完全跟隨上課前提醒顯示，下面的独立設定暫時不可編輯';

  @override
  String get followBeforeClassDisplayTitle => '跟隨上課前提醒設定';

  @override
  String get liveKeepAliveTitle => '後台保活';

  @override
  String get liveKeepAliveOptionsTitle => '保活選項';

  @override
  String get liveKeepAliveOptionsSubtitle => '用於提升超級島和提醒在後台場景下的穩定性';

  @override
  String get hideFromRecentsTitle => '從最近任務中隱藏應用';

  @override
  String get hideFromRecentsSubtitle => '開啟後應用會尽量不顯示在最近任務列表中';

  @override
  String get keepAliveServiceTitle => '輕嶼課表後台保活服務';

  @override
  String get keepAliveServiceEnabledSubtitle => '目前已開啟，系統會保持後台保活輔助服務處於可用狀態';

  @override
  String get keepAliveServiceDisabledSubtitle =>
      '目前未開啟，可進入系統無障礙設定手動打開輕嶼課表後台保活服務';

  @override
  String get goEnableAction => '去開啟';

  @override
  String get keepAliveConfirmTitle => '開啟後台保活服務';

  @override
  String get keepAliveConfirmBody =>
      '該服務僅用於在後台重新整理桌面小工具與重排課程提醒，不會讀取螢幕內容，也不會代替你執行任何點選操作。開啟需要在系統設定中授予「無障礙」權限，可隨時關閉。';

  @override
  String get keepAliveConfirmGoAction => '去開啟';

  @override
  String get layoutEntryTitle => '布局與節次';

  @override
  String get layoutEntrySubtitle => '節次時間、行高、時間列、周末顯示與卡片布局';

  @override
  String get remindersSectionTitle => '提醒與通知';

  @override
  String get liveGuideEntryTitle => '使用引導與權限';

  @override
  String get liveGuideEntrySubtitle => '簡稱建議、通知、自啟動、電池策略';

  @override
  String get managementSectionTitle => '課表管理';

  @override
  String timeSchemeEntryCurrentPrefix(String name) {
    return '目前：$name · 切換、編輯節次和複製';
  }

  @override
  String get timeSchemeEntrySubtitle => '切換、編輯節次、複製和管理時間範本';

  @override
  String semesterOverviewCurrentWeek(int current, int total) {
    return '目前第 $current 周 / 共 $total 周';
  }

  @override
  String get semesterStartUnset => '未設定開學日期';

  @override
  String semesterStartSet(String date) {
    return '開學日期：$date';
  }

  @override
  String get setSemesterStartDate => '設定開學日期';

  @override
  String get semesterStartDateLabel => '開學日期';

  @override
  String syncedCurrentWeekMessage(int week) {
    return '已同步到第 $week 周';
  }

  @override
  String get pickSemesterWeekCountTitle => '選擇學期周數';

  @override
  String get pickSemesterWeekCountSubtitle => '不同學校可按實際教學周數調整';

  @override
  String weekCountItem(int count) {
    return '$count 周';
  }

  @override
  String get diagnosticsLogIntro => '支持 Markdown 與原文兩種查看方式，排查時可以直接在手機上看完整日誌';

  @override
  String get diagnosticsRawTab => '原文';

  @override
  String get diagnosticsStructuredTab => '結構化';

  @override
  String get diagnosticsLevelLabel => '等級';

  @override
  String get diagnosticsLevelAll => '全部';

  @override
  String get diagnosticsLevelError => '錯誤';

  @override
  String get diagnosticsLevelWarn => '警告';

  @override
  String get diagnosticsLevelInfo => '資訊';

  @override
  String get diagnosticsLevelDebug => '除錯';

  @override
  String get diagnosticsLevelVerbose => '詳細';

  @override
  String diagnosticsShowingCount(int shown, int total) {
    return '顯示 $shown / $total 條日誌';
  }

  @override
  String get diagnosticsNoMatchingTitle => '目前篩選下沒有日誌';

  @override
  String get diagnosticsNoMatchingSubtitle => '可切換回「全部」，或改看原文繼續排查';

  @override
  String diagnosticsLoadEarlierLabel(int count) {
    return '載入更早日誌（還有 $count 筆）';
  }

  @override
  String get diagnosticsLevelInferred => '推斷等級';

  @override
  String get diagnosticsRawFilteredHint => '原文視圖會跟隨目前等級篩選，只顯示對應日誌區塊';

  @override
  String get diagnosticsTimeSortAscending => '正序';

  @override
  String get diagnosticsTimeSortDescending => '倒序';

  @override
  String get diagnosticsDisplayOptionsTitle => '檢視與排序';

  @override
  String get diagnosticsStreamingHint => '即時更新中，新日誌會自動追加顯示';

  @override
  String get diagnosticsEmptyTitle => '暫無日誌';

  @override
  String get diagnosticsEmptySubtitle => '目前沒有有可顯示的超級島診斷日誌';

  @override
  String get diagnosticsLogTitleFallback => '超級島診斷日誌';

  @override
  String get diagnosticsDeviceInfoTitle => '設備與匯出資訊';

  @override
  String get diagnosticsContentTitle => '日誌內容';

  @override
  String get diagnosticsRecentLogsTitle => '最近日誌';

  @override
  String get diagnosticsUnknownCategory => '未分類事件';

  @override
  String get diagnosticsExportedAt => '匯出時間';

  @override
  String get diagnosticsTime => '時間';

  @override
  String get diagnosticsCategory => '類別';

  @override
  String get diagnosticsMessage => '消息';

  @override
  String get diagnosticsStackTrace => '堆棧';

  @override
  String get firstUseGuideTitle => '首次使用引導';

  @override
  String get guideAndPermissionsTitle => '使用引導與權限';

  @override
  String get refreshStatusTooltip => '刷新狀態';

  @override
  String get guideHeroTitle => '先把這頁做完，再開始用';

  @override
  String get guideHeroSubtitle => '首屏先授權，下面還會明確說明系統版本支持、簡稱設定和匯入方式，記得繼續下滑';

  @override
  String get guideChipPermissions => '權限準備';

  @override
  String get guideChipShortName => '簡稱設定';

  @override
  String get guideChipImport => '匯入課表';

  @override
  String guideChipReadyCount(int count) {
    return '$count/3 已完成';
  }

  @override
  String get guideBottomReachedHint => '你已經滑到最後了，確認無誤後就可以開始使用';

  @override
  String get guideScrollHint => '向下滑動繼續，下面還有 HyperOS 版本說明、權限清單、簡稱設定和匯入方式';

  @override
  String get guideRequestNotificationFirst => '先申請通知權限';

  @override
  String get quickSetupTitle => '首屏快速設定';

  @override
  String get quickSetupSubtitle => '先把最關鍵的 5 個入口放在前面，不用翻到下面再找';

  @override
  String get quickActionNotificationsTitle => '通知設定';

  @override
  String get quickActionNotificationsSubtitle => '先確保能發通知';

  @override
  String get quickActionIslandTitle => '超級島權限';

  @override
  String get quickActionIslandSubtitle => '檢查 promoted 通知';

  @override
  String get quickActionAutoStartTitle => '自啟動';

  @override
  String get quickActionAutoStartSubtitle => '避免後台被殺';

  @override
  String get quickActionBatteryTitle => '電池無限製';

  @override
  String get quickActionBatterySubtitle => '避免提醒中斷';

  @override
  String get quickActionKeepAliveTitle => '後台保活輔助';

  @override
  String get quickActionKeepAliveSubtitle => '提升後台穩定性';

  @override
  String get guidePrivacyConsentLabel => '我已閱讀並同意友盟相關隱私說明';

  @override
  String get guideRequireConsentHint => '請先滑到底部閱讀說明，並勾選同意後開始使用';

  @override
  String get guideContinueHint => '繼續下滑查看完整引導內容';

  @override
  String get exitAppAction => '退出應用';

  @override
  String get continueReadingAction => '繼續查看';

  @override
  String get agreeAndStartAction => '同意並開始使用';

  @override
  String get startUsingAction => '開始使用';

  @override
  String get editSingleLessonTitle => '編輯單節課';

  @override
  String get editCourseTitle => '編輯課程';

  @override
  String get addSingleLessonTitle => '添加單節課';

  @override
  String get addCourseTitle => '添加課程';

  @override
  String get deleteCourseTitle => '刪除課程';

  @override
  String get courseDeleted => '課程已刪除';

  @override
  String get addMethodTitle => '添加方式';

  @override
  String get singleLessonLabel => '單節課';

  @override
  String get recurringLessonLabel => '多節課';

  @override
  String get singleLessonHint => '適合補課、臨時加課，課程只會落在一個周次';

  @override
  String get recurringLessonHint => '適合同一時間連續上很多周的常規課程';

  @override
  String get sharedInfoTitle => '共享資訊';

  @override
  String get sharedInfoHint => '查看共享欄位說明';

  @override
  String get sharedInfoSheetItemCourseName =>
      '課程名稱：課程唯一標識，名稱相同的多條排課視為同一課程；更改名稱將形成獨立課程記錄';

  @override
  String get sharedInfoSheetItemShortName =>
      '課程簡稱：用於超級島等場景的簡短展示，需手動填寫，系統不會自動生成，啟用「優先顯示課程簡稱」後生效；建議控制在 3 個漢字以內';

  @override
  String get sharedInfoSheetItemSharedSync =>
      '共享同步：課程簡稱、顏色、性質、簡介等欄位將同步至同名課程的其他排課記錄';

  @override
  String get reuseExistingCourseLabel => '沿用已有課程';

  @override
  String get reuseExistingCourseHelper => '選一個已有課程，自動帶入課程名、老師和其他共享資訊';

  @override
  String get manualInputLabel => '手動填寫';

  @override
  String get noTemplateCoursesHint => '目前課表裡還沒有有現成課程，先手動錄入一門，後面臨時加課就能直接選了';

  @override
  String get courseNameLabel => '課程名稱';

  @override
  String get courseNameHelper => '作為課程唯一標識；名稱相同的多條排課將歸為同一課程，請填寫完整名稱，請勿為介面顯示而縮寫';

  @override
  String get pleaseEnterCourseName => '請輸入課程名稱';

  @override
  String get courseShortNameOptional => '課程簡稱';

  @override
  String get courseShortNameHelper =>
      '建議填寫，用於超級島等場景的簡短展示，簡稱不會自動生成；啟用「優先顯示課程簡稱」後生效，建議控制在 3 個漢字以內';

  @override
  String get courseShortNameAutoFillAction => '取前兩字';

  @override
  String get teacherLabel => '授課教師';

  @override
  String get courseNatureLabel => '課程性質';

  @override
  String get courseDescriptionOptional => '課程簡介 (可選)';

  @override
  String get currentScheduleHint => '這裡的星期、節次、教室、周次和單雙周只影響目前這一條排課';

  @override
  String followProfileTimeScheme(String name) {
    return '跟隨目前課表（$name）';
  }

  @override
  String get timeSchemeOverrideLabel => '上課時間方案';

  @override
  String get lessonWeeksTitle => '上課周次';

  @override
  String get singleLessonWeekHint => '單節課只會出現在一個周次裡，適合補課、臨時加課';

  @override
  String get rangeWeekLabel => '連續周';

  @override
  String get customWeekLabel => '自定義周';

  @override
  String get allWeeksLabel => '全部';

  @override
  String get oddWeeksLabel => '單周';

  @override
  String get evenWeeksLabel => '雙周';

  @override
  String get allWeeksHint => '按開始周到結束周連續排課';

  @override
  String get oddWeeksHint => '只保留范圍內的單周';

  @override
  String get evenWeeksHint => '只保留范圍內的雙周';

  @override
  String get customPaletteColor => '調色盤自定義顏色';

  @override
  String timeSchemeSetCountValue(int count) {
    return '$count 套';
  }

  @override
  String profileCountValue(int count) {
    return '$count 個';
  }

  @override
  String courseSectionCountValue(int count) {
    return '$count 節';
  }

  @override
  String timeSchemeStartsAt(String start) {
    return '$start 起';
  }

  @override
  String get weekdayShortMonday => '一';

  @override
  String get weekdayShortTuesday => '二';

  @override
  String get weekdayShortWednesday => '三';

  @override
  String get weekdayShortThursday => '四';

  @override
  String get weekdayShortFriday => '五';

  @override
  String get weekdayShortSaturday => '六';

  @override
  String get weekdayShortSunday => '日';

  @override
  String weekdaySectionRange(String weekday, int startSection, int endSection) {
    return '週$weekday $startSection-$endSection節';
  }

  @override
  String timeSchemeUsageReference(
    String profileName,
    String courseName,
    String weekday,
    int startSection,
    int endSection,
    String usageType,
  ) {
    return '$profileName · $courseName（週$weekday $startSection-$endSection節，$usageType）';
  }

  @override
  String weekdaySectionSummary(
    String weekday,
    int startSection,
    int endSection,
  ) {
    return '周$weekday $startSection-$endSection節';
  }

  @override
  String get timeRangeValidationNoCrossDay => '結束時間必須晚於開始時間';

  @override
  String get timeSchemeNameEmptyValidation => '時間模板名稱不能為空';

  @override
  String get liveTimeCorrectionNone => '不校正';

  @override
  String liveTimeCorrectionDelay(int seconds) {
    return '整體延後 $seconds 秒';
  }

  @override
  String liveTimeCorrectionAdvance(int seconds) {
    return '整體提前 $seconds 秒';
  }

  @override
  String liveClassReminderLeadSummaryImmediate(int seconds) {
    return '從上課開始就進入重點提醒顯示，並在距離下課 $seconds 秒切到秒級倒數';
  }

  @override
  String liveClassReminderLeadSummaryKeepNormal(int minutes, int seconds) {
    return '上課後先保留普通課中通知，在距離下課前 $minutes 分鐘切到重點提醒 / 下課提醒，並在最後 $seconds 秒切到秒級倒數';
  }

  @override
  String liveClassReminderLeadSummaryIsland(int minutes, int seconds) {
    return '在距離下課前 $minutes 分鐘切到超級島與重點提醒，並在最後 $seconds 秒切到秒級倒數';
  }

  @override
  String liveClassReminderLeadSummaryFocused(int minutes, int seconds) {
    return '在距離下課前 $minutes 分鐘開始顯示重點提醒，並在最後 $seconds 秒切到秒級倒數';
  }

  @override
  String get liveSettingsEntrySubtitle => '提醒時段、島顯示、通知欄和顯示內容';

  @override
  String get timetableProfilesEntrySubtitle => '新建、切換、複製、重新命名和刪除課表';

  @override
  String get homeTitleSectionTitle => '首頁標題';

  @override
  String get homeTitleSectionSubtitle => '控制首頁左上角課表切換入口的樣式';

  @override
  String get homeTitleStyleLabel => '標題樣式';

  @override
  String get themeSeedSectionTitle => '應用主題色';

  @override
  String get themeSeedSectionSubtitle => '影響頂部欄、強調色和全局主色調';

  @override
  String get frostedSheetSectionTitle => '磨砂玻璃';

  @override
  String get frostedSheetSectionSubtitle =>
      '調整首頁彈出面板的高斯模糊強度與磨砂亮度，滑桿越靠右，白色磨砂層越明顯';

  @override
  String get frostedBlurEnabledTitle => '啟用模糊';

  @override
  String get frostedBlurEnabledSubtitle =>
      '關閉後，彈窗、首頁模糊區域與「回到本週」按鈕僅保留半透明底色，不再取樣模糊';

  @override
  String get frostedSheetPreviewOpenAction => '開啟預覽面板';

  @override
  String get frostedSheetPreviewDemoTitle => '預覽';

  @override
  String get frostedSheetPreviewDemoSubtitle => '磨砂玻璃效果即時預覽';

  @override
  String get frostedSheetBlurLabel => '模糊強度';

  @override
  String get frostedSheetTintLabel => '磨砂亮度';

  @override
  String get timetableBackgroundColorSectionTitle => '課表背景色';

  @override
  String get timetableBackgroundColorSectionSubtitle => '只作用於課表頁面的大背景';

  @override
  String get homePageBackgroundFillLabel => '背景填充';

  @override
  String get homePageBackgroundFillColor => '純色';

  @override
  String get homePageBackgroundFillImage => '圖片';

  @override
  String get homePageBackgroundImageTitle => '背景圖';

  @override
  String get homePageBackgroundImageSubtitle => '在「圖片」模式下，套用於下方勾選的顯示區域';

  @override
  String get homePageWallpaperTitle => '背景圖片';

  @override
  String get homePageWallpaperSubtitle => '全螢幕鋪底一張圖；勾選下方區域決定透出範圍，未勾選區域仍顯示課表背景色';

  @override
  String get homePageBackdropFollowsWeekPagerTitle => '背景隨週次滑動';

  @override
  String get homePageBackdropFollowsWeekPagerSubtitle => '左右切換週次時，背景圖與課表頁面一起移動';

  @override
  String get homePageBackgroundScopeTitle => '背景顯示區域';

  @override
  String get homePageBackgroundScopeSubtitle =>
      '從上到下依序控制各區域是否透出背景圖；未勾選區域仍顯示課表背景色';

  @override
  String get homePageBackgroundScopeStatusBar => '狀態列';

  @override
  String get homePageBackgroundScopeTimetable => '課表區域';

  @override
  String get homePageBackgroundScopeWeekdayBar => '資訊欄';

  @override
  String get homePageBackgroundScopeHeader => '頂欄';

  @override
  String get homePageHeaderBlurTitle => '頂欄高斯模糊';

  @override
  String get homePageHeaderBlurSubtitle => '模糊標題欄（輕嶼課表）區域；勾選「狀態列」時一併模糊狀態列';

  @override
  String get homePageWeekdayBarBlurTitle => '資訊欄高斯模糊';

  @override
  String get homePageWeekdayBarBlurSubtitle => '模糊週次與星期資訊欄，透出下方背景圖';

  @override
  String get homePageTimeColumnBlurTitle => '時間欄高斯模糊';

  @override
  String get homePageTimeColumnBlurSubtitle => '模糊左側節次/時間列，透出下方背景圖';

  @override
  String get homePageRegionBlurSectionSubtitle => '需搭配背景圖使用；模糊強度跟隨「彈窗磨砂玻璃」設定';

  @override
  String get homePagePickImageAction => '選擇圖片';

  @override
  String get homePageSwitchImageAction => '切換照片';

  @override
  String get homePageClearImageAction => '清除圖片';

  @override
  String get homePageImageNotSelected => '未選擇';

  @override
  String get wallpaperPositionPickerTitle => '調整桌布顯示位置';

  @override
  String get wallpaperPositionPickerResetTooltip => '重設置中';

  @override
  String get wallpaperPositionPickerDragHint => '拖曳桌布調整位置';

  @override
  String get wallpaperPositionPickerSwitchWallpaper => '更換桌布';

  @override
  String get wallpaperPositionPickerDone => '完成';

  @override
  String get wallpaperPositionPickerExit => '退出';

  @override
  String get appearanceTextColorsSectionTitle => '文字顏色';

  @override
  String get appearanceTextColorsSectionSubtitle => '自訂課程卡片、星期欄與時間軸文字顏色';

  @override
  String get defaultTimetablePreviewName => '預設課表';

  @override
  String get beforeClassDisplaySettingsTitle => '上課前提醒顯示';

  @override
  String get duringEndDisplaySettingsTitle => '課中／下課提醒顯示';

  @override
  String get liveDisplaySummaryShortName => '簡稱';

  @override
  String get liveDisplaySummaryCourseName => '課程名';

  @override
  String get liveDisplaySummaryLocation => '地點';

  @override
  String liveDisplaySummaryCountdown(String style) {
    return '倒數（$style）';
  }

  @override
  String get liveDisplaySummaryStageText => '階段文字';

  @override
  String get liveDisplaySummaryLeftLabelImage => '圖示';

  @override
  String get liveDisplaySummaryMinimal => '最簡顯示';

  @override
  String get liveDisplaySummaryCountdownShort => '倒數';

  @override
  String liveDisplaySummaryMore(String first, int count) {
    return '$first等$count項';
  }

  @override
  String get guideHyperOsChip => 'HyperOS 3.0.300+';

  @override
  String get guideStatusTitle => '目前狀態';

  @override
  String get guideStatusNotificationPermission => '通知權限';

  @override
  String get guideStatusEnabled => '已開啟';

  @override
  String get guideStatusDisabled => '未開啟';

  @override
  String get guideStatusIslandSupport => '焦點通知 / 超級島';

  @override
  String get guideStatusSystemAllowed => '系統已允许';

  @override
  String get guideStatusEnabledPending => '已開啟但系統暫未確認';

  @override
  String get guideStatusSuggestedCheck => '建議檢查';

  @override
  String get guideStatusBatteryOptimization => '電池優化';

  @override
  String get guideStatusBatteryUnrestricted => '無限制';

  @override
  String get guideStatusBatteryRestricted => '仍受限制';

  @override
  String get guideStatusKeepAlive => '後台保活輔助';

  @override
  String get guideStatusAndroidVersion => 'Android 版本';

  @override
  String get guideStatusVersionUnknown => '未識别';

  @override
  String get guideStatusIslandSystemSupport => '超級島系統支持';

  @override
  String get guideStatusIslandSystemRequirement => '需 HyperOS 3.0.300 及以上';

  @override
  String get guideStatusIslandHint =>
      '如果你主要想用超級島，先確認系統版本至少是 HyperOS 3.0.300，再继续把下面權限清單按顺序點完';

  @override
  String get guidePermissionChecklistTitle => '權限清單';

  @override
  String get guidePermissionChecklistSubtitle => '按這個顺序檢查，最省事，也最不容易漏';

  @override
  String get guideChecklistRequestNotificationTitle => '申请通知權限';

  @override
  String get guideChecklistRequestNotificationSubtitle => '這是所有提醒的前提';

  @override
  String get guideChecklistOpenNotificationTitle => '打開通知設定';

  @override
  String get guideChecklistOpenNotificationSubtitle => '檢查通知总開關、锁屏展示和实時通知權限';

  @override
  String get guideChecklistOpenIslandTitle => '打開焦點通知設定';

  @override
  String get guideChecklistOpenIslandSubtitle =>
      'HyperOS 3.0.300 及以上再檢查 promoted / 超級島通知';

  @override
  String get guideChecklistOpenAutoStartTitle => '打開自啟動設定';

  @override
  String get guideChecklistOpenAutoStartSubtitle => '允许應用開机自啟和後台常驻';

  @override
  String get guideChecklistOpenBatteryTitle => '打開電池策略設定';

  @override
  String get guideChecklistOpenBatterySubtitle => '建議改成無限制，避免上課提醒被中斷';

  @override
  String get guideChecklistOpenKeepAliveTitle => '打開後台保活輔助';

  @override
  String get guideChecklistOpenKeepAliveSubtitle => '進一步提升超級島和提醒在後台場景下的穩定性';

  @override
  String get guideShortNameAdviceTitle => '課程簡稱建議';

  @override
  String get guideShortNameAdviceSubtitle =>
      '超級島支持顯示課程簡稱，簡稱不是自動生成的，需要你在課程编辑裡自己填寫，建議控制在 3 個字以內，顯示会更穩定';

  @override
  String get guideShortNameRecommended => '推荐示例';

  @override
  String get guideShortNameNotRecommended => '不推荐';

  @override
  String get guideShortNameRecommendedExample => '高數 / 概率 / 數控';

  @override
  String get guideShortNameNotRecommendedExample => '高等數学A(1) / 數控技術及應用';

  @override
  String get guideSetCourseShortNameAction => '去設定課程簡稱';

  @override
  String get guideImportMethodsTitle => '課表導入方式';

  @override
  String get guideImportMethodsSubtitle =>
      '目前版本已经支持部分学校的教務系統網頁登入導入；如果你的学校還没適配，也還有其他遷移方式';

  @override
  String get guideImportMethodStep1 =>
      '優先進入“導入課程 > 教務系統導入”，选擇学校和適配器後，直接在應用內打開教務網頁完成導入。';

  @override
  String get guideImportMethodStep2 =>
      '如果你的学校暫時没有適配，可以先在 WakeUp 等課表應用裡導入教務系統課程，再導出日歷格式，最後回到本應用導入。';

  @override
  String get guideImportMethodStep3 =>
      '如果别人已经在用本應用，也可以让对方導出完整備份文件，你直接導入就能恢複課程和設定。';

  @override
  String get guideImportMethodExtra =>
      '如果你会抓包、網頁偵錯或 JavaScript，也欢迎參與学校教務適配补充，让更多学校能直接導入。';

  @override
  String get guideFinalTipsTitle => '最後再看這 3 条';

  @override
  String get guideFinalTip1 =>
      '1. HyperOS 3.0.300 及以上才支持超級島；如果系統版本不够，應用仍可正常發普通提醒。';

  @override
  String get guideFinalTip2 => '2. 先在設定頁調整「上課前弹出」和「課中與臨近下課提醒」的閾值。';

  @override
  String get guideFinalTip3 => '3. 完成系統權限設定後，再用測試通知驗證；如果島区還是偶尔消失，優先檢查自啟動和省電策略。';

  @override
  String get guidePrivacyHelperRequireConsent =>
      '你勾选同意後，代表你已阅讀並同意上述友盟相關說明、隱私內容與免责提示';

  @override
  String get guidePrivacyHelperViewOnly =>
      '這裡保留與首次啟動一致的隱私、第三方 SDK 與免责說明，方便你隨時查看；目前頁面不需要再次勾选同意';

  @override
  String get guidePrivacySectionTitle => '隱私、第三方 SDK 與免责說明';

  @override
  String get guidePrivacyParagraph1 =>
      '本應用主體功能按本地运行方式設計，課表、時間模板、課程記錄和大部分設定預設保存在你的裝置本地。';

  @override
  String get guidePrivacyParagraph2 =>
      '只有在你主動使用檢查更新、下載更新、導入導出等联網功能，或你勾选同意後初始化友盟相關 SDK 時，應用才会與外部服務發生資料交互。';

  @override
  String get guidePrivacyParagraph3 =>
      '本應用接入友盟移動統計 SDK、友盟應用性能监控 SDK 以及高級运营分析依赖庫。它們的服務用途包括移動統計分析、應用性能监控以及高級运营分析相關能力；只有在你勾选同意後，這些 SDK 才会正式初始化。';

  @override
  String get guidePrivacyParagraph4 =>
      '按友盟官方說明，這些 SDK 可能處理的資訊包括：裝置資訊（如 IMEI、MAC、Android ID、OAID、IDFA、OpenUDID、GUID、SIM 卡 IMSI 等）、網路狀態、裝置標識，以及高級运营分析依赖庫涉及的應用列表和地理位置相關資訊。';

  @override
  String get guideRiskTitle => '免责與风险提示';

  @override
  String get guideRiskParagraph1 =>
      '1. 超級島、焦點通知、後台提醒和保活效果依赖系統版本、机型、厂商策略、權限、自啟動、電池策略等外部条件，無法保证所有裝置表现完全一致。';

  @override
  String get guideRiskParagraph2 =>
      '2. 檢查更新、鏡像下載、系統下載器、導入導出與分享等能力依赖網路环境、第三方服務和系統文件能力；若出现失败、限速或文件異常，请以 Release 頁面、你自己保存的備份文件和系統提示為准。';

  @override
  String get guideRiskParagraph3 =>
      '3. 在遷移、導入或覆盖資料前，请先自行確認備份文件完整可用，並妥善保管含有課表資訊的文件；因用户自行刪除、覆盖、分享或保管不當造成的資料問題，需要由用户自行承担相應风险。';

  @override
  String get guideUmengPrivacyLink =>
      '友盟隱私政策：https://www.umeng.com/page/policy';

  @override
  String get liveDiagnosticsUnavailable => '目前還没有可查看的超級島診斷日誌';

  @override
  String get liveDiagnosticsViewerTitle => '超級島診斷日誌';

  @override
  String get liveDiagnosticsShareText => '這是輕嶼課表導出的超級島診斷日誌，可用于排查“超級島没有弹出”等問題';

  @override
  String get liveDiagnosticsShareSubject => '輕嶼課表 - 超級島診斷日誌';

  @override
  String get liveDiagnosticsSnapshotShareText =>
      '這是輕嶼課表目前測試診斷頁導出的超級島狀態快照，可用于排查“超級島没有弹出”等問題';

  @override
  String get liveDiagnosticsSnapshotShareSubject => '輕嶼課表 - 超級島狀態快照';

  @override
  String get liveDiagnosticsNothingToExport => '目前没有可導出的日誌文件，也没有可導出的狀態快照';

  @override
  String get liveDiagnosticsCleared => '已清空超級島診斷日誌，後续会重新開始收集';

  @override
  String get liveDiagnosticsClearFailed => '清空超級島診斷日誌失败';

  @override
  String get liveTestingNotRefreshed => '尚未刷新';

  @override
  String get liveTestingTitle => '測試與診斷';

  @override
  String get liveTestingNotificationTitle => '測試通知';

  @override
  String get liveTestingNotificationSubtitle => '用于驗證超級島、通知栏和課程簡稱等顯示效果';

  @override
  String get liveTestingStartAction => '開始測試';

  @override
  String get liveTestingCancelAction => '取消測試';

  @override
  String get liveTestingSessionRunning => '自檢測試進行中';

  @override
  String get liveTestingSessionCanceled => '已取消自檢測試';

  @override
  String get liveTestingUmengHint => '下面兩個按鈕僅測試版顯示，用于驗證友盟 U-APM 崩溃和卡顿上報';

  @override
  String get liveTestingCrashAction => '崩溃測試';

  @override
  String get liveTestingAnrAction => '異常卡顿測試';

  @override
  String get liveTestingIslandStatusTitle => '上島狀態診斷';

  @override
  String get liveTestingIslandStatusSubtitle => '這裡直接顯示原生实時服務、通知构造结果和不上島原因';

  @override
  String get liveTestingServiceStatusRunning => '服務运行中';

  @override
  String get liveTestingServiceStatusStopped => '服務未运行';

  @override
  String get liveTestingNoIslandReasonTitle => '不上島原因';

  @override
  String get liveTestingNoIslandReasonEmpty => '目前無拦截原因';

  @override
  String get liveTestingRefreshAction => '刷新診斷';

  @override
  String get liveTestingRefreshing => '刷新中';

  @override
  String get liveTestingExportAction => '導出並分享日誌';

  @override
  String get liveTestingExporting => '導出中';

  @override
  String get liveTestingAutoRefreshTitle => '自動刷新';

  @override
  String liveTestingAutoRefreshOn(int seconds) {
    return '每 $seconds 秒自動拉取一次診斷狀態';
  }

  @override
  String get liveTestingAutoRefreshOff => '關閉後只在手動刷新時更新，便于穩定查看目前狀態';

  @override
  String liveTestingRefreshedAt(String time) {
    return '上次刷新：$time';
  }

  @override
  String get liveTestingSectionEnvironment => '环境與權限';

  @override
  String get liveTestingSectionService => '服務狀態';

  @override
  String get liveTestingSectionCourse => '課程資料';

  @override
  String get liveTestingSectionTiming => '時間與階段';

  @override
  String get liveTestingSectionSwitches => '階段開關';

  @override
  String get liveTestingSectionDisplay => '島顯示配置';

  @override
  String get liveTestingSectionNotification => '通知判定结果';

  @override
  String get liveTestingSectionRecentLogs => '最近診斷日誌';

  @override
  String get liveTestingRawDataTitle => '原始偵錯資料';

  @override
  String get liveTestingRawDataSubtitle => '預設折叠，排查時再展開核对完整原生字段';

  @override
  String get liveTestingExpandRawJson => '展開原始 JSON';

  @override
  String get liveTestingExpandRawJsonSubtitle => '避免大段原始字段一直占满頁面';

  @override
  String get liveTestingLocalLogsTitle => '本地診斷日誌';

  @override
  String get liveTestingLocalLogsSubtitle =>
      '一键導出日誌文件，直接通過系統分享發给開發者；也可以清空後重新收集';

  @override
  String get liveTestingClearLogsAction => '清空日誌';

  @override
  String get liveTestingClearingLogs => '清空中';

  @override
  String get liveTestingViewPhoneLogsAction => '查看手机日誌';

  @override
  String get liveTestingMoreTesterOptionsAction => '更多測試者选項';

  @override
  String get yesLabel => '是';

  @override
  String get noLabel => '否';

  @override
  String get liveTestingCurrentNativeFieldsSubtitle => '顯示目前原生診斷字段';

  @override
  String get liveTestingCrashSoon => '即将触發友盟 U-APM 測試崩溃，请重新打開應用查看後台是否收到上報';

  @override
  String get liveTestingAnrSoon =>
      '即将触發约 30 秒主線程卡死，请脱离 flutter run 測試，並在卡死後重新打開應用查看友盟後台';

  @override
  String get liveTestingNoCourseAvailable => '目前没有可測試的課程';

  @override
  String get liveTestingPresetArmedButHidden =>
      '已注入自檢預設課程，但超級島此刻不會彈出——若「上課前提醒」已關閉，島會在課程真正開始後（約 1 分鐘後）才出現';

  @override
  String get liveTestingHolidayBlocked =>
      '目前在假期範圍內，超級島在假期期間不會顯示；如需測試，請先在「課表設定 → 假日標記」中移除涵蓋今天的假期';

  @override
  String get liveTestingNotIslandHoliday =>
      '目前在假期範圍內——超級島在假期期間不會顯示，可在「課表設定 → 假日標記」中管理假期';

  @override
  String get liveTestingCourseTestAction => '選課測試';

  @override
  String get liveTestingCourseTestPickerTitle => '選擇要測試的課程';

  @override
  String get liveTestingCourseTestStageTitle => '選擇要預覽的階段';

  @override
  String get liveTestingCourseTestStageBeforeClass => '課前倒數（島保持約 3 分鐘）';

  @override
  String get liveTestingCourseTestStageDuringClass => '上課中（島保持約 4 分鐘）';

  @override
  String liveTestingCourseTestActiveChip(String course) {
    return '選課測試中 · $course';
  }

  @override
  String get liveTestingCourseTestStopAction => '停止測試';

  @override
  String liveTestingCourseTestStartedToast(String course, String stage) {
    return '已強制啟動「$course」的超級島測試（$stage）。請按 Home 鍵回桌面查看；島會在測試視窗結束後自動收島並恢復正式調度';
  }

  @override
  String get liveTestingCourseTestStoppedToast => '已停止選課測試，正式調度已恢復';

  @override
  String get liveTestingInFlight => '測試進行中，請勿重複點擊，請稍後再試';

  @override
  String get liveTestingProductionHomeHint =>
      '已走正式超級島選課路徑。請按 Home 鍵回到桌面查看（停留在應用內時系統通常不會彈出）';

  @override
  String get liveTestingPresetFallbackNote => '（未檢測到可測試的真實課程，已改用自檢預設課程，不會寫入課表）';

  @override
  String get liveTestingTestCourseNote => '此處顯示備注，可以在課程编辑頁進行設定';

  @override
  String get liveTestingNotificationSent => '已發送上課提醒測試通知，约 8 秒內会進入上課前提醒階段';

  @override
  String sendFailedWithError(String error) {
    return '發送失败: $error';
  }

  @override
  String get homeWidgetSettingsTitle => '桌面小工具';

  @override
  String get homeWidgetTodayCourseTitle => '今日課程工具';

  @override
  String get homeWidgetTodayCourseSubtitle =>
      '首批支持 2×2、2×4、4×4 三种尺寸，點擊小工具会直接打開首頁，課程開始和结束時会主動刷新';

  @override
  String get homeWidgetQuickAddTitle => '快速添加到桌面';

  @override
  String get homeWidgetCheckingPinSupport => '正在檢查目前桌面是否支持應用內添加小工具…';

  @override
  String get homeWidgetPinSupported => '支持的话会直接弹出系統添加確認，不是單独的權限弹窗；確認後即可固定到桌面';

  @override
  String get homeWidgetPinUnsupported =>
      '目前桌面不支持應用內直接添加時，仍可长按桌面 → 小工具 → 輕嶼課表 手動添加';

  @override
  String get homeWidgetBackgroundStyleLabel => '背景样式';

  @override
  String get homeWidgetShowLocationTitle => '顯示地點';

  @override
  String get homeWidgetShowLocationSubtitle => '關閉後改顯週次與課程數';

  @override
  String get homeWidgetShowCountdownTitle => '顯示倒計時';

  @override
  String get homeWidgetShowCountdownSubtitle => '顯示下一節課倒計時';

  @override
  String get homeWidgetCountdownLeadTitle => '倒計時提前量';

  @override
  String get homeWidgetCountdownLeadSubtitle => '設置上課前多少分鐘自動切換到倒計時模式';

  @override
  String get homeWidgetCountdownLeadAlways => '始終顯示';

  @override
  String homeWidgetCountdownLeadMinutes(String minutes) {
    return '上課前 $minutes 分鐘';
  }

  @override
  String get widgetCountdownStyleTitle => '倒計時樣式';

  @override
  String get homeWidgetHideCompletedTitle => '隱藏已上完課程';

  @override
  String get homeWidgetHideCompletedSubtitle => '只顯示未結束的課程';

  @override
  String get homeWidgetShowTomorrowTitle => '下課後顯示明天課程';

  @override
  String get homeWidgetShowTomorrowSubtitle => '今日課後自動顯示明天課程';

  @override
  String get homeWidgetAppearanceTitle => '卡片外觀';

  @override
  String get homeWidgetHeightAdjustTitle => '卡片高度';

  @override
  String get homeWidgetHeightAdjustHint => '範圍 -16 ~ 16，0 為預設檔：正數比預設更高，負數更矮';

  @override
  String get defaultLabel => '預設';

  @override
  String higherByValue(String value) {
    return '更高 $value';
  }

  @override
  String lowerByValue(String value) {
    return '更矮 $value';
  }

  @override
  String get homeWidgetCornerRadiusTitle => '卡片圆角';

  @override
  String get homeWidgetDescriptionTitle => '說明';

  @override
  String get homeWidgetDescriptionText =>
      '小工具目前優先展示今日課程，無課狀態会保持完整卡片，不会出现空白；如果你切换課表或修改样式，桌面工具也会跟着刷新';

  @override
  String homeWidgetPinRequested(String label) {
    return '已發起“$label”添加请求，请在系統弹窗裡確認並放到桌面';
  }

  @override
  String homeWidgetPinUnsupportedManual(String label) {
    return '目前系統桌面不支持應用內直接添加小工具，请长按桌面 → 小工具 → 輕嶼課表，再手動添加“$label”';
  }

  @override
  String get homeWidgetInvalidType => '小工具類型無效，请稍後重試';

  @override
  String homeWidgetPinFailedManual(String label) {
    return '發起添加失败，请长按桌面 → 小工具 → 輕嶼課表，再手動添加“$label”';
  }

  @override
  String get homeWidgetBindingSectionTitle => '各卡片綁定管理';

  @override
  String get homeWidgetBindingFollowActive => '跟隨目前課表';

  @override
  String get homeWidgetBindingEmpty => '桌面上還沒有今日課程卡片，先新增一張再回來綁定';

  @override
  String get homeWidgetBindingSaveFailed => '儲存卡片綁定失敗，請稍後重試';

  @override
  String get homeWidgetBindingMissingToast => '這張卡片綁定的課表已失效，已按普通方式開啟';

  @override
  String get homeWidgetExactAlarmBannerTitle => '精確鬧鐘權限未授予';

  @override
  String get homeWidgetExactAlarmBannerText =>
      '未授予「鬧鐘和提醒」權限時，課程邊界只能非精確刷新，桌面卡片可能延遲更新，建議授權以保證按課程時間精確刷新';

  @override
  String get homeWidgetExactAlarmGrantAction => '去授權';

  @override
  String get homeWidgetExactAlarmOpenFailed => '無法開啟授權頁，請到系統設定中手動開啟「鬧鐘和提醒」權限';

  @override
  String get homeWidgetExactAlarmFallbackHint =>
      '已在系統設定中開啟應用程式資訊，請在其中開啟「鬧鐘和提醒」權限';

  @override
  String get layoutSettingsTitle => '布局與節次';

  @override
  String get layoutDensityTitle => '課表密度';

  @override
  String get layoutAutoFitHeightTitle => '自動充满屏幕高度';

  @override
  String get layoutAutoFitHeightSubtitle => '開啟後会按目前節數自動铺满頁面底部，不再保留下方空隙';

  @override
  String get layoutHideWeekendsTitle => '隱藏周六周日';

  @override
  String get layoutHideWeekendsSubtitle => '開啟後首頁只顯示周一到周五，剩余列宽会自動铺满';

  @override
  String get layoutEnableHapticsTitle => '啟用應用內震動反饋';

  @override
  String get layoutEnableHapticsSubtitle => '關閉後，頁码切换等交互不再触發輕微震動';

  @override
  String pageTransitionSpeedLabel(String speed) {
    return '頁面轉場速度 $speed×';
  }

  @override
  String get pageTransitionSpeedTitle => '頁面轉場速度';

  @override
  String get pageTransitionSpeedSubtitle =>
      '調節進入和返回子頁面時的滑動動畫快慢，數值越大越快，越小越慢；會疊加系統「過渡動畫縮放」設定';

  @override
  String pageTransitionSpeedDurationHint(int milliseconds) {
    return '約 $milliseconds 毫秒';
  }

  @override
  String get layoutTimeColumnDisplayLabel => '首頁時間列顯示';

  @override
  String get layoutTimeColumnWidthLabel => '時間栏宽度';

  @override
  String get layoutBackToCurrentWeekButtonStyleLabel => '「返回本週」按鈕樣式';

  @override
  String get layoutBackToCurrentWeekButtonStyleHelper =>
      '預設維持現在的內嵌樣式；也可以改成周視圖右下角的小型懸浮按鈕';

  @override
  String get layoutBackToCurrentWeekButtonStyleInline => '時間欄內嵌';

  @override
  String get layoutBackToCurrentWeekButtonStyleFloating => '右下角懸浮';

  @override
  String layoutBackToCurrentWeekButtonOpacityLabel(int value) {
    return '懸浮按鈕不透明度 $value%';
  }

  @override
  String get layoutBackToCurrentWeekButtonOpacityTitle => '懸浮按鈕不透明度';

  @override
  String get layoutBackToCurrentWeekButtonOpacitySubtitle => '只對右下角懸浮樣式生效';

  @override
  String layoutCourseCardGapLabel(String value) {
    return '課程卡片間距 $value';
  }

  @override
  String get layoutCourseCardGapTitle => '課程卡片間距';

  @override
  String layoutSectionHeightLabel(String value) {
    return '課表行高 $value';
  }

  @override
  String get layoutSectionHeightTitle => '課表行高';

  @override
  String layoutCompactFontSizeLabel(String value) {
    return '紧凑字級 $value';
  }

  @override
  String get layoutCompactFontSizeTitle => '緊湊字級';

  @override
  String layoutCourseCardFontSizeLabel(String value) {
    return '課程卡片字級 $value';
  }

  @override
  String get layoutCourseCardFontSizeTitle => '課程卡片字級';

  @override
  String get layoutCourseCardDisplayTitle => '課程卡片顯示';

  @override
  String get layoutCourseCardDisplaySubtitle => '預設顯示課程名、老師和教室；其他資訊可按課表自由開關組合';

  @override
  String get layoutShowTeacherTitle => '顯示老師';

  @override
  String get layoutShowClassroomTitle => '顯示教室';

  @override
  String get layoutShowTimeTitle => '顯示時間';

  @override
  String get layoutShowTimeLabelsTitle => '顯示上下課字樣';

  @override
  String get layoutShowTimeLabelsSubtitle => '關閉後僅顯示時間點，不顯示“上課”“下課”文字';

  @override
  String get layoutShowWeeksTitle => '顯示週數';

  @override
  String get layoutShowWeeksSubtitle => '例如第 1-16 周、單双周';

  @override
  String get layoutShowDescriptionTitle => '顯示課程簡介';

  @override
  String get layoutShowDescriptionSubtitle => '預設關閉，空間不足時会最先被壓缩';

  @override
  String get layoutShowOtherWeeksTitle => '顯示非本周課程';

  @override
  String get layoutShowOtherWeeksSubtitle => '非本週課程以半透明灰色顯示';

  @override
  String get layoutVerticalAlignLabel => '垂直排版';

  @override
  String get layoutHorizontalAlignLabel => '水平排版';

  @override
  String get layoutShowConflictBadgeTitle => '首頁顯示冲突小胶囊';

  @override
  String get layoutShowConflictBadgeSubtitle => '關閉後，首頁課表不再对冲突課程顯示“冲突”小胶囊';

  @override
  String layoutConflictOpacityLabel(int value) {
    return '冲突課程透明度 $value%';
  }

  @override
  String get layoutConflictOpacityTitle => '衝突課程透明度';

  @override
  String get layoutConflictOpacitySubtitle => '冲突課程会自動层叠顯示，調低透明度後能同時看到多節課';

  @override
  String get layoutTipsText =>
      '時間模板已移到設定首頁，這裡主要調課表行高、時間列、周末顯示和課程卡片布局；如果你想只改目前課表的時間，先在時間模板裡複制一套再應用';

  @override
  String currentWeekCompact(int week) {
    return '$week周';
  }

  @override
  String get sampleCourseNumericalControl => '數控';

  @override
  String get sampleCourseAdvancedMath => '高數';

  @override
  String get sampleTeacherZhang => '张老師';

  @override
  String get sampleCourseEnglish => '英語';

  @override
  String get sampleTeacherLi => '李老師';

  @override
  String get aboutRepositorySheetTitle => '開源倉庫';

  @override
  String get aboutRepositorySheetHint =>
      '如果你想补学校教務匯入適配，建議同時查看教務適配倉 qingyu_warehouse';

  @override
  String get aboutOpenGitHubAction => '打開 GitHub';

  @override
  String get aboutOpenWarehouseRepoAction => '打開教務適配倉';

  @override
  String get copiedRepositoryAddress => '已複制倉庫地址';

  @override
  String get copiedWarehouseRepositoryAddress => '已複制教務適配倉地址';

  @override
  String get aboutUpdateScreenTitle => '版本更新';

  @override
  String get aboutUpdateStatusTitle => '更新狀態';

  @override
  String get aboutRefreshCheckTooltip => '重新檢查';

  @override
  String get aboutCheckingLatestVersion => '正在檢查最新版本資訊…';

  @override
  String get aboutCheckingForUpdate => '正在檢測更新…';

  @override
  String get aboutReadVersionFailed => '暫時無法讀取版本資訊，请稍後重試';

  @override
  String get aboutReadVersionFailedHint =>
      '如果你目前網路访問 GitHub 不穩定，可稍後再試，或切到下面的國內下載方式後重試';

  @override
  String get aboutViewReleaseAction => '查看 Release';

  @override
  String get aboutDownloadNowAction => '立即下載';

  @override
  String get aboutOpenDownloadPageAction => '打開下載頁';

  @override
  String get aboutCurrentVersionLabel => '目前版本';

  @override
  String get aboutLatestVersionLabel => '最新版本';

  @override
  String get aboutUnreleasedLabel => '未發布';

  @override
  String get aboutVersionChannelLabel => '版本通道';

  @override
  String get aboutPrereleaseChannel => '測試版';

  @override
  String get aboutUpdateAvailableHint =>
      '你现在只需要點下面的“立即下載”即可，測速、鏡像和測試版都已经收進後面的高級选項裡';

  @override
  String get aboutUpdateNoUpdateHint =>
      '目前版本已经可正常使用；如果你要體验測試版，可以在後面的高級选項裡打開測試版檢測';

  @override
  String aboutUpdatedAt(String time) {
    return '更新時間：$time';
  }

  @override
  String get aboutUpdateNowTitle => '立即更新';

  @override
  String get aboutUpdateNowAndroidSubtitle =>
      '普通使用只需要點一次立即下載，下載慢、下載失败、要换線路時，再去下面的高級选項';

  @override
  String get aboutUpdateNowOtherSubtitle => '目前平台会直接打開下載頁面，不会在應用內安装';

  @override
  String get aboutMirrorDownloadHint => '目前会優先使用國內下載，大多數國內網路直接點“立即下載”就行';

  @override
  String get aboutOriginalDownloadHint => '目前会優先使用國際源下載，如果下載慢或打不開，建議先切回“國內下載”';

  @override
  String get aboutUseSystemDownloaderAction => '使用系統下載器下載';

  @override
  String get aboutOpenReleasePageAction => '打開 Release 頁面';

  @override
  String get aboutDownloadMethodTitle => '下載方式';

  @override
  String get aboutDownloadMethodSubtitle =>
      '預設推荐國內下載，只有你能穩定访問 GitHub 時，再切到國際源下載';

  @override
  String get aboutDownloadMethodMirror => '國內下載';

  @override
  String get aboutDownloadMethodOriginal => '國際源下載';

  @override
  String aboutMirrorModeHintRecommended(String current, String recommended) {
    return '目前使用國內下載 · $current，系統最近測速更推荐“$recommended”，需要時可在後面的高級选項裡切换';
  }

  @override
  String aboutMirrorModeHintCurrent(String current) {
    return '目前使用國內下載 · $current，如果下載慢或失败，再到後面的高級选項裡測速、换線路或填寫自定义地址';
  }

  @override
  String get aboutOriginalModeHint =>
      '目前使用國際源下載，只有你網路能穩定访問 GitHub 時才建議這样設定；否則请切回國內下載';

  @override
  String get aboutReleaseNotesTitle => '本次更新說明';

  @override
  String get aboutReleaseNotesSubtitle => '顯示目前檢測到版本的 Release 說明';

  @override
  String get aboutAdvancedOptionsTitle => '高級选項';

  @override
  String get aboutAdvancedOptionsSubtitle => '只有下載慢、要手動切線路、或要檢測測試版時再展開';

  @override
  String get aboutMirrorSectionTitle => '下載線路與鏡像';

  @override
  String get aboutMirrorSectionMirrorHint =>
      '目前使用國內下載，這裡可以手動切線路、測速推荐，或填寫自定义下載地址';

  @override
  String get aboutMirrorSectionOriginalHint =>
      '你现在使用的是國際源下載，下面的線路設定只有在切回“國內下載”後才会生效';

  @override
  String get aboutFillCustomMirrorFirst => '先填寫自定义下載地址';

  @override
  String get aboutCurrentCustomMirrorTitle => '目前自定义下載地址';

  @override
  String get aboutCurrentMirrorTitle => '目前下載線路地址';

  @override
  String get aboutCurrentCustomMirrorHint => '目前正在使用你手動填寫的下載地址';

  @override
  String get aboutCurrentMirrorHint => '如果目前線路访問失败，可以切到其他內置線路，或改用自定义地址';

  @override
  String get aboutProbeMirrorsAction => '測速並推荐';

  @override
  String get aboutProbingMirrors => '測速中…';

  @override
  String get aboutEditCustomMirrorAction => '修改自定义地址';

  @override
  String get aboutSetCustomMirrorAction => '填寫自定义地址';

  @override
  String aboutSwitchToRecommendedAction(String label) {
    return '切到推荐：$label';
  }

  @override
  String get aboutMirrorDisabledHint =>
      '目前没有使用國內下載，所以這裡的線路設定暫時不会生效，需要的话，请先在上面的“下載方式”裡切回國內下載';

  @override
  String get aboutRecentProbeResultsTitle => '最近測速结果';

  @override
  String get aboutUnavailable => '不可用';

  @override
  String get aboutRecommended => '推荐';

  @override
  String get aboutCheckPrereleaseTitle => '檢測測試版本';

  @override
  String get aboutCheckPrereleaseSubtitle => '打開後会把測試版也纳入更新檢查；普通使用建議關閉';

  @override
  String get aboutUpdatePromptTitle => '彈窗提醒';

  @override
  String get aboutUpdatePromptSubtitle => '發現新版本時在首頁自動彈窗，關閉後僅顯示紅點角標';

  @override
  String get aboutDiagnosticsTitle => '測試與診斷';

  @override
  String get aboutDiagnosticsSubtitle => '只有遇到“超級島没弹出”或需要给開發者反饋時再展開';

  @override
  String get aboutRecordDiagnosticsTitle => '記錄應用日誌';

  @override
  String get aboutRecordDiagnosticsSubtitle => '打開後会在本地持续記錄關键日誌，僅用于排查“该弹不弹”等問題';

  @override
  String get aboutExportDiagnosticsAction => '匯出診斷日誌';

  @override
  String get aboutViewPhoneLogsAction => '查看手机日誌';

  @override
  String get aboutClearAndRecollectAction => '清空並重新收集';

  @override
  String get aboutLiveDiagnosticsEnabled => '已開啟超級島診斷日誌';

  @override
  String get aboutLiveDiagnosticsDisabled => '已關閉超級島診斷日誌';

  @override
  String get aboutNoDiagnosticsExportYet => '還没有可匯出的超級島診斷日誌';

  @override
  String get aboutProbeNoMirrorFound => '測速完成，但暫時没有發现可用鏡像線路';

  @override
  String aboutProbeCurrentFastest(String label) {
    return '測速完成，目前線路“$label”已是最快可用線路';
  }

  @override
  String aboutProbeRecommendSwitch(String label) {
    return '測速完成，推荐切换到“$label”';
  }

  @override
  String get switchAction => '切换';

  @override
  String aboutSwitchToMirrorAfterError(String error) {
    return '$error，可切到國內鏡像後再試';
  }

  @override
  String aboutSwitchPresetAfterError(String error, String label) {
    return '$error，建議切换到“$label”後重試';
  }

  @override
  String get aboutSetMirrorSourceTitle => '設定鏡像源';

  @override
  String get aboutMirrorPrefixLabel => '鏡像前缀';

  @override
  String get aboutMirrorPrefixInvalid => '鏡像源格式不正確，请輸入完整的 http 或 https 地址';

  @override
  String get aboutMirrorSaved => '鏡像源已保存';

  @override
  String get aboutDownloadCancelled => '已取消下載';

  @override
  String get aboutInstallReady => '安装包已准備好，已尝試打開安装界面；如果系統没有弹出，请稍後从通知或文件管理器手動安装';

  @override
  String get aboutUpdatePackageTitle => '輕嶼課表更新包';

  @override
  String get aboutUpdatePackageDescription => '已交给系統下載管理器下載，完成後可直接从系統通知安装';

  @override
  String get aboutSystemDownloaderQueued => '已交给系統下載管理器，请在系統通知或下載列表裡查看進度';

  @override
  String get aboutSystemDownloaderFailed => '調用系統下載管理器失败';

  @override
  String get aboutDownloadCancelling => '正在取消下載…';

  @override
  String aboutDownloadingBytes(String value) {
    return '正在下載更新 $value';
  }

  @override
  String aboutDownloadingPercent(String value) {
    return '正在下載更新 $value%';
  }

  @override
  String get aboutMirrorUnknownSizeHint => '鏡像源未返回文件总大小，先顯示已下載體积';

  @override
  String get aboutCancelDownloadAction => '取消下載';

  @override
  String get aboutContinueDownloadAction => '繼續下載';

  @override
  String get aboutDismissDialogAction => '關閉彈窗';

  @override
  String get aboutContributorsScreenTitle => '代码贡献者';

  @override
  String get aboutDevelopersTitle => '開發人员';

  @override
  String get aboutDeveloperMaintainerSubtitle => '輕嶼課表開發與維護';

  @override
  String get aboutWarehouseMaintainersTitle => '教務匯入適配者';

  @override
  String get aboutWarehouseMaintainersIntro =>
      '以下名單来自 qingyu_warehouse 適配倉的 maintainer 字段汇总，若本地已有缓存，会先顯示缓存，再後台刷新';

  @override
  String aboutWarehouseMaintainersLoadFailed(String error) {
    return '暫時無法讀取適配者名單：$error';
  }

  @override
  String get aboutWarehouseMaintainersEmpty => '目前還没有讀取到適配者資訊';

  @override
  String aboutWarehouseMaintainerCount(int count) {
    return '$count 個適配項';
  }

  @override
  String get aboutParticipateWarehouseTitle => '參與教務適配';

  @override
  String get aboutParticipateWarehouseSubtitle =>
      '如果你会抓包、網頁偵錯、JavaScript，或者愿意长期維護自己学校的教務系統，欢迎去 qingyu_warehouse 提交新的学校適配與修複';

  @override
  String get importFileReadFailed => '無法讀取所选文件';

  @override
  String get importCleartextBlockedHint => '該站點暫不支援 HTTPS 存取且未在明文白名單內，無法在此開啟';

  @override
  String get importReplaceExistingTitle => '匯入課程';

  @override
  String importReplaceExistingMessage(String name) {
    return '匯入 $name 時，是否替换现有課程？此操作也會清空目前課表上的獨立日程（如自習、會議等）。';
  }

  @override
  String get importNoCoursesRecognized => '未識别到可匯入課程';

  @override
  String get importConfirmSemesterMappingTitle => '確認開学日期和周次对應';

  @override
  String get importConfirmSemesterMappingSubtitleIcs =>
      '请选擇学校校歷的開学日期，系統已根据文件裡最早的上課日期给出預設周次对應，你也可以手動調整';

  @override
  String importOverwriteCount(int count) {
    return '已覆盖匯入 $count 条課程';
  }

  @override
  String importUpdatedCount(int count) {
    return '已更新課表：新增或更新 $count 条課程';
  }

  @override
  String get importNoCourseChanges => '没有需要新增或更新的課程';

  @override
  String get aiImportTitle => '識圖匯入';

  @override
  String aiPreviewSummary(
    int courseCount,
    int sectionCount,
    String warningSuffix,
  ) {
    return '識别到 $courseCount 門課，最高到第 $sectionCount 節$warningSuffix';
  }

  @override
  String aiWarningCountSuffix(int count) {
    return '，$count 条提醒';
  }

  @override
  String get aiWorkflowCompactTitle => '複制提示词 -> 豆包識圖 -> 匯入';

  @override
  String get aiWorkflowCompactSubtitle => '豆包專家模式 -> 複制 JSON -> 选擇開学日期';

  @override
  String get aiWorkflowTitle => '複制提示词 -> 豆包識圖 -> 粘贴 JSON -> 匯入';

  @override
  String get aiWorkflowSubtitle =>
      '先複制提示词，再到豆包左下角切换為專家模式，把課表截圖和提示词一起發過去，把豆包返回的 JSON 複制回這裡，點擊匯入後再选擇開学日期';

  @override
  String get aiPromptShortAction => '提示词';

  @override
  String get aiExpertModeSuggestion => '建議豆包專家模式，支持多圖，截圖需带星期表头';

  @override
  String get aiHintExpertMode => '先切到豆包專家模式';

  @override
  String get aiHintSendScreenshot => '截圖和提示词一起發';

  @override
  String get aiHintCopyJsonBack => '返回结果複制 JSON';

  @override
  String get aiHintPickSemesterAfterImport => '匯入後再选開学日期';

  @override
  String get jsonLabelShort => 'JSON';

  @override
  String get aiPasteJsonTitle => '粘贴 AI 返回的 JSON';

  @override
  String aiCourseCountChip(int count) {
    return '$count 門課';
  }

  @override
  String get aiParseFailedChip => '解析失败';

  @override
  String get aiPasteJsonHintShort => '粘贴 AI 返回的 JSON';

  @override
  String get aiPasteJsonHintLong =>
      '把豆包返回的 JSON 原样粘贴到這裡，然後點擊匯入，支持纯 JSON，也兼容 ```json 代码块';

  @override
  String get detailAction => '详情';

  @override
  String get aiParseErrorTitle => '解析错误';

  @override
  String get viewDetailsAction => '查看详情';

  @override
  String get aiWorkflowFooter =>
      '複制提示词 -> 豆包發送截圖和提示词 -> 把 JSON 贴回這裡 -> 點擊匯入 -> 选擇開学日期';

  @override
  String get previewAction => '預覽';

  @override
  String get confirmImportAction => '確認匯入';

  @override
  String get promptCopiedHint => '提示词已複制，去豆包發送截圖和提示词';

  @override
  String get clipboardNoText => '剪贴板裡没有可用文本';

  @override
  String get aiPromptSheetTitle => '識圖提示词';

  @override
  String get aiPromptSheetSubtitle =>
      '建議使用豆包，先把豆包左下角切换為專家模式，再把下面整段提示词和課表截圖一起發過去，让它只返回 JSON，生成後把 JSON 複制回本頁，點擊匯入後再选擇開学日期';

  @override
  String get aiPreviewTitle => '解析預覽';

  @override
  String get aiPasteJsonFirst => '请先粘贴 AI 返回的 JSON';

  @override
  String get aiParseFailedIncompleteJson => '解析失败，请確認粘贴的是完整 JSON';

  @override
  String get importAiResultTitle => '匯入 AI 解析结果';

  @override
  String get importAiReplaceMessage =>
      '是否用目前這份 AI 解析结果替换现有課程？此操作也會清空目前課表上的獨立日程（如自習、會議等）。';

  @override
  String get importConfirmSemesterMappingSubtitleAi =>
      '请选擇学校校歷的開学日期，再確認課表裡的第 1 周对應校歷第几周，如果学校第一周没課，這裡通常要改成第 2 周';

  @override
  String aiWarningExtraSuffix(int count) {
    return '，另有 $count 条識别提醒';
  }

  @override
  String get pasteAction => '粘贴';

  @override
  String get importConfirmSemesterMappingSubtitleWarehouse =>
      '教務脚本已返回課程周次，请確認校歷開学日期；如果学校前几周没有課，可把“課表第 1 周”对應到校歷後面的周次';

  @override
  String aiPreviewCourseCount(int count) {
    return '課程數量：$count';
  }

  @override
  String aiPreviewMaxSection(int section) {
    return '最大節次：第 $section 節';
  }

  @override
  String get aiPreviewWarningsTitle => '識别提醒';

  @override
  String get aiPreviewCoursesTitle => '課程預覽';

  @override
  String aiPreviewRemainingCourses(int count) {
    return '其余 $count 条将在匯入後寫入目前課表';
  }

  @override
  String get warehouseMissingSchoolTitle => '学校列表裡没有你的学校？';

  @override
  String get warehouseMissingSchoolSubtitle =>
      '去反饋頁提一個 Issue 就行，建議一起寫上学校名稱、教務系統網址、登入後課表頁連結或截圖，這样更方便补適配';

  @override
  String get laterAction => '稍後再說';

  @override
  String get goFeedbackAction => '去反饋頁';

  @override
  String get warehouseFeedbackMissingSchoolTitle => '缺少学校？去反饋';

  @override
  String get warehouseCustomDebugTitle => '自訂偵錯';

  @override
  String get warehouseImportExecutionLogTitle => '課表匯入執行日誌';

  @override
  String get warehouseImportExecutionLogMenuLabel => '課表匯入執行日誌';

  @override
  String get warehouseImportExecutionLogShareText =>
      '這是輕嶼課表匯出的教務匯入執行日誌，包含腳本注入、橋接訊息、逾時與匯入結果等過程記錄，可直接回饋給開發人員排查問題';

  @override
  String get warehouseImportExecutionLogShareSubject => '輕嶼課表 - 課表匯入執行日誌';

  @override
  String get warehouseImportExecutionLogEmpty =>
      '暫無匯入執行記錄。請先開啟教務網頁並執行匯入腳本，再回來查看。';

  @override
  String get warehouseRootLoadFailedTitle => '暫時無法讀取適配倉';

  @override
  String get searchSchoolHint => '搜索学校名稱、首字母或代码';

  @override
  String get clearSearchTooltip => '清空';

  @override
  String get noMatchingSchools => '没有找到匹配的学校';

  @override
  String get noAvailableSchools => '暫無可用学校';

  @override
  String get searchSchoolSuggestion => '試試学校全稱、首字母或倉庫裡的学校代码';

  @override
  String get deleteDebugRecordTitle => '刪除偵錯記錄';

  @override
  String deleteDebugRecordMessage(String name) {
    return '確認刪除“$name”？刪除後不会影响已经匯入的課程';
  }

  @override
  String deletedDebugRecord(String name) {
    return '已刪除偵錯記錄：$name';
  }

  @override
  String get customDebugName => '自定义偵錯';

  @override
  String get localDebugMaintainer => '本地偵錯';

  @override
  String get customDebugDescription => '用户保存的自定义教務偵錯脚本';

  @override
  String get addDebugRecordTooltip => '新增偵錯記錄';

  @override
  String get customDebugIntroTitle => '這裡放你自己的教務偵錯記錄';

  @override
  String get customDebugIntroSubtitle =>
      '每条記錄都可以保存自定义網址和整段脚本，保存後下次直接點“開始偵錯”就能複用，不需要再去某個学校详情頁裡找入口';

  @override
  String get addDebugRecordAction => '新增偵錯記錄';

  @override
  String get noSavedDebugRecords => '還没有保存的偵錯記錄';

  @override
  String get noSavedDebugRecordsHint => '先新增一条，把網址和脚本贴進去，以後就能直接複用';

  @override
  String debugScriptLength(int count) {
    return '脚本 $count 字符';
  }

  @override
  String get startDebugAction => '開始偵錯';

  @override
  String get editAction => '编辑';

  @override
  String get scriptFileReadFailed => '無法讀取脚本文件';

  @override
  String scriptFileImported(String name) {
    return '已匯入脚本文件：$name';
  }

  @override
  String scriptFileImportFailed(String error) {
    return '匯入脚本文件失败：$error';
  }

  @override
  String get debugRecordNameRequired => '请先填寫偵錯記錄名稱';

  @override
  String get invalidImportUrl => '请輸入有效的教務網址';

  @override
  String get debugScriptRequired => '请先填寫或匯入脚本';

  @override
  String get editDebugRecordTitle => '编辑偵錯記錄';

  @override
  String get addDebugRecordTitle => '新增偵錯記錄';

  @override
  String get savingAction => '保存中…';

  @override
  String get debugRecordFormula => '一条記錄 = 一個網址 + 一段脚本';

  @override
  String get debugRecordFormulaSubtitle =>
      '適合你反複偵錯同一個学校，或者不同学校保留多套脚本，保存後会一直保留，後面可隨時修改';

  @override
  String get debugRecordNameLabel => '記錄名稱';

  @override
  String get debugRecordNameHint => '例如：重庆机電-新版教務';

  @override
  String get importUrlLabel => '教務網址';

  @override
  String get debugScriptLabel => '偵錯脚本';

  @override
  String get importFromFileAction => '从文件匯入';

  @override
  String get debugScriptHint => '把浏覽器擴展匯出的完整脚本粘贴到這裡';

  @override
  String get saveDebugRecordAction => '保存偵錯記錄';

  @override
  String get fillUrlThenImport => '填寫網址後匯入';

  @override
  String get webLoginImport => '網頁登入匯入';

  @override
  String get fillUrlThenRecord => '填寫網址後錄製';

  @override
  String get recordImportAction => '錄製匯入';

  @override
  String get quickImportAction => '⚡ 快捷匯入';

  @override
  String get quickImportTooltip => '快捷匯入';

  @override
  String get selectQuickImportTitle => '選擇快捷匯入';

  @override
  String quickImportMacroSteps(String adapterName, int stepCount) {
    return '$adapterName · $stepCount 步';
  }

  @override
  String quickImportTitle(String name) {
    return '快捷匯入 - $name';
  }

  @override
  String get noSavedQuickImportRecords => '暫無已保存的快捷匯入記錄';

  @override
  String get noValidWarehouseLoginUrl => '未找到有效的教務登入網址';

  @override
  String get noMacroRecordFound => '未找到錄製記錄，請先完成一次錄製';

  @override
  String get quickImportPlayingTitle => '自動匯入中…';

  @override
  String get quickImportExecutingScriptTitle => '回放完成，正在執行匯入腳本…';

  @override
  String get quickImportManualInputTitle => '需要手動操作';

  @override
  String get quickImportManualInputHint => '請完成當前需要的手動操作，完成後點擊繼續';

  @override
  String get quickImportCancelImportAction => '取消匯入';

  @override
  String get quickImportContinueAction => '繼續';

  @override
  String get quickImportFinishedTitle => '匯入完成';

  @override
  String get quickImportDismissAction => '完成';

  @override
  String get quickImportRetryAction => '重試';

  @override
  String get homePullQuickImportTitle => '首頁下拉快捷匯入';

  @override
  String get homePullQuickImportSubtitle => '在首頁下拉時自動執行教務快捷匯入';

  @override
  String get homePullQuickImportFetchingCourses => '正在取得新課程…';

  @override
  String get homePullQuickImportNeedsManualAction => '需要手動操作，請前往教務匯入頁面繼續';

  @override
  String quickImportPlaybackStepProgress(int current, int total) {
    return '步驟 $current / $total';
  }

  @override
  String get quickImportCancelPlaybackAction => '取消';

  @override
  String get quickImportUnknownError => '發生未知錯誤';

  @override
  String get recentSchoolLabel => '最近使用';

  @override
  String get warehouseSchoolTapHint => '點擊進入，選擇適配器匯入';

  @override
  String get warehouseAdaptersLoadFailedTitle => '暫時無法讀取適配器列表';

  @override
  String get stopRecordingTooltip => '停止錄製';

  @override
  String get startRecordingTooltip => '錄製操作';

  @override
  String get savedImportUrlHint => '已保存教務網址，下次可直接匯入';

  @override
  String get adapterIntroSubtitle => '可查看適配器資訊、登入入口與脚本狀態';

  @override
  String get schoolLabel => '学校';

  @override
  String get categoryLabel => '類别';

  @override
  String get maintainerLabel => '維護者';

  @override
  String get adapterInfoTitle => '適配器資訊';

  @override
  String get scriptPathLabel => '脚本路徑';

  @override
  String get loginEntryLabel => '登入入口';

  @override
  String get unsetConfigLabel => '未配置';

  @override
  String get adapterOverrideImportUrlHint => '目前使用你手動覆盖的登入地址';

  @override
  String get repositoryLabel => '倉庫';

  @override
  String get scriptStatusTitle => '脚本狀態';

  @override
  String scriptLoadedLength(int count) {
    return '脚本已成功讀取，长度 $count 字符';
  }

  @override
  String get scriptEmpty => '脚本為空';

  @override
  String get openLoginInAppAction => '應用內打開登入入口';

  @override
  String get openInSystemBrowserAction => '系統浏覽器打開';

  @override
  String get copiedImportLoginUrl => '已複制教務登入地址';

  @override
  String get copyLoginAddressAction => '複制登入地址';

  @override
  String get copiedScriptRawUrl => '已複制脚本原始地址';

  @override
  String get copyScriptAddressAction => '複制脚本地址';

  @override
  String get customLoginAddressAction => '自定义登入地址';

  @override
  String get editCustomLoginAddressAction => '修改自定义地址';

  @override
  String get clearCustomLoginAddressAction => '清除自定义地址';

  @override
  String get restoreRepositoryAddressAction => '恢複倉庫地址';

  @override
  String get invalidLoginEntryUrl => '登入入口地址無效';

  @override
  String get savedCustomLoginAddress => '已保存自定义登入地址';

  @override
  String get clearedCustomLoginAddress => '已清除自定义登入地址';

  @override
  String get restoredRepositoryImportUrl => '已恢複倉庫裡的登入地址';

  @override
  String get backToCurrentWeekAction => '返回本週';

  @override
  String get nonCurrentWeekLabel => '非本周';

  @override
  String get conflictLabel => '冲突';

  @override
  String get courseConflictSectionTitle => '衝突課程';

  @override
  String get courseNormalSectionTitle => '其他課程';

  @override
  String get courseConflictDetailTitle => '衝突詳情';

  @override
  String get courseConflictDetailEntryTitle => '查看衝突詳情';

  @override
  String get courseConflictDetailEntrySubtitle => '查看互撞排課與重疊時段';

  @override
  String courseConflictWithCourse(String name) {
    return '與「$name」衝突';
  }

  @override
  String get courseConflictOpenPartnerAction => '查看對方排課';

  @override
  String get courseConflictEmpty => '目前沒有偵測到衝突';

  @override
  String get courseConflictPairTitle => '衝突組合';

  @override
  String get selectWeekTitle => '选擇周次';

  @override
  String availableWeeksCount(int count) {
    return '共 $count 周';
  }

  @override
  String goToWeekLabel(int week) {
    return '第 $week 周';
  }

  @override
  String get homeMenuUpdateTitle => '軟體更新';

  @override
  String get homeMenuProfilesTitle => '課表管理';

  @override
  String get homeMenuOverviewTitle => '課程總覽';

  @override
  String get homeMenuAddCourseTitle => '新增課程';

  @override
  String get homeMenuImportTitle => '匯入課程';

  @override
  String get homeMenuSettingsTitle => '課表設定';

  @override
  String get homeMenuCoffeeTitle => '請喝咖啡';

  @override
  String get homeMenuFeedbackTitle => '問題回饋';

  @override
  String get switchTimetableTitle => '切换課表';

  @override
  String get todayTimetableTitle => '今日課表';

  @override
  String get dayTimetableTitle => '單日時間軸';

  @override
  String get backToWeekViewAction => '返回周視圖';

  @override
  String get backToTodayAction => '回到今天';

  @override
  String get ongoingCourseBadge => '正在上課';

  @override
  String get dayViewEmptyTitle => '暫無課程';

  @override
  String shortNamePrefix(String value) {
    return '簡稱：$value';
  }

  @override
  String teacherPrefix(String value) {
    return '老師：$value';
  }

  @override
  String locationPrefix(String value) {
    return '地點：$value';
  }

  @override
  String courseDialogCurrentWeekHint(int week) {
    return '目前查看第 $week 周，可直接对這一周這節課調課';
  }

  @override
  String courseDialogNotThisWeekHint(int week) {
    return '目前查看第 $week 周，這門課這周没有上課，因此不能按“本周這節”調課';
  }

  @override
  String get editActionShort => '编辑';

  @override
  String get rescheduleAction => '調課';

  @override
  String get deleteActionShort => '刪除';

  @override
  String get deleteModeTitle => '刪除方式';

  @override
  String get deleteModeSubtitle => '你可以刪掉整条排課，也可以只刪目前看到的這一周這一節';

  @override
  String get deleteCourseAction => '刪這個課';

  @override
  String get deleteOccurrenceAction => '刪這節課';

  @override
  String deleteModeHintCurrentWeek(int week) {
    return '“刪這個課”会刪除這条排課的全部周次；“刪這節課”只会刪除第 $week 周這一次';
  }

  @override
  String deleteModeHintUnavailable(int week) {
    return '目前卡片不是第 $week 周的实際排課，所以只能刪除整条排課';
  }

  @override
  String deleteScheduleConfirmMessage(String name, String detail) {
    return '確定刪除“$name”這条排課嗎？\n$detail';
  }

  @override
  String deleteOccurrenceConfirmMessage(String name, int week, String detail) {
    return '確定刪除“$name”在第 $week 周的這一節嗎？\n$detail';
  }

  @override
  String occurrenceDeletedMessage(int week) {
    return '已刪除第 $week 周這節課';
  }

  @override
  String get noChangesDetected => '未檢測到变更';

  @override
  String get rescheduleCurrentOccurrenceTitle => '調本周這節課';

  @override
  String rescheduleCurrentOccurrenceSubtitle(int week) {
    return '僅改第 $week 週本節，原課該週移除，其他週不變';
  }

  @override
  String get rescheduleTargetWeekLabel => '調到第几周';

  @override
  String get weekdayFieldLabel => '星期';

  @override
  String get startSectionFieldLabel => '開始節次';

  @override
  String get endSectionFieldLabel => '结束節次';

  @override
  String get courseLocationFieldLabel => '上課地點';

  @override
  String get confirmRescheduleAction => '確認調課';

  @override
  String get homeTitleStyleClassicLabel => '經典文字';

  @override
  String get homeTitleStyleBrandLabel => '大 Logo';

  @override
  String get homeTitleStyleClassicDescription => '維持原本標題樣式，只顯示文字，點一下即可切換課表';

  @override
  String get homeTitleStyleBrandDescription => '顯示大 Logo 和較小的課表名稱，更強調品牌感';

  @override
  String get widgetBackgroundStyleGlass => '半透明玻璃感';

  @override
  String get widgetBackgroundStyleSolid => '純色卡片';

  @override
  String get widgetBackgroundStyleGradient => '漸層卡片';

  @override
  String get homeWidgetTargetCompact22 => '主卡 2×2';

  @override
  String get homeWidgetTargetMiniList22 => '迷你清單 2×2';

  @override
  String get homeWidgetTargetMedium24 => '總覽 2×4';

  @override
  String get homeWidgetTargetLarge44 => '清單 4×4';

  @override
  String get homeWidgetTargetStats22 => '統計 2×2';

  @override
  String get homeWidgetTargetStats24 => '統計概覽 2×4';

  @override
  String get homeWidgetTargetTodayStrip41 => '今日橫條 4×1';

  @override
  String get homeWidgetTargetStatsStrip41 => '統計橫條 4×1';

  @override
  String get homeWidgetTargetExamCard22 => '考試倒數 2×2';

  @override
  String get homeWidgetTargetTodayWide42 => '今日橫寬 4×2';

  @override
  String get addCourseSheetTitle => '新增內容';

  @override
  String get addCourseSheetSubtitle =>
      '空白課表區域不響應點擊，請從這裡明確選擇是加一節臨時課、整學期重複課，還是插入一條單次日程';

  @override
  String courseWeekdaySectionSummary(
    String weekDescription,
    String weekday,
    int startSection,
    int endSection,
  ) {
    return '$weekDescription · $weekday 第$startSection-$endSection節';
  }

  @override
  String weekdaySectionTimeSummary(
    String weekday,
    int startSection,
    int endSection,
    String startTime,
    String endTime,
  ) {
    return '$weekday 第$startSection-$endSection節 · $startTime-$endTime';
  }

  @override
  String rescheduledToMessage(
    int week,
    String weekday,
    int startSection,
    int endSection,
  ) {
    return '已調到第 $week 周 $weekday 第$startSection-$endSection節';
  }

  @override
  String courseCountSummary(int count) {
    return '$count 門課';
  }

  @override
  String dayAgendaInProgressStatus(int minutes) {
    return '進行中 · 剩餘 $minutes 分鐘';
  }

  @override
  String dayAgendaEndingSoonStatus(int minutes) {
    return '快下課了 · 剩餘 $minutes 分鐘';
  }

  @override
  String scheduleAgendaInProgressStatus(int minutes) {
    return '進行中 · 剩餘 $minutes 分鐘';
  }

  @override
  String scheduleAgendaEndingSoonStatus(int minutes) {
    return '即將結束 · 剩餘 $minutes 分鐘';
  }

  @override
  String get currentBadge => '當前';

  @override
  String get feedbackXiaohongshuTitle => '小紅書';

  @override
  String feedbackXiaohongshuSubtitle(String id) {
    return '小紅書号：$id';
  }

  @override
  String get feedbackCoolapkTitle => '酷安';

  @override
  String feedbackCoolapkSubtitle(String id) {
    return '酷安号：$id';
  }

  @override
  String get feedbackQqGroupTitle => 'QQ 群';

  @override
  String feedbackQqGroupSubtitle(String id) {
    return '群号：$id';
  }

  @override
  String get feedbackWechatOaTitle => '微信公眾號';

  @override
  String feedbackWechatOaSubtitle(String name) {
    return '$name';
  }

  @override
  String get copiedCurrentTimetable => '已複製當前課表';

  @override
  String sectionRangeLabel(int startSection, int endSection) {
    return '第$startSection-$endSection節';
  }

  @override
  String classStartsAtLabel(String time) {
    return '$time 開始';
  }

  @override
  String classEndsAtLabel(String time) {
    return '$time 結束';
  }

  @override
  String get invalidSectionTimeFormat => '節次時間格式不正確';

  @override
  String get noSectionTimesToSave => '沒有可保存的節次時間';

  @override
  String warehouseImportedTimeSchemeName(String schoolName) {
    return '$schoolName 匯入節次';
  }

  @override
  String get unnamedScript => '未命名腳本';

  @override
  String localDebugModeScriptStatus(String scriptName) {
    return '本地偵錯模式：$scriptName';
  }

  @override
  String get executeImportScriptTooltip => '執行匯入腳本';

  @override
  String get switchToMobileWebTooltip => '切換到移動端頁面';

  @override
  String get switchToDesktopWebTooltip => '切換到桌面端頁面';

  @override
  String get rememberCurrentInputTooltip => '記住當前輸入';

  @override
  String get fillRememberedTooltip => '填充已記住賬號';

  @override
  String get clearRememberedTooltip => '清除已記住賬號';

  @override
  String get copyCurrentAddressTooltip => '複製當前地址';

  @override
  String get copiedCurrentAddress => '已複製當前地址';

  @override
  String get warehouseLoginHintLocalDebug => '當前為本地偵錯腳本模式';

  @override
  String get warehouseLoginHintImport => '在此登入教務系統後執行匯入';

  @override
  String get currentPageModeDesktop => '當前页面模式：桌面端';

  @override
  String get currentPageModeMobile => '當前页面模式：移动端';

  @override
  String localScriptLabel(String scriptName) {
    return '本地腳本：$scriptName';
  }

  @override
  String get webAddressHint => '輸入網頁地址';

  @override
  String get goAction => '前往';

  @override
  String rememberedAccountLabel(String username) {
    return '已記住賬號：$username';
  }

  @override
  String get importingAction => '匯入中...';

  @override
  String get executeLocalDebugScriptAction => '執行本地偵錯腳本';

  @override
  String get executeImportScriptAction => '執行匯入腳本';

  @override
  String get invalidWebAddress => '網頁地址無效';

  @override
  String get injectingLocalDebugScript => '正在注入本地偵錯腳本';

  @override
  String get injectingAdapterScript => '正在注入適配器腳本';

  @override
  String get localDebugScriptInjected => '本地偵錯腳本已注入';

  @override
  String get scriptInjected => '腳本已注入';

  @override
  String get scriptInjectionFailed => '腳本注入失敗';

  @override
  String executeFailedWithError(String error) {
    return '執行失敗：$error';
  }

  @override
  String get importFlowFinished => '匯入流程已完成';

  @override
  String get defaultContinuePrompt => '請按提示繼續操作';

  @override
  String get inputRequiredTitle => '需要输入';

  @override
  String get pleaseEnterFourDigitYear => '請輸入 4 位年份';

  @override
  String get pleaseChooseTitle => '請選擇';

  @override
  String get invalidCourseConfigFormat => '課程配置格式不正確';

  @override
  String saveCourseConfigFailedWithError(String error) {
    return '保存課程配置失敗：$error';
  }

  @override
  String saveSectionTimesFailedWithError(String error) {
    return '保存節次時間失敗：$error';
  }

  @override
  String get invalidCourseDataFormat => '課程資料格式不正確';

  @override
  String get noImportableCoursesFromScript => '腳本未返回可匯入課程';

  @override
  String importCourseCountPrompt(int count) {
    return '識別到 $count 門課程，是否匯入？';
  }

  @override
  String get importCancelledStatus => '已取消匯入';

  @override
  String applyReturnedTimeSchemeFailed(String error) {
    return '應用返回的節次模板失败：$error';
  }

  @override
  String get importInterruptedStatus => '匯入已中斷';

  @override
  String get importFailedStatus => '匯入失敗';

  @override
  String importFailedWithError(String error) {
    return '匯入失敗：$error';
  }

  @override
  String get unknownTeacher => '未知教師';

  @override
  String get unknownLocation => '未知地點';

  @override
  String get autofillLoginTitle => '自動填充登入資訊';

  @override
  String autofillLoginMessage(String username) {
    return '檢測到已記住賬號 $username，是否自動填充？';
  }

  @override
  String get notNowAction => '暫不';

  @override
  String get autofillAction => '自動填充';

  @override
  String get rememberPasswordTitle => '記住密碼';

  @override
  String rememberPasswordMessage(String username) {
    return '是否記住賬號 $username 的登入資訊，並在下次自動填充？';
  }

  @override
  String get dontRememberAction => '不記住';

  @override
  String get rememberAndAutofillAction => '記住並自動填充';

  @override
  String get savedRememberedLoginStatus => '已保存記住的登入資訊';

  @override
  String get autofilledRememberedLoginStatus => '已自動填充記住的登入資訊';

  @override
  String get noRecognizedLoginInputs => '未識別到登入輸入項';

  @override
  String get noUsernameOrPasswordRecognized => '未識別到用戶名或密碼';

  @override
  String get rememberedCurrentLoginStatus => '已記住當前登入資訊';

  @override
  String get rememberedCurrentLoginSuccess => '已記住當前登入資訊';

  @override
  String rememberLoginFailedWithError(String error) {
    return '記住登入資訊失敗：$error';
  }

  @override
  String get clearedRememberedLoginStatus => '已清除記住的登入資訊';

  @override
  String get clearedRememberedLoginSuccess => '已清除記住的登入資訊';

  @override
  String get addScheduleTitle => '新增日程';

  @override
  String get editScheduleTitle => '編輯日程';

  @override
  String get addScheduleAction => '新增日程';

  @override
  String get scheduleTitleLabel => '日程標題';

  @override
  String get scheduleTitleHint => '例如：開組會、辦證件、取包裹';

  @override
  String get scheduleTitleRequired => '請輸入日程標題';

  @override
  String get scheduleInfoSectionTitle => '日程資訊';

  @override
  String get scheduleInfoSectionSubtitle => '日程會按具體日期插入日視圖時間線，不會改動課程本身';

  @override
  String get scheduleTimeSectionTitle => '時間安排';

  @override
  String get scheduleTimeSectionSubtitle => '選擇這條日程實際發生的日期和起止時間';

  @override
  String get scheduleAppearanceSectionTitle => '顯示樣式';

  @override
  String get scheduleAppearanceSectionSubtitle => '選一個更容易和課程區分的日程顏色';

  @override
  String get scheduleLocationLabel => '地點';

  @override
  String get scheduleLocationHint => '選填';

  @override
  String get scheduleDateLabel => '日期';

  @override
  String get scheduleStartGroupLabel => '開始';

  @override
  String get scheduleEndGroupLabel => '結束';

  @override
  String get scheduleStartDateLabel => '開始日期';

  @override
  String get scheduleEndDateLabel => '結束日期';

  @override
  String get scheduleStartTimeLabel => '開始時間';

  @override
  String get scheduleEndTimeLabel => '結束時間';

  @override
  String get scheduleColorLabel => '日程顏色';

  @override
  String get scheduleNoteLabel => '備註';

  @override
  String get scheduleNoteHint => '選填';

  @override
  String get scheduleBadgeLabel => '日程';

  @override
  String scheduleCountSummary(int count) {
    return '日程 $count 項';
  }

  @override
  String get scheduleTimeRangeInvalid => '結束時間必須晚於開始時間';

  @override
  String get scheduleDateRangeInvalid => '結束日期不能早於開始日期';

  @override
  String get scheduleSingleDayHint => '同日結束時，結束時間必須晚於開始時間';

  @override
  String get scheduleCrossDayHint => '跨日日程會按當天切片顯示在日視圖時間軸裡';

  @override
  String get scheduleSavedHint => '日程已新增';

  @override
  String get scheduleUpdatedHint => '日程已更新';

  @override
  String get crossDayBadgeLabel => '跨日';

  @override
  String deleteScheduleMessage(String title) {
    return '刪除日程「$title」？';
  }

  @override
  String get scheduleDeletedHint => '日程已刪除';

  @override
  String get scheduleListTitle => '日程安排';

  @override
  String get scheduleListEmptyTitle => '暫無日程';

  @override
  String get scheduleUpcomingSection => '即將到來';

  @override
  String get schedulePastSection => '已過期';

  @override
  String get schedulePausedSection => '已暫停';

  @override
  String get scheduleOngoingLabel => '進行中';

  @override
  String scheduleTimeRange(String start, String end) {
    return '$start – $end';
  }

  @override
  String scheduleWeeklyWithDay(String day) {
    return '每週$day';
  }

  @override
  String get examListTitle => '考試安排';

  @override
  String get addExam => '新增考試';

  @override
  String get editExam => '編輯考試';

  @override
  String get saveExam => '儲存考試';

  @override
  String get noExams => '暫無考試安排';

  @override
  String get examToday => '今天有考試';

  @override
  String daysUntilExam(int days) {
    return '距離考試還有 $days 天';
  }

  @override
  String get examPassed => '已結束';

  @override
  String get linkCourse => '關聯課程';

  @override
  String get linkCourseRequired => '請選擇關聯課程';

  @override
  String get examNameLabel => '考試名稱';

  @override
  String get examNameRequired => '請輸入考試名稱';

  @override
  String get examDateLabel => '考試日期';

  @override
  String get examDateHint => '請選擇日期';

  @override
  String get examDateRequired => '請選擇考試日期';

  @override
  String get examEndTimeBeforeStart => '結束時間不能早於開始時間';

  @override
  String get examStartTimeLabel => '開始時間';

  @override
  String get examEndTimeLabel => '結束時間';

  @override
  String get examLocationLabel => '考場';

  @override
  String get examLocationHint => '留空則使用上課教室';

  @override
  String get sameAsClassroom => '同上課教室';

  @override
  String get examSeatLabel => '座位號';

  @override
  String get examReminderLabel => '提醒設定';

  @override
  String get examNoteLabel => '備註';

  @override
  String get deleteExam => '刪除考試';

  @override
  String deleteExamConfirm(String name) {
    return '刪除考試「$name」？';
  }

  @override
  String get examBadgeLabel => '考試';

  @override
  String get examCountdownToday => '今天';

  @override
  String examCountdownDays(int days) {
    return '$days天後';
  }

  @override
  String get examOverviewCountdown => '倒數';

  @override
  String get examOverviewCountdownUnit => '天後';

  @override
  String examOverviewTodayCount(int count) {
    return '今日 $count 場';
  }

  @override
  String examOverviewUpcomingCount(int count) {
    return '共 $count 場';
  }

  @override
  String get examOverviewInProgress => '考試進行中';

  @override
  String get examOverviewLiveBadge => '進行中';

  @override
  String examOverviewStartsAt(String time) {
    return '$time 開始';
  }

  @override
  String examOverviewUntilTime(String time) {
    return '至 $time';
  }

  @override
  String get examOverviewReminderOn => '已設提醒';

  @override
  String get examOverviewReminderOff => '未設提醒';

  @override
  String examTimeRange(String start, String end) {
    return '$start – $end';
  }

  @override
  String get sortAction => '排序';

  @override
  String get sortByAdded => '依新增順序';

  @override
  String get sortByName => '依課程名稱';

  @override
  String get sortBySchedule => '依上課時間';

  @override
  String scheduleEntryTitle(int index) {
    return '排課紀錄 $index';
  }

  @override
  String get scheduleEntrySingleTitle => '上課安排';

  @override
  String get scheduleEntryCardSubtitle => '設定這門課在何時、哪些週、由誰在哪裡上課';

  @override
  String get scheduleEntryTimeSectionTitle => '什麼時候上';

  @override
  String get scheduleEntryTimeSectionSubtitle => '選擇星期幾和第幾節課；連堂請填寫起止節次，單節課起止相同';

  @override
  String get scheduleEntryWeeksSectionTitle => '哪些週上';

  @override
  String get scheduleEntryPeopleSectionTitle => '誰在哪裡上';

  @override
  String get scheduleEntryTimeSchemeSectionTitle => '特殊時間方案';

  @override
  String get scheduleEntryTimeSchemeSectionSubtitle =>
      '預設跟隨目前課表；僅當本節課上下課時間與課表不同時才需要修改';

  @override
  String scheduleSectionNumberLabel(int section) {
    return '$section節';
  }

  @override
  String get addScheduleEntryAction => '新增排課時段';

  @override
  String get deleteScheduleEntryAction => '刪除排課';

  @override
  String get holidaySettingsEntryTitle => '假日標記';

  @override
  String get holidaySettingsEntrySubtitle => '在課表上標示放假日與補班日';

  @override
  String get holidayMakeupWorkday => '補班';

  @override
  String get holidaySettingsTitle => '假日標記';

  @override
  String get holidayEnableTitle => '啟用假日標記';

  @override
  String get holidayEnableSubtitle => '啟用後會在課表上標示放假日與補班日';

  @override
  String get holidayDataSectionTitle => '假日資料';

  @override
  String get holidayDataYear => '年份';

  @override
  String get holidayDataCount => '數量';

  @override
  String get holidayDataEmpty => '目前沒有假日資料';

  @override
  String get holidayCheckUpdate => '檢查更新';

  @override
  String get holidayAdvancedTitle => '假日資料更新';

  @override
  String get holidayUpcomingSectionTitle => '近期假日';

  @override
  String get holidayNoUpcoming => '近期沒有假日';

  @override
  String get holidayBadgeLabel => '休';

  @override
  String get holidayStatusLabel => '放假';

  @override
  String get suspendedBadgeLabel => '停';

  @override
  String get suspendedStatusLabel => '停課';

  @override
  String get courseActionSuspend => '停課';

  @override
  String get courseActionUnsuspend => '恢復上課';

  @override
  String get courseActionEditPrimary => '編輯課程';

  @override
  String get courseActionRescheduleSecondary => '調課';

  @override
  String get courseActionSuspendSecondary => '停課';

  @override
  String get courseActionDeleteSecondary => '刪除';

  @override
  String get courseNoteSheetTitle => '課程備註';

  @override
  String get courseNoteAction => '備註';

  @override
  String get courseNoteSaveAction => '儲存';

  @override
  String get courseNoteTabWholeCourse => '課程簡介';

  @override
  String get courseNoteTabThisSession => '本節課';

  @override
  String get courseNoteWholeCourseLabel => '課程簡介';

  @override
  String get courseNoteWholeCourseHint => '同名課程共享，長期有效（例如課程說明、課堂注意事項）。';

  @override
  String get courseNoteWholeCoursePlaceholder => '例如：這個老師容易點名、教室在新大樓…';

  @override
  String get courseNoteSessionLabel => '本節課備註';

  @override
  String courseNoteSessionHint(int week) {
    return '僅對第 $week 週這一次課生效，適合記錄作業或攜帶物品。';
  }

  @override
  String get courseNoteSessionPlaceholder => '例如：交第三章習題、帶電腦…';

  @override
  String get courseNoteHasHomeworkTitle => '有作業';

  @override
  String get courseNoteHasHomeworkSubtitle => '開啟後，週檢視課程卡片會顯示作業圓標';

  @override
  String get courseNoteHomeworkMarked => '本節有作業';

  @override
  String get courseNoteTileSubtitleEmpty => '記錄作業、帶電腦或課堂提醒';

  @override
  String get courseNoteTileSubtitleWhole => '已有課程簡介';

  @override
  String get courseNoteTileSubtitleSession => '已有本節課備註';

  @override
  String get courseNoteTileSubtitleBoth => '課程簡介與本節課均有備註';

  @override
  String get courseNoteReadOnlyNotice => '對方課程僅可查看備註，無法編輯。';

  @override
  String get courseNoteDoneEditingAction => '完成';

  @override
  String courseActionSheetNotice(int week) {
    return '您正在查看第 $week 周，如該時段突發考試或衝突，可立即在下方執行快速調課或停課';
  }

  @override
  String get courseActionOddWeekShort => '單周';

  @override
  String get courseActionEvenWeekShort => '雙周';

  @override
  String get courseActionConflictExpandHint => '展開查看其他衝突課程，點擊可切換操作對象';

  @override
  String get courseActionConflictCollapseHint => '點擊收起衝突課程列表';

  @override
  String get courseActionConflictSwitchAction => '切換';

  @override
  String courseActionCoupleRelatedCount(int count) {
    return '還有 $count 節情侶課表課程';
  }

  @override
  String get courseActionCoupleExpandHint => '展開查看對方的課或一起上課，點擊可切換預覽';

  @override
  String get courseActionCoupleCollapseHint => '點擊收起情侶課表課程列表';

  @override
  String courseActionMixedRelatedCount(int count) {
    return '還有 $count 節相關課程';
  }

  @override
  String get courseActionPartnerReadOnlyNotice => '這是對方課表中的課程，僅供查看，無法編輯或調課';

  @override
  String get suspendSheetTitle => '停課';

  @override
  String get suspendSheetSubtitle => '選擇停課範圍';

  @override
  String get suspendThisWeek => '本週停課';

  @override
  String get suspendThisWeekDesc => '只停本週';

  @override
  String get suspendAllWeeks => '全部週次停課';

  @override
  String get suspendAllWeeksDesc => '套用到所有週次';

  @override
  String get unsuspendAllWeeks => '恢復全部週次';

  @override
  String get unsuspendAllWeeksDesc => '恢復所有週次';

  @override
  String get customHolidayTitle => '自訂假日';

  @override
  String get customHolidayAdd => '新增假日';

  @override
  String get customHolidayEdit => '編輯假日';

  @override
  String get customHolidayDelete => '刪除';

  @override
  String get customHolidayDeleteConfirm => '確定要刪除此自訂假日嗎？';

  @override
  String get customHolidayNameLabel => '假日名稱';

  @override
  String get customHolidayStartDate => '開始日期';

  @override
  String get customHolidayEndDate => '結束日期';

  @override
  String get customHolidayType => '類型';

  @override
  String get customHolidayTypeVacation => '放假';

  @override
  String get customHolidayTypeWorkday => '補班日';

  @override
  String get customHolidayEmpty => '目前沒有自訂假日';

  @override
  String get customHolidayCorrupted => '自訂假日資料讀取異常，已暫停讀寫以防覆蓋丟失';

  @override
  String get customHolidayNameRequired => '請輸入假日名稱';

  @override
  String customHolidayDateRange(Object start, Object end) {
    return '$start ~ $end';
  }

  @override
  String get selectTeacherTitle => '選擇老師';

  @override
  String get selectLocationTitle => '選擇地點';

  @override
  String get historyRecordsLabel => '歷史紀錄';

  @override
  String get noHistoryRecords => '目前沒有歷史紀錄';

  @override
  String get weekPickerTitle => '選擇上課週次';

  @override
  String get selectTimeSchemeTitle => '選擇時間方案';

  @override
  String get manageTimeSchemesAction => '管理時間方案';

  @override
  String get examDefaultName => '期末考試';

  @override
  String get examDateWeekPickerTitle => '選擇考試日期';

  @override
  String get weekPickerCalendarTooltip => '使用日曆選擇';

  @override
  String get thisWeekLabel => '本週';

  @override
  String get guidePrivacyPageTitle => '隱私權條款';

  @override
  String get guidePermissionsPageTitle => '系統權限';

  @override
  String get guideTipsPageTitle => '使用技巧';

  @override
  String get guidePersonalizePageTitle => '個人化設定';

  @override
  String get guidePersonalizeSubtitle => '以下選擇立即生效，之後可隨時在「設定 → 外觀」中調整';

  @override
  String get guidePersonalizeMenuStyleTitle => '選單樣式';

  @override
  String get guidePersonalizeNavFormTitle => '導覽形態';

  @override
  String get guidePersonalizeVisualEffectTitle => '視覺效果';

  @override
  String get guidePersonalizeVisualEffectSolid => '實體卡片';

  @override
  String get guideVisualEffectGaussianDesc => '背景即時高斯模糊，通透有層次';

  @override
  String get guideVisualEffectLiquidDesc => '液態玻璃折射，更具質感（功耗略高）';

  @override
  String get guideVisualEffectSolidDesc => '不啟用模糊效果，效能最佳';

  @override
  String get guidePersonalizeThemeModeTitle => '深淺色模式';

  @override
  String get guidePersonalizeSeedColorTitle => '主題色';

  @override
  String get guidePrevButton => '上一步';

  @override
  String get guideNextButton => '下一步';

  @override
  String get guidePermissionsHeader => '系統權限設定';

  @override
  String get guidePermissionsSubtitle => '完成這些設定，超級島和提醒才能正常使用';

  @override
  String get guidePermissionsFooterHint =>
      '點擊後跳轉到系統設定，返回應用後可識別的狀態會自動刷新；自啟動受系統限制，請以系統頁面開關為準';

  @override
  String get guideTipsHeader => '使用技巧';

  @override
  String get guideTipsSubtitle => '這些隨時可以在「設定」裡找到';

  @override
  String get guidePrivacyReadBeforeUse => '使用前請閱讀並同意以下內容';

  @override
  String get guidePrivacyViewOnly => '隱私權、第三方 SDK 與免責聲明';

  @override
  String holidayDataYearLabel(Object year) {
    return '$year年國定假日';
  }

  @override
  String get holidayUpdateLog => '更新紀錄';

  @override
  String holidayUpdateLogCount(int count) {
    return '$count筆';
  }

  @override
  String holidayDateSameMonth(int month, int start, int end) {
    return '$month月$start日 - $end日';
  }

  @override
  String holidayDateSameDay(int month, int day) {
    return '$month月$day日';
  }

  @override
  String holidayDateDiffMonth(
    int startMonth,
    int startDay,
    int endMonth,
    int endDay,
  ) {
    return '$startMonth月$startDay日 - $endMonth月$endDay日';
  }

  @override
  String get liveTestingHolidayOverride => '假期狀態覆蓋';

  @override
  String get liveTestingHolidayOverrideSubtitle =>
      '開啟後模擬假期狀態，用於測試提醒和小工具是否正確隱藏課程';

  @override
  String get liveTestingHolidayModeEnabled => '假期模式已開啟';

  @override
  String get liveTestingHolidayModeDisabled => '假期模式已關閉';

  @override
  String get liveTestingHolidayModeEnabledDesc => '課程提醒和小工具將隱藏所有課程';

  @override
  String get liveTestingHolidayModeDisabledDesc => '當前使用正常假期數據';

  @override
  String get textColorTitle => '文字顏色';

  @override
  String get textColorSubtitle => '自訂課表各區域的文字顏色';

  @override
  String get textColorIndependentDetail => '獨立設定詳情顏色';

  @override
  String get textColorCourseCardTitle => '課程卡片標題顏色';

  @override
  String get textColorCourseCardDetail => '課程卡片詳情顏色';

  @override
  String get textColorWeekdayBar => '星期欄字體顏色';

  @override
  String get textColorWeekdayBarAccent => '星期欄強調色彩';

  @override
  String get textColorTimeAxis => '時間軸字體顏色';

  @override
  String get textColorSelectColor => '選擇顏色';

  @override
  String get textColorCurrentColor => '目前顏色';

  @override
  String get themeExport => '匯出主題';

  @override
  String get themeImport => '匯入主題';

  @override
  String get themeExportSuccess => '主題已複製到剪貼簿';

  @override
  String get themeImportSuccess => '主題已匯入';

  @override
  String get themeImportFailed => '剪貼簿內容格式錯誤';

  @override
  String get themeManageTitle => '主題管理';

  @override
  String get themeManageSubtitle => '匯出、匯入和切換主題';

  @override
  String get themePreset => '預設主題';

  @override
  String get themeSaved => '我的主題';

  @override
  String get themeSaveCurrent => '儲存當前主題';

  @override
  String get themeApply => '套用';

  @override
  String get themeDelete => '刪除';

  @override
  String themeDeleteConfirmMessage(String name) {
    return '確定要刪除主題「$name」嗎？';
  }

  @override
  String get textColorLowContrastWarning => '顏色對比度較低，可能會影響可讀性';

  @override
  String get themeCurrentTheme => '當前主題';

  @override
  String themeBasedOnModified(String baseName) {
    return '基於$baseName（已修改）';
  }

  @override
  String get themeResetToPreset => '重設';

  @override
  String get themeUnsavedChangesTitle => '未儲存的修改';

  @override
  String get themeUnsavedChangesMessage => '當前主題有未儲存的修改，是否儲存？';

  @override
  String get themeDiscardAndApply => '放棄並套用';

  @override
  String get themeNameHint => '輸入主題名稱';

  @override
  String get themePresetBlue => '預設藍';

  @override
  String get themePresetPurple => '暗夜紫';

  @override
  String get themePresetGreen => '森林綠';

  @override
  String get themePresetOrange => '暖陽橙';

  @override
  String get themePresetEyeCare => '護眼模式';

  @override
  String get themePresetHighContrast => '高對比度';

  @override
  String get themePresetDarkMinimal => '深色極簡';

  @override
  String get foruiThemeNeutral => '中性灰';

  @override
  String get foruiThemeZinc => '鋅灰';

  @override
  String get foruiThemeSlate => '石板灰';

  @override
  String get foruiThemeBlue => '藍';

  @override
  String get foruiThemeGreen => '綠';

  @override
  String get foruiThemeOrange => '橙';

  @override
  String get foruiThemeRed => '紅';

  @override
  String get foruiThemeRose => '玫紅';

  @override
  String get foruiThemeViolet => '紫';

  @override
  String get foruiThemeYellow => '黃';

  @override
  String get themeUndo => '撤銷';

  @override
  String themeChanged(String themeName) {
    return '已切換到 $themeName';
  }

  @override
  String get themeRename => '重新命名';

  @override
  String get themeDuplicate => '複製';

  @override
  String themeDuplicateCopyName(String name) {
    return '$name 副本';
  }

  @override
  String get themeMoreActions => '更多操作';

  @override
  String get courseNatureRequired => '必修';

  @override
  String get courseNatureElective => '選修';

  @override
  String get homeMenuStatisticsTitle => '課程統計';

  @override
  String get statisticsTitle => '課程統計';

  @override
  String get statisticsOverview => '本週概覽';

  @override
  String get statisticsCourseCount => '課程門數';

  @override
  String get statisticsSectionCount => '本週課時';

  @override
  String get statisticsWeeklyCourses => '本週課程';

  @override
  String get statisticsDailyDistribution => '每日課時分佈';

  @override
  String get statisticsNatureRatio => '必修 / 選修';

  @override
  String get statisticsCourseList => '課程列表';

  @override
  String get statisticsSectionsUnit => '節';

  @override
  String get statisticsSectionUnit => '節';

  @override
  String get statisticsNoData => '暫無課程數據';

  @override
  String get statisticsCourseCountRatio => '門數比例';

  @override
  String get statisticsSectionCountRatio => '課時比例';

  @override
  String statisticsWeekSelector(int week) {
    return '第 $week 週';
  }

  @override
  String get statisticsStoryBusiestDayTitle => '最忙的一天';

  @override
  String statisticsStoryBusiestDayContent(int week, String day, String avg) {
    return '截至第$week週，這學期你最忙的一天是 **$day**，平均 **$avg** 節課';
  }

  @override
  String get statisticsStoryLightestDayTitle => '最輕鬆的一天';

  @override
  String statisticsStoryLightestDayContent(int week, String day, String avg) {
    return '截至第$week週，你最輕鬆的一天是 **$day**，只有 **$avg** 節課';
  }

  @override
  String get statisticsStoryFavoriteRoomTitle => '最常去的教室';

  @override
  String statisticsStoryFavoriteRoomContent(int week, String room, int count) {
    return '截至第$week週，你最常去的教室是 **$room**，共去了 **$count** 次';
  }

  @override
  String get statisticsStoryBuildingCountTitle => '教學樓探險';

  @override
  String statisticsStoryBuildingCountContent(int week, int count) {
    return '截至第$week週，你的課程分佈在 **$count** 棟不同的教學樓';
  }

  @override
  String get statisticsStoryTimeRangeTitle => '時間跨度';

  @override
  String statisticsStoryTimeRangeContent(String earliest, String latest) {
    return '你最早的課是 **$earliest**，最晚的課是 **$latest**';
  }

  @override
  String get statisticsSemesterLabelCourses => '門課程';

  @override
  String get statisticsSemesterLabelSections => '節課';

  @override
  String get statisticsSemesterLabelWeeks => '週';

  @override
  String get statisticsSemesterLabelDayStreak => '天連續';

  @override
  String get statisticsAchievementsTitle => '成就徽章';

  @override
  String get statisticsStoriesTitle => '數據故事';

  @override
  String get statisticsRankingTitle => '課程排行';

  @override
  String get statisticsNoDataHint => '添加課程後即可查看統計';

  @override
  String get statisticsShareLabel => '分享統計';

  @override
  String get statisticsExportTitle => '匯出統計';

  @override
  String get statisticsExportModulesSection => '包含模組';

  @override
  String get statisticsExportFormatSection => '匯出格式';

  @override
  String get statisticsExportFormatImage => '長圖 (PNG)';

  @override
  String get statisticsExportFormatPdf => 'PDF 文件';

  @override
  String get statisticsExportAction => '開始匯出';

  @override
  String get statisticsExportSelectModuleHint => '請至少選擇一個模組';

  @override
  String get statisticsExportModuleOverview => '學期總覽';

  @override
  String get statisticsExportBrandTagline => '把課程資訊做成系統體驗';

  @override
  String statisticsExportGithubHint(String url) {
    return 'GitHub 搜尋專案：$url';
  }

  @override
  String get statisticsExportQrScanHint => '掃碼造訪官網';

  @override
  String statisticsExportRankingMore(int count) {
    return '另有 $count 門課程未展示';
  }

  @override
  String get statisticsShareTitle => '我的學期統計';

  @override
  String statisticsRankingSlotDetail(
    String day,
    int startSection,
    int endSection,
  ) {
    return '$day 第$startSection-$endSection節';
  }

  @override
  String get statisticsAchievementEarlyBirdName => '早八戰士';

  @override
  String get statisticsAchievementEarlyBirdDescription => '有 8:00 的課，真棒！';

  @override
  String get statisticsAchievementPerfectAttendanceName => '全勤達人';

  @override
  String get statisticsAchievementPerfectAttendanceDescription => '某門課每週都有';

  @override
  String get statisticsAchievementWeekendWarriorName => '週末戰士';

  @override
  String get statisticsAchievementWeekendWarriorDescription => '週末有課';

  @override
  String get statisticsAchievementClassKingName => '課王';

  @override
  String get statisticsAchievementClassKingDescription => '某天 ≥ 6 節課';

  @override
  String get statisticsAchievementScholarName => '學霸';

  @override
  String get statisticsAchievementScholarDescription => '總課時 ≥ 100';

  @override
  String get statisticsAchievementBalancedName => '均衡大師';

  @override
  String get statisticsAchievementBalancedDescription => '每天課時差距 ≤ 2';

  @override
  String get statisticsAchievementNightOwlName => '夜貓子';

  @override
  String get statisticsAchievementNightOwlDescription => '有 18:00 以後的課';

  @override
  String get statisticsAchievementExplorerName => '教室探索家';

  @override
  String get statisticsAchievementExplorerDescription => '使用過 ≥ 5 個不同教室';

  @override
  String statisticsNatureLegendDetail(int count, int sections) {
    return '$count 門 · $sections 節';
  }

  @override
  String get statisticsWeekCurrentHint => '本週';

  @override
  String get weeklyReportTitle => '本週課程小結';

  @override
  String weeklyReportBody(
    int week,
    int sections,
    int courses,
    String delta,
    String busiestDay,
  ) {
    return '第$week週 · 共$sections節 · $courses門課\n較上週 $delta 節\n最忙的一天是 $busiestDay';
  }

  @override
  String get weeklyReportBodyEmpty => '本週暫無課程，好好休息吧';

  @override
  String weeklyReportNextFire(String date, String time) {
    return '下次推送 $date $time';
  }

  @override
  String get weeklyReportEnabledHint => '已開啟每週週報推送';

  @override
  String get weeklyReportDisabledHint => '已關閉每週週報推送';

  @override
  String get statisticsCompareTitle => '課表對比';

  @override
  String get statisticsCompareActive => '當前課表';

  @override
  String get statisticsCompareNone => '暫無其他課表，可在課表管理中新建';

  @override
  String statisticsCompareDelta(String delta) {
    return '較當前 $delta 節';
  }

  @override
  String get statisticsCompareDetailTitle => '課表對比詳情';

  @override
  String get statisticsCompareWeek => '當前週';

  @override
  String get statisticsMoreTitle => '深度分析';

  @override
  String get statisticsMoreGroupTrend => '趨勢 · 分佈';

  @override
  String get statisticsMoreGroupPeople => '教室 · 教師 · 排行';

  @override
  String get statisticsNatureNoneRequired => '暫無必修';

  @override
  String get statisticsNatureNoneElective => '暫無選修';

  @override
  String get statisticsAchievementMorningPersonName => '早起鳥';

  @override
  String get statisticsAchievementMorningPersonDescription => '早間課時佔比 ≥ 50%';

  @override
  String get statisticsAchievementGapMasterName => '時間管理大師';

  @override
  String get statisticsAchievementGapMasterDescription => '最長課間空檔 ≤ 2 節';

  @override
  String get statisticsAchievementEarlyBirdDetail =>
      '解鎖條件：課表中有 08:00 或更早開始的課程。';

  @override
  String get statisticsAchievementPerfectAttendanceDetail =>
      '解鎖條件：至少一門課程在開課週期內每週都有課（無停課、無單雙週跳課）。';

  @override
  String get statisticsAchievementWeekendWarriorDetail => '解鎖條件：週末（週六或週日）有課。';

  @override
  String get statisticsAchievementClassKingDetail => '解鎖條件：某一天排課達到 6 節及以上。';

  @override
  String get statisticsAchievementScholarDetail => '解鎖條件：學期累計課時達到 100 節。';

  @override
  String get statisticsAchievementBalancedDetail =>
      '解鎖條件：每天課時差距不超過 2 節，課表安排均衡。';

  @override
  String get statisticsAchievementNightOwlDetail => '解鎖條件：有 18:00 以後才結束的課。';

  @override
  String get statisticsAchievementExplorerDetail => '解鎖條件：使用過 5 個及以上不同的教室。';

  @override
  String get statisticsAchievementFullDayKingDetail =>
      '解鎖條件：某一天排課達到 8 節及以上，全天滿課。';

  @override
  String get statisticsAchievementBuildingHopperDetail =>
      '解鎖條件：同一天內去過 3 棟及以上不同的教學樓。';

  @override
  String get statisticsAchievementMorningPersonDetail =>
      '解鎖條件：早間（12:00 前開始）課時佔總課時的一半以上。';

  @override
  String get statisticsAchievementGapMasterDetail =>
      '解鎖條件：每天課間最長空檔不超過 2 節，時間安排緊湊。';

  @override
  String get statisticsAchievementDetailConfirm => '知道了';

  @override
  String get statisticsAchievementLocked => '未達成';

  @override
  String get statisticsSettingsTitle => '統計設定';

  @override
  String get statisticsTabSemester => '學期';

  @override
  String get statisticsTabWeek => '週';

  @override
  String get statisticsSemesterProgressTitle => '學期進度';

  @override
  String statisticsSemesterProgressRange(String start, String end) {
    return '學期 $start - $end';
  }

  @override
  String statisticsSemesterProgressAsOf(String date) {
    return '今天 $date';
  }

  @override
  String statisticsSemesterProgressDetail(int week, int done, int total) {
    return '截至第 $week 週，已上 $done 節 / 共 $total 節';
  }

  @override
  String statisticsSemesterProgressRemaining(int count) {
    return '剩餘 $count 節';
  }

  @override
  String get statisticsSemesterProgressNotStarted => '還未開學，尚未上課';

  @override
  String get statisticsSemesterProgressEstimated => '按週估算';

  @override
  String get statisticsTrendTitle => '每週課時趨勢';

  @override
  String statisticsTrendTooltip(int week, int sections) {
    return '第 $week 週 · $sections 節';
  }

  @override
  String get statisticsComparisonTitle => '本週小結';

  @override
  String get statisticsComparisonLastWeek => '上週課時';

  @override
  String get statisticsComparisonAverage => '學期週均';

  @override
  String statisticsComparisonVsLastWeek(String delta) {
    return '較上週 $delta 節';
  }

  @override
  String statisticsComparisonVsAverage(String delta) {
    return '較週均 $delta 節';
  }

  @override
  String get statisticsComparisonNew => '新學期第一週';

  @override
  String get statisticsHeatmapTitle => '學期熱力圖';

  @override
  String get statisticsHeatmapHint => '顏色越深，課時越多';

  @override
  String get statisticsTimeUtilTitle => '時間利用';

  @override
  String get statisticsTimeEarliest => '最早課';

  @override
  String get statisticsTimeLatest => '最晚課';

  @override
  String get statisticsTimeMorning => '早間課時';

  @override
  String get statisticsTimeNoon => '午間課時';

  @override
  String get statisticsTimeEvening => '晚間課時';

  @override
  String get statisticsTimeWeekend => '週末課時';

  @override
  String get statisticsTimeGap => '最長課間空檔';

  @override
  String statisticsTimeGapValue(int sections) {
    return '$sections 節';
  }

  @override
  String get statisticsVenueTitle => '教室與教學樓';

  @override
  String get statisticsVenueTopRooms => '常去教室';

  @override
  String get statisticsVenueBuildings => '教學樓課時';

  @override
  String statisticsVenueVisits(int count) {
    return '$count 次';
  }

  @override
  String get statisticsTeacherTitle => '教師課時排行';

  @override
  String statisticsTeacherCourseCount(int count) {
    return '$count 門課';
  }

  @override
  String get statisticsAchievementFullDayKingName => '滿課日之王';

  @override
  String get statisticsAchievementFullDayKingDescription => '單日 ≥ 8 節課';

  @override
  String get statisticsAchievementBuildingHopperName => '跨樓達人';

  @override
  String get statisticsAchievementBuildingHopperDescription => '單日跨 ≥ 3 棟教學樓';

  @override
  String statisticsAchievementProgress(int current, int target) {
    return '$current/$target';
  }

  @override
  String get statisticsAchievementDone => '已達成';

  @override
  String statisticsWeekDailyHint(int week) {
    return '點擊查看第 $week 週詳情';
  }

  @override
  String get weekListSeparator => '、';

  @override
  String courseWeekListLabel(String weeks) {
    return '第$weeks周';
  }

  @override
  String courseWeekRangeLabel(int startWeek, int endWeek, String mode) {
    return '第$startWeek-$endWeek周$mode';
  }

  @override
  String courseWeekSuspendedLabel(String weeks) {
    return '第$weeks周停课';
  }

  @override
  String get importSemesterStartDateTitle => '开学日期';

  @override
  String get importSemesterStartDateSubtitle => '按這一天所在週作為校曆第 1 週';

  @override
  String get importFirstCourseWeekMappingLabel => '課表第 1 週對應校曆第幾週';

  @override
  String get importFirstCourseWeekMappingSubtitle =>
      '如果學校第一週沒課，就選第 2 週；前兩週都沒課就選第 3 週';

  @override
  String get importSemesterMappingNoShiftHint => '匯入後會直接把課表第 1 週當作校曆第 1 週';

  @override
  String importSemesterMappingShiftHint(int shiftedWeeks, int calendarWeek) {
    return '匯入後會把所有課程週次整體順延 $shiftedWeeks 週，讓課表第 1 週落在校曆第 $calendarWeek 週';
  }

  @override
  String calendarWeekOption(int week) {
    return '校曆第 $week 週';
  }

  @override
  String get aboutDownloadPackageMethodTitle => '下载安装包方式';

  @override
  String get aboutInAppDownloadTitle => '应用内下载';

  @override
  String get aboutInAppDownloadSubtitle => '下載完成後直接在應用內安裝';

  @override
  String get aboutSystemDownloaderTitle => '系统管理器';

  @override
  String get aboutSystemDownloaderChoiceSubtitle => '交給系統下載管理器處理';

  @override
  String get syncErrorAuthFailed => '帳號或密碼錯誤';

  @override
  String get syncErrorAccessDenied => '沒有存取權限';

  @override
  String get syncErrorCertificateError => '憑證校驗失敗';

  @override
  String get syncErrorConnectionTimeout => '連線逾時';

  @override
  String get syncErrorConnectionFailed => '無法連線伺服器';

  @override
  String get syncErrorNetworkError => '網路異常';

  @override
  String get syncErrorInvalidResponse => '伺服器回應無效';

  @override
  String get syncErrorLocalChangesPendingSync => '本機有未同步修改，已跳過自動覆蓋';

  @override
  String get syncErrorMissingCredentials => '請先設定雲同步帳號';

  @override
  String get syncErrorBackupNotFound => '備份不存在';

  @override
  String get syncErrorMissingBackupSnapshot => '備份快照缺失';

  @override
  String get syncErrorCannotDeleteCurrentBackup => '不能刪除目前備份';

  @override
  String get syncErrorProviderNotReady => '課表尚未就緒';

  @override
  String get syncErrorInsecureUrl => '僅支援 HTTPS 加密連線，HTTP 明文協定已被停用';

  @override
  String get syncErrorSyncFailed => '同步失敗';

  @override
  String get sectionTimeDisplayHidden => '不显示';

  @override
  String get sectionTimeDisplayStartOnly => '仅显示上课时间';

  @override
  String get sectionTimeDisplayStartAndEnd => '显示上下课时间';

  @override
  String get examReminderNone => '不提醒';

  @override
  String get examReminderMin30 => '考前 30 分钟';

  @override
  String get examReminderHour1 => '考前 1 小时';

  @override
  String get examReminderHour1AndMin30 => '考前 1 小时 + 30 分钟';

  @override
  String get examReminderDay1 => '考前 1 天';

  @override
  String get examReminderDay1AndHour1 => '考前 1 天 + 1 小时';

  @override
  String get examReminderCustom => '自定义';

  @override
  String examReminderOffsetMinutes(int minutes) {
    return '考前 $minutes 分钟';
  }

  @override
  String examReminderOffsetHours(int hours) {
    return '考前 $hours 小时';
  }

  @override
  String examReminderOffsetDays(int days) {
    return '考前 $days 天';
  }

  @override
  String get examReminderCustomEmpty => '请至少选择一个提醒时间';

  @override
  String get examReminderAddCustom => '添加提醒';

  @override
  String get examReminderAddCustomTitle => '自定义提醒时间';

  @override
  String get examReminderAddCustomHint => '设置距离考试开始前多久提醒，可添加多个';

  @override
  String get examReminderPickerDays => '天';

  @override
  String get examReminderPickerHours => '小时';

  @override
  String get examReminderPickerMinutes => '分钟';

  @override
  String get examReminderCustomAlreadyAdded => '该提醒时间已添加';

  @override
  String get examReminderCustomInvalid => '请设置大于 0 的提醒时间';

  @override
  String get examReminderCustomEmptyHint => '还没有自定义提醒，点下方添加';

  @override
  String get debugCopiedJson => '已複製 JSON';

  @override
  String get liveDuringClassTimeNearest => '最近时间';

  @override
  String get liveDuringClassTimeTotal => '总时间';

  @override
  String get liveCountdownTextStyleSmart => '智能（中文）';

  @override
  String get liveCountdownTextStyleSmartMinS => '智能（英文）';

  @override
  String get liveCountdownTextStyleMinuteSecondCn => '分秒（5分钟19秒）';

  @override
  String get liveCountdownTextStyleMinuteSecondColon => 'mm:ss（05:19）';

  @override
  String get liveCountdownTextStyleMinuteSecondMinS => 'min+s（5min19s）';

  @override
  String get liveCountdownTextStyleMinuteSecondMinSlashS => 'min/s（5min/19s）';

  @override
  String get liveCountdownTextStyleMinuteOnlyCn => '纯分钟（5分钟）';

  @override
  String get liveCountdownTextStyleMinuteOnlyMin => 'min（5min）';

  @override
  String get liveCountdownTextStyleMinuteOnlySlash => '/min（5/min）';

  @override
  String get liveCountdownTextStyleSecondOnlyCn => '纯秒（5秒）';

  @override
  String get liveCountdownTextStyleSecondOnlyShort => 's（5s）';

  @override
  String get liveCountdownTextStyleSecondOnlySlash => '/s（5/s）';

  @override
  String get miuiIslandLabelStyleTextOnly => '仅文字';

  @override
  String get miuiIslandLabelStyleIconAndText => '图标+文字';

  @override
  String get miuiIslandLabelContentCourseName => '课程名';

  @override
  String get miuiIslandLabelContentLocation => '教室';

  @override
  String get miuiIslandLabelContentCourseNameAndLocation => '课程名+教室';

  @override
  String get miuiIslandLabelFontWeightRegular => '常规';

  @override
  String get miuiIslandLabelFontWeightMedium => '中等';

  @override
  String get miuiIslandLabelFontWeightBold => '加粗';

  @override
  String get miuiIslandLabelRenderQualityStandard => '标准';

  @override
  String get miuiIslandLabelRenderQualityHigh => '高清';

  @override
  String get miuiIslandLabelRenderQualityUltra => '超高清';

  @override
  String get miuiIslandExpandedIconAppIcon => '应用图标';

  @override
  String get miuiIslandExpandedIconCustomImage => '自定义图片';

  @override
  String get miuiIslandExpandedIconHidden => '不显示';

  @override
  String get liveBeforeClassQuickActionNone => '不显示';

  @override
  String get liveBeforeClassQuickActionSilent => '打开静音';

  @override
  String get liveBeforeClassQuickActionDoNotDisturb => '打开免打扰';

  @override
  String get liveBeforeClassQuickActionBoth => '靜音和免打擾';

  @override
  String get courseCardVerticalAlignTop => '顶部对齐';

  @override
  String get courseCardVerticalAlignCenter => '垂直居中';

  @override
  String get courseCardVerticalAlignBottom => '底部对齐';

  @override
  String get courseCardVerticalAlignSpaceEvenly => '上下均布';

  @override
  String get courseCardHorizontalAlignLeft => '居左';

  @override
  String get courseCardHorizontalAlignCenter => '居中';

  @override
  String get courseCardHorizontalAlignRight => '居右';

  @override
  String get timetableTimeColumnWidthNarrow => '窄';

  @override
  String get timetableTimeColumnWidthWide => '宽';

  @override
  String get timetableCourseSpacingNarrow => '窄';

  @override
  String get timetableCourseSpacingWide => '宽';

  @override
  String get appUpdateDownloadSourceOriginal => 'GitHub 原版';

  @override
  String get appUpdateDownloadSourceMirror => '国内镜像';

  @override
  String get appUpdateDownloadChannelPgyer => '蒲公英下载';

  @override
  String get appUpdateDownloadChannelGithub => 'GitHub 下载';

  @override
  String get appUpdateDownloadChannelPgyerDescription => '国内高速下载，推荐使用';

  @override
  String get appUpdateDownloadChannelGithubDescription => 'GitHub 原生 + 国内镜像';

  @override
  String get appUpdateDownloadChannelGitcode => 'GitCode 直連';

  @override
  String get appUpdateDownloadChannelGitcodeDescription =>
      'GitCode 發行版直連下載，國內速度快';

  @override
  String get holidayStatutoryLabel => '法定假日';

  @override
  String get serviceMsgImportFileUnrecognized =>
      'Import failed. The file content could not be recognized.';

  @override
  String get serviceMsgImportUseOverwriteForFullBackup =>
      'This is a full data backup. Please import using overwrite current timetable.';

  @override
  String get serviceMsgImportNoProfilesInBackup =>
      'No recoverable timetables were found in the backup file.';

  @override
  String get serviceMsgUnrecognizedMikcbDataFile =>
      'Not a recognizable mikcb data file.';

  @override
  String get serviceMsgMissingSettingsData => 'Settings data is missing.';

  @override
  String get serviceMsgUnrecognizedMikcbFullBackup =>
      'Not a recognizable mikcb full backup file.';

  @override
  String get serviceMsgMissingFullBackupData =>
      'Complete backup data is missing.';

  @override
  String get serviceMsgUseProfileBackupNotFull =>
      'Use a timetable profile backup JSON, not a full data backup.';

  @override
  String get serviceMsgUnrecognizedSyncSnapshot =>
      'Not a recognizable mikcb cloud sync snapshot.';

  @override
  String get serviceMsgMissingSyncTimetableData =>
      'Cloud sync timetable data is missing.';

  @override
  String get serviceMsgSyncSnapshotChecksumFailed =>
      'Cloud sync snapshot verification failed.';

  @override
  String get serviceMsgSyncSnapshotNoProfiles =>
      'No recoverable timetables in the cloud sync snapshot.';

  @override
  String get serviceMsgSyncSnapshotUnrecognized =>
      'Cloud sync snapshot could not be recognized.';

  @override
  String get serviceMsgTimeSchemeNotFound => 'Time scheme not found.';

  @override
  String get serviceMsgTimeSchemeConfigUnavailable =>
      'Current timetable time configuration is unavailable.';

  @override
  String get serviceMsgTimeSchemeNotFoundSelected =>
      'Selected time scheme was not found.';

  @override
  String serviceMsgTimeSchemeSectionsInsufficient(
    int startSection,
    int endSection,
  ) {
    return 'Selected time scheme does not have enough sections for sections $startSection-$endSection.';
  }

  @override
  String serviceMsgSectionCountBelowUsage(int requiredMaxSection) {
    return '有課排到第$requiredMaxSection節';
  }

  @override
  String serviceMsgSectionCountBelowUsageDetail(
    int requiredMaxSection,
    String profileName,
    String courseName,
    int dayOfWeek,
    int startSection,
    int endSection,
    String usageType,
  ) {
    return 'Section count cannot be less than the maximum section in use (section $requiredMaxSection). In use: $profileName · $courseName (weekday $dayOfWeek sections $startSection-$endSection, $usageType)';
  }

  @override
  String get serviceMsgAtLeastOneSectionRequired =>
      'At least one section time must be kept.';

  @override
  String serviceMsgSectionEndMustAfterStart(int sectionNumber) {
    return 'Section $sectionNumber end time must be later than start time. Overnight classes are not supported.';
  }

  @override
  String serviceMsgSectionStartBeforePreviousEnd(int sectionNumber) {
    return 'Section $sectionNumber start time cannot be earlier than the previous section end time.';
  }

  @override
  String get serviceMsgPeriodStartTimeRequired =>
      'Set the first section start time for periods that have sections.';

  @override
  String serviceMsgSectionCrossesMidnight(int sectionNumber) {
    return 'Section $sectionNumber would cross midnight. Overnight classes are not supported.';
  }

  @override
  String get serviceMsgClassDurationMustPositive =>
      'Class duration must be greater than 0.';

  @override
  String get serviceMsgBreakDurationMustNonNegative =>
      'Break duration cannot be less than 0.';

  @override
  String get serviceMsgAtLeastOnePeriodSection =>
      'At least one period must have sections.';

  @override
  String get serviceMsgInvalidTimeFormat => 'Time format is invalid.';

  @override
  String get serviceMsgLinkedCourseNotFound => 'Linked course was not found.';

  @override
  String get serviceMsgCourseNotFoundForDelete =>
      'Course to delete was not found.';

  @override
  String serviceMsgCourseNotScheduledWeek(int sourceWeek) {
    return 'This course is not scheduled in week $sourceWeek.';
  }

  @override
  String get serviceMsgCourseNotFoundForReschedule =>
      'Course to reschedule was not found.';

  @override
  String get serviceMsgTargetWeekOutOfRange =>
      'Target week is outside the current semester range.';

  @override
  String get serviceMsgAtLeastOneScheduleSlot =>
      'At least one class time slot must be kept.';

  @override
  String get serviceMsgCourseNameRequired => 'Course name cannot be empty.';

  @override
  String get serviceMsgBackupContentRequired =>
      'Backup content cannot be empty.';

  @override
  String get serviceMsgSpreadsheetFormatOrEncodingUnrecognized =>
      'Could not recognize spreadsheet format or encoding. Save CSV as UTF-8 and try again.';

  @override
  String serviceMsgSpreadsheetXlsxParseFailed(String error) {
    return 'Failed to parse XLSX file: $error';
  }

  @override
  String serviceMsgSpreadsheetRowWarning(int rowNumber, String message) {
    return 'Row $rowNumber: $message';
  }

  @override
  String serviceMsgSpreadsheetWakeupInsufficientColumns(
    int rowNumber,
    int columnCount,
  ) {
    return 'WakeUp format needs at least 7 columns, but row $rowNumber has only $columnCount.';
  }

  @override
  String get serviceMsgWeekdayMustBe1To7 => 'Weekday must be between 1 and 7.';

  @override
  String get serviceMsgCustomWeeksRequired => 'Weeks cannot be empty.';

  @override
  String get serviceMsgClassWeeksRequired => 'Class weeks cannot be empty.';

  @override
  String get serviceMsgStartWeekMustBeAtLeast1 =>
      'Start week must be at least 1.';

  @override
  String serviceMsgStartWeekExceedsSemester(
    int startWeek,
    int semesterWeekCount,
  ) {
    return 'Start week $startWeek exceeds semester week count $semesterWeekCount.';
  }

  @override
  String get serviceMsgEndWeekBeforeStartWeek =>
      'End week cannot be earlier than start week.';

  @override
  String get serviceMsgWeeksRangeRequired =>
      'Class weeks or start week + end week must be provided.';

  @override
  String serviceMsgFieldMustBeAtLeast1(String field) {
    return '$field must be at least 1.';
  }

  @override
  String serviceMsgFieldCannotBeLessThan(String startField, String endField) {
    return '$endField cannot be less than $startField.';
  }

  @override
  String serviceMsgSectionOutOfRange(int section, int maxSection) {
    return 'Section $section is outside the time scheme range (1-$maxSection).';
  }

  @override
  String serviceMsgFieldMustBeInteger(String field) {
    return '$field must be an integer.';
  }

  @override
  String serviceMsgFieldCannotBeEmpty(String field) {
    return '$field cannot be empty.';
  }

  @override
  String serviceMsgSpreadsheetEndWeekClamped(
    int rowNumber,
    int endWeek,
    int semesterWeekCount,
  ) {
    return 'Row $rowNumber: end week $endWeek exceeds semester week count $semesterWeekCount; adjusted to $semesterWeekCount.';
  }

  @override
  String serviceMsgSpreadsheetOddEvenBoth(int rowNumber) {
    return 'Row $rowNumber: odd and even weeks cannot both be selected; treated as odd weeks.';
  }

  @override
  String get serviceMsgFieldCourseName => 'Course name';

  @override
  String get serviceMsgFieldWeekday => 'Weekday';

  @override
  String get serviceMsgFieldStartSection => 'Start section';

  @override
  String get serviceMsgFieldEndSection => 'End section';

  @override
  String get serviceMsgFieldCustomWeeks => 'Weeks';

  @override
  String get serviceMsgFieldClassWeeks => 'Class weeks';

  @override
  String get serviceMsgFieldStartWeek => 'Start week';

  @override
  String get serviceMsgFieldEndWeek => 'End week';

  @override
  String serviceMsgWeekStartInvalid(String itemName) {
    return '$itemName: week range start is invalid.';
  }

  @override
  String serviceMsgWeekRangeInvalid(String itemName) {
    return '$itemName: week range is invalid.';
  }

  @override
  String serviceMsgWeekRangeTooLarge(String itemName) {
    return '$itemName: week range is too large. Please check.';
  }

  @override
  String serviceMsgWeekTokenUnrecognized(String itemName, String token) {
    return '$itemName: unrecognized week token: $token';
  }

  @override
  String serviceMsgWeeksExceedSemesterClamped(
    String itemName,
    int semesterWeekCount,
    String weeks,
  ) {
    return '$itemName contains weeks beyond semester week count $semesterWeekCount ($weeks); excess weeks were ignored.';
  }

  @override
  String get serviceMsgAiResultNotObject =>
      'AI result is not a valid JSON object. Copy the full JSON again.';

  @override
  String serviceMsgAiSchemaMustBe(String schema) {
    return 'schema must be $schema';
  }

  @override
  String get serviceMsgAiCoursesMustBeArray => 'courses must be an array.';

  @override
  String get serviceMsgAiWarningsMustBeArray =>
      'warnings must be a string array.';

  @override
  String get serviceMsgAiWarningItemMustBeString =>
      'Each warnings item must be a string.';

  @override
  String serviceMsgAiCourseNotObject(int index) {
    return 'courses[$index] is not a valid object.';
  }

  @override
  String serviceMsgAiCourseNameEmpty(int index) {
    return 'courses[$index].name cannot be empty.';
  }

  @override
  String serviceMsgAiCourseDayOfWeekInvalid(int index) {
    return 'courses[$index].dayOfWeek must be between 1 and 7.';
  }

  @override
  String serviceMsgAiCourseStartSectionInvalid(int index) {
    return 'courses[$index].startSection must be at least 1.';
  }

  @override
  String serviceMsgAiCourseEndSectionInvalid(int index) {
    return 'courses[$index].endSection cannot be less than startSection.';
  }

  @override
  String serviceMsgAiCourseCustomWeeksEmpty(int index) {
    return 'courses[$index].customWeeks cannot be empty.';
  }

  @override
  String serviceMsgAiCourseNatureInvalid(int index) {
    return 'courses[$index].courseNature must be required or elective.';
  }

  @override
  String serviceMsgAiUnknownFields(String targetName, String fields) {
    return '$targetName contains unsupported fields: $fields';
  }

  @override
  String serviceMsgAiFieldMustBeString(String field) {
    return '$field must be a string.';
  }

  @override
  String serviceMsgAiFieldMustBeInteger(String field) {
    return '$field must be an integer.';
  }

  @override
  String serviceMsgAiWeekListInvalid(String itemName) {
    return '$itemName can only contain integers greater than or equal to 1.';
  }

  @override
  String serviceMsgAiWeekListTypeInvalid(String field) {
    return '$field must be an integer array or week string.';
  }

  @override
  String get serviceMsgNoReleaseAvailable =>
      'No release has been published yet.';

  @override
  String get serviceMsgNoReleaseWithPrerelease =>
      'No stable or prerelease version is available yet.';

  @override
  String serviceMsgUpdateCheckHttpFailed(int statusCode) {
    return 'Update check failed (HTTP $statusCode).';
  }

  @override
  String get serviceMsgUpdateCheckNetworkFailed =>
      'Network error. Unable to check for updates right now.';

  @override
  String get serviceMsgUpdateDownloadHashMismatch =>
      '安裝包校驗失敗，為防止安裝被篡改的檔案已取消本次更新';

  @override
  String get serviceMsgUpdateSha256UnverifiedRefused =>
      '無法校驗安裝包完整性（缺少官方 SHA-256），已取消應用內更新，請前往發佈頁手動下載';

  @override
  String get serviceMsgUpdateDownloadUrlUntrusted =>
      'Update download URL failed security validation.';

  @override
  String serviceMsgUpdateDownloadHttpFailed(int statusCode) {
    return 'Download failed (HTTP $statusCode).';
  }

  @override
  String serviceMsgUpdateOpenInstallerFailed(String detail) {
    return 'Failed to open installer: $detail';
  }

  @override
  String serviceMsgUpdateDownloadInstallError(String detail) {
    return 'Download or installation error: $detail';
  }

  @override
  String get serviceMsgInvalidUrl => 'Invalid URL.';

  @override
  String get serviceMsgUpdateAvailablePrerelease =>
      'A new prerelease version is available.';

  @override
  String get serviceMsgUpdateAvailable => 'A new version is available.';

  @override
  String get serviceMsgAlreadyLatest =>
      'You are already on the latest version.';

  @override
  String get serviceMsgShareBackupText =>
      'This is a full backup of the current timetable. Import it to restore courses and settings.';

  @override
  String get serviceMsgShareBackupSubject => 'Qingyu Timetable backup';

  @override
  String serviceMsgShareBackupSubjectNamed(String profileName) {
    return '$profileName - Qingyu Timetable backup';
  }

  @override
  String get serviceMsgShareFullBackupText =>
      'This is a full data backup containing all timetables, the active timetable, and time schemes.';

  @override
  String get serviceMsgShareFullBackupSubject =>
      'Qingyu Timetable - full data backup';

  @override
  String get serviceMsgInvalidRepositoryUrl =>
      'Repository URL format is invalid.';

  @override
  String get serviceMsgIncompleteGithubRepoUrl =>
      'GitHub repository URL is incomplete.';

  @override
  String get serviceMsgIncompleteRawGithubUrl =>
      'raw.githubusercontent.com URL is incomplete.';

  @override
  String get serviceMsgGithubOnlySupported =>
      'Only GitHub repository URLs are supported.';

  @override
  String get serviceMsgWarehouseNoSchoolsIndex =>
      'No school or tool index was found.';

  @override
  String serviceMsgWarehouseNoAdapters(String schoolName) {
    return 'No adapter information was found for $schoolName.';
  }

  @override
  String serviceMsgWarehouseFetchFailedMirror(int candidatesCount) {
    return 'Unable to read the adapter repository. Tried $candidatesCount mirror endpoints. Check your network or switch mirror in Version Update.';
  }

  @override
  String get serviceMsgWarehouseFetchFailedGithub =>
      'Unable to read the adapter repository on GitHub. Check your network or switch to a mirror in Version Update.';

  @override
  String get serviceMsgWarehouseScriptChecksumFailed =>
      'Adapter script integrity check failed: downloaded content does not match the repository\'s declared SHA-256, so execution was blocked. Refresh the school list and try again; if it keeps happening, report the adapter to qingyu_warehouse.';

  @override
  String get serviceMsgManualInputCaptcha =>
      'Enter the captcha manually, then tap Continue.';

  @override
  String get serviceMsgManualInputPassword =>
      'Enter the password manually. If it was auto-filled, tap Continue.';

  @override
  String get serviceMsgMacroNoSteps => 'No recorded steps.';

  @override
  String get serviceMsgMacroUserCancelled => 'Cancelled by user.';

  @override
  String serviceMsgMacroStepFailed(
    int stepIndex,
    int totalSteps,
    String detail,
  ) {
    return 'Step $stepIndex/$totalSteps failed: $detail';
  }

  @override
  String get serviceMsgMacroNavigateUrlEmpty => 'Navigation URL is empty.';

  @override
  String serviceMsgMacroNavigateUrlInvalid(String url) {
    return 'Invalid URL: $url';
  }

  @override
  String get serviceMsgMacroFillSelectorEmpty =>
      'Fill-field selector is empty.';

  @override
  String serviceMsgMacroElementNotFound(String selector) {
    return 'Element not found: $selector';
  }

  @override
  String get serviceMsgMacroClickSelectorEmpty => 'Click selector is empty.';

  @override
  String get serviceMsgMacroUrlPatternEmpty => 'URL pattern is empty.';

  @override
  String get serviceMsgMacroWaitSelectorEmpty => 'Wait selector is empty.';

  @override
  String get serviceMsgMacroManualInputDefault => 'Manual action required.';

  @override
  String serviceMsgMacroPollTimeout(
    String stepLabel,
    int timeoutSeconds,
    String lastError,
  ) {
    return '$stepLabel timed out (${timeoutSeconds}s)$lastError';
  }

  @override
  String get serviceMsgMacroReplayNavigate => 'Navigating…';

  @override
  String get serviceMsgMacroReplayFillField => 'Filling form…';

  @override
  String get serviceMsgMacroReplayClick => 'Clicking…';

  @override
  String get serviceMsgMacroReplayWaitUrl => 'Waiting for navigation…';

  @override
  String get serviceMsgMacroReplayWaitSelector => 'Waiting for page element…';

  @override
  String get serviceMsgMacroReplayWaitManual => 'Waiting for user action…';

  @override
  String get serviceMsgMacroReplayExecuteScript => 'Running import script…';

  @override
  String get serviceMsgMacroReplayDelay => 'Waiting…';

  @override
  String serviceMsgMacroReplayFailed(String detail) {
    return 'Failed: $detail';
  }

  @override
  String serviceMsgMacroReplayPaused(String reason) {
    return 'Waiting for manual action: $reason';
  }

  @override
  String serviceMsgSupportDonorsLoadFailed(String detail) {
    return 'Failed to load supporters list: $detail';
  }

  @override
  String serviceMsgStatisticsShareFailed(String detail) {
    return 'Share failed: $detail';
  }

  @override
  String get serviceMsgAuthFailed => 'Invalid username or password.';

  @override
  String get serviceMsgAccessDenied => 'Access denied.';

  @override
  String get serviceMsgCertificateError => 'Certificate validation failed.';

  @override
  String get serviceMsgConnectionTimeout => 'Connection timed out.';

  @override
  String get serviceMsgConnectionFailed => 'Could not connect to the server.';

  @override
  String get serviceMsgInvalidResponse => 'Invalid server response.';

  @override
  String get serviceMsgSyncFailed => 'Sync failed.';

  @override
  String get serviceMsgUsageTypeOverride => 'override time scheme';

  @override
  String get serviceMsgUsageTypeProfile => 'profile main time scheme';

  @override
  String get dataTransferProfileShareText => '这是轻屿课表当前课表的完整备份文件，导入后可直接恢复课程和设置';

  @override
  String get dataTransferProfileShareSubject => '轻屿课表备份';

  @override
  String dataTransferProfileShareSubjectNamed(String profileName) {
    return '$profileName - 轻屿课表备份';
  }

  @override
  String get dataTransferFullBackupShareText =>
      '这是轻屿课表的全部数据备份文件，包含所有课表、当前选中课表和时间模板';

  @override
  String get dataTransferFullBackupShareSubject => '轻屿课表 - 全部数据备份';

  @override
  String courseWeekCustomDescription(String weeks) {
    return '第$weeks周';
  }

  @override
  String courseWeekRangeDescription(int startWeek, int endWeek, String mode) {
    return '第$startWeek-$endWeek周$mode';
  }

  @override
  String get courseWeekOddModeSuffix => ' 单周';

  @override
  String get courseWeekEvenModeSuffix => ' 双周';

  @override
  String courseWeekSuspensionDescription(String weeks) {
    return '第$weeks周停课';
  }

  @override
  String get courseWeekListSeparator => '、';

  @override
  String holidayLogMemoryCacheHit(int year, int count) {
    return '$year年：命中内存缓存（$count 条），后台刷新中…';
  }

  @override
  String holidayLogLocalCacheHit(int year, int count) {
    return '$year年：命中本地缓存（$count 条），后台刷新中…';
  }

  @override
  String holidayLogNoCacheFetching(int year) {
    return '$year年：无缓存，正在拉取远程数据…';
  }

  @override
  String holidayLogRemoteSuccess(int year, int count) {
    return '$year年：远程拉取成功（$count 条），已缓存';
  }

  @override
  String holidayLogRemoteFailedBuiltin(int year) {
    return '$year年：远程拉取失败，使用内置资产兜底';
  }

  @override
  String holidayLogBuiltinLoaded(int year, int count) {
    return '$year年：加载内置资产（$count 条）';
  }

  @override
  String holidayLogBackgroundSuccess(int year, int count) {
    return '$year年：后台更新成功（$count 条），已覆盖缓存';
  }

  @override
  String holidayLogBackgroundNoData(int year) {
    return '$year年：后台更新未获取到新数据';
  }

  @override
  String get holidayLogPrimaryApiFailed => '主 API 失败，尝试备用 API…';

  @override
  String holidayLogRequesting(String uri) {
    return '正在请求 $uri …';
  }

  @override
  String holidayLogPrimaryApiStatus(int statusCode) {
    return '主 API 响应 $statusCode，跳过';
  }

  @override
  String holidayLogPrimaryApiError(String message) {
    return '主 API 返回错误：$message';
  }

  @override
  String holidayLogPrimaryApiException(String error) {
    return '主 API 异常：$error';
  }

  @override
  String holidayLogPrimaryApiParsing(int count) {
    return '主 API 返回 $count 条原始数据，正在解析…';
  }

  @override
  String get holidayLogNoValidEntries => '解析后无有效条目，跳过';

  @override
  String holidayLogFallbackApiStatus(int statusCode) {
    return '备用 API 响应 $statusCode，跳过';
  }

  @override
  String get holidayLogFallbackApiError => '备用 API 返回错误';

  @override
  String holidayLogFallbackApiParsing(int count) {
    return '备用 API 返回 $count 条原始数据，正在解析…';
  }

  @override
  String holidayLogFallbackApiException(String error) {
    return '备用 API 异常：$error';
  }

  @override
  String get holidayNameNewYear => '元旦';

  @override
  String get holidayNameLaborDay => '劳动节';

  @override
  String get holidayNameNationalDay => '国庆节';

  @override
  String get holidayNameSpringFestival => '春节';

  @override
  String get holidayNameQingming => '清明节';

  @override
  String get holidayNameDragonBoat => '端午节';

  @override
  String get holidayNameMidAutumn => '中秋节';

  @override
  String macroReplayStatusFailed(String error) {
    return '失败: $error';
  }

  @override
  String macroReplayStatusPaused(String reason) {
    return '等待手动操作: $reason';
  }

  @override
  String get macroReplayStepNavigating => '正在导航...';

  @override
  String get macroReplayStepFilling => '正在填充表单...';

  @override
  String get macroReplayStepClicking => '正在点击...';

  @override
  String get macroReplayStepWaitUrl => '等待页面跳转...';

  @override
  String get macroReplayStepWaitSelector => '等待页面元素...';

  @override
  String get macroReplayStepWaitManual => '等待用户操作';

  @override
  String get macroReplayStepExecuteScript => '正在执行导入脚本...';

  @override
  String get macroReplayStepDelay => '等待中...';

  @override
  String get macroReplayAcceleratedFallbackTip => '快捷路径失败，正在使用完整录制步骤重试…';

  @override
  String get macroReplayNoSteps => '没有录制的步骤';

  @override
  String get macroReplayUserCancelled => '用户取消';

  @override
  String macroReplayStepFailed(int current, int total, String error) {
    return '第 $current/$total 步失败: $error';
  }

  @override
  String get macroReplayEmptyNavigateUrl => '导航 URL 为空';

  @override
  String macroReplayInvalidUrl(String url) {
    return '无效的 URL: $url';
  }

  @override
  String get macroReplayEmptyFillSelector => '填充字段的选择器为空';

  @override
  String macroReplayFieldNotFound(String selector) {
    return '未找到表单字段: $selector';
  }

  @override
  String get macroReplayEmptyClickSelector => '点击元素的选择器为空';

  @override
  String macroReplayClickNotFound(String selector) {
    return '未找到点击元素: $selector';
  }

  @override
  String macroReplayWaitUrlPattern(String pattern) {
    return '等待 URL 匹配: $pattern';
  }

  @override
  String get macroReplayEmptyWaitSelector => '等待元素的选择器为空';

  @override
  String macroReplayWaitSelector(String selector) {
    return '等待元素: $selector';
  }

  @override
  String get macroReplayManualActionRequired => '需要手动操作';

  @override
  String macroReplayNavigateTo(String url) {
    return '导航到 $url';
  }

  @override
  String get macroReplayWaitPageLoad => '等待页面加载';

  @override
  String get macroReplayWaitDomReady => '等待 DOM 就绪';

  @override
  String get hyperosShowcaseTitle => '澎湃 UI 组件库';

  @override
  String get hyperosShowcaseSectionSummary => '概要卡片';

  @override
  String get hyperosShowcaseKitSubtitle => 'mikcb 澎湃风格组件一览';

  @override
  String get hyperosShowcaseSectionTags => '标签 / 手风琴 / 提示';

  @override
  String get hyperosShowcaseAccordionSection1 => '第一节';

  @override
  String get hyperosShowcaseAccordionSection1Body => '展开后显示的内容区域';

  @override
  String get hyperosShowcaseAccordionSection2 => '第二节';

  @override
  String get hyperosShowcaseAccordionSection2Body => '可折叠分组，替代 FAccordion';

  @override
  String get hyperosShowcaseSectionNavRows => '列表行 · 导航';

  @override
  String get hyperosShowcaseNavRowWithIcon => '带图标';

  @override
  String get hyperosShowcaseNavRowNoIconSubtitle => '无左侧彩图标';

  @override
  String get hyperosShowcaseNavRowDetails => '详情';

  @override
  String get hyperosShowcaseSectionSwitchRows => '列表行 · 开关 / 危险';

  @override
  String get hyperosShowcaseSwitchRowSubtitle => '带图标开关行';

  @override
  String get hyperosShowcaseSwitchRowPlain => '纯文字开关行';

  @override
  String get hyperosShowcaseSectionChoiceRows => '列表行 · 单选 / 选择 / 日期';

  @override
  String get hyperosShowcaseOptionA => '选项 A';

  @override
  String get hyperosShowcaseOptionB => '选项 B';

  @override
  String get hyperosShowcaseOptionC => '选项 C';

  @override
  String get hyperosShowcaseSelectSizeTitle => '选择尺寸';

  @override
  String get hyperosShowcaseSizeSmall => '小';

  @override
  String get hyperosShowcaseSizeMedium => '中';

  @override
  String get hyperosShowcaseSizeLarge => '大';

  @override
  String get hyperosShowcaseSectionControls => '控件卡片';

  @override
  String get hyperosShowcaseControlsSubtitle => '滑条、分段、按钮';

  @override
  String get hyperosShowcaseSegmentLeft => '左';

  @override
  String get hyperosShowcaseSegmentRight => '右';

  @override
  String get hyperosShowcaseSectionInput => '输入';

  @override
  String get hyperosShowcaseInputHint => '请输入内容';

  @override
  String get hyperosShowcaseInputCardLabel => '卡片内输入';

  @override
  String get hyperosShowcaseSectionPicker => '滚轮选择器';

  @override
  String hyperosShowcasePickerCurrentValue(int value) {
    return '当前值：$value';
  }

  @override
  String get hyperosShowcaseSectionInline => '基础控件 · 行内';

  @override
  String get hyperosShowcaseCheckboxSubtitle => '多选偏好行';

  @override
  String get hyperosShowcaseSectionNavActions => '导航与操作';

  @override
  String get hyperosShowcaseTooltipButton => '带 Tooltip 的按钮';

  @override
  String get hyperosShowcaseSectionProgress => '进度与刷新';

  @override
  String get hyperosShowcaseSectionColorChip => '颜色选择 · ColorChip';

  @override
  String get hyperosShowcaseSectionNavBar => '底部导航 · HyperosNavigationBar';

  @override
  String get hyperosShowcaseNavHome => '首页';

  @override
  String get hyperosShowcaseNavTimetable => '课表';

  @override
  String get hyperosShowcaseNavSettings => '设置';

  @override
  String get hyperosShowcaseSectionEmpty => '空态 / 分割线 / 装饰';

  @override
  String get hyperosShowcaseEmptySubtitle => '列表无数据时的占位';

  @override
  String get hyperosShowcaseActionButton => '操作按钮';

  @override
  String get hyperosShowcaseDividerRowTitle => '第二行（上方有缩进分割线）';

  @override
  String get hyperosShowcaseSectionPressable => '底层行 · HyperosPressableRow';

  @override
  String get hyperosShowcaseSectionShell => '页面壳层';

  @override
  String get hyperosShowcaseRootPageDetails => '无返回键根页';

  @override
  String get hyperosShowcaseSubpageSubtitle => '当前页即 Subpage + HyperosListView';

  @override
  String get hyperosShowcaseAlreadyInSubpage => '已在 Subpage 中';

  @override
  String get hyperosShowcaseSectionFrosted => '模糊顶栏 · 滚动物理';

  @override
  String get hyperosShowcaseSectionFeedback => '反馈 · 弹层';

  @override
  String get hyperosShowcaseSectionIconColors => '主题色 · HyperosIconColors';

  @override
  String get hyperosShowcaseFooterNote => '此页仅在非 Release 构建设置首页可见，用于组件视觉验收';

  @override
  String get hyperosShowcaseUndoAction => '撤销';

  @override
  String get hyperosShowcaseDialogMessage => '系统风格对话框示例';

  @override
  String get hyperosShowcaseConfirmTitle => '确认操作';

  @override
  String get hyperosShowcaseConfirmed => '已确认';

  @override
  String get hyperosShowcaseToastDescription => '带图标与副标题，App Toast 同款';

  @override
  String get hyperosShowcaseMenuCopy => '复制';

  @override
  String get hyperosShowcaseMenuShare => '分享';

  @override
  String get hyperosShowcaseMenuDelete => '删除';

  @override
  String get hyperosShowcaseRefreshDone => '刷新完成';

  @override
  String get hyperosShowcaseSearchTooltip => '搜索';

  @override
  String get hyperosShowcaseRootShellLabel => '根页壳层';

  @override
  String get hyperosShowcasePushSubtitle => '通过 HyperosNavigation.push 进入';

  @override
  String get hyperosShowcaseSampleText => '示例文本';

  @override
  String courseImportQuickImportDescription(
    String schoolName,
    String adapterName,
  ) {
    return '快捷导入 $schoolName $adapterName';
  }

  @override
  String get courseImportScriptNoCourses => '导入脚本未返回课程数据';

  @override
  String get courseImportScriptFailed => '脚本执行失败';

  @override
  String get courseImportRecordingStatus => '录制中…点击停止完成录制';

  @override
  String get courseImportRecordingStartedTip => '录制已开始，请按正常流程操作教务网站';

  @override
  String get courseImportAutoRecordingStartedTip => '已在背景記錄操作，匯入成功後可儲存為快捷匯入';

  @override
  String get courseImportRecordingEmptyStatus => '未录制到任何操作';

  @override
  String get courseImportRecordingEmptyTip => '未录制到任何操作';

  @override
  String get courseImportSaveRecordingTitle => '保存录制';

  @override
  String courseImportSaveRecordingMessage(int count) {
    return '录制了 $count 个操作步骤，是否保存为快捷导入？';
  }

  @override
  String courseImportSaveAutoRecordingMessage(int count) {
    return '匯入成功。已記錄 $count 個操作步驟，是否儲存本次匯入路徑，以便下次快捷匯入？';
  }

  @override
  String courseImportRecordingSavedStatus(int count) {
    return '录制已保存（$count 步）';
  }

  @override
  String get courseImportWeekNotProvided => '未提供周次';

  @override
  String get courseImportLocationNotFilled => '未填写地点';

  @override
  String courseImportPreviewLine(
    String weekday,
    int startSection,
    int endSection,
    String name,
    String location,
    String weekText,
  ) {
    return '周$weekday 第$startSection-$endSection节  $name  $location  周次：$weekText';
  }

  @override
  String courseImportCalendarWeekLabel(int week) {
    return '校历第 $week 周';
  }

  @override
  String get courseImportTermStartDateTitle => '开学日期';

  @override
  String get courseImportFirstWeekMappingLabel => '课表第 1 周对应校历第几周';

  @override
  String get courseImportFirstWeekMappingSubtitle =>
      '如果学校第一周没课，就选第 2 周；前两周都没课就选第 3 周';

  @override
  String get courseImportFirstWeekNoShift => '导入后会直接把课表第 1 周当作校历第 1 周';

  @override
  String courseImportFirstWeekShifted(int weeks, int targetWeek) {
    return '导入后会把所有课程周次整体顺延 $weeks 周，让课表第 1 周落在校历第 $targetWeek 周';
  }

  @override
  String get courseImportContinueAction => '继续导入';

  @override
  String get courseImportUpdateRecommendedAction => '更新课表（推荐）';

  @override
  String get courseImportOverwriteAction => '覆盖导入';

  @override
  String get courseImportSectionCountInsufficientTitle => '时间模板节次不足';

  @override
  String courseImportSectionCountInsufficientMessage(
    int current,
    int required,
  ) {
    return '当前课表时间模板只有 $current 节，但导入数据需要到第 $required 节，是否自动补齐后继续导入？';
  }

  @override
  String get courseImportAutoFillAndImportAction => '自动补齐并导入';

  @override
  String get courseImportPortalUrlTitle => '输入教务网址';

  @override
  String get courseImportPortalUrlSaveContinue => '保存并继续';

  @override
  String get courseImportPortalUrlLabel => '教务网址';

  @override
  String get courseImportPortalUrlHint => '保存后下次会直接使用，也可以在适配器信息页里修改';

  @override
  String get courseImportPortalUrlInvalid => '登录地址格式不正确';

  @override
  String get logAppLoggerInitialized => '应用日志服务已初始化';

  @override
  String get logPrivacyConsentUpdated => '隐私协议同意状态已更新';

  @override
  String get logAppLogRecordingEnabled => '应用日志记录已开启';

  @override
  String get logAppLogRecordingRemainsEnabled => '应用日志记录保持开启';

  @override
  String get logStartupFlowStarted => '启动流程处理已开始';

  @override
  String get logStartupFlowCompletedNoOnboarding => '启动流程已完成（无需引导页）';

  @override
  String get logStartupFlowCompletedAfterGuide => '启动流程已完成（经过引导页）';

  @override
  String get logStartupFlowFailed => '启动流程失败，进入降级模式';

  @override
  String get logAppLifecycleChanged => '应用生命周期已变更';

  @override
  String get logNavigatorRouteReplaced => '导航路由已替换';

  @override
  String get logNavigatorRouteChanged => '导航路由已变更';

  @override
  String get logAppLogsDefaultMigrated => '迁移时已默认开启应用日志记录';

  @override
  String get logTimetableLoadSettingsFailed => '加载课表设置失败';

  @override
  String get logTimetableLoadCoursesFailed => '加载课程数据失败';

  @override
  String get logTimetableLoadCurrentWeekFailed => '加载当前周次失败';

  @override
  String get logHomeWidgetPinSupportFailed => '检查桌面小组件固定支持失败';

  @override
  String get logHomeWidgetPinRequestFailed => '请求固定桌面小组件失败';

  @override
  String get logHomeWidgetSyncFailed => '同步桌面小组件快照失败';

  @override
  String get logHomeWidgetClearFailed => '清空桌面小组件快照失败';

  @override
  String get logHomeWidgetScheduleFailed => '调度桌面小组件刷新失败';

  @override
  String get logHomeWidgetExactAlarmCheckFailed => '檢查精確鬧鐘權限失敗';

  @override
  String get logHomeWidgetExactAlarmRequestFailed => '請求精確鬧鐘授權失敗';

  @override
  String get logMiuiLiveInitializeFailed => '初始化 MIUI 超级岛通道失败';

  @override
  String get logMiuiLiveOpenPromotedSettingsFailed => '打开超级岛权限设置失败';

  @override
  String get logMiuiLiveOpenNotificationSettingsFailed => '打开通知设置失败';

  @override
  String get logMiuiLiveOpenAutostartSettingsFailed => '打开自启动设置失败';

  @override
  String get logMiuiLiveOpenBatterySettingsFailed => '打开电池优化设置失败';

  @override
  String get logMiuiLiveOpenAccessibilitySettingsFailed => '打开无障碍设置失败';

  @override
  String get logMiuiLiveHideFromRecentsFailed => '更新「从最近任务隐藏」失败';

  @override
  String get logLiveUpdateStartFailed => '从 Flutter 启动超级岛失败';

  @override
  String get logLiveUpdateStopFailed => '从 Flutter 停止超级岛失败';

  @override
  String get logLiveUpdateDebugStatusFailed => '获取原生超级岛调试状态失败';

  @override
  String get logLiveUpdateSnapshotSyncFailed => '同步超级岛课表快照失败';

  @override
  String get logLiveUpdateSnapshotClearFailed => '清空超级岛课表快照失败';

  @override
  String get logLiveUpdateSuspendTriggersFailed => '挂起超级岛课表调度失败';

  @override
  String get logLanEditAuthFailed => '局域网编辑：认证失败';

  @override
  String get logLanEditCourseCreated => '局域网编辑：已创建课程';

  @override
  String get logLanEditCourseUpdated => '局域网编辑：已更新课程';

  @override
  String get logLanEditCourseDeleted => '局域网编辑：已删除课程';

  @override
  String get logLanEditCourseGroupSaved => '局域网编辑：已保存课程组';

  @override
  String get logLanEditMergeImported => '局域网编辑：已导入合并备份';

  @override
  String get logLanEditCoursesBatchDeleted => '局域网编辑：已批量删除课程';

  @override
  String get logLanEditCurrentWeekSet => '局域网编辑：已设置当前周次';

  @override
  String get logLanEditProfileSwitched => '局域网编辑：已切换课表';

  @override
  String get logLanEditSpreadsheetImported => '局域网编辑：已导入表格';

  @override
  String get logLanEditSessionStarted => '局域网编辑：会话已启动';

  @override
  String get logLanEditSessionStopped => '局域网编辑：会话已停止';

  @override
  String get logLiveUpdateTestRequested => '用户请求手动超级岛测试通知';

  @override
  String get logLiveUpdateTestNoSelection => '手动超级岛测试：未找到可用课程';

  @override
  String get logLiveUpdateTestSelectionReady => '手动超级岛测试：已解析目标课程';

  @override
  String get logLiveUpdateTestSuspendSync => '手动超级岛测试：已临时暂停定时同步';

  @override
  String get logLiveUpdateTestStarting => '手动超级岛测试：正在启动原生超级岛';

  @override
  String get logLiveUpdateTestStarted => '手动超级岛测试：已成功请求原生超级岛';

  @override
  String get logLiveUpdateTestFailed => '手动超级岛测试：原生超级岛出现前失败';

  @override
  String logLiveUpdateSettingsSynced(
    String beforeClass,
    String duringClass,
    String beforeEnd,
    String promote,
    String notification,
    String countdown,
    String courseName,
    String location,
  ) {
    return 'Flutter 超级岛设置已同步：课前=$beforeClass，课中=$duringClass，下课前=$beforeEnd，提升=$promote，通知=$notification，倒计时=$countdown，课程名=$courseName，地点=$location';
  }

  @override
  String get logFieldSource => '来源';

  @override
  String get logFieldPlatform => '平台';

  @override
  String get logFieldVersion => '版本';

  @override
  String get logFieldBuildNumber => '构建号';

  @override
  String get logFieldLoggingEnabled => '日志记录';

  @override
  String get logFieldPrivacyAccepted => '隐私协议';

  @override
  String get logFieldAccepted => '已同意';

  @override
  String get logFieldPrevious => '先前状态';

  @override
  String get logFieldTruncated => '已截断';

  @override
  String get logFieldTruncatedHint => '截断提示';

  @override
  String get logFieldThrowable => '异常';

  @override
  String get logFieldExtras => '附加信息';

  @override
  String get logFieldContext => '设备上下文';

  @override
  String get logFieldError => '错误';

  @override
  String get logFieldBrand => '品牌';

  @override
  String get logFieldManufacturer => '制造商';

  @override
  String get logFieldModel => '型号';

  @override
  String get logFieldSdkInt => 'SDK 版本';

  @override
  String get logFieldVersionName => '版本名';

  @override
  String get logFieldChannel => '渠道';

  @override
  String get logFieldHasNotificationPermission => '通知权限';

  @override
  String get logFieldHasPromotedPermissionDeclared => '已声明提升通知权限';

  @override
  String get logFieldCanPostPromotedNotifications => '可发布提升通知';

  @override
  String get logFieldIgnoringBatteryOptimizations => '忽略电池优化';

  @override
  String get logFieldKeepAliveAccessibilityEnabled => '无障碍保活已启用';

  @override
  String get logFieldHideFromRecentsEnabled => '从最近任务隐藏';

  @override
  String get logFieldTaskRemovedRecently => '近期任务被移除';

  @override
  String get logFieldLastTaskRemovedAt => '上次任务移除时间';

  @override
  String get logFieldProcessImportance => '进程重要性';

  @override
  String get logFieldAutoStartStatus => '自启动状态';

  @override
  String get logFieldLiveEnableBeforeClass => '课前超级岛';

  @override
  String get logFieldLiveEnableDuringClass => '课中超级岛';

  @override
  String get logFieldLiveEnableBeforeEnd => '下课前超级岛';

  @override
  String get logFieldLivePromoteDuringClass => '课中提升通知';

  @override
  String get logFieldLiveShowDuringClassNotification => '课中状态栏通知';

  @override
  String get logFieldLiveShowCountdown => '显示倒计时';

  @override
  String get logFieldLiveShowStageText => '显示阶段文字';

  @override
  String get logFieldLiveShowCourseName => '显示课程名';

  @override
  String get logFieldLiveShowLocation => '显示地点';

  @override
  String get logFieldLiveUseShortName => '使用简称';

  @override
  String get logFieldLiveHidePrefixText => '隐藏前缀文字';

  @override
  String get logFieldLiveDuringClassTimeDisplayMode => '课中时间显示模式';

  @override
  String get logFieldLiveEnableMiuiIslandLabelImage => '岛标签图片';

  @override
  String get logFieldLiveMiuiIslandLabelStyle => '岛标签样式';

  @override
  String get logFieldLiveMiuiIslandLabelContent => '岛标签内容';

  @override
  String get logFieldLiveMiuiIslandLabelFontColor => '岛标签字体颜色';

  @override
  String get logFieldLiveMiuiIslandLabelFontWeight => '岛标签字重';

  @override
  String get logFieldLiveMiuiIslandLabelRenderQuality => '岛标签渲染质量';

  @override
  String get logFieldLiveMiuiIslandLabelFontSize => '岛标签字号';

  @override
  String get logFieldLiveMiuiIslandLabelOffsetX => '岛标签 X 偏移';

  @override
  String get logFieldLiveMiuiIslandLabelOffsetY => '岛标签 Y 偏移';

  @override
  String get logFieldLiveMiuiIslandExpandedIconMode => '展开图标模式';

  @override
  String get logFieldLiveShowBeforeClassMinutes => '课前显示分钟数';

  @override
  String get logFieldLiveClassReminderStartMinutes => '上课提醒开始分钟';

  @override
  String get logFieldLiveEndSecondsCountdownThreshold => '下课秒倒计时阈值';

  @override
  String get logFieldState => '状态';

  @override
  String get logFieldRoute => '路由';

  @override
  String get logFieldPreviousRoute => '先前路由';

  @override
  String get logFieldProfileId => '课表配置 ID';

  @override
  String get logFieldReason => '原因';

  @override
  String get logFieldClientIp => '客户端 IP';

  @override
  String get logFieldPort => '端口';

  @override
  String get logFieldCourseName => '课程名';

  @override
  String get logFieldStage => '阶段';

  @override
  String get logFieldFrom => '来源页面';

  @override
  String get logFieldCurrentWeek => '当前周次';

  @override
  String get logFieldWeekday => '星期';

  @override
  String get logFieldUntilMillis => '暂停截止时间';

  @override
  String get logFieldStartAtMillis => '开始时间';

  @override
  String get logFieldMergedCourseCount => '合并课程数';

  @override
  String get logFieldDeletedCount => '删除数量';

  @override
  String get logFieldRequested => '请求数量';

  @override
  String get logFieldTarget => '目标';

  @override
  String get logFieldCount => '数量';

  @override
  String get logFieldValue => '值';

  @override
  String get logFieldSnapshotLength => '快照长度';

  @override
  String get logFieldStoredSnapshotVersion => '存储快照版本';

  @override
  String get logFieldIntentIsNull => 'Intent 为空';

  @override
  String get logFieldAction => '操作';

  @override
  String get logFieldStep => '步骤';

  @override
  String get logCatAppLoggerInitialized => '应用日志：初始化';

  @override
  String get logCatPrivacyConsentUpdated => '应用日志：隐私协议';

  @override
  String get logCatAppLogRecordingEnabled => '应用日志：记录开关';

  @override
  String get logCatStartupFlowStarted => '启动流程：开始';

  @override
  String get logCatStartupFlowCompleted => '启动流程：完成';

  @override
  String get logCatStartupFlowFailed => '启动流程：失败';

  @override
  String get logCatAppLifecycleStateChanged => '应用生命周期';

  @override
  String get logCatRoutePushed => '路由：入栈';

  @override
  String get logCatRoutePopped => '路由：出栈';

  @override
  String get logCatRouteReplaced => '路由：替换';

  @override
  String get logCatFlutterFrameworkError => 'Flutter 框架错误';

  @override
  String get logCatFlutterPlatformError => 'Flutter 平台错误';

  @override
  String get logCatFlutterZoneError => 'Flutter Zone 错误';

  @override
  String get logCatAppLogsDefaultMigrated => '应用日志：迁移';

  @override
  String get logCatTimetableLoadSettingsFailed => '课表：加载设置失败';

  @override
  String get logCatTimetableLoadCoursesFailed => '课表：加载课程失败';

  @override
  String get logCatTimetableLoadCurrentWeekFailed => '课表：加载周次失败';

  @override
  String get logCatHomeWidgetPinSupportFailed => '桌面小组件：检查固定支持';

  @override
  String get logCatHomeWidgetPinRequestFailed => '桌面小组件：请求固定';

  @override
  String get logCatHomeWidgetSyncFailed => '桌面小组件：同步失败';

  @override
  String get logCatHomeWidgetClearFailed => '桌面小组件：清空失败';

  @override
  String get logCatHomeWidgetScheduleFailed => '桌面小组件：调度刷新';

  @override
  String get logCatMiuiLiveInitializeFailed => '超级岛：初始化失败';

  @override
  String get logCatMiuiLiveOpenPromotedSettingsFailed => '超级岛：打开权限设置';

  @override
  String get logCatMiuiLiveOpenNotificationSettingsFailed => '超级岛：打开通知设置';

  @override
  String get logCatMiuiLiveOpenAutostartSettingsFailed => '超级岛：打开自启动设置';

  @override
  String get logCatMiuiLiveOpenBatterySettingsFailed => '超级岛：打开电池优化';

  @override
  String get logCatMiuiLiveOpenAccessibilitySettingsFailed => '超级岛：打开无障碍设置';

  @override
  String get logCatMiuiLiveHideFromRecentsFailed => '超级岛：隐藏最近任务';

  @override
  String get logCatLiveUpdateFlutterInitializeFailed => '超级岛：Flutter 初始化失败';

  @override
  String get logCatLiveUpdateStartFailed => '超级岛：启动失败';

  @override
  String get logCatLiveUpdateStopFailed => '超级岛：停止失败';

  @override
  String get logCatLiveUpdateDebugStatusFailed => '超级岛：调试状态失败';

  @override
  String get logCatLiveUpdateSettingsSynced => '超级岛：设置已同步';

  @override
  String get logCatLiveUpdateSnapshotSyncFailed => '超级岛：快照同步失败';

  @override
  String get logCatLiveUpdateSnapshotClearFailed => '超级岛：快照清空失败';

  @override
  String get logCatLanEditAuthFailed => '局域网编辑：认证';

  @override
  String get logCatLanEditCourseCreated => '局域网编辑：创建课程';

  @override
  String get logCatLanEditCourseUpdated => '局域网编辑：更新课程';

  @override
  String get logCatLanEditCourseDeleted => '局域网编辑：删除课程';

  @override
  String get logCatLanEditCourseGroupSaved => '局域网编辑：保存课程组';

  @override
  String get logCatLanEditMergeImported => '局域网编辑：合并导入';

  @override
  String get logCatLanEditCoursesBatchDeleted => '局域网编辑：批量删除';

  @override
  String get logCatLanEditCurrentWeekSet => '局域网编辑：设置周次';

  @override
  String get logCatLanEditSpreadsheetImported => '局域网编辑：表格导入';

  @override
  String get logCatLanEditSessionStarted => '局域网编辑：会话启动';

  @override
  String get logCatLanEditSessionStopped => '局域网编辑：会话停止';

  @override
  String get logCatLiveUpdateTestRequested => '超级岛测试：请求';

  @override
  String get logCatLiveUpdateTestNoSelection => '超级岛测试：无课程';

  @override
  String get logCatLiveUpdateTestSelectionReady => '超级岛测试：已选课程';

  @override
  String get logCatLiveUpdateTestSuspendSync => '超级岛测试：暂停同步';

  @override
  String get logCatLiveUpdateTestStarting => '超级岛测试：启动中';

  @override
  String get logCatLiveUpdateTestStarted => '超级岛测试：已启动';

  @override
  String get logCatLiveUpdateTestFailed => '超级岛测试：失败';

  @override
  String get logCatLiveUpdateSnapshotSettings => '超级岛：快照设置';

  @override
  String get logCatLiveUpdateSnapshotSynced => '超级岛：快照已同步';

  @override
  String get logCatLiveUpdateSnapshotCleared => '超级岛：快照已清空';

  @override
  String get logCatLiveUpdateAlarmTriggered => '超级岛：闹钟触发';

  @override
  String get logCatLiveUpdateSchedulerResume => '超级岛：调度恢复';

  @override
  String get logCatLiveUpdateRescheduleHoliday => '超级岛：节假日跳过';

  @override
  String get logCatLiveUpdateRescheduleActive => '超级岛：立即启动';

  @override
  String get logCatLiveUpdateRescheduleScheduled => '超级岛：已调度';

  @override
  String get logCatLiveUpdateSnapshotParseFailed => '超级岛：快照解析失败';

  @override
  String get logCatLiveUpdateSnapshotInvalidatedAfterUpgrade => '超级岛：升级后快照失效';

  @override
  String get logCatLiveUpdatePayloadSelected => '超级岛：已选负载';

  @override
  String get logCatLiveUpdateSchedulerStartFailed => '超级岛：调度启动失败';

  @override
  String get logCatLiveUpdateStartRequested => '超级岛：请求启动';

  @override
  String get logCatLiveUpdateStopRequested => '超级岛：请求停止';

  @override
  String get logCatLiveUpdateServiceMissingPayload => '超级岛：服务缺少负载';

  @override
  String get logCatLiveUpdateServiceStarted => '超级岛：服务已启动';

  @override
  String get logCatLiveUpdateServiceStartFailed => '超级岛：服务启动失败';

  @override
  String get logCatLiveUpdateServiceFgsStartDenied =>
      '超级岛：服务内 startForeground 被拒';

  @override
  String get logCatLiveUpdateFgsRetryScheduled => '超级岛：前台服务被拒，已排退避重试';

  @override
  String get logCatLiveUpdateFgsStartGaveUp => '超级岛：重试耗尽，已降级为普通通知';

  @override
  String get logCatLiveUpdateTaskRemoved => '超级岛：任务被移除';

  @override
  String get logCatLiveUpdateTaskRemovedResumed => '超级岛：任务移除后恢复';

  @override
  String get logCatLiveUpdateBeforeClassQuickAction => '超级岛：课前快捷操作';

  @override
  String get logCatLiveUpdateBeforeClassQuickActionRestored => '超级岛：课前快捷操作已恢复';

  @override
  String get logCatLiveUpdateStatusBarDismissed => '超级岛：状态栏通知已关闭';

  @override
  String get logCatLiveUpdateNotPromoted => '超级岛：未提升通知';

  @override
  String get logCatLiveUpdatePromotedNotShown => '超级岛：提升未显示';

  @override
  String get logCatLiveUpdateServiceStopped => '超级岛：服务已停止';

  @override
  String get logCatKeepAliveAccessibilityConnected => '保活：无障碍已连接';

  @override
  String get logCatDiagnosticsEnabled => '诊断：已开启';

  @override
  String get logCatDiagnosticsCleared => '诊断：已清空';

  @override
  String get logCatDiagnosticsBootstrap => '诊断：引导';

  @override
  String get logCatFlutterDiagnostic => 'Flutter 诊断';

  @override
  String get logCatFlutterDiagnosticEvent => 'Flutter 诊断事件';

  @override
  String get logCatRenderFailed => '渲染失败';

  @override
  String get logCatDebugSnapshot => '调试快照';

  @override
  String get logExportTitle => '轻屿课表 - 应用日志';

  @override
  String get appUpdateMirrorPresetGhfast => '默认镜像';

  @override
  String get appUpdateMirrorPresetGhproxyCn => '备用镜像 1';

  @override
  String get appUpdateMirrorPresetGhLlkk => '备用镜像 2';

  @override
  String get appUpdateMirrorPresetGhProxyCom => '备用镜像 3';

  @override
  String get appUpdateMirrorPresetGhproxyNet => '备用镜像 4';

  @override
  String get appUpdateMirrorPresetCustom => '自定义';

  @override
  String get appUpdateMirrorPresetCustomDescription => '填写自定义镜像地址前缀';

  @override
  String get cloudBackupRetentionTitle => '备份保留策略';

  @override
  String get cloudBackupMaxCountTitle => '最多保留份数';

  @override
  String get cloudBackupMaxCountSubtitle => '超过后自动删除最旧的备份';

  @override
  String cloudBackupMaxCountOption(int count) {
    return '$count 份';
  }

  @override
  String get cloudBackupMaxAgeTitle => '最长保留天数';

  @override
  String get cloudBackupMaxAgeSubtitle => '超过后自动删除过期备份';

  @override
  String cloudBackupMaxAgeOption(int days) {
    return '$days 天';
  }

  @override
  String get statisticsShareText => '来自轻屿课表的学期统计';

  @override
  String get aboutUpdateAvailableHeadline => '有版本更新';

  @override
  String get aboutAlreadyLatestHeadline => '已是最新版本';

  @override
  String get aboutDownloadChannelSectionTitle => '下载渠道';

  @override
  String get aboutMirrorProbeFailedLabel => '失败';

  @override
  String timeSchemeImportSupplementName(String name) {
    return '$name（导入补齐）';
  }

  @override
  String profileTimeSchemeName(String profileName) {
    return '$profileName 时间';
  }

  @override
  String get currentProfileTimeSchemeName => '当前课表时间';

  @override
  String get unnamedTimetableProfile => '未命名课表';

  @override
  String get cloudBackupManualProtectedTitle => '手动备份永不过期';

  @override
  String get cloudBackupManualProtectedSubtitle => '开启后，手动创建的备份不会被自动清理';

  @override
  String courseImportPortalUrlMissingBody(
    String schoolName,
    String adapterName,
  ) {
    return '“$schoolName / $adapterName” 没有默认登录地址，请先输入学校教务系统网址';
  }

  @override
  String guidePermissionsProgressLabel(int ready, int total) {
    return '已就绪 $ready/$total';
  }

  @override
  String get locationTimeMatchEntryTitle => '地點作息匹配';

  @override
  String get locationTimeMatchEntrySubtitle => '按上課地點關鍵詞自動選用時間範本';

  @override
  String get locationTimeMatchTitle => '地點作息匹配';

  @override
  String get locationTimeMatchSubtitle =>
      '按地點關鍵詞自動匹配時間範本。重新匹配僅更新命中課程的鐘點，未命中課程保持不變。';

  @override
  String get locationTimeMatchWeekAxisNote =>
      '说明：首页左侧时间列仍显示课表默认模板；卡片/详情/实况上的钟点以地点匹配结果为准。';

  @override
  String get locationTimeMatchPreviewLabel => '试匹配地点';

  @override
  String get locationTimeMatchPreviewHint => '例如 A1062 或 A主201';

  @override
  String get locationTimeMatchPreviewNoMatch => '未命中任何地点组，将使用课表默认时间模板';

  @override
  String locationTimeMatchPreviewResult(
    String group,
    String scheme,
    String keyword,
  ) {
    return '将匹配：$group · $scheme（关键词 $keyword）';
  }

  @override
  String get locationTimeMatchApplyActive => '重新匹配目前課表';

  @override
  String get locationTimeMatchApplyTitle => '重新匹配目前課表？';

  @override
  String locationTimeMatchApplyMessage(int count) {
    return '目前有 $count 門課程命中地點規則。節次適配的課程會恢復自動匹配並同步鐘點；此前手動指定的模板將被清除，未命中的課程不會改變。';
  }

  @override
  String get locationTimeMatchApplyConfirm => '重新匹配';

  @override
  String locationTimeMatchApplyUpdated(int matched, int updated) {
    return '已重新匹配 $matched 門，更新 $updated 門鐘點';
  }

  @override
  String locationTimeMatchApplyAlreadyAligned(int matched) {
    return '已重新匹配 $matched 門，鐘點無需改寫';
  }

  @override
  String get locationTimeMatchApplyNoneMatched => '沒有匹配到可套用的課程';

  @override
  String locationTimeMatchApplyOverflowResult(int matched, int count) {
    return '有 $count 門課節次無法對號入座（範本節數不足），已拒絕套用';
  }

  @override
  String locationTimeMatchApplyOverflowHint(String names) {
    return '未套用示例：$names';
  }

  @override
  String get locationTimeMatchEmpty => '還沒有地點組';

  @override
  String get locationTimeMatchCreateGroup => '新建地点组';

  @override
  String get locationTimeMatchEditGroup => '编辑地点组';

  @override
  String get locationTimeMatchUnknownScheme => '未知时间模板';

  @override
  String get locationTimeMatchNoKeywords => '未设置关键词';

  @override
  String locationTimeMatchBoundScheme(String name) {
    return '时间模板：$name';
  }

  @override
  String locationTimeMatchKeywordsLine(String keywords) {
    return '关键词：$keywords';
  }

  @override
  String get locationTimeMatchDeleteTitle => '删除地点组？';

  @override
  String locationTimeMatchDeleteMessage(String name) {
    return '確定刪除「$name」？自動匹配的課程將恢復課表預設模板；手動指定模板的課程不受影響。';
  }

  @override
  String get locationTimeMatchDeleted => '已删除地点组';

  @override
  String get locationTimeMatchGroupNameLabel => '地点组名称';

  @override
  String get locationTimeMatchGroupNameHint => '例如：主教学楼 / 其他教学楼';

  @override
  String get locationTimeMatchBoundSchemeLabel => '绑定时间模板';

  @override
  String get locationTimeMatchNeedTimeScheme => '请先创建至少一套时间模板';

  @override
  String get locationTimeMatchEnabledLabel => '启用此地点组';

  @override
  String get locationTimeMatchKeywordsSection => '地点关键词';

  @override
  String get locationTimeMatchKeywordsHelp =>
      '可从课表地点一键识别楼栋，或手动填写关键词（如 A主、A1、A6）。匹配模式建议用「前缀」，更长的关键词优先。';

  @override
  String get locationTimeMatchSelectedKeywords => '已选关键词';

  @override
  String get locationTimeMatchNoSelectedKeywords => '尚未添加关键词';

  @override
  String get locationTimeMatchPickFromLocations => '从课表地点选择';

  @override
  String get locationTimeMatchBuildingSuggestions => '从课表识别的楼栋';

  @override
  String get locationTimeMatchNoBuildingSuggestions => '当前课表没有可识别的楼栋地点';

  @override
  String get locationTimeMatchAddBuilding => '添加';

  @override
  String get locationTimeMatchAddAllBuildings => '一键添加全部未配置楼栋';

  @override
  String locationTimeMatchBuildingRoomCount(int count) {
    return '$count 间教室';
  }

  @override
  String locationTimeMatchBuildingGateTags(String tags) {
    return '标签：$tags';
  }

  @override
  String locationTimeMatchKeywordExtracted(String keyword) {
    return '已从地点提取关键词 $keyword';
  }

  @override
  String get locationTimeMatchKeywordAlreadyExists => '关键词已存在';

  @override
  String locationTimeMatchKeywordUsedByGroup(String group) {
    return '關鍵詞已被「$group」使用';
  }

  @override
  String get locationTimeMatchAddKeyword => '手动添加关键词';

  @override
  String get locationTimeMatchKeywordLabel => '关键词';

  @override
  String get locationTimeMatchKeywordHint => 'A1 / A主 / 六教';

  @override
  String get locationTimeMatchModeLabel => '匹配模式';

  @override
  String get locationTimeMatchModePrefix => '前缀';

  @override
  String get locationTimeMatchModeContains => '包含';

  @override
  String get locationTimeMatchModeExact => '精确';

  @override
  String get locationTimeMatchKeywordTooShort => '关键词过短，容易误匹配';

  @override
  String get locationTimeMatchNameRequired => '请填写地点组名称';

  @override
  String get locationTimeMatchKeywordRequired => '请至少添加一个关键词';

  @override
  String get locationTimeMatchSaved => '地点组已保存';

  @override
  String get locationTimeMatchSaveFailed => '保存失败';

  @override
  String get followLocationAutoTimeScheme => '跟隨課表 / 地點自動';

  @override
  String get followLocationAutoTimeSchemeDescription =>
      '未手動指定時，依上課地點關鍵詞自動匹配時間範本；未命中則用課表預設範本';

  @override
  String locationTimeMatchedSchemeHint(String scheme) {
    return '自動 · $scheme';
  }

  @override
  String locationTimeAutoResolvedByGroup(String group, String scheme) {
    return '地點組「$group」→ $scheme';
  }

  @override
  String locationTimeAutoResolvedByTimetable(String scheme) {
    return '課表預設 → $scheme';
  }

  @override
  String get scheduleDateRuleSectionTitle => '日期作息規則';

  @override
  String get scheduleDateRuleSectionSubtitle =>
      '開始日自動將所選模板套用為全部課表預設作息。最多 2 條且區間不重疊；地點作息匹配優先。';

  @override
  String get scheduleDateRuleAdd => '新增日期規則';

  @override
  String get scheduleDateRuleEdit => '編輯日期規則';

  @override
  String get scheduleDateRuleEmpty => '未設定日期規則';

  @override
  String get scheduleDateRuleNameLabel => '規則名稱';

  @override
  String get scheduleDateRuleNameHint => '例如：夏令時 / 冬令時';

  @override
  String get scheduleDateRuleStartDate => '開始日期';

  @override
  String get scheduleDateRuleEndDate => '結束日期';

  @override
  String get scheduleDateRuleBoundScheme => '使用時間模板';

  @override
  String get scheduleDateRuleEnabled => '啟用';

  @override
  String get scheduleDateRuleActiveToday => '今天在區間內';

  @override
  String scheduleDateRuleRangeSummary(String start, String end) {
    return '$start ~ $end';
  }

  @override
  String get scheduleDateRuleMaxReached => '最多只能新增 2 條日期規則';

  @override
  String get scheduleDateRuleNeedScheme => '請先建立至少一套時間模板';

  @override
  String get scheduleDateRuleNameRequired => '請填寫規則名稱';

  @override
  String get scheduleDateRuleSaved => '日期規則已儲存';

  @override
  String get scheduleDateRuleSavedAndApplied => '日期規則已儲存，今天已更新所有課表的預設作息';

  @override
  String get scheduleDateRuleSavedForFuture => '日期規則已儲存，將在開始日期更新所有課表的預設作息';

  @override
  String get scheduleDateRuleSavedButApplyFailed =>
      '日期規則已儲存，但今天自動套用失敗（請檢查模板節次是否足夠）';

  @override
  String get scheduleDateRuleDeleted => '已刪除日期規則';

  @override
  String get scheduleDateRuleDeleteTitle => '刪除日期規則？';

  @override
  String scheduleDateRuleDeleteMessage(String name) {
    return '確定刪除「$name」？刪除後不會自動還原已套用的作息，需手動調整。';
  }

  @override
  String scheduleDateRuleSaveFailed(String reason) {
    return '儲存失敗：$reason';
  }

  @override
  String get scheduleDateRuleErrorMax => '已達到 2 條上限';

  @override
  String get scheduleDateRuleErrorOverlap => '日期區間與已有規則重疊';

  @override
  String get scheduleDateRuleErrorInvalidDate => '日期格式無效';

  @override
  String get scheduleDateRuleErrorEndBeforeStart => '結束日期不能早於開始日期';

  @override
  String get scheduleDateRuleErrorSchemeRequired => '請選擇時間模板';

  @override
  String get scheduleDateRuleErrorNameRequired => '請填寫名稱';

  @override
  String get scheduleDateRuleNote => '地點匹配優先於日期規則。';

  @override
  String get frostedGlassModeLabel => '玻璃模式';

  @override
  String get liquidGlassScopeSectionTitle => '液態玻璃作用範圍';

  @override
  String get liquidGlassScopePopupTitle => '下拉選擇彈窗';

  @override
  String get liquidGlassScopePopupSubtitle => '玻璃模式等設定列彈出的小氣泡選單';

  @override
  String get liquidGlassScopeSelectSheetTitle => '全螢幕選擇面板';

  @override
  String get liquidGlassScopeSelectSheetSubtitle => '預設主題、字體等長列表選擇彈窗，預設保持磨砂';

  @override
  String get liquidGlassScopeSheetDialogTitle => '彈窗與對話框';

  @override
  String get liquidGlassScopeSheetDialogSubtitle => '底部彈窗、確認對話框與動作選單';

  @override
  String get liquidGlassScopeHomeChromeTitle => '首頁玻璃帶';

  @override
  String get liquidGlassScopeHomeChromeSubtitle => '標題列與星期列的玻璃背景帶';

  @override
  String get liquidGlassScopeDockTitle => '玻璃塢導航';

  @override
  String get liquidGlassScopeDockSubtitle => '底部懸浮藥丸與加課圓鈕';

  @override
  String get liquidGlassScopePickerButtonsTitle => '壁紙選點按鈕';

  @override
  String get liquidGlassScopePickerButtonsSubtitle => '壁紙位置選擇頁懸浮在壁紙上的玻璃按鈕';

  @override
  String get frostedGlassModeFrosted => '經典磨砂';

  @override
  String get frostedGlassModeLiquid => '液態玻璃';

  @override
  String get frostedGlassModeGaussian => '高斯模糊';

  @override
  String get frostedGlassModeTranslucent => '半透明';

  @override
  String get frostedLiquidGlassHint => '液態玻璃需要高效能裝置支援';

  @override
  String get advancedMaterialTitle => '進階材質';

  @override
  String get advancedMaterialEntrySubtitle => '液態玻璃參數微調';

  @override
  String get liquidGlassPresetLabel => '液態玻璃預設';

  @override
  String get liquidGlassPresetClear => '清澈';

  @override
  String get liquidGlassPresetLight => '輕霧';

  @override
  String get liquidGlassPresetStandard => '標準';

  @override
  String get liquidGlassPresetDense => '濃密';

  @override
  String get liquidGlassPresetCustom => '自訂';

  @override
  String get courseCardSettingsTitle => '課程卡片';

  @override
  String get courseCardSectionFields => '顯示欄位';

  @override
  String get courseCardSectionLayout => '版面配置';

  @override
  String get courseCardSurfaceStyleLabel => '卡片外觀';

  @override
  String get courseCardSurfaceStyleSolid => '實體卡片';

  @override
  String get courseCardSurfaceStyleGaussian => '高斯模糊';

  @override
  String get courseCardSectionColor => '顏色';

  @override
  String get liveSelfCheckTitle => '自我檢查';

  @override
  String get collapsibleLargeTitle => '折疊大標題';

  @override
  String get liquidGlassCustomExpandedTitle => '自訂參數';

  @override
  String get liquidGlassThicknessLabel => '厚度';

  @override
  String get liquidGlassBlurLabel => '模糊強度';

  @override
  String get liquidGlassTintLabel => '染色強度';

  @override
  String get liquidGlassLightIntensityLabel => '燈光強度';

  @override
  String get liquidGlassAmbientStrengthLabel => '環境光強度';

  @override
  String get liquidGlassRefractiveIndexLabel => '折射率';

  @override
  String get liquidGlassSaturationLabel => '飽和度';

  @override
  String get liquidGlassChromaticAberrationLabel => '色差';

  @override
  String get liquidGlassLightAngleLabel => '光照角度';

  @override
  String get liquidGlassVisibilityLabel => '可見性';

  @override
  String get liquidGlassResetAction => '還原預設';

  @override
  String get diagnosticsEntryTitle => '診斷';

  @override
  String get memoryStatsEntryTitle => '記憶體狀態';

  @override
  String get generalSettingsTitle => '一般';

  @override
  String get settingsResetDefaultsTitle => '還原預設值';

  @override
  String get settingsResetDefaultsConfirmTitle => '確認還原';

  @override
  String get settingsResetConfirmBodyCourseCard => '將把課程卡片的顯示欄位、版面與顏色恢復為預設值。';

  @override
  String get settingsResetConfirmBodyTimetablePage =>
      '將把課表頁面的密度、回到當前週按鈕與背景（含清除桌布）恢復為預設值。';

  @override
  String get settingsResetConfirmBodyAppearance => '將把主題模式、字型、主題色與玻璃質感恢復為預設值。';

  @override
  String get settingsResetConfirmBodyHomeWidget => '將把桌面小工具的顯示項目與外觀恢復為預設值。';

  @override
  String get settingsResetConfirmBodyHomeNavigation => '將把底欄、選單與首頁標題設定恢復為預設值。';

  @override
  String get settingsResetDoneMessage => '設定已重設';

  @override
  String get timetablePageSettingsTitle => '課表頁面';

  @override
  String get timetablePageSectionDensity => '密度';

  @override
  String get timetablePageSectionBackToWeek => '回到目前週次';

  @override
  String get timetablePageSectionBackground => '背景';

  @override
  String get largeTitleContentGap => '16.0';

  @override
  String get selectTimeTitle => '選擇時間';

  @override
  String get liveSelfCheckSubtitle => '執行自我檢查';

  @override
  String get frostedSheetPreviewShowTitle => '顯示預覽';

  @override
  String get frostedSheetPreviewShowSubtitle => '在頂部顯示磨砂玻璃預覽';

  @override
  String get aboutSupportUpdatesSectionTitle => '支援與更新';

  @override
  String get aboutProductSectionTitle => '產品';

  @override
  String get aboutCommunitySectionTitle => '社群';

  @override
  String get selectStartTimeTitle => '選擇開始時間';

  @override
  String get selectEndTimeTitle => '選擇結束時間';

  @override
  String get weekdayInkContrastTitle => '文字對比度不足';

  @override
  String get weekdayInkContrastBodyDark =>
      '你的資訊欄文字顏色在深色桌布上對比度不足，已暫時切換為自動白色以保證可讀。可在「課表頁面 → 文字顏色」中更換顏色或恢復預設。';

  @override
  String get weekdayInkContrastBodyLight =>
      '你的資訊欄文字顏色在淺色桌布上對比度不足，已暫時切換為自動黑色以保證可讀。可在「課表頁面 → 文字顏色」中更換顏色或恢復預設。';

  @override
  String get gotItAction => '知道了';

  @override
  String get settingsTimetableSectionTitle => '課表';

  @override
  String get liveIslandLabelEntryEnabled => '已開啟';

  @override
  String get liveIslandLabelEntryDisabled => '已關閉';

  @override
  String get settingsDisplayAppearanceSectionTitle => '課表顯示';

  @override
  String get settingsReminderDesktopSectionTitle => '提醒與桌面';

  @override
  String get settingsAppSectionTitle => '應用程式';

  @override
  String get settingsDataShareSectionTitle => '資料與共享';

  @override
  String get coupleTimetableEntryUnboundLabel => '未綁定';

  @override
  String get settingsAboutSectionTitle => '關於';

  @override
  String get diagnosticsEntrySubtitle => '日誌 · 自檢 · 記憶體';

  @override
  String get settingsSemesterScreenTitle => '學期設定';

  @override
  String get syncCurrentWeekNeedsStartDate => '請先設定開學日期';

  @override
  String get liveNotificationPermissionMissing => '缺少通知權限';

  @override
  String get developerSectionTitle => '開發人員選項';

  @override
  String get liveTestingFixtureEntryTitle => '實況測試樣例';

  @override
  String get hyperosShowcaseEntryTitle => 'HyperOS 元件展示';

  @override
  String get hyperosShowcaseEntrySubtitle => 'HyperOS 元件預覽';

  @override
  String get miuixShowcaseEntryTitle => 'Miuix 元件展示';

  @override
  String get miuixShowcaseEntrySubtitle => 'Miuix 元件預覽';

  @override
  String get debugUiOverlayToggleTitle => '除錯 UI 疊層';

  @override
  String get scheduleRepeatSectionTitle => '重複設定';

  @override
  String get scheduleRepeatNone => '不重複';

  @override
  String get scheduleRepeatDaily => '每天';

  @override
  String get scheduleRepeatWeekly => '每週';

  @override
  String get scheduleRepeatEndDateLabel => '重複結束日期';

  @override
  String get scheduleRepeatEndDateHint => '重複行程需要設定結束日期';

  @override
  String get scheduleRepeatWeeklyHint => '按開始日期對應的星期重複';

  @override
  String get scheduleReminderSectionTitle => '行程提醒';

  @override
  String get scheduleReminderOff => '不提醒';

  @override
  String scheduleReminderMinutes(int minutes) {
    return '提前 $minutes 分鐘';
  }

  @override
  String get scheduleReminderPermissionMissing => '通知權限未開啟，行程仍會儲存，但提醒可能無法送達';

  @override
  String get scheduleReminderPermissionAction => '檢查通知權限';

  @override
  String get scheduleEnabledTitle => '啟用行程';

  @override
  String get scheduleDisabledSubtitle => '已暫停，不會顯示提醒';

  @override
  String get scheduleEditScopeTitle => '編輯範圍';

  @override
  String get scheduleEditScopeThis => '僅本次';

  @override
  String get scheduleEditScopeAll => '全部重複行程';

  @override
  String get scheduleDeleteScopeTitle => '刪除範圍';

  @override
  String get scheduleDeleteScopeThis => '僅刪除本次';

  @override
  String get scheduleDeleteScopeAll => '刪除全部重複行程';

  @override
  String get scheduleOccurrenceEditHint => '你正在編輯這條重複行程的一次實例';

  @override
  String get scheduleRepeatEndRequired => '請選擇重複結束日期';

  @override
  String get homeMenuTasksTitle => '任務清單';

  @override
  String get taskListTitle => '任務清單';

  @override
  String get addTask => '新增任務';

  @override
  String get editTask => '編輯任務';

  @override
  String get saveTask => '儲存任務';

  @override
  String get taskTitleLabel => '任務標題';

  @override
  String get taskTitleHint => '例如：完成第三章習題';

  @override
  String get taskTitleRequired => '請輸入任務標題';

  @override
  String get taskNoteLabel => '備註';

  @override
  String get taskNoteHint => '補充說明（可選）';

  @override
  String get taskDueDateLabel => '截止日期';

  @override
  String get taskNoDueDate => '無截止日期';

  @override
  String get taskCourseLabel => '來源課程';

  @override
  String get taskCourseFilter => '課程篩選';

  @override
  String get taskAllCourses => '全部課程';

  @override
  String get taskNoCourse => '無關聯課程';

  @override
  String get taskAllFilter => '全部';

  @override
  String get taskTodayFilter => '今日';

  @override
  String get taskWeekFilter => '本週';

  @override
  String get taskOverdueSection => '已逾期';

  @override
  String get taskCompletedSection => '已完成';

  @override
  String get taskNoTasks => '還沒有任務';

  @override
  String get taskNoTasksForToday => '今日沒有待辦任務';

  @override
  String get taskNoTasksForWeek => '本週沒有待辦任務';

  @override
  String get taskNoTasksForCourse => '這個課程暫無任務';

  @override
  String get taskDelete => '刪除任務';

  @override
  String get taskDeleteConfirm => '確定刪除這個任務嗎？';

  @override
  String get taskHomeworkDefaultTitle => '課程作業';

  @override
  String get taskAddFromCourse => '新增任務';

  @override
  String get taskViewCourse => '查看課程';

  @override
  String get taskSaved => '任務已儲存';

  @override
  String get taskUpdated => '任務已更新';

  @override
  String get taskDeleted => '任務已刪除';

  @override
  String get icsExportSectionTitle => '匯出日曆';

  @override
  String get icsExportSectionSubtitle => '選擇課程、考試和日程，產生 ICS 日曆並分享';

  @override
  String get icsExportTitle => '匯出日曆';

  @override
  String get icsExportProfileLabel => '課表';

  @override
  String get icsExportProfileSelectTitle => '選擇課表';

  @override
  String get icsExportDateRangeTitle => '日期範圍';

  @override
  String get icsExportStartDate => '開始日期';

  @override
  String get icsExportEndDate => '結束日期';

  @override
  String get icsExportTypesTitle => '日曆內容';

  @override
  String get icsExportCourses => '課程';

  @override
  String get icsExportExams => '考試';

  @override
  String get icsExportSchedules => '日程';

  @override
  String get icsExportButton => '匯出並分享';

  @override
  String get icsExportSharing => '準備日曆…';

  @override
  String get icsExportNoProfiles => '暫無可匯出的課表';

  @override
  String get icsExportDateRangeInvalid => '請選擇不早於開始日期的結束日期';

  @override
  String get icsExportNoSelection => '至少選擇一種日曆內容';

  @override
  String get icsExportSemesterStartRequired => '匯出課程前，請先設定學期開始日期';

  @override
  String get icsExportNoEvents => '所選日期範圍內沒有日曆事件';

  @override
  String get icsExportCancelled => '已取消分享日曆';

  @override
  String get icsExportFailed => '日曆匯出失敗，請稍後再試';

  @override
  String icsExportShared(int count) {
    return '已匯出並分享 $count 個日曆事件';
  }

  @override
  String get icsExportShareText => '這是來自輕屿課表的日曆檔案';

  @override
  String get icsExportShareSubject => '輕屿課表日曆';

  @override
  String get homeNavigationTitle => '首頁與導覽';

  @override
  String get homeMenuCustomizeSectionTitle => '右上角選單';

  @override
  String get homeNavigationSubtitle => '底欄形態、選單與首頁標題';

  @override
  String get homeNavigationFormLabel => '應用形態';

  @override
  String get homeNavigationFormClassic => '經典形態';

  @override
  String get homeNavigationFormClassicSubtitle => '保持現有的頁面與導覽方式';

  @override
  String get homeNavigationFormGlassDock => '玻璃塢';

  @override
  String get homeNavigationFormGlassDockSubtitle => '懸浮玻璃底欄，切換日/週課表';

  @override
  String get glassDockTabWeek => '週課表';

  @override
  String get glassDockTabDay => '日課表';

  @override
  String get glassDockLayoutLabel => '玻璃塢內容佈局';

  @override
  String get glassDockLayoutOverlay => '滿屏懸浮';

  @override
  String get glassDockLayoutOverlaySubtitle => '課表滿屏顯示，底欄浮動在課表之上';

  @override
  String get glassDockLayoutInset => '內容避讓';

  @override
  String get glassDockLayoutInsetSubtitle => '課表底部預留空間，底欄懸浮在下方';

  @override
  String get glassDockInsetClearanceLabel => '避讓高度';

  @override
  String get glassDockRoundActionLabel => '圓鈕功能';

  @override
  String get glassDockButtonIconTitle => '圓鈕圖示';

  @override
  String get glassDockButtonIconDefault => '預設（加號）';

  @override
  String get glassDockButtonIconSearchHint => '搜尋圖示名稱';

  @override
  String get glassDockCustomizeSectionTitle => '底部導覽列';

  @override
  String get glassDockCustomizeTitle => '自訂底欄按鈕';

  @override
  String get homeDockEditorViewCategory => '檢視切換';

  @override
  String get glassDockEntriesSectionTitle => '底欄入口';

  @override
  String get glassDockShowDayTabTitle => '顯示日課表入口';

  @override
  String get glassDockShowWeekTabTitle => '顯示週課表入口';

  @override
  String get glassDockShowAddButtonTitle => '顯示圓鈕';

  @override
  String get glassDockShowAddButtonSubtitle => '在藥丸右側顯示獨立圓鈕，功能與圖示可在下方自訂';

  @override
  String get glassDockButtonBackToWeekLabel => '回本週 / 今天';

  @override
  String get glassDockExtraButtonSemanticLabel => '新增課程';

  @override
  String get homeMenuStyleLabel => '右上角選單樣式';

  @override
  String get homeMenuStyleList => '列表選單';

  @override
  String get homeMenuStyleGrid => '八宮格選單';

  @override
  String get homeMenuStyleListSubtitle => '錨定清單，可自訂';

  @override
  String get homeMenuStyleGridSubtitle => '圖示瓷貼，可自訂';

  @override
  String get homeMenuCustomizeTitle => '自訂選單按鈕';

  @override
  String homeGridCustomizeDetails(int count, int max) {
    return '已啟用 $count/$max 個';
  }

  @override
  String homeGridEditorHintBody(int max) {
    return '最多放置 $max 個按鈕；按住項目拖動即可排序。';
  }

  @override
  String get homeGridEditorEnabledTitle => '已啟用';

  @override
  String get homeGridEditorAvailableTitle => '可新增';

  @override
  String get homeGridEditorRemoveTooltip => '移除';

  @override
  String get homeGridEditorAddTooltip => '新增';

  @override
  String get homeGridEditorResetAction => '恢復預設排列';

  @override
  String get homeGridEditorAllAdded => '所有入口都已啟用';

  @override
  String get homeGridEditorMaxReached => '已達上限';

  @override
  String get homeGridEditorPinnedTooltip => '此入口用於重新開啟本頁，無法移除';

  @override
  String get homeMenuCategoryFeatures => '功能入口';

  @override
  String get homeMenuCategoryData => '資料與同步';

  @override
  String get homeMenuCategoryPreferences => '偏好設定';

  @override
  String get homeMenuCategoryAbout => '關於與支援';

  @override
  String classAlarmLeadMinutesLabel(int minutes) {
    return '提前 $minutes 分鐘';
  }

  @override
  String get classAlarmInvalidTimeToast => '這門課的節次超出時間模板，無法設定鬧鐘';

  @override
  String get classAlarmSheetTitle => '上課提醒';

  @override
  String classAlarmQuickOption(Object minutes) {
    return '上課前 $minutes 分鐘提醒';
  }

  @override
  String get classAlarmCustomOption => '自訂提醒時間…';

  @override
  String classAlarmExistingLabel(Object time) {
    return '已設提醒：$time';
  }

  @override
  String get classAlarmSetToast => '提醒已設定';

  @override
  String get classAlarmRemovedToast => '已取消這堂課的提醒';

  @override
  String get classAlarmPastToast => '所選時間已過，請換一個時間';

  @override
  String get classAlarmNoSemesterToast => '請先在設定中填寫學期開始日期';

  @override
  String get classAlarmActionLabel => '設這節課的鬧鐘';

  @override
  String classAlarmConfirmMessage(String detail) {
    return '將在系統時鐘創建：$detail。系統鬧鐘無法識別假期與調休，停課期間照常響鈴；刪除請在系統時鐘中完成。';
  }

  @override
  String classAlarmVariableSuffix(String days) {
    return '另外，$days的第一節課時間在不同周不一致，這些天未創建鬧鐘。';
  }

  @override
  String get classAlarmEntryTitle => '上課鬧鐘';

  @override
  String get classAlarmGroupSetup => '添加鬧鐘';

  @override
  String get classAlarmGroupBehavior => '響鈴行為';

  @override
  String get classAlarmAddAllTitle => '批量添加上課鬧鐘';

  @override
  String get classAlarmRangeNext4Weeks => '未來 4 周';

  @override
  String get classAlarmRangeNext8Weeks => '未來 8 周';

  @override
  String get classAlarmRangeLabel => '添加範圍';

  @override
  String get classAlarmRangeRemaining => '本週起至學期結束';

  @override
  String get classAlarmRangeWhole => '整學期';

  @override
  String get classAlarmLeadTitle => '提前量';

  @override
  String get classAlarmSkipUiTitle => '跳過確認頁';

  @override
  String get classAlarmSkipUiSubtitle => '嘗試直接寫入鬧鐘，不彈出時鐘確認頁（部分機型不支持）';

  @override
  String get classAlarmOpenClock => '打開系統時鐘';

  @override
  String get classAlarmConfirmTitle => '創建重複鬧鐘？';

  @override
  String get classAlarmNoSchemeToast => '請先在設置中選擇時間模板';

  @override
  String get classAlarmNoDataToast => '所選範圍內沒有找到課表';

  @override
  String get classAlarmAddedToast => '已交給系統時鐘處理';

  @override
  String get classAlarmLaunchFailedToast => '未找到可處理的時鐘應用';

  @override
  String get classAlarmCourseConfirmTitle => '添加這節課的重複鬧鐘？';

  @override
  String classAlarmCourseConfirmMessage(
    String weekday,
    String time,
    int lead,
    String weeks,
  ) {
    return '將在系統時鐘創建每週$weekday $time 的重複鬧鐘（比上課提前$lead分鐘響鈴；上課週次：$weeks）。假期與非上課週仍會響鈴，刪除需在系統時鐘中完成。';
  }

  @override
  String get classAlarmDaySeparator => '、';

  @override
  String get classAlarmDetailSeparator => '；';
}
