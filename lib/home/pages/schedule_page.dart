part of '../home_page.dart';

class SchedulePage extends StatefulWidget {
  final bool isSoccer;

  const SchedulePage({super.key, required this.isSoccer});

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  bool _isMyPageOpen = false;
  String? _selectedFixtureRound;
  String? _selectedKboDate;
  late Future<Map<String, dynamic>> _leagueFuture;
  ScrollController? _roundScrollController;
  ScrollController? _kboDateScrollController;
  final Map<String, GlobalKey> _roundPillKeys = {};
  final Map<String, GlobalKey> _kboDatePillKeys = {};
  bool _didAlignInitialRound = false;
  bool _didAlignInitialKboDate = false;
  double _roundDragDx = 0;
  double _kboDateDragDx = 0;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _leagueFuture = _fetchLeagueData();
    _refreshTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (!mounted) return;
      setState(() {
        _leagueFuture = _fetchLeagueData();
      });
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _roundScrollController?.dispose();
    _kboDateScrollController?.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _fetchLeagueData() {
    return widget.isSoccer
        ? ApiService.fetchLeagueData()
        : ApiService.fetchKboLeagueData();
  }

  void _toggleMyPage() => setState(() => _isMyPageOpen = !_isMyPageOpen);

  void _selectRound(String round) {
    if (_selectedFixtureRound == round) return;
    setState(() => _selectedFixtureRound = round);
  }

  void _selectKboDate(String date) {
    if (_selectedKboDate == date) return;
    setState(() => _selectedKboDate = date);
  }

  void _startRoundSwipe(DragStartDetails _) {
    _roundDragDx = 0;
  }

  void _updateRoundSwipe(DragUpdateDetails details) {
    _roundDragDx += details.primaryDelta ?? 0;
  }

  void _endRoundSwipe(
    List<String> rounds,
    String selectedRound,
    DragEndDetails details,
  ) {
    final velocity = details.primaryVelocity ?? 0;
    final useVelocity = velocity.abs() >= 180;
    final direction = useVelocity ? velocity : _roundDragDx;
    _roundDragDx = 0;

    if (direction.abs() < (useVelocity ? 1 : 48)) return;

    final currentIndex = rounds.indexOf(selectedRound);
    if (currentIndex < 0) return;

    final nextIndex = direction < 0 ? currentIndex + 1 : currentIndex - 1;
    if (nextIndex < 0 || nextIndex >= rounds.length) return;

    _selectRound(rounds[nextIndex]);
  }

  void _startKboDateSwipe(DragStartDetails _) {
    _kboDateDragDx = 0;
  }

  void _updateKboDateSwipe(DragUpdateDetails details) {
    _kboDateDragDx += details.primaryDelta ?? 0;
  }

  void _endKboDateSwipe(
    List<String> dates,
    String selectedDate,
    DragEndDetails details,
  ) {
    final velocity = details.primaryVelocity ?? 0;
    final useVelocity = velocity.abs() >= 180;
    final direction = useVelocity ? velocity : _kboDateDragDx;
    _kboDateDragDx = 0;

    if (direction.abs() < (useVelocity ? 1 : 48)) return;

    final currentIndex = dates.indexOf(selectedDate);
    if (currentIndex < 0) return;

    final nextIndex = direction < 0 ? currentIndex + 1 : currentIndex - 1;
    if (nextIndex < 0 || nextIndex >= dates.length) return;

    _selectKboDate(dates[nextIndex]);
  }

  void _scrollSelectedRoundIntoView(
    List<String> rounds,
    String selectedRound, {
    bool animated = true,
  }) {
    if (!rounds.contains(selectedRound)) return;
    final keyContext = _roundPillKeys[selectedRound]?.currentContext;
    if (keyContext == null) return;

    Scrollable.ensureVisible(
      keyContext,
      duration: animated ? const Duration(milliseconds: 280) : Duration.zero,
      curve: Curves.easeOutCubic,
      alignment: 0.45,
      alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
    );
  }

