part of '../home_page.dart';

class PasswordPage extends StatefulWidget {
  const PasswordPage({super.key});

  @override
  State<PasswordPage> createState() => _PasswordPageState();
}

class _PasswordPageState extends State<PasswordPage> {
  bool _isMyPageOpen = false;
  bool _submitting = false;
  final TextEditingController _currentPasswordController =
      TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  void _toggleMyPage() => setState(() => _isMyPageOpen = !_isMyPageOpen);

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String? _passwordValidationMessage(String value) {
    if (value.isEmpty) return null;
    if (!_isAllowedPasswordValue(value)) {
      return '비밀번호는 영문, 숫자, 특수문자만 사용할 수 있습니다.';
    }
    if (value.length < 6) {
      return '비밀번호는 6자 이상이어야 합니다.';
    }
    return null;
  }

  String? _confirmPasswordValidationMessage(String value) {
    if (value.isEmpty) return null;
    if (value != _newPasswordController.text) {
      return '새 비밀번호가 일치하지 않습니다.';
    }
    return null;
  }

  double _passwordStrength(String value) {
    if (value.isEmpty) return 0;
    var score = 0.0;
    if (value.length >= 6) score += 0.35;
    if (value.length >= 10) score += 0.15;
    if (RegExp(r'[A-Za-z]').hasMatch(value)) score += 0.2;
    if (RegExp(r'\d').hasMatch(value)) score += 0.15;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(value)) score += 0.15;
    return score.clamp(0, 1);
  }

  String _passwordStrengthLabel(double strength) {
    if (strength >= 0.85) return '강함';
    if (strength >= 0.55) return '보통';
    if (strength > 0) return '약함';
    return '입력 전';
  }

  Future<void> _changePassword() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _submitting) return;

    final providerIds = user.providerData
        .map((provider) => provider.providerId)
        .toSet();
    if (!providerIds.contains('password')) {
      _showSnack('이 계정은 이메일 비밀번호 변경을 지원하지 않습니다.');
      return;
    }

    final currentPassword = _currentPasswordController.text;
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;
    final passwordValidationMessage = _passwordValidationMessage(newPassword);
    final confirmValidationMessage = _confirmPasswordValidationMessage(
      confirmPassword,
    );

    if (currentPassword.isEmpty ||
        newPassword.isEmpty ||
        confirmPassword.isEmpty) {
      _showSnack('모든 항목을 입력해 주세요.');
      return;
    }
    if (!_isAllowedPasswordValue(currentPassword)) {
      _showSnack('현재 비밀번호는 영문, 숫자, 특수문자만 입력할 수 있습니다.');
      return;
    }
    if (passwordValidationMessage != null) {
      _showSnack(passwordValidationMessage);
      return;
    }
    if (confirmValidationMessage != null) {
      _showSnack(confirmValidationMessage);
      return;
    }
    if (currentPassword == newPassword) {
      _showSnack('새 비밀번호를 현재 비밀번호와 다르게 입력해 주세요.');
      return;
    }
    if ((user.email ?? '').trim().isEmpty) {
      _showSnack('계정 이메일을 찾을 수 없어 비밀번호를 변경할 수 없습니다.');
      return;
    }

    setState(() => _submitting = true);
    try {
      final credential = EmailAuthProvider.credential(
        email: user.email!.trim(),
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);
      await user.reload();
      if (!mounted) return;
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      _showSnack('비밀번호가 변경되었습니다.');
      Navigator.pop(context);
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      final message = switch (error.code) {
        'wrong-password' || 'invalid-credential' =>
          '현재 비밀번호가 올바르지 않습니다.',
        'weak-password' => '새 비밀번호가 너무 약합니다.',
        'too-many-requests' =>
          '요청이 많아 잠시 차단되었습니다. 잠시 후 다시 시도해 주세요.',
        'requires-recent-login' =>
          '보안을 위해 다시 로그인한 뒤 시도해주세요.',
        _ => error.message ?? '비밀번호 변경에 실패했습니다.',
      };
      _showSnack(message);
    } catch (_) {
      if (!mounted) return;
      _showSnack('비밀번호 변경 중 오류가 발생했습니다.');
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = _leagueItSurfacePalette(context);
    final strength = _passwordStrength(_newPasswordController.text);
    final strengthLabel = _passwordStrengthLabel(strength);

    return _OverlayScaffold(
      isMyPageOpen: _isMyPageOpen,
      onToggleMyPage: _toggleMyPage,
      title: 'LeagueIt',
      showSearch: false,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
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
                    offset: Offset(0, 16),
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
                      'PASSWORD',
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
                    '비밀번호 변경',
                    style: TextStyle(
                      fontSize: 28,
                      height: 1.2,
                      fontWeight: FontWeight.w800,
                      color: palette.ink,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '현재 비밀번호를 확인한 뒤 새 비밀번호로 변경합니다.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      fontWeight: FontWeight.w600,
                      color: palette.mutedInk,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _SignUpInputField(
                    controller: _currentPasswordController,
                    label: '현재 비밀번호',
                    hintText: '현재 비밀번호 입력',
                    prefixIcon: Icons.lock_outline_rounded,
                    textInputAction: TextInputAction.next,
                    obscureText: true,
                    fillColor: palette.fieldFill,
                    enabled: !_submitting,
                    keyboardType: TextInputType.visiblePassword,
                    inputFormatters: <TextInputFormatter>[
                      _passwordAsciiInputFormatter,
                    ],
                  ),
                  const SizedBox(height: 14),
                  _SignUpInputField(
                    controller: _newPasswordController,
                    label: '새 비밀번호',
                    hintText: '영문/숫자/특수문자 6자 이상',
                    prefixIcon: Icons.lock_reset_rounded,
                    textInputAction: TextInputAction.next,
                    obscureText: true,
                    fillColor: palette.fieldFill,
                    enabled: !_submitting,
                    keyboardType: TextInputType.visiblePassword,
                    inputFormatters: <TextInputFormatter>[
                      _passwordAsciiInputFormatter,
                    ],
                    helperText: _passwordValidationMessage(
                      _newPasswordController.text,
                    ),
                    helperColor: const Color(0xFFD74C4C),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 14),
                  _SignUpInputField(
                    controller: _confirmPasswordController,
                    label: '새 비밀번호 확인',
                    hintText: '새 비밀번호를 다시 입력',
                    prefixIcon: Icons.verified_user_outlined,
                    textInputAction: TextInputAction.done,
                    obscureText: true,
                    fillColor: palette.fieldFill,
                    enabled: !_submitting,
                    keyboardType: TextInputType.visiblePassword,
                    inputFormatters: <TextInputFormatter>[
                      _passwordAsciiInputFormatter,
                    ],
                    helperText: _confirmPasswordValidationMessage(
                      _confirmPasswordController.text,
                    ),
                    helperColor: const Color(0xFFD74C4C),
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) {
                      if (!_submitting) {
                        unawaited(_changePassword());
                      }
                    },
                  ),
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                    decoration: BoxDecoration(
                      color: palette.tileSurface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: palette.cardBorder),
                    ),
                    child: _StrengthMeter(strength: strength, label: strengthLabel),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _submitting ? null : _changePassword,
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        backgroundColor: palette.accent,
                        disabledBackgroundColor: palette.buttonDisabled,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: _submitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              '변경하기',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Center(
              child: Text(
                '현재 비밀번호를 알아야 변경할 수 있습니다.',
                style: TextStyle(
                  color: palette.mutedInk,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StrengthMeter extends StatelessWidget {
  final double strength;
  final String label;
  const _StrengthMeter({required this.strength, required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '비밀번호 강도: $label',
          style: TextStyle(color: cs.onSurface.withValues(alpha: 0.7)),
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: strength,
            minHeight: 10,
            backgroundColor: cs.onSurface.withValues(alpha: 0.1),
            valueColor: AlwaysStoppedAnimation(cs.primary),
          ),
        ),
      ],
    );
  }
}
