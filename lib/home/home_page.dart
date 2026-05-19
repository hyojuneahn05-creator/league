import 'dart:async';
import 'dart:math';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:leagueit/app_settings.dart';
import 'package:leagueit/auth/auth_controller.dart';
import 'package:leagueit/services/api_service.dart';
import 'package:leagueit/services/league_service.dart';

part 'widgets/custom_app_bar.dart';
part 'widgets/my_page_card.dart';
part 'widgets/side_menu.dart';
part 'widgets/card_switcher.dart';
part 'widgets/card_base.dart';
part 'widgets/shared_cards.dart';
part 'pages/simple_page.dart';
part 'pages/create_league_page.dart';
part 'pages/join_league_page.dart';
part 'pages/login_page.dart';
part 'pages/sign_up_page.dart';
part 'pages/faq_page.dart';
part 'pages/match_detail_page.dart';
part 'pages/roster_page.dart';
part 'pages/league_page.dart';
part 'pages/privacy_policy_page.dart';
part 'pages/profile_page.dart';
part 'pages/password_page.dart';
part 'pages/my_league_page.dart';
part 'pages/about_page.dart';
part 'pages/playbook_page.dart';
part 'pages/settings_page.dart';
part 'pages/draft_page.dart';
part 'pages/player_profile_page.dart';
part 'data/doc_player_meta.dart';
part 'pages/team_page.dart';
part 'pages/standings_page.dart';
part 'pages/schedule_page.dart';

final GlobalKey<LeagueItHomePageState> homeKey =
    GlobalKey<LeagueItHomePageState>();

// Hide placeholder league/match/standings data until real data is connected.
const bool kUseMockDataOutsideDraft = false;
const Duration _koreaTimeOffset = Duration(hours: 9);

DateTime _toKst(DateTime value) => value.toUtc().add(_koreaTimeOffset);

String _twoDigits(int value) => value.toString().padLeft(2, '0');

String _kstMonthDayTimeLabel(DateTime value) {
  final kst = _toKst(value);
  return '${kst.month}/${kst.day} ${_twoDigits(kst.hour)}:${_twoDigits(kst.minute)}';
}

String _kstDotDateTimeLabel(DateTime value) {
  final kst = _toKst(value);
  return '${kst.year}.${_twoDigits(kst.month)}.${_twoDigits(kst.day)} '
      '${_twoDigits(kst.hour)}:${_twoDigits(kst.minute)}';
}

// ---------------------------------------------------------------------------
// Fantasy league (mock) data used across My League + Matchup details (League).
// Keep this centralized so ranks/standings stay consistent in the UI.
// ---------------------------------------------------------------------------

class _FantasyLeagueStanding {
  final String team;
  final int pts;
  const _FantasyLeagueStanding({required this.team, required this.pts});
}

class _JoinedDraft {
  final String leagueId;
  final String leagueName;
  final DateTime when;
  final bool isSoccer;
  final int teamCount;
  final int roundCount;
  final int memberCount;
  final String inviteCode;
  final String ownerId;
  final List<_DraftOrderEntry> draftOrder;
  final bool fantasyReady;
  final List<_FantasyTeamState> fantasyTeams;
  final List<_FantasyScheduleMatchup> fantasySchedule;
  final List<List<_PlayerSlot?>> draftBoard;

  const _JoinedDraft({
    required this.leagueId,
    required this.leagueName,
    required this.when,
    required this.isSoccer,
    this.teamCount = 8,
    this.roundCount = 1,
    this.memberCount = 1,
    this.inviteCode = '',
    this.ownerId = '',
    this.draftOrder = const [],
    this.fantasyReady = false,
    this.fantasyTeams = const [],
    this.fantasySchedule = const [],
    this.draftBoard = const [],
  });
}

class _DraftOrderEntry {
  final String uid;
  final String displayName;
  final int slot;

  const _DraftOrderEntry({
    required this.uid,
    required this.displayName,
    required this.slot,
  });
}

class _FantasyTeamPlayer {
  final String name;
  final String position;
  final int score;

  const _FantasyTeamPlayer({
    required this.name,
    required this.position,
    required this.score,
  });

  _PlayerSlot toPlayerSlot() =>
      _PlayerSlot(name: name, score: score, position: position);

  Map<String, dynamic> toMap() => {
    'name': name,
    'position': position,
    'score': score,
  };
}

class _FantasyTeamState {
  final String uid;
  final String teamName;
  final List<_FantasyTeamPlayer> roster;
  final List<_FantasyTeamPlayer> starting;
  final List<_FantasyTeamPlayer> bench;

  const _FantasyTeamState({
    required this.uid,
    required this.teamName,
    this.roster = const [],
    this.starting = const [],
    this.bench = const [],
  });

  Map<String, dynamic> toMap() => {
    'uid': uid,
    'teamName': teamName,
    'roster': roster.map((player) => player.toMap()).toList(),
    'starting': starting.map((player) => player.toMap()).toList(),
    'bench': bench.map((player) => player.toMap()).toList(),
  };
}

class _FantasyTeamBranding {
  final IconData icon;
  final Color tint;
  static const Color defaultIconColor = Color(0xFF1E6B3A);

  const _FantasyTeamBranding({required this.icon, required this.tint});
}

const List<_FantasyTeamBranding> _fantasyTeamBrandings = [
  _FantasyTeamBranding(icon: Icons.shield_outlined, tint: Color(0xFFD7F8E0)),
  _FantasyTeamBranding(
    icon: Icons.workspace_premium_outlined,
    tint: Color(0xFFECFFB8),
  ),
  _FantasyTeamBranding(
    icon: Icons.military_tech_outlined,
    tint: Color(0xFFFFE2BE),
  ),
  _FantasyTeamBranding(
    icon: Icons.flag_circle_outlined,
    tint: Color(0xFFDDEBFF),
  ),
  _FantasyTeamBranding(icon: Icons.stars_outlined, tint: Color(0xFFF7DDF7)),
  _FantasyTeamBranding(
    icon: Icons.emoji_events_outlined,
    tint: Color(0xFFFFF0C4),
  ),
  _FantasyTeamBranding(
    icon: Icons.health_and_safety_outlined,
    tint: Color(0xFFE3F4FF),
  ),
  _FantasyTeamBranding(icon: Icons.verified_outlined, tint: Color(0xFFE4F7CF)),
];

