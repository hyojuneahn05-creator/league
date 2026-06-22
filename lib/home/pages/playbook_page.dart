part of '../home_page.dart';

class PlaybookPage extends StatefulWidget {
  const PlaybookPage({super.key});

  @override
  State<PlaybookPage> createState() => _PlaybookPageState();
}

class _PlaybookPageState extends State<PlaybookPage> {
  bool _isMyPageOpen = false;
  void _toggleMyPage() => setState(() => _isMyPageOpen = !_isMyPageOpen);

  @override
  Widget build(BuildContext context) {
    return _OverlayScaffold(
      isMyPageOpen: _isMyPageOpen,
      onToggleMyPage: _toggleMyPage,
      showSearch: false,
      child: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(child: _PlaybookHero()),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 36),
            sliver: SliverList.list(
              children: const [_PlaybookTimeline()],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaybookHero extends StatelessWidget {
  const _PlaybookHero();

  @override
  Widget build(BuildContext context) {
    final palette = _leagueItSurfacePalette(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 20, 0, 18),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 26),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              palette.accent,
              palette.accent.withValues(alpha: 0.82),
            ],
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: palette.accent.withValues(alpha: 0.22),
              blurRadius: 26,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.18),
                ),
              ),
              child: const Text(
                'LeagueIt 이용 방법',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'PlayBook',
              style: TextStyle(
                color: Colors.white,
                fontSize: 34,
                height: 1.05,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.7,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaybookTimeline extends StatelessWidget {
  const _PlaybookTimeline();

  @override
  Widget build(BuildContext context) {
    final palette = _leagueItSurfacePalette(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 980),
        child: Column(
          children: [
            for (var index = 0; index < _playbookSteps.length; index++)
              _PlaybookStepCard(
                step: _playbookSteps[index],
                index: index,
                isLast: index == _playbookSteps.length - 1,
              ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: palette.accentSoft,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: palette.chipBorder),
              ),
              child: Text(
                '리그 생성부터 시즌 운영까지 모든 기능은 LeagueIt 안에서 하나의 흐름으로 연결됩니다.',
                style: TextStyle(
                  color: palette.accent,
                  fontSize: 15,
                  height: 1.45,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaybookStepCard extends StatelessWidget {
  final _PlaybookStepData step;
  final int index;
  final bool isLast;

  const _PlaybookStepCard({
    required this.step,
    required this.index,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final palette = _leagueItSurfacePalette(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 64,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: palette.accent,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: palette.accent.withValues(alpha: 0.24),
                        blurRadius: 16,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (!isLast)
                  Container(
                    width: 2,
                    height: 88,
                    margin: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          palette.accent.withValues(alpha: 0.40),
                          palette.cardBorder,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
              decoration: BoxDecoration(
                color: palette.tileSurface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: palette.cardBorder),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: palette.accentSoft,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(step.icon, color: palette.accent, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'STEP ${index + 1}',
                              style: TextStyle(
                                color: palette.mutedInk,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              step.title,
                              style: TextStyle(
                                color: palette.ink,
                                fontSize: 20,
                                height: 1.2,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    step.body,
                    style: TextStyle(
                      color: palette.ink,
                      fontSize: 15,
                      height: 1.55,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaybookStepData {
  final IconData icon;
  final String title;
  final String body;

  const _PlaybookStepData({
    required this.icon,
    required this.title,
    required this.body,
  });
}

const List<_PlaybookStepData> _playbookSteps = [
  _PlaybookStepData(
    icon: Icons.person_add_alt_1_rounded,
    title: '회원가입 / 로그인',
    body: '이메일 또는 Google 계정으로 가입하세요.',
  ),
  _PlaybookStepData(
    icon: Icons.groups_rounded,
    title: '리그 생성 / 참가',
    body: '새 판타지 리그를 만들거나, 초대 코드로 친구의 리그에 참가하세요.',
  ),
  _PlaybookStepData(
    icon: Icons.how_to_vote_rounded,
    title: '드래프트',
    body: '리그 시작 전 드래프트를 통해 K리그 또는 KBO 선수들을 선택하세요.',
  ),
  _PlaybookStepData(
    icon: Icons.view_quilt_rounded,
    title: '로스터 구성',
    body: '드래프트 후 나만의 팀 로스터를 구성하세요. 포지션별로 선수를 배치하고 최적의 라인업을 완성하세요.',
  ),
  _PlaybookStepData(
    icon: Icons.compare_arrows_rounded,
    title: '선수 영입 및 트레이드',
    body: '시즌 중 부진한 선수는 방출하고 새로운 선수를 영입할 수 있습니다. 또한 다른 팀과 트레이드를 통해 원하는 선수를 데려올 수 있습니다.',
  ),
  _PlaybookStepData(
    icon: Icons.stars_rounded,
    title: '선수 점수 확인',
    body: '실제 경기 결과를 바탕으로 선수들의 판타지 포인트가 자동으로 계산됩니다.',
  ),
  _PlaybookStepData(
    icon: Icons.emoji_events_rounded,
    title: '매치업 확인',
    body: '매주 상대방과의 판타지 점수를 비교하며 승부를 겨루세요.',
  ),
  _PlaybookStepData(
    icon: Icons.leaderboard_rounded,
    title: '순위 확인',
    body: '리그 탭에서 전체 순위와 나의 성적을 확인하세요.',
  ),
];
