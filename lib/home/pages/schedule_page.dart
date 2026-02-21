part of '../home_page.dart';

class SchedulePage extends StatefulWidget {
  final bool isSoccer;

  const SchedulePage({
    super.key,
    required this.isSoccer,
  });

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  bool _isMyPageOpen = false;
  void _toggleMyPage() => setState(() => _isMyPageOpen = !_isMyPageOpen);

  @override
  Widget build(BuildContext context) {
    if (!kUseMockDataOutsideDraft) {
      return _OverlayScaffold(
        isMyPageOpen: _isMyPageOpen,
        onToggleMyPage: _toggleMyPage,
        showSearch: false,
        child: Center(
          child: _comingSoonCard(
            widget.isSoccer ? 'K리그 일정 연동 준비 중' : 'KBO 일정 연동 준비 중',
            subtitle: '공식 데이터 연동 후 제공됩니다.',
          ),
        ),
      );
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final Color text = isDark ? Colors.white : Colors.black87;
    final Color muted = isDark ? Colors.white70 : Colors.black54;
    final Color border = isDark ? Colors.white12 : Colors.black12;
    final Color surface =
        isDark ? const Color.fromARGB(255, 30, 30, 30) : theme.cardColor;
    final Color headerBg =
        isDark ? Colors.white10 : Colors.black.withOpacity(0.03);

    final soccerRows =
        widget.isSoccer ? _soccerStandingsRows() : const <_SoccerStandingsRow>[];
    final baseballRows = widget.isSoccer
        ? const <_BaseballStandingsRow>[]
        : _baseballStandingsRows();

    final int nextRound = widget.isSoccer
        ? ((soccerRows.isEmpty ? 0 : soccerRows.map((e) => e.played).reduce(max)) +
            1)
        : ((baseballRows.isEmpty ? 0 : baseballRows.map((e) => e.played).reduce(max)) +
            1);

    final fixtures = _buildRoundFixtures(
      teams: widget.isSoccer ? _kLeagueTeams : _kboTeams,
      roundNumber: nextRound,
    );

    void openTeam(String team) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TeamPage(isSoccer: widget.isSoccer, team: team),
        ),
      );
    }

    Widget fixtureCard(_FixturePair f) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
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
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => openTeam(f.home),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    f.home,
                    maxLines: 2,
                    overflow: TextOverflow.clip,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      height: 1.05,
                      color: text,
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
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
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => openTeam(f.away),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    f.away,
                    textAlign: TextAlign.right,
                    maxLines: 2,
                    overflow: TextOverflow.clip,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      height: 1.05,
                      color: text,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return _OverlayScaffold(
      isMyPageOpen: _isMyPageOpen,
      onToggleMyPage: _toggleMyPage,
      showSearch: false,
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            sliver: SliverToBoxAdapter(
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    decoration: BoxDecoration(
                      color: surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: border),
                    ),
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: headerBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: border),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            widget.isSoccer
                                ? Icons.sports_soccer
                                : Icons.sports_baseball,
                            size: 16,
                            color: muted,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Round $nextRound',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: text,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            widget.isSoccer ? 'K League 일정' : 'KBO 일정',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  for (int i = 0; i < fixtures.length; i++) ...[
                    if (i != 0) const SizedBox(height: 14),
                    fixtureCard(fixtures[i]),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