int _stableSeedForBrand(String key) {
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

_FantasyTeamBranding _fantasyTeamBrandingFor({
  required String uid,
  required String teamName,
}) {
  final seedKey = uid.isNotEmpty ? '$uid|$teamName' : teamName;
  final index = _stableSeedForBrand(seedKey) % _fantasyTeamBrandings.length;
  return _fantasyTeamBrandings[index];
}

class _FantasyScheduleMatchup {
  final int round;
  final String homeUid;
  final String homeTeam;
  final String awayUid;
  final String awayTeam;

  const _FantasyScheduleMatchup({
    required this.round,
    required this.homeUid,
    required this.homeTeam,
    required this.awayUid,
    required this.awayTeam,
  });

  Map<String, dynamic> toMap() => {
    'round': round,
    'homeUid': homeUid,
    'homeTeam': homeTeam,
    'awayUid': awayUid,
    'awayTeam': awayTeam,
  };
}

class _FantasyMatchupView {
  final _JoinedDraft draft;
  final int round;
  final _FantasyScheduleMatchup matchup;
  final _FantasyTeamState myTeam;
  final _FantasyTeamState opponent;
  final double myScore;
  final double opponentScore;

  const _FantasyMatchupView({
    required this.draft,
    required this.round,
    required this.matchup,
    required this.myTeam,
    required this.opponent,
    required this.myScore,
    required this.opponentScore,
  });
}

const Duration _draftPickDuration = Duration(seconds: 90);
const Duration _draftRetentionWindow = Duration(hours: 24);

int _draftRoundsForSport(bool isSoccer) => isSoccer ? 18 : 21;

Duration _draftTotalDuration({required bool isSoccer, required int teamCount}) {
  final safeTeamCount = teamCount <= 0 ? 8 : teamCount;
  return Duration(
    seconds:
        _draftPickDuration.inSeconds *
        _draftRoundsForSport(isSoccer) *
        safeTeamCount,
  );
}

DateTime _draftEndsAt(_JoinedDraft draft) {
  return draft.when.add(
    _draftTotalDuration(isSoccer: draft.isSoccer, teamCount: draft.teamCount),
  );
}

bool _isDraftCompletedAt(_JoinedDraft draft, DateTime now) {
  return !now.isBefore(_draftEndsAt(draft));
}

bool _isDraftExpiredAt(_JoinedDraft draft, DateTime now) {
  return !now.isBefore(draft.when.add(_draftRetentionWindow));
}

Duration _fantasyRoundInterval(bool isSoccer) =>
    isSoccer ? const Duration(days: 7) : const Duration(days: 1);

int _currentFantasyRoundAt(_JoinedDraft draft, DateTime now) {
  final roundCount = max(1, draft.roundCount);
  if (now.isBefore(draft.when)) return 1;
  final interval = _fantasyRoundInterval(draft.isSoccer);
  final elapsed = now.difference(draft.when);
  final round = (elapsed.inSeconds ~/ interval.inSeconds) + 1;
  return round.clamp(1, roundCount);
}

const Duration _fantasySoccerScoreCacheTtl = Duration(seconds: 20);

class _FantasySoccerRoundScoreSnapshot {
  final String leagueId;
  final int round;
  final DateTime generatedAt;
  final bool finalized;
  final Map<String, double> basePlayerScores;
  final Map<String, double> displayedPlayerScores;
  final Map<String, double> teamScores;
  final Map<String, String?> captainNames;
  final Map<String, String?> viceCaptainNames;

  const _FantasySoccerRoundScoreSnapshot({
    required this.leagueId,
    required this.round,
    required this.generatedAt,
    required this.finalized,
    required this.basePlayerScores,
    required this.displayedPlayerScores,
    required this.teamScores,
    required this.captainNames,
    required this.viceCaptainNames,
  });
}

final Map<String, _FantasySoccerRoundScoreSnapshot>
_fantasySoccerRoundScoreCache = <String, _FantasySoccerRoundScoreSnapshot>{};
final Map<String, Future<_FantasySoccerRoundScoreSnapshot>>
_fantasySoccerRoundScoreInFlight =
    <String, Future<_FantasySoccerRoundScoreSnapshot>>{};

String _fantasyTeamIdentity({required String uid, required String teamName}) =>
    uid.trim().isNotEmpty ? uid.trim() : teamName.trim();

String _fantasySoccerPlayerCacheKey({
  required String teamUid,
  required String teamName,
  required String playerName,
}) => '${_fantasyTeamIdentity(uid: teamUid, teamName: teamName)}|$playerName';

String _fantasySoccerRoundCacheKey(_JoinedDraft draft, int round) =>
    '${draft.leagueId}|$round';

String _normalizeFantasySoccerPosition(String raw) {
  switch (raw.trim().toUpperCase()) {
    case 'GK':
    case 'G':
      return 'GK';
    case 'DF':
    case 'D':
      return 'DF';
    case 'MF':
    case 'M':
      return 'MF';
    case 'FW':
    case 'F':
      return 'FW';
    default:
      return '';
  }
}

bool _isKLeagueFinalStatus(String short) {
  switch (short.trim().toUpperCase()) {
    case 'FT':
    case 'AET':
    case 'PEN':
      return true;
    default:
      return false;
  }
}

double _kLeagueGoalPoints(String position) {
  switch (position) {
    case 'GK':
      return 10;
    case 'DF':
      return 7;
    case 'MF':
      return 6;
    case 'FW':
      return 5;
    default:
      return 0;
  }
}

double _kLeagueAssistPoints(String position) {
  switch (position) {
    case 'GK':
      return 5;
    case 'DF':
    case 'MF':
    case 'FW':
      return 3;
    default:
      return 0;
  }
}

double _kLeagueCleanSheetPoints(String position) {
  switch (position) {
    case 'GK':
    case 'DF':
      return 3;
    default:
      return 0;
  }
}

Map<String, String> _kLeagueLineupClubLookup(List<dynamic> lineups) {
  final lookup = <String, String>{};
  for (final rawLineup in lineups) {
    final lineup = _fixtureAsMap(rawLineup);
    final team = _fixtureAsMap(lineup['team']);
    final club = _canonicalKLeagueClub(
      _kLeagueDisplayTeamName(_fixtureText(team['name'])),
    );
    if (club.isEmpty) continue;
    for (final raw in [
      ..._fixtureAsList(lineup['startXI']),
      ..._fixtureAsList(lineup['substitutes']),
    ]) {
      final player = _lineupPlayerFromRaw(raw, lineup: lineup);
      if (player == null) continue;
      if (player.id.isNotEmpty) lookup[player.id] = club;
      lookup[player.originalName] = club;
      lookup[player.name] = club;
    }
  }
  return lookup;
}

Map<String, int> _kLeagueOwnGoalCounts(
  List<dynamic> events,
  Map<String, String> playerNames,
  Map<String, String> clubLookup,
) {
  final counts = <String, int>{};
  for (final raw in events) {
    final event = _fixtureAsMap(raw);
    if (_fixtureText(event['type']) != 'Goal') continue;
    if (_fixtureText(event['detail']) != 'Own Goal') continue;
    final player = _fixtureAsMap(event['player']);
    final displayName = _eventPlayerDisplayName(player, playerNames);
    if (displayName.isEmpty) continue;
    final playerId = _fixtureText(player['id']);
    final club = clubLookup[playerId].toString().trim().isNotEmpty
        ? clubLookup[playerId]!
        : (clubLookup[displayName] ?? '');
    if (club.isEmpty) continue;
    final key = '$club|$displayName';
    counts.update(key, (value) => value + 1, ifAbsent: () => 1);
  }
  return counts;
}

int _kLeagueEventMinuteValue(Map<String, dynamic> time) {
  final elapsed = _readNullableInt(time['elapsed']) ?? 0;
  final extra = _readNullableInt(time['extra']) ?? 0;
  return min(90, elapsed + extra);
}

int _kLeagueFixtureTotalMinutes(
  Map<String, dynamic> fixtureMeta,
  List<dynamic> events,
) {
  final status = _fixtureAsMap(fixtureMeta['status']);
  final elapsed = _readNullableInt(status['elapsed']) ?? 0;
  var total = max(90, min(90, elapsed));
  for (final raw in events) {
    final event = _fixtureAsMap(raw);
    total = max(total, _kLeagueEventMinuteValue(_fixtureAsMap(event['time'])));
  }
  return min(90, max(90, total));
}

Map<String, String> _kLeagueLineupPositionLookup(List<dynamic> lineups) {
  final lookup = <String, String>{};
  for (final rawLineup in lineups) {
    final lineup = _fixtureAsMap(rawLineup);
    for (final raw in [
      ..._fixtureAsList(lineup['startXI']),
      ..._fixtureAsList(lineup['substitutes']),
    ]) {
      final player = _lineupPlayerFromRaw(raw, lineup: lineup);
      if (player == null) continue;
      final normalized = _normalizeFantasySoccerPosition(player.position);
      if (normalized.isEmpty) continue;
      if (player.id.isNotEmpty) lookup[player.id] = normalized;
      lookup[player.originalName] = normalized;
      lookup[player.name] = normalized;
    }
  }
  return lookup;
}

String _kLeagueEventPlayerPosition(
  Map<String, dynamic> player,
  Map<String, String> playerNames,
  Map<String, String> positionLookup,
) {
  final id = _fixtureText(player['id']);
  if (id.isNotEmpty && positionLookup[id] != null) return positionLookup[id]!;
  final displayName = _eventPlayerDisplayName(player, playerNames);
  if (displayName.isNotEmpty && positionLookup[displayName] != null) {
    return positionLookup[displayName]!;
  }
  final originalName = _fixtureText(player['name']);
  return positionLookup[originalName] ?? '';
}

String _kLeagueRosterNameForClubNumber(String club, String number) {
  final jersey = int.tryParse(number.trim());
  if (jersey == null) return '';
  final canonicalClub = _canonicalKLeagueClub(club);
  for (final entry in _docRosterEntries) {
    if (entry.meta.number != jersey) continue;
    if (_canonicalKLeagueClub(entry.meta.club) == canonicalClub) {
      return entry.name;
    }
  }
  return '';
}

String _kLeagueScoreLookupKeyFromDetail(
  Map<String, dynamic> detail, {
  required String playerName,
  required String canonicalClub,
  required String number,
  Map<String, double>? scores,
}) {
  final lookup = scores ?? _kLeagueFantasyBaseScoresFromDetail(detail);
  final directKey = '$canonicalClub|$playerName';
  if (lookup.containsKey(directKey)) return directKey;

  final rosterName = _kLeagueRosterNameForClubNumber(canonicalClub, number);
  if (rosterName.isNotEmpty) {
    final rosterKey = '$canonicalClub|$rosterName';
    if (lookup.containsKey(rosterKey)) return rosterKey;
  }

  final lineups = _fixtureAsList(detail['lineups']);
  for (final rawLineup in lineups) {
    final lineup = _fixtureAsMap(rawLineup);
    final team = _fixtureAsMap(lineup['team']);
    final club = _canonicalKLeagueClub(
      _kLeagueDisplayTeamName(_fixtureText(team['name'])),
    );
    if (club != canonicalClub) continue;
    for (final raw in [
      ..._fixtureAsList(lineup['startXI']),
      ..._fixtureAsList(lineup['substitutes']),
    ]) {
      final player = _lineupPlayerFromRaw(raw, lineup: lineup);
      if (player == null) continue;
      if (player.number.trim() == number.trim()) {
        final key = '$canonicalClub|${player.name}';
        if (lookup.containsKey(key)) return key;
      }
    }
  }

  return directKey;
}

Map<String, double> _kLeagueFantasyBaseScoresFromDetail(
  Map<String, dynamic> detail,
) {
  final detailFixture = _fixtureAsMap(detail['fixture']);
  final fixtureMeta = _fixtureAsMap(detailFixture['fixture']);
  final teams = _fixtureAsMap(detailFixture['teams']);
  final goals = _fixtureAsMap(detailFixture['goals']);
  final lineups = _fixtureAsList(detail['lineups']);
  final events = _fixtureAsList(detail['events']);
  final playerNames = _eventPlayerNameMap(lineups);
  final clubLookup = _kLeagueLineupClubLookup(lineups);
  final positionLookup = _kLeagueLineupPositionLookup(lineups);
  final ownGoalCounts = _kLeagueOwnGoalCounts(events, playerNames, clubLookup);
  final totalMinutes = _kLeagueFixtureTotalMinutes(fixtureMeta, events);

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
  final status = _fixtureAsMap(fixtureMeta['status']);
  final isFinal = _isKLeagueFinalStatus(_fixtureText(status['short']));

  final resultBonusByClub = <String, double>{};
  if (isFinal) {
    if (homeGoals > awayGoals) {
      resultBonusByClub[homeClub] = 3;
      resultBonusByClub[awayClub] = 0;
    } else if (homeGoals < awayGoals) {
      resultBonusByClub[homeClub] = 0;
      resultBonusByClub[awayClub] = 3;
    } else {
      resultBonusByClub[homeClub] = 1;
      resultBonusByClub[awayClub] = 1;
    }
  }

  final scores = <String, double>{};
  final subOutMinuteByKey = <String, int>{};
  final subInMinuteByKey = <String, int>{};

  void addScore(String key, double value) {
    if (key.isEmpty) return;
    scores.update(key, (current) => current + value, ifAbsent: () => value);
  }

  for (final raw in events) {
    final event = _fixtureAsMap(raw);
    final type = _fixtureText(event['type']);
    final detailText = _fixtureText(event['detail']);
    final player = _fixtureAsMap(event['player']);
    final assist = _fixtureAsMap(event['assist']);
    final minute = _kLeagueEventMinuteValue(_fixtureAsMap(event['time']));

    if (type == 'subst' || type == 'Subst') {
      final outName = _eventPlayerDisplayName(player, playerNames);
      final inName = _eventPlayerDisplayName(assist, playerNames);
      final outClub =
          clubLookup[_fixtureText(player['id'])].toString().trim().isNotEmpty
          ? clubLookup[_fixtureText(player['id'])]!
          : (clubLookup[outName] ?? '');
      final inClub =
          clubLookup[_fixtureText(assist['id'])].toString().trim().isNotEmpty
          ? clubLookup[_fixtureText(assist['id'])]!
          : (clubLookup[inName] ?? '');
      if (outName.isNotEmpty && outClub.isNotEmpty) {
        subOutMinuteByKey['$outClub|$outName'] = minute;
      }
      if (inName.isNotEmpty && inClub.isNotEmpty) {
        subInMinuteByKey['$inClub|$inName'] = minute;
      }
      continue;
    }

    if (type == 'Goal') {
      final scorerName = _eventPlayerDisplayName(player, playerNames);
      final scorerClub =
          clubLookup[_fixtureText(player['id'])].toString().trim().isNotEmpty
          ? clubLookup[_fixtureText(player['id'])]!
          : (clubLookup[scorerName] ?? '');
      if (detailText == 'Own Goal') {
        // Handled from lineup-based own-goal map below.
      } else if (detailText == 'Missed Penalty') {
        if (scorerName.isNotEmpty && scorerClub.isNotEmpty) {
          addScore('$scorerClub|$scorerName', -1);
        }
      } else if (scorerName.isNotEmpty && scorerClub.isNotEmpty) {
        final position = _kLeagueEventPlayerPosition(
          player,
          playerNames,
          positionLookup,
        );
        addScore('$scorerClub|$scorerName', _kLeagueGoalPoints(position));
      }

      final assistName = _eventPlayerDisplayName(assist, playerNames);
      final assistClub =
          clubLookup[_fixtureText(assist['id'])].toString().trim().isNotEmpty
          ? clubLookup[_fixtureText(assist['id'])]!
          : (clubLookup[assistName] ?? '');
      if (assistName.isNotEmpty && assistClub.isNotEmpty) {
        final assistPosition = _kLeagueEventPlayerPosition(
          assist,
          playerNames,
          positionLookup,
        );
        addScore(
          '$assistClub|$assistName',
          _kLeagueAssistPoints(assistPosition),
        );
      }
      continue;
    }

    if (type == 'Card') {
      final cardName = _eventPlayerDisplayName(player, playerNames);
      final cardClub =
          clubLookup[_fixtureText(player['id'])].toString().trim().isNotEmpty
          ? clubLookup[_fixtureText(player['id'])]!
          : (clubLookup[cardName] ?? '');
      if (cardName.isEmpty || cardClub.isEmpty) continue;
      if (detailText.contains('Red')) {
        addScore('$cardClub|$cardName', -3);
      } else if (detailText.contains('Yellow')) {
        addScore('$cardClub|$cardName', -1);
      }
    }
  }

  for (final rawLineup in lineups) {
    final lineup = _fixtureAsMap(rawLineup);
    final team = _fixtureAsMap(lineup['team']);
    final club = _canonicalKLeagueClub(
      _kLeagueDisplayTeamName(_fixtureText(team['name'])),
    );
    final teamBonus = resultBonusByClub[club] ?? 0;
    final cleanSheetPoints =
        isFinal &&
            ((club == homeClub && awayGoals == 0) ||
                (club == awayClub && homeGoals == 0))
        ? 3.0
        : 0.0;

    for (final rawPlayer in _fixtureAsList(lineup['startXI'])) {
      final player = _lineupPlayerFromRaw(rawPlayer, lineup: lineup);
      if (player == null) continue;
      final key = '$club|${player.name}';
      final minutes = (subOutMinuteByKey[key] ?? totalMinutes).toDouble();
      final playerCleanSheetPoints = cleanSheetPoints > 0
          ? _kLeagueCleanSheetPoints(player.position)
          : 0.0;
      addScore(
        key,
        minutes * 0.1 +
            teamBonus +
            playerCleanSheetPoints +
            (ownGoalCounts[key] ?? 0) * -2,
      );
    }

    for (final rawPlayer in _fixtureAsList(lineup['substitutes'])) {
      final player = _lineupPlayerFromRaw(rawPlayer, lineup: lineup);
      if (player == null) continue;
      final key = '$club|${player.name}';
      final enteredAt = subInMinuteByKey[key];
      if (enteredAt == null) {
        addScore(key, (ownGoalCounts[key] ?? 0) * -2);
        continue;
      }
      final minutes = max(0, totalMinutes - enteredAt).toDouble();
      final playerCleanSheetPoints = cleanSheetPoints > 0
          ? _kLeagueCleanSheetPoints(player.position)
          : 0.0;
      addScore(
        key,
        minutes * 0.1 +
            teamBonus +
            playerCleanSheetPoints +
            (ownGoalCounts[key] ?? 0) * -2,
      );
    }
  }

  final expandedScores = Map<String, double>.from(scores);
  for (final rawLineup in lineups) {
    final lineup = _fixtureAsMap(rawLineup);
    final team = _fixtureAsMap(lineup['team']);
    final club = _canonicalKLeagueClub(
      _kLeagueDisplayTeamName(_fixtureText(team['name'])),
    );
    for (final rawPlayer in [
      ..._fixtureAsList(lineup['startXI']),
      ..._fixtureAsList(lineup['substitutes']),
    ]) {
      final player = _lineupPlayerFromRaw(rawPlayer, lineup: lineup);
      if (player == null) continue;
      final key = '$club|${player.name}';
      final value = scores[key];
      if (value == null) continue;
      expandedScores[key] = value;
      if (player.originalName.trim().isNotEmpty) {
        expandedScores['$club|${player.originalName.trim()}'] = value;
      }
      final rosterName = _kLeagueRosterNameForClubNumber(club, player.number);
      if (rosterName.isNotEmpty) {
        expandedScores['$club|$rosterName'] = value;
      }
    }
  }

  return expandedScores;
}

Future<_FantasySoccerRoundScoreSnapshot>
_computeFantasySoccerRoundScoreSnapshot(_JoinedDraft draft, int round) async {
  final roundStart = draft.when.toUtc().add(Duration(days: 7 * (round - 1)));
  final roundEnd = roundStart.add(const Duration(days: 7));
  final nowUtc = DateTime.now().toUtc();
  final leagueData = await ApiService.fetchLeagueData();
  final rawFixtures = _fixtureAsList(leagueData['fixtures']);
  final relevantFixtures = <Map<String, dynamic>>[];

  for (final raw in rawFixtures) {
    final map = _fixtureAsMap(raw);
    final fixture = _fixtureAsMap(map['fixture']);
    final kickoff = DateTime.tryParse(_fixtureText(fixture['date']))?.toUtc();
    if (kickoff == null) continue;
    if (kickoff.isBefore(roundStart) || !kickoff.isBefore(roundEnd)) continue;
    relevantFixtures.add(map);
  }

  var allFinal = relevantFixtures.isNotEmpty || nowUtc.isAfter(roundEnd);
  final baseByClubAndPlayer = <String, double>{};

  for (final rawFixture in relevantFixtures) {
    final fixture = _fixtureAsMap(rawFixture['fixture']);
    final fixtureId = _readNullableInt(fixture['id']);
    if (fixtureId == null || fixtureId <= 0) {
      allFinal = false;
      continue;
    }

    final detail = await ApiService.fetchFixtureDetails(fixtureId);
    final detailFixture = _fixtureAsMap(detail['fixture']);
    final fixtureMeta = _fixtureAsMap(detailFixture['fixture']);
    final status = _fixtureAsMap(fixtureMeta['status']);
    final statusShort = _fixtureText(status['short']);
    final isFinal = _isKLeagueFinalStatus(statusShort);
    if (!isFinal) allFinal = false;
    final fixtureScores = _kLeagueFantasyBaseScoresFromDetail(detail);
    fixtureScores.forEach(
      (key, score) => baseByClubAndPlayer.update(
        key,
        (value) => value + score,
        ifAbsent: () => score,
      ),
    );
  }

  final basePlayerScores = <String, double>{};
  final displayedPlayerScores = <String, double>{};
  final teamScores = <String, double>{};
  final captainNames = <String, String?>{};
  final viceCaptainNames = <String, String?>{};

  for (final team in draft.fantasyTeams) {
    final teamKey = _fantasyTeamIdentity(
      uid: team.uid,
      teamName: team.teamName,
    );
    double baseScoreFor(_FantasyTeamPlayer player) {
      final meta = _resolvePlayerMeta(player.name);
      final clubKey = _canonicalKLeagueClub(meta.club);
      return baseByClubAndPlayer['$clubKey|${player.name}'] ?? 0;
    }

    final rankedStarters = [...team.starting]
      ..sort((a, b) {
        final scoreCompare = baseScoreFor(b).compareTo(baseScoreFor(a));
        if (scoreCompare != 0) return scoreCompare;
        return a.name.compareTo(b.name);
      });
    final captain = rankedStarters.isEmpty ? null : rankedStarters.first.name;
    final viceCaptain = rankedStarters.length < 2
        ? null
        : rankedStarters[1].name;
    captainNames[teamKey] = captain;
    viceCaptainNames[teamKey] = viceCaptain;

    for (final player in team.roster) {
      final base = baseScoreFor(player);
      final displayed = player.name == captain ? base * 2 : base;
      final playerKey = _fantasySoccerPlayerCacheKey(
        teamUid: team.uid,
        teamName: team.teamName,
        playerName: player.name,
      );
      basePlayerScores[playerKey] = base;
      displayedPlayerScores[playerKey] = displayed;
    }

    teamScores[teamKey] = team.starting.fold<double>(
      0,
      (total, player) =>
          total +
          (displayedPlayerScores[_fantasySoccerPlayerCacheKey(
                teamUid: team.uid,
                teamName: team.teamName,
                playerName: player.name,
              )] ??
              0),
    );
  }

  return _FantasySoccerRoundScoreSnapshot(
    leagueId: draft.leagueId,
    round: round,
    generatedAt: DateTime.now(),
    finalized: allFinal,
    basePlayerScores: basePlayerScores,
    displayedPlayerScores: displayedPlayerScores,
    teamScores: teamScores,
    captainNames: captainNames,
    viceCaptainNames: viceCaptainNames,
  );
}

Future<_FantasySoccerRoundScoreSnapshot> _ensureFantasySoccerRoundScoreSnapshot(
  _JoinedDraft draft,
  int round, {
  bool force = false,
}) {
  final cacheKey = _fantasySoccerRoundCacheKey(draft, round);
  final cached = _fantasySoccerRoundScoreCache[cacheKey];
  final now = DateTime.now();
  if (!force && cached != null) {
    final fresh =
        now.difference(cached.generatedAt) < _fantasySoccerScoreCacheTtl;
    if (cached.finalized || fresh) {
      return Future.value(cached);
    }
  }
  final inFlight = _fantasySoccerRoundScoreInFlight[cacheKey];
  if (inFlight != null) return inFlight;

  final future = _computeFantasySoccerRoundScoreSnapshot(draft, round)
      .then((snapshot) {
        _fantasySoccerRoundScoreCache[cacheKey] = snapshot;
        return snapshot;
      })
      .whenComplete(() {
        _fantasySoccerRoundScoreInFlight.remove(cacheKey);
      });

  _fantasySoccerRoundScoreInFlight[cacheKey] = future;
  return future;
}

_FantasySoccerRoundScoreSnapshot? _fantasySoccerRoundScoreSnapshotFor(
  _JoinedDraft draft,
  int round,
) {
  return _fantasySoccerRoundScoreCache[_fantasySoccerRoundCacheKey(
    draft,
    round,
  )];
}

double _fantasySoccerBasePlayerRoundScore(
  _JoinedDraft draft,
  _FantasyTeamState team,
  String playerName,
  int round,
) {
  final snapshot = _fantasySoccerRoundScoreSnapshotFor(draft, round);
  if (snapshot == null) return 0;
  return snapshot.basePlayerScores[_fantasySoccerPlayerCacheKey(
        teamUid: team.uid,
        teamName: team.teamName,
        playerName: playerName,
      )] ??
      0;
}

double _fantasySoccerDisplayedPlayerRoundScore(
  _JoinedDraft draft,
  _FantasyTeamState team,
  String playerName,
  int round,
) {
  final snapshot = _fantasySoccerRoundScoreSnapshotFor(draft, round);
  if (snapshot == null) return 0;
  return snapshot.displayedPlayerScores[_fantasySoccerPlayerCacheKey(
        teamUid: team.uid,
        teamName: team.teamName,
        playerName: playerName,
      )] ??
      0;
}

String? _fantasySoccerCaptainName(
  _JoinedDraft draft,
  _FantasyTeamState team,
  int round,
) {
  final snapshot = _fantasySoccerRoundScoreSnapshotFor(draft, round);
  if (snapshot == null) return null;
  return snapshot.captainNames[_fantasyTeamIdentity(
    uid: team.uid,
    teamName: team.teamName,
  )];
}

String? _fantasySoccerViceCaptainName(
  _JoinedDraft draft,
  _FantasyTeamState team,
  int round,
) {
  final snapshot = _fantasySoccerRoundScoreSnapshotFor(draft, round);
  if (snapshot == null) return null;
  return snapshot.viceCaptainNames[_fantasyTeamIdentity(
    uid: team.uid,
    teamName: team.teamName,
  )];
}

double _fantasyPlayerRoundScore(
  _FantasyTeamPlayer player,
  int round, {
  required bool isSoccer,
  _JoinedDraft? draft,
  _FantasyTeamState? team,
}) {
  if (isSoccer) {
    if (draft == null || team == null) return 0;
    return _fantasySoccerDisplayedPlayerRoundScore(
      draft,
      team,
      player.name,
      round,
    );
  }
  final seed = _stableSeedFromKey(
    '${player.name}|${player.position}|$round|${isSoccer ? 'soccer' : 'baseball'}',
  );
  final variance = ((seed % 17) - 8) / 2.0;
  final base = player.score.toDouble();
  return max(0, base * 1.4 + variance * 1.3);
}

double _fantasyTeamRoundScore(
  _FantasyTeamState team,
  int round, {
  required bool isSoccer,
  _JoinedDraft? draft,
}) {
  if (isSoccer) {
    if (draft == null) return 0;
    final snapshot = _fantasySoccerRoundScoreSnapshotFor(draft, round);
    if (snapshot == null) return 0;
    return snapshot.teamScores[_fantasyTeamIdentity(
          uid: team.uid,
          teamName: team.teamName,
        )] ??
        0;
  }
  return team.starting.fold<double>(
    0,
    (total, player) =>
        total +
        _fantasyPlayerRoundScore(
          player,
          round,
          isSoccer: isSoccer,
          draft: draft,
          team: team,
        ),
  );
}

String? _currentUserFantasyTeamName(_JoinedDraft draft) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return null;

  for (final team in draft.fantasyTeams) {
    if (team.uid == user.uid) return team.teamName;
  }

  for (final entry in draft.draftOrder) {
    if (entry.uid == user.uid) return entry.displayName;
  }

  final displayName = user.displayName?.trim();
  if (displayName != null && displayName.isNotEmpty) return displayName;
  final emailPrefix = (user.email ?? '').split('@').first.trim();
  if (emailPrefix.isNotEmpty) return emailPrefix;
  return null;
}

