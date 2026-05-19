part of '../home_page.dart';

enum PlayerOwnership { myTeam, otherTeam, freeAgent }

final Map<String, List<_PlayerRoundPoints>> _kLeaguePlayerRoundPointsCache =
    <String, List<_PlayerRoundPoints>>{};
final Map<String, Future<List<_PlayerRoundPoints>>>
_kLeaguePlayerRoundPointsInFlight =
    <String, Future<List<_PlayerRoundPoints>>>{};

String _kLeaguePlayerRoundPointsCacheKey({
  required String playerName,
  required String canonicalClub,
  required int number,
}) => '$canonicalClub|$number|$playerName';

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
  late final Future<_PlayerFantasyProfileData?> _fantasyProfileFuture;

  @override
  void initState() {
    super.initState();
    _fantasyProfileFuture = _loadFantasyProfileData();
  }

  void _toggleMyPage() => setState(() => _isMyPageOpen = !_isMyPageOpen);

  Future<_PlayerFantasyProfileData?> _loadFantasyProfileData() async {
    var loadedRoundPoints = const <_PlayerRoundPoints>[];
    try {
      final meta = widget.metaOverride != null
          ? (
              position: widget.metaOverride!.position,
              club: widget.metaOverride!.club,
              number: widget.metaOverride!.number,
            )
          : _resolvePlayerMeta(widget.name);
      final isSoccerPlayer = _normalizeFantasySoccerPosition(
        meta.position,
      ).isNotEmpty;
      if (!isSoccerPlayer) return null;

      loadedRoundPoints = await _loadKLeagueRoundPointsForPlayer(
        playerName: widget.name,
        club: meta.club,
      );

      final homeState = homeKey.currentState;
      if (homeState == null) {
        return _PlayerFantasyProfileData(
          draft: null,
          team: null,
          roundPoints: loadedRoundPoints.reversed.toList(),
        );
      }
      unawaited(
        homeState._refreshFantasySoccerScores().catchError((
          Object error,
          StackTrace stackTrace,
        ) {
          debugPrint(
            'Player profile fantasy refresh failed for ${widget.name}: $error',
          );
          debugPrint('$stackTrace');
        }),
      );

      final soccerDrafts =
          homeState._joinedDrafts
              .where(
                (draft) =>
                    draft.isSoccer &&
                    draft.fantasyReady &&
                    draft.fantasyTeams.isNotEmpty &&
                    draft.fantasySchedule.isNotEmpty,
              )
              .toList()
            ..sort((a, b) => a.when.compareTo(b.when));

      for (final draft in soccerDrafts) {
        _FantasyTeamState? matchedTeam;
        for (final team in draft.fantasyTeams) {
          if (team.roster.any((player) => player.name == widget.name)) {
            matchedTeam = team;
            break;
          }
        }
        if (matchedTeam == null) continue;

        return _PlayerFantasyProfileData(
          draft: draft,
          team: matchedTeam,
          roundPoints: loadedRoundPoints.reversed.toList(),
        );
      }

      return _PlayerFantasyProfileData(
        draft: null,
        team: null,
        roundPoints: loadedRoundPoints.reversed.toList(),
      );
    } catch (error, stackTrace) {
      debugPrint('Player profile load failed for ${widget.name}: $error');
      debugPrint('$stackTrace');
      return _PlayerFantasyProfileData(
        draft: null,
        team: null,
        roundPoints: loadedRoundPoints.reversed.toList(),
      );
    }
  }

  Future<List<_PlayerRoundPoints>> _loadKLeagueRoundPointsForPlayer({
    required String playerName,
    required String club,
  }) async {
    final meta = _resolvePlayerMeta(playerName);
    final canonicalClub = _canonicalKLeagueClub(club);
    final cacheKey = _kLeaguePlayerRoundPointsCacheKey(
      playerName: playerName,
      canonicalClub: canonicalClub,
      number: meta.number,
    );
    final cached = _kLeaguePlayerRoundPointsCache[cacheKey];
    if (cached != null) return cached;
    final inFlight = _kLeaguePlayerRoundPointsInFlight[cacheKey];
    if (inFlight != null) return inFlight;

    final future = () async {
      final leagueData = await ApiService.fetchLeagueData();
      final rawFixtures = _fixtureAsList(leagueData['fixtures']);
      final fixtures = _kLeagueFixturesFromApi(rawFixtures);
      final now = DateTime.now();

      int latestRound = 0;
      for (final fixture in fixtures) {
        final roundNumber = _roundNumber(fixture.round);
        if (roundNumber <= 0) continue;
        final started =
            !fixture.date.isAfter(now) ||
            _isKLeagueFinalStatus(fixture.statusShort) ||
            fixture.minuteLabel.isNotEmpty;
        if (!started) continue;
        if (roundNumber > latestRound) latestRound = roundNumber;
      }
      if (latestRound <= 0) return const <_PlayerRoundPoints>[];

      final roundTotals = <int, _KLeaguePlayerRoundAccumulator>{};
      for (int round = 1; round <= latestRound; round++) {
        roundTotals[round] = _KLeaguePlayerRoundAccumulator.empty(round);
      }
      final relevantFixtures =
          <({int round, int fixtureId, String opponentLabel})>[];

      for (final raw in rawFixtures) {
        final map = _fixtureAsMap(raw);
        final league = _fixtureAsMap(map['league']);
        final round = _roundNumber(_fixtureText(league['round']));
        if (round <= 0 || round > latestRound) continue;

        final fixture = _fixtureAsMap(map['fixture']);
        final teams = _fixtureAsMap(map['teams']);
        final date = DateTime.tryParse(_fixtureText(fixture['date']));
        if (date == null) continue;
        final homeClub = _canonicalKLeagueClub(
          _kLeagueDisplayTeamName(
            _fixtureText(_fixtureAsMap(teams['home'])['name']),
          ),
        );
        final awayClub = _canonicalKLeagueClub(
          _kLeagueDisplayTeamName(
            _fixtureText(_fixtureAsMap(teams['away'])['name']),
          ),
        );
        if (homeClub != canonicalClub && awayClub != canonicalClub) continue;
        final opponentLabel = homeClub == canonicalClub
            ? _kLeagueDisplayTeamName(
                _fixtureText(_fixtureAsMap(teams['away'])['name']),
              )
            : _kLeagueDisplayTeamName(
                _fixtureText(_fixtureAsMap(teams['home'])['name']),
              );

        final started =
            !date.isAfter(now) ||
            _isKLeagueFinalStatus(
              _fixtureText(_fixtureAsMap(fixture['status'])['short']),
            ) ||
            _fixtureMinuteLabel(
              _fixtureText(_fixtureAsMap(fixture['status'])['elapsed']),
              _fixtureText(_fixtureAsMap(fixture['status'])['extra']),
            ).isNotEmpty;
        if (!started) continue;

        final fixtureId = _readNullableInt(fixture['id']);
        if (fixtureId == null || fixtureId <= 0) continue;
        relevantFixtures.add((
          round: round,
          fixtureId: fixtureId,
          opponentLabel: opponentLabel,
        ));
      }

      final results = await Future.wait(
        relevantFixtures.map((fixtureInfo) async {
          try {
            final detail = await ApiService.fetchFixtureDetails(
              fixtureInfo.fixtureId,
            );
            final score = _kLeagueRoundScoreBreakdownForPlayerFromDetail(
              detail,
              playerName: playerName,
              canonicalClub: canonicalClub,
              number: '${meta.number}',
              opponentLabel: fixtureInfo.opponentLabel,
            );
            return (round: fixtureInfo.round, score: score);
          } catch (error, stackTrace) {
            debugPrint(
              'Round points detail load failed for $playerName '
              '(round=${fixtureInfo.round}, fixture=${fixtureInfo.fixtureId}): $error',
            );
            debugPrint('$stackTrace');
            return (
              round: fixtureInfo.round,
              score: _KLeaguePlayerRoundAccumulator.empty(
                fixtureInfo.round,
                opponentLabel: fixtureInfo.opponentLabel,
              ),
            );
          }
        }),
      );

      for (final result in results) {
        roundTotals[result.round] =
            (roundTotals[result.round] ??
                    _KLeaguePlayerRoundAccumulator.empty(result.round))
                .merge(result.score);
      }

      final computed = [
        for (int round = 1; round <= latestRound; round++)
          _PlayerRoundPoints.fromAccumulator(roundTotals[round]!),
      ];
      _kLeaguePlayerRoundPointsCache[cacheKey] = computed;
      return computed;
    }();

    _kLeaguePlayerRoundPointsInFlight[cacheKey] = future;
    try {
      return await future;
    } finally {
      _kLeaguePlayerRoundPointsInFlight.remove(cacheKey);
    }
  }

  _KLeaguePlayerRoundAccumulator _kLeagueRoundScoreBreakdownForPlayerFromDetail(
    Map<String, dynamic> detail, {
    required String playerName,
    required String canonicalClub,
    required String number,
    required String opponentLabel,
  }) {
    final fallbackMeta = _resolvePlayerMeta(playerName);
    final detailFixture = _fixtureAsMap(detail['fixture']);
    final fixtureMeta = _fixtureAsMap(detailFixture['fixture']);
    final teams = _fixtureAsMap(detailFixture['teams']);
    final goals = _fixtureAsMap(detailFixture['goals']);
    final lineups = _fixtureAsList(detail['lineups']);
    final players = _fixtureAsList(detail['players']);
    final events = _fixtureAsList(detail['events']);
    final playerNames = _eventPlayerNameMap(lineups);
    final totalMinutes = _kLeagueFixtureTotalMinutes(fixtureMeta, events);

    _LineupPlayer? targetPlayer;
    Map<String, dynamic>? targetPlayerStats;
    var started = false;
    int? statsMinutes;

    for (final rawLineup in lineups) {
      final lineup = _fixtureAsMap(rawLineup);
      final team = _fixtureAsMap(lineup['team']);
      final club = _canonicalKLeagueClub(
        _kLeagueDisplayTeamName(_fixtureText(team['name'])),
      );
      if (club != canonicalClub) continue;

      for (final raw in _fixtureAsList(lineup['startXI'])) {
        final player = _lineupPlayerFromRaw(raw, lineup: lineup);
        if (player == null) continue;
        if (player.number.trim() == number.trim()) {
          targetPlayer = player;
          started = true;
          break;
        }
      }
      if (targetPlayer != null) break;

      for (final raw in _fixtureAsList(lineup['substitutes'])) {
        final player = _lineupPlayerFromRaw(raw, lineup: lineup);
        if (player == null) continue;
        if (player.number.trim() == number.trim()) {
          targetPlayer = player;
          started = false;
          break;
        }
      }
      if (targetPlayer != null) break;
    }

    for (final rawTeamBlock in players) {
      final teamBlock = _fixtureAsMap(rawTeamBlock);
      final team = _fixtureAsMap(teamBlock['team']);
      final club = _canonicalKLeagueClub(
        _kLeagueDisplayTeamName(_fixtureText(team['name'])),
      );
      if (club != canonicalClub) continue;
      for (final rawPlayerBlock in _fixtureAsList(teamBlock['players'])) {
        final playerBlock = _fixtureAsMap(rawPlayerBlock);
        final player = _fixtureAsMap(playerBlock['player']);
        final statsList = _fixtureAsList(playerBlock['statistics']);
        final statsEntry = statsList.isNotEmpty
            ? _fixtureAsMap(statsList.first)
            : const <String, dynamic>{};
        final games = _fixtureAsMap(statsEntry['games']);
        final gamesNumber = _readNullableInt(games['number']);
        final playerNumber = _readNullableInt(player['number']);
        final playerId = _fixtureText(player['id']);
        final matchesByNumber =
            (gamesNumber != null && gamesNumber.toString() == number) ||
            (playerNumber != null && playerNumber.toString() == number);
        final matchesById =
            targetPlayer != null &&
            playerId.isNotEmpty &&
            playerId == targetPlayer!.id;
        if (!matchesByNumber && !matchesById) continue;
        targetPlayerStats = playerBlock;
        statsMinutes = _readNullableInt(games['minutes']);
        if (targetPlayer == null) {
          targetPlayer = _LineupPlayer(
            id: _fixtureText(player['id']),
            originalName: _fixtureText(player['name']),
            name: _fixtureText(player['name']).isNotEmpty
                ? _fixtureText(player['name'])
                : playerName,
            number: number,
            position: _fixtureText(games['position']).isNotEmpty
                ? _fixtureText(games['position'])
                : fallbackMeta.position,
            gridLine: null,
            gridColumn: null,
          );
        }
        started = games['substitute'] != true;
        break;
      }
      if (targetPlayerStats != null) break;
    }

    final round = _roundNumber(
      _fixtureText(_fixtureAsMap(detailFixture['league'])['round']),
    );
    if (targetPlayer == null) {
      return _KLeaguePlayerRoundAccumulator.empty(
        round,
        opponentLabel: opponentLabel,
      );
    }

    final playerId = targetPlayer.id;
    final playerDisplayName = targetPlayer.name;
    final normalizedPosition = _normalizeFantasySoccerPosition(
      targetPlayer.position,
    );

    bool matchesTarget(Map<String, dynamic> player) {
      final eventId = _fixtureText(player['id']);
      if (playerId.isNotEmpty && eventId.isNotEmpty && eventId == playerId) {
        return true;
      }
      final displayName = _eventPlayerDisplayName(player, playerNames);
      if (displayName.isNotEmpty && displayName == playerDisplayName) {
        return true;
      }
      final rawName = _fixtureText(player['name']);
      return rawName.isNotEmpty &&
          (rawName == playerDisplayName || rawName == playerName);
    }

    int? subOutMinute;
    int? subInMinute;
    var goalsCount = 0;
    var assistsCount = 0;
    var yellowCards = 0;
    var redCards = 0;
    var missedPenalties = 0;
    var ownGoals = 0;

    for (final raw in events) {
      final event = _fixtureAsMap(raw);
      final type = _fixtureText(event['type']);
      final detailText = _fixtureText(event['detail']);
      final player = _fixtureAsMap(event['player']);
      final assist = _fixtureAsMap(event['assist']);
      final minute = _kLeagueEventMinuteValue(_fixtureAsMap(event['time']));

      if (type == 'subst' || type == 'Subst') {
        if (matchesTarget(player)) subOutMinute = minute;
        if (matchesTarget(assist)) subInMinute = minute;
        continue;
      }

      if (type == 'Goal') {
        if (matchesTarget(player)) {
          if (detailText == 'Own Goal') {
            ownGoals += 1;
          } else if (detailText == 'Missed Penalty') {
            missedPenalties += 1;
          } else {
            goalsCount += 1;
          }
        }
        if (matchesTarget(assist)) {
          assistsCount += 1;
        }
        continue;
      }

      if (type == 'Card' && matchesTarget(player)) {
        if (detailText.contains('Red')) {
          redCards += 1;
        } else if (detailText.contains('Yellow')) {
          yellowCards += 1;
        }
      }
    }

    final playedMinutes =
        statsMinutes ??
        (started
            ? (subOutMinute ?? totalMinutes)
            : (subInMinute != null ? max(0, totalMinutes - subInMinute) : 0));
    final appeared =
        (statsMinutes != null && statsMinutes > 0) ||
        started ||
        subInMinute != null;

    final homeTeam = _fixtureAsMap(teams['home']);
    final awayTeam = _fixtureAsMap(teams['away']);
    final homeClub = _canonicalKLeagueClub(
      _kLeagueDisplayTeamName(_fixtureText(homeTeam['name'])),
    );
    final awayClub = _canonicalKLeagueClub(
      _kLeagueDisplayTeamName(_fixtureText(awayTeam['name'])),
    );
    final homeGoals = _readNullableInt(goals['home']) ?? 0;
    final awayGoals = _readNullableInt(goals['away']) ?? 0;
    final isFinal = _isKLeagueFinalStatus(
      _fixtureText(_fixtureAsMap(fixtureMeta['status'])['short']),
    );

    double teamResultPoints = 0;
    if (appeared && isFinal) {
      if (homeGoals == awayGoals) {
        teamResultPoints = 1;
      } else if ((canonicalClub == homeClub && homeGoals > awayGoals) ||
          (canonicalClub == awayClub && awayGoals > homeGoals)) {
        teamResultPoints = 3;
      }
    }
    final cleanSheetPoints =
        appeared &&
            isFinal &&
            ((canonicalClub == homeClub && awayGoals == 0) ||
                (canonicalClub == awayClub && homeGoals == 0))
        ? _kLeagueCleanSheetPoints(normalizedPosition)
        : 0.0;

    final details = <_PlayerRoundPointDetail>[];
    void addDetail(String label, double points, {String? detail}) {
      if (points == 0) return;
      details.add(
        _PlayerRoundPointDetail(label: label, detail: detail, points: points),
      );
    }

    addDetail('출전', playedMinutes * 0.1, detail: '$playedMinutes분');
    addDetail(
      '득점',
      goalsCount * _kLeagueGoalPoints(normalizedPosition),
      detail: '$goalsCount회',
    );
    addDetail(
      '어시스트',
      assistsCount * _kLeagueAssistPoints(normalizedPosition),
      detail: '$assistsCount회',
    );
    addDetail('옐로카드', yellowCards * -1.0, detail: '$yellowCards회');
    addDetail('레드카드', redCards * -3.0, detail: '$redCards회');
    addDetail('페널티킥 실축', missedPenalties * -1.0, detail: '$missedPenalties회');
    addDetail('자책골', ownGoals * -2.0, detail: '$ownGoals회');
    addDetail('무실점', cleanSheetPoints);
    if (appeared && isFinal) {
      final resultLabel = homeGoals == awayGoals
          ? '무승부'
          : (teamResultPoints > 0 ? '승리' : '패배');
      addDetail('경기 결과', teamResultPoints, detail: resultLabel);
    }

    return _KLeaguePlayerRoundAccumulator(
      round: round,
      basePoints: details.fold(0.0, (total, item) => total + item.points),
      appeared: appeared,
      details: details,
      opponentLabel: opponentLabel,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    // Prefer the app's session ownership cache when available so profiles opened
    // from different entry points (home search, schedule, etc.) stay consistent.
    final resolvedOwnership =
        _MatchDetailPageState._playerOwnerCache[widget.name] ??
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
      child: FutureBuilder<_PlayerFantasyProfileData?>(
        future: _fantasyProfileFuture,
        builder: (context, snapshot) {
          final fantasyData = snapshot.data;
          final fantasyTeamName = fantasyData?.team?.teamName ?? '—';
          final roundPoints =
              fantasyData?.roundPoints ?? const <_PlayerRoundPoints>[];

          Widget roundPointsSection() {
            return Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: isDark ? Colors.white10 : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Round points',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: text,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (snapshot.connectionState == ConnectionState.waiting)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (roundPoints.isEmpty)
                    Text(
                      '이전 라운드 포인트가 아직 없습니다.',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: muted,
                      ),
                    )
                  else
                    ...roundPoints.map((entry) {
                      final badge = entry.isCaptain
                          ? 'C'
                          : (entry.isViceCaptain ? 'VC' : null);
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.black12
                              : const Color(0xFFF8F8F8),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: border),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        entry.opponentLabel == null ||
                                                entry.opponentLabel!.isEmpty
                                            ? 'Round ${entry.round}'
                                            : 'Round ${entry.round} · vs ${entry.opponentLabel}',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w900,
                                          color: text,
                                        ),
                                      ),
                                      if (badge != null) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: entry.isCaptain
                                                ? const Color(0xFFFFCF4D)
                                                : Colors.white,
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                            border: Border.all(
                                              color: entry.isCaptain
                                                  ? const Color(0xFFE0B331)
                                                  : const Color(0xFF7EA9FF),
                                            ),
                                          ),
                                          child: Text(
                                            badge,
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w900,
                                              color: entry.isCaptain
                                                  ? const Color(0xFF1F1F1F)
                                                  : const Color(0xFF4672E8),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Fpts ${entry.displayedPoints.toStringAsFixed(1)}'
                                    '${entry.isCaptain ? ' · base ${entry.basePoints.toStringAsFixed(1)}' : ''}'
                                    '${entry.isViceCaptain ? ' · VC' : ''}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: muted,
                                    ),
                                  ),
                                  if (entry.details.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    ...entry.details.map(
                                      (detail) => Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                detail.detail == null ||
                                                        detail.detail!.isEmpty
                                                    ? detail.label
                                                    : '${detail.label} · ${detail.detail}',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                  color: muted,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              '${detail.points >= 0 ? '+' : ''}${detail.points.toStringAsFixed(1)}',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w900,
                                                color: detail.points >= 0
                                                    ? text
                                                    : const Color(0xFFD94141),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            );
          }

          return ListView(
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
              infoTile('판타지 팀', fantasyTeamName),
              const SizedBox(height: 10),
              infoTile('Apts', '—'),
              const SizedBox(height: 24),
              roundPointsSection(),
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
          );
        },
      ),
    );
  }
}