  void _scrollSelectedKboDateIntoView(
    List<String> dates,
    String selectedDate, {
    bool animated = true,
  }) {
    if (!dates.contains(selectedDate)) return;
    final keyContext = _kboDatePillKeys[selectedDate]?.currentContext;
    if (keyContext == null) return;

    Scrollable.ensureVisible(
      keyContext,
      duration: animated ? const Duration(milliseconds: 280) : Duration.zero,
      curve: Curves.easeOutCubic,
      alignment: 0.45,
      alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final Color text = isDark ? Colors.white : Colors.black87;
    final Color muted = isDark ? Colors.white70 : Colors.black54;
    final Color border = isDark ? Colors.white12 : Colors.black12;
    final Color surface = isDark
        ? const Color.fromARGB(255, 30, 30, 30)
        : theme.cardColor;
    if (widget.isSoccer) {
      return _OverlayScaffold(
        isMyPageOpen: _isMyPageOpen,
        onToggleMyPage: _toggleMyPage,
        showSearch: false,
        child: FutureBuilder<Map<String, dynamic>>(
          future: _leagueFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: _comingSoonCard(
                  'K리그 일정을 불러오지 못했습니다.',
                  subtitle: '${snapshot.error}',
                ),
              );
            }

            final allFixtures =
                snapshot.data?['fixtures'] as List<dynamic>? ?? [];
            final fixtures = _kLeagueFixturesFromApi(allFixtures);
            final standings = _soccerRowsFromApi(
              snapshot.data?['standings'] as List<dynamic>?,
            );
            final recordsByTeam = {
              for (final row in standings)
                row.team: '${row.wins}승 ${row.draws}무 ${row.losses}패',
            };
            final roundKeys = _fixtureRoundKeys(fixtures);
            final selectedKey =
                _selectedFixtureRound != null &&
                    roundKeys.contains(_selectedFixtureRound)
                ? _selectedFixtureRound!
                : _defaultFixtureRound(fixtures);
            final selectedFixtures = fixtures
                .where((fixture) => fixture.round == selectedKey)
                .toList();
            final selectedRoundLabel = _roundTitleLabel(selectedKey);
            _roundScrollController ??= ScrollController();
            WidgetsBinding.instance.addPostFrameCallback((_) {
              final animated = _didAlignInitialRound;
              _scrollSelectedRoundIntoView(
                roundKeys,
                selectedKey,
                animated: animated,
              );
              _didAlignInitialRound = true;
            });

            return CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color.fromARGB(255, 30, 30, 30)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(color: border),
                            boxShadow: isDark
                                ? const []
                                : const [
                                    BoxShadow(
                                      color: Colors.black12,
                                      blurRadius: 12,
                                      offset: Offset(0, 6),
                                    ),
                                  ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'K League Schedule',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  color: text,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                selectedRoundLabel.isEmpty
                                    ? '일정 없음'
                                    : selectedRoundLabel,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  color: muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (fixtures.isEmpty)
                          _comingSoonCard(
                            '공식 일정이 아직 없습니다.',
                            subtitle: 'API에 일정이 등록되면 자동으로 표시됩니다.',
                          )
                        else ...[
                          SizedBox(
                            height: 50,
                            child: SingleChildScrollView(
                              controller: _roundScrollController,
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  for (
                                    int i = 0;
                                    i < roundKeys.length;
                                    i++
                                  ) ...[
                                    if (i != 0) const SizedBox(width: 10),
                                    KeyedSubtree(
                                      key: _roundPillKeys.putIfAbsent(
                                        roundKeys[i],
                                        () => GlobalKey(),
                                      ),
                                      child: _FixtureRoundPill(
                                        label: _roundPillLabel(roundKeys[i]),
                                        selected: roundKeys[i] == selectedKey,
                                        text: text,
                                        muted: muted,
                                        border: border,
                                        onTap: () => _selectRound(roundKeys[i]),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onHorizontalDragStart: _startRoundSwipe,
                            onHorizontalDragUpdate: _updateRoundSwipe,
                            onHorizontalDragEnd: (details) =>
                                _endRoundSwipe(roundKeys, selectedKey, details),
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 240),
                              switchInCurve: Curves.easeOutCubic,
                              switchOutCurve: Curves.easeOutCubic,
                              transitionBuilder: (child, animation) {
                                final offset = Tween<Offset>(
                                  begin: const Offset(0.04, 0),
                                  end: Offset.zero,
                                ).animate(animation);
                                return FadeTransition(
                                  opacity: animation,
                                  child: SlideTransition(
                                    position: offset,
                                    child: child,
                                  ),
                                );
                              },
                              child: selectedFixtures.isEmpty
                                  ? KeyedSubtree(
                                      key: ValueKey('empty-$selectedKey'),
                                      child: _comingSoonCard(
                                        '선택한 라운드에 경기가 없습니다.',
                                        subtitle: '다른 라운드를 선택해 주세요.',
                                      ),
                                    )
                                  : Column(
                                      key: ValueKey(selectedKey),
                                      children: [
                                        for (
                                          int i = 0;
                                          i < selectedFixtures.length;
                                          i++
                                        ) ...[
                                          if (i != 0)
                                            const SizedBox(height: 16),
                                          _ApiFixtureCard(
                                            fixture: selectedFixtures[i],
                                            homeRecord:
                                                recordsByTeam[selectedFixtures[i]
                                                    .home] ??
                                                '',
                                            awayRecord:
                                                recordsByTeam[selectedFixtures[i]
                                                    .away] ??
                                                '',
                                            text: text,
                                            muted: muted,
                                            border: border,
                                            surface: surface,
                                            onTap: selectedFixtures[i].id > 0
                                                ? () {
                                                    Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                        builder: (_) =>
                                                            _KLeagueFixtureDetailPage(
                                                              fixture:
                                                                  selectedFixtures[i],
                                                            ),
                                                      ),
                                                    );
                                                  }
                                                : null,
                                          ),
                                        ],
                                      ],
                                    ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      );
    }

    Widget kboMatchCard(_KboMatch match, {VoidCallback? onTap}) {
      final score = match.hasScore
          ? '${match.homeScore} : ${match.awayScore}'
          : '-:-';
      final statusLabel = _kboStatusLabel(match.status);
      final isLive = _isKboLiveStatus(match.status);
      final badgeBackground = isLive
          ? const Color(0xFFE8F7EC)
          : const Color(0xFFFFEEE2);
      final badgeBorder = isLive
          ? const Color(0xFFB7E4C7)
          : const Color(0xFFFFD1B3);
      final badgeText = isLive
          ? const Color(0xFF16A34A)
          : const Color(0xFFE85D04);
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Ink(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 16, 18, 16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: border),
              boxShadow: isDark
                  ? const []
                  : const [
                      BoxShadow(
                        color: Color(0x14000000),
                        blurRadius: 16,
                        offset: Offset(0, 8),
                      ),
                    ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: badgeBackground,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: badgeBorder),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: badgeText,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      match.dateTimeLabel,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: muted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        match.home,
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
                    Container(
                      width: 102,
                      height: 64,
                      alignment: Alignment.center,
                      margin: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white10
                            : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: border),
                      ),
                      child: Text(
                        score,
                        style: TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.w900,
                          color: text,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        match.away,
                        textAlign: TextAlign.right,
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
                  ],
                ),
                if (match.venue.isNotEmpty || match.city.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    [
                      match.venue,
                      match.city,
                    ].where((e) => e.isNotEmpty).join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: muted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return _OverlayScaffold(
      isMyPageOpen: _isMyPageOpen,
      onToggleMyPage: _toggleMyPage,
      showSearch: false,
      child: FutureBuilder<Map<String, dynamic>>(
        future: _leagueFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: _comingSoonCard(
                'KBO 일정을 불러오지 못했습니다.',
                subtitle: '${snapshot.error}',
              ),
            );
          }

          final matches = _kboMatchesFromApi(
            snapshot.data?['matches'] as List<dynamic>?,
          );
          final dateKeys = _kboDateKeys(matches);
          final selectedDate =
              _selectedKboDate != null && dateKeys.contains(_selectedKboDate)
              ? _selectedKboDate!
              : _kboDefaultDate(matches);
          final selectedMatches = matches
              .where((match) => match.date == selectedDate)
              .toList();
          _kboDateScrollController ??= ScrollController();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final animated = _didAlignInitialKboDate;
            _scrollSelectedKboDateIntoView(
              dateKeys,
              selectedDate,
              animated: animated,
            );
            _didAlignInitialKboDate = true;
          });

          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color.fromARGB(255, 30, 30, 30)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: border),
                          boxShadow: isDark
                              ? const []
                              : const [
                                  BoxShadow(
                                    color: Colors.black12,
                                    blurRadius: 12,
                                    offset: Offset(0, 6),
                                  ),
                                ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'KBO Schedule',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: text,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              selectedDate.isEmpty
                                  ? '일정 없음'
                                  : _homeScheduleDateLabel(selectedDate),
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                color: muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (matches.isEmpty)
                        _comingSoonCard(
                          '공식 일정이 아직 없습니다.',
                          subtitle: 'API에 일정이 등록되면 자동으로 표시됩니다.',
                        )
                      else ...[
                        SizedBox(
                          height: 50,
                          child: SingleChildScrollView(
                            controller: _kboDateScrollController,
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                for (int i = 0; i < dateKeys.length; i++) ...[
                                  if (i != 0) const SizedBox(width: 10),
                                  KeyedSubtree(
                                    key: _kboDatePillKeys.putIfAbsent(
                                      dateKeys[i],
                                      () => GlobalKey(),
                                    ),
                                    child: _FixtureRoundPill(
                                      label: _homeScheduleDateLabel(
                                        dateKeys[i],
                                      ),
                                      selected: dateKeys[i] == selectedDate,
                                      text: text,
                                      muted: muted,
                                      border: border,
                                      onTap: () => _selectKboDate(dateKeys[i]),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onHorizontalDragStart: _startKboDateSwipe,
                          onHorizontalDragUpdate: _updateKboDateSwipe,
                          onHorizontalDragEnd: (details) =>
                              _endKboDateSwipe(dateKeys, selectedDate, details),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 240),
                            switchInCurve: Curves.easeOutCubic,
                            switchOutCurve: Curves.easeOutCubic,
                            transitionBuilder: (child, animation) {
                              final offset = Tween<Offset>(
                                begin: const Offset(0.04, 0),
                                end: Offset.zero,
                              ).animate(animation);
                              return FadeTransition(
                                opacity: animation,
                                child: SlideTransition(
                                  position: offset,
                                  child: child,
                                ),
                              );
                            },
                            child: selectedMatches.isEmpty
                                ? KeyedSubtree(
                                    key: ValueKey('empty-$selectedDate'),
                                    child: _comingSoonCard(
                                      '선택한 날짜에 경기가 없습니다.',
                                      subtitle: '다른 날짜를 선택해 주세요.',
                                    ),
                                  )
                                : Column(
                                    key: ValueKey(selectedDate),
                                    children: [
                                      for (
                                        int i = 0;
                                        i < selectedMatches.length;
                                        i++
                                      ) ...[
                                        if (i != 0) const SizedBox(height: 16),
                                        kboMatchCard(
                                          selectedMatches[i],
                                          onTap: selectedMatches[i].id > 0
                                              ? () {
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (_) =>
                                                          _KboMatchDetailPage(
                                                            match:
                                                                selectedMatches[i],
                                                          ),
                                                    ),
                                                  );
                                                }
                                              : null,
                                        ),
                                      ],
                                    ],
                                  ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _KboMatchDetailPage extends StatefulWidget {
  final _KboMatch match;

  const _KboMatchDetailPage({required this.match});

  @override
  State<_KboMatchDetailPage> createState() => _KboMatchDetailPageState();
}

class _KboMatchDetailPageState extends State<_KboMatchDetailPage> {
  bool _isMyPageOpen = false;
  late Future<Map<String, dynamic>> _detailFuture;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _detailFuture = ApiService.fetchKboMatchDetails(widget.match.id);
    _refreshTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (!mounted) return;
      setState(() {
        _detailFuture = ApiService.fetchKboMatchDetails(widget.match.id);
      });
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _toggleMyPage() => setState(() => _isMyPageOpen = !_isMyPageOpen);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text = isDark ? Colors.white : const Color(0xFF202124);
    final muted = isDark ? Colors.white70 : const Color(0xFF7B7B7B);
    final border = isDark ? Colors.white12 : const Color(0xFFE5E5E5);

    return _OverlayScaffold(
      isMyPageOpen: _isMyPageOpen,
      onToggleMyPage: _toggleMyPage,
      showSearch: false,
      title: '경기 상세',
      child: FutureBuilder<Map<String, dynamic>>(
        future: _detailFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: _comingSoonCard(
                'KBO 경기 상세를 불러오지 못했습니다.',
                subtitle: '${snapshot.error}',
              ),
            );
          }

          final data = snapshot.data ?? const <String, dynamic>{};
          final match = _fixtureAsMap(data['match']);
          final home = _fixtureText(match['home'], widget.match.home);
          final away = _fixtureText(match['away'], widget.match.away);
          final homeScore =
              _readNullableInt(match['homeScore']) ?? widget.match.homeScore;
          final awayScore =
              _readNullableInt(match['awayScore']) ?? widget.match.awayScore;
          final date = _kboResolvedDate(match, widget.match);
          final time = _kboResolvedTime(match, widget.match);
          final status = _fixtureText(match['status'], widget.match.status);
          final venue = _fixtureText(match['venue'], widget.match.venue);
          final city = _fixtureText(match['city'], widget.match.city);
          final lineups = _fixtureAsList(data['lineups']);

          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 34),
                sliver: SliverList(
                  delegate: SliverChildListDelegate.fixed([
                    _KboScoreHeroCard(
                      home: home,
                      away: away,
                      homeScore: homeScore,
                      awayScore: awayScore,
                      date: date,
                      time: time,
                      status: status,
                      text: text,
                      muted: muted,
                      border: border,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 24),
                    _KboSectionTitle('Inning Breakdown', color: text),
                    const SizedBox(height: 12),
                    _KboInningBreakdownCard(
                      innings: _fixtureAsList(data['innings']),
                      home: home,
                      away: away,
                      homeScore: homeScore,
                      awayScore: awayScore,
                      text: text,
                      muted: muted,
                      border: border,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 24),
                    _KboSectionTitle('Pitching', color: text),
                    const SizedBox(height: 12),
                    _KboPitchingCard(
                      pitching: _fixtureAsMap(data['pitching']),
                      lineups: lineups,
                      home: home,
                      away: away,
                      homeScore: homeScore,
                      awayScore: awayScore,
                      text: text,
                      muted: muted,
                      border: border,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 24),
                    _KboSectionTitle('Starting Lineups', color: text),
                    const SizedBox(height: 12),
                    _KboStartingLineupsCard(
                      lineups: lineups,
                      home: home,
                      away: away,
                      text: text,
                      muted: muted,
                      border: border,
                      isDark: isDark,
                    ),
                    if (venue.isNotEmpty || city.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      _KboSectionTitle('경기 정보', color: text),
                      const SizedBox(height: 12),
                      _KboGameInfoCard(
                        venue: venue,
                        city: city,
                        text: text,
                        muted: muted,
                        border: border,
                        isDark: isDark,
                      ),
                    ],
                  ]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _KboScoreHeroCard extends StatelessWidget {
  final String home;
  final String away;
  final int? homeScore;
  final int? awayScore;
  final String date;
  final String time;
  final String status;
  final Color text;
  final Color muted;
  final Color border;
  final bool isDark;

  const _KboScoreHeroCard({
    required this.home,
    required this.away,
    required this.homeScore,
    required this.awayScore,
    required this.date,
    required this.time,
    required this.status,
    required this.text,
    required this.muted,
    required this.border,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final score = homeScore == null || awayScore == null
        ? '-:-'
        : '$homeScore : $awayScore';
    return _KboDetailCard(
      border: border,
      isDark: isDark,
      child: Column(
        children: [
          Row(
            children: [
              _KboStatusChip(status: status),
              const Spacer(),
              Text(
                _kboStatusLabel(status) == 'Final' ? 'Final' : 'KBO',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            [
              _kboDetailDateLabel(date),
              _shortTimeLabel(time),
            ].where((e) => e.isNotEmpty).join(' '),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: muted,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _KboTeamHero(
                  name: home,
                  color: const Color(0xFF3B82F6),
                  align: CrossAxisAlignment.start,
                  textAlign: TextAlign.left,
                  text: text,
                ),
              ),
              Container(
                width: 128,
                height: 82,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white10 : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: border),
                ),
                child: Text(
                  score,
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    color: text,
                  ),
                ),
              ),
              Expanded(
                child: _KboTeamHero(
                  name: away,
                  color: const Color(0xFFF97316),
                  align: CrossAxisAlignment.end,
                  textAlign: TextAlign.right,
                  text: text,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _KboTeamHero extends StatelessWidget {
  final String name;
  final Color color;
  final CrossAxisAlignment align;
  final TextAlign textAlign;
  final Color text;

  const _KboTeamHero({
    required this.name,
    required this.color,
    required this.align,
    required this.textAlign,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: align,
      children: [
        Container(
          width: 58,
          height: 58,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: Text(
            name.isEmpty ? '-' : name.substring(0, 1),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          name,
          maxLines: 2,
          textAlign: textAlign,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 18,
            height: 1.1,
            fontWeight: FontWeight.w900,
            color: text,
          ),
        ),
      ],
    );
  }
}

class _KboInningBreakdownCard extends StatelessWidget {
  final List<dynamic> innings;
  final String home;
  final String away;
  final int? homeScore;
  final int? awayScore;
  final Color text;
  final Color muted;
  final Color border;
  final bool isDark;

  const _KboInningBreakdownCard({
    required this.innings,
    required this.home,
    required this.away,
    required this.homeScore,
    required this.awayScore,
    required this.text,
    required this.muted,
    required this.border,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final inningRows = innings.map(_fixtureAsMap).toList();
    final regular = List.generate(9, (index) => '${index + 1}');
    final extras = inningRows.where((row) {
      final label = _fixtureText(row['label']);
      final parsed = int.tryParse(label);
      return parsed != null && parsed > 9;
    }).toList();
    final headers = [...regular, 'EX', 'R', 'H', 'E'];

    String valueFor(String label, String side) {
      if (label == 'EX') {
        final total = extras.fold<int>(0, (runningTotal, row) {
          return runningTotal + (_readNullableInt(row[side]) ?? 0);
        });
        return total == 0 ? '0' : '$total';
      }
      if (label == 'R') {
        return side == 'home' ? '${homeScore ?? '-'}' : '${awayScore ?? '-'}';
      }
      if (label == 'H' || label == 'E') return '-';
      final row = inningRows.firstWhere(
        (entry) => _fixtureText(entry['label']) == label,
        orElse: () => const <String, dynamic>{},
      );
      return _fixtureText(row[side], '0');
    }

    if (inningRows.isEmpty && homeScore == null && awayScore == null) {
      return _KboEmptyCard(
        text: text,
        muted: muted,
        border: border,
        isDark: isDark,
        message: '이닝별 기록이 아직 제공되지 않습니다.',
      );
    }

    return _KboDetailCard(
      border: border,
      isDark: isDark,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _KboInningRow(values: ['', ...headers], text: muted, bold: true),
            const SizedBox(height: 10),
            _KboInningRow(
              values: [
                home,
                ...headers.map((label) => valueFor(label, 'home')),
              ],
              text: text,
              bold: true,
            ),
            Divider(color: border),
            _KboInningRow(
              values: [
                away,
                ...headers.map((label) => valueFor(label, 'away')),
              ],
              text: text,
              bold: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _KboInningRow extends StatelessWidget {
  final List<String> values;
  final Color text;
  final bool bold;

  const _KboInningRow({
    required this.values,
    required this.text,
    required this.bold,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (int i = 0; i < values.length; i++)
          SizedBox(
            width: i == 0 ? 64 : 28,
            child: Text(
              values[i],
              textAlign: i == 0 ? TextAlign.left : TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: i == 0 ? 13 : 12,
                fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
                color: text,
              ),
            ),
          ),
      ],
    );
  }
}

class _KboPitchingCard extends StatelessWidget {
  final Map<String, dynamic> pitching;
  final List<dynamic> lineups;
  final String home;
  final String away;
  final int? homeScore;
  final int? awayScore;
  final Color text;
  final Color muted;
  final Color border;
  final bool isDark;

  const _KboPitchingCard({
    required this.pitching,
    required this.lineups,
    required this.home,
    required this.away,
    required this.homeScore,
    required this.awayScore,
    required this.text,
    required this.muted,
    required this.border,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final homePitching = _fixtureAsMap(pitching['home']);
    final awayPitching = _fixtureAsMap(pitching['away']);
    final homeLineup = _kboLineupForTeam(lineups, home);
    final awayLineup = _kboLineupForTeam(lineups, away);
    final homeName = _fixtureText(
      homePitching['name'],
      _fixtureText(homeLineup['starterPitcher'], '-'),
    );
    final awayName = _fixtureText(
      awayPitching['name'],
      _fixtureText(awayLineup['starterPitcher'], '-'),
    );
    final homeSaveName = _fixtureText(homePitching['saveName']);
    final awaySaveName = _fixtureText(awayPitching['saveName']);
    final homeResult = _pitchingResult(
      explicit: _fixtureText(homePitching['result']),
      isHome: true,
    );
    final awayResult = _pitchingResult(
      explicit: _fixtureText(awayPitching['result']),
      isHome: false,
    );

    return _KboDetailCard(
      border: border,
      isDark: isDark,
      child: Row(
        children: [
          Expanded(
            child: _KboPitcherSide(
              team: home,
              pitcher: homeName,
              result: homeResult,
              savePitcher: homeSaveName,
              alignRight: false,
              text: text,
              muted: muted,
            ),
          ),
          Container(width: 1, height: 58, color: border),
          Expanded(
            child: _KboPitcherSide(
              team: away,
              pitcher: awayName,
              result: awayResult,
              savePitcher: awaySaveName,
              alignRight: true,
              text: text,
              muted: muted,
            ),
          ),
        ],
      ),
    );
  }

  String _pitchingResult({required String explicit, required bool isHome}) {
    if (explicit.contains('승') || explicit.toLowerCase().contains('win')) {
      return '승';
    }
    if (explicit.contains('패') || explicit.toLowerCase().contains('loss')) {
      return '패';
    }
    if (homeScore == null || awayScore == null || homeScore == awayScore) {
      return '';
    }
    final won = isHome ? homeScore! > awayScore! : awayScore! > homeScore!;
    return won ? '승' : '패';
  }
}

class _KboPitcherSide extends StatelessWidget {
  final String team;
  final String pitcher;
  final String result;
  final String savePitcher;
  final bool alignRight;
  final Color text;
  final Color muted;

  const _KboPitcherSide({
    required this.team,
    required this.pitcher,
    required this.result,
    required this.savePitcher,
    required this.alignRight,
    required this.text,
    required this.muted,
  });

  @override
  Widget build(BuildContext context) {
    final saveVisible = savePitcher.isNotEmpty && savePitcher != pitcher;
    return Column(
      crossAxisAlignment: alignRight
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          team,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            color: muted,
          ),
        ),
        const SizedBox(height: 18),
        _KboPitcherRow(
          pitcher: pitcher,
          result: result,
          alignRight: alignRight,
          text: text,
        ),
        if (saveVisible) ...[
          const SizedBox(height: 8),
          _KboPitcherRow(
            pitcher: savePitcher,
            result: '세',
            alignRight: alignRight,
            text: text,
          ),
        ],
      ],
    );
  }
}

class _KboPitcherRow extends StatelessWidget {
  final String pitcher;
  final String result;
  final bool alignRight;
  final Color text;

  const _KboPitcherRow({
    required this.pitcher,
    required this.result,
    required this.alignRight,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final children = [
      if (result.isNotEmpty) _KboDecisionBadge(result: result),
      if (result.isNotEmpty) const SizedBox(width: 8),
      Flexible(
        child: Text(
          pitcher,
          maxLines: 1,
          textAlign: alignRight ? TextAlign.right : TextAlign.left,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            color: text,
          ),
        ),
      ),
    ];

    return Row(
      mainAxisAlignment: alignRight
          ? MainAxisAlignment.end
          : MainAxisAlignment.start,
      children: alignRight ? children.reversed.toList() : children,
    );
  }
}

class _KboStartingLineupsCard extends StatelessWidget {
  final List<dynamic> lineups;
  final String home;
  final String away;
  final Color text;
  final Color muted;
  final Color border;
  final bool isDark;

  const _KboStartingLineupsCard({
    required this.lineups,
    required this.home,
    required this.away,
    required this.text,
    required this.muted,
    required this.border,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final homeLineup = _kboLineupForTeam(lineups, home);
    final awayLineup = _kboLineupForTeam(lineups, away);
    final hasLineups =
        _fixtureAsList(homeLineup['players']).isNotEmpty ||
        _fixtureAsList(awayLineup['players']).isNotEmpty ||
        _fixtureText(homeLineup['starterPitcher']).isNotEmpty ||
        _fixtureText(awayLineup['starterPitcher']).isNotEmpty;

    if (!hasLineups) {
      return _KboEmptyCard(
        text: text,
        muted: muted,
        border: border,
        isDark: isDark,
        message: '선발 라인업이 아직 제공되지 않습니다.',
      );
    }

    return _KboDetailCard(
      border: border,
      isDark: isDark,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _KboLineupColumn(
                lineup: homeLineup,
                fallbackTeam: home,
                text: text,
                muted: muted,
                border: border,
              ),
            ),
            Container(width: 1, color: border),
            Expanded(
              child: _KboLineupColumn(
                lineup: awayLineup,
                fallbackTeam: away,
                text: text,
                muted: muted,
                border: border,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KboLineupColumn extends StatelessWidget {
  final Map<String, dynamic> lineup;
  final String fallbackTeam;
  final Color text;
  final Color muted;
  final Color border;

  const _KboLineupColumn({
    required this.lineup,
    required this.fallbackTeam,
    required this.text,
    required this.muted,
    required this.border,
  });

  @override
  Widget build(BuildContext context) {
    final team = _fixtureText(lineup['team'], fallbackTeam);
    final starterPitcher = _fixtureText(lineup['starterPitcher']);
    final allPlayers = _fixtureAsList(lineup['players']).map(_fixtureAsMap);
    final source = _fixtureText(lineup['source']);
    final isProjected = source == 'projected';
    final players = isProjected
        ? const Iterable<Map<String, dynamic>>.empty()
        : allPlayers;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            team,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: text,
            ),
          ),
          if (isProjected) ...[
            const SizedBox(height: 6),
            Text(
              '공식 타순 미제공 · 로스터 기준 선발명단',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: muted,
              ),
            ),
          ],
          Divider(height: 22, color: border),
          if (starterPitcher.isNotEmpty) ...[
            _KboStarterPitcherRow(
              name: starterPitcher,
              text: text,
              muted: muted,
              border: border,
            ),
            Divider(height: 22, color: border),
          ],
          for (final player in players) ...[
            Text(
              _kboLineupPlayerLabel(player),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: text,
              ),
            ),
            Divider(height: 22, color: border),
          ],
          if (players.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 8),
              child: Text(
                starterPitcher.isEmpty
                    ? '선발 정보 준비 중'
                    : isProjected
                    ? '공식 선발명단이 아직 제공되지 않습니다.'
                    : '타순 정보는 아직 제공되지 않습니다.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  fontWeight: FontWeight.w700,
                  color: muted,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _KboStarterPitcherRow extends StatelessWidget {
  final String name;
  final Color text;
  final Color muted;
  final Color border;

  const _KboStarterPitcherRow({
    required this.name,
    required this.text,
    required this.muted,
    required this.border,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: border.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '선발투수',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: muted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: text,
            ),
          ),
        ],
      ),
    );
  }
}

class _KboGameInfoCard extends StatelessWidget {
  final String venue;
  final String city;
  final Color text;
  final Color muted;
  final Color border;
  final bool isDark;

  const _KboGameInfoCard({
    required this.venue,
    required this.city,
    required this.text,
    required this.muted,
    required this.border,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return _KboDetailCard(
      border: border,
      isDark: isDark,
      child: Column(
        children: [
          _KboInfoRow(label: '경기장', value: venue, text: text, muted: muted),
          if (city.isNotEmpty) ...[
            const SizedBox(height: 14),
            _KboInfoRow(label: '도시', value: city, text: text, muted: muted),
          ],
        ],
      ),
    );
  }
}

class _KboInfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color text;
  final Color muted;

  const _KboInfoRow({
    required this.label,
    required this.value,
    required this.text,
    required this.muted,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: muted,
          ),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: text,
            ),
          ),
        ),
      ],
    );
  }
}

class _KboDetailCard extends StatelessWidget {
  final Widget child;
  final Color border;
  final bool isDark;

  const _KboDetailCard({
    required this.child,
    required this.border,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: border),
        boxShadow: isDark
            ? const []
            : const [
                BoxShadow(
                  color: Color(0x10000000),
                  blurRadius: 18,
                  offset: Offset(0, 8),
                ),
              ],
      ),
      child: child,
    );
  }
}

class _KboEmptyCard extends StatelessWidget {
  final String message;
  final Color text;
  final Color muted;
  final Color border;
  final bool isDark;

  const _KboEmptyCard({
    required this.message,
    required this.text,
    required this.muted,
    required this.border,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return _KboDetailCard(
      border: border,
      isDark: isDark,
      child: Text(
        message,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          color: muted,
        ),
      ),
    );
  }
}

class _KboSectionTitle extends StatelessWidget {
  final String title;
  final Color color;

  const _KboSectionTitle(this.title, {required this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: color),
    );
  }
}

class _KboStatusChip extends StatelessWidget {
  final String status;

  const _KboStatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final isLive = _isKboLiveStatus(status);
    final background = isLive
        ? const Color(0xFFE8F7EC)
        : const Color(0xFF0F172A);
    final textColor = isLive ? const Color(0xFF16A34A) : Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _kboStatusLabel(status),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          color: textColor,
        ),
      ),
    );
  }
}

class _KboDecisionBadge extends StatelessWidget {
  final String result;

  const _KboDecisionBadge({required this.result});

  @override
  Widget build(BuildContext context) {
    final won = result == '승';
    final save = result == '세';
    final color = won || save
        ? const Color(0xFF3B82F6)
        : const Color(0xFFFF5A5F);
    return Container(
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        result,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          color: color,
        ),
      ),
    );
  }
}

String _kboDetailDateLabel(String value) {
  final parts = value.split('-');
  if (parts.length == 3) {
    return '${parts[1]}/${parts[2]}';
  }
  return _homeScheduleDateLabel(value);
}

String _kboResolvedDate(Map<String, dynamic> match, _KboMatch fallback) {
  final rawDate = _fixtureText(match['date'], fallback.date);
  final rawDateUtc = _fixtureText(match['dateUtc'], fallback.dateUtc);
  final rawTimeUtc = _fixtureText(match['timeUtc'], fallback.timeUtc);
  return _kboDisplayDateKey(rawDate, rawDateUtc, rawTimeUtc);
}

String _kboResolvedTime(Map<String, dynamic> match, _KboMatch fallback) {
  final rawTime = _fixtureText(match['time'], fallback.time);
  final rawDateUtc = _fixtureText(match['dateUtc'], fallback.dateUtc);
  final rawTimeUtc = _fixtureText(match['timeUtc'], fallback.timeUtc);
  return _kboDisplayTimeValue(rawTime, rawDateUtc, rawTimeUtc);
}

Map<String, dynamic> _kboLineupForTeam(List<dynamic> lineups, String team) {
  final normalized = team.trim();
  for (final raw in lineups) {
    final lineup = _fixtureAsMap(raw);
    if (_fixtureText(lineup['team']) == normalized) return lineup;
  }
  return const {};
}

String _kboLineupPlayerLabel(Map<String, dynamic> player) {
  final order = _fixtureText(player['order']);
  final name = _fixtureText(player['name'], '-');
  final position = _fixtureText(player['position']);
  final orderPrefix = order.isEmpty ? '' : '$order ';
  final positionSuffix = position.isEmpty ? '' : ' · $position';
  return '$orderPrefix$name$positionSuffix';
}

class _KLeagueFixture {
  final int id;
  final String home;
  final String away;
  final DateTime date;
  final String statusShort;
  final String statusLong;
  final String minuteLabel;
  final String venue;
  final String round;
  final int? homeGoals;
  final int? awayGoals;

  const _KLeagueFixture({
    required this.id,
    required this.home,
    required this.away,
    required this.date,
    required this.statusShort,
    required this.statusLong,
    required this.minuteLabel,
    required this.venue,
    required this.round,
    required this.homeGoals,
    required this.awayGoals,
  });

  bool get hasScore => homeGoals != null && awayGoals != null;
}

class _FixtureRoundPill extends StatelessWidget {
  final String label;
  final bool selected;
  final Color text;
  final Color muted;
  final Color border;
  final VoidCallback onTap;

  const _FixtureRoundPill({
    required this.label,
    required this.selected,
    required this.text,
    required this.muted,
    required this.border,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color bg = selected
        ? Colors.black87
        : (Theme.of(context).brightness == Brightness.dark
              ? Colors.white10
              : const Color(0xFFF6F7F9));
    final Color fg = selected ? Colors.white : text;

    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: selected ? Colors.black87 : border),
          boxShadow: selected
              ? const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ]
              : const [],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            color: fg,
          ),
        ),
      ),
    );
  }
}

