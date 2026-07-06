import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../ui/hyperos/hyperos.dart';
import '../utils/hex_color.dart';

/// Gallery of all HyperOS / 澎湃 UI components for visual QA.
class HyperosShowcaseScreen extends StatefulWidget {
  const HyperosShowcaseScreen({super.key});

  @override
  State<HyperosShowcaseScreen> createState() => _HyperosShowcaseScreenState();
}

class _HyperosShowcaseScreenState extends State<HyperosShowcaseScreen> {
  bool _switchOn = true;
  bool _checkboxOn = false;
  String _radioValue = 'a';
  int _choiceIndex = 0;
  String? _selectValue = 'medium';
  DateTime? _pickedDate = DateTime(2026, 3, 1);
  double _sliderValue = 0.6;
  int _tabIndex = 0;
  int _segmentIndex = 0;
  int _pickerValue = 12;
  bool _buttonLoading = false;
  int _navBarIndex = 0;
  Color _selectedChipColor = HyperosIconColors.blue;
  Color _singleChipColor = HyperosIconColors.green;
  String _selectedHexColor = '#3482FF';
  final _popupAnchorKey = GlobalKey();
  final _selectPopupAnchorKey = GlobalKey();
  final _textController = TextEditingController(text: '示例文本');
  final _searchController = TextEditingController();

  static const _selectItems = <String, String>{
    '小': 'small',
    '中': 'medium',
    '大': 'large',
  };

  static const _chipColors = <Color>[
    HyperosIconColors.blue,
    HyperosIconColors.green,
    HyperosIconColors.orange,
    HyperosIconColors.purple,
    HyperosIconColors.red,
  ];

  static const _hexColors = <String>[
    '#3482FF',
    '#34C759',
    '#FF9500',
    '#AF52DE',
    '#FF3B30',
  ];

