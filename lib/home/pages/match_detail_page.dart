part of '../home_page.dart';

class MatchDetailPage extends StatefulWidget {
  final bool isSoccer;
  final _MatchSection? initialSection;
  final double? overrideHomeScore;
  final double? overrideAwayScore;

  const MatchDetailPage({
    super.key,
    required this.isSoccer,
    this.initialSection,
    this.overrideHomeScore,
    this.overrideAwayScore,
  });

  @override
  State<MatchDetailPage> createState() => _MatchDetailPageState();
}

int _sumLineupScores(List<_Player> rows) =>
    rows.expand((r) => r.slots).fold(0, (a, b) => a + b.score);

_LineupData _recomputeLineupScoreTotals(_LineupData lineup) {
  final homeTotal = _sumLineupScores(lineup.home);
  final awayTotal = _sumLineupScores(lineup.away);
  if (homeTotal == lineup.homeScore && awayTotal == lineup.awayScore) {
    return lineup;
  }
  return _LineupData(
    home: lineup.home,
    away: lineup.away,
    homeScore: homeTotal,
    awayScore: awayTotal,
    homeFormation: lineup.homeFormation,
    awayFormation: lineup.awayFormation,
  );
}

int _stableSeedFromKey(String key) {
  var hash = 0;
  for (final c in key.codeUnits) {
    hash = 0x1fffffff & (hash + c);
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    hash ^= (hash >> 6);
  }
  hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
  hash ^= (hash >> 11);
  hash = 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  return hash & 0x7fffffff;
}

Widget _comingSoonCard(String title, {String? subtitle}) {
  return Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: const Color(0xFFF8F8F8),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.black12),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.hourglass_top, size: 28, color: Colors.black54),
        const SizedBox(height: 10),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.black54, fontSize: 12),
          ),
        ],
      ],
    ),
  );
}

const Map<String, ({int df, int mf, int fw})> _formationOptions = {
  '4-3-3': (df: 4, mf: 3, fw: 3),
  '4-4-2': (df: 4, mf: 4, fw: 2),
  '4-5-1': (df: 4, mf: 5, fw: 1),
  '3-4-3': (df: 3, mf: 4, fw: 3),
  '3-5-2': (df: 3, mf: 5, fw: 2),
  '5-4-1': (df: 5, mf: 4, fw: 1),
  '5-2-3': (df: 5, mf: 2, fw: 3),
};

String? _formationKeyForCounts({
  required int df,
  required int mf,
  required int fw,
}) {
  for (final e in _formationOptions.entries) {
    if (e.value.df == df && e.value.mf == mf && e.value.fw == fw) return e.key;
  }
  return null;
}

bool _isAllowedFormationCounts({required int df, required int mf, required int fw}) =>
    _formationKeyForCounts(df: df, mf: mf, fw: fw) != null;

bool _isValidStartingXI(List<_PlayerSlot> starting) {
  if (starting.length != 11) return false;
  final gk = starting.where((p) => p.position == 'GK').length;
  if (gk != 1) return false;
  final df = starting.where((p) => p.position == 'DF').length;
  final mf = starting.where((p) => p.position == 'MF').length;
  final fw = starting.where((p) => p.position == 'FW').length;
  // Disallow unknown positions in starting XI.
  final known = gk + df + mf + fw;
  if (known != 11) return false;
  return _isAllowedFormationCounts(df: df, mf: mf, fw: fw);
}

List<_PlayerSlot> _buildPlayerPool(Random random) {
  // Use ONLY the updated roster-document players for MatchDetailPage.
  final result = <_PlayerSlot>[];
  for (final e in _docMetaByName.entries) {
    final seed =
        _stableSeedFromKey('pts|${e.key}|${e.value.club}|${e.value.number}');
    result.add(
      _PlayerSlot(
        name: e.key,
        score: 5 + (seed % 6), // 5~10점 (deterministic)
        position: e.value.position,
      ),
    );
  }
  result.shuffle(random);
  return result;
}

class _MatchDetailPageState extends State<MatchDetailPage> {
  // 캐시: 앱을 재시작하기 전까지 로스터/선수 풀 유지
  static _LineupData? _cachedSoccerLineup;
  static List<_PlayerSlot>? _cachedSoccerPlayers;
  static final Map<String, PlayerOwnership> _playerOwnerCache = {};
  // 리그 일정(다른 경기)에서 동일한 점수/라인업을 유지하기 위한 캐시
  static final Map<String, _LineupData> _cachedSoccerFixtureLineups = {};
  static const String _mySoccerFixtureKey = 'S|Round 12|Blue Foxes|Red Bears';
  static final Map<String, List<_PlayerSlot>> _cachedTeamBenches = {};
  // 벤치가 "홈->Matchup 재진입" 때마다 바뀌지 않도록 18명을 순서대로 고정
  static final List<String> _myTeamRosterOrder = [];
  static final Set<String> _myTeamRosterSet = {};

  static bool _isFreeAgent(String name) {
    // 결정론적 배정 (앱 리프레시 전까지 항상 동일)
    final seed = name.codeUnits.fold<int>(0, (p, e) => p + e);
    return (seed % 100) < 15;
  }
  List<_PlayerSlot> _starting = [];
  List<_PlayerSlot> _bench = [];

  int get _myRosterCount => _starting.length + _bench.length;

  void _persistMyRosterToCache() {
    _myTeamRosterOrder
      ..clear()
      ..addAll(_starting.map((e) => e.name))
      ..addAll(_bench.map((e) => e.name));
    _myTeamRosterSet
      ..clear()
      ..addAll(_myTeamRosterOrder);
  }

