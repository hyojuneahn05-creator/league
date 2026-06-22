part of '../home_page.dart';

class StandingsPage extends StatefulWidget {
  final bool isSoccer;

  const StandingsPage({super.key, required this.isSoccer});

  @override
  State<StandingsPage> createState() => _StandingsPageState();
}

class _StandingsPageState extends State<StandingsPage> {
  bool _isMyPageOpen = false;

  void _toggleMyPage() => setState(() => _isMyPageOpen = !_isMyPageOpen);

  Widget _splitLegend(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Widget item(Color color, String label) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 18,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          item(const Color(0xFF4FB6FF), '상위 스플릿'),
          const SizedBox(width: 18),
          item(const Color(0xFFFF4B4B), '하위 스플릿'),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isSoccer) {
      return _OverlayScaffold(
        isMyPageOpen: _isMyPageOpen,
        onToggleMyPage: _toggleMyPage,
        showSearch: false,
        child: FutureBuilder<Map<String, dynamic>>(
          future: _loadCachedKLeagueLeagueData(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: _comingSoonCard(
                  'K리그 순위를 불러오지 못했습니다.',
                  subtitle: '${snapshot.error}',
                ),
              );
            }

            final soccerRows = _soccerRowsFromApi(
              snapshot.data?['standings'] as List<dynamic>?,
            );
            return CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      children: [
                        _KLeagueApiSummaryCard(
                          data: snapshot.data ?? const <String, dynamic>{},
                        ),
                        const SizedBox(height: 14),
                        _SoccerStandingsTable(
                          rows: soccerRows,
                          mode: _StandingsTableMode.detail,
                          onTeamTap: (team) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    TeamPage(isSoccer: true, team: team),
                              ),
                            );
                          },
                        ),
                        _splitLegend(context),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      );
    }

    return _OverlayScaffold(
      isMyPageOpen: _isMyPageOpen,
      onToggleMyPage: _toggleMyPage,
      showSearch: false,
      child: FutureBuilder<Map<String, dynamic>>(
        future: _loadCachedKboLeagueData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: _comingSoonCard(
                'KBO 순위를 불러오지 못했습니다.',
                subtitle: '${snapshot.error}',
              ),
            );
          }

          final baseballRows = _baseballRowsFromApi(
            snapshot.data?['standings'] as List<dynamic>?,
          );
          if (baseballRows.isEmpty) {
            return Center(
              child: _comingSoonCard(
                'KBO 순위 데이터가 아직 없습니다.',
                subtitle: '공식 데이터가 연결되면 자동으로 표시됩니다.',
              ),
            );
          }

          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    children: [
                      _KboApiSummaryCard(
                        data: snapshot.data ?? const <String, dynamic>{},
                      ),
                      const SizedBox(height: 14),
                      _BaseballStandingsTable(
                        rows: baseballRows,
                        mode: _StandingsTableMode.detail,
                        onTeamTap: (team) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  TeamPage(isSoccer: false, team: team),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _KLeagueApiSummaryCard extends StatelessWidget {
  final Map<String, dynamic> data;

  const _KLeagueApiSummaryCard({required this.data});

  int _currentRound() {
    final rawFixtures = _fixtureAsList(data['fixtures']);
    var latestRound = 0;
    for (final raw in rawFixtures) {
      final map = _fixtureAsMap(raw);
      if (!_kLeagueFixtureMapHasStarted(map)) continue;
      final round = _roundNumber(
        _fixtureText(_fixtureAsMap(map['league'])['round']),
      );
      if (round > latestRound) latestRound = round;
    }
    return latestRound;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final Color text = isDark ? Colors.white : Colors.black87;
    final Color border = isDark ? Colors.white12 : Colors.black12;
    final Color surface = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    final season = data['season'] ?? ApiService.targetSeason;
    final currentRound = _currentRound();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        color: surface,
        gradient: isDark
            ? null
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFF7FAFF), Color(0xFFFFFFFF)],
              ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: border),
        boxShadow: isDark
            ? const []
            : const [
                BoxShadow(
                  color: Color(0x16000000),
                  blurRadius: 18,
                  offset: Offset(0, 10),
                ),
              ],
      ),
      child: Stack(
        children: [
          if (!isDark)
            Positioned(
              top: -22,
              right: -12,
              child: Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  color: const Color(0xFF2D6DFF).withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          if (!isDark)
            Positioned(
              bottom: -28,
              left: -10,
              child: Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: const Color(0xFF16A34A).withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white10 : const Color(0xFFEDF4FF),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: isDark
                            ? Colors.white12
                            : const Color(0xFFD7E6FF),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.shield_outlined,
                          size: 14,
                          color: isDark
                              ? Colors.white70
                              : const Color(0xFF2D6DFF),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'K LEAGUE 1',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF2D6DFF),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white10 : const Color(0xFFF2F8F3),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: isDark
                            ? Colors.white12
                            : const Color(0xFFD9EEDD),
                      ),
                    ),
                    child: Text(
                      currentRound > 0 ? 'ROUND $currentRound' : 'PRE-SEASON',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : const Color(0xFF14833B),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                '$season K리그 1',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  height: 1.02,
                  color: text,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _KboApiSummaryCard extends StatelessWidget {
  final Map<String, dynamic> data;

  const _KboApiSummaryCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final Color text = isDark ? Colors.white : Colors.black87;
    final Color border = isDark ? Colors.white12 : Colors.black12;
    final Color surface = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final season = data['season'] ?? ApiService.targetSeason;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        color: surface,
        gradient: isDark
            ? null
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFFF8F2), Color(0xFFFFFFFF)],
              ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: border),
        boxShadow: isDark
            ? const []
            : const [
                BoxShadow(
                  color: Color(0x16000000),
                  blurRadius: 18,
                  offset: Offset(0, 10),
                ),
              ],
      ),
      child: Stack(
        children: [
          if (!isDark)
            Positioned(
              top: -22,
              right: -12,
              child: Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  color: const Color(0xFFE85D2A).withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          if (!isDark)
            Positioned(
              bottom: -28,
              left: -10,
              child: Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white10 : const Color(0xFFFFEFE8),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: isDark
                            ? Colors.white12
                            : const Color(0xFFFFD9CC),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.sports_baseball,
                          size: 14,
                          color: isDark
                              ? Colors.white70
                              : const Color(0xFFE85D2A),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'KBO',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFFE85D2A),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white10 : const Color(0xFFFFF7E8),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: isDark
                            ? Colors.white12
                            : const Color(0xFFF3DEB4),
                      ),
                    ),
                    child: Text(
                      'REGULAR SEASON',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : const Color(0xFF9A6700),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                '$season KBO 리그',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  height: 1.02,
                  color: text,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