  @override
  void dispose() {
    _textController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return HyperosSubpage(
      onBack: () => Navigator.pop(context),
      title: const Text('澎湃 UI 组件库'),
      child: HyperosListView(
        children: [
          _section('概要卡片'),
          HyperosSummaryCard(
            leading: Container(
              width: HyperosSummaryCard.leadingSize,
              height: HyperosSummaryCard.leadingSize,
              decoration: BoxDecoration(
                color: HyperosIconColors.blue,
                borderRadius: BorderRadius.circular(
                  HyperosSummaryCard.leadingRadius,
                ),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.widgets_outlined, color: Colors.white),
            ),
            title: 'HyperOS UI Kit',
            subtitle: 'mikcb 澎湃风格组件一览',
          ),
          const HyperosSectionGap(),

          _section('标签 / 手风琴 / 提示'),
          HyperosCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: const [
                  HyperosTag(label: 'HyperosTag'),
                  HyperosTag(label: 'Outlined', outlined: true),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          const HyperosHintBanner(
            icon: Icon(Icons.info_outline, size: 18),
            title: Text('HyperosHintBanner · 信息提示横幅'),
          ),
          const SizedBox(height: 8),
          HyperosControlCard(
            title: 'HyperosAccordion',
            child: HyperosAccordion(
              items: [
                HyperosAccordionItem(
                  title: Text(
                    '第一节',
                    style: HyperosTypography.listTitle(context),
                  ),
                  child: Text(
                    '展开后显示的内容区域。',
                    style: HyperosTypography.listDetail(context),
                  ),
                ),
                HyperosAccordionItem(
                  title: Text(
                    '第二节',
                    style: HyperosTypography.listTitle(context),
                  ),
                  child: Text(
                    '可折叠分组，替代 FAccordion。',
                    style: HyperosTypography.listDetail(context),
                  ),
                ),
              ],
            ),
          ),
          const HyperosSectionGap(),

          _section('列表行 · 导航'),
          HyperosListGroup(
            children: [
              HyperosListTile(
                icon: Icons.palette_outlined,
                iconAccent: HyperosIconColors.blue,
                title: 'HyperosListTile',
                details: '带图标',
                onTap: () {},
              ),
              HyperosNavTile(
                title: 'HyperosNavTile',
                subtitle: '无左侧彩图标',
                details: '详情',
                onTap: () {},
              ),
              HyperosActionTile(
                icon: Icons.upload_outlined,
                title: 'HyperosActionTile',
                onTap: () {},
              ),
            ],
          ),
          const HyperosSectionGap(),

          _section('列表行 · 开关 / 危险'),
          HyperosSwitchListGroup(
            children: [
              HyperosSwitchTile(
                icon: Icons.dark_mode_outlined,
                iconAccent: HyperosIconColors.purple,
                title: 'HyperosSwitchTile',
                subtitle: '带图标开关行',
                value: _switchOn,
                onChanged: (v) => setState(() => _switchOn = v),
              ),
              HyperosSwitchTile(
                title: '纯文字开关行',
                value: !_switchOn,
                onChanged: (v) => setState(() => _switchOn = !v),
              ),
            ],
          ),
          const HyperosSectionGap(),
          HyperosListGroup(
            children: [
              HyperosDangerTile(title: 'HyperosDangerTile', onTap: () {}),
            ],
          ),
          const HyperosSectionGap(),

          _section('列表行 · 单选 / 选择 / 日期'),
          HyperosChoiceGroup(
            children: [
              HyperosChoiceTile(
                title: '选项 A',
                prefix: const HyperosColorDot(color: HyperosIconColors.blue),
                selected: _choiceIndex == 0,
                highlightSelectedText: true,
                onTap: () => setState(() => _choiceIndex = 0),
              ),
              HyperosChoiceTile(
                title: '选项 B',
                prefix: const HyperosColorDot(color: HyperosIconColors.green),
                selected: _choiceIndex == 1,
                highlightSelectedText: true,
                showDivider: true,
                onTap: () => setState(() => _choiceIndex = 1),
              ),
              HyperosChoiceTile(
                title: '选项 C',
                prefix: const HyperosColorDot(color: HyperosIconColors.orange),
                selected: _choiceIndex == 2,
                highlightSelectedText: true,
                onTap: () => setState(() => _choiceIndex = 2),
              ),
            ],
          ),
          const HyperosSectionGap(),
          HyperosListGroup(
            children: [
              HyperosSelectTile<String>(
                label: 'HyperosSelectTile',
                items: _selectItems,
                value: _selectValue,
                sheetTitle: '选择尺寸',
                onChanged: (v) => setState(() => _selectValue = v),
              ),
              HyperosDateTile(
                label: 'HyperosDateTile',
                value: _pickedDate,
                onChanged: (d) => setState(() => _pickedDate = d),
              ),
            ],
          ),
          const HyperosSectionGap(),

          _section('控件卡片'),
          HyperosControlCard(
            title: 'HyperosControlCard',
            subtitle: '滑条、分段、按钮',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                HyperosSliderTile(
                  title: 'HyperosSliderTile',
                  value: _sliderValue,
                  valueLabel: '${(_sliderValue * 100).round()}%',
                  onChanged: (v) => setState(() => _sliderValue = v),
                ),
                const SizedBox(height: 12),
                HyperosSlider(
                  value: _sliderValue,
                  onChanged: (v) => setState(() => _sliderValue = v),
                ),
                const SizedBox(height: 16),
                HyperosTabRow(
                  tabs: const ['Tab A', 'Tab B', 'Tab C'],
                  selectedIndex: _tabIndex,
                  onChanged: (i) => setState(() => _tabIndex = i),
                ),
                const SizedBox(height: 8),
                HyperosTabRow(
                  tabs: const ['左', '右'],
                  selectedIndex: _tabIndex.isEven ? 0 : 1,
                  onChanged: (i) => setState(() => _tabIndex = i),
                  style: HyperosTabRowStyle.bordered,
                ),
                const SizedBox(height: 8),
                HyperosSegmentedControl(
                  tabs: const ['Seg A', 'Seg B'],
                  selectedIndex: _segmentIndex,
                  onChanged: (i) => setState(() => _segmentIndex = i),
                  style: HyperosTabRowStyle.bordered,
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    HyperosButton(
                      label: 'Primary',
                      onPressed: () => _demoSnackBar('Primary tapped'),
                    ),
                    HyperosButton(
                      label: 'Secondary',
                      variant: HyperosButtonVariant.secondary,
                      onPressed: () {},
                    ),
                    HyperosButton(
                      label: 'Destructive',
                      variant: HyperosButtonVariant.destructive,
                      onPressed: () {},
                    ),
                    HyperosButton(
                      label: 'Loading',
                      loading: _buttonLoading,
                      onPressed: _toggleButtonLoading,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                HyperosButton(
                  label: 'HyperosButton · expand',
                  expand: true,
                  onPressed: () {},
                ),
              ],
            ),
          ),
          const HyperosSectionGap(),

          _section('输入'),
          HyperosCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: HyperosTextField(
                controller: _textController,
                label: 'HyperosTextField',
                hint: '请输入内容',
              ),
            ),
          ),
          const HyperosSectionGap(),
          HyperosListGroup(
            children: [
              HyperosTextFieldTile(
                cardTitle: 'HyperosTextFieldTile',
                field: HyperosTextField(
                  controller: _textController,
                  label: '卡片内输入',
                  hint: '请输入内容',
                ),
              ),
            ],
          ),
          const HyperosSectionGap(),
          HyperosCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: HyperosSearchBar(
                controller: _searchController,
                hint: 'HyperosSearchBar',
                onClear: () => _searchController.clear(),
              ),
            ),
          ),
          const HyperosSectionGap(),

          _section('滚轮选择器'),
          HyperosControlCard(
            title: 'HyperosNumberPicker',
            child: HyperosNumberPickerTile(
              title: 'HyperosNumberPickerTile',
              subtitle: '当前值：$_pickerValue',
              picker: HyperosNumberPicker(
                min: 1,
                max: 20,
                value: _pickerValue,
                onChanged: (v) => setState(() => _pickerValue = v),
              ),
            ),
          ),
          const HyperosSectionGap(),

          _section('基础控件 · 行内'),
          HyperosCard(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  HyperosCheckbox(
                    value: _checkboxOn,
                    onChanged: (v) => setState(() => _checkboxOn = v),
                  ),
                  const SizedBox(width: 16),
                  HyperosRadio<String>(
                    value: 'a',
                    groupValue: _radioValue,
                    onChanged: (v) => setState(() => _radioValue = v!),
                  ),
                  const SizedBox(width: 8),
                  const Text('Radio A'),
                  const SizedBox(width: 16),
                  HyperosRadio<String>(
                    value: 'b',
                    groupValue: _radioValue,
                    onChanged: (v) => setState(() => _radioValue = v!),
                  ),
                  const SizedBox(width: 8),
                  const Text('Radio B'),
                  const Spacer(),
                  HyperosSwitch(
                    value: _switchOn,
                    onChanged: (v) => setState(() => _switchOn = v),
                  ),
                ],
              ),
            ),
          ),
          const HyperosSectionGap(),
          HyperosListGroup(
            children: [
              HyperosCheckboxTile(
                title: 'HyperosCheckboxTile',
                subtitle: '多选偏好行',
                value: _checkboxOn,
                onChanged: (v) => setState(() => _checkboxOn = v),
              ),
              HyperosRadioTile<String>(
                title: 'HyperosRadioTile · A',
                value: 'a',
                groupValue: _radioValue,
                onChanged: (v) => setState(() => _radioValue = v!),
              ),
              HyperosRadioTile<String>(
                title: 'HyperosRadioTile · B',
                value: 'b',
                groupValue: _radioValue,
                onChanged: (v) => setState(() => _radioValue = v!),
              ),
            ],
          ),
          const HyperosSectionGap(),

          _section('导航与操作'),
          HyperosControlCard(
            title: 'IconButton / Fab / Badge / Tooltip',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    HyperosIconButton(
                      icon: Icons.edit_outlined,
                      tooltip: 'HyperosIconButton',
                      onPressed: () {},
                    ),
                    HyperosIconButton(icon: Icons.more_vert, onPressed: null),
                    HyperosFab(
                      mini: true,
                      icon: Icons.add,
                      tooltip: 'HyperosFab mini',
                      onPressed: () {},
                    ),
                    HyperosFab(
                      icon: Icons.add,
                      tooltip: 'HyperosFab',
                      onPressed: () {},
                    ),
                    HyperosBadge(
                      child: HyperosIconButton(
                        icon: Icons.notifications_outlined,
                        onPressed: () {},
                      ),
                    ),
                    HyperosBadge(
                      label: '9',
                      child: HyperosIconButton(
                        icon: Icons.mail_outline,
                        onPressed: () {},
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                HyperosTooltip(
                  message: 'HyperosTooltip · 长按查看',
                  child: HyperosButton(
                    label: '带 Tooltip 的按钮',
                    onPressed: () {},
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: HyperosFloatingToolbar(
                    children: [
                      HyperosIconButton(
                        icon: Icons.content_copy_outlined,
                        onPressed: () {},
                      ),
                      HyperosIconButton(
                        icon: Icons.share_outlined,
                        onPressed: () {},
                      ),
                      HyperosIconButton(
                        icon: Icons.delete_outline,
                        onPressed: () {},
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const HyperosSectionGap(),

          _section('进度与刷新'),
          HyperosControlCard(
            title: 'HyperosCircularProgress / HyperosLinearProgress',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Row(
                  children: [
                    HyperosCircularProgress(),
                    SizedBox(width: 12),
                    HyperosCircularProgress(size: 32, strokeWidth: 3),
                  ],
                ),
                const SizedBox(height: 16),
                const HyperosLinearProgress(),
                const SizedBox(height: 8),
                HyperosLinearProgress(value: _sliderValue),
              ],
            ),
          ),
          const HyperosSectionGap(),
          HyperosCard(
            child: SizedBox(
              height: 120,
              child: HyperosRefreshIndicator(
                onRefresh: _demoRefresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    const SizedBox(height: 48),
                    Text(
                      'HyperosRefreshIndicator · 下拉刷新',
                      textAlign: TextAlign.center,
                      style: HyperosTypography.listDetail(context),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const HyperosSectionGap(),

          _section('颜色选择 · ColorChip'),
          HyperosControlCard(
            title: 'HyperosColorChip',
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final color in _chipColors)
                  HyperosColorChip(
                    color: color,
                    selected: _singleChipColor == color,
                    onTap: () => setState(() => _singleChipColor = color),
                  ),
              ],
            ),
          ),
          const HyperosSectionGap(),
          HyperosControlCard(
            title: 'HyperosColorChipGroup',
            child: HyperosColorChipGroup(
              colors: _chipColors,
              selectedColor: _selectedChipColor,
              onSelected: (c) => setState(() => _selectedChipColor = c),
            ),
          ),
          const HyperosSectionGap(),
          HyperosControlCard(
            title: 'HyperosHexColorChipGroup',
            child: HyperosHexColorChipGroup(
              colorHexes: _hexColors,
              selectedHex: _selectedHexColor,
              colorParser: (hex) => parseHexColorOrFallback(
                hex,
                fallback: HyperosIconColors.blue,
              ),
              onSelectedHex: (hex) => setState(() => _selectedHexColor = hex),
            ),
          ),
          const HyperosSectionGap(),

          _section('底部导航 · HyperosNavigationBar'),
          HyperosCard(
            child: HyperosNavigationBar(
              selectedIndex: _navBarIndex,
              onDestinationSelected: (i) => setState(() => _navBarIndex = i),
              destinations: const [
                HyperosNavigationDestination(
                  icon: Icons.home_outlined,
                  selectedIcon: Icons.home,
                  label: '首页',
                ),
                HyperosNavigationDestination(
                  icon: Icons.calendar_today_outlined,
                  selectedIcon: Icons.calendar_today,
                  label: '课表',
                ),
                HyperosNavigationDestination(
                  icon: Icons.settings_outlined,
                  selectedIcon: Icons.settings,
                  label: '设置',
                ),
              ],
            ),
          ),
          const HyperosSectionGap(),

          _section('空态 / 分割线 / 装饰'),
          HyperosCard(
            child: HyperosEmptyState(
              title: 'HyperosEmptyState',
              subtitle: '列表无数据时的占位',
              action: HyperosButton(label: '操作按钮', onPressed: () {}),
            ),
          ),
          const SizedBox(height: 8),
          const HyperosDivider(),
          HyperosCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const HyperosIconBadge(
                    icon: Icons.star_outline,
                    accent: HyperosIconColors.yellow,
                  ),
                  const SizedBox(width: 12),
                  const HyperosChevron(),
                  const SizedBox(width: 12),
                  const HyperosUpDownChevron(),
                  const Spacer(),
                  const HyperosSelectedCheckmark(),
                  const SizedBox(width: 12),
                  const HyperosColorDot(color: HyperosIconColors.teal),
                ],
              ),
            ),
          ),
          HyperosCard(
            child: Column(
              children: [
                HyperosActionTile(
                  icon: Icons.folder_outlined,
                  title: 'HyperosInsetDivider 示例',
                  onTap: () {},
                ),
                HyperosInsetDivider(
                  indent: HyperosTokens.actionTileDividerIndent,
                ),
                HyperosActionTile(
                  icon: Icons.folder_open_outlined,
                  title: '第二行（上方有缩进分割线）',
                  onTap: () {},
                ),
              ],
            ),
          ),
          const HyperosSectionGap(),

          _section('底层行 · HyperosPressableRow'),
          HyperosCard(
            child: HyperosPressableRow(
              onTap: () => _demoSnackBar('HyperosPressableRow tapped'),
              child: Padding(
                padding: HyperosTokens.rowPaddingUniform,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'HyperosPressableRow',
                        style: HyperosTypography.listTitle(context),
                      ),
                    ),
                    const HyperosChevron(),
                  ],
                ),
              ),
            ),
          ),
          const HyperosSectionGap(),

          _section('页面壳层'),
          HyperosListGroup(
            children: [
              HyperosListTile(
                icon: Icons.home_outlined,
                iconAccent: HyperosIconColors.blue,
                title: 'HyperosRootPage',
                details: '无返回键根页',
                onTap: _demoRootPage,
              ),
              HyperosNavTile(
                title: 'HyperosSubpage',
                subtitle: '当前页即 Subpage + HyperosListView',
                details: '—',
                onTap: () => _demoSnackBar('已在 Subpage 中'),
              ),
            ],
          ),
          const HyperosSectionGap(),

          _section('模糊顶栏 · 滚动物理'),
          HyperosCard(
            child: ClipRRect(
              borderRadius: HyperosTheme.cardBorderRadius,
              child: SizedBox(
                height: 148,
                child: HyperosBlurredHeaderScope(
                  contentTopInset: 48,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Container(color: HyperosIconColors.blue),
                          ),
                          Expanded(
                            child: Container(color: HyperosIconColors.orange),
                          ),
                          Expanded(
                            child: Container(color: HyperosIconColors.purple),
                          ),
                        ],
                      ),
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        height: 48,
                        child: HyperosBlurredHeaderShell(
                          child: Center(
                            child: Text(
                              'HyperosBlurredHeaderShell',
                              style: HyperosTypography.listTitle(context),
                            ),
                          ),
                        ),
                      ),
                      HyperosBlurredBodyInset(
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(
                              'HyperosBlurredBodyInset',
                              style: HyperosTypography.listDetail(context),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          HyperosCard(
            child: SizedBox(
              height: 96,
              child: ListView(
                physics: const HyperosOverscrollPhysics(),
                children: [
                  const SizedBox(height: 36),
                  Text(
                    'HyperosOverscrollPhysics · 拖到顶/底体验橡皮筋',
                    textAlign: TextAlign.center,
                    style: HyperosTypography.listDetail(context),
                  ),
                ],
              ),
            ),
          ),
          const HyperosSectionGap(),

          _section('反馈 · 弹层'),
          HyperosListGroup(
            children: [
              HyperosListTile(
                icon: Icons.chat_bubble_outline,
                iconAccent: HyperosIconColors.cyan,
                title: 'showHyperosSnackBar',
                onTap: () => _demoSnackBar('SnackBar 示例消息'),
              ),
              HyperosListTile(
                icon: Icons.notifications_active_outlined,
                iconAccent: HyperosIconColors.blue,
                title: 'showHyperosRichSnackBar',
                onTap: _demoRichSnackBar,
              ),
              HyperosListTile(
                icon: Icons.sms_outlined,
                iconAccent: HyperosIconColors.indigo,
                title: 'HyperosSnackBar',
                details: 'SnackBar 子类',
                onTap: _demoSnackBarWidget,
              ),
              HyperosListTile(
                icon: Icons.info_outline,
                iconAccent: HyperosIconColors.indigo,
                title: 'showHyperosDialog',
                onTap: _demoDialog,
              ),
              HyperosListTile(
                icon: Icons.check_circle_outline,
                iconAccent: HyperosIconColors.green,
                title: 'showHyperosConfirmDialog',
                onTap: _demoConfirmDialog,
              ),
              HyperosListTile(
                icon: Icons.view_agenda_outlined,
                iconAccent: HyperosIconColors.orange,
                title: 'showHyperosSelectSheet',
                details: 'HyperosSheet + ChoiceGroup',
                onTap: _demoSelectSheet,
              ),
              HyperosListTile(
                icon: Icons.call_to_action_outlined,
                iconAccent: HyperosIconColors.purple,
                title: 'showHyperosSheet',
                details: 'HyperosSheetFrame',
                onTap: _demoGenericSheet,
              ),
              HyperosListTile(
                key: _selectPopupAnchorKey,
                icon: Icons.arrow_drop_down_circle_outlined,
                iconAccent: HyperosIconColors.teal,
                title: 'showHyperosSelectPopup',
                details: _selectValue == null
                    ? null
                    : _selectItems.entries
                          .firstWhere((e) => e.value == _selectValue)
                          .key,
                onTap: _demoSelectPopup,
              ),
              HyperosListTile(
                key: _popupAnchorKey,
                icon: Icons.more_horiz,
                iconAccent: HyperosIconColors.yellow,
                title: 'showHyperosListPopup',
                onTap: _demoListPopup,
              ),
            ],
          ),
          const HyperosSectionGap(),

          _section('主题色 · HyperosIconColors'),
          HyperosCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final entry in _iconColorSwatches)
                    _ColorSwatch(label: entry.$1, color: entry.$2),
                ],
              ),
            ),
          ),
          if (!kReleaseMode) ...[
            const HyperosSectionGap(),
            const HyperosSectionDescription(
              text: '此页仅在非 Release 构建设置首页可见，用于组件视觉验收。',
            ),
          ],
          const HyperosSectionGap(),
        ],
      ),
    );
  }

  Widget _section(String label) => HyperosSectionLabel(text: label);

  void _demoSnackBar(String message) {
    showHyperosSnackBar(
      context,
      message: message,
      actionLabel: '撤销',
      onAction: () {},
    );
  }

  Future<void> _demoDialog() async {
    await showHyperosDialog<void>(
      context: context,
      title: 'HyperosDialog',
      message: '系统风格对话框示例。',
      actions: [
        HyperosDialogAction(
          label: '取消',
          onPressed: () => Navigator.pop(context),
        ),
        HyperosDialogAction(
          label: '确定',
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }

  Future<void> _demoConfirmDialog() async {
    final ok = await showHyperosConfirmDialog(
      context: context,
      title: '确认操作',
      message: 'HyperosConfirmDialog 返回 bool?',
      cancelLabel: '取消',
      confirmLabel: '确认',
    );
    if (!mounted || ok != true) return;
    _demoSnackBar('已确认');
  }

  void _demoRichSnackBar() {
    showHyperosRichSnackBar(
      context,
      message: 'showHyperosRichSnackBar',
      description: '带图标与副标题，App Toast 同款',
      icon: Icons.check_circle_outline,
      iconColor: HyperosIconColors.green,
      actionLabel: '撤销',
      onAction: () {},
    );
  }

  void _demoSnackBarWidget() {
    ScaffoldMessenger.of(context).showSnackBar(
      HyperosSnackBar(context: context, message: 'HyperosSnackBar widget 类'),
    );
  }

  void _demoRootPage() {
    HyperosNavigation.push(
      context,
      builder: (_) => const _HyperosRootPageDemo(),
    );
  }

  Future<void> _demoSelectSheet() async {
    final picked = await showHyperosSelectSheet<String>(
      context: context,
      title: 'showHyperosSelectSheet',
      description: 'HyperosSheet + HyperosChoiceGroup',
      items: _selectItems,
      currentValue: _selectValue,
    );
    if (!mounted || picked == null) return;
    setState(() => _selectValue = picked);
  }

  Future<void> _demoGenericSheet() async {
    await showHyperosSheet<void>(
      context: context,
      builder: (sheetContext) => HyperosSheet(
        title: 'showHyperosSheet',
        description: 'HyperosSheetFrame 灰底圆角容器',
        child: HyperosButton(
          label: '关闭',
          expand: true,
          onPressed: () => Navigator.pop(sheetContext),
        ),
      ),
    );
  }

  Future<void> _demoSelectPopup() async {
    final picked = await showHyperosSelectPopup<String>(
      context: context,
      anchorRect: hyperosSelectPopupAnchorRect(context, _selectPopupAnchorKey),
      items: _selectItems,
      currentValue: _selectValue,
    );
    if (!mounted || picked == null) return;
    setState(() => _selectValue = picked);
  }

  Future<void> _demoListPopup() async {
    final picked = await showHyperosListPopup<String>(
      context: context,
      position: hyperosPopupPositionBelow(context, _popupAnchorKey),
      items: const [
        HyperosPopupMenuItem(label: '复制', value: 'copy'),
        HyperosPopupMenuItem(label: '分享', value: 'share'),
        HyperosPopupMenuItem(label: '删除', value: 'delete', destructive: true),
      ],
    );
    if (!mounted || picked == null) return;
    _demoSnackBar('ListPopup: $picked');
  }

  Future<void> _demoRefresh() async {
    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    _demoSnackBar('刷新完成');
  }

  Future<void> _toggleButtonLoading() async {
    setState(() => _buttonLoading = true);
    await Future<void>.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    setState(() => _buttonLoading = false);
  }
}

/// Demo page for [HyperosRootPage] + [HyperosPageRoute] via [HyperosNavigation].
class _HyperosRootPageDemo extends StatelessWidget {
  const _HyperosRootPageDemo();

  @override
  Widget build(BuildContext context) {
    return HyperosRootPage(
      title: const Text('HyperosRootPage'),
      suffixes: [
        HyperosIconButton(icon: Icons.search, tooltip: '搜索', onPressed: () {}),
      ],
      child: HyperosListView(
        children: [
          const HyperosSectionLabel(text: '根页壳层'),
          HyperosListGroup(
            children: [
              HyperosNavTile(
                title: 'HyperosPageRoute',
                subtitle: '通过 HyperosNavigation.push 进入',
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
          const HyperosSectionGap(),
        ],
      ),
    );
  }
}

const _iconColorSwatches = <(String, Color)>[
  ('blue', HyperosIconColors.blue),
  ('green', HyperosIconColors.green),
  ('orange', HyperosIconColors.orange),
  ('purple', HyperosIconColors.purple),
  ('teal', HyperosIconColors.teal),
  ('red', HyperosIconColors.red),
  ('yellow', HyperosIconColors.yellow),
  ('indigo', HyperosIconColors.indigo),
  ('cyan', HyperosIconColors.cyan),
];

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        HyperosIconBadge(icon: Icons.circle, accent: color),
        const SizedBox(height: 4),
        Text(label, style: HyperosTypography.listDetail(context)),
      ],
    );
  }
}
