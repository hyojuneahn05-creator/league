part of '../home_page.dart';

enum PlayerOwnership { myTeam, otherTeam, freeAgent }

Future<Map<String, dynamic>>? _cachedKLeagueLeagueDataFuture;
Map<String, dynamic>? _cachedKLeagueLeagueData;
Future<Map<String, dynamic>>? _cachedKboLeagueDataFuture;
Map<String, dynamic>? _cachedKboLeagueData;
DateTime? _cachedKLeagueLeagueDataUpdatedAt;
DateTime? _cachedKboLeagueDataUpdatedAt;
const FlutterSecureStorage _leagueDataCacheStorage = FlutterSecureStorage(
  iOptions: IOSOptions(accountName: 'leagueit_local_state'),
);
const String _kLeagueLeagueDataCacheKey = 'kleague.league_data.v1';
const String _kboLeagueDataCacheKey = 'kbo.league_data.v1';
const Duration _leagueDataMemoryCacheTtl = Duration(minutes: 5);
const Duration _leagueDataPrimeCacheTtl = Duration(minutes: 30);
const int _kLeagueFixtureDetailConcurrencyLimit = 2;
const String _kLeagueFixtureDetailStorageKeyPrefix =
    'kleague.fixture_detail.v1';
final Map<int, Future<Map<String, dynamic>>> _cachedKLeagueFixtureDetails =
    <int, Future<Map<String, dynamic>>>{};
final Map<int, DateTime> _cachedKLeagueFixtureDetailsUpdatedAt =
    <int, DateTime>{};
int _activeKLeagueFixtureDetailRequests = 0;
final Queue<Completer<void>> _pendingKLeagueFixtureDetailRequestSlots =
    Queue<Completer<void>>();
final Map<String, Future<double?>> _cachedKLeaguePlayerAptsFutures =
    <String, Future<double?>>{};
final Map<String, double?> _cachedKLeaguePlayerApts = <String, double?>{};
const FlutterSecureStorage _kLeaguePlayerAptsStorage = FlutterSecureStorage(
  iOptions: IOSOptions(accountName: 'leagueit_local_state'),
);
const String _kLeaguePlayerAptsStorageKey = 'kleague.player_apts.v2';
Future<void>? _kLeaguePlayerAptsRestoreFuture;
final Map<String, Future<List<_PlayerRoundPoints>>>
_cachedKLeaguePlayerRoundPointsFutures =
    <String, Future<List<_PlayerRoundPoints>>>{};
final Map<String, List<_PlayerRoundPoints>> _cachedKLeaguePlayerRoundPoints =
    <String, List<_PlayerRoundPoints>>{};
final Map<String, DateTime> _cachedKLeaguePlayerRoundPointsUpdatedAt =
    <String, DateTime>{};
final Map<String, Future<List<_PlayerRoundPoints>>>
_cachedKboPlayerRoundPointsFutures =
    <String, Future<List<_PlayerRoundPoints>>>{};
final Map<String, bool> _cachedKboPlayerRoundPointsFutureHasFullSeason =
    <String, bool>{};
final Map<String, Set<int>> _cachedKboPlayerRoundPointsFutureTargetRounds =
    <String, Set<int>>{};
final Map<String, List<_PlayerRoundPoints>> _cachedKboPlayerRoundPoints =
    <String, List<_PlayerRoundPoints>>{};
final Map<String, bool> _cachedKboPlayerRoundPointsHasFullSeason =
    <String, bool>{};
final Map<String, Future<double?>> _cachedKboPlayerAptsFutures =
    <String, Future<double?>>{};
final Map<String, double?> _cachedKboPlayerApts = <String, double?>{};
final Map<String, Future<Map<String, dynamic>>> _cachedKboMatchDetails =
    <String, Future<Map<String, dynamic>>>{};
final Map<String, DateTime> _cachedKboMatchDetailFailureTimestamps =
    <String, DateTime>{};
final Map<String, String> _cachedKboMatchDetailFailureMessages =
    <String, String>{};
final Map<String, DateTime> _cachedKboPlayerRoundPointsUpdatedAt =
    <String, DateTime>{};
final Map<String, DateTime> _cachedKboMatchDetailsUpdatedAt =
    <String, DateTime>{};
final Map<String, DateTime> _loggedKboMatchDetailFailuresAt =
    <String, DateTime>{};
const Duration _kboProfileCacheTtl = Duration(minutes: 5);
const Duration _kboMatchDetailFailureCooldown = Duration(seconds: 30);
const Duration _kboMatchDetailLogCooldown = Duration(seconds: 30);
const int _kboMatchDetailConcurrencyLimit = 2;
const String _kboMatchDetailStorageKeyPrefix = 'kbo.match_detail.v1';
int _activeKboMatchDetailRequests = 0;
final Queue<Completer<void>> _pendingKboMatchDetailRequestSlots =
    Queue<Completer<void>>();

Future<T> _runKboMatchDetailRequestLimited<T>(
  Future<T> Function() action,
) async {
  if (_activeKboMatchDetailRequests >= _kboMatchDetailConcurrencyLimit) {
    final waiter = Completer<void>();
    _pendingKboMatchDetailRequestSlots.addLast(waiter);
    await waiter.future;
  }
  _activeKboMatchDetailRequests += 1;
  try {
    return await action();
  } finally {
    _activeKboMatchDetailRequests = max(0, _activeKboMatchDetailRequests - 1);
    if (_pendingKboMatchDetailRequestSlots.isNotEmpty) {
      _pendingKboMatchDetailRequestSlots.removeFirst().complete();
    }
  }
}

Future<T> _runKLeagueFixtureDetailRequestLimited<T>(
  Future<T> Function() action,
) async {
  if (_activeKLeagueFixtureDetailRequests >=
      _kLeagueFixtureDetailConcurrencyLimit) {
    final waiter = Completer<void>();
    _pendingKLeagueFixtureDetailRequestSlots.addLast(waiter);
    await waiter.future;
  }
  _activeKLeagueFixtureDetailRequests += 1;
  try {
    return await action();
  } finally {
    _activeKLeagueFixtureDetailRequests = max(
      0,
      _activeKLeagueFixtureDetailRequests - 1,
    );
    if (_pendingKLeagueFixtureDetailRequestSlots.isNotEmpty) {
      _pendingKLeagueFixtureDetailRequestSlots.removeFirst().complete();
    }
  }
}

const FlutterSecureStorage _kLeaguePlayerRoundPointsStorage =
    FlutterSecureStorage(
      iOptions: IOSOptions(accountName: 'leagueit_local_state'),
    );
const String _kLeaguePlayerRoundPointsStorageKey =
    'kleague.player_round_points.v3';
// TODO: If this cache grows further, shard it by player or round instead of
// persisting a single large JSON blob.
const int _kLeaguePlayerRoundPointsStorageMaxEntries = 80;
Future<void>? _kLeaguePlayerRoundPointsRestoreFuture;
bool _didHydratePersistedPlayerRoundPointsCache = false;
const Duration _kLeagueProfileCacheTtl = Duration(minutes: 5);
final Map<String, _PersistedPlayerRoundPointsEntry>
_persistedKLeaguePlayerRoundPointsEntries =
    <String, _PersistedPlayerRoundPointsEntry>{};

Future<void> _clearCorruptedKLeaguePlayerRoundPointsCache() async {
  await _deleteLocalStateCache(_kLeaguePlayerRoundPointsStorageKey);
  try {
    await _kLeaguePlayerRoundPointsStorage.delete(
      key: _kLeaguePlayerRoundPointsStorageKey,
    );
  } catch (error, stackTrace) {
    debugPrint(
      'Failed to clear legacy player round points cache '
      '($_kLeaguePlayerRoundPointsStorageKey): $error',
    );
    debugPrint('$stackTrace');
  }
}

Map<String, dynamic> _playerRoundPointDetailToJson(
  _PlayerRoundPointDetail detail,
) => <String, dynamic>{
  'label': detail.label,
  'detail': detail.detail,
  'points': detail.points,
};

_PlayerRoundPointDetail? _playerRoundPointDetailFromJson(
  Map<String, dynamic> json,
) {
  final label = '${json['label'] ?? ''}'.trim();
  if (label.isEmpty) return null;
  return _PlayerRoundPointDetail(
    label: label,
    detail: '${json['detail'] ?? ''}'.trim().isEmpty
        ? null
        : '${json['detail']}'.trim(),
    points: (json['points'] as num?)?.toDouble() ?? 0.0,
  );
}

Map<String, dynamic> _playerRoundPointsToJson(
  _PlayerRoundPoints roundPoints,
) => <String, dynamic>{
  'round': roundPoints.round,
  'displayedPoints': roundPoints.displayedPoints,
  'basePoints': roundPoints.basePoints,
  'isCaptain': roundPoints.isCaptain,
  'isViceCaptain': roundPoints.isViceCaptain,
  'appeared': roundPoints.appeared,
  'started': roundPoints.started,
  'details': roundPoints.details.map(_playerRoundPointDetailToJson).toList(),
  'opponentLabel': roundPoints.opponentLabel,
};

_PlayerRoundPoints? _playerRoundPointsFromJson(Map<String, dynamic> json) {
  final round = _readNullableInt(json['round']) ?? 0;
  if (round <= 0) return null;
  final details = _fixtureAsList(json['details'])
      .map((raw) => _playerRoundPointDetailFromJson(_fixtureAsMap(raw)))
      .whereType<_PlayerRoundPointDetail>()
      .toList();
  return _PlayerRoundPoints(
    round: round,
    displayedPoints: (json['displayedPoints'] as num?)?.toDouble() ?? 0.0,
    basePoints: (json['basePoints'] as num?)?.toDouble() ?? 0.0,
    isCaptain: json['isCaptain'] == true,
    isViceCaptain: json['isViceCaptain'] == true,
    appeared: json['appeared'] == true,
    started: json['started'] == true,
    details: details,
    opponentLabel: '${json['opponentLabel'] ?? ''}'.trim().isEmpty
        ? null
        : '${json['opponentLabel']}'.trim(),
  );
}

bool _playerMatchesProfileMeta(
  _FantasyTeamPlayer player,
  String name, {
  required ({String position, String club, int number}) meta,
}) {
  if (player.name != name) return false;
  final playerClub = _canonicalKLeagueClub(player.club);
  final profileClub = _canonicalKLeagueClub(meta.club);
  if (playerClub.isNotEmpty &&
      profileClub.isNotEmpty &&
      playerClub != profileClub) {
    return false;
  }
  if (meta.number > 0 && player.number > 0 && player.number != meta.number) {
    return false;
  }
  final normalizedProfilePosition = _normalizeFantasySoccerPosition(
    meta.position,
  );
  final normalizedPlayerPosition = _normalizeFantasySoccerPosition(
    player.position,
  );
  if (normalizedProfilePosition.isNotEmpty &&
      normalizedPlayerPosition.isNotEmpty &&
      normalizedProfilePosition != normalizedPlayerPosition) {
    return false;
  }
  return true;
}

bool _fantasyTeamPlayerMatchesProfileMeta(
  _FantasyTeamPlayer player,
  String name, {
  required ({String position, String club, int number}) meta,
}) {
  final isSoccerPlayer = _normalizeFantasySoccerPosition(
    meta.position,
  ).isNotEmpty;
  if (isSoccerPlayer) {
    return _playerMatchesProfileMeta(player, name, meta: meta);
  }
  if (player.name != name) return false;
  final playerClub = _normalizeKboDraftClub(player.club);
  final profileClub = _normalizeKboDraftClub(meta.club);
  if (playerClub.isNotEmpty &&
      profileClub.isNotEmpty &&
      playerClub != profileClub) {
    return false;
  }
  if (meta.number > 0 && player.number > 0 && meta.number != player.number) {
    return false;
  }
  final playerPosition = _normalizeKboProfilePosition(player.position);
  final profilePosition = _normalizeKboProfilePosition(meta.position);
  if (playerPosition.isNotEmpty &&
      profilePosition.isNotEmpty &&
      playerPosition != profilePosition) {
    return false;
  }
  return true;
}

