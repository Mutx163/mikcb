from pathlib import Path

p = Path('lib/screens/hyperos_showcase_screen.dart')
s = p.read_text(encoding='utf-8')
repls = [
    ("subtitle: 'mikcb 澎湃风格组件一览'", "subtitle: l10n.hyperosShowcaseKitSubtitle"),
    ("_section('标签 / 手风琴 / 提示')", "_section(l10n.hyperosShowcaseSectionTags)"),
    ("'第一节'", "l10n.hyperosShowcaseAccordionSection1"),
    ("'展开后显示的内容区域。'", "l10n.hyperosShowcaseAccordionSection1Body"),
    ("'第二节'", "l10n.hyperosShowcaseAccordionSection2"),
    ("'可折叠分组，替代 FAccordion。'", "l10n.hyperosShowcaseAccordionSection2Body"),
    ("_section('列表行 · 导航')", "_section(l10n.hyperosShowcaseSectionNavRows)"),
    ("details: '带图标'", "details: l10n.hyperosShowcaseNavRowWithIcon"),
    ("subtitle: '无左侧彩图标'", "subtitle: l10n.hyperosShowcaseNavRowNoIconSubtitle"),
    ("details: '详情'", "details: l10n.hyperosShowcaseNavRowDetails"),
    ("_section('列表行 · 开关 / 危险')", "_section(l10n.hyperosShowcaseSectionSwitchRows)"),
    ("subtitle: '带图标开关行'", "subtitle: l10n.hyperosShowcaseSwitchRowSubtitle"),
    ("title: '纯文字开关行'", "title: l10n.hyperosShowcaseSwitchRowPlain"),
    ("_section('列表行 · 单选 / 选择 / 日期')", "_section(l10n.hyperosShowcaseSectionChoiceRows)"),
    ("title: '选项 A'", "title: l10n.hyperosShowcaseOptionA"),
    ("title: '选项 B'", "title: l10n.hyperosShowcaseOptionB"),
    ("title: '选项 C'", "title: l10n.hyperosShowcaseOptionC"),
    ("sheetTitle: '选择尺寸'", "sheetTitle: l10n.hyperosShowcaseSelectSizeTitle"),
    ("_section('控件卡片')", "_section(l10n.hyperosShowcaseSectionControls)"),
    ("subtitle: '滑条、分段、按钮'", "subtitle: l10n.hyperosShowcaseControlsSubtitle"),
    ("tabs: const ['左', '右']", "tabs: [l10n.hyperosShowcaseSegmentLeft, l10n.hyperosShowcaseSegmentRight]"),
    ("_section('输入')", "_section(l10n.hyperosShowcaseSectionInput)"),
    ("hint: '请输入内容'", "hint: l10n.hyperosShowcaseInputHint"),
    ("label: '卡片内输入'", "label: l10n.hyperosShowcaseInputCardLabel"),
    ("_section('滚轮选择器')", "_section(l10n.hyperosShowcaseSectionPicker)"),
    ("subtitle: '当前值：$_pickerValue'", "subtitle: l10n.hyperosShowcasePickerCurrentValue(_pickerValue)"),
    ("_section('基础控件 · 行内')", "_section(l10n.hyperosShowcaseSectionInline)"),
    ("subtitle: '多选偏好行'", "subtitle: l10n.hyperosShowcaseCheckboxSubtitle"),
    ("_section('导航与操作')", "_section(l10n.hyperosShowcaseSectionNavActions)"),
    ("label: '带 Tooltip 的按钮'", "label: l10n.hyperosShowcaseTooltipButton"),
    ("_section('进度与刷新')", "_section(l10n.hyperosShowcaseSectionProgress)"),
    ("_section('颜色选择 · ColorChip')", "_section(l10n.hyperosShowcaseSectionColorChip)"),
    ("_section('底部导航 · HyperosNavigationBar')", "_section(l10n.hyperosShowcaseSectionNavBar)"),
    ("label: '首页'", "label: l10n.hyperosShowcaseNavHome"),
    ("label: '课表'", "label: l10n.hyperosShowcaseNavTimetable"),
    ("label: '设置'", "label: l10n.hyperosShowcaseNavSettings"),
    ("_section('空态 / 分割线 / 装饰')", "_section(l10n.hyperosShowcaseSectionEmpty)"),
    ("subtitle: '列表无数据时的占位'", "subtitle: l10n.hyperosShowcaseEmptySubtitle"),
    ("label: '操作按钮'", "label: l10n.hyperosShowcaseActionButton"),
    ("title: '第二行（上方有缩进分割线）'", "title: l10n.hyperosShowcaseDividerRowTitle"),
    ("_section('底层行 · HyperosPressableRow')", "_section(l10n.hyperosShowcaseSectionPressable)"),
    ("_section('页面壳层')", "_section(l10n.hyperosShowcaseSectionShell)"),
    ("details: '无返回键根页'", "details: l10n.hyperosShowcaseRootPageDetails"),
    ("subtitle: '当前页即 Subpage + HyperosListView'", "subtitle: l10n.hyperosShowcaseSubpageSubtitle"),
    ("_demoSnackBar('已在 Subpage 中')", "_demoSnackBar(l10n.hyperosShowcaseAlreadyInSubpage)"),
    ("_section('模糊顶栏 · 滚动物理')", "_section(l10n.hyperosShowcaseSectionFrosted)"),
    ("_section('反馈 · 弹层')", "_section(l10n.hyperosShowcaseSectionFeedback)"),
    ("_section('主题色 · HyperosIconColors')", "_section(l10n.hyperosShowcaseSectionIconColors)"),
    ("text: '此页仅在非 Release 构建设置首页可见，用于组件视觉验收。'", "text: l10n.hyperosShowcaseFooterNote"),
    ("_selectItems", "selectItems"),
]
for a, b in repls:
    s = s.replace(a, b)