  Future<void> _trySignFreeAgent(_PlayerSlot fa) async {
    final ownership =
        _MatchDetailPageState._playerOwnerCache[fa.name] ?? PlayerOwnership.freeAgent;
    if (ownership != PlayerOwnership.freeAgent) return;

    // If roster is not full (shouldn't happen often in this demo), just add to bench.
    if (_myRosterCount < 18) {
      setState(() {
        _bench.add(fa);
        _MatchDetailPageState._playerOwnerCache[fa.name] = PlayerOwnership.myTeam;
        _persistMyRosterToCache();
        _applyStartingToLineup();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${fa.name} 선수를 영입했습니다.')),
        );
      }
      return;
    }

    // Roster is full: require releasing one player.
    final released = await showModalBottomSheet<_PlayerSlot>(
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

        Widget row(_PlayerSlot p, {required bool isStarting}) {
          return ListTile(
            dense: true,
            title: Text(
              p.name,
              style: TextStyle(fontWeight: FontWeight.w900, color: text),
            ),
            subtitle: Text(
              '${isStarting ? '스타팅' : '벤치'} · ${p.position}',
              style: TextStyle(fontWeight: FontWeight.w700, color: muted),
            ),
            onTap: () => Navigator.pop(ctx, p),
          );
        }

        return SafeArea(
          child: FractionallySizedBox(
            heightFactor: 0.82,
            child: Container(
              margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: border),
              ),
              child: Column(
                children: [
                  Text(
                    '로스터가 가득 찼습니다 (18명)\n방출할 선수를 선택하세요',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      color: text,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '방출 후 FA 선수가 벤치로 들어갑니다.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: muted,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 4, bottom: 6),
                          child: Text(
                            '스타팅 11',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                              color: muted,
                            ),
                          ),
                        ),
                        for (final p in _starting) row(p, isStarting: true),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.only(left: 4, bottom: 6),
                          child: Text(
                            '벤치 7',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                              color: muted,
                            ),
                          ),
                        ),
                        for (final p in _bench) row(p, isStarting: false),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('취소'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (released == null) return;

    final wasStarting = _starting.contains(released);
    final wasBench = _bench.contains(released);
    if (!wasStarting && !wasBench) return;

    // If releasing a starter, we must promote a bench player of the same position
    // so the starting XI stays valid.
    _PlayerSlot? promoted;
    if (wasStarting) {
      final idx = _bench.indexWhere((b) => b.position == released.position);
      if (idx < 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('해당 포지션의 벤치 선수가 없어 스타팅 방출이 불가합니다.'),
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }
      promoted = _bench.removeAt(idx);
    }

    setState(() {
      // Release
      _starting.remove(released);
      _bench.remove(released);
      _MatchDetailPageState._playerOwnerCache[released.name] =
          PlayerOwnership.freeAgent;

      // Promote if needed
      if (promoted != null) {
        _starting.add(promoted);
      }

      // Sign FA to bench
      _bench.add(fa);
      _MatchDetailPageState._playerOwnerCache[fa.name] = PlayerOwnership.myTeam;

      _persistMyRosterToCache();
      _applyStartingToLineup();
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${released.name} 방출 · ${fa.name} 영입 완료')),
      );
    }
  }

  Future<_PlayerSlot?> _pickMyRosterPlayerSheet({
    required String title,
    String? subtitle,
  }) async {
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

        Widget row(_PlayerSlot p, {required bool isStarting}) {
          return ListTile(
            dense: true,
            title: Text(
              p.name,
              style: TextStyle(fontWeight: FontWeight.w900, color: text),
            ),
            subtitle: Text(
              '${isStarting ? '스타팅' : '벤치'} · ${p.position}',
              style: TextStyle(fontWeight: FontWeight.w700, color: muted),
            ),
            onTap: () => Navigator.pop(ctx, p),
          );
        }

        return SafeArea(
          child: FractionallySizedBox(
            heightFactor: 0.82,
            child: Container(
              margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: border),
              ),
              child: Column(
                children: [
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      color: text,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: muted,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 4, bottom: 6),
                          child: Text(
                            '스타팅 11',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                              color: muted,
                            ),
                          ),
                        ),
                        for (final p in _starting) row(p, isStarting: true),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.only(left: 4, bottom: 6),
                          child: Text(
                            '벤치 7',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                              color: muted,
                            ),
                          ),
                        ),
                        for (final p in _bench) row(p, isStarting: false),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('취소'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _requestTrade(_PlayerSlot target) async {
    final own = _MatchDetailPageState._playerOwnerCache[target.name] ??
        PlayerOwnership.freeAgent;
    if (own != PlayerOwnership.otherTeam) return;

    final offered = await _pickMyRosterPlayerSheet(
      title: '트레이드 요청',
      subtitle: '${target.name} 선수를 원합니다.\n내 로스터에서 제안할 선수를 선택하세요.',
    );
    if (offered == null) return;

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${offered.name} ↔ ${target.name} 트레이드 요청을 보냈습니다.')),
    );
  }

  void _applyStartingToLineup() {
    if (_lineup == null || _starting.isEmpty) return;
    final flat = List<_PlayerSlot>.from(_starting);
    // ensure 11 players by padding with bench if needed
    if (flat.length < 11 && _bench.isNotEmpty) {
      flat.addAll(_bench.take(11 - flat.length));
    }
    if (flat.length < 11) return;
    // Determine formation based on starting XI positions.
    final gks = flat.where((p) => p.position == 'GK').toList();
    final dfs = flat.where((p) => p.position == 'DF').toList();
    final mfs = flat.where((p) => p.position == 'MF').toList();
    final fws = flat.where((p) => p.position == 'FW').toList();

    final int dfCount = dfs.length;
    final int mfCount = mfs.length;
    final int fwCount = fws.length;
    final formationName = _formationKeyForCounts(
          df: dfCount,
          mf: mfCount,
          fw: fwCount,
        ) ??
        _lineup!.homeFormation;

    // Build home rows in GK -> DF -> MF -> FW order (Matchup view expects this).
    final gkSlot = (gks.isNotEmpty ? gks.first : flat.first);
    // Never place a DF into FW lane etc: each lane strictly uses its own position list.
    final dfSlots = List<_PlayerSlot>.from(dfs);
    final mfSlots = List<_PlayerSlot>.from(mfs);
    final fwSlots = List<_PlayerSlot>.from(fws);

    final newHome = <_Player>[
      _Player(slots: [
        _PlayerSlot(name: gkSlot.name, score: gkSlot.score, position: gkSlot.position),
      ]),
      _Player(
        slots: dfSlots
            .map((p) => _PlayerSlot(name: p.name, score: p.score, position: p.position))
            .toList(),
      ),
      _Player(
        slots: mfSlots
            .map((p) => _PlayerSlot(name: p.name, score: p.score, position: p.position))
            .toList(),
      ),
      _Player(
        slots: fwSlots
            .map((p) => _PlayerSlot(name: p.name, score: p.score, position: p.position))
            .toList(),
      ),
    ];

    // 선수 포인트는 고정, 스코어는 라인업 합산 값으로 변동되게 한다.
    // (override 점수로 다시 스케일링하지 않음)
    final next = _LineupData(
      home: newHome,
      away: _lineup!.away,
      homeScore: _sumLineupScores(newHome),
      awayScore: _sumLineupScores(_lineup!.away),
      homeFormation: formationName,
      awayFormation: _lineup!.awayFormation,
    );
    _lineup = next;
    _cachedSoccerLineup = _lineup;
    if (_cachedSoccerLineup != null) {
      _cachedSoccerFixtureLineups[_mySoccerFixtureKey] = _cachedSoccerLineup!;
    }
  }

  static String _soccerFixtureKey(_FixtureScore f) =>
      'S|${f.roundLabel}|${f.home}|${f.away}';

  static _LineupData getOrCreateSoccerFixtureLineup(_FixtureScore f) {
    final key = _soccerFixtureKey(f);
    if (key == _mySoccerFixtureKey && _cachedSoccerLineup != null) {
      final fixed = _recomputeLineupScoreTotals(_cachedSoccerLineup!);
      _cachedSoccerLineup = fixed;
      _cachedSoccerFixtureLineups[key] = fixed;
      return fixed;
    }

    final hit = _cachedSoccerFixtureLineups[key];
    if (hit != null) return _recomputeLineupScoreTotals(hit);

    final seeded = Random(_stableSeedFromKey(key));
    final created = _generateLineup(isSoccer: true, random: seeded);
    final fixed = _recomputeLineupScoreTotals(created);
    _cachedSoccerFixtureLineups[key] = fixed;

    // 리그 일정에서 내 경기를 먼저 열었을 때도 Matchup details와 점수가 일치하게 캐시를 채움
    if (key == _mySoccerFixtureKey && _cachedSoccerLineup == null) {
      _cachedSoccerLineup = fixed;
    }
    return fixed;
  }

  static List<_PlayerSlot> getOrCreateTeamBench({
    required String teamName,
    required List<_PlayerSlot> starting,
  }) {
    final key = 'B|$teamName';
    final cached = _cachedTeamBenches[key];
    if (cached != null) return List<_PlayerSlot>.from(cached);

    // Player pool should be stable across the app session.
    _cachedSoccerPlayers ??= _buildPlayerPool(Random(0));
    final pool = _cachedSoccerPlayers ?? const <_PlayerSlot>[];
    final startingNames = starting.map((e) => e.name).toSet();
    final candidates =
        pool.where((p) => !startingNames.contains(p.name)).toList();
    candidates.shuffle(Random(_stableSeedFromKey('$key|bench')));
    final bench = candidates.take(7).map((p) => _PlayerSlot(
          name: p.name,
          score: p.score,
          position: p.position,
        )).toList();
    _cachedTeamBenches[key] = bench;
    return List<_PlayerSlot>.from(bench);
  }

  void _swapPlayers(_PlayerSlot from, _PlayerSlot to) {
    final prevStarting = List<_PlayerSlot>.from(_starting);
    final prevBench = List<_PlayerSlot>.from(_bench);

    final fromStart = _starting.contains(from);
    final toStart = _starting.contains(to);

    // Tentatively apply swap.
    if (fromStart && toStart) {
      final i = _starting.indexOf(from);
      final j = _starting.indexOf(to);
      final tmp = _starting[i];
      _starting[i] = _starting[j];
      _starting[j] = tmp;
    } else if (!fromStart && !toStart) {
      final i = _bench.indexOf(from);
      final j = _bench.indexOf(to);
      final tmp = _bench[i];
      _bench[i] = _bench[j];
      _bench[j] = tmp;
    } else if (fromStart && !toStart) {
      final i = _starting.indexOf(from);
      final j = _bench.indexOf(to);
      _starting[i] = to;
      _bench[j] = from;
    } else {
      final i = _bench.indexOf(from);
      final j = _starting.indexOf(to);
      _bench[i] = to;
      _starting[j] = from;
    }

    // Enforce that starting XI always matches one of the allowed formations,
    // and positions never get "forced" into other lanes.
    if (!_isValidStartingXI(_starting)) {
      _starting = prevStarting;
      _bench = prevBench;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('이 교체는 허용되지 않는 포메이션이 됩니다. 다른 선수로 교체해 주세요.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() {});
    // 스왑 결과를 캐시에 반영해서 화면 재진입해도 유지
    _persistMyRosterToCache();
    _applyStartingToLineup();
  }

  final GlobalKey<_LeagueItSubAppBarState> _appBarKey =
      GlobalKey<_LeagueItSubAppBarState>();
  bool _isMyPageOpen = false;
  late _MatchSection _section;
  _LineupData? _lineup;
  late final List<_PlayerSlot> _allPlayers;
  String _playerSearch = '';
  bool _showOnlyFreeAgents = false;

  @override
  void initState() {
    super.initState();
    _section = widget.initialSection ?? _MatchSection.matchup;
    final random = Random();
    if (widget.isSoccer) {
      _lineup =
          _cachedSoccerLineup ?? _generateLineup(isSoccer: true, random: random);
      if (_lineup != null) {
        _lineup = _recomputeLineupScoreTotals(_lineup!);
      }
      _cachedSoccerLineup = _lineup;
      if (_cachedSoccerLineup != null) {
        _cachedSoccerFixtureLineups[_mySoccerFixtureKey] = _cachedSoccerLineup!;
      }
      _cachedSoccerPlayers ??= _buildPlayerPool(random);
      _allPlayers = _cachedSoccerPlayers!;
      _assignOwnership(random);
      _initRosterLists();
    } else {
      _lineup = null;
      _allPlayers = [];
    }
  }

  void _assignOwnership(Random random) {
    // 1) 내 로스터(18)는 최초 1회만 생성하고 계속 유지
    if (_myTeamRosterOrder.isEmpty) {
      final starting = _lineup?.home
              .expand((p) => p.slots)
              .map((s) => s.name)
              .toList() ??
          [];
      _myTeamRosterOrder
        ..clear()
        ..addAll(starting);
      _myTeamRosterSet
        ..clear()
        ..addAll(starting);

      final benchCandidates = _allPlayers
          .where((p) => !_myTeamRosterSet.contains(p.name))
          .toList()
        ..shuffle(random);
      for (final p
          in benchCandidates.take(max(0, 18 - _myTeamRosterOrder.length))) {
        _myTeamRosterOrder.add(p.name);
        _myTeamRosterSet.add(p.name);
      }
    }

    // 2) 내 로스터는 항상 내 팀 소유
    for (final n in _myTeamRosterOrder) {
      _playerOwnerCache[n] = PlayerOwnership.myTeam;
    }

    // 3) 상대 라인업은 다른 팀 소유(내 팀으로 고정된 선수는 덮어쓰지 않음)
    final awayNames = _lineup?.away
            .expand((p) => p.slots)
            .map((s) => s.name)
            .toList() ??
        [];
    for (final n in awayNames) {
      if (_playerOwnerCache[n] == PlayerOwnership.myTeam) continue;
      _playerOwnerCache[n] = PlayerOwnership.otherTeam;
    }

    // 4) 나머지는 결정론적으로 FA/다른 팀으로 고정
    for (final p in _allPlayers) {
      if (_playerOwnerCache.containsKey(p.name)) continue;
      _playerOwnerCache[p.name] =
          _isFreeAgent(p.name) ? PlayerOwnership.freeAgent : PlayerOwnership.otherTeam;
    }
  }

  void _initRosterLists() {
    final ownedPlayers = _allPlayers
        .where((p) => _playerOwnerCache[p.name] == PlayerOwnership.myTeam)
        .toList();
    // 유지된 이름 순서대로 정렬
    final orderedNames = _myTeamRosterOrder.isNotEmpty
        ? List<String>.from(_myTeamRosterOrder)
        : ownedPlayers.map((p) => p.name).toList();
    final ordered = <_PlayerSlot>[];
    for (final n in orderedNames) {
      final hit =
          ownedPlayers.firstWhere((p) => p.name == n, orElse: () => _PlayerSlot(name: n, score: 0, position: 'FW'));
      if (!ordered.contains(hit)) ordered.add(hit);
    }
    // 부족하면 채우기
    for (final p in ownedPlayers) {
      if (!ordered.contains(p)) ordered.add(p);
    }
    _starting = ordered.take(11).toList();
    _bench = ordered.skip(11).take(7).toList();
    _applyStartingToLineup();
  }


  @override
  Widget build(BuildContext context) {
    if (!kUseMockDataOutsideDraft) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: LeagueItSubAppBar(
          key: _appBarKey,
          onMyPageTap: () => setState(() => _isMyPageOpen = !_isMyPageOpen),
          showSearch: false,
        ),
        body: Stack(
          children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _comingSoonCard(
                  '실데이터 연동 준비 중',
                  subtitle:
                      'Matchup, Roster, Players, League 데이터는 API/Firebase 연동 후 제공됩니다.\n(Mock은 Draft 연습에서만 사용)',
                ),
              ),
            ),
            if (_isMyPageOpen)
              GestureDetector(
                onTap: () => setState(() => _isMyPageOpen = false),
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

    final String homeEmoji = widget.isSoccer ? '🦊' : '🦁';
    final String awayEmoji = widget.isSoccer ? '🐻' : '🐯';
    final double defaultWinPct = widget.isSoccer ? 0.73 : 0.58;
    const String homeRecord = 'W3 D1 L1';
    const String awayRecord = 'W2 D2 L1';
    final double homeScoreDisplay = widget.isSoccer
        ? (_lineup?.homeScore.toDouble() ?? 0)
        : (widget.overrideHomeScore ?? (_lineup?.homeScore.toDouble() ?? 0));
    final double awayScoreDisplay = widget.isSoccer
        ? (_lineup?.awayScore.toDouble() ?? 0)
        : (widget.overrideAwayScore ?? (_lineup?.awayScore.toDouble() ?? 0));
    final double totalScore = homeScoreDisplay + awayScoreDisplay;
    final double winPctHome = totalScore > 0
        ? homeScoreDisplay / totalScore
        : defaultWinPct;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: LeagueItSubAppBar(
        key: _appBarKey,
        onMyPageTap: () => setState(() => _isMyPageOpen = !_isMyPageOpen),
        showSearch: false,
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () {
          FocusScope.of(context).unfocus();
          _appBarKey.currentState?.closeSearch();
        },
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      _CategoryChip(
                        label: 'Match up',
                        active: _section == _MatchSection.matchup,
                        onTap: () =>
                            setState(() => _section = _MatchSection.matchup),
                      ),
                      _CategoryChip(
                        label: 'Roster',
                        active: _section == _MatchSection.roster,
                        onTap: () =>
                            setState(() => _section = _MatchSection.roster),
                      ),
                      _CategoryChip(
                        label: 'Players',
                        active: _section == _MatchSection.players,
                        onTap: () =>
                            setState(() => _section = _MatchSection.players),
                      ),
                      _CategoryChip(
                        label: 'League',
                        active: _section == _MatchSection.league,
                        onTap: () =>
                            setState(() => _section = _MatchSection.league),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (_section == _MatchSection.matchup && widget.isSoccer) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _TeamBadge(
                          emoji: homeEmoji,
                          label: '${(winPctHome * 100).round()}%',
                        ),
                        Column(
                          children: [
                            Text(
                              (widget.isSoccer &&
                                      (_lineup != null ||
                                          widget.overrideHomeScore != null))
                                  ? '${homeScoreDisplay.toStringAsFixed(0)} vs ${awayScoreDisplay.toStringAsFixed(0)}'
                                  : '준비 중',
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Win probability',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                        _TeamBadge(
                          emoji: awayEmoji,
                          label: '${((1 - winPctHome) * 100).round()}%',
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _WinBar(homeRatio: winPctHome),
                    const SizedBox(height: 12),
                  ],
                  if (_section == _MatchSection.matchup && !widget.isSoccer) ...[
                    _comingSoonCard(
                      'KBO Match up은 준비 중입니다.',
                      subtitle: '현재는 K League(축구) 매치업만 지원해요.',
                    ),
                    const SizedBox(height: 12),
                  ],
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                child: _buildSectionContent(
                  key: ValueKey(_section),
                  context: context,
                  section: _section,
                  lineup: _lineup,
                  isSoccer: widget.isSoccer,
                  allPlayers: _allPlayers,
                  startingSlots: _starting,
                  benchSlots: _bench,
                  onSwapPlayer: _swapPlayers,
                  onSignFreeAgent: _trySignFreeAgent,
                  onTradeRequest: _requestTrade,
                  homeRecord: homeRecord,
                  awayRecord: awayRecord,
                  searchQuery: _playerSearch,
                  showOnlyFreeAgents: _showOnlyFreeAgents,
                  onToggleShowOnlyFreeAgents: (v) =>
                      setState(() => _showOnlyFreeAgents = v),
                  onSearchChanged: (text) =>
                      setState(() => _playerSearch = text.trim()),
                ),
                ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
            IgnorePointer(
              ignoring: !_isMyPageOpen,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOut,
                opacity: _isMyPageOpen ? 1 : 0,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _isMyPageOpen = false),
                  child: Container(color: Colors.black.withOpacity(0.35)),
                ),
              ),
            ),
            Positioned(
              top: 100,
              right: 24,
              child: IgnorePointer(
                ignoring: !_isMyPageOpen,
                child: AnimatedSlide(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  offset: _isMyPageOpen ? Offset.zero : const Offset(0.10, -0.06),
                  child: AnimatedScale(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutCubic,
                    scale: _isMyPageOpen ? 1.0 : 0.96,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOut,
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void _showInlinePlayerCard(
  BuildContext context,
  _PlayerSlot slot, {
  PlayerOwnership ownership = PlayerOwnership.freeAgent,
}) {
  showDialog(
    context: context,
    barrierColor: Colors.black45,
    builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Theme.of(
              context,
            ).colorScheme.primary.withOpacity(.12),
            child: Text(
              slot.name.characters.first,
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w800,
                fontSize: 22,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            slot.name,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            '${slot.position} · ${slot.score} pts',
            style: const TextStyle(fontSize: 14, color: Colors.black54),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PlayerProfilePage(
                  name: slot.name,
                  ownership: ownership,
                ),
              ),
            );
          },
          child: const Text('프로필'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('닫기'),
        ),
      ],
    ),
  );
}

enum _MatchSection { matchup, roster, players, league }

Widget _buildSectionContent({
  Key? key,
  required BuildContext context,
  required _MatchSection section,
  _LineupData? lineup,
  required bool isSoccer,
  List<_PlayerSlot>? allPlayers,
  List<_PlayerSlot>? startingSlots,
  List<_PlayerSlot>? benchSlots,
  void Function(_PlayerSlot, _PlayerSlot)? onSwapPlayer,
  Future<void> Function(_PlayerSlot)? onSignFreeAgent,
  Future<void> Function(_PlayerSlot)? onTradeRequest,
  required String homeRecord,
  required String awayRecord,
  String searchQuery = '',
  bool showOnlyFreeAgents = false,
  void Function(bool)? onToggleShowOnlyFreeAgents,
  void Function(String)? onSearchChanged,
}) {
  switch (section) {
    case _MatchSection.matchup:
      if (lineup != null) {
        return _LineupField(
          key: key,
          lineup: lineup,
          isSoccer: true,
          homeRecord: homeRecord,
          awayRecord: awayRecord,
          onPlayerTap: (slot) => _showInlinePlayerCard(
            context,
            slot,
            ownership: _MatchDetailPageState._playerOwnerCache[slot.name] ??
                PlayerOwnership.freeAgent,
          ),
        );
      }
      return Container(
        key: key,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black12),
        ),
        child: const Text(
          'KBO 매치업 상세는 준비 중입니다.',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      );

    case _MatchSection.roster:
      if (!isSoccer) {
        return _comingSoonCard(
          'KBO Roster는 준비 중입니다.',
          subtitle: '현재는 K League(축구)만 지원해요.',
        );
      }
      final startList = startingSlots ?? [];
      final benchList = benchSlots ?? [];
      if (startList.isEmpty && benchList.isEmpty && lineup == null && (allPlayers == null || allPlayers.isEmpty)) {
        return const SizedBox.shrink();
      }

      void openMyPlayerProfile(_PlayerSlot p) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                PlayerProfilePage(name: p.name, ownership: PlayerOwnership.myTeam),
          ),
        );
      }

      if (!isSoccer || lineup == null) {
        // KBO or missing lineup: keep simple lists.
        return Container(
          key: key,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F8F8),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.black12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'My Team',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              const Text('Starting', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              _DraggableRosterList(
                players: startList,
                onSwap: onSwapPlayer,
                onTap: openMyPlayerProfile,
              ),
              const SizedBox(height: 12),
              const Text('Bench', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              _DraggableRosterList(
                players: benchList,
                showMeta: true,
                onSwap: onSwapPlayer,
                onTap: openMyPlayerProfile,
              ),
            ],
          ),
        );
      }

      final rosterByName = <String, _PlayerSlot>{
        for (final p in [...startList, ...benchList]) p.name: p,
      };
      final homeRows = lineup.home;
      final displayRows = homeRows.isNotEmpty &&
              homeRows.first.slots.isNotEmpty &&
              homeRows.first.slots.first.position == 'GK'
          ? homeRows.reversed.toList()
          : homeRows;

      return Container(
        key: key,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F8F8),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'My Roster',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            _RosterHalfPitch(
              rows: displayRows,
              rosterByName: rosterByName,
              color: Colors.blueAccent,
              onSwap: onSwapPlayer,
              onTap: openMyPlayerProfile,
            ),
            const SizedBox(height: 12),
            const Text('Bench', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            _DraggableRosterList(
              players: benchList,
              showMeta: true,
              onSwap: onSwapPlayer,
              onTap: openMyPlayerProfile,
            ),
          ],
        ),
      );

