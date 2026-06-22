part of '../home_page.dart';

enum _StandingsTableMode { compact, detail }

const Map<String, String> _kLeagueKoreanTeamNames = {
  'Bucheon FC 1995': '부천',
  '부천FC 1995': '부천',
  '부천 FC 1995': '부천',
  'Gangwon FC': '강원',
  '강원 FC': '강원',
  'FC Anyang': '안양',
  'FC 안양': '안양',
  'Daejeon Citizen': '대전',
  'Daejeon Hana Citizen': '대전',
  '대전 하나 시티즌': '대전',
  'Gwangju FC': '광주',
  '광주 FC': '광주',
  'Jeju United FC': '제주',
  'Jeju SK': '제주',
  '제주 SK': '제주',
  'Jeonbuk Motors': '전북',
  'Jeonbuk Hyundai Motors': '전북',
  '전북 현대 모터스': '전북',
  '전북 현대': '전북',
  'Incheon United': '인천',
  '인천 유나이티드': '인천',
  'Pohang Steelers': '포항',
  '포항 스틸러스': '포항',
  'FC Seoul': '서울',
  'FC 서울': '서울',
  '울산 HD': '울산',
  'Ulsan Hyundai FC': '울산',
  'Ulsan HD': '울산',
  'Gimcheon Sangmu FC': '김천',
  'Gimcheon Sangmu': '김천',
  '김천 상무': '김천',
};

String _kLeagueDisplayTeamName(String value) {
  final trimmed = value.trim();
  return _kLeagueKoreanTeamNames[trimmed] ?? trimmed;
}

const Map<String, String> _kboKoreanTeamNames = {
  'Doosan Bears': '베어스',
  '두산': '베어스',
  'Hanwha Eagles': '이글스',
  '한화': '이글스',
  'KIA Tigers': '타이거즈',
  'KIA': '타이거즈',
  'Kiwoom Heroes': '히어로즈',
  '키움': '히어로즈',
  'KT Wiz': '위즈',
  'kt wiz Suwon': '위즈',
  'KT': '위즈',
  'LG Twins': '트윈스',
  'LG': '트윈스',
  'Lotte Giants': '자이언츠',
  '롯데': '자이언츠',
  'NC Dinos': '다이노스',
  'NC': '다이노스',
  'Samsung Lions': '라이온즈',
  '삼성': '라이온즈',
  'SSG Landers': '랜더스',
  'SSG': '랜더스',
};

String _kboDisplayTeamName(String value) {
  final trimmed = value.trim();
  return _kboKoreanTeamNames[trimmed] ?? trimmed;
}

String _displayFantasyClubName(String value, {required bool isSoccer}) {
  return isSoccer ? _kLeagueDisplayTeamName(value) : _kboDisplayTeamName(value);
}

String _displayFantasyOpponentLabel(String value, {required bool isSoccer}) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return '';
  return trimmed
      .split(RegExp(r'\s*/\s*'))
      .map((part) => _displayFantasyClubName(part, isSoccer: isSoccer))
      .where((part) => part.isNotEmpty)
      .join(' / ');
}

class _SoccerStandingsRow {
  final String team;
  final int played;
  final int wins;
  final int draws;
  final int losses;
  final int goalsFor;
  final int goalsAgainst;
  final int points;
  final String form;

  const _SoccerStandingsRow({
    required this.team,
    required this.played,
    required this.wins,
    required this.draws,
    required this.losses,
    required this.goalsFor,
    required this.goalsAgainst,
    required this.points,
    this.form = '',
  });

  int get goalDiff => goalsFor - goalsAgainst;
}

class _BaseballStandingsRow {
  final String team;
  final int played;
  final int wins;
  final int draws;
  final int losses;
  final int runsFor;
  final int runsAgainst;
  final int runsDiff;
  final double gamesBehind;
  final String streak; // e.g. W3 / L2

