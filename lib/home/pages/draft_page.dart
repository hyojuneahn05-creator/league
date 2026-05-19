part of '../home_page.dart';

enum _DraftPlayerFilter {
  all,
  gk,
  df,
  mf,
  fw,
  pitcher,
  infielder,
  outfielder,
  catcher,
}

extension on _DraftPlayerFilter {
  String get label {
    switch (this) {
      case _DraftPlayerFilter.all:
        return 'All';
      case _DraftPlayerFilter.gk:
        return 'GK';
      case _DraftPlayerFilter.df:
        return 'DF';
      case _DraftPlayerFilter.mf:
        return 'MF';
      case _DraftPlayerFilter.fw:
        return 'FW';
      case _DraftPlayerFilter.pitcher:
        return 'P';
      case _DraftPlayerFilter.infielder:
        return 'IF';
      case _DraftPlayerFilter.outfielder:
        return 'OF';
      case _DraftPlayerFilter.catcher:
        return 'C';
    }
  }

  String? get position {
    switch (this) {
      case _DraftPlayerFilter.all:
        return null;
      case _DraftPlayerFilter.gk:
        return 'GK';
      case _DraftPlayerFilter.df:
        return 'DF';
      case _DraftPlayerFilter.mf:
        return 'MF';
      case _DraftPlayerFilter.fw:
        return 'FW';
      case _DraftPlayerFilter.pitcher:
        return 'P';
      case _DraftPlayerFilter.infielder:
        return 'IF';
      case _DraftPlayerFilter.outfielder:
        return 'OF';
      case _DraftPlayerFilter.catcher:
        return 'C';
    }
  }
}

class _DraftRules {
  final int rounds;
  final List<_DraftPlayerFilter> filters;
  final Map<String, int> minimums;
  final String rosterSummary;
  const _DraftRules({
    required this.rounds,
    required this.filters,
    required this.minimums,
    required this.rosterSummary,
  });
}

const _DraftRules _kLeagueDraftRules = _DraftRules(
  rounds: 18,
  filters: [
    _DraftPlayerFilter.all,
    _DraftPlayerFilter.gk,
    _DraftPlayerFilter.df,
    _DraftPlayerFilter.mf,
    _DraftPlayerFilter.fw,
  ],
  minimums: {'GK': 1, 'DF': 3, 'MF': 4, 'FW': 3},
  rosterSummary: '18명 · GK 1 / DF 3 / MF 4 / FW 3 최소',
);

const _DraftRules _kboDraftRules = _DraftRules(
  rounds: 21,
  filters: [
    _DraftPlayerFilter.all,
    _DraftPlayerFilter.pitcher,
    _DraftPlayerFilter.infielder,
    _DraftPlayerFilter.outfielder,
    _DraftPlayerFilter.catcher,
  ],
  minimums: {'P': 1, 'IF': 4, 'OF': 3, 'C': 1},
  rosterSummary: '21명 · P 1 / IF 4 / OF 3 / C 1 최소',
);

class _DraftSessionState {
  final List<List<_PlayerSlot?>> board;
  final int currentIndex;
  final bool draftComplete;
  final DateTime? currentTurnStartedAt;

  const _DraftSessionState({
    required this.board,
    required this.currentIndex,
    required this.draftComplete,
    required this.currentTurnStartedAt,
  });
}

final Map<String, _DraftSessionState> _draftSessionCache =
    <String, _DraftSessionState>{};

String _draftSessionKey({
  required bool isMock,
  required String leagueName,
  required DateTime draftTime,
  required int teamCount,
  required bool isSoccer,
}) {
  return '${isMock ? 'mock' : 'real'}|$leagueName|${draftTime.toIso8601String()}|$teamCount|$isSoccer';
}

String _draftSessionKeyForJoinedDraft(_JoinedDraft draft) {
  return _draftSessionKey(
    isMock: false,
    leagueName: draft.leagueName,
    draftTime: draft.when,
    teamCount: draft.teamCount,
    isSoccer: draft.isSoccer,
  );
}