class _PlayerFantasyProfileData {
  final _JoinedDraft? draft;
  final _FantasyTeamState? team;
  final List<_PlayerRoundPoints> roundPoints;

  const _PlayerFantasyProfileData({
    required this.draft,
    required this.team,
    required this.roundPoints,
  });
}

class _PlayerRoundPoints {
  final int round;
  final double displayedPoints;
  final double basePoints;
  final bool isCaptain;
  final bool isViceCaptain;
  final bool appeared;
  final List<_PlayerRoundPointDetail> details;
  final String? opponentLabel;

  const _PlayerRoundPoints({
    required this.round,
    required this.displayedPoints,
    required this.basePoints,
    required this.isCaptain,
    required this.isViceCaptain,
    required this.appeared,
    required this.details,
    required this.opponentLabel,
  });

  factory _PlayerRoundPoints.fromAccumulator(
    _KLeaguePlayerRoundAccumulator accumulator,
  ) {
    return _PlayerRoundPoints(
      round: accumulator.round,
      displayedPoints: accumulator.basePoints,
      basePoints: accumulator.basePoints,
      isCaptain: false,
      isViceCaptain: false,
      appeared: accumulator.appeared,
      details: accumulator.details,
      opponentLabel: accumulator.opponentLabel,
    );
  }
}

