part of '../home_page.dart';

class MyLeaguePage extends StatefulWidget {
  const MyLeaguePage({super.key});

  @override
  State<MyLeaguePage> createState() => _MyLeaguePageState();
}

class _MyLeaguePageState extends State<MyLeaguePage> {
  bool _isMyPageOpen = false;
  void _toggleMyPage() => setState(() => _isMyPageOpen = !_isMyPageOpen);
  void _goToCreateLeague() {
    Navigator.push<_DraftResult>(
      context,
      MaterialPageRoute(
        builder: (_) => const CreateLeaguePage(isSoccer: true),
      ),
    ).then((res) {
      if (res != null) {
        homeKey.currentState?.setDraft(res.when, res.leagueName, isSoccer: true);
        homeKey.currentState?.setHasLeagueForSport(true, true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final List<_JoinedDraft> joinedDrafts =
        homeKey.currentState?.joinedDrafts ?? const [];
    final List<_LeagueSummaryData> leagues = joinedDrafts
        .map(
          (d) => _LeagueSummaryData(
            title: d.leagueName,
            record: '실시간 경기/포인트 데이터 연동 예정',
            rank: '리그 순위 연동 예정',
            nextMatch:
                'Draft: ${d.when.month}/${d.when.day} ${d.when.hour.toString().padLeft(2, '0')}:${d.when.minute.toString().padLeft(2, '0')}',
            isSoccer: d.isSoccer,
          ),
        )
        .toList();

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusScope.of(context).unfocus(),
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            appBar: LeagueItSubAppBar(
              onMyPageTap: _toggleMyPage,
              showSearch: false,
            ),
            body: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  '내 리그',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 16),
                if (leagues.isEmpty)
                  _EmptyLeagueState(
                    onCreate: _goToCreateLeague,
                    onBrowse: _goToCreateLeague,
                  )
                else
                  ...leagues.map(
                    (l) => _LeagueSummaryCard(
                      title: l.title,
                      record: l.record,
                      rank: l.rank,
                      nextMatch: l.nextMatch,
                      isSoccer: l.isSoccer,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MatchDetailPage(
                              isSoccer: l.isSoccer,
                              initialSection: _MatchSection.league,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                if (leagues.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _goToCreateLeague,
                    icon: const Icon(Icons.add),
                    label: const Text('새 리그 생성'),
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '참가 중인 Draft',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (joinedDrafts.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: cs.surface.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: cs.onSurface.withOpacity(0.08)),
                      ),
                      child: Text(
                        '참가 중인 Draft가 없습니다.',
                        style: TextStyle(color: cs.onSurface.withOpacity(0.75)),
                      ),
                    )
                  else
                    ...joinedDrafts.map(
                      (d) => _JoinedDraftCard(
                        draft: d,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DraftDetailPage(
                                leagueName: d.leagueName,
                                draftTime: d.when,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
                const SizedBox(height: 24),
                Text(
                  '최근 활동',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: cs.surface.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: cs.onSurface.withOpacity(0.08)),
                  ),
                  child: Text(
                    '최근 활동은 실데이터 연동 이후 제공됩니다.',
                    style: TextStyle(color: cs.onSurface.withOpacity(0.75)),
                  ),
                ),
              ],
            ),
          ),
          if (_isMyPageOpen)
            GestureDetector(
              onTap: _toggleMyPage,
              child: Container(color: Colors.black.withOpacity(0.35)),
            ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutBack,
            top: _isMyPageOpen ? 100 : 20,
            right: _isMyPageOpen ? 24 : 12,
            child: AnimatedScale(
              duration: const Duration(milliseconds: 400),
              scale: _isMyPageOpen ? 1.0 : 0.2,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 250),
                opacity: _isMyPageOpen ? 1 : 0,
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
        ],
      ),
    );
  }
}

class _LeagueSummaryCard extends StatelessWidget {
  final String title;
  final String record;
  final String rank;
  final String nextMatch;
  final bool isSoccer;
  final VoidCallback? onTap;
  const _LeagueSummaryCard({
    required this.title,
    required this.record,
    required this.rank,
    required this.nextMatch,
    required this.isSoccer,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bool comingSoon = !isSoccer;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cs.surface.withOpacity(0.9),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs.onSurface.withOpacity(0.08)),
          boxShadow: [
            BoxShadow(
              color: cs.onSurface.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: comingSoon
                        ? Colors.black.withOpacity(0.06)
                        : cs.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    comingSoon ? '준비 중' : rank,
                    style: TextStyle(
                      fontSize: 12,
                      color: comingSoon ? cs.onSurface : cs.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              comingSoon ? 'KBO 기능은 준비 중입니다.' : record,
              style: TextStyle(color: cs.onSurface.withOpacity(0.7)),
            ),
            const SizedBox(height: 4),
            Text(
              comingSoon ? '곧 업데이트될 예정이에요.' : nextMatch,
              style: TextStyle(color: cs.onSurface.withOpacity(0.7)),
            ),
          ],
        ),
      ),
    );
  }
}

class _JoinedDraftCard extends StatelessWidget {
  final _JoinedDraft draft;
  final VoidCallback onTap;
  const _JoinedDraftCard({required this.draft, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final diff = draft.when.difference(now);
    final String remain = diff.isNegative
        ? '시작됨'
        : _formatDuration(diff);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cs.surface.withOpacity(0.9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.onSurface.withOpacity(0.08)),
        ),
        child: Row(
          children: [
            Icon(
              Icons.schedule,
              color: cs.primary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    draft.leagueName,
                    style: TextStyle(
                      color: cs.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${draft.isSoccer ? 'K League' : 'KBO'} · ${draft.when.month}/${draft.when.day} ${draft.when.hour.toString().padLeft(2, '0')}:${draft.when.minute.toString().padLeft(2, '0')}',
                    style: TextStyle(
                      color: cs.onSurface.withOpacity(0.7),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              remain,
              style: TextStyle(
                color: cs.onSurface.withOpacity(0.75),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LeagueSummaryData {
  final String title;
  final String record;
  final String rank;
  final String nextMatch;
  final bool isSoccer;
  const _LeagueSummaryData({
    required this.title,
    required this.record,
    required this.rank,
    required this.nextMatch,
    required this.isSoccer,
  });
}

class _EmptyLeagueState extends StatelessWidget {
  final VoidCallback onCreate;
  final VoidCallback onBrowse;
  const _EmptyLeagueState({
    required this.onCreate,
    required this.onBrowse,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cs.surface.withOpacity(0.9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.onSurface.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: cs.primary.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.emoji_events, color: cs.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '아직 참가한 리그가 없어요',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '새 리그를 만들거나 초대받은 링크로 참여해보세요.',
            style: TextStyle(color: cs.onSurface.withOpacity(0.7)),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: onCreate,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    backgroundColor: cs.primary,
                    foregroundColor: cs.onPrimary,
                  ),
                  child: const Text('리그 생성'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: onBrowse,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(color: cs.onSurface.withOpacity(0.3)),
                  ),
                  child: const Text('참가 링크 입력'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