  const _BaseballStandingsRow({
    required this.team,
    required this.played,
    required this.wins,
    required this.draws,
    required this.losses,
    this.runsFor = 0,
    this.runsAgainst = 0,
    this.runsDiff = 0,
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
      team: '부천',
      played: 23,
      wins: 16,
      draws: 4,
      losses: 3,
      goalsFor: 39,
      goalsAgainst: 18,
      points: 52,
    ),
    const _SoccerStandingsRow(
      team: '대전',
      played: 23,
      wins: 15,
      draws: 4,
      losses: 4,
      goalsFor: 36,
      goalsAgainst: 20,
      points: 49,
    ),
    const _SoccerStandingsRow(
      team: '안양',
      played: 23,
      wins: 14,
      draws: 4,
      losses: 5,
      goalsFor: 33,
      goalsAgainst: 22,
      points: 46,
    ),
    const _SoccerStandingsRow(
      team: '서울',
      played: 23,
      wins: 13,
      draws: 5,
      losses: 5,
      goalsFor: 31,
      goalsAgainst: 23,
      points: 44,
    ),
    const _SoccerStandingsRow(
      team: '강원',
      played: 23,
      wins: 12,
      draws: 5,
      losses: 6,
      goalsFor: 29,
      goalsAgainst: 24,
      points: 41,
    ),
    const _SoccerStandingsRow(
      team: '김천',
      played: 23,
      wins: 11,
      draws: 6,
      losses: 6,
      goalsFor: 28,
      goalsAgainst: 25,
      points: 39,
    ),
    const _SoccerStandingsRow(
      team: '광주',
      played: 23,
      wins: 10,
      draws: 6,
      losses: 7,
      goalsFor: 27,
      goalsAgainst: 27,
      points: 36,
    ),
    const _SoccerStandingsRow(
      team: '인천',
      played: 23,
      wins: 9,
      draws: 7,
      losses: 7,
      goalsFor: 25,
      goalsAgainst: 28,
      points: 34,
    ),
    const _SoccerStandingsRow(
      team: '제주',
      played: 23,
      wins: 9,
      draws: 5,
      losses: 9,
      goalsFor: 24,
      goalsAgainst: 29,
      points: 32,
    ),
    const _SoccerStandingsRow(
      team: '전북',
      played: 23,
      wins: 8,
      draws: 6,
      losses: 9,
      goalsFor: 23,
      goalsAgainst: 30,
      points: 30,
    ),
    const _SoccerStandingsRow(
      team: '포항',
      played: 23,
      wins: 8,
      draws: 4,
      losses: 11,
      goalsFor: 22,
      goalsAgainst: 32,
      points: 28,
    ),
    const _SoccerStandingsRow(
      team: '울산',
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
      team: '트윈스',
      played: 40,
      wins: 26,
      draws: 1,
      losses: 13,
      gamesBehind: 0.0,
      streak: 'W3',
    ),
    const _BaseballStandingsRow(
      team: '이글스',
      played: 40,
      wins: 24,
      draws: 1,
      losses: 15,
      gamesBehind: 2.0,
      streak: 'W1',
    ),
    const _BaseballStandingsRow(
      team: '랜더스',
      played: 40,
      wins: 23,
      draws: 0,
      losses: 17,
      gamesBehind: 3.5,
      streak: 'L1',
    ),
    const _BaseballStandingsRow(
      team: '라이온즈',
      played: 40,
      wins: 22,
      draws: 1,
      losses: 17,
      gamesBehind: 4.0,
      streak: 'W2',
    ),
    const _BaseballStandingsRow(
      team: '다이노스',
      played: 40,
      wins: 21,
      draws: 1,
      losses: 18,
      gamesBehind: 5.0,
      streak: 'W1',
    ),
    const _BaseballStandingsRow(
      team: '위즈',
      played: 40,
      wins: 20,
      draws: 0,
      losses: 20,
      gamesBehind: 6.5,
      streak: 'L2',
    ),
    const _BaseballStandingsRow(
      team: '자이언츠',
      played: 40,
      wins: 19,
      draws: 1,
      losses: 20,
      gamesBehind: 7.0,
      streak: 'W1',
    ),
    const _BaseballStandingsRow(
      team: '베어스',
      played: 40,
      wins: 18,
      draws: 0,
      losses: 22,
      gamesBehind: 8.5,
      streak: 'L1',
    ),
    const _BaseballStandingsRow(
      team: '타이거즈',
      played: 40,
      wins: 17,
      draws: 0,
      losses: 23,
      gamesBehind: 9.5,
      streak: 'W1',
    ),
    const _BaseballStandingsRow(
      team: '히어로즈',
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
    String fmtPct(double v) {
      final s = v.toStringAsFixed(3);
      return s.startsWith('0') ? s.substring(1) : s;
    }

    String fmtGb(double v) => v == v.roundToDouble()
        ? v.toStringAsFixed(1).replaceFirst('.0', '')
        : v.toStringAsFixed(1);

    Color? rankAccent(int rank) {
      switch (rank) {
        case 1:
          return const Color(0xFF0B7A3B);
        case 2:
          return const Color(0xFF4F8CFF);
        case 3:
          return const Color(0xFF7ED7F7);
        case 4:
          return const Color(0xFFFFB24C);
        case 5:
          return const Color(0xFFFF4D4F);
      }
      return null;
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
            SizedBox(width: 38), // rank
            SizedBox(width: 28), // logo placeholder
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
      final accent = rankAccent(rank);
      final Color logoBg = isDark ? Colors.white10 : Colors.black12;
      final Color rankBg = isDark ? Colors.white10 : Colors.black12;

      final child = Container(
        constraints: const BoxConstraints(minHeight: 64),
        child: Stack(
          children: [
            if (accent != null)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Container(width: 6, color: accent),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              child: Row(
                children: [
                  SizedBox(
                    width: 38,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        width: 28,
                        height: 28,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: rankBg,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$rank',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: logoBg,
                      shape: BoxShape.circle,
                      border: Border.all(color: border),
                    ),
                    child: Icon(
                      Icons.sports_baseball,
                      size: 15,
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
  final VoidCallback? onHelpTap;
  final Widget Function(BuildContext context, Widget child)? wrapHelpButton;

  const _OverlayScaffold({
    required this.isMyPageOpen,
    required this.onToggleMyPage,
    required this.child,
    this.title,
    this.showSearch = true,
    this.onHelpTap,
    this.wrapHelpButton,
  });

  @override
  Widget build(BuildContext context) {
    final palette = _leagueItSurfacePalette(context);
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusScope.of(context).unfocus(),
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: palette.pageBackground,
            appBar: LeagueItSubAppBar(
              onMyPageTap: onToggleMyPage,
              onHelpTap: onHelpTap,
              title: title,
              showSearch: showSearch,
              wrapHelpButton: wrapHelpButton,
            ),
            body: child,
          ),
          _MyPagePopupOverlay(
            isOpen: isMyPageOpen,
            onDismiss: onToggleMyPage,
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
        ],
      ),
    );
  }
}

class _HomeStandingsCard extends StatelessWidget {
  final bool isSoccer;
  final Future<Map<String, dynamic>> leagueFuture;
  final Widget Function(Widget child)? headerCoachmarkBuilder;

  const _HomeStandingsCard({
    super.key,
    required this.isSoccer,
    required this.leagueFuture,
    this.headerCoachmarkBuilder,
  });

  @override
  Widget build(BuildContext context) {
    if (!isSoccer) {
      return FutureBuilder<Map<String, dynamic>>(
        future: leagueFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _comingSoonCard(
              'KBO 순위를 불러오지 못했습니다.',
              subtitle: '잠시 후 다시 시도해주세요.',
            );
          }
          final rows = snapshot.hasData
              ? _baseballRowsFromApi(
                  snapshot.data!['standings'] as List<dynamic>?,
                )
              : const <_BaseballStandingsRow>[];
          if (snapshot.hasData && rows.isEmpty) {
            return _comingSoonCard(
              'KBO 순위 데이터가 아직 없습니다.',
              subtitle: '공식 데이터가 연결되면 자동으로 표시됩니다.',
            );
          }
          return _buildCard(
            context,
            soccerRows: const <_SoccerStandingsRow>[],
            baseballRows: rows,
          );
        },
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
    final header = Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
    );
    final showcasedHeader = headerCoachmarkBuilder == null
        ? header
        : headerCoachmarkBuilder!(header);

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
          showcasedHeader,
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

Map<String, dynamic> _stringKeyedMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, mapValue) => MapEntry('$key', mapValue));
  }
  return const <String, dynamic>{};
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
    final teamMap = _stringKeyedMap(row['team']);
    if (teamMap.isEmpty) continue;
    final allMap = _stringKeyedMap(row['all']);
    final goalsMap = _stringKeyedMap(allMap['goals']).isNotEmpty
        ? _stringKeyedMap(allMap['goals'])
        : _stringKeyedMap(row['goals']);
    rows.add(
      _SoccerStandingsRow(
        team: _kLeagueDisplayTeamName(
          (teamMap['name'] as String?) ?? 'Unknown',
        ),
        played: readInt(allMap['played'] ?? row['played']),
        wins: readInt(allMap['win'] ?? row['win']),
        draws: readInt(allMap['draw'] ?? row['draw']),
        losses: readInt(allMap['lose'] ?? row['lose']),
        goalsFor: readInt(goalsMap['for'] ?? row['goalsFor']),
        goalsAgainst: readInt(goalsMap['against'] ?? row['goalsAgainst']),
        points: readInt(row['points'] ?? row['pts']),
        form: '${row['form'] ?? ''}',
      ),
    );
  }

  if (rows.isEmpty) return _soccerPreseasonZeroRows();

  rows.sort((a, b) {
    final p = b.points.compareTo(a.points);
    if (p != 0) return p;
    final gd = b.goalDiff.compareTo(a.goalDiff);
    if (gd != 0) return gd;
    return a.team.compareTo(b.team);
  });
  return rows;
}

int _readIntValue(dynamic value) {
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

double _readDoubleValue(dynamic value) {
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}

String _currentKboStreak(dynamic value) {
  final raw = '${value ?? ''}'.trim().toUpperCase();
  if (raw.isEmpty) return '';
  if (RegExp(r'^[WLD]\d+$').hasMatch(raw)) return raw;

  final outcomes = RegExp(r'[WLD]').allMatches(raw).map((m) => m[0]!).toList();
  if (outcomes.isEmpty) return '';

  final latest = outcomes.last;
  var count = 0;
  for (var i = outcomes.length - 1; i >= 0; i--) {
    if (outcomes[i] != latest) break;
    count++;
  }
  return '$latest$count';
}

List<_BaseballStandingsRow> _baseballRowsFromApi(List<dynamic>? standings) {
  final source = standings ?? const <dynamic>[];
  if (source.isEmpty) return const <_BaseballStandingsRow>[];

  final rows = <_BaseballStandingsRow>[];
  for (final raw in source) {
    final row = raw is Map<String, dynamic>
        ? raw
        : Map<String, dynamic>.from(raw as Map);
    rows.add(
      _BaseballStandingsRow(
        team: _kboDisplayTeamName('${row['team'] ?? 'Unknown'}'),
        played: _readIntValue(row['played']),
        wins: _readIntValue(row['wins']),
        draws: _readIntValue(row['draws']),
        losses: _readIntValue(row['losses']),
        runsFor: _readIntValue(row['runsFor']),
        runsAgainst: _readIntValue(row['runsAgainst']),
        runsDiff: _readIntValue(row['runsDiff']),
        gamesBehind: _readDoubleValue(row['gamesBehind']),
        streak: _currentKboStreak(row['streak'] ?? row['form']),
      ),
    );
  }

  rows.sort((a, b) {
    final p = b.winPct.compareTo(a.winPct);
    if (p != 0) return p;
    final gb = a.gamesBehind.compareTo(b.gamesBehind);
    if (gb != 0) return gb;
    return a.team.compareTo(b.team);
  });
  return rows;
}

class _FixturePair {
  final String home;
  final String away;
  const _FixturePair({required this.home, required this.away});
}

class _KboMatch {
  final int id;
  final String home;
  final String away;
  final String date;
  final String time;
  final String dateUtc;
  final String timeUtc;
  final String status;
  final String liveInningLabel;
  final int? homeScore;
  final int? awayScore;
  final String venue;
  final String city;

  const _KboMatch({
    required this.id,
    required this.home,
    required this.away,
    required this.date,
    required this.time,
    required this.dateUtc,
    required this.timeUtc,
    required this.status,
    required this.liveInningLabel,
    required this.homeScore,
    required this.awayScore,
    required this.venue,
    required this.city,
  });

  bool get hasScore => homeScore != null && awayScore != null;
  String get dateTimeLabel {
    final datePart = _homeScheduleDateLabel(date);
    final timePart = _shortTimeLabel(time);
    if (datePart.isEmpty) return timePart;
    if (timePart.isEmpty) return datePart;
    return '$datePart $timePart';
  }
}

List<_KboMatch> _kboMatchesFromApi(List<dynamic>? matches) {
  final source = matches ?? const <dynamic>[];
  final result = <_KboMatch>[];
  for (final raw in source) {
    final match = raw is Map<String, dynamic>
        ? raw
        : Map<String, dynamic>.from(raw as Map);
    final rawDate = '${match['date'] ?? ''}';
    final rawTime = '${match['time'] ?? ''}';
    final rawDateUtc = '${match['dateUtc'] ?? ''}';
    final rawTimeUtc = '${match['timeUtc'] ?? ''}';
    result.add(
      _KboMatch(
        id: _readIntValue(match['id']),
        home: _kboDisplayTeamName('${match['home'] ?? 'TBD'}'),
        away: _kboDisplayTeamName('${match['away'] ?? 'TBD'}'),
        date: _kboDisplayDateKey(rawDate, rawDateUtc, rawTimeUtc),
        time: _kboDisplayTimeValue(rawTime, rawDateUtc, rawTimeUtc),
        dateUtc: rawDateUtc,
        timeUtc: rawTimeUtc,
        status: '${match['status'] ?? ''}',
        liveInningLabel: '${match['liveInningLabel'] ?? ''}'.trim(),
        homeScore: match['homeScore'] == null
            ? null
            : _readIntValue(match['homeScore']),
        awayScore: match['awayScore'] == null
            ? null
            : _readIntValue(match['awayScore']),
        venue: _kboVenueKoreanLabel('${match['venue'] ?? ''}'),
        city: '${match['city'] ?? ''}',
      ),
    );
  }
  result.sort((a, b) {
    final left = '${a.date} ${a.time} ${a.id}';
    final right = '${b.date} ${b.time} ${b.id}';
    return left.compareTo(right);
  });
  return result;
}

DateTime? _kboUtcDateTime(String dateUtc, String timeUtc) {
  if (dateUtc.isEmpty || timeUtc.isEmpty) return null;
  final normalizedTime = RegExp(r'^\d{2}:\d{2}$').hasMatch(timeUtc)
      ? '$timeUtc:00'
      : timeUtc;
  return DateTime.tryParse('${dateUtc}T${normalizedTime}Z');
}

String _kboDisplayDateKey(String fallbackDate, String dateUtc, String timeUtc) {
  final utc = _kboUtcDateTime(dateUtc, timeUtc);
  if (utc == null) return fallbackDate;
  final kst = _toKst(utc);
  return '${kst.year}-${_twoDigits(kst.month)}-${_twoDigits(kst.day)}';
}

String _kboDisplayTimeValue(
  String fallbackTime,
  String dateUtc,
  String timeUtc,
) {
  final utc = _kboUtcDateTime(dateUtc, timeUtc);
  if (utc == null) return fallbackTime;
  final kst = _toKst(utc);
  return '${_twoDigits(kst.hour)}:${_twoDigits(kst.minute)}:00';
}

String _shortTimeLabel(String value) {
  final parts = value.split(':');
  if (parts.length >= 2) return '${parts[0]}:${parts[1]}';
  return value;
}

String _kboStatusLabel(String value) {
  final normalized = value.trim().toLowerCase();
  if (normalized == 'played' || normalized == 'final') return '종료';
  if (normalized == 'playing' || normalized == 'live') return '진행중';
  if (normalized == 'postponed') return '연기';
  if (normalized == 'cancelled' || normalized == 'canceled') return '취소';
  if (normalized == 'fixture' ||
      normalized == 'scheduled' ||
      normalized == 'not started' ||
      normalized.isEmpty) {
    return '예정';
  }
  return value;
}

String _kboInningLabel(String value) {
  final raw = value.trim();
  if (raw.isEmpty) return '';
  if (raw.contains('회')) return raw;
  final digits = RegExp(r'\d+').firstMatch(raw)?.group(0);
  if (digits == null || digits.isEmpty) return raw;
  return '$digits회';
}

String _kboCompactLiveInningLabel(String value) {
  final raw = value.trim();
  if (raw.isEmpty) return '';
  final digits = RegExp(r'\d+').firstMatch(raw)?.group(0);
  if (digits == null || digits.isEmpty) return '';
  if (raw.contains('초')) return '$digits ▲';
  if (raw.contains('말')) return '$digits ▼';
  return '$digits회';
}

String _kboStatusDisplayLabel(String status, {String liveInningLabel = ''}) {
  final base = _kboStatusLabel(status);
  if (!_isKboLiveStatus(status)) return base;
  final inning = _kboInningLabel(liveInningLabel);
  if (inning.isEmpty) return base;
  return '$base · $inning';
}

bool _isKboLiveStatus(String value) {
  final normalized = _kboStatusLabel(value).trim().toLowerCase();
  return normalized == '진행중';
}

String _kboDefaultDate(List<_KboMatch> matches) {
  if (matches.isEmpty) return '';
  final nowKey = DateTime.now().toIso8601String().substring(0, 10);
  final upcoming = matches.where((m) => m.date.compareTo(nowKey) >= 0);
  if (upcoming.isNotEmpty) return upcoming.first.date;
  return matches.last.date;
}

List<String> _kboDateKeys(List<_KboMatch> matches) {
  return matches.map((m) => m.date).where((d) => d.isNotEmpty).toSet().toList()
    ..sort();
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
  final Widget Function(Widget child)? headerCoachmarkBuilder;
  const _HomeScheduleCard({
    super.key,
    required this.isSoccer,
    required this.leagueFuture,
    this.headerCoachmarkBuilder,
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
          final scheduleDate = fixtures.isEmpty ? '' : (fixtures.first['date'] ?? '');
          return _buildScheduleCard(
            context,
            roundLabel: scheduleDate.isEmpty
                ? 'K리그 일정'
                : 'K리그 일정 ${_homeScheduleDateLabel(scheduleDate)}',
            fixtures: fixtures,
            isSoccer: true,
          );
        },
      );
    }

    return FutureBuilder<Map<String, dynamic>>(
      future: leagueFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _comingSoonCard(
            'KBO 일정을 불러오지 못했습니다.',
            subtitle: '잠시 후 다시 시도해주세요.',
          );
        }
        final matches = _kboMatchesFromApi(
          snapshot.data?['matches'] as List<dynamic>?,
        );
        final defaultDate = _kboDefaultDate(matches);
        final fixtures = matches
            .where((match) => match.date == defaultDate)
            .take(6)
            .map(
              (match) => {
                'home': match.home,
                'away': match.away,
                'date': match.dateTimeLabel,
                'time': _shortTimeLabel(match.time),
                'venue': match.venue,
                'status': match.status,
                'liveInningLabel': match.liveInningLabel,
                'score': match.hasScore
                    ? '${match.homeScore} : ${match.awayScore}'
                    : '',
              },
            )
            .toList();
        return _buildScheduleCard(
          context,
          roundLabel: defaultDate.isEmpty
              ? 'KBO 일정'
              : 'KBO 일정 ${_homeScheduleDateLabel(defaultDate)}',
          fixtures: fixtures,
          isSoccer: false,
        );
      },
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
        : Colors.white;
    final Color rowBg = isDark ? Colors.white10 : const Color(0xFFF8FAFC);
    final Color accent = isSoccer
        ? const Color(0xFF16A34A)
        : const Color(0xFFE85D04);
    final Color accentSoft = isDark
        ? accent.withValues(alpha: 0.18)
        : accent.withValues(alpha: 0.10);

    Widget inningBadge(String label) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF16A34A).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: const Color(0xFF16A34A).withValues(alpha: 0.30),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w900,
            color: Color(0xFF16A34A),
          ),
        ),
      );
    }

    Widget teamName(String name, {TextAlign align = TextAlign.left}) {
      return Text(
        name,
        textAlign: align,
        maxLines: 2,
        overflow: TextOverflow.clip,
        style: TextStyle(
          fontSize: 19,
          fontWeight: FontWeight.w900,
          height: 1.05,
          color: text,
        ),
      );
    }

    Widget fixtureRow(Map<String, String> fixture) {
      final dateValue = fixture['date'] ?? '';
      final parsedDateLabel = _homeScheduleDateLabel(dateValue);
      final dateLabel = parsedDateLabel.isEmpty ? dateValue : parsedDateLabel;
      final timeLabel = fixture['time'] ?? '';
      final rawVenue = fixture['venue'] ?? '';
      final venue = isSoccer
          ? _kLeagueVenueOrCityKoreanLabel(rawVenue)
          : _kboVenueKoreanLabel(rawVenue);
      final status = isSoccer ? '' : (fixture['status'] ?? '');
      final liveInningLabel = isSoccer
          ? ''
          : (fixture['liveInningLabel'] ?? '');
      final minuteLabel = fixture['minute'] ?? '';
      final score = fixture['score'] ?? '';
      final isLive = isSoccer
          ? status.toLowerCase() == 'live'
          : _isKboLiveStatus(status);
      final compactInningLabel = isSoccer
          ? ''
          : _kboCompactLiveInningLabel(liveInningLabel);
      final centerText = score.isNotEmpty ? score : 'VS';
      final centerBg = score.isNotEmpty
          ? (isLive ? const Color(0xFFE8F7EC) : accentSoft)
          : accentSoft;
      final centerBorder = isLive
          ? const Color(0xFFB7E4C7)
          : accent.withValues(alpha: 0.20);
      final centerColor = isLive ? const Color(0xFF16A34A) : accent;

      return Container(
        padding: const EdgeInsets.fromLTRB(12, 11, 12, 10),
        decoration: BoxDecoration(
          color: rowBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(child: teamName(fixture['home'] ?? 'TBD')),
                Container(
                  width: 108,
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  child: Column(
                    children: [
                      if (!isSoccer && isLive) ...[
                        const Text(
                          'LIVE',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                            color: Color(0xFF16A34A),
                          ),
                        ),
                        const SizedBox(height: 6),
                      ],
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: centerBg,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: centerBorder),
                        ),
                        child: Text(
                          centerText,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: score.isNotEmpty ? 19 : 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: score.isNotEmpty ? 0 : 0.8,
                            color: centerColor,
                          ),
                        ),
                      ),
                      if (!isSoccer &&
                          isLive &&
                          compactInningLabel.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        inningBadge(compactInningLabel),
                      ],
                    ],
                  ),
                ),
                Expanded(
                  child: teamName(
                    fixture['away'] ?? 'TBD',
                    align: TextAlign.right,
                  ),
                ),
              ],
            ),
            if (isSoccer &&
                (status.isNotEmpty ||
                    minuteLabel.isNotEmpty ||
                    dateLabel.isNotEmpty ||
                    venue.isNotEmpty)) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  if (status.isNotEmpty) ...[
                    Text(
                      status,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: isLive ? const Color(0xFF16A34A) : muted,
                      ),
                    ),
                    if (minuteLabel.isNotEmpty ||
                        dateLabel.isNotEmpty ||
                        venue.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Text(
                          '·',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: muted,
                          ),
                        ),
                      ),
                  ],
                  if (minuteLabel.isNotEmpty) ...[
                    Text(
                      minuteLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: isLive ? const Color(0xFF16A34A) : muted,
                      ),
                    ),
                    if (dateLabel.isNotEmpty || venue.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Text(
                          '·',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: muted,
                          ),
                        ),
                      ),
                  ],
                  if (dateLabel.isNotEmpty) ...[
                    Icon(Icons.schedule_rounded, size: 13, color: muted),
                    const SizedBox(width: 4),
                    Text(
                      dateLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: muted,
                      ),
                    ),
                  ],
                  if (dateLabel.isNotEmpty && venue.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text(
                        '·',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: muted,
                        ),
                      ),
                    ),
                  if (venue.isNotEmpty)
                    Expanded(
                      child: Text(
                        venue,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: muted,
                        ),
                      ),
                    )
                  else
                    const Spacer(),
                ],
              ),
            ],
            if (!isSoccer && (timeLabel.isNotEmpty || venue.isNotEmpty)) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  if (timeLabel.isNotEmpty)
                    Text(
                      timeLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: muted,
                      ),
                    ),
                  if (timeLabel.isNotEmpty && venue.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text(
                        '·',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: muted,
                        ),
                      ),
                    ),
                  if (venue.isNotEmpty)
                    Expanded(
                      child: Text(
                        venue,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: muted,
                        ),
                      ),
                    )
                  else
                    const Spacer(),
                ],
              ),
            ],
          ],
        ),
      );
    }

    final header = Container(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      decoration: BoxDecoration(
        color: rowBg,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: accentSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isSoccer ? Icons.sports_soccer : Icons.sports_baseball,
              size: 18,
              color: accent,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  roundLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: text,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    final showcasedHeader = headerCoachmarkBuilder == null
        ? header
        : headerCoachmarkBuilder!(header);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: border),
        boxShadow: isDark
            ? const []
            : const [
                BoxShadow(
                  color: Color(0x16000000),
                  blurRadius: 22,
                  offset: Offset(0, 12),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          showcasedHeader,
          const SizedBox(height: 12),
          if (fixtures.isEmpty)
            Text(
              '시즌 시작 전입니다. 공식 일정이 아직 없습니다.',
              style: TextStyle(fontSize: 13, color: muted),
            )
          else
            for (int i = 0; i < fixtures.length; i++) ...[
              if (i != 0) const SizedBox(height: 8),
              fixtureRow(fixtures[i]),
            ],
        ],
      ),
    );
  }
}