String? _currentUserFantasyUid() => FirebaseAuth.instance.currentUser?.uid;

_FantasyMatchupView? _currentFantasyMatchupForDraft(_JoinedDraft draft) {
  if (!draft.fantasyReady ||
      draft.fantasyTeams.isEmpty ||
      draft.fantasySchedule.isEmpty) {
    debugPrint(
      'currentFantasyMatchupForDraft: fantasy data missing '
      '(ready=${draft.fantasyReady}, teams=${draft.fantasyTeams.length}, schedule=${draft.fantasySchedule.length}) '
      'for ${draft.leagueName}',
    );
    return null;
  }
  final myUid = _currentUserFantasyUid();
  final myTeamName = _currentUserFantasyTeamName(draft);
  if ((myUid == null || myUid.isEmpty) &&
      (myTeamName == null || myTeamName.isEmpty)) {
    debugPrint(
      'currentFantasyMatchupForDraft: no current user identity for ${draft.leagueName}',
    );
    return null;
  }

  final round = _currentFantasyRoundAt(draft, DateTime.now());
  final matchup = draft.fantasySchedule.firstWhere(
    (item) =>
        item.round == round &&
        (((myUid != null && myUid.isNotEmpty) &&
                (item.homeUid == myUid || item.awayUid == myUid)) ||
            ((myTeamName != null && myTeamName.isNotEmpty) &&
                (item.homeTeam == myTeamName || item.awayTeam == myTeamName))),
    orElse: () => const _FantasyScheduleMatchup(
      round: -1,
      homeUid: '',
      homeTeam: '',
      awayUid: '',
      awayTeam: '',
    ),
  );
  if (matchup.round < 0) {
    debugPrint(
      'currentFantasyMatchupForDraft: no matchup found '
      '(round=$round, uid=$myUid, team=$myTeamName) for ${draft.leagueName}',
    );
    return null;
  }

  _FantasyTeamState? findTeam({String? uid, String? name}) {
    for (final team in draft.fantasyTeams) {
      if (uid != null && uid.isNotEmpty && team.uid == uid) return team;
      if (name != null && name.isNotEmpty && team.teamName == name) return team;
    }
    return null;
  }

  final homeTeam = findTeam(uid: matchup.homeUid, name: matchup.homeTeam);
  final awayTeam = findTeam(uid: matchup.awayUid, name: matchup.awayTeam);
  if (homeTeam == null || awayTeam == null) {
    debugPrint(
      'currentFantasyMatchupForDraft: team lookup failed '
      '(homeUid=${matchup.homeUid}, homeTeam=${matchup.homeTeam}, '
      'awayUid=${matchup.awayUid}, awayTeam=${matchup.awayTeam}) '
      'for ${draft.leagueName}',
    );
    return null;
  }

  final isHome =
      (myUid != null && myUid.isNotEmpty && matchup.homeUid == myUid) ||
      (myTeamName != null &&
          myTeamName.isNotEmpty &&
          matchup.homeTeam == myTeamName);
  final myTeam = isHome ? homeTeam : awayTeam;
  final opponent = isHome ? awayTeam : homeTeam;

  return _FantasyMatchupView(
    draft: draft,
    round: round,
    matchup: matchup,
    myTeam: myTeam,
    opponent: opponent,
    myScore: _fantasyTeamRoundScore(
      myTeam,
      round,
      isSoccer: draft.isSoccer,
      draft: draft,
    ),
    opponentScore: _fantasyTeamRoundScore(
      opponent,
      round,
      isSoccer: draft.isSoccer,
      draft: draft,
    ),
  );
}

