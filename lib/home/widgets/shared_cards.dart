part of '../home_page.dart';

enum _StandingsTableMode { compact, detail }

class _SoccerStandingsRow {
  final String team;
  final int played;
  final int wins;
  final int draws;
  final int losses;
  final int goalsFor;
  final int goalsAgainst;
  final int points;

  const _SoccerStandingsRow({
    required this.team,
    required this.played,
    required this.wins,
    required this.draws,
    required this.losses,
    required this.goalsFor,
    required this.goalsAgainst,
    required this.points,
  });

  int get goalDiff => goalsFor - goalsAgainst;
}

class _BaseballStandingsRow {
  final String team;
  final int played;
  final int wins;
  final int draws;
  final int losses;
  final double gamesBehind;
  final String streak; // e.g. W3 / L2

  const _BaseballStandingsRow({
    required this.team,
    required this.played,
    required this.wins,
    required this.draws,
    required this.losses,
    required this.gamesBehind,
    required this.streak,
  });

  double get winPct {
    final denom = wins + losses;
    if (denom <= 0) return 0.0;
    return wins / denom;
  }
}

List<_SoccerStandingsRow> _soccerStandingsRows() {
  final rows = <_SoccerStandingsRow>[
    const _SoccerStandingsRow(
      team: '부천FC 1995',
      played: 23,
      wins: 16,
      draws: 4,
      losses: 3,
      goalsFor: 39,
      goalsAgainst: 18,
      points: 52,
    ),
    const _SoccerStandingsRow(
      team: '대전 하나 시티즌',
      played: 23,
      wins: 15,
      draws: 4,
      losses: 4,
      goalsFor: 36,
      goalsAgainst: 20,
      points: 49,
    ),
    const _SoccerStandingsRow(
      team: 'FC 안양',
      played: 23,
      wins: 14,
      draws: 4,
      losses: 5,
      goalsFor: 33,
      goalsAgainst: 22,
      points: 46,
    ),
    const _SoccerStandingsRow(
      team: 'FC 서울',
      played: 23,
      wins: 13,
      draws: 5,
      losses: 5,
      goalsFor: 31,
      goalsAgainst: 23,
      points: 44,
    ),
    const _SoccerStandingsRow(
      team: '강원 FC',
      played: 23,
      wins: 12,
      draws: 5,
      losses: 6,
      goalsFor: 29,
      goalsAgainst: 24,
      points: 41,
    ),
    const _SoccerStandingsRow(
      team: '김천 상무',
      played: 23,
      wins: 11,
      draws: 6,
      losses: 6,
      goalsFor: 28,
      goalsAgainst: 25,
      points: 39,
    ),
    const _SoccerStandingsRow(
      team: '광주 FC',
      played: 23,
      wins: 10,
      draws: 6,
      losses: 7,
      goalsFor: 27,
      goalsAgainst: 27,
      points: 36,
    ),
    const _SoccerStandingsRow(
      team: '인천 유나이티드',
      played: 23,
      wins: 9,
      draws: 7,
      losses: 7,
      goalsFor: 25,
      goalsAgainst: 28,
      points: 34,
    ),
    const _SoccerStandingsRow(
      team: '제주 SK',
      played: 23,
      wins: 9,
      draws: 5,
      losses: 9,
      goalsFor: 24,
      goalsAgainst: 29,
      points: 32,
    ),
    const _SoccerStandingsRow(
      team: '전북 현대',
      played: 23,
      wins: 8,
      draws: 6,
      losses: 9,
      goalsFor: 23,
      goalsAgainst: 30,
      points: 30,
    ),
    const _SoccerStandingsRow(
      team: '포항 스틸러스',
      played: 23,
      wins: 8,
      draws: 4,
      losses: 11,
      goalsFor: 22,
      goalsAgainst: 32,
      points: 28,
    ),
    const _SoccerStandingsRow(
      team: '울산 HD',
      played: 23,
      wins: 7,
      draws: 5,
      losses: 11,
      goalsFor: 21,
      goalsAgainst: 34,
      points: 26,
    ),
  ];
  rows.sort((a, b) {
    final p = b.points.compareTo(a.points);
    if (p != 0) return p;
    final gd = b.goalDiff.compareTo(a.goalDiff);
    if (gd != 0) return gd;
    return a.team.compareTo(b.team);
  });
  return rows;
}