    case _MatchSection.league:
      if (!isSoccer) {
        return _comingSoonCard(
          'KBO League 탭은 준비 중입니다.',
          subtitle: '리그 순위/일정/파워랭킹 기능을 준비하고 있어요.',
        );
      }
      // Shared mock standings (also used in My League) so ranks stay consistent.
      final standings = _fantasyLeagueStandings(isSoccer: isSoccer);

      final fixtures = isSoccer
          ? [
              'Round 12 · Blue Foxes vs Red Bears',
              'Round 12 · White Tigers vs Green Hawks',
              'Round 12 · Sky Giants vs Orange Wolves',
              'Round 12 · Mint Dolphins vs Purple Knights',
              'Round 12 · Silver Sharks vs Golden Owls',
            ]
          : [
              'Round 68 · Sluggers vs Bombers',
              'Round 68 · Titans vs Waves',
              'Round 69 · Rockets vs Knights',
              'Round 69 · Sparks vs Mariners',
              'Round 69 · Bulls vs Bears',
            ];

      final power = isSoccer
          ? [
              {'team': 'Blue Foxes', 'form': 'W D W'},
              {'team': 'Red Bears', 'form': 'W W W'},
              {'team': 'White Tigers', 'form': 'W W L'},
              {'team': 'Green Hawks', 'form': 'D W W'},
              {'team': 'Sky Giants', 'form': 'W D L'},
              {'team': 'Orange Wolves', 'form': 'D W L'},
              {'team': 'Mint Dolphins', 'form': 'W L W'},
              {'team': 'Purple Knights', 'form': 'D D W'},
              {'team': 'Silver Sharks', 'form': 'L W W'},
              {'team': 'Golden Owls', 'form': 'L L W'},
            ]
          : [
              {'team': 'Bombers', 'form': 'W W W'},
              {'team': 'Sluggers', 'form': 'W W L'},
              {'team': 'Titans', 'form': 'W D W'},
              {'team': 'Waves', 'form': 'L W W'},
              {'team': 'Rockets', 'form': 'W L W'},
              {'team': 'Knights', 'form': 'W W L'},
              {'team': 'Sparks', 'form': 'D W L'},
              {'team': 'Mariners', 'form': 'L D W'},
              {'team': 'Bulls', 'form': 'W L L'},
              {'team': 'Bears', 'form': 'L L W'},
            ];

