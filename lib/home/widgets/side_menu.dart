part of '../home_page.dart';

class SideMenu extends StatelessWidget {
  final double width;
  const SideMenu({super.key, required this.width});

  @override
  Widget build(BuildContext context) {
    final Color fg = Theme.of(context).colorScheme.onSurface;
    final Color bg = Theme.of(context).scaffoldBackgroundColor;

    return Material(
      color: Colors.transparent,
      child: Container(
        width: width,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.only(
            topRight: Radius.circular(26),
            bottomRight: Radius.circular(26),
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black38,
              blurRadius: 14,
              offset: Offset(6, 0),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Image.asset(
                  'assets/leagueit_logo.png',
                  width: 26,
                  height: 26,
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.error),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "LeagueIt",
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                      color: fg,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),

            _MenuItem(
              "About Us",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AboutPage()),
                );
              },
            ),
            const SizedBox(height: 22),

            _MenuItem(
              "PlayBook",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PlaybookPage()),
                );
              },
            ),
            const SizedBox(height: 22),

            _MenuItem(
              "Privacy Policy",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PrivacyPolicyPage()),
                );
              },
            ),
            const SizedBox(height: 22),

            _MenuItem(
              "FAQs",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const FAQPage()),
                );
              },
            ),
            const SizedBox(height: 22),

            _MenuItem(
              "Settings",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsPage()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final String title;
  final VoidCallback onTap;

  const _MenuItem(this.title, {required this.onTap});

  @override
  Widget build(BuildContext context) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: title,
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w500,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout();

    final double textWidth = textPainter.width;

    return InkWell(
      onTap: onTap,
      child: Stack(
        alignment: Alignment.bottomLeft,
        children: [
          Positioned(
            bottom: 0,
            child: Container(
              width: textWidth,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF00BC13).withOpacity(0.25),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(
              title,
              softWrap: false,
              overflow: TextOverflow.visible,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w500,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
