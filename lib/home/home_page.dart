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

// IMPORTANT:
// Only Mock Draft remains enabled.
// All other mock league/match/standings data must be hidden until real data is connected.
const bool kUseMockDataOutsideDraft = true;

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

  const _JoinedDraft({
    required this.leagueId,
    required this.leagueName,
    required this.when,
    required this.isSoccer,
  });
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
  late final Future<Map<String, dynamic>> _leagueFuture;

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
  Duration _draftRemaining = Duration.zero;
  List<_JoinedDraft> _joinedDrafts = const [];
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
  List<_JoinedDraft> get joinedDrafts => List.unmodifiable(_joinedDrafts);

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
              drafts.add(
                _JoinedDraft(
                  leagueId: doc.id,
                  leagueName: name,
                  when: when,
                  isSoccer: _parseIsSoccerLeague(data),
                ),
              );
            }
            drafts.sort((a, b) => a.when.compareTo(b.when));
            if (!mounted) return;
            setState(() {
              _joinedDrafts = drafts;
              _setPrimaryDraftFromJoinedDrafts();
            });
            _startDraftTimer();
          },
          onError: (e, st) {
            debugPrint('watchMyDrafts error: $e');
            debugPrint('$st');
          },
        );
  }

  DateTime? _parseDraftDate(Map<String, dynamic> data) {
    final raw = data['draftDateTime'] ?? data['draftAt'] ?? data['draftTime'];
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw);
    if (raw is int) return DateTime.fromMillisecondsSinceEpoch(raw);
    return null;
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
    if (_joinedDrafts.isEmpty) {
      _draftTime = null;
      _draftLeagueName = null;
      _draftRemaining = Duration.zero;
      _draftTimer?.cancel();
      return;
    }

    final now = DateTime.now();
    final upcoming = _joinedDrafts.where((d) => d.when.isAfter(now)).toList()
      ..sort((a, b) => a.when.compareTo(b.when));

    if (upcoming.isEmpty) {
      _draftTime = null;
      _draftLeagueName = null;
      _draftRemaining = Duration.zero;
      _draftTimer?.cancel();
      return;
    }

    _draftTime = upcoming.first.when;
    _draftLeagueName = upcoming.first.leagueName;
  }

  void _startDraftTimer() {
    _draftTimer?.cancel();
    if (_draftTime == null) return;
    _tickDraft();
    _draftTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _tickDraft();
    });
  }

  void _tickDraft() {
    if (_draftTime == null) return;
    final remaining = _draftTime!.difference(DateTime.now());
    if (remaining.isNegative) {
      setState(_setPrimaryDraftFromJoinedDrafts);
      _startDraftTimer();
    } else {
      setState(() => _draftRemaining = remaining);
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
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => DraftDetailPage(
                                              leagueName:
                                                  _draftLeagueName ??
                                                  'My League',
                                              draftTime: _draftTime!,
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
                                if (kUseMockDataOutsideDraft) ...[
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
                                      isSoccer: _frontLeagueIsSoccer,
                                      leagueFuture: _leagueFuture,
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => const SchedulePage(
                                            isSoccer: true,
                                          ),
                                        ),
                                      );
                                    },
                                    child: _HomeScheduleCard(
                                      isSoccer: true,
                                      leagueFuture: _leagueFuture,
                                    ),
                                  ),
                                ] else ...[
                                  _comingSoonCard(
                                    '공식 리그 순위/일정 데이터 연동 준비 중',
                                    subtitle: 'Mock 데이터는 Draft 기능에서만 사용합니다.',
                                  ),
                                ],
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
                  'Draft: ${draftTime.month}/${draftTime.day} ${draftTime.hour.toString().padLeft(2, '0')}:${draftTime.minute.toString().padLeft(2, '0')}',
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
  final String leagueName;
  final DateTime draftTime;
  const DraftDetailPage({
    super.key,
    required this.leagueName,
    required this.draftTime,
  });

  @override
  State<DraftDetailPage> createState() => _DraftDetailPageState();
}

class _DraftDetailPageState extends State<DraftDetailPage> {
  late Duration _remaining;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _remaining = widget.draftTime.difference(DateTime.now());
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final diff = widget.draftTime.difference(DateTime.now());
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bool allowEnter = _remaining <= const Duration(hours: 1);
    return Scaffold(
      appBar: AppBar(title: const Text('Draft')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.leagueName,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'Draft 일정: ${widget.draftTime.month}/${widget.draftTime.day} ${widget.draftTime.hour.toString().padLeft(2, '0')}:${widget.draftTime.minute.toString().padLeft(2, '0')}',
              style: TextStyle(color: cs.onSurface.withOpacity(0.8)),
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
                    _remaining.isNegative || _remaining == Duration.zero
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
              '드래프트 시작 1시간 전부터 입장 가능합니다. 각 픽당 1분30초가 주어집니다.',
              style: TextStyle(
                color: cs.onSurface.withOpacity(0.8),
                height: 1.4,
              ),
            ),
            const Spacer(),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatedButton(
                  onPressed: allowEnter
                      ? () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DraftPage(
                                draftTime: widget.draftTime,
                                leagueName: widget.leagueName,
                              ),
                            ),
                          );
                        }
                      : null,
                  child: Text(
                    allowEnter
                        ? 'Enter Draft (실제)'
                        : '입장 가능까지 ${_formatDuration(_remaining)}',
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DraftPage(
                          draftTime: widget.draftTime,
                          leagueName: widget.leagueName,
                          isMock: true,
                        ),
                      ),
                    );
                  },
                  child: const Text('Mock Draft (언제나 연습)'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
