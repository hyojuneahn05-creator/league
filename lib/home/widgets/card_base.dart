part of '../home_page.dart';

class CardBase extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isSoccer;
  final VoidCallback onStart;

  const CardBase({
    super.key,
    required this.title,
    required this.subtitle,
    required this.isSoccer,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color bg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final Color stroke = isDark ? Colors.white70 : Colors.black87;
    // Slightly different greens per league (K League vs KBO).
    final Color accent =
        isSoccer ? const Color(0xFF00A86B) : const Color(0xFF7CB342);
    const double headerH = 80;
    const double borderW = 2;
    const double outerRadius = 18;
    const double innerRadius = outerRadius - borderW;
    final double headerInnerH = headerH - borderW;
    final Color headerTop = Color.lerp(accent, Colors.white, 0.06)!;
    final Color headerBottom = Color.lerp(accent, Colors.black, 0.12)!;
    final IconData cornerSportIcon =
        isSoccer ? Icons.sports_soccer : Icons.sports_baseball;
    final Color cornerSportColor = (isDark ? Colors.white : Colors.black)
        .withOpacity(isDark ? 0.10 : 0.08);

    return Container(
      width: 360,
      height: 200,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        boxShadow: isDark
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.35),
                  offset: const Offset(0, 10),
                  blurRadius: 18,
                ),
              ]
            : const [
                BoxShadow(
                  color: Colors.black12,
                  offset: Offset(0, 8),
                  blurRadius: 12,
                ),
              ],
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: stroke.withOpacity(isDark ? 0.3 : 0.8),
          width: 2,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            left: borderW,
            right: borderW,
            top: borderW,
            height: headerInnerH,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [headerTop, headerBottom],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(innerRadius),
                ),
              ),
            ),
          ),
          // Quarter-visible sport icon in the bottom-left corner (like the reference sketch).
          Positioned(
            left: -72,
            bottom: -78,
            child: Icon(
              cornerSportIcon,
              size: 210,
              color: cornerSportColor,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                Align(
                  alignment: Alignment.bottomRight,
                  child: GestureDetector(
                    onTap: onStart,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: accent,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.10),
                            blurRadius: 10,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Text(
                        'Start',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class MatchupCard extends StatelessWidget {
  final bool isSoccer;
  final VoidCallback onStart;

  const MatchupCard({super.key, required this.isSoccer, required this.onStart});

  @override
  Widget build(BuildContext context) {
    final String leagueLabel = isSoccer ? 'K League' : 'KBO';
    final IconData leagueIcon = isSoccer
        ? Icons.sports_soccer
        : Icons.sports_baseball;
    final String homeEmoji = isSoccer ? '🦊' : '🦁';
    final String awayEmoji = isSoccer ? '🐻' : '🐯';
    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color bg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final Color stroke = isDark ? Colors.white70 : Colors.black87;
    // Slightly different greens per league (K League vs KBO).
    final Color accent =
        isSoccer ? const Color(0xFF00A86B) : const Color(0xFF7CB342);
    const double headerH = 56;
    const double borderW = 2;
    const double outerRadius = 18;
    const double innerRadius = outerRadius - borderW;
    final double headerInnerH = headerH - borderW;
    final Color headerTop = Color.lerp(accent, Colors.white, 0.06)!;
    final Color headerBottom = Color.lerp(accent, Colors.black, 0.12)!;

    return InkWell(
      onTap: onStart,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 360,
        height: 200,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(18),
          boxShadow: isDark
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.35),
                    offset: const Offset(0, 10),
                    blurRadius: 18,
                  ),
                ]
              : const [
                  BoxShadow(
                    color: Colors.black12,
                    offset: Offset(0, 8),
                    blurRadius: 12,
                  ),
                ],
        ),
        foregroundDecoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: stroke.withOpacity(isDark ? 0.3 : 0.8),
            width: 2,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              left: borderW,
              right: borderW,
              top: borderW,
              height: headerInnerH,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [headerTop, headerBottom],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(innerRadius),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(leagueIcon, color: Colors.white, size: 18),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '$leagueLabel · This Week',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _TeamBadge(emoji: homeEmoji, label: 'You'),
                      Text(
                        'vs',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: stroke,
                        ),
                      ),
                      _TeamBadge(emoji: awayEmoji, label: 'Alex'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TeamBadge extends StatelessWidget {
  final String emoji;
  final String label;

  const _TeamBadge({required this.emoji, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color bg = theme.cardColor;
    final Color stroke = theme.colorScheme.onSurface;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            color: bg.withOpacity(0.7),
            shape: BoxShape.circle,
            border: Border.all(color: stroke.withOpacity(0.3)),
          ),
          child: Center(
            child: Text(emoji, style: const TextStyle(fontSize: 32)),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: stroke,
          ),
        ),
      ],
    );
  }
}