class _ApiFixtureCard extends StatelessWidget {
  final _KLeagueFixture fixture;
  final String homeRecord;
  final String awayRecord;
  final Color text;
  final Color muted;
  final Color border;
  final Color surface;
  final VoidCallback? onTap;

  const _ApiFixtureCard({
    required this.fixture,
    required this.homeRecord,
    required this.awayRecord,
    required this.text,
    required this.muted,
    required this.border,
    required this.surface,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dateLabel = _fixtureDateTimeLabel(fixture.date);
    final statusLabel = _fixtureStatusLabel(fixture);
    final isLive = _isKLeagueLiveStatus(fixture.statusShort);
    final topMetaLabel = isLive && fixture.minuteLabel.isNotEmpty
        ? fixture.minuteLabel
        : dateLabel;

    Widget team(String name, String record, TextAlign align) {
      return Expanded(
        child: Column(
          crossAxisAlignment: align == TextAlign.right
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Text(
              name,
              textAlign: align,
              maxLines: 2,
              overflow: TextOverflow.clip,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                height: 1.05,
                color: text,
              ),
            ),
            if (record.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                record,
                textAlign: align,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: muted,
                ),
              ),
            ],
          ],
        ),
      );
    }

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(22, 18, 18, 18),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: border),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 10,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isLive
                        ? const Color(0xFFE8F7EC)
                        : const Color(0xFFE9EDF2),
                    borderRadius: BorderRadius.circular(18),
                    border: isLive
                        ? Border.all(color: const Color(0xFFB7E4C7))
                        : null,
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                      color: isLive
                          ? const Color(0xFF16A34A)
                          : const Color(0xFF5C6470),
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  topMetaLabel,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: muted,
                  ),
                ),
                const SizedBox(width: 10),
                Icon(Icons.chevron_right, color: muted, size: 24),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                team(fixture.home, homeRecord, TextAlign.left),
                Container(
                  width: 104,
                  height: 68,
                  alignment: Alignment.center,
                  margin: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white10
                        : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: border),
                  ),
                  child: Text(
                    fixture.hasScore
                        ? '${fixture.homeGoals} : ${fixture.awayGoals}'
                        : '-:-',
                    style: TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w900,
                      color: text,
                    ),
                  ),
                ),
                team(fixture.away, awayRecord, TextAlign.right),
              ],
            ),
            if (fixture.venue.isNotEmpty || fixture.round.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                [
                  fixture.round,
                  fixture.venue,
                ].where((e) => e.isNotEmpty).join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
    );
  }
}