      // 전체 선수 중 상위 30명 → podium 상위 3, 세부 화면은 30명 리스트
      List<_PlayerSlot> allPool;
      if (allPlayers != null && allPlayers.isNotEmpty) {
        allPool = List<_PlayerSlot>.from(allPlayers);
      } else if (lineup != null) {
        allPool = [
          ...lineup.home.expand((r) => r.slots),
          ...lineup.away.expand((r) => r.slots),
        ];
      } else {
        allPool = [
          _PlayerSlot(name: '이승우', score: 12, position: 'FW'),
          _PlayerSlot(name: '조현우', score: 11, position: 'GK'),
          _PlayerSlot(name: '박성훈', score: 10, position: 'MF'),
        ];
      }
      allPool.sort((a, b) => b.score.compareTo(a.score));
      final top30 = allPool.take(30).toList();
      final podium = top30.take(3).toList();

      void pushDetail(String title, List<String> items) {
        if (title == '리그 일정') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => _FixtureCardsPage(isSoccer: isSoccer),
            ),
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  _SimpleListPage(title: title, items: items, isSoccer: isSoccer),
            ),
          );
        }
      }

      Widget buildList(String title, List<String> items) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              dense: true,
              title: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              trailing: const Icon(Icons.chevron_right, size: 18),
              onTap: () => pushDetail(title, items),
            ),
            const SizedBox(height: 4),
          ],
        );
      }

      Widget podiumView() {
        const heights = [150.0, 130.0, 110.0]; // 1위 중앙, 2위 왼쪽, 3위 오른쪽
        final displayOrder = [1, 0, 2]; // left=2nd, center=1st, right=3rd
        final topPlayers = podium.take(3).toList();
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => _PlayerOfWeekPage(players: top30),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F8F8),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.black12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '이주의 선수',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(topPlayers.length, (displayIdx) {
                    final podiumIdx = displayOrder[displayIdx];
                    final p = topPlayers[podiumIdx];
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          width: 70,
                          height: heights[podiumIdx],
                          decoration: BoxDecoration(
                            color: Colors.blueGrey.shade100,
                            border: Border.all(color: Colors.black26),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              '${podiumIdx + 1}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 22,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          p.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          '${p.position} · ${p.score} pts',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    );
                  }),
                ),
              ],
            ),
          ),
        );
      }

      return Column(
        key: key,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          buildList(
            '리그 순위',
            standings
                .map(
                  (e) =>
                      '${standings.indexOf(e) + 1}. ${e.team} · ${e.pts} pts',
                )
                .toList(),
          ),
          buildList('리그 일정', fixtures),
          buildList(
            '파워 랭킹',
            power
                .map(
                  (p) => '${power.indexOf(p) + 1}. ${p['team']} · ${p['form']}',
                )
                .toList(),
          ),
          podiumView(),
        ],
      );

    case _MatchSection.players:
      if (!isSoccer) {
        return _comingSoonCard(
          'KBO Players는 준비 중입니다.',
          subtitle: '현재는 K League(축구) 선수만 검색/프로필을 지원해요.',
        );
      }
      if (allPlayers == null || allPlayers.isEmpty) {
        return Container(
          key: key,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F8F8),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.black12),
          ),
          child: const Text(
            'KBO에서는 선수 목록을 준비 중입니다.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        );
      }
      final allSlots = allPlayers;
      final q = searchQuery.toLowerCase();
      PlayerOwnership ownOf(_PlayerSlot p) =>
          _MatchDetailPageState._playerOwnerCache[p.name] ??
          PlayerOwnership.freeAgent;
      final slotsAfterFa = showOnlyFreeAgents
          ? allSlots.where((p) => ownOf(p) == PlayerOwnership.freeAgent).toList()
          : allSlots;
      final filtered = q.isEmpty
          ? slotsAfterFa
          : slotsAfterFa
              .where((p) => p.name.toLowerCase().contains(q))
              .toList();
      final faCount =
          allSlots.where((p) => ownOf(p) == PlayerOwnership.freeAgent).length;
      return Container(
        key: key,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F8F8),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'All Players',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            TextField(
              decoration: InputDecoration(
                hintText: '선수 이름 검색',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Colors.black12),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              onChanged: onSearchChanged,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                FilterChip(
                  label: const Text(
                    'FA',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  selected: showOnlyFreeAgents,
                  onSelected: (v) => onToggleShowOnlyFreeAgents?.call(v),
                  selectedColor: Colors.blueGrey.withOpacity(0.14),
                  checkmarkColor: Colors.blueGrey,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                    side: const BorderSide(color: Colors.black12),
                  ),
                ),
                const Spacer(),
                Text(
                  'FA $faCount',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (filtered.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 22),
                alignment: Alignment.center,
                child: Text(
                  showOnlyFreeAgents
                      ? '현재 조건에 맞는 FA 선수가 없습니다.'
                      : '검색 결과가 없습니다.',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.black54,
                  ),
                ),
              ),
            ...filtered.map(
              (p) {
                final ownership = ownOf(p);

                Color statusColor(PlayerOwnership o) => switch (o) {
                      PlayerOwnership.myTeam => Colors.green,
                      PlayerOwnership.otherTeam => Colors.redAccent,
                      PlayerOwnership.freeAgent => Colors.blueGrey,
                    };

                String statusLabel(PlayerOwnership o) => switch (o) {
                      PlayerOwnership.myTeam => '내 팀',
                      PlayerOwnership.otherTeam => '다른 팀',
                      PlayerOwnership.freeAgent => 'FA',
                    };

                return Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: statusColor(ownership).withOpacity(0.14),
                            border: Border.all(
                              color: statusColor(ownership),
                              width: 1.2,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          statusLabel(ownership),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: statusColor(ownership),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PlayerProfilePage(
                                    name: p.name,
                                    ownership: ownership,
                                    onSign: ownership == PlayerOwnership.freeAgent
                                        ? () => onSignFreeAgent?.call(p) ?? Future.value()
                                        : null,
                                    onTradeRequest:
                                        ownership == PlayerOwnership.otherTeam
                                            ? () => onTradeRequest?.call(p) ??
                                                Future.value()
                                            : null,
                                  ),
                                ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    p.name,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${p.position} · ${_resolvePlayerMeta(p.name).club}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.black54,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        if (ownership == PlayerOwnership.freeAgent)
                          InkWell(
                            onTap: () => onSignFreeAgent?.call(p),
                            borderRadius: BorderRadius.circular(999),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: Colors.green,
                                  width: 1.2,
                                ),
                              ),
                              child: const Text(
                                '영입',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.green,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const Divider(
                      height: 12,
                      thickness: 1,
                      color: Colors.black12,
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      );
  }
}

class _LineupField extends StatelessWidget {
  final _LineupData lineup;
  final bool isSoccer;
  final String homeRecord;
  final String awayRecord;
  final void Function(_PlayerSlot) onPlayerTap;

  const _LineupField({
    Key? key,
    required this.lineup,
    required this.isSoccer,
    required this.homeRecord,
    required this.awayRecord,
    required this.onPlayerTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final Color homeColor = Colors.blueAccent;
    final Color awayColor = Colors.redAccent;
    const double margin = 16;
    const double padding = 24;
    final int maxRows = max(lineup.home.length, lineup.away.length);
    final double halfHeight = max(
      260.0,
      (maxRows <= 1 ? 120.0 : 70.0 * (maxRows - 1) + 120.0),
    );
    final double fieldHeight = margin * 2 + halfHeight * 2;

    return SizedBox(
      height: fieldHeight,
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _PitchPainter())),
          Positioned(
            left: 10,
            top: 10,
            child: Text(
              homeRecord,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
          ),
          Positioned(
            right: 10,
            bottom: 10,
            child: Text(
              awayRecord,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
          ),
          ..._positionRows(
            rows: lineup.home,
            top: margin,
            height: halfHeight,
            padding: padding,
            isHome: true,
            color: homeColor,
            onTap: onPlayerTap,
          ),
          ..._positionRows(
            rows: lineup.away,
            top: margin + halfHeight,
            height: halfHeight,
            padding: padding,
            isHome: false,
            color: awayColor,
            onTap: onPlayerTap,
          ),
        ],
      ),
    );
  }
}

class _LineupRow extends StatelessWidget {
  final _Player players;
  final Color color;
  final void Function(_PlayerSlot) onTap;

