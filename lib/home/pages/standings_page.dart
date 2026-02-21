part of '../home_page.dart';

class StandingsPage extends StatefulWidget {
  final bool isSoccer;

  const StandingsPage({
    super.key,
    required this.isSoccer,
  });

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
    if (!kUseMockDataOutsideDraft) {
      return _OverlayScaffold(
        isMyPageOpen: _isMyPageOpen,
        onToggleMyPage: _toggleMyPage,
        showSearch: false,
        child: Center(
          child: _comingSoonCard(
            widget.isSoccer ? 'K리그 순위 연동 준비 중' : 'KBO 순위 연동 준비 중',
            subtitle: '공식 데이터 연동 후 제공됩니다.',
          ),
        ),
      );
    }

    final soccerRows = widget.isSoccer ? _soccerStandingsRows() : const <_SoccerStandingsRow>[];
    final baseballRows =
        widget.isSoccer ? const <_BaseballStandingsRow>[] : _baseballStandingsRows();

    return _OverlayScaffold(
      isMyPageOpen: _isMyPageOpen,
      onToggleMyPage: _toggleMyPage,
      showSearch: false,
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            sliver: SliverToBoxAdapter(
              child: widget.isSoccer
                  ? Column(
                      children: [
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
                    )
                  : _BaseballStandingsTable(
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
            ),
          ),
        ],
      ),
    );
  }
}