class _KLeagueFixtureDetailPage extends StatefulWidget {
  final _KLeagueFixture fixture;

  const _KLeagueFixtureDetailPage({required this.fixture});

  @override
  State<_KLeagueFixtureDetailPage> createState() =>
      _KLeagueFixtureDetailPageState();
}

class _KLeagueFixtureDetailPageState extends State<_KLeagueFixtureDetailPage> {
  bool _isMyPageOpen = false;
  Map<String, dynamic>? _data;
  Object? _error;
  bool _isInitialLoading = true;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadFixtureDetails(showLoading: true);
    _refreshTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (!mounted) return;
      _loadFixtureDetails();
    });
  }

  Future<void> _loadFixtureDetails({bool showLoading = false}) async {
    if (showLoading) {
      setState(() {
        _isInitialLoading = true;
        _error = null;
      });
    }
    try {
      final data = await ApiService.fetchFixtureDetails(widget.fixture.id);
      if (!mounted) return;
      setState(() {
        _data = data;
        _error = null;
        _isInitialLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _isInitialLoading = false;
      });
    }
  }

  void _toggleMyPage() => setState(() => _isMyPageOpen = !_isMyPageOpen);

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final Color text = isDark ? Colors.white : Colors.black87;
    final Color muted = isDark ? Colors.white70 : Colors.black54;
    final Color border = isDark ? Colors.white12 : Colors.black12;
    final Color surface = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final Color subtle = isDark ? Colors.white10 : const Color(0xFFF8FAFC);

    Widget sectionCard(String title, Widget child) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 16),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: border),
          boxShadow: isDark
              ? const []
              : const [
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 18,
                    offset: Offset(0, 10),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: text,
              ),
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      );
    }

    Widget emptyState(String message) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: subtle,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border),
        ),
        child: Text(
          message,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: muted,
          ),
        ),
      );
    }

    Widget infoRow(String label, String value) {
      if (value.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 92,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: muted,
                ),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 13,
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
      title: '경기 상세',
      showSearch: false,
      child: Builder(
        builder: (context) {
          if (_isInitialLoading && _data == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (_error != null && _data == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: _comingSoonCard(
                  '경기 상세 정보를 불러오지 못했습니다.',
                  subtitle: '$_error',
                ),
              ),
            );
          }

          final data = _data ?? const <String, dynamic>{};
          final fixtureData = _fixtureAsMap(data['fixture']);
          final fixture = _fixtureAsMap(fixtureData['fixture']);
          final league = _fixtureAsMap(fixtureData['league']);
          final teams = _fixtureAsMap(fixtureData['teams']);
          final goals = _fixtureAsMap(fixtureData['goals']);
          final score = _fixtureAsMap(fixtureData['score']);
          final status = _fixtureAsMap(fixture['status']);
          final venue = _fixtureAsMap(fixture['venue']);
          final home = _fixtureAsMap(teams['home']);
          final away = _fixtureAsMap(teams['away']);
          final events = _fixtureAsList(data['events']);
          final lineups = _fixtureAsList(data['lineups']);
          final eventPlayerNames = _eventPlayerNameMap(lineups);

          final homeName = _kLeagueDisplayTeamName(
            _fixtureText(home['name'], widget.fixture.home),
          );
          final awayName = _kLeagueDisplayTeamName(
            _fixtureText(away['name'], widget.fixture.away),
          );
          final homeId = _readNullableInt(home['id']);
          final awayId = _readNullableInt(away['id']);
          final homeGoals =
              _readNullableInt(goals['home']) ?? widget.fixture.homeGoals;
          final awayGoals =
              _readNullableInt(goals['away']) ?? widget.fixture.awayGoals;
          final scoreLabel = homeGoals != null && awayGoals != null
              ? '$homeGoals : $awayGoals'
              : '-:-';
          final date = DateTime.tryParse(
            _fixtureText(
              fixture['date'],
              widget.fixture.date.toIso8601String(),
            ),
          );
          final dateLabel = date == null ? '' : _fixtureDateTimeLabel(date);
          final statusLabel = _fixtureText(
            status['long'],
            _fixtureStatusLabel(widget.fixture),
          );
          final minuteLabel = _fixtureMinuteLabel(
            _fixtureText(status['elapsed']),
            _fixtureText(status['extra']),
          );
          final scorers = _goalScorerRows(
            events,
            homeId,
            awayId,
            eventPlayerNames,
          );

          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    children: [
                      _FixtureScoreHero(
                        homeName: homeName,
                        awayName: awayName,
                        scoreLabel: scoreLabel,
                        statusLabel: _fixtureDetailStatusLabel(
                          _fixtureText(
                            status['short'],
                            widget.fixture.statusShort,
                          ),
                          statusLabel,
                        ),
                        roundLabel: _fixtureText(
                          league['round'],
                          widget.fixture.round,
                        ),
                        dateLabel: dateLabel,
                        minuteLabel: minuteLabel,
                        scorers: scorers,
                        text: text,
                        muted: muted,
                        border: border,
                        surface: surface,
                      ),
                      const SizedBox(height: 16),
                      lineups.isEmpty
                          ? sectionCard(
                              '스타팅 라인업',
                              emptyState('라인업은 경기 20-40분 전 또는 경기 후 제공됩니다.'),
                            )
                          : _FixturePitchLineupCard(
                              lineups: lineups,
                              homeTeamId: homeId,
                              awayTeamId: awayId,
                              events: events,
                              text: text,
                              muted: muted,
                              border: border,
                            ),
                      if (lineups.isNotEmpty)
                        _FixtureBenchCard(
                          lineups: lineups,
                          homeTeamId: homeId,
                          awayTeamId: awayId,
                          events: events,
                          text: text,
                          muted: muted,
                          border: border,
                          surface: surface,
                        ),
                      sectionCard(
                        '이벤트',
                        events.isEmpty
                            ? emptyState('아직 골, 카드, 교체 이벤트가 없습니다.')
                            : _FixtureTimelineView(
                                events: events,
                                text: text,
                                muted: muted,
                                border: border,
                                homeTeamId: homeId,
                                playerNames: eventPlayerNames,
                              ),
                      ),
                      sectionCard(
                        '경기 정보',
                        Column(
                          children: [
                            infoRow(
                              '경기장',
                              [
                                _fixtureText(
                                  venue['name'],
                                  widget.fixture.venue,
                                ),
                                _fixtureText(venue['city']),
                              ].where((e) => e.isNotEmpty).join(' · '),
                            ),
                            infoRow('심판', _fixtureText(fixture['referee'])),
                            infoRow(
                              '상태',
                              [
                                statusLabel,
                                if (minuteLabel.isNotEmpty) minuteLabel,
                              ].where((e) => e.isNotEmpty).join(' · '),
                            ),
                            infoRow(
                              '하프타임',
                              _scorePartLabel(score, ['halftime']),
                            ),
                            infoRow(
                              '풀타임',
                              _scorePartLabel(score, ['fulltime']),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _FixtureScoreHero extends StatelessWidget {
  final String homeName;
  final String awayName;
  final String scoreLabel;
  final String statusLabel;
  final String roundLabel;
  final String dateLabel;
  final String minuteLabel;
  final List<_GoalScorerRow> scorers;
  final Color text;
  final Color muted;
  final Color border;
  final Color surface;

  const _FixtureScoreHero({
    required this.homeName,
    required this.awayName,
    required this.scoreLabel,
    required this.statusLabel,
    required this.roundLabel,
    required this.dateLabel,
    required this.minuteLabel,
    required this.scorers,
    required this.text,
    required this.muted,
    required this.border,
    required this.surface,
  });

  @override
  Widget build(BuildContext context) {
    final isLive = statusLabel.toUpperCase() == 'LIVE';
    final metaLabel = isLive && minuteLabel.isNotEmpty
        ? '$dateLabel · $minuteLabel'
        : dateLabel;
    Widget team(String name, TextAlign align, Color accent) {
      final initial = name.isEmpty ? '?' : name.characters.first;
      return Expanded(
        child: Column(
          crossAxisAlignment: align == TextAlign.right
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: accent.withValues(alpha: 0.35)),
              ),
              child: Text(
                initial,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: accent,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              name,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              textAlign: align,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                height: 1.08,
                color: text,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x16000000),
            blurRadius: 22,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isLive
                      ? const Color(0xFFE8F7EC)
                      : const Color(0xFF111827),
                  borderRadius: BorderRadius.circular(999),
                  border: isLive
                      ? Border.all(color: const Color(0xFFB7E4C7))
                      : null,
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: isLive ? const Color(0xFF16A34A) : Colors.white,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                _roundTitleLabel(roundLabel),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            metaLabel,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: muted,
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              team(homeName, TextAlign.left, const Color(0xFF2563EB)),
              Container(
                width: 110,
                height: 74,
                alignment: Alignment.center,
                margin: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: border),
                ),
                child: Text(
                  scoreLabel,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: text,
                  ),
                ),
              ),
              team(awayName, TextAlign.right, const Color(0xFFF97316)),
            ],
          ),
          if (scorers.isNotEmpty) ...[
            const SizedBox(height: 18),
            Divider(color: border, height: 1),
            const SizedBox(height: 12),
            _ScoreScorersView(scorers: scorers, text: text, border: border),
          ],
        ],
      ),
    );
  }
}

