part of '../home_page.dart';

enum LeagueCard { kLeague, kbo }

class CardSwitcher extends StatefulWidget {
  final bool isLoggedIn;

  const CardSwitcher({super.key, required this.isLoggedIn});

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
      }
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
    final bool showMatchUp = widget.isLoggedIn;

    final Offset frontOffset = Offset(m, -m * 0.35);
    final Offset backOffset = Offset(peek - m * 0.9, -peek + m * 0.35);

    final bool frontSoccer = _front == LeagueCard.kLeague;
    final bool backSoccer = _back == LeagueCard.kLeague;

    final String frontTitle = showMatchUp
        ? "THIS WEEK MATCH"
        : "CREATE YOUR LEAGUE";

    final String frontSubtitle = showMatchUp
        ? "You vs Alex · K League"
        : (frontSoccer ? "K League · Soccer" : "KBO · Baseball");

    final VoidCallback frontAction = showMatchUp
        ? () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const SimplePage(title: "Match Detail"),
              ),
            );
          }
        : () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CreateLeaguePage(isSoccer: frontSoccer),
              ),
            );
          };

    return SizedBox(
      width: 300,
      height: 200,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Transform.translate(
            offset: backOffset,
            child: CardBase(
              title: showMatchUp ? "THIS WEEK MATCH" : "CREATE YOUR LEAGUE",
              subtitle: showMatchUp
                  ? (backSoccer
                        ? "You vs Alex · K League"
                        : "You vs Alex · KBO")
                  : (backSoccer ? "K League · Soccer" : "KBO · Baseball"),
              isSoccer: backSoccer,
              onStart: () {},
            ),
          ),

          Transform.translate(
            offset: frontOffset,
            child: GestureDetector(
              onPanUpdate: handleDragUpdate,
              onPanEnd: handleDragEnd,
              child: CardBase(
                title: frontTitle,
                subtitle: frontSubtitle,
                isSoccer: frontSoccer,
                onStart: frontAction,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