String _homeScheduleDateLabel(String value) {
  if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
    final parts = value.split('-');
    return '${int.parse(parts[1])}/${int.parse(parts[2])}';
  }
  final date = DateTime.tryParse(value);
  if (date == null) return '';
  return _kstMonthDayTimeLabel(date);
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
    final fixture = _stringKeyedMap(map['fixture']);
    final teams = _stringKeyedMap(map['teams']);
    final home = _stringKeyedMap(teams['home']);
    final away = _stringKeyedMap(teams['away']);
    final venue = _stringKeyedMap(fixture['venue']);
    final league = _stringKeyedMap(map['league']);
    final goals = _stringKeyedMap(map['goals']);
    final status = _stringKeyedMap(fixture['status']);
    final date = DateTime.tryParse('${fixture['date']}')?.toUtc();
    final homeGoals = _readNullableInt(goals['home']);
    final awayGoals = _readNullableInt(goals['away']);
    final statusShort = '${status['short'] ?? ''}';
    return {
      'home': _kLeagueDisplayTeamName('${home['name'] ?? 'TBD'}'),
      'away': _kLeagueDisplayTeamName('${away['name'] ?? 'TBD'}'),
      'round': '${league['round'] ?? ''}',
      'date': date?.toIso8601String() ?? '',
      'venue': _kLeagueVenueOrCityKoreanLabel(
        '${venue['name'] ?? ''}',
        '${venue['city'] ?? ''}',
      ),
      'status': _kLeagueHomeFixtureStatusLabel(statusShort),
      'statusShort': statusShort,
      'minute': _fixtureMinuteLabel(
        _fixtureText(status['elapsed']),
        _fixtureText(status['extra']),
      ),
      'score': homeGoals != null && awayGoals != null
          ? '$homeGoals : $awayGoals'
          : '',
    };
  }).toList()..sort((a, b) => a['date']!.compareTo(b['date']!));

  final firstLive = parsed.firstWhere(
    (e) => _isKLeagueLiveStatusShort(e['statusShort'] ?? ''),
    orElse: () => const <String, String>{},
  );
  final targetFixture = firstLive.isNotEmpty
      ? firstLive
      : parsed.firstWhere((e) {
          final d = DateTime.tryParse(e['date'] ?? '')?.toUtc();
          return d != null && d.isAfter(now);
        }, orElse: () => parsed.first);

  final targetRound = targetFixture['round'];
  return parsed.where((e) => e['round'] == targetRound).toList();
}

bool _isKLeagueLiveStatusShort(String value) {
  switch (value.toUpperCase()) {
    case '1H':
    case '2H':
    case 'HT':
    case 'ET':
    case 'LIVE':
      return true;
    default:
      return false;
  }
}

String _kLeagueHomeFixtureStatusLabel(String short) {
  switch (short.toUpperCase()) {
    case 'FT':
    case 'AET':
    case 'PEN':
      return 'Final';
    case 'NS':
    case 'TBD':
      return 'Scheduled';
    case '1H':
    case '2H':
    case 'HT':
    case 'ET':
    case 'LIVE':
      return 'LIVE';
    case 'PST':
      return 'Postponed';
    case 'CANC':
      return 'Canceled';
    default:
      return short;
  }
}

const List<String> _kLeagueTeams = [
  '부천',
  '대전',
  '안양',
  '서울',
  '강원',
  '김천',
  '광주',
  '인천',
  '제주',
  '전북',
  '포항',
  '울산',
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