_PlayerFantasyProfileData _resolveFantasyProfileDataSync(
  String playerName, {
  required ({String position, String club, int number}) meta,
}) {
  final homeState = homeKey.currentState;
  if (homeState == null) {
    return const _PlayerFantasyProfileData(draft: null, team: null);
  }

  final drafts =
      homeState._joinedDrafts
          .where(
            (draft) =>
                draft.fantasyReady &&
                draft.fantasyTeams.isNotEmpty &&
                draft.fantasySchedule.isNotEmpty,
          )
          .toList()
        ..sort((a, b) => a.when.compareTo(b.when));

  for (final draft in drafts) {
    for (final team in draft.fantasyTeams) {
      if (team.roster.any(
        (player) => _fantasyTeamPlayerMatchesProfileMeta(
          player,
          playerName,
          meta: meta,
        ),
      )) {
        return _PlayerFantasyProfileData(draft: draft, team: team);
      }
    }
  }

  return const _PlayerFantasyProfileData(draft: null, team: null);
}

Future<void> _restorePersistedKLeaguePlayerRoundPointsCache() {
  if (_didHydratePersistedPlayerRoundPointsCache) {
    return Future<void>.value();
  }
  final inFlight = _kLeaguePlayerRoundPointsRestoreFuture;
  if (inFlight != null) return inFlight;
  final future =
      () async {
        try {
          final raw = await _readLocalStateCacheWithLegacySecureStorage(
            key: _kLeaguePlayerRoundPointsStorageKey,
            legacyStorage: _kLeaguePlayerRoundPointsStorage,
          );
          if (raw == null || raw.trim().isEmpty) {
            _didHydratePersistedPlayerRoundPointsCache = true;
            return;
          }
          dynamic decoded;
          try {
            decoded = jsonDecode(raw);
          } on FormatException catch (error, stackTrace) {
            debugPrint(
              'Warning: corrupted player round points cache detected '
              '($_kLeaguePlayerRoundPointsStorageKey). Clearing entry. '
              'Error: $error',
            );
            debugPrint('$stackTrace');
            await _clearCorruptedKLeaguePlayerRoundPointsCache();
            _didHydratePersistedPlayerRoundPointsCache = true;
            return;
          }
          if (decoded is! Map<String, dynamic>) {
            debugPrint(
              'Warning: unexpected player round points cache payload type '
              'for $_kLeaguePlayerRoundPointsStorageKey. Clearing entry.',
            );
            await _clearCorruptedKLeaguePlayerRoundPointsCache();
            _didHydratePersistedPlayerRoundPointsCache = true;
            return;
          }
          final entries = _fixtureAsMap(decoded['entries']);
          for (final entry in entries.entries) {
            final payload = _fixtureAsMap(entry.value);
            final isSoccer = payload['isSoccer'] != false;
            final hasFullSeason = isSoccer || payload['hasFullSeason'] == true;
            final updatedAt = DateTime.tryParse(
              '${payload['updatedAt'] ?? ''}',
            );
            final roundPoints = _fixtureAsList(payload['roundPoints'])
                .map(
                  (rawRound) =>
                      _playerRoundPointsFromJson(_fixtureAsMap(rawRound)),
                )
                .whereType<_PlayerRoundPoints>()
                .toList();
            if (updatedAt == null || roundPoints.isEmpty) continue;
            if (DateTime.now().difference(updatedAt) >
                _kLeagueProfileCacheTtl) {
              continue;
            }
            final existingUpdatedAt = isSoccer
                ? _cachedKLeaguePlayerRoundPointsUpdatedAt[entry.key]
                : _cachedKboPlayerRoundPointsUpdatedAt[entry.key];
            if (existingUpdatedAt != null &&
                !updatedAt.isAfter(existingUpdatedAt)) {
              continue;
            }
            _persistedKLeaguePlayerRoundPointsEntries[entry.key] =
                _PersistedPlayerRoundPointsEntry(
                  isSoccer: isSoccer,
                  hasFullSeason: hasFullSeason,
                  updatedAt: updatedAt,
                  roundPoints: roundPoints,
                );
            if (isSoccer) {
              _cachedKLeaguePlayerRoundPoints[entry.key] = roundPoints;
              _cachedKLeaguePlayerRoundPointsUpdatedAt[entry.key] = updatedAt;
              final parts = entry.key.split('|');
              if (parts.length >= 2) {
                _syncKLeaguePlayerAptsCacheFromRoundPoints(
                  playerName: parts[parts.length - 2],
                  club: parts.first,
                  roundPoints: roundPoints,
                  persist: false,
                );
              }
            } else {
              _cachedKboPlayerRoundPoints[entry.key] = roundPoints;
              _cachedKboPlayerRoundPointsHasFullSeason[entry.key] =
                  hasFullSeason;
              _cachedKboPlayerRoundPointsUpdatedAt[entry.key] = updatedAt;
              if (hasFullSeason) {
                _cachedKboPlayerApts[entry.key] = _kLeagueAptsFromRoundPoints(
                  roundPoints,
                );
              }
            }
          }
          _didHydratePersistedPlayerRoundPointsCache = true;
        } catch (error, stackTrace) {
          debugPrint(
            'restorePersistedKLeaguePlayerRoundPointsCache failed: $error',
          );
          debugPrint('$stackTrace');
        }
      }().whenComplete(() {
        _kLeaguePlayerRoundPointsRestoreFuture = null;
      });
  _kLeaguePlayerRoundPointsRestoreFuture = future;
  return future;
}

Future<void> _persistKLeaguePlayerRoundPointsCache() async {
  try {
    final sortedEntries =
        _persistedKLeaguePlayerRoundPointsEntries.entries.toList()
          ..sort((a, b) => b.value.updatedAt.compareTo(a.value.updatedAt));
    final limitedEntries = sortedEntries.take(
      _kLeaguePlayerRoundPointsStorageMaxEntries,
    );
    final payload = <String, dynamic>{
      'entries': <String, dynamic>{
        for (final entry in limitedEntries)
          entry.key: <String, dynamic>{
            'isSoccer': entry.value.isSoccer,
            'hasFullSeason': entry.value.hasFullSeason,
            'updatedAt': entry.value.updatedAt.toIso8601String(),
            'roundPoints': entry.value.roundPoints
                .map(_playerRoundPointsToJson)
                .toList(),
          },
      },
    };
    final encoded = jsonEncode(payload);
    try {
      await _writeLocalStateCache(_kLeaguePlayerRoundPointsStorageKey, encoded);
    } catch (error, stackTrace) {
      debugPrint('persistKLeaguePlayerRoundPointsCache write failed: $error');
      debugPrint('$stackTrace');
      await _deleteLocalStateCache(_kLeaguePlayerRoundPointsStorageKey);
    }
  } catch (error, stackTrace) {
    debugPrint('persistKLeaguePlayerRoundPointsCache failed: $error');
    debugPrint('$stackTrace');
  }
}

Future<void> _restorePersistedKLeaguePlayerAptsCache() {
  final inFlight = _kLeaguePlayerAptsRestoreFuture;
  if (inFlight != null) return inFlight;
  final future =
      () async {
        try {
          final raw = await _readLocalStateCacheWithLegacySecureStorage(
            key: _kLeaguePlayerAptsStorageKey,
            legacyStorage: _kLeaguePlayerAptsStorage,
          );
          if (raw == null || raw.trim().isEmpty) return;
          final decoded = jsonDecode(raw);
          if (decoded is! Map<String, dynamic>) return;
          final entries = _fixtureAsMap(decoded['entries']);
          for (final entry in entries.entries) {
            final value = (entry.value as num?)?.toDouble();
            if (value == null) continue;
            _cachedKLeaguePlayerApts[entry.key] = value;
          }
        } catch (error, stackTrace) {
          debugPrint('restorePersistedKLeaguePlayerAptsCache failed: $error');
          debugPrint('$stackTrace');
        }
      }().whenComplete(() {
        _kLeaguePlayerAptsRestoreFuture = null;
      });
  _kLeaguePlayerAptsRestoreFuture = future;
  return future;
}

Future<void> _persistKLeaguePlayerAptsCache() async {
  try {
    final payload = <String, dynamic>{
      'entries': <String, double>{
        for (final entry in _cachedKLeaguePlayerApts.entries)
          if (entry.value != null) entry.key: entry.value!,
      },
    };
    await _writeLocalStateCache(
      _kLeaguePlayerAptsStorageKey,
      jsonEncode(payload),
    );
  } catch (error, stackTrace) {
    debugPrint('persistKLeaguePlayerAptsCache failed: $error');
    debugPrint('$stackTrace');
  }
}

String _kLeagueRoundPointsCacheKey({
  required String playerName,
  required String club,
  int? preferredNumber,
}) {
  final resolvedMeta = _resolvePlayerMeta(playerName);
  final targetNumber = preferredNumber != null && preferredNumber > 0
      ? preferredNumber
      : resolvedMeta.number;
  return '${_kLeagueSeasonAptsKey(club: club, name: playerName)}|$targetNumber';
}

List<_PlayerRoundPoints>? _cachedKLeagueRoundPointsForPlayer({
  required String playerName,
  required String club,
  int? preferredNumber,
}) {
  final cacheKey = _kLeagueRoundPointsCacheKey(
    playerName: playerName,
    club: club,
    preferredNumber: preferredNumber,
  );
  final cachedAt = _cachedKLeaguePlayerRoundPointsUpdatedAt[cacheKey];
  final isStale =
      cachedAt == null ||
      DateTime.now().difference(cachedAt) > _kLeagueProfileCacheTtl;
  if (isStale) {
    _cachedKLeaguePlayerRoundPoints.remove(cacheKey);
    _cachedKLeaguePlayerRoundPointsFutures.remove(cacheKey);
    _cachedKLeaguePlayerRoundPointsUpdatedAt.remove(cacheKey);
    _persistedKLeaguePlayerRoundPointsEntries.remove(cacheKey);
    return null;
  }
  return _cachedKLeaguePlayerRoundPoints[cacheKey];
}

String _normalizeKboProfilePosition(String value) {
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
    case 'C':
    case 'P':
    case 'DH':
      return value.trim().toUpperCase();
    default:
      return value.trim().toUpperCase();
  }
}

bool _isKnownKboPlayerMeta(({String position, String club, int number}) meta) {
  final club = _normalizeKboDraftClub(meta.club);
  final position = _normalizeKboProfilePosition(meta.position);
  return _kboDraftClubs.contains(club) ||
      const <String>{'P', 'C', 'IF', 'OF', 'DH'}.contains(position);
}

String _kboRoundPointsCacheKey({
  required String playerName,
  required String club,
  int? preferredNumber,
  String? preferredPosition,
}) {
  final normalizedClub = _normalizeKboDraftClub(club);
  final normalizedPosition = _normalizeKboProfilePosition(
    preferredPosition ?? '',
  );
  final targetNumber = preferredNumber != null && preferredNumber > 0
      ? preferredNumber
      : 0;
  return '$normalizedClub|$playerName|$targetNumber|$normalizedPosition';
}

String _kboSeasonAptsKey({
  required String playerName,
  required String club,
  int? preferredNumber,
  String? preferredPosition,
}) {
  final normalizedClub = _normalizeKboDraftClub(club);
  final normalizedPosition = _normalizeKboProfilePosition(
    preferredPosition ?? '',
  );
  final targetNumber = preferredNumber != null && preferredNumber > 0
      ? preferredNumber
      : 0;
  return '$normalizedClub|$playerName|$targetNumber|$normalizedPosition';
}

bool _kboRoundPointsCoverTargetRounds(
  Iterable<_PlayerRoundPoints> roundPoints,
  Set<int> targetRounds,
) {
  if (targetRounds.isEmpty) return true;
  final coveredRounds = roundPoints.map((entry) => entry.round).toSet();
  return targetRounds.every(coveredRounds.contains);
}

List<_PlayerRoundPoints> _mergePlayerRoundPointsByRound({
  Iterable<_PlayerRoundPoints>? base,
  required Iterable<_PlayerRoundPoints> updates,
}) {
  final merged = <int, _PlayerRoundPoints>{};
  for (final entry in base ?? const <_PlayerRoundPoints>[]) {
    merged[entry.round] = entry;
  }
  for (final entry in updates) {
    merged[entry.round] = entry;
  }
  final result = merged.values.toList()
    ..sort((left, right) => left.round.compareTo(right.round));
  return result;
}

List<_PlayerRoundPoints>? _cachedKboRoundPointsForPlayer({
  required String playerName,
  required String club,
  int? preferredNumber,
  String? preferredPosition,
  bool allowStale = true,
}) {
  final key = _kboRoundPointsCacheKey(
    playerName: playerName,
    club: club,
    preferredNumber: preferredNumber,
    preferredPosition: preferredPosition,
  );
  final cached = _cachedKboPlayerRoundPoints[key];
  if (cached == null) return null;
  final cachedAt = _cachedKboPlayerRoundPointsUpdatedAt[key];
  final isFresh =
      cachedAt != null &&
      DateTime.now().difference(cachedAt) <= _kboProfileCacheTtl;
  if (!allowStale && !isFresh) {
    return null;
  }
  return cached;
}

