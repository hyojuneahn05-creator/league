part of '../home_page.dart';

enum LeagueCard { kLeague, kbo }

class CardSwitcher extends StatefulWidget {
  final bool isLoggedIn;
  final bool hasSoccerLeague;
  final bool hasBaseballLeague;
  final bool frontLeagueIsSoccer;
  final ValueChanged<bool>? onFrontLeagueChanged;

  const CardSwitcher({
    super.key,
    required this.isLoggedIn,
    required this.hasSoccerLeague,
    required this.hasBaseballLeague,
    required this.frontLeagueIsSoccer,
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
  Curve _releaseCurve = Curves.linear;

  static const double switchThreshold = 120;
  static const double maxDrag = 220;
  static const double peek = 16;
  static const double releasePixelsPerSecond = 520;

  double _lerp(double begin, double end, double t) {
    return begin + (end - begin) * t;
  }

  void _syncFrontLeague(bool isSoccer) {
    _front = isSoccer ? LeagueCard.kLeague : LeagueCard.kbo;
    _back = isSoccer ? LeagueCard.kbo : LeagueCard.kLeague;
  }

  @override
  void initState() {
    super.initState();
    _syncFrontLeague(widget.frontLeagueIsSoccer);
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );

    _controller.addListener(() {
      final t = _releaseCurve.transform(_controller.value);
      setState(() {
        dragX = _fromDrag + (_toDrag - _fromDrag) * t;
      });
    });

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (_pendingSwitch) {
          final tmp = _front;
          _front = _back;
          _back = tmp;
          _pendingSwitch = false;
          dragX = 0.0;
          widget.onFrontLeagueChanged?.call(_front == LeagueCard.kLeague);
          setState(() {});
          return;
        }

        if (dragX != 0.0) {
          setState(() => dragX = 0.0);
        }
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onFrontLeagueChanged?.call(_front == LeagueCard.kLeague);
    });
  }

  @override
  void didUpdateWidget(covariant CardSwitcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.frontLeagueIsSoccer == widget.frontLeagueIsSoccer) return;
    if (_controller.isAnimating) return;
    setState(() {
      dragX = 0.0;
      _pendingSwitch = false;
      _syncFrontLeague(widget.frontLeagueIsSoccer);
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
    _toDrag = _pendingSwitch ? dragX.sign * maxDrag : 0.0;
    final distance = (_toDrag - _fromDrag).abs();
    final durationMs = ((distance / releasePixelsPerSecond) * 1000)
        .round()
        .clamp(140, 360);
    _releaseCurve = Curves.linear;
    _controller.duration = Duration(milliseconds: durationMs);
    _controller.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final mediaSize = MediaQuery.sizeOf(context);
    final screenWidth = mediaSize.width;
    final bool isTabletLayout = mediaSize.shortestSide >= 700;
    final double frameWidth = min(
      max(284.0, screenWidth - 44.0),
      isTabletLayout ? 600.0 : double.infinity,
    );
    final cardWidth = frameWidth - peek;
    final cardHeight = cardWidth * (isTabletLayout ? 0.54 : 0.62);
    final double m = dragX.abs();
    final double progress = (m / switchThreshold).clamp(0.0, 1.0);
    bool hasLeagueFor(bool isSoccer) =>
        isSoccer ? widget.hasSoccerLeague : widget.hasBaseballLeague;

    final Offset frontOffset = Offset(m, -m * 0.35);
    final Offset backOffset = Offset(_lerp(peek, 6, progress), -peek);
    final double frontScale = _lerp(1.0, 0.94, progress);
    final double backScale = _lerp(0.95, 1.0, progress);
    final double frontRotation = _lerp(0.0, 0.03, progress);

    final bool frontSoccer = _front == LeagueCard.kLeague;
    final bool backSoccer = _back == LeagueCard.kLeague;
    final frontMatchup = homeKey.currentState?.currentFantasyMatchupForSport(
      frontSoccer,
    );
    final backMatchup = homeKey.currentState?.currentFantasyMatchupForSport(
      backSoccer,
    );
    final bool showMatchUpFront = widget.isLoggedIn && frontMatchup != null;
    final bool showMatchUpBack = widget.isLoggedIn && backMatchup != null;

    Widget cardFor({
      required bool isSoccer,
      required bool showMatchUp,
      required _FantasyMatchupView? matchup,
      required VoidCallback onStart,
    }) {
      if (showMatchUp) {
        return MatchupCard(
          isSoccer: isSoccer,
          onStart: onStart,
          matchup: matchup,
        );
      }

      if (widget.isLoggedIn &&
          hasLeagueFor(isSoccer) &&
          !kUseMockDataOutsideDraft) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onStart,
          child: _LeagueDataPendingCard(isSoccer: isSoccer),
        );
      }

      return CardBase(
        title: "CREATE YOUR LEAGUE",
        subtitle: isSoccer ? "K League · Soccer" : "KBO · Baseball",
        isSoccer: isSoccer,
        onStart: onStart,
      );
    }

    Future<void> openFor(bool isSoccer, _FantasyMatchupView? matchup) async {
      if (!widget.isLoggedIn) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CreateLeaguePage(isSoccer: isSoccer),
          ),
        );
        return;
      }
      final fantasyDraft = widget.isLoggedIn && hasLeagueFor(isSoccer)
          ? homeKey.currentState?.fantasyDraftForSport(isSoccer)
          : null;
      Navigator.push(
        context,
        _matchDetailPageRoute(
          isSoccer: isSoccer,
          draft: fantasyDraft,
          initialSection: _MatchSection.matchup,
          preferredFantasyRound: matchup?.round,
        ),
      );
    }

    Widget animatedCard({
      required Widget child,
      required Offset offset,
      required double scale,
      required double opacity,
      required double rotation,
      bool interactive = false,
    }) {
      final card = Transform.translate(
        offset: offset,
        child: Transform.rotate(
          angle: rotation,
          alignment: Alignment.center,
          child: Transform.scale(
            scale: scale,
            alignment: Alignment.center,
            child: Opacity(opacity: opacity.clamp(0.0, 1.0), child: child),
          ),
        ),
      );

      if (!interactive) {
        return IgnorePointer(ignoring: true, child: card);
      }

      return GestureDetector(
        behavior: HitTestBehavior.translucent,
        // Horizontal-only drag so vertical swipes can scroll the home page.
        onHorizontalDragUpdate: handleDragUpdate,
        onHorizontalDragEnd: handleDragEnd,
        child: card,
      );
    }

    return SizedBox(
      width: frameWidth,
      height: cardHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          animatedCard(
            offset: backOffset,
            child: SizedBox(
              width: cardWidth,
              height: cardHeight,
              child: cardFor(
                isSoccer: backSoccer,
                showMatchUp: showMatchUpBack,
                matchup: backMatchup,
                onStart: () => openFor(backSoccer, backMatchup),
              ),
            ),
            scale: backScale,
            opacity: 1.0,
            rotation: 0.0,
          ),
          animatedCard(
            offset: frontOffset,
            scale: frontScale,
            opacity: 1.0,
            rotation: frontRotation,
            interactive: true,
            child: SizedBox(
              width: cardWidth,
              height: cardHeight,
              child: cardFor(
                isSoccer: frontSoccer,
                showMatchUp: showMatchUpFront,
                matchup: frontMatchup,
                onStart: () => openFor(frontSoccer, frontMatchup),
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
      width: double.infinity,
      height: double.infinity,
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
            '공식 경기/포인트 데이터 연동 후 제공됩니다.',
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
