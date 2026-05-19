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
          future: ApiService.fetchLeagueData(),
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
        future: ApiService.fetchKboLeagueData(),
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
                  child: _BaseballStandingsTable(
                    rows: baseballRows,
                    mode: _StandingsTableMode.detail,
                    onTeamTap: (team) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TeamPage(isSoccer: false, team: team),
                        ),
                      );
                    },
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final Color text = isDark ? Colors.white : Colors.black87;
    final Color muted = isDark ? Colors.white70 : Colors.black54;
    final Color border = isDark ? Colors.white12 : Colors.black12;
    final Color surface = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    final seasons = data['seasons'] as List<dynamic>? ?? const [];
    final teams = data['teams'] as List<dynamic>? ?? const [];
    final season = data['season'] ?? ApiService.targetSeason;

    Widget metric(String label, String value) {
      return Expanded(
        child: Container(
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
              const SizedBox(height: 5),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: text,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
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
                  blurRadius: 10,
                  offset: Offset(0, 6),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'K League 1 API',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: text,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              metric('Season', '$season'),
              const SizedBox(width: 10),
              metric('Teams', '${teams.length}'),
              const SizedBox(width: 10),
              metric('Available', '${seasons.length}'),
            ],
          ),
        ],
      ),
    );
  }
}
