part of '../home_page.dart';

class PasswordPage extends StatefulWidget {
  const PasswordPage({super.key});

  @override
  State<PasswordPage> createState() => _PasswordPageState();
}

class _PasswordPageState extends State<PasswordPage> {
  bool _isMyPageOpen = false;
  void _toggleMyPage() => setState(() => _isMyPageOpen = !_isMyPageOpen);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusScope.of(context).unfocus(),
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            appBar: LeagueItSubAppBar(
              onMyPageTap: _toggleMyPage,
              showSearch: false,
            ),
            body: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  '비밀번호 변경',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 20),
                const _PwdField(label: '현재 비밀번호'),
                const _PwdField(label: '새 비밀번호'),
                const _PwdField(label: '새 비밀번호 확인'),
                const SizedBox(height: 12),
                _StrengthMeter(strength: 0.6, label: '보통'),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: const Text('변경하기'),
                ),
              ],
            ),
          ),
          if (_isMyPageOpen)
            GestureDetector(
              onTap: _toggleMyPage,
              child: Container(color: Colors.black.withOpacity(0.35)),
            ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutBack,
            top: _isMyPageOpen ? 100 : 20,
            right: _isMyPageOpen ? 24 : 12,
            child: AnimatedScale(
              duration: const Duration(milliseconds: 400),
              scale: _isMyPageOpen ? 1.0 : 0.2,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 250),
                opacity: _isMyPageOpen ? 1 : 0,
                child: MyPageCard(
                  isLoggedIn: homeKey.currentState?.isLoggedIn ?? false,
                  onLogin: () {
                    homeKey.currentState?.updateLogin(true);
                    Navigator.pop(context);
                  },
                  onLogout: () {
                    homeKey.currentState?.updateLogin(false);
                    homeKey.currentState?.closePanels();
                    Navigator.pop(context);
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PwdField extends StatelessWidget {
  final String label;
  const _PwdField({required this.label});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        obscureText: true,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}

class _StrengthMeter extends StatelessWidget {
  final double strength; // 0~1
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
          style: TextStyle(color: cs.onSurface.withOpacity(0.7)),
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: strength,
            minHeight: 10,
            backgroundColor: cs.onSurface.withOpacity(0.1),
            valueColor: AlwaysStoppedAnimation(cs.primary),
          ),
        ),
      ],
    );
  }
}