List<_FantasyTeamPlayer> _parseFantasyTeamPlayers(dynamic raw) {
  final list = raw as List<dynamic>? ?? const [];
  return list.whereType<Map>().map((item) {
    final map = Map<String, dynamic>.from(item);
    return _FantasyTeamPlayer(
      name: '${map['name'] ?? ''}',
      position: '${map['position'] ?? ''}',
      score: map['score'] is int
          ? map['score'] as int
          : int.tryParse('${map['score'] ?? 0}') ?? 0,
    );
  }).toList();
}

List<_FantasyTeamState> _parseFantasyTeams(dynamic raw) {
  final list = raw as List<dynamic>? ?? const [];
  return list.whereType<Map>().map((item) {
    final map = Map<String, dynamic>.from(item);
    return _FantasyTeamState(
      uid: '${map['uid'] ?? ''}',
      teamName: '${map['teamName'] ?? 'Team'}',
      roster: _parseFantasyTeamPlayers(map['roster']),
      starting: _parseFantasyTeamPlayers(map['starting']),
      bench: _parseFantasyTeamPlayers(map['bench']),
    );
  }).toList();
}

List<_FantasyScheduleMatchup> _parseFantasySchedule(dynamic raw) {
  final list = raw as List<dynamic>? ?? const [];
  return list.whereType<Map>().map((item) {
    final map = Map<String, dynamic>.from(item);
    return _FantasyScheduleMatchup(
      round: map['round'] is int
          ? map['round'] as int
          : int.tryParse('${map['round'] ?? 0}') ?? 0,
      homeUid: '${map['homeUid'] ?? ''}',
      homeTeam: '${map['homeTeam'] ?? ''}',
      awayUid: '${map['awayUid'] ?? ''}',
      awayTeam: '${map['awayTeam'] ?? ''}',
    );
  }).toList()..sort((a, b) {
    final roundCompare = a.round.compareTo(b.round);
    if (roundCompare != 0) return roundCompare;
    return a.homeTeam.compareTo(b.homeTeam);
  });
}

List<List<_PlayerSlot?>> _parseDraftBoard(dynamic raw) {
  final rows = raw as List<dynamic>? ?? const [];
  return rows.map<List<_PlayerSlot?>>((row) {
    final dynamic rawCells;
    if (row is Map) {
      rawCells = row['cells'];
    } else {
      rawCells = row;
    }
    final cells = rawCells as List<dynamic>? ?? const [];
    return cells.map<_PlayerSlot?>((cell) {
      if (cell is! Map) return null;
      final map = Map<String, dynamic>.from(cell);
      final name = '${map['name'] ?? ''}';
      if (name.isEmpty) return null;
      return _PlayerSlot(
        name: name,
        position: '${map['position'] ?? ''}',
        score: map['score'] is int
            ? map['score'] as int
            : int.tryParse('${map['score'] ?? 0}') ?? 0,
      );
    }).toList();
  }).toList();
}

List<Map<String, dynamic>> _draftBoardToFirestoreRows(
  List<List<_PlayerSlot?>> board,
) {
  return List<Map<String, dynamic>>.generate(board.length, (rowIndex) {
    return {
      'row': rowIndex,
      'cells': board[rowIndex]
          .map(
            (slot) => slot == null
                ? null
                : {
                    'name': slot.name,
                    'position': slot.position,
                    'score': slot.score,
                  },
          )
          .toList(),
    };
  });
}

class _RecoveredFantasyPayload {
  final List<List<_PlayerSlot?>> board;
  final List<_FantasyTeamState> teams;
  final List<_FantasyScheduleMatchup> schedule;

  const _RecoveredFantasyPayload({
    required this.board,
    required this.teams,
    required this.schedule,
  });
}

const List<String> _kboDraftClubs = [
  'LG',
  'KIA',
  '삼성',
  '두산',
  '롯데',
  '한화',
  'KT',
  'SSG',
  'NC',
  '키움',
];

const String _kboDraftPlayerDirectoryAsset =
    'functions/kbo_players_season_2026.txt';

List<_PlayerSlot>? _kboDraftPlayerPoolCache;
Future<List<_PlayerSlot>>? _kboDraftPlayerPoolFuture;

String _normalizeKboDraftClub(String value) {
  switch (value.trim()) {
    case 'Samsung':
    case 'SAMSUNG':
      return '삼성';
    case 'Doosan':
    case 'DOOSAN':
      return '두산';
    case 'Lotte':
    case 'LOTTE':
      return '롯데';
    case 'Hanwha':
    case 'HANWHA':
      return '한화';
    case 'Kiwoom':
    case 'KIWOOM':
      return '키움';
    default:
      return value.trim();
  }
}

String? _normalizeKboDraftPosition(String value) {
  switch (value.trim()) {
    case 'Pitcher':
      return 'P';
    case 'Catcher':
      return 'C';
    case 'Outfielder':
    case 'Center Fielder':
      return 'OF';
    case 'Infielder':
    case 'Second baseman':
    case 'Third baseman':
      return 'IF';
    default:
      return null;
  }
}

List<_PlayerSlot> _fallbackRecoveredBaseballPlayerPool() {
  final pool = <_PlayerSlot>[];
  for (final club in _kboDraftClubs) {
    for (int i = 1; i <= 12; i++) {
      pool.add(
        _makeRecoveredBaseballSlot(club: club, position: 'P', number: i),
      );
    }
    for (int i = 1; i <= 8; i++) {
      pool.add(
        _makeRecoveredBaseballSlot(club: club, position: 'IF', number: i),
      );
    }
    for (int i = 1; i <= 6; i++) {
      pool.add(
        _makeRecoveredBaseballSlot(club: club, position: 'OF', number: i),
      );
    }
    for (int i = 1; i <= 3; i++) {
      pool.add(
        _makeRecoveredBaseballSlot(club: club, position: 'C', number: i),
      );
    }
  }
  return pool;
}

List<_PlayerSlot> _parseKboDraftPlayerPool(String raw) {
  final seen = <String>{};
  final pool = <_PlayerSlot>[];

  for (final line in raw.split(RegExp(r'\r?\n'))) {
    final parts = line.split('|').map((part) => part.trim()).toList();
    if (parts.length < 5) continue;
    final englishName = parts[0];
    final koreanName = parts[1];
    final club = _normalizeKboDraftClub(parts[2]);
    final position = _normalizeKboDraftPosition(parts[3]);
    final number = parts[4];
    if (englishName.isEmpty || koreanName.isEmpty || position == null) {
      continue;
    }

    final displayName = koreanName;
    final dedupeKey = '$club|$displayName|$position|$number';
    if (!seen.add(dedupeKey)) continue;

    final scoreSeed = _stableSeedFromKey(dedupeKey);
    pool.add(
      _PlayerSlot(
        name: displayName,
        score: 5 + (scoreSeed % 6),
        position: position,
      ),
    );
  }

  return pool;
}

Future<List<_PlayerSlot>> _loadKboDraftPlayerPool() {
  final cached = _kboDraftPlayerPoolCache;
  if (cached != null) return Future.value(cached);
  final inFlight = _kboDraftPlayerPoolFuture;
  if (inFlight != null) return inFlight;

  _kboDraftPlayerPoolFuture = rootBundle
      .loadString(_kboDraftPlayerDirectoryAsset)
      .then((raw) {
        final parsed = _parseKboDraftPlayerPool(raw);
        final resolved = parsed.isNotEmpty
            ? parsed
            : _fallbackRecoveredBaseballPlayerPool();
        _kboDraftPlayerPoolCache = resolved;
        return resolved;
      })
      .catchError((Object error) {
        debugPrint('Unable to load KBO draft player pool: $error');
        final fallback = _fallbackRecoveredBaseballPlayerPool();
        _kboDraftPlayerPoolCache = fallback;
        return fallback;
      });

  return _kboDraftPlayerPoolFuture!;
}

_PlayerSlot _makeRecoveredBaseballSlot({
  required String club,
  required String position,
  required int number,
}) {
  final scoreSeed = _stableSeedFromKey('$club|$position|$number');
  return _PlayerSlot(
    name: '$club $position$number',
    score: 5 + (scoreSeed % 6),
    position: position,
  );
}

List<_PlayerSlot> _buildRecoveredBaseballPlayerPool(
  Random random,
  List<_PlayerSlot> basePool,
) {
  final pool = List<_PlayerSlot>.from(basePool);
  pool.shuffle(random);
  return pool;
}

