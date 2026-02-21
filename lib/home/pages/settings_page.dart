part of '../home_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _isMyPageOpen = false;
  bool _darkMode = false;
  bool _pushEnabled = true;

  void _toggleMyPage() => setState(() => _isMyPageOpen = !_isMyPageOpen);

  @override
  void initState() {
    super.initState();
    _darkMode = appSettings.darkMode;
  }

  @override
  Widget build(BuildContext context) {
    return _OverlayScaffold(
      isMyPageOpen: _isMyPageOpen,
      onToggleMyPage: _toggleMyPage,
      showSearch: false,
      child: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(child: _SettingsHero()),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
            sliver: SliverList.list(
              children: [
                _SettingsTile(
                  icon: Icons.dark_mode_outlined,
                  title: 'Display',
                  body: '다크 모드 전환',
                  trailing: Switch(
                    value: _darkMode,
                    onChanged: (v) => setState(() {
                      _darkMode = v;
                      appSettings.setDarkMode(v);
                    }),
                  ),
                ),
                _SettingsTile(
                  icon: Icons.notifications_active_outlined,
                  title: 'Notifications',
                  body: '매치 알림, 라인업 마감 알림',
                  trailing: Switch(
                    value: _pushEnabled,
                    onChanged: (v) => setState(() => _pushEnabled = v),
                  ),
                ),
                const _InfoCard(
                  icon: Icons.privacy_tip_outlined,
                  title: 'Privacy & Security',
                  body: '데이터 접근 및 권한 설정을 확인하세요.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final Widget trailing;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.body,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFE4F7EA),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.green.shade300),
            ),
            child: Icon(icon, size: 18, color: Colors.green.shade800),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: const TextStyle(fontSize: 13.5, color: Colors.black87),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          trailing,
        ],
      ),
    );
  }
}

class _SettingsHero extends StatelessWidget {
  const _SettingsHero();

  @override
  Widget build(BuildContext context) {
    return _GradientCard(
      icon: Icons.tune_outlined,
      title: 'Settings',
      subtitle: '디스플레이, 알림, 텍스트 크기 등을 관리하세요',
    );
  }
}
