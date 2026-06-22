import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiService {
  ApiService._();

  static const String baseUrl =
      'https://us-central1-leagueit-e6a05.cloudfunctions.net/getLeagueStandings';
  static const String teamStatisticsUrl =
      'https://us-central1-leagueit-e6a05.cloudfunctions.net/getTeamStatistics';
  static const String fixtureDetailsUrl =
      'https://us-central1-leagueit-e6a05.cloudfunctions.net/getFixtureDetails';
  static const String kboLeagueDataUrl =
      'https://us-central1-leagueit-e6a05.cloudfunctions.net/getKboLeagueData';
  static const String kboMatchDetailsUrl =
      'https://us-central1-leagueit-e6a05.cloudfunctions.net/getKboMatchDetails';
  static const int targetSeason = 2026;
  static const List<int> _retryableStatusCodes = <int>[429, 500, 502, 503, 504];
  static const Map<String, String> _kLeagueApiTeamNames = {
    '부천FC 1995': 'Bucheon FC 1995',
    '강원 FC': 'Gangwon FC',
    'FC 안양': 'FC Anyang',
    '대전 하나 시티즌': 'Daejeon Citizen',
    '광주 FC': 'Gwangju FC',
    '제주 유나이티드': 'Jeju United FC',
    '제주 SK': 'Jeju United FC',
    '전북 현대 모터스': 'Jeonbuk Motors',
    '인천 유나이티드': 'Incheon United',
    '포항 스틸러스': 'Pohang Steelers',
    'FC 서울': 'FC Seoul',
    '울산 HD': 'Ulsan Hyundai FC',
    '김천 상무': 'Gimcheon Sangmu FC',
  };

  static Future<http.Response> _getWithRetry(
    Uri uri, {
    int maxAttempts = 3,
  }) async {
    http.Response? lastResponse;
    Object? lastError;
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        final response = await http
            .get(uri)
            .timeout(const Duration(seconds: 12));
        if (response.statusCode == 200) {
          return response;
        }
        lastResponse = response;
        if (!_retryableStatusCodes.contains(response.statusCode) ||
            attempt == maxAttempts - 1) {
          break;
        }
      } catch (error) {
        lastError = error;
        if (attempt == maxAttempts - 1) rethrow;
      }
      await Future<void>.delayed(Duration(milliseconds: 350 * (attempt + 1)));
    }
    if (lastResponse != null) {
      throw Exception('Request failed (${lastResponse.statusCode})');
    }
    if (lastError != null) {
      throw Exception('Request failed ($lastError)');
    }
    throw Exception('Request failed');
  }

  static Future<Map<String, dynamic>> fetchLeagueData() async {
    final response = await _getWithRetry(Uri.parse(baseUrl));

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Invalid response format');
    }

    final fixtures = _extractFixtures(decoded);
    final standings = _extractStandings(decoded, fixtures: fixtures);
    debugPrint(
      'API loaded: standings=${standings.length}, fixtures=${fixtures.length}',
    );

    return {
      ...decoded,
      'standings': standings,
      'fixtures': fixtures,
      'teams': _extractTeams(decoded),
      'seasons': _extractSeasons(decoded),
    };
  }

  static Future<Map<String, dynamic>> fetchTeamStatistics(String team) async {
    final apiTeamName = _kLeagueApiTeamNames[team.trim()] ?? team;
    final uri = Uri.parse(
      teamStatisticsUrl,
    ).replace(queryParameters: {'team': apiTeamName});
    final response = await _getWithRetry(uri);

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Invalid team statistics response format');
    }

    return decoded;
  }

  static Future<Map<String, dynamic>> fetchFixtureDetails(int fixtureId) async {
    final uri = Uri.parse(
      fixtureDetailsUrl,
    ).replace(queryParameters: {'fixture': '$fixtureId'});
    final response = await _getWithRetry(uri);
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Invalid fixture details response format');
    }
    return decoded;
  }

  static Future<Map<String, dynamic>> fetchKboLeagueData() async {
    final response = await _getWithRetry(Uri.parse(kboLeagueDataUrl));

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Invalid KBO response format');
    }

    final standings = decoded['standings'];
    final matches = decoded['matches'];
    debugPrint(
      'KBO API loaded: standings=${standings is List ? standings.length : 0}, '
      'matches=${matches is List ? matches.length : 0}',
    );

    return decoded;
  }

  static Future<Map<String, dynamic>> fetchKboMatchDetails(
    int matchId, {
    int? fantasyRound,
  }) async {
    final queryParameters = <String, String>{'match': '$matchId'};
    if (fantasyRound != null && fantasyRound > 0) {
      queryParameters['round'] = '$fantasyRound';
    }
    final uri = Uri.parse(
      kboMatchDetailsUrl,
    ).replace(queryParameters: queryParameters);
    final response = await _getWithRetry(uri);

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Invalid KBO match details response format');
    }

    return decoded;
  }

  static List<dynamic> _extractStandings(
    Map<String, dynamic> decoded, {
    required List<dynamic> fixtures,
  }) {
    if (_isPreseason(decoded, fixtures)) {
      return _buildPreseasonStandings();
    }

    final topStandings = decoded['standings'];
    if (topStandings is List<dynamic>) {
      return topStandings;
    }

    final responseList = decoded['response'];
    if (responseList is List && responseList.isNotEmpty) {
      final first = responseList.first;
      if (first is Map<String, dynamic>) {
        final league = first['league'];
        if (league is Map<String, dynamic>) {
          final standingsGroup = league['standings'];
          if (standingsGroup is List && standingsGroup.isNotEmpty) {
            final firstStandingGroup = standingsGroup.first;
            if (firstStandingGroup is List<dynamic>) {
              return firstStandingGroup;
            }
          }
        }
      }
    }

    return _buildPreseasonStandings();
  }

  static List<dynamic> _extractFixtures(Map<String, dynamic> decoded) {
    final topFixtures = decoded['fixtures'];
    if (topFixtures is List<dynamic>) {
      return topFixtures;
    }
    return const <dynamic>[];
  }

  static List<dynamic> _extractTeams(Map<String, dynamic> decoded) {
    final topTeams = decoded['teams'];
    if (topTeams is List<dynamic>) {
      return topTeams;
    }
    return const <dynamic>[];
  }

  static List<dynamic> _extractSeasons(Map<String, dynamic> decoded) {
    final topSeasons = decoded['seasons'];
    if (topSeasons is List<dynamic>) {
      return topSeasons;
    }
    return const <dynamic>[];
  }

  static bool _isPreseason(
    Map<String, dynamic> decoded,
    List<dynamic> fixtures,
  ) {
    final season = _readSeason(decoded, fixtures);
    if (season != targetSeason) return false;

    if (fixtures.isEmpty) return true;

    DateTime? firstKickoffUtc;
    for (final raw in fixtures) {
      final map = raw is Map<String, dynamic>
          ? raw
          : Map<String, dynamic>.from(raw as Map);
      final fixture = (map['fixture'] as Map?)?.cast<String, dynamic>() ?? {};
      final dateString = fixture['date']?.toString();
      if (dateString == null) continue;
      final parsed = DateTime.tryParse(dateString)?.toUtc();
      if (parsed == null) continue;
      if (firstKickoffUtc == null || parsed.isBefore(firstKickoffUtc)) {
        firstKickoffUtc = parsed;
      }
    }

    if (firstKickoffUtc == null) return true;
    return DateTime.now().toUtc().isBefore(firstKickoffUtc);
  }

  static int? _readSeason(
    Map<String, dynamic> decoded,
    List<dynamic> fixtures,
  ) {
    final parameters = decoded['parameters'];
    final seasonValue = parameters is Map ? parameters['season'] : null;
    final fromParameters = int.tryParse('$seasonValue');
    if (fromParameters != null) return fromParameters;

    final topSeason = int.tryParse('${decoded['season']}');
    if (topSeason != null) return topSeason;

    for (final raw in fixtures) {
      final map = raw is Map<String, dynamic>
          ? raw
          : Map<String, dynamic>.from(raw as Map);
      final league = (map['league'] as Map?)?.cast<String, dynamic>();
      final season = int.tryParse('${league?['season']}');
      if (season != null) return season;
    }
    return null;
  }

  static List<Map<String, dynamic>> _buildPreseasonStandings() {
    const teams = <String>[
      'Bucheon FC 1995',
      'Daejeon Hana Citizen',
      'FC Anyang',
      'FC Seoul',
      'Gangwon FC',
      'Gimcheon Sangmu',
      'Gwangju FC',
      'Incheon United',
      'Jeju SK',
      'Jeonbuk Hyundai Motors',
      'Pohang Steelers',
      'Ulsan HD',
    ];

    return List<Map<String, dynamic>>.generate(teams.length, (index) {
      return <String, dynamic>{
        'rank': index + 1,
        'team': <String, dynamic>{'name': teams[index], 'logo': ''},
        'all': <String, dynamic>{'played': 0, 'win': 0, 'draw': 0, 'lose': 0},
        'goals': <String, dynamic>{'for': 0, 'against': 0},
        'goalsDiff': 0,
        'points': 0,
      };
    });
  }
}
