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

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loginWithEmail() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      _showSnack('이메일과 비밀번호를 입력해 주세요.');
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Log in")),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: "Email",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: "Password",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _loginWithEmail,
                  child: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text("Log in"),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  onPressed: _submitting ? null : _loginWithGoogle,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.black87,
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFFDADCE0)),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image(
                        image: AssetImage('assets/google_logo.png'),
                        width: 20,
                        height: 20,
                      ),
                      SizedBox(width: 12),
                      Text(
                        "Google로 로그인",
                        style: TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Row(
                children: [
                  Expanded(child: Divider()),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text('또는'),
                  ),
                  Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _submitting
                    ? null
                    : () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const SignUpPage()),
                        );
                      },
                child: const Text("회원가입"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