  const _LineupRow({
    required this.players,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: players.slots
            .map(
              (slot) => _PlayerChip(
                slot: slot,
                color: color,
                onTap: () => onTap(slot),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _PlayerChip extends StatelessWidget {
  final _PlayerSlot slot;
  final Color color;
  final VoidCallback? onTap;

  const _PlayerChip({required this.slot, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 1.6),
            ),
            child: Center(
              child: Text(
                '${slot.score}',
                style: TextStyle(fontWeight: FontWeight.w700, color: color),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          slot.name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      ],
    );
  }
}

class _WinBar extends StatelessWidget {
  final double homeRatio;
  const _WinBar({required this.homeRatio});

  @override
  Widget build(BuildContext context) {
    const double radius = 10;
    const double borderW = 1.2;

    final rOuter = BorderRadius.circular(radius);
    final rInner = BorderRadius.circular(max(0, radius - borderW));
    final double ratio = homeRatio.isNaN ? 0.5 : homeRatio.clamp(0.0, 1.0);

    const Color homeColor = Color(0xFFCCE6FF);
    const Color awayColor = Color(0xFFFFE6CC);

    // Outer border + inner clipped fill so the border never gets painted over.
    return Container(
      height: 14,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: rOuter,
        border: Border.all(color: Colors.black87, width: borderW),
      ),
      padding: const EdgeInsets.all(borderW),
      child: ClipRRect(
        borderRadius: rInner,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final homeW = w * ratio;
            return Stack(
              fit: StackFit.expand,
              children: [
                const Positioned.fill(child: ColoredBox(color: awayColor)),
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: homeW,
                  child: const ColoredBox(color: homeColor),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SimpleListPage extends StatefulWidget {
  final String title;
  final List<String> items;
  final bool isSoccer;
  const _SimpleListPage({
    required this.title,
    required this.items,
    required this.isSoccer,
  });

  @override
  State<_SimpleListPage> createState() => _SimpleListPageState();
}

class _SimpleListPageState extends State<_SimpleListPage> {
  bool _isMyPageOpen = false;
  void _toggleMyPage() => setState(() => _isMyPageOpen = !_isMyPageOpen);

  String _extractTeamName(String raw) {
    var s = raw.trim();
    final dot = s.indexOf('.');
    if (dot != -1) s = s.substring(dot + 1).trim();
    final mid = s.indexOf('·');
    if (mid != -1) s = s.substring(0, mid).trim();
    return s;
  }

  @override
  Widget build(BuildContext context) {
    final isStanding = widget.title == '리그 순위';
    final isPower = widget.title == '파워 랭킹';
    return _OverlayScaffold(
      isMyPageOpen: _isMyPageOpen,
      onToggleMyPage: _toggleMyPage,
      title: 'LeagueIt',
      showSearch: false,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: widget.items.length,
        separatorBuilder: (_, __) => const SizedBox.shrink(),
        itemBuilder: (_, i) {
          if (isStanding) {
            final colors = [Colors.green, Colors.blue, Colors.teal, Colors.grey];
            final color = colors[(i ~/ 3).clamp(0, colors.length - 1)];
            return Column(
              children: [
                ListTile(
                  dense: true,
                  tileColor:
                      i.isEven ? color.withOpacity(0.06) : color.withOpacity(0.03),
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${i + 1}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                  title: Text(
                    widget.items[i],
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                  onTap: widget.isSoccer
                      ? () {
                          final team = _extractTeamName(widget.items[i]);
                          final myTeam =
                              widget.isSoccer ? 'Blue Foxes' : 'Seoul Sluggers';
                          if (team == myTeam) {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => MatchDetailPage(
                                  isSoccer: widget.isSoccer,
                                  initialSection: _MatchSection.roster,
                                ),
                              ),
                            );
                            return;
                          }
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => _TeamSquadPage(teamName: team),
                            ),
                          );
                        }
                      : null,
                ),
                const Divider(height: 1, thickness: 1, color: Color(0xFFEAEAEA)),
              ],
            );
          } else if (isPower) {
            final color = i < 3 ? Colors.orange : Colors.deepPurple;
            return Column(
              children: [
                ListTile(
                  dense: true,
                  tileColor:
                      i.isEven ? color.withOpacity(0.07) : color.withOpacity(0.03),
                  leading: Icon(Icons.bolt, color: color),
                  title: Text(
                    widget.items[i],
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14.5,
                    ),
                  ),
                  subtitle: Text(
                    'Power rank ${i + 1}',
                    style: TextStyle(
                      fontSize: 12,
                      color: color.withOpacity(0.8),
                    ),
                  ),
                  trailing: Icon(Icons.trending_up, color: color),
                  onTap: widget.isSoccer
                      ? () {
                          final team = _extractTeamName(widget.items[i]);
                          final myTeam =
                              widget.isSoccer ? 'Blue Foxes' : 'Seoul Sluggers';
                          if (team == myTeam) {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => MatchDetailPage(
                                  isSoccer: widget.isSoccer,
                                  initialSection: _MatchSection.roster,
                                ),
                              ),
                            );
                            return;
                          }
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => _TeamSquadPage(teamName: team),
                            ),
                          );
                        }
                      : null,
                ),
                const Divider(height: 1, thickness: 1, color: Color(0xFFEAEAEA)),
              ],
            );
          } else {
            return Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Color(0xFFE5E5E5)),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  radius: 14,
                  backgroundColor: Colors.blueGrey.withOpacity(0.12),
                  child: Text(
                    '${i + 1}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
                title: Text(
                  widget.items[i],
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            );
          }
        },
      ),
    );
  }
}

class _TeamSquadPage extends StatefulWidget {
  const _TeamSquadPage({required this.teamName});
  final String teamName;

  @override
  State<_TeamSquadPage> createState() => _TeamSquadPageState();
}

class _TeamSquadPageState extends State<_TeamSquadPage> {
  bool _isMyPageOpen = false;
  void _toggleMyPage() => setState(() => _isMyPageOpen = !_isMyPageOpen);

  Color _teamColor(String name) {
    final seed = name.codeUnits.fold<int>(0, (p, e) => p + e);
    const palette = [
      Color(0xFF6EC5FF),
      Color(0xFF9FE2BF),
      Color(0xFFFFC785),
      Color(0xFFE7B0FF),
      Color(0xFFA7B8FF),
      Color(0xFFFFB6C1),
      Color(0xFF8DE3FF),
    ];
    return palette[seed % palette.length];
  }

  _FixtureScore? _fixtureForTeam(String team) {
    for (final f in _kLeagueFixtureMeta) {
      if (f.home == team || f.away == team) return f;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final fixture = _fixtureForTeam(widget.teamName);
    if (fixture == null) {
      return _OverlayScaffold(
        isMyPageOpen: _isMyPageOpen,
        onToggleMyPage: _toggleMyPage,
        title: 'LeagueIt',
        showSearch: false,
        child: Center(
          child: Text(
            '${widget.teamName}의 경기를 찾지 못했어요.',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      );
    }

    final lineup = _MatchDetailPageState.getOrCreateSoccerFixtureLineup(fixture);
    final isHome = fixture.home == widget.teamName;
    final rows = isHome ? lineup.home : lineup.away;
    final starting = rows.expand((r) => r.slots).toList();
    final bench = _MatchDetailPageState.getOrCreateTeamBench(
      teamName: widget.teamName,
      starting: starting,
    );
    final color = _teamColor(widget.teamName);

    // Display rows should be ordered from top(FW) -> bottom(GK) in a half pitch view.
    final displayRows = rows.isNotEmpty &&
            rows.first.slots.isNotEmpty &&
            rows.first.slots.first.position == 'GK'
        ? rows.reversed.toList()
        : rows;

    return _OverlayScaffold(
      isMyPageOpen: _isMyPageOpen,
      onToggleMyPage: _toggleMyPage,
      title: 'LeagueIt',
      showSearch: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.teamName,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            _HalfLineupField(
              rows: displayRows,
              color: color,
              onPlayerTap: (slot) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PlayerProfilePage(
                      name: slot.name,
                      ownership: PlayerOwnership.otherTeam,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 14),
            const Text(
              'Bench',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            _StaticRosterList(
              players: bench,
              onTap: (slot) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PlayerProfilePage(
                      name: slot.name,
                      ownership: PlayerOwnership.otherTeam,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _HalfLineupField extends StatelessWidget {
  const _HalfLineupField({
    required this.rows,
    required this.color,
    required this.onPlayerTap,
  });

  final List<_Player> rows;
  final Color color;
  final void Function(_PlayerSlot) onPlayerTap;

  @override
  Widget build(BuildContext context) {
    const double margin = 16;
    const double padding = 24;
    final double usableHeight = max(
      260.0,
      (rows.length <= 1 ? 120.0 : 70.0 * (rows.length - 1) + 120.0),
    );
    final double fieldHeight = margin * 2 + usableHeight;

    return SizedBox(
      height: fieldHeight,
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _HalfPitchPainter())),
          ..._positionRowsHalf(
            rows: rows,
            top: margin,
            height: usableHeight,
            padding: padding,
            color: color,
            onTap: onPlayerTap,
          ),
        ],
      ),
    );
  }
}

class _RosterHalfPitch extends StatelessWidget {
  const _RosterHalfPitch({
    required this.rows,
    required this.rosterByName,
    required this.color,
    required this.onSwap,
    required this.onTap,
  });

  final List<_Player> rows;
  final Map<String, _PlayerSlot> rosterByName;
  final Color color;
  final void Function(_PlayerSlot from, _PlayerSlot to)? onSwap;
  final void Function(_PlayerSlot) onTap;

  @override
  Widget build(BuildContext context) {
    const double margin = 16;
    const double padding = 24;
    final double usableHeight = max(
      260.0,
      (rows.length <= 1 ? 120.0 : 70.0 * (rows.length - 1) + 120.0),
    );
    final double fieldHeight = margin * 2 + usableHeight;

    return SizedBox(
      height: fieldHeight,
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _HalfPitchPainter())),
          ..._positionRowsHalfDraggable(
            rows: rows,
            top: margin,
            height: usableHeight,
            padding: padding,
            rosterByName: rosterByName,
            color: color,
            onSwap: onSwap,
            onTap: onTap,
          ),
        ],
      ),
    );
  }
}

List<Widget> _positionRowsHalfDraggable({
  required List<_Player> rows,
  required double top,
  required double height,
  required double padding,
  required Map<String, _PlayerSlot> rosterByName,
  required Color color,
  required void Function(_PlayerSlot from, _PlayerSlot to)? onSwap,
  required void Function(_PlayerSlot) onTap,
}) {
  final double usable = max(40, height - padding * 2);
  final double spacing = rows.length > 1 ? usable / rows.length : usable / 2;
  final double start = padding.clamp(0, height - padding - usable);
  return [
    for (int i = 0; i < rows.length; i++)
      Positioned(
        top: top + start + spacing * i,
        left: 0,
        right: 0,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: rows[i].slots.map((s) {
              final slot = rosterByName[s.name] ?? s;
              return _DraggableRosterChip(
                slot: slot,
                color: color,
                onSwap: onSwap,
                onTap: onTap,
              );
            }).toList(),
          ),
        ),
      ),
  ];
}

