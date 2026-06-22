part of '../home_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  static const String _appVersionLabel = '1.0.0+1';

  bool _isMyPageOpen = false;
  bool _pushEnabled = true;
  bool _largeTextMode = false;
  bool _isDeletingAccount = false;
  ScoreNumberFormat _scoreNumberFormat = ScoreNumberFormat.oneDecimal;
  AppThemePreference _themePreference = AppThemePreference.light;

  void _toggleMyPage() => setState(() => _isMyPageOpen = !_isMyPageOpen);

  @override
  void initState() {
    super.initState();
    _syncFromAppSettings();
    appSettings.addListener(_handleAppSettingsChanged);
  }

  @override
  void dispose() {
    appSettings.removeListener(_handleAppSettingsChanged);
    super.dispose();
  }

  void _handleAppSettingsChanged() {
    if (!mounted) return;
    setState(_syncFromAppSettings);
  }

  void _syncFromAppSettings() {
    _themePreference = appSettings.themePreference;
    _pushEnabled = appSettings.pushEnabled;
    _largeTextMode = appSettings.largeTextMode;
    _scoreNumberFormat = appSettings.scoreNumberFormat;
  }

  String _scoreNumberFormatLabel(ScoreNumberFormat format) {
    switch (format) {
      case ScoreNumberFormat.oneDecimal:
        return '소수 1자리';
      case ScoreNumberFormat.integerIfPossible:
        return '정수 우선';
    }
  }

  String _themePreferenceLabel(AppThemePreference preference) {
    switch (preference) {
      case AppThemePreference.light:
        return '라이트';
      case AppThemePreference.dark:
        return '다크';
      case AppThemePreference.autoSunCycle:
        return '자동';
    }
  }

  Future<void> _applyThemePreference(AppThemePreference preference) async {
    setState(() => _themePreference = preference);
    final message = await appSettings.setThemePreference(preference);
    if (!mounted || message == null || message.trim().isEmpty) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  bool _hasPasswordProvider(User user) {
    return user.providerData.any(
      (provider) => provider.providerId == 'password',
    );
  }

  bool _hasGoogleProvider(User user) {
    return user.providerData.any(
      (provider) => provider.providerId == 'google.com',
    );
  }

  Future<String?> _showDeleteAccountDialog({
    required bool requiresPassword,
    required String email,
  }) async {
    return showDialog<String>(
      context: context,
      builder: (ctx) => _DeleteAccountDialog(
        requiresPassword: requiresPassword,
        email: email,
      ),
    );
  }

  String _deleteAccountErrorMessage(FirebaseAuthException error) {
    return switch (error.code) {
      'missing-password' => '현재 비밀번호를 입력해 주세요.',
      'wrong-password' || 'invalid-credential' => '현재 비밀번호가 올바르지 않습니다.',
      'requires-recent-login' => '보안을 위해 다시 로그인한 뒤 시도해 주세요.',
      'too-many-requests' => '요청이 많아 잠시 차단되었습니다. 잠시 후 다시 시도해 주세요.',
      'google-auth-missing-token' => 'Google 인증 정보를 다시 가져오지 못했습니다. 다시 시도해 주세요.',
      'missing-email' => '계정 이메일을 찾을 수 없어 탈퇴를 진행할 수 없습니다.',
      'unsupported-provider' => '이 로그인 방식은 앱 내 회원탈퇴를 지원하지 않습니다.',
      'null-user' || 'invalid-user' => '로그인 사용자 정보를 다시 확인해 주세요.',
      _ => error.message ?? '회원탈퇴에 실패했습니다.',
    };
  }

  Future<void> _deleteAccount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _isDeletingAccount) return;
    final navigator = Navigator.of(context);

    final requiresPassword = _hasPasswordProvider(user);
    final confirmedInput = await _showDeleteAccountDialog(
      requiresPassword: requiresPassword,
      email: user.email?.trim() ?? '',
    );
    if (confirmedInput == null) return;
    if (requiresPassword && confirmedInput.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('현재 비밀번호를 입력해 주세요.')));
      return;
    }

    final deletedUid = user.uid.trim();
    setState(() => _isDeletingAccount = true);

    try {
      await authController.deleteCurrentUser(currentPassword: confirmedInput);
      await homeKey.currentState?.clearPersistedLocalStateForUid(deletedUid);
      await _deletePersistedProfileAvatarForUid(deletedUid);
      navigator.popUntil((route) => route.isFirst);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final rootContext = homeKey.currentContext;
        if (rootContext == null) return;
        ScaffoldMessenger.maybeOf(
          rootContext,
        )?.showSnackBar(const SnackBar(content: Text('회원탈퇴가 완료되었습니다.')));
      });
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_deleteAccountErrorMessage(error))),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('회원탈퇴 중 오류가 발생했습니다.')));
    } finally {
      if (mounted) {
        setState(() => _isDeletingAccount = false);
      }
    }
  }

  void _replayAppOnboarding() {
    final navigator = Navigator.of(context);
    navigator.popUntil((route) => route.isFirst);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final homeState = homeKey.currentState;
      homeState?.replayAppOnboarding();
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = _leagueItSurfacePalette(context);
    final user = FirebaseAuth.instance.currentUser;
    final providerHint = user == null
        ? '로그인된 계정을 찾을 수 없습니다.'
        : _hasPasswordProvider(user)
        ? '현재 비밀번호를 다시 입력한 뒤 탈퇴할 수 있습니다.'
        : _hasGoogleProvider(user)
        ? '탈퇴 시 Google 인증이 한 번 더 필요합니다.'
        : '탈퇴 시 계정과 프로필 데이터가 함께 삭제됩니다.';
    return _OverlayScaffold(
      isMyPageOpen: _isMyPageOpen,
      onToggleMyPage: _toggleMyPage,
      title: 'LeagueIt',
      showSearch: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(32),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [palette.gradientTop, palette.gradientBottom],
              ),
              border: Border.all(color: palette.cardBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: palette.isDark ? 0.28 : 0.07,
                  ),
                  blurRadius: 28,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: palette.accentSoft,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'SETTINGS',
                    style: TextStyle(
                      color: palette.accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  '설정',
                  style: TextStyle(
                    fontSize: 28,
                    height: 1.2,
                    fontWeight: FontWeight.w800,
                    color: palette.ink,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '테마, 숫자 표기, 글씨 크기, 알림을 관리하세요',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                    color: palette.mutedInk,
                  ),
                ),
                const SizedBox(height: 24),
                _SettingsTile(
                  palette: palette,
                  icon: Icons.dark_mode_outlined,
                  title: '테마 모드',
                  body: _themePreference == AppThemePreference.autoSunCycle
                      ? appSettings.themeAutomationDescription
                      : _themePreference == AppThemePreference.dark
                      ? '다크 테마를 항상 사용합니다.'
                      : '밝은 테마를 항상 사용합니다.',
                  trailing: DropdownButtonHideUnderline(
                    child: DropdownButton<AppThemePreference>(
                      value: _themePreference,
                      borderRadius: BorderRadius.circular(14),
                      dropdownColor: palette.tileSurface,
                      style: TextStyle(
                        color: palette.ink,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                      iconEnabledColor: palette.accent,
                      items: AppThemePreference.values
                          .map(
                            (preference) =>
                                DropdownMenuItem<AppThemePreference>(
                                  value: preference,
                                  child: Text(
                                    _themePreferenceLabel(preference),
                                  ),
                                ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        unawaited(_applyThemePreference(value));
                      },
                    ),
                  ),
                ),
                _SettingsTile(
                  palette: palette,
                  icon: Icons.format_list_numbered_rounded,
                  title: '숫자 표기 방식',
                  body: '점수와 수치를 어떤 방식으로 표시할지 정합니다.',
                  trailing: DropdownButtonHideUnderline(
                    child: DropdownButton<ScoreNumberFormat>(
                      value: _scoreNumberFormat,
                      borderRadius: BorderRadius.circular(14),
                      dropdownColor: palette.tileSurface,
                      style: TextStyle(
                        color: palette.ink,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                      iconEnabledColor: palette.accent,
                      items: ScoreNumberFormat.values
                          .map(
                            (format) => DropdownMenuItem<ScoreNumberFormat>(
                              value: format,
                              child: Text(_scoreNumberFormatLabel(format)),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _scoreNumberFormat = value);
                        appSettings.setScoreNumberFormat(value);
                      },
                    ),
                  ),
                ),
                _SettingsTile(
                  palette: palette,
                  icon: Icons.text_fields_rounded,
                  title: '큰 글씨 모드',
                  body: '텍스트를 조금 더 크게 표시합니다.',
                  trailing: Switch.adaptive(
                    value: _largeTextMode,
                    onChanged: (value) {
                      setState(() => _largeTextMode = value);
                      appSettings.setLargeTextMode(value);
                    },
                  ),
                ),
                _SettingsTile(
                  palette: palette,
                  icon: Icons.notifications_active_outlined,
                  title: '푸시 알림',
                  body: '경기, 매치업, 주요 이벤트 알림을 받습니다.',
                  trailing: Switch.adaptive(
                    value: _pushEnabled,
                    onChanged: (value) {
                      setState(() => _pushEnabled = value);
                      appSettings.setPushEnabled(value);
                    },
                  ),
                ),
                _SettingsTile(
                  palette: palette,
                  icon: Icons.info_outline_rounded,
                  title: '앱 버전',
                  body: '현재 설치된 LeagueIt 버전입니다.',
                  trailing: Text(
                    _appVersionLabel,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: palette.accent,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                  decoration: BoxDecoration(
                    color: palette.tileSurface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: palette.cardBorder),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: palette.accentSoft,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: palette.chipBorder),
                        ),
                        child: Icon(
                          Icons.play_circle_outline_rounded,
                          color: palette.accent,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '온보딩 다시 보기',
                              style: TextStyle(
                                color: palette.ink,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '앱 소개 화면을 처음부터 다시 보여줍니다.',
                              style: TextStyle(
                                color: palette.mutedInk,
                                fontSize: 13.5,
                                height: 1.4,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton(
                        onPressed: _replayAppOnboarding,
                        style: FilledButton.styleFrom(
                          backgroundColor: palette.accent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          '다시 보기',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                  decoration: BoxDecoration(
                    color: palette.tileSurface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFF3B5AF)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF1F2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.warning_amber_rounded,
                              color: Color(0xFFD92D20),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              '회원탈퇴',
                              style: TextStyle(
                                color: palette.ink,
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '계정을 삭제하면 프로필, 유저네임, 참가 중인 리그 연결 정보가 앱에서 정리됩니다.',
                        style: TextStyle(
                          color: palette.ink,
                          fontSize: 13.5,
                          height: 1.45,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        providerHint,
                        style: const TextStyle(
                          color: Color(0xFFB42318),
                          fontSize: 12.5,
                          height: 1.4,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: user == null || _isDeletingAccount
                              ? null
                              : _deleteAccount,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFD92D20),
                            disabledBackgroundColor: palette.buttonDisabled,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: _isDeletingAccount
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  '회원탈퇴 진행',
                                  style: TextStyle(fontWeight: FontWeight.w800),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Center(
            child: Text(
              '설정은 이 기기에서 바로 적용됩니다.',
              style: TextStyle(
                color: palette.mutedInk,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final _LeagueItSurfacePalette palette;
  final IconData icon;
  final String title;
  final String body;
  final Widget trailing;

  const _SettingsTile({
    required this.palette,
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
        color: palette.tileSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: palette.accentSoft,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: palette.chipBorder),
            ),
            child: Icon(icon, size: 18, color: palette.accent),
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
                    fontWeight: FontWeight.w700,
                    color: palette.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: TextStyle(fontSize: 13.5, color: palette.mutedInk),
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

class _DeleteAccountDialog extends StatefulWidget {
  final bool requiresPassword;
  final String email;

  const _DeleteAccountDialog({
    required this.requiresPassword,
    required this.email,
  });

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = _leagueItSurfacePalette(context);
    return AlertDialog(
      backgroundColor: palette.tileSurface,
      title: const Text('회원탈퇴'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.requiresPassword
                  ? '계정을 삭제하면 프로필과 가입 중인 리그 정보가 함께 정리됩니다.\n현재 비밀번호를 입력해 확인해 주세요.'
                  : '계정을 삭제하면 프로필과 가입 중인 리그 정보가 함께 정리됩니다.\n계속하면 인증을 한 번 더 진행합니다.',
              style: TextStyle(
                color: palette.ink,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (widget.requiresPassword) ...[
              const SizedBox(height: 16),
              Text(
                widget.email,
                style: TextStyle(
                  color: palette.mutedInk,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _controller,
                obscureText: true,
                enableSuggestions: false,
                autocorrect: false,
                inputFormatters: [_passwordAsciiInputFormatter],
                decoration: const InputDecoration(labelText: '현재 비밀번호'),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFD92D20),
          ),
          onPressed: () => Navigator.of(
            context,
          ).pop(widget.requiresPassword ? _controller.text : ''),
          child: const Text('회원탈퇴'),
        ),
      ],
    );
  }
}
