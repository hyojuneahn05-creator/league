part of '../home_page.dart';

class MyLeaguePage extends StatefulWidget {
  const MyLeaguePage({super.key});

  @override
  State<MyLeaguePage> createState() => _MyLeaguePageState();
}

class _MyLeaguePageState extends State<MyLeaguePage> {
  bool _isMyPageOpen = false;
  final Set<String> _leavingLeagueIds = <String>{};
  Timer? _clockTimer;

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  void _toggleMyPage() => setState(() => _isMyPageOpen = !_isMyPageOpen);

  void _goToCreateLeague(bool isSoccer) {
    Navigator.push<_DraftResult>(
      context,
      MaterialPageRoute(builder: (_) => CreateLeaguePage(isSoccer: isSoccer)),
    ).then((res) {
      if (res != null) {
        homeKey.currentState?.setDraft(
          res.when,
          res.leagueName,
          isSoccer: res.isSoccer,
        );
        homeKey.currentState?.setHasLeagueForSport(res.isSoccer, true);
      }
    });
  }

  Future<void> _goToJoinLeague() async {
    final joined = await Navigator.push<_JoinedDraft>(
      context,
      MaterialPageRoute(builder: (_) => const JoinLeaguePage()),
    );
    if (joined == null) return;
    homeKey.currentState?.addOrUpdateJoinedDraft(joined);
    homeKey.currentState?.setHasLeagueForSport(joined.isSoccer, true);
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _showLeagueEntryOptions() async {
    final cs = Theme.of(context).colorScheme;
    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        Widget tile({
          required IconData icon,
          required String title,
          required String subtitle,
          required VoidCallback onTap,
        }) {
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 4,
            ),
            leading: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: cs.primary.withOpacity(0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: cs.primary),
            ),
            title: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: Text(subtitle),
            onTap: () {
              Navigator.pop(ctx);
              onTap();
            },
          );
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '리그 선택',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  '새 리그를 만들거나 초대 코드로 기존 리그에 참가할 수 있어요.',
                  style: TextStyle(color: cs.onSurface.withOpacity(0.72)),
                ),
                const SizedBox(height: 14),
                tile(
                  icon: Icons.add_circle_outline,
                  title: '새 리그 생성',
                  subtitle: 'K리그 또는 KBO 판타지리그를 선택합니다.',
                  onTap: _showCreateLeagueSportOptions,
                ),
                tile(
                  icon: Icons.key_rounded,
                  title: '리그 참가',
                  subtitle: '초대 코드를 입력해서 바로 참가합니다.',
                  onTap: () {
                    unawaited(_goToJoinLeague());
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showCreateLeagueSportOptions() async {
    final cs = Theme.of(context).colorScheme;
    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        Widget tile({
          required IconData icon,
          required String title,
          required String subtitle,
          required bool isSoccer,
        }) {
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 4,
            ),
            leading: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: cs.primary.withOpacity(0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: cs.primary),
            ),
            title: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: Text(subtitle),
            onTap: () {
              Navigator.pop(ctx);
              _goToCreateLeague(isSoccer);
            },
          );
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '종목 선택',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  '생성할 판타지리그 종목을 선택해 주세요.',
                  style: TextStyle(color: cs.onSurface.withOpacity(0.72)),
                ),
                const SizedBox(height: 14),
                tile(
                  icon: Icons.sports_soccer,
                  title: 'K리그 판타지리그',
                  subtitle: '축구 드래프트와 라운드 옵션으로 생성합니다.',
                  isSoccer: true,
                ),
                tile(
                  icon: Icons.sports_baseball,
                  title: 'KBO 판타지리그',
                  subtitle: '야구 드래프트로 생성하며 34라운드로 고정됩니다.',
                  isSoccer: false,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<bool> _showLeaveDialog({
    required String title,
    required String message,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          content: Text(
            message,
            style: const TextStyle(fontSize: 14, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFD92D20),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('탈퇴'),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  Future<void> _leaveLeague(
    _JoinedDraft draft, {
    required bool fromDraftSection,
  }) async {
    if (draft.leagueId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('리그 정보를 불러오는 중입니다.')));
      return;
    }
    if (_leavingLeagueIds.contains(draft.leagueId)) return;

    final confirmed = await _showLeaveDialog(
      title: fromDraftSection ? 'Draft 탈퇴' : '리그 탈퇴',
      message: fromDraftSection
          ? '${draft.leagueName} Draft 참여를 취소할까요?\n리그 참가도 함께 해제됩니다.'
          : '${draft.leagueName}에서 탈퇴할까요?\n해당 Draft 참여도 함께 취소됩니다.',
    );
    if (!confirmed || !mounted) return;

    setState(() => _leavingLeagueIds.add(draft.leagueId));
    try {
      await LeagueService.instance.leaveLeague(draft.leagueId);
      homeKey.currentState?.removeJoinedDraftByLeagueId(draft.leagueId);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${draft.leagueName}에서 탈퇴했습니다.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('탈퇴 실패: $e')));
    } finally {
      if (mounted) {
        setState(() => _leavingLeagueIds.remove(draft.leagueId));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final List<_JoinedDraft> joinedLeagues =
        homeKey.currentState?.joinedDrafts ?? const [];
    final List<_JoinedDraft> visibleDrafts =
        homeKey.currentState?.visibleDraftEntries ?? const [];

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
                if (joinedLeagues.isEmpty)
                  _EmptyLeagueState(
                    onCreate: () {
                      unawaited(_showLeagueEntryOptions());
                    },
                    onBrowse: () {
                      unawaited(_goToJoinLeague());
                    },
                  )
                else
                  ...joinedLeagues.map(
                    (draft) => _SwipeLeaveTile(
                      key: ValueKey('league-${draft.leagueId}'),
                      enabled: !_leavingLeagueIds.contains(draft.leagueId),
                      actionPadding: const EdgeInsets.only(bottom: 12),
                      actionGap: 10,
                      onLeaveTap: () =>
                          _leaveLeague(draft, fromDraftSection: false),
                      child: _LeagueSummaryCard(
                        title: draft.leagueName,
                        record: '실시간 경기/포인트 데이터 연동 예정',
                        rank: '리그 순위 연동 예정',
                        nextMatch:
                            'Draft: ${_kstMonthDayTimeLabel(draft.when)}',
                        isSoccer: draft.isSoccer,
                        trailingBusy: _leavingLeagueIds.contains(
                          draft.leagueId,
                        ),
                        onTap: _leavingLeagueIds.contains(draft.leagueId)
                            ? null
                            : () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => MatchDetailPage(
                                      isSoccer: draft.isSoccer,
                                      draft: draft,
                                      initialSection: _MatchSection.league,
                                    ),
                                  ),
                                );
                              },
                      ),
                    ),
                  ),
                if (joinedLeagues.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () {
                      unawaited(_showLeagueEntryOptions());
                    },
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
                  if (visibleDrafts.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: cs.surface.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: cs.onSurface.withOpacity(0.08),
                        ),
                      ),
                      child: Text(
                        '참가 중인 Draft가 없습니다.',
                        style: TextStyle(color: cs.onSurface.withOpacity(0.75)),
                      ),
                    )
                  else
                    ...visibleDrafts.map(
                      (d) => _SwipeLeaveTile(
                        key: ValueKey('draft-${d.leagueId}'),
                        enabled: !_leavingLeagueIds.contains(d.leagueId),
                        actionPadding: const EdgeInsets.only(bottom: 10),
                        actionGap: 10,
                        onLeaveTap: () =>
                            _leaveLeague(d, fromDraftSection: true),
                        child: _JoinedDraftCard(
                          draft: d,
                          busy: _leavingLeagueIds.contains(d.leagueId),
                          onTap: _leavingLeagueIds.contains(d.leagueId)
                              ? null
                              : () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => DraftDetailPage(draft: d),
                                    ),
                                  );
                                },
                        ),
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
  final bool trailingBusy;
  const _LeagueSummaryCard({
    required this.title,
    required this.record,
    required this.rank,
    required this.nextMatch,
    required this.isSoccer,
    this.onTap,
    this.trailingBusy = false,
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
                if (trailingBusy)
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: cs.primary,
                    ),
                  )
                else
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
  final VoidCallback? onTap;
  final bool busy;
  const _JoinedDraftCard({
    required this.draft,
    required this.onTap,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final diff = draft.when.difference(now);
    final String remain = _isDraftCompletedAt(draft, now)
        ? '완료'
        : diff.isNegative
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
            Icon(Icons.schedule, color: cs.primary),
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
                    '${draft.isSoccer ? 'K League' : 'KBO'} · ${_kstMonthDayTimeLabel(draft.when)}',
                    style: TextStyle(
                      color: cs.onSurface.withOpacity(0.7),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (busy)
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: cs.primary,
                ),
              )
            else
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

class _SwipeLeaveTile extends StatefulWidget {
  final Widget child;
  final Future<void> Function() onLeaveTap;
  final bool enabled;
  final EdgeInsets actionPadding;
  final double actionGap;

  const _SwipeLeaveTile({
    super.key,
    required this.child,
    required this.onLeaveTap,
    this.enabled = true,
    this.actionPadding = EdgeInsets.zero,
    this.actionGap = 0,
  });

  @override
  State<_SwipeLeaveTile> createState() => _SwipeLeaveTileState();
}

class _SwipeLeaveTileState extends State<_SwipeLeaveTile> {
  static const double _maxActionRatio = 0.34;
  static const double _snapVelocity = 720;

  double _offsetX = 0;
  bool _dragging = false;
  Duration _settleDuration = const Duration(milliseconds: 180);

  bool get _isOpen => _offsetX < -1;

  Duration _durationForDistance(double distance) {
    final ms = ((distance / _snapVelocity) * 1000).round().clamp(90, 220);
    return Duration(milliseconds: ms);
  }

  void _animateTo(double target) {
    final distance = (_offsetX - target).abs();
    setState(() {
      _dragging = false;
      _settleDuration = _durationForDistance(distance);
      _offsetX = target;
    });
  }

  void _handleDragUpdate(DragUpdateDetails details, double actionWidth) {
    if (!widget.enabled) return;
    setState(() {
      _dragging = true;
      _offsetX = (_offsetX + details.delta.dx).clamp(-actionWidth, 0.0);
    });
  }

  void _handleDragEnd(DragEndDetails details, double actionWidth) {
    if (!widget.enabled) return;
    final shouldOpen =
        _offsetX.abs() > actionWidth * 0.45 || details.primaryVelocity! < -300;
    _animateTo(shouldOpen ? -actionWidth : 0);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final actionWidth = constraints.maxWidth * _maxActionRatio;
        final revealedWidth = (-_offsetX).clamp(0.0, actionWidth);
        final buttonWidth = (actionWidth - widget.actionGap).clamp(
          0.0,
          actionWidth,
        );
        return Stack(
          children: [
            Positioned.fill(
              child: Align(
                alignment: Alignment.centerRight,
                child: ClipRect(
                  child: Align(
                    alignment: Alignment.centerRight,
                    widthFactor: actionWidth <= 0
                        ? 0
                        : revealedWidth / actionWidth,
                    child: Padding(
                      padding: widget.actionPadding.add(
                        EdgeInsets.only(left: widget.actionGap),
                      ),
                      child: SizedBox(
                        width: buttonWidth,
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFD92D20),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: widget.enabled
                                  ? () async {
                                      await widget.onLeaveTap();
                                      if (mounted) _animateTo(0);
                                    }
                                  : null,
                              child: const Center(
                                child: Text(
                                  '탈퇴',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            AnimatedContainer(
              duration: _dragging ? Duration.zero : _settleDuration,
              curve: Curves.linear,
              transform: Matrix4.translationValues(_offsetX, 0, 0),
              child: Stack(
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onHorizontalDragUpdate: (d) =>
                        _handleDragUpdate(d, actionWidth),
                    onHorizontalDragEnd: (d) => _handleDragEnd(d, actionWidth),
                    child: widget.child,
                  ),
                  if (_isOpen)
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: () => _animateTo(0),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _EmptyLeagueState extends StatelessWidget {
  final VoidCallback onCreate;
  final VoidCallback onBrowse;
  const _EmptyLeagueState({required this.onCreate, required this.onBrowse});

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