class _DraggableRosterChip extends StatelessWidget {
  const _DraggableRosterChip({
    required this.slot,
    required this.color,
    required this.onSwap,
    required this.onTap,
  });

  final _PlayerSlot slot;
  final Color color;
  final void Function(_PlayerSlot from, _PlayerSlot to)? onSwap;
  final void Function(_PlayerSlot) onTap;

  @override
  Widget build(BuildContext context) {
    return DragTarget<_PlayerSlot>(
      onWillAcceptWithDetails: (details) => details.data != slot,
      onAcceptWithDetails: (details) => onSwap?.call(details.data, slot),
      builder: (context, candidate, rejected) {
        final highlight = candidate.isNotEmpty;
        return LongPressDraggable<_PlayerSlot>(
          data: slot,
          feedback: _chipBody(context, highlight: true, isGhost: true),
          childWhenDragging: Opacity(
            opacity: 0.35,
            child: _chipBody(context, highlight: false),
          ),
          child: _chipBody(context, highlight: highlight),
        );
      },
    );
  }

  Widget _chipBody(BuildContext context,
      {required bool highlight, bool isGhost = false}) {
    final body = GestureDetector(
      onTap: () => onTap(slot),
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: (highlight ? Colors.green : color).withOpacity(0.14),
              shape: BoxShape.circle,
              border: Border.all(
                color: highlight ? Colors.green : color,
                width: highlight ? 2.2 : 1.6,
              ),
            ),
            child: Center(
              child: Text(
                '${slot.score}',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: highlight ? Colors.green : color,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: 58,
            child: Text(
              slot.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );

    if (!isGhost) return body;
    return Material(
      color: Colors.transparent,
      child: Opacity(opacity: 0.9, child: body),
    );
  }
}

class _HalfPitchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint fill = Paint()
      ..color = const Color(0xFF0E5F2F)
      ..style = PaintingStyle.fill;
    final Paint line = Paint()
      ..color = const Color.fromARGB(255, 71, 115, 91).withOpacity(0.8)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final double width = size.width;
    final double height = size.height;

    final Rect fieldRect = Rect.fromLTWH(0, 0, width, height);
    canvas.drawRRect(
      RRect.fromRectAndRadius(fieldRect, const Radius.circular(12)),
      fill,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(fieldRect, const Radius.circular(12)),
      line,
    );

    // Halfway line at the top of the half-field
    canvas.drawLine(const Offset(0, 0), Offset(width, 0), line);

    // Center circle arc (bottom half of the circle is outside this half)
    const double centerRadius = 36;
    // Use an arc centered at top-middle
    canvas.drawArc(
      Rect.fromCircle(center: Offset(width / 2, 0), radius: centerRadius),
      0,
      pi,
      false,
      line,
    );

    // Penalty box near the bottom goal
    const double boxDepth = 80;
    const double boxWidthInset = 40;
    canvas.drawRect(
      Rect.fromLTWH(
        boxWidthInset,
        height - boxDepth,
        width - boxWidthInset * 2,
        boxDepth,
      ),
      line,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

List<Widget> _positionRowsHalf({
  required List<_Player> rows,
  required double top,
  required double height,
  required double padding,
  required Color color,
  required void Function(_PlayerSlot) onTap,
}) {
  final double usable = max(40, height - padding * 2);
  final double spacing = rows.length > 1 ? usable / rows.length : usable / 2;
  final double start = padding.clamp(0, height - padding - usable);
  return [
    for (int i = 0; i < rows.length; i++)
      Positioned(
        top: top + start + spacing * i,
        left: 0,
        right: 0,
        child: _LineupRow(players: rows[i], color: color, onTap: onTap),
      ),
  ];
}

class _StaticRosterList extends StatelessWidget {
  const _StaticRosterList({required this.players, this.onTap});
  final List<_PlayerSlot> players;
  final void Function(_PlayerSlot)? onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: players
          .map(
            (p) => Container(
              margin: const EdgeInsets.symmetric(vertical: 6),
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: onTap == null ? null : () => onTap!(p),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.black12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${p.name} (${p.position})',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _PlayerOfWeekPage extends StatefulWidget {
  final List<_PlayerSlot> players;
  const _PlayerOfWeekPage({required this.players});

  @override
  State<_PlayerOfWeekPage> createState() => _PlayerOfWeekPageState();
}

class _PlayerOfWeekPageState extends State<_PlayerOfWeekPage> {
  bool _isMyPageOpen = false;
  void _toggleMyPage() => setState(() => _isMyPageOpen = !_isMyPageOpen);

  @override
  Widget build(BuildContext context) {
    final sorted = [...widget.players]
      ..sort((a, b) => b.score.compareTo(a.score));
    final top = sorted.take(30).toList();
    final podium = top.take(3).toList();
    final rest = top.length > 3 ? top.sublist(3) : <_PlayerSlot>[];

    Widget podiumView() {
      if (podium.isEmpty) return const SizedBox.shrink();
      const heights = [150.0, 130.0, 110.0]; // 1위 중앙, 2위 왼쪽, 3위 오른쪽
      final displayOrder = [1, 0, 2]; // left=2nd, center=1st, right=3rd
      final displayCount = min(3, podium.length);

      Widget bar(int podiumIdx, _PlayerSlot p) {
        return InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            final own = _MatchDetailPageState._playerOwnerCache[p.name] ??
                PlayerOwnership.freeAgent;
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PlayerProfilePage(name: p.name, ownership: own),
              ),
            );
          },
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Container(
                width: 70,
                height: heights[podiumIdx],
                decoration: BoxDecoration(
                  color: Colors.blueGrey.shade100,
                  border: Border.all(color: Colors.black26),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    '${podiumIdx + 1}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: 86,
                child: Text(
                  p.name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
              Text(
                '${p.score} pts',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
        );
      }

      return Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E5E5)),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 4,
              offset: Offset(0, 2),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Top 3',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(displayCount, (displayIdx) {
                final podiumIdx =
                    displayCount == 3 ? displayOrder[displayIdx] : displayIdx;
                final p = podium[podiumIdx];
                return bar(podiumIdx, p);
              }),
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
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: 1 + rest.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) {
          if (i == 0) {
            return podiumView();
          }
          final idx = i - 1;
          final p = rest[idx];
          final rank = idx + 4; // 4등부터
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E5E5)),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: Offset(0, 2),
                )
              ],
            ),
            child: ListTile(
              leading: CircleAvatar(
                radius: 18,
                backgroundColor: Colors.blueGrey.withOpacity(.12),
                child: Text(
                  '$rank',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blueGrey,
                  ),
                ),
              ),
              title: Text(
                p.name,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text('${p.position} · ${p.score} pts'),
              trailing: const Icon(Icons.chevron_right, size: 18),
              onTap: () {
                final own = _MatchDetailPageState._playerOwnerCache[p.name] ??
                    PlayerOwnership.freeAgent;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        PlayerProfilePage(name: p.name, ownership: own),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _DraggableRosterList extends StatelessWidget {
  final List<_PlayerSlot> players;
  final bool showMeta;
  final void Function(_PlayerSlot from, _PlayerSlot to)? onSwap;
  final void Function(_PlayerSlot)? onTap;
  const _DraggableRosterList({
    required this.players,
    this.showMeta = false,
    this.onSwap,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[
      ...players.map(
        (p) => DragTarget<_PlayerSlot>(
          onWillAcceptWithDetails: (details) => details.data != p,
          onAcceptWithDetails: (details) => onSwap?.call(details.data, p),
          builder: (context, candidate, rejected) => LongPressDraggable<_PlayerSlot>(
            data: p,
            feedback: _ghostTile(p),
            childWhenDragging:
                Opacity(opacity: 0.4, child: _tile(context, p)),
            child: _tile(
              context,
              p,
              highlight: candidate.isNotEmpty,
            ),
          ),
        ),
      ),
    ];
    return Column(children: children);
  }

  Widget _tile(BuildContext context, _PlayerSlot p, {bool highlight = false}) {
    final meta = showMeta ? _resolvePlayerMeta(p.name) : null;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Material(
        color: highlight ? Colors.green.withOpacity(0.08) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap == null ? null : () => onTap!(p),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.black12),
            ),
            child: Row(
              children: [
                const Icon(Icons.drag_indicator,
                    size: 18, color: Colors.black45),
                const SizedBox(width: 8),
                Expanded(
                  child: showMeta
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.name,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${p.position} · ${meta!.club}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        )
                      : Text(
                          p.name,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _ghostTile(_PlayerSlot p) {
    final meta = showMeta ? _resolvePlayerMeta(p.name) : null;
    return Material(
      color: Colors.transparent,
      child: Opacity(
        opacity: 0.85,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.green),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 6,
                offset: Offset(0, 3),
              )
            ],
          ),
          child: showMeta
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${p.position} · ${meta!.club}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                )
              : Text(
                  p.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
      ),
    );
  }
}

class _LineupData {
  final List<_Player> home;
  final List<_Player> away;
  final int homeScore;
  final int awayScore;
  final String homeFormation;
  final String awayFormation;

  _LineupData({
    required this.home,
    required this.away,
    required this.homeScore,
    required this.awayScore,
    required this.homeFormation,
    required this.awayFormation,
  });
}

_LineupData _normalizeLineupToScores(
  _LineupData lineup,
  double targetHome,
  double targetAway,
) {
  int sumSlots(List<_Player> rows) =>
      rows.expand((r) => r.slots).fold(0, (a, b) => a + b.score);

  List<_Player> scale(List<_Player> rows, int target) {
    if (rows.isEmpty) return rows;
    final lengths = rows.map((r) => r.slots.length).toList();
    final flat = rows.expand((r) => r.slots).toList();
    final current = sumSlots(rows);
    final factor = current == 0 ? 1.0 : target / current;
    final List<_PlayerSlot> scaled = flat
        .map(
          (s) => _PlayerSlot(
            name: s.name,
            score: max(1, (s.score * factor).round()),
            position: s.position,
          ),
        )
        .toList();
    int diff = target - scaled.fold(0, (a, b) => a + b.score);
    var idx = 0;
    while (diff != 0 && scaled.isNotEmpty) {
      final i = idx % scaled.length;
      scaled[i] = _PlayerSlot(
        name: scaled[i].name,
        position: scaled[i].position,
        score: max(1, scaled[i].score + (diff > 0 ? 1 : -1)),
      );
      diff += diff > 0 ? -1 : 1;
      idx++;
    }
    int start = 0;
    final List<_Player> rebuilt = [];
    for (final len in lengths) {
      rebuilt.add(_Player(slots: scaled.sublist(start, start + len)));
      start += len;
    }
    return rebuilt;
  }

  final int targetHomeInt = targetHome.round();
  final int targetAwayInt = targetAway.round();
  final newHome = scale(lineup.home, targetHomeInt);
  final newAway = scale(lineup.away, targetAwayInt);

  return _LineupData(
    home: newHome,
    away: newAway,
    homeScore: targetHomeInt,
    awayScore: targetAwayInt,
    homeFormation: lineup.homeFormation,
    awayFormation: lineup.awayFormation,
  );
}

class _Player {
  final List<_PlayerSlot> slots;
  _Player({required this.slots});
}

class _PlayerSlot {
  final String name;
  final int score;
  final String position;
  _PlayerSlot({
    required this.name,
    required this.score,
    required this.position,
  });
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback? onTap;
  const _CategoryChip({required this.label, this.active = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    const Color activeColor = Colors.green;
    final Color stroke = Theme.of(context).colorScheme.onSurface;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? activeColor.withOpacity(0.12) : Colors.transparent,
          border: Border.all(color: active ? activeColor : stroke, width: 1.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: active ? activeColor : stroke,
          ),
        ),
      ),
    );
  }
}

