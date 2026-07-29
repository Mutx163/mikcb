part of '../timetable_settings_screen.dart';

/// 通用设置：语言、转场速度、触感反馈、首页下拉快速导入。
///
/// 这四项原本挤在「外观与主题」里，但没有一项是外观：语言是国际化，转场与
/// 触感是交互反馈，下拉快速导入是一个手势功能开关。放在这里，外观页才能真的
/// 只谈「长什么样」。
class _GeneralSettingsScreen extends StatefulWidget {
  const _GeneralSettingsScreen();

  @override
  State<_GeneralSettingsScreen> createState() => _GeneralSettingsScreenState();
}

class _GeneralSettingsScreenState extends State<_GeneralSettingsScreen> {
  late final TimetableProvider _timetableProvider;
  late TimetableSettings _draft;
  Timer? _autoSaveTimer;
  Future<void> _saveQueue = Future<void>.value();

  @override
  void initState() {
    super.initState();
    _timetableProvider = context.read<TimetableProvider>();
    _draft = _timetableProvider.settings;
  }

  @override
  void dispose() {
    // 滑块 debounce 未到期时若直接返回，只 cancel 会丢最后一档草稿。
    if (_autoSaveTimer?.isActive ?? false) {
      _autoSaveTimer?.cancel();
      _enqueuePersist(_draft);
    } else {
      _autoSaveTimer?.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return HyperosSubpage(
      onBack: () => Navigator.pop(context),
      title: Text(l10n.generalSettingsTitle),
      child: HyperosListView(
        pageStorageKey: const PageStorageKey<String>('settings-general'),
        children: [
          HyperosListGroup(
            children: [
              HyperosSelectTile<String>(
                label: l10n.languageModeLabel,
                subtitle: l10n.languageSectionSubtitle,
                items: buildLocaleMenuMap(context),
                value: normalizeLocaleTagForDropdown(_draft.appLocaleTag),
                onChanged: (value) {
                  _updateDraft(_draft.copyWith(appLocaleTag: value));
                },
              ),
              HyperosSliderTile(
                title: l10n.pageTransitionSpeedTitle,
                value: _draft.pageTransitionSpeed,
                min: TimetableSettings.minPageTransitionSpeed,
                max: TimetableSettings.maxPageTransitionSpeed,
                divisions: 20,
                valueLabel: '${_draft.pageTransitionSpeed.toStringAsFixed(1)}×',
                onChanged: (value) {
                  HyperosNavigation.applyUserTransitionSpeed(context, value);
                  _updateDraft(
                    _draft.copyWith(pageTransitionSpeed: value),
                    debounce: true,
                  );
                },
              ),
              HyperosSwitchTile(
                title: l10n.layoutEnableHapticsTitle,
                subtitle: l10n.layoutEnableHapticsSubtitle,
                value: _draft.enableHaptics,
                onChanged: (value) {
                  _updateDraft(_draft.copyWith(enableHaptics: value));
                },
              ),
              HyperosSwitchTile(
                title: l10n.homePullQuickImportTitle,
                subtitle: l10n.homePullQuickImportSubtitle,
                value: _draft.homePullQuickImportEnabled,
                onChanged: (value) {
                  _updateDraft(
                    _draft.copyWith(homePullQuickImportEnabled: value),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _updateDraft(TimetableSettings next, {bool debounce = false}) {
    setState(() {
      _draft = next;
    });
    _autoSaveTimer?.cancel();
    if (debounce) {
      _autoSaveTimer = Timer(
        const Duration(milliseconds: 250),
        () => _enqueuePersist(next),
      );
      return;
    }
    _enqueuePersist(next);
  }

  void _enqueuePersist(TimetableSettings next) {
    _saveQueue = _saveQueue.catchError((_) {}).then((_) => _persistDraft(next));
  }

  Future<void> _persistDraft(TimetableSettings next) async {
    final provider = _timetableProvider;
    final message = await provider.updateTimetableSettings(
      next.copyWith(
        activeTimeSchemeId: provider.settings.activeTimeSchemeId,
        sections: List<SectionTime>.from(provider.settings.sections),
      ),
    );
    if (!mounted) {
      return;
    }
    if (message != null) {
      showAppToast(context, message: message);
      setState(() {
        _draft = provider.settings;
      });
      return;
    }
  }
}