List<_FantasyTeamPlayer> _buildRecoveredSoccerStarting(
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

List<_FantasyTeamPlayer> _buildRecoveredBaseballStarting(
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

Future<_RecoveredFantasyPayload> _recoverFantasyPayloadFromDraft(
  _JoinedDraft draft,
) async {
  final seedKey =
      'real|${draft.leagueName}|${draft.when.toIso8601String()}|${draft.teamCount}|${draft.isSoccer}';
  final random = Random(_stableSeedFromKey(seedKey));
  final rounds = _draftRoundsForSport(draft.isSoccer);
  final board = List.generate(
    rounds,
    (_) => List<_PlayerSlot?>.filled(draft.teamCount, null),
  );
  final playerPool = draft.isSoccer
      ? _buildPlayerPool(random)
      : _buildRecoveredBaseballPlayerPool(
          random,
          await _loadKboDraftPlayerPool(),
        );
  final minimums = draft.isSoccer
      ? const {'GK': 1, 'DF': 3, 'MF': 4, 'FW': 3}
      : const {'P': 1, 'IF': 4, 'OF': 3, 'C': 1};
  final draftOrderEntries = List<_DraftOrderEntry>.generate(draft.teamCount, (
    index,
  ) {
    if (index < draft.draftOrder.length) return draft.draftOrder[index];
    return _DraftOrderEntry(
      uid: '',
      displayName: 'Team ${index + 1}',
      slot: index + 1,
    );
  });

  bool isPicked(_PlayerSlot player) =>
      board.any((row) => row.any((slot) => slot?.name == player.name));

  Iterable<_PlayerSlot> availablePlayers() =>
      playerPool.where((player) => !isPicked(player));

  Map<String, int> teamPositionCounts(int teamIdx) {
    final counts = <String, int>{};
    for (int row = 0; row < rounds; row++) {
      final slot = board[row][teamIdx];
      if (slot == null) continue;
      counts.update(slot.position, (value) => value + 1, ifAbsent: () => 1);
    }
    return counts;
  }

  int remainingEmptySlotsForTeam(int teamIdx) {
    int count = 0;
    for (int row = 0; row < rounds; row++) {
      if (board[row][teamIdx] == null) count++;
    }
    return count;
  }

  bool canStillMeetMinimumsAfterPick(int teamIdx, _PlayerSlot candidate) {
    final counts = teamPositionCounts(teamIdx);
    counts.update(candidate.position, (value) => value + 1, ifAbsent: () => 1);
    final remainingSlotsAfterPick = remainingEmptySlotsForTeam(teamIdx) - 1;
    int stillNeeded = 0;
    for (final entry in minimums.entries) {
      final have = counts[entry.key] ?? 0;
      stillNeeded += max(0, entry.value - have);
    }
    return stillNeeded <= remainingSlotsAfterPick;
  }

  List<_PlayerSlot> selectablePlayersForTeam(int teamIdx) {
    final available = availablePlayers().toList();
    final constrained = available
        .where((player) => canStillMeetMinimumsAfterPick(teamIdx, player))
        .toList();
    return constrained.isNotEmpty ? constrained : available;
  }

  _PlayerSlot? takeAvailablePlayerForPosition(String position) {
    final available = availablePlayers()
        .where((player) => player.position == position)
        .toList();
    if (available.isEmpty) return null;
    return available[random.nextInt(available.length)];
  }

  for (int index = 0; index < rounds * draft.teamCount; index++) {
    final row = index ~/ draft.teamCount;
    final col = index % draft.teamCount;
    final available = selectablePlayersForTeam(col);
    if (available.isEmpty) continue;
    board[row][col] = available[random.nextInt(available.length)];
  }

  for (int teamIdx = 0; teamIdx < draft.teamCount; teamIdx++) {
    final blankRows = <int>[];
    for (int row = 0; row < rounds; row++) {
      if (board[row][teamIdx] == null) blankRows.add(row);
    }
    if (blankRows.isEmpty) continue;

    final counts = teamPositionCounts(teamIdx);
    for (final entry in minimums.entries) {
      while ((counts[entry.key] ?? 0) < entry.value && blankRows.isNotEmpty) {
        final candidate = takeAvailablePlayerForPosition(entry.key);
        if (candidate == null) break;
        final row = blankRows.removeAt(0);
        board[row][teamIdx] = candidate;
        counts.update(
          candidate.position,
          (value) => value + 1,
          ifAbsent: () => 1,
        );
      }
    }

    while (blankRows.isNotEmpty) {
      final available = availablePlayers().toList();
      if (available.isEmpty) break;
      final row = blankRows.removeAt(0);
      board[row][teamIdx] = available[random.nextInt(available.length)];
    }
  }

  final teams = <_FantasyTeamState>[];
  for (int teamIdx = 0; teamIdx < draft.teamCount; teamIdx++) {
    final roster = <_FantasyTeamPlayer>[];
    for (int row = 0; row < rounds; row++) {
      final slot = board[row][teamIdx];
      if (slot == null) continue;
      roster.add(
        _FantasyTeamPlayer(
          name: slot.name,
          position: slot.position,
          score: slot.score,
        ),
      );
    }
    final starting = draft.isSoccer
        ? _buildRecoveredSoccerStarting(roster)
        : _buildRecoveredBaseballStarting(roster);
    final startingNames = starting.map((player) => player.name).toSet();
    final bench = roster
        .where((player) => !startingNames.contains(player.name))
        .toList();
    final entry = draftOrderEntries[teamIdx];
    teams.add(
      _FantasyTeamState(
        uid: entry.uid,
        teamName: entry.displayName,
        roster: roster,
        starting: starting,
        bench: bench,
      ),
    );
  }

  final pairings = draftOrderEntries
      .map((entry) => (uid: entry.uid, name: entry.displayName))
      .toList();
  var rotation = [...pairings];
  final hasBye = rotation.length.isOdd;
  if (hasBye) {
    rotation = [...rotation, (uid: '__bye__', name: 'BYE')];
  }
  final baseRounds = <List<_FantasyScheduleMatchup>>[];
  final roundsPerCycle = rotation.length - 1;
  for (int round = 0; round < roundsPerCycle; round++) {
    final roundPairings = <_FantasyScheduleMatchup>[];
    for (int i = 0; i < rotation.length / 2; i++) {
      final home = rotation[i];
      final away = rotation[rotation.length - 1 - i];
      if (home.uid == '__bye__' || away.uid == '__bye__') continue;
      roundPairings.add(
        _FantasyScheduleMatchup(
          round: round + 1,
          homeUid: round.isEven ? home.uid : away.uid,
          homeTeam: round.isEven ? home.name : away.name,
          awayUid: round.isEven ? away.uid : home.uid,
          awayTeam: round.isEven ? away.name : home.name,
        ),
      );
    }
    baseRounds.add(roundPairings);
    rotation = [
      rotation.first,
      rotation.last,
      ...rotation.sublist(1, rotation.length - 1),
    ];
  }

  final schedule = <_FantasyScheduleMatchup>[];
  for (int round = 1; round <= max(1, draft.roundCount); round++) {
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

  return _RecoveredFantasyPayload(
    board: board,
    teams: teams,
    schedule: schedule,
  );
}

String _fantasyMyTeamName({required bool isSoccer}) =>
    isSoccer ? 'Blue Foxes' : 'Seoul Sluggers';

List<_FantasyLeagueStanding> _fantasyLeagueStandings({required bool isSoccer}) {
  // NOTE: This is mock data until we plug in a backend + real-time scoring.
  return isSoccer
      ? const [
          _FantasyLeagueStanding(team: 'Blue Foxes', pts: 38),
          _FantasyLeagueStanding(team: 'Red Bears', pts: 36),
          _FantasyLeagueStanding(team: 'White Tigers', pts: 34),
          _FantasyLeagueStanding(team: 'Green Hawks', pts: 32),
          _FantasyLeagueStanding(team: 'Sky Giants', pts: 29),
          _FantasyLeagueStanding(team: 'Orange Wolves', pts: 27),
          _FantasyLeagueStanding(team: 'Mint Dolphins', pts: 25),
          _FantasyLeagueStanding(team: 'Purple Knights', pts: 23),
          _FantasyLeagueStanding(team: 'Silver Sharks', pts: 20),
          _FantasyLeagueStanding(team: 'Golden Owls', pts: 18),
        ]
      : const [
          _FantasyLeagueStanding(team: 'Seoul Sluggers', pts: 52),
          _FantasyLeagueStanding(team: 'Busan Bombers', pts: 50),
          _FantasyLeagueStanding(team: 'Daegu Titans', pts: 48),
          _FantasyLeagueStanding(team: 'Incheon Waves', pts: 47),
          _FantasyLeagueStanding(team: 'Daejeon Rockets', pts: 45),
          _FantasyLeagueStanding(team: 'Suwon Knights', pts: 43),
          _FantasyLeagueStanding(team: 'Gwangju Sparks', pts: 40),
          _FantasyLeagueStanding(team: 'Jeju Mariners', pts: 38),
          _FantasyLeagueStanding(team: 'Ulsan Bulls', pts: 36),
          _FantasyLeagueStanding(team: 'Anyang Bears', pts: 34),
        ];
}

String _fantasyRankText({required bool isSoccer}) {
  final rows = _fantasyLeagueStandings(isSoccer: isSoccer);
  final myTeam = _fantasyMyTeamName(isSoccer: isSoccer);
  final idx = rows.indexWhere((r) => r.team == myTeam);
  final rank = idx < 0 ? '-' : '${idx + 1}위';
  return '$rank / ${rows.length}팀';
}

class LeagueItHomePage extends StatefulWidget {
  const LeagueItHomePage({super.key});

  @override
  State<LeagueItHomePage> createState() => LeagueItHomePageState();
}

class LeagueItHomePageState extends State<LeagueItHomePage>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late AnimationController _launchController;
  late Animation<double> _launchOpacity;
  late Animation<double> _launchScale;
  late Animation<Offset> _launchSlide;
  bool _showLaunchIntro = false;
  static bool _didPlayLaunchIntro = false;
  late final TextEditingController _searchController;
  late final ScrollController _suggestionsScrollController;
  late Future<Map<String, dynamic>> _leagueFuture;
  late Future<Map<String, dynamic>> _kboLeagueFuture;

  bool _isMenuOpen = false;
  bool _isMyPageOpen = false;
  bool _isLoggedIn = false;
  bool _hasSoccerLeague = false;
  bool _hasBaseballLeague = false;
  bool _frontLeagueIsSoccer = true;
  List<String> _suggestions = [];
  DateTime? _draftTime;
  String? _draftLeagueName;
  Timer? _draftTimer;
  Timer? _kboLiveRefreshTimer;
  Duration _draftRemaining = Duration.zero;
  List<_JoinedDraft> _joinedDrafts = const [];
  final Set<String> _recoveringFantasyLeagueIds = <String>{};
  bool _isRefreshingFantasySoccerScores = false;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _joinedDraftsSub;
  final FlutterSecureStorage _localStateStorage = const FlutterSecureStorage(
    iOptions: IOSOptions(accountName: 'leagueit_local_state'),
  );
  static const String _kHasSoccerLeagueKey = 'home.has_soccer_league';
  static const String _kHasBaseballLeagueKey = 'home.has_baseball_league';
  static const String _kDraftTimeKey = 'home.draft_time';
  static const String _kDraftNameKey = 'home.draft_name';
  static const String _kFrontLeagueKey = 'home.front_is_soccer';
  // Keep false in normal app flow. When true, login/league state is randomized
  // for UI demos and can look like "mock login".
  static const bool _demoRandomState = false;
  static const List<String> _demoLeagueNames = [
    'K League Masters',
    'Weekend Warriors',
    'Fantasy 12',
    'Sunday League',
  ];
  late final List<String> _playerDirectory;

  bool get isLoggedIn => _isLoggedIn;
  bool get hasSoccerLeague => _hasSoccerLeague;
  bool get hasBaseballLeague => _hasBaseballLeague;
  // Back-compat: treat "hasLeague" as soccer league for existing callers.
  bool get hasLeague => _hasSoccerLeague;
  List<_JoinedDraft> get joinedDrafts {
    final all = List<_JoinedDraft>.from(_joinedDrafts)
      ..sort((a, b) => a.when.compareTo(b.when));
    return List.unmodifiable(all);
  }

  List<_JoinedDraft> get visibleDraftEntries {
    final now = DateTime.now();
    final visible =
        _joinedDrafts.where((draft) => !_isDraftExpiredAt(draft, now)).toList()
          ..sort((a, b) => a.when.compareTo(b.when));
    return List.unmodifiable(visible);
  }

  _JoinedDraft? get primaryDraft {
    final now = DateTime.now();
    final visible = _joinedDrafts
        .where((draft) => !_isDraftExpiredAt(draft, now))
        .toList();
    if (visible.isEmpty) return null;
    final upcoming = visible.where((d) => d.when.isAfter(now)).toList()
      ..sort((a, b) => a.when.compareTo(b.when));
    if (upcoming.isNotEmpty) return upcoming.first;
    return visible.first;
  }

  _JoinedDraft? fantasyDraftForSport(bool isSoccer) {
    final candidates =
        _joinedDrafts
            .where((draft) => draft.isSoccer == isSoccer && draft.fantasyReady)
            .toList()
          ..sort((a, b) => a.when.compareTo(b.when));
    if (candidates.isEmpty) return null;
    for (final draft in candidates) {
      if (_currentFantasyMatchupForDraft(draft) != null) {
        return draft;
      }
    }
    return candidates.first;
  }

  _FantasyMatchupView? currentFantasyMatchupForSport(bool isSoccer) {
    final draft = fantasyDraftForSport(isSoccer);
    if (draft == null) return null;
    return _currentFantasyMatchupForDraft(draft);
  }

  Future<void> _refreshFantasySoccerScores() async {
    if (_isRefreshingFantasySoccerScores) return;
    final soccerDrafts = _joinedDrafts
        .where(
          (draft) =>
              draft.isSoccer &&
              draft.fantasyReady &&
              draft.fantasyTeams.isNotEmpty &&
              draft.fantasySchedule.isNotEmpty,
        )
        .toList();
    if (soccerDrafts.isEmpty) return;

    _isRefreshingFantasySoccerScores = true;
    try {
      for (final draft in soccerDrafts) {
        final currentRound = _currentFantasyRoundAt(draft, DateTime.now());
        for (int round = 1; round <= currentRound; round++) {
          await _ensureFantasySoccerRoundScoreSnapshot(
            draft,
            round,
            force: round == currentRound,
          );
        }
      }
      if (!mounted) return;
      setState(() {});
    } catch (e, st) {
      debugPrint('refreshFantasySoccerScores failed: $e');
      debugPrint('$st');
    } finally {
      _isRefreshingFantasySoccerScores = false;
    }
  }

  String _userStateKey(String key) {
    final uid = authController.session?.accessToken ?? 'anonymous';
    return '$uid.$key';
  }

  Future<void> _safeWriteLocalState({
    required String key,
    required String value,
  }) async {
    try {
      await _localStateStorage.write(key: key, value: value);
    } on PlatformException catch (e) {
      // iOS keychain can throw -25299("item already exists") on write.
      final code = '${e.code}';
      final raw = '${e.message} ${e.details}'.toLowerCase();
      final isDuplicate =
          code.contains('-25299') ||
          raw.contains('already exists') ||
          raw.contains('-25299') ||
          raw.contains('keychain');
      if (!isDuplicate) rethrow;

      await _localStateStorage.delete(key: key);
      await _localStateStorage.write(key: key, value: value);
    }
  }

  Future<void> _saveLocalState() async {
    if (!_isLoggedIn) return;
    await _safeWriteLocalState(
      key: _userStateKey(_kHasSoccerLeagueKey),
      value: _hasSoccerLeague ? '1' : '0',
    );
    await _safeWriteLocalState(
      key: _userStateKey(_kHasBaseballLeagueKey),
      value: _hasBaseballLeague ? '1' : '0',
    );
    await _safeWriteLocalState(
      key: _userStateKey(_kFrontLeagueKey),
      value: _frontLeagueIsSoccer ? '1' : '0',
    );
    if (_draftTime == null) {
      await _localStateStorage.delete(key: _userStateKey(_kDraftTimeKey));
      await _localStateStorage.delete(key: _userStateKey(_kDraftNameKey));
      return;
    }
    await _safeWriteLocalState(
      key: _userStateKey(_kDraftTimeKey),
      value: _draftTime!.toIso8601String(),
    );
    await _safeWriteLocalState(
      key: _userStateKey(_kDraftNameKey),
      value: _draftLeagueName ?? '',
    );
  }

  Future<void> _restoreLocalState() async {
    if (!_isLoggedIn) return;

    final soccerRaw = await _localStateStorage.read(
      key: _userStateKey(_kHasSoccerLeagueKey),
    );
    final baseballRaw = await _localStateStorage.read(
      key: _userStateKey(_kHasBaseballLeagueKey),
    );
    final frontRaw = await _localStateStorage.read(
      key: _userStateKey(_kFrontLeagueKey),
    );
    final draftTimeRaw = await _localStateStorage.read(
      key: _userStateKey(_kDraftTimeKey),
    );
    final draftNameRaw = await _localStateStorage.read(
      key: _userStateKey(_kDraftNameKey),
    );

    final bool hasSavedLeagueFlags = soccerRaw != null || baseballRaw != null;

    // Backward-compat default: if user is logged in and no prior local league
    // state exists, show soccer matchup card so the home does not look logged out.
    final bool soccer = hasSavedLeagueFlags ? soccerRaw == '1' : true;
    final bool baseball = hasSavedLeagueFlags ? baseballRaw == '1' : false;
    final bool frontSoccer = frontRaw == null
        ? _frontLeagueIsSoccer
        : frontRaw == '1';
    final DateTime? savedDraftTime = DateTime.tryParse(draftTimeRaw ?? '');

    if (!mounted) return;
    setState(() {
      _hasSoccerLeague = soccer;
      _hasBaseballLeague = baseball;
      _frontLeagueIsSoccer = frontSoccer;
      _draftTime = savedDraftTime;
      _draftLeagueName = savedDraftTime == null
          ? null
          : (draftNameRaw ?? 'My League');
    });
    _startDraftTimer();
    _listenJoinedDrafts();
    await _saveLocalState();
  }

  void updateLogin(bool value) {
    if (value) {
      if (mounted && _isLoggedIn != authController.isLoggedIn) {
        setState(() => _isLoggedIn = authController.isLoggedIn);
      }
      unawaited(_restoreLocalState());
      return;
    }
    if (!value) {
      unawaited(authController.signOut());
    }
  }

  void setHasLeague(bool value) {
    // Back-compat: sets soccer league.
    setState(() => _hasSoccerLeague = value);
    unawaited(_saveLocalState());
  }

  bool hasLeagueForSport(bool isSoccer) =>
      isSoccer ? _hasSoccerLeague : _hasBaseballLeague;

  void setHasLeagueForSport(bool isSoccer, bool value) {
    setState(() {
      if (isSoccer) {
        _hasSoccerLeague = value;
      } else {
        _hasBaseballLeague = value;
      }
    });
    unawaited(_saveLocalState());
  }

  void closePanels() {
    setState(() {
      _isMenuOpen = false;
      _isMyPageOpen = false;
    });
  }

  void resetHomeUI() {
    setState(() {
      _isMenuOpen = false;
      _isMyPageOpen = false;
    });
    _searchController.clear();
  }

  void setDraft(
    DateTime when,
    String name, {
    bool markLeague = true,
    bool isSoccer = true,
  }) {
    setState(() {
      _draftTime = when;
      _draftLeagueName = name;
      _upsertJoinedDraft(
        _JoinedDraft(
          leagueId: '',
          leagueName: name,
          when: when,
          isSoccer: isSoccer,
        ),
      );
      if (markLeague) {
        if (isSoccer) {
          _hasSoccerLeague = true;
        } else {
          _hasBaseballLeague = true;
        }
      }
    });
    _startDraftTimer();
    unawaited(_saveLocalState());
  }

  void addOrUpdateJoinedDraft(_JoinedDraft draft) {
    setState(() {
      _upsertJoinedDraft(draft);
      _hasSoccerLeague = _joinedDrafts.any((d) => d.isSoccer);
      _hasBaseballLeague = _joinedDrafts.any((d) => !d.isSoccer);
      _setPrimaryDraftFromJoinedDrafts();
    });
    _startDraftTimer();
    unawaited(_saveLocalState());
  }

  void _upsertJoinedDraft(_JoinedDraft draft) {
    final next = List<_JoinedDraft>.from(_joinedDrafts);
    final idx = next.indexWhere(
      (d) =>
          (draft.leagueId.isNotEmpty &&
              d.leagueId.isNotEmpty &&
              d.leagueId == draft.leagueId) ||
          (d.leagueName == draft.leagueName && d.isSoccer == draft.isSoccer),
    );
    if (idx >= 0) {
      next[idx] = draft;
    } else {
      next.add(draft);
    }
    next.sort((a, b) => a.when.compareTo(b.when));
    _joinedDrafts = next;
  }

  void removeJoinedDraftByLeagueId(String leagueId) {
    if (leagueId.isEmpty) return;

    final next = _joinedDrafts.where((d) => d.leagueId != leagueId).toList()
      ..sort((a, b) => a.when.compareTo(b.when));

    setState(() {
      _joinedDrafts = next;
      _hasSoccerLeague = next.any((d) => d.isSoccer);
      _hasBaseballLeague = next.any((d) => !d.isSoccer);
      _setPrimaryDraftFromJoinedDrafts();
    });
    _startDraftTimer();
    unawaited(_saveLocalState());
  }

  void _listenJoinedDrafts() {
    _joinedDraftsSub?.cancel();
    if (!_isLoggedIn) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _joinedDraftsSub = FirebaseFirestore.instance
        .collection('leagues')
        .where('members', arrayContains: user.uid)
        .snapshots()
        .listen(
          (snapshot) {
            final drafts = <_JoinedDraft>[];
            for (final doc in snapshot.docs) {
              final data = doc.data();
              final when = _parseDraftDate(data);
              if (when == null) continue;
              final name = (data['name'] as String?)?.trim().isNotEmpty == true
                  ? (data['name'] as String).trim()
                  : 'My League';
              final members = List<String>.from(
                (data['members'] as List<dynamic>? ?? const []).map(
                  (e) => '$e',
                ),
              );
              final draft = _JoinedDraft(
                leagueId: doc.id,
                leagueName: name,
                when: when,
                isSoccer: _parseIsSoccerLeague(data),
                teamCount: _parseTeamCount(data),
                roundCount: _parseRoundCount(data, _parseIsSoccerLeague(data)),
                memberCount: members.length,
                inviteCode: '${data['inviteCode'] ?? ''}',
                ownerId: '${data['ownerId'] ?? ''}',
                draftOrder: _parseDraftOrder(data['draftOrder']),
                fantasyReady: data['fantasyReady'] == true,
                fantasyTeams: _parseFantasyTeams(data['fantasyTeams']),
                fantasySchedule: _parseFantasySchedule(data['fantasySchedule']),
                draftBoard: _parseDraftBoard(data['draftBoard']),
              );
              drafts.add(draft);
            }
            drafts.sort((a, b) => a.when.compareTo(b.when));
            if (!mounted) return;
            setState(() {
              _joinedDrafts = drafts;
              _hasSoccerLeague = drafts.any((d) => d.isSoccer);
              _hasBaseballLeague = drafts.any((d) => !d.isSoccer);
              _setPrimaryDraftFromJoinedDrafts();
            });
            unawaited(_refreshFantasySoccerScores());
            for (final draft in drafts) {
              if (_shouldRecoverFantasyLeague(draft)) {
                unawaited(_recoverFantasyLeagueState(draft));
              }
            }
            _startDraftTimer();
          },
          onError: (e, st) {
            debugPrint('watchMyDrafts error: $e');
            debugPrint('$st');
          },
        );
  }

  bool _shouldRecoverFantasyLeague(_JoinedDraft draft) {
    if (draft.leagueId.isEmpty) return false;
    if (draft.fantasyReady) return false;
    if (!_isDraftCompletedAt(draft, DateTime.now())) return false;
    return draft.draftOrder.length >= draft.teamCount && draft.teamCount > 1;
  }

  Future<void> _recoverFantasyLeagueState(_JoinedDraft draft) async {
    if (_recoveringFantasyLeagueIds.contains(draft.leagueId)) return;
    _recoveringFantasyLeagueIds.add(draft.leagueId);
    try {
      final payload = await _recoverFantasyPayloadFromDraft(draft);
      await LeagueService.instance.finalizeFantasyLeague(
        leagueId: draft.leagueId,
        draftBoard: _draftBoardToFirestoreRows(payload.board),
        fantasyTeams: payload.teams.map((team) => team.toMap()).toList(),
        fantasySchedule: payload.schedule
            .map((matchup) => matchup.toMap())
            .toList(),
      );
      if (!mounted) return;
      setState(() {
        _upsertJoinedDraft(
          _JoinedDraft(
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
            fantasyReady: true,
            fantasyTeams: payload.teams,
            fantasySchedule: payload.schedule,
            draftBoard: payload.board,
          ),
        );
        _hasSoccerLeague = _joinedDrafts.any((d) => d.isSoccer);
        _hasBaseballLeague = _joinedDrafts.any((d) => !d.isSoccer);
        _setPrimaryDraftFromJoinedDrafts();
      });
      unawaited(_refreshFantasySoccerScores());
      _startDraftTimer();
    } catch (e, st) {
      debugPrint('recoverFantasyLeagueState failed for ${draft.leagueId}: $e');
      debugPrint('$st');
    } finally {
      _recoveringFantasyLeagueIds.remove(draft.leagueId);
    }
  }

  DateTime? _parseDraftDate(Map<String, dynamic> data) {
    final raw = data['draftDateTime'] ?? data['draftAt'] ?? data['draftTime'];
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw);
    if (raw is int) return DateTime.fromMillisecondsSinceEpoch(raw);
    return null;
  }

  int _parseTeamCount(Map<String, dynamic> data) {
    final raw = data['teamCount'];
    if (raw is int) return raw;
    if (raw is String) return int.tryParse(raw) ?? 8;
    return 8;
  }

  int _parseRoundCount(Map<String, dynamic> data, bool isSoccer) {
    final raw = data['roundCount'];
    if (raw is int) return raw;
    if (raw is String) return int.tryParse(raw) ?? (isSoccer ? 19 : 34);
    return isSoccer ? 19 : 34;
  }

  List<_DraftOrderEntry> _parseDraftOrder(dynamic raw) {
    final list = raw as List<dynamic>?;
    if (list == null || list.isEmpty) return const [];
    final result = <_DraftOrderEntry>[];
    for (final item in list) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      result.add(
        _DraftOrderEntry(
          uid: '${map['uid'] ?? ''}',
          displayName: '${map['displayName'] ?? 'Team'}',
          slot: map['slot'] is int
              ? map['slot'] as int
              : int.tryParse('${map['slot'] ?? 0}') ?? 0,
        ),
      );
    }
    result.sort((a, b) => a.slot.compareTo(b.slot));
    return result;
  }

  bool _parseIsSoccerLeague(Map<String, dynamic> data) {
    final sport = (data['sport'] as String?)?.toLowerCase().trim();
    final name = (data['name'] as String?)?.toLowerCase().trim() ?? '';
    if (sport == null || sport.isEmpty) {
      if (name.contains('kbo') ||
          name.contains('baseball') ||
          name.contains('야구')) {
        return false;
      }
      return true;
    }
    return sport == 'soccer' ||
        sport == 'k league' ||
        sport == 'k-league' ||
        sport == 'kleague';
  }

  void _setPrimaryDraftFromJoinedDrafts() {
    final now = DateTime.now();
    final visible =
        _joinedDrafts.where((draft) => !_isDraftExpiredAt(draft, now)).toList()
          ..sort((a, b) => a.when.compareTo(b.when));

    if (visible.isEmpty) {
      _draftTime = null;
      _draftLeagueName = null;
      _draftRemaining = Duration.zero;
      return;
    }
    final upcoming = visible.where((d) => d.when.isAfter(now)).toList()
      ..sort((a, b) => a.when.compareTo(b.when));

    if (upcoming.isEmpty) {
      _draftTime = null;
      _draftLeagueName = null;
      _draftRemaining = Duration.zero;
      return;
    }

    _draftTime = upcoming.first.when;
    _draftLeagueName = upcoming.first.leagueName;
  }

  void _startDraftTimer() {
    _draftTimer?.cancel();
    if (_draftTime == null && _joinedDrafts.isEmpty) return;
    _tickDraft();
    _draftTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _tickDraft();
    });
  }

  void _tickDraft() {
    final now = DateTime.now();
    if (!mounted) return;
    setState(() {
      final expiredDrafts = _joinedDrafts
          .where((draft) => _isDraftExpiredAt(draft, now))
          .toList();
      for (final draft in expiredDrafts) {
        _draftSessionCache.remove(_draftSessionKeyForJoinedDraft(draft));
      }
      _hasSoccerLeague = _joinedDrafts.any((d) => d.isSoccer);
      _hasBaseballLeague = _joinedDrafts.any((d) => !d.isSoccer);
      _setPrimaryDraftFromJoinedDrafts();
      if (_draftTime != null) {
        final remaining = _draftTime!.difference(now);
        _draftRemaining = remaining.isNegative ? Duration.zero : remaining;
      }
    });
    if (_draftTime == null && _joinedDrafts.isEmpty) {
      _draftTimer?.cancel();
    }
  }

  void _applyDemoState() {
    final rand = Random();
    // 0: 로그아웃, 1: 로그인만(리그 없음), 2: 로그인+드래프트(리그 없음),
    // 3: 로그인+리그 보유(매치업만), 4: 로그인+리그+드래프트
    final scenario = rand.nextInt(5);
    switch (scenario) {
      case 0:
        setState(() {
          _isLoggedIn = false;
          _hasSoccerLeague = false;
          _hasBaseballLeague = false;
          _draftTime = null;
          _draftLeagueName = null;
        });
        _draftTimer?.cancel();
        return;
      case 1:
        setState(() {
          _isLoggedIn = true;
          _hasSoccerLeague = false;
          _hasBaseballLeague = false;
          _draftTime = null;
          _draftLeagueName = null;
        });
        return;
      case 2:
        {
          final now = DateTime.now();
          final when = now.add(
            Duration(minutes: 10 + rand.nextInt(60 * 24 * 3)),
          );
          final name = _demoLeagueNames[rand.nextInt(_demoLeagueNames.length)];
          setState(() {
            _isLoggedIn = true;
            _hasSoccerLeague = false;
            _hasBaseballLeague = false;
          });
          setDraft(when, name, markLeague: false, isSoccer: true);
          return;
        }
      case 3:
        setState(() {
          _isLoggedIn = true;
          _hasSoccerLeague = true;
          _hasBaseballLeague = false;
          _draftTime = null;
          _draftLeagueName = null;
        });
        return;
      case 4:
      default:
        {
          final now = DateTime.now();
          final when = now.add(
            Duration(minutes: 10 + rand.nextInt(60 * 24 * 3)),
          );
          final name = _demoLeagueNames[rand.nextInt(_demoLeagueNames.length)];
          setState(() {
            _isLoggedIn = true;
            _hasSoccerLeague = true;
            _hasBaseballLeague = false;
          });
          setDraft(when, name, isSoccer: true);
          return;
        }
    }
  }

  @override
  void initState() {
    super.initState();

    _searchController = TextEditingController();
    _suggestionsScrollController = ScrollController();
    _playerDirectory = getAllPlayerNames();
    _leagueFuture = ApiService.fetchLeagueData();
    _kboLeagueFuture = ApiService.fetchKboLeagueData();
    _kboLiveRefreshTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (!mounted) return;
      setState(() {
        _leagueFuture = ApiService.fetchLeagueData();
        _kboLeagueFuture = ApiService.fetchKboLeagueData();
      });
      unawaited(_refreshFantasySoccerScores());
    });

    // Restore persisted login state.
    _isLoggedIn = authController.isLoggedIn;
    authController.addListener(_syncAuthToHomeState);

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );

    _fadeController.forward();

    // App launch transition (home animates in without a dedicated splash page).
    _launchController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _launchScale = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(
        parent: _launchController,
        curve: const Interval(0.0, 0.60, curve: Curves.easeOutCubic),
      ),
    );
    _launchSlide =
        Tween<Offset>(begin: Offset.zero, end: const Offset(0, -0.06)).animate(
          CurvedAnimation(
            parent: _launchController,
            curve: const Interval(0.0, 0.60, curve: Curves.easeOutCubic),
          ),
        );
    _launchOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _launchController,
        curve: const Interval(0.25, 1.0, curve: Curves.easeInCubic),
      ),
    );

    if (!_didPlayLaunchIntro) {
      _didPlayLaunchIntro = true;
      _showLaunchIntro = true;
      _launchController.forward().whenComplete(() {
        if (!mounted) return;
        setState(() => _showLaunchIntro = false);
      });
    } else {
      _launchController.value = 1;
      _showLaunchIntro = false;
    }

    _startDraftTimer();
    unawaited(_restoreLocalState());

    assert(() {
      // Only apply demo-random state when no persisted session exists.
      if (_demoRandomState && !authController.isLoggedIn) _applyDemoState();
      return true;
    }());
  }

  void _syncAuthToHomeState() {
    if (!mounted) return;
    final v = authController.isLoggedIn;
    if (_isLoggedIn == v) {
      if (v) {
        unawaited(_restoreLocalState());
        _listenJoinedDrafts();
      }
      return;
    }
    setState(() => _isLoggedIn = v);
    if (v) {
      unawaited(_restoreLocalState());
      _listenJoinedDrafts();
      return;
    }
    if (!v) {
      // When logging out, clear league/draft state (same behavior as before).
      setState(() {
        _hasSoccerLeague = false;
        _hasBaseballLeague = false;
        _draftTime = null;
        _draftLeagueName = null;
        _draftRemaining = Duration.zero;
        _joinedDrafts = const [];
        _isMenuOpen = false;
        _isMyPageOpen = false;
      });
      _draftTimer?.cancel();
      _joinedDraftsSub?.cancel();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _suggestionsScrollController.dispose();
    authController.removeListener(_syncAuthToHomeState);
    _fadeController.dispose();
    _launchController.dispose();
    _draftTimer?.cancel();
    _kboLiveRefreshTimer?.cancel();
    _joinedDraftsSub?.cancel();
    super.dispose();
  }

  void _toggleMenu() {
    setState(() {
      _isMenuOpen = !_isMenuOpen;
      _isMyPageOpen = false;
    });
  }

  void _toggleMyPage() {
    setState(() => _isMyPageOpen = !_isMyPageOpen);
  }

  @override
  Widget build(BuildContext context) {
    final double sidebarWidth = MediaQuery.of(context).size.width * 0.42;
    const double topGap = 140;

    return Stack(
      children: [
        ////////////////////////////////////////////////////////////////
        /// MAIN PAGE
        ////////////////////////////////////////////////////////////////
        Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(60),
            child: _CustomAppBar(
              onMenuPressed: _toggleMenu,
              onMyPagePressed: _toggleMyPage,
              searchController: _searchController,
              onSearch: _handleSearch,
              onChanged: _updateSuggestions,
            ),
          ),
          body: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        children: [
                          SizedBox(
                            height: constraints.maxHeight,
                            child: Stack(
                              children: [
                                Column(
                                  children: [
                                    const SizedBox(height: topGap),
                                    Expanded(
                                      child: Center(
                                        child: CardSwitcher(
                                          isLoggedIn: _isLoggedIn,
                                          hasSoccerLeague: _hasSoccerLeague,
                                          hasBaseballLeague: _hasBaseballLeague,
                                          onFrontLeagueChanged: (isSoccer) {
                                            if (_frontLeagueIsSoccer ==
                                                isSoccer) {
                                              return;
                                            }
                                            setState(
                                              () => _frontLeagueIsSoccer =
                                                  isSoccer,
                                            );
                                            unawaited(_saveLocalState());
                                          },
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                  ],
                                ),
                                Positioned(
                                  top: 92,
                                  left: 0,
                                  right: 0,
                                  child: FadeTransition(
                                    opacity: _fadeAnimation,
                                    child: const Center(
                                      child: Text(
                                        'LeagueIt',
                                        style: TextStyle(
                                          fontSize: 45,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                if (_isLoggedIn && _draftTime != null)
                                  Positioned(
                                    top: 172,
                                    left: 0,
                                    right: 0,
                                    child: GestureDetector(
                                      onTap: () {
                                        final draft =
                                            homeKey.currentState?.primaryDraft;
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => DraftDetailPage(
                                              draft:
                                                  draft ??
                                                  _JoinedDraft(
                                                    leagueId: '',
                                                    leagueName:
                                                        _draftLeagueName ??
                                                        'My League',
                                                    when: _draftTime!,
                                                    isSoccer: true,
                                                  ),
                                            ),
                                          ),
                                        );
                                      },
                                      child: _DraftBanner(
                                        leagueName:
                                            _draftLeagueName ?? 'My League',
                                        remaining: _draftRemaining,
                                        draftTime: _draftTime!,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          // Standings table: full height (no inner scrolling); page scroll handles it.
                          const SizedBox(height: 12),
                          // Only lift the standings card to reduce the gap to the main card area.
                          Transform.translate(
                            offset: const Offset(0, -160),
                            child: Column(
                              children: [
                                GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => StandingsPage(
                                          isSoccer: _frontLeagueIsSoccer,
                                        ),
                                      ),
                                    );
                                  },
                                  child: _HomeStandingsCard(
                                    key: ValueKey(
                                      'home-standings-${_frontLeagueIsSoccer ? 'soccer' : 'baseball'}',
                                    ),
                                    isSoccer: _frontLeagueIsSoccer,
                                    leagueFuture: _frontLeagueIsSoccer
                                        ? _leagueFuture
                                        : _kboLeagueFuture,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => SchedulePage(
                                          isSoccer: _frontLeagueIsSoccer,
                                        ),
                                      ),
                                    );
                                  },
                                  child: _HomeScheduleCard(
                                    key: ValueKey(
                                      'home-schedule-${_frontLeagueIsSoccer ? 'soccer' : 'baseball'}',
                                    ),
                                    isSoccer: _frontLeagueIsSoccer,
                                    leagueFuture: _frontLeagueIsSoccer
                                        ? _leagueFuture
                                        : _kboLeagueFuture,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 28),
                        ],
                      ),
                    );
                  },
                ),
              ),
              if (_suggestions.isNotEmpty)
                Positioned(
                  top: 1, // 검색창 언더바에 바짝
                  right: 70,
                  child: Material(
                    elevation: 8,
                    borderRadius: BorderRadius.circular(12),
                    color: Theme.of(context).cardColor,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minWidth: 190,
                        maxWidth: 190,
                      ),
                      child: Builder(
                        builder: (context) {
                          const double maxH = 220;
                          const double rowH = 44;
                          final double desiredH = _suggestions.length * rowH;
                          final bool needsScroll = desiredH > maxH;
                          final double height = (needsScroll ? maxH : desiredH)
                              .clamp(rowH, maxH);

                          return SizedBox(
                            height: height,
                            child: ScrollbarTheme(
                              data: ScrollbarThemeData(
                                thumbColor: const WidgetStatePropertyAll(
                                  Colors.white,
                                ),
                                trackColor: WidgetStatePropertyAll(
                                  Colors.white.withOpacity(0.18),
                                ),
                                thickness: const WidgetStatePropertyAll(4),
                                radius: const Radius.circular(999),
                              ),
                              child: Scrollbar(
                                controller: _suggestionsScrollController,
                                thumbVisibility: needsScroll,
                                trackVisibility: needsScroll,
                                child: ListView.builder(
                                  controller: _suggestionsScrollController,
                                  padding: EdgeInsets.zero,
                                  itemExtent: rowH,
                                  itemCount: _suggestions.length,
                                  itemBuilder: (_, i) {
                                    final name = _suggestions[i];
                                    final meta = _resolvePlayerMeta(name);
                                    final isDark =
                                        Theme.of(context).brightness ==
                                        Brightness.dark;
                                    final Color muted = isDark
                                        ? Colors.white70
                                        : Colors.black.withOpacity(0.55);
                                    return ListTile(
                                      dense: true,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 12,
                                          ),
                                      title: Text(
                                        name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 13,
                                        ),
                                      ),
                                      trailing: SizedBox(
                                        width: 88,
                                        child: Text(
                                          '${meta.club} #${meta.number}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.right,
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            color: muted,
                                          ),
                                        ),
                                      ),
                                      onTap: () => _handleSearch(name),
                                    );
                                  },
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),

        ////////////////////////////////////////////////////////////////
        /// DIM BACKGROUND (MENU)
        ////////////////////////////////////////////////////////////////
        if (_isMenuOpen)
          AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            opacity: 0.45,
            child: GestureDetector(
              onTap: _toggleMenu,
              child: Container(color: const Color.fromARGB(255, 5, 5, 5)),
            ),
          ),

        ////////////////////////////////////////////////////////////////
        /// SIDE MENU
        ////////////////////////////////////////////////////////////////
        AnimatedPositioned(
          duration: const Duration(milliseconds: 340),
          curve: Curves.easeOutCubic,
          left: _isMenuOpen ? 0 : -sidebarWidth,
          top: 0,
          bottom: 0,
          child: SideMenu(width: sidebarWidth),
        ),

        ////////////////////////////////////////////////////////////////
        /// DIM BACKGROUND (MY PAGE)
        ////////////////////////////////////////////////////////////////
        IgnorePointer(
          ignoring: !_isMyPageOpen,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            opacity: _isMyPageOpen ? 1 : 0,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _toggleMyPage,
              child: Container(
                color: const Color.fromARGB(255, 0, 0, 0).withOpacity(0.35),
              ),
            ),
          ),
        ),

        ////////////////////////////////////////////////////////////////
        /// MY PAGE POPUP
        ////////////////////////////////////////////////////////////////
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
                    isLoggedIn: _isLoggedIn,
                    onLogin: () {
                      updateLogin(true);
                      _toggleMyPage();
                    },
                    onLogout: () {
                      updateLogin(false);
                      _toggleMyPage();
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
        if (_showLaunchIntro)
          Positioned.fill(
            child: IgnorePointer(
              // Block interaction until the intro finishes.
              ignoring: false,
              child: AnimatedBuilder(
                animation: _launchController,
                builder: (context, _) {
                  final theme = Theme.of(context);
                  final isDark = theme.brightness == Brightness.dark;
                  final bg = theme.scaffoldBackgroundColor;
                  final fg = isDark ? Colors.white : Colors.black;
                  return Opacity(
                    opacity: _launchOpacity.value,
                    child: Container(
                      color: bg,
                      child: Center(
                        child: SlideTransition(
                          position: _launchSlide,
                          child: ScaleTransition(
                            scale: _launchScale,
                            child: Text(
                              'LeagueIt',
                              style: TextStyle(
                                fontSize: 56,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.8,
                                color: fg,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }

  void _handleSearch(String query) {
    if (query.isEmpty) return;
    _clearSuggestions();
    _searchController.clear();
    final ownership =
        _MatchDetailPageState._playerOwnerCache[query] ??
        PlayerOwnership.otherTeam;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerProfilePage(name: query, ownership: ownership),
      ),
    ).then((_) {
      _searchController.clear();
      _clearSuggestions();
    });
  }

  void _updateSuggestions(String text) {
    final q = text.trim();
    if (q.isEmpty) {
      _clearSuggestions();
      return;
    }
    final matches = _playerDirectory
        .where((name) => name.toLowerCase().contains(q.toLowerCase()))
        .toList();
    setState(() => _suggestions = matches);
  }

  void _clearSuggestions() {
    if (_suggestions.isEmpty) return;
    setState(() => _suggestions = []);
  }
}

String _formatDuration(Duration d) {
  final days = d.inDays;
  final hours = d.inHours % 24;
  final minutes = d.inMinutes % 60;
  final seconds = d.inSeconds % 60;
  if (days > 0) {
    return '${days}d ${hours}h ${minutes}m ${seconds}s';
  }
  if (hours > 0) {
    return '${hours}h ${minutes}m ${seconds}s';
  }
  return '${minutes}m ${seconds}s';
}

class _DraftBanner extends StatelessWidget {
  final String leagueName;
  final Duration remaining;
  final DateTime draftTime;
  const _DraftBanner({
    required this.leagueName,
    required this.remaining,
    required this.draftTime,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            cs.primary.withOpacity(0.15),
            cs.secondary.withOpacity(0.12),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.onSurface.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: cs.onSurface.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.timer_outlined, size: 26),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$leagueName Draft',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '시작까지 ${_formatDuration(remaining)}',
                  style: TextStyle(
                    color: cs.onSurface.withOpacity(0.75),
                    fontSize: 13,
                  ),
                ),
                Text(
                  'Draft: ${_kstMonthDayTimeLabel(draftTime)}',
                  style: TextStyle(
                    color: cs.onSurface.withOpacity(0.6),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right),
        ],
      ),
    );
  }
}

class DraftDetailPage extends StatefulWidget {
  final _JoinedDraft draft;
  const DraftDetailPage({super.key, required this.draft});

  @override
  State<DraftDetailPage> createState() => _DraftDetailPageState();
}

class _DraftDetailPageState extends State<DraftDetailPage> {
  late Duration _remaining;
  Timer? _timer;
  late int _teamCount;
  late int _memberCount;
  late String _inviteCode;
  late List<_DraftOrderEntry> _draftOrder;
  bool _ordering = false;

  @override
  void initState() {
    super.initState();
    _remaining = widget.draft.when.difference(DateTime.now());
    _teamCount = widget.draft.teamCount;
    _memberCount = widget.draft.memberCount;
    _inviteCode = widget.draft.inviteCode;
    _draftOrder = List<_DraftOrderEntry>.from(widget.draft.draftOrder)
      ..sort((a, b) => a.slot.compareTo(b.slot));
    _startTimer();
    unawaited(_ensureDraftOrderIfNeeded());
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final diff = widget.draft.when.difference(DateTime.now());
      if (!mounted) return;
      if (diff.isNegative) {
        setState(() {
          _remaining = Duration.zero;
        });
        _timer?.cancel();
      } else {
        setState(() {
          _remaining = diff;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _ensureDraftOrderIfNeeded() async {
    if (_ordering) return;
    if (widget.draft.leagueId.isEmpty) return;
    if (_memberCount < _teamCount) return;
    if (_draftOrder.length == _teamCount) return;

    setState(() => _ordering = true);
    try {
      final data = await LeagueService.instance.ensureDraftOrder(
        widget.draft.leagueId,
      );
      if (!mounted) return;
      final raw = data['draftOrder'] as List<dynamic>? ?? const [];
      final next =
          raw
              .whereType<Map>()
              .map(
                (item) => _DraftOrderEntry(
                  uid: '${item['uid'] ?? ''}',
                  displayName: '${item['displayName'] ?? 'Team'}',
                  slot: item['slot'] is int
                      ? item['slot'] as int
                      : int.tryParse('${item['slot'] ?? 0}') ?? 0,
                ),
              )
              .toList()
            ..sort((a, b) => a.slot.compareTo(b.slot));
      setState(() {
        _memberCount = data['memberCount'] is int
            ? data['memberCount'] as int
            : _memberCount;
        _teamCount = data['teamCount'] is int
            ? data['teamCount'] as int
            : _teamCount;
        _draftOrder = next;
      });
    } catch (_) {
      if (!mounted) return;
    } finally {
      if (mounted) setState(() => _ordering = false);
    }
  }

  String? _currentUserDraftTeamName() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    for (final entry in _draftOrder) {
      if (entry.uid == user.uid) return entry.displayName;
    }

    final displayName = user.displayName?.trim() ?? '';
    if (displayName.isNotEmpty) {
      for (final entry in _draftOrder) {
        if (entry.displayName.trim().toLowerCase() ==
            displayName.toLowerCase()) {
          return entry.displayName;
        }
      }
      return displayName;
    }

    final emailPrefix = (user.email ?? '').split('@').first.trim();
    if (emailPrefix.isNotEmpty) {
      for (final entry in _draftOrder) {
        if (entry.displayName.trim().toLowerCase() ==
            emailPrefix.toLowerCase()) {
          return entry.displayName;
        }
      }
      return emailPrefix;
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final bool isCompleted = _isDraftCompletedAt(widget.draft, now);
    final bool canReviewCompletedDraft =
        isCompleted && !_isDraftExpiredAt(widget.draft, now);
    final bool allowEnterWindow = _remaining <= const Duration(hours: 1);
    final bool hasEnoughTeams = _memberCount >= _teamCount;
    final bool hasDraftOrder = _draftOrder.length == _teamCount;
    final bool allowRealDraft =
        !isCompleted &&
        allowEnterWindow &&
        hasEnoughTeams &&
        hasDraftOrder &&
        !_ordering;
    final bool showDraftOrder = allowEnterWindow && _draftOrder.isNotEmpty;
    final String inviteCode = _inviteCode.trim().toUpperCase();
    return Scaffold(
      appBar: AppBar(title: const Text('Draft')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.draft.leagueName,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'Draft 일정: ${_kstMonthDayTimeLabel(widget.draft.when)}',
              style: TextStyle(color: cs.onSurface.withOpacity(0.8)),
            ),
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cs.surface.withOpacity(0.95),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cs.onSurface.withOpacity(0.08)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '참가 상태',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$_memberCount/$_teamCount 팀 참가 중',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    hasEnoughTeams
                        ? '참가 팀 수가 충족되어 실제 Draft를 진행할 수 있습니다.'
                        : '설정된 참가 팀 수가 모두 모여야 실제 Draft가 열립니다.',
                    style: TextStyle(
                      color: cs.onSurface.withOpacity(0.78),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          inviteCode.isEmpty
                              ? '초대 코드 준비 중'
                              : '초대 코드: $inviteCode',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: cs.onSurface,
                          ),
                        ),
                      ),
                      if (inviteCode.isNotEmpty)
                        TextButton.icon(
                          onPressed: () async {
                            await Clipboard.setData(
                              ClipboardData(text: inviteCode),
                            );
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('초대 코드를 복사했습니다.')),
                            );
                          },
                          icon: const Icon(Icons.copy_rounded, size: 18),
                          label: const Text('복사'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cs.surface.withOpacity(0.95),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cs.onSurface.withOpacity(0.08)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Draft 순서',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  if (!allowEnterWindow)
                    Text(
                      'Draft 시작 1시간 전부터 순서가 공개됩니다.',
                      style: TextStyle(
                        color: cs.onSurface.withOpacity(0.76),
                        height: 1.4,
                      ),
                    )
                  else if (!hasEnoughTeams)
                    Text(
                      '참가 팀 수가 모두 모이면 랜덤 순서가 확정됩니다.',
                      style: TextStyle(
                        color: cs.onSurface.withOpacity(0.76),
                        height: 1.4,
                      ),
                    )
                  else if (_ordering)
                    Row(
                      children: [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: cs.primary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text('Draft 순서를 확정하는 중입니다.'),
                      ],
                    )
                  else if (showDraftOrder)
                    Column(
                      children: _draftOrder
                          .map(
                            (entry) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Row(
                                children: [
                                  Container(
                                    width: 30,
                                    height: 30,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: cs.primary.withOpacity(0.12),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text(
                                      '${entry.slot}',
                                      style: TextStyle(
                                        color: cs.primary,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      entry.displayName,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                    )
                  else
                    Text(
                      '순서가 아직 확정되지 않았습니다. 잠시 후 다시 확인해 주세요.',
                      style: TextStyle(
                        color: cs.onSurface.withOpacity(0.76),
                        height: 1.4,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cs.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '카운트다운',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isCompleted
                        ? 'Draft가 완료되었어요.'
                        : _remaining.isNegative || _remaining == Duration.zero
                        ? 'Draft가 시작되었어요.'
                        : _formatDuration(_remaining),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Draft 정보',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              '드래프트 시작 1시간 전부터 실제 Draft 입장이 가능합니다. 참가 팀 수가 모이기 전에는 Mock Draft로만 연습할 수 있습니다.',
              style: TextStyle(
                color: cs.onSurface.withOpacity(0.8),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatedButton(
                  onPressed: allowRealDraft || canReviewCompletedDraft
                      ? () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DraftPage(
                                leagueId: widget.draft.leagueId,
                                draftTime: widget.draft.when,
                                leagueName: widget.draft.leagueName,
                                teamCount: _teamCount,
                                roundCount: widget.draft.roundCount,
                                isSoccer: widget.draft.isSoccer,
                                draftOrderEntries: _draftOrder,
                                savedBoard: widget.draft.draftBoard,
                                reviewOnly: canReviewCompletedDraft,
                                teamNames: _draftOrder
                                    .map((entry) => entry.displayName)
                                    .toList(),
                              ),
                            ),
                          );
                        }
                      : null,
                  child: Text(
                    allowRealDraft
                        ? 'Enter Draft (실제)'
                        : canReviewCompletedDraft
                        ? 'Draft 결과 보기'
                        : isCompleted
                        ? 'Draft 완료'
                        : !allowEnterWindow
                        ? '입장 가능까지 ${_formatDuration(_remaining)}'
                        : _ordering
                        ? 'Draft 순서 확정 중...'
                        : !hasDraftOrder
                        ? 'Draft 순서 확정 대기 중'
                        : '참가 팀 $_memberCount/$_teamCount',
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: () {
                    final orderedNames = _draftOrder.length == _teamCount
                        ? _draftOrder.map((entry) => entry.displayName).toList()
                        : null;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DraftPage(
                          leagueId: widget.draft.leagueId,
                          draftTime: widget.draft.when,
                          leagueName: widget.draft.leagueName,
                          teamCount: widget.draft.teamCount,
                          roundCount: widget.draft.roundCount,
                          isMock: true,
                          isSoccer: widget.draft.isSoccer,
                          draftOrderEntries: _draftOrder,
                          teamNames: orderedNames,
                          myTeamName: _currentUserDraftTeamName(),
                        ),
                      ),
                    );
                  },
                  child: const Text('Mock Draft'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