List<_BaseballStandingsRow> _baseballStandingsRows() {
  final rows = <_BaseballStandingsRow>[
    const _BaseballStandingsRow(
      team: 'LG',
      played: 40,
      wins: 26,
      draws: 1,
      losses: 13,
      gamesBehind: 0.0,
      streak: 'W3',
    ),
    const _BaseballStandingsRow(
      team: '한화',
      played: 40,
      wins: 24,
      draws: 1,
      losses: 15,
      gamesBehind: 2.0,
      streak: 'W1',
    ),
    const _BaseballStandingsRow(
      team: 'SSG',
      played: 40,
      wins: 23,
      draws: 0,
      losses: 17,
      gamesBehind: 3.5,
      streak: 'L1',
    ),
    const _BaseballStandingsRow(
      team: '삼성',
      played: 40,
      wins: 22,
      draws: 1,
      losses: 17,
      gamesBehind: 4.0,
      streak: 'W2',
    ),
    const _BaseballStandingsRow(
      team: 'NC',
      played: 40,
      wins: 21,
      draws: 1,
      losses: 18,
      gamesBehind: 5.0,
      streak: 'W1',
    ),
    const _BaseballStandingsRow(
      team: 'KT',
      played: 40,
      wins: 20,
      draws: 0,
      losses: 20,
      gamesBehind: 6.5,
      streak: 'L2',
    ),
    const _BaseballStandingsRow(
      team: '롯데',
      played: 40,
      wins: 19,
      draws: 1,
      losses: 20,
      gamesBehind: 7.0,
      streak: 'W1',
    ),
    const _BaseballStandingsRow(
      team: '두산',
      played: 40,
      wins: 18,
      draws: 0,
      losses: 22,
      gamesBehind: 8.5,
      streak: 'L1',
    ),
    const _BaseballStandingsRow(
      team: 'KIA',
      played: 40,
      wins: 17,
      draws: 0,
      losses: 23,
      gamesBehind: 9.5,
      streak: 'W1',
    ),
    const _BaseballStandingsRow(
      team: '키움',
      played: 40,
      wins: 15,
      draws: 0,
      losses: 25,
      gamesBehind: 11.5,
      streak: 'L3',
    ),
  ];
  rows.sort((a, b) {
    final p = b.winPct.compareTo(a.winPct);
    if (p != 0) return p;
    final gb = a.gamesBehind.compareTo(b.gamesBehind);
    if (gb != 0) return gb;
    return a.team.compareTo(b.team);
  });
  return rows;
}

class _SoccerStandingsTable extends StatelessWidget {
  final List<_SoccerStandingsRow> rows;
  final _StandingsTableMode mode;
  final ValueChanged<String>? onTeamTap;

