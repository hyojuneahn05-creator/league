part of '../home_page.dart';

enum PlayerOwnership { myTeam, otherTeam, freeAgent }

class PlayerProfilePage extends StatefulWidget {
  final String name;
  final PlayerOwnership ownership;
  final _DocPlayerMeta? metaOverride;
  final Future<void> Function()? onSign;
  final Future<void> Function()? onTradeRequest;
  const PlayerProfilePage({
    super.key,
    required this.name,
    this.ownership = PlayerOwnership.freeAgent,
    this.metaOverride,
    this.onSign,
    this.onTradeRequest,
  });

  @override
  State<PlayerProfilePage> createState() => _PlayerProfilePageState();
}

class _PlayerProfilePageState extends State<PlayerProfilePage> {
  bool _isMyPageOpen = false;
  void _toggleMyPage() => setState(() => _isMyPageOpen = !_isMyPageOpen);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    // Prefer the app's session ownership cache when available so profiles opened
    // from different entry points (home search, schedule, etc.) stay consistent.
    final resolvedOwnership = _MatchDetailPageState._playerOwnerCache[widget.name] ??
        widget.ownership;
    final meta = widget.metaOverride != null
        ? (
            position: widget.metaOverride!.position,
            club: widget.metaOverride!.club,
            number: widget.metaOverride!.number,
          )
        : _resolvePlayerMeta(widget.name);
    final Color text = isDark ? Colors.white : Colors.black87;
    final Color muted = isDark ? Colors.white70 : Colors.black54;
    final Color border = isDark ? Colors.white12 : Colors.black12;

    Widget infoTile(String label, String value) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? Colors.white10 : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 110,
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  color: muted,
                ),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: text,
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
      title: 'LeagueIt',
      showSearch: false,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: CircleAvatar(
              radius: 48,
              backgroundColor: cs.primary.withOpacity(.12),
              child: Text(
                widget.name.isNotEmpty ? widget.name.characters.first : '?',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: cs.primary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              widget.name,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: text,
              ),
            ),
          ),
          const SizedBox(height: 22),
          Text(
            'Player Info',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: text,
            ),
          ),
          const SizedBox(height: 10),
          infoTile('포지션', meta.position),
          const SizedBox(height: 10),
          infoTile('소속팀', meta.club),
          const SizedBox(height: 10),
          infoTile('등번호', '${meta.number}'),
          const SizedBox(height: 10),
          infoTile('최근 경기 포인트', '—'),
          const SizedBox(height: 24),
          if (resolvedOwnership == PlayerOwnership.freeAgent)
            ElevatedButton.icon(
              onPressed: () async {
                if (widget.onSign != null) {
                  await widget.onSign!.call();
                  return;
                }
                await _signFreeAgentFromProfile(context, widget.name);
              },
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('영입'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
                backgroundColor: Colors.blueAccent,
              ),
            ),
          if (resolvedOwnership == PlayerOwnership.freeAgent)
            const SizedBox(height: 12),
          if (resolvedOwnership == PlayerOwnership.otherTeam)
            ElevatedButton.icon(
              onPressed: () async {
                if (widget.onTradeRequest != null) {
                  await widget.onTradeRequest!.call();
                  return;
                }
                await _requestTradeFromProfile(context, widget.name);
              },
              icon: const Icon(Icons.swap_horiz),
              label: const Text('트레이드 요청'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
                backgroundColor: Colors.orangeAccent,
              ),
            ),
          if (resolvedOwnership == PlayerOwnership.otherTeam)
            const SizedBox(height: 12),
        ],
      ),
    );
  }
}

void _ensureFantasyOwnershipCacheInitialized() {
  // Ensure a stable player pool.
  _MatchDetailPageState._cachedSoccerPlayers ??=
      _buildPlayerPool(Random(_stableSeedFromKey('pool|kLeague')));

  final pool = _MatchDetailPageState._cachedSoccerPlayers!;

  // Ensure my roster (18) exists so sign/trade flows can work from profiles too.
  if (_MatchDetailPageState._myTeamRosterOrder.isEmpty) {
    final seeded = Random(_stableSeedFromKey('init|myRoster'));
    final lineup = _MatchDetailPageState._cachedSoccerLineup ??
        _generateLineup(isSoccer: true, random: seeded);
    _MatchDetailPageState._cachedSoccerLineup = lineup;

    final starting =
        lineup.home.expand((p) => p.slots).map((s) => s.name).toList();
    _MatchDetailPageState._myTeamRosterOrder
      ..clear()
      ..addAll(starting.take(11));
    _MatchDetailPageState._myTeamRosterSet
      ..clear()
      ..addAll(_MatchDetailPageState._myTeamRosterOrder);

    final benchCandidates = pool
        .where((p) => !_MatchDetailPageState._myTeamRosterSet.contains(p.name))
        .toList()
      ..shuffle(seeded);
    for (final p in benchCandidates.take(
      max(0, 18 - _MatchDetailPageState._myTeamRosterOrder.length),
    )) {
      _MatchDetailPageState._myTeamRosterOrder.add(p.name);
      _MatchDetailPageState._myTeamRosterSet.add(p.name);
    }
  }

  // Fill ownership for the whole pool (myTeam / FA / otherTeam).
  for (final n in _MatchDetailPageState._myTeamRosterOrder) {
    _MatchDetailPageState._playerOwnerCache[n] = PlayerOwnership.myTeam;
  }
  for (final p in pool) {
    if (_MatchDetailPageState._playerOwnerCache.containsKey(p.name)) continue;
    _MatchDetailPageState._playerOwnerCache[p.name] =
        _MatchDetailPageState._isFreeAgent(p.name)
            ? PlayerOwnership.freeAgent
            : PlayerOwnership.otherTeam;
  }
}