class _PitchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint fill = Paint()
      ..color = const Color(0xFF0E5F2F)
      ..style = PaintingStyle.fill;
    final Paint line = Paint()
      ..color = const Color.fromARGB(255, 71, 115, 91).withOpacity(0.8)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final double width = size.width;
    final double height = size.height;

    // Field fill
    final Rect fieldRect = Rect.fromLTWH(0, 0, width, height);
    canvas.drawRRect(
      RRect.fromRectAndRadius(fieldRect, const Radius.circular(12)),
      fill,
    );

    // Outer border
    canvas.drawRRect(
      RRect.fromRectAndRadius(fieldRect, const Radius.circular(12)),
      line,
    );

    // Halfway line
    canvas.drawLine(Offset(0, height / 2), Offset(width, height / 2), line);

    // Center circle
    canvas.drawCircle(Offset(width / 2, height / 2), 36, line);

    // Penalty boxes
    const double boxDepth = 80;
    const double boxWidthInset = 40;
    canvas.drawRect(
      Rect.fromLTWH(boxWidthInset, 0, width - boxWidthInset * 2, boxDepth),
      line,
    );
    canvas.drawRect(
      Rect.fromLTWH(
        boxWidthInset,
        height - boxDepth,
        width - boxWidthInset * 2,
        boxDepth,
      ),
      line,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

List<Widget> _positionRows({
  required List<_Player> rows,
  required double top,
  required double height,
  required double padding,
  required bool isHome,
  required Color color,
  required void Function(_PlayerSlot) onTap,
}) {
  final double usable = max(40, height - padding * 2);
  final double bias = isHome ? -usable * 0.2 : usable * 0.2;
  final double start = (padding + bias).clamp(0, height - padding - usable);
  final double spacing = rows.length > 1 ? usable / (rows.length) : usable / 2;
  return [
    for (int i = 0; i < rows.length; i++)
      Positioned(
        top: top + start + spacing * i,
        left: 0,
        right: 0,
        child: _LineupRow(players: rows[i], color: color, onTap: onTap),
      ),
  ];
}

_LineupData _generateLineup({required bool isSoccer, Random? random}) {
  final rng = random ?? Random();

  if (!isSoccer) {
    // Baseball is not implemented yet in this mock.
    return _LineupData(
      home: const [],
      away: const [],
      homeScore: 0,
      awayScore: 0,
      homeFormation: '—',
      awayFormation: '—',
    );
  }

  // Use ONLY the updated roster-document players for lineup generation.
  final all = _buildPlayerPool(Random(_stableSeedFromKey('pool|kLeague')));
  final gk = all.where((p) => p.position == 'GK').toList();
  final df = all.where((p) => p.position == 'DF').toList();
  final mf = all.where((p) => p.position == 'MF').toList();
  final fw = all.where((p) => p.position == 'FW').toList();

  List<_PlayerSlot> pickN(List<_PlayerSlot> pool, int n) {
    final list = List<_PlayerSlot>.from(pool)..shuffle(rng);
    return List.generate(n, (i) => list[i % list.length]);
  }

  final formations = _formationOptions.keys.toList();
  final homeFormation = formations[rng.nextInt(formations.length)];
  final awayFormation = formations[rng.nextInt(formations.length)];
  final home = _formationOptions[homeFormation]!;
  final away = _formationOptions[awayFormation]!;

  // Home(blue): GK -> DF -> MF -> FW (Matchup view positions it in the top half)
  final homeRows = [
    _Player(slots: pickN(gk, 1)),
    _Player(slots: pickN(df, home.df)),
    _Player(slots: pickN(mf, home.mf)),
    _Player(slots: pickN(fw, home.fw)),
  ];

  // Away(red): FW -> MF -> DF -> GK so that GK appears near the bottom.
  final awayRows = [
    _Player(slots: pickN(fw.reversed.toList(), away.fw)),
    _Player(slots: pickN(mf.reversed.toList(), away.mf)),
    _Player(slots: pickN(df.reversed.toList(), away.df)),
    _Player(slots: pickN(gk.reversed.toList(), 1)),
  ];

  int sumScores(List<_Player> rows) =>
      rows.expand((r) => r.slots).fold(0, (a, b) => a + b.score);

  return _LineupData(
    home: homeRows,
    away: awayRows,
    homeScore: sumScores(homeRows),
    awayScore: sumScores(awayRows),
    homeFormation: homeFormation,
    awayFormation: awayFormation,
  );
}

class _FixtureScore {
  const _FixtureScore({
    required this.roundLabel,
    required this.home,
    required this.away,
    required this.homeScore,
    required this.awayScore,
    required this.homeRecord,
    required this.awayRecord,
  });

  final String roundLabel;
  final String home;
  final String away;
  final double homeScore;
  final double awayScore;
  final String homeRecord;
  final String awayRecord;

  bool get homeWinning => homeScore >= awayScore;
}

// K League: 10 teams / 5 matches for a single round.
// Scores are derived from the cached lineup totals (starting XI points sum).
const List<_FixtureScore> _kLeagueFixtureMeta = [
  _FixtureScore(
    roundLabel: 'Round 12',
    home: 'Blue Foxes',
    away: 'Red Bears',
    homeScore: 0,
    awayScore: 0,
    homeRecord: '7-6 · L1',
    awayRecord: '9-4 · L1',
  ),
  _FixtureScore(
    roundLabel: 'Round 12',
    home: 'White Tigers',
    away: 'Green Hawks',
    homeScore: 0,
    awayScore: 0,
    homeRecord: '7-6 · W1',
    awayRecord: '8-5 · W1',
  ),
  _FixtureScore(
    roundLabel: 'Round 12',
    home: 'Sky Giants',
    away: 'Orange Wolves',
    homeScore: 0,
    awayScore: 0,
    homeRecord: '6-7 · W1',
    awayRecord: '6-7 · L1',
  ),
  _FixtureScore(
    roundLabel: 'Round 12',
    home: 'Mint Dolphins',
    away: 'Purple Knights',
    homeScore: 0,
    awayScore: 0,
    homeRecord: '5-8 · L2',
    awayRecord: '8-5 · W2',
  ),
  _FixtureScore(
    roundLabel: 'Round 12',
    home: 'Silver Sharks',
    away: 'Golden Owls',
    homeScore: 0,
    awayScore: 0,
    homeRecord: '6-7 · W2',
    awayRecord: '7-6 · L1',
  ),
];

class _FixtureCardsPage extends StatefulWidget {
  const _FixtureCardsPage({required this.isSoccer});
  final bool isSoccer;

  @override
  State<_FixtureCardsPage> createState() => _FixtureCardsPageState();
}

class _FixtureCardsPageState extends State<_FixtureCardsPage> {
  bool _isMyPageOpen = false;
  void _toggleMyPage() => setState(() => _isMyPageOpen = !_isMyPageOpen);

  List<_FixtureScore> get _fixtures => widget.isSoccer
      ? _buildSoccerFixtures()
      : const [
          _FixtureScore(
            roundLabel: 'Series G68',
            home: 'Seoul Sluggers',
            away: 'Busan Bombers',
            homeScore: 6.4,
            awayScore: 4.9,
            homeRecord: '52-30 · W3',
            awayRecord: '50-32 · L1',
          ),
          _FixtureScore(
            roundLabel: 'Series G68',
            home: 'Daegu Titans',
            away: 'Incheon Waves',
            homeScore: 3.2,
            awayScore: 2.1,
            homeRecord: '48-35 · W2',
            awayRecord: '47-36 · L1',
          ),
          _FixtureScore(
            roundLabel: 'Series G69',
            home: 'Daejeon Rockets',
            away: 'Suwon Knights',
            homeScore: 5.7,
            awayScore: 6.1,
            homeRecord: '45-38 · L1',
            awayRecord: '43-40 · W2',
          ),
          _FixtureScore(
            roundLabel: 'Series G69',
            home: 'Gwangju Sparks',
            away: 'Jeju Mariners',
            homeScore: 4.2,
            awayScore: 3.8,
            homeRecord: '40-43 · W1',
            awayRecord: '38-45 · L1',
          ),
          _FixtureScore(
            roundLabel: 'Series G69',
            home: 'Ulsan Bulls',
            away: 'Anyang Bears',
            homeScore: 5.1,
            awayScore: 2.9,
            homeRecord: '36-47 · W2',
            awayRecord: '34-49 · L2',
          ),
        ];

  List<_FixtureScore> _buildSoccerFixtures() {
    return _kLeagueFixtureMeta.map((f) {
      final lineup = _MatchDetailPageState.getOrCreateSoccerFixtureLineup(f);
      return _FixtureScore(
        roundLabel: f.roundLabel,
        home: f.home,
        away: f.away,
        homeScore: lineup.homeScore.toDouble(),
        awayScore: lineup.awayScore.toDouble(),
        homeRecord: f.homeRecord,
        awayRecord: f.awayRecord,
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final myTeam = widget.isSoccer ? 'Blue Foxes' : 'Seoul Sluggers';
    final cached =
        widget.isSoccer ? _MatchDetailPageState._cachedSoccerLineup : null;
    final ordered = List<_FixtureScore>.from(_fixtures)
      ..sort((a, b) {
        final aMy = (a.home == myTeam || a.away == myTeam) ? 0 : 1;
        final bMy = (b.home == myTeam || b.away == myTeam) ? 0 : 1;
        return aMy.compareTo(bMy);
      });
    return _OverlayScaffold(
      isMyPageOpen: _isMyPageOpen,
      onToggleMyPage: _toggleMyPage,
      title: 'LeagueIt',
      showSearch: false,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: ordered.length,
        itemBuilder: (context, index) {
          var data = ordered[index];
          // 내 경기(Blue Foxes vs Red Bears)는 실제 라인업 합산 점수와 동일하게 표시
          if (cached != null && (data.home == myTeam || data.away == myTeam)) {
            data = _FixtureScore(
              roundLabel: data.roundLabel,
              home: data.home,
              away: data.away,
              homeScore: cached.homeScore.toDouble(),
              awayScore: cached.awayScore.toDouble(),
              homeRecord: data.homeRecord,
              awayRecord: data.awayRecord,
            );
          }
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () async {
                final isMyGame = data.home == myTeam || data.away == myTeam;
                if (isMyGame) {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MatchDetailPage(
                        isSoccer: widget.isSoccer,
                        initialSection: _MatchSection.matchup,
                      ),
                    ),
                  );
                } else {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => _FixtureDetailPage(
                        fixture: data,
                        isSoccer: widget.isSoccer,
                      ),
                    ),
                  );
                }
                if (!mounted) return;
                setState(() {}); // 스코어 캐시 변경을 반영
              },
              child: _FixtureScoreCard(data: data, isSoccer: widget.isSoccer),
            ),
          );
        },
      ),
    );
  }
}

