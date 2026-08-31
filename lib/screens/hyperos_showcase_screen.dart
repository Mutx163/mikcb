import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:university_timetable/l10n/app_localizations.dart';

import '../models/timetable_settings.dart';
import '../providers/timetable_provider.dart';
import '../services/app_update_service.dart';
import '../ui/hyperos/hyperos.dart';
import '../utils/hex_color.dart';
import '../widgets/home_update_prompt.dart';

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
  DateTime? _pickedDate = DateTime(2026, 3);
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
  final _textController = TextEditingController();
  final _searchController = TextEditingController();
  Timer? _demoUpdateProgressTimer;

  Map<String, String> _selectItemMap(AppLocalizations l10n) => {
    l10n.hyperosShowcaseSizeSmall: 'small',
    l10n.hyperosShowcaseSizeMedium: 'medium',
    l10n.hyperosShowcaseSizeLarge: 'large',
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
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _textController.text = AppLocalizations.of(
        context,
      )!.hyperosShowcaseSampleText;
    });
  }

  @override
  void dispose() {
    _demoUpdateProgressTimer?.cancel();
    _textController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final selectItems = _selectItemMap(l10n);
    return HyperosSubpage(
      onBack: () => Navigator.pop(context),
      title: Text(l10n.hyperosShowcaseTitle),
      child: HyperosListView(
        children: [
          _section(l10n.hyperosShowcaseSectionSummary),
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
            subtitle: l10n.hyperosShowcaseKitSubtitle,
          ),
          const HyperosSectionGap(),

          _section(l10n.hyperosShowcaseSectionTags),
          const HyperosCard(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
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
            child: HyperosControlCardInset(
              child: HyperosAccordion(
                items: [
                  HyperosAccordionItem(
                    title: Text(
                      l10n.hyperosShowcaseAccordionSection1,
                      style: HyperosTypography.listTitle(context),
                    ),
                    child: Text(
                      l10n.hyperosShowcaseAccordionSection1Body,
                      style: HyperosTypography.listDetail(context),
                    ),
                  ),
                  HyperosAccordionItem(
                    title: Text(
                      l10n.hyperosShowcaseAccordionSection2,
                      style: HyperosTypography.listTitle(context),
                    ),
                    child: Text(
                      l10n.hyperosShowcaseAccordionSection2Body,
                      style: HyperosTypography.listDetail(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const HyperosSectionGap(),

          _section(l10n.hyperosShowcaseSectionNavRows),
          HyperosListGroup(
            children: [
              HyperosListTile(
                icon: Icons.palette_outlined,
                iconAccent: HyperosIconColors.blue,
                title: 'HyperosListTile',
                details: l10n.hyperosShowcaseNavRowWithIcon,
                onTap: () {},
              ),
              HyperosNavTile(
                title: 'HyperosNavTile',
                subtitle: l10n.hyperosShowcaseNavRowNoIconSubtitle,
                details: l10n.hyperosShowcaseNavRowDetails,
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

          _section(l10n.hyperosShowcaseSectionSwitchRows),
          HyperosSwitchListGroup(
            children: [
              HyperosSwitchTile(
                icon: Icons.dark_mode_outlined,
                iconAccent: HyperosIconColors.purple,
                title: 'HyperosSwitchTile',
                subtitle: l10n.hyperosShowcaseSwitchRowSubtitle,
                value: _switchOn,
                onChanged: (v) => setState(() => _switchOn = v),
              ),
              HyperosSwitchTile(
                title: l10n.hyperosShowcaseSwitchRowPlain,
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

          _section(l10n.hyperosShowcaseSectionChoiceRows),
          HyperosChoiceGroup(
            children: [
              HyperosChoiceTile(
                title: l10n.hyperosShowcaseOptionA,
                prefix: const HyperosColorDot(color: HyperosIconColors.blue),
                selected: _choiceIndex == 0,
                highlightSelectedText: true,
                onTap: () => setState(() => _choiceIndex = 0),
              ),
              HyperosChoiceTile(
                title: l10n.hyperosShowcaseOptionB,
                prefix: const HyperosColorDot(color: HyperosIconColors.green),
                selected: _choiceIndex == 1,
                highlightSelectedText: true,
                showDivider: true,
                onTap: () => setState(() => _choiceIndex = 1),
              ),
              HyperosChoiceTile(
                title: l10n.hyperosShowcaseOptionC,
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
                items: selectItems,
                value: _selectValue,
                sheetTitle: l10n.hyperosShowcaseSelectSizeTitle,
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

          _section(l10n.hyperosShowcaseSectionControls),
          HyperosControlCard(
            title: 'HyperosControlCard',
            subtitle: l10n.hyperosShowcaseControlsSubtitle,
            edgeToEdge: true,
            child: HyperosControlCardRows(
              children: [
                HyperosSliderTile(
                  title: 'HyperosSliderTile',
                  value: _sliderValue,
                  valueLabel: '${(_sliderValue * 100).round()}%',
                  onChanged: (v) => setState(() => _sliderValue = v),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    HyperosControlCardScope.defaultHorizontalPadding,
                    0,
                    HyperosControlCardScope.defaultHorizontalPadding,
                    12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
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
                        tabs: [
                          l10n.hyperosShowcaseSegmentLeft,
                          l10n.hyperosShowcaseSegmentRight,
                        ],
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
              ],
            ),
          ),
          const HyperosSectionGap(),

          _section(l10n.hyperosShowcaseSectionInput),
          HyperosCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: HyperosTextField(
                controller: _textController,
                label: 'HyperosTextField',
                hint: l10n.hyperosShowcaseInputHint,
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
                  label: l10n.hyperosShowcaseInputCardLabel,
                  hint: l10n.hyperosShowcaseInputHint,
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
                onClear: _searchController.clear,
              ),
            ),
          ),
          const HyperosSectionGap(),

          _section(l10n.hyperosShowcaseSectionPicker),
          HyperosControlCard(
            title: 'HyperosNumberPicker',
            child: HyperosNumberPickerTile(
              title: 'HyperosNumberPickerTile',
              subtitle: l10n.hyperosShowcasePickerCurrentValue(_pickerValue),
              picker: HyperosNumberPicker(
                min: 1,
                max: 20,
                value: _pickerValue,
                onChanged: (v) => setState(() => _pickerValue = v),
              ),
            ),
          ),
          const HyperosSectionGap(),

          _section(l10n.hyperosShowcaseSectionInline),
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
                subtitle: l10n.hyperosShowcaseCheckboxSubtitle,
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

          _section(l10n.hyperosShowcaseSectionNavActions),
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
                    const HyperosIconButton(icon: Icons.more_vert),
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
                    label: l10n.hyperosShowcaseTooltipButton,
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

          _section(l10n.hyperosShowcaseSectionProgress),
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

          _section(l10n.hyperosShowcaseSectionColorChip),
          HyperosControlCard(
            title: 'HyperosColorChip',
            child: HyperosControlCardInset(
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
          ),
          const HyperosSectionGap(),
          HyperosControlCard(
            title: 'HyperosColorChipGroup',
            child: HyperosControlCardInset(
              child: HyperosColorChipGroup(
                colors: _chipColors,
                selectedColor: _selectedChipColor,
                onSelected: (c) => setState(() => _selectedChipColor = c),
              ),
            ),
          ),
          const HyperosSectionGap(),
          HyperosControlCard(
            title: 'HyperosHexColorChipGroup',
            child: HyperosControlCardInset(
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
          ),
          const HyperosSectionGap(),

          _section(l10n.hyperosShowcaseSectionNavBar),
          HyperosCard(
            child: HyperosNavigationBar(
              selectedIndex: _navBarIndex,
              onDestinationSelected: (i) => setState(() => _navBarIndex = i),
              destinations: [
                HyperosNavigationDestination(
                  icon: Icons.home_outlined,
                  selectedIcon: Icons.home,
                  label: l10n.hyperosShowcaseNavHome,
                ),
                HyperosNavigationDestination(
                  icon: Icons.calendar_today_outlined,
                  selectedIcon: Icons.calendar_today,
                  label: l10n.hyperosShowcaseNavTimetable,
                ),
                HyperosNavigationDestination(
                  icon: Icons.settings_outlined,
                  selectedIcon: Icons.settings,
                  label: l10n.hyperosShowcaseNavSettings,
                ),
              ],
            ),
          ),
          const HyperosSectionGap(),

          _section(l10n.hyperosShowcaseSectionEmpty),
          HyperosCard(
            child: HyperosEmptyState(
              title: 'HyperosEmptyState',
              subtitle: l10n.hyperosShowcaseEmptySubtitle,
              action: HyperosButton(
                label: l10n.hyperosShowcaseActionButton,
                onPressed: () {},
              ),
            ),
          ),
          const SizedBox(height: 8),
          const HyperosDivider(),
          const HyperosCard(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  HyperosIconBadge(
                    icon: Icons.star_outline,
                    accent: HyperosIconColors.yellow,
                  ),
                  SizedBox(width: 12),
                  HyperosChevron(),
                  SizedBox(width: 12),
                  HyperosUpDownChevron(),
                  Spacer(),
                  HyperosSelectedCheckmark(),
                  SizedBox(width: 12),
                  HyperosColorDot(color: HyperosIconColors.teal),
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
                  title: l10n.hyperosShowcaseDividerRowTitle,
                  onTap: () {},
                ),
              ],
            ),
          ),
          const HyperosSectionGap(),

          _section(l10n.hyperosShowcaseSectionPressable),
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

          _section(l10n.hyperosShowcaseSectionShell),
          HyperosListGroup(
            children: [
              HyperosListTile(
                icon: Icons.home_outlined,
                iconAccent: HyperosIconColors.blue,
                title: 'HyperosRootPage',
                details: l10n.hyperosShowcaseRootPageDetails,
                onTap: _demoRootPage,
              ),
              HyperosNavTile(
                title: 'HyperosSubpage',
                subtitle: l10n.hyperosShowcaseSubpageSubtitle,
                details: '—',
                onTap: () =>
                    _demoSnackBar(l10n.hyperosShowcaseAlreadyInSubpage),
              ),
            ],
          ),
          const HyperosSectionGap(),

          _section(l10n.hyperosShowcaseSectionFrosted),
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

          _section(l10n.hyperosShowcaseSectionFeedback),
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
                details: 'floating · 四边圆角+外边距',
                onTap: _demoGenericSheet,
              ),
              HyperosListTile(
                icon: Icons.vertical_align_bottom_outlined,
                iconAccent: HyperosIconColors.indigo,
                title: 'showHomeHyperosSheet',
                details: 'edge · 贴边仅上圆角',
                onTap: _demoEdgeSheet,
              ),
              if (!kReleaseMode)
                HyperosListTile(
                  icon: Icons.system_update,
                  iconAccent: HyperosIconColors.red,
                  title: '模拟收到新版本更新',
                  details: 'showHomeUpdatePrompt · 假数据',
                  onTap: _demoAppUpdatePrompt,
                ),
              HyperosListTile(
                key: _selectPopupAnchorKey,
                icon: Icons.arrow_drop_down_circle_outlined,
                iconAccent: HyperosIconColors.teal,
                title: 'showHyperosSelectPopup',
                details: _selectValue == null
                    ? null
                    : selectItems.entries
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

          _section(l10n.hyperosShowcaseSectionIconColors),
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
            HyperosSectionDescription(text: l10n.hyperosShowcaseFooterNote),
          ],
          const HyperosSectionGap(),
        ],
      ),
    );
  }

  Widget _section(String label) => HyperosSectionLabel(text: label);

  void _demoSnackBar(String message) {
    final l10n = AppLocalizations.of(context)!;
    showHyperosSnackBar(
      context,
      message: message,
      actionLabel: l10n.hyperosShowcaseUndoAction,
      onAction: () {},
    );
  }

  Future<void> _demoDialog() async {
    final l10n = AppLocalizations.of(context)!;
    await showHyperosDialog<void>(
      context: context,
      title: 'HyperosDialog',
      message: l10n.hyperosShowcaseDialogMessage,
      actions: [
        HyperosDialogAction(
          label: l10n.cancelAction,
          onPressed: () => Navigator.pop(context),
        ),
        HyperosDialogAction(
          label: l10n.confirmAction,
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }

  Future<void> _demoConfirmDialog() async {
    final l10n = AppLocalizations.of(context)!;
    final ok = await showHyperosConfirmDialog(
      context: context,
      title: l10n.hyperosShowcaseConfirmTitle,
      message: 'HyperosConfirmDialog 返回 bool?',
      cancelLabel: l10n.cancelAction,
      confirmLabel: l10n.confirmAction,
    );
    if (!mounted || ok != true) return;
    _demoSnackBar(l10n.hyperosShowcaseConfirmed);
  }

  void _demoRichSnackBar() {
    final l10n = AppLocalizations.of(context)!;
    showHyperosRichSnackBar(
      context,
      message: 'showHyperosRichSnackBar',
      description: l10n.hyperosShowcaseToastDescription,
      icon: Icons.check_circle_outline,
      iconColor: HyperosIconColors.green,
      actionLabel: l10n.hyperosShowcaseUndoAction,
      onAction: () {},
    );
  }

  void _demoSnackBarWidget() {
    showHyperosSnackBar(context, message: 'HyperosToastCapsule / system toast');
  }

  void _demoRootPage() {
    HyperosNavigation.push(
      context,
      builder: (_) => const _HyperosRootPageDemo(),
    );
  }

  Future<void> _demoSelectSheet() async {
    final l10n = AppLocalizations.of(context)!;
    final picked = await showHyperosSelectSheet<String>(
      context: context,
      title: 'showHyperosSelectSheet',
      description: 'HyperosSheet + HyperosChoiceGroup',
      items: _selectItemMap(l10n),
      currentValue: _selectValue,
      cancelLabel: l10n.cancelAction,
    );
    if (!mounted || picked == null) return;
    setState(() => _selectValue = picked);
  }

  Future<void> _demoGenericSheet() async {
    final l10n = AppLocalizations.of(context)!;
    await showHyperosSheet<void>(
      context: context,
      builder: (sheetContext) => HyperosSheet(
        title: 'showHyperosSheet · floating',
        description: '四边圆角 + 外边距（同 Dialog）',
        child: HyperosButton(
          label: l10n.closeAction,
          expand: true,
          onPressed: () => Navigator.pop(sheetContext),
        ),
      ),
    );
  }

  Future<void> _demoEdgeSheet() async {
    final l10n = AppLocalizations.of(context)!;
    await showHomeHyperosSheet<void>(
      context: context,
      builder: (sheetContext) => HyperosSheet(
        title: 'showHomeHyperosSheet · edge',
        description: '贴边、仅上圆角（首页菜单同款）',
        child: HyperosButton(
          label: l10n.closeAction,
          expand: true,
          onPressed: () => Navigator.pop(sheetContext),
        ),
      ),
    );
  }

  /// 模拟「发现新版本」推送：用假 Release 数据拉起首页同款更新弹窗。
  ///
  /// 仅调试/性能版可达本页。主按钮文案与点击行为按当前设置
  /// （下载渠道 / 来源 / 镜像）自适应，与线上分支一致；假下载只推进
  /// 内存进度条，不访问网络、不写磁盘，便于验收各状态。
  Future<void> _demoAppUpdatePrompt() async {
    final settings = context.read<TimetableProvider>().settings;
    String currentVersion;
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      currentVersion = packageInfo.version;
    } on Exception catch (_) {
      // 无插件环境（如纯 Widget 测试）下的兜底，保证弹窗始终能弹出。
      currentVersion = '0.0.0';
    }
    if (!mounted) return;
    const release = AppReleaseInfo(
      version: '9.9.9',
      title: '模拟更新 · 弹窗演示数据',
      body: '这是一条用于验收更新弹窗的模拟更新日志。\n'
          '- 假下载只播放进度动画，不访问网络\n'
          '- 下拉或点击遮罩即可关闭',
      releaseUrl: 'https://github.com/Mutx163/mikcb/releases',
      downloadUrl:
          'https://github.com/Mutx163/mikcb/releases/download/demo/demo.apk',
      pgyerDownloadUrl: 'https://www.pgyer.com/qingyu',
      updatedAt: null,
      isPrerelease: false,
    );
    final channel = AppUpdateDownloadChannelX.fromValue(
      settings.appUpdateDownloadChannel,
    );
    final source = AppUpdateDownloadSourceX.fromValue(
      settings.appUpdateDownloadSource,
    );
    final mirrorPrefix = resolveAppUpdateMirrorUrlPrefix(
      preset: AppUpdateMirrorPresetX.fromValue(settings.appUpdateMirrorPreset),
      customUrlPrefix: settings.appUpdateMirrorUrlPrefix,
    );
    // 与线上首页同一条 URL 解析链路：渠道决定蒲公英/GitHub，
    // 来源与镜像前缀只影响 GitHub 直链。
    final effectiveDownloadUrl = AppUpdateService().getEffectiveDownloadUrl(
      release: release,
      channel: channel,
      source: source,
      mirrorUrlPrefix: mirrorPrefix,
    );
    final hasDirectDownload =
        effectiveDownloadUrl != null && effectiveDownloadUrl.trim().isNotEmpty;
    final controller = HomeUpdatePromptController();
    _demoUpdateProgressTimer?.cancel();
    try {
      await showHomeUpdatePrompt(
        context,
        release: release,
        currentVersion: currentVersion,
        downloadChannel: channel,
        hasDirectDownload: hasDirectDownload,
        controller: controller,
        onDownload: () async {
          // 与线上分支一致：蒲公英渠道或无直链时跳浏览器并关弹窗；
          // 演示里仅以 toast 提示，不真正打开。
          if (channel == AppUpdateDownloadChannel.pgyer || !hasDirectDownload) {
            if (mounted) {
              _demoSnackBar('演示数据：当前配置下会跳转浏览器打开下载页');
            }
            return false;
          }
          return _playFakeDownload(controller);
        },
        onViewRelease: () async {
          if (!mounted) return;
          _demoSnackBar('演示数据：跳过打开 Release 页面');
        },
        onCancelDownload: () {
          _demoUpdateProgressTimer?.cancel();
          _demoUpdateProgressTimer = null;
          controller.finishInAppDownload(success: false, cancelled: true);
        },
        onResumeDownload: () => _playFakeDownload(controller),
      );
    } finally {
      _demoUpdateProgressTimer?.cancel();
      _demoUpdateProgressTimer = null;
      controller.dispose();
    }
  }

  /// 假下载动画：约 6 秒推进到 100%，期间可取消；返回 true 保持弹窗打开。
  Future<bool> _playFakeDownload(HomeUpdatePromptController controller) {
    const totalBytes = 96 * 1024 * 1024;
    const ticks = 60; // 约 6 秒播完（100ms 一帧）。
    const step = totalBytes ~/ ticks;
    var downloaded = 0;
    controller.beginInAppDownload();
    _demoUpdateProgressTimer = Timer.periodic(
      const Duration(milliseconds: 100),
      (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        downloaded += step;
        if (downloaded >= totalBytes) {
          timer.cancel();
          _demoUpdateProgressTimer = null;
          controller.finishInAppDownload(success: true);
          return;
        }
        controller.updateInAppProgress(downloaded, totalBytes);
      },
    );
    return Future<bool>.value(true);
  }

  Future<void> _demoSelectPopup() async {
    final l10n = AppLocalizations.of(context)!;
    final picked = await showHyperosSelectPopup<String>(
      context: context,
      anchorRect: hyperosSelectPopupAnchorRect(context, _selectPopupAnchorKey),
      items: _selectItemMap(l10n),
      currentValue: _selectValue,
    );
    if (!mounted || picked == null) return;
    setState(() => _selectValue = picked);
  }

  Future<void> _demoListPopup() async {
    final l10n = AppLocalizations.of(context)!;
    final picked = await showHyperosListPopup<String>(
      context: context,
      position: hyperosPopupPositionBelow(context, _popupAnchorKey),
      items: [
        HyperosPopupMenuItem(
          label: l10n.hyperosShowcaseMenuCopy,
          value: 'copy',
        ),
        HyperosPopupMenuItem(
          label: l10n.hyperosShowcaseMenuShare,
          value: 'share',
        ),
        HyperosPopupMenuItem(
          label: l10n.hyperosShowcaseMenuDelete,
          value: 'delete',
          destructive: true,
        ),
      ],
    );
    if (!mounted || picked == null) return;
    _demoSnackBar('ListPopup: $picked');
  }

  Future<void> _demoRefresh() async {
    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    _demoSnackBar(AppLocalizations.of(context)!.hyperosShowcaseRefreshDone);
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
    final l10n = AppLocalizations.of(context)!;
    return HyperosRootPage(
      title: const Text('HyperosRootPage'),
      suffixes: [
        HyperosIconButton(
          icon: Icons.search,
          tooltip: l10n.hyperosShowcaseSearchTooltip,
          onPressed: () {},
        ),
      ],
      child: HyperosListView(
        children: [
          HyperosSectionLabel(text: l10n.hyperosShowcaseRootShellLabel),
          HyperosListGroup(
            children: [
              HyperosNavTile(
                title: 'HyperosPageRoute',
                subtitle: l10n.hyperosShowcasePushSubtitle,
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