List<_PlayerRoundPoints>? _cachedFullSeasonKboRoundPointsForPlayer({
  required String playerName,
  required String club,
  int? preferredNumber,
  String? preferredPosition,
  bool allowStale = true,
}) {
  final cached = _cachedKboRoundPointsForPlayer(
    playerName: playerName,
    club: club,
    preferredNumber: preferredNumber,
    preferredPosition: preferredPosition,
    allowStale: allowStale,
  );
  if (cached == null) return null;
  final key = _kboRoundPointsCacheKey(
    playerName: playerName,
    club: club,
    preferredNumber: preferredNumber,
    preferredPosition: preferredPosition,
  );
  return _cachedKboPlayerRoundPointsHasFullSeason[key] == true ? cached : null;
}

double? _cachedFullSeasonKboAptsForPlayer({
  required String playerName,
  required String club,
  int? preferredNumber,
  String? preferredPosition,
  bool allowStale = true,
}) {
  final roundPoints = _cachedFullSeasonKboRoundPointsForPlayer(
    playerName: playerName,
    club: club,
    preferredNumber: preferredNumber,
    preferredPosition: preferredPosition,
    allowStale: allowStale,
  );
  if (roundPoints != null) {
    return _kLeagueAptsFromRoundPoints(roundPoints);
  }
  final cacheKey = _kboSeasonAptsKey(
    playerName: playerName,
    club: club,
    preferredNumber: preferredNumber,
    preferredPosition: preferredPosition,
  );
  final roundPointsKey = _kboRoundPointsCacheKey(
    playerName: playerName,
    club: club,
    preferredNumber: preferredNumber,
    preferredPosition: preferredPosition,
  );
  if (_cachedKboPlayerRoundPointsHasFullSeason[roundPointsKey] == true &&
      _cachedKboPlayerApts.containsKey(cacheKey)) {
    return _cachedKboPlayerApts[cacheKey];
  }
  return null;
}

String _kboMatchDetailCacheKey(int matchId, {int? fantasyRound}) {
  final round = fantasyRound != null && fantasyRound > 0 ? fantasyRound : 0;
  return 'v2|$matchId|$round';
}

String _kboMatchDetailDiskCacheKey(int matchId, {int? fantasyRound}) {
  return '$_kboMatchDetailStorageKeyPrefix.${_kboMatchDetailCacheKey(matchId, fantasyRound: fantasyRound)}';
}

bool _isHistoricalKboFantasyRound(int round, {DateTime? now}) {
  if (round <= 0) return false;
  return round < _latestStartedKboFantasyRound(now ?? DateTime.now());
}

Future<({Map<String, dynamic> detail, DateTime updatedAt})?>
_restorePersistedKboMatchDetail(int matchId, {int? fantasyRound}) async {
  try {
    final raw = await _readLocalStateCache(
      _kboMatchDetailDiskCacheKey(matchId, fantasyRound: fantasyRound),
    );
    if (raw == null || raw.trim().isEmpty) return null;
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) return null;
    final detail = _fixtureAsMap(decoded['detail']);
    if (detail.isEmpty) return null;
    final updatedAt =
        DateTime.tryParse('${decoded['updatedAt'] ?? ''}') ?? DateTime(1970);
    return (detail: detail, updatedAt: updatedAt);
  } catch (error, stackTrace) {
    debugPrint('restorePersistedKboMatchDetail failed: $error');
    debugPrint('$stackTrace');
    return null;
  }
}

Future<void> _persistKboMatchDetail(
  int matchId,
  Map<String, dynamic> detail, {
  int? fantasyRound,
}) async {
  try {
    await _writeLocalStateCache(
      _kboMatchDetailDiskCacheKey(matchId, fantasyRound: fantasyRound),
      jsonEncode(<String, dynamic>{
        'updatedAt': DateTime.now().toIso8601String(),
        'detail': detail,
      }),
    );
  } catch (error, stackTrace) {
    debugPrint('persistKboMatchDetail failed: $error');
    debugPrint('$stackTrace');
  }
}

bool _shouldUseCachedKboMatchDetail(
  Map<String, dynamic> detail, {
  required DateTime cachedAt,
  bool forceRefresh = false,
  int? fantasyRound,
  DateTime? now,
}) {
  final current = now ?? DateTime.now();
  if (fantasyRound != null &&
      _isHistoricalKboFantasyRound(fantasyRound, now: current)) {
    return true;
  }
  if (_isKboTerminalStatus('${detail['status'] ?? ''}')) {
    return true;
  }
  if (!forceRefresh && current.difference(cachedAt) <= _kboProfileCacheTtl) {
    return true;
  }
  return false;
}

Map<int, int> _kboFrozenCancelledMatchOriginalRounds(
  Map<String, dynamic>? leagueData,
) {
  final result = <int, int>{};
  for (final raw in _fixtureAsList(leagueData?['fantasyExcludedMatches'])) {
    final map = _fixtureAsMap(raw);
    final matchId = _readNullableInt(map['matchId']);
    final originalRound = _readNullableInt(map['originalRound']) ?? 0;
    if (matchId == null || matchId <= 0 || originalRound <= 0) continue;
    result[matchId] = originalRound;
  }
  return result;
}

Future<Map<String, dynamic>> _loadCachedKboMatchDetail(
  int matchId, {
  bool forceRefresh = false,
  int? fantasyRound,
}) async {
  final cacheKey = _kboMatchDetailCacheKey(matchId, fantasyRound: fantasyRound);
  final now = DateTime.now();
  final inFlight = _cachedKboMatchDetails[cacheKey];
  final cachedAt = _cachedKboMatchDetailsUpdatedAt[cacheKey];
  final isStale =
      cachedAt == null || now.difference(cachedAt) > _kboProfileCacheTtl;
  if (inFlight != null) {
    if (cachedAt != null) {
      try {
        final detail = await inFlight;
        if (_shouldUseCachedKboMatchDetail(
          detail,
          cachedAt: cachedAt,
          forceRefresh: forceRefresh,
          fantasyRound: fantasyRound,
          now: now,
        )) {
          return detail;
        }
      } catch (_) {
        // Fall through to persisted/network fetch below.
      }
    } else if (!forceRefresh && !isStale) {
      return inFlight;
    }
    if (!isStale && now.difference(cachedAt) < const Duration(seconds: 4)) {
      return inFlight;
    }
  }

  final persisted = await _restorePersistedKboMatchDetail(
    matchId,
    fantasyRound: fantasyRound,
  );
  if (persisted != null &&
      _shouldUseCachedKboMatchDetail(
        persisted.detail,
        cachedAt: persisted.updatedAt,
        forceRefresh: forceRefresh,
        fantasyRound: fantasyRound,
        now: now,
      )) {
    final future = Future<Map<String, dynamic>>.value(persisted.detail);
    _cachedKboMatchDetails[cacheKey] = future;
    _cachedKboMatchDetailsUpdatedAt[cacheKey] = persisted.updatedAt;
    return future;
  }

  final failedAt = _cachedKboMatchDetailFailureTimestamps[cacheKey];
  if (failedAt != null &&
      now.difference(failedAt) < _kboMatchDetailFailureCooldown) {
    final cachedMessage =
        _cachedKboMatchDetailFailureMessages[cacheKey] ?? 'Request failed';
    return Future<Map<String, dynamic>>.error(Exception(cachedMessage));
  }
  if (forceRefresh || isStale) {
    _cachedKboMatchDetails.remove(cacheKey);
    _cachedKboMatchDetailsUpdatedAt.remove(cacheKey);
  }
  final cached = _cachedKboMatchDetails[cacheKey];
  if (cached != null) return cached;
  final future =
      _runKboMatchDetailRequestLimited(
            () => ApiService.fetchKboMatchDetails(
              matchId,
              fantasyRound: fantasyRound,
            ),
          )
          .then((detail) {
            _cachedKboMatchDetailFailureTimestamps.remove(cacheKey);
            _cachedKboMatchDetailFailureMessages.remove(cacheKey);
            unawaited(
              _persistKboMatchDetail(
                matchId,
                detail,
                fantasyRound: fantasyRound,
              ),
            );
            return detail;
          })
          .catchError((error) {
            _cachedKboMatchDetails.remove(cacheKey);
            _cachedKboMatchDetailsUpdatedAt.remove(cacheKey);
            _cachedKboMatchDetailFailureTimestamps[cacheKey] = DateTime.now();
            _cachedKboMatchDetailFailureMessages[cacheKey] = '$error';
            throw error;
          });
  _cachedKboMatchDetails[cacheKey] = future;
  _cachedKboMatchDetailsUpdatedAt[cacheKey] = now;
  return future;
}

bool _shouldLogKboMatchDetailFailure(int matchId, {int? fantasyRound}) {
  final cacheKey = _kboMatchDetailCacheKey(matchId, fantasyRound: fantasyRound);
  final lastLoggedAt = _loggedKboMatchDetailFailuresAt[cacheKey];
  final now = DateTime.now();
  if (lastLoggedAt != null &&
      now.difference(lastLoggedAt) < _kboMatchDetailLogCooldown) {
    return false;
  }
  _loggedKboMatchDetailFailuresAt[cacheKey] = now;
  return true;
}

int _kboFantasyRoundForMatchDate(DateTime matchDate) {
  final day = _kstDayOnly(matchDate);
  for (final window in _kboFantasyRoundWindows2026) {
    if (_kboFantasyRoundContainsDay(day, window)) return window.round;
  }
  return 0;
}

bool _kboMatchMapHasStarted(Map<String, dynamic> matchMap, {DateTime? now}) {
  final current = now ?? DateTime.now();
  final date = DateTime.tryParse('${matchMap['date'] ?? ''}');
  final status = '${matchMap['status'] ?? ''}'.trim().toLowerCase();
  if (status == 'played' ||
      status == 'in progress' ||
      status == 'playing' ||
      status == 'final') {
    return true;
  }
  if (date == null) return false;
  return !date.isAfter(current);
}

const Map<String, String> _kboRoundPointLabelTranslations = <String, String>{
  'Single': '안타',
  'Double': '2루타',
  'Triple': '3루타',
  'Home Run': '홈런',
  'RBI': '타점',
  'Run Scored': '득점',
  'Walk': '볼넷/HBP',
  'Hit by Pitch': '볼넷/HBP',
  'Stolen Base': '도루',
  'Strikeout': '삼진',
  'Pitching Strikeout': '탈삼진',
  'Inning Pitched': '이닝',
  'Win': '승리',
  'Save': '세이브',
  'Earned Run': '자책점',
  'Pitching Walk': '볼넷',
};

const Map<String, int> _kboRoundPointDisplayOrder = <String, int>{
  '안타': 0,
  '2루타': 1,
  '3루타': 2,
  '홈런': 3,
  '타점': 4,
  '득점': 5,
  '볼넷/HBP': 6,
  '도루': 7,
  '삼진': 8,
  '탈삼진': 9,
  '이닝': 10,
  '승리': 11,
  '세이브': 12,
  '자책점': 13,
  '볼넷': 14,
};

String? _kboFantasyRoundDateLabel(int round) {
  final window = _kboFantasyRoundWindows2026
      .where((entry) => entry.round == round)
      .cast<_KboFantasyRoundWindow?>()
      .firstWhere((entry) => entry != null, orElse: () => null);
  if (window == null) return null;
  return '${window.startKst.month}/${window.startKst.day}'
      '~${window.endKst.month}/${window.endKst.day}';
}

int _latestStartedKboFantasyRound(DateTime now) {
  final windows = _kboFantasyRoundWindows2026;
  if (windows.isEmpty) return 0;

  final nowDay = _kstDayOnly(now);
  if (nowDay.isBefore(windows.first.startKst)) return 0;

  var latestRound = 0;
  for (final window in windows) {
    if (nowDay.isBefore(window.startKst)) break;
    latestRound = window.round;
  }
  return latestRound;
}

List<_PlayerRoundPoints> _visibleProfileRoundPoints(
  List<_PlayerRoundPoints> roundPoints, {
  required bool isSoccerPlayer,
}) {
  if (isSoccerPlayer) return roundPoints;

  final latestStartedRound = _latestStartedKboFantasyRound(DateTime.now());
  if (latestStartedRound <= 0) return const <_PlayerRoundPoints>[];

  return roundPoints
      .where((entry) => entry.round > 0 && entry.round <= latestStartedRound)
      .toList(growable: false);
}