class _PlayerRoundPointDetail {
  final String label;
  final String? detail;
  final double points;

  const _PlayerRoundPointDetail({
    required this.label,
    this.detail,
    required this.points,
  });
}

class _KLeaguePlayerRoundAccumulator {
  final int round;
  final double basePoints;
  final bool appeared;
  final List<_PlayerRoundPointDetail> details;
  final String? opponentLabel;

  const _KLeaguePlayerRoundAccumulator({
    required this.round,
    required this.basePoints,
    required this.appeared,
    required this.details,
    required this.opponentLabel,
  });

  factory _KLeaguePlayerRoundAccumulator.empty(
    int round, {
    String? opponentLabel,
  }) {
    return _KLeaguePlayerRoundAccumulator(
      round: round,
      basePoints: 0,
      appeared: false,
      details: const <_PlayerRoundPointDetail>[],
      opponentLabel: opponentLabel,
    );
  }

  _KLeaguePlayerRoundAccumulator merge(_KLeaguePlayerRoundAccumulator other) {
    return _KLeaguePlayerRoundAccumulator(
      round: round,
      basePoints: basePoints + other.basePoints,
      appeared: appeared || other.appeared,
      details: [...details, ...other.details],
      opponentLabel: (opponentLabel != null && opponentLabel!.isNotEmpty)
          ? opponentLabel
          : other.opponentLabel,
    );
  }
}

