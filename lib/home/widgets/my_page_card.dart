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
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 260,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 18,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "My Page",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 18),

            if (!isLoggedIn) ...[
              _MyPageItem(
                "Log in",
                onTap: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginPage()),
                  );
                  if (result == true) {
                    onLogin();
                  }
                },
              ),
              _MyPageItem(
                "Create account",
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SignUpPage()),
                  );
                },
              ),
            ] else ...[
              _MyPageItem(
                "Profile",
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ProfilePage()),
                  );
                },
              ),
              _MyPageItem(
                "My League",
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MyLeaguePage()),
                  );
                },
              ),
              _MyPageItem(
                "Password",
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PasswordPage()),
                  );
                },
              ),
              const Divider(height: 22),
              _MyPageItem("Log out", isDanger: true, onTap: onLogout),
            ],
          ],
        ),
      ),
    );
  }
}

class _MyPageItem extends StatelessWidget {
  final String title;
  final VoidCallback onTap;
  final bool isDanger;

  const _MyPageItem(this.title, {required this.onTap, this.isDanger = false});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 16,
            color: isDanger ? Colors.red : Colors.black87,
            fontWeight: isDanger ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