class _ScoreScorersView extends StatelessWidget {
  final List<_GoalScorerRow> scorers;
  final Color text;
  final Color border;

  const _ScoreScorersView({
    required this.scorers,
    required this.text,
    required this.border,
  });

  @override
  Widget build(BuildContext context) {
    final homeScorers = scorers.where((scorer) => scorer.isHome).toList();
    final awayScorers = scorers.where((scorer) => !scorer.isHome).toList();
    final rowCount = max(homeScorers.length, awayScorers.length);

    return Column(
      children: [
        for (int i = 0; i < rowCount; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    i < homeScorers.length ? _scorerLabel(homeScorers[i]) : '',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: text,
                    ),
                  ),
                ),
                Container(
                  width: 1,
                  height: 18,
                  margin: const EdgeInsets.symmetric(horizontal: 14),
                  color: border,
                ),
                Expanded(
                  child: Text(
                    i < awayScorers.length ? _scorerLabel(awayScorers[i]) : '',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: text,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  String _scorerLabel(_GoalScorerRow scorer) {
    return "${scorer.minute}' ${scorer.name}${scorer.detail.isEmpty ? '' : ' (${scorer.detail})'}";
  }
}

class _FixturePitchLineupCard extends StatelessWidget {
  final List<dynamic> lineups;
  final int? homeTeamId;
  final int? awayTeamId;
  final List<dynamic> events;
  final Color text;
  final Color muted;
  final Color border;

  const _FixturePitchLineupCard({
    required this.lineups,
    required this.homeTeamId,
    required this.awayTeamId,
    required this.events,
    required this.text,
    required this.muted,
    required this.border,
  });

  @override
  Widget build(BuildContext context) {
    final home =
        _lineupForTeam(lineups, homeTeamId) ?? _fixtureAsMap(lineups.first);
    final away =
        _lineupForTeam(lineups, awayTeamId) ??
        (lineups.length > 1 ? _fixtureAsMap(lineups[1]) : const {});

    return Container(
      width: double.infinity,
      height: 720,
      decoration: BoxDecoration(
        color: const Color(0xFF0B6634),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0x22000000)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x18000000),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _FootballPitchPainter())),
          _LineupTeamLabel(lineup: home, alignment: Alignment.topLeft),
          _LineupTeamLabel(lineup: away, alignment: Alignment.bottomRight),
          ..._pitchPlayerWidgets(home, true),
          ..._pitchPlayerWidgets(away, false),
        ],
      ),
    );
  }

  List<Widget> _pitchPlayerWidgets(Map<String, dynamic> lineup, bool isHome) {
    final formation = _supportedFormation(_fixtureText(lineup['formation']));
    final players = _lineupPlayersForFormation(lineup, formation);
    final badgesByName = _eventBadgesByPlayer(events);
    final widgets = <Widget>[];
    const widthPadding = 2.0;
    const playerMarkerWidth = 62.0;
    final yValues = isHome
        ? <double>[0.06, 0.20, 0.32, 0.43]
        : <double>[0.94, 0.80, 0.68, 0.57];

    for (int lineIndex = 0; lineIndex < players.length; lineIndex++) {
      final line = players[lineIndex];
      if (line.isEmpty) continue;
      for (int i = 0; i < line.length; i++) {
        final player = line[i];
        final baseFraction = line.length == 1
            ? 0.5
            : (i + 1) / (line.length + 1);
        final spread = switch (line.length) {
          2 => 1.10,
          3 => 1.12,
          4 => 1.13,
          5 => 1.08,
          _ => 1.0,
        };
        final fraction = (0.5 + (baseFraction - 0.5) * spread)
            .clamp(0.12, 0.88)
            .toDouble();
        widgets.add(
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final x =
                    widthPadding +
                    (constraints.maxWidth - widthPadding * 2) * fraction -
                    playerMarkerWidth / 2;
                final y = constraints.maxHeight * yValues[lineIndex] - 29;
                return Stack(
                  children: [
                    Positioned(
                      left: x,
                      top: y,
                      width: playerMarkerWidth,
                      child: _PitchPlayerMarker(
                        player: player,
                        isHome: isHome,
                        badges: _badgesForLineupPlayer(badgesByName, player),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      }
    }

    return widgets;
  }
}

class _LineupTeamLabel extends StatelessWidget {
  final Map<String, dynamic> lineup;
  final Alignment alignment;

  const _LineupTeamLabel({required this.lineup, required this.alignment});

  @override
  Widget build(BuildContext context) {
    final team = _fixtureAsMap(lineup['team']);
    final name = _kLeagueDisplayTeamName(_fixtureText(team['name'], 'Team'));
    final formation = _supportedFormation(
      _fixtureText(lineup['formation']),
    ).label;

    return Align(
      alignment: alignment,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Text(
          '$name\n$formation',
          textAlign: alignment == Alignment.bottomRight
              ? TextAlign.right
              : TextAlign.left,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w900,
            height: 1.18,
          ),
        ),
      ),
    );
  }
}

class _PitchPlayerMarker extends StatelessWidget {
  final _LineupPlayer player;
  final bool isHome;
  final List<_EventBadge> badges;

  const _PitchPlayerMarker({
    required this.player,
    required this.isHome,
    required this.badges,
  });

  @override
  Widget build(BuildContext context) {
    final color = isHome ? const Color(0xFF3B82F6) : const Color(0xFFFF5B5B);
    final scoringBadges = badges
        .where(
          (badge) =>
              badge.kind == _EventBadgeKind.goal ||
              badge.kind == _EventBadgeKind.assist,
        )
        .toList();
    final substitutionBadge = badges
        .where((badge) => badge.kind == _EventBadgeKind.substitution)
        .take(1)
        .toList();
    final cardBadges = badges
        .where(
          (badge) =>
              badge.kind == _EventBadgeKind.yellowCard ||
              badge.kind == _EventBadgeKind.redCard,
        )
        .toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFF126B38),
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 2),
              ),
              child: Text(
                player.number,
                style: TextStyle(
                  color: color,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            for (int i = 0; i < scoringBadges.take(3).length; i++)
              Positioned(
                right: -7 - (i * 10),
                top: -6,
                child: _SmallEventBadge(badge: scoringBadges[i]),
              ),
            for (int i = 0; i < substitutionBadge.length; i++)
              Positioned(
                right: -7,
                bottom: -4,
                child: _SmallEventBadge(badge: substitutionBadge[i]),
              ),
            for (int i = 0; i < cardBadges.take(2).length; i++)
              Positioned(
                left: -5 + (i * 8),
                top: -5,
                child: _SmallEventBadge(badge: cardBadges[i]),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          player.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 9,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _SmallEventBadge extends StatelessWidget {
  final _EventBadge badge;

  const _SmallEventBadge({required this.badge});

  @override
  Widget build(BuildContext context) {
    if (badge.kind == _EventBadgeKind.yellowCard) {
      return Container(
        width: 10,
        height: 14,
        decoration: BoxDecoration(
          color: const Color(0xFFFACC15),
          borderRadius: BorderRadius.circular(2),
        ),
      );
    }
    if (badge.kind == _EventBadgeKind.redCard) {
      return Container(
        width: 10,
        height: 14,
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444),
          borderRadius: BorderRadius.circular(2),
        ),
      );
    }
    if (badge.kind == _EventBadgeKind.assist) {
      return Container(
        width: 18,
        height: 18,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
        child: const Text(
          'A',
          style: TextStyle(
            color: Color(0xFFDC2626),
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
      );
    }

    return Container(
      width: 18,
      height: 18,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      child: Icon(
        badge.kind == _EventBadgeKind.goal
            ? Icons.sports_soccer
            : Icons.swap_horiz,
        size: 12,
        color: badge.kind == _EventBadgeKind.goal
            ? const Color(0xFF111827)
            : const Color(0xFF2563EB),
      ),
    );
  }
}

class _FixtureBenchCard extends StatelessWidget {
  final List<dynamic> lineups;
  final int? homeTeamId;
  final int? awayTeamId;
  final List<dynamic> events;
  final Color text;
  final Color muted;
  final Color border;
  final Color surface;

  const _FixtureBenchCard({
    required this.lineups,
    required this.homeTeamId,
    required this.awayTeamId,
    required this.events,
    required this.text,
    required this.muted,
    required this.border,
    required this.surface,
  });

  @override
  Widget build(BuildContext context) {
    final home =
        _lineupForTeam(lineups, homeTeamId) ?? _fixtureAsMap(lineups.first);
    final away =
        _lineupForTeam(lineups, awayTeamId) ??
        (lineups.length > 1 ? _fixtureAsMap(lineups[1]) : const {});

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 0),
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(22)),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _benchColumn(home, false)),
          Container(
            width: 1,
            height: 360,
            margin: const EdgeInsets.symmetric(horizontal: 12),
            color: border,
          ),
          Expanded(child: _benchColumn(away, true)),
        ],
      ),
    );
  }

  Widget _benchColumn(Map<String, dynamic> lineup, bool alignRight) {
    final team = _fixtureAsMap(lineup['team']);
    final teamName = _kLeagueDisplayTeamName(
      _fixtureText(team['name'], 'Team'),
    );
    final substitutes = _fixtureAsList(lineup['substitutes'])
        .map((raw) => _lineupPlayerFromRaw(raw, lineup: lineup))
        .whereType<_LineupPlayer>()
        .toList();
    final badgesByName = _eventBadgesByPlayer(events);
    substitutes.sort((a, b) {
      final aSubbedIn = _badgesForLineupPlayer(
        badgesByName,
        a,
      ).any((badge) => badge.kind == _EventBadgeKind.substitution);
      final bSubbedIn = _badgesForLineupPlayer(
        badgesByName,
        b,
      ).any((badge) => badge.kind == _EventBadgeKind.substitution);
      if (aSubbedIn == bSubbedIn) return 0;
      return aSubbedIn ? -1 : 1;
    });

    return Column(
      crossAxisAlignment: alignRight
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          '$teamName 교체 명단',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: alignRight ? TextAlign.right : TextAlign.left,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            color: muted,
          ),
        ),
        const SizedBox(height: 12),
        for (int i = 0; i < substitutes.length; i++) ...[
          _benchPlayerRow(
            substitutes[i],
            alignRight,
            _badgesForLineupPlayer(badgesByName, substitutes[i]),
          ),
          if (i != substitutes.length - 1) Divider(height: 16, color: border),
        ],
      ],
    );
  }

  Widget _benchPlayerRow(
    _LineupPlayer player,
    bool alignRight,
    List<_EventBadge> badges,
  ) {
    final displayBadges = _orderedEventBadgesForDisplay(badges);
    final content = [
      Flexible(
        child: Text(
          '${player.number} ${player.name}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: alignRight ? TextAlign.right : TextAlign.left,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            color: text,
          ),
        ),
      ),
      if (badges.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(left: 5, right: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (int i = 0; i < displayBadges.take(4).length; i++) ...[
                if (i != 0) const SizedBox(width: 3),
                _SmallEventBadge(badge: displayBadges[i]),
              ],
            ],
          ),
        ),
    ];

    return Row(
      mainAxisAlignment: alignRight
          ? MainAxisAlignment.end
          : MainAxisAlignment.start,
      children: alignRight ? content.reversed.toList() : content,
    );
  }
}

