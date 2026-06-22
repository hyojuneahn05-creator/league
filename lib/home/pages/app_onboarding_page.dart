part of '../home_page.dart';

class AppOnboardingPage extends StatefulWidget {
  const AppOnboardingPage({super.key});

  @override
  State<AppOnboardingPage> createState() => _AppOnboardingPageState();
}

class _AppOnboardingPageState extends State<AppOnboardingPage> {
  static const List<_AppOnboardingSlide> _slides = [
    _AppOnboardingSlide(
      accent: Color(0xFF0F9D58),
      icon: Icons.emoji_events_rounded,
      eyebrow: 'WELCOME',
      title: 'LeagueIt에서\n판타지 리그를 시작하세요',
      body: 'K리그와 KBO 판타지리그를 한 앱에서 만들고, 드래프트와 매치업을 이어서 관리 할 수 있습니다.',
      points: [
        'K리그, KBO 판타지리그 생성과 참가를 빠르게 시작',
        '드래프트 이후 홈에서 이번 주 매치업 바로 확인',
        '로그인 상태에 맞춰 기록과 리그 상태 자동 보관',
      ],
    ),
    _AppOnboardingSlide(
      accent: Color(0xFF2563EB),
      icon: Icons.bolt_rounded,
      eyebrow: 'LIVE MATCHUP',
      title: '실시간 점수와\n라인업 흐름을 추적하세요',
      body: '홈 카드와 경기 상세에서 이번 라운드 점수, 예상 Fpts, 선수별 실제 반영값을 바로 확인할 수 있습니다.',
      points: [
        '매치업 카드에서 리그별 홈 화면 전환',
        '경기 상세에서 선수별 실제 Fpts와 예상 Fpts 비교',
        'K리그, KBO 공식 경기 결과 확인',
      ],
    ),
    _AppOnboardingSlide(
      accent: Color(0xFFF59E0B),
      icon: Icons.explore_rounded,
      eyebrow: 'EXPLORE',
      title: '순위표와 일정,\n선수 정보까지 한 번에',
      body: '홈 아래 순위표와 일정 위젯, 선수 검색과 프로필 화면까지 연결되어 리그 흐름을 끊지 않고 볼 수 있습니다.',
      points: [
        '현재 선택한 리그 기준으로 순위표와 일정 동기화',
        '선수 검색 후 프로필과 라운드 포인트 확인',
        'K리그, KBO 실제 순위와 판타지리그 순위를 각각 확인',
      ],
    ),
  ];

  late final PageController _pageController;
  int _pageIndex = 0;

  bool get _isLastPage => _pageIndex == _slides.length - 1;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _finish() {
    Navigator.of(context).pop(true);
  }