double? _parseKboRoundPointCount(String? raw) {
  if (raw == null) return null;
  final normalized = raw.replaceAll('IP', '').trim();
  if (normalized.isEmpty) return null;
  final match = RegExp(r'-?\d+(?:\.\d+)?').firstMatch(normalized);
  if (match == null) return null;
  return double.tryParse(match.group(0)!);
}

String? _formatKboRoundPointCount(String label, double? value) {
  if (value == null) return null;
  if (label == '이닝') return value.toStringAsFixed(1);
  final whole = value.roundToDouble();
  if ((value - whole).abs() < 0.001) return whole.toStringAsFixed(0);
  return value.toStringAsFixed(1);
}

List<_PlayerRoundPointDetail> _groupKboRoundPointDetails(
  Iterable<_PlayerRoundPointDetail> details,
) {
  final grouped = <String, ({double points, double? count})>{};

  for (final detail in details) {
    final label =
        _kboRoundPointLabelTranslations[detail.label] ?? detail.label.trim();
    final previous = grouped[label];
    final count = _parseKboRoundPointCount(detail.detail);
    grouped[label] = (
      points: (previous?.points ?? 0) + detail.points,
      count: (previous?.count ?? 0) + (count ?? 0),
    );
  }

  final rows = grouped.entries.map((entry) {
    final count = entry.value.count;
    final formattedCount = _formatKboRoundPointCount(
      entry.key,
      count == null || count == 0 ? null : count,
    );
    return _PlayerRoundPointDetail(
      label: entry.key,
      detail: formattedCount,
      points: entry.value.points,
    );
  }).toList();

  rows.sort((left, right) {
    final leftOrder = _kboRoundPointDisplayOrder[left.label] ?? 999;
    final rightOrder = _kboRoundPointDisplayOrder[right.label] ?? 999;
    if (leftOrder != rightOrder) return leftOrder.compareTo(rightOrder);
    return left.label.compareTo(right.label);
  });
  return rows;
}

bool _kboPlayerStatMatchesProfile(
  Map<String, dynamic> stat,
  String playerName, {
  required ({String position, String club, int number}) meta,
}) {
  final statName = '${stat['name'] ?? ''}'.trim();
  if (statName != playerName) return false;

  final statClub = _normalizeKboDraftClub('${stat['team'] ?? ''}');
  final profileClub = _normalizeKboDraftClub(meta.club);
  if (statClub.isNotEmpty &&
      profileClub.isNotEmpty &&
      statClub != profileClub) {
    return false;
  }

  final statNumber = int.tryParse('${stat['number'] ?? ''}') ?? 0;
  if (meta.number > 0 && statNumber > 0 && meta.number != statNumber) {
    return false;
  }

  final statPosition = _normalizeKboProfilePosition(
    '${stat['position'] ?? ''}',
  );
  final profilePosition = _normalizeKboProfilePosition(meta.position);
  if (profilePosition.isNotEmpty &&
      statPosition.isNotEmpty &&
      profilePosition != statPosition &&
      statPosition != 'DH') {
    return false;
  }

  return true;
}

Future<Map<String, dynamic>> _loadCachedKLeagueLeagueData({
  bool forceRefresh = false,
}) {
  final now = DateTime.now();
  final cachedData = _cachedKLeagueLeagueData;
  final cachedAt = _cachedKLeagueLeagueDataUpdatedAt;
  final inFlight = _cachedKLeagueLeagueDataFuture;
  if (cachedData != null && _isLeagueDataMemoryCacheFresh(cachedAt, now: now)) {
    return Future.value(cachedData);
  }
  if (inFlight != null) {
    return inFlight;
  }
  final future =
      () async {
        final restored = await _restoreLeagueDataCacheEntry(
          _kLeagueLeagueDataCacheKey,
        );
        if (restored != null &&
            _isLeagueDataMemoryCacheFresh(restored.updatedAt, now: now)) {
          _cachedKLeagueLeagueData = restored.data;
          _cachedKLeagueLeagueDataUpdatedAt = restored.updatedAt ?? now;
          return restored.data;
        }
        if (!forceRefresh && cachedData != null) {
          return cachedData;
        }
        try {
          final value = await ApiService.fetchLeagueData();
          final fetchedAt = DateTime.now();
          _cachedKLeagueLeagueData = value;
          _cachedKLeagueLeagueDataUpdatedAt = fetchedAt;
          unawaited(_persistLeagueDataCache(_kLeagueLeagueDataCacheKey, value));
          return value;
        } catch (error, stackTrace) {
          debugPrint('K League league data load failed: $error');
          debugPrint('$stackTrace');
          if (cachedData != null) {
            return cachedData;
          }
          if (restored != null) {
            _cachedKLeagueLeagueData = restored.data;
            _cachedKLeagueLeagueDataUpdatedAt = restored.updatedAt;
            return restored.data;
          }
          final fallback = _emptyKLeagueLeagueData();
          _cachedKLeagueLeagueData = fallback;
          _cachedKLeagueLeagueDataUpdatedAt = null;
          return fallback;
        }
      }().whenComplete(() {
        _cachedKLeagueLeagueDataFuture = null;
      });
  _cachedKLeagueLeagueDataFuture = future;
  return future;
}

Future<Map<String, dynamic>> _loadCachedKboLeagueData({
  bool forceRefresh = false,
}) {
  final now = DateTime.now();
  final cachedData = _cachedKboLeagueData;
  final cachedAt = _cachedKboLeagueDataUpdatedAt;
  final inFlight = _cachedKboLeagueDataFuture;
  if (cachedData != null && _isLeagueDataMemoryCacheFresh(cachedAt, now: now)) {
    return Future.value(cachedData);
  }
  if (inFlight != null) {
    return inFlight;
  }
  final future =
      () async {
        final restored = await _restoreLeagueDataCacheEntry(
          _kboLeagueDataCacheKey,
        );
        if (restored != null &&
            _isLeagueDataMemoryCacheFresh(restored.updatedAt, now: now)) {
          _cachedKboLeagueData = restored.data;
          _cachedKboLeagueDataUpdatedAt = restored.updatedAt ?? now;
          return restored.data;
        }
        if (!forceRefresh && cachedData != null) {
          return cachedData;
        }
        try {
          final value = await ApiService.fetchKboLeagueData();
          final fetchedAt = DateTime.now();
          _cachedKboLeagueData = value;
          _cachedKboLeagueDataUpdatedAt = fetchedAt;
          unawaited(_persistLeagueDataCache(_kboLeagueDataCacheKey, value));
          return value;
        } catch (error, stackTrace) {
          debugPrint('KBO league data load failed: $error');
          debugPrint('$stackTrace');
          if (cachedData != null) {
            return cachedData;
          }
          if (restored != null) {
            _cachedKboLeagueData = restored.data;
            _cachedKboLeagueDataUpdatedAt = restored.updatedAt;
            return restored.data;
          }
          final fallback = _emptyKboLeagueData();
          _cachedKboLeagueData = fallback;
          _cachedKboLeagueDataUpdatedAt = null;
          return fallback;
        }
      }().whenComplete(() {
        _cachedKboLeagueDataFuture = null;
      });
  _cachedKboLeagueDataFuture = future;
  return future;
}

Future<({Map<String, dynamic> data, DateTime? updatedAt})?>
_restoreLeagueDataCacheEntry(String key) async {
  try {
    final raw = await _readLocalStateCacheWithLegacySecureStorage(
      key: key,
      legacyStorage: _leagueDataCacheStorage,
    );
    if (raw == null || raw.trim().isEmpty) return null;
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) {
      final data = _fixtureAsMap(decoded['data']);
      final updatedAt = DateTime.tryParse('${decoded['updatedAt'] ?? ''}');
      if (data.isNotEmpty) {
        return (data: data, updatedAt: updatedAt);
      }
      return (data: decoded, updatedAt: null);
    }
    if (decoded is Map) {
      return (
        data: Map<String, dynamic>.from(decoded.cast<Object?, Object?>()),
        updatedAt: null,
      );
    }
  } catch (error, stackTrace) {
    debugPrint('League data cache restore failed ($key): $error');
    debugPrint('$stackTrace');
  }
  return null;
}

Future<Map<String, dynamic>?> _restoreLeagueDataCache(String key) async {
  final restored = await _restoreLeagueDataCacheEntry(key);
  return restored?.data;
}

Future<void> _persistLeagueDataCache(
  String key,
  Map<String, dynamic> value,
) async {
  try {
    await _writeLocalStateCache(
      key,
      jsonEncode(<String, dynamic>{
        'updatedAt': DateTime.now().toIso8601String(),
        'data': value,
      }),
    );
  } catch (error, stackTrace) {
    debugPrint('League data cache persist failed ($key): $error');
    debugPrint('$stackTrace');
  }
}

Map<String, dynamic> _emptyKLeagueLeagueData() => <String, dynamic>{
  'season': ApiService.targetSeason,
  'standings': const <dynamic>[],
  'fixtures': const <dynamic>[],
  'teams': const <dynamic>[],
  'seasons': const <dynamic>[],
};

Map<String, dynamic> _emptyKboLeagueData() => const <String, dynamic>{
  'standings': <dynamic>[],
  'matches': <dynamic>[],
};

bool _isLeagueDataCacheFresh(DateTime? updatedAt, {DateTime? now}) {
  if (updatedAt == null) return false;
  return (now ?? DateTime.now()).difference(updatedAt) <=
      _leagueDataPrimeCacheTtl;
}

bool _isLeagueDataMemoryCacheFresh(DateTime? updatedAt, {DateTime? now}) {
  if (updatedAt == null) return false;
  return (now ?? DateTime.now()).difference(updatedAt) <=
      _leagueDataMemoryCacheTtl;
}

String _kLeagueFixtureDetailDiskCacheKey(int fixtureId) {
  return '$_kLeagueFixtureDetailStorageKeyPrefix.$fixtureId';
}

Future<({Map<String, dynamic> detail, DateTime updatedAt})?>
_restorePersistedKLeagueFixtureDetail(int fixtureId) async {
  try {
    final raw = await _readLocalStateCache(
      _kLeagueFixtureDetailDiskCacheKey(fixtureId),
    );
    if (raw == null || raw.trim().isEmpty) return null;
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) return null;
    final detail = _fixtureAsMap(decoded['detail']);
    if (detail.isEmpty) return null;
    final updatedAt =
        DateTime.tryParse('${decoded['updatedAt'] ?? ''}') ?? DateTime(1970);
    return (detail: detail, updatedAt: updatedAt);
  } catch (error, stackTrace) {
    debugPrint('restorePersistedKLeagueFixtureDetail failed: $error');
    debugPrint('$stackTrace');
    return null;
  }
}

Future<void> _persistKLeagueFixtureDetail(
  int fixtureId,
  Map<String, dynamic> detail,
) async {
  try {
    await _writeLocalStateCache(
      _kLeagueFixtureDetailDiskCacheKey(fixtureId),
      jsonEncode(<String, dynamic>{
        'updatedAt': DateTime.now().toIso8601String(),
        'detail': detail,
      }),
    );
  } catch (error, stackTrace) {
    debugPrint('persistKLeagueFixtureDetail failed: $error');
    debugPrint('$stackTrace');
  }
}

bool _isKLeagueFixtureDetailFinal(Map<String, dynamic> detail) {
  final detailFixture = _fixtureAsMap(detail['fixture']);
  final fixtureMeta = _fixtureAsMap(detailFixture['fixture']);
  final status = _fixtureAsMap(fixtureMeta['status']);
  return _isKLeagueFinalStatus(_fixtureText(status['short']));
}

