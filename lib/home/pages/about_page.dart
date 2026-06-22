part of '../home_page.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  bool _isMyPageOpen = false;

  void _toggleMyPage() => setState(() => _isMyPageOpen = !_isMyPageOpen);

  @override
  Widget build(BuildContext context) {
    return _OverlayScaffold(
      isMyPageOpen: _isMyPageOpen,
      onToggleMyPage: _toggleMyPage,
      showSearch: false,
      child: const _AboutHero(),
    );
  }
}

class _AboutHero extends StatelessWidget {
  const _AboutHero();

  @override
  Widget build(BuildContext context) {
    final palette = _leagueItSurfacePalette(context);
    final width = MediaQuery.sizeOf(context).width;
    final heroHeight = width < 420 ? 260.0 : 320.0;
    final headlineSize = width < 420 ? 30.0 : 42.0;
    final bodySize = width < 420 ? 20.0 : 24.0;
    final contactTitleSize = width < 420 ? 18.0 : 20.0;
    final contactBodySize = width < 420 ? 16.0 : 18.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 36),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: heroHeight,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: palette.cardBorder.withValues(alpha: 0.5),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.10),
                      blurRadius: 28,
                      offset: const Offset(0, 18),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset('assets/About_us_soccer.jpg', fit: BoxFit.cover),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.18),
                            Colors.black.withValues(alpha: 0.34),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'About us',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w500,
                              shadows: [
                                Shadow(
                                  blurRadius: 16,
                                  color: Colors.black54,
                                  offset: Offset(0, 3),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 760),
                                child: Text(
                                  '판타지 스포츠를 더 쉽고, 더 재미있게',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: headlineSize,
                                    height: 1.22,
                                    fontWeight: FontWeight.w800,
                                    shadows: const [
                                      Shadow(
                                        blurRadius: 24,
                                        color: Colors.black87,
                                        offset: Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
                child: Text(
                  'LeagueIt은 K리그와 KBO를 사랑하는 모든 분들을 위한 판타지 스포츠 플랫폼입니다. 나이, 성별에 관계없이 누구나 쉽게 자신만의 판타지 리그를 만들고, 친구들과 함께 경쟁하며 한국 스포츠의 짜릿함을 더 깊이 즐길 수 있습니다.',
                  style: TextStyle(
                    color: palette.ink,
                    fontSize: bodySize,
                    height: 1.55,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: palette.cardBorder.withValues(alpha: 0.5),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 24,
                      offset: const Offset(0, 14),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.asset(
                  'assets/about_us_phone.png',
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
                child: Text(
                  'LeagueIt은 리그를 만드는 순간부터 시즌이 끝날 때까지, 유저가 자신의 팀을 직접 운영하고 친구들과 경쟁하는 전 과정을 한곳에서 경험할 수 있도록 돕습니다.',
                  style: TextStyle(
                    color: palette.ink,
                    fontSize: bodySize,
                    height: 1.55,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: palette.tileSurface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: palette.cardBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '연락처',
                      style: TextStyle(
                        color: palette.ink,
                        fontSize: contactTitleSize,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'leagueit@gmail.com',
                      style: TextStyle(
                        color: palette.mutedInk,
                        fontSize: contactBodySize,
                        height: 1.4,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