class _FixtureTimelineView extends StatelessWidget {
  final List<dynamic> events;
  final Color text;
  final Color muted;
  final Color border;
  final int? homeTeamId;
  final Map<String, String> playerNames;

  const _FixtureTimelineView({
    required this.events,
    required this.text,
    required this.muted,
    required this.border,
    required this.homeTeamId,
    required this.playerNames,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: Align(
            alignment: Alignment.center,
            child: Container(width: 1, color: border),
          ),
        ),
        Column(
          children: [
            for (int i = 0; i < events.length; i++) ...[
              _eventRow(events[i]),
              if (i != events.length - 1) const SizedBox(height: 12),
            ],
          ],
        ),
      ],
    );
  }

  Widget _eventRow(dynamic raw) {
    final event = _fixtureAsMap(raw);
    final time = _fixtureAsMap(event['time']);
    final team = _fixtureAsMap(event['team']);
    final player = _fixtureAsMap(event['player']);
    final assist = _fixtureAsMap(event['assist']);
    final teamId = _readNullableInt(team['id']);
    final minute = _eventMinute(time);
    final badge =
        _eventBadgeFor(event) ?? const _EventBadge(_EventBadgeKind.other);
    final isHome = homeTeamId != null && teamId == homeTeamId;

    final playerName = _eventPlayerDisplayName(player, playerNames);
    final assistName = _eventPlayerDisplayName(assist, playerNames);
    final isSubstitution = badge.kind == _EventBadgeKind.substitution;
    final eventText = playerName;
    final isGoal = badge.kind == _EventBadgeKind.goal;
    final subText = isSubstitution
        ? assistName
        : (isGoal && assistName.isNotEmpty ? '도움: $assistName' : '');
    final playerBadge = _eventBadgeFor(event, includeOther: false);

    return Row(
      children: [
        Expanded(
          child: isHome
              ? _splitEventContent(
                  eventText,
                  subText,
                  TextAlign.right,
                  CrossAxisAlignment.end,
                  playerBadge,
                  isSubstitution,
                )
              : const SizedBox.shrink(),
        ),
        SizedBox(
          width: 44,
          child: Center(
            child: Text(
              minute.isEmpty ? '-' : "$minute'",
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: muted,
              ),
            ),
          ),
        ),
        Expanded(
          child: !isHome
              ? _splitEventContent(
                  eventText,
                  subText,
                  TextAlign.left,
                  CrossAxisAlignment.start,
                  playerBadge,
                  isSubstitution,
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _splitEventContent(
    String title,
    String subtitle,
    TextAlign align,
    CrossAxisAlignment crossAxisAlignment,
    _EventBadge? playerBadge,
    bool isSubstitution,
  ) {
    final alignRight = align == TextAlign.right;
    return Column(
      crossAxisAlignment: crossAxisAlignment,
      children: [
        Row(
          mainAxisAlignment: alignRight
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          children: [
            if (alignRight && playerBadge != null) ...[
              _SmallEventBadge(badge: playerBadge),
              const SizedBox(width: 5),
            ],
            if (alignRight && isSubstitution) ...[
              _eventDirectionTag('in', const Color(0xFF16A34A)),
              const SizedBox(width: 5),
            ],
            Flexible(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: align,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: text,
                ),
              ),
            ),
            if (!alignRight && isSubstitution) ...[
              const SizedBox(width: 5),
              _eventDirectionTag('in', const Color(0xFF16A34A)),
            ],
            if (!alignRight && playerBadge != null) ...[
              const SizedBox(width: 5),
              _SmallEventBadge(badge: playerBadge),
            ],
          ],
        ),
        if (subtitle.isNotEmpty) ...[
          const SizedBox(height: 3),
          Row(
            mainAxisAlignment: alignRight
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            children: [
              if (alignRight && isSubstitution) ...[
                _eventDirectionTag('out', const Color(0xFFDC2626)),
                const SizedBox(width: 5),
              ],
              Flexible(
                child: Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: align,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: muted,
                  ),
                ),
              ),
              if (!alignRight && isSubstitution) ...[
                const SizedBox(width: 5),
                _eventDirectionTag('out', const Color(0xFFDC2626)),
              ],
            ],
          ),
        ],
      ],
    );
  }

  Widget _eventDirectionTag(String label, Color color) {
    return Text(
      label,
      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: color),
    );
  }
}