Future<Map<String, dynamic>> _loadCachedKLeagueFixtureDetail(
  int fixtureId, {
  bool forceRefresh = false,
}) async {
  if (forceRefresh) {
    _cachedKLeagueFixtureDetails.remove(fixtureId);
    _cachedKLeagueFixtureDetailsUpdatedAt.remove(fixtureId);
  }

  final cached = _cachedKLeagueFixtureDetails[fixtureId];
  final cachedAt = _cachedKLeagueFixtureDetailsUpdatedAt[fixtureId];
  if (cached != null) {
    try {
      final detail = await cached;
      if (_isKLeagueFixtureDetailFinal(detail)) return detail;
      if (cachedAt != null &&
          DateTime.now().difference(cachedAt) <= _kLeagueProfileCacheTtl) {
        return detail;
      }
    } catch (_) {
      // Fall through to a fresh fetch below.
    }
  }

  final restored = await _restorePersistedKLeagueFixtureDetail(fixtureId);
  if (restored != null) {
    final future = Future<Map<String, dynamic>>.value(restored.detail);
    _cachedKLeagueFixtureDetails[fixtureId] = future;
    _cachedKLeagueFixtureDetailsUpdatedAt[fixtureId] = restored.updatedAt;
    return restored.detail;
  }

  _cachedKLeagueFixtureDetails.remove(fixtureId);
  _cachedKLeagueFixtureDetailsUpdatedAt.remove(fixtureId);

  final future =
      _runKLeagueFixtureDetailRequestLimited(() async {
        final detail = await ApiService.fetchFixtureDetails(fixtureId);
        _cachedKLeagueFixtureDetailsUpdatedAt[fixtureId] = DateTime.now();
        unawaited(_persistKLeagueFixtureDetail(fixtureId, detail));
        return detail;
      }).catchError((error) {
        _cachedKLeagueFixtureDetails.remove(fixtureId);
        _cachedKLeagueFixtureDetailsUpdatedAt.remove(fixtureId);
        throw error;
      });
  _cachedKLeagueFixtureDetails[fixtureId] = future;
  _cachedKLeagueFixtureDetailsUpdatedAt[fixtureId] = DateTime.now();
  try {
    return await future;
  } catch (error) {
    if (cached != null) {
      try {
        return await cached;
      } catch (_) {}
    }
    if (restored != null) {
      return restored.detail;
    }
    rethrow;
  }
}

bool _kLeagueFixtureMapHasStarted(
  Map<String, dynamic> fixtureMap, {
  DateTime? now,
}) {
  final fixture = _fixtureAsMap(fixtureMap['fixture']);
  final kickoff = DateTime.tryParse(_fixtureText(fixture['date']));
  if (kickoff == null) return false;
  final status = _fixtureAsMap(fixture['status']);
  return !kickoff.isAfter(now ?? DateTime.now()) ||
      _isKLeagueFinalStatus(_fixtureText(status['short'])) ||
      _fixtureMinuteLabel(
        _fixtureText(status['elapsed']),
        _fixtureText(status['extra']),
      ).isNotEmpty;
}

double? _kLeagueAptsFromRoundPoints(Iterable<_PlayerRoundPoints> roundPoints) {
  final appearedRounds = roundPoints.where((entry) => entry.appeared).toList();
  if (appearedRounds.isEmpty) return null;
  return appearedRounds
          .map((entry) => entry.basePoints)
          .fold(0.0, (total, points) => total + points) /
      appearedRounds.length;
}

void _syncKLeaguePlayerAptsCacheFromRoundPoints({
  required String playerName,
  required String club,
  int? preferredNumber,
  required List<_PlayerRoundPoints> roundPoints,
  bool persist = true,
}) {
  _cachedKLeaguePlayerApts[_kLeagueSeasonAptsKey(
    club: club,
    name: playerName,
    preferredNumber: preferredNumber,
  )] = _kLeagueAptsFromRoundPoints(
    roundPoints,
  );
  if (persist) {
    unawaited(_persistKLeaguePlayerAptsCache());
  }
}

Future<double?> _loadKLeaguePlayerAptsShared({
  required String playerName,
  required String club,
  int? preferredNumber,
}) {
  final resolvedMeta = _resolvePlayerMeta(playerName);
  final targetNumber = preferredNumber != null && preferredNumber > 0
      ? preferredNumber
      : resolvedMeta.number;
  final cacheKey = _kLeagueSeasonAptsKey(
    club: club,
    name: playerName,
    preferredNumber: targetNumber,
  );
  final inFlight = _cachedKLeaguePlayerAptsFutures[cacheKey];
  if (inFlight != null) return inFlight;

  final future =
      () async {
        await _restorePersistedKLeaguePlayerAptsCache();
        await _restorePersistedKLeaguePlayerRoundPointsCache();
        final cachedRoundPoints = _cachedKLeagueRoundPointsForPlayer(
          playerName: playerName,
          club: club,
          preferredNumber: targetNumber,
        );
        if (cachedRoundPoints != null) {
          _syncKLeaguePlayerAptsCacheFromRoundPoints(
            playerName: playerName,
            club: club,
            preferredNumber: targetNumber,
            roundPoints: cachedRoundPoints,
          );
          return _cachedKLeaguePlayerApts[cacheKey];
        }
        final cached = _cachedKLeaguePlayerApts[cacheKey];
        if (_cachedKLeaguePlayerApts.containsKey(cacheKey)) {
          return cached;
        }
        final roundPoints = await _loadKLeagueRoundPointsForPlayerShared(
          playerName: playerName,
          club: club,
          preferredNumber: targetNumber,
        );
        _syncKLeaguePlayerAptsCacheFromRoundPoints(
          playerName: playerName,
          club: club,
          preferredNumber: targetNumber,
          roundPoints: roundPoints,
        );
        return _cachedKLeaguePlayerApts[cacheKey];
      }().whenComplete(() {
        _cachedKLeaguePlayerAptsFutures.remove(cacheKey);
      });

  _cachedKLeaguePlayerAptsFutures[cacheKey] = future;
  return future;
}

Future<double?> _loadKboPlayerAptsShared({
  required String playerName,
  required String club,
  int? preferredNumber,
  String? preferredPosition,
  bool allowHistoryFetch = true,
}) {
  final cacheKey = _kboSeasonAptsKey(
    playerName: playerName,
    club: club,
    preferredNumber: preferredNumber,
    preferredPosition: preferredPosition,
  );
  final inFlight = _cachedKboPlayerAptsFutures[cacheKey];
  if (inFlight != null) return inFlight;

  final cachedRoundPoints = _cachedFullSeasonKboRoundPointsForPlayer(
    playerName: playerName,
    club: club,
    preferredNumber: preferredNumber,
    preferredPosition: preferredPosition,
  );
  if (cachedRoundPoints != null) {
    final apts = _kLeagueAptsFromRoundPoints(cachedRoundPoints);
    _cachedKboPlayerApts[cacheKey] = apts;
    return Future.value(apts);
  }
  final roundPointsKey = _kboRoundPointsCacheKey(
    playerName: playerName,
    club: club,
    preferredNumber: preferredNumber,
    preferredPosition: preferredPosition,
  );
  if (_cachedKboPlayerRoundPointsHasFullSeason[roundPointsKey] == true &&
      _cachedKboPlayerApts.containsKey(cacheKey)) {
    return Future.value(_cachedKboPlayerApts[cacheKey]);
  }
  if (!allowHistoryFetch) {
    return Future.value(_cachedKboPlayerApts[cacheKey]);
  }

  final future =
      () async {
        final roundPoints = await _loadKboRoundPointsForPlayerShared(
          playerName: playerName,
          club: club,
          preferredNumber: preferredNumber,
          preferredPosition: preferredPosition,
        );
        final apts = _kLeagueAptsFromRoundPoints(roundPoints);
        _cachedKboPlayerApts[cacheKey] = apts;
        return apts;
      }().whenComplete(() {
        _cachedKboPlayerAptsFutures.remove(cacheKey);
      });

  _cachedKboPlayerAptsFutures[cacheKey] = future;
  return future;
}

Future<List<_PlayerRoundPoints>> _loadKLeagueRoundPointsForPlayerShared({
  required String playerName,
  required String club,
  int? preferredNumber,
  bool forceRefresh = false,
}) async {
  final resolvedMeta = _resolvePlayerMeta(playerName);
  final targetNumber = preferredNumber != null && preferredNumber > 0
      ? preferredNumber
      : resolvedMeta.number;
  final playerCacheKey = _kLeagueRoundPointsCacheKey(
    playerName: playerName,
    club: club,
    preferredNumber: targetNumber,
  );
  if (forceRefresh) {
    _cachedKLeaguePlayerRoundPoints.remove(playerCacheKey);
    _cachedKLeaguePlayerRoundPointsFutures.remove(playerCacheKey);
    _cachedKLeaguePlayerRoundPointsUpdatedAt.remove(playerCacheKey);
    _cachedKLeaguePlayerApts.remove(
      _kLeagueSeasonAptsKey(
        club: club,
        name: playerName,
        preferredNumber: targetNumber,
      ),
    );
    _cachedKLeaguePlayerAptsFutures.remove(
      _kLeagueSeasonAptsKey(
        club: club,
        name: playerName,
        preferredNumber: targetNumber,
      ),
    );
  }
  final cached = _cachedKLeaguePlayerRoundPoints[playerCacheKey];
  if (cached != null) return cached;
  final inFlight = _cachedKLeaguePlayerRoundPointsFutures[playerCacheKey];
  if (inFlight != null) return inFlight;

  final future =
      () async {
        await _restorePersistedKLeaguePlayerRoundPointsCache();
        final restored = _cachedKLeaguePlayerRoundPoints[playerCacheKey];
        if (restored != null && !forceRefresh) {
          return restored;
        }
        final leagueData = await _loadCachedKLeagueLeagueData(
          forceRefresh: forceRefresh,
        );
        final rawFixtures = _fixtureAsList(leagueData['fixtures']);
        final fixtures = _kLeagueFixturesFromApi(rawFixtures);
        final now = DateTime.now();
        final canonicalClub = _canonicalKLeagueClub(club);

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

        final opponentByRound = <int, String>{};
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

          opponentByRound[round] = opponentLabel;
          if (!_kLeagueFixtureMapHasStarted(map, now: now)) continue;
          final fixtureId = _readNullableInt(fixture['id']);
          if (fixtureId == null || fixtureId <= 0) continue;
          relevantFixtures.add((
            round: round,
            fixtureId: fixtureId,
            opponentLabel: opponentLabel,
          ));
        }

        final rounds = <int, _KLeaguePlayerRoundAccumulator>{};
        for (int round = 1; round <= latestRound; round++) {
          rounds[round] = _KLeaguePlayerRoundAccumulator.empty(
            round,
            opponentLabel: opponentByRound[round] ?? '',
          );
        }

        final resolvedFixtures = await Future.wait(
          relevantFixtures.map((fixtureInfo) async {
            try {
              final detail = await _loadCachedKLeagueFixtureDetail(
                fixtureInfo.fixtureId,
                forceRefresh: forceRefresh,
              );
              final score =
                  _kLeagueRoundScoreBreakdownForPlayerFromDetailShared(
                    detail,
                    playerName: playerName,
                    canonicalClub: canonicalClub,
                    number: '$targetNumber',
                    opponentLabel: fixtureInfo.opponentLabel,
                  );
              return (round: fixtureInfo.round, score: score);
            } catch (error, stackTrace) {
              debugPrint(
                'Round points detail load failed for $playerName '
                '(round=${fixtureInfo.round}, fixture=${fixtureInfo.fixtureId}): '
                '$error',
              );
              debugPrint('$stackTrace');
              return null;
            }
          }),
        );
        for (final resolved
            in resolvedFixtures
                .whereType<
                  ({int round, _KLeaguePlayerRoundAccumulator score})
                >()) {
          rounds[resolved.round] =
              (rounds[resolved.round] ??
                      _KLeaguePlayerRoundAccumulator.empty(resolved.round))
                  .merge(resolved.score);
        }

        final result = [
          for (int round = 1; round <= latestRound; round++)
            _PlayerRoundPoints.fromAccumulator(rounds[round]!),
        ];
        final hasMeaningfulScore = result.any((entry) {
          return entry.displayedPoints != 0.0 || entry.details.isNotEmpty;
        });
        if (!forceRefresh && latestRound > 0 && !hasMeaningfulScore) {
          for (final fixtureInfo in relevantFixtures) {
            _cachedKLeagueFixtureDetails.remove(fixtureInfo.fixtureId);
            _cachedKLeagueFixtureDetailsUpdatedAt.remove(fixtureInfo.fixtureId);
          }
          _cachedKLeaguePlayerRoundPoints.remove(playerCacheKey);
          _cachedKLeaguePlayerRoundPointsUpdatedAt.remove(playerCacheKey);
          _persistedKLeaguePlayerRoundPointsEntries.remove(playerCacheKey);
          return _loadKLeagueRoundPointsForPlayerShared(
            playerName: playerName,
            club: club,
            preferredNumber: targetNumber,
            forceRefresh: true,
          );
        }
        _cachedKLeaguePlayerRoundPoints[playerCacheKey] = result;
        _cachedKLeaguePlayerRoundPointsUpdatedAt[playerCacheKey] =
            DateTime.now();
        _syncKLeaguePlayerAptsCacheFromRoundPoints(
          playerName: playerName,
          club: club,
          preferredNumber: targetNumber,
          roundPoints: result,
        );
        _persistedKLeaguePlayerRoundPointsEntries[playerCacheKey] =
            _PersistedPlayerRoundPointsEntry(
              isSoccer: true,
              hasFullSeason: true,
              updatedAt: DateTime.now(),
              roundPoints: result,
            );
        unawaited(_persistKLeaguePlayerRoundPointsCache());
        return result;
      }().whenComplete(() {
        _cachedKLeaguePlayerRoundPointsFutures.remove(playerCacheKey);
      });

  _cachedKLeaguePlayerRoundPointsFutures[playerCacheKey] = future;
  return future;
}

