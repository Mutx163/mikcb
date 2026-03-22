import 'package:flutter/material.dart';

import '../services/miui_live_activities_service.dart';
import 'course_overview_screen.dart';

class UserGuideScreen extends StatefulWidget {
  const UserGuideScreen({super.key});

  @override
  State<UserGuideScreen> createState() => _UserGuideScreenState();
}

class _UserGuideScreenState extends State<UserGuideScreen> {
  final MiuiLiveActivitiesService _service = MiuiLiveActivitiesService();
  final ScrollController _scrollController = ScrollController();

  bool _isLoading = true;
  bool _hasNotificationPermission = false;
  bool _hasPromotedPermission = false;
  bool _canPostPromoted = false;
  bool _isIgnoringBatteryOptimizations = false;
  bool _isNearBottom = false;
  int _androidVersion = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    _refreshStatus();
    WidgetsBinding.instance.addPostFrameCallback((_) => _handleScroll());
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) {
      return;
    }
    final position = _scrollController.position;
    final nextValue = position.pixels >= position.maxScrollExtent - 48;
    if (nextValue != _isNearBottom) {
      setState(() {
        _isNearBottom = nextValue;
      });
    }
  }

  Future<void> _refreshStatus() async {
    setState(() {
      _isLoading = true;
    });

    final promotedSupport = await _service.checkPromotedSupport();
    final hasNotificationPermission =
        await _service.checkNotificationPermission();
    final isIgnoringBatteryOptimizations =
        await _service.isIgnoringBatteryOptimizations();

    if (!mounted) {
      return;
    }
    setState(() {
      _androidVersion = (promotedSupport['androidVersion'] as int?) ?? 0;
      _hasNotificationPermission =
          promotedSupport['hasNotificationPermission'] == true ||
              hasNotificationPermission;
      _hasPromotedPermission = promotedSupport['hasPromotedPermission'] == true;
      _canPostPromoted = promotedSupport['canPostPromoted'] == true;
      _isIgnoringBatteryOptimizations = isIgnoringBatteryOptimizations;
      _isLoading = false;
    });
  }

  Future<void> _runAction(Future<void> Function() action) async {
    await action();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!mounted) {
      return;
    }
    await _refreshStatus();
  }

  Future<void> _scrollMore() async {
    if (!_scrollController.hasClients) {
      return;
    }
    final target = (_scrollController.offset + 420).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );
    await _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('首次使用引导'),
        actions: [
          IconButton(
            tooltip: '刷新状态',
            onPressed: _refreshStatus,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        children: [
          _buildHeroCard(theme),
          const SizedBox(height: 16),
          _buildQuickActionsCard(theme),
          const SizedBox(height: 16),
          _buildStatusCard(theme),
          const SizedBox(height: 16),
          _buildPermissionChecklistCard(theme),
          const SizedBox(height: 16),
          _buildShortNameCard(theme),
          const SizedBox(height: 16),
          _buildImportGuideCard(theme),
          const SizedBox(height: 16),
          _buildTipsCard(theme),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(theme),
    );
  }

  Widget _buildHeroCard(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    final readyCount = [
      _hasNotificationPermission,
      _canPostPromoted,
      _isIgnoringBatteryOptimizations,
    ].where((item) => item).length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primaryContainer,
            colorScheme.surfaceContainerHighest,
          ],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.auto_awesome_rounded,
                  color: colorScheme.onPrimary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '先把这页做完，再开始用',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '首屏先授权，下面还有简称设置和导入说明，记得继续下滑。',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildHeroChip(Icons.security_rounded, '权限准备'),
              _buildHeroChip(Icons.edit_note_rounded, '简称设置'),
              _buildHeroChip(Icons.import_export_rounded, '导入课表'),
              _buildHeroChip(Icons.check_circle_rounded, '$readyCount/3 已完成'),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: colorScheme.surface.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.swipe_up_alt_rounded,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _isNearBottom
                        ? '你已经滑到最后了，确认无误后就可以开始使用。'
                        : '向下滑动继续，下面还有权限清单、简称设置和导入方式。',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _runAction(() async {
                await _service.requestNotificationPermission();
              }),
              icon: const Icon(Icons.notifications_active_outlined),
              label: const Text('先申请通知权限'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '首屏快速设置',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '先把最关键的 4 个入口放在前面，不用翻到下面再找。',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 14),
            GridView.count(
              shrinkWrap: true,
              crossAxisCount: 2,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.45,
              children: [
                _buildQuickActionButton(
                  icon: Icons.notifications_outlined,
                  title: '通知设置',
                  subtitle: '先确保能发通知',
                  onTap: () => _runAction(_service.openNotificationSettings),
                ),
                _buildQuickActionButton(
                  icon: Icons.star_border_rounded,
                  title: '超级岛权限',
                  subtitle: '检查 promoted 通知',
                  onTap: () => _runAction(_service.openPromotedSettings),
                ),
                _buildQuickActionButton(
                  icon: Icons.play_circle_outline_rounded,
                  title: '自启动',
                  subtitle: '避免后台被杀',
                  onTap: () => _runAction(_service.openAutoStartSettings),
                ),
                _buildQuickActionButton(
                  icon: Icons.battery_saver_outlined,
                  title: '电池无限制',
                  subtitle: '避免提醒中断',
                  onTap: () =>
                      _runAction(_service.openBatteryOptimizationSettings),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '当前状态',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else ...[
              _buildStatusTile(
                icon: Icons.notifications_active_outlined,
                title: '通知权限',
                value: _hasNotificationPermission ? '已开启' : '未开启',
                success: _hasNotificationPermission,
              ),
              _buildStatusTile(
                icon: Icons.auto_awesome,
                title: '焦点通知 / 超级岛',
                value: _canPostPromoted
                    ? '系统已允许'
                    : (_hasPromotedPermission ? '已开启但系统暂未确认' : '建议检查'),
                success: _canPostPromoted,
              ),
              _buildStatusTile(
                icon: Icons.battery_charging_full_outlined,
                title: '电池优化',
                value: _isIgnoringBatteryOptimizations ? '无限制' : '仍受限制',
                success: _isIgnoringBatteryOptimizations,
              ),
              _buildStatusTile(
                icon: Icons.phone_android_outlined,
                title: 'Android 版本',
                value: _androidVersion > 0 ? 'Android $_androidVersion' : '未识别',
                success: _androidVersion >= 13,
              ),
              const SizedBox(height: 6),
              Text(
                '如果上面的项目还没全绿，继续下滑，把下面的权限清单按顺序点完。',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionChecklistCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '权限清单',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '按这个顺序检查，最省事，也最不容易漏。',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            _buildChecklistTile(
              step: '1',
              icon: Icons.notifications_outlined,
              title: '申请通知权限',
              subtitle: '这是所有提醒的前提',
              onTap: () => _runAction(() async {
                await _service.requestNotificationPermission();
              }),
            ),
            _buildChecklistTile(
              step: '2',
              icon: Icons.tune,
              title: '打开通知设置',
              subtitle: '检查通知总开关、锁屏展示和实时通知权限',
              onTap: () => _runAction(_service.openNotificationSettings),
            ),
            _buildChecklistTile(
              step: '3',
              icon: Icons.star_border,
              title: '打开焦点通知设置',
              subtitle: '检查系统是否允许 promoted / 超级岛通知',
              onTap: () => _runAction(_service.openPromotedSettings),
            ),
            _buildChecklistTile(
              step: '4',
              icon: Icons.play_circle_outline,
              title: '打开自启动设置',
              subtitle: '允许应用开机自启和后台常驻',
              onTap: () => _runAction(_service.openAutoStartSettings),
            ),
            _buildChecklistTile(
              step: '5',
              icon: Icons.battery_saver_outlined,
              title: '打开电池策略设置',
              subtitle: '建议改成无限制，避免上课提醒被中断',
              onTap: () => _runAction(_service.openBatteryOptimizationSettings),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShortNameCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '课程简称建议',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '超级岛支持显示课程简称。简称不是自动生成的，需要你在课程编辑里自己填写。建议控制在 3 个字以内，显示会更稳定。',
            ),
            const SizedBox(height: 12),
            _buildTipLine('推荐示例', '高数 / 概率 / 数控'),
            const SizedBox(height: 6),
            _buildTipLine('不推荐', '高等数学A(1) / 数控技术及应用'),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      settings: const RouteSettings(name: '/courses/overview'),
                      builder: (_) => const CourseOverviewScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.edit_outlined),
                label: const Text('去设置课程简称'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImportGuideCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '课表导入方式',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '当前版本还没有直接连接教务系统导入，所以首次导入通常有两条路。',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            _buildNumberedLine(
              '1',
              '先在 WakeUp 等课表应用里导入教务系统课程，再导出日历格式，最后回到本应用导入。',
            ),
            const SizedBox(height: 8),
            _buildNumberedLine(
              '2',
              '如果别人已经在用本应用，也可以让对方导出完整备份文件，你直接导入就能恢复课程和设置。',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTipsCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '最后再看这 3 条',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '1. 先在设置页调整“上课前弹出”和“下课前数秒提醒”的阈值。',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              '2. 完成系统权限设置后，再用测试通知验证展示效果。',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              '3. 如果岛区还是偶尔消失，优先检查系统是否回收后台，通常是自启动或省电策略没有放开。',
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          border: Border(
            top: BorderSide(color: colorScheme.outlineVariant),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _isNearBottom ? '已经到底了，确认后就可以开始使用。' : '继续下滑，下面还有内容。',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(width: 12),
            if (!_isNearBottom)
              FilledButton.icon(
                onPressed: _scrollMore,
                icon: const Icon(Icons.keyboard_arrow_down_rounded),
                label: const Text('继续查看'),
              )
            else
              FilledButton.icon(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.check_rounded),
                label: const Text('开始使用'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroChip(IconData icon, String text) {
    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text(text),
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: colorScheme.primary),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChecklistTile({
    required String step,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
                child: Text(
                  step,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 12),
              Icon(icon, color: colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusTile({
    required IconData icon,
    required String title,
    required String value,
    required bool success,
  }) {
    final color = success ? Colors.green.shade700 : Colors.orange.shade700;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(value, style: TextStyle(color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipLine(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(child: Text(value)),
      ],
    );
  }

  Widget _buildNumberedLine(String step, String text) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 12,
          backgroundColor: colorScheme.primaryContainer,
          foregroundColor: colorScheme.onPrimaryContainer,
          child: Text(
            step,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(text)),
      ],
    );
  }
}
