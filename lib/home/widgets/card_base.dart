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
    final Color accent = isSoccer
        ? const Color(0xFF00A86B)
        : const Color(0xFF7CB342);
    const double headerH = 80;
    const double borderW = 2;
    const double outerRadius = 18;
    const double innerRadius = outerRadius - borderW;
    final double headerInnerH = headerH - borderW;
    final Color headerTop = Color.lerp(accent, Colors.white, 0.06)!;
    final Color headerBottom = Color.lerp(accent, Colors.black, 0.12)!;
    final IconData cornerSportIcon = isSoccer
        ? Icons.sports_soccer
        : Icons.sports_baseball;
    final Color cornerSportColor = (isDark ? Colors.white : Colors.black)
        .withOpacity(isDark ? 0.10 : 0.08);

    return Container(
      width: double.infinity,
      height: double.infinity,
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
            child: Icon(cornerSportIcon, size: 210, color: cornerSportColor),
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
  final _FantasyMatchupView? matchup;

  const MatchupCard({
    super.key,
    required this.isSoccer,
    required this.onStart,
    this.matchup,
  });

  @override
  Widget build(BuildContext context) {
    final mediaSize = MediaQuery.sizeOf(context);
    final bool isTabletLayout = mediaSize.shortestSide >= 700;
    final String leagueLabel =
        (matchup?.draft.leagueName.trim().isNotEmpty == true)
        ? matchup!.draft.leagueName.trim()
        : (isSoccer ? 'K League' : 'KBO');
    final IconData leagueIcon = isSoccer
        ? Icons.sports_soccer
        : Icons.sports_baseball;
    final String homeLabel = matchup?.myTeam.teamName ?? 'You';
    final String awayLabel = matchup?.opponent.teamName ?? 'Opponent';
    final String homeUid = matchup?.myTeam.uid ?? '';
    final String awayUid = matchup?.opponent.uid ?? '';
    final String roundLabel = matchup == null
        ? '이번 주'
        : '${matchup!.round} 라운드';
    final bool animateScoreChanges =
        matchup != null && _fantasyMatchupHasLiveOfficialGames(matchup!);
    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color bg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final Color stroke = isDark ? Colors.white70 : Colors.black87;
    // Slightly different greens per league (K League vs KBO).
    final Color accent = isSoccer
        ? const Color(0xFF00A86B)
        : const Color(0xFF7CB342);
    const double headerH = 56;
    const double borderW = 2;
    const double outerRadius = 18;
    const double innerRadius = outerRadius - borderW;
    final double headerInnerH = headerH - borderW;
    final Color headerTop = Color.lerp(accent, Colors.white, 0.06)!;
    final Color headerBottom = Color.lerp(accent, Colors.black, 0.12)!;
    final double teamAvatarSize = isTabletLayout ? 96 : 70;
    final double teamIconSize = isTabletLayout ? 36 : 28;
    final double teamLabelSize = isTabletLayout ? 16 : 13;
    final double scoreFontSize = isTabletLayout ? 24 : 16;

    return InkWell(
      onTap: onStart,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: double.infinity,
        height: double.infinity,
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
                          '$leagueLabel · $roundLabel',
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
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: _TeamBadge(
                          uid: homeUid,
                          teamName: homeLabel,
                          label: homeLabel,
                          avatarSize: teamAvatarSize,
                          iconSize: teamIconSize,
                          labelSize: teamLabelSize,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: matchup == null
                              ? Text(
                                  'vs',
                                  style: TextStyle(
                                    fontSize: scoreFontSize,
                                    fontWeight: FontWeight.w700,
                                    color: stroke,
                                  ),
                                )
                              : matchup!.scoresReady
                              ? _AnimatedFantasyScorePair(
                                  scoreIdentity:
                                      '${matchup!.draft.leagueId}|${matchup!.round}|home-card',
                                  homeScore: matchup!.myScore,
                                  awayScore: matchup!.opponentScore,
                                  fractionDigits: 1,
                                  animateChanges: animateScoreChanges,
                                  baseColor: stroke,
                                  separator: 'vs',
                                  scoreStyle: TextStyle(
                                    fontSize: scoreFontSize,
                                    fontWeight: FontWeight.w700,
                                    color: stroke,
                                  ),
                                  separatorStyle: TextStyle(
                                    fontSize: scoreFontSize,
                                    fontWeight: FontWeight.w700,
                                    color: stroke,
                                  ),
                                )
                              : Text(
                                  '준비 중',
                                  style: TextStyle(
                                    fontSize: scoreFontSize,
                                    fontWeight: FontWeight.w700,
                                    color: stroke,
                                  ),
                                ),
                        ),
                      ),
                      Expanded(
                        child: _TeamBadge(
                          uid: awayUid,
                          teamName: awayLabel,
                          label: awayLabel,
                          avatarSize: teamAvatarSize,
                          iconSize: teamIconSize,
                          labelSize: teamLabelSize,
                        ),
                      ),
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
  final String? uid;
  final String? teamName;
  final String label;
  final IconData? icon;
  final Color? fillColor;
  final Color? iconColor;
  final double avatarSize;
  final double iconSize;
  final double labelSize;

  const _TeamBadge({
    this.uid,
    this.teamName,
    required this.label,
    this.icon,
    this.fillColor,
    this.iconColor,
    this.avatarSize = 70,
    this.iconSize = 28,
    this.labelSize = 13,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color bg = theme.cardColor;
    final Color stroke = theme.colorScheme.onSurface;
    final normalizedUid = uid?.trim() ?? '';
    final normalizedTeamName = teamName?.trim() ?? '';
    final bool useFantasyAvatar =
        normalizedUid.isNotEmpty && normalizedTeamName.isNotEmpty;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (useFantasyAvatar)
          _FantasyTeamAvatar(
            uid: normalizedUid,
            teamName: normalizedTeamName,
            size: avatarSize,
            iconSize: iconSize,
          )
        else
          Container(
            width: avatarSize,
            height: avatarSize,
            decoration: BoxDecoration(
              color: fillColor ?? bg.withOpacity(0.7),
              shape: BoxShape.circle,
              border: Border.all(color: stroke.withOpacity(0.3)),
            ),
            child: Center(
              child: Icon(
                icon ?? Icons.shield_outlined,
                size: iconSize,
                color: iconColor ?? stroke.withOpacity(0.7),
              ),
            ),
          ),
        const SizedBox(height: 6),
        Text(
          label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: labelSize,
            color: stroke,
          ),
        ),
      ],
    );
  }
}