Future<List<_PlayerRoundPoints>> _loadKboRoundPointsForPlayerShared({
  required String playerName,
  required String club,
  int? preferredNumber,
  String? preferredPosition,
  bool forceRefresh = false,
  Set<int>? targetRounds,
  bool logFailures = true,
}) async {
  final resolvedMeta = _resolvePlayerMeta(playerName);
  final targetNumber = preferredNumber != null && preferredNumber > 0
      ? preferredNumber
      : resolvedMeta.number;
  final normalizedClub = _normalizeKboDraftClub(
    club.isNotEmpty ? club : resolvedMeta.club,
  );
  final targetPosition = _normalizeKboProfilePosition(
    (preferredPosition?.isNotEmpty == true
            ? preferredPosition
            : resolvedMeta.position)
        .toString(),
  );
  final playerCacheKey = _kboRoundPointsCacheKey(
    playerName: playerName,
    club: normalizedClub,
    preferredNumber: targetNumber,
    preferredPosition: targetPosition,
  );
  final normalizedTargetRounds = targetRounds == null
      ? null
      : Set<int>.from(targetRounds.where((round) => round > 0));
  final cached = _cachedKboPlayerRoundPoints[playerCacheKey];
  final inFlight = _cachedKboPlayerRoundPointsFutures[playerCacheKey];
  final cachedAt = _cachedKboPlayerRoundPointsUpdatedAt[playerCacheKey];
  final cachedHasFullSeason =
      _cachedKboPlayerRoundPointsHasFullSeason[playerCacheKey] == true;
  final isStale =
      cachedAt == null ||
      DateTime.now().difference(cachedAt) > _kboProfileCacheTtl;

  if (!forceRefresh &&
      cached != null &&
      !isStale &&
      ((normalizedTargetRounds == null && cachedHasFullSeason) ||
          (normalizedTargetRounds != null &&
              _kboRoundPointsCoverTargetRounds(
                cached,
                normalizedTargetRounds,
              )))) {
    return cached;
  }
  if (inFlight != null) {
    final inFlightHasFullSeason =
        _cachedKboPlayerRoundPointsFutureHasFullSeason[playerCacheKey] == true;
    final inFlightTargetRounds =
        _cachedKboPlayerRoundPointsFutureTargetRounds[playerCacheKey];
    final canReuseInFlight = normalizedTargetRounds == null
        ? inFlightHasFullSeason
        : inFlightHasFullSeason ||
              (inFlightTargetRounds != null &&
                  inFlightTargetRounds.isNotEmpty &&
                  normalizedTargetRounds.every(inFlightTargetRounds.contains));
    if (canReuseInFlight) {
      return inFlight;
    }
    return inFlight.then((_) {
      return _loadKboRoundPointsForPlayerShared(
        playerName: playerName,
        club: club,
        preferredNumber: preferredNumber,
        preferredPosition: preferredPosition,
        forceRefresh: forceRefresh,
        targetRounds: targetRounds,
        logFailures: logFailures,
      );
    });
  }

  final future =
      () async {
        await _restorePersistedKLeaguePlayerRoundPointsCache();
        final restored = _cachedKboPlayerRoundPoints[playerCacheKey];
        final restoredHasFullSeason =
            _cachedKboPlayerRoundPointsHasFullSeason[playerCacheKey] == true;
        if (!forceRefresh &&
            restored != null &&
            ((normalizedTargetRounds == null && restoredHasFullSeason) ||
                (normalizedTargetRounds != null &&
                    _kboRoundPointsCoverTargetRounds(
                      restored,
                      normalizedTargetRounds,
                    )))) {
          return restored;
        }
        final previousResult = restored ?? cached;
        final previousHasFullSeason =
            restoredHasFullSeason || cachedHasFullSeason;
        final now = DateTime.now();
        final currentStartedRound = _latestStartedKboFantasyRound(now);
        final previousByRound = <int, _PlayerRoundPoints>{
          for (final entry in previousResult ?? const <_PlayerRoundPoints>[])
            entry.round: entry,
        };
        final leagueData = await _loadCachedKboLeagueData(
          forceRefresh: forceRefresh,
        );
        final rawMatches = _fixtureAsList(leagueData['matches']);
        final frozenCancelledOriginalRounds =
            _kboFrozenCancelledMatchOriginalRounds(leagueData);

        int latestRound = 0;
        final opponentByRound = <int, String>{};
        final relevantMatches =
            <({int round, int matchId, String opponentLabel})>[];

        for (final raw in rawMatches) {
          final match = _fixtureAsMap(raw);
          final matchDate = DateTime.tryParse('${match['date'] ?? ''}');
          if (matchDate == null) continue;

          final homeClub = _normalizeKboDraftClub('${match['home'] ?? ''}');
          final awayClub = _normalizeKboDraftClub('${match['away'] ?? ''}');
          if (homeClub != normalizedClub && awayClub != normalizedClub) {
            continue;
          }

          final currentRound = _kboFantasyRoundForMatchDate(matchDate);
          if (currentRound <= 0) continue;
          final matchId = _readNullableInt(match['id']);
          final effectiveRound = matchId != null && matchId > 0
              ? (frozenCancelledOriginalRounds[matchId] ?? currentRound)
              : currentRound;
          if (effectiveRound <= 0) continue;
          if (normalizedTargetRounds != null &&
              !normalizedTargetRounds.contains(effectiveRound)) {
            continue;
          }

          final opponentLabel = homeClub == normalizedClub
              ? awayClub
              : homeClub;
          opponentByRound[effectiveRound] =
              opponentByRound[effectiveRound] == null ||
                  opponentByRound[effectiveRound]!.isEmpty
              ? opponentLabel
              : opponentByRound[effectiveRound]!;

          final shouldUseFrozenSnapshot =
              matchId != null &&
              matchId > 0 &&
              frozenCancelledOriginalRounds[matchId] == effectiveRound;
          if (!shouldUseFrozenSnapshot &&
              !_kboMatchMapHasStarted(match, now: now)) {
            continue;
          }
          if (effectiveRound > latestRound) latestRound = effectiveRound;
          if (matchId == null || matchId <= 0) continue;
          final hasCachedRound = previousByRound[effectiveRound] != null;
          final isHistoricalRound =
              effectiveRound > 0 && effectiveRound < currentStartedRound;
          if (isHistoricalRound && hasCachedRound) {
            continue;
          }
          relevantMatches.add((
            round: effectiveRound,
            matchId: matchId,
            opponentLabel: opponentLabel,
          ));
        }

        if (latestRound <= 0) return const <_PlayerRoundPoints>[];

        final rounds = <int, _KLeaguePlayerRoundAccumulator>{};
        final roundsToBuild = <int>{
          for (final entry in previousByRound.entries)
            if (normalizedTargetRounds != null
                ? normalizedTargetRounds.contains(entry.key)
                : entry.key <= latestRound)
              entry.key,
          ...opponentByRound.keys,
        };
        if (normalizedTargetRounds == null) {
          roundsToBuild.addAll(<int>[
            for (int round = 1; round <= latestRound; round++) round,
          ]);
        }
        for (final round in roundsToBuild) {
          rounds[round] = _KLeaguePlayerRoundAccumulator.empty(
            round,
            opponentLabel:
                opponentByRound[round] ??
                previousByRound[round]?.opponentLabel ??
                '',
          );
        }

        Future<({int round, _KLeaguePlayerRoundAccumulator score})?>
        resolveMatchRoundScore(
          ({int round, int matchId, String opponentLabel}) matchInfo,
        ) async {
          final isHistoricalRound =
              matchInfo.round > 0 && matchInfo.round < currentStartedRound;
          final refreshAttempts = isHistoricalRound
              ? const <bool>[false]
              : forceRefresh
              ? const <bool>[true]
              : const <bool>[false, true];
          for (final attemptForceRefresh in refreshAttempts) {
            try {
              final detail = await _loadCachedKboMatchDetail(
                matchInfo.matchId,
                forceRefresh: attemptForceRefresh,
                fantasyRound: matchInfo.round,
              );
              final score = _kboRoundScoreBreakdownForPlayerFromDetailShared(
                detail,
                playerName: playerName,
                meta: (
                  position: targetPosition,
                  club: normalizedClub,
                  number: targetNumber,
                ),
                opponentLabel: matchInfo.opponentLabel,
              );
              return (round: matchInfo.round, score: score);
            } catch (error, stackTrace) {
              if (attemptForceRefresh &&
                  logFailures &&
                  _shouldLogKboMatchDetailFailure(
                    matchInfo.matchId,
                    fantasyRound: matchInfo.round,
                  )) {
                debugPrint(
                  'KBO round points detail load failed for $playerName '
                  '(round=${matchInfo.round}, match=${matchInfo.matchId}): '
                  '$error',
                );
                debugPrint('$stackTrace');
              }
            }
          }
          return null;
        }

        final expectedMatchCountsByRound = <int, int>{};
        for (final matchInfo in relevantMatches) {
          expectedMatchCountsByRound.update(
            matchInfo.round,
            (current) => current + 1,
            ifAbsent: () => 1,
          );
        }

        final resolvedMatches =
            <({int round, _KLeaguePlayerRoundAccumulator score})?>[];
        for (
          var start = 0;
          start < relevantMatches.length;
          start += _kboMatchDetailConcurrencyLimit
        ) {
          final end = min(
            start + _kboMatchDetailConcurrencyLimit,
            relevantMatches.length,
          );
          final batch = relevantMatches.sublist(start, end);
          resolvedMatches.addAll(
            await Future.wait(batch.map(resolveMatchRoundScore)),
          );
        }
        final resolvedMatchCountsByRound = <int, int>{};
        final fullyResolvedRounds = <int>{};
        for (final resolved
            in resolvedMatches
                .whereType<
                  ({int round, _KLeaguePlayerRoundAccumulator score})
                >()) {
          resolvedMatchCountsByRound.update(
            resolved.round,
            (current) => current + 1,
            ifAbsent: () => 1,
          );
          rounds[resolved.round] =
              (rounds[resolved.round] ??
                      _KLeaguePlayerRoundAccumulator.empty(resolved.round))
                  .merge(resolved.score);
        }
        for (final entry in expectedMatchCountsByRound.entries) {
          if ((resolvedMatchCountsByRound[entry.key] ?? 0) >= entry.value) {
            fullyResolvedRounds.add(entry.key);
          }
        }

        if (relevantMatches.isNotEmpty &&
            fullyResolvedRounds.isEmpty &&
            previousResult != null) {
          return previousResult;
        }
        if (relevantMatches.isNotEmpty &&
            fullyResolvedRounds.isEmpty &&
            previousResult == null) {
          return const <_PlayerRoundPoints>[];
        }

        final allResultRounds = <int>{
          ...rounds.keys,
          ...previousByRound.keys,
        }.toList()..sort();
        final result = <_PlayerRoundPoints>[];
        for (final round in allResultRounds) {
          if (!fullyResolvedRounds.contains(round) &&
              previousByRound[round] != null) {
            result.add(previousByRound[round]!);
            continue;
          }
          final accumulator = rounds[round];
          if (accumulator == null) continue;
          result.add(_PlayerRoundPoints.fromAccumulator(accumulator));
        }
        final mergedResult = normalizedTargetRounds == null
            ? result
            : _mergePlayerRoundPointsByRound(
                base: previousResult,
                updates: result,
              );
        final hasFullSeason =
            normalizedTargetRounds == null || previousHasFullSeason;
        _cachedKboPlayerRoundPoints[playerCacheKey] = mergedResult;
        _cachedKboPlayerRoundPointsHasFullSeason[playerCacheKey] =
            hasFullSeason;
        _cachedKboPlayerRoundPointsUpdatedAt[playerCacheKey] = DateTime.now();
        if (hasFullSeason) {
          final seasonAptsKey = _kboSeasonAptsKey(
            playerName: playerName,
            club: normalizedClub,
            preferredNumber: targetNumber,
            preferredPosition: targetPosition,
          );
          _cachedKboPlayerApts[seasonAptsKey] = _kLeagueAptsFromRoundPoints(
            mergedResult,
          );
        }
        _persistedKLeaguePlayerRoundPointsEntries[playerCacheKey] =
            _PersistedPlayerRoundPointsEntry(
              isSoccer: false,
              hasFullSeason: hasFullSeason,
              updatedAt: DateTime.now(),
              roundPoints: mergedResult,
            );
        unawaited(_persistKLeaguePlayerRoundPointsCache());
        return mergedResult;
      }().whenComplete(() {
        _cachedKboPlayerRoundPointsFutures.remove(playerCacheKey);
        _cachedKboPlayerRoundPointsFutureHasFullSeason.remove(playerCacheKey);
        _cachedKboPlayerRoundPointsFutureTargetRounds.remove(playerCacheKey);
      });

  _cachedKboPlayerRoundPointsFutures[playerCacheKey] = future;
  _cachedKboPlayerRoundPointsFutureHasFullSeason[playerCacheKey] =
      normalizedTargetRounds == null;
  if (normalizedTargetRounds != null && normalizedTargetRounds.isNotEmpty) {
    _cachedKboPlayerRoundPointsFutureTargetRounds[playerCacheKey] =
        Set<int>.from(normalizedTargetRounds);
  } else {
    _cachedKboPlayerRoundPointsFutureTargetRounds.remove(playerCacheKey);
  }
  return future;
}