_PlayerSlot _slotForName(String name) {
  final pool = _MatchDetailPageState._cachedSoccerPlayers;
  if (pool != null) {
    final hit = pool.cast<_PlayerSlot?>().firstWhere(
          (p) => p?.name == name,
          orElse: () => null,
        );
    if (hit != null) return hit;
  }
  final meta = _resolvePlayerMeta(name);
  final seed = _stableSeedFromKey('pts|$name|${meta.club}|${meta.number}');
  return _PlayerSlot(
    name: name,
    score: 5 + (seed % 6),
    position: meta.position,
  );
}

Future<_PlayerSlot?> _pickFromMyRosterSheet(
  BuildContext context, {
  required String title,
  required String subtitle,
}) async {
  _ensureFantasyOwnershipCacheInitialized();
  final order = _MatchDetailPageState._myTeamRosterOrder;
  final startingNames = order.take(min(11, order.length)).toList();
  final benchNames = order.length > 11 ? order.skip(11).toList() : <String>[];

  final starting = startingNames.map(_slotForName).toList();
  final bench = benchNames.map(_slotForName).toList();

  return showModalBottomSheet<_PlayerSlot>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) {
      final theme = Theme.of(ctx);
      final isDark = theme.brightness == Brightness.dark;
      final Color surface =
          isDark ? const Color.fromARGB(255, 30, 30, 30) : theme.cardColor;
      final Color border = isDark ? Colors.white12 : Colors.black12;
      final Color text = isDark ? Colors.white : Colors.black87;
      final Color muted = isDark ? Colors.white70 : Colors.black54;

      Widget header(String t) => Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 6),
            child: Text(
              t,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 16,
                color: text,
              ),
            ),
          );

      Widget row(_PlayerSlot p, {required bool isStarting}) {
        return ListTile(
          dense: true,
          title: Text(
            p.name,
            style: TextStyle(fontWeight: FontWeight.w900, color: text),
          ),
          subtitle: Text(
            '${isStarting ? '스타팅' : '벤치'} · ${p.position} · ${p.score} pts',
            style: TextStyle(fontWeight: FontWeight.w700, color: muted),
          ),
          onTap: () => Navigator.pop(ctx, p),
        );
      }

      return SafeArea(
        child: FractionallySizedBox(
          heightFactor: 0.78,
          child: Container(
            decoration: BoxDecoration(
              color: surface,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(18)),
              border: Border.all(color: border),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                          color: text,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: muted,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.only(
                      left: 6,
                      right: 6,
                      bottom: MediaQuery.of(ctx).viewInsets.bottom + 8,
                    ),
                    children: [
                      if (starting.isNotEmpty) header('Starting 11'),
                      ...starting.map((p) => row(p, isStarting: true)),
                      if (bench.isNotEmpty) header('Bench'),
                      ...bench.map((p) => row(p, isStarting: false)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

void _rebuildCachedMyLineupFromRosterOrder() {
  final lineup = _MatchDetailPageState._cachedSoccerLineup;
  if (lineup == null) return;

  final order = _MatchDetailPageState._myTeamRosterOrder;
  if (order.length < 11) return;
  final starting = order.take(11).map(_slotForName).toList();
  if (!_isValidStartingXI(starting)) return;

  final gk = starting.firstWhere((p) => p.position == 'GK');
  final dfs = starting.where((p) => p.position == 'DF').toList();
  final mfs = starting.where((p) => p.position == 'MF').toList();
  final fws = starting.where((p) => p.position == 'FW').toList();

  final formation = _formationKeyForCounts(
        df: dfs.length,
        mf: mfs.length,
        fw: fws.length,
      ) ??
      lineup.homeFormation;

  final newHome = <_Player>[
    _Player(
      slots: [
        _PlayerSlot(
          name: gk.name,
          score: gk.score,
          position: gk.position,
        ),
      ],
    ),
    _Player(
      slots: dfs
          .map((p) =>
              _PlayerSlot(name: p.name, score: p.score, position: p.position))
          .toList(),
    ),
    _Player(
      slots: mfs
          .map((p) =>
              _PlayerSlot(name: p.name, score: p.score, position: p.position))
          .toList(),
    ),
    _Player(
      slots: fws
          .map((p) =>
              _PlayerSlot(name: p.name, score: p.score, position: p.position))
          .toList(),
    ),
  ];

  _MatchDetailPageState._cachedSoccerLineup = _LineupData(
    home: newHome,
    away: lineup.away,
    homeScore: _sumLineupScores(newHome),
    awayScore: _sumLineupScores(lineup.away),
    homeFormation: formation,
    awayFormation: lineup.awayFormation,
  );
}

Future<void> _signFreeAgentFromProfile(
  BuildContext context,
  String name,
) async {
  _ensureFantasyOwnershipCacheInitialized();

  final own = _MatchDetailPageState._playerOwnerCache[name] ??
      (_MatchDetailPageState._isFreeAgent(name)
          ? PlayerOwnership.freeAgent
          : PlayerOwnership.otherTeam);
  if (own != PlayerOwnership.freeAgent) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('이미 다른 팀에 소속된 선수입니다.')),
    );
    return;
  }

  final fa = _slotForName(name);
  final order = _MatchDetailPageState._myTeamRosterOrder;
  final set = _MatchDetailPageState._myTeamRosterSet;

  if (set.contains(name)) {
    _MatchDetailPageState._playerOwnerCache[name] = PlayerOwnership.myTeam;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$name 선수가 이미 내 로스터에 있습니다.')),
    );
    return;
  }

  if (order.length < 18) {
    order.add(name);
    set.add(name);
    _MatchDetailPageState._playerOwnerCache[name] = PlayerOwnership.myTeam;
    _rebuildCachedMyLineupFromRosterOrder();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${fa.name} 선수를 영입했습니다.')),
    );
    return;
  }

  final released = await _pickFromMyRosterSheet(
    context,
    title: '영입',
    subtitle: '${fa.name} 선수를 영입하려면\n내 로스터에서 방출할 선수를 선택하세요.',
  );
  if (released == null) return;

  final releasedIdx = order.indexOf(released.name);
  if (releasedIdx < 0) return;

  final isStarting = releasedIdx < 11;

  // If releasing a starter, we need a bench replacement with the same position.
  if (isStarting) {
    final benchStart = min(11, order.length);
    final benchNames = order.skip(benchStart).toList();
    final replacementName = benchNames.firstWhere(
      (n) => _slotForName(n).position == released.position,
      orElse: () => '',
    );
    if (replacementName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${released.position} 벤치 선수가 없어서\n이 선수는 방출할 수 없습니다.',
          ),
        ),
      );
      return;
    }

    // Promote replacement into released starter slot.
    order[releasedIdx] = replacementName;
    // Put FA into the vacated bench spot.
    final benchIdx = order.indexOf(replacementName, benchStart);
    order[benchIdx] = fa.name;
  } else {
    // Bench release: just replace.
    order[releasedIdx] = fa.name;
  }

  set
    ..clear()
    ..addAll(order);

  _MatchDetailPageState._playerOwnerCache[released.name] =
      PlayerOwnership.freeAgent;
  _MatchDetailPageState._playerOwnerCache[fa.name] = PlayerOwnership.myTeam;

  _rebuildCachedMyLineupFromRosterOrder();

  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${released.name} 방출 · ${fa.name} 영입 완료')),
    );
  }
}

Future<void> _requestTradeFromProfile(
  BuildContext context,
  String targetName,
) async {
  _ensureFantasyOwnershipCacheInitialized();

  final own = _MatchDetailPageState._playerOwnerCache[targetName] ??
      (_MatchDetailPageState._isFreeAgent(targetName)
          ? PlayerOwnership.freeAgent
          : PlayerOwnership.otherTeam);
  if (own != PlayerOwnership.otherTeam) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('FA 선수는 트레이드가 아니라 영입으로 가능합니다.')),
    );
    return;
  }

  final offered = await _pickFromMyRosterSheet(
    context,
    title: '트레이드 요청',
    subtitle: '$targetName 선수를 원합니다.\n내 로스터에서 제안할 선수를 선택하세요.',
  );
  if (offered == null) return;

  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${offered.name} ↔ $targetName 트레이드 요청을 보냈습니다.'),
      ),
    );
  }
}