class DraftPage extends StatefulWidget {
  final String leagueId;
  final DateTime draftTime;
  final String leagueName;
  final int teamCount;
  final int roundCount;
  final bool isMock;
  final bool isSoccer;
  final bool reviewOnly;
  final List<_DraftOrderEntry> draftOrderEntries;
  final List<String>? teamNames;
  final String? myTeamName;
  final List<List<_PlayerSlot?>>? savedBoard;
  const DraftPage({
    super.key,
    this.leagueId = '',
    required this.draftTime,
    required this.leagueName,
    this.teamCount = 8,
    this.roundCount = 1,
    this.isMock = false,
    this.isSoccer = true,
    this.reviewOnly = false,
    this.draftOrderEntries = const [],
    this.teamNames,
    this.myTeamName,
    this.savedBoard,
  });

  @override
  State<DraftPage> createState() => _DraftPageState();
}

class _DraftPageState extends State<DraftPage> with TickerProviderStateMixin {
  static const Duration pickTime = _draftPickDuration;
  static const Duration mockAiPickDelay = Duration(milliseconds: 450);

  late final _DraftRules _rules;
  late final List<String> _teamNames;
  late final List<List<_PlayerSlot?>> _board;
  late final List<int> _order;
  late final Random _rand;
  late final AnimationController _blinkController;
  late final ValueNotifier<String> _timeLabel;
  late final String _sessionKey;
  List<_PlayerSlot> _playerPool = const [];

  int _currentIndex = 0;
  bool _draftComplete = false;
  bool _finalizingFantasy = false;
  bool _isLoadingPlayerPool = false;
  Timer? _pickTimer;
  Timer? _mockAiTimer;
  Duration _pickRemaining = pickTime;
  DateTime? _currentTurnStartedAt;

  @override
  void initState() {
    super.initState();
    _rules = widget.isSoccer ? _kLeagueDraftRules : _kboDraftRules;
    _sessionKey = _draftSessionKey(
      isMock: widget.isMock,
      leagueName: widget.leagueName,
      draftTime: widget.draftTime,
      teamCount: widget.teamCount,
      isSoccer: widget.isSoccer,
    );
    _rand = Random(_stableSeedFromKey(_sessionKey));

    final provided = widget.teamNames;
    if (provided != null && provided.length == widget.teamCount) {
      _teamNames = List<String>.from(provided);
    } else {
      _teamNames = List.generate(widget.teamCount, (i) => 'Team ${i + 1}')
        ..shuffle(_rand);
    }

    _board = List.generate(
      _rules.rounds,
      (_) => List<_PlayerSlot?>.filled(widget.teamCount, null),
    );
    _order = List<int>.generate(_rules.rounds * widget.teamCount, (i) => i);

    _timeLabel = ValueNotifier('0:00');

    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
      lowerBound: 0.25,
      upperBound: 1.0,
    )..repeat(reverse: true);

    if (widget.isSoccer) {
      _playerPool = _buildPlayerPool(_rand);
      _finishDraftInitialization();
      return;
    }

