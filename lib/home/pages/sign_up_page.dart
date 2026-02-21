part of '../home_page.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmController.text;

    if (email.isEmpty || password.isEmpty || confirm.isEmpty) {
      _showSnack('모든 항목을 입력해 주세요.');
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
      await authController.signUpWithEmail(email: email, password: password);
      // 요구사항: 가입 성공 후 다시 로그인하도록 즉시 로그아웃.
      await authController.signOut();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('회원가입 완료. 로그인해 주세요.')),
      );
      Navigator.pop(context);
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
    return Scaffold(
      appBar: AppBar(title: const Text('회원가입')),
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
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _confirmController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm password',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _signUp,
                  child: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('회원가입'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
