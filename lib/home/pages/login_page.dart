part of '../home_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _submitting = false;

  static final RegExp _emailPattern = RegExp(
    r"^[A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]+@[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+$",
  );

  String? _emailValidationMessage(String value) {
    final email = value.trim();
    if (email.isEmpty) return null;
    if (!_emailPattern.hasMatch(email)) {
      return '올바른 이메일 형식이 아닙니다.';
    }
    return null;
  }

  String? _passwordValidationMessage(String value) {
    if (value.isEmpty) return null;
    if (!_isAllowedPasswordValue(value)) {
      return '비밀번호는 영문, 숫자, 특수문자만 사용할 수 있습니다.';
    }
    return null;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loginWithEmail() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final emailValidationMessage = _emailValidationMessage(email);
    final passwordValidationMessage = _passwordValidationMessage(password);
    if (email.isEmpty || password.isEmpty) {
      _showSnack('이메일과 비밀번호를 입력해 주세요.');
      return;
    }
    if (emailValidationMessage != null) {
      _showSnack(emailValidationMessage);
      return;
    }
    if (passwordValidationMessage != null) {
      _showSnack(passwordValidationMessage);
      return;
    }

    setState(() => _submitting = true);
    try {
      await authController.signInWithEmail(email: email, password: password);
      if (!mounted) return;
      Navigator.pop(context, true);
    } on FirebaseAuthException catch (e) {
      _showSnack(_firebaseErrorMessage(e));
    } catch (_) {
      _showSnack('로그인 중 오류가 발생했습니다.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _loginWithGoogle() async {
    setState(() => _submitting = true);
    try {
      await authController.signInWithGoogle();
      if (!mounted) return;
      Navigator.pop(context, true);
    } on FirebaseAuthException catch (e) {
      if (_isGoogleCancelCode(e.code)) {
        return;
      }
      _showSnack(_firebaseErrorMessage(e));
    } on Exception catch (e) {
      if (_isGoogleCancelError(e)) {
        return;
      }
      _showSnack('Google 로그인 실패: $e');
    } catch (_) {
      _showSnack('Google 로그인 중 오류가 발생했습니다.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _loginWithApple() async {
    setState(() => _submitting = true);
    try {
      await authController.signInWithApple();
      if (!mounted) return;
      Navigator.pop(context, true);
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        return;
      }
      _showSnack('Apple 로그인 실패: ${e.message}');
    } on FirebaseAuthException catch (e) {
      _showSnack(_firebaseErrorMessage(e));
    } catch (_) {
      _showSnack('Apple 로그인 중 오류가 발생했습니다.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _firebaseErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return '이메일 형식이 올바르지 않습니다.';
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return '이메일 또는 비밀번호가 올바르지 않습니다.';
      case 'too-many-requests':
        return '요청이 많아 잠시 차단되었습니다. 잠시 후 다시 시도해 주세요.';
      default:
        return e.message ?? '인증에 실패했습니다.';
    }
  }

  bool _isGoogleCancelCode(String code) {
    return code == 'aborted-by-user' ||
        code == 'popup-closed-by-user' ||
        code == 'cancelled-popup-request' ||
        code == 'web-context-cancelled';
  }

  bool _isGoogleCancelError(Object error) {
    final text = error.toString().toLowerCase();
    return text.contains('google signinexceptioncode.canceled') ||
        text.contains('google signinexceptioncode.cancelled') ||
        text.contains(' canceled') ||
        text.contains(' cancelled') ||
        text.contains('user canceled') ||
        text.contains('user cancelled') ||
        text.contains('aborted-by-user') ||
        text.contains('popup_closed_by_user');
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final palette = _leagueItSurfacePalette(context);

    return Scaffold(
      backgroundColor: palette.pageBackground,
      appBar: AppBar(
        backgroundColor: palette.pageBackground,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          '로그인',
          style: TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w700,
            color: palette.ink,
          ),
        ),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                        'WELCOME BACK',
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
                      'LeagueIt',
                      style: TextStyle(
                        fontSize: 28,
                        height: 1.2,
                        fontWeight: FontWeight.w800,
                        color: palette.ink,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _SignUpInputField(
                      controller: _emailController,
                      label: '이메일',
                      hintText: 'name@example.com',
                      keyboardType: TextInputType.emailAddress,
                      prefixIcon: Icons.alternate_email_rounded,
                      textInputAction: TextInputAction.next,
                      fillColor: palette.fieldFill,
                    ),
                    const SizedBox(height: 14),
                    _SignUpInputField(
                      controller: _passwordController,
                      label: '비밀번호',
                      hintText: '영문/숫자/특수문자 입력',
                      obscureText: true,
                      prefixIcon: Icons.lock_outline_rounded,
                      textInputAction: TextInputAction.done,
                      keyboardType: TextInputType.visiblePassword,
                      inputFormatters: <TextInputFormatter>[
                        _passwordAsciiInputFormatter,
                      ],
                      onSubmitted: (_) {
                        if (!_submitting) {
                          unawaited(_loginWithEmail());
                        }
                      },
                      fillColor: palette.fieldFill,
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _submitting ? null : _loginWithEmail,
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
                                  strokeWidth: 2.4,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Text(
                                '로그인',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(child: Divider(color: palette.cardBorder)),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            '또는',
                            style: TextStyle(
                              color: palette.mutedInk,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Expanded(child: Divider(color: palette.cardBorder)),
                      ],
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: OutlinedButton(
                        onPressed: _submitting ? null : _loginWithGoogle,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: palette.ink,
                          backgroundColor: palette.tileSurface,
                          side: BorderSide(color: palette.cardBorder),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image(
                              image: AssetImage('assets/google_logo.png'),
                              width: 20,
                              height: 20,
                            ),
                            SizedBox(width: 12),
                            Text(
                              'Google로 로그인',
                              style: TextStyle(
                                color: palette.ink,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: OutlinedButton(
                        onPressed: _submitting ? null : _loginWithApple,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: Colors.black,
                          disabledBackgroundColor: Colors.black26,
                          side: const BorderSide(color: Colors.black),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(CupertinoIcons.logo_apple, size: 20),
                            SizedBox(width: 12),
                            Text(
                              'Apple로 로그인',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Center(
                      child: TextButton(
                        onPressed: _submitting
                            ? null
                            : () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const SignUpPage(),
                                  ),
                                );
                              },
                        child: const Text(
                          '회원가입',
                          style: TextStyle(
                            color: Color(0xFF245B45),
                            fontSize: 15,
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
                  '계정이 없으면 회원가입을 진행하세요.',
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
      ),
    );
  }
}