class _FootballPitchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = Colors.white.withValues(alpha: 0.20)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final stripe = Paint()..color = Colors.black.withValues(alpha: 0.05);

    for (int i = 0; i < 8; i++) {
      if (i.isEven) {
        canvas.drawRect(
          Rect.fromLTWH(i * size.width / 8, 0, size.width / 8, size.height),
          stripe,
        );
      }
    }

    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      line,
    );
    canvas.drawCircle(Offset(size.width / 2, size.height / 2), 42, line);
    canvas.drawCircle(Offset(size.width / 2, size.height / 2), 3, line);

    final boxWidth = size.width * 0.78;
    final boxLeft = (size.width - boxWidth) / 2;
    canvas.drawRect(Rect.fromLTWH(boxLeft, 0, boxWidth, 92), line);
    canvas.drawRect(
      Rect.fromLTWH(boxLeft, size.height - 92, boxWidth, 92),
      line,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _GoalScorerRow {
  final bool isHome;
  final String minute;
  final String name;
  final String detail;

  const _GoalScorerRow({
    required this.isHome,
    required this.minute,
    required this.name,
    required this.detail,
  });
}

class _LineupPlayer {
  final String id;
  final String originalName;
  final String name;
  final String number;
  final String position;
  final int? gridLine;
  final int? gridColumn;

  const _LineupPlayer({
    required this.id,
    required this.originalName,
    required this.name,
    required this.number,
    required this.position,
    required this.gridLine,
    required this.gridColumn,
  });
}

class _SupportedFormation {
  final String label;
  final List<int> lines;

  const _SupportedFormation(this.label, this.lines);
}

enum _EventBadgeKind { goal, assist, substitution, yellowCard, redCard, other }

class _EventBadge {
  final _EventBadgeKind kind;

  const _EventBadge(this.kind);
}

const List<_SupportedFormation> _supportedFormations = [
  _SupportedFormation('4-5-1', [4, 5, 1]),
  _SupportedFormation('4-4-2', [4, 4, 2]),
  _SupportedFormation('4-3-3', [4, 3, 3]),
  _SupportedFormation('3-5-2', [3, 5, 2]),
  _SupportedFormation('3-4-3', [3, 4, 3]),
  _SupportedFormation('5-4-1', [5, 4, 1]),
  _SupportedFormation('5-3-2', [5, 3, 2]),
];

Map<String, dynamic>? _lineupForTeam(List<dynamic> lineups, int? teamId) {
  if (teamId == null) return null;
  for (final raw in lineups) {
    final lineup = _fixtureAsMap(raw);
    final team = _fixtureAsMap(lineup['team']);
    if (_readNullableInt(team['id']) == teamId) return lineup;
  }
  return null;
}

_SupportedFormation _supportedFormation(String rawFormation) {
  final parts = rawFormation
      .split('-')
      .map((part) => int.tryParse(part.trim()))
      .whereType<int>()
      .toList();

  if (parts.length == 3) {
    for (final formation in _supportedFormations) {
      if (_listEquals(formation.lines, parts)) return formation;
    }
  }

  final normalized = parts.length >= 3
      ? <int>[
          parts.first,
          parts.sublist(1, parts.length - 1).fold<int>(0, (a, b) => a + b),
          parts.last,
        ]
      : const <int>[4, 4, 2];

  return _supportedFormations.reduce((best, formation) {
    final currentScore = _formationDistance(formation.lines, normalized);
    final bestScore = _formationDistance(best.lines, normalized);
    return currentScore < bestScore ? formation : best;
  });
}

bool _listEquals(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

int _formationDistance(List<int> a, List<int> b) {
  var distance = 0;
  for (int i = 0; i < min(a.length, b.length); i++) {
    distance += (a[i] - b[i]).abs();
  }
  return distance;
}

List<List<_LineupPlayer>> _lineupPlayersForFormation(
  Map<String, dynamic> lineup,
  _SupportedFormation formation,
) {
  final rawPlayers = _fixtureAsList(lineup['startXI'])
      .map((raw) => _lineupPlayerFromRaw(raw, lineup: lineup))
      .whereType<_LineupPlayer>()
      .toList();

  final rows = List.generate(4, (_) => <_LineupPlayer>[]);
  final unassigned = <_LineupPlayer>[];

  for (final player in rawPlayers) {
    final rowIndex = _lineupRowIndex(player);
    if (rowIndex == null) {
      unassigned.add(player);
    } else {
      rows[rowIndex].add(player);
    }
  }

  for (final player in unassigned) {
    rows[_leastCrowdedOutfieldRow(rows)].add(player);
  }

  for (final row in rows) {
    row.sort((a, b) {
      final columnCompare = (a.gridColumn ?? 999).compareTo(
        b.gridColumn ?? 999,
      );
      if (columnCompare != 0) return columnCompare;
      return rawPlayers.indexOf(a).compareTo(rawPlayers.indexOf(b));
    });
  }

  return rows;
}

_LineupPlayer? _lineupPlayerFromRaw(
  dynamic raw, {
  required Map<String, dynamic> lineup,
}) {
  final wrapper = _fixtureAsMap(raw);
  final player = _fixtureAsMap(wrapper['player']);
  final name = _fixtureText(player['name']);
  if (name.isEmpty) return null;
  final team = _fixtureAsMap(lineup['team']);
  final teamName = _fixtureText(team['name']);
  final number = _fixtureText(player['number'], '-');
  final grid = _fixtureText(player['grid'] ?? wrapper['grid']);
  final gridLine = _parseGridPart(grid, 0);
  final gridColumn = _parseGridPart(grid, 1);
  final position = _normalizeLineupPosition(
    _fixtureText(player['pos'] ?? wrapper['pos']),
    gridLine: gridLine,
  );
  return _LineupPlayer(
    id: _fixtureText(player['id']),
    originalName: name,
    name: _kLeagueDisplayPlayerName(name, teamName: teamName, number: number),
    number: number,
    position: position,
    gridLine: gridLine,
    gridColumn: gridColumn,
  );
}

int? _lineupRowIndex(_LineupPlayer player) {
  return switch (player.position) {
    'G' => 0,
    'D' => 1,
    'M' => 2,
    'F' => 3,
    _ => _lineupRowIndexFromGrid(player.gridLine),
  };
}

int? _lineupRowIndexFromGrid(int? gridLine) {
  return switch (gridLine) {
    1 => 0,
    2 => 1,
    3 => 2,
    4 => 3,
    _ => null,
  };
}

int _leastCrowdedOutfieldRow(List<List<_LineupPlayer>> rows) {
  var bestIndex = 2;
  for (final index in const [1, 2, 3]) {
    if (rows[index].length < rows[bestIndex].length) bestIndex = index;
  }
  return bestIndex;
}

String _normalizeLineupPosition(String raw, {required int? gridLine}) {
  final value = raw.trim().toUpperCase();
  if (value == 'G' || value == 'GK' || value.contains('GOAL')) return 'G';
  if (value == 'D' || value == 'DF' || value.contains('DEF')) return 'D';
  if (value == 'M' || value == 'MF' || value.contains('MID')) return 'M';
  if (value == 'F' || value == 'FW' || value.contains('FOR')) return 'F';
  return switch (_lineupRowIndexFromGrid(gridLine)) {
    0 => 'G',
    1 => 'D',
    2 => 'M',
    3 => 'F',
    _ => '',
  };
}

int? _parseGridPart(String grid, int index) {
  final parts = grid.split(':');
  if (parts.length <= index) return null;
  return int.tryParse(parts[index].trim());
}

List<_GoalScorerRow> _goalScorerRows(
  List<dynamic> events,
  int? homeTeamId,
  int? awayTeamId,
  Map<String, String> playerNames,
) {
  return events
      .map(_fixtureAsMap)
      .where((event) => _fixtureText(event['type']) == 'Goal')
      .map((event) {
        final team = _fixtureAsMap(event['team']);
        final player = _fixtureAsMap(event['player']);
        final time = _fixtureAsMap(event['time']);
        final teamId = _readNullableInt(team['id']);
        return _GoalScorerRow(
          isHome: homeTeamId != null
              ? teamId == homeTeamId
              : teamId != awayTeamId,
          minute: _eventMinute(time),
          name: _eventPlayerDisplayName(player, playerNames, 'Unknown'),
          detail: _goalDetailLabel(_fixtureText(event['detail'])),
        );
      })
      .toList();
}

String _eventMinute(Map<String, dynamic> time) {
  final elapsed = _fixtureText(time['elapsed']);
  final extra = _fixtureText(time['extra']);
  if (elapsed.isEmpty) return '';
  return extra.isEmpty ? elapsed : '$elapsed+$extra';
}

String _goalDetailLabel(String detail) {
  return switch (detail) {
    'Penalty' => 'PK',
    'Own Goal' => 'OG',
    'Missed Penalty' => 'PK Miss',
    _ => '',
  };
}

Map<String, List<_EventBadge>> _eventBadgesByPlayer(List<dynamic> events) {
  final badges = <String, List<_EventBadge>>{};
  for (final raw in events) {
    final event = _fixtureAsMap(raw);
    final player = _fixtureAsMap(event['player']);
    final assist = _fixtureAsMap(event['assist']);
    void add(String key, _EventBadge badge) {
      if (key.isNotEmpty) {
        badges.putIfAbsent(key, () => []).add(badge);
      }
    }

    void addPlayer(Map<String, dynamic> target, _EventBadge badge) {
      add(_fixtureText(target['id']), badge);
      add(_fixtureText(target['name']), badge);
    }

    final badge = _eventBadgeFor(event);
    if (badge == null) continue;

    if (badge.kind == _EventBadgeKind.goal) {
      addPlayer(player, badge);
      if (_fixtureText(assist['name']).isNotEmpty) {
        addPlayer(assist, const _EventBadge(_EventBadgeKind.assist));
      }
    } else if (badge.kind == _EventBadgeKind.substitution) {
      addPlayer(player, badge);
      addPlayer(assist, badge);
    } else {
      addPlayer(player, badge);
    }
  }
  return badges;
}

Map<String, String> _eventPlayerNameMap(List<dynamic> lineups) {
  final names = <String, String>{};
  for (final rawLineup in lineups) {
    final lineup = _fixtureAsMap(rawLineup);
    for (final raw in [
      ..._fixtureAsList(lineup['startXI']),
      ..._fixtureAsList(lineup['substitutes']),
    ]) {
      final player = _lineupPlayerFromRaw(raw, lineup: lineup);
      if (player == null) continue;
      if (player.id.isNotEmpty) names[player.id] = player.name;
      names[player.originalName] = player.name;
    }
  }
  return names;
}

String _eventPlayerDisplayName(
  Map<String, dynamic> player,
  Map<String, String> playerNames, [
  String fallback = '',
]) {
  final id = _fixtureText(player['id']);
  final name = _fixtureText(player['name']);
  if (id.isNotEmpty && playerNames[id] != null) return playerNames[id]!;
  if (name.isNotEmpty && playerNames[name] != null) return playerNames[name]!;
  return name.isEmpty ? fallback : name;
}

String _kLeagueDisplayPlayerName(
  String value, {
  required String teamName,
  required String number,
}) {
  final trimmed = value.trim();
  final jersey = int.tryParse(number);
  if (jersey == null) return trimmed;

  final club = _canonicalKLeagueClub(_kLeagueDisplayTeamName(teamName));
  for (final entry in _docRosterEntries) {
    if (entry.meta.number != jersey) continue;
    if (_canonicalKLeagueClub(entry.meta.club) == club) return entry.name;
  }

  return trimmed;
}

String _canonicalKLeagueClub(String value) {
  return value
      .trim()
      .replaceAll('제주 유나이티드', '제주 SK')
      .replaceAll('전북 현대 모터스', '전북 현대')
      .replaceAll('부천FC', '부천 FC');
}

List<_EventBadge> _badgesForLineupPlayer(
  Map<String, List<_EventBadge>> badgesByPlayer,
  _LineupPlayer player,
) {
  if (player.id.isNotEmpty && badgesByPlayer[player.id] != null) {
    return badgesByPlayer[player.id]!;
  }
  if (badgesByPlayer[player.originalName] != null) {
    return badgesByPlayer[player.originalName]!;
  }
  return badgesByPlayer[player.name] ?? const [];
}

List<_EventBadge> _orderedEventBadgesForDisplay(List<_EventBadge> badges) {
  final output = [...badges];
  output.sort((a, b) {
    int priority(_EventBadge badge) {
      return switch (badge.kind) {
        _EventBadgeKind.substitution => 0,
        _EventBadgeKind.assist => 1,
        _EventBadgeKind.goal => 2,
        _EventBadgeKind.yellowCard => 3,
        _EventBadgeKind.redCard => 4,
        _EventBadgeKind.other => 5,
      };
    }

    return priority(a).compareTo(priority(b));
  });
  return output;
}

_EventBadge? _eventBadgeFor(
  Map<String, dynamic> event, {
  bool includeOther = true,
}) {
  final type = _fixtureText(event['type']);
  final detail = _fixtureText(event['detail']);
  if (type == 'Goal') return const _EventBadge(_EventBadgeKind.goal);
  if (type == 'subst' || type == 'Subst') {
    return const _EventBadge(_EventBadgeKind.substitution);
  }
  if (type == 'Card' && detail.contains('Red')) {
    return const _EventBadge(_EventBadgeKind.redCard);
  }
  if (type == 'Card' && detail.contains('Yellow')) {
    return const _EventBadge(_EventBadgeKind.yellowCard);
  }
  return includeOther ? const _EventBadge(_EventBadgeKind.other) : null;
}

List<_KLeagueFixture> _kLeagueFixturesFromApi(List<dynamic> fixtures) {
  final parsed = <_KLeagueFixture>[];
  for (final raw in fixtures) {
    final map = raw is Map<String, dynamic>
        ? raw
        : Map<String, dynamic>.from(raw as Map);
    final fixture = (map['fixture'] as Map?)?.cast<String, dynamic>() ?? {};
    final teams = (map['teams'] as Map?)?.cast<String, dynamic>() ?? {};
    final goals = (map['goals'] as Map?)?.cast<String, dynamic>() ?? {};
    final home = (teams['home'] as Map?)?.cast<String, dynamic>() ?? {};
    final away = (teams['away'] as Map?)?.cast<String, dynamic>() ?? {};
    final venue = (fixture['venue'] as Map?)?.cast<String, dynamic>() ?? {};
    final status = (fixture['status'] as Map?)?.cast<String, dynamic>() ?? {};
    final league = (map['league'] as Map?)?.cast<String, dynamic>() ?? {};
    final date = DateTime.tryParse('${fixture['date']}');
    if (date == null) continue;

    parsed.add(
      _KLeagueFixture(
        id: _readNullableInt(fixture['id']) ?? 0,
        home: _kLeagueDisplayTeamName('${home['name'] ?? 'TBD'}'),
        away: _kLeagueDisplayTeamName('${away['name'] ?? 'TBD'}'),
        date: date,
        statusShort: '${status['short'] ?? ''}',
        statusLong: '${status['long'] ?? ''}',
        minuteLabel: _fixtureMinuteLabel(
          _fixtureText(status['elapsed']),
          _fixtureText(status['extra']),
        ),
        venue: '${venue['name'] ?? ''}',
        round: '${league['round'] ?? ''}',
        homeGoals: _readNullableInt(goals['home']),
        awayGoals: _readNullableInt(goals['away']),
      ),
    );
  }
  parsed.sort((a, b) => a.date.compareTo(b.date));
  return parsed;
}

int? _readNullableInt(dynamic value) {
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

List<String> _fixtureRoundKeys(List<_KLeagueFixture> fixtures) {
  final rounds = fixtures
      .map((fixture) => fixture.round)
      .where((round) => round.isNotEmpty)
      .toSet()
      .toList();
  rounds.sort((a, b) => _roundNumber(a).compareTo(_roundNumber(b)));
  return rounds;
}

String _defaultFixtureRound(List<_KLeagueFixture> fixtures) {
  if (fixtures.isEmpty) return '';
  final now = DateTime.now();
  final upcoming = fixtures.where((fixture) => !fixture.date.isBefore(now));
  return (upcoming.isEmpty ? fixtures.last : upcoming.first).round;
}

int _roundNumber(String round) {
  final match = RegExp(r'(\d+)$').firstMatch(round);
  return int.tryParse(match?.group(1) ?? '') ?? 0;
}

String _roundPillLabel(String round) {
  final number = _roundNumber(round);
  if (number <= 0) return round;
  return 'R$number';
}

String _roundTitleLabel(String round) {
  final number = _roundNumber(round);
  if (number <= 0) return round;
  return 'Round $number';
}

String _fixtureDateTimeLabel(DateTime date) {
  return _kstDotDateTimeLabel(date);
}

String _fixtureMinuteLabel(String elapsed, [String extra = '']) {
  if (elapsed.isEmpty) return '';
  final normalizedExtra = extra.trim();
  if (normalizedExtra.isEmpty || normalizedExtra == '0') return "$elapsed'";
  return "$elapsed+$normalizedExtra'";
}

String _fixtureStatusLabel(_KLeagueFixture fixture) {
  switch (fixture.statusShort) {
    case 'FT':
    case 'AET':
    case 'PEN':
      return 'Finished';
    case 'NS':
    case 'TBD':
      return 'Scheduled';
    case '1H':
    case '2H':
    case 'HT':
    case 'ET':
    case 'LIVE':
      return 'LIVE';
    case 'PST':
      return 'Postponed';
    case 'CANC':
      return 'Canceled';
    default:
      return fixture.statusLong.isEmpty ? 'Scheduled' : fixture.statusLong;
  }
}

String _fixtureDetailStatusLabel(String short, String fallback) {
  switch (short) {
    case 'FT':
    case 'AET':
    case 'PEN':
      return 'Final';
    case 'NS':
    case 'TBD':
      return 'Scheduled';
    case '1H':
    case '2H':
    case 'HT':
    case 'ET':
    case 'LIVE':
      return 'LIVE';
    case 'PST':
      return 'Postponed';
    case 'CANC':
      return 'Canceled';
    default:
      return fallback.isEmpty ? 'Scheduled' : fallback;
  }
}

bool _isKLeagueLiveStatus(String short) {
  switch (short.toUpperCase()) {
    case '1H':
    case '2H':
    case 'HT':
    case 'ET':
    case 'LIVE':
      return true;
    default:
      return false;
  }
}

Map<String, dynamic> _fixtureAsMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return const {};
}

List<dynamic> _fixtureAsList(dynamic value) {
  if (value is List<dynamic>) return value;
  if (value is List) return List<dynamic>.from(value);
  return const <dynamic>[];
}

String _fixtureText(dynamic value, [String fallback = '']) {
  if (value == null) return fallback;
  final text = '$value'.trim();
  if (text.isEmpty || text == 'null') return fallback;
  return text;
}

String _scorePartLabel(Map<String, dynamic> score, List<String> keys) {
  if (keys.isEmpty) return '';
  final part = _fixtureAsMap(score[keys.first]);
  final home = _fixtureText(part['home']);
  final away = _fixtureText(part['away']);
  if (home.isEmpty && away.isEmpty) return '';
  return '${home.isEmpty ? '-' : home} : ${away.isEmpty ? '-' : away}';
}