_KLeaguePlayerRoundAccumulator _kboRoundScoreBreakdownForPlayerFromDetailShared(
  Map<String, dynamic> detail, {
  required String playerName,
  required ({String position, String club, int number}) meta,
  required String opponentLabel,
}) {
  final playerStats = _fixtureAsList(detail['playerStats']);
  final matchingStats = playerStats
      .map(_fixtureAsMap)
      .whereType<Map<String, dynamic>>()
      .where(
        (entry) => _kboPlayerStatMatchesProfile(entry, playerName, meta: meta),
      )
      .toList();
  if (matchingStats.isEmpty) {
    return _KLeaguePlayerRoundAccumulator.empty(
      _kboFantasyRoundForMatchDate(
        DateTime.tryParse('${_fixtureAsMap(detail['match'])['date'] ?? ''}') ??
            DateTime(2026),
      ),
      opponentLabel: opponentLabel,
    );
  }

  final details = <_PlayerRoundPointDetail>[];
  double points = 0.0;
  var started = false;
  for (final stat in matchingStats) {
    final fantasy = _fixtureAsMap(stat['fantasy']);
    details.addAll(
      _fixtureAsList(fantasy['details'])
          .map((raw) => _playerRoundPointDetailFromJson(_fixtureAsMap(raw)))
          .whereType<_PlayerRoundPointDetail>(),
    );
    points += (fantasy['points'] as num?)?.toDouble() ?? 0.0;
    started = started || stat['started'] == true;
  }
  points = double.parse(points.toStringAsFixed(2));
  final matchStarted = _kboMatchMapHasStarted(_fixtureAsMap(detail['match']));
  final appeared =
      (matchStarted && started) || details.isNotEmpty || points != 0.0;
  return _KLeaguePlayerRoundAccumulator(
    round: _kboFantasyRoundForMatchDate(
      DateTime.tryParse('${_fixtureAsMap(detail['match'])['date'] ?? ''}') ??
          DateTime(2026),
    ),
    basePoints: points,
    appeared: appeared,
    started: started,
    details: details,
    opponentLabel: opponentLabel,
  );
}

_KLeaguePlayerRoundAccumulator
_kLeagueRoundScoreBreakdownForPlayerFromDetailShared(
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
          playerId == targetPlayer.id;
      if (!matchesByNumber && !matchesById) continue;
      targetPlayerStats = playerBlock;
      statsMinutes = _readNullableInt(games['minutes']);
      targetPlayer ??= _LineupPlayer(
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

  final hasEventEvidence =
      subInMinute != null ||
      subOutMinute != null ||
      goalsCount > 0 ||
      assistsCount > 0 ||
      yellowCards > 0 ||
      redCards > 0 ||
      missedPenalties > 0 ||
      ownGoals > 0;
  final hasStatsRecord = targetPlayerStats != null;
  final appeared =
      (statsMinutes != null && statsMinutes > 0) ||
      hasEventEvidence ||
      (started && !hasStatsRecord);
  final rawPlayedMinutes =
      statsMinutes ??
      ((started && !hasStatsRecord)
          ? (subOutMinute ?? totalMinutes)
          : (subInMinute != null ? max(0, totalMinutes - subInMinute) : 0));
  final playedMinutes = appeared ? max(1, min(90, rawPlayedMinutes)) : 0;

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
    started: started,
    details: details,
    opponentLabel: opponentLabel,
  );
}

class PlayerProfilePage extends StatefulWidget {
  final String name;
  final PlayerOwnership ownership;
  final _DocPlayerMeta? metaOverride;
  final Future<void> Function()? onSign;
  final Future<void> Function()? onTradeRequest;
  final Future<void> Function()? onRelease;
  final bool showLockedAction;
  final String? lockedActionMessage;
  const PlayerProfilePage({
    super.key,
    required this.name,
    this.ownership = PlayerOwnership.freeAgent,
    this.metaOverride,
    this.onSign,
    this.onTradeRequest,
    this.onRelease,
    this.showLockedAction = false,
    this.lockedActionMessage,
  });

  @override
  State<PlayerProfilePage> createState() => _PlayerProfilePageState();
}

class _PlayerProfilePageState extends State<PlayerProfilePage> {
  bool _isMyPageOpen = false;
  bool _isLoadingFullKboHistory = false;
  late Future<_PlayerFantasyProfileData?> _fantasyProfileFuture;
  late Future<List<_PlayerRoundPoints>> _roundPointsFuture;
  List<_PlayerRoundPoints> _initialRoundPoints = const <_PlayerRoundPoints>[];
  _PlayerFantasyProfileData? _initialFantasyProfileData;

  @override
  void initState() {
    super.initState();
    _resetProfileFutures();
    unawaited(_hydrateInitialRoundPointsFromPersistedCache());
  }

