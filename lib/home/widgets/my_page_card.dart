part of '../home_page.dart';

class MyPageCard extends StatelessWidget {
  final bool isLoggedIn;
  final VoidCallback onLogin;
  final VoidCallback onLogout;

  const MyPageCard({
    super.key,
    required this.isLoggedIn,
    required this.onLogin,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final palette = _leagueItSurfacePalette(context);
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 292,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [palette.popupSurfaceTop, palette.popupSurfaceBottom],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: palette.popupBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: palette.isDark ? 0.34 : 0.13),
              blurRadius: 30,
              offset: Offset(0, 18),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              top: -34,
              right: -26,
              child: Container(
                width: 132,
                height: 132,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [Color(0x553B82F6), Color(0x003B82F6)],
                  ),
                ),
              ),
            ),
            Positioned(
              left: -18,
              bottom: -48,
              child: Container(
                width: 124,
                height: 124,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [Color(0x4010B981), Color(0x0010B981)],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF1D4ED8), Color(0xFF60A5FA)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Icon(
                          Icons.person_rounded,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '마이페이지',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: palette.ink,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isLoggedIn
                                  ? '리그 설정과 계정 메뉴를 한곳에서 관리하세요'
                                  : '로그인과 계정 생성을 여기서 진행하세요',
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.35,
                                fontWeight: FontWeight.w700,
                                color: palette.mutedInk,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isLoggedIn
                              ? palette.accentSoft
                              : palette.tileSurface,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          isLoggedIn ? '이용 중' : '게스트',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: isLoggedIn
                                ? palette.accent
                                : palette.mutedInk,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: palette.tileSurface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: palette.popupBorder),
                    ),
                    child: Column(
                      children: [
                        if (!isLoggedIn) ...[
                          _MyPageAction(
                            title: '로그인',
                            subtitle: 'LeagueIt 계정으로 계속 진행하세요',
                            icon: Icons.login_rounded,
                            accent: const Color(0xFF2563EB),
                            onTap: () async {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const LoginPage(),
                                ),
                              );
                              if (result == true) {
                                onLogin();
                              }
                            },
                          ),
                          const SizedBox(height: 10),
                          _MyPageAction(
                            title: '계정 만들기',
                            subtitle: '새 프로필을 만들고 리그에 참여하세요',
                            icon: Icons.person_add_alt_1_rounded,
                            accent: const Color(0xFF10B981),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const SignUpPage(),
                                ),
                              );
                            },
                          ),
                        ] else ...[
                          _MyPageAction(
                            title: '프로필',
                            subtitle: '내 계정 정보를 관리하세요',
                            icon: Icons.badge_rounded,
                            accent: const Color(0xFF2563EB),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const ProfilePage(),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 10),
                          _MyPageAction(
                            title: '내 리그',
                            subtitle: '참여 중인 리그와 초대를 확인하세요',
                            icon: Icons.emoji_events_rounded,
                            accent: const Color(0xFFF59E0B),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const MyLeaguePage(),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 10),
                          _MyPageAction(
                            title: '비밀번호',
                            subtitle: '로그인 비밀번호를 변경하세요',
                            icon: Icons.lock_reset_rounded,
                            accent: const Color(0xFF8B5CF6),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const PasswordPage(),
                                ),
                              );
                            },
                          ),
                        ],
                        const SizedBox(height: 10),
                        _MyPageAction(
                          title: '설정',
                          subtitle: '앱 설정과 권한 항목을 확인하세요',
                          icon: Icons.settings_rounded,
                          accent: const Color(0xFF0EA5E9),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const SettingsPage(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  if (isLoggedIn) ...[
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton.icon(
                        onPressed: onLogout,
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFFDC2626),
                          backgroundColor: palette.isDark
                              ? const Color(0xFF3A171B)
                              : const Color(0xFFFFF1F2),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        icon: const Icon(Icons.logout_rounded, size: 18),
                        label: const Text(
                          '로그아웃',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MyPagePopupOverlay extends StatelessWidget {
  final bool isOpen;
  final VoidCallback onDismiss;
  final bool isLoggedIn;
  final VoidCallback onLogin;
  final VoidCallback onLogout;

  const _MyPagePopupOverlay({
    required this.isOpen,
    required this.onDismiss,
    required this.isLoggedIn,
    required this.onLogin,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        IgnorePointer(
          ignoring: !isOpen,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            opacity: isOpen ? 1 : 0,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onDismiss,
              child: Container(color: Colors.black.withValues(alpha: 0.35)),
            ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            ignoring: !isOpen,
            child: SafeArea(
              bottom: false,
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: AnimatedSlide(
                    duration: const Duration(milliseconds: 320),
                    curve: Curves.easeOutCubic,
                    offset: isOpen ? Offset.zero : const Offset(0, -0.08),
                    child: AnimatedScale(
                      duration: const Duration(milliseconds: 320),
                      curve: Curves.easeOutCubic,
                      scale: isOpen ? 1.0 : 0.97,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        opacity: isOpen ? 1 : 0,
                        child: MyPageCard(
                          isLoggedIn: isLoggedIn,
                          onLogin: onLogin,
                          onLogout: onLogout,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MyPageAction extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;

  const _MyPageAction({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = _leagueItSurfacePalette(context);
    return Material(
      color: palette.tileSurface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: palette.popupBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: accent, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: palette.ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: palette.mutedInk,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: palette.mutedInk,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