    _isLoadingPlayerPool = true;
    unawaited(_initializeBaseballPlayerPool());
  }

  @override
  void dispose() {
    _pickTimer?.cancel();
    _mockAiTimer?.cancel();
    if (!widget.isMock && !widget.reviewOnly) {
      _persistActualDraftSession();
    }
    _blinkController.dispose();
    _timeLabel.dispose();
    super.dispose();
  }

  Future<void> _initializeBaseballPlayerPool() async {
    final basePool = await _loadKboDraftPlayerPool();
    if (!mounted) return;
    setState(() {
      _playerPool = List<_PlayerSlot>.from(basePool)..shuffle(_rand);
      _isLoadingPlayerPool = false;
    });
    _finishDraftInitialization();
  }

  void _finishDraftInitialization() {
    if (widget.isMock) {
      _handleTurnChange();
      return;
    }

    _restoreActualDraftSession();
    if (widget.reviewOnly) {
      if (!_boardHasAnyPicks) {
        _generateCompletedBoardForReview();
      }
      _draftComplete = true;
      _pickRemaining = Duration.zero;
      _updateTimeLabel();
      _persistActualDraftSession();
      unawaited(_maybeFinalizeFantasyLeague());
    } else {
      _syncActualDraftClock(notify: false, showSnackBar: false);
      _startActualDraftClock();
    }
  }

  Duration get _totalDraftDuration =>
      Duration(seconds: _order.length * pickTime.inSeconds);

  DateTime get _draftEndTime => widget.draftTime.add(_totalDraftDuration);

  bool get _isBeforeActualStart =>
      !widget.isMock && DateTime.now().isBefore(widget.draftTime);

  List<List<_PlayerSlot?>> _cloneBoard(List<List<_PlayerSlot?>> source) {
    return source
        .map(
          (round) => round
              .map(
                (slot) => slot == null
                    ? null
                    : _PlayerSlot(
                        name: slot.name,
                        score: slot.score,
                        position: slot.position,
                      ),
              )
              .toList(),
        )
        .toList();
  }

  bool get _boardHasAnyPicks =>
      _board.any((round) => round.any((slot) => slot != null));

  void _applySavedBoard(List<List<_PlayerSlot?>> board) {
    for (int row = 0; row < _board.length && row < board.length; row++) {
      for (
        int col = 0;
        col < _board[row].length && col < board[row].length;
        col++
      ) {
        final slot = board[row][col];
        _board[row][col] = slot == null
            ? null
            : _PlayerSlot(
                name: slot.name,
                score: slot.score,
                position: slot.position,
              );
      }
    }
  }

  void _restoreActualDraftSession() {
    final cached = _draftSessionCache[_sessionKey];
    if (cached != null) {
      final restoredBoard = _cloneBoard(cached.board);
      _applySavedBoard(restoredBoard);
      _currentIndex = cached.currentIndex.clamp(0, max(0, _order.length - 1));
      _draftComplete = cached.draftComplete;
      _currentTurnStartedAt = cached.currentTurnStartedAt;
      return;
    }

    if (widget.savedBoard != null && widget.savedBoard!.isNotEmpty) {
      _applySavedBoard(widget.savedBoard!);
      _draftComplete = true;
      _currentIndex = max(0, _order.length - 1);
      _currentTurnStartedAt = _draftEndTime.subtract(pickTime);
      return;
    }

    final now = DateTime.now();
    if (now.isBefore(widget.draftTime)) {
      _currentIndex = 0;
      _currentTurnStartedAt = widget.draftTime;
      _pickRemaining = widget.draftTime.difference(now);
      _updateTimeLabel();
      return;
    }

    final elapsedSeconds = now.difference(widget.draftTime).inSeconds;
    final skippedTurns = elapsedSeconds ~/ pickTime.inSeconds;
    if (skippedTurns >= _order.length) {
      _currentIndex = max(0, _order.length - 1);
      _currentTurnStartedAt = _draftEndTime.subtract(pickTime);
      return;
    }

    _currentIndex = skippedTurns.clamp(0, max(0, _order.length - 1));
    _currentTurnStartedAt = widget.draftTime.add(
      Duration(seconds: _currentIndex * pickTime.inSeconds),
    );
  }

  void _generateCompletedBoardForReview() {
    for (int index = 0; index < _order.length; index++) {
      final (row, col) = _idxToPos(_order[index]);
      if (_board[row][col] != null) continue;
      final available = _selectablePlayersForTeam(col);
      if (available.isEmpty) continue;
      _board[row][col] = available[_rand.nextInt(available.length)];
    }
    if (_hasBlankSlots) {
      _fillMissedPicksForActualDraft();
    }
    _currentIndex = max(0, _order.length - 1);
    _currentTurnStartedAt = _draftEndTime.subtract(pickTime);
  }

  void _persistActualDraftSession() {
    if (widget.isMock) return;
    _draftSessionCache[_sessionKey] = _DraftSessionState(
      board: _cloneBoard(_board),
      currentIndex: _currentIndex,
      draftComplete: _draftComplete,
      currentTurnStartedAt: _currentTurnStartedAt,
    );
  }

  void _clearActualDraftSession() {
    _draftSessionCache.remove(_sessionKey);
  }

  String _ord(int n) {
    final mod100 = n % 100;
    if (mod100 >= 11 && mod100 <= 13) return '${n}th';
    switch (n % 10) {
      case 1:
        return '${n}st';
      case 2:
        return '${n}nd';
      case 3:
        return '${n}rd';
      default:
        return '${n}th';
    }
  }

  String get _timerText {
    if (_draftComplete) return '완료';
    if (_pickRemaining.isNegative) return '0:00';
    return _formatClock(_pickRemaining);
  }

  String _formatClock(Duration duration) {
    final totalSeconds = max(0, duration.inSeconds);
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  void _startPickTimer() {
    _pickTimer?.cancel();
    _mockAiTimer?.cancel();
    _pickRemaining = pickTime;
    _updateTimeLabel();
    _pickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _draftComplete) return;
      setState(() {
        _pickRemaining -= const Duration(seconds: 1);
        _updateTimeLabel();
        if (_pickRemaining <= Duration.zero) {
          if (widget.isMock) {
            _autoPickOrAdvanceCurrentTurn();
          } else {
            _advancePick();
          }
        }
      });
    });
  }

  void _updateTimeLabel() {
    if (_pickRemaining.isNegative) {
      _timeLabel.value = '0:00';
      return;
    }
    _timeLabel.value = _formatClock(_pickRemaining);
  }

  void _startActualDraftClock() {
    _pickTimer?.cancel();
    _pickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _syncActualDraftClock();
    });
  }

  void _syncActualDraftClock({bool notify = true, bool showSnackBar = true}) {
    if (widget.isMock || !mounted) return;
    final now = DateTime.now();

    if (_draftComplete) {
      _pickRemaining = Duration.zero;
      _updateTimeLabel();
      if (notify) {
        setState(() {});
      }
      return;
    }

    if (now.isBefore(widget.draftTime)) {
      _pickRemaining = widget.draftTime.difference(now);
      _currentTurnStartedAt = widget.draftTime;
      _updateTimeLabel();
      _persistActualDraftSession();
      if (notify) {
        setState(() {});
      }
      return;
    }

    _currentTurnStartedAt ??= widget.draftTime.add(
      Duration(seconds: _currentIndex * pickTime.inSeconds),
    );

    while (!now.isBefore(_currentTurnStartedAt!.add(pickTime))) {
      final turnEnd = _currentTurnStartedAt!.add(pickTime);
      if (_currentIndex >= _order.length - 1) {
        _finishDraft(showSnackBar: showSnackBar);
        return;
      }
      _currentIndex++;
      _currentTurnStartedAt = turnEnd;
    }

    _pickRemaining = _currentTurnStartedAt!.add(pickTime).difference(now);
    _updateTimeLabel();
    _persistActualDraftSession();
    if (notify) {
      setState(() {});
    }
  }

  void _advancePick() {
    _pickTimer?.cancel();
    _mockAiTimer?.cancel();
    if (_currentIndex < _order.length - 1) {
      setState(() => _currentIndex++);
      if (widget.isMock) {
        _handleTurnChange();
      } else {
        _currentTurnStartedAt = DateTime.now();
        _persistActualDraftSession();
        _startActualDraftClock();
      }
      return;
    }
    _finishDraft();
  }

  void _finishDraft({bool showSnackBar = true}) {
    _pickTimer?.cancel();
    _mockAiTimer?.cancel();
    if (!mounted || _draftComplete) return;
    final hadBlankSlots = _hasBlankSlots;
    setState(() {
      if (!widget.isMock) {
        _fillMissedPicksForActualDraft();
      }
      _draftComplete = true;
      _pickRemaining = Duration.zero;
      _timeLabel.value = '0:00';
    });
    _persistActualDraftSession();
    unawaited(_maybeFinalizeFantasyLeague());
    if (showSnackBar) {
      final message = !widget.isMock && hadBlankSlots
          ? 'Draft 완료! 빈칸은 포지션 최소 조건에 맞춰 자동 보정되었습니다.'
          : 'Draft 완료!';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  (int row, int col) _idxToPos(int idx) =>
      (idx ~/ widget.teamCount, idx % widget.teamCount);

  bool get _isMockUserTurn {
    if (!widget.isMock) return true;
    final mine = widget.myTeamName?.trim();
    if (mine == null || mine.isEmpty) return true;
    final (_, col) = _idxToPos(_order[_currentIndex]);
    return _teamNames[col].trim().toLowerCase() == mine.toLowerCase();
  }

  void _handleTurnChange() {
    _pickTimer?.cancel();
    _mockAiTimer?.cancel();
    if (_draftComplete || _currentIndex >= _order.length) return;
    if (widget.isMock && !_isMockUserTurn) {
      _pickRemaining = Duration.zero;
      _updateTimeLabel();
      _mockAiTimer = Timer(mockAiPickDelay, _autoPickOrAdvanceCurrentTurn);
      return;
    }
    _startPickTimer();
  }

  void _autoPickOrAdvanceCurrentTurn() {
    if (!mounted || _draftComplete || _currentIndex >= _order.length) return;
    final (row, col) = _idxToPos(_order[_currentIndex]);
    if (_board[row][col] != null) {
      _advancePick();
      return;
    }
    final available = _selectablePlayersForTeam(col);
    if (available.isEmpty) {
      _advancePick();
      return;
    }
    setState(() {
      _board[row][col] = available[_rand.nextInt(available.length)];
    });
    _advancePick();
  }

  Iterable<_PlayerSlot> _availablePlayers() =>
      _playerPool.where((p) => !_isPicked(p));

  bool _isCurrentCell(int row, int col) {
    if (_isBeforeActualStart) return false;
    if (_draftComplete || _currentIndex >= _order.length) return false;
    final (r, c) = _idxToPos(_order[_currentIndex]);
    return r == row && c == col;
  }

  bool _isPicked(_PlayerSlot p) =>
      _board.any((round) => round.any((sel) => sel?.name == p.name));

  bool get _hasBlankSlots =>
      _board.any((round) => round.any((slot) => slot == null));

  Map<String, int> _teamPositionCounts(int teamIdx) {
    final counts = <String, int>{};
    for (int row = 0; row < _rules.rounds; row++) {
      final slot = _board[row][teamIdx];
      if (slot == null) continue;
      counts.update(slot.position, (value) => value + 1, ifAbsent: () => 1);
    }
    return counts;
  }

  int _remainingEmptySlotsForTeam(int teamIdx) {
    int count = 0;
    for (int row = 0; row < _rules.rounds; row++) {
      if (_board[row][teamIdx] == null) {
        count++;
      }
    }
    return count;
  }

  bool _canStillMeetMinimumsAfterPick(int teamIdx, _PlayerSlot candidate) {
    final counts = _teamPositionCounts(teamIdx);
    counts.update(candidate.position, (value) => value + 1, ifAbsent: () => 1);
    final remainingSlotsAfterPick = _remainingEmptySlotsForTeam(teamIdx) - 1;
    int stillNeeded = 0;
    for (final entry in _rules.minimums.entries) {
      final have = counts[entry.key] ?? 0;
      stillNeeded += max(0, entry.value - have);
    }
    return stillNeeded <= remainingSlotsAfterPick;
  }

  List<_PlayerSlot> _selectablePlayersForTeam(int teamIdx) {
    final available = _availablePlayers().toList();
    final constrained = available
        .where((player) => _canStillMeetMinimumsAfterPick(teamIdx, player))
        .toList();
    return constrained.isNotEmpty ? constrained : available;
  }

  void _fillMissedPicksForActualDraft() {
    for (int teamIdx = 0; teamIdx < widget.teamCount; teamIdx++) {
      final blankRows = <int>[];
      for (int row = 0; row < _rules.rounds; row++) {
        if (_board[row][teamIdx] == null) {
          blankRows.add(row);
        }
      }
      if (blankRows.isEmpty) continue;

      final counts = _teamPositionCounts(teamIdx);
      for (final entry in _rules.minimums.entries) {
        while ((counts[entry.key] ?? 0) < entry.value && blankRows.isNotEmpty) {
          final candidate = _takeAvailablePlayerForPosition(entry.key);
          if (candidate == null) break;
          final row = blankRows.removeAt(0);
          _board[row][teamIdx] = candidate;
          counts.update(
            candidate.position,
            (value) => value + 1,
            ifAbsent: () => 1,
          );
        }
      }

      while (blankRows.isNotEmpty) {
        final available = _availablePlayers().toList();
        if (available.isEmpty) break;
        final row = blankRows.removeAt(0);
        _board[row][teamIdx] = available[_rand.nextInt(available.length)];
      }
    }
  }

  _PlayerSlot? _takeAvailablePlayerForPosition(String position) {
    final available = _availablePlayers()
        .where((player) => player.position == position)
        .toList();
    if (available.isEmpty) return null;
    return available[_rand.nextInt(available.length)];
  }

  List<Map<String, dynamic>> _serializeDraftBoard() {
    return _draftBoardToFirestoreRows(_board);
  }

  List<_FantasyTeamPlayer> _draftedRosterForTeam(int teamIdx) {
    final roster = <_FantasyTeamPlayer>[];
    for (int row = 0; row < _board.length; row++) {
      final slot = _board[row][teamIdx];
      if (slot == null) continue;
      roster.add(
        _FantasyTeamPlayer(
          name: slot.name,
          position: slot.position,
          score: slot.score,
        ),
      );
    }
    return roster;
  }

  List<_FantasyTeamPlayer> _buildSoccerStarting(
    List<_FantasyTeamPlayer> roster,
  ) {
    final gks = roster.where((p) => p.position == 'GK').toList()
      ..sort((a, b) => b.score.compareTo(a.score));
    final dfs = roster.where((p) => p.position == 'DF').toList()
      ..sort((a, b) => b.score.compareTo(a.score));
    final mfs = roster.where((p) => p.position == 'MF').toList()
      ..sort((a, b) => b.score.compareTo(a.score));
    final fws = roster.where((p) => p.position == 'FW').toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    const formations = [
      (4, 4, 2),
      (4, 3, 3),
      (3, 4, 3),
      (4, 5, 1),
      (3, 5, 2),
      (5, 4, 1),
      (5, 2, 3),
    ];
    for (final (dfNeed, mfNeed, fwNeed) in formations) {
      if (gks.isEmpty ||
          dfs.length < dfNeed ||
          mfs.length < mfNeed ||
          fws.length < fwNeed) {
        continue;
      }
      return [
        gks.first,
        ...dfs.take(dfNeed),
        ...mfs.take(mfNeed),
        ...fws.take(fwNeed),
      ];
    }
    return roster.take(11).toList();
  }

  List<_FantasyTeamPlayer> _buildBaseballStarting(
    List<_FantasyTeamPlayer> roster,
  ) {
    final catchers = roster.where((p) => p.position == 'C').toList()
      ..sort((a, b) => b.score.compareTo(a.score));
    final pitchers = roster.where((p) => p.position == 'P').toList()
      ..sort((a, b) => b.score.compareTo(a.score));
    final infielders = roster.where((p) => p.position == 'IF').toList()
      ..sort((a, b) => b.score.compareTo(a.score));
    final outfielders = roster.where((p) => p.position == 'OF').toList()
      ..sort((a, b) => b.score.compareTo(a.score));
    return [
      ...catchers.take(1),
      ...pitchers.take(1),
      ...infielders.take(4),
      ...outfielders.take(3),
    ];
  }

  List<_FantasyTeamState> _buildFantasyTeams() {
    final teams = <_FantasyTeamState>[];
    for (int teamIdx = 0; teamIdx < widget.teamCount; teamIdx++) {
      final roster = _draftedRosterForTeam(teamIdx);
      final starting = widget.isSoccer
          ? _buildSoccerStarting(roster)
          : _buildBaseballStarting(roster);
      final startingNames = starting.map((player) => player.name).toSet();
      final bench = roster
          .where((player) => !startingNames.contains(player.name))
          .toList();
      final entry = teamIdx < widget.draftOrderEntries.length
          ? widget.draftOrderEntries[teamIdx]
          : _DraftOrderEntry(
              uid: '',
              displayName: _teamNames[teamIdx],
              slot: teamIdx + 1,
            );
      teams.add(
        _FantasyTeamState(
          uid: entry.uid,
          teamName: _teamNames[teamIdx],
          roster: roster,
          starting: starting,
          bench: bench,
        ),
      );
    }
    return teams;
  }

  List<_FantasyScheduleMatchup> _buildFantasySchedule() {
    final entries = List<_DraftOrderEntry>.generate(widget.teamCount, (index) {
      if (index < widget.draftOrderEntries.length) {
        return widget.draftOrderEntries[index];
      }
      return _DraftOrderEntry(
        uid: '',
        displayName: _teamNames[index],
        slot: index + 1,
      );
    });
    var teams = entries
        .map((entry) => (uid: entry.uid, name: entry.displayName))
        .toList();
    final hasBye = teams.length.isOdd;
    if (hasBye) {
      teams = [...teams, (uid: '__bye__', name: 'BYE')];
    }

    final baseRounds = <List<_FantasyScheduleMatchup>>[];
    var rotation = [...teams];
    final roundsPerCycle = rotation.length - 1;
    for (int round = 0; round < roundsPerCycle; round++) {
      final pairings = <_FantasyScheduleMatchup>[];
      for (int i = 0; i < rotation.length / 2; i++) {
        final home = rotation[i];
        final away = rotation[rotation.length - 1 - i];
        if (home.uid == '__bye__' || away.uid == '__bye__') continue;
        pairings.add(
          _FantasyScheduleMatchup(
            round: round + 1,
            homeUid: round.isEven ? home.uid : away.uid,
            homeTeam: round.isEven ? home.name : away.name,
            awayUid: round.isEven ? away.uid : home.uid,
            awayTeam: round.isEven ? away.name : home.name,
          ),
        );
      }
      baseRounds.add(pairings);
      rotation = [
        rotation.first,
        rotation.last,
        ...rotation.sublist(1, rotation.length - 1),
      ];
    }

    final schedule = <_FantasyScheduleMatchup>[];
    for (int round = 1; round <= widget.roundCount; round++) {
      final cycleIndex = (round - 1) % baseRounds.length;
      final cycleNumber = (round - 1) ~/ baseRounds.length;
      for (final matchup in baseRounds[cycleIndex]) {
        final flip = cycleNumber.isOdd;
        schedule.add(
          _FantasyScheduleMatchup(
            round: round,
            homeUid: flip ? matchup.awayUid : matchup.homeUid,
            homeTeam: flip ? matchup.awayTeam : matchup.homeTeam,
            awayUid: flip ? matchup.homeUid : matchup.awayUid,
            awayTeam: flip ? matchup.homeTeam : matchup.awayTeam,
          ),
        );
      }
    }
    return schedule;
  }

  Future<void> _maybeFinalizeFantasyLeague() async {
    if (_finalizingFantasy || widget.isMock || widget.leagueId.isEmpty) return;
    _finalizingFantasy = true;
    try {
      await LeagueService.instance.finalizeFantasyLeague(
        leagueId: widget.leagueId,
        draftBoard: _serializeDraftBoard(),
        fantasyTeams: _buildFantasyTeams().map((team) => team.toMap()).toList(),
        fantasySchedule: _buildFantasySchedule()
            .map((matchup) => matchup.toMap())
            .toList(),
      );
    } catch (e) {
      debugPrint('finalizeFantasyLeague failed: $e');
    } finally {
      _finalizingFantasy = false;
    }
  }

  Future<void> _onCellTap(int row, int col) async {
    if (_isBeforeActualStart ||
        _draftComplete ||
        !_isCurrentCell(row, col) ||
        !_isMockUserTurn) {
      return;
    }
    final picked = await Navigator.push<_PlayerSlot>(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerSelectPage(
          available: _selectablePlayersForTeam(col),
          timeListenable: _timeLabel,
          filters: _rules.filters,
        ),
      ),
    );
    if (picked != null) {
      setState(() {
        _board[row][col] = picked;
      });
      _persistActualDraftSession();
      _advancePick();
    }
  }

  String get _footerLabel {
    if (_draftComplete) {
      return widget.isMock ? 'Mock Draft 완료' : 'Draft 완료 · 빈칸 자동 보정까지 반영됨';
    }
    if (_isBeforeActualStart) {
      return 'Draft 시작 대기';
    }
    final (curRow, curCol) = _idxToPos(_order[_currentIndex]);
    return '현재 픽: ${_teamNames[curCol]} · ${_ord(curRow + 1)} 라운드';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_isLoadingPlayerPool) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            '${widget.leagueName} ${widget.isMock ? 'Mock Draft' : 'Draft'}',
          ),
        ),
        body: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 12),
              Text(
                'KBO 선수 로스터 불러오는 중',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${widget.leagueName} ${widget.isMock ? 'Mock Draft' : 'Draft'}',
        ),
      ),
      body: Column(
        children: [
          const SizedBox(height: 8),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: widget.isMock
                  ? Colors.orange.withOpacity(0.10)
                  : cs.primary.withOpacity(0.10),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: widget.isMock
                    ? Colors.orange.withOpacity(0.24)
                    : cs.primary.withOpacity(0.24),
              ),
            ),
            child: Text(
              widget.isMock
                  ? 'Mock Draft · ${widget.isSoccer ? 'K리그 18명' : 'KBO 21명'} 기준으로 연습용으로 진행됩니다.'
                  : '실제 Draft · ${_rules.rosterSummary}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _timerText,
            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: LayoutBuilder(
              builder: (ctx, constraints) {
                final double rowHeight =
                    (constraints.maxHeight - 40) / (widget.teamCount + 1);
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SingleChildScrollView(
                    child: DataTable(
                      headingRowHeight: max(40, rowHeight),
                      dataRowMinHeight: max(48, rowHeight - 2),
                      dataRowMaxHeight: max(72, rowHeight + 10),
                      columnSpacing: 28,
                      columns: [
                        const DataColumn(label: Text('팀')),
                        for (int r = 0; r < _rules.rounds; r++)
                          DataColumn(label: Text(_ord(r + 1))),
                      ],
                      rows: List.generate(widget.teamCount, (teamIdx) {
                        return DataRow(
                          cells: [
                            DataCell(Text(_teamNames[teamIdx])),
                            for (int r = 0; r < _rules.rounds; r++)
                              DataCell(
                                AnimatedBuilder(
                                  animation: _blinkController,
                                  builder: (context, _) {
                                    final active = _isCurrentCell(r, teamIdx);
                                    final bg = active
                                        ? cs.error.withOpacity(
                                            _blinkController.value * 0.35,
                                          )
                                        : Colors.transparent;
                                    return Container(
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: Colors.black54,
                                          width: 0.8,
                                        ),
                                        color: bg,
                                      ),
                                      child: Center(
                                        child: _board[r][teamIdx] == null
                                            ? const SizedBox.shrink()
                                            : Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                    ),
                                                child: Text(
                                                  _board[r][teamIdx]!.name,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                      ),
                                    );
                                  },
                                ),
                                onTap: () => _onCellTap(r, teamIdx),
                              ),
                          ],
                        );
                      }),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Text(
              _footerLabel,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class PlayerSelectPage extends StatefulWidget {
  final List<_PlayerSlot> available;
  final ValueListenable<String> timeListenable;
  final List<_DraftPlayerFilter> filters;
  const PlayerSelectPage({
    super.key,
    required this.available,
    required this.timeListenable,
    required this.filters,
  });

  @override
  State<PlayerSelectPage> createState() => _PlayerSelectPageState();
}

class _PlayerSelectPageState extends State<PlayerSelectPage> {
  _DraftPlayerFilter _filter = _DraftPlayerFilter.all;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.available.where((p) {
      final filterPosition = _filter.position;
      final matchesFilter =
          filterPosition == null || p.position == filterPosition;
      final matchesQuery =
          _query.isEmpty || p.name.toLowerCase().contains(_query.toLowerCase());
      return matchesFilter && matchesQuery;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Player'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: ValueListenableBuilder<String>(
                valueListenable: widget.timeListenable,
                builder: (_, v, __) => Text(
                  v,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: '선수 검색',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ),
              ],
            ),
          ),
          Wrap(
            spacing: 8,
            children: widget.filters.map((f) {
              final active = _filter == f;
              return ChoiceChip(
                label: Text(f.label),
                selected: active,
                onSelected: (_) => setState(() => _filter = f),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              itemCount: filtered.length,
              itemBuilder: (ctx, i) {
                final p = filtered[i];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blueAccent.withOpacity(0.1),
                    child: Text(
                      p.position,
                      style: const TextStyle(fontSize: 11, color: Colors.blue),
                    ),
                  ),
                  title: Text(p.name),
                  subtitle: Text('포지션: ${p.position}'),
                  trailing: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, p),
                    child: const Text('Draft'),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
