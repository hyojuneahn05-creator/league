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
      backgroundColor: cs.surface,
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
      backgroundColor: cs.surface,
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
                  subtitle: '야구 드래프트로 생성하며 라운드는 자동 계산됩니다.',
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
      title: fromDraftSection ? '드래프트 탈퇴' : '리그 탈퇴',
      message: fromDraftSection
          ? '${draft.leagueName} 드래프트 참여를 취소할까요?\n리그 참가도 함께 해제됩니다.'
          : '${draft.leagueName}에서 탈퇴할까요?\n해당 드래프트 참여도 함께 취소됩니다.',
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
                  ...joinedLeagues.map((draft) {
                    final canOpenLeagueDetail =
                        draft.fantasyReady &&
                        draft.fantasyTeams.isNotEmpty &&
                        draft.fantasySchedule.isNotEmpty &&
                        !_leavingLeagueIds.contains(draft.leagueId);
                    final isComingSoon = !draft.isSoccer && !draft.fantasyReady;
                    return _SwipeLeaveTile(
                      key: ValueKey('league-${draft.leagueId}'),
                      enabled: !_leavingLeagueIds.contains(draft.leagueId),
                      actionPadding: const EdgeInsets.only(bottom: 12),
                      actionGap: 10,
                      onLeaveTap: () =>
                          _leaveLeague(draft, fromDraftSection: false),
                      child: _LeagueSummaryCard(
                        draft: draft,
                        comingSoon: isComingSoon,
                        trailingBusy: _leavingLeagueIds.contains(
                          draft.leagueId,
                        ),
                        onTap: canOpenLeagueDetail
                            ? () {
                                Navigator.push(
                                  context,
                                  _matchDetailPageRoute(
                                    isSoccer: draft.isSoccer,
                                    draft: draft,
                                    initialSection: _MatchSection.league,
                                  ),
                                );
                              }
                            : null,
                      ),
                    );
                  }),
                if (joinedLeagues.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () {
                      unawaited(_showLeagueEntryOptions());
                    },
                    child: const Text('리그 생성 / 리그 참가'),
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '참가 중인 드래프트',
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
                        '참가 중인 드래프트가 없습니다.',
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
              ],
            ),
          ),
          if (_isMyPageOpen)
            GestureDetector(
              onTap: _toggleMyPage,
              child: Container(color: Colors.black.withOpacity(0.35)),
            ),
          _MyPagePopupOverlay(
            isOpen: _isMyPageOpen,
            onDismiss: _toggleMyPage,
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

class _LeagueSummaryCard extends StatelessWidget {
  final _JoinedDraft draft;
  final bool comingSoon;
  final VoidCallback? onTap;
  final bool trailingBusy;
  const _LeagueSummaryCard({
    required this.draft,
    this.comingSoon = false,
    this.onTap,
    this.trailingBusy = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final palette = _leagueItSurfacePalette(context);
    final now = DateTime.now();
    final accent = draft.isSoccer
        ? const Color(0xFF1FA45A)
        : const Color(0xFFE36A1D);
    final isFantasyLive =
        draft.fantasyReady &&
        draft.fantasyTeams.isNotEmpty &&
        draft.fantasySchedule.isNotEmpty;
    final currentRound = isFantasyLive
        ? _currentFantasyRoundAt(draft, now)
        : null;
    final matchup = isFantasyLive
        ? _currentFantasyMatchupForDraft(draft)
        : null;
    final myTeamName = _currentUserFantasyTeamName(draft) ?? '내 팀 미정';
    _FantasyTeamState? myTeam;
    if (matchup != null) {
      myTeam = matchup.myTeam;
    } else {
      for (final team in draft.fantasyTeams) {
        if (team.teamName == myTeamName) {
          myTeam = team;
          break;
        }
      }
    }
    final isDraftDone = _isDraftCompletedAt(draft, now);
    final sportLabel = draft.isSoccer ? 'K League' : 'KBO';
    final statusLabel = comingSoon
        ? '준비 중'
        : isFantasyLive
        ? '진행 중'
        : isDraftDone
        ? '동기화 중'
        : '드래프트 예정';
    final statusBg = comingSoon
        ? cs.onSurface.withValues(alpha: 0.08)
        : accent.withValues(alpha: 0.14);
    final statusFg = comingSoon ? cs.onSurface : accent;

    Widget metaChip(IconData icon, String label) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: palette.tileSurface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: palette.cardBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: palette.mutedInk),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: palette.mutedInk,
              ),
            ),
          ],
        ),
      );
    }

    Widget matchupPanel() {
      if (comingSoon) {
        return Text(
          'KBO 실시간 리그 데이터 연동 준비 중입니다.',
          style: TextStyle(
            fontSize: 13,
            height: 1.45,
            color: cs.onSurface.withValues(alpha: 0.70),
            fontWeight: FontWeight.w700,
          ),
        );
      }
      if (!isFantasyLive) {
        return Text(
          isDraftDone
              ? '드래프트는 완료됐고 리그 데이터를 정리하고 있습니다.'
              : '드래프트 시작 시각: ${_kstMonthDayTimeLabel(draft.when)}',
          style: TextStyle(
            fontSize: 13,
            height: 1.45,
            color: cs.onSurface.withValues(alpha: 0.70),
            fontWeight: FontWeight.w700,
          ),
        );
      }
      if (matchup == null) {
        return Text(
          '현재 라운드 매치업을 불러오는 중입니다.',
          style: TextStyle(
            fontSize: 13,
            height: 1.45,
            color: cs.onSurface.withValues(alpha: 0.70),
            fontWeight: FontWeight.w700,
          ),
        );
      }

      final leftScore = matchup.scoresReady
          ? _formatFantasyFixtureScore(matchup.myScore)
          : '0.0';
      final rightScore = matchup.scoresReady
          ? _formatFantasyFixtureScore(matchup.opponentScore)
          : '0.0';
      return Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: palette.tileSurface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: palette.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${currentRound ?? matchup.round} 라운드 매치업',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: palette.mutedInk,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    matchup.myTeam.teamName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: palette.ink,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '$leftScore : $rightScore',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: palette.ink,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    matchup.opponent.teamName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: palette.ink,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              matchup.scoresReady ? '현재 예상/실시간 점수' : '점수 집계 준비 중',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: palette.mutedInk,
              ),
            ),
          ],
        ),
      );
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: palette.fieldFill,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: palette.cardBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: palette.isDark ? 0.18 : 0.05,
              ),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: palette.tileSurface,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: accent.withValues(alpha: 0.24)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        draft.isSoccer
                            ? Icons.sports_soccer
                            : Icons.sports_baseball,
                        size: 14,
                        color: accent,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        sportLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: accent,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                if (trailingBusy)
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: accent,
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: statusFg,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              draft.leagueName,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: palette.ink,
                height: 1.0,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _FantasyTeamAvatar(
                  uid: myTeam?.uid ?? '',
                  teamName: myTeam?.teamName ?? myTeamName,
                  size: 42,
                  iconSize: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '내 팀',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: palette.mutedInk,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        myTeam?.teamName ?? myTeamName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: palette.ink,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            matchupPanel(),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (currentRound != null)
                  metaChip(Icons.layers_outlined, '$currentRound 라운드'),
                metaChip(Icons.groups_rounded, '${draft.teamCount}팀'),
              ],
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
