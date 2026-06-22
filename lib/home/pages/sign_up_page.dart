part of '../home_page.dart';

enum _UsernameAvailabilityState {
  idle,
  checking,
  available,
  unavailable,
  invalid,
}

enum _InlineFieldState {
  idle,
  valid,
  invalid,
}

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  bool _submitting = false;
  Timer? _usernameDebounce;
  int _usernameCheckToken = 0;
  _UsernameAvailabilityState _usernameState = _UsernameAvailabilityState.idle;
  String? _usernameMessage;

  String _sanitizeUsername(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  static final RegExp _emailPattern = RegExp(
    r"^[A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]+@[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+$",
  );

  String _normalizeUsername(String value) {
    return _sanitizeUsername(value).toLowerCase();
  }

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
    if (value.length < 6) {
      return '비밀번호는 6자 이상이어야 합니다.';
    }
    return null;
  }

  String? _confirmPasswordValidationMessage(String value) {
    if (value.isEmpty) return null;
    if (value != _passwordController.text) {
      return '비밀번호가 일치하지 않습니다.';
    }
    return null;
  }

  String? _usernameValidationMessage(String username) {
    if (username.isEmpty) return null;
    if (username.length < 2) {
      return '유저네임은 2자 이상이어야 합니다.';
    }
    if (username.contains('/')) {
      return '유저네임에는 / 문자를 사용할 수 없습니다.';
    }
    return null;
  }

  void _handleUsernameChanged(String rawValue) {
    final username = _sanitizeUsername(rawValue);
    _usernameDebounce?.cancel();
    final validationMessage = _usernameValidationMessage(username);
    if (username.isEmpty) {
      setState(() {
        _usernameState = _UsernameAvailabilityState.idle;
        _usernameMessage = null;
      });
      return;
    }
    if (validationMessage != null) {
      setState(() {
        _usernameState = _UsernameAvailabilityState.invalid;
        _usernameMessage = validationMessage;
      });
      return;
    }

    final token = ++_usernameCheckToken;
    setState(() {
      _usernameState = _UsernameAvailabilityState.checking;
      _usernameMessage = null;
    });
    _usernameDebounce = Timer(const Duration(milliseconds: 350), () {
      unawaited(_checkUsernameAvailability(username, token));
    });
  }

  Future<void> _checkUsernameAvailability(String username, int token) async {
    try {
      final normalizedUsername = _normalizeUsername(username);
      final snapshot = await FirebaseFirestore.instance
          .collection('usernames')
          .doc(normalizedUsername)
          .get();
      if (!mounted || token != _usernameCheckToken) return;
      final currentUsername = _sanitizeUsername(_usernameController.text);
      if (currentUsername != username) return;
      setState(() {
        if (snapshot.exists) {
          _usernameState = _UsernameAvailabilityState.unavailable;
          _usernameMessage = '이미 사용 중인 유저네임입니다.';
        } else {
          _usernameState = _UsernameAvailabilityState.available;
          _usernameMessage = '사용 가능한 유저네임입니다.';
        }
      });
    } catch (_) {
      if (!mounted || token != _usernameCheckToken) return;
      setState(() {
        _usernameState = _UsernameAvailabilityState.invalid;
        _usernameMessage = '유저네임 확인에 실패했습니다. 다시 시도해주세요.';
      });
    }
  }

  Future<bool> _ensureUsernameAvailableForSubmit(String username) async {
    final validationMessage = _usernameValidationMessage(username);
    if (validationMessage != null) {
      setState(() {
        _usernameState = _UsernameAvailabilityState.invalid;
        _usernameMessage = validationMessage;
      });
      return false;
    }
    if (_usernameState == _UsernameAvailabilityState.available) {
      return true;
    }
    if (_usernameState == _UsernameAvailabilityState.checking) {
      _usernameDebounce?.cancel();
      await _checkUsernameAvailability(username, _usernameCheckToken);
      return _usernameState == _UsernameAvailabilityState.available;
    }
    final token = ++_usernameCheckToken;
    setState(() {
      _usernameState = _UsernameAvailabilityState.checking;
      _usernameMessage = null;
    });
    await _checkUsernameAvailability(username, token);
    return _usernameState == _UsernameAvailabilityState.available;
  }

  Color _usernameBorderColor() {
    switch (_usernameState) {
      case _UsernameAvailabilityState.available:
        return const Color(0xFF2F8F5B);
      case _UsernameAvailabilityState.unavailable:
      case _UsernameAvailabilityState.invalid:
        return const Color(0xFFD74C4C);
      case _UsernameAvailabilityState.checking:
        return const Color(0xFFD6DBD1);
      case _UsernameAvailabilityState.idle:
        return const Color(0xFFD6DBD1);
    }
  }

  Color _usernameMessageColor() {
    switch (_usernameState) {
      case _UsernameAvailabilityState.available:
        return const Color(0xFF2F8F5B);
      case _UsernameAvailabilityState.unavailable:
      case _UsernameAvailabilityState.invalid:
        return const Color(0xFFD74C4C);
      case _UsernameAvailabilityState.checking:
        return const Color(0xFF6B6C66);
      case _UsernameAvailabilityState.idle:
        return const Color(0xFF6B6C66);
    }
  }

  Widget? _usernameStatusIcon() {
    switch (_usernameState) {
      case _UsernameAvailabilityState.checking:
        return null;
      case _UsernameAvailabilityState.available:
        return const Icon(
          Icons.check_circle_rounded,
          color: Color(0xFF2F8F5B),
        );
      case _UsernameAvailabilityState.unavailable:
      case _UsernameAvailabilityState.invalid:
        return const Icon(
          Icons.cancel_rounded,
          color: Color(0xFFD74C4C),
        );
      case _UsernameAvailabilityState.idle:
        return null;
    }
  }

  _InlineFieldState _inlineFieldState(String? message, String value) {
    if (value.isEmpty) return _InlineFieldState.idle;
    return message == null ? _InlineFieldState.valid : _InlineFieldState.invalid;
  }

  Color _inlineFieldBorderColor(_InlineFieldState state) {
    switch (state) {
      case _InlineFieldState.valid:
        return const Color(0xFF2F8F5B);
      case _InlineFieldState.invalid:
        return const Color(0xFFD74C4C);
      case _InlineFieldState.idle:
        return const Color(0xFFD6DBD1);
    }
  }

  Color _inlineFieldHelperColor(_InlineFieldState state) {
    switch (state) {
      case _InlineFieldState.valid:
        return const Color(0xFF2F8F5B);
      case _InlineFieldState.invalid:
        return const Color(0xFFD74C4C);
      case _InlineFieldState.idle:
        return const Color(0xFF6B6C66);
    }
  }

  Widget? _inlineFieldStatusIcon(_InlineFieldState state) {
    switch (state) {
      case _InlineFieldState.valid:
        return const Icon(
          Icons.check_circle_rounded,
          color: Color(0xFF2F8F5B),
        );
      case _InlineFieldState.invalid:
        return const Icon(
          Icons.cancel_rounded,
          color: Color(0xFFD74C4C),
        );
      case _InlineFieldState.idle:
        return null;
    }
  }

  @override
  void dispose() {
    _usernameDebounce?.cancel();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    final username = _sanitizeUsername(_usernameController.text);
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmController.text;

    if (username.isEmpty || email.isEmpty || password.isEmpty || confirm.isEmpty) {
      _showSnack('모든 항목을 입력해 주세요.');
      return;
    }
    if (username.length < 2) {
      _showSnack('유저네임은 2자 이상이어야 합니다.');
      return;
    }
    if (username.contains('/')) {
      _showSnack('유저네임에는 / 문자를 사용할 수 없습니다.');
      return;
    }
    if (!await _ensureUsernameAvailableForSubmit(username)) {
      if (_usernameState == _UsernameAvailabilityState.unavailable) {
        _showSnack('이미 사용 중인 유저네임입니다.');
      }
      return;
    }
    if (!_isAllowedPasswordValue(password) ||
        !_isAllowedPasswordValue(confirm)) {
      _showSnack('비밀번호는 영문, 숫자, 특수문자만 사용할 수 있습니다.');
      return;
    }
    if (password != confirm) {
      _showSnack('비밀번호가 일치하지 않습니다.');
      return;
    }
    if (password.length < 6) {
      _showSnack('비밀번호는 6자 이상이어야 합니다.');
      return;
    }

    setState(() => _submitting = true);
    try {
      await authController.signUpWithEmail(
        email: email,
        password: password,
        username: username,
      );
      // 요구사항: 가입 성공 후 다시 로그인하도록 즉시 로그아웃.
      await authController.signOut();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('회원가입 완료. 로그인해 주세요.')),
      );
      Navigator.pop(context);
    } on UsernameAlreadyTakenException {
      _showSnack('이미 사용 중인 유저네임입니다.');
    } on FirebaseAuthException catch (e) {
      _showSnack(_firebaseErrorMessage(e));
    } catch (_) {
      _showSnack('회원가입 중 오류가 발생했습니다.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _firebaseErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return '이미 사용 중인 이메일입니다.';
      case 'invalid-email':
        return '이메일 형식이 올바르지 않습니다.';
      case 'weak-password':
        return '비밀번호가 너무 약합니다.';
      default:
        return e.message ?? '회원가입에 실패했습니다.';
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = _leagueItSurfacePalette(context);
    final emailMessage = _emailValidationMessage(_emailController.text);
    final emailState = _inlineFieldState(
      emailMessage,
      _emailController.text.trim(),
    );
    final passwordMessage = _passwordValidationMessage(_passwordController.text);
    final passwordState = _inlineFieldState(
      passwordMessage,
      _passwordController.text,
    );
    final confirmMessage = _confirmPasswordValidationMessage(
      _confirmController.text,
    );
    final confirmState = _inlineFieldState(
      confirmMessage,
      _confirmController.text,
    );

    return Scaffold(
      backgroundColor: palette.pageBackground,
      appBar: AppBar(
        backgroundColor: palette.pageBackground,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          '회원가입',
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
                        'WELCOME',
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
                      controller: _usernameController,
                      label: '유저네임',
                      hintText: '2자 이상, 특수 문자 X',
                      prefixIcon: Icons.person_outline_rounded,
                      textInputAction: TextInputAction.next,
                      fillColor: palette.fieldFill,
                      borderColor: _usernameBorderColor(),
                      focusedBorderColor: _usernameBorderColor(),
                      helperText: _usernameMessage,
                      helperColor: _usernameMessageColor(),
                      suffixIcon: _usernameStatusIcon(),
                      onChanged: _handleUsernameChanged,
                    ),
                    const SizedBox(height: 14),
                    _SignUpInputField(
                      controller: _emailController,
                      label: '이메일',
                      hintText: 'name@example.com',
                      keyboardType: TextInputType.emailAddress,
                      prefixIcon: Icons.alternate_email_rounded,
                      textInputAction: TextInputAction.next,
                      fillColor: palette.fieldFill,
                      onChanged: (_) => setState(() {}),
                      borderColor: _inlineFieldBorderColor(emailState),
                      focusedBorderColor: _inlineFieldBorderColor(emailState),
                      helperText: emailMessage,
                      helperColor: _inlineFieldHelperColor(emailState),
                      suffixIcon: _inlineFieldStatusIcon(emailState),
                    ),
                    const SizedBox(height: 14),
                    _SignUpInputField(
                      controller: _passwordController,
                      label: '비밀번호',
                      hintText: '영문/숫자/특수문자 6자 이상',
                      obscureText: true,
                      prefixIcon: Icons.lock_outline_rounded,
                      textInputAction: TextInputAction.next,
                      fillColor: palette.fieldFill,
                      keyboardType: TextInputType.visiblePassword,
                      inputFormatters: <TextInputFormatter>[
                        _passwordAsciiInputFormatter,
                      ],
                      onChanged: (_) => setState(() {}),
                      borderColor: _inlineFieldBorderColor(passwordState),
                      focusedBorderColor: _inlineFieldBorderColor(passwordState),
                      helperText: passwordMessage,
                      helperColor: _inlineFieldHelperColor(passwordState),
                      suffixIcon: _inlineFieldStatusIcon(passwordState),
                    ),
                    const SizedBox(height: 14),
                    _SignUpInputField(
                      controller: _confirmController,
                      label: '비밀번호 확인',
                      hintText: '비밀번호를 다시 입력',
                      obscureText: true,
                      prefixIcon: Icons.verified_user_outlined,
                      textInputAction: TextInputAction.done,
                      keyboardType: TextInputType.visiblePassword,
                      inputFormatters: <TextInputFormatter>[
                        _passwordAsciiInputFormatter,
                      ],
                      onSubmitted: (_) {
                        if (!_submitting) {
                          unawaited(_signUp());
                        }
                      },
                      onChanged: (_) => setState(() {}),
                      fillColor: palette.fieldFill,
                      borderColor: _inlineFieldBorderColor(confirmState),
                      focusedBorderColor: _inlineFieldBorderColor(confirmState),
                      helperText: confirmMessage,
                      helperColor: _inlineFieldHelperColor(confirmState),
                      suffixIcon: _inlineFieldStatusIcon(confirmState),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _submitting ? null : _signUp,
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
                                '회원가입',
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
                  '이미 계정이 있으면 뒤로 돌아가 로그인하세요.',
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

class _SignUpInputField extends StatelessWidget {
  const _SignUpInputField({
    required this.controller,
    required this.label,
    required this.hintText,
    required this.prefixIcon,
    required this.fillColor,
    this.focusNode,
    this.enabled = true,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.onSubmitted,
    this.inputFormatters,
    this.onChanged,
    this.borderColor,
    this.focusedBorderColor,
    this.helperText,
    this.helperColor,
    this.suffixIcon,
  });

  final TextEditingController controller;
  final String label;
  final String hintText;
  final IconData prefixIcon;
  final Color fillColor;
  final FocusNode? focusNode;
  final bool enabled;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final ValueChanged<String>? onSubmitted;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final Color? borderColor;
  final Color? focusedBorderColor;
  final String? helperText;
  final Color? helperColor;
  final Widget? suffixIcon;

  @override
  Widget build(BuildContext context) {
    final palette = _leagueItSurfacePalette(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: palette.ink,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          focusNode: focusNode,
          enabled: enabled,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          obscureText: obscureText,
          autocorrect: false,
          enableSuggestions: false,
          onSubmitted: onSubmitted,
          onChanged: onChanged,
          inputFormatters: inputFormatters,
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(color: palette.mutedInk),
            helperText: helperText,
            helperMaxLines: 2,
            helperStyle: TextStyle(
              color: helperColor ?? palette.mutedInk,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
            filled: true,
            fillColor: fillColor,
            prefixIcon: Icon(prefixIcon, color: palette.mutedInk),
            suffixIcon: suffixIcon == null
                ? null
                : Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: suffixIcon,
                  ),
            suffixIconConstraints: const BoxConstraints(
              minWidth: 24,
              minHeight: 24,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 18,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(
                color: borderColor ?? palette.cardBorder,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(
                color: focusedBorderColor ?? palette.accent,
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