  @override
  void didUpdateWidget(covariant PlayerProfilePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.name != widget.name ||
        oldWidget.metaOverride?.club != widget.metaOverride?.club ||
        oldWidget.metaOverride?.number != widget.metaOverride?.number ||
        oldWidget.metaOverride?.position != widget.metaOverride?.position) {
      _resetProfileFutures();
      unawaited(_hydrateInitialRoundPointsFromPersistedCache());
    }
  }

  void _toggleMyPage() => setState(() => _isMyPageOpen = !_isMyPageOpen);

  ({String position, String club, int number}) _currentProfileMeta() {
    return widget.metaOverride != null
        ? (
            position: widget.metaOverride!.position,
            club: widget.metaOverride!.club,
            number: widget.metaOverride!.number,
          )
        : _resolvePlayerMeta(widget.name);
  }

  void _resetProfileFutures() {
    final meta = _currentProfileMeta();
    final isSoccerPlayer = _normalizeFantasySoccerPosition(
      meta.position,
    ).isNotEmpty;
    final isKboPlayer = !isSoccerPlayer && _isKnownKboPlayerMeta(meta);
    final cachedRoundPoints = isSoccerPlayer
        ? _cachedKLeagueRoundPointsForPlayer(
            playerName: widget.name,
            club: meta.club,
            preferredNumber: meta.number,
          )
        : (isKboPlayer
              ? _cachedKboRoundPointsForPlayer(
                  playerName: widget.name,
                  club: meta.club,
                  preferredNumber: meta.number,
                  preferredPosition: meta.position,
                )
              : null);
    _initialRoundPoints = cachedRoundPoints == null
        ? const <_PlayerRoundPoints>[]
        : _visibleProfileRoundPoints(
            cachedRoundPoints.reversed.toList(),
            isSoccerPlayer: isSoccerPlayer,
          );
    _initialFantasyProfileData = _resolveFantasyProfileDataSync(
      widget.name,
      meta: meta,
    );
    _roundPointsFuture = _loadRoundPoints(meta);
    _fantasyProfileFuture = _loadFantasyProfileData(meta);
  }

  Future<void> _hydrateInitialRoundPointsFromPersistedCache() async {
    final meta = _currentProfileMeta();
    final isSoccerPlayer = _normalizeFantasySoccerPosition(
      meta.position,
    ).isNotEmpty;
    await _restorePersistedKLeaguePlayerRoundPointsCache();
    if (!mounted) return;
    final restored = isSoccerPlayer
        ? _cachedKLeagueRoundPointsForPlayer(
            playerName: widget.name,
            club: meta.club,
            preferredNumber: meta.number,
          )
        : _cachedKboRoundPointsForPlayer(
            playerName: widget.name,
            club: meta.club,
            preferredNumber: meta.number,
            preferredPosition: meta.position,
          );
    if (restored == null || restored.isEmpty) return;
    final nextInitial = _visibleProfileRoundPoints(
      restored.reversed.toList(),
      isSoccerPlayer: isSoccerPlayer,
    );
    if (listEquals(_initialRoundPoints, nextInitial)) return;
    setState(() {
      _initialRoundPoints = nextInitial;
    });
  }

  Future<void> _loadFullKboRoundHistory(
    ({String position, String club, int number}) meta,
  ) async {
    if (_isLoadingFullKboHistory || !_isKnownKboPlayerMeta(meta)) return;
    setState(() {
      _isLoadingFullKboHistory = true;
      _roundPointsFuture = () async {
        final roundPoints = await _loadKboRoundPointsForPlayerShared(
          playerName: widget.name,
          club: meta.club,
          preferredNumber: meta.number,
          preferredPosition: meta.position,
        );
        return _visibleProfileRoundPoints(
          roundPoints.reversed.toList(),
          isSoccerPlayer: false,
        );
      }();
    });
    try {
      final loaded = await _roundPointsFuture;
      if (!mounted) return;
      setState(() {
        _initialRoundPoints = loaded;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingFullKboHistory = false;
        });
      }
    }
  }

  Future<List<_PlayerRoundPoints>> _loadRoundPoints(
    ({String position, String club, int number}) meta,
  ) async {
    final isSoccerPlayer = _normalizeFantasySoccerPosition(
      meta.position,
    ).isNotEmpty;
    try {
      late final List<_PlayerRoundPoints> roundPoints;
      if (isSoccerPlayer) {
        roundPoints = await _loadKLeagueRoundPointsForPlayerShared(
          playerName: widget.name,
          club: meta.club,
          preferredNumber: meta.number,
        );
      } else if (_isKnownKboPlayerMeta(meta)) {
        await _restorePersistedKLeaguePlayerRoundPointsCache();
        final cachedFullSeason = _cachedFullSeasonKboRoundPointsForPlayer(
          playerName: widget.name,
          club: meta.club,
          preferredNumber: meta.number,
          preferredPosition: meta.position,
        );
        if (cachedFullSeason != null && cachedFullSeason.isNotEmpty) {
          roundPoints = cachedFullSeason;
        } else {
          final currentRound = _latestStartedKboFantasyRound(DateTime.now());
          if (currentRound <= 0) {
            roundPoints = const <_PlayerRoundPoints>[];
          } else {
            roundPoints = await _loadKboRoundPointsForPlayerShared(
              playerName: widget.name,
              club: meta.club,
              preferredNumber: meta.number,
              preferredPosition: meta.position,
              targetRounds: <int>{currentRound},
            );
          }
        }
      } else {
        roundPoints = const <_PlayerRoundPoints>[];
      }
      return _visibleProfileRoundPoints(
        roundPoints.reversed.toList(),
        isSoccerPlayer: isSoccerPlayer,
      );
    } catch (error, stackTrace) {
      debugPrint('Player round points load failed for ${widget.name}: $error');
      debugPrint('$stackTrace');
      return _initialRoundPoints;
    }
  }

  Future<_PlayerFantasyProfileData?> _loadFantasyProfileData(
    ({String position, String club, int number}) meta,
  ) async {
    try {
      final resolved = _resolveFantasyProfileDataSync(widget.name, meta: meta);
      final draft = resolved.draft;
      final homeState = homeKey.currentState;
      final isSoccerPlayer = _normalizeFantasySoccerPosition(
        meta.position,
      ).isNotEmpty;
      if (isSoccerPlayer && draft != null && homeState != null) {
        unawaited(homeState._refreshFantasySoccerScores());
      }
      return resolved;
    } catch (error, stackTrace) {
      debugPrint('Player profile load failed for ${widget.name}: $error');
      debugPrint('$stackTrace');
      return const _PlayerFantasyProfileData(draft: null, team: null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final meta = widget.metaOverride != null
        ? (
            position: widget.metaOverride!.position,
            club: widget.metaOverride!.club,
            number: widget.metaOverride!.number,
          )
        : _resolvePlayerMeta(widget.name);
    // Prefer the app's session ownership cache when available so profiles opened
    // from different entry points (home search, schedule, etc.) stay consistent.
    final profileIdentity = _playerSlotIdentity(
      _PlayerSlot(
        name: widget.name,
        score: 0,
        position: meta.position,
        club: meta.club,
        number: meta.number,
      ),
    );
    final resolvedOwnership =
        _MatchDetailPageState._playerOwnerCache[profileIdentity] ??
        _MatchDetailPageState._playerOwnerCache[widget.name] ??
        widget.ownership;
    final Color text = isDark ? Colors.white : Colors.black87;
    final Color muted = isDark ? Colors.white70 : Colors.black54;
    final Color border = isDark ? Colors.white12 : Colors.black12;
    final isKboProfile =
        _normalizeFantasySoccerPosition(meta.position).isEmpty &&
        _isKnownKboPlayerMeta(meta);
    final displayClub = _displayFantasyClubName(
      meta.club,
      isSoccer: !isKboProfile,
    );

    Widget infoTile(String label, String value, {Color? valueColor}) {
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
                  color: valueColor ?? text,
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
        initialData: _initialFantasyProfileData,
        builder: (context, snapshot) {
          final fantasyData = snapshot.data;
          final fantasyTeamName = fantasyData?.team?.teamName ?? '—';

          Widget roundPointsSection() {
            return FutureBuilder<List<_PlayerRoundPoints>>(
              future: _roundPointsFuture,
              initialData: _initialRoundPoints,
              builder: (context, roundSnapshot) {
                final roundPoints =
                    roundSnapshot.data ?? const <_PlayerRoundPoints>[];
                final hasFullKboHistory =
                    isKboProfile &&
                    _cachedFullSeasonKboRoundPointsForPlayer(
                          playerName: widget.name,
                          club: meta.club,
                          preferredNumber: meta.number,
                          preferredPosition: meta.position,
                        ) !=
                        null;
                if (roundSnapshot.connectionState == ConnectionState.waiting &&
                    roundPoints.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }
                if (roundPoints.isEmpty) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '이전 라운드 포인트가 아직 없습니다.',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: muted,
                        ),
                      ),
                      if (isKboProfile && !hasFullKboHistory) ...[
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: _isLoadingFullKboHistory
                              ? null
                              : () => unawaited(_loadFullKboRoundHistory(meta)),
                          child: Text(
                            _isLoadingFullKboHistory
                                ? '이전 라운드 기록 불러오는 중...'
                                : '이전 라운드 기록 불러오기',
                          ),
                        ),
                      ],
                    ],
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ...roundPoints.map((entry) {
                      final badge = entry.isCaptain
                          ? 'C'
                          : (entry.isViceCaptain ? 'VC' : null);
                      final displayedDetails = isKboProfile
                          ? _groupKboRoundPointDetails(entry.details)
                          : entry.details;
                      final didNotAppear = isKboProfile && !entry.appeared;
                      final opponentLabel = entry.opponentLabel == null
                          ? ''
                          : (isKboProfile
                                ? _displayFantasyOpponentLabel(
                                    entry.opponentLabel!,
                                    isSoccer: false,
                                  )
                                : entry.opponentLabel!);
                      final roundDateLabel = isKboProfile
                          ? _kboFantasyRoundDateLabel(entry.round)
                          : null;
                      final roundHeader = isKboProfile
                          ? (roundDateLabel == null
                                ? '${entry.round} 라운드'
                                : '${entry.round} 라운드 · $roundDateLabel')
                          : (opponentLabel.isEmpty
                                ? '${entry.round} 라운드'
                                : '${entry.round} 라운드 · vs $opponentLabel');
                      final scoreColor = entry.displayedPoints >= 0
                          ? const Color(0xFF2E6BFF)
                          : const Color(0xFFD94141);
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF162235)
                              : const Color(0xFFEFF4FF),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: isDark
                                ? const Color(0xFF30425D)
                                : const Color(0xFFD7E3FF),
                          ),
                          boxShadow: isDark
                              ? const []
                              : const [
                                  BoxShadow(
                                    color: Color(0x122E6BFF),
                                    blurRadius: 14,
                                    offset: Offset(0, 6),
                                  ),
                                ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              roundHeader,
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w900,
                                                color: text,
                                              ),
                                            ),
                                          ),
                                          if (badge != null) ...[
                                            const SizedBox(width: 8),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFDCE8FF),
                                                borderRadius:
                                                    BorderRadius.circular(999),
                                              ),
                                              child: Text(
                                                entry.isCaptain ? 'CAP' : 'VC',
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w900,
                                                  color: Color(0xFF2E6BFF),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      if (entry.isCaptain ||
                                          entry.isViceCaptain)
                                        const SizedBox(height: 6),
                                      if (entry.isCaptain ||
                                          entry.isViceCaptain)
                                        Text(
                                          '${entry.isCaptain ? 'base ${entry.basePoints.toStringAsFixed(1)}' : ''}'
                                          '${entry.isCaptain && entry.isViceCaptain ? ' · ' : ''}'
                                          '${entry.isViceCaptain ? 'VC 적용' : ''}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: muted,
                                          ),
                                        ),
                                      if (isKboProfile &&
                                          opponentLabel.isNotEmpty) ...[
                                        const SizedBox(height: 6),
                                        Text(
                                          'vs $opponentLabel',
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
                                const SizedBox(width: 14),
                                Text(
                                  didNotAppear
                                      ? 'DNP'
                                      : '${entry.displayedPoints.toStringAsFixed(1)} pts',
                                  style: TextStyle(
                                    fontSize: 16,
                                    height: 1.0,
                                    fontWeight: FontWeight.w900,
                                    color: didNotAppear
                                        ? const Color(0xFF667085)
                                        : scoreColor,
                                  ),
                                ),
                              ],
                            ),
                            if (didNotAppear) ...[
                              const SizedBox(height: 12),
                              Text(
                                '출전하지 않음',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: muted,
                                ),
                              ),
                            ] else if (displayedDetails.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              ...displayedDetails.map(
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
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: muted,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        '${detail.points >= 0 ? '+' : ''}${detail.points.toStringAsFixed(1)}',
                                        textAlign: TextAlign.right,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w900,
                                          color: detail.points >= 0
                                              ? const Color(0xFF2E6BFF)
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
                      );
                    }),
                    if (isKboProfile && !hasFullKboHistory) ...[
                      const SizedBox(height: 6),
                      OutlinedButton(
                        onPressed: _isLoadingFullKboHistory
                            ? null
                            : () => unawaited(_loadFullKboRoundHistory(meta)),
                        child: Text(
                          _isLoadingFullKboHistory
                              ? '이전 라운드 기록 불러오는 중...'
                              : '이전 라운드 기록 불러오기',
                        ),
                      ),
                    ],
                  ],
                );
              },
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
                '선수 정보',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: text,
                ),
              ),
              const SizedBox(height: 10),
              infoTile('포지션', meta.position),
              const SizedBox(height: 10),
              infoTile('소속팀', displayClub),
              const SizedBox(height: 10),
              infoTile('등번호', '${meta.number}'),
              const SizedBox(height: 10),
              infoTile('판타지 팀', fantasyTeamName),
              const SizedBox(height: 10),
              FutureBuilder<List<_PlayerRoundPoints>>(
                future: _roundPointsFuture,
                initialData: _initialRoundPoints,
                builder: (context, roundSnapshot) {
                  final roundPoints =
                      roundSnapshot.data ?? const <_PlayerRoundPoints>[];
                  final apts = _kLeagueAptsFromRoundPoints(roundPoints);
                  return infoTile(
                    'Apts',
                    apts == null ? '—' : apts.toStringAsFixed(1),
                    valueColor: _aptsDisplayColor(apts),
                  );
                },
              ),
              const SizedBox(height: 24),
              Text(
                '라운드 Fpts',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: text,
                ),
              ),
              const SizedBox(height: 10),
              roundPointsSection(),
              const SizedBox(height: 24),
              if (widget.showLockedAction &&
                  resolvedOwnership != PlayerOwnership.myTeam)
                ElevatedButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.lock_rounded),
                  label: Text(widget.lockedActionMessage ?? '잠김'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                    disabledBackgroundColor: const Color(0xFFF2F4F7),
                    disabledForegroundColor: const Color(0xFF667085),
                  ),
                ),
              if (widget.showLockedAction &&
                  resolvedOwnership != PlayerOwnership.myTeam)
                const SizedBox(height: 12),
              if (!widget.showLockedAction &&
                  resolvedOwnership == PlayerOwnership.freeAgent)
                ElevatedButton.icon(
                  onPressed: () async {
                    if (widget.onSign != null) {
                      await widget.onSign!.call();
                      return;
                    }
                    await _signFreeAgentFromProfile(context, widget.name);
                  },
                  icon: const Icon(Icons.person_add_alt_1, color: Colors.white),
                  label: const Text('영입'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                    backgroundColor: const Color(0xFF16A34A),
                    foregroundColor: Colors.white,
                  ),
                ),
              if (!widget.showLockedAction &&
                  resolvedOwnership == PlayerOwnership.freeAgent)
                const SizedBox(height: 12),
              if (!widget.showLockedAction &&
                  resolvedOwnership == PlayerOwnership.otherTeam)
                ElevatedButton.icon(
                  onPressed: () async {
                    if (widget.onTradeRequest != null) {
                      await widget.onTradeRequest!.call();
                      return;
                    }
                    await _requestTradeFromProfile(context, widget.name);
                  },
                  icon: const Icon(Icons.swap_horiz, color: Colors.white),
                  label: const Text('트레이드 요청'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                  ),
                ),
              if (!widget.showLockedAction &&
                  resolvedOwnership == PlayerOwnership.otherTeam)
                const SizedBox(height: 12),
              if (!widget.showLockedAction &&
                  resolvedOwnership == PlayerOwnership.myTeam)
                ElevatedButton.icon(
                  onPressed: widget.onRelease == null
                      ? null
                      : () async {
                          await widget.onRelease!.call();
                        },
                  icon: const Icon(
                    Icons.remove_circle_outline,
                    color: Colors.white,
                  ),
                  label: const Text('방출'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                    backgroundColor: const Color(0xFFDC2626),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFFF2F4F7),
                    disabledForegroundColor: const Color(0xFF667085),
                  ),
                ),
              if (!widget.showLockedAction &&
                  resolvedOwnership == PlayerOwnership.myTeam)
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
  const _PlayerFantasyProfileData({required this.draft, required this.team});
}

class _PersistedPlayerRoundPointsEntry {
  final bool isSoccer;
  final bool hasFullSeason;
  final DateTime updatedAt;
  final List<_PlayerRoundPoints> roundPoints;
  const _PersistedPlayerRoundPointsEntry({
    required this.isSoccer,
    required this.hasFullSeason,
    required this.updatedAt,
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
  final bool started;
  final List<_PlayerRoundPointDetail> details;
  final String? opponentLabel;

  const _PlayerRoundPoints({
    required this.round,
    required this.displayedPoints,
    required this.basePoints,
    required this.isCaptain,
    required this.isViceCaptain,
    required this.appeared,
    required this.started,
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
      started: accumulator.started,
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
  final bool started;
  final List<_PlayerRoundPointDetail> details;
  final String? opponentLabel;

  const _KLeaguePlayerRoundAccumulator({
    required this.round,
    required this.basePoints,
    required this.appeared,
    required this.started,
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
      started: false,
      details: const <_PlayerRoundPointDetail>[],
      opponentLabel: opponentLabel,
    );
  }

  _KLeaguePlayerRoundAccumulator merge(_KLeaguePlayerRoundAccumulator other) {
    final mergedLabels = <String>{
      for (final raw in [opponentLabel, other.opponentLabel])
        if (raw != null && raw.trim().isNotEmpty)
          ...raw
              .split('/')
              .map((part) => part.trim())
              .where((part) => part.isNotEmpty),
    }.toList();
    return _KLeaguePlayerRoundAccumulator(
      round: round,
      basePoints: basePoints + other.basePoints,
      appeared: appeared || other.appeared,
      started: started || other.started,
      details: [...details, ...other.details],
      opponentLabel: mergedLabels.isEmpty ? null : mergedLabels.join(' / '),
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
  if (!context.mounted) return;

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