  void _next() {
    if (_isLastPage) {
      _finish();
      return;
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = _leagueItSurfacePalette(context);
    final slide = _slides[_pageIndex];
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: palette.pageBackground,
        body: Stack(
          children: [
            Positioned(
              top: -80,
              right: -30,
              child: _AppOnboardingGlow(
                color: slide.accent.withValues(
                  alpha: palette.isDark ? 0.26 : 0.18,
                ),
                size: 220,
              ),
            ),
            Positioned(
              left: -70,
              bottom: 140,
              child: _AppOnboardingGlow(
                color: palette.accentSoft.withValues(
                  alpha: palette.isDark ? 0.24 : 0.34,
                ),
                size: 190,
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Row(
                          children: [
                            Image.asset(
                              'assets/leagueit_logo.png',
                              width: 28,
                              height: 28,
                              fit: BoxFit.contain,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'LeagueIt Guide',
                              style: TextStyle(
                                color: palette.ink,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: _finish,
                          style: TextButton.styleFrom(
                            foregroundColor: palette.mutedInk,
                          ),
                          child: const Text(
                            '건너뛰기',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Expanded(
                      child: PageView.builder(
                        controller: _pageController,
                        itemCount: _slides.length,
                        onPageChanged: (value) {
                          if (!mounted) return;
                          setState(() => _pageIndex = value);
                        },
                        itemBuilder: (context, index) {
                          final item = _slides[index];
                          final bool active = index == _pageIndex;
                          return AnimatedScale(
                            duration: const Duration(milliseconds: 220),
                            scale: active ? 1 : 0.98,
                            child: Align(
                              alignment: Alignment.topCenter,
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.fromLTRB(
                                  24,
                                  26,
                                  24,
                                  24,
                                ),
                                decoration: BoxDecoration(
                                  color: palette.tileSurface,
                                  borderRadius: BorderRadius.circular(32),
                                  border: Border.all(color: palette.cardBorder),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: palette.isDark ? 0.24 : 0.08,
                                      ),
                                      blurRadius: 30,
                                      offset: const Offset(0, 18),
                                    ),
                                  ],
                                ),
                                child: SingleChildScrollView(
                                  physics: const BouncingScrollPhysics(),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 68,
                                        height: 68,
                                        decoration: BoxDecoration(
                                          color: item.accent.withValues(
                                            alpha: palette.isDark ? 0.2 : 0.12,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            22,
                                          ),
                                        ),
                                        child: Icon(
                                          item.icon,
                                          size: 34,
                                          color: item.accent,
                                        ),
                                      ),
                                      const SizedBox(height: 22),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: item.accent.withValues(
                                            alpha: palette.isDark ? 0.18 : 0.1,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                        ),
                                        child: Text(
                                          item.eyebrow,
                                          style: TextStyle(
                                            color: item.accent,
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 0.7,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 18),
                                      Text(
                                        item.title,
                                        style: TextStyle(
                                          color: palette.ink,
                                          fontSize: 31,
                                          height: 1.16,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      const SizedBox(height: 14),
                                      Text(
                                        item.body,
                                        style: TextStyle(
                                          color: palette.mutedInk,
                                          fontSize: 15,
                                          height: 1.55,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 24),
                                      ...item.points.map(
                                        (point) => Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 12,
                                          ),
                                          child: Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 14,
                                              vertical: 14,
                                            ),
                                            decoration: BoxDecoration(
                                              color: palette.pageBackground,
                                              borderRadius:
                                                  BorderRadius.circular(18),
                                              border: Border.all(
                                                color: palette.cardBorder,
                                              ),
                                            ),
                                            child: Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Container(
                                                  width: 22,
                                                  height: 22,
                                                  margin: const EdgeInsets.only(
                                                    top: 1,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: item.accent
                                                        .withValues(
                                                          alpha: 0.14,
                                                        ),
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: Icon(
                                                    Icons.check_rounded,
                                                    size: 14,
                                                    color: item.accent,
                                                  ),
                                                ),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: Text(
                                                    point,
                                                    style: TextStyle(
                                                      color: palette.ink,
                                                      fontSize: 14,
                                                      height: 1.45,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
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
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        ...List.generate(_slides.length, (index) {
                          final bool active = index == _pageIndex;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: active ? 28 : 9,
                            height: 9,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: active ? slide.accent : palette.chipBorder,
                              borderRadius: BorderRadius.circular(999),
                            ),
                          );
                        }),
                        const Spacer(),
                        Text(
                          '${_pageIndex + 1}/${_slides.length}',
                          style: TextStyle(
                            color: palette.mutedInk,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _next,
                        style: FilledButton.styleFrom(
                          backgroundColor: slide.accent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 17),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: Text(
                          _isLastPage ? '시작하기' : '다음',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppOnboardingSlide {
  final Color accent;
  final IconData icon;
  final String eyebrow;
  final String title;
  final String body;
  final List<String> points;

  const _AppOnboardingSlide({
    required this.accent,
    required this.icon,
    required this.eyebrow,
    required this.title,
    required this.body,
    required this.points,
  });
}

class _AppOnboardingGlow extends StatelessWidget {
  final Color color;
  final double size;

  const _AppOnboardingGlow({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
        ),
      ),
    );
  }
}