  const _SoccerStandingsTable({
    required this.rows,
    required this.mode,
    this.onTeamTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final Color border = isDark ? Colors.white12 : Colors.black12;
    final Color headerBg = isDark
        ? Colors.white.withOpacity(0.06)
        : Colors.black.withOpacity(0.03);

    const double colPlayed = 44;
    const double colGD = 48;
    const double colPts = 52;

    String fmtSigned(int v) => v >= 0 ? '+$v' : '$v';

    Widget statChip(String label, String value) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isDark ? Colors.white10 : Colors.black.withOpacity(0.04),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: border),
        ),
        child: Text(
          '$label $value',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white70 : Colors.black87,
          ),
        ),
      );
    }

    Widget header() {
      if (mode == _StandingsTableMode.compact) {
        return Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          color: headerBg,
          child: Row(
            children: const [
              SizedBox(width: 26 + 12),
              Expanded(
                child: Text(
                  '팀',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                ),
              ),
              SizedBox(
                width: colPlayed,
                child: Text(
                  '경기수',
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ),
              SizedBox(
                width: colGD,
                child: Text(
                  '득실',
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ),
              SizedBox(
                width: colPts,
                child: Text(
                  '승점',
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        );
      }

      // Detail mode header: table-like columns (no horizontal scroll).
      return Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        color: headerBg,
        child: Row(
          children: const [
            SizedBox(width: 22), // #
            SizedBox(width: 24), // logo placeholder
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Team',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
              ),
            ),
            SizedBox(
              width: 26,
              child: Text(
                'PL',
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ),
            SizedBox(
              width: 22,
              child: Text(
                'W',
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ),
            SizedBox(
              width: 22,
              child: Text(
                'D',
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ),
            SizedBox(
              width: 22,
              child: Text(
                'L',
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ),
            SizedBox(
              width: 46,
              child: Text(
                '+/-',
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ),
            SizedBox(
              width: 30,
              child: Text(
                'GD',
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ),
            SizedBox(
              width: 34,
              child: Text(
                'PTS',
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      );
    }

    Widget rowCompact(int index) {
      final r = rows[index];
      final rank = index + 1;
      final Color rankBg = isDark ? Colors.white10 : Colors.black12;
      final child = SizedBox(
        height: 58, // more breathing room; allows 2-line team names
        child: Row(
          children: [
            const SizedBox(width: 12),
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: rankBg, shape: BoxShape.circle),
              child: Text(
                '$rank',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                r.team,
                maxLines: 2,
                softWrap: true,
                overflow: TextOverflow.clip,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.15,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
            SizedBox(
              width: colPlayed,
              child: Text(
                '${r.played}',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white70 : Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            SizedBox(
              width: colGD,
              child: Text(
                fmtSigned(r.goalDiff),
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 12,
                  color: r.goalDiff >= 0
                      ? (isDark
                            ? Colors.lightGreenAccent
                            : Colors.green.shade800)
                      : (isDark ? Colors.orangeAccent : Colors.deepOrange),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            SizedBox(
              width: colPts,
              child: Text(
                '${r.points}',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
        ),
      );

      if (onTeamTap == null) return child;
      return Material(
        color: Colors.transparent,
        child: InkWell(onTap: () => onTeamTap!(r.team), child: child),
      );
    }

    Widget rowDetail(int index) {
      final r = rows[index];
      final rank = index + 1;
      final Color stripe = rank <= 6
          ? const Color(0xFF4FB6FF) // sky blue
          : const Color(0xFFFF4B4B); // red
      final Color logoBg = isDark ? Colors.white10 : Colors.black12;

      final child = Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: stripe, width: 4)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 22,
              child: Text(
                '$rank',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
            ),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: logoBg,
                shape: BoxShape.circle,
                border: Border.all(color: border),
              ),
              child: Icon(
                Icons.sports_soccer,
                size: 14,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                r.team,
                maxLines: 2,
                softWrap: true,
                overflow: TextOverflow.clip,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.15,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
            SizedBox(
              width: 26,
              child: Text(
                '${r.played}',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white70 : Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            SizedBox(
              width: 22,
              child: Text(
                '${r.wins}',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white70 : Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            SizedBox(
              width: 22,
              child: Text(
                '${r.draws}',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white70 : Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            SizedBox(
              width: 22,
              child: Text(
                '${r.losses}',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white70 : Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            SizedBox(
              width: 46,
              child: Text(
                '${r.goalsFor}-${r.goalsAgainst}',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white70 : Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            SizedBox(
              width: 30,
              child: Text(
                fmtSigned(r.goalDiff),
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 12,
                  color: r.goalDiff >= 0
                      ? (isDark
                            ? Colors.lightGreenAccent
                            : Colors.green.shade800)
                      : (isDark ? Colors.orangeAccent : Colors.deepOrange),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            SizedBox(
              width: 34,
              child: Text(
                '${r.points}',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ),
          ],
        ),
      );

      if (onTeamTap == null) return child;
      return Material(
        color: Colors.transparent,
        child: InkWell(onTap: () => onTeamTap!(r.team), child: child),
      );
    }

    final content = ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: border),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            header(),
            ...List.generate(rows.length, (i) {
              final row = mode == _StandingsTableMode.compact
                  ? rowCompact(i)
                  : rowDetail(i);
              if (i == rows.length - 1) return row;
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  row,
                  Divider(height: 1, color: border),
                ],
              );
            }),
          ],
        ),
      ),
    );

    // In detail mode, this is designed to fit without horizontal scrolling.
    return content;
  }
}

class _BaseballStandingsTable extends StatelessWidget {
  final List<_BaseballStandingsRow> rows;
  final _StandingsTableMode mode;
  final ValueChanged<String>? onTeamTap;

  const _BaseballStandingsTable({
    required this.rows,
    required this.mode,
    this.onTeamTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final Color border = isDark ? Colors.white12 : Colors.black12;
    final Color headerBg = isDark
        ? Colors.white.withOpacity(0.06)
        : Colors.black.withOpacity(0.03);

    const double colPlayed = 44;
    const double colPct = 56;
    const double colGB = 56;
    const double colStreak = 56;

    Widget statChip(String label, String value) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isDark ? Colors.white10 : Colors.black.withOpacity(0.04),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: border),
        ),
        child: Text(
          '$label $value',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white70 : Colors.black87,
          ),
        ),
      );
    }

    String fmtPct(double v) {
      final s = v.toStringAsFixed(3);
      return s.startsWith('0') ? s.substring(1) : s;
    }

    String fmtGb(double v) => v == v.roundToDouble()
        ? v.toStringAsFixed(1).replaceFirst('.0', '')
        : v.toStringAsFixed(1);

    Widget header() {
      if (mode == _StandingsTableMode.compact) {
        return Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          color: headerBg,
          child: Row(
            children: const [
              SizedBox(width: 26 + 12),
              Expanded(
                child: Text(
                  '팀',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                ),
              ),
              SizedBox(
                width: colPlayed,
                child: Text(
                  '경기수',
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ),
              SizedBox(
                width: colPct,
                child: Text(
                  '승률',
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ),
              SizedBox(
                width: colGB,
                child: Text(
                  '게임차',
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        );
      }

      // Detail mode header: table-like columns (no horizontal scroll).
      return Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        color: headerBg,
        child: Row(
          children: const [
            SizedBox(width: 22), // #
            SizedBox(width: 24), // logo placeholder
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Team',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
              ),
            ),
            SizedBox(
              width: 28,
              child: Text(
                'PL',
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ),
            SizedBox(
              width: 24,
              child: Text(
                'W',
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ),
            SizedBox(
              width: 24,
              child: Text(
                'D',
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ),
            SizedBox(
              width: 24,
              child: Text(
                'L',
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ),
            SizedBox(
              width: 44,
              child: Text(
                'GB',
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ),
            SizedBox(
              width: 44,
              child: Text(
                'STR',
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      );
    }

    Widget rowCompact(int index) {
      final r = rows[index];
      final rank = index + 1;
      final Color rankBg = isDark ? Colors.white10 : Colors.black12;
      final child = SizedBox(
        height: 56,
        child: Row(
          children: [
            const SizedBox(width: 12),
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: rankBg, shape: BoxShape.circle),
              child: Text(
                '$rank',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                r.team,
                maxLines: 2,
                softWrap: true,
                overflow: TextOverflow.clip,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.15,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
            SizedBox(
              width: colPlayed,
              child: Text(
                '${r.played}',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white70 : Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            SizedBox(
              width: colPct,
              child: Text(
                fmtPct(r.winPct),
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white70 : Colors.black87,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            SizedBox(
              width: colGB,
              child: Text(
                fmtGb(r.gamesBehind),
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white70 : Colors.black87,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
        ),
      );
      if (onTeamTap == null) return child;
      return Material(
        color: Colors.transparent,
        child: InkWell(onTap: () => onTeamTap!(r.team), child: child),
      );
    }

    Widget rowDetail(int index) {
      final r = rows[index];
      final rank = index + 1;
      final Color logoBg = isDark ? Colors.white10 : Colors.black12;

      final child = Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Row(
          children: [
            SizedBox(
              width: 22,
              child: Text(
                '$rank',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
            ),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: logoBg,
                shape: BoxShape.circle,
                border: Border.all(color: border),
              ),
              child: Icon(
                Icons.sports_baseball,
                size: 14,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                r.team,
                maxLines: 2,
                softWrap: true,
                overflow: TextOverflow.clip,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.15,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
            SizedBox(
              width: 28,
              child: Text(
                '${r.played}',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white70 : Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            SizedBox(
              width: 24,
              child: Text(
                '${r.wins}',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white70 : Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            SizedBox(
              width: 24,
              child: Text(
                '${r.draws}',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white70 : Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            SizedBox(
              width: 24,
              child: Text(
                '${r.losses}',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white70 : Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            SizedBox(
              width: 44,
              child: Text(
                fmtGb(r.gamesBehind),
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white70 : Colors.black87,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            SizedBox(
              width: 44,
              child: Text(
                r.streak,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white70 : Colors.black87,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      );
      if (onTeamTap == null) return child;
      return Material(
        color: Colors.transparent,
        child: InkWell(onTap: () => onTeamTap!(r.team), child: child),
      );
    }

    final content = ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: border),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            header(),
            ...List.generate(rows.length, (i) {
              final row = mode == _StandingsTableMode.compact
                  ? rowCompact(i)
                  : rowDetail(i);
              if (i == rows.length - 1) return row;
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  row,
                  Divider(height: 1, color: border),
                ],
              );
            }),
          ],
        ),
      ),
    );

    return content;
  }
}

class _GradientCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _GradientCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFDCF8E8), Color(0xFFC6E8FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black12),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.green.shade400, width: 1.2),
            ),
            child: Icon(icon, size: 26, color: Colors.green.shade700),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 14, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFE4F7EA),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.green.shade300),
            ),
            child: Icon(icon, size: 18, color: Colors.green.shade800),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  body,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black87,
                    height: 1.5,
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

class _OverlayScaffold extends StatelessWidget {
  final bool isMyPageOpen;
  final VoidCallback onToggleMyPage;
  final Widget child;
  final String? title;
  final bool showSearch;

  const _OverlayScaffold({
    required this.isMyPageOpen,
    required this.onToggleMyPage,
    required this.child,
    this.title,
    this.showSearch = true,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusScope.of(context).unfocus(),
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: Colors.white,
            appBar: LeagueItSubAppBar(
              onMyPageTap: onToggleMyPage,
              title: title,
              showSearch: showSearch,
            ),
            body: child,
          ),
          // Dim background (animated) + popup.
          IgnorePointer(
            ignoring: !isMyPageOpen,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              opacity: isMyPageOpen ? 1 : 0,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onToggleMyPage,
                child: Container(color: Colors.black.withOpacity(0.35)),
              ),
            ),
          ),
          Positioned(
            top: 100,
            right: 24,
            child: IgnorePointer(
              ignoring: !isMyPageOpen,
              child: AnimatedSlide(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                offset: isMyPageOpen ? Offset.zero : const Offset(0.10, -0.06),
                child: AnimatedScale(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  scale: isMyPageOpen ? 1.0 : 0.96,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    opacity: isMyPageOpen ? 1 : 0,
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
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeStandingsCard extends StatelessWidget {
  final bool isSoccer;
  final Future<Map<String, dynamic>> leagueFuture;

  const _HomeStandingsCard({
    required this.isSoccer,
    required this.leagueFuture,
  });

  @override
  Widget build(BuildContext context) {
    if (!isSoccer) {
      return _buildCard(
        context,
        soccerRows: const <_SoccerStandingsRow>[],
        baseballRows: _baseballStandingsRows(),
      );
    }

    return FutureBuilder<Map<String, dynamic>>(
      future: leagueFuture,
      builder: (context, snapshot) {
        final rows = snapshot.hasData
            ? _soccerRowsFromApi(snapshot.data!['standings'] as List<dynamic>?)
            : _soccerPreseasonZeroRows();
        return _buildCard(
          context,
          soccerRows: rows,
          baseballRows: const <_BaseballStandingsRow>[],
        );
      },
    );
  }

  Widget _buildCard(
    BuildContext context, {
    required List<_SoccerStandingsRow> soccerRows,
    required List<_BaseballStandingsRow> baseballRows,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final Color surface = isDark
        ? const Color.fromARGB(255, 30, 30, 30)
        : theme.cardColor;
    final Color border = isDark ? Colors.white12 : Colors.black12;
    final Color headerChipBg = isDark
        ? Colors.white10
        : const Color(0xFFE4F7EA);

    final title = isSoccer ? 'K리그 순위표' : 'KBO 순위표';
    final subtitle = isSoccer ? 'K League' : 'KBO';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
        boxShadow: isDark
            ? const []
            : const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 10,
                  offset: Offset(0, 6),
                ),
              ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: headerChipBg,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: border),
                ),
                child: Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white70 : Colors.green.shade900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (isSoccer)
            _SoccerStandingsTable(
              rows: soccerRows,
              mode: _StandingsTableMode.compact,
            )
          else
            _BaseballStandingsTable(
              rows: baseballRows,
              mode: _StandingsTableMode.compact,
            ),
        ],
      ),
    );
  }
}

List<_SoccerStandingsRow> _soccerPreseasonZeroRows() {
  return _kLeagueTeams
      .map(
        (team) => _SoccerStandingsRow(
          team: team,
          played: 0,
          wins: 0,
          draws: 0,
          losses: 0,
          goalsFor: 0,
          goalsAgainst: 0,
          points: 0,
        ),
      )
      .toList();
}

List<_SoccerStandingsRow> _soccerRowsFromApi(List<dynamic>? standings) {
  final source = standings ?? const <dynamic>[];
  if (source.isEmpty) return _soccerPreseasonZeroRows();

  int readInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    if (value is double) return value.toInt();
    return 0;
  }

  final rows = <_SoccerStandingsRow>[];
  for (final raw in source) {
    final row = raw is Map<String, dynamic>
        ? raw
        : Map<String, dynamic>.from(raw as Map);
    final teamMap = (row['team'] as Map?)?.cast<String, dynamic>() ?? {};
    final allMap = (row['all'] as Map?)?.cast<String, dynamic>() ?? {};
    final goalsMap = (row['goals'] as Map?)?.cast<String, dynamic>() ?? {};
    rows.add(
      _SoccerStandingsRow(
        team: (teamMap['name'] as String?) ?? 'Unknown',
        played: readInt(allMap['played'] ?? row['played']),
        wins: readInt(allMap['win'] ?? row['win']),
        draws: readInt(allMap['draw'] ?? row['draw']),
        losses: readInt(allMap['lose'] ?? row['lose']),
        goalsFor: readInt(goalsMap['for'] ?? row['goalsFor']),
        goalsAgainst: readInt(goalsMap['against'] ?? row['goalsAgainst']),
        points: readInt(row['points'] ?? row['pts']),
      ),
    );
  }

  rows.sort((a, b) {
    final p = b.points.compareTo(a.points);
    if (p != 0) return p;
    final gd = b.goalDiff.compareTo(a.goalDiff);
    if (gd != 0) return gd;
    return a.team.compareTo(b.team);
  });
  return rows;
}

class _FixturePair {
  final String home;
  final String away;
  const _FixturePair({required this.home, required this.away});
}

// Deterministic round-robin pairing. UI mock until we plug real K League/KBO data.
List<_FixturePair> _buildRoundFixtures({
  required List<String> teams,
  required int roundNumber,
}) {
  if (teams.length < 2) return const [];
  final int n = teams.length;
  if (n.isOdd) {
    final even = List<String>.from(teams)..add('BYE');
    return _buildRoundFixtures(
      teams: even,
      roundNumber: roundNumber,
    ).where((m) => m.home != 'BYE' && m.away != 'BYE').toList();
  }

  final int baseRound = ((roundNumber - 1) % (n - 1)) + 1;
  final list = List<String>.from(teams);

  void rotateOnce() {
    final fixed = list.first;
    final rest = list.sublist(1);
    final rotated = <String>[rest.last, ...rest.take(rest.length - 1)];
    list
      ..clear()
      ..add(fixed)
      ..addAll(rotated);
  }

  for (int r = 1; r < baseRound; r++) {
    rotateOnce();
  }

  final result = <_FixturePair>[];
  for (int i = 0; i < n ~/ 2; i++) {
    var a = list[i];
    var b = list[n - 1 - i];
    final bool swap = ((baseRound + i) % 2 == 0);
    if (swap) {
      final tmp = a;
      a = b;
      b = tmp;
    }
    result.add(_FixturePair(home: a, away: b));
  }
  return result;
}

class _HomeScheduleCard extends StatelessWidget {
  final bool isSoccer;
  final Future<Map<String, dynamic>> leagueFuture;
  const _HomeScheduleCard({
    required this.isSoccer,
    required this.leagueFuture,
  });

  @override
  Widget build(BuildContext context) {
    if (isSoccer) {
      return FutureBuilder<Map<String, dynamic>>(
        future: leagueFuture,
        builder: (context, snapshot) {
          final allFixtures =
              snapshot.data?['fixtures'] as List<dynamic>? ?? [];
          final fixtures = _pickUpcomingRoundFixturesFromApi(allFixtures);
          final roundLabel = _readRoundLabelFromApi(fixtures) ?? 'Round 1';
          return _buildScheduleCard(
            context,
            roundLabel: roundLabel,
            fixtures: fixtures,
            isSoccer: true,
          );
        },
      );
    }

    final int nextRound =
        ((_baseballStandingsRows().isEmpty
            ? 0
            : _baseballStandingsRows().map((e) => e.played).reduce(max)) +
        1);
    final fixtures = _buildRoundFixtures(
      teams: _kboTeams,
      roundNumber: nextRound,
    );
    return _buildScheduleCard(
      context,
      roundLabel: 'Round $nextRound',
      fixtures: fixtures
          .map((e) => {'home': e.home, 'away': e.away, 'date': '', 'venue': ''})
          .toList(),
      isSoccer: false,
    );
  }

  Widget _buildScheduleCard(
    BuildContext context, {
    required String roundLabel,
    required List<Map<String, String>> fixtures,
    required bool isSoccer,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final Color text = isDark ? Colors.white : Colors.black87;
    final Color muted = isDark ? Colors.white70 : Colors.black54;
    final Color border = isDark ? Colors.white12 : Colors.black12;
    final Color surface = isDark
        ? const Color.fromARGB(255, 30, 30, 30)
        : theme.cardColor;
    final Color headerBg = isDark
        ? Colors.white10
        : Colors.black.withOpacity(0.03);

    Widget teamName(String name, {TextAlign align = TextAlign.left}) {
      return Text(
        name,
        textAlign: align,
        maxLines: 2,
        overflow: TextOverflow.clip,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w800,
          height: 1.05,
          color: text,
        ),
      );
    }

    return Container(
      width: double.infinity,
      // Give fixture rows more horizontal room (long club names wrap less).
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
        boxShadow: isDark
            ? const []
            : const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 10,
                  offset: Offset(0, 6),
                ),
              ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: headerBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: border),
            ),
            child: Row(
              children: [
                Icon(
                  isSoccer ? Icons.sports_soccer : Icons.sports_baseball,
                  size: 16,
                  color: muted,
                ),
                const SizedBox(width: 8),
                Text(
                  roundLabel,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: text,
                  ),
                ),
                const Spacer(),
                Text(
                  '리그 일정',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (fixtures.isEmpty)
            Text(
              '시즌 시작 전입니다. 공식 일정이 아직 없습니다.',
              style: TextStyle(fontSize: 13, color: muted),
            )
          else
            for (int i = 0; i < fixtures.length; i++) ...[
              if (i != 0) Divider(height: 16, thickness: 1, color: border),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(child: teamName(fixtures[i]['home'] ?? 'TBD')),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        'vs',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: muted,
                        ),
                      ),
                    ),
                    Expanded(
                      child: teamName(
                        fixtures[i]['away'] ?? 'TBD',
                        align: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              ),
            ],
        ],
      ),
    );
  }
}

List<Map<String, String>> _pickUpcomingRoundFixturesFromApi(
  List<dynamic> fixtures,
) {
  if (fixtures.isEmpty) return const <Map<String, String>>[];

  final now = DateTime.now().toUtc();
  final parsed = fixtures.map((raw) {
    final map = raw is Map<String, dynamic>
        ? raw
        : Map<String, dynamic>.from(raw as Map);
    final fixture = (map['fixture'] as Map?)?.cast<String, dynamic>() ?? {};
    final teams = (map['teams'] as Map?)?.cast<String, dynamic>() ?? {};
    final home = (teams['home'] as Map?)?.cast<String, dynamic>() ?? {};
    final away = (teams['away'] as Map?)?.cast<String, dynamic>() ?? {};
    final venue = (fixture['venue'] as Map?)?.cast<String, dynamic>() ?? {};
    final league = (map['league'] as Map?)?.cast<String, dynamic>() ?? {};
    final date = DateTime.tryParse('${fixture['date']}')?.toUtc();
    return {
      'home': '${home['name'] ?? 'TBD'}',
      'away': '${away['name'] ?? 'TBD'}',
      'round': '${league['round'] ?? ''}',
      'date': date?.toIso8601String() ?? '',
      'venue': '${venue['name'] ?? ''}',
    };
  }).toList()..sort((a, b) => a['date']!.compareTo(b['date']!));

  final firstUpcoming = parsed.firstWhere((e) {
    final d = DateTime.tryParse(e['date'] ?? '')?.toUtc();
    return d != null && d.isAfter(now);
  }, orElse: () => parsed.first);

  final targetRound = firstUpcoming['round'];
  return parsed.where((e) => e['round'] == targetRound).toList();
}

String? _readRoundLabelFromApi(List<Map<String, String>> fixtures) {
  if (fixtures.isEmpty) return null;
  final round = fixtures.first['round'];
  if (round == null || round.isEmpty) return null;
  return round;
}

const List<String> _kLeagueTeams = [
  '부천FC 1995',
  '대전 하나 시티즌',
  'FC 안양',
  'FC 서울',
  '강원 FC',
  '김천 상무',
  '광주 FC',
  '인천 유나이티드',
  '제주 SK',
  '전북 현대',
  '포항 스틸러스',
  '울산 HD',
];

const List<String> _kboTeams = [
  'LG',
  '한화',
  'SSG',
  '삼성',
  'NC',
  'KT',
  '롯데',
  '두산',
  'KIA',
  '키움',
];
