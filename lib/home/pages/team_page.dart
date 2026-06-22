part of '../home_page.dart';

class _KLeagueTeamNextMatch {
  final String homeTeam;
  final String awayTeam;
  final bool isHome;
  final String roundLabel;
  final DateTime kickoff;
  final String venueLabel;

  const _KLeagueTeamNextMatch({
    required this.homeTeam,
    required this.awayTeam,
    required this.isHome,
    required this.roundLabel,
    required this.kickoff,
    required this.venueLabel,
  });

  String get opponent => isHome ? awayTeam : homeTeam;
}

class _KLeagueTeamAppearanceLineup {
  final _SupportedFormation formation;
  final List<_PlayerSlot> starting;
  final Map<String, int> goalsByIdentity;
  final Map<String, int> assistsByIdentity;

  const _KLeagueTeamAppearanceLineup({
    required this.formation,
    required this.starting,
    required this.goalsByIdentity,
    required this.assistsByIdentity,
  });

  Map<String, _PlayerSlot> get rosterByIdentity => {
    for (final slot in starting) _playerSlotIdentity(slot): slot,
  };

  List<_Player> get rows =>
      _rowsFromSoccerStartingSlots(starting).reversed.toList();

  int goalsForSlot(_PlayerSlot slot) =>
      goalsByIdentity[_playerSlotIdentity(slot)] ?? 0;

  int assistsForSlot(_PlayerSlot slot) =>
      assistsByIdentity[_playerSlotIdentity(slot)] ?? 0;
}

class _KLeagueTeamPageData {
  final int rank;
  final List<String> recentForm;
  final _KLeagueTeamNextMatch? nextMatch;
  final _KLeagueTeamAppearanceLineup? lineup;

  const _KLeagueTeamPageData({
    required this.rank,
    required this.recentForm,
    required this.nextMatch,
    required this.lineup,
  });
}

class _KboTeamAppearanceLineup {
  final List<_PlayerSlot> starting;
  final Map<String, int> startsByIdentity;
  final Map<String, int> appearancesByIdentity;

  const _KboTeamAppearanceLineup({
    required this.starting,
    required this.startsByIdentity,
    required this.appearancesByIdentity,
  });

  Map<String, _PlayerSlot> get rosterByIdentity => {
    for (final slot in starting) _playerSlotIdentity(slot): slot,
  };

  double startsForSlot(_PlayerSlot slot) =>
      (startsByIdentity[_playerSlotIdentity(slot)] ?? 0).toDouble();

  int appearancesForSlot(_PlayerSlot slot) =>
      appearancesByIdentity[_playerSlotIdentity(slot)] ?? 0;
}

class _KboTeamNextMatch {
  final String homeTeam;
  final String awayTeam;
  final bool isHome;
  final String dateTimeLabel;
  final String venueLabel;

  const _KboTeamNextMatch({
    required this.homeTeam,
    required this.awayTeam,
    required this.isHome,
    required this.dateTimeLabel,
    required this.venueLabel,
  });

  String get opponent => isHome ? awayTeam : homeTeam;
}

class _KboTeamPageData {
  final int rank;
  final _KboTeamNextMatch? nextMatch;
  final _KboTeamAppearanceLineup? lineup;

  const _KboTeamPageData({
    required this.rank,
    required this.nextMatch,
    required this.lineup,
  });
}

class TeamPage extends StatefulWidget {
  final bool isSoccer;
  final String team;

  const TeamPage({super.key, required this.isSoccer, required this.team});

  @override
  State<TeamPage> createState() => _TeamPageState();
}

class _TeamPageState extends State<TeamPage> {
  bool _isMyPageOpen = false;
  late final Future<_KLeagueTeamPageData> _soccerTeamFuture;
  late final Future<_KboTeamPageData> _kboTeamFuture;

  @override
  void initState() {
    super.initState();
    _soccerTeamFuture = _loadSoccerTeamPageData();
    if (!widget.isSoccer) {
      _kboTeamFuture = _loadKboTeamPageData();
    }
  }

  Future<_KLeagueTeamPageData> _loadSoccerTeamPageData() async {
    final leagueData = await _loadCachedKLeagueLeagueData();
    final standings = _soccerRowsFromApi(
      leagueData['standings'] as List<dynamic>?,
    );
    final teamRow = standings.cast<_SoccerStandingsRow?>().firstWhere(
      (row) => row?.team == widget.team,
      orElse: () => null,
    );
    final rank = teamRow == null ? 0 : standings.indexOf(teamRow) + 1;
    final nextMatch = _resolveNextKLeagueMatch(leagueData);
    final lineup = await _buildKLeagueAppearanceLineup(leagueData);
    return _KLeagueTeamPageData(
      rank: rank,
      recentForm: _recentFormTokens(teamRow?.form ?? ''),
      nextMatch: nextMatch,
      lineup: lineup,
    );
  }

  Future<_KboTeamPageData> _loadKboTeamPageData() async {
    final leagueData = await _loadCachedKboLeagueData();
    final standings = _baseballRowsFromApi(
      leagueData['standings'] as List<dynamic>?,
    );
    final team = _normalizeKboDraftClub(_kboDisplayTeamName(widget.team));
    var rank = 0;
    for (var index = 0; index < standings.length; index++) {
      final rowTeam = _normalizeKboDraftClub(standings[index].team);
      if (rowTeam != team) continue;
      rank = index + 1;
      break;
    }
    final nextMatch = _resolveNextKboMatch(leagueData);
    final lineup = await _buildKboAppearanceLineup(leagueData: leagueData);
    return _KboTeamPageData(rank: rank, nextMatch: nextMatch, lineup: lineup);
  }