# dialog helpers need l10n parameter
s = s.replace(
    "void _demoSnackBar(String message) {",
    "void _demoSnackBar(String message) {\n    final l10n = AppLocalizations.of(context)!;",
)
s = s.replace(
    "actionLabel: '撤销',",
    "actionLabel: l10n.hyperosShowcaseUndoAction,",
)
s = s.replace(
    "Future<void> _demoDialog() async {",
    "Future<void> _demoDialog() async {\n    final l10n = AppLocalizations.of(context)!;",
)
s = s.replace("message: '系统风格对话框示例。'", "message: l10n.hyperosShowcaseDialogMessage")
s = s.replace("label: '取消',", "label: l10n.cancelAction,")
s = s.replace("label: '确定',", "label: l10n.confirmAction,")
s = s.replace(
    "Future<void> _demoConfirm() async {",
    "Future<void> _demoConfirm() async {\n    final l10n = AppLocalizations.of(context)!;",
)
s = s.replace("title: '确认操作'", "title: l10n.hyperosShowcaseConfirmTitle")
s = s.replace("cancelLabel: '取消'", "cancelLabel: l10n.cancelAction")
s = s.replace("confirmLabel: '确认'", "confirmLabel: l10n.confirmAction")
s = s.replace("_demoSnackBar('已确认')", "_demoSnackBar(l10n.hyperosShowcaseConfirmed)")
s = s.replace(
    "Future<void> _demoToast() async {",
    "Future<void> _demoToast() async {\n    final l10n = AppLocalizations.of(context)!;",
)
s = s.replace(
    "description: '带图标与副标题，App Toast 同款'",
    "description: l10n.hyperosShowcaseToastDescription",
)
s = s.replace("label: '关闭'", "label: l10n.closeAction")
s = s.replace("label: '复制'", "label: l10n.hyperosShowcaseMenuCopy")
s = s.replace("label: '分享'", "label: l10n.hyperosShowcaseMenuShare")
s = s.replace("label: '删除'", "label: l10n.hyperosShowcaseMenuDelete")
s = s.replace("_demoSnackBar('刷新完成')", "_demoSnackBar(l10n.hyperosShowcaseRefreshDone)")
s = s.replace("tooltip: '搜索'", "tooltip: l10n.hyperosShowcaseSearchTooltip")
s = s.replace(
    "const HyperosSectionLabel(text: '根页壳层')",
    "HyperosSectionLabel(text: l10n.hyperosShowcaseRootShellLabel)",
)
s = s.replace(
    "subtitle: '通过 HyperosNavigation.push 进入'",
    "subtitle: l10n.hyperosShowcasePushSubtitle",
)

p.write_text(s, encoding='utf-8')
print('updated')
