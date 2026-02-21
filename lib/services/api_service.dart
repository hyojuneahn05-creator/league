import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiService {
  ApiService._();

  static const String baseUrl =
      'https://us-central1-leagueit-e6a05.cloudfunctions.net/getLeagueStandings';
  static const int targetSeason = 2026;

  static Future<Map<String, dynamic>> fetchLeagueData() async {
    final response = await http.get(Uri.parse(baseUrl));
    if (response.statusCode != 200) {
      throw Exception('Failed to load league data (${response.statusCode})');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Invalid response format');
    }

    final fixtures = _extractFixtures(decoded);
    final standings = _extractStandings(decoded, fixtures: fixtures);
    debugPrint(
      'API loaded: standings=${standings.length}, fixtures=${fixtures.length}',
    );

    return {'standings': standings, 'fixtures': fixtures};
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
