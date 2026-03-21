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

  bool _isLoading = true;
  bool _hasNotificationPermission = false;
  bool _hasPromotedPermission = false;
  bool _canPostPromoted = false;
  bool _isIgnoringBatteryOptimizations = false;
  int _androidVersion = 0;

  @override
  void initState() {
    super.initState();
    _refreshStatus();
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

    if (!mounted) return;
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
    if (!mounted) return;
    await _refreshStatus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('使用引导'),
        actions: [
          IconButton(
            tooltip: '刷新状态',
            onPressed: _refreshStatus,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildIntroCard(theme),
          const SizedBox(height: 16),
          _buildImportGuideCard(theme),
          const SizedBox(height: 16),
          _buildStatusCard(colorScheme),
          const SizedBox(height: 16),
          _buildPermissionCard(),
          const SizedBox(height: 16),
          _buildShortNameCard(),
          const SizedBox(height: 16),
          _buildTipsCard(theme),
        ],
      ),
    );
  }

  Widget _buildIntroCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '超级岛完整使用建议',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '想让上课提醒稳定显示，需要系统允许通知常驻、允许后台运行，并尽量关闭省电限制。'
              '如果你希望岛区显示更干净，建议给课程设置简称，最好控制在 3 个字以内。',
              style: theme.textTheme.bodyMedium,
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
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '当前版本还没有直接连接教务系统导入的能力，所以首次导入通常有两条路：',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Text(
              '1. 先在 WakeUp 等课表应用里导入教务系统课程，再在它们的软件里选择“日历格式导出”，最后回到本应用导入课程。',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              '2. 直接让其他用户从本应用导出完整备份文件，你拿到后在“数据备份与迁移”里导入，就能直接恢复课程和设置。',
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(ColorScheme colorScheme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '当前状态',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '引导设置',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('按顺序检查这些入口，能明显减少超级岛不显示、被系统杀后台、提醒中断的问题。'),
            const SizedBox(height: 12),
            _buildActionTile(
              icon: Icons.notifications_outlined,
              title: '申请通知权限',
              subtitle: '先确保应用可以发通知',
              onTap: () => _runAction(() async {
                await _service.requestNotificationPermission();
              }),
            ),
            _buildActionTile(
              icon: Icons.tune,
              title: '打开通知设置',
              subtitle: '检查通知总开关、锁屏展示和实时通知权限',
              onTap: () => _runAction(_service.openNotificationSettings),
            ),
            _buildActionTile(
              icon: Icons.star_border,
              title: '打开焦点通知设置',
              subtitle: '检查系统是否允许推广 / promoted ongoing 通知',
              onTap: () => _runAction(_service.openPromotedSettings),
            ),
            _buildActionTile(
              icon: Icons.play_circle_outline,
              title: '打开自启动设置',
              subtitle: '允许应用开机自启和后台常驻',
              onTap: () => _runAction(_service.openAutoStartSettings),
            ),
            _buildActionTile(
              icon: Icons.battery_saver_outlined,
              title: '打开电池策略设置',
              subtitle: '建议将本应用改成无限制，避免上课提醒被中断',
              onTap: () => _runAction(_service.openBatteryOptimizationSettings),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShortNameCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '课程简称建议',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '超级岛支持显示课程简称。简称不是自动生成的，需要你在课程编辑里自己填写。'
              '建议控制在 3 个字以内，岛区显示会更稳定，也更不容易被截断。',
            ),
            const SizedBox(height: 12),
            _buildTipLine('推荐示例', '高数 / 概率 / 数控'),
            const SizedBox(height: 6),
            _buildTipLine('不推荐', '高等数学A(1) / 数控技术及应用'),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
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

  Widget _buildTipsCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '使用建议',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(value, style: TextStyle(color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
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
}