  void _toggleMyPage() => setState(() => _isMyPageOpen = !_isMyPageOpen);

  String _kboPositionBucket(String value) {
    switch (value.trim().toUpperCase()) {
      case '1B':
      case '2B':
      case '3B':
      case 'SS':
      case 'IF':
        return 'IF';
      case 'LF':
      case 'CF':
      case 'RF':
      case 'OF':
        return 'OF';
      default:
        return value.trim().toUpperCase();
    }
  }

  List<String> _recentFormTokens(String rawForm) {
    final normalized = rawForm.toUpperCase().replaceAll(RegExp(r'[^WDL]'), '');
    if (normalized.isEmpty) return const <String>[];
    final tokens = normalized.split('');
    final recentFive = tokens.length <= 5 ? tokens : tokens.take(5).toList();
    return recentFive.reversed.toList();
  }

  Widget _buildRecentFormChip(String result) {
    final normalized = result.trim().toUpperCase();
    final (
      Color fill,
      Color stroke,
      Color fg,
      String label,
    ) = switch (normalized) {
      'W' => (
        const Color(0xFFE8FFF1),
        const Color(0xFF45C16C),
        const Color(0xFF14833B),
        'W',
      ),
      'D' => (
        const Color(0xFFFFF8E7),
        const Color(0xFFE3B341),
        const Color(0xFF9B6A00),
        'D',
      ),
      'L' => (
        const Color(0xFFFFECEC),
        const Color(0xFFE26666),
        const Color(0xFFB42318),
        'L',
      ),
      _ => (
        const Color(0xFFF2F4F7),
        const Color(0xFFD0D5DD),
        const Color(0xFF667085),
        normalized,
      ),
    };
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: stroke),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: fg),
      ),
    );
  }

  _KLeagueTeamNextMatch? _resolveNextKLeagueMatch(
    Map<String, dynamic> leagueData,
  ) {
    final rawFixtures = _fixtureAsList(leagueData['fixtures']);
    final now = DateTime.now();
    final candidates = <_KLeagueTeamNextMatch>[];
    for (final raw in rawFixtures) {
      final map = _fixtureAsMap(raw);
      final teams = _fixtureAsMap(map['teams']);
      final homeTeam = _kLeagueDisplayTeamName(
        _fixtureText(_fixtureAsMap(teams['home'])['name']),
      );
      final awayTeam = _kLeagueDisplayTeamName(
        _fixtureText(_fixtureAsMap(teams['away'])['name']),
      );
      if (homeTeam != widget.team && awayTeam != widget.team) continue;

      final fixture = _fixtureAsMap(map['fixture']);
      final kickoff = DateTime.tryParse(_fixtureText(fixture['date']));
      if (kickoff == null || _kLeagueFixtureMapHasStarted(map, now: now)) {
        continue;
      }

      final status = _fixtureAsMap(fixture['status']);
      if (_isKLeagueFinalStatus(_fixtureText(status['short']))) continue;

      final venue = _fixtureAsMap(fixture['venue']);
      candidates.add(
        _KLeagueTeamNextMatch(
          homeTeam: homeTeam,
          awayTeam: awayTeam,
          isHome: homeTeam == widget.team,
          roundLabel: _fixtureText(_fixtureAsMap(map['league'])['round']),
          kickoff: kickoff,
          venueLabel: _kLeagueVenueOrCityKoreanLabel(
            _fixtureText(venue['name']),
            _fixtureText(venue['city']),
          ),
        ),
      );
    }
    if (candidates.isEmpty) return null;
    candidates.sort((a, b) => a.kickoff.compareTo(b.kickoff));
    return candidates.first;
  }

  DateTime? _kboMatchStartAt(Map<String, dynamic> matchMap) {
    final dateUtc = '${matchMap['dateUtc'] ?? ''}'.trim();
    final timeUtc = '${matchMap['timeUtc'] ?? ''}'.trim();
    final utc = _kboUtcDateTime(dateUtc, timeUtc);
    if (utc != null) return utc.toLocal();

    final dateText = '${matchMap['date'] ?? ''}'.trim();
    final timeText = '${matchMap['time'] ?? ''}'.trim();
    if (dateText.isEmpty) return null;
    if (dateText.contains('T')) {
      final parsed = DateTime.tryParse(dateText);
      if (parsed != null) return parsed;
    }
    var normalizedTime = timeText;
    if (RegExp(r'^\d{2}:\d{2}$').hasMatch(normalizedTime)) {
      normalizedTime = '$normalizedTime:00';
    }
    if (RegExp(r'^\d{2}:\d{2}:\d{2}$').hasMatch(normalizedTime)) {
      return DateTime.tryParse('${dateText}T$normalizedTime');
    }
    return DateTime.tryParse(dateText);
  }

  String _kboFallbackDateTimeLabel(Map<String, dynamic> matchMap) {
    final startAt = _kboMatchStartAt(matchMap);
    if (startAt != null) {
      return _fixtureDateTimeLabel(startAt);
    }
    final dateLabel = _homeScheduleDateLabel('${matchMap['date'] ?? ''}');
    final timeLabel = _shortTimeLabel('${matchMap['time'] ?? ''}');
    if (dateLabel.isEmpty) return timeLabel;
    if (timeLabel.isEmpty) return dateLabel;
    return '$dateLabel $timeLabel';
  }

  _KboTeamNextMatch? _resolveNextKboMatch(Map<String, dynamic> leagueData) {
    final rawMatches = _fixtureAsList(leagueData['matches']);
    if (rawMatches.isEmpty) return null;

    final parsedById = {
      for (final match in _kboMatchesFromApi(rawMatches))
        if (match.id > 0) match.id: match,
    };
    final team = _normalizeKboDraftClub(_kboDisplayTeamName(widget.team));
    final now = DateTime.now();
    final candidates = <({DateTime startAt, _KboTeamNextMatch match})>[];

    for (final raw in rawMatches) {
      final matchMap = _fixtureAsMap(raw);
      final homeTeam = _kboDisplayTeamName('${matchMap['home'] ?? ''}');
      final awayTeam = _kboDisplayTeamName('${matchMap['away'] ?? ''}');
      final homeClub = _normalizeKboDraftClub(homeTeam);
      final awayClub = _normalizeKboDraftClub(awayTeam);
      if (homeClub != team && awayClub != team) continue;

      final statusLabel = _kboStatusLabel('${matchMap['status'] ?? ''}');
      if (statusLabel == '종료' ||
          statusLabel == '진행중' ||
          statusLabel == '취소' ||
          statusLabel == '연기') {
        continue;
      }

      final startAt = _kboMatchStartAt(matchMap);
      if (startAt == null || !startAt.isAfter(now)) continue;

      final parsed = parsedById[_readNullableInt(matchMap['id']) ?? -1];
      final dateTimeLabel =
          parsed?.dateTimeLabel ?? _kboFallbackDateTimeLabel(matchMap);
      final venueLabel =
          (parsed?.venue.trim().isNotEmpty == true
                  ? parsed!.venue
                  : _kboVenueKoreanLabel('${matchMap['venue'] ?? ''}'))
              .trim();

      candidates.add((
        startAt: startAt,
        match: _KboTeamNextMatch(
          homeTeam: homeTeam,
          awayTeam: awayTeam,
          isHome: homeClub == team,
          dateTimeLabel: dateTimeLabel,
          venueLabel: venueLabel,
        ),
      ));
    }

    if (candidates.isEmpty) return null;
    candidates.sort((a, b) => a.startAt.compareTo(b.startAt));
    return candidates.first.match;
  }

  Future<_KLeagueTeamAppearanceLineup?> _buildKLeagueAppearanceLineup(
    Map<String, dynamic> leagueData,
  ) async {
    final rawFixtures = _fixtureAsList(leagueData['fixtures']);
    final now = DateTime.now();
    final relevantFixtures = <({int fixtureId, DateTime kickoff})>[];
    for (final raw in rawFixtures) {
      final map = _fixtureAsMap(raw);
      final teams = _fixtureAsMap(map['teams']);
      final homeTeam = _kLeagueDisplayTeamName(
        _fixtureText(_fixtureAsMap(teams['home'])['name']),
      );
      final awayTeam = _kLeagueDisplayTeamName(
        _fixtureText(_fixtureAsMap(teams['away'])['name']),
      );
      if (homeTeam != widget.team && awayTeam != widget.team) continue;
      if (!_kLeagueFixtureMapHasStarted(map, now: now)) continue;
      final fixtureId = _readNullableInt(_fixtureAsMap(map['fixture'])['id']);
      final kickoff = DateTime.tryParse(
        _fixtureText(_fixtureAsMap(map['fixture'])['date']),
      );
      if (fixtureId == null || fixtureId <= 0 || kickoff == null) continue;
      relevantFixtures.add((fixtureId: fixtureId, kickoff: kickoff));
    }

    if (relevantFixtures.isEmpty) return null;
    relevantFixtures.sort((a, b) => a.kickoff.compareTo(b.kickoff));

    final formationCounts = <String, int>{};
    final playerCounts =
        <
          String,
          ({
            String name,
            int number,
            int appearances,
            int minutes,
            int goals,
            int assists,
            double gridColumnSum,
            int gridColumnCount,
            Map<String, int> positionCounts,
          })
        >{};
    const batchSize = 4;
    for (var start = 0; start < relevantFixtures.length; start += batchSize) {
      final end = min(start + batchSize, relevantFixtures.length);
      final batch = relevantFixtures.sublist(start, end);
      final details = await Future.wait(
        batch.map((fixture) async {
          try {
            return await _loadCachedKLeagueFixtureDetail(fixture.fixtureId);
          } catch (error, stackTrace) {
            debugPrint(
              'TeamPage fixture detail load failed '
              '(team=${widget.team}, fixture=${fixture.fixtureId}): $error',
            );
            debugPrint('$stackTrace');
            return null;
          }
        }),
      );

      for (final detail in details.whereType<Map<String, dynamic>>()) {
        final lineups = _fixtureAsList(detail['lineups']);
        Map<String, dynamic>? teamLineup;
        for (final rawLineup in lineups) {
          final lineup = _fixtureAsMap(rawLineup);
          final lineupTeam = _kLeagueDisplayTeamName(
            _fixtureText(_fixtureAsMap(lineup['team'])['name']),
          );
          if (lineupTeam == widget.team) {
            teamLineup = lineup;
            break;
          }
        }
        if (teamLineup == null) continue;

        final formation = _supportedFormation(
          _fixtureText(teamLineup['formation']),
        );
        formationCounts[formation.label] =
            (formationCounts[formation.label] ?? 0) + 1;

        final lineupPlayersById = <String, _LineupPlayer>{};
        final lineupPlayersByNumber = <String, _LineupPlayer>{};
        final lineupPlayersByName = <String, _LineupPlayer>{};
        for (final raw in [
          ..._fixtureAsList(teamLineup['startXI']),
          ..._fixtureAsList(teamLineup['substitutes']),
        ]) {
          final player = _lineupPlayerFromRaw(raw, lineup: teamLineup);
          if (player == null) continue;
          if (player.id.isNotEmpty) {
            lineupPlayersById[player.id] = player;
          }
          if (player.number.trim().isNotEmpty) {
            lineupPlayersByNumber[player.number.trim()] = player;
          }
          if (player.name.trim().isNotEmpty) {
            lineupPlayersByName[player.name.trim()] = player;
          }
          if (player.originalName.trim().isNotEmpty) {
            lineupPlayersByName[player.originalName.trim()] = player;
          }
        }

        Map<String, dynamic>? teamPlayerBlock;
        for (final rawTeamBlock in _fixtureAsList(detail['players'])) {
          final teamBlock = _fixtureAsMap(rawTeamBlock);
          final teamName = _kLeagueDisplayTeamName(
            _fixtureText(_fixtureAsMap(teamBlock['team'])['name']),
          );
          if (teamName == widget.team) {
            teamPlayerBlock = teamBlock;
            break;
          }
        }
        final detailFixture = _fixtureAsMap(detail['fixture']);
        final fixtureMeta = _fixtureAsMap(detailFixture['fixture']);
        final events = _fixtureAsList(detail['events']);
        final eventPlayerNames = _eventPlayerNameMap(lineups);
        final totalMinutes = _kLeagueFixtureTotalMinutes(fixtureMeta, events);

        final statByIdentity =
            <String, ({int minutes, int goals, int assists})>{};
        if (teamPlayerBlock != null) {
          for (final rawPlayerBlock in _fixtureAsList(
            teamPlayerBlock['players'],
          )) {
            final playerBlock = _fixtureAsMap(rawPlayerBlock);
            final player = _fixtureAsMap(playerBlock['player']);
            final statsList = _fixtureAsList(playerBlock['statistics']);
            final stats = statsList.isNotEmpty
                ? _fixtureAsMap(statsList.first)
                : const <String, dynamic>{};
            final games = _fixtureAsMap(stats['games']);
            final goals = _fixtureAsMap(stats['goals']);
            final numberValue =
                _readNullableInt(games['number']) ??
                _readNullableInt(player['number']) ??
                0;
            final number = numberValue > 0 ? '$numberValue' : '';
            final playerId = _fixtureText(player['id']);
            final lineupPlayer =
                (playerId.isNotEmpty ? lineupPlayersById[playerId] : null) ??
                (number.isNotEmpty ? lineupPlayersByNumber[number] : null);
            final displayName =
                lineupPlayer?.name ??
                _kLeagueDisplayPlayerName(
                  _fixtureText(player['name']),
                  teamName: widget.team,
                  number: number,
                );
            final identity = _fantasyPlayerIdentity(
              name: displayName,
              club: widget.team,
              number: numberValue,
            );
            statByIdentity[identity] = (
              minutes: _readNullableInt(games['minutes']) ?? 0,
              goals: _readNullableInt(goals['total']) ?? 0,
              assists: _readNullableInt(goals['assists']) ?? 0,
            );
          }
        }

        _LineupPlayer? lineupPlayerForEvent(Map<String, dynamic> playerLike) {
          final playerId = _fixtureText(playerLike['id']);
          if (playerId.isNotEmpty && lineupPlayersById[playerId] != null) {
            return lineupPlayersById[playerId];
          }
          final displayName = _eventPlayerDisplayName(
            playerLike,
            eventPlayerNames,
          );
          if (displayName.isNotEmpty &&
              lineupPlayersByName[displayName] != null) {
            return lineupPlayersByName[displayName];
          }
          final rawName = _fixtureText(playerLike['name']);
          return rawName.isEmpty ? null : lineupPlayersByName[rawName];
        }

        String? identityForLineupPlayer(_LineupPlayer player) {
          final numberValue = int.tryParse(player.number.trim()) ?? 0;
          return _fantasyPlayerIdentity(
            name: player.name,
            club: widget.team,
            number: numberValue,
          );
        }

        final subOutMinuteByIdentity = <String, int>{};
        final subInMinuteByIdentity = <String, int>{};
        final eventGoalsByIdentity = <String, int>{};
        final eventAssistsByIdentity = <String, int>{};

        for (final rawEvent in events) {
          final event = _fixtureAsMap(rawEvent);
          final type = _fixtureText(event['type']);
          final detailText = _fixtureText(event['detail']);
          final minute = _kLeagueEventMinuteValue(_fixtureAsMap(event['time']));
          final player = _fixtureAsMap(event['player']);
          final assist = _fixtureAsMap(event['assist']);

          if (type == 'subst' || type == 'Subst') {
            final outPlayer = lineupPlayerForEvent(player);
            final inPlayer = lineupPlayerForEvent(assist);
            final outIdentity = outPlayer == null
                ? null
                : identityForLineupPlayer(outPlayer);
            final inIdentity = inPlayer == null
                ? null
                : identityForLineupPlayer(inPlayer);
            if (outIdentity != null) {
              subOutMinuteByIdentity[outIdentity] = minute;
            }
            if (inIdentity != null) {
              subInMinuteByIdentity[inIdentity] = minute;
            }
            continue;
          }

          if (type == 'Goal') {
            final scorer = lineupPlayerForEvent(player);
            final scorerIdentity = scorer == null
                ? null
                : identityForLineupPlayer(scorer);
            if (scorerIdentity != null &&
                detailText != 'Own Goal' &&
                detailText != 'Missed Penalty') {
              eventGoalsByIdentity.update(
                scorerIdentity,
                (value) => value + 1,
                ifAbsent: () => 1,
              );
            }
            final assister = lineupPlayerForEvent(assist);
            final assistIdentity = assister == null
                ? null
                : identityForLineupPlayer(assister);
            if (assistIdentity != null) {
              eventAssistsByIdentity.update(
                assistIdentity,
                (value) => value + 1,
                ifAbsent: () => 1,
              );
            }
          }
        }

        for (final rawPlayer in _fixtureAsList(teamLineup['startXI'])) {
          final lineupPlayer = _lineupPlayerFromRaw(
            rawPlayer,
            lineup: teamLineup,
          );
          if (lineupPlayer == null) continue;
          final identity = identityForLineupPlayer(lineupPlayer);
          if (identity == null) continue;
          final stats = statByIdentity[identity];
          final minutes =
              stats?.minutes ??
              (subOutMinuteByIdentity[identity] ?? totalMinutes);
          if (minutes <= 0) continue;
          final rosterPosition = switch (lineupPlayer.position) {
            'G' => 'GK',
            'D' => 'DF',
            'M' => 'MF',
            'F' => 'FW',
            _ => '',
          };
          if (rosterPosition.isEmpty) continue;
          final existing = playerCounts[identity];
          final positionCounts = Map<String, int>.from(
            existing?.positionCounts ?? const <String, int>{},
          );
          positionCounts[rosterPosition] =
              (positionCounts[rosterPosition] ?? 0) + 1;
          final gridColumn = lineupPlayer.gridColumn;
          playerCounts[identity] = (
            name: existing?.name ?? lineupPlayer.name,
            number:
                existing?.number ?? (int.tryParse(lineupPlayer.number) ?? 0),
            appearances: (existing?.appearances ?? 0) + 1,
            minutes: (existing?.minutes ?? 0) + minutes,
            goals:
                (existing?.goals ?? 0) +
                max(stats?.goals ?? 0, eventGoalsByIdentity[identity] ?? 0),
            assists:
                (existing?.assists ?? 0) +
                max(stats?.assists ?? 0, eventAssistsByIdentity[identity] ?? 0),
            gridColumnSum:
                (existing?.gridColumnSum ?? 0) + (gridColumn?.toDouble() ?? 0),
            gridColumnCount:
                (existing?.gridColumnCount ?? 0) + (gridColumn == null ? 0 : 1),
            positionCounts: positionCounts,
          );
        }

        for (final rawPlayer in _fixtureAsList(teamLineup['substitutes'])) {
          final lineupPlayer = _lineupPlayerFromRaw(
            rawPlayer,
            lineup: teamLineup,
          );
          if (lineupPlayer == null) continue;
          final identity = identityForLineupPlayer(lineupPlayer);
          if (identity == null) continue;
          final stats = statByIdentity[identity];
          final enteredAt = subInMinuteByIdentity[identity];
          final hasAppearanceEvidence =
              (stats?.minutes ?? 0) > 0 || enteredAt != null;
          if (!hasAppearanceEvidence) continue;
          final minutes =
              stats?.minutes ??
              max(0, totalMinutes - (enteredAt ?? totalMinutes));
          if (minutes <= 0) continue;
          final rosterPosition = switch (lineupPlayer.position) {
            'G' => 'GK',
            'D' => 'DF',
            'M' => 'MF',
            'F' => 'FW',
            _ => '',
          };
          if (rosterPosition.isEmpty) continue;
          final existing = playerCounts[identity];
          final positionCounts = Map<String, int>.from(
            existing?.positionCounts ?? const <String, int>{},
          );
          positionCounts[rosterPosition] =
              (positionCounts[rosterPosition] ?? 0) + 1;
          final gridColumn = lineupPlayer.gridColumn;
          playerCounts[identity] = (
            name: existing?.name ?? lineupPlayer.name,
            number:
                existing?.number ?? (int.tryParse(lineupPlayer.number) ?? 0),
            appearances: (existing?.appearances ?? 0) + 1,
            minutes: (existing?.minutes ?? 0) + minutes,
            goals:
                (existing?.goals ?? 0) +
                max(stats?.goals ?? 0, eventGoalsByIdentity[identity] ?? 0),
            assists:
                (existing?.assists ?? 0) +
                max(stats?.assists ?? 0, eventAssistsByIdentity[identity] ?? 0),
            gridColumnSum:
                (existing?.gridColumnSum ?? 0) + (gridColumn?.toDouble() ?? 0),
            gridColumnCount:
                (existing?.gridColumnCount ?? 0) + (gridColumn == null ? 0 : 1),
            positionCounts: positionCounts,
          );
        }
      }
    }

    if (playerCounts.isEmpty) return null;

    double averageGridColumn(String identity) {
      final entry = playerCounts[identity];
      final count = entry?.gridColumnCount ?? 0;
      if (count <= 0) return 999;
      return (entry?.gridColumnSum ?? 0) / count;
    }

    String dominantPosition(Map<String, int> positionCounts) {
      final entries = positionCounts.entries.toList()
        ..sort((a, b) {
          final byCount = b.value.compareTo(a.value);
          if (byCount != 0) return byCount;
          return a.key.compareTo(b.key);
        });
      return entries.isEmpty ? '' : entries.first.key;
    }

    final appearanceSlots = playerCounts.entries
        .map((entry) {
          final appearance = entry.value;
          final position = dominantPosition(appearance.positionCounts);
          if (position.isEmpty) return null;
          return _PlayerSlot(
            name: appearance.name,
            score: appearance.appearances,
            position: position,
            club: widget.team,
            number: appearance.number,
            playerId: entry.key,
          );
        })
        .whereType<_PlayerSlot>()
        .toList();

    if (appearanceSlots.isEmpty) return null;

    int compareSlots(_PlayerSlot a, _PlayerSlot b) {
      final aMinutes = playerCounts[_playerSlotIdentity(a)]?.minutes ?? 0;
      final bMinutes = playerCounts[_playerSlotIdentity(b)]?.minutes ?? 0;
      final byMinutes = bMinutes.compareTo(aMinutes);
      if (byMinutes != 0) return byMinutes;
      final byAppearances = b.score.compareTo(a.score);
      if (byAppearances != 0) return byAppearances;
      final byNumber = a.number.compareTo(b.number);
      if (byNumber != 0) return byNumber;
      return a.name.compareTo(b.name);
    }

    List<_PlayerSlot> sortedByAppearances(String position) {
      final candidates =
          appearanceSlots.where((slot) => slot.position == position).toList()
            ..sort(compareSlots);
      return candidates;
    }

    List<_PlayerSlot> sortRowByGrid(List<_PlayerSlot> slots) {
      final ordered = List<_PlayerSlot>.from(slots)
        ..sort((a, b) {
          final byGrid = averageGridColumn(
            _playerSlotIdentity(a),
          ).compareTo(averageGridColumn(_playerSlotIdentity(b)));
          if (byGrid != 0) return byGrid;
          return compareSlots(a, b);
        });
      return ordered;
    }

    final selectedFormation =
        _supportedFormations
            .map(
              (formation) => (
                formation: formation,
                count: formationCounts[formation.label] ?? 0,
              ),
            )
            .toList()
          ..sort((a, b) {
            final byCount = b.count.compareTo(a.count);
            if (byCount != 0) return byCount;
            return _supportedFormations
                .indexOf(a.formation)
                .compareTo(_supportedFormations.indexOf(b.formation));
          });
    final formation = selectedFormation.first.formation;

    final gk = sortedByAppearances('GK');
    final df = sortedByAppearances('DF');
    final mf = sortedByAppearances('MF');
    final fw = sortedByAppearances('FW');
    final selected = <_PlayerSlot>[
      ...gk.take(1),
      ...sortRowByGrid(df.take(formation.lines[0]).toList()),
      ...sortRowByGrid(mf.take(formation.lines[1]).toList()),
      ...sortRowByGrid(fw.take(formation.lines[2]).toList()),
    ];

    final selectedIds = selected.map(_playerSlotIdentity).toSet();
    final fallback =
        appearanceSlots
            .where((slot) => !selectedIds.contains(_playerSlotIdentity(slot)))
            .toList()
          ..sort(compareSlots);
    selected.addAll(fallback.take(max(0, 11 - selected.length)));

    if (selected.length < 11) return null;
    return _KLeagueTeamAppearanceLineup(
      formation: formation,
      starting: selected.take(11).toList(),
      goalsByIdentity: {
        for (final entry in playerCounts.entries) entry.key: entry.value.goals,
      },
      assistsByIdentity: {
        for (final entry in playerCounts.entries)
          entry.key: entry.value.assists,
      },
    );
  }

  Future<_KboTeamAppearanceLineup?> _buildKboAppearanceLineup({
    Map<String, dynamic>? leagueData,
  }) async {
    await _loadKboDraftPlayerDirectory();
    final team = _normalizeKboDraftClub(widget.team);
    final sourceLeagueData = leagueData ?? await _loadCachedKboLeagueData();
    final rawMatches = _fixtureAsList(sourceLeagueData['matches']);
    final now = DateTime.now();
    final relevantMatches = <({int matchId, DateTime matchDate})>[];

    for (final raw in rawMatches) {
      final match = _fixtureAsMap(raw);
      final homeClub = _normalizeKboDraftClub('${match['home'] ?? ''}');
      final awayClub = _normalizeKboDraftClub('${match['away'] ?? ''}');
      if (homeClub != team && awayClub != team) continue;
      if (!_kboMatchMapHasStarted(match, now: now)) continue;
      final matchId = _readNullableInt(match['id']);
      final matchDate = DateTime.tryParse('${match['date'] ?? ''}');
      if (matchId == null || matchId <= 0 || matchDate == null) continue;
      relevantMatches.add((matchId: matchId, matchDate: matchDate));
    }

    if (relevantMatches.isEmpty) return null;
    relevantMatches.sort((a, b) => a.matchDate.compareTo(b.matchDate));

    final playerCounts =
        <
          String,
          ({
            String name,
            int number,
            int starts,
            int appearances,
            Map<String, int> positionCounts,
          })
        >{};

    const batchSize = 4;
    for (var start = 0; start < relevantMatches.length; start += batchSize) {
      final end = min(start + batchSize, relevantMatches.length);
      final batch = relevantMatches.sublist(start, end);
      final details = await Future.wait(
        batch.map((match) async {
          try {
            return await _loadCachedKboMatchDetail(match.matchId);
          } catch (error, stackTrace) {
            debugPrint(
              'KBO TeamPage match detail load failed '
              '(team=${widget.team}, match=${match.matchId}): $error',
            );
            debugPrint('$stackTrace');
            return null;
          }
        }),
      );

      for (final detail in details.whereType<Map<String, dynamic>>()) {
        for (final rawStat in _fixtureAsList(detail['playerStats'])) {
          final stat = _fixtureAsMap(rawStat);
          final club = _normalizeKboDraftClub('${stat['team'] ?? ''}');
          if (club != team) continue;

          final number = int.tryParse('${stat['number'] ?? ''}') ?? 0;
          final rawName = '${stat['name'] ?? ''}'.trim();
          final name = _kboDisplayPlayerName(
            rawName,
            club: team,
            number: number,
          );
          final position = _resolveKboPlayerPosition(
            '${stat['position'] ?? ''}',
            club: team,
            rawName: rawName,
            number: number,
          );
          if (name.isEmpty || position.isEmpty) continue;

          final identity = _fantasyPlayerIdentity(
            name: name,
            club: team,
            number: number,
          );
          final existing = playerCounts[identity];
          final positionCounts = Map<String, int>.from(
            existing?.positionCounts ?? const <String, int>{},
          );
          positionCounts[position] = (positionCounts[position] ?? 0) + 1;
          playerCounts[identity] = (
            name: existing?.name ?? name,
            number: existing?.number ?? number,
            starts: (existing?.starts ?? 0) + (stat['started'] == true ? 1 : 0),
            appearances: (existing?.appearances ?? 0) + 1,
            positionCounts: positionCounts,
          );
        }
      }
    }

    if (playerCounts.isEmpty) return null;

    String dominantPosition(Map<String, int> counts) {
      final entries = counts.entries.toList()
        ..sort((a, b) {
          final byCount = b.value.compareTo(a.value);
          if (byCount != 0) return byCount;
          return a.key.compareTo(b.key);
        });
      return entries.isEmpty ? '' : entries.first.key;
    }

    final roster = playerCounts.entries
        .map((entry) {
          final position = dominantPosition(entry.value.positionCounts);
          if (position.isEmpty) return null;
          return _PlayerSlot(
            name: entry.value.name,
            score: entry.value.starts,
            position: position,
            club: team,
            number: entry.value.number,
            playerId: entry.key,
          );
        })
        .whereType<_PlayerSlot>()
        .toList();

    if (roster.isEmpty) return null;

    int compareSlots(_PlayerSlot a, _PlayerSlot b) {
      final aData = playerCounts[_playerSlotIdentity(a)];
      final bData = playerCounts[_playerSlotIdentity(b)];
      final byStarts = (bData?.starts ?? 0).compareTo(aData?.starts ?? 0);
      if (byStarts != 0) return byStarts;
      final byAppearances = (bData?.appearances ?? 0).compareTo(
        aData?.appearances ?? 0,
      );
      if (byAppearances != 0) return byAppearances;
      final byNumber = a.number.compareTo(b.number);
      if (byNumber != 0) return byNumber;
      return a.name.compareTo(b.name);
    }

    List<_PlayerSlot> sortedByPosition(String position) {
      final players =
          roster
              .where((slot) => _kboPositionBucket(slot.position) == position)
              .toList()
            ..sort(compareSlots);
      return players;
    }

    final catchers = sortedByPosition('C');
    final pitchers = sortedByPosition('P');
    final infielders = sortedByPosition('IF');
    final outfielders = sortedByPosition('OF');
    final designatedHitters = sortedByPosition('DH');

    final starting = <_PlayerSlot>[
      ...catchers.take(1),
      ...pitchers.take(1),
      ...infielders.take(4),
      ...outfielders.take(3),
    ];
    final usedIds = starting.map(_playerSlotIdentity).toSet();
    final dhCandidate =
        designatedHitters.cast<_PlayerSlot?>().firstWhere(
          (slot) =>
              slot != null && !usedIds.contains(_playerSlotIdentity(slot)),
          orElse: () => null,
        ) ??
        roster.cast<_PlayerSlot?>().firstWhere(
          (slot) =>
              slot != null &&
              _isBaseballHitterPosition(slot.position) &&
              !usedIds.contains(_playerSlotIdentity(slot)),
          orElse: () => null,
        );
    if (dhCandidate != null) {
      starting.add(dhCandidate);
    }

    if (starting.length < 9) return null;
    return _KboTeamAppearanceLineup(
      starting: starting,
      startsByIdentity: {
        for (final entry in playerCounts.entries) entry.key: entry.value.starts,
      },
      appearancesByIdentity: {
        for (final entry in playerCounts.entries)
          entry.key: entry.value.appearances,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final Color text = isDark ? Colors.white : Colors.black87;
    final Color muted = isDark ? Colors.white70 : Colors.black54;
    final Color border = isDark ? Colors.white12 : Colors.black12;
    final Color surface = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    Widget sectionTitle(String t) => Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 10),
      child: Text(
        t,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w900,
          color: text,
        ),
      ),
    );

    if (widget.isSoccer) {
      return _OverlayScaffold(
        isMyPageOpen: _isMyPageOpen,
        onToggleMyPage: _toggleMyPage,
        showSearch: false,
        child: FutureBuilder<_KLeagueTeamPageData>(
          future: _soccerTeamFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return Center(
                child: _comingSoonCard(
                  '팀 정보를 불러오지 못했습니다.',
                  subtitle: '${snapshot.error}',
                ),
              );
            }

            final data = snapshot.data!;
            final nextMatch = data.nextMatch;
            final lineup = data.lineup;

            void openPlayer(_PlayerSlot slot) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PlayerProfilePage(
                    name: slot.name,
                    ownership:
                        _MatchDetailPageState._playerOwnerCache[slot.name] ??
                        PlayerOwnership.otherTeam,
                    metaOverride: _DocPlayerMeta(
                      position: slot.position,
                      club: widget.team,
                      number: slot.number,
                    ),
                  ),
                ),
              );
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFFFFFFF), Color(0xFFF4F8FF)],
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: border),
                    boxShadow: isDark
                        ? const []
                        : const [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 12,
                              offset: Offset(0, 8),
                            ),
                          ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.team,
                              maxLines: 2,
                              overflow: TextOverflow.clip,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                height: 1.05,
                                color: text,
                              ),
                            ),
                            const SizedBox(height: 14),
                            if (data.recentForm.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.fromLTRB(
                                  12,
                                  10,
                                  12,
                                  10,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.82),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: const Color(0xFFE3EAF6),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '최근 5경기 폼',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: muted,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        for (
                                          int i = 0;
                                          i < data.recentForm.length;
                                          i++
                                        ) ...[
                                          if (i != 0) const SizedBox(width: 8),
                                          _buildRecentFormChip(
                                            data.recentForm[i],
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        data.rank <= 0 ? '' : '${data.rank}위',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: muted,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  margin: const EdgeInsets.only(top: 16),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: border),
                    boxShadow: isDark
                        ? const []
                        : const [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 12,
                              offset: Offset(0, 8),
                            ),
                          ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.calendar_month, size: 16, color: muted),
                          const SizedBox(width: 8),
                          Text(
                            'Next match',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: text,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            nextMatch == null
                                ? ''
                                : _roundTitleLabel(nextMatch.roundLabel),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: muted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (nextMatch == null)
                        Text(
                          '예정된 다음 경기가 없습니다.',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: muted,
                          ),
                        )
                      else ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white10
                                : Colors.black.withValues(alpha: 0.03),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: border),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  widget.team,
                                  maxLines: 2,
                                  overflow: TextOverflow.clip,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    height: 1.05,
                                    color: text,
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      nextMatch.isHome ? 'HOME' : 'AWAY',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w900,
                                        color: muted,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'vs',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w900,
                                        color: muted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  nextMatch.opponent,
                                  textAlign: TextAlign.right,
                                  maxLines: 2,
                                  overflow: TextOverflow.clip,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    height: 1.05,
                                    color: text,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '${_fixtureDateTimeLabel(nextMatch.kickoff)} · ${nextMatch.venueLabel}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: muted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                sectionTitle('Roster'),
                if (lineup == null)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white10 : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: border),
                    ),
                    child: Text(
                      '해당 시점까지의 출전 라인업을 불러오지 못했습니다.',
                      style: TextStyle(
                        color: muted,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
                    decoration: BoxDecoration(
                      color: surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${lineup.formation.label} · 총 출전 시간 기준',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: muted,
                          ),
                        ),
                        const SizedBox(height: 14),
                        _FantasyRosterHalfPitch(
                          rows: lineup.rows,
                          rosterByName: lineup.rosterByIdentity,
                          color: Colors.blueAccent,
                          showScoreLabel: false,
                          goalCountForSlot: lineup.goalsForSlot,
                          assistCountForSlot: lineup.assistsForSlot,
                          goalkeeperRowOffset: 24,
                          onSwap: null,
                          onTap: openPlayer,
                        ),
                      ],
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
      child: FutureBuilder<_KboTeamPageData>(
        future: _kboTeamFuture,
        builder: (context, snapshot) {
          void openPlayer(_PlayerSlot slot) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PlayerProfilePage(
                  name: slot.name,
                  ownership:
                      _MatchDetailPageState._playerOwnerCache[slot.name] ??
                      PlayerOwnership.otherTeam,
                  metaOverride: _DocPlayerMeta(
                    position: slot.position,
                    club: widget.team,
                    number: slot.number,
                  ),
                ),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return Center(
              child: _comingSoonCard(
                'KBO 팀 정보를 불러오지 못했습니다.',
                subtitle: '${snapshot.error}',
              ),
            );
          }

          final data = snapshot.data!;
          final nextMatch = data.nextMatch;
          final lineup = data.lineup;

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            children: [
              Container(
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
                            blurRadius: 12,
                            offset: Offset(0, 8),
                          ),
                        ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white10 : Colors.black12,
                        shape: BoxShape.circle,
                        border: Border.all(color: border),
                      ),
                      child: Icon(
                        Icons.sports_baseball,
                        size: 26,
                        color: muted,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              widget.team,
                              maxLines: 2,
                              overflow: TextOverflow.clip,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                height: 1.05,
                                color: text,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              data.rank <= 0 ? '' : '${data.rank}위',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                color: muted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                margin: const EdgeInsets.only(top: 16),
                padding: const EdgeInsets.all(18),
                constraints: const BoxConstraints(minHeight: 168),
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: border),
                  boxShadow: isDark
                      ? const []
                      : const [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 12,
                            offset: Offset(0, 8),
                          ),
                        ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.calendar_month, size: 16, color: muted),
                        const SizedBox(width: 8),
                        Text(
                          'Next match',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: text,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (nextMatch == null)
                      Text(
                        '예정된 다음 경기가 없습니다.',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: muted,
                        ),
                      )
                    else ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white10
                              : Colors.black.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: border),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                widget.team,
                                maxLines: 2,
                                overflow: TextOverflow.clip,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  height: 1.05,
                                  color: text,
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    nextMatch.isHome ? 'HOME' : 'AWAY',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                      color: muted,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'vs',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900,
                                      color: muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Text(
                                nextMatch.opponent,
                                textAlign: TextAlign.right,
                                maxLines: 2,
                                overflow: TextOverflow.clip,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  height: 1.05,
                                  color: text,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        [
                          nextMatch.dateTimeLabel,
                          if (nextMatch.venueLabel.isNotEmpty)
                            nextMatch.venueLabel,
                        ].join(' · '),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: muted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              sectionTitle('Roster'),
              if (lineup == null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white10 : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: border),
                  ),
                  child: Text(
                    '해당 시점까지의 KBO 로스터를 불러오지 못했습니다.',
                    style: TextStyle(
                      color: muted,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
                  decoration: BoxDecoration(
                    color: surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '총 선발 경기 기준',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: muted,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _FantasyBaseballRosterDiamond(
                        starting: lineup.starting,
                        onSwap: null,
                        onTap: openPlayer,
                        scoreForSlot: lineup.startsForSlot,
                        actualScoreForSlot: lineup.startsForSlot,
                        showScoreValue: false,
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