void _ensureFantasyOwnershipCacheInitialized() {
  // Ensure a stable player pool.
  _MatchDetailPageState._cachedSoccerPlayers ??= _buildPlayerPool(
    Random(_stableSeedFromKey('pool|kLeague')),
  );

  final pool = _MatchDetailPageState._cachedSoccerPlayers!;

  // Ensure my roster (18) exists so sign/trade flows can work from profiles too.
  if (_MatchDetailPageState._myTeamRosterOrder.isEmpty) {
    final seeded = Random(_stableSeedFromKey('init|myRoster'));
    final lineup =
        _MatchDetailPageState._cachedSoccerLineup ??
        _generateLineup(isSoccer: true, random: seeded);
    _MatchDetailPageState._cachedSoccerLineup = lineup;

    final starting = lineup.home
        .expand((p) => p.slots)
        .map((s) => s.name)
        .toList();
    _MatchDetailPageState._myTeamRosterOrder
      ..clear()
      ..addAll(starting.take(11));
    _MatchDetailPageState._myTeamRosterSet
      ..clear()
      ..addAll(_MatchDetailPageState._myTeamRosterOrder);

    final benchCandidates =
        pool
            .where(
              (p) => !_MatchDetailPageState._myTeamRosterSet.contains(p.name),
            )
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
      final Color surface = isDark
          ? const Color.fromARGB(255, 30, 30, 30)
          : theme.cardColor;
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
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(18),
              ),
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

  final formation =
      _formationKeyForCounts(df: dfs.length, mf: mfs.length, fw: fws.length) ??
      lineup.homeFormation;

  final newHome = <_Player>[
    _Player(
      slots: [
        _PlayerSlot(name: gk.name, score: gk.score, position: gk.position),
      ],
    ),
    _Player(
      slots: dfs
          .map(
            (p) =>
                _PlayerSlot(name: p.name, score: p.score, position: p.position),
          )
          .toList(),
    ),
    _Player(
      slots: mfs
          .map(
            (p) =>
                _PlayerSlot(name: p.name, score: p.score, position: p.position),
          )
          .toList(),
    ),
    _Player(
      slots: fws
          .map(
            (p) =>
                _PlayerSlot(name: p.name, score: p.score, position: p.position),
          )
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

  final own =
      _MatchDetailPageState._playerOwnerCache[name] ??
      (_MatchDetailPageState._isFreeAgent(name)
          ? PlayerOwnership.freeAgent
          : PlayerOwnership.otherTeam);
  if (own != PlayerOwnership.freeAgent) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('이미 다른 팀에 소속된 선수입니다.')));
    return;
  }

  final fa = _slotForName(name);
  final order = _MatchDetailPageState._myTeamRosterOrder;
  final set = _MatchDetailPageState._myTeamRosterSet;

  if (set.contains(name)) {
    _MatchDetailPageState._playerOwnerCache[name] = PlayerOwnership.myTeam;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$name 선수가 이미 내 로스터에 있습니다.')));
    return;
  }

  if (order.length < 18) {
    order.add(name);
    set.add(name);
    _MatchDetailPageState._playerOwnerCache[name] = PlayerOwnership.myTeam;
    _rebuildCachedMyLineupFromRosterOrder();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${fa.name} 선수를 영입했습니다.')));
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
          content: Text('${released.position} 벤치 선수가 없어서\n이 선수는 방출할 수 없습니다.'),
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

  final own =
      _MatchDetailPageState._playerOwnerCache[targetName] ??
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
      SnackBar(content: Text('${offered.name} ↔ $targetName 트레이드 요청을 보냈습니다.')),
    );
  }
}
