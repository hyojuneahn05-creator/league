part of '../home_page.dart';

class TeamPage extends StatefulWidget {
  final bool isSoccer;
  final String team;

  const TeamPage({
    super.key,
    required this.isSoccer,
    required this.team,
  });

  @override
  State<TeamPage> createState() => _TeamPageState();
}

class _TeamPageState extends State<TeamPage> {
  bool _isMyPageOpen = false;
  void _toggleMyPage() => setState(() => _isMyPageOpen = !_isMyPageOpen);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final Color text = isDark ? Colors.white : Colors.black87;
    final Color muted = isDark ? Colors.white70 : Colors.black54;
    final Color border = isDark ? Colors.white12 : Colors.black12;
    final Color surface = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    final soccerRows =
        widget.isSoccer ? _soccerStandingsRows() : const <_SoccerStandingsRow>[];
    final baseballRows = widget.isSoccer
        ? const <_BaseballStandingsRow>[]
        : _baseballStandingsRows();

    final int rank = widget.isSoccer
        ? (soccerRows.indexWhere((r) => r.team == widget.team) + 1)
        : (baseballRows.indexWhere((r) => r.team == widget.team) + 1);

    final _SoccerStandingsRow? sRow = widget.isSoccer
        ? (soccerRows.where((r) => r.team == widget.team).isEmpty
            ? null
            : soccerRows.firstWhere((r) => r.team == widget.team))
        : null;

    final _BaseballStandingsRow? bRow = widget.isSoccer
        ? null
        : (baseballRows.where((r) => r.team == widget.team).isEmpty
            ? null
            : baseballRows.firstWhere((r) => r.team == widget.team));

    final playerPool =
        _MatchDetailPageState._cachedSoccerPlayers ?? _buildPlayerPool(Random(0));

    final rosterEntries =
        widget.isSoccer ? _docRosterForClub(widget.team) : const <_DocRosterEntry>[];

    final poolByName = {for (final p in playerPool) p.name: p};

    final roster = widget.isSoccer
        ? rosterEntries
            .map((e) {
              final fromPool = poolByName[e.name];
              final score = fromPool?.score ??
                  ((_stableSeedFromKey('pts|${e.name}|${e.meta.club}|${e.meta.number}') %
                          8) +
                      1);
              return (name: e.name, meta: e.meta, score: score);
            })
            .toList()
        : <({String name, _DocPlayerMeta meta, int score})>[];

    int posOrder(String p) => switch (p) {
          'GK' => 0,
          'DF' => 1,
          'MF' => 2,
          'FW' => 3,
          _ => 9,
        };

    roster.sort((a, b) {
      final ma = a.meta;
      final mb = b.meta;
      final po = posOrder(ma.position).compareTo(posOrder(mb.position));
      if (po != 0) return po;
      final no = ma.number.compareTo(mb.number);
      if (no != 0) return no;
      return a.name.compareTo(b.name);
    });

    Widget statCell(String label, String value) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? Colors.white10 : Colors.black.withOpacity(0.03),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: muted,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: text,
              ),
            ),
          ],
        ),
      );
    }

    Widget sectionTitle(String t) => Padding(
          padding: const EdgeInsets.only(top: 18, bottom: 10),
          child: Text(
            t,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: text,
            ),
          ),
        );

    Widget playerRow(({String name, _DocPlayerMeta meta, int score}) p) {
      final meta = p.meta;
      final own = _MatchDetailPageState._playerOwnerCache[p.name] ??
          PlayerOwnership.otherTeam;
      return InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PlayerProfilePage(
                name: p.name,
                ownership: own,
                metaOverride: meta,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white10 : Colors.black12,
                  shape: BoxShape.circle,
                  border: Border.all(color: border),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${meta.number}',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: text,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: text,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      meta.position,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: muted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${p.score} pts',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return _OverlayScaffold(
      isMyPageOpen: _isMyPageOpen,
      onToggleMyPage: _toggleMyPage,
      showSearch: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: border),
              boxShadow: isDark
                  ? const []
                  : const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 12,
                        offset: Offset(0, 8),
                      ),
                    ],
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white10 : Colors.black12,
                    shape: BoxShape.circle,
                    border: Border.all(color: border),
                  ),
                  child: Icon(
                    widget.isSoccer ? Icons.sports_soccer : Icons.sports_baseball,
                    size: 26,
                    color: muted,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          widget.team,
                          maxLines: 2,
                          overflow: TextOverflow.clip,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            height: 1.05,
                            color: text,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          rank <= 0 ? '' : '${rank}위',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: muted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Next match card (replaces the old Stats grid).
          Builder(
            builder: (context) {
              final int nextRound = widget.isSoccer
                  ? ((soccerRows.isEmpty
                          ? 0
                          : soccerRows.map((e) => e.played).reduce(max)) +
                      1)
                  : ((baseballRows.isEmpty
                          ? 0
                          : baseballRows.map((e) => e.played).reduce(max)) +
                      1);

              final fixtures = _buildRoundFixtures(
                teams: widget.isSoccer ? _kLeagueTeams : _kboTeams,
                roundNumber: nextRound,
              );
              final f = fixtures.firstWhere(
                (m) => m.home == widget.team || m.away == widget.team,
                orElse: () => const _FixturePair(home: '—', away: '—'),
              );
              final isHome = f.home == widget.team;
              final opponent = isHome ? f.away : f.home;

              return Container(
                margin: const EdgeInsets.only(top: 16),
                padding: const EdgeInsets.all(18),
                constraints: const BoxConstraints(minHeight: 168),
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: border),
                  boxShadow: isDark
                      ? const []
                      : const [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 12,
                            offset: Offset(0, 8),
                          ),
                        ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_month,
                          size: 16,
                          color: muted,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Next match',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: text,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'Round $nextRound',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: muted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                      decoration: BoxDecoration(
                        color:
                            isDark ? Colors.white10 : Colors.black.withOpacity(0.03),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: border),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.team,
                              maxLines: 2,
                              overflow: TextOverflow.clip,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                height: 1.05,
                                color: text,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  isHome ? 'HOME' : 'AWAY',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                    color: muted,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'vs',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                    color: muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Text(
                              opponent,
                              textAlign: TextAlign.right,
                              maxLines: 2,
                              overflow: TextOverflow.clip,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                height: 1.05,
                                color: text,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '경기 시간/경기장 정보는 추후 연동 예정입니다.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: muted,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          sectionTitle('Roster'),
          if (!widget.isSoccer)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? Colors.white10 : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: border),
              ),
              child: Text(
                'KBO 팀 로스터는 준비 중입니다.',
                style: TextStyle(
                  color: muted,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          else if (roster.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? Colors.white10 : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: border),
              ),
              child: Text(
                'Roster 문서에 이 팀 소속 선수가 없습니다.',
                style: TextStyle(
                  color: muted,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: border),
              ),
              child: Column(
                children: [
                  for (int i = 0; i < roster.length; i++) ...[
                    if (i != 0) Divider(height: 1, thickness: 1, color: border),
                    playerRow(roster[i]),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}