class _FixtureScoreCard extends StatelessWidget {
  const _FixtureScoreCard({required this.data, required this.isSoccer});
  final _FixtureScore data;
  final bool isSoccer;

  Color _teamColor(String name) {
    final seed = name.codeUnits.fold<int>(0, (p, e) => p + e);
    const palette = [
      Color(0xFF6EC5FF),
      Color(0xFF9FE2BF),
      Color(0xFFFFC785),
      Color(0xFFE7B0FF),
      Color(0xFFA7B8FF),
      Color(0xFFFFB6C1),
      Color(0xFF8DE3FF),
    ];
    return palette[seed % palette.length];
  }

  @override
  Widget build(BuildContext context) {
    final homeColor = _teamColor(data.home);
    final awayColor = _teamColor(data.away);
    return Card(
      elevation: 3,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.roundLabel,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                _teamRow(
                  context,
                  name: data.home,
                  record: data.homeRecord,
                  score: data.homeScore,
                  color: homeColor,
                  isWinner: data.homeWinning,
                ),
                const SizedBox(height: 14),
                _teamRow(
                  context,
                  name: data.away,
                  record: data.awayRecord,
                  score: data.awayScore,
                  color: awayColor,
                  isWinner: !data.homeWinning,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _teamRow(
    BuildContext context, {
    required String name,
    required String record,
    required double score,
    required Color color,
    required bool isWinner,
  }) {
    final scoreText =
        isSoccer ? score.toStringAsFixed(0) : score.toStringAsFixed(1);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _avatar(color),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                record,
                style: const TextStyle(color: Colors.black54, fontSize: 13),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              scoreText,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: isWinner
                    ? Theme.of(context).colorScheme.primary
                    : Colors.black87,
              ),
            ),
            const SizedBox(height: 2),
          ],
        ),
      ],
    );
  }

  Widget _avatar(Color color) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [color, color.withOpacity(.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(.25),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: const Icon(Icons.sports_soccer, color: Colors.white),
    );
  }
}

class _FixtureDetailPage extends StatefulWidget {
  const _FixtureDetailPage({required this.fixture, required this.isSoccer});
  final _FixtureScore fixture;
  final bool isSoccer;

  @override
  State<_FixtureDetailPage> createState() => _FixtureDetailPageState();
}

class _FixtureDetailPageState extends State<_FixtureDetailPage> {
  bool _isMyPageOpen = false;
  void _toggleMyPage() => setState(() => _isMyPageOpen = !_isMyPageOpen);

  @override
  Widget build(BuildContext context) {
    final _LineupData? lineup = widget.isSoccer
        ? _MatchDetailPageState.getOrCreateSoccerFixtureLineup(widget.fixture)
        : null;
    final double homeScore =
        widget.isSoccer ? lineup!.homeScore.toDouble() : widget.fixture.homeScore;
    final double awayScore =
        widget.isSoccer ? lineup!.awayScore.toDouble() : widget.fixture.awayScore;
    final total = homeScore + awayScore;
    final winPctHome = total == 0 ? 0.5 : homeScore / total;
    final homePct = (winPctHome * 100).round();
    final awayPct = 100 - homePct;
    final scoreText = widget.isSoccer
        ? '${homeScore.toStringAsFixed(0)} vs ${awayScore.toStringAsFixed(0)}'
        : '${homeScore.toStringAsFixed(1)} vs ${awayScore.toStringAsFixed(1)}';
    return _OverlayScaffold(
      isMyPageOpen: _isMyPageOpen,
      onToggleMyPage: _toggleMyPage,
      title: 'LeagueIt',
      showSearch: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _TeamBadge(
                  emoji: '🦊',
                  label: widget.isSoccer
                      ? homeScore.toStringAsFixed(0)
                      : homeScore.toStringAsFixed(1),
                ),
                Column(
                  children: [
                    Text(
                      scoreText,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${widget.fixture.homeRecord}  |  ${widget.fixture.awayRecord}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
                _TeamBadge(
                  emoji: '🐻',
                  label: widget.isSoccer
                      ? awayScore.toStringAsFixed(0)
                      : awayScore.toStringAsFixed(1),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Text(
                  '$homePct%',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Text(
                  'Win probability',
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                ),
                Text(
                  '$awayPct%',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _WinBar(homeRatio: winPctHome.clamp(0.0, 1.0)),
            const SizedBox(height: 20),
            if (lineup != null)
              _LineupField(
                lineup: lineup,
                isSoccer: true,
                homeRecord: widget.fixture.homeRecord,
                awayRecord: widget.fixture.awayRecord,
                onPlayerTap: (slot) => _showInlinePlayerCard(
                  context,
                  slot,
                  ownership: PlayerOwnership.otherTeam,
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F8F8),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.black12),
                ),
                child: const Text('KBO 경기는 포메이션 없이 점수만 제공합니다.'),
              ),
          ],
        ),
      ),
    );
  }
}

class _TradePage extends StatefulWidget {
  final List<_PlayerSlot> myRoster;
  final List<_PlayerSlot> market;
  final bool isSoccer;
  const _TradePage({
    required this.myRoster,
    required this.market,
    required this.isSoccer,
  });

  @override
  State<_TradePage> createState() => _TradePageState();
}

class _TradePageState extends State<_TradePage> {
  bool _isMyPageOpen = false;
  int? _selectedMine;
  int? _selectedTarget;
  late List<_PlayerSlot> _myRoster;
  late List<_PlayerSlot> _market;

  @override
  void initState() {
    super.initState();
    _myRoster = List<_PlayerSlot>.from(widget.myRoster);
    _market = List<_PlayerSlot>.from(widget.market);
  }

  void _toggleMyPage() => setState(() => _isMyPageOpen = !_isMyPageOpen);

  void _executeTrade() {
    if (_selectedMine == null || _selectedTarget == null) return;
    final mine = _myRoster[_selectedMine!];
    final target = _market[_selectedTarget!];
    setState(() {
      _myRoster[_selectedMine!] = target;
      _market[_selectedTarget!] = mine;
      _selectedMine = null;
      _selectedTarget = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${target.name} ↔ ${mine.name} 트레이드 완료')),
    );
  }

  Widget _panel({
    required String title,
    required List<_PlayerSlot> data,
    required bool isMine,
  }) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F8F8),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.separated(
                itemCount: data.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final p = data[i];
                  final selected =
                      isMine ? _selectedMine == i : _selectedTarget == i;
                  return ListTile(
                    dense: true,
                    leading: Icon(
                      selected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      color: selected ? Colors.green : Colors.grey,
                    ),
                    title: Text('${p.name} (${p.position})'),
                    trailing: Text('${p.score} pts'),
                    onTap: () {
                      setState(() {
                        if (isMine) {
                          _selectedMine = i;
                        } else {
                          _selectedTarget = i;
                        }
                      });
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _OverlayScaffold(
      isMyPageOpen: _isMyPageOpen,
      onToggleMyPage: _toggleMyPage,
      title: 'LeagueIt',
      showSearch: false,
      child: Column(
        children: [
          const SizedBox(height: 12),
          Expanded(
            child: Row(
              children: [
                _panel(title: '내 팀', data: _myRoster, isMine: true),
                _panel(title: '상대 팀', data: _market, isMine: false),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.swap_horiz),
              label: const Text('트레이드 제안'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: (_selectedMine != null && _selectedTarget != null)
                  ? _executeTrade
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

// 공용 선수 이름 풀 (검색 제안용)
List<String> getAllPlayerNames() {
  final all = _docMetaByName.keys.toList()..sort();
  return all;
}
