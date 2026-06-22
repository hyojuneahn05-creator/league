part of '../home_page.dart';

class MatchDetailPage extends StatefulWidget {
  final bool isSoccer;
  final _JoinedDraft? draft;
  final _MatchSection? initialSection;
  final int? preferredFantasyRound;
  final double? overrideHomeScore;
  final double? overrideAwayScore;

  const MatchDetailPage({
    super.key,
    required this.isSoccer,
    this.draft,
    this.initialSection,
    this.preferredFantasyRound,
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

Route<void> _matchDetailPageRoute({
  required bool isSoccer,
  _JoinedDraft? draft,
  _MatchSection? initialSection,
  int? preferredFantasyRound,
  double? overrideHomeScore,
  double? overrideAwayScore,
}) {
  return MaterialPageRoute<void>(
    builder: (_) => MatchDetailPage(
      isSoccer: isSoccer,
      draft: draft,
      initialSection: initialSection,
      preferredFantasyRound: preferredFantasyRound,
      overrideHomeScore: overrideHomeScore,
      overrideAwayScore: overrideAwayScore,
    ),
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

final Map<String, Map<int, _FantasyWeeklyLeaderSection>>
_cachedKLeagueWeeklyLeaderSnapshots =
    <String, Map<int, _FantasyWeeklyLeaderSection>>{};
final Map<int, _FantasyWeeklyLeaderSection> _cachedKboWeeklyLeaderSnapshots =
    <int, _FantasyWeeklyLeaderSection>{};
const FlutterSecureStorage _kLeagueWeeklyLeaderSnapshotStorage =
    FlutterSecureStorage(
      iOptions: IOSOptions(accountName: 'leagueit_local_state'),
    );
const FlutterSecureStorage _fantasyNotificationStorage = FlutterSecureStorage(
  iOptions: IOSOptions(accountName: 'leagueit_local_state'),
);
const String _kLeagueWeeklyLeaderSnapshotStoragePrefix =
    'kleague.weekly_top3.v1';
const String _kboWeeklyLeaderSnapshotStorageKey = 'kbo.weekly_leaders.2026.v1';
const int _kboWeeklyLeaderDisplayTotalRounds = 25;
const String _fantasyNotificationEntriesStorageKeyPrefix =
    'fantasy.notifications.v1';
const String _fantasyNotificationRosterStateStorageKeyPrefix =
    'fantasy.notifications.roster_state.v1';
const String _fantasyNotificationFptsStateStorageKeyPrefix =
    'fantasy.notifications.fpts_state.v1';
const String _fantasyProjectedScoresStorageKeyPrefix =
    'fantasy.projected_scores.v2';
const String _kboVisibleTeamScoresStorageKeyPrefix =
    'fantasy.kbo_visible_team_scores.v1';
const int _fantasyProjectedScoresStorageMaxEntries = 18;
const int _kboVisibleTeamScoresStorageMaxEntries = 18;
const Duration _fantasyNotificationRetentionWindow = Duration(days: 3);
const Duration _fantasyNotificationRealtimeWindow = Duration(minutes: 2);
bool _didHydratePersistedFantasyProjectedScoresCache = false;
Future<void>? _fantasyProjectedScoresRestoreCacheFuture;
final Map<String, _PersistedFantasyProjectedScoresEntry>
_persistedFantasyProjectedScoresEntries =
    <String, _PersistedFantasyProjectedScoresEntry>{};
bool _didHydratePersistedKboVisibleTeamScoresCache = false;
Future<void>? _kboVisibleTeamScoresRestoreCacheFuture;
final Map<String, _PersistedKboVisibleTeamScoresEntry>
_persistedKboVisibleTeamScoresEntries =
    <String, _PersistedKboVisibleTeamScoresEntry>{};
final Set<String> _freshKboVisibleTeamScoresKeys = <String>{};
final Map<
  int,
  Map<
    String,
    ({double opportunityFactor, int confirmedStarts, int completedStarts})
  >
>
_cachedKboPitcherWeeklyProjectionContextsByRound =
    <
      int,
      Map<
        String,
        ({double opportunityFactor, int confirmedStarts, int completedStarts})
      >
    >{};
final Map<
  int,
  Future<
    Map<
      String,
      ({double opportunityFactor, int confirmedStarts, int completedStarts})
    >
  >
>
_inFlightKboPitcherWeeklyProjectionContextsByRound =
    <
      int,
      Future<
        Map<
          String,
          ({double opportunityFactor, int confirmedStarts, int completedStarts})
        >
      >
    >{};

class _PersistedFantasyProjectedScoresEntry {
  final DateTime updatedAt;
  final Map<String, double> scores;

  const _PersistedFantasyProjectedScoresEntry({
    required this.updatedAt,
    required this.scores,
  });
}

class _PersistedKboVisibleTeamScoresEntry {
  final DateTime updatedAt;
  final Map<String, double> scores;

  const _PersistedKboVisibleTeamScoresEntry({
    required this.updatedAt,
    required this.scores,
  });
}

String _kLeagueWeeklyLeaderSnapshotStorageKey(String leagueId) =>
    '$_kLeagueWeeklyLeaderSnapshotStoragePrefix.$leagueId';

String _fantasyNotificationUserScopeKey() {
  final uid = FirebaseAuth.instance.currentUser?.uid.trim() ?? '';
  return uid.isEmpty ? 'anonymous' : uid;
}

String _fantasyNotificationEntriesStorageKey() =>
    '$_fantasyNotificationEntriesStorageKeyPrefix.${_fantasyNotificationUserScopeKey()}';

String _fantasyNotificationRosterStateStorageKey() =>
    '$_fantasyNotificationRosterStateStorageKeyPrefix.${_fantasyNotificationUserScopeKey()}';

String _fantasyNotificationFptsStateStorageKey() =>
    '$_fantasyNotificationFptsStateStorageKeyPrefix.${_fantasyNotificationUserScopeKey()}';

String _fantasyProjectedScoresStorageKey() =>
    '$_fantasyProjectedScoresStorageKeyPrefix.${_fantasyNotificationUserScopeKey()}';

String _kboVisibleTeamScoresStorageKey() =>
    '$_kboVisibleTeamScoresStorageKeyPrefix.${_fantasyNotificationUserScopeKey()}';

Future<void> _restorePersistedFantasyProjectedScoresCache() {
  if (_didHydratePersistedFantasyProjectedScoresCache) {
    return Future<void>.value();
  }
  final inFlight = _fantasyProjectedScoresRestoreCacheFuture;
  if (inFlight != null) return inFlight;
  final future =
      () async {
        try {
          final raw = await _readLocalStateCacheWithLegacySecureStorage(
            key: _fantasyProjectedScoresStorageKey(),
            legacyStorage: _fantasyNotificationStorage,
          );
          if (raw == null || raw.trim().isEmpty) {
            _didHydratePersistedFantasyProjectedScoresCache = true;
            return;
          }
          final decoded = jsonDecode(raw);
          if (decoded is! Map<String, dynamic>) {
            _didHydratePersistedFantasyProjectedScoresCache = true;
            return;
          }
          final entries = _fixtureAsMap(decoded['entries']);
          for (final entry in entries.entries) {
            final payload = _fixtureAsMap(entry.value);
            final updatedAt = DateTime.tryParse(
              '${payload['updatedAt'] ?? ''}',
            );
            final rawScores = _fixtureAsMap(payload['scores']);
            final scores = <String, double>{};
            for (final scoreEntry in rawScores.entries) {
              final rawValue = scoreEntry.value;
              final value = rawValue is num
                  ? rawValue.toDouble()
                  : double.tryParse('${rawValue ?? ''}');
              if (value == null) continue;
              scores[scoreEntry.key] = value;
            }
            if (updatedAt == null || scores.isEmpty) continue;
            _persistedFantasyProjectedScoresEntries[entry.key] =
                _PersistedFantasyProjectedScoresEntry(
                  updatedAt: updatedAt,
                  scores: scores,
                );
          }
          _didHydratePersistedFantasyProjectedScoresCache = true;
        } catch (error, stackTrace) {
          debugPrint(
            'restorePersistedFantasyProjectedScoresCache failed: $error',
          );
          debugPrint('$stackTrace');
        }
      }().whenComplete(() {
        _fantasyProjectedScoresRestoreCacheFuture = null;
      });
  _fantasyProjectedScoresRestoreCacheFuture = future;
  return future;
}

Future<void> _persistFantasyProjectedScoresCache() async {
  try {
    final sortedEntries =
        _persistedFantasyProjectedScoresEntries.entries.toList()
          ..sort((a, b) => b.value.updatedAt.compareTo(a.value.updatedAt));
    final payload = <String, dynamic>{
      'entries': <String, dynamic>{
        for (final entry in sortedEntries.take(
          _fantasyProjectedScoresStorageMaxEntries,
        ))
          entry.key: <String, dynamic>{
            'updatedAt': entry.value.updatedAt.toIso8601String(),
            'scores': <String, double>{
              for (final score in entry.value.scores.entries)
                score.key: score.value,
            },
          },
      },
    };
    await _writeLocalStateCache(
      _fantasyProjectedScoresStorageKey(),
      jsonEncode(payload),
    );
  } catch (error, stackTrace) {
    debugPrint('persistFantasyProjectedScoresCache failed: $error');
    debugPrint('$stackTrace');
  }
}

String _fantasyProjectedScoresCacheKeyForDraftRound(
  _JoinedDraft draft,
  int fantasyRound,
) => '${draft.leagueId}|$fantasyRound';

_PersistedFantasyProjectedScoresEntry?
_persistedFantasyProjectedScoresEntryForRound(
  _JoinedDraft draft,
  int fantasyRound,
) {
  final cacheKey = _fantasyProjectedScoresCacheKeyForDraftRound(
    draft,
    fantasyRound,
  );
  return _persistedFantasyProjectedScoresEntries[cacheKey];
}

void _storePersistedFantasyProjectedScoresEntryForRound(
  _JoinedDraft draft,
  int fantasyRound,
  Map<String, double> scores,
) {
  if (draft.isSoccer || scores.isEmpty) return;
  final cacheKey = _fantasyProjectedScoresCacheKeyForDraftRound(
    draft,
    fantasyRound,
  );
  _persistedFantasyProjectedScoresEntries[cacheKey] =
      _PersistedFantasyProjectedScoresEntry(
        updatedAt: DateTime.now(),
        scores: Map<String, double>.from(scores),
      );
}

Map<String, dynamic> _serializeKboPitcherWeeklyContextSlot(_PlayerSlot slot) {
  return <String, dynamic>{
    'identity': _playerSlotIdentity(slot),
    'name': slot.name.trim(),
    'position': slot.position.trim(),
    'club': _normalizeKboDraftClub(slot.club),
    'number': slot.number,
  };
}

Map<String, dynamic> _serializeKboPitcherWeeklyContextMatch(
  Map<String, dynamic> match,
) {
  return <String, dynamic>{
    'id': _readNullableInt(match['id']) ?? 0,
    'date': _fixtureText(match['date']),
    'home': _fixtureText(match['home']),
    'away': _fixtureText(match['away']),
    'status': _fixtureText(match['status']),
  };
}

Map<String, dynamic> _serializeKboPitcherWeeklyContextDetail(
  Map<String, dynamic> detail,
) {
  final match = _fixtureAsMap(detail['match']);
  return <String, dynamic>{
    'match': <String, dynamic>{
      'home': _fixtureText(match['home']),
      'away': _fixtureText(match['away']),
      'status': _fixtureText(match['status']),
      'date': _fixtureText(match['date']),
    },
    'lineups': [
      for (final raw in _fixtureAsList(detail['lineups']))
        <String, dynamic>{
          'team': _fixtureText(_fixtureAsMap(raw)['team']),
          'starterPitcher': _fixtureText(_fixtureAsMap(raw)['starterPitcher']),
        },
    ],
    'playerStats': [
      for (final raw in _fixtureAsList(detail['playerStats']))
        <String, dynamic>{
          'name': _fixtureText(_fixtureAsMap(raw)['name']),
          'team': _fixtureText(_fixtureAsMap(raw)['team']),
          'number': _readNullableInt(_fixtureAsMap(raw)['number']) ?? 0,
          'position': _fixtureText(_fixtureAsMap(raw)['position']),
          'started': _fixtureAsMap(raw)['started'] == true,
        },
    ],
  };
}

bool _kboPitcherStatMatchesSerializedSlot(
  Map<String, dynamic> stat,
  Map<String, dynamic> slot,
) {
  final slotClub = _normalizeKboDraftClub('${slot['club'] ?? ''}');
  final statClub = _normalizeKboDraftClub('${stat['team'] ?? ''}');
  if (slotClub.isNotEmpty && statClub.isNotEmpty && slotClub != statClub) {
    return false;
  }

  final slotNumber = _readNullableInt(slot['number']) ?? 0;
  final statNumber = _readNullableInt(stat['number']) ?? 0;
  if (slotNumber > 0 && statNumber > 0 && slotNumber != statNumber) {
    return false;
  }

  final statPosition = _fixtureText(stat['position']).trim().toUpperCase();
  if (statPosition.isNotEmpty && statPosition != 'P') {
    return false;
  }

  final slotName = _fixtureText(slot['name']);
  final statName = _fixtureText(stat['name']);
  if (slotName.isEmpty || statName.isEmpty) return false;
  if (slotName == statName) return true;
  return _kboNormalizedStarterPitcherName(slotName) ==
      _kboNormalizedStarterPitcherName(statName);
}

Map<String, dynamic> _computeKboPitcherWeeklyProjectionContextsInIsolate(
  Map<String, dynamic> request,
) {
  final targetRound = _readNullableInt(request['targetRound']) ?? 0;
  final now =
      DateTime.tryParse('${request['nowIso8601'] ?? ''}') ?? DateTime.now();
  final slots = _fixtureAsList(request['slots'])
      .map(_fixtureAsMap)
      .where(
        (slot) => _isKboPitcherPositionValue(_fixtureText(slot['position'])),
      )
      .toList(growable: false);
  final rawMatches = _fixtureAsList(
    request['rawMatches'],
  ).map(_fixtureAsMap).toList(growable: false);
  final detailByMatchIdRaw = _fixtureAsMap(request['detailsByMatchId']);
  final detailByMatchId = <int, Map<String, dynamic>>{
    for (final entry in detailByMatchIdRaw.entries)
      (_readNullableInt(entry.key) ?? 0): _fixtureAsMap(entry.value),
  };

  final byClub = <String, List<Map<String, dynamic>>>{};
  for (final match in rawMatches) {
    final matchDate = DateTime.tryParse(_fixtureText(match['date']));
    if (matchDate == null ||
        _kboFantasyRoundForMatchDate(matchDate) != targetRound) {
      continue;
    }
    final serialized = _serializeKboPitcherWeeklyContextMatch(match);
    final homeClub = _normalizeKboDraftClub(_fixtureText(serialized['home']));
    final awayClub = _normalizeKboDraftClub(_fixtureText(serialized['away']));
    if (homeClub.isNotEmpty) {
      byClub
          .putIfAbsent(homeClub, () => <Map<String, dynamic>>[])
          .add(serialized);
    }
    if (awayClub.isNotEmpty) {
      byClub
          .putIfAbsent(awayClub, () => <Map<String, dynamic>>[])
          .add(serialized);
    }
  }

  final result = <String, Map<String, dynamic>>{};
  for (final slot in slots) {
    final identity = _fixtureText(slot['identity']);
    if (identity.isEmpty || result.containsKey(identity)) continue;

    final normalizedClub = _normalizeKboDraftClub(_fixtureText(slot['club']));
    final clubMatches =
        List<Map<String, dynamic>>.from(
          byClub[normalizedClub] ?? const <Map<String, dynamic>>[],
        )..sort((a, b) {
          final aDate =
              DateTime.tryParse(_fixtureText(a['date'])) ?? DateTime(1970);
          final bDate =
              DateTime.tryParse(_fixtureText(b['date'])) ?? DateTime(1970);
          return aDate.compareTo(bDate);
        });
    if (clubMatches.isEmpty) {
      result[identity] = <String, dynamic>{
        'opportunityFactor': 1.0,
        'confirmedStarts': 0,
        'completedStarts': 0,
      };
      continue;
    }

    final scheduledDates = clubMatches
        .map((match) => DateTime.tryParse(_fixtureText(match['date'])))
        .whereType<DateTime>()
        .toList(growable: false);
    final startedDates = <DateTime>[];
    final confirmedStartMatchKeys = <String>{};
    final completedStartMatchKeys = <String>{};

    for (final match in clubMatches) {
      final matchId = _readNullableInt(match['id']);
      final matchDate = DateTime.tryParse(_fixtureText(match['date']));
      if (matchId == null || matchId <= 0 || matchDate == null) continue;
      final detail = detailByMatchId[matchId];
      if (detail == null || detail.isEmpty) continue;

      final detailMatch = _fixtureAsMap(detail['match']);
      final matchHasActuallyStarted =
          _isKboTerminalStatus(_fixtureText(detailMatch['status'])) ||
          _kboMatchMapHasStarted(detailMatch, now: now);
      final matchedStat = _fixtureAsList(detail['playerStats'])
          .map(_fixtureAsMap)
          .cast<Map<String, dynamic>?>()
          .firstWhere(
            (entry) =>
                entry != null &&
                _kboPitcherStatMatchesSerializedSlot(entry, slot),
            orElse: () => null,
          );
      final matchKey =
          '$matchId|${matchDate.toIso8601String().split('T').first}';
      if (matchedStat?['started'] == true) {
        confirmedStartMatchKeys.add(matchKey);
        if (matchHasActuallyStarted) {
          if (completedStartMatchKeys.add(matchKey)) {
            startedDates.add(matchDate);
          }
        }
      }

      final homeClub = _normalizeKboDraftClub(
        _fixtureText(detailMatch['home']),
      );
      final awayClub = _normalizeKboDraftClub(
        _fixtureText(detailMatch['away']),
      );
      final detailTeam = normalizedClub == homeClub
          ? _fixtureText(detailMatch['home'])
          : normalizedClub == awayClub
          ? _fixtureText(detailMatch['away'])
          : '';
      if (detailTeam.isEmpty) continue;
      final lineup = _kboLineupForTeam(
        _fixtureAsList(detail['lineups']),
        detailTeam,
      );
      final starterPitcher = _fixtureText(lineup['starterPitcher']);
      final slotName = _fixtureText(slot['name']);
      if (starterPitcher.isNotEmpty &&
          slotName.isNotEmpty &&
          _kboNormalizedStarterPitcherName(starterPitcher) ==
              _kboNormalizedStarterPitcherName(slotName)) {
        confirmedStartMatchKeys.add(matchKey);
      }
    }

    result[identity] = <String, dynamic>{
      'opportunityFactor': _kboPitcherWeeklyOpportunityFactor(
        startedDates: startedDates,
        scheduledDates: scheduledDates,
        confirmedWeeklyStarts: confirmedStartMatchKeys.length,
      ),
      'confirmedStarts': confirmedStartMatchKeys.length,
      'completedStarts': completedStartMatchKeys.length,
    };
  }

  return <String, dynamic>{'contexts': result};
}

Future<void> _restorePersistedKboVisibleTeamScoresCache() {
  if (_didHydratePersistedKboVisibleTeamScoresCache) {
    return Future<void>.value();
  }
  final inFlight = _kboVisibleTeamScoresRestoreCacheFuture;
  if (inFlight != null) return inFlight;
  final future =
      () async {
        try {
          final raw = await _readLocalStateCacheWithLegacySecureStorage(
            key: _kboVisibleTeamScoresStorageKey(),
            legacyStorage: _fantasyNotificationStorage,
          );
          if (raw == null || raw.trim().isEmpty) {
            _didHydratePersistedKboVisibleTeamScoresCache = true;
            return;
          }
          final decoded = jsonDecode(raw);
          if (decoded is! Map<String, dynamic>) {
            _didHydratePersistedKboVisibleTeamScoresCache = true;
            return;
          }
          final entries = _fixtureAsMap(decoded['entries']);
          for (final entry in entries.entries) {
            final payload = _fixtureAsMap(entry.value);
            final updatedAt = DateTime.tryParse(
              '${payload['updatedAt'] ?? ''}',
            );
            final rawScores = _fixtureAsMap(payload['scores']);
            final scores = <String, double>{};
            for (final scoreEntry in rawScores.entries) {
              final rawValue = scoreEntry.value;
              final value = rawValue is num
                  ? rawValue.toDouble()
                  : double.tryParse('${rawValue ?? ''}');
              if (value == null) continue;
              scores[scoreEntry.key] = value;
            }
            if (updatedAt == null || scores.isEmpty) continue;
            _persistedKboVisibleTeamScoresEntries[entry.key] =
                _PersistedKboVisibleTeamScoresEntry(
                  updatedAt: updatedAt,
                  scores: scores,
                );
          }
          _didHydratePersistedKboVisibleTeamScoresCache = true;
        } catch (error, stackTrace) {
          debugPrint(
            'restorePersistedKboVisibleTeamScoresCache failed: $error',
          );
          debugPrint('$stackTrace');
        }
      }().whenComplete(() {
        _kboVisibleTeamScoresRestoreCacheFuture = null;
      });
  _kboVisibleTeamScoresRestoreCacheFuture = future;
  return future;
}

Future<void> _persistKboVisibleTeamScoresCache() async {
  try {
    final sortedEntries = _persistedKboVisibleTeamScoresEntries.entries.toList()
      ..sort((a, b) => b.value.updatedAt.compareTo(a.value.updatedAt));
    final payload = <String, dynamic>{
      'entries': <String, dynamic>{
        for (final entry in sortedEntries.take(
          _kboVisibleTeamScoresStorageMaxEntries,
        ))
          entry.key: <String, dynamic>{
            'updatedAt': entry.value.updatedAt.toIso8601String(),
            'scores': <String, double>{
              for (final score in entry.value.scores.entries)
                score.key: score.value,
            },
          },
      },
    };
    await _writeLocalStateCache(
      _kboVisibleTeamScoresStorageKey(),
      jsonEncode(payload),
    );
  } catch (error, stackTrace) {
    debugPrint('persistKboVisibleTeamScoresCache failed: $error');
    debugPrint('$stackTrace');
  }
}

bool _hasKoreanBatchim(String value) {
  final text = value.trim();
  if (text.isEmpty) return false;
  final code = text.runes.last;
  if (code < 0xAC00 || code > 0xD7A3) return false;
  return (code - 0xAC00) % 28 != 0;
}

String _koreanParticle(
  String value, {
  required String withBatchim,
  required String withoutBatchim,
}) => _hasKoreanBatchim(value) ? withBatchim : withoutBatchim;

String _withKoreanParticle(
  String value, {
  required String withBatchim,
  required String withoutBatchim,
}) {
  final text = value.trim();
  if (text.isEmpty) return '';
  return '$text${_koreanParticle(text, withBatchim: withBatchim, withoutBatchim: withoutBatchim)}';
}

class _FantasyNotificationEntry {
  final String id;
  final String kind;
  final String leagueId;
  final String leagueName;
  final bool isSoccer;
  final String title;
  final String message;
  final DateTime createdAt;
  final bool isRead;

  const _FantasyNotificationEntry({
    required this.id,
    required this.kind,
    required this.leagueId,
    required this.leagueName,
    required this.isSoccer,
    required this.title,
    required this.message,
    required this.createdAt,
    this.isRead = false,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'kind': kind,
    'leagueId': leagueId,
    'leagueName': leagueName,
    'isSoccer': isSoccer,
    'title': title,
    'message': message,
    'createdAt': createdAt.toIso8601String(),
    'isRead': isRead,
  };

  factory _FantasyNotificationEntry.fromMap(Map<String, dynamic> map) {
    return _FantasyNotificationEntry(
      id: '${map['id'] ?? ''}',
      kind: '${map['kind'] ?? ''}',
      leagueId: '${map['leagueId'] ?? ''}',
      leagueName: '${map['leagueName'] ?? ''}',
      isSoccer: map['isSoccer'] == true,
      title: '${map['title'] ?? ''}',
      message: '${map['message'] ?? ''}',
      createdAt:
          DateTime.tryParse('${map['createdAt'] ?? ''}') ?? DateTime(1970),
      isRead: map['isRead'] == true,
    );
  }

  _FantasyNotificationEntry copyWith({
    String? id,
    String? kind,
    String? leagueId,
    String? leagueName,
    bool? isSoccer,
    String? title,
    String? message,
    DateTime? createdAt,
    bool? isRead,
  }) {
    return _FantasyNotificationEntry(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      leagueId: leagueId ?? this.leagueId,
      leagueName: leagueName ?? this.leagueName,
      isSoccer: isSoccer ?? this.isSoccer,
      title: title ?? this.title,
      message: message ?? this.message,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
    );
  }
}

({String leagueId, int round, String playerId})?
_fptsNotificationIdentityFromEntry(_FantasyNotificationEntry entry) {
  if (entry.kind != 'fpts') return null;
  final rawId = entry.id.trim();
  if (rawId.isEmpty) return null;
  final parts = rawId.split(':');
  if (parts.length < 5) return null;

  String? prefix;
  if (parts[0] == 'fpts') {
    prefix = 'fpts';
  } else if (parts[0] == 'fpts_pitcher') {
    prefix = 'fpts_pitcher';
  } else if (parts[0] == 'fpts_hr') {
    prefix = 'fpts_hr';
  }
  if (prefix == null) return null;

  final leagueId = parts[1].trim();
  final round = int.tryParse(parts[2].trim()) ?? 0;
  final playerId = parts.sublist(3, parts.length - 1).join(':').trim();
  if (leagueId.isEmpty || round <= 0 || playerId.isEmpty) return null;
  return (leagueId: leagueId, round: round, playerId: playerId);
}

String _notificationCenterPlainText(String value) {
  final buffer = StringBuffer();
  for (final rune in value.runes) {
    final isEmojiRune =
        (rune >= 0x1F000 && rune <= 0x1FAFF) ||
        (rune >= 0x2600 && rune <= 0x27BF) ||
        rune == 0xFE0F ||
        rune == 0x200D;
    if (isEmojiRune) continue;
    buffer.writeCharCode(rune);
  }
  return buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
}

List<_FantasyNotificationEntry> _trimFantasyNotificationEntries(
  Iterable<_FantasyNotificationEntry> entries, {
  DateTime? now,
  Set<String>? allowedLeagueIds,
}) {
  final current = now ?? DateTime.now();
  final cutoff = current.subtract(_fantasyNotificationRetentionWindow);
  final trimmed = entries.where((entry) {
    if (entry.createdAt.isBefore(cutoff)) return false;
    if (allowedLeagueIds == null) return true;
    return allowedLeagueIds.contains(entry.leagueId.trim());
  }).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return trimmed;
}

double _roundFantasyNotificationScore(double value) =>
    double.parse(value.toStringAsFixed(2));

DateTime? _fantasyNotificationObservedAtFromState(Map<String, dynamic>? state) {
  if (state == null) return null;
  final raw = '${state['observedAt'] ?? ''}'.trim();
  if (raw.isEmpty) return null;
  return DateTime.tryParse(raw);
}

bool _shouldEmitRealtimeFantasyNotification({
  required DateTime now,
  required Map<String, dynamic>? previousState,
}) {
  final observedAt = _fantasyNotificationObservedAtFromState(previousState);
  if (observedAt == null) return false;
  final elapsed = now.difference(observedAt);
  return !elapsed.isNegative && elapsed <= _fantasyNotificationRealtimeWindow;
}

double? _parseFantasyNotificationDetailNumber(String? raw) {
  final text = raw?.trim() ?? '';
  if (text.isEmpty) return null;
  final match = RegExp(r'-?\d+(?:\.\d+)?').firstMatch(text);
  if (match == null) return null;
  return double.tryParse(match.group(0)!);
}

double? _kboRoundPointCountFromDetails(
  _PlayerRoundPoints roundPoints,
  List<String> labels, {
  double? pointsPerUnit,
}) {
  var total = 0.0;
  var found = false;
  for (final detail in roundPoints.details) {
    if (!labels.contains(detail.label.trim())) continue;
    final parsed = _parseFantasyNotificationDetailNumber(detail.detail);
    if (parsed != null) {
      total += parsed;
      found = true;
      continue;
    }
    if (pointsPerUnit != null && pointsPerUnit.abs() > 0.001) {
      total += detail.points / pointsPerUnit;
      found = true;
    }
  }
  if (!found) return null;
  return total;
}

int _completedKboPitcherInningMilestone(_PlayerRoundPoints roundPoints) {
  final innings = _kboRoundPointCountFromDetails(roundPoints, const [
    'Inning Pitched',
    '이닝',
  ], pointsPerUnit: 2.0);
  if (innings == null || !innings.isFinite || innings < 1.0) return 0;
  return innings.floor();
}

int _kboHomeRunCount(_PlayerRoundPoints roundPoints) {
  final homeRuns = _kboRoundPointCountFromDetails(roundPoints, const [
    'Home Run',
    '홈런',
  ], pointsPerUnit: 5.0);
  if (homeRuns == null || !homeRuns.isFinite || homeRuns <= 0) return 0;
  return homeRuns.round();
}

int _kboRbiCount(_PlayerRoundPoints roundPoints) {
  final rbi = _kboRoundPointCountFromDetails(roundPoints, const [
    'RBI',
    '타점',
  ], pointsPerUnit: 1.0);
  if (rbi == null || !rbi.isFinite || rbi <= 0) return 0;
  return rbi.round();
}

int _kboHomeRunRunValue(_PlayerRoundPoints roundPoints) {
  final homeRuns = _kboHomeRunCount(roundPoints);
  if (homeRuns <= 0) return 0;
  final rbi = _kboRbiCount(roundPoints);
  if (rbi <= 0) return 1;
  return max(1, min(4, (rbi / homeRuns).round()));
}

String _buildBaseballPitcherFptsNotificationMessage({
  required String playerName,
  required double displayedScore,
}) {
  return '${_withKoreanParticle(playerName, withBatchim: '이', withoutBatchim: '가')} '
      '${displayedScore.toStringAsFixed(1)} Fpts를 기록했습니다.';
}

String _buildBaseballHomeRunNotificationMessage({
  required String playerName,
  required int runValue,
}) {
  return '${_withKoreanParticle(playerName, withBatchim: '이', withoutBatchim: '가')} '
      '$runValue점 홈런을 기록했습니다.';
}

enum _FantasyRosterLockPhase { preLock, locked, unlocked }

String _fantasyRosterLockPhaseStorageValue(_FantasyRosterLockPhase phase) {
  switch (phase) {
    case _FantasyRosterLockPhase.locked:
      return 'locked';
    case _FantasyRosterLockPhase.unlocked:
      return 'unlocked';
    case _FantasyRosterLockPhase.preLock:
      return 'pre_lock';
  }
}

_FantasyRosterLockPhase _fantasyRosterLockPhaseFromState(
  Map<String, dynamic>? map,
) {
  final raw = '${map?['phase'] ?? ''}'.trim().toLowerCase();
  switch (raw) {
    case 'locked':
      return _FantasyRosterLockPhase.locked;
    case 'unlocked':
      return _FantasyRosterLockPhase.unlocked;
    case 'pre_lock':
      return _FantasyRosterLockPhase.preLock;
    default:
      return map?['locked'] == true
          ? _FantasyRosterLockPhase.locked
          : _FantasyRosterLockPhase.preLock;
  }
}

List<Map<String, dynamic>> _playerSlotsToTradeMaps(List<_PlayerSlot> players) {
  return players
      .map(
        (player) => <String, dynamic>{
          'name': player.name,
          'position': player.position,
          'club': player.club,
          'number': player.number,
          'playerId': player.playerId,
        },
      )
      .toList();
}

String _slotClub(_PlayerSlot slot) {
  if (slot.club.trim().isNotEmpty) {
    return _canonicalKLeagueClub(slot.club.trim());
  }
  return _canonicalKLeagueClub(
    _resolvePlayerMeta(slot.name, asOf: DateTime.now()).club,
  );
}

String _slotDisplayClub(_PlayerSlot slot, {required bool isSoccer}) {
  final rawClub = slot.club.trim().isNotEmpty
      ? slot.club.trim()
      : _resolvePlayerMeta(slot.name, asOf: DateTime.now()).club;
  return _displayFantasyClubName(rawClub, isSoccer: isSoccer);
}

Color _aptsDisplayColor(double? apts) {
  if (apts == null) return const Color(0xFF3C3C4A);
  if (apts < 5.0) return const Color(0xFFE53935);
  if (apts < 10.0) return const Color(0xFFFB8C00);
  if (apts < 15.0) return const Color(0xFF2E7D32);
  return const Color(0xFF1E88E5);
}

String _slotAptsKey(_PlayerSlot slot) => _kLeagueSeasonAptsKey(
  club: _slotClub(slot),
  name: slot.name,
  preferredNumber: slot.number,
);

double? _cachedProjectedFallbackForSlot(
  _PlayerSlot slot, {
  required bool isSoccer,
}) {
  if (isSoccer) {
    final cachedApts = _cachedKLeaguePlayerApts[_slotAptsKey(slot)];
    if (cachedApts != null) return cachedApts;
    final roundPoints = _cachedKLeagueRoundPointsForPlayer(
      playerName: slot.name,
      club: _slotClub(slot),
      preferredNumber: slot.number,
    );
    if (roundPoints != null) {
      return _kLeagueAptsFromRoundPoints(roundPoints);
    }
    return null;
  }

  final fromFullSeasonCache = _cachedFullSeasonKboAptsForPlayer(
    playerName: slot.name,
    club: _normalizeKboDraftClub(slot.club),
    preferredNumber: slot.number,
    preferredPosition: slot.position,
  );
  if (fromFullSeasonCache != null) return fromFullSeasonCache;
  return null;
}

bool _hasCachedFullSeasonKboHistoryForSlot(
  _PlayerSlot slot, {
  bool allowStale = true,
}) {
  return _cachedFullSeasonKboRoundPointsForPlayer(
        playerName: slot.name,
        club: _normalizeKboDraftClub(slot.club),
        preferredNumber: slot.number,
        preferredPosition: slot.position,
        allowStale: allowStale,
      ) !=
      null;
}

bool _hasCachedKboRoundPointsForSlot(_PlayerSlot slot, int targetRound) {
  final roundPoints = _cachedKboRoundPointsForPlayer(
    playerName: slot.name,
    club: _normalizeKboDraftClub(slot.club),
    preferredNumber: slot.number,
    preferredPosition: slot.position,
  );
  if (roundPoints == null) return false;
  return roundPoints.any((entry) => entry.round == targetRound);
}

Future<void> _primeKboProjectionSourceDataForSlots(
  Iterable<_PlayerSlot> slots, {
  required int targetRound,
  required bool includeTargetRoundLivePoints,
}) async {
  final uniqueSlots = <String, _PlayerSlot>{};
  for (final slot in slots) {
    uniqueSlots[_playerSlotIdentity(slot)] = slot;
  }
  if (uniqueSlots.isEmpty) return;

  Future<void> loadBatched(
    List<_PlayerSlot> players, {
    Set<int>? targetRounds,
  }) async {
    if (players.isEmpty) return;
    const batchSize = 4;
    for (var start = 0; start < players.length; start += batchSize) {
      final end = min(start + batchSize, players.length);
      final batch = players.sublist(start, end);
      await Future.wait(
        batch.map(
          (slot) => _loadKboRoundPointsForPlayerShared(
            playerName: slot.name,
            club: _normalizeKboDraftClub(slot.club),
            preferredNumber: slot.number,
            preferredPosition: slot.position,
            targetRounds: targetRounds,
          ),
        ),
      );
    }
  }

  final historicalMissing = uniqueSlots.values
      .where((slot) => !_hasCachedFullSeasonKboHistoryForSlot(slot))
      .toList();
  await loadBatched(historicalMissing);

  if (!includeTargetRoundLivePoints) return;

  final currentRoundMissing = uniqueSlots.values
      .where((slot) => !_hasCachedKboRoundPointsForSlot(slot, targetRound))
      .toList();
  await loadBatched(currentRoundMissing, targetRounds: <int>{targetRound});
}

PlayerOwnership _ownerForSlot(_PlayerSlot slot) {
  return _MatchDetailPageState._playerOwnerCache[_playerSlotIdentity(slot)] ??
      _MatchDetailPageState._playerOwnerCache[slot.name] ??
      PlayerOwnership.freeAgent;
}

int _rosterNumberForClubNamePosition({
  required String club,
  required String name,
  required String position,
}) {
  final canonicalClub = _canonicalKLeagueClub(club);
  final normalizedPosition = _normalizeFantasySoccerPosition(position);
  for (final entry in _docRosterEntries) {
    if (entry.name != name) continue;
    if (_canonicalKLeagueClub(entry.meta.club) != canonicalClub) continue;
    if (_normalizeFantasySoccerPosition(entry.meta.position) !=
        normalizedPosition) {
      continue;
    }
    return entry.meta.number;
  }
  final transferredNumber = _kLeagueTransferredRosterNumberForClubNamePosition(
    club: club,
    name: name,
    position: position,
    asOf: DateTime.now(),
  );
  if (transferredNumber > 0) return transferredNumber;
  return 0;
}

void _setOwnerForSlot(_PlayerSlot slot, PlayerOwnership ownership) {
  _MatchDetailPageState._playerOwnerCache[_playerSlotIdentity(slot)] =
      ownership;
}

Map<String, dynamic> _weeklyLeaderEntryToJson(
  _FantasyWeeklyLeaderEntry entry,
) => {
  'name': entry.name,
  'position': entry.position,
  'club': entry.club,
  'number': entry.number,
  'points': entry.points,
};

_FantasyWeeklyLeaderEntry? _weeklyLeaderEntryFromJson(
  Map<String, dynamic> json,
) {
  final name = '${json['name'] ?? ''}'.trim();
  final position = '${json['position'] ?? ''}'.trim();
  final club = '${json['club'] ?? ''}'.trim();
  final number =
      _readNullableInt(json['number']) ??
      _rosterNumberForClubNamePosition(
        club: club,
        name: name,
        position: position,
      );
  final points = (json['points'] as num?)?.toDouble() ?? 0.0;
  if (name.isEmpty || position.isEmpty || club.isEmpty) return null;
  return _FantasyWeeklyLeaderEntry(
    name: name,
    position: position,
    club: club,
    number: number,
    points: points,
    ownership:
        _MatchDetailPageState._playerOwnerCache[name] ??
        PlayerOwnership.freeAgent,
  );
}

List<_FantasyWeeklyLeaderSection> _weeklyLeaderSectionsFromPayload(
  dynamic decoded, {
  int? maxLeadersPerSection = 3,
}) {
  if (decoded is! List) return const <_FantasyWeeklyLeaderSection>[];
  final restored = <_FantasyWeeklyLeaderSection>[];
  for (final item in decoded) {
    if (item is! Map) continue;
    final round = _readNullableInt(item['round']);
    if (round == null || round <= 0) continue;
    final rawLeaders = item['leaders'];
    if (rawLeaders is! List) continue;
    final leaders = rawLeaders
        .map(
          (entry) => entry is Map
              ? _weeklyLeaderEntryFromJson(
                  Map<String, dynamic>.from(entry.cast<Object?, Object?>()),
                )
              : null,
        )
        .whereType<_FantasyWeeklyLeaderEntry>()
        .toList();
    final trimmedLeaders = maxLeadersPerSection == null
        ? leaders
        : leaders.take(maxLeadersPerSection).toList();
    if (trimmedLeaders.isEmpty) continue;
    restored.add(
      _FantasyWeeklyLeaderSection(round: round, leaders: trimmedLeaders),
    );
  }
  restored.sort((a, b) => b.round.compareTo(a.round));
  return restored;
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
  '5-3-2': (df: 5, mf: 3, fw: 2),
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

bool _isAllowedFormationCounts({
  required int df,
  required int mf,
  required int fw,
}) => _formationKeyForCounts(df: df, mf: mf, fw: fw) != null;

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

bool _hasValidBaseballStartingLineup(List<_PlayerSlot> starting) {
  return _isValidBaseballStartingLineup<_PlayerSlot>(
    starting,
    positionOf: (player) => player.position,
  );
}

class _FantasyRosterLockState {
  final int fantasyRound;
  final int leagueRound;
  final Set<String> lockedClubs;
  final Set<String> upcomingLockClubs;
  final DateTime? locksAtUtc;
  final DateTime? unlocksAtUtc;
  final _FantasyRosterLockPhase phase;

  const _FantasyRosterLockState({
    this.fantasyRound = 0,
    this.leagueRound = 0,
    this.lockedClubs = const <String>{},
    this.upcomingLockClubs = const <String>{},
    this.locksAtUtc,
    this.unlocksAtUtc,
    this.phase = _FantasyRosterLockPhase.preLock,
  });

  static const unlocked = _FantasyRosterLockState();

  bool get hasLockedPlayers =>
      phase == _FantasyRosterLockPhase.locked && lockedClubs.isNotEmpty;

  bool isLocked(_PlayerSlot slot) {
    return lockedClubs.contains(_slotClub(slot));
  }
}

enum _FantasyRosterMembership { none, starting, bench }

const Duration _kboLockMatchDurationEstimate = Duration(hours: 4);
const Duration _kboProjectionMatchDurationEstimate = Duration(
  hours: 3,
  minutes: 30,
);
const Duration _kboDailyUnlockDelay = Duration(hours: 5);

bool _isKboTerminalStatus(String value) {
  final normalized = value.trim().toLowerCase();
  final labeled = _kboStatusLabel(value).trim();
  return normalized == 'played' ||
      normalized == 'final' ||
      normalized == 'postponed' ||
      normalized == 'cancelled' ||
      normalized == 'canceled' ||
      labeled == '종료' ||
      labeled == '연기' ||
      labeled == '취소';
}

DateTime? _kboMatchKickoffUtcFromMap(Map<String, dynamic> match) {
  final utc = _kboUtcDateTime(
    _fixtureText(match['dateUtc']),
    _fixtureText(match['timeUtc']),
  );
  if (utc != null) return utc;
  final date = _fixtureText(match['date']);
  final time = _fixtureText(match['time']);
  if (date.isEmpty || time.isEmpty) return null;
  final fallback = DateTime.tryParse('${date}T$time');
  return fallback == null ? null : _toUtcFromKst(fallback);
}

double _kboLiveMatchProgress(Map<String, dynamic> match, {DateTime? now}) {
  final current = now ?? DateTime.now();
  final status = _fixtureText(match['status']).trim();
  if (_isKboTerminalStatus(status)) return 1.0;
  if (!_kboMatchMapHasStarted(match, now: current)) return 0.0;

  final kickoffUtc = _kboMatchKickoffUtcFromMap(match);
  if (kickoffUtc == null) {
    return 0.6;
  }

  final elapsed = current.toUtc().difference(kickoffUtc);
  if (elapsed <= Duration.zero) return 0.0;
  final projected =
      elapsed.inMilliseconds /
      _kboProjectionMatchDurationEstimate.inMilliseconds;
  return projected.clamp(0.0, 0.98);
}

double _kboRoundProgressForClubFromMatches(
  List<dynamic> rawMatches, {
  required String club,
  required int leagueRound,
  DateTime? now,
}) {
  final canonicalClub = _normalizeKboDraftClub(club);
  if (canonicalClub.isEmpty || leagueRound <= 0) return 0.0;
  final current = now ?? DateTime.now();
  var totalGames = 0;
  var progressUnits = 0.0;

  for (final raw in rawMatches) {
    final match = _fixtureAsMap(raw);
    final matchDate = DateTime.tryParse('${match['date'] ?? ''}');
    if (matchDate == null ||
        _kboFantasyRoundForMatchDate(matchDate) != leagueRound) {
      continue;
    }
    final homeClub = _normalizeKboDraftClub('${match['home'] ?? ''}');
    final awayClub = _normalizeKboDraftClub('${match['away'] ?? ''}');
    if (homeClub != canonicalClub && awayClub != canonicalClub) continue;

    totalGames += 1;
    final status = '${match['status'] ?? ''}';
    if (_isKboTerminalStatus(status)) {
      progressUnits += 1.0;
      continue;
    }
    if (_kboMatchMapHasStarted(match, now: current)) {
      progressUnits += _kboLiveMatchProgress(match, now: current);
    }
  }

  if (totalGames <= 0) return 0.0;
  return (progressUnits / totalGames).clamp(0.0, 1.0);
}

double _liveAdjustedKboProjectedBaseScore({
  required double baseProjection,
  required double actualScore,
  required double roundProgress,
}) {
  final progress = roundProgress.clamp(0.0, 1.0);
  if (progress <= 0) return baseProjection;
  if (progress >= 1.0) return actualScore;

  // Keep the current live total, then add a discounted remainder estimate.
  final adjusted = actualScore + (baseProjection * (1.0 - progress) * 0.78);
  return max(actualScore, adjusted).clamp(-99.0, 99.0);
}

double _liveAdjustedKboPitcherProjectedBaseScore({
  required double baseProjection,
  required double actualScore,
  required double roundProgress,
  int confirmedWeeklyStarts = 0,
  int completedWeeklyStarts = 0,
}) {
  final genericLiveProjection = _liveAdjustedKboProjectedBaseScore(
    baseProjection: baseProjection,
    actualScore: actualScore,
    roundProgress: roundProgress,
  );
  if (confirmedWeeklyStarts <= 1 || actualScore.abs() < 0.001) {
    return genericLiveProjection;
  }

  final effectiveCompletedStarts = max(
    completedWeeklyStarts,
    actualScore.abs() >= 0.001 ? 1 : 0,
  ).clamp(0, confirmedWeeklyStarts);
  final remainingStarts = confirmedWeeklyStarts - effectiveCompletedStarts;
  if (remainingStarts <= 0) {
    return max(actualScore, genericLiveProjection).clamp(-99.0, 99.0);
  }

  final projectedPerStart = baseProjection / confirmedWeeklyStarts;
  final adjusted = actualScore + (projectedPerStart * remainingStarts);
  return max(
    max(actualScore, genericLiveProjection),
    adjusted,
  ).clamp(-99.0, 99.0);
}

double _kboPitcherWeeklyOpportunityFactor({
  required List<DateTime> startedDates,
  required List<DateTime> scheduledDates,
  int confirmedWeeklyStarts = 0,
}) {
  if (confirmedWeeklyStarts >= 2 || startedDates.length >= 2) {
    return 1.42;
  }
  if (startedDates.isEmpty) {
    return 1.0;
  }

  startedDates.sort();
  scheduledDates.sort();
  final firstStart = startedDates.first;
  final remainingGames = scheduledDates
      .where((date) => date.isAfter(firstStart))
      .toList();
  final hasWeekendWindow = remainingGames.any(
    (date) =>
        date.weekday == DateTime.saturday || date.weekday == DateTime.sunday,
  );

  switch (firstStart.weekday) {
    case DateTime.tuesday:
      return remainingGames.length >= 4 ? 1.34 : 1.28;
    case DateTime.wednesday:
      return remainingGames.length >= 3 ? 1.22 : 1.16;
    case DateTime.thursday:
      return hasWeekendWindow ? 0.95 : 0.98;
    case DateTime.friday:
      return 0.84;
    case DateTime.saturday:
      return 0.76;
    case DateTime.sunday:
      return 0.72;
    default:
      return 1.0;
  }
}

String _kboNormalizedStarterPitcherName(String value) =>
    value.replaceAll(' ', '').trim();

bool _isKboPitcherPositionValue(String value) =>
    value.trim().toUpperCase() == 'P';

bool _isKboPitcherSlot(_PlayerSlot slot) =>
    _isKboPitcherPositionValue(slot.position);

bool _kboStarterPitcherMatchesSlot(String starterPitcher, _PlayerSlot slot) {
  if (!_isKboPitcherSlot(slot)) return false;
  final starterName = starterPitcher.trim();
  final slotName = slot.name.trim();
  if (starterName.isEmpty || slotName.isEmpty) return false;
  if (starterName == slotName) return true;
  return _kboNormalizedStarterPitcherName(starterName) ==
      _kboNormalizedStarterPitcherName(slotName);
}

List<String> _kboProjectionAliasKeysForSlot(_PlayerSlot slot) {
  final keys = <String>{_playerSlotIdentity(slot)};
  final normalizedClub = _normalizeKboDraftClub(slot.club);
  final trimmedName = slot.name.trim();
  if (normalizedClub.isNotEmpty && trimmedName.isNotEmpty) {
    if (slot.number > 0) {
      keys.add('$normalizedClub|${slot.number}|$trimmedName');
    }
    keys.add('$normalizedClub|$trimmedName');
  }
  if (trimmedName.isNotEmpty) {
    keys.add(trimmedName);
  }
  return keys.toList(growable: false);
}

void _storeKboProjectionValueForSlot(
  Map<String, double> target,
  _PlayerSlot slot,
  double value,
) {
  for (final key in _kboProjectionAliasKeysForSlot(slot)) {
    target[key] = value;
  }
}

void _storeKboPitcherProjectionContextForSlot(
  Map<
    String,
    ({double opportunityFactor, int confirmedStarts, int completedStarts})
  >
  target,
  _PlayerSlot slot,
  ({double opportunityFactor, int confirmedStarts, int completedStarts}) value,
) {
  for (final key in _kboProjectionAliasKeysForSlot(slot)) {
    target[key] = value;
  }
}

Future<
  Map<
    String,
    ({double opportunityFactor, int confirmedStarts, int completedStarts})
  >
>
_loadKboPitcherWeeklyProjectionContexts(
  Iterable<_PlayerSlot> slots, {
  required List<dynamic> rawMatches,
  required int targetRound,
}) async {
  final requestedPitchers = <String, _PlayerSlot>{};
  for (final slot in slots) {
    if (!_isKboPitcherSlot(slot)) continue;
    requestedPitchers[_playerSlotIdentity(slot)] = slot;
  }
  if (requestedPitchers.isEmpty) {
    return const <
      String,
      ({double opportunityFactor, int confirmedStarts, int completedStarts})
    >{};
  }

  Map<
    String,
    ({double opportunityFactor, int confirmedStarts, int completedStarts})
  >
  subsetFromCache() {
    final cached =
        _cachedKboPitcherWeeklyProjectionContextsByRound[targetRound];
    if (cached == null || cached.isEmpty) {
      return const <
        String,
        ({double opportunityFactor, int confirmedStarts, int completedStarts})
      >{};
    }
    return {
      for (final entry in requestedPitchers.entries)
        if (cached.containsKey(entry.key)) entry.key: cached[entry.key]!,
    };
  }

  var cachedSubset = subsetFromCache();
  if (cachedSubset.length == requestedPitchers.length) {
    return cachedSubset;
  }

  final inFlight =
      _inFlightKboPitcherWeeklyProjectionContextsByRound[targetRound];
  if (inFlight != null) {
    await inFlight;
    cachedSubset = subsetFromCache();
    if (cachedSubset.length == requestedPitchers.length) {
      return cachedSubset;
    }
  }

  final future = () async {
    final existing =
        _cachedKboPitcherWeeklyProjectionContextsByRound[targetRound] ??
        const <
          String,
          ({double opportunityFactor, int confirmedStarts, int completedStarts})
        >{};
    final missingSlots = [
      for (final entry in requestedPitchers.entries)
        if (!existing.containsKey(entry.key)) entry.value,
    ];
    if (missingSlots.isEmpty) {
      return Map<
        String,
        ({double opportunityFactor, int confirmedStarts, int completedStarts})
      >.from(existing);
    }

    final targetRoundMatches =
        [for (final raw in rawMatches) _fixtureAsMap(raw)]
            .where((match) {
              final matchDate = DateTime.tryParse(_fixtureText(match['date']));
              return matchDate != null &&
                  _kboFantasyRoundForMatchDate(matchDate) == targetRound;
            })
            .toList(growable: false);

    final relevantMatches = <int, Map<String, dynamic>>{};
    final relevantClubs = missingSlots
        .map((slot) => _normalizeKboDraftClub(slot.club))
        .where((club) => club.isNotEmpty)
        .toSet();
    for (final match in targetRoundMatches) {
      final matchId = _readNullableInt(match['id']);
      if (matchId == null || matchId <= 0) continue;
      final homeClub = _normalizeKboDraftClub(_fixtureText(match['home']));
      final awayClub = _normalizeKboDraftClub(_fixtureText(match['away']));
      if (relevantClubs.contains(homeClub) ||
          relevantClubs.contains(awayClub)) {
        relevantMatches[matchId] = match;
      }
    }

    final detailsByMatchId = <String, Map<String, dynamic>>{};
    if (relevantMatches.isNotEmpty) {
      const batchSize = 4;
      final ids = relevantMatches.keys.toList()..sort();
      for (var start = 0; start < ids.length; start += batchSize) {
        final end = min(start + batchSize, ids.length);
        final batch = ids.sublist(start, end);
        final resolved = await Future.wait(
          batch.map((matchId) async {
            final match = relevantMatches[matchId]!;
            try {
              final detail = await _loadCachedKboMatchDetail(
                matchId,
                forceRefresh: !_isKboTerminalStatus(
                  _fixtureText(match['status']),
                ),
                fantasyRound: targetRound,
              );
              return MapEntry<String, Map<String, dynamic>>(
                '$matchId',
                _serializeKboPitcherWeeklyContextDetail(detail),
              );
            } catch (error, stackTrace) {
              debugPrint(
                'KBO pitcher weekly context detail load failed '
                '(round=$targetRound, match=$matchId): $error',
              );
              debugPrint('$stackTrace');
              return null;
            }
          }),
        );
        for (final entry
            in resolved.whereType<MapEntry<String, Map<String, dynamic>>>()) {
          detailsByMatchId[entry.key] = entry.value;
        }
      }
    }

    final computedRaw =
        await compute<Map<String, dynamic>, Map<String, dynamic>>(
          _computeKboPitcherWeeklyProjectionContextsInIsolate,
          <String, dynamic>{
            'targetRound': targetRound,
            'nowIso8601': DateTime.now().toIso8601String(),
            'slots': [
              for (final slot in missingSlots)
                _serializeKboPitcherWeeklyContextSlot(slot),
            ],
            'rawMatches': [
              for (final match in targetRoundMatches)
                _serializeKboPitcherWeeklyContextMatch(match),
            ],
            'detailsByMatchId': detailsByMatchId,
          },
        );

    final computedContexts =
        <
          String,
          ({double opportunityFactor, int confirmedStarts, int completedStarts})
        >{};
    final contextsRaw = _fixtureAsMap(computedRaw['contexts']);
    for (final entry in contextsRaw.entries) {
      final value = _fixtureAsMap(entry.value);
      computedContexts[entry.key] = (
        opportunityFactor:
            (value['opportunityFactor'] as num?)?.toDouble() ??
            double.tryParse('${value['opportunityFactor'] ?? ''}') ??
            1.0,
        confirmedStarts:
            (value['confirmedStarts'] as num?)?.toInt() ??
            int.tryParse('${value['confirmedStarts'] ?? ''}') ??
            0,
        completedStarts:
            (value['completedStarts'] as num?)?.toInt() ??
            int.tryParse('${value['completedStarts'] ?? ''}') ??
            0,
      );
    }

    final merged =
        Map<
            String,
            ({
              double opportunityFactor,
              int confirmedStarts,
              int completedStarts,
            })
          >.from(existing)
          ..addAll(computedContexts);
    _cachedKboPitcherWeeklyProjectionContextsByRound[targetRound] = merged;
    return merged;
  }();

  _inFlightKboPitcherWeeklyProjectionContextsByRound[targetRound] = future;
  try {
    await future;
  } finally {
    if (identical(
      _inFlightKboPitcherWeeklyProjectionContextsByRound[targetRound],
      future,
    )) {
      _inFlightKboPitcherWeeklyProjectionContextsByRound.remove(targetRound);
    }
  }

  return subsetFromCache();
}

Future<Map<String, double>> _loadKboPitcherWeeklyOpportunityFactors(
  Iterable<_PlayerSlot> slots, {
  required List<dynamic> rawMatches,
  required int targetRound,
}) async {
  final contexts = await _loadKboPitcherWeeklyProjectionContexts(
    slots,
    rawMatches: rawMatches,
    targetRound: targetRound,
  );
  return {
    for (final entry in contexts.entries)
      entry.key: entry.value.opportunityFactor,
  };
}

bool _kboFantasyRoundAllGamesTerminal(
  _JoinedDraft draft,
  int fantasyRound, {
  DateTime? now,
}) {
  if (draft.isSoccer || fantasyRound <= 0) return false;
  final rawMatches = _fixtureAsList(_cachedKboLeagueData?['matches']);
  if (rawMatches.isEmpty) return false;
  final leagueRound = _mappedKboRoundForFantasyRound(draft, fantasyRound);
  final currentTime = now ?? DateTime.now();
  var sawRoundMatch = false;
  var anyStarted = false;

  for (final raw in rawMatches) {
    final match = _fixtureAsMap(raw);
    final matchDate = DateTime.tryParse(_fixtureText(match['date']));
    if (matchDate == null ||
        _kboFantasyRoundForMatchDate(matchDate) != leagueRound) {
      continue;
    }
    sawRoundMatch = true;
    final status = _fixtureText(match['status']);
    final terminal = _isKboTerminalStatus(status);
    final started = terminal || _kboMatchMapHasStarted(match, now: currentTime);
    if (started) {
      anyStarted = true;
    }
    if (!terminal) {
      return false;
    }
  }

  return sawRoundMatch && anyStarted;
}

bool _kboFantasyTeamStartingRoundComplete(
  _JoinedDraft draft,
  _FantasyTeamState team,
  int fantasyRound, {
  DateTime? now,
}) {
  if (draft.isSoccer || fantasyRound <= 0) return false;
  final rawMatches = _fixtureAsList(_cachedKboLeagueData?['matches']);
  if (rawMatches.isEmpty) return false;

  final state = _kboRoundScoreStateForTeam(team, fantasyRound);
  final starters = state == null
      ? team.starting
      : _resolvedKboRoundStarterPlayers(team, state);
  final starterClubs = starters
      .map((player) => _normalizeKboDraftClub(player.club))
      .where((club) => club.isNotEmpty)
      .toSet();
  if (starterClubs.isEmpty) return false;

  final leagueRound = _mappedKboRoundForFantasyRound(draft, fantasyRound);
  final currentTime = now ?? DateTime.now();
  var sawRelevantMatch = false;

  for (final raw in rawMatches) {
    final match = _fixtureAsMap(raw);
    final matchDate = DateTime.tryParse(_fixtureText(match['date']));
    if (matchDate == null ||
        _kboFantasyRoundForMatchDate(matchDate) != leagueRound) {
      continue;
    }

    final homeClub = _normalizeKboDraftClub(_fixtureText(match['home']));
    final awayClub = _normalizeKboDraftClub(_fixtureText(match['away']));
    if (!starterClubs.contains(homeClub) && !starterClubs.contains(awayClub)) {
      continue;
    }

    sawRelevantMatch = true;
    final status = _fixtureText(match['status']);
    final terminal = _isKboTerminalStatus(status);
    final started = terminal || _kboMatchMapHasStarted(match, now: currentTime);
    if (!started || !terminal) {
      return false;
    }
  }

  return sawRelevantMatch;
}

List<_FantasyTeamPlayer> _fantasyProjectionRosterPlayers(
  _FantasyTeamState team,
) {
  final source = team.roster.isNotEmpty
      ? team.roster
      : [...team.starting, ...team.bench];
  final seen = <String>{};
  final roster = <_FantasyTeamPlayer>[];
  for (final player in source) {
    final identity = _fantasyTeamPlayerIdentity(player);
    if (!seen.add(identity)) continue;
    roster.add(player);
  }
  return roster;
}

bool _kboFantasyTeamRosterRoundComplete(
  _JoinedDraft draft,
  _FantasyTeamState team,
  int fantasyRound, {
  DateTime? now,
}) {
  if (draft.isSoccer || fantasyRound <= 0) return false;
  final rawMatches = _fixtureAsList(_cachedKboLeagueData?['matches']);
  if (rawMatches.isEmpty) return false;

  final rosterPlayers = _fantasyProjectionRosterPlayers(team);
  final rosterClubs = rosterPlayers
      .map((player) => _normalizeKboDraftClub(player.club))
      .where((club) => club.isNotEmpty)
      .toSet();
  if (rosterClubs.isEmpty) return false;

  final leagueRound = _mappedKboRoundForFantasyRound(draft, fantasyRound);
  final currentTime = now ?? DateTime.now();
  var sawRelevantMatch = false;

  for (final raw in rawMatches) {
    final match = _fixtureAsMap(raw);
    final matchDate = DateTime.tryParse(_fixtureText(match['date']));
    if (matchDate == null ||
        _kboFantasyRoundForMatchDate(matchDate) != leagueRound) {
      continue;
    }

    final homeClub = _normalizeKboDraftClub(_fixtureText(match['home']));
    final awayClub = _normalizeKboDraftClub(_fixtureText(match['away']));
    if (!rosterClubs.contains(homeClub) && !rosterClubs.contains(awayClub)) {
      continue;
    }

    sawRelevantMatch = true;
    final status = _fixtureText(match['status']);
    final terminal = _isKboTerminalStatus(status);
    final started = terminal || _kboMatchMapHasStarted(match, now: currentTime);
    if (!started || !terminal) {
      return false;
    }
  }

  return sawRelevantMatch;
}

double? _forcedKboLeadingWinRatio({
  required _JoinedDraft draft,
  required int fantasyRound,
  required _FantasyTeamState myTeam,
  required _FantasyTeamState opponentTeam,
  required double myActual,
  required double opponentActual,
  DateTime? now,
}) {
  if (draft.isSoccer || myActual <= opponentActual + 0.0001) {
    return null;
  }
  final currentTime = now ?? DateTime.now();
  if (!_kboFantasyTeamStartingRoundComplete(
    draft,
    opponentTeam,
    fantasyRound,
    now: currentTime,
  )) {
    return null;
  }
  if (_kboFantasyTeamStartingRoundComplete(
    draft,
    myTeam,
    fantasyRound,
    now: currentTime,
  )) {
    return 1.0;
  }

  final downsideRisk = _kboFantasyTeamRemainingDownsideRisk(
    draft,
    myTeam,
    fantasyRound,
    now: currentTime,
  );
  if (downsideRisk <= 0.5) {
    return 0.99;
  }

  final lead = myActual - opponentActual;
  final coverage = lead / downsideRisk;
  if (coverage >= 8.0) return 0.99;
  if (coverage >= 6.0) return 0.985;
  if (coverage >= 4.5) return 0.98;
  if (coverage >= 3.5) return 0.97;
  if (coverage >= 2.5) return 0.95;
  if (coverage >= 1.8) return 0.92;
  return null;
}

bool _isCaptainForFantasyTeamPlayer(
  _FantasyTeamState team,
  _FantasyTeamPlayer player,
) {
  final playerIdentity = _fantasyTeamPlayerIdentity(player);
  if (team.captainPlayerId?.trim().isNotEmpty == true) {
    return team.captainPlayerId == playerIdentity;
  }
  return team.captainName == player.name;
}

double _kboDisplayedScoreForFantasyTeamPlayer(
  _FantasyTeamState team,
  _FantasyTeamPlayer player,
  _PlayerRoundPoints? entry,
) {
  final displayed = entry?.displayedPoints ?? 0.0;
  return _isCaptainForFantasyTeamPlayer(team, player)
      ? displayed * 2
      : displayed;
}

double _kboSeasonAptsForFantasyTeamPlayer(_FantasyTeamPlayer player) {
  return _cachedFullSeasonKboAptsForPlayer(
        playerName: player.name,
        club: _normalizeKboDraftClub(player.club),
        preferredNumber: player.number,
        preferredPosition: player.position,
      ) ??
      0.0;
}

double _kboFantasyTeamRemainingDownsideRisk(
  _JoinedDraft draft,
  _FantasyTeamState team,
  int fantasyRound, {
  DateTime? now,
}) {
  if (draft.isSoccer || fantasyRound <= 0) return 0.0;
  final rawMatches = _fixtureAsList(_cachedKboLeagueData?['matches']);
  if (rawMatches.isEmpty) return 0.0;

  final state = _kboRoundScoreStateForTeam(team, fantasyRound);
  final starters = state == null
      ? team.starting
      : _resolvedKboRoundStarterPlayers(team, state);
  if (starters.isEmpty) return 0.0;

  final currentTime = now ?? DateTime.now();
  final leagueRound = _mappedKboRoundForFantasyRound(draft, fantasyRound);
  final clubProgressCache = <String, double>{};

  double progressForClub(String club) {
    final normalizedClub = _normalizeKboDraftClub(club);
    if (normalizedClub.isEmpty) return 1.0;
    return clubProgressCache.putIfAbsent(
      normalizedClub,
      () => _kboRoundProgressForClubFromMatches(
        rawMatches,
        club: normalizedClub,
        leagueRound: leagueRound,
        now: currentTime,
      ),
    );
  }

  double totalRisk = 0.0;
  for (final player in starters) {
    final clubProgress = progressForClub(player.club);
    final remainingProgress = (1.0 - clubProgress).clamp(0.0, 1.0);
    if (remainingProgress <= 0.001) continue;

    final roundPoints = _cachedKboRoundPointsForPlayer(
      playerName: player.name,
      club: _normalizeKboDraftClub(player.club),
      preferredNumber: player.number,
      preferredPosition: player.position,
    );
    final absoluteRound = _mappedKboRoundForFantasyRound(draft, fantasyRound);
    final roundEntry = roundPoints?.cast<_PlayerRoundPoints?>().firstWhere(
      (entry) => entry?.round == absoluteRound,
      orElse: () => null,
    );
    final seasonApts = _kboSeasonAptsForFantasyTeamPlayer(player);
    final displayedActual = _kboDisplayedScoreForFantasyTeamPlayer(
      team,
      player,
      roundEntry,
    );
    final hasAppearance =
        roundEntry != null &&
        (roundEntry.appeared ||
            roundEntry.started ||
            roundEntry.details.isNotEmpty ||
            roundEntry.basePoints != 0.0);

    if (_isKboPitcherPositionValue(player.position)) {
      final baseRisk = hasAppearance
          ? max(
              3.0,
              min(12.0, displayedActual.abs() * 0.30 + seasonApts * 0.18),
            )
          : max(7.0, min(16.0, max(seasonApts * 0.60, 8.0)));
      final progressWeight = hasAppearance
          ? max(0.20, remainingProgress)
          : max(0.45, remainingProgress);
      totalRisk += baseRisk * progressWeight;
      continue;
    }

    final hitterRisk = max(
      1.0,
      min(3.5, max(seasonApts * 0.15, displayedActual.abs() * 0.08)),
    );
    totalRisk += hitterRisk * max(0.20, remainingProgress);
  }

  return totalRisk.clamp(0.0, 99.0);
}

bool _fantasyRoundIsFinalized(
  _JoinedDraft draft,
  int fantasyRound, {
  DateTime? now,
}) {
  final currentTime = now ?? DateTime.now();
  final currentRound = _currentFantasyRoundAt(draft, currentTime);
  if (fantasyRound < currentRound) {
    return true;
  }
  if (draft.isSoccer) {
    final snapshot = _fantasySoccerRoundScoreSnapshotFor(draft, fantasyRound);
    return snapshot?.finalized == true;
  }
  return _kboFantasyRoundAllGamesTerminal(
        draft,
        fantasyRound,
        now: currentTime,
      ) ||
      _shouldFreezeUnlockedKboRoundScore(draft, fantasyRound, now: currentTime);
}

DateTime? _kboMatchKickoffUtc(_KboMatch match) {
  final utc = _kboUtcDateTime(match.dateUtc, match.timeUtc);
  if (utc != null) return utc;
  if (match.date.isEmpty || match.time.isEmpty) return null;
  final fallback = DateTime.tryParse('${match.date}T${match.time}');
  return fallback == null ? null : _toUtcFromKst(fallback);
}

_FantasyRosterLockState _fantasyRosterLockStateForDraft(
  _JoinedDraft draft, {
  DateTime? now,
}) {
  final currentTime = now ?? DateTime.now();
  final fantasyRound = _currentFantasyRoundAt(draft, currentTime);
  if (draft.isSoccer) {
    final cachedLeagueData = _cachedKLeagueLeagueData;
    final rawFixtures = _fixtureAsList(cachedLeagueData?['fixtures']);
    if (rawFixtures.isEmpty) return _FantasyRosterLockState.unlocked;

    final windows = _kLeagueRoundWindowsFromFixtures(rawFixtures);
    if (windows.isEmpty) return _FantasyRosterLockState.unlocked;

    final leagueRound = _mappedKLeagueRoundForFantasyRound(
      draft,
      fantasyRound,
      rawFixtures,
    );
    final window = windows.cast<_KLeagueRoundWindow?>().firstWhere(
      (item) => item?.round == leagueRound,
      orElse: () => null,
    );
    if (window == null) {
      return _FantasyRosterLockState(
        fantasyRound: fantasyRound,
        leagueRound: leagueRound,
      );
    }

    final unlocksAtUtc = _kLeagueRoundAdvanceUtc(window);
    if (!currentTime.toUtc().isBefore(unlocksAtUtc)) {
      return _FantasyRosterLockState(
        fantasyRound: fantasyRound,
        leagueRound: leagueRound,
        locksAtUtc: window.startUtc,
        unlocksAtUtc: unlocksAtUtc,
        phase: _FantasyRosterLockPhase.unlocked,
      );
    }

    if (currentTime.toUtc().isBefore(window.startUtc)) {
      return _FantasyRosterLockState(
        fantasyRound: fantasyRound,
        leagueRound: leagueRound,
        locksAtUtc: window.startUtc,
        unlocksAtUtc: unlocksAtUtc,
        phase: _FantasyRosterLockPhase.preLock,
      );
    }

    final lockedClubs = <String>{};
    for (final raw in rawFixtures) {
      final map = _fixtureAsMap(raw);
      final league = _fixtureAsMap(map['league']);
      if (_roundNumber(_fixtureText(league['round'])) != leagueRound) continue;
      if (!_kLeagueFixtureMapHasStarted(map, now: currentTime)) continue;

      final teams = _fixtureAsMap(map['teams']);
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
      if (homeClub.isNotEmpty) lockedClubs.add(homeClub);
      if (awayClub.isNotEmpty) lockedClubs.add(awayClub);
    }

    return _FantasyRosterLockState(
      fantasyRound: fantasyRound,
      leagueRound: leagueRound,
      lockedClubs: lockedClubs,
      locksAtUtc: window.startUtc,
      unlocksAtUtc: unlocksAtUtc,
      phase: _FantasyRosterLockPhase.locked,
    );
  }

  final cachedLeagueData = _cachedKboLeagueData;
  final rawMatches = _fixtureAsList(cachedLeagueData?['matches']);
  final leagueRound = _mappedKboRoundForFantasyRound(draft, fantasyRound);
  if (rawMatches.isEmpty || fantasyRound <= 0) {
    return _FantasyRosterLockState(
      fantasyRound: fantasyRound,
      leagueRound: leagueRound,
    );
  }
  if (!_kboFantasyRoundHasStarted(draft, fantasyRound, currentTime)) {
    return _FantasyRosterLockState(
      fantasyRound: fantasyRound,
      leagueRound: leagueRound,
    );
  }

  final todayKey =
      '${_kstDayOnly(currentTime).year}-${_twoDigits(_kstDayOnly(currentTime).month)}-${_twoDigits(_kstDayOnly(currentTime).day)}';
  final roundMatches = _kboMatchesFromApi(rawMatches).where((match) {
    final matchDate = DateTime.tryParse(match.date);
    if (matchDate == null) return false;
    return _kboFantasyRoundForMatchDate(matchDate) == leagueRound &&
        match.date == todayKey;
  }).toList();
  if (roundMatches.isEmpty) {
    return _FantasyRosterLockState(
      fantasyRound: fantasyRound,
      leagueRound: leagueRound,
    );
  }

  DateTime? unlocksAtUtc;
  DateTime? latestEstimatedEndUtc;
  DateTime? earliestUpcomingKickoffUtc;
  var allTerminal = true;
  var anyStarted = false;
  final lockedClubs = <String>{};
  final upcomingLockClubs = <String>{};
  for (final match in roundMatches) {
    final kickoffUtc = _kboMatchKickoffUtc(match);
    if (kickoffUtc != null) {
      final estimatedEndUtc = kickoffUtc.add(_kboLockMatchDurationEstimate);
      if (latestEstimatedEndUtc == null ||
          estimatedEndUtc.isAfter(latestEstimatedEndUtc)) {
        latestEstimatedEndUtc = estimatedEndUtc;
      }
    }
    final started = kickoffUtc != null
        ? !currentTime.toUtc().isBefore(kickoffUtc)
        : (_isKboLiveStatus(match.status) ||
              _isKboTerminalStatus(match.status));
    if (!started) {
      if (kickoffUtc != null) {
        final homeClub = _normalizeKboDraftClub(match.home);
        final awayClub = _normalizeKboDraftClub(match.away);
        if (earliestUpcomingKickoffUtc == null ||
            kickoffUtc.isBefore(earliestUpcomingKickoffUtc)) {
          earliestUpcomingKickoffUtc = kickoffUtc;
          upcomingLockClubs
            ..clear()
            ..addAll([
              if (homeClub.isNotEmpty) homeClub,
              if (awayClub.isNotEmpty) awayClub,
            ]);
        } else if (kickoffUtc.isAtSameMomentAs(earliestUpcomingKickoffUtc)) {
          if (homeClub.isNotEmpty) upcomingLockClubs.add(homeClub);
          if (awayClub.isNotEmpty) upcomingLockClubs.add(awayClub);
        }
      }
      allTerminal = false;
      continue;
    }
    anyStarted = true;
    final terminal = _isKboTerminalStatus(match.status);
    allTerminal = allTerminal && terminal;
    lockedClubs.add(_normalizeKboDraftClub(match.home));
    lockedClubs.add(_normalizeKboDraftClub(match.away));
  }

  if (latestEstimatedEndUtc != null) {
    unlocksAtUtc = latestEstimatedEndUtc.add(_kboDailyUnlockDelay);
  }
  if (!anyStarted) {
    return _FantasyRosterLockState(
      fantasyRound: fantasyRound,
      leagueRound: leagueRound,
      locksAtUtc: roundMatches
          .map(_kboMatchKickoffUtc)
          .whereType<DateTime>()
          .fold<DateTime?>(
            null,
            (previous, kickoff) =>
                previous == null || kickoff.isBefore(previous)
                ? kickoff
                : previous,
          ),
      upcomingLockClubs: upcomingLockClubs,
      unlocksAtUtc: unlocksAtUtc,
      phase: _FantasyRosterLockPhase.preLock,
    );
  }
  if (allTerminal &&
      unlocksAtUtc != null &&
      !currentTime.toUtc().isBefore(unlocksAtUtc)) {
    return _FantasyRosterLockState(
      fantasyRound: fantasyRound,
      leagueRound: leagueRound,
      locksAtUtc: roundMatches
          .map(_kboMatchKickoffUtc)
          .whereType<DateTime>()
          .fold<DateTime?>(
            null,
            (previous, kickoff) =>
                previous == null || kickoff.isBefore(previous)
                ? kickoff
                : previous,
          ),
      unlocksAtUtc: unlocksAtUtc,
      phase: _FantasyRosterLockPhase.unlocked,
    );
  }
  return _FantasyRosterLockState(
    fantasyRound: fantasyRound,
    leagueRound: leagueRound,
    lockedClubs: lockedClubs,
    locksAtUtc: roundMatches
        .map(_kboMatchKickoffUtc)
        .whereType<DateTime>()
        .fold<DateTime?>(
          null,
          (previous, kickoff) => previous == null || kickoff.isBefore(previous)
              ? kickoff
              : previous,
        ),
    unlocksAtUtc: unlocksAtUtc,
    phase: _FantasyRosterLockPhase.locked,
  );
}

List<_Player> _rowsFromSoccerStartingSlots(List<_PlayerSlot> starting) {
  final gk = starting.where((p) => p.position == 'GK').toList();
  final df = starting.where((p) => p.position == 'DF').toList();
  final mf = starting.where((p) => p.position == 'MF').toList();
  final fw = starting.where((p) => p.position == 'FW').toList();
  return [
    if (gk.isNotEmpty) _Player(slots: [gk.first]),
    if (df.isNotEmpty) _Player(slots: df),
    if (mf.isNotEmpty) _Player(slots: mf),
    if (fw.isNotEmpty) _Player(slots: fw),
  ];
}

List<_PlayerSlot> _buildPlayerPool(Random random, {DateTime? asOf}) {
  // Use ONLY the updated roster-document players for MatchDetailPage.
  final effectiveDate = asOf ?? DateTime.now();
  final result = <_PlayerSlot>[];
  final seen = <String>{};
  for (final entry in _docRosterEntries) {
    final resolvedMeta = _applyKLeagueTransferOverride(entry.name, (
      position: entry.meta.position,
      club: entry.meta.club,
      number: entry.meta.number,
    ), asOf: effectiveDate);
    final dedupeKey = _fantasyPlayerIdentity(
      name: entry.name,
      club: resolvedMeta.club,
      number: resolvedMeta.number,
    );
    if (!seen.add(dedupeKey)) continue;
    final seed = _stableSeedFromKey(
      'pts|${entry.name}|${resolvedMeta.club}|${resolvedMeta.number}',
    );
    result.add(
      _PlayerSlot(
        name: entry.name,
        score: 5 + (seed % 6), // 5~10점 (deterministic)
        position: resolvedMeta.position,
        club: resolvedMeta.club,
        number: resolvedMeta.number,
        playerId: dedupeKey,
      ),
    );
  }
  result.shuffle(random);
  return result;
}

final Map<String, ({String position, String club, int number})>
_apiPlayerMetaByName = <String, ({String position, String club, int number})>{};
List<_PlayerSlot>? _cachedApiSoccerPlayers;
Future<List<_PlayerSlot>>? _cachedApiSoccerPlayersFuture;

String _normalizeApiPlayerPosition(String raw) {
  switch (raw.trim().toLowerCase()) {
    case 'goalkeeper':
      return 'GK';
    case 'defender':
      return 'DF';
    case 'midfielder':
      return 'MF';
    case 'forward':
      return 'FW';
    default:
      return raw.trim().toUpperCase();
  }
}

Future<List<_PlayerSlot>> _loadApiSoccerPlayers() {
  final cached = _cachedApiSoccerPlayers;
  if (cached != null) return Future.value(cached);
  final inFlight = _cachedApiSoccerPlayersFuture;
  if (inFlight != null) return inFlight;
  final future = () async {
    final effectiveDate = DateTime.now();
    final raw = await rootBundle.loadString('docs/api_players_season_2026.txt');
    final seen = <String>{};
    final players = <_PlayerSlot>[];
    for (final line in raw.split(RegExp(r'\r?\n'))) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      final parts = trimmed.split('|').map((part) => part.trim()).toList();
      if (parts.length < 5) continue;
      final koreanName = parts[1];
      if (koreanName.isEmpty) continue;
      final rawClub = _kLeagueDisplayTeamName(parts[2]);
      final rawPosition = _normalizeApiPlayerPosition(parts[3]);
      final rawNumber =
          int.tryParse(parts[4]) ?? _fallbackJerseyNumberForName(koreanName);
      final rawMeta = (position: rawPosition, club: rawClub, number: rawNumber);
      final resolvedMeta = _applyKLeagueTransferOverride(
        koreanName,
        rawMeta,
        asOf: effectiveDate,
      );
      final playerId = _fantasyPlayerIdentity(
        name: koreanName,
        club: resolvedMeta.club,
        number: resolvedMeta.number,
      );
      if (!seen.add(playerId)) continue;
      final seed = _stableSeedFromKey(
        'api|$koreanName|${resolvedMeta.club}|${resolvedMeta.number}',
      );
      _apiPlayerMetaByName.putIfAbsent(koreanName, () {
        return rawMeta;
      });
      players.add(
        _PlayerSlot(
          name: koreanName,
          score: 5 + (seed % 6),
          position: resolvedMeta.position,
          club: resolvedMeta.club,
          number: resolvedMeta.number,
          playerId: playerId,
        ),
      );
    }
    _cachedApiSoccerPlayers = players;
    _cachedApiSoccerPlayersFuture = null;
    return players;
  }();
  _cachedApiSoccerPlayersFuture = future;
  return future;
}

class _MatchDetailPageState extends State<MatchDetailPage>
    with WidgetsBindingObserver {
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
  List<String> _savedStartingNames = const [];
  List<String> _savedBenchNames = const [];
  Map<String, _PlayerSlot> _savedRosterById = const <String, _PlayerSlot>{};
  String? _captainName;
  String? _viceCaptainName;
  String? _captainPlayerId;
  String? _viceCaptainPlayerId;
  String? _savedCaptainName;
  String? _savedViceCaptainName;
  String? _savedCaptainPlayerId;
  String? _savedViceCaptainPlayerId;
  bool _rosterDirty = false;
  bool _isSavingRoster = false;
  bool _allowImmediateRoutePop = false;
  final Set<String> _activeRosterDragIds = <String>{};
  static const int _initialPlayersVisibleCount = 24;
  static const int _playersVisiblePageSize = 24;
  final ScrollController _scrollController = ScrollController();
  Timer? _lockRefreshTimer;
  List<_FantasyNotificationEntry> _notificationEntries =
      const <_FantasyNotificationEntry>[];
  int _notificationUnreadCount = 0;
  bool _isNotificationCenterOpen = false;
  Future<void>? _syncFantasyNotificationsFuture;
  bool _syncFantasyNotificationsQueued = false;
  bool _syncFantasyNotificationsQueuedMarkRead = false;
  StreamSubscription<PushNotificationCenterEvent>?
  _notificationCenterEntriesSubscription;

  int get _myRosterCount => _starting.length + _bench.length;

  List<String> get _currentStartingIds =>
      _starting.map(_playerSlotIdentity).toList();
  List<String> get _currentBenchIds => _bench.map(_playerSlotIdentity).toList();
  bool get _hasActiveRosterDrag => _activeRosterDragIds.isNotEmpty;
  bool get _shouldPreserveLocalRosterState =>
      _rosterDirty || _isSavingRoster || _hasActiveRosterDrag;

  bool _listEqualsByValue(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  bool _computeRosterDirty() {
    return !_listEqualsByValue(_savedStartingNames, _currentStartingIds) ||
        !_listEqualsByValue(_savedBenchNames, _currentBenchIds) ||
        _savedCaptainName != _captainName ||
        _savedViceCaptainName != _viceCaptainName ||
        _savedCaptainPlayerId != _captainPlayerId ||
        _savedViceCaptainPlayerId != _viceCaptainPlayerId;
  }

  void _captureSavedRosterState() {
    _savedStartingNames = _currentStartingIds;
    _savedBenchNames = _currentBenchIds;
    _savedRosterById = {
      for (final player in [..._starting, ..._bench])
        _playerSlotIdentity(player): player,
    };
    _savedCaptainName = _captainName;
    _savedViceCaptainName = _viceCaptainName;
    _savedCaptainPlayerId = _captainPlayerId;
    _savedViceCaptainPlayerId = _viceCaptainPlayerId;
    _rosterDirty = false;
  }

  ({
    List<_PlayerSlot> starting,
    List<_PlayerSlot> bench,
    String? captainName,
    String? viceCaptainName,
    String? captainPlayerId,
    String? viceCaptainPlayerId,
    Map<String, PlayerOwnership> ownerCache,
  })
  _captureRosterMutationSnapshot() {
    return (
      starting: List<_PlayerSlot>.from(_starting),
      bench: List<_PlayerSlot>.from(_bench),
      captainName: _captainName,
      viceCaptainName: _viceCaptainName,
      captainPlayerId: _captainPlayerId,
      viceCaptainPlayerId: _viceCaptainPlayerId,
      ownerCache: Map<String, PlayerOwnership>.from(_playerOwnerCache),
    );
  }

  void _restoreRosterMutationSnapshot(
    ({
      List<_PlayerSlot> starting,
      List<_PlayerSlot> bench,
      String? captainName,
      String? viceCaptainName,
      String? captainPlayerId,
      String? viceCaptainPlayerId,
      Map<String, PlayerOwnership> ownerCache,
    })
    snapshot,
  ) {
    void applySnapshot() {
      _starting = List<_PlayerSlot>.from(snapshot.starting);
      _bench = List<_PlayerSlot>.from(snapshot.bench);
      _captainName = snapshot.captainName;
      _viceCaptainName = snapshot.viceCaptainName;
      _captainPlayerId = snapshot.captainPlayerId;
      _viceCaptainPlayerId = snapshot.viceCaptainPlayerId;
      _playerOwnerCache
        ..clear()
        ..addAll(snapshot.ownerCache);
      _rosterDirty = _computeRosterDirty();
      _persistMyRosterToCache();
      _applyStartingToLineup();
    }

    if (mounted) {
      setState(applySnapshot);
    } else {
      applySnapshot();
    }
  }

  void _handleRosterDragStarted(_PlayerSlot slot) {
    _activeRosterDragIds.add(_playerSlotIdentity(slot));
  }

  void _handleRosterDragFinished(_PlayerSlot slot) {
    _activeRosterDragIds.remove(_playerSlotIdentity(slot));
  }

  _FantasyRosterLockState get _rosterLockState {
    final draft = _fantasyDraft;
    if (draft == null) {
      return _FantasyRosterLockState.unlocked;
    }
    final now = DateTime.now();
    final bucket =
        now.toUtc().millisecondsSinceEpoch ~/
        _rosterLockStateCacheWindow.inMilliseconds;
    final leagueDataStamp = draft.isSoccer
        ? (_cachedKLeagueLeagueDataUpdatedAt?.millisecondsSinceEpoch ?? 0)
        : (_cachedKboLeagueDataUpdatedAt?.millisecondsSinceEpoch ?? 0);
    final cacheKey =
        '${draft.leagueId}|${draft.isSoccer ? 'soccer' : 'kbo'}|$bucket|$leagueDataStamp';
    if (_cachedRosterLockStateValue != null &&
        _cachedRosterLockStateKey == cacheKey) {
      return _cachedRosterLockStateValue!;
    }
    final value = _fantasyRosterLockStateForDraft(draft, now: now);
    _cachedRosterLockStateKey = cacheKey;
    _cachedRosterLockStateValue = value;
    return value;
  }

  bool _isRosterSlotLocked(_PlayerSlot slot) => _rosterLockState.isLocked(slot);

  _FantasyRosterMembership _savedMembershipForPlayerId(String playerId) {
    if (_savedStartingNames.contains(playerId)) {
      return _FantasyRosterMembership.starting;
    }
    if (_savedBenchNames.contains(playerId)) {
      return _FantasyRosterMembership.bench;
    }
    return _FantasyRosterMembership.none;
  }

  _FantasyRosterMembership _currentMembershipForPlayerId(String playerId) {
    if (_currentStartingIds.contains(playerId)) {
      return _FantasyRosterMembership.starting;
    }
    if (_currentBenchIds.contains(playerId)) {
      return _FantasyRosterMembership.bench;
    }
    return _FantasyRosterMembership.none;
  }

  bool _didLockedRosterMembershipChange() {
    final lockState = _rosterLockState;
    if (!lockState.hasLockedPlayers) return false;

    final currentById = {
      for (final player in [..._starting, ..._bench])
        _playerSlotIdentity(player): player,
    };
    final playerIds = <String>{..._savedRosterById.keys, ...currentById.keys};

    for (final playerId in playerIds) {
      final slot = currentById[playerId] ?? _savedRosterById[playerId];
      if (slot == null || !lockState.isLocked(slot)) continue;
      if (_savedMembershipForPlayerId(playerId) !=
          _currentMembershipForPlayerId(playerId)) {
        return true;
      }
    }
    return false;
  }

  bool _didLockedLeadershipChange() {
    final lockState = _rosterLockState;
    if (!lockState.hasLockedPlayers) return false;

    bool lockedPlayerChanged(String? beforeId, String? afterId) {
      final normalizedBefore = beforeId?.trim() ?? '';
      final normalizedAfter = afterId?.trim() ?? '';
      if (normalizedBefore == normalizedAfter) return false;
      final beforeSlot = normalizedBefore.isEmpty
          ? null
          : (_savedRosterById[normalizedBefore] ??
                {
                  for (final player in [..._starting, ..._bench])
                    _playerSlotIdentity(player): player,
                }[normalizedBefore]);
      final afterSlot = normalizedAfter.isEmpty
          ? null
          : ({
                  for (final player in [..._starting, ..._bench])
                    _playerSlotIdentity(player): player,
                }[normalizedAfter] ??
                _savedRosterById[normalizedAfter]);
      return (beforeSlot != null && lockState.isLocked(beforeSlot)) ||
          (afterSlot != null && lockState.isLocked(afterSlot));
    }

    return lockedPlayerChanged(_savedCaptainPlayerId, _captainPlayerId) ||
        lockedPlayerChanged(_savedViceCaptainPlayerId, _viceCaptainPlayerId);
  }

  bool _hasLockedRosterChanges() {
    return _didLockedRosterMembershipChange() || _didLockedLeadershipChange();
  }

  void _showRosterLockMessage({String? playerName}) {
    if (!mounted) return;
    final unlocksAtUtc = _rosterLockState.unlocksAtUtc;
    final message = playerName == null
        ? unlocksAtUtc == null
              ? '잠긴 선수는 변경할 수 없습니다.'
              : '잠긴 선수는 ${_kstMonthDayTimeLabel(unlocksAtUtc)}까지 변경할 수 없습니다.'
        : unlocksAtUtc == null
        ? '$playerName 선수는 잠겨 있습니다.'
        : '$playerName 선수는 ${_kstMonthDayTimeLabel(unlocksAtUtc)}까지 잠겨 있습니다.';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<_PlayerSlot?> _showModernRosterPickerSheet({
    required String title,
    required String subtitle,
    required IconData icon,
    String? helperText,
    bool Function(_PlayerSlot player)? isSelectable,
  }) {
    return showModalBottomSheet<_PlayerSlot>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final isDark = theme.brightness == Brightness.dark;
        final Color surface = isDark
            ? const Color(0xFF171A1D)
            : const Color(0xFFFFFCF6);
        final Color border = isDark
            ? Colors.white.withValues(alpha: 0.08)
            : const Color(0xFFD7DED0);
        final Color text = isDark ? Colors.white : const Color(0xFF171717);
        final Color muted = isDark ? Colors.white70 : const Color(0xFF667085);
        const Color accent = Color(0xFF2E8B57);
        final Color accentSoft = isDark
            ? const Color(0xFF1F3B31)
            : const Color(0xFFE4F4EA);
        final Color cardFill = isDark ? const Color(0xFF1F2428) : Colors.white;

        Widget sectionLabel(String label, int count) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(2, 0, 2, 10),
            child: Row(
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: text,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: accentSoft,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$count명',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: accent,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        Widget rosterCard(_PlayerSlot p, {required bool isStarting}) {
          final selectable = isSelectable?.call(p) ?? true;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: selectable ? () => Navigator.pop(ctx, p) : null,
                borderRadius: BorderRadius.circular(22),
                child: Ink(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: selectable
                        ? cardFill
                        : cardFill.withValues(alpha: isDark ? 0.82 : 0.7),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: selectable
                          ? border
                          : border.withValues(alpha: 0.8),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: isDark ? 0.18 : 0.05,
                        ),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isStarting
                                ? const [Color(0xFF2E8B57), Color(0xFF6BCB8B)]
                                : const [Color(0xFF3C6DF0), Color(0xFF84A9FF)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          p.position,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    p.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      color: selectable
                                          ? text
                                          : muted.withValues(alpha: 0.9),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isStarting
                                        ? accentSoft
                                        : const Color(0xFFE7EEFF),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    isStarting ? '스타팅' : '벤치',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      color: isStarting
                                          ? accent
                                          : const Color(0xFF315EDB),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              widget.isSoccer
                                  ? '${p.club.isEmpty ? '-' : p.club} · ${p.position}'
                                  : '${p.club} · ${p.position} · #${p.number}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: muted,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? const Color(0xFF242B31)
                                        : const Color(0xFFF3F6FB),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    '현재 ${p.score} pts',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: isDark
                                          ? Colors.white70
                                          : const Color(0xFF4B5563),
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                if (!selectable)
                                  const Icon(
                                    Icons.lock_rounded,
                                    size: 18,
                                    color: Color(0xFF98A2B3),
                                  )
                                else
                                  const Icon(
                                    Icons.arrow_forward_rounded,
                                    size: 20,
                                    color: Color(0xFF98A2B3),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        return SafeArea(
          child: FractionallySizedBox(
            heightFactor: 0.88,
            child: Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: border),
              ),
              child: Column(
                children: [
                  Container(
                    width: 54,
                    height: 5,
                    margin: const EdgeInsets.only(top: 12),
                    decoration: BoxDecoration(
                      color: border,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isDark
                              ? const [Color(0xFF20332B), Color(0xFF172026)]
                              : const [Color(0xFFEAF7EE), Color(0xFFF7F4EA)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(
                                alpha: isDark ? 0.08 : 0.75,
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(icon, color: accent, size: 24),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 28,
                              height: 1.08,
                              fontWeight: FontWeight.w900,
                              color: text,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            subtitle,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: muted,
                            ),
                          ),
                          if (helperText != null) ...[
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(
                                  alpha: isDark ? 0.06 : 0.8,
                                ),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.info_outline_rounded,
                                    size: 16,
                                    color: accent,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      helperText,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: muted,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
                      children: [
                        sectionLabel('스타팅', _starting.length),
                        for (final p in _starting)
                          rosterCard(p, isStarting: true),
                        const SizedBox(height: 8),
                        sectionLabel('벤치', _bench.length),
                        for (final p in _bench)
                          rosterCard(p, isStarting: false),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: BorderSide(color: border),
                          foregroundColor: text,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: const Text(
                          '취소',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
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

  _PlayerSlot? _validatedStartingLeader({
    String? preferredPlayerId,
    String? preferredName,
  }) {
    final candidateId = preferredPlayerId?.trim() ?? '';
    if (candidateId.isNotEmpty) {
      for (final player in _starting) {
        if (_playerSlotIdentity(player) == candidateId) return player;
      }
    }
    final candidateName = preferredName?.trim();
    if (candidateName == null || candidateName.isEmpty) return null;
    for (final player in _starting) {
      if (player.name == candidateName) return player;
    }
    return null;
  }

  double _leadershipCandidateScore(_PlayerSlot slot) {
    if (!widget.isSoccer || _fantasyDraft == null || _fantasyMyTeam == null) {
      return _fantasyProjectedSlotScore(slot, isSoccer: widget.isSoccer);
    }
    final round = _effectiveFantasyRoundForDraft(_fantasyDraft!);
    return _fantasySoccerBasePlayerRoundScore(
      _fantasyDraft!,
      _fantasyMyTeam!,
      slot.name,
      round,
      playerId: slot.playerId,
    );
  }

  List<_PlayerSlot> _rankedLeadershipCandidates() {
    final ranked = [..._starting]
      ..sort((a, b) {
        final scoreCompare = _leadershipCandidateScore(
          b,
        ).compareTo(_leadershipCandidateScore(a));
        if (scoreCompare != 0) return scoreCompare;
        return a.name.compareTo(b.name);
      });
    return ranked;
  }

  _PlayerSlot? _defaultCaptainSelection({String? excludingPlayerId}) {
    for (final player in _rankedLeadershipCandidates()) {
      if (_playerSlotIdentity(player) != excludingPlayerId) return player;
    }
    return null;
  }

  _PlayerSlot? _defaultViceCaptainSelection({String? captainPlayerId}) {
    for (final player in _rankedLeadershipCandidates()) {
      if (_playerSlotIdentity(player) != captainPlayerId) return player;
    }
    return null;
  }

  void _normalizeLeadershipSelection({
    String? preferredCaptainName,
    String? preferredViceCaptainName,
    String? preferredCaptainPlayerId,
    String? preferredViceCaptainPlayerId,
  }) {
    final captain =
        _validatedStartingLeader(
          preferredPlayerId: preferredCaptainPlayerId,
          preferredName: preferredCaptainName,
        ) ??
        _defaultCaptainSelection();
    final preferredVice = _validatedStartingLeader(
      preferredPlayerId: preferredViceCaptainPlayerId,
      preferredName: preferredViceCaptainName,
    );
    final captainPlayerId = captain == null
        ? null
        : _playerSlotIdentity(captain);
    final viceCaptain =
        preferredVice != null &&
            _playerSlotIdentity(preferredVice) != captainPlayerId
        ? preferredVice
        : _defaultViceCaptainSelection(captainPlayerId: captainPlayerId);
    _captainName = captain?.name;
    _viceCaptainName = viceCaptain?.name;
    _captainPlayerId = captainPlayerId;
    _viceCaptainPlayerId = viceCaptain == null
        ? null
        : _playerSlotIdentity(viceCaptain);
  }

  _FantasyTeamPlayer _fantasyTeamPlayerFromSlot(_PlayerSlot slot) {
    return _FantasyTeamPlayer(
      name: slot.name,
      position: slot.position,
      score: slot.score,
      club: slot.club,
      number: slot.number,
      playerId: slot.playerId,
    );
  }

  Future<void> _primeKboRoundPointsForPlayers(
    Iterable<_FantasyTeamPlayer> players,
  ) async {
    final unique = <String, _FantasyTeamPlayer>{};
    for (final player in players) {
      unique[_fantasyTeamPlayerIdentity(player)] = player;
    }
    const batchSize = 2;
    final values = unique.values.toList();
    for (var start = 0; start < values.length; start += batchSize) {
      final end = min(start + batchSize, values.length);
      final batch = values.sublist(start, end);
      await Future.wait(
        batch.map(
          (player) => _loadKboRoundPointsForPlayerShared(
            playerName: player.name,
            club: _normalizeKboDraftClub(player.club),
            preferredNumber: player.number,
            preferredPosition: player.position,
          ),
        ),
      );
    }
  }

  List<_KboFantasyRoundScoreState> _mergeKboRoundScoreState(
    List<_KboFantasyRoundScoreState> existing,
    _KboFantasyRoundScoreState nextState,
  ) {
    final merged = [
      for (final state in existing)
        if (state.round != nextState.round) state,
      nextState,
    ]..sort((a, b) => a.round.compareTo(b.round));
    return merged;
  }

  Future<List<_KboFantasyRoundScoreState>> _updatedKboRoundScoreStates({
    required _JoinedDraft draft,
    required _FantasyTeamState existingTeam,
    required _FantasyTeamState nextTeam,
  }) async {
    if (draft.isSoccer) return existingTeam.kboRoundScoreStates;
    final now = DateTime.now();
    final round = _effectiveFantasyRoundForDraft(draft, now: now);
    if (round <= 0 || !_kboFantasyRoundHasStarted(draft, round, now)) {
      return existingTeam.kboRoundScoreStates;
    }
    // Re-freeze the current displayed team score on every allowed in-round save
    // so unlocked roster edits do not retroactively change the matchup total.
    await _loadCachedKboLeagueData();
    await _primeKboRoundPointsForPlayers([
      ...existingTeam.starting,
      ...nextTeam.starting,
    ]);
    final bankedScore = _fantasyTeamRoundScore(
      existingTeam,
      round,
      isSoccer: false,
      draft: draft,
    );
    final starterBaselines = <String, double>{
      for (final player in nextTeam.starting)
        _fantasyTeamPlayerIdentity(
          player,
        ): _fantasyKboDisplayedPlayerRoundScore(
          player,
          draft: draft,
          round: round,
          team: nextTeam,
        ),
    };
    final existingState = _kboRoundScoreStateForTeam(existingTeam, round);
    return _mergeKboRoundScoreState(
      existingTeam.kboRoundScoreStates,
      _KboFantasyRoundScoreState(
        round: round,
        bankedScore: bankedScore,
        starterBaselines: starterBaselines,
        starterPlayers: nextTeam.starting,
        doubledPlayerId: _effectiveCaptainDoublePlayerIdForKboTeam(
          nextTeam,
          draft: draft,
          round: round,
        ),
        updatedAt: now.toUtc(),
        unlockedScoreSnapshot: existingState?.unlockedScoreSnapshot,
        unlockedAt: existingState?.unlockedAt,
      ),
    );
  }

  _JoinedDraft _draftWithUpdatedFantasyMyTeam(
    _JoinedDraft draft,
    _FantasyTeamState updatedMyTeam,
  ) {
    final updatedTeams = draft.fantasyTeams.map((team) {
      final sameUid =
          updatedMyTeam.uid.isNotEmpty && team.uid == updatedMyTeam.uid;
      final sameName = team.teamName == updatedMyTeam.teamName;
      return (sameUid || sameName) ? updatedMyTeam : team;
    }).toList();
    return _JoinedDraft(
      leagueId: draft.leagueId,
      leagueName: draft.leagueName,
      when: draft.when,
      isSoccer: draft.isSoccer,
      teamCount: draft.teamCount,
      roundCount: draft.roundCount,
      memberCount: draft.memberCount,
      inviteCode: draft.inviteCode,
      ownerId: draft.ownerId,
      draftOrder: draft.draftOrder,
      fantasyReady: draft.fantasyReady,
      fantasyTeams: updatedTeams,
      fantasySchedule: draft.fantasySchedule,
      draftBoard: draft.draftBoard,
    );
  }

  Set<int> _soccerRosterSaveWarmRoundsForDraft(_JoinedDraft draft) {
    if (!draft.isSoccer || draft.roundCount <= 0) {
      return const <int>{};
    }
    final rounds = <int>{};
    final detailRound = _selectedFantasyMatchupForDraft(draft)?.round;
    if (detailRound != null && detailRound > 0) {
      rounds.add(detailRound);
    }
    final homeRound = _homeDisplayedFantasyRoundAt(draft, DateTime.now());
    if (homeRound > 0) {
      rounds.add(min(max(1, homeRound), max(1, draft.roundCount)));
    }
    return rounds;
  }

  Future<void> _refreshSoccerSnapshotsAfterRosterSave(
    _JoinedDraft draft,
  ) async {
    if (!draft.isSoccer || draft.leagueId.trim().isEmpty) return;
    final warmRounds = _soccerRosterSaveWarmRoundsForDraft(draft);
    if (warmRounds.isEmpty) return;

    for (final round in warmRounds) {
      final cacheKey = _fantasySoccerRoundCacheKey(draft, round);
      _fantasySoccerRoundScoreCache.remove(cacheKey);
      _fantasySoccerRoundScoreInFlight.remove(cacheKey);
    }

    for (final round in warmRounds.toList()..sort()) {
      try {
        await _ensureFantasySoccerRoundScoreSnapshot(draft, round, force: true);
      } catch (error, stackTrace) {
        debugPrint(
          'soccer roster save snapshot warm failed '
          '(league=${draft.leagueId}, round=$round): $error',
        );
        debugPrint('$stackTrace');
      }
    }
    unawaited(_persistFantasySoccerRoundScoreCache());
  }

  Future<bool> _performFantasyRosterSave({
    bool showSuccessSnackBar = true,
  }) async {
    final draft = _fantasyDraft;
    final myTeam = _fantasyMyTeam;
    if (_isSavingRoster || !_rosterDirty || draft == null || myTeam == null) {
      return false;
    }
    if (mounted) {
      setState(() {
        _isSavingRoster = true;
      });
    }
    try {
      await _refreshRosterLockDataForSave();
      if (_hasLockedRosterChanges()) {
        _showRosterLockMessage();
        return false;
      }

      final nextMyTeam = _FantasyTeamState(
        uid: myTeam.uid,
        teamName: myTeam.teamName,
        roster: [
          ..._starting.map(_fantasyTeamPlayerFromSlot),
          ..._bench.map(_fantasyTeamPlayerFromSlot),
        ],
        starting: _starting.map(_fantasyTeamPlayerFromSlot).toList(),
        bench: _bench.map(_fantasyTeamPlayerFromSlot).toList(),
        captainName: _captainName,
        viceCaptainName: _viceCaptainName,
        captainPlayerId: _captainPlayerId,
        viceCaptainPlayerId: _viceCaptainPlayerId,
        kboRoundScoreStates: myTeam.kboRoundScoreStates,
      );
      final updatedMyTeam = draft.isSoccer
          ? nextMyTeam
          : _normalizeBaseballFantasyTeam(nextMyTeam);
      final updatedKboRoundScoreStates = draft.isSoccer
          ? updatedMyTeam.kboRoundScoreStates
          : await _updatedKboRoundScoreStates(
              draft: draft,
              existingTeam: myTeam,
              nextTeam: updatedMyTeam,
            );
      final persistedMyTeam = _FantasyTeamState(
        uid: updatedMyTeam.uid,
        teamName: updatedMyTeam.teamName,
        roster: updatedMyTeam.roster,
        starting: updatedMyTeam.starting,
        bench: updatedMyTeam.bench,
        captainName: updatedMyTeam.captainName,
        viceCaptainName: updatedMyTeam.viceCaptainName,
        captainPlayerId: updatedMyTeam.captainPlayerId,
        viceCaptainPlayerId: updatedMyTeam.viceCaptainPlayerId,
        kboRoundScoreStates: updatedKboRoundScoreStates,
      );
      final updatedDraft = _draftWithUpdatedFantasyMyTeam(
        draft,
        persistedMyTeam,
      );
      final updatedMatchup = _selectedFantasyMatchupForDraft(updatedDraft);

      await LeagueService.instance.updateFantasyRoster(
        leagueId: draft.leagueId,
        teamName: persistedMyTeam.teamName,
        roster: persistedMyTeam.roster.map((player) => player.toMap()).toList(),
        starting: persistedMyTeam.starting
            .map((player) => player.toMap())
            .toList(),
        bench: persistedMyTeam.bench.map((player) => player.toMap()).toList(),
        captainName: persistedMyTeam.captainName,
        viceCaptainName: persistedMyTeam.viceCaptainName,
        captainPlayerId: persistedMyTeam.captainPlayerId,
        viceCaptainPlayerId: persistedMyTeam.viceCaptainPlayerId,
        kboRoundScoreStates: persistedMyTeam.kboRoundScoreStates
            .map((state) => state.toMap())
            .toList(),
      );

      if (draft.isSoccer) {
        await _refreshSoccerSnapshotsAfterRosterSave(updatedDraft);
      }

      if (!mounted) return true;
      setState(() {
        _resolvedFantasyDraft = updatedDraft;
        _fantasyMyTeam = updatedMatchup?.myTeam ?? persistedMyTeam;
        _fantasyMatchup = updatedMatchup;
        _rebuildFantasyOwnershipCacheFor(
          draft: updatedDraft,
          allPlayers: _allPlayers,
        );
        _fantasyProjectedScores = const <String, double>{};
        _fantasyPitcherWeeklyProjectionContexts =
            const <
              String,
              ({
                double opportunityFactor,
                int confirmedStarts,
                int completedStarts,
              })
            >{};
        _fantasyProjectedScoresKey = '';
        _fantasyProjectedScoresFreshKey = '';
        _fantasyPitcherWeeklyProjectionContextsKey = '';
        _fantasyProjectedScoresFuture = null;
        if (updatedMatchup != null && updatedDraft.isSoccer) {
          _lineup = _buildFantasySoccerLineup(updatedMatchup);
        } else if (!updatedDraft.isSoccer) {
          _lineup = null;
        }
        _persistMyRosterToCache();
        _captureSavedRosterState();
      });
      if (_section == _MatchSection.matchup ||
          _section == _MatchSection.roster) {
        unawaited(_primePersistedFantasyProjectedScores(updatedDraft));
        unawaited(_ensureFantasyProjectedScores(updatedDraft));
      }

      final homeState = homeKey.currentState;
      if (homeState != null && homeState.mounted) {
        homeState.setState(() {
          homeState._upsertJoinedDraft(updatedDraft);
          homeState._sanitizeSelectedHomeLeagues();
          homeState._setPrimaryDraftFromJoinedDrafts();
        });
        unawaited(homeState._saveLocalState());
      }

      if (showSuccessSnackBar && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('로스터 설정이 저장되었습니다.')));
      }
      return true;
    } finally {
      if (mounted) {
        setState(() {
          _isSavingRoster = false;
        });
      } else {
        _isSavingRoster = false;
      }
    }
  }

  Future<void> _refreshRosterLockDataForSave() async {
    if (widget.isSoccer) {
      await _loadCachedKLeagueLeagueData(forceRefresh: true);
    } else {
      await _loadCachedKboLeagueData(forceRefresh: true);
    }
    if (!mounted) return;
    setState(() {});
  }

  String _rosterSaveFailureMessage(Object error) {
    final raw = '$error'.trim();
    if (raw.isEmpty) {
      return '로스터 저장에 실패했습니다. 다시 시도해 주세요.';
    }
    final normalized = raw
        .replaceFirst(RegExp(r'^Exception:\s*'), '')
        .replaceFirst(RegExp(r'^\[firebase_functions\/[^\]]+\]\s*'), '')
        .trim();
    if (normalized.isEmpty) {
      return '로스터 저장에 실패했습니다. 다시 시도해 주세요.';
    }
    return normalized;
  }

  bool _isGenericRosterSaveFailureMessage(String message) {
    return message == '로스터 저장에 실패했습니다. 다시 시도해 주세요.';
  }

  Future<void> _saveFantasyRosterChanges() async {
    final draft = _fantasyDraft;
    final myTeam = _fantasyMyTeam;
    if (_isSavingRoster || !_rosterDirty || draft == null || myTeam == null) {
      return;
    }

    final dialogContextCompleter = Completer<BuildContext>();
    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          if (!dialogContextCompleter.isCompleted) {
            dialogContextCompleter.complete(dialogContext);
          }
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            content: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                ),
                SizedBox(width: 14),
                Text(
                  '로스터 저장 중...',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          );
        },
      ),
    );

    final dialogContext = await dialogContextCompleter.future;
    try {
      final saved = await _performFantasyRosterSave(showSuccessSnackBar: false);
      if (!mounted) return;
      if (saved) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('로스터 설정이 저장되었습니다.')));
      }
    } catch (error, stackTrace) {
      debugPrint('Roster save failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_rosterSaveFailureMessage(error))));
    } finally {
      if (dialogContext.mounted) {
        Navigator.of(dialogContext).pop();
      }
    }
  }

  Future<bool> _persistPlayersTabRosterChange({
    required String successMessage,
    required String failureMessage,
    bool showSuccessDialog = false,
  }) async {
    try {
      final saved = await _performFantasyRosterSave(showSuccessSnackBar: false);
      if (!saved) return false;
      if (!mounted) return true;
      if (showSuccessDialog) {
        await showDialog<void>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              title: const Text(
                '영입 완료',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              content: Text(
                successMessage,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text(
                    '확인',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            );
          },
        );
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(successMessage)));
      }
      return true;
    } catch (error, stackTrace) {
      debugPrint('Players tab roster save failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return false;
      final message = _rosterSaveFailureMessage(error);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isGenericRosterSaveFailureMessage(message)
                ? failureMessage
                : message,
          ),
        ),
      );
      return false;
    }
  }

  void _maybeAutoScrollRoster(Offset globalPosition) {
    if (!_scrollController.hasClients) return;
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return;
    final local = renderObject.globalToLocal(globalPosition);
    final size = renderObject.size;
    const edgeThreshold = 120.0;
    const step = 18.0;
    final position = _scrollController.position;
    final current = position.pixels;
    if (local.dy < edgeThreshold) {
      final target = max(position.minScrollExtent, current - step);
      if ((target - current).abs() > 0.1) {
        _scrollController.jumpTo(target);
      }
      return;
    }
    if (local.dy > size.height - edgeThreshold) {
      final target = min(position.maxScrollExtent, current + step);
      if ((target - current).abs() > 0.1) {
        _scrollController.jumpTo(target);
      }
    }
  }

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
    if (_isSavingRoster) return;
    await _refreshRosterLockDataForSave();
    if (!mounted) return;
    final ownership = _ownerForSlot(fa);
    if (ownership != PlayerOwnership.freeAgent) return;
    if (_isRosterSlotLocked(fa)) {
      _showRosterLockMessage(playerName: fa.name);
      return;
    }

    // If roster is not full (shouldn't happen often in this demo), just add to bench.
    if (_myRosterCount < 18) {
      final snapshot = _captureRosterMutationSnapshot();
      setState(() {
        _bench.add(fa);
        _setOwnerForSlot(fa, PlayerOwnership.myTeam);
        _normalizeLeadershipSelection(
          preferredCaptainName: _captainName,
          preferredViceCaptainName: _viceCaptainName,
          preferredCaptainPlayerId: _captainPlayerId,
          preferredViceCaptainPlayerId: _viceCaptainPlayerId,
        );
        _rosterDirty = _computeRosterDirty();
        _persistMyRosterToCache();
        _applyStartingToLineup();
      });
      final saved = await _persistPlayersTabRosterChange(
        successMessage: '${fa.name} 선수를 영입했습니다.',
        failureMessage: '${fa.name} 영입 저장에 실패했습니다. 다시 시도하세요.',
        showSuccessDialog: true,
      );
      if (!saved) {
        _restoreRosterMutationSnapshot(snapshot);
      }
      return;
    }

    final releasablePlayers = [
      ..._starting,
      ..._bench,
    ].where((player) => !_isRosterSlotLocked(player)).toList();
    if (releasablePlayers.isEmpty) {
      _showRosterLockMessage();
      return;
    }

    // Roster is full: require releasing one player.
    final released = await _showModernRosterPickerSheet(
      title: 'Make Room',
      subtitle: '방출할 선수를 선택하면 새 FA 선수가 벤치로 합류합니다.',
      helperText: '로스터가 가득 찼습니다 (${releasablePlayers.length}명 선택 가능)',
      icon: Icons.person_remove_alt_1_rounded,
      isSelectable: (player) => !_isRosterSlotLocked(player),
    );

    if (released == null) return;
    if (_isRosterSlotLocked(released)) {
      _showRosterLockMessage(playerName: released.name);
      return;
    }

    final wasStarting = _starting.contains(released);
    final wasBench = _bench.contains(released);
    if (!wasStarting && !wasBench) return;

    // If releasing a starter, we must promote a bench player of the same position
    // so the starting XI stays valid.
    _PlayerSlot? promoted;
    if (wasStarting) {
      final idx = _bench.indexWhere(
        (b) => b.position == released.position && !_isRosterSlotLocked(b),
      );
      if (idx < 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('이동 가능한 같은 포지션 벤치 선수가 없어 스타팅 변경이 불가합니다.'),
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }
      promoted = _bench[idx];
    }

    final snapshot = _captureRosterMutationSnapshot();
    setState(() {
      // Release
      _starting.remove(released);
      _bench.remove(released);
      _setOwnerForSlot(released, PlayerOwnership.freeAgent);

      // Promote if needed
      if (promoted != null) {
        _bench.removeWhere(
          (player) =>
              _playerSlotIdentity(player) == _playerSlotIdentity(promoted!),
        );
        _starting.add(promoted);
      }

      // Sign FA to bench
      _bench.add(fa);
      _setOwnerForSlot(fa, PlayerOwnership.myTeam);

      _normalizeLeadershipSelection(
        preferredCaptainName: _captainName,
        preferredViceCaptainName: _viceCaptainName,
        preferredCaptainPlayerId: _captainPlayerId,
        preferredViceCaptainPlayerId: _viceCaptainPlayerId,
      );
      _rosterDirty = _computeRosterDirty();
      _persistMyRosterToCache();
      _applyStartingToLineup();
    });
    final saved = await _persistPlayersTabRosterChange(
      successMessage: '${released.name} 방출 · ${fa.name} 영입 완료',
      failureMessage: '${fa.name} 영입 저장에 실패했습니다. 다시 시도하세요.',
      showSuccessDialog: true,
    );
    if (!saved) {
      _restoreRosterMutationSnapshot(snapshot);
    }
  }

  Future<_PlayerSlot?> _pickMyRosterPlayerSheet({
    required String title,
    String? subtitle,
    bool Function(_PlayerSlot player)? isSelectable,
  }) async {
    return _showModernRosterPickerSheet(
      title: title,
      subtitle: subtitle ?? '선수를 탭하면 바로 선택됩니다.',
      helperText: '스타팅과 벤치를 한 화면에서 비교할 수 있습니다.',
      icon: Icons.swap_horiz_rounded,
      isSelectable: isSelectable,
    );
  }

  Future<void> _requestTrade(_PlayerSlot target) async {
    final own = _ownerForSlot(target);
    if (own != PlayerOwnership.otherTeam) return;
    await _loadCachedKLeagueLeagueData();
    if (!mounted) return;
    if (_isRosterSlotLocked(target)) {
      _showRosterLockMessage(playerName: target.name);
      return;
    }
    final draft = _fantasyDraft;
    final myTeam = _fantasyMyTeam;
    if (draft == null || myTeam == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('트레이드 팀 정보를 찾을 수 없습니다.')));
      return;
    }

    _FantasyTeamState? opponentTeam;
    for (final team in draft.fantasyTeams) {
      if (team.teamName == myTeam.teamName) continue;
      if (team.roster.any(
        (player) =>
            _playerSlotIdentity(player.toPlayerSlot()) ==
            _playerSlotIdentity(target),
      )) {
        opponentTeam = team;
        break;
      }
    }
    if (opponentTeam == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('상대 팀 로스터를 찾을 수 없습니다.')));
      return;
    }

    final proposal = await Navigator.push<_TradeProposal>(
      context,
      MaterialPageRoute(
        builder: (_) => _TradePage(
          myTeamName: myTeam.teamName,
          opponentTeamName: opponentTeam!.teamName,
          myRoster: [..._starting, ..._bench],
          opponentRoster: opponentTeam.roster
              .map((player) => player.toPlayerSlot())
              .toList(),
          initialOpponentPlayerName: target.name,
          isSoccer: widget.isSoccer,
          isLocked: _isRosterSlotLocked,
          rosterUnlocksAtUtc: _rosterLockState.unlocksAtUtc,
        ),
      ),
    );
    if (proposal == null || !mounted) return;
    try {
      await LeagueService.instance.submitTradeRequest(
        leagueId: draft.leagueId,
        leagueName: draft.leagueName,
        isSoccer: draft.isSoccer,
        fromUid: myTeam.uid,
        fromTeamName: proposal.myTeamName,
        toUid: opponentTeam.uid,
        toTeamName: proposal.opponentTeamName,
        fromPlayers: _playerSlotsToTradeMaps(proposal.myPlayers),
        toPlayers: _playerSlotsToTradeMaps(proposal.opponentPlayers),
      );
    } on FirebaseException catch (error, stackTrace) {
      debugPrint('submitTradeRequest failed: ${error.code} ${error.message}');
      debugPrint('$stackTrace');
      if (!mounted) return;
      final message = error.code == 'permission-denied'
          ? '트레이드 요청 권한이 설정되지 않아 요청을 보낼 수 없습니다.'
          : '트레이드 요청 전송에 실패했습니다. 잠시 후 다시 시도해주세요.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      return;
    }
    if (!mounted) return;
    final myNames = proposal.myPlayers.map((player) => player.name).join(', ');
    final opponentNames = proposal.opponentPlayers
        .map((player) => player.name)
        .join(', ');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$myNames ↔ $opponentNames 트레이드 요청을 ${proposal.opponentTeamName}에 보냈습니다.',
        ),
      ),
    );
    unawaited(_syncFantasyNotifications());
  }

  Future<void> _releaseMyPlayer(_PlayerSlot target) async {
    if (_isSavingRoster) return;
    final own = _ownerForSlot(target);
    if (own != PlayerOwnership.myTeam) return;
    await _loadCachedKLeagueLeagueData();
    if (!mounted) return;
    if (_isRosterSlotLocked(target)) {
      _showRosterLockMessage(playerName: target.name);
      return;
    }

    final targetKey = _playerSlotIdentity(target);
    final isStarting = _starting.any(
      (player) => _playerSlotIdentity(player) == targetKey,
    );
    final released = isStarting
        ? _starting.firstWhere(
            (player) => _playerSlotIdentity(player) == targetKey,
          )
        : _bench.firstWhere(
            (player) => _playerSlotIdentity(player) == targetKey,
            orElse: () => target,
          );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text(
            '선수 방출',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          content: Text(
            isStarting
                ? '${released.name} 선수를 방출하시겠습니까?\n스타팅 선수 방출 시 같은 포지션 벤치 선수가 자동 승격됩니다.'
                : '${released.name} 선수를 방출하시겠습니까?',
            style: const TextStyle(fontWeight: FontWeight.w700, height: 1.45),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE85C53),
                foregroundColor: Colors.white,
              ),
              child: const Text('방출'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;

    _PlayerSlot? promoted;
    if (isStarting) {
      final idx = _bench.indexWhere(
        (player) =>
            player.position == released.position &&
            !_isRosterSlotLocked(player),
      );
      if (idx < 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('이동 가능한 같은 포지션 벤치 선수가 없어 스타팅 방출이 불가합니다.'),
            ),
          );
        }
        return;
      }
      promoted = _bench.removeAt(idx);
    }

    setState(() {
      _starting.removeWhere(
        (player) => _playerSlotIdentity(player) == targetKey,
      );
      _bench.removeWhere((player) => _playerSlotIdentity(player) == targetKey);
      if (promoted != null) {
        _starting.add(promoted);
      }
      _setOwnerForSlot(released, PlayerOwnership.freeAgent);
      _normalizeLeadershipSelection(
        preferredCaptainName: _captainName,
        preferredViceCaptainName: _viceCaptainName,
        preferredCaptainPlayerId: _captainPlayerId,
        preferredViceCaptainPlayerId: _viceCaptainPlayerId,
      );
      _rosterDirty = _computeRosterDirty();
      _persistMyRosterToCache();
      _applyStartingToLineup();
    });
    await _persistPlayersTabRosterChange(
      successMessage: '${released.name} 선수를 방출했습니다.',
      failureMessage: '${released.name} 방출 저장에 실패했습니다. 다시 시도하세요.',
    );
  }

  void _applyStartingToLineup() {
    if (!widget.isSoccer || _lineup == null || _starting.isEmpty) return;
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
    final formationName =
        _formationKeyForCounts(df: dfCount, mf: mfCount, fw: fwCount) ??
        _lineup!.homeFormation;

    // Build home rows in GK -> DF -> MF -> FW order (Matchup view expects this).
    final gkSlot = (gks.isNotEmpty ? gks.first : flat.first);
    // Never place a DF into FW lane etc: each lane strictly uses its own position list.
    final dfSlots = List<_PlayerSlot>.from(dfs);
    final mfSlots = List<_PlayerSlot>.from(mfs);
    final fwSlots = List<_PlayerSlot>.from(fws);

    final newHome = <_Player>[
      _Player(
        slots: [
          _PlayerSlot(
            name: gkSlot.name,
            score: gkSlot.score,
            position: gkSlot.position,
            club: gkSlot.club,
            number: gkSlot.number,
            playerId: gkSlot.playerId,
          ),
        ],
      ),
      _Player(
        slots: dfSlots
            .map(
              (p) => _PlayerSlot(
                name: p.name,
                score: p.score,
                position: p.position,
                club: p.club,
                number: p.number,
                playerId: p.playerId,
              ),
            )
            .toList(),
      ),
      _Player(
        slots: mfSlots
            .map(
              (p) => _PlayerSlot(
                name: p.name,
                score: p.score,
                position: p.position,
                club: p.club,
                number: p.number,
                playerId: p.playerId,
              ),
            )
            .toList(),
      ),
      _Player(
        slots: fwSlots
            .map(
              (p) => _PlayerSlot(
                name: p.name,
                score: p.score,
                position: p.position,
                club: p.club,
                number: p.number,
                playerId: p.playerId,
              ),
            )
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
    final candidates = pool
        .where((p) => !startingNames.contains(p.name))
        .toList();
    candidates.shuffle(Random(_stableSeedFromKey('$key|bench')));
    final bench = candidates
        .take(7)
        .map(
          (p) => _PlayerSlot(
            name: p.name,
            score: p.score,
            position: p.position,
            club: p.club,
            number: p.number,
            playerId: p.playerId,
          ),
        )
        .toList();
    _cachedTeamBenches[key] = bench;
    return List<_PlayerSlot>.from(bench);
  }

  void _swapPlayers(_PlayerSlot from, _PlayerSlot to) {
    if (_isRosterSlotLocked(from) || _isRosterSlotLocked(to)) {
      _showRosterLockMessage(
        playerName: _isRosterSlotLocked(from) ? from.name : to.name,
      );
      return;
    }
    final fromKey = _playerSlotIdentity(from);
    final toKey = _playerSlotIdentity(to);
    if (fromKey == toKey) return;
    final fromStart = _starting.any(
      (player) => _playerSlotIdentity(player) == fromKey,
    );
    final toStart = _starting.any(
      (player) => _playerSlotIdentity(player) == toKey,
    );

    if (!fromStart && !toStart) {
      final fromBench = _bench.any(
        (player) => _playerSlotIdentity(player) == fromKey,
      );
      final toBench = _bench.any(
        (player) => _playerSlotIdentity(player) == toKey,
      );
      if (!fromBench || !toBench) return;
    }

    final prevStarting = List<_PlayerSlot>.from(_starting);
    final prevBench = List<_PlayerSlot>.from(_bench);

    // Tentatively apply swap.
    if (fromStart && toStart) {
      final i = _starting.indexWhere(
        (player) => _playerSlotIdentity(player) == fromKey,
      );
      final j = _starting.indexWhere(
        (player) => _playerSlotIdentity(player) == toKey,
      );
      if (i < 0 || j < 0) return;
      final tmp = _starting[i];
      _starting[i] = _starting[j];
      _starting[j] = tmp;
    } else if (!fromStart && !toStart) {
      final i = _bench.indexWhere(
        (player) => _playerSlotIdentity(player) == fromKey,
      );
      final j = _bench.indexWhere(
        (player) => _playerSlotIdentity(player) == toKey,
      );
      if (i < 0 || j < 0) return;
      final tmp = _bench[i];
      _bench[i] = _bench[j];
      _bench[j] = tmp;
    } else if (fromStart && !toStart) {
      final i = _starting.indexWhere(
        (player) => _playerSlotIdentity(player) == fromKey,
      );
      final j = _bench.indexWhere(
        (player) => _playerSlotIdentity(player) == toKey,
      );
      if (i < 0 || j < 0) return;
      _starting[i] = to;
      _bench[j] = from;
    } else {
      final i = _bench.indexWhere(
        (player) => _playerSlotIdentity(player) == fromKey,
      );
      final j = _starting.indexWhere(
        (player) => _playerSlotIdentity(player) == toKey,
      );
      if (i < 0 || j < 0) return;
      _bench[i] = to;
      _starting[j] = from;
    }

    // Enforce that starting XI always matches one of the allowed formations,
    // and positions never get "forced" into other lanes.
    final isValidStarting = widget.isSoccer
        ? _isValidStartingXI(_starting)
        : _hasValidBaseballStartingLineup(_starting);
    if (!isValidStarting) {
      if (mounted) {
        setState(() {
          _starting = prevStarting;
          _bench = prevBench;
        });
      } else {
        _starting = prevStarting;
        _bench = prevBench;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isSoccer
                ? '이 교체는 허용되지 않는 포메이션이 됩니다. 다른 선수로 교체해 주세요.'
                : '이 교체는 허용되지 않는 야구 포지션 구성이 됩니다. 같은 포지션 선수로 교체해 주세요.',
          ),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (!mounted) return;
    setState(() {
      _normalizeLeadershipSelection(
        preferredCaptainName: _captainName,
        preferredViceCaptainName: _viceCaptainName,
        preferredCaptainPlayerId: _captainPlayerId,
        preferredViceCaptainPlayerId: _viceCaptainPlayerId,
      );
      _rosterDirty = _computeRosterDirty();
    });
    // 스왑 결과를 캐시에 반영해서 화면 재진입해도 유지
    _persistMyRosterToCache();
    _applyStartingToLineup();
  }

  void _toggleMyPageOverlay() {
    _myPageOpen.value = !_myPageOpen.value;
  }

  void _closeMyPageOverlay() {
    if (_myPageOpen.value) {
      _myPageOpen.value = false;
    }
  }

  final GlobalKey<_LeagueItSubAppBarState> _appBarKey =
      GlobalKey<_LeagueItSubAppBarState>();
  final GlobalKey _matchDetailHeaderShowcaseKey = GlobalKey();
  final GlobalKey _matchDetailMatchupTabShowcaseKey = GlobalKey();
  final GlobalKey _matchDetailRosterTabShowcaseKey = GlobalKey();
  final GlobalKey _matchDetailPlayersTabShowcaseKey = GlobalKey();
  final GlobalKey _matchDetailLeagueTabShowcaseKey = GlobalKey();
  final ValueNotifier<bool> _myPageOpen = ValueNotifier<bool>(false);
  Timer? _matchDetailCoachRetryTimer;
  _MatchSection? _matchDetailCoachRestoreSection;
  bool _isMatchDetailCoachShowcaseActive = false;
  bool _isResolvingFantasyDraft = false;
  late _MatchSection _section;
  _LineupData? _lineup;
  List<_PlayerSlot> _allPlayers = const [];
  String _playerSearch = '';
  late final TextEditingController _playerSearchController;
  Timer? _playerSearchDebounce;
  bool _showPlayerFilters = false;
  bool _showOnlyFreeAgents = false;
  bool _sortPlayersByAptsDesc = false;
  _PlayerPositionFilter _playerPositionFilter = _PlayerPositionFilter.all;
  Future<Map<String, double>>? _profileAptsFuture;
  String _profileAptsFutureKey = '';
  int _playersVisibleCount = _initialPlayersVisibleCount;
  int? _selectedLeagueRound;
  _FantasyMatchupView? _fantasyMatchup;
  _FantasyTeamState? _fantasyMyTeam;
  _JoinedDraft? _resolvedFantasyDraft;
  List<_FantasyWeeklyLeaderSection> _kLeagueWeeklyLeaderSections = const [];
  List<_FantasyWeeklyLeaderSection> _kboWeeklyLeaderSections = const [];
  List<int> _kLeagueWeeklyRounds = const [];
  Map<int, int> _fantasyRoundByKLeagueRound = const {};
  int? _currentKLeagueWeeklyRound;
  Future<void>? _primeKLeagueWeeklyRoundsFuture;
  String _primeKLeagueWeeklyRoundsLeagueId = '';
  Future<void>? _primeKboWeeklyRoundsFuture;
  bool _primeKboWeeklyRoundsInFlightForceRefresh = false;
  bool _pendingForcedKboWeeklyRefresh = false;
  bool _hasPendingKboWeeklyLeaderRefresh = false;
  Future<void>? _primeKboStandingsHistoryFuture;
  String _primeKboStandingsHistoryKey = '';
  bool _isPrimingKLeagueWeeklyRounds = false;
  bool _isPrimingKboWeeklyRounds = false;
  DateTime? _lastKboLeagueRefreshAt;
  Map<String, double> _fantasyProjectedScores = const <String, double>{};
  Map<
    String,
    ({double opportunityFactor, int confirmedStarts, int completedStarts})
  >
  _fantasyPitcherWeeklyProjectionContexts =
      const <
        String,
        ({double opportunityFactor, int confirmedStarts, int completedStarts})
      >{};
  Future<void>? _fantasyProjectedScoresFuture;
  String _fantasyProjectedScoresKey = '';
  String _fantasyProjectedScoresFreshKey = '';
  String _fantasyPitcherWeeklyProjectionContextsKey = '';
  Future<void>? _visibleKboRoundPointsFuture;
  String _visibleKboRoundPointsFutureKey = '';
  String _visibleKboRoundPointsLoadedKey = '';
  _FantasyRosterLockState? _cachedRosterLockStateValue;
  String _cachedRosterLockStateKey = '';
  _JoinedDraft? get _fantasyDraft => _resolvedFantasyDraft;
  static const Duration _kboLeagueRefreshCooldown = Duration(seconds: 45);
  static const Duration _kboWeeklyLiveRefreshCooldown = Duration(seconds: 12);
  static const Duration _rosterLockStateCacheWindow = Duration(seconds: 5);

  String get _matchDetailCoachStorageKey {
    final sport = widget.isSoccer ? 'soccer' : 'baseball';
    return 'match_detail.coachmarks.$sport.v4';
  }

  List<GlobalKey> get _matchDetailCoachKeys => <GlobalKey>[
    _matchDetailHeaderShowcaseKey,
    _matchDetailMatchupTabShowcaseKey,
    _matchDetailRosterTabShowcaseKey,
    _matchDetailPlayersTabShowcaseKey,
    _matchDetailLeagueTabShowcaseKey,
  ];

  _MatchSection? _matchDetailSectionForCoachKey(GlobalKey key) {
    if (key == _matchDetailMatchupTabShowcaseKey) {
      return _MatchSection.matchup;
    }
    if (key == _matchDetailRosterTabShowcaseKey) {
      return _MatchSection.roster;
    }
    if (key == _matchDetailPlayersTabShowcaseKey) {
      return _MatchSection.players;
    }
    if (key == _matchDetailLeagueTabShowcaseKey) {
      return _MatchSection.league;
    }
    return null;
  }

  void _handleMatchDetailCoachMarkStart(int? _, GlobalKey key) {
    if (!mounted || !_isMatchDetailCoachShowcaseActive) return;
    final targetSection = _matchDetailSectionForCoachKey(key);
    if (targetSection == null || _section == targetSection) return;
    unawaited(_setSection(targetSection));
  }

  void _handleMatchDetailCoachMarkDismiss(GlobalKey? _) {
    _restoreMatchDetailCoachSectionIfNeeded();
  }

  void _detachMatchDetailCoachCallbacks() {
    try {
      final showcase = ShowcaseView.get();
      showcase.removeOnStartCallback(_handleMatchDetailCoachMarkStart);
      showcase.removeOnFinishCallback(_restoreMatchDetailCoachSectionIfNeeded);
      showcase.removeOnDismissCallback(_handleMatchDetailCoachMarkDismiss);
    } catch (_) {}
  }

  void _attachMatchDetailCoachCallbacks() {
    _detachMatchDetailCoachCallbacks();
    final showcase = ShowcaseView.get();
    showcase.addOnStartCallback(_handleMatchDetailCoachMarkStart);
    showcase.addOnFinishCallback(_restoreMatchDetailCoachSectionIfNeeded);
    showcase.addOnDismissCallback(_handleMatchDetailCoachMarkDismiss);
  }

  void _restoreMatchDetailCoachSectionIfNeeded() {
    if (!mounted || !_isMatchDetailCoachShowcaseActive) return;
    final restoreSection = _matchDetailCoachRestoreSection;
    _isMatchDetailCoachShowcaseActive = false;
    _matchDetailCoachRestoreSection = null;
    _detachMatchDetailCoachCallbacks();
    if (restoreSection == null || _section == restoreSection) return;
    unawaited(_setSection(restoreSection));
  }

  Widget _buildMatchDetailCoachMark({
    required GlobalKey showcaseKey,
    required String title,
    required String description,
    required Widget child,
    BorderRadius? targetBorderRadius,
    EdgeInsets targetPadding = const EdgeInsets.all(6),
    TooltipPosition? tooltipPosition,
    bool enableAutoScroll = false,
    double scrollAlignment = 0.5,
    Widget? supplementalContent,
  }) {
    return _buildLeagueItCoachMark(
      context: context,
      showcaseKey: showcaseKey,
      title: title,
      description: description,
      targetBorderRadius: targetBorderRadius,
      targetPadding: targetPadding,
      tooltipPosition: tooltipPosition,
      enableAutoScroll: enableAutoScroll,
      scrollAlignment: scrollAlignment,
      supplementalContent: supplementalContent,
      child: child,
    );
  }

  void _scheduleMatchDetailCoachMarks({bool force = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_maybeStartMatchDetailCoachMarks(force: force));
    });
  }

  void _retryMatchDetailCoachMarks({bool force = false}) {
    _matchDetailCoachRetryTimer?.cancel();
    _matchDetailCoachRetryTimer = Timer(const Duration(milliseconds: 320), () {
      if (!mounted) return;
      unawaited(_maybeStartMatchDetailCoachMarks(force: force));
    });
  }

  Future<void> _maybeStartMatchDetailCoachMarks({bool force = false}) async {
    if (!mounted) {
      return;
    }
    if (_fantasyDraft == null) {
      return;
    }
    if (_myPageOpen.value) {
      _retryMatchDetailCoachMarks(force: force);
      return;
    }

    if (!force) {
      final seen = await _readLocalStateCache(_matchDetailCoachStorageKey);
      if (seen == '1') return;
    }
    if (!mounted) return;

    try {
      final showcase = ShowcaseView.get();
      final allTargetsReady = _matchDetailCoachKeys.every(
        showcase.isTargetRendered,
      );
      if (!allTargetsReady) {
        _retryMatchDetailCoachMarks(force: force);
        return;
      }
      if (showcase.isShowcaseRunning) return;
      _matchDetailCoachRestoreSection = _section;
      _isMatchDetailCoachShowcaseActive = true;
      _attachMatchDetailCoachCallbacks();
      await _writeLocalStateCache(_matchDetailCoachStorageKey, '1');
      if (!mounted) return;
      showcase.startShowCase(
        _matchDetailCoachKeys,
        delay: const Duration(milliseconds: 240),
      );
    } catch (error, stackTrace) {
      _isMatchDetailCoachShowcaseActive = false;
      _matchDetailCoachRestoreSection = null;
      _detachMatchDetailCoachCallbacks();
      debugPrint('MatchDetail coach mark start failed: $error');
      debugPrint('$stackTrace');
      _retryMatchDetailCoachMarks(force: force);
    }
  }

  void _replayMatchDetailCoachMarks() {
    if (!mounted) return;
    if (_fantasyDraft == null) return;
    _matchDetailCoachRetryTimer?.cancel();
    try {
      final showcase = ShowcaseView.get();
      if (showcase.isShowcaseRunning) {
        showcase.dismiss();
      }
    } catch (_) {}
    _isMatchDetailCoachShowcaseActive = false;
    _matchDetailCoachRestoreSection = null;
    _detachMatchDetailCoachCallbacks();
    _closeMyPageOverlay();
    _scheduleMatchDetailCoachMarks(force: true);
  }

  Widget _wrapMatchDetailHelpButton(BuildContext context, Widget child) {
    return child;
  }

  int? _preferredFantasyRoundForDraft(_JoinedDraft draft) {
    final preferred = widget.preferredFantasyRound;
    if (preferred == null || preferred <= 0) return null;
    return min(max(1, preferred), max(1, draft.roundCount));
  }

  int _effectiveFantasyRoundForDraft(_JoinedDraft draft, {DateTime? now}) {
    return _preferredFantasyRoundForDraft(draft) ??
        _currentFantasyRoundAt(draft, now ?? DateTime.now());
  }

  int _effectiveKboWeeklyLeaderRoundForDraft(
    _JoinedDraft draft, {
    DateTime? now,
  }) {
    final fantasyRound = _effectiveFantasyRoundForDraft(draft, now: now);
    return min(
      _kboWeeklyLeaderDisplayTotalRounds,
      max(1, _mappedKboRoundForFantasyRound(draft, fantasyRound)),
    );
  }

  List<_FantasyTeamState> _projectionSourceTeamsForDraftRound(
    _JoinedDraft draft, {
    required int fantasyRound,
  }) {
    final matchup = _currentFantasyMatchupForDraft(
      draft,
      forcedRound: fantasyRound,
    );
    final ordered = <_FantasyTeamState>[];
    final seen = <String>{};

    void addTeam(_FantasyTeamState? team) {
      if (team == null) return;
      final key = _fantasyTeamIdentity(uid: team.uid, teamName: team.teamName);
      if (!seen.add(key)) return;
      ordered.add(team);
    }

    if (matchup != null) {
      addTeam(matchup.myTeam);
      addTeam(matchup.opponent);
    }
    if (ordered.isNotEmpty) {
      return ordered;
    }
    for (final team in draft.fantasyTeams) {
      addTeam(team);
    }
    return ordered;
  }

  _FantasyMatchupView? _selectedFantasyMatchupForDraft(_JoinedDraft draft) {
    return _currentFantasyMatchupForDraft(
      draft,
      forcedRound: _preferredFantasyRoundForDraft(draft),
    );
  }

  void _handlePlayerSearchChanged(String text) {
    _playerSearchDebounce?.cancel();
    _playerSearchDebounce = Timer(const Duration(milliseconds: 180), () {
      if (!mounted) return;
      final next = text.trim();
      if (_playerSearch == next) return;
      setState(() {
        _playerSearch = next;
        _playersVisibleCount = _initialPlayersVisibleCount;
      });
    });
  }

  void _primeProfileAptsIfNeeded({
    List<_PlayerSlot>? players,
    bool rebuild = false,
    bool allowKboHistoryFetch = true,
  }) {
    final targetPlayers = players ?? _allPlayers;
    if (targetPlayers.isEmpty) return;
    final key =
        '${widget.isSoccer ? 'soccer' : 'kbo'}|${_profileAptsKeyFor(targetPlayers)}|hist:${allowKboHistoryFetch ? 1 : 0}';
    if (_profileAptsFuture != null && _profileAptsFutureKey == key) return;

    final future = _loadProfileAptsForSlots(
      targetPlayers,
      isSoccer: widget.isSoccer,
      allowKboHistoryFetch: allowKboHistoryFetch,
    );
    if (!rebuild) {
      _profileAptsFutureKey = key;
      _profileAptsFuture = future;
      return;
    }
    if (!mounted) return;
    setState(() {
      _profileAptsFutureKey = key;
      _profileAptsFuture = future;
    });
  }

  void _primePlayersAptsIfNeeded() {
    if (_section != _MatchSection.players) return;
    _primeProfileAptsIfNeeded(
      players: _allPlayers,
      rebuild: true,
      allowKboHistoryFetch: false,
    );
  }

  bool get _shouldPrimeMatchupProjectedScores =>
      _section == _MatchSection.matchup || _section == _MatchSection.roster;

  void _applyPersistedFantasyProjectedScoresIfReady(
    _JoinedDraft draft, {
    bool rebuild = false,
  }) {
    if (draft.isSoccer || !_shouldPrimeMatchupProjectedScores) return;
    if (!_didHydratePersistedFantasyProjectedScoresCache) return;
    _applyPersistedFantasyProjectedScoresEntry(draft, rebuild: rebuild);
  }

  Future<void> _warmProjectedScoresCache() async {
    await _restorePersistedFantasyProjectedScoresCache();
    if (!mounted) return;
    final draft = _fantasyDraft;
    if (draft == null) return;
    _applyPersistedFantasyProjectedScoresIfReady(draft, rebuild: true);
  }

  Future<void> _warmProfileAptsCaches() async {
    await _restorePersistedKLeaguePlayerAptsCache();
    await _restorePersistedKboPlayerAptsCache();
    await _restorePersistedKLeaguePlayerRoundPointsCache();
    if (!mounted) return;
    final draft = _fantasyDraft;
    if (draft != null && _shouldPrimeMatchupProjectedScores) {
      _applyPersistedFantasyProjectedScoresIfReady(draft, rebuild: true);
      unawaited(_ensureFantasyProjectedScores(draft));
    }
    if (_section == _MatchSection.league && _allPlayers.isNotEmpty) {
      _primeProfileAptsIfNeeded();
    }
    if (_section == _MatchSection.players ||
        _section == _MatchSection.league ||
        _section == _MatchSection.matchup ||
        _section == _MatchSection.roster) {
      setState(() {});
    }
  }

  void _seedFantasyModeForFirstPaint(_JoinedDraft draft) {
    final normalizedDraft = _normalizeJoinedDraftFantasyParticipants(draft);
    final previousLeagueId = _resolvedFantasyDraft?.leagueId;
    _resolvedFantasyDraft = normalizedDraft;
    if (previousLeagueId != normalizedDraft.leagueId) {
      _kLeagueWeeklyLeaderSections = const [];
      _kLeagueWeeklyRounds = const [];
      _fantasyRoundByKLeagueRound = const {};
      _currentKLeagueWeeklyRound = null;
      _isPrimingKLeagueWeeklyRounds = false;
    }

    final nextMatchup = _selectedFantasyMatchupForDraft(normalizedDraft);
    _fantasyMatchup = nextMatchup;
    _fantasyMyTeam =
        nextMatchup?.myTeam ??
        (normalizedDraft.fantasyTeams.isEmpty
            ? null
            : normalizedDraft.fantasyTeams.first);
    _starting =
        _fantasyMyTeam?.starting
            .map((player) => player.toPlayerSlot())
            .toList() ??
        [];
    _bench =
        _fantasyMyTeam?.bench.map((player) => player.toPlayerSlot()).toList() ??
        [];
    _lineup = normalizedDraft.isSoccer && nextMatchup != null
        ? _buildFantasySoccerLineup(nextMatchup)
        : null;
    _allPlayers = _buildFantasyAllPlayers(normalizedDraft);
    _rebuildFantasyOwnershipCacheFor(
      draft: normalizedDraft,
      allPlayers: _allPlayers,
    );
    _normalizeLeadershipSelection(
      preferredCaptainName: _fantasyMyTeam?.captainName,
      preferredViceCaptainName: _fantasyMyTeam?.viceCaptainName,
      preferredCaptainPlayerId: _fantasyMyTeam?.captainPlayerId,
      preferredViceCaptainPlayerId: _fantasyMyTeam?.viceCaptainPlayerId,
    );
    _captureSavedRosterState();
  }

  void _scheduleInitialMatchDetailBootstrap({_JoinedDraft? readyDraft}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_primeRosterLockData());
      unawaited(_restoreFantasyNotifications());
      unawaited(_syncFantasyNotifications());
      if (!widget.isSoccer &&
          (_section == _MatchSection.matchup ||
              _section == _MatchSection.roster)) {
        unawaited(_refreshVisibleKboRoundPoints());
      }
      if (!widget.isSoccer) {
        unawaited(_restoreCachedKboWeeklyLeaderSections());
        unawaited(
          _restorePersistedKboVisibleTeamScoresCache().then((_) {
            _reapplyPersistedKboVisibleMatchupScores();
          }),
        );
      }
      unawaited(_warmProjectedScoresCache());
      unawaited(_warmProfileAptsCaches());
      if (readyDraft != null) {
        _applyFantasyDraft(readyDraft);
        if (widget.isSoccer) {
          unawaited(
            _refreshFantasySoccerScoresAndRebuild(
              includeHistory:
                  _section == _MatchSection.league &&
                  _needsHistoricalSoccerScoreWarmup(readyDraft),
            ),
          );
        }
        return;
      }
      unawaited(_resolveFantasyDraft());
    });
  }

  void _maybeExpandPlayersVisibleCount() {
    if (_section != _MatchSection.players) return;
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.extentAfter > 720) return;
    setState(() {
      _playersVisibleCount += _playersVisiblePageSize;
    });
  }

  String _profileAptsKeyFor(List<_PlayerSlot> players) {
    var hash = 17;
    for (final player in players) {
      hash = 0x1fffffff & (hash * 31 + _playerSlotIdentity(player).hashCode);
    }
    return '${players.length}|$hash';
  }

  List<_PlayerSlot> _filteredPlayersForPlayersSection() {
    final q = _playerSearch.trim().toLowerCase();
    final filtered =
        _allPlayers
            .where((player) {
              if (_showOnlyFreeAgents &&
                  _ownerForSlot(player) != PlayerOwnership.freeAgent) {
                return false;
              }
              if (!_playerMatchesPositionFilter(
                player,
                isSoccer: widget.isSoccer,
                filter: _playerPositionFilter,
              )) {
                return false;
              }
              return _playerMatchesQuery(
                player,
                normalizedQuery: q,
                isSoccer: widget.isSoccer,
              );
            })
            .toList(growable: false)
          ..sort(
            (left, right) => _comparePlayersByDisplayOrder(
              left,
              right,
              isSoccer: widget.isSoccer,
            ),
          );
    return filtered;
  }

  ({
    List<_PlayerSlot> filteredPlayers,
    Future<Map<String, double>> profileAptsFuture,
  })
  _playersSectionBundle() {
    final filteredPlayers = _filteredPlayersForPlayersSection();
    final future = _allPlayers.isEmpty
        ? Future.value(const <String, double>{})
        : _ensureProfileAptsFuture(
            _allPlayers,
            allowKboHistoryFetch: _sortPlayersByAptsDesc,
          );
    return (filteredPlayers: filteredPlayers, profileAptsFuture: future);
  }

  Future<Map<String, double>> _ensureProfileAptsFuture(
    List<_PlayerSlot> players, {
    bool allowKboHistoryFetch = true,
  }) {
    final key =
        '${widget.isSoccer ? 'soccer' : 'kbo'}|${_profileAptsKeyFor(players)}|hist:${allowKboHistoryFetch ? 1 : 0}';
    if (_profileAptsFuture != null && _profileAptsFutureKey == key) {
      return _profileAptsFuture!;
    }
    _profileAptsFutureKey = key;
    _profileAptsFuture = _loadProfileAptsForSlots(
      players,
      isSoccer: widget.isSoccer,
      allowKboHistoryFetch: allowKboHistoryFetch,
    );
    return _profileAptsFuture!;
  }

  Future<List<_FantasyWeeklyLeaderSection>> _loadKboWeeklyLeaderSections(
    List<_PlayerSlot> players, {
    bool forceRefresh = false,
  }) async {
    final unique = <String, _PlayerSlot>{};
    for (final player in players) {
      unique[_playerSlotIdentity(player)] = player;
    }
    final allPlayers = unique.values.toList();
    final playersByClubAndName = <String, List<_PlayerSlot>>{};
    for (final player in allPlayers) {
      final club = _normalizeKboDraftClub(player.club);
      final name = player.name.trim();
      if (club.isEmpty || name.isEmpty) continue;
      playersByClubAndName.putIfAbsent('$club|$name', () => <_PlayerSlot>[]);
      playersByClubAndName['$club|$name']!.add(player);
    }

    final now = DateTime.now();
    final draft = _fantasyDraft;
    final leagueData = await _loadCachedKboLeagueData(
      forceRefresh: forceRefresh,
    );
    final rawMatches = _fixtureAsList(leagueData['matches']);
    final currentRound = draft == null
        ? min(
            _kboWeeklyLeaderDisplayTotalRounds,
            max(1, _currentKboRoundAt(now)),
          )
        : _effectiveKboWeeklyLeaderRoundForDraft(draft, now: now);
    final latestCompletedRound = currentRound;
    final relevantMatches =
        <({int round, int matchId, String homeClub, String awayClub})>[];
    final seenMatchIds = <int>{};
    for (final raw in rawMatches) {
      final match = _fixtureAsMap(raw);
      final matchDate = DateTime.tryParse('${match['date'] ?? ''}');
      if (matchDate == null) continue;
      final round = _kboFantasyRoundForMatchDate(matchDate);
      if (round <= 0 || round > currentRound) continue;
      if (!_kboMatchMapHasStarted(match, now: now)) continue;
      final matchId = _readNullableInt(match['id']);
      if (matchId == null || matchId <= 0 || !seenMatchIds.add(matchId)) {
        continue;
      }
      relevantMatches.add((
        round: round,
        matchId: matchId,
        homeClub: _normalizeKboDraftClub('${match['home'] ?? ''}'),
        awayClub: _normalizeKboDraftClub('${match['away'] ?? ''}'),
      ));
    }

    final roundAccumulators =
        <int, Map<String, _KLeaguePlayerRoundAccumulator>>{
          for (int round = 1; round <= latestCompletedRound; round++)
            round: <String, _KLeaguePlayerRoundAccumulator>{},
        };
    const batchSize = 5;
    for (var start = 0; start < relevantMatches.length; start += batchSize) {
      final end = min(start + batchSize, relevantMatches.length);
      final batch = relevantMatches.sublist(start, end);
      final resolved = await Future.wait(
        batch.map((matchInfo) async {
          try {
            final detail = await _loadCachedKboMatchDetail(
              matchInfo.matchId,
              forceRefresh: matchInfo.round == currentRound,
              fantasyRound: matchInfo.round,
            );
            return (matchInfo: matchInfo, detail: detail);
          } catch (error, stackTrace) {
            debugPrint(
              'KBO weekly leader match detail load failed '
              '(round=${matchInfo.round}, match=${matchInfo.matchId}): $error',
            );
            debugPrint('$stackTrace');
            return null;
          }
        }),
      );
      for (final entry
          in resolved
              .whereType<
                ({
                  ({int round, int matchId, String homeClub, String awayClub})
                  matchInfo,
                  Map<String, dynamic> detail,
                })
              >()) {
        final playerStats = _fixtureAsList(entry.detail['playerStats']);
        final matchMap = _fixtureAsMap(entry.detail['match']);
        final round = entry.matchInfo.round;
        final accumulators = roundAccumulators[round];
        if (accumulators == null) continue;
        for (final rawStat in playerStats) {
          final stat = _fixtureAsMap(rawStat);
          final name = '${stat['name'] ?? ''}'.trim();
          final club = _normalizeKboDraftClub('${stat['team'] ?? ''}');
          if (name.isEmpty || club.isEmpty) continue;
          final candidates = playersByClubAndName['$club|$name'];
          if (candidates == null || candidates.isEmpty) continue;
          _PlayerSlot? matched;
          for (final candidate in candidates) {
            if (_kboPlayerStatMatchesProfile(
              stat,
              name,
              meta: (
                position: candidate.position,
                club: _normalizeKboDraftClub(candidate.club),
                number: candidate.number,
              ),
            )) {
              matched = candidate;
              break;
            }
          }
          matched ??= candidates.length == 1 ? candidates.first : null;
          if (matched == null) continue;
          final fantasy = _fixtureAsMap(stat['fantasy']);
          final details = _fixtureAsList(fantasy['details'])
              .map((raw) => _playerRoundPointDetailFromJson(_fixtureAsMap(raw)))
              .whereType<_PlayerRoundPointDetail>()
              .toList();
          final points = double.parse(
            (((fantasy['points'] as num?)?.toDouble() ?? 0.0)).toStringAsFixed(
              2,
            ),
          );
          final started = stat['started'] == true;
          final appeared =
              (_kboMatchMapHasStarted(matchMap, now: now) && started) ||
              details.isNotEmpty ||
              points != 0.0;
          final opponentLabel = club == entry.matchInfo.homeClub
              ? entry.matchInfo.awayClub
              : entry.matchInfo.homeClub;
          final score = _KLeaguePlayerRoundAccumulator(
            round: round,
            basePoints: points,
            appeared: appeared,
            started: started,
            details: details,
            opponentLabel: opponentLabel,
          );
          final identity = _playerSlotIdentity(matched);
          accumulators[identity] =
              (accumulators[identity] ??
                      _KLeaguePlayerRoundAccumulator.empty(
                        round,
                        opponentLabel: opponentLabel,
                      ))
                  .merge(score);
        }
      }
    }

    List<_FantasyWeeklyLeaderEntry> leadersForRound(int round, int limit) {
      final accumulators = roundAccumulators[round];
      if (accumulators == null || accumulators.isEmpty) {
        return const <_FantasyWeeklyLeaderEntry>[];
      }
      final leaders = <_FantasyWeeklyLeaderEntry>[];
      for (final entry in accumulators.entries) {
        final player = unique[entry.key];
        if (player == null) continue;
        final points = entry.value.basePoints;
        if (points <= 0) continue;
        leaders.add(
          _FantasyWeeklyLeaderEntry(
            name: player.name,
            position: player.position,
            club: _normalizeKboDraftClub(player.club),
            number: player.number,
            points: points,
            ownership: _ownerForSlot(player),
          ),
        );
      }
      leaders.sort((a, b) {
        final pointCompare = b.points.compareTo(a.points);
        if (pointCompare != 0) return pointCompare;
        final clubCompare = a.club.compareTo(b.club);
        if (clubCompare != 0) return clubCompare;
        return a.name.compareTo(b.name);
      });
      return leaders.take(limit).toList();
    }

    final sections = <_FantasyWeeklyLeaderSection>[];

    if (currentRound > 0) {
      sections.add(
        _FantasyWeeklyLeaderSection(
          round: currentRound,
          leaders: leadersForRound(currentRound, 30),
        ),
      );
    }

    for (int round = latestCompletedRound; round >= 1; round--) {
      if (round == currentRound) continue;
      sections.add(
        _FantasyWeeklyLeaderSection(
          round: round,
          leaders: leadersForRound(round, 3),
        ),
      );
    }

    return sections;
  }

  List<_FantasyWeeklyLeaderEntry> _kboWeeklyLeadersForRound(
    List<_PlayerSlot> players, {
    required int round,
    required int limit,
  }) {
    final leaders = <_FantasyWeeklyLeaderEntry>[];
    for (final player in players) {
      final roundPoints = _cachedKboRoundPointsForPlayer(
        playerName: player.name,
        club: _normalizeKboDraftClub(player.club),
        preferredNumber: player.number,
        preferredPosition: player.position,
      );
      if (roundPoints == null) continue;
      _PlayerRoundPoints? target;
      for (final entry in roundPoints) {
        if (entry.round == round) {
          target = entry;
          break;
        }
      }
      final points = target?.displayedPoints ?? 0.0;
      if (points <= 0) continue;
      leaders.add(
        _FantasyWeeklyLeaderEntry(
          name: player.name,
          position: player.position,
          club: _slotClub(player),
          number: player.number,
          points: points,
          ownership: _ownerForSlot(player),
        ),
      );
    }
    leaders.sort((a, b) {
      final pointCompare = b.points.compareTo(a.points);
      if (pointCompare != 0) return pointCompare;
      final clubCompare = a.club.compareTo(b.club);
      if (clubCompare != 0) return clubCompare;
      return a.name.compareTo(b.name);
    });
    return leaders.take(limit).toList();
  }

  Widget _buildSectionTabs() {
    return Row(
      children: [
        buildTab(
          'Match up',
          _MatchSection.matchup,
          showcaseKey: _matchDetailMatchupTabShowcaseKey,
          coachTitle: 'Match up',
          coachDescription:
              '현재 매치업 스코어, 예상 Fpts, 승리 확률, 양 팀의 선발&교체 명단을 확인 할 수 있습니다.',
        ),
        buildTab(
          'Roster',
          _MatchSection.roster,
          showcaseKey: _matchDetailRosterTabShowcaseKey,
          coachTitle: 'Roster',
          coachDescription: '내 로스터를 관리하고 스타팅 라인업을 정할 수 있습니다.',
        ),
        buildTab(
          'Players',
          _MatchSection.players,
          showcaseKey: _matchDetailPlayersTabShowcaseKey,
          coachTitle: 'Players',
          coachDescription:
              '전체 선수 검색, 선수 영입, 트레이드 요청처럼 선수 관련 작업을 진행 할 수 있습니다.',
        ),
        buildTab(
          'League',
          _MatchSection.league,
          showcaseKey: _matchDetailLeagueTabShowcaseKey,
          coachTitle: 'League',
          coachDescription:
              '리그 순위, 일정, 파워랭킹, 이주의 선수처럼 리그 전체 흐름을 이 탭에서 확인 할 수 있습니다.',
          last: true,
        ),
      ],
    );
  }

  Widget buildTab(
    String label,
    _MatchSection section, {
    required GlobalKey showcaseKey,
    required String coachTitle,
    required String coachDescription,
    bool last = false,
  }) {
    final chip = _CategoryChip(
      label: label,
      active: _section == section,
      onTap: () {
        unawaited(_setSection(section));
      },
    );
    return Expanded(
      child: Padding(
        padding: EdgeInsets.only(right: last ? 0 : 8),
        child: _buildMatchDetailCoachMark(
          showcaseKey: showcaseKey,
          title: coachTitle,
          description: coachDescription,
          targetBorderRadius: BorderRadius.circular(18),
          tooltipPosition: TooltipPosition.bottom,
          enableAutoScroll: true,
          scrollAlignment: 0.16,
          child: chip,
        ),
      ),
    );
  }

  Widget _buildFantasyLeagueHeader(_JoinedDraft draft) {
    final palette = _leagueItSurfacePalette(context);
    final isSoccer = draft.isSoccer;
    final accent = isSoccer ? const Color(0xFF1F6B38) : const Color(0xFF174EA6);
    final gradient = palette.isDark
        ? (isSoccer
              ? const [Color(0xFF18221B), Color(0xFF241C15)]
              : const [Color(0xFF161E2A), Color(0xFF241D17)])
        : (isSoccer
              ? const [Color(0xFFE5F7D8), Color(0xFFFFF2D9)]
              : const [Color(0xFFE5F0FF), Color(0xFFFFF0E0)]);
    final icon = isSoccer ? Icons.sports_soccer : Icons.sports_baseball;
    final sportLabel = isSoccer ? 'K League' : 'KBO';

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: _buildMatchDetailCoachMark(
        showcaseKey: _matchDetailHeaderShowcaseKey,
        title: '리그 헤더',
        description:
            '현재 어떤 판타지리그에 속해있는지를 보여줍니다.',
        targetBorderRadius: BorderRadius.circular(28),
        targetPadding: const EdgeInsets.fromLTRB(6, 6, 6, 0),
        enableAutoScroll: true,
        scrollAlignment: 0.08,
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradient,
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: palette.cardBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: palette.isDark ? 0.28 : 0.07,
                ),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: palette.isDark
                              ? palette.tileSurface
                              : Colors.white.withValues(alpha: 0.84),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: accent.withValues(alpha: 0.14),
                          ),
                        ),
                        child: Icon(icon, color: accent, size: 26),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: palette.isDark
                                    ? accent.withValues(alpha: 0.22)
                                    : accent.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                sportLabel,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  color: accent,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              draft.leagueName.trim().isEmpty
                                  ? 'Fantasy League'
                                  : draft.leagueName.trim(),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                height: 1.05,
                                color: palette.ink,
                                letterSpacing: -0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _matchSectionLabel(_MatchSection section) => switch (section) {
    _MatchSection.matchup => 'Match up',
    _MatchSection.roster => 'Roster',
    _MatchSection.players => 'Players',
    _MatchSection.league => 'League',
  };

  Future<bool> _confirmLeaveWithUnsavedRosterChanges({
    required String destinationLabel,
  }) async {
    if (!_rosterDirty) return true;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text(
            '저장되지 않은 변경사항',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          content: Text(
            '저장하지 않은 로스터 변경사항이 있습니다.\n저장하지 않고 $destinationLabel(으)로 이동할까요?',
            style: const TextStyle(fontWeight: FontWeight.w700, height: 1.45),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('계속 편집'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE85C53),
                foregroundColor: Colors.white,
              ),
              child: const Text('이동'),
            ),
          ],
        );
      },
    );
    return confirmed ?? false;
  }

  Future<bool> _handlePendingRosterExit() {
    return _confirmLeaveWithUnsavedRosterChanges(destinationLabel: '이전 화면');
  }

  Future<void> _handleRoutePopInvoked<T>(bool didPop, T? result) async {
    if (didPop || !_rosterDirty || _allowImmediateRoutePop) return;
    if (!await _handlePendingRosterExit()) return;
    if (!mounted) return;
    _allowImmediateRoutePop = true;
    Navigator.of(context).pop(result);
  }

  Future<void> _setSection(_MatchSection section) async {
    if (_section == section) return;
    if (_section == _MatchSection.roster &&
        !await _confirmLeaveWithUnsavedRosterChanges(
          destinationLabel: '${_matchSectionLabel(section)} 탭',
        )) {
      return;
    }
    if (section == _MatchSection.league) {
      _primeProfileAptsIfNeeded();
    }
    if (!mounted) return;
    setState(() {
      _section = section;
      if (section == _MatchSection.players) {
        _playersVisibleCount = _initialPlayersVisibleCount;
      }
    });
    final draft = _fantasyDraft;
    if (draft != null &&
        (section == _MatchSection.matchup || section == _MatchSection.roster)) {
      unawaited(_primePersistedFantasyProjectedScores(draft));
      unawaited(_ensureFantasyProjectedScores(draft));
    }
    if (section == _MatchSection.players) {
      _primePlayersAptsIfNeeded();
    }
    if (!widget.isSoccer && section == _MatchSection.matchup) {
      unawaited(_refreshVisibleKboRoundPoints(forceRefresh: true));
    }
    if (section != _MatchSection.league) return;
    if (draft == null) return;
    if (widget.isSoccer) {
      unawaited(_primeKLeagueWeeklyRounds(draft));
      unawaited(
        _refreshFantasySoccerScoresAndRebuild(
          includeHistory: _needsHistoricalSoccerScoreWarmup(draft),
        ),
      );
      return;
    }
    final shouldForceWeeklyRefresh = _hasPendingKboWeeklyLeaderRefresh;
    unawaited(_primeKboStandingsHistoryForDraft(draft));
    unawaited(
      _primeKboWeeklyRounds(
        forceRefresh: shouldForceWeeklyRefresh,
        bypassCooldown: shouldForceWeeklyRefresh,
      ),
    );
  }

  _JoinedDraft? _homeDraftForCurrentFantasyLeague() {
    final currentLeagueId =
        _resolvedFantasyDraft?.leagueId.trim() ??
        widget.draft?.leagueId.trim() ??
        '';
    final homeState = homeKey.currentState;
    if (homeState == null) return null;

    if (currentLeagueId.isNotEmpty) {
      for (final draft in homeState.joinedDrafts) {
        if (draft.leagueId == currentLeagueId &&
            draft.isSoccer == widget.isSoccer &&
            draft.fantasyReady) {
          return draft;
        }
      }
    }
    return null;
  }

  _JoinedDraft? _findReadyFantasyDraft() {
    final resolved = _resolvedFantasyDraft;
    if (resolved != null && resolved.fantasyReady) {
      return resolved;
    }

    final currentLeagueDraft = _homeDraftForCurrentFantasyLeague();
    if (currentLeagueDraft != null) {
      return currentLeagueDraft;
    }

    final homeState = homeKey.currentState;
    if (homeState != null) {
      final primary = homeState.fantasyDraftForSport(widget.isSoccer);
      if (primary != null && primary.fantasyReady) {
        return primary;
      }

      final candidates =
          homeState.joinedDrafts
              .where(
                (draft) =>
                    draft.isSoccer == widget.isSoccer && draft.fantasyReady,
              )
              .toList()
            ..sort((a, b) => a.when.compareTo(b.when));
      if (candidates.isNotEmpty) {
        return candidates.first;
      }
    }

    final direct = widget.draft;
    if (direct != null && direct.fantasyReady) {
      return direct;
    }
    return null;
  }

  _JoinedDraft? _findRecoverableFantasyDraft() {
    final homeState = homeKey.currentState;
    if (homeState == null) return null;
    final candidates =
        homeState.joinedDrafts
            .where((draft) => draft.isSoccer == widget.isSoccer)
            .toList()
          ..sort((a, b) => a.when.compareTo(b.when));
    for (final draft in candidates) {
      if (homeState._shouldRecoverFantasyLeague(draft)) {
        return draft;
      }
    }
    return null;
  }

  void _applyFantasyDraft(_JoinedDraft draft) {
    draft = _normalizeJoinedDraftFantasyParticipants(draft);
    final previousLeagueId = _resolvedFantasyDraft?.leagueId;
    _resolvedFantasyDraft = draft;
    if (previousLeagueId != draft.leagueId) {
      _kLeagueWeeklyLeaderSections = const [];
      _kLeagueWeeklyRounds = const [];
      _fantasyRoundByKLeagueRound = const {};
      _currentKLeagueWeeklyRound = null;
      _isPrimingKLeagueWeeklyRounds = false;
    }
    _initFantasyMode(draft);
    if (!draft.isSoccer) {
      unawaited(_hydrateActiveBaseballFantasyMetadata(draft));
      if (_section == _MatchSection.league) {
        final shouldForceWeeklyRefresh = _hasPendingKboWeeklyLeaderRefresh;
        unawaited(_primeKboStandingsHistoryForDraft(draft));
        unawaited(
          _primeKboWeeklyRounds(
            forceRefresh: shouldForceWeeklyRefresh,
            bypassCooldown: shouldForceWeeklyRefresh,
          ),
        );
      }
    }
    if (_section == _MatchSection.league &&
        (_kLeagueWeeklyLeaderSections.isEmpty ||
            previousLeagueId != draft.leagueId)) {
      unawaited(_primeKLeagueWeeklyRounds(draft));
    }
  }

  _JoinedDraft _draftWithCompletedKboStandingSnapshots(
    _JoinedDraft draft,
    int throughRound,
  ) {
    if (draft.isSoccer || throughRound <= 0) return draft;

    var changed = false;
    final updatedTeams = draft.fantasyTeams.map((team) {
      var teamChanged = false;
      final updatedStates = team.kboRoundScoreStates.map((state) {
        if (state.round <= 0 || state.round > throughRound) {
          return state;
        }
        final storedStarterIds = state.starterBaselines.keys.toList(
          growable: false,
        );
        final resolvedPlayers = _resolvedKboRoundStarterPlayers(team, state);
        final resolvedDoubledPlayerId =
            state.doubledPlayerId?.trim().isNotEmpty == true
            ? state.doubledPlayerId!.trim()
            : _effectiveCaptainDoublePlayerIdForKboTeam(
                team,
                draft: draft,
                round: state.round,
              );
        final canFreezeSnapshot =
            state.starterPlayers.isNotEmpty ||
            storedStarterIds.isEmpty ||
            resolvedPlayers.length == storedStarterIds.length;
        final computedSnapshot =
            state.unlockedScoreSnapshot ??
            (canFreezeSnapshot
                ? (state.bankedScore +
                      resolvedPlayers.fold<double>(0.0, (total, player) {
                        final playerIdentity = _fantasyTeamPlayerIdentity(
                          player,
                        );
                        final currentBase = _fantasyKboBasePlayerRoundScore(
                          player,
                          draft: draft,
                          round: state.round,
                        );
                        final current =
                            playerIdentity == resolvedDoubledPlayerId
                            ? currentBase * 2
                            : currentBase;
                        final baseline =
                            state.starterBaselines[playerIdentity] ?? 0.0;
                        return total + (current - baseline);
                      }))
                : null);

        final needsStarterBackfill =
            state.starterPlayers.isEmpty && resolvedPlayers.isNotEmpty;
        final needsCaptainBackfill =
            ((state.doubledPlayerId?.trim() ?? '').isEmpty) &&
            (resolvedDoubledPlayerId ?? '').isNotEmpty;
        final needsSnapshotBackfill =
            state.unlockedScoreSnapshot == null && computedSnapshot != null;
        if (!needsStarterBackfill &&
            !needsCaptainBackfill &&
            !needsSnapshotBackfill) {
          return state;
        }
        changed = true;
        teamChanged = true;
        return _KboFantasyRoundScoreState(
          round: state.round,
          bankedScore: state.bankedScore,
          starterBaselines: state.starterBaselines,
          starterPlayers: needsStarterBackfill
              ? resolvedPlayers
              : state.starterPlayers,
          doubledPlayerId: needsCaptainBackfill
              ? resolvedDoubledPlayerId
              : state.doubledPlayerId,
          updatedAt: state.updatedAt,
          unlockedScoreSnapshot: computedSnapshot,
          unlockedAt: state.unlockedAt,
        );
      }).toList();

      if (!teamChanged) return team;
      return _FantasyTeamState(
        uid: team.uid,
        teamName: team.teamName,
        roster: team.roster,
        starting: team.starting,
        bench: team.bench,
        captainName: team.captainName,
        viceCaptainName: team.viceCaptainName,
        captainPlayerId: team.captainPlayerId,
        viceCaptainPlayerId: team.viceCaptainPlayerId,
        kboRoundScoreStates: updatedStates,
      );
    }).toList();

    if (!changed) return draft;
    return _JoinedDraft(
      leagueId: draft.leagueId,
      leagueName: draft.leagueName,
      when: draft.when,
      isSoccer: draft.isSoccer,
      teamCount: draft.teamCount,
      roundCount: draft.roundCount,
      memberCount: draft.memberCount,
      inviteCode: draft.inviteCode,
      ownerId: draft.ownerId,
      draftOrder: draft.draftOrder,
      fantasyReady: draft.fantasyReady,
      fantasyTeams: updatedTeams,
      fantasySchedule: draft.fantasySchedule,
      draftBoard: draft.draftBoard,
    );
  }

  bool _hasCompletedKboStandingSnapshots(_JoinedDraft draft, int throughRound) {
    if (draft.isSoccer || throughRound <= 0) return true;
    final byName = {for (final team in draft.fantasyTeams) team.teamName: team};
    for (final matchup in draft.fantasySchedule) {
      if (matchup.round <= 0 || matchup.round > throughRound) continue;
      final homeTeam = byName[matchup.homeTeam];
      final awayTeam = byName[matchup.awayTeam];
      if (homeTeam == null || awayTeam == null) return false;
      final homeState = _kboRoundScoreStateForTeam(homeTeam, matchup.round);
      final awayState = _kboRoundScoreStateForTeam(awayTeam, matchup.round);
      if (homeState?.unlockedScoreSnapshot == null ||
          awayState?.unlockedScoreSnapshot == null) {
        return false;
      }
    }
    return true;
  }

  Future<void> _persistFantasyDraftSnapshot(_JoinedDraft draft) async {
    final homeState = homeKey.currentState;
    if (homeState == null || !homeState.mounted) return;
    homeState.setState(() {
      homeState._upsertJoinedDraft(draft);
      homeState._setPrimaryDraftFromJoinedDrafts();
    });
    await homeState._saveLocalState();
  }

  Future<void> _primeKboStandingsHistoryForDraft(
    _JoinedDraft draft, {
    bool forceRefresh = false,
  }) {
    if (draft.isSoccer) return Future.value();
    final completedRound = _completedKboFantasyRoundForStandings(
      draft,
      DateTime.now(),
    );
    if (completedRound <= 0) return Future.value();
    if (!forceRefresh &&
        _hasCompletedKboStandingSnapshots(draft, completedRound)) {
      return Future.value();
    }

    final cacheKey =
        '${draft.leagueId}|$completedRound|${forceRefresh ? 'force' : 'cached'}';
    final inFlight = _primeKboStandingsHistoryFuture;
    if (inFlight != null && _primeKboStandingsHistoryKey == cacheKey) {
      return inFlight;
    }

    final future =
        () async {
          final targetRounds = <int>{
            for (var round = 1; round <= completedRound; round++)
              _mappedKboRoundForFantasyRound(draft, round),
          }..removeWhere((round) => round <= 0);
          if (targetRounds.isEmpty) return;

          final uniquePlayers = <String, _FantasyTeamPlayer>{};
          for (final team in draft.fantasyTeams) {
            for (final player in [
              ...team.roster,
              ...team.starting,
              ...team.bench,
            ]) {
              uniquePlayers[_fantasyTeamPlayerIdentity(player)] = player;
            }
            for (final state in team.kboRoundScoreStates) {
              if (state.round <= 0 || state.round > completedRound) continue;
              for (final player in _resolvedKboRoundStarterPlayers(
                team,
                state,
              )) {
                uniquePlayers[_fantasyTeamPlayerIdentity(player)] = player;
              }
            }
          }

          const batchSize = 2;
          final values = uniquePlayers.values.toList(growable: false);
          for (var index = 0; index < values.length; index += batchSize) {
            final batch = values.skip(index).take(batchSize);
            await Future.wait(
              batch.map(
                (player) => _loadKboRoundPointsForPlayerShared(
                  playerName: player.name,
                  club: _normalizeKboDraftClub(player.club),
                  preferredNumber: player.number,
                  preferredPosition: player.position,
                  forceRefresh: forceRefresh,
                  targetRounds: targetRounds,
                  logFailures: false,
                ),
              ),
            );
          }

          final updatedDraft = _draftWithCompletedKboStandingSnapshots(
            draft,
            completedRound,
          );
          if (!mounted) return;
          if (_resolvedFantasyDraft?.leagueId != draft.leagueId) return;

          setState(() {
            if (!identical(updatedDraft, draft)) {
              _resolvedFantasyDraft = updatedDraft;
              _fantasyMatchup = _selectedFantasyMatchupForDraft(updatedDraft);
              _fantasyMyTeam = _myFantasyTeamForDraft(updatedDraft);
            }
          });
          if (!identical(updatedDraft, draft)) {
            await _persistFantasyDraftSnapshot(updatedDraft);
          }
        }().whenComplete(() {
          if (_primeKboStandingsHistoryKey == cacheKey) {
            _primeKboStandingsHistoryFuture = null;
          }
        });

    _primeKboStandingsHistoryKey = cacheKey;
    _primeKboStandingsHistoryFuture = future;
    return future;
  }

  List<_FantasyWeeklyLeaderSection> _mergeWeeklyLeaderSections({
    required int currentDisplayRound,
    _FantasyWeeklyLeaderSection? currentRoundSection,
    required Map<int, _FantasyWeeklyLeaderSection> cachedPreviousSections,
    required Map<int, _FantasyWeeklyLeaderSection> computedPreviousSections,
  }) {
    final merged = <_FantasyWeeklyLeaderSection>[];
    if (currentRoundSection != null) {
      merged.add(currentRoundSection);
    }
    for (int round = currentDisplayRound - 1; round >= 1; round--) {
      final section =
          computedPreviousSections[round] ?? cachedPreviousSections[round];
      if (section != null) {
        merged.add(section);
      }
    }
    return merged;
  }

  Future<void> _restoreCachedKLeagueWeeklyLeaderSections(
    _JoinedDraft draft,
  ) async {
    final storageKey = _kLeagueWeeklyLeaderSnapshotStorageKey(draft.leagueId);
    final raw = await _kLeagueWeeklyLeaderSnapshotStorage.read(key: storageKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final restored = _weeklyLeaderSectionsFromPayload(jsonDecode(raw));
      if (!mounted) return;
      if (_fantasyDraft?.leagueId != draft.leagueId) return;
      if (restored.isEmpty) return;
      final snapshotCache = _cachedKLeagueWeeklyLeaderSnapshots.putIfAbsent(
        draft.leagueId,
        () => <int, _FantasyWeeklyLeaderSection>{},
      );
      for (final section in restored) {
        snapshotCache[section.round] = section;
      }
      setState(() {
        final currentRoundSection = _kLeagueWeeklyLeaderSections.isEmpty
            ? null
            : _kLeagueWeeklyLeaderSections.firstWhere(
                (section) => section.round == _currentKLeagueWeeklyRound,
                orElse: () => const _FantasyWeeklyLeaderSection(
                  round: -1,
                  leaders: <_FantasyWeeklyLeaderEntry>[],
                ),
              );
        final hasCurrent =
            currentRoundSection != null && currentRoundSection.round > 0;
        _kLeagueWeeklyLeaderSections = [
          if (hasCurrent) currentRoundSection,
          ...restored.where(
            (section) => section.round != _currentKLeagueWeeklyRound,
          ),
        ];
      });
    } catch (_) {
      // Ignore invalid local snapshot payloads.
    }
  }

  Future<void> _restoreRemoteKLeagueWeeklyLeaderSections(
    _JoinedDraft draft,
  ) async {
    try {
      final payload = await LeagueService.instance
          .getKLeagueWeeklyLeaderSnapshots(draft.leagueId);
      final restored = _weeklyLeaderSectionsFromPayload(payload);
      if (!mounted) return;
      if (_fantasyDraft?.leagueId != draft.leagueId) return;
      if (restored.isEmpty) return;
      final snapshotCache = _cachedKLeagueWeeklyLeaderSnapshots.putIfAbsent(
        draft.leagueId,
        () => <int, _FantasyWeeklyLeaderSection>{},
      );
      for (final section in restored) {
        snapshotCache[section.round] = section;
      }
      await _persistCachedKLeagueWeeklyLeaderSections(draft, snapshotCache);
      setState(() {
        final currentRoundSection = _kLeagueWeeklyLeaderSections.isEmpty
            ? null
            : _kLeagueWeeklyLeaderSections.firstWhere(
                (section) => section.round == _currentKLeagueWeeklyRound,
                orElse: () => const _FantasyWeeklyLeaderSection(
                  round: -1,
                  leaders: <_FantasyWeeklyLeaderEntry>[],
                ),
              );
        final hasCurrent =
            currentRoundSection != null && currentRoundSection.round > 0;
        _kLeagueWeeklyLeaderSections = [
          if (hasCurrent) currentRoundSection,
          ...restored.where(
            (section) => section.round != _currentKLeagueWeeklyRound,
          ),
        ];
      });
    } catch (error, stackTrace) {
      debugPrint('restoreRemoteKLeagueWeeklyLeaderSections failed: $error');
      debugPrint('$stackTrace');
    }
  }

  Future<void> _persistCachedKLeagueWeeklyLeaderSections(
    _JoinedDraft draft,
    Map<int, _FantasyWeeklyLeaderSection> snapshots,
  ) async {
    final storageKey = _kLeagueWeeklyLeaderSnapshotStorageKey(draft.leagueId);
    final payload = snapshots.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));
    final encoded = jsonEncode([
      for (final entry in payload)
        {
          'round': entry.key,
          'leaders': [
            for (final leader in entry.value.leaders.take(3))
              _weeklyLeaderEntryToJson(leader),
          ],
        },
    ]);
    await _kLeagueWeeklyLeaderSnapshotStorage.write(
      key: storageKey,
      value: encoded,
    );
  }

  Future<void> _persistRemoteKLeagueWeeklyLeaderSections(
    _JoinedDraft draft,
    Map<int, _FantasyWeeklyLeaderSection> snapshots,
  ) async {
    final payload = snapshots.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));
    await LeagueService.instance.saveKLeagueWeeklyLeaderSnapshots(
      leagueId: draft.leagueId,
      snapshots: [
        for (final entry in payload)
          {
            'round': entry.key,
            'leaders': [
              for (final leader in entry.value.leaders.take(3))
                _weeklyLeaderEntryToJson(leader),
            ],
          },
      ],
    );
  }

  List<_FantasyWeeklyLeaderSection> _buildKboWeeklyLeaderSectionsFromCache() {
    final draft = _fantasyDraft;
    final currentRound = draft == null
        ? min(
            _kboWeeklyLeaderDisplayTotalRounds,
            max(1, _currentKboRoundAt(DateTime.now())),
          )
        : _effectiveKboWeeklyLeaderRoundForDraft(draft);
    _FantasyWeeklyLeaderSection withResolvedOwnership(
      _FantasyWeeklyLeaderSection section,
    ) {
      return _FantasyWeeklyLeaderSection(
        round: section.round,
        leaders: section.leaders.map((leader) {
          final ownership = _ownerForSlot(
            _PlayerSlot(
              name: leader.name,
              score: 0,
              position: leader.position,
              club: leader.club,
              number: leader.number,
            ),
          );
          return _FantasyWeeklyLeaderEntry(
            name: leader.name,
            position: leader.position,
            club: leader.club,
            number: leader.number,
            points: leader.points,
            ownership: ownership,
          );
        }).toList(),
      );
    }

    final sections = <_FantasyWeeklyLeaderSection>[];
    final current = _cachedKboWeeklyLeaderSnapshots[currentRound];
    sections.add(
      current != null
          ? withResolvedOwnership(current)
          : _FantasyWeeklyLeaderSection(
              round: currentRound,
              leaders: const <_FantasyWeeklyLeaderEntry>[],
            ),
    );
    for (int round = currentRound - 1; round >= 1; round--) {
      final section = _cachedKboWeeklyLeaderSnapshots[round];
      if (section != null) {
        sections.add(withResolvedOwnership(section));
      }
    }
    return sections;
  }

  Future<void> _restoreCachedKboWeeklyLeaderSections() async {
    final raw = await _kLeagueWeeklyLeaderSnapshotStorage.read(
      key: _kboWeeklyLeaderSnapshotStorageKey,
    );
    if (raw == null || raw.isEmpty) return;
    try {
      final restored = _weeklyLeaderSectionsFromPayload(
        jsonDecode(raw),
        maxLeadersPerSection: null,
      );
      if (restored.isEmpty) return;
      _cachedKboWeeklyLeaderSnapshots.clear();
      for (final section in restored) {
        _cachedKboWeeklyLeaderSnapshots[section.round] = section;
      }
      if (!mounted || widget.isSoccer) return;
      setState(() {
        _kboWeeklyLeaderSections = _buildKboWeeklyLeaderSectionsFromCache();
      });
    } catch (_) {
      // Ignore invalid local snapshot payloads.
    }
  }

  Future<void> _persistCachedKboWeeklyLeaderSections() async {
    final payload = _cachedKboWeeklyLeaderSnapshots.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));
    final encoded = jsonEncode([
      for (final entry in payload)
        {
          'round': entry.key,
          'leaders': [
            for (final leader in entry.value.leaders)
              _weeklyLeaderEntryToJson(leader),
          ],
        },
    ]);
    await _kLeagueWeeklyLeaderSnapshotStorage.write(
      key: _kboWeeklyLeaderSnapshotStorageKey,
      value: encoded,
    );
  }

  bool _shouldRunKboLeagueRefresh({
    required bool forceRefresh,
    bool bypassCooldown = false,
  }) {
    if (bypassCooldown) return true;
    final last = _lastKboLeagueRefreshAt;
    if (last == null) return true;
    final cooldown = forceRefresh
        ? _kboWeeklyLiveRefreshCooldown
        : _kboLeagueRefreshCooldown;
    return DateTime.now().difference(last) >= cooldown;
  }

  Future<void> _primeKboWeeklyRounds({
    bool forceRefresh = false,
    bool bypassCooldown = false,
  }) {
    if (widget.isSoccer) return Future.value();
    final inFlight = _primeKboWeeklyRoundsFuture;
    if (inFlight != null) {
      if (forceRefresh && !_primeKboWeeklyRoundsInFlightForceRefresh) {
        _pendingForcedKboWeeklyRefresh = true;
        return inFlight.then(
          (_) => _primeKboWeeklyRounds(
            forceRefresh: true,
            bypassCooldown: bypassCooldown,
          ),
        );
      }
      return inFlight;
    }
    if (!_shouldRunKboLeagueRefresh(
      forceRefresh: forceRefresh,
      bypassCooldown: bypassCooldown,
    )) {
      return Future.value();
    }
    _primeKboWeeklyRoundsInFlightForceRefresh = forceRefresh;
    final future =
        () async {
          try {
            if (_cachedKboWeeklyLeaderSnapshots.isEmpty) {
              await _restoreCachedKboWeeklyLeaderSections();
            }
            if (mounted) {
              setState(() {
                _isPrimingKboWeeklyRounds = true;
                if (_kboWeeklyLeaderSections.isEmpty &&
                    _cachedKboWeeklyLeaderSnapshots.isNotEmpty) {
                  _kboWeeklyLeaderSections =
                      _buildKboWeeklyLeaderSectionsFromCache();
                }
              });
            }
            final players = await _loadKboDraftPlayerPool();
            final draft = _fantasyDraft;
            if (mounted) {
              setState(() {
                _allPlayers = players;
                if (draft != null) {
                  _rebuildFantasyOwnershipCacheFor(
                    draft: draft,
                    allPlayers: players,
                  );
                }
              });
            }
            final sections = await _loadKboWeeklyLeaderSections(
              players,
              forceRefresh: forceRefresh,
            );
            _cachedKboWeeklyLeaderSnapshots
              ..clear()
              ..addEntries(
                sections.map((section) => MapEntry(section.round, section)),
              );
            await _persistCachedKboWeeklyLeaderSections();
            if (!mounted || widget.isSoccer) return;
            setState(() {
              _lastKboLeagueRefreshAt = DateTime.now();
              _kboWeeklyLeaderSections =
                  _buildKboWeeklyLeaderSectionsFromCache();
            });
            _hasPendingKboWeeklyLeaderRefresh = false;
          } catch (error, stackTrace) {
            debugPrint('primeKboWeeklyRounds failed: $error');
            debugPrint('$stackTrace');
          } finally {
            if (mounted && !widget.isSoccer) {
              setState(() {
                _isPrimingKboWeeklyRounds = false;
              });
            }
          }
        }().whenComplete(() {
          final shouldRunForcedRefresh =
              _pendingForcedKboWeeklyRefresh &&
              !_primeKboWeeklyRoundsInFlightForceRefresh;
          _primeKboWeeklyRoundsFuture = null;
          _primeKboWeeklyRoundsInFlightForceRefresh = false;
          _pendingForcedKboWeeklyRefresh = false;
          if (shouldRunForcedRefresh && !widget.isSoccer) {
            unawaited(_primeKboWeeklyRounds(forceRefresh: true));
          }
        });
    _primeKboWeeklyRoundsFuture = future;
    return future;
  }

  Future<void> _primeKLeagueWeeklyRounds(_JoinedDraft draft) {
    if (!widget.isSoccer) return Future.value();
    if (_primeKLeagueWeeklyRoundsFuture != null &&
        _primeKLeagueWeeklyRoundsLeagueId == draft.leagueId) {
      return _primeKLeagueWeeklyRoundsFuture!;
    }
    final future =
        () async {
          try {
            if (mounted && _fantasyDraft?.leagueId == draft.leagueId) {
              setState(() {
                _isPrimingKLeagueWeeklyRounds = true;
              });
            }
            final cachedSnapshots = _cachedKLeagueWeeklyLeaderSnapshots
                .putIfAbsent(
                  draft.leagueId,
                  () => <int, _FantasyWeeklyLeaderSection>{},
                );
            if (cachedSnapshots.isEmpty) {
              await _restoreCachedKLeagueWeeklyLeaderSections(draft);
            }
            if (cachedSnapshots.isEmpty) {
              await _restoreRemoteKLeagueWeeklyLeaderSections(draft);
            }
            final leagueData = await _loadCachedKLeagueLeagueData();
            final players = await _loadApiSoccerPlayers();
            if (!mounted) return;
            if (_fantasyDraft?.leagueId != draft.leagueId) return;
            final rawFixtures = _fixtureAsList(leagueData['fixtures']);
            final fixtureIdsByRound = <int, List<int>>{};
            int latestStartedRound = 0;
            for (final raw in rawFixtures) {
              final map = _fixtureAsMap(raw);
              if (!_kLeagueFixtureMapHasStarted(map)) continue;
              final round = _roundNumber(
                _fixtureText(_fixtureAsMap(map['league'])['round']),
              );
              if (round > latestStartedRound) latestStartedRound = round;
              final fixtureId = _readNullableInt(
                _fixtureAsMap(map['fixture'])['id'],
              );
              if (round > 0 && fixtureId != null && fixtureId > 0) {
                fixtureIdsByRound
                    .putIfAbsent(round, () => <int>[])
                    .add(fixtureId);
              }
            }
            final roundWindows = _kLeagueRoundWindowsFromFixtures(rawFixtures);
            final preferredFantasyRound = _preferredFantasyRoundForDraft(draft);
            final currentDisplayRound = preferredFantasyRound != null
                ? _mappedKLeagueRoundForFantasyRound(
                    draft,
                    preferredFantasyRound,
                    rawFixtures,
                  )
                : roundWindows.isEmpty
                ? (latestStartedRound > 0 ? latestStartedRound : null)
                : _currentKLeagueRoundAt(DateTime.now(), roundWindows);
            final effectiveDisplayRound = currentDisplayRound ?? 0;
            final weeklyRounds = <int>[
              for (
                int round = 1;
                round <= max(latestStartedRound, effectiveDisplayRound);
                round++
              )
                round,
            ];

            double pointsForPlayer(
              _PlayerSlot player,
              Map<String, double> roundScores,
            ) {
              final fallbackMeta = _resolvePlayerMeta(
                player.name,
                asOf: DateTime.now(),
              );
              final club = _canonicalKLeagueClub(
                (player.club.isNotEmpty ? player.club : fallbackMeta.club)
                    .trim(),
              );
              if (club.isEmpty) return 0;
              final direct = roundScores['$club|${player.name}'];
              if (direct != null) return direct;
              final number = player.number > 0
                  ? player.number
                  : fallbackMeta.number;
              if (number > 0) {
                final rosterName = _kLeagueRosterNameForClubNumber(
                  club,
                  '$number',
                );
                if (rosterName.isNotEmpty) {
                  final rosterScore = roundScores['$club|$rosterName'];
                  if (rosterScore != null) return rosterScore;
                }
              }
              return 0;
            }

            _FantasyWeeklyLeaderSection? currentRoundSection;
            if (effectiveDisplayRound > latestStartedRound &&
                effectiveDisplayRound > 0) {
              currentRoundSection = _FantasyWeeklyLeaderSection(
                round: effectiveDisplayRound,
                leaders: const <_FantasyWeeklyLeaderEntry>[],
              );
            }
            final computedPreviousSections =
                <int, _FantasyWeeklyLeaderSection>{};
            final roundsToCompute = <int>[];
            for (int round = latestStartedRound; round >= 1; round--) {
              final needsCurrent = round == effectiveDisplayRound;
              final needsPrevious = !cachedSnapshots.containsKey(round);
              if (needsCurrent || needsPrevious) {
                roundsToCompute.add(round);
              }
            }
            for (final round in roundsToCompute) {
              final roundScores = <String, double>{};
              for (final fixtureId
                  in fixtureIdsByRound[round] ?? const <int>[]) {
                try {
                  final detail = await _loadCachedKLeagueFixtureDetail(
                    fixtureId,
                  );
                  final scores = _kLeagueFantasyBaseScoresFromDetail(detail);
                  scores.forEach(
                    (key, value) => roundScores.update(
                      key,
                      (current) => current + value,
                      ifAbsent: () => value,
                    ),
                  );
                } catch (error, stackTrace) {
                  debugPrint(
                    'primeKLeagueWeeklyRounds detail load failed '
                    '(round=$round, fixture=$fixtureId): $error',
                  );
                  debugPrint('$stackTrace');
                }
              }

              final leaders =
                  players
                      .map((player) {
                        final points = pointsForPlayer(player, roundScores);
                        return _FantasyWeeklyLeaderEntry(
                          name: player.name,
                          position: player.position,
                          club: player.club,
                          number: player.number,
                          points: points,
                          ownership:
                              _MatchDetailPageState._playerOwnerCache[player
                                  .name] ??
                              PlayerOwnership.freeAgent,
                        );
                      })
                      .where((player) => player.points > 0)
                      .toList()
                    ..sort((a, b) {
                      final pointCompare = b.points.compareTo(a.points);
                      if (pointCompare != 0) return pointCompare;
                      return a.name.compareTo(b.name);
                    });
              final section = _FantasyWeeklyLeaderSection(
                round: round,
                leaders: round == effectiveDisplayRound
                    ? leaders.take(30).toList()
                    : leaders.take(3).toList(),
              );
              if (round == effectiveDisplayRound) {
                currentRoundSection = section;
              } else {
                computedPreviousSections[round] = section;
                cachedSnapshots[round] = section;
              }

              if (!mounted) return;
              if (_fantasyDraft?.leagueId != draft.leagueId) return;
            }

            if (!mounted) return;
            if (_fantasyDraft?.leagueId != draft.leagueId) return;
            if (computedPreviousSections.isNotEmpty) {
              await _persistCachedKLeagueWeeklyLeaderSections(
                draft,
                cachedSnapshots,
              );
              unawaited(
                _persistRemoteKLeagueWeeklyLeaderSections(
                  draft,
                  cachedSnapshots,
                ),
              );
            }
            setState(() {
              _kLeagueWeeklyLeaderSections = _mergeWeeklyLeaderSections(
                currentDisplayRound: effectiveDisplayRound,
                currentRoundSection: currentRoundSection,
                cachedPreviousSections: cachedSnapshots,
                computedPreviousSections: computedPreviousSections,
              );
              _kLeagueWeeklyRounds = weeklyRounds;
              _fantasyRoundByKLeagueRound = const {};
              _currentKLeagueWeeklyRound = effectiveDisplayRound > 0
                  ? effectiveDisplayRound
                  : null;
            });
          } catch (error, stackTrace) {
            debugPrint('primeKLeagueWeeklyRounds failed: $error');
            debugPrint('$stackTrace');
          } finally {
            if (mounted && _fantasyDraft?.leagueId == draft.leagueId) {
              setState(() {
                _isPrimingKLeagueWeeklyRounds = false;
              });
            }
          }
        }().whenComplete(() {
          if (_primeKLeagueWeeklyRoundsLeagueId == draft.leagueId) {
            _primeKLeagueWeeklyRoundsFuture = null;
          }
        });
    _primeKLeagueWeeklyRoundsLeagueId = draft.leagueId;
    _primeKLeagueWeeklyRoundsFuture = future;
    return future;
  }

  Future<void> _refreshFantasySoccerScoresAndRebuild({
    bool includeHistory = false,
    bool forceRefreshLiveData = false,
  }) async {
    if (!widget.isSoccer) return;
    final draft = _fantasyDraft;
    final homeState = homeKey.currentState;
    if (draft == null || homeState == null) return;
    await homeState._refreshFantasySoccerScores(
      includeHistory: includeHistory,
      forceRefreshLiveData: forceRefreshLiveData,
    );
    final ready = _findReadyFantasyDraft() ?? draft;
    if (!mounted) return;
    setState(() {
      _applyFantasyDraft(ready);
    });
  }

  bool _needsHistoricalSoccerScoreWarmup(_JoinedDraft draft) {
    if (!draft.isSoccer) return false;
    final currentRound = _currentFantasyRoundAt(draft, DateTime.now());
    for (int round = 1; round < currentRound; round++) {
      if (_fantasySoccerRoundScoreSnapshotFor(draft, round) == null) {
        return true;
      }
    }
    return false;
  }

  Future<void> _resolveFantasyDraft() async {
    final ready = _findReadyFantasyDraft();
    if (ready != null) {
      if (!mounted) return;
      setState(() {
        _applyFantasyDraft(ready);
      });
      unawaited(
        _refreshFantasySoccerScoresAndRebuild(
          includeHistory:
              _section == _MatchSection.league &&
              _needsHistoricalSoccerScoreWarmup(ready),
        ),
      );
      return;
    }

    final recoverable = _findRecoverableFantasyDraft();
    final homeState = homeKey.currentState;
    if (recoverable == null || homeState == null) return;

    if (mounted) {
      setState(() {
        _isResolvingFantasyDraft = true;
      });
    }

    await homeState._recoverFantasyLeagueState(recoverable);
    final recovered = _findReadyFantasyDraft();
    if (!mounted) return;
    setState(() {
      if (recovered != null) {
        _applyFantasyDraft(recovered);
      }
      _isResolvingFantasyDraft = false;
    });
    if (recovered != null) {
      unawaited(
        _refreshFantasySoccerScoresAndRebuild(
          includeHistory:
              _section == _MatchSection.league &&
              _needsHistoricalSoccerScoreWarmup(recovered),
        ),
      );
    }
  }

  _LineupData _buildFantasySoccerLineup(_FantasyMatchupView matchup) {
    List<_Player> rowsFrom(
      _FantasyTeamState team,
      List<_FantasyTeamPlayer> players,
    ) {
      _PlayerSlot slotFrom(_FantasyTeamPlayer player) {
        final score = _fantasyPlayerRoundScore(
          player,
          matchup.round,
          isSoccer: true,
          draft: matchup.draft,
          team: team,
        );
        return _PlayerSlot(
          name: player.name,
          score: score.round(),
          position: player.position,
          club: player.club,
          number: player.number,
          playerId: player.playerId,
        );
      }

      final gk = players.where((p) => p.position == 'GK').take(1).toList();
      final dfs = players.where((p) => p.position == 'DF').toList();
      final mfs = players.where((p) => p.position == 'MF').toList();
      final fws = players.where((p) => p.position == 'FW').toList();
      return [
        _Player(slots: gk.map(slotFrom).toList()),
        _Player(slots: dfs.map(slotFrom).toList()),
        _Player(slots: mfs.map(slotFrom).toList()),
        _Player(slots: fws.map(slotFrom).toList()),
      ];
    }

    final homeRows = rowsFrom(matchup.myTeam, matchup.myTeam.starting);
    final awayBaseRows = rowsFrom(matchup.opponent, matchup.opponent.starting);
    final awayRows = awayBaseRows.reversed.toList();
    final homeFormation =
        _formationKeyForCounts(
          df: matchup.myTeam.starting.where((p) => p.position == 'DF').length,
          mf: matchup.myTeam.starting.where((p) => p.position == 'MF').length,
          fw: matchup.myTeam.starting.where((p) => p.position == 'FW').length,
        ) ??
        '4-3-3';
    final awayFormation =
        _formationKeyForCounts(
          df: matchup.opponent.starting.where((p) => p.position == 'DF').length,
          mf: matchup.opponent.starting.where((p) => p.position == 'MF').length,
          fw: matchup.opponent.starting.where((p) => p.position == 'FW').length,
        ) ??
        '4-3-3';
    return _LineupData(
      home: homeRows,
      away: awayRows,
      homeScore: matchup.myScore.round(),
      awayScore: matchup.opponentScore.round(),
      homeFormation: homeFormation,
      awayFormation: awayFormation,
    );
  }

  List<_PlayerSlot> _buildFantasyAllPlayers(_JoinedDraft draft) {
    final players = <_PlayerSlot>[];
    for (final team in draft.fantasyTeams) {
      for (final player in team.roster) {
        players.add(player.toPlayerSlot());
      }
    }
    return players;
  }

  bool _isKnownKboClubName(String club) {
    final trimmed = club.trim();
    if (trimmed.isEmpty) return false;
    return _kboDraftClubs.contains(_normalizeKboDraftClub(trimmed));
  }

  String _baseballPoolLookupKey(String name, String position) =>
      '${name.trim()}|${position.trim()}';

  _PlayerSlot _hydrateBaseballSlotFromPool(
    _PlayerSlot slot, {
    required Map<String, _PlayerSlot> byPlayerId,
    required Map<String, _PlayerSlot> byClubAndNumber,
    required Map<String, _PlayerSlot> uniqueByNameAndPosition,
  }) {
    final rawPlayerId = slot.playerId.trim();
    final normalizedClub = _normalizeKboDraftClub(slot.club);
    final resolved =
        byPlayerId[rawPlayerId] ??
        ((slot.number > 0 && normalizedClub.isNotEmpty)
            ? byClubAndNumber[_kboClubNumberLookupKey(
                normalizedClub,
                slot.number,
              )]
            : null) ??
        uniqueByNameAndPosition[_baseballPoolLookupKey(
          slot.name,
          slot.position,
        )];
    final hasValidKboClub = _isKnownKboClubName(slot.club);
    final resolvedPosition = _resolveKboPlayerPosition(
      slot.position,
      club: normalizedClub,
      rawName: slot.name,
      number: slot.number,
    );
    final fallbackHydratedScore = slot.score > 0
        ? slot.score
        : _fallbackKboProjectionSeedScore(slot);

    if (resolved == null) {
      return _PlayerSlot(
        name: slot.name,
        score: fallbackHydratedScore,
        position: resolvedPosition.isNotEmpty
            ? resolvedPosition
            : slot.position,
        club: hasValidKboClub ? slot.club : '',
        number: hasValidKboClub ? slot.number : 0,
        playerId: rawPlayerId,
      );
    }

    final resolvedScore = slot.score > 0
        ? slot.score
        : (resolved.score > 0 ? resolved.score : fallbackHydratedScore);

    return _PlayerSlot(
      name: resolved.name,
      score: resolvedScore,
      position: resolvedPosition.isNotEmpty
          ? resolvedPosition
          : resolved.position,
      club: hasValidKboClub ? slot.club : resolved.club,
      number: slot.number > 0 ? slot.number : resolved.number,
      playerId: resolved.playerId,
    );
  }

  _FantasyTeamPlayer _hydrateBaseballFantasyPlayerFromPool(
    _FantasyTeamPlayer player, {
    required Map<String, _PlayerSlot> byPlayerId,
    required Map<String, _PlayerSlot> byClubAndNumber,
    required Map<String, _PlayerSlot> uniqueByNameAndPosition,
  }) {
    final hydrated = _hydrateBaseballSlotFromPool(
      player.toPlayerSlot(),
      byPlayerId: byPlayerId,
      byClubAndNumber: byClubAndNumber,
      uniqueByNameAndPosition: uniqueByNameAndPosition,
    );
    return _FantasyTeamPlayer(
      name: hydrated.name,
      position: hydrated.position,
      score: hydrated.score,
      club: hydrated.club,
      number: hydrated.number,
      playerId: hydrated.playerId,
    );
  }

  _JoinedDraft _hydrateBaseballDraftFromPool(
    _JoinedDraft draft,
    List<_PlayerSlot> pool,
  ) {
    final byPlayerId = <String, _PlayerSlot>{
      for (final player in pool)
        if (player.playerId.trim().isNotEmpty) player.playerId.trim(): player,
    };
    final byClubAndNumber = <String, _PlayerSlot>{
      for (final player in pool)
        if (player.number > 0 && _normalizeKboDraftClub(player.club).isNotEmpty)
          _kboClubNumberLookupKey(player.club, player.number): player,
    };
    final groupedByNameAndPosition = <String, List<_PlayerSlot>>{};
    for (final player in pool) {
      groupedByNameAndPosition
          .putIfAbsent(
            _baseballPoolLookupKey(player.name, player.position),
            () => <_PlayerSlot>[],
          )
          .add(player);
    }
    final uniqueByNameAndPosition = <String, _PlayerSlot>{
      for (final entry in groupedByNameAndPosition.entries)
        if (entry.value.length == 1) entry.key: entry.value.first,
    };

    final updatedTeams = draft.fantasyTeams.map((team) {
      return _FantasyTeamState(
        uid: team.uid,
        teamName: team.teamName,
        roster: team.roster
            .map(
              (player) => _hydrateBaseballFantasyPlayerFromPool(
                player,
                byPlayerId: byPlayerId,
                byClubAndNumber: byClubAndNumber,
                uniqueByNameAndPosition: uniqueByNameAndPosition,
              ),
            )
            .toList(),
        starting: team.starting
            .map(
              (player) => _hydrateBaseballFantasyPlayerFromPool(
                player,
                byPlayerId: byPlayerId,
                byClubAndNumber: byClubAndNumber,
                uniqueByNameAndPosition: uniqueByNameAndPosition,
              ),
            )
            .toList(),
        bench: team.bench
            .map(
              (player) => _hydrateBaseballFantasyPlayerFromPool(
                player,
                byPlayerId: byPlayerId,
                byClubAndNumber: byClubAndNumber,
                uniqueByNameAndPosition: uniqueByNameAndPosition,
              ),
            )
            .toList(),
        captainName: team.captainName,
        viceCaptainName: team.viceCaptainName,
        captainPlayerId: team.captainPlayerId,
        viceCaptainPlayerId: team.viceCaptainPlayerId,
        kboRoundScoreStates: team.kboRoundScoreStates
            .map(
              (state) => _KboFantasyRoundScoreState(
                round: state.round,
                bankedScore: state.bankedScore,
                starterBaselines: state.starterBaselines,
                starterPlayers: state.starterPlayers
                    .map(
                      (player) => _hydrateBaseballFantasyPlayerFromPool(
                        player,
                        byPlayerId: byPlayerId,
                        byClubAndNumber: byClubAndNumber,
                        uniqueByNameAndPosition: uniqueByNameAndPosition,
                      ),
                    )
                    .toList(),
                doubledPlayerId: state.doubledPlayerId,
                updatedAt: state.updatedAt,
                unlockedScoreSnapshot: state.unlockedScoreSnapshot,
                unlockedAt: state.unlockedAt,
              ),
            )
            .toList(),
      );
    }).toList();

    final updatedBoard = draft.draftBoard
        .map(
          (row) => row
              .map(
                (slot) => slot == null
                    ? null
                    : _hydrateBaseballSlotFromPool(
                        slot,
                        byPlayerId: byPlayerId,
                        byClubAndNumber: byClubAndNumber,
                        uniqueByNameAndPosition: uniqueByNameAndPosition,
                      ),
              )
              .toList(),
        )
        .toList();

    return _JoinedDraft(
      leagueId: draft.leagueId,
      leagueName: draft.leagueName,
      when: draft.when,
      isSoccer: draft.isSoccer,
      teamCount: draft.teamCount,
      roundCount: draft.roundCount,
      memberCount: draft.memberCount,
      inviteCode: draft.inviteCode,
      ownerId: draft.ownerId,
      draftOrder: draft.draftOrder,
      fantasyReady: draft.fantasyReady,
      fantasyTeams: updatedTeams,
      fantasySchedule: draft.fantasySchedule,
      draftBoard: updatedBoard,
    );
  }

  bool _baseballDraftNeedsMetadataHydration(_JoinedDraft draft) {
    if (draft.isSoccer) return false;
    for (final team in draft.fantasyTeams) {
      for (final player in team.roster) {
        if (!_isKnownKboClubName(player.club) ||
            player.number <= 0 ||
            player.playerId.trim().isEmpty) {
          return true;
        }
      }
    }
    return false;
  }

  Future<void> _hydrateActiveBaseballFantasyMetadata(_JoinedDraft draft) async {
    if (!_baseballDraftNeedsMetadataHydration(draft)) return;
    final pool = await _loadKboDraftPlayerPool();
    if (!mounted) return;
    if (_resolvedFantasyDraft?.leagueId != draft.leagueId) return;

    final hydratedDraft = _hydrateBaseballDraftFromPool(draft, pool);
    if (!mounted) return;
    if (_resolvedFantasyDraft?.leagueId != draft.leagueId) return;

    setState(() {
      _resolvedFantasyDraft = hydratedDraft;
      _fantasyMatchup = _selectedFantasyMatchupForDraft(hydratedDraft);
      final preserveLocalState =
          _shouldPreserveLocalRosterState &&
          _resolvedFantasyDraft?.leagueId == hydratedDraft.leagueId;
      if (!preserveLocalState && _fantasyMatchup != null) {
        _fantasyMyTeam = _fantasyMatchup!.myTeam;
        _starting = _fantasyMatchup!.myTeam.starting
            .map((player) => player.toPlayerSlot())
            .toList();
        _bench = _fantasyMatchup!.myTeam.bench
            .map((player) => player.toPlayerSlot())
            .toList();
      } else if (!preserveLocalState) {
        _fantasyMyTeam = hydratedDraft.fantasyTeams.isEmpty
            ? null
            : hydratedDraft.fantasyTeams.first;
        _starting =
            _fantasyMyTeam?.starting
                .map((player) => player.toPlayerSlot())
                .toList() ??
            [];
        _bench =
            _fantasyMyTeam?.bench
                .map((player) => player.toPlayerSlot())
                .toList() ??
            [];
      } else {
        _fantasyMyTeam =
            _myFantasyTeamForDraft(hydratedDraft) ??
            (hydratedDraft.fantasyTeams.isEmpty
                ? null
                : hydratedDraft.fantasyTeams.first);
      }
      _allPlayers = pool;
      _rebuildFantasyOwnershipCacheFor(
        draft: hydratedDraft,
        allPlayers: _allPlayers,
      );
      if (!preserveLocalState) {
        _normalizeLeadershipSelection(
          preferredCaptainName: _fantasyMyTeam?.captainName,
          preferredViceCaptainName: _fantasyMyTeam?.viceCaptainName,
          preferredCaptainPlayerId: _fantasyMyTeam?.captainPlayerId,
          preferredViceCaptainPlayerId: _fantasyMyTeam?.viceCaptainPlayerId,
        );
        _captureSavedRosterState();
      }
      _fantasyProjectedScores = const <String, double>{};
      _fantasyPitcherWeeklyProjectionContexts =
          const <
            String,
            ({
              double opportunityFactor,
              int confirmedStarts,
              int completedStarts,
            })
          >{};
      _fantasyProjectedScoresKey = '';
      _fantasyProjectedScoresFreshKey = '';
      _fantasyPitcherWeeklyProjectionContextsKey = '';
      _fantasyProjectedScoresFuture = null;
      _visibleKboRoundPointsFuture = null;
      _visibleKboRoundPointsFutureKey = '';
      _visibleKboRoundPointsLoadedKey = '';
    });
    if (_section == _MatchSection.matchup || _section == _MatchSection.roster) {
      unawaited(_primePersistedFantasyProjectedScores(hydratedDraft));
      unawaited(_ensureFantasyProjectedScores(hydratedDraft));
      unawaited(_refreshVisibleKboRoundPoints(forceRefresh: true));
    }
    if (_section == _MatchSection.league) {
      unawaited(_primeKboStandingsHistoryForDraft(hydratedDraft));
    }
  }

  void _rebuildFantasyOwnershipCacheFor({
    required _JoinedDraft draft,
    required List<_PlayerSlot> allPlayers,
  }) {
    _playerOwnerCache.clear();
    for (final player in allPlayers) {
      _setOwnerForSlot(player, PlayerOwnership.freeAgent);
    }
    for (final team in draft.fantasyTeams) {
      final rosterPlayers = <String, _FantasyTeamPlayer>{};
      for (final player in [...team.roster, ...team.starting, ...team.bench]) {
        rosterPlayers[_fantasyTeamPlayerIdentity(player)] = player;
      }
      for (final player in rosterPlayers.values) {
        _setOwnerForSlot(
          player.toPlayerSlot(),
          team.teamName == _fantasyMyTeam?.teamName
              ? PlayerOwnership.myTeam
              : PlayerOwnership.otherTeam,
        );
      }
    }
  }

  Future<void> _loadFantasyApiPlayerPool(_JoinedDraft draft) async {
    final players = widget.isSoccer
        ? await _loadApiSoccerPlayers()
        : await _loadKboDraftPlayerPool();
    if (!mounted) return;
    if (_fantasyDraft?.leagueId != draft.leagueId) return;
    setState(() {
      _allPlayers = players;
      _playersVisibleCount = _initialPlayersVisibleCount;
      _rebuildFantasyOwnershipCacheFor(
        draft: _resolvedFantasyDraft ?? draft,
        allPlayers: _allPlayers,
      );
    });
    if (_section == _MatchSection.players) {
      _primePlayersAptsIfNeeded();
    } else {
      _primeProfileAptsIfNeeded(rebuild: _section == _MatchSection.league);
    }
    if (!draft.isSoccer && _section == _MatchSection.league) {
      final shouldForceWeeklyRefresh = _hasPendingKboWeeklyLeaderRefresh;
      unawaited(
        _primeKboWeeklyRounds(
          forceRefresh: shouldForceWeeklyRefresh,
          bypassCooldown: shouldForceWeeklyRefresh,
        ),
      );
    }
  }

  Future<void> _loadStandaloneBaseballPlayerPool() async {
    final players = await _loadKboDraftPlayerPool();
    if (!mounted || widget.isSoccer) return;
    if (_fantasyDraft != null) return;
    setState(() {
      _allPlayers = players;
      _playersVisibleCount = _initialPlayersVisibleCount;
    });
    if (_section == _MatchSection.players) {
      _primePlayersAptsIfNeeded();
    } else {
      _primeProfileAptsIfNeeded(rebuild: _section == _MatchSection.league);
    }
  }

  void _initFantasyMode(_JoinedDraft draft) {
    final nextMatchup = _selectedFantasyMatchupForDraft(draft);
    final preserveLocalState =
        _shouldPreserveLocalRosterState &&
        _resolvedFantasyDraft?.leagueId == draft.leagueId;
    _fantasyMatchup = nextMatchup;
    if (nextMatchup != null) {
      _fantasyMyTeam = nextMatchup.myTeam;
      if (!preserveLocalState) {
        _starting = nextMatchup.myTeam.starting
            .map((player) => player.toPlayerSlot())
            .toList();
        _bench = nextMatchup.myTeam.bench
            .map((player) => player.toPlayerSlot())
            .toList();
        if (draft.isSoccer) {
          _lineup = _buildFantasySoccerLineup(nextMatchup);
        } else {
          _lineup = null;
        }
      }
    } else {
      _fantasyMyTeam = draft.fantasyTeams.isEmpty
          ? null
          : draft.fantasyTeams.first;
      if (!preserveLocalState) {
        _starting =
            _fantasyMyTeam?.starting
                .map((player) => player.toPlayerSlot())
                .toList() ??
            [];
        _bench =
            _fantasyMyTeam?.bench
                .map((player) => player.toPlayerSlot())
                .toList() ??
            [];
        _lineup = null;
      }
    }
    _allPlayers = _buildFantasyAllPlayers(draft);
    _rebuildFantasyOwnershipCacheFor(draft: draft, allPlayers: _allPlayers);
    _applyPersistedFantasyProjectedScoresIfReady(draft);
    if (_section == _MatchSection.league) {
      _primeProfileAptsIfNeeded();
    }
    if (!preserveLocalState) {
      _normalizeLeadershipSelection(
        preferredCaptainName: _fantasyMyTeam?.captainName,
        preferredViceCaptainName: _fantasyMyTeam?.viceCaptainName,
        preferredCaptainPlayerId: _fantasyMyTeam?.captainPlayerId,
        preferredViceCaptainPlayerId: _fantasyMyTeam?.viceCaptainPlayerId,
      );
      _captureSavedRosterState();
    }
    unawaited(_loadFantasyApiPlayerPool(draft));
    if (_section == _MatchSection.matchup || _section == _MatchSection.roster) {
      unawaited(_primePersistedFantasyProjectedScores(draft));
      unawaited(_ensureFantasyProjectedScores(draft));
      if (!draft.isSoccer) {
        unawaited(_refreshVisibleKboRoundPoints(forceRefresh: true));
      }
    } else if (_section == _MatchSection.league) {
      _primeProfileAptsIfNeeded(rebuild: true);
    }
    unawaited(_syncFantasyNotifications());
  }

  Future<void> _primeRosterLockData() async {
    final now = DateTime.now();
    if (widget.isSoccer) {
      if (_cachedKLeagueLeagueData != null &&
          _isLeagueDataCacheFresh(
            _cachedKLeagueLeagueDataUpdatedAt,
            now: now,
          )) {
        if (!mounted) return;
        setState(() {});
        return;
      }
      final restored = await _restoreLeagueDataCacheEntry(
        _kLeagueLeagueDataCacheKey,
      );
      if (restored != null &&
          _isLeagueDataCacheFresh(restored.updatedAt, now: now)) {
        _cachedKLeagueLeagueData = restored.data;
        _cachedKLeagueLeagueDataUpdatedAt = restored.updatedAt ?? now;
      } else {
        await _loadCachedKLeagueLeagueData(forceRefresh: true);
      }
    } else {
      if (_cachedKboLeagueData != null &&
          _isLeagueDataCacheFresh(_cachedKboLeagueDataUpdatedAt, now: now)) {
        if (!mounted) return;
        setState(() {});
        return;
      }
      final restored = await _restoreLeagueDataCacheEntry(
        _kboLeagueDataCacheKey,
      );
      if (restored != null &&
          _isLeagueDataCacheFresh(restored.updatedAt, now: now)) {
        _cachedKboLeagueData = restored.data;
        _cachedKboLeagueDataUpdatedAt = restored.updatedAt ?? now;
      } else {
        await _loadCachedKboLeagueData(forceRefresh: true);
      }
    }
    if (!mounted) return;
    setState(() {});
  }

  List<_JoinedDraft> _notificationDrafts() {
    final homeState = homeKey.currentState;
    final drafts = homeState?.joinedDrafts ?? const <_JoinedDraft>[];
    if (drafts.isNotEmpty) {
      return drafts.where((draft) => draft.fantasyReady).toList();
    }
    final single = _fantasyDraft;
    if (single != null && single.fantasyReady) {
      return <_JoinedDraft>[single];
    }
    return const <_JoinedDraft>[];
  }

  _FantasyTeamState? _myFantasyTeamForDraft(_JoinedDraft draft) {
    final myUid = _currentUserFantasyUid();
    final myTeamName = _currentUserFantasyTeamName(draft);
    for (final team in draft.fantasyTeams) {
      if (myUid != null &&
          myUid.isNotEmpty &&
          team.uid.trim() == myUid.trim()) {
        return team;
      }
      if (myTeamName != null &&
          myTeamName.isNotEmpty &&
          _sameFantasyIdentity(team.teamName, myTeamName)) {
        return team;
      }
    }
    return null;
  }

  List<String> _kboLockedStartingPlayerNamesForNotification(
    _FantasyTeamState team,
    Set<String> lockedClubs,
  ) {
    if (lockedClubs.isEmpty) return const <String>[];
    final normalizedLockedClubs = lockedClubs
        .map(_normalizeKboDraftClub)
        .where((club) => club.isNotEmpty)
        .toSet();
    if (normalizedLockedClubs.isEmpty) return const <String>[];
    final names = <String>[];
    final seen = <String>{};
    for (final player in team.starting) {
      final club = _normalizeKboDraftClub(player.club);
      if (!normalizedLockedClubs.contains(club)) continue;
      final name = player.name.trim();
      if (name.isEmpty || !seen.add(name)) continue;
      names.add(name);
    }
    return names;
  }

  String _buildKboRosterTimingNotificationMessage({
    required String leagueName,
    required List<String> playerNames,
    required bool isSoon,
  }) {
    if (playerNames.isEmpty) {
      return isSoon
          ? '$leagueName 로스터가 30분 내 일부 잠깁니다.'
          : '$leagueName 일부 선수가 잠겼습니다.';
    }
    if (playerNames.length == 1) {
      return isSoon
          ? '${playerNames.first} 선수가 30분 뒤 잠깁니다.'
          : '${playerNames.first} 선수가 잠겼습니다.';
    }
    return isSoon
        ? '${playerNames.first} 외 ${playerNames.length - 1}명의 선수가 30분 뒤 잠깁니다.'
        : '${playerNames.first} 외 ${playerNames.length - 1}명의 선수가 잠겼습니다.';
  }

  Set<String> _notificationActivePlayerIdsForDraftRound(
    _JoinedDraft draft,
    _FantasyTeamState team,
    int round,
  ) {
    final players = !draft.isSoccer
        ? () {
            final state = _kboRoundScoreStateForTeam(team, round);
            if (state == null) return team.starting;
            return _resolvedKboRoundStarterPlayers(team, state);
          }()
        : team.starting;
    return {
      for (final player in players) _playerSlotIdentity(player.toPlayerSlot()),
    };
  }

  List<_FantasyNotificationEntry> _pruneStaleFptsNotificationEntries(
    List<_FantasyNotificationEntry> entries,
    Iterable<_JoinedDraft> drafts,
  ) {
    final activeStartingIdsByLeague = <String, Set<String>>{};
    final activeRoundByLeague = <String, int>{};
    final now = DateTime.now();

    for (final draft in drafts) {
      final myTeam = _myFantasyTeamForDraft(draft);
      if (myTeam == null) continue;
      final leagueId = draft.leagueId.trim();
      if (leagueId.isEmpty) continue;
      final activeRound = _currentFantasyRoundAt(draft, now);
      activeRoundByLeague[leagueId] = activeRound;
      activeStartingIdsByLeague[leagueId] =
          _notificationActivePlayerIdsForDraftRound(draft, myTeam, activeRound);
    }

    return entries
        .where((entry) {
          final identity = _fptsNotificationIdentityFromEntry(entry);
          if (identity == null) return true;
          final activeRound = activeRoundByLeague[identity.leagueId];
          final activeStartingIds =
              activeStartingIdsByLeague[identity.leagueId];
          if (activeRound == null || activeStartingIds == null) return true;
          if (identity.round != activeRound) return true;
          return activeStartingIds.contains(identity.playerId);
        })
        .toList(growable: false);
  }

  _JoinedDraft? _notificationDraftForLeague(String leagueId) {
    final id = leagueId.trim();
    if (id.isEmpty) return null;
    final homeDrafts =
        homeKey.currentState?.joinedDrafts ?? const <_JoinedDraft>[];
    for (final draft in homeDrafts) {
      if (draft.leagueId == id) return draft;
    }
    final current = _fantasyDraft;
    if (current != null && current.leagueId == id) {
      return current;
    }
    return null;
  }

  _MatchSection _notificationTargetSection(_FantasyNotificationEntry entry) {
    switch (entry.kind) {
      case 'roster_lock_soon':
      case 'roster_lock':
      case 'roster_unlock':
      case 'fpts':
        return _MatchSection.roster;
      default:
        return _MatchSection.matchup;
    }
  }

  void _reapplyPersistedKboVisibleMatchupScores() {
    final draft = _resolvedFantasyDraft;
    if (!mounted || draft == null || draft.isSoccer) return;
    final nextMatchup = _selectedFantasyMatchupForDraft(draft);
    if (nextMatchup == null) return;
    setState(() {
      _fantasyMatchup = nextMatchup;
      if (!_shouldPreserveLocalRosterState) {
        _fantasyMyTeam = nextMatchup.myTeam;
      }
    });
  }

  String? _tradeRequestIdForEntry(_FantasyNotificationEntry entry) {
    if (entry.kind != 'trade_request') return null;
    final raw = entry.id.trim();
    if (!raw.startsWith('trade:')) return null;
    final id = raw.substring('trade:'.length).trim();
    return id.isEmpty ? null : id;
  }

  Future<void> _openNotificationEntry(_FantasyNotificationEntry entry) async {
    final draft = _notificationDraftForLeague(entry.leagueId);
    if (draft == null || !mounted) return;
    final tradeRequestId = _tradeRequestIdForEntry(entry);
    if (tradeRequestId != null) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              _TradeRequestDetailPage(draft: draft, requestId: tradeRequestId),
        ),
      );
      if (!mounted) return;
      await _syncFantasyNotifications();
      return;
    }
    final targetSection = _notificationTargetSection(entry);
    if (_fantasyDraft?.leagueId == draft.leagueId) {
      setState(() {
        _section = targetSection;
      });
      if (!draft.isSoccer &&
          (targetSection == _MatchSection.matchup ||
              targetSection == _MatchSection.roster)) {
        unawaited(_refreshVisibleKboRoundPoints(forceRefresh: true));
      }
      return;
    }
    await Navigator.of(context).push(
      _matchDetailPageRoute(
        isSoccer: draft.isSoccer,
        draft: draft,
        initialSection: targetSection,
      ),
    );
  }

  Future<List<_FantasyNotificationEntry>>
  _loadStoredNotificationEntries() async {
    final raw = await _fantasyNotificationStorage.read(
      key: _fantasyNotificationEntriesStorageKey(),
    );
    if (raw == null || raw.isEmpty) return const <_FantasyNotificationEntry>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const <_FantasyNotificationEntry>[];
      return decoded
          .whereType<Map>()
          .map(
            (item) => _FantasyNotificationEntry.fromMap(
              Map<String, dynamic>.from(item.cast<Object?, Object?>()),
            ),
          )
          .toList();
    } catch (_) {
      return const <_FantasyNotificationEntry>[];
    }
  }

  Future<void> _restoreFantasyNotifications() async {
    final entries = _trimFantasyNotificationEntries(
      await _loadStoredNotificationEntries(),
    );
    final unreadCount = entries.where((entry) => !entry.isRead).length;
    if (!mounted) return;
    setState(() {
      _notificationEntries = entries;
      _notificationUnreadCount = unreadCount;
    });
    unawaited(pushNotificationService.syncAppIconBadgeCount(unreadCount));
  }

  Future<void> _persistNotificationEntries(
    List<_FantasyNotificationEntry> entries,
  ) async {
    final trimmed = _trimFantasyNotificationEntries(entries);
    await _fantasyNotificationStorage.write(
      key: _fantasyNotificationEntriesStorageKey(),
      value: jsonEncode(trimmed.map((entry) => entry.toMap()).toList()),
    );
  }

  Future<Map<String, dynamic>> _loadRosterNotificationState() async {
    final raw = await _fantasyNotificationStorage.read(
      key: _fantasyNotificationRosterStateStorageKey(),
    );
    if (raw == null || raw.isEmpty) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return <String, dynamic>{};
      return Map<String, dynamic>.from(decoded.cast<String, dynamic>());
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  Future<void> _persistRosterNotificationState(
    Map<String, dynamic> state,
  ) async {
    await _fantasyNotificationStorage.write(
      key: _fantasyNotificationRosterStateStorageKey(),
      value: jsonEncode(state),
    );
  }

  Future<Map<String, dynamic>> _loadFptsNotificationState() async {
    final raw = await _fantasyNotificationStorage.read(
      key: _fantasyNotificationFptsStateStorageKey(),
    );
    if (raw == null || raw.isEmpty) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return <String, dynamic>{};
      return Map<String, dynamic>.from(decoded.cast<String, dynamic>());
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  Future<void> _persistFptsNotificationState(Map<String, dynamic> state) async {
    await _fantasyNotificationStorage.write(
      key: _fantasyNotificationFptsStateStorageKey(),
      value: jsonEncode(state),
    );
  }

  Future<void> _syncFantasyNotifications({bool markRead = false}) async {
    _syncFantasyNotificationsQueued = true;
    _syncFantasyNotificationsQueuedMarkRead =
        _syncFantasyNotificationsQueuedMarkRead || markRead;
    final inFlight = _syncFantasyNotificationsFuture;
    if (inFlight != null) {
      await inFlight;
      return;
    }

    final future = () async {
      while (_syncFantasyNotificationsQueued) {
        final effectiveMarkRead = _syncFantasyNotificationsQueuedMarkRead;
        _syncFantasyNotificationsQueued = false;
        _syncFantasyNotificationsQueuedMarkRead = false;
        await _runSyncFantasyNotifications(markRead: effectiveMarkRead);
      }
    }();
    _syncFantasyNotificationsFuture = future;
    try {
      await future;
    } finally {
      if (identical(_syncFantasyNotificationsFuture, future)) {
        _syncFantasyNotificationsFuture = null;
      }
    }
  }

  Future<void> _runSyncFantasyNotifications({bool markRead = false}) async {
    final drafts = _notificationDrafts();
    if (drafts.isEmpty) {
      final entries = _trimFantasyNotificationEntries(
        await _loadStoredNotificationEntries(),
      );
      final unreadCount = entries.where((entry) => !entry.isRead).length;
      if (!mounted) return;
      setState(() {
        _notificationEntries = entries;
        _notificationUnreadCount = unreadCount;
      });
      unawaited(pushNotificationService.syncAppIconBadgeCount(unreadCount));
      return;
    }

    final homeState = homeKey.currentState;
    if (drafts.any((draft) => draft.isSoccer)) {
      await homeState?._refreshFantasySoccerScores(includeHistory: false);
      await _loadCachedKLeagueLeagueData();
    }
    if (drafts.any((draft) => !draft.isSoccer)) {
      await _loadCachedKboLeagueData();
    }

    var entries = _trimFantasyNotificationEntries(
      await _loadStoredNotificationEntries(),
    );
    entries = _pruneStaleFptsNotificationEntries(entries, drafts);
    final rosterState = await _loadRosterNotificationState();
    final previousFptsState = await _loadFptsNotificationState();
    final nextFptsState = <String, dynamic>{};
    final existingIds = entries.map((entry) => entry.id).toSet();
    final now = DateTime.now();

    void addEntry(_FantasyNotificationEntry entry) {
      if (existingIds.add(entry.id)) {
        entries = [entry, ...entries];
      }
    }

    void removeEntriesWhere(bool Function(_FantasyNotificationEntry entry) test) {
      final removedIds = <String>{};
      entries = entries.where((entry) {
        final shouldRemove = test(entry);
        if (shouldRemove) {
          removedIds.add(entry.id);
        }
        return !shouldRemove;
      }).toList();
      existingIds.removeWhere(removedIds.contains);
    }

    void removeLocalSyntheticFptsEntries({
      required String leagueId,
      required int round,
      required _PlayerSlot slot,
    }) {
      final slotIdentity = _playerSlotIdentity(slot);
      final prefixes = <String>[
        'fpts:$leagueId:$round:$slotIdentity:',
        'fpts_pitcher:$leagueId:$round:$slotIdentity:',
        'fpts_hr:$leagueId:$round:$slotIdentity:',
      ];
      removeEntriesWhere(
        (entry) =>
            entry.kind == 'fpts' &&
            prefixes.any((prefix) => entry.id.startsWith(prefix)),
      );
    }

    void trackFptsEntry({
      required _JoinedDraft draft,
      required int round,
      required _PlayerSlot slot,
      required double score,
      required String title,
      required String message,
    }) {
      final stateKey = '${draft.leagueId}|$round|${_playerSlotIdentity(slot)}';
      final previousRaw = previousFptsState[stateKey];
      final previous = previousRaw is Map
          ? Map<String, dynamic>.from(previousRaw.cast<Object?, Object?>())
          : null;
      final previousScore = previous == null
          ? null
          : (previous['score'] as num?)?.toDouble() ??
                double.tryParse('${previous['score'] ?? ''}');
      final previousRevision = previous == null
          ? 0
          : (previous['revision'] as num?)?.toInt() ??
                int.tryParse('${previous['revision'] ?? ''}') ??
                0;
      final canEmitRealtime = _shouldEmitRealtimeFantasyNotification(
        now: now,
        previousState: previous,
      );
      if (!canEmitRealtime) {
        removeLocalSyntheticFptsEntries(
          leagueId: draft.leagueId,
          round: round,
          slot: slot,
        );
      }
      if (previous == null) {
        nextFptsState[stateKey] = <String, dynamic>{
          'score': score,
          'revision': 0,
          'observedAt': now.toIso8601String(),
        };
        return;
      }
      final didChange =
          previousScore == null || (previousScore - score).abs() > 0.001;
      var revision = previousRevision;
      if (didChange && score.abs() > 0.001 && canEmitRealtime) {
        revision += 1;
        addEntry(
          _FantasyNotificationEntry(
            id: 'fpts:${draft.leagueId}:$round:${_playerSlotIdentity(slot)}:$revision',
            kind: 'fpts',
            leagueId: draft.leagueId,
            leagueName: draft.leagueName,
            isSoccer: draft.isSoccer,
            title: title,
            message: message,
            createdAt: now,
          ),
        );
      }
      nextFptsState[stateKey] = <String, dynamic>{
        'score': score,
        'revision': revision,
        'observedAt': now.toIso8601String(),
      };
    }

    void trackKboFptsEntry({
      required _JoinedDraft draft,
      required int round,
      required _PlayerSlot slot,
      required _FantasyTeamState team,
      required _PlayerRoundPoints roundPoints,
    }) {
      final stateKey = '${draft.leagueId}|$round|${_playerSlotIdentity(slot)}';
      final previousRaw = previousFptsState[stateKey];
      final previous = previousRaw is Map
          ? Map<String, dynamic>.from(previousRaw.cast<Object?, Object?>())
          : null;
      final canEmitRealtime = _shouldEmitRealtimeFantasyNotification(
        now: now,
        previousState: previous,
      );
      if (!canEmitRealtime) {
        removeLocalSyntheticFptsEntries(
          leagueId: draft.leagueId,
          round: round,
          slot: slot,
        );
      }
      final isPitcher = slot.position.trim().toUpperCase() == 'P';
      final baseScore = roundPoints.displayedPoints;
      final displayedScore = _roundFantasyNotificationScore(
        _isCaptainForTeam(team, slot) ? baseScore * 2 : baseScore,
      );
      if (previous == null) {
        if (isPitcher) {
          nextFptsState[stateKey] = <String, dynamic>{
            'type': 'kbo_pitcher',
            'pitcherMilestone': _completedKboPitcherInningMilestone(
              roundPoints,
            ),
            'displayedScore': displayedScore,
            'observedAt': now.toIso8601String(),
          };
        } else {
          nextFptsState[stateKey] = <String, dynamic>{
            'type': 'kbo_hitter',
            'homeRuns': _kboHomeRunCount(roundPoints),
            'observedAt': now.toIso8601String(),
          };
        }
        return;
      }

      if (isPitcher) {
        final milestone = _completedKboPitcherInningMilestone(roundPoints);
        final previousMilestone =
            (previous['pitcherMilestone'] as num?)?.toInt() ??
            int.tryParse('${previous['pitcherMilestone'] ?? ''}') ??
            0;
        final previousDisplayedScore =
            (previous['displayedScore'] as num?)?.toDouble() ??
            double.tryParse('${previous['displayedScore'] ?? ''}') ??
            0.0;
        if (milestone > previousMilestone) {
          final skippedMilestones =
              previousMilestone > 0 && milestone > previousMilestone + 1;
          final missingBaseline = previousMilestone <= 0 && milestone > 1;
          if (skippedMilestones || missingBaseline) {
            nextFptsState[stateKey] = <String, dynamic>{
              'type': 'kbo_pitcher',
              'pitcherMilestone': milestone,
              'displayedScore': displayedScore,
              'observedAt': now.toIso8601String(),
            };
            return;
          }
          final pushDisplayedScore = _roundFantasyNotificationScore(
            displayedScore - previousDisplayedScore,
          );
          if (pushDisplayedScore > 0.001 && canEmitRealtime) {
            addEntry(
              _FantasyNotificationEntry(
                id: 'fpts_pitcher:${draft.leagueId}:$round:${_playerSlotIdentity(slot)}:$milestone',
                kind: 'fpts',
                leagueId: draft.leagueId,
                leagueName: draft.leagueName,
                isSoccer: false,
                title: '${draft.leagueName} Fpts 업데이트⚾️💥',
                message: _buildBaseballPitcherFptsNotificationMessage(
                  playerName: slot.name,
                  displayedScore: pushDisplayedScore,
                ),
                createdAt: now,
              ),
            );
          }
          nextFptsState[stateKey] = <String, dynamic>{
            'type': 'kbo_pitcher',
            'pitcherMilestone': milestone,
            'displayedScore': displayedScore,
            'observedAt': now.toIso8601String(),
          };
          return;
        }
        nextFptsState[stateKey] = <String, dynamic>{
          'type': 'kbo_pitcher',
          'pitcherMilestone': previousMilestone,
          'displayedScore': previousDisplayedScore,
          'observedAt': now.toIso8601String(),
        };
        return;
      }

      final homeRuns = _kboHomeRunCount(roundPoints);
      final previousHomeRuns =
          (previous['homeRuns'] as num?)?.toInt() ??
          int.tryParse('${previous['homeRuns'] ?? ''}') ??
          0;
      if (homeRuns > previousHomeRuns && canEmitRealtime) {
        final runValue = _kboHomeRunRunValue(roundPoints);
        if (runValue > 0) {
          addEntry(
            _FantasyNotificationEntry(
              id: 'fpts_hr:${draft.leagueId}:$round:${_playerSlotIdentity(slot)}:$homeRuns',
              kind: 'fpts',
              leagueId: draft.leagueId,
              leagueName: draft.leagueName,
              isSoccer: false,
              title: '${draft.leagueName} Fpts 업데이트⚾️💥',
              message: _buildBaseballHomeRunNotificationMessage(
                playerName: slot.name,
                runValue: runValue,
              ),
              createdAt: now,
            ),
          );
        }
      }
      nextFptsState[stateKey] = <String, dynamic>{
        'type': 'kbo_hitter',
        'homeRuns': homeRuns,
        'observedAt': now.toIso8601String(),
      };
    }

    for (final draft in drafts) {
      final myTeam = _myFantasyTeamForDraft(draft);
      if (myTeam == null) continue;

      final currentRound = _currentFantasyRoundAt(draft, now);
      final lockState = _fantasyRosterLockStateForDraft(draft, now: now);
      final currentPhase = lockState.phase;
      final currentLocked = lockState.hasLockedPlayers;
      final rosterTimingClubs = draft.isSoccer
          ? const <String>{}
          : (currentPhase == _FantasyRosterLockPhase.preLock
                ? lockState.upcomingLockClubs
                : lockState.lockedClubs);
      final affectedLockedStartingPlayers = draft.isSoccer
          ? const <String>[]
          : _kboLockedStartingPlayerNamesForNotification(
              myTeam,
              rosterTimingClubs,
            );
      if (draft.isSoccer || draft.fantasyReady) {
        final previous = rosterState[draft.leagueId];
        final previousMap = previous is Map
            ? Map<String, dynamic>.from(previous.cast<Object?, Object?>())
            : null;
        final previousPhase = _fantasyRosterLockPhaseFromState(previousMap);
        final previousLocked =
            previousMap?['locked'] == true ||
            previousPhase == _FantasyRosterLockPhase.locked;
        final previousRound = previousMap?['round'] is int
            ? previousMap!['round'] as int
            : int.tryParse('${previousMap?['round'] ?? ''}') ?? 0;
        final lockStartsAtUtc = lockState.locksAtUtc;
        final lockSoonCreatedAt = lockStartsAtUtc?.subtract(
          const Duration(minutes: 30),
        );

        if (lockStartsAtUtc != null) {
          final lockWarningLead = lockStartsAtUtc.difference(now.toUtc());
          if (lockWarningLead > Duration.zero &&
              lockWarningLead <= const Duration(minutes: 30) &&
              (draft.isSoccer || affectedLockedStartingPlayers.isNotEmpty)) {
            addEntry(
              _FantasyNotificationEntry(
                id: 'lock_soon:${draft.leagueId}:$currentRound:${lockStartsAtUtc.millisecondsSinceEpoch}',
                kind: 'roster_lock_soon',
                leagueId: draft.leagueId,
                leagueName: draft.leagueName,
                isSoccer: draft.isSoccer,
                title: '로스터 잠금 예정🔒',
                message: draft.isSoccer
                    ? '${draft.leagueName} 로스터가 30분 내 잠깁니다.'
                    : _buildKboRosterTimingNotificationMessage(
                        leagueName: draft.leagueName,
                        playerNames: affectedLockedStartingPlayers,
                        isSoon: true,
                      ),
                createdAt: lockSoonCreatedAt ?? now,
              ),
            );
          }
        }

        if (previousMap == null) {
          if (currentLocked &&
              (draft.isSoccer || affectedLockedStartingPlayers.isNotEmpty)) {
            addEntry(
              _FantasyNotificationEntry(
                id: 'lock:${draft.leagueId}:$currentRound',
                kind: 'roster_lock',
                leagueId: draft.leagueId,
                leagueName: draft.leagueName,
                isSoccer: draft.isSoccer,
                title: '로스터 잠금🔒',
                message: draft.isSoccer
                    ? '${draft.leagueName} 로스터가 잠겼습니다.'
                    : _buildKboRosterTimingNotificationMessage(
                        leagueName: draft.leagueName,
                        playerNames: affectedLockedStartingPlayers,
                        isSoon: false,
                      ),
                createdAt: lockStartsAtUtc ?? now,
              ),
            );
          }
        } else {
          final roundChanged = previousRound != currentRound;
          final becameLocked =
              currentLocked && (roundChanged || !previousLocked);
          final becameUnlocked = previousLocked && !currentLocked;

          if (becameLocked &&
              (draft.isSoccer || affectedLockedStartingPlayers.isNotEmpty)) {
            addEntry(
              _FantasyNotificationEntry(
                id: 'lock:${draft.leagueId}:$currentRound',
                kind: 'roster_lock',
                leagueId: draft.leagueId,
                leagueName: draft.leagueName,
                isSoccer: draft.isSoccer,
                title: '로스터 잠금🔒',
                message: draft.isSoccer
                    ? '${draft.leagueName} 로스터가 잠겼습니다.'
                    : _buildKboRosterTimingNotificationMessage(
                        leagueName: draft.leagueName,
                        playerNames: affectedLockedStartingPlayers,
                        isSoon: false,
                      ),
                createdAt: lockStartsAtUtc ?? now,
              ),
            );
          } else if (becameUnlocked) {
            addEntry(
              _FantasyNotificationEntry(
                id: 'unlock:${draft.leagueId}:${max(previousRound, 1)}',
                kind: 'roster_unlock',
                leagueId: draft.leagueId,
                leagueName: draft.leagueName,
                isSoccer: draft.isSoccer,
                title: '로스터 잠금 해제🔓',
                message: '${draft.leagueName} 로스터 잠금이 해제되었습니다.',
                createdAt: lockState.unlocksAtUtc ?? now,
              ),
            );
          }
        }

        rosterState[draft.leagueId] = <String, dynamic>{
          'locked': currentLocked,
          'phase': _fantasyRosterLockPhaseStorageValue(currentPhase),
          'round': currentRound,
        };
      }

      final round = currentRound;
      if (round <= 0) continue;
      if (!draft.isSoccer && !_kboFantasyRoundHasStarted(draft, round, now)) {
        continue;
      }

      if (draft.isSoccer) {
        for (final player in myTeam.starting) {
          final score = _fantasyPlayerRoundScore(
            player,
            round,
            isSoccer: true,
            draft: draft,
            team: myTeam,
          );
          final slot = player.toPlayerSlot();
          trackFptsEntry(
            draft: draft,
            round: round,
            slot: slot,
            score: score,
            title: '${slot.name} Fpts 알림',
            message:
                '${draft.leagueName} Round $round에서 ${_withKoreanParticle(slot.name, withBatchim: '이', withoutBatchim: '가')} ${score.toStringAsFixed(1)} Fpts를 기록했습니다.',
          );
        }
      } else {
        final absoluteRound = _mappedKboRoundForFantasyRound(draft, round);
        final uniqueSlots = <String, _PlayerSlot>{
          for (final player in myTeam.starting)
            _playerSlotIdentity(player.toPlayerSlot()): player.toPlayerSlot(),
        };
        const batchSize = 2;
        final pending = uniqueSlots.values.where((slot) {
          return _cachedKboRoundPointsForPlayer(
                playerName: slot.name,
                club: _normalizeKboDraftClub(slot.club),
                preferredNumber: slot.number,
                preferredPosition: slot.position,
              ) ==
              null;
        }).toList();
        for (var start = 0; start < pending.length; start += batchSize) {
          final end = min(start + batchSize, pending.length);
          final batch = pending.sublist(start, end);
          await Future.wait(
            batch.map(
              (slot) => _loadKboRoundPointsForPlayerShared(
                playerName: slot.name,
                club: _normalizeKboDraftClub(slot.club),
                preferredNumber: slot.number,
                preferredPosition: slot.position,
                targetRounds: <int>{absoluteRound},
              ),
            ),
          );
        }
        for (final slot in uniqueSlots.values) {
          final roundPoints = _cachedKboRoundPointsForPlayer(
            playerName: slot.name,
            club: _normalizeKboDraftClub(slot.club),
            preferredNumber: slot.number,
            preferredPosition: slot.position,
          );
          if (roundPoints == null) continue;
          final target = roundPoints.cast<_PlayerRoundPoints?>().firstWhere(
            (entry) => entry?.round == absoluteRound,
            orElse: () => null,
          );
          if (target == null) continue;
          trackKboFptsEntry(
            draft: draft,
            round: round,
            slot: slot,
            team: myTeam,
            roundPoints: target,
          );
        }
      }
    }

    List<Map<String, dynamic>> tradeRequests = const <Map<String, dynamic>>[];
    try {
      tradeRequests = await LeagueService.instance
          .getTradeRequestsForCurrentUser();
    } catch (error, stackTrace) {
      debugPrint('syncFantasyNotifications trade request load failed: $error');
      debugPrint('$stackTrace');
    }
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    for (final trade in tradeRequests) {
      final requestId = '${trade['id'] ?? ''}'.trim();
      if (requestId.isEmpty) continue;
      final fromUid = '${trade['fromUid'] ?? ''}';
      final fromTeamName = '${trade['fromTeamName'] ?? ''}';
      final toTeamName = '${trade['toTeamName'] ?? ''}';
      final leagueId = '${trade['leagueId'] ?? ''}';
      final leagueName = '${trade['leagueName'] ?? ''}';
      final createdAt = trade['createdAt'] is Timestamp
          ? (trade['createdAt'] as Timestamp).toDate()
          : now;
      final incoming = currentUid.isNotEmpty && currentUid != fromUid;
      addEntry(
        _FantasyNotificationEntry(
          id: 'trade:$requestId',
          kind: 'trade_request',
          leagueId: leagueId,
          leagueName: leagueName,
          isSoccer: '${trade['sport'] ?? ''}' == 'soccer',
          title: '$leagueName 트레이드 요청🔄',
          message: incoming
              ? '$fromTeamName에서 트레이드 요청을 보냈습니다.'
              : '$toTeamName에 트레이드 요청을 보냈습니다.',
          createdAt: createdAt,
        ),
      );
    }

    entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (markRead) {
      entries = entries.map((entry) => entry.copyWith(isRead: true)).toList();
    }
    entries = _trimFantasyNotificationEntries(entries, now: now);
    await _persistRosterNotificationState(rosterState);
    await _persistFptsNotificationState(nextFptsState);
    await _persistNotificationEntries(entries);
    final unreadCount = entries.where((entry) => !entry.isRead).length;
    if (!mounted) return;
    setState(() {
      _notificationEntries = entries;
      _notificationUnreadCount = unreadCount;
    });
    unawaited(pushNotificationService.syncAppIconBadgeCount(unreadCount));
  }

  Future<void> _openNotificationCenter(BuildContext anchorContext) async {
    if (_isNotificationCenterOpen) return;
    _isNotificationCenterOpen = true;
    final navigatorContext = context;
    try {
      try {
        await _syncFantasyNotifications();
      } catch (error, stackTrace) {
        debugPrint('openNotificationCenter sync failed: $error');
        debugPrint('$stackTrace');
        await _restoreFantasyNotifications();
      }
      if (!mounted) return;
      final entries = List<_FantasyNotificationEntry>.from(
        _notificationEntries,
      );
      final renderBox = anchorContext.findRenderObject() as RenderBox?;
      final overlayBox =
          Overlay.of(anchorContext).context.findRenderObject() as RenderBox?;
      if (renderBox == null || overlayBox == null) return;
      final anchorBottomRight = renderBox.localToGlobal(
        renderBox.size.bottomRight(Offset.zero),
        ancestor: overlayBox,
      );
      const popupWidth = 320.0;
      final overlaySize = overlayBox.size;
      final desiredLeft = anchorBottomRight.dx - popupWidth + 20;
      final left = desiredLeft
          .clamp(12.0, overlaySize.width - popupWidth - 12.0)
          .toDouble();
      final top = min(
        anchorBottomRight.dy + 10,
        overlaySize.height - 24.0,
      ).toDouble();

      final selectedEntry = await showGeneralDialog<_FantasyNotificationEntry>(
        context: navigatorContext,
        barrierDismissible: true,
        barrierLabel: '알림 닫기',
        barrierColor: Colors.transparent,
        transitionDuration: const Duration(milliseconds: 240),
        pageBuilder: (context, animation, secondaryAnimation) {
          return Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () => Navigator.of(context).pop(),
                ),
              ),
              Positioned(
                left: left,
                top: top,
                width: popupWidth,
                child: _FantasyNotificationPopup(
                  entries: entries,
                  onTapEntry: (entry) => Navigator.of(context).pop(entry),
                ),
              ),
            ],
          );
        },
        transitionBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return FadeTransition(
            opacity: Tween<double>(begin: 0.0, end: 1.0).animate(curved),
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, -0.08),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
      );
      await _syncFantasyNotifications(markRead: true);
      if (!mounted || selectedEntry == null) return;
      await _openNotificationEntry(selectedEntry);
    } finally {
      _isNotificationCenterOpen = false;
    }
  }

  Future<void> _handleIncomingNotificationCenterEvent(
    PushNotificationCenterEvent event,
  ) async {
    await _restoreFantasyNotifications();
    if (!mounted) return;

    final activeDraft = _fantasyDraft ?? _resolvedFantasyDraft;
    if (activeDraft == null) return;
    if (event.leagueId.isNotEmpty && activeDraft.leagueId != event.leagueId) {
      return;
    }

    if (event.kind == 'fpts') {
      if (event.isSoccer) {
        await _refreshFantasySoccerScoresAndRebuild(
          includeHistory:
              _section == _MatchSection.league &&
              _needsHistoricalSoccerScoreWarmup(activeDraft),
          forceRefreshLiveData: true,
        );
        return;
      }
      await _loadCachedKboLeagueData();
      await _refreshVisibleKboRoundPoints(forceRefresh: true);
      if (_section == _MatchSection.league) {
        await _primeKboWeeklyRounds(forceRefresh: true, bypassCooldown: true);
      } else {
        _hasPendingKboWeeklyLeaderRefresh = true;
      }
      if (!mounted) return;
      _reapplyPersistedKboVisibleMatchupScores();
      return;
    }

    if (event.kind == 'roster_lock' ||
        event.kind == 'roster_lock_soon' ||
        event.kind == 'roster_unlock') {
      await _primeRosterLockData();
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _playerSearchController = TextEditingController(text: _playerSearch);
    _scrollController.addListener(_maybeExpandPlayersVisibleCount);
    _lockRefreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      if (_hasActiveRosterDrag) return;
      final route = ModalRoute.of(context);
      if (route?.isCurrent != true) return;
      unawaited(_primeRosterLockData());
      if (widget.isSoccer) {
        unawaited(() async {
          await _refreshFantasySoccerScoresAndRebuild(
            includeHistory: false,
            forceRefreshLiveData: true,
          );
          await _syncFantasyNotifications();
        }());
      } else {
        if (_section == _MatchSection.matchup ||
            _section == _MatchSection.roster) {
          unawaited(() async {
            await _refreshVisibleKboRoundPoints(forceRefresh: true);
            await _syncFantasyNotifications();
          }());
        } else {
          unawaited(_syncFantasyNotifications());
        }
        if (_section == _MatchSection.league) {
          unawaited(_primeKboWeeklyRounds());
        }
      }
    });
    _section = widget.initialSection ?? _MatchSection.matchup;
    _notificationCenterEntriesSubscription = pushNotificationService
        .notificationCenterEntriesChanged
        .listen((event) {
          unawaited(_handleIncomingNotificationCenterEvent(event));
        });
    final readyDraft = _findReadyFantasyDraft();
    if (readyDraft != null) {
      _seedFantasyModeForFirstPaint(readyDraft);
      _scheduleInitialMatchDetailBootstrap(readyDraft: readyDraft);
      _scheduleMatchDetailCoachMarks();
      return;
    }
    final random = Random();
    if (widget.isSoccer) {
      _lineup =
          _cachedSoccerLineup ??
          _generateLineup(isSoccer: true, random: random);
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
      unawaited(_loadStandaloneBaseballPlayerPool());
    }
    if (_section == _MatchSection.league) {
      _primeProfileAptsIfNeeded();
    }
    _scheduleInitialMatchDetailBootstrap();
    _scheduleMatchDetailCoachMarks();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted || state != AppLifecycleState.resumed) return;
    unawaited(_restoreFantasyNotifications());
    if (!widget.isSoccer &&
        (_section == _MatchSection.matchup ||
            _section == _MatchSection.roster)) {
      unawaited(_refreshVisibleKboRoundPoints(forceRefresh: true));
    }
    if (!widget.isSoccer && _section == _MatchSection.league) {
      unawaited(_primeKboWeeklyRounds(forceRefresh: true));
    }
    unawaited(_syncFantasyNotifications());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _lockRefreshTimer?.cancel();
    _matchDetailCoachRetryTimer?.cancel();
    _detachMatchDetailCoachCallbacks();
    _playerSearchDebounce?.cancel();
    _notificationCenterEntriesSubscription?.cancel();
    _scrollController.removeListener(_maybeExpandPlayersVisibleCount);
    _playerSearchController.dispose();
    _myPageOpen.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _assignOwnership(Random random) {
    // 1) 내 로스터(18)는 최초 1회만 생성하고 계속 유지
    if (_myTeamRosterOrder.isEmpty) {
      final starting =
          _lineup?.home.expand((p) => p.slots).map((s) => s.name).toList() ??
          [];
      _myTeamRosterOrder
        ..clear()
        ..addAll(starting);
      _myTeamRosterSet
        ..clear()
        ..addAll(starting);

      final benchCandidates =
          _allPlayers.where((p) => !_myTeamRosterSet.contains(p.name)).toList()
            ..shuffle(random);
      for (final p in benchCandidates.take(
        max(0, 18 - _myTeamRosterOrder.length),
      )) {
        _myTeamRosterOrder.add(p.name);
        _myTeamRosterSet.add(p.name);
      }
    }

    // 2) 내 로스터는 항상 내 팀 소유
    for (final n in _myTeamRosterOrder) {
      _playerOwnerCache[n] = PlayerOwnership.myTeam;
    }

    // 3) 상대 라인업은 다른 팀 소유(내 팀으로 고정된 선수는 덮어쓰지 않음)
    final awayNames =
        _lineup?.away.expand((p) => p.slots).map((s) => s.name).toList() ?? [];
    for (final n in awayNames) {
      if (_playerOwnerCache[n] == PlayerOwnership.myTeam) continue;
      _playerOwnerCache[n] = PlayerOwnership.otherTeam;
    }

    // 4) 나머지는 결정론적으로 FA/다른 팀으로 고정
    for (final p in _allPlayers) {
      if (_playerOwnerCache.containsKey(p.name)) continue;
      _playerOwnerCache[p.name] = _isFreeAgent(p.name)
          ? PlayerOwnership.freeAgent
          : PlayerOwnership.otherTeam;
    }
  }

  void _initRosterLists() {
    final ownedPlayers = _allPlayers
        .where((p) => _ownerForSlot(p) == PlayerOwnership.myTeam)
        .toList();
    // 유지된 이름 순서대로 정렬
    final orderedNames = _myTeamRosterOrder.isNotEmpty
        ? List<String>.from(_myTeamRosterOrder)
        : ownedPlayers.map((p) => p.name).toList();
    final ordered = <_PlayerSlot>[];
    for (final n in orderedNames) {
      final hit = ownedPlayers.firstWhere(
        (p) => p.name == n,
        orElse: () => _PlayerSlot(name: n, score: 0, position: 'FW'),
      );
      if (!ordered.contains(hit)) ordered.add(hit);
    }
    // 부족하면 채우기
    for (final p in ownedPlayers) {
      if (!ordered.contains(p)) ordered.add(p);
    }
    _starting = ordered.take(11).toList();
    _bench = ordered.skip(11).take(7).toList();
    _normalizeLeadershipSelection(
      preferredCaptainName: _captainName,
      preferredViceCaptainName: _viceCaptainName,
      preferredCaptainPlayerId: _captainPlayerId,
      preferredViceCaptainPlayerId: _viceCaptainPlayerId,
    );
    _applyStartingToLineup();
    _captureSavedRosterState();
  }

  List<_FantasyStandingRow> _fantasyStandings(_JoinedDraft draft) {
    return _fantasyStandingRowsForDraft(draft);
  }

  double _fantasyProjectedPlayerScore(_FantasyTeamPlayer player) {
    return _fantasyProjectedScoreForSlot(
      player.toPlayerSlot(),
      team: _fantasyMyTeam,
    );
  }

  double _fantasyProjectedTeamScore(
    _FantasyTeamState team, {
    _JoinedDraft? draft,
    int? fantasyRound,
  }) {
    final resolvedDraft = draft;
    final resolvedFantasyRound = fantasyRound;
    if (resolvedDraft != null &&
        !resolvedDraft.isSoccer &&
        resolvedFantasyRound != null) {
      final now = DateTime.now();
      final actualScore = _fantasyTeamRoundScore(
        team,
        resolvedFantasyRound,
        isSoccer: false,
        draft: resolvedDraft,
      );
      if (_kboFantasyTeamRosterRoundComplete(
        resolvedDraft,
        team,
        resolvedFantasyRound,
        now: now,
      )) {
        return actualScore;
      }

      final rosterPlayers = _fantasyProjectionRosterPlayers(team);
      if (rosterPlayers.isNotEmpty) {
        final projectedStarting = _buildBaseballStartingFromRoster(
          rosterPlayers,
          positionOf: (player) => player.position,
          scoreOf: (player) {
            final projected = _fantasyProjectedBaseScoreForSlot(
              player.toPlayerSlot(),
              draft: resolvedDraft,
              fantasyRound: resolvedFantasyRound,
            );
            final current = _fantasyKboBasePlayerRoundScore(
              player,
              draft: resolvedDraft,
              round: resolvedFantasyRound,
            );
            return ((projected - current) * 1000).round();
          },
          identityOf: (player) => _fantasyTeamPlayerIdentity(player),
        );
        if (projectedStarting.isNotEmpty) {
          final projectedStartingIds = projectedStarting
              .map(_fantasyTeamPlayerIdentity)
              .toSet();
          final projectedTeam = _FantasyTeamState(
            uid: team.uid,
            teamName: team.teamName,
            roster: rosterPlayers,
            starting: projectedStarting,
            bench: rosterPlayers
                .where(
                  (player) => !projectedStartingIds.contains(
                    _fantasyTeamPlayerIdentity(player),
                  ),
                )
                .toList(growable: false),
            captainName: team.captainName,
            viceCaptainName: team.viceCaptainName,
            captainPlayerId: team.captainPlayerId,
            viceCaptainPlayerId: team.viceCaptainPlayerId,
            kboRoundScoreStates: team.kboRoundScoreStates,
          );
          return actualScore +
              projectedTeam.starting.fold<double>(0.0, (total, player) {
                final projected = _fantasyProjectedScoreForSlot(
                  player.toPlayerSlot(),
                  team: projectedTeam,
                  draft: resolvedDraft,
                  fantasyRound: resolvedFantasyRound,
                );
                final current = _fantasyKboDisplayedPlayerRoundScore(
                  player,
                  draft: resolvedDraft,
                  round: resolvedFantasyRound,
                  team: projectedTeam,
                );
                return total + (projected - current);
              });
        }
      }

      final state = _kboRoundScoreStateForTeam(team, resolvedFantasyRound);
      if (state != null) {
        return state.bankedScore +
            team.starting.fold<double>(0.0, (total, player) {
              final identity = _fantasyTeamPlayerIdentity(player);
              final projected = _fantasyProjectedScoreForSlot(
                player.toPlayerSlot(),
                team: team,
                draft: resolvedDraft,
                fantasyRound: resolvedFantasyRound,
              );
              final baseline = state.starterBaselines[identity] ?? 0.0;
              return total + (projected - baseline);
            });
      }
    }
    return team.starting.fold<double>(
      0,
      (total, player) =>
          total +
          _fantasyProjectedScoreForSlot(
            player.toPlayerSlot(),
            team: team,
            draft: draft,
            fantasyRound: fantasyRound,
          ),
    );
  }

  double _fantasyProjectedMatchupTeamScore(
    _FantasyTeamState team, {
    required _JoinedDraft draft,
    required int fantasyRound,
    required double actualScore,
  }) {
    if (!draft.isSoccer) {
      final now = DateTime.now();
      if (fantasyRound < _currentFantasyRoundAt(draft, now) ||
          _kboFantasyRoundAllGamesTerminal(draft, fantasyRound, now: now) ||
          _shouldFreezeUnlockedKboRoundScore(draft, fantasyRound, now: now)) {
        return actualScore;
      }
    }
    return _fantasyProjectedTeamScore(
      team,
      draft: draft,
      fantasyRound: fantasyRound,
    );
  }

  bool _isFantasyRoundFinalized(
    _JoinedDraft draft,
    int fantasyRound, {
    DateTime? now,
  }) {
    return _fantasyRoundIsFinalized(draft, fantasyRound, now: now);
  }

  double _fantasyWinRatio({
    required _JoinedDraft draft,
    required int fantasyRound,
    required double myActual,
    required double opponentActual,
    required double myProjected,
    required double opponentProjected,
  }) {
    final finalized = _isFantasyRoundFinalized(draft, fantasyRound);
    final homeScore = finalized ? myActual : myProjected;
    final awayScore = finalized ? opponentActual : opponentProjected;
    if (finalized) {
      if ((homeScore - awayScore).abs() < 0.0001) return 0.5;
      return homeScore > awayScore ? 1.0 : 0.0;
    }
    final total = homeScore + awayScore;
    return total <= 0 ? 0.5 : homeScore / total;
  }

  bool _isCaptainForTeam(_FantasyTeamState? team, _PlayerSlot slot) {
    if (team == null) return false;
    final playerId = _playerSlotIdentity(slot);
    if (team.captainPlayerId?.trim().isNotEmpty == true) {
      return team.captainPlayerId == playerId;
    }
    return team.captainName == slot.name;
  }

  double _fantasyProjectedBaseScoreForSlot(
    _PlayerSlot slot, {
    _JoinedDraft? draft,
    int? fantasyRound,
  }) {
    final resolvedDraft = draft ?? _fantasyDraft;
    final aliasedProjected = resolvedDraft != null && !resolvedDraft.isSoccer
        ? _kboProjectionAliasKeysForSlot(slot)
              .map((key) => _fantasyProjectedScores[key])
              .whereType<double?>()
              .firstWhere((value) => value != null, orElse: () => null)
        : _fantasyProjectedScores[_playerSlotIdentity(slot)];
    final cachedFallback = _cachedProjectedFallbackForSlot(
      slot,
      isSoccer: widget.isSoccer,
    );
    final base =
        aliasedProjected ??
        cachedFallback ??
        ((resolvedDraft == null || resolvedDraft.isSoccer)
            ? _fantasyProjectedSlotScore(slot, isSoccer: widget.isSoccer)
            : 0.0);
    if (widget.isSoccer || resolvedDraft == null || resolvedDraft.isSoccer) {
      return base;
    }

    final leagueData = _cachedKboLeagueData;
    final rawMatches = _fixtureAsList(leagueData?['matches']);
    if (rawMatches.isEmpty) return base;

    final now = DateTime.now();
    final resolvedFantasyRound =
        fantasyRound ?? _effectiveFantasyRoundForDraft(resolvedDraft, now: now);
    if (!_kboFantasyRoundHasStarted(resolvedDraft, resolvedFantasyRound, now)) {
      return base;
    }
    final currentFantasyRound = _effectiveFantasyRoundForDraft(
      resolvedDraft,
      now: now,
    );
    if (resolvedFantasyRound < currentFantasyRound ||
        _kboFantasyRoundAllGamesTerminal(
          resolvedDraft,
          resolvedFantasyRound,
          now: now,
        )) {
      return _fantasyKboBaseScoreForSlot(
        slot,
        draft: resolvedDraft,
        fantasyRound: resolvedFantasyRound,
      );
    }

    final pitcherContext = _kboProjectionAliasKeysForSlot(slot)
        .map((key) => _fantasyPitcherWeeklyProjectionContexts[key])
        .whereType<
          ({
            double opportunityFactor,
            int confirmedStarts,
            int completedStarts,
          })?
        >()
        .firstWhere((value) => value != null, orElse: () => null);
    final currentRoundEntry = _fantasyKboRoundEntryForSlot(
      slot,
      draft: resolvedDraft,
      fantasyRound: resolvedFantasyRound,
    );
    final actual = _fantasyKboBaseScoreForSlot(
      slot,
      draft: resolvedDraft,
      fantasyRound: resolvedFantasyRound,
    );
    final confirmedWeeklyStarts = pitcherContext?.confirmedStarts ?? 0;
    final completedWeeklyStarts = max(
      pitcherContext?.completedStarts ?? 0,
      actual.abs() >= 0.001 ? 1 : 0,
    );
    if (_isKboPitcherSlot(slot) &&
        !_kboPitcherHasRecordedAppearance(currentRoundEntry)) {
      // Weekly starting pitchers should keep their full projection until
      // they actually take the mound.
      return base;
    }
    final leagueRound = _mappedKboRoundForFantasyRound(
      resolvedDraft,
      resolvedFantasyRound,
    );
    final progress = _kboRoundProgressForClubFromMatches(
      rawMatches,
      club: slot.club,
      leagueRound: leagueRound,
      now: now,
    );
    if (_isKboPitcherSlot(slot)) {
      return _liveAdjustedKboPitcherProjectedBaseScore(
        baseProjection: base,
        actualScore: actual,
        roundProgress: progress,
        confirmedWeeklyStarts: confirmedWeeklyStarts,
        completedWeeklyStarts: completedWeeklyStarts,
      );
    }
    return _liveAdjustedKboProjectedBaseScore(
      baseProjection: base,
      actualScore: actual,
      roundProgress: progress,
    );
  }

  double _fantasyProjectedScoreForSlot(
    _PlayerSlot slot, {
    _FantasyTeamState? team,
    _JoinedDraft? draft,
    int? fantasyRound,
  }) {
    final base = _fantasyProjectedBaseScoreForSlot(
      slot,
      draft: draft,
      fantasyRound: fantasyRound,
    );
    return _isCaptainForTeam(team, slot) ? base * 2 : base;
  }

  double _fantasyCurrentKboScoreForSlot(_PlayerSlot slot) {
    final draft = _fantasyDraft;
    if (draft == null || draft.isSoccer) {
      return slot.score.toDouble();
    }
    final fantasyRound = _effectiveFantasyRoundForDraft(draft);
    return _fantasyKboScoreForSlot(
      slot,
      draft: draft,
      fantasyRound: fantasyRound,
      team: _fantasyMyTeam,
    );
  }

  double _fantasyKboBaseScoreForSlot(
    _PlayerSlot slot, {
    required _JoinedDraft draft,
    required int fantasyRound,
  }) {
    if (draft.isSoccer ||
        !_kboFantasyRoundHasStarted(draft, fantasyRound, DateTime.now())) {
      return 0.0;
    }
    final absoluteRound = _mappedKboRoundForFantasyRound(draft, fantasyRound);
    final roundPoints = _cachedKboRoundPointsForPlayer(
      playerName: slot.name,
      club: _normalizeKboDraftClub(slot.club),
      preferredNumber: slot.number,
      preferredPosition: slot.position,
    );
    if (roundPoints == null) return 0.0;
    for (final entry in roundPoints) {
      if (entry.round == absoluteRound) {
        return entry.basePoints;
      }
    }
    return 0.0;
  }

  _PlayerRoundPoints? _fantasyKboRoundEntryForSlot(
    _PlayerSlot slot, {
    required _JoinedDraft draft,
    required int fantasyRound,
  }) {
    if (draft.isSoccer ||
        !_kboFantasyRoundHasStarted(draft, fantasyRound, DateTime.now())) {
      return null;
    }
    final absoluteRound = _mappedKboRoundForFantasyRound(draft, fantasyRound);
    final roundPoints = _cachedKboRoundPointsForPlayer(
      playerName: slot.name,
      club: _normalizeKboDraftClub(slot.club),
      preferredNumber: slot.number,
      preferredPosition: slot.position,
    );
    if (roundPoints == null) return null;
    for (final entry in roundPoints) {
      if (entry.round == absoluteRound) {
        return entry;
      }
    }
    return null;
  }

  bool _kboPitcherHasRecordedAppearance(_PlayerRoundPoints? entry) {
    if (entry == null) return false;
    if (entry.details.isNotEmpty) return true;
    return entry.basePoints != 0.0;
  }

  double _fantasyKboScoreForSlot(
    _PlayerSlot slot, {
    required _JoinedDraft draft,
    required int fantasyRound,
    _FantasyTeamState? team,
  }) {
    if (draft.isSoccer ||
        !_kboFantasyRoundHasStarted(draft, fantasyRound, DateTime.now())) {
      return 0.0;
    }
    final absoluteRound = _mappedKboRoundForFantasyRound(draft, fantasyRound);
    final roundPoints = _cachedKboRoundPointsForPlayer(
      playerName: slot.name,
      club: _normalizeKboDraftClub(slot.club),
      preferredNumber: slot.number,
      preferredPosition: slot.position,
    );
    if (roundPoints == null) return 0.0;
    for (final entry in roundPoints) {
      if (entry.round == absoluteRound) {
        return _isCaptainForTeam(team, slot)
            ? entry.displayedPoints * 2
            : entry.displayedPoints;
      }
    }
    return 0.0;
  }

  double _fantasyDisplayedKboTeamScore(
    _FantasyTeamState team, {
    required _JoinedDraft draft,
    required int fantasyRound,
  }) {
    return _fantasyTeamRoundScore(
      team,
      fantasyRound,
      isSoccer: false,
      draft: draft,
    );
  }

  void _cacheVisibleKboMatchupScores(
    _JoinedDraft draft, {
    required int fantasyRound,
  }) {
    final matchup = _fantasyMatchup;
    if (matchup == null) return;
    _cacheKboVisibleTeamScoresForRound(draft, fantasyRound, <String, double>{
      _fantasyTeamIdentity(
        uid: matchup.myTeam.uid,
        teamName: matchup.myTeam.teamName,
      ): _fantasyDisplayedKboTeamScore(
        matchup.myTeam,
        draft: draft,
        fantasyRound: fantasyRound,
      ),
      _fantasyTeamIdentity(
        uid: matchup.opponent.uid,
        teamName: matchup.opponent.teamName,
      ): _fantasyDisplayedKboTeamScore(
        matchup.opponent,
        draft: draft,
        fantasyRound: fantasyRound,
      ),
    });
  }

  Future<void> _refreshVisibleKboRoundPoints({
    bool forceRefresh = false,
  }) async {
    final draft = _fantasyDraft;
    if (draft == null || draft.isSoccer) return;
    final now = DateTime.now();
    final round = _effectiveFantasyRoundForDraft(draft, now: now);
    final absoluteRound = _mappedKboRoundForFantasyRound(draft, round);
    final cacheKey = _fantasyProjectedScoresCacheKeyForRound(draft, round);
    final inFlight = _visibleKboRoundPointsFuture;
    if (inFlight != null && _visibleKboRoundPointsFutureKey == cacheKey) {
      return inFlight;
    }
    if (!forceRefresh && _visibleKboRoundPointsLoadedKey == cacheKey) {
      return;
    }
    if (!_kboFantasyRoundHasStarted(draft, round, now)) return;
    final future =
        () async {
          if (_shouldFreezeUnlockedKboRoundScore(draft, round, now: now)) {
            final homeState = homeKey.currentState;
            if (homeState != null) {
              final updatedDraft = await homeState
                  ._ensureUnlockedKboMatchupScoreSnapshotsForDraft(draft);
              if (!mounted) return;
              if (!identical(updatedDraft, draft)) {
                setState(() {
                  _resolvedFantasyDraft = updatedDraft;
                  _fantasyMatchup = _selectedFantasyMatchupForDraft(
                    updatedDraft,
                  );
                  _fantasyMyTeam = _myFantasyTeamForDraft(updatedDraft);
                });
              }
            }
            _cacheVisibleKboMatchupScores(draft, fantasyRound: round);
            _visibleKboRoundPointsLoadedKey = cacheKey;
            return;
          }

          final slots = <String, _PlayerSlot>{};
          if (_section == _MatchSection.matchup && _fantasyMatchup != null) {
            for (final team in [
              _fantasyMatchup!.myTeam,
              _fantasyMatchup!.opponent,
            ]) {
              for (final player in team.starting) {
                final slot = player.toPlayerSlot();
                slots[_playerSlotIdentity(slot)] = slot;
              }
              for (final player in team.bench) {
                final slot = player.toPlayerSlot();
                slots[_playerSlotIdentity(slot)] = slot;
              }
            }
          } else if (_fantasyMyTeam != null) {
            for (final player in _fantasyMyTeam!.roster) {
              final slot = player.toPlayerSlot();
              slots[_playerSlotIdentity(slot)] = slot;
            }
          }
          if (slots.isEmpty) return;

          const batchSize = 2;
          final values = slots.values
              .where(
                (slot) => !_hasCachedKboRoundPointsForSlot(slot, absoluteRound),
              )
              .toList();
          if (values.isEmpty) {
            _visibleKboRoundPointsLoadedKey = cacheKey;
            _cacheVisibleKboMatchupScores(draft, fantasyRound: round);
            if (!mounted) return;
            setState(() {});
            return;
          }
          for (var start = 0; start < values.length; start += batchSize) {
            final end = min(start + batchSize, values.length);
            final batch = values.sublist(start, end);
            await Future.wait(
              batch.map(
                (slot) => _loadKboRoundPointsForPlayerShared(
                  playerName: slot.name,
                  club: _normalizeKboDraftClub(slot.club),
                  preferredNumber: slot.number,
                  preferredPosition: slot.position,
                  forceRefresh:
                      forceRefresh &&
                      !_hasCachedKboRoundPointsForSlot(slot, absoluteRound),
                  // Shared KBO round caches are keyed by absolute KBO round,
                  // not the draft-relative fantasy round used by matchup UI.
                  targetRounds: <int>{absoluteRound},
                ),
              ),
            );
          }
          _visibleKboRoundPointsLoadedKey = cacheKey;
          _cacheVisibleKboMatchupScores(draft, fantasyRound: round);
          if (!mounted) return;
          setState(() {});
        }().whenComplete(() {
          if (_visibleKboRoundPointsFutureKey == cacheKey) {
            _visibleKboRoundPointsFuture = null;
          }
        });
    _visibleKboRoundPointsFutureKey = cacheKey;
    _visibleKboRoundPointsFuture = future;
    return future;
  }

  String _fantasyProjectedScoresCacheKeyForRound(
    _JoinedDraft draft,
    int fantasyRound,
  ) => _fantasyProjectedScoresCacheKeyForDraftRound(draft, fantasyRound);

  String _fantasyProjectedScoresCacheKey(_JoinedDraft draft) {
    final round = _effectiveFantasyRoundForDraft(draft);
    return _fantasyProjectedScoresCacheKeyForRound(draft, round);
  }

  bool _hasReadyFantasyProjectedScores(
    _JoinedDraft draft, {
    required int fantasyRound,
  }) {
    if (draft.isSoccer) return true;
    if (_baseballDraftNeedsMetadataHydration(draft)) return false;
    final projectedKey = _fantasyProjectedScoresCacheKeyForRound(
      draft,
      fantasyRound,
    );
    if (_fantasyProjectedScoresKey != projectedKey ||
        _fantasyProjectedScores.isEmpty) {
      return false;
    }
    if (!_hasDisplayableFantasyProjectedScores(
      draft,
      fantasyRound: fantasyRound,
    )) {
      return false;
    }
    final now = DateTime.now();
    if (!_kboFantasyRoundHasStarted(draft, fantasyRound, now)) {
      return true;
    }
    return _visibleKboRoundPointsLoadedKey == projectedKey &&
        _fantasyPitcherWeeklyProjectionContextsKey == projectedKey;
  }

  bool _hasDisplayableFantasyProjectedScores(
    _JoinedDraft draft, {
    required int fantasyRound,
  }) {
    if (draft.isSoccer) return true;
    final projectedKey = _fantasyProjectedScoresCacheKeyForRound(
      draft,
      fantasyRound,
    );
    if (_fantasyProjectedScoresKey != projectedKey ||
        _fantasyProjectedScores.isEmpty) {
      return false;
    }
    final sourceTeams = _projectionSourceTeamsForDraftRound(
      draft,
      fantasyRound: fantasyRound,
    );
    if (sourceTeams.isEmpty) return false;
    for (final team in sourceTeams) {
      for (final player in team.roster) {
        final slot = player.toPlayerSlot();
        final hasProjection = draft.isSoccer
            ? _fantasyProjectedScores.containsKey(_playerSlotIdentity(slot))
            : _kboProjectionAliasKeysForSlot(
                slot,
              ).any(_fantasyProjectedScores.containsKey);
        if (!hasProjection) {
          return false;
        }
      }
    }
    return true;
  }

  void _applyPersistedFantasyProjectedScoresEntry(
    _JoinedDraft draft, {
    bool rebuild = true,
  }) {
    if (draft.isSoccer) return;
    final cacheKey = _fantasyProjectedScoresCacheKey(draft);
    final entry = _persistedFantasyProjectedScoresEntries[cacheKey];
    if (entry == null || entry.scores.isEmpty) return;
    if (_fantasyProjectedScoresFreshKey == cacheKey &&
        _fantasyProjectedScoresKey == cacheKey &&
        _fantasyProjectedScores.isNotEmpty) {
      return;
    }
    if (_fantasyProjectedScoresKey == cacheKey &&
        _fantasyProjectedScores.isNotEmpty) {
      return;
    }
    if (rebuild) {
      if (!mounted) return;
      setState(() {
        _fantasyProjectedScores = Map<String, double>.from(entry.scores);
        _fantasyPitcherWeeklyProjectionContexts =
            const <
              String,
              ({
                double opportunityFactor,
                int confirmedStarts,
                int completedStarts,
              })
            >{};
        _fantasyProjectedScoresKey = cacheKey;
        _fantasyProjectedScoresFreshKey = '';
        _fantasyPitcherWeeklyProjectionContextsKey = '';
      });
      return;
    }
    _fantasyProjectedScores = Map<String, double>.from(entry.scores);
    _fantasyPitcherWeeklyProjectionContexts =
        const <
          String,
          ({double opportunityFactor, int confirmedStarts, int completedStarts})
        >{};
    _fantasyProjectedScoresKey = cacheKey;
    _fantasyProjectedScoresFreshKey = '';
    _fantasyPitcherWeeklyProjectionContextsKey = '';
  }

  Future<void> _primePersistedFantasyProjectedScores(
    _JoinedDraft draft, {
    bool rebuild = true,
  }) async {
    _applyPersistedFantasyProjectedScoresEntry(draft, rebuild: rebuild);
    if (_didHydratePersistedFantasyProjectedScoresCache) return;
    await _restorePersistedFantasyProjectedScoresCache();
    if (!mounted) return;
    final activeDraft = _fantasyDraft;
    if (activeDraft == null ||
        activeDraft.leagueId != draft.leagueId ||
        activeDraft.isSoccer != draft.isSoccer) {
      return;
    }
    _applyPersistedFantasyProjectedScoresEntry(activeDraft, rebuild: rebuild);
  }

  Future<void> _ensureFantasyProjectedScores(_JoinedDraft draft) {
    final fantasyRound = _effectiveFantasyRoundForDraft(draft);
    final cacheKey = _fantasyProjectedScoresCacheKeyForRound(
      draft,
      fantasyRound,
    );
    final inFlight = _fantasyProjectedScoresFuture;
    if (inFlight != null && _fantasyProjectedScoresKey == cacheKey) {
      return inFlight;
    }
    if (_hasReadyFantasyProjectedScores(draft, fantasyRound: fantasyRound) &&
        _fantasyProjectedScoresFreshKey == cacheKey) {
      return Future.value();
    }
    final future =
        () async {
          final bundle = await _loadFantasyProjectedScores(draft);
          final projections = bundle.scores;
          final pitcherContexts = bundle.pitcherContexts;
          if (!mounted) return;
          if (_fantasyProjectedScoresCacheKey(draft) != cacheKey) return;
          _persistedFantasyProjectedScoresEntries[cacheKey] =
              _PersistedFantasyProjectedScoresEntry(
                updatedAt: DateTime.now(),
                scores: Map<String, double>.from(projections),
              );
          unawaited(_persistFantasyProjectedScoresCache());
          setState(() {
            _fantasyProjectedScores = projections;
            _fantasyPitcherWeeklyProjectionContexts = pitcherContexts;
            _fantasyProjectedScoresKey = cacheKey;
            _fantasyProjectedScoresFreshKey = cacheKey;
            _fantasyPitcherWeeklyProjectionContextsKey = cacheKey;
          });
        }().whenComplete(() {
          if (_fantasyProjectedScoresKey == cacheKey) {
            _fantasyProjectedScoresFuture = null;
          }
        });
    _fantasyProjectedScoresKey = cacheKey;
    _fantasyProjectedScoresFuture = future;
    return future;
  }

  Future<
    ({
      Map<String, double> scores,
      Map<
        String,
        ({double opportunityFactor, int confirmedStarts, int completedStarts})
      >
      pitcherContexts,
    })
  >
  _loadFantasyProjectedScores(_JoinedDraft draft) async {
    if (!draft.isSoccer) {
      return _loadKboFantasyProjectedScores(draft);
    }
    await _restorePersistedKLeaguePlayerAptsCache();
    await _restorePersistedKLeaguePlayerRoundPointsCache();
    final leagueData = await _loadCachedKLeagueLeagueData();
    final rawFixtures = _fixtureAsList(leagueData['fixtures']);
    final targetFantasyRound = _effectiveFantasyRoundForDraft(draft);
    final targetKLeagueRound = _mappedKLeagueRoundForFantasyRound(
      draft,
      targetFantasyRound,
      rawFixtures,
    );
    final teamFormFactors = _teamFormFactorsForProjectedFpts(
      rawFixtures,
      targetKLeagueRound,
    );
    final sourceTeams = _projectionSourceTeamsForDraftRound(
      draft,
      fantasyRound: targetFantasyRound,
    );

    final uniquePlayers = <String, _PlayerSlot>{};
    for (final team in sourceTeams) {
      for (final player in team.roster) {
        final slot = player.toPlayerSlot();
        uniquePlayers[_playerSlotIdentity(slot)] = slot;
      }
    }

    final pending = uniquePlayers.values.where((slot) {
      final cached = _cachedKLeagueRoundPointsForPlayer(
        playerName: slot.name,
        club: _slotClub(slot),
        preferredNumber: slot.number,
      );
      return cached == null;
    }).toList();

    const batchSize = 2;
    for (var start = 0; start < pending.length; start += batchSize) {
      final end = min(start + batchSize, pending.length);
      final batch = pending.sublist(start, end);
      await Future.wait(
        batch.map(
          (slot) => _loadKLeagueRoundPointsForPlayerShared(
            playerName: slot.name,
            club: _slotClub(slot),
            preferredNumber: slot.number,
          ),
        ),
      );
    }

    final projections = <String, double>{};
    for (final slot in uniquePlayers.values) {
      final roundPoints =
          _cachedKLeagueRoundPointsForPlayer(
            playerName: slot.name,
            club: _slotClub(slot),
            preferredNumber: slot.number,
          ) ??
          const <_PlayerRoundPoints>[];
      projections[_playerSlotIdentity(slot)] = _projectKLeagueFptsForSlot(
        slot,
        roundPoints,
        targetRound: targetKLeagueRound,
        teamFormFactor: teamFormFactors[_slotClub(slot)] ?? 1.0,
      );
    }
    return (
      scores: projections,
      pitcherContexts:
          const <
            String,
            ({
              double opportunityFactor,
              int confirmedStarts,
              int completedStarts,
            })
          >{},
    );
  }

  Future<
    ({
      Map<String, double> scores,
      Map<
        String,
        ({double opportunityFactor, int confirmedStarts, int completedStarts})
      >
      pitcherContexts,
    })
  >
  _loadKboFantasyProjectedScores(_JoinedDraft draft) async {
    await _restorePersistedKLeaguePlayerAptsCache();
    await _restorePersistedKLeaguePlayerRoundPointsCache();
    await _restorePersistedKLeaguePlayerAptsCache();
    await _restorePersistedKLeaguePlayerRoundPointsCache();
    final leagueData = await _loadCachedKboLeagueData();
    final rawMatches = _fixtureAsList(leagueData['matches']);
    final targetFantasyRound = _effectiveFantasyRoundForDraft(draft);
    final targetKboRound = _mappedKboRoundForFantasyRound(
      draft,
      targetFantasyRound,
    );
    final teamFormFactors = _kboTeamFormFactorsForProjectedFpts(
      rawMatches,
      targetKboRound,
    );
    final opponentFormFactors = _kboOpponentFormFactorsForProjectedFpts(
      rawMatches,
      targetKboRound,
      teamFormFactors,
    );

    final sourceTeams = _projectionSourceTeamsForDraftRound(
      draft,
      fantasyRound: targetFantasyRound,
    );

    final uniquePlayers = <String, _PlayerSlot>{};
    for (final team in sourceTeams) {
      for (final player in team.roster) {
        final slot = player.toPlayerSlot();
        uniquePlayers[_playerSlotIdentity(slot)] = slot;
      }
    }

    await _primeKboProjectionSourceDataForSlots(
      uniquePlayers.values,
      targetRound: targetKboRound,
      includeTargetRoundLivePoints: _kboFantasyRoundHasStarted(
        draft,
        targetFantasyRound,
        DateTime.now(),
      ),
    );
    final pitcherContexts = await _loadKboPitcherWeeklyProjectionContexts(
      uniquePlayers.values,
      rawMatches: rawMatches,
      targetRound: targetKboRound,
    );
    final pitcherContextsByAlias =
        <
          String,
          ({double opportunityFactor, int confirmedStarts, int completedStarts})
        >{};
    for (final slot in uniquePlayers.values) {
      final context = pitcherContexts[_playerSlotIdentity(slot)];
      if (context == null) continue;
      _storeKboPitcherProjectionContextForSlot(
        pitcherContextsByAlias,
        slot,
        context,
      );
    }

    final projections = <String, double>{};
    for (final slot in uniquePlayers.values) {
      final roundPoints =
          _cachedKboRoundPointsForPlayer(
            playerName: slot.name,
            club: _normalizeKboDraftClub(slot.club),
            preferredNumber: slot.number,
            preferredPosition: slot.position,
          ) ??
          const <_PlayerRoundPoints>[];
      final club = _normalizeKboDraftClub(slot.club);
      final projected = _projectKboFptsForSlot(
        slot,
        roundPoints,
        targetRound: targetKboRound,
        teamFormFactor: teamFormFactors[club] ?? 1.0,
        opponentFormFactor: opponentFormFactors[club] ?? 1.0,
        pitcherOpportunityFactor:
            pitcherContexts[_playerSlotIdentity(slot)]?.opportunityFactor ??
            1.0,
      );
      _storeKboProjectionValueForSlot(projections, slot, projected);
    }
    return (scores: projections, pitcherContexts: pitcherContextsByAlias);
  }

  Map<String, double> _teamFormFactorsForProjectedFpts(
    List<dynamic> rawFixtures,
    int targetRound,
  ) {
    final byClub = <String, List<({DateTime date, double points})>>{};
    for (final raw in rawFixtures) {
      final map = _fixtureAsMap(raw);
      final round = _roundNumber(
        _fixtureText(_fixtureAsMap(map['league'])['round']),
      );
      if (round <= 0 || round >= targetRound) continue;
      final fixture = _fixtureAsMap(map['fixture']);
      final status = _fixtureAsMap(fixture['status']);
      if (!_isKLeagueFinalStatus(_fixtureText(status['short']))) continue;
      final teams = _fixtureAsMap(map['teams']);
      final goals = _fixtureAsMap(map['goals']);
      final date =
          DateTime.tryParse(_fixtureText(fixture['date'])) ?? DateTime(1970);
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
      final homeGoals = _readNullableInt(goals['home']) ?? 0;
      final awayGoals = _readNullableInt(goals['away']) ?? 0;
      double homePoints = 0;
      double awayPoints = 0;
      if (homeGoals == awayGoals) {
        homePoints = 1;
        awayPoints = 1;
      } else if (homeGoals > awayGoals) {
        homePoints = 3;
      } else {
        awayPoints = 3;
      }
      if (homeClub.isNotEmpty) {
        byClub.putIfAbsent(homeClub, () => <({DateTime date, double points})>[])
          ..add((date: date, points: homePoints));
      }
      if (awayClub.isNotEmpty) {
        byClub.putIfAbsent(awayClub, () => <({DateTime date, double points})>[])
          ..add((date: date, points: awayPoints));
      }
    }

    final factors = <String, double>{};
    byClub.forEach((club, entries) {
      entries.sort((a, b) => b.date.compareTo(a.date));
      final recent = entries.take(5).toList();
      if (recent.isEmpty) {
        factors[club] = 1.0;
        return;
      }
      final averagePoints =
          recent.fold<double>(0, (total, item) => total + item.points) /
          recent.length;
      factors[club] = (0.85 + (averagePoints / 3.0) * 0.30).clamp(0.85, 1.15);
    });
    return factors;
  }

  Map<String, double> _kboTeamFormFactorsForProjectedFpts(
    List<dynamic> rawMatches,
    int targetRound,
  ) {
    final byClub =
        <
          String,
          List<({DateTime date, double resultPoints, double runDiff})>
        >{};
    for (final raw in rawMatches) {
      final match = _fixtureAsMap(raw);
      final matchDate = DateTime.tryParse('${match['date'] ?? ''}');
      if (matchDate == null) continue;
      final round = _kboFantasyRoundForMatchDate(matchDate);
      if (round <= 0 || round >= targetRound) continue;
      if (!_kboMatchMapHasStarted(match)) continue;
      final homeClub = _normalizeKboDraftClub('${match['home'] ?? ''}');
      final awayClub = _normalizeKboDraftClub('${match['away'] ?? ''}');
      final homeScore = (_readNullableInt(match['homeScore']) ?? 0).toDouble();
      final awayScore = (_readNullableInt(match['awayScore']) ?? 0).toDouble();
      if (homeClub.isEmpty || awayClub.isEmpty) continue;
      final homePoints = homeScore > awayScore
          ? 1.0
          : homeScore == awayScore
          ? 0.5
          : 0.0;
      final awayPoints = awayScore > homeScore
          ? 1.0
          : homeScore == awayScore
          ? 0.5
          : 0.0;
      byClub.putIfAbsent(
        homeClub,
        () => <({DateTime date, double resultPoints, double runDiff})>[],
      )..add((
        date: matchDate,
        resultPoints: homePoints,
        runDiff: homeScore - awayScore,
      ));
      byClub.putIfAbsent(
        awayClub,
        () => <({DateTime date, double resultPoints, double runDiff})>[],
      )..add((
        date: matchDate,
        resultPoints: awayPoints,
        runDiff: awayScore - homeScore,
      ));
    }

    final factors = <String, double>{};
    byClub.forEach((club, entries) {
      entries.sort((a, b) => b.date.compareTo(a.date));
      final recent = entries.take(6).toList();
      if (recent.isEmpty) {
        factors[club] = 1.0;
        return;
      }
      final winRate =
          recent.fold<double>(0.0, (sum, item) => sum + item.resultPoints) /
          recent.length;
      final avgRunDiff =
          recent.fold<double>(0.0, (sum, item) => sum + item.runDiff) /
          recent.length;
      final runDiffBoost = (avgRunDiff / 6.0).clamp(-1.0, 1.0) * 0.07;
      factors[club] = (0.88 + winRate * 0.18 + runDiffBoost).clamp(0.84, 1.16);
    });
    return factors;
  }

  Map<String, double> _kboOpponentFormFactorsForProjectedFpts(
    List<dynamic> rawMatches,
    int targetRound,
    Map<String, double> teamFormFactors,
  ) {
    final opponentsByClub = <String, Set<String>>{};
    for (final raw in rawMatches) {
      final match = _fixtureAsMap(raw);
      final matchDate = DateTime.tryParse('${match['date'] ?? ''}');
      if (matchDate == null) continue;
      final round = _kboFantasyRoundForMatchDate(matchDate);
      if (round != targetRound) continue;
      final homeClub = _normalizeKboDraftClub('${match['home'] ?? ''}');
      final awayClub = _normalizeKboDraftClub('${match['away'] ?? ''}');
      if (homeClub.isEmpty || awayClub.isEmpty) continue;
      opponentsByClub.putIfAbsent(homeClub, () => <String>{}).add(awayClub);
      opponentsByClub.putIfAbsent(awayClub, () => <String>{}).add(homeClub);
    }

    final factors = <String, double>{};
    opponentsByClub.forEach((club, opponents) {
      if (opponents.isEmpty) {
        factors[club] = 1.0;
        return;
      }
      final avgOpponentForm =
          opponents.fold<double>(
            0.0,
            (sum, opponent) => sum + (teamFormFactors[opponent] ?? 1.0),
          ) /
          opponents.length;
      factors[club] = (1.0 - (avgOpponentForm - 1.0) * 0.55).clamp(0.90, 1.10);
    });
    return factors;
  }

  double _kboPitcherWeeklyOpportunityFactor({
    required List<DateTime> startedDates,
    required List<DateTime> scheduledDates,
    int confirmedWeeklyStarts = 0,
  }) {
    if (confirmedWeeklyStarts >= 2 || startedDates.length >= 2) {
      return 1.42;
    }
    if (startedDates.isEmpty) {
      return 1.0;
    }

    startedDates.sort();
    scheduledDates.sort();
    final firstStart = startedDates.first;
    final remainingGames = scheduledDates
        .where((date) => date.isAfter(firstStart))
        .toList();
    final hasWeekendWindow = remainingGames.any(
      (date) =>
          date.weekday == DateTime.saturday || date.weekday == DateTime.sunday,
    );

    switch (firstStart.weekday) {
      case DateTime.tuesday:
        return remainingGames.length >= 4 ? 1.34 : 1.28;
      case DateTime.wednesday:
        return remainingGames.length >= 3 ? 1.22 : 1.16;
      case DateTime.thursday:
        return hasWeekendWindow ? 0.95 : 0.98;
      case DateTime.friday:
        return 0.84;
      case DateTime.saturday:
        return 0.76;
      case DateTime.sunday:
        return 0.72;
      default:
        return 1.0;
    }
  }

  Future<Map<String, double>> _loadKboPitcherWeeklyOpportunityFactors(
    Iterable<_PlayerSlot> slots, {
    required List<dynamic> rawMatches,
    required int targetRound,
  }) async {
    final byClub = <String, List<Map<String, dynamic>>>{};
    for (final raw in rawMatches) {
      final match = _fixtureAsMap(raw);
      final matchDate = DateTime.tryParse('${match['date'] ?? ''}');
      if (matchDate == null ||
          _kboFantasyRoundForMatchDate(matchDate) != targetRound) {
        continue;
      }
      final homeClub = _normalizeKboDraftClub('${match['home'] ?? ''}');
      final awayClub = _normalizeKboDraftClub('${match['away'] ?? ''}');
      if (homeClub.isNotEmpty) {
        byClub.putIfAbsent(homeClub, () => <Map<String, dynamic>>[]).add(match);
      }
      if (awayClub.isNotEmpty) {
        byClub.putIfAbsent(awayClub, () => <Map<String, dynamic>>[]).add(match);
      }
    }

    final result = <String, double>{};
    final seen = <String>{};
    final detailFutures = <int, Future<Map<String, dynamic>>>{};
    for (final slot in slots) {
      if (!_isKboPitcherSlot(slot)) continue;
      final identity = _playerSlotIdentity(slot);
      if (!seen.add(identity)) continue;

      final normalizedClub = _normalizeKboDraftClub(slot.club);
      final clubMatches =
          List<Map<String, dynamic>>.from(
            byClub[normalizedClub] ?? const <Map<String, dynamic>>[],
          )..sort((a, b) {
            final aDate =
                DateTime.tryParse('${a['date'] ?? ''}') ?? DateTime(1970);
            final bDate =
                DateTime.tryParse('${b['date'] ?? ''}') ?? DateTime(1970);
            return aDate.compareTo(bDate);
          });
      if (clubMatches.isEmpty) {
        result[identity] = 1.0;
        continue;
      }

      final scheduledDates = clubMatches
          .map((match) => DateTime.tryParse('${match['date'] ?? ''}'))
          .whereType<DateTime>()
          .toList();
      final startedDates = <DateTime>[];
      final confirmedStartDateKeys = <String>{};

      for (final match in clubMatches) {
        final matchId = _readNullableInt(match['id']);
        final matchDate = DateTime.tryParse('${match['date'] ?? ''}');
        if (matchId == null || matchId <= 0 || matchDate == null) continue;
        try {
          final shouldForceRefresh = !_isKboTerminalStatus(
            '${match['status'] ?? ''}',
          );
          final detail = await detailFutures.putIfAbsent(
            matchId,
            () => _loadCachedKboMatchDetail(
              matchId,
              forceRefresh: shouldForceRefresh,
              fantasyRound: targetRound,
            ),
          );
          final playerStats = _fixtureAsList(detail['playerStats']);
          final matchedStat = playerStats
              .map(_fixtureAsMap)
              .cast<Map<String, dynamic>?>()
              .firstWhere(
                (entry) =>
                    entry != null &&
                    _kboPlayerStatMatchesProfile(
                      entry,
                      slot.name,
                      meta: (
                        position: _normalizeKboProfilePosition(slot.position),
                        club: normalizedClub,
                        number: slot.number,
                      ),
                    ),
                orElse: () => null,
              );
          if (matchedStat?['started'] == true) {
            startedDates.add(matchDate);
            confirmedStartDateKeys.add(
              DateTime(
                matchDate.year,
                matchDate.month,
                matchDate.day,
              ).toIso8601String(),
            );
          }
          final detailMatch = _fixtureAsMap(detail['match']);
          final lineups = _fixtureAsList(detail['lineups']);
          final homeClub = _normalizeKboDraftClub(
            '${detailMatch['home'] ?? ''}',
          );
          final awayClub = _normalizeKboDraftClub(
            '${detailMatch['away'] ?? ''}',
          );
          final detailTeam = normalizedClub == homeClub
              ? '${detailMatch['home'] ?? ''}'
              : normalizedClub == awayClub
              ? '${detailMatch['away'] ?? ''}'
              : '';
          if (detailTeam.isNotEmpty) {
            final lineup = _kboLineupForTeam(lineups, detailTeam);
            final starterPitcher = _fixtureText(lineup['starterPitcher']);
            if (_kboStarterPitcherMatchesSlot(starterPitcher, slot)) {
              confirmedStartDateKeys.add(
                DateTime(
                  matchDate.year,
                  matchDate.month,
                  matchDate.day,
                ).toIso8601String(),
              );
            }
          }
        } catch (_) {
          // Leave the factor neutral if a single match detail is unavailable.
        }
      }

      result[identity] = _kboPitcherWeeklyOpportunityFactor(
        startedDates: startedDates,
        scheduledDates: scheduledDates,
        confirmedWeeklyStarts: confirmedStartDateKeys.length,
      );
    }
    return result;
  }

  double _projectKLeagueFptsForSlot(
    _PlayerSlot slot,
    List<_PlayerRoundPoints> roundPoints, {
    required int targetRound,
    required double teamFormFactor,
  }) {
    final previous =
        roundPoints.where((entry) => entry.round < targetRound).toList()
          ..sort((a, b) => b.round.compareTo(a.round));
    final fallback =
        _cachedKLeaguePlayerApts[_slotAptsKey(slot)] ??
        _fantasyProjectedSlotScore(slot, isSoccer: true);
    if (previous.isEmpty) {
      return (fallback * teamFormFactor).clamp(0.0, 25.0);
    }

    final recent = previous.take(5).toList();
    const weights = <double>[0.34, 0.26, 0.18, 0.14, 0.08];
    var weightedTotal = 0.0;
    var weightTotal = 0.0;
    for (var i = 0; i < recent.length; i++) {
      weightedTotal += recent[i].basePoints * weights[i];
      weightTotal += weights[i];
    }
    final weightedRecent = weightTotal > 0
        ? weightedTotal / weightTotal
        : fallback;
    final seasonApts = _kLeagueAptsFromRoundPoints(previous) ?? fallback;
    final recentTwo = recent.take(2).toList();
    final previousThree = recent.skip(2).take(3).toList();
    final recentTwoAvg = recentTwo.isEmpty
        ? weightedRecent
        : recentTwo.fold<double>(0, (t, e) => t + e.basePoints) /
              recentTwo.length;
    final previousThreeAvg = previousThree.isEmpty
        ? weightedRecent
        : previousThree.fold<double>(0, (t, e) => t + e.basePoints) /
              previousThree.length;
    final trendBonus = (recentTwoAvg - previousThreeAvg) * 0.25;
    final appearanceRate =
        recent.where((entry) => entry.appeared).length / recent.length;
    final consecutiveNoShows = recent
        .take(2)
        .where((entry) => !entry.appeared)
        .length;
    final hadRecentRedCard = recent
        .take(1)
        .any(
          (entry) => entry.details.any(
            (detail) => detail.label == '레드카드' && detail.points < 0,
          ),
        );
    if (hadRecentRedCard) return 0.0;
    final yellowCardCount = recent.fold<double>(0.0, (total, entry) {
      final yellowPenalty = entry.details
          .where((detail) => detail.label == '옐로카드' && detail.points < 0)
          .fold<double>(0.0, (sum, detail) => sum + detail.points.abs());
      return total + yellowPenalty;
    });

    var projected = weightedRecent * 0.70 + seasonApts * 0.30 + trendBonus;
    projected *= teamFormFactor;
    projected *= (0.72 + appearanceRate * 0.28);
    if (consecutiveNoShows >= 2) {
      projected *= 0.82;
    }
    if (yellowCardCount >= 5) {
      projected *= 0.82;
    } else if (yellowCardCount >= 3) {
      projected *= 0.92;
    }
    return projected.clamp(0.0, 25.0);
  }

  double _projectKboFptsForSlot(
    _PlayerSlot slot,
    List<_PlayerRoundPoints> roundPoints, {
    required int targetRound,
    required double teamFormFactor,
    required double opponentFormFactor,
    double pitcherOpportunityFactor = 1.0,
  }) {
    final previous =
        roundPoints.where((entry) => entry.round < targetRound).toList()
          ..sort((a, b) => b.round.compareTo(a.round));
    final fallback =
        _kLeagueAptsFromRoundPoints(previous) ??
        _cachedFullSeasonKboAptsForPlayer(
          playerName: slot.name,
          club: _normalizeKboDraftClub(slot.club),
          preferredNumber: slot.number,
          preferredPosition: slot.position,
        ) ??
        _fantasyProjectedSlotScore(slot, isSoccer: false);
    if (previous.isEmpty) {
      return (fallback * teamFormFactor * opponentFormFactor).clamp(0.0, 60.0);
    }

    final recent = previous.take(6).toList();
    const weights = <double>[0.30, 0.24, 0.18, 0.13, 0.09, 0.06];
    var weightedTotal = 0.0;
    var weightTotal = 0.0;
    for (var i = 0; i < recent.length; i++) {
      weightedTotal += recent[i].basePoints * weights[i];
      weightTotal += weights[i];
    }
    final weightedRecent = weightTotal > 0
        ? weightedTotal / weightTotal
        : fallback;
    final seasonApts = _kLeagueAptsFromRoundPoints(previous) ?? fallback;
    final recentTwo = recent.take(2).toList();
    final previousFour = recent.skip(2).take(4).toList();
    final recentTwoAvg = recentTwo.isEmpty
        ? weightedRecent
        : recentTwo.fold<double>(0.0, (sum, entry) => sum + entry.basePoints) /
              recentTwo.length;
    final previousFourAvg = previousFour.isEmpty
        ? weightedRecent
        : previousFour.fold<double>(
                0.0,
                (sum, entry) => sum + entry.basePoints,
              ) /
              previousFour.length;
    final trendBonus = (recentTwoAvg - previousFourAvg) * 0.22;
    final appearanceRate =
        recent.where((entry) => entry.appeared).length / recent.length;
    final startedRate =
        recent.where((entry) => entry.started).length / recent.length;
    final latestMissStreak = recent
        .takeWhile((entry) => !entry.appeared)
        .length;

    var projected = weightedRecent * 0.68 + seasonApts * 0.32 + trendBonus;
    projected *= teamFormFactor;
    projected *= opponentFormFactor;
    projected *= (0.65 + appearanceRate * 0.35);
    if (!_isKboPitcherSlot(slot)) {
      projected *= (0.78 + startedRate * 0.22);
    }
    if (latestMissStreak >= 3) {
      projected *= 0.48;
    } else if (latestMissStreak == 2) {
      projected *= 0.64;
    } else if (latestMissStreak == 1) {
      projected *= 0.84;
    }
    if (_isKboPitcherSlot(slot)) {
      projected *= pitcherOpportunityFactor.clamp(0.7, 1.45);
    }
    return projected.clamp(0.0, 60.0);
  }

  List<int> _fantasyLeagueRounds(_JoinedDraft draft) {
    final rounds =
        draft.fantasySchedule
            .map((matchup) => matchup.round)
            .where((round) => round > 0)
            .toSet()
            .toList()
          ..sort();
    return rounds.isEmpty ? const [1] : rounds;
  }

  int _effectiveSelectedLeagueRound(_JoinedDraft draft) {
    final rounds = _fantasyLeagueRounds(draft);
    final currentRound = _currentFantasyRoundAt(draft, DateTime.now());
    final preferred = _selectedLeagueRound;
    if (preferred != null && rounds.contains(preferred)) {
      return preferred;
    }
    if (rounds.contains(currentRound)) return currentRound;
    return rounds.last;
  }

  List<String> _fantasyLeagueStandingItems(_JoinedDraft draft) {
    final standings = _fantasyStandings(draft);
    return List<String>.generate(standings.length, (index) {
      final row = standings[index];
      return '${index + 1}. ${row.team} · ${row.played} · ${row.wins}-${row.ties}-${row.losses} · ${row.standingPoints} pts · ${row.scoredPoints.toStringAsFixed(1)} · ${row.allowedPoints.toStringAsFixed(1)} · ${row.goalDiff.toStringAsFixed(1)}';
    });
  }

  List<String> _fantasyLeaguePowerRankItems(_JoinedDraft draft) {
    final rows = _fantasyPowerRowsForDraft(draft);

    return List<String>.generate(rows.length, (index) {
      final row = rows[index];
      return '${index + 1}. ${row.team} · ${row.form} · ${row.recentAverage.toStringAsFixed(1)} Fpts';
    });
  }

  List<
    ({
      String name,
      String position,
      String club,
      double points,
      PlayerOwnership ownership,
    })
  >
  _fantasyRoundLeaders(_JoinedDraft draft, int round, {int limit = 3}) {
    final leaders =
        <
          ({
            String name,
            String position,
            String club,
            double points,
            PlayerOwnership ownership,
          })
        >[];
    for (final team in draft.fantasyTeams) {
      final ownership = team.teamName == _fantasyMyTeam?.teamName
          ? PlayerOwnership.myTeam
          : PlayerOwnership.otherTeam;
      for (final player in team.roster) {
        final points = draft.isSoccer
            ? _fantasySoccerBasePlayerRoundScore(
                draft,
                team,
                player.name,
                round,
                playerId: player.playerId,
              )
            : _fantasyPlayerRoundScore(
                player,
                round,
                isSoccer: draft.isSoccer,
                draft: draft,
                team: team,
              );
        leaders.add((
          name: player.name,
          position: player.position,
          club: player.club,
          points: points,
          ownership: ownership,
        ));
      }
    }
    leaders.sort((a, b) {
      final pointCompare = b.points.compareTo(a.points);
      if (pointCompare != 0) return pointCompare;
      return a.name.compareTo(b.name);
    });
    return leaders.take(limit).toList();
  }

  List<
    ({
      String position,
      String name,
      String club,
      double apts,
      PlayerOwnership ownership,
    })
  >
  _positionAptsLeaders(
    List<_PlayerSlot> players,
    Map<String, double> seasonAptsByClubAndPlayer,
  ) {
    final leaders =
        <
          ({
            String position,
            String name,
            String club,
            double apts,
            PlayerOwnership ownership,
          })
        >[];
    for (final position in _aptsRankingPositions(widget.isSoccer)) {
      final candidates = players.where((player) => player.position == position);
      if (candidates.isEmpty) continue;
      final ranked = candidates.toList()
        ..sort((a, b) {
          final scoreCompare = _positionAptsForSlot(
            b,
            seasonAptsByClubAndPlayer,
          ).compareTo(_positionAptsForSlot(a, seasonAptsByClubAndPlayer));
          if (scoreCompare != 0) return scoreCompare;
          return a.name.compareTo(b.name);
        });
      final leader = ranked.first;
      leaders.add((
        position: position,
        name: leader.name,
        club: _slotClub(leader),
        apts: _positionAptsForSlot(leader, seasonAptsByClubAndPlayer),
        ownership: _ownerForSlot(leader),
      ));
    }
    return leaders;
  }

  double _positionAptsForSlot(
    _PlayerSlot slot,
    Map<String, double> profileAptsByClubAndPlayer,
  ) {
    return profileAptsByClubAndPlayer[_slotAptsKey(slot)] ?? 0.0;
  }

  Future<Map<String, double>> _loadProfileAptsByPlayers(
    List<_PlayerSlot> players,
  ) => _loadProfileAptsForSlots(players, isSoccer: widget.isSoccer);

  List<_PositionAptsRankEntry> _positionAptsRankings(
    List<_PlayerSlot> players,
    String position,
    Map<String, double> profileAptsByClubAndPlayer,
  ) {
    final ranked =
        players.where((player) => player.position == position).toList()
          ..sort((a, b) {
            final scoreCompare = _positionAptsForSlot(
              b,
              profileAptsByClubAndPlayer,
            ).compareTo(_positionAptsForSlot(a, profileAptsByClubAndPlayer));
            if (scoreCompare != 0) return scoreCompare;
            return a.name.compareTo(b.name);
          });
    return ranked.map((player) {
      return _PositionAptsRankEntry(
        position: position,
        name: player.name,
        club: _slotClub(player),
        number: player.number,
        apts: _positionAptsForSlot(player, profileAptsByClubAndPlayer),
        ownership: _ownerForSlot(player),
      );
    }).toList();
  }

  String _formatFantasyBadgeScore(double value) {
    final rounded = value.toStringAsFixed(1);
    if (rounded.endsWith('.0')) {
      return rounded.substring(0, rounded.length - 2);
    }
    return rounded;
  }

  double _fantasySoccerCurrentPlayerScore(
    _JoinedDraft draft,
    _FantasyTeamState team,
    _FantasyTeamPlayer player,
    int round,
  ) {
    return _fantasyPlayerRoundScore(
      player,
      round,
      isSoccer: true,
      draft: draft,
      team: team,
    );
  }

  double _fantasySoccerBasePlayerScore(
    _JoinedDraft draft,
    _FantasyTeamState team,
    _FantasyTeamPlayer player,
    int round,
  ) {
    return _fantasySoccerBasePlayerRoundScore(
      draft,
      team,
      player.name,
      round,
      playerId: player.playerId,
    );
  }

  double _fantasySlotDisplayScore(_PlayerSlot slot) {
    if (!widget.isSoccer || _fantasyDraft == null || _fantasyMyTeam == null) {
      if (_fantasyDraft != null && _fantasyMyTeam != null && !widget.isSoccer) {
        return _fantasyProjectedScoreForSlot(slot, team: _fantasyMyTeam);
      }
      return _fantasyProjectedSlotScore(slot, isSoccer: widget.isSoccer);
    }
    final base = _leadershipCandidateScore(slot);
    return _playerSlotIdentity(slot) == _captainPlayerId ? base * 2 : base;
  }

  ({String? opponentLabel, bool fixtureStarted}) _kLeagueMatchupContextForSlot({
    required List<dynamic> rawFixtures,
    required _PlayerSlot slot,
    required int leagueRound,
  }) {
    final canonicalClub = _slotClub(slot);
    for (final raw in rawFixtures) {
      final map = _fixtureAsMap(raw);
      final league = _fixtureAsMap(map['league']);
      if (_roundNumber(_fixtureText(league['round'])) != leagueRound) continue;
      final teams = _fixtureAsMap(map['teams']);
      final homeName = _kLeagueDisplayTeamName(
        _fixtureText(_fixtureAsMap(teams['home'])['name']),
      );
      final awayName = _kLeagueDisplayTeamName(
        _fixtureText(_fixtureAsMap(teams['away'])['name']),
      );
      final homeClub = _canonicalKLeagueClub(homeName);
      final awayClub = _canonicalKLeagueClub(awayName);
      if (homeClub != canonicalClub && awayClub != canonicalClub) continue;
      return (
        opponentLabel: homeClub == canonicalClub ? awayName : homeName,
        fixtureStarted: _kLeagueFixtureMapHasStarted(map),
      );
    }
    return (opponentLabel: null, fixtureStarted: false);
  }

  Future<
    ({
      double displayedPoints,
      double basePoints,
      List<_PlayerRoundPointDetail> details,
      bool appeared,
      bool isCaptain,
      String? opponentLabel,
      bool fixtureStarted,
    })
  >
  _loadMatchupPlayerPopupData({
    required _PlayerSlot slot,
    required _FantasyTeamState team,
    required int round,
  }) async {
    final draft = _fantasyDraft;
    if (draft != null && !widget.isSoccer) {
      final absoluteRound = _mappedKboRoundForFantasyRound(draft, round);
      final leagueData = await _loadCachedKboLeagueData();
      final rawMatches = _fixtureAsList(leagueData['matches']);
      final context = _kboRosterContextForSlot(
        rawMatches: rawMatches,
        slot: slot,
        leagueRound: absoluteRound,
        now: DateTime.now(),
      );
      var roundPoints = _cachedKboRoundPointsForPlayer(
        playerName: slot.name,
        club: _normalizeKboDraftClub(slot.club),
        preferredNumber: slot.number,
        preferredPosition: slot.position,
      );
      roundPoints ??= await _loadKboRoundPointsForPlayerShared(
        playerName: slot.name,
        club: _normalizeKboDraftClub(slot.club),
        preferredNumber: slot.number,
        preferredPosition: slot.position,
      );

      _PlayerRoundPoints? matchedRound;
      for (final entry in roundPoints) {
        if (entry.round == absoluteRound) {
          matchedRound = entry;
          break;
        }
      }

      final displayedPoints = matchedRound?.displayedPoints ?? 0.0;
      final isCaptain = _isCaptainForTeam(team, slot);
      final basePoints = matchedRound?.basePoints ?? displayedPoints;
      final boostedDisplayedPoints = isCaptain
          ? basePoints * 2
          : displayedPoints;
      final detailRows = _groupKboRoundPointDetails(
        matchedRound?.details ?? const <_PlayerRoundPointDetail>[],
      );
      final captainBonus = boostedDisplayedPoints - basePoints;
      if (isCaptain && captainBonus.abs() > 0.001) {
        detailRows.add(
          _PlayerRoundPointDetail(
            label: '캡틴 배수',
            detail: '주장 적용',
            points: captainBonus,
          ),
        );
      }

      return (
        displayedPoints: boostedDisplayedPoints,
        basePoints: basePoints,
        details: detailRows,
        appeared: matchedRound?.appeared ?? boostedDisplayedPoints > 0,
        isCaptain: isCaptain,
        opponentLabel: context.opponentLabel,
        fixtureStarted: context.fixtureStarted,
      );
    }

    await _restorePersistedKLeaguePlayerRoundPointsCache();
    var targetLeagueRound = round;
    String? opponentLabel;
    var fixtureStarted = false;
    if (draft != null && widget.isSoccer) {
      final leagueData = await _loadCachedKLeagueLeagueData();
      final rawFixtures = _fixtureAsList(leagueData['fixtures']);
      if (rawFixtures.isNotEmpty) {
        targetLeagueRound = _mappedKLeagueRoundForFantasyRound(
          draft,
          round,
          rawFixtures,
        );
        final context = _kLeagueMatchupContextForSlot(
          rawFixtures: rawFixtures,
          slot: slot,
          leagueRound: targetLeagueRound,
        );
        opponentLabel = context.opponentLabel;
        fixtureStarted = context.fixtureStarted;
      }
    }
    final displayedPoints = draft == null
        ? slot.score.toDouble()
        : _fantasySoccerDisplayedPlayerRoundScore(
            draft,
            team,
            slot.name,
            round,
            playerId: slot.playerId,
          );
    final basePoints = draft == null
        ? slot.score.toDouble()
        : _fantasySoccerBasePlayerRoundScore(
            draft,
            team,
            slot.name,
            round,
            playerId: slot.playerId,
          );
    var roundPoints = _cachedKLeagueRoundPointsForPlayer(
      playerName: slot.name,
      club: _slotClub(slot),
      preferredNumber: slot.number,
    );
    roundPoints ??= await _loadKLeagueRoundPointsForPlayerShared(
      playerName: slot.name,
      club: _slotClub(slot),
      preferredNumber: slot.number,
    );

    _PlayerRoundPoints? matchedRound;
    for (final entry in roundPoints) {
      if (entry.round == targetLeagueRound) {
        matchedRound = entry;
        break;
      }
    }

    final isCaptain = _isCaptainForTeam(team, slot);
    final detailRows = <_PlayerRoundPointDetail>[...?matchedRound?.details];
    final captainBonus = displayedPoints - basePoints;
    if (isCaptain && captainBonus.abs() > 0.001) {
      detailRows.add(
        _PlayerRoundPointDetail(
          label: '캡틴 배수',
          detail: '주장 적용',
          points: captainBonus,
        ),
      );
    }

    return (
      displayedPoints: displayedPoints,
      basePoints: basePoints,
      details: detailRows,
      appeared: matchedRound?.appeared ?? displayedPoints > 0,
      isCaptain: isCaptain,
      opponentLabel: matchedRound?.opponentLabel ?? opponentLabel,
      fixtureStarted: fixtureStarted,
    );
  }

  Future<void> _showMatchupPlayerMiniProfile({
    required _PlayerSlot slot,
    required _FantasyTeamState team,
    required int round,
    required PlayerOwnership ownership,
  }) async {
    final popupFuture = _loadMatchupPlayerPopupData(
      slot: slot,
      team: team,
      round: round,
    );
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 24,
          ),
          backgroundColor: Colors.transparent,
          child:
              FutureBuilder<
                ({
                  double displayedPoints,
                  double basePoints,
                  List<_PlayerRoundPointDetail> details,
                  bool appeared,
                  bool isCaptain,
                  String? opponentLabel,
                  bool fixtureStarted,
                })
              >(
                future: popupFuture,
                builder: (context, snapshot) {
                  final theme = Theme.of(context);
                  final palette = _leagueItSurfacePalette(context);
                  final titleStyle = theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: palette.ink,
                  );
                  final subtitleStyle = theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: palette.mutedInk,
                  );

                  Widget shell({required Widget child}) {
                    return Container(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                      decoration: BoxDecoration(
                        color: palette.fieldFill,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: palette.cardBorder),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x14000000),
                            blurRadius: 24,
                            offset: Offset(0, 12),
                          ),
                        ],
                      ),
                      child: child,
                    );
                  }

                  if (snapshot.connectionState != ConnectionState.done) {
                    return shell(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 30),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 28,
                              height: 28,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.6,
                              ),
                            ),
                            SizedBox(height: 14),
                            Text(
                              '선수 점수 불러오는 중...',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: palette.mutedInk,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  if (snapshot.hasError || !snapshot.hasData) {
                    return shell(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(slot.name, style: titleStyle),
                          const SizedBox(height: 8),
                          Text('이 경기 점수 상세를 불러오지 못했습니다.', style: subtitleStyle),
                          const SizedBox(height: 18),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(dialogContext).pop(),
                                child: const Text('닫기'),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.of(dialogContext).pop();
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => PlayerProfilePage(
                                        name: slot.name,
                                        ownership: ownership,
                                        metaOverride: _DocPlayerMeta(
                                          position: slot.position,
                                          club: slot.club,
                                          number: slot.number,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2D6DFF),
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('프로필'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }

                  final data = snapshot.data!;
                  final hasDetails = data.details.isNotEmpty;
                  return shell(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(slot.name, style: titleStyle),
                                  const SizedBox(height: 6),
                                  Text(
                                    '${_displayFantasyClubName(slot.club, isSoccer: widget.isSoccer)} · ${slot.position}',
                                    style: subtitleStyle?.copyWith(
                                      fontSize: 13,
                                    ),
                                  ),
                                  if (data.opponentLabel != null &&
                                      data.opponentLabel!.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      'vs ${_displayFantasyOpponentLabel(data.opponentLabel!, isSoccer: widget.isSoccer)}',
                                      style: subtitleStyle?.copyWith(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w900,
                                        color: const Color(0xFFF28C28),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: palette.tileSurface,
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${data.displayedPoints.toStringAsFixed(1)} pts',
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF2D6DFF),
                                    ),
                                  ),
                                  if (data.isCaptain)
                                    const Text(
                                      'Captain applied',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF5B7FD6),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                          decoration: BoxDecoration(
                            color: palette.tileSurface,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: palette.cardBorder),
                          ),
                          child: hasDetails
                              ? Column(
                                  children: data.details.map((detail) {
                                    final pointsColor = detail.points < 0
                                        ? const Color(0xFFD92D20)
                                        : const Color(0xFF2D6DFF);
                                    return Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 10,
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  detail.label,
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w800,
                                                    color: Color(0xFF344054),
                                                  ),
                                                ),
                                                if (detail.detail != null &&
                                                    detail.detail!.isNotEmpty)
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                          top: 2,
                                                        ),
                                                    child: Text(
                                                      detail.detail!,
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color: Color(
                                                          0xFF667085,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Text(
                                            '${detail.points >= 0 ? '+' : ''}${detail.points.toStringAsFixed(1)}',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w900,
                                              color: pointsColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                )
                              : Text(
                                  !data.fixtureStarted
                                      ? '이 matchup 경기는 아직 시작되지 않았습니다.'
                                      : data.appeared
                                      ? '이 경기의 세부 점수 항목이 아직 집계되지 않았습니다.'
                                      : '이 경기에서 출전 기록이 없습니다.',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF667085),
                                    height: 1.4,
                                  ),
                                ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  Navigator.of(dialogContext).pop();
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => PlayerProfilePage(
                                        name: slot.name,
                                        ownership: ownership,
                                        metaOverride: _DocPlayerMeta(
                                          position: slot.position,
                                          club: slot.club,
                                          number: slot.number,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF2D6DFF),
                                  side: const BorderSide(
                                    color: Color(0xFFBFD3FF),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: const Text(
                                  '프로필',
                                  style: TextStyle(fontWeight: FontWeight.w800),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () =>
                                    Navigator.of(dialogContext).pop(),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2D6DFF),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: const Text(
                                  '닫기',
                                  style: TextStyle(fontWeight: FontWeight.w800),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
        );
      },
    );
  }

  void _openMyPlayerProfile(_PlayerSlot player) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerProfilePage(
          name: player.name,
          ownership: PlayerOwnership.myTeam,
          metaOverride: _DocPlayerMeta(
            position: player.position,
            club: player.club,
            number: player.number,
          ),
        ),
      ),
    );
  }

  bool _lockedLeadershipParticipant(_PlayerSlot? slot) {
    return slot != null && _isRosterSlotLocked(slot);
  }

  bool _shouldBlockLeadershipChangeFor(_PlayerSlot slot) {
    final currentCaptain = _starting.cast<_PlayerSlot?>().firstWhere(
      (player) => _playerSlotIdentity(player!) == _captainPlayerId,
      orElse: () => null,
    );
    final currentViceCaptain = _starting.cast<_PlayerSlot?>().firstWhere(
      (player) => _playerSlotIdentity(player!) == _viceCaptainPlayerId,
      orElse: () => null,
    );
    return _lockedLeadershipParticipant(slot) ||
        _lockedLeadershipParticipant(currentCaptain) ||
        _lockedLeadershipParticipant(currentViceCaptain);
  }

  void _selectCaptainForSlot(_PlayerSlot slot) {
    if (_shouldBlockLeadershipChangeFor(slot)) {
      _showRosterLockMessage(playerName: slot.name);
      return;
    }
    setState(() {
      _normalizeLeadershipSelection(
        preferredCaptainName: slot.name,
        preferredCaptainPlayerId: _playerSlotIdentity(slot),
        preferredViceCaptainName:
            _viceCaptainPlayerId == _playerSlotIdentity(slot)
            ? null
            : _viceCaptainName,
        preferredViceCaptainPlayerId:
            _viceCaptainPlayerId == _playerSlotIdentity(slot)
            ? null
            : _viceCaptainPlayerId,
      );
      _rosterDirty = _computeRosterDirty();
    });
  }

  void _selectViceCaptainForSlot(_PlayerSlot slot) {
    if (_shouldBlockLeadershipChangeFor(slot)) {
      _showRosterLockMessage(playerName: slot.name);
      return;
    }
    setState(() {
      _normalizeLeadershipSelection(
        preferredCaptainName: _captainPlayerId == _playerSlotIdentity(slot)
            ? null
            : _captainName,
        preferredCaptainPlayerId: _captainPlayerId == _playerSlotIdentity(slot)
            ? null
            : _captainPlayerId,
        preferredViceCaptainName: slot.name,
        preferredViceCaptainPlayerId: _playerSlotIdentity(slot),
      );
      _rosterDirty = _computeRosterDirty();
    });
  }

  Future<void> _showStartingPlayerMiniProfile(
    _PlayerSlot slot, {
    bool allowLeadershipActions = true,
  }) async {
    String? dialogCaptainPlayerId = _captainPlayerId;
    String? dialogViceCaptainPlayerId = _viceCaptainPlayerId;
    final kboPopupFuture = widget.isSoccer
        ? null
        : _loadKboStartingPlayerPopupData(slot);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 28,
            vertical: 24,
          ),
          backgroundColor: Colors.transparent,
          child: StatefulBuilder(
            builder: (dialogContext, setDialogState) {
              final isCaptain =
                  dialogCaptainPlayerId == _playerSlotIdentity(slot);
              final isViceCaptain =
                  dialogViceCaptainPlayerId == _playerSlotIdentity(slot);
              final leadershipLocked = _shouldBlockLeadershipChangeFor(slot);

              return FutureBuilder<
                ({
                  double displayedPoints,
                  double basePoints,
                  List<_PlayerRoundPointDetail> details,
                  bool appeared,
                  bool isCaptain,
                  String? opponentLabel,
                  bool fixtureStarted,
                })
              >(
                future: kboPopupFuture,
                builder: (context, snapshot) {
                  final palette = _leagueItSurfacePalette(context);
                  final popupData = snapshot.data;
                  final score =
                      (popupData?.displayedPoints ??
                              (widget.isSoccer
                                  ? _fantasySlotDisplayScore(slot)
                                  : _fantasyCurrentKboScoreForSlot(slot)))
                          .toStringAsFixed(1);
                  final hasKboDetails =
                      !widget.isSoccer &&
                      snapshot.connectionState == ConnectionState.done &&
                      popupData != null &&
                      popupData.details.isNotEmpty;
                  final kboDetailRows = popupData?.details ?? const [];

                  return Container(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                    decoration: BoxDecoration(
                      color: palette.fieldFill,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: palette.cardBorder),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x14000000),
                          blurRadius: 22,
                          offset: Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF4A82FF,
                                  ).withOpacity(0.10),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: const Color(0xFF4A82FF),
                                    width: 1.8,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.person,
                                  size: 34,
                                  color: Color(0xFF4A82FF),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                slot.name,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF171717),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                !widget.isSoccer && slot.club.trim().isNotEmpty
                                    ? '${slot.position} · ${_displayFantasyClubName(slot.club, isSoccer: widget.isSoccer)} · $score점'
                                    : popupData?.opponentLabel?.isNotEmpty ==
                                          true
                                    ? '${slot.position} · ${_displayFantasyOpponentLabel(popupData!.opponentLabel!, isSoccer: widget.isSoccer)} · $score점'
                                    : '${slot.position} · $score점',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: palette.mutedInk,
                                ),
                              ),
                              const SizedBox(height: 14),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                alignment: WrapAlignment.center,
                                children: [
                                  if (leadershipLocked)
                                    _miniProfileBadge(
                                      label: 'LOCKED',
                                      backgroundColor: const Color(0xFFF2F4F7),
                                      textColor: const Color(0xFF667085),
                                    ),
                                  if (isCaptain)
                                    _miniProfileBadge(
                                      label: '주장',
                                      backgroundColor: const Color(0xFFFFCF4D),
                                      textColor: const Color(0xFF1F1F1F),
                                    ),
                                  if (isViceCaptain)
                                    _miniProfileBadge(
                                      label: '부주장',
                                      backgroundColor: const Color(0xFFEAF1FF),
                                      textColor: const Color(0xFF4672E8),
                                    ),
                                ],
                              ),
                              if (!widget.isSoccer) ...[
                                const SizedBox(height: 16),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.fromLTRB(
                                    14,
                                    14,
                                    14,
                                    12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: palette.tileSurface,
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: palette.cardBorder,
                                    ),
                                  ),
                                  child:
                                      snapshot.connectionState !=
                                          ConnectionState.done
                                      ? Padding(
                                          padding: EdgeInsets.symmetric(
                                            vertical: 10,
                                          ),
                                          child: Column(
                                            children: [
                                              SizedBox(
                                                width: 22,
                                                height: 22,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2.4,
                                                    ),
                                              ),
                                              SizedBox(height: 10),
                                              Text(
                                                '세부 Fpts 불러오는 중...',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w700,
                                                  color: palette.mutedInk,
                                                ),
                                              ),
                                            ],
                                          ),
                                        )
                                      : hasKboDetails
                                      ? Column(
                                          children: kboDetailRows.map((detail) {
                                            final pointsColor =
                                                detail.points < 0
                                                ? const Color(0xFFD92D20)
                                                : const Color(0xFF2D6DFF);
                                            return Padding(
                                              padding: const EdgeInsets.only(
                                                bottom: 10,
                                              ),
                                              child: Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          detail.label,
                                                          style: TextStyle(
                                                            fontSize: 14,
                                                            fontWeight:
                                                                FontWeight.w800,
                                                            color: palette.ink,
                                                          ),
                                                        ),
                                                        if (detail.detail !=
                                                                null &&
                                                            detail
                                                                .detail!
                                                                .isNotEmpty)
                                                          Padding(
                                                            padding:
                                                                const EdgeInsets.only(
                                                                  top: 2,
                                                                ),
                                                            child: Text(
                                                              detail.detail!,
                                                              style: TextStyle(
                                                                fontSize: 12,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w700,
                                                                color: palette
                                                                    .mutedInk,
                                                              ),
                                                            ),
                                                          ),
                                                      ],
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Text(
                                                    '${detail.points >= 0 ? '+' : ''}${detail.points.toStringAsFixed(1)}',
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.w900,
                                                      color: pointsColor,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          }).toList(),
                                        )
                                      : Text(
                                          popupData == null
                                              ? '이 경기의 세부 점수를 불러오지 못했습니다.'
                                              : !popupData.fixtureStarted
                                              ? '이 경기는 아직 시작되지 않았습니다.'
                                              : popupData.appeared
                                              ? '이 경기의 세부 점수 항목이 아직 집계되지 않았습니다.'
                                              : '이 경기에서 출전 기록이 없습니다.',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: palette.mutedInk,
                                            height: 1.4,
                                          ),
                                        ),
                                ),
                              ],
                              const SizedBox(height: 18),
                              if (allowLeadershipActions) ...[
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: leadershipLocked
                                            ? null
                                            : () {
                                                _selectCaptainForSlot(slot);
                                                setDialogState(() {
                                                  dialogCaptainPlayerId =
                                                      _captainPlayerId;
                                                  dialogViceCaptainPlayerId =
                                                      _viceCaptainPlayerId;
                                                });
                                              },
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: const Color(
                                            0xFF1F1F1F,
                                          ),
                                          side: BorderSide(
                                            color: isCaptain
                                                ? const Color(0xFFE0B331)
                                                : palette.cardBorder,
                                          ),
                                          backgroundColor: isCaptain
                                              ? const Color(0xFFFFF3C6)
                                              : palette.tileSurface,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 14,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                          ),
                                        ),
                                        child: const Text(
                                          '주장',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: leadershipLocked
                                            ? null
                                            : () {
                                                _selectViceCaptainForSlot(slot);
                                                setDialogState(() {
                                                  dialogCaptainPlayerId =
                                                      _captainPlayerId;
                                                  dialogViceCaptainPlayerId =
                                                      _viceCaptainPlayerId;
                                                });
                                              },
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: const Color(
                                            0xFF4672E8,
                                          ),
                                          side: BorderSide(
                                            color: isViceCaptain
                                                ? const Color(0xFF7EA9FF)
                                                : palette.cardBorder,
                                          ),
                                          backgroundColor: isViceCaptain
                                              ? const Color(0xFFEAF1FF)
                                              : palette.tileSurface,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 14,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                          ),
                                        ),
                                        child: const Text(
                                          '부주장',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                              ],
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: () {
                                    Navigator.of(dialogContext).pop();
                                    _openMyPlayerProfile(slot);
                                  },
                                  style: ElevatedButton.styleFrom(
                                    elevation: 0,
                                    backgroundColor: const Color(0xFF4A82FF),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  child: const Text(
                                    '프로필',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Positioned(
                          top: -8,
                          right: -8,
                          child: Container(
                            decoration: BoxDecoration(
                              color: palette.tileSurface,
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              onPressed: () =>
                                  Navigator.of(dialogContext).pop(),
                              icon: Icon(Icons.close, color: palette.ink),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  Future<
    ({
      double displayedPoints,
      double basePoints,
      List<_PlayerRoundPointDetail> details,
      bool appeared,
      bool isCaptain,
      String? opponentLabel,
      bool fixtureStarted,
    })
  >
  _loadKboStartingPlayerPopupData(_PlayerSlot slot) async {
    final draft = _fantasyDraft;
    final team = _fantasyMyTeam;
    if (draft == null || team == null || draft.isSoccer) {
      return (
        displayedPoints: _fantasyCurrentKboScoreForSlot(slot),
        basePoints: _fantasyCurrentKboScoreForSlot(slot),
        details: const <_PlayerRoundPointDetail>[],
        appeared: false,
        isCaptain: false,
        opponentLabel: null,
        fixtureStarted: false,
      );
    }

    final now = DateTime.now();
    final fantasyRound = _effectiveFantasyRoundForDraft(draft, now: now);
    final absoluteRound = _mappedKboRoundForFantasyRound(draft, fantasyRound);
    final leagueData = await _loadCachedKboLeagueData();
    final rawMatches = _fixtureAsList(leagueData['matches']);
    final matchupContext = _kboRosterContextForSlot(
      rawMatches: rawMatches,
      slot: slot,
      leagueRound: absoluteRound,
      now: now,
    );

    var roundPoints = _cachedKboRoundPointsForPlayer(
      playerName: slot.name,
      club: _normalizeKboDraftClub(slot.club),
      preferredNumber: slot.number,
      preferredPosition: slot.position,
    );
    roundPoints ??= await _loadKboRoundPointsForPlayerShared(
      playerName: slot.name,
      club: _normalizeKboDraftClub(slot.club),
      preferredNumber: slot.number,
      preferredPosition: slot.position,
    );

    _PlayerRoundPoints? matchedRound;
    for (final entry in roundPoints) {
      if (entry.round == absoluteRound) {
        matchedRound = entry;
        break;
      }
    }

    final isCaptain = _isCaptainForTeam(team, slot);
    final displayedPoints = matchedRound?.displayedPoints ?? 0.0;
    final basePoints = matchedRound?.basePoints ?? displayedPoints;
    final boostedDisplayedPoints = isCaptain ? basePoints * 2 : displayedPoints;
    final detailRows = _groupKboRoundPointDetails(
      matchedRound?.details ?? const <_PlayerRoundPointDetail>[],
    );
    final captainBonus = boostedDisplayedPoints - basePoints;
    if (isCaptain && captainBonus.abs() > 0.001) {
      detailRows.add(
        _PlayerRoundPointDetail(
          label: '캡틴 배수',
          detail: '주장 적용',
          points: captainBonus,
        ),
      );
    }

    return (
      displayedPoints: boostedDisplayedPoints,
      basePoints: basePoints,
      details: detailRows,
      appeared: matchedRound?.appeared ?? boostedDisplayedPoints > 0,
      isCaptain: isCaptain,
      opponentLabel: matchupContext.opponentLabel,
      fixtureStarted: matchupContext.fixtureStarted,
    );
  }

  ({String? opponentLabel, bool fixtureStarted}) _kboRosterContextForSlot({
    required List<dynamic> rawMatches,
    required _PlayerSlot slot,
    required int leagueRound,
    required DateTime now,
  }) {
    final canonicalClub = _normalizeKboDraftClub(slot.club);
    final opponentClubs = <String>[];
    var anyFixtureStarted = false;
    for (final raw in rawMatches) {
      final map = _fixtureAsMap(raw);
      final matchDate = DateTime.tryParse('${map['date'] ?? ''}');
      if (matchDate == null) continue;
      if (_kboFantasyRoundForMatchDate(matchDate) != leagueRound) continue;
      final homeClub = _normalizeKboDraftClub('${map['home'] ?? ''}');
      final awayClub = _normalizeKboDraftClub('${map['away'] ?? ''}');
      if (canonicalClub != homeClub && canonicalClub != awayClub) continue;
      final kickoffUtc = _kboUtcDateTime(
        '${map['dateUtc'] ?? ''}',
        '${map['timeUtc'] ?? ''}',
      );
      final fixtureStarted = kickoffUtc != null
          ? !now.toUtc().isBefore(kickoffUtc)
          : _kboMatchMapHasStarted(map, now: now);
      anyFixtureStarted = anyFixtureStarted || fixtureStarted;
      final opponentClub = canonicalClub == homeClub ? awayClub : homeClub;
      if (opponentClub.isNotEmpty && !opponentClubs.contains(opponentClub)) {
        opponentClubs.add(opponentClub);
      }
    }
    return (
      opponentLabel: opponentClubs.isEmpty ? null : opponentClubs.join(' / '),
      fixtureStarted: anyFixtureStarted,
    );
  }

  Widget _miniProfileBadge({
    required String label,
    required Color backgroundColor,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: textColor,
        ),
      ),
    );
  }

  Widget _fantasyTeamSummary({required _FantasyTeamState team}) {
    return Column(
      children: [
        _FantasyTeamAvatar(
          uid: team.uid,
          teamName: team.teamName,
          size: 52,
          iconSize: 24,
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: 78,
          child: Text(
            team.teamName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }

  double _fantasyMatchupCurrentScoreForPlayer(
    _FantasyTeamPlayer player, {
    required _JoinedDraft draft,
    required _FantasyTeamState team,
    required int round,
  }) {
    return widget.isSoccer
        ? _fantasySoccerCurrentPlayerScore(draft, team, player, round)
        : _fantasyKboScoreForSlot(
            player.toPlayerSlot(),
            draft: draft,
            fantasyRound: round,
            team: team,
          );
  }

  double _fantasyMatchupProjectedScoreForPlayer(
    _FantasyTeamPlayer player, {
    required _JoinedDraft draft,
    required _FantasyTeamState team,
    required int round,
  }) {
    return _fantasyProjectedScoreForSlot(
      player.toPlayerSlot(),
      team: team,
      draft: draft,
      fantasyRound: round,
    );
  }

  Widget _fantasyStartingPlayerCard({
    required _FantasyTeamPlayer player,
    required int round,
    required _JoinedDraft draft,
    required _FantasyTeamState team,
    bool isCaptain = false,
    void Function(_FantasyTeamPlayer player)? onPlayerTap,
    EdgeInsetsGeometry margin = const EdgeInsets.only(bottom: 10),
  }) {
    final palette = _leagueItSurfacePalette(context);
    final projectionsDisplayable = _hasDisplayableFantasyProjectedScores(
      draft,
      fantasyRound: round,
    );
    final current = _fantasyMatchupCurrentScoreForPlayer(
      player,
      draft: draft,
      team: team,
      round: round,
    );
    final projected = _fantasyMatchupProjectedScoreForPlayer(
      player,
      draft: draft,
      team: team,
      round: round,
    );
    final card = Container(
      margin: margin,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: palette.tileSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: palette.ink,
                    ),
                    children: [
                      TextSpan(text: player.name),
                      if (isCaptain)
                        const TextSpan(
                          text: ' C',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFFFFCF4D),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  projectionsDisplayable
                      ? projected.toStringAsFixed(1)
                      : '계산 중...',
                  style: TextStyle(
                    fontSize: 13,
                    color: palette.mutedInk,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: palette.isDark
                      ? const Color(0xFF223458)
                      : const Color(0xFFE9F0FF),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  _formatFantasyBadgeScore(current),
                  style: TextStyle(
                    color: palette.isDark
                        ? const Color(0xFF8EB7FF)
                        : const Color(0xFF2D6DFF),
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    if (onPlayerTap == null) return card;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => onPlayerTap(player),
        child: card,
      ),
    );
  }

  Widget _fantasyStartingList({
    String? title,
    required List<_FantasyTeamPlayer> players,
    required int round,
    required _JoinedDraft draft,
    required _FantasyTeamState team,
    void Function(_FantasyTeamPlayer player)? onPlayerTap,
  }) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(
              title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
          ],
          ...players.map(
            (player) => _fantasyStartingPlayerCard(
              player: player,
              round: round,
              draft: draft,
              team: team,
              isCaptain: _isCaptainFantasyPlayerForTeam(team, player),
              onPlayerTap: onPlayerTap,
            ),
          ),
        ],
      ),
    );
  }

  Widget _fantasyBaseballStartingMatchup({
    required _FantasyMatchupView matchup,
    required int round,
  }) {
    final palette = _leagueItSurfacePalette(context);
    final myMap = _buildBaseballFieldPlayerMap(matchup.myTeam.starting);
    final opponentMap = _buildBaseballFieldPlayerMap(matchup.opponent.starting);
    final rows = _baseballMatchupPositionRowOrder
        .where((label) => myMap[label] != null || opponentMap[label] != null)
        .toList();

    Widget playerCell({
      required _FantasyTeamPlayer? player,
      required _FantasyTeamState team,
      required PlayerOwnership ownership,
    }) {
      if (player == null) {
        return Container(
          height: 68,
          decoration: BoxDecoration(
            color: palette.tileSurface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: palette.cardBorder),
          ),
          alignment: Alignment.center,
          child: Text(
            '선수 없음',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: palette.mutedInk,
            ),
          ),
        );
      }
      return _fantasyStartingPlayerCard(
        player: player,
        round: round,
        draft: matchup.draft,
        team: team,
        isCaptain: _isCaptainFantasyPlayerForTeam(team, player),
        margin: EdgeInsets.zero,
        onPlayerTap: (_) {
          unawaited(
            _showMatchupPlayerMiniProfile(
              slot: player.toPlayerSlot(),
              team: team,
              round: round,
              ownership: ownership,
            ),
          );
        },
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.fieldFill,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  matchup.myTeam.teamName,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: palette.ink,
                  ),
                ),
              ),
              SizedBox(
                width: 56,
                child: Center(
                  child: Text(
                    '포지션',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: palette.mutedInk,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  matchup.opponent.teamName,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: palette.ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < rows.length; i++) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: playerCell(
                    player: myMap[rows[i]],
                    team: matchup.myTeam,
                    ownership: PlayerOwnership.myTeam,
                  ),
                ),
                SizedBox(
                  width: 56,
                  child: Center(
                    child: Text(
                      rows[i],
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: palette.mutedInk,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: playerCell(
                    player: opponentMap[rows[i]],
                    team: matchup.opponent,
                    ownership: PlayerOwnership.otherTeam,
                  ),
                ),
              ],
            ),
            if (i != rows.length - 1) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  Widget _fantasyBenchColumns({
    required _FantasyMatchupView matchup,
    required int round,
  }) {
    final palette = _leagueItSurfacePalette(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.fieldFill,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '교체명단',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: palette.ink,
            ),
          ),
          const SizedBox(height: 8),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _fantasyStartingList(
                  players: matchup.myTeam.bench,
                  round: round,
                  draft: matchup.draft,
                  team: matchup.myTeam,
                  onPlayerTap: (player) {
                    unawaited(
                      _showMatchupPlayerMiniProfile(
                        slot: player.toPlayerSlot(),
                        team: matchup.myTeam,
                        round: round,
                        ownership: PlayerOwnership.myTeam,
                      ),
                    );
                  },
                ),
                Container(
                  width: 1,
                  margin: const EdgeInsets.symmetric(horizontal: 14),
                  color: palette.cardBorder,
                ),
                _fantasyStartingList(
                  players: matchup.opponent.bench,
                  round: round,
                  draft: matchup.draft,
                  team: matchup.opponent,
                  onPlayerTap: (player) {
                    unawaited(
                      _showMatchupPlayerMiniProfile(
                        slot: player.toPlayerSlot(),
                        team: matchup.opponent,
                        round: round,
                        ownership: PlayerOwnership.otherTeam,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFantasySectionContent(_JoinedDraft draft) {
    final palette = _leagueItSurfacePalette(context);
    switch (_section) {
      case _MatchSection.matchup:
        final matchup = _fantasyMatchup;
        if (matchup == null) {
          return _comingSoonCard('현재 라운드 매치업이 아직 없습니다.');
        }
        final myActual = widget.isSoccer
            ? matchup.myScore
            : _fantasyDisplayedKboTeamScore(
                matchup.myTeam,
                draft: matchup.draft,
                fantasyRound: matchup.round,
              );
        final opponentActual = widget.isSoccer
            ? matchup.opponentScore
            : _fantasyDisplayedKboTeamScore(
                matchup.opponent,
                draft: matchup.draft,
                fantasyRound: matchup.round,
              );
        final myProjected = _fantasyProjectedMatchupTeamScore(
          matchup.myTeam,
          draft: matchup.draft,
          fantasyRound: matchup.round,
          actualScore: myActual,
        );
        final opponentProjected = _fantasyProjectedMatchupTeamScore(
          matchup.opponent,
          draft: matchup.draft,
          fantasyRound: matchup.round,
          actualScore: opponentActual,
        );
        final homeRatio =
            _forcedKboLeadingWinRatio(
              draft: matchup.draft,
              fantasyRound: matchup.round,
              myTeam: matchup.myTeam,
              opponentTeam: matchup.opponent,
              myActual: myActual,
              opponentActual: opponentActual,
            ) ??
            _fantasyWinRatio(
              draft: matchup.draft,
              fantasyRound: matchup.round,
              myActual: myActual,
              opponentActual: opponentActual,
              myProjected: myProjected,
              opponentProjected: opponentProjected,
            );
        final projectionsDisplayable = _hasDisplayableFantasyProjectedScores(
          matchup.draft,
          fantasyRound: matchup.round,
        );
        final animateActualScoreChanges = _fantasyMatchupHasLiveOfficialGames(
          matchup,
        );
        final actualScoreBaseColor = palette.ink;
        final actualScoreStyle = const TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.8,
          fontFeatures: [FontFeature.tabularFigures()],
        );
        final fantasySoccerLineup = widget.isSoccer
            ? _buildFantasySoccerLineup(matchup)
            : null;
        final myStartingIds = matchup.myTeam.starting
            .map((player) => _playerSlotIdentity(player.toPlayerSlot()))
            .toSet();
        final opponentStartingIds = matchup.opponent.starting
            .map((player) => _playerSlotIdentity(player.toPlayerSlot()))
            .toSet();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: _fantasyTeamSummary(team: matchup.myTeam),
                ),
                Expanded(
                  flex: 3,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Column(
                      children: [
                        SizedBox(
                          height: 34,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: _AnimatedFantasyScoreText(
                                      key: ValueKey(
                                        '${matchup.draft.leagueId}|${matchup.round}|matchup-tab|home',
                                      ),
                                      score: myActual,
                                      fractionDigits: 1,
                                      style: actualScoreStyle,
                                      baseColor: actualScoreBaseColor,
                                      animateChanges: animateActualScoreChanges,
                                      textAlign: TextAlign.right,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(
                                width: 22,
                                child: Center(
                                  child: Text(
                                    ':',
                                    style: TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.8,
                                      fontFeatures: [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: _AnimatedFantasyScoreText(
                                      key: ValueKey(
                                        '${matchup.draft.leagueId}|${matchup.round}|matchup-tab|away',
                                      ),
                                      score: opponentActual,
                                      fractionDigits: 1,
                                      style: actualScoreStyle,
                                      baseColor: actualScoreBaseColor,
                                      animateChanges: animateActualScoreChanges,
                                      textAlign: TextAlign.left,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Text(
                                projectionsDisplayable
                                    ? myProjected.toStringAsFixed(1)
                                    : '계산 중',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: palette.mutedInk,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 66,
                              child: Text(
                                widget.isSoccer ? '예상\nFpts' : '예상\nFpts',
                                maxLines: 2,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 11,
                                  height: 1.2,
                                  color: palette.mutedInk,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                projectionsDisplayable
                                    ? opponentProjected.toStringAsFixed(1)
                                    : '계산 중',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: palette.mutedInk,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: _fantasyTeamSummary(team: matchup.opponent),
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (projectionsDisplayable) ...[
              Row(
                children: [
                  Text(
                    '${(homeRatio * 100).round()}%',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '승리 확률',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: palette.mutedInk,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    '${((1 - homeRatio) * 100).round()}%',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              _WinBar(homeRatio: homeRatio),
            ] else ...[
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                alignment: Alignment.center,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2.0),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '승리 확률 계산 중...',
                      style: TextStyle(
                        fontSize: 13,
                        color: palette.mutedInk,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 18),
            if (widget.isSoccer) ...[
              _LineupField(
                lineup: fantasySoccerLineup!,
                isSoccer: true,
                homeRecord: '',
                awayRecord: '',
                isCaptainForSlot: (slot) {
                  final slotId = _playerSlotIdentity(slot);
                  if (myStartingIds.contains(slotId)) {
                    return _isCaptainForTeam(matchup.myTeam, slot);
                  }
                  if (opponentStartingIds.contains(slotId)) {
                    return _isCaptainForTeam(matchup.opponent, slot);
                  }
                  return false;
                },
                scoreForSlot: (slot) {
                  final slotId = _playerSlotIdentity(slot);
                  if (myStartingIds.contains(slotId)) {
                    return _fantasyProjectedScoreForSlot(
                      slot,
                      team: matchup.myTeam,
                    );
                  }
                  if (opponentStartingIds.contains(slotId)) {
                    return _fantasyProjectedScoreForSlot(
                      slot,
                      team: matchup.opponent,
                    );
                  }
                  return _fantasyProjectedBaseScoreForSlot(slot);
                },
                onPlayerTap: (slot) {
                  final slotId = _playerSlotIdentity(slot);
                  final selectedTeam = myStartingIds.contains(slotId)
                      ? matchup.myTeam
                      : matchup.opponent;
                  final ownership = myStartingIds.contains(slotId)
                      ? PlayerOwnership.myTeam
                      : PlayerOwnership.otherTeam;
                  unawaited(
                    _showMatchupPlayerMiniProfile(
                      slot: slot,
                      team: selectedTeam,
                      round: matchup.round,
                      ownership: ownership,
                    ),
                  );
                },
              ),
              const SizedBox(height: 14),
              _fantasyBenchColumns(matchup: matchup, round: matchup.round),
            ] else ...[
              _fantasyBaseballStartingMatchup(
                matchup: matchup,
                round: matchup.round,
              ),
              const SizedBox(height: 14),
              _fantasyBenchColumns(matchup: matchup, round: matchup.round),
            ],
          ],
        );
      case _MatchSection.roster:
        if (!widget.isSoccer) {
          final projectionsDisplayable = _hasDisplayableFantasyProjectedScores(
            draft,
            fantasyRound: _effectiveFantasyRoundForDraft(draft),
          );
          final rosterLockState = _rosterLockState;

          void openMyPlayerProfile(_PlayerSlot slot) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PlayerProfilePage(
                  name: slot.name,
                  ownership: PlayerOwnership.myTeam,
                  metaOverride: _DocPlayerMeta(
                    position: slot.position,
                    club: slot.club,
                    number: slot.number,
                  ),
                ),
              ),
            );
          }

          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: palette.fieldFill,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: palette.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'My Roster',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: palette.ink,
                  ),
                ),
                if (_hasLockedRosterChanges()) ...[
                  const SizedBox(height: 8),
                  const Text(
                    '잠긴 선수에 대한 미저장 변경이 있어서 저장할 수 없습니다.',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFD92D20),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                _FantasyBaseballRosterDiamond(
                  starting: _starting,
                  isLocked: rosterLockState.isLocked,
                  showProjectedLabel: projectionsDisplayable,
                  scoreForSlot: (slot) =>
                      _fantasyProjectedScoreForSlot(slot, team: _fantasyMyTeam),
                  actualScoreForSlot: _fantasyCurrentKboScoreForSlot,
                  captainPlayerId:
                      _captainPlayerId ?? _fantasyMyTeam?.captainPlayerId,
                  viceCaptainPlayerId:
                      _viceCaptainPlayerId ??
                      _fantasyMyTeam?.viceCaptainPlayerId,
                  captainName: _captainName ?? _fantasyMyTeam?.captainName,
                  viceCaptainName:
                      _viceCaptainName ?? _fantasyMyTeam?.viceCaptainName,
                  onSwap: _swapPlayers,
                  onTap: (slot) {
                    unawaited(_showStartingPlayerMiniProfile(slot));
                  },
                  onDragUpdate: _maybeAutoScrollRoster,
                  onDragStarted: _handleRosterDragStarted,
                  onDragEnded: _handleRosterDragFinished,
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed:
                        _rosterDirty &&
                            !_hasLockedRosterChanges() &&
                            !_isSavingRoster
                        ? _saveFantasyRosterChanges
                        : null,
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor: const Color(0xFF4A82FF),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: palette.buttonDisabled,
                      disabledForegroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isSavingRoster
                        ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              ),
                              SizedBox(width: 10),
                              Text(
                                '저장 중...',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          )
                        : const Text(
                            '저장',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  '교체명단',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: palette.ink,
                  ),
                ),
                const SizedBox(height: 8),
                _FantasyBenchList(
                  players: _bench,
                  isLocked: rosterLockState.isLocked,
                  isSoccer: false,
                  showProjectedScores: projectionsDisplayable,
                  scoreForSlot: (slot) =>
                      _fantasyProjectedScoreForSlot(slot, team: _fantasyMyTeam),
                  actualScoreForSlot: _fantasyCurrentKboScoreForSlot,
                  onSwap: _swapPlayers,
                  onTap: (slot) {
                    unawaited(
                      _showStartingPlayerMiniProfile(
                        slot,
                        allowLeadershipActions: false,
                      ),
                    );
                  },
                  onDragUpdate: _maybeAutoScrollRoster,
                  onDragStarted: _handleRosterDragStarted,
                  onDragEnded: _handleRosterDragFinished,
                ),
              ],
            ),
          );
        }

        final rosterByName = <String, _PlayerSlot>{
          for (final p in [..._starting, ..._bench]) _playerSlotIdentity(p): p,
        };
        final displayRows = _rowsFromSoccerStartingSlots(
          _starting,
        ).reversed.toList();
        final currentRound = _effectiveFantasyRoundForDraft(draft);
        final rosterLockState = _rosterLockState;
        final rankedStarting = [..._starting]
          ..sort(
            (a, b) => _fantasyProjectedScoreForSlot(
              b,
              team: _fantasyMyTeam,
            ).compareTo(_fantasyProjectedScoreForSlot(a, team: _fantasyMyTeam)),
          );

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: palette.fieldFill,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: palette.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'My Roster',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: palette.ink,
                ),
              ),
              if (_hasLockedRosterChanges()) ...[
                const SizedBox(height: 8),
                const Text(
                  '잠긴 선수에 대한 미저장 변경이 있어서 저장할 수 없습니다.',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFD92D20),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              _FantasyRosterHalfPitch(
                rows: displayRows,
                rosterByName: rosterByName,
                color: Colors.blueAccent,
                goalkeeperRowOffset: 24,
                isLocked: rosterLockState.isLocked,
                captainPlayerId:
                    _captainPlayerId ?? _fantasyMyTeam?.captainPlayerId,
                viceCaptainPlayerId:
                    _viceCaptainPlayerId ?? _fantasyMyTeam?.viceCaptainPlayerId,
                captainName:
                    _captainName ??
                    _fantasySoccerCaptainName(
                      draft,
                      _fantasyMyTeam!,
                      currentRound,
                    ) ??
                    (rankedStarting.isEmpty ? null : rankedStarting[0].name),
                viceCaptainName:
                    _viceCaptainName ??
                    _fantasySoccerViceCaptainName(
                      draft,
                      _fantasyMyTeam!,
                      currentRound,
                    ) ??
                    (rankedStarting.length < 2 ? null : rankedStarting[1].name),
                scoreForSlot: (slot) =>
                    _fantasyProjectedScoreForSlot(slot, team: _fantasyMyTeam),
                onSwap: _swapPlayers,
                onTap: (slot) {
                  unawaited(_showStartingPlayerMiniProfile(slot));
                },
                onDragUpdate: _maybeAutoScrollRoster,
                onDragStarted: _handleRosterDragStarted,
                onDragEnded: _handleRosterDragFinished,
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed:
                      _rosterDirty &&
                          !_hasLockedRosterChanges() &&
                          !_isSavingRoster
                      ? _saveFantasyRosterChanges
                      : null,
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    backgroundColor: const Color(0xFF4A82FF),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: palette.buttonDisabled,
                    disabledForegroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isSavingRoster
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            ),
                            SizedBox(width: 10),
                            Text(
                              '저장 중...',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        )
                      : const Text(
                          '저장',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                '교체명단',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: palette.ink,
                ),
              ),
              const SizedBox(height: 8),
              _FantasyBenchList(
                players: _bench,
                isLocked: rosterLockState.isLocked,
                isSoccer: true,
                scoreForSlot: (slot) =>
                    _fantasyProjectedScoreForSlot(slot, team: _fantasyMyTeam),
                onSwap: _swapPlayers,
                onTap: (slot) {
                  unawaited(
                    _showStartingPlayerMiniProfile(
                      slot,
                      allowLeadershipActions: false,
                    ),
                  );
                },
                onDragUpdate: _maybeAutoScrollRoster,
                onDragStarted: _handleRosterDragStarted,
                onDragEnded: _handleRosterDragFinished,
              ),
            ],
          ),
        );
      case _MatchSection.players:
        final playersSection = _playersSectionBundle();
        final rosterLockState = _rosterLockState;
        return _buildSectionContent(
          context: context,
          section: _MatchSection.players,
          isSoccer: widget.isSoccer,
          allPlayers: _allPlayers,
          filteredPlayersOverride: playersSection.filteredPlayers,
          startingSlots: _starting,
          benchSlots: _bench,
          onSignFreeAgent: _trySignFreeAgent,
          onTradeRequest: _requestTrade,
          onReleasePlayer: _releaseMyPlayer,
          isLocked: rosterLockState.isLocked,
          rosterUnlocksAtUtc: rosterLockState.unlocksAtUtc,
          profileAptsFuture: playersSection.profileAptsFuture,
          homeRecord: '',
          awayRecord: '',
          maxVisiblePlayers: _playersVisibleCount,
          searchQuery: _playerSearch,
          showPlayerFilters: _showPlayerFilters,
          showOnlyFreeAgents: _showOnlyFreeAgents,
          sortPlayersByAptsDesc: _sortPlayersByAptsDesc,
          positionFilter: _playerPositionFilter,
          onToggleShowPlayerFilters: () => setState(() {
            _showPlayerFilters = !_showPlayerFilters;
            _playersVisibleCount = _initialPlayersVisibleCount;
          }),
          onToggleShowOnlyFreeAgents: (v) => setState(() {
            _showOnlyFreeAgents = v;
            _playersVisibleCount = _initialPlayersVisibleCount;
          }),
          onToggleSortPlayersByAptsDesc: (v) => setState(() {
            _sortPlayersByAptsDesc = v;
            _playersVisibleCount = _initialPlayersVisibleCount;
          }),
          onPositionFilterChanged: (value) => setState(() {
            _playerPositionFilter = value;
            _playersVisibleCount = _initialPlayersVisibleCount;
          }),
          onSearchChanged: _handlePlayerSearchChanged,
          searchController: _playerSearchController,
          onRosterDragUpdate: _maybeAutoScrollRoster,
          usePrimaryPlayersScroll: true,
        );
      case _MatchSection.league:
        final standingsItems = _fantasyLeagueStandingItems(draft);
        final powerRankItems = _fantasyLeaguePowerRankItems(draft);
        final weeklyLeaderSections = _kLeagueWeeklyLeaderSections;
        final previewSection = weeklyLeaderSections.isEmpty
            ? null
            : weeklyLeaderSections.first;
        final currentWeeklyRound =
            previewSection?.round ?? _currentKLeagueWeeklyRound;
        final weeklyPreviewLeaders = previewSection == null
            ? const <_FantasyWeeklyLeaderEntry>[]
            : previewSection.leaders.take(3).toList();

        final standingRows = _fantasyStandings(draft);
        final powerRows = _fantasyPowerRowsForDraft(draft);

        void pushSimpleList(
          String title,
          List<String> items, {
          List<_FantasyStandingRow>? standingRows,
          List<_FantasyPowerRow>? powerRows,
          String? highlightTeamName,
        }) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => _SimpleListPage(
                title: title,
                items: items,
                isSoccer: draft.isSoccer,
                standingRows: standingRows,
                powerRows: powerRows,
                highlightTeamName: highlightTeamName,
                fantasyDraft: draft,
              ),
            ),
          );
        }

        Future<void> openFantasySchedule() async {
          if (draft.isSoccer) {
            unawaited(
              _refreshFantasySoccerScoresAndRebuild(includeHistory: false),
            );
          }
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => _FixtureCardsPage(
                isSoccer: draft.isSoccer,
                fantasyDraft: draft,
                preferredFantasyRound: _preferredFantasyRoundForDraft(draft),
              ),
            ),
          );
        }

        Widget buildOverviewRow({
          required String title,
          required VoidCallback onTap,
        }) {
          return InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right, size: 22),
                ],
              ),
            ),
          );
        }

        Widget buildWeeklyLeaderPodium() {
          const slotHeights = [146.0, 176.0, 126.0];
          const displayOrder = [1, 0, 2];
          if (weeklyPreviewLeaders.isEmpty) {
            return Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 34),
              alignment: Alignment.center,
              child: _isPrimingKLeagueWeeklyRounds
                  ? const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.4),
                        ),
                        SizedBox(height: 12),
                        Text(
                          '이주의 선수 집계 중입니다.',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    )
                  : const Text(
                      '해당 라운드 집계가 아직 없습니다.',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.black54,
                      ),
                    ),
            );
          }

          Widget podiumCard(
            int rankIndex,
            int displayIndex,
            _FantasyWeeklyLeaderEntry player,
          ) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  width: 92,
                  height: slotHeights[displayIndex],
                  decoration: BoxDecoration(
                    color: const Color(0xFFD4DEE7),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFAFBCC7)),
                  ),
                  child: Center(
                    child: Text(
                      '${rankIndex + 1}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: 96,
                  child: Text(
                    player.name,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                SizedBox(
                  width: 96,
                  child: Text(
                    _displayFantasyClubName(
                      player.club,
                      isSoccer: widget.isSoccer,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.black45,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${player.position} · ${player.points.toStringAsFixed(1)}P',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.black54,
                  ),
                ),
              ],
            );
          }

          final displayCount = min(3, weeklyPreviewLeaders.length);
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(displayCount, (displayIndex) {
              final leaderIndex = displayCount == 3
                  ? displayOrder[displayIndex]
                  : displayIndex;
              return podiumCard(
                leaderIndex,
                displayIndex,
                weeklyPreviewLeaders[leaderIndex],
              );
            }),
          );
        }

        Widget buildPositionLeaderCard(
          ({
            String position,
            String name,
            String club,
            double apts,
            PlayerOwnership ownership,
          })
          leader,
          List<_PositionAptsRankEntry> ranking,
        ) {
          final accent = _positionAccentColor(leader.position);
          return InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => _PositionAptsRankingPage(
                    isSoccer: draft.isSoccer,
                    position: leader.position,
                    rankings: ranking,
                  ),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: palette.tileSurface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: palette.cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: accent.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          leader.position,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: accent,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '1위',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: palette.ink,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    leader.name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: palette.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    leader.club,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: palette.mutedInk,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Apts ${leader.apts.toStringAsFixed(1)}',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: _aptsDisplayColor(leader.apts),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            buildOverviewRow(
              title: '리그 순위',
              onTap: () => pushSimpleList(
                '리그 순위',
                standingsItems,
                standingRows: standingRows,
                highlightTeamName: _fantasyMyTeam?.teamName,
              ),
            ),
            buildOverviewRow(
              title: '리그 일정',
              onTap: () {
                unawaited(openFantasySchedule());
              },
            ),
            buildOverviewRow(
              title: '파워 랭킹',
              onTap: () => pushSimpleList(
                '파워 랭킹',
                powerRankItems,
                powerRows: powerRows,
                highlightTeamName: _fantasyMyTeam?.teamName,
              ),
            ),
            const SizedBox(height: 10),
            if (draft.isSoccer)
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () async {
                  if (_kLeagueWeeklyLeaderSections.isEmpty) {
                    await _primeKLeagueWeeklyRounds(draft);
                  }
                  if (!mounted) return;
                  final sections = _kLeagueWeeklyLeaderSections;
                  final currentRound = sections.isEmpty
                      ? (_currentKLeagueWeeklyRound ?? 0)
                      : sections.first.round;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => _FantasyWeeklyLeadersPage(
                        sections: sections,
                        currentRound: currentRound,
                        isSoccer: true,
                      ),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: palette.fieldFill,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: palette.cardBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currentWeeklyRound == null
                            ? '이주의 선수'
                            : '이주의 선수 · Round $currentWeeklyRound',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: palette.ink,
                        ),
                      ),
                      const SizedBox(height: 18),
                      buildWeeklyLeaderPodium(),
                    ],
                  ),
                ),
              )
            else
              Builder(
                builder: (context) {
                  final sections = _kboWeeklyLeaderSections;
                  final preview = sections.isEmpty ? null : sections.first;
                  final previewLeaders = preview == null
                      ? const <_FantasyWeeklyLeaderEntry>[]
                      : preview.leaders.take(3).toList();

                  Widget buildKboWeeklyLeaderPodium() {
                    if (_isPrimingKboWeeklyRounds && preview == null) {
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 34),
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '이주의 선수 집계 중입니다.',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: palette.mutedInk,
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    if (previewLeaders.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          '해당 라운드 집계가 아직 없습니다.',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: palette.mutedInk,
                          ),
                        ),
                      );
                    }

                    const slotHeights = [146.0, 176.0, 126.0];
                    const displayOrder = [1, 0, 2];
                    final displayCount = min(3, previewLeaders.length);

                    Widget podiumCard(
                      int rankIndex,
                      int displayIndex,
                      _FantasyWeeklyLeaderEntry player,
                    ) {
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            width: 92,
                            height: slotHeights[displayIndex],
                            decoration: BoxDecoration(
                              color: palette.isDark
                                  ? const Color(0xFF263038)
                                  : const Color(0xFFD4DEE7),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: palette.isDark
                                    ? const Color(0xFF41515E)
                                    : const Color(0xFFAFBCC7),
                              ),
                            ),
                            child: Center(
                              child: Text(
                                '${rankIndex + 1}',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  color: palette.ink,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: 96,
                            child: Text(
                              player.name,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                color: palette.ink,
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          SizedBox(
                            width: 96,
                            child: Text(
                              _displayFantasyClubName(
                                player.club,
                                isSoccer: widget.isSoccer,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: palette.mutedInk,
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${player.position} · ${player.points.toStringAsFixed(1)}P',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: palette.mutedInk,
                            ),
                          ),
                        ],
                      );
                    }

                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: List.generate(displayCount, (displayIndex) {
                        final leaderIndex = displayCount == 3
                            ? displayOrder[displayIndex]
                            : displayIndex;
                        return podiumCard(
                          leaderIndex,
                          displayIndex,
                          previewLeaders[leaderIndex],
                        );
                      }),
                    );
                  }

                  return InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: sections.isEmpty
                        ? null
                        : () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => _FantasyWeeklyLeadersPage(
                                  sections: sections,
                                  currentRound: sections.first.round,
                                  isSoccer: false,
                                  refreshSections: () async {
                                    await _primeKboWeeklyRounds(
                                      forceRefresh: true,
                                      bypassCooldown: true,
                                    );
                                    return _kboWeeklyLeaderSections;
                                  },
                                ),
                              ),
                            );
                          },
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: palette.fieldFill,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: palette.cardBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            preview == null
                                ? '이주의 선수'
                                : '이주의 선수 · Round ${preview.round}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: palette.ink,
                            ),
                          ),
                          const SizedBox(height: 18),
                          buildKboWeeklyLeaderPodium(),
                        ],
                      ),
                    ),
                  );
                },
              ),
            const SizedBox(height: 14),
            FutureBuilder<Map<String, double>>(
              future: _ensureProfileAptsFuture(_allPlayers),
              builder: (context, snapshot) {
                final seasonApts = {
                  ...?snapshot.data,
                  ..._cachedProfileAptsForSlots(
                    _allPlayers,
                    isSoccer: widget.isSoccer,
                  ),
                };
                final positionLeaders = _positionAptsLeaders(
                  _allPlayers,
                  seasonApts,
                );
                final positionRankings = {
                  for (final position in _aptsRankingPositions(draft.isSoccer))
                    position: _positionAptsRankings(
                      _allPlayers,
                      position,
                      seasonApts,
                    ),
                };

                return Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: palette.fieldFill,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: palette.cardBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '포지션별 Apts 리더',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: palette.ink,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '선수 프로필과 같은 Apts 기준으로 정렬합니다.',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: palette.mutedInk,
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (positionLeaders.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          child: Text(
                            '표시할 포지션 리더가 없습니다.',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: palette.mutedInk,
                            ),
                          ),
                        )
                      else
                        ...positionLeaders.map(
                          (leader) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: buildPositionLeaderCard(
                              leader,
                              positionRankings[leader.position] ?? const [],
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_fantasyDraft != null) {
      final isPlayersSection = _section == _MatchSection.players;
      return PopScope<Object?>(
        canPop: !_rosterDirty || _allowImmediateRoutePop,
        onPopInvokedWithResult: _handleRoutePopInvoked,
        child: Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: LeagueItSubAppBar(
            key: _appBarKey,
            onMyPageTap: _toggleMyPageOverlay,
            onHelpTap: _replayMatchDetailCoachMarks,
            onNotificationTap: _openNotificationCenter,
            notificationCount: _notificationUnreadCount,
            showSearch: false,
            wrapHelpButton: _wrapMatchDetailHelpButton,
          ),
          body: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () {
              FocusScope.of(context).unfocus();
              _appBarKey.currentState?.closeSearch();
            },
            child: Stack(
              children: [
                if (isPlayersSection)
                  NestedScrollView(
                    controller: _scrollController,
                    headerSliverBuilder: (context, innerBoxIsScrolled) {
                      return [
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const SizedBox(height: 0),
                                _buildFantasyLeagueHeader(_fantasyDraft!),
                                _buildSectionTabs(),
                              ],
                            ),
                          ),
                        ),
                      ];
                    },
                    body: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: _buildFantasySectionContent(_fantasyDraft!),
                    ),
                  )
                else
                  SingleChildScrollView(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 0),
                        _buildFantasyLeagueHeader(_fantasyDraft!),
                        _buildSectionTabs(),
                        const SizedBox(height: 18),
                        _buildFantasySectionContent(_fantasyDraft!),
                      ],
                    ),
                  ),
                ValueListenableBuilder<bool>(
                  valueListenable: _myPageOpen,
                  builder: (context, isOpen, child) {
                    return _MyPagePopupOverlay(
                      isOpen: isOpen,
                      onDismiss: _closeMyPageOverlay,
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
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_isResolvingFantasyDraft) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: LeagueItSubAppBar(
          key: _appBarKey,
          onMyPageTap: _toggleMyPageOverlay,
          onHelpTap: _replayMatchDetailCoachMarks,
          onNotificationTap: _openNotificationCenter,
          notificationCount: _notificationUnreadCount,
          showSearch: false,
          wrapHelpButton: _wrapMatchDetailHelpButton,
        ),
        body: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 12),
              Text(
                '매치업 데이터 준비 중',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      );
    }

    if (!kUseMockDataOutsideDraft) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: LeagueItSubAppBar(
          key: _appBarKey,
          onMyPageTap: _toggleMyPageOverlay,
          onHelpTap: _replayMatchDetailCoachMarks,
          onNotificationTap: _openNotificationCenter,
          notificationCount: _notificationUnreadCount,
          showSearch: false,
          wrapHelpButton: _wrapMatchDetailHelpButton,
        ),
        body: Stack(
          children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _comingSoonCard(
                  '실데이터 연동 준비 중',
                  subtitle:
                      'Matchup, Roster, Players, League 데이터는 API/Firebase 연동 후 제공됩니다.',
                ),
              ),
            ),
            ValueListenableBuilder<bool>(
              valueListenable: _myPageOpen,
              builder: (context, isOpen, child) {
                return _MyPagePopupOverlay(
                  isOpen: isOpen,
                  onDismiss: _closeMyPageOverlay,
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
                );
              },
            ),
          ],
        ),
      );
    }

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
    final isPlayersSection = _section == _MatchSection.players;
    final playersSection = _section == _MatchSection.players
        ? _playersSectionBundle()
        : null;
    final rosterLockState = _rosterLockState;
    return PopScope<Object?>(
      canPop: !_rosterDirty || _allowImmediateRoutePop,
      onPopInvokedWithResult: _handleRoutePopInvoked,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: LeagueItSubAppBar(
          key: _appBarKey,
          onMyPageTap: _toggleMyPageOverlay,
          onHelpTap: _replayMatchDetailCoachMarks,
          onNotificationTap: _openNotificationCenter,
          notificationCount: _notificationUnreadCount,
          showSearch: false,
          wrapHelpButton: _wrapMatchDetailHelpButton,
        ),
        body: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () {
            FocusScope.of(context).unfocus();
            _appBarKey.currentState?.closeSearch();
          },
          child: Stack(
            children: [
              if (isPlayersSection)
                NestedScrollView(
                  controller: _scrollController,
                  headerSliverBuilder: (context, innerBoxIsScrolled) {
                    return [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const SizedBox(height: 8),
                              _buildSectionTabs(),
                            ],
                          ),
                        ),
                      ),
                    ];
                  },
                  body: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: _buildSectionContent(
                        key: ValueKey(_section),
                        context: context,
                        section: _section,
                        lineup: _lineup,
                        isSoccer: widget.isSoccer,
                        allPlayers: _allPlayers,
                        filteredPlayersOverride:
                            playersSection?.filteredPlayers,
                        startingSlots: _starting,
                        benchSlots: _bench,
                        onSwapPlayer: _swapPlayers,
                        onSignFreeAgent: _trySignFreeAgent,
                        onTradeRequest: _requestTrade,
                        onReleasePlayer: _releaseMyPlayer,
                        isLocked: rosterLockState.isLocked,
                        rosterUnlocksAtUtc: rosterLockState.unlocksAtUtc,
                        homeRecord: homeRecord,
                        awayRecord: awayRecord,
                        profileAptsFuture: playersSection?.profileAptsFuture,
                        maxVisiblePlayers: _playersVisibleCount,
                        searchQuery: _playerSearch,
                        showPlayerFilters: _showPlayerFilters,
                        showOnlyFreeAgents: _showOnlyFreeAgents,
                        sortPlayersByAptsDesc: _sortPlayersByAptsDesc,
                        positionFilter: _playerPositionFilter,
                        onToggleShowPlayerFilters: () => setState(() {
                          _showPlayerFilters = !_showPlayerFilters;
                          _playersVisibleCount = _initialPlayersVisibleCount;
                        }),
                        onToggleShowOnlyFreeAgents: (v) => setState(() {
                          _showOnlyFreeAgents = v;
                          _playersVisibleCount = _initialPlayersVisibleCount;
                        }),
                        onToggleSortPlayersByAptsDesc: (v) => setState(() {
                          _sortPlayersByAptsDesc = v;
                          _playersVisibleCount = _initialPlayersVisibleCount;
                        }),
                        onPositionFilterChanged: (value) => setState(() {
                          _playerPositionFilter = value;
                          _playersVisibleCount = _initialPlayersVisibleCount;
                        }),
                        onSearchChanged: _handlePlayerSearchChanged,
                        searchController: _playerSearchController,
                        onRosterDragUpdate: _maybeAutoScrollRoster,
                        usePrimaryPlayersScroll: true,
                      ),
                    ),
                  ),
                )
              else
                SingleChildScrollView(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 8),
                      _buildSectionTabs(),
                      const SizedBox(height: 14),
                      if (_section == _MatchSection.matchup &&
                          widget.isSoccer) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _TeamBadge(
                              icon: widget.isSoccer
                                  ? Icons.shield_outlined
                                  : Icons.sports_baseball,
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
                                  '승리 확률',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                            _TeamBadge(
                              icon: widget.isSoccer
                                  ? Icons.workspace_premium_outlined
                                  : Icons.emoji_events_outlined,
                              label: '${((1 - winPctHome) * 100).round()}%',
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _WinBar(homeRatio: winPctHome),
                        const SizedBox(height: 12),
                      ],
                      if (_section == _MatchSection.matchup &&
                          !widget.isSoccer) ...[
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
                          filteredPlayersOverride:
                              playersSection?.filteredPlayers,
                          startingSlots: _starting,
                          benchSlots: _bench,
                          onSwapPlayer: _swapPlayers,
                          onSignFreeAgent: _trySignFreeAgent,
                          onTradeRequest: _requestTrade,
                          onReleasePlayer: _releaseMyPlayer,
                          isLocked: rosterLockState.isLocked,
                          rosterUnlocksAtUtc: rosterLockState.unlocksAtUtc,
                          homeRecord: homeRecord,
                          awayRecord: awayRecord,
                          profileAptsFuture: playersSection?.profileAptsFuture,
                          maxVisiblePlayers: null,
                          searchQuery: _playerSearch,
                          showPlayerFilters: _showPlayerFilters,
                          showOnlyFreeAgents: _showOnlyFreeAgents,
                          sortPlayersByAptsDesc: _sortPlayersByAptsDesc,
                          positionFilter: _playerPositionFilter,
                          onToggleShowPlayerFilters: () => setState(() {
                            _showPlayerFilters = !_showPlayerFilters;
                            _playersVisibleCount = _initialPlayersVisibleCount;
                          }),
                          onToggleShowOnlyFreeAgents: (v) => setState(() {
                            _showOnlyFreeAgents = v;
                            _playersVisibleCount = _initialPlayersVisibleCount;
                          }),
                          onToggleSortPlayersByAptsDesc: (v) => setState(() {
                            _sortPlayersByAptsDesc = v;
                            _playersVisibleCount = _initialPlayersVisibleCount;
                          }),
                          onPositionFilterChanged: (value) => setState(() {
                            _playerPositionFilter = value;
                            _playersVisibleCount = _initialPlayersVisibleCount;
                          }),
                          onSearchChanged: _handlePlayerSearchChanged,
                          searchController: _playerSearchController,
                          onRosterDragUpdate: _maybeAutoScrollRoster,
                        ),
                      ),
                    ],
                  ),
                ),
              ValueListenableBuilder<bool>(
                valueListenable: _myPageOpen,
                builder: (context, isOpen, child) {
                  return _MyPagePopupOverlay(
                    isOpen: isOpen,
                    onDismiss: _closeMyPageOverlay,
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
                  );
                },
              ),
            ],
          ),
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
  final palette = _leagueItSurfacePalette(context);
  showDialog(
    context: context,
    barrierColor: Colors.black45,
    builder: (_) => AlertDialog(
      backgroundColor: palette.fieldFill,
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
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: palette.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${slot.position} · ${slot.score} pts',
            style: TextStyle(fontSize: 14, color: palette.mutedInk),
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
                  metaOverride: _DocPlayerMeta(
                    position: slot.position,
                    club: slot.club,
                    number: slot.number,
                  ),
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

Future<Map<String, double>> _loadProfileAptsForSlots(
  List<_PlayerSlot> players, {
  required bool isSoccer,
  bool allowKboHistoryFetch = true,
}) async {
  if (isSoccer) {
    await _restorePersistedKLeaguePlayerAptsCache();
    await _restorePersistedKLeaguePlayerRoundPointsCache();
    final unique = <String, ({String name, String club, int number})>{};
    for (final player in players) {
      final club = _slotClub(player);
      final key = _slotAptsKey(player);
      unique[key] = (name: player.name, club: club, number: player.number);
    }

    final results = <String, double>{};
    for (final entry in unique.entries) {
      final roundPoints = _cachedKLeagueRoundPointsForPlayer(
        playerName: entry.value.name,
        club: entry.value.club,
        preferredNumber: entry.value.number,
      );
      if (roundPoints != null) {
        final apts = _kLeagueAptsFromRoundPoints(roundPoints);
        if (apts != null) {
          results[entry.key] = apts;
        }
        continue;
      }
      final cachedApts = _cachedKLeaguePlayerApts[entry.key];
      if (cachedApts != null) {
        results[entry.key] = cachedApts;
      }
    }
    final pending = unique.entries
        .where((entry) => !results.containsKey(entry.key))
        .toList();
    if (pending.isEmpty) {
      return results;
    }

    const batchSize = 3;
    for (var start = 0; start < pending.length; start += batchSize) {
      final end = min(start + batchSize, pending.length);
      final batch = pending.sublist(start, end);
      final batchEntries = await Future.wait(
        batch.map((entry) async {
          try {
            final value = await _loadKLeaguePlayerAptsShared(
              playerName: entry.value.name,
              club: entry.value.club,
              preferredNumber: entry.value.number,
            );
            return MapEntry(entry.key, value);
          } catch (error, stackTrace) {
            debugPrint(
              'Profile Apts load failed for ${entry.value.name} '
              '(${entry.value.club}): $error',
            );
            debugPrint('$stackTrace');
            return MapEntry<String, double?>(entry.key, null);
          }
        }),
      );
      for (final entry in batchEntries) {
        if (entry.value != null) {
          results[entry.key] = entry.value!;
        }
      }
    }
    return results;
  }

  await _restorePersistedKboPlayerAptsCache();
  final unique =
      <String, ({String name, String club, int number, String position})>{};
  await _restorePersistedKLeaguePlayerRoundPointsCache();
  for (final player in players) {
    final key = _slotAptsKey(player);
    unique[key] = (
      name: player.name,
      club: _normalizeKboDraftClub(player.club),
      number: player.number,
      position: player.position,
    );
  }

  final results = <String, double>{};
  for (final entry in unique.entries) {
    final apts = _cachedFullSeasonKboAptsForPlayer(
      playerName: entry.value.name,
      club: entry.value.club,
      preferredNumber: entry.value.number,
      preferredPosition: entry.value.position,
    );
    if (apts != null) {
      results[entry.key] = apts;
    }
  }

  final pending = unique.entries
      .where((entry) => !results.containsKey(entry.key))
      .toList();
  if (pending.isEmpty) {
    return results;
  }

  const batchSize = 2;
  for (var start = 0; start < pending.length; start += batchSize) {
    final end = min(start + batchSize, pending.length);
    final batch = pending.sublist(start, end);
    final batchEntries = await Future.wait(
      batch.map((entry) async {
        try {
          final value = await _loadKboPlayerAptsShared(
            playerName: entry.value.name,
            club: entry.value.club,
            preferredNumber: entry.value.number,
            preferredPosition: entry.value.position,
            allowHistoryFetch: allowKboHistoryFetch,
          );
          return MapEntry(entry.key, value);
        } catch (error, stackTrace) {
          debugPrint(
            'KBO profile Apts load failed for ${entry.value.name} '
            '(${entry.value.club}): $error',
          );
          debugPrint('$stackTrace');
          return MapEntry<String, double?>(entry.key, null);
        }
      }),
    );
    for (final entry in batchEntries) {
      if (entry.value != null) {
        results[entry.key] = entry.value!;
      }
    }
  }
  return results;
}

Map<String, double> _cachedProfileAptsForSlots(
  List<_PlayerSlot> players, {
  required bool isSoccer,
}) {
  final results = <String, double>{};
  for (final player in players) {
    final key = _slotAptsKey(player);
    if (isSoccer) {
      final cached = _cachedKLeaguePlayerApts[key];
      if (cached != null) {
        results[key] = cached;
      }
      continue;
    }
    final apts = _cachedFullSeasonKboAptsForPlayer(
      playerName: player.name,
      club: _normalizeKboDraftClub(player.club),
      preferredNumber: player.number,
      preferredPosition: player.position,
    );
    if (apts != null) {
      results[key] = apts;
      continue;
    }
  }
  return results;
}

enum _MatchSection { matchup, roster, players, league }

enum _PlayerPositionFilter { all, gk, df, mf, fw, p, c, inf, of }

List<(_PlayerPositionFilter, String)> _playerPositionFiltersForSport(
  bool isSoccer,
) {
  return isSoccer
      ? const [
          (_PlayerPositionFilter.all, '전체'),
          (_PlayerPositionFilter.gk, 'GK'),
          (_PlayerPositionFilter.df, 'DF'),
          (_PlayerPositionFilter.mf, 'MF'),
          (_PlayerPositionFilter.fw, 'FW'),
        ]
      : const [
          (_PlayerPositionFilter.all, '전체'),
          (_PlayerPositionFilter.p, 'P'),
          (_PlayerPositionFilter.c, 'C'),
          (_PlayerPositionFilter.inf, 'IF'),
          (_PlayerPositionFilter.of, 'OF'),
        ];
}

String _playerPositionFilterLabel(_PlayerPositionFilter filter) {
  return switch (filter) {
    _PlayerPositionFilter.all => '전체',
    _PlayerPositionFilter.gk => 'GK',
    _PlayerPositionFilter.df => 'DF',
    _PlayerPositionFilter.mf => 'MF',
    _PlayerPositionFilter.fw => 'FW',
    _PlayerPositionFilter.p => 'P',
    _PlayerPositionFilter.c => 'C',
    _PlayerPositionFilter.inf => 'IF',
    _PlayerPositionFilter.of => 'OF',
  };
}

bool _playerMatchesPositionFilter(
  _PlayerSlot player, {
  required bool isSoccer,
  required _PlayerPositionFilter filter,
}) {
  return switch (filter) {
    _PlayerPositionFilter.all => true,
    _PlayerPositionFilter.gk => isSoccer && player.position == 'GK',
    _PlayerPositionFilter.df => isSoccer && player.position == 'DF',
    _PlayerPositionFilter.mf => isSoccer && player.position == 'MF',
    _PlayerPositionFilter.fw => isSoccer && player.position == 'FW',
    _PlayerPositionFilter.p => !isSoccer && player.position == 'P',
    _PlayerPositionFilter.c => !isSoccer && player.position == 'C',
    _PlayerPositionFilter.inf => !isSoccer && player.position == 'IF',
    _PlayerPositionFilter.of => !isSoccer && player.position == 'OF',
  };
}

bool _playerMatchesQuery(
  _PlayerSlot player, {
  required String normalizedQuery,
  required bool isSoccer,
}) {
  if (normalizedQuery.isEmpty) return true;
  final club = _slotClub(player);
  final displayClub = _slotDisplayClub(player, isSoccer: isSoccer);
  return player.name.toLowerCase().contains(normalizedQuery) ||
      club.toLowerCase().contains(normalizedQuery) ||
      displayClub.toLowerCase().contains(normalizedQuery);
}

int _comparePlayersByDisplayOrder(
  _PlayerSlot left,
  _PlayerSlot right, {
  required bool isSoccer,
}) {
  final clubCompare = _slotDisplayClub(
    left,
    isSoccer: isSoccer,
  ).compareTo(_slotDisplayClub(right, isSoccer: isSoccer));
  if (clubCompare != 0) return clubCompare;
  final positionCompare = left.position.compareTo(right.position);
  if (positionCompare != 0) return positionCompare;
  final numberCompare = left.number.compareTo(right.number);
  if (numberCompare != 0) return numberCompare;
  return left.name.compareTo(right.name);
}

Widget _playersActionButton({
  required String label,
  required Color foregroundColor,
  required Color backgroundColor,
  required Color borderColor,
  required VoidCallback onTap,
}) {
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(999),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor, width: 1.2),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          color: foregroundColor,
        ),
      ),
    ),
  );
}

Widget _lockedActionIcon({
  required BuildContext context,
  String tooltip = '잠김',
  EdgeInsetsGeometry padding = const EdgeInsets.symmetric(
    horizontal: 10,
    vertical: 8,
  ),
}) {
  final palette = _leagueItSurfacePalette(context);
  return Tooltip(
    message: tooltip,
    child: Container(
      padding: padding,
      decoration: BoxDecoration(
        color: palette.tileSurface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: palette.cardBorder, width: 1.2),
      ),
      child: Icon(Icons.lock_rounded, size: 16, color: palette.mutedInk),
    ),
  );
}

List<String> _aptsRankingPositions(bool isSoccer) =>
    isSoccer ? const ['GK', 'DF', 'MF', 'FW'] : const ['P', 'C', 'IF', 'OF'];

Color _positionAccentColor(String position) => switch (position) {
  'GK' => const Color(0xFF6F88A6),
  'DF' => const Color(0xFF557AA4),
  'MF' => const Color(0xFF2D8A61),
  'FW' => const Color(0xFFC07A2C),
  'P' => const Color(0xFF5B6CFF),
  'C' => const Color(0xFF00897B),
  'IF' => const Color(0xFFEF6C00),
  'OF' => const Color(0xFF8E24AA),
  _ => const Color(0xFF4A82FF),
};

Widget _buildSectionContent({
  Key? key,
  required BuildContext context,
  required _MatchSection section,
  _LineupData? lineup,
  required bool isSoccer,
  Future<Map<String, double>>? profileAptsFuture,
  List<_PlayerSlot>? allPlayers,
  List<_PlayerSlot>? filteredPlayersOverride,
  List<_PlayerSlot>? startingSlots,
  List<_PlayerSlot>? benchSlots,
  void Function(_PlayerSlot, _PlayerSlot)? onSwapPlayer,
  Future<void> Function(_PlayerSlot)? onSignFreeAgent,
  Future<void> Function(_PlayerSlot)? onTradeRequest,
  Future<void> Function(_PlayerSlot)? onReleasePlayer,
  bool Function(_PlayerSlot slot)? isLocked,
  DateTime? rosterUnlocksAtUtc,
  required String homeRecord,
  required String awayRecord,
  int? maxVisiblePlayers,
  String searchQuery = '',
  bool showPlayerFilters = false,
  bool showOnlyFreeAgents = false,
  bool sortPlayersByAptsDesc = false,
  _PlayerPositionFilter positionFilter = _PlayerPositionFilter.all,
  VoidCallback? onToggleShowPlayerFilters,
  void Function(bool)? onToggleShowOnlyFreeAgents,
  void Function(bool)? onToggleSortPlayersByAptsDesc,
  void Function(_PlayerPositionFilter)? onPositionFilterChanged,
  void Function(String)? onSearchChanged,
  TextEditingController? searchController,
  void Function(Offset globalPosition)? onRosterDragUpdate,
  ScrollController? playersScrollController,
  bool usePrimaryPlayersScroll = false,
}) {
  final palette = _leagueItSurfacePalette(context);
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
            ownership:
                _MatchDetailPageState._playerOwnerCache[slot.name] ??
                PlayerOwnership.freeAgent,
          ),
        );
      }
      return Container(
        key: key,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: palette.tileSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: palette.cardBorder),
        ),
        child: Text(
          'KBO 매치업 상세는 준비 중입니다.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: palette.ink,
          ),
        ),
      );

    case _MatchSection.roster:
      final startList = startingSlots ?? [];
      final benchList = benchSlots ?? [];
      if (startList.isEmpty &&
          benchList.isEmpty &&
          lineup == null &&
          (allPlayers == null || allPlayers.isEmpty)) {
        return const SizedBox.shrink();
      }

      void openMyPlayerProfile(_PlayerSlot p) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PlayerProfilePage(
              name: p.name,
              ownership: PlayerOwnership.myTeam,
              metaOverride: _DocPlayerMeta(
                position: p.position,
                club: p.club,
                number: p.number,
              ),
            ),
          ),
        );
      }

      if (!isSoccer) {
        return Container(
          key: key,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: palette.fieldFill,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: palette.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'My Team',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: palette.ink,
                ),
              ),
              const SizedBox(height: 14),
              _FantasyBaseballRosterDiamond(
                starting: startList,
                onSwap: onSwapPlayer,
                onTap: openMyPlayerProfile,
                onDragUpdate: onRosterDragUpdate,
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: null,
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    disabledBackgroundColor: const Color(0xFFD1D7E5),
                    disabledForegroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    '저장',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '교체명단',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: palette.ink,
                ),
              ),
              const SizedBox(height: 8),
              _FantasyBenchList(
                players: benchList,
                onSwap: onSwapPlayer,
                onTap: openMyPlayerProfile,
                onDragUpdate: onRosterDragUpdate,
              ),
            ],
          ),
        );
      }

      final rosterByName = <String, _PlayerSlot>{
        for (final p in [...startList, ...benchList]) _playerSlotIdentity(p): p,
      };
      final homeRows = lineup?.home ?? _rowsFromSoccerStartingSlots(startList);
      final displayRows =
          homeRows.isNotEmpty &&
              homeRows.first.slots.isNotEmpty &&
              homeRows.first.slots.first.position == 'GK'
          ? homeRows.reversed.toList()
          : homeRows;

      return Container(
        key: key,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: palette.fieldFill,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: palette.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'My Roster',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: palette.ink,
              ),
            ),
            const SizedBox(height: 14),
            _FantasyRosterHalfPitch(
              rows: displayRows,
              rosterByName: rosterByName,
              color: Colors.blueAccent,
              goalkeeperRowOffset: 24,
              captainName: startList.isEmpty
                  ? null
                  : ([...startList]..sort(
                          (a, b) => _fantasyProjectedSlotScore(
                            b,
                          ).compareTo(_fantasyProjectedSlotScore(a)),
                        ))
                        .first
                        .name,
              viceCaptainName: startList.length < 2
                  ? null
                  : ([...startList]..sort(
                          (a, b) => _fantasyProjectedSlotScore(
                            b,
                          ).compareTo(_fantasyProjectedSlotScore(a)),
                        ))[1]
                        .name,
              onSwap: onSwapPlayer,
              onTap: openMyPlayerProfile,
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: null,
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  disabledBackgroundColor: const Color(0xFFD1D7E5),
                  disabledForegroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  '저장',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              '교체명단',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: palette.ink,
              ),
            ),
            const SizedBox(height: 8),
            _FantasyBenchList(
              players: benchList,
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
              builder: (_) => _SimpleListPage(
                title: title,
                items: items,
                isSoccer: isSoccer,
              ),
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
              color: palette.fieldFill,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: palette.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '이주의 선수',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: palette.ink,
                  ),
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
      if (allPlayers == null || allPlayers.isEmpty) {
        return Container(
          key: key,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: palette.fieldFill,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: palette.cardBorder),
          ),
          child: Text(
            isSoccer ? '선수 목록을 불러오는 중입니다.' : 'KBO 선수 목록을 불러오는 중입니다.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: palette.ink,
            ),
          ),
        );
      }
      final allSlots = allPlayers;
      final q = searchQuery.trim().toLowerCase();
      final baseFiltered =
          filteredPlayersOverride ??
                allSlots
                    .where((player) {
                      if (showOnlyFreeAgents &&
                          _ownerForSlot(player) != PlayerOwnership.freeAgent) {
                        return false;
                      }
                      if (!_playerMatchesPositionFilter(
                        player,
                        isSoccer: isSoccer,
                        filter: positionFilter,
                      )) {
                        return false;
                      }
                      return _playerMatchesQuery(
                        player,
                        normalizedQuery: q,
                        isSoccer: isSoccer,
                      );
                    })
                    .toList(growable: false)
            ..sort(
              (left, right) => _comparePlayersByDisplayOrder(
                left,
                right,
                isSoccer: isSoccer,
              ),
            );
      final positionFilters = _playerPositionFiltersForSport(isSoccer);
      final sortLabel = 'Apts 높은 순';
      final rosterUnlockLabel = rosterUnlocksAtUtc != null
          ? _kstMonthDayTimeLabel(rosterUnlocksAtUtc)
          : null;
      PlayerOwnership ownOf(_PlayerSlot p) => _ownerForSlot(p);
      final lockedPlayerIds = isLocked == null
          ? const <String>{}
          : <String>{
              for (final player in allSlots)
                if (isLocked(player)) _playerSlotIdentity(player),
            };
      bool isLockedForSlot(_PlayerSlot p) =>
          lockedPlayerIds.contains(_playerSlotIdentity(p));
      final faCount = allSlots
          .where((p) => ownOf(p) == PlayerOwnership.freeAgent)
          .length;
      final filterSummary = <String>[
        if (sortPlayersByAptsDesc) sortLabel,
        if (positionFilter != _PlayerPositionFilter.all)
          _playerPositionFilterLabel(positionFilter),
        if (showOnlyFreeAgents) 'FA만',
      ].where((label) => label.isNotEmpty).join(' · ');
      Widget actionButton(_PlayerSlot p, PlayerOwnership ownership) {
        if (isLockedForSlot(p)) {
          return _lockedActionIcon(
            context: context,
            tooltip: rosterUnlockLabel == null
                ? '해당 선수는 잠겼습니다.'
                : '해당 선수는 $rosterUnlockLabel까지 잠겼습니다.',
          );
        }
        switch (ownership) {
          case PlayerOwnership.freeAgent:
            return _playersActionButton(
              label: '영입',
              foregroundColor: const Color(0xFF2E8B57),
              backgroundColor: const Color(0xFFE6F6EC),
              borderColor: const Color(0xFF2E8B57),
              onTap: () => onSignFreeAgent?.call(p),
            );
          case PlayerOwnership.otherTeam:
            return _playersActionButton(
              label: '트레이드',
              foregroundColor: const Color(0xFF2E6BFF),
              backgroundColor: const Color(0xFFEAF1FF),
              borderColor: const Color(0xFF2E6BFF),
              onTap: () => onTradeRequest?.call(p),
            );
          case PlayerOwnership.myTeam:
            return _playersActionButton(
              label: '방출',
              foregroundColor: const Color(0xFFE85C53),
              backgroundColor: const Color(0xFFFFECEA),
              borderColor: const Color(0xFFE85C53),
              onTap: () => onReleasePlayer?.call(p),
            );
        }
      }

      Widget buildPlayerRow(_PlayerSlot p, Map<String, double> aptsMap) {
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

        final apts = aptsMap[_slotAptsKey(p)];
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: statusColor(ownership).withOpacity(0.14),
                border: Border.all(color: statusColor(ownership), width: 1.2),
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
                        metaOverride: _DocPlayerMeta(
                          position: p.position,
                          club: p.club,
                          number: p.number,
                        ),
                        onSign:
                            ownership == PlayerOwnership.freeAgent &&
                                !isLockedForSlot(p)
                            ? () => onSignFreeAgent?.call(p) ?? Future.value()
                            : null,
                        onTradeRequest:
                            ownership == PlayerOwnership.otherTeam &&
                                !isLockedForSlot(p)
                            ? () => onTradeRequest?.call(p) ?? Future.value()
                            : null,
                        onRelease:
                            ownership == PlayerOwnership.myTeam &&
                                !isLockedForSlot(p)
                            ? () => onReleasePlayer?.call(p) ?? Future.value()
                            : null,
                        showLockedAction:
                            ownership != PlayerOwnership.myTeam &&
                            isLockedForSlot(p),
                        lockedActionMessage: rosterUnlockLabel == null
                            ? '해당 선수는 잠겼습니다.'
                            : '해당 선수는 $rosterUnlockLabel까지 잠겼습니다.',
                      ),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Text(
                            p.name,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: palette.ink,
                            ),
                          ),
                          Text(
                            '${p.position} · ${_slotDisplayClub(p, isSoccer: isSoccer)}${p.number > 0 ? ' · #${p.number}' : ''}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: palette.mutedInk,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      if (isSoccer)
                        Text(
                          apts == null
                              ? 'Apts —'
                              : 'Apts ${apts.toStringAsFixed(1)}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: _aptsDisplayColor(apts),
                          ),
                        )
                      else
                        Text(
                          apts == null
                              ? 'Apts —'
                              : 'Apts ${apts.toStringAsFixed(1)}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: _aptsDisplayColor(apts),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            actionButton(p, ownership),
          ],
        );
      }

      return FutureBuilder<Map<String, double>>(
        future:
            profileAptsFuture ??
            Future.value(
              _cachedProfileAptsForSlots(baseFiltered, isSoccer: isSoccer),
            ),
        builder: (context, snapshot) {
          final aptsSourcePlayers = sortPlayersByAptsDesc
              ? baseFiltered
              : (maxVisiblePlayers == null
                    ? baseFiltered
                    : baseFiltered.take(maxVisiblePlayers).toList());
          final aptsMap = {
            ..._cachedProfileAptsForSlots(
              aptsSourcePlayers,
              isSoccer: isSoccer,
            ),
            ...?snapshot.data,
          };

          double? aptsOf(_PlayerSlot p) {
            return aptsMap[_slotAptsKey(p)];
          }

          final filtered = sortPlayersByAptsDesc
              ? (List<_PlayerSlot>.from(baseFiltered)..sort((left, right) {
                  final scoreCompare = (aptsOf(right) ?? 0.0).compareTo(
                    aptsOf(left) ?? 0.0,
                  );
                  if (scoreCompare != 0) return scoreCompare;
                  return _comparePlayersByDisplayOrder(
                    left,
                    right,
                    isSoccer: isSoccer,
                  );
                }))
              : baseFiltered;
          final visibleFiltered = maxVisiblePlayers == null
              ? filtered
              : filtered.take(maxVisiblePlayers).toList();
          final hasMorePlayers = visibleFiltered.length < filtered.length;

          Future<void> openPlayersFilterSheet() async {
            var tempSortPlayersByAptsDesc = sortPlayersByAptsDesc;
            var tempShowOnlyFreeAgents = showOnlyFreeAgents;
            var tempPositionFilter = positionFilter;
            await showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (sheetContext) {
                return StatefulBuilder(
                  builder: (sheetContext, setModalState) {
                    final activeFilterCount = <Object>[
                      if (tempSortPlayersByAptsDesc) sortLabel,
                      if (tempPositionFilter != _PlayerPositionFilter.all)
                        tempPositionFilter,
                      if (tempShowOnlyFreeAgents) true,
                    ].length;
                    return SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 18),
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                          decoration: BoxDecoration(
                            color: palette.fieldFill,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: palette.cardBorder),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'Players 필터',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      color: palette.ink,
                                    ),
                                  ),
                                  const Spacer(),
                                  if (activeFilterCount > 0)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: palette.isDark
                                            ? const Color(0xFF223458)
                                            : const Color(0xFFEAF1FF),
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                      ),
                                      child: Text(
                                        '$activeFilterCount개 적용 중',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF2E6BFF),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 18),
                              Text(
                                '정렬',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  color: palette.mutedInk,
                                ),
                              ),
                              const SizedBox(height: 10),
                              FilterChip(
                                label: Text(
                                  sortLabel,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                selected: tempSortPlayersByAptsDesc,
                                onSelected: (selected) {
                                  setModalState(() {
                                    tempSortPlayersByAptsDesc = selected;
                                  });
                                },
                                backgroundColor: palette.tileSurface,
                                selectedColor: palette.accentSoft,
                                checkmarkColor: palette.accent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(999),
                                  side: BorderSide(color: palette.cardBorder),
                                ),
                              ),
                              const SizedBox(height: 18),
                              Text(
                                '포지션',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  color: palette.mutedInk,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  for (final entry in positionFilters)
                                    ChoiceChip(
                                      label: Text(
                                        entry.$2,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      selected: tempPositionFilter == entry.$1,
                                      onSelected: (_) {
                                        setModalState(() {
                                          tempPositionFilter = entry.$1;
                                        });
                                      },
                                      backgroundColor: palette.tileSurface,
                                      selectedColor: palette.isDark
                                          ? const Color(0xFF223458)
                                          : const Color(0xFFE8F0FF),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                        side: BorderSide(
                                          color: palette.cardBorder,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 18),
                              Text(
                                '대상',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  color: palette.mutedInk,
                                ),
                              ),
                              const SizedBox(height: 10),
                              FilterChip(
                                label: const Text(
                                  'FA만 보기',
                                  style: TextStyle(fontWeight: FontWeight.w800),
                                ),
                                selected: tempShowOnlyFreeAgents,
                                onSelected: (selected) {
                                  setModalState(() {
                                    tempShowOnlyFreeAgents = selected;
                                  });
                                },
                                backgroundColor: palette.tileSurface,
                                selectedColor: palette.isDark
                                    ? const Color(0xFF223458)
                                    : const Color(0xFFEAF1FF),
                                checkmarkColor: const Color(0xFF4A82FF),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(999),
                                  side: BorderSide(color: palette.cardBorder),
                                ),
                              ),
                              const SizedBox(height: 22),
                              Row(
                                children: [
                                  TextButton(
                                    onPressed: () {
                                      setModalState(() {
                                        tempSortPlayersByAptsDesc = false;
                                        tempShowOnlyFreeAgents = false;
                                        tempPositionFilter =
                                            _PlayerPositionFilter.all;
                                      });
                                    },
                                    child: const Text(
                                      '초기화',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.of(sheetContext).pop();
                                    },
                                    child: Text(
                                      '닫기',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: palette.mutedInk,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  FilledButton(
                                    onPressed: () {
                                      if (tempSortPlayersByAptsDesc !=
                                          sortPlayersByAptsDesc) {
                                        onToggleSortPlayersByAptsDesc?.call(
                                          tempSortPlayersByAptsDesc,
                                        );
                                      }
                                      if (tempShowOnlyFreeAgents !=
                                          showOnlyFreeAgents) {
                                        onToggleShowOnlyFreeAgents?.call(
                                          tempShowOnlyFreeAgents,
                                        );
                                      }
                                      if (tempPositionFilter !=
                                          positionFilter) {
                                        onPositionFilterChanged?.call(
                                          tempPositionFilter,
                                        );
                                      }
                                      Navigator.of(sheetContext).pop();
                                    },
                                    style: FilledButton.styleFrom(
                                      backgroundColor: const Color(0xFF11192A),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 18,
                                        vertical: 14,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    child: const Text(
                                      '적용',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            );
          }

          Widget buildEmptyState() {
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 22),
              alignment: Alignment.center,
              child: Text(
                showOnlyFreeAgents ||
                        positionFilter != _PlayerPositionFilter.all
                    ? '현재 조건에 맞는 선수가 없습니다.'
                    : '검색 결과가 없습니다.',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: palette.mutedInk,
                ),
              ),
            );
          }

          Widget buildPlayersSummaryRow() {
            return Row(
              children: [
                Text(
                  '총 ${filtered.length}명',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: palette.mutedInk,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'FA $faCount',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: palette.mutedInk,
                  ),
                ),
                if (filterSummary.isNotEmpty) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      filterSummary,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF4A82FF),
                      ),
                    ),
                  ),
                ],
              ],
            );
          }

          Widget buildPlayersTitle({Color? backgroundColor}) {
            return Container(
              color: backgroundColor,
              alignment: Alignment.centerLeft,
              child: Text(
                'Players',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: palette.ink,
                ),
              ),
            );
          }

          Widget buildPlayersSearchRow({Color? backgroundColor}) {
            return Builder(
              builder: (searchRowContext) {
                return Container(
                  color: backgroundColor,
                  alignment: Alignment.center,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: searchController,
                          style: TextStyle(color: palette.ink),
                          decoration: InputDecoration(
                            hintText: '선수 이름 또는 팀명 검색',
                            hintStyle: TextStyle(color: palette.mutedInk),
                            prefixIcon: Icon(
                              Icons.search,
                              color: palette.mutedInk,
                            ),
                            filled: true,
                            fillColor: palette.tileSurface,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: palette.cardBorder),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: palette.cardBorder),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                color: palette.accent,
                                width: 1.4,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                          ),
                          onChanged: onSearchChanged,
                          onTap: () {
                            Scrollable.ensureVisible(
                              searchRowContext,
                              alignment: 0.0,
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeOutCubic,
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        height: 56,
                        child: OutlinedButton.icon(
                          onPressed: openPlayersFilterSheet,
                          icon: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Icon(
                                filterSummary.isEmpty
                                    ? Icons.tune_rounded
                                    : Icons.filter_alt_rounded,
                                size: 18,
                              ),
                              if (filterSummary.isNotEmpty)
                                Positioned(
                                  right: -4,
                                  top: -4,
                                  child: Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF2E6BFF),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          label: Text(
                            filterSummary.isEmpty ? '필터' : '필터 적용',
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: filterSummary.isEmpty
                                ? palette.ink
                                : const Color(0xFF2E6BFF),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            side: BorderSide(
                              color: filterSummary.isEmpty
                                  ? palette.cardBorder
                                  : const Color(0xFF2E6BFF),
                            ),
                            backgroundColor: filterSummary.isEmpty
                                ? palette.tileSurface
                                : (palette.isDark
                                      ? const Color(0xFF223458)
                                      : const Color(0xFFEAF1FF)),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          }

          final playerList = filtered.isEmpty
              ? buildEmptyState()
              : ListView.separated(
                  controller: usePrimaryPlayersScroll
                      ? playersScrollController
                      : null,
                  primary: false,
                  shrinkWrap: !usePrimaryPlayersScroll,
                  physics: usePrimaryPlayersScroll
                      ? const AlwaysScrollableScrollPhysics()
                      : const NeverScrollableScrollPhysics(),
                  itemCount: visibleFiltered.length + (hasMorePlayers ? 1 : 0),
                  itemBuilder: (context, index) =>
                      index < visibleFiltered.length
                      ? buildPlayerRow(visibleFiltered[index], aptsMap)
                      : Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: Center(
                            child: Text(
                              '계속 스크롤하면 더 불러옵니다. '
                              '(${visibleFiltered.length}/${filtered.length})',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: palette.mutedInk,
                              ),
                            ),
                          ),
                        ),
                  separatorBuilder: (_, __) => Divider(
                    height: 12,
                    thickness: 1,
                    color: palette.cardBorder,
                  ),
                );
          final sliverChildCount = max(
            0,
            (visibleFiltered.length + (hasMorePlayers ? 1 : 0)) * 2 - 1,
          );

          const headerChildren = <Widget>[];

          return Container(
            key: key,
            padding: usePrimaryPlayersScroll
                ? EdgeInsets.zero
                : const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: palette.fieldFill,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: palette.cardBorder),
            ),
            child: usePrimaryPlayersScroll
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CustomScrollView(
                      controller: playersScrollController,
                      primary: playersScrollController == null,
                      slivers: [
                        const SliverToBoxAdapter(child: SizedBox(height: 20)),
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          sliver: SliverPersistentHeader(
                            pinned: true,
                            delegate: _PinnedBoxHeaderDelegate(
                              height: 34,
                              child: buildPlayersTitle(
                                backgroundColor: palette.fieldFill,
                              ),
                            ),
                          ),
                        ),
                        if (headerChildren.isNotEmpty)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                20,
                                10,
                                20,
                                10,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: headerChildren,
                              ),
                            ),
                          ),
                        const SliverToBoxAdapter(child: SizedBox(height: 6)),
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          sliver: SliverPersistentHeader(
                            pinned: true,
                            delegate: _PinnedBoxHeaderDelegate(
                              height: 56,
                              child: buildPlayersSearchRow(
                                backgroundColor: palette.fieldFill,
                              ),
                            ),
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                            child: buildPlayersSummaryRow(),
                          ),
                        ),
                        if (filtered.isEmpty)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                              child: buildEmptyState(),
                            ),
                          )
                        else
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate((
                                context,
                                index,
                              ) {
                                final logicalItemCount =
                                    visibleFiltered.length +
                                    (hasMorePlayers ? 1 : 0);
                                if (logicalItemCount <= 0) {
                                  return const SizedBox.shrink();
                                }
                                if (index.isOdd) {
                                  return Divider(
                                    height: 12,
                                    thickness: 1,
                                    color: palette.cardBorder,
                                  );
                                }
                                final itemIndex = index ~/ 2;
                                if (itemIndex < visibleFiltered.length) {
                                  return buildPlayerRow(
                                    visibleFiltered[itemIndex],
                                    aptsMap,
                                  );
                                }
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  child: Center(
                                    child: Text(
                                      '계속 스크롤하면 더 불러옵니다. '
                                      '(${visibleFiltered.length}/${filtered.length})',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: palette.mutedInk,
                                      ),
                                    ),
                                  ),
                                );
                              }, childCount: sliverChildCount),
                            ),
                          ),
                      ],
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      buildPlayersTitle(),
                      if (headerChildren.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        ...headerChildren,
                      ],
                      const SizedBox(height: 10),
                      buildPlayersSearchRow(),
                      const SizedBox(height: 12),
                      buildPlayersSummaryRow(),
                      const SizedBox(height: 12),
                      playerList,
                    ],
                  ),
          );
        },
      );
  }
}

class _PinnedBoxHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _PinnedBoxHeaderDelegate({required this.child, required this.height});

  final Widget child;
  final double height;

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return child;
  }

  @override
  bool shouldRebuild(covariant _PinnedBoxHeaderDelegate oldDelegate) {
    return oldDelegate.height != height || oldDelegate.child != child;
  }
}

class _LineupField extends StatelessWidget {
  final _LineupData lineup;
  final bool isSoccer;
  final String homeRecord;
  final String awayRecord;
  final double Function(_PlayerSlot slot)? scoreForSlot;
  final bool Function(_PlayerSlot slot)? isCaptainForSlot;
  final void Function(_PlayerSlot) onPlayerTap;

  const _LineupField({
    Key? key,
    required this.lineup,
    required this.isSoccer,
    required this.homeRecord,
    required this.awayRecord,
    this.scoreForSlot,
    this.isCaptainForSlot,
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
            color: homeColor,
            scoreForSlot: scoreForSlot,
            isCaptainForSlot: isCaptainForSlot,
            onTap: onPlayerTap,
          ),
          ..._positionRows(
            rows: lineup.away,
            top: margin + halfHeight,
            height: halfHeight,
            padding: padding,
            color: awayColor,
            scoreForSlot: scoreForSlot,
            isCaptainForSlot: isCaptainForSlot,
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
  final double Function(_PlayerSlot slot)? scoreForSlot;
  final bool Function(_PlayerSlot slot)? isCaptainForSlot;
  final void Function(_PlayerSlot) onTap;

  const _LineupRow({
    required this.players,
    required this.color,
    this.scoreForSlot,
    this.isCaptainForSlot,
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
                scoreForSlot: scoreForSlot,
                isCaptain: isCaptainForSlot?.call(slot) ?? false,
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
  final double Function(_PlayerSlot slot)? scoreForSlot;
  final bool isCaptain;
  final VoidCallback? onTap;

  const _PlayerChip({
    required this.slot,
    required this.color,
    this.scoreForSlot,
    this.isCaptain = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
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
              if (isCaptain)
                Positioned(
                  top: -4,
                  right: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFCF4D),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0xFFE0B331)),
                    ),
                    child: const Text(
                      'C',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1F1F1F),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${slot.name} / ${(scoreForSlot?.call(slot) ?? slot.score.toDouble()).toStringAsFixed(1)}',
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
  final List<_FantasyStandingRow>? standingRows;
  final List<_FantasyPowerRow>? powerRows;
  final String? highlightTeamName;
  final _JoinedDraft? fantasyDraft;
  const _SimpleListPage({
    required this.title,
    required this.items,
    required this.isSoccer,
    this.standingRows,
    this.powerRows,
    this.highlightTeamName,
    this.fantasyDraft,
  });

  @override
  State<_SimpleListPage> createState() => _SimpleListPageState();
}

class _SimpleListPageState extends State<_SimpleListPage> {
  bool _isMyPageOpen = false;
  void _toggleMyPage() => setState(() => _isMyPageOpen = !_isMyPageOpen);

  _FantasyTeamState? _boardFantasyTeam(String teamName) {
    final draft = widget.fantasyDraft;
    if (draft == null) return null;
    return _fantasyTeamByName(draft, teamName);
  }

  Widget _teamNameCell(
    String teamName, {
    double avatarSize = 30,
    double iconSize = 16,
    TextStyle? style,
  }) {
    final team = _boardFantasyTeam(teamName);
    return Row(
      children: [
        _FantasyTeamAvatar(
          uid: team?.uid ?? '',
          teamName: team?.teamName ?? teamName,
          size: avatarSize,
          iconSize: iconSize,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            teamName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
      ],
    );
  }

  String _extractTeamName(String raw) {
    var s = raw.trim();
    final rankPrefix = RegExp(r'^\d+\.\s*');
    s = s.replaceFirst(rankPrefix, '').trim();
    final mid = s.indexOf('·');
    if (mid != -1) s = s.substring(0, mid).trim();
    return s;
  }

  ({String team, String record, String points}) _standingParts(String raw) {
    final segments = raw.split('·').map((part) => part.trim()).toList();
    final team = _extractTeamName(raw);
    final record = segments.length > 1 ? segments[1] : '0-0-0';
    final points = segments.length > 2 ? segments[2] : '0.0 pts';
    return (team: team, record: record, points: points);
  }

  ({String team, String form, double recentAverage}) _powerParts(String raw) {
    final segments = raw.split('·').map((part) => part.trim()).toList();
    final team = _extractTeamName(raw);
    final form = segments.length > 1 ? segments[1] : '—';
    final avgSource = segments.length > 2 ? segments[2] : '0.0 Fpts';
    final recentAverage =
        double.tryParse(avgSource.replaceAll(RegExp(r'[^0-9.\-]'), '')) ?? 0.0;
    return (team: team, form: form, recentAverage: recentAverage);
  }

  Future<void> _openTeamDetail(String item) async {
    final team = _extractTeamName(item);
    final draft = widget.fantasyDraft;
    if (draft == null) return;
    final fantasyTeam = _fantasyTeamByName(draft, team);
    if (fantasyTeam == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _FantasyTeamProfilePage(
          draft: draft,
          team: fantasyTeam,
          isMyTeam: fantasyTeam.teamName == widget.highlightTeamName,
        ),
      ),
    );
  }

  Color _standingAccent(int index) {
    const palette = [
      Color(0xFF7AE582),
      Color(0xFF5BC0FF),
      Color(0xFF10B3A3),
      Color(0xFF6E7C91),
    ];
    return palette[index.clamp(0, palette.length - 1)];
  }

  double _standingTeamColumnWidth(
    BuildContext context,
    List<_FantasyStandingRow> rows, {
    required TextStyle textStyle,
  }) {
    final textScaler = MediaQuery.textScalerOf(context);
    var longestWidth = 0.0;
    for (final row in rows) {
      final painter = TextPainter(
        text: TextSpan(text: row.team, style: textStyle),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        textScaler: textScaler,
      )..layout();
      if (painter.width > longestWidth) {
        longestWidth = painter.width;
      }
    }

    const avatarWidth = 30.0;
    const spacingWidth = 10.0;
    const trailingBuffer = 12.0;
    const minWidth = 118.0;
    const maxWidth = 196.0;
    return (avatarWidth + spacingWidth + longestWidth + trailingBuffer).clamp(
      minWidth,
      maxWidth,
    );
  }

  Widget _buildStandingBoard() {
    final palette = _leagueItSurfacePalette(context);
    final leagueName = widget.fantasyDraft?.leagueName.trim() ?? '';
    final headerLeagueName = leagueName.isEmpty ? 'Fantasy League' : leagueName;
    final roundCount = max(1, widget.fantasyDraft?.roundCount ?? 1);
    final rows =
        widget.standingRows ??
        List.generate(widget.items.length, (index) {
          final parts = _standingParts(widget.items[index]);
          return _FantasyStandingRow(
            team: parts.team,
            played: 0,
            wins: 0,
            losses: 0,
            ties: 0,
            standingPoints:
                int.tryParse(
                  parts.points.replaceAll(RegExp(r'[^0-9\-]'), ''),
                ) ??
                0,
            scoredPoints: 0,
            allowedPoints: 0,
          );
        });

    const rankWidth = 44.0;
    const compactCellWidth = 50.0;
    const pointsCellWidth = 58.0;
    const scoreCellWidth = 72.0;
    const goalDiffCellWidth = 84.0;
    final teamNameTextStyle = TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.2,
      color: palette.ink,
    );
    final teamWidth = _standingTeamColumnWidth(
      context,
      rows,
      textStyle: teamNameTextStyle,
    );

    Widget headerCell(
      String label, {
      double width = compactCellWidth,
      TextAlign align = TextAlign.center,
    }) {
      return SizedBox(
        width: width,
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.visible,
          softWrap: false,
          textAlign: align,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: palette.mutedInk,
          ),
        ),
      );
    }

    Widget valueCell(
      String value, {
      double width = compactCellWidth,
      TextAlign align = TextAlign.center,
      Color? color,
      FontWeight weight = FontWeight.w800,
      double fontSize = 14,
    }) {
      return SizedBox(
        width: width,
        child: Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.visible,
          softWrap: false,
          textAlign: align,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: weight,
            color:
                color ??
                (palette.isDark ? Colors.white : const Color(0xFF101828)),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: palette.isDark
                  ? const [Color(0xFF152130), Color(0xFF1B5A52)]
                  : const [Color(0xFF13203B), Color(0xFF1A816F)],
            ),
            borderRadius: BorderRadius.circular(26),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        headerLeagueName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      '리그 순위표',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${rows.length}팀 · ${roundCount}라운드',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: palette.isDark
                            ? const Color(0xFFCFD8E6)
                            : const Color(0xFFD8E4F2),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.leaderboard_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Container(
          decoration: BoxDecoration(
            color: palette.fieldFill,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: palette.cardBorder),
            boxShadow: const [
              BoxShadow(
                color: Color(0x12111A2B),
                blurRadius: 22,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: palette.tileSurface,
                      border: Border(
                        bottom: BorderSide(color: palette.cardBorder),
                      ),
                    ),
                    child: Row(
                      children: [
                        headerCell(
                          '순위',
                          width: rankWidth,
                          align: TextAlign.left,
                        ),
                        headerCell(
                          '팀',
                          width: teamWidth,
                          align: TextAlign.left,
                        ),
                        headerCell('P'),
                        headerCell('W'),
                        headerCell('D'),
                        headerCell('L'),
                        headerCell('PTS', width: pointsCellWidth),
                        headerCell('F', width: scoreCellWidth),
                        headerCell('A', width: scoreCellWidth),
                        headerCell('GD', width: goalDiffCellWidth),
                      ],
                    ),
                  ),
                  for (int index = 0; index < rows.length; index++)
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _openTeamDetail(rows[index].team),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: rows[index].team == widget.highlightTeamName
                                ? (palette.isDark
                                      ? const Color(0xFF17372A)
                                      : const Color(0xFFEAF8F1))
                                : index.isEven
                                ? palette.fieldFill
                                : palette.tileSurface,
                            border: Border(
                              bottom: BorderSide(color: palette.cardBorder),
                            ),
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: rankWidth,
                                child: Row(
                                  children: [
                                    Container(
                                      width: 30,
                                      height: 30,
                                      decoration: BoxDecoration(
                                        color:
                                            rows[index].team ==
                                                widget.highlightTeamName
                                            ? const Color(0xFFB7E9CD)
                                            : (index < 3
                                                  ? _standingAccent(
                                                      index,
                                                    ).withValues(alpha: 0.16)
                                                  : (palette.isDark
                                                        ? const Color(
                                                            0xFF20272D,
                                                          )
                                                        : const Color(
                                                            0xFFF3F6FA,
                                                          ))),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        '${index + 1}',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w900,
                                          color:
                                              rows[index].team ==
                                                  widget.highlightTeamName
                                              ? const Color(0xFF147A52)
                                              : (index < 3
                                                    ? _standingAccent(index)
                                                    : const Color(0xFF475467)),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(
                                width: teamWidth,
                                child: _teamNameCell(
                                  rows[index].team,
                                  style: teamNameTextStyle,
                                ),
                              ),
                              valueCell('${rows[index].played}'),
                              valueCell('${rows[index].wins}'),
                              valueCell('${rows[index].ties}'),
                              valueCell('${rows[index].losses}'),
                              valueCell(
                                '${rows[index].standingPoints}',
                                width: pointsCellWidth,
                                color: palette.isDark
                                    ? Colors.white
                                    : const Color(0xFF16825D),
                                weight: FontWeight.w900,
                              ),
                              valueCell(
                                _formatFantasyFixtureScore(
                                  rows[index].scoredPoints,
                                ),
                                width: scoreCellWidth,
                              ),
                              valueCell(
                                _formatFantasyFixtureScore(
                                  rows[index].allowedPoints,
                                ),
                                width: scoreCellWidth,
                              ),
                              valueCell(
                                rows[index].goalDiff >= 0
                                    ? '+${_formatFantasyFixtureScore(rows[index].goalDiff)}'
                                    : _formatFantasyFixtureScore(
                                        rows[index].goalDiff,
                                      ),
                                width: goalDiffCellWidth,
                                fontSize: 13,
                                color: palette.isDark
                                    ? Colors.white
                                    : (rows[index].goalDiff >= 0
                                          ? const Color(0xFF16825D)
                                          : const Color(0xFFC0352B)),
                                weight: FontWeight.w900,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: palette.tileSurface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: palette.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'P: 경기수  W: 승  D: 무  L: 패',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: palette.ink,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'PTS: 승점  F: 득점  A: 실점  GD: 득실차',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: palette.ink,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPowerRankBoard() {
    final palette = _leagueItSurfacePalette(context);
    final rows =
        widget.powerRows ??
        List.generate(widget.items.length, (index) {
          final parts = _powerParts(widget.items[index]);
          return _FantasyPowerRow(
            team: parts.team,
            form: parts.form,
            recentAverage: parts.recentAverage,
            wins: 0,
            scoredPoints: 0,
          );
        });

    const rankWidth = 44.0;
    const streakWidth = 92.0;

    Widget headerCell(
      String label, {
      double width = streakWidth,
      TextAlign align = TextAlign.center,
    }) {
      return SizedBox(
        width: width,
        child: Text(
          label,
          textAlign: align,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: palette.mutedInk,
          ),
        ),
      );
    }

    Widget streakChip(String form) {
      final streak = form.replaceAll(' ', '').trim();
      final normalized = streak.isEmpty || streak == '—' ? '-' : streak;
      final positive = !normalized.contains('L') || normalized == '-';
      final fillColor = positive
          ? const Color(0xFFE7F7EE)
          : const Color(0xFFFCECEC);
      final strokeColor = positive
          ? const Color(0xFFB7DEC5)
          : const Color(0xFFE5BCBC);
      final textColor = positive
          ? const Color(0xFF11875D)
          : const Color(0xFFC0352B);
      return SizedBox(
        width: streakWidth,
        child: Align(
          alignment: Alignment.center,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              color: fillColor,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: strokeColor, width: 1.6),
            ),
            child: Text(
              normalized,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
                color: textColor,
              ),
            ),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF20193A), Color(0xFF0E8F7B)],
            ),
            borderRadius: BorderRadius.circular(26),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'Power Ranking',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      '현재 리그 흐름',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${rows.length}개 팀의 현재 전력 흐름을 순위표로 정리했습니다.',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFD8E4F2),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.bolt_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE6EBF2)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x12111A2B),
                blurRadius: 22,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: palette.tileSurface,
                    border: Border(
                      bottom: BorderSide(color: palette.cardBorder),
                    ),
                  ),
                  child: Row(
                    children: [
                      headerCell('순위', width: rankWidth, align: TextAlign.left),
                      Expanded(
                        child: Text(
                          'Team',
                          textAlign: TextAlign.left,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: palette.mutedInk,
                          ),
                        ),
                      ),
                      headerCell('Streak', width: streakWidth),
                    ],
                  ),
                ),
                for (int index = 0; index < rows.length; index++)
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _openTeamDetail(rows[index].team),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: rows[index].team == widget.highlightTeamName
                              ? (palette.isDark
                                    ? const Color(0xFF17372A)
                                    : const Color(0xFFEAF8F1))
                              : index.isEven
                              ? palette.fieldFill
                              : palette.tileSurface,
                          border: Border(
                            bottom: BorderSide(color: palette.cardBorder),
                          ),
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: rankWidth,
                              child: Row(
                                children: [
                                  Container(
                                    width: 30,
                                    height: 30,
                                    decoration: BoxDecoration(
                                      color:
                                          rows[index].team ==
                                              widget.highlightTeamName
                                          ? const Color(0xFFB7E9CD)
                                          : (index < 3
                                                ? _standingAccent(
                                                    index,
                                                  ).withValues(alpha: 0.16)
                                                : const Color(0xFFF3F6FA)),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      '${index + 1}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w900,
                                        color:
                                            rows[index].team ==
                                                widget.highlightTeamName
                                            ? const Color(0xFF147A52)
                                            : (index < 3
                                                  ? _standingAccent(index)
                                                  : const Color(0xFF475467)),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: _teamNameCell(
                                rows[index].team,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.2,
                                  color: palette.ink,
                                ),
                              ),
                            ),
                            streakChip(rows[index].form),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: palette.tileSurface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: palette.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Streak: 현재 연속 흐름',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: palette.ink,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '예시: W3, W2, W, L, L2, D',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: palette.ink,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = _leagueItSurfacePalette(context);
    final isStanding = widget.title == '리그 순위';
    final isPower = widget.title == '파워 랭킹';
    return _OverlayScaffold(
      isMyPageOpen: _isMyPageOpen,
      onToggleMyPage: _toggleMyPage,
      title: 'LeagueIt',
      showSearch: false,
      child: isStanding
          ? _buildStandingBoard()
          : isPower
          ? _buildPowerRankBoard()
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: widget.items.length,
              separatorBuilder: (_, __) => const SizedBox.shrink(),
              itemBuilder: (_, i) {
                return Card(
                  color: palette.fieldFill,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: palette.cardBorder),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      radius: 14,
                      backgroundColor: palette.tileSurface,
                      child: Text(
                        '${i + 1}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: palette.ink,
                        ),
                      ),
                    ),
                    title: Text(
                      widget.items[i],
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: palette.ink,
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _FantasyTeamProfilePage extends StatefulWidget {
  const _FantasyTeamProfilePage({
    required this.draft,
    required this.team,
    required this.isMyTeam,
  });

  final _JoinedDraft draft;
  final _FantasyTeamState team;
  final bool isMyTeam;

  @override
  State<_FantasyTeamProfilePage> createState() =>
      _FantasyTeamProfilePageState();
}

class _FantasyTeamProfilePageState extends State<_FantasyTeamProfilePage> {
  Map<String, double> _projectedScores = const <String, double>{};

  PlayerOwnership get _ownership =>
      widget.isMyTeam ? PlayerOwnership.myTeam : PlayerOwnership.otherTeam;

  @override
  void initState() {
    super.initState();
    if (!widget.draft.isSoccer) {
      unawaited(_primeKboProjectedScores());
    }
  }

  bool _isCaptainForTeam(_PlayerSlot slot) {
    final playerId = _playerSlotIdentity(slot);
    if (widget.team.captainPlayerId?.trim().isNotEmpty == true) {
      return widget.team.captainPlayerId == playerId;
    }
    return widget.team.captainName == slot.name;
  }

  double _projectedBaseForSlot(_PlayerSlot slot) {
    final cachedFallback = _cachedProjectedFallbackForSlot(
      slot,
      isSoccer: widget.draft.isSoccer,
    );
    final base =
        _projectedScores[_playerSlotIdentity(slot)] ??
        cachedFallback ??
        (widget.draft.isSoccer
            ? _fantasyProjectedSlotScore(slot, isSoccer: true)
            : 0.0);
    if (widget.draft.isSoccer) return base;

    final leagueData = _cachedKboLeagueData;
    final rawMatches = _fixtureAsList(leagueData?['matches']);
    if (rawMatches.isEmpty) return base;

    final now = DateTime.now();
    final fantasyRound = _currentFantasyRoundAt(widget.draft, now);
    if (!_kboFantasyRoundHasStarted(widget.draft, fantasyRound, now)) {
      return base;
    }

    final actual = _actualKboScoreForSlot(slot);
    final leagueRound = _mappedKboRoundForFantasyRound(
      widget.draft,
      fantasyRound,
    );
    final progress = _kboRoundProgressForClubFromMatches(
      rawMatches,
      club: slot.club,
      leagueRound: leagueRound,
      now: now,
    );
    return _liveAdjustedKboProjectedBaseScore(
      baseProjection: base,
      actualScore: actual,
      roundProgress: progress,
    );
  }

  double _projectedScoreForSlot(_PlayerSlot slot) {
    final base = _projectedBaseForSlot(slot);
    return _isCaptainForTeam(slot) ? base * 2 : base;
  }

  double _actualKboScoreForSlot(_PlayerSlot slot) {
    final fantasyRound = _currentFantasyRoundAt(widget.draft, DateTime.now());
    if (!_kboFantasyRoundHasStarted(
      widget.draft,
      fantasyRound,
      DateTime.now(),
    )) {
      return 0.0;
    }
    final absoluteRound = _mappedKboRoundForFantasyRound(
      widget.draft,
      fantasyRound,
    );
    final roundPoints = _cachedKboRoundPointsForPlayer(
      playerName: slot.name,
      club: _normalizeKboDraftClub(slot.club),
      preferredNumber: slot.number,
      preferredPosition: slot.position,
    );
    if (roundPoints == null) return 0.0;
    for (final entry in roundPoints) {
      if (entry.round == absoluteRound) {
        return _isCaptainForTeam(slot)
            ? entry.displayedPoints * 2
            : entry.displayedPoints;
      }
    }
    return 0.0;
  }

  Future<void> _primeKboProjectedScores() async {
    try {
      final projections = await _loadKboProjectedScoresForTeamProfile();
      if (!mounted) return;
      setState(() {
        _projectedScores = projections;
      });
    } catch (error, stackTrace) {
      debugPrint('FantasyTeamProfile KBO projected load failed: $error');
      debugPrint('$stackTrace');
    }
  }

  Future<Map<String, double>> _loadKboProjectedScoresForTeamProfile() async {
    await _restorePersistedKLeaguePlayerAptsCache();
    await _restorePersistedKLeaguePlayerRoundPointsCache();
    final leagueData = await _loadCachedKboLeagueData();
    final rawMatches = _fixtureAsList(leagueData['matches']);
    final targetFantasyRound = _currentFantasyRoundAt(
      widget.draft,
      DateTime.now(),
    );
    final targetKboRound = _mappedKboRoundForFantasyRound(
      widget.draft,
      targetFantasyRound,
    );
    final teamFormFactors = _kboTeamFormFactorsForTeamProfile(
      rawMatches,
      targetKboRound,
    );
    final opponentFormFactors = _kboOpponentFormFactorsForTeamProfile(
      rawMatches,
      targetKboRound,
      teamFormFactors,
    );

    final uniquePlayers = <String, _PlayerSlot>{};
    for (final player in widget.team.roster) {
      final slot = player.toPlayerSlot();
      uniquePlayers[_playerSlotIdentity(slot)] = slot;
    }

    await _primeKboProjectionSourceDataForSlots(
      uniquePlayers.values,
      targetRound: targetKboRound,
      includeTargetRoundLivePoints: _kboFantasyRoundHasStarted(
        widget.draft,
        targetFantasyRound,
        DateTime.now(),
      ),
    );
    final pitcherOpportunityFactors =
        await _loadKboPitcherWeeklyOpportunityFactors(
          uniquePlayers.values,
          rawMatches: rawMatches,
          targetRound: targetKboRound,
        );

    final projections = <String, double>{};
    for (final slot in uniquePlayers.values) {
      final club = _normalizeKboDraftClub(slot.club);
      final roundPoints =
          _cachedKboRoundPointsForPlayer(
            playerName: slot.name,
            club: club,
            preferredNumber: slot.number,
            preferredPosition: slot.position,
          ) ??
          const <_PlayerRoundPoints>[];
      projections[_playerSlotIdentity(slot)] = _projectKboFptsForTeamProfile(
        slot,
        roundPoints,
        targetRound: targetKboRound,
        teamFormFactor: teamFormFactors[club] ?? 1.0,
        opponentFormFactor: opponentFormFactors[club] ?? 1.0,
        pitcherOpportunityFactor:
            pitcherOpportunityFactors[_playerSlotIdentity(slot)] ?? 1.0,
      );
    }
    return projections;
  }

  Map<String, double> _kboTeamFormFactorsForTeamProfile(
    List<dynamic> rawMatches,
    int targetRound,
  ) {
    final byClub =
        <
          String,
          List<({DateTime date, double resultPoints, double runDiff})>
        >{};
    for (final raw in rawMatches) {
      final match = _fixtureAsMap(raw);
      final matchDate = DateTime.tryParse('${match['date'] ?? ''}');
      if (matchDate == null) continue;
      final round = _kboFantasyRoundForMatchDate(matchDate);
      if (round <= 0 || round >= targetRound) continue;
      if (!_kboMatchMapHasStarted(match)) continue;
      final homeClub = _normalizeKboDraftClub('${match['home'] ?? ''}');
      final awayClub = _normalizeKboDraftClub('${match['away'] ?? ''}');
      final homeScore = (_readNullableInt(match['homeScore']) ?? 0).toDouble();
      final awayScore = (_readNullableInt(match['awayScore']) ?? 0).toDouble();
      if (homeClub.isEmpty || awayClub.isEmpty) continue;
      final homePoints = homeScore > awayScore
          ? 1.0
          : homeScore == awayScore
          ? 0.5
          : 0.0;
      final awayPoints = awayScore > homeScore
          ? 1.0
          : homeScore == awayScore
          ? 0.5
          : 0.0;
      byClub.putIfAbsent(
        homeClub,
        () => <({DateTime date, double resultPoints, double runDiff})>[],
      )..add((
        date: matchDate,
        resultPoints: homePoints,
        runDiff: homeScore - awayScore,
      ));
      byClub.putIfAbsent(
        awayClub,
        () => <({DateTime date, double resultPoints, double runDiff})>[],
      )..add((
        date: matchDate,
        resultPoints: awayPoints,
        runDiff: awayScore - homeScore,
      ));
    }

    final factors = <String, double>{};
    byClub.forEach((club, entries) {
      entries.sort((a, b) => b.date.compareTo(a.date));
      final recent = entries.take(6).toList();
      if (recent.isEmpty) {
        factors[club] = 1.0;
        return;
      }
      final winRate =
          recent.fold<double>(0.0, (sum, item) => sum + item.resultPoints) /
          recent.length;
      final avgRunDiff =
          recent.fold<double>(0.0, (sum, item) => sum + item.runDiff) /
          recent.length;
      final runDiffBoost = (avgRunDiff / 6.0).clamp(-1.0, 1.0) * 0.07;
      factors[club] = (0.88 + winRate * 0.18 + runDiffBoost).clamp(0.84, 1.16);
    });
    return factors;
  }

  Map<String, double> _kboOpponentFormFactorsForTeamProfile(
    List<dynamic> rawMatches,
    int targetRound,
    Map<String, double> teamFormFactors,
  ) {
    final opponentsByClub = <String, Set<String>>{};
    for (final raw in rawMatches) {
      final match = _fixtureAsMap(raw);
      final matchDate = DateTime.tryParse('${match['date'] ?? ''}');
      if (matchDate == null) continue;
      final round = _kboFantasyRoundForMatchDate(matchDate);
      if (round != targetRound) continue;
      final homeClub = _normalizeKboDraftClub('${match['home'] ?? ''}');
      final awayClub = _normalizeKboDraftClub('${match['away'] ?? ''}');
      if (homeClub.isEmpty || awayClub.isEmpty) continue;
      opponentsByClub.putIfAbsent(homeClub, () => <String>{}).add(awayClub);
      opponentsByClub.putIfAbsent(awayClub, () => <String>{}).add(homeClub);
    }
    final factors = <String, double>{};
    opponentsByClub.forEach((club, opponents) {
      if (opponents.isEmpty) {
        factors[club] = 1.0;
        return;
      }
      final avgOpponentForm =
          opponents.fold<double>(
            0.0,
            (sum, opponent) => sum + (teamFormFactors[opponent] ?? 1.0),
          ) /
          opponents.length;
      factors[club] = (1.0 - (avgOpponentForm - 1.0) * 0.55).clamp(0.90, 1.10);
    });
    return factors;
  }

  double _projectKboFptsForTeamProfile(
    _PlayerSlot slot,
    List<_PlayerRoundPoints> roundPoints, {
    required int targetRound,
    required double teamFormFactor,
    required double opponentFormFactor,
    double pitcherOpportunityFactor = 1.0,
  }) {
    final previous =
        roundPoints.where((entry) => entry.round < targetRound).toList()
          ..sort((a, b) => b.round.compareTo(a.round));
    final fallback =
        _kLeagueAptsFromRoundPoints(previous) ??
        _cachedFullSeasonKboAptsForPlayer(
          playerName: slot.name,
          club: _normalizeKboDraftClub(slot.club),
          preferredNumber: slot.number,
          preferredPosition: slot.position,
        ) ??
        _fantasyProjectedSlotScore(slot, isSoccer: false);
    if (previous.isEmpty) {
      return (fallback * teamFormFactor * opponentFormFactor).clamp(0.0, 60.0);
    }

    final recent = previous.take(6).toList();
    const weights = <double>[0.30, 0.24, 0.18, 0.13, 0.09, 0.06];
    var weightedTotal = 0.0;
    var weightTotal = 0.0;
    for (var i = 0; i < recent.length; i++) {
      weightedTotal += recent[i].basePoints * weights[i];
      weightTotal += weights[i];
    }
    final weightedRecent = weightTotal > 0
        ? weightedTotal / weightTotal
        : fallback;
    final seasonApts = _kLeagueAptsFromRoundPoints(previous) ?? fallback;
    final recentTwo = recent.take(2).toList();
    final previousFour = recent.skip(2).take(4).toList();
    final recentTwoAvg = recentTwo.isEmpty
        ? weightedRecent
        : recentTwo.fold<double>(0.0, (sum, entry) => sum + entry.basePoints) /
              recentTwo.length;
    final previousFourAvg = previousFour.isEmpty
        ? weightedRecent
        : previousFour.fold<double>(
                0.0,
                (sum, entry) => sum + entry.basePoints,
              ) /
              previousFour.length;
    final trendBonus = (recentTwoAvg - previousFourAvg) * 0.22;
    final appearanceRate =
        recent.where((entry) => entry.appeared).length / recent.length;
    final startedRate =
        recent.where((entry) => entry.started).length / recent.length;
    final latestMissStreak = recent
        .takeWhile((entry) => !entry.appeared)
        .length;

    var projected = weightedRecent * 0.68 + seasonApts * 0.32 + trendBonus;
    projected *= teamFormFactor;
    projected *= opponentFormFactor;
    projected *= (0.65 + appearanceRate * 0.35);
    if (!_isKboPitcherSlot(slot)) {
      projected *= (0.78 + startedRate * 0.22);
    }
    if (latestMissStreak >= 3) {
      projected *= 0.48;
    } else if (latestMissStreak == 2) {
      projected *= 0.64;
    } else if (latestMissStreak == 1) {
      projected *= 0.84;
    }
    if (_isKboPitcherSlot(slot)) {
      projected *= pitcherOpportunityFactor.clamp(0.7, 1.45);
    }
    return projected.clamp(0.0, 60.0);
  }

  Future<void> _openPlayer(
    BuildContext context,
    _FantasyTeamPlayer player,
  ) async {
    final slot = player.toPlayerSlot();
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerProfilePage(
          name: slot.name,
          ownership: _ownership,
          metaOverride: _DocPlayerMeta(
            position: slot.position,
            club: slot.club,
            number: slot.number,
          ),
        ),
      ),
    );
  }

  Widget _benchCard(BuildContext context, _FantasyTeamPlayer player) {
    final palette = _leagueItSurfacePalette(context);
    final slot = player.toPlayerSlot();
    final projected = _projectedScoreForSlot(slot).toStringAsFixed(1);
    final actual = widget.draft.isSoccer ? null : _actualKboScoreForSlot(slot);
    final actualLabel = actual == null
        ? null
        : (() {
            final rounded = actual.toStringAsFixed(1);
            return rounded.endsWith('.0')
                ? rounded.substring(0, rounded.length - 2)
                : rounded;
          })();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          unawaited(_openPlayer(context, player));
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: palette.tileSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: palette.cardBorder),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      slot.name,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: palette.ink,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${slot.position} · ${_displayFantasyClubName(slot.club, isSoccer: widget.draft.isSoccer)} / $projected',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: palette.mutedInk,
                      ),
                    ),
                  ],
                ),
              ),
              if (actual != null) ...[
                const SizedBox(width: 10),
                Container(
                  width: 42,
                  height: 42,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE9F0FF),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    actualLabel!,
                    style: const TextStyle(
                      color: Color(0xFF2D6DFF),
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = _leagueItSurfacePalette(context);
    _FantasyStandingRow? standing;
    for (final row in _fantasyStandingRowsForDraft(widget.draft)) {
      if (row.team == widget.team.teamName) {
        standing = row;
        break;
      }
    }
    final teamRecord = standing == null
        ? '0승 0무 0패'
        : '${standing.wins}승 ${standing.ties}무 ${standing.losses}패';
    final startingSlots = widget.team.starting
        .map((player) => player.toPlayerSlot())
        .toList();
    final allSlots = [
      ...startingSlots,
      ...widget.team.bench.map((player) => player.toPlayerSlot()),
    ];
    final rosterByName = {
      for (final slot in allSlots) _playerSlotIdentity(slot): slot,
    };
    final displayRows = widget.draft.isSoccer
        ? _rowsFromSoccerStartingSlots(startingSlots).reversed.toList()
        : const <_Player>[];

    return _OverlayScaffold(
      isMyPageOpen: false,
      onToggleMyPage: () {},
      title: 'LeagueIt',
      showSearch: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: palette.fieldFill,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: palette.cardBorder),
              ),
              child: Column(
                children: [
                  _FantasyTeamAvatar(
                    uid: widget.team.uid,
                    teamName: widget.team.teamName,
                    size: 64,
                    iconSize: 28,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.team.teamName,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: palette.ink,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    teamRecord,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: palette.mutedInk,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: palette.fieldFill,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: palette.cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.draft.isSoccer ? 'Starting' : 'Roster',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: palette.ink,
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (widget.draft.isSoccer)
                    _FantasyRosterHalfPitch(
                      rows: displayRows,
                      rosterByName: rosterByName,
                      color: Colors.blueAccent,
                      goalkeeperRowOffset: 24,
                      captainPlayerId: widget.team.captainPlayerId,
                      viceCaptainPlayerId: widget.team.viceCaptainPlayerId,
                      captainName: widget.team.captainName,
                      viceCaptainName: widget.team.viceCaptainName,
                      scoreForSlot: _projectedScoreForSlot,
                      onSwap: null,
                      onTap: (slot) {
                        final player = widget.team.roster.firstWhere(
                          (candidate) =>
                              _playerSlotIdentity(candidate.toPlayerSlot()) ==
                              _playerSlotIdentity(slot),
                        );
                        unawaited(_openPlayer(context, player));
                      },
                    )
                  else
                    _FantasyBaseballRosterDiamond(
                      starting: startingSlots,
                      captainPlayerId: widget.team.captainPlayerId,
                      viceCaptainPlayerId: widget.team.viceCaptainPlayerId,
                      captainName: widget.team.captainName,
                      viceCaptainName: widget.team.viceCaptainName,
                      scoreForSlot: _projectedScoreForSlot,
                      actualScoreForSlot: _actualKboScoreForSlot,
                      onSwap: null,
                      onTap: (slot) {
                        final player = widget.team.roster.firstWhere(
                          (candidate) =>
                              _playerSlotIdentity(candidate.toPlayerSlot()) ==
                              _playerSlotIdentity(slot),
                        );
                        unawaited(_openPlayer(context, player));
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: palette.fieldFill,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: palette.cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.draft.isSoccer ? 'Bench' : '교체명단',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: palette.ink,
                    ),
                  ),
                  const SizedBox(height: 14),
                  ...widget.team.bench.map(
                    (player) => _benchCard(context, player),
                  ),
                ],
              ),
            ),
          ],
        ),
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

    final lineup = _MatchDetailPageState.getOrCreateSoccerFixtureLineup(
      fixture,
    );
    final isHome = fixture.home == widget.teamName;
    final rows = isHome ? lineup.home : lineup.away;
    final starting = rows.expand((r) => r.slots).toList();
    final bench = _MatchDetailPageState.getOrCreateTeamBench(
      teamName: widget.teamName,
      starting: starting,
    );
    final color = _teamColor(widget.teamName);

    // Display rows should be ordered from top(FW) -> bottom(GK) in a half pitch view.
    final displayRows =
        rows.isNotEmpty &&
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
                      metaOverride: _DocPlayerMeta(
                        position: slot.position,
                        club: slot.club,
                        number: slot.number,
                      ),
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
                      metaOverride: _DocPlayerMeta(
                        position: slot.position,
                        club: slot.club,
                        number: slot.number,
                      ),
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

int _fallbackKboProjectionSeedScore(_PlayerSlot slot) {
  final normalizedClub = _normalizeKboDraftClub(slot.club);
  final trimmedName = slot.name.trim();
  final trimmedPosition = slot.position.trim();
  final fallbackKey =
      normalizedClub.isNotEmpty &&
          trimmedName.isNotEmpty &&
          trimmedPosition.isNotEmpty &&
          slot.number > 0
      ? '$normalizedClub|$trimmedName|$trimmedPosition|${slot.number}'
      : normalizedClub.isNotEmpty &&
            trimmedName.isNotEmpty &&
            trimmedPosition.isNotEmpty
      ? '$normalizedClub|$trimmedName|$trimmedPosition'
      : _playerSlotIdentity(slot);
  return 5 + (_stableSeedFromKey(fallbackKey) % 6);
}

int _resolvedFantasyProjectionSeedScore(
  _PlayerSlot slot, {
  bool isSoccer = true,
}) {
  if (slot.score > 0) return slot.score;
  if (isSoccer) return slot.score;
  return _fallbackKboProjectionSeedScore(slot);
}

double _fantasyProjectedSlotScore(_PlayerSlot slot, {bool isSoccer = true}) {
  final seedScore = _resolvedFantasyProjectionSeedScore(
    slot,
    isSoccer: isSoccer,
  );
  return (isSoccer ? 1.8 : 3.6) * seedScore;
}

class _FantasyRosterHalfPitch extends StatelessWidget {
  const _FantasyRosterHalfPitch({
    super.key,
    required this.rows,
    required this.rosterByName,
    required this.color,
    required this.onSwap,
    required this.onTap,
    this.isLocked,
    this.scoreForSlot,
    this.showScoreLabel = true,
    this.goalCountForSlot,
    this.assistCountForSlot,
    this.captainPlayerId,
    this.viceCaptainPlayerId,
    this.captainName,
    this.viceCaptainName,
    this.onDragUpdate,
    this.onDragStarted,
    this.onDragEnded,
    this.goalkeeperRowOffset = 0,
  });

  final List<_Player> rows;
  final Map<String, _PlayerSlot> rosterByName;
  final Color color;
  final void Function(_PlayerSlot from, _PlayerSlot to)? onSwap;
  final void Function(_PlayerSlot) onTap;
  final bool Function(_PlayerSlot slot)? isLocked;
  final double Function(_PlayerSlot slot)? scoreForSlot;
  final bool showScoreLabel;
  final int Function(_PlayerSlot slot)? goalCountForSlot;
  final int Function(_PlayerSlot slot)? assistCountForSlot;
  final String? captainPlayerId;
  final String? viceCaptainPlayerId;
  final String? captainName;
  final String? viceCaptainName;
  final void Function(Offset globalPosition)? onDragUpdate;
  final void Function(_PlayerSlot slot)? onDragStarted;
  final void Function(_PlayerSlot slot)? onDragEnded;
  final double goalkeeperRowOffset;

  @override
  Widget build(BuildContext context) {
    const double margin = 12;
    const double padding = 18;
    final double usableHeight = max(
      320.0,
      (rows.length <= 1 ? 150.0 : 78.0 * (rows.length - 1) + 132.0),
    );
    final double fieldHeight = margin * 2 + usableHeight;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxCols = rows.fold<int>(
          1,
          (prev, row) => max(prev, row.slots.length),
        );
        final chipWidth = ((constraints.maxWidth - 20) / maxCols).clamp(
          56.0,
          82.0,
        );
        return SizedBox(
          height: fieldHeight,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(painter: _HalfPitchPainter()),
                ),
                ..._positionRowsHalfFantasyRoster(
                  rows: rows,
                  top: margin,
                  height: usableHeight,
                  padding: padding,
                  chipWidth: chipWidth,
                  goalkeeperRowOffset: goalkeeperRowOffset,
                  rosterByName: rosterByName,
                  color: color,
                  captainPlayerId: captainPlayerId,
                  viceCaptainPlayerId: viceCaptainPlayerId,
                  captainName: captainName,
                  viceCaptainName: viceCaptainName,
                  isLocked: isLocked,
                  scoreForSlot: scoreForSlot,
                  showScoreLabel: showScoreLabel,
                  goalCountForSlot: goalCountForSlot,
                  assistCountForSlot: assistCountForSlot,
                  onDragUpdate: onDragUpdate,
                  onDragStarted: onDragStarted,
                  onDragEnded: onDragEnded,
                  onSwap: onSwap,
                  onTap: onTap,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _BaseballFieldSlotSpec {
  final String label;
  final Alignment alignment;

  const _BaseballFieldSlotSpec({required this.label, required this.alignment});
}

class _BaseballFieldAssignment {
  final _BaseballFieldSlotSpec spec;
  final _PlayerSlot slot;

  const _BaseballFieldAssignment({required this.spec, required this.slot});
}

const List<_BaseballFieldSlotSpec> _baseballFieldLayout = [
  _BaseballFieldSlotSpec(label: 'LF', alignment: Alignment(-0.85, -0.75)),
  _BaseballFieldSlotSpec(label: 'CF', alignment: Alignment(0, -0.85)),
  _BaseballFieldSlotSpec(label: 'RF', alignment: Alignment(0.85, -0.75)),
  _BaseballFieldSlotSpec(label: '3B', alignment: Alignment(-0.80, 0.10)),
  _BaseballFieldSlotSpec(label: 'SS', alignment: Alignment(-0.35, -0.30)),
  _BaseballFieldSlotSpec(label: '2B', alignment: Alignment(0.35, -0.30)),
  _BaseballFieldSlotSpec(label: '1B', alignment: Alignment(0.80, 0.10)),
  _BaseballFieldSlotSpec(label: 'P', alignment: Alignment(0, 0.48)),
  _BaseballFieldSlotSpec(label: 'C', alignment: Alignment(0, 1.10)),
  _BaseballFieldSlotSpec(label: 'DH', alignment: Alignment(0.82, 0.86)),
];

List<_BaseballFieldAssignment> _buildBaseballFieldAssignments(
  List<_PlayerSlot> starting,
) {
  final remaining = List<_PlayerSlot>.from(starting);

  String normalizedPosition(String value) => value.trim().toUpperCase();

  String bucketForPosition(String value) {
    switch (normalizedPosition(value)) {
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
        return normalizedPosition(value);
    }
  }

  _PlayerSlot? takeSlot({required String label, String? fallbackBucket}) {
    final exactIndex = remaining.indexWhere(
      (slot) => normalizedPosition(slot.position) == label,
    );
    if (exactIndex >= 0) {
      return remaining.removeAt(exactIndex);
    }
    if (fallbackBucket == null) return null;
    final fallbackIndex = remaining.indexWhere(
      (slot) => bucketForPosition(slot.position) == fallbackBucket,
    );
    if (fallbackIndex >= 0) {
      return remaining.removeAt(fallbackIndex);
    }
    return null;
  }

  final byLabel = <String, _PlayerSlot>{
    if (takeSlot(label: 'LF', fallbackBucket: 'OF') case final slot?)
      'LF': slot,
    if (takeSlot(label: 'CF', fallbackBucket: 'OF') case final slot?)
      'CF': slot,
    if (takeSlot(label: 'RF', fallbackBucket: 'OF') case final slot?)
      'RF': slot,
    if (takeSlot(label: '3B', fallbackBucket: 'IF') case final slot?)
      '3B': slot,
    if (takeSlot(label: 'SS', fallbackBucket: 'IF') case final slot?)
      'SS': slot,
    if (takeSlot(label: '2B', fallbackBucket: 'IF') case final slot?)
      '2B': slot,
    if (takeSlot(label: '1B', fallbackBucket: 'IF') case final slot?)
      '1B': slot,
    if (takeSlot(label: 'P') case final slot?) 'P': slot,
    if (takeSlot(label: 'C') case final slot?) 'C': slot,
  };
  final usedIds = byLabel.values.map(_playerSlotIdentity).toSet();
  final dhCandidate =
      remaining.cast<_PlayerSlot?>().firstWhere(
        (slot) =>
            slot != null &&
            normalizedPosition(slot.position) == 'DH' &&
            !usedIds.contains(_playerSlotIdentity(slot)),
        orElse: () => null,
      ) ??
      remaining.cast<_PlayerSlot?>().firstWhere(
        (slot) =>
            slot != null &&
            bucketForPosition(slot.position) != 'P' &&
            !usedIds.contains(_playerSlotIdentity(slot)),
        orElse: () => null,
      );
  if (dhCandidate != null) {
    byLabel['DH'] = dhCandidate;
  }

  return _baseballFieldLayout
      .where((spec) => byLabel.containsKey(spec.label))
      .map(
        (spec) =>
            _BaseballFieldAssignment(spec: spec, slot: byLabel[spec.label]!),
      )
      .toList();
}

const List<String> _baseballMatchupPositionRowOrder = <String>[
  'P',
  'C',
  '1B',
  '2B',
  '3B',
  'SS',
  'LF',
  'CF',
  'RF',
  'DH',
];

Map<String, _FantasyTeamPlayer> _buildBaseballFieldPlayerMap(
  List<_FantasyTeamPlayer> players,
) {
  final assignments = _buildBaseballFieldAssignments(
    players.map((player) => player.toPlayerSlot()).toList(),
  );
  final mapped = <String, _FantasyTeamPlayer>{};
  for (final assignment in assignments) {
    final slotId = _playerSlotIdentity(assignment.slot);
    final player = players.cast<_FantasyTeamPlayer?>().firstWhere(
      (item) => item != null && _fantasyTeamPlayerIdentity(item) == slotId,
      orElse: () => null,
    );
    if (player != null) {
      mapped[assignment.spec.label] = player;
    }
  }
  return mapped;
}

class _FantasyBaseballRosterDiamond extends StatelessWidget {
  const _FantasyBaseballRosterDiamond({
    super.key,
    required this.starting,
    required this.onSwap,
    required this.onTap,
    this.isLocked,
    this.scoreForSlot,
    this.actualScoreForSlot,
    this.captainPlayerId,
    this.viceCaptainPlayerId,
    this.captainName,
    this.viceCaptainName,
    this.onDragUpdate,
    this.onDragStarted,
    this.onDragEnded,
    this.showScoreValue = true,
    this.showProjectedLabel = true,
  });

  final List<_PlayerSlot> starting;
  final void Function(_PlayerSlot from, _PlayerSlot to)? onSwap;
  final void Function(_PlayerSlot) onTap;
  final bool Function(_PlayerSlot slot)? isLocked;
  final double Function(_PlayerSlot slot)? scoreForSlot;
  final double Function(_PlayerSlot slot)? actualScoreForSlot;
  final String? captainPlayerId;
  final String? viceCaptainPlayerId;
  final String? captainName;
  final String? viceCaptainName;
  final void Function(Offset globalPosition)? onDragUpdate;
  final void Function(_PlayerSlot slot)? onDragStarted;
  final void Function(_PlayerSlot slot)? onDragEnded;
  final bool showScoreValue;
  final bool showProjectedLabel;

  @override
  Widget build(BuildContext context) {
    final assignments = _buildBaseballFieldAssignments(starting);
    return LayoutBuilder(
      builder: (context, constraints) {
        final fieldHeight = (constraints.maxWidth * 0.98)
            .clamp(320.0, 430.0)
            .toDouble();
        final height = (constraints.maxWidth * 1.08)
            .clamp(348.0, 470.0)
            .toDouble();
        final chipSize = (constraints.maxWidth * 0.125)
            .clamp(40.0, 52.0)
            .toDouble();
        final labelWidth = (constraints.maxWidth * 0.22)
            .clamp(72.0, 96.0)
            .toDouble();
        return SizedBox(
          height: height,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(painter: _BaseballDiamondPainter()),
                ),
                Positioned(
                  left: 0,
                  top: 0,
                  right: 0,
                  height: fieldHeight,
                  child: Stack(
                    children: [
                      for (final assignment in assignments)
                        Positioned.fill(
                          child: Align(
                            alignment: assignment.spec.alignment,
                            child: _FantasyBaseballFieldChip(
                              key: ValueKey(
                                'kbo-field-${_playerSlotIdentity(assignment.slot)}',
                              ),
                              slot: assignment.slot,
                              size: chipSize,
                              labelWidth: labelWidth,
                              onSwap: onSwap,
                              onTap: onTap,
                              isLocked:
                                  isLocked?.call(assignment.slot) ?? false,
                              scoreForSlot: scoreForSlot,
                              actualScoreForSlot: actualScoreForSlot,
                              isCaptain:
                                  (captainPlayerId?.isNotEmpty == true &&
                                      _playerSlotIdentity(assignment.slot) ==
                                          captainPlayerId) ||
                                  (captainPlayerId == null &&
                                      assignment.slot.name == captainName),
                              isViceCaptain:
                                  (viceCaptainPlayerId?.isNotEmpty == true &&
                                      _playerSlotIdentity(assignment.slot) ==
                                          viceCaptainPlayerId) ||
                                  (viceCaptainPlayerId == null &&
                                      assignment.slot.name == viceCaptainName),
                              onDragUpdate: onDragUpdate,
                              onDragStarted: onDragStarted,
                              onDragEnded: onDragEnded,
                              showScoreValue: showScoreValue,
                              showProjectedLabel: showProjectedLabel,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _FantasyBaseballFieldChip extends StatelessWidget {
  const _FantasyBaseballFieldChip({
    super.key,
    required this.slot,
    required this.size,
    required this.labelWidth,
    required this.onSwap,
    required this.onTap,
    this.isLocked = false,
    this.scoreForSlot,
    this.actualScoreForSlot,
    this.isCaptain = false,
    this.isViceCaptain = false,
    this.onDragUpdate,
    this.onDragStarted,
    this.onDragEnded,
    this.showScoreValue = true,
    this.showProjectedLabel = true,
  });

  final _PlayerSlot slot;
  final double size;
  final double labelWidth;
  final void Function(_PlayerSlot from, _PlayerSlot to)? onSwap;
  final void Function(_PlayerSlot) onTap;
  final bool isLocked;
  final double Function(_PlayerSlot slot)? scoreForSlot;
  final double Function(_PlayerSlot slot)? actualScoreForSlot;
  final bool isCaptain;
  final bool isViceCaptain;
  final void Function(Offset globalPosition)? onDragUpdate;
  final void Function(_PlayerSlot slot)? onDragStarted;
  final void Function(_PlayerSlot slot)? onDragEnded;
  final bool showScoreValue;
  final bool showProjectedLabel;

  @override
  Widget build(BuildContext context) {
    final palette = _leagueItSurfacePalette(context);
    return DragTarget<_PlayerSlot>(
      onWillAcceptWithDetails: (details) =>
          !isLocked &&
          _playerSlotIdentity(details.data) != _playerSlotIdentity(slot),
      onAcceptWithDetails: (details) {
        if (isLocked) return;
        onSwap?.call(details.data, slot);
      },
      builder: (context, candidate, rejected) {
        if (isLocked) {
          return _nodeBody(palette);
        }
        return LongPressDraggable<_PlayerSlot>(
          key: ValueKey('drag-${_playerSlotIdentity(slot)}'),
          data: slot,
          rootOverlay: true,
          feedback: _ghostNode(palette),
          onDragStarted: () => onDragStarted?.call(slot),
          onDragCompleted: () => onDragEnded?.call(slot),
          onDraggableCanceled: (_, __) => onDragEnded?.call(slot),
          onDragEnd: (_) => onDragEnded?.call(slot),
          onDragUpdate: (details) => onDragUpdate?.call(details.globalPosition),
          childWhenDragging: Opacity(opacity: 0.35, child: _nodeBody(palette)),
          child: _nodeBody(palette, highlight: candidate.isNotEmpty),
        );
      },
    );
  }

  Widget _nodeBody(_LeagueItSurfacePalette palette, {bool highlight = false}) {
    final projected =
        scoreForSlot?.call(slot) ??
        _fantasyProjectedSlotScore(slot, isSoccer: false);
    final actual = actualScoreForSlot?.call(slot) ?? projected;
    final accent = isLocked ? const Color(0xFF98A2B3) : const Color(0xFF173F8A);
    final scoreTextColor = palette.isDark
        ? palette.ink
        : const Color(0xFF111111);
    final labelColor = palette.isDark ? palette.ink : const Color(0xFF111111);
    final fillColor = isLocked
        ? (palette.isDark ? const Color(0xFF2A3238) : const Color(0xFFF2F4F7))
        : (palette.isDark
              ? const Color(0xFF1C2227)
              : Colors.white.withValues(alpha: 0.14));
    final badgeFontSize = (size * 0.16).clamp(9.0, 11.0);
    final scoreLabel = projected.toStringAsFixed(1);
    return SizedBox(
      width: labelWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => onTap(slot),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: highlight
                          ? (palette.isDark
                                ? const Color(0xFF27456E)
                                : const Color(0xFFE4EEFF))
                          : fillColor,
                      border: Border.all(color: accent, width: 1.8),
                    ),
                    alignment: Alignment.center,
                    child: showScoreValue
                        ? Text(
                            actual.toStringAsFixed(1),
                            style: TextStyle(
                              color: scoreTextColor,
                              fontSize: size * 0.30,
                              fontWeight: FontWeight.w700,
                            ),
                          )
                        : Icon(Icons.person, size: size * 0.42, color: accent),
                  ),
                  if (isCaptain || isViceCaptain)
                    Positioned(
                      top: -4,
                      right: -4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: isCaptain
                              ? const Color(0xFFFFCF4D)
                              : (palette.isDark
                                    ? palette.tileSurface
                                    : Colors.white),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: isViceCaptain
                                ? const Color(0xFF7EA9FF)
                                : const Color(0xFFE0B331),
                          ),
                        ),
                        child: Text(
                          isCaptain ? 'C' : 'VC',
                          style: TextStyle(
                            fontSize: badgeFontSize,
                            fontWeight: FontWeight.w900,
                            color: isCaptain
                                ? const Color(0xFF1F1F1F)
                                : const Color(0xFF4672E8),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 5),
          if (showScoreValue) ...[
            Text(
              slot.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: labelColor,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                height: 1.05,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              showProjectedLabel ? scoreLabel : '계산 중...',
              maxLines: 1,
              overflow: TextOverflow.visible,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: labelColor,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                height: 1.0,
              ),
            ),
          ] else
            Text(
              slot.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: labelColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }

  Widget _ghostNode(_LeagueItSurfacePalette palette) {
    return Material(
      color: Colors.transparent,
      child: Opacity(opacity: 0.95, child: _nodeBody(palette)),
    );
  }
}

class _BaseballDiamondPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final background = Paint()..color = const Color(0xFF39A51C);
    canvas.drawRect(rect, background);

    final fieldHeight = (size.width * 0.98).clamp(320.0, 430.0).toDouble();

    final home = Offset(size.width * 0.5, fieldHeight * 0.90);
    final first = Offset(size.width * 0.82, fieldHeight * 0.64);
    final second = Offset(size.width * 0.5, fieldHeight * 0.40);
    final third = Offset(size.width * 0.18, fieldHeight * 0.64);
    final leftCorner = Offset(-size.width * 0.18, fieldHeight * 0.35);
    final rightCorner = Offset(size.width * 1.18, fieldHeight * 0.35);

    Offset pointOnFoulLine(Offset corner, double y) {
      final t = (home.dy - y) / (home.dy - corner.dy);
      return Offset(home.dx + (corner.dx - home.dx) * t, y);
    }

    final dirtEdgeY = fieldHeight * 0.58;
    final dirtFirst = pointOnFoulLine(rightCorner, dirtEdgeY);
    final dirtThird = pointOnFoulLine(leftCorner, dirtEdgeY);

    final dirtPaint = Paint()..color = const Color(0xFFD2954B);
    final dirtCurvePeak = Offset(size.width * 0.5, fieldHeight * 0.08);
    final homeDirtRadius = size.width * 0.060;
    final homeDirtY = fieldHeight * 0.81;
    final homeDirtLeft = pointOnFoulLine(leftCorner, homeDirtY);
    final homeDirtRight = pointOnFoulLine(rightCorner, homeDirtY);
    final dirtPath = Path()
      ..moveTo(homeDirtLeft.dx, homeDirtLeft.dy)
      ..lineTo(dirtThird.dx, dirtThird.dy)
      ..quadraticBezierTo(
        dirtCurvePeak.dx,
        dirtCurvePeak.dy,
        dirtFirst.dx,
        dirtFirst.dy,
      )
      ..lineTo(homeDirtRight.dx, homeDirtRight.dy)
      ..close();
    canvas.drawPath(dirtPath, dirtPaint);

    final bridgeY = home.dy - homeDirtRadius * 0.62;
    final bridgeLeft = pointOnFoulLine(leftCorner, bridgeY);
    final bridgeRight = pointOnFoulLine(rightCorner, bridgeY);
    final bridgePath = Path()
      ..moveTo(homeDirtLeft.dx, homeDirtLeft.dy)
      ..lineTo(bridgeLeft.dx, bridgeLeft.dy)
      ..lineTo(bridgeRight.dx, bridgeRight.dy)
      ..lineTo(homeDirtRight.dx, homeDirtRight.dy)
      ..close();
    canvas.drawPath(bridgePath, dirtPaint);

    final infieldGrassPaint = Paint()..color = const Color(0xFF36A116);
    final innerHomeLeft = Offset(size.width * 0.44, fieldHeight * 0.80);
    final innerHomeRight = Offset(size.width * 0.56, fieldHeight * 0.80);
    final innerLaneY = fieldHeight * 0.66;
    final innerFirstT = (innerLaneY - innerHomeRight.dy) / (first.dy - home.dy);
    final innerThirdT = (innerLaneY - innerHomeLeft.dy) / (third.dy - home.dy);
    final innerFirst = Offset(
      innerHomeRight.dx + (first.dx - home.dx) * innerFirstT,
      innerLaneY,
    );
    final innerSecond = Offset(size.width * 0.5, fieldHeight * 0.49);
    final innerThird = Offset(
      innerHomeLeft.dx + (third.dx - home.dx) * innerThirdT,
      innerLaneY,
    );
    canvas.drawPath(
      Path()
        ..moveTo(innerHomeLeft.dx, innerHomeLeft.dy)
        ..lineTo(innerThird.dx, innerThird.dy)
        ..lineTo(innerSecond.dx, innerSecond.dy)
        ..lineTo(innerFirst.dx, innerFirst.dy)
        ..lineTo(innerHomeRight.dx, innerHomeRight.dy)
        ..close(),
      infieldGrassPaint,
    );

    final moundPaint = Paint()..color = const Color(0xFFD2954B);
    canvas.drawCircle(
      Offset(size.width * 0.5, fieldHeight * 0.66),
      size.width * 0.042,
      moundPaint,
    );
    final homeDirtPaint = Paint()..color = const Color(0xFFD2954B);
    canvas.drawCircle(
      Offset(size.width * 0.5, fieldHeight * 0.90),
      homeDirtRadius,
      homeDirtPaint,
    );

    final linePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(home, leftCorner, linePaint);
    canvas.drawLine(home, rightCorner, linePaint);

    _drawBase(canvas, third, size.width * 0.020);
    _drawBase(canvas, second, size.width * 0.020);
    _drawBase(canvas, first, size.width * 0.020);
    _drawHomePlate(canvas, home, size.width * 0.022);
  }

  void _drawBase(Canvas canvas, Offset center, double radius) {
    final paint = Paint()..color = Colors.white;
    final path = Path()
      ..moveTo(center.dx, center.dy - radius)
      ..lineTo(center.dx + radius, center.dy)
      ..lineTo(center.dx, center.dy + radius)
      ..lineTo(center.dx - radius, center.dy)
      ..close();
    canvas.drawPath(path, paint);
  }

  void _drawHomePlate(Canvas canvas, Offset center, double radius) {
    final paint = Paint()..color = Colors.white;
    final path = Path()
      ..moveTo(center.dx - radius, center.dy)
      ..lineTo(center.dx - radius, center.dy + radius * 0.9)
      ..lineTo(center.dx, center.dy + radius * 1.4)
      ..lineTo(center.dx + radius, center.dy + radius * 0.9)
      ..lineTo(center.dx + radius, center.dy)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

List<Widget> _positionRowsHalfFantasyRoster({
  required List<_Player> rows,
  required double top,
  required double height,
  required double padding,
  required double chipWidth,
  required double goalkeeperRowOffset,
  required Map<String, _PlayerSlot> rosterByName,
  required Color color,
  required String? captainPlayerId,
  required String? viceCaptainPlayerId,
  required String? captainName,
  required String? viceCaptainName,
  required bool Function(_PlayerSlot slot)? isLocked,
  required double Function(_PlayerSlot slot)? scoreForSlot,
  required bool showScoreLabel,
  required int Function(_PlayerSlot slot)? goalCountForSlot,
  required int Function(_PlayerSlot slot)? assistCountForSlot,
  required void Function(Offset globalPosition)? onDragUpdate,
  required void Function(_PlayerSlot slot)? onDragStarted,
  required void Function(_PlayerSlot slot)? onDragEnded,
  required void Function(_PlayerSlot from, _PlayerSlot to)? onSwap,
  required void Function(_PlayerSlot) onTap,
}) {
  final double usable = max(40, height - padding * 2);
  final double spacing = rows.length > 1 ? usable / rows.length : usable / 2;
  final double start = padding.clamp(0, height - padding - usable);
  return [
    for (int i = 0; i < rows.length; i++)
      Positioned(
        top:
            top +
            start +
            spacing * i +
            (rows[i].slots.length == 1 && rows[i].slots.first.position == 'GK'
                ? goalkeeperRowOffset
                : 0),
        left: 0,
        right: 0,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: rows[i].slots.map((s) {
              final slot = rosterByName[_playerSlotIdentity(s)] ?? s;
              return _FantasyRosterChip(
                key: ValueKey('soccer-pitch-${_playerSlotIdentity(slot)}'),
                slot: slot,
                width: chipWidth,
                color: color,
                isLocked: isLocked?.call(slot) ?? false,
                isCaptain:
                    (captainPlayerId?.isNotEmpty == true &&
                        _playerSlotIdentity(slot) == captainPlayerId) ||
                    (captainPlayerId == null && slot.name == captainName),
                isViceCaptain:
                    (viceCaptainPlayerId?.isNotEmpty == true &&
                        _playerSlotIdentity(slot) == viceCaptainPlayerId) ||
                    (viceCaptainPlayerId == null &&
                        slot.name == viceCaptainName),
                scoreForSlot: scoreForSlot,
                showScoreLabel: showScoreLabel,
                goalCountForSlot: goalCountForSlot,
                assistCountForSlot: assistCountForSlot,
                onDragUpdate: onDragUpdate,
                onDragStarted: onDragStarted,
                onDragEnded: onDragEnded,
                onSwap: onSwap,
                onTap: onTap,
              );
            }).toList(),
          ),
        ),
      ),
  ];
}

class _FantasyRosterChip extends StatelessWidget {
  const _FantasyRosterChip({
    super.key,
    required this.slot,
    required this.width,
    required this.color,
    required this.onSwap,
    required this.onTap,
    this.isLocked = false,
    this.scoreForSlot,
    this.showScoreLabel = true,
    this.goalCountForSlot,
    this.assistCountForSlot,
    this.isCaptain = false,
    this.isViceCaptain = false,
    this.onDragUpdate,
    this.onDragStarted,
    this.onDragEnded,
  });

  final _PlayerSlot slot;
  final double width;
  final Color color;
  final void Function(_PlayerSlot from, _PlayerSlot to)? onSwap;
  final void Function(_PlayerSlot) onTap;
  final bool isLocked;
  final double Function(_PlayerSlot slot)? scoreForSlot;
  final bool showScoreLabel;
  final int Function(_PlayerSlot slot)? goalCountForSlot;
  final int Function(_PlayerSlot slot)? assistCountForSlot;
  final bool isCaptain;
  final bool isViceCaptain;
  final void Function(Offset globalPosition)? onDragUpdate;
  final void Function(_PlayerSlot slot)? onDragStarted;
  final void Function(_PlayerSlot slot)? onDragEnded;

  @override
  Widget build(BuildContext context) {
    final palette = _leagueItSurfacePalette(context);
    return DragTarget<_PlayerSlot>(
      onWillAcceptWithDetails: (details) =>
          !isLocked &&
          _playerSlotIdentity(details.data) != _playerSlotIdentity(slot),
      onAcceptWithDetails: (details) {
        if (isLocked) return;
        onSwap?.call(details.data, slot);
      },
      builder: (context, candidate, rejected) {
        final highlight = !isLocked && candidate.isNotEmpty;
        if (isLocked) {
          return _chipBody(context, palette, highlight: highlight);
        }
        return LongPressDraggable<_PlayerSlot>(
          key: ValueKey('drag-${_playerSlotIdentity(slot)}'),
          data: slot,
          rootOverlay: true,
          feedback: _chipBody(context, palette, highlight: true, isGhost: true),
          onDragStarted: () => onDragStarted?.call(slot),
          onDragCompleted: () => onDragEnded?.call(slot),
          onDraggableCanceled: (_, __) => onDragEnded?.call(slot),
          onDragEnd: (_) => onDragEnded?.call(slot),
          onDragUpdate: (details) => onDragUpdate?.call(details.globalPosition),
          childWhenDragging: Opacity(
            opacity: 0.35,
            child: _chipBody(context, palette, highlight: false),
          ),
          child: _chipBody(context, palette, highlight: highlight),
        );
      },
    );
  }

  Widget _chipBody(
    BuildContext context,
    _LeagueItSurfacePalette palette, {
    required bool highlight,
    bool isGhost = false,
  }) {
    final circleSize = (width * 0.62).clamp(40.0, 58.0);
    final iconSize = (circleSize * 0.42).clamp(16.0, 24.0);
    final badgeFontSize = width <= 62 ? 9.0 : 10.0;
    final textFontSize = width <= 62 ? 8.5 : 10.0;
    final goalCount = goalCountForSlot?.call(slot) ?? 0;
    final assistCount = assistCountForSlot?.call(slot) ?? 0;
    final scoreLabel = showScoreLabel
        ? (scoreForSlot?.call(slot) ?? _fantasyProjectedSlotScore(slot))
              .toStringAsFixed(1)
        : null;
    final body = GestureDetector(
      onTap: () => onTap(slot),
      child: SizedBox(
        width: width,
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: circleSize,
                  height: circleSize,
                  decoration: BoxDecoration(
                    color: palette.isDark
                        ? (highlight
                              ? const Color(0xFF183A27)
                              : const Color(0xFF1B2328))
                        : (highlight ? Colors.green : color).withOpacity(0.08),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: highlight ? Colors.green : color,
                      width: highlight ? 2.2 : 1.8,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.person,
                      size: iconSize,
                      color: highlight ? Colors.green : color,
                    ),
                  ),
                ),
                if (goalCount > 0)
                  Positioned(
                    top: -5,
                    left: isLocked ? 14 : -10,
                    child: _FantasyRosterEventBadge(
                      background: palette.isDark
                          ? palette.tileSurface
                          : Colors.white,
                      foreground: const Color(0xFF111827),
                      icon: Icons.sports_soccer,
                      count: goalCount > 1 ? goalCount : null,
                    ),
                  ),
                if (assistCount > 0)
                  Positioned(
                    top: -5,
                    right: isCaptain || isViceCaptain ? 24 : -8,
                    child: _FantasyRosterEventBadge(
                      background: palette.isDark
                          ? palette.tileSurface
                          : Colors.white,
                      foreground: const Color(0xFFDC2626),
                      label: 'A',
                      count: assistCount > 1 ? assistCount : null,
                    ),
                  ),
                if (isCaptain || isViceCaptain)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: isCaptain
                            ? const Color(0xFFFFCF4D)
                            : (palette.isDark
                                  ? palette.tileSurface
                                  : Colors.white),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: isViceCaptain
                              ? const Color(0xFF7EA9FF)
                              : const Color(0xFFE0B331),
                        ),
                      ),
                      child: Text(
                        isCaptain ? 'C' : 'VC',
                        style: TextStyle(
                          fontSize: badgeFontSize,
                          fontWeight: FontWeight.w900,
                          color: isCaptain
                              ? const Color(0xFF1F1F1F)
                              : const Color(0xFF4672E8),
                        ),
                      ),
                    ),
                  ),
                if (isLocked)
                  Positioned(
                    left: -2,
                    top: -2,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: palette.isDark
                            ? palette.tileSurface
                            : Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: palette.cardBorder),
                      ),
                      child: Icon(
                        Icons.lock_rounded,
                        size: 13,
                        color: palette.mutedInk,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: width,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  scoreLabel == null ? slot.name : '${slot.name} / $scoreLabel',
                  style: TextStyle(
                    color: palette.isDark ? palette.ink : Colors.white,
                    fontSize: textFontSize,
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (!isGhost) return body;
    return Material(
      color: Colors.transparent,
      child: Opacity(opacity: 0.92, child: body),
    );
  }
}

class _FantasyRosterEventBadge extends StatelessWidget {
  const _FantasyRosterEventBadge({
    required this.background,
    required this.foreground,
    this.icon,
    this.label,
    this.count,
  });

  final Color background;
  final Color foreground;
  final IconData? icon;
  final String? label;
  final int? count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 20),
      padding: EdgeInsets.symmetric(horizontal: count == null ? 6 : 7),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (label != null)
            Text(
              label!,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w900,
                height: 1,
                color: foreground,
              ),
            )
          else if (icon != null)
            Icon(icon, size: 11, color: foreground),
          if (count != null) ...[
            const SizedBox(width: 2),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                height: 1,
                color: foreground,
              ),
            ),
          ],
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
    this.isLocked = false,
  });

  final _PlayerSlot slot;
  final Color color;
  final void Function(_PlayerSlot from, _PlayerSlot to)? onSwap;
  final void Function(_PlayerSlot) onTap;
  final bool isLocked;

  @override
  Widget build(BuildContext context) {
    return DragTarget<_PlayerSlot>(
      onWillAcceptWithDetails: (details) => !isLocked && details.data != slot,
      onAcceptWithDetails: (details) {
        if (isLocked) return;
        onSwap?.call(details.data, slot);
      },
      builder: (context, candidate, rejected) {
        final highlight = !isLocked && candidate.isNotEmpty;
        if (isLocked) {
          return _chipBody(context, highlight: false);
        }
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

  Widget _chipBody(
    BuildContext context, {
    required bool highlight,
    bool isGhost = false,
  }) {
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
          if (isLocked)
            Container(
              margin: const EdgeInsets.only(top: 4),
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFD0D5DD)),
              ),
              child: const Icon(
                Icons.lock_rounded,
                size: 12,
                color: Color(0xFF667085),
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
                      horizontal: 12,
                      vertical: 10,
                    ),
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
    final palette = _leagueItSurfacePalette(context);
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
            final own =
                _MatchDetailPageState._playerOwnerCache[p.name] ??
                PlayerOwnership.freeAgent;
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PlayerProfilePage(
                  name: p.name,
                  ownership: own,
                  metaOverride: _DocPlayerMeta(
                    position: p.position,
                    club: p.club,
                    number: p.number,
                  ),
                ),
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
                  color: palette.isDark
                      ? const Color(0xFF263038)
                      : Colors.blueGrey.shade100,
                  border: Border.all(
                    color: palette.isDark
                        ? const Color(0xFF41515E)
                        : Colors.black26,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    '${podiumIdx + 1}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                      color: palette.ink,
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
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: palette.ink,
                  ),
                ),
              ),
              Text(
                '${p.score} pts',
                style: TextStyle(fontSize: 12, color: palette.mutedInk),
              ),
            ],
          ),
        );
      }

      return Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: palette.fieldFill,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: palette.cardBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: palette.isDark ? 0.22 : 0.08,
              ),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Top 3',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: palette.ink,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(displayCount, (displayIdx) {
                final podiumIdx = displayCount == 3
                    ? displayOrder[displayIdx]
                    : displayIdx;
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
              color: palette.fieldFill,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: palette.cardBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: palette.isDark ? 0.22 : 0.08,
                  ),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ListTile(
              leading: CircleAvatar(
                radius: 18,
                backgroundColor: palette.tileSurface,
                child: Text(
                  '$rank',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: palette.ink,
                  ),
                ),
              ),
              title: Text(
                p.name,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: palette.ink,
                ),
              ),
              subtitle: Text(
                '${p.position} · ${p.score} pts',
                style: TextStyle(color: palette.mutedInk),
              ),
              trailing: const Icon(Icons.chevron_right, size: 18),
              onTap: () {
                final own =
                    _MatchDetailPageState._playerOwnerCache[p.name] ??
                    PlayerOwnership.freeAgent;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PlayerProfilePage(
                      name: p.name,
                      ownership: own,
                      metaOverride: _DocPlayerMeta(
                        position: p.position,
                        club: p.club,
                        number: p.number,
                      ),
                    ),
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

class _FantasyWeeklyLeaderEntry {
  const _FantasyWeeklyLeaderEntry({
    required this.name,
    required this.position,
    required this.club,
    required this.number,
    required this.points,
    required this.ownership,
  });

  final String name;
  final String position;
  final String club;
  final int number;
  final double points;
  final PlayerOwnership ownership;
}

class _FantasyWeeklyLeaderSection {
  const _FantasyWeeklyLeaderSection({
    required this.round,
    required this.leaders,
  });

  final int round;
  final List<_FantasyWeeklyLeaderEntry> leaders;
}

class _FantasyWeeklyLeadersPage extends StatefulWidget {
  const _FantasyWeeklyLeadersPage({
    required this.sections,
    required this.currentRound,
    required this.isSoccer,
    this.refreshSections,
    this.preferFreshSections = false,
  });

  final List<_FantasyWeeklyLeaderSection> sections;
  final int currentRound;
  final bool isSoccer;
  final Future<List<_FantasyWeeklyLeaderSection>> Function()? refreshSections;
  final bool preferFreshSections;

  @override
  State<_FantasyWeeklyLeadersPage> createState() =>
      _FantasyWeeklyLeadersPageState();
}

class _FantasyWeeklyLeadersPageState extends State<_FantasyWeeklyLeadersPage> {
  bool _isMyPageOpen = false;
  bool _isRefreshingSections = false;
  late List<_FantasyWeeklyLeaderSection> _sections;
  late int _currentRound;

  @override
  void initState() {
    super.initState();
    _sections = widget.preferFreshSections ? const [] : widget.sections;
    _currentRound = widget.currentRound;
    unawaited(_refreshSections());
  }

  void _toggleMyPage() => setState(() => _isMyPageOpen = !_isMyPageOpen);

  Future<void> _refreshSections() async {
    final refresh = widget.refreshSections;
    if (refresh == null) return;
    setState(() {
      _isRefreshingSections = true;
    });
    try {
      final refreshed = await refresh();
      if (!mounted || refreshed.isEmpty) return;
      setState(() {
        _sections = refreshed;
        _currentRound = refreshed.first.round;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshingSections = false;
        });
      }
    }
  }

  void _openPlayer(_FantasyWeeklyLeaderEntry player) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerProfilePage(
          name: player.name,
          ownership: player.ownership,
          metaOverride: _DocPlayerMeta(
            position: player.position,
            club: player.club,
            number: player.number,
          ),
        ),
      ),
    );
  }

  Widget _buildPodium(List<_FantasyWeeklyLeaderEntry> leaders) {
    final palette = _leagueItSurfacePalette(context);
    if (leaders.isEmpty) return const SizedBox.shrink();
    const slotHeights = [130.0, 156.0, 116.0];
    const displayOrder = [1, 0, 2];
    final displayCount = min(3, leaders.length);

    Widget podiumCard(
      int rankIndex,
      int displayIndex,
      _FantasyWeeklyLeaderEntry player,
    ) {
      return InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openPlayer(player),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Container(
              width: 86,
              height: slotHeights[displayIndex],
              decoration: BoxDecoration(
                color: palette.isDark
                    ? const Color(0xFF263038)
                    : const Color(0xFFD4DEE7),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: palette.isDark
                      ? const Color(0xFF41515E)
                      : const Color(0xFFAFBCC7),
                ),
              ),
              child: Center(
                child: Text(
                  '${rankIndex + 1}',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: palette.ink,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: 94,
              child: Text(
                player.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: palette.ink,
                ),
              ),
            ),
            const SizedBox(height: 2),
            SizedBox(
              width: 94,
              child: Text(
                _displayFantasyClubName(player.club, isSoccer: widget.isSoccer),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: palette.mutedInk,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${player.position} · ${player.points.toStringAsFixed(1)}P',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: palette.mutedInk,
              ),
            ),
          ],
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(displayCount, (displayIndex) {
        final leaderIndex = displayCount == 3
            ? displayOrder[displayIndex]
            : displayIndex;
        return podiumCard(leaderIndex, displayIndex, leaders[leaderIndex]);
      }),
    );
  }

  Widget _buildCurrentRoundSection(_FantasyWeeklyLeaderSection section) {
    final palette = _leagueItSurfacePalette(context);
    final visibleLeaders = section.leaders.take(30).toList();
    final podium = visibleLeaders.take(3).toList();
    final rest = visibleLeaders.length > 3
        ? visibleLeaders.sublist(3)
        : const <_FantasyWeeklyLeaderEntry>[];
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: palette.fieldFill,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: palette.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: palette.isDark ? 0.22 : 0.07),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Round ${section.round}',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: palette.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '해당 라운드 최고 Fpts 선수 30명입니다.',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: palette.mutedInk,
            ),
          ),
          const SizedBox(height: 18),
          if (visibleLeaders.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                '이 라운드 집계가 아직 시작되지 않았습니다.',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: palette.mutedInk,
                ),
              ),
            )
          else
            _buildPodium(podium),
          if (rest.isNotEmpty) ...[
            const SizedBox(height: 18),
            ...List.generate(rest.length, (index) {
              final player = rest[index];
              final rank = index + 4;
              return Padding(
                padding: EdgeInsets.only(
                  bottom: index == rest.length - 1 ? 0 : 10,
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _openPlayer(player),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: palette.tileSurface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: palette.cardBorder),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: palette.isDark
                                ? const Color(0xFF20272D)
                                : const Color(0xFFE9EEF5),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '$rank',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: palette.ink,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                player.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: palette.ink,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${player.position} · ${_displayFantasyClubName(player.club, isSoccer: widget.isSoccer)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: palette.mutedInk,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '${player.points.toStringAsFixed(1)}P',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: palette.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildPastRoundSection(_FantasyWeeklyLeaderSection section) {
    final palette = _leagueItSurfacePalette(context);
    final leaders = section.leaders.take(3).toList();
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: palette.fieldFill,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Round ${section.round}',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: palette.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '해당 라운드 Top 3 선수입니다.',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: palette.mutedInk,
            ),
          ),
          const SizedBox(height: 18),
          _buildPodium(leaders),
        ],
      ),
    );
  }

  Widget _buildLoadingSection() {
    final palette = _leagueItSurfacePalette(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 28),
      decoration: BoxDecoration(
        color: palette.fieldFill,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: palette.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: palette.isDark ? 0.22 : 0.07),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2.6),
          ),
          const SizedBox(height: 14),
          Text(
            '선수 프로필 기준 라운드 Fpts로 이주의 선수를 다시 집계하고 있습니다.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: palette.mutedInk,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptySection() {
    final palette = _leagueItSurfacePalette(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      decoration: BoxDecoration(
        color: palette.fieldFill,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Text(
        '표시할 이주의 선수 집계가 아직 없습니다.',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: palette.mutedInk,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = _leagueItSurfacePalette(context);
    final hasSections = _sections.isNotEmpty;
    final itemCount = hasSections ? _sections.length + 1 : 2;
    return _OverlayScaffold(
      isMyPageOpen: _isMyPageOpen,
      onToggleMyPage: _toggleMyPage,
      title: 'LeagueIt',
      showSearch: false,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
        itemCount: itemCount,
        separatorBuilder: (_, __) => const SizedBox(height: 14),
        itemBuilder: (_, index) {
          if (index == 0) {
            return Container(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: palette.isDark
                      ? const [Color(0xFF152130), Color(0xFF1B5A52)]
                      : const [Color(0xFF13203B), Color(0xFF1A816F)],
                ),
                borderRadius: BorderRadius.circular(26),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '이주의 선수',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: -0.8,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    '현재 라운드는 Top 30, 이전 라운드는 Top 3만 아래로 이어서 보여줍니다.',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: palette.isDark
                          ? const Color(0xFFCFD8E6)
                          : const Color(0xFFD8E4F2),
                    ),
                  ),
                ],
              ),
            );
          }
          if (!hasSections) {
            return _isRefreshingSections
                ? _buildLoadingSection()
                : _buildEmptySection();
          }
          final section = _sections[index - 1];
          return section.round == _currentRound
              ? _buildCurrentRoundSection(section)
              : _buildPastRoundSection(section);
        },
      ),
    );
  }
}

class _PositionAptsRankingPage extends StatefulWidget {
  const _PositionAptsRankingPage({
    required this.isSoccer,
    required this.position,
    required this.rankings,
  });

  final bool isSoccer;
  final String position;
  final List<_PositionAptsRankEntry> rankings;

  @override
  State<_PositionAptsRankingPage> createState() =>
      _PositionAptsRankingPageState();
}

class _PositionAptsRankingPageState extends State<_PositionAptsRankingPage> {
  bool _isMyPageOpen = false;
  void _toggleMyPage() => setState(() => _isMyPageOpen = !_isMyPageOpen);

  List<_PositionAptsRankEntry> _resolvedRankings() {
    final rankings =
        widget.rankings.map((player) {
          final liveApts = widget.isSoccer
              ? (() {
                  final roundPoints = _cachedKLeagueRoundPointsForPlayer(
                    playerName: player.name,
                    club: player.club,
                    preferredNumber: player.number,
                  );
                  return roundPoints != null
                      ? _kLeagueAptsFromRoundPoints(roundPoints)
                      : _cachedKLeaguePlayerApts[_kLeagueSeasonAptsKey(
                          club: player.club,
                          name: player.name,
                          preferredNumber: player.number,
                        )];
                })()
              : (() {
                  final apts = _cachedFullSeasonKboAptsForPlayer(
                    playerName: player.name,
                    club: _normalizeKboDraftClub(player.club),
                    preferredNumber: player.number,
                    preferredPosition: player.position,
                  );
                  return apts;
                })();
          if (liveApts == null) return player;
          return _PositionAptsRankEntry(
            position: player.position,
            name: player.name,
            club: player.club,
            number: player.number,
            apts: liveApts,
            ownership: player.ownership,
          );
        }).toList()..sort((a, b) {
          final scoreCompare = b.apts.compareTo(a.apts);
          if (scoreCompare != 0) return scoreCompare;
          final clubCompare = a.club.compareTo(b.club);
          if (clubCompare != 0) return clubCompare;
          return a.name.compareTo(b.name);
        });
    return rankings;
  }

  @override
  Widget build(BuildContext context) {
    final palette = _leagueItSurfacePalette(context);
    final rankings = _resolvedRankings();
    final accent = _positionAccentColor(widget.position);

    return _OverlayScaffold(
      isMyPageOpen: _isMyPageOpen,
      onToggleMyPage: _toggleMyPage,
      title: 'LeagueIt',
      showSearch: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
        children: [
          const SizedBox(height: 6),
          Text(
            '${widget.position} Apts 랭킹',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.6,
              color: palette.ink,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '누적 판타지 포인트 기준 평균 점수 순위입니다.',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: palette.mutedInk,
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: palette.fieldFill,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: palette.cardBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: palette.isDark ? 0.22 : 0.07,
                  ),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
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
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        widget.position,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: accent,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${rankings.length}명',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: palette.ink,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (rankings.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    child: Text(
                      '표시할 선수가 없습니다.',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: palette.mutedInk,
                      ),
                    ),
                  )
                else
                  ...List.generate(rankings.length, (index) {
                    final player = rankings[index];
                    return InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PlayerProfilePage(
                              name: player.name,
                              ownership: player.ownership,
                              metaOverride: _DocPlayerMeta(
                                position: player.position,
                                club: player.club,
                                number: player.number,
                              ),
                            ),
                          ),
                        ).then((_) {
                          if (!mounted) return;
                          setState(() {});
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          border: index == rankings.length - 1
                              ? null
                              : Border(
                                  bottom: BorderSide(color: palette.cardBorder),
                                ),
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 44,
                              child: Text(
                                '${index + 1}',
                                maxLines: 1,
                                softWrap: false,
                                overflow: TextOverflow.visible,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: palette.ink,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    player.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900,
                                      color: palette.ink,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _displayFantasyClubName(
                                      player.club,
                                      isSoccer: widget.isSoccer,
                                    ),
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: palette.mutedInk,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Apts ${player.apts.toStringAsFixed(1)}',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                color: _aptsDisplayColor(player.apts),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DraggableRosterList extends StatelessWidget {
  final List<_PlayerSlot> players;
  final bool showMeta;
  final void Function(_PlayerSlot from, _PlayerSlot to)? onSwap;
  final void Function(_PlayerSlot)? onTap;
  final bool Function(_PlayerSlot slot)? isLocked;
  const _DraggableRosterList({
    required this.players,
    this.showMeta = false,
    this.onSwap,
    this.onTap,
    this.isLocked,
  });

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[
      ...players.map(
        (p) => DragTarget<_PlayerSlot>(
          onWillAcceptWithDetails: (details) =>
              !(isLocked?.call(p) ?? false) && details.data != p,
          onAcceptWithDetails: (details) {
            if (isLocked?.call(p) ?? false) return;
            onSwap?.call(details.data, p);
          },
          builder: (context, candidate, rejected) {
            final locked = isLocked?.call(p) ?? false;
            if (locked) return _tile(context, p);
            return LongPressDraggable<_PlayerSlot>(
              data: p,
              feedback: _ghostTile(p),
              childWhenDragging: Opacity(
                opacity: 0.4,
                child: _tile(context, p),
              ),
              child: _tile(context, p, highlight: candidate.isNotEmpty),
            );
          },
        ),
      ),
    ];
    return Column(children: children);
  }

  Widget _tile(BuildContext context, _PlayerSlot p, {bool highlight = false}) {
    final locked = isLocked?.call(p) ?? false;
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
                Icon(
                  locked ? Icons.lock_rounded : Icons.drag_indicator,
                  size: 18,
                  color: locked ? const Color(0xFF667085) : Colors.black45,
                ),
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
                              '${p.position} · ${p.club}',
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
              ),
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
                      '${p.position} · ${p.club}',
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

class _FantasyBenchList extends StatelessWidget {
  const _FantasyBenchList({
    super.key,
    required this.players,
    this.isLocked,
    this.onSwap,
    this.onTap,
    this.scoreForSlot,
    this.actualScoreForSlot,
    this.isSoccer = true,
    this.showProjectedScores = true,
    this.onDragUpdate,
    this.onDragStarted,
    this.onDragEnded,
  });

  final List<_PlayerSlot> players;
  final bool Function(_PlayerSlot slot)? isLocked;
  final void Function(_PlayerSlot from, _PlayerSlot to)? onSwap;
  final void Function(_PlayerSlot)? onTap;
  final double Function(_PlayerSlot slot)? scoreForSlot;
  final double Function(_PlayerSlot slot)? actualScoreForSlot;
  final bool isSoccer;
  final bool showProjectedScores;
  final void Function(Offset globalPosition)? onDragUpdate;
  final void Function(_PlayerSlot slot)? onDragStarted;
  final void Function(_PlayerSlot slot)? onDragEnded;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ...players.map(
          (p) => KeyedSubtree(
            key: ValueKey('bench-${_playerSlotIdentity(p)}'),
            child: DragTarget<_PlayerSlot>(
              onWillAcceptWithDetails: (details) =>
                  !(isLocked?.call(p) ?? false) &&
                  _playerSlotIdentity(details.data) != _playerSlotIdentity(p),
              onAcceptWithDetails: (details) {
                if (isLocked?.call(p) ?? false) return;
                onSwap?.call(details.data, p);
              },
              builder: (context, candidate, rejected) {
                final locked = isLocked?.call(p) ?? false;
                if (locked) return _tile(context, p);
                return LongPressDraggable<_PlayerSlot>(
                  key: ValueKey('drag-${_playerSlotIdentity(p)}'),
                  data: p,
                  rootOverlay: true,
                  feedback: _ghostTile(context, p),
                  onDragStarted: () => onDragStarted?.call(p),
                  onDragCompleted: () => onDragEnded?.call(p),
                  onDraggableCanceled: (_, __) => onDragEnded?.call(p),
                  onDragEnd: (_) => onDragEnded?.call(p),
                  onDragUpdate: (details) =>
                      onDragUpdate?.call(details.globalPosition),
                  childWhenDragging: Opacity(
                    opacity: 0.4,
                    child: _tile(context, p),
                  ),
                  child: _tile(context, p, highlight: candidate.isNotEmpty),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _tile(BuildContext context, _PlayerSlot p, {bool highlight = false}) {
    return _tileBody(context, p, highlight: highlight);
  }

  Widget _tileBody(
    BuildContext context,
    _PlayerSlot p, {
    bool highlight = false,
  }) {
    final palette = _leagueItSurfacePalette(context);
    final locked = isLocked?.call(p) ?? false;
    final projected = scoreForSlot?.call(p) ?? _fantasyProjectedSlotScore(p);
    final actual = actualScoreForSlot?.call(p);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Material(
        color: highlight
            ? (palette.isDark
                  ? const Color(0xFF183A27)
                  : Colors.green.withOpacity(0.08))
            : palette.tileSurface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap == null ? null : () => onTap!(p),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: palette.cardBorder),
            ),
            child: Row(
              children: [
                Icon(
                  locked ? Icons.lock_rounded : Icons.drag_indicator,
                  size: 20,
                  color: locked ? palette.mutedInk : palette.mutedInk,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        showProjectedScores
                            ? '${p.name} / ${projected.toStringAsFixed(1)}'
                            : '${p.name} / 계산 중...',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: palette.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${p.position} · ${p.club}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: palette.mutedInk,
                        ),
                      ),
                    ],
                  ),
                ),
                if (actual != null) ...[
                  const SizedBox(width: 10),
                  Container(
                    constraints: const BoxConstraints(minWidth: 38),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: palette.isDark
                          ? const Color(0xFF223458)
                          : const Color(0xFFE9F0FF),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _formatBenchActualScore(actual),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: palette.isDark
                            ? const Color(0xFF8EB7FF)
                            : const Color(0xFF2D6DFF),
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatBenchActualScore(double value) {
    final rounded = value.toStringAsFixed(1);
    if (rounded.endsWith('.0')) {
      return rounded.substring(0, rounded.length - 2);
    }
    return rounded;
  }

  Widget _ghostTile(BuildContext context, _PlayerSlot p) {
    if (isSoccer) {
      return _FantasyRosterChip(
        slot: p,
        width: 82,
        color: Colors.blueAccent,
        scoreForSlot: scoreForSlot,
        onSwap: null,
        onTap: (_) {},
      )._chipBody(
        context,
        _leagueItSurfacePalette(context),
        highlight: true,
        isGhost: true,
      );
    }
    return _FantasyBaseballFieldChip(
      slot: p,
      size: 48,
      labelWidth: 88,
      scoreForSlot: scoreForSlot,
      actualScoreForSlot: actualScoreForSlot,
      onSwap: null,
      onTap: (_) {},
    )._ghostNode(_leagueItSurfacePalette(context));
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
  final String club;
  final int number;
  final String playerId;
  _PlayerSlot({
    required this.name,
    required this.score,
    required this.position,
    this.club = '',
    this.number = 0,
    this.playerId = '',
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
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: active ? activeColor.withOpacity(0.12) : Colors.transparent,
          border: Border.all(color: active ? activeColor : stroke, width: 1.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: active ? activeColor : stroke,
              ),
            ),
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
  required Color color,
  double Function(_PlayerSlot slot)? scoreForSlot,
  bool Function(_PlayerSlot slot)? isCaptainForSlot,
  required void Function(_PlayerSlot) onTap,
}) {
  const double rowHeight = 64;
  const double edgeInset = 14;
  const double penaltyBoxDepth = 65;
  const double goalKeeperInset = 0;
  final double firstRowTop = top + padding + edgeInset;
  final double lastRowTop = top + height - padding - rowHeight - edgeInset;
  final double span = lastRowTop - firstRowTop;
  final bool isFourLineSoccerShape = rows.length == 4;
  final bool startsWithGoalkeeper =
      rows.isNotEmpty &&
      rows.first.slots.length == 1 &&
      rows.first.slots.first.position == 'GK';
  final List<double> fractions = isFourLineSoccerShape
      ? (startsWithGoalkeeper
            ? const [0.0, 0.16, 0.58, 1.0]
            : const [0.0, 0.42, 0.84, 1.0])
      : [
          for (int i = 0; i < rows.length; i++)
            rows.length > 1 ? i / (rows.length - 1) : 0.0,
        ];
  return [
    for (int i = 0; i < rows.length; i++)
      () {
        final row = rows[i];
        final isGoalkeeperRow =
            row.slots.length == 1 && row.slots.first.position == 'GK';
        double rowTop = firstRowTop + span * fractions[i];
        if (isFourLineSoccerShape && isGoalkeeperRow) {
          rowTop = startsWithGoalkeeper
              ? top + goalKeeperInset
              : top + height - penaltyBoxDepth + goalKeeperInset;
        }
        return Positioned(
          top: rowTop,
          left: 0,
          right: 0,
          child: _LineupRow(
            players: row,
            color: color,
            scoreForSlot: scoreForSlot,
            isCaptainForSlot: isCaptainForSlot,
            onTap: onTap,
          ),
        );
      }(),
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

class _FantasyStandingRow {
  const _FantasyStandingRow({
    required this.team,
    required this.played,
    required this.wins,
    required this.losses,
    required this.ties,
    required this.standingPoints,
    required this.scoredPoints,
    required this.allowedPoints,
  });

  final String team;
  final int played;
  final int wins;
  final int losses;
  final int ties;
  final int standingPoints;
  final double scoredPoints;
  final double allowedPoints;

  double get goalDiff => scoredPoints - allowedPoints;
}

class _FantasyPowerRow {
  const _FantasyPowerRow({
    required this.team,
    required this.form,
    required this.recentAverage,
    required this.wins,
    required this.scoredPoints,
  });

  final String team;
  final String form;
  final double recentAverage;
  final int wins;
  final double scoredPoints;
}

int _fantasyPowerFormPriority(String form) {
  final normalized = form.replaceAll(' ', '').trim();
  if (normalized.startsWith('W')) return 3;
  if (normalized.startsWith('D')) return 2;
  if (normalized.isEmpty || normalized == '—' || normalized == '-') return 1;
  if (normalized.startsWith('L')) return 0;
  return 1;
}

int _fantasyPowerStreakLength(String form) {
  final normalized = form.replaceAll(' ', '').trim();
  final match = RegExp(r'^[WLD](\d+)?$').firstMatch(normalized);
  if (match == null) {
    return normalized == '—' || normalized == '-' || normalized.isEmpty ? 0 : 1;
  }
  return int.tryParse(match.group(1) ?? '') ?? 1;
}

int _fantasyPowerStreakCompare(String leftForm, String rightForm) {
  final left = leftForm.replaceAll(' ', '').trim();
  final right = rightForm.replaceAll(' ', '').trim();
  final leftLength = _fantasyPowerStreakLength(left);
  final rightLength = _fantasyPowerStreakLength(right);

  if (left.startsWith('W') && right.startsWith('W')) {
    return rightLength.compareTo(leftLength);
  }
  if (left.startsWith('L') && right.startsWith('L')) {
    return leftLength.compareTo(rightLength);
  }
  if (left.startsWith('D') && right.startsWith('D')) {
    return rightLength.compareTo(leftLength);
  }
  return rightLength.compareTo(leftLength);
}

class _PositionAptsRankEntry {
  const _PositionAptsRankEntry({
    required this.position,
    required this.name,
    required this.club,
    required this.number,
    required this.apts,
    required this.ownership,
  });

  final String position;
  final String name;
  final String club;
  final int number;
  final double apts;
  final PlayerOwnership ownership;
}

List<int> _fantasyScheduleRounds(_JoinedDraft draft) {
  final rounds =
      draft.fantasySchedule
          .map((matchup) => matchup.round)
          .where((round) => round > 0)
          .toSet()
          .toList()
        ..sort();
  return rounds.isEmpty ? const [1] : rounds;
}

int _completedFantasyRoundForStandings(_JoinedDraft draft) {
  final currentRound = _currentFantasyRoundAt(draft, DateTime.now());
  if (!draft.isSoccer) {
    return _completedKboFantasyRoundForStandings(draft, DateTime.now());
  }
  final snapshot =
      _fantasySoccerRoundScoreCache[_fantasySoccerRoundCacheKey(
        draft,
        currentRound,
      )];
  if (snapshot?.finalized == true) {
    return currentRound;
  }
  return max(0, currentRound - 1);
}

int _completedKboFantasyRoundForStandings(_JoinedDraft draft, DateTime now) {
  final scheduledRounds = _fantasyScheduleRounds(draft);
  if (scheduledRounds.isEmpty) return 0;

  var completedRound = 0;
  for (final round in scheduledRounds) {
    if (round <= 0) continue;
    if (!_kboFantasyRoundHasStarted(draft, round, now)) {
      break;
    }
    if (!_kboFantasyRoundAllGamesTerminal(draft, round, now: now) &&
        !_shouldFreezeUnlockedKboRoundScore(draft, round, now: now)) {
      break;
    }
    completedRound = round;
  }
  return completedRound;
}

List<_FantasyStandingRow> _fantasyStandingRowsForDraft(
  _JoinedDraft draft, {
  int? throughRound,
}) {
  final effectiveRound =
      throughRound ?? _completedFantasyRoundForStandings(draft);
  final stats = {
    for (final team in draft.fantasyTeams)
      team.teamName: (
        played: 0,
        wins: 0,
        losses: 0,
        ties: 0,
        standingPoints: 0,
        scoredPoints: 0.0,
        allowedPoints: 0.0,
      ),
  };
  final byName = {for (final team in draft.fantasyTeams) team.teamName: team};
  for (final matchup in draft.fantasySchedule.where(
    (item) => item.round <= effectiveRound,
  )) {
    final home = byName[matchup.homeTeam];
    final away = byName[matchup.awayTeam];
    if (home == null || away == null) continue;
    final homeScore = _fantasyTeamRoundScore(
      home,
      matchup.round,
      isSoccer: draft.isSoccer,
      draft: draft,
    );
    final awayScore = _fantasyTeamRoundScore(
      away,
      matchup.round,
      isSoccer: draft.isSoccer,
      draft: draft,
    );
    final homeStat = stats[home.teamName]!;
    final awayStat = stats[away.teamName]!;
    stats[home.teamName] = (
      played: homeStat.played + 1,
      wins: homeStat.wins + (homeScore > awayScore ? 1 : 0),
      losses: homeStat.losses + (homeScore < awayScore ? 1 : 0),
      ties: homeStat.ties + (homeScore == awayScore ? 1 : 0),
      standingPoints:
          homeStat.standingPoints +
          (homeScore > awayScore
              ? 3
              : homeScore == awayScore
              ? 1
              : 0),
      scoredPoints: homeStat.scoredPoints + homeScore,
      allowedPoints: homeStat.allowedPoints + awayScore,
    );
    stats[away.teamName] = (
      played: awayStat.played + 1,
      wins: awayStat.wins + (awayScore > homeScore ? 1 : 0),
      losses: awayStat.losses + (awayScore < homeScore ? 1 : 0),
      ties: awayStat.ties + (awayScore == homeScore ? 1 : 0),
      standingPoints:
          awayStat.standingPoints +
          (awayScore > homeScore
              ? 3
              : awayScore == homeScore
              ? 1
              : 0),
      scoredPoints: awayStat.scoredPoints + awayScore,
      allowedPoints: awayStat.allowedPoints + homeScore,
    );
  }
  final rows = stats.entries
      .map(
        (entry) => _FantasyStandingRow(
          team: entry.key,
          played: entry.value.played,
          wins: entry.value.wins,
          losses: entry.value.losses,
          ties: entry.value.ties,
          standingPoints: entry.value.standingPoints,
          scoredPoints: entry.value.scoredPoints,
          allowedPoints: entry.value.allowedPoints,
        ),
      )
      .toList();
  rows.sort((a, b) {
    final standingCompare = b.standingPoints.compareTo(a.standingPoints);
    if (standingCompare != 0) return standingCompare;
    final diffCompare = b.goalDiff.compareTo(a.goalDiff);
    if (diffCompare != 0) return diffCompare;
    final scoredCompare = b.scoredPoints.compareTo(a.scoredPoints);
    if (scoredCompare != 0) return scoredCompare;
    return a.team.compareTo(b.team);
  });
  return rows;
}

List<_FantasyPowerRow> _fantasyPowerRowsForDraft(_JoinedDraft draft) {
  final currentRound = _completedFantasyRoundForStandings(draft);
  final standings = _fantasyStandingRowsForDraft(
    draft,
    throughRound: currentRound,
  );
  final byName = {for (final team in draft.fantasyTeams) team.teamName: team};
  final rows =
      standings.map((standing) {
        final team = byName[standing.team];
        if (team == null) {
          return _FantasyPowerRow(
            team: standing.team,
            form: '—',
            recentAverage: 0.0,
            wins: standing.wins,
            scoredPoints: standing.scoredPoints,
          );
        }
        final recentMatchups =
            draft.fantasySchedule
                .where(
                  (matchup) =>
                      matchup.round <= currentRound &&
                      (matchup.homeTeam == team.teamName ||
                          matchup.awayTeam == team.teamName),
                )
                .toList()
              ..sort((a, b) => b.round.compareTo(a.round));
        final recentThree = recentMatchups.take(3).toList();
        final streakMarks = <String>[];
        var pointTotal = 0.0;
        for (final matchup in recentMatchups.reversed) {
          final home = byName[matchup.homeTeam];
          final away = byName[matchup.awayTeam];
          if (home == null || away == null) continue;
          final teamScore = _fantasyTeamRoundScore(
            team,
            matchup.round,
            isSoccer: draft.isSoccer,
            draft: draft,
          );
          final opponent = matchup.homeTeam == team.teamName ? away : home;
          final opponentScore = _fantasyTeamRoundScore(
            opponent,
            matchup.round,
            isSoccer: draft.isSoccer,
            draft: draft,
          );
          final mark = teamScore > opponentScore
              ? 'W'
              : teamScore < opponentScore
              ? 'L'
              : 'D';
          streakMarks.add(mark);
          if (recentThree.any((recent) => recent.round == matchup.round)) {
            pointTotal += teamScore;
          }
        }
        String streakLabel() {
          if (streakMarks.isEmpty) return '—';
          final latest = streakMarks.last;
          var streakCount = 0;
          for (final mark in streakMarks.reversed) {
            if (mark != latest) break;
            streakCount++;
          }
          if (streakCount <= 1) return latest;
          return '$latest$streakCount';
        }

        final recentAverage = recentThree.isEmpty
            ? 0.0
            : pointTotal / recentThree.length;
        return _FantasyPowerRow(
          team: team.teamName,
          form: streakLabel(),
          recentAverage: recentAverage,
          wins: standing.wins,
          scoredPoints: standing.scoredPoints,
        );
      }).toList()..sort((a, b) {
        final formCompare = _fantasyPowerFormPriority(
          b.form,
        ).compareTo(_fantasyPowerFormPriority(a.form));
        if (formCompare != 0) return formCompare;
        final streakCompare = _fantasyPowerStreakCompare(a.form, b.form);
        if (streakCompare != 0) return streakCompare;
        final winsCompare = b.wins.compareTo(a.wins);
        if (winsCompare != 0) return winsCompare;
        final recentCompare = b.recentAverage.compareTo(a.recentAverage);
        if (recentCompare != 0) return recentCompare;
        final scoredCompare = b.scoredPoints.compareTo(a.scoredPoints);
        if (scoredCompare != 0) return scoredCompare;
        return a.team.compareTo(b.team);
      });

  return rows;
}

String _formatFantasyFixtureScore(double value) {
  final rounded = value.toStringAsFixed(1);
  if (rounded.endsWith('.0')) return rounded.substring(0, rounded.length - 2);
  return rounded;
}

String _kboVisibleTeamScoresCacheKeyForRound(
  _JoinedDraft draft,
  int fantasyRound,
) => '${draft.leagueId}|$fantasyRound';

double? _persistedKboVisibleTeamScoreForTeam(
  _FantasyTeamState team, {
  required _JoinedDraft draft,
  required int round,
}) {
  final cacheKey = _kboVisibleTeamScoresCacheKeyForRound(draft, round);
  final entry = _persistedKboVisibleTeamScoresEntries[cacheKey];
  if (entry == null || entry.scores.isEmpty) return null;
  return entry.scores[_fantasyTeamIdentity(
    uid: team.uid,
    teamName: team.teamName,
  )];
}

void _cacheKboVisibleTeamScoresForRound(
  _JoinedDraft draft,
  int fantasyRound,
  Map<String, double> scores,
) {
  if (scores.isEmpty) return;
  final cacheKey = _kboVisibleTeamScoresCacheKeyForRound(draft, fantasyRound);
  _persistedKboVisibleTeamScoresEntries[cacheKey] =
      _PersistedKboVisibleTeamScoresEntry(
        updatedAt: DateTime.now(),
        scores: Map<String, double>.from(scores),
      );
  _freshKboVisibleTeamScoresKeys.add(cacheKey);
  unawaited(_persistKboVisibleTeamScoresCache());
}

String _fantasyFixtureRecordText(
  _JoinedDraft draft,
  String teamName,
  int round,
) {
  final previousRound = max(0, round - 1);
  final standings = _fantasyStandingRowsForDraft(
    draft,
    throughRound: previousRound,
  );
  _FantasyStandingRow? row;
  for (final standing in standings) {
    if (standing.team == teamName) {
      row = standing;
      break;
    }
  }
  if (row == null) return '0승 0무 0패';
  return '${row.wins}승 ${row.ties}무 ${row.losses}패';
}

_FantasyTeamState? _fantasyTeamByName(_JoinedDraft draft, String teamName) {
  for (final team in draft.fantasyTeams) {
    if (_sameFantasyIdentity(team.teamName, teamName)) return team;
  }
  return null;
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
  const _FixtureCardsPage({
    required this.isSoccer,
    this.fantasyDraft,
    this.preferredFantasyRound,
  });
  final bool isSoccer;
  final _JoinedDraft? fantasyDraft;
  final int? preferredFantasyRound;

  @override
  State<_FixtureCardsPage> createState() => _FixtureCardsPageState();
}

class _FixtureCardsPageState extends State<_FixtureCardsPage> {
  bool _isMyPageOpen = false;
  int? _selectedRound;
  bool _isLoadingFantasyScores = false;
  Map<String, double> _kboVisibleTeamScores = const <String, double>{};
  int? _queuedFantasyScoreRound;
  final Map<String, Future<Map<String, double>>> _kboVisibleTeamScoreLoads =
      <String, Future<Map<String, double>>>{};
  final Map<int, GlobalKey> _roundChipKeys = <int, GlobalKey>{};
  int? _lastEnsuredVisibleRound;
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

  bool get _isFantasySchedule => widget.fantasyDraft != null;

  @override
  void initState() {
    super.initState();
    if (_isFantasySchedule) {
      unawaited(_primeFantasyScores());
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _ensureSelectedRoundChipVisible();
      });
    }
  }

  @override
  void didUpdateWidget(covariant _FixtureCardsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isFantasySchedule) return;
    final oldLeagueId = oldWidget.fantasyDraft?.leagueId;
    final newLeagueId = widget.fantasyDraft?.leagueId;
    final preferredRoundChanged =
        oldWidget.preferredFantasyRound != widget.preferredFantasyRound;
    if (oldLeagueId != newLeagueId || preferredRoundChanged) {
      _lastEnsuredVisibleRound = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _ensureSelectedRoundChipVisible();
      });
    }
  }

  GlobalKey _roundChipKeyFor(int round) =>
      _roundChipKeys.putIfAbsent(round, GlobalKey.new);

  void _ensureSelectedRoundChipVisible([int? round]) {
    final draft = widget.fantasyDraft;
    if (!mounted || draft == null) return;
    final targetRound = round ?? _effectiveRound(draft);
    if (_lastEnsuredVisibleRound == targetRound && round == null) {
      return;
    }
    final targetKey = _roundChipKeyFor(targetRound);
    final targetContext = targetKey.currentContext;
    if (targetContext == null) return;
    _lastEnsuredVisibleRound = targetRound;
    Scrollable.ensureVisible(
      targetContext,
      alignment: 0.5,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  String _kboVisibleTeamScoresKey(_JoinedDraft draft, int fantasyRound) =>
      '${draft.leagueId}|$fantasyRound';

  Map<String, double> _persistedKboVisibleScoresForRound(
    _JoinedDraft draft,
    int fantasyRound,
  ) {
    final entry =
        _persistedKboVisibleTeamScoresEntries[_kboVisibleTeamScoresKey(
          draft,
          fantasyRound,
        )];
    if (entry == null || entry.scores.isEmpty) return const <String, double>{};
    return Map<String, double>.from(entry.scores);
  }

  Future<void> _applyPersistedKboVisibleScoresIfAvailable(
    _JoinedDraft draft,
    int fantasyRound,
  ) async {
    await _restorePersistedKboVisibleTeamScoresCache();
    if (!mounted || _effectiveRound(draft) != fantasyRound) return;
    final persisted = _persistedKboVisibleScoresForRound(draft, fantasyRound);
    if (persisted.isEmpty) return;
    setState(() {
      _kboVisibleTeamScores = persisted;
    });
  }

  Future<void> _primeFantasyScores({int? round}) async {
    final draft = widget.fantasyDraft;
    if (draft == null) return;
    final targetRound = round ?? _effectiveRound(draft);
    if (_isLoadingFantasyScores) {
      _queuedFantasyScoreRound = targetRound;
      return;
    }
    _isLoadingFantasyScores = true;
    if (mounted) {
      setState(() {});
    }
    try {
      if (draft.isSoccer) {
        await _ensureFantasySoccerRoundScoreSnapshot(
          draft,
          targetRound,
          forceRefreshLiveData:
              targetRound == _currentFantasyRoundAt(draft, DateTime.now()),
        );
        if (mounted) {
          setState(() {});
        }
        unawaited(() async {
          try {
            for (int value = 1; value < targetRound; value++) {
              await _ensureFantasySoccerRoundScoreSnapshot(
                draft,
                value,
                force: false,
              );
            }
          } catch (error, stackTrace) {
            debugPrint('primeFantasyScores history failed: $error');
            debugPrint('$stackTrace');
          } finally {
            if (mounted) {
              setState(() {});
            }
          }
        }());
        return;
      }
      await _applyPersistedKboVisibleScoresIfAvailable(draft, targetRound);
      final scores = await _loadVisibleKboTeamScoresForRound(
        draft,
        targetRound,
      );
      if (!mounted || _effectiveRound(draft) != targetRound) return;
      setState(() {
        _kboVisibleTeamScores = scores;
      });
    } catch (error, stackTrace) {
      debugPrint('primeFantasyScores failed: $error');
      debugPrint('$stackTrace');
    } finally {
      _isLoadingFantasyScores = false;
      if (mounted) {
        setState(() {});
      }
      final queuedRound = _queuedFantasyScoreRound;
      _queuedFantasyScoreRound = null;
      if (draft == widget.fantasyDraft &&
          queuedRound != null &&
          queuedRound != targetRound) {
        unawaited(_primeFantasyScores(round: queuedRound));
      }
    }
  }

  int _effectiveRound(_JoinedDraft draft) {
    final rounds = _fantasyScheduleRounds(draft);
    final currentRound = widget.preferredFantasyRound != null
        ? min(max(1, widget.preferredFantasyRound!), max(1, draft.roundCount))
        : _currentFantasyRoundAt(draft, DateTime.now());
    if (_selectedRound != null && rounds.contains(_selectedRound)) {
      return _selectedRound!;
    }
    if (rounds.contains(currentRound)) return currentRound;
    return rounds.first;
  }

  Future<Map<String, double>> _loadVisibleKboTeamScoresForRound(
    _JoinedDraft draft,
    int fantasyRound,
  ) async {
    final loadKey = _kboVisibleTeamScoresKey(draft, fantasyRound);
    final inFlight = _kboVisibleTeamScoreLoads[loadKey];
    if (inFlight != null) return inFlight;
    final future =
        _loadVisibleKboTeamScoresForRoundInternal(
          draft,
          fantasyRound,
        ).whenComplete(() {
          _kboVisibleTeamScoreLoads.remove(loadKey);
        });
    _kboVisibleTeamScoreLoads[loadKey] = future;
    return future;
  }

  Future<Map<String, double>> _loadVisibleKboTeamScoresForRoundInternal(
    _JoinedDraft draft,
    int fantasyRound,
  ) async {
    final matchups = draft.fantasySchedule
        .where((matchup) => matchup.round == fantasyRound)
        .toList();
    if (matchups.isEmpty) return const <String, double>{};

    _FantasyTeamState? findTeam({required String uid, required String name}) {
      for (final team in draft.fantasyTeams) {
        if (uid.isNotEmpty && team.uid == uid) return team;
        if (name.isNotEmpty && _sameFantasyIdentity(team.teamName, name)) {
          return team;
        }
      }
      return null;
    }

    final teamsByIdentity = <String, _FantasyTeamState>{};
    for (final matchup in matchups) {
      final homeTeam = findTeam(uid: matchup.homeUid, name: matchup.homeTeam);
      final awayTeam = findTeam(uid: matchup.awayUid, name: matchup.awayTeam);
      if (homeTeam != null) {
        teamsByIdentity[_fantasyTeamIdentity(
              uid: homeTeam.uid,
              teamName: homeTeam.teamName,
            )] =
            homeTeam;
      }
      if (awayTeam != null) {
        teamsByIdentity[_fantasyTeamIdentity(
              uid: awayTeam.uid,
              teamName: awayTeam.teamName,
            )] =
            awayTeam;
      }
    }
    if (teamsByIdentity.isEmpty) return const <String, double>{};

    await _restorePersistedKboVisibleTeamScoresCache();
    final persisted = _persistedKboVisibleScoresForRound(draft, fantasyRound);
    final now = DateTime.now();
    if (persisted.isNotEmpty &&
        _fantasyRoundIsFinalized(draft, fantasyRound, now: now)) {
      return persisted;
    }

    final roundPlayersByTeamIdentity = <String, List<_FantasyTeamPlayer>>{};
    final playersByClubAndName = <String, List<_FantasyTeamPlayer>>{};
    for (final entry in teamsByIdentity.entries) {
      final team = entry.value;
      final state = _kboRoundScoreStateForTeam(team, fantasyRound);
      final roundPlayers = state == null
          ? team.starting
          : _resolvedKboRoundStarterPlayers(team, state);
      roundPlayersByTeamIdentity[entry.key] = roundPlayers;
      for (final player in roundPlayers) {
        final club = _normalizeKboDraftClub(player.club);
        final name = player.name.trim();
        if (club.isEmpty || name.isEmpty) continue;
        playersByClubAndName.putIfAbsent(
          '$club|$name',
          () => <_FantasyTeamPlayer>[],
        );
        playersByClubAndName['$club|$name']!.add(player);
      }
    }

    final leagueData = await _loadCachedKboLeagueData();
    final rawMatches = _fixtureAsList(leagueData['matches']);
    final frozenCancelledOriginalRounds =
        _kboFrozenCancelledMatchOriginalRounds(leagueData);
    final absoluteRound = _mappedKboRoundForFantasyRound(draft, fantasyRound);
    final relevantMatchIds = <int>{};
    for (final raw in rawMatches) {
      final match = _fixtureAsMap(raw);
      final matchDate = DateTime.tryParse('${match['date'] ?? ''}');
      if (matchDate == null || !_kboMatchMapHasStarted(match, now: now)) {
        continue;
      }
      final matchId = _readNullableInt(match['id']);
      if (matchId == null || matchId <= 0) continue;
      final originalRound = frozenCancelledOriginalRounds[matchId];
      if (originalRound != null && originalRound != absoluteRound) {
        continue;
      }
      if (_kboFantasyRoundForMatchDate(matchDate) != absoluteRound &&
          originalRound != absoluteRound) {
        continue;
      }
      relevantMatchIds.add(matchId);
    }

    final currentScores = <String, double>{};
    if (relevantMatchIds.isNotEmpty) {
      const batchSize = 5;
      final ids = relevantMatchIds.toList();
      for (var start = 0; start < ids.length; start += batchSize) {
        final end = min(start + batchSize, ids.length);
        final batch = ids.sublist(start, end);
        final resolved = await Future.wait(
          batch.map((matchId) async {
            try {
              return await _loadCachedKboMatchDetail(
                matchId,
                fantasyRound: absoluteRound,
              );
            } catch (error, stackTrace) {
              debugPrint(
                'Fantasy schedule KBO match detail load failed '
                '(round=$fantasyRound, match=$matchId): $error',
              );
              debugPrint('$stackTrace');
              return null;
            }
          }),
        );

        for (final detail in resolved.whereType<Map<String, dynamic>>()) {
          for (final rawStat in _fixtureAsList(detail['playerStats'])) {
            final stat = _fixtureAsMap(rawStat);
            final name = '${stat['name'] ?? ''}'.trim();
            final club = _normalizeKboDraftClub('${stat['team'] ?? ''}');
            if (name.isEmpty || club.isEmpty) continue;
            final candidates = playersByClubAndName['$club|$name'];
            if (candidates == null || candidates.isEmpty) continue;
            _FantasyTeamPlayer? matched;
            for (final candidate in candidates) {
              if (_kboPlayerStatMatchesProfile(
                stat,
                name,
                meta: (
                  position: candidate.position,
                  club: _normalizeKboDraftClub(candidate.club),
                  number: candidate.number,
                ),
              )) {
                matched = candidate;
                break;
              }
            }
            matched ??= candidates.length == 1 ? candidates.first : null;
            if (matched == null) continue;
            final fantasy = _fixtureAsMap(stat['fantasy']);
            final points = double.parse(
              (((fantasy['points'] as num?)?.toDouble() ?? 0.0))
                  .toStringAsFixed(2),
            );
            final playerIdentity = _fantasyTeamPlayerIdentity(matched);
            currentScores[playerIdentity] =
                (currentScores[playerIdentity] ?? 0.0) + points;
          }
        }
      }
    }

    final scoresByTeam = <String, double>{};
    for (final entry in teamsByIdentity.entries) {
      final team = entry.value;
      final roundPlayers =
          roundPlayersByTeamIdentity[entry.key] ?? team.starting;
      final unlockedSnapshot = _kboUnlockedRoundScoreSnapshotForTeam(
        team,
        draft: draft,
        round: fantasyRound,
      );
      if (unlockedSnapshot != null) {
        scoresByTeam[entry.key] = unlockedSnapshot;
        continue;
      }
      final state = _kboRoundScoreStateForTeam(team, fantasyRound);
      final baselines = state?.starterBaselines ?? const <String, double>{};
      final bankedScore = state?.bankedScore ?? 0.0;
      final doubledPlayerId = state?.doubledPlayerId?.trim().isNotEmpty == true
          ? state!.doubledPlayerId!.trim()
          : _effectiveCaptainDoublePlayerIdForKboTeam(
              team,
              draft: draft,
              round: fantasyRound,
            );
      scoresByTeam[entry.key] =
          bankedScore +
          roundPlayers.fold<double>(0.0, (total, player) {
            final playerIdentity = _fantasyTeamPlayerIdentity(player);
            final currentBase = currentScores[playerIdentity] ?? 0.0;
            final current = playerIdentity == doubledPlayerId
                ? currentBase * 2
                : currentBase;
            final baseline = baselines[playerIdentity] ?? 0.0;
            return total + (current - baseline);
          });
    }
    _cacheKboVisibleTeamScoresForRound(draft, fantasyRound, scoresByTeam);
    return scoresByTeam;
  }

  double _fantasyScheduleDisplayedTeamScore(
    _FantasyTeamState team, {
    required _JoinedDraft draft,
    required int round,
  }) {
    final now = DateTime.now();
    if (draft.isSoccer) {
      if (round > _currentFantasyRoundAt(draft, now)) {
        return 0.0;
      }
      return _fantasyTeamRoundScore(team, round, isSoccer: true, draft: draft);
    }
    if (!_kboFantasyRoundHasStarted(draft, round, now)) {
      return 0.0;
    }
    final key = _fantasyTeamIdentity(uid: team.uid, teamName: team.teamName);
    return _kboVisibleTeamScores[key] ??
        _fantasyTeamRoundScore(team, round, isSoccer: false, draft: draft);
  }

  @override
  Widget build(BuildContext context) {
    final palette = _leagueItSurfacePalette(context);
    if (_isFantasySchedule) {
      final draft = widget.fantasyDraft!;
      final rounds = _fantasyScheduleRounds(draft);
      final selectedRound = _effectiveRound(draft);
      final myUid = _currentUserFantasyUid();
      final myTeamName = _currentUserFantasyTeamName(draft);

      bool isCurrentUserMatchup(_FantasyScheduleMatchup matchup) =>
          (myUid != null &&
              (matchup.homeUid == myUid || matchup.awayUid == myUid)) ||
          (myTeamName != null &&
              (matchup.homeTeam == myTeamName ||
                  matchup.awayTeam == myTeamName));

      final matchups =
          draft.fantasySchedule
              .where((matchup) => matchup.round == selectedRound)
              .toList()
            ..sort((a, b) {
              final aMine = isCurrentUserMatchup(a) ? 0 : 1;
              final bMine = isCurrentUserMatchup(b) ? 0 : 1;
              if (aMine != bMine) return aMine.compareTo(bMine);
              return a.homeTeam.compareTo(b.homeTeam);
            });
      final currentRound = _currentFantasyRoundAt(draft, DateTime.now());
      final now = DateTime.now();

      Future<void> openMatchup(_FantasyScheduleMatchup matchup) async {
        final homeTeam = _fantasyTeamByName(draft, matchup.homeTeam);
        final awayTeam = _fantasyTeamByName(draft, matchup.awayTeam);
        if (homeTeam == null || awayTeam == null) return;
        final initialHomeScore = _fantasyScheduleDisplayedTeamScore(
          homeTeam,
          draft: draft,
          round: matchup.round,
        );
        final initialAwayScore = _fantasyScheduleDisplayedTeamScore(
          awayTeam,
          draft: draft,
          round: matchup.round,
        );
        homeKey.currentState?.setBackgroundLiveRefreshSuspended(true);
        try {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => _FantasyFixtureDetailPage(
                draft: draft,
                matchup: matchup,
                homeTeam: homeTeam,
                awayTeam: awayTeam,
                initialHomeScore: initialHomeScore,
                initialAwayScore: initialAwayScore,
              ),
            ),
          );
        } finally {
          homeKey.currentState?.setBackgroundLiveRefreshSuspended(false);
        }
        if (!mounted) return;
        setState(() {});
      }

      Widget buildRoundChip(int round) {
        final active = round == selectedRound;
        return Padding(
          key: _roundChipKeyFor(round),
          padding: const EdgeInsets.only(right: 10),
          child: ChoiceChip(
            label: Text(
              '$round라운드',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: active ? Colors.white : const Color(0xFF445062),
              ),
            ),
            selected: active,
            onSelected: (_) {
              setState(() => _selectedRound = round);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _ensureSelectedRoundChipVisible(round);
              });
              unawaited(_primeFantasyScores(round: round));
            },
            selectedColor: const Color(0xFF11192A),
            backgroundColor: palette.tileSurface,
            side: BorderSide(color: palette.cardBorder),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        );
      }

      if (_lastEnsuredVisibleRound != selectedRound) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _ensureSelectedRoundChipVisible(selectedRound);
        });
      }

      Widget buildMatchCard(_FantasyScheduleMatchup matchup) {
        final homeTeam = _fantasyTeamByName(draft, matchup.homeTeam);
        final awayTeam = _fantasyTeamByName(draft, matchup.awayTeam);
        if (homeTeam == null || awayTeam == null) {
          return const SizedBox.shrink();
        }
        final homeScore = _fantasyScheduleDisplayedTeamScore(
          homeTeam,
          draft: draft,
          round: matchup.round,
        );
        final awayScore = _fantasyScheduleDisplayedTeamScore(
          awayTeam,
          draft: draft,
          round: matchup.round,
        );
        final isMyMatchup = isCurrentUserMatchup(matchup);
        final isRoundFinalized = _fantasyRoundIsFinalized(
          draft,
          matchup.round,
          now: now,
        );
        final roundStarted = draft.isSoccer
            ? matchup.round <= currentRound
            : _kboFantasyRoundHasStarted(draft, matchup.round, now);
        final isPastRound = matchup.round < currentRound;
        final isCurrentRound = matchup.round == currentRound && roundStarted;
        final statusLabel = isPastRound || (isCurrentRound && isRoundFinalized)
            ? '종료'
            : isCurrentRound
            ? '진행중'
            : '예정';
        final statusColor = isCurrentRound && !isRoundFinalized
            ? const Color(0xFF20A35B)
            : const Color(0xFF6E7C91);
        final homeRecord = _fantasyFixtureRecordText(
          draft,
          matchup.homeTeam,
          matchup.round,
        );
        final awayRecord = _fantasyFixtureRecordText(
          draft,
          matchup.awayTeam,
          matchup.round,
        );

        Widget buildTeamBlock(
          _FantasyTeamState team,
          String record, {
          required bool alignRight,
        }) {
          final crossAxisAlignment = alignRight
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start;
          final alignment = alignRight
              ? Alignment.centerRight
              : Alignment.centerLeft;
          final textAlign = alignRight ? TextAlign.right : TextAlign.left;

          return Column(
            crossAxisAlignment: crossAxisAlignment,
            children: [
              _FantasyTeamAvatar(
                uid: team.uid,
                teamName: team.teamName,
                size: 42,
                iconSize: 20,
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 28,
                width: double.infinity,
                child: Align(
                  alignment: alignment,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: alignment,
                    child: Text(
                      team.teamName,
                      maxLines: 1,
                      textAlign: textAlign,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                record,
                textAlign: textAlign,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: palette.mutedInk,
                ),
              ),
            ],
          );
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: palette.fieldFill,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isMyMatchup ? const Color(0xFFDCE6CF) : palette.cardBorder,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: () => openMatchup(matchup),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
              child: Column(
                children: [
                  Row(
                    children: [
                      if (isMyMatchup)
                        Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1F2A44),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            'MY MATCHUP',
                            style: TextStyle(
                              fontSize: 11,
                              height: 1,
                              letterSpacing: 0.5,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          statusLabel,
                          style: const TextStyle(
                            fontSize: 11,
                            height: 1,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const Spacer(),
                      InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => openMatchup(matchup),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          child: Row(
                            children: [
                              Text(
                                '라인업 보기',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: palette.mutedInk,
                                ),
                              ),
                              SizedBox(width: 4),
                              Icon(
                                Icons.chevron_right,
                                size: 20,
                                color: palette.mutedInk,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: buildTeamBlock(
                          homeTeam,
                          homeRecord,
                          alignRight: false,
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 14),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: palette.tileSurface,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: palette.cardBorder),
                        ),
                        child: Text(
                          '${_formatFantasyFixtureScore(homeScore)} : ${_formatFantasyFixtureScore(awayScore)}',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: palette.ink,
                          ),
                        ),
                      ),
                      Expanded(
                        child: buildTeamBlock(
                          awayTeam,
                          awayRecord,
                          alignRight: true,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      }

      return _OverlayScaffold(
        isMyPageOpen: _isMyPageOpen,
        onToggleMyPage: _toggleMyPage,
        title: 'LeagueIt',
        showSearch: false,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: palette.fieldFill,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: palette.cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    draft.leagueName,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: palette.ink,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Fantasy Schedule',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: palette.mutedInk,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: rounds.map(buildRoundChip).toList()),
            ),
            const SizedBox(height: 18),
            ...matchups.map(buildMatchCard),
          ],
        ),
      );
    }

    final myTeam = widget.isSoccer ? 'Blue Foxes' : 'Seoul Sluggers';
    final cached = widget.isSoccer
        ? _MatchDetailPageState._cachedSoccerLineup
        : null;
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
                    _matchDetailPageRoute(
                      isSoccer: widget.isSoccer,
                      initialSection: _MatchSection.matchup,
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
    final palette = _leagueItSurfacePalette(context);
    final homeColor = _teamColor(data.home);
    final awayColor = _teamColor(data.away);
    return Card(
      color: palette.fieldFill,
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
                  style: TextStyle(
                    fontSize: 13,
                    color: palette.mutedInk,
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
    final palette = _leagueItSurfacePalette(context);
    final scoreText = isSoccer
        ? score.toStringAsFixed(0)
        : score.toStringAsFixed(1);
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
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: palette.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                record,
                style: TextStyle(color: palette.mutedInk, fontSize: 13),
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
                    : palette.ink,
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
    final palette = _leagueItSurfacePalette(context);
    final _LineupData? lineup = widget.isSoccer
        ? _MatchDetailPageState.getOrCreateSoccerFixtureLineup(widget.fixture)
        : null;
    final double homeScore = widget.isSoccer
        ? lineup!.homeScore.toDouble()
        : widget.fixture.homeScore;
    final double awayScore = widget.isSoccer
        ? lineup!.awayScore.toDouble()
        : widget.fixture.awayScore;
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
                  icon: widget.isSoccer
                      ? Icons.shield_outlined
                      : Icons.sports_baseball,
                  label: widget.isSoccer
                      ? homeScore.toStringAsFixed(0)
                      : homeScore.toStringAsFixed(1),
                ),
                Column(
                  children: [
                    Text(
                      scoreText,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: palette.ink,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${widget.fixture.homeRecord}  |  ${widget.fixture.awayRecord}',
                      style: TextStyle(fontSize: 13, color: palette.mutedInk),
                    ),
                  ],
                ),
                _TeamBadge(
                  icon: widget.isSoccer
                      ? Icons.workspace_premium_outlined
                      : Icons.emoji_events_outlined,
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
                Text(
                  '승리 확률',
                  style: TextStyle(fontSize: 13, color: palette.mutedInk),
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
                  color: palette.fieldFill,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: palette.cardBorder),
                ),
                child: Text(
                  'KBO 경기는 포메이션 없이 점수만 제공합니다.',
                  style: TextStyle(color: palette.ink),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FantasyFixtureDetailPage extends StatefulWidget {
  const _FantasyFixtureDetailPage({
    required this.draft,
    required this.matchup,
    required this.homeTeam,
    required this.awayTeam,
    this.initialHomeScore,
    this.initialAwayScore,
  });

  final _JoinedDraft draft;
  final _FantasyScheduleMatchup matchup;
  final _FantasyTeamState homeTeam;
  final _FantasyTeamState awayTeam;
  final double? initialHomeScore;
  final double? initialAwayScore;

  @override
  State<_FantasyFixtureDetailPage> createState() =>
      _FantasyFixtureDetailPageState();
}

class _FantasyFixtureDetailPageState extends State<_FantasyFixtureDetailPage> {
  bool _isMyPageOpen = false;
  bool _isLoadingProjectedScores = false;
  Map<String, double> _projectedScores = const <String, double>{};
  double? _initialVisibleHomeScore;
  double? _initialVisibleAwayScore;
  final GlobalKey _detailSummaryShowcaseKey = GlobalKey();
  final GlobalKey _detailLineupShowcaseKey = GlobalKey();
  final GlobalKey _detailBenchShowcaseKey = GlobalKey();
  Timer? _detailCoachRetryTimer;
  Map<
    String,
    ({double opportunityFactor, int confirmedStarts, int completedStarts})
  >
  _pitcherWeeklyProjectionContexts =
      const <
        String,
        ({double opportunityFactor, int confirmedStarts, int completedStarts})
      >{};

  void _toggleMyPage() => setState(() => _isMyPageOpen = !_isMyPageOpen);

  String get _detailCoachStorageKey {
    final sport = widget.draft.isSoccer ? 'soccer' : 'baseball';
    return 'matchup_detail.coachmarks.$sport.v3';
  }

  List<GlobalKey> get _detailCoachKeys => <GlobalKey>[
    _detailSummaryShowcaseKey,
    _detailLineupShowcaseKey,
    _detailBenchShowcaseKey,
  ];

  Widget _buildDetailCoachMark({
    required GlobalKey showcaseKey,
    required String title,
    required String description,
    required Widget child,
    BorderRadius? targetBorderRadius,
    TooltipPosition? tooltipPosition,
    bool enableAutoScroll = false,
    double scrollAlignment = 0.5,
    Widget? supplementalContent,
  }) {
    return _buildLeagueItCoachMark(
      context: context,
      showcaseKey: showcaseKey,
      title: title,
      description: description,
      targetBorderRadius: targetBorderRadius,
      tooltipPosition: tooltipPosition,
      enableAutoScroll: enableAutoScroll,
      scrollAlignment: scrollAlignment,
      supplementalContent: supplementalContent,
      child: child,
    );
  }

  Widget _buildProjectedScoresLoadingNotice() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FBFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD7E7FF)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2.0),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              '예상 Fpts를 계산하는 중입니다.',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  void _scheduleDetailCoachMarks({bool force = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_maybeStartDetailCoachMarks(force: force));
    });
  }

  void _retryDetailCoachMarks({bool force = false}) {
    _detailCoachRetryTimer?.cancel();
    _detailCoachRetryTimer = Timer(const Duration(milliseconds: 320), () {
      if (!mounted) return;
      unawaited(_maybeStartDetailCoachMarks(force: force));
    });
  }

  Future<void> _maybeStartDetailCoachMarks({bool force = false}) async {
    if (!mounted || _isMyPageOpen) {
      _retryDetailCoachMarks(force: force);
      return;
    }

    if (!force) {
      final seen = await _readLocalStateCache(_detailCoachStorageKey);
      if (seen == '1') return;
    }
    if (!mounted) return;

    try {
      final showcase = ShowcaseView.get();
      final allTargetsReady = _detailCoachKeys.every(showcase.isTargetRendered);
      if (!allTargetsReady) {
        _retryDetailCoachMarks(force: force);
        return;
      }
      if (showcase.isShowcaseRunning) return;
      await _writeLocalStateCache(_detailCoachStorageKey, '1');
      if (!mounted) return;
      showcase.startShowCase(
        _detailCoachKeys,
        delay: const Duration(milliseconds: 240),
      );
    } catch (error, stackTrace) {
      debugPrint('Matchup detail coach mark start failed: $error');
      debugPrint('$stackTrace');
      _retryDetailCoachMarks(force: force);
    }
  }

  void _replayDetailCoachMarks() {
    if (!mounted) return;
    _detailCoachRetryTimer?.cancel();
    try {
      final showcase = ShowcaseView.get();
      if (showcase.isShowcaseRunning) {
        showcase.dismiss();
      }
    } catch (_) {}
    if (_isMyPageOpen) {
      setState(() => _isMyPageOpen = false);
    }
    _scheduleDetailCoachMarks(force: true);
  }

  _FantasyTeamState _resolvedMatchupTeamForRound(_FantasyTeamState team) {
    if (widget.draft.isSoccer) return team;

    final state = _kboRoundScoreStateForTeam(team, widget.matchup.round);
    if (state == null) return team;

    final historicalStarting = _resolvedKboRoundStarterPlayers(team, state);
    if (historicalStarting.isEmpty) return team;

    final now = DateTime.now();
    final isHistoricalOrFinalized =
        widget.matchup.round < _currentFantasyRoundAt(widget.draft, now) ||
        _kboFantasyRoundAllGamesTerminal(
          widget.draft,
          widget.matchup.round,
          now: now,
        ) ||
        _shouldFreezeUnlockedKboRoundScore(
          widget.draft,
          widget.matchup.round,
          now: now,
        );

    final orderedRoster = <_FantasyTeamPlayer>[];
    final seenIds = <String>{};

    void appendPlayers(Iterable<_FantasyTeamPlayer> players) {
      for (final player in players) {
        final identity = _fantasyTeamPlayerIdentity(player);
        if (!seenIds.add(identity)) continue;
        orderedRoster.add(player);
      }
    }

    appendPlayers(historicalStarting);
    if (!isHistoricalOrFinalized) {
      appendPlayers(team.roster);
      appendPlayers(team.starting);
      appendPlayers(team.bench);
      appendPlayers(state.starterPlayers);
    }

    final roster = List<_FantasyTeamPlayer>.from(orderedRoster);
    final starterIds = historicalStarting
        .map(_fantasyTeamPlayerIdentity)
        .toSet();
    final bench = isHistoricalOrFinalized
        ? const <_FantasyTeamPlayer>[]
        : roster
              .where(
                (player) =>
                    !starterIds.contains(_fantasyTeamPlayerIdentity(player)),
              )
              .toList(growable: false);

    final doubledPlayerId = state.doubledPlayerId?.trim();
    final doubledPlayer = doubledPlayerId == null || doubledPlayerId.isEmpty
        ? null
        : historicalStarting.cast<_FantasyTeamPlayer?>().firstWhere(
            (player) =>
                player != null &&
                _fantasyTeamPlayerIdentity(player) == doubledPlayerId,
            orElse: () => null,
          );

    return _FantasyTeamState(
      uid: team.uid,
      teamName: team.teamName,
      roster: roster,
      starting: historicalStarting,
      bench: bench,
      captainName: doubledPlayer?.name ?? team.captainName,
      viceCaptainName: team.viceCaptainName,
      captainPlayerId: doubledPlayerId?.isNotEmpty == true
          ? doubledPlayerId
          : team.captainPlayerId,
      viceCaptainPlayerId: team.viceCaptainPlayerId,
      kboRoundScoreStates: team.kboRoundScoreStates,
    );
  }

  _FantasyTeamState get _roundHomeTeam =>
      _resolvedMatchupTeamForRound(widget.homeTeam);

  _FantasyTeamState get _roundAwayTeam =>
      _resolvedMatchupTeamForRound(widget.awayTeam);

  List<_FantasyTeamState> _matchupTeamsForRound() => <_FantasyTeamState>[
    _roundHomeTeam,
    _roundAwayTeam,
  ];

  Map<String, _PlayerSlot> _matchupUniquePlayers() {
    final uniquePlayers = <String, _PlayerSlot>{};
    for (final team in _matchupTeamsForRound()) {
      for (final player in [...team.roster, ...team.starting, ...team.bench]) {
        final slot = player.toPlayerSlot();
        uniquePlayers[_playerSlotIdentity(slot)] = slot;
      }
    }
    return uniquePlayers;
  }

  bool _hasDisplayableProjectedScoresForMatchup(Map<String, double> scores) {
    if (scores.isEmpty) return false;
    final sourceTeams = _matchupTeamsForRound();
    for (final team in sourceTeams) {
      for (final player in team.roster) {
        final slot = player.toPlayerSlot();
        final hasProjection = widget.draft.isSoccer
            ? scores.containsKey(_playerSlotIdentity(slot))
            : _kboProjectionAliasKeysForSlot(slot).any(scores.containsKey);
        if (!hasProjection) {
          return false;
        }
      }
    }
    return true;
  }

  @override
  void initState() {
    super.initState();
    _initialVisibleHomeScore = widget.initialHomeScore;
    _initialVisibleAwayScore = widget.initialAwayScore;
    _seedProjectedScoresForFirstPaint();
    final roundHomeTeam = _roundHomeTeam;
    final roundAwayTeam = _roundAwayTeam;
    if (kDebugMode) {
      debugPrint(
        'FixtureDetail init '
        'round=${widget.matchup.round} '
        'home=${roundHomeTeam.teamName} '
        'away=${roundAwayTeam.teamName} '
        'initialHomeScore=${widget.initialHomeScore} '
        'initialAwayScore=${widget.initialAwayScore} '
        'homeStarting=${roundHomeTeam.starting.map((player) => '${player.name}/${player.position}/${player.club}/${player.number}/${player.playerId}').toList()} '
        'awayStarting=${roundAwayTeam.starting.map((player) => '${player.name}/${player.position}/${player.club}/${player.number}/${player.playerId}').toList()}',
      );
    }
    unawaited(_hydratePersistedProjectedScores());
    unawaited(_primeProjectedScores());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_primeVisibleRoundPoints());
    });
    _scheduleDetailCoachMarks();
  }

  @override
  void dispose() {
    _detailCoachRetryTimer?.cancel();
    super.dispose();
  }

  double _displayedActualScoreForTeam(
    _FantasyTeamState team, {
    required bool isHomeTeam,
  }) {
    if (widget.draft.isSoccer) {
      return _fantasyTeamRoundScore(
        team,
        widget.matchup.round,
        isSoccer: true,
        draft: widget.draft,
      );
    }

    final persisted = _persistedKboVisibleTeamScoreForTeam(
      team,
      draft: widget.draft,
      round: widget.matchup.round,
    );
    if (persisted != null) return persisted;

    final initial = isHomeTeam
        ? _initialVisibleHomeScore
        : _initialVisibleAwayScore;
    if (initial != null) return initial;

    return _fantasyTeamRoundScore(
      team,
      widget.matchup.round,
      isSoccer: false,
      draft: widget.draft,
    );
  }

  Future<void> _hydratePersistedProjectedScores() async {
    await _restorePersistedFantasyProjectedScoresCache();
    if (!mounted) return;
    final entry = _persistedFantasyProjectedScoresEntryForRound(
      widget.draft,
      widget.matchup.round,
    );
    if (entry == null ||
        entry.scores.isEmpty ||
        !_hasDisplayableProjectedScoresForMatchup(entry.scores)) {
      return;
    }
    setState(() {
      _projectedScores = Map<String, double>.from(entry.scores);
    });
  }

  Future<void> _primeVisibleRoundPoints() async {
    if (widget.draft.isSoccer) return;
    final now = DateTime.now();
    if (!_kboFantasyRoundHasStarted(widget.draft, widget.matchup.round, now)) {
      return;
    }
    final absoluteRound = _mappedKboRoundForFantasyRound(
      widget.draft,
      widget.matchup.round,
    );
    final uniqueSlots = <String, _PlayerSlot>{};
    for (final team in _matchupTeamsForRound()) {
      for (final player in [...team.starting, ...team.bench]) {
        final slot = player.toPlayerSlot();
        uniqueSlots[_playerSlotIdentity(slot)] = slot;
      }
    }
    if (uniqueSlots.isEmpty) return;
    const batchSize = 2;
    final values = uniqueSlots.values.toList();
    for (var start = 0; start < values.length; start += batchSize) {
      final end = min(start + batchSize, values.length);
      final batch = values.sublist(start, end);
      await Future.wait(
        batch.map(
          (slot) => _loadKboRoundPointsForPlayerShared(
            playerName: slot.name,
            club: _normalizeKboDraftClub(slot.club),
            preferredNumber: slot.number,
            preferredPosition: slot.position,
            forceRefresh: true,
            targetRounds: <int>{absoluteRound},
          ),
        ),
      );
    }
    if (!mounted) return;
    setState(() {});
  }

  void _seedProjectedScoresForFirstPaint() {
    final seededScores = <String, double>{};
    final persistedEntry = _persistedFantasyProjectedScoresEntryForRound(
      widget.draft,
      widget.matchup.round,
    );
    if (persistedEntry != null && persistedEntry.scores.isNotEmpty) {
      seededScores.addAll(persistedEntry.scores);
    }

    for (final slot in _matchupUniquePlayers().values) {
      final hasPersistedScore = widget.draft.isSoccer
          ? seededScores.containsKey(_playerSlotIdentity(slot))
          : _kboProjectionAliasKeysForSlot(slot).any(seededScores.containsKey);
      if (hasPersistedScore) continue;
      final fallbackScore =
          _cachedProjectedFallbackForSlot(
            slot,
            isSoccer: widget.draft.isSoccer,
          ) ??
          _fantasyProjectedSlotScore(slot, isSoccer: widget.draft.isSoccer);
      if (widget.draft.isSoccer) {
        seededScores[_playerSlotIdentity(slot)] = fallbackScore;
      } else {
        _storeKboProjectionValueForSlot(seededScores, slot, fallbackScore);
      }
    }

    if (seededScores.isNotEmpty) {
      _projectedScores = seededScores;
    }
  }

  Future<void> _primeProjectedScores() async {
    if (mounted) {
      setState(() {
        _isLoadingProjectedScores = true;
      });
    } else {
      _isLoadingProjectedScores = true;
    }
    Map<String, double> scores = _projectedScores;
    Map<
      String,
      ({double opportunityFactor, int confirmedStarts, int completedStarts})
    >
    contexts = _pitcherWeeklyProjectionContexts;
    try {
      try {
        final bundle = await _loadProjectedScoresForMatchup();
        scores = bundle.scores;
        if (bundle.pitcherContexts.isNotEmpty) {
          contexts = bundle.pitcherContexts;
        }
      } catch (error, stackTrace) {
        debugPrint('FantasyFixtureDetail projected load failed: $error');
        debugPrint('$stackTrace');
      }

      if (!mounted) return;
      if (kDebugMode) {
        final pitcherSlots = <_PlayerSlot>[
          for (final team in _matchupTeamsForRound())
            for (final player in team.starting)
              if (_isKboPitcherPositionValue(player.position))
                player.toPlayerSlot(),
        ];
        debugPrint(
          'FixtureDetail projected bundle pitchers='
          '${pitcherSlots.map((slot) => '${slot.name}/${slot.club}/${slot.number}/${slot.playerId}').toList()}',
        );
        for (final slot in pitcherSlots) {
          final aliasKeys = _kboProjectionAliasKeysForSlot(slot);
          debugPrint(
            'FixtureDetail projected bundle pitcher=${slot.name} '
            'slotKey=${_playerSlotIdentity(slot)} '
            'aliasKeys=$aliasKeys '
            'scores=${{for (final key in aliasKeys) key: scores[key]}} '
            'contexts=${{for (final key in aliasKeys) key: contexts[key]}}',
          );
        }
      }
      await _restorePersistedFantasyProjectedScoresCache();
      final existingEntry = _persistedFantasyProjectedScoresEntryForRound(
        widget.draft,
        widget.matchup.round,
      );
      final mergedScores = <String, double>{
        ...?existingEntry?.scores,
        ...scores,
      };
      _storePersistedFantasyProjectedScoresEntryForRound(
        widget.draft,
        widget.matchup.round,
        mergedScores,
      );
      unawaited(_persistFantasyProjectedScoresCache());
      if (!mounted) return;
      setState(() {
        _projectedScores = scores;
        _pitcherWeeklyProjectionContexts = contexts;
        _isLoadingProjectedScores = false;
      });
    } finally {
      if (mounted && _isLoadingProjectedScores) {
        setState(() {
          _isLoadingProjectedScores = false;
        });
      } else if (!mounted) {
        _isLoadingProjectedScores = false;
      }
    }
  }

  Future<
    ({
      Map<String, double> scores,
      Map<
        String,
        ({double opportunityFactor, int confirmedStarts, int completedStarts})
      >
      pitcherContexts,
    })
  >
  _loadProjectedScoresForMatchup({
    Map<
      String,
      ({double opportunityFactor, int confirmedStarts, int completedStarts})
    >?
    preloadedPitcherContexts,
  }) async {
    if (widget.draft.isSoccer) {
      await _restorePersistedKLeaguePlayerAptsCache();
      await _restorePersistedKLeaguePlayerRoundPointsCache();
      final leagueData = await _loadCachedKLeagueLeagueData();
      final rawFixtures = _fixtureAsList(leagueData['fixtures']);
      final targetKLeagueRound = _mappedKLeagueRoundForFantasyRound(
        widget.draft,
        widget.matchup.round,
        rawFixtures,
      );
      final teamFormFactors = _teamFormFactorsForProjectedFptsDetail(
        rawFixtures,
        targetKLeagueRound,
      );

      final uniquePlayers = <String, _PlayerSlot>{};
      for (final team in _matchupTeamsForRound()) {
        for (final player in team.roster) {
          final slot = player.toPlayerSlot();
          uniquePlayers[_playerSlotIdentity(slot)] = slot;
        }
      }

      final pending = uniquePlayers.values.where((slot) {
        final cached = _cachedKLeagueRoundPointsForPlayer(
          playerName: slot.name,
          club: _slotClub(slot),
          preferredNumber: slot.number,
        );
        return cached == null;
      }).toList();

      const batchSize = 4;
      for (var start = 0; start < pending.length; start += batchSize) {
        final end = min(start + batchSize, pending.length);
        final batch = pending.sublist(start, end);
        await Future.wait(
          batch.map(
            (slot) => _loadKLeagueRoundPointsForPlayerShared(
              playerName: slot.name,
              club: _slotClub(slot),
              preferredNumber: slot.number,
            ),
          ),
        );
      }

      final projections = <String, double>{};
      for (final slot in uniquePlayers.values) {
        final roundPoints =
            _cachedKLeagueRoundPointsForPlayer(
              playerName: slot.name,
              club: _slotClub(slot),
              preferredNumber: slot.number,
            ) ??
            const <_PlayerRoundPoints>[];
        projections[_playerSlotIdentity(
          slot,
        )] = _projectKLeagueFptsForSlotDetail(
          slot,
          roundPoints,
          targetRound: targetKLeagueRound,
          teamFormFactor: teamFormFactors[_slotClub(slot)] ?? 1.0,
        );
      }
      return (
        scores: projections,
        pitcherContexts:
            const <
              String,
              ({
                double opportunityFactor,
                int confirmedStarts,
                int completedStarts,
              })
            >{},
      );
    }

    final leagueData = await _loadCachedKboLeagueData();
    final rawMatches = _fixtureAsList(leagueData['matches']);
    final targetKboRound = _mappedKboRoundForFantasyRound(
      widget.draft,
      widget.matchup.round,
    );
    final teamFormFactors = _kboTeamFormFactorsForProjectedFptsDetail(
      rawMatches,
      targetKboRound,
    );
    final opponentFormFactors = _kboOpponentFormFactorsForProjectedFptsDetail(
      rawMatches,
      targetKboRound,
      teamFormFactors,
    );

    final uniquePlayers = _matchupUniquePlayers();
    final projectionSourceFuture = _primeKboProjectionSourceDataForSlots(
      uniquePlayers.values,
      targetRound: targetKboRound,
      includeTargetRoundLivePoints: _kboFantasyRoundHasStarted(
        widget.draft,
        widget.matchup.round,
        DateTime.now(),
      ),
    );
    final pitcherContextsFuture = preloadedPitcherContexts?.isNotEmpty == true
        ? Future.value(preloadedPitcherContexts!)
        : _loadKboPitcherWeeklyProjectionContexts(
            uniquePlayers.values,
            rawMatches: rawMatches,
            targetRound: targetKboRound,
          );
    await projectionSourceFuture;
    final pitcherContexts = await pitcherContextsFuture;

    final projections = <String, double>{};
    for (final slot in uniquePlayers.values) {
      final slotIdentity = _playerSlotIdentity(slot);
      final club = _normalizeKboDraftClub(slot.club);
      final roundPoints =
          _cachedKboRoundPointsForPlayer(
            playerName: slot.name,
            club: club,
            preferredNumber: slot.number,
            preferredPosition: slot.position,
          ) ??
          const <_PlayerRoundPoints>[];
      final projected = _projectKboFptsForMatchupDetail(
        slot,
        roundPoints,
        targetRound: targetKboRound,
        teamFormFactor: teamFormFactors[club] ?? 1.0,
        opponentFormFactor: opponentFormFactors[club] ?? 1.0,
        pitcherOpportunityFactor:
            pitcherContexts[slotIdentity]?.opportunityFactor ?? 1.0,
      );
      _storeKboProjectionValueForSlot(projections, slot, projected);
    }
    return (scores: projections, pitcherContexts: pitcherContexts);
  }

  Map<String, double> _teamFormFactorsForProjectedFptsDetail(
    List<dynamic> rawFixtures,
    int targetRound,
  ) {
    final byClub = <String, List<({DateTime date, double points})>>{};
    for (final raw in rawFixtures) {
      final map = _fixtureAsMap(raw);
      final round = _roundNumber(
        _fixtureText(_fixtureAsMap(map['league'])['round']),
      );
      if (round <= 0 || round >= targetRound) continue;
      final fixture = _fixtureAsMap(map['fixture']);
      final status = _fixtureAsMap(fixture['status']);
      if (!_isKLeagueFinalStatus(_fixtureText(status['short']))) continue;
      final teams = _fixtureAsMap(map['teams']);
      final goals = _fixtureAsMap(map['goals']);
      final date =
          DateTime.tryParse(_fixtureText(fixture['date'])) ?? DateTime(1970);
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
      final homeGoals = _readNullableInt(goals['home']) ?? 0;
      final awayGoals = _readNullableInt(goals['away']) ?? 0;
      double homePoints = 0;
      double awayPoints = 0;
      if (homeGoals == awayGoals) {
        homePoints = 1;
        awayPoints = 1;
      } else if (homeGoals > awayGoals) {
        homePoints = 3;
      } else {
        awayPoints = 3;
      }
      if (homeClub.isNotEmpty) {
        byClub.putIfAbsent(homeClub, () => <({DateTime date, double points})>[])
          ..add((date: date, points: homePoints));
      }
      if (awayClub.isNotEmpty) {
        byClub.putIfAbsent(awayClub, () => <({DateTime date, double points})>[])
          ..add((date: date, points: awayPoints));
      }
    }

    final factors = <String, double>{};
    byClub.forEach((club, entries) {
      entries.sort((a, b) => b.date.compareTo(a.date));
      final recent = entries.take(5).toList();
      if (recent.isEmpty) {
        factors[club] = 1.0;
        return;
      }
      final averagePoints =
          recent.fold<double>(0, (total, item) => total + item.points) /
          recent.length;
      factors[club] = (0.85 + (averagePoints / 3.0) * 0.30).clamp(0.85, 1.15);
    });
    return factors;
  }

  double _projectKLeagueFptsForSlotDetail(
    _PlayerSlot slot,
    List<_PlayerRoundPoints> roundPoints, {
    required int targetRound,
    required double teamFormFactor,
  }) {
    final previous =
        roundPoints.where((entry) => entry.round < targetRound).toList()
          ..sort((a, b) => b.round.compareTo(a.round));
    final fallback =
        _cachedKLeaguePlayerApts[_slotAptsKey(slot)] ??
        _fantasyProjectedSlotScore(slot, isSoccer: true);
    if (previous.isEmpty) {
      return (fallback * teamFormFactor).clamp(0.0, 25.0);
    }

    final recent = previous.take(5).toList();
    const weights = <double>[0.34, 0.26, 0.18, 0.14, 0.08];
    var weightedTotal = 0.0;
    var weightTotal = 0.0;
    for (var i = 0; i < recent.length; i++) {
      weightedTotal += recent[i].basePoints * weights[i];
      weightTotal += weights[i];
    }
    final weightedRecent = weightTotal > 0
        ? weightedTotal / weightTotal
        : fallback;
    final seasonApts = _kLeagueAptsFromRoundPoints(previous) ?? fallback;
    final recentTwo = recent.take(2).toList();
    final previousThree = recent.skip(2).take(3).toList();
    final recentTwoAvg = recentTwo.isEmpty
        ? weightedRecent
        : recentTwo.fold<double>(0, (t, e) => t + e.basePoints) /
              recentTwo.length;
    final previousThreeAvg = previousThree.isEmpty
        ? weightedRecent
        : previousThree.fold<double>(0, (t, e) => t + e.basePoints) /
              previousThree.length;
    final trendBonus = (recentTwoAvg - previousThreeAvg) * 0.25;
    final appearanceRate =
        recent.where((entry) => entry.appeared).length / recent.length;
    final consecutiveNoShows = recent
        .take(2)
        .where((entry) => !entry.appeared)
        .length;
    final hadRecentRedCard = recent
        .take(1)
        .any(
          (entry) => entry.details.any(
            (detail) => detail.label == '레드카드' && detail.points < 0,
          ),
        );
    if (hadRecentRedCard) return 0.0;
    final yellowCardCount = recent.fold<double>(0.0, (total, entry) {
      final yellowPenalty = entry.details
          .where((detail) => detail.label == '옐로카드' && detail.points < 0)
          .fold<double>(0.0, (sum, detail) => sum + detail.points.abs());
      return total + yellowPenalty;
    });

    var projected = weightedRecent * 0.70 + seasonApts * 0.30 + trendBonus;
    projected *= teamFormFactor;
    projected *= (0.72 + appearanceRate * 0.28);
    if (consecutiveNoShows >= 2) {
      projected *= 0.82;
    }
    if (yellowCardCount >= 5) {
      projected *= 0.82;
    } else if (yellowCardCount >= 3) {
      projected *= 0.92;
    }
    return projected.clamp(0.0, 25.0);
  }

  Map<String, double> _kboTeamFormFactorsForProjectedFptsDetail(
    List<dynamic> rawMatches,
    int targetRound,
  ) {
    final byClub =
        <
          String,
          List<({DateTime date, double resultPoints, double runDiff})>
        >{};
    for (final raw in rawMatches) {
      final match = _fixtureAsMap(raw);
      final matchDate = DateTime.tryParse('${match['date'] ?? ''}');
      if (matchDate == null) continue;
      final round = _kboFantasyRoundForMatchDate(matchDate);
      if (round <= 0 || round >= targetRound) continue;
      if (!_kboMatchMapHasStarted(match)) continue;
      final homeClub = _normalizeKboDraftClub('${match['home'] ?? ''}');
      final awayClub = _normalizeKboDraftClub('${match['away'] ?? ''}');
      final homeScore = (_readNullableInt(match['homeScore']) ?? 0).toDouble();
      final awayScore = (_readNullableInt(match['awayScore']) ?? 0).toDouble();
      if (homeClub.isEmpty || awayClub.isEmpty) continue;
      final homePoints = homeScore > awayScore
          ? 1.0
          : homeScore == awayScore
          ? 0.5
          : 0.0;
      final awayPoints = awayScore > homeScore
          ? 1.0
          : homeScore == awayScore
          ? 0.5
          : 0.0;
      byClub.putIfAbsent(
        homeClub,
        () => <({DateTime date, double resultPoints, double runDiff})>[],
      )..add((
        date: matchDate,
        resultPoints: homePoints,
        runDiff: homeScore - awayScore,
      ));
      byClub.putIfAbsent(
        awayClub,
        () => <({DateTime date, double resultPoints, double runDiff})>[],
      )..add((
        date: matchDate,
        resultPoints: awayPoints,
        runDiff: awayScore - homeScore,
      ));
    }

    final factors = <String, double>{};
    byClub.forEach((club, entries) {
      entries.sort((a, b) => b.date.compareTo(a.date));
      final recent = entries.take(6).toList();
      if (recent.isEmpty) {
        factors[club] = 1.0;
        return;
      }
      final winRate =
          recent.fold<double>(0.0, (sum, item) => sum + item.resultPoints) /
          recent.length;
      final avgRunDiff =
          recent.fold<double>(0.0, (sum, item) => sum + item.runDiff) /
          recent.length;
      final runDiffBoost = (avgRunDiff / 6.0).clamp(-1.0, 1.0) * 0.07;
      factors[club] = (0.88 + winRate * 0.18 + runDiffBoost).clamp(0.84, 1.16);
    });
    return factors;
  }

  Map<String, double> _kboOpponentFormFactorsForProjectedFptsDetail(
    List<dynamic> rawMatches,
    int targetRound,
    Map<String, double> teamFormFactors,
  ) {
    final opponentsByClub = <String, Set<String>>{};
    for (final raw in rawMatches) {
      final match = _fixtureAsMap(raw);
      final matchDate = DateTime.tryParse('${match['date'] ?? ''}');
      if (matchDate == null) continue;
      final round = _kboFantasyRoundForMatchDate(matchDate);
      if (round != targetRound) continue;
      final homeClub = _normalizeKboDraftClub('${match['home'] ?? ''}');
      final awayClub = _normalizeKboDraftClub('${match['away'] ?? ''}');
      if (homeClub.isEmpty || awayClub.isEmpty) continue;
      opponentsByClub.putIfAbsent(homeClub, () => <String>{}).add(awayClub);
      opponentsByClub.putIfAbsent(awayClub, () => <String>{}).add(homeClub);
    }

    final factors = <String, double>{};
    opponentsByClub.forEach((club, opponents) {
      if (opponents.isEmpty) {
        factors[club] = 1.0;
        return;
      }
      final avgOpponentForm =
          opponents.fold<double>(
            0.0,
            (sum, opponent) => sum + (teamFormFactors[opponent] ?? 1.0),
          ) /
          opponents.length;
      factors[club] = (1.0 - (avgOpponentForm - 1.0) * 0.55).clamp(0.90, 1.10);
    });
    return factors;
  }

  double _projectKboFptsForMatchupDetail(
    _PlayerSlot slot,
    List<_PlayerRoundPoints> roundPoints, {
    required int targetRound,
    required double teamFormFactor,
    required double opponentFormFactor,
    double pitcherOpportunityFactor = 1.0,
  }) {
    final previous =
        roundPoints.where((entry) => entry.round < targetRound).toList()
          ..sort((a, b) => b.round.compareTo(a.round));
    final fallback =
        _kLeagueAptsFromRoundPoints(previous) ??
        _cachedFullSeasonKboAptsForPlayer(
          playerName: slot.name,
          club: _normalizeKboDraftClub(slot.club),
          preferredNumber: slot.number,
          preferredPosition: slot.position,
        ) ??
        _fantasyProjectedSlotScore(slot, isSoccer: false);
    if (previous.isEmpty) {
      return (fallback * teamFormFactor * opponentFormFactor).clamp(0.0, 60.0);
    }

    final recent = previous.take(6).toList();
    const weights = <double>[0.30, 0.24, 0.18, 0.13, 0.09, 0.06];
    var weightedTotal = 0.0;
    var weightTotal = 0.0;
    for (var i = 0; i < recent.length; i++) {
      weightedTotal += recent[i].basePoints * weights[i];
      weightTotal += weights[i];
    }
    final weightedRecent = weightTotal > 0
        ? weightedTotal / weightTotal
        : fallback;
    final seasonApts = _kLeagueAptsFromRoundPoints(previous) ?? fallback;
    final recentTwo = recent.take(2).toList();
    final previousFour = recent.skip(2).take(4).toList();
    final recentTwoAvg = recentTwo.isEmpty
        ? weightedRecent
        : recentTwo.fold<double>(0.0, (sum, entry) => sum + entry.basePoints) /
              recentTwo.length;
    final previousFourAvg = previousFour.isEmpty
        ? weightedRecent
        : previousFour.fold<double>(
                0.0,
                (sum, entry) => sum + entry.basePoints,
              ) /
              previousFour.length;
    final trendBonus = (recentTwoAvg - previousFourAvg) * 0.22;
    final appearanceRate =
        recent.where((entry) => entry.appeared).length / recent.length;
    final startedRate =
        recent.where((entry) => entry.started).length / recent.length;
    final latestMissStreak = recent
        .takeWhile((entry) => !entry.appeared)
        .length;

    var projected = weightedRecent * 0.68 + seasonApts * 0.32 + trendBonus;
    projected *= teamFormFactor;
    projected *= opponentFormFactor;
    projected *= (0.65 + appearanceRate * 0.35);
    if (!_isKboPitcherSlot(slot)) {
      projected *= (0.78 + startedRate * 0.22);
    }
    if (latestMissStreak >= 3) {
      projected *= 0.48;
    } else if (latestMissStreak == 2) {
      projected *= 0.64;
    } else if (latestMissStreak == 1) {
      projected *= 0.84;
    }
    if (_isKboPitcherSlot(slot)) {
      projected *= pitcherOpportunityFactor.clamp(0.7, 1.45);
    }
    return projected.clamp(0.0, 60.0);
  }

  @override
  Widget build(BuildContext context) {
    final palette = _leagueItSurfacePalette(context);
    final roundHomeTeam = _roundHomeTeam;
    final roundAwayTeam = _roundAwayTeam;
    final actualScoreCache = <String, double>{};
    final projectedBaseCache = <String, double>{};
    final projectedScoreCache = <String, double>{};
    final kboRoundProgressCache = <String, double>{};
    final homeScore = _displayedActualScoreForTeam(
      roundHomeTeam,
      isHomeTeam: true,
    );
    final awayScore = _displayedActualScoreForTeam(
      roundAwayTeam,
      isHomeTeam: false,
    );
    final homeRecord = _fantasyFixtureRecordText(
      widget.draft,
      roundHomeTeam.teamName,
      widget.matchup.round,
    );
    final awayRecord = _fantasyFixtureRecordText(
      widget.draft,
      roundAwayTeam.teamName,
      widget.matchup.round,
    );
    final currentUserUid = _currentUserFantasyUid();
    final currentUserTeamName = _currentUserFantasyTeamName(widget.draft);

    bool isCurrentUserTeam(_FantasyTeamState team) =>
        (currentUserUid != null && team.uid == currentUserUid) ||
        (currentUserTeamName != null && team.teamName == currentUserTeamName);
    final displayLeftTeam =
        isCurrentUserTeam(roundAwayTeam) && !isCurrentUserTeam(roundHomeTeam)
        ? roundAwayTeam
        : roundHomeTeam;
    final isDisplayLeftHome = identical(displayLeftTeam, roundHomeTeam);
    final displayRightTeam = isDisplayLeftHome ? roundAwayTeam : roundHomeTeam;
    final displayLeftScore = isDisplayLeftHome ? homeScore : awayScore;
    final displayRightScore = identical(displayRightTeam, roundAwayTeam)
        ? awayScore
        : homeScore;
    final displayLeftRecord = isDisplayLeftHome ? homeRecord : awayRecord;
    final displayRightRecord = identical(displayRightTeam, roundAwayTeam)
        ? awayRecord
        : homeRecord;

    PlayerOwnership ownershipForTeam(_FantasyTeamState team) =>
        isCurrentUserTeam(team)
        ? PlayerOwnership.myTeam
        : PlayerOwnership.otherTeam;

    double scoreForPlayer(_FantasyTeamState team, _FantasyTeamPlayer player) =>
        actualScoreCache.putIfAbsent(
          '${team.uid}|${team.teamName}|${_fantasyTeamPlayerIdentity(player)}',
          () => _fantasyPlayerRoundScore(
            player,
            widget.matchup.round,
            isSoccer: widget.draft.isSoccer,
            draft: widget.draft,
            team: team,
          ),
        );

    bool isCaptainForTeam(_FantasyTeamState team, _PlayerSlot slot) {
      final playerId = _playerSlotIdentity(slot);
      if (team.captainPlayerId?.trim().isNotEmpty == true) {
        return team.captainPlayerId == playerId;
      }
      return team.captainName == slot.name;
    }

    double projectedBaseForSlot(_PlayerSlot slot) {
      final slotKey = _playerSlotIdentity(slot);
      return projectedBaseCache.putIfAbsent(slotKey, () {
        final aliasKeys = _kboProjectionAliasKeysForSlot(slot);
        final aliasedProjected = _kboProjectionAliasKeysForSlot(slot)
            .map((key) => _projectedScores[key])
            .whereType<double?>()
            .firstWhere((value) => value != null, orElse: () => null);
        final cachedFallback = _cachedProjectedFallbackForSlot(
          slot,
          isSoccer: widget.draft.isSoccer,
        );
        final base =
            aliasedProjected ??
            cachedFallback ??
            (widget.draft.isSoccer
                ? _fantasyProjectedSlotScore(slot, isSoccer: true)
                : 0.0);
        if (widget.draft.isSoccer) return base;

        final actual = _fantasyPlayerRoundScore(
          _FantasyTeamPlayer(
            name: slot.name,
            position: slot.position,
            score: slot.score,
            club: slot.club,
            number: slot.number,
            playerId: slot.playerId,
          ),
          widget.matchup.round,
          isSoccer: widget.draft.isSoccer,
          draft: widget.draft,
        );
        final pitcherContext = _kboProjectionAliasKeysForSlot(slot)
            .map((key) => _pitcherWeeklyProjectionContexts[key])
            .whereType<
              ({
                double opportunityFactor,
                int confirmedStarts,
                int completedStarts,
              })?
            >()
            .firstWhere((value) => value != null, orElse: () => null);
        final confirmedWeeklyStarts = pitcherContext?.confirmedStarts ?? 0;
        final completedWeeklyStarts = max(
          pitcherContext?.completedStarts ?? 0,
          actual.abs() >= 0.001 ? 1 : 0,
        );

        final leagueData = _cachedKboLeagueData;
        final rawMatches = _fixtureAsList(leagueData?['matches']);
        if (rawMatches.isEmpty) {
          if (_isKboPitcherSlot(slot) &&
              confirmedWeeklyStarts > completedWeeklyStarts &&
              actual.abs() >= 0.001) {
            return _liveAdjustedKboPitcherProjectedBaseScore(
              baseProjection: base,
              actualScore: actual,
              roundProgress: 0.0,
              confirmedWeeklyStarts: confirmedWeeklyStarts,
              completedWeeklyStarts: completedWeeklyStarts,
            );
          }
          return base;
        }

        final now = DateTime.now();
        final fantasyRound = widget.matchup.round;
        if (!_kboFantasyRoundHasStarted(widget.draft, fantasyRound, now)) {
          return base;
        }
        final currentFantasyRound = _currentFantasyRoundAt(widget.draft, now);
        if (fantasyRound < currentFantasyRound ||
            _kboFantasyRoundAllGamesTerminal(
              widget.draft,
              fantasyRound,
              now: now,
            )) {
          return _fantasyPlayerRoundScore(
            _FantasyTeamPlayer(
              name: slot.name,
              position: slot.position,
              score: slot.score,
              club: slot.club,
              number: slot.number,
              playerId: slot.playerId,
            ),
            fantasyRound,
            isSoccer: widget.draft.isSoccer,
            draft: widget.draft,
          );
        }

        final absoluteRound = _mappedKboRoundForFantasyRound(
          widget.draft,
          fantasyRound,
        );
        final cachedRoundPoints = _cachedKboRoundPointsForPlayer(
          playerName: slot.name,
          club: _normalizeKboDraftClub(slot.club),
          preferredNumber: slot.number,
          preferredPosition: slot.position,
        );
        final currentRoundEntry = cachedRoundPoints
            ?.cast<_PlayerRoundPoints?>()
            .firstWhere(
              (entry) => entry?.round == absoluteRound,
              orElse: () => null,
            );
        if (_isKboPitcherSlot(slot) &&
            !((currentRoundEntry?.details.isNotEmpty ?? false) ||
                (currentRoundEntry?.basePoints ?? 0.0) != 0.0) &&
            actual.abs() < 0.001) {
          return base;
        }
        final leagueRound = absoluteRound;
        final normalizedClub = _normalizeKboDraftClub(slot.club);
        final progress = kboRoundProgressCache.putIfAbsent(
          normalizedClub,
          () => _kboRoundProgressForClubFromMatches(
            rawMatches,
            club: normalizedClub,
            leagueRound: leagueRound,
            now: now,
          ),
        );
        if (kDebugMode && _isKboPitcherSlot(slot)) {
          debugPrint(
            'FixtureDetail projectedBase pitcher=${slot.name} '
            'slotKey=$slotKey '
            'aliasKeys=$aliasKeys '
            'aliasedProjected=$aliasedProjected '
            'base=$base '
            'actual=$actual '
            'confirmed=$confirmedWeeklyStarts '
            'completed=$completedWeeklyStarts '
            'progress=$progress '
            'club=${slot.club} '
            'normalizedClub=$normalizedClub '
            'rawMatches=${rawMatches.length}',
          );
        }
        if (_isKboPitcherSlot(slot)) {
          return _liveAdjustedKboPitcherProjectedBaseScore(
            baseProjection: base,
            actualScore: actual,
            roundProgress: progress,
            confirmedWeeklyStarts: confirmedWeeklyStarts,
            completedWeeklyStarts: completedWeeklyStarts,
          );
        }
        return _liveAdjustedKboProjectedBaseScore(
          baseProjection: base,
          actualScore: actual,
          roundProgress: progress,
        );
      });
    }

    double projectedScoreForSlot(_PlayerSlot slot, {_FantasyTeamState? team}) {
      final slotKey =
          '${team?.uid ?? ''}|${team?.teamName ?? ''}|${_playerSlotIdentity(slot)}';
      return projectedScoreCache.putIfAbsent(slotKey, () {
        final base = projectedBaseForSlot(slot);
        return team != null && isCaptainForTeam(team, slot) ? base * 2 : base;
      });
    }

    String formatBadgeScore(double value) {
      final rounded = value.toStringAsFixed(1);
      if (rounded.endsWith('.0')) {
        return rounded.substring(0, rounded.length - 2);
      }
      return rounded;
    }

    double projectedTeamScore(_FantasyTeamState team) {
      if (!widget.draft.isSoccer) {
        final now = DateTime.now();
        final fantasyRound = widget.matchup.round;
        final actualScore = _displayedActualScoreForTeam(
          team,
          isHomeTeam: identical(team, roundHomeTeam),
        );
        if (_kboFantasyTeamRosterRoundComplete(
          widget.draft,
          team,
          fantasyRound,
          now: now,
        )) {
          return actualScore;
        }
        final rosterPlayers = _fantasyProjectionRosterPlayers(team);
        if (rosterPlayers.isNotEmpty) {
          final projectedStarting = _buildBaseballStartingFromRoster(
            rosterPlayers,
            positionOf: (player) => player.position,
            scoreOf: (player) {
              final projected = projectedBaseForSlot(player.toPlayerSlot());
              final current = _fantasyKboBasePlayerRoundScore(
                player,
                draft: widget.draft,
                round: fantasyRound,
              );
              return ((projected - current) * 1000).round();
            },
            identityOf: (player) => _fantasyTeamPlayerIdentity(player),
          );
          if (projectedStarting.isNotEmpty) {
            final projectedStartingIds = projectedStarting
                .map(_fantasyTeamPlayerIdentity)
                .toSet();
            final projectedTeam = _FantasyTeamState(
              uid: team.uid,
              teamName: team.teamName,
              roster: rosterPlayers,
              starting: projectedStarting,
              bench: rosterPlayers
                  .where(
                    (player) => !projectedStartingIds.contains(
                      _fantasyTeamPlayerIdentity(player),
                    ),
                  )
                  .toList(growable: false),
              captainName: team.captainName,
              viceCaptainName: team.viceCaptainName,
              captainPlayerId: team.captainPlayerId,
              viceCaptainPlayerId: team.viceCaptainPlayerId,
              kboRoundScoreStates: team.kboRoundScoreStates,
            );
            return actualScore +
                projectedTeam.starting.fold<double>(0.0, (total, player) {
                  final slot = player.toPlayerSlot();
                  final projected = projectedScoreForSlot(
                    slot,
                    team: projectedTeam,
                  );
                  final current = _fantasyKboDisplayedPlayerRoundScore(
                    player,
                    draft: widget.draft,
                    round: fantasyRound,
                    team: projectedTeam,
                  );
                  return total + (projected - current);
                });
          }
        }
      }
      return team.starting.fold<double>(
        0.0,
        (total, player) =>
            total + projectedScoreForSlot(player.toPlayerSlot(), team: team),
      );
    }

    double projectedMatchupTeamScore(
      _FantasyTeamState team, {
      required double actualScore,
    }) {
      if (!widget.draft.isSoccer) {
        final now = DateTime.now();
        if (widget.matchup.round < _currentFantasyRoundAt(widget.draft, now) ||
            _kboFantasyRoundAllGamesTerminal(
              widget.draft,
              widget.matchup.round,
              now: now,
            ) ||
            _kboFantasyTeamRosterRoundComplete(
              widget.draft,
              team,
              widget.matchup.round,
              now: now,
            ) ||
            _shouldFreezeUnlockedKboRoundScore(
              widget.draft,
              widget.matchup.round,
              now: now,
            )) {
          return actualScore;
        }
      }
      return projectedTeamScore(team);
    }

    double matchupWinRatio({
      required double myActual,
      required double opponentActual,
      required double myProjected,
      required double opponentProjected,
    }) {
      final now = DateTime.now();
      final currentRound = _currentFantasyRoundAt(widget.draft, now);
      final finalized = widget.matchup.round < currentRound
          ? true
          : widget.draft.isSoccer
          ? (_fantasySoccerRoundScoreSnapshotFor(
                  widget.draft,
                  widget.matchup.round,
                )?.finalized ==
                true)
          : _kboFantasyRoundAllGamesTerminal(
                  widget.draft,
                  widget.matchup.round,
                  now: now,
                ) ||
                _shouldFreezeUnlockedKboRoundScore(
                  widget.draft,
                  widget.matchup.round,
                  now: now,
                );
      final homeScore = finalized ? myActual : myProjected;
      final awayScore = finalized ? opponentActual : opponentProjected;
      if (finalized) {
        if ((homeScore - awayScore).abs() < 0.0001) return 0.5;
        return homeScore > awayScore ? 1.0 : 0.0;
      }
      final total = homeScore + awayScore;
      return total <= 0 ? 0.5 : homeScore / total;
    }

    double scoreForSlot(_PlayerSlot slot) {
      for (final team in [roundHomeTeam, roundAwayTeam]) {
        for (final player in team.roster) {
          final playerSlot = player.toPlayerSlot();
          if (_playerSlotIdentity(playerSlot) != _playerSlotIdentity(slot)) {
            continue;
          }
          return scoreForPlayer(team, player);
        }
      }
      return slot.score.toDouble();
    }

    Future<void> openProfile(
      _PlayerSlot slot,
      PlayerOwnership ownership,
    ) async {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PlayerProfilePage(
            name: slot.name,
            ownership: ownership,
            metaOverride: _DocPlayerMeta(
              position: slot.position,
              club: slot.club,
              number: slot.number,
            ),
          ),
        ),
      );
      if (!mounted) return;
      setState(() {});
    }

    List<_Player> rowsFromTeam(_FantasyTeamState team) {
      _PlayerSlot slotFrom(_FantasyTeamPlayer player) {
        final slot = player.toPlayerSlot();
        return _PlayerSlot(
          name: slot.name,
          score: scoreForPlayer(team, player).round(),
          position: slot.position,
          club: slot.club,
          number: slot.number,
          playerId: slot.playerId,
        );
      }

      final gk = team.starting
          .where((p) => p.position == 'GK')
          .take(1)
          .toList();
      final dfs = team.starting.where((p) => p.position == 'DF').toList();
      final mfs = team.starting.where((p) => p.position == 'MF').toList();
      final fws = team.starting.where((p) => p.position == 'FW').toList();
      return [
        _Player(slots: gk.map(slotFrom).toList()),
        _Player(slots: dfs.map(slotFrom).toList()),
        _Player(slots: mfs.map(slotFrom).toList()),
        _Player(slots: fws.map(slotFrom).toList()),
      ];
    }

    Widget buildBenchColumn(_FantasyTeamState team) {
      final ownership = ownershipForTeam(team);
      final benchPlayers = team.bench.toList();

      double benchNameFontSize(String name) {
        if (name.length >= 10) return 10.5;
        if (name.length >= 8) return 11.5;
        if (name.length >= 6) return 12.5;
        return 14.0;
      }

      double benchNameRowFontSize(String value) {
        if (value.length >= 14) return 10.8;
        if (value.length >= 11) return 11.6;
        return 12.8;
      }

      double benchClubFontSize(String value) {
        if (value.length >= 8) return 9.8;
        if (value.length >= 6) return 10.4;
        return 11.0;
      }

      return Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              team.teamName,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: palette.ink,
              ),
            ),
            const SizedBox(height: 8),
            if (benchPlayers.isEmpty)
              Text(
                '교체명단이 없습니다.',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: palette.mutedInk,
                ),
              )
            else
              ...benchPlayers.map((player) {
                final slot = player.toPlayerSlot();
                final displayClub = _displayFantasyClubName(
                  slot.club,
                  isSoccer: widget.draft.isSoccer,
                );
                final nameRowLabel = '${slot.name} · ${slot.position}';
                final projected = projectedScoreForSlot(slot, team: team);
                final actual = scoreForPlayer(team, player);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      unawaited(openProfile(slot, ownership));
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: palette.tileSurface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: palette.cardBorder),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  nameRowLabel,
                                  maxLines: 1,
                                  softWrap: false,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: benchNameRowFontSize(
                                      nameRowLabel,
                                    ),
                                    fontWeight: FontWeight.w800,
                                    height: 1.1,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        displayClub,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        softWrap: false,
                                        style: TextStyle(
                                          fontSize: benchClubFontSize(
                                            displayClub,
                                          ),
                                          fontWeight: FontWeight.w700,
                                          color: palette.mutedInk,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      projected.toStringAsFixed(1),
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: palette.mutedInk,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            width: 38,
                            child: Text(
                              actual.toStringAsFixed(1),
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                color: palette.ink,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
          ],
        ),
      );
    }

    Widget buildStartingMatchupCell(
      _FantasyTeamPlayer? player,
      _FantasyTeamState team,
    ) {
      if (player == null) {
        return Container(
          height: 68,
          decoration: BoxDecoration(
            color: palette.tileSurface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: palette.cardBorder),
          ),
          alignment: Alignment.center,
          child: const Text(
            '선수 없음',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF98A2B3),
            ),
          ),
        );
      }

      final slot = player.toPlayerSlot();
      final projected = projectedScoreForSlot(slot, team: team);
      final actual = scoreForPlayer(team, player);
      return InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          unawaited(openProfile(slot, ownershipForTeam(team)));
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: palette.fieldFill,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: palette.cardBorder),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      slot.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: palette.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      projected.toStringAsFixed(1),
                      style: TextStyle(
                        fontSize: 13,
                        color: palette.mutedInk,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  color: Color(0xFFE9F0FF),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  formatBadgeScore(actual),
                  style: const TextStyle(
                    color: Color(0xFF2D6DFF),
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    Widget buildBaseballStartingMatchup() {
      final leftMap = _buildBaseballFieldPlayerMap(displayLeftTeam.starting);
      final rightMap = _buildBaseballFieldPlayerMap(displayRightTeam.starting);
      final rows = _baseballMatchupPositionRowOrder
          .where((label) => leftMap[label] != null || rightMap[label] != null)
          .toList();
      final header = Row(
        children: [
          Expanded(
            child: Text(
              displayLeftTeam.teamName,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(
            width: 56,
            child: Center(
              child: Text(
                '포지션',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF667085),
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ),
          Expanded(
            child: Text(
              displayRightTeam.teamName,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      );
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: palette.fieldFill,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: palette.cardBorder),
        ),
        child: Column(
          children: [
            _buildDetailCoachMark(
              showcaseKey: _detailLineupShowcaseKey,
              title: '선발 매치업',
              description:
                  '포지션별로 좌우 선발 선수를 비교합니다. 원형 배지는 실제 Fpts, 이름 아래 숫자는 예상 Fpts입니다.',
              targetBorderRadius: BorderRadius.circular(14),
              enableAutoScroll: true,
              scrollAlignment: 0.42,
              child: header,
            ),
            const SizedBox(height: 10),
            for (var i = 0; i < rows.length; i++) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: buildStartingMatchupCell(
                      leftMap[rows[i]],
                      displayLeftTeam,
                    ),
                  ),
                  SizedBox(
                    width: 56,
                    child: Center(
                      child: Text(
                        rows[i],
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF475467),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: buildStartingMatchupCell(
                      rightMap[rows[i]],
                      displayRightTeam,
                    ),
                  ),
                ],
              ),
              if (i != rows.length - 1) const SizedBox(height: 10),
            ],
          ],
        ),
      );
    }

    final lineup = _LineupData(
      home: rowsFromTeam(displayLeftTeam),
      away: rowsFromTeam(displayRightTeam).reversed.toList(),
      homeScore: displayLeftScore.round(),
      awayScore: displayRightScore.round(),
      homeFormation: '',
      awayFormation: '',
    );
    final displayLeftProjected = projectedMatchupTeamScore(
      displayLeftTeam,
      actualScore: displayLeftScore,
    );
    final displayRightProjected = projectedMatchupTeamScore(
      displayRightTeam,
      actualScore: displayRightScore,
    );
    final projectedHomeRatio =
        _forcedKboLeadingWinRatio(
          draft: widget.draft,
          fantasyRound: widget.matchup.round,
          myTeam: displayLeftTeam,
          opponentTeam: displayRightTeam,
          myActual: displayLeftScore,
          opponentActual: displayRightScore,
        ) ??
        matchupWinRatio(
          myActual: displayLeftScore,
          opponentActual: displayRightScore,
          myProjected: displayLeftProjected,
          opponentProjected: displayRightProjected,
        );

    return _OverlayScaffold(
      isMyPageOpen: _isMyPageOpen,
      onToggleMyPage: _toggleMyPage,
      onHelpTap: _replayDetailCoachMarks,
      title: 'LeagueIt',
      showSearch: false,
      wrapHelpButton: (context, child) => child,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildDetailCoachMark(
              showcaseKey: _detailSummaryShowcaseKey,
              title: '매치업 요약',
              description: '현재 점수, 예상 Fpts, 팀 기록, 승리 확률을 여기서 한 번에 확인합니다.',
              targetBorderRadius: BorderRadius.circular(24),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: palette.fieldFill,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: palette.cardBorder),
                ),
                child: Column(
                  children: [
                    Text(
                      'Round ${widget.matchup.round}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: palette.mutedInk,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${_formatFantasyFixtureScore(displayLeftScore)} : ${_formatFantasyFixtureScore(displayRightScore)}',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        color: palette.ink,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (_isLoadingProjectedScores && _projectedScores.isEmpty)
                      _buildProjectedScoresLoadingNotice()
                    else
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              displayLeftProjected.toStringAsFixed(1),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: palette.mutedInk,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 66,
                            child: Text(
                              '예상\nFpts',
                              maxLines: 2,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11,
                                height: 1.2,
                                color: palette.mutedInk,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              displayRightProjected.toStringAsFixed(1),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF6D6D6D),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              Text(
                                displayLeftTeam.teamName,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                displayLeftRecord,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: palette.mutedInk,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            children: [
                              Text(
                                displayRightTeam.teamName,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                displayRightRecord,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: palette.mutedInk,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_isLoadingProjectedScores && _projectedScores.isEmpty)
                      Text(
                        '승리 확률 계산 중...',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: palette.mutedInk,
                          fontWeight: FontWeight.w700,
                        ),
                      )
                    else ...[
                      Row(
                        children: [
                          Text(
                            '${(projectedHomeRatio * 100).round()}%',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              '승리 확률',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: palette.mutedInk,
                              ),
                            ),
                          ),
                          Text(
                            '${((1 - projectedHomeRatio) * 100).round()}%',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _WinBar(homeRatio: projectedHomeRatio.clamp(0.0, 1.0)),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (widget.draft.isSoccer)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: palette.fieldFill,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: palette.cardBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailCoachMark(
                      showcaseKey: _detailLineupShowcaseKey,
                      title: '선발 라인업',
                      description:
                          '이 구역에서 선발 선수들의 실제 Fpts와 예상 Fpts를 비교하고, 선수를 탭해 상세 정보를 볼 수 있습니다.',
                      targetBorderRadius: BorderRadius.circular(12),
                      enableAutoScroll: true,
                      scrollAlignment: 0.42,
                      child: const Text(
                        'Starting XI',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _LineupField(
                      lineup: lineup,
                      isSoccer: true,
                      homeRecord: displayLeftRecord,
                      awayRecord: displayRightRecord,
                      scoreForSlot: projectedScoreForSlot,
                      onPlayerTap: (slot) {
                        for (final team in [
                          displayLeftTeam,
                          displayRightTeam,
                        ]) {
                          for (final player in team.roster) {
                            final playerSlot = player.toPlayerSlot();
                            if (_playerSlotIdentity(playerSlot) !=
                                _playerSlotIdentity(slot)) {
                              continue;
                            }
                            unawaited(
                              openProfile(slot, ownershipForTeam(team)),
                            );
                            return;
                          }
                        }
                      },
                    ),
                  ],
                ),
              )
            else
              buildBaseballStartingMatchup(),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: palette.fieldFill,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: palette.cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailCoachMark(
                    showcaseKey: _detailBenchShowcaseKey,
                    title: '교체 명단',
                    description: '벤치 선수들의 예상 Fpts와 실제 반영값도 여기서 함께 비교할 수 있습니다.',
                    targetBorderRadius: BorderRadius.circular(12),
                    enableAutoScroll: true,
                    scrollAlignment: 0.5,
                    child: Text(
                      widget.draft.isSoccer ? 'Bench' : '교체명단',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        buildBenchColumn(displayLeftTeam),
                        Container(
                          width: 1,
                          margin: const EdgeInsets.symmetric(horizontal: 14),
                          color: palette.cardBorder,
                        ),
                        buildBenchColumn(displayRightTeam),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FantasyNotificationPopup extends StatelessWidget {
  final List<_FantasyNotificationEntry> entries;
  final ValueChanged<_FantasyNotificationEntry>? onTapEntry;

  const _FantasyNotificationPopup({required this.entries, this.onTapEntry});

  IconData _iconForKind(String kind) {
    switch (kind) {
      case 'fpts':
        return Icons.sports_score_outlined;
      case 'roster_lock_soon':
        return Icons.schedule_rounded;
      case 'roster_lock':
        return Icons.lock_outline_rounded;
      case 'roster_unlock':
        return Icons.lock_open_rounded;
      case 'trade_request':
        return Icons.swap_horiz_rounded;
      default:
        return Icons.notifications_none;
    }
  }

  Color _accentForEntry(_FantasyNotificationEntry entry) {
    if (entry.kind == 'trade_request') return const Color(0xFF2E6BFF);
    if (entry.kind == 'fpts') {
      return entry.isSoccer ? const Color(0xFF16A34A) : const Color(0xFF0F766E);
    }
    if (entry.kind == 'roster_lock_soon') return const Color(0xFFCA8A04);
    return const Color(0xFF667085);
  }

  @override
  Widget build(BuildContext context) {
    final palette = _leagueItSurfacePalette(context);
    return Container(
      width: 320,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.fieldFill,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.cardBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '알림',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: palette.ink,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 12),
          if (entries.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(
                child: Text(
                  '받은 알림이 없습니다.',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: palette.mutedInk,
                  ),
                ),
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 360),
              child: SingleChildScrollView(
                child: Column(
                  children: entries.map((entry) {
                    final accent = _accentForEntry(entry);
                    final plainTitle = _notificationCenterPlainText(
                      entry.title,
                    );
                    final plainMessage = _notificationCenterPlainText(
                      entry.message,
                    );
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: onTapEntry == null
                            ? null
                            : () => onTapEntry!(entry),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: palette.tileSurface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: palette.cardBorder),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: accent.withOpacity(0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  _iconForKind(entry.kind),
                                  color: accent,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      plainTitle,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w900,
                                        color: palette.ink,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      plainMessage,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: palette.mutedInk,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      _kstMonthDayTimeLabel(entry.createdAt),
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF98A2B3),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FantasyNotificationCenterPage extends StatefulWidget {
  final List<_FantasyNotificationEntry> entries;

  const _FantasyNotificationCenterPage({required this.entries});

  @override
  State<_FantasyNotificationCenterPage> createState() =>
      _FantasyNotificationCenterPageState();
}

class _FantasyNotificationCenterPageState
    extends State<_FantasyNotificationCenterPage> {
  bool _isMyPageOpen = false;

  void _toggleMyPage() => setState(() => _isMyPageOpen = !_isMyPageOpen);

  IconData _iconForKind(String kind) {
    switch (kind) {
      case 'fpts':
        return Icons.sports_score_outlined;
      case 'roster_lock_soon':
        return Icons.schedule_rounded;
      case 'roster_lock':
        return Icons.lock_outline_rounded;
      case 'roster_unlock':
        return Icons.lock_open_rounded;
      case 'trade_request':
        return Icons.swap_horiz_rounded;
      default:
        return Icons.notifications_none;
    }
  }

  Color _accentForEntry(_FantasyNotificationEntry entry) {
    if (entry.kind == 'trade_request') return const Color(0xFF2E6BFF);
    if (entry.kind == 'fpts') {
      return entry.isSoccer ? const Color(0xFF16A34A) : const Color(0xFF0F766E);
    }
    if (entry.kind == 'roster_lock_soon') return const Color(0xFFCA8A04);
    return const Color(0xFF667085);
  }

  @override
  Widget build(BuildContext context) {
    final palette = _leagueItSurfacePalette(context);
    final entries = widget.entries;
    return _OverlayScaffold(
      isMyPageOpen: _isMyPageOpen,
      onToggleMyPage: _toggleMyPage,
      title: 'LeagueIt',
      showSearch: false,
      child: entries.isEmpty
          ? const Center(
              child: Text(
                '표시할 알림이 없습니다.',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: entries.length + 1,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: EdgeInsets.only(bottom: 4),
                    child: Text(
                      '알림 센터',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: palette.ink,
                      ),
                    ),
                  );
                }
                final entry = entries[index - 1];
                final accent = _accentForEntry(entry);
                final plainTitle = _notificationCenterPlainText(entry.title);
                final plainMessage = _notificationCenterPlainText(
                  entry.message,
                );
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: palette.fieldFill,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: palette.cardBorder),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: accent.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(_iconForKind(entry.kind), color: accent),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    plainTitle,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900,
                                      color: palette.ink,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: accent.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    entry.isSoccer ? 'K리그' : 'KBO',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: accent,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              entry.leagueName,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: palette.mutedInk,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              plainMessage,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF344054),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _kstMonthDayTimeLabel(entry.createdAt),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF98A2B3),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

_PlayerSlot _tradePlayerSlotFromMap(Map<String, dynamic> map) {
  final score = (map['score'] as num?)?.toDouble() ?? 0.0;
  return _PlayerSlot(
    name: '${map['name'] ?? ''}'.trim(),
    position: '${map['position'] ?? ''}'.trim(),
    club: '${map['club'] ?? ''}'.trim(),
    number: _readNullableInt(map['number']) ?? 0,
    playerId: '${map['playerId'] ?? ''}'.trim(),
    score: score.round(),
  );
}

class _TradeRequestDetailPage extends StatefulWidget {
  final _JoinedDraft draft;
  final String requestId;

  const _TradeRequestDetailPage({required this.draft, required this.requestId});

  @override
  State<_TradeRequestDetailPage> createState() =>
      _TradeRequestDetailPageState();
}

class _TradeRequestDetailPageState extends State<_TradeRequestDetailPage> {
  bool _isMyPageOpen = false;
  bool _isLoading = true;
  bool _isSubmitting = false;
  Map<String, dynamic>? _request;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_loadRequest());
  }

  void _toggleMyPage() => setState(() => _isMyPageOpen = !_isMyPageOpen);

  _FantasyTeamState? _teamForParticipant(String uid, String teamName) {
    for (final team in widget.draft.fantasyTeams) {
      if (uid.isNotEmpty && team.uid == uid) return team;
      if (team.teamName == teamName) return team;
    }
    return null;
  }

  List<_FantasyTeamPlayer> _resolveTradePlayersFromRoster(
    _FantasyTeamState team,
    List<dynamic> requested,
  ) {
    final remaining = [...team.roster];
    final resolved = <_FantasyTeamPlayer>[];
    for (final raw in requested) {
      final map = _fixtureAsMap(raw);
      final requestedId = '${map['playerId'] ?? ''}'.trim();
      final requestedName = '${map['name'] ?? ''}'.trim();
      final requestedClub = _normalizeKboDraftClub('${map['club'] ?? ''}');
      final requestedNumber = _readNullableInt(map['number']) ?? 0;
      final index = remaining.indexWhere((player) {
        if (requestedId.isNotEmpty &&
            _fantasyTeamPlayerIdentity(player) == requestedId) {
          return true;
        }
        if (player.name != requestedName) return false;
        final sameClub =
            requestedClub.isEmpty ||
            _normalizeKboDraftClub(player.club) == requestedClub;
        final sameNumber =
            requestedNumber <= 0 || player.number == requestedNumber;
        return sameClub && sameNumber;
      });
      if (index < 0) continue;
      resolved.add(remaining.removeAt(index));
    }
    return resolved;
  }

  List<_FantasyTeamPlayer> _nextRosterAfterTrade(
    List<_FantasyTeamPlayer> roster,
    List<_FantasyTeamPlayer> outgoing,
    List<_FantasyTeamPlayer> incoming,
  ) {
    final outgoingIds = outgoing.map(_fantasyTeamPlayerIdentity).toSet();
    return [
      ...roster.where(
        (player) => !outgoingIds.contains(_fantasyTeamPlayerIdentity(player)),
      ),
      ...incoming,
    ];
  }

  Future<void> _primeKboRoundPointsForTradePlayers(
    Iterable<_FantasyTeamPlayer> players,
  ) async {
    final unique = <String, _FantasyTeamPlayer>{};
    for (final player in players) {
      unique[_fantasyTeamPlayerIdentity(player)] = player;
    }
    const batchSize = 2;
    final values = unique.values.toList();
    for (var start = 0; start < values.length; start += batchSize) {
      final end = min(start + batchSize, values.length);
      final batch = values.sublist(start, end);
      await Future.wait(
        batch.map(
          (player) => _loadKboRoundPointsForPlayerShared(
            playerName: player.name,
            club: _normalizeKboDraftClub(player.club),
            preferredNumber: player.number,
            preferredPosition: player.position,
          ),
        ),
      );
    }
  }

  Future<List<_KboFantasyRoundScoreState>> _updatedTradeKboRoundScoreStates({
    required _FantasyTeamState existingTeam,
    required _FantasyTeamState nextTeam,
  }) async {
    final draft = widget.draft;
    final round = _currentFantasyRoundAt(draft, DateTime.now());
    if (round <= 0 ||
        !_kboFantasyRoundHasStarted(draft, round, DateTime.now())) {
      return existingTeam.kboRoundScoreStates;
    }
    await _loadCachedKboLeagueData();
    await _primeKboRoundPointsForTradePlayers([
      ...existingTeam.starting,
      ...nextTeam.starting,
    ]);
    final bankedScore = _fantasyTeamRoundScore(
      existingTeam,
      round,
      isSoccer: false,
      draft: draft,
    );
    final existingState = _kboRoundScoreStateForTeam(existingTeam, round);
    final nextState = _KboFantasyRoundScoreState(
      round: round,
      bankedScore: bankedScore,
      starterBaselines: {
        for (final player in nextTeam.starting)
          _fantasyTeamPlayerIdentity(
            player,
          ): _fantasyKboDisplayedPlayerRoundScore(
            player,
            draft: draft,
            round: round,
            team: nextTeam,
          ),
      },
      starterPlayers: nextTeam.starting,
      doubledPlayerId: _effectiveCaptainDoublePlayerIdForKboTeam(
        nextTeam,
        draft: draft,
        round: round,
      ),
      updatedAt: DateTime.now().toUtc(),
      unlockedScoreSnapshot: existingState?.unlockedScoreSnapshot,
      unlockedAt: existingState?.unlockedAt,
    );
    final merged = [
      for (final state in existingTeam.kboRoundScoreStates)
        if (state.round != round) state,
      nextState,
    ]..sort((a, b) => a.round.compareTo(b.round));
    return merged;
  }

  Future<Map<String, List<Map<String, dynamic>>>?>
  _kboRoundScoreStatesByTeam() async {
    if (widget.draft.isSoccer || _request == null) return null;
    final request = _request!;
    final fromUid = '${request['fromUid'] ?? ''}'.trim();
    final toUid = '${request['toUid'] ?? ''}'.trim();
    final fromTeamName = '${request['fromTeamName'] ?? ''}'.trim();
    final toTeamName = '${request['toTeamName'] ?? ''}'.trim();
    final fromTeam = _teamForParticipant(fromUid, fromTeamName);
    final toTeam = _teamForParticipant(toUid, toTeamName);
    if (fromTeam == null || toTeam == null) return null;

    final fromPlayers = _resolveTradePlayersFromRoster(
      fromTeam,
      request['fromPlayers'] as List<dynamic>? ?? const [],
    );
    final toPlayers = _resolveTradePlayersFromRoster(
      toTeam,
      request['toPlayers'] as List<dynamic>? ?? const [],
    );
    final nextFromTeam = _normalizeBaseballFantasyTeam(
      _FantasyTeamState(
        uid: fromTeam.uid,
        teamName: fromTeam.teamName,
        roster: _nextRosterAfterTrade(fromTeam.roster, fromPlayers, toPlayers),
        starting: fromTeam.starting,
        bench: fromTeam.bench,
        captainName: fromTeam.captainName,
        viceCaptainName: fromTeam.viceCaptainName,
        captainPlayerId: fromTeam.captainPlayerId,
        viceCaptainPlayerId: fromTeam.viceCaptainPlayerId,
        kboRoundScoreStates: fromTeam.kboRoundScoreStates,
      ),
    );
    final nextToTeam = _normalizeBaseballFantasyTeam(
      _FantasyTeamState(
        uid: toTeam.uid,
        teamName: toTeam.teamName,
        roster: _nextRosterAfterTrade(toTeam.roster, toPlayers, fromPlayers),
        starting: toTeam.starting,
        bench: toTeam.bench,
        captainName: toTeam.captainName,
        viceCaptainName: toTeam.viceCaptainName,
        captainPlayerId: toTeam.captainPlayerId,
        viceCaptainPlayerId: toTeam.viceCaptainPlayerId,
        kboRoundScoreStates: toTeam.kboRoundScoreStates,
      ),
    );

    final fromStates = await _updatedTradeKboRoundScoreStates(
      existingTeam: fromTeam,
      nextTeam: nextFromTeam,
    );
    final toStates = await _updatedTradeKboRoundScoreStates(
      existingTeam: toTeam,
      nextTeam: nextToTeam,
    );
    return {
      if (fromUid.isNotEmpty)
        fromUid: fromStates.map((state) => state.toMap()).toList(),
      if (toUid.isNotEmpty)
        toUid: toStates.map((state) => state.toMap()).toList(),
    };
  }

  Future<void> _loadRequest() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final request = await LeagueService.instance.getTradeRequestById(
        widget.requestId,
      );
      if (!mounted) return;
      setState(() {
        _request = request;
        _isLoading = false;
        _error = request == null ? '트레이드 요청 정보를 찾을 수 없습니다.' : null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = '트레이드 요청 정보를 불러오지 못했습니다.';
      });
    }
  }

  Future<void> _respond(String action) async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    try {
      final kboRoundScoreStatesByTeam = action == 'accept'
          ? await _kboRoundScoreStatesByTeam()
          : null;
      final response = await LeagueService.instance.respondToTradeRequest(
        requestId: widget.requestId,
        action: action,
        kboRoundScoreStatesByTeam: kboRoundScoreStatesByTeam,
      );
      if (!mounted) return;
      await _loadRequest();
      if (!mounted) return;
      final status = '${response['status'] ?? action}'.trim();
      final message = status == 'accepted' ? '트레이드를 수락했습니다.' : '트레이드를 거절했습니다.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$error'.trim().isNotEmpty ? '$error' : '트레이드 응답 처리에 실패했습니다.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  String _statusLabel(String status) {
    switch (status.trim().toLowerCase()) {
      case 'accepted':
        return '수락됨';
      case 'declined':
        return '거절됨';
      case 'pending':
      default:
        return '대기중';
    }
  }

  Color _statusColor(String status) {
    switch (status.trim().toLowerCase()) {
      case 'accepted':
        return const Color(0xFF16A34A);
      case 'declined':
        return const Color(0xFFE53935);
      case 'pending':
      default:
        return const Color(0xFF2E6BFF);
    }
  }

  Widget _playerListCard({
    required String title,
    required List<_PlayerSlot> players,
    required Color accent,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: accent,
              ),
            ),
            const SizedBox(height: 10),
            for (final player in players)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: accent.withOpacity(0.10),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        player.position,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: accent,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            player.name,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${_displayFantasyClubName(player.club, isSoccer: widget.draft.isSoccer)} · #${player.number}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF667085),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final request = _request;
    final currentUid = FirebaseAuth.instance.currentUser?.uid.trim() ?? '';
    final status = '${request?['status'] ?? 'pending'}';
    final incoming =
        currentUid.isNotEmpty && currentUid == '${request?['toUid'] ?? ''}';
    final canRespond = incoming && status == 'pending';
    final fromPlayers = (request?['fromPlayers'] as List<dynamic>? ?? const [])
        .map((item) => _tradePlayerSlotFromMap(_fixtureAsMap(item)))
        .toList();
    final toPlayers = (request?['toPlayers'] as List<dynamic>? ?? const [])
        .map((item) => _tradePlayerSlotFromMap(_fixtureAsMap(item)))
        .toList();
    final statusColor = _statusColor(status);

    return _OverlayScaffold(
      isMyPageOpen: _isMyPageOpen,
      onToggleMyPage: _toggleMyPage,
      title: 'LeagueIt',
      showSearch: false,
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Text(
                _error!,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          '트레이드 요청',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          _statusLabel(status),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${request?['leagueName'] ?? widget.draft.leagueName}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF667085),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${request?['fromTeamName'] ?? ''} → ${request?['toTeamName'] ?? ''}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          incoming
                              ? '상대 팀이 보낸 트레이드 요청입니다. 아래 선수 구성을 확인한 뒤 수락 또는 거절할 수 있습니다.'
                              : '보낸 트레이드 요청 상세입니다.',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF667085),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _kstMonthDayTimeLabel(
                            request?['createdAt'] is Timestamp
                                ? (request!['createdAt'] as Timestamp).toDate()
                                : DateTime.now(),
                          ),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF98A2B3),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _playerListCard(
                        title: '${request?['fromTeamName'] ?? ''} 제공',
                        players: fromPlayers,
                        accent: const Color(0xFF2E6BFF),
                      ),
                      const SizedBox(width: 12),
                      _playerListCard(
                        title: '${request?['toTeamName'] ?? ''} 제공',
                        players: toPlayers,
                        accent: const Color(0xFF16A34A),
                      ),
                    ],
                  ),
                  if (canRespond) ...[
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _isSubmitting
                                ? null
                                : () => _respond('decline'),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                              foregroundColor: const Color(0xFFE53935),
                              side: const BorderSide(color: Color(0xFFE53935)),
                            ),
                            child: const Text(
                              '거절',
                              style: TextStyle(fontWeight: FontWeight.w900),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isSubmitting
                                ? null
                                : () => _respond('accept'),
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                              backgroundColor: const Color(0xFF2E6BFF),
                              foregroundColor: Colors.white,
                            ),
                            child: Text(
                              _isSubmitting ? '처리 중...' : '수락',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

class _TradePage extends StatefulWidget {
  final String myTeamName;
  final String opponentTeamName;
  final List<_PlayerSlot> myRoster;
  final List<_PlayerSlot> opponentRoster;
  final String? initialOpponentPlayerName;
  final bool isSoccer;
  final bool Function(_PlayerSlot slot)? isLocked;
  final DateTime? rosterUnlocksAtUtc;
  const _TradePage({
    required this.myTeamName,
    required this.opponentTeamName,
    required this.myRoster,
    required this.opponentRoster,
    this.initialOpponentPlayerName,
    required this.isSoccer,
    this.isLocked,
    this.rosterUnlocksAtUtc,
  });

  @override
  State<_TradePage> createState() => _TradePageState();
}

class _TradePageState extends State<_TradePage> {
  static const int _maxPlayersInTrade = 8;
  bool _isMyPageOpen = false;
  late List<_PlayerSlot> _myRoster;
  late List<_PlayerSlot> _opponentRoster;
  final Set<String> _selectedMyNames = <String>{};
  final Set<String> _selectedOpponentNames = <String>{};

  @override
  void initState() {
    super.initState();
    _myRoster = List<_PlayerSlot>.from(widget.myRoster);
    _opponentRoster = List<_PlayerSlot>.from(widget.opponentRoster);
    final initialName = widget.initialOpponentPlayerName?.trim();
    if (initialName != null && initialName.isNotEmpty) {
      final initialPlayer = _opponentRoster.cast<_PlayerSlot?>().firstWhere(
        (player) => player?.name == initialName,
        orElse: () => null,
      );
      if (initialPlayer != null &&
          !(widget.isLocked?.call(initialPlayer) ?? false)) {
        _selectedOpponentNames.add(initialName);
      }
    }
  }

  void _toggleMyPage() => setState(() => _isMyPageOpen = !_isMyPageOpen);

  int get _selectedTotal =>
      _selectedMyNames.length + _selectedOpponentNames.length;

  bool get _canSubmitTrade =>
      _selectedMyNames.isNotEmpty &&
      _selectedOpponentNames.isNotEmpty &&
      _selectedTotal <= _maxPlayersInTrade;

  void _toggleSelection({required _PlayerSlot player, required bool isMine}) {
    if (widget.isLocked?.call(player) ?? false) {
      final message = widget.rosterUnlocksAtUtc == null
          ? '잠긴 선수는 트레이드에 포함할 수 없습니다.'
          : '잠긴 선수는 ${_kstMonthDayTimeLabel(widget.rosterUnlocksAtUtc!)}까지 트레이드에 포함할 수 없습니다.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      return;
    }
    final bucket = isMine ? _selectedMyNames : _selectedOpponentNames;
    final alreadySelected = bucket.contains(player.name);
    if (!alreadySelected && _selectedTotal >= _maxPlayersInTrade) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('트레이드에는 최대 8명까지 포함할 수 있습니다.')),
      );
      return;
    }
    setState(() {
      if (alreadySelected) {
        bucket.remove(player.name);
      } else {
        bucket.add(player.name);
      }
    });
  }

  void _submitTradeProposal() {
    if (!_canSubmitTrade) return;
    final myPlayers = _myRoster
        .where((player) => _selectedMyNames.contains(player.name))
        .toList();
    final opponentPlayers = _opponentRoster
        .where((player) => _selectedOpponentNames.contains(player.name))
        .toList();
    Navigator.pop(
      context,
      _TradeProposal(
        myTeamName: widget.myTeamName,
        opponentTeamName: widget.opponentTeamName,
        myPlayers: myPlayers,
        opponentPlayers: opponentPlayers,
      ),
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
                  final locked = widget.isLocked?.call(p) ?? false;
                  final selected = isMine
                      ? _selectedMyNames.contains(p.name)
                      : _selectedOpponentNames.contains(p.name);
                  return ListTile(
                    dense: true,
                    leading: Icon(
                      locked
                          ? Icons.lock_rounded
                          : selected
                          ? Icons.check_circle
                          : Icons.circle_outlined,
                      color: selected
                          ? (isMine
                                ? const Color(0xFF2E8B57)
                                : const Color(0xFF2E6BFF))
                          : locked
                          ? const Color(0xFF667085)
                          : Colors.grey,
                    ),
                    title: Text(
                      p.name,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text(
                      '${p.position} · ${p.club} · Apts ${_fantasyProjectedSlotScore(p).toStringAsFixed(1)}',
                    ),
                    onTap: () => _toggleSelection(player: p, isMine: isMine),
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F8F8),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.black12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '트레이드 제안',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${widget.opponentTeamName}와 트레이드할 선수를 선택하세요. 내 팀과 상대 팀을 합쳐 최대 8명까지 선택할 수 있습니다.',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF5E5E5E),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '선택 $_selectedTotal/$_maxPlayersInTrade · 내 팀 ${_selectedMyNames.length}명 · 상대 팀 ${_selectedOpponentNames.length}명',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF2E6BFF),
                    ),
                  ),
                  if ([..._myRoster, ..._opponentRoster].any(
                    (player) => widget.isLocked?.call(player) ?? false,
                  )) ...[
                    const SizedBox(height: 8),
                    Text(
                      widget.rosterUnlocksAtUtc == null
                          ? '잠긴 선수는 선택할 수 없습니다.'
                          : '잠긴 선수는 선택할 수 없습니다. 전체 해제: ${_kstMonthDayTimeLabel(widget.rosterUnlocksAtUtc!)}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF667085),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Row(
              children: [
                _panel(title: widget.myTeamName, data: _myRoster, isMine: true),
                _panel(
                  title: widget.opponentTeamName,
                  data: _opponentRoster,
                  isMine: false,
                ),
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
                backgroundColor: const Color(0xFF2E6BFF),
                foregroundColor: Colors.white,
              ),
              onPressed: _canSubmitTrade ? _submitTradeProposal : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _TradeProposal {
  final String myTeamName;
  final String opponentTeamName;
  final List<_PlayerSlot> myPlayers;
  final List<_PlayerSlot> opponentPlayers;

  const _TradeProposal({
    required this.myTeamName,
    required this.opponentTeamName,
    required this.myPlayers,
    required this.opponentPlayers,
  });
}

// 공용 선수 이름 풀 (검색 제안용)
List<String> getAllPlayerNames() {
  final all = _docMetaByName.keys.toList()..sort();
  return all;
}
