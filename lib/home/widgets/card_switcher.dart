part of '../home_page.dart';

enum LeagueCard { kLeague, kbo }

class CardSwitcher extends StatefulWidget {
  final bool isLoggedIn;
  final bool hasSoccerLeague;
  final bool hasBaseballLeague;
  final ValueChanged<bool>? onFrontLeagueChanged;

  const CardSwitcher({
    super.key,
    required this.isLoggedIn,
    required this.hasSoccerLeague,
    required this.hasBaseballLeague,
    this.onFrontLeagueChanged,
  });

  @override
  State<CardSwitcher> createState() => _CardSwitcherState();
}

class _CardSwitcherState extends State<CardSwitcher>
    with SingleTickerProviderStateMixin {
  double dragX = 0.0;
  late final AnimationController _controller;

  LeagueCard _front = LeagueCard.kLeague;
  LeagueCard _back = LeagueCard.kbo;

  double _fromDrag = 0.0;
  double _toDrag = 0.0;
  bool _pendingSwitch = false;

  static const double switchThreshold = 120;
  static const double maxDrag = 220;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );

    _controller.addListener(() {
      final t = Curves.easeOutCubic.transform(_controller.value);
      setState(() {
        dragX = _fromDrag + (_toDrag - _fromDrag) * t;
      });
    });

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && _pendingSwitch) {
        final tmp = _front;
        _front = _back;
        _back = tmp;
        _pendingSwitch = false;
        widget.onFrontLeagueChanged?.call(_front == LeagueCard.kLeague);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onFrontLeagueChanged?.call(_front == LeagueCard.kLeague);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void handleDragUpdate(DragUpdateDetails d) {
    if (_controller.isAnimating) _controller.stop();
    setState(() {
      dragX += d.delta.dx;
      dragX = dragX.clamp(-maxDrag, maxDrag);
    });
  }

  void handleDragEnd(DragEndDetails _) {
    _pendingSwitch = dragX.abs() > switchThreshold;
    _fromDrag = dragX;
    _toDrag = 0.0;
    _controller.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    const double peek = 16;
    final double m = dragX.abs();
    bool hasLeagueFor(bool isSoccer) =>
        isSoccer ? widget.hasSoccerLeague : widget.hasBaseballLeague;

    final Offset frontOffset = Offset(m, -m * 0.35);
    final Offset backOffset = Offset(peek - m * 0.9, -peek + m * 0.35);

    final bool frontSoccer = _front == LeagueCard.kLeague;
    final bool backSoccer = _back == LeagueCard.kLeague;
    final bool showMatchUpFront =
        kUseMockDataOutsideDraft &&
        widget.isLoggedIn &&
        hasLeagueFor(frontSoccer);
    final bool showMatchUpBack =
        kUseMockDataOutsideDraft && widget.isLoggedIn && hasLeagueFor(backSoccer);

    Widget cardFor({
      required bool isSoccer,
      required bool showMatchUp,
      required VoidCallback onStart,
    }) {
      if (showMatchUp) {
        return MatchupCard(
          isSoccer: isSoccer,
          onStart: onStart,
        );
      }

      if (widget.isLoggedIn &&
          hasLeagueFor(isSoccer) &&
          !kUseMockDataOutsideDraft) {
        return _LeagueDataPendingCard(isSoccer: isSoccer);
      }

      return CardBase(
        title: "CREATE YOUR LEAGUE",
        subtitle: isSoccer ? "K League · Soccer" : "KBO · Baseball",
        isSoccer: isSoccer,
        onStart: onStart,
      );
    }

    Future<void> openFor(bool isSoccer) async {
      if (widget.isLoggedIn && hasLeagueFor(isSoccer)) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MatchDetailPage(
              isSoccer: isSoccer,
              initialSection: _MatchSection.matchup,
            ),
          ),
        );
        return;
      }

      // 이미 로그인되어 있으면 바로 생성 화면으로 이동
      if (homeKey.currentState?.isLoggedIn == true) {
        final result = await Navigator.push<_DraftResult>(
          context,
          MaterialPageRoute(
            builder: (_) => CreateLeaguePage(isSoccer: isSoccer),
          ),
        );
        if (result != null) {
          homeKey.currentState
              ?.setDraft(result.when, result.leagueName, isSoccer: isSoccer);
          homeKey.currentState?.setHasLeagueForSport(isSoccer, true);
        }
        return;
      }

      // 로그인 안된 상태면 로그인부터
      final loggedIn = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
      if (loggedIn == true) {
        homeKey.currentState?.updateLogin(true);
        final result = await Navigator.push<_DraftResult>(
          context,
          MaterialPageRoute(
            builder: (_) => CreateLeaguePage(isSoccer: isSoccer),
          ),
        );
        if (result != null) {
          homeKey.currentState
              ?.setDraft(result.when, result.leagueName, isSoccer: isSoccer);
          homeKey.currentState?.setHasLeagueForSport(isSoccer, true);
        }
      }
    }

    return SizedBox(
      width: 300,
      height: 200,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Transform.translate(
            offset: backOffset,
            child: cardFor(
              isSoccer: backSoccer,
              showMatchUp: showMatchUpBack,
              onStart: () => openFor(backSoccer),
            ),
          ),
          Transform.translate(
            offset: frontOffset,
            child: GestureDetector(
              // Horizontal-only drag so vertical swipes can scroll the home page.
              onHorizontalDragUpdate: handleDragUpdate,
              onHorizontalDragEnd: handleDragEnd,
              child: cardFor(
                isSoccer: frontSoccer,
                showMatchUp: showMatchUpFront,
                onStart: () => openFor(frontSoccer),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LeagueDataPendingCard extends StatelessWidget {
  final bool isSoccer;

  const _LeagueDataPendingCard({required this.isSoccer});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      width: 300,
      height: 200,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cs.onSurface.withOpacity(0.16), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isSoccer ? 'K League' : 'KBO',
            style: TextStyle(
              color: cs.primary,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '실시간 경기/포인트 데이터 연동 준비 중',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const Spacer(),
          Text(
            'Mock 데이터는 Draft 연습에서만 사용됩니다.',
            style: TextStyle(
              color: cs.onSurface.withOpacity(0.7),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
